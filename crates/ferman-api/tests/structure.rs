//! A document's structure follows its revisions (M4 plan, W0): a commit that is not a block's goes
//! through the actor's confirmation, history, publish, reload and save; the page list, the
//! handles, text and search follow it; every page it leaves alone stays pixel-identical.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh). Each saved file is also
//! written to `FERMAN_SAVED_DIR` when it is set, for CI's `qpdf --check`.
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};

use ferman_api::facade::{
    DocumentId, Engine, EngineConfig, ErrorKind, OpenedDocument, PageBlocks, PdfiumLibrary,
    RESOLUTIONS, SearchEvent, SearchOptions, SearchSink, block_on, compare,
};

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

/// A copy of kira-tr in a folder of `test`'s own.
fn copy(test: &str) -> (PathBuf, PathBuf) {
    let dir = std::env::temp_dir().join(format!("ferman-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("kira.pdf");
    std::fs::copy(corpus("kira-tr"), &path).unwrap();
    (dir, path)
}

fn text(page: &PageBlocks) -> String {
    page.blocks
        .iter()
        .flat_map(|block| block.lines.iter().map(|line| line.text.as_str()))
        .collect::<Vec<_>>()
        .join("\n")
}

/// Replaces `from` with `to` in the block of page `page` of `doc` that has it, and commits.
fn edit(doc: DocumentId, page: u32, from: &str, to: &str) {
    let blocks = block_on(engine().text_blocks(doc, page)).unwrap();
    let block = blocks
        .blocks
        .iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains(from)))
        .unwrap();
    let lines: Vec<&str> = block.lines.iter().map(|line| line.text.as_str()).collect();
    let tx = block_on(engine().begin_edit(doc, page, block.id)).unwrap();
    block_on(engine().apply(tx, lines.join("\n").replacen(from, to, 1))).unwrap();
    block_on(engine().commit(tx, "Edited text".to_owned())).unwrap();
}

/// Whether page `page` of the two documents draws the same pixels at every resolution.
fn same_pixels(a: &OpenedDocument, b: &OpenedDocument, page: u32) -> bool {
    let index = usize::try_from(page).unwrap();
    RESOLUTIONS.iter().all(|&dpi| {
        let old = block_on(engine().render_page(a.id, page, a.pages[index].size, dpi)).unwrap();
        let new = block_on(engine().render_page(b.id, page, b.pages[index].size, dpi)).unwrap();
        compare(&old, &new, None, 0).is_some_and(|diff| diff.differing == 0)
    })
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
fn a_rotation_reverts_past_a_later_edit_and_saves() {
    let (dir, path) = copy("rotate-edit-revert");
    let original = block_on(engine().open(corpus("kira-tr"), None)).unwrap();
    let opened = block_on(engine().open(path.clone(), None)).unwrap();
    let doc = opened.id;
    let (first, third) = (opened.pages[0].handle, opened.pages[2].handle);
    assert_ne!(first, third);

    let turned = block_on(engine().rotate_page(doc, 2, 1, "Rotated".to_owned())).unwrap();
    assert_eq!(turned.current, 1);
    assert!(turned.render_key.is_some());
    let pages = turned.structure.expect("the pages changed").pages;
    assert_eq!(pages[2].handle, third);
    assert!((pages[2].size.width - opened.pages[2].size.height).abs() < 0.01);
    assert!((pages[2].size.height - opened.pages[2].size.width).abs() < 0.01);
    assert!(
        same_pixels(&original, &opened, 0),
        "the page before it stays"
    );

    edit(doc, 0, "18.500", "19.500");
    let history = block_on(engine().history(doc)).unwrap();
    assert_eq!(history.steps[0].pages, [third]);
    assert_eq!(history.steps[1].pages, [first]);

    // Undo goes back through both, and redo forward.
    let undone = block_on(engine().undo(doc)).unwrap();
    assert!(undone.structure.is_none(), "the text edit left the pages");
    let undone = block_on(engine().undo(doc)).unwrap();
    assert!(undone.structure.is_some());
    assert_eq!(block_on(engine().redo(doc)).unwrap().current, 1);
    assert_eq!(block_on(engine().redo(doc)).unwrap().current, 2);

    // Reverted alone: the later edit does not depend on it.
    let reverted = block_on(engine().revert(doc, 0, false, "Reverted".to_owned())).unwrap();
    assert!(reverted.reverted);
    assert!(reverted.dependents.is_empty());
    let pages = reverted
        .revision
        .structure
        .expect("the page turned back")
        .pages;
    assert_eq!(pages[2].size, opened.pages[2].size);
    assert!(text(&block_on(engine().text_blocks(doc, 0)).unwrap()).contains("19.500"));

    block_on(engine().save(doc, None)).unwrap();
    keep("api-rotate-revert", &path);
    block_on(engine().close(doc)).unwrap();

    // Opened again: the edit is there, the rotation is not, and pages 2 and 3 are the original's.
    let saved = std::fs::read(&path).unwrap();
    assert!(saved.starts_with(&std::fs::read(corpus("kira-tr")).unwrap()));
    let reopened = block_on(engine().open(path, None)).unwrap();
    assert_eq!(reopened.read_only, None);
    assert_eq!(reopened.pages[2].size, original.pages[2].size);
    assert!(text(&block_on(engine().text_blocks(reopened.id, 0)).unwrap()).contains("19.500"));
    assert!(same_pixels(&original, &reopened, 1));
    assert!(same_pixels(&original, &reopened, 2));
    assert!(!same_pixels(&original, &reopened, 0));
    block_on(engine().close(reopened.id)).unwrap();
    block_on(engine().close(original.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_rotated_page_keeps_its_edit_when_the_rotation_goes() {
    let (dir, path) = copy("rotate-same-page");
    let doc = block_on(engine().open(path.clone(), None)).unwrap().id;
    block_on(engine().rotate_page(doc, 0, 1, "Rotated".to_owned())).unwrap();
    // The text is laid out and edited on the turned page.
    edit(doc, 0, "18.500", "19.500");
    let reverted = block_on(engine().revert(doc, 0, false, "Reverted".to_owned())).unwrap();
    assert!(reverted.reverted, "{:?}", reverted.dependents);
    assert!(text(&block_on(engine().text_blocks(doc, 0)).unwrap()).contains("19.500"));
    block_on(engine().close(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

/// A search's matches, by page.
#[derive(Clone, Default)]
struct Found(Arc<Mutex<(Vec<u32>, bool)>>);

impl SearchSink for Found {
    fn deliver(&mut self, event: SearchEvent) -> bool {
        let mut found = self.0.lock().unwrap();
        match event {
            SearchEvent::Matches(matches) => found.0.extend(matches.iter().map(|m| m.page)),
            SearchEvent::Done { .. } => found.1 = true,
            _ => {}
        }
        true
    }
}

fn search(doc: DocumentId, query: &str) -> Vec<u32> {
    let found = Found::default();
    engine()
        .search(
            doc,
            query.to_owned(),
            SearchOptions::default(),
            false,
            Box::new(found.clone()),
        )
        .unwrap();
    let start = std::time::Instant::now();
    loop {
        {
            let done = found.0.lock().unwrap();
            if done.1 {
                return done.0.clone();
            }
        }
        assert!(start.elapsed().as_secs() < 60);
        std::thread::sleep(std::time::Duration::from_millis(5));
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn search_reads_the_revisions_and_a_commit_refused_changes_nothing() {
    let (dir, path) = copy("search-revised");
    let doc = block_on(engine().open(path, None)).unwrap().id;
    assert_eq!(search(doc, "18.500"), [0]);
    edit(doc, 0, "18.500", "19.500");
    assert!(search(doc, "18.500").is_empty());
    assert_eq!(search(doc, "19.500"), [0]);
    block_on(engine().undo(doc)).unwrap();
    assert_eq!(search(doc, "18.500"), [0]);

    let refused = block_on(engine().rotate_page(doc, 9, 1, "Rotated".to_owned())).unwrap_err();
    assert_eq!(refused.kind, ErrorKind::InvalidInput);
    assert_eq!(block_on(engine().history(doc)).unwrap().current, 0);
    block_on(engine().close(doc)).unwrap();

    // A signed document waits for its confirmation, as a block's commit does.
    let signed = block_on(engine().open(corpus("kira-tr-signed"), None))
        .unwrap()
        .id;
    let refused = block_on(engine().rotate_page(signed, 0, 1, "Rotated".to_owned())).unwrap_err();
    assert_eq!(refused.kind, ErrorKind::ConfirmationRequired);
    assert_eq!(block_on(engine().history(signed)).unwrap().steps.len(), 0);
    block_on(engine().confirm_edit_signed(signed)).unwrap();
    let turned = block_on(engine().rotate_page(signed, 0, 1, "Rotated".to_owned())).unwrap();
    assert_eq!(turned.current, 1);
    block_on(engine().close_discarding(signed)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}
