//! A block's new text as new operators in its own fonts (docs/ARCHITECTURE.md §6.6, ADR 0005,
//! ROADMAP §7 step 3): the [`Splice`]s that replace exactly the operators of the lines that
//! changed, in simple and composite fonts.
//!
//! - **Re-encoding.** Each new character becomes a code of a simple font of its line (Type1 with
//!   the standard 14, TrueType symbolic or not, Type3) whose text reads back as the character
//!   through the font's ToUnicode CMap or encoding (Standard, WinAnsi, MacRoman, `/Differences`)
//!   and whose glyph the font has: the embedded program's, a standard 14 font's metrics, a Type3
//!   font's `/CharProcs`. The font of the character before it is tried first, then the one after
//!   it, then the line's others. A character no font of the line can draw is reported
//!   ([`Outcome::MissingGlyphs`]), never substituted; the missing-glyph steps come with W3.
//! - **Composite fonts (ROADMAP §7 step 4).** In a Type0 font (`CIDFontType0` or
//!   `CIDFontType2`; `Identity-H`, an embedded CMap with its `usecmap` parents, or a bundled
//!   predefined CMap such as `90ms-RKSJ-H`) a new character takes the code its ToUnicode CMap
//!   gives it, of the codespace's length, when the CMap's CID has a glyph in the embedded
//!   program (through `/CIDToGIDMap` or the CFF charset); its width is the one `/W` or `/DW`
//!   give. Else the program's own cmap may hold the glyph: its CID's code then goes into a copy
//!   of the font ([`FontCopy`]) with the code's ToUnicode entry and, when `/DW` is not its
//!   advance, its width in `/W`, under a new name used only by the new codes. The original
//!   dictionaries never change. Composite strings are written in hex.
//! - **Operators.** A changed line's operators, from its first show to its last, become one run
//!   of `TJ` (or `Tj` when the line had no `TJ` and needs no adjustment), a `Tf` between runs of
//!   different fonts. The unchanged start and end of the line keep their codes and their places
//!   relative to each other: gaps, kerning and `Td` moves become `TJ` numbers. The line keeps its
//!   start; the text after the change moves with it, whatever the alignment.
//! - **State invariant.** After the replacement the font, `Tc`, `Tw`, `Tz`, `TL`, `Ts`, `Tr`, the
//!   line matrix and, when later operators read it, the text matrix equal what the original line
//!   left behind: a final `Tf`, a `Tm` with the original line matrix and an empty `[n] TJ` that
//!   moves the text matrix to the original end. Colour and `q` depth are untouched, since a line
//!   with such operators inside is not rewritten.
//! - **Justification, line by line.** `Tw` stays as it was, so new spaces stretch like the old
//!   ones; a line justified by `TJ` gives new spaces (or, glyph by glyph, new glyphs) the line's
//!   mean adjustment. A line of a left-aligned block wider than its frame is still written and
//!   listed in [`Rewrite::overflowing`]; one of a justified block reflows the block.
//! - **Reflow (ROADMAP §7 step 5).** A block is rewritten line by line when the new text has one
//!   piece per line (separated by `\n`) and the block is left-aligned or justified. Any other
//!   text, and every right-aligned or centred block, is laid out again in the block's frame by
//!   [`reflow`](crate::reflow), a `\n` ending a paragraph, with the real advances of the line's
//!   fonts, `Tc`, `Tw` and `Tz`; a one-line block given one line keeps it, however long, since
//!   its frame is only its old text. Each planned line gets a `Tm` at its planned start, in the font
//!   and state of the block's first show: alignment kept, justified lines stretched by the
//!   block's own method (`Tw` per line, or `TJ` numbers after the spaces or between the glyphs).
//!   Kept characters keep their codes; new ones are encoded as above. All the new lines go into
//!   the operators of the block's first line in content order; the other lines' operators are
//!   replaced by what keeps the state invariant (docs/ARCHITECTURE.md §6.6 step 6), so lines in
//!   text objects of their own, with colour operators between them, reflow too.
//! - **Overflow (§6.8).** When the lines need more than the frame holds, the rewrite carries the
//!   [`OverflowPlan`] and writes the [`Choice`] asked for: Extend writes every line below the
//!   frame, Tighten writes the plan's tracking as `Tc`, and Keep and warn (also the default, and
//!   what a disabled choice falls back to) writes the lines past the frame with `3 Tr`, invisible
//!   but still in the text, since clipping paths and `q` are not allowed inside a text object.
//!
//! Simple fonts' strings are written as literal strings with `\(`, `\)`, `\\` and octal escapes;
//! the original operator's string form is not visible here, since spans carry no bytes.
//!
//! Not rewritten yet ([`Unsupported`]): right-to-left and vertical lines (Identity-V is W3), a
//! new character only a composite font could draw whose predefined CMap is not bundled or that
//! needs a copy of a form's font, lines whose operators are not a plain run of shows (marked
//! content, colour or other operators inside, a show shared with another line, a split operator,
//! different spacing between the shows, a shifted baseline), and the reflow of a block whose lines
//! differ in spacing, colour or turn, are in several streams, or have a raised baseline. Marked
//! content around a line, such as `/ActualText`, is kept as it is.
// Positions, codes and spans come from files (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::HashMap;
use std::ops::Range;

use ferman_core::Document;
use ferman_core::interpret::{
    FontResource, GraphicsState, Matrix, OperatorEvent, Span, SpanSource, TextShow, TextSink,
    multiply,
};
use ferman_core::revision::{FontCopy, RevisionStore};
use ferman_fonts::{FontProgram, with_text};

use crate::TextError;
use crate::extract::{Collector, PdfFont, displayed, glyph_box};
use crate::layout::{Alignment, Justification, Line, TextBlock, TextChar, TextDirection};
use crate::reflow::{self, OverflowPlan};

/// One replacement in a content stream, for ferman-core's splicer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Splice {
    /// The stream.
    pub source: SpanSource,
    /// The bytes it replaces, in the stream's decoded data.
    pub range: Range<usize>,
    /// The bytes that replace them.
    pub bytes: Vec<u8>,
}

/// A block's new operators.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Rewrite {
    /// One splice per changed line, in the block's line order; none when no line changed.
    pub splices: Vec<Splice>,
    /// The font copies the splices name, to add to the page's resources in the same
    /// transaction before the splices ([`RevisionStore::add_fonts`]).
    pub fonts: Vec<FontCopy>,
    /// The lines, as indices into the block's lines, whose new text runs past the frame of a
    /// left-aligned block rewritten line by line: written as they are.
    pub overflowing: Vec<usize>,
    /// The overflow choices, when the reflowed text needs more lines than the frame holds.
    pub overflow: Option<OverflowPlan>,
    /// The choice written for that overflow: the one asked for when it is available, else
    /// [`Choice::Keep`].
    pub chosen: Option<Choice>,
    /// How many lines past the frame are written invisible ([`Choice::Keep`]).
    pub hidden: usize,
}

/// One of the overflow choices (a3-4, docs/ARCHITECTURE.md §6.8).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Choice {
    /// "Extend block by N line(s)": every line written, the frame grown.
    Extend,
    /// "Tighten spacing slightly (−x%)": `Tc` tightened as the plan says, so the text fits.
    Tighten,
    /// "Keep and warn": every line written, the ones past the frame invisible (`3 Tr`), so
    /// their text stays in the file.
    Keep,
}

/// What rewriting a block gives.
#[derive(Debug, Clone, PartialEq)]
pub enum Outcome {
    /// The splices.
    Rewritten(Rewrite),
    /// These characters, in the order they first appear, have no glyph in the fonts of their
    /// line: the missing-glyph steps decide (docs/ARCHITECTURE.md §6.7).
    MissingGlyphs(Vec<char>),
    /// The block cannot be rewritten yet.
    Unsupported(Unsupported),
}

/// Why a block cannot be rewritten yet.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum Unsupported {
    /// The block is not editable ([`TextBlock::editability`]).
    NotEditable,
    /// The block runs right to left or vertically.
    Direction,
    /// A new character could only come from a composite font of its line whose predefined CMap
    /// is not bundled, or from a copy of a font of a form.
    CompositeFont,
    /// A changed line's operators are not a plain run of shows (module documentation).
    Operators,
    /// The block's glyphs are not on the page: it comes from another revision.
    Stale,
}

/// The splices that give `block` of page `index` the text `text`, its lines separated by `\n`,
/// one per line of the block.
///
/// # Errors
///
/// [`TextError::Core`] when the page cannot be interpreted.
pub fn rewrite_block(
    document: &Document,
    index: usize,
    block: &TextBlock,
    text: &str,
) -> Result<Outcome, TextError> {
    rewrite_through(document, None, index, block, text, &[], None)
}

/// [`rewrite_block`] for a block of the document as `revisions` changed it (its current revision
/// and its open transaction), as [`text_page_revised`](crate::layout::text_page_revised) lays
/// it out.
///
/// # Errors
///
/// As [`rewrite_block`].
pub fn rewrite_block_revised(
    document: &Document,
    revisions: &RevisionStore,
    index: usize,
    block: &TextBlock,
    text: &str,
) -> Result<Outcome, TextError> {
    rewrite_through(document, Some(revisions), index, block, text, &[], None)
}

/// [`rewrite_block`] (or [`rewrite_block_revised`] with `revisions`) with the overflow choice
/// `choice` (none yet: [`Choice::Keep`]) and the page's blocks `others`, which may block
/// [`Choice::Extend`]. `text` is the block's new text, a line feed ending a paragraph where the
/// block is reflowed (module documentation).
///
/// # Errors
///
/// As [`rewrite_block`].
pub fn rewrite_block_with(
    document: &Document,
    revisions: Option<&RevisionStore>,
    index: usize,
    block: &TextBlock,
    text: &str,
    others: &[TextBlock],
    choice: Option<Choice>,
) -> Result<Outcome, TextError> {
    rewrite_through(document, revisions, index, block, text, others, choice)
}

fn rewrite_through(
    document: &Document,
    revisions: Option<&RevisionStore>,
    index: usize,
    block: &TextBlock,
    text: &str,
    others: &[TextBlock],
    choice: Option<Choice>,
) -> Result<Outcome, TextError> {
    if !block.editability.is_editable() {
        return Ok(Outcome::Unsupported(Unsupported::NotEditable));
    }
    if block.direction != TextDirection::LeftToRight
        || block
            .lines
            .iter()
            .any(|line| line.direction != TextDirection::LeftToRight)
    {
        return Ok(Outcome::Unsupported(Unsupported::Direction));
    }
    let texts: Vec<&str> = text.split('\n').collect();
    let line_by_line = texts.len() == block.lines.len()
        && matches!(block.alignment, Alignment::Left | Alignment::Justified);
    let mut recorder = Recorder::default();
    match revisions {
        Some(revisions) => revisions.page_text(document, index, &mut recorder)?,
        None => document.page_text(index, &mut recorder)?,
    }
    let page = Page::new(&recorder, document.structure().pages.get(index));
    let frame = Frame::of(block);
    let fresh;
    let store = match revisions {
        Some(revisions) => revisions,
        None => {
            fresh = RevisionStore::new(document);
            &fresh
        }
    };
    let mut copies = Copies {
        document,
        store,
        page: index,
        list: Vec::new(),
    };
    let mut rewrite = Rewrite::default();
    let mut missing: Vec<char> = Vec::new();
    if !line_by_line {
        return reflowed(&page, block, text, others, choice, copies);
    }
    for (at, (line, new)) in block.lines.iter().zip(texts.iter().copied()).enumerate() {
        if line.text == new {
            continue;
        }
        match page.line(line, new, block.justification, &frame, &mut copies) {
            Err(unsupported) => return Ok(Outcome::Unsupported(unsupported)),
            Ok(Planned::Missing(chars)) => missing.extend(chars),
            Ok(Planned::Splice(splice, over)) => {
                rewrite.splices.push(splice);
                if over {
                    rewrite.overflowing.push(at);
                }
            }
        }
    }
    if !missing.is_empty() {
        let mut seen = Vec::new();
        missing.retain(|c| {
            let first = !seen.contains(c);
            seen.push(*c);
            first
        });
        return Ok(Outcome::MissingGlyphs(missing));
    }
    if block.alignment == Alignment::Justified && !rewrite.overflowing.is_empty() {
        // A justified block is one paragraph: a line past its frame reflows it.
        copies.list.clear();
        return reflowed(&page, block, &texts.join(" "), others, choice, copies);
    }
    rewrite.fonts = copies.finish();
    Ok(Outcome::Rewritten(rewrite))
}

/// The outcome of reflowing `block` to `text`.
fn reflowed(
    page: &Page<'_>,
    block: &TextBlock,
    text: &str,
    others: &[TextBlock],
    choice: Option<Choice>,
    mut copies: Copies<'_>,
) -> Result<Outcome, TextError> {
    Ok(match page.block(block, text, others, choice, &mut copies) {
        Err(unsupported) => Outcome::Unsupported(unsupported),
        Ok(Reflowed::Missing(mut missing)) => {
            let mut seen = Vec::new();
            missing.retain(|c| {
                let first = !seen.contains(c);
                seen.push(*c);
                first
            });
            Outcome::MissingGlyphs(missing)
        }
        Ok(Reflowed::Splice {
            splices,
            overflow,
            chosen,
            hidden,
        }) => Outcome::Rewritten(Rewrite {
            splices,
            fonts: copies.finish(),
            overflowing: Vec::new(),
            overflow,
            chosen,
            hidden,
        }),
    })
}

/// The font copies a block's new codes need, one per font copied.
struct Copies<'a> {
    document: &'a Document,
    store: &'a RevisionStore,
    page: usize,
    list: Vec<Copied>,
}

/// One font copy as the lines add to it.
struct Copied {
    /// The original's key, and the key the copy goes by among the rewrite's fonts.
    base: u64,
    key: u64,
    /// The original's ToUnicode CMap, decoded.
    to_unicode: Option<Vec<u8>>,
    copy: FontCopy,
    /// The new codes' text.
    texts: Vec<(Vec<u8>, String)>,
}

impl Copies<'_> {
    /// The key and name of the copy of the font `base`, named `name` on the page, that draws
    /// `code` with `needs`; the copy is made with its first code.
    fn add(
        &mut self,
        base: u64,
        name: &[u8],
        font: &PdfFont,
        code: &[u8],
        needs: &Needs,
    ) -> Result<(u64, Vec<u8>), Unsupported> {
        let at = match self.list.iter().position(|copied| copied.base == base) {
            Some(at) => at,
            None => {
                let taken: Vec<Vec<u8>> = self
                    .list
                    .iter()
                    .map(|copied| copied.copy.name.clone())
                    .collect();
                let fresh = self
                    .store
                    .free_font_name(self.document, self.page, name, &taken)
                    .map_err(|_| Unsupported::Operators)?;
                self.list.push(Copied {
                    base,
                    // Font keys are hashes of their dictionaries; a copy's is derived from its
                    // original's.
                    key: base ^ 0x5C0F_F0C0_FFEE_0001,
                    to_unicode: font.resource.to_unicode.clone(),
                    copy: FontCopy {
                        base: name.to_vec(),
                        name: fresh,
                        widths: Vec::new(),
                        to_unicode: Vec::new(),
                    },
                    texts: Vec::new(),
                });
                self.list.len().saturating_sub(1)
            }
        };
        let copied = self.list.get_mut(at).ok_or(Unsupported::Operators)?;
        if let Some(width) = needs.width
            && !copied.copy.widths.iter().any(|(cid, _)| *cid == needs.cid)
        {
            copied.copy.widths.push((needs.cid, width));
        }
        if needs.text && !copied.texts.iter().any(|(bytes, _)| bytes == code) {
            copied.texts.push((code.to_vec(), needs.c.to_string()));
        }
        Ok((copied.key, copied.copy.name.clone()))
    }

    /// The copies, each with its ToUnicode CMap.
    fn finish(self) -> Vec<FontCopy> {
        self.list
            .into_iter()
            .map(|copied| FontCopy {
                to_unicode: with_text(copied.to_unicode.as_deref(), &copied.texts),
                ..copied.copy
            })
            .collect()
    }
}

/// One operator as the interpreter left it.
struct Event {
    name: Vec<u8>,
    span: Span,
    state: GraphicsState,
    /// Its show, for a show operator with a font.
    show: Option<usize>,
}

/// One show: where its text space is on the page, the state it drew with and its glyphs.
struct Show {
    matrix: Matrix,
    state: GraphicsState,
    glyphs: Range<usize>,
}

/// The sink that keeps every operator and show beside the placed glyphs.
#[derive(Default)]
struct Recorder {
    collector: Collector,
    events: Vec<Event>,
    shows: Vec<Show>,
    /// The show of each glyph.
    glyph_shows: Vec<usize>,
    pending: Option<usize>,
}

impl TextSink for Recorder {
    fn font(&mut self, font: &FontResource) {
        self.collector.font(font);
    }

    fn show(&mut self, show: &TextShow<'_>) -> (f32, f32) {
        let start = self.collector.glyphs.len();
        let advance = self.collector.show(show);
        let end = self.collector.glyphs.len();
        let at = self.shows.len();
        self.shows.push(Show {
            matrix: show.matrix,
            state: show.state.clone(),
            glyphs: start..end,
        });
        self.glyph_shows
            .extend(std::iter::repeat_n(at, end.saturating_sub(start)));
        self.pending = Some(at);
        advance
    }

    fn operator(&mut self, operator: &OperatorEvent<'_>) {
        self.collector.operator(operator);
        self.events.push(Event {
            name: operator.name.to_vec(),
            span: operator.span.clone(),
            state: operator.state.clone(),
            show: self.pending.take(),
        });
    }
}

/// The operators inside a line that its rewrite replaces: shows, positioning and text state.
const INSIDE: [&[u8]; 13] = [
    b"Tj", b"TJ", b"'", b"\"", b"Td", b"TD", b"Tm", b"T*", b"Tc", b"Tw", b"Tz", b"TL", b"Ts",
];
const INSIDE_FONT: &[u8] = b"Tf";

/// The operators after a line that neither read nor set the text matrices.
const PASSIVE: [&[u8]; 26] = [
    b"Tc", b"Tw", b"Tz", b"TL", b"Ts", b"Tf", b"Tr", b"g", b"G", b"rg", b"RG", b"k", b"K", b"cs",
    b"CS", b"sc", b"SC", b"scn", b"SCN", b"gs", b"q", b"Q", b"BMC", b"BDC", b"EMC", b"MP",
];

/// A page's recorded content, indexed for its lines.
struct Page<'a> {
    recorder: &'a Recorder,
    page: Option<&'a ferman_core::structure::Page>,
    /// Glyphs by their operator's source and offset and their index in it.
    by_link: HashMap<(SpanSource, usize, usize), Vec<usize>>,
    /// The event of each show.
    show_events: HashMap<usize, usize>,
}

/// What a changed line gives.
enum Planned {
    Splice(Splice, bool),
    Missing(Vec<char>),
}

/// A line's glyphs and the operators that draw them.
struct Runs {
    units: Vec<Unit>,
    /// Its glyphs, in content order.
    glyphs: Vec<usize>,
    shows: Vec<usize>,
    /// Its first and last operator, as indices into the recorded events.
    first: usize,
    last: usize,
    source: SpanSource,
}

/// Whether two shows draw with the same spacing, colour, baseline and turn of text space.
fn alike(other: &GraphicsState, state: &GraphicsState) -> bool {
    other.char_spacing == state.char_spacing
        && other.word_spacing == state.word_spacing
        && other.horizontal_scaling == state.horizontal_scaling
        && other.rise == state.rise
        && other.render_mode == state.render_mode
        && other.fill == state.fill
        && other.stroke == state.stroke
        && other.ctm == state.ctm
        && other.text_matrix.get(..4) == state.text_matrix.get(..4)
}

/// A run of a line's characters drawn by one glyph, or a space no glyph drew.
struct Unit {
    glyph: Option<usize>,
    chars: Range<usize>,
}

/// A glyph of the new line at its place.
struct Placed {
    font: u64,
    size: f32,
    bytes: Vec<u8>,
    /// Whether its font is composite, so its string is written in hex.
    hex: bool,
    x: f32,
    step: f32,
    ink: bool,
}

/// The block's frame along its lines, in displayed points.
struct Frame {
    along: [f32; 2],
    end: f32,
}

impl Frame {
    fn of(block: &TextBlock) -> Self {
        let along = block
            .lines
            .first()
            .map(|line| {
                let [[x0, y0], [x1, y1]] = line.baseline;
                let length = (x1 - x0).hypot(y1 - y0);
                if length > 0.0 {
                    [(x1 - x0) / length, (y1 - y0) / length]
                } else {
                    [1.0, 0.0]
                }
            })
            .unwrap_or([1.0, 0.0]);
        let end = block
            .lines
            .iter()
            .map(|line| dot(line.baseline[1], along))
            .fold(f32::NEG_INFINITY, f32::max);
        Self { along, end }
    }
}

fn dot(a: [f32; 2], b: [f32; 2]) -> f32 {
    a[0] * b[0] + a[1] * b[1]
}

/// The point `m` takes `[x, y]` to.
fn apply(m: Matrix, [x, y]: [f32; 2]) -> [f32; 2] {
    let [a, b, c, d, e, f] = m;
    [x * a + y * c + e, x * b + y * d + f]
}

/// The inverse of `m`, when it has one.
fn invert(m: Matrix) -> Option<Matrix> {
    let [a, b, c, d, e, f] = m;
    let det = a * d - b * c;
    if det.abs() < 1e-12 || !det.is_finite() {
        return None;
    }
    let (ia, ib, ic, id) = (d / det, -b / det, -c / det, a / det);
    Some([ia, ib, ic, id, -(e * ia + f * ic), -(e * ib + f * id)])
}

/// Whether two matrices place text at the same spot.
fn same(a: Matrix, b: Matrix) -> bool {
    a.iter()
        .zip(b)
        .enumerate()
        .all(|(at, (x, y))| (x - y).abs() <= if at < 4 { 1e-6 } else { 1e-3 })
}

/// The text state a replacement has reached, to restore the original's.
struct Sim {
    font: Option<u64>,
    size: f32,
    char_spacing: f32,
    word_spacing: f32,
    horizontal_scaling: f32,
    leading: f32,
    rise: f32,
    render_mode: u8,
    text_matrix: Matrix,
    line_matrix: Matrix,
}

impl Sim {
    fn of(state: &GraphicsState) -> Self {
        Self {
            font: state.font,
            size: state.size,
            char_spacing: state.char_spacing,
            word_spacing: state.word_spacing,
            horizontal_scaling: state.horizontal_scaling,
            leading: state.leading,
            rise: state.rise,
            render_mode: state.render_mode,
            text_matrix: state.text_matrix,
            line_matrix: state.line_matrix,
        }
    }
}

/// What the operators after a line read of the text matrices.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Need {
    Nothing,
    LineMatrix,
    Both,
}

impl<'a> Page<'a> {
    fn new(recorder: &'a Recorder, page: Option<&'a ferman_core::structure::Page>) -> Self {
        let mut by_link: HashMap<(SpanSource, usize, usize), Vec<usize>> = HashMap::new();
        for (at, glyph) in recorder.collector.glyphs.iter().enumerate() {
            let span = &glyph.link.span;
            by_link
                .entry((span.source, span.range.start, glyph.link.index))
                .or_default()
                .push(at);
        }
        let show_events = recorder
            .events
            .iter()
            .enumerate()
            .filter_map(|(at, event)| event.show.map(|show| (show, at)))
            .collect();
        Self {
            recorder,
            page,
            by_link,
            show_events,
        }
    }

    /// The glyph that drew `c`: of a form placed twice, the placement whose box is the
    /// character's.
    fn glyph_of(&self, c: &TextChar) -> Option<usize> {
        let link = c.glyph.as_ref()?;
        let found = self
            .by_link
            .get(&(link.span.source, link.span.range.start, link.index))?;
        let glyphs = &self.recorder.collector.glyphs;
        let distance = |at: usize| -> f32 {
            match (glyphs.get(at), c.bbox) {
                (Some(glyph), Some(bbox)) => displayed(self.page, glyph_box(glyph))
                    .iter()
                    .zip(bbox)
                    .map(|(a, b)| (a - b).abs())
                    .sum(),
                _ => 0.0,
            }
        };
        found
            .iter()
            .copied()
            .min_by(|&a, &b| distance(a).total_cmp(&distance(b)))
    }

    /// A line's glyphs and the operators that draw them, when they are a plain run of shows.
    fn runs(&self, line: &Line) -> Result<Runs, Unsupported> {
        let recorder = self.recorder;
        // The line's characters as glyphs, in content order.
        let mut units: Vec<Unit> = Vec::new();
        for (at, c) in line.chars.iter().enumerate() {
            let glyph = match &c.glyph {
                Some(_) => Some(self.glyph_of(c).ok_or(Unsupported::Stale)?),
                None => None,
            };
            let next = at.checked_add(1).ok_or(Unsupported::Operators)?;
            match units.last_mut() {
                Some(unit) if glyph.is_some() && unit.glyph == glyph => unit.chars.end = next,
                _ => units.push(Unit {
                    glyph,
                    chars: at..next,
                }),
            }
        }
        let glyphs: Vec<usize> = units.iter().filter_map(|unit| unit.glyph).collect();
        if glyphs.is_empty()
            || glyphs
                .windows(2)
                .any(|pair| matches!(pair, [a, b] if a >= b))
        {
            return Err(Unsupported::Operators);
        }
        let mut shows: Vec<usize> = glyphs
            .iter()
            .filter_map(|&g| recorder.glyph_shows.get(g).copied())
            .collect();
        shows.dedup();
        let in_line = |glyph: usize| glyphs.binary_search(&glyph).is_ok();
        for &show in &shows {
            let all = recorder
                .shows
                .get(show)
                .is_some_and(|show| show.glyphs.clone().all(in_line));
            if !all {
                return Err(Unsupported::Operators);
            }
        }
        let (Some(first_show), Some(last_show)) = (shows.first(), shows.last()) else {
            return Err(Unsupported::Operators);
        };
        let (Some(&first), Some(&last)) = (
            self.show_events.get(first_show),
            self.show_events.get(last_show),
        ) else {
            return Err(Unsupported::Operators);
        };
        let source = self.plain(first, last, &shows)?;
        Ok(Runs {
            units,
            glyphs,
            shows,
            first,
            last,
            source,
        })
    }

    /// The stream of the operators `first..=last`, when they are all shows of `shows` (or empty
    /// ones), positioning and text state, in one stream.
    fn plain(&self, first: usize, last: usize, shows: &[usize]) -> Result<SpanSource, Unsupported> {
        let recorder = self.recorder;
        let events = recorder
            .events
            .get(first..=last)
            .ok_or(Unsupported::Operators)?;
        let source = events.first().ok_or(Unsupported::Operators)?.span.source;
        for event in events {
            let allowed = INSIDE.contains(&event.name.as_slice()) || event.name == INSIDE_FONT;
            let foreign = event.show.is_some_and(|show| {
                !shows.contains(&show)
                    && recorder
                        .shows
                        .get(show)
                        .is_some_and(|show| !show.glyphs.is_empty())
            });
            if !allowed || foreign || event.span.source != source || event.span.carried {
                return Err(Unsupported::Operators);
            }
        }
        Ok(source)
    }

    /// The bytes the operators `first..=last` take in their stream.
    fn range(&self, first: usize, last: usize) -> Result<Range<usize>, Unsupported> {
        let events = &self.recorder.events;
        let head = events.get(first).ok_or(Unsupported::Operators)?;
        let tail = events.get(last).ok_or(Unsupported::Operators)?;
        Ok(head.span.range.start..tail.span.range.end)
    }

    /// The splice for one changed line.
    fn line(
        &self,
        line: &Line,
        new: &str,
        justification: Option<Justification>,
        frame: &Frame,
        copies: &mut Copies<'_>,
    ) -> Result<Planned, Unsupported> {
        let recorder = self.recorder;
        let glyphs = &recorder.collector.glyphs;
        let Runs {
            units,
            glyphs: line_glyphs,
            shows,
            first,
            last,
            source,
        } = self.runs(line)?;
        let show_of = |glyph: usize| recorder.glyph_shows.get(glyph).copied();
        let events = recorder
            .events
            .get(first..=last)
            .ok_or(Unsupported::Operators)?;
        let range = self.range(first, last)?;
        let first_show = *shows.first().ok_or(Unsupported::Operators)?;
        let base = recorder
            .shows
            .get(first_show)
            .ok_or(Unsupported::Operators)?;
        let state = &base.state;
        for &show in &shows {
            let other = &recorder
                .shows
                .get(show)
                .ok_or(Unsupported::Operators)?
                .state;
            if !alike(other, state) {
                return Err(Unsupported::Operators);
            }
        }
        let inverse = invert(base.matrix).ok_or(Unsupported::Operators)?;
        let scaling = state.horizontal_scaling;
        // Where each glyph starts along the line, in the first show's text space.
        let mut x_of: HashMap<usize, f32> = HashMap::new();
        for &g in &line_glyphs {
            let glyph = glyphs.get(g).ok_or(Unsupported::Operators)?;
            let show = show_of(g)
                .and_then(|show| recorder.shows.get(show))
                .ok_or(Unsupported::Operators)?;
            let [ox, oy] = apply(inverse, apply(show.matrix, [0.0, 0.0]));
            if oy.abs() > 0.01 {
                return Err(Unsupported::Operators);
            }
            x_of.insert(g, ox + glyph.offset);
        }
        let x = |g: usize| x_of.get(&g).copied().unwrap_or(0.0);
        let step = |g: usize| glyphs.get(g).map_or(0.0, |glyph| glyph.step);
        let end = |g: usize| x(g) + step(g);
        let is_space = |g: usize| glyphs.get(g).is_some_and(|glyph| glyph.text == " ");
        // The gap after each glyph to the next one, and the width of each space no glyph drew.
        let gap_after = |at: usize| -> f32 {
            let (Some(Some(g)), Some(Some(next))) = (
                units.get(at).map(|unit| unit.glyph),
                at.checked_add(1)
                    .and_then(|n| units.get(n))
                    .map(|unit| unit.glyph),
            ) else {
                return 0.0;
            };
            x(next) - end(g)
        };
        let gap_width = |at: usize| -> f32 {
            let previous = at
                .checked_sub(1)
                .and_then(|p| units.get(p))
                .and_then(|unit| unit.glyph);
            let next = at
                .checked_add(1)
                .and_then(|n| units.get(n))
                .and_then(|unit| unit.glyph);
            match (previous, next) {
                (Some(previous), Some(next)) => x(next) - end(previous),
                _ => 0.0,
            }
        };
        let mean = |values: Vec<f32>| -> Option<f32> {
            let count = values.len();
            (count > 0).then(|| values.iter().sum::<f32>() / count as f32)
        };
        let space_trail = mean(
            (0..units.len())
                .filter(|&at| {
                    units
                        .get(at)
                        .and_then(|unit| unit.glyph)
                        .is_some_and(is_space)
                })
                .map(gap_after)
                .collect(),
        );
        let glyph_trail = mean(
            (0..units.len())
                .filter(|&at| {
                    units
                        .get(at)
                        .and_then(|unit| unit.glyph)
                        .is_some_and(|g| !is_space(g))
                })
                .map(gap_after)
                .collect(),
        );
        let space_gap = mean(
            (0..units.len())
                .filter(|&at| units.get(at).is_some_and(|unit| unit.glyph.is_none()))
                .map(gap_width)
                .collect(),
        )
        .or_else(|| {
            mean(
                line_glyphs
                    .iter()
                    .filter(|&&g| is_space(g))
                    .map(|&g| step(g))
                    .collect(),
            )
        })
        .unwrap_or(0.25 * state.size * scaling);
        // The unchanged start and end, cut at glyph boundaries.
        let old: Vec<char> = line.chars.iter().map(|c| c.ch).collect();
        let fresh: Vec<char> = new.chars().collect();
        let prefix = old.iter().zip(&fresh).take_while(|(a, b)| a == b).count();
        let room = old.len().min(fresh.len()).saturating_sub(prefix);
        let suffix = old
            .iter()
            .rev()
            .zip(fresh.iter().rev())
            .take(room)
            .take_while(|(a, b)| a == b)
            .count();
        let kept_head = units
            .iter()
            .take_while(|unit| unit.chars.end <= prefix)
            .count();
        let tail_from = old.len().saturating_sub(suffix);
        let kept_tail = units
            .iter()
            .enumerate()
            .skip(kept_head)
            .find(|(_, unit)| unit.chars.start >= tail_from)
            .map_or(units.len(), |(at, _)| at);
        let head_chars = kept_head
            .checked_sub(1)
            .and_then(|at| units.get(at))
            .map_or(0, |unit| unit.chars.end);
        let tail_chars = units
            .get(kept_tail)
            .map_or(0, |unit| old.len().saturating_sub(unit.chars.start));
        let middle = fresh
            .get(head_chars..fresh.len().saturating_sub(tail_chars))
            .ok_or(Unsupported::Operators)?;
        let mut encoder = Encoder::new(recorder, &shows, source)?;
        let font_of = |g: usize| glyphs.get(g).map(|glyph| glyph.font);
        let next_font = units
            .get(kept_tail)
            .and_then(|unit| unit.glyph)
            .and_then(font_of);
        let mut placed: Vec<Placed> = Vec::new();
        let mut missing = Vec::new();
        let first_x = line_glyphs.first().map_or(0.0, |&g| x(g));
        let mut cursor = first_x;
        let keep = |at: usize, next_kept: bool, placed: &mut Vec<Placed>, cursor: &mut f32| {
            let Some(unit) = units.get(at) else {
                return;
            };
            let Some(g) = unit.glyph else {
                *cursor += gap_width(at);
                return;
            };
            let Some(glyph) = glyphs.get(g) else {
                return;
            };
            let size = show_of(g)
                .and_then(|show| recorder.shows.get(show))
                .map_or(state.size, |show| show.state.size);
            let length = glyph.length.min(4);
            let bytes = glyph.code.to_be_bytes();
            placed.push(Placed {
                font: glyph.font,
                size,
                hex: recorder
                    .collector
                    .fonts
                    .get(&glyph.font)
                    .is_some_and(|font| font.cmap.is_some()),
                bytes: bytes
                    .get(4_usize.saturating_sub(length)..)
                    .unwrap_or_default()
                    .to_vec(),
                x: *cursor,
                step: glyph.step,
                ink: !glyph.text.chars().all(char::is_whitespace),
            });
            *cursor += glyph.step;
            if next_kept {
                *cursor += gap_after(at);
            }
        };
        for at in 0..kept_head {
            keep(
                at,
                at.saturating_add(1) < kept_head,
                &mut placed,
                &mut cursor,
            );
        }
        for &c in middle {
            let previous = placed.last().map(|p| p.font);
            let order: Vec<u64> = previous
                .into_iter()
                .chain(next_font)
                .chain(encoder.fonts.iter().map(|(key, ..)| *key))
                .collect();
            let chosen = encoder.choose(copies, &order, c)?;
            match chosen {
                Some(Chosen {
                    font: key,
                    bytes,
                    width,
                    hex,
                    size,
                }) => {
                    let spacing = state.char_spacing
                        + if bytes == [32] {
                            state.word_spacing
                        } else {
                            0.0
                        };
                    let advance = (width * size + spacing) * scaling;
                    placed.push(Placed {
                        font: key,
                        size,
                        hex,
                        bytes,
                        x: cursor,
                        step: advance,
                        ink: !c.is_whitespace(),
                    });
                    cursor += advance;
                    cursor += match (justification, c == ' ') {
                        (Some(Justification::Adjustments), true) => space_trail.unwrap_or(0.0),
                        (Some(Justification::Glyphs), false) => glyph_trail.unwrap_or(0.0),
                        _ => 0.0,
                    };
                }
                None if c == ' ' => cursor += space_gap,
                None => missing.push(c),
            }
        }
        for at in kept_tail..units.len() {
            keep(
                at,
                at.saturating_add(1) < units.len(),
                &mut placed,
                &mut cursor,
            );
        }
        if !missing.is_empty() {
            return if encoder.composite {
                Err(Unsupported::CompositeFont)
            } else {
                Ok(Planned::Missing(missing))
            };
        }
        // The operators.
        let before = first
            .checked_sub(1)
            .and_then(|at| recorder.events.get(at))
            .ok_or(Unsupported::Operators)?;
        let mut out = Vec::new();
        let mut sim = Sim::of(&before.state);
        restore(&mut out, &mut sim, state, Need::Both)?;
        let tj = events.iter().any(|event| event.name == b"TJ");
        let name_of = |key: u64| encoder.name(key);
        let mut natural = 0.0_f32;
        let mut items: Vec<Item> = Vec::new();
        let mut hex = false;
        for glyph in &placed {
            if sim.font != Some(glyph.font) || sim.size != glyph.size || glyph.hex != hex {
                flush(&mut out, &mut items, tj, hex)?;
                hex = glyph.hex;
            }
            if sim.font != Some(glyph.font) || sim.size != glyph.size {
                let name = name_of(glyph.font).ok_or(Unsupported::Operators)?;
                set_font(&mut out, &name, glyph.size)?;
                sim.font = Some(glyph.font);
                sim.size = glyph.size;
            }
            let unit = glyph.size * scaling / 1000.0;
            let d = glyph.x - natural;
            if d.abs() > 1e-4 && unit != 0.0 {
                let n = ((-d / unit) * 1000.0).round() / 1000.0;
                if n != 0.0 {
                    items.push(Item::Number(n));
                    natural -= n * unit;
                }
            }
            match items.last_mut() {
                Some(Item::Text(bytes)) => bytes.extend_from_slice(&glyph.bytes),
                _ => items.push(Item::Text(glyph.bytes.clone())),
            }
            natural += glyph.step;
        }
        flush(&mut out, &mut items, tj, hex)?;
        sim.text_matrix = multiply([1.0, 0.0, 0.0, 1.0, natural, 0.0], state.text_matrix);
        sim.line_matrix = state.line_matrix;
        let target = &events.last().ok_or(Unsupported::Operators)?.state;
        let need = need_after(
            recorder
                .events
                .get(last.saturating_add(1)..)
                .unwrap_or_default(),
        );
        restore(&mut out, &mut sim, target, need)?;
        if !matches!(out.first(), Some(b'[' | b'(' | b'/' | b'<')) {
            out.insert(0, b' ');
        }
        // Overflow: the new line's last ink past the frame's end.
        let first_ink = line_glyphs
            .iter()
            .find(|&&g| {
                glyphs
                    .get(g)
                    .is_some_and(|glyph| !glyph.text.trim().is_empty())
            })
            .map_or(first_x, |&g| x(g));
        let new_end = placed
            .iter()
            .filter(|glyph| glyph.ink)
            .map(|glyph| glyph.x + glyph.step)
            .fold(f32::NEG_INFINITY, f32::max);
        let [a, b, ..] = base.matrix;
        let over = new_end.is_finite()
            && dot(line.baseline[0], frame.along) + (new_end - first_ink) * a.hypot(b)
                > frame.end + 0.5;
        Ok(Planned::Splice(
            Splice {
                source,
                range,
                bytes: out,
            },
            over,
        ))
    }
}

/// What a reflowed block gives.
enum Reflowed {
    Splice {
        splices: Vec<Splice>,
        overflow: Option<OverflowPlan>,
        chosen: Option<Choice>,
        hidden: usize,
    },
    Missing(Vec<char>),
}

/// One glyph of a reflowed block, at a character of the new text.
struct Piece {
    /// The character's byte offset in the new text.
    at: usize,
    font: u64,
    size: f32,
    /// Its code; empty for a space no font draws, written as a `TJ` move.
    bytes: Vec<u8>,
    hex: bool,
    /// Its advance per unit of font size.
    width: f32,
    /// Whether its character is a space.
    blank: bool,
}

impl Piece {
    /// Whether it is the single-byte code 32, which `Tw` widens.
    fn space(&self) -> bool {
        self.bytes == [32]
    }

    /// Whether it is a space, of any code, or a move where no font draws one.
    fn blank(&self) -> bool {
        self.blank
    }
}

impl Page<'_> {
    /// The splice that lays `text` out in `block`'s frame (module documentation): one
    /// replacement of every operator from the block's first show to its last.
    #[allow(clippy::too_many_lines)]
    fn block(
        &self,
        block: &TextBlock,
        text: &str,
        others: &[TextBlock],
        choice: Option<Choice>,
        copies: &mut Copies<'_>,
    ) -> Result<Reflowed, Unsupported> {
        let recorder = self.recorder;
        let glyphs = &recorder.collector.glyphs;
        let runs: Vec<Runs> = block
            .lines
            .iter()
            .map(|line| self.runs(line))
            .collect::<Result<_, _>>()?;
        // The lines' operators in content order: the first run takes the new text, the others
        // only what keeps the state invariant (docs/ARCHITECTURE.md §6.6 step 6).
        let mut order: Vec<&Runs> = runs.iter().collect();
        order.sort_by_key(|run| run.first);
        let head = *order.first().ok_or(Unsupported::Operators)?;
        let (first, last, source) = (head.first, head.last, head.source);
        if order.iter().any(|run| run.source != source) {
            return Err(Unsupported::Operators);
        }
        let mut shows: Vec<usize> = runs.iter().flat_map(|run| run.shows.clone()).collect();
        shows.sort_unstable();
        shows.dedup();
        let range = self.range(first, last)?;
        let first_show = *shows.first().ok_or(Unsupported::Operators)?;
        let base = recorder
            .shows
            .get(first_show)
            .ok_or(Unsupported::Operators)?;
        let state = &base.state;
        let word_spacing = block.justification == Some(Justification::WordSpacing);
        for &show in &shows {
            let other = &recorder
                .shows
                .get(show)
                .ok_or(Unsupported::Operators)?
                .state;
            // A block justified by `Tw` sets it per line, and so does its rewrite; lines an
            // earlier Keep and warn hid (`3 Tr`) are checked below.
            let other = GraphicsState {
                word_spacing: if word_spacing {
                    state.word_spacing
                } else {
                    other.word_spacing
                },
                render_mode: if other.render_mode == 3 {
                    state.render_mode
                } else {
                    other.render_mode
                },
                ..other.clone()
            };
            if !alike(&other, state) {
                return Err(Unsupported::Operators);
            }
        }
        // The lines an earlier Keep and warn hid past the frame: invisible lines at the block's
        // end. They are laid out again with the rest, and the frame is the lines before them.
        let hidden_before = |run: &Runs| {
            state.render_mode != 3
                && run.shows.iter().all(|&show| {
                    recorder
                        .shows
                        .get(show)
                        .is_some_and(|show| show.state.render_mode == 3)
                })
        };
        let shown = runs
            .iter()
            .rposition(|run| !hidden_before(run))
            .map_or(0, |at| at.saturating_add(1));
        let visible_shows = |run: &Runs| {
            run.shows.iter().all(|&show| {
                recorder
                    .shows
                    .get(show)
                    .is_some_and(|show| show.state.render_mode == state.render_mode)
            })
        };
        if shown == 0 || !runs.iter().take(shown).all(visible_shows) {
            return Err(Unsupported::Operators);
        }
        let kept_block;
        let framed = if shown < block.lines.len() {
            let lines = block.lines.get(..shown).ok_or(Unsupported::Operators)?;
            let bbox = lines.iter().fold(
                [f32::MAX, f32::MAX, f32::MIN, f32::MIN],
                |[l, t, r, b], line| {
                    let [x0, y0, x1, y1] = line.bbox;
                    [l.min(x0), t.min(y0), r.max(x1), b.max(y1)]
                },
            );
            kept_block = TextBlock {
                lines: lines.to_vec(),
                bbox,
                ..block.clone()
            };
            &kept_block
        } else {
            block
        };
        let [a, b, ..] = base.matrix;
        let scale = a.hypot(b);
        let scaling = state.horizontal_scaling;
        // shortcut: a raised baseline is not reflowed; `Ts` joins when a file needs it.
        if state.rise != 0.0 || scale <= 0.0 || scaling <= 0.0 || !scale.is_finite() {
            return Err(Unsupported::Operators);
        }
        let to_text = invert(base.matrix).ok_or(Unsupported::Operators)?;
        let from_displayed = invert(display_matrix(self.page)).ok_or(Unsupported::Operators)?;
        let frame = reflow::Frame {
            lines: shown,
            ..reflow::Frame::of(block).ok_or(Unsupported::Operators)?
        };
        // A one-line block's frame is only its old text, so one line in stays one line out
        // (a right-aligned or centred cell grows along its line, as a left-aligned one does).
        let planned = if block.lines.len() == 1 && !text.contains('\n') {
            reflow::Frame {
                width: f32::MAX,
                ..frame
            }
        } else {
            frame
        };

        // The old text, its lines joined by a space, and which glyph drew each character.
        let mut old: Vec<(char, Option<(usize, usize)>)> = Vec::new();
        let mut starts = Vec::new();
        for (l, (line, run)) in block.lines.iter().zip(&runs).enumerate() {
            if l > 0 {
                old.push((' ', None));
            }
            starts.push(old.len());
            for (u, unit) in run.units.iter().enumerate() {
                for _ in unit.chars.clone() {
                    old.push((' ', Some((l, u))));
                }
            }
            for (slot, c) in old
                .iter_mut()
                .skip(*starts.last().unwrap_or(&0))
                .zip(&line.chars)
            {
                slot.0 = c.ch;
            }
        }
        let fresh: Vec<(usize, char)> = text.char_indices().collect();
        let same = |a: char, b: char| a == b || (a.is_whitespace() && b.is_whitespace());
        let prefix = old
            .iter()
            .zip(&fresh)
            .take_while(|((a, _), (_, b))| same(*a, *b))
            .count();
        let room = old.len().min(fresh.len()).saturating_sub(prefix);
        let suffix = old
            .iter()
            .rev()
            .zip(fresh.iter().rev())
            .take(room)
            .take_while(|((a, _), (_, b))| same(*a, *b))
            .count();
        let tail_old = old.len().saturating_sub(suffix);
        let tail_new = fresh.len().saturating_sub(suffix);
        // The old characters of a glyph, as indices into `old`.
        let unit_range = |l: usize, u: usize| -> Option<Range<usize>> {
            let start = *starts.get(l)?;
            let chars = &runs.get(l)?.units.get(u)?.chars;
            Some(start.checked_add(chars.start)?..start.checked_add(chars.end)?)
        };
        let kept = |range: &Range<usize>| range.end <= prefix || range.start >= tail_old;

        let mut encoder = Encoder::new(recorder, &shows, source)?;
        let mut pieces: Vec<Piece> = Vec::new();
        let mut missing = Vec::new();
        for (i, &(at, c)) in fresh.iter().enumerate() {
            let before = if i < prefix {
                Some(i)
            } else if i >= tail_new {
                i.checked_sub(tail_new)
                    .and_then(|k| k.checked_add(tail_old))
            } else {
                None
            };
            let glyph = before
                .and_then(|o| old.get(o).and_then(|(_, unit)| *unit).map(|unit| (o, unit)))
                .and_then(|(o, (l, u))| {
                    let g = runs.get(l)?.units.get(u)?.glyph?;
                    Some((o, unit_range(l, u)?, g))
                });
            if let Some((o, range, g)) = glyph
                && kept(&range)
            {
                // A kept glyph keeps its code, at its first character.
                if o == range.start
                    && let Some(glyph) = glyphs.get(g)
                {
                    let font = recorder
                        .collector
                        .fonts
                        .get(&glyph.font)
                        .ok_or(Unsupported::Operators)?;
                    let length = glyph.length.min(4);
                    let size = recorder
                        .glyph_shows
                        .get(g)
                        .and_then(|&show| recorder.shows.get(show))
                        .map_or(state.size, |show| show.state.size);
                    pieces.push(Piece {
                        at,
                        font: glyph.font,
                        size,
                        bytes: glyph
                            .code
                            .to_be_bytes()
                            .get(4_usize.saturating_sub(length)..)
                            .unwrap_or_default()
                            .to_vec(),
                        hex: font.cmap.is_some(),
                        width: font.width(glyph.code, length),
                        blank: glyph.text.chars().all(char::is_whitespace),
                    });
                }
                continue;
            }
            if c == '\n' || c == '\r' {
                continue;
            }
            let c = if c.is_whitespace() { ' ' } else { c };
            let order: Vec<u64> = pieces
                .last()
                .map(|piece| piece.font)
                .into_iter()
                .chain(encoder.fonts.iter().map(|(key, ..)| *key))
                .collect();
            match encoder.choose(copies, &order, c)? {
                Some(chosen) => pieces.push(Piece {
                    at,
                    font: chosen.font,
                    size: chosen.size,
                    bytes: chosen.bytes,
                    hex: chosen.hex,
                    width: chosen.width,
                    blank: c == ' ',
                }),
                None if c == ' ' => pieces.push(Piece {
                    at,
                    font: state.font.unwrap_or_default(),
                    size: state.size,
                    bytes: Vec::new(),
                    hex: false,
                    // shortcut: a space no font draws is a quarter em; measure the old gaps when
                    // a file without space glyphs is reflowed.
                    width: 0.25,
                    blank: true,
                }),
                None => missing.push(c),
            }
        }
        if !missing.is_empty() {
            if encoder.composite {
                return Err(Unsupported::CompositeFont);
            }
            return Ok(Reflowed::Missing(missing));
        }

        // Advances in text space without the justification, and in points for the plan.
        let advance = |piece: &Piece, char_spacing: f32| -> f32 {
            if piece.bytes.is_empty() {
                return piece.width * piece.size * scaling;
            }
            let spacing = if piece.space() && !word_spacing {
                state.word_spacing
            } else {
                0.0
            };
            (piece.width * piece.size + char_spacing + spacing) * scaling
        };
        let mut by_char: HashMap<char, f32> = HashMap::new();
        for piece in &pieces {
            if let Some(c) = text.get(piece.at..).and_then(|rest| rest.chars().next()) {
                by_char
                    .entry(if c.is_whitespace() { ' ' } else { c })
                    .or_insert(advance(piece, state.char_spacing) * scale);
            }
        }
        let points = |c: char| by_char.get(&c).copied().unwrap_or(0.0);
        let page_box = self
            .page
            .map_or([f32::MIN, f32::MIN, f32::MAX, f32::MAX], |page| {
                [0.0, 0.0, page.size.0, page.size.1]
            });
        let overflow = reflow::overflow(framed, &planned, text, points, others, page_box);
        let (plan, tracking, visible, chosen) = match &overflow {
            None => (
                reflow::reflow(&planned, text, points),
                0.0,
                usize::MAX,
                None,
            ),
            Some(plan) => match (choice, &plan.extend, &plan.tighten) {
                (Some(Choice::Tighten), _, Ok(tighten)) => (
                    tighten.plan.clone(),
                    tighten.tracking,
                    usize::MAX,
                    Some(Choice::Tighten),
                ),
                (Some(Choice::Extend), Ok(_), _) => (
                    reflow::reflow(&frame, text, points),
                    0.0,
                    usize::MAX,
                    Some(Choice::Extend),
                ),
                // Keep and warn, also for a choice that is disabled.
                _ => (
                    reflow::reflow(&frame, text, points),
                    0.0,
                    frame.lines,
                    Some(Choice::Keep),
                ),
            },
        };
        let char_spacing = state.char_spacing - tracking / (scale * scaling);

        // The operators.
        let before = first
            .checked_sub(1)
            .and_then(|at| recorder.events.get(at))
            .ok_or(Unsupported::Operators)?;
        let mut out = Vec::new();
        let mut sim = Sim::of(&before.state);
        restore(&mut out, &mut sim, state, Need::Nothing)?;
        if char_spacing != sim.char_spacing {
            space(&mut out);
            number(&mut out, char_spacing)?;
            out.extend_from_slice(b" Tc");
            sim.char_spacing = char_spacing;
        }
        let mut hidden = 0_usize;
        let mut end = None;
        for (n, line) in plan.lines.iter().enumerate() {
            let line_pieces: Vec<&Piece> = pieces
                .iter()
                .filter(|piece| line.range.contains(&piece.at))
                .collect();
            if line_pieces.is_empty() {
                continue;
            }
            if n >= visible {
                hidden = hidden.saturating_add(1);
                if sim.render_mode != 3 {
                    out.extend_from_slice(b" 3 Tr");
                    sim.render_mode = 3;
                }
            }
            let natural: f32 = line_pieces
                .iter()
                .map(|piece| advance(piece, char_spacing))
                .sum();
            let width = natural * scale;
            let room = frame.width - width;
            // The stretch at each gap, in text space, by the block's method.
            let stretch = line.stretch.map(|stretch| {
                let gaps = match stretch.method {
                    Justification::WordSpacing => {
                        line_pieces.iter().filter(|piece| piece.space()).count()
                    }
                    Justification::Adjustments => {
                        line_pieces.iter().filter(|piece| piece.blank()).count()
                    }
                    Justification::Glyphs => line_pieces.len().saturating_sub(1),
                };
                #[allow(clippy::cast_precision_loss)]
                let per_gap = if gaps > 0 && room > 0.0 {
                    room / gaps as f32 / scale
                } else {
                    0.0
                };
                (stretch.method, per_gap)
            });
            let offset = match frame.alignment {
                Alignment::Right => room,
                Alignment::Center => room / 2.0,
                Alignment::Left | Alignment::Justified => 0.0,
            };
            if word_spacing {
                let tw = match stretch {
                    Some((Justification::WordSpacing, per_gap)) => per_gap / scaling,
                    _ => 0.0,
                };
                if tw != sim.word_spacing {
                    space(&mut out);
                    number(&mut out, tw)?;
                    out.extend_from_slice(b" Tw");
                    sim.word_spacing = tw;
                }
            }
            #[allow(clippy::cast_precision_loss)]
            let down = frame.pitch * n as f32;
            let point = [
                frame.origin[0] + frame.along[0] * offset + frame.across[0] * down,
                frame.origin[1] + frame.along[1] * offset + frame.across[1] * down,
            ];
            let [tx, ty] = apply(to_text, apply(from_displayed, point));
            let matrix = multiply([1.0, 0.0, 0.0, 1.0, tx, ty], state.text_matrix);
            space(&mut out);
            for value in matrix {
                number(&mut out, value)?;
                out.push(b' ');
            }
            out.extend_from_slice(b"Tm");
            sim.line_matrix = matrix;
            sim.text_matrix = matrix;
            let mut moved = 0.0_f32;
            let mut items: Vec<Item> = Vec::new();
            let mut hex = false;
            for (k, piece) in line_pieces.iter().enumerate() {
                if !piece.bytes.is_empty()
                    && (sim.font != Some(piece.font) || sim.size != piece.size || piece.hex != hex)
                {
                    flush(&mut out, &mut items, false, hex)?;
                    hex = piece.hex;
                    if sim.font != Some(piece.font) || sim.size != piece.size {
                        let name = encoder.name(piece.font).ok_or(Unsupported::Operators)?;
                        set_font(&mut out, &name, piece.size)?;
                        sim.font = Some(piece.font);
                        sim.size = piece.size;
                    }
                }
                let unit = sim.size * scaling / 1000.0;
                if unit == 0.0 {
                    return Err(Unsupported::Operators);
                }
                let mut shift = 0.0_f32;
                if piece.bytes.is_empty() {
                    shift += advance(piece, char_spacing);
                } else {
                    match items.last_mut() {
                        Some(Item::Text(bytes)) => bytes.extend_from_slice(&piece.bytes),
                        _ => items.push(Item::Text(piece.bytes.clone())),
                    }
                    // A word-spacing block's `Tw` is the line's own, which `advance` leaves out.
                    moved += advance(piece, char_spacing)
                        + if piece.space() && word_spacing {
                            sim.word_spacing * scaling
                        } else {
                            0.0
                        };
                }
                let not_last = k.saturating_add(1) < line_pieces.len();
                shift += match stretch {
                    Some((Justification::Adjustments, per_gap)) if piece.blank() => per_gap,
                    Some((Justification::Glyphs, per_gap)) if not_last => per_gap,
                    _ => 0.0,
                };
                if shift != 0.0 {
                    let n = ((-shift / unit) * 1000.0).round() / 1000.0;
                    items.push(Item::Number(n));
                    moved -= n * unit;
                }
            }
            flush(&mut out, &mut items, false, hex)?;
            end = Some(multiply([1.0, 0.0, 0.0, 1.0, moved, 0.0], matrix));
        }
        if let Some(end) = end {
            sim.text_matrix = end;
        }
        let target = &recorder
            .events
            .get(last)
            .ok_or(Unsupported::Operators)?
            .state;
        let need = need_after(
            recorder
                .events
                .get(last.saturating_add(1)..)
                .unwrap_or_default(),
        );
        restore(&mut out, &mut sim, target, need)?;
        if !matches!(out.first(), Some(b'[' | b'(' | b'/' | b'<')) {
            out.insert(0, b' ');
        }
        let mut splices = vec![Splice {
            source,
            range,
            bytes: out,
        }];
        for run in order.iter().skip(1) {
            let events = &recorder.events;
            let before = run
                .first
                .checked_sub(1)
                .and_then(|at| events.get(at))
                .ok_or(Unsupported::Operators)?;
            let target = &events.get(run.last).ok_or(Unsupported::Operators)?.state;
            let need = need_after(events.get(run.last.saturating_add(1)..).unwrap_or_default());
            let mut out = Vec::new();
            restore(&mut out, &mut Sim::of(&before.state), target, need)?;
            out.insert(0, b' ');
            splices.push(Splice {
                source,
                range: self.range(run.first, run.last)?,
                bytes: out,
            });
        }
        Ok(Reflowed::Splice {
            splices,
            overflow,
            chosen,
            hidden,
        })
    }
}

/// The matrix that takes user space to displayed page space: the crop box's corner at the
/// origin, y down, the page's rotation applied.
fn display_matrix(page: Option<&ferman_core::structure::Page>) -> Matrix {
    let Some(page) = page else {
        return [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
    };
    let (ox, oy) = page.display_point(0.0, 0.0);
    let (xx, xy) = page.display_point(1.0, 0.0);
    let (yx, yy) = page.display_point(0.0, 1.0);
    [xx - ox, xy - oy, yx - ox, yy - oy, ox, oy]
}

/// A new character's code, in the font that draws it.
struct Chosen {
    font: u64,
    bytes: Vec<u8>,
    /// Its advance per unit of font size.
    width: f32,
    /// Whether the font is composite, so its string is written in hex.
    hex: bool,
    /// The size the font is set at.
    size: f32,
}

/// The fonts of some shows, which new characters are encoded in.
struct Encoder<'a> {
    recorder: &'a Recorder,
    programs: HashMap<u64, Option<FontProgram<'a>>>,
    /// The fonts with the name and size their shows set them with, then the font copies made.
    fonts: Vec<(u64, Vec<u8>, f32)>,
    source: SpanSource,
    /// Whether a character was left out that only a composite font whose predefined CMap is
    /// not bundled, or a copy of a form's font, could draw.
    composite: bool,
}

impl<'a> Encoder<'a> {
    fn new(
        recorder: &'a Recorder,
        shows: &[usize],
        source: SpanSource,
    ) -> Result<Self, Unsupported> {
        let mut fonts: Vec<(u64, Vec<u8>, f32)> = Vec::new();
        for &show in shows {
            let state = &recorder
                .shows
                .get(show)
                .ok_or(Unsupported::Operators)?
                .state;
            if let (Some(font), Some(name)) = (state.font, &state.font_name)
                && !fonts.iter().any(|(key, ..)| *key == font)
            {
                fonts.push((font, name.clone(), state.size));
            }
        }
        Ok(Self {
            recorder,
            programs: HashMap::new(),
            fonts,
            source,
            composite: false,
        })
    }

    /// The name a font is set by.
    fn name(&self, key: u64) -> Option<Vec<u8>> {
        self.fonts
            .iter()
            .find(|(font, ..)| *font == key)
            .map(|(_, name, _)| name.clone())
    }

    /// `c` in the first font of `order` that draws it (module documentation), making the font
    /// copy it needs; `None` when none does.
    fn choose(
        &mut self,
        copies: &mut Copies<'_>,
        order: &[u64],
        c: char,
    ) -> Result<Option<Chosen>, Unsupported> {
        let recorder = self.recorder;
        for &key in order {
            let Some(font) = recorder.collector.fonts.get(&key) else {
                continue;
            };
            let program = self.programs.entry(key).or_insert_with(|| font.program());
            let size_of = |fonts: &[(u64, Vec<u8>, f32)], key: u64| {
                fonts
                    .iter()
                    .find(|(font, ..)| *font == key)
                    .map(|(_, _, size)| *size)
            };
            if font.cmap.is_none() {
                if let Some(code) = encode(font, program.as_ref(), c) {
                    return Ok(Some(Chosen {
                        font: key,
                        bytes: vec![code],
                        width: font.width(u32::from(code), 1),
                        hex: false,
                        size: size_of(&self.fonts, key).ok_or(Unsupported::Operators)?,
                    }));
                }
                continue;
            }
            if !font.cmap_known {
                self.composite = true;
                continue;
            }
            let Some(found) = encode_composite(font, program.as_ref(), c) else {
                continue;
            };
            let Some(needs) = &found.needs else {
                return Ok(Some(Chosen {
                    font: key,
                    bytes: found.bytes,
                    width: found.width,
                    hex: true,
                    size: size_of(&self.fonts, key).ok_or(Unsupported::Operators)?,
                }));
            };
            // A copy goes into the page's resources; a form's fonts are not copied yet.
            let named = self.fonts.iter().find(|(font, ..)| *font == key).cloned();
            let (Some((_, name, size)), SpanSource::Page { .. }) = (named, self.source) else {
                self.composite = true;
                continue;
            };
            let (copy, copy_name) = copies.add(key, &name, font, &found.bytes, needs)?;
            if !self.fonts.iter().any(|(font, ..)| *font == copy) {
                self.fonts.push((copy, copy_name, size));
            }
            return Ok(Some(Chosen {
                font: copy,
                bytes: found.bytes,
                width: found.width,
                hex: true,
                size,
            }));
        }
        Ok(None)
    }
}

/// The code of `font` that draws `c` and reads back as it: the lowest whose text is `c` and
/// whose glyph the font has.
fn encode(font: &PdfFont, program: Option<&FontProgram<'_>>, c: char) -> Option<u8> {
    // U+FFFD is what a code without text reads as, not a character a code draws.
    if c == char::REPLACEMENT_CHARACTER {
        return None;
    }
    let text = c.to_string();
    (0..=u8::MAX).find(|&code| font.text(u32::from(code)) == text && font.has_glyph(program, code))
}

/// A new character's code in a composite font.
struct Composite {
    bytes: Vec<u8>,
    /// Its advance per unit of font size.
    width: f32,
    /// What a copy of the font must add for it; `None` when the font draws it as it is.
    needs: Option<Needs>,
}

/// What a copy of a composite font adds for a new code.
struct Needs {
    cid: u32,
    /// Its advance in thousandths of an em, which `/W` lacks and `/DW` is not.
    width: Option<f32>,
    /// Whether the ToUnicode CMap needs an entry for it, and its character.
    text: bool,
    c: char,
}

/// The code of composite `font` that draws `c` (module documentation): the one its ToUnicode
/// CMap gives `c` when its CID has a glyph, else the code of the CID of the glyph the program's
/// cmap gives `c`, with what a copy of the font must add for it.
fn encode_composite(
    font: &PdfFont,
    program: Option<&FontProgram<'_>>,
    c: char,
) -> Option<Composite> {
    if c == char::REPLACEMENT_CHARACTER || !font.cmap_known || font.vertical() {
        return None;
    }
    let cmap = font.cmap.as_ref()?;
    let text = c.to_string();
    // The code's bytes, which the codespace must read back as this one code.
    let bytes_of = |code: u32, length: usize| -> Option<Vec<u8>> {
        let all = code.to_be_bytes();
        let bytes = all.get(4_usize.checked_sub(length)?..)?.to_vec();
        let read: Vec<(u32, usize)> = cmap.codes(&bytes).collect();
        (read == [(code, length)]).then_some(bytes)
    };
    // Without a program the reader's own font draws the CIDs; one that does not parse is
    // trusted the same way.
    let drawn =
        |cid: u32| program.map_or(cid != 0, |program| font.cid_glyph(program, cid).is_some());
    let mapped = font.to_unicode.as_ref();
    if let Some((code, length)) = mapped.and_then(|cmap| cmap.code_for_text(&text))
        && let Some(bytes) = bytes_of(code, length)
        && cmap.cid(code, length).is_some_and(drawn)
    {
        return Some(Composite {
            bytes,
            width: font.width(code, length),
            needs: None,
        });
    }
    let program = program?;
    let glyph = program.glyph_for_char(c).filter(|glyph| glyph.0 != 0)?;
    let cid = font.glyph_cid(program, glyph)?;
    if font.cid_glyph(program, cid) != Some(glyph) {
        return None;
    }
    let (code, length) = cmap.code_for_cid(cid)?;
    let bytes = bytes_of(code, length)?;
    let needs_text = match mapped.and_then(|cmap| cmap.text(code)) {
        Some(other) if other != text => return None,
        Some(_) => false,
        None => true,
    };
    let resource = &font.resource;
    let listed = resource
        .cid_widths
        .iter()
        .any(|&(first, last, _)| (first..=last).contains(&cid));
    let units = f32::from(program.units_per_em());
    let advance = (!listed && units > 0.0)
        .then(|| program.advance_width(glyph))
        .flatten()
        .map(|advance| (advance * 1000.0 / units).round())
        .filter(|advance| advance.is_finite() && (advance - resource.default_width).abs() > 0.5);
    let width = advance.map_or_else(|| font.width(code, length), |advance| advance / 1000.0);
    let needs = (needs_text || advance.is_some()).then_some(Needs {
        cid,
        width: advance,
        text: needs_text,
        c,
    });
    Some(Composite {
        bytes,
        width,
        needs,
    })
}

/// What the operators after `events`' start need restored: nothing when the text object ends
/// or the matrix is set anew, the line matrix before a move to the next line, both otherwise.
fn need_after(events: &[Event]) -> Need {
    for event in events {
        match event.name.as_slice() {
            b"ET" | b"BT" | b"Tm" => return Need::Nothing,
            b"Td" | b"TD" | b"T*" | b"'" | b"\"" => return Need::LineMatrix,
            name if PASSIVE.contains(&name) || name == b"DP" || name == b"ri" => {}
            _ => return Need::Both,
        }
    }
    Need::Nothing
}

/// A part of a `TJ` array.
enum Item {
    Text(Vec<u8>),
    Number(f32),
}

/// Writes the pending `items` as one show and clears them: `Tj` for a single string when the
/// line had no `TJ`, else `TJ`; its strings in hex when `hex`.
fn flush(out: &mut Vec<u8>, items: &mut Vec<Item>, tj: bool, hex: bool) -> Result<(), Unsupported> {
    let string = if hex { hex_string } else { string };
    match items.as_slice() {
        [] => return Ok(()),
        [Item::Text(bytes)] if !tj => {
            space(out);
            string(out, bytes);
            out.extend_from_slice(b" Tj");
        }
        _ => {
            space(out);
            out.push(b'[');
            for (at, item) in items.iter().enumerate() {
                match item {
                    Item::Text(bytes) => string(out, bytes),
                    Item::Number(n) => {
                        if at > 0 {
                            out.push(b' ');
                        }
                        number(out, *n)?;
                        out.push(b' ');
                    }
                }
            }
            if out.last() == Some(&b' ') {
                out.pop();
            }
            out.extend_from_slice(b"] TJ");
        }
    }
    items.clear();
    Ok(())
}

/// Emits what takes the text state from `sim` to `target`'s: the font and size, `Tc`, `Tw`,
/// `Tz`, `TL`, `Ts`, `Tr`, and the matrices `need` names.
fn restore(
    out: &mut Vec<u8>,
    sim: &mut Sim,
    target: &GraphicsState,
    need: Need,
) -> Result<(), Unsupported> {
    if sim.font != target.font || sim.size != target.size {
        let name = target.font_name.as_ref().ok_or(Unsupported::Operators)?;
        set_font(out, name, target.size)?;
        sim.font = target.font;
        sim.size = target.size;
    }
    let set = |out: &mut Vec<u8>, now: f32, then: f32, operator: &[u8]| {
        if now != then {
            space(out);
            number(out, then)?;
            out.push(b' ');
            out.extend_from_slice(operator);
        }
        Ok::<(), Unsupported>(())
    };
    set(out, sim.char_spacing, target.char_spacing, b"Tc")?;
    set(out, sim.word_spacing, target.word_spacing, b"Tw")?;
    set(
        out,
        sim.horizontal_scaling * 100.0,
        target.horizontal_scaling * 100.0,
        b"Tz",
    )?;
    set(out, sim.leading, target.leading, b"TL")?;
    set(out, sim.rise, target.rise, b"Ts")?;
    set(
        out,
        f32::from(sim.render_mode),
        f32::from(target.render_mode),
        b"Tr",
    )?;
    sim.char_spacing = target.char_spacing;
    sim.word_spacing = target.word_spacing;
    sim.horizontal_scaling = target.horizontal_scaling;
    sim.leading = target.leading;
    sim.rise = target.rise;
    sim.render_mode = target.render_mode;
    let line_differs = !same(sim.line_matrix, target.line_matrix);
    let text_differs = need == Need::Both && !same(sim.text_matrix, target.text_matrix);
    if need == Need::Nothing || !(line_differs || text_differs) {
        return Ok(());
    }
    space(out);
    for value in target.line_matrix {
        number(out, value)?;
        out.push(b' ');
    }
    out.extend_from_slice(b"Tm");
    sim.line_matrix = target.line_matrix;
    sim.text_matrix = target.line_matrix;
    if need == Need::Both && !same(sim.text_matrix, target.text_matrix) {
        // A show moves the text matrix alone: an empty `TJ` with the distance left.
        let [a, b, ..] = target.line_matrix;
        let [_, _, _, _, e, f] = target.text_matrix;
        let [_, _, _, _, e0, f0] = target.line_matrix;
        let length = a * a + b * b;
        let unit = target.size * target.horizontal_scaling / 1000.0;
        if length == 0.0 || unit == 0.0 || target.font.is_none() {
            return Err(Unsupported::Operators);
        }
        let dx = ((e - e0) * a + (f - f0) * b) / length;
        let moved = multiply([1.0, 0.0, 0.0, 1.0, dx, 0.0], target.line_matrix);
        if !same(moved, target.text_matrix) {
            return Err(Unsupported::Operators);
        }
        space(out);
        out.push(b'[');
        number(out, -dx / unit)?;
        out.extend_from_slice(b"] TJ");
        sim.text_matrix = target.text_matrix;
    }
    Ok(())
}

/// A space before the next token, unless the output is empty or ends in one.
fn space(out: &mut Vec<u8>) {
    if out.last().is_some_and(|&byte| byte != b' ') {
        out.push(b' ');
    }
}

/// `/name size Tf`.
fn set_font(out: &mut Vec<u8>, name: &[u8], size: f32) -> Result<(), Unsupported> {
    space(out);
    out.push(b'/');
    for &byte in name {
        if byte.is_ascii_graphic() && !b"()<>[]{}/%#".contains(&byte) {
            out.push(byte);
        } else {
            out.extend_from_slice(format!("#{byte:02X}").as_bytes());
        }
    }
    out.push(b' ');
    number(out, size)?;
    out.extend_from_slice(b" Tf");
    Ok(())
}

/// A number in the shortest form that reads back as the same `f32`, without an exponent; none
/// for an infinity or NaN, which hostile sizes and matrices can give and PDF cannot write.
fn number(out: &mut Vec<u8>, value: f32) -> Result<(), Unsupported> {
    if !value.is_finite() {
        return Err(Unsupported::Operators);
    }
    let value = if value == 0.0 { 0.0 } else { value };
    out.extend_from_slice(format!("{value}").as_bytes());
    Ok(())
}

/// A literal string: `(`, `)` and `\` escaped, bytes outside printable ASCII in octal.
fn string(out: &mut Vec<u8>, bytes: &[u8]) {
    out.push(b'(');
    for &byte in bytes {
        match byte {
            b'(' | b')' | b'\\' => out.extend_from_slice(&[b'\\', byte]),
            0x20..=0x7E => out.push(byte),
            _ => out.extend_from_slice(format!("\\{byte:03o}").as_bytes()),
        }
    }
    out.push(b')');
}

/// A hex string, `<…>`.
fn hex_string(out: &mut Vec<u8>, bytes: &[u8]) {
    out.push(b'<');
    for byte in bytes {
        out.extend_from_slice(format!("{byte:02X}").as_bytes());
    }
    out.push(b'>');
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    #[test]
    fn composite_runs_are_written_in_hex() {
        let mut out = Vec::new();
        hex_string(&mut out, &[0x00, 0x0A, 0x82, 0xFF]);
        assert_eq!(out, b"<000A82FF>");
        let mut out = Vec::new();
        let mut items = vec![
            Item::Text(vec![0x01, 0x02]),
            Item::Number(-250.0),
            Item::Text(vec![0x82, 0xA0]),
        ];
        flush(&mut out, &mut items, false, true).unwrap();
        assert_eq!(out, b"[<0102> -250 <82A0>] TJ");
        let mut items = vec![Item::Text(vec![0x30, 0x42])];
        let mut out = Vec::new();
        flush(&mut out, &mut items, false, true).unwrap();
        assert_eq!(out, b"<3042> Tj");
        assert!(items.is_empty());
    }

    #[test]
    fn strings_escape_what_a_literal_cannot_hold() {
        let mut out = Vec::new();
        string(&mut out, b"a(b)c\\d\r\n\xF0 ");
        assert_eq!(out, b"(a\\(b\\)c\\\\d\\015\\012\\360 )");
    }

    #[test]
    fn numbers_read_back_exactly_without_exponents() {
        for value in [0.0_f32, -0.0, 1.0, 745.41, 1e-7, -2.305, 123_456.79, 0.001] {
            let mut out = Vec::new();
            number(&mut out, value).unwrap();
            let text = String::from_utf8(out).unwrap();
            assert!(
                !text.contains('e') && !text.starts_with("-0") || value < 0.0,
                "{text}"
            );
            assert_eq!(text.parse::<f32>().unwrap(), value, "{text}");
        }
    }

    #[test]
    fn font_names_escape_delimiters() {
        let mut out = Vec::new();
        set_font(&mut out, b"F 1#", 11.5).unwrap();
        assert_eq!(out, b"/F#201#23 11.5 Tf");
    }

    #[test]
    fn numbers_pdf_cannot_write_are_refused() {
        for value in [f32::INFINITY, f32::NEG_INFINITY, f32::NAN] {
            assert_eq!(number(&mut Vec::new(), value), Err(Unsupported::Operators));
        }
    }

    #[test]
    fn matrices_invert() {
        let m = [0.0, 2.0, -2.0, 0.0, 10.0, 20.0];
        let inverse = invert(m).unwrap();
        let [x, y] = apply(inverse, apply(m, [3.0, 4.0]));
        assert!((x - 3.0).abs() < 1e-5 && (y - 4.0).abs() < 1e-5);
        assert_eq!(invert([1.0, 1.0, 1.0, 1.0, 0.0, 0.0]), None);
    }

    #[test]
    fn later_operators_decide_what_is_restored() {
        let event = |name: &[u8]| Event {
            name: name.to_vec(),
            span: Span {
                source: SpanSource::Page { stream: (1, 0) },
                range: 0..0,
                carried: false,
            },
            state: GraphicsState::default(),
            show: None,
        };
        assert!(need_after(&[event(b"Tw"), event(b"ET")]) == Need::Nothing);
        assert!(need_after(&[event(b"rg"), event(b"Td")]) == Need::LineMatrix);
        assert!(need_after(&[event(b"Tf"), event(b"Tj")]) == Need::Both);
        assert!(need_after(&[event(b"Do")]) == Need::Both);
        assert!(need_after(&[]) == Need::Nothing);
    }
}
