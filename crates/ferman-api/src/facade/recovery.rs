//! Crash recovery (docs/ARCHITECTURE.md §7.6 and §7.7, ADR 0008): the app names the recovery
//! directory once at launch ([`Engine::start_recovery`]), and from then on each document actor
//! keeps its document's journal, snapshots and base copy there from the first unsaved change
//! (`edit`), until a save, "Don't save" ([`Engine::close_discarding`]) or Discard deletes them.
//!
//! At launch the app asks [`Engine::list_recoverable`] for the documents of sessions that ended
//! without cleaning up (a1-12), and opens each one the person keeps with
//! [`Engine::restore_recovered`]: the bytes it was opened from with every unsaved change as one
//! unsaved step, the file on disk unchanged. A document whose original changed since opens under
//! a new name, so neither is overwritten (a11-7f). [`Engine::set_recovery_enabled`] is the
//! a11-1c switch "Save a recovery copy every minute".

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};
use std::thread;

use ferman_core::recovery::{self, DocumentRecovery, Manifest, RecoverySession, Resume};
use ferman_core::save::FileStamp;
use ferman_core::{CoreError, OpenOptions, Password, Source};
use ferman_text::extract::PageText;

use super::document::OpenedDocument;
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};

/// A document a session that ended without cleaning up left recovery files for (a1-12).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RecoverableDocument {
    /// The session's name, for [`Engine::restore_recovered`] and
    /// [`Engine::discard_recovery`].
    pub session: String,
    /// The document's name in the session.
    pub document: String,
    /// The file the document saves to.
    pub original: PathBuf,
    /// Whether that file changed on disk since it was opened or saved: restoring opens the
    /// document under a new name (a11-7f).
    pub original_changed: bool,
    /// How many unsaved changes the files hold.
    pub changes: u32,
    /// Whether the document is encrypted: restoring needs its password again (a1-8).
    pub encrypted: bool,
}

/// A document [`Engine::restore_recovered`] opened.
#[derive(Debug, Clone, PartialEq)]
pub struct RestoredDocument {
    /// The document, as [`Engine::open`] gives it.
    pub opened: OpenedDocument,
    /// The file it saves to: the original, or a new name beside it when the original changed.
    pub path: PathBuf,
    /// Whether the original changed on disk since the document was opened or saved.
    pub original_changed: bool,
    /// The pages' render key with the restored changes; `None` when PDFium could not reload.
    pub render_key: Option<u64>,
}

/// The recovery switch and the running session, which the document actors share.
#[derive(Debug)]
pub(super) struct Recovery {
    state: Mutex<State>,
}

#[derive(Debug)]
struct State {
    root: Option<PathBuf>,
    session: Option<Arc<RecoverySession>>,
    /// "Save a recovery copy every minute" (a11-1c), on by default.
    enabled: bool,
}

impl Default for Recovery {
    fn default() -> Self {
        Self {
            state: Mutex::new(State {
                root: None,
                session: None,
                enabled: true,
            }),
        }
    }
}

impl Recovery {
    fn state(&self) -> std::sync::MutexGuard<'_, State> {
        self.state.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// The running session while recovery is on.
    pub(super) fn session(&self) -> Option<Arc<RecoverySession>> {
        let state = self.state();
        state.session.clone().filter(|_| state.enabled)
    }

    /// The recovery directory and the running session's name.
    fn root(&self) -> Result<(PathBuf, Option<Arc<RecoverySession>>), ApiError> {
        let state = self.state();
        let root = state.root.clone().ok_or_else(|| {
            ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details("recovery has not started")
        })?;
        Ok((root, state.session.clone()))
    }
}

#[cfg(test)]
impl Recovery {
    /// Recovery started in `root`.
    pub(super) fn started(root: &Path) -> Self {
        let recovery = Self::default();
        {
            let mut state = recovery.state();
            state.session = Some(Arc::new(RecoverySession::start(root).unwrap()));
            state.root = Some(root.to_path_buf());
        }
        recovery
    }

    pub(super) fn set_enabled(&self, enabled: bool) {
        self.state().enabled = enabled;
    }
}

impl Engine {
    /// Starts recovery in `root`, the app data directory's recovery folder
    /// (docs/ARCHITECTURE.md §7.6): a session of this instance, locked while it runs. Calling it
    /// again with the same root does nothing.
    ///
    /// # Errors
    ///
    /// `InvalidInput` once started in another root, and `Io` or `PermissionDenied` when the
    /// folder cannot be made.
    pub async fn start_recovery(&self, root: PathBuf) -> Result<(), ApiError> {
        guard_async(async move {
            {
                let state = self.recovery.state();
                if let Some(started) = &state.root {
                    return if *started == root {
                        Ok(())
                    } else {
                        Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                            .with_details("recovery started in another folder"))
                    };
                }
            }
            let session = {
                let root = root.clone();
                off_thread(move || Ok(RecoverySession::start(&root)?)).await?
            };
            let mut state = self.recovery.state();
            if state.root.is_none() {
                state.root = Some(root);
                state.session = Some(Arc::new(session));
            }
            Ok(())
        })
        .await
    }

    /// Turns recovery files on or off ("Save a recovery copy every minute", a11-1c). Off, the
    /// actors delete their documents' files within a second and write none.
    ///
    /// # Errors
    ///
    /// Returns an internal error only if the call panics.
    pub async fn set_recovery_enabled(&self, enabled: bool) -> Result<(), ApiError> {
        guard_async(async move {
            self.recovery.state().enabled = enabled;
            Ok(())
        })
        .await
    }

    /// The documents of the sessions in the recovery folder whose instance is gone, this one's
    /// left out (a1-12); none before [`start_recovery`](Self::start_recovery).
    ///
    /// # Errors
    ///
    /// Returns an internal error only if the call panics.
    pub async fn list_recoverable(&self) -> Result<Vec<RecoverableDocument>, ApiError> {
        guard_async(async move {
            let Ok((root, own)) = self.recovery.root() else {
                return Ok(Vec::new());
            };
            let own = own.map(|session| session.name());
            off_thread(move || {
                Ok(recovery::list(&root, own.as_deref())
                    .into_iter()
                    .map(|found| RecoverableDocument {
                        session: found.session,
                        document: found.document,
                        original: found.manifest.original,
                        original_changed: found.original_changed,
                        changes: found.changes,
                        encrypted: found.manifest.encrypted,
                    })
                    .collect())
            })
            .await
        })
        .await
    }

    /// Deletes the recovery files of `document` of `session`, or of the whole session without a
    /// document (Discard in a1-12).
    ///
    /// # Errors
    ///
    /// `InvalidInput` before [`start_recovery`](Self::start_recovery) or for names that are not
    /// a session's or a document's, and `Io` when the files cannot be deleted.
    pub async fn discard_recovery(
        &self,
        session: String,
        document: Option<String>,
    ) -> Result<(), ApiError> {
        guard_async(async move {
            let (root, _) = self.recovery.root()?;
            off_thread(move || Ok(recovery::discard(&root, &session, document.as_deref())?)).await
        })
        .await
    }

    /// Opens `document` of the crashed `session` as it was at the crash: the bytes it was
    /// opened from (the base copy, or the original when it has none and did not change) with
    /// every unsaved change as one unsaved step of its history; the file on disk is unchanged.
    /// When the original changed, the document saves to a new name beside it,
    /// `<name> (recovered).pdf`, so neither is overwritten (a11-7f). The running session takes
    /// the files over until a save or "Don't save".
    ///
    /// # Errors
    ///
    /// `PasswordRequired` for an encrypted document without its password, then
    /// `WrongPassword`; `NotFound` when the files are gone, or the original changed and no copy
    /// of it was kept; `InvalidInput` before [`start_recovery`](Self::start_recovery) or for
    /// names that are not a session's or a document's or a live session; and the errors of
    /// [`open`](Self::open).
    pub async fn restore_recovered(
        &self,
        session: String,
        document: String,
        password: Option<Password>,
    ) -> Result<RestoredDocument, ApiError> {
        guard_async(async move {
            let (root, own) = self.recovery.root()?;
            let dir = recovery::document_dir(&root, &session, &document).ok_or_else(|| {
                ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                    .with_details("not a crashed session's document")
            })?;
            let options = OpenOptions {
                password: password.clone(),
                ..OpenOptions::default()
            };
            let read = {
                let dir = dir.clone();
                off_thread(move || read_recovered(&dir, &options)).await?
            };
            let Read {
                source,
                model,
                first,
                store,
                resume,
                path,
                stamp,
                original_changed,
            } = read;
            let kept = stamp.clone();
            let opened = self
                .register(path.clone(), password, &source, model, first, |model| {
                    model
                        .revised
                        .get_mut()
                        .unwrap_or_else(PoisonError::into_inner)
                        .store = Arc::new(store);
                    model.stamp = stamp;
                })
                .await?;
            let id = opened.id;
            // Only now: a document that fails to open leaves its files to be offered again. If
            // they cannot be taken, the next commit starts new ones, and they are offered too.
            if let Some(own) = own {
                let original = path.clone();
                let adopted = off_thread(move || {
                    let dir = recovery::take(&dir, &own);
                    Ok(DocumentRecovery::adopt(dir, resume, original, kept))
                })
                .await
                .ok();
                if let Some(model) = self.models()?.get(&id) {
                    *model
                        .recovery
                        .lock()
                        .unwrap_or_else(PoisonError::into_inner) = adopted;
                }
            }
            let (current, reload) = self
                .ask(id, |session| Ok((session.current(), session.publish())))
                .await?;
            let render_key = self.revision_info(id, current, reload).await.render_key;
            Ok(RestoredDocument {
                opened,
                path,
                original_changed,
                render_key,
            })
        })
        .await
    }
}

/// What [`read_recovered`] reads.
struct Read {
    source: Source,
    model: ferman_core::Document,
    first: Option<Arc<PageText>>,
    store: ferman_core::revision::RevisionStore,
    resume: Resume,
    path: PathBuf,
    stamp: FileStamp,
    original_changed: bool,
}

/// Reads a crashed document's files in `dir` and opens what they hold, leaving them where they
/// are.
fn read_recovered(dir: &Path, options: &OpenOptions) -> Result<Read, ApiError> {
    let manifest = Manifest::read(dir).map_err(|err| match err {
        CoreError::Io { .. } => ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
            .with_details("no recovery files"),
        err => err.into(),
    })?;
    let original_changed = manifest.stamp.changed(&manifest.original).unwrap_or(true);
    let source = if manifest.base {
        Source::read(&dir.join("base.pdf"))?
    } else if !original_changed {
        Source::read(&manifest.original)?
    } else {
        return Err(ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
            .with_details("the original changed and no copy of it was kept"));
    };
    let model = ferman_core::open(&source, options)?;
    let restored = recovery::restore(dir, &model)?;
    let first = (model.page_count() > 0)
        .then(|| ferman_text::extract::page_layout(&model, 0).ok())
        .flatten()
        .map(Arc::new);
    let (path, stamp) = if original_changed {
        // Nothing is at the new name yet: a file that appears there stops a save.
        let missing = FileStamp {
            size: 0,
            modified: None,
            sha256: [0; 32],
        };
        (recovered_name(&manifest.original), missing)
    } else {
        (manifest.original.clone(), manifest.stamp.clone())
    };
    Ok(Read {
        source,
        model,
        first,
        store: restored.store,
        resume: restored.resume,
        path,
        stamp,
        original_changed,
    })
}

/// A name beside `original` that no file has: `<stem> (recovered).pdf`, then
/// `<stem> (recovered 2).pdf` and on (a11-7f).
fn recovered_name(original: &Path) -> PathBuf {
    let stem = original
        .file_stem()
        .map(|stem| stem.to_string_lossy().into_owned())
        .unwrap_or_default();
    let extension = original
        .extension()
        .map(|extension| format!(".{}", extension.to_string_lossy()))
        .unwrap_or_default();
    let named = |n: u32| {
        let suffix = if n == 1 {
            "(recovered)".to_owned()
        } else {
            format!("(recovered {n})")
        };
        original.with_file_name(format!("{stem} {suffix}{extension}"))
    };
    (1..1000)
        .map(named)
        .find(|path| !path.exists())
        .unwrap_or_else(|| named(1000))
}

/// Runs `work` on a thread of its own, so file work never holds an async worker, and a panic
/// becomes an error ([`guard`]).
async fn off_thread<T: Send + 'static>(
    work: impl FnOnce() -> Result<T, ApiError> + Send + 'static,
) -> Result<T, ApiError> {
    let (reply, receiver) = futures_channel::oneshot::channel();
    thread::Builder::new()
        .name("ferman-recovery".to_owned())
        .stack_size(super::document::PARSE_STACK)
        .spawn(move || {
            let _ = reply.send(guard(std::panic::AssertUnwindSafe(work)));
        })
        .map_err(|_| ApiError::internal("cannot start the recovery thread"))?;
    receiver
        .await
        .map_err(|_canceled| ApiError::internal("the recovery thread stopped"))?
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_recovered_name_takes_the_first_free_one() {
        let dir = std::env::temp_dir().join(format!("ferman-recovered-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let original = dir.join("iv fatura 4187.pdf");
        assert_eq!(
            recovered_name(&original),
            dir.join("iv fatura 4187 (recovered).pdf")
        );
        std::fs::write(dir.join("iv fatura 4187 (recovered).pdf"), b"x").unwrap();
        assert_eq!(
            recovered_name(&original),
            dir.join("iv fatura 4187 (recovered 2).pdf")
        );
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
