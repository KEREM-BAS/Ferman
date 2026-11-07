//! Flatten, hide all, the comment summary and links through the facade (M4 plan, W2): what each
//! page draws compared before and after with PDFium.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::sync::mpsc;
use std::time::Duration;

use ferman_api::facade::{
    AnnotationInfo, AnnotationKind, DocumentId, Engine, EngineConfig, ErrorKind, FontSettings,
    JobEvent, JobId, JobResult, JobSink, LinkLook, LinkTarget, NewAnnotation, NewLink,
    NewLinkDestination, OpGate, OpenedDocument, PageInfo, PageRaster, PdfiumLibrary, RefusedLink,
    SummaryFormat, SummaryLabels, SummaryLayout, SummaryOptions, SummarySort, block_on, compare,
    device_region,
};
use ferman_core::DocumentOp;

const DPI: u32 = 110;
const FILE: &str = "annots-other-producer";

fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
        let engine = Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Path(library.into()),
        });
        block_on(engine.set_font_settings(FontSettings {
            bundled_dir: Some(
                PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../app/assets/fonts"),
            ),
            ..FontSettings::default()
        }))
        .unwrap();
        engine
    })
}

fn folder(test: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("ferman-flatten-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

fn copy(test: &str, name: &str) -> (PathBuf, PathBuf) {
    let dir = folder(test);
    let path = dir.join(format!("{name}.pdf"));
    std::fs::copy(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(format!("{name}.pdf")),
        &path,
    )
    .unwrap();
    (dir, path)
}

fn open(path: &Path) -> OpenedDocument {
    block_on(engine().open(path.to_path_buf(), None)).unwrap()
}

fn draw(doc: DocumentId, pages: &[PageInfo], index: usize) -> PageRaster {
    let page = u32::try_from(index).unwrap();
    block_on(engine().render_page(doc, page, pages[index].size, DPI)).unwrap()
}

fn list(doc: DocumentId) -> Vec<AnnotationInfo> {
    block_on(engine().annotations(doc)).unwrap().annotations
}

struct Events(mpsc::Sender<JobEvent>);

impl JobSink for Events {
    fn deliver(&mut self, event: JobEvent) {
        let _ = self.0.send(event);
    }
}

fn sink() -> (Box<dyn JobSink>, mpsc::Receiver<JobEvent>) {
    let (sender, events) = mpsc::channel();
    (Box::new(Events(sender)), events)
}

fn ended(events: &mpsc::Receiver<JobEvent>) -> JobResult {
    loop {
        let event = events.recv_timeout(Duration::from_secs(120)).unwrap();
        if let Some(result) = event.result {
            return result;
        }
    }
}

fn flatten(doc: DocumentId, handles: Vec<u64>, copy: Option<PathBuf>) -> (JobId, JobResult) {
    let (sink, events) = sink();
    let job = engine()
        .flatten_annotations_job(doc, handles, copy, None, "Flatten".to_owned(), sink)
        .unwrap();
    (job, ended(&events))
}

fn draft(kind: AnnotationKind, rect: [f32; 4], points: Vec<Vec<[f32; 2]>>) -> NewAnnotation {
    NewAnnotation {
        kind,
        rect,
        points,
        color: [0.85, 0.22, 0.17],
        stroke: 2.0,
        opacity: 1.0,
        contents: String::new(),
        author: "Ayşe Yılmaz".to_owned(),
        font_size: 12.0,
        arrow: false,
        label: String::new(),
        meta: None,
        tilt: 0.0,
        icon: None,
    }
}

/// One annotation of every kind Ferman creates: each has its appearance.
fn every_kind() -> Vec<NewAnnotation> {
    let quad = |x: f32, y: f32| vec![[x, y], [x + 120.0, y], [x, y + 14.0], [x + 120.0, y + 14.0]];
    let mut text_box = draft(
        AnnotationKind::FreeText,
        [90.0, 100.0, 300.0, 170.0],
        vec![],
    );
    text_box.contents = "İŞĞÜ öçı Türkçe kutu".to_owned();
    let mut arabic = draft(
        AnnotationKind::FreeText,
        [90.0, 180.0, 300.0, 240.0],
        vec![],
    );
    arabic.contents = "هذا تعليق باللغة العربية 2026".to_owned();
    let mut callout = draft(
        AnnotationKind::Callout,
        [150.0, 250.0, 330.0, 300.0],
        vec![vec![[60.0, 340.0], [100.0, 275.0], [150.0, 275.0]]],
    );
    callout.contents = "Bu madde değerlendirilmeli.".to_owned();
    let mut stamp = draft(AnnotationKind::Stamp, [320.0, 340.0, 480.0, 390.0], vec![]);
    stamp.label = "İMZALANDI".to_owned();
    stamp.tilt = -3.0;
    stamp.font_size = 18.0;
    stamp.opacity = 0.9;
    let mut arrow = draft(
        AnnotationKind::Line,
        [0.0; 4],
        vec![vec![[60.0, 420.0], [240.0, 480.0]]],
    );
    arrow.arrow = true;
    let mut highlight = draft(AnnotationKind::Highlight, [0.0; 4], vec![quad(60.0, 520.0)]);
    highlight.color = [1.0, 0.82, 0.2];
    highlight.opacity = 0.6;
    vec![
        highlight,
        draft(
            AnnotationKind::Underline,
            [0.0; 4],
            vec![quad(200.0, 520.0)],
        ),
        draft(
            AnnotationKind::StrikeOut,
            [0.0; 4],
            vec![quad(340.0, 520.0)],
        ),
        draft(AnnotationKind::Note, [500.0, 60.0, 524.0, 84.0], vec![]),
        text_box,
        arabic,
        callout,
        draft(
            AnnotationKind::Ink,
            [0.0; 4],
            vec![vec![[300.0, 420.0], [340.0, 470.0], [380.0, 430.0]]],
        ),
        draft(AnnotationKind::Square, [60.0, 500.0, 160.0, 560.0], vec![]),
        draft(AnnotationKind::Circle, [180.0, 500.0, 280.0, 560.0], vec![]),
        arrow,
        draft(
            AnnotationKind::Polygon,
            [0.0; 4],
            vec![vec![
                [300.0, 500.0],
                [400.0, 510.0],
                [380.0, 570.0],
                [310.0, 560.0],
            ]],
        ),
        stamp,
    ]
}

fn flatten_and_apply(doc: DocumentId, handles: Vec<u64>) {
    let (job, result) = flatten(doc, handles, None);
    assert!(matches!(result, JobResult::Done { .. }), "{result:?}");
    block_on(engine().apply_job_change(job)).unwrap();
}

fn same(before: &PageRaster, after: &PageRaster, context: &str) {
    let diff = compare(before, after, None, 0).unwrap();
    assert_eq!(diff.differing, 0, "{context}: {diff:?}");
}

/// Every kind drawn on page `index` of a file, flattened: the page draws the same, undo brings
/// them back, and the saved file opens as it showed.
fn every_kind_on(test: &str, name: &str, index: usize, exact: bool) {
    let (dir, path) = copy(test, name);
    let original = std::fs::read(&path).unwrap();
    let opened = open(&path);
    let (doc, pages) = (opened.id, opened.pages.clone());
    let page = pages[index].handle;
    let foreign: Vec<u64> = list(doc).iter().map(|a| a.handle).collect();
    let mut made = Vec::new();
    for new in every_kind() {
        let what = format!("{:?}", new.kind);
        made.push(
            block_on(engine().add_annotation(doc, page, new, what))
                .unwrap()
                .handle,
        );
    }
    let edges: Vec<[f32; 4]> = list(doc)
        .iter()
        .filter(|a| {
            made.contains(&a.handle)
                && matches!(a.kind, AnnotationKind::Note | AnnotationKind::FreeText)
        })
        .map(|a| a.rect)
        .collect();
    let before = draw(doc, &pages, index);
    flatten_and_apply(doc, made.clone());
    let after = draw(doc, &pages, index);
    if exact {
        same(&before, &after, "flattened");
    } else {
        // Filed in BACKLOG: on a turned page a few antialiased pixels at the edge of a text box
        // and inside a note's icon differ, by up to 40 of 255; all the rest is the same.
        let scale = f64::from(DPI) / 72.0;
        let region = device_region(&edges, scale).unwrap();
        let diff = compare(&before, &after, Some(region), 2).unwrap();
        assert!(diff.passed() && diff.differing < 500, "flattened: {diff:?}");
    }
    assert!(list(doc).iter().all(|a| !made.contains(&a.handle)));
    assert!(
        foreign
            .iter()
            .all(|f| list(doc).iter().any(|a| a.handle == *f))
    );

    block_on(engine().undo(doc)).unwrap();
    assert!(list(doc).iter().any(|a| a.handle == made[0]));
    same(&before, &draw(doc, &pages, index), "undone");
    block_on(engine().redo(doc)).unwrap();

    let saved = dir.join("saved.pdf");
    block_on(engine().save_copy(doc, saved.clone(), None)).unwrap();
    assert!(std::fs::read(&saved).unwrap().starts_with(&original));
    let again = open(&saved);
    same(&after, &draw(again.id, &again.pages, index), "reopened");
    assert!(list(again.id).iter().all(|a| !made.contains(&a.handle)));
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn every_kind_flattens_the_same_on_a_plain_page() {
    every_kind_on("kinds-plain", "kira-tr", 0, true);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn every_kind_flattens_the_same_on_a_turned_page() {
    every_kind_on("kinds-turned", FILE, 1, false);
}

/// Another program's annotations: with an appearance each draws the same. Without one PDFium makes
/// up its own (a no-AP Line or Polygon it does not draw at all), so Ferman's differs inside the
/// annotation's box (BACKLOG). A no-AP text box can vanish in PDFium once another form's font loads
/// differently, so the callout's box stays out of the comparison.
#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn another_program_s_annotations_flatten() {
    let (dir, path) = copy("foreign", FILE);
    let opened = open(&path);
    let (doc, pages) = (opened.id, opened.pages.clone());
    let page = pages[0].handle;
    let all: Vec<AnnotationInfo> = list(doc).into_iter().filter(|a| a.page == page).collect();
    let callout = all
        .iter()
        .find(|a| a.kind == AnnotationKind::Callout)
        .unwrap()
        .rect;
    let scale = f64::from(DPI) / 72.0;
    for annotation in &all {
        let before = draw(doc, &pages, 0);
        flatten_and_apply(doc, vec![annotation.handle]);
        let after = draw(doc, &pages, 0);
        let gone = list(doc).iter().all(|a| a.handle != annotation.handle);
        let region = device_region(&[annotation.rect, callout], scale).unwrap();
        let diff = compare(&before, &after, Some(region), 2).unwrap();
        assert!(diff.passed(), "{}: {diff:?}", annotation.subtype);
        if gone {
            block_on(engine().undo(doc)).unwrap();
        } else {
            // A type Ferman has no drawing for, with none of its own: it stays as it came.
            assert_eq!(annotation.subtype, "Caret");
        }
    }
    // The ones with an appearance, the text boxes' font aside, draw exactly the same.
    let drawn = |subtype: &str| all.iter().find(|a| a.subtype == subtype).unwrap().handle;
    for subtype in ["Highlight", "StrikeOut", "Square", "Polygon"] {
        let before = draw(doc, &pages, 0);
        flatten_and_apply(doc, vec![drawn(subtype)]);
        same(&before, &draw(doc, &pages, 0), subtype);
        block_on(engine().undo(doc)).unwrap();
    }
    // All of them: only the type with nothing to draw is left.
    flatten_and_apply(doc, all.iter().map(|a| a.handle).collect());
    let left: Vec<String> = list(doc)
        .into_iter()
        .filter(|a| a.page == page)
        .map(|a| a.subtype)
        .collect();
    assert_eq!(left, ["Caret"]);
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn the_copy_comes_first_and_a_failed_one_changes_nothing() {
    let (dir, path) = copy("copy", FILE);
    let opened = open(&path);
    let doc = opened.id;
    let all: Vec<u64> = list(doc).iter().map(|a| a.handle).collect();

    // A folder that is not there: the job fails, and no change waits.
    let missing = dir.join("no-such-folder").join("copy.pdf");
    let (job, result) = flatten(doc, all.clone(), Some(missing));
    assert!(matches!(result, JobResult::Failed(_)), "{result:?}");
    assert!(block_on(engine().apply_job_change(job)).is_err());
    assert_eq!(list(doc).len(), all.len());

    // A file that is there is never replaced.
    let taken = dir.join("taken.pdf");
    std::fs::write(&taken, b"mine").unwrap();
    let (taken_sink, _) = sink();
    let err = engine()
        .flatten_annotations_job(
            doc,
            all.clone(),
            Some(taken.clone()),
            None,
            String::new(),
            taken_sink,
        )
        .err()
        .unwrap();
    assert_eq!(err.kind, ErrorKind::InvalidInput);
    assert_eq!(std::fs::read(&taken).unwrap(), b"mine");

    // The copy keeps the comments; the document loses them only at the change.
    let kept = dir.join("kept.pdf");
    let (job, result) = flatten(doc, all.clone(), Some(kept.clone()));
    assert!(matches!(result, JobResult::Done { .. }), "{result:?}");
    assert_eq!(list(doc).len(), all.len());
    block_on(engine().apply_job_change(job)).unwrap();
    assert!(list(doc).len() < all.len());
    let copy = open(&kept);
    assert_eq!(list(copy.id).len(), all.len());
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn flattening_a_certified_file_asks_even_where_comments_keep_it() {
    let (dir, path) = copy("signed", "cert-p3");
    let doc = open(&path).id;
    // A comment keeps this signature; what flattening takes, the edit gate, does not.
    for (op, gate) in [
        (DocumentOp::Comment, OpGate::KeepsSignatures),
        (DocumentOp::EditText, OpGate::BreaksSignatures),
    ] {
        assert_eq!(
            block_on(engine().op_gate(doc, op, Vec::new())).unwrap(),
            gate
        );
    }
    let (job, result) = flatten(doc, Vec::new(), None);
    assert!(matches!(result, JobResult::Done { .. }), "{result:?}");
    let err = block_on(engine().apply_job_change(job)).unwrap_err();
    assert_eq!(err.kind, ErrorKind::ConfirmationRequired);
    // The change waits for the answer.
    block_on(engine().confirm_edit_signed(doc)).unwrap();
    block_on(engine().apply_job_change(job)).unwrap();
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn flattening_takes_the_edit_gate_where_comments_are_allowed() {
    let (dir, path) = copy("comments-only", "kira-tr-comments-only");
    let opened = open(&path);
    let doc = opened.id;
    let mark = block_on(engine().add_annotation(
        doc,
        opened.pages[0].handle,
        draft(AnnotationKind::Square, [60.0, 60.0, 160.0, 160.0], vec![]),
        "Square".to_owned(),
    ))
    .unwrap();
    let (sink, _events) = sink();
    let err = engine()
        .flatten_annotations_job(
            doc,
            vec![mark.handle],
            None,
            None,
            "Flatten".to_owned(),
            sink,
        )
        .err()
        .unwrap();
    assert_eq!(err.kind, ErrorKind::NotEditable);
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn hide_all_renders_without_them_and_is_never_saved() {
    let (dir, path) = copy("hide", FILE);
    let original = std::fs::read(&path).unwrap();
    let opened = open(&path);
    let (doc, pages) = (opened.id, opened.pages.clone());
    let shown = draw(doc, &pages, 0);

    block_on(engine().show_comments(doc, false)).unwrap();
    let hidden = draw(doc, &pages, 0);
    assert!(compare(&shown, &hidden, None, 0).unwrap().differing > 0);

    // Saving does not write the appendix: the same file, no revision, whatever is shown.
    let saved = dir.join("saved.pdf");
    block_on(engine().save_copy(doc, saved.clone(), None)).unwrap();
    assert_eq!(std::fs::read(&saved).unwrap(), original);

    // It holds through a commit, whose new comment hides too.
    let page = pages[0].handle;
    let new = draft(AnnotationKind::Square, [60.0, 100.0, 160.0, 160.0], vec![]);
    let made = block_on(engine().add_annotation(doc, page, new, String::new())).unwrap();
    same(&hidden, &draw(doc, &pages, 0), "a commit while hidden");
    block_on(engine().delete_annotation(doc, made.handle, String::new())).unwrap();

    // The page draws as if each were gone: only the private type, which is no markup, stays.
    let (dir2, other) = copy("hide-gone", FILE);
    let second = open(&other);
    for annotation in list(second.id) {
        if annotation.page == page && annotation.subtype != "ACME_Mark" {
            let _ =
                block_on(engine().delete_annotation(second.id, annotation.handle, String::new()));
        }
    }
    // Direct and thread members: delete takes replies with their top, so some already went.
    same(&hidden, &draw(second.id, &second.pages, 0), "as if deleted");

    block_on(engine().show_comments(doc, true)).unwrap();
    same(&shown, &draw(doc, &pages, 0), "shown again");
    let _ = std::fs::remove_dir_all(dir);
    let _ = std::fs::remove_dir_all(dir2);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn hide_all_leaves_form_fields() {
    let (dir, path) = copy("hide-form", "form-aks1-tr");
    let opened = open(&path);
    let (doc, pages) = (opened.id, opened.pages.clone());
    let shown = draw(doc, &pages, 0);
    block_on(engine().show_comments(doc, false)).unwrap();
    same(&shown, &draw(doc, &pages, 0), "a form");
    let _ = std::fs::remove_dir_all(dir);
}

fn options() -> SummaryOptions {
    SummaryOptions {
        open: true,
        resolved: true,
        replies: true,
        empty_pages: false,
        sort: SummarySort::Page,
        labels: SummaryLabels {
            page: "Sayfa {n}".to_owned(),
            columns: [
                "Sayfa",
                "Tür",
                "Yazar",
                "Tarih",
                "Metin",
                "Yanıtlar",
                "Durum",
            ]
            .map(str::to_owned)
            .to_vec(),
            kinds: vec![(AnnotationKind::Note, "Not".to_owned())],
            open: "Açık".to_owned(),
            resolved: "Çözüldü".to_owned(),
            no_comments: "Yorum yok".to_owned(),
            date_pattern: "dd.MM.yyyy HH:mm".to_owned(),
        },
    }
}

fn summary(doc: DocumentId, format: SummaryFormat, options: SummaryOptions, out: PathBuf) {
    let (sink, events) = sink();
    engine()
        .comment_summary_job(doc, format, options, out, None, sink)
        .unwrap();
    let result = ended(&events);
    assert!(matches!(result, JobResult::Done { .. }), "{result:?}");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_summary_sets_a_long_comment_whole() {
    let (dir, path) = copy("summary-long", "kira-tr");
    let opened = open(&path);
    let doc = opened.id;
    let mut long = "kelime ".repeat(10_000);
    long.push_str("SONKELIME");
    assert!(long.len() > 64 * 1024);
    let mut note = draft(AnnotationKind::Note, [40.0, 40.0, 64.0, 64.0], vec![]);
    note.contents = long;
    block_on(engine().add_annotation(doc, opened.pages[0].handle, note, String::new())).unwrap();
    let out = dir.join("long.pdf");
    summary(
        doc,
        SummaryFormat::Pdf(SummaryLayout::CommentsOnly, 595.0, 842.0),
        options(),
        out.clone(),
    );
    let pdf = open(&out);
    let last = u32::try_from(pdf.pages.len() - 1).unwrap();
    let blocks = block_on(engine().text_blocks(pdf.id, last)).unwrap().blocks;
    assert!(
        blocks
            .iter()
            .flat_map(|block| &block.lines)
            .any(|line| line.text.contains("SONKELIME"))
    );
    block_on(engine().close(pdf.id)).unwrap();
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_summary_of_a_hundred_comments() {
    const COMMENTS: usize = 100;
    let (dir, path) = copy("summary", "kira-tr");
    let opened = open(&path);
    let doc = opened.id;
    let page = opened.pages[0].handle;
    let original_pages = opened.pages.len();
    let texts = [
        "Ödeme günü İSTANBUL",
        "=HYPERLINK(\"http://evil\")",
        "تعليق عربي",
        "@mention",
        "düz, \"tırnak\"",
    ];
    for at in 0..COMMENTS {
        #[allow(clippy::cast_precision_loss)]
        let x = 40.0 + (at % 20) as f32 * 25.0;
        #[allow(clippy::cast_precision_loss)]
        let y = 40.0 + (at / 20) as f32 * 30.0;
        let mut note = draft(AnnotationKind::Note, [x, y, x + 24.0, y + 24.0], vec![]);
        note.contents = format!("{} {at}", texts[at % texts.len()]);
        block_on(engine().add_annotation(doc, page, note, String::new())).unwrap();
    }

    let csv_path = dir.join("summary.csv");
    summary(doc, SummaryFormat::Csv, options(), csv_path.clone());
    let csv = std::fs::read_to_string(&csv_path).unwrap();
    assert!(csv.starts_with("\u{FEFF}\"Sayfa\",\"Tür\""));
    assert_eq!(csv.matches("\r\n").count(), COMMENTS + 1);
    assert_eq!(csv.matches("\"Not\"").count(), COMMENTS);
    assert!(csv.contains("\"'=HYPERLINK(\"\"http://evil\"\") 1\""));
    assert!(csv.contains("\"'@mention 3\""));
    assert!(csv.contains("تعليق عربي"));
    assert!(!csv.contains(",\"=") && !csv.contains(",\"@"));

    // An output that exists is refused, and stays.
    let (taken_sink, _) = sink();
    let err = engine()
        .comment_summary_job(
            doc,
            SummaryFormat::Csv,
            options(),
            csv_path.clone(),
            None,
            taken_sink,
        )
        .err()
        .unwrap();
    assert_eq!(err.kind, ErrorKind::InvalidInput);

    const A4: (f32, f32) = (595.28, 841.89);
    for (name, layout) in [
        ("comments-only", SummaryLayout::CommentsOnly),
        ("page-and-comments", SummaryLayout::PageAndComments),
        ("page-then-list", SummaryLayout::PageThenList),
    ] {
        let out = dir.join(format!("{name}.pdf"));
        summary(
            doc,
            SummaryFormat::Pdf(layout, A4.0, A4.1),
            options(),
            out.clone(),
        );
        let pdf = open(&out);
        assert!(pdf.pages.len() >= 2, "{name}: {} pages", pdf.pages.len());
        let mut text = String::new();
        for at in 0..pdf.pages.len() {
            let page = u32::try_from(at).unwrap();
            for block in block_on(engine().text_blocks(pdf.id, page)).unwrap().blocks {
                for line in block.lines {
                    text.push_str(&line.text);
                    text.push('\n');
                }
            }
        }
        assert!(text.contains("Sayfa 1"), "{name}");
        assert!(text.contains("Ödeme günü İSTANBUL 0"), "{name}: {text}");
        assert!(text.contains("99"), "{name}");
        block_on(engine().close(pdf.id)).unwrap();
    }

    // Open comments left out: a summary with none says so instead of failing.
    let none = SummaryOptions {
        open: false,
        resolved: false,
        ..options()
    };
    let out = dir.join("none.pdf");
    summary(
        doc,
        SummaryFormat::Pdf(SummaryLayout::CommentsOnly, 595.0, 842.0),
        none,
        out.clone(),
    );
    assert_eq!(open(&out).pages.len(), 1);
    assert_eq!(opened.pages.len(), original_pages);
    let _ = std::fs::remove_dir_all(dir);
}

/// A two-page PDF with `annots` as the first page's `/Annots`, its objects from 10 on as `extra`.
fn pdf_with_links(annots: &str, extra: &[&str]) -> Vec<u8> {
    pdf_turned(0, annots, extra)
}

/// [`pdf_with_links`] with the first page turned by `rotate`.
fn pdf_turned(rotate: u32, annots: &str, extra: &[&str]) -> Vec<u8> {
    let mut objects = vec![
        "<</Type/Catalog/Pages 2 0 R/Names<</Dests<</Names[(named) [4 0 R /Fit]]>>>>>>".to_owned(),
        "<</Type/Pages/Kids[3 0 R 4 0 R]/Count 2>>".to_owned(),
        format!(
            "<</Type/Page/Parent 2 0 R/MediaBox[0 0 400 400]/Rotate {rotate}/Annots[{annots}]>>"
        ),
        "<</Type/Page/Parent 2 0 R/MediaBox[0 0 400 400]>>".to_owned(),
    ];
    objects.extend(extra.iter().map(|object| (*object).to_owned()));
    let mut out = b"%PDF-1.7\n".to_vec();
    let mut offsets = Vec::new();
    for (at, object) in objects.iter().enumerate() {
        offsets.push(out.len());
        out.extend(format!("{} 0 obj\n{object}\nendobj\n", at + 1).as_bytes());
    }
    let xref = out.len();
    out.extend(format!("xref\n0 {}\n0000000000 65535 f \n", objects.len() + 1).as_bytes());
    for offset in offsets {
        out.extend(format!("{offset:010} 00000 n \n").as_bytes());
    }
    out.extend(
        format!(
            "trailer\n<</Size {}/Root 1 0 R>>\nstartxref\n{xref}\n%%EOF\n",
            objects.len() + 1
        )
        .as_bytes(),
    );
    out
}

fn link(y: u32, rest: &str) -> String {
    format!(
        "<</Subtype/Link/Rect[10 {y} 100 {}]/Border[0 0 0]{rest}>>",
        y + 20
    )
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn links_read_as_what_they_are_and_only_web_and_mail_are_offered() {
    let dir = folder("links");
    let path = dir.join("links.pdf");
    let annots = [
        link(370, "/A<</S/URI/URI(https://example.org/a)>>"),
        link(340, "/A<</S/URI/URI(mailto:a@example.org)>>"),
        link(310, "/A<</S/URI/URI(javascript:alert\\(1\\))>>"),
        link(280, "/A<</S/URI/URI(file:///etc/passwd)>>"),
        link(250, "/A<</S/JavaScript/JS(app.alert\\(1\\))>>"),
        link(220, "/A<</S/Launch/F(calc.exe)>>"),
        link(190, "/A<</S/GoToR/F(other.pdf)/D[0/Fit]>>"),
        link(160, "/A<</S/Hide/T(x)/Private(keep me)>>"),
        link(130, "/A<</S/GoTo/D[4 0 R/Fit]>>"),
        link(100, "/Dest(named)"),
        link(70, "/Dest[9/Fit]"),
    ]
    .concat();
    std::fs::write(&path, pdf_with_links(&annots, &[])).unwrap();
    let opened = open(&path);
    let doc = opened.id;
    let second = opened.pages[1].handle;
    let links = block_on(engine().links(doc)).unwrap().links;
    let targets: Vec<LinkTarget> = links.iter().map(|link| link.target.clone()).collect();
    assert_eq!(
        targets,
        [
            LinkTarget::Web("https://example.org/a".to_owned()),
            LinkTarget::Mail("mailto:a@example.org".to_owned()),
            LinkTarget::Refused(RefusedLink::Script, "javascript:alert(1)".to_owned()),
            LinkTarget::Refused(RefusedLink::File, "file:///etc/passwd".to_owned()),
            LinkTarget::Refused(RefusedLink::Script, String::new()),
            LinkTarget::Refused(RefusedLink::Launch, "calc.exe".to_owned()),
            LinkTarget::Refused(RefusedLink::File, "other.pdf".to_owned()),
            LinkTarget::Refused(RefusedLink::Action, "Hide".to_owned()),
            LinkTarget::Page(second),
            LinkTarget::Page(second),
            LinkTarget::Broken { wanted: Some(10) },
        ]
    );

    // A click lands on the link there, in displayed points, and follows nothing.
    let first = opened.pages[0].handle;
    let hit = block_on(engine().link_at(doc, first, 50.0, 400.0 - 375.0)).unwrap();
    assert_eq!(
        hit.unwrap().target,
        LinkTarget::Web("https://example.org/a".to_owned())
    );
    assert!(
        block_on(engine().link_at(doc, first, 300.0, 200.0))
            .unwrap()
            .is_none()
    );

    // Nothing but web, mail or a page can be written.
    for refused in ["javascript:alert(1)", "file:///etc/passwd", "ftp://x"] {
        let new = NewLink {
            rect: [10.0, 10.0, 50.0, 30.0],
            quads: Vec::new(),
            target: NewLinkDestination::Web(refused.to_owned()),
            look: LinkLook::Invisible,
            color: [0.0, 0.0, 1.0],
        };
        let err = block_on(engine().add_link(doc, first, new, String::new())).unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput, "{refused}");
    }

    // A change of its box keeps an action Ferman does not know.
    let unknown = links[7].handle;
    block_on(engine().update_link(
        doc,
        unknown,
        Some([10.0, 240.0, 120.0, 260.0]),
        None,
        None,
        None,
        String::new(),
    ))
    .unwrap();
    let saved = dir.join("saved.pdf");
    block_on(engine().save_copy(doc, saved.clone(), None)).unwrap();
    let bytes = std::fs::read(&saved).unwrap();
    let text = String::from_utf8_lossy(&bytes);
    assert!(text.matches("Hide").count() >= 2, "/S /Hide written again");
    let reopened = open(&saved);
    let kept = block_on(engine().links(reopened.id)).unwrap().links;
    assert_eq!(
        kept[7].target,
        LinkTarget::Refused(RefusedLink::Action, "Hide".to_owned())
    );
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_page_link_survives_a_page_move_and_undo_takes_each_change_back() {
    let (dir, path) = copy("goto", "kira-tr");
    let opened = open(&path);
    let (doc, pages) = (opened.id, opened.pages.clone());
    assert!(pages.len() >= 2);
    let (first, last) = (pages[0].handle, pages[pages.len() - 1].handle);
    let plain = draw(doc, &pages, 0);

    let new = NewLink {
        rect: [60.0, 60.0, 200.0, 90.0],
        quads: Vec::new(),
        target: NewLinkDestination::Page(last),
        look: LinkLook::Invisible,
        color: [0.0, 0.0, 1.0],
    };
    let made = block_on(engine().add_link(doc, first, new, String::new())).unwrap();
    // An invisible link draws nothing.
    same(&plain, &draw(doc, &pages, 0), "invisible");
    let target = |doc| {
        block_on(engine().links(doc))
            .unwrap()
            .links
            .iter()
            .find(|link| link.handle == made.handle)
            .map(|link| link.target.clone())
    };
    assert_eq!(target(doc), Some(LinkTarget::Page(last)));

    // Move the target page to the front: the link still goes to that page.
    block_on(engine().move_pages(doc, vec![last], Some(first), "Move".to_owned())).unwrap();
    assert_eq!(target(doc), Some(LinkTarget::Page(last)));
    block_on(engine().undo(doc)).unwrap();

    // A thin box and an underline show in PDFium, and only in the link's box.
    for look in [LinkLook::Box, LinkLook::Underline] {
        block_on(engine().update_link(
            doc,
            made.handle,
            None,
            None,
            Some(look),
            None,
            String::new(),
        ))
        .unwrap();
        let scale = f64::from(DPI) / 72.0;
        let region = device_region(&[[60.0, 60.0, 200.0, 90.0]], scale).unwrap();
        let diff = compare(&plain, &draw(doc, &pages, 0), Some(region), 2).unwrap();
        assert!(diff.passed() && diff.differing > 0, "{look:?}: {diff:?}");
    }
    block_on(engine().update_link(
        doc,
        made.handle,
        None,
        Some(NewLinkDestination::Web("https://example.org".to_owned())),
        None,
        None,
        String::new(),
    ))
    .unwrap();
    assert_eq!(
        target(doc),
        Some(LinkTarget::Web("https://example.org".to_owned()))
    );
    block_on(engine().undo(doc)).unwrap();
    assert_eq!(target(doc), Some(LinkTarget::Page(last)));

    block_on(engine().delete_link(doc, made.handle, String::new())).unwrap();
    assert_eq!(target(doc), None);
    block_on(engine().undo(doc)).unwrap();
    assert_eq!(target(doc), Some(LinkTarget::Page(last)));
    let _ = std::fs::remove_dir_all(dir);
}

/// A form of 100 by 100 with a mark in one corner, which shows which way it was turned.
const CORNER_FORM: &str = "<</Type/XObject/Subtype/Form/BBox[0 0 100 100]/Length 39>>stream\n\
    0 0 1 rg 0 0 100 100 re f 1 0 0 rg 0 0 30 30 re f\nendstream";

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn annotations_written_directly_in_annots_all_flatten() {
    let dir = folder("direct");
    let path = dir.join("direct.pdf");
    let square = |x: u32, rest: &str| {
        format!(
            "<</Subtype/Square/Rect[{x} 20 {} 110]/C[1 0 0]/BS<</W 2>>{rest}>>",
            x + 90
        )
    };
    // One Ferman has to draw before each of the two that draw themselves.
    let annots = [
        square(10, ""),
        square(110, "/AP<</N 5 0 R>>"),
        square(210, ""),
        square(310, "/AP<</N 5 0 R>>"),
    ]
    .join(" ");
    std::fs::write(&path, pdf_turned(0, &annots, &[CORNER_FORM])).unwrap();
    let opened = open(&path);
    let (doc, pages) = (opened.id, opened.pages.clone());
    let all = list(doc);
    assert_eq!(all.len(), 4);
    let drawn: Vec<[f32; 4]> = [all[1].rect, all[3].rect].to_vec();
    let before = draw(doc, &pages, 0);
    flatten_and_apply(doc, all.iter().map(|a| a.handle).collect());
    assert!(list(doc).is_empty());
    // Those that had an appearance draw the same; only the others may differ.
    let scale = f64::from(DPI) / 72.0;
    let others = device_region(&[all[0].rect, all[2].rect], scale).unwrap();
    let diff = compare(&before, &draw(doc, &pages, 0), Some(others), 2).unwrap();
    assert!(diff.passed(), "{drawn:?}: {diff:?}");
    block_on(engine().undo(doc)).unwrap();
    assert_eq!(list(doc).len(), 4);
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn no_rotate_stays_upright_when_flattened() {
    for rotate in [0, 90, 180, 270] {
        let dir = folder(&format!("no-rotate-{rotate}"));
        let path = dir.join("turned.pdf");
        let annots = "<</Subtype/Stamp/F 16/Rect[150 150 250 250]/AP<</N 5 0 R>>>>";
        std::fs::write(&path, pdf_turned(rotate, annots, &[CORNER_FORM])).unwrap();
        let opened = open(&path);
        let (doc, pages) = (opened.id, opened.pages.clone());
        let before = draw(doc, &pages, 0);
        flatten_and_apply(doc, list(doc).iter().map(|a| a.handle).collect());
        assert!(list(doc).is_empty());
        // Filed in BACKLOG: on a turned page only the box's antialiased edge differs. Not turned
        // back, the page differs by some 47,000 pixels.
        let diff = compare(&before, &draw(doc, &pages, 0), None, 0).unwrap();
        assert!(
            if rotate == 0 {
                diff.differing == 0
            } else {
                diff.differing < 1000
            },
            "turned {rotate}: {diff:?}"
        );
        let _ = std::fs::remove_dir_all(dir);
    }
}
