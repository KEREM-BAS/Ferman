//! Crash recovery through the facade (ROADMAP §7 step 9, docs/ARCHITECTURE.md §7.6 and §7.7): a
//! child process edits copies of kira-tr and payslip-aes256 and is killed after their journals
//! are synced; the parent lists the crashed session, restores kira-tr with the same revision the
//! child committed and the encrypted payslip with its password only, the original files
//! unchanged and the payslip's new text nowhere on disk in plaintext, and "Don't save" deletes
//! the files. Two more copies of kira-tr: one whose original changes after the crash opens under
//! a new name and saves beside it, and one without a base copy opens from its original.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh). The child is this test
//! binary again, run with `FERMAN_RECOVERY_CHILD`. Unix only: the kill is a `SIGKILL`.
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::time::{Duration, Instant};

use ferman_api::facade::{
    DocumentId, Engine, EngineConfig, ErrorKind, PageBlocks, Password, PdfiumLibrary, block_on,
};

const CHILD: &str = "FERMAN_RECOVERY_CHILD";
const TEST: &str = "a_killed_instance_is_restored_from_its_journal";

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

fn text(page: &PageBlocks) -> String {
    page.blocks
        .iter()
        .flat_map(|block| block.lines.iter().map(|line| line.text.as_str()))
        .collect::<Vec<_>>()
        .join("\n")
}

/// `bytes` without the update's random second `/ID` string, so two saves of one revision
/// compare.
fn without_id(bytes: &[u8]) -> Vec<u8> {
    let at = bytes.windows(3).rposition(|w| w == b"/ID").unwrap();
    let end = at + bytes[at..].iter().position(|&b| b == b']').unwrap();
    [&bytes[..at], &bytes[end..]].concat()
}

const USER: &str = "Eylül2026maaşı";

/// Replaces `from` with `to` in the block of page 1 of `doc` that has it, and commits.
fn edit(doc: DocumentId, from: &str, to: &str) {
    let page = block_on(engine().text_blocks(doc, 0)).unwrap();
    let block = page
        .blocks
        .iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains(from)))
        .unwrap();
    let lines: Vec<&str> = block.lines.iter().map(|line| line.text.as_str()).collect();
    let tx = block_on(engine().begin_edit(doc, 0, block.id)).unwrap();
    block_on(engine().apply(tx, lines.join("\n").replacen(from, to, 1))).unwrap();
    block_on(engine().commit(tx, "Edited text".to_owned())).unwrap();
}

/// The child: edits page 1 of `dir/kira.pdf` and `dir/payslip.pdf`, writes kira's committed
/// revision as `expected.pdf`, edits `changed.pdf` and `nobase.pdf`, waits for the journals' sync
/// and says so, then waits to be killed (and ends by itself if the parent is gone).
fn child(dir: &Path) -> ! {
    block_on(engine().start_recovery(dir.join("Recovery"))).unwrap();
    let doc = block_on(engine().open(dir.join("kira.pdf"), None))
        .unwrap()
        .id;
    edit(doc, "18.500", "19.500");
    block_on(engine().save_copy(doc, dir.join("expected.pdf"), None)).unwrap();
    let payslip = block_on(engine().open(
        dir.join("payslip.pdf"),
        Some(Password::new(USER.to_owned())),
    ))
    .unwrap()
    .id;
    block_on(engine().unlock_owner(payslip, Password::new("bordro-yonetim-2026".to_owned())))
        .unwrap();
    edit(payslip, "0187", "0188");
    for name in ["changed.pdf", "nobase.pdf"] {
        let doc = block_on(engine().open(dir.join(name), None)).unwrap().id;
        edit(doc, "18.500", "19.500");
    }
    let doc = block_on(engine().open(dir.join("rotated.pdf"), None))
        .unwrap()
        .id;
    block_on(engine().rotate_page(doc, 2, 1, "Rotated".to_owned())).unwrap();
    edit(doc, "18.500", "19.500");
    let arranged = block_on(engine().open(dir.join("arranged.pdf"), None)).unwrap();
    let pages: Vec<u64> = arranged.pages.iter().map(|page| page.handle).collect();
    let doc = arranged.id;
    block_on(engine().move_pages(doc, vec![pages[3]], Some(pages[0]), "Moved".to_owned())).unwrap();
    block_on(engine().delete_pages(doc, vec![pages[1]], "Deleted".to_owned())).unwrap();
    block_on(engine().duplicate_pages(doc, vec![pages[5]], "Duplicated".to_owned())).unwrap();
    let commented = block_on(engine().open(dir.join("commented.pdf"), None)).unwrap();
    block_on(engine().add_annotation(
        commented.id,
        commented.pages[0].handle,
        ferman_api::facade::NewAnnotation {
            kind: ferman_api::facade::AnnotationKind::Square,
            rect: [60.0, 60.0, 160.0, 160.0],
            points: Vec::new(),
            color: [0.85, 0.22, 0.17],
            stroke: 2.0,
            opacity: 1.0,
            contents: "Bak".to_owned(),
            author: "Ayşe".to_owned(),
            font_size: 12.0,
            arrow: false,
            label: String::new(),
            meta: None,
            tilt: 0.0,
            icon: None,
        },
        "Square".to_owned(),
    ))
    .unwrap();
    let filled = block_on(engine().open(dir.join("filled.pdf"), None)).unwrap();
    let field = block_on(engine().form_fields(filled.id))
        .unwrap()
        .fields
        .into_iter()
        .find(|field| field.name == "adi")
        .unwrap();
    block_on(engine().set_field_value(
        filled.id,
        field.handle,
        // In the field's own font: this engine has no bundled fonts.
        vec!["Mehmet".to_owned()],
        None,
        "Fill".to_owned(),
    ))
    .unwrap();
    // Past the one-second sync of the actor's tick.
    std::thread::sleep(Duration::from_millis(2500));
    std::fs::write(dir.join("ready"), b"").unwrap();
    std::thread::sleep(Duration::from_secs(300));
    std::process::exit(2);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_killed_instance_is_restored_from_its_journal() {
    if let Some(dir) = std::env::var_os(CHILD) {
        child(Path::new(&dir));
    }
    if cfg!(windows) {
        return;
    }
    let dir = std::env::temp_dir().join(format!("ferman-api-recovery-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let original = std::fs::read(corpus("kira-tr")).unwrap();
    std::fs::write(dir.join("kira.pdf"), &original).unwrap();
    let payslip = std::fs::read(corpus("payslip-aes256")).unwrap();
    std::fs::write(dir.join("payslip.pdf"), &payslip).unwrap();
    std::fs::write(dir.join("changed.pdf"), &original).unwrap();
    std::fs::write(dir.join("nobase.pdf"), &original).unwrap();
    std::fs::write(dir.join("rotated.pdf"), &original).unwrap();
    let tree = std::fs::read(corpus("pages-tree")).unwrap();
    std::fs::write(dir.join("arranged.pdf"), &tree).unwrap();
    let notes = std::fs::read(corpus("annots-other-producer")).unwrap();
    std::fs::write(dir.join("commented.pdf"), &notes).unwrap();
    let form = std::fs::read(corpus("form-aks1-tr")).unwrap();
    std::fs::write(dir.join("filled.pdf"), &form).unwrap();

    let mut child = std::process::Command::new(std::env::current_exe().unwrap())
        .args(["--ignored", "--exact", TEST, "--test-threads", "1"])
        .env(CHILD, &dir)
        .stdout(std::process::Stdio::null())
        .spawn()
        .unwrap();
    let start = Instant::now();
    while !dir.join("ready").exists() {
        if let Some(status) = child.try_wait().unwrap() {
            panic!("the child ended first: {status}");
        }
        assert!(
            start.elapsed() < Duration::from_secs(120),
            "the child never got ready"
        );
        std::thread::sleep(Duration::from_millis(50));
    }
    // SIGKILL on Unix: nothing of the child runs after it.
    child.kill().unwrap();
    child.wait().unwrap();

    let root = dir.join("Recovery");
    block_on(engine().start_recovery(root.clone())).unwrap();
    let listed = block_on(engine().list_recoverable()).unwrap();
    assert_eq!(listed.len(), 8, "{listed:?}");
    let named = |name: &str| {
        listed
            .iter()
            .find(|found| found.original == dir.join(name))
            .unwrap()
    };

    // The encrypted payslip: its new text is nowhere in plaintext, and it opens with its
    // password only.
    let mut written = Vec::new();
    let mut dirs = vec![root.clone()];
    while let Some(dir) = dirs.pop() {
        for entry in std::fs::read_dir(dir).unwrap().flatten() {
            if entry.path().is_dir() {
                dirs.push(entry.path());
            } else {
                written.extend(std::fs::read(entry.path()).unwrap());
            }
        }
    }
    let word = "BRD-2026-09-0188";
    let wide: Vec<u8> = word.encode_utf16().flat_map(u16::to_be_bytes).collect();
    for needle in [word.as_bytes(), &wide] {
        assert!(!written.windows(needle.len()).any(|w| w == needle));
    }
    let secret = named("payslip.pdf");
    assert!(secret.encrypted && !secret.original_changed);
    let restore = |password: Option<&str>| {
        block_on(engine().restore_recovered(
            secret.session.clone(),
            secret.document.clone(),
            password.map(|password| Password::new(password.to_owned())),
            None,
        ))
    };
    assert_eq!(restore(None).unwrap_err().kind, ErrorKind::PasswordRequired);
    assert_eq!(
        restore(Some("eylul2026")).unwrap_err().kind,
        ErrorKind::WrongPassword
    );
    let secret = restore(Some(USER)).unwrap().opened.id;
    let restored = text(&block_on(engine().text_blocks(secret, 0)).unwrap());
    assert!(restored.contains("BRD-2026-09-0188"), "{restored}");
    assert_eq!(std::fs::read(dir.join("payslip.pdf")).unwrap(), payslip);

    // An annotation comes back from the journal: objects, so no record of its own.
    let found = named("commented.pdf");
    let restored = block_on(engine().restore_recovered(
        found.session.clone(),
        found.document.clone(),
        None,
        None,
    ))
    .unwrap();
    let notes = block_on(engine().annotations(restored.opened.id)).unwrap();
    assert!(
        notes
            .annotations
            .iter()
            .any(|note| note.contents.as_deref() == Some("Bak")
                && note.author.as_deref() == Some("Ayşe")),
        "the new square is back"
    );
    assert!(block_on(engine().undo(restored.opened.id)).is_ok());

    // A field's value comes back the same way.
    let found = named("filled.pdf");
    let restored = block_on(engine().restore_recovered(
        found.session.clone(),
        found.document.clone(),
        None,
        None,
    ))
    .unwrap();
    let form = block_on(engine().form_fields(restored.opened.id)).unwrap();
    assert!(
        form.fields
            .iter()
            .any(|field| field.name == "adi" && field.values == ["Mehmet"]),
        "the value is back"
    );
    assert!(block_on(engine().undo(restored.opened.id)).is_ok());

    let found = named("kira.pdf");
    assert_eq!(found.original, dir.join("kira.pdf"));
    assert!(!found.original_changed);
    assert_eq!((found.changes, found.encrypted), (1, false));

    let restored = block_on(engine().restore_recovered(
        found.session.clone(),
        found.document.clone(),
        None,
        None,
    ))
    .unwrap();
    assert_eq!(restored.path, dir.join("kira.pdf"));
    assert!(!restored.original_changed);
    assert!(restored.render_key.is_some());
    let doc = restored.opened.id;
    assert_eq!(block_on(engine().history(doc)).unwrap().current, 1);
    assert!(text(&block_on(engine().text_blocks(doc, 0)).unwrap()).contains("19.500"));
    block_on(engine().save_copy(doc, dir.join("restored.pdf"), None)).unwrap();
    assert_eq!(
        without_id(&std::fs::read(dir.join("restored.pdf")).unwrap()),
        without_id(&std::fs::read(dir.join("expected.pdf")).unwrap()),
        "the restored revision is the one committed"
    );
    assert_eq!(std::fs::read(dir.join("kira.pdf")).unwrap(), original);
    // The original changed after the crash: it stays as it is, and the document saves beside it.
    let changed = [&original[..], b"\n% changed by another app\n"].concat();
    std::fs::write(dir.join("changed.pdf"), &changed).unwrap();
    let listed_changed = block_on(engine().list_recoverable())
        .unwrap()
        .into_iter()
        .find(|found| found.original == dir.join("changed.pdf"))
        .unwrap();
    assert!(listed_changed.original_changed);
    let restored = block_on(engine().restore_recovered(
        listed_changed.session.clone(),
        listed_changed.document.clone(),
        None,
        None,
    ))
    .unwrap();
    assert!(restored.original_changed);
    assert_eq!(restored.path, dir.join("changed (recovered).pdf"));
    assert!(
        text(&block_on(engine().text_blocks(restored.opened.id, 0)).unwrap()).contains("19.500")
    );
    block_on(engine().save(restored.opened.id, None)).unwrap();
    assert_eq!(std::fs::read(dir.join("changed.pdf")).unwrap(), changed);
    assert!(
        std::fs::read(dir.join("changed (recovered).pdf"))
            .unwrap()
            .starts_with(&original)
    );
    block_on(engine().close(restored.opened.id)).unwrap();

    // A change that is not a block's replays like any other: the document opens rotated, its
    // handles those of the file, and the step that turned it reverts.
    let rotated = named("rotated.pdf");
    let handles = block_on(engine().open(dir.join("nobase.pdf"), None)).unwrap();
    let restored = block_on(engine().restore_recovered(
        rotated.session.clone(),
        rotated.document.clone(),
        None,
        None,
    ))
    .unwrap();
    let rotated_doc = restored.opened.id;
    assert_eq!(
        (
            restored.opened.pages[2].size.width,
            restored.opened.pages[2].size.height
        ),
        (handles.pages[2].size.height, handles.pages[2].size.width),
        "the restored document opens with its pages as the revisions leave them"
    );
    assert_eq!(restored.opened.pages[2].handle, handles.pages[2].handle);
    assert!(text(&block_on(engine().text_blocks(rotated_doc, 0)).unwrap()).contains("19.500"));
    block_on(engine().close(handles.id)).unwrap();
    block_on(engine().close_discarding(rotated_doc)).unwrap();

    // Page operations replay too: the tree, the order and the copy come back, and undo takes
    // them all at once.
    let arranged = named("arranged.pdf");
    let handles = block_on(engine().open(corpus("pages-tree"), None)).unwrap();
    let ids: Vec<u64> = handles.pages.iter().map(|page| page.handle).collect();
    let restored = block_on(engine().restore_recovered(
        arranged.session.clone(),
        arranged.document.clone(),
        None,
        None,
    ))
    .unwrap();
    let pages: Vec<u64> = restored
        .opened
        .pages
        .iter()
        .map(|page| page.handle)
        .collect();
    assert_eq!(pages.len(), 6);
    assert_eq!(pages[..5], [ids[3], ids[0], ids[2], ids[4], ids[5]]);
    assert!(!ids.contains(&pages[5]));
    assert_eq!(restored.opened.pages[3].label, handles.pages[4].label);
    let arranged_doc = restored.opened.id;
    let back = block_on(engine().undo(arranged_doc))
        .unwrap()
        .structure
        .unwrap();
    let back: Vec<u64> = back.pages.iter().map(|page| page.handle).collect();
    assert_eq!(back, ids);
    block_on(engine().close(handles.id)).unwrap();
    block_on(engine().close_discarding(arranged_doc)).unwrap();

    // A document too large for a base copy opens from its original, while that is unchanged.
    let nobase = named("nobase.pdf");
    let files = root.join(&nobase.session).join(&nobase.document);
    std::fs::remove_file(files.join("base.pdf")).unwrap();
    let manifest = std::fs::read_to_string(files.join("manifest.json")).unwrap();
    assert!(manifest.contains("\"base\": true"));
    std::fs::write(
        files.join("manifest.json"),
        manifest.replace("\"base\": true", "\"base\": false"),
    )
    .unwrap();
    let nobase = block_on(engine().restore_recovered(
        nobase.session.clone(),
        nobase.document.clone(),
        None,
        None,
    ))
    .unwrap()
    .opened
    .id;
    assert!(text(&block_on(engine().text_blocks(nobase, 0)).unwrap()).contains("19.500"));
    assert_eq!(std::fs::read(dir.join("nobase.pdf")).unwrap(), original);

    // The running session took the files over: nothing is left to offer, and "Don't save"
    // deletes them.
    assert!(block_on(engine().list_recoverable()).unwrap().is_empty());
    assert!(!root.join(&found.session).exists());
    let sessions = || {
        std::fs::read_dir(&root)
            .unwrap()
            .flatten()
            .flat_map(|session| std::fs::read_dir(session.path()).unwrap().flatten())
            .filter(|entry| entry.path().is_dir())
            .count()
    };
    assert_eq!(sessions(), 3, "the save deleted the changed document's");
    block_on(engine().close_discarding(nobase)).unwrap();
    block_on(engine().close_discarding(doc)).unwrap();
    block_on(engine().close_discarding(secret)).unwrap();
    assert_eq!(sessions(), 0);
    std::fs::remove_dir_all(&dir).unwrap();
}
