//! The outline, the document information and attached files through the facade (M4 plan W6):
//! each change is one history step that names no page, reaches the app as the revised structure,
//! undoes, saves incrementally and reopens as it was left, and changes no page's pixels.
//! PDFium's own readers of the same edits are `ferman-render`'s `structure_edits` test.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;
use std::sync::OnceLock;

use ferman_api::facade::{
    Engine, EngineConfig, ErrorKind, InfoEdit, OutlineEdit, PdfiumLibrary, block_on, compare,
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

fn copy(test: &str, name: &str) -> (PathBuf, PathBuf) {
    let dir = std::env::temp_dir().join(format!("ferman-parts-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
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

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn outline_information_and_attachments_are_steps_that_save_and_reopen() {
    let (dir, path) = copy("steps", "kira-tr");
    let original = std::fs::read(&path).unwrap();
    let opened = block_on(engine().open(path.clone(), None)).unwrap();
    let doc = opened.id;
    let size = opened.pages[0].size;
    let first = block_on(engine().render_page(doc, 0, size, 72)).unwrap();
    let attached = opened.attachments.len();

    let outline = vec![
        OutlineEdit {
            item: None,
            page: Some(0),
            title: "Taraflar".to_owned(),
            depth: 0,
            open: true,
        },
        OutlineEdit {
            item: None,
            page: Some(2),
            title: "Ödeme".to_owned(),
            depth: 1,
            open: true,
        },
    ];
    let step = block_on(engine().set_outline(doc, outline, "Bookmarks".to_owned())).unwrap();
    let structure = step.structure.unwrap();
    let titles: Vec<&str> = structure.outline.iter().map(|i| i.title.as_str()).collect();
    assert_eq!(titles, ["Taraflar"]);
    assert_eq!(structure.outline[0].children[0].page, Some(2));
    assert_eq!(step.changed_pages, Some(Vec::new()));

    let info = InfoEdit {
        title: "Kira sözleşmesi".to_owned(),
        author: "Ayşe Yılmaz".to_owned(),
        ..InfoEdit::default()
    };
    let step = block_on(engine().set_info(doc, info, "Properties".to_owned())).unwrap();
    let structure = step.structure.unwrap();
    assert_eq!(structure.info.author.as_deref(), Some("Ayşe Yılmaz"));

    let file = dir.join("ödeme planı.csv");
    std::fs::write(&file, b"ay,tutar\nKasim,15000\n").unwrap();
    let step = block_on(engine().attach_file(
        doc,
        file,
        "ödeme planı.csv".to_owned(),
        "Attach".to_owned(),
    ))
    .unwrap();
    let structure = step.structure.unwrap();
    assert_eq!(structure.attachments.len(), attached + 1);
    let index = structure
        .attachments
        .iter()
        .position(|a| a.name == "ödeme planı.csv")
        .unwrap();
    // The attachment is read from the revisions, before any save.
    let out = dir.join("out.csv");
    block_on(engine().save_attachment(doc, u32::try_from(index).unwrap(), out.clone(), None))
        .unwrap();
    assert_eq!(std::fs::read(&out).unwrap(), b"ay,tutar\nKasim,15000\n");

    // Undo takes the attachment back; redo restores it.
    let undone = block_on(engine().undo(doc)).unwrap();
    assert_eq!(undone.structure.unwrap().attachments.len(), attached);
    block_on(engine().redo(doc)).unwrap();
    assert_eq!(block_on(engine().history(doc)).unwrap().steps.len(), 3);

    // A file attachment annotation is a comment, not removed here; an index past the end fails.
    let refused = block_on(engine().remove_attachment(doc, 99, "Remove".to_owned())).unwrap_err();
    assert_eq!(refused.kind, ErrorKind::InvalidInput);

    // No page looks different.
    let after = block_on(engine().render_page(doc, 0, size, 72)).unwrap();
    assert_eq!(compare(&first, &after, None, 0).unwrap().differing, 0);

    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    let saved = std::fs::read(&path).unwrap();
    assert!(saved.starts_with(&original));
    let again = block_on(engine().open(path.clone(), None)).unwrap();
    assert_eq!(again.outline[0].title, "Taraflar");
    assert_eq!(again.info.title.as_deref(), Some("Kira sözleşmesi"));
    assert_eq!(again.attachments.len(), attached + 1);
    let index = again
        .attachments
        .iter()
        .position(|a| a.name == "ödeme planı.csv")
        .unwrap();
    let step = block_on(engine().remove_attachment(
        again.id,
        u32::try_from(index).unwrap(),
        "Remove".to_owned(),
    ))
    .unwrap();
    assert_eq!(step.structure.unwrap().attachments.len(), attached);
    block_on(engine().close_discarding(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}
