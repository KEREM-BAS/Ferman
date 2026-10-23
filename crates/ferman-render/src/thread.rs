//! The render thread: one dedicated thread that owns PDFium and every document loaded into it.
//!
//! PDFium is not thread-safe, so every PDFium call runs on this thread (docs/ARCHITECTURE.md §4.4,
//! ADR 0009). pdfium-render's `thread_safe` feature stays on as a second guard. Callers send
//! messages over a crossbeam channel; a call that answers gets its reply through a oneshot future,
//! so an async API function awaits it without blocking a thread.
//!
//! The thread takes every waiting message before each item it renders, so a new wanted set
//! replaces the old one before the next tile starts, and again after rendering, so the bitmap goes
//! to the views that want it now (see [`crate::queue`]). Rendered bitmaps go through the caches of
//! [`crate::cache`] first.

use std::collections::HashMap;
use std::future::Future;
use std::num::NonZeroUsize;
use std::ops::ControlFlow;
use std::path::PathBuf;
use std::sync::Arc;
use std::thread::{self, JoinHandle};

use crossbeam_channel::{Receiver, Sender, TryRecvError};
use ferman_core::Password;
use futures_channel::oneshot;
use pdfium_render::prelude::Pdfium;

use crate::cache::{Bitmap, BitmapCache, BitmapKey};
use crate::document::LoadedDocument;
use crate::queue::Queue;
use crate::tiles::{Failed, Item, PageSize, Rendered, ViewEvent, ViewSink, Wanted};
use crate::{PDFIUM_TAG, RenderError, library};

/// The name of the render thread, as debuggers and crash reports show it.
pub const THREAD_NAME: &str = "ferman-render";

/// One mebibyte.
const MIB: usize = 1024 * 1024;

/// What the render thread needs to start.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RenderConfig {
    /// The PDFium shared library to load: `libpdfium.so`, `pdfium.dll` or `libpdfium.dylib`, as an
    /// explicit path (ferman-api resolves where it is). `None` starts the thread without PDFium,
    /// and its status is then [`PdfiumStatus::NotLoaded`].
    pub pdfium_library: Option<PathBuf>,
    /// The tile cache's cap in bytes of pixels; 0 keeps no tiles. Default 256 MiB. ferman-api sets
    /// it from Settings › Advanced (a11-1k), clamped to a share of memory (§4.7, Proposed).
    pub tile_cache_bytes: usize,
    /// The thumbnail cache's cap in bytes of pixels; 0 keeps none. Default 64 MiB.
    pub thumbnail_cache_bytes: usize,
    /// How many pages of each document stay loaded in PDFium, at least 1. Default 8 (§4.7,
    /// Proposed).
    pub loaded_pages: usize,
}

impl Default for RenderConfig {
    fn default() -> Self {
        Self {
            pdfium_library: None,
            tile_cache_bytes: 256 * MIB,
            thumbnail_cache_bytes: 64 * MIB,
            loaded_pages: 8,
        }
    }
}

/// Whether the render thread has a working PDFium.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PdfiumStatus {
    /// No PDFium library was given to load.
    NotLoaded,
    /// PDFium is bound and a real call into it succeeded.
    Loaded {
        /// The pinned build tag, [`PDFIUM_TAG`]. PDFium has no runtime version API, so this is
        /// the pin recorded with `tools/pdfium`, not a value read from the library.
        tag: &'static str,
    },
    /// A library was given but it could not be bound, or the first call into it failed.
    Failed {
        /// Technical text for logs and bug reports. It never contains the library path.
        reason: String,
    },
}

/// A document loaded on the render thread. Never reused within a process.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct DocumentId(pub(crate) u64);

impl DocumentId {
    /// The number behind the id.
    #[must_use]
    pub fn get(self) -> u64 {
        self.0
    }

    /// The id behind a number from [`get`](Self::get), as a handle that crossed the bridge. A
    /// number that names no open document gives [`RenderError::NotFound`].
    #[must_use]
    pub fn from_raw(raw: u64) -> Self {
        Self(raw)
    }
}

/// A view of a document: the canvas, the thumbnail strip, and later split view, compare and
/// version preview each open their own. Never reused within a process.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct ViewId(pub(crate) u64);

impl ViewId {
    /// The number behind the id.
    #[must_use]
    pub fn get(self) -> u64 {
        self.0
    }

    /// The id behind a number from [`get`](Self::get), as a handle that crossed the bridge. A
    /// number that names no open view gives [`RenderError::NotFound`].
    #[must_use]
    pub fn from_raw(raw: u64) -> Self {
        Self(raw)
    }
}

/// A document PDFium opened.
#[derive(Debug, Clone, PartialEq)]
pub struct OpenedDocument {
    /// Its id on the render thread.
    pub id: DocumentId,
    /// Every page's size in points as displayed, read without loading the pages.
    pub pages: Vec<PageSize>,
}

/// A message to the render thread. Those that answer carry the sender of their reply.
enum Message {
    Status(oneshot::Sender<PdfiumStatus>),
    Open {
        bytes: Arc<[u8]>,
        password: Option<Password>,
        reply: oneshot::Sender<Result<OpenedDocument, RenderError>>,
    },
    Close {
        document: DocumentId,
        reply: oneshot::Sender<Result<(), RenderError>>,
    },
    OpenView {
        document: DocumentId,
        sink: Box<dyn ViewSink>,
        reply: oneshot::Sender<Result<ViewId, RenderError>>,
    },
    Want {
        view: ViewId,
        generation: u64,
        wanted: Vec<Wanted>,
    },
    CloseView(ViewId),
}

/// The handle of the render thread.
///
/// Dropping it closes the message channel, lets the thread finish the item it is rendering, close
/// every document and PDFium on its own thread and exit, and waits for that. pdfium-render keeps
/// the library bound until the process ends (it has no unbind), so a later render thread in the
/// same process reuses the binding for the same file.
#[derive(Debug)]
pub struct RenderThread {
    messages: Option<Sender<Message>>,
    handle: Option<JoinHandle<()>>,
}

impl RenderThread {
    /// Starts the render thread, which loads the configured PDFium library before it answers its
    /// first message.
    ///
    /// A library that does not load is not an error here: the thread keeps running and reports
    /// [`PdfiumStatus::Failed`], so the app can show an error screen instead of crashing.
    ///
    /// # Errors
    ///
    /// Returns [`RenderError::ThreadStart`] if the operating system cannot start the thread.
    pub fn start(config: RenderConfig) -> Result<Self, RenderError> {
        let (messages, inbox) = crossbeam_channel::unbounded();
        let handle = thread::Builder::new()
            .name(THREAD_NAME.to_owned())
            .spawn(move || run(config, &inbox))
            .map_err(|source| RenderError::ThreadStart { source })?;
        Ok(Self {
            messages: Some(messages),
            handle: Some(handle),
        })
    }

    /// Asks the render thread whether PDFium is loaded.
    ///
    /// The message is sent at once; the returned future only waits for the reply, so it can be
    /// awaited from an async API function without blocking. It does not borrow `self`.
    ///
    /// # Errors
    ///
    /// The future resolves to [`RenderError::ThreadStopped`] if the thread is no longer running.
    pub fn status(
        &self,
    ) -> impl Future<Output = Result<PdfiumStatus, RenderError>> + Send + 'static {
        let reply = self.ask(Message::Status);
        async move { reply?.await.map_err(|_canceled| RenderError::ThreadStopped) }
    }

    /// Loads a document into PDFium from `bytes`, which it reads in place for as long as the
    /// document is open, and reads its page sizes. An encrypted document needs `password`, which
    /// is wiped from Ferman's memory once PDFium has it; what PDFium keeps is Q22.
    ///
    /// # Errors
    ///
    /// The future resolves to [`RenderError::PdfiumUnavailable`] without PDFium,
    /// [`RenderError::PasswordRequired`] for an encrypted document without its password,
    /// [`RenderError::WrongPassword`] for a password that does not open it,
    /// [`RenderError::UnsupportedSecurity`] for a security handler PDFium does not have,
    /// [`RenderError::Damaged`] when PDFium cannot read it, and [`RenderError::ThreadStopped`]
    /// if the thread is no longer running.
    pub fn open_document(
        &self,
        bytes: Arc<[u8]>,
        password: Option<Password>,
    ) -> impl Future<Output = Result<OpenedDocument, RenderError>> + Send + 'static {
        let reply = self.ask(|reply| Message::Open {
            bytes,
            password,
            reply,
        });
        async move { flatten(reply?.await) }
    }

    /// Closes a document: its views end, its cached bitmaps are dropped, and PDFium closes it.
    ///
    /// # Errors
    ///
    /// The future resolves to [`RenderError::NotFound`] for a document that is not open, and to
    /// [`RenderError::ThreadStopped`] if the thread is no longer running.
    pub fn close_document(
        &self,
        document: DocumentId,
    ) -> impl Future<Output = Result<(), RenderError>> + Send + 'static {
        let reply = self.ask(|reply| Message::Close { document, reply });
        async move { flatten(reply?.await) }
    }

    /// Opens a view of `document` whose events go to `sink`, with an empty wanted set. The view
    /// ends, and `sink` is dropped, when it is closed, when its document closes or when `sink`
    /// reports its receiver gone.
    ///
    /// # Errors
    ///
    /// The future resolves to [`RenderError::NotFound`] for a document that is not open, and to
    /// [`RenderError::ThreadStopped`] if the thread is no longer running.
    pub fn open_view(
        &self,
        document: DocumentId,
        sink: Box<dyn ViewSink>,
    ) -> impl Future<Output = Result<ViewId, RenderError>> + Send + 'static {
        let reply = self.ask(|reply| Message::OpenView {
            document,
            sink,
            reply,
        });
        async move { flatten(reply?.await) }
    }

    /// Replaces the wanted set of `view`, in priority order. A `generation` no newer than the
    /// view's last one is ignored, so an old set never replaces a newer one. An item the
    /// document cannot render (no such page, out of range) is answered at once with
    /// [`ViewEvent::Failed`]. A view that is not open ignores it.
    ///
    /// # Errors
    ///
    /// Returns [`RenderError::ThreadStopped`] if the thread is no longer running.
    pub fn request(
        &self,
        view: ViewId,
        generation: u64,
        wanted: Vec<Wanted>,
    ) -> Result<(), RenderError> {
        self.send(Message::Want {
            view,
            generation,
            wanted,
        })
    }

    /// Closes a view: its queued items are dropped and its sink with them.
    ///
    /// # Errors
    ///
    /// Returns [`RenderError::ThreadStopped`] if the thread is no longer running.
    pub fn close_view(&self, view: ViewId) -> Result<(), RenderError> {
        self.send(Message::CloseView(view))
    }

    /// Sends a message that answers and returns the receiver of its reply.
    fn ask<T>(
        &self,
        message: impl FnOnce(oneshot::Sender<T>) -> Message,
    ) -> Result<oneshot::Receiver<T>, RenderError> {
        let (reply, receiver) = oneshot::channel();
        self.send(message(reply))?;
        Ok(receiver)
    }

    fn send(&self, message: Message) -> Result<(), RenderError> {
        self.messages
            .as_ref()
            .ok_or(RenderError::ThreadStopped)?
            .send(message)
            .map_err(|_closed| RenderError::ThreadStopped)
    }
}

/// A reply that may not have come, because the thread stopped first.
fn flatten<T>(reply: Result<Result<T, RenderError>, oneshot::Canceled>) -> Result<T, RenderError> {
    reply.map_err(|_canceled| RenderError::ThreadStopped)?
}

impl Drop for RenderThread {
    fn drop(&mut self) {
        // Closing the channel ends the thread's loop.
        drop(self.messages.take());
        if let Some(handle) = self.handle.take()
            && handle.join().is_err()
        {
            // The panic itself went to the panic hook; its payload can hold any text, so it is not
            // logged here (docs/ARCHITECTURE.md §8.4).
            tracing::error!("the render thread ended with a panic");
        }
    }
}

/// The body of the render thread: load PDFium, then take messages and render until the channel
/// closes.
fn run(config: RenderConfig, inbox: &Receiver<Message>) {
    let (loaded, status): (Option<(Pdfium, library::Owner)>, PdfiumStatus) =
        match config.pdfium_library.as_ref() {
            None => (None, PdfiumStatus::NotLoaded),
            Some(path) => match library::load(path) {
                Ok(loaded) => {
                    tracing::info!(path = %path.display(), tag = PDFIUM_TAG, "PDFium loaded");
                    (Some(loaded), PdfiumStatus::Loaded { tag: PDFIUM_TAG })
                }
                Err(err) => (
                    None,
                    PdfiumStatus::Failed {
                        reason: err.to_string(),
                    },
                ),
            },
        };
    let (pdfium, owner) = loaded.unzip();
    let mut state = State::new(pdfium.as_ref(), status, &config);
    loop {
        let message = if state.queue.has_work() {
            match inbox.try_recv() {
                Ok(message) => Some(message),
                Err(TryRecvError::Empty) => None,
                Err(TryRecvError::Disconnected) => break,
            }
        } else {
            match inbox.recv() {
                Ok(message) => Some(message),
                Err(_closed) => break,
            }
        };
        let flow = match message {
            Some(message) => {
                state.handle(message);
                ControlFlow::Continue(())
            }
            None => state.work(inbox),
        };
        if flow.is_break() {
            break;
        }
    }
    // Documents (and their pages) close before PDFium is dropped, all on this thread; then another
    // render thread may have PDFium.
    drop(state);
    drop(pdfium);
    drop(owner);
}

/// Everything the render thread holds besides PDFium itself.
struct State<'p> {
    pdfium: Option<&'p Pdfium>,
    status: PdfiumStatus,
    documents: HashMap<DocumentId, LoadedDocument<'p>>,
    queue: Queue,
    tiles: BitmapCache,
    thumbnails: BitmapCache,
    loaded_pages: NonZeroUsize,
    /// The last id given to a document or a view.
    last_id: u64,
}

impl<'p> State<'p> {
    fn new(pdfium: Option<&'p Pdfium>, status: PdfiumStatus, config: &RenderConfig) -> Self {
        Self {
            pdfium,
            status,
            documents: HashMap::new(),
            queue: Queue::default(),
            tiles: BitmapCache::new(config.tile_cache_bytes),
            thumbnails: BitmapCache::new(config.thumbnail_cache_bytes),
            loaded_pages: NonZeroUsize::new(config.loaded_pages).unwrap_or(NonZeroUsize::MIN),
            last_id: 0,
        }
    }

    fn next_id(&mut self) -> u64 {
        self.last_id = self.last_id.saturating_add(1);
        self.last_id
    }

    fn handle(&mut self, message: Message) {
        // A caller may have stopped waiting for a reply; that is not an error.
        match message {
            Message::Status(reply) => {
                let _ = reply.send(self.status.clone());
            }
            Message::Open {
                bytes,
                password,
                reply,
            } => {
                let opened = self.open(bytes, password.as_ref());
                if let Err(Ok(unclaimed)) = reply.send(opened) {
                    // Nobody will ever know its id, so nobody could close it.
                    self.close(unclaimed.id);
                }
            }
            Message::Close { document, reply } => {
                let closed = if self.documents.contains_key(&document) {
                    self.close(document);
                    Ok(())
                } else {
                    Err(RenderError::NotFound { what: "document" })
                };
                let _ = reply.send(closed);
            }
            Message::OpenView {
                document,
                sink,
                reply,
            } => {
                if self.documents.contains_key(&document) {
                    let view = ViewId(self.next_id());
                    self.queue.open(view, document, sink);
                    if reply.send(Ok(view)).is_err() {
                        self.queue.close(view);
                    }
                } else {
                    let _ = reply.send(Err(RenderError::NotFound { what: "document" }));
                }
            }
            Message::Want {
                view,
                generation,
                wanted,
            } => self.want(view, generation, &wanted),
            Message::CloseView(view) => self.queue.close(view),
        }
    }

    fn open(
        &mut self,
        bytes: Arc<[u8]>,
        password: Option<&Password>,
    ) -> Result<OpenedDocument, RenderError> {
        let pdfium = self.pdfium.ok_or_else(|| RenderError::PdfiumUnavailable {
            reason: match &self.status {
                PdfiumStatus::Failed { reason } => reason.clone(),
                _ => "PDFium is not loaded".to_owned(),
            },
        })?;
        let document = LoadedDocument::load(pdfium, bytes, password, self.loaded_pages)?;
        let pages = document.sizes().to_vec();
        let id = DocumentId(self.next_id());
        self.documents.insert(id, document);
        Ok(OpenedDocument { id, pages })
    }

    fn close(&mut self, document: DocumentId) {
        self.queue.close_document(document);
        self.tiles.retain(|key| key.document != document);
        self.thumbnails.retain(|key| key.document != document);
        // Its pages close first, then the document, in LoadedDocument's drop.
        self.documents.remove(&document);
    }

    /// Takes a new wanted set: the items the document can render are queued, the others answered
    /// with their failure at once.
    fn want(&mut self, view: ViewId, generation: u64, wanted: &[Wanted]) {
        if !self.queue.is_newer(view, generation) {
            return;
        }
        let Some(document) = self
            .queue
            .document(view)
            .and_then(|document| self.documents.get(&document))
        else {
            return;
        };
        let (valid, invalid): (Vec<Wanted>, Vec<Wanted>) = wanted
            .iter()
            .partition(|entry| document.check(&entry.item).is_ok());
        let failures: Vec<Failed> = invalid
            .iter()
            .filter_map(|entry| {
                let reason = document.check(&entry.item).err()?;
                Some(Failed {
                    item: entry.item,
                    generation,
                    reason,
                })
            })
            .collect();
        self.queue.replace(view, generation, &valid);
        for failed in failures {
            self.queue.send(view, ViewEvent::Failed(failed));
        }
    }

    /// Renders, or takes from a cache, the next queued item and delivers it.
    fn work(&mut self, inbox: &Receiver<Message>) -> ControlFlow<()> {
        let Some((document, item)) = self.queue.next() else {
            return ControlFlow::Continue(());
        };
        let Some(loaded) = self.documents.get_mut(&document) else {
            // Closing a document closes its views, so this does not happen; drop them anyway.
            self.queue.close_document(document);
            return ControlFlow::Continue(());
        };
        let render_key = loaded.render_key(item.page());
        let key = BitmapKey {
            document,
            render_key,
            item,
        };
        let cache = match item {
            Item::Tile(_) => &mut self.tiles,
            Item::Thumbnail(_) => &mut self.thumbnails,
        };
        if let Some(bitmap) = cache.get(&key) {
            self.queue.deliver(document, &item, |generation| {
                rendered(item, render_key, generation, bitmap)
            });
            return ControlFlow::Continue(());
        }
        let result = loaded.render(&item);
        // Messages that came in while it rendered decide who wants it now.
        loop {
            match inbox.try_recv() {
                Ok(message) => self.handle(message),
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => return ControlFlow::Break(()),
            }
        }
        if !self.documents.contains_key(&document) {
            return ControlFlow::Continue(());
        }
        match result {
            Ok(bitmap) => {
                self.queue.deliver(document, &item, |generation| {
                    rendered(item, render_key, generation, &bitmap)
                });
                let cache = match item {
                    Item::Tile(_) => &mut self.tiles,
                    Item::Thumbnail(_) => &mut self.thumbnails,
                };
                cache.insert(key, bitmap);
            }
            Err(reason) => {
                tracing::warn!(page = item.page(), ?reason, "an item did not render");
                self.queue.deliver(document, &item, |generation| {
                    ViewEvent::Failed(Failed {
                        item,
                        generation,
                        reason,
                    })
                });
            }
        }
        ControlFlow::Continue(())
    }
}

/// The event for a bitmap, with its own copy of the pixels.
fn rendered(item: Item, render_key: u64, generation: u64, bitmap: &Bitmap) -> ViewEvent {
    ViewEvent::Rendered(Rendered {
        item,
        render_key,
        generation,
        rect: bitmap.rect,
        stride: bitmap.rect.width.saturating_mul(4),
        pixels: bitmap.pixels.clone(),
    })
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use std::sync::{Mutex, MutexGuard, PoisonError};
    use std::task::{Context, Poll, Waker};

    /// Taken by every test of this binary that loads PDFium, because only one render thread may
    /// hold it at a time.
    pub(crate) fn serial() -> MutexGuard<'static, ()> {
        static SERIAL: Mutex<()> = Mutex::new(());
        SERIAL.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Polls a future on this thread until it is ready. The render thread wakes it through the
    /// oneshot channel; the test just spins, which is fine for a few microseconds.
    fn wait<F: Future>(future: F) -> F::Output {
        let mut future = std::pin::pin!(future);
        let mut cx = Context::from_waker(Waker::noop());
        loop {
            if let Poll::Ready(output) = future.as_mut().poll(&mut cx) {
                return output;
            }
            thread::yield_now();
        }
    }

    fn with_library(path: PathBuf) -> RenderConfig {
        RenderConfig {
            pdfium_library: Some(path),
            ..RenderConfig::default()
        }
    }

    #[test]
    fn without_a_library_the_status_is_not_loaded() {
        let render = RenderThread::start(RenderConfig::default()).unwrap();
        assert_eq!(wait(render.status()).unwrap(), PdfiumStatus::NotLoaded);
    }

    #[test]
    fn without_pdfium_a_document_does_not_open() {
        let render = RenderThread::start(RenderConfig::default()).unwrap();
        let bytes: Arc<[u8]> = Arc::from(&b"%PDF-1.7\n"[..]);
        match wait(render.open_document(bytes, None)) {
            Err(RenderError::PdfiumUnavailable { reason }) => {
                assert_eq!(reason, "PDFium is not loaded");
            }
            other => panic!("expected PdfiumUnavailable, got {other:?}"),
        }
    }

    #[test]
    fn unknown_documents_and_views_are_not_found() {
        let render = RenderThread::start(RenderConfig::default()).unwrap();
        assert!(matches!(
            wait(render.close_document(DocumentId(7))),
            Err(RenderError::NotFound { what: "document" })
        ));
        let (sender, receiver) = crossbeam_channel::unbounded::<ViewEvent>();
        assert!(matches!(
            wait(render.open_view(DocumentId(7), Box::new(sender))),
            Err(RenderError::NotFound { what: "document" })
        ));
        // The sink was dropped with the refused view, so its stream has ended.
        assert!(receiver.recv().is_err());
        // Requests to a view that is not open are ignored.
        render.request(ViewId(3), 1, Vec::new()).unwrap();
        render.close_view(ViewId(3)).unwrap();
        assert_eq!(wait(render.status()).unwrap(), PdfiumStatus::NotLoaded);
    }

    #[test]
    fn a_missing_library_is_failed_without_its_path() {
        let _serial = serial();
        let path = std::env::temp_dir()
            .join(format!("ferman-render-missing-{}", std::process::id()))
            .join("libpdfium.so");
        let render = RenderThread::start(with_library(path)).unwrap();
        match wait(render.status()).unwrap() {
            PdfiumStatus::Failed { reason } => {
                assert!(!reason.is_empty());
                assert!(!reason.contains("ferman-render-missing"), "{reason}");
            }
            other => panic!("expected Failed, got {other:?}"),
        }
        // Opening a document says why PDFium is missing, still without the path.
        match wait(render.open_document(Arc::from(&b"%PDF-1.7\n"[..]), None)) {
            Err(RenderError::PdfiumUnavailable { reason }) => {
                assert!(!reason.contains("ferman-render-missing"), "{reason}");
            }
            other => panic!("expected PdfiumUnavailable, got {other:?}"),
        }
    }

    #[test]
    fn a_file_that_is_not_a_library_is_failed_without_its_path() {
        let _serial = serial();
        let dir =
            std::env::temp_dir().join(format!("ferman-render-garbage-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("libpdfium.so");
        std::fs::write(&path, b"this is not a shared library").unwrap();
        let render = RenderThread::start(with_library(path)).unwrap();
        let status = wait(render.status()).unwrap();
        drop(render);
        std::fs::remove_dir_all(&dir).unwrap();
        match status {
            PdfiumStatus::Failed { reason } => {
                assert!(!reason.contains("ferman-render-garbage"), "{reason}");
            }
            other => panic!("expected Failed, got {other:?}"),
        }
    }

    #[test]
    fn drop_waits_for_the_thread_to_exit() {
        let render = RenderThread::start(RenderConfig::default()).unwrap();
        let thread = render.handle.as_ref().unwrap().thread().clone();
        assert_eq!(thread.name(), Some(THREAD_NAME));
        let status = render.status();
        drop(render);
        // The thread answered the message sent before the drop, then exited; the drop joined it.
        assert_eq!(wait(status).unwrap(), PdfiumStatus::NotLoaded);
    }

    #[test]
    fn the_handle_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<RenderThread>();
    }

    #[test]
    fn the_default_caps_are_the_documented_ones() {
        let config = RenderConfig::default();
        assert_eq!(config.tile_cache_bytes, 256 * MIB);
        assert_eq!(config.thumbnail_cache_bytes, 64 * MIB);
        assert_eq!(config.loaded_pages, 8);
        assert_eq!(config.pdfium_library, None);
    }

    fn pdfium_path() -> PathBuf {
        let path = std::env::var_os("FERMAN_PDFIUM_PATH")
            .filter(|value| !value.is_empty())
            .expect("FERMAN_PDFIUM_PATH must name the PDFium library (tools/pdfium/fetch.sh)");
        PathBuf::from(path)
    }

    #[test]
    #[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
    fn pdfium_loads_and_reports_the_pinned_tag() {
        let _serial = serial();
        let render = RenderThread::start(with_library(pdfium_path())).unwrap();
        assert_eq!(
            wait(render.status()).unwrap(),
            PdfiumStatus::Loaded {
                tag: "chromium/7881"
            }
        );
    }

    #[test]
    #[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
    fn a_second_render_thread_reuses_the_binding() {
        let _serial = serial();
        let path = pdfium_path();
        for _ in 0..3 {
            let render = RenderThread::start(with_library(path.clone())).unwrap();
            assert!(matches!(
                wait(render.status()).unwrap(),
                PdfiumStatus::Loaded { .. }
            ));
        }
    }

    #[test]
    #[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
    fn a_second_render_thread_at_once_is_refused_until_the_first_stops() {
        let _serial = serial();
        let path = pdfium_path();
        let first = RenderThread::start(with_library(path.clone())).unwrap();
        assert_eq!(
            wait(first.status()).unwrap(),
            PdfiumStatus::Loaded { tag: PDFIUM_TAG }
        );
        let second = RenderThread::start(with_library(path.clone())).unwrap();
        assert_eq!(
            wait(second.status()).unwrap(),
            PdfiumStatus::Failed {
                reason: RenderError::PdfiumInUse.to_string()
            }
        );
        drop(second);
        drop(first);
        let third = RenderThread::start(with_library(path)).unwrap();
        assert_eq!(
            wait(third.status()).unwrap(),
            PdfiumStatus::Loaded { tag: PDFIUM_TAG }
        );
    }

    #[test]
    #[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
    fn another_library_after_binding_is_refused() {
        let _serial = serial();
        let render = RenderThread::start(with_library(pdfium_path())).unwrap();
        assert!(matches!(
            wait(render.status()).unwrap(),
            PdfiumStatus::Loaded { .. }
        ));
        drop(render);
        let other =
            RenderThread::start(with_library(PathBuf::from("/no/such/dir/libpdfium.so"))).unwrap();
        assert_eq!(
            wait(other.status()).unwrap(),
            PdfiumStatus::Failed {
                reason: RenderError::PdfiumAlreadyBound.to_string()
            }
        );
    }
}
