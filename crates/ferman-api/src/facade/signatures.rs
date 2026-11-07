//! Fill anything and simple signatures through the facade (M4 plan, W3, decisions 20 to 23): the
//! places to fill on a page without fields, the handwriting styles that can write a name, a
//! signature placed as one step behind the Comment gate (it is an annotation, G148), and the
//! saved signatures and initials.
//!
//! Saved signatures are plain files in a folder of the app data directory that the app names,
//! apart from `settings.json`, so settings export and reset never touch them (decision 22). The
//! app owns their format; the engine writes each through the safe write and reads them back
//! within limits. Nothing about them is logged.

use std::path::{Path, PathBuf};

use ferman_core::{CoreError, DocumentOp, WriteError};
use ferman_ops::fill::{self, TargetKind};
use ferman_ops::signatures::{self as ops, NewSignature};
use ferman_render::DocumentId;

use super::annotations::{AnnotationCommit, rect_to_display, rect_to_user};
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::guard_async;
use super::recovery::off_thread;

/// The most saved signature files read.
pub const MAX_SAVED: usize = 64;
/// The largest saved signature file read or written, in bytes.
pub const MAX_SAVED_BYTES: u64 = 8 * 1024 * 1024;
/// The longest saved signature file name.
const LONGEST_NAME: usize = 64;

/// One place to fill, in displayed points.
#[derive(Debug, Clone, PartialEq)]
pub struct FillTarget {
    /// What it is.
    pub kind: TargetKind,
    /// `[left, top, right, bottom]`: a line's stroke, a comb's cells together.
    pub rect: [f32; 4],
    /// A comb's cells; 1 for the others.
    pub cells: u32,
}

/// The places to fill on a page.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct FillTargets {
    /// From the top down, then left to right as the page is stored.
    pub targets: Vec<FillTarget>,
    /// Whether a limit cut the list short.
    pub truncated: bool,
}

/// A saved signature file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SavedSignature {
    /// Its file name.
    pub name: String,
    /// What the app wrote.
    pub bytes: Vec<u8>,
}

/// A file name the app may use for a saved signature: letters, digits, `-`, `_` and `.`, not
/// starting with a dot (the safe write's temp files do), so it can never leave the folder.
fn valid_name(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= LONGEST_NAME
        && !name.starts_with('.')
        && name
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.'))
}

fn io(err: std::io::Error) -> CoreError {
    CoreError::Io { kind: err.kind() }
}

fn bad_name() -> ApiError {
    ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL).with_details("bad file name")
}

fn read_saved(dir: &Path) -> Result<Vec<SavedSignature>, ApiError> {
    let entries = match std::fs::read_dir(dir) {
        Ok(entries) => entries,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(err) => return Err(io(err).into()),
    };
    let mut found: Vec<(String, PathBuf)> = Vec::new();
    // Bounded: a folder of thousands of strange names costs a look at each, nothing more.
    for entry in entries.take(MAX_SAVED.saturating_mul(16)).flatten() {
        let Ok(name) = entry.file_name().into_string() else {
            continue;
        };
        let regular = std::fs::symlink_metadata(entry.path())
            .is_ok_and(|meta| meta.is_file() && meta.len() <= MAX_SAVED_BYTES);
        if valid_name(&name) && regular {
            found.push((name, entry.path()));
        }
    }
    found.sort();
    found.truncate(MAX_SAVED);
    Ok(found
        .into_iter()
        .filter_map(|(name, path)| {
            let bytes = std::fs::read(path).ok()?;
            (bytes.len() as u64 <= MAX_SAVED_BYTES).then_some(SavedSignature { name, bytes })
        })
        .collect())
}

impl Engine {
    /// The lines, boxes, check boxes and combs drawn on page `page` (by its handle), from a
    /// snapshot of the committed revisions (a5-4). Nothing is written.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for a page the document does not have, `NotFound` for a document that is
    /// not open.
    pub async fn fill_targets(
        &self,
        document: DocumentId,
        page: u64,
    ) -> Result<FillTargets, ApiError> {
        guard_async(async move {
            let snapshot = self.job_snapshot(document)?;
            off_thread(move || {
                let (base, store) = (snapshot.base(), snapshot.store());
                let pages = store.pages(base);
                let index = pages
                    .iter()
                    .position(|candidate| candidate.handle() == page)
                    .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
                let shown = pages
                    .get(index)
                    .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
                let found = fill::targets(base, store, index)?;
                Ok(FillTargets {
                    targets: found
                        .targets
                        .into_iter()
                        .map(|target| FillTarget {
                            kind: target.kind,
                            rect: rect_to_display(shown, target.rect),
                            cells: target.cells,
                        })
                        .collect(),
                    truncated: found.truncated,
                })
            })
            .await
        })
        .await
    }

    /// Whether each typed-signature style, Caveat, Dancing Script and Homemade Apple in that
    /// order, can write every letter of `text` (decision 23, G158): a style that cannot is not
    /// offered for that name.
    ///
    /// # Errors
    ///
    /// Only an internal one.
    pub async fn handwriting_styles(&self, text: String) -> Result<Vec<(String, bool)>, ApiError> {
        guard_async(async move {
            let fonts = std::sync::Arc::clone(&self.fonts);
            off_thread(move || {
                Ok(ops::handwriting_styles(&fonts.library(), &text)
                    .into_iter()
                    .map(|(family, covered)| (family.to_owned(), covered))
                    .collect())
            })
            .await
        })
        .await
    }

    /// Places `signature`, in displayed points, on the page `page` by its handle, as one step
    /// `name`: a stamp annotation, with the private key naming its field when it signs one, never
    /// `/V` (decisions 20 and 21). It asks what a comment asks.
    ///
    /// # Errors
    ///
    /// As [`add_annotation`](Self::add_annotation); `InvalidInput` too for a field that is no
    /// signature field, is signed or has a simple signature already, `Unsupported` for a letter
    /// the style cannot draw or an image with no ink or none Ferman reads, and `ResourceLimit` for
    /// an image past the limits.
    pub async fn add_signature(
        &self,
        document: DocumentId,
        page: u64,
        signature: NewSignature,
        name: String,
    ) -> Result<AnnotationCommit, ApiError> {
        guard_async(async move {
            let (current, reload, handle) = self
                .ask(document, move |session| {
                    let index = session
                        .page_indices(&[page])?
                        .first()
                        .copied()
                        .ok_or_else(|| ApiError::from(CoreError::Write(WriteError::NoSuchPage)))?;
                    let library = session.font_library();
                    let limits = ferman_core::OpenOptions::default().limits;
                    let date = super::annotations::now();
                    let mut handle = 0;
                    let (current, reload) = session.commit_change(
                        DocumentOp::Comment,
                        &[],
                        name,
                        &[index],
                        (String::new(), String::new()),
                        |doc, working| {
                            let page = working
                                .pages(doc)
                                .get(index)
                                .cloned()
                                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
                            let signature = NewSignature {
                                rect: rect_to_user(&page, signature.rect),
                                ..signature
                            };
                            handle = ops::place(
                                doc, working, index, &signature, &date, &library, &limits,
                            )?;
                            Ok(())
                        },
                    )?;
                    // The next save's version is a signature's (a9-8).
                    session.signed_now();
                    Ok((current, reload, handle))
                })
                .await?;
            Ok(AnnotationCommit {
                handle,
                revision: self.revision_info(document, current, reload).await,
            })
        })
        .await
    }

    /// The saved signatures and initials in `dir`, by file name: at most [`MAX_SAVED`] files of
    /// at most [`MAX_SAVED_BYTES`], regular files with a name [`write_saved_signature`] takes.
    /// A folder not made yet has none.
    ///
    /// [`write_saved_signature`]: Self::write_saved_signature
    ///
    /// # Errors
    ///
    /// The errors of reading the folder.
    pub async fn saved_signatures(&self, dir: PathBuf) -> Result<Vec<SavedSignature>, ApiError> {
        guard_async(async move { off_thread(move || read_saved(&dir)).await }).await
    }

    /// Writes `bytes` as the saved signature `name` in `dir` through the safe write, making the
    /// folder first.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for a name of other characters, one starting with a dot or longer than 64
    /// bytes, or bytes past [`MAX_SAVED_BYTES`]; the errors of the write.
    pub async fn write_saved_signature(
        &self,
        dir: PathBuf,
        name: String,
        bytes: Vec<u8>,
    ) -> Result<(), ApiError> {
        guard_async(async move {
            if !valid_name(&name) || bytes.len() as u64 > MAX_SAVED_BYTES {
                return Err(bad_name());
            }
            off_thread(move || {
                std::fs::create_dir_all(&dir).map_err(io)?;
                ferman_core::save::safe_write(&dir.join(name), &bytes, None)?;
                Ok(())
            })
            .await
        })
        .await
    }

    /// Deletes the saved signature `name` in `dir`; one not there is gone already.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for a name [`write_saved_signature`](Self::write_saved_signature) refuses;
    /// the errors of the delete.
    pub async fn delete_saved_signature(&self, dir: PathBuf, name: String) -> Result<(), ApiError> {
        guard_async(async move {
            if !valid_name(&name) {
                return Err(bad_name());
            }
            off_thread(move || match std::fs::remove_file(dir.join(name)) {
                Err(err) if err.kind() != std::io::ErrorKind::NotFound => Err(io(err).into()),
                _ => Ok(()),
            })
            .await
        })
        .await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::facade::block_on;

    #[test]
    fn names_stay_in_the_folder() {
        for good in ["a", "signature-1.json", "initials_2"] {
            assert!(valid_name(good), "{good}");
        }
        for bad in ["", ".hidden", "../x", "a/b", "a\\b", "ş", &"x".repeat(65)] {
            assert!(!valid_name(bad), "{bad}");
        }
    }

    #[test]
    fn saved_signatures_are_written_listed_and_deleted() {
        let engine = Engine::start(super::super::EngineConfig {
            pdfium: super::super::PdfiumLibrary::Disabled,
        });
        let dir = std::env::temp_dir().join(format!("ferman-saved-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        assert!(
            block_on(engine.saved_signatures(dir.clone()))
                .unwrap()
                .is_empty()
        );
        block_on(engine.write_saved_signature(dir.clone(), "b.json".into(), b"{}".to_vec()))
            .unwrap();
        block_on(engine.write_saved_signature(dir.clone(), "a.json".into(), b"[1]".to_vec()))
            .unwrap();
        std::fs::write(dir.join(".a.json.ferman-1.tmp"), b"left over").unwrap();
        std::fs::write(dir.join("big.json"), vec![0; MAX_SAVED_BYTES as usize + 1]).unwrap();
        let saved = block_on(engine.saved_signatures(dir.clone())).unwrap();
        let names: Vec<&str> = saved.iter().map(|s| s.name.as_str()).collect();
        assert_eq!(names, ["a.json", "b.json"]);
        assert_eq!(saved[0].bytes, b"[1]");
        assert!(
            block_on(engine.write_saved_signature(dir.clone(), "../x".into(), Vec::new())).is_err()
        );
        block_on(engine.delete_saved_signature(dir.clone(), "a.json".into())).unwrap();
        block_on(engine.delete_saved_signature(dir.clone(), "a.json".into())).unwrap();
        let saved = block_on(engine.saved_signatures(dir.clone())).unwrap();
        assert_eq!(saved.len(), 1);
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
