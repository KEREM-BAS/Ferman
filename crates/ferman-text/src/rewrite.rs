//! A block's new text as new operators in its own fonts (docs/ARCHITECTURE.md §6.6, ADR 0005,
//! ROADMAP §7 step 3): the [`Splice`]s that replace exactly the operators of the lines that
//! changed, for simple fonts.
//!
//! - **Re-encoding.** Each new character becomes a code of a simple font of its line (Type1 with
//!   the standard 14, TrueType symbolic or not, Type3) whose text reads back as the character
//!   through the font's ToUnicode CMap or encoding (Standard, WinAnsi, MacRoman, `/Differences`)
//!   and whose glyph the font has: the embedded program's, a standard 14 font's metrics, a Type3
//!   font's `/CharProcs`. The font of the character before it is tried first, then the one after
//!   it, then the line's others. A character no font of the line can draw is reported
//!   ([`Outcome::MissingGlyphs`]), never substituted; the missing-glyph steps come with W3.
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
//! - **Justification (W1).** `Tw` stays as it was, so new spaces stretch like the old ones; a
//!   line justified by `TJ` gives new spaces (or, glyph by glyph, new glyphs) the line's mean
//!   adjustment. Exact re-justification, reflow and the overflow choices are W2: a line wider
//!   than its frame is still written and listed in [`Rewrite::overflowing`].
//!
//! Strings are written as literal strings with `\(`, `\)`, `\\` and octal escapes; the original
//! operator's string form is not visible here, since spans carry no bytes.
//!
//! Not rewritten yet ([`Unsupported`]): right-to-left and vertical lines, another number of lines,
//! a new character only a composite font of the line could draw, and lines whose operators are
//! not a plain run of shows (marked content, colour or other operators inside, a show shared with
//! another line, a split operator, different spacing between the shows, a shifted baseline).
//! Marked content around a line, such as `/ActualText`, is kept as it is.
// Positions, codes and spans come from files (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::HashMap;
use std::ops::Range;

use ferman_core::Document;
use ferman_core::interpret::{
    FontResource, GraphicsState, Matrix, OperatorEvent, Span, SpanSource, TextShow, TextSink,
    multiply,
};
use ferman_core::revision::RevisionStore;
use ferman_fonts::FontProgram;

use crate::TextError;
use crate::extract::{Collector, PdfFont, displayed, glyph_box};
use crate::layout::{Justification, Line, TextBlock, TextChar, TextDirection};

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
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Rewrite {
    /// One splice per changed line, in the block's line order; none when no line changed.
    pub splices: Vec<Splice>,
    /// The lines, as indices into the block's lines, whose new text runs past the block's frame.
    /// They are written as they are; reflow and the overflow choices are W2.
    pub overflowing: Vec<usize>,
}

/// What rewriting a block gives.
#[derive(Debug, Clone, PartialEq, Eq)]
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
    /// The new text has another number of lines: reflow is W2.
    LineCount,
    /// The block runs right to left or vertically.
    Direction,
    /// A new character could only come from a composite font of its line.
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
    rewrite_through(document, None, index, block, text)
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
    rewrite_through(document, Some(revisions), index, block, text)
}

fn rewrite_through(
    document: &Document,
    revisions: Option<&RevisionStore>,
    index: usize,
    block: &TextBlock,
    text: &str,
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
    if texts.len() != block.lines.len() {
        return Ok(Outcome::Unsupported(Unsupported::LineCount));
    }
    let mut recorder = Recorder::default();
    match revisions {
        Some(revisions) => revisions.page_text(document, index, &mut recorder)?,
        None => document.page_text(index, &mut recorder)?,
    }
    let page = Page::new(&recorder, document.structure().pages.get(index));
    let frame = Frame::of(block);
    let mut rewrite = Rewrite::default();
    let mut missing: Vec<char> = Vec::new();
    for (at, (line, new)) in block.lines.iter().zip(texts).enumerate() {
        if line.text == new {
            continue;
        }
        match page.line(line, new, block.justification, &frame) {
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
    Ok(Outcome::Rewritten(rewrite))
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

    /// The splice for one changed line.
    fn line(
        &self,
        line: &Line,
        new: &str,
        justification: Option<Justification>,
        frame: &Frame,
    ) -> Result<Planned, Unsupported> {
        let recorder = self.recorder;
        let glyphs = &recorder.collector.glyphs;
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
        let line_glyphs: Vec<usize> = units.iter().filter_map(|unit| unit.glyph).collect();
        if line_glyphs.is_empty()
            || line_glyphs
                .windows(2)
                .any(|pair| matches!(pair, [a, b] if a >= b))
        {
            return Err(Unsupported::Operators);
        }
        let show_of = |glyph: usize| recorder.glyph_shows.get(glyph).copied();
        let mut shows: Vec<usize> = line_glyphs.iter().filter_map(|&g| show_of(g)).collect();
        shows.dedup();
        let in_line = |glyph: usize| line_glyphs.binary_search(&glyph).is_ok();
        for &show in &shows {
            let all = recorder
                .shows
                .get(show)
                .is_some_and(|show| show.glyphs.clone().all(in_line));
            if !all {
                return Err(Unsupported::Operators);
            }
        }
        let (Some(&first_show), Some(&last_show)) = (shows.first(), shows.last()) else {
            return Err(Unsupported::Operators);
        };
        let (Some(&first), Some(&last)) = (
            self.show_events.get(&first_show),
            self.show_events.get(&last_show),
        ) else {
            return Err(Unsupported::Operators);
        };
        let events = recorder
            .events
            .get(first..=last)
            .ok_or(Unsupported::Operators)?;
        let head = events.first().ok_or(Unsupported::Operators)?;
        let source = head.span.source;
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
        let range = head.span.range.start
            ..events
                .last()
                .map_or(head.span.range.end, |event| event.span.range.end);
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
            let alike = other.char_spacing == state.char_spacing
                && other.word_spacing == state.word_spacing
                && other.horizontal_scaling == state.horizontal_scaling
                && other.rise == state.rise
                && other.render_mode == state.render_mode
                && other.fill == state.fill
                && other.stroke == state.stroke
                && other.ctm == state.ctm
                && other.text_matrix.get(..4) == state.text_matrix.get(..4);
            if !alike {
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
        // The fonts of the line, with the name and size its shows set them with.
        let mut fonts: Vec<(u64, Vec<u8>, f32)> = Vec::new();
        for &show in &shows {
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
        let font_of = |g: usize| glyphs.get(g).map(|glyph| glyph.font);
        let next_font = units
            .get(kept_tail)
            .and_then(|unit| unit.glyph)
            .and_then(font_of);
        let mut programs: HashMap<u64, Option<FontProgram<'_>>> = HashMap::new();
        let mut placed: Vec<Placed> = Vec::new();
        let mut missing = Vec::new();
        let mut composite = false;
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
            let order = previous
                .into_iter()
                .chain(next_font)
                .chain(fonts.iter().map(|(key, ..)| *key));
            let mut chosen = None;
            for key in order {
                let Some(font) = recorder.collector.fonts.get(&key) else {
                    continue;
                };
                if font.cmap.is_some() {
                    composite = true;
                    continue;
                }
                let program = programs.entry(key).or_insert_with(|| font.program());
                if let Some(code) = encode(font, program.as_ref(), c) {
                    chosen = Some((key, font, code));
                    break;
                }
            }
            match chosen {
                Some((key, font, code)) => {
                    let size = fonts
                        .iter()
                        .find(|(font, ..)| *font == key)
                        .map_or(state.size, |(_, _, size)| *size);
                    let spacing =
                        state.char_spacing + if code == 32 { state.word_spacing } else { 0.0 };
                    let advance = (font.width(u32::from(code), 1) * size + spacing) * scaling;
                    placed.push(Placed {
                        font: key,
                        size,
                        bytes: vec![code],
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
            return if composite {
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
        let name_of = |key: u64| {
            fonts
                .iter()
                .find(|(font, ..)| *font == key)
                .map(|(_, name, _)| name.clone())
        };
        let mut natural = 0.0_f32;
        let mut items: Vec<Item> = Vec::new();
        for glyph in &placed {
            if sim.font != Some(glyph.font) || sim.size != glyph.size {
                flush(&mut out, &mut items, tj)?;
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
        flush(&mut out, &mut items, tj)?;
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
/// line had no `TJ`, else `TJ`.
fn flush(out: &mut Vec<u8>, items: &mut Vec<Item>, tj: bool) -> Result<(), Unsupported> {
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

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

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
