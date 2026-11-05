//! Edit transactions through the facade (ROADMAP §7 step 2, docs/ARCHITECTURE.md §3.6): an edit
//! of a copy of a corpus file, its preview, commit, render reload, undo, redo and save, and the
//! file saved opened again; a damaged document refused; a signed document's confirmation and
//! its working copy.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh). Each saved file is also
//! written to `FERMAN_SAVED_DIR` when it is set, for CI's `qpdf --check`.
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;
use std::sync::OnceLock;

use ferman_api::facade::{
    Engine, EngineConfig, ErrorKind, MessageKey, PageBlocks, Password, PdfiumLibrary, block_on,
};

/// One engine for the whole test binary: one render thread of a process may hold PDFium.
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

fn lines(page: &PageBlocks) -> String {
    page.blocks
        .iter()
        .flat_map(|block| block.lines.iter().map(|line| line.text.as_str()))
        .collect::<Vec<_>>()
        .join("\n")
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn an_edit_renders_undoes_redoes_and_saves() {
    let dir = std::env::temp_dir().join(format!("ferman-api-edit-test-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("booking.pdf");
    std::fs::copy(corpus("edit-e15-helvetica"), &path).unwrap();
    let original = std::fs::read(&path).unwrap();
    let opened = block_on(engine().open(path.clone(), None)).unwrap();
    let doc = opened.id;

    let page = block_on(engine().text_blocks(doc, 0)).unwrap();
    let block = page
        .blocks
        .iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains("Monday")))
        .unwrap();
    let text = block
        .lines
        .iter()
        .map(|line| line.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    let tx = block_on(engine().begin_edit(doc, 0, block.id)).unwrap();
    let preview = block_on(engine().apply(tx, text.replace("Monday", "Friday"))).unwrap();
    assert!(preview.missing.is_empty());
    assert!(lines(&preview.page).contains("Friday"));
    // The preview is not committed: the readers still see the text before.
    assert!(lines(&block_on(engine().text_blocks(doc, 0)).unwrap()).contains("Monday"));

    let committed = block_on(engine().commit(tx, "Edited text".to_owned())).unwrap();
    assert_eq!(committed.current, 1);
    let first_key = committed.render_key.expect("the render thread reloaded");
    assert!(lines(&block_on(engine().text_blocks(doc, 0)).unwrap()).contains("Friday"));
    let err = block_on(engine().apply(tx, text.clone())).unwrap_err();
    assert_eq!(err.kind, ErrorKind::NotFound, "the transaction ended");

    let undone = block_on(engine().undo(doc)).unwrap();
    assert_eq!(undone.current, 0);
    assert!(undone.render_key.unwrap() > first_key);
    assert!(lines(&block_on(engine().text_blocks(doc, 0)).unwrap()).contains("Monday"));
    let history = block_on(engine().history(doc)).unwrap();
    assert_eq!((history.current, history.steps.len()), (0, 1));
    block_on(engine().redo(doc)).unwrap();

    block_on(engine().save(doc, None)).unwrap();
    let saved = std::fs::read(&path).unwrap();
    assert_eq!(saved.get(..original.len()), Some(original.as_slice()));
    if let Some(out) = std::env::var_os("FERMAN_SAVED_DIR").filter(|dir| !dir.is_empty()) {
        let out = PathBuf::from(out);
        std::fs::create_dir_all(&out).unwrap();
        std::fs::write(out.join("api-edit-helvetica.pdf"), &saved).unwrap();
    }
    block_on(engine().close(doc)).unwrap();
    assert_eq!(
        block_on(engine().history(doc)).unwrap_err().kind,
        ErrorKind::NotFound
    );

    // PDFium and ferman-core open the saved file with its pages and the new text.
    let reopened = block_on(engine().open(path.clone(), None)).unwrap();
    assert_eq!(reopened.read_only, None);
    assert_eq!(reopened.pages.len(), opened.pages.len());
    let text = lines(&block_on(engine().text_blocks(reopened.id, 0)).unwrap());
    assert!(text.contains("Friday") && !text.contains("Monday"));
    block_on(engine().close(reopened.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_damaged_document_is_not_editable() {
    let damaged = block_on(engine().open(corpus("kira-tr-damaged"), None)).unwrap();
    let page = block_on(engine().text_blocks(damaged.id, 0)).unwrap();
    let block = page.blocks.first().unwrap();
    let err = block_on(engine().begin_edit(damaged.id, 0, block.id)).unwrap_err();
    assert_eq!(err.kind, ErrorKind::NotEditable);
    assert_eq!(err.message_key, MessageKey::EDIT_DAMAGED);
    block_on(engine().close(damaged.id)).unwrap();
}

/// E24 (ROADMAP §7): an encrypted document edited after the owner password unlocked it, saved
/// and opened again is still encrypted, with the password, and reads the new text; without the
/// password it does not open, so the new objects are encrypted too. Here rather than in
/// `edit_cases.rs`, whose cases run below the facade on files without passwords.
#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e24_an_encrypted_document_stays_encrypted_after_an_edit() {
    let dir = std::env::temp_dir().join(format!("ferman-api-e24-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("payslip.pdf");
    std::fs::copy(corpus("payslip-aes256"), &path).unwrap();
    let original = std::fs::read(&path).unwrap();
    let user = || Some(Password::new("Eylül2026maaşı".to_owned()));
    let opened = block_on(engine().open(path.clone(), user())).unwrap();
    let doc = opened.id;
    block_on(engine().unlock_owner(doc, Password::new("bordro-yonetim-2026".to_owned()))).unwrap();

    let page = block_on(engine().text_blocks(doc, 0)).unwrap();
    let block = page
        .blocks
        .iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains("0187")))
        .unwrap();
    let text = block
        .lines
        .iter()
        .map(|line| line.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    let tx = block_on(engine().begin_edit(doc, 0, block.id)).unwrap();
    let preview = block_on(engine().apply(tx, text.replace("0187", "0188"))).unwrap();
    assert!(preview.missing.is_empty());
    block_on(engine().commit(tx, "Edited text".to_owned())).unwrap();
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();

    let saved = std::fs::read(&path).unwrap();
    assert_eq!(saved.get(..original.len()), Some(original.as_slice()));
    let update = String::from_utf8_lossy(saved.get(original.len()..).unwrap());
    assert!(
        update.contains("/Encrypt"),
        "the update's trailer keeps /Encrypt"
    );
    assert!(!update.contains("BRD-2026"), "no plaintext of the new text");
    if let Some(out) = std::env::var_os("FERMAN_SAVED_DIR").filter(|dir| !dir.is_empty()) {
        let out = PathBuf::from(out);
        std::fs::create_dir_all(&out).unwrap();
        std::fs::write(out.join("api-e24-payslip-aes256.pdf"), &saved).unwrap();
    }
    let err = block_on(engine().open(path.clone(), None)).unwrap_err();
    assert_eq!(err.kind, ErrorKind::PasswordRequired);
    let reopened = block_on(engine().open(path.clone(), user())).unwrap();
    assert!(reopened.security.is_some());
    let text = lines(&block_on(engine().text_blocks(reopened.id, 0)).unwrap());
    assert!(
        text.contains("BRD-2026-09-0188") && !text.contains("BRD-2026-09-0187"),
        "{text}"
    );
    block_on(engine().close(reopened.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

/// A signed document previews without its confirmation and commits and saves with it; "Edit a
/// copy" gives an unsigned file that edits without one (ROADMAP §7 step 10). The byte range is
/// checked in `edit_cases.rs` (E25).
#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_signed_document_commits_only_after_its_confirmation() {
    let dir = std::env::temp_dir().join(format!("ferman-api-signed-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("signed.pdf");
    std::fs::copy(corpus("kira-tr-signed"), &path).unwrap();
    let original = std::fs::read(&path).unwrap();
    let edit_amount = |doc| {
        let page = block_on(engine().text_blocks(doc, 0)).unwrap();
        let block = page
            .blocks
            .iter()
            .find(|block| block.lines.iter().any(|line| line.text.contains("18.500")))
            .unwrap();
        let text = block
            .lines
            .iter()
            .map(|line| line.text.as_str())
            .collect::<Vec<_>>()
            .join("\n");
        let tx = block_on(engine().begin_edit(doc, 0, block.id)).unwrap();
        block_on(engine().apply(tx, text.replace("18.500", "19.500"))).unwrap();
        tx
    };

    let opened = block_on(engine().open(path.clone(), None)).unwrap();
    let doc = opened.id;
    assert!(opened.signed);
    let tx = edit_amount(doc);
    let err = block_on(engine().commit(tx, "Edited text".to_owned())).unwrap_err();
    assert_eq!(err.kind, ErrorKind::ConfirmationRequired);
    let err = block_on(engine().save(doc, None)).unwrap_err();
    assert_eq!(err.kind, ErrorKind::ConfirmationRequired);
    assert!(block_on(engine().would_break_signatures(doc)).unwrap());
    assert!(
        !block_on(engine().history(doc))
            .unwrap()
            .signature_invalidated
    );

    // The same transaction commits after the confirmation.
    block_on(engine().confirm_edit_signed(doc)).unwrap();
    let info = block_on(engine().commit(tx, "Edited text".to_owned())).unwrap();
    assert_eq!(info.current, 1);
    assert!(
        block_on(engine().history(doc))
            .unwrap()
            .signature_invalidated
    );
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    let saved = std::fs::read(&path).unwrap();
    assert_eq!(saved.get(..original.len()), Some(original.as_slice()));

    // Closing ends the confirmation: the file still counts as signed and asks again.
    let reopened = block_on(engine().open(path.clone(), None)).unwrap();
    assert!(reopened.signed);
    let err = block_on(engine().optimize_and_clean(reopened.id, None)).unwrap_err();
    assert_eq!(err.kind, ErrorKind::ConfirmationRequired);

    // "Edit a copy": the working copy is another file, unsigned, and asks nothing.
    let working = dir.join("signed (copy).pdf");
    block_on(engine().save_unsigned_copy(reopened.id, working.clone(), None)).unwrap();
    block_on(engine().close(reopened.id)).unwrap();
    assert_eq!(std::fs::read(&path).unwrap(), saved);
    let copy = block_on(engine().open(working, None)).unwrap();
    assert!(!copy.signed);
    assert!(copy.signatures.iter().all(|field| !field.signed));
    block_on(engine().save(copy.id, None)).unwrap();
    block_on(engine().close(copy.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}
