//! Pages between files (a6-2, a6-3, G45): Extract, Split and Combine as jobs that write new files,
//! Insert and Replace as jobs that hand back a change for the open document, and the previews their
//! dialogs show first.
//!
//! An output is unencrypted and carries no signature, whatever its inputs: the previews say so
//! before anything is written, and an input that forbids assembling needs its owner password
//! (question 6 of the M4 plan). Create PDF is a Combine: a blank page or files into a new file, which
//! the app then opens, since the open path reads a file.

use std::collections::BTreeSet;
use std::panic::AssertUnwindSafe;
use std::path::{Path, PathBuf};
use std::thread;

use ferman_core::assemble::ImportOptions;
use ferman_core::assemble::PageImport;
use ferman_core::revision::RevisionStore;
use ferman_core::{CoreError, Document, DocumentOp, OpenOptions, Password, Source};
use ferman_ops::OpsError;
use ferman_ops::combine::{Assembly, copy_pages, place_after, place_replacing};
use ferman_ops::images::{self, Image, Paper};
use ferman_ops::split::{self, Naming, SplitFile, SplitMode};
use ferman_render::{DocumentId, PageSize};
use ferman_text::NotEditableReason;

use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};
use super::jobs::{JobChange, JobId, JobRun, JobSink, JobStop};

/// The thread of a preview, with the stack of the open thread: a parser recurses, within limits.
const PREVIEW_STACK: usize = 64 * 1024 * 1024;

/// Pixels per inch of the raster that tells a blank page: a mark that small still shows.
const BLANK_DPI: u32 = 36;

/// What a file with nothing but one blank or image page costs.
const SMALL_FILE: u64 = 512;

/// What a new file gets from a document's pages. Attachments belong to no page, so Extract and
/// Split leave them.
const PAGES_ONLY: ImportOptions = ImportOptions {
    keep_forms: true,
    document_parts: false,
};

/// One input of Combine or Create PDF.
#[derive(Debug, Clone)]
pub enum CombineSource {
    /// A PDF or an image file.
    File {
        /// Where it is.
        path: PathBuf,
        /// What opens it.
        password: Option<Password>,
        /// Its pages by index, in the order to take them; `None` for all. An image has one.
        pages: Option<Vec<u32>>,
    },
    /// A blank page of this width and height, in points.
    Blank(f32, f32),
}

/// One input with what goes with it.
#[derive(Debug, Clone)]
pub struct CombineFile {
    /// What it is.
    pub source: CombineSource,
    /// The title of a bookmark for its first page, when a6-3's checkbox asks for one.
    pub bookmark: Option<String>,
}

/// Whether an input can be used, for its row in a6-3 (G45).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputStatus {
    /// It can.
    Ready,
    /// It needs its password.
    PasswordRequired,
    /// The password does not open it.
    WrongPassword,
    /// It forbids assembling, which only its owner password lifts.
    OwnerPasswordRequired,
    /// Its page range names a page it does not have, or a page twice.
    BadRange,
    /// Neither a PDF nor an image Ferman can read, or the file is gone.
    Unreadable,
}

/// One input's row.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CombineFileInfo {
    /// Whether it can be used; the numbers below are zero if not.
    pub status: InputStatus,
    /// Whether it is an image, "converted to 1 page".
    pub image: bool,
    /// Its pages in all.
    pub pages: u32,
    /// How many of them it adds.
    pub selected: u32,
    /// About what it adds to the output, in bytes.
    pub bytes: u64,
    /// Whether it is encrypted: the output will not be.
    pub encrypted: bool,
    /// Whether it is signed: the output carries no signature.
    pub signed: bool,
}

/// What a6-3 shows before anything is written.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CombinePreview {
    /// A row per input, in order.
    pub files: Vec<CombineFileInfo>,
    /// The pages of the output.
    pub pages: u32,
    /// About how large it comes out, in bytes.
    pub bytes: u64,
}

/// What a6-2 shows before anything is written.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SplitPreview {
    /// The files.
    pub files: Vec<SplitFile>,
    /// How many top-level bookmarks go to a page.
    pub bookmarks: u32,
    /// How many pages count as blank.
    pub blank_pages: u32,
    /// Whether the document is encrypted: the files will not be.
    pub encrypted: bool,
    /// Whether it is signed: the files carry no signature.
    pub signed: bool,
}

/// One file of a split, as the plan names it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SplitOutput {
    /// Its name in the output folder.
    pub name: String,
    /// Its first page, as an index.
    pub first: u32,
    /// Its last page, as an index.
    pub last: u32,
}

/// An input read into memory.
enum Loaded {
    Pdf(Box<Document>),
    Image(Image),
}

/// Reads `path` as a PDF or, failing that, as an image. Text from it is untrusted; the limits are
/// the open path's.
fn load(path: &Path, password: Option<Password>) -> Result<Loaded, ApiError> {
    let source = Source::read(path)?;
    let options = OpenOptions {
        password,
        ..OpenOptions::default()
    };
    match ferman_core::open(&source, &options) {
        Ok(document) => {
            if !document.permissions().assemble() {
                return Err(ApiError::not_editable(NotEditableReason::Restricted));
            }
            Ok(Loaded::Pdf(Box::new(document)))
        }
        Err(not_pdf @ CoreError::NotPdf { .. }) => {
            match images::load(source.bytes(), &options.limits) {
                Ok(image) => Ok(Loaded::Image(image)),
                Err(OpsError::UnreadableImage) => Err(not_pdf.into()),
                Err(err) => Err(err.into()),
            }
        }
        Err(err) => Err(err.into()),
    }
}

/// `pages` as indices, all of them for `None`.
fn indices(pages: Option<&[u32]>, count: usize) -> Vec<usize> {
    pages.map_or_else(
        || (0..count).collect(),
        |pages| {
            pages
                .iter()
                .map(|page| usize::try_from(*page).unwrap_or(usize::MAX))
                .collect()
        },
    )
}

/// The row of `file`.
fn inspect(file: &CombineSource, keep_forms: bool) -> CombineFileInfo {
    let row = |status| CombineFileInfo {
        status,
        image: false,
        pages: 0,
        selected: 0,
        bytes: 0,
        encrypted: false,
        signed: false,
    };
    let CombineSource::File {
        path,
        password,
        pages,
    } = file
    else {
        return CombineFileInfo {
            pages: 1,
            selected: 1,
            bytes: SMALL_FILE,
            ..row(InputStatus::Ready)
        };
    };
    let loaded = match load(path, password.clone()) {
        Ok(loaded) => loaded,
        Err(err) => {
            return row(match err.kind {
                ErrorKind::PasswordRequired => InputStatus::PasswordRequired,
                ErrorKind::WrongPassword => InputStatus::WrongPassword,
                ErrorKind::NotEditable => InputStatus::OwnerPasswordRequired,
                _ => InputStatus::Unreadable,
            });
        }
    };
    let document = match loaded {
        Loaded::Pdf(document) => document,
        Loaded::Image(image) => {
            let stored = match &image.pixels {
                images::Pixels::Dct(jpeg) => jpeg.len(),
                images::Pixels::Samples(samples) => samples.len(),
            };
            return CombineFileInfo {
                image: true,
                pages: 1,
                selected: 1,
                bytes: u64::try_from(stored)
                    .unwrap_or(u64::MAX)
                    .saturating_add(SMALL_FILE),
                ..row(InputStatus::Ready)
            };
        }
    };
    let revisions = RevisionStore::new(&document);
    let count = revisions.pages(&document).len();
    let selection = indices(pages.as_deref(), count);
    let options = ImportOptions {
        keep_forms,
        document_parts: true,
    };
    let Ok(mut weighing) = PageImport::new(&document, &revisions, &selection, options) else {
        return row(InputStatus::BadRange);
    };
    let mut bytes = 0u64;
    for position in 0..selection.len() {
        // A page too deep to weigh is a page the job will refuse too.
        let Ok(more) = weighing.weigh(position) else {
            return row(InputStatus::Unreadable);
        };
        bytes = bytes.saturating_add(more);
    }
    let Ok(more) = weighing.weigh_attachments() else {
        return row(InputStatus::Unreadable);
    };
    bytes = bytes.saturating_add(more);
    CombineFileInfo {
        pages: u32::try_from(count).unwrap_or(u32::MAX),
        selected: u32::try_from(selection.len()).unwrap_or(u32::MAX),
        bytes,
        encrypted: document.encryption().is_some(),
        signed: document.structure().signed(),
        ..row(InputStatus::Ready)
    }
}

/// Runs `work` on a thread of its own, so that a large file never holds an async worker.
async fn off_the_worker<T: Send + 'static>(
    work: impl FnOnce() -> Result<T, ApiError> + Send + 'static,
) -> Result<T, ApiError> {
    let (reply, receiver) = futures_channel::oneshot::channel();
    thread::Builder::new()
        .name("ferman-preview".to_owned())
        .stack_size(PREVIEW_STACK)
        .spawn(move || {
            // The caller may have stopped waiting; then nobody needs the result.
            let _ = reply.send(guard(AssertUnwindSafe(work)));
        })
        .map_err(|_| ApiError::internal("cannot start a preview's thread"))?;
    receiver
        .await
        .map_err(|_canceled| ApiError::internal("a preview's thread stopped"))?
}

/// Refuses a new file's place that is taken, so a job never replaces a file; one that appears
/// later fails the job ([`JobRun::output_pdf`]).
fn free_output(output: &Path) -> Result<(), ApiError> {
    if output.try_exists().unwrap_or(true) {
        return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
            .with_details("the output file exists"));
    }
    Ok(())
}

fn invalid(details: &'static str) -> ApiError {
    ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL).with_details(details)
}

/// Counts the pages a job copies and reports them, one checkpoint each.
struct Progress<'a> {
    run: &'a mut JobRun,
    done: u32,
    total: u32,
}

impl Progress<'_> {
    fn step(&mut self) -> Result<(), JobStop> {
        self.run.checkpoint()?;
        self.done = self.done.saturating_add(1);
        self.run.progress(
            // A progress fraction: precision does not matter.
            Some(f64::from(self.done) as f32 / f64::from(self.total.max(1)) as f32),
            MessageKey::JOB_PAGE_OF,
            vec![
                ("page".to_owned(), self.done.to_string()),
                ("pages".to_owned(), self.total.to_string()),
            ],
        );
        Ok(())
    }
}

/// `pages` of the file at `path` brought in: for the write of a [`JobChange`].
struct Incoming {
    loaded: Loaded,
    pages: Option<Vec<u32>>,
    paper: Paper,
}

impl Incoming {
    /// Opens it and checks its range, in the job, so the commit only has to copy.
    fn read(
        path: &Path,
        password: Option<Password>,
        pages: Option<Vec<u32>>,
        paper: Paper,
    ) -> Result<Self, ApiError> {
        let loaded = load(path, password)?;
        if let Loaded::Pdf(document) = &loaded {
            let revisions = RevisionStore::new(document);
            let selection = indices(pages.as_deref(), revisions.pages(document).len());
            PageImport::new(document, &revisions, &selection, inserted_options())?;
        }
        Ok(Self {
            loaded,
            pages,
            paper,
        })
    }

    /// Copies it into the open transaction of `working`, the first pages taking over `replacing`.
    // shortcut: the copy runs on the document's actor, which waits for it; it clones what the file
    // holds and decodes nothing. Copy in the job and replay the objects if a large insert stalls
    // the document's other calls.
    fn write(
        &self,
        doc: &Document,
        working: &mut RevisionStore,
        replacing: &[ferman_core::write::ObjectRef],
    ) -> Result<Vec<ferman_core::write::ObjectRef>, ApiError> {
        match &self.loaded {
            Loaded::Pdf(source) => {
                let revisions = RevisionStore::new(source);
                let selection = indices(self.pages.as_deref(), revisions.pages(source).len());
                copy_pages(
                    doc,
                    working,
                    source,
                    &revisions,
                    &selection,
                    inserted_options(),
                    None,
                    replacing,
                    &mut || Ok::<(), OpsError>(()),
                )
                .map_err(ApiError::from)
            }
            Loaded::Image(image) => Ok(vec![images::image_page(doc, working, image, self.paper)?]),
        }
    }

    /// How many pages it brings.
    fn page_count(&self) -> u32 {
        match &self.loaded {
            Loaded::Image(_) => 1,
            Loaded::Pdf(document) => match &self.pages {
                Some(pages) => u32::try_from(pages.len()).unwrap_or(u32::MAX),
                None => u32::try_from(document.page_count()).unwrap_or(u32::MAX),
            },
        }
    }
}

fn inserted_options() -> ImportOptions {
    ImportOptions {
        keep_forms: true,
        document_parts: true,
    }
}

impl Engine {
    /// What Combine would write for `files`, with a row per input.
    ///
    /// # Errors
    ///
    /// `Internal` when its thread does not start. A file that cannot be used says so in its row.
    pub async fn combine_preview(
        &self,
        files: Vec<CombineSource>,
        keep_forms: bool,
    ) -> Result<CombinePreview, ApiError> {
        off_the_worker(move || {
            let files: Vec<CombineFileInfo> =
                files.iter().map(|file| inspect(file, keep_forms)).collect();
            let pages = files
                .iter()
                .fold(0u32, |sum, file| sum.saturating_add(file.selected));
            let bytes = files
                .iter()
                .fold(SMALL_FILE, |sum, file| sum.saturating_add(file.bytes));
            Ok(CombinePreview {
                files,
                pages,
                bytes,
            })
        })
        .await
    }

    /// Writes `files`, in order, as the new file `output`, as a job: Combine, and Create PDF from
    /// a blank page or files. An image with no page size takes `paper` (G152). With `staging` the
    /// file waits there for the platform layer's swap.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for no input or an `output` that exists. An input that cannot be used fails
    /// the job with its own error, and leaves nothing.
    pub fn combine_job(
        &self,
        files: Vec<CombineFile>,
        keep_forms: bool,
        paper: Paper,
        output: PathBuf,
        staging: Option<PathBuf>,
        sink: Box<dyn JobSink>,
    ) -> Result<JobId, ApiError> {
        guard(AssertUnwindSafe(|| {
            if files.is_empty() {
                return Err(invalid("nothing to combine"));
            }
            free_output(&output)?;
            self.start_job(None, sink, move |run| {
                let options = ImportOptions {
                    keep_forms,
                    document_parts: true,
                };
                let limits = OpenOptions::default().limits;
                let mut read = Vec::with_capacity(files.len());
                let mut total = 0u32;
                for file in files {
                    run.checkpoint()?;
                    let CombineSource::File {
                        path,
                        password,
                        pages,
                    } = &file.source
                    else {
                        total = total.saturating_add(1);
                        read.push((file, None));
                        continue;
                    };
                    let loaded = load(path, password.clone())?;
                    total = total.saturating_add(match (&loaded, pages) {
                        (Loaded::Pdf(_), Some(pages)) => {
                            u32::try_from(pages.len()).unwrap_or(u32::MAX)
                        }
                        (Loaded::Pdf(document), None) => {
                            u32::try_from(document.page_count()).unwrap_or(u32::MAX)
                        }
                        (Loaded::Image(_), _) => 1,
                    });
                    read.push((file, Some(loaded)));
                }
                let mut assembly = Assembly::new(&limits)?;
                let mut progress = Progress {
                    run,
                    done: 0,
                    total,
                };
                for (file, loaded) in read {
                    let bookmark = file.bookmark.as_deref();
                    match (file.source, loaded) {
                        (CombineSource::Blank(width, height), _) => {
                            progress.step()?;
                            assembly.add_blank((width, height), bookmark)?;
                        }
                        (_, Some(Loaded::Image(image))) => {
                            progress.step()?;
                            assembly.add_image(&image, paper, bookmark)?;
                        }
                        (CombineSource::File { pages, .. }, Some(Loaded::Pdf(document))) => {
                            let revisions = RevisionStore::new(&document);
                            let selection =
                                indices(pages.as_deref(), revisions.pages(&document).len());
                            assembly.add_pages(
                                &document,
                                &revisions,
                                &selection,
                                options,
                                bookmark,
                                &mut || progress.step(),
                            )?;
                        }
                        (CombineSource::File { .. }, None) => {
                            return Err(ApiError::internal("an input that was not read").into());
                        }
                    }
                }
                let bytes = assembly.finish()?;
                progress.run.output_pdf(output, &bytes, staging)?;
                Ok(None)
            })
        }))
    }

    /// Writes `pages` (by handle, in their order) of `document` as its revisions stand now as the
    /// new file `output`, as a job. The result reports the revision it read.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for an `output` that exists or a page it does not have; `NotEditable` for a
    /// document that forbids assembling without its owner password; `NotFound`.
    pub fn extract_pages_job(
        &self,
        document: DocumentId,
        pages: Vec<u64>,
        output: PathBuf,
        staging: Option<PathBuf>,
        sink: Box<dyn JobSink>,
    ) -> Result<JobId, ApiError> {
        guard(AssertUnwindSafe(|| {
            free_output(&output)?;
            let snapshot = self.job_snapshot(document)?;
            snapshot.may_assemble()?;
            let selection = pages
                .iter()
                .map(|handle| snapshot.store().page_index(snapshot.base(), *handle))
                .collect::<Option<Vec<usize>>>()
                .ok_or_else(|| invalid("a page the document does not have"))?;
            let read = snapshot.clone();
            self.start_job(Some(&read), sink, move |run| {
                let mut assembly = Assembly::new(&OpenOptions::default().limits)?;
                let mut progress = Progress {
                    run,
                    done: 0,
                    total: u32::try_from(selection.len()).unwrap_or(u32::MAX),
                };
                assembly.add_pages(
                    snapshot.base(),
                    snapshot.store(),
                    &selection,
                    PAGES_ONLY,
                    None,
                    &mut || progress.step(),
                )?;
                let bytes = assembly.finish()?;
                progress.run.output_pdf(output, &bytes, staging)?;
                Ok(None)
            })
        }))
    }

    /// The files a split of `document` would write (a6-2). `folder`, when known, keeps the names
    /// free in it; under the sandbox the folder comes from the picker (G143), which grants it.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for a count or size of nothing; `NotFound`; for
    /// [`SplitMode::BlankPages`], the render thread's errors.
    pub async fn split_preview(
        &self,
        document: DocumentId,
        mode: SplitMode,
        template: String,
        folder: Option<PathBuf>,
    ) -> Result<SplitPreview, ApiError> {
        guard_async(async move {
            let snapshot = self.job_snapshot(document)?;
            snapshot.may_assemble()?;
            let mut blank = Vec::new();
            if mode == SplitMode::BlankPages {
                let sizes: Vec<(f32, f32)> = snapshot
                    .store()
                    .pages(snapshot.base())
                    .iter()
                    .map(|page| page.size)
                    .collect();
                for (index, (width, height)) in sizes.into_iter().enumerate() {
                    let page = u32::try_from(index).unwrap_or(u32::MAX);
                    let raster = ferman_render::render_page(
                        self.render()?,
                        document,
                        page,
                        PageSize { width, height },
                        BLANK_DPI,
                    )
                    .await?;
                    if split::is_blank(&raster.pixels) {
                        blank.push(index);
                    }
                }
            }
            off_the_worker(move || {
                let base = snapshot.base();
                let stem = snapshot.file_stem();
                let taken = |name: &str| {
                    folder
                        .as_ref()
                        .is_some_and(|folder| folder.join(name).exists())
                };
                let plan = split::plan(
                    base,
                    snapshot.store(),
                    mode,
                    &blank,
                    Naming {
                        document: &stem,
                        template: &template,
                    },
                    &taken,
                )?;
                Ok(SplitPreview {
                    files: plan.files,
                    bookmarks: plan.bookmarks,
                    blank_pages: plan.blank_pages,
                    encrypted: base.encryption().is_some(),
                    signed: base.structure().signed(),
                })
            })
            .await
        })
        .await
    }

    /// Writes `files`, as [`split_preview`](Self::split_preview) planned them, into `folder` as
    /// new files, as a job. The result reports the revision it read.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for no file, a name that is not a plain file name, one used twice or taken,
    /// or a page range the document does not have; `NotEditable` and `NotFound` as
    /// [`extract_pages_job`](Self::extract_pages_job).
    pub fn split_job(
        &self,
        document: DocumentId,
        files: Vec<SplitOutput>,
        folder: PathBuf,
        staging: Option<PathBuf>,
        sink: Box<dyn JobSink>,
    ) -> Result<JobId, ApiError> {
        guard(AssertUnwindSafe(|| {
            let snapshot = self.job_snapshot(document)?;
            snapshot.may_assemble()?;
            if files.is_empty() {
                return Err(invalid("no file to write"));
            }
            let count = snapshot.store().pages(snapshot.base()).len();
            let mut names = BTreeSet::new();
            let mut total = 0u32;
            for file in &files {
                if Path::new(&file.name).file_name() != Some(file.name.as_ref())
                    || !names.insert(file.name.to_lowercase())
                {
                    return Err(invalid("a file name that cannot be used"));
                }
                free_output(&folder.join(&file.name))?;
                if file.first > file.last
                    || usize::try_from(file.last).unwrap_or(usize::MAX) >= count
                {
                    return Err(invalid("a page range the document does not have"));
                }
                total = total.saturating_add(file.last - file.first + 1);
            }
            let read = snapshot.clone();
            self.start_job(Some(&read), sink, move |run| {
                let limits = OpenOptions::default().limits;
                let mut progress = Progress {
                    run,
                    done: 0,
                    total,
                };
                for file in files {
                    let selection: Vec<usize> = (file.first..=file.last)
                        .map(|page| usize::try_from(page).unwrap_or(usize::MAX))
                        .collect();
                    let mut assembly = Assembly::new(&limits)?;
                    assembly.add_pages(
                        snapshot.base(),
                        snapshot.store(),
                        &selection,
                        PAGES_ONLY,
                        None,
                        &mut || progress.step(),
                    )?;
                    let bytes = assembly.finish()?;
                    progress
                        .run
                        .output_pdf(folder.join(&file.name), &bytes, staging.clone())?;
                }
                Ok(None)
            })
        }))
    }

    /// Reads `pages` (`None` for all) of the PDF or image at `path` as a job, whose change, for
    /// [`apply_job_change`](Self::apply_job_change), inserts them after the page `after`, or first
    /// when `None`, as one step `name`. It is refused if the document moved since (decision 1).
    ///
    /// # Errors
    ///
    /// `InvalidInput` for a page it does not have; `NotEditable` and `NotFound` as
    /// [`extract_pages_job`](Self::extract_pages_job). A file that cannot be used fails the job.
    #[allow(clippy::too_many_arguments)]
    pub fn insert_pages_job(
        &self,
        document: DocumentId,
        path: PathBuf,
        password: Option<Password>,
        pages: Option<Vec<u32>>,
        after: Option<u64>,
        paper: Paper,
        name: String,
        sink: Box<dyn JobSink>,
    ) -> Result<JobId, ApiError> {
        guard(AssertUnwindSafe(|| {
            let snapshot = self.job_snapshot(document)?;
            snapshot.may_assemble()?;
            let anchor = after
                .map(|handle| {
                    snapshot
                        .store()
                        .page_index(snapshot.base(), handle)
                        .ok_or_else(|| invalid("a page the document does not have"))
                })
                .transpose()?;
            self.start_job(Some(&snapshot), sink, move |run| {
                run.checkpoint()?;
                let incoming = Incoming::read(&path, password, pages, paper)?;
                report_read(run, incoming.page_count());
                Ok(Some(JobChange {
                    op: DocumentOp::Organize,
                    fields: Vec::new(),
                    name,
                    pages: anchor.into_iter().collect(),
                    summary: (String::new(), String::new()),
                    write: Box::new(move |doc, working| {
                        let new = incoming.write(doc, working, &[])?;
                        place_after(doc, working, &new, anchor)?;
                        Ok(())
                    }),
                }))
            })
        }))
    }

    /// Reads `source_pages` (`None` for all) of the PDF at `path` as a job, whose change, for
    /// [`apply_job_change`](Self::apply_job_change), puts them in the place of `pages` (by handle)
    /// as one step `name`. Each new page takes over a replaced page's object, so bookmarks, links
    /// and labels that went to it stay; fewer new pages delete the rest, more go after the last.
    /// It is refused if the document moved since (decision 1).
    ///
    /// # Errors
    ///
    /// `InvalidInput` for no page or one it does not have; `NotEditable` and `NotFound` as
    /// [`extract_pages_job`](Self::extract_pages_job). A file that cannot be used fails the job.
    #[allow(clippy::too_many_arguments)]
    pub fn replace_pages_job(
        &self,
        document: DocumentId,
        pages: Vec<u64>,
        path: PathBuf,
        password: Option<Password>,
        source_pages: Option<Vec<u32>>,
        name: String,
        sink: Box<dyn JobSink>,
    ) -> Result<JobId, ApiError> {
        guard(AssertUnwindSafe(|| {
            let snapshot = self.job_snapshot(document)?;
            snapshot.may_assemble()?;
            let replaced: BTreeSet<usize> = pages
                .iter()
                .map(|handle| snapshot.store().page_index(snapshot.base(), *handle))
                .collect::<Option<_>>()
                .ok_or_else(|| invalid("a page the document does not have"))?;
            if replaced.is_empty() {
                return Err(invalid("no page to replace"));
            }
            let replaced: Vec<usize> = replaced.into_iter().collect();
            self.start_job(Some(&snapshot), sink, move |run| {
                run.checkpoint()?;
                // Paper is for images, which do not get here.
                let incoming = Incoming::read(&path, password, source_pages, Paper::A4)?;
                if matches!(incoming.loaded, Loaded::Image(_)) {
                    return Err(invalid("an image cannot replace pages").into());
                }
                report_read(run, incoming.page_count());
                Ok(Some(JobChange {
                    op: DocumentOp::Organize,
                    fields: Vec::new(),
                    name,
                    pages: replaced.clone(),
                    summary: (String::new(), String::new()),
                    write: Box::new(move |doc, working| {
                        let refs = working.page_refs(doc, &replaced)?;
                        let new = incoming.write(doc, working, &refs)?;
                        place_replacing(doc, working, &replaced, &new)?;
                        Ok(())
                    }),
                }))
            })
        }))
    }
}

/// Reports that a change's source was read: its copy is the commit's.
fn report_read(run: &mut JobRun, pages: u32) {
    run.progress(
        Some(1.0),
        MessageKey::JOB_PAGE_OF,
        vec![
            ("page".to_owned(), pages.to_string()),
            ("pages".to_owned(), pages.to_string()),
        ],
    );
}
