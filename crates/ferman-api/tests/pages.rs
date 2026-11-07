//! Page operations through the facade (M4 plan, W1): move, delete, rotate and duplicate, undone,
//! redone, saved and reopened on `tez-tr` and on `pages-tree`, whose pages inherit what they draw
//! with. Pages keep their pixels, labels and bookmarks, and nothing else changes a pixel.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh). Each saved file is also
//! written to `FERMAN_SAVED_DIR` when it is set, for CI's `qpdf --check`.
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use ferman_api::facade::{
    DocumentId, Engine, EngineConfig, ErrorKind, LabelRange, LabelStyle, Margins, OpGate,
    OpenedDocument, OutlineItem, PageFit, PageInfo, PageRaster, Password, PdfiumLibrary, block_on,
    compare,
};
use ferman_core::DocumentOp;

fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
        Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Path(library.into()),
        })
    })
}

fn corpus(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"))
}

/// A copy of corpus file `name` in a folder of `test`'s own.
fn copy(test: &str, name: &str) -> (PathBuf, PathBuf) {
    let dir = std::env::temp_dir().join(format!("ferman-pages-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!("{name}.pdf"));
    std::fs::copy(corpus(name), &path).unwrap();
    (dir, path)
}

fn open(path: &Path) -> OpenedDocument {
    block_on(engine().open(path.to_path_buf(), None)).unwrap()
}

/// Page `index` as a document that lists `pages` draws it.
fn draw(doc: DocumentId, pages: &[PageInfo], index: usize, dpi: u32) -> PageRaster {
    let page = u32::try_from(index).unwrap();
    block_on(engine().render_page(doc, page, pages[index].size, dpi)).unwrap()
}

fn same(a: &PageRaster, b: &PageRaster) -> bool {
    compare(a, b, None, 0).is_some_and(|diff| diff.differing == 0)
}

/// Each page's handle, in order.
fn handles(pages: &[PageInfo]) -> Vec<u64> {
    pages.iter().map(|page| page.handle).collect()
}

/// The titles and target pages of `items`, children after their parent, targets by page handle.
fn outline(items: &[OutlineItem], pages: &[PageInfo]) -> Vec<(String, Option<u64>)> {
    let mut out = Vec::new();
    for item in items {
        let target = item
            .page
            .map(|page| pages[usize::try_from(page).unwrap()].handle);
        out.push((item.title.clone(), target));
        out.extend(outline(&item.children, pages));
    }
    out
}

/// What the app holds of a document.
#[derive(Debug, Clone, PartialEq)]
struct Listing {
    pages: Vec<PageInfo>,
    outline: Vec<(String, Option<u64>)>,
}

impl Listing {
    fn of(opened: &OpenedDocument) -> Self {
        Self {
            pages: opened.pages.clone(),
            outline: outline(&opened.outline, &opened.pages),
        }
    }

    /// `self` after the revision `info`, which must have changed the structure.
    fn after(info: &ferman_api::facade::RevisionInfo) -> Self {
        let structure = info.structure.as_ref().expect("the structure changed");
        Self {
            pages: structure.pages.clone(),
            outline: outline(&structure.outline, &structure.pages),
        }
    }

    fn label(&self, handle: u64) -> Option<String> {
        self.pages
            .iter()
            .find(|page| page.handle == handle)
            .and_then(|page| page.label.clone())
    }
}

/// Rasters of `pages` of `doc` by handle.
fn rasters(doc: DocumentId, pages: &[PageInfo], dpi: u32) -> HashMap<u64, PageRaster> {
    (0..pages.len())
        .map(|index| (pages[index].handle, draw(doc, pages, index, dpi)))
        .collect()
}

/// Move, delete, rotate and duplicate on file `name`: the acceptance of ROADMAP §8.
fn organize(test: &str, name: &str, dpi: u32) {
    let (dir, path) = copy(test, name);
    let opened = open(&path);
    let doc = opened.id;
    let first = Listing::of(&opened);
    let before = rasters(doc, &first.pages, dpi);
    let ids = handles(&first.pages);
    let count = ids.len();
    let (turned, moved, deleted, copied) = (ids[0], [ids[1], ids[3]], ids[2], ids[4]);
    let (last, untouched) = (ids[count - 1], ids[5]);

    // One step each. The moved pages go to the end, the others close up.
    let step1 =
        block_on(engine().move_pages(doc, moved.to_vec(), None, "Moved".to_owned())).unwrap();
    let after_move = Listing::after(&step1);
    let order = handles(&after_move.pages);
    assert_eq!(order[count - 2..], moved);
    assert_eq!(order[..4], [ids[0], ids[2], ids[4], ids[5]]);
    let step2 = block_on(engine().delete_pages(doc, vec![deleted], "Deleted".to_owned())).unwrap();
    let after_delete = Listing::after(&step2);
    assert_eq!(after_delete.pages.len(), count - 1);
    assert!(!handles(&after_delete.pages).contains(&deleted));
    let step3 =
        block_on(engine().rotate_pages(doc, vec![turned], 1, "Rotated".to_owned())).unwrap();
    let after_rotate = Listing::after(&step3);
    let rotation = |pages: &[PageInfo]| {
        pages
            .iter()
            .find(|page| page.handle == turned)
            .map(|page| page.rotation)
    };
    assert_eq!(
        rotation(&after_rotate.pages),
        rotation(&after_delete.pages).map(|degrees| (degrees + 90) % 360)
    );
    let step4 =
        block_on(engine().duplicate_pages(doc, vec![copied], "Duplicated".to_owned())).unwrap();
    let last_step = Listing::after(&step4);
    assert_eq!(last_step.pages.len(), count);
    assert_eq!(step4.current, 4);

    // Labels stay on their pages, a copy continues the range before it; bookmarks follow, and one
    // to the deleted page has no target any more.
    for handle in ids.iter().filter(|handle| **handle != deleted) {
        assert_eq!(
            last_step.label(*handle),
            first.label(*handle),
            "{name} {handle}"
        );
    }
    for (index, (title, target)) in first.outline.iter().enumerate() {
        let (now, new) = &last_step.outline[index];
        assert_eq!(now, title);
        let wanted = target.filter(|target| *target != deleted);
        assert_eq!(*new, wanted, "{name}: {title}");
    }

    // Undo walks back through the same lists, and every page draws as it did.
    let check = |listing: &Listing| {
        let pages = &listing.pages;
        let saw = rasters(doc, pages, dpi);
        for handle in handles(pages) {
            if handle != turned && ids.contains(&handle) {
                assert!(same(&saw[&handle], &before[&handle]), "{name} {handle}");
            }
        }
    };
    check(&last_step);
    let undone = block_on(engine().undo(doc)).unwrap();
    assert_eq!(Listing::after(&undone), after_rotate);
    let undone = block_on(engine().undo(doc)).unwrap();
    assert_eq!(Listing::after(&undone), after_delete);
    let undone = block_on(engine().undo(doc)).unwrap();
    assert_eq!(Listing::after(&undone), after_move);
    let undone = block_on(engine().undo(doc)).unwrap();
    assert_eq!(Listing::after(&undone), first);
    let saw = rasters(doc, &first.pages, dpi);
    for handle in &ids {
        assert!(same(&saw[handle], &before[handle]), "{name} {handle}");
    }
    for expected in [&after_move, &after_delete, &after_rotate, &last_step] {
        let redone = block_on(engine().redo(doc)).unwrap();
        assert_eq!(&Listing::after(&redone), expected);
    }

    // A turned page keeps its pixels turned: only its own raster changes.
    let turned_index = handles(&last_step.pages)
        .iter()
        .position(|handle| *handle == turned)
        .unwrap();
    assert_ne!(
        last_step.pages[turned_index].size, first.pages[0].size,
        "{name}"
    );

    // Saved and reopened, the file says the same, and the original is its prefix.
    block_on(engine().save(doc, None)).unwrap();
    keep(&format!("{name}-organized"), &path);
    let saved = std::fs::read(&path).unwrap();
    assert!(saved.starts_with(&std::fs::read(corpus(name)).unwrap()));
    block_on(engine().close(doc)).unwrap();
    let again = open(&path);
    let listing = Listing::of(&again);
    assert_eq!(handles(&listing.pages), handles(&last_step.pages));
    for (title_target, now) in last_step.outline.iter().zip(&listing.outline) {
        assert_eq!(title_target, now);
    }
    for handle in ids.iter().filter(|handle| **handle != deleted) {
        assert_eq!(listing.label(*handle), first.label(*handle), "{name}");
    }
    let saw = rasters(again.id, &listing.pages, dpi);
    for handle in [moved[0], moved[1], copied, last, untouched] {
        assert!(same(&saw[&handle], &before[&handle]), "{name} {handle}");
    }
    // The copy draws what its original draws.
    let copy = handles(&listing.pages)
        .into_iter()
        .find(|handle| !ids.contains(handle))
        .unwrap();
    assert!(same(&saw[&copy], &before[&copied]), "{name}");
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

/// Saves a copy in `FERMAN_SAVED_DIR` when it is set.
fn keep(name: &str, file: &Path) {
    if let Some(out) = std::env::var_os("FERMAN_SAVED_DIR").filter(|dir| !dir.is_empty()) {
        let out = PathBuf::from(out);
        std::fs::create_dir_all(&out).unwrap();
        std::fs::copy(file, out.join(format!("{name}.pdf"))).unwrap();
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn organizing_a_thesis_keeps_its_pages_labels_and_bookmarks() {
    organize("tez", "tez-tr", 72);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn organizing_a_tree_with_inherited_attributes_keeps_its_pixels() {
    organize("tree", "pages-tree", 150);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_page_moved_between_nodes_keeps_pixels_at_every_resolution() {
    let (dir, path) = copy("nodes", "pages-tree");
    let opened = open(&path);
    let doc = opened.id;
    let ids = handles(&opened.pages);
    let found = block_on(engine().white_margins(doc, ids.clone())).unwrap();
    assert!(found.iter().all(Option::is_some), "every page draws");
    let before: Vec<_> = [72, 150, 300]
        .into_iter()
        .map(|dpi| rasters(doc, &opened.pages, dpi))
        .collect();
    // Out of the turned node, and a plain page into it.
    let info =
        block_on(engine().move_pages(doc, vec![ids[0], ids[5]], Some(ids[1]), "Moved".to_owned()))
            .unwrap();
    let pages = info.structure.unwrap().pages;
    assert_eq!(handles(&pages)[..3], [ids[0], ids[5], ids[1]]);
    for (dpi, before) in [72, 150, 300].into_iter().zip(&before) {
        let now = rasters(doc, &pages, dpi);
        for handle in &ids {
            assert!(same(&now[handle], &before[handle]), "{handle} at {dpi}");
        }
    }
    // Reversing the whole document moves pages across every node.
    let info = block_on(engine().move_pages(
        doc,
        vec![ids[2], ids[3], ids[4]],
        Some(ids[0]),
        "Moved".to_owned(),
    ))
    .unwrap();
    let pages = info.structure.unwrap().pages;
    let info = block_on(engine().save(doc, None)).map(|_| ());
    info.unwrap();
    block_on(engine().close(doc)).unwrap();
    let again = open(&path);
    assert_eq!(handles(&again.pages), handles(&pages));
    let now = rasters(again.id, &again.pages, 150);
    for handle in &ids {
        assert!(same(&now[handle], &before[1][handle]), "{handle}");
    }
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_step_of_pages_reverts_alone_and_revert_all_goes_home() {
    let (dir, path) = copy("revert", "tez-tr");
    let opened = open(&path);
    let doc = opened.id;
    let ids = handles(&opened.pages);
    block_on(engine().rotate_pages(doc, vec![ids[9]], 1, "Rotated".to_owned())).unwrap();
    block_on(engine().delete_pages(doc, vec![ids[3], ids[4]], "Deleted".to_owned())).unwrap();
    block_on(engine().move_pages(doc, vec![ids[20]], Some(ids[0]), "Moved".to_owned())).unwrap();

    // The turn touched its page alone: it goes, the others stay.
    let reverted = block_on(engine().revert(doc, 0, false, "Reverted".to_owned())).unwrap();
    assert!(reverted.reverted, "{:?}", reverted.dependents);
    let pages = reverted.revision.structure.unwrap().pages;
    assert_eq!(pages.len(), ids.len() - 2);
    assert_eq!(pages[0].handle, ids[20]);
    let turned = pages.iter().find(|page| page.handle == ids[9]).unwrap();
    assert_eq!(turned.size, opened.pages[9].size);

    // The history names the pages of each step, by handle.
    let history = block_on(engine().history(doc)).unwrap();
    assert_eq!(history.steps[1].pages, [ids[3], ids[4]]);

    // The delete and the move share /Kids: one depends on the other.
    let refused = block_on(engine().revert(doc, 1, false, "Reverted".to_owned())).unwrap();
    assert!(!refused.reverted);
    assert_eq!(refused.dependents, [2]);
    let both = block_on(engine().revert(doc, 1, true, "Reverted".to_owned())).unwrap();
    assert!(both.reverted);
    assert_eq!(
        handles(&both.revision.structure.unwrap().pages),
        ids,
        "back in order"
    );

    let info = block_on(engine().revert_all(doc, "Reverted all".to_owned())).unwrap();
    assert!(info.current > 0);
    let bytes_before = std::fs::read(&path).unwrap();
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    let again = open(&path);
    assert_eq!(handles(&again.pages), ids);
    assert!(std::fs::read(&path).unwrap().starts_with(&bytes_before));
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_blank_page_goes_where_it_is_asked_and_keeps_the_range() {
    let (dir, path) = copy("blank", "tez-tr");
    let opened = open(&path);
    let doc = opened.id;
    let ids = handles(&opened.pages);
    let info = block_on(engine().insert_blank_pages(
        doc,
        Some(ids[8]),
        2,
        (300.0, 400.0),
        "Inserted".to_owned(),
    ))
    .unwrap();
    let pages = info.structure.unwrap().pages;
    assert_eq!(pages.len(), ids.len() + 2);
    assert_eq!(pages[9].size.width, 300.0);
    assert_eq!(pages[9].label.as_deref(), Some("2"));
    assert_eq!(pages[10].label.as_deref(), Some("3"));
    // The page that followed keeps its own label.
    assert_eq!(pages[11].handle, ids[9]);
    assert_eq!(pages[11].label, opened.pages[9].label);
    let white = draw(doc, &pages, 9, 72);
    assert!(white.pixels.iter().all(|channel| *channel == 255));
    assert_eq!(
        block_on(engine().white_margins(doc, vec![pages[9].handle])).unwrap(),
        [None]
    );
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    let again = open(&path);
    assert_eq!(again.pages.len(), ids.len() + 2);
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

/// `inner` is `outer` with `(left, top)` pixels cut off.
fn is_cut_of(inner: &PageRaster, outer: &PageRaster, (left, top): (usize, usize)) -> bool {
    let row = |raster: &PageRaster, y: usize, x: usize, width: usize| {
        let stride = raster.width as usize * 4;
        raster.pixels[y * stride + x * 4..y * stride + (x + width) * 4].to_vec()
    };
    let width = inner.width as usize;
    (0..inner.height as usize).all(|y| row(inner, y, 0, width) == row(outer, y + top, left, width))
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_crop_hides_and_white_margins_find_the_content() {
    let (dir, path) = copy("crop", "kira-tr");
    let opened = open(&path);
    let doc = opened.id;
    let ids = handles(&opened.pages);
    let before = draw(doc, &opened.pages, 0, 72);
    let found = block_on(engine().white_margins(doc, vec![ids[0]])).unwrap()[0].unwrap();
    assert!(
        found.top > 10.0 && found.left > 10.0 && found.right > 10.0,
        "{found:?}"
    );
    assert!(found.top < 200.0 && found.left < 200.0, "{found:?}");

    let margins = Margins {
        top: 20.0,
        bottom: 30.0,
        left: 10.0,
        right: 40.0,
    };
    let info = block_on(engine().crop_pages(
        doc,
        vec![(ids[0], margins), (ids[1], found)],
        "Cropped".to_owned(),
    ))
    .unwrap();
    assert_eq!(info.changed_pages.as_deref(), Some(&[0, 1][..]));
    let pages = info.structure.unwrap().pages;
    assert_eq!(pages[0].size.width, opened.pages[0].size.width - 50.0);
    assert_eq!(pages[0].size.height, opened.pages[0].size.height - 50.0);
    assert!(is_cut_of(&draw(doc, &pages, 0, 72), &before, (10, 20)));
    // Hidden, not removed: the third page is as it was, and undo gives it all back.
    let undone = block_on(engine().undo(doc)).unwrap();
    assert_eq!(
        undone.structure.unwrap().pages[0].size,
        opened.pages[0].size
    );
    assert!(same(&draw(doc, &opened.pages, 0, 72), &before));
    let redone = block_on(engine().redo(doc)).unwrap();
    let pages = redone.structure.unwrap().pages;
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    let again = open(&path);
    assert_eq!(again.pages[0].size, pages[0].size);
    assert!(is_cut_of(
        &draw(again.id, &again.pages, 0, 72),
        &before,
        (10, 20)
    ));
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_new_page_size_centres_or_scales() {
    let (dir, path) = copy("size", "kira-tr");
    let opened = open(&path);
    let doc = opened.id;
    let ids = handles(&opened.pages);
    let size = opened.pages[0].size;
    let before = rasters(doc, &opened.pages, 72);

    // Centred on a page 100 points larger each way.
    let bigger = (size.width + 100.0, size.height + 100.0);
    let info = block_on(engine().set_page_size(
        doc,
        vec![ids[0]],
        bigger,
        PageFit::Centre,
        "Resized".to_owned(),
    ))
    .unwrap();
    let pages = info.structure.unwrap().pages;
    assert_eq!((pages[0].size.width, pages[0].size.height), bigger);
    assert!(is_cut_of(
        &before[&ids[0]],
        &draw(doc, &pages, 0, 72),
        (50, 50)
    ));
    assert!(same(&draw(doc, &pages, 1, 72), &before[&ids[1]]));

    // Scaled to half: all the content is there, in half the room.
    let half = (size.width / 2.0, size.height / 2.0);
    let info = block_on(engine().set_page_size(
        doc,
        vec![ids[1]],
        half,
        PageFit::Scale,
        "Resized".to_owned(),
    ))
    .unwrap();
    let pages = info.structure.unwrap().pages;
    assert_eq!((pages[1].size.width, pages[1].size.height), half);
    let full = block_on(engine().white_margins(doc, vec![ids[2]])).unwrap()[0];
    assert!(full.is_some());
    let scaled = block_on(engine().white_margins(doc, vec![ids[1]])).unwrap()[0].unwrap();
    assert!(scaled.left > 5.0, "{scaled:?}");
    assert!(same(&draw(doc, &pages, 2, 72), &before[&ids[2]]));

    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    let again = open(&path);
    assert_eq!(
        (again.pages[1].size.width, again.pages[1].size.height),
        half
    );
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn label_ranges_are_read_and_set_as_one_step() {
    let (dir, path) = copy("labels", "pages-tree");
    let opened = open(&path);
    let doc = opened.id;
    let ranges = block_on(engine().page_label_ranges(doc)).unwrap();
    assert_eq!(ranges.len(), 3);
    assert_eq!(ranges[2].prefix, "Ek-");
    let info = block_on(engine().set_page_labels(
        doc,
        vec![
            LabelRange {
                start: 0,
                style: LabelStyle::RomanUpper,
                prefix: String::new(),
                first: 4,
            },
            LabelRange {
                start: 3,
                style: LabelStyle::None,
                prefix: "Şekil".to_owned(),
                first: 1,
            },
        ],
        "Labels".to_owned(),
    ))
    .unwrap();
    let pages = info.structure.unwrap().pages;
    assert_eq!(pages[0].label.as_deref(), Some("IV"));
    assert_eq!(pages[2].label.as_deref(), Some("VI"));
    assert_eq!(pages[5].label.as_deref(), Some("Şekil"));
    let undone = block_on(engine().undo(doc)).unwrap();
    assert_eq!(
        undone.structure.unwrap().pages[0].label.as_deref(),
        Some("i")
    );
    let refused = block_on(engine().set_page_labels(
        doc,
        vec![LabelRange {
            start: 9,
            style: LabelStyle::Decimal,
            prefix: String::new(),
            first: 1,
        }],
        "Labels".to_owned(),
    ))
    .unwrap_err();
    assert_eq!(refused.kind, ErrorKind::InvalidInput);
    block_on(engine().close(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn the_gates_stop_each_operation() {
    // A document whose permissions forbid assembling.
    let restricted = block_on(engine().open(corpus("kira-tr-restricted"), None)).unwrap();
    let doc = restricted.id;
    let ids = handles(&restricted.pages);
    assert_eq!(
        block_on(engine().op_gate(doc, DocumentOp::Organize, Vec::new())).unwrap(),
        OpGate::Forbidden
    );
    let results = [
        block_on(engine().rotate_pages(doc, vec![ids[0]], 1, "x".to_owned())),
        block_on(engine().delete_pages(doc, vec![ids[0]], "x".to_owned())),
        block_on(engine().move_pages(doc, vec![ids[0]], None, "x".to_owned())),
        block_on(engine().duplicate_pages(doc, vec![ids[0]], "x".to_owned())),
        block_on(engine().insert_blank_pages(doc, None, 1, (100.0, 100.0), "x".to_owned())),
        block_on(engine().set_page_size(
            doc,
            vec![ids[0]],
            (100.0, 100.0),
            PageFit::Centre,
            "x".to_owned(),
        )),
        block_on(engine().crop_pages(doc, vec![(ids[0], Margins::default())], "x".to_owned())),
        block_on(engine().set_page_labels(doc, Vec::new(), "x".to_owned())),
    ];
    for result in results {
        assert_eq!(result.unwrap_err().kind, ErrorKind::NotEditable);
    }
    block_on(engine().close(doc)).unwrap();

    // A signed document waits for its confirmation, and the gate says why.
    let signed = block_on(engine().open(corpus("kira-tr-signed"), None)).unwrap();
    let doc = signed.id;
    let ids = handles(&signed.pages);
    assert_eq!(
        block_on(engine().op_gate(doc, DocumentOp::Organize, Vec::new())).unwrap(),
        OpGate::BreaksSignatures
    );
    let refused =
        block_on(engine().delete_pages(doc, vec![ids[0]], "Deleted".to_owned())).unwrap_err();
    assert_eq!(refused.kind, ErrorKind::ConfirmationRequired);
    assert!(block_on(engine().history(doc)).unwrap().steps.is_empty());
    block_on(engine().confirm_edit_signed(doc)).unwrap();
    let info = block_on(engine().delete_pages(doc, vec![ids[0]], "Deleted".to_owned())).unwrap();
    assert_eq!(info.current, 1);
    block_on(engine().close_discarding(doc)).unwrap();

    // What cannot apply is refused, and leaves no step.
    let (dir, path) = copy("gates", "kira-tr");
    let opened = open(&path);
    let doc = opened.id;
    let ids = handles(&opened.pages);
    let all = block_on(engine().delete_pages(doc, ids.clone(), "x".to_owned())).unwrap_err();
    assert_eq!(all.kind, ErrorKind::InvalidInput);
    let gone = block_on(engine().rotate_pages(doc, vec![12345], 1, "x".to_owned())).unwrap_err();
    assert_eq!(gone.kind, ErrorKind::InvalidInput);
    assert!(block_on(engine().history(doc)).unwrap().steps.is_empty());
    block_on(engine().close(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn an_encrypted_document_keeps_its_protection_through_page_operations() {
    let (dir, path) = copy("encrypted", "payslip-aes256");
    let password = || Some(Password::new("Eylül2026maaşı".to_owned()));
    let opened = block_on(engine().open(path.clone(), password())).unwrap();
    let doc = opened.id;
    let ids = handles(&opened.pages);
    let before = draw(doc, &opened.pages, 0, 72);
    block_on(engine().duplicate_pages(doc, vec![ids[0]], "Duplicated".to_owned())).unwrap();
    block_on(engine().insert_blank_pages(doc, None, 1, (100.0, 100.0), "Inserted".to_owned()))
        .unwrap();
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    assert_eq!(
        block_on(engine().open(path.clone(), None))
            .unwrap_err()
            .kind,
        ErrorKind::PasswordRequired
    );
    let again = block_on(engine().open(path, password())).unwrap();
    assert_eq!(again.pages.len(), ids.len() + 2);
    assert!(same(&draw(again.id, &again.pages, 1, 72), &before));
    assert!(same(&draw(again.id, &again.pages, 2, 72), &before));
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

/// A classic PDF with `objects`, the first of them number 1, its catalog.
fn pdf_with(objects: &[String]) -> Vec<u8> {
    let mut out = b"%PDF-1.7\n".to_vec();
    let mut offsets = Vec::new();
    for (index, object) in objects.iter().enumerate() {
        offsets.push(out.len());
        out.extend(format!("{} 0 obj\n{object}\nendobj\n", index + 1).bytes());
    }
    let xref = out.len();
    out.extend(format!("xref\n0 {}\n0000000000 65535 f \n", objects.len() + 1).bytes());
    for offset in offsets {
        out.extend(format!("{offset:010} 00000 n \n").bytes());
    }
    out.extend(
        format!(
            "trailer\n<</Size {}/Root 1 0 R>>\nstartxref\n{xref}\n%%EOF\n",
            objects.len() + 1
        )
        .bytes(),
    );
    out
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_hostile_page_tree_does_not_hang() {
    let page = |parent: u32| format!("<</Type/Page/Parent {parent} 0 R/MediaBox[0 0 200 300]>>");
    let catalog = "<</Type/Catalog/Pages 2 0 R>>".to_owned();
    let trees: [(&str, Vec<String>); 4] = [
        (
            "count",
            vec![
                catalog.clone(),
                "<</Type/Pages/Count 2000000000/Kids[3 0 R 4 0 R 5 0 R]>>".to_owned(),
                page(2),
                page(2),
                page(2),
            ],
        ),
        (
            "cycle",
            vec![
                catalog.clone(),
                "<</Type/Pages/Count 3/Kids[3 0 R 6 0 R 4 0 R 5 0 R]>>".to_owned(),
                page(2),
                page(2),
                page(2),
                "<</Type/Pages/Parent 2 0 R/Count 1/Kids[2 0 R]>>".to_owned(),
            ],
        ),
        (
            "shared",
            vec![
                catalog.clone(),
                "<</Type/Pages/Count 4/Kids[6 0 R 6 0 R 5 0 R]>>".to_owned(),
                page(6),
                page(6),
                page(2),
                "<</Type/Pages/Parent 2 0 R/Count 2/Kids[3 0 R 4 0 R]>>".to_owned(),
            ],
        ),
        (
            "negative",
            vec![
                catalog,
                "<</Type/Pages/Count -3/Kids[3 0 R 4 0 R 5 0 R]>>".to_owned(),
                page(4),
                page(99),
                page(2),
            ],
        ),
    ];
    let dir = std::env::temp_dir().join(format!("ferman-pages-hostile-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let mut edited = 0;
    for (name, objects) in trees {
        let path = dir.join(format!("{name}.pdf"));
        std::fs::write(&path, pdf_with(&objects)).unwrap();
        let Ok(opened) = block_on(engine().open(path.clone(), None)) else {
            continue;
        };
        let doc = opened.id;
        let ids = handles(&opened.pages);
        // A file whose readers disagree opens read-only: refused, which is no hang either.
        match block_on(engine().delete_pages(doc, vec![ids[0]], "Deleted".to_owned())) {
            Ok(info) => {
                let pages = info.structure.unwrap().pages;
                let count = pages.len();
                let last = pages[count - 1].handle;
                block_on(engine().move_pages(doc, vec![last], Some(pages[0].handle), "M".into()))
                    .unwrap();
                block_on(engine().save(doc, None)).unwrap();
                block_on(engine().close(doc)).unwrap();
                let again = open(&path);
                assert_eq!(again.pages.len(), count, "{name}");
                assert_eq!(again.pages[0].handle, last, "{name}");
                assert!(again.read_only.is_none(), "{name}");
                edited += 1;
                block_on(engine().close(again.id)).unwrap();
            }
            Err(err) => {
                assert_eq!(err.kind, ErrorKind::NotEditable, "{name}");
                block_on(engine().close(doc)).unwrap();
            }
        }
    }
    assert!(edited > 0, "at least one tree is repaired, not refused");
    std::fs::remove_dir_all(&dir).unwrap();
}
