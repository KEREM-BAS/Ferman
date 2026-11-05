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
//! Saving writes the incremental update through ferman-core's safe write (temp file, flush,
//! verify, rename). The atomic replace with its metadata, external changes and every failure of
//! docs/ARCHITECTURE.md §7.8 come later (M3 W4).

use std::panic::AssertUnwindSafe;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc;
use std::sync::{Arc, Mutex, PoisonError};
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH};

use ferman_core::revision::{self, RevisionStore};
use ferman_core::{CoreError, WriteError};
use ferman_fonts::{FontLibrary, FontOrigin, ScanLimits};
use ferman_render::DocumentId;
use ferman_text::extract::CharBox;
use ferman_text::{
    BlockId, Choice, EditContext, Editability, FontCandidate, FontChoice, FontSources,
    MissingGlyphs, MissingReason, NotEditableReason, Outcome, OverflowPlan, Substitution,
    SubstitutionKind, TextBlock,
};

use super::document::Model;
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};
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

    /// The library when it is built, and whether to ask each time.
    fn cached(&self) -> (Option<Arc<FontLibrary>>, bool) {
        let state = self.state.lock().unwrap_or_else(PoisonError::into_inner);
        (state.1.clone(), state.0.ask_each_time)
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
}

/// The document's history for the Undo history panel (a3-10).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct History {
    /// Every committed step, oldest first: those before `current` apply, the rest can be redone.
    pub steps: Vec<HistoryStep>,
    /// How many steps apply.
    pub current: u32,
}

/// A message to an actor: a call to run on its session.
type Job = Box<dyn FnOnce(&mut Session) + Send>;

/// An actor's mailbox. Dropping it ends the thread after the job it is running.
#[derive(Debug)]
pub(super) struct Actor(mpsc::Sender<Job>);

/// The revised bytes for the render thread: the serial of the publish and what follows the
/// original bytes.
type Reload = Option<(u64, Arc<[u8]>)>;

/// The transaction ids handed out; 0 is never one.
static NEXT_TRANSACTION: AtomicU64 = AtomicU64::new(1);

/// An actor's state: one document's revisions and its open transaction.
pub(super) struct Session {
    model: Arc<Model>,
    /// The committed revisions, the store the model's snapshot shares.
    committed: Arc<RevisionStore>,
    open: Option<Open>,
    steps: Vec<HistoryStep>,
    /// Where Save writes.
    path: PathBuf,
    fonts: Arc<Fonts>,
    /// The fonts the UI has been told of, by step and name.
    announced: Vec<(SubstitutionKind, String)>,
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
    /// The step 3 choice made in this transaction.
    font_choice: Option<FontChoice>,
    /// The applied text's step 3 characters drawn without a choice, and its substitutions.
    pending: Option<MissingGlyphs>,
    substitutions: Vec<Substitution>,
}

impl Session {
    #[cfg(test)]
    pub(super) fn new(model: Arc<Model>) -> Self {
        Self::with_fonts(model, Arc::default())
    }

    pub(super) fn with_fonts(model: Arc<Model>, fonts: Arc<Fonts>) -> Self {
        let committed = Arc::clone(&model.revised().store);
        let path = model.path.clone();
        Self {
            model,
            committed,
            open: None,
            steps: Vec::new(),
            path,
            fonts,
            announced: Vec::new(),
        }
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
            font_choice: None,
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
        let rewrite = |library: Option<&FontLibrary>, ask: bool, open: &Open| {
            ferman_text::rewrite_block_fonts(
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
                    choice: open.font_choice.as_ref(),
                },
            )
        };
        let (library, ask) = fonts.cached();
        let mut outcome = rewrite(library.as_deref(), ask, open)?;
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
            outcome = rewrite(Some(&library), ask, open)?;
        }
        let (missing, overflowing, glyphs) = match outcome {
            Outcome::Rewritten(rewrite) => {
                let splices: Vec<revision::Splice> = rewrite
                    .splices
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
        })
    }

    pub(super) fn commit(
        &mut self,
        transaction: TransactionId,
        name: String,
    ) -> Result<(u32, Reload, Vec<FontSubstitution>), ApiError> {
        if self.open(transaction)?.pending.is_some() {
            // Never silent: the provisional font waits for choose_font or keep_as_is.
            return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details(PENDING_CHOICE));
        }
        let (working, hidden, substitutions) = self.open.take().map_or_else(
            || (None, 0, Vec::new()),
            |open| (open.working, open.hidden, open.substitutions),
        );
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
            time: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .ok()
                .and_then(|since| i64::try_from(since.as_millis()).ok())
                .unwrap_or(0),
            hidden_lines: u32::try_from(hidden).unwrap_or(u32::MAX),
            substitutions,
        });
        self.committed = Arc::new(working);
        Ok((self.current(), self.publish(), told))
    }

    pub(super) fn rollback(&mut self, transaction: TransactionId) -> Result<u32, ApiError> {
        self.open(transaction)?;
        self.open = None;
        Ok(self.current())
    }

    pub(super) fn undo(&mut self) -> Result<(u32, Reload), ApiError> {
        self.closed()?;
        Arc::make_mut(&mut self.committed).undo()?;
        Ok((self.current(), self.publish()))
    }

    pub(super) fn redo(&mut self) -> Result<(u32, Reload), ApiError> {
        self.closed()?;
        Arc::make_mut(&mut self.committed).redo()?;
        Ok((self.current(), self.publish()))
    }

    pub(super) fn history(&self) -> History {
        History {
            steps: self.steps.clone(),
            current: self.current(),
        }
    }

    /// The document's bytes with the committed revisions as an incremental update.
    pub(super) fn bytes(&self) -> Result<Vec<u8>, ApiError> {
        Ok(self.committed.incremental_update(&self.model.document)?)
    }

    /// Writes the committed revisions to `path`, or to the document's file; Save then writes
    /// to `path`. An open transaction is not saved.
    pub(super) fn save(&mut self, path: Option<PathBuf>) -> Result<(), ApiError> {
        let bytes = self.bytes()?;
        let target = path.unwrap_or_else(|| self.path.clone());
        ferman_core::save::safe_write(&target, &bytes, None)?;
        self.path = target;
        Ok(())
    }

    fn closed(&self) -> Result<(), ApiError> {
        if self.open.is_some() {
            return Err(CoreError::Write(WriteError::TransactionOpen).into());
        }
        Ok(())
    }

    fn current(&self) -> u32 {
        u32::try_from(self.committed.current()).unwrap_or(u32::MAX)
    }

    /// Publishes the committed revisions for the readers and returns the revised bytes for the
    /// render thread, or `None` when they cannot be written (logged).
    fn publish(&self) -> Reload {
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

    /// Commits the transaction as the step `name` of the history, dropping the steps undone,
    /// and has the render thread show it. A transaction that changed nothing adds no step.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a transaction that is not open, and `InvalidInput` while step 3's
    /// characters wait for [`choose_font`](Self::choose_font) or
    /// [`keep_as_is`](Self::keep_as_is) (the transaction stays open).
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
            // choice is pending.
            let pending = result
                .as_ref()
                .err()
                .is_some_and(|err| err.details.as_deref() == Some(PENDING_CHOICE));
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

    /// The document's history (a3-10).
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open.
    pub async fn history(&self, document: DocumentId) -> Result<History, ApiError> {
        guard_async(async move { self.ask(document, |session| Ok(session.history())).await }).await
    }

    /// Saves the committed revisions to the document's file as an incremental update: the
    /// original bytes stay an exact prefix.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open, `Unsupported` for a repaired one
    /// (saved as a repaired copy instead, later), and the file errors of the write.
    pub async fn save(&self, document: DocumentId) -> Result<(), ApiError> {
        guard_async(async move { self.ask(document, |session| session.save(None)).await }).await
    }

    /// Saves the committed revisions as the file at `path`, as [`save`](Self::save) does; later
    /// saves write to `path`.
    ///
    /// # Errors
    ///
    /// As [`save`](Self::save).
    pub async fn save_as(&self, document: DocumentId, path: PathBuf) -> Result<(), ApiError> {
        guard_async(async move {
            self.ask(document, move |session| session.save(Some(path)))
                .await
        })
        .await
    }

    /// Ends the actor and the transactions of a document that closes.
    pub(super) fn end_edits(&self, document: DocumentId) {
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
    async fn ask<T: Send + 'static>(
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
        let (mailbox, inbox) = mpsc::channel::<Job>();
        thread::Builder::new()
            .name("ferman-edit".to_owned())
            .stack_size(ACTOR_STACK)
            .spawn(move || {
                let mut session = Session::with_fonts(model, fonts);
                for job in inbox {
                    job(&mut session);
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
    async fn revision_info(
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

    #[test]
    fn save_writes_an_incremental_update_and_save_as_moves_the_target() {
        let dir = std::env::temp_dir().join(format!("ferman-api-edit-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let own = dir.join("own.pdf");
        std::fs::copy(corpus("edit-e15-helvetica"), &own).unwrap();
        let source = ferman_core::Source::read(&own).unwrap();
        let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
        let mut session = Session::new(Arc::new(Model::new(
            document,
            own.clone(),
            None,
            false,
            None,
        )));
        let original = std::fs::read(&own).unwrap();
        edit(&mut session, "Monday", "Friday", "Edited text");
        session.save(None).unwrap();
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

        let other = dir.join("other.pdf");
        session.save(Some(other.clone())).unwrap();
        session.undo().unwrap();
        session.save(None).unwrap();
        assert_eq!(
            std::fs::read(&other).unwrap(),
            original,
            "Save writes to the new file"
        );
        assert_eq!(std::fs::read(&own).unwrap(), written);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn a_repaired_document_is_not_saved_over() {
        let mut session = session("kira-tr-damaged", Some(NotEditableReason::Damaged));
        assert!(session.model.document.repair().is_some());
        let target =
            std::env::temp_dir().join(format!("ferman-api-repaired-{}.pdf", std::process::id()));
        let err = session.save(Some(target.clone())).unwrap_err();
        assert_eq!(err.kind, ErrorKind::Unsupported);
        assert!(!target.exists());
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
