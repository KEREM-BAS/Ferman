//! Edit transactions, undo and redo, and saving (docs/ARCHITECTURE.md §3.6, §4.2, §5.4 and §5.5,
//! ADR 0009).
//!
//! Each document that is edited gets an actor: a thread of its own (`ferman-edit`) that runs the
//! document's edit calls one at a time from its mailbox, so mutations have a total order and never
//! run on the UI's threads. The actor holds the document's [`RevisionStore`] and the open
//! transaction. After each commit, undo and redo it publishes the committed store in the model
//! ([`Model::revised`]), which [`Engine::text_blocks`] lays out, and the engine hands the render
//! thread the revised bytes (the incremental update the save would write), so PDFium reloads the
//! document and every page gets a new render key.
//!
//! A transaction edits one block. [`Engine::apply`] replaces the block's whole text: it rewrites
//! the block of the committed revision each time, so the open transaction holds only the newest
//! text, and returns the page as it would read (the preview is not rendered). [`Engine::commit`]
//! makes it a named step of the history (a3-10), [`Engine::rollback`] discards it.
//!
//! A document is editable only when it opened writable (not repaired, its readers agree, not an
//! XFA-only form) and its author's restrictions do not apply (or the owner password lifted them,
//! docs/ARCHITECTURE.md §6.5); otherwise [`Engine::begin_edit`] fails with
//! [`ErrorKind::NotEditable`] and the reason's message.
//!
//! Missing glyphs (docs/ARCHITECTURE.md §6.7, ADR 0006): step 1 is the rewriter's own; steps 2 and
//! 3 look in the fonts [`Engine::set_font_settings`] names (the bundled directory, extra
//! directories and, when allowed, the system's), indexed once on an actor thread the first time
//! an edit needs them. The preview carries step 3's [`MissingGlyphInfo`]: with "Ask each time"
//! the text waits for [`Engine::choose_font`] or [`Engine::keep_as_is`]; otherwise the closest
//! candidate draws the characters provisionally and the commit is refused until one of the two
//! is called, so nothing is substituted silently. Every substitution is recorded with its commit
//! ([`HistoryStep::substitutions`], [`RevisionInfo::substitutions`]), marked as announced after
//! the first commit that names its font, so the UI says it once (G37).
//!
//! Saving (docs/ARCHITECTURE.md §7, ADR 0008) writes the committed revisions through ferman-core's
//! save sequence ([`ferman_core::save::save_pdf`]): an incremental update by default, the whole
//! file rewritten once [`Engine::optimize_and_clean`] has run (so the earlier revisions it dropped
//! never come back), and a full rewrite to another file for a repaired document
//! ([`Engine::save_repaired_copy`]). Each failure of §7.8 has its kind, and says whether Save as
//! is the way out; the committed revisions stay as they were, so the save can be tried again.
//! The actor keeps the file's stamp (size, modification time, SHA-256) from the open and from
//! each save, and Save stops with [`ErrorKind::FileChangedOnDisk`] when the file changed under
//! it (§7.5); [`Engine::check_external_change`] asks the same when the window regains focus.
//! "Keep mine" is [`Engine::save_over_change`]; "Reload" is the app closing the document and
//! opening it again, which drops the edits.
//!
//! Under the macOS App Sandbox a file is granted on its own, not its folder, so every save takes
//! an optional staging directory (ADR 0008): the file is written and checked there, the staged
//! path goes back to the app, whose platform layer swaps it in, and [`Engine::finish_save`] then
//! records the stamp and moves the document's file and saved revision. Until then the document
//! is as it was, so a swap that fails keeps the edits and can be tried again.
//!
//! A recovery write that fails never fails an edit. The actor remembers it until a later write
//! succeeds, and a save failure says so ([`ApiError::no_recovery_copy`]), since the edits are then
//! only in memory (docs/ARCHITECTURE.md §7.8).
//!
//! Signed documents (docs/ARCHITECTURE.md §6.9, G35): a transaction may preview, but a commit that
//! changes something and every write of a signed document fail with
//! [`ErrorKind::ConfirmationRequired`] until [`Engine::confirm_edit_signed`] ran ("Edit anyway").
//! The actor holds the confirmation until the document closes; it is never persisted, not even
//! across a restore from the recovery files. The one write without it is a byte-for-byte copy of
//! the unchanged file to another path, which leaves the signature valid. "Edit a copy" is
//! [`Engine::save_unsigned_copy`] and an open of the new file.

use std::panic::AssertUnwindSafe;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc;
use std::sync::{Arc, Mutex, PoisonError};
use std::thread;
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use ferman_core::recovery::{Change, DocumentRecovery, SYNC_INTERVAL};
use ferman_core::revision::{self, RevisionStore};
use ferman_core::save::FileStamp;
use ferman_core::{CoreError, WriteError};
use ferman_fonts::{FontLibrary, FontOrigin, ScanLimits};
use ferman_render::DocumentId;
use ferman_text::extract::CharBox;
use ferman_text::{
    BlockId, BlockStyle, BlockStyleInfo, Choice, EditContext, Editability, FontCandidate,
    FontChoice, FontSources, MissingGlyphs, MissingReason, NotEditableReason, Outcome,
    OverflowPlan, Substitution, SubstitutionKind, TextBlock,
};

use super::document::Model;
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};
use super::recovery::Recovery;
use super::text::{PageBlocks, page_blocks_info};

/// The stack of an actor thread: the interpreter recurses into nested objects, bounded by the
/// limits, as the open and layout threads do.
const ACTOR_STACK: usize = 64 * 1024 * 1024;

/// The handle of an open edit transaction.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct TransactionId(u64);

impl TransactionId {
    /// The raw value, for the UI.
    #[must_use]
    pub fn get(self) -> u64 {
        self.0
    }

    /// A transaction id from its raw value.
    #[must_use]
    pub fn from_raw(raw: u64) -> Self {
        Self(raw)
    }
}

/// What the block's page would read after [`Engine::apply`].
#[derive(Debug, Clone, PartialEq)]
pub struct EditPreview {
    /// The page's blocks with the new text; with the text before when characters are missing.
    pub page: PageBlocks,
    /// The characters no font could draw, each once in the order they first appear: the text
    /// was not applied ([`glyphs`](Self::glyphs) says why and what step 3 offers).
    pub missing: Vec<char>,
    /// Step 3's characters and candidates (docs/ARCHITECTURE.md §6.7): drawn provisionally in
    /// the closest candidate until [`Engine::choose_font`] or [`Engine::keep_as_is`], or not
    /// drawn at all (then [`missing`](Self::missing) lists them).
    pub glyphs: Option<MissingGlyphInfo>,
    /// The substitutions the applied text makes (steps 2 and 3).
    pub substitutions: Vec<FontSubstitution>,
    /// Whether a line of a left-aligned block rewritten line by line runs past its frame.
    pub overflowing: bool,
    /// The overflow choices with their amounts, when the reflowed text needs more lines than
    /// the frame holds (docs/ARCHITECTURE.md §6.8).
    pub overflow: Option<OverflowPlan>,
    /// The choice the preview shows and a commit keeps: [`Choice::Keep`] until
    /// [`Engine::resolve_overflow`] picks another.
    pub chosen: Option<Choice>,
    /// The table cells whose values likely depend on the edited one (a3-9): the UI tints them
    /// and says "Totals don't update"; the engine never changes them.
    pub dependents: Vec<DependentCell>,
    /// The block's language tag as a commit leaves it: the one [`Engine::set_block_language`]
    /// asked for, else the block's own, else the document's.
    pub language: Option<String>,
}

/// The overflow choice the open transaction has written, to write again with its new language.
fn open_choice(open: Option<&Open>) -> Option<Choice> {
    open.and_then(|open| open.chosen)
}

/// Characters step 3 draws, or waits for a choice for.
#[derive(Debug, Clone, PartialEq)]
pub struct MissingGlyphInfo {
    /// Each missing character and its offset in the new text, in UTF-16 code units, in text
    /// order.
    pub chars: Vec<(char, u32)>,
    /// The font they are missing from, its PostScript name without the subset tag.
    pub font: String,
    /// Why the same font did not draw them (step 2).
    pub reason: MissingReason,
    /// Whether the font is bold or italic, so only fonts of that style are offered.
    pub bold: bool,
    /// See [`bold`](Self::bold).
    pub italic: bool,
    /// The candidates, best first (a3-3b).
    pub candidates: Vec<FontCandidate>,
    /// Whether the first candidate draws them now, provisionally.
    pub drawn: bool,
}

impl MissingGlyphInfo {
    fn new(missing: MissingGlyphs, text: &str, drawn: bool) -> Self {
        let utf16 = |at: usize| {
            u32::try_from(text.get(..at).unwrap_or(text).encode_utf16().count()).unwrap_or(u32::MAX)
        };
        Self {
            chars: missing
                .chars
                .iter()
                .map(|&(c, at)| (c, utf16(at)))
                .collect(),
            font: missing.font,
            reason: missing.reason,
            bold: missing.bold,
            italic: missing.italic,
            candidates: missing.candidates,
            drawn,
        }
    }
}

/// A substitution with whether the UI has been told of its font already.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FontSubstitution {
    /// The substitution.
    pub substitution: Substitution,
    /// Whether an earlier commit of this document named the same font in the same step: the
    /// notice (step 2, a3-17) or the toast (a11-6) is said once.
    pub announced: bool,
}

/// Where the fonts for missing glyphs come from (docs/ARCHITECTURE.md §6.7).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct FontSettings {
    /// The fonts bundled with the app (IBM Plex and the similar fonts of a3-3b).
    pub bundled_dir: Option<PathBuf>,
    /// Directories whose fonts count as installed, besides the system's.
    pub font_dirs: Vec<PathBuf>,
    /// Whether the fonts installed on this computer are used (off in tests, so they never
    /// depend on the machine's fonts).
    pub system_fonts: bool,
    /// "Ask each time" (a11-1c): step 3 waits for a choice instead of drawing the closest
    /// candidate.
    pub ask_each_time: bool,
    /// "Keep the original font and mark the character" (a11-1c): step 3 keeps the characters in
    /// their font without a glyph.
    pub mark_missing: bool,
    /// Reflow while typing turned off (a11-1c): only a line feed ends a line.
    pub keep_lines: bool,
}

/// The engine's font settings and the library built from them, shared by the actors.
#[derive(Debug, Default)]
pub(super) struct Fonts {
    state: Mutex<(FontSettings, Option<Arc<FontLibrary>>)>,
}

impl Fonts {
    pub(super) fn set(&self, settings: FontSettings) {
        let mut state = self.state.lock().unwrap_or_else(PoisonError::into_inner);
        if state.0 != settings {
            *state = (settings, None);
        }
    }

    /// The library when it is built, and whether to ask each time, mark and keep the lines.
    fn cached(&self) -> (Option<Arc<FontLibrary>>, (bool, bool, bool)) {
        let state = self.state.lock().unwrap_or_else(PoisonError::into_inner);
        let settings = &state.0;
        let flags = (
            settings.ask_each_time,
            settings.mark_missing,
            settings.keep_lines,
        );
        (state.1.clone(), flags)
    }

    /// The library, built now if it is not yet.
    fn library(&self) -> Arc<FontLibrary> {
        let mut state = self.state.lock().unwrap_or_else(PoisonError::into_inner);
        if let Some(library) = &state.1 {
            return Arc::clone(library);
        }
        let settings = &state.0;
        let limits = ScanLimits::default();
        let mut library = FontLibrary::new();
        if let Some(dir) = &settings.bundled_dir {
            library.add_dir(dir, FontOrigin::Bundled, &limits);
        }
        for dir in &settings.font_dirs {
            library.add_dir(dir, FontOrigin::Installed, &limits);
        }
        if settings.system_fonts {
            library.add_system_fonts(&limits);
        }
        let library = Arc::new(library);
        state.1 = Some(Arc::clone(&library));
        library
    }
}

/// A table cell that likely depends on the edited one.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DependentCell {
    /// Its block.
    pub id: BlockId,
    /// Its frame, `[left, top, right, bottom]` in page space.
    pub frame: CharBox,
}

/// The confirmation of the first change to a signed document (a3-16a, "Edit anyway"), for one
/// document until it closes. The engine holds it: the calls it allows do not take it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ConfirmationToken(u64);

impl ConfirmationToken {
    /// The raw value, for the UI.
    #[must_use]
    pub fn get(self) -> u64 {
        self.0
    }
}

/// Where the document's history stands after a commit, rollback, undo or redo.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RevisionInfo {
    /// How many steps of the history apply: 0 is the document as opened.
    pub current: u32,
    /// The pages' new render key when the render thread reloaded the revised document; `None`
    /// when nothing it shows changed, or it could not reload.
    pub render_key: Option<u64>,
    /// The substitutions the commit made, for the "Font substituted" toast (a11-6); empty after
    /// anything else.
    pub substitutions: Vec<FontSubstitution>,
}

/// One committed step of the history.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HistoryStep {
    /// Its name as the UI gave it at commit.
    pub name: String,
    /// When it was committed, in milliseconds since the Unix epoch.
    pub time: i64,
    /// The lines Keep and warn left hidden past the block's frame: the warning the review list
    /// and the page thumbnail show (a3-12); 0 for none.
    pub hidden_lines: u32,
    /// The characters it set in another font than their line's (a3-12's font rows).
    pub substitutions: Vec<Substitution>,
    /// The page of the block it changed; `None` for a revert and a restored step.
    pub page: Option<u32>,
    /// The block's text before it, for the review list (a3-12); empty for a revert and a
    /// restored step.
    pub before: String,
    /// The block's text after it; see `before`.
    pub after: String,
    /// The steps this one reverted, by index; empty for an edit.
    pub reverts: Vec<u32>,
}

/// The document's history for the Undo history panel (a3-10).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct History {
    /// Every committed step, oldest first: those before `current` apply, the rest can be redone.
    pub steps: Vec<HistoryStep>,
    /// How many steps apply.
    pub current: u32,
    /// Whether the document as it stands no longer matches its signatures: the signature row of
    /// the review list (a3-12, G42), named from the open result's signatures.
    pub signature_invalidated: bool,
}

/// What [`Engine::revert`] did.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Reverted {
    /// Whether the step was reverted; `false` when later steps depend on it and were not asked
    /// to go with it, and the history is as it was.
    pub reverted: bool,
    /// The steps that depend on it, by index, oldest first.
    pub dependents: Vec<u32>,
    /// Where the history stands.
    pub revision: RevisionInfo,
}

/// A message to an actor: a call to run on its session.
type Job = Box<dyn FnOnce(&mut Session) + Send>;

/// An actor's mailbox. Dropping it ends the thread after the job it is running.
#[derive(Debug)]
pub(super) struct Actor(mpsc::Sender<Job>);

/// Where a save writes.
pub(super) enum SaveTarget {
    /// The document's file; `over_change` saves over a file that changed on disk ("Keep mine").
    File { over_change: bool },
    /// Another file, which later saves write to.
    As(PathBuf),
    /// Another file, while later saves still write to the document's.
    Copy(PathBuf),
}

/// What a finished write changes in the session.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Written {
    /// The file at the path holds the current revision, and later saves write to it.
    Saved,
    /// The same, written whole, so later saves rewrite it too (Optimize and clean).
    Rewritten,
    /// The document's own file changed but holds other bytes (a repaired copy over it).
    Stamped,
    /// Another file: nothing.
    Elsewhere,
}

/// A write whose verified temp file waits for the platform layer's swap ([`Engine::finish_save`]).
struct Staged {
    staged: PathBuf,
    path: PathBuf,
    stamp: FileStamp,
    written: Written,
    revision: usize,
}

/// Whether `a` and `b` name the same file, links resolved. On Unix the file's identity decides:
/// macOS's `realpath` keeps the case it is given, so `A.PDF` and `a.pdf` on a volume that ignores
/// case resolve to two paths, and an "other" path could replace the document's own file.
fn same_file(a: &Path, b: &Path) -> bool {
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt as _;
        if let (Ok(a), Ok(b)) = (std::fs::metadata(a), std::fs::metadata(b)) {
            return (a.dev(), a.ino()) == (b.dev(), b.ino());
        }
    }
    let resolve = |path: &Path| std::fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    resolve(a) == resolve(b)
}

/// The revised bytes for the render thread: the serial of the publish and what follows the
/// original bytes.
type Reload = Option<(u64, Arc<[u8]>)>;

/// The transaction ids handed out; 0 is never one.
static NEXT_TRANSACTION: AtomicU64 = AtomicU64::new(1);

/// The confirmation tokens handed out.
static NEXT_CONFIRMATION: AtomicU64 = AtomicU64::new(1);

/// An actor's state: one document's revisions and its open transaction.
pub(super) struct Session {
    model: Arc<Model>,
    /// The committed revisions, the store the model's snapshot shares.
    committed: Arc<RevisionStore>,
    open: Option<Open>,
    steps: Vec<HistoryStep>,
    /// The frame each step's block had before it, by step: what a later edit depends on
    /// (a3-12b).
    frames: Vec<Option<[f32; 4]>>,
    /// Where Save writes.
    path: PathBuf,
    /// The file at `path` as it was opened or last saved.
    stamp: FileStamp,
    /// Whether Optimize and clean rewrote the file, so later saves rewrite it too.
    rewritten: bool,
    fonts: Arc<Fonts>,
    /// The fonts the UI has been told of, by step and name.
    announced: Vec<(SubstitutionKind, String)>,
    /// The revision the file at `path` holds; `None` once a commit replaced it in the history.
    saved: Option<usize>,
    /// The recovery switch and the running session, shared by the actors.
    recovery_config: Arc<Recovery>,
    /// The document's recovery files, from its first unsaved change (docs/ARCHITECTURE.md
    /// §7.6).
    recovery: Option<DocumentRecovery>,
    /// Whether the last recovery write failed, so no copy holds every unsaved change.
    recovery_failed: bool,
    /// The confirmation of the first change to a signed document.
    confirmation: Option<ConfirmationToken>,
    /// The write waiting for its swap.
    staged: Option<Staged>,
}

/// The open transaction.
struct Open {
    id: TransactionId,
    page: usize,
    /// The block as the committed revision lays it out.
    block: TextBlock,
    /// The committed revisions with the newest text in an open transaction, once one applied.
    working: Option<RevisionStore>,
    /// The page's blocks, which may block Extend.
    others: Vec<TextBlock>,
    dependents: Vec<DependentCell>,
    /// The newest text applied, and its overflow choices, the choice written and hidden lines.
    text: Option<String>,
    overflow: Option<OverflowPlan>,
    chosen: Option<Choice>,
    hidden: usize,
    /// The newest text asked for, applied or not.
    requested: Option<String>,
    /// The language tag asked for, written as `/Lang` around the block's operators.
    language: Option<String>,
    /// The step 3 choice made in this transaction.
    font_choice: Option<FontChoice>,
    /// The style the panel set in this transaction (a3-2).
    style: BlockStyle,
    /// The applied text's step 3 characters drawn without a choice, and its substitutions.
    pending: Option<MissingGlyphs>,
    substitutions: Vec<Substitution>,
}

impl Session {
    #[cfg(test)]
    pub(super) fn new(model: Arc<Model>) -> Self {
        Self::with_engine(model, Arc::default(), Arc::default())
    }

    pub(super) fn with_engine(
        model: Arc<Model>,
        fonts: Arc<Fonts>,
        recovery_config: Arc<Recovery>,
    ) -> Self {
        let committed = Arc::clone(&model.revised().store);
        let path = model.path.clone();
        let stamp = model.stamp.clone();
        let recovery = model
            .recovery
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .take();
        // A restored document starts with its unsaved revision as one step, named by the UI.
        let steps = (0..committed.current())
            .map(|_| HistoryStep {
                name: String::new(),
                time: now_millis(),
                hidden_lines: 0,
                substitutions: Vec::new(),
                page: None,
                before: String::new(),
                after: String::new(),
                reverts: Vec::new(),
            })
            .collect();
        Self {
            model,
            committed,
            open: None,
            steps,
            frames: Vec::new(),
            path,
            stamp,
            rewritten: false,
            fonts,
            announced: Vec::new(),
            saved: Some(0),
            recovery_config,
            recovery,
            recovery_failed: false,
            confirmation: None,
            staged: None,
        }
    }

    /// Whether the document holds signatures a change would invalidate.
    fn signed(&self) -> bool {
        self.model.document.structure().signed()
    }

    /// Fails while a signed document waits for its confirmation.
    fn confirmed(&self) -> Result<(), ApiError> {
        if self.signed() && self.confirmation.is_none() {
            return Err(ApiError::new(
                ErrorKind::ConfirmationRequired,
                MessageKey::INTERNAL,
            ));
        }
        Ok(())
    }

    /// The document's confirmation, made with the first call.
    fn confirm(&mut self) -> ConfirmationToken {
        *self.confirmation.get_or_insert_with(|| {
            ConfirmationToken(NEXT_CONFIRMATION.fetch_add(1, Ordering::Relaxed))
        })
    }

    fn context(&self) -> EditContext {
        EditContext {
            document: self.model.read_only,
            ..EditContext::default()
        }
    }

    fn page_index(&self, page: u32) -> Result<usize, ApiError> {
        usize::try_from(page)
            .ok()
            .filter(|&index| index < self.model.document.page_count())
            .ok_or_else(|| {
                ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                    .with_details("no such page")
            })
    }

    pub(super) fn begin(&mut self, page: u32, block: BlockId) -> Result<TransactionId, ApiError> {
        if self.open.is_some() {
            return Err(CoreError::Write(WriteError::TransactionOpen).into());
        }
        if let Some(reason) = self.model.read_only {
            return Err(ApiError::not_editable(reason));
        }
        if self
            .model
            .security()
            .is_some_and(|security| security.restricted())
        {
            return Err(ApiError::not_editable(NotEditableReason::Restricted));
        }
        let index = self.page_index(page)?;
        let text = ferman_text::text_page_revised(
            &self.model.document,
            &self.committed,
            index,
            &self.context(),
        )?;
        let dependents = ferman_text::dependent_cells(&text, block)
            .into_iter()
            .filter_map(|id| {
                let cell = text.blocks.iter().find(|candidate| candidate.id == id)?;
                Some(DependentCell {
                    id,
                    frame: cell.bbox,
                })
            })
            .collect();
        let block = text
            .blocks
            .iter()
            .find(|candidate| candidate.id == block)
            .cloned()
            .ok_or_else(|| {
                ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
                    .with_details("no such block")
            })?;
        if let Editability::NotEditable(reason) = block.editability {
            return Err(ApiError::not_editable(reason));
        }
        let id = TransactionId(NEXT_TRANSACTION.fetch_add(1, Ordering::Relaxed));
        self.open = Some(Open {
            id,
            page: index,
            block,
            working: None,
            others: text.blocks,
            dependents,
            text: None,
            overflow: None,
            chosen: None,
            hidden: 0,
            requested: None,
            language: None,
            font_choice: None,
            style: BlockStyle::default(),
            pending: None,
            substitutions: Vec::new(),
        });
        Ok(id)
    }

    fn open(&mut self, transaction: TransactionId) -> Result<&mut Open, ApiError> {
        self.open
            .as_mut()
            .filter(|open| open.id == transaction)
            .ok_or_else(|| {
                ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
                    .with_details("no such transaction")
            })
    }

    pub(super) fn apply(
        &mut self,
        transaction: TransactionId,
        text: &str,
    ) -> Result<EditPreview, ApiError> {
        self.write(transaction, text, None)
    }

    pub(super) fn resolve_overflow(
        &mut self,
        transaction: TransactionId,
        choice: Choice,
    ) -> Result<EditPreview, ApiError> {
        let open = self.open(transaction)?;
        let disabled = || {
            ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details("that overflow choice is not available")
        };
        let plan = open.overflow.as_ref().ok_or_else(disabled)?;
        let available = match choice {
            Choice::Extend => plan.extend.is_ok(),
            Choice::Tighten => plan.tighten.is_ok(),
            Choice::Keep => true,
        };
        let text = open
            .text
            .clone()
            .filter(|_| available)
            .ok_or_else(disabled)?;
        self.write(transaction, &text, Some(choice))
    }

    /// Writes `tag` as the block's language, with the newest text asked for or the block's own.
    pub(super) fn set_block_language(
        &mut self,
        transaction: TransactionId,
        tag: String,
    ) -> Result<EditPreview, ApiError> {
        if !ferman_text::valid_language_tag(&tag) {
            return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details("not a language tag"));
        }
        let open = self.open(transaction)?;
        open.language = Some(tag);
        let text = open.requested.clone().unwrap_or_else(|| open.block.text());
        self.write(transaction, &text, open_choice(self.open.as_ref()))
    }

    /// Draws step 3's characters in the candidate `postscript_name` of `origin` and returns
    /// the page as it would read.
    pub(super) fn choose_font(
        &mut self,
        transaction: TransactionId,
        origin: FontOrigin,
        postscript_name: String,
    ) -> Result<EditPreview, ApiError> {
        self.write_choice(
            transaction,
            FontChoice::Font {
                origin,
                postscript_name,
            },
        )
    }

    /// Keeps step 3's characters in the closest candidate ("Keep as is").
    pub(super) fn keep_as_is(
        &mut self,
        transaction: TransactionId,
    ) -> Result<EditPreview, ApiError> {
        self.write_choice(transaction, FontChoice::KeepAsIs)
    }

    /// Writes the newest text asked for again with the step 3 choice `choice`; a choice that
    /// cannot draw it is refused and the one before stays.
    fn write_choice(
        &mut self,
        transaction: TransactionId,
        choice: FontChoice,
    ) -> Result<EditPreview, ApiError> {
        let open = self.open(transaction)?;
        let refused = || {
            ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details("no font choice is open, or that font cannot draw the characters")
        };
        let text = open.requested.clone().ok_or_else(refused)?;
        let before = open.font_choice.replace(choice);
        let preview = self.write(transaction, &text, None)?;
        if !preview.missing.is_empty() {
            self.open(transaction)?.font_choice = before;
            return Err(refused());
        }
        Ok(preview)
    }

    /// Writes the transaction's newest text, or the block's own, with `style` over what the
    /// transaction set already. A style that cannot be written is dropped again: the text stays as
    /// it was applied before, and the preview says what a font lacks.
    pub(super) fn set_style(
        &mut self,
        transaction: TransactionId,
        style: BlockStyle,
    ) -> Result<EditPreview, ApiError> {
        if !style.valid() {
            return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details("a block style out of range"));
        }
        let open = self.open(transaction)?;
        let merged = open.style.merged(style);
        let before = std::mem::replace(&mut open.style, merged);
        let text = open
            .requested
            .clone()
            .unwrap_or_else(|| ferman_text::paragraph_text(&open.block));
        let choice = open.chosen;
        let requested = open.requested.clone();
        let written = self.write(transaction, &text, choice);
        let refused = written
            .as_ref()
            .map_or(true, |preview| !preview.missing.is_empty());
        if refused {
            let open = self.open(transaction)?;
            open.style = before;
            open.requested = requested;
        }
        written
    }

    /// Moves the transaction's block by `by` in page space, without changing its size.
    pub(super) fn move_block(
        &mut self,
        transaction: TransactionId,
        by: [f32; 2],
    ) -> Result<EditPreview, ApiError> {
        let open = self.open(transaction)?;
        let [left, top, right, bottom] = open.style.frame.unwrap_or(open.block.bbox);
        let frame = [left + by[0], top + by[1], right + by[0], bottom + by[1]];
        self.set_style(
            transaction,
            BlockStyle {
                frame: Some(frame),
                ..BlockStyle::default()
            },
        )
    }

    /// What the text panel shows of `block` of `page`, as the committed revisions lay it out.
    pub(super) fn block_style(
        &self,
        page: u32,
        block: BlockId,
    ) -> Result<Option<BlockStyleInfo>, ApiError> {
        let (index, found) = self.committed_block(page, block)?;
        let library = self.fonts.library();
        Ok(ferman_text::block_style(
            &self.model.document,
            &self.committed,
            index,
            &found,
            Some(&library),
        )?)
    }

    /// The fonts a3-2's font field offers for `block` of `page`.
    pub(super) fn block_fonts(
        &self,
        page: u32,
        block: BlockId,
    ) -> Result<Vec<FontCandidate>, ApiError> {
        let (index, found) = self.committed_block(page, block)?;
        let library = self.fonts.library();
        Ok(ferman_text::block_fonts(
            &self.model.document,
            &self.committed,
            index,
            &found,
            Some(&library),
        )?)
    }

    fn committed_block(&self, page: u32, block: BlockId) -> Result<(usize, TextBlock), ApiError> {
        let index = self.page_index(page)?;
        let text = ferman_text::text_page_revised(
            &self.model.document,
            &self.committed,
            index,
            &self.context(),
        )?;
        let found = text
            .blocks
            .into_iter()
            .find(|candidate| candidate.id == block)
            .ok_or_else(|| {
                ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
                    .with_details("no such block")
            })?;
        Ok((index, found))
    }

    /// Rewrites the transaction's block to `text` with the overflow choice `choice`.
    fn write(
        &mut self,
        transaction: TransactionId,
        text: &str,
        choice: Option<Choice>,
    ) -> Result<EditPreview, ApiError> {
        let context = self.context();
        let committed = Arc::clone(&self.committed);
        let model = Arc::clone(&self.model);
        let fonts = Arc::clone(&self.fonts);
        let announced = self.announced.clone();
        let document = &model.document;
        let open = self.open(transaction)?;
        open.requested = Some(text.to_owned());
        let (library, (ask, mark, keep_lines)) = fonts.cached();
        let rewrite = |library: Option<&FontLibrary>, open: &Open| {
            ferman_text::rewrite_block_styled(
                document,
                Some(&committed),
                open.page,
                &open.block,
                text,
                &open.others,
                choice,
                &FontSources {
                    library,
                    ask,
                    mark,
                    keep_lines,
                    choice: open.font_choice.as_ref(),
                },
                &open.style,
            )
        };
        let mut outcome = rewrite(library.as_deref(), open)?;
        // The fonts are indexed the first time an edit needs them.
        let fell_back = match &outcome {
            Outcome::MissingGlyphs(_) => true,
            // A font of the page may lend the characters without the library; the installed
            // and bundled fonts are still candidates.
            Outcome::Rewritten(rewrite) => !rewrite.substitutions.is_empty(),
            // Right-to-left text is shaped in the installed or bundled copy of its font.
            Outcome::Unsupported(unsupported) => *unsupported == ferman_text::Unsupported::Shaping,
        };
        if library.is_none() && fell_back {
            let library = fonts.library();
            outcome = rewrite(Some(&library), open)?;
        }
        let (missing, overflowing, glyphs) = match outcome {
            Outcome::Rewritten(rewrite) => {
                let splices = match open
                    .language
                    .as_deref()
                    .filter(|&tag| open.block.language.as_deref() != Some(tag))
                {
                    Some(tag) => ferman_text::with_language(
                        document,
                        Some(&committed),
                        open.page,
                        &open.block,
                        tag,
                        rewrite.splices,
                    )?
                    .map_err(|unsupported| {
                        ApiError::new(ErrorKind::Unsupported, MessageKey::UNSUPPORTED)
                            .with_details(format!("no language written: {unsupported:?}"))
                    })?,
                    None => rewrite.splices,
                };
                let splices: Vec<revision::Splice> = splices
                    .into_iter()
                    .map(|splice| revision::Splice {
                        source: splice.source,
                        range: splice.range,
                        bytes: splice.bytes,
                    })
                    .collect();
                let mut working = (*committed).clone();
                working.begin()?;
                // The font copies and new fonts the new codes need, in the same transaction as
                // the splices that name them, so undo and redo cover both.
                working.add_new_fonts(
                    document,
                    open.page,
                    &rewrite.fonts,
                    &rewrite.simple_fonts,
                    &rewrite.new_fonts,
                )?;
                working.splice(document, open.page, &splices, &[])?;
                open.working = Some(working);
                open.text = Some(text.to_owned());
                open.overflow = rewrite.overflow;
                open.chosen = rewrite.chosen;
                open.hidden = rewrite.hidden;
                let glyphs = rewrite
                    .pending
                    .clone()
                    .map(|pending| MissingGlyphInfo::new(pending, text, true));
                open.pending = rewrite.pending;
                open.substitutions = rewrite.substitutions;
                (Vec::new(), !rewrite.overflowing.is_empty(), glyphs)
            }
            // The text before stays applied, with its overflow choice and substitutions.
            Outcome::MissingGlyphs(missing) => {
                let mut chars: Vec<char> = Vec::new();
                for &(c, _) in &missing.chars {
                    if !chars.contains(&c) {
                        chars.push(c);
                    }
                }
                (
                    chars,
                    false,
                    Some(MissingGlyphInfo::new(missing, text, false)),
                )
            }
            Outcome::Unsupported(unsupported) => {
                return Err(
                    ApiError::new(ErrorKind::Unsupported, MessageKey::UNSUPPORTED)
                        .with_details(format!("not rewritten yet: {unsupported:?}")),
                );
            }
        };
        let revisions = open.working.as_ref().unwrap_or(&committed);
        let page = ferman_text::text_page_revised(document, revisions, open.page, &context)?;
        let substitutions = open
            .substitutions
            .iter()
            .map(|substitution| announce(&announced, substitution))
            .collect();
        Ok(EditPreview {
            page: page_blocks_info(&model, &page),
            missing,
            glyphs,
            substitutions,
            overflowing,
            overflow: open.overflow.clone(),
            chosen: open.chosen,
            dependents: open.dependents.clone(),
            language: open
                .language
                .clone()
                .or_else(|| open.block.language.clone())
                .or_else(|| document.structure().language.clone()),
        })
    }

    pub(super) fn commit(
        &mut self,
        transaction: TransactionId,
        name: String,
    ) -> Result<(u32, Reload, Vec<FontSubstitution>), ApiError> {
        let open = self.open(transaction)?;
        let changed = open.working.is_some();
        if open.pending.is_some() {
            // Never silent: the provisional font waits for choose_font or keep_as_is.
            return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details(PENDING_CHOICE));
        }
        if changed {
            self.confirmed()?;
        }
        let Some(open) = self.open.take() else {
            return Ok((self.current(), None, Vec::new()));
        };
        let (working, hidden, substitutions) = (open.working, open.hidden, open.substitutions);
        let page = u32::try_from(open.page).ok();
        let frame = open.block.bbox;
        let text_before = open.block.text();
        let text_after = open.text.unwrap_or_default();
        let before = self.committed.current();
        let Some(mut working) = working else {
            return Ok((self.current(), None, Vec::new()));
        };
        // A transaction that changed nothing adds no step.
        if working.commit()? == before {
            return Ok((self.current(), None, Vec::new()));
        }
        let told: Vec<FontSubstitution> = substitutions
            .iter()
            .map(|substitution| announce(&self.announced, substitution))
            .collect();
        for substitution in &substitutions {
            let key = (substitution.kind, substitution.to.clone());
            if !self.announced.contains(&key) {
                self.announced.push(key);
            }
        }
        self.steps.truncate(before);
        self.steps.push(HistoryStep {
            name,
            time: now_millis(),
            hidden_lines: u32::try_from(hidden).unwrap_or(u32::MAX),
            substitutions,
            page,
            before: text_before,
            after: text_after,
            reverts: Vec::new(),
        });
        self.frames.resize(before, None);
        self.frames.push(Some(frame));
        self.committed = Arc::new(working);
        self.journal(Change::Commit);
        Ok((self.current(), self.publish(), told))
    }

    /// The edits that still count: applied, not reverted, and not a revert themselves.
    fn live_steps(&self) -> Vec<usize> {
        let applied = self
            .steps
            .get(..self.committed.current())
            .unwrap_or_default();
        let gone: Vec<u32> = applied
            .iter()
            .flat_map(|step| step.reverts.iter().copied())
            .collect();
        applied
            .iter()
            .enumerate()
            .filter(|(index, step)| {
                step.reverts.is_empty()
                    && u32::try_from(*index).is_ok_and(|index| !gone.contains(&index))
            })
            .map(|(index, _)| index)
            .collect()
    }

    /// Whether `later` builds on `earlier` whatever their bytes say: it changed the same block,
    /// or `earlier` added resources to the page that `later`'s text may draw with.
    fn builds_on(&self, later: usize, earlier: usize) -> bool {
        let (Some(a), Some(b)) = (self.steps.get(earlier), self.steps.get(later)) else {
            return false;
        };
        // A restored step does not know its page, so it may be `later`'s.
        if a.page.is_some() && b.page.is_some() && a.page != b.page {
            return false;
        }
        let frame = |step: usize| self.frames.get(step).copied().flatten();
        let overlapping = matches!((frame(earlier), frame(later)), (Some(a), Some(b))
            if a[0] < b[2] && b[0] < a[2] && a[1] < b[3] && b[1] < a[3]);
        overlapping
            || !self
                .committed
                .revisions()
                .get(earlier)
                .is_some_and(ferman_core::revision::ChangeSet::streams_only)
    }

    /// `set`, the steps to revert, grown by every live step that depends on one of them, and the
    /// open transaction that reverts them all. Bytes that cannot be taken out name the later
    /// step sharing the object.
    fn revert_plan(
        &self,
        mut set: Vec<usize>,
        live: &[usize],
    ) -> Result<(Vec<usize>, RevisionStore), ApiError> {
        loop {
            for &later in live {
                if !set.contains(&later)
                    && set
                        .iter()
                        .any(|&step| later > step && self.builds_on(later, step))
                {
                    set.push(later);
                }
            }
            set.sort_unstable();
            let mut working = (*self.committed).clone();
            working.begin()?;
            let mut stuck = None;
            for &step in set.iter().rev() {
                if !working.revert_revision(&self.model.document, step)? {
                    stuck = Some(step);
                    break;
                }
            }
            let Some(stuck) = stuck else {
                return Ok((set, working));
            };
            let revisions = self.committed.revisions();
            let shares = |later: usize| {
                let (Some(a), Some(b)) = (revisions.get(stuck), revisions.get(later)) else {
                    return false;
                };
                a.ids().any(|id| b.ids().any(|other| other == id))
            };
            let next = live
                .iter()
                .copied()
                .find(|&later| later > stuck && !set.contains(&later) && shares(later))
                .ok_or_else(|| {
                    ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                        .with_details("a later change holds this step's bytes")
                })?;
            set.push(next);
        }
    }

    /// Commits `working`, which reverts `reverts`, as the step `name`.
    fn commit_revert(
        &mut self,
        mut working: RevisionStore,
        name: String,
        reverts: Vec<u32>,
    ) -> Result<(u32, Reload), ApiError> {
        let before = self.committed.current();
        working.commit()?;
        self.steps.truncate(before);
        self.steps.push(HistoryStep {
            name,
            time: now_millis(),
            hidden_lines: 0,
            substitutions: Vec::new(),
            page: None,
            before: String::new(),
            after: String::new(),
            reverts,
        });
        self.frames.resize(before, None);
        self.frames.push(None);
        self.committed = Arc::new(working);
        self.journal(Change::Commit);
        Ok((self.current(), self.publish()))
    }

    /// Reverts `step` alone as a new step `name`, which Undo takes back. With later steps that
    /// depend on it, they go too if `with_dependents`; otherwise nothing changes and the
    /// dependents come back (G42): both, or neither.
    pub(super) fn revert(
        &mut self,
        step: u32,
        with_dependents: bool,
        name: String,
    ) -> Result<(bool, Vec<u32>, u32, Reload), ApiError> {
        self.closed()?;
        self.confirmed()?;
        let live = self.live_steps();
        let index = usize::try_from(step)
            .ok()
            .filter(|index| live.contains(index))
            .ok_or_else(|| {
                ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                    .with_details("that step does not apply")
            })?;
        let (set, working) = self.revert_plan(vec![index], &live)?;
        let all: Vec<u32> = set
            .iter()
            .filter_map(|&step| u32::try_from(step).ok())
            .collect();
        let dependents: Vec<u32> = all.iter().copied().filter(|&other| other != step).collect();
        if !dependents.is_empty() && !with_dependents {
            return Ok((false, dependents, self.current(), None));
        }
        let (current, reload) = self.commit_revert(working, name, all)?;
        Ok((true, dependents, current, reload))
    }

    /// Takes the document back to how it opened as a new step `name`, which Undo takes back.
    pub(super) fn revert_all(&mut self, name: String) -> Result<(u32, Reload), ApiError> {
        self.closed()?;
        self.confirmed()?;
        let live = self.live_steps();
        if live.is_empty() {
            return Ok((self.current(), None));
        }
        let mut working = (*self.committed).clone();
        working.begin()?;
        working.revert_all(&self.model.document)?;
        let reverts = live
            .iter()
            .filter_map(|&step| u32::try_from(step).ok())
            .collect();
        self.commit_revert(working, name, reverts)
    }

    pub(super) fn rollback(&mut self, transaction: TransactionId) -> Result<u32, ApiError> {
        self.open(transaction)?;
        self.open = None;
        Ok(self.current())
    }

    pub(super) fn undo(&mut self) -> Result<(u32, Reload), ApiError> {
        self.closed()?;
        Arc::make_mut(&mut self.committed).undo()?;
        self.journal(Change::Move);
        Ok((self.current(), self.publish()))
    }

    pub(super) fn redo(&mut self) -> Result<(u32, Reload), ApiError> {
        self.closed()?;
        Arc::make_mut(&mut self.committed).redo()?;
        self.journal(Change::Move);
        Ok((self.current(), self.publish()))
    }

    pub(super) fn history(&self) -> History {
        History {
            steps: self.steps.clone(),
            current: self.current(),
            signature_invalidated: self.signed() && (self.current() > 0 || self.rewritten),
        }
    }

    /// The document's bytes with the committed revisions as an incremental update.
    pub(super) fn bytes(&self) -> Result<Vec<u8>, ApiError> {
        Ok(self.committed.incremental_update(&self.model.document)?)
    }

    /// A save failure as the app gets it.
    fn save_failure(&self, err: CoreError) -> ApiError {
        self.unwritten(ApiError::from(err).of_save())
    }

    /// A save that stopped before writing, as the app gets it: says when no recovery copy exists.
    fn unwritten(&self, err: impl Into<ApiError>) -> ApiError {
        let mut err = err.into();
        err.no_recovery_copy = self.recovery_failed;
        err
    }

    /// Writes `bytes` as the file at `path`, checking the document's stamp with `check`: at once,
    /// or with `staging` as far as the swap, whose staged path it returns.
    fn put(
        &mut self,
        path: PathBuf,
        (bytes, original): (&[u8], Option<&[u8]>),
        check: bool,
        staging: Option<&Path>,
        written: Written,
    ) -> Result<Option<PathBuf>, ApiError> {
        let expected = check.then_some(&self.stamp);
        let revision = self.committed.current();
        let Some(staging) = staging else {
            let stamp = ferman_core::save::save_pdf(&path, bytes, original, expected)
                .map_err(|err| self.save_failure(err))?;
            self.wrote(path, stamp, written, revision);
            return Ok(None);
        };
        let (staged, stamp) =
            ferman_core::save::stage_pdf(&path, staging, bytes, original, expected)
                .map_err(|err| self.save_failure(err))?;
        if let Some(earlier) = self.staged.take() {
            let _ = std::fs::remove_file(earlier.staged);
        }
        self.staged = Some(Staged {
            staged: staged.clone(),
            path,
            stamp,
            written,
            revision,
        });
        Ok(Some(staged))
    }

    /// What a write that reached `path` changes.
    fn wrote(&mut self, path: PathBuf, stamp: FileStamp, written: Written, revision: usize) {
        match written {
            Written::Elsewhere => {}
            Written::Stamped => self.stamp = stamp,
            Written::Saved | Written::Rewritten => {
                self.path = path;
                self.stamp = stamp;
                self.rewritten |= written == Written::Rewritten;
                self.saved_now(revision);
            }
        }
    }

    /// Ends the staged write after the platform layer's swap: `swapped`, it counts as written;
    /// otherwise the document is as it was and the staged file goes. Whether the last recovery
    /// write failed, which the app's failure dialog says.
    pub(super) fn finish_save(&mut self, swapped: bool) -> Result<bool, ApiError> {
        let staged = self.staged.take().ok_or_else(|| {
            ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details("no save waits for its swap")
        })?;
        if swapped {
            let stamp = staged.stamp.settled(&staged.path);
            self.wrote(staged.path, stamp, staged.written, staged.revision);
        } else {
            let _ = std::fs::remove_file(staged.staged);
        }
        Ok(self.recovery_failed)
    }

    /// Writes the committed revisions as `target` says. An open transaction is not saved.
    pub(super) fn save(
        &mut self,
        target: SaveTarget,
        staging: Option<&Path>,
    ) -> Result<Option<PathBuf>, ApiError> {
        let own_file = match &target {
            SaveTarget::File { .. } => true,
            SaveTarget::As(path) | SaveTarget::Copy(path) => same_file(path, &self.path),
        };
        // The unchanged file copied elsewhere keeps its signature valid.
        if own_file || self.committed.current() > 0 || self.rewritten {
            self.confirmed()?;
        }
        let (path, check, moves) = match target {
            SaveTarget::File { over_change } => (self.path.clone(), !over_change, true),
            SaveTarget::As(path) => {
                let same = same_file(&path, &self.path);
                (path, same, true)
            }
            // A copy over the document's own file is a save of it.
            SaveTarget::Copy(path) => {
                let same = same_file(&path, &self.path);
                (path, same, same)
            }
        };
        let model = Arc::clone(&self.model);
        let (bytes, original) = if self.rewritten {
            (
                self.committed
                    .full_rewrite(&model.document)
                    .map_err(|err| self.unwritten(err))?,
                None,
            )
        } else {
            let original: &[u8] = model.document.source().bytes();
            (
                self.bytes().map_err(|err| self.unwritten(err))?,
                Some(original),
            )
        };
        let written = if moves {
            Written::Saved
        } else {
            Written::Elsewhere
        };
        self.put(path, (&bytes, original), check, staging, written)
    }

    /// Optimize and clean: the document's file rewritten whole (docs/ARCHITECTURE.md §7.3).
    pub(super) fn optimize_and_clean(
        &mut self,
        staging: Option<&Path>,
    ) -> Result<Option<PathBuf>, ApiError> {
        self.confirmed()?;
        if self.model.document.repair().is_some() {
            return Err(CoreError::Write(WriteError::Repaired).into());
        }
        let bytes = self
            .committed
            .full_rewrite(&self.model.document)
            .map_err(|err| self.unwritten(err))?;
        let path = self.path.clone();
        self.put(path, (&bytes, None), true, staging, Written::Rewritten)
    }

    /// A repaired document rewritten whole as the file at `path`; its own file only with
    /// `replace_original` (ADR 0008).
    pub(super) fn save_repaired_copy(
        &mut self,
        path: &Path,
        replace_original: bool,
        staging: Option<&Path>,
    ) -> Result<Option<PathBuf>, ApiError> {
        self.confirmed()?;
        let original = same_file(path, &self.path);
        if original && !replace_original {
            return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details("replacing the damaged original needs its confirmation"));
        }
        let bytes = self
            .committed
            .full_rewrite(&self.model.document)
            .map_err(|err| self.unwritten(err))?;
        let written = if original {
            Written::Stamped
        } else {
            Written::Elsewhere
        };
        self.put(path.to_owned(), (&bytes, None), original, staging, written)
    }

    /// The working copy of "Edit a copy": the committed revisions rewritten whole and unsigned
    /// as the file at `path`, never the document's own file. The document does not move.
    pub(super) fn save_unsigned_copy(
        &mut self,
        path: &Path,
        staging: Option<&Path>,
    ) -> Result<Option<PathBuf>, ApiError> {
        if same_file(path, &self.path) {
            return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details("the unsigned copy cannot replace the signed original"));
        }
        let bytes = self
            .committed
            .without_signatures(&self.model.document)
            .map_err(|err| self.unwritten(err))?;
        self.put(
            path.to_owned(),
            (&bytes, None),
            false,
            staging,
            Written::Elsewhere,
        )
    }

    /// Whether the document's file changed on disk since it was opened or saved.
    pub(super) fn external_change(&self) -> Result<bool, ApiError> {
        // A swap in progress is this document's own write; the next check sees anyone else's.
        if self.staged.is_some() {
            return Ok(false);
        }
        Ok(self.stamp.changed(&self.path)?)
    }

    /// Records the change that made the current revision in the recovery files, made with the
    /// first unsaved change; with the switch off (a11-1c) or no session there are none. A
    /// recovery write that fails is logged and never fails the edit.
    fn journal(&mut self, change: Change) {
        if change == Change::Commit
            && self
                .saved
                .is_some_and(|saved| self.committed.current() <= saved)
        {
            self.saved = None;
        }
        let Some(session) = self.recovery_config.session() else {
            self.discard_recovery();
            return;
        };
        if self.recovery.is_none() {
            match DocumentRecovery::new(&session, self.path.clone(), self.stamp.clone(), self.saved)
            {
                Ok(recovery) => self.recovery = Some(recovery),
                Err(err) => {
                    tracing::warn!(error = %err, "no recovery files");
                    self.recovery_failed = true;
                }
            }
        }
        if let Some(recovery) = &mut self.recovery {
            // A record after a failed one holds every unsaved object.
            self.recovery_failed = recovery
                .record(
                    &self.model.document,
                    &self.committed,
                    change,
                    Instant::now(),
                )
                .inspect_err(|err| {
                    tracing::warn!(error = %err, "the recovery journal could not be written");
                })
                .is_err();
        }
    }

    /// The actor's tick, about once a second: syncs the journal and writes the minute's
    /// snapshot; deletes the files once the switch is off.
    pub(super) fn tick(&mut self) {
        if self.recovery_config.session().is_none() {
            self.discard_recovery();
            return;
        }
        if let Some(recovery) = &mut self.recovery
            && let Err(err) = recovery.tick(&self.model.document, &self.committed, Instant::now())
        {
            tracing::warn!(error = %err, "the recovery journal could not be written");
            self.recovery_failed = true;
        }
    }

    /// Deletes the recovery files ("Don't save", or the switch turned off).
    pub(super) fn discard_recovery(&mut self) {
        self.recovery_failed = false;
        if let Some(mut recovery) = self.recovery.take()
            && let Err(err) = recovery.clear()
        {
            tracing::warn!(error = %err, "the recovery files could not be deleted");
        }
    }

    /// After a save of revision `saved` to `path`: its recovery files go.
    fn saved_now(&mut self, saved: usize) {
        self.saved = Some(saved);
        self.recovery_failed = false;
        if let Some(recovery) = &mut self.recovery
            && let Err(err) = recovery.saved(saved, self.path.clone(), self.stamp.clone())
        {
            tracing::warn!(error = %err, "the recovery files could not be deleted");
        }
    }

    fn closed(&self) -> Result<(), ApiError> {
        if self.open.is_some() {
            return Err(CoreError::Write(WriteError::TransactionOpen).into());
        }
        Ok(())
    }

    pub(super) fn current(&self) -> u32 {
        u32::try_from(self.committed.current()).unwrap_or(u32::MAX)
    }

    /// Publishes the committed revisions for the readers and returns the revised bytes for the
    /// render thread, or `None` when they cannot be written (logged).
    pub(super) fn publish(&self) -> Reload {
        let serial = {
            let mut revised = self.model.revised();
            revised.store = Arc::clone(&self.committed);
            revised.generation = revised.generation.saturating_add(1);
            revised.blocks.fill(None);
            revised.generation
        };
        // shortcut: the whole file is built to cut off its update; build the update alone when
        // large files make edits slow.
        match self.bytes() {
            Ok(bytes) => {
                let original = self.model.document.source().len();
                Some((serial, Arc::from(bytes.get(original..).unwrap_or_default())))
            }
            Err(err) => {
                tracing::warn!(error = %err, "the revised bytes could not be built");
                None
            }
        }
    }
}

/// Now, in milliseconds since the Unix epoch.
fn now_millis() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .ok()
        .and_then(|since| i64::try_from(since.as_millis()).ok())
        .unwrap_or(0)
}

/// The details of the error a commit gets while a step 3 choice is pending.
const PENDING_CHOICE: &str = "a font choice is pending: choose a font or keep as is";

/// `substitution` with whether `announced` names its font.
fn announce(
    announced: &[(SubstitutionKind, String)],
    substitution: &Substitution,
) -> FontSubstitution {
    FontSubstitution {
        substitution: substitution.clone(),
        announced: announced.contains(&(substitution.kind, substitution.to.clone())),
    }
}

impl Engine {
    /// Sets where the fonts for missing glyphs come from, and "Ask each time"; the fonts are
    /// indexed again the next time an edit needs them.
    ///
    /// # Errors
    ///
    /// Returns an internal error only if the call panics.
    pub async fn set_font_settings(&self, settings: FontSettings) -> Result<(), ApiError> {
        guard_async(async move {
            self.fonts.set(settings);
            Ok(())
        })
        .await
    }

    /// Draws the characters step 3 offers candidates for in the candidate `postscript_name` of
    /// `origin` (a3-3b), and returns the page as it would read; the choice holds for the rest of
    /// the transaction.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open, and `InvalidInput` when no text
    /// waits for a font or the font cannot draw every character.
    pub async fn choose_font(
        &self,
        transaction: TransactionId,
        origin: FontOrigin,
        postscript_name: String,
    ) -> Result<EditPreview, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            self.ask(document, move |session| {
                session.choose_font(transaction, origin, postscript_name)
            })
            .await
        })
        .await
    }

    /// Sets the language of the transaction's block to the tag `tag` (a3-14), written as `/Lang`
    /// on marked content around its operators, which draws nothing, and returns the page as it
    /// would read; the transaction stays open, and a commit makes it one step with its text.
    ///
    /// # Errors
    ///
    /// `NotFound` for a transaction that is not open, `InvalidInput` for a tag that is not one,
    /// `Unsupported` for a block drawn in a way that cannot be marked.
    pub async fn set_block_language(
        &self,
        transaction: TransactionId,
        tag: String,
    ) -> Result<EditPreview, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            self.ask(document, move |session| {
                session.set_block_language(transaction, tag)
            })
            .await
        })
        .await
    }

    /// Keeps the characters step 3 drew provisionally in the closest candidate ("Keep as is"),
    /// or draws them in it after "Ask each time", and returns the page as it would read.
    ///
    /// # Errors
    ///
    /// As [`choose_font`](Self::choose_font).
    pub async fn keep_as_is(&self, transaction: TransactionId) -> Result<EditPreview, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            self.ask(document, move |session| session.keep_as_is(transaction))
                .await
        })
        .await
    }

    /// Opens a transaction that edits `block` of `page` of `document`.
    ///
    /// # Errors
    ///
    /// Returns `NotEditable` with the reason for a block or a document that cannot be edited,
    /// `InvalidInput` while another transaction of the document is open or for a page it does
    /// not have, and `NotFound` for a document that is not open or a block the page does not
    /// have.
    pub async fn begin_edit(
        &self,
        document: DocumentId,
        page: u32,
        block: BlockId,
    ) -> Result<TransactionId, ApiError> {
        guard_async(async move {
            let transaction = self
                .ask(document, move |session| session.begin(page, block))
                .await?;
            self.transactions
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .insert(transaction, document);
            Ok(transaction)
        })
        .await
    }

    /// Replaces the text of the transaction's block with `text` and returns the page as it
    /// would read. With one piece per line of a left-aligned or justified block, separated by
    /// line feeds, the changed lines are rewritten in place; any other text is laid out again in
    /// the block's frame, a line feed ending a paragraph (a justified line past its frame
    /// reflows the block as one paragraph). When the text needs more lines than the frame
    /// holds, the preview carries the overflow choices and shows Keep and warn, which a commit
    /// keeps unless [`resolve_overflow`](Self::resolve_overflow) picks another choice.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open, `Unsupported` for text the
    /// rewriter cannot write yet (right to left, a line drawn with other operators inside…), or
    /// the error of reading the page.
    pub async fn apply(
        &self,
        transaction: TransactionId,
        text: String,
    ) -> Result<EditPreview, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            self.ask(document, move |session| session.apply(transaction, &text))
                .await
        })
        .await
    }

    /// Writes the newest text of the transaction again with the overflow choice `choice` and
    /// returns the page as it would read; the transaction stays open.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open, and `InvalidInput` when its text
    /// does not overflow or the choice is disabled (Extend into another block or off the page,
    /// Tighten past the cap).
    pub async fn resolve_overflow(
        &self,
        transaction: TransactionId,
        choice: Choice,
    ) -> Result<EditPreview, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            self.ask(document, move |session| {
                session.resolve_overflow(transaction, choice)
            })
            .await
        })
        .await
    }

    /// Gives the transaction's block `style` (a3-2) over what the transaction set already, laid
    /// out again in its frame, and returns the page as it would read. A font that cannot draw the
    /// block leaves it as it was, and the preview names the characters it lacks.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open, `InvalidInput` for numbers out of
    /// range, and `Unsupported` for a style the block cannot take (a vertical block, another font
    /// for right-to-left text or in a form, another box for a turned block).
    pub async fn set_block_style(
        &self,
        transaction: TransactionId,
        style: BlockStyle,
    ) -> Result<EditPreview, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            self.ask(document, move |session| {
                session.set_style(transaction, style)
            })
            .await
        })
        .await
    }

    /// Moves the transaction's block by `by` in page space and returns the page as it would read.
    ///
    /// # Errors
    ///
    /// As [`set_block_style`](Self::set_block_style).
    pub async fn move_block(
        &self,
        transaction: TransactionId,
        by: [f32; 2],
    ) -> Result<EditPreview, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            self.ask(document, move |session| session.move_block(transaction, by))
                .await
        })
        .await
    }

    /// Gives the transaction's block the box `frame` in page space, its text reflowed in it, and
    /// returns the page as it would read. Text that no longer fits comes back with the overflow
    /// choices, as [`apply`](Self::apply) gives them.
    ///
    /// # Errors
    ///
    /// As [`set_block_style`](Self::set_block_style).
    pub async fn resize_block(
        &self,
        transaction: TransactionId,
        frame: CharBox,
    ) -> Result<EditPreview, ApiError> {
        self.set_block_style(
            transaction,
            BlockStyle {
                frame: Some(frame),
                ..BlockStyle::default()
            },
        )
        .await
    }

    /// What the text panel shows of `block` of `page` of `document` (a3-2); `None` for a block
    /// without glyphs on the page.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open or a block the page does not have,
    /// `InvalidInput` for a page it does not have, or the error of reading the page.
    pub async fn block_style(
        &self,
        document: DocumentId,
        page: u32,
        block: BlockId,
    ) -> Result<Option<BlockStyleInfo>, ApiError> {
        guard_async(async move {
            self.ask(document, move |session| session.block_style(page, block))
                .await
        })
        .await
    }

    /// The fonts a3-2's font field offers for `block` of `page` of `document`, best first.
    ///
    /// # Errors
    ///
    /// As [`block_style`](Self::block_style).
    pub async fn block_fonts(
        &self,
        document: DocumentId,
        page: u32,
        block: BlockId,
    ) -> Result<Vec<FontCandidate>, ApiError> {
        guard_async(async move {
            self.ask(document, move |session| session.block_fonts(page, block))
                .await
        })
        .await
    }

    /// Commits the transaction as the step `name` of the history, dropping the steps undone,
    /// and has the render thread show it. A transaction that changed nothing adds no step.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open, `InvalidInput` while step 3's
    /// characters wait for [`choose_font`](Self::choose_font) or
    /// [`keep_as_is`](Self::keep_as_is), and `ConfirmationRequired` for a change to a signed
    /// document before [`confirm_edit_signed`](Self::confirm_edit_signed) (in both cases the
    /// transaction stays open).
    pub async fn commit(
        &self,
        transaction: TransactionId,
        name: String,
    ) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            let result = self
                .ask(document, move |session| session.commit(transaction, name))
                .await;
            // A failed commit ends the transaction too: the actor dropped it, unless a font
            // choice or the signed document's confirmation is pending.
            let pending = result.as_ref().err().is_some_and(|err| {
                err.details.as_deref() == Some(PENDING_CHOICE)
                    || err.kind == ErrorKind::ConfirmationRequired
            });
            if !pending {
                self.end_transaction(transaction);
            }
            let (current, reload, substitutions) = result?;
            let mut info = self.revision_info(document, current, reload).await;
            info.substitutions = substitutions;
            Ok(info)
        })
        .await
    }

    /// Discards the transaction; the history does not change.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open.
    pub async fn rollback(&self, transaction: TransactionId) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let document = self.transaction_document(transaction)?;
            let current = self
                .ask(document, move |session| session.rollback(transaction))
                .await;
            self.end_transaction(transaction);
            let current = current?;
            Ok(RevisionInfo {
                current,
                render_key: None,
                substitutions: Vec::new(),
            })
        })
        .await
    }

    /// Steps the document back one step of its history.
    ///
    /// # Errors
    ///
    /// Returns `InvalidInput` at the start of the history or while a transaction is open, and
    /// `NotFound` for a document that is not open.
    pub async fn undo(&self, document: DocumentId) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self.ask(document, Session::undo).await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }

    /// Steps the document forward one step undone.
    ///
    /// # Errors
    ///
    /// Returns `InvalidInput` with nothing to redo or while a transaction is open, and
    /// `NotFound` for a document that is not open.
    pub async fn redo(&self, document: DocumentId) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self.ask(document, Session::redo).await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }

    /// Reverts history step `step` (from 0) alone, as a new step `name` that Undo takes back; the
    /// steps around it stay (a3-12). When later steps depend on it they are named and nothing
    /// changes, unless `with_dependents` reverts them too (a3-12b).
    ///
    /// # Errors
    ///
    /// Returns `InvalidInput` for a step that does not apply or was reverted, while a transaction
    /// is open, or when a later change holds the step's bytes and no step can be named;
    /// `ConfirmationRequired` for a signed document before its confirmation; `NotFound` for a
    /// document that is not open.
    pub async fn revert(
        &self,
        document: DocumentId,
        step: u32,
        with_dependents: bool,
        name: String,
    ) -> Result<Reverted, ApiError> {
        guard_async(async move {
            let (reverted, dependents, current, reload) = self
                .ask(document, move |session| {
                    session.revert(step, with_dependents, name)
                })
                .await?;
            Ok(Reverted {
                reverted,
                dependents,
                revision: self.revision_info(document, current, reload).await,
            })
        })
        .await
    }

    /// Takes the document back to how it opened, as a new step `name` that Undo takes back
    /// (a3-12b's Revert all).
    ///
    /// # Errors
    ///
    /// Returns `InvalidInput` while a transaction is open, `ConfirmationRequired` for a signed
    /// document before its confirmation, and `NotFound` for a document that is not open.
    pub async fn revert_all(
        &self,
        document: DocumentId,
        name: String,
    ) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self
                .ask(document, move |session| session.revert_all(name))
                .await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }

    /// The document's history (a3-10).
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open.
    pub async fn history(&self, document: DocumentId) -> Result<History, ApiError> {
        guard_async(async move { self.ask(document, |session| Ok(session.history())).await }).await
    }

    /// Saves the committed revisions to the document's file as an incremental update: the
    /// original bytes stay an exact prefix (after Optimize and clean, the file is rewritten
    /// whole again).
    ///
    /// With `staging`, the macOS App Sandbox's replacement directory (ADR 0008), this and every
    /// other save stops short of the file: the checked temp file stays there, its path comes
    /// back for the platform layer to swap in, and the document is as it was until
    /// [`finish_save`](Self::finish_save). Without it `None` comes back and the file is written.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open, `Unsupported` for a repaired one
    /// (saved with [`save_repaired_copy`](Self::save_repaired_copy) instead),
    /// `ConfirmationRequired` for a signed document before
    /// [`confirm_edit_signed`](Self::confirm_edit_signed) (save, save as and copy alike, but for
    /// the unchanged file copied to another path), `FileChangedOnDisk` when the file changed
    /// since it was opened or saved, and the save failures of docs/ARCHITECTURE.md §7.8
    /// (`DiskFull`, `PermissionDenied`, `FileLocked`, `RenameFailed`, `VolumeGone`, `HardLinked`,
    /// `NotOwner`, `Io`) with [`ApiError::offer_save_as`]. The file and the committed revisions stay as they were.
    pub async fn save(
        &self,
        document: DocumentId,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        self.save_to(document, SaveTarget::File { over_change: false }, staging)
            .await
    }

    /// Saves as [`save`](Self::save) does, over a file that changed on disk ("Keep mine",
    /// a11-7b).
    ///
    /// # Errors
    ///
    /// As [`save`](Self::save), without `FileChangedOnDisk`.
    pub async fn save_over_change(
        &self,
        document: DocumentId,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        self.save_to(document, SaveTarget::File { over_change: true }, staging)
            .await
    }

    /// Saves the committed revisions as the file at `path`, as [`save`](Self::save) does; later
    /// saves write to `path`.
    ///
    /// # Errors
    ///
    /// As [`save`](Self::save); `FileChangedOnDisk` only when `path` is the document's file.
    pub async fn save_as(
        &self,
        document: DocumentId,
        path: PathBuf,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        self.save_to(document, SaveTarget::As(path), staging).await
    }

    /// Saves a copy of the committed revisions as the file at `path`; later saves still write
    /// to the document's file. A copy over the document's own file is a save of it.
    ///
    /// # Errors
    ///
    /// As [`save`](Self::save); `FileChangedOnDisk` only when `path` is the document's file.
    pub async fn save_copy(
        &self,
        document: DocumentId,
        path: PathBuf,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        self.save_to(document, SaveTarget::Copy(path), staging)
            .await
    }

    async fn save_to(
        &self,
        document: DocumentId,
        target: SaveTarget,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        guard_async(async move {
            self.ask(document, move |session| {
                session.save(target, staging.as_deref())
            })
            .await
        })
        .await
    }

    /// Ends a staged save (`staging` on any save) once the platform layer tried the swap:
    /// `swapped`, the document's stamp, file and saved revision move as a save's do; otherwise it
    /// stays as it was, its edits with it, and the staged file goes. Returns whether the last
    /// recovery write failed, as [`ApiError::no_recovery_copy`] says it for the other failures.
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open, `InvalidInput` when no save waits.
    pub async fn finish_save(&self, document: DocumentId, swapped: bool) -> Result<bool, ApiError> {
        guard_async(async move {
            self.ask(document, move |session| session.finish_save(swapped))
                .await
        })
        .await
    }

    /// Optimize and clean (docs/ARCHITECTURE.md §7.3): the document's file rewritten whole,
    /// without earlier revisions and unreferenced objects, streams compressed, encrypted with
    /// its own key; later saves rewrite it whole too. It breaks signatures, so the UI asks
    /// [`would_break_signatures`](Self::would_break_signatures) and warns first, and on a signed
    /// document it needs [`confirm_edit_signed`](Self::confirm_edit_signed).
    ///
    /// # Errors
    ///
    /// As [`save`](Self::save), `ConfirmationRequired` even for an unchanged document;
    /// `Unsupported` for a repaired document.
    pub async fn optimize_and_clean(
        &self,
        document: DocumentId,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        guard_async(async move {
            self.ask(document, move |session| {
                session.optimize_and_clean(staging.as_deref())
            })
            .await
        })
        .await
    }

    /// Writes a repaired document (a1-9) rewritten whole as the file at `path` (B103). Its own
    /// damaged file is replaced only with `replace_original`, the user's confirmation
    /// (ADR 0008); the document keeps its file either way.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for the document's own file without `replace_original`,
    /// `ConfirmationRequired` for a signed document before
    /// [`confirm_edit_signed`](Self::confirm_edit_signed), and the save failures of
    /// [`save`](Self::save).
    pub async fn save_repaired_copy(
        &self,
        document: DocumentId,
        path: PathBuf,
        replace_original: bool,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        guard_async(async move {
            self.ask(document, move |session| {
                session.save_repaired_copy(&path, replace_original, staging.as_deref())
            })
            .await
        })
        .await
    }

    /// Whether a full rewrite of the document (Optimize and clean) would break signatures
    /// (G35).
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open.
    pub async fn would_break_signatures(&self, document: DocumentId) -> Result<bool, ApiError> {
        guard_async(async move { self.ask(document, |session| Ok(session.signed())).await }).await
    }

    /// Confirms the first change to a signed document ("Edit anyway", a3-16a): commits and
    /// writes of this document no longer fail with `ConfirmationRequired` until it closes. The
    /// confirmation is the document's own and is never persisted; asking again returns the same
    /// token.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open.
    pub async fn confirm_edit_signed(
        &self,
        document: DocumentId,
    ) -> Result<ConfirmationToken, ApiError> {
        guard_async(async move { self.ask(document, |session| Ok(session.confirm())).await }).await
    }

    /// Writes the working copy of "Edit a copy" (a3-16a): the document's committed revisions
    /// rewritten whole as the file at `path`, without its signatures, which the app then opens
    /// as any file. The document and its file stay as they are. Needs no confirmation.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for the document's own file, and the save failures of
    /// [`save`](Self::save).
    pub async fn save_unsigned_copy(
        &self,
        document: DocumentId,
        path: PathBuf,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        guard_async(async move {
            self.ask(document, move |session| {
                session.save_unsigned_copy(&path, staging.as_deref())
            })
            .await
        })
        .await
    }

    /// Whether the document's file changed on disk since it was opened or saved
    /// (docs/ARCHITECTURE.md §7.5): size and modification time, then the SHA-256 when either
    /// differs. The app asks when its window regains focus and shows a11-7b.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open, and `Io` when the file cannot be
    /// read.
    pub async fn check_external_change(&self, document: DocumentId) -> Result<bool, ApiError> {
        guard_async(async move {
            self.ask(document, |session| session.external_change())
                .await
        })
        .await
    }

    /// Ends the actor and the transactions of a document that closes; its recovery files go
    /// with `discard_recovery` ("Don't save") and stay otherwise.
    pub(super) async fn end_edits(&self, document: DocumentId, discard_recovery: bool) {
        let running = self
            .actors
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .contains_key(&document);
        if discard_recovery && running {
            let _ = self
                .ask(document, |session| {
                    session.discard_recovery();
                    Ok(())
                })
                .await;
        }
        self.actors
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&document);
        self.transactions
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .retain(|_, owner| *owner != document);
    }

    /// Runs `job` on the actor of `document`, started on first use, and awaits its result.
    pub(super) async fn ask<T: Send + 'static>(
        &self,
        document: DocumentId,
        job: impl FnOnce(&mut Session) -> Result<T, ApiError> + Send + 'static,
    ) -> Result<T, ApiError> {
        let (reply, receiver) = futures_channel::oneshot::channel();
        let job: Job = Box::new(move |session| {
            // A panic is the last resort: the session keeps what the job changed before it.
            let result = guard(AssertUnwindSafe(|| job(session)));
            let _ = reply.send(result);
        });
        self.actor(document)?
            .send(job)
            .map_err(|_| ApiError::internal("the edit actor stopped"))?;
        receiver
            .await
            .map_err(|_canceled| ApiError::internal("the edit actor stopped"))?
    }

    /// The mailbox of `document`'s actor, which starts with its first call.
    fn actor(&self, document: DocumentId) -> Result<mpsc::Sender<Job>, ApiError> {
        let mut actors = self.actors.lock().unwrap_or_else(PoisonError::into_inner);
        if let Some(Actor(mailbox)) = actors.get(&document) {
            return Ok(mailbox.clone());
        }
        let model = self
            .models()?
            .get(&document)
            .cloned()
            .ok_or_else(|| ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL))?;
        let fonts = Arc::clone(&self.fonts);
        let recovery = Arc::clone(&self.recovery);
        let (mailbox, inbox) = mpsc::channel::<Job>();
        thread::Builder::new()
            .name("ferman-edit".to_owned())
            .stack_size(ACTOR_STACK)
            .spawn(move || {
                let mut session = Session::with_engine(model, fonts, recovery);
                loop {
                    match inbox.recv_timeout(SYNC_INTERVAL) {
                        Ok(job) => job(&mut session),
                        Err(mpsc::RecvTimeoutError::Timeout) => {}
                        Err(mpsc::RecvTimeoutError::Disconnected) => break,
                    }
                    // After a job too: a steady stream of them would never time out.
                    let _ = guard(AssertUnwindSafe(|| {
                        session.tick();
                        Ok(())
                    }));
                }
            })
            .map_err(|_| ApiError::internal("cannot start the edit actor"))?;
        actors.insert(document, Actor(mailbox.clone()));
        Ok(mailbox)
    }

    fn transaction_document(&self, transaction: TransactionId) -> Result<DocumentId, ApiError> {
        self.transactions
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .get(&transaction)
            .copied()
            .ok_or_else(|| {
                ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL)
                    .with_details("no such transaction")
            })
    }

    fn end_transaction(&self, transaction: TransactionId) {
        self.transactions
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&transaction);
    }

    /// Hands the render thread the revised bytes, unless a newer revision was handed already,
    /// and awaits the new render key.
    pub(super) async fn revision_info(
        &self,
        document: DocumentId,
        current: u32,
        reload: Reload,
    ) -> RevisionInfo {
        let reply = (|| {
            let (serial, appendix) = reload?;
            let model = self.models().ok()?.get(&document).cloned()?;
            let mut rendered = model
                .rendered
                .lock()
                .unwrap_or_else(PoisonError::into_inner);
            if serial <= *rendered {
                return None;
            }
            *rendered = serial;
            // Sent under the lock, so reloads reach the render thread in the actor's order.
            Some(self.render().ok()?.reload(document, appendix))
        })();
        let render_key = match reply {
            Some(reply) => match reply.await {
                Ok(key) => Some(key),
                Err(err) => {
                    // shortcut: PDFium reloads without the password (Q22), so a document that
                    // needs one keeps showing the revision it opened with.
                    tracing::warn!(error = %err, "the render thread did not reload the revision");
                    None
                }
            },
            None => None,
        };
        RevisionInfo {
            current,
            render_key,
            substitutions: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::facade::document::Model;
    use ferman_text::PageText;

    fn corpus(name: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(format!("{name}.pdf"))
    }

    fn session(name: &str, read_only: Option<NotEditableReason>) -> Session {
        let path = corpus(name);
        let source = ferman_core::Source::read(&path).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        Session::new(Arc::new(Model::new(document, path, read_only, false, None)))
    }

    /// The page's blocks as the actor's readers see them.
    fn blocks(session: &Session, page: usize) -> PageText {
        let store = Arc::clone(&session.model.revised().store);
        ferman_text::text_page_revised(&session.model.document, &store, page, &session.context())
            .unwrap()
    }

    /// The file the revisions would save, without the random second `/ID` string.
    fn saved(session: &Session) -> Vec<u8> {
        let mut bytes = session.bytes().unwrap();
        let original = session.model.document.source().len();
        if bytes.len() > original {
            let tail = bytes.get(original..).unwrap();
            let at = tail.windows(3).rposition(|w| w == b"/ID").unwrap() + original;
            let end = bytes
                .get(at..)
                .unwrap()
                .iter()
                .position(|&b| b == b']')
                .unwrap()
                + at;
            bytes.drain(at..end);
        }
        bytes
    }

    /// Writes `bytes` as `name` into `FERMAN_SAVED_DIR` when it is set, for CI's `qpdf --check`.
    fn keep(name: &str, bytes: &[u8]) {
        if let Some(dir) = std::env::var_os("FERMAN_SAVED_DIR").filter(|dir| !dir.is_empty()) {
            let dir = PathBuf::from(dir);
            std::fs::create_dir_all(&dir).unwrap();
            std::fs::write(dir.join(format!("{name}.pdf")), bytes).unwrap();
        }
    }

    /// Edits the first block of page 0 whose text has `from`, replacing it with `to`.
    fn edit(session: &mut Session, from: &str, to: &str, name: &str) -> (u32, Reload) {
        let block = blocks(session, 0)
            .blocks
            .into_iter()
            .find(|block| block.lines.iter().any(|line| line.text.contains(from)))
            .unwrap();
        let text: Vec<String> = block.lines.iter().map(|line| line.text.clone()).collect();
        let tx = session.begin(0, block.id).unwrap();
        let preview = session
            .apply(tx, &text.join("\n").replacen(from, to, 1))
            .unwrap();
        assert!(preview.missing.is_empty());
        assert!(
            preview
                .page
                .blocks
                .iter()
                .any(|block| block.lines.iter().any(|line| line.text.contains(to)))
        );
        let (current, reload, _) = session.commit(tx, name.to_owned()).unwrap();
        (current, reload)
    }

    /// The block texts of page 0, joined.
    fn page_text(session: &Session) -> String {
        blocks(session, 0)
            .blocks
            .iter()
            .flat_map(|block| block.lines.iter().map(|line| line.text.clone()))
            .collect::<Vec<_>>()
            .join("\n")
    }

    #[test]
    fn a_step_reverts_alone_and_undo_brings_it_back() {
        let mut session = session("edit-e15-helvetica", None);
        let opened = page_text(&session);
        let first_words: Vec<String> = blocks(&session, 0)
            .blocks
            .iter()
            .filter_map(|block| block.lines.first())
            .filter_map(|line| line.text.split(' ').next().map(str::to_owned))
            .collect();
        assert!(first_words.len() >= 2, "two blocks: {first_words:?}");
        edit(&mut session, &first_words[0], "Ax", "first");
        edit(&mut session, &first_words[1], "By", "second");
        let edited = page_text(&session);
        let history = session.history();
        assert_eq!(history.steps[0].page, Some(0));
        assert!(history.steps[0].before.contains(&first_words[0]));
        assert!(history.steps[0].after.contains("Ax"));

        // Another block on the page stays: its bytes do not touch the first edit's.
        let (done, dependents, current, reload) =
            session.revert(0, false, "reverted".to_owned()).unwrap();
        assert!(done);
        assert!(dependents.is_empty());
        assert_eq!(current, 3);
        assert!(reload.is_some());
        let text = page_text(&session);
        assert!(!text.contains("Ax"), "{text}");
        assert!(text.contains("By"), "{text}");
        assert_eq!(session.history().steps[2].reverts, vec![0]);
        // A step reverted cannot be reverted again.
        assert!(session.revert(0, true, "again".to_owned()).is_err());

        session.undo().unwrap();
        assert_eq!(page_text(&session), edited);
        session.redo().unwrap();
        session.revert(1, false, "second too".to_owned()).unwrap();
        assert_eq!(page_text(&session), opened);
        session.bytes().unwrap();
    }

    #[test]
    fn a_step_a_later_edit_builds_on_is_refused_until_asked() {
        let mut session = session("edit-e15-helvetica", None);
        let opened = page_text(&session);
        edit(&mut session, "Monday", "Friday", "first");
        edit(&mut session, "Friday", "Sunday", "second");
        let edited = page_text(&session);

        let (done, dependents, current, reload) =
            session.revert(0, false, "reverted".to_owned()).unwrap();
        assert!(!done);
        assert_eq!(dependents, vec![1]);
        assert_eq!(current, 2);
        assert!(reload.is_none());
        assert_eq!(page_text(&session), edited);

        let (done, dependents, current, _) =
            session.revert(0, true, "reverted".to_owned()).unwrap();
        assert!(done);
        assert_eq!(dependents, vec![1]);
        assert_eq!(current, 3);
        assert_eq!(page_text(&session), opened);
        assert_eq!(session.history().steps[2].reverts, vec![0, 1]);
    }

    #[test]
    fn revert_all_goes_back_to_the_opened_file_and_undo_brings_the_edits_back() {
        let mut session = session("edit-e15-helvetica", None);
        let opened = page_text(&session);
        edit(&mut session, "Monday", "Friday", "first");
        edit(&mut session, "Friday", "Sunday", "second");
        let edited = page_text(&session);
        let (current, _) = session.revert_all("all".to_owned()).unwrap();
        assert_eq!(current, 3);
        assert_eq!(page_text(&session), opened);
        assert!(session.live_steps().is_empty());
        session.undo().unwrap();
        assert_eq!(page_text(&session), edited);
        assert_eq!(session.live_steps(), vec![0, 1]);
    }

    #[test]
    fn an_edit_commits_publishes_and_undoes() {
        let mut session = session("edit-e15-helvetica", None);
        let original = saved(&session);
        assert_eq!(
            original.as_slice(),
            &**session.model.document.source().bytes()
        );
        let (current, reload) = edit(&mut session, "Monday", "Friday", "Edited text");
        assert_eq!(current, 1);
        let (serial, appendix) = reload.unwrap();
        assert_eq!(serial, 1);
        assert!(!appendix.is_empty());
        // The readers see the new text, laid out again.
        let page = blocks(&session, 0);
        assert!(
            page.blocks
                .iter()
                .any(|b| b.lines.iter().any(|l| l.text.contains("Friday")))
        );
        let history = session.history();
        assert_eq!(history.current, 1);
        assert_eq!(history.steps.first().unwrap().name, "Edited text");
        assert!(history.steps.first().unwrap().time > 0);

        let (current, reload) = session.undo().unwrap();
        assert_eq!(current, 0);
        assert!(
            reload.unwrap().1.is_empty(),
            "nothing appended at the start"
        );
        assert_eq!(saved(&session), original);
        assert_eq!(session.history().steps.len(), 1, "the step can be redone");
        let err = session.undo().unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
        session.redo().unwrap();
        assert!(session.redo().is_err());

        // A new edit after an undo drops the redo branch.
        session.undo().unwrap();
        edit(&mut session, "Monday", "Sunday", "Second");
        let history = session.history();
        assert_eq!(history.current, 1);
        assert_eq!(history.steps.len(), 1);
        assert_eq!(history.steps.first().unwrap().name, "Second");
    }

    /// A copy of the signed corpus file in a folder of its own, opened as a session.
    fn signed_copy(dir: &Path) -> Session {
        let path = dir.join("signed.pdf");
        std::fs::copy(corpus("kira-tr-signed"), &path).unwrap();
        let source = ferman_core::Source::read(&path).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        Session::new(Arc::new(Model::new(document, path, None, false, None)))
    }

    fn temp_dir(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("ferman-{name}-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn refused<T: std::fmt::Debug>(result: Result<T, ApiError>) {
        assert_eq!(result.unwrap_err().kind, ErrorKind::ConfirmationRequired);
    }

    #[test]
    fn a_signed_document_writes_nothing_before_its_confirmation() {
        let dir = temp_dir("signed-writes");
        let mut session = signed_copy(&dir);
        let path = session.path.clone();
        let before = std::fs::read(&path).unwrap();

        // A preview needs no confirmation, the commit does, and the transaction stays open.
        let block = blocks(&session, 0)
            .blocks
            .into_iter()
            .find(|block| block.lines.iter().any(|l| l.text.contains("18.500")))
            .unwrap();
        let text: Vec<String> = block.lines.iter().map(|l| l.text.clone()).collect();
        let tx = session.begin(0, block.id).unwrap();
        session
            .apply(tx, &text.join("\n").replacen("18.500", "19.500", 1))
            .unwrap();
        refused(session.commit(tx, "Edited".to_owned()));
        assert_eq!(session.current(), 0);
        assert!(session.open.is_some());
        assert!(!session.history().signature_invalidated);
        session.rollback(tx).unwrap();

        // A commit that changed nothing asks nothing.
        let tx = session.begin(0, block.id).unwrap();
        assert_eq!(session.commit(tx, "Nothing".to_owned()).unwrap().0, 0);

        refused(session.save(SaveTarget::File { over_change: false }, None));
        refused(session.save(SaveTarget::File { over_change: true }, None));
        refused(session.save(SaveTarget::As(path.clone()), None));
        refused(session.save(SaveTarget::Copy(path.clone()), None));
        refused(session.optimize_and_clean(None));
        refused(session.save_repaired_copy(&dir.join("fixed.pdf"), false, None));
        assert_eq!(std::fs::read(&path).unwrap(), before);

        // The unchanged file copied elsewhere keeps its signature valid.
        let copy = dir.join("copy.pdf");
        session.save(SaveTarget::Copy(copy.clone()), None).unwrap();
        assert_eq!(std::fs::read(&copy).unwrap(), before);

        // The working copy is unsigned, and never the original.
        let working = dir.join("working.pdf");
        session.save_unsigned_copy(&working, None).unwrap();
        let source = ferman_core::Source::read(&working).unwrap();
        let opened = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        assert!(!opened.structure().signed());
        let err = session.save_unsigned_copy(&path, None).unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
        assert_eq!(std::fs::read(&path).unwrap(), before);

        // The confirmation is this document's: another session of the same file still asks.
        let token = session.confirm();
        assert_eq!(session.confirm(), token);
        let other = signed_copy(&dir);
        assert!(other.confirmed().is_err());
        edit(&mut session, "18.500", "19.500", "Edited");
        assert!(session.history().signature_invalidated);
        session
            .save(SaveTarget::File { over_change: false }, None)
            .unwrap();
        let saved = std::fs::read(&path).unwrap();
        assert_eq!(saved.get(..before.len()), Some(before.as_slice()));
        session.undo().unwrap();
        assert!(!session.history().signature_invalidated);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn a_restored_signed_document_asks_again() {
        let dir = temp_dir("signed-restored");
        let mut session = signed_copy(&dir);
        let path = session.path.clone();
        session.confirm();
        edit(&mut session, "18.500", "19.500", "Edited");
        let before = std::fs::read(&path).unwrap();

        // A new actor over the published revision, as a restore starts one.
        let mut restored = Session::new(Arc::clone(&session.model));
        assert_eq!(restored.current(), 1);
        assert!(restored.history().signature_invalidated);
        refused(restored.save(SaveTarget::File { over_change: false }, None));
        let copy = dir.join("copy.pdf");
        refused(restored.save(SaveTarget::Copy(copy.clone()), None));
        assert!(!copy.exists());
        assert_eq!(std::fs::read(&path).unwrap(), before);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    /// The other name of the signed file never counts as another path: not a hard link, and not
    /// the name in another case where the volume ignores case.
    #[cfg(unix)]
    #[test]
    fn the_unsigned_copy_never_replaces_the_original_under_another_name() {
        let dir = temp_dir("signed-alias");
        let mut session = signed_copy(&dir);
        let path = session.path.clone();
        let before = std::fs::read(&path).unwrap();
        let link = dir.join("link.pdf");
        std::fs::hard_link(&path, &link).unwrap();
        let upper = dir.join("SIGNED.PDF");
        for alias in [Some(link), upper.exists().then_some(upper)]
            .into_iter()
            .flatten()
        {
            let err = session.save_unsigned_copy(&alias, None).unwrap_err();
            assert_eq!(err.kind, ErrorKind::InvalidInput, "{}", alias.display());
            assert_eq!(std::fs::read(&path).unwrap(), before);
        }
        assert!(!same_file(&path, &dir.join("other.pdf")));
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn optimize_and_clean_after_the_confirmation_keeps_the_row() {
        let dir = temp_dir("signed-optimize");
        let mut session = signed_copy(&dir);
        session.confirm();
        session.optimize_and_clean(None).unwrap();
        assert!(session.history().signature_invalidated);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn an_unsigned_document_needs_no_confirmation() {
        let mut session = session("edit-e15-helvetica", None);
        assert!(session.confirmed().is_ok());
        edit(&mut session, "Monday", "Friday", "Edited");
        assert!(!session.history().signature_invalidated);
    }

    #[test]
    fn rollback_and_an_unchanged_commit_add_no_step() {
        let mut session = session("edit-e15-helvetica", None);
        let block = blocks(&session, 0).blocks.remove(0);
        let tx = session.begin(0, block.id).unwrap();
        // One transaction at a time; undo waits for it.
        let err = session.begin(0, block.id).unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
        assert_eq!(session.undo().unwrap_err().kind, ErrorKind::InvalidInput);
        session
            .apply(tx, &block.lines.first().unwrap().text.replace('e', "a"))
            .unwrap();
        assert_eq!(session.rollback(tx).unwrap(), 0);
        assert_eq!(session.rollback(tx).unwrap_err().kind, ErrorKind::NotFound);

        let tx = session.begin(0, block.id).unwrap();
        let (current, reload, _) = session.commit(tx, "Nothing".to_owned()).unwrap();
        assert_eq!((current, reload.is_none()), (0, true));
        assert!(session.history().steps.is_empty());
    }

    #[test]
    fn apply_replaces_the_text_each_time() {
        let mut session = session("edit-e15-helvetica", None);
        let block = blocks(&session, 0)
            .blocks
            .into_iter()
            .find(|block| block.lines.iter().any(|l| l.text.contains("Monday")))
            .unwrap();
        let text = block
            .lines
            .iter()
            .map(|l| l.text.clone())
            .collect::<Vec<_>>()
            .join("\n");
        let tx = session.begin(0, block.id).unwrap();
        session
            .apply(tx, &text.replace("Monday", "Tuesday"))
            .unwrap();
        let preview = session
            .apply(tx, &text.replace("Monday", "Friday"))
            .unwrap();
        let lines: String = preview
            .page
            .blocks
            .iter()
            .flat_map(|b| b.lines.iter().map(|l| l.text.clone()))
            .collect();
        assert!(lines.contains("Friday") && !lines.contains("Tuesday"));
        // Text that cannot be written leaves the text before applied.
        let preview = session.apply(tx, "Monday \u{0634}").unwrap();
        assert_eq!(preview.missing, ['\u{0634}']);
        assert!(session.open.as_ref().unwrap().working.is_some());
        let preview = session
            .apply(tx, &text.replace("Monday", "Friday"))
            .unwrap();
        assert_eq!(preview.overflow, None);
        session.commit(tx, "Friday".to_owned()).unwrap();
        assert!(
            blocks(&session, 0)
                .blocks
                .iter()
                .any(|b| b.lines.iter().any(|l| l.text.contains("Friday")))
        );
    }

    /// The first block of page 0 whose text has `needle`, and its text as one paragraph.
    fn paragraph(session: &Session, needle: &str) -> (BlockId, String) {
        let block = blocks(session, 0)
            .blocks
            .into_iter()
            .find(|block| block.lines.iter().any(|l| l.text.contains(needle)))
            .unwrap();
        let text = block
            .lines
            .iter()
            .map(|l| l.text.clone())
            .collect::<Vec<_>>()
            .join(" ");
        (block.id, text)
    }

    const SENTENCE: &str = " Kiracı, gecikme hâlinde kiraya verene yazılı bildirimde bulunur.";

    #[test]
    fn an_overflow_offers_its_choices_and_keeps_the_warning() {
        // E06: Madde 4 grows by a line; the IBAN line below blocks Extend.
        let mut session = session("kira-tr", None);
        let (id, text) = paragraph(&session, "aylık kira bedeli");
        let tx = session.begin(0, id).unwrap();
        let preview = session.apply(tx, &format!("{text}{SENTENCE}")).unwrap();
        let lines: Vec<&str> = preview
            .page
            .blocks
            .iter()
            .flat_map(|block| block.lines.iter().map(|line| line.text.as_str()))
            .filter(|line| line.contains("Kirac") || line.contains("gecikme"))
            .collect();
        let plan = preview
            .overflow
            .clone()
            .unwrap_or_else(|| panic!("{lines:?}"));
        assert_eq!(plan.over, 1);
        assert!(
            matches!(&plan.extend, Err(ferman_text::ExtendBlocked::Block { text, .. }) if text.starts_with("IBAN")),
            "{:?}",
            plan.extend
        );
        assert_eq!(preview.chosen, Some(Choice::Keep));
        let err = session.resolve_overflow(tx, Choice::Extend).unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
        session.resolve_overflow(tx, Choice::Keep).unwrap();
        // Text that cannot be written leaves the overflowing text and its choice applied.
        let preview = session
            .apply(tx, &format!("{text}{SENTENCE} \u{0634}"))
            .unwrap();
        assert_eq!(preview.missing, ['\u{0634}']);
        assert_eq!(
            (preview.overflow.is_some(), preview.chosen),
            (true, Some(Choice::Keep))
        );
        session.commit(tx, "Kept".to_owned()).unwrap();
        assert_eq!(session.history().steps.first().unwrap().hidden_lines, 1);
        // The hidden line's text is in the file.
        let bytes = session.bytes().unwrap();
        let saved = ferman_core::open(
            &ferman_core::Source::from_bytes(Arc::from(bytes.as_slice())),
            &ferman_core::OpenOptions::default(),
        )
        .unwrap();
        let extracted = ferman_text::extract::page_text(&saved, 0).unwrap();
        assert!(extracted.contains("gecikme hâlinde"), "{extracted}");
        // The kept paragraph stays editable: with less text the hidden line fits again, and
        // with as much it is kept hidden in the old frame, not drawn over the IBAN line.
        let (id, kept) = paragraph(&session, "aylık kira bedeli");
        let tx = session.begin(0, id).unwrap();
        let preview = session.apply(tx, &format!("{kept} Ek.")).unwrap();
        let plan = preview.overflow.unwrap();
        assert_eq!(plan.over, 1);
        assert!(plan.extend.is_err(), "{:?}", plan.extend);
        let preview = session
            .apply(tx, &kept.replace(SENTENCE.trim(), "Kısa."))
            .unwrap();
        assert_eq!(preview.overflow, None);
        session.commit(tx, "Shortened".to_owned()).unwrap();
        assert_eq!(session.history().steps.get(1).unwrap().hidden_lines, 0);
        keep("facade-e06-keep", &bytes);

        // Madde 3 has room below: Extend.
        let (id, text) = paragraph(&session, "Kira süresi");
        let tx = session.begin(0, id).unwrap();
        let preview = session.apply(tx, &format!("{text}{SENTENCE}")).unwrap();
        assert_eq!(preview.overflow.unwrap().extend.unwrap().lines, 1);
        let preview = session.resolve_overflow(tx, Choice::Extend).unwrap();
        assert_eq!(preview.chosen, Some(Choice::Extend));
        session.commit(tx, "Extended".to_owned()).unwrap();
        assert_eq!(session.history().steps.get(2).unwrap().hidden_lines, 0);
        // Text that fits has no choice to make.
        let (id, text) = paragraph(&session, "Kira bedeli her");
        let tx = session.begin(0, id).unwrap();
        session
            .apply(tx, &text.replacen("on iki", "12", 1))
            .unwrap();
        let err = session.resolve_overflow(tx, Choice::Keep).unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
    }

    #[test]
    fn a_style_is_one_step_and_undoes_to_the_original() {
        let mut session = session("kira-tr", None);
        let original = saved(&session);
        let (block, _) = paragraph(&session, "Kira süresi 01.11.2026");
        let info = session.block_style(0, block).unwrap().unwrap();
        assert!(info.size > 0.0);
        assert!(!info.document_colours.is_empty());
        let transaction = session.begin(0, block).unwrap();
        let preview = session
            .set_style(
                transaction,
                BlockStyle {
                    colour: Some(0x00C8_1E1E),
                    char_spacing: Some(1.0),
                    ..BlockStyle::default()
                },
            )
            .unwrap();
        assert!(preview.missing.is_empty());
        // A later change in the same transaction builds on the first.
        session.move_block(transaction, [2.0, 0.0]).unwrap();
        let (current, reload, _) = session.commit(transaction, "Style".to_owned()).unwrap();
        assert_eq!(current, 1);
        assert!(reload.is_some());
        session.undo().unwrap();
        assert_eq!(saved(&session), original);
    }

    #[test]
    fn a_style_out_of_range_changes_nothing() {
        let mut session = session("kira-tr", None);
        let (block, _) = paragraph(&session, "Kira süresi 01.11.2026");
        let transaction = session.begin(0, block).unwrap();
        let error = session
            .set_style(
                transaction,
                BlockStyle {
                    size: Some(0.0),
                    ..BlockStyle::default()
                },
            )
            .unwrap_err();
        assert_eq!(error.kind, ErrorKind::InvalidInput);
        let (current, reload, _) = session.commit(transaction, "Style".to_owned()).unwrap();
        assert_eq!((current, reload.is_none()), (0, true));
    }

    #[test]
    fn a_font_without_the_characters_leaves_the_block_as_it_was() {
        let mut session = session("kira-tr", None);
        let (block, _) = paragraph(&session, "Kira süresi 01.11.2026");
        let transaction = session.begin(0, block).unwrap();
        let preview = session
            .set_style(
                transaction,
                BlockStyle {
                    font: Some(ferman_text::BlockFont {
                        origin: FontOrigin::Bundled,
                        postscript_name: "NoSuchFont".to_owned(),
                    }),
                    ..BlockStyle::default()
                },
            )
            .unwrap();
        assert!(!preview.missing.is_empty());
        let (current, ..) = session.commit(transaction, "Style".to_owned()).unwrap();
        assert_eq!(current, 0);
    }

    #[test]
    fn a_table_cell_names_the_cells_that_depend_on_it() {
        // E07: a price flags its row's amount and the totals below.
        let mut session = session("fatura-tr", None);
        let page = blocks(&session, 0);
        let price = page
            .blocks
            .iter()
            .find(|block| block.text() == "1.250,00")
            .unwrap();
        let tx = session.begin(0, price.id).unwrap();
        let preview = session.apply(tx, "1.350,00").unwrap();
        let texts: Vec<String> = preview
            .dependents
            .iter()
            .map(|cell| {
                page.blocks
                    .iter()
                    .find(|block| block.id == cell.id)
                    .unwrap()
                    .text()
            })
            .collect();
        assert_eq!(texts, ["1.250,00", "22.950,00", "4.590,00", "27.540,00"]);
        assert!(
            preview
                .dependents
                .iter()
                .all(|cell| cell.frame[2] > cell.frame[0])
        );
    }

    #[test]
    fn a_block_language_is_marked_around_its_operators_and_survives_a_text_edit() {
        let mut session = session("fatura-tr", None);
        let page = blocks(&session, 0);
        let price = page
            .blocks
            .iter()
            .find(|block| block.text() == "1.250,00")
            .unwrap();
        let (left, right) = (price.bbox[0], price.bbox[2]);
        assert_eq!(price.language, None);
        let others: Vec<String> = page
            .blocks
            .iter()
            .filter(|block| block.id != price.id)
            .map(TextBlock::text)
            .collect();

        // The language alone is a step, and the preview names it.
        let tx = session.begin(0, price.id).unwrap();
        let preview = session.set_block_language(tx, "en-GB".to_owned()).unwrap();
        assert_eq!(preview.language.as_deref(), Some("en-GB"));
        assert_eq!(session.commit(tx, "Language".to_owned()).unwrap().0, 1);
        let page = blocks(&session, 0);
        let marked: Vec<_> = page
            .blocks
            .iter()
            .filter(|block| block.language.as_deref() == Some("en-GB"))
            .collect();
        assert_eq!(marked.len(), 1, "only the block is marked");
        assert_eq!(marked[0].text(), "1.250,00");
        assert_eq!(marked[0].bbox[0], left);
        assert_eq!(marked[0].bbox[2], right);
        let rest: Vec<String> = page
            .blocks
            .iter()
            .filter(|block| block.id != marked[0].id)
            .map(TextBlock::text)
            .collect();
        assert_eq!(rest, others);

        // Text typed later stays inside the mark, and keeps the right edge.
        let tx = session.begin(0, marked[0].id).unwrap();
        session.apply(tx, "11.350,00").unwrap();
        session.commit(tx, "Text".to_owned()).unwrap();
        let page = blocks(&session, 0);
        let edited = page
            .blocks
            .iter()
            .find(|block| block.text() == "11.350,00")
            .unwrap();
        assert_eq!(edited.language.as_deref(), Some("en-GB"));
        assert!((edited.bbox[2] - right).abs() < 0.5);

        // The language and the text in one transaction, in either order, make one step.
        let tx = session.begin(0, edited.id).unwrap();
        session.apply(tx, "12.350,00").unwrap();
        session.set_block_language(tx, "de".to_owned()).unwrap();
        session.apply(tx, "13.350,00").unwrap();
        session.commit(tx, "Both".to_owned()).unwrap();
        let page = blocks(&session, 0);
        let edited = page
            .blocks
            .iter()
            .find(|block| block.text() == "13.350,00")
            .unwrap();
        assert_eq!(edited.language.as_deref(), Some("de"));

        let tx = session.begin(0, edited.id).unwrap();
        let err = session
            .set_block_language(tx, "en) Tj (evil".to_owned())
            .unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
    }

    #[test]
    fn a_tagged_document_gives_its_blocks_their_structure_language() {
        let session = session("tez-tr", None);
        let languages: Vec<Option<String>> = (0..session.model.document.page_count())
            .flat_map(|page| blocks(&session, page).blocks)
            .map(|block| block.language)
            .collect();
        assert!(languages.iter().any(|l| l.as_deref() == Some("en-US")));
        assert!(languages.iter().any(Option::is_none));
    }

    #[test]
    fn a_glyph_the_encoding_lacks_is_written_through_differences() {
        let mut session = session("edit-e04-differences", None);
        let block = blocks(&session, 0)
            .blocks
            .into_iter()
            .find(|block| block.lines.iter().any(|l| l.text.contains("Kira bedeli")))
            .unwrap();
        let text = block
            .lines
            .iter()
            .map(|l| l.text.clone())
            .collect::<Vec<_>>()
            .join("\n");
        let tx = session.begin(0, block.id).unwrap();
        let preview = session
            .apply(tx, &text.replacen("bedeli", "bedeliğ", 1))
            .unwrap();
        // Step 1: no substitution, nothing to choose.
        assert!(preview.missing.is_empty() && preview.glyphs.is_none());
        assert!(preview.substitutions.is_empty());
        let (current, _, substitutions) = session.commit(tx, "ğ".to_owned()).unwrap();
        assert_eq!(current, 1);
        assert!(substitutions.is_empty());
        let lines: Vec<String> = blocks(&session, 0)
            .blocks
            .into_iter()
            .flat_map(|block| block.lines.into_iter().map(|line| line.text))
            .collect();
        assert!(
            lines.iter().any(|line| line.contains("bedeliğ")),
            "{lines:?}"
        );
    }

    /// A session on `name` whose fonts are the bundled ones only.
    fn bundled_session(name: &str, ask_each_time: bool) -> Session {
        let mut session = session(name, None);
        let fonts = Fonts::default();
        fonts.set(FontSettings {
            bundled_dir: Some(
                PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../app/assets/fonts"),
            ),
            ask_each_time,
            ..FontSettings::default()
        });
        session.fonts = Arc::new(fonts);
        session
    }

    #[test]
    fn the_third_choice_keeps_the_font_and_reads_the_character_back() {
        // A composite subset (kira-tr's Madde 6) and a simple font (e04).
        for (name, starts, typed) in [
            ("kira-tr", "Olağan bakım", "değişir ğ"),
            ("edit-e04-differences", "Kira bedeli", "ⱥ"),
        ] {
            let mut session = bundled_session(name, false);
            let fonts = Fonts::default();
            fonts.set(FontSettings {
                bundled_dir: None,
                mark_missing: true,
                ..FontSettings::default()
            });
            session.fonts = Arc::new(fonts);
            let (block, text) = paragraph(&session, starts);
            let tx = session.begin(0, block).unwrap();
            let preview = session.apply(tx, &format!("{text} {typed}")).unwrap();
            assert!(
                preview.missing.is_empty() && preview.glyphs.is_none(),
                "{name}"
            );
            let [marked] = preview.substitutions.as_slice() else {
                panic!("{name}: {:?}", preview.substitutions);
            };
            assert_eq!(marked.substitution.kind, SubstitutionKind::Marked);
            assert_eq!(marked.substitution.from, marked.substitution.to);
            let lines: Vec<String> = preview
                .page
                .blocks
                .iter()
                .flat_map(|block| block.lines.iter().map(|line| line.text.clone()))
                .collect();
            let last = typed.chars().next_back().unwrap();
            assert!(
                lines.iter().any(|line| line.contains(last)),
                "{name}: {lines:?}"
            );
            // Nothing waits for an answer.
            let (current, _, told) = session.commit(tx, "Mark".to_owned()).unwrap();
            assert_eq!((current, told.len()), (1, 1), "{name}");
        }
    }

    #[test]
    fn with_reflow_off_only_a_line_feed_ends_a_line() {
        let lines_of = |keep_lines: bool| {
            let mut session = bundled_session("kira-tr", false);
            let fonts = Fonts::default();
            fonts.set(FontSettings {
                keep_lines,
                ..FontSettings::default()
            });
            session.fonts = Arc::new(fonts);
            let (block, text) = paragraph(&session, "Olağan bakım");
            let tx = session.begin(0, block).unwrap();
            // One paragraph: the block's lines as one, without any new character.
            let preview = session.apply(tx, &text.replace('\n', " ")).unwrap();
            let edited = preview
                .page
                .blocks
                .iter()
                .find(|block| {
                    block
                        .lines
                        .first()
                        .is_some_and(|line| line.text.contains("Olağan bakım"))
                })
                .unwrap();
            edited.lines.len()
        };
        assert!(lines_of(false) > 1);
        assert_eq!(lines_of(true), 1);
    }

    #[test]
    fn right_to_left_text_indexes_the_fonts_to_shape_in() {
        // The first edit has no font library yet; the rewrite asks for one and gets it.
        let mut session = bundled_session("he-para", false);
        let (block, text) = paragraph(&session, "הרצל 24");
        let tx = session.begin(0, block).unwrap();
        let preview = session.apply(tx, &text.replacen("24", "42", 1)).unwrap();
        assert!(preview.missing.is_empty());
        assert!(preview.substitutions.is_empty());
        session.commit(tx, "House number".to_owned()).unwrap();
        assert!(
            blocks(&session, 0)
                .blocks
                .iter()
                .any(|b| b.text().contains("הרצל 42"))
        );
    }

    #[test]
    fn step_3_waits_for_a_choice_before_it_commits_and_says_so_once() {
        let mut session = bundled_session("kira-tr", false);
        let (_, text) = paragraph(&session, "Olağan bakım");
        let typed = format!("{text} Ortak alan kuralları değiştirilemez.");
        for round in 0..2 {
            let (block, _) = paragraph(&session, "Olağan bakım");
            let tx = session.begin(0, block).unwrap();
            let preview = session.apply(tx, &typed).unwrap();
            assert!(preview.missing.is_empty());
            let glyphs = preview.glyphs.unwrap();
            assert!(glyphs.drawn);
            // The bundled fonts are offered even when a font of the page lends the character.
            assert!(
                glyphs
                    .candidates
                    .iter()
                    .any(|c| c.origin == FontOrigin::Bundled),
                "{:?}",
                glyphs.candidates
            );
            // The offset is in UTF-16 code units.
            let at = typed.rfind('ğ').unwrap();
            let utf16 = u32::try_from(typed[..at].encode_utf16().count()).unwrap();
            assert_eq!(glyphs.chars, [('ğ', utf16)]);
            let to = preview.substitutions[0].substitution.to.clone();
            assert_eq!(preview.substitutions[0].announced, round == 1);
            // Never silent: the commit waits for the choice, the transaction stays open.
            let refused = session.commit(tx, "Madde 6".to_owned()).unwrap_err();
            assert_eq!(refused.details.as_deref(), Some(PENDING_CHOICE));
            assert!(session.keep_as_is(tx).unwrap().glyphs.is_none());
            let (_, _, told) = session.commit(tx, "Madde 6".to_owned()).unwrap();
            assert_eq!(told[0].substitution.to, to);
            assert_eq!(told[0].announced, round == 1);
            assert_eq!(session.history().steps[0].substitutions.len(), 1);
            let blocks = blocks(&session, 0);
            assert!(
                blocks
                    .blocks
                    .iter()
                    .any(|b| b.text().contains("değiştirilemez"))
            );
            session.undo().unwrap();
        }
    }

    #[test]
    fn ask_each_time_applies_nothing_until_a_font_is_chosen() {
        let mut session = bundled_session("kira-tr", true);
        let (block, text) = paragraph(&session, "Olağan bakım");
        let tx = session.begin(0, block).unwrap();
        let typed = format!("{text} değişir");
        let preview = session.apply(tx, &typed).unwrap();
        assert_eq!(preview.missing, ['ğ']);
        let glyphs = preview.glyphs.unwrap();
        assert!(!glyphs.drawn);
        assert!(session.open.as_ref().unwrap().working.is_none());
        // A font without the character is refused; a usable one is drawn.
        let partial = glyphs.candidates.iter().find(|c| !c.usable());
        if let Some(partial) = partial {
            assert!(
                session
                    .choose_font(tx, partial.origin, partial.postscript_name.clone())
                    .is_err()
            );
        }
        let usable = glyphs.candidates.iter().find(|c| c.usable()).unwrap();
        let chosen = session
            .choose_font(tx, usable.origin, usable.postscript_name.clone())
            .unwrap();
        assert!(chosen.missing.is_empty() && chosen.glyphs.is_none());
        assert_eq!(
            chosen.substitutions[0].substitution.to,
            usable.postscript_name
        );
        let (current, _, told) = session.commit(tx, "Madde 6".to_owned()).unwrap();
        assert_eq!((current, told.len()), (1, 1));
    }

    #[test]
    fn a_composite_font_edit_commits_and_undoes() {
        let mut session = session("zh-hans", None);
        let original = saved(&session);
        edit(
            &mut session,
            "一万九千五百元",
            "一万五千九百元",
            "Edited text",
        );
        keep("facade-zh-hans", &session.bytes().unwrap());
        session.undo().unwrap();
        assert_eq!(saved(&session), original);
    }

    #[test]
    fn a_read_only_document_and_unknown_handles_are_refused() {
        let mut session = session("edit-e15-helvetica", Some(NotEditableReason::Damaged));
        let block = blocks(&session, 0).blocks.remove(0);
        let err = session.begin(0, block.id).unwrap_err();
        assert_eq!(err.kind, ErrorKind::NotEditable);
        assert_eq!(err.message_key, MessageKey::EDIT_DAMAGED);

        let mut session = super::tests::session("edit-e15-helvetica", None);
        assert_eq!(
            session.begin(0, BlockId(1)).unwrap_err().kind,
            ErrorKind::NotFound
        );
        assert_eq!(
            session.begin(9, block.id).unwrap_err().kind,
            ErrorKind::InvalidInput
        );
        let stale = TransactionId(u64::MAX);
        assert_eq!(
            session.apply(stale, "x").unwrap_err().kind,
            ErrorKind::NotFound
        );
        assert_eq!(
            session.commit(stale, String::new()).unwrap_err().kind,
            ErrorKind::NotFound
        );
    }

    #[test]
    fn a_restricted_document_is_not_editable_until_unlocked() {
        let path = corpus("kira-tr-restricted");
        let source = ferman_core::Source::read(&path).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        let model = Arc::new(Model::new(document, path, None, false, None));
        let mut session = Session::new(Arc::clone(&model));
        let block = blocks(&session, 0).blocks.remove(0);
        let err = session.begin(0, block.id).unwrap_err();
        assert_eq!(err.message_key, MessageKey::EDIT_RESTRICTED);
        model.owner_unlocked.store(true, Ordering::Relaxed);
        session.begin(0, block.id).unwrap();
    }

    /// A session of a copy of the corpus file `name` as `file` in a new folder `dir`.
    fn copied(name: &str, dir: &str, file: &str) -> (Session, PathBuf) {
        let dir = std::env::temp_dir().join(format!("ferman-api-{dir}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let own = dir.join(file);
        std::fs::copy(corpus(name), &own).unwrap();
        let source = ferman_core::Source::read(&own).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        let read_only = document
            .repair()
            .is_some()
            .then_some(NotEditableReason::Damaged);
        let model = Model::new(document, own.clone(), read_only, false, None);
        (Session::new(Arc::new(model)), own)
    }

    fn file() -> SaveTarget {
        SaveTarget::File { over_change: false }
    }

    #[test]
    fn the_recovery_files_follow_the_unsaved_changes() {
        let (mut session, own) = copied("edit-e15-helvetica", "recovery", "own.pdf");
        let config = Arc::new(Recovery::started(&own.parent().unwrap().join("Recovery")));
        session.recovery_config = Arc::clone(&config);
        edit(&mut session, "Monday", "Friday", "Edited text");
        let dir = session.recovery.as_ref().unwrap().dir().to_path_buf();
        for file in ["manifest.json", "base.pdf", "journal.log"] {
            assert!(dir.join(file).is_file(), "{file}");
        }
        assert_eq!(
            std::fs::read(dir.join("base.pdf")).unwrap(),
            std::fs::read(&own).unwrap()
        );
        // A save deletes them; an undo past it makes them again.
        session.save(file(), None).unwrap();
        assert!(!dir.exists());
        session.undo().unwrap();
        assert!(dir.join("journal.log").is_file());
        let manifest = ferman_core::recovery::Manifest::read(&dir).unwrap();
        assert_eq!(manifest.saved_revision, 1);
        assert_eq!(manifest.original, own);
        // The switch off deletes them at the next tick, and nothing is written while it is.
        config.set_enabled(false);
        session.tick();
        assert!(!dir.exists());
        session.redo().unwrap();
        assert!(!dir.exists());
        config.set_enabled(true);
        session.undo().unwrap();
        let dir = session.recovery.as_ref().unwrap().dir().to_path_buf();
        assert!(dir.join("journal.log").is_file());
        // "Don't save".
        session.discard_recovery();
        assert!(!dir.exists());
        // Undone past the save, a new edit is at the saved number and is still unsaved.
        edit(&mut session, "Monday", "Sunday", "Edited text");
        assert_eq!(session.current(), 1);
        let dir = session.recovery.as_ref().unwrap().dir().to_path_buf();
        assert!(dir.join("journal.log").is_file());
        session.undo().unwrap();
        session.redo().unwrap();
        assert!(dir.join("journal.log").is_file());
        session.discard_recovery();
        std::fs::remove_dir_all(own.parent().unwrap()).unwrap();
    }

    #[test]
    fn save_writes_an_incremental_update_and_save_as_moves_the_target() {
        let (mut session, own) = copied("edit-e15-helvetica", "edit", "own.pdf");
        let dir = own.parent().unwrap().to_path_buf();
        let original = std::fs::read(&own).unwrap();
        edit(&mut session, "Monday", "Friday", "Edited text");
        session.save(file(), None).unwrap();
        // A copy over its own file is a save: the next save does not see a change on disk.
        session.save(SaveTarget::Copy(own.clone()), None).unwrap();
        assert!(!session.external_change().unwrap());
        let written = std::fs::read(&own).unwrap();
        assert_eq!(written.get(..original.len()), Some(original.as_slice()));
        assert!(written.len() > original.len());
        keep("api-save-helvetica", &written);
        let reopened = ferman_core::open(
            &ferman_core::Source::read(&own).unwrap(),
            &ferman_core::OpenOptions::default(),
        )
        .unwrap();
        assert!(reopened.repair().is_none());
        let text = ferman_text::extract::page_text(&reopened, 0).unwrap();
        assert!(text.contains("Friday") && !text.contains("Monday"));

        // A copy does not move the document's file.
        let copy = dir.join("copy.pdf");
        session.save(SaveTarget::Copy(copy.clone()), None).unwrap();
        assert_eq!(std::fs::read(&copy).unwrap().len(), written.len());
        assert_eq!(session.path, own);

        let other = dir.join("other.pdf");
        session.save(SaveTarget::As(other.clone()), None).unwrap();
        session.undo().unwrap();
        session.save(file(), None).unwrap();
        assert_eq!(
            std::fs::read(&other).unwrap(),
            original,
            "Save writes to the new file"
        );
        assert_eq!(std::fs::read(&own).unwrap(), written);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn a_failed_save_keeps_the_edits_and_can_be_tried_again() {
        let (mut session, own) = copied("edit-e15-helvetica", "edit-failed", "own.pdf");
        let original = std::fs::read(&own).unwrap();
        edit(&mut session, "Monday", "Friday", "Edited text");
        let link = own.with_file_name("link.pdf");
        std::fs::hard_link(&own, &link).unwrap();
        let err = session.save(file(), None).unwrap_err();
        assert_eq!(err.kind, ErrorKind::HardLinked);
        assert!(err.offer_save_as);
        assert_eq!(std::fs::read(&own).unwrap(), original);
        assert_eq!(session.current(), 1, "the edit is kept");
        std::fs::remove_file(&link).unwrap();
        session.save(file(), None).unwrap();
        let text = ferman_text::extract::page_text(
            &ferman_core::open(
                &ferman_core::Source::read(&own).unwrap(),
                &ferman_core::OpenOptions::default(),
            )
            .unwrap(),
            0,
        )
        .unwrap();
        assert!(text.contains("Friday"));
        std::fs::remove_dir_all(own.parent().unwrap()).unwrap();
    }

    #[test]
    fn a_staged_save_moves_nothing_until_it_is_finished() {
        let (mut session, own) = copied("edit-e15-helvetica", "edit-staged", "own.pdf");
        let dir = own.parent().unwrap().to_path_buf();
        let staging = dir.join("staging");
        std::fs::create_dir(&staging).unwrap();
        let original = std::fs::read(&own).unwrap();
        let stamp = session.stamp.clone();
        edit(&mut session, "Monday", "Friday", "Edited text");

        // Stage: the file, the stamp and the saved revision stay until the swap.
        let staged = session.save(file(), Some(&staging)).unwrap().unwrap();
        assert_eq!(staged.parent(), Some(staging.as_path()));
        assert_eq!(std::fs::read(&own).unwrap(), original);
        assert_eq!(session.stamp, stamp);
        assert_eq!(session.saved, Some(0));
        assert!(!session.external_change().unwrap());

        // A failed swap: the edits stay, the staged file goes, and it can be tried again.
        assert!(!session.finish_save(false).unwrap());
        assert!(!staged.exists());
        assert_eq!(std::fs::read(&own).unwrap(), original);
        assert_eq!(session.stamp, stamp);
        assert_eq!(session.saved, Some(0));
        assert_eq!(session.current(), 1, "the edit is kept");
        assert_eq!(
            session.finish_save(false).unwrap_err().kind,
            ErrorKind::InvalidInput,
            "nothing waits any more"
        );

        // The swap, then the finish: the next save sees its own file.
        let staged = session.save(file(), Some(&staging)).unwrap().unwrap();
        let written = std::fs::read(&staged).unwrap();
        std::fs::rename(&staged, &own).unwrap();
        assert_eq!(session.saved, Some(0), "not recorded yet");
        assert!(!session.external_change().unwrap(), "its own swap");
        session.finish_save(true).unwrap();
        assert_eq!(session.saved, Some(1));
        assert!(!session.external_change().unwrap());
        assert!(written.starts_with(&original));
        assert_eq!(session.save(file(), None).unwrap(), None);

        // Save as moves the document only at the finish; a copy elsewhere never does.
        let other = dir.join("other.pdf");
        let staged = session
            .save(SaveTarget::As(other.clone()), Some(&staging))
            .unwrap()
            .unwrap();
        assert_eq!(session.path, own);
        std::fs::rename(&staged, &other).unwrap();
        session.finish_save(true).unwrap();
        assert_eq!(session.path, other);
        let copy = dir.join("copy.pdf");
        let staged = session
            .save(SaveTarget::Copy(copy.clone()), Some(&staging))
            .unwrap()
            .unwrap();
        std::fs::rename(&staged, &copy).unwrap();
        session.finish_save(true).unwrap();
        assert_eq!(session.path, other);

        // Optimize and clean counts as rewritten only at the finish.
        let staged = session.optimize_and_clean(Some(&staging)).unwrap().unwrap();
        assert!(!session.rewritten);
        std::fs::rename(&staged, &other).unwrap();
        session.finish_save(true).unwrap();
        assert!(session.rewritten);
        assert!(!session.external_change().unwrap());
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_staged_save_keeps_the_recovery_files_until_it_is_finished() {
        let (mut session, own) = copied("edit-e15-helvetica", "edit-staged-rec", "own.pdf");
        let root = own.parent().unwrap().to_path_buf();
        let staging = root.join("staging");
        std::fs::create_dir(&staging).unwrap();
        session.recovery_config = Arc::new(Recovery::started(&root.join("Recovery")));
        edit(&mut session, "Monday", "Friday", "Edited text");
        let dir = session.recovery.as_ref().unwrap().dir().to_path_buf();
        session.save(file(), Some(&staging)).unwrap().unwrap();
        assert!(dir.join("journal.log").is_file(), "after the stage");
        session.finish_save(false).unwrap();
        assert!(dir.join("journal.log").is_file(), "after a failed swap");
        let staged = session.save(file(), Some(&staging)).unwrap().unwrap();
        std::fs::rename(&staged, &own).unwrap();
        session.finish_save(true).unwrap();
        assert!(!dir.exists(), "after the swap");
        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn a_staged_save_keeps_the_external_change_check() {
        let (mut session, own) = copied("edit-e15-helvetica", "edit-staged-changed", "own.pdf");
        let dir = own.parent().unwrap().to_path_buf();
        let staging = dir.join("staging");
        std::fs::create_dir(&staging).unwrap();
        edit(&mut session, "Monday", "Friday", "Edited text");
        std::fs::write(&own, b"someone else's").unwrap();
        let err = session.save(file(), Some(&staging)).unwrap_err();
        assert_eq!(err.kind, ErrorKind::FileChangedOnDisk);
        assert_eq!(std::fs::read_dir(&staging).unwrap().count(), 0);
        assert!(session.staged.is_none());
        std::fs::remove_dir_all(dir).unwrap();
    }

    /// The lock of `Recovery::started` stops the folder being replaced on Windows.
    #[cfg(unix)]
    #[test]
    fn a_save_failure_says_when_no_recovery_copy_exists() {
        let (mut session, own) = copied("edit-e15-helvetica", "edit-no-recovery", "own.pdf");
        let dir = own.parent().unwrap().to_path_buf();
        let root = dir.join("Recovery");
        session.recovery_config = Arc::new(Recovery::started(&root));
        // Nothing can be made under the session's folder any more.
        std::fs::remove_dir_all(&root).unwrap();
        std::fs::write(&root, b"not a folder").unwrap();
        edit(&mut session, "Monday", "Friday", "Edited text");
        let link = own.with_file_name("link.pdf");
        std::fs::hard_link(&own, &link).unwrap();
        let err = session.save(file(), None).unwrap_err();
        assert_eq!(err.kind, ErrorKind::HardLinked);
        assert!(err.no_recovery_copy);

        // A failed swap says so too.
        std::fs::remove_file(&link).unwrap();
        let staging = dir.join("staging");
        std::fs::create_dir(&staging).unwrap();
        session.save(file(), Some(&staging)).unwrap();
        assert!(session.finish_save(false).unwrap());

        // Once saved, nothing is at risk.
        session.save(file(), None).unwrap();
        std::fs::hard_link(&own, &link).unwrap();
        assert!(!session.save(file(), None).unwrap_err().no_recovery_copy);
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_recovery_copy_that_works_is_not_reported_missing() {
        let (mut session, own) = copied("edit-e15-helvetica", "edit-recovery-ok", "own.pdf");
        let dir = own.parent().unwrap().to_path_buf();
        session.recovery_config = Arc::new(Recovery::started(&dir.join("Recovery")));
        edit(&mut session, "Monday", "Friday", "Edited text");
        let link = own.with_file_name("link.pdf");
        std::fs::hard_link(&own, &link).unwrap();
        assert!(!session.save(file(), None).unwrap_err().no_recovery_copy);
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_file_changed_on_disk_stops_save_until_keep_mine() {
        let (mut session, own) = copied("edit-e15-helvetica", "edit-changed", "own.pdf");
        assert!(!session.external_change().unwrap());
        edit(&mut session, "Monday", "Friday", "Edited text");
        let mut theirs = std::fs::read(&own).unwrap();
        theirs.extend_from_slice(
            b"
% another app
",
        );
        std::fs::write(&own, &theirs).unwrap();
        assert!(session.external_change().unwrap());
        let err = session.save(file(), None).unwrap_err();
        assert_eq!(err.kind, ErrorKind::FileChangedOnDisk);
        assert!(!err.offer_save_as);
        assert!(!err.details.unwrap_or_default().contains("Friday"));
        assert_eq!(std::fs::read(&own).unwrap(), theirs);
        assert_eq!(session.current(), 1);
        // Keep mine.
        session
            .save(SaveTarget::File { over_change: true }, None)
            .unwrap();
        assert!(!session.external_change().unwrap());
        assert_ne!(std::fs::read(&own).unwrap(), theirs);
        std::fs::remove_dir_all(own.parent().unwrap()).unwrap();
    }

    #[test]
    fn optimize_and_clean_rewrites_the_file_and_later_saves_too() {
        let (mut session, own) = copied("edit-e15-helvetica", "edit-clean", "own.pdf");
        let original = std::fs::read(&own).unwrap();
        edit(&mut session, "Monday", "Friday", "Edited text");
        session.save(file(), None).unwrap();
        session.optimize_and_clean(None).unwrap();
        let cleaned = std::fs::read(&own).unwrap();
        assert!(!cleaned.starts_with(&original), "a new file, not an update");
        keep("api-optimize-helvetica", &cleaned);
        let reopened = ferman_core::open(
            &ferman_core::Source::from_bytes(cleaned.into()),
            &ferman_core::OpenOptions::default(),
        )
        .unwrap();
        assert!(reopened.repair().is_none());
        let text = ferman_text::extract::page_text(&reopened, 0).unwrap();
        assert!(text.contains("Friday") && !text.contains("Monday"));
        // The next save rewrites again: the revisions before the clean do not come back.
        session.undo().unwrap();
        session.save(file(), None).unwrap();
        let saved = std::fs::read(&own).unwrap();
        assert!(!saved.starts_with(&original));
        let text = ferman_text::extract::page_text(
            &ferman_core::open(
                &ferman_core::Source::from_bytes(saved.into()),
                &ferman_core::OpenOptions::default(),
            )
            .unwrap(),
            0,
        )
        .unwrap();
        assert!(text.contains("Monday"));
        std::fs::remove_dir_all(own.parent().unwrap()).unwrap();
    }

    #[test]
    fn a_repaired_document_is_saved_only_as_a_repaired_copy() {
        let (mut session, own) = copied("kira-tr-damaged", "repaired", "damaged.pdf");
        assert!(session.model.document.repair().is_some());
        let damaged = std::fs::read(&own).unwrap();
        let target = own.with_file_name("repaired.pdf");
        let err = session
            .save(SaveTarget::As(target.clone()), None)
            .unwrap_err();
        assert_eq!(err.kind, ErrorKind::Unsupported);
        assert!(!target.exists());
        let err = session.optimize_and_clean(None).unwrap_err();
        assert_eq!(err.kind, ErrorKind::Unsupported);

        session.save_repaired_copy(&target, false, None).unwrap();
        let repaired = ferman_core::open(
            &ferman_core::Source::read(&target).unwrap(),
            &ferman_core::OpenOptions::default(),
        )
        .unwrap();
        assert!(repaired.repair().is_none());
        assert_eq!(session.path, own, "the document keeps its file");

        let err = session.save_repaired_copy(&own, false, None).unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
        assert_eq!(std::fs::read(&own).unwrap(), damaged);
        session.save_repaired_copy(&own, true, None).unwrap();
        let replaced = ferman_core::open(
            &ferman_core::Source::read(&own).unwrap(),
            &ferman_core::OpenOptions::default(),
        )
        .unwrap();
        assert!(replaced.repair().is_none());
        std::fs::remove_dir_all(own.parent().unwrap()).unwrap();
    }

    /// A seeded xorshift generator: the same edits on every run.
    struct Random(u64);

    impl Random {
        fn below(&mut self, n: usize) -> usize {
            self.0 ^= self.0 << 13;
            self.0 ^= self.0 >> 7;
            self.0 ^= self.0 << 17;
            usize::try_from(self.0 % u64::try_from(n).unwrap()).unwrap()
        }
    }

    #[test]
    fn fifty_edits_undo_to_the_original_bytes_and_redo_to_each_revision() {
        // ROADMAP §7 step 2: 50 random edits, then 50 undos give the original bytes; each redo
        // gives its revision's bytes again.
        let mut session = session("edit-e15-helvetica", None);
        let mut random = Random(0x5EED_F00D);
        let original = saved(&session);
        let mut revisions = vec![original.clone()];
        const LETTERS: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";
        let mut tries = 0;
        while revisions.len() <= 50 {
            tries += 1;
            assert!(tries < 500, "too few edits were rewritten");
            let page = blocks(&session, 0);
            let block = page.blocks.get(random.below(page.blocks.len())).unwrap();
            let mut lines: Vec<Vec<char>> = block
                .lines
                .iter()
                .map(|l| l.text.chars().collect())
                .collect();
            let line = lines.get_mut(random.below(block.lines.len())).unwrap();
            let at = random.below(line.len() + 1);
            let cut = random.below(4).min(line.len() - at);
            let new: Vec<char> = (0..random.below(5))
                .map(|_| char::from(*LETTERS.get(random.below(LETTERS.len())).unwrap()))
                .collect();
            line.splice(at..at + cut, new);
            let text = lines
                .iter()
                .map(|l| l.iter().collect::<String>())
                .collect::<Vec<_>>()
                .join("\n");
            let tx = session.begin(0, block.id).unwrap();
            let changed = session
                .apply(tx, &text)
                .is_ok_and(|preview| preview.missing.is_empty());
            if !changed {
                session.rollback(tx).unwrap();
                continue;
            }
            let before = session.history().current;
            let (current, ..) = session
                .commit(tx, format!("edit {}", revisions.len()))
                .unwrap();
            if current == before {
                continue;
            }
            revisions.push(saved(&session));
        }
        keep("api-fifty-edits", &session.bytes().unwrap());
        for at in (0..50).rev() {
            session.undo().unwrap();
            assert_eq!(&saved(&session), revisions.get(at).unwrap(), "undo to {at}");
        }
        assert_eq!(saved(&session), original);
        for at in 1..=50 {
            session.redo().unwrap();
            assert_eq!(&saved(&session), revisions.get(at).unwrap(), "redo to {at}");
        }
        assert_eq!(session.history().steps.len(), 50);
    }
}
