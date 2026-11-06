//! Writing a file for the user without ever corrupting one (ADR 0008, docs/ARCHITECTURE.md §7.2,
//! §7.5 and §7.8).
//!
//! The sequence: the target's symbolic link resolved (the file it names is replaced, the link
//! stays); a read-only target, or one with other hard links, refused; leftover temp files of
//! crashed saves deleted; free space checked for the new file plus a margin; a temp file
//! `.<name>.ferman-<unique>.tmp` created exclusively beside the target (hidden on Windows),
//! written, flushed to the disk (`sync_all`: `fsync`, `F_FULLFSYNC` on Apple platforms,
//! `FlushFileBuffers`), read back and compared (a PDF's cross-reference data parsed, an
//! incremental update checked to start with the original bytes); the target's metadata copied
//! (mode bits, owner and group, and on macOS ACLs and extended attributes with `fcopyfile`); the
//! temp file swapped in (`rename(2)`, `ReplaceFileW` on Windows), retried with backoff while
//! another app holds the file; the folder flushed.
//!
//! Every failure leaves the target as it was and deletes the temp file, and reads as a
//! [`SaveError`] when it has a kind of its own (§7.8), [`CoreError::Io`] otherwise. A process
//! killed at any point leaves the old file or the new one, never a mix; the crash test kills a
//! save at 1,000 points (100 by default, `FERMAN_CRASH_POINTS` for more).
//!
//! [`save_pdf`] also checks that the file is still the one opened or last saved (§7.5): size and
//! modification time, then the SHA-256 when either differs.
//!
//! Under the macOS App Sandbox a file chosen in the save panel is granted on its own, not its
//! folder, so the platform layer names a staging directory (the system's item-replacement
//! directory on the same volume): the temp file is written and verified there ([`stage_pdf`],
//! [`safe_write`]), and the platform layer swaps it in with `replaceItemAt`, which keeps the
//! metadata itself but not a hard link or another user's ownership, so those are refused as ever.

use std::fs::{self, File, Metadata, OpenOptions};
use std::io::{self, ErrorKind, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use sha2::{Digest, Sha256};

use crate::limits::Limits;
use crate::{CoreError, SaveError, platform, sniff, xref};

/// Free space needed past the new file's size.
const MARGIN: u64 = 1 << 20;

/// How much is written between two checks of the fault seam; small in tests, so the crash test
/// stops inside the data.
const CHUNK: usize = if cfg!(test) { 512 } else { 1 << 20 };

/// The waits between attempts to replace a file another app holds, under one second in all.
const BACKOFF_MS: [u64; 4] = [50, 100, 200, 400];

/// A temp file of an earlier save is deleted only once it is this old, so another instance's
/// save in progress is never touched.
const STALE: Duration = Duration::from_secs(600);

/// A file's size, modification time and SHA-256, recorded at open and after each save
/// (docs/ARCHITECTURE.md §7.5).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileStamp {
    /// The size in bytes.
    pub size: u64,
    /// The modification time, if the system has one.
    pub modified: Option<SystemTime>,
    /// The SHA-256 of the bytes.
    pub sha256: [u8; 32],
}

impl FileStamp {
    /// Whether the file at `path` is no longer the one stamped: its size differs, or its
    /// modification time differs and so does its hash. A file that is gone has not changed:
    /// saving writes it again.
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`] when the file cannot be read.
    pub fn changed(&self, path: &Path) -> Result<bool, CoreError> {
        let path = resolve(path);
        let metadata = match fs::metadata(&path) {
            Ok(metadata) => metadata,
            Err(err) if err.kind() == ErrorKind::NotFound => return Ok(false),
            Err(err) => return Err(io(err.kind())),
        };
        if metadata.len() != self.size {
            return Ok(true);
        }
        if self.modified.is_some() && metadata.modified().ok() == self.modified {
            return Ok(false);
        }
        Ok(hash_file(&path)? != self.sha256)
    }

    /// The stamp of `bytes` about to be a file, with no modification time yet.
    fn of(bytes: &[u8]) -> Self {
        Self {
            size: u64::try_from(bytes.len()).unwrap_or(u64::MAX),
            modified: None,
            sha256: Sha256::digest(bytes).into(),
        }
    }

    /// This stamp with the modification time of the file now at `path`: what a save swapped in
    /// by the platform layer records once it is in place.
    #[must_use]
    pub fn settled(self, path: &Path) -> Self {
        Self {
            modified: fs::metadata(resolve(path))
                .and_then(|metadata| metadata.modified())
                .ok(),
            ..self
        }
    }
}

/// The SHA-256 of the file at `path`, read a part at a time.
fn hash_file(path: &Path) -> Result<[u8; 32], CoreError> {
    let mut file = File::open(path).map_err(|err| io(err.kind()))?;
    let mut hasher = Sha256::new();
    let mut chunk = vec![0u8; 1 << 20];
    loop {
        let read = file.read(&mut chunk).map_err(|err| io(err.kind()))?;
        match chunk.get(..read) {
            Some([]) | None => break,
            Some(part) => hasher.update(part),
        }
    }
    Ok(hasher.finalize().into())
}

/// Saves the document `bytes` as the file at `target`, replacing what is there, and returns
/// the new file's stamp.
///
/// `original` is the file the document was opened from when `bytes` are an incremental update
/// of it: it must be an exact prefix. With `expected`, a file at `target` that is no longer
/// that one stops the save with [`SaveError::ChangedOnDisk`].
///
/// # Errors
///
/// [`CoreError::Save`] with the failure's kind, [`CoreError::Io`] for one without, and
/// [`CoreError::Internal`] when `bytes` do not start with `original`. The target is as it was
/// and no temp file is left.
pub fn save_pdf(
    target: &Path,
    bytes: &[u8],
    original: Option<&[u8]>,
    expected: Option<&FileStamp>,
) -> Result<FileStamp, CoreError> {
    checked(target, bytes, original, expected)?;
    let request = Request {
        target,
        bytes,
        staging: None,
        pdf: true,
    };
    write(&request, &mut std::thread::sleep)?;
    Ok(FileStamp::of(bytes).settled(target))
}

/// Does what [`save_pdf`] does up to the swap, with the temp file in the directory `staging`:
/// every check, and `target` not touched. Returns the verified temp file's path, for the platform
/// layer to swap in, and the stamp to [settle](FileStamp::settled) once it has.
///
/// # Errors
///
/// As [`save_pdf`]; `target` is as it was and no temp file is left.
pub fn stage_pdf(
    target: &Path,
    staging: &Path,
    bytes: &[u8],
    original: Option<&[u8]>,
    expected: Option<&FileStamp>,
) -> Result<(PathBuf, FileStamp), CoreError> {
    checked(target, bytes, original, expected)?;
    let request = Request {
        target,
        bytes,
        staging: Some(staging),
        pdf: true,
    };
    let staged = write(&request, &mut std::thread::sleep)?.ok_or(CoreError::Internal {
        context: "a staged write without its temp file",
    })?;
    Ok((staged, FileStamp::of(bytes)))
}

/// The checks of a document's save before anything is written.
fn checked(
    target: &Path,
    bytes: &[u8],
    original: Option<&[u8]>,
    expected: Option<&FileStamp>,
) -> Result<(), CoreError> {
    if original.is_some_and(|original| !bytes.starts_with(original)) {
        return Err(CoreError::Internal {
            context: "an incremental update that does not start with the original",
        });
    }
    if let Some(expected) = expected
        && expected.changed(target)?
    {
        return Err(CoreError::Save(SaveError::ChangedOnDisk));
    }
    Ok(())
}

/// Writes `bytes` as the file at `target`, replacing what is there, through the same sequence
/// as [`save_pdf`] without its PDF checks.
///
/// With `staging`, the verified temp file stays in that directory and its path is returned for
/// the platform layer to swap in; `target` is not touched. Without it, `None` is returned.
///
/// # Errors
///
/// As [`save_pdf`]; `InvalidInput` for a target without a file name or folder, or one that is
/// not a file.
pub fn safe_write(
    target: &Path,
    bytes: &[u8],
    staging: Option<&Path>,
) -> Result<Option<PathBuf>, CoreError> {
    let request = Request {
        target,
        bytes,
        staging,
        pdf: false,
    };
    write(&request, &mut std::thread::sleep)
}

/// What to write where.
struct Request<'a> {
    target: &'a Path,
    bytes: &'a [u8],
    staging: Option<&'a Path>,
    /// Whether the bytes are a PDF whose cross-reference data must parse.
    pdf: bool,
}

/// The steps of the sequence, where the fault seam can fail or stop a save in tests.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Step {
    /// Looking at the target.
    Inspect,
    /// The free-space check.
    Space,
    /// Creating the temp file.
    Create,
    /// Writing the data from this offset.
    Write(usize),
    /// Flushing the temp file.
    Flush,
    /// Reading it back.
    Verify,
    /// Copying the target's metadata.
    Metadata,
    /// Giving the temp file the target's owner.
    Owner,
    /// Swapping it in.
    Replace,
    /// Flushing the folder.
    SyncFolder,
}

fn write(
    request: &Request<'_>,
    sleep: &mut dyn FnMut(Duration),
) -> Result<Option<PathBuf>, CoreError> {
    let target = resolve(request.target);
    let (Some(folder), Some(name)) = (target.parent(), target.file_name()) else {
        return Err(io(ErrorKind::InvalidInput));
    };
    let existing = match fault(Step::Inspect).and_then(|()| fs::metadata(&target)) {
        Ok(metadata) => Some(metadata),
        Err(err) if err.kind() == ErrorKind::NotFound => None,
        Err(err) => return Err(classify(Step::Inspect, &err)),
    };
    if let Some(metadata) = &existing {
        if !metadata.is_file() {
            return Err(io(ErrorKind::InvalidInput));
        }
        if metadata.permissions().readonly() {
            return Err(CoreError::Save(SaveError::PermissionDenied));
        }
        let links = platform::link_count(&target).map_err(|err| classify(Step::Inspect, &err))?;
        // A swap through the platform layer breaks a hard link just as a rename does.
        if links > 1 {
            return Err(CoreError::Save(SaveError::HardLinked));
        }
    }
    let folder = request.staging.unwrap_or(folder);
    remove_stale(folder);
    fault(Step::Space).map_err(|err| classify(Step::Space, &err))?;
    let needed = u64::try_from(request.bytes.len())
        .unwrap_or(u64::MAX)
        .saturating_add(MARGIN);
    if platform::free_space(folder).is_some_and(|free| free < needed) {
        return Err(CoreError::Save(SaveError::DiskFull));
    }

    let (temp, mut file) = create_temp(folder, &name.to_string_lossy())?;
    let written = write_verified(&mut file, &temp, request).and_then(|()| match &existing {
        Some(metadata) if request.staging.is_none() => keep_metadata(&target, metadata, &file),
        Some(metadata) => same_owner(metadata, &file),
        None => Ok(()),
    });
    drop(file);
    if let Err(err) = written {
        let _ = fs::remove_file(&temp);
        return Err(err);
    }
    if request.staging.is_some() {
        return Ok(Some(temp));
    }
    let replaced = retry(sleep, || {
        fault(Step::Replace)?;
        platform::replace(&temp, &target, existing.is_some())
    });
    if let Err(err) = replaced {
        // `ReplaceFileW` can fail after deleting the original (ERROR_UNABLE_TO_MOVE_REPLACEMENT):
        // the verified temp file is then the only copy on disk, so it stays.
        if existing.is_none() || fs::symlink_metadata(&target).is_ok() {
            let _ = fs::remove_file(&temp);
        }
        return Err(classify(Step::Replace, &err));
    }
    // The new file is in place; a folder that cannot be flushed loses nothing flushed already.
    if fault(Step::SyncFolder).is_ok() {
        sync_folder(folder);
    }
    Ok(None)
}

/// `target` with its symbolic links resolved; as given when it does not exist yet.
fn resolve(target: &Path) -> PathBuf {
    fs::canonicalize(target).unwrap_or_else(|_| target.to_path_buf())
}

/// A new temp file in `folder` for the file `name`: `.<name>.ferman-<unique>.tmp`, created
/// exclusively so it never opens a file that is there already.
fn create_temp(folder: &Path, name: &str) -> Result<(PathBuf, File), CoreError> {
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    fault(Step::Create).map_err(|err| classify(Step::Create, &err))?;
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
        let mut options = OpenOptions::new();
        options.write(true).create_new(true);
        match platform::hidden(&mut options).open(&path) {
            Ok(file) => return Ok((path, file)),
            Err(err) if err.kind() == ErrorKind::AlreadyExists => {}
            Err(err) => return Err(classify(Step::Create, &err)),
        }
    }
    Err(io(ErrorKind::AlreadyExists))
}

/// Whether `name` is one of the temp files [`create_temp`] makes.
fn is_temp_name(name: &str) -> bool {
    name.strip_prefix('.')
        .and_then(|name| name.strip_suffix(".tmp"))
        .and_then(|name| name.rsplit_once(".ferman-"))
        .is_some_and(|(file, unique)| {
            !file.is_empty() && !unique.is_empty() && unique.bytes().all(|b| b.is_ascii_hexdigit())
        })
}

/// Deletes the temp files of earlier saves in `folder` that a crash left behind: older than
/// this process's first save and than [`STALE`].
fn remove_stale(folder: &Path) {
    static FIRST_SAVE: OnceLock<SystemTime> = OnceLock::new();
    let first = *FIRST_SAVE.get_or_init(SystemTime::now);
    let Some(cutoff) = SystemTime::now().checked_sub(STALE) else {
        return;
    };
    let cutoff = cutoff.min(first);
    let Ok(entries) = fs::read_dir(folder) else {
        return;
    };
    for entry in entries.flatten() {
        if !is_temp_name(&entry.file_name().to_string_lossy()) {
            continue;
        }
        let old = entry.metadata().is_ok_and(|metadata| {
            metadata.is_file() && metadata.modified().is_ok_and(|modified| modified < cutoff)
        });
        if old {
            let _ = fs::remove_file(entry.path());
        }
    }
}

/// Writes the data, flushes it to the disk and reads the file back to compare.
fn write_verified(file: &mut File, path: &Path, request: &Request<'_>) -> Result<(), CoreError> {
    for (index, part) in request.bytes.chunks(CHUNK).enumerate() {
        fault(Step::Write(index.saturating_mul(CHUNK)))
            .and_then(|()| file.write_all(part))
            .map_err(|err| classify(Step::Write(0), &err))?;
    }
    fault(Step::Flush)
        .and_then(|()| file.sync_all())
        .map_err(|err| classify(Step::Flush, &err))?;
    let mut read = Vec::new();
    read.try_reserve_exact(request.bytes.len())
        .map_err(|_| CoreError::OutOfMemory {
            context: "reading a saved file back",
        })?;
    fault(Step::Verify)
        .and_then(|()| File::open(path))
        .and_then(|mut back| back.read_to_end(&mut read))
        .map_err(|err| classify(Step::Verify, &err))?;
    if read != request.bytes {
        return Err(CoreError::Save(SaveError::Verify));
    }
    if request.pdf {
        let base = read
            .get(sniff::header_offset(&read).unwrap_or(0)..)
            .unwrap_or_default();
        if !matches!(xref::read(base, &Limits::default()), Ok(Ok(_))) {
            return Err(CoreError::Save(SaveError::Verify));
        }
    }
    Ok(())
}

/// Gives the temp file `file` the metadata of the file at `target`: ACLs and extended attributes
/// on macOS (best effort: a volume without them still saves), owner and group, and mode bits.
/// An owner that cannot be kept is [`SaveError::NotOwner`]; a group the user is not in is lost,
/// as with every editor.
fn keep_metadata(target: &Path, metadata: &Metadata, file: &File) -> Result<(), CoreError> {
    fault(Step::Metadata).map_err(|err| classify(Step::Metadata, &err))?;
    if let Ok(from) = File::open(target) {
        let _ = platform::copy_metadata(&from, file);
    }
    if fault(Step::Owner).is_err() {
        return Err(CoreError::Save(SaveError::NotOwner));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt as _;
        let ours = file
            .metadata()
            .map_err(|err| classify(Step::Metadata, &err))?;
        if (metadata.uid(), metadata.gid()) != (ours.uid(), ours.gid())
            && std::os::unix::fs::fchown(file, Some(metadata.uid()), Some(metadata.gid())).is_err()
            && metadata.uid() != ours.uid()
        {
            return Err(CoreError::Save(SaveError::NotOwner));
        }
        // After fchown, which clears set-user-ID bits.
        file.set_permissions(metadata.permissions())
            .map_err(|err| classify(Step::Metadata, &err))?;
    }
    #[cfg(not(unix))]
    let _ = metadata;
    Ok(())
}

/// Fails when a swap through the platform layer would give the file at `metadata` to the user
/// who wrote `file`: `replaceItemAt` keeps the rest of the metadata, but no call there restores
/// an owner.
fn same_owner(metadata: &Metadata, file: &File) -> Result<(), CoreError> {
    if fault(Step::Owner).is_err() {
        return Err(CoreError::Save(SaveError::NotOwner));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt as _;
        let ours = file
            .metadata()
            .map_err(|err| classify(Step::Metadata, &err))?;
        if metadata.uid() != ours.uid() {
            return Err(CoreError::Save(SaveError::NotOwner));
        }
    }
    #[cfg(not(unix))]
    let _ = (metadata, file);
    Ok(())
}

/// Runs `op`, again after each wait of [`BACKOFF_MS`] while another app holds the file.
fn retry(
    sleep: &mut dyn FnMut(Duration),
    mut op: impl FnMut() -> io::Result<()>,
) -> io::Result<()> {
    for wait in BACKOFF_MS {
        match op() {
            Err(err) if save_error(&err) == Some(SaveError::FileLocked) => {
                sleep(Duration::from_millis(wait));
            }
            done => return done,
        }
    }
    op()
}

/// The kind of save failure `err` stands for, if it has one.
fn save_error(err: &io::Error) -> Option<SaveError> {
    if let Some(kind) = err.raw_os_error().and_then(platform::classify) {
        return Some(kind);
    }
    Some(match err.kind() {
        ErrorKind::StorageFull | ErrorKind::QuotaExceeded => SaveError::DiskFull,
        ErrorKind::PermissionDenied | ErrorKind::ReadOnlyFilesystem => SaveError::PermissionDenied,
        ErrorKind::ResourceBusy | ErrorKind::ExecutableFileBusy => SaveError::FileLocked,
        _ => return None,
    })
}

/// `err` at `step` as ferman-core's error: a replace that fails for a reason without a kind of
/// its own is [`SaveError::RenameFailed`].
fn classify(step: Step, err: &io::Error) -> CoreError {
    match save_error(err) {
        Some(kind) => CoreError::Save(kind),
        None if step == Step::Replace => CoreError::Save(SaveError::RenameFailed),
        None => io(err.kind()),
    }
}

/// Flushes the folder's entry for the renamed file; Windows needs none (`MOVEFILE_WRITE_THROUGH`).
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

/// The fault seam of the tests: a hook that fails, or stops the process at, a step.
#[cfg(test)]
type Fault = Box<dyn FnMut(Step) -> io::Result<()>>;

#[cfg(test)]
thread_local! {
    static FAULT: std::cell::RefCell<Option<Fault>> = std::cell::RefCell::new(None);
}

#[cfg(test)]
fn fault(step: Step) -> io::Result<()> {
    FAULT.with(|hook| hook.borrow_mut().as_mut().map_or(Ok(()), |hook| hook(step)))
}

#[cfg(not(test))]
#[inline]
#[allow(clippy::unnecessary_wraps)]
fn fault(_step: Step) -> io::Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    #[cfg(unix)]
    use std::process::Command;

    use super::*;
    use crate::revision::RevisionStore;
    use crate::{OpenOptions as Options, Source, open};

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

    /// Makes the error a fault returns.
    type MakeError = fn() -> io::Error;

    /// Runs `body` with `hook` as the fault seam.
    fn with_fault<T>(
        hook: impl FnMut(Step) -> io::Result<()> + 'static,
        body: impl FnOnce() -> T,
    ) -> T {
        FAULT.with(|seam| *seam.borrow_mut() = Some(Box::new(hook)));
        let result = body();
        FAULT.with(|seam| *seam.borrow_mut() = None);
        result
    }

    /// A corpus file and the same document rewritten whole: the old and the new file.
    fn old_and_new() -> (Vec<u8>, Vec<u8>) {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated/kira-tr.pdf");
        let old = fs::read(path).unwrap();
        let doc = open(&Source::from_bytes(old.clone().into()), &Options::default()).unwrap();
        let new = RevisionStore::new(&doc).full_rewrite(&doc).unwrap();
        assert_ne!(old, new);
        (old, new)
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

    #[test]
    fn a_staged_save_checks_as_a_save_does_and_leaves_the_target_until_the_swap() {
        let (old, new) = old_and_new();
        let dir = temp_dir("stage");
        let staging = temp_dir("stage-replacement");
        let target = dir.join("doc.pdf");
        fs::write(&target, &old).unwrap();
        let opened = FileStamp::of(&old).settled(&target);

        // Target untouched, the temp file verified, no modification time before the swap.
        let (staged, stamp) = stage_pdf(&target, &staging, &new, None, Some(&opened)).unwrap();
        assert_eq!(staged.parent(), Some(staging.as_path()));
        assert_eq!(fs::read(&staged).unwrap(), new);
        assert_eq!(fs::read(&target).unwrap(), old);
        assert_eq!(names(&dir), ["doc.pdf"]);
        assert_eq!(stamp.modified, None);
        assert!(stamp.changed(&target).unwrap());

        // The swap, then the stamp: this is the file now.
        fs::rename(&staged, &target).unwrap();
        let settled = stamp.settled(&target);
        assert!(settled.modified.is_some());
        assert!(!settled.changed(&target).unwrap());

        // A file that changed under the document stops it, and so does a bad incremental update.
        let err = stage_pdf(&target, &staging, &new, None, Some(&opened)).unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::ChangedOnDisk)));
        let err = stage_pdf(&target, &staging, &old, Some(&new), None).unwrap_err();
        assert!(matches!(err, CoreError::Internal { .. }));
        // Bytes that are no PDF do not pass the read-back.
        let err = stage_pdf(&target, &staging, b"not a pdf", None, None).unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::Verify)));
        assert_eq!(fs::read(&target).unwrap(), new);
        assert!(names(&staging).is_empty());
        fs::remove_dir_all(dir).unwrap();
        fs::remove_dir_all(staging).unwrap();
    }

    #[test]
    fn a_staged_save_refuses_hard_links_and_an_owner_it_cannot_keep() {
        let (old, new) = old_and_new();
        let dir = temp_dir("stage-refused");
        let staging = temp_dir("stage-refused-replacement");
        let target = dir.join("doc.pdf");
        fs::write(&target, &old).unwrap();

        let err = with_fault(
            |step| {
                if step == Step::Owner {
                    Err(ErrorKind::Other.into())
                } else {
                    Ok(())
                }
            },
            || stage_pdf(&target, &staging, &new, None, None).unwrap_err(),
        );
        assert!(matches!(err, CoreError::Save(SaveError::NotOwner)));

        fs::hard_link(&target, dir.join("other.pdf")).unwrap();
        let err = stage_pdf(&target, &staging, &new, None, None).unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::HardLinked)));

        assert_eq!(fs::read(&target).unwrap(), old);
        assert!(names(&staging).is_empty());
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

    #[test]
    fn every_failure_on_every_step_leaves_the_original_and_no_temp_file() {
        let (old, new) = old_and_new();
        assert!(new.len() > 2 * CHUNK);
        let dir = temp_dir("faults");
        let target = dir.join("doc.pdf");
        let steps = [
            Step::Inspect,
            Step::Space,
            Step::Create,
            Step::Write(0),
            Step::Write(CHUNK),
            Step::Flush,
            Step::Verify,
            Step::Metadata,
            Step::Replace,
        ];
        let errors: [(MakeError, Option<SaveError>); 5] = [
            (|| ErrorKind::StorageFull.into(), Some(SaveError::DiskFull)),
            (
                || ErrorKind::PermissionDenied.into(),
                Some(SaveError::PermissionDenied),
            ),
            (
                || ErrorKind::ReadOnlyFilesystem.into(),
                Some(SaveError::PermissionDenied),
            ),
            (
                #[cfg(unix)]
                || io::Error::from_raw_os_error(libc::EIO),
                #[cfg(windows)]
                || io::Error::from_raw_os_error(55),
                Some(SaveError::VolumeGone),
            ),
            (|| ErrorKind::Other.into(), None),
        ];
        for step in steps {
            for (make, expected) in errors {
                fs::write(&target, &old).unwrap();
                let err = with_fault(
                    move |at| if at == step { Err(make()) } else { Ok(()) },
                    || save_pdf(&target, &new, None, None),
                )
                .unwrap_err();
                let expected = match expected {
                    Some(kind) => Some(kind),
                    None if step == Step::Replace => Some(SaveError::RenameFailed),
                    None => None,
                };
                match (err, expected) {
                    (CoreError::Save(kind), Some(expected)) => {
                        assert_eq!(kind, expected, "{step:?}");
                    }
                    (CoreError::Io { kind }, None) => assert_eq!(kind, ErrorKind::Other),
                    (err, expected) => panic!("{step:?}: {err:?}, expected {expected:?}"),
                }
                assert_eq!(
                    fs::read(&target).unwrap(),
                    old,
                    "{step:?} keeps the original"
                );
                assert_eq!(names(&dir), ["doc.pdf"], "{step:?} leaves no temp file");
            }
        }
        // An owner that cannot be restored.
        let err = with_fault(
            |at| {
                if at == Step::Owner {
                    Err(ErrorKind::PermissionDenied.into())
                } else {
                    Ok(())
                }
            },
            || save_pdf(&target, &new, None, None),
        )
        .unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::NotOwner)));
        assert_eq!(fs::read(&target).unwrap(), old);
        assert_eq!(names(&dir), ["doc.pdf"]);
        // A folder that cannot be flushed: the new file is in place.
        with_fault(
            |at| {
                if at == Step::SyncFolder {
                    Err(ErrorKind::Other.into())
                } else {
                    Ok(())
                }
            },
            || save_pdf(&target, &new, None, None),
        )
        .unwrap();
        assert_eq!(fs::read(&target).unwrap(), new);
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_locked_file_is_retried_with_backoff_then_reported() {
        let dir = temp_dir("locked");
        let target = dir.join("doc.txt");
        fs::write(&target, b"old").unwrap();
        let request = Request {
            target: &target,
            bytes: b"new",
            staging: None,
            pdf: false,
        };
        let locked = || ErrorKind::ResourceBusy.into();
        let mut slept = Vec::new();
        let err = with_fault(
            move |at| {
                if at == Step::Replace {
                    Err(locked())
                } else {
                    Ok(())
                }
            },
            || write(&request, &mut |wait| slept.push(wait)),
        )
        .unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::FileLocked)));
        assert_eq!(slept, BACKOFF_MS.map(Duration::from_millis));
        assert!(slept.iter().sum::<Duration>() < Duration::from_secs(1));
        assert_eq!(fs::read(&target).unwrap(), b"old");
        assert_eq!(names(&dir), ["doc.txt"]);

        // Released after two attempts.
        let mut attempts = 0;
        let mut slept = Vec::new();
        with_fault(
            move |at| {
                if at == Step::Replace && attempts < 2 {
                    attempts += 1;
                    return Err(locked());
                }
                Ok(())
            },
            || write(&request, &mut |wait| slept.push(wait)),
        )
        .unwrap();
        assert_eq!(slept.len(), 2);
        assert_eq!(fs::read(&target).unwrap(), b"new");
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn hard_links_and_read_only_files_are_refused() {
        let dir = temp_dir("refused");
        let target = dir.join("doc.txt");
        fs::write(&target, b"old").unwrap();
        fs::hard_link(&target, dir.join("other.txt")).unwrap();
        let err = safe_write(&target, b"new", None).unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::HardLinked)));
        assert_eq!(fs::read(&target).unwrap(), b"old");
        fs::remove_file(dir.join("other.txt")).unwrap();

        let mut permissions = fs::metadata(&target).unwrap().permissions();
        permissions.set_readonly(true);
        fs::set_permissions(&target, permissions.clone()).unwrap();
        let err = safe_write(&target, b"new", None).unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::PermissionDenied)));
        assert_eq!(fs::read(&target).unwrap(), b"old");
        assert_eq!(names(&dir), ["doc.txt"]);
        #[allow(clippy::permissions_set_readonly_false)]
        permissions.set_readonly(false);
        fs::set_permissions(&target, permissions).unwrap();
        fs::remove_dir_all(dir).unwrap();
    }

    #[cfg(unix)]
    #[test]
    fn the_mode_bits_are_kept() {
        use std::os::unix::fs::PermissionsExt as _;
        let dir = temp_dir("mode");
        let target = dir.join("doc.txt");
        fs::write(&target, b"old").unwrap();
        fs::set_permissions(&target, fs::Permissions::from_mode(0o640)).unwrap();
        safe_write(&target, b"new", None).unwrap();
        assert_eq!(
            fs::metadata(&target).unwrap().permissions().mode() & 0o777,
            0o640
        );
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn the_new_file_has_a_new_modification_time() {
        let dir = temp_dir("mtime");
        let target = dir.join("doc.txt");
        fs::write(&target, b"old").unwrap();
        let old = SystemTime::now() - Duration::from_secs(3600);
        File::options()
            .write(true)
            .open(&target)
            .unwrap()
            .set_modified(old)
            .unwrap();
        safe_write(&target, b"new", None).unwrap();
        assert!(fs::metadata(&target).unwrap().modified().unwrap() > old);
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_replace_that_lost_the_original_keeps_the_temp_file() {
        let dir = temp_dir("lost");
        let target = dir.join("doc.txt");
        fs::write(&target, b"old").unwrap();
        let gone = target.clone();
        let err = with_fault(
            move |at| {
                if at == Step::Replace {
                    // As ReplaceFileW after deleting the original.
                    let _ = fs::remove_file(&gone);
                    return Err(ErrorKind::Other.into());
                }
                Ok(())
            },
            || safe_write(&target, b"new", None),
        )
        .unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::RenameFailed)));
        let left = names(&dir);
        assert_eq!(left.len(), 1);
        assert!(is_temp_name(&left[0]));
        assert_eq!(fs::read(dir.join(&left[0])).unwrap(), b"new");
        fs::remove_dir_all(dir).unwrap();
    }

    #[cfg(target_vendor = "apple")]
    #[test]
    fn extended_attributes_are_kept() {
        let dir = temp_dir("xattr");
        let target = dir.join("doc.txt");
        fs::write(&target, b"old").unwrap();
        let tag = "io.github.kerembas.ferman.test";
        assert!(
            Command::new("xattr")
                .args(["-w", tag, "kept"])
                .arg(&target)
                .status()
                .unwrap()
                .success()
        );
        safe_write(&target, b"new", None).unwrap();
        let out = Command::new("xattr")
            .args(["-p", tag])
            .arg(&target)
            .output()
            .unwrap();
        assert_eq!(out.stdout.trim_ascii(), b"kept");
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_file_changed_on_disk_stops_the_save() {
        let (old, new) = old_and_new();
        let dir = temp_dir("changed");
        let target = dir.join("doc.pdf");
        fs::write(&target, &old).unwrap();
        let stamp = Source::read(&target).unwrap().stamp();
        assert!(!stamp.changed(&target).unwrap());
        // The same bytes written again: a new time, the same hash.
        fs::write(&target, &old).unwrap();
        let file = File::options().write(true).open(&target).unwrap();
        file.set_modified(SystemTime::now() + Duration::from_secs(5))
            .unwrap();
        drop(file);
        assert!(!stamp.changed(&target).unwrap());

        let mut other = old.clone();
        *other.last_mut().unwrap() ^= 1;
        fs::write(&target, &other).unwrap();
        assert!(stamp.changed(&target).unwrap());
        let err = save_pdf(&target, &new, None, Some(&stamp)).unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::ChangedOnDisk)));
        assert!(!SaveError::ChangedOnDisk.offers_save_as());
        assert_eq!(fs::read(&target).unwrap(), other);

        // Keep mine: saved without the check, and the new stamp matches.
        let saved = save_pdf(&target, &new, None, None).unwrap();
        assert!(!saved.changed(&target).unwrap());
        assert_eq!(saved.size, new.len() as u64);
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn an_incremental_update_must_start_with_the_original() {
        let (old, new) = old_and_new();
        let dir = temp_dir("prefix");
        let target = dir.join("doc.pdf");
        let err = save_pdf(&target, &new, Some(&old), None).unwrap_err();
        assert!(matches!(err, CoreError::Internal { .. }));
        let mut update = old.clone();
        update.extend_from_slice(b"\n% nothing\n");
        // Its last startxref is still the original's, so it parses.
        save_pdf(&target, &update, Some(&old), None).unwrap();
        assert_eq!(fs::read(&target).unwrap(), update);
        // Bytes that are not a PDF do not verify.
        let err = save_pdf(&target, b"%PDF-1.7\nno table", None, None).unwrap_err();
        assert!(matches!(err, CoreError::Save(SaveError::Verify)));
        assert_eq!(fs::read(&target).unwrap(), update);
        assert_eq!(names(&dir), ["doc.pdf"]);
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn leftover_temp_files_of_crashed_saves_are_deleted() {
        let dir = temp_dir("stale");
        let target = dir.join("doc.txt");
        let old_temp = dir.join(".doc.txt.ferman-1a2b3c.tmp");
        let new_temp = dir.join(".doc.txt.ferman-4d5e6f.tmp");
        let lookalike = dir.join(".doc.txt.ferman-xyz.tmp");
        for path in [&old_temp, &new_temp, &lookalike] {
            fs::write(path, b"half").unwrap();
        }
        for path in [&old_temp, &lookalike] {
            let file = File::options().write(true).open(path).unwrap();
            file.set_modified(SystemTime::now() - Duration::from_secs(3600))
                .unwrap();
        }
        safe_write(&target, b"new", None).unwrap();
        assert_eq!(
            names(&dir),
            [
                ".doc.txt.ferman-4d5e6f.tmp",
                ".doc.txt.ferman-xyz.tmp",
                "doc.txt"
            ]
        );
        assert!(is_temp_name(".a b.pdf.ferman-0f.tmp"));
        assert!(!is_temp_name("a.pdf.ferman-0f.tmp"));
        assert!(!is_temp_name("..ferman-0f.tmp"));
        fs::remove_dir_all(dir).unwrap();
    }

    /// The child of the crash test: saves `FERMAN_CRASH_DIR/doc.pdf` and stops the process
    /// (`exit`, which runs no destructors and deletes nothing, as a kill would, without the
    /// crash report an abort makes on macOS) at the step `FERMAN_CRASH_AT` names. Without the
    /// variable it does nothing.
    #[test]
    fn crash_child() {
        let (Some(dir), Some(at)) = (
            std::env::var_os("FERMAN_CRASH_DIR"),
            std::env::var("FERMAN_CRASH_AT").ok(),
        ) else {
            return;
        };
        let target = PathBuf::from(dir).join("doc.pdf");
        let new = fs::read(target.with_extension("new")).unwrap();
        let old = fs::read(&target).unwrap();
        with_fault(
            move |step| {
                if format!("{step:?}") == at {
                    std::process::exit(86);
                }
                Ok(())
            },
            || {
                save_pdf(
                    &target,
                    &new,
                    None,
                    Some(&FileStamp {
                        size: old.len() as u64,
                        modified: None,
                        sha256: Sha256::digest(&old).into(),
                    }),
                )
            },
        )
        .unwrap();
    }

    /// ROADMAP §7 step 8: a save killed at 1,000 points leaves the old file or the new one, and
    /// both open. The points are seeded: a step, and for the data a chunk's offset. 100 run by
    /// default; `FERMAN_CRASH_POINTS` sets the count (CI runs 1,000).
    #[cfg(unix)]
    #[test]
    fn a_save_killed_at_any_point_leaves_the_old_or_the_new_file() {
        let (old, new) = old_and_new();
        let points: usize = std::env::var("FERMAN_CRASH_POINTS")
            .ok()
            .and_then(|count| count.parse().ok())
            .unwrap_or(100);
        let dir = temp_dir("crash");
        let target = dir.join("doc.pdf");
        fs::write(target.with_extension("new"), &new).unwrap();
        let chunks = new.len().div_ceil(CHUNK);
        let mut seed: u64 = 0x5EED_F00D;
        let mut next = |n: usize| {
            seed ^= seed << 13;
            seed ^= seed >> 7;
            seed ^= seed << 17;
            (seed % n as u64) as usize
        };
        let (mut kept_old, mut got_new) = (0, 0);
        for _ in 0..points {
            fs::write(&target, &old).unwrap();
            let step = match next(10) {
                0 => Step::Inspect,
                1 => Step::Space,
                2 => Step::Create,
                3..=5 => Step::Write(next(chunks) * CHUNK),
                6 => Step::Flush,
                7 => Step::Verify,
                8 => Step::Replace,
                _ => Step::SyncFolder,
            };
            let status = Command::new(std::env::current_exe().unwrap())
                .args([
                    "--exact",
                    "save::tests::crash_child",
                    "--test-threads=1",
                    "-q",
                ])
                .env("FERMAN_CRASH_DIR", &dir)
                .env("FERMAN_CRASH_AT", format!("{step:?}"))
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .status()
                .unwrap();
            assert!(!status.success(), "{step:?} stops the child");
            let bytes = fs::read(&target).unwrap();
            if bytes == old {
                kept_old += 1;
            } else {
                assert_eq!(bytes, new, "{step:?}: the old file or the new one");
                got_new += 1;
            }
            open(&Source::from_bytes(bytes.into()), &Options::default()).unwrap();
            for name in names(&dir) {
                if is_temp_name(&name) {
                    fs::remove_file(dir.join(name)).unwrap();
                }
            }
        }
        assert!(kept_old > 0 && got_new > 0, "{kept_old} old, {got_new} new");
        fs::remove_dir_all(dir).unwrap();
    }
}
