//! Settings › Fonts (a11-1d): the fonts bundled with Ferman and installed on this computer, one
//! row per family, with the scripts each covers read from its file.

use std::collections::HashMap;
use std::path::PathBuf;

use ferman_fonts::{FaceInfo, FontLibrary, FontOrigin, ScanLimits, Script, scripts_of};

use super::engine::Engine;
use super::error::ApiError;
use super::guard::guard_async;
use super::recovery::off_thread;

/// A family of Settings › Fonts.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstalledFont {
    /// The family name.
    pub family: String,
    /// Bundled with Ferman or installed on this computer.
    pub origin: FontOrigin,
    /// The scripts its regular face covers.
    pub scripts: Vec<Script>,
}

impl Engine {
    /// The families bundled in `bundled_dir` and installed on this computer, bundled first and
    /// then by name, each once (a family both bundled and installed is listed as bundled). The
    /// folders are scanned on a thread of their own, within [`ScanLimits`].
    ///
    /// # Errors
    ///
    /// `Internal` only if the thread cannot start or the scan panics.
    pub async fn installed_fonts(
        &self,
        bundled_dir: Option<PathBuf>,
    ) -> Result<Vec<InstalledFont>, ApiError> {
        guard_async(async move {
            off_thread(move || {
                let limits = ScanLimits::default();
                let mut library = FontLibrary::new();
                if let Some(dir) = &bundled_dir {
                    library.add_dir(dir, FontOrigin::Bundled, &limits);
                }
                library.add_system_fonts(&limits);
                Ok(families(&library))
            })
            .await
        })
        .await
    }
}

/// One row per family of `library`, by its best face: bundled before installed, then upright
/// regular before other styles.
fn families(library: &FontLibrary) -> Vec<InstalledFont> {
    let rank = |face: &FaceInfo| {
        (
            face.origin != FontOrigin::Bundled,
            face.italic,
            face.weight.abs_diff(400),
            face.stretch.abs_diff(5),
        )
    };
    let mut best: HashMap<String, FaceInfo> = HashMap::new();
    for face in library.faces() {
        if face.origin == FontOrigin::Embedded || face.family.is_empty() {
            continue;
        }
        let key = face.family.to_lowercase();
        if best.get(&key).is_none_or(|kept| rank(&face) < rank(kept)) {
            best.insert(key, face);
        }
    }
    let mut rows: Vec<InstalledFont> = best
        .into_values()
        .map(|face| InstalledFont {
            scripts: library.with_data(face.id, scripts_of).unwrap_or_default(),
            family: face.family,
            origin: face.origin,
        })
        .collect();
    rows.sort_by_cached_key(|row| (row.origin != FontOrigin::Bundled, row.family.to_lowercase()));
    rows
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fonts() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../app/assets/fonts")
    }

    #[test]
    fn each_family_is_listed_once_by_name_with_its_scripts() {
        let mut library = FontLibrary::new();
        library.add_dir(&fonts(), FontOrigin::Installed, &ScanLimits::default());
        let rows = families(&library);
        let names: Vec<&str> = rows.iter().map(|row| row.family.as_str()).collect();
        let mut sorted = names.clone();
        sorted.sort_by_key(|name| name.to_lowercase());
        assert_eq!(names, sorted);
        let mut unique = names.clone();
        unique.dedup();
        assert_eq!(unique, names);
        let sans = rows
            .iter()
            .find(|row| row.family == "IBM Plex Sans")
            .unwrap();
        assert!(sans.scripts.contains(&Script::Turkish));
        let arabic = rows
            .iter()
            .find(|row| row.family == "IBM Plex Sans Arabic")
            .unwrap();
        assert!(arabic.scripts.contains(&Script::Arabic));
    }

    #[test]
    fn bundled_fonts_come_first() {
        let mut library = FontLibrary::new();
        let limits = ScanLimits::default();
        library.add_dir(&fonts().join("caveat"), FontOrigin::Installed, &limits);
        library.add_dir(&fonts().join("ibm-plex-mono"), FontOrigin::Bundled, &limits);
        // The same family again as installed: listed once, as bundled.
        library.add_dir(
            &fonts().join("ibm-plex-mono"),
            FontOrigin::Installed,
            &limits,
        );
        let rows = families(&library);
        let listed: Vec<(&str, FontOrigin)> = rows
            .iter()
            .map(|row| (row.family.as_str(), row.origin))
            .collect();
        assert_eq!(
            listed,
            [
                ("IBM Plex Mono", FontOrigin::Bundled),
                ("Caveat", FontOrigin::Installed)
            ]
        );
    }
}
