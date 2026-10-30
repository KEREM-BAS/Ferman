//! A page's text in reading order (docs/ARCHITECTURE.md §6.2 to §6.4, §6.10 and §6.11): fonts
//! from their resources, glyphs placed by the interpreter, lines by baseline, right-to-left lines
//! in logical order, and vertical text in columns.
//!
//! Lines follow the content order, which is the reading order of the documents Ferman makes and of
//! most others; columns and blocks are M3's (`layout`). A word break goes where a space glyph is,
//! or where the gap to the next glyph passes a fifth of the font size. A right-to-left line is
//! stored in visual order, so it is read back with the bidi algorithm (UAX #9): each glyph keeps
//! its own text (a lam-alef ligature stays "لا"), and brackets at right-to-left levels are mirrored.
// Positions and widths come from files (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::HashMap;

use ferman_core::Document;
use ferman_core::interpret::{FontResource, Matrix, ShowItem, TextShow, TextSink};
use ferman_core::structure::FontKind;
use ferman_fonts::{BaseEncoding, CMap, SimpleEncoding};
use unicode_bidi::{BidiClass, BidiInfo, Level, bidi_class};

use crate::TextError;

/// The gap, as a share of the font size, from which two glyphs are two words.
const WORD_GAP: f32 = 0.2;

/// A box `[left, top, right, bottom]`.
pub type CharBox = [f32; 4];

/// A page's text with the box of every character in displayed points: from the page's top-left
/// corner as it shows after its crop box and `/Rotate`, y down, as the canvas lays pages out. A
/// space or line break no glyph drew has no box.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct PageText {
    /// Lines separated by `\n`, words by spaces.
    pub text: String,
    /// One per character of `text`.
    pub boxes: Vec<Option<CharBox>>,
}

/// The text of page `index`: lines separated by `\n`, words by spaces.
///
/// # Errors
///
/// [`TextError::Core`] when a limit stops the interpreter.
pub fn page_text(document: &Document, index: usize) -> Result<String, TextError> {
    Ok(page_layout(document, index)?.text)
}

/// The text of page `index` with its characters' boxes.
///
/// # Errors
///
/// [`TextError::Core`] when a limit stops the interpreter.
pub fn page_layout(document: &Document, index: usize) -> Result<PageText, TextError> {
    let mut collector = Collector::default();
    document.page_text(index, &mut collector)?;
    let page = document.structure().pages.get(index);
    let mut out = PageText::default();
    for (n, line) in lines(&collector.glyphs).into_iter().enumerate() {
        if n > 0 {
            out.text.push('\n');
            out.boxes.push(None);
        }
        for (c, found) in line {
            out.text.push(c);
            out.boxes.push(found.map(|[left, bottom, right, top]| {
                let Some(page) = page else {
                    return [left, top, right, bottom];
                };
                let corners = [
                    page.display_point(left, bottom),
                    page.display_point(right, top),
                ];
                let xs = corners.map(|(x, _)| x);
                let ys = corners.map(|(_, y)| y);
                [
                    xs[0].min(xs[1]),
                    ys[0].min(ys[1]),
                    xs[0].max(xs[1]),
                    ys[0].max(ys[1]),
                ]
            }));
        }
    }
    Ok(out)
}

/// A line's characters with the boxes of their glyphs in page space, `[left, bottom, right,
/// top]`.
type Line = Vec<(char, Option<CharBox>)>;

/// A font, ready to split strings into codes and give their widths and text.
struct PdfFont {
    /// A composite font's CMap; a simple font's codes are single bytes.
    cmap: Option<CMap>,
    encoding: SimpleEncoding,
    to_unicode: Option<CMap>,
    resource: FontResource,
}

impl PdfFont {
    fn new(resource: &FontResource) -> Self {
        let cmap = (resource.kind == FontKind::Type0).then(|| {
            match (&resource.cmap, resource.cmap_name.as_deref()) {
                (Some(bytes), _) => CMap::parse(bytes),
                (None, Some(b"Identity-V")) => CMap::identity(true),
                // shortcut: other predefined CMaps read as Identity-H; bundle Adobe's CMaps
                // (BSD-3-Clause) when a document needs them.
                _ => CMap::identity(false),
            }
        });
        let base = resource
            .base_encoding
            .as_deref()
            .and_then(BaseEncoding::from_name)
            .or((!resource.symbolic).then_some(BaseEncoding::Standard));
        let differences = resource
            .differences
            .iter()
            .map(|(code, name)| (*code, name.as_str()));
        Self {
            cmap,
            encoding: SimpleEncoding::new(base, differences),
            to_unicode: resource.to_unicode.as_deref().map(CMap::parse),
            resource: resource.clone(),
        }
    }

    fn vertical(&self) -> bool {
        self.cmap.as_ref().is_some_and(CMap::is_vertical)
    }

    fn codes(&self, bytes: &[u8]) -> Vec<(u32, usize)> {
        match &self.cmap {
            Some(cmap) => cmap.codes(bytes).collect(),
            None => bytes.iter().map(|&byte| (u32::from(byte), 1)).collect(),
        }
    }

    /// The horizontal advance of `code`, per unit of font size.
    fn width(&self, code: u32, length: usize) -> f32 {
        let font = &self.resource;
        if let Some(cmap) = &self.cmap {
            let cid = cmap.cid(code, length).unwrap_or(0);
            let width = font
                .cid_widths
                .iter()
                .find(|(first, last, _)| (first..=last).contains(&&cid))
                .map_or(font.default_width, |&(_, _, width)| width);
            return width / 1000.0;
        }
        let width = code
            .checked_sub(font.first_char)
            .and_then(|at| usize::try_from(at).ok())
            .and_then(|at| font.widths.get(at))
            .copied()
            .unwrap_or(font.missing_width);
        if font.kind == FontKind::Type3 {
            let [a, ..] = font.font_matrix;
            return width * a;
        }
        // shortcut: a standard font without /Widths gets half an em; bundle the standard 14's
        // metrics when their licence is checked (docs/ARCHITECTURE.md §6.2).
        if width == 0.0 && font.widths.is_empty() {
            return 0.5;
        }
        width / 1000.0
    }

    /// The vertical advance of `code`, per unit of font size (negative: down the column).
    fn vertical_advance(&self, code: u32, length: usize) -> f32 {
        let font = &self.resource;
        let cid = self
            .cmap
            .as_ref()
            .and_then(|cmap| cmap.cid(code, length))
            .unwrap_or(0);
        let w1y = font
            .vertical_metrics
            .iter()
            .find(|(first, last, _)| (first..=last).contains(&&cid))
            .map_or(font.default_vertical[1], |&(_, _, [w1y, _, _])| w1y);
        w1y / 1000.0
    }

    /// The text of `code`: its ToUnicode entry, the encoding's glyph name, or U+FFFD.
    fn text(&self, code: u32) -> String {
        if let Some(text) = self.to_unicode.as_ref().and_then(|cmap| cmap.text(code)) {
            return text;
        }
        if self.cmap.is_none()
            && let Some(text) = u8::try_from(code)
                .ok()
                .and_then(|code| self.encoding.text(code))
        {
            return text.to_owned();
        }
        char::REPLACEMENT_CHARACTER.to_string()
    }
}

/// One glyph on the page.
#[derive(Debug, Clone, PartialEq)]
struct Glyph {
    text: String,
    /// Its origin and the point its advance reaches, in page space.
    start: [f32; 2],
    end: [f32; 2],
    /// Its font size in page space.
    size: f32,
    vertical: bool,
}

/// The sink that places glyphs.
#[derive(Default)]
struct Collector {
    fonts: HashMap<u64, PdfFont>,
    glyphs: Vec<Glyph>,
}

impl TextSink for Collector {
    fn font(&mut self, font: &FontResource) {
        self.fonts.insert(font.key, PdfFont::new(font));
    }

    fn show(&mut self, show: &TextShow<'_>) -> (f32, f32) {
        let Some(font) = self.fonts.get(&show.font) else {
            return (0.0, 0.0);
        };
        let vertical = font.vertical();
        let scale = if vertical {
            1.0
        } else {
            show.horizontal_scaling
        };
        let [_, _, c, d, _, _] = show.matrix;
        let size = show.size * d.hypot(c);
        let mut advance = 0.0_f32;
        for item in show.items {
            let bytes = match item {
                ShowItem::Adjust(n) => {
                    advance -= n / 1000.0 * show.size * scale;
                    continue;
                }
                ShowItem::Text(bytes) => bytes,
            };
            for (code, length) in font.codes(bytes) {
                let spacing = show.char_spacing
                    + if length == 1 && code == 32 {
                        show.word_spacing
                    } else {
                        0.0
                    };
                let (origin, step) = if vertical {
                    (
                        [0.0, advance],
                        font.vertical_advance(code, length) * show.size + spacing,
                    )
                } else {
                    (
                        [advance, show.rise],
                        (font.width(code, length) * show.size + spacing) * scale,
                    )
                };
                let reach = if vertical {
                    [0.0, advance + step]
                } else {
                    [advance + step, show.rise]
                };
                self.glyphs.push(Glyph {
                    text: font.text(code),
                    start: apply(show.matrix, origin),
                    end: apply(show.matrix, reach),
                    size,
                    vertical,
                });
                advance += step;
            }
        }
        if vertical {
            (0.0, advance)
        } else {
            (advance, 0.0)
        }
    }
}

/// A point of text space in page space.
fn apply(m: Matrix, [x, y]: [f32; 2]) -> [f32; 2] {
    let [a, b, c, d, e, f] = m;
    [x * a + y * c + e, x * b + y * d + f]
}

/// The glyphs as lines in content order.
fn lines(glyphs: &[Glyph]) -> Vec<Line> {
    let mut out: Vec<Vec<&Glyph>> = Vec::new();
    for glyph in glyphs {
        let joins = out.last().and_then(|line| line.last()).is_some_and(|last| {
            let size = last.size.max(glyph.size);
            if last.vertical {
                (glyph.start[0] - last.start[0]).abs() < size * 0.6
                    && glyph.start[1] < last.start[1] + size
            } else {
                (glyph.start[1] - last.start[1]).abs() < size * 0.5
                    && glyph.start[0] > last.start[0] - size
            }
        });
        match out.last_mut() {
            Some(line) if joins => line.push(glyph),
            _ => out.push(vec![glyph]),
        }
    }
    out.iter().map(|line| words(line)).collect()
}

/// One line's characters, with spaces at word gaps, in logical order.
fn words(line: &[&Glyph]) -> Line {
    let rtl = line
        .iter()
        .any(|glyph| glyph.text.chars().any(right_to_left));
    // A combining mark comes before its base in a right-to-left line's visual order; it stays
    // with that base. Such a line is read left to right, as it shows, whatever order drew it.
    let mut units: Vec<(Vec<&Glyph>, &Glyph)> = Vec::new();
    let mut marks = Vec::new();
    for &glyph in line {
        if rtl && !glyph.text.is_empty() && glyph.text.chars().all(is_mark) {
            marks.push(glyph);
        } else {
            units.push((std::mem::take(&mut marks), glyph));
        }
    }
    if rtl && !line.iter().any(|glyph| glyph.vertical) {
        units.sort_by(|(_, a), (_, b)| a.start[0].total_cmp(&b.start[0]));
    }
    let mut visual: Line = Vec::new();
    let mut previous: Option<&Glyph> = None;
    for (marks, glyph) in &units {
        if let Some(last) = previous {
            let gap = if last.vertical {
                last.end[1] - glyph.start[1]
            } else {
                glyph.start[0] - last.end[0]
            };
            let spaced = visual.last().is_some_and(|(c, _)| c.is_whitespace())
                || glyph.text.starts_with(char::is_whitespace);
            if !spaced && gap > glyph.size.max(last.size) * WORD_GAP {
                visual.push((' ', None));
            }
        }
        let logical = with_marks(glyph, marks);
        let area = Some(glyph_box(glyph));
        // A right-to-left unit is reversed here, so reading the line back restores it.
        if logical.chars().any(right_to_left) {
            visual.extend(logical.chars().rev().map(|c| (c, area)));
        } else {
            visual.extend(logical.chars().map(|c| (c, area)));
        }
        previous = Some(glyph);
    }
    for mark in marks {
        let area = Some(glyph_box(mark));
        visual.extend(mark.text.chars().map(|c| (c, area)));
    }
    if rtl { logical(&visual) } else { visual }
}

/// The box a glyph covers in page space, `[left, bottom, right, top]`: its advance across, and
/// from a fifth of its size below the baseline to four fifths above.
fn glyph_box(glyph: &Glyph) -> CharBox {
    let [x0, y0] = glyph.start;
    let [x1, y1] = glyph.end;
    let size = glyph.size;
    if glyph.vertical {
        [x0 - size / 2.0, y0.min(y1), x0 + size / 2.0, y0.max(y1)]
    } else {
        [x0.min(x1), y0 - size * 0.2, x0.max(x1), y0 + size * 0.8]
    }
}

/// A right-to-left glyph's text in logical order with the marks drawn on it. On a ligature
/// (lam-alef, ta-ra) a mark goes after the letter it sits over, whose share of the width holds it
/// (the first letter is on the right), or before an alef.
fn with_marks(glyph: &Glyph, marks: &[&Glyph]) -> String {
    let letters: Vec<char> = glyph.text.chars().collect();
    let last = letters.len().saturating_sub(1);
    let width = glyph.end[0] - glyph.start[0];
    let mut after: Vec<Vec<char>> = vec![Vec::new(); letters.len().max(1)];
    for mark in marks {
        let from_left = if width > 0.0 {
            ((mark.start[0] - glyph.start[0]) / width).clamp(0.0, 1.0)
        } else {
            0.0
        };
        // Truncation picks the letter whose share of the width holds the mark.
        #[allow(
            clippy::cast_possible_truncation,
            clippy::cast_sign_loss,
            clippy::cast_precision_loss
        )]
        let mut letter = (((1.0 - from_left) * letters.len() as f32) as usize).min(last);
        // Tanween on an alef is typed before it (ISO 8859-6 practice, "ًا").
        if letter > 0 && letters.get(letter) == Some(&'ا') {
            letter = letter.saturating_sub(1);
        }
        if let Some(slot) = after.get_mut(letter) {
            slot.extend(mark.text.chars());
        }
    }
    letters
        .iter()
        .zip(after)
        .flat_map(|(&letter, marks)| std::iter::once(letter).chain(marks))
        .collect()
}

/// Whether `c` is a combining mark (bidi class NSM).
fn is_mark(c: char) -> bool {
    bidi_class(c) == BidiClass::NSM
}

/// Whether `c` is a strong right-to-left character.
fn right_to_left(c: char) -> bool {
    matches!(bidi_class(c), BidiClass::R | BidiClass::AL)
}

/// A right-to-left line in visual order, read back into logical order with each character's box,
/// its brackets mirrored at right-to-left levels.
fn logical(visual: &[(char, Option<CharBox>)]) -> Line {
    let text: String = visual.iter().map(|(c, _)| c).collect();
    let info = BidiInfo::new(&text, Some(Level::rtl()));
    let Some(paragraph) = info.paragraphs.first() else {
        return visual.to_vec();
    };
    // Levels per byte, then one per character, with the line rules (L1) applied.
    let levels = info.reordered_levels_per_char(paragraph, paragraph.range.clone());
    let chars: Vec<(char, Option<CharBox>)> = visual
        .iter()
        .zip(&levels)
        .map(|(&(c, area), level)| (if level.is_rtl() { mirror(c) } else { c }, area))
        .collect();
    BidiInfo::reorder_visual(&levels)
        .into_iter()
        .filter_map(|at| chars.get(at).copied())
        .collect()
}

/// The bracket that mirrors `c`, or `c`.
fn mirror(c: char) -> char {
    match c {
        '(' => ')',
        ')' => '(',
        '[' => ']',
        ']' => '[',
        '{' => '}',
        '}' => '{',
        '<' => '>',
        '>' => '<',
        '«' => '»',
        '»' => '«',
        other => other,
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    fn glyph(text: &str, x: f32, y: f32) -> Glyph {
        Glyph {
            text: text.to_owned(),
            start: [x, y],
            end: [x + 5.0, y],
            size: 10.0,
            vertical: false,
        }
    }

    fn text(lines: Vec<Line>) -> Vec<String> {
        lines
            .into_iter()
            .map(|line| line.into_iter().map(|(c, _)| c).collect())
            .collect()
    }

    #[test]
    fn glyphs_become_words_and_lines() {
        let glyphs = [
            glyph("K", 0.0, 700.0),
            glyph("i", 5.0, 700.0),
            glyph("r", 30.0, 700.0),
            glyph("a", 0.0, 680.0),
        ];
        assert_eq!(text(lines(&glyphs)), ["Ki r", "a"]);
    }

    #[test]
    fn a_right_to_left_line_reads_in_logical_order() {
        // "عام 2025 (جديد)" drawn in visual order, the ligature "لا" as one glyph.
        let visual = [
            "(", "د", "ي", "د", "ج", ")", " ", "2", "0", "2", "5", " ", "م", "ا", "ع",
        ];
        let glyphs: Vec<Glyph> = (0_u8..)
            .zip(visual)
            .map(|(i, text)| glyph(text, f32::from(i) * 5.0, 0.0))
            .collect();
        assert_eq!(text(lines(&glyphs)), ["عام 2025 (جديد)"]);
        let ligature = [glyph("لا", 0.0, 0.0), glyph("ب", 5.0, 0.0)];
        assert_eq!(text(lines(&ligature)), ["بلا"]);
    }

    #[test]
    fn vertical_glyphs_make_columns() {
        let column = |x: f32, y: f32, text: &str| Glyph {
            text: text.to_owned(),
            start: [x, y],
            end: [x, y - 10.0],
            size: 10.0,
            vertical: true,
        };
        let glyphs = [
            column(100.0, 700.0, "拝"),
            column(100.0, 690.0, "啓"),
            column(80.0, 700.0, "秋"),
        ];
        assert_eq!(text(lines(&glyphs)), ["拝啓", "秋"]);
    }
}
