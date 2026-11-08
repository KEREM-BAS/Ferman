//! Version history (ADR 0022, a9-8, a11-1c): the app names the versions folder in its data
//! directory once at launch ([`Engine::start_versions`]); from then on every save of a document's
//! own file keeps a version, after the file as it was opened, and a save after a simple signature
//! keeps a signature's (`edit`). Versions older than 30 days go at each open and save.
//!
//! [`Engine::versions`] lists a document's versions, [`Engine::open_version`] opens one read-only
//! from its bytes for the preview, and [`Engine::restore_version`] makes one the file again
//! (decision 27 of the M4 plan). "Keep versions" (a11-1c) is [`Engine::set_versions_enabled`]:
//! off, saves keep nothing, and what was kept stays until it is purged and can still be restored
//! (the restore keeps its own two versions then too).

use std::path::PathBuf;
use std::sync::{Mutex, PoisonError};
use std::thread;
use std::time::SystemTime;

use ferman_core::versions::{KEEP, Version, VersionKind, Versions};
use ferman_core::{OpenOptions, Password, Source};
use ferman_render::DocumentId;

use super::document::{OpenedDocument, PARSE_STACK};
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};

/// A version as a9-8's timeline shows it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VersionInfo {
    /// Its id, for [`Engine::open_version`] and [`Engine::restore_version`].
    pub id: u64,
    /// What made it.
    pub kind: VersionKind,
    /// When, in milliseconds since the Unix epoch.
    pub time: u64,
    /// Its size in bytes.
    pub size: u64,
    /// How many edits it holds since the version before.
    pub edits: u32,
    /// Their names as the history named them; empty for an encrypted document (decision 28).
    pub names: Vec<String>,
}

impl From<Version> for VersionInfo {
    fn from(version: Version) -> Self {
        Self {
            id: version.id,
            kind: version.kind,
            time: version.time,
            size: version.size,
            edits: version.edits,
            names: version.names,
        }
    }
}

/// The versions folder and the switch, which the document actors share.
#[derive(Debug)]
pub(super) struct VersionConfig {
    state: Mutex<(Option<PathBuf>, bool)>,
}

impl Default for VersionConfig {
    fn default() -> Self {
        // On by default, as a11-1c draws "Keep versions".
        Self {
            state: Mutex::new((None, true)),
        }
    }
}

impl VersionConfig {
    /// The versions, while there is a folder and the switch is on.
    pub(super) fn store(&self) -> Option<Versions> {
        let state = self.state.lock().unwrap_or_else(PoisonError::into_inner);
        match &*state {
            (Some(root), true) => Some(Versions::new(root.clone())),
            _ => None,
        }
    }

    /// The versions in the folder, whatever the switch says: what was kept stays listed and can
    /// be restored.
    pub(super) fn kept(&self) -> Option<Versions> {
        let state = self.state.lock().unwrap_or_else(PoisonError::into_inner);
        state.0.clone().map(Versions::new)
    }

    /// A folder at `root` with the switch `enabled`.
    #[cfg(test)]
    pub(super) fn at(root: PathBuf, enabled: bool) -> Self {
        Self {
            state: Mutex::new((Some(root), enabled)),
        }
    }

    /// Purges old versions on a thread of its own, so an open never waits for it.
    pub(super) fn purge_soon(&self) {
        if let Some(versions) = self.kept() {
            let _ = thread::Builder::new()
                .name("ferman-versions".to_owned())
                .spawn(move || versions.purge(SystemTime::now(), KEEP));
        }
    }
}

impl Engine {
    /// Names the versions folder in the app's data directory, made owner-only with its first
    /// version, and purges what is past 30 days. Called once at launch.
    pub fn start_versions(&self, root: PathBuf) {
        self.versions
            .state
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .0 = Some(root);
        self.versions.purge_soon();
    }

    /// "Keep versions" (a11-1c): off, saves keep no version.
    pub fn set_versions_enabled(&self, enabled: bool) {
        self.versions
            .state
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .1 = enabled;
    }

    /// The versions of `document`'s file, newest first; none before [`start_versions`].
    ///
    /// [`start_versions`]: Self::start_versions
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open.
    pub async fn versions(&self, document: DocumentId) -> Result<Vec<VersionInfo>, ApiError> {
        guard_async(async move {
            let (path, sha) = self
                .ask(document, |session| Ok(session.version_key()))
                .await?;
            let Some(versions) = self.versions.kept() else {
                return Ok(Vec::new());
            };
            let (reply, receiver) = futures_channel::oneshot::channel();
            thread::Builder::new()
                .name("ferman-versions".to_owned())
                .spawn(move || {
                    let list = versions.list(&path, &sha);
                    let _ = reply.send(list);
                })
                .map_err(|_| ApiError::internal("cannot start the versions thread"))?;
            let list = receiver
                .await
                .map_err(|_| ApiError::internal("the versions thread stopped"))?;
            Ok(list.into_iter().map(VersionInfo::from).collect())
        })
        .await
    }

    /// Opens version `version` of `document` from its bytes as a document of its own, read-only,
    /// for a9-8's preview; close it with [`close`](Self::close). An encrypted document's version
    /// needs its `password` again. Nothing is written.
    ///
    /// # Errors
    ///
    /// `NotFound` for a version it does not have, and what [`open`](Self::open) returns.
    pub async fn open_version(
        &self,
        document: DocumentId,
        version: u64,
        password: Option<Password>,
    ) -> Result<OpenedDocument, ApiError> {
        guard_async(async move {
            self.render()?;
            let (path, sha) = self
                .ask(document, |session| Ok(session.version_key()))
                .await?;
            let versions = self.versions.kept().ok_or_else(|| {
                ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
                    .with_details("no versions folder")
            })?;
            let (reply, receiver) = futures_channel::oneshot::channel();
            let reading = path.clone();
            let opening = password.clone();
            thread::Builder::new()
                .name("ferman-open".to_owned())
                .stack_size(PARSE_STACK)
                .spawn(move || {
                    let result = guard(move || {
                        let bytes = versions.read(&reading, &sha, version)?;
                        let source = Source::from_bytes(bytes.into());
                        let options = OpenOptions {
                            password: opening,
                            ..OpenOptions::default()
                        };
                        let model = ferman_core::open(&source, &options)?;
                        Ok((source, model))
                    });
                    let _ = reply.send(result);
                })
                .map_err(|_| ApiError::internal("cannot start the open thread"))?;
            let (source, model) = receiver
                .await
                .map_err(|_| ApiError::internal("the open thread stopped"))??;
            // Its model refuses every change; the app shows it as the preview it asked for.
            self.register(path, password, &source, model, None, |model| {
                model.read_only = Some(ferman_text::NotEditableReason::ReadOnly);
            })
            .await
        })
        .await
    }

    /// Makes version `version` the file of `document` again (a9-8, decision 27): unsaved work is
    /// kept as a version first, the file is replaced whole after the external-change check
    /// (staged in `staging` under the sandbox, for [`finish_save`](Self::finish_save)), the
    /// recovery journal goes, and the restore becomes a version. The document's revisions do not
    /// change: the app opens the file again, as "Reload" does.
    ///
    /// # Errors
    ///
    /// `NotFound` for a version it does not have or with versions off, `FileChangedOnDisk`, and
    /// the save failures.
    pub async fn restore_version(
        &self,
        document: DocumentId,
        version: u64,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        guard_async(async move {
            self.ask(document, move |session| {
                session.restore_version(version, staging.as_deref())
            })
            .await
        })
        .await
    }
}
