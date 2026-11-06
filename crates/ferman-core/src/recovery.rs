//! The recovery journal (docs/ARCHITECTURE.md §7.6 and §7.7, ADR 0008): what an edited document
//! needs to come back after a crash, in the app data directory.
//!
//! ```text
//! <root>/<session>/instance.lock          the running instance's lock, its PID and start time
//! <root>/<session>/<document>/manifest.json   the original's path, stamp, encrypted flag, last saved revision
//!                            /base.pdf        the bytes the document was opened from, up to 200 MB
//!                            /snapshot-<rev>.bin  every unsaved change, one record
//!                            /journal.log     the records after the snapshot
//! ```
//!
//! A [`RecoverySession`] holds `instance.lock` locked while the app runs; the system lets the lock
//! go when the process ends however it ends, so a session whose lock can be taken belongs to an
//! instance that is gone ([`list`]). A lock file with nothing in it belongs to a session that is
//! starting: it is written while locked. The session and document names are random hex, and every
//! directory is owner-only (0700 on Unix).
//!
//! A [`DocumentRecovery`] writes one document's files. Its first unsaved change copies the
//! original (the bytes in memory, so a file changed since cannot slip in) and writes the
//! manifest; each commit appends a record of the objects the revision changed, and an undo or
//! redo a record of every unsaved object, so replay is pure data and never depends on fonts or
//! engine behaviour (a physical log). Records are synced at most once per second
//! ([`DocumentRecovery::tick`] syncs the rest), and every minute with unsaved changes a snapshot
//! of every unsaved object is written through the atomic save sequence and the journal restarts.
//! The objects are written as PDF objects encrypted with the document's own key, as the
//! incremental writer writes them, so an encrypted document's text never reaches the disk in
//! plaintext. A save that reaches the revision on disk deletes the files.
//!
//! A record is its payload's length (`u32`, little endian), the first 8 bytes of the payload's
//! SHA-256 and the payload: a kind (1 for one revision's objects, 2 for every unsaved object),
//! a sequence number (`u64`), the revision (`u32`) and the count of unsaved changes (`u32`),
//! then the objects as `n g obj … endobj`. A snapshot is one record; journal records whose
//! sequence number it covers are skipped. A torn or damaged record ends the journal: what follows
//! it is ignored, so the journal is cut back to its whole records before anything is appended
//! again.
// Lengths come from files on disk (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeMap;
use std::fs::{self, File, OpenOptions};
use std::io::{self, ErrorKind, Seek as _, SeekFrom, Write as _};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use lopdf::{Object, ObjectId, Stream};
use sha2::{Digest, Sha256};

use crate::appendix::indirect;
use crate::limits::Limits;
use crate::revision::RevisionStore;
use crate::save::{FileStamp, safe_write};
use crate::security::system_random;
use crate::syntax::{Parser, is_whitespace};
use crate::{CoreError, Document};

/// Originals up to this size are copied into `base.pdf`; larger ones rely on the manifest's hash
/// (M3 plan decision 10).
pub const BASE_COPY_LIMIT: u64 = 200 * 1024 * 1024;

/// Journal records are synced at most this often.
pub const SYNC_INTERVAL: Duration = Duration::from_secs(1);

/// A snapshot is written this often while there are unsaved changes.
pub const SNAPSHOT_INTERVAL: Duration = Duration::from_secs(60);

const LOCK: &str = "instance.lock";
const MANIFEST: &str = "manifest.json";
const BASE: &str = "base.pdf";
const JOURNAL: &str = "journal.log";

/// A record's kinds.
const ONE_REVISION: u8 = 1;
const UNSAVED: u8 = 2;

/// The bytes before a record's payload: its length and checksum.
const FRAME: usize = 12;
/// The payload's fixed part: kind, sequence number, revision and changes.
const HEADER: usize = 17;

/// The manifest of one document's recovery files.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Manifest {
    /// The file the document saves to.
    pub original: PathBuf,
    /// That file as it was opened or last saved.
    pub stamp: FileStamp,
    /// Whether the document is encrypted: restoring asks for its password.
    pub encrypted: bool,
    /// The revision the file holds: the changes past it are unsaved.
    pub saved_revision: u64,
    /// Whether `base.pdf` holds the bytes the document was opened from.
    pub base: bool,
}

impl Manifest {
    /// The manifest as JSON.
    #[must_use]
    pub fn to_json(&self) -> String {
        let mut out = String::from("{\n  \"version\": 1,\n  \"original\": ");
        json_string(&mut out, &self.original.to_string_lossy());
        out.push_str(&format!(",\n  \"size\": {}", self.stamp.size));
        if let Some(since) = self
            .stamp
            .modified
            .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
        {
            out.push_str(&format!(
                ",\n  \"modified_secs\": {},\n  \"modified_nanos\": {}",
                since.as_secs(),
                since.subsec_nanos()
            ));
        }
        out.push_str(&format!(
            ",\n  \"sha256\": \"{}\",\n  \"encrypted\": {},\n  \"saved_revision\": {},\n  \"base\": {}\n}}\n",
            hex(&self.stamp.sha256),
            self.encrypted,
            self.saved_revision,
            self.base
        ));
        out
    }

    /// A manifest from the JSON [`to_json`](Self::to_json) writes; `None` when it is not one.
    #[must_use]
    pub fn parse(json: &[u8]) -> Option<Self> {
        let fields = flat_json(std::str::from_utf8(json).ok()?)?;
        let text = |key: &str| match fields.get(key) {
            Some(Json::Text(text)) => Some(text.clone()),
            _ => None,
        };
        let number = |key: &str| match fields.get(key) {
            Some(Json::Number(number)) => Some(*number),
            _ => None,
        };
        let flag = |key: &str| match fields.get(key) {
            Some(Json::Flag(flag)) => Some(*flag),
            _ => None,
        };
        let modified = match (number("modified_secs"), number("modified_nanos")) {
            (Some(secs), Some(nanos)) => UNIX_EPOCH.checked_add(Duration::new(
                secs,
                u32::try_from(nanos)
                    .ok()
                    .filter(|&nanos| nanos < 1_000_000_000)?,
            )),
            _ => None,
        };
        let digest = text("sha256")?;
        let mut sha256 = [0u8; 32];
        if digest.len() != 64 {
            return None;
        }
        for (byte, pair) in sha256.iter_mut().zip(digest.as_bytes().chunks(2)) {
            *byte = u8::from_str_radix(std::str::from_utf8(pair).ok()?, 16).ok()?;
        }
        Some(Self {
            original: PathBuf::from(text("original")?),
            stamp: FileStamp {
                size: number("size")?,
                modified,
                sha256,
            },
            encrypted: flag("encrypted")?,
            saved_revision: number("saved_revision")?,
            base: flag("base")?,
        })
    }

    /// The manifest in the document directory `dir`.
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`]; `InvalidData` for a manifest that does not parse.
    pub fn read(dir: &Path) -> Result<Self, CoreError> {
        let bytes = fs::read(dir.join(MANIFEST)).map_err(io)?;
        Self::parse(&bytes).ok_or(CoreError::Io {
            kind: ErrorKind::InvalidData,
        })
    }
}

/// The running instance's session directory, its lock held until the session is dropped.
#[derive(Debug)]
pub struct RecoverySession {
    dir: PathBuf,
    lock: Option<File>,
}

impl RecoverySession {
    /// Starts a session under `root`, which is created owner-only when it is missing: a new
    /// directory with a random name and `instance.lock` in it, locked, with this process's ID
    /// and start time.
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`] when the directory or the lock cannot be made, and
    /// [`WriteError::Random`](crate::WriteError::Random).
    pub fn start(root: &Path) -> Result<Self, CoreError> {
        make_dir(root).map_err(io)?;
        let dir = root.join(random_name()?);
        make_dir(&dir).map_err(io)?;
        let mut lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create_new(true)
            .open(dir.join(LOCK))
            .map_err(io)?;
        lock.try_lock()
            .map_err(|_| io_kind(ErrorKind::WouldBlock))?;
        let started = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |since| since.as_millis());
        writeln!(lock, "{}\n{started}", std::process::id()).map_err(io)?;
        Ok(Self {
            dir,
            lock: Some(lock),
        })
    }

    /// The session's directory.
    #[must_use]
    pub fn dir(&self) -> &Path {
        &self.dir
    }

    /// The session's name, its directory's.
    #[must_use]
    pub fn name(&self) -> String {
        self.dir
            .file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .unwrap_or_default()
    }
}

impl Drop for RecoverySession {
    /// A session that holds no document's files is deleted; one that does stays for the next
    /// launch to offer.
    fn drop(&mut self) {
        drop(self.lock.take());
        if document_dirs(&self.dir).is_empty() {
            let _ = fs::remove_dir_all(&self.dir);
        }
    }
}

/// A document of a session that ended without cleaning up: what a1-12 lists.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Recoverable {
    /// The session's name.
    pub session: String,
    /// The document's name in it.
    pub document: String,
    /// Its manifest.
    pub manifest: Manifest,
    /// How many unsaved changes the files hold.
    pub changes: u32,
    /// Whether the original changed on disk since the document was opened or saved (a11-7f).
    pub original_changed: bool,
}

/// The documents of the sessions under `root` whose instance is gone, `own` (the running
/// session's name) left out. A document whose files hold nothing to restore (a crash before its
/// first record, or a manifest that cannot be used) is deleted, and so is a crashed session
/// without documents.
#[must_use]
pub fn list(root: &Path, own: Option<&str>) -> Vec<Recoverable> {
    let mut found = Vec::new();
    let Ok(entries) = fs::read_dir(root) else {
        return found;
    };
    for entry in entries.flatten() {
        let session = entry.file_name().to_string_lossy().into_owned();
        let dir = entry.path();
        if Some(session.as_str()) == own || !valid_name(&session) || !dir.is_dir() || live(&dir) {
            continue;
        }
        for (document, path) in document_dirs(&dir) {
            let manifest = match Manifest::read(&path) {
                Ok(manifest) => manifest,
                Err(CoreError::Io {
                    kind: ErrorKind::NotFound | ErrorKind::InvalidData,
                }) => {
                    let _ = fs::remove_dir_all(&path);
                    continue;
                }
                Err(_) => continue,
            };
            let Some(newest) = latest(&path) else {
                if holds_nothing(&path) {
                    let _ = fs::remove_dir_all(&path);
                }
                continue;
            };
            let changes = newest.changes;
            let original_changed = manifest.stamp.changed(&manifest.original).unwrap_or(true);
            found.push(Recoverable {
                session: session.clone(),
                document,
                manifest,
                changes,
                original_changed,
            });
        }
        // Without its lock it may be a session that is starting.
        if document_dirs(&dir).is_empty() && dir.join(LOCK).exists() {
            let _ = fs::remove_dir_all(&dir);
        }
    }
    found.sort_by(|a, b| (&a.session, &a.document).cmp(&(&b.session, &b.document)));
    found
}

/// The directory of `document` in the crashed `session` under `root`; `None` for names that are
/// not a session's or a document's, and for a session a live instance holds.
#[must_use]
pub fn document_dir(root: &Path, session: &str, document: &str) -> Option<PathBuf> {
    (valid_name(session) && valid_name(document) && !live(&root.join(session)))
        .then(|| root.join(session).join(document))
}

/// Deletes the files of `document` of `session` under `root`, or the whole session without a
/// document; a session left without documents goes too. A live session is refused.
///
/// # Errors
///
/// [`CoreError::Io`]: `InvalidInput` for names that are not a session's or a document's,
/// `WouldBlock` for a live session, and what deleting reports.
pub fn discard(root: &Path, session: &str, document: Option<&str>) -> Result<(), CoreError> {
    if !valid_name(session) || document.is_some_and(|document| !valid_name(document)) {
        return Err(io_kind(ErrorKind::InvalidInput));
    }
    let dir = root.join(session);
    if live(&dir) {
        return Err(io_kind(ErrorKind::WouldBlock));
    }
    if let Some(document) = document {
        remove_dir(&dir.join(document))?;
        if !document_dirs(&dir).is_empty() {
            return Ok(());
        }
    }
    remove_dir(&dir)
}

/// Moves the files of a restored document, in the directory `dir` of a crashed session, into
/// the running session `into`, which takes them over; the crashed session goes once it has no
/// documents left. Files that cannot be moved stay where they are. Returns where they are.
#[must_use]
pub fn take(dir: &Path, into: &RecoverySession) -> PathBuf {
    let (Some(name), Some(session)) = (dir.file_name(), dir.parent()) else {
        return dir.to_path_buf();
    };
    if session == into.dir() {
        return dir.to_path_buf();
    }
    let moved = into.dir().join(name);
    if fs::rename(dir, &moved).is_err() {
        return dir.to_path_buf();
    }
    if !live(session) && document_dirs(session).is_empty() {
        let _ = fs::remove_dir_all(session);
    }
    moved
}

/// Whether a live instance holds the lock of the session directory `dir`. A lock file that is
/// still empty belongs to a session that is starting, and is left alone: probing it could make
/// that session's own lock fail. One that cannot be read counts as held (Windows refuses to read
/// a locked range).
fn live(dir: &Path) -> bool {
    let path = dir.join(LOCK);
    match fs::read(&path) {
        Ok(contents) if contents.is_empty() => return true,
        Ok(_) => {}
        Err(err) if err.kind() == ErrorKind::NotFound => return false,
        Err(_) => return true,
    }
    let Ok(file) = OpenOptions::new().read(true).write(true).open(&path) else {
        return true;
    };
    // The lock is released when `file` is dropped.
    file.try_lock().is_err()
}

/// Whether the document directory `dir` has no record to restore and nothing that could not be
/// read.
fn holds_nothing(dir: &Path) -> bool {
    snapshots(dir).is_empty()
        && match fs::read(dir.join(JOURNAL)) {
            Ok(journal) => records(&journal).is_empty(),
            Err(err) => err.kind() == ErrorKind::NotFound,
        }
}

/// The document directories of a session directory, by name.
fn document_dirs(dir: &Path) -> Vec<(String, PathBuf)> {
    let Ok(entries) = fs::read_dir(dir) else {
        return Vec::new();
    };
    entries
        .flatten()
        .filter(|entry| entry.path().is_dir())
        .filter_map(|entry| {
            let name = entry.file_name().to_string_lossy().into_owned();
            valid_name(&name).then(|| (name, entry.path()))
        })
        .collect()
}

/// A document's unsaved revision read back from its recovery files.
#[derive(Debug)]
pub struct Restored {
    /// The document's revisions: one, with every unsaved object (none when an undo went back past
    /// a save, so it differs from the file), or none when nothing is unsaved.
    pub store: RevisionStore,
    /// How many unsaved changes the files hold.
    pub changes: u32,
    /// Where the journal goes on, for [`DocumentRecovery::adopt`].
    pub resume: Resume,
}

/// Where a restored document's journal goes on.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Resume {
    /// The next record's sequence number.
    next: u64,
    /// The length of the journal's whole records: a torn tail is cut off.
    journal_len: u64,
}

/// Reads the snapshot and the journal of the document directory `dir` as changes of `doc`
/// (opened from `base.pdf` or the original, with its password): the newest snapshot, then the
/// records after it in order, each decrypted with the document's key.
///
/// # Errors
///
/// [`CoreError::Io`] when the files cannot be read, and the errors of parsing and decrypting an
/// object within the document's limits.
pub fn restore(dir: &Path, doc: &Document) -> Result<Restored, CoreError> {
    let mut objects = BTreeMap::new();
    let mut changes = 0;
    let mut covered = None;
    let snapshot = snapshots(dir)
        .into_iter()
        .filter_map(|path| fs::read(path).ok())
        .filter_map(|data| {
            let record = records(&data).into_iter().next()?;
            Some((record.seq, data))
        })
        .max_by_key(|(seq, _)| *seq);
    if let Some((_, data)) = &snapshot
        && let Some(record) = records(data).into_iter().next()
    {
        objects = read_objects(record.body, doc)?;
        changes = record.changes;
        covered = Some(record.seq);
    }
    let journal = match fs::read(dir.join(JOURNAL)) {
        Ok(journal) => journal,
        Err(err) if err.kind() == ErrorKind::NotFound => Vec::new(),
        Err(err) => return Err(io(err)),
    };
    let mut last = covered;
    for record in records(&journal) {
        if covered.is_some_and(|covered| record.seq <= covered) {
            continue;
        }
        // One revision's objects mean nothing without those before it (a snapshot that is gone).
        if record.kind == ONE_REVISION && last.is_none() {
            break;
        }
        let read = read_objects(record.body, doc)?;
        if record.kind == UNSAVED {
            objects = read;
        } else {
            objects.extend(read);
        }
        changes = record.changes;
        last = Some(record.seq);
    }
    Ok(Restored {
        store: RevisionStore::restored(doc, objects, changes > 0),
        changes,
        resume: Resume {
            next: last.map_or(0, |seq| seq.saturating_add(1)),
            journal_len: whole_records(&journal),
        },
    })
}

/// What changed the current revision.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Change {
    /// A commit: the newest revision's objects are recorded.
    Commit,
    /// An undo or a redo: every unsaved object is recorded.
    Move,
}

/// One document's recovery files, written as it is edited.
#[derive(Debug)]
pub struct DocumentRecovery {
    dir: PathBuf,
    original: PathBuf,
    stamp: FileStamp,
    /// The revision the file holds; `None` once a commit replaced it in the history, so no
    /// revision equals the file any more.
    saved: Option<usize>,
    /// The journal, once the files exist.
    journal: Option<File>,
    seq: u64,
    /// Whether the next record must hold every unsaved object: the journal has no base yet.
    fresh: bool,
    unsynced: bool,
    last_sync: Option<Instant>,
    last_snapshot: Option<Instant>,
    /// Whether records were written since the last snapshot.
    since_snapshot: bool,
}

impl DocumentRecovery {
    /// The recovery of a document that saves to `original`, stamped `stamp` and holding revision
    /// `saved` (`None` once no revision equals the file), in a new directory of `session`.
    /// Nothing is written before the first unsaved change.
    ///
    /// # Errors
    ///
    /// [`WriteError::Random`](crate::WriteError::Random).
    pub fn new(
        session: &RecoverySession,
        original: PathBuf,
        stamp: FileStamp,
        saved: Option<usize>,
    ) -> Result<Self, CoreError> {
        Ok(Self::at(
            session.dir().join(random_name()?),
            original,
            stamp,
            saved,
            0,
        ))
    }

    /// Takes over the files of a restored document in `dir` (moved into the running session):
    /// they stay until a save or a discard, and new records follow them, the first with every
    /// unsaved object.
    #[must_use]
    pub fn adopt(dir: PathBuf, resume: Resume, original: PathBuf, stamp: FileStamp) -> Self {
        let mut recovery = Self::at(dir, original, stamp, Some(0), resume.next);
        recovery.journal = open_journal(&recovery.dir.join(JOURNAL))
            .and_then(|mut journal| {
                journal.set_len(resume.journal_len)?;
                journal.seek(SeekFrom::End(0))?;
                Ok(journal)
            })
            .ok();
        recovery
    }

    fn at(
        dir: PathBuf,
        original: PathBuf,
        stamp: FileStamp,
        saved: Option<usize>,
        seq: u64,
    ) -> Self {
        Self {
            dir,
            original,
            stamp,
            saved,
            journal: None,
            seq,
            fresh: true,
            unsynced: false,
            last_sync: None,
            last_snapshot: None,
            since_snapshot: false,
        }
    }

    /// The document's directory.
    #[must_use]
    pub fn dir(&self) -> &Path {
        &self.dir
    }

    /// Whether the files exist.
    #[must_use]
    pub fn written(&self) -> bool {
        self.journal.is_some()
    }

    /// Records the change that made `store`'s current revision, at `now`: the files are made
    /// with the first unsaved change and deleted when an undo or redo reaches the revision saved.
    /// A commit is never that revision, even at its number: it replaced it in the history.
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`] and [`CoreError::Save`] when a file cannot be written, and
    /// [`WriteError::Random`](crate::WriteError::Random) for an encrypted document.
    pub fn record(
        &mut self,
        doc: &Document,
        store: &RevisionStore,
        change: Change,
        now: Instant,
    ) -> Result<(), CoreError> {
        let current = store.current();
        if change == Change::Commit && self.saved.is_some_and(|saved| current <= saved) {
            self.saved = None;
        }
        if self.saved == Some(current) {
            return self.clear();
        }
        if self.journal.is_none() {
            self.create(doc)?;
            self.last_snapshot = Some(now);
        }
        let everything = self.fresh || change == Change::Move;
        let objects = if everything {
            store.committed()
        } else {
            current
                .checked_sub(1)
                .and_then(|newest| store.revisions().get(newest))
                .map(|changes| {
                    changes
                        .objects
                        .iter()
                        .map(|(id, object)| (*id, object))
                        .collect()
                })
                .unwrap_or_default()
        };
        let kind = if everything { UNSAVED } else { ONE_REVISION };
        let record = self.encode(doc, kind, current, &objects)?;
        let journal = self.journal.as_mut().ok_or(CoreError::Internal {
            context: "a recovery journal that is not open",
        })?;
        let before = journal.stream_position().map_err(io)?;
        if let Err(err) = journal.write_all(&record) {
            // Nothing after a torn record is read: cut it off, and the next record holds all.
            let _ = journal
                .set_len(before)
                .and_then(|()| journal.seek(SeekFrom::Start(before)));
            self.fresh = true;
            self.since_snapshot = true;
            return Err(io(err));
        }
        self.fresh = false;
        self.since_snapshot = true;
        self.unsynced = true;
        self.tick(doc, store, now)
    }

    /// Syncs the journal when it was last synced a second ago or more, and writes a snapshot
    /// when the last one is a minute old and records followed it.
    ///
    /// # Errors
    ///
    /// As [`record`](Self::record).
    pub fn tick(
        &mut self,
        doc: &Document,
        store: &RevisionStore,
        now: Instant,
    ) -> Result<(), CoreError> {
        let Some(journal) = &self.journal else {
            return Ok(());
        };
        let due = |last: Option<Instant>, every| {
            last.is_none_or(|last| now.saturating_duration_since(last) >= every)
        };
        if self.unsynced && due(self.last_sync, SYNC_INTERVAL) {
            journal.sync_data().map_err(io)?;
            self.unsynced = false;
            self.last_sync = Some(now);
        }
        if self.since_snapshot && due(self.last_snapshot, SNAPSHOT_INTERVAL) {
            // Before the attempt: one that fails is tried again in a minute, not every second.
            self.last_snapshot = Some(now);
            self.snapshot(doc, store)?;
        }
        Ok(())
    }

    /// Writes every unsaved object as `snapshot-<rev>.bin` through the atomic sequence, deletes
    /// the older snapshots and restarts the journal.
    ///
    /// # Errors
    ///
    /// As [`record`](Self::record).
    pub fn snapshot(&mut self, doc: &Document, store: &RevisionStore) -> Result<(), CoreError> {
        if self.journal.is_none() {
            return Ok(());
        }
        let current = store.current();
        let record = self.encode(doc, UNSAVED, current, &store.committed())?;
        let name = format!("snapshot-{current}.bin");
        safe_write(&self.dir.join(&name), &record, None)?;
        for old in snapshots(&self.dir) {
            if old.file_name().is_some_and(|file| file != name.as_str()) {
                let _ = fs::remove_file(old);
            }
        }
        // The records the snapshot covers are skipped on replay even if this does not happen.
        let journal = self.journal.as_mut().ok_or(CoreError::Internal {
            context: "a recovery journal that is not open",
        })?;
        journal.set_len(0).map_err(io)?;
        journal.seek(SeekFrom::Start(0)).map_err(io)?;
        journal.sync_all().map_err(io)?;
        self.since_snapshot = false;
        self.fresh = false;
        self.unsynced = false;
        Ok(())
    }

    /// After a save of revision `saved` to `original`, stamped `stamp`: the files are deleted,
    /// and the next unsaved change starts them again.
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`] when they cannot be deleted.
    pub fn saved(
        &mut self,
        saved: usize,
        original: PathBuf,
        stamp: FileStamp,
    ) -> Result<(), CoreError> {
        self.saved = Some(saved);
        self.original = original;
        self.stamp = stamp;
        self.clear()
    }

    /// Deletes the files ("Don't save", Discard, or the switch turned off).
    ///
    /// # Errors
    ///
    /// [`CoreError::Io`] when they cannot be deleted.
    pub fn clear(&mut self) -> Result<(), CoreError> {
        self.journal = None;
        self.fresh = true;
        self.unsynced = false;
        self.since_snapshot = false;
        remove_dir(&self.dir)
    }

    /// The directory, `base.pdf` and the manifest.
    fn create(&mut self, doc: &Document) -> Result<(), CoreError> {
        make_dir(&self.dir).map_err(io)?;
        let bytes: &[u8] = doc.source().bytes();
        let base = u64::try_from(bytes.len()).is_ok_and(|len| len <= BASE_COPY_LIMIT);
        // shortcut: a plain copy; clonefile or a reflink would save the space on APFS, Btrfs,
        // XFS and ReFS when large documents make it matter.
        if base {
            safe_write(&self.dir.join(BASE), bytes, None)?;
        }
        let manifest = Manifest {
            original: self.original.clone(),
            stamp: self.stamp.clone(),
            encrypted: doc.encryption().is_some(),
            saved_revision: self
                .saved
                .and_then(|saved| u64::try_from(saved).ok())
                .unwrap_or(u64::MAX),
            base,
        };
        safe_write(
            &self.dir.join(MANIFEST),
            manifest.to_json().as_bytes(),
            None,
        )?;
        self.journal = Some(open_journal(&self.dir.join(JOURNAL)).map_err(io)?);
        Ok(())
    }

    /// A record of `objects`, encrypted with the document's key, with the next sequence number.
    fn encode(
        &mut self,
        doc: &Document,
        kind: u8,
        revision: usize,
        objects: &BTreeMap<ObjectId, &Object>,
    ) -> Result<Vec<u8>, CoreError> {
        let distance = self
            .saved
            .map_or(revision, |saved| revision.abs_diff(saved));
        let changes = u32::try_from(distance).unwrap_or(u32::MAX);
        let mut payload = vec![kind];
        payload.extend(self.seq.to_le_bytes());
        payload.extend(u32::try_from(revision).unwrap_or(u32::MAX).to_le_bytes());
        payload.extend(changes.to_le_bytes());
        let encryption = doc.decrypter();
        for (&id, &value) in objects {
            if encryption.is_some_and(|(_, encrypt)| encrypt == Some(id)) {
                continue;
            }
            match encryption {
                Some((decrypter, _)) => {
                    let mut value = value.clone();
                    decrypter.encrypt_object(id, &mut value, &mut system_random, doc.limits())?;
                    indirect(&mut payload, id, &value);
                }
                None => indirect(&mut payload, id, value),
            }
        }
        self.seq = self.seq.saturating_add(1);
        frame(&payload)
    }
}

/// The journal at `path`, created when missing, positioned at its end. Not opened for appending:
/// Windows refuses to cut a file through a handle that only appends.
fn open_journal(path: &Path) -> io::Result<File> {
    let mut journal = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(false)
        .open(path)?;
    journal.seek(SeekFrom::End(0))?;
    Ok(journal)
}

/// `payload` with its length and checksum in front.
pub(crate) fn frame(payload: &[u8]) -> Result<Vec<u8>, CoreError> {
    let len = u32::try_from(payload.len()).map_err(|_| CoreError::OutOfMemory {
        context: "a recovery record",
    })?;
    let mut out = Vec::new();
    out.try_reserve(payload.len().saturating_add(FRAME))
        .map_err(|_| CoreError::OutOfMemory {
            context: "a recovery record",
        })?;
    out.extend(len.to_le_bytes());
    out.extend(Sha256::digest(payload).get(..8).unwrap_or_default());
    out.extend_from_slice(payload);
    Ok(out)
}

/// A record read back.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct Record<'a> {
    kind: u8,
    seq: u64,
    revision: u32,
    changes: u32,
    body: &'a [u8],
}

impl<'a> Record<'a> {
    /// The objects, as `n g obj … endobj`.
    #[cfg(feature = "fuzzing")]
    pub(crate) fn body(&self) -> &'a [u8] {
        self.body
    }
}

/// The whole records at the start of `data`, up to the first one that is torn, damaged or of an
/// unknown kind.
pub(crate) fn records(data: &[u8]) -> Vec<Record<'_>> {
    let mut out = Vec::new();
    let mut rest = data;
    while let Some((record, after)) = next_record(rest) {
        out.push(record);
        rest = after;
    }
    out
}

/// The length of the whole records at the start of `data`.
fn whole_records(data: &[u8]) -> u64 {
    let mut rest = data;
    while let Some((_, after)) = next_record(rest) {
        rest = after;
    }
    u64::try_from(data.len().saturating_sub(rest.len())).unwrap_or(0)
}

fn next_record(data: &[u8]) -> Option<(Record<'_>, &[u8])> {
    let (frame, rest) = data.split_at_checked(FRAME)?;
    let (len, sum) = frame.split_at_checked(4)?;
    let len = usize::try_from(u32::from_le_bytes(len.try_into().ok()?)).ok()?;
    let (payload, rest) = rest.split_at_checked(len)?;
    if Sha256::digest(payload).get(..8) != Some(sum) {
        return None;
    }
    let (header, body) = payload.split_at_checked(HEADER)?;
    let kind = *header.first()?;
    if kind != ONE_REVISION && kind != UNSAVED {
        return None;
    }
    let seq = u64::from_le_bytes(header.get(1..9)?.try_into().ok()?);
    let revision = u32::from_le_bytes(header.get(9..13)?.try_into().ok()?);
    let changes = u32::from_le_bytes(header.get(13..17)?.try_into().ok()?);
    Some((
        Record {
            kind,
            seq,
            revision,
            changes,
            body,
        },
        rest,
    ))
}

/// The objects of a record's body, decrypted with `doc`'s key.
fn read_objects(body: &[u8], doc: &Document) -> Result<BTreeMap<ObjectId, Object>, CoreError> {
    let mut objects = BTreeMap::new();
    let decrypter = doc.decrypter();
    for (id, mut object) in parse_objects(body, doc.limits())? {
        if let Some((decrypter, _)) = decrypter {
            decrypter.decrypt_object(id, &mut object, doc.limits())?;
        }
        objects.insert(id, object);
    }
    Ok(objects)
}

/// The indirect objects of a record's body, in order.
pub(crate) fn parse_objects(
    body: &[u8],
    limits: &Limits,
) -> Result<Vec<(ObjectId, Object)>, CoreError> {
    let mut out = Vec::new();
    let mut parser = Parser::new(body, 0, limits);
    loop {
        let at = parser.pos();
        if body
            .get(at..)
            .is_none_or(|rest| rest.iter().all(|&b| is_whitespace(b)))
        {
            return Ok(out);
        }
        let indirect = parser.indirect(&|_| None)?;
        if !indirect.complete || indirect.end <= at {
            return Err(CoreError::Syntax {
                offset: u64::try_from(at).unwrap_or(u64::MAX),
                problem: "a recovery record's object without its end",
            });
        }
        let object = match (indirect.object, indirect.data) {
            (Object::Dictionary(dict), Some(data)) => Object::Stream(Stream::new(
                dict,
                body.get(data).unwrap_or_default().to_vec(),
            )),
            (object, _) => object,
        };
        out.push((indirect.id, object));
        parser.seek(indirect.end);
    }
}

/// The newest record of the document directory `dir`: the journal's last after the snapshot,
/// or the snapshot's.
fn latest(dir: &Path) -> Option<Record<'static>> {
    let mut newest: Option<Record<'static>> = None;
    let mut keep = |data: &[u8]| {
        for record in records(data) {
            if newest.is_none_or(|newest| record.seq >= newest.seq) {
                newest = Some(Record {
                    body: &[],
                    ..record
                });
            }
        }
    };
    for snapshot in snapshots(dir) {
        if let Ok(data) = fs::read(snapshot) {
            keep(&data);
        }
    }
    if let Ok(data) = fs::read(dir.join(JOURNAL)) {
        keep(&data);
    }
    newest
}

/// The snapshot files of the document directory `dir`.
fn snapshots(dir: &Path) -> Vec<PathBuf> {
    let Ok(entries) = fs::read_dir(dir) else {
        return Vec::new();
    };
    entries
        .flatten()
        .filter(|entry| {
            let name = entry.file_name();
            let name = name.to_string_lossy();
            name.strip_prefix("snapshot-")
                .and_then(|rest| rest.strip_suffix(".bin"))
                .is_some_and(|rev| !rev.is_empty() && rev.bytes().all(|b| b.is_ascii_digit()))
        })
        .map(|entry| entry.path())
        .collect()
}

/// A new random name for a session or a document: 32 hex digits.
fn random_name() -> Result<String, CoreError> {
    let mut bytes = [0u8; 16];
    system_random(&mut bytes)?;
    Ok(hex(&bytes))
}

/// Whether `name` is one [`random_name`] makes, so it names nothing outside the root.
fn valid_name(name: &str) -> bool {
    (1..=64).contains(&name.len()) && name.bytes().all(|b| b.is_ascii_hexdigit())
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

/// Creates `dir` and its missing parents, owner-only on Unix.
fn make_dir(dir: &Path) -> io::Result<()> {
    let mut builder = fs::DirBuilder::new();
    builder.recursive(true);
    #[cfg(unix)]
    std::os::unix::fs::DirBuilderExt::mode(&mut builder, 0o700);
    builder.create(dir)
}

/// Deletes `dir` and everything in it; one that is gone already is fine.
fn remove_dir(dir: &Path) -> Result<(), CoreError> {
    match fs::remove_dir_all(dir) {
        Err(err) if err.kind() != ErrorKind::NotFound => Err(io(err)),
        _ => Ok(()),
    }
}

fn io(err: io::Error) -> CoreError {
    io_kind(err.kind())
}

fn io_kind(kind: ErrorKind) -> CoreError {
    CoreError::Io { kind }
}

/// Writes `text` as a JSON string.
fn json_string(out: &mut String, text: &str) {
    out.push('"');
    for c in text.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            c if u32::from(c) < 0x20 => out.push_str(&format!("\\u{:04x}", u32::from(c))),
            c => out.push(c),
        }
    }
    out.push('"');
}

/// A value of the manifest's flat JSON object.
#[derive(Debug, Clone, PartialEq, Eq)]
enum Json {
    Text(String),
    Number(u64),
    Flag(bool),
}

/// The fields of a flat JSON object of strings, unsigned integers and booleans; `None` for
/// anything else.
fn flat_json(text: &str) -> Option<BTreeMap<String, Json>> {
    let mut chars = text.trim().chars().peekable();
    let mut fields = BTreeMap::new();
    let skip = |chars: &mut std::iter::Peekable<std::str::Chars<'_>>| {
        while chars.next_if(|c| c.is_whitespace()).is_some() {}
    };
    if chars.next()? != '{' {
        return None;
    }
    skip(&mut chars);
    if chars.next_if_eq(&'}').is_some() {
        return chars.next().is_none().then_some(fields);
    }
    loop {
        skip(&mut chars);
        let key = json_text(&mut chars)?;
        skip(&mut chars);
        if chars.next()? != ':' {
            return None;
        }
        skip(&mut chars);
        let value = match chars.peek()? {
            '"' => Json::Text(json_text(&mut chars)?),
            't' | 'f' => {
                let word: String =
                    std::iter::from_fn(|| chars.next_if(char::is_ascii_lowercase)).collect();
                Json::Flag(match word.as_str() {
                    "true" => true,
                    "false" => false,
                    _ => return None,
                })
            }
            _ => {
                let digits: String =
                    std::iter::from_fn(|| chars.next_if(char::is_ascii_digit)).collect();
                Json::Number(digits.parse().ok()?)
            }
        };
        fields.insert(key, value);
        skip(&mut chars);
        match chars.next()? {
            ',' => {}
            '}' => return chars.next().is_none().then_some(fields),
            _ => return None,
        }
    }
}

/// A JSON string at `chars`, quotes included.
fn json_text(chars: &mut std::iter::Peekable<std::str::Chars<'_>>) -> Option<String> {
    if chars.next()? != '"' {
        return None;
    }
    let mut out = String::new();
    loop {
        match chars.next()? {
            '"' => return Some(out),
            '\\' => match chars.next()? {
                '"' => out.push('"'),
                '\\' => out.push('\\'),
                '/' => out.push('/'),
                'n' => out.push('\n'),
                'r' => out.push('\r'),
                't' => out.push('\t'),
                'b' => out.push('\u{8}'),
                'f' => out.push('\u{c}'),
                'u' => {
                    let unit = |chars: &mut std::iter::Peekable<std::str::Chars<'_>>| {
                        let digits: String = chars.take(4).collect();
                        (digits.len() == 4)
                            .then(|| u16::from_str_radix(&digits, 16).ok())
                            .flatten()
                    };
                    let first = unit(chars)?;
                    let mut units = vec![first];
                    if (0xD800..0xDC00).contains(&first) {
                        if chars.next()? != '\\' || chars.next()? != 'u' {
                            return None;
                        }
                        units.push(unit(chars)?);
                    }
                    out.push_str(&String::from_utf16(&units).ok()?);
                }
                _ => return None,
            },
            c => out.push(c),
        }
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;
    use crate::{OpenOptions as Open, Password, Source, open};

    fn temp(name: &str) -> PathBuf {
        let dir =
            std::env::temp_dir().join(format!("ferman-recovery-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        dir
    }

    fn corpus(name: &str, password: Option<&str>) -> Document {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(format!("{name}.pdf"));
        let source = Source::read(&path).unwrap();
        open(
            &source,
            &Open {
                password: password.map(|password| Password::new(password.to_owned())),
                ..Open::default()
            },
        )
        .unwrap()
    }

    /// `store` with a commit that puts `objects`.
    fn commit(store: &mut RevisionStore, objects: Vec<(ObjectId, Object)>) {
        store.begin().unwrap();
        for (id, object) in objects {
            store.put(id, object).unwrap();
        }
        store.commit().unwrap();
    }

    fn page_stream(text: &str) -> Object {
        Object::Stream(Stream::new(
            lopdf::Dictionary::new(),
            format!("BT /F1 12 Tf ({text}) Tj ET").into_bytes(),
        ))
    }

    fn stamp() -> FileStamp {
        FileStamp {
            size: 7,
            modified: UNIX_EPOCH.checked_add(Duration::new(1_700_000_000, 5)),
            sha256: [0xAB; 32],
        }
    }

    #[test]
    fn the_manifest_reads_back_with_any_path() {
        let manifest = Manifest {
            original: PathBuf::from("/tmp/a \"quoted\" \\ path\u{1}/Kira sözleşmesi 𝄞.pdf"),
            stamp: stamp(),
            encrypted: true,
            saved_revision: 3,
            base: false,
        };
        assert_eq!(
            Manifest::parse(manifest.to_json().as_bytes()),
            Some(manifest.clone())
        );
        let without_time = Manifest {
            stamp: FileStamp {
                modified: None,
                ..stamp()
            },
            ..manifest
        };
        assert_eq!(
            Manifest::parse(without_time.to_json().as_bytes()),
            Some(without_time)
        );
        for bad in [&b""[..], b"{", b"[]", b"{\"size\": -1}", b"{} x", b"\xff"] {
            assert_eq!(Manifest::parse(bad), None);
        }
    }

    #[test]
    fn a_torn_or_damaged_record_ends_the_journal() {
        let limits = Limits::default();
        let mut body = Vec::new();
        indirect(&mut body, (5, 0), &page_stream("one"));
        indirect(&mut body, (6, 0), &Object::Integer(7));
        let mut payload = vec![ONE_REVISION];
        payload.extend(4u64.to_le_bytes());
        payload.extend(2u32.to_le_bytes());
        payload.extend(2u32.to_le_bytes());
        payload.extend(&body);
        let one = frame(&payload).unwrap();
        let mut data = [one.clone(), one.clone()].concat();
        let read = records(&data);
        assert_eq!(read.len(), 2);
        assert_eq!((read[0].seq, read[0].revision, read[0].changes), (4, 2, 2));
        let objects = parse_objects(read[0].body, &limits).unwrap();
        assert_eq!(objects.len(), 2);
        assert_eq!(objects[1], ((6, 0), Object::Integer(7)));
        let Object::Stream(stream) = &objects[0].1 else {
            panic!("a stream")
        };
        assert_eq!(stream.content, b"BT /F1 12 Tf (one) Tj ET");
        // Torn: every shorter tail is ignored.
        for cut in one.len()..data.len() {
            assert_eq!(records(&data[..cut]).len(), 1);
        }
        // Damaged: one flipped bit ends it there.
        let last = data.len() - 3;
        data[last] ^= 1;
        assert_eq!(records(&data).len(), 1);
        data[20] ^= 1;
        assert!(records(&data).is_empty());
        // Lengths past the data never read out of bounds.
        assert!(records(&[0xFF; 40]).is_empty());
    }

    /// Edits `doc` twice, undoes once and redoes, with a snapshot between, and restores it.
    #[test]
    fn the_journal_and_snapshot_restore_the_unsaved_revision() {
        let root = temp("restore");
        let doc = corpus("kira-tr", None);
        let session = RecoverySession::start(&root).unwrap();
        let mut recovery = DocumentRecovery::new(
            &session,
            PathBuf::from("/nowhere/kira.pdf"),
            stamp(),
            Some(0),
        )
        .unwrap();
        let mut store = RevisionStore::new(&doc);
        let now = Instant::now();
        let new = store.next_number();
        commit(&mut store, vec![((new, 0), page_stream("first"))]);
        recovery.record(&doc, &store, Change::Commit, now).unwrap();
        assert!(recovery.dir().join(BASE).is_file());
        assert_eq!(
            fs::read(recovery.dir().join(BASE)).unwrap(),
            &doc.source().bytes()[..]
        );
        recovery.snapshot(&doc, &store).unwrap();
        commit(&mut store, vec![((new + 1, 0), Object::Integer(42))]);
        recovery
            .record(
                &doc,
                &store,
                Change::Commit,
                now + Duration::from_millis(10),
            )
            .unwrap();
        store.undo().unwrap();
        recovery.record(&doc, &store, Change::Move, now).unwrap();
        store.redo().unwrap();
        recovery.record(&doc, &store, Change::Move, now).unwrap();
        commit(&mut store, vec![((new, 0), page_stream("second"))]);
        recovery.record(&doc, &store, Change::Commit, now).unwrap();

        let listed = list(&root, Some(&session.name()));
        assert!(listed.is_empty(), "a live session is not listed");
        let restored = restore(recovery.dir(), &doc).unwrap();
        assert_eq!(restored.changes, 3);
        assert_eq!(
            store_bytes(&restored.store, &doc),
            store_bytes(&store, &doc)
        );
        let manifest = Manifest::read(recovery.dir()).unwrap();
        assert_eq!((manifest.base, manifest.encrypted), (true, false));

        // A save of the revision deletes the files; undoing past it starts them again.
        let dir = recovery.dir().to_path_buf();
        recovery
            .saved(store.current(), PathBuf::from("/nowhere/kira.pdf"), stamp())
            .unwrap();
        assert!(!dir.exists());
        store.undo().unwrap();
        recovery.record(&doc, &store, Change::Move, now).unwrap();
        assert_eq!(restore(&dir, &doc).unwrap().changes, 1);
        recovery.clear().unwrap();
        assert!(!dir.exists());
        drop(session);
        assert!(
            fs::read_dir(&root).unwrap().next().is_none(),
            "an empty session goes"
        );
        fs::remove_dir_all(&root).unwrap();
    }

    /// The incremental update with fixed random bytes, so two stores' updates compare.
    fn store_bytes(store: &RevisionStore, doc: &Document) -> Vec<u8> {
        store
            .write_update(doc, &mut |out: &mut [u8]| {
                out.fill(7);
                Ok(())
            })
            .unwrap()
    }

    #[test]
    fn a_crashed_session_is_listed_and_discarded() {
        let root = temp("list");
        let doc = corpus("kira-tr", None);
        let session = RecoverySession::start(&root).unwrap();
        let name = session.name();
        let mut recovery = DocumentRecovery::new(
            &session,
            PathBuf::from("/nowhere/gone.pdf"),
            FileStamp {
                modified: None,
                ..stamp()
            },
            Some(0),
        )
        .unwrap();
        let mut store = RevisionStore::new(&doc);
        let new = store.next_number();
        commit(&mut store, vec![((new, 0), Object::Integer(1))]);
        recovery
            .record(&doc, &store, Change::Commit, Instant::now())
            .unwrap();
        let document = recovery
            .dir()
            .file_name()
            .unwrap()
            .to_string_lossy()
            .into_owned();
        assert_eq!(
            discard(&root, &name, None).unwrap_err().to_string(),
            io_kind(ErrorKind::WouldBlock).to_string(),
            "a live session is never discarded"
        );
        // As a crash leaves it: the lock let go, the files kept.
        drop(recovery);
        drop(session);
        let listed = list(&root, None);
        assert_eq!(listed.len(), 1);
        assert_eq!(
            (listed[0].session.as_str(), listed[0].document.as_str()),
            (name.as_str(), document.as_str())
        );
        assert_eq!(listed[0].changes, 1);
        assert!(
            !listed[0].original_changed,
            "a missing original has not changed"
        );
        assert!(discard(&root, "../x", None).is_err());
        assert!(document_dir(&root, &name, "..").is_none());
        discard(&root, &name, Some(&document)).unwrap();
        assert!(list(&root, None).is_empty());
        assert!(
            !root.join(&name).exists(),
            "the session went with its last document"
        );
        fs::remove_dir_all(&root).unwrap();
    }

    /// A recovery of kira-tr at a path that does not exist, in a new session under `root`.
    fn started(root: &Path, saved: Option<usize>) -> (RecoverySession, DocumentRecovery) {
        let session = RecoverySession::start(root).unwrap();
        let recovery =
            DocumentRecovery::new(&session, PathBuf::from("/nowhere/kira.pdf"), stamp(), saved)
                .unwrap();
        (session, recovery)
    }

    /// Saved at two, undone to one, a new edit is revision two again: not the one in the file.
    #[test]
    fn a_commit_at_the_saved_number_is_unsaved() {
        let root = temp("renumbered");
        let doc = corpus("kira-tr", None);
        let (session, mut recovery) = started(&root, Some(0));
        let mut store = RevisionStore::new(&doc);
        let new = store.next_number();
        let now = Instant::now();
        commit(&mut store, vec![((new, 0), Object::Integer(1))]);
        commit(&mut store, vec![((new, 0), Object::Integer(2))]);
        recovery
            .saved(store.current(), PathBuf::from("/nowhere/kira.pdf"), stamp())
            .unwrap();
        store.undo().unwrap();
        recovery.record(&doc, &store, Change::Move, now).unwrap();
        commit(&mut store, vec![((new, 0), Object::Integer(3))]);
        assert_eq!(store.current(), 2);
        recovery.record(&doc, &store, Change::Commit, now).unwrap();
        assert!(recovery.written(), "the new revision has its files");
        let restored = restore(recovery.dir(), &doc).unwrap();
        assert_eq!(
            restored.store.lookup((new, 0)),
            Some(&Object::Integer(3)),
            "the new revision comes back"
        );
        // Nothing reaches the saved revision any more: an undo and a redo keep the files.
        store.undo().unwrap();
        recovery.record(&doc, &store, Change::Move, now).unwrap();
        store.redo().unwrap();
        recovery.record(&doc, &store, Change::Move, now).unwrap();
        assert!(recovery.dir().join(JOURNAL).is_file());
        assert_eq!(restore(recovery.dir(), &doc).unwrap().changes, 2);
        recovery.clear().unwrap();
        drop(session);
        fs::remove_dir_all(&root).unwrap();
    }

    /// Edit, save, undo: the file holds the edit and the document does not. It comes back as a
    /// change, so it does not read as saved.
    #[test]
    fn an_undo_past_a_save_comes_back_unsaved() {
        let root = temp("past-save");
        let doc = corpus("kira-tr", None);
        let (session, mut recovery) = started(&root, Some(0));
        let mut store = RevisionStore::new(&doc);
        let new = store.next_number();
        let now = Instant::now();
        commit(&mut store, vec![((new, 0), Object::Integer(1))]);
        recovery
            .saved(1, PathBuf::from("/nowhere/kira.pdf"), stamp())
            .unwrap();
        store.undo().unwrap();
        recovery.record(&doc, &store, Change::Move, now).unwrap();
        let restored = restore(recovery.dir(), &doc).unwrap();
        assert_eq!((restored.changes, restored.store.current()), (1, 1));
        assert!(restored.store.committed().is_empty());
        assert_eq!(
            restored.store.incremental_update(&doc).unwrap(),
            &doc.source().bytes()[..]
        );
        recovery.clear().unwrap();
        drop(session);
        fs::remove_dir_all(&root).unwrap();
    }

    /// A crash tears a record; the restored document's next records must still be read.
    #[test]
    fn records_after_a_restore_follow_a_torn_tail() {
        let root = temp("torn");
        let doc = corpus("kira-tr", None);
        let (session, mut recovery) = started(&root, Some(0));
        let mut store = RevisionStore::new(&doc);
        let new = store.next_number();
        let now = Instant::now();
        commit(&mut store, vec![((new, 0), Object::Integer(1))]);
        recovery.record(&doc, &store, Change::Commit, now).unwrap();
        commit(&mut store, vec![((new + 1, 0), Object::Integer(2))]);
        recovery.record(&doc, &store, Change::Commit, now).unwrap();
        let dir = recovery.dir().to_path_buf();
        drop(recovery);
        let journal = dir.join(JOURNAL);
        let whole = fs::read(&journal).unwrap();
        fs::write(&journal, &whole[..whole.len() - 3]).unwrap();

        let restored = restore(&dir, &doc).unwrap();
        assert_eq!(restored.store.lookup((new + 1, 0)), None);
        let mut store = restored.store;
        let mut recovery = DocumentRecovery::adopt(
            dir.clone(),
            restored.resume,
            PathBuf::from("/nowhere/kira.pdf"),
            stamp(),
        );
        commit(&mut store, vec![((new + 2, 0), Object::Integer(3))]);
        recovery.record(&doc, &store, Change::Commit, now).unwrap();

        let again = restore(&dir, &doc).unwrap();
        assert_eq!(again.store.lookup((new, 0)), Some(&Object::Integer(1)));
        assert_eq!(again.store.lookup((new + 2, 0)), Some(&Object::Integer(3)));
        assert_eq!(
            fs::metadata(&journal).unwrap().len(),
            again.resume.journal_len,
            "no torn record is left in the middle"
        );
        recovery.clear().unwrap();
        drop(session);
        fs::remove_dir_all(&root).unwrap();
    }

    #[test]
    fn the_clock_decides_the_sync_and_the_snapshot() {
        let root = temp("clock");
        let doc = corpus("kira-tr", None);
        let (session, mut recovery) = started(&root, Some(0));
        let mut store = RevisionStore::new(&doc);
        let new = store.next_number();
        let start = Instant::now();
        commit(&mut store, vec![((new, 0), Object::Integer(1))]);
        recovery
            .record(&doc, &store, Change::Commit, start)
            .unwrap();
        assert!(!recovery.unsynced, "the first record is synced at once");
        commit(&mut store, vec![((new, 0), Object::Integer(2))]);
        recovery
            .record(
                &doc,
                &store,
                Change::Commit,
                start + Duration::from_millis(100),
            )
            .unwrap();
        assert!(recovery.unsynced, "at most once per second");
        recovery
            .tick(&doc, &store, start + Duration::from_millis(999))
            .unwrap();
        assert!(recovery.unsynced);
        recovery.tick(&doc, &store, start + SYNC_INTERVAL).unwrap();
        assert!(!recovery.unsynced);
        assert!(snapshots(recovery.dir()).is_empty());
        recovery
            .tick(&doc, &store, start + SNAPSHOT_INTERVAL)
            .unwrap();
        assert_eq!(snapshots(recovery.dir()).len(), 1);
        assert_eq!(fs::metadata(recovery.dir().join(JOURNAL)).unwrap().len(), 0);
        // Nothing new: no snapshot follows.
        let snapshot = snapshots(recovery.dir()).remove(0);
        fs::remove_file(&snapshot).unwrap();
        recovery
            .tick(&doc, &store, start + 3 * SNAPSHOT_INTERVAL)
            .unwrap();
        assert!(snapshots(recovery.dir()).is_empty());
        recovery.clear().unwrap();
        drop(session);
        fs::remove_dir_all(&root).unwrap();
    }

    /// One revision's objects without the snapshot before them are not a document's state.
    #[test]
    fn a_journal_without_its_snapshot_restores_nothing() {
        let root = temp("no-snapshot");
        let doc = corpus("kira-tr", None);
        let (session, mut recovery) = started(&root, Some(0));
        let mut store = RevisionStore::new(&doc);
        let new = store.next_number();
        let now = Instant::now();
        commit(&mut store, vec![((new, 0), Object::Integer(1))]);
        recovery.record(&doc, &store, Change::Commit, now).unwrap();
        recovery.snapshot(&doc, &store).unwrap();
        commit(&mut store, vec![((new + 1, 0), Object::Integer(2))]);
        recovery.record(&doc, &store, Change::Commit, now).unwrap();
        fs::remove_file(snapshots(recovery.dir()).remove(0)).unwrap();
        let restored = restore(recovery.dir(), &doc).unwrap();
        assert!(restored.store.committed().is_empty());
        recovery.clear().unwrap();
        drop(session);
        fs::remove_dir_all(&root).unwrap();
    }

    #[test]
    fn listing_leaves_a_starting_session_and_clears_what_holds_nothing() {
        let root = temp("starting");
        fs::create_dir_all(&root).unwrap();
        // Another instance between creating its lock and locking it.
        let starting = root.join("abc1");
        fs::create_dir(&starting).unwrap();
        fs::write(starting.join(LOCK), b"").unwrap();
        // Crashes: before the manifest, and before the first record.
        let crashed = root.join("abc2");
        fs::create_dir_all(crashed.join("d1")).unwrap();
        fs::write(crashed.join(LOCK), b"1\n2\n").unwrap();
        fs::write(crashed.join("d1").join(BASE), b"%PDF").unwrap();
        let manifest = Manifest {
            original: PathBuf::from("/nowhere/kira.pdf"),
            stamp: stamp(),
            encrypted: false,
            saved_revision: 0,
            base: true,
        };
        fs::create_dir_all(crashed.join("d2")).unwrap();
        fs::write(crashed.join("d2").join(MANIFEST), manifest.to_json()).unwrap();
        fs::write(crashed.join("d2").join(JOURNAL), [0xFF; 5]).unwrap();

        assert!(list(&root, None).is_empty());
        assert!(starting.join(LOCK).exists(), "a starting session stays");
        assert!(!crashed.exists(), "nothing to restore: it goes");
        assert!(discard(&root, "abc1", None).is_err());
        fs::remove_dir_all(&root).unwrap();
    }

    #[test]
    fn a_live_session_names_no_document_to_restore() {
        let root = temp("live");
        let session = RecoverySession::start(&root).unwrap();
        assert_eq!(document_dir(&root, &session.name(), "abc"), None);
        let name = session.name();
        drop(session);
        assert_eq!(
            document_dir(&root, &name, "abc"),
            Some(root.join(&name).join("abc"))
        );
        fs::remove_dir_all(&root).unwrap();
    }

    #[cfg(unix)]
    #[test]
    fn the_directories_are_owner_only() {
        use std::os::unix::fs::PermissionsExt as _;
        let root = temp("mode");
        let session = RecoverySession::start(&root).unwrap();
        for dir in [&root, &session.dir().to_path_buf()] {
            assert_eq!(
                fs::metadata(dir).unwrap().permissions().mode() & 0o777,
                0o700
            );
        }
        drop(session);
        fs::remove_dir_all(&root).unwrap();
    }

    /// Every byte under `root`, and every Flate stream of the records decoded, without the key.
    fn everything_written(root: &Path) -> Vec<Vec<u8>> {
        let mut out = Vec::new();
        let mut dirs = vec![root.to_path_buf()];
        while let Some(dir) = dirs.pop() {
            for entry in fs::read_dir(dir).unwrap().flatten() {
                if entry.path().is_dir() {
                    dirs.push(entry.path());
                    continue;
                }
                // The session holds it locked, and Windows refuses to read it (os error 33).
                if entry.file_name() == LOCK {
                    continue;
                }
                let data = fs::read(entry.path()).unwrap();
                for record in records(&data) {
                    for (_, object) in parse_objects(record.body, &Limits::default()).unwrap() {
                        if let Object::Stream(stream) = object {
                            let mut plain = Vec::new();
                            let mut inflate = flate2::read::ZlibDecoder::new(&stream.content[..]);
                            if std::io::Read::read_to_end(&mut inflate, &mut plain).is_ok() {
                                out.push(plain);
                            }
                        }
                    }
                }
                out.push(data);
            }
        }
        out
    }

    fn contains(haystack: &[u8], needle: &[u8]) -> bool {
        haystack
            .windows(needle.len())
            .any(|window| window == needle)
    }

    /// The known-plaintext scan (M3 plan W4): an edit of an encrypted document leaves its new
    /// word and the page's text nowhere under the recovery directory, while the same edit of a
    /// document without encryption does (so the scan finds what is there).
    #[test]
    fn an_encrypted_document_never_reaches_the_disk_in_plaintext() {
        const WORD: &str = "Zebrafink-Quokka-7319";
        let utf16: Vec<u8> = WORD.encode_utf16().flat_map(u16::to_be_bytes).collect();
        for (name, password, encrypted) in [
            ("payslip-aes256", Some("Eylül2026maaşı"), true),
            ("payslip-aes128", Some("bordro2026"), true),
            ("kira-tr", None, false),
        ] {
            let root = temp(&format!("plain-{name}"));
            let doc = corpus(name, password);
            // The first page's content, decrypted, which the page shows.
            let page = doc.model().get_pages().values().next().copied().unwrap();
            let contents = doc.model().get_page_content(page);
            let session = RecoverySession::start(&root).unwrap();
            let mut recovery =
                DocumentRecovery::new(&session, PathBuf::from("/nowhere/p.pdf"), stamp(), Some(0))
                    .unwrap();
            let mut store = RevisionStore::new(&doc);
            let text = Object::String(WORD.as_bytes().to_vec(), lopdf::StringFormat::Literal);
            let wide = Object::String(utf16.clone(), lopdf::StringFormat::Literal);
            let new = store.next_number();
            commit(
                &mut store,
                vec![
                    ((new, 0), page_stream(WORD)),
                    ((new + 1, 0), Object::Array(vec![text, wide])),
                ],
            );
            let now = Instant::now();
            recovery.record(&doc, &store, Change::Commit, now).unwrap();
            recovery.snapshot(&doc, &store).unwrap();
            commit(&mut store, vec![((new + 2, 0), page_stream(WORD))]);
            recovery
                .record(&doc, &store, Change::Commit, now + SNAPSHOT_INTERVAL)
                .unwrap();
            let written = everything_written(&root);
            let found = written
                .iter()
                .any(|data| contains(data, WORD.as_bytes()) || contains(data, &utf16));
            assert_eq!(found, !encrypted, "{name}");
            if encrypted {
                let page_text = &contents[..contents.len().min(48)];
                assert!(page_text.len() >= 32, "{name}");
                assert!(
                    !written.iter().any(|data| contains(data, page_text)),
                    "{name}"
                );
                // Restoring needs the key: the objects come back decrypted.
                let restored = restore(recovery.dir(), &doc).unwrap();
                let Some(Object::Stream(stream)) = restored.store.lookup((new + 2, 0)) else {
                    panic!("the stream comes back")
                };
                assert!(contains(&stream.content, WORD.as_bytes()));
            }
            recovery.clear().unwrap();
            drop(session);
            fs::remove_dir_all(&root).unwrap();
        }
    }
}
