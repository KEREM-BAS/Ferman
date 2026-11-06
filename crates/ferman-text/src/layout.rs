//! The text model (docs/ARCHITECTURE.md §6.4 and §6.5): a page's glyphs as words, lines and
//! blocks (paragraph frames) with their alignment and justification method, columns, table
//! columns, reading order, block ids and editability.
//!
//! - **Lines.** The glyphs that share a baseline in content order, as [`extract`](crate::extract)
//!   groups them, split where one show ends and the next starts more than an em away: a table's
//!   cells or two columns side by side. A line's direction comes from its glyphs, so turned text
//!   groups in its own text space.
//! - **Blocks.** A line joins the block whose last line is one leading above it, at the same size,
//!   overlapping it along the line, and with a left, right or centre edge in common with it; a
//!   block keeps one leading. A justified block ends after its unstretched last line, and a
//!   stretched line never follows an unstretched one in a block.
//! - **Alignment.** Stretched lines make a block justified, by `Tw` word spacing or `TJ`
//!   adjustments after spaces; lines without spaces flush on both sides with more spacing per
//!   glyph than the last are justified glyph by glyph. Otherwise the shared edge of the lines; a
//!   one-line block takes its table column's alignment, or the page's text edge it touches, or
//!   the centre of the page's text.
//! - **Reading order.** Blocks whose extents in y overlap form a band; bands go from the top.
//!   Inside a band, single lines go row by row and longer blocks column by column, from the right
//!   on a right-to-left page; vertical text goes from the right.
//! - **Columns.** A block's column is its rank from the left among the blocks whose extent in y
//!   overlaps its own.
//! - **Tables.** At least two consecutive bands of two or more single-line blocks, one of them
//!   with three or more, each close below the last: the cells' extents along the line cluster into
//!   columns, and a column's alignment is the edge its cells share.
//! - **Block ids.** [`BlockId`] is the FNV-1a hash of the first glyph's operator (its stream or
//!   form object, its offset in that stream's decoded data) and the glyph's index in the show,
//!   with the number of earlier blocks of the page that hash the same (a form placed twice):
//!   the same for the same content on every run.
//!
//! Geometry is in page space: points from the top-left of the displayed page, y down
//! (docs/ARCHITECTURE.md §3.3).

use std::collections::HashMap;
use std::ops::Range;

use ferman_core::interpret::SpanSource;
use ferman_core::revision::RevisionStore;
use ferman_core::{CoreError, Document};

use crate::TextError;
use crate::editability::{Complexity, EditContext, Editability, NotEditableReason, overlaps};
use crate::extract::{
    self, CharBox, Collector, Glyph, GlyphLink, displayed, glyph_box, line_groups, right_to_left,
    words,
};

/// The gap between two shows on one baseline, in ems, from which they are two lines.
const SPLIT_GAP: f32 = 1.0;
/// The largest distance between the baselines of a block's first two lines, in ems: after an
/// unstretched line, and after a stretched one (which never ends a paragraph).
const MAX_PITCH: f32 = 2.0;
const MAX_PITCH_STRETCHED: f32 = 2.5;
/// The same for lines with another line beside them on their baseline, as the rows of a grid.
const MAX_PITCH_BESIDE: f32 = 1.75;
/// The most lines a page is laid out from: grouping compares lines pairwise, so a hostile page
/// with more gets one block per line in content order, each [`Complexity::Limits`].
const MAX_LINES: usize = 10_000;

/// A block's id on its page, the same for the same content (module documentation).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct BlockId(pub u64);

/// The direction text runs in.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub enum TextDirection {
    /// Left to right.
    #[default]
    LeftToRight,
    /// Right to left: Arabic, Persian, Hebrew.
    RightToLeft,
    /// Vertical columns, from the top, the columns from the right.
    Vertical,
}

/// How a block's lines sit in its frame. Vertical text's start (top) is `Left` and its end
/// `Right`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Alignment {
    /// Flush left.
    Left,
    /// Flush right.
    Right,
    /// Centred.
    Center,
    /// Flush on both sides, but for the last line.
    Justified,
}

/// How a justified block stretches its lines, so an edit stretches them the same way.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Justification {
    /// `Tw` word spacing.
    WordSpacing,
    /// `TJ` adjustments after the spaces.
    Adjustments,
    /// Extra space after every glyph (`Tc` or `TJ`), in text without spaces.
    Glyphs,
}

/// One character of a line.
#[derive(Debug, Clone, PartialEq)]
pub struct TextChar {
    /// The character.
    pub ch: char,
    /// The box of the glyph that drew it, `[left, top, right, bottom]`; `None` for a space no
    /// glyph drew.
    pub bbox: Option<CharBox>,
    /// The glyph's operator and its index in it.
    pub glyph: Option<GlyphLink>,
}

/// One line of a block.
#[derive(Debug, Clone, PartialEq)]
pub struct Line {
    /// Its text in logical order, words separated by spaces.
    pub text: String,
    /// One per character of `text`.
    pub chars: Vec<TextChar>,
    /// Its words, as ranges of `chars`.
    pub words: Vec<Range<usize>>,
    /// The box of its glyphs.
    pub bbox: CharBox,
    /// Its baseline from the start of its first glyph to the end of its last, in visual order
    /// (from the top in vertical text).
    pub baseline: [[f32; 2]; 2],
    /// Its largest font size.
    pub size: f32,
    /// The direction it runs in.
    pub direction: TextDirection,
}

/// A paragraph frame.
#[derive(Debug, Clone, PartialEq)]
pub struct TextBlock {
    /// Its id (module documentation).
    pub id: BlockId,
    /// The box of its lines.
    pub bbox: CharBox,
    /// Its lines, from the first.
    pub lines: Vec<Line>,
    /// How its lines sit.
    pub alignment: Alignment,
    /// How it is justified, when it is.
    pub justification: Option<Justification>,
    /// The direction its text runs in.
    pub direction: TextDirection,
    /// Its rank from the left among the blocks beside it.
    pub column: usize,
    /// Its table cell.
    pub cell: Option<TableCell>,
    /// Whether it can be edited.
    pub editability: Editability,
    /// The language tag of most of its characters: `/Lang` of the marked content around them,
    /// else of their structure element (or its ancestors); `None` when most have neither.
    pub language: Option<String>,
}

impl TextBlock {
    /// Its text: the lines joined by line feeds.
    #[must_use]
    pub fn text(&self) -> String {
        let lines: Vec<&str> = self.lines.iter().map(|line| line.text.as_str()).collect();
        lines.join("\n")
    }
}

/// A table's column, in page space.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TableColumn {
    /// Its left edge.
    pub left: f32,
    /// Its right edge.
    pub right: f32,
    /// The edge its cells share: a column of amounts is `Right`.
    pub alignment: Alignment,
}

/// A table found on the page: its columns, for edits inside a cell (a3-9).
#[derive(Debug, Clone, PartialEq)]
pub struct Table {
    /// Its columns, from the left.
    pub columns: Vec<TableColumn>,
    /// How many rows it has.
    pub rows: usize,
}

/// Where a block is in a table.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TableCell {
    /// The table's index in [`PageText::tables`].
    pub table: usize,
    /// The row, from the top.
    pub row: usize,
    /// The column, from the left.
    pub column: usize,
}

/// A page's text model.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct PageText {
    /// Its blocks in reading order.
    pub blocks: Vec<TextBlock>,
    /// Its tables.
    pub tables: Vec<Table>,
    /// The direction most of its lines run in.
    pub direction: TextDirection,
    /// Why a page without blocks has no text to edit: [`NotEditableReason::ImageOnly`] or
    /// [`NotEditableReason::OutlinedText`].
    pub empty: Option<NotEditableReason>,
}

/// The text model of page `index`, with what `context` says about the document.
///
/// # Errors
///
/// [`TextError::Core`] when the page cannot be interpreted; a resource limit is not an error but
/// makes every block [`Complexity::Limits`].
pub fn text_page(
    document: &Document,
    index: usize,
    context: &EditContext,
) -> Result<PageText, TextError> {
    text_page_through(document, None, index, context)
}

/// [`text_page`] of the document as `revisions` changed it: its current revision and its open
/// transaction.
///
/// # Errors
///
/// As [`text_page`].
pub fn text_page_revised(
    document: &Document,
    revisions: &RevisionStore,
    index: usize,
    context: &EditContext,
) -> Result<PageText, TextError> {
    text_page_through(document, Some(revisions), index, context)
}

fn text_page_through(
    document: &Document,
    revisions: Option<&RevisionStore>,
    index: usize,
    context: &EditContext,
) -> Result<PageText, TextError> {
    let mut collector = Collector::default();
    let interpreted = match revisions {
        Some(revisions) => revisions.page_text(document, index, &mut collector),
        None => document.page_text(index, &mut collector),
    };
    let limited = match interpreted {
        Ok(()) => false,
        Err(CoreError::ResourceLimit { .. }) => true,
        Err(err) => return Err(err.into()),
    };
    collector.finish();
    let page = document.pages_through(revisions).get(index);
    let mut model = build(&collector.glyphs, page, context, limited);
    if model.blocks.is_empty() {
        model.empty = empty_reason(collector.images, collector.paths);
    }
    let tagged = if collector.show_mcids.is_empty() {
        HashMap::new()
    } else {
        let wanted = collector.show_mcids.values().copied().collect();
        document.marked_content_languages(revisions, index, &wanted)
    };
    for block in &mut model.blocks {
        block.language = block_language(block, &collector, &tagged);
    }
    Ok(model)
}

/// The language most of `block`'s characters are in; `None` when most have none.
fn block_language(
    block: &TextBlock,
    collector: &Collector,
    tagged: &HashMap<i64, String>,
) -> Option<String> {
    let mut counts: Vec<(Option<&str>, usize)> = Vec::new();
    for link in block
        .lines
        .iter()
        .flat_map(|line| &line.chars)
        .filter_map(|c| c.glyph.as_ref())
    {
        let key = (link.span.source, link.span.range.start);
        // A form's marked-content ids belong to the form's own structure parents.
        let language = collector.show_languages.get(&key).or_else(|| {
            matches!(link.span.source, SpanSource::Page { .. })
                .then(|| collector.show_mcids.get(&key))
                .flatten()
                .and_then(|mcid| tagged.get(mcid))
        });
        let language = language.map(String::as_str);
        match counts.iter_mut().find(|(seen, _)| *seen == language) {
            Some((_, count)) => *count = count.saturating_add(1),
            None => counts.push((language, 1)),
        }
    }
    let mut best: Option<(Option<&str>, usize)> = None;
    for entry in counts {
        if best.is_none_or(|(_, count)| entry.1 > count) {
            best = Some(entry);
        }
    }
    best.and_then(|(language, _)| language).map(str::to_owned)
}

/// Why a page without text has none to edit: a scan, or text drawn as shapes.
fn empty_reason(images: bool, paths: bool) -> Option<NotEditableReason> {
    if images {
        Some(NotEditableReason::ImageOnly)
    } else if paths {
        Some(NotEditableReason::OutlinedText)
    } else {
        None
    }
}

/// One line before it joins a block: its glyphs, its characters and its geometry in user space.
#[derive(Debug, Clone)]
struct Frag {
    chars: extract::Line,
    /// The unit vector along the line, and the one across it (towards the line above).
    along: [f32; 2],
    across: [f32; 2],
    vertical: bool,
    rtl: bool,
    size: f32,
    /// The baseline's position across.
    offset: f32,
    /// The extent of its glyphs along the line, spaces at its ends left out.
    low: f32,
    high: f32,
    /// How it is stretched, if it is.
    stretched: Option<Justification>,
    /// Whether it has a space.
    spaces: bool,
    /// The mean spacing after each glyph, in thousandths of an em.
    spacing: f32,
    /// Its first glyph in content order.
    first: usize,
    /// The extents of its baseline in user space, `(x, y)` low and high, for bands and columns.
    x_span: (f32, f32),
    y_span: (f32, f32),
    /// Whether it is a table cell: a line beside another on its baseline, one of them a number.
    cell: bool,
    /// Whether another line is beside it on its baseline.
    beside: bool,
}

fn dot(a: [f32; 2], b: [f32; 2]) -> f32 {
    a[0] * b[0] + a[1] * b[1]
}

/// The tolerance for edges that line up.
fn tolerance(size: f32) -> f32 {
    (size * 0.08).max(0.5)
}

/// The glyphs as lines, split at the gaps between shows.
fn frags(glyphs: &[Glyph]) -> Vec<Frag> {
    let mut out = Vec::new();
    for group in collinear(line_groups(glyphs)) {
        let mut piece: Vec<(usize, &Glyph)> = Vec::new();
        for (at, glyph) in group {
            if let Some((_, last)) = piece.last() {
                let size = last.size.max(glyph.size);
                let along = direction(last);
                let gap = (dot(glyph.start, along) - dot(last.end, along))
                    .max(dot(last.start, along) - dot(glyph.end, along));
                if glyph.show != last.show && gap > size * SPLIT_GAP {
                    out.extend(frag(&std::mem::take(&mut piece)));
                }
            }
            piece.push((at, glyph));
        }
        out.extend(frag(&piece));
    }
    out
}

/// `groups` with each one that continues the one before on the same baseline, as turned text
/// does, joined to it.
fn collinear(groups: Vec<Vec<(usize, &Glyph)>>) -> Vec<Vec<(usize, &Glyph)>> {
    let mut out: Vec<Vec<(usize, &Glyph)>> = Vec::new();
    for group in groups {
        let continues = match (out.last().and_then(|line| line.last()), group.first()) {
            (Some((_, last)), Some((_, next))) if !last.vertical && !next.vertical => {
                let along = direction(last);
                let across = [-along[1], along[0]];
                let size = last.size.max(next.size);
                along[0] < 0.999
                    && dot(direction(next), along) > 0.999
                    && (dot(last.start, across) - dot(next.start, across)).abs() <= tolerance(size)
                    && (dot(next.start, along) - dot(last.end, along)).abs() <= size * SPLIT_GAP
            }
            _ => false,
        };
        match out.last_mut() {
            Some(line) if continues => line.extend(group),
            _ => out.push(group),
        }
    }
    out
}

/// The unit vector a glyph advances along.
fn direction(glyph: &Glyph) -> [f32; 2] {
    let [dx, dy] = [glyph.end[0] - glyph.start[0], glyph.end[1] - glyph.start[1]];
    let length = dx.hypot(dy);
    if length > 1e-4 {
        [dx / length, dy / length]
    } else if glyph.vertical {
        [0.0, -1.0]
    } else {
        [1.0, 0.0]
    }
}

fn frag(piece: &[(usize, &Glyph)]) -> Option<Frag> {
    let (first, _) = *piece.first()?;
    let vertical = piece.iter().any(|(_, glyph)| glyph.vertical);
    let lead = piece
        .iter()
        .find(|(_, glyph)| glyph.vertical == vertical && !glyph.space && glyph.start != glyph.end)
        .or_else(|| piece.first())
        .map(|(_, glyph)| *glyph)?;
    let along = direction(lead);
    let along = if vertical { [0.0, -1.0] } else { along };
    let across = [-along[1], along[0]];
    let size = piece
        .iter()
        .map(|(_, glyph)| glyph.size)
        .fold(0.0, f32::max);
    let biggest = piece
        .iter()
        .find(|(_, glyph)| glyph.size >= size)
        .map_or(lead, |(_, glyph)| *glyph);
    let inked: Vec<&Glyph> = piece
        .iter()
        .map(|(_, glyph)| *glyph)
        .filter(|glyph| !glyph.text.chars().all(char::is_whitespace))
        .collect();
    let ends = if inked.is_empty() {
        piece.iter().map(|(_, glyph)| *glyph).collect()
    } else {
        inked
    };
    let mut low = f32::INFINITY;
    let mut high = f32::NEG_INFINITY;
    let mut xs = (f32::INFINITY, f32::NEG_INFINITY);
    let mut ys = (f32::INFINITY, f32::NEG_INFINITY);
    for glyph in &ends {
        for point in [glyph.start, glyph.end] {
            low = low.min(dot(point, along));
            high = high.max(dot(point, along));
        }
    }
    // The baseline's ends, for bands and columns: as the ground truth measures them.
    let offset = dot(biggest.start, across);
    for point in [
        [
            along[0] * low + across[0] * offset,
            along[1] * low + across[1] * offset,
        ],
        [
            along[0] * high + across[0] * offset,
            along[1] * high + across[1] * offset,
        ],
    ] {
        xs = (xs.0.min(point[0]), xs.1.max(point[0]));
        ys = (ys.0.min(point[1]), ys.1.max(point[1]));
    }
    let (x_span, y_span) = if vertical {
        ((xs.0 - size / 2.0, xs.1 + size / 2.0), ys)
    } else {
        (xs, (ys.0 - size * 0.2, ys.1 + size * 0.8))
    };
    let space_glyphs = || {
        piece.iter().map(|(_, glyph)| *glyph).filter(|glyph| {
            glyph.space || (!glyph.text.is_empty() && glyph.text.chars().all(char::is_whitespace))
        })
    };
    let stretched = if space_glyphs().any(|glyph| glyph.word_spacing.abs() > 0.01) {
        Some(Justification::WordSpacing)
    } else if space_glyphs().any(|glyph| glyph.adjust < -0.5) {
        Some(Justification::Adjustments)
    } else {
        None
    };
    #[allow(clippy::cast_precision_loss)]
    let count = piece.len().max(1) as f32;
    // shortcut: Tc is taken at the page's font size (no CTM scale); exact once a block needs it.
    let spacing = piece
        .iter()
        .map(|(_, glyph)| {
            -glyph.adjust + glyph.char_spacing * 1000.0 / glyph.size.max(f32::MIN_POSITIVE)
        })
        .sum::<f32>()
        / count;
    let chars = words(piece);
    Some(Frag {
        rtl: chars.iter().any(|&(c, _)| right_to_left(c)),
        spaces: chars.iter().any(|&(c, _)| c.is_whitespace()),
        chars,
        along,
        across,
        vertical,
        size,
        offset,
        low,
        high,
        stretched,
        spacing,
        first,
        x_span,
        y_span,
        cell: false,
        beside: false,
    })
}

/// Whether `text` is a number, an amount or a percentage, such as `18.500,00` or `%20`.
fn numeric(text: &str) -> bool {
    let mut digits = false;
    for c in text.chars().filter(|c| !c.is_whitespace()) {
        if c.is_numeric() {
            digits = true;
        } else if !matches!(
            c,
            '.' | ',' | '%' | '-' | '+' | '/' | '(' | ')' | '\'' | '\u{2212}'
        ) {
            return false;
        }
    }
    digits
}

/// Marks the lines that are table cells: beside another line on their baseline, one of the two
/// a number.
fn mark_cells(frags: &mut [Frag]) {
    let numbers: Vec<bool> = frags
        .iter()
        .map(|frag| numeric(&frag.chars.iter().map(|&(c, _)| c).collect::<String>()))
        .collect();
    let mut cells = vec![false; frags.len()];
    let mut besides = vec![false; frags.len()];
    for (a, first) in frags.iter().enumerate() {
        for (b, second) in frags.iter().enumerate().skip(a.saturating_add(1)) {
            let beside = first.vertical == second.vertical
                && dot(first.along, second.along) > 0.999
                && (first.offset - second.offset).abs() <= tolerance(first.size.max(second.size))
                && (first.high <= second.low || second.high <= first.low);
            if beside {
                for at in [a, b] {
                    if let Some(slot) = besides.get_mut(at) {
                        *slot = true;
                    }
                }
            }
            if beside && (numbers.get(a) == Some(&true) || numbers.get(b) == Some(&true)) {
                for at in [a, b] {
                    if let Some(cell) = cells.get_mut(at) {
                        *cell = true;
                    }
                }
            }
        }
    }
    for ((frag, cell), beside) in frags.iter_mut().zip(cells).zip(besides) {
        frag.cell = cell;
        frag.beside = beside;
    }
}

/// The edges two lines share: left, right, centre.
fn shared_edges(a: &Frag, b: &Frag) -> [bool; 3] {
    let tol = tolerance(a.size.max(b.size));
    [
        (a.low - b.low).abs() <= tol,
        (a.high - b.high).abs() <= tol,
        ((a.low + a.high) / 2.0 - (b.low + b.high) / 2.0).abs() <= tol,
    ]
}

/// A block being built: its lines as indices of the fragments.
struct Building {
    lines: Vec<usize>,
    /// The edges every pair of consecutive lines shares.
    edges: [bool; 3],
    pitch: f32,
}

/// The distance from each line to the nearest line below it that could continue it.
fn follow(frags: &[Frag]) -> Vec<Option<f32>> {
    frags
        .iter()
        .map(|line| {
            frags
                .iter()
                .filter(|other| {
                    other.vertical == line.vertical
                        && dot(other.along, line.along) > 0.999
                        && (other.size - line.size).abs() <= 0.1
                        && other.low < line.high
                        && line.low < other.high
                        && !other.cell
                })
                .map(|other| line.offset - other.offset)
                .filter(|&pitch| pitch >= line.size * 0.5 && pitch <= line.size * MAX_PITCH)
                .min_by(f32::total_cmp)
        })
        .collect()
}

/// The lines grouped into blocks, in content order.
fn group(frags: &[Frag]) -> Vec<Building> {
    let mut blocks: Vec<Building> = Vec::new();
    let follows = follow(frags);
    for (index, line) in frags.iter().enumerate() {
        // A line followed more closely than it follows starts a paragraph.
        let next = follows.get(index).copied().flatten();
        let mut best: Option<(usize, f32, [bool; 3])> = None;
        for (at, block) in blocks.iter().enumerate() {
            let (Some(&first), Some(&last)) = (block.lines.first(), block.lines.last()) else {
                continue;
            };
            let (Some(first), Some(last)) = (frags.get(first), frags.get(last)) else {
                continue;
            };
            if last.vertical != line.vertical || dot(last.along, line.along) < 0.999 {
                continue;
            }
            let pitch = last.offset - line.offset;
            let tol = tolerance(line.size);
            let most = if last.stretched.is_some() {
                MAX_PITCH_STRETCHED
            } else if last.beside || line.beside {
                MAX_PITCH_BESIDE
            } else {
                MAX_PITCH
            };
            let fits = if block.lines.len() >= 2 {
                (pitch - block.pitch).abs() <= tol
            } else {
                pitch >= line.size * 0.5
                    && pitch <= line.size * most
                    && next.is_none_or(|next| next >= pitch - tol)
            };
            let same_size =
                (line.size - last.size).abs() <= 0.1 && (line.size - first.size).abs() <= 0.1;
            let overlapping = line.low < last.high && last.low < line.high;
            let stretched_block = block
                .lines
                .iter()
                .any(|&n| frags.get(n).is_some_and(|frag| frag.stretched.is_some()));
            // An unstretched line flush on both sides of a justified block filled its width
            // exactly, so it ends nothing.
            let full = |frag: &Frag| {
                block
                    .lines
                    .iter()
                    .filter_map(|&n| frags.get(n))
                    .any(|other| {
                        other.stretched.is_some() && shared_edges(other, frag)[..2] == [true, true]
                    })
            };
            let ended = last.stretched.is_none() && !full(last);
            let closed = stretched_block && ended;
            let restarts = line.stretched.is_some() && ended;
            let shared = shared_edges(last, line);
            let edges = [
                block.edges[0] && shared[0],
                block.edges[1] && shared[1],
                block.edges[2] && shared[2],
            ];
            if !fits
                || !same_size
                || !overlapping
                || closed
                || restarts
                || last.cell
                || line.cell
                || edges == [false; 3]
            {
                continue;
            }
            if best.is_none_or(|(_, nearest, _)| pitch < nearest) {
                best = Some((at, pitch, edges));
            }
        }
        match best.and_then(|(at, pitch, edges)| blocks.get_mut(at).map(|b| (b, pitch, edges))) {
            Some((block, pitch, edges)) => {
                block.lines.push(index);
                block.edges = edges;
                block.pitch = pitch;
            }
            None => blocks.push(Building {
                lines: vec![index],
                edges: [true; 3],
                pitch: 0.0,
            }),
        }
    }
    blocks
}

/// A block's extent `(x, y)` in user space.
fn spans(lines: &[&Frag]) -> ((f32, f32), (f32, f32)) {
    lines.iter().fold(
        (
            (f32::INFINITY, f32::NEG_INFINITY),
            (f32::INFINITY, f32::NEG_INFINITY),
        ),
        |((x0, x1), (y0, y1)), frag| {
            (
                (x0.min(frag.x_span.0), x1.max(frag.x_span.1)),
                (y0.min(frag.y_span.0), y1.max(frag.y_span.1)),
            )
        },
    )
}

/// Whether two extents overlap.
fn overlap(a: (f32, f32), b: (f32, f32)) -> bool {
    a.0 < b.1 - 0.01 && b.0 < a.1 - 0.01
}

/// A block during analysis.
struct Draft<'f> {
    lines: Vec<&'f Frag>,
    edges: [bool; 3],
    x: (f32, f32),
    y: (f32, f32),
    alignment: Alignment,
    justification: Option<Justification>,
    cell: Option<TableCell>,
    column: usize,
}

impl Draft<'_> {
    fn single(&self) -> bool {
        self.lines.len() == 1
    }

    fn vertical(&self) -> bool {
        self.lines.first().is_some_and(|line| line.vertical)
    }

    fn rtl(&self) -> bool {
        let rtl = self.lines.iter().filter(|line| line.rtl).count();
        rtl * 2 > self.lines.len()
    }

    fn horizontal(&self) -> bool {
        self.lines
            .first()
            .is_some_and(|line| !line.vertical && line.along[0] > 0.999)
    }

    fn top(&self) -> f32 {
        self.y.1
    }
}

/// The model of a page's glyphs.
fn build(
    glyphs: &[Glyph],
    page: Option<&ferman_core::structure::Page>,
    context: &EditContext,
    limited: bool,
) -> PageText {
    let mut frags = frags(glyphs);
    let many = frags.len() > MAX_LINES;
    let limited = limited || many;
    let buildings = if many {
        (0..frags.len())
            .map(|at| Building {
                lines: vec![at],
                edges: [true; 3],
                pitch: 0.0,
            })
            .collect()
    } else {
        mark_cells(&mut frags);
        group(&frags)
    };
    let mut drafts: Vec<Draft<'_>> = buildings
        .into_iter()
        .map(|building| {
            let lines: Vec<&Frag> = building
                .lines
                .iter()
                .filter_map(|&n| frags.get(n))
                .collect();
            let (x, y) = spans(&lines);
            Draft {
                lines,
                edges: building.edges,
                x,
                y,
                alignment: Alignment::Left,
                justification: None,
                cell: None,
                column: 0,
            }
        })
        .collect();
    // The page reads right to left when most of its strong characters do.
    let (rtl, ltr) = frags.iter().flat_map(|frag| &frag.chars).fold(
        (0_usize, 0_usize),
        |(rtl, ltr), &(c, _)| match unicode_bidi::bidi_class(c) {
            unicode_bidi::BidiClass::R | unicode_bidi::BidiClass::AL => {
                (rtl.saturating_add(1), ltr)
            }
            unicode_bidi::BidiClass::L => (rtl, ltr.saturating_add(1)),
            _ => (rtl, ltr),
        },
    );
    let rtl_page = rtl > ltr;
    let vertical_page = frags.iter().filter(|frag| frag.vertical).count() * 2 > frags.len();
    let direction = if vertical_page {
        TextDirection::Vertical
    } else if rtl_page {
        TextDirection::RightToLeft
    } else {
        TextDirection::LeftToRight
    };

    let tables = if many {
        Vec::new()
    } else {
        order(&mut drafts, rtl_page)
    };
    let centre = page.map(|page| {
        let crop = &page.crop_box;
        (
            (crop.left + crop.right) / 2.0,
            (crop.bottom + crop.top) / 2.0,
        )
    });
    for at in (0..drafts.len()).filter(|_| !many) {
        let alignment = align(&drafts, at, &frags, centre);
        if let Some(draft) = drafts.get_mut(at) {
            (draft.alignment, draft.justification) = alignment;
        }
    }
    let columns: Vec<usize> = drafts
        .iter()
        .enumerate()
        .filter(|_| !many)
        .map(|(at, draft)| {
            drafts
                .iter()
                .enumerate()
                .filter(|(other, them)| {
                    *other != at
                        && overlap(draft.y, them.y)
                        && (them.x.0 < draft.x.0 || (them.x.0 == draft.x.0 && *other < at))
                })
                .count()
        })
        .collect();
    for (draft, column) in drafts.iter_mut().zip(columns) {
        draft.column = column;
    }

    let mut seen: HashMap<u64, u64> = HashMap::new();
    let blocks = drafts
        .iter()
        .map(|draft| {
            let lines: Vec<Line> = draft
                .lines
                .iter()
                .map(|frag| line(frag, glyphs, page))
                .collect();
            let bbox = lines.iter().fold(
                [
                    f32::INFINITY,
                    f32::INFINITY,
                    f32::NEG_INFINITY,
                    f32::NEG_INFINITY,
                ],
                |[l, t, r, b], line| {
                    [
                        l.min(line.bbox[0]),
                        t.min(line.bbox[1]),
                        r.max(line.bbox[2]),
                        b.max(line.bbox[3]),
                    ]
                },
            );
            let first = draft.lines.iter().map(|frag| frag.first).min();
            let hash = first
                .and_then(|first| glyphs.get(first))
                .map_or(0, |glyph| block_hash(&glyph.link));
            let repeats = seen.entry(hash).or_insert(0);
            let earlier = *repeats;
            *repeats = repeats.saturating_add(1);
            let direction = if draft.vertical() {
                TextDirection::Vertical
            } else if draft.rtl() {
                TextDirection::RightToLeft
            } else {
                TextDirection::LeftToRight
            };
            let drawn: Vec<&Glyph> = draft
                .lines
                .iter()
                .flat_map(|frag| &frag.chars)
                .filter_map(|&(_, at)| at.and_then(|at| glyphs.get(at)))
                .collect();
            let mut block = TextBlock {
                id: BlockId(fnv(hash, &earlier.to_le_bytes())),
                bbox,
                lines,
                alignment: draft.alignment,
                justification: draft.justification,
                direction,
                column: draft.column,
                cell: draft.cell,
                editability: Editability::Editable,
                language: None,
            };
            block.editability = editability(&block, &drawn, context, limited);
            block
        })
        .collect();
    let tables = tables
        .into_iter()
        .map(|(rows, columns)| Table {
            rows,
            columns: columns
                .into_iter()
                .map(|(low, high, alignment)| {
                    let left = displayed(page, [low, 0.0, low, 0.0])[0];
                    let right = displayed(page, [high, 0.0, high, 0.0])[0];
                    TableColumn {
                        left: left.min(right),
                        right: left.max(right),
                        alignment,
                    }
                })
                .collect(),
        })
        .collect();
    PageText {
        blocks,
        tables,
        direction,
        empty: None,
    }
}

const FNV_OFFSET: u64 = 0xcbf2_9ce4_8422_2325;

/// FNV-1a over `bytes`, from `hash`.
fn fnv(hash: u64, bytes: &[u8]) -> u64 {
    bytes.iter().fold(hash, |hash, &byte| {
        (hash ^ u64::from(byte)).wrapping_mul(0x0100_0000_01b3)
    })
}

/// The hash of a glyph's operator and index.
fn block_hash(link: &GlyphLink) -> u64 {
    let (kind, (number, generation)) = match link.span.source {
        SpanSource::Page { stream } => (0_u8, stream),
        SpanSource::Form { form } => (1, form),
    };
    let mut hash = fnv(FNV_OFFSET, &[kind]);
    hash = fnv(hash, &number.to_le_bytes());
    hash = fnv(hash, &generation.to_le_bytes());
    hash = fnv(
        hash,
        &u64::try_from(link.span.range.start)
            .unwrap_or(u64::MAX)
            .to_le_bytes(),
    );
    fnv(
        hash,
        &u64::try_from(link.index).unwrap_or(u64::MAX).to_le_bytes(),
    )
}

/// The table columns found on a page: per table its row count and its columns' extents in x
/// (user space) with their alignment.
type Found = Vec<(usize, Vec<(f32, f32, Alignment)>)>;

/// The x extents of `drafts`, merged where they overlap, from the left.
fn intervals<'a>(drafts: impl Iterator<Item = &'a Draft<'a>>) -> Vec<(f32, f32)> {
    let mut spans: Vec<(f32, f32)> = drafts.map(|draft| draft.x).collect();
    spans.sort_by(|a, b| a.0.total_cmp(&b.0));
    let mut out: Vec<(f32, f32)> = Vec::new();
    for (low, high) in spans {
        match out.last_mut() {
            Some(last) if low < last.1 => last.1 = last.1.max(high),
            _ => out.push((low, high)),
        }
    }
    out
}

/// The gaps between `intervals` at least `width` wide.
fn gutters(intervals: &[(f32, f32)], width: f32) -> Vec<(f32, f32)> {
    intervals
        .windows(2)
        .filter_map(|pair| match pair {
            [a, b] if b.0 - a.1 >= width => Some((a.1, b.0)),
            _ => None,
        })
        .collect()
}

/// Puts `drafts` in reading order and finds the tables, marking their cells.
///
/// Bands (blocks whose extents in y overlap) go from the top. Consecutive bands of two or more
/// blocks that keep a gutter open between them are a grid: a table when one of its lines is a
/// number cell or a row has three or more blocks, read row by row; otherwise columns of text side
/// by side, read column by column. A band alone is read column by column. Right-to-left pages
/// read from the right, vertical text from the right.
fn order(drafts: &mut Vec<Draft<'_>>, rtl_page: bool) -> Found {
    // Bands: blocks joined by overlapping extents in y.
    let count = drafts.len();
    let mut band: Vec<usize> = (0..count).collect();
    fn root(band: &[usize], mut at: usize) -> usize {
        while let Some(&parent) = band.get(at) {
            if parent == at {
                break;
            }
            at = parent;
        }
        at
    }
    for a in 0..count {
        for b in a.saturating_add(1)..count {
            let (Some(first), Some(second)) = (drafts.get(a), drafts.get(b)) else {
                continue;
            };
            if overlap(first.y, second.y) {
                let (ra, rb) = (root(&band, a), root(&band, b));
                if let Some(slot) = band.get_mut(ra.max(rb)) {
                    *slot = ra.min(rb);
                }
            }
        }
    }
    let roots: Vec<usize> = (0..count).map(|at| root(&band, at)).collect();
    let mut groups: Vec<Vec<Draft<'_>>> = Vec::new();
    let mut keys: Vec<usize> = Vec::new();
    for (draft, key) in std::mem::take(drafts).into_iter().zip(roots) {
        match keys.iter().position(|&k| k == key) {
            Some(at) => {
                if let Some(group) = groups.get_mut(at) {
                    group.push(draft);
                }
            }
            None => {
                keys.push(key);
                groups.push(vec![draft]);
            }
        }
    }
    let top = |group: &Vec<Draft<'_>>| {
        group
            .iter()
            .map(Draft::top)
            .fold(f32::NEG_INFINITY, f32::max)
    };
    groups.sort_by(|a, b| top(b).total_cmp(&top(a)));

    // Grids: consecutive bands of two or more horizontal blocks that keep a gutter open.
    let mut regions: Vec<Vec<Vec<Draft<'_>>>> = Vec::new();
    for group in groups {
        let size = group
            .iter()
            .flat_map(|draft| &draft.lines)
            .map(|line| line.size)
            .fold(0.0, f32::max);
        let gridded = |band: &Vec<Draft<'_>>| {
            band.len() >= 2
                && band
                    .iter()
                    .all(|draft| !draft.vertical() && draft.horizontal())
        };
        // Each block of the band falls in one column of the grid, one block per column.
        let joins = gridded(&group)
            && regions.last().is_some_and(|region| {
                let columns = intervals(region.iter().flatten());
                let mut taken = vec![false; columns.len()];
                region.iter().all(gridded)
                    && !gutters(&columns, size).is_empty()
                    && group.iter().all(|draft| {
                        let mut hits = columns
                            .iter()
                            .enumerate()
                            .filter(|&(_, &(low, high))| draft.x.0 < high && low < draft.x.1);
                        match (hits.next(), hits.next()) {
                            (Some((at, _)), None) => taken
                                .get_mut(at)
                                .is_some_and(|slot| !std::mem::replace(slot, true)),
                            _ => false,
                        }
                    })
            });
        match regions.last_mut() {
            Some(region) if joins => region.push(group),
            _ => regions.push(vec![group]),
        }
    }

    let mut found = Vec::new();
    for region in regions {
        let columns = intervals(region.iter().flatten());
        let table = region.len() >= 2
            && region
                .iter()
                .flatten()
                .any(|draft| draft.lines.iter().any(|line| line.cell))
            || region.len() >= 2 && region.iter().any(|band| band.len() >= 3);
        if table {
            let index = found.len();
            let mut members: Vec<Vec<&Frag>> = vec![Vec::new(); columns.len()];
            let rows = region.len();
            for (row, mut band) in region.into_iter().enumerate() {
                if rtl_page {
                    band.sort_by(|a, b| b.x.1.total_cmp(&a.x.1));
                } else {
                    band.sort_by(|a, b| a.x.0.total_cmp(&b.x.0));
                }
                for mut draft in band {
                    let column = columns
                        .iter()
                        .position(|&(low, high)| draft.x.0 >= low && draft.x.1 <= high);
                    if let Some(column) = column {
                        draft.cell = Some(TableCell {
                            table: index,
                            row,
                            column,
                        });
                        if let (Some(members), Some(line)) =
                            (members.get_mut(column), draft.lines.first().copied())
                        {
                            members.push(line);
                        }
                    }
                    drafts.push(draft);
                }
            }
            let aligned = columns
                .iter()
                .zip(&members)
                .map(|(&(low, high), cells)| (low, high, shared_alignment(cells)))
                .collect();
            found.push((rows, aligned));
            continue;
        }
        let mut blocks: Vec<Draft<'_>> = region.into_iter().flatten().collect();
        let column_of = |draft: &Draft<'_>| {
            columns
                .iter()
                .position(|&(low, high)| draft.x.0 >= low && draft.x.1 <= high)
                .unwrap_or(0)
        };
        if blocks.iter().any(Draft::vertical) {
            blocks.sort_by(|a, b| b.x.1.total_cmp(&a.x.1).then(b.top().total_cmp(&a.top())));
        } else if rtl_page {
            blocks.sort_by(|a, b| {
                column_of(b)
                    .cmp(&column_of(a))
                    .then(b.x.1.total_cmp(&a.x.1))
                    .then(b.top().total_cmp(&a.top()))
            });
        } else {
            blocks.sort_by(|a, b| {
                column_of(a)
                    .cmp(&column_of(b))
                    .then(b.top().total_cmp(&a.top()))
                    .then(a.x.0.total_cmp(&b.x.0))
            });
        }
        drafts.extend(blocks);
    }
    found
}

/// The edge a column's cells share: left, right or centre, left when none.
fn shared_alignment(cells: &[&Frag]) -> Alignment {
    let Some(first) = cells.first() else {
        return Alignment::Left;
    };
    let mut edges = [true; 3];
    for cell in cells {
        let shared = shared_edges(first, cell);
        for (edge, shared) in edges.iter_mut().zip(shared) {
            *edge &= shared;
        }
    }
    match edges {
        [true, ..] => Alignment::Left,
        [false, true, _] => Alignment::Right,
        [false, false, true] => Alignment::Center,
        _ => Alignment::Left,
    }
}

/// The alignment and justification of block `at`.
fn align(
    drafts: &[Draft<'_>],
    at: usize,
    frags: &[Frag],
    centre: Option<(f32, f32)>,
) -> (Alignment, Option<Justification>) {
    let Some(draft) = drafts.get(at) else {
        return (Alignment::Left, None);
    };
    let rtl = draft.rtl();
    if let Some(method) = draft
        .lines
        .iter()
        .find_map(|line| line.stretched.filter(|m| *m == Justification::WordSpacing))
        .or_else(|| draft.lines.iter().find_map(|line| line.stretched))
    {
        return (Alignment::Justified, Some(method));
    }
    if let Some(cell) = draft.cell {
        // The column's alignment, from the drafts that share the column.
        let cells: Vec<&Frag> = drafts
            .iter()
            .filter(|other| {
                other
                    .cell
                    .is_some_and(|c| c.table == cell.table && c.column == cell.column)
            })
            .filter_map(|other| other.lines.first().copied())
            .collect();
        return (shared_alignment(&cells), None);
    }
    if let [body @ .., last] = draft.lines.as_slice()
        && !body.is_empty()
        && draft.lines.iter().all(|line| !line.spaces)
        && body.windows(2).all(|pair| match pair {
            [a, b] => shared_edges(a, b)[..2] == [true, true],
            _ => true,
        })
        && body
            .iter()
            // Above zero: a short last line's kerning alone (`す。`) must not read as stretching.
            .all(|line| {
                line.spacing > 0.0 && line.spacing > last.spacing + 1.0 && line.high > last.high
            })
    {
        return (Alignment::Justified, Some(Justification::Glyphs));
    }
    if !draft.single() {
        let [left, right, center] = draft.edges;
        let alignment = match (rtl, left, right, center) {
            (true, _, true, _) | (false, false, true, _) => Alignment::Right,
            (_, true, _, _) => Alignment::Left,
            (_, false, false, true) => Alignment::Center,
            _ if rtl => Alignment::Right,
            _ => Alignment::Left,
        };
        return (alignment, None);
    }
    // One line: the page's text edge it touches, or the centre of the page's text.
    let Some(line) = draft.lines.first() else {
        return (Alignment::Left, None);
    };
    let parallel: Vec<&Frag> = frags
        .iter()
        .filter(|frag| frag.vertical == line.vertical && dot(frag.along, line.along) > 0.999)
        .collect();
    // Lines of its size, whose edges it can share.
    let peers: Vec<&Frag> = parallel
        .iter()
        .copied()
        .filter(|frag| (frag.size - line.size).abs() <= 0.1)
        .collect();
    let tol = tolerance(line.size);
    // How many lines share an edge at `at`.
    let sharing = |of: fn(&Frag) -> f32, at: f32| {
        peers
            .iter()
            .filter(|other| (of(other) - at).abs() <= tol)
            .count()
    };
    let low = parallel
        .iter()
        .map(|frag| frag.low)
        .fold(line.low, f32::min);
    let high = parallel
        .iter()
        .map(|frag| frag.high)
        .fold(line.high, f32::max);
    let left = (line.low - low).abs() <= tol;
    let right = (line.high - high).abs() <= tol;
    let shared_left = sharing(|frag| frag.low, line.low);
    let shared_right = sharing(|frag| frag.high, line.high);
    let shared_centre = sharing(
        |frag| (frag.low + frag.high) / 2.0,
        (line.low + line.high) / 2.0,
    );
    // The outermost edges two lines of its size share, as a frame's.
    let shared_edge = |of: fn(&Frag) -> f32, outer: fn(f32, f32) -> bool| {
        peers
            .iter()
            .map(|frag| of(frag))
            .filter(|&at| sharing(of, at) >= 2)
            .fold(None, |best: Option<f32>, at| match best {
                Some(best) if !outer(at, best) => Some(best),
                _ => Some(at),
            })
    };
    let framed = shared_edge(|frag| frag.low, |a, b| a < b)
        .zip(shared_edge(|frag| frag.high, |a, b| a > b))
        .map(|(low, high)| (low + high) / 2.0);
    let middle = (line.low + line.high) / 2.0;
    // The centre of the page's text, or of the page itself for horizontal text.
    let page_centre = centre
        .filter(|_| !line.vertical && line.along[0] > 0.999)
        .map(|(x, _)| x);
    // A page's margins may differ by a binding allowance: two hundredths of its width.
    let page_tol = centre.map_or(tol, |(x, _)| tol.max(x * 0.04));
    let center = (middle - (low + high) / 2.0).abs() <= tol
        || framed.is_some_and(|at| (middle - at).abs() <= tol)
        || page_centre.is_some_and(|x| (middle - x).abs() <= page_tol);
    // The edge it shares with the most other lines; then the page's text edge it touches, or
    // the centre; then the side its direction starts from.
    let most = shared_left.max(shared_right).max(shared_centre);
    let start = if rtl { shared_right } else { shared_left };
    let alignment = if most >= 2 {
        if start == most {
            if rtl {
                Alignment::Right
            } else {
                Alignment::Left
            }
        } else if shared_centre == most {
            Alignment::Center
        } else if shared_left == most {
            Alignment::Left
        } else {
            Alignment::Right
        }
    } else {
        match (rtl, left, right, center) {
            (true, _, true, _) | (false, false, true, false) => Alignment::Right,
            (false, true, ..) | (true, true, false, false) => Alignment::Left,
            (_, _, _, true) => Alignment::Center,
            (true, ..) => Alignment::Right,
            (false, ..) => Alignment::Left,
        }
    };
    (alignment, None)
}

/// A fragment as a line of the model, in page space.
fn line(frag: &Frag, glyphs: &[Glyph], page: Option<&ferman_core::structure::Page>) -> Line {
    let chars: Vec<TextChar> = frag
        .chars
        .iter()
        .map(|&(ch, at)| {
            let glyph = at.and_then(|at| glyphs.get(at));
            TextChar {
                ch,
                bbox: glyph.map(|glyph| displayed(page, glyph_box(glyph))),
                glyph: glyph.map(|glyph| glyph.link.clone()),
            }
        })
        .collect();
    let mut words = Vec::new();
    let mut start = None;
    for (at, c) in chars.iter().enumerate() {
        match (c.ch.is_whitespace(), start) {
            (false, None) => start = Some(at),
            (true, Some(from)) => {
                words.push(from..at);
                start = None;
            }
            _ => {}
        }
    }
    if let Some(from) = start {
        words.push(from..chars.len());
    }
    let bbox = chars.iter().filter_map(|c| c.bbox).fold(
        [
            f32::INFINITY,
            f32::INFINITY,
            f32::NEG_INFINITY,
            f32::NEG_INFINITY,
        ],
        |[l, t, r, b], [cl, ct, cr, cb]| [l.min(cl), t.min(ct), r.max(cr), b.max(cb)],
    );
    let point = |along: f32| {
        let [x, y] = [
            frag.along[0] * along + frag.across[0] * frag.offset,
            frag.along[1] * along + frag.across[1] * frag.offset,
        ];
        let shown = displayed(page, [x, y, x, y]);
        [shown[0], shown[1]]
    };
    Line {
        text: chars.iter().map(|c| c.ch).collect(),
        chars,
        words,
        bbox,
        baseline: [point(frag.low), point(frag.high)],
        size: frag.size,
        direction: if frag.vertical {
            TextDirection::Vertical
        } else if frag.rtl {
            TextDirection::RightToLeft
        } else {
            TextDirection::LeftToRight
        },
    }
}

/// Whether a block can be edited.
fn editability(
    block: &TextBlock,
    links: &[&Glyph],
    context: &EditContext,
    limited: bool,
) -> Editability {
    let reason = if let Some(reason) = context.document {
        Some(reason)
    } else if context
        .signature_areas
        .iter()
        .any(|&area| overlaps(area, block.bbox))
    {
        Some(NotEditableReason::SignatureAppearance)
    } else if context
        .field_areas
        .iter()
        .any(|&area| overlaps(area, block.bbox))
    {
        Some(NotEditableReason::AnnotationOrField)
    } else if limited {
        Some(NotEditableReason::TooComplex(Complexity::Limits))
    } else if !links.is_empty() && links.iter().all(|glyph| matches!(glyph.render_mode, 3 | 7)) {
        Some(NotEditableReason::InvisibleText)
    } else if block.text().contains(char::REPLACEMENT_CHARACTER) {
        Some(NotEditableReason::UnknownText)
    } else if links.iter().any(|glyph| glyph.link.span.carried) {
        Some(NotEditableReason::TooComplex(Complexity::SplitOperator))
    } else if links.iter().any(|glyph| glyph.skewed) {
        Some(NotEditableReason::TooComplex(Complexity::Skewed))
    } else {
        None
    };
    reason.map_or(Editability::Editable, Editability::NotEditable)
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;
    use crate::extract::test_glyph;

    /// A line of `text` at `(x, y)`, 6 points per character, one show per line.
    fn line(text: &str, x: f32, y: f32, show: usize) -> Vec<Glyph> {
        text.chars()
            .enumerate()
            .map(|(at, c)| {
                let start = x + 6.0 * at as f32;
                Glyph {
                    end: [start + 6.0, y],
                    show,
                    ..test_glyph(&c.to_string(), [start, y])
                }
            })
            .collect()
    }

    fn model(glyphs: &[Glyph]) -> PageText {
        build(glyphs, None, &EditContext::default(), false)
    }

    fn texts(model: &PageText) -> Vec<String> {
        model.blocks.iter().map(TextBlock::text).collect()
    }

    #[test]
    fn lines_at_one_leading_make_a_block_and_a_gap_starts_another() {
        let mut glyphs = line("Kira", 72.0, 700.0, 0);
        glyphs.extend(line("bedeli", 72.0, 685.0, 1));
        glyphs.extend(line("Not", 72.0, 640.0, 2));
        let model = model(&glyphs);
        assert_eq!(texts(&model), ["Kira\nbedeli", "Not"]);
        assert_eq!(model.blocks[0].alignment, Alignment::Left);
        assert_eq!(model.blocks[0].lines[1].words, vec![0..6_usize]);
    }

    #[test]
    fn stretched_lines_are_justified_by_their_method_and_end_the_block() {
        let mut glyphs = line("a b", 72.0, 700.0, 0);
        glyphs[1].word_spacing = 2.0;
        glyphs.extend(line("c", 72.0, 685.0, 1));
        // The next paragraph, one leading below, starts a block of its own.
        let mut next = line("d e", 72.0, 670.0, 2);
        next[1].adjust = -200.0;
        glyphs.extend(next);
        let model = model(&glyphs);
        assert_eq!(texts(&model), ["a b\nc", "d e"]);
        assert_eq!(model.blocks[0].alignment, Alignment::Justified);
        assert_eq!(
            model.blocks[0].justification,
            Some(Justification::WordSpacing)
        );
        assert_eq!(
            model.blocks[1].justification,
            Some(Justification::Adjustments)
        );
    }

    #[test]
    fn shows_far_apart_on_a_baseline_are_cells_of_a_table() {
        let mut glyphs = Vec::new();
        for (row, y) in [700.0, 680.0, 660.0].into_iter().enumerate() {
            glyphs.extend(line("Kira", 72.0, y, row * 3));
            glyphs.extend(line("1", 200.0, y, row * 3 + 1));
            glyphs.extend(line(
                ["10,00", "250,50", "5,00"][row],
                300.0,
                y,
                row * 3 + 2,
            ));
        }
        let model = model(&glyphs);
        assert_eq!(model.blocks.len(), 9);
        assert_eq!(model.tables.len(), 1);
        assert_eq!(model.tables[0].rows, 3);
        let amounts = model.tables[0].columns[2];
        assert_eq!(amounts.alignment, Alignment::Left);
        let cell = model.blocks[5].cell.unwrap();
        assert_eq!((cell.row, cell.column), (1, 2));
        assert!(numeric("18.500,00") && numeric("%20") && !numeric("Fatura no: 1"));
    }

    #[test]
    fn a_right_aligned_amount_column_is_right_aligned() {
        let mut glyphs = Vec::new();
        for (row, (y, amount)) in [(700.0, "1.250,00"), (680.0, "750,00"), (660.0, "18.500,00")]
            .into_iter()
            .enumerate()
        {
            glyphs.extend(line("Kalem", 72.0, y, row * 3));
            glyphs.extend(line("x", 150.0, y, row * 3 + 1));
            let width = 6.0 * amount.chars().count() as f32;
            glyphs.extend(line(amount, 400.0 - width, y, row * 3 + 2));
        }
        let model = model(&glyphs);
        assert_eq!(model.tables[0].columns[2].alignment, Alignment::Right);
        assert_eq!(model.blocks[2].alignment, Alignment::Right);
    }

    #[test]
    fn block_ids_come_from_the_first_glyph_and_repeats_differ() {
        let mut glyphs = line("Damga", 72.0, 700.0, 0);
        // The same operator drawn again elsewhere, as a form placed twice draws it.
        glyphs.extend(line("Damga", 72.0, 500.0, 1));
        let first = model(&glyphs);
        let again = model(&glyphs);
        let ids: Vec<BlockId> = first.blocks.iter().map(|block| block.id).collect();
        assert_eq!(
            ids,
            again
                .blocks
                .iter()
                .map(|block| block.id)
                .collect::<Vec<_>>()
        );
        assert_ne!(ids[0], ids[1]);
        let link = first.blocks[0].lines[0].chars[0].glyph.clone().unwrap();
        assert_eq!(link.index, 0);
    }

    #[test]
    fn every_reason_the_page_content_shows() {
        let reason = |glyphs: &[Glyph], context: &EditContext, limited: bool| {
            build(glyphs, None, context, limited).blocks[0].editability
        };
        let none = EditContext::default();
        let plain = line("Kira", 72.0, 700.0, 0);
        assert_eq!(reason(&plain, &none, false), Editability::Editable);
        let not = Editability::NotEditable;
        let mut invisible = plain.clone();
        for glyph in &mut invisible {
            glyph.render_mode = 3;
        }
        assert_eq!(
            reason(&invisible, &none, false),
            not(NotEditableReason::InvisibleText)
        );
        let mut unknown = plain.clone();
        unknown[1].text = "\u{FFFD}".to_owned();
        assert_eq!(
            reason(&unknown, &none, false),
            not(NotEditableReason::UnknownText)
        );
        let mut carried = plain.clone();
        carried[0].link.span.carried = true;
        assert_eq!(
            reason(&carried, &none, false),
            not(NotEditableReason::TooComplex(Complexity::SplitOperator))
        );
        let mut skewed = plain.clone();
        skewed[2].skewed = true;
        assert_eq!(
            reason(&skewed, &none, false),
            not(NotEditableReason::TooComplex(Complexity::Skewed))
        );
        assert_eq!(
            reason(&plain, &none, true),
            not(NotEditableReason::TooComplex(Complexity::Limits))
        );
        let restricted = EditContext {
            document: Some(NotEditableReason::Restricted),
            ..EditContext::default()
        };
        assert_eq!(
            reason(&plain, &restricted, false),
            not(NotEditableReason::Restricted)
        );
        // Without a page, boxes are in user space with y flipped: the line spans y 692 to 702.
        let area = [70.0, 690.0, 100.0, 710.0];
        let signed = EditContext {
            signature_areas: vec![area],
            ..EditContext::default()
        };
        assert_eq!(
            reason(&plain, &signed, false),
            not(NotEditableReason::SignatureAppearance)
        );
        let field = EditContext {
            field_areas: vec![area],
            ..EditContext::default()
        };
        assert_eq!(
            reason(&plain, &field, false),
            not(NotEditableReason::AnnotationOrField)
        );
        assert_eq!(empty_reason(true, true), Some(NotEditableReason::ImageOnly));
        assert_eq!(
            empty_reason(false, true),
            Some(NotEditableReason::OutlinedText)
        );
        assert_eq!(empty_reason(false, false), None);
    }

    #[test]
    fn a_page_of_too_many_lines_gets_a_block_per_line() {
        // One number per line, far apart: every line would be a table cell.
        let glyphs: Vec<Glyph> = (0..=MAX_LINES)
            .map(|at| {
                let start = [
                    72.0 + 40.0 * (at % 10) as f32,
                    700.0 - 12.0 * (at / 10) as f32,
                ];
                Glyph {
                    end: [start[0] + 6.0, start[1]],
                    show: at,
                    ..test_glyph("1", start)
                }
            })
            .collect();
        let model = model(&glyphs);
        assert_eq!(model.blocks.len(), MAX_LINES + 1);
        assert!(model.tables.is_empty());
        assert!(model.blocks.iter().all(|block| block.editability
            == Editability::NotEditable(NotEditableReason::TooComplex(Complexity::Limits))));
    }

    #[test]
    fn vertical_columns_read_from_the_right() {
        let column = |x: f32, text: &str, show: usize| -> Vec<Glyph> {
            text.chars()
                .enumerate()
                .map(|(at, c)| {
                    let y = 700.0 - 10.0 * at as f32;
                    Glyph {
                        end: [x, y - 10.0],
                        vertical: true,
                        show,
                        ..test_glyph(&c.to_string(), [x, y])
                    }
                })
                .collect()
        };
        let mut glyphs = column(500.0, "拝啓秋冷", 0);
        glyphs.extend(column(482.0, "の候", 1));
        glyphs.extend(column(400.0, "敬具", 2));
        let model = model(&glyphs);
        assert_eq!(texts(&model), ["拝啓秋冷\nの候", "敬具"]);
        assert_eq!(model.direction, TextDirection::Vertical);
        assert_eq!(model.blocks[0].direction, TextDirection::Vertical);
    }
}
