//! Background jobs (docs/ARCHITECTURE.md §3.7, ADR 0009, a11-6b): long work on a plain thread of
//! its own, which the user can pause and cancel between its steps and which outlives its tab or
//! dialog. Search stays outside (`search`).
//!
//! A job reads an immutable copy of the base and the store, taken when it starts
//! ([`JobSnapshot`]), so the user keeps editing. A job never changes a document: it writes new
//! files or hands back a [`JobChange`], which [`Engine::apply_job_change`] commits on the actor
//! and refuses if the revision moved (M4 plan, decision 1).
//!
//! One rule for temp files: everything a job writes goes into a folder of its own in the system's
//! temp directory, which goes when the job ends, however it ends. Files for the user wait there
//! ([`JobRun::output_pdf`]) and reach their place through the safe write only after the job's
//! last step, so a job that is cancelled or fails leaves no partial output. A folder holds a
//! lock for as long as its job runs; the next engine start deletes a folder nobody holds, which
//! is what a crash leaves.

use std::collections::HashMap;
use std::fs::{self, File, OpenOptions};
use std::io;
use std::panic::AssertUnwindSafe;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Condvar, Mutex, MutexGuard, PoisonError};
use std::thread;
use std::time::{Duration, Instant};

use ferman_core::revision::RevisionStore;
use ferman_core::{Document, DocumentOp};
use ferman_render::DocumentId;

use super::document::Model;
use super::edit::RevisionInfo;
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};

/// The stack of a job's thread: the interpreter recurses into nested objects, bounded by the
/// limits, as the open thread does.
const JOB_STACK: usize = 64 * 1024 * 1024;

/// At most ten progress events a second.
const PROGRESS_GAP: Duration = Duration::from_millis(100);

/// How long a finished job's result stays available (a11-6b).
const RESULT_KEPT: Duration = Duration::from_secs(60 * 60);

/// The start of a job folder's name in the temp directory.
const FOLDER_PREFIX: &str = "ferman-job-";

/// The file in a job's folder whose lock says the job runs.
const LOCK_FILE: &str = ".lock";

/// The details of the error a job's change gets when the document moved on.
pub const JOB_STALE: &str = "the document changed since the job read it";

/// A job. Never reused within a process.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct JobId(u64);

impl JobId {
    /// The number behind the id.
    #[must_use]
    pub fn get(self) -> u64 {
        self.0
    }

    /// The id behind a number from [`get`](Self::get), as a handle that crossed the bridge.
    #[must_use]
    pub fn from_raw(raw: u64) -> Self {
        Self(raw)
    }
}

/// A file a job finished.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JobOutput {
    /// Where it belongs.
    pub path: PathBuf,
    /// With a staging directory (ADR 0008), the verified file waiting for the platform layer's
    /// swap into `path`, which is not touched yet.
    pub staged: Option<PathBuf>,
}

/// How a job ended.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum JobResult {
    /// It finished.
    Done {
        /// The files it wrote.
        outputs: Vec<JobOutput>,
        /// How many steps of the document's history it read, when it read a document: edits
        /// since are not in its result.
        revision: Option<u32>,
        /// Whether a change waits for [`Engine::apply_job_change`].
        change: bool,
    },
    /// It failed; nothing of it is left.
    Failed(ApiError),
    /// It was cancelled; nothing of it is left.
    Cancelled,
}

/// What a job reports. The first event comes before the job's work, with no progress; the last
/// has its `result`.
#[derive(Debug, Clone, PartialEq)]
pub struct JobEvent {
    /// The job, whose handle pauses and cancels it.
    pub job: JobId,
    /// Whether it is parked between two steps.
    pub paused: bool,
    /// How far it is, 0 to 1; `None` when unknown.
    pub progress: Option<f32>,
    /// The ARB key of where it is, such as `jobPageOf`.
    pub message: Option<MessageKey>,
    /// The key's parameters.
    pub params: Vec<(String, String)>,
    /// How it ended, on the last event.
    pub result: Option<JobResult>,
}

/// Receives a job's events on its thread. A sink nobody listens to any more does not stop the
/// job, which keeps running with its tab closed.
pub trait JobSink: Send {
    /// Delivers one event.
    fn deliver(&mut self, event: JobEvent);
}

/// The immutable copy a job reads: the base and the store as published when it was taken.
#[derive(Clone)]
pub struct JobSnapshot {
    document: DocumentId,
    model: Arc<Model>,
    store: Arc<RevisionStore>,
    generation: u64,
}

impl JobSnapshot {
    /// The document as opened.
    #[must_use]
    pub fn base(&self) -> &Document {
        &self.model.document
    }

    /// The revisions on top of it.
    #[must_use]
    pub fn store(&self) -> &RevisionStore {
        &self.store
    }
}

/// Why a job stopped before its end.
#[derive(Debug)]
pub enum JobStop {
    /// The user cancelled it, seen at [`JobRun::checkpoint`].
    Cancelled,
    /// It failed.
    Failed(ApiError),
}

impl From<ApiError> for JobStop {
    fn from(err: ApiError) -> Self {
        Self::Failed(err)
    }
}

/// What writes a [`JobChange`] into a transaction of the committed revisions, on the actor.
type ChangeWriter = Box<dyn FnOnce(&Document, &mut RevisionStore) -> Result<(), ApiError> + Send>;

/// A change for the open document that a job prepared.
pub struct JobChange {
    /// The operation it is, which the document's permissions and signatures gate.
    pub op: DocumentOp,
    /// The full names of the form fields a [`DocumentOp::Fill`] fills.
    pub fields: Vec<String>,
    /// Its history step's name.
    pub name: String,
    /// The pages it changes, as the revisions read leave them.
    pub pages: Vec<usize>,
    /// What the step says it changed, before and after.
    pub summary: (String, String),
    /// Writes it.
    pub write: ChangeWriter,
}

/// What pause and cancel ask of a job.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Wish {
    Run,
    Pause,
    Cancel,
}

/// The wish a job sees at its next checkpoint.
#[derive(Debug)]
struct Control {
    wish: Mutex<Wish>,
    changed: Condvar,
}

impl Control {
    fn wish(&self) -> MutexGuard<'_, Wish> {
        self.wish.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Asks for `wish`; a cancel stays.
    fn ask(&self, wish: Wish) {
        let mut current = self.wish();
        if *current != Wish::Cancel {
            *current = wish;
        }
        self.changed.notify_all();
    }

    /// Parks while paused; whether the job was cancelled.
    fn wait(&self) -> bool {
        let mut wish = self.wish();
        while *wish == Wish::Pause {
            wish = self
                .changed
                .wait(wish)
                .unwrap_or_else(PoisonError::into_inner);
        }
        *wish == Wish::Cancel
    }
}

/// A job's folder in the temp directory, made when it first writes and deleted when it ends.
#[derive(Debug)]
struct JobFolder {
    job: JobId,
    /// The folder, with its lock held.
    open: Option<(PathBuf, File)>,
    files: u32,
}

impl JobFolder {
    /// A new file's path in the folder.
    fn file(&mut self) -> io::Result<PathBuf> {
        let dir = match &self.open {
            Some((dir, _)) => dir.clone(),
            None => {
                let dir = std::env::temp_dir().join(format!(
                    "{FOLDER_PREFIX}{}-{}",
                    std::process::id(),
                    self.job.0
                ));
                create_private_dir(&dir)?;
                let lock = File::create(dir.join(LOCK_FILE))?;
                lock.try_lock().map_err(io::Error::from)?;
                self.open = Some((dir.clone(), lock));
                dir
            }
        };
        self.files = self.files.saturating_add(1);
        Ok(dir.join(self.files.to_string()))
    }

    fn remove(&mut self) {
        if let Some((dir, lock)) = self.open.take() {
            // Windows keeps an open file from going.
            drop(lock);
            if let Err(err) = fs::remove_dir_all(&dir) {
                tracing::warn!(error = %err, "a job's temp folder could not be deleted");
            }
        }
    }
}

impl Drop for JobFolder {
    fn drop(&mut self) {
        self.remove();
    }
}

/// Makes `dir` for this user alone: the output of an encrypted document is plain text there.
fn create_private_dir(dir: &Path) -> io::Result<()> {
    #[cfg_attr(not(unix), allow(unused_mut))]
    let mut builder = fs::DirBuilder::new();
    #[cfg(unix)]
    std::os::unix::fs::DirBuilderExt::mode(&mut builder, 0o700);
    builder.create(dir)
}

/// Deletes the job folders in `temp` whose job is gone: a crashed process's lock went with it.
fn sweep(temp: &Path) {
    let Ok(entries) = fs::read_dir(temp) else {
        return;
    };
    for entry in entries.flatten() {
        if !entry
            .file_name()
            .to_string_lossy()
            .starts_with(FOLDER_PREFIX)
        {
            continue;
        }
        let dir = entry.path();
        // A folder without its lock file never held anything, and another user's cannot be read.
        let free = OpenOptions::new()
            .write(true)
            .open(dir.join(LOCK_FILE))
            .is_ok_and(|lock| lock.try_lock().is_ok());
        if free && let Err(err) = fs::remove_dir_all(&dir) {
            tracing::warn!(error = %err, "a crashed job's temp folder could not be deleted");
        }
    }
}

/// A file waiting for the job's end.
struct Pending {
    temp: PathBuf,
    target: PathBuf,
    staging: Option<PathBuf>,
}

/// A running job as its work sees it.
pub struct JobRun {
    job: JobId,
    control: Arc<Control>,
    sink: Box<dyn JobSink>,
    folder: JobFolder,
    pending: Vec<Pending>,
    /// The last progress reported, and when it was last sent.
    progress: Option<f32>,
    message: Option<MessageKey>,
    params: Vec<(String, String)>,
    sent: Option<Instant>,
}

impl JobRun {
    /// Parks here while the job is paused. Call it between pages or objects.
    ///
    /// # Errors
    ///
    /// [`JobStop::Cancelled`] once the job is cancelled: return it.
    pub fn checkpoint(&mut self) -> Result<(), JobStop> {
        let wish = *self.control.wish();
        let cancelled = match wish {
            Wish::Run => false,
            Wish::Cancel => true,
            Wish::Pause => {
                self.send(true, None);
                let cancelled = self.control.wait();
                if !cancelled {
                    self.send(false, None);
                }
                cancelled
            }
        };
        if cancelled {
            Err(JobStop::Cancelled)
        } else {
            Ok(())
        }
    }

    /// Reports how far the job is, at most ten times a second; the rest are dropped.
    pub fn progress(
        &mut self,
        progress: Option<f32>,
        message: MessageKey,
        params: Vec<(String, String)>,
    ) {
        self.progress = progress;
        self.message = Some(message);
        self.params = params;
        if self.sent.is_none_or(|sent| sent.elapsed() >= PROGRESS_GAP) {
            self.sent = Some(Instant::now());
            self.send(false, None);
        }
    }

    /// A path in the job's folder for a file of its own, gone when the job ends.
    ///
    /// # Errors
    ///
    /// `DiskFull` or `Io` when the folder cannot be made.
    pub fn temp_file(&mut self) -> Result<PathBuf, ApiError> {
        self.folder.file().map_err(temp_failure)
    }

    /// Keeps `bytes`, a PDF, for the new file `target`: written there through the safe write after
    /// the job's last step (staged in `staging` under the macOS App Sandbox), and never if it stops
    /// first. A file at `target` by then, which is not what the job read, fails the job and stays.
    ///
    /// # Errors
    ///
    /// `DiskFull` or `Io` when the job's folder cannot hold them.
    pub fn output_pdf(
        &mut self,
        target: PathBuf,
        bytes: &[u8],
        staging: Option<PathBuf>,
    ) -> Result<(), ApiError> {
        let temp = self.temp_file()?;
        fs::write(&temp, bytes).map_err(temp_failure)?;
        self.pending.push(Pending {
            temp,
            target,
            staging,
        });
        Ok(())
    }

    fn send(&mut self, paused: bool, result: Option<JobResult>) {
        self.sink.deliver(JobEvent {
            job: self.job,
            paused,
            progress: self.progress,
            message: self.message,
            params: self.params.clone(),
            result,
        });
    }

    /// Puts the waiting files in place. A failure takes back those it created.
    fn publish(&mut self) -> Result<Vec<JobOutput>, ApiError> {
        let mut outputs = Vec::new();
        let mut created = Vec::new();
        for pending in std::mem::take(&mut self.pending) {
            match publish_one(&pending) {
                Ok(output) => {
                    created.push(output.staged.clone().unwrap_or_else(|| output.path.clone()));
                    outputs.push(output);
                }
                Err(err) => {
                    for file in created {
                        let _ = fs::remove_file(file);
                    }
                    return Err(err);
                }
            }
        }
        Ok(outputs)
    }
}

/// One waiting file through the safe write.
fn publish_one(pending: &Pending) -> Result<JobOutput, ApiError> {
    let bytes = fs::read(&pending.temp).map_err(temp_failure)?;
    let staged =
        ferman_core::save::save_new_pdf(&pending.target, pending.staging.as_deref(), &bytes)
            .map_err(|err| ApiError::from(err).of_save())?;
    Ok(JobOutput {
        path: pending.target.clone(),
        staged,
    })
}

/// A failure of a job's folder as the app gets it.
fn temp_failure(err: io::Error) -> ApiError {
    let kind = if err.kind() == io::ErrorKind::StorageFull {
        ErrorKind::DiskFull
    } else {
        ErrorKind::Io
    };
    ApiError::new(kind, MessageKey::INTERNAL).with_details("a job's temp file")
}

/// A change waiting for [`Engine::apply_job_change`], with the document and generation it read.
struct WaitingChange {
    change: JobChange,
    document: DocumentId,
    generation: u64,
}

/// A finished job, kept for [`RESULT_KEPT`].
struct Finished {
    at: Instant,
    result: JobResult,
    change: Option<WaitingChange>,
}

/// A job the manager knows.
struct Entry {
    control: Arc<Control>,
    finished: Option<Finished>,
}

/// The jobs of an engine.
#[derive(Default)]
pub(super) struct JobManager {
    jobs: Mutex<HashMap<JobId, Entry>>,
}

impl std::fmt::Debug for JobManager {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("JobManager").finish_non_exhaustive()
    }
}

impl JobManager {
    /// The manager of an engine that starts now, which cleans up after a crash.
    pub(super) fn start() -> Self {
        sweep(&std::env::temp_dir());
        Self::default()
    }

    fn jobs(&self) -> MutexGuard<'_, HashMap<JobId, Entry>> {
        self.jobs.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Forgets the results older than [`RESULT_KEPT`] at `now`.
    fn purge(&self, now: Instant) {
        self.jobs().retain(|_, entry| {
            entry
                .finished
                .as_ref()
                .is_none_or(|finished| now.saturating_duration_since(finished.at) < RESULT_KEPT)
        });
    }

    fn take_change(&self, job: JobId) -> Option<WaitingChange> {
        self.jobs()
            .get_mut(&job)
            .and_then(|entry| entry.finished.as_mut())
            .and_then(|finished| finished.change.take())
    }

    fn put_change_back(&self, job: JobId, waiting: WaitingChange) {
        if let Some(finished) = self
            .jobs()
            .get_mut(&job)
            .and_then(|entry| entry.finished.as_mut())
        {
            finished.change = Some(waiting);
        }
    }

    fn ask(&self, job: JobId, wish: Wish) {
        if let Some(entry) = self.jobs().get(&job) {
            entry.control.ask(wish);
        }
    }
}

impl Engine {
    /// The copy of `document` a job reads: what the actor last published.
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open.
    pub fn job_snapshot(&self, document: DocumentId) -> Result<JobSnapshot, ApiError> {
        let model = self
            .models()?
            .get(&document)
            .cloned()
            .ok_or_else(|| ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL))?;
        let (store, generation) = {
            let revised = model.revised();
            (Arc::clone(&revised.store), revised.generation)
        };
        Ok(JobSnapshot {
            document,
            model,
            store,
            generation,
        })
    }

    /// Runs `work` as a job on a thread of its own; `sink` receives the first event before this
    /// returns. `read` is the copy `work` holds, when it reads a document: the result reports its
    /// revision, and a change is checked against it.
    ///
    /// # Errors
    ///
    /// `Internal` when the thread does not start.
    pub fn start_job(
        &self,
        read: Option<&JobSnapshot>,
        sink: Box<dyn JobSink>,
        work: impl FnOnce(&mut JobRun) -> Result<Option<JobChange>, JobStop> + Send + 'static,
    ) -> Result<JobId, ApiError> {
        static NEXT: AtomicU64 = AtomicU64::new(1);
        let job = JobId(NEXT.fetch_add(1, Ordering::Relaxed));
        let control = Arc::new(Control {
            wish: Mutex::new(Wish::Run),
            changed: Condvar::new(),
        });
        self.jobs.purge(Instant::now());
        self.jobs.jobs().insert(
            job,
            Entry {
                control: Arc::clone(&control),
                finished: None,
            },
        );
        let mut run = JobRun {
            job,
            control,
            sink,
            folder: JobFolder {
                job,
                open: None,
                files: 0,
            },
            pending: Vec::new(),
            progress: None,
            message: None,
            params: Vec::new(),
            sent: None,
        };
        run.send(false, None);
        let manager = Arc::clone(&self.jobs);
        let revision = read.map(|read| u32::try_from(read.store.current()).unwrap_or(u32::MAX));
        let source = read.map(|read| (read.document, read.generation));
        let spawned = thread::Builder::new()
            .name("ferman-job".to_owned())
            .stack_size(JOB_STACK)
            .spawn(move || {
                let outcome = guard(AssertUnwindSafe(|| {
                    Ok(work(&mut run).and_then(|change| {
                        run.checkpoint()?;
                        Ok((run.publish()?, change))
                    }))
                }))
                .unwrap_or_else(|err| Err(JobStop::Failed(err)));
                // Before the last event: a job that says it ended has left nothing behind.
                run.folder.remove();
                let (result, change) = match outcome {
                    Ok((outputs, change)) => (
                        JobResult::Done {
                            outputs,
                            revision,
                            change: change.is_some(),
                        },
                        change,
                    ),
                    Err(JobStop::Cancelled) => (JobResult::Cancelled, None),
                    Err(JobStop::Failed(err)) => (JobResult::Failed(err), None),
                };
                let change =
                    change
                        .zip(source)
                        .map(|(change, (document, generation))| WaitingChange {
                            change,
                            document,
                            generation,
                        });
                if let Some(entry) = manager.jobs().get_mut(&job) {
                    entry.finished = Some(Finished {
                        at: Instant::now(),
                        result: result.clone(),
                        change,
                    });
                }
                run.send(false, Some(result));
            });
        if spawned.is_err() {
            self.jobs.jobs().remove(&job);
            return Err(ApiError::internal("cannot start a job's thread"));
        }
        Ok(job)
    }

    /// Parks a job at its next checkpoint. A job that ended ignores it.
    pub fn pause_job(&self, job: JobId) {
        self.jobs.ask(job, Wish::Pause);
    }

    /// Lets a paused job go on. A job that ended ignores it.
    pub fn resume_job(&self, job: JobId) {
        self.jobs.ask(job, Wish::Run);
    }

    /// Cancels a job at its next checkpoint; it ends with [`JobResult::Cancelled`] and leaves
    /// nothing. A job that ended ignores it.
    pub fn cancel_job(&self, job: JobId) {
        self.jobs.ask(job, Wish::Cancel);
    }

    /// How `job` ended, for an hour after it did; `None` while it runs, and after that hour.
    #[must_use]
    pub fn job_result(&self, job: JobId) -> Option<JobResult> {
        self.jobs.purge(Instant::now());
        self.jobs
            .jobs()
            .get(&job)
            .and_then(|entry| entry.finished.as_ref())
            .map(|finished| finished.result.clone())
    }

    /// Commits the change `job` prepared, as one step of the document's history.
    ///
    /// # Errors
    ///
    /// `InvalidInput` with [`JOB_STALE`] when the document's revision moved since the job read
    /// it, which uses the change up, as a write that fails does; `NotFound` for a job with no
    /// change waiting or a document that closed; and what any commit returns. A refusal the user
    /// can answer (`ConfirmationRequired`, `TransactionOpen`, `NotEditable`) keeps the change for
    /// another try.
    pub async fn apply_job_change(&self, job: JobId) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let not_found = || ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL);
            let document = self
                .jobs
                .jobs()
                .get(&job)
                .and_then(|entry| entry.finished.as_ref())
                .and_then(|finished| finished.change.as_ref())
                .map(|waiting| waiting.document)
                .ok_or_else(not_found)?;
            let jobs = Arc::clone(&self.jobs);
            let (current, reload) = self
                .ask(document, move |session| {
                    // Taken on the actor: of two calls, one finds it.
                    let waiting = jobs.take_change(job).ok_or_else(not_found)?;
                    if session.published_generation() != waiting.generation {
                        return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                            .with_details(JOB_STALE));
                    }
                    if let Err(refused) = session.may_change(waiting.change.op) {
                        jobs.put_change_back(job, waiting);
                        return Err(refused);
                    }
                    let change = waiting.change;
                    session.commit_change(
                        change.op,
                        &change.fields,
                        change.name,
                        &change.pages,
                        change.summary,
                        change.write,
                    )
                })
                .await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }

    /// Copies `document` as its revisions stand now to the new file `output`, page by page, as a
    /// job: the first job, which proves the manager from the bridge to the file. With `staging`
    /// the file waits there for the platform layer's swap.
    ///
    /// # Errors
    ///
    /// `InvalidInput` when `output` exists, so a copy never replaces the document's own file (a
    /// file that appears there later fails the job, as [`JobRun::output_pdf`] says); `NotFound` for
    /// a document that is not open.
    pub fn copy_document_job(
        &self,
        document: DocumentId,
        output: PathBuf,
        staging: Option<PathBuf>,
        sink: Box<dyn JobSink>,
    ) -> Result<JobId, ApiError> {
        guard(AssertUnwindSafe(|| {
            if output.try_exists().unwrap_or(true) {
                return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                    .with_details("the copy's file exists"));
            }
            let snapshot = self.job_snapshot(document)?;
            let read = snapshot.clone();
            self.start_job(Some(&read), sink, move |run| {
                let base = snapshot.base();
                let pages = snapshot.store().pages(base).len();
                let pages = u32::try_from(pages).unwrap_or(u32::MAX);
                for page in 1..=pages {
                    run.checkpoint()?;
                    run.progress(
                        // A progress fraction: precision does not matter.
                        Some(f64::from(page) as f32 / f64::from(pages) as f32),
                        MessageKey::JOB_PAGE_OF,
                        vec![
                            ("page".to_owned(), page.to_string()),
                            ("pages".to_owned(), pages.to_string()),
                        ],
                    );
                }
                let bytes = snapshot
                    .store()
                    .incremental_update(base)
                    .map_err(ApiError::from)?;
                run.output_pdf(output, &bytes, staging)?;
                Ok(None)
            })
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::facade::block_on;
    use crate::facade::engine::{EngineConfig, PdfiumLibrary};
    use std::sync::mpsc;
    use std::time::Duration;

    /// A sink that hands each event to the test.
    struct Events(mpsc::Sender<JobEvent>);

    impl JobSink for Events {
        fn deliver(&mut self, event: JobEvent) {
            let _ = self.0.send(event);
        }
    }

    fn engine() -> Engine {
        Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Disabled,
        })
    }

    fn sink() -> (Box<dyn JobSink>, mpsc::Receiver<JobEvent>) {
        let (sender, events) = mpsc::channel();
        (Box::new(Events(sender)), events)
    }

    fn corpus() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/corpus/generated/kira-tr.pdf")
    }

    /// Opens kira-tr in `engine` as `id`, which PDFium's absence does not stop.
    fn open(engine: &Engine, id: u64) -> DocumentId {
        let source = ferman_core::Source::read(&corpus()).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        let id = DocumentId::from_raw(id);
        engine.models().unwrap().insert(
            id,
            Arc::new(Model::new(document, corpus(), None, false, None)),
        );
        id
    }

    /// A folder of `test`'s own.
    fn folder(test: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("ferman-jobs-{test}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn last(events: &mpsc::Receiver<JobEvent>) -> JobResult {
        loop {
            let event = events.recv_timeout(Duration::from_secs(60)).unwrap();
            if let Some(result) = event.result {
                return result;
            }
        }
    }

    fn job_folder(job: JobId) -> PathBuf {
        std::env::temp_dir().join(format!(
            "{FOLDER_PREFIX}{}-{}",
            std::process::id(),
            job.get()
        ))
    }

    fn pdf() -> Vec<u8> {
        fs::read(corpus()).unwrap()
    }

    #[test]
    fn the_first_event_names_the_job_and_the_last_its_end() {
        let engine = engine();
        let (sink, events) = sink();
        let job = engine.start_job(None, sink, |_| Ok(None)).unwrap();
        let first = events.recv().unwrap();
        assert_eq!(first.job, job);
        assert_eq!(first.result, None);
        assert_eq!(
            last(&events),
            JobResult::Done {
                outputs: Vec::new(),
                revision: None,
                change: false
            }
        );
        assert!(matches!(
            engine.job_result(job),
            Some(JobResult::Done { .. })
        ));
    }

    #[test]
    fn progress_comes_at_most_ten_times_a_second() {
        let engine = engine();
        let (sink, events) = sink();
        let started = Instant::now();
        engine
            .start_job(None, sink, |run| {
                for _ in 0..200_000 {
                    run.progress(Some(0.5), MessageKey::JOB_PAGE_OF, Vec::new());
                }
                thread::sleep(Duration::from_millis(250));
                run.progress(Some(1.0), MessageKey::JOB_PAGE_OF, Vec::new());
                Ok(None)
            })
            .unwrap();
        let mut sent = 0_u128;
        for event in events.iter() {
            if event.result.is_some() {
                break;
            }
            sent += u128::from(event.progress.is_some());
        }
        // One at the start, then one per gap.
        assert!(sent >= 2, "{sent}");
        assert!(
            sent <= 1 + started.elapsed().as_millis() / PROGRESS_GAP.as_millis(),
            "{sent}"
        );
    }

    #[test]
    fn a_paused_job_waits_at_its_checkpoint_and_goes_on() {
        let engine = engine();
        let (sink, events) = sink();
        let (step, steps) = mpsc::channel();
        let (go, wait) = mpsc::channel::<()>();
        let job = engine
            .start_job(None, sink, move |run| {
                wait.recv().unwrap();
                run.checkpoint()?;
                step.send(()).unwrap();
                Ok(None)
            })
            .unwrap();
        engine.pause_job(job);
        go.send(()).unwrap();
        let paused = events
            .iter()
            .find(|event| event.paused)
            .expect("a paused event");
        assert_eq!(paused.job, job);
        assert!(steps.recv_timeout(Duration::from_millis(100)).is_err());
        assert_eq!(engine.job_result(job), None);
        engine.resume_job(job);
        assert!(!events.recv().unwrap().paused);
        steps.recv_timeout(Duration::from_secs(60)).unwrap();
        assert!(matches!(last(&events), JobResult::Done { .. }));
    }

    #[test]
    fn cancelling_leaves_no_temp_file_and_no_output() {
        let engine = engine();
        let (sink, events) = sink();
        let dir = folder("cancel");
        let target = dir.join("out.pdf");
        let (go, wait) = mpsc::channel::<()>();
        let (seen, written) = mpsc::channel();
        let output = target.clone();
        let bytes = pdf();
        let job = engine
            .start_job(None, sink, move |run| {
                run.output_pdf(output, &bytes, None)?;
                seen.send(run.folder.open.is_some()).unwrap();
                wait.recv().unwrap();
                run.checkpoint()?;
                Ok(None)
            })
            .unwrap();
        assert!(written.recv().unwrap());
        assert!(job_folder(job).is_dir());
        engine.cancel_job(job);
        // A cancel stays, whatever follows.
        engine.resume_job(job);
        go.send(()).unwrap();
        assert_eq!(last(&events), JobResult::Cancelled);
        assert!(!job_folder(job).exists());
        assert!(!target.exists());
        assert_eq!(fs::read_dir(&dir).unwrap().count(), 0);
    }

    #[test]
    fn cancelling_a_paused_job_ends_it() {
        let engine = engine();
        let (sink, events) = sink();
        let (go, wait) = mpsc::channel::<()>();
        let job = engine
            .start_job(None, sink, move |run| {
                wait.recv().unwrap();
                run.checkpoint()?;
                Ok(None)
            })
            .unwrap();
        engine.pause_job(job);
        go.send(()).unwrap();
        assert!(events.iter().any(|event| event.paused));
        engine.cancel_job(job);
        assert_eq!(last(&events), JobResult::Cancelled);
    }

    #[test]
    fn a_failure_or_a_panic_leaves_nothing() {
        let engine = engine();
        let dir = folder("failure");
        let target = dir.join("out.pdf");
        for panics in [false, true] {
            let (sink, events) = sink();
            let output = target.clone();
            let bytes = pdf();
            let job = engine
                .start_job(None, sink, move |run| {
                    run.output_pdf(output, &bytes, None)?;
                    assert!(!panics, "a job's bug");
                    Err(ApiError::internal("failed").into())
                })
                .unwrap();
            assert!(matches!(last(&events), JobResult::Failed(_)));
            assert!(!job_folder(job).exists());
            assert!(!target.exists());
        }
    }

    #[test]
    fn a_failed_output_takes_back_the_ones_before_it() {
        let engine = engine();
        let (sink, events) = sink();
        let dir = folder("second-output");
        let first = dir.join("first.pdf");
        let second = dir.join("no-such-folder").join("second.pdf");
        let output = first.clone();
        let bytes = pdf();
        engine
            .start_job(None, sink, move |run| {
                run.output_pdf(output, &bytes, None)?;
                run.output_pdf(second, &bytes, None)?;
                Ok(None)
            })
            .unwrap();
        assert!(matches!(last(&events), JobResult::Failed(_)));
        assert!(!first.exists());
    }

    #[test]
    fn a_result_goes_after_an_hour() {
        let engine = engine();
        let (sink, events) = sink();
        let job = engine.start_job(None, sink, |_| Ok(None)).unwrap();
        last(&events);
        let near = Instant::now() + RESULT_KEPT - Duration::from_secs(60);
        engine.jobs.purge(near);
        assert!(engine.job_result(job).is_some());
        engine.jobs.purge(Instant::now() + RESULT_KEPT);
        assert_eq!(engine.job_result(job), None);
    }

    #[test]
    fn a_job_reads_the_revision_it_started_from_while_the_document_moves_on() {
        let engine = engine();
        let doc = open(&engine, 9_005);
        let read = engine.job_snapshot(doc).unwrap();
        let held = read.clone();
        block_on(engine.rotate_page(doc, 0, 1, "Moved on".to_owned())).unwrap();
        assert_eq!(block_on(engine.history(doc)).unwrap().current, 1);
        let dir = folder("moved-on");
        let target = dir.join("copy.pdf");
        let output = target.clone();
        let (sink, events) = sink();
        engine
            .start_job(Some(&read), sink, move |run| {
                let bytes = held
                    .store()
                    .incremental_update(held.base())
                    .map_err(ApiError::from)?;
                run.output_pdf(output, &bytes, None)?;
                Ok(None)
            })
            .unwrap();
        let JobResult::Done { revision, .. } = last(&events) else {
            panic!("expected Done");
        };
        assert_eq!(revision, Some(0));
        assert_eq!(fs::read(&target).unwrap(), pdf());
    }

    #[test]
    fn a_copy_writes_a_new_file_and_only_a_new_one() {
        let engine = engine();
        let doc = open(&engine, 9_001);
        let dir = folder("copy");
        let target = dir.join("copy.pdf");
        let (sink, events) = sink();
        let job = engine
            .copy_document_job(doc, target.clone(), None, sink)
            .unwrap();
        let result = last(&events);
        assert_eq!(
            result,
            JobResult::Done {
                outputs: vec![JobOutput {
                    path: target.clone(),
                    staged: None
                }],
                revision: Some(0),
                change: false
            }
        );
        assert_eq!(fs::read(&target).unwrap(), pdf());
        assert!(!job_folder(job).exists());
        // The file is there now, so a second copy to it is refused.
        let (sink, _events) = self::sink();
        let refused = engine
            .copy_document_job(doc, target, None, sink)
            .unwrap_err();
        assert_eq!(refused.kind, ErrorKind::InvalidInput);
    }

    #[test]
    fn a_copy_staged_for_the_sandbox_leaves_its_target_alone() {
        let engine = engine();
        let doc = open(&engine, 9_002);
        let dir = folder("staged");
        let staging = dir.join("staging");
        fs::create_dir_all(&staging).unwrap();
        let target = dir.join("copy.pdf");
        let (sink, events) = sink();
        engine
            .copy_document_job(doc, target.clone(), Some(staging.clone()), sink)
            .unwrap();
        let JobResult::Done { outputs, .. } = last(&events) else {
            panic!("expected Done");
        };
        let staged = outputs[0].staged.clone().unwrap();
        assert!(staged.starts_with(&staging));
        assert_eq!(fs::read(staged).unwrap(), pdf());
        assert!(!target.exists());
    }

    /// A change that rotates the first page.
    fn rotate() -> JobChange {
        JobChange {
            op: DocumentOp::Organize,
            fields: Vec::new(),
            name: "Rotated".to_owned(),
            pages: vec![0],
            summary: (String::new(), String::new()),
            write: Box::new(|doc, working| Ok(ferman_ops::pages::rotate(doc, working, &[0], 1)?)),
        }
    }

    #[test]
    fn a_change_applies_only_while_the_revision_stands() {
        let engine = engine();
        let doc = open(&engine, 9_003);
        let start = |engine: &Engine| {
            let (sink, events) = sink();
            let read = engine.job_snapshot(doc).unwrap();
            let job = engine
                .start_job(Some(&read), sink, |_| Ok(Some(rotate())))
                .unwrap();
            assert!(matches!(
                last(&events),
                JobResult::Done { change: true, .. }
            ));
            job
        };
        let job = start(&engine);
        let info = block_on(engine.apply_job_change(job)).unwrap();
        assert_eq!(info.current, 1);
        // Used up.
        let again = block_on(engine.apply_job_change(job)).unwrap_err();
        assert_eq!(again.kind, ErrorKind::NotFound);

        let stale = start(&engine);
        block_on(engine.rotate_page(doc, 0, 1, "Moved on".to_owned())).unwrap();
        let refused = block_on(engine.apply_job_change(stale)).unwrap_err();
        assert_eq!(refused.kind, ErrorKind::InvalidInput);
        assert_eq!(refused.details.as_deref(), Some(JOB_STALE));
        assert_eq!(block_on(engine.history(doc)).unwrap().current, 2);
    }

    #[test]
    fn a_change_for_a_closed_document_is_refused() {
        let engine = engine();
        let doc = open(&engine, 9_004);
        let (sink, events) = sink();
        let read = engine.job_snapshot(doc).unwrap();
        let job = engine
            .start_job(Some(&read), sink, |_| Ok(Some(rotate())))
            .unwrap();
        last(&events);
        engine.models().unwrap().remove(&doc);
        let refused = block_on(engine.apply_job_change(job)).unwrap_err();
        assert_eq!(refused.kind, ErrorKind::NotFound);
    }

    #[test]
    fn a_change_a_signed_document_stops_waits_for_the_confirmation() {
        let engine = engine();
        let source =
            ferman_core::Source::read(&corpus().with_file_name("kira-tr-signed.pdf")).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        let doc = DocumentId::from_raw(9_005);
        engine.models().unwrap().insert(
            doc,
            Arc::new(Model::new(document, corpus(), None, false, None)),
        );
        let (sink, events) = sink();
        let read = engine.job_snapshot(doc).unwrap();
        let job = engine
            .start_job(Some(&read), sink, |_| Ok(Some(rotate())))
            .unwrap();
        last(&events);
        let refused = block_on(engine.apply_job_change(job)).unwrap_err();
        assert_eq!(refused.kind, ErrorKind::ConfirmationRequired);
        block_on(engine.confirm_edit_signed(doc)).unwrap();
        assert_eq!(block_on(engine.apply_job_change(job)).unwrap().current, 1);
    }

    #[test]
    fn a_file_that_appears_while_a_copy_runs_is_not_replaced() {
        let engine = engine();
        let doc = open(&engine, 9_006);
        let dir = folder("appears");
        let target = dir.join("copy.pdf");
        let (sink, events) = sink();
        let read = engine.job_snapshot(doc).unwrap();
        let newer = target.clone();
        engine
            .start_job(Some(&read), sink, move |run| {
                run.output_pdf(newer.clone(), &pdf(), None)?;
                // The user's Save As, or another app, while the job waits.
                fs::write(&newer, b"newer").unwrap();
                Ok(None)
            })
            .unwrap();
        let JobResult::Failed(err) = last(&events) else {
            panic!("not refused");
        };
        assert_eq!(err.kind, ErrorKind::FileChangedOnDisk);
        assert_eq!(fs::read(&target).unwrap(), b"newer");
    }

    /// The environment variable that makes this test binary the job the crash test kills.
    const CRASH_CHILD: &str = "FERMAN_JOB_CRASH_CHILD";

    /// In a child process of [`a_killed_job_leaves_no_output_and_the_next_start_cleans_up`]:
    /// reaches the point of holding a temp file, says so, and dies there. With the variable set
    /// to `start`, only starts an engine.
    #[test]
    #[ignore = "a child process of the crash test"]
    fn crash_child() {
        let engine = engine();
        if std::env::var(CRASH_CHILD).as_deref() != Ok("kill") {
            return;
        }
        let target = PathBuf::from(std::env::var_os("FERMAN_JOB_CRASH_TARGET").unwrap());
        let (sink, _events) = sink();
        let bytes = pdf();
        engine
            .start_job(None, sink, move |run| {
                run.output_pdf(target, &bytes, None)?;
                std::process::abort();
            })
            .unwrap();
        thread::sleep(Duration::from_secs(60));
    }

    #[test]
    fn a_killed_job_leaves_no_output_and_the_next_start_cleans_up() {
        let dir = folder("crash");
        let temp = dir.join("temp");
        fs::create_dir_all(&temp).unwrap();
        let target = dir.join("out.pdf");
        let child = |mode: &str| {
            std::process::Command::new(std::env::current_exe().unwrap())
                .args(["--exact", "facade::jobs::tests::crash_child", "--ignored"])
                .env(CRASH_CHILD, mode)
                .env("FERMAN_JOB_CRASH_TARGET", &target)
                .env("TMPDIR", &temp)
                .env("TEMP", &temp)
                .env("TMP", &temp)
                .output()
                .unwrap()
        };
        let killed = child("kill");
        assert!(!killed.status.success());
        assert!(!target.exists());
        let held = |temp: &Path| {
            fs::read_dir(temp)
                .unwrap()
                .flatten()
                .filter(|entry| {
                    entry
                        .file_name()
                        .to_string_lossy()
                        .starts_with(FOLDER_PREFIX)
                })
                .count()
        };
        assert_eq!(held(&temp), 1, "the crash leaves its job folder");
        assert!(child("start").status.success());
        assert_eq!(held(&temp), 0, "the next start deletes it");
    }

    #[test]
    fn a_running_job_keeps_its_folder_through_a_sweep() {
        let engine = engine();
        let (sink, events) = sink();
        let (go, wait) = mpsc::channel::<()>();
        let (seen, written) = mpsc::channel();
        let job = engine
            .start_job(None, sink, move |run| {
                run.temp_file()?;
                seen.send(()).unwrap();
                wait.recv().unwrap();
                Ok(None)
            })
            .unwrap();
        written.recv().unwrap();
        sweep(&std::env::temp_dir());
        assert!(job_folder(job).is_dir());
        go.send(()).unwrap();
        last(&events);
    }
}
