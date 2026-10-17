//! The render thread: one dedicated thread that owns PDFium.
//!
//! PDFium is not thread-safe, so every PDFium call runs on this thread (docs/ARCHITECTURE.md §4.4,
//! ADR 0009). pdfium-render's `thread_safe` feature stays on as a second guard. Callers send
//! requests over a channel and get each reply through a oneshot future, so an async API function
//! awaits the answer without blocking a thread.
//!
//! In M1 the thread loads PDFium and answers one request: its status. Rendering arrives in M2.

use std::future::Future;
use std::path::PathBuf;
use std::sync::mpsc;
use std::thread::{self, JoinHandle};

use futures_channel::oneshot;
use pdfium_render::prelude::Pdfium;

use crate::{PDFIUM_TAG, RenderError, library};

/// The name of the render thread, as debuggers and crash reports show it.
pub const THREAD_NAME: &str = "ferman-render";

/// What the render thread needs to start.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct RenderConfig {
    /// The PDFium shared library to load: `libpdfium.so`, `pdfium.dll` or `libpdfium.dylib`, as an
    /// explicit path (ferman-api resolves where it is). `None` starts the thread without PDFium,
    /// and its status is then [`PdfiumStatus::NotLoaded`].
    pub pdfium_library: Option<PathBuf>,
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

/// A request to the render thread. Each carries the sender of its reply.
enum Request {
    Status(oneshot::Sender<PdfiumStatus>),
}

/// The handle of the render thread.
///
/// Dropping it closes the request channel, lets the thread finish the request it is working on,
/// drop PDFium on its own thread and exit, and waits for that. pdfium-render keeps the library
/// bound until the process ends (it has no unbind), so a later render thread in the same process
/// reuses the binding for the same file.
#[derive(Debug)]
pub struct RenderThread {
    requests: Option<mpsc::Sender<Request>>,
    handle: Option<JoinHandle<()>>,
}

impl RenderThread {
    /// Starts the render thread, which loads the configured PDFium library before it answers its
    /// first request.
    ///
    /// A library that does not load is not an error here: the thread keeps running and reports
    /// [`PdfiumStatus::Failed`], so the app can show an error screen instead of crashing.
    ///
    /// # Errors
    ///
    /// Returns [`RenderError::ThreadStart`] if the operating system cannot start the thread.
    pub fn start(config: RenderConfig) -> Result<Self, RenderError> {
        let (requests, inbox) = mpsc::channel();
        let handle = thread::Builder::new()
            .name(THREAD_NAME.to_owned())
            .spawn(move || run(config, &inbox))
            .map_err(|source| RenderError::ThreadStart { source })?;
        Ok(Self {
            requests: Some(requests),
            handle: Some(handle),
        })
    }

    /// Asks the render thread whether PDFium is loaded.
    ///
    /// The request is sent at once; the returned future only waits for the reply, so it can be
    /// awaited from an async API function without blocking. It does not borrow `self`.
    ///
    /// # Errors
    ///
    /// The future resolves to [`RenderError::ThreadStopped`] if the thread is no longer running.
    pub fn status(
        &self,
    ) -> impl Future<Output = Result<PdfiumStatus, RenderError>> + Send + 'static {
        let reply = self.request(Request::Status);
        async move { reply?.await.map_err(|_canceled| RenderError::ThreadStopped) }
    }

    /// Sends a request and returns the receiver of its reply.
    fn request<T>(
        &self,
        request: impl FnOnce(oneshot::Sender<T>) -> Request,
    ) -> Result<oneshot::Receiver<T>, RenderError> {
        let (reply, receiver) = oneshot::channel();
        self.requests
            .as_ref()
            .ok_or(RenderError::ThreadStopped)?
            .send(request(reply))
            .map_err(|_closed| RenderError::ThreadStopped)?;
        Ok(receiver)
    }
}

impl Drop for RenderThread {
    fn drop(&mut self) {
        // Closing the channel ends the thread's request loop.
        drop(self.requests.take());
        if let Some(handle) = self.handle.take()
            && handle.join().is_err()
        {
            // The panic itself went to the panic hook; its payload can hold any text, so it is not
            // logged here (docs/ARCHITECTURE.md §8.4).
            tracing::error!("the render thread ended with a panic");
        }
    }
}

/// The body of the render thread: load PDFium, then answer requests until the channel closes.
fn run(config: RenderConfig, inbox: &mpsc::Receiver<Request>) {
    // The thread owns PDFium for its whole life; M2 renders with it.
    let (pdfium, status): (Option<Pdfium>, PdfiumStatus) = match config.pdfium_library {
        None => (None, PdfiumStatus::NotLoaded),
        Some(path) => match library::load(&path) {
            Ok(pdfium) => {
                tracing::info!(path = %path.display(), tag = PDFIUM_TAG, "PDFium loaded");
                (Some(pdfium), PdfiumStatus::Loaded { tag: PDFIUM_TAG })
            }
            Err(err) => (
                None,
                PdfiumStatus::Failed {
                    reason: err.to_string(),
                },
            ),
        },
    };
    for request in inbox {
        match request {
            Request::Status(reply) => {
                // The caller may have stopped waiting; that is not an error.
                let _ = reply.send(status.clone());
            }
        }
    }
    // The channel is closed: PDFium (if loaded) is dropped here, on its own thread.
    drop(pdfium);
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::task::{Context, Poll, Waker};

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

    #[test]
    fn without_a_library_the_status_is_not_loaded() {
        let render = RenderThread::start(RenderConfig::default()).unwrap();
        assert_eq!(wait(render.status()).unwrap(), PdfiumStatus::NotLoaded);
    }

    #[test]
    fn a_missing_library_is_failed_without_its_path() {
        let path = std::env::temp_dir()
            .join(format!("ferman-render-missing-{}", std::process::id()))
            .join("libpdfium.so");
        let render = RenderThread::start(RenderConfig {
            pdfium_library: Some(path.clone()),
        })
        .unwrap();
        match wait(render.status()).unwrap() {
            PdfiumStatus::Failed { reason } => {
                assert!(!reason.is_empty());
                assert!(!reason.contains("ferman-render-missing"), "{reason}");
            }
            other => panic!("expected Failed, got {other:?}"),
        }
    }

    #[test]
    fn a_file_that_is_not_a_library_is_failed_without_its_path() {
        let dir =
            std::env::temp_dir().join(format!("ferman-render-garbage-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("libpdfium.so");
        std::fs::write(&path, b"this is not a shared library").unwrap();
        let render = RenderThread::start(RenderConfig {
            pdfium_library: Some(path.clone()),
        })
        .unwrap();
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
        // The thread answered the request sent before the drop, then exited; the drop joined it.
        assert_eq!(wait(status).unwrap(), PdfiumStatus::NotLoaded);
    }

    #[test]
    fn the_handle_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<RenderThread>();
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
        let render = RenderThread::start(RenderConfig {
            pdfium_library: Some(pdfium_path()),
        })
        .unwrap();
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
        let path = pdfium_path();
        for _ in 0..3 {
            let render = RenderThread::start(RenderConfig {
                pdfium_library: Some(path.clone()),
            })
            .unwrap();
            assert!(matches!(
                wait(render.status()).unwrap(),
                PdfiumStatus::Loaded { .. }
            ));
        }
    }

    #[test]
    #[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
    fn concurrent_render_threads_all_load() {
        let path = pdfium_path();
        let threads: Vec<_> = (0..4)
            .map(|_| {
                let path = path.clone();
                thread::spawn(move || {
                    let render = RenderThread::start(RenderConfig {
                        pdfium_library: Some(path),
                    })
                    .unwrap();
                    wait(render.status()).unwrap()
                })
            })
            .collect();
        for handle in threads {
            assert_eq!(
                handle.join().unwrap(),
                PdfiumStatus::Loaded { tag: PDFIUM_TAG }
            );
        }
    }

    #[test]
    #[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
    fn another_library_after_binding_is_refused() {
        let render = RenderThread::start(RenderConfig {
            pdfium_library: Some(pdfium_path()),
        })
        .unwrap();
        assert!(matches!(
            wait(render.status()).unwrap(),
            PdfiumStatus::Loaded { .. }
        ));
        let other = RenderThread::start(RenderConfig {
            pdfium_library: Some(PathBuf::from("/no/such/dir/libpdfium.so")),
        })
        .unwrap();
        assert_eq!(
            wait(other.status()).unwrap(),
            PdfiumStatus::Failed {
                reason: RenderError::PdfiumAlreadyBound.to_string()
            }
        );
    }
}
