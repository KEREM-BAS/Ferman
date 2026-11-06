//! A block's new text as new operators in its own fonts (docs/ARCHITECTURE.md §6.6, ADR 0005,
//! ROADMAP §7 step 3): the [`Splice`]s that replace exactly the operators of the lines that
//! changed, in simple and composite fonts.
//!
//! - **Re-encoding.** Each new character becomes a code of a simple font of its line (Type1 with
//!   the standard 14, TrueType symbolic or not, Type3) whose text reads back as the character
//!   through the font's ToUnicode CMap or encoding (Standard, WinAnsi, MacRoman, `/Differences`)
//!   and whose glyph the font has: the embedded program's, a standard 14 font's metrics, a Type3
//!   font's `/CharProcs`. The font of the character before it is tried first, then the one after
//!   it, then the line's others of the same face (the PostScript name without its subset tag):
//!   a producer's Turkish letters in a composite copy of the face are used, another face's never.
//!   A font whose embedded program's `fsType` allows at most preview and print lends no glyph to
//!   new text (Q09).
//! - **Missing glyphs (docs/ARCHITECTURE.md §6.7, ADR 0006).** Step 1: a glyph the embedded
//!   program of a simple font (TrueType that is not symbolic, Type1) has but no code of its
//!   encoding shows gets a free code (one the font draws nothing with) through `/Differences` in
//!   a copy of the font ([`SimpleFontCopy`]) with the code's width and, when the font has one,
//!   its ToUnicode entry, used only by the new codes. Steps 2 and 3 are
//!   [`fallback`](crate::fallback)'s: the characters still missing get a new embedded font
//!   ([`EmbeddedFont`]), or the block is not rewritten and the outcome is
//!   [`Outcome::MissingGlyphs`]. Never substituted silently.
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
//! - **Right to left (ROADMAP §7 step 7, docs/ARCHITECTURE.md §6.10).** A block with a
//!   right-to-left line is always laid out again, a justified one given line by line as one
//!   paragraph. Its text is split into directional runs per paragraph by the `bidi` module
//!   (numbers and an IBAN stay left to right), each run shaped in the installed or bundled copy
//!   of its characters' font, since subsets drop the layout tables. Each shaped glyph is the
//!   subset's glyph of the same `post` name when its code reads back as the glyph's text; the
//!   others go into a new font of the same face (step 2). A character no copy covers, and all the
//!   text of a font without a usable copy (none installed, or its `fsType` forbids the glyphs the
//!   subset lacks), is shaped in a similar font (step 3, [`fallback`](crate::fallback)), since a
//!   glyph left in the subset cannot join it: the choice is the [`MissingGlyphs`], or the closest
//!   provisionally with [`Rewrite::pending`]. Without a font library:
//!   [`Unsupported::Shaping`]. Shaped advances and mark offsets become `TJ` numbers; ZWNJ is not
//!   written; a justified paragraph's last line keeps the right edge. One glyph with two texts
//!   (a decomposed letter's base, also set alone) takes a code in a second new font, since
//!   ToUnicode is per code.
//! - **Clusters in left-to-right text.** A combining mark or conjoining jamo typed after its base
//!   is first composed (`composed`), so a subset's precomposed glyph draws it. What does not
//!   compose (old Hangul, an ideographic variation sequence, a mark on a letter with no
//!   composite) is shaped as a cluster in the same font or a similar one, as above, the block
//!   laid out again; the characters around it keep their codes.
//! - **Vertical text (ROADMAP §7 step 7, E13).** A block with a vertical line is rewritten
//!   column by column, given one piece per column, and only the show the change falls in is
//!   written again. In an `Identity-V` run each new character takes the cell of the one it
//!   replaces, its advance from `/W2` or `/DW2`, and the run ends where it ended; a different
//!   number of characters is written only in a column's last show of a top-aligned block, the
//!   cells after them moved by the run's pitch (past the frame: [`Rewrite::overflowing`]). New
//!   characters come from the ToUnicode CMap, so the subset's `vert` forms are found by their
//!   text; the program's cmap lends only ideographs, which have no vertical form. An upright run
//!   across the column (tate-chu-yoko, an `Identity-H` show) is written whole, centred where it
//!   was and compressed with `Tz` to the wider of one em and its old width; it takes the
//!   missing-glyph steps like horizontal text.
//!
//! - **Style (a3-2).** [`rewrite_block_styled`] always lays the block out again, with the changes of
//!   its [`BlockStyle`]: the size scales every font, pitch and `Tc` of the block; a colour is set
//!   before the block's first show and the old fill after its last; a font sets every character
//!   in a new font of steps 2 and 3, or a font of the page, keeping no old code; a new box moves the
//!   first baseline with its top left and fills its width and height.
//!
//! Simple fonts' strings are written as literal strings with `\(`, `\)`, `\\` and octal escapes;
//! the original operator's string form is not visible here, since spans carry no bytes.
//!
//! Not rewritten yet ([`Unsupported`]): vertical text whose change crosses shows, needs a
//! character its vertical font lacks (steps 2 and 3 make horizontal fonts) or a reflow of the
//! columns (kinsoku, columns from the right), a new character only a composite font could draw
//! whose predefined CMap is not bundled or that needs a copy of a form's font, lines whose operators are not a plain run of shows (marked
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
use ferman_core::revision::{EmbeddedFont, FontCopy, RevisionStore, SimpleFontCopy};
use ferman_core::structure::FontKind;
use ferman_fonts::{
    Direction, Embedding, FaceInfo, FontLibrary, FontProgram, GlyphId, SameFont, ShapeRequest,
    ShapedRun, ShapingFont, glyph_names, strip_subset_tag, with_text,
};
use unicode_normalization::char::{compose, is_combining_mark};

use crate::TextError;
use crate::bidi;
use crate::extract::{CharBox, Collector, PdfFont, displayed, glyph_box, mirror, single};
use crate::fallback::{
    self, FontSources, Miss, MissingGlyphs, MissingReason, Substitute, Substitution,
    SubstitutionKind,
};
use crate::layout::{Alignment, Justification, Line, TextBlock, TextChar, TextDirection};
use crate::reflow::{self, OverflowPlan};
use crate::style::{self, BlockStyle, BlockStyleInfo};

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
    /// transaction before the splices ([`RevisionStore::add_new_fonts`]).
    pub fonts: Vec<FontCopy>,
    /// The simple font copies with codes added through `/Differences` (step 1), added with
    /// them.
    pub simple_fonts: Vec<SimpleFontCopy>,
    /// The new fonts the substituted characters are set in (steps 2 and 3), added with them.
    pub new_fonts: Vec<EmbeddedFont>,
    /// The substitutions those fonts make: the review list's and the toast's.
    pub substitutions: Vec<Substitution>,
    /// Step 3's characters drawn provisionally in the closest candidate, which the caller has
    /// not chosen yet: the choice it may still make.
    pub pending: Option<MissingGlyphs>,
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
// The rewrite is the common outcome; boxing it would only cost every caller.
#[allow(clippy::large_enum_variant)]
pub enum Outcome {
    /// The splices.
    Rewritten(Rewrite),
    /// Characters no font of their line draws, which steps 1 and 2 could not draw either and
    /// step 3 waits for a choice for (or has no candidate for): the text is not written.
    MissingGlyphs(MissingGlyphs),
    /// The block cannot be rewritten yet.
    Unsupported(Unsupported),
}

/// Why a block cannot be rewritten yet.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum Unsupported {
    /// The block is not editable ([`TextBlock::editability`]).
    NotEditable,
    /// The block runs vertically and the change is one the writer cannot place yet: across
    /// shows of a column, a character the vertical font lacks, a reflow of the columns, or a
    /// column of another length that is not the last show of a top-aligned block.
    Direction,
    /// A new character could only come from a composite font of its line whose predefined CMap
    /// is not bundled, from a copy of a font of a form, or (in a form) from a new font.
    CompositeFont,
    /// A changed line's operators are not a plain run of shows (module documentation).
    Operators,
    /// The block's glyphs are not on the page: it comes from another revision.
    Stale,
    /// The text needs shaping and no font library was given, or a chosen face would not load:
    /// subsets drop the layout tables. The caller can index the fonts and ask again.
    Shaping,
    /// The block cannot take the style asked for: a vertical block any, a right-to-left block or
    /// a form's block another font, a turned block another box, a fill that is a pattern.
    Style,
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
    rewrite_block_with(document, None, index, block, text, &[], None)
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
    rewrite_block_with(document, Some(revisions), index, block, text, &[], None)
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
    rewrite_block_fonts(
        document,
        revisions,
        index,
        block,
        text,
        others,
        choice,
        &FontSources::default(),
    )
}

/// Whether `tag` can be written as a block's `/Lang`: a language tag's letters, digits and hyphens
/// (35 characters is RFC 5646's longest useful tag), so it needs no string escapes.
#[must_use]
pub fn valid_language_tag(tag: &str) -> bool {
    (1..=35).contains(&tag.len())
        && tag.starts_with(|c: char| c.is_ascii_alphabetic())
        && tag.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-')
}

/// `text`, a rewrite's splices for `block`, with every operator of the block drawn in marked
/// content naming the language `tag`. A splice's new bytes are wrapped. A line no splice touches
/// gets its operators wrapped: whole when they are a plain run, so a later text edit can replace
/// them, else one show at a time, which stays balanced across text objects. Marked content draws
/// nothing, so no pixel changes.
///
/// # Errors
///
/// [`TextError::Core`] when the page cannot be interpreted; the inner [`Unsupported`] for a tag
/// that is not [`valid_language_tag`], or a show split across streams.
pub fn with_language(
    document: &Document,
    revisions: Option<&RevisionStore>,
    index: usize,
    block: &TextBlock,
    tag: &str,
    text: Vec<Splice>,
) -> Result<Result<Vec<Splice>, Unsupported>, TextError> {
    if !valid_language_tag(tag) {
        return Ok(Err(Unsupported::Operators));
    }
    let open = format!("/Span <</Lang ({tag})>> BDC\n").into_bytes();
    let close = b"\nEMC\n".to_vec();
    let mut recorder = Recorder::default();
    match revisions {
        Some(revisions) => revisions.page_text(document, index, &mut recorder)?,
        None => document.page_text(index, &mut recorder)?,
    }
    let page = Page::new(&recorder, document.structure().pages.get(index));
    let mut around: Vec<(SpanSource, Range<usize>)> = Vec::new();
    for line in &block.lines {
        if let Ok(runs) = page.runs(line)
            && let Ok(range) = page.range(runs.first, runs.last)
        {
            around.push((runs.source, range));
            continue;
        }
        for c in &line.chars {
            let Some(glyph) = &c.glyph else { continue };
            if glyph.span.carried {
                return Ok(Err(Unsupported::Operators));
            }
            around.push((glyph.span.source, glyph.span.range.clone()));
        }
    }
    around.retain(|(source, range)| {
        !text.iter().any(|splice| {
            splice.source == *source
                && splice.range.start < range.end
                && range.start < splice.range.end
        })
    });
    around.sort_by_key(|(_, range)| (range.start, range.end));
    around.dedup();
    let mut out = Vec::new();
    // At one offset the end of what comes before goes first.
    let mut marks: Vec<(usize, bool, SpanSource)> = Vec::new();
    for (source, range) in around {
        marks.push((range.start, true, source));
        marks.push((range.end, false, source));
    }
    marks.sort_by_key(|&(at, starts, _)| (at, starts));
    for (at, starts, source) in marks {
        out.push(Splice {
            source,
            range: at..at,
            bytes: if starts { open.clone() } else { close.clone() },
        });
    }
    for mut splice in text {
        if !splice.bytes.is_empty() {
            let mut bytes = open.clone();
            bytes.append(&mut splice.bytes);
            bytes.extend_from_slice(&close);
            splice.bytes = bytes;
        }
        out.push(splice);
    }
    Ok(Ok(out))
}

/// [`rewrite_block_with`] with the missing-glyph steps 2 and 3 looking in `sources`
/// ([`fallback`](crate::fallback)).
///
/// # Errors
///
/// As [`rewrite_block`].
#[allow(clippy::too_many_arguments)]
pub fn rewrite_block_fonts(
    document: &Document,
    revisions: Option<&RevisionStore>,
    index: usize,
    block: &TextBlock,
    text: &str,
    others: &[TextBlock],
    choice: Option<Choice>,
    sources: &FontSources<'_>,
) -> Result<Outcome, TextError> {
    rewrite_block_styled(
        document,
        revisions,
        index,
        block,
        text,
        others,
        choice,
        sources,
        &BlockStyle::default(),
    )
}

/// [`rewrite_block_fonts`] with the block's style changed (a3-2): any style lays the block out again
/// in its frame, and a font in `style` sets the whole block in it, its characters that font's
/// (the outcome is [`Outcome::MissingGlyphs`] when it cannot draw them all).
///
/// # Errors
///
/// As [`rewrite_block`].
#[allow(clippy::too_many_arguments)]
pub fn rewrite_block_styled(
    document: &Document,
    revisions: Option<&RevisionStore>,
    index: usize,
    block: &TextBlock,
    text: &str,
    others: &[TextBlock],
    choice: Option<Choice>,
    sources: &FontSources<'_>,
    style: &BlockStyle,
) -> Result<Outcome, TextError> {
    if !block.editability.is_editable() {
        return Ok(Outcome::Unsupported(Unsupported::NotEditable));
    }
    let composed_text;
    let text = if right_to_left(block) {
        text
    } else {
        composed_text = composed_changes(&block.text(), text);
        composed_text.as_str()
    };
    let texts: Vec<&str> = text.split('\n').collect();
    let vertical = block.direction == TextDirection::Vertical
        || block
            .lines
            .iter()
            .any(|line| line.direction == TextDirection::Vertical);
    // Vertical text is rewritten column by column; its reflow is not written yet.
    if vertical && texts.len() != block.lines.len() {
        return Ok(Outcome::Unsupported(Unsupported::Direction));
    }
    let styled = !style.is_empty();
    // Right-to-left text is shaped in the installed copy of its own font.
    if styled && (vertical || (style.font.is_some() && right_to_left(block))) {
        return Ok(Outcome::Unsupported(Unsupported::Style));
    }
    // Right-to-left text is always shaped and laid out again; a justified paragraph given line
    // by line is one paragraph.
    let joined;
    let text = if (styled || right_to_left(block))
        && !sources.keep_lines
        && block.alignment == Alignment::Justified
        && texts.len() == block.lines.len()
    {
        joined = texts.join(" ");
        joined.as_str()
    } else {
        text
    };
    // A new cluster is shaped, which only the block's writer does.
    let parts = |text: &str| text.chars().filter(|&c| cluster_part(c)).count();
    let old_parts: usize = block.lines.iter().map(|line| parts(&line.text)).sum();
    let line_by_line = vertical
        || !styled
            && texts.len() == block.lines.len()
            && matches!(block.alignment, Alignment::Left | Alignment::Justified)
            && !right_to_left(block)
            && parts(text) <= old_parts;
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
    let attempt = |substitutes: &[Substitute], reserved: Vec<Vec<u8>>| {
        let copies = Copies {
            document,
            store,
            page: index,
            list: Vec::new(),
            simple: Vec::new(),
            reserved,
        };
        let inputs = Inputs {
            page: &page,
            block,
            text,
            texts: &texts,
            line_by_line,
            others,
            choice,
            frame: &frame,
            substitutes,
            sources,
            style,
        };
        inputs.attempt(copies)
    };
    let mut taken: Vec<Vec<u8>> = Vec::new();
    let mut name = |base: &[u8]| {
        let fresh = store.free_font_name(document, index, base, &taken).ok()?;
        taken.push(fresh.clone());
        Some(fresh)
    };
    if let Some(font) = &style.font {
        let Some((base, resource)) = page.first_font(block) else {
            return Ok(Outcome::Unsupported(Unsupported::Style));
        };
        let misses = text_misses(text, base, &resource);
        let lenders = lenders(&recorder, &misses);
        let resolved = match fallback::whole_block(
            &recorder.collector.fonts,
            base,
            &resource,
            text,
            &lenders,
            sources,
            font,
            &mut name,
        ) {
            Ok(resolved) => resolved,
            Err(missing) => return Ok(Outcome::MissingGlyphs(missing)),
        };
        let reserved = resolved
            .substitutes
            .iter()
            .filter(|substitute| !substitute.existing)
            .map(|substitute| substitute.name.clone())
            .collect();
        return Ok(match attempt(&resolved.substitutes, reserved)? {
            // Fonts of shaped clusters come beside the chosen font's.
            Attempt::Done(mut rewrite) => {
                let mut new_fonts = resolved.fonts;
                new_fonts.append(&mut rewrite.new_fonts);
                Outcome::Rewritten(Rewrite {
                    new_fonts,
                    ..rewrite
                })
            }
            Attempt::Glyphs(missing) => Outcome::MissingGlyphs(missing),
            Attempt::Unsupported(unsupported) => Outcome::Unsupported(unsupported),
            Attempt::Missing(_) => Outcome::Unsupported(Unsupported::Style),
        });
    }
    let misses = match attempt(&[], Vec::new())? {
        Attempt::Done(rewrite) => return Ok(Outcome::Rewritten(rewrite)),
        Attempt::Unsupported(unsupported) => return Ok(Outcome::Unsupported(unsupported)),
        Attempt::Glyphs(missing) => return Ok(Outcome::MissingGlyphs(missing)),
        Attempt::Missing(misses) => misses,
    };
    // Steps 2 and 3, then the block again with the new fonts.
    let lenders = lenders(&recorder, &misses);
    let resolved = match fallback::resolve(
        &recorder.collector.fonts,
        &recorder.collector.glyphs,
        &misses,
        &lenders,
        sources,
        &mut name,
    ) {
        Ok(resolved) => resolved,
        Err(missing) => return Ok(Outcome::MissingGlyphs(missing)),
    };
    let reserved = resolved
        .substitutes
        .iter()
        .filter(|substitute| !substitute.existing)
        .map(|substitute| substitute.name.clone())
        .collect();
    match attempt(&resolved.substitutes, reserved)? {
        // Fonts of shaped clusters come beside step 2's and 3's.
        Attempt::Done(mut rewrite) => {
            let mut new_fonts = resolved.fonts;
            new_fonts.append(&mut rewrite.new_fonts);
            let mut substitutions = resolved.substitutions;
            substitutions.append(&mut rewrite.substitutions);
            Ok(Outcome::Rewritten(Rewrite {
                new_fonts,
                substitutions,
                pending: resolved.pending.or(rewrite.pending.take()),
                ..rewrite
            }))
        }
        Attempt::Unsupported(unsupported) => Ok(Outcome::Unsupported(unsupported)),
        Attempt::Glyphs(missing) => Ok(Outcome::MissingGlyphs(missing)),
        Attempt::Missing(misses) => Ok(Outcome::MissingGlyphs(MissingGlyphs {
            chars: misses.iter().map(|miss| (miss.c, miss.at)).collect(),
            font: String::new(),
            reason: fallback::MissingReason::NotInstalled,
            bold: false,
            italic: false,
            candidates: Vec::new(),
        })),
    }
}

/// Every character of `text` once, as missing from the font `font`: what the page's other fonts
/// are asked to lend when a font is chosen for a whole block.
fn text_misses(text: &str, font: u64, name: &[u8]) -> Vec<Miss> {
    let mut misses: Vec<Miss> = Vec::new();
    for (at, c) in text.char_indices() {
        if !c.is_whitespace() && !misses.iter().any(|miss| miss.c == c) {
            misses.push(Miss {
                c,
                at,
                font,
                name: name.to_vec(),
            });
        }
    }
    misses
}

/// The fonts of the page's own content of another face than the missing characters' that encode
/// some of them with their own codes, not restricted: step 3's embedded candidates.
fn lenders(recorder: &Recorder, misses: &[Miss]) -> Vec<fallback::PageFont> {
    let fonts = &recorder.collector.fonts;
    let face = |key: u64| {
        fonts
            .get(&key)
            .and_then(|font| font.resource.base_font.as_deref())
            .map(strip_subset_tag)
    };
    let faces: Vec<Option<&str>> = misses.iter().map(|miss| face(miss.font)).collect();
    let mut chars: Vec<char> = misses.iter().map(|miss| miss.c).collect();
    chars.dedup();
    let mut seen: Vec<u64> = Vec::new();
    let mut lenders = Vec::new();
    for event in &recorder.events {
        let (Some(show), SpanSource::Page { .. }) = (event.show, event.span.source) else {
            continue;
        };
        let Some(state) = recorder.shows.get(show).map(|show| &show.state) else {
            continue;
        };
        let (Some(key), Some(name)) = (state.font, &state.font_name) else {
            continue;
        };
        if seen.contains(&key) || faces.contains(&face(key)) {
            continue;
        }
        seen.push(key);
        let Some(font) = fonts.get(&key) else {
            continue;
        };
        // A vertical font would draw the character down a column.
        if fallback::restriction(font).is_some() || font.vertical() {
            continue;
        }
        let program = font.program();
        let draws = |c: char| match font.cmap {
            None => encode(font, program.as_ref(), c).is_some(),
            Some(_) => encode_composite(font, program.as_ref(), c)
                .is_some_and(|found| found.needs.is_none()),
        };
        let covered: Vec<char> = chars.iter().copied().filter(|&c| draws(c)).collect();
        if covered.is_empty() {
            continue;
        }
        let preview: Vec<String> = fallback::PREVIEW
            .split(' ')
            .map(|pair| pair.chars().filter(|&c| draws(c)).collect::<String>())
            .filter(|pair| !pair.is_empty())
            .collect();
        let postscript_name = face(key).unwrap_or_default().to_owned();
        lenders.push(fallback::PageFont {
            key,
            name: name.clone(),
            family: program
                .as_ref()
                .and_then(FontProgram::family_name)
                .unwrap_or_else(|| postscript_name.clone()),
            postscript_name,
            chars: covered,
            preview: preview.join(" "),
        });
    }
    lenders
}

/// What one pass of the rewrite gives.
#[allow(clippy::large_enum_variant)]
enum Attempt {
    Done(Rewrite),
    Missing(Vec<Miss>),
    /// Shaped glyphs no step can draw (right-to-left text).
    Glyphs(MissingGlyphs),
    Unsupported(Unsupported),
}

/// Whether `block` or one of its lines runs right to left.
fn right_to_left(block: &TextBlock) -> bool {
    block.direction == TextDirection::RightToLeft
        || block
            .lines
            .iter()
            .any(|line| line.direction == TextDirection::RightToLeft)
}

/// What a pass of the rewrite reads.
struct Inputs<'a> {
    page: &'a Page<'a>,
    block: &'a TextBlock,
    text: &'a str,
    texts: &'a [&'a str],
    line_by_line: bool,
    others: &'a [TextBlock],
    choice: Option<Choice>,
    frame: &'a Frame,
    substitutes: &'a [Substitute],
    sources: &'a FontSources<'a>,
    style: &'a BlockStyle,
}

impl Inputs<'_> {
    /// One pass: the block line by line or reflowed, with the new fonts `substitutes`.
    fn attempt(&self, mut copies: Copies<'_>) -> Result<Attempt, TextError> {
        let Self {
            page,
            block,
            text,
            texts,
            line_by_line,
            others,
            choice,
            frame,
            substitutes,
            sources,
            style,
        } = *self;
        if !line_by_line {
            return Ok(reflowed(
                page,
                block,
                text,
                others,
                choice,
                copies,
                substitutes,
                sources,
                style,
            ));
        }
        let mut rewrite = Rewrite::default();
        let mut missing: Vec<Miss> = Vec::new();
        let mut start = 0_usize;
        for (at, (line, new)) in block.lines.iter().zip(texts.iter().copied()).enumerate() {
            let base = start;
            start = start.saturating_add(new.len()).saturating_add(1);
            if line.text == new {
                continue;
            }
            let planned = if line.direction == TextDirection::Vertical {
                page.vertical_line(
                    line,
                    new,
                    base,
                    block.alignment == Alignment::Left,
                    frame,
                    &mut copies,
                    substitutes,
                )
            } else {
                page.line(
                    line,
                    new,
                    base,
                    block.justification,
                    frame,
                    &mut copies,
                    substitutes,
                )
            };
            match planned {
                Err(unsupported) => return Ok(Attempt::Unsupported(unsupported)),
                Ok(Planned::Missing(misses)) => missing.extend(misses),
                Ok(Planned::Splice(splice, over)) => {
                    rewrite.splices.push(splice);
                    if over {
                        rewrite.overflowing.push(at);
                    }
                }
            }
        }
        if !missing.is_empty() {
            return Ok(Attempt::Missing(missing));
        }
        if block.alignment == Alignment::Justified
            && !sources.keep_lines
            && !rewrite.overflowing.is_empty()
            && block
                .lines
                .iter()
                .all(|line| line.direction != TextDirection::Vertical)
        {
            // A justified block is one paragraph: a line past its frame reflows it.
            copies.list.clear();
            copies.simple.clear();
            return Ok(reflowed(
                page,
                block,
                &texts.join(" "),
                others,
                choice,
                copies,
                substitutes,
                sources,
                style,
            ));
        }
        (rewrite.fonts, rewrite.simple_fonts) = copies.finish();
        Ok(Attempt::Done(rewrite))
    }
}

/// The outcome of reflowing `block` to `text`.
#[allow(clippy::too_many_arguments)]
fn reflowed(
    page: &Page<'_>,
    block: &TextBlock,
    text: &str,
    others: &[TextBlock],
    choice: Option<Choice>,
    mut copies: Copies<'_>,
    substitutes: &[Substitute],
    sources: &FontSources<'_>,
    style: &BlockStyle,
) -> Attempt {
    match page.block(
        block,
        text,
        others,
        choice,
        &mut copies,
        substitutes,
        sources,
        style,
    ) {
        Err(unsupported) => Attempt::Unsupported(unsupported),
        Ok(Reflowed::Missing(missing)) => Attempt::Missing(missing),
        Ok(Reflowed::Glyphs(missing)) => Attempt::Glyphs(missing),
        Ok(Reflowed::Splice {
            splices,
            overflow,
            chosen,
            hidden,
            new_fonts,
            substitutions,
            pending,
        }) => {
            let (fonts, simple_fonts) = copies.finish();
            Attempt::Done(Rewrite {
                splices,
                fonts,
                simple_fonts,
                new_fonts,
                substitutions,
                pending,
                overflow,
                chosen,
                hidden,
                ..Rewrite::default()
            })
        }
    }
}

/// The font copies a block's new codes need, one per font copied.
struct Copies<'a> {
    document: &'a Document,
    store: &'a RevisionStore,
    page: usize,
    list: Vec<Copied>,
    simple: Vec<SimpleCopied>,
    /// Names the new fonts of steps 2 and 3 take.
    reserved: Vec<Vec<u8>>,
}

/// One simple font copy as the lines add codes to it (step 1).
struct SimpleCopied {
    base: u64,
    key: u64,
    to_unicode: Option<Vec<u8>>,
    copy: SimpleFontCopy,
    /// The character of each new code.
    chars: Vec<char>,
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
                let fresh = self.fresh_name(name)?;
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

    /// A name for a copy of the font named `name` that no font of the page, no copy and no new
    /// font takes.
    fn fresh_name(&self, name: &[u8]) -> Result<Vec<u8>, Unsupported> {
        let taken: Vec<Vec<u8>> = self
            .list
            .iter()
            .map(|copied| copied.copy.name.clone())
            .chain(self.simple.iter().map(|copied| copied.copy.name.clone()))
            .chain(self.reserved.iter().cloned())
            .collect();
        self.store
            .free_font_name(self.document, self.page, name, &taken)
            .map_err(|_| Unsupported::Operators)
    }

    /// The key, name and code of `c` in the simple copy of the font `base`, named `name` on the
    /// page, whose program draws it as the glyph `glyph` (step 1): the copy's code for it, or a
    /// free code of the font (one it draws nothing with and has no text for) given `glyph`
    /// through `/Differences`, with `width` in thousandths of an em. `None` when no code is
    /// free.
    #[allow(clippy::too_many_arguments)]
    fn add_simple(
        &mut self,
        base: u64,
        name: &[u8],
        font: &PdfFont,
        program: Option<&FontProgram<'_>>,
        c: char,
        glyph: &str,
        width: f32,
    ) -> Result<Option<(u64, Vec<u8>, u8)>, Unsupported> {
        let at = match self.simple.iter().position(|copied| copied.base == base) {
            Some(at) => at,
            None => {
                let fresh = self.fresh_name(name)?;
                self.simple.push(SimpleCopied {
                    base,
                    // Font keys are hashes of their dictionaries; a copy's is derived from its
                    // original's.
                    key: base ^ 0x5D1F_F0C0_FFEE_0002,
                    to_unicode: font.resource.to_unicode.clone(),
                    copy: SimpleFontCopy {
                        base: name.to_vec(),
                        name: fresh,
                        codes: Vec::new(),
                        to_unicode: None,
                    },
                    chars: Vec::new(),
                });
                self.simple.len().saturating_sub(1)
            }
        };
        let copied = self.simple.get_mut(at).ok_or(Unsupported::Operators)?;
        let found = copied
            .chars
            .iter()
            .zip(&copied.copy.codes)
            .find(|(seen, _)| **seen == c)
            .map(|(_, (code, ..))| *code);
        let code = match found {
            Some(code) => code,
            None => {
                let used = |code: u8| copied.copy.codes.iter().any(|(at, ..)| *at == code);
                let unmapped = |code: u8| {
                    font.to_unicode
                        .as_ref()
                        .is_none_or(|cmap| cmap.text(u32::from(code)).is_none())
                };
                // The codes WinAnsi leaves unused first, then the rest of the upper half, then
                // the lower; never 32, which `Tw` widens.
                let Some(code) = [129_u8, 141, 143, 144, 157]
                    .into_iter()
                    .chain(128..=255)
                    .chain(33..128)
                    .find(|&code| !used(code) && unmapped(code) && !font.has_glyph(program, code))
                else {
                    return Ok(None);
                };
                copied.copy.codes.push((code, glyph.to_owned(), width));
                copied.chars.push(c);
                code
            }
        };
        Ok(Some((copied.key, copied.copy.name.clone(), code)))
    }

    /// The copies, each with its ToUnicode CMap.
    fn finish(self) -> (Vec<FontCopy>, Vec<SimpleFontCopy>) {
        let copies = self
            .list
            .into_iter()
            .map(|copied| FontCopy {
                to_unicode: with_text(copied.to_unicode.as_deref(), &copied.texts),
                ..copied.copy
            })
            .collect();
        let simple = self
            .simple
            .into_iter()
            .map(|copied| {
                let texts: Vec<(Vec<u8>, String)> = copied
                    .copy
                    .codes
                    .iter()
                    .zip(&copied.chars)
                    .map(|((code, ..), c)| (vec![*code], c.to_string()))
                    .collect();
                SimpleFontCopy {
                    to_unicode: copied
                        .to_unicode
                        .as_deref()
                        .map(|original| with_text(Some(original), &texts)),
                    ..copied.copy
                }
            })
            .collect();
        (copies, simple)
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
    Missing(Vec<Miss>),
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

    /// A line's characters as units of one glyph each, and its glyphs in content order.
    fn units(&self, line: &Line) -> Result<(Vec<Unit>, Vec<usize>), Unsupported> {
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
        let mut glyphs: Vec<usize> = units.iter().filter_map(|unit| unit.glyph).collect();
        // A right-to-left line's characters are logical, its glyphs visual.
        if line.direction == TextDirection::RightToLeft {
            glyphs.sort_unstable();
            glyphs.dedup();
        }
        if glyphs.is_empty()
            || glyphs
                .windows(2)
                .any(|pair| matches!(pair, [a, b] if a >= b))
        {
            return Err(Unsupported::Operators);
        }
        // A glyph an `/ActualText` covers has no character, so no unit would replace it and it
        // would stay drawn beside the new text.
        let all = &self.recorder.collector.glyphs;
        let stranded = glyphs.iter().any(|&glyph| {
            all.get(glyph.saturating_add(1))
                .is_some_and(|next| next.covered)
                && glyphs.binary_search(&glyph.saturating_add(1)).is_err()
        });
        if stranded {
            return Err(Unsupported::Operators);
        }
        Ok((units, glyphs))
    }

    /// A line's glyphs and the operators that draw them, when they are a plain run of shows.
    fn runs(&self, line: &Line) -> Result<Runs, Unsupported> {
        let recorder = self.recorder;
        let (units, glyphs) = self.units(line)?;
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

    /// The splice for one changed line, whose new text `new` starts at byte `start` of the
    /// block's.
    #[allow(clippy::too_many_arguments)]
    fn line(
        &self,
        line: &Line,
        new: &str,
        start: usize,
        justification: Option<Justification>,
        frame: &Frame,
        copies: &mut Copies<'_>,
        substitutes: &[Substitute],
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
        let (prefix, suffix) = common_ends(&old, &fresh);
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
        let offsets: Vec<usize> = new.char_indices().map(|(at, _)| at).collect();
        let mut encoder = Encoder::new(recorder, &shows, source, substitutes, 1.0)?;
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
        for (k, &c) in middle.iter().enumerate() {
            let previous = placed.last().map(|p| p.font);
            let order: Vec<u64> = previous
                .into_iter()
                .chain(next_font)
                .chain(encoder.fonts.iter().map(|(key, ..)| *key))
                .collect();
            let chosen = encoder.choose(copies, &order, c)?;
            let at = head_chars
                .checked_add(k)
                .and_then(|i| offsets.get(i))
                .map_or(start, |&at| start.saturating_add(at));
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
                None => missing.push(encoder.miss(&order, c, at)),
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
        let natural = write_placed(&mut out, &mut sim, &placed, tj, scaling, None, &|key| {
            encoder.name(key)
        })?;
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

    /// The splice for one changed line of vertical text (ROADMAP §7 step 7, E13), whose new
    /// text `new` starts at byte `start` of the block's: only the show the change falls in is
    /// written again, and a change across shows is [`Unsupported::Direction`]. In a run of
    /// vertical glyphs each new character takes the cell of the one it replaces and the run
    /// ends where it ended; a different number of characters is written only in the line's
    /// last show of a top-aligned block (`grows`), the cells after them moved by the run's
    /// pitch. An upright run across the column (tate-chu-yoko) is written whole, centred where
    /// it was and compressed with `Tz` to the wider of one em and its old width.
    #[allow(clippy::too_many_arguments)]
    fn vertical_line(
        &self,
        line: &Line,
        new: &str,
        start: usize,
        grows: bool,
        frame: &Frame,
        copies: &mut Copies<'_>,
        substitutes: &[Substitute],
    ) -> Result<Planned, Unsupported> {
        let recorder = self.recorder;
        let glyphs = &recorder.collector.glyphs;
        let (units, line_glyphs) = self.units(line)?;
        let old: Vec<char> = line.chars.iter().map(|c| c.ch).collect();
        let fresh: Vec<char> = new.chars().collect();
        let (prefix, suffix) = common_ends(&old, &fresh);
        // The characters the change touches; an insertion is anchored to the one before it.
        let (lo, hi) = match old.len().saturating_sub(suffix) {
            end if end > prefix => (prefix, end),
            _ if prefix > 0 => (prefix.saturating_sub(1), prefix),
            _ => (0, 1),
        };
        let touched: Vec<usize> = (0..units.len())
            .filter(|&at| {
                units
                    .get(at)
                    .is_some_and(|unit| unit.chars.start < hi && lo < unit.chars.end)
            })
            .collect();
        let (Some(&t0), Some(&t_last)) = (touched.first(), touched.last()) else {
            return Err(Unsupported::Operators);
        };
        let t1 = t_last.saturating_add(1);
        let show_of = |at: usize| {
            units
                .get(at)
                .and_then(|unit| unit.glyph)
                .and_then(|g| recorder.glyph_shows.get(g).copied())
        };
        let show = show_of(t0).ok_or(Unsupported::Direction)?;
        if touched.iter().any(|&at| show_of(at) != Some(show)) {
            return Err(Unsupported::Direction);
        }
        let drawn = recorder.shows.get(show).ok_or(Unsupported::Operators)?;
        if drawn
            .glyphs
            .clone()
            .any(|g| line_glyphs.binary_search(&g).is_err())
        {
            return Err(Unsupported::Operators);
        }
        let event_at = *self.show_events.get(&show).ok_or(Unsupported::Operators)?;
        let event = recorder
            .events
            .get(event_at)
            .ok_or(Unsupported::Operators)?;
        if !matches!(event.name.as_slice(), b"Tj" | b"TJ") || event.span.carried {
            return Err(Unsupported::Operators);
        }
        let source = event.span.source;
        let state = &drawn.state;
        let key = state.font.ok_or(Unsupported::Operators)?;
        let upright = !recorder
            .collector
            .fonts
            .get(&key)
            .ok_or(Unsupported::Operators)?
            .vertical();
        // An upright run stands across the column; a run turned along it is not one.
        let [a, b, c, d, ..] = drawn.matrix;
        if upright && (a <= 0.0 || d <= 0.0 || b.abs() > 1e-3 * a || c.abs() > 1e-3 * d) {
            return Err(Unsupported::Direction);
        }
        // The show's units, the touched ones among them.
        let s0 = (0..t0)
            .rev()
            .take_while(|&at| show_of(at) == Some(show))
            .last()
            .unwrap_or(t0);
        let s1 = (t1..units.len())
            .take_while(|&at| show_of(at) == Some(show))
            .last()
            .map_or(t1, |at| at.saturating_add(1));
        let char_start = units.get(t0).map_or(0, |unit| unit.chars.start);
        let char_end = units.get(t_last).map_or(old.len(), |unit| unit.chars.end);
        let middle = fresh
            .get(
                char_start
                    ..fresh
                        .len()
                        .saturating_sub(old.len().saturating_sub(char_end)),
            )
            .ok_or(Unsupported::Operators)?;
        let offsets: Vec<usize> = new.char_indices().map(|(at, _)| at).collect();
        let glyph_at = |at: usize| {
            units
                .get(at)
                .and_then(|unit| unit.glyph)
                .and_then(|g| glyphs.get(g))
        };
        // The new characters in the show's font, its copy or a new font of steps 2 and 3.
        let mut encoder = Encoder::new(recorder, &[show], source, substitutes, 1.0)?;
        let order = [key];
        let mut chosen = Vec::new();
        let mut missing = Vec::new();
        for (k, &c) in middle.iter().enumerate() {
            match encoder.choose(copies, &order, c)? {
                Some(found) => chosen.push(found),
                // A new font is horizontal: no step 2 or 3 for a vertical run.
                None if !upright => return Err(Unsupported::Direction),
                None => {
                    let at = char_start
                        .checked_add(k)
                        .and_then(|i| offsets.get(i))
                        .map_or(start, |&at| start.saturating_add(at));
                    missing.push(encoder.miss(&order, c, at));
                }
            }
        }
        if !missing.is_empty() {
            return if encoder.composite {
                Err(Unsupported::CompositeFont)
            } else {
                Ok(Planned::Missing(missing))
            };
        }
        let kept = |at: usize| -> Option<Placed> {
            let glyph = glyph_at(at)?;
            let length = glyph.length.min(4);
            let bytes = glyph.code.to_be_bytes();
            Some(Placed {
                font: glyph.font,
                size: state.size,
                hex: recorder
                    .collector
                    .fonts
                    .get(&glyph.font)
                    .is_some_and(|font| font.cmap.is_some()),
                bytes: bytes.get(4_usize.saturating_sub(length)..)?.to_vec(),
                x: glyph.offset,
                step: glyph.step,
                ink: !glyph.text.chars().all(char::is_whitespace),
            })
        };
        let spacing = |bytes: &[u8]| {
            state.char_spacing
                + if bytes == [32] {
                    state.word_spacing
                } else {
                    0.0
                }
        };
        // Where the show's text space ends, after the number following its last glyph.
        let last = (s0..s1)
            .rev()
            .find_map(glyph_at)
            .ok_or(Unsupported::Operators)?;
        let scaling = if upright {
            state.horizontal_scaling
        } else {
            1.0
        };
        let old_end = last.offset + last.step - last.adjust * state.size * scaling / 1000.0;
        let mut placed: Vec<Placed> = Vec::new();
        let mut out = Vec::new();
        let mut sim = Sim::of(state);
        let (end, scaling, shift) = if upright {
            // Every glyph again at Tz 100, then centred and compressed.
            let unscaled = |at: usize| {
                kept(at)
                    .map(|mut glyph| {
                        glyph.step /= state.horizontal_scaling;
                        glyph
                    })
                    .ok_or(Unsupported::Operators)
            };
            let mut all: Vec<Placed> = Vec::new();
            for at in s0..t0 {
                all.push(unscaled(at)?);
            }
            for found in &chosen {
                all.push(Placed {
                    font: found.font,
                    size: found.size,
                    hex: found.hex,
                    bytes: found.bytes.clone(),
                    x: 0.0,
                    step: found.width * found.size + spacing(&found.bytes),
                    ink: true,
                });
            }
            for at in t1..s1 {
                all.push(unscaled(at)?);
            }
            let natural: f32 = all.iter().map(|glyph| glyph.step).sum();
            let room = state.size.max(old_end);
            let fit = if natural > room && natural > 0.0 {
                room / natural
            } else {
                1.0
            };
            let mut x = (old_end - natural * fit) / 2.0;
            for mut glyph in all {
                glyph.x = x;
                glyph.step *= fit;
                x += glyph.step;
                placed.push(glyph);
            }
            if fit != state.horizontal_scaling {
                space(&mut out);
                number(&mut out, fit * 100.0)?;
                out.extend_from_slice(b" Tz");
                sim.horizontal_scaling = fit;
            }
            (old_end, fit, 0.0)
        } else {
            // The cells of the touched glyphs, and the pitch of the run.
            let cells: Vec<f32> = (t0..t1).filter_map(glyph_at).map(|g| g.offset).collect();
            let run: Vec<f32> = (s0..s1).filter_map(glyph_at).map(|g| g.offset).collect();
            let pitch = match (run.first(), run.last()) {
                (Some(first), Some(last)) if run.len() > 1 => {
                    (last - first) / (run.len().saturating_sub(1)) as f32
                }
                _ => last.step,
            };
            let (n, m) = (chosen.len(), cells.len());
            let last_show = line_glyphs
                .last()
                .is_some_and(|&g| drawn.glyphs.end == g.saturating_add(1));
            if n != m && !(grows && last_show) {
                return Err(Unsupported::Direction);
            }
            let shift = (n as f32 - m as f32) * pitch;
            for at in s0..t0 {
                placed.push(kept(at).ok_or(Unsupported::Operators)?);
            }
            let fonts = &recorder.collector.fonts;
            for (k, found) in chosen.iter().enumerate() {
                let x = match cells.get(k) {
                    Some(&cell) => cell,
                    None => {
                        let beyond = k.saturating_sub(m).saturating_add(1) as f32;
                        cells.last().copied().unwrap_or(0.0) + beyond * pitch
                    }
                };
                let code = found
                    .bytes
                    .iter()
                    .fold(0_u32, |code, &byte| (code << 8) | u32::from(byte));
                let advance = fonts
                    .get(&encoder.base(found.font))
                    .ok_or(Unsupported::Operators)?
                    .vertical_advance(code, found.bytes.len());
                placed.push(Placed {
                    font: found.font,
                    size: found.size,
                    hex: found.hex,
                    bytes: found.bytes.clone(),
                    x,
                    step: advance * found.size + spacing(&found.bytes),
                    ink: true,
                });
            }
            for at in t1..s1 {
                let mut glyph = kept(at).ok_or(Unsupported::Operators)?;
                glyph.x += shift;
                placed.push(glyph);
            }
            if shift != 0.0
                && need_after(
                    recorder
                        .events
                        .get(event_at.saturating_add(1)..)
                        .unwrap_or_default(),
                ) != Need::Nothing
            {
                return Err(Unsupported::Direction);
            }
            (old_end + shift, 1.0, shift)
        };
        let tj = event.name == b"TJ";
        write_placed(
            &mut out,
            &mut sim,
            &placed,
            tj,
            scaling,
            Some(end),
            &|key| encoder.name(key),
        )?;
        restore(&mut out, &mut sim, state, Need::Nothing)?;
        if !matches!(out.first(), Some(b'[' | b'(' | b'/' | b'<')) {
            out.insert(0, b' ');
        }
        // Overflow: the column grown past the frame's end.
        let over = shift < 0.0
            && dot(line.baseline[1], frame.along) - shift * c.hypot(d) > frame.end + 0.5;
        Ok(Planned::Splice(
            Splice {
                source,
                range: event.span.range.clone(),
                bytes: out,
            },
            over,
        ))
    }
}

/// How many characters `old` and `fresh` share at their start, and then at their end.
fn common_ends(old: &[char], fresh: &[char]) -> (usize, usize) {
    let prefix = old.iter().zip(fresh).take_while(|(a, b)| a == b).count();
    let room = old.len().min(fresh.len()).saturating_sub(prefix);
    let suffix = old
        .iter()
        .rev()
        .zip(fresh.iter().rev())
        .take(room)
        .take_while(|(a, b)| a == b)
        .count();
    (prefix, suffix)
}

/// What a reflowed block gives.
#[allow(clippy::large_enum_variant)]
enum Reflowed {
    Splice {
        splices: Vec<Splice>,
        overflow: Option<OverflowPlan>,
        chosen: Option<Choice>,
        hidden: usize,
        /// Step 2's fonts for shaped glyphs the block's subsets lack (right-to-left text).
        new_fonts: Vec<EmbeddedFont>,
        substitutions: Vec<Substitution>,
        /// Step 3's choice for shaped text the caller may still make.
        pending: Option<MissingGlyphs>,
    },
    Missing(Vec<Miss>),
    Glyphs(MissingGlyphs),
}

/// One glyph of a reflowed block, at a character of the new text.
#[derive(Clone)]
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
    /// Its shaped advance less `width`, per unit of font size: a `TJ` number after it.
    kern: f32,
    /// Its shaped offset from the pen, per unit of font size: a `TJ` number before it, taken
    /// back after it.
    offset: f32,
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
    #[allow(clippy::too_many_lines, clippy::too_many_arguments)]
    fn block(
        &self,
        block: &TextBlock,
        text: &str,
        others: &[TextBlock],
        choice: Option<Choice>,
        copies: &mut Copies<'_>,
        substitutes: &[Substitute],
        sources: &FontSources<'_>,
        style: &BlockStyle,
    ) -> Result<Reflowed, Unsupported> {
        let recorder = self.recorder;
        let rtl = right_to_left(block);
        // A chosen font sets every character: nothing keeps its old code.
        let forced = style.font.is_some();
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
        let set_by_tw = block.justification == Some(Justification::WordSpacing);
        // `Tw` widens only the single-byte code 32, which a new font does not have.
        let word_spacing = set_by_tw && !forced;
        for &show in &shows {
            let other = &recorder
                .shows
                .get(show)
                .ok_or(Unsupported::Operators)?
                .state;
            // A block justified by `Tw` sets it per line, and so does its rewrite; lines an
            // earlier Keep and warn hid (`3 Tr`) are checked below.
            let other = GraphicsState {
                word_spacing: if set_by_tw {
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
        let mut frame = reflow::Frame {
            lines: shown,
            ..reflow::Frame::of(block).ok_or(Unsupported::Operators)?
        };
        // The style's size scales every font of the block, and the spacing that goes with it.
        let ratio = style.size.map_or(1.0, |size| size / frame.size);
        if !ratio.is_finite() || ratio <= 0.0 {
            return Err(Unsupported::Style);
        }
        frame.size *= ratio;
        frame.pitch = style
            .line_spacing
            .map_or(frame.pitch * ratio, |multiple| multiple * frame.size);
        if let Some(alignment) = style.alignment {
            frame.alignment = alignment;
        }
        if frame.alignment == Alignment::Justified
            && (frame.justification.is_none() || (forced && set_by_tw))
        {
            // `TJ` numbers stretch a line in any font.
            frame.justification = Some(Justification::Adjustments);
        }
        // The new box: the first baseline moves with its top left, and the text fills its size.
        let moved_block;
        let (framed, resized) = if let Some([left, top, right, bottom]) = style.frame {
            if frame.along[1].abs() > 1e-3 {
                return Err(Unsupported::Style);
            }
            let [l, t, r, b] = framed.bbox;
            let by = [left - l, top - t];
            let wider = (right - left) - (r - l);
            let taller = (bottom - top) - (b - t);
            frame.origin = [frame.origin[0] + by[0], frame.origin[1] + by[1]];
            frame.width = (frame.width + wider).max(style::MIN_FRAME);
            if taller.abs() > 1e-2 {
                let first = framed
                    .lines
                    .first()
                    .map_or(0.0, |line| line.bbox[3] - line.bbox[1]);
                // At most a page's worth of lines, however small the pitch.
                #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
                let across = (((bottom - top - first) / frame.pitch + 1e-3)
                    .floor()
                    .max(0.0) as usize)
                    .min(100_000);
                frame.lines = across.saturating_add(1);
            }
            let shifted =
                |[x0, y0, x1, y1]: CharBox| [x0 + by[0], y0 + by[1], x1 + by[0], y1 + by[1]];
            moved_block = TextBlock {
                bbox: [left, top, right, bottom],
                lines: framed
                    .lines
                    .iter()
                    .map(|line| Line {
                        bbox: shifted(line.bbox),
                        ..line.clone()
                    })
                    .collect(),
                ..framed.clone()
            };
            (&moved_block, wider.abs() > 1e-2)
        } else {
            (framed, false)
        };
        // A one-line block's frame is only its old text, so one line in stays one line out
        // (a right-aligned or centred cell grows along its line, as a left-aligned one does), until
        // a new width says otherwise.
        let planned = if block.lines.len() == 1 && !text.contains('\n') && !resized {
            reflow::Frame {
                width: f32::MAX,
                ..frame
            }
        } else {
            frame
        };
        let base_spacing = style
            .char_spacing
            .map_or(state.char_spacing * ratio, |percent| {
                percent / 100.0 * state.size * ratio
            });

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

        let clusters = if rtl {
            Vec::new()
        } else {
            new_clusters(&fresh, prefix..tail_new)
        };
        let in_cluster = |i: usize| clusters.iter().any(|cluster| cluster.contains(&i));

        let mut encoder = Encoder::new(recorder, &shows, source, substitutes, ratio)?;
        let mut pieces: Vec<Piece> = Vec::new();
        let mut missing = Vec::new();
        let mut kept_fonts: Vec<Option<u64>> = vec![None; fresh.len()];
        for (i, &(at, c)) in fresh.iter().enumerate() {
            if in_cluster(i) {
                continue;
            }
            let before = if i < prefix {
                Some(i)
            } else if i >= tail_new {
                i.checked_sub(tail_new)
                    .and_then(|k| k.checked_add(tail_old))
            } else {
                None
            };
            let glyph = before
                .filter(|_| !forced)
                .and_then(|o| old.get(o).and_then(|(_, unit)| *unit).map(|unit| (o, unit)))
                .and_then(|(o, (l, u))| {
                    let g = runs.get(l)?.units.get(u)?.glyph?;
                    Some((o, unit_range(l, u)?, g))
                });
            if let Some((o, range, g)) = glyph
                && kept(&range)
            {
                if rtl {
                    // Right-to-left text is shaped again, kept characters in their fonts.
                    if let Some(slot) = kept_fonts.get_mut(i) {
                        *slot = glyphs.get(g).map(|glyph| glyph.font);
                    }
                    continue;
                }
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
                        size: size * ratio,
                        bytes: glyph
                            .code
                            .to_be_bytes()
                            .get(4_usize.saturating_sub(length)..)
                            .unwrap_or_default()
                            .to_vec(),
                        hex: font.cmap.is_some(),
                        width: font.width(glyph.code, length),
                        blank: glyph.text.chars().all(char::is_whitespace),
                        kern: 0.0,
                        offset: 0.0,
                    });
                }
                continue;
            }
            if c == '\n' || c == '\r' || rtl {
                continue;
            }
            let c = if c.is_whitespace() { ' ' } else { c };
            let order: Vec<u64> = pieces
                .last()
                .map(|piece| piece.font)
                .into_iter()
                .chain(encoder.fonts.iter().map(|(key, ..)| *key))
                .collect();
            let chosen = if forced {
                encoder.lent(state.font, c)?
            } else {
                encoder.choose(copies, &order, c)?
            };
            match chosen {
                Some(chosen) => pieces.push(Piece {
                    at,
                    font: chosen.font,
                    size: chosen.size,
                    bytes: chosen.bytes,
                    hex: chosen.hex,
                    width: chosen.width,
                    blank: c == ' ',
                    kern: 0.0,
                    offset: 0.0,
                }),
                None if c == ' ' => pieces.push(Piece {
                    at,
                    font: state.font.unwrap_or_default(),
                    size: state.size * ratio,
                    bytes: Vec::new(),
                    hex: false,
                    // shortcut: a space no font draws is a quarter em; measure the old gaps when
                    // a file without space glyphs is reflowed.
                    width: 0.25,
                    blank: true,
                    kern: 0.0,
                    offset: 0.0,
                }),
                None => missing.push(encoder.miss(&order, c, at)),
            }
        }
        if !missing.is_empty() {
            if encoder.composite {
                return Err(Unsupported::CompositeFont);
            }
            return Ok(Reflowed::Missing(missing));
        }
        let mut new_fonts = Vec::new();
        let mut substitutions = Vec::new();
        let shaping = if rtl || !clusters.is_empty() {
            let library = sources.library.ok_or(Unsupported::Shaping)?;
            let originals: Vec<u64> = encoder.fonts.iter().map(|(key, ..)| *key).collect();
            let default = state.font.ok_or(Unsupported::Operators)?;
            // In a left-to-right block only the clusters are shaped, in the fonts around them.
            for piece in &pieces {
                if let Ok(i) = fresh.binary_search_by_key(&piece.at, |&(at, _)| at)
                    && let Some(slot) = kept_fonts.get_mut(i)
                {
                    *slot = Some(encoder.base(piece.font));
                }
            }
            let scope: Vec<bool> = (0..fresh.len()).map(|i| rtl || in_cluster(i)).collect();
            let inputs = ShapingInputs {
                fresh: &fresh,
                kept: kept_fonts,
                scope: &scope,
                default,
                originals: &originals,
                rtl,
                sources,
            };
            match Shaping::new(text, &inputs, library, recorder)? {
                Ok(shaping) => Some(shaping),
                Err(missing) => return Ok(Reflowed::Glyphs(missing)),
            }
        } else {
            None
        };
        let pending = shaping.as_ref().and_then(|shaping| shaping.pending.clone());
        // The clusters of a left-to-right block join its pieces in text order.
        if let (false, Some(shaping)) = (rtl, &shaping) {
            let mut glyphs = Vec::new();
            for cluster in &clusters {
                let start = fresh.get(cluster.start).ok_or(Unsupported::Shaping)?.0;
                let end = fresh.get(cluster.end).map_or(text.len(), |&(at, _)| at);
                glyphs.extend(shaping.run(start..end, false)?);
            }
            match shaping.pieces(&[glyphs], &mut encoder, copies)? {
                Ok(mut set) => {
                    new_fonts = set.fonts;
                    substitutions = set.substitutions;
                    pieces.extend(set.lines.pop().unwrap_or_default());
                    pieces.sort_by_key(|piece| piece.at);
                }
                Err(missing) => return Ok(Reflowed::Glyphs(missing)),
            }
        }
        // A shaped cluster's advance in points, at its first character, for the plan.
        let mut shaped_points: HashMap<usize, f32> = HashMap::new();
        if let (true, Some(shaping)) = (rtl, &shaping) {
            for glyph in shaping.measure()? {
                let size = encoder
                    .size(shaping.base(glyph.font))
                    .unwrap_or(state.size * ratio);
                *shaped_points.entry(glyph.at).or_default() +=
                    (glyph.advance * size + base_spacing) * scaling * scale;
            }
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
                    .or_insert(advance(piece, base_spacing) * scale);
            }
        }
        let points = |at: usize, c: char| {
            if rtl {
                shaped_points.get(&at).copied().unwrap_or(0.0)
            } else {
                by_char.get(&c).copied().unwrap_or(0.0)
            }
        };
        let page_box = self
            .page
            .map_or([f32::MIN, f32::MIN, f32::MAX, f32::MAX], |page| {
                [0.0, 0.0, page.size.0, page.size.1]
            });
        let (frame, planned) = if sources.keep_lines {
            let wide = reflow::unwrapped(&frame, text, points);
            (wide, wide)
        } else {
            (frame, planned)
        };
        let overflow = reflow::overflow_at(framed, &planned, text, points, others, page_box);
        let (plan, tracking, visible, chosen) = match &overflow {
            None => (
                reflow::reflow_at(&planned, text, points),
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
                    reflow::reflow_at(&frame, text, points),
                    0.0,
                    usize::MAX,
                    Some(Choice::Extend),
                ),
                // Keep and warn, also for a choice that is disabled.
                _ => (
                    reflow::reflow_at(&frame, text, points),
                    0.0,
                    frame.lines,
                    Some(Choice::Keep),
                ),
            },
        };
        let char_spacing = base_spacing - tracking / (scale * scaling);

        // Each line's glyphs, from its start: shaped right-to-left lines in visual order.
        let line_sets: Vec<Vec<Piece>> = match shaping.as_ref().filter(|_| rtl) {
            None => plan
                .lines
                .iter()
                .map(|line| {
                    pieces
                        .iter()
                        .filter(|piece| line.range.contains(&piece.at))
                        .cloned()
                        .collect()
                })
                .collect(),
            Some(shaping) => {
                let shaped: Vec<Vec<ShapedGlyph>> = plan
                    .lines
                    .iter()
                    .map(|line| shaping.line(line.range.clone()))
                    .collect::<Result<_, _>>()?;
                match shaping.pieces(&shaped, &mut encoder, copies)? {
                    Ok(set) => {
                        new_fonts = set.fonts;
                        substitutions = set.substitutions;
                        set.lines
                    }
                    Err(missing) => return Ok(Reflowed::Glyphs(missing)),
                }
            }
        };

        // The operators.
        let before = first
            .checked_sub(1)
            .and_then(|at| recorder.events.get(at))
            .ok_or(Unsupported::Operators)?;
        let mut out = Vec::new();
        let mut sim = Sim::of(&before.state);
        restore(&mut out, &mut sim, state, Need::Nothing)?;
        if let Some(colour) = style.colour {
            set_colour(&mut out, b"DeviceRGB", &style::components(colour))?;
        }
        if char_spacing != sim.char_spacing {
            space(&mut out);
            number(&mut out, char_spacing)?;
            out.extend_from_slice(b" Tc");
            sim.char_spacing = char_spacing;
        }
        let mut hidden = 0_usize;
        let mut end = None;
        for (n, (line, set)) in plan.lines.iter().zip(&line_sets).enumerate() {
            let line_pieces: Vec<&Piece> = set.iter().collect();
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
                .map(|piece| advance(piece, char_spacing) + piece.kern * piece.size * scaling)
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
                // A right-to-left paragraph's last line keeps the frame's right edge.
                Alignment::Justified if rtl && stretch.is_none() => room,
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
                let mut shift = (piece.kern - piece.offset) * piece.size * scaling;
                if piece.bytes.is_empty() {
                    shift += advance(piece, char_spacing);
                } else {
                    if piece.offset != 0.0 {
                        let n = ((-piece.offset * piece.size * scaling / unit) * 1000.0).round()
                            / 1000.0;
                        items.push(Item::Number(n));
                        moved -= n * unit;
                    }
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
        if style.colour.is_some() {
            let fill = &target.fill;
            if fill.pattern.is_some() {
                return Err(Unsupported::Style);
            }
            set_colour(&mut out, &fill.space, &fill.components)?;
        }
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
            new_fonts,
            substitutions,
            pending,
        })
    }
}

impl Page<'_> {
    /// The state of the show that drew `block`'s first glyph, and the operator's stream.
    fn first_show(&self, block: &TextBlock) -> Option<(&GraphicsState, SpanSource)> {
        let glyph = block
            .lines
            .iter()
            .flat_map(|line| &line.chars)
            .find_map(|c| self.glyph_of(c))?;
        let show = *self.recorder.glyph_shows.get(glyph)?;
        let state = &self.recorder.shows.get(show)?.state;
        let source = self.recorder.collector.glyphs.get(glyph)?.link.span.source;
        Some((state, source))
    }

    /// The key and resource name of `block`'s first font, when a new font can go beside it: not in
    /// a form, whose block cannot name the page's new fonts.
    fn first_font(&self, block: &TextBlock) -> Option<(u64, Vec<u8>)> {
        let (state, source) = self.first_show(block)?;
        if !matches!(source, SpanSource::Page { .. }) {
            return None;
        }
        Some((state.font?, state.font_name.clone()?))
    }
}

fn recorded(
    document: &Document,
    revisions: &RevisionStore,
    index: usize,
) -> Result<Recorder, TextError> {
    let mut recorder = Recorder::default();
    revisions.page_text(document, index, &mut recorder)?;
    Ok(recorder)
}

/// What the text panel shows of `block` of page `index` (a3-2); `None` for a block without glyphs on
/// the page: it comes from another revision.
///
/// # Errors
///
/// [`TextError::Core`] when the page cannot be interpreted.
pub fn block_style(
    document: &Document,
    revisions: &RevisionStore,
    index: usize,
    block: &TextBlock,
    library: Option<&FontLibrary>,
) -> Result<Option<BlockStyleInfo>, TextError> {
    let recorder = recorded(document, revisions, index)?;
    let page = Page::new(&recorder, document.structure().pages.get(index));
    let Some((state, _)) = page.first_show(block) else {
        return Ok(None);
    };
    let Some(frame) = reflow::Frame::of(block) else {
        return Ok(None);
    };
    let Some(pdf) = state
        .font
        .and_then(|key| recorder.collector.fonts.get(&key))
    else {
        return Ok(None);
    };
    let font_style = fallback::style_of(pdf);
    let (bold, italic) = (font_style.weight >= 600, font_style.italic);
    let text = block.text();
    let misses = text_misses(&text, state.font.unwrap_or_default(), b"");
    let lent = lenders(&recorder, &misses);
    let toggled = |bold: bool, italic: bool| {
        fallback::toggled_face(
            &recorder.collector.fonts,
            pdf,
            &text,
            &lent,
            library,
            bold,
            italic,
        )
    };
    // The page's text colours by how many shows use them.
    let mut colours: Vec<(u32, usize)> = Vec::new();
    for show in &recorder.shows {
        if show.state.render_mode != 3
            && let Some(colour) = style::rgb(&show.state.fill.space, &show.state.fill.components)
        {
            match colours.iter_mut().find(|(seen, _)| *seen == colour) {
                Some((_, count)) => *count = count.saturating_add(1),
                None => colours.push((colour, 1)),
            }
        }
    }
    colours.sort_by_key(|(_, count)| std::cmp::Reverse(*count));
    let family = pdf
        .program()
        .and_then(|program| program.family_name())
        .unwrap_or_else(|| fallback::font_name(Some(pdf)));
    Ok(Some(BlockStyleInfo {
        font: fallback::font_name(Some(pdf)),
        family,
        bold,
        italic,
        bold_toggle: toggled(!bold, italic),
        italic_toggle: toggled(bold, !italic),
        size: frame.size,
        colour: style::rgb(&state.fill.space, &state.fill.components),
        document_colours: colours
            .into_iter()
            .take(8)
            .map(|(colour, _)| colour)
            .collect(),
        alignment: block.alignment,
        char_spacing: if state.size == 0.0 {
            0.0
        } else {
            state.char_spacing / state.size * 100.0
        },
        line_spacing: if frame.size > 0.0 {
            frame.pitch / frame.size
        } else {
            0.0
        },
        frame: block.bbox,
    }))
}

/// The fonts a3-2's font field offers for `block` of page `index`, best first: those that have
/// characters of its text, in its first font's weight class and slant.
///
/// # Errors
///
/// [`TextError::Core`] when the page cannot be interpreted.
pub fn block_fonts(
    document: &Document,
    revisions: &RevisionStore,
    index: usize,
    block: &TextBlock,
    library: Option<&FontLibrary>,
) -> Result<Vec<fallback::FontCandidate>, TextError> {
    let recorder = recorded(document, revisions, index)?;
    let page = Page::new(&recorder, document.structure().pages.get(index));
    let Some((state, _)) = page.first_show(block) else {
        return Ok(Vec::new());
    };
    let Some(pdf) = state
        .font
        .and_then(|key| recorder.collector.fonts.get(&key))
    else {
        return Ok(Vec::new());
    };
    let text = block.text();
    let misses = text_misses(&text, state.font.unwrap_or_default(), b"");
    let lent = lenders(&recorder, &misses);
    Ok(fallback::block_candidates(
        &recorder.collector.fonts,
        pdf,
        &text,
        &lent,
        &FontSources {
            library,
            ask: false,
            mark: false,
            keep_lines: false,
            choice: None,
        },
    ))
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
    /// Whether each font's program allows at most preview and print (Q09).
    restricted: HashMap<u64, bool>,
    /// The fonts with the name and size their shows set them with, then the font copies and new
    /// fonts made.
    fonts: Vec<(u64, Vec<u8>, f32)>,
    /// The font each copy and new font stands in for.
    bases: HashMap<u64, u64>,
    substitutes: &'a [Substitute],
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
        substitutes: &'a [Substitute],
        ratio: f32,
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
                fonts.push((font, name.clone(), state.size * ratio));
            }
        }
        let mut bases = HashMap::new();
        // A new font is set at its base font's size; one whose base the shows do not set is not
        // used.
        for substitute in substitutes {
            let size = fonts
                .iter()
                .find(|(key, ..)| *key == substitute.base)
                .map(|(_, _, size)| *size);
            if let Some(size) = size
                && !fonts.iter().any(|(key, ..)| *key == substitute.key)
            {
                fonts.push((substitute.key, substitute.name.clone(), size));
                // A font of the page keeps its own face, so it draws only what it lends.
                if !substitute.existing {
                    bases.insert(substitute.key, substitute.base);
                }
            }
        }
        Ok(Self {
            recorder,
            programs: HashMap::new(),
            restricted: HashMap::new(),
            fonts,
            bases,
            substitutes,
            source,
            composite: false,
        })
    }

    /// The size a font is set at.
    fn size(&self, key: u64) -> Option<f32> {
        self.fonts
            .iter()
            .find(|(font, ..)| *font == key)
            .map(|(_, _, size)| *size)
    }

    /// The name a font is set by.
    fn name(&self, key: u64) -> Option<Vec<u8>> {
        self.fonts
            .iter()
            .find(|(font, ..)| *font == key)
            .map(|(_, name, _)| name.clone())
    }

    /// The font of the page `key` stands for: itself, or the original of a copy or new font.
    fn base(&self, key: u64) -> u64 {
        self.bases.get(&key).copied().unwrap_or(key)
    }

    /// The face of a font of the page: its PostScript name without the subset tag.
    fn face(&self, key: u64) -> Option<&'a str> {
        let font = self.recorder.collector.fonts.get(&self.base(key))?;
        font.resource.base_font.as_deref().map(strip_subset_tag)
    }

    /// The fonts `order` names that a character may come from: the originals, without repeats,
    /// of the first one's face (module documentation).
    fn candidates(&self, order: &[u64]) -> Vec<u64> {
        let face = order.first().map(|&key| self.face(key));
        let mut keys: Vec<u64> = Vec::new();
        for &key in order {
            let key = self.base(key);
            if !keys.contains(&key) && face.is_none_or(|face| self.face(key) == face) {
                keys.push(key);
            }
        }
        keys
    }

    /// `c` at byte `at`, missing from the fonts of `order`.
    fn miss(&self, order: &[u64], c: char, at: usize) -> Miss {
        let font = order
            .first()
            .map(|&key| self.base(key))
            .or_else(|| self.fonts.first().map(|(key, ..)| *key))
            .unwrap_or_default();
        Miss {
            c,
            at,
            font,
            name: self.name(font).unwrap_or_default(),
        }
    }

    /// `c` in the first font of `order` that draws it (module documentation), making the font
    /// copy it needs; then through `/Differences` in a copy of a simple font whose program has
    /// it (step 1); then in a new font of steps 2 and 3. `None` when none does.
    fn choose(
        &mut self,
        copies: &mut Copies<'_>,
        order: &[u64],
        c: char,
    ) -> Result<Option<Chosen>, Unsupported> {
        let recorder = self.recorder;
        let candidates = self.candidates(order);
        let size_of = |fonts: &[(u64, Vec<u8>, f32)], key: u64| {
            fonts
                .iter()
                .find(|(font, ..)| *font == key)
                .map(|(_, _, size)| *size)
        };
        for &key in &candidates {
            let Some(font) = recorder.collector.fonts.get(&key) else {
                continue;
            };
            // Q09: a program that allows at most preview and print lends no glyph to new text.
            let restricted = *self
                .restricted
                .entry(key)
                .or_insert_with(|| fallback::restriction(font).is_some());
            if restricted {
                continue;
            }
            let program = self.programs.entry(key).or_insert_with(|| font.program());
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
                self.bases.insert(copy, key);
            }
            return Ok(Some(Chosen {
                font: copy,
                bytes: found.bytes,
                width: found.width,
                hex: true,
                size,
            }));
        }
        // Step 1: a glyph of the program that no code shows, through `/Differences`.
        if let SpanSource::Page { .. } = self.source {
            for &key in &candidates {
                let Some(font) = recorder.collector.fonts.get(&key) else {
                    continue;
                };
                let Some(Some(program)) = self.programs.get(&key) else {
                    continue;
                };
                let Some((glyph, width)) = differences_glyph(font, program, c) else {
                    continue;
                };
                let named = self.fonts.iter().find(|(font, ..)| *font == key).cloned();
                let Some((_, name, size)) = named else {
                    continue;
                };
                let Some((copy, copy_name, code)) =
                    copies.add_simple(key, &name, font, Some(program), c, &glyph, width)?
                else {
                    continue;
                };
                if !self.fonts.iter().any(|(font, ..)| *font == copy) {
                    self.fonts.push((copy, copy_name, size));
                    self.bases.insert(copy, key);
                }
                return Ok(Some(Chosen {
                    font: copy,
                    bytes: vec![code],
                    width: width / 1000.0,
                    hex: false,
                    size,
                }));
            }
        }
        // New fonts go into the page's resources only: a form's block cannot name them.
        if !matches!(self.source, SpanSource::Page { .. }) {
            self.composite = true;
            return Ok(None);
        }
        let base = candidates.first().copied();
        let marked = |substitute: &&Substitute| substitute.marks.contains(&c);
        let keeps = self
            .substitutes
            .iter()
            .filter(marked)
            .find(|substitute| Some(substitute.base) == base)
            .or_else(|| self.substitutes.iter().find(marked))
            .map(|substitute| substitute.base);
        if let Some(key) = keeps {
            return self.without_glyph(copies, key, c);
        }
        self.lent(base, c)
    }

    /// `c` in a new font or a font of the page of steps 2 and 3, those for the characters of `base`
    /// first, else any that has it. `None` when none does.
    fn lent(&self, base: Option<u64>, c: char) -> Result<Option<Chosen>, Unsupported> {
        let recorder = self.recorder;
        let size_of = |fonts: &[(u64, Vec<u8>, f32)], key: u64| {
            fonts
                .iter()
                .find(|(font, ..)| *font == key)
                .map(|(_, _, size)| *size)
        };
        let mut lent: Vec<&Substitute> = self
            .substitutes
            .iter()
            .filter(|substitute| self.fonts.iter().any(|(key, ..)| *key == substitute.key))
            .collect();
        lent.sort_by_key(|substitute| Some(substitute.base) != base);
        for substitute in lent {
            let size = size_of(&self.fonts, substitute.key).ok_or(Unsupported::Operators)?;
            if !substitute.existing {
                if let Some((_, code, width)) =
                    substitute.glyphs.iter().find(|(drawn, ..)| *drawn == c)
                {
                    return Ok(Some(Chosen {
                        font: substitute.key,
                        bytes: code.clone(),
                        width: *width,
                        hex: true,
                        size,
                    }));
                }
                continue;
            }
            let Some(font) = recorder.collector.fonts.get(&substitute.key) else {
                continue;
            };
            let program = font.program();
            let chosen = match font.cmap {
                None => encode(font, program.as_ref(), c).map(|code| Chosen {
                    font: substitute.key,
                    bytes: vec![code],
                    width: font.width(u32::from(code), 1),
                    hex: false,
                    size,
                }),
                Some(_) => encode_composite(font, program.as_ref(), c)
                    .filter(|found| found.needs.is_none())
                    .map(|found| Chosen {
                        font: substitute.key,
                        bytes: found.bytes,
                        width: found.width,
                        hex: true,
                        size,
                    }),
            };
            if chosen.is_some() {
                return Ok(chosen);
            }
        }
        Ok(None)
    }

    /// `c` in a copy of the font `key` with a code that draws no glyph and reads back as `c`
    /// ([`FontSources::mark`]). `None` when no such code is free, or the font's program has the
    /// glyph and may not lend it (Q09).
    fn without_glyph(
        &mut self,
        copies: &mut Copies<'_>,
        key: u64,
        c: char,
    ) -> Result<Option<Chosen>, Unsupported> {
        let recorder = self.recorder;
        let named = self.fonts.iter().find(|(font, ..)| *font == key).cloned();
        let (Some(font), Some((_, name, size))) = (recorder.collector.fonts.get(&key), named)
        else {
            return Ok(None);
        };
        if font.vertical() {
            return Ok(None);
        }
        let program = font.program();
        // The reader draws its `.notdef`, which has no width of its own to rely on.
        let advance = if ideograph(c) { 1000.0 } else { 500.0 };
        let (copy, copy_name, bytes, hex) = if font.cmap.is_none() {
            let lends = program
                .as_ref()
                .and_then(|program| program.glyph_for_char(c))
                .is_some_and(|glyph| glyph.0 != 0);
            if lends {
                return Ok(None);
            }
            // The name gives the text without a ToUnicode CMap; the program has no such glyph.
            let glyph = match u32::from(c) {
                value @ ..=0xFFFF => format!("uni{value:04X}"),
                value => format!("u{value:05X}"),
            };
            let Some((copy, copy_name, code)) =
                copies.add_simple(key, &name, font, program.as_ref(), c, &glyph, advance)?
            else {
                return Ok(None);
            };
            (copy, copy_name, vec![code], false)
        } else {
            let taken = copies
                .list
                .iter()
                .find(|copied| copied.base == key)
                .map_or(&[][..], |copied| copied.texts.as_slice());
            let Some((bytes, cid)) = program
                .as_ref()
                .and_then(|program| code_without_glyph(font, program, taken, c))
            else {
                return Ok(None);
            };
            let needs = Needs {
                cid,
                width: Some(advance),
                text: true,
                c,
            };
            let (copy, copy_name) = copies.add(key, &name, font, &bytes, &needs)?;
            (copy, copy_name, bytes, true)
        };
        if !self.fonts.iter().any(|(font, ..)| *font == copy) {
            self.fonts.push((copy, copy_name, size));
            self.bases.insert(copy, key);
        }
        Ok(Some(Chosen {
            font: copy,
            bytes,
            width: advance / 1000.0,
            hex,
            size,
        }))
    }
}

/// How many CIDs [`code_without_glyph`] tries.
const FREE_CIDS: usize = 1024;

/// A code of composite `font`, with its CID, that has no glyph and no text, or that `taken` (a
/// copy's new codes) gave `c` already. From the top of the CIDs, which a subset rarely reaches.
fn code_without_glyph(
    font: &PdfFont,
    program: &FontProgram<'_>,
    taken: &[(Vec<u8>, String)],
    c: char,
) -> Option<(Vec<u8>, u32)> {
    if !font.cmap_known {
        return None;
    }
    let cmap = font.cmap.as_ref()?;
    let text = c.to_string();
    for cid in (1..=0xFFFF_u32).rev().take(FREE_CIDS) {
        let Some((code, length)) = cmap.code_for_cid(cid) else {
            continue;
        };
        let Some(bytes) = 4_usize
            .checked_sub(length)
            .and_then(|from| code.to_be_bytes().get(from..).map(<[u8]>::to_vec))
        else {
            continue;
        };
        if cmap.codes(&bytes).collect::<Vec<_>>() != [(code, length)] {
            continue;
        }
        match taken.iter().find(|(seen, _)| *seen == bytes) {
            Some((_, seen)) if *seen == text => return Some((bytes, cid)),
            Some(_) => continue,
            None => {}
        }
        let mapped = font.to_unicode.as_ref().and_then(|cmap| cmap.text(code));
        if mapped.is_none() && font.cid_glyph(program, cid).is_none() {
            return Some((bytes, cid));
        }
    }
    None
}

/// A code's bytes and its advance per unit of font size.
type Code = (Vec<u8>, f32);

/// A font of a right-to-left block with the installed or bundled copy of it that shapes its text.
struct Shaper {
    font: ShapingFont,
    data: Vec<u8>,
    index: u32,
    face: FaceInfo,
    /// Whether its licence lets glyphs it has and the subset lacks be embedded (step 2).
    embeddable: bool,
    /// The block's font whose characters it draws.
    base: u64,
    /// Whether it is another face (step 3): it has none of the subset's glyphs.
    similar: bool,
}

/// What [`Shaping::new`] shapes a block's text from.
struct ShapingInputs<'a> {
    /// The new text's characters with their byte offsets.
    fresh: &'a [(usize, char)],
    /// A kept character's font, a new one's `None`.
    kept: Vec<Option<u64>>,
    /// Which characters are shaped.
    scope: &'a [bool],
    default: u64,
    /// The block's fonts.
    originals: &'a [u64],
    /// Whether the block's base direction is right to left.
    rtl: bool,
    sources: &'a FontSources<'a>,
}

/// A similar font's key among the shapers, from the key of the block's font it draws for.
const SIMILAR_KEY: u64 = 0x5B57_0F0C_0FFE_E200;

/// One shaped glyph of a right-to-left block.
struct ShapedGlyph {
    /// The byte offset of its cluster in the new text.
    at: usize,
    /// The font of the block it is set in.
    font: u64,
    /// The glyph in the shaping font.
    glyph: GlyphId,
    /// The text it stands for, a mirrored bracket as the bracket it shows; empty for the second
    /// glyph of a cluster.
    text: String,
    /// Its shaped advance per unit of font size.
    advance: f32,
    /// Its horizontal offset from the pen per unit of font size (a mark's place).
    offset: f32,
}

/// What [`Shaping::pieces`] gives: each line's glyphs and the step 2 fonts they need.
struct ShapedLines {
    lines: Vec<Vec<Piece>>,
    fonts: Vec<EmbeddedFont>,
    substitutions: Vec<Substitution>,
}

/// A right-to-left block's new text, shaped (module documentation): each character in a font of
/// the block, each run in the same font as installed or bundled, its glyphs found again in the
/// block's subset by name.
struct Shaping<'a> {
    text: &'a str,
    recorder: &'a Recorder,
    /// The shaper of each character, by byte offset, ascending: the key of the block's font, or
    /// of the similar font that draws for it.
    fonts: Vec<(usize, u64)>,
    shapers: HashMap<u64, Shaper>,
    /// Whether the block's base direction is right to left.
    base_rtl: bool,
    /// Step 3's choice the caller may still make.
    pending: Option<MissingGlyphs>,
}

impl<'a> Shaping<'a> {
    /// The fonts of `text`'s characters: a kept character's own, a new one the font of the
    /// character before it (or after it, else the default), unless that font's copy lacks it and
    /// another of the block's fonts has it. What no copy can draw goes to step 3: the outer error.
    fn new(
        text: &'a str,
        inputs: &ShapingInputs<'_>,
        library: &FontLibrary,
        recorder: &'a Recorder,
    ) -> Result<Result<Self, MissingGlyphs>, Unsupported> {
        let ShapingInputs {
            fresh,
            kept,
            scope,
            default,
            originals,
            rtl,
            sources,
        } = inputs;
        let mut assigned = kept.clone();
        let mut last = None;
        for slot in &mut assigned {
            match slot {
                Some(font) => last = Some(*font),
                None => *slot = last,
            }
        }
        let first = assigned
            .iter()
            .flatten()
            .next()
            .copied()
            .unwrap_or(*default);
        let mut keys: Vec<u64> = originals.to_vec();
        for font in assigned.iter().flatten() {
            if !keys.contains(font) {
                keys.push(*font);
            }
        }
        let mut shapers = HashMap::new();
        for key in keys {
            if let Some(shaper) = shaper(library, recorder, key) {
                shapers.insert(key, shaper);
            }
        }
        // Through the shaper: a letter without a glyph of its own may decompose into glyphs.
        let covers = |shapers: &HashMap<u64, Shaper>, key: u64, c: char| {
            shapers.get(&key).is_some_and(|shaper| {
                let mut bytes = [0; 4];
                let text = c.encode_utf8(&mut bytes);
                shaper
                    .font
                    .shape(&ShapeRequest::new(text, Direction::LeftToRight))
                    .is_ok_and(|run| run.missing_clusters().is_empty())
            })
        };
        let visible = |c: char| !c.is_whitespace() && !bidi::is_hidden(c.encode_utf8(&mut [0; 4]));
        let fonts_of = |shapers: &HashMap<u64, Shaper>| -> Vec<(usize, u64)> {
            fresh
                .iter()
                .zip(&assigned)
                .map(|(&(at, c), slot)| {
                    let mut font = slot.unwrap_or(first);
                    if visible(c)
                        && !covers(shapers, font, c)
                        && let Some(&other) = originals.iter().find(|&&key| covers(shapers, key, c))
                    {
                        font = other;
                    }
                    (at, font)
                })
                .collect()
        };
        let mut shaping = Self {
            text,
            recorder,
            fonts: fonts_of(&shapers),
            shapers,
            base_rtl: *rtl,
            pending: None,
        };
        // A copy whose licence forbids the glyphs the subset lacks cannot shape this text.
        let mut reason = MissingReason::NotInstalled;
        let forbidden: Vec<u64> = shaping
            .shapers
            .iter()
            .filter(|(_, shaper)| !shaper.embeddable)
            .map(|(key, _)| *key)
            .collect();
        for key in forbidden {
            if shaping.lacks_glyphs(key, scope)? {
                let removed = shaping.shapers.remove(&key);
                if let Some(shaper) = removed {
                    reason = MissingReason::NotEmbeddable {
                        font: shaper.face.postscript_name.clone(),
                        embedding: Embedding::of(&shaper.data, shaper.index),
                    };
                }
                shaping.fonts = fonts_of(&shaping.shapers);
            }
        }
        // Step 3: the characters no copy covers, and all the text of a font without a copy.
        let mut needed: Vec<usize> = Vec::new();
        for (i, (&(_, c), &(_, font))) in fresh.iter().zip(&shaping.fonts).enumerate() {
            let shaped = scope.get(i).copied().unwrap_or(false);
            if shaped
                && (!shaping.shapers.contains_key(&font)
                    || visible(c) && !covers(&shaping.shapers, font, c))
            {
                needed.push(i);
            }
        }
        // A mark stays with its base, in one font.
        let joins = |i: usize| {
            fresh
                .get(i)
                .is_some_and(|&(_, c)| is_combining_mark(c) || cluster_part(c))
        };
        let mut whole = vec![false; fresh.len()];
        for &i in &needed {
            let mut start = i;
            while start > 0 && joins(start) {
                start = start.saturating_sub(1);
            }
            let mut end = i.saturating_add(1);
            while joins(end) {
                end = end.saturating_add(1);
            }
            if let Some(slots) = whole.get_mut(start..end) {
                slots.fill(true);
            }
        }
        let needed: Vec<usize> = (0..fresh.len())
            .filter(|&i| {
                whole.get(i).copied().unwrap_or(false) && scope.get(i).copied().unwrap_or(false)
            })
            .collect();
        let Some(&first_needed) = needed.first() else {
            return Ok(Ok(shaping));
        };
        let mut wanted = String::new();
        for &i in &needed {
            if let Some(&(_, c)) = fresh.get(i)
                && visible(c)
                && !c.is_control()
            {
                wanted.push(c);
            }
        }
        // What the callout names: the new characters, or (a deletion that joins letters anew) all.
        let named = |i: &&usize| kept.get(**i).is_some_and(Option::is_none);
        let mut chars: Vec<(char, usize)> = needed
            .iter()
            .filter(named)
            .filter_map(|&i| fresh.get(i).map(|&(at, c)| (c, at)))
            .filter(|&(c, _)| visible(c))
            .collect();
        if chars.is_empty() {
            chars = needed
                .iter()
                .filter_map(|&i| fresh.get(i).map(|&(at, c)| (c, at)))
                .filter(|&(c, _)| visible(c))
                .collect();
        }
        let font = shaping
            .fonts
            .get(first_needed)
            .map_or(first, |&(_, font)| font);
        let collector = &recorder.collector;
        let (face, pending) = match fallback::similar_shaper(
            library,
            collector.fonts.get(&font),
            &wanted,
            chars,
            reason,
            sources,
        ) {
            Ok(found) => found,
            Err(missing) => return Ok(Err(missing)),
        };
        shaping.pending = pending;
        for i in needed {
            let Some((_, slot)) = shaping.fonts.get_mut(i) else {
                continue;
            };
            let base = *slot;
            let key = base ^ SIMILAR_KEY;
            *slot = key;
            if let std::collections::hash_map::Entry::Vacant(slot) = shaping.shapers.entry(key) {
                let shaper = library
                    .with_data(face.id, |data, index| {
                        Some(Shaper {
                            font: ShapingFont::new_at(data.to_vec(), index, face.instance.as_ref())
                                .ok()?,
                            data: data.to_vec(),
                            index,
                            face: face.clone(),
                            embeddable: true,
                            base,
                            similar: true,
                        })
                    })
                    .flatten()
                    .ok_or(Unsupported::Shaping)?;
                slot.insert(shaper);
            }
        }
        Ok(Ok(shaping))
    }

    /// Whether the characters of `scope` in the font `key` need a glyph its subset cannot give.
    fn lacks_glyphs(&self, key: u64, scope: &[bool]) -> Result<bool, Unsupported> {
        let Some((shaper, pdf)) = self
            .shapers
            .get(&key)
            .zip(self.recorder.collector.fonts.get(&key))
        else {
            return Ok(false);
        };
        let mut start = None;
        let mut ranges = Vec::new();
        for (i, &(at, font)) in self.fonts.iter().enumerate() {
            let inside = font == key && scope.get(i).copied().unwrap_or(false);
            match (inside, start) {
                (true, None) => start = Some(at),
                (false, Some(from)) => {
                    ranges.push(from..at);
                    start = None;
                }
                _ => {}
            }
        }
        if let Some(from) = start {
            ranges.push(from..self.text.len());
        }
        for range in ranges {
            for run in bidi::visual_runs(self.text, range, self.base_rtl) {
                for glyph in self.run(run.range, run.rtl)? {
                    if glyph.glyph.0 != 0
                        && embedded_code(pdf, &shaper.data, glyph.glyph, &glyph.text).is_none()
                    {
                        return Ok(true);
                    }
                }
            }
        }
        Ok(false)
    }

    /// The block's font a key of the shapers draws for.
    fn base(&self, key: u64) -> u64 {
        self.shapers.get(&key).map_or(key, |shaper| shaper.base)
    }

    /// The block's font of the character at byte `at`.
    fn font_at(&self, at: usize) -> Option<u64> {
        let found = self.fonts.partition_point(|(start, _)| *start <= at);
        self.fonts.get(found.checked_sub(1)?).map(|(_, font)| *font)
    }

    /// The glyphs of the run `range`, in its direction, in visual order.
    fn run(&self, range: Range<usize>, rtl: bool) -> Result<Vec<ShapedGlyph>, Unsupported> {
        let piece = self.text.get(range.clone()).ok_or(Unsupported::Shaping)?;
        // The run's pieces of one font each, in logical order.
        let mut segments: Vec<(Range<usize>, u64)> = Vec::new();
        for (offset, c) in piece.char_indices() {
            let at = range.start.saturating_add(offset);
            let font = self.font_at(at).ok_or(Unsupported::Shaping)?;
            let end = at.saturating_add(c.len_utf8());
            match segments.last_mut() {
                Some((segment, last)) if *last == font => segment.end = end,
                _ => segments.push((at..end, font)),
            }
        }
        if rtl {
            segments.reverse();
        }
        let direction = if rtl {
            Direction::RightToLeft
        } else {
            Direction::LeftToRight
        };
        let mut glyphs = Vec::new();
        for (segment, font) in segments {
            let shaper = self.shapers.get(&font).ok_or(Unsupported::Shaping)?;
            let program = FontProgram::parse(&shaper.data).map_err(|_| Unsupported::Shaping)?;
            let piece = self.text.get(segment.clone()).ok_or(Unsupported::Shaping)?;
            let run = shaper
                .font
                .shape(&ShapeRequest::new(piece, direction))
                .map_err(|_| Unsupported::Shaping)?;
            let units = f32::from(run.units_per_em);
            for (glyph, text) in run.glyphs.iter().zip(texts(&run, piece, &program, rtl)) {
                // A zero width non-joiner only breaks a join: its glyph is not written.
                if bidi::is_hidden(&text) {
                    continue;
                }
                let text = match single(&text) {
                    Some(c)
                        if rtl
                            && mirror(c) != c
                            && program.glyph_for_char(mirror(c)) == Some(glyph.glyph) =>
                    {
                        mirror(c).to_string()
                    }
                    _ => text,
                };
                // shortcut: vertical mark offsets (`y_offset`) are not written; `Ts` per glyph
                // when a font's marks need them.
                #[allow(clippy::cast_precision_loss)]
                let (advance, offset) = (
                    glyph.x_advance as f32 / units,
                    glyph.x_offset as f32 / units,
                );
                glyphs.push(ShapedGlyph {
                    at: segment.start.saturating_add(glyph.cluster),
                    font,
                    glyph: glyph.glyph,
                    text,
                    advance,
                    offset,
                });
            }
        }
        Ok(glyphs)
    }

    /// The glyphs of the line `range` of the text, in visual order from the left.
    fn line(&self, range: Range<usize>) -> Result<Vec<ShapedGlyph>, Unsupported> {
        let mut glyphs = Vec::new();
        for run in bidi::visual_runs(self.text, range, self.base_rtl) {
            glyphs.extend(self.run(run.range, run.rtl)?);
        }
        Ok(glyphs)
    }

    /// The glyphs of every paragraph, unbroken: the advances the plan measures.
    fn measure(&self) -> Result<Vec<ShapedGlyph>, Unsupported> {
        let mut glyphs = Vec::new();
        let mut start = 0_usize;
        for paragraph in self.text.split('\n') {
            let end = start.saturating_add(paragraph.trim_end_matches('\r').len());
            glyphs.extend(self.line(start..end)?);
            start = start.saturating_add(paragraph.len()).saturating_add(1);
        }
        Ok(glyphs)
    }

    /// The lines' glyphs as codes of the block's fonts, or of new fonts of the same faces for
    /// the glyphs the subsets lack (step 2, said once); the characters no step draws when a
    /// glyph is `.notdef` or the face forbids embedding.
    fn pieces(
        &self,
        lines: &[Vec<ShapedGlyph>],
        encoder: &mut Encoder<'_>,
        copies: &mut Copies<'_>,
    ) -> Result<Result<ShapedLines, MissingGlyphs>, Unsupported> {
        let fonts = &self.recorder.collector.fonts;
        let mut found: HashMap<(u64, u32, String), Option<Code>> = HashMap::new();
        // A font per list; one glyph with two texts takes a list of its own for the second,
        // since ToUnicode is per code.
        let mut wanted: Vec<(u64, Vec<(GlyphId, String)>)> = Vec::new();
        let mut undrawn: Vec<(char, usize, u64)> = Vec::new();
        for glyph in lines.iter().flatten() {
            if glyph.glyph.0 == 0 {
                if let Some(c) = self
                    .text
                    .get(glyph.at..)
                    .and_then(|rest| rest.chars().next())
                {
                    undrawn.push((c, glyph.at, glyph.font));
                }
                continue;
            }
            let key = (glyph.font, glyph.glyph.0, glyph.text.clone());
            if found.contains_key(&key) {
                continue;
            }
            let shaper = self.shapers.get(&glyph.font).ok_or(Unsupported::Shaping)?;
            let code = if shaper.similar {
                None
            } else {
                let pdf = fonts.get(&glyph.font).ok_or(Unsupported::Operators)?;
                embedded_code(pdf, &shaper.data, glyph.glyph, &glyph.text)
            };
            if code.is_none() {
                let free = wanted.iter().position(|(font, list)| {
                    *font == glyph.font && list.iter().all(|(seen, _)| *seen != glyph.glyph)
                });
                match free.and_then(|at| wanted.get_mut(at)) {
                    Some((_, list)) => list.push((glyph.glyph, glyph.text.clone())),
                    None => wanted.push((glyph.font, vec![(glyph.glyph, glyph.text.clone())])),
                }
            }
            found.insert(key, code);
        }
        let missing = |chars: Vec<(char, usize)>, font: u64, reason| MissingGlyphs {
            chars,
            font: fallback::font_name(fonts.get(&self.base(font))),
            reason,
            bold: false,
            italic: false,
            candidates: Vec::new(),
        };
        if let Some(&(_, _, font)) = undrawn.first() {
            let chars = undrawn.iter().map(|&(c, at, _)| (c, at)).collect();
            return Ok(Err(missing(chars, font, MissingReason::NotInstalled)));
        }
        // Step 2: the glyphs the subsets lack, from the same faces, in new fonts.
        let mut created: HashMap<(u64, u32, String), (u64, Code)> = HashMap::new();
        let mut new_fonts = Vec::new();
        let mut substitutions = Vec::new();
        for (font, list) in &wanted {
            let shaper = self.shapers.get(font).ok_or(Unsupported::Shaping)?;
            if !shaper.embeddable {
                let chars = lines
                    .iter()
                    .flatten()
                    .filter(|glyph| glyph.font == *font)
                    .filter(|glyph| list.iter().any(|(wanted, _)| *wanted == glyph.glyph))
                    // Each character the glyph stands for, a ligature's too, at its place.
                    .flat_map(|glyph| {
                        self.text
                            .get(glyph.at..)
                            .unwrap_or_default()
                            .char_indices()
                            .take(glyph.text.chars().count())
                            .map(move |(i, c)| (c, glyph.at.saturating_add(i)))
                    })
                    .collect();
                let reason = MissingReason::NotEmbeddable {
                    font: shaper.face.postscript_name.clone(),
                    embedding: Embedding::of(&shaper.data, shaper.index),
                };
                return Ok(Err(missing(chars, *font, reason)));
            }
            // New fonts go into the page's resources, which a form's content cannot name.
            if matches!(encoder.source, SpanSource::Form { .. }) {
                return Err(Unsupported::CompositeFont);
            }
            let base = shaper.base;
            let resource = encoder.name(base).ok_or(Unsupported::Operators)?;
            let name = copies.fresh_name(&resource)?;
            copies.reserved.push(name.clone());
            let (embedded, codes) = fallback::embed(
                &shaper.data,
                shaper.index,
                shaper.face.instance.as_ref(),
                list,
                name.clone(),
            )
            .ok_or(Unsupported::Shaping)?;
            // Keys are hashes of font dictionaries; a new font's is derived from its base's.
            let key =
                font ^ 0x5B57_0F0C_0FFE_E100 ^ u64::try_from(new_fonts.len()).unwrap_or_default();
            let size = encoder.size(base).ok_or(Unsupported::Operators)?;
            encoder.fonts.push((key, name, size));
            let from = fallback::font_name(fonts.get(&base));
            let to = shaper.face.postscript_name.clone();
            // Said once for a font, however many it took.
            let at = substitutions
                .iter()
                .position(|seen: &Substitution| seen.from == from && seen.to == to)
                .unwrap_or_else(|| {
                    substitutions.push(Substitution {
                        kind: if shaper.similar {
                            SubstitutionKind::Similar
                        } else {
                            SubstitutionKind::SameFont
                        },
                        chars: String::new(),
                        from,
                        to,
                        origin: shaper.face.origin,
                    });
                    substitutions.len().saturating_sub(1)
                });
            if let Some(substitution) = substitutions.get_mut(at) {
                for (_, text) in list {
                    for c in text.chars().filter(|c| !c.is_whitespace()) {
                        if !substitution.chars.contains(c) {
                            substitution.chars.push(c);
                        }
                    }
                }
            }
            new_fonts.push(embedded);
            for ((glyph, text), (_, code, width)) in list.iter().zip(codes) {
                created.insert((*font, glyph.0, text.clone()), (key, (code, width)));
            }
        }
        let mut sets = Vec::with_capacity(lines.len());
        for line in lines {
            let mut pieces = Vec::with_capacity(line.len());
            for glyph in line {
                let size = encoder
                    .size(self.base(glyph.font))
                    .ok_or(Unsupported::Operators)?;
                let own = found
                    .get(&(glyph.font, glyph.glyph.0, glyph.text.clone()))
                    .cloned()
                    .flatten();
                let (font, (bytes, width)) = match own {
                    Some(code) => (glyph.font, code),
                    None => {
                        let (key, code) = created
                            .get(&(glyph.font, glyph.glyph.0, glyph.text.clone()))
                            .ok_or(Unsupported::Shaping)?;
                        (*key, code.clone())
                    }
                };
                pieces.push(Piece {
                    at: glyph.at,
                    font,
                    size,
                    bytes,
                    hex: true,
                    width,
                    blank: !glyph.text.is_empty() && glyph.text.chars().all(char::is_whitespace),
                    kern: glyph.advance - width,
                    offset: glyph.offset,
                });
            }
            sets.push(pieces);
        }
        Ok(Ok(ShapedLines {
            lines: sets,
            fonts: new_fonts,
            substitutions,
        }))
    }
}

/// Whether `c` joins the character before it in a cluster the shaper must draw: Latin, Greek and
/// Cyrillic combining marks, kana voicing and Hangul tone marks, conjoining jamo and variation
/// selectors. Indic and Southeast Asian marks are left to their codes, as a document's own are.
fn cluster_part(c: char) -> bool {
    matches!(c,
        '\u{0300}'..='\u{036F}'
        | '\u{1AB0}'..='\u{1AFF}'
        | '\u{1DC0}'..='\u{1DFF}'
        | '\u{20D0}'..='\u{20FF}'
        | '\u{FE20}'..='\u{FE2F}'
        | '\u{302A}'..='\u{302F}'
        | '\u{3099}'..='\u{309A}'
        | '\u{1100}'..='\u{11FF}'
        | '\u{A960}'..='\u{A97F}'
        | '\u{D7B0}'..='\u{D7FF}'
        | '\u{FE00}'..='\u{FE0F}'
        | '\u{E0100}'..='\u{E01EF}')
}

/// `text` with each combining mark or conjoining jamo composed into the character before it where
/// Unicode composes them; compatibility ideographs and other characters stay as they are, which
/// whole-text NFC would change.
fn composed(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        let both = (is_combining_mark(c) || cluster_part(c))
            .then(|| out.chars().next_back().and_then(|last| compose(last, c)))
            .flatten();
        if let Some(both) = both {
            out.pop();
            out.push(both);
        } else {
            out.push(c);
        }
    }
    out
}

/// `text` with only what differs from `old` [`composed`]: a document's stored decomposed text the
/// person did not touch stays as it is, so it is neither rewritten nor looked up as a new letter.
fn composed_changes(old: &str, text: &str) -> String {
    let old: Vec<char> = old.chars().collect();
    let fresh: Vec<char> = text.chars().collect();
    let (mut prefix, mut suffix) = common_ends(&old, &fresh);
    let joins = |c: Option<&char>| c.is_some_and(|&c| is_combining_mark(c) || cluster_part(c));
    // A mark at either end of the change composes with what stands before it.
    while prefix > 0 && joins(fresh.get(prefix)) {
        prefix = prefix.saturating_sub(1);
    }
    while suffix > 0 && joins(fresh.get(fresh.len().saturating_sub(suffix))) {
        suffix = suffix.saturating_sub(1);
    }
    let end = fresh.len().saturating_sub(suffix);
    let middle: String = fresh.get(prefix..end).unwrap_or_default().iter().collect();
    let mut out: String = fresh.get(..prefix).unwrap_or_default().iter().collect();
    out.push_str(&composed(&middle));
    out.extend(fresh.get(end..).unwrap_or_default());
    out
}

/// The clusters of `fresh` a change falls in, as index ranges: a base with the parts after it,
/// any part of which lies in `changed`.
fn new_clusters(fresh: &[(usize, char)], changed: Range<usize>) -> Vec<Range<usize>> {
    let part = |i: usize| fresh.get(i).is_some_and(|&(_, c)| cluster_part(c));
    // A leading jamo starts a syllable of its own.
    let leading = |c: char| matches!(c, '\u{1100}'..='\u{115F}' | '\u{A960}'..='\u{A97F}');
    let joins = |i: usize| part(i) && !fresh.get(i).is_some_and(|&(_, c)| leading(c));
    let mut clusters = Vec::new();
    let mut start = 0_usize;
    while start < fresh.len() {
        let mut end = start.saturating_add(1);
        while joins(end) {
            end = end.saturating_add(1);
        }
        let parts = end.saturating_sub(start) > 1 || part(start);
        if parts && (start..end).any(|i| changed.contains(&i)) {
            clusters.push(start..end);
        }
        start = end;
    }
    clusters
}

/// The text each glyph of `run` (shaped from `text` in `program`) stands for, for ToUnicode:
/// a cluster of one glyph per character gives each its character in logical order; in another
/// cluster of several glyphs, a mark whose nominal glyph it is gets its own character (placed back
/// on its letter by its position when the text is read) and the cluster's first glyph in logical
/// order the rest (a lam-yeh ligature "لي" with its kasra drawn apart).
fn texts(run: &ShapedRun, text: &str, program: &FontProgram<'_>, rtl: bool) -> Vec<String> {
    let mut starts: Vec<usize> = run.glyphs.iter().map(|glyph| glyph.cluster).collect();
    starts.push(text.len());
    starts.sort_unstable();
    starts.dedup();
    let mut texts = vec![String::new(); run.glyphs.len()];
    let mut clusters: Vec<(usize, Vec<usize>)> = Vec::new();
    for (at, glyph) in run.glyphs.iter().enumerate() {
        // Clusters are monotone (`ClusterLevel::MonotoneCharacters`), so a cluster's glyphs
        // are adjacent.
        match clusters
            .last_mut()
            .filter(|(start, _)| *start == glyph.cluster)
        {
            Some((_, members)) => members.push(at),
            None => clusters.push((glyph.cluster, vec![at])),
        }
    }
    for (start, mut members) in clusters {
        if rtl {
            members.reverse();
        }
        let end = starts
            .get(starts.partition_point(|&next| next <= start))
            .copied()
            .unwrap_or(text.len());
        let cluster = text.get(start..end).unwrap_or_default();
        if members.len() > 1 && members.len() == cluster.chars().count() {
            for (&member, c) in members.iter().zip(cluster.chars()) {
                if let Some(slot) = texts.get_mut(member) {
                    *slot = c.to_string();
                }
            }
            continue;
        }
        let mut rest = cluster.to_owned();
        let Some((&first, others)) = members.split_first() else {
            continue;
        };
        for &member in others {
            let Some(glyph) = run.glyphs.get(member) else {
                continue;
            };
            let own = rest
                .char_indices()
                .find(|&(_, c)| program.glyph_for_char(c) == Some(glyph.glyph));
            if let (Some((at, c)), Some(slot)) = (own, texts.get_mut(member)) {
                *slot = c.to_string();
                rest.remove(at);
            }
        }
        if let Some(slot) = texts.get_mut(first) {
            *slot = rest;
        }
    }
    texts
}

/// The same font as `key`'s among `library`'s, ready to shape, with whether it may be embedded.
fn shaper(library: &FontLibrary, recorder: &Recorder, key: u64) -> Option<Shaper> {
    let pdf = recorder.collector.fonts.get(&key)?;
    let (face, embeddable) =
        match fallback::same_font(library, pdf, key, &recorder.collector.glyphs, true) {
            SameFont::Found { face, .. } => (face, true),
            SameFont::NotEmbeddable { face, .. } => (face, false),
            SameFont::NotFound => return None,
        };
    library
        .with_data(face.id, |data, index| {
            Some(Shaper {
                font: ShapingFont::new_at(data.to_vec(), index, face.instance.as_ref()).ok()?,
                data: data.to_vec(),
                index,
                face,
                embeddable,
                base: key,
                similar: false,
            })
        })
        .flatten()
}

/// The code of `pdf` that draws the glyph `glyph` of the shaping font `data` and reads back as
/// `text`, with its width per unit of font size: the subset's glyph of the same name.
fn embedded_code(pdf: &PdfFont, data: &[u8], glyph: GlyphId, text: &str) -> Option<Code> {
    if fallback::restriction(pdf).is_some() {
        return None;
    }
    let name = FontProgram::parse(data).ok()?.glyph_name(glyph)?;
    let program = pdf.program()?;
    let own = program.glyph_for_name(&name).filter(|glyph| glyph.0 != 0)?;
    // A glyph that stands for nothing must read as nothing, not as U+FFFD.
    let reads = |found: Option<String>| found.as_deref() == Some(text);
    let Some(cmap) = &pdf.cmap else {
        // A simple font: a code its encoding gives the glyph, with the same text.
        if text.is_empty() {
            return None;
        }
        let code = (0..=u8::MAX).find(|&code| {
            pdf.glyph(&program, code) == Some(own) && pdf.text(u32::from(code)) == text
        })?;
        return Some((vec![code], pdf.width(u32::from(code), 1)));
    };
    if !pdf.cmap_known || pdf.vertical() {
        return None;
    }
    let cid = pdf.glyph_cid(&program, own)?;
    if pdf.cid_glyph(&program, cid) != Some(own) {
        return None;
    }
    let (code, length) = cmap.code_for_cid(cid)?;
    let bytes = code
        .to_be_bytes()
        .get(4_usize.checked_sub(length)?..)?
        .to_vec();
    if cmap.codes(&bytes).collect::<Vec<_>>() != [(code, length)] {
        return None;
    }
    let found = pdf.to_unicode.as_ref().and_then(|cmap| cmap.text(code));
    reads(found).then(|| (bytes, pdf.width(code, length)))
}

/// The fonts page `index` of `document` draws text with, by `/BaseFont` as written, each with the
/// characters of `letters` an edit could not draw in it, even through a copy of the font (step 1),
/// so typing them needs step 2 or 3 (a2-7). Sorted by name. A Type3 font, which has no characters
/// to type with, is left out.
///
/// # Errors
///
/// [`TextError::Core`] when a limit stops the interpreter.
pub fn missing_letters(
    document: &Document,
    index: usize,
    letters: &str,
) -> Result<Vec<(String, String)>, TextError> {
    let mut collector = crate::extract::Collector::default();
    document.page_text(index, &mut collector)?;
    let mut fonts: Vec<(String, String)> = collector
        .fonts
        .values()
        .filter(|font| font.resource.kind != FontKind::Type3)
        .filter_map(|font| {
            let name = font.resource.base_font.clone()?;
            let restricted = fallback::restriction(font).is_some();
            let program = font.program();
            let draws = |c: char| {
                if restricted {
                    return false;
                }
                if font.cmap.is_some() {
                    return font.cmap_known
                        && encode_composite(font, program.as_ref(), c).is_some();
                }
                encode(font, program.as_ref(), c).is_some()
                    || program
                        .as_ref()
                        .is_some_and(|program| differences_glyph(font, program, c).is_some())
            };
            Some((name, letters.chars().filter(|&c| !draws(c)).collect()))
        })
        .collect();
    fonts.sort();
    Ok(fonts)
}

/// The glyph name a copy of simple `font` gives a new code so that `program` draws `c` with it
/// (step 1), and its width in thousandths of an em: a TrueType font that is not symbolic, by the
/// name `post` gives the glyph `c` maps to (else its standard name, which readers map through
/// the Unicode cmap), a Type1 program by a name of `c` it has.
fn differences_glyph(font: &PdfFont, program: &FontProgram<'_>, c: char) -> Option<(String, f32)> {
    let resource = &font.resource;
    if c == char::REPLACEMENT_CHARACTER
        || c.is_whitespace()
        || (resource.symbolic && resource.kind == FontKind::TrueType)
    {
        return None;
    }
    let names = glyph_names(c);
    let found = |glyph: Option<ferman_fonts::GlyphId>| glyph.filter(|glyph| glyph.0 != 0);
    let (name, glyph) = match resource.kind {
        FontKind::TrueType => {
            let glyph = found(program.glyph_for_char(c))?;
            let name = names
                .iter()
                .find(|name| program.glyph_for_name(name) == Some(glyph))
                .or_else(|| names.first())?;
            (name.clone(), glyph)
        }
        FontKind::Type1 | FontKind::MultipleMaster => names
            .iter()
            .find_map(|name| Some((name.clone(), found(program.glyph_for_name(name))?)))?,
        _ => return None,
    };
    let units = f32::from(program.units_per_em());
    if units <= 0.0 {
        return None;
    }
    let width = (program.advance_width(glyph)? * 1000.0 / units).round();
    width.is_finite().then_some((name, width))
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
    if c == char::REPLACEMENT_CHARACTER || !font.cmap_known {
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
    // The program's cmap gives the horizontal form; in vertical text only an ideograph, which
    // has no vertical form, is drawn by it. Others need the `vert` substitution the subset lacks.
    if font.vertical() && !ideograph(c) {
        return None;
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

/// Whether `c` is a CJK unified or compatibility ideograph.
fn ideograph(c: char) -> bool {
    matches!(
        c,
        '\u{3400}'..='\u{4DBF}'
            | '\u{4E00}'..='\u{9FFF}'
            | '\u{F900}'..='\u{FAFF}'
            | '\u{20000}'..='\u{323AF}'
    )
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

/// Writes `placed` as shows from where the text matrix is, each glyph at its `x` along the
/// writing direction through `TJ` numbers (thousandths of the font size times `scaling`, the
/// `Tz` of horizontal text and 1 in vertical text), its fonts set with `name_of`'s names; then,
/// with `end`, the number that takes the matrix there. Returns how far the shows advance.
fn write_placed(
    out: &mut Vec<u8>,
    sim: &mut Sim,
    placed: &[Placed],
    tj: bool,
    scaling: f32,
    end: Option<f32>,
    name_of: &dyn Fn(u64) -> Option<Vec<u8>>,
) -> Result<f32, Unsupported> {
    let mut natural = 0.0_f32;
    let mut items: Vec<Item> = Vec::new();
    let mut hex = false;
    let number_to = |items: &mut Vec<Item>, natural: &mut f32, to: f32, size: f32| {
        let unit = size * scaling / 1000.0;
        let d = to - *natural;
        if d.abs() > 1e-4 && unit != 0.0 {
            let n = ((-d / unit) * 1000.0).round() / 1000.0;
            if n != 0.0 {
                items.push(Item::Number(n));
                *natural -= n * unit;
            }
        }
    };
    for glyph in placed {
        if sim.font != Some(glyph.font) || sim.size != glyph.size || glyph.hex != hex {
            flush(out, &mut items, tj, hex)?;
            hex = glyph.hex;
        }
        if sim.font != Some(glyph.font) || sim.size != glyph.size {
            let name = name_of(glyph.font).ok_or(Unsupported::Operators)?;
            set_font(out, &name, glyph.size)?;
            sim.font = Some(glyph.font);
            sim.size = glyph.size;
        }
        number_to(&mut items, &mut natural, glyph.x, glyph.size);
        match items.last_mut() {
            Some(Item::Text(bytes)) => bytes.extend_from_slice(&glyph.bytes),
            _ => items.push(Item::Text(glyph.bytes.clone())),
        }
        natural += glyph.step;
    }
    if let Some(end) = end {
        number_to(&mut items, &mut natural, end, sim.size);
    }
    flush(out, &mut items, tj, hex)?;
    Ok(natural)
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

/// Sets the fill colour to `numbers` in `colour_space`: the device spaces' own operators, or the
/// space by name, as `cs` and `scn` do.
fn set_colour(out: &mut Vec<u8>, colour_space: &[u8], numbers: &[f32]) -> Result<(), Unsupported> {
    let operator: &[u8] = match colour_space {
        b"DeviceGray" => b"g",
        b"DeviceRGB" => b"rg",
        b"DeviceCMYK" => b"k",
        name => {
            space(out);
            out.push(b'/');
            for &byte in name {
                if byte.is_ascii_graphic() && !b"()<>[]{}/%#".contains(&byte) {
                    out.push(byte);
                } else {
                    out.extend_from_slice(format!("#{byte:02X}").as_bytes());
                }
            }
            out.extend_from_slice(b" cs");
            // `cs` alone already set the space's initial colour.
            if numbers.is_empty() {
                return Ok(());
            }
            b"scn"
        }
    };
    for &value in numbers {
        space(out);
        number(out, value)?;
    }
    space(out);
    out.extend_from_slice(operator);
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
    fn a_ligature_with_a_mark_apart_gives_the_mark_its_own_text() {
        let data = std::fs::read(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../app/assets/fonts/ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf"
        ))
        .unwrap();
        let font = ShapingFont::new(data.clone(), 0).unwrap();
        let program = FontProgram::parse(&data).unwrap();
        // Plex Sans Arabic draws "لِي" as the lam-yeh ligature with the kasra apart; "بَ" as
        // two clusters, the beh and the fatha.
        for (text, expected) in [("لِي", vec!["\u{650}", "لي"]), ("بَ", vec!["\u{64e}", "ب"])]
        {
            let run = font
                .shape(&ShapeRequest::new(text, Direction::RightToLeft))
                .unwrap();
            assert_eq!(texts(&run, text, &program, true), expected, "{text}");
        }
        // Left to right, one glyph per character keeps each its own.
        let run = font
            .shape(&ShapeRequest::new("IBAN", Direction::LeftToRight))
            .unwrap();
        assert_eq!(texts(&run, "IBAN", &program, false), ["I", "B", "A", "N"]);
    }

    #[test]
    fn marks_compose_and_only_the_changed_clusters_are_shaped() {
        assert_eq!(composed("e\u{301}"), "\u{E9}");
        assert_eq!(composed("か\u{3099}"), "が");
        assert_eq!(composed("\u{1112}\u{1161}\u{11AB}"), "한");
        // Old Hangul, a variation sequence and a compatibility ideograph stay.
        assert_eq!(composed("\u{1112}\u{119E}"), "\u{1112}\u{119E}");
        assert_eq!(composed("葛\u{E0100}"), "葛\u{E0100}");
        assert_eq!(composed("\u{F900}"), "\u{F900}");
        // Only the change composes.
        assert_eq!(composed_changes("e\u{301}", "e\u{301}"), "e\u{301}");
        assert_eq!(
            composed_changes("e\u{301}\nb", "e\u{301}\nc"),
            "e\u{301}\nc"
        );
        assert_eq!(
            composed_changes("e\u{301}x", "e\u{301}xa\u{301}"),
            "e\u{301}x\u{E1}"
        );
        assert_eq!(composed_changes("e", "e\u{301}"), "\u{E9}");
        assert_eq!(composed_changes("a\u{301}", "e\u{301}"), "\u{E9}");
        let fresh: Vec<(usize, char)> = "ax\u{302}b\u{1112}\u{119E}".char_indices().collect();
        assert_eq!(new_clusters(&fresh, 0..fresh.len()), [1..3, 4..6]);
        assert_eq!(new_clusters(&fresh, 4..5), vec![4..6]);
        assert!(new_clusters(&fresh, 3..4).is_empty());
    }

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
