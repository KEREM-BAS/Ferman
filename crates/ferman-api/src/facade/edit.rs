//! Edit transactions, undo and redo, and saving (docs/ARCHITECTURE.md §3.6, §4.2, §5.4 and §5.5,
//! ADR 0009).
//!
//! Each document that is edited gets an actor: a thread of its own (`ferman-edit`) that runs the
//! document's edit calls one at a time from its mailbox, so mutations have a total order and never
//! run on the UI's threads. The actor holds the document's [`RevisionStore`] and the open
//! transaction. After each commit, undo and redo it publishes the committed store in the model
//! ([`Model::revised`]), which [`Engine::text_blocks`] lays out, and the engine hands the render
//! thread the revised bytes (the incremental update the save would write), so PDFium reloads the
//! document and every page gets a new render key.
//!
//! A transaction edits one block. [`Engine::apply`] replaces the block's whole text: it rewrites
//! the block of the committed revision each time, so the open transaction holds only the newest
//! text, and returns the page as it would read (the preview is not rendered). [`Engine::commit`]
//! makes it a named step of the history (a3-10), [`Engine::rollback`] discards it.
//!
//! A document is editable only when it opened writable (not repaired, its readers agree, not an
//! XFA-only form) and its author's restrictions do not apply (or the owner password lifted them,
//! docs/ARCHITECTURE.md §6.5); otherwise [`Engine::begin_edit`] fails with
//! [`ErrorKind::NotEditable`] and the reason's message.
//!
//! Saving writes the incremental update through ferman-core's safe write (temp file, flush,
//! verify, rename). The atomic replace with its metadata, external changes and every failure of
//! docs/ARCHITECTURE.md §7.8 come later (M3 W4).

use std::panic::AssertUnwindSafe;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc;
use std::sync::{Arc, PoisonError};
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH};

use ferman_core::revision::{self, RevisionStore};
use ferman_core::{CoreError, WriteError};
use ferman_render::DocumentId;
use ferman_text::{BlockId, EditContext, Editability, NotEditableReason, Outcome, TextBlock};

use super::document::Model;
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};
use super::text::{PageBlocks, page_blocks_info};

/// The stack of an actor thread: the interpreter recurses into nested objects, bounded by the
/// limits, as the open and layout threads do.
const ACTOR_STACK: usize = 64 * 1024 * 1024;

/// The handle of an open edit transaction.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct TransactionId(u64);

impl TransactionId {
    /// The raw value, for the UI.
    #[must_use]
    pub fn get(self) -> u64 {
        self.0
    }

    /// A transaction id from its raw value.
    #[must_use]
    pub fn from_raw(raw: u64) -> Self {
        Self(raw)
    }
}

/// What the block's page would read after [`Engine::apply`].
#[derive(Debug, Clone, PartialEq)]
pub struct EditPreview {
    /// The page's blocks with the new text; with the text before when characters are missing.
    pub page: PageBlocks,
    /// The characters no font of their line can draw, in the order they first appear: the text
    /// was not applied, and the missing-glyph steps decide (docs/ARCHITECTURE.md §6.7).
    pub missing: Vec<char>,
    /// Whether a line runs past the block's frame (the overflow choices come with reflow).
    pub overflowing: bool,
}

/// Where the document's history stands after a commit, rollback, undo or redo.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RevisionInfo {
    /// How many steps of the history apply: 0 is the document as opened.
    pub current: u32,
    /// The pages' new render key when the render thread reloaded the revised document; `None`
    /// when nothing it shows changed, or it could not reload.
    pub render_key: Option<u64>,
}

/// One committed step of the history.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HistoryStep {
    /// Its name as the UI gave it at commit.
    pub name: String,
    /// When it was committed, in milliseconds since the Unix epoch.
    pub time: i64,
}

/// The document's history for the Undo history panel (a3-10).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct History {
    /// Every committed step, oldest first: those before `current` apply, the rest can be redone.
    pub steps: Vec<HistoryStep>,
    /// How many steps apply.
    pub current: u32,
}

/// A message to an actor: a call to run on its session.
type Job = Box<dyn FnOnce(&mut Session) + Send>;

/// An actor's mailbox. Dropping it ends the thread after the job it is running.
#[derive(Debug)]
pub(super) struct Actor(mpsc::Sender<Job>);

/// The revised bytes for the render thread: the serial of the publish and what follows the
/// original bytes.
type Reload = Option<(u64, Arc<[u8]>)>;

/// The transaction ids handed out; 0 is never one.
static NEXT_TRANSACTION: AtomicU64 = AtomicU64::new(1);

/// An actor's state: one document's revisions and its open transaction.
pub(super) struct Session {
    model: Arc<Model>,
    /// The committed revisions, the store the model's snapshot shares.
    committed: Arc<RevisionStore>,
    open: Option<Open>,
    steps: Vec<HistoryStep>,
    /// Where Save writes.
    path: PathBuf,
}

/// The open transaction.
struct Open {
    id: TransactionId,
    page: usize,
    /// The block as the committed revision lays it out.
    block: TextBlock,
    /// The committed revisions with the newest text in an open transaction, once one applied.
    working: Option<RevisionStore>,
}

impl Session {
    pub(super) fn new(model: Arc<Model>) -> Self {
        let committed = Arc::clone(&model.revised().store);
        let path = model.path.clone();
        Self {
            model,
            committed,
            open: None,
            steps: Vec::new(),
            path,
        }
    }

    fn context(&self) -> EditContext {
        EditContext {
            document: self.model.read_only,
            ..EditContext::default()
        }
    }

    fn page_index(&self, page: u32) -> Result<usize, ApiError> {
        usize::try_from(page)
            .ok()
            .filter(|&index| index < self.model.document.page_count())
            .ok_or_else(|| {
                ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                    .with_details("no such page")
            })
    }

    pub(super) fn begin(&mut self, page: u32, block: BlockId) -> Result<TransactionId, ApiError> {
        if self.open.is_some() {
            return Err(CoreError::Write(WriteError::TransactionOpen).into());
        }
        if let Some(reason) = self.model.read_only {
            return Err(ApiError::not_editable(reason));
        }
        if self
            .model
            .security()
            .is_some_and(|security| security.restricted())
        {
            return Err(ApiError::not_editable(NotEditableReason::Restricted));
        }
        let index = self.page_index(page)?;
        let text = ferman_text::text_page_revised(
            &self.model.document,
            &self.committed,
            index,
            &self.context(),
        )?;
        let block = text
            .blocks
            .into_iter()
            .find(|candidate| candidate.id == block)
            .ok_or_else(|| {
                ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
                    .with_details("no such block")
            })?;
        if let Editability::NotEditable(reason) = block.editability {
            return Err(ApiError::not_editable(reason));
        }
        let id = TransactionId(NEXT_TRANSACTION.fetch_add(1, Ordering::Relaxed));
        self.open = Some(Open {
            id,
            page: index,
            block,
            working: None,
        });
        Ok(id)
    }

    fn open(&mut self, transaction: TransactionId) -> Result<&mut Open, ApiError> {
        self.open
            .as_mut()
            .filter(|open| open.id == transaction)
            .ok_or_else(|| {
                ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
                    .with_details("no such transaction")
            })
    }

    pub(super) fn apply(
        &mut self,
        transaction: TransactionId,
        text: &str,
    ) -> Result<EditPreview, ApiError> {
        let context = self.context();
        let committed = Arc::clone(&self.committed);
        let model = Arc::clone(&self.model);
        let document = &model.document;
        let open = self.open(transaction)?;
        let outcome =
            ferman_text::rewrite_block_revised(document, &committed, open.page, &open.block, text)?;
        let (missing, overflowing) = match outcome {
            Outcome::Rewritten(rewrite) => {
                let splices: Vec<revision::Splice> = rewrite
                    .splices
                    .into_iter()
                    .map(|splice| revision::Splice {
                        source: splice.source,
                        range: splice.range,
                        bytes: splice.bytes,
                    })
                    .collect();
                let mut working = (*committed).clone();
                working.begin()?;
                working.splice(document, open.page, &splices, &[])?;
                open.working = Some(working);
                (Vec::new(), !rewrite.overflowing.is_empty())
            }
            // The text before stays applied.
            Outcome::MissingGlyphs(missing) => (missing, false),
            Outcome::Unsupported(unsupported) => {
                return Err(
                    ApiError::new(ErrorKind::Unsupported, MessageKey::UNSUPPORTED)
                        .with_details(format!("not rewritten yet: {unsupported:?}")),
                );
            }
        };
        let revisions = open.working.as_ref().unwrap_or(&committed);
        let page = ferman_text::text_page_revised(document, revisions, open.page, &context)?;
        Ok(EditPreview {
            page: page_blocks_info(&model, &page),
            missing,
            overflowing,
        })
    }

    pub(super) fn commit(
        &mut self,
        transaction: TransactionId,
        name: String,
    ) -> Result<(u32, Reload), ApiError> {
        self.open(transaction)?;
        let working = self.open.take().and_then(|open| open.working);
        let before = self.committed.current();
        let Some(mut working) = working else {
            return Ok((self.current(), None));
        };
        // A transaction that changed nothing adds no step.
        if working.commit()? == before {
            return Ok((self.current(), None));
        }
        self.steps.truncate(before);
        self.steps.push(HistoryStep {
            name,
            time: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .ok()
                .and_then(|since| i64::try_from(since.as_millis()).ok())
                .unwrap_or(0),
        });
        self.committed = Arc::new(working);
        Ok((self.current(), self.publish()))
    }

    pub(super) fn rollback(&mut self, transaction: TransactionId) -> Result<u32, ApiError> {
        self.open(transaction)?;
        self.open = None;
        Ok(self.current())
    }

    pub(super) fn undo(&mut self) -> Result<(u32, Reload), ApiError> {
        self.closed()?;
        Arc::make_mut(&mut self.committed).undo()?;
        Ok((self.current(), self.publish()))
    }

    pub(super) fn redo(&mut self) -> Result<(u32, Reload), ApiError> {
        self.closed()?;
        Arc::make_mut(&mut self.committed).redo()?;
        Ok((self.current(), self.publish()))
    }

    pub(super) fn history(&self) -> History {
        History {
            steps: self.steps.clone(),
            current: self.current(),
        }
    }

    /// The document's bytes with the committed revisions as an incremental update.
    pub(super) fn bytes(&self) -> Result<Vec<u8>, ApiError> {
        Ok(self.committed.incremental_update(&self.model.document)?)
    }

    /// Writes the committed revisions to `path`, or to the document's file; Save then writes
    /// to `path`. An open transaction is not saved.
    pub(super) fn save(&mut self, path: Option<PathBuf>) -> Result<(), ApiError> {
        let bytes = self.bytes()?;
        let target = path.unwrap_or_else(|| self.path.clone());
        ferman_core::save::safe_write(&target, &bytes, None)?;
        self.path = target;
        Ok(())
    }

    fn closed(&self) -> Result<(), ApiError> {
        if self.open.is_some() {
            return Err(CoreError::Write(WriteError::TransactionOpen).into());
        }
        Ok(())
    }

    fn current(&self) -> u32 {
        u32::try_from(self.committed.current()).unwrap_or(u32::MAX)
    }

    /// Publishes the committed revisions for the readers and returns the revised bytes for the
    /// render thread, or `None` when they cannot be written (logged).
    fn publish(&self) -> Reload {
        let serial = {
            let mut revised = self.model.revised();
            revised.store = Arc::clone(&self.committed);
            revised.generation = revised.generation.saturating_add(1);
            revised.blocks.fill(None);
            revised.generation
        };
        // shortcut: the whole file is built to cut off its update; build the update alone when
        // large files make edits slow.
        match self.bytes() {
            Ok(bytes) => {
                let original = self.model.document.source().len();
                Some((serial, Arc::from(bytes.get(original..).unwrap_or_default())))
            }
            Err(err) => {
                tracing::warn!(error = %err, "the revised bytes could not be built");
                None
            }
        }
    }
}

impl Engine {
    /// Opens a transaction that edits `block` of `page` of `document`.
    ///
    /// # Errors
    ///
    /// Returns `NotEditable` with the reason for a block or a document that cannot be edited,
    /// `InvalidInput` while another transaction of the document is open or for a page it does
    /// not have, and `NotFound` for a document that is not open or a block the page does not
    /// have.
    pub async fn begin_edit(
        &self,
        document: DocumentId,
        page: u32,
        block: BlockId,
    ) -> Result<TransactionId, ApiError> {
        guard_async(async move {
            let transaction = self
                .ask(document, move |session| session.begin(page, block))
                .await?;
            self.transactions
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .insert(transaction, document);
            Ok(transaction)
        })
        .await
    }

    /// Replaces the text of the transaction's block with `text`, its lines separated by line
    /// feeds, one per line of the block, and returns the page as it would read.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open, `Unsupported` for text the
    /// rewriter cannot write yet (another number of lines, right to left, a block inside a
    /// form…), or the error of reading the page.
    pub async fn apply(
        &self,
        transaction: TransactionId,
        text: String,
    ) -> Result<EditPreview, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            self.ask(document, move |session| session.apply(transaction, &text))
                .await
        })
        .await
    }

    /// Commits the transaction as the step `name` of the history, dropping the steps undone,
    /// and has the render thread show it. A transaction that changed nothing adds no step.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open.
    pub async fn commit(
        &self,
        transaction: TransactionId,
        name: String,
    ) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            let result = self
                .ask(document, move |session| session.commit(transaction, name))
                .await;
            // A failed commit ends the transaction too: the actor dropped it.
            self.end_transaction(transaction);
            let (current, reload) = result?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }

    /// Discards the transaction; the history does not change.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open.
    pub async fn rollback(&self, transaction: TransactionId) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            let current = self
                .ask(document, move |session| session.rollback(transaction))
                .await;
            self.end_transaction(transaction);
            let current = current?;
            Ok(RevisionInfo {
                current,
                render_key: None,
            })
        })
        .await
    }

    /// Steps the document back one step of its history.
    ///
    /// # Errors
    ///
    /// Returns `InvalidInput` at the start of the history or while a transaction is open, and
    /// `NotFound` for a document that is not open.
    pub async fn undo(&self, document: DocumentId) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self.ask(document, Session::undo).await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }

    /// Steps the document forward one step undone.
    ///
    /// # Errors
    ///
    /// Returns `InvalidInput` with nothing to redo or while a transaction is open, and
    /// `NotFound` for a document that is not open.
    pub async fn redo(&self, document: DocumentId) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self.ask(document, Session::redo).await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }

    /// The document's history (a3-10).
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open.
    pub async fn history(&self, document: DocumentId) -> Result<History, ApiError> {
        guard_async(async move { self.ask(document, |session| Ok(session.history())).await }).await
    }

    /// Saves the committed revisions to the document's file as an incremental update: the
    /// original bytes stay an exact prefix.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open, `Unsupported` for a repaired one
    /// (saved as a repaired copy instead, later), and the file errors of the write.
    pub async fn save(&self, document: DocumentId) -> Result<(), ApiError> {
        guard_async(async move { self.ask(document, |session| session.save(None)).await }).await
    }

    /// Saves the committed revisions as the file at `path`, as [`save`](Self::save) does; later
    /// saves write to `path`.
    ///
    /// # Errors
    ///
    /// As [`save`](Self::save).
    pub async fn save_as(&self, document: DocumentId, path: PathBuf) -> Result<(), ApiError> {
        guard_async(async move {
            self.ask(document, move |session| session.save(Some(path)))
                .await
        })
        .await
    }

    /// Ends the actor and the transactions of a document that closes.
    pub(super) fn end_edits(&self, document: DocumentId) {
        self.actors
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&document);
        self.transactions
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .retain(|_, owner| *owner != document);
    }

    /// Runs `job` on the actor of `document`, started on first use, and awaits its result.
    async fn ask<T: Send + 'static>(
        &self,
        document: DocumentId,
        job: impl FnOnce(&mut Session) -> Result<T, ApiError> + Send + 'static,
    ) -> Result<T, ApiError> {
        let (reply, receiver) = futures_channel::oneshot::channel();
        let job: Job = Box::new(move |session| {
            // A panic is the last resort: the session keeps what the job changed before it.
            let result = guard(AssertUnwindSafe(|| job(session)));
            let _ = reply.send(result);
        });
        self.actor(document)?
            .send(job)
            .map_err(|_| ApiError::internal("the edit actor stopped"))?;
        receiver
            .await
            .map_err(|_canceled| ApiError::internal("the edit actor stopped"))?
    }

    /// The mailbox of `document`'s actor, which starts with its first call.
    fn actor(&self, document: DocumentId) -> Result<mpsc::Sender<Job>, ApiError> {
        let mut actors = self.actors.lock().unwrap_or_else(PoisonError::into_inner);
        if let Some(Actor(mailbox)) = actors.get(&document) {
            return Ok(mailbox.clone());
        }
        let model = self
            .models()?
            .get(&document)
            .cloned()
            .ok_or_else(|| ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL))?;
        let (mailbox, inbox) = mpsc::channel::<Job>();
        thread::Builder::new()
            .name("ferman-edit".to_owned())
            .stack_size(ACTOR_STACK)
            .spawn(move || {
                let mut session = Session::new(model);
                for job in inbox {
                    job(&mut session);
                }
            })
            .map_err(|_| ApiError::internal("cannot start the edit actor"))?;
        actors.insert(document, Actor(mailbox.clone()));
        Ok(mailbox)
    }

    fn transaction_document(&self, transaction: TransactionId) -> Result<DocumentId, ApiError> {
        self.transactions
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .get(&transaction)
            .copied()
            .ok_or_else(|| {
                ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
                    .with_details("no such transaction")
            })
    }

    fn end_transaction(&self, transaction: TransactionId) {
        self.transactions
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&transaction);
    }

    /// Hands the render thread the revised bytes, unless a newer revision was handed already,
    /// and awaits the new render key.
    async fn revision_info(
        &self,
        document: DocumentId,
        current: u32,
        reload: Reload,
    ) -> RevisionInfo {
        let reply = (|| {
            let (serial, appendix) = reload?;
            let model = self.models().ok()?.get(&document).cloned()?;
            let mut rendered = model
                .rendered
                .lock()
                .unwrap_or_else(PoisonError::into_inner);
            if serial <= *rendered {
                return None;
            }
            *rendered = serial;
            // Sent under the lock, so reloads reach the render thread in the actor's order.
            Some(self.render().ok()?.reload(document, appendix))
        })();
        let render_key = match reply {
            Some(reply) => match reply.await {
                Ok(key) => Some(key),
                Err(err) => {
                    // shortcut: PDFium reloads without the password (Q22), so a document that
                    // needs one keeps showing the revision it opened with.
                    tracing::warn!(error = %err, "the render thread did not reload the revision");
                    None
                }
            },
            None => None,
        };
        RevisionInfo {
            current,
            render_key,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::facade::document::Model;
    use ferman_text::PageText;

    fn corpus(name: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(format!("{name}.pdf"))
    }

    fn session(name: &str, read_only: Option<NotEditableReason>) -> Session {
        let path = corpus(name);
        let source = ferman_core::Source::read(&path).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        Session::new(Arc::new(Model::new(document, path, read_only, false, None)))
    }

    /// The page's blocks as the actor's readers see them.
    fn blocks(session: &Session, page: usize) -> PageText {
        let store = Arc::clone(&session.model.revised().store);
        ferman_text::text_page_revised(&session.model.document, &store, page, &session.context())
            .unwrap()
    }

    /// The file the revisions would save, without the random second `/ID` string.
    fn saved(session: &Session) -> Vec<u8> {
        let mut bytes = session.bytes().unwrap();
        let original = session.model.document.source().len();
        if bytes.len() > original {
            let tail = bytes.get(original..).unwrap();
            let at = tail.windows(3).rposition(|w| w == b"/ID").unwrap() + original;
            let end = bytes
                .get(at..)
                .unwrap()
                .iter()
                .position(|&b| b == b']')
                .unwrap()
                + at;
            bytes.drain(at..end);
        }
        bytes
    }

    /// Writes `bytes` as `name` into `FERMAN_SAVED_DIR` when it is set, for CI's `qpdf --check`.
    fn keep(name: &str, bytes: &[u8]) {
        if let Some(dir) = std::env::var_os("FERMAN_SAVED_DIR").filter(|dir| !dir.is_empty()) {
            let dir = PathBuf::from(dir);
            std::fs::create_dir_all(&dir).unwrap();
            std::fs::write(dir.join(format!("{name}.pdf")), bytes).unwrap();
        }
    }

    /// Edits the first block of page 0 whose text has `from`, replacing it with `to`.
    fn edit(session: &mut Session, from: &str, to: &str, name: &str) -> (u32, Reload) {
        let block = blocks(session, 0)
            .blocks
            .into_iter()
            .find(|block| block.lines.iter().any(|line| line.text.contains(from)))
            .unwrap();
        let text: Vec<String> = block.lines.iter().map(|line| line.text.clone()).collect();
        let tx = session.begin(0, block.id).unwrap();
        let preview = session
            .apply(tx, &text.join("\n").replacen(from, to, 1))
            .unwrap();
        assert!(preview.missing.is_empty());
        assert!(
            preview
                .page
                .blocks
                .iter()
                .any(|block| block.lines.iter().any(|line| line.text.contains(to)))
        );
        session.commit(tx, name.to_owned()).unwrap()
    }

    #[test]
    fn an_edit_commits_publishes_and_undoes() {
        let mut session = session("edit-e15-helvetica", None);
        let original = saved(&session);
        assert_eq!(
            original.as_slice(),
            &**session.model.document.source().bytes()
        );
        let (current, reload) = edit(&mut session, "Monday", "Friday", "Edited text");
        assert_eq!(current, 1);
        let (serial, appendix) = reload.unwrap();
        assert_eq!(serial, 1);
        assert!(!appendix.is_empty());
        // The readers see the new text, laid out again.
        let page = blocks(&session, 0);
        assert!(
            page.blocks
                .iter()
                .any(|b| b.lines.iter().any(|l| l.text.contains("Friday")))
        );
        let history = session.history();
        assert_eq!(history.current, 1);
        assert_eq!(history.steps.first().unwrap().name, "Edited text");
        assert!(history.steps.first().unwrap().time > 0);

        let (current, reload) = session.undo().unwrap();
        assert_eq!(current, 0);
        assert!(
            reload.unwrap().1.is_empty(),
            "nothing appended at the start"
        );
        assert_eq!(saved(&session), original);
        assert_eq!(session.history().steps.len(), 1, "the step can be redone");
        let err = session.undo().unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
        session.redo().unwrap();
        assert!(session.redo().is_err());

        // A new edit after an undo drops the redo branch.
        session.undo().unwrap();
        edit(&mut session, "Monday", "Sunday", "Second");
        let history = session.history();
        assert_eq!(history.current, 1);
        assert_eq!(history.steps.len(), 1);
        assert_eq!(history.steps.first().unwrap().name, "Second");
    }

    #[test]
    fn rollback_and_an_unchanged_commit_add_no_step() {
        let mut session = session("edit-e15-helvetica", None);
        let block = blocks(&session, 0).blocks.remove(0);
        let tx = session.begin(0, block.id).unwrap();
        // One transaction at a time; undo waits for it.
        let err = session.begin(0, block.id).unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
        assert_eq!(session.undo().unwrap_err().kind, ErrorKind::InvalidInput);
        session
            .apply(tx, &block.lines.first().unwrap().text.replace('e', "a"))
            .unwrap();
        assert_eq!(session.rollback(tx).unwrap(), 0);
        assert_eq!(session.rollback(tx).unwrap_err().kind, ErrorKind::NotFound);

        let tx = session.begin(0, block.id).unwrap();
        let (current, reload) = session.commit(tx, "Nothing".to_owned()).unwrap();
        assert_eq!((current, reload.is_none()), (0, true));
        assert!(session.history().steps.is_empty());
    }

    #[test]
    fn apply_replaces_the_text_each_time() {
        let mut session = session("edit-e15-helvetica", None);
        let block = blocks(&session, 0)
            .blocks
            .into_iter()
            .find(|block| block.lines.iter().any(|l| l.text.contains("Monday")))
            .unwrap();
        let text = block
            .lines
            .iter()
            .map(|l| l.text.clone())
            .collect::<Vec<_>>()
            .join("\n");
        let tx = session.begin(0, block.id).unwrap();
        session
            .apply(tx, &text.replace("Monday", "Tuesday"))
            .unwrap();
        let preview = session
            .apply(tx, &text.replace("Monday", "Friday"))
            .unwrap();
        let lines: String = preview
            .page
            .blocks
            .iter()
            .flat_map(|b| b.lines.iter().map(|l| l.text.clone()))
            .collect();
        assert!(lines.contains("Friday") && !lines.contains("Tuesday"));
        // Another number of lines is not rewritten yet; the text before stays applied.
        let err = session.apply(tx, &format!("{text}\nmore")).unwrap_err();
        assert_eq!(err.kind, ErrorKind::Unsupported);
        assert!(session.open.as_ref().unwrap().working.is_some());
        session.commit(tx, "Friday".to_owned()).unwrap();
        assert!(
            blocks(&session, 0)
                .blocks
                .iter()
                .any(|b| b.lines.iter().any(|l| l.text.contains("Friday")))
        );
    }

    #[test]
    fn a_missing_glyph_is_reported_not_written() {
        let mut session = session("edit-e04-differences", None);
        let block = blocks(&session, 0)
            .blocks
            .into_iter()
            .find(|block| block.lines.iter().any(|l| l.text.contains("Kira bedeli")))
            .unwrap();
        let text = block
            .lines
            .iter()
            .map(|l| l.text.clone())
            .collect::<Vec<_>>()
            .join("\n");
        let tx = session.begin(0, block.id).unwrap();
        let preview = session
            .apply(tx, &text.replacen("bedeli", "bedeliğ", 1))
            .unwrap();
        assert_eq!(preview.missing, ['ğ']);
        assert!(session.open.as_ref().unwrap().working.is_none());
    }

    #[test]
    fn a_read_only_document_and_unknown_handles_are_refused() {
        let mut session = session("edit-e15-helvetica", Some(NotEditableReason::Damaged));
        let block = blocks(&session, 0).blocks.remove(0);
        let err = session.begin(0, block.id).unwrap_err();
        assert_eq!(err.kind, ErrorKind::NotEditable);
        assert_eq!(err.message_key, MessageKey::EDIT_DAMAGED);

        let mut session = super::tests::session("edit-e15-helvetica", None);
        assert_eq!(
            session.begin(0, BlockId(1)).unwrap_err().kind,
            ErrorKind::NotFound
        );
        assert_eq!(
            session.begin(9, block.id).unwrap_err().kind,
            ErrorKind::InvalidInput
        );
        let stale = TransactionId(u64::MAX);
        assert_eq!(
            session.apply(stale, "x").unwrap_err().kind,
            ErrorKind::NotFound
        );
        assert_eq!(
            session.commit(stale, String::new()).unwrap_err().kind,
            ErrorKind::NotFound
        );
    }

    #[test]
    fn a_restricted_document_is_not_editable_until_unlocked() {
        let path = corpus("kira-tr-restricted");
        let source = ferman_core::Source::read(&path).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        let model = Arc::new(Model::new(document, path, None, false, None));
        let mut session = Session::new(Arc::clone(&model));
        let block = blocks(&session, 0).blocks.remove(0);
        let err = session.begin(0, block.id).unwrap_err();
        assert_eq!(err.message_key, MessageKey::EDIT_RESTRICTED);
        model.owner_unlocked.store(true, Ordering::Relaxed);
        session.begin(0, block.id).unwrap();
    }

    #[test]
    fn save_writes_an_incremental_update_and_save_as_moves_the_target() {
        let dir = std::env::temp_dir().join(format!("ferman-api-edit-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let own = dir.join("own.pdf");
        std::fs::copy(corpus("edit-e15-helvetica"), &own).unwrap();
        let source = ferman_core::Source::read(&own).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        let mut session = Session::new(Arc::new(Model::new(
            document,
            own.clone(),
            None,
            false,
            None,
        )));
        let original = std::fs::read(&own).unwrap();
        edit(&mut session, "Monday", "Friday", "Edited text");
        session.save(None).unwrap();
        let written = std::fs::read(&own).unwrap();
        assert_eq!(written.get(..original.len()), Some(original.as_slice()));
        assert!(written.len() > original.len());
        keep("api-save-helvetica", &written);
        let reopened = ferman_core::open(
            &ferman_core::Source::read(&own).unwrap(),
            &ferman_core::OpenOptions::default(),
        )
        .unwrap();
        assert!(reopened.repair().is_none());
        let text = ferman_text::extract::page_text(&reopened, 0).unwrap();
        assert!(text.contains("Friday") && !text.contains("Monday"));

        let other = dir.join("other.pdf");
        session.save(Some(other.clone())).unwrap();
        session.undo().unwrap();
        session.save(None).unwrap();
        assert_eq!(
            std::fs::read(&other).unwrap(),
            original,
            "Save writes to the new file"
        );
        assert_eq!(std::fs::read(&own).unwrap(), written);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn a_repaired_document_is_not_saved_over() {
        let mut session = session("kira-tr-damaged", Some(NotEditableReason::Damaged));
        assert!(session.model.document.repair().is_some());
        let target =
            std::env::temp_dir().join(format!("ferman-api-repaired-{}.pdf", std::process::id()));
        let err = session.save(Some(target.clone())).unwrap_err();
        assert_eq!(err.kind, ErrorKind::Unsupported);
        assert!(!target.exists());
    }

    /// A seeded xorshift generator: the same edits on every run.
    struct Random(u64);

    impl Random {
        fn below(&mut self, n: usize) -> usize {
            self.0 ^= self.0 << 13;
            self.0 ^= self.0 >> 7;
            self.0 ^= self.0 << 17;
            usize::try_from(self.0 % u64::try_from(n).unwrap()).unwrap()
        }
    }

    #[test]
    fn fifty_edits_undo_to_the_original_bytes_and_redo_to_each_revision() {
        // ROADMAP §7 step 2: 50 random edits, then 50 undos give the original bytes; each redo
        // gives its revision's bytes again.
        let mut session = session("edit-e15-helvetica", None);
        let mut random = Random(0x5EED_F00D);
        let original = saved(&session);
        let mut revisions = vec![original.clone()];
        const LETTERS: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";
        let mut tries = 0;
        while revisions.len() <= 50 {
            tries += 1;
            assert!(tries < 500, "too few edits were rewritten");
            let page = blocks(&session, 0);
            let block = page.blocks.get(random.below(page.blocks.len())).unwrap();
            let mut lines: Vec<Vec<char>> = block
                .lines
                .iter()
                .map(|l| l.text.chars().collect())
                .collect();
            let line = lines.get_mut(random.below(block.lines.len())).unwrap();
            let at = random.below(line.len() + 1);
            let cut = random.below(4).min(line.len() - at);
            let new: Vec<char> = (0..random.below(5))
                .map(|_| char::from(*LETTERS.get(random.below(LETTERS.len())).unwrap()))
                .collect();
            line.splice(at..at + cut, new);
            let text = lines
                .iter()
                .map(|l| l.iter().collect::<String>())
                .collect::<Vec<_>>()
                .join("\n");
            let tx = session.begin(0, block.id).unwrap();
            let changed = session
                .apply(tx, &text)
                .is_ok_and(|preview| preview.missing.is_empty());
            if !changed {
                session.rollback(tx).unwrap();
                continue;
            }
            let before = session.history().current;
            let (current, _) = session
                .commit(tx, format!("edit {}", revisions.len()))
                .unwrap();
            if current == before {
                continue;
            }
            revisions.push(saved(&session));
        }
        keep("api-fifty-edits", &session.bytes().unwrap());
        for at in (0..50).rev() {
            session.undo().unwrap();
            assert_eq!(&saved(&session), revisions.get(at).unwrap(), "undo to {at}");
        }
        assert_eq!(saved(&session), original);
        for at in 1..=50 {
            session.redo().unwrap();
            assert_eq!(&saved(&session), revisions.get(at).unwrap(), "redo to {at}");
        }
        assert_eq!(session.history().steps.len(), 50);
    }
}
