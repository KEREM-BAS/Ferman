//! AI clients working in the running app (ADR 0019): the engine's side of the MCP server.
//!
//! A client connects with the name it gives ([`Engine::connect_client`]) and may read every open
//! document ([`Engine::open_documents`]); it may change them only once the user grants it edit
//! ([`Engine::grant_edit`]), read only by default. Its changes are the user's own edit
//! transactions, owned by it: one open transaction per document as for the user, so a client
//! waits while another transaction of the document is open ([`Engine::client_begin_edit`]), and
//! a client that disconnects has its open transactions rolled back
//! ([`Engine::disconnect_client`]). Each step it commits names it in the history
//! ([`HistoryStep::client`](super::HistoryStep::client)) and reaches the app through the change
//! stream ([`Engine::watch_client_changes`]), so the app redraws and its undo list follows; the
//! user's undo undoes it like any other step. A client's first commit on a signed document asks
//! the user even after the user's own confirmation ([`Engine::confirm_client_signed`]).
//!
//! Every other change a client makes is the facade's own call run for it ([`Engine::as_client`]):
//! the actor's jobs carry the client, so its step names it and a signed document asks for its own
//! confirmation. What the UI would confirm with the user reaches the app as a request
//! ([`Engine::watch_client_requests`]) that the user answers ([`Engine::answer_client_request`]).
//!
//! This part needs no async runtime and is always built; the MCP protocol on top of it is
//! `facade::mcp`, behind the `mcp` feature.

use std::cell::RefCell;
use std::collections::HashMap;
use std::fmt;
use std::future::Future;
use std::path::PathBuf;
use std::pin::Pin;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, PoisonError};
use std::task::{Context, Poll};

use ferman_render::DocumentId;
use ferman_text::BlockId;

use super::document::{DocumentStructure, page_info};
use super::edit::{EditPreview, Job, RevisionInfo, TransactionId};
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::guard_async;

/// A connected client's handle, never reused within a process.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct ClientId(u64);

impl ClientId {
    /// The raw value, for the UI.
    #[must_use]
    pub fn get(self) -> u64 {
        self.0
    }

    /// A client id from its raw value.
    #[must_use]
    pub fn from_raw(raw: u64) -> Self {
        Self(raw)
    }
}

/// The client ids handed out; 0 is never one.
static NEXT_CLIENT: AtomicU64 = AtomicU64::new(1);

/// A connected client.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClientInfo {
    /// Its handle.
    pub id: ClientId,
    /// The name it gave when it connected.
    pub name: String,
    /// Whether the user let it change documents; read only otherwise.
    pub may_edit: bool,
}

/// A document open in Ferman, as a client sees it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OpenDocumentInfo {
    /// Its handle.
    pub id: DocumentId,
    /// The name of the file it was opened from.
    pub name: String,
    /// Its title, from its information, as it stands now.
    pub title: Option<String>,
    /// How many pages it has now.
    pub pages: u32,
}

/// A step a client committed, for the app to redraw and update its undo list.
#[derive(Debug, Clone, PartialEq)]
pub struct ClientChange {
    /// The document it changed.
    pub document: DocumentId,
    /// The client's name, as the step names it.
    pub client: String,
    /// Where the history stands, with the pages to redraw.
    pub revision: RevisionInfo,
}

/// Receives the clients' changes, on the thread of the client's call.
pub trait ChangeSink: Send {
    /// Delivers one change.
    fn deliver(&mut self, change: ClientChange);
}

/// What a client asks the user to allow, as the UI would ask for the user's own action.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ClientRequestKind {
    /// Its first change to a signed document, which invalidates the signatures (a3-16a).
    EditSigned,
    /// Saving the document over its file. The app saves in its own flow (staging and the
    /// platform's swap) when the user allows, then answers.
    Save,
    /// Writing a new file at this path (compress, extract, split, combine).
    WriteFile(PathBuf),
    /// Reading the file at this path into the document (attach, combine).
    ReadFile(PathBuf),
    /// Placing a simple signature in the user's name.
    Sign,
    /// Restoring this version ([`VersionInfo::id`](super::VersionInfo::id)) over the document's
    /// file. The app restores it in its own flow when the user allows, then answers.
    RestoreVersion(u64),
}

/// A client's request the user answers in the app.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClientRequest {
    /// Its handle, for [`Engine::answer_client_request`].
    pub id: u64,
    /// The client that asks.
    pub client: ClientId,
    /// Its name.
    pub client_name: String,
    /// The document it is about, if any.
    pub document: Option<DocumentId>,
    /// What it asks.
    pub kind: ClientRequestKind,
}

/// Receives the clients' requests, on the thread of the client's call, under the engine's lock
/// of its clients: it hands them on and never calls the engine itself.
pub trait RequestSink: Send {
    /// Delivers one request.
    fn deliver(&mut self, request: ClientRequest);
}

/// The request ids handed out.
static NEXT_REQUEST: AtomicU64 = AtomicU64::new(1);

thread_local! {
    /// The client whose call the current poll of an [`Acting`] future runs.
    static ACTING: RefCell<Option<(ClientId, String)>> = const { RefCell::new(None) };
}

/// The client whose call runs on this thread now, and its name; `None` for the user's.
pub(super) fn acting() -> Option<(ClientId, String)> {
    ACTING.with_borrow(Clone::clone)
}

/// A facade call run for a client ([`Engine::as_client`]): while it is polled, [`acting`] names
/// the client, so each actor job it sends carries it.
pub struct Acting<F> {
    client: (ClientId, String),
    call: Pin<Box<F>>,
}

impl<F: Future> Future for Acting<F> {
    type Output = F::Output;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<F::Output> {
        /// Puts back what was acting, also when the call panics.
        struct Restore(Option<(ClientId, String)>);
        impl Drop for Restore {
            fn drop(&mut self) {
                ACTING.set(self.0.take());
            }
        }
        let _restore = Restore(ACTING.replace(Some(self.client.clone())));
        self.call.as_mut().poll(cx)
    }
}

/// The connected clients and the app's change stream.
#[derive(Default)]
pub(super) struct Clients {
    connected: HashMap<ClientId, Connected>,
    sink: Option<Box<dyn ChangeSink>>,
    requests: Option<Box<dyn RequestSink>>,
    /// The requests waiting for the user, with their client.
    pending: HashMap<u64, (ClientId, futures_channel::oneshot::Sender<bool>)>,
}

impl fmt::Debug for Clients {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Clients")
            .field("connected", &self.connected.len())
            .field("watched", &self.sink.is_some())
            .field("pending", &self.pending.len())
            .finish()
    }
}

#[derive(Debug)]
struct Connected {
    name: String,
    may_edit: bool,
    /// Its open transactions.
    transactions: Vec<TransactionId>,
}

fn no_client() -> ApiError {
    ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL).with_details("no such client")
}

fn no_transaction() -> ApiError {
    ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL).with_details("no such transaction")
}

impl Engine {
    fn clients(&self) -> std::sync::MutexGuard<'_, Clients> {
        self.clients.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Connects a client by the name it gives, read only until [`grant_edit`](Self::grant_edit).
    pub fn connect_client(&self, name: String) -> ClientId {
        let id = ClientId(NEXT_CLIENT.fetch_add(1, Ordering::Relaxed));
        self.clients().connected.insert(
            id,
            Connected {
                name,
                may_edit: false,
                transactions: Vec::new(),
            },
        );
        id
    }

    /// Disconnects a client: its open transactions are rolled back, after any call of theirs
    /// already sent to their document. Nothing happens for a client that is gone.
    pub fn disconnect_client(&self, client: ClientId) {
        let Some(connected) = ({
            let mut clients = self.clients();
            // Its requests are declined: their senders drop.
            clients.pending.retain(|_, (asker, _)| *asker != client);
            clients.connected.remove(&client)
        }) else {
            return;
        };
        for transaction in connected.transactions {
            self.drop_transaction(transaction);
        }
    }

    /// Rolls a transaction back without waiting: its actor runs the rollback after the jobs
    /// already in its mailbox.
    fn drop_transaction(&self, transaction: TransactionId) {
        let document = self
            .transactions
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&transaction);
        if let Some(mailbox) = document.and_then(|document| self.actor(document).ok()) {
            let job: Job = Box::new(move |session| {
                let _ = session.rollback(transaction);
            });
            let _ = mailbox.send(job);
        }
    }

    /// The connected clients, oldest first.
    #[must_use]
    pub fn connected_clients(&self) -> Vec<ClientInfo> {
        let mut clients: Vec<ClientInfo> = self
            .clients()
            .connected
            .iter()
            .map(|(id, connected)| ClientInfo {
                id: *id,
                name: connected.name.clone(),
                may_edit: connected.may_edit,
            })
            .collect();
        clients.sort_by_key(|client| client.id);
        clients
    }

    /// Lets `client` change documents, or makes it read only again; its open transactions stay.
    ///
    /// # Errors
    ///
    /// `NotFound` for a client that is not connected.
    pub fn grant_edit(&self, client: ClientId, may_edit: bool) -> Result<(), ApiError> {
        self.clients()
            .connected
            .get_mut(&client)
            .ok_or_else(no_client)?
            .may_edit = may_edit;
        Ok(())
    }

    /// Makes `sink` receive every step a client commits, in place of the one before.
    pub fn watch_client_changes(&self, sink: Box<dyn ChangeSink>) {
        self.clients().sink = Some(sink);
    }

    /// Makes `sink` receive every request a client makes of the user, in place of the one
    /// before. Without one, every request is declined.
    pub fn watch_client_requests(&self, sink: Box<dyn RequestSink>) {
        self.clients().requests = Some(sink);
    }

    /// The user's answer to `request`. Nothing happens for a request that is gone (answered, or
    /// its client disconnected).
    pub fn answer_client_request(&self, request: u64, allow: bool) {
        if let Some((_, answer)) = self.clients().pending.remove(&request) {
            let _ = answer.send(allow);
        }
    }

    /// Asks the user to allow `kind` for `client`, and waits for the answer.
    ///
    /// # Errors
    ///
    /// `PermissionDenied` when the user declines, when the app shows no requests, or when the
    /// client disconnects meanwhile.
    pub async fn ask_user(
        &self,
        client: ClientId,
        document: Option<DocumentId>,
        kind: ClientRequestKind,
    ) -> Result<(), ApiError> {
        let declined = || {
            ApiError::new(ErrorKind::PermissionDenied, MessageKey::INTERNAL)
                .with_details("the user did not allow it")
        };
        let answer = {
            let mut clients = self.clients();
            let client_name = clients
                .connected
                .get(&client)
                .ok_or_else(no_client)?
                .name
                .clone();
            let Some(requests) = clients.requests.as_mut() else {
                return Err(declined());
            };
            let id = NEXT_REQUEST.fetch_add(1, Ordering::Relaxed);
            requests.deliver(ClientRequest {
                id,
                client,
                client_name,
                document,
                kind,
            });
            // Under the same lock, so no answer comes before it waits.
            let (answer, waiting) = futures_channel::oneshot::channel();
            clients.pending.insert(id, (client, answer));
            waiting
        };
        match answer.await {
            Ok(true) => Ok(()),
            Ok(false) | Err(_) => Err(declined()),
        }
    }

    /// The client's name, when the user let it edit.
    fn editor(&self, client: ClientId) -> Result<String, ApiError> {
        let clients = self.clients();
        let connected = clients.connected.get(&client).ok_or_else(no_client)?;
        if !connected.may_edit {
            return Err(
                ApiError::new(ErrorKind::PermissionDenied, MessageKey::INTERNAL)
                    .with_details("the client may only read"),
            );
        }
        Ok(connected.name.clone())
    }

    /// `call`, a facade call, run for `client`: its step names the client and a signed document
    /// asks for the client's own confirmation. Report its change with
    /// [`report_client_change`](Self::report_client_change).
    ///
    /// # Errors
    ///
    /// `PermissionDenied` for a client the user has not let edit, `NotFound` for one that is not
    /// connected.
    pub fn as_client<F: Future>(&self, client: ClientId, call: F) -> Result<Acting<F>, ApiError> {
        Ok(Acting {
            client: (client, self.editor(client)?),
            call: Box::pin(call),
        })
    }

    /// Hands a step `client` committed to the app's change stream.
    pub fn report_client_change(
        &self,
        client: ClientId,
        document: DocumentId,
        revision: &RevisionInfo,
    ) {
        let mut clients = self.clients();
        let name = clients
            .connected
            .get(&client)
            .map(|connected| connected.name.clone())
            .unwrap_or_default();
        if let Some(sink) = &mut clients.sink {
            sink.deliver(ClientChange {
                document,
                client: name,
                revision: revision.clone(),
            });
        }
    }

    /// `document`'s pages, outline, attachments and information as they stand now.
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open.
    pub fn document_now(&self, document: DocumentId) -> Result<DocumentStructure, ApiError> {
        let models = self.models()?;
        let model = models
            .get(&document)
            .ok_or_else(|| ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL))?;
        let store = Arc::clone(&model.revised().store);
        let doc = &model.document;
        Ok(DocumentStructure {
            pages: store.pages(doc).iter().map(page_info).collect(),
            outline: store.outline(doc).to_vec(),
            attachments: store.attachments(doc).to_vec(),
            info: store.info(doc).clone(),
        })
    }

    /// The documents open in Ferman, oldest first, as they stand now.
    ///
    /// # Errors
    ///
    /// `Internal` when the models' lock is poisoned.
    pub fn open_documents(&self) -> Result<Vec<OpenDocumentInfo>, ApiError> {
        let mut documents: Vec<OpenDocumentInfo> = self
            .models()?
            .iter()
            .map(|(id, model)| {
                let store = Arc::clone(&model.revised().store);
                // shortcut: the name is the opened file's, not the one Save as moved it to; read
                // the actor's path once a client shows the difference.
                let name = model
                    .path
                    .file_name()
                    .map(|name| name.to_string_lossy().into_owned())
                    .unwrap_or_default();
                OpenDocumentInfo {
                    id: *id,
                    name,
                    title: store.info(&model.document).title.clone(),
                    pages: u32::try_from(store.pages(&model.document).len()).unwrap_or(u32::MAX),
                }
            })
            .collect();
        documents.sort_by_key(|document| document.id.get());
        Ok(documents)
    }

    /// The user's confirmation that `client` may change the signed `document` (a3-16a, asked
    /// for the client's first commit even after the user's own).
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open.
    pub async fn confirm_client_signed(
        &self,
        document: DocumentId,
        client: ClientId,
    ) -> Result<(), ApiError> {
        guard_async(async move {
            self.ask(document, move |session| {
                session.confirm_client(client);
                Ok(())
            })
            .await
        })
        .await
    }

    /// Begins `client`'s transaction on a block, as [`begin_edit`](Self::begin_edit) does for
    /// the user. While another transaction of the document is open (the user's edit, another
    /// client's), it waits for it to end.
    ///
    /// # Errors
    ///
    /// `PermissionDenied` for a client the user has not let edit, `NotFound` for a client that is
    /// not connected (or disconnected while it waited), `InvalidInput` while its own transaction
    /// of the document is open, and the errors of [`begin_edit`](Self::begin_edit).
    pub async fn client_begin_edit(
        &self,
        client: ClientId,
        document: DocumentId,
        page: u32,
        block: BlockId,
    ) -> Result<TransactionId, ApiError> {
        guard_async(async move {
            let name = self.editor(client)?;
            let transaction = loop {
                let owner = (client, name.clone());
                let begun = self
                    .ask(document, move |session| {
                        session.begin_for_client(page, block, owner)
                    })
                    .await?;
                match begun {
                    Ok(transaction) => break transaction,
                    // The actor dropped the waiter: the document closed.
                    Err(waiting) => waiting.await.map_err(|_canceled| {
                        ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
                    })?,
                }
            };
            self.transactions
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .insert(transaction, document);
            let kept = self
                .clients()
                .connected
                .get_mut(&client)
                .map(|connected| connected.transactions.push(transaction))
                .is_some();
            if !kept {
                // It disconnected while this began.
                self.drop_transaction(transaction);
                return Err(no_client());
            }
            Ok(transaction)
        })
        .await
    }

    /// Fails unless `transaction` is `client`'s.
    fn owned(&self, client: ClientId, transaction: TransactionId) -> Result<(), ApiError> {
        let clients = self.clients();
        let connected = clients.connected.get(&client).ok_or_else(no_client)?;
        if !connected.transactions.contains(&transaction) {
            return Err(no_transaction());
        }
        Ok(())
    }

    /// Forgets `client`'s transactions that ended.
    fn forget_ended(&self, client: ClientId) {
        let open = self
            .transactions
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .clone();
        if let Some(connected) = self.clients().connected.get_mut(&client) {
            connected
                .transactions
                .retain(|transaction| open.contains_key(transaction));
        }
    }

    /// [`apply`](Self::apply) on `client`'s own transaction.
    ///
    /// # Errors
    ///
    /// `NotFound` for a transaction that is not the client's, and the errors of
    /// [`apply`](Self::apply).
    pub async fn client_apply(
        &self,
        client: ClientId,
        transaction: TransactionId,
        text: String,
    ) -> Result<EditPreview, ApiError> {
        self.owned(client, transaction)?;
        self.apply(transaction, text).await
    }

    /// [`commit`](Self::commit) of `client`'s own transaction: the step names the client, and
    /// the app hears of it through [`watch_client_changes`](Self::watch_client_changes).
    ///
    /// # Errors
    ///
    /// `NotFound` for a transaction that is not the client's, `ConfirmationRequired` for its
    /// first change to a signed document before
    /// [`confirm_client_signed`](Self::confirm_client_signed), and the errors of
    /// [`commit`](Self::commit).
    pub async fn client_commit(
        &self,
        client: ClientId,
        transaction: TransactionId,
        name: String,
    ) -> Result<RevisionInfo, ApiError> {
        self.owned(client, transaction)?;
        let document = self.transaction_document(transaction)?;
        let result = self.commit(transaction, name).await;
        self.forget_ended(client);
        let revision = result?;
        self.report_client_change(client, document, &revision);
        Ok(revision)
    }

    /// [`rollback`](Self::rollback) of `client`'s own transaction.
    ///
    /// # Errors
    ///
    /// `NotFound` for a transaction that is not the client's.
    pub async fn client_rollback(
        &self,
        client: ClientId,
        transaction: TransactionId,
    ) -> Result<RevisionInfo, ApiError> {
        self.owned(client, transaction)?;
        let result = self.rollback(transaction).await;
        self.forget_ended(client);
        result
    }
}
