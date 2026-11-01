//! Writing a file for the user without ever corrupting one (ADR 0008, docs/ARCHITECTURE.md §7):
//! a temp file created exclusively beside the target, every byte written and flushed to the disk,
//! read back and compared, then renamed over the target in one step, and the directory flushed.
//! A failure leaves the target as it was and deletes the temp file.
//!
//! M2 writes only new files with it: an embedded file saved with "Save attachment as…" (a2-3b,
//! B110). The incremental writer and the full rewrite of M3 build on it.
//!
//! Under the macOS App Sandbox a file chosen in the save panel is granted on its own, not its
//! folder, so the platform layer names a staging directory (the system's item-replacement
//! directory on the same volume): the temp file is written and verified there, and the platform
//! layer swaps it in with `replaceItemAt`.
//!
//! shortcut: on Windows the rename is the standard library's (`MoveFileExW` replacing the target),
//! not `ReplaceFileW`, which needs `unsafe` FFI; it keeps no metadata of a file it replaces, which a
//! new attachment file does not have. The document writer (M3) brings `ReplaceFileW` with the
//! owner's approval of its unsafe call.

use std::fs::{self, File, OpenOptions};
use std::io::{ErrorKind, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

use crate::CoreError;

/// Writes `bytes` as the file at `target`, replacing what is there.
///
/// With `staging`, the verified temp file stays in that directory and its path is returned for the
/// platform layer to swap in; `target` is not touched. Without it, the temp file is made beside
/// `target` and renamed over it, and `None` is returned.
///
/// # Errors
///
/// [`CoreError::Io`] when a step fails, `InvalidData` when the bytes read back differ, and
/// `InvalidInput` for a target without a file name or folder.
pub fn safe_write(
    target: &Path,
    bytes: &[u8],
    staging: Option<&Path>,
) -> Result<Option<PathBuf>, CoreError> {
    // A symbolic link is followed: the file it names is replaced, never the link.
    let target = match fs::canonicalize(target) {
        Ok(resolved) => resolved,
        Err(_) => target.to_path_buf(),
    };
    let (Some(folder), Some(name)) = (target.parent(), target.file_name()) else {
        return Err(io(ErrorKind::InvalidInput));
    };
    let folder = staging.unwrap_or(folder);
    let (temp, mut file) = create_temp(folder, &name.to_string_lossy())?;
    let written = write_verified(&mut file, &temp, bytes);
    drop(file);
    if let Err(err) = written {
        let _ = fs::remove_file(&temp);
        return Err(err);
    }
    if staging.is_some() {
        return Ok(Some(temp));
    }
    if let Err(err) = fs::rename(&temp, &target) {
        let _ = fs::remove_file(&temp);
        return Err(io(err.kind()));
    }
    sync_folder(folder);
    Ok(None)
}

/// A new temp file in `folder` for the file `name`: `.<name>.ferman-<unique>.tmp`, created
/// exclusively so it never opens a file that is there already.
fn create_temp(folder: &Path, name: &str) -> Result<(PathBuf, File), CoreError> {
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |elapsed| elapsed.subsec_nanos());
    for _ in 0..16 {
        let unique = format!(
            "{:x}{nanos:x}{:x}",
            std::process::id(),
            COUNTER.fetch_add(1, Ordering::Relaxed)
        );
        let path = folder.join(format!(".{name}.ferman-{unique}.tmp"));
        match OpenOptions::new().write(true).create_new(true).open(&path) {
            Ok(file) => return Ok((path, file)),
            Err(err) if err.kind() == ErrorKind::AlreadyExists => {}
            Err(err) => return Err(io(err.kind())),
        }
    }
    Err(io(ErrorKind::AlreadyExists))
}

/// Writes `bytes`, flushes them to the disk (`F_FULLFSYNC` on macOS, `FlushFileBuffers` on
/// Windows, through `sync_all`) and reads the file back to compare.
fn write_verified(file: &mut File, path: &Path, bytes: &[u8]) -> Result<(), CoreError> {
    file.write_all(bytes).map_err(|err| io(err.kind()))?;
    file.sync_all().map_err(|err| io(err.kind()))?;
    let mut read = Vec::with_capacity(bytes.len());
    File::open(path)
        .and_then(|mut back| back.read_to_end(&mut read))
        .map_err(|err| io(err.kind()))?;
    if read != bytes {
        return Err(io(ErrorKind::InvalidData));
    }
    Ok(())
}

/// Flushes the folder's entry for the renamed file; Windows needs none, and a failure loses
/// nothing that was not flushed already.
fn sync_folder(folder: &Path) {
    #[cfg(unix)]
    if let Ok(dir) = File::open(folder) {
        let _ = dir.sync_all();
    }
    #[cfg(not(unix))]
    let _ = folder;
}

fn io(kind: ErrorKind) -> CoreError {
    CoreError::Io { kind }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("ferman-save-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn names(dir: &Path) -> Vec<String> {
        let mut names: Vec<_> = fs::read_dir(dir)
            .unwrap()
            .map(|entry| entry.unwrap().file_name().to_string_lossy().into_owned())
            .collect();
        names.sort();
        names
    }

    #[test]
    fn writes_a_new_file_and_replaces_an_old_one_leaving_no_temp_file() {
        let dir = temp_dir("replace");
        let target = dir.join("ekler.csv");
        assert_eq!(safe_write(&target, b"a,b\n", None).unwrap(), None);
        assert_eq!(fs::read(&target).unwrap(), b"a,b\n");
        safe_write(&target, b"c\n", None).unwrap();
        assert_eq!(fs::read(&target).unwrap(), b"c\n");
        assert_eq!(names(&dir), ["ekler.csv"]);
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_failed_write_leaves_the_target_and_no_temp_file() {
        let dir = temp_dir("fail");
        let target = dir.join("missing-folder").join("ekler.csv");
        let err = safe_write(&target, b"x", None).unwrap_err();
        assert!(matches!(
            err,
            CoreError::Io {
                kind: ErrorKind::NotFound
            }
        ));
        assert!(names(&dir).is_empty());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn with_a_staging_folder_the_verified_temp_file_stays_there() {
        let dir = temp_dir("staging");
        let staging = temp_dir("staging-replacement");
        let target = dir.join("ekler.csv");
        let staged = safe_write(&target, b"a,b\n", Some(&staging))
            .unwrap()
            .unwrap();
        assert_eq!(staged.parent(), Some(staging.as_path()));
        assert_eq!(fs::read(&staged).unwrap(), b"a,b\n");
        assert!(!target.exists());
        fs::remove_dir_all(dir).unwrap();
        fs::remove_dir_all(staging).unwrap();
    }

    #[cfg(unix)]
    #[test]
    fn a_symbolic_link_keeps_pointing_at_the_replaced_file() {
        let dir = temp_dir("link");
        let real = dir.join("real.csv");
        fs::write(&real, b"old").unwrap();
        let link = dir.join("link.csv");
        std::os::unix::fs::symlink(&real, &link).unwrap();
        safe_write(&link, b"new", None).unwrap();
        assert!(
            fs::symlink_metadata(&link)
                .unwrap()
                .file_type()
                .is_symlink()
        );
        assert_eq!(fs::read(&real).unwrap(), b"new");
        fs::remove_dir_all(dir).unwrap();
    }
}
