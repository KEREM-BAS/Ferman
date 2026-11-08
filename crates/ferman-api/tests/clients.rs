//! AI clients in the running app (ADR 0019), through the facade: a stand-in client opens, edits
//! and commits, the history names it, the app hears of it and the user's undo undoes it; a client
//! waits while the user's edit is open; a disconnect mid-transaction rolls back and leaves the
//! file and the history as they were; a read-only client and a signed document's first client
//! commit are refused until the user allows them.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::sync::mpsc;
use std::time::Duration;

use ferman_api::facade::{
    BlockId, ChangeSink, ClientChange, DocumentId, Engine, EngineConfig, ErrorKind, PdfiumLibrary,
    block_on,
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

/// A copy of a corpus file in a directory of the test's own.
fn copy(test: &str, name: &str) -> (PathBuf, PathBuf) {
    let dir = std::env::temp_dir().join(format!("ferman-api-{test}-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!("{name}.pdf"));
    let corpus = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"));
    std::fs::copy(corpus, &path).unwrap();
    (dir, path)
}

/// The block of page 1 that reads `needle`, and its text.
fn block(doc: DocumentId, needle: &str) -> (BlockId, String) {
    let page = block_on(engine().text_blocks(doc, 0)).unwrap();
    let block = page
        .blocks
        .iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains(needle)))
        .unwrap();
    let text = block
        .lines
        .iter()
        .map(|line| line.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    (block.id, text)
}

fn reads(doc: DocumentId, needle: &str) -> bool {
    block_on(engine().text_blocks(doc, 0))
        .unwrap()
        .blocks
        .iter()
        .any(|block| block.lines.iter().any(|line| line.text.contains(needle)))
}

struct Changes(mpsc::Sender<ClientChange>);

impl ChangeSink for Changes {
    fn deliver(&mut self, change: ClientChange) {
        let _ = self.0.send(change);
    }
}

fn open(path: &Path) -> DocumentId {
    block_on(engine().open(path.to_path_buf(), None))
        .unwrap()
        .id
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_client_edits_commits_and_the_users_undo_undoes_it() {
    let (dir, path) = copy("client-edit", "edit-e15-helvetica");
    let doc = open(&path);
    let (changes, heard) = mpsc::channel();
    engine().watch_client_changes(Box::new(Changes(changes)));

    let client = engine().connect_client("Stand-in".to_owned());
    let listed = engine().open_documents().unwrap();
    let listed = listed.iter().find(|listed| listed.id == doc).unwrap();
    assert_eq!(
        (listed.name.as_str(), listed.pages),
        ("edit-e15-helvetica.pdf", 1)
    );

    // Read only until the user grants edit.
    let (id, text) = block(doc, "Monday");
    let err = block_on(engine().client_begin_edit(client, doc, 0, id)).unwrap_err();
    assert_eq!(err.kind, ErrorKind::PermissionDenied);
    engine().grant_edit(client, true).unwrap();

    let tx = block_on(engine().client_begin_edit(client, doc, 0, id)).unwrap();
    block_on(engine().client_apply(client, tx, text.replace("Monday", "Friday"))).unwrap();
    // Another client cannot touch it.
    let other = engine().connect_client("Other".to_owned());
    let err = block_on(engine().client_commit(other, tx, "Edited text".to_owned())).unwrap_err();
    assert_eq!(err.kind, ErrorKind::NotFound);
    engine().disconnect_client(other);

    let committed = block_on(engine().client_commit(client, tx, "Edited text".to_owned())).unwrap();
    assert_eq!(committed.current, 1);
    assert!(committed.render_key.is_some(), "the render thread reloaded");
    assert!(reads(doc, "Friday"));
    // Tests run side by side on one engine: other documents' changes are skipped.
    let change = loop {
        let change = heard.recv_timeout(Duration::from_secs(5)).unwrap();
        if change.document == doc {
            break change;
        }
    };
    assert_eq!(
        (change.document, change.client.as_str(), change.revision),
        (doc, "Stand-in", committed)
    );
    let history = block_on(engine().history(doc)).unwrap();
    assert_eq!(history.steps.len(), 1);
    assert_eq!(history.steps[0].client.as_deref(), Some("Stand-in"));

    // The user's undo undoes it, and the user's own step names no client.
    assert_eq!(block_on(engine().undo(doc)).unwrap().current, 0);
    assert!(reads(doc, "Monday"));
    let (id, text) = block(doc, "Monday");
    let tx = block_on(engine().begin_edit(doc, 0, id)).unwrap();
    block_on(engine().apply(tx, text.replace("Monday", "Sunday"))).unwrap();
    block_on(engine().commit(tx, "Edited text".to_owned())).unwrap();
    let history = block_on(engine().history(doc)).unwrap();
    assert_eq!((history.current, history.steps.len()), (1, 1));
    assert_eq!(history.steps[0].client, None);
    assert!(
        heard.try_iter().all(|change| change.document != doc),
        "the user's own commit is not streamed"
    );

    engine().disconnect_client(client);
    block_on(engine().close(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_client_waits_for_the_users_edit_and_a_disconnect_rolls_back() {
    let (dir, path) = copy("client-wait", "edit-e15-helvetica");
    let original = std::fs::read(&path).unwrap();
    let doc = open(&path);
    let client = engine().connect_client("Stand-in".to_owned());
    engine().grant_edit(client, true).unwrap();
    let (id, text) = block(doc, "Monday");

    // The user's edit is open: the client waits until it ends.
    let users = block_on(engine().begin_edit(doc, 0, id)).unwrap();
    let (begun, waited) = mpsc::channel();
    let waiting = std::thread::spawn(move || {
        let _ = begun.send(block_on(engine().client_begin_edit(client, doc, 0, id)));
    });
    assert!(
        waited.recv_timeout(Duration::from_millis(300)).is_err(),
        "the client did not wait"
    );
    block_on(engine().rollback(users)).unwrap();
    let tx = waited
        .recv_timeout(Duration::from_secs(5))
        .unwrap()
        .unwrap();
    waiting.join().unwrap();

    // While the client's transaction is open, the user's edit is refused, as any second one.
    block_on(engine().client_apply(client, tx, text.replace("Monday", "Friday"))).unwrap();
    let err = block_on(engine().begin_edit(doc, 0, id)).unwrap_err();
    assert_eq!(err.kind, ErrorKind::InvalidInput);

    // The client disconnects mid-transaction: rolled back, nothing committed, the file as it was.
    engine().disconnect_client(client);
    let history = block_on(engine().history(doc)).unwrap();
    assert_eq!((history.current, history.steps.len()), (0, 0));
    assert!(reads(doc, "Monday"));
    let err = block_on(engine().commit(tx, "Edited text".to_owned())).unwrap_err();
    assert_eq!(err.kind, ErrorKind::NotFound, "the transaction ended");
    let users = block_on(engine().begin_edit(doc, 0, id)).unwrap();
    block_on(engine().rollback(users)).unwrap();
    assert!(
        engine()
            .connected_clients()
            .iter()
            .all(|connected| connected.id != client)
    );
    block_on(engine().close(doc)).unwrap();
    assert_eq!(std::fs::read(&path).unwrap(), original);
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_clients_first_commit_on_a_signed_document_asks_even_after_the_users() {
    let (dir, path) = copy("client-signed", "kira-tr-signed");
    let doc = open(&path);
    block_on(engine().confirm_edit_signed(doc)).unwrap();
    let client = engine().connect_client("Stand-in".to_owned());
    engine().grant_edit(client, true).unwrap();
    let (id, text) = block(doc, "18.500");
    let tx = block_on(engine().client_begin_edit(client, doc, 0, id)).unwrap();
    block_on(engine().client_apply(client, tx, text.replace("18.500", "19.500"))).unwrap();
    let err = block_on(engine().client_commit(client, tx, "Edited text".to_owned())).unwrap_err();
    assert_eq!(err.kind, ErrorKind::ConfirmationRequired);

    // The transaction stays open for the user's answer.
    block_on(engine().confirm_client_signed(doc, client)).unwrap();
    let info = block_on(engine().client_commit(client, tx, "Edited text".to_owned())).unwrap();
    assert_eq!(info.current, 1);
    engine().disconnect_client(client);
    block_on(engine().close(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn taking_edit_away_stops_a_waiting_or_open_client_transaction() {
    let (dir, path) = copy("client-revoke", "edit-e15-helvetica");
    let doc = open(&path);
    let client = engine().connect_client("Stand-in".to_owned());
    engine().grant_edit(client, true).unwrap();
    let (id, text) = block(doc, "Monday");

    // The client waits for the user's edit; the user takes its edit away meanwhile.
    let users = block_on(engine().begin_edit(doc, 0, id)).unwrap();
    let (begun, waited) = mpsc::channel();
    let waiting = std::thread::spawn(move || {
        let _ = begun.send(block_on(engine().client_begin_edit(client, doc, 0, id)));
    });
    assert!(waited.recv_timeout(Duration::from_millis(300)).is_err());
    engine().grant_edit(client, false).unwrap();
    block_on(engine().rollback(users)).unwrap();
    let err = waited
        .recv_timeout(Duration::from_secs(5))
        .unwrap()
        .unwrap_err();
    waiting.join().unwrap();
    assert_eq!(err.kind, ErrorKind::PermissionDenied);
    // Its transaction was rolled back: the user can edit again.
    let users = block_on(engine().begin_edit(doc, 0, id)).unwrap();
    block_on(engine().rollback(users)).unwrap();

    // An open transaction can no longer apply or commit once edit is taken away.
    engine().grant_edit(client, true).unwrap();
    let tx = block_on(engine().client_begin_edit(client, doc, 0, id)).unwrap();
    engine().grant_edit(client, false).unwrap();
    let err =
        block_on(engine().client_apply(client, tx, text.replace("Monday", "Friday"))).unwrap_err();
    assert_eq!(err.kind, ErrorKind::PermissionDenied);
    let err = block_on(engine().client_commit(client, tx, "Edited text".to_owned())).unwrap_err();
    assert_eq!(err.kind, ErrorKind::PermissionDenied);
    block_on(engine().client_rollback(client, tx)).unwrap();
    let history = block_on(engine().history(doc)).unwrap();
    assert_eq!(history.steps.len(), 0);

    engine().disconnect_client(client);
    block_on(engine().close(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}
