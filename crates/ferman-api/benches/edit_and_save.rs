//! The engine's parts of two budgets (docs/ARCHITECTURE.md §14), through the facade as the app
//! calls it:
//!
//! - **Edit-to-render:** from `apply` through `commit` (which has PDFium reload the document) to
//!   the bitmaps of every tile the edited block touches, at 100 % with a device pixel ratio of 2,
//!   on `kira-tr` and on a page of `long-500`. The engine's budget is 75 ms.
//! - **Save:** the incremental save of a 20 MB, 500-page file with 10 edits, including the flush
//!   to disk, on a temporary copy. The budget is 500 ms. The 20 MB file is `long-500` with an
//!   incremental update of 500 unreferenced streams of random bytes, one a page, as images would
//!   weigh; it is built here, in the temporary directory, and never joins the corpus.
//!
//! Needs the PDFium library (`FERMAN_PDFIUM_PATH`, absolute) and `long-500.pdf`, which is over
//! 1 MB and so not committed: `cargo run --manifest-path tools/corpus/Cargo.toml -- generate`
//! makes it. Without either the benchmark says so and measures nothing.
//!
//! - **Annotation commits:** adding a square and moving it on a page of `long-500`, each one step
//!   (M4 decision 16). No budget of its own yet: ROADMAP §8 asks for the measurement.
//! - **Form commits:** a text field's value set on a page of `long-500` as the app sends it on blur
//!   or Tab, one step (decision 16), once in the field's own font and once in bundled Plex. The
//!   field is added here by an incremental update of the copy. No budget of its own yet.
//!
//! With `FERMAN_BENCH_GUARD=1` (CI) it then times the slowest of 20 edits of each file and one
//! cold save and fails above the budgets: a guard against a gross regression, since a CI runner
//! is not R1 or R2.
//!
//! ```sh
//! FERMAN_PDFIUM_PATH="$PWD/build/pdfium/<id>/lib/<libpdfium>" cargo bench -p ferman-api --bench edit_and_save
//! ```
// A benchmark is a program: it reports on stderr and fails loudly.
#![allow(
    clippy::print_stderr,
    clippy::expect_used,
    clippy::unwrap_used,
    clippy::panic
)]

use std::fmt::Write as _;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{Receiver, Sender, channel};
use std::time::{Duration, Instant};

use criterion::Criterion;
use ferman_api::facade::{
    AnnotationChange, AnnotationKind, BlockInfo, DocumentId, Engine, EngineConfig, FontSettings,
    Item, NewAnnotation, PageSize, PdfiumLibrary, Priority, TilePosition, TileRequest, ViewEvent,
    ViewSink, Wanted, ZoomBucket, block_on,
};

/// The engine's part of edit-to-render (ARCHITECTURE §14).
const EDIT_TO_RENDER: Duration = Duration::from_millis(75);

/// The save of 20 MB, 500 pages and 10 edits (ARCHITECTURE §14).
const SAVE: Duration = Duration::from_millis(500);

/// The file the save budget names.
const SAVE_FILE_BYTES: usize = 20_000_000;

/// How much slower than R1 and R2 the guard lets a shared CI runner be (ARCHITECTURE §14): a guard
/// against a gross regression. The reference budgets stay the owner's checks on R1 and R2.
const CI_CALIBRATION: u32 = 4;

/// The tile grid at 100 % with a device pixel ratio of 2.
const TILE_POINTS: f32 = 256.0;

struct Events(Sender<ViewEvent>);

impl ViewSink for Events {
    fn deliver(&mut self, event: ViewEvent) -> bool {
        self.0.send(event).is_ok()
    }
}

fn corpus(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"))
}

fn text_of(block: &BlockInfo) -> String {
    block
        .lines
        .iter()
        .map(|line| line.text.as_str())
        .collect::<Vec<_>>()
        .join("\n")
}

/// `long-500` with an incremental update that brings it to `SAVE_FILE_BYTES`.
fn padded(long: &[u8]) -> Vec<u8> {
    const STREAMS: usize = 500;
    let tail = String::from_utf8_lossy(&long[long.len() - 512..]).into_owned();
    let trailer = tail.rsplit_once("trailer").unwrap().1;
    let (dict, rest) = trailer.split_once("startxref").unwrap();
    let previous: usize = rest.split_whitespace().next().unwrap().parse().unwrap();
    let (dict, size) = dict.trim().rsplit_once("/Size ").unwrap();
    let size: usize = size.trim_end_matches(">>").parse().unwrap();

    let mut out = long.to_vec();
    let length = (SAVE_FILE_BYTES - long.len()) / STREAMS;
    let mut state = 0x2545_F491_4F6C_DD1D_u64;
    let mut offsets = String::new();
    for index in 0..STREAMS {
        writeln!(offsets, "{:010} 00000 n ", out.len()).unwrap();
        out.extend_from_slice(
            format!("{} 0 obj\n<</Length {length}>>\nstream\n", size + index).as_bytes(),
        );
        // Xorshift: bytes no later step could compress away.
        out.extend((0..length).map(|_| {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            state.to_le_bytes()[0]
        }));
        out.extend_from_slice(b"\nendstream\nendobj\n");
    }
    let xref = out.len();
    out.extend_from_slice(
        format!(
            "xref\n{size} {STREAMS}\n{offsets}trailer\n{dict}/Size {}/Prev {previous}>>\nstartxref\n{xref}\n%%EOF\n",
            size + STREAMS
        )
        .as_bytes(),
    );
    out
}

/// `long` with a text field on page 251 (index 250) by an incremental update: the page, the catalog
/// with its form, the field and its font.
fn with_form(long: &[u8], path: &Path) -> Vec<u8> {
    let document = ferman_core::open(
        &ferman_core::Source::from_bytes(long.to_vec().into()),
        &ferman_core::OpenOptions::default(),
    )
    .unwrap();
    let store = ferman_core::revision::RevisionStore::new(&document);
    let page = store.page_refs(&document, &[250]).unwrap()[0].handle() >> 16;
    let text = String::from_utf8_lossy(long).into_owned();
    let tail = &text[text.len() - 512..];
    let trailer = tail.rsplit_once("trailer").unwrap().1;
    let (dict, rest) = trailer.split_once("startxref").unwrap();
    let previous: usize = rest.split_whitespace().next().unwrap().parse().unwrap();
    let (dict, size) = dict.trim().rsplit_once("/Size ").unwrap();
    let size: usize = size.trim_end_matches(">>").parse().unwrap();
    let root: usize = dict
        .split_once("/Root ")
        .unwrap()
        .1
        .split_whitespace()
        .next()
        .unwrap()
        .parse()
        .unwrap();
    let body = |number: u64| -> String {
        let start = text.find(&format!("\n{number} 0 obj\n")).unwrap() + 1;
        let open = text[start..].find("<<").unwrap() + start;
        let end = text[open..].find("\nendobj").unwrap() + open;
        text[open..end].trim_end().trim_end_matches(">>").to_owned()
    };
    let (field, font) = (size, size + 1);
    let objects = [
        (page, format!("{}/Annots[{field} 0 R]>>", body(page))),
        (
            root as u64,
            format!(
                "{}/AcroForm<</Fields[{field} 0 R]/DR<</Font<</Helv {font} 0 R>>>>/DA(/Helv 0 Tf 0 g)>>>>",
                body(root as u64)
            ),
        ),
        (
            field as u64,
            format!(
                "<</Type/Annot/Subtype/Widget/FT/Tx/T(ad)/Rect[72 700 300 720]/F 4/P {page} 0 R/DA(/Helv 10 Tf 0 g)>>"
            ),
        ),
        (
            font as u64,
            "<</Type/Font/Subtype/Type1/BaseFont/Helvetica/Encoding/WinAnsiEncoding>>".to_owned(),
        ),
    ];
    let mut out = long.to_vec();
    let mut xref = String::from("xref\n");
    for (number, object) in objects {
        writeln!(xref, "{number} 1\n{:010} 00000 n ", out.len()).unwrap();
        out.extend_from_slice(format!("{number} 0 obj\n{object}\nendobj\n").as_bytes());
    }
    let at = out.len();
    out.extend_from_slice(
        format!(
            "{xref}trailer\n{dict}/Size {}/Prev {previous}>>\nstartxref\n{at}\n%%EOF\n",
            size + 2
        )
        .as_bytes(),
    );
    std::fs::write(path, &out).unwrap();
    out
}

/// A field's value set, as one step; only the commit is timed.
fn field_set(engine: &Engine, document: DocumentId, value: &str) -> Duration {
    let field = block_on(engine.form_fields(document)).unwrap().fields[0].handle;
    let start = Instant::now();
    block_on(engine.set_field_value(
        document,
        field,
        vec![value.to_owned()],
        None,
        "Fill".to_owned(),
    ))
    .unwrap();
    let elapsed = start.elapsed();
    block_on(engine.undo(document)).unwrap();
    elapsed
}

/// One edit of a block on an open document.
struct Target {
    document: DocumentId,
    page: u32,
    size: PageSize,
    block: BlockInfo,
    edited: String,
}

/// The first block on `page` of an open document that has `from`, and its text with `from`
/// replaced by `to`.
fn target(
    engine: &Engine,
    document: DocumentId,
    page: u32,
    size: PageSize,
    (from, to): (&str, &str),
) -> Target {
    let blocks = block_on(engine.text_blocks(document, page)).unwrap();
    let block = blocks
        .blocks
        .into_iter()
        .find(|block| text_of(block).contains(from))
        .unwrap_or_else(|| panic!("no block on page {page} has {from:?}"));
    let edited = text_of(&block).replacen(from, to, 1);
    Target {
        document,
        page,
        size,
        block,
        edited,
    }
}

/// Every tile the block touches at 100 % with a device pixel ratio of 2.
fn tiles(target: &Target) -> Vec<Wanted> {
    let [left, top, right, bottom] = target.block.frame;
    let cell = |points: f32, side: f32| {
        // A frame may reach past its page; the grid does not.
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let index = (points.clamp(0.0, side - 1.0) / TILE_POINTS) as u32;
        index
    };
    let (width, height) = (target.size.width, target.size.height);
    let mut wanted = Vec::new();
    for row in cell(top, height)..=cell(bottom, height) {
        for column in cell(left, width)..=cell(right, width) {
            wanted.push(Wanted {
                item: Item::Tile(TileRequest {
                    page: target.page,
                    zoom: ZoomBucket::new(0).unwrap(),
                    device_pixel_ratio: 2.0,
                    position: TilePosition { column, row },
                }),
                priority: Priority::Visible,
            });
        }
    }
    wanted
}

/// The edit from `apply` to the bitmaps of every tile the block touches, then undone, which is
/// not timed.
fn edit_to_render(engine: &Engine, target: &Target) -> Duration {
    let tx = block_on(engine.begin_edit(target.document, target.page, target.block.id)).unwrap();
    let (sender, events): (_, Receiver<ViewEvent>) = channel();
    let view = block_on(engine.open_view(target.document, Box::new(Events(sender)))).unwrap();
    let wanted = tiles(target);
    let count = wanted.len();

    let start = Instant::now();
    block_on(engine.apply(tx, target.edited.clone())).unwrap();
    let revision = block_on(engine.commit(tx, "Edited text".to_owned())).unwrap();
    let key = revision.render_key.expect("PDFium reloaded");
    engine.request(view, 1, wanted).unwrap();
    for _ in 0..count {
        match events.recv_timeout(Duration::from_secs(30)).unwrap() {
            ViewEvent::Rendered(rendered) => assert_eq!(rendered.render_key, key),
            ViewEvent::Failed(failed) => panic!("{failed:?}"),
        }
    }
    let elapsed = start.elapsed();

    engine.close_view(view).unwrap();
    block_on(engine.undo(target.document)).unwrap();
    elapsed
}

/// The save of a fresh copy of the 20 MB file with 10 edits committed on pages 1, 51, 101…;
/// only the save is timed.
fn save(engine: &Engine, source: &Path, dir: &Path) -> Duration {
    let path = dir.join("copy.pdf");
    std::fs::copy(source, &path).unwrap();
    let opened = block_on(engine.open(path.clone(), None)).unwrap();
    assert_eq!(opened.read_only, None);
    assert_eq!(opened.pages.len(), 500);
    for page in (0..500u32).step_by(50) {
        let size = opened.pages[page as usize].size;
        let edit = target(engine, opened.id, page, size, ("the", "he"));
        let tx = block_on(engine.begin_edit(opened.id, page, edit.block.id)).unwrap();
        block_on(engine.apply(tx, edit.edited)).unwrap();
        block_on(engine.commit(tx, "Edited text".to_owned())).unwrap();
    }
    let history = block_on(engine.history(opened.id)).unwrap();
    assert_eq!(history.current, 10);

    let start = Instant::now();
    block_on(engine.save(opened.id, None)).unwrap();
    let elapsed = start.elapsed();

    let (before, after) = (
        std::fs::read(source).unwrap(),
        std::fs::read(&path).unwrap(),
    );
    assert!(
        after.len() > before.len() && after.starts_with(&before),
        "incremental"
    );
    block_on(engine.close(opened.id)).unwrap();
    std::fs::remove_file(path).unwrap();
    elapsed
}

/// A square added on a page of the open document, then undone, which is not timed.
fn annotation_add(engine: &Engine, document: DocumentId, page: u64) -> Duration {
    let start = Instant::now();
    block_on(engine.add_annotation(document, page, square(), "Square".to_owned())).unwrap();
    let elapsed = start.elapsed();
    block_on(engine.undo(document)).unwrap();
    elapsed
}

/// A square moved by a fractional amount, once it is there; only the move is timed.
fn annotation_move(engine: &Engine, document: DocumentId, page: u64) -> Duration {
    let made =
        block_on(engine.add_annotation(document, page, square(), "Square".to_owned())).unwrap();
    let change = AnnotationChange {
        rect: Some([72.37, 72.61, 172.37, 172.61]),
        ..AnnotationChange::default()
    };
    let start = Instant::now();
    block_on(engine.update_annotation(document, made.handle, change, "Move".to_owned())).unwrap();
    let elapsed = start.elapsed();
    block_on(engine.undo(document)).unwrap();
    block_on(engine.undo(document)).unwrap();
    elapsed
}

fn square() -> NewAnnotation {
    NewAnnotation {
        kind: AnnotationKind::Square,
        rect: [72.0, 72.0, 172.0, 172.0],
        points: Vec::new(),
        color: [0.85, 0.22, 0.17],
        stroke: 2.0,
        opacity: 1.0,
        contents: String::new(),
        author: "Bench".to_owned(),
        font_size: 12.0,
        arrow: false,
        label: String::new(),
        meta: None,
        tilt: 0.0,
        icon: None,
        comb: None,
    }
}

fn main() {
    let Some(library) = std::env::var_os("FERMAN_PDFIUM_PATH").filter(|path| !path.is_empty())
    else {
        eprintln!("edit_and_save: FERMAN_PDFIUM_PATH is not set, so nothing is measured");
        return;
    };
    let Ok(long) = std::fs::read(corpus("long-500")) else {
        eprintln!(
            "edit_and_save: long-500.pdf is missing (tools/corpus generate makes it), so nothing is measured"
        );
        return;
    };
    let engine = Engine::start(EngineConfig {
        pdfium: PdfiumLibrary::Path(library.into()),
    });
    let dir = std::env::temp_dir().join(format!("ferman-bench-edit-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();

    // Copies: nothing here touches the corpus.
    let open_copy = |name: &str, page: u32, edit: (&str, &str)| {
        let path = dir.join(format!("{name}.pdf"));
        std::fs::copy(corpus(name), &path).unwrap();
        let opened = block_on(engine.open(path, None)).unwrap();
        let size = opened.pages[page as usize].size;
        target(&engine, opened.id, page, size, edit)
    };
    let kira = open_copy("kira-tr", 0, ("18.500", "19.500"));
    let handbook = open_copy("long-500", 250, ("the", "he"));
    let source = dir.join("long-20mb.pdf");
    let bytes = padded(&long);
    assert!(bytes.len() >= SAVE_FILE_BYTES);
    std::fs::write(&source, &bytes).unwrap();

    let mut criterion = Criterion::default()
        .sample_size(10)
        .warm_up_time(Duration::from_secs(1))
        .measurement_time(Duration::from_secs(3))
        .configure_from_args();
    let mut timed = |name: &str, run: &dyn Fn() -> Duration| {
        criterion.bench_function(name, |bench| {
            bench.iter_custom(|iters| (0..iters).map(|_| run()).sum());
        });
    };
    timed("edit_to_render/kira_tr", &|| edit_to_render(&engine, &kira));
    timed("edit_to_render/long_500", &|| {
        edit_to_render(&engine, &handbook)
    });
    let marked = block_on(engine.open(dir.join("long-500.pdf"), None)).unwrap();
    let marked_page = marked.pages[250].handle;
    timed("annotation/add/long_500", &|| {
        annotation_add(&engine, marked.id, marked_page)
    });
    timed("annotation/move/long_500", &|| {
        annotation_move(&engine, marked.id, marked_page)
    });
    // The bundled fonts, for the value its field's font cannot draw.
    block_on(engine.set_font_settings(FontSettings {
        bundled_dir: Some(PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../app/assets/fonts")),
        ..FontSettings::default()
    }))
    .unwrap();
    let form_path = dir.join("long-500-form.pdf");
    with_form(&long, &form_path);
    let form = block_on(engine.open(form_path, None)).unwrap();
    timed("form/set/long_500", &|| {
        field_set(&engine, form.id, "Mehmet Kaya")
    });
    timed("form/set_bundled/long_500", &|| {
        field_set(&engine, form.id, "Ayşe Yılmaz")
    });
    timed("save/20_mb_500_pages_10_edits", &|| {
        save(&engine, &source, &dir)
    });
    criterion.final_summary();

    if std::env::var_os("FERMAN_BENCH_GUARD").is_some() {
        for (name, edit) in [("kira-tr", &kira), ("long-500", &handbook)] {
            let mut times: Vec<Duration> = (0..20).map(|_| edit_to_render(&engine, edit)).collect();
            times.sort_unstable();
            let (median, slowest) = (times[times.len() / 2], times[times.len() - 1]);
            eprintln!(
                "edit_and_save guard: {name}, 20 edits, median {median:?}, slowest {slowest:?} ({} tiles)",
                tiles(edit).len()
            );
            // The median: one scheduler stall on a shared runner says nothing about the code.
            assert!(
                median < EDIT_TO_RENDER * CI_CALIBRATION,
                "edits of {name} took {median:?} (median), over {CI_CALIBRATION} x {EDIT_TO_RENDER:?}"
            );
        }
        let elapsed = save(&engine, &source, &dir);
        eprintln!("edit_and_save guard: the save of 20 MB and 10 edits in {elapsed:?}");
        assert!(
            elapsed < SAVE * CI_CALIBRATION,
            "the save took {elapsed:?}, over {CI_CALIBRATION} x {SAVE:?}"
        );
    }
    block_on(engine.close_discarding(kira.document)).unwrap();
    block_on(engine.close_discarding(handbook.document)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}
