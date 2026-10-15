//! Binding to the PDFium library: the only module that names pdfium-render.
//!
//! pdfium-render keeps its bindings in a process-wide static and binds once per process: a second
//! `bind_to_library` fails, and it never unloads the library. This module serialises binding behind
//! one lock and remembers which file was bound, so a later render thread in the same process (tests,
//! or a restarted engine) reuses the binding for the same file and is refused for another one.

use std::error::Error;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};

use pdfium_render::prelude::{Pdfium, PdfiumError};

use crate::RenderError;

/// The library file this process bound, canonicalised when possible.
static BOUND: Mutex<Option<PathBuf>> = Mutex::new(None);

/// What replaces the library path in error text, so that no path reaches `engine_info()`, which
/// ends up in bug reports (docs/ARCHITECTURE.md §8.4). The local log keeps the full text.
const PATH_PLACEHOLDER: &str = "<pdfium library>";

/// Binds the PDFium library at `path` and proves it works with a real call.
///
/// A relative path is made absolute against the current directory first, so the dynamic loader
/// never searches its library path for a bare file name: the configured file is the one loaded.
///
/// Must run on the render thread: the returned [`Pdfium`] is the thread's own.
pub(crate) fn load(path: &Path) -> Result<Pdfium, RenderError> {
    let absolute = std::path::absolute(path).map_err(|err| RenderError::PdfiumLoad {
        reason: format!("the library path cannot be made absolute: {err}"),
    })?;
    let pdfium = bind(&absolute)?;
    probe(&pdfium, &absolute)?;
    Ok(pdfium)
}

/// Binds the library, or reuses this process's binding if it is the same file.
fn bind(path: &Path) -> Result<Pdfium, RenderError> {
    // A poisoned lock only means a thread panicked while binding; the Option is still valid.
    let mut bound = BOUND.lock().unwrap_or_else(PoisonError::into_inner);
    let key = canonical(path);
    match bound.as_ref() {
        Some(existing) if *existing == key => {
            // The bindings are already in pdfium-render's static, so `Pdfium::default()` takes its
            // reuse branch (its first bind attempt returns `PdfiumLibraryBindingsAlreadyInitialized`
            // before touching any file) and none of its panicking fallbacks can run.
            Ok(Pdfium::default())
        }
        Some(_) => Err(RenderError::PdfiumAlreadyBound),
        None => {
            let bindings = Pdfium::bind_to_library(path).map_err(|err| match err {
                PdfiumError::PdfiumLibraryBindingsAlreadyInitialized => {
                    RenderError::PdfiumAlreadyBound
                }
                other => RenderError::PdfiumLoad {
                    reason: describe(&other, path),
                },
            })?;
            // Calls FPDF_InitLibrary once and moves the bindings into pdfium-render's static.
            let pdfium = Pdfium::new(bindings);
            *bound = Some(key);
            Ok(pdfium)
        }
    }
}

/// Proves that PDFium works, not just that its symbols were found: creates an empty document,
/// counts its pages and closes it (`FPDF_CreateNewDocument`, `FPDF_GetPageCount`,
/// `FPDF_CloseDocument`).
fn probe(pdfium: &Pdfium, path: &Path) -> Result<(), RenderError> {
    let document = pdfium
        .create_new_pdf()
        .map_err(|err| RenderError::PdfiumProbe {
            reason: describe(&err, path),
        })?;
    let pages = document.pages().len();
    drop(document);
    if pages == 0 {
        Ok(())
    } else {
        Err(RenderError::PdfiumProbe {
            reason: format!("an empty document reports {pages} pages"),
        })
    }
}

/// The library path as compared between bindings: canonical if the file can be resolved.
fn canonical(path: &Path) -> PathBuf {
    std::fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf())
}

/// One line of technical text for a pdfium-render error, without the library path.
fn describe(err: &PdfiumError, path: &Path) -> String {
    let text = match err {
        // libloading puts the operating system's message (dlerror or the Windows error) in the
        // error's source; its own text is only "dlopen failed".
        PdfiumError::LoadLibraryError(load) => chain(load),
        other => format!("{other:?}"),
    };
    tracing::warn!(path = %path.display(), error = %text, "PDFium did not load");
    redact(&text, path)
}

/// An error and its sources, joined with ": ".
fn chain(err: &dyn Error) -> String {
    let mut text = err.to_string();
    let mut source = err.source();
    while let Some(cause) = source {
        text.push_str(": ");
        text.push_str(&cause.to_string());
        source = cause.source();
    }
    text
}

/// `text` with every spelling of the library path replaced: as given, and resolved through
/// symbolic links (for a missing file, its folder resolved; macOS reports `/var/…` as
/// `/private/var/…`, for example).
fn redact(text: &str, path: &Path) -> String {
    let mut spellings = vec![path.display().to_string()];
    let resolved = std::fs::canonicalize(path).ok().or_else(|| {
        let folder = std::fs::canonicalize(path.parent()?).ok()?;
        Some(folder.join(path.file_name()?))
    });
    if let Some(resolved) = resolved {
        spellings.push(resolved.display().to_string());
    }
    // Longest first, so a path that contains another is replaced whole.
    spellings.sort_by_key(|spelling| std::cmp::Reverse(spelling.len()));
    spellings
        .iter()
        .filter(|spelling| !spelling.is_empty())
        .fold(text.to_owned(), |text, spelling| {
            text.replace(spelling.as_str(), PATH_PLACEHOLDER)
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn redact_replaces_every_occurrence_of_the_path() {
        let path = Path::new("/home/someone/Ferman/lib/libpdfium.so");
        let text = "/home/someone/Ferman/lib/libpdfium.so: cannot open shared object file \
                    (tried /home/someone/Ferman/lib/libpdfium.so)";
        let redacted = redact(text, path);
        assert!(!redacted.contains("someone"), "{redacted}");
        assert_eq!(
            redacted,
            "<pdfium library>: cannot open shared object file (tried <pdfium library>)"
        );
    }

    #[test]
    fn redact_replaces_the_resolved_folder_of_a_missing_file() {
        let folder = std::env::temp_dir();
        let resolved = std::fs::canonicalize(&folder)
            .unwrap()
            .join("no-such-libpdfium.so");
        let path = folder.join("no-such-libpdfium.so");
        let text = format!("tried '{}' and '{}'", path.display(), resolved.display());
        let redacted = redact(&text, &path);
        assert!(!redacted.contains("no-such-libpdfium"), "{redacted}");
    }

    #[test]
    fn redact_keeps_text_without_the_path() {
        let path = Path::new("/opt/pdfium/libpdfium.so");
        assert_eq!(redact("dlopen failed", path), "dlopen failed".to_owned());
    }

    #[test]
    fn chain_joins_the_sources() {
        #[derive(Debug, thiserror::Error)]
        #[error("dlopen failed")]
        struct Outer(#[source] std::io::Error);
        let err = Outer(std::io::Error::other("no such file"));
        assert_eq!(chain(&err), "dlopen failed: no such file");
    }

    #[test]
    fn canonical_falls_back_to_the_path_as_given() {
        let missing = Path::new("/no/such/dir/libpdfium.so");
        assert_eq!(canonical(missing), missing.to_path_buf());
    }
}
