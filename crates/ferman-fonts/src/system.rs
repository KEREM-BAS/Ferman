//! Font sources for missing glyphs (ADR 0006): fonts installed on this computer, the fonts bundled
//! with the app, and font programs embedded in the document, in one [`FontLibrary`] indexed by
//! fontdb.
//!
//! The library is built from what the caller gives it: font directories ([`FontLibrary::add_dir`],
//! [`FontLibrary::add_system_fonts`] for the operating system's own) and byte blobs
//! ([`FontLibrary::add_bytes`]). Tests fill it from known files, so they never depend on the fonts
//! of the machine they run on. The directories are walked here, not by fontdb, so the work is
//! bounded ([`ScanLimits`]); files are read, never written, and a file that is not a font is
//! skipped. Faces are indexed by name and style; their bytes are read again only when a face is
//! opened ([`FontLibrary::with_data`]).

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use crate::FontError;
use crate::type1::MAX_PROGRAM;

/// Where a face comes from, the three groups of the a3-3b picker.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum FontOrigin {
    /// A font program embedded in this document.
    Embedded,
    /// A font installed on this computer.
    Installed,
    /// A font bundled with Ferman (IBM Plex and the other document fonts in `app/assets/fonts`).
    Bundled,
}

/// The bounds of a directory scan.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ScanLimits {
    /// The most font files read in one scan.
    pub max_files: usize,
    /// The largest font file read; larger files are skipped.
    pub max_file_bytes: u64,
    /// The most bytes read in one scan, over all files.
    pub max_total_bytes: u64,
    /// How deep the scan goes below each directory.
    pub max_depth: usize,
}

impl Default for ScanLimits {
    /// 4,000 files of up to 64 MB ([`MAX_PROGRAM`]), 2 GB in all, 8 levels deep: more than a
    /// large font collection holds.
    fn default() -> Self {
        Self {
            max_files: 4_000,
            max_file_bytes: u64::try_from(MAX_PROGRAM).unwrap_or(u64::MAX),
            max_total_bytes: 2 * 1024 * 1024 * 1024,
            max_depth: 8,
        }
    }
}

/// A face in a [`FontLibrary`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct FaceId(fontdb::ID);

/// What the library knows of a face without opening it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FaceInfo {
    /// The face.
    pub id: FaceId,
    /// Where it comes from.
    pub origin: FontOrigin,
    /// The PostScript name (name ID 6).
    pub postscript_name: String,
    /// The family (typographic family, else family), in English if the font has it.
    pub family: String,
    /// The weight class, 100 to 900.
    pub weight: u16,
    /// Italic or oblique.
    pub italic: bool,
    /// The width class, 1 (ultra-condensed) to 9 (ultra-expanded), 5 normal.
    pub stretch: u16,
}

/// The fonts Ferman can take glyphs from.
#[derive(Default)]
pub struct FontLibrary {
    db: fontdb::Database,
    origins: HashMap<fontdb::ID, FontOrigin>,
}

impl std::fmt::Debug for FontLibrary {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("FontLibrary")
            .field("faces", &self.db.len())
            .finish()
    }
}

/// The directories an operating system keeps its fonts in, for [`FontLibrary::add_system_fonts`].
#[must_use]
pub fn system_font_dirs() -> Vec<PathBuf> {
    let home = std::env::var_os("HOME").map(PathBuf::from);
    let mut dirs = Vec::new();
    if cfg!(target_os = "macos") {
        dirs.push(PathBuf::from("/System/Library/Fonts"));
        dirs.push(PathBuf::from("/Library/Fonts"));
        dirs.extend(home.map(|home| home.join("Library/Fonts")));
    } else if cfg!(windows) {
        let windir =
            std::env::var_os("WINDIR").map_or_else(|| PathBuf::from("C:\\Windows"), PathBuf::from);
        dirs.push(windir.join("Fonts"));
        if let Some(local) = std::env::var_os("LOCALAPPDATA") {
            dirs.push(PathBuf::from(local).join("Microsoft\\Windows\\Fonts"));
        }
    } else {
        dirs.push(PathBuf::from("/usr/share/fonts"));
        dirs.push(PathBuf::from("/usr/local/share/fonts"));
        if let Some(data) = std::env::var_os("XDG_DATA_HOME") {
            dirs.push(PathBuf::from(data).join("fonts"));
        } else if let Some(home) = &home {
            dirs.push(home.join(".local/share/fonts"));
        }
        dirs.extend(home.map(|home| home.join(".fonts")));
    }
    dirs
}

impl FontLibrary {
    /// An empty library.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// The number of faces.
    #[must_use]
    pub fn len(&self) -> usize {
        self.db.len()
    }

    /// Whether the library has no faces.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.db.is_empty()
    }

    /// Adds the fonts installed on this computer ([`system_font_dirs`]) as
    /// [`FontOrigin::Installed`]. Returns the number of faces added.
    pub fn add_system_fonts(&mut self, limits: &ScanLimits) -> usize {
        let mut budget = Budget { files: 0, bytes: 0 };
        system_font_dirs()
            .iter()
            .map(|dir| self.scan(dir, FontOrigin::Installed, limits, &mut budget, 0))
            .sum()
    }

    /// Adds the `.ttf`, `.otf`, `.ttc` and `.otc` files in `dir` and below it, as `origin`.
    /// Unreadable files and files that are not fonts are skipped. Returns the number of faces
    /// added.
    pub fn add_dir(&mut self, dir: &Path, origin: FontOrigin, limits: &ScanLimits) -> usize {
        let mut budget = Budget { files: 0, bytes: 0 };
        self.scan(dir, origin, limits, &mut budget, 0)
    }

    /// Adds the font program `data` (an sfnt or a collection), as `origin`: an embedded program,
    /// or a font a test supplies. Returns the faces added.
    ///
    /// # Errors
    ///
    /// [`FontError::ProgramTooLarge`] over [`MAX_PROGRAM`], [`FontError::Malformed`] when fontdb
    /// finds no named face in it.
    pub fn add_bytes(
        &mut self,
        data: Vec<u8>,
        origin: FontOrigin,
    ) -> Result<Vec<FaceId>, FontError> {
        if data.len() > MAX_PROGRAM {
            return Err(FontError::ProgramTooLarge {
                size: u64::try_from(data.len()).unwrap_or(u64::MAX),
                max: u64::try_from(MAX_PROGRAM).unwrap_or(u64::MAX),
            });
        }
        let ids = self
            .db
            .load_font_source(fontdb::Source::Binary(Arc::new(data)));
        if ids.is_empty() {
            return Err(FontError::Malformed {
                context: "font program without a named face",
            });
        }
        for id in &ids {
            self.origins.insert(*id, origin);
        }
        Ok(ids.iter().copied().map(FaceId).collect())
    }

    /// The faces, in the order they were added.
    pub fn faces(&self) -> impl Iterator<Item = FaceInfo> + '_ {
        self.db.faces().map(|face| self.info(face))
    }

    /// The face `id`, if the library has it.
    #[must_use]
    pub fn face(&self, id: FaceId) -> Option<FaceInfo> {
        self.db.face(id.0).map(|face| self.info(face))
    }

    /// Calls `f` with the bytes of the font file of `id` and the face's index in it. A file is
    /// read again for the call; `None` when it is gone or now over [`MAX_PROGRAM`].
    pub fn with_data<T>(&self, id: FaceId, f: impl FnOnce(&[u8], u32) -> T) -> Option<T> {
        let (source, index) = self.db.face_source(id.0)?;
        match source {
            fontdb::Source::Binary(data) => Some(f((*data).as_ref(), index)),
            fontdb::Source::File(path) => {
                let size = std::fs::metadata(&path).ok()?.len();
                if size > u64::try_from(MAX_PROGRAM).unwrap_or(u64::MAX) {
                    return None;
                }
                let data = std::fs::read(&path).ok()?;
                Some(f(&data, index))
            }
        }
    }

    fn info(&self, face: &fontdb::FaceInfo) -> FaceInfo {
        FaceInfo {
            id: FaceId(face.id),
            origin: self
                .origins
                .get(&face.id)
                .copied()
                .unwrap_or(FontOrigin::Installed),
            postscript_name: face.post_script_name.clone(),
            family: face
                .families
                .first()
                .map(|(family, _)| family.clone())
                .unwrap_or_default(),
            weight: face.weight.0,
            italic: face.style != fontdb::Style::Normal,
            stretch: face.stretch.to_number(),
        }
    }

    fn scan(
        &mut self,
        dir: &Path,
        origin: FontOrigin,
        limits: &ScanLimits,
        budget: &mut Budget,
        depth: usize,
    ) -> usize {
        if depth > limits.max_depth {
            return 0;
        }
        let Ok(entries) = std::fs::read_dir(dir) else {
            return 0;
        };
        // Sorted, so the same directory gives the same faces in the same order on every system.
        let mut entries: Vec<_> = entries
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .collect();
        entries.sort();
        let mut added = 0usize;
        for path in entries {
            // Symbolic links are not followed: a link cycle cannot loop the scan.
            let Ok(meta) = std::fs::symlink_metadata(&path) else {
                continue;
            };
            if meta.is_dir() {
                added = added.saturating_add(self.scan(
                    &path,
                    origin,
                    limits,
                    budget,
                    depth.saturating_add(1),
                ));
            } else if meta.is_file() && is_font_file(&path) {
                if !budget.take(meta.len(), limits) {
                    if budget.files >= limits.max_files {
                        break;
                    }
                    continue;
                }
                let before = self.db.len();
                if self.db.load_font_file(&path).is_ok() {
                    let ids: Vec<fontdb::ID> =
                        self.db.faces().skip(before).map(|face| face.id).collect();
                    added = added.saturating_add(ids.len());
                    for id in ids {
                        self.origins.insert(id, origin);
                    }
                }
            }
        }
        added
    }
}

/// What a scan has used of its [`ScanLimits`].
struct Budget {
    files: usize,
    bytes: u64,
}

impl Budget {
    /// Takes a file of `size` bytes from the budget; false when it does not fit.
    fn take(&mut self, size: u64, limits: &ScanLimits) -> bool {
        if self.files >= limits.max_files || size > limits.max_file_bytes {
            return false;
        }
        let Some(bytes) = self
            .bytes
            .checked_add(size)
            .filter(|&bytes| bytes <= limits.max_total_bytes)
        else {
            return false;
        };
        self.files = self.files.saturating_add(1);
        self.bytes = bytes;
        true
    }
}

fn is_font_file(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .is_some_and(|ext| {
            ["ttf", "otf", "ttc", "otc"]
                .iter()
                .any(|known| ext.eq_ignore_ascii_case(known))
        })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_fonts::{plex, plex_dir};

    #[test]
    fn a_directory_scan_finds_the_bundled_fonts() {
        let mut library = FontLibrary::new();
        let added = library.add_dir(&plex_dir(), FontOrigin::Bundled, &ScanLimits::default());
        assert!(added >= 6, "{added}");
        assert_eq!(library.len(), added);
        let sans = library
            .faces()
            .find(|face| face.postscript_name == "IBMPlexSans")
            .unwrap();
        assert_eq!(sans.family, "IBM Plex Sans");
        assert_eq!(sans.weight, 400);
        assert!(!sans.italic);
        assert_eq!(sans.stretch, 5);
        assert_eq!(sans.origin, FontOrigin::Bundled);
        let italic = library
            .faces()
            .find(|face| face.postscript_name == "IBMPlexSans-Italic")
            .unwrap();
        assert!(italic.italic);
        // The bytes come back for the face.
        let size = library
            .with_data(sans.id, |data, index| (data.len(), index))
            .unwrap();
        assert_eq!(
            size,
            (plex("ibm-plex-sans/IBMPlexSans-Regular.ttf").len(), 0)
        );
    }

    #[test]
    fn scans_are_bounded() {
        let limits = ScanLimits {
            max_files: 2,
            ..ScanLimits::default()
        };
        let mut library = FontLibrary::new();
        assert_eq!(
            library.add_dir(&plex_dir(), FontOrigin::Bundled, &limits),
            2
        );
        let tiny = ScanLimits {
            max_file_bytes: 1024,
            ..ScanLimits::default()
        };
        let mut library = FontLibrary::new();
        assert_eq!(library.add_dir(&plex_dir(), FontOrigin::Bundled, &tiny), 0);
        let shallow = ScanLimits {
            max_depth: 0,
            ..ScanLimits::default()
        };
        // The Plex files are one level below the directory.
        let mut library = FontLibrary::new();
        assert_eq!(
            library.add_dir(&plex_dir(), FontOrigin::Bundled, &shallow),
            0
        );
        assert!(library.is_empty());
    }

    #[test]
    fn bytes_are_added_with_their_origin_and_garbage_is_refused() {
        let mut library = FontLibrary::new();
        let ids = library
            .add_bytes(
                plex("ibm-plex-mono/IBMPlexMono-Regular.ttf"),
                FontOrigin::Embedded,
            )
            .unwrap();
        assert_eq!(ids.len(), 1);
        assert_eq!(library.face(ids[0]).unwrap().origin, FontOrigin::Embedded);
        assert!(matches!(
            library.add_bytes(b"not a font".to_vec(), FontOrigin::Embedded),
            Err(FontError::Malformed { .. })
        ));
        assert_eq!(library.len(), 1);
    }

    #[test]
    fn missing_directories_and_non_fonts_are_skipped() {
        let mut library = FontLibrary::new();
        let limits = ScanLimits::default();
        assert_eq!(
            library.add_dir(
                Path::new("/nonexistent/ferman/fonts"),
                FontOrigin::Installed,
                &limits
            ),
            0
        );
        // The licence files beside the fonts are not fonts; the crate's own sources are no fonts.
        assert_eq!(
            library.add_dir(
                Path::new(env!("CARGO_MANIFEST_DIR")),
                FontOrigin::Installed,
                &limits
            ),
            0
        );
    }
}
