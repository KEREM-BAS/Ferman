//! Version history ([ADR 0022](../../../docs/adr/0022-version-history.md), a9-8): every save, the
//! file as it was before the first save, a simple signature and a restore become a version, kept
//! in the app data directory for [`KEEP_DAYS`] days.
//!
//! ```text
//! <root>/                           owner-only
//! └── <32 hex digits>/              one document, owner-only
//!     ├── manifest.json             the file's path and the SHA-256 of its last saved bytes
//!     ├── <id>.json                 a version: kind, time, size, edit count and names, SHA-256
//!     └── <id>.pdf                  its bytes, as the file held them
//! ```
//!
//! A document's folder is found by its file's path, then, after a rename or a move (the path it
//! recorded is gone), by the hash of the bytes it last saved, which is the file's own hash until
//! something else writes it; a copy of the file next to it starts a folder of its own. Every
//! file is written with [`safe_write`](crate::save::safe_write). A version's bytes are the file's,
//! so an encrypted document's stay encrypted; its rows keep counts only, never the names of its
//! edits, which are document text (decision 28 of the M4 plan). The id of a version is its time in
//! milliseconds since the Unix epoch, made unique within its folder.
//!
//! shortcut: each version is a whole copy of the file; store an incremental version as its
//! update section over the one before when large files make the folder too big.

use std::fs;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use sha2::{Digest, Sha256};

use crate::CoreError;
use crate::recovery::{
    Json, flat_json, hex, io, json_string, make_dir, random_name, remove_dir, valid_name,
};
use crate::save::safe_write;

/// How long a version is kept.
pub const KEEP_DAYS: u64 = 30;

/// [`KEEP_DAYS`] as a duration.
pub const KEEP: Duration = Duration::from_secs(KEEP_DAYS * 24 * 60 * 60);

const MANIFEST: &str = "manifest.json";

/// Keeps a purge from deleting a folder while a version is written into it.
static WRITING: Mutex<()> = Mutex::new(());

/// What made a version.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VersionKind {
    /// The file as it was opened, before the first save that kept a version.
    Opened,
    /// A save.
    Saved,
    /// A save that holds a new simple signature.
    Signed,
    /// The unsaved work kept before a restore replaced it.
    Unsaved,
    /// A restore of an earlier version.
    Restored,
}

impl VersionKind {
    fn name(self) -> &'static str {
        match self {
            Self::Opened => "opened",
            Self::Saved => "saved",
            Self::Signed => "signed",
            Self::Unsaved => "unsaved",
            Self::Restored => "restored",
        }
    }

    fn from_name(name: &str) -> Option<Self> {
        [
            Self::Opened,
            Self::Saved,
            Self::Signed,
            Self::Unsaved,
            Self::Restored,
        ]
        .into_iter()
        .find(|kind| kind.name() == name)
    }
}

/// A version as a row of a9-8 shows it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Version {
    /// Its id within its document's folder: its time, unique.
    pub id: u64,
    /// What made it.
    pub kind: VersionKind,
    /// When, in milliseconds since the Unix epoch.
    pub time: u64,
    /// Its size in bytes.
    pub size: u64,
    /// How many edits it holds since the version before.
    pub edits: u32,
    /// The names of those edits; empty for an encrypted document.
    pub names: Vec<String>,
    /// The SHA-256 of its bytes.
    pub sha256: [u8; 32],
}

/// What a new version says of itself.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewVersion {
    /// What made it.
    pub kind: VersionKind,
    /// How many edits it holds.
    pub edits: u32,
    /// Their names, left out for an encrypted document.
    pub names: Vec<String>,
    /// Whether the document is encrypted.
    pub encrypted: bool,
}

/// The version folders under one root.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Versions {
    root: PathBuf,
}

/// The SHA-256 of `bytes`.
#[must_use]
pub fn sha256(bytes: &[u8]) -> [u8; 32] {
    Sha256::digest(bytes).into()
}

fn now_millis(now: SystemTime) -> u64 {
    now.duration_since(UNIX_EPOCH).map_or(0, |since| {
        u64::try_from(since.as_millis()).unwrap_or(u64::MAX)
    })
}

fn parse_hex(text: &str) -> Option<[u8; 32]> {
    if text.len() != 64 {
        return None;
    }
    let mut out = [0u8; 32];
    for (byte, pair) in out.iter_mut().zip(text.as_bytes().chunks(2)) {
        *byte = u8::from_str_radix(std::str::from_utf8(pair).ok()?, 16).ok()?;
    }
    Some(out)
}

/// A folder's manifest: the file's path and the hash of its last saved bytes.
fn read_manifest(dir: &Path) -> Option<(PathBuf, [u8; 32])> {
    let fields = flat_json(&fs::read_to_string(dir.join(MANIFEST)).ok()?)?;
    let (Some(Json::Text(path)), Some(Json::Text(sha))) =
        (fields.get("path"), fields.get("sha256"))
    else {
        return None;
    };
    Some((PathBuf::from(path), parse_hex(sha)?))
}

fn write_manifest(dir: &Path, path: &Path, sha: &[u8; 32]) -> Result<(), CoreError> {
    let mut out = String::from("{\n  \"version\": 1,\n  \"path\": ");
    json_string(&mut out, &path.to_string_lossy());
    out.push_str(&format!(",\n  \"sha256\": \"{}\"\n}}\n", hex(sha)));
    safe_write(&dir.join(MANIFEST), out.as_bytes(), None).map(drop)
}

fn read_version(dir: &Path, id: u64) -> Option<Version> {
    let fields = flat_json(&fs::read_to_string(dir.join(format!("{id}.json"))).ok()?)?;
    let text = |key: &str| match fields.get(key) {
        Some(Json::Text(text)) => Some(text.clone()),
        _ => None,
    };
    let number = |key: &str| match fields.get(key) {
        Some(Json::Number(number)) => Some(*number),
        _ => None,
    };
    let names = text("names")?;
    Some(Version {
        id,
        kind: VersionKind::from_name(&text("kind")?)?,
        time: number("time")?,
        size: number("size")?,
        edits: u32::try_from(number("edits")?).ok()?,
        names: if names.is_empty() {
            Vec::new()
        } else {
            names.split('\n').map(str::to_owned).collect()
        },
        sha256: parse_hex(&text("sha256")?)?,
    })
}

/// The ids of the versions in `dir`, oldest first.
fn version_ids(dir: &Path) -> Vec<u64> {
    let mut ids: Vec<u64> = fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|entry| {
            entry
                .file_name()
                .to_str()?
                .strip_suffix(".json")?
                .parse()
                .ok()
        })
        .collect();
    ids.sort_unstable();
    ids
}

impl Versions {
    /// The versions under `root`, which is made owner-only when the first one is written.
    #[must_use]
    pub fn new(root: PathBuf) -> Self {
        Self { root }
    }

    /// The document folders, by name.
    fn folders(&self) -> Vec<PathBuf> {
        fs::read_dir(&self.root)
            .into_iter()
            .flatten()
            .flatten()
            .filter(|entry| entry.file_name().to_str().is_some_and(valid_name))
            .map(|entry| entry.path())
            .collect()
    }

    /// The folder of the file at `path` whose bytes hash to `sha256`: the one with that path,
    /// else the one whose last saved bytes have that hash and whose file is gone (renamed or
    /// moved; a copy does not take over the original's history).
    #[must_use]
    pub fn find(&self, path: &Path, sha256: &[u8; 32]) -> Option<PathBuf> {
        let manifests: Vec<(PathBuf, PathBuf, [u8; 32])> = self
            .folders()
            .into_iter()
            .filter_map(|dir| read_manifest(&dir).map(|(file, sha)| (dir, file, sha)))
            .collect();
        manifests
            .iter()
            .find(|(_, file, _)| file == path)
            .or_else(|| {
                manifests
                    .iter()
                    .find(|(_, file, sha)| sha == sha256 && !file.exists())
            })
            .map(|(dir, _, _)| dir.clone())
    }

    /// The versions of the file at `path` whose bytes hash to `sha256`, newest first.
    #[must_use]
    pub fn list(&self, path: &Path, sha256: &[u8; 32]) -> Vec<Version> {
        let Some(dir) = self.find(path, sha256) else {
            return Vec::new();
        };
        let mut versions: Vec<Version> = version_ids(&dir)
            .into_iter()
            .filter_map(|id| read_version(&dir, id))
            .collect();
        versions.reverse();
        versions
    }

    /// The bytes of version `id` of that file.
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`] with `NotFound` for a version it does not have, or one whose bytes no
    /// longer match their hash.
    pub fn read(&self, path: &Path, sha256: &[u8; 32], id: u64) -> Result<Vec<u8>, CoreError> {
        let not_found = || CoreError::Io {
            kind: ErrorKind::NotFound,
        };
        let dir = self.find(path, sha256).ok_or_else(not_found)?;
        let version = read_version(&dir, id).ok_or_else(not_found)?;
        let bytes = fs::read(dir.join(format!("{id}.pdf"))).map_err(io)?;
        if self::sha256(&bytes) != version.sha256 {
            return Err(not_found());
        }
        Ok(bytes)
    }

    /// Keeps `bytes`, which the file at `path` now holds unless `kind` is
    /// [`VersionKind::Unsaved`], as a new version at `now`. `last` is the hash the file's folder
    /// is found by (its bytes before this write); the folder then answers to `path` and these
    /// bytes. A file whose newest version already holds these bytes gets no second one.
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`] and the failures of [`safe_write`].
    pub fn add(
        &self,
        path: &Path,
        last: &[u8; 32],
        bytes: &[u8],
        version: &NewVersion,
        now: SystemTime,
    ) -> Result<Option<Version>, CoreError> {
        let sha = sha256(bytes);
        let _writing = WRITING.lock().unwrap_or_else(PoisonError::into_inner);
        let dir = match self.find(path, last) {
            Some(dir) => dir,
            None => {
                make_dir(&self.root).map_err(io)?;
                let dir = self.root.join(random_name()?);
                make_dir(&dir).map_err(io)?;
                dir
            }
        };
        // Made again if a purge emptied and deleted it since it was found.
        make_dir(&dir).map_err(io)?;
        let ids = version_ids(&dir);
        if ids
            .last()
            .and_then(|&id| read_version(&dir, id))
            .is_some_and(|newest| newest.sha256 == sha && version.kind != VersionKind::Restored)
        {
            if version.kind != VersionKind::Unsaved {
                write_manifest(&dir, path, &sha)?;
            }
            return Ok(None);
        }
        let mut id = now_millis(now);
        while ids.contains(&id) {
            id = id.saturating_add(1);
        }
        let names = if version.encrypted {
            Vec::new()
        } else {
            version.names.clone()
        };
        let row = Version {
            id,
            kind: version.kind,
            time: now_millis(now),
            size: u64::try_from(bytes.len()).unwrap_or(u64::MAX),
            edits: version.edits,
            names,
            sha256: sha,
        };
        safe_write(&dir.join(format!("{id}.pdf")), bytes, None)?;
        let mut json = String::from("{\n  \"kind\": ");
        json_string(&mut json, row.kind.name());
        json.push_str(&format!(
            ",\n  \"time\": {},\n  \"size\": {},\n  \"edits\": {},\n  \"names\": ",
            row.time, row.size, row.edits
        ));
        // A name never holds a line break: the edit's name as the UI gave it, on one line.
        json_string(&mut json, &row.names.join("\n"));
        json.push_str(&format!(",\n  \"sha256\": \"{}\"\n}}\n", hex(&sha)));
        if let Err(err) = safe_write(&dir.join(format!("{id}.json")), json.as_bytes(), None) {
            let _ = fs::remove_file(dir.join(format!("{id}.pdf")));
            return Err(err);
        }
        if version.kind != VersionKind::Unsaved {
            write_manifest(&dir, path, &sha)?;
        }
        Ok(Some(row))
    }

    /// Deletes version `id` of that file, as a write that was not swapped in leaves it.
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`].
    pub fn remove(&self, path: &Path, sha256: &[u8; 32], id: u64) -> Result<(), CoreError> {
        let _writing = WRITING.lock().unwrap_or_else(PoisonError::into_inner);
        let Some(dir) = self.find(path, sha256) else {
            return Ok(());
        };
        for name in [format!("{id}.json"), format!("{id}.pdf")] {
            match fs::remove_file(dir.join(name)) {
                Err(err) if err.kind() != ErrorKind::NotFound => return Err(io(err)),
                _ => {}
            }
        }
        Ok(())
    }

    /// Deletes every version older than `keep` at `now`, a copy without its row (an add cut off
    /// before it) older than that by its file's time, and a folder left with none.
    pub fn purge(&self, now: SystemTime, keep: Duration) {
        let _writing = WRITING.lock().unwrap_or_else(PoisonError::into_inner);
        let oldest = now_millis(now).saturating_sub(u64::try_from(keep.as_millis()).unwrap_or(0));
        let cut_off = now.checked_sub(keep).unwrap_or(UNIX_EPOCH);
        for dir in self.folders() {
            let mut removed = false;
            for id in version_ids(&dir) {
                let old = read_version(&dir, id).is_none_or(|version| version.time < oldest);
                if old {
                    let _ = fs::remove_file(dir.join(format!("{id}.json")));
                    let _ = fs::remove_file(dir.join(format!("{id}.pdf")));
                    removed = true;
                }
            }
            for entry in fs::read_dir(&dir).into_iter().flatten().flatten() {
                let name = entry.file_name();
                let orphan = name
                    .to_str()
                    .and_then(|name| name.strip_suffix(".pdf"))
                    .is_some_and(|id| !dir.join(format!("{id}.json")).exists());
                let old = entry
                    .metadata()
                    .and_then(|meta| meta.modified())
                    .is_ok_and(|time| time < cut_off);
                if orphan && old {
                    let _ = fs::remove_file(entry.path());
                    removed = true;
                }
            }
            // Only a folder this purge emptied: one with no version yet is being written to. One
            // that stays is purged again at the next open or save.
            if removed && version_ids(&dir).is_empty() {
                let _ = remove_dir(&dir);
            }
        }
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    fn temp(name: &str) -> PathBuf {
        let dir =
            std::env::temp_dir().join(format!("ferman-versions-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        dir
    }

    fn saved(edits: u32, names: &[&str]) -> NewVersion {
        NewVersion {
            kind: VersionKind::Saved,
            edits,
            names: names.iter().map(|name| (*name).to_owned()).collect(),
            encrypted: false,
        }
    }

    #[test]
    fn versions_are_written_listed_read_found_after_a_rename_and_purged() {
        let root = temp("cycle");
        let versions = Versions::new(root.clone());
        let file = PathBuf::from("/docs/Kira.pdf");
        let start = UNIX_EPOCH + Duration::from_secs(1_800_000_000);
        let first = b"%PDF-1.7 first".to_vec();
        let opened = NewVersion {
            kind: VersionKind::Opened,
            ..saved(0, &[])
        };
        let a = versions
            .add(&file, &sha256(&first), &first, &opened, start)
            .unwrap()
            .unwrap();
        let second = b"%PDF-1.7 second".to_vec();
        let b = versions
            .add(
                &file,
                &sha256(&first),
                &second,
                &saved(2, &["Madde 4", "Madde 6"]),
                start + Duration::from_secs(60),
            )
            .unwrap()
            .unwrap();
        // The same bytes again make no second row.
        assert!(
            versions
                .add(&file, &sha256(&second), &second, &saved(0, &[]), start)
                .unwrap()
                .is_none()
        );
        let list = versions.list(&file, &[0; 32]);
        assert_eq!(list.len(), 2);
        assert_eq!(list[0], b);
        assert_eq!(list[1], a);
        assert_eq!(list[0].names, ["Madde 4", "Madde 6"]);
        assert_eq!(versions.read(&file, &[0; 32], a.id).unwrap(), first);
        // A renamed file is found by the hash of its last saved bytes.
        let renamed = PathBuf::from("/docs/Kira (2).pdf");
        assert_eq!(versions.list(&renamed, &sha256(&second)).len(), 2);
        assert!(versions.list(&renamed, &sha256(&first)).is_empty());
        // Owner-only.
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt as _;
            let mode = fs::metadata(&root).unwrap().permissions().mode();
            assert_eq!(mode & 0o077, 0);
        }
        // Thirty days after the second, the first is gone; after another minute, the folder.
        versions.purge(start + KEEP + Duration::from_secs(30), KEEP);
        assert_eq!(versions.list(&file, &[0; 32]), std::slice::from_ref(&b));
        versions.purge(start + KEEP + Duration::from_secs(61), KEEP);
        assert!(versions.list(&file, &[0; 32]).is_empty());
        assert!(versions.folders().is_empty());
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn a_copy_of_the_file_does_not_take_over_its_history() {
        let root = temp("copy");
        let versions = Versions::new(root.join("versions"));
        let original = root.join("Template.pdf");
        let copy = root.join("Client A.pdf");
        let bytes = b"%PDF-1.7 template".to_vec();
        fs::create_dir_all(&root).unwrap();
        fs::write(&original, &bytes).unwrap();
        fs::write(&copy, &bytes).unwrap();
        let sha = sha256(&bytes);
        versions
            .add(&original, &sha, &bytes, &saved(1, &[]), SystemTime::now())
            .unwrap();
        assert!(versions.list(&copy, &sha).is_empty());
        assert_eq!(versions.list(&original, &sha).len(), 1);
        // Once the original is gone, the same bytes are its file renamed.
        fs::remove_file(&original).unwrap();
        assert_eq!(versions.list(&copy, &sha).len(), 1);
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn a_copy_left_without_its_row_is_purged_by_its_age() {
        let root = temp("orphan");
        let versions = Versions::new(root.clone());
        let file = PathBuf::from("/docs/Kira.pdf");
        let now = SystemTime::now();
        let row = versions
            .add(&file, &[0; 32], b"%PDF-1.7 kept", &saved(0, &[]), now)
            .unwrap()
            .unwrap();
        let dir = versions.find(&file, &[0; 32]).unwrap();
        let stray = dir.join("17.pdf");
        fs::write(&stray, b"%PDF-1.7 cut off").unwrap();
        versions.purge(now + Duration::from_secs(60), KEEP);
        assert!(stray.exists(), "younger than KEEP");
        let later = now + KEEP;
        versions
            .add(&file, &[0; 32], b"%PDF-1.7 later", &saved(1, &[]), later)
            .unwrap();
        versions.purge(later + Duration::from_secs(60), KEEP);
        assert!(!stray.exists());
        assert!(!dir.join(format!("{}.pdf", row.id)).exists());
        assert_eq!(versions.list(&file, &[0; 32]).len(), 1);
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn an_encrypted_documents_rows_keep_counts_only_and_a_damaged_copy_is_not_read() {
        let root = temp("encrypted");
        let versions = Versions::new(root.clone());
        let file = PathBuf::from("/docs/Bordro.pdf");
        let bytes = b"%PDF-1.7 encrypted".to_vec();
        let version = NewVersion {
            encrypted: true,
            ..saved(3, &["Maaş 18.500 TL"])
        };
        let row = versions
            .add(&file, &[1; 32], &bytes, &version, SystemTime::now())
            .unwrap()
            .unwrap();
        assert_eq!(row.edits, 3);
        assert!(row.names.is_empty());
        let dir = versions.find(&file, &[0; 32]).unwrap();
        let json = fs::read_to_string(dir.join(format!("{}.json", row.id))).unwrap();
        assert!(!json.contains("Maa"));
        fs::write(dir.join(format!("{}.pdf", row.id)), b"changed").unwrap();
        assert!(versions.read(&file, &[0; 32], row.id).is_err());
        versions.remove(&file, &[0; 32], row.id).unwrap();
        assert!(versions.list(&file, &[0; 32]).is_empty());
        let _ = fs::remove_dir_all(root);
    }
}
