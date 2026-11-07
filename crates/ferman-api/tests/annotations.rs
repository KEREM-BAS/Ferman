//! Annotations through the facade (M4 plan, W2), on `annots-other-producer`: every type read, every
//! type added and edited, saved, reopened and rendered. Pixels change only inside the annotation's
//! rectangle, an untouched annotation's bytes stay in the original's prefix, only the touched page
//! gets a new render key, and undo, redo and revert bring back what was.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::{OnceLock, mpsc};

use ferman_api::facade::{
    AnnotationChange, AnnotationInfo, AnnotationKind, DocumentId, Engine, EngineConfig, ErrorKind,
    FontSettings, NewAnnotation, OpGate, OpenedDocument, PageInfo, PageRaster, PdfiumLibrary,
    SearchEvent, SearchOptions, SearchSink, block_on, compare, device_region,
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

fn corpus(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"))
}

fn copy(test: &str, name: &str) -> (PathBuf, PathBuf) {
    let dir = std::env::temp_dir().join(format!("ferman-notes-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!("{name}.pdf"));
    std::fs::copy(corpus(name), &path).unwrap();
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

fn find(doc: DocumentId, handle: u64) -> AnnotationInfo {
    list(doc)
        .into_iter()
        .find(|annotation| annotation.handle == handle)
        .unwrap()
}

/// Asserts `before` and `after` differ, and only inside `rect` (displayed points); a pixel of
/// anti-aliasing on the edge counts as inside.
fn only_inside(before: &PageRaster, after: &PageRaster, rect: [f32; 4], context: &str) {
    let scale = f64::from(DPI) / 72.0;
    let region = device_region(&[rect], scale).unwrap();
    let diff = compare(before, after, Some(region), 2).unwrap();
    assert!(diff.passed(), "{context}: {diff:?} outside {rect:?}");
    assert!(diff.differing > 0, "{context}: nothing was drawn");
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

/// One new annotation of every kind Ferman creates, placed in the page's displayed space.
fn drafts() -> Vec<(&'static str, NewAnnotation)> {
    let quad = |x: f32, y: f32| vec![[x, y], [x + 120.0, y], [x, y + 14.0], [x + 120.0, y + 14.0]];
    let mut text_box = draft(
        AnnotationKind::FreeText,
        [90.0, 100.0, 300.0, 170.0],
        vec![],
    );
    text_box.contents =
        "İŞĞÜ öçı Türkçe kutu; uzun bir satır kendiliğinden kırılır ve kutuda kalır.".to_owned();
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
    stamp.meta = Some("Ayşe Yılmaz · 06.11.2026".to_owned());
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
    highlight.contents = "Bak @Av. D. Aksoy".to_owned();
    vec![
        ("highlight", highlight),
        (
            "underline",
            draft(
                AnnotationKind::Underline,
                [0.0; 4],
                vec![quad(200.0, 520.0)],
            ),
        ),
        (
            "strike out",
            draft(
                AnnotationKind::StrikeOut,
                [0.0; 4],
                vec![quad(340.0, 520.0)],
            ),
        ),
        (
            "note",
            draft(AnnotationKind::Note, [500.0, 60.0, 524.0, 84.0], vec![]),
        ),
        ("text box", text_box),
        ("arabic text box", arabic),
        ("callout", callout),
        (
            "ink",
            draft(
                AnnotationKind::Ink,
                [0.0; 4],
                vec![
                    vec![[300.0, 420.0], [340.0, 470.0], [380.0, 430.0]],
                    vec![[390.0, 430.0], [430.0, 470.0]],
                ],
            ),
        ),
        (
            "square",
            draft(AnnotationKind::Square, [60.0, 500.0, 160.0, 560.0], vec![]),
        ),
        (
            "circle",
            draft(AnnotationKind::Circle, [180.0, 500.0, 280.0, 560.0], vec![]),
        ),
        ("arrow", arrow),
        (
            "line",
            draft(
                AnnotationKind::Line,
                [0.0; 4],
                vec![vec![[60.0, 575.0], [240.0, 575.0]]],
            ),
        ),
        (
            "polygon",
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
        ),
        ("stamp", stamp),
    ]
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn every_type_of_another_producer_is_read() {
    let opened = open(&corpus(FILE));
    let all = block_on(engine().annotations(opened.id)).unwrap();
    assert!(!all.truncated);
    let count = |kind| all.annotations.iter().filter(|a| a.kind == kind).count();
    for (kind, wanted) in [
        (AnnotationKind::Highlight, 3),
        (AnnotationKind::Squiggly, 1),
        (AnnotationKind::Underline, 1),
        (AnnotationKind::StrikeOut, 1),
        (AnnotationKind::Note, 4),
        (AnnotationKind::FreeText, 2),
        (AnnotationKind::Callout, 1),
        (AnnotationKind::Ink, 2),
        (AnnotationKind::Square, 2),
        (AnnotationKind::Circle, 1),
        (AnnotationKind::Line, 2),
        (AnnotationKind::Polygon, 1),
        (AnnotationKind::Stamp, 1),
        (AnnotationKind::Other, 2),
    ] {
        assert_eq!(count(kind), wanted, "{kind:?}");
    }
    assert_eq!(all.people, ["Av. D. Aksoy"]);
    let note = all
        .annotations
        .iter()
        .find(|a| a.kind == AnnotationKind::Note && a.rich)
        .unwrap();
    assert!(note.resolved, "the state reply says Completed");
    assert_eq!(note.resolved_by.as_deref(), Some("Av. D. Aksoy"));
    assert!(note.contents.as_deref().unwrap().contains("TBK"));
    let reply = all
        .annotations
        .iter()
        .find(|a| a.contents.as_deref() == Some("Uygun, 37.000 TL."))
        .unwrap();
    assert_eq!(reply.replies_to, Some(note.handle));
    let line = all
        .annotations
        .iter()
        .find(|a| a.kind == AnnotationKind::Line && a.arrow)
        .unwrap();
    assert_eq!(line.points[0].len(), 2);
    let date = note.modified.unwrap();
    assert_eq!((date.year, date.offset_minutes), (2026, Some(180)));
    // On the turned page a box's geometry is as the reader sees it: inside the turned page.
    let turned = &opened.pages[1];
    for annotation in all.annotations.iter().filter(|a| a.page == turned.handle) {
        let [left, top, right, bottom] = annotation.rect;
        assert!(left >= 0.0 && top >= 0.0, "{annotation:?}");
        assert!(
            right <= turned.size.width && bottom <= turned.size.height,
            "{annotation:?}"
        );
    }
    block_on(engine().close(opened.id)).unwrap();
}

/// Adds and edits every kind on page `index`, saves, reopens and compares.
fn every_type_on(test: &str, index: usize) {
    let (dir, path) = copy(test, FILE);
    let original = std::fs::read(&path).unwrap();
    let opened = open(&path);
    let doc = opened.id;
    let page = opened.pages[index].handle;
    let pages = opened.pages.clone();
    let untouched: Vec<AnnotationInfo> = list(doc);
    let mut handles = Vec::new();
    for (what, new) in drafts() {
        let before = draw(doc, &pages, index);
        let made = block_on(engine().add_annotation(doc, page, new, what.to_owned())).unwrap();
        // Only this page gets a new key.
        assert_eq!(
            made.revision.changed_pages,
            Some(vec![u32::try_from(index).unwrap()]),
            "{what}"
        );
        let after = draw(doc, &pages, index);
        let rect = find(doc, made.handle).rect;
        only_inside(&before, &after, rect, what);
        // The other page does not change.
        handles.push((what, made.handle));
    }
    for (what, handle) in &handles {
        let annotation = find(doc, *handle);
        let [l, t, r, b] = annotation.rect;
        let before = draw(doc, &pages, index);
        let change = match annotation.kind {
            // A stamp's drawing is not made again: it takes a new box.
            AnnotationKind::Stamp => AnnotationChange {
                rect: Some([l - 10.0, t - 10.0, r - 10.0, b - 10.0]),
                ..AnnotationChange::default()
            },
            AnnotationKind::FreeText | AnnotationKind::Callout => AnnotationChange {
                contents: Some("Yeni metin: İĞŞ".to_owned()),
                color: Some([0.16, 0.3, 0.68]),
                ..AnnotationChange::default()
            },
            _ => AnnotationChange {
                color: Some([0.16, 0.3, 0.68]),
                ..AnnotationChange::default()
            },
        };
        let moved = change.rect;
        let info =
            block_on(engine().update_annotation(doc, *handle, change, format!("Edit {what}")))
                .unwrap();
        assert_eq!(info.handle, *handle, "{what} keeps its identity");
        let after = draw(doc, &pages, index);
        let area = moved.map_or(annotation.rect, |rect| {
            [
                l.min(rect[0]),
                t.min(rect[1]),
                r.max(rect[2]),
                b.max(rect[3]),
            ]
        });
        only_inside(&before, &after, area, &format!("edit of {what}"));
    }
    let final_pixels: Vec<PageRaster> = (0..pages.len()).map(|i| draw(doc, &pages, i)).collect();
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();

    // The file grew; what was there is an exact prefix, and no untouched annotation is in the
    // update.
    let saved = std::fs::read(&path).unwrap();
    assert_eq!(saved[..original.len()], original[..]);
    let update = &saved[original.len()..];
    for needle in [&b"7f3c-"[..], b"ACME_Data", b"xfa:APIVersion"] {
        assert!(
            !update.windows(needle.len()).any(|w| w == needle),
            "{}",
            String::from_utf8_lossy(needle)
        );
    }

    // Text is set in the bundled Plex faces: Sans for Latin, Arabic for Arabic, SemiBold for a
    // stamp.
    for needle in [
        &b"+IBMPlexSans"[..],
        b"+IBMPlexSansArabic",
        b"+IBMPlexSans-SmBld",
    ] {
        assert!(
            update.windows(needle.len()).any(|w| w == needle),
            "{}",
            String::from_utf8_lossy(needle)
        );
    }

    let again = open(&path);
    let reopened = list(again.id);
    assert_eq!(reopened.len(), untouched.len() + handles.len());
    for before in &untouched {
        assert_eq!(
            reopened.iter().find(|a| a.handle == before.handle),
            Some(before)
        );
    }
    for (i, before) in final_pixels.iter().enumerate() {
        let after = draw(again.id, &again.pages, i);
        let diff = compare(before, &after, None, 0).unwrap();
        assert_eq!(diff.differing, 0, "page {i} reopens as it was drawn");
    }
    // The text and author read back, a mention with them.
    let (_, highlight) = handles[0];
    let found = reopened.iter().find(|a| a.handle == highlight).unwrap();
    assert_eq!(found.author.as_deref(), Some("Ayşe Yılmaz"));
    assert_eq!(found.mentions, ["Av. D. Aksoy"]);
    assert!(found.created.is_some());
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn every_type_is_added_and_edited_on_a_plain_page() {
    every_type_on("plain", 0);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn every_type_is_added_and_edited_on_a_turned_page() {
    every_type_on("turned", 1);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_foreign_annotation_keeps_what_an_edit_does_not_change() {
    let (dir, path) = copy("foreign", FILE);
    let opened = open(&path);
    let doc = opened.id;
    let rich_box = list(doc)
        .into_iter()
        .find(|a| a.kind == AnnotationKind::FreeText && a.rich)
        .unwrap();
    // A move keeps its appearance and its rich text.
    let [l, t, r, b] = rich_box.rect;
    let before = draw(doc, &opened.pages, 0);
    block_on(engine().update_annotation(
        doc,
        rich_box.handle,
        AnnotationChange {
            rect: Some([l + 5.0, t, r + 5.0, b]),
            ..AnnotationChange::default()
        },
        "Move".to_owned(),
    ))
    .unwrap();
    only_inside(
        &before,
        &draw(doc, &opened.pages, 0),
        [l, t, r + 5.0, b],
        "a moved box",
    );
    assert!(find(doc, rich_box.handle).rich);
    // New text replaces rich text, which no longer says the same.
    block_on(engine().update_annotation(
        doc,
        rich_box.handle,
        AnnotationChange {
            contents: Some("Değişti".to_owned()),
            ..AnnotationChange::default()
        },
        "Text".to_owned(),
    ))
    .unwrap();
    assert!(!find(doc, rich_box.handle).rich);

    // An unknown type written directly in /Annots: its text is editable, and it then has an object
    // of its own; its style is not Ferman's to change.
    let caret = list(doc)
        .into_iter()
        .find(|a| a.subtype == "Caret")
        .unwrap();
    let refused = block_on(engine().update_annotation(
        doc,
        caret.handle,
        AnnotationChange {
            color: Some([0.0, 0.0, 0.0]),
            ..AnnotationChange::default()
        },
        "Style".to_owned(),
    ))
    .unwrap_err();
    assert_eq!(refused.kind, ErrorKind::InvalidInput);
    let changed = block_on(engine().update_annotation(
        doc,
        caret.handle,
        AnnotationChange {
            contents: Some("Kadıköy".to_owned()),
            ..AnnotationChange::default()
        },
        "Caret".to_owned(),
    ))
    .unwrap();
    assert_ne!(changed.handle, caret.handle);
    let found = find(doc, changed.handle);
    assert_eq!(found.subtype, "Caret");
    assert_eq!(found.contents.as_deref(), Some("Kadıköy"));

    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    let saved = std::fs::read(&path).unwrap();
    let original = std::fs::read(corpus(FILE)).unwrap();
    let update = &saved[original.len()..];
    assert!(!update.windows(9).any(|w| w == b"ACME_Data"));
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn replies_resolve_delete_undo_redo_and_revert() {
    let (dir, path) = copy("thread", FILE);
    let opened = open(&path);
    let doc = opened.id;
    let page = opened.pages[0].handle;
    let start = draw(doc, &opened.pages, 0);
    let count = list(doc).len();

    let top = block_on(engine().add_annotation(
        doc,
        page,
        draft(AnnotationKind::Square, [60.0, 550.0, 160.0, 610.0], vec![]),
        "Square".to_owned(),
    ))
    .unwrap()
    .handle;
    let with_top = draw(doc, &opened.pages, 0);
    let reply = block_on(engine().reply_to_annotation(
        doc,
        top,
        "Mert Kaya".to_owned(),
        "Tamam @Ayşe Yılmaz".to_owned(),
        "Reply".to_owned(),
    ))
    .unwrap();
    let found = find(doc, reply.handle);
    assert_eq!(found.replies_to, Some(top));
    assert_eq!(found.mentions, ["Ayşe Yılmaz"]);
    // A reply draws nothing of its own.
    let diff = compare(&with_top, &draw(doc, &opened.pages, 0), None, 0).unwrap();
    assert_eq!(diff.differing, 0);

    // A reply to the reply joins the thread.
    let second = block_on(engine().reply_to_annotation(
        doc,
        reply.handle,
        "Ayşe Yılmaz".to_owned(),
        "Sağ ol".to_owned(),
        "Reply".to_owned(),
    ))
    .unwrap();
    assert_eq!(find(doc, second.handle).thread, top);

    block_on(engine().set_annotation_resolved(
        doc,
        top,
        "Mert Kaya".to_owned(),
        true,
        "Resolve".to_owned(),
    ))
    .unwrap();
    let resolved = find(doc, top);
    assert!(resolved.resolved);
    assert_eq!(resolved.resolved_by.as_deref(), Some("Mert Kaya"));
    // Resolving again adds no step.
    let steps = block_on(engine().history(doc)).unwrap().steps.len();
    block_on(engine().set_annotation_resolved(
        doc,
        top,
        "Mert Kaya".to_owned(),
        true,
        "Resolve".to_owned(),
    ))
    .unwrap();
    assert_eq!(block_on(engine().history(doc)).unwrap().steps.len(), steps);
    block_on(engine().undo(doc)).unwrap();
    assert!(!find(doc, top).resolved);
    block_on(engine().redo(doc)).unwrap();
    assert!(find(doc, top).resolved);
    block_on(engine().set_annotation_resolved(
        doc,
        top,
        "Ayşe Yılmaz".to_owned(),
        false,
        "Reopen".to_owned(),
    ))
    .unwrap();
    assert!(!find(doc, top).resolved);

    // Deleting takes the thread with it, as one step.
    block_on(engine().delete_annotation(doc, top, "Delete".to_owned())).unwrap();
    assert_eq!(list(doc).len(), count);
    let diff = compare(&start, &draw(doc, &opened.pages, 0), None, 0).unwrap();
    assert_eq!(diff.differing, 0, "the page is as it was");
    block_on(engine().undo(doc)).unwrap();
    assert_eq!(find(doc, top).kind, AnnotationKind::Square);
    assert_eq!(find(doc, reply.handle).thread, top, "same identities");
    let diff = compare(&with_top, &draw(doc, &opened.pages, 0), None, 0).unwrap();
    assert_eq!(diff.differing, 0);

    // A foreign annotation deleted, and the step reverted alone.
    let foreign = list(doc)
        .into_iter()
        .find(|a| a.kind == AnnotationKind::Polygon)
        .unwrap();
    block_on(engine().delete_annotation(doc, foreign.handle, "Delete".to_owned())).unwrap();
    assert!(list(doc).iter().all(|a| a.handle != foreign.handle));
    let step = block_on(engine().history(doc)).unwrap().steps.len() - 1;
    let reverted = block_on(engine().revert(
        doc,
        u32::try_from(step).unwrap(),
        false,
        "Reverted".to_owned(),
    ))
    .unwrap();
    assert!(reverted.reverted);
    assert_eq!(find(doc, foreign.handle), foreign);
    block_on(engine().revert_all(doc, "Reverted all".to_owned())).unwrap();
    assert_eq!(list(doc).len(), count);
    let diff = compare(&start, &draw(doc, &opened.pages, 0), None, 0).unwrap();
    assert_eq!(diff.differing, 0, "revert all goes home");
    block_on(engine().close(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn the_gate_is_annotate_and_a_certification_says_what_it_allows() {
    let new = || draft(AnnotationKind::Square, [60.0, 60.0, 160.0, 160.0], vec![]);
    // Level 3 allows comments, with the confirmation; level 2 does not keep the signature.
    for (name, gate) in [
        ("cert-p3", OpGate::KeepsSignatures),
        ("cert-p2", OpGate::BreaksSignatures),
    ] {
        let opened = open(&corpus(name));
        let doc = opened.id;
        let page = opened.pages[0].handle;
        assert_eq!(
            block_on(engine().op_gate(doc, DocumentOp::Comment, Vec::new())).unwrap(),
            gate,
            "{name}"
        );
        let refused =
            block_on(engine().add_annotation(doc, page, new(), "Square".to_owned())).unwrap_err();
        assert_eq!(refused.kind, ErrorKind::ConfirmationRequired, "{name}");
        block_on(engine().confirm_edit_signed(doc)).unwrap();
        block_on(engine().add_annotation(doc, page, new(), "Square".to_owned())).unwrap();
        block_on(engine().close(doc)).unwrap();
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn text_no_font_has_is_refused_and_writes_nothing() {
    let (dir, path) = copy("nofont", FILE);
    let opened = open(&path);
    let doc = opened.id;
    let count = list(doc).len();
    let mut new = draft(
        AnnotationKind::FreeText,
        [90.0, 100.0, 300.0, 170.0],
        vec![],
    );
    // A private-use character no bundled font draws; nothing is substituted silently.
    new.contents = "\u{E123}".to_owned();
    let refused =
        block_on(engine().add_annotation(doc, opened.pages[0].handle, new, "Text".to_owned()))
            .unwrap_err();
    assert_eq!(refused.kind, ErrorKind::Unsupported);
    assert_eq!(list(doc).len(), count);
    assert!(block_on(engine().history(doc)).unwrap().steps.is_empty());
    block_on(engine().close(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

/// A search's events, sent to this test's thread.
struct Found(mpsc::Sender<SearchEvent>);

impl SearchSink for Found {
    fn deliver(&mut self, event: SearchEvent) -> bool {
        self.0.send(event).is_ok()
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_mark_quotes_its_text_and_a_comment_is_found() {
    let (_dir, path) = copy("quote", "kira-tr");
    let opened = open(&path);
    let page = opened.pages[0].handle;
    let blocks = block_on(engine().text_blocks(opened.id, 0)).unwrap();
    let line = &blocks.blocks[0].lines[0];
    let [l, t, r, b] = line.bbox;
    let mut mark = draft(
        AnnotationKind::Highlight,
        [l, t, r, b],
        vec![vec![[l, t], [r, t], [l, b], [r, b]]],
    );
    mark.contents = "Depozito üç\naylık kalsın".to_owned();
    let added =
        block_on(engine().add_annotation(opened.id, page, mark, "Highlight".to_owned())).unwrap();
    let shown = find(opened.id, added.handle);
    assert_eq!(
        shown.quote.as_deref(),
        Some(
            line.text
                .split_whitespace()
                .collect::<Vec<_>>()
                .join(" ")
                .as_str()
        ),
    );

    let search = |comments: bool| {
        let (events, received) = mpsc::channel();
        engine()
            .search(
                opened.id,
                "aylik".to_owned(),
                SearchOptions {
                    ignore_accents: true,
                    ..SearchOptions::default()
                },
                false,
                comments,
                Box::new(Found(events)),
            )
            .unwrap();
        let mut found = Vec::new();
        for event in received.iter() {
            match event {
                SearchEvent::Matches(matches) => found.extend(matches),
                SearchEvent::Done { .. } => break,
                _ => {}
            }
        }
        found
    };
    assert!(search(false).iter().all(|found| found.comment.is_none()));
    let found = search(true);
    let comment = found.iter().find(|found| found.comment.is_some()).unwrap();
    assert_eq!(comment.comment, Some(added.handle));
    assert_eq!(comment.page, 0);
    assert_eq!(comment.snippet, "aylık kalsın");
    assert_eq!(comment.snippet_range, 0..5);
    assert_eq!(comment.rects.len(), 1);
}
