//! Hit testing, caret stops and selection inside a block (docs/ARCHITECTURE.md §3.5 and §6.12).
//!
//! A caret index counts characters of [`TextBlock::text`], the lines joined by line feeds; a stop
//! sits at every grapheme cluster boundary of a line, so the caret never splits a letter from its
//! marks. Positions run along each line's baseline in page space, so turned pages and vertical
//! columns work alike. In right-to-left text a character's leading edge is its right one: the
//! levels come from the bidi algorithm (UAX #9) with the line's direction as the paragraph's.
//! A ligature's glyph is shared out evenly among its characters.

use std::ops::Range;

use unicode_bidi::{BidiInfo, Level};
use unicode_normalization::char::is_combining_mark;

use crate::extract::CharBox;
use crate::layout::{Line, TextBlock, TextDirection};

/// A place the caret can stop.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CaretStop {
    /// Its caret index in the block's text.
    pub index: usize,
    /// The line it is on.
    pub line: usize,
    /// Where it is on the line's baseline, in page space.
    pub point: [f32; 2],
}

/// Whether the caret may stop before `chars[at]`: a grapheme cluster boundary (UAX #29's rules
/// for marks, joiners, variation selectors and CR LF).
// shortcut: no Hangul jamo, emoji modifier or regional indicator rules; take unicode-segmentation
// when a document needs them.
fn boundary(chars: &[char], at: usize) -> bool {
    let (Some(&before), Some(&after)) =
        (at.checked_sub(1).and_then(|b| chars.get(b)), chars.get(at))
    else {
        return true;
    };
    let joins = |c: char| {
        is_combining_mark(c)
            || c == '\u{200D}'
            || ('\u{FE00}'..='\u{FE0F}').contains(&c)
            || ('\u{E0100}'..='\u{E01EF}').contains(&c)
    };
    !(joins(after) || before == '\u{200D}' || (before == '\r' && after == '\n'))
}

/// A line's geometry along its baseline.
struct Along<'a> {
    line: &'a Line,
    origin: [f32; 2],
    direction: [f32; 2],
    /// Each character's extent along the baseline, when its glyph has a box.
    spans: Vec<Option<(f32, f32)>>,
    /// Whether each character reads right to left.
    rtl: Vec<bool>,
}

impl<'a> Along<'a> {
    fn new(line: &'a Line) -> Self {
        let [start, end] = line.baseline;
        let (dx, dy) = (end[0] - start[0], end[1] - start[1]);
        let length = dx.hypot(dy);
        let direction = if length > 1e-4 {
            [dx / length, dy / length]
        } else if line.direction == TextDirection::Vertical {
            [0.0, 1.0]
        } else {
            [1.0, 0.0]
        };
        let project =
            |[x, y]: [f32; 2]| (x - start[0]) * direction[0] + (y - start[1]) * direction[1];
        let mut spans: Vec<Option<(f32, f32)>> = line
            .chars
            .iter()
            .map(|c| {
                c.bbox.map(|[l, t, r, b]| {
                    let ends = [[l, t], [r, t], [l, b], [r, b]].map(project);
                    (
                        ends.iter().copied().fold(f32::INFINITY, f32::min),
                        ends.iter().copied().fold(f32::NEG_INFINITY, f32::max),
                    )
                })
            })
            .collect();
        let rtl = levels(line);
        // Characters of one glyph (a ligature, a letter and its marks) share it out evenly.
        let mut at = 0;
        while at < line.chars.len() {
            let glyph = line.chars.get(at).and_then(|c| c.glyph.as_ref());
            let mut end = at.saturating_add(1);
            while glyph.is_some() && line.chars.get(end).and_then(|c| c.glyph.as_ref()) == glyph {
                end = end.saturating_add(1);
            }
            let letters: Vec<usize> = (at..end)
                .filter(|&n| line.chars.get(n).is_some_and(|c| !is_combining_mark(c.ch)))
                .collect();
            if let (Some(Some((low, high))), true) = (spans.get(at).copied(), letters.len() > 1) {
                #[allow(clippy::cast_precision_loss)]
                let share = (high - low) / letters.len() as f32;
                let backwards = rtl.get(at).copied().unwrap_or(false);
                for (k, &n) in letters.iter().enumerate() {
                    #[allow(clippy::cast_precision_loss)]
                    let k = if backwards { letters.len() - 1 - k } else { k } as f32;
                    if let Some(slot) = spans.get_mut(n) {
                        *slot = Some((low + share * k, low + share * (k + 1.0)));
                    }
                }
            }
            at = end;
        }
        Self {
            line,
            origin: start,
            direction,
            spans,
            rtl,
        }
    }

    fn project(&self, [x, y]: [f32; 2]) -> f32 {
        (x - self.origin[0]) * self.direction[0] + (y - self.origin[1]) * self.direction[1]
    }

    fn point(&self, along: f32) -> [f32; 2] {
        [
            self.origin[0] + self.direction[0] * along,
            self.origin[1] + self.direction[1] * along,
        ]
    }

    /// Where the character at `at` starts (`leading`) or ends in reading order.
    fn edge(&self, at: usize, leading: bool) -> Option<f32> {
        let (low, high) = self.spans.get(at).copied().flatten()?;
        let rtl = self.rtl.get(at).copied().unwrap_or(false);
        Some(if leading != rtl { low } else { high })
    }

    /// Where the caret stands before character `at` (`at` = the length: after the last).
    fn caret(&self, at: usize) -> f32 {
        let count = self.line.chars.len();
        let before = (0..at.min(count)).rev().find_map(|n| self.edge(n, false));
        let after = (at..count).find_map(|n| self.edge(n, true));
        let own = self.edge(at, true);
        let previous = at.checked_sub(1).and_then(|n| self.edge(n, false));
        own.or(previous).or(before).or(after).unwrap_or(0.0)
    }
}

/// The caret stops of line `number`, which starts at caret index `start`.
fn line_stops(along: &Along<'_>, number: usize, start: usize) -> Vec<CaretStop> {
    let chars: Vec<char> = along.line.chars.iter().map(|c| c.ch).collect();
    (0..=chars.len())
        .filter(|&at| boundary(&chars, at))
        .map(|at| CaretStop {
            index: start.saturating_add(at),
            line: number,
            point: along.point(along.caret(at)),
        })
        .collect()
}

/// Whether each character of `line` reads right to left.
fn levels(line: &Line) -> Vec<bool> {
    let base = (line.direction == TextDirection::RightToLeft).then(Level::rtl);
    let info = BidiInfo::new(&line.text, base);
    line.text
        .char_indices()
        .map(|(at, _)| info.levels.get(at).is_some_and(|level| level.is_rtl()))
        .collect()
}

impl TextBlock {
    /// The caret index where each line starts.
    fn line_starts(&self) -> Vec<usize> {
        let mut starts = Vec::with_capacity(self.lines.len());
        let mut at = 0_usize;
        for line in &self.lines {
            starts.push(at);
            at = at.saturating_add(line.chars.len()).saturating_add(1);
        }
        starts
    }

    /// Every caret stop of the block, line by line in logical order.
    #[must_use]
    pub fn caret_stops(&self) -> Vec<CaretStop> {
        self.lines
            .iter()
            .enumerate()
            .zip(self.line_starts())
            .flat_map(|((number, line), start)| line_stops(&Along::new(line), number, start))
            .collect()
    }

    /// The caret index nearest `point` (page space): on the nearest line, the nearest stop.
    #[must_use]
    pub fn hit(&self, point: [f32; 2]) -> usize {
        let distance = |[l, t, r, b]: CharBox| {
            let dx = (l - point[0]).max(point[0] - r).max(0.0);
            let dy = (t - point[1]).max(point[1] - b).max(0.0);
            dx.hypot(dy)
        };
        let Some(((number, line), start)) = self
            .lines
            .iter()
            .enumerate()
            .zip(self.line_starts())
            .min_by(|((_, a), _), ((_, b), _)| distance(a.bbox).total_cmp(&distance(b.bbox)))
        else {
            return 0;
        };
        let along = Along::new(line);
        let at = along.project(point);
        line_stops(&along, number, start)
            .into_iter()
            .min_by(|a, b| {
                (along.project(a.point) - at)
                    .abs()
                    .total_cmp(&(along.project(b.point) - at).abs())
            })
            .map_or(0, |stop| stop.index)
    }

    /// The caret at `index`, as a box of no width across its line (no height for a vertical
    /// one), or `None` past the text.
    #[must_use]
    pub fn caret_rect(&self, index: usize) -> Option<CharBox> {
        let starts = self.line_starts();
        let (number, start) = starts
            .iter()
            .copied()
            .enumerate()
            .rev()
            .find(|&(_, start)| start <= index)?;
        let line = self.lines.get(number)?;
        let at = index.checked_sub(start)?;
        if at > line.chars.len() {
            return None;
        }
        let along = Along::new(line);
        let [x, y] = along.point(along.caret(at));
        let [l, t, r, b] = line.bbox;
        Some(if along.direction[0].abs() >= along.direction[1].abs() {
            [x, t, x, b]
        } else {
            [l, y, r, y]
        })
    }

    /// The boxes that cover the characters of `range` (caret indices), one per run that is
    /// together on screen: a range across both directions of a line takes several.
    #[must_use]
    pub fn selection_quads(&self, range: Range<usize>) -> Vec<CharBox> {
        let mut quads = Vec::new();
        for (line, start) in self.lines.iter().zip(self.line_starts()) {
            let along = Along::new(line);
            let selected = |at: usize| range.contains(&start.saturating_add(at));
            let mut spans: Vec<(f32, f32, bool)> = along
                .spans
                .iter()
                .enumerate()
                .filter_map(|(at, span)| span.map(|(low, high)| (low, high, selected(at))))
                .collect();
            spans.sort_by(|a, b| a.0.total_cmp(&b.0));
            let mut run: Option<(f32, f32)> = None;
            let [l, t, r, b] = line.bbox;
            let mut close = |run: &mut Option<(f32, f32)>| {
                if let Some((low, high)) = run.take() {
                    let [x0, y0] = along.point(low);
                    let [x1, y1] = along.point(high);
                    quads.push(if along.direction[0].abs() >= along.direction[1].abs() {
                        [x0.min(x1), t, x0.max(x1), b]
                    } else {
                        [l, y0.min(y1), r, y0.max(y1)]
                    });
                }
            };
            for (low, high, chosen) in spans {
                if chosen {
                    run = Some(run.map_or((low, high), |(a, b)| (a.min(low), b.max(high))));
                } else {
                    close(&mut run);
                }
            }
            close(&mut run);
        }
        quads
    }

    /// The text of `range` (caret indices), lines separated by line feeds, for copying.
    #[must_use]
    pub fn selected_text(&self, range: Range<usize>) -> String {
        self.text()
            .chars()
            .skip(range.start)
            .take(range.end.saturating_sub(range.start))
            .collect()
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;
    use crate::editability::Editability;
    use crate::extract::GlyphLink;
    use crate::layout::{Alignment, BlockId, TextChar};
    use ferman_core::interpret::{Span, SpanSource};

    /// A line of `text` from `x` on baseline `y`, each character 10 points wide,
    /// `glyphs[i]` the glyph of character i.
    fn line(text: &str, x: f32, y: f32, glyphs: &[usize], direction: TextDirection) -> Line {
        let chars: Vec<char> = text.chars().collect();
        let boxes: Vec<f32> = glyphs.iter().map(|&g| x + 10.0 * g as f32).collect();
        let link = |g: usize| GlyphLink {
            span: Span {
                source: SpanSource::Page { stream: (1, 0) },
                range: g..g + 1,
                carried: false,
            },
            index: g,
        };
        let chars: Vec<TextChar> = chars
            .iter()
            .zip(glyphs)
            .zip(boxes)
            .map(|((&ch, &g), left)| TextChar {
                ch,
                bbox: Some([left, y - 8.0, left + 10.0, y + 2.0]),
                glyph: Some(link(g)),
            })
            .collect();
        let width = 10.0 * (glyphs.iter().max().map_or(0, |g| g + 1)) as f32;
        Line {
            text: text.to_owned(),
            chars,
            words: Vec::new(),
            bbox: [x, y - 8.0, x + width, y + 2.0],
            baseline: [[x, y], [x + width, y]],
            size: 10.0,
            direction,
        }
    }

    fn block(lines: Vec<Line>) -> TextBlock {
        TextBlock {
            id: BlockId(1),
            bbox: [0.0, 0.0, 100.0, 100.0],
            lines,
            alignment: Alignment::Left,
            justification: None,
            direction: TextDirection::LeftToRight,
            column: 0,
            cell: None,
            editability: Editability::Editable,
        }
    }

    #[test]
    fn stops_fall_between_letters_and_never_inside_a_cluster() {
        // "şe" with a combining cedilla: s + U+0327 + e is two clusters.
        let block = block(vec![line(
            "s\u{327}e",
            0.0,
            20.0,
            &[0, 0, 1],
            TextDirection::LeftToRight,
        )]);
        let stops: Vec<(usize, f32)> = block
            .caret_stops()
            .iter()
            .map(|stop| (stop.index, stop.point[0]))
            .collect();
        assert_eq!(stops, [(0, 0.0), (2, 10.0), (3, 20.0)]);
    }

    #[test]
    fn a_point_hits_the_nearest_stop_on_the_nearest_line() {
        let block = block(vec![
            line("ab", 0.0, 20.0, &[0, 1], TextDirection::LeftToRight),
            line("cd", 0.0, 40.0, &[0, 1], TextDirection::LeftToRight),
        ]);
        assert_eq!(block.hit([3.0, 18.0]), 0);
        assert_eq!(block.hit([7.0, 18.0]), 1);
        // The second line starts at index 3, after "ab" and the line feed.
        assert_eq!(block.hit([19.0, 39.0]), 5);
        assert_eq!(block.hit([500.0, 500.0]), 5);
        assert_eq!(block.caret_rect(4), Some([10.0, 32.0, 10.0, 42.0]));
        assert_eq!(block.caret_rect(9), None);
    }

    #[test]
    fn a_ligature_is_shared_out_among_its_letters() {
        // "fi" drawn as one glyph, 10 points wide.
        let block = block(vec![line(
            "fix",
            0.0,
            20.0,
            &[0, 0, 1],
            TextDirection::LeftToRight,
        )]);
        let points: Vec<f32> = block
            .caret_stops()
            .iter()
            .map(|stop| stop.point[0])
            .collect();
        assert_eq!(points, [0.0, 5.0, 10.0, 20.0]);
    }

    #[test]
    fn right_to_left_carets_start_on_the_right() {
        // "שלום" in logical order, drawn right to left: ש rightmost.
        let block = block(vec![line(
            "שלום",
            0.0,
            20.0,
            &[3, 2, 1, 0],
            TextDirection::RightToLeft,
        )]);
        let points: Vec<f32> = block
            .caret_stops()
            .iter()
            .map(|stop| stop.point[0])
            .collect();
        assert_eq!(points, [40.0, 30.0, 20.0, 10.0, 0.0]);
        assert_eq!(block.hit([38.0, 20.0]), 0);
        // Selecting the first two letters covers the right half.
        assert_eq!(block.selection_quads(0..2), [[20.0, 12.0, 40.0, 22.0]]);
    }

    #[test]
    fn selection_covers_runs_across_lines_and_copies_their_text() {
        let block = block(vec![
            line("abc", 0.0, 20.0, &[0, 1, 2], TextDirection::LeftToRight),
            line("de", 0.0, 40.0, &[0, 1], TextDirection::LeftToRight),
        ]);
        assert_eq!(
            block.selection_quads(1..5),
            [[10.0, 12.0, 30.0, 22.0], [0.0, 32.0, 10.0, 42.0]]
        );
        assert_eq!(block.selected_text(1..5), "bc\nd");
    }

    #[test]
    fn mixed_directions_select_in_several_runs() {
        // "אב12" in a right-to-left line: the digits read left to right, left of the letters.
        let block = block(vec![line(
            "אב12",
            0.0,
            20.0,
            &[3, 2, 0, 1],
            TextDirection::RightToLeft,
        )]);
        // ב and 1 are logically adjacent but not together on screen.
        assert_eq!(
            block.selection_quads(1..3),
            [[0.0, 12.0, 10.0, 22.0], [20.0, 12.0, 30.0, 22.0]]
        );
    }
}
