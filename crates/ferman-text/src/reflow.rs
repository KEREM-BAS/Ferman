//! An edited block's new text laid out in its frame, and the overflow choices when it does not
//! fit (docs/ARCHITECTURE.md §6.6 and §6.8, ROADMAP §7 steps 4 and 5, a3-4, a3-18, G38, G54).
//! Plans only: `rewrite` turns them into operators.
//!
//! - **Frame.** [`Frame::of`] reads a block's frame from its lines: the first baseline's
//!   direction, the pitch between the first two baselines (one line: 1.2 em, until the caller
//!   sets the line's `TL`), and the extent along the line of all its lines, so a right-aligned
//!   block's frame ends where its lines end and a centred one's centre stays.
//! - **Lines.** The text breaks greedily at [`linebreak`](crate::linebreak)'s opportunities: a
//!   line takes the next piece while it fits the frame's width, a line feed ends a paragraph, a
//!   piece wider than the frame gets a line of its own (no hyphenation, M4). Spaces at the end of a
//!   line do not count; in vertical text a comma or full stop may hang past the end (burasage).
//! - **Alignment.** Left and justified lines start at the frame's start, right-aligned lines keep
//!   its end, centred lines its centre. A justified line but a paragraph's last stretches to the
//!   frame by the block's own method: the same extra length per space for `Tw` and for `TJ`
//!   adjustments after the spaces, per glyph for text without spaces.
//! - **Overflow.** When the lines need more than the frame holds, [`overflow`] offers the three
//!   choices with their amounts. *Extend block by N line(s)* grows the frame by N pitches across
//!   the lines, unless the new lines' area meets another block of the page or leaves the page.
//!   *Tighten spacing slightly (−x%)* is the smallest tracking, in steps of 0.1% of the em per
//!   glyph (−0.6% is `Tc` −0.006 em, glyph shapes unchanged), up to [`TIGHTEN_CAP`], that makes
//!   the text fit. *Keep and warn* is always there: every line is kept and the ones past the
//!   frame are counted as hidden.
//!
//! Lengths are page-space points along the line. The caller's advance function gives each
//! character's advance with the line's font, size, `Tc` and `Tz` and without the justification's
//! `Tw`, which the plan computes; `rewrite` turns the plan's lengths into `Tw`, `Tc` and `TJ`
//! numbers through the line's text matrix.

use std::ops::Range;

use crate::editability::overlaps;
use crate::extract::CharBox;
use crate::layout::{Alignment, BlockId, Justification, TextBlock, TextDirection};
use crate::linebreak::{Break, HANGING, breaks};

/// The most a block's tracking may tighten, in percent of the em per glyph (docs/PROGRESS.md
/// M3 decision 5).
pub const TIGHTEN_CAP: f32 = 2.0;
/// The step the tightening is tried and shown in, in percent: one decimal, as a3-4 shows it.
const TIGHTEN_STEP: f32 = 0.1;
/// The leading of a one-line block whose pitch is unknown, in ems.
const DEFAULT_LEADING: f32 = 1.2;
/// How far a line may pass the frame and still fit, in points: rounding, not layout.
const FIT: f32 = 1e-3;

/// Where a block's lines go.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Frame {
    /// The start of the first line's baseline at the frame's start (its left, or top in vertical
    /// text), in page space.
    pub origin: [f32; 2],
    /// The unit vector along the lines.
    pub along: [f32; 2],
    /// The unit vector from one baseline to the next.
    pub across: [f32; 2],
    /// The frame's length along the lines.
    pub width: f32,
    /// The distance from one baseline to the next.
    pub pitch: f32,
    /// How many lines it holds.
    pub lines: usize,
    /// The em the tracking is measured in: the block's largest font size.
    pub size: f32,
    /// How the lines sit.
    pub alignment: Alignment,
    /// How a justified block stretches its lines.
    pub justification: Option<Justification>,
    /// Whether a comma or full stop may hang past the end of a line: vertical text.
    pub hanging: bool,
}

impl Frame {
    /// The frame of `block`'s lines (module documentation); `None` for a block without lines.
    #[must_use]
    pub fn of(block: &TextBlock) -> Option<Self> {
        let first = block.lines.first()?;
        let [start, end] = first.baseline;
        let along = unit(sub(end, start)).unwrap_or(match block.direction {
            TextDirection::Vertical => [0.0, 1.0],
            _ => [1.0, 0.0],
        });
        // A quarter turn clockwise in page space (y down): down for horizontal lines, to the left
        // for vertical columns.
        let across = [-along[1], along[0]];
        let size = block.lines.iter().map(|line| line.size).fold(0.0, f32::max);
        let pitch = block
            .lines
            .get(1)
            .map(|second| dot(sub(second.baseline[0], start), across))
            .filter(|pitch| *pitch > 0.0)
            .unwrap_or(size * DEFAULT_LEADING);
        let (low, high) = block
            .lines
            .iter()
            .fold((0.0_f32, 0.0_f32), |(low, high), line| {
                let [from, to] = line.baseline;
                (
                    low.min(dot(sub(from, start), along)),
                    high.max(dot(sub(to, start), along)),
                )
            });
        Some(Self {
            origin: add(start, scale(along, low)),
            along,
            across,
            width: high - low,
            pitch,
            lines: block.lines.len(),
            size,
            alignment: block.alignment,
            justification: block.justification,
            hanging: block.direction == TextDirection::Vertical,
        })
    }
}

/// How a justified line stretches to its frame.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Stretch {
    /// The block's method.
    pub method: Justification,
    /// The places that stretch: the spaces, or for [`Justification::Glyphs`] the gaps between
    /// characters.
    pub gaps: usize,
    /// The extra length at each.
    pub per_gap: f32,
}

/// One line of a plan.
#[derive(Debug, Clone, PartialEq)]
pub struct PlannedLine {
    /// Its text, as a byte range of the new text, without the spaces and the line feed after it.
    pub range: Range<usize>,
    /// The start of its baseline, in page space (its left, or top in vertical text).
    pub start: [f32; 2],
    /// Its natural length, without stretching; a hanging comma or full stop does not count.
    pub width: f32,
    /// How it stretches, when it is a justified line other than a paragraph's last.
    pub stretch: Option<Stretch>,
    /// Whether it ends a paragraph: a line feed or the end of the text follows it.
    pub last: bool,
}

/// The new text laid out in a frame.
#[derive(Debug, Clone, PartialEq)]
pub struct ReflowPlan {
    /// The lines, from the first; the ones past the frame's lines too.
    pub lines: Vec<PlannedLine>,
    /// How many lines the frame holds.
    pub frame_lines: usize,
}

impl ReflowPlan {
    /// How many lines go past the frame.
    #[must_use]
    pub fn over(&self) -> usize {
        self.lines.len().saturating_sub(self.frame_lines)
    }
}

/// `text` laid out in `frame` with the character advances `advance` gives (module
/// documentation).
#[must_use]
pub fn reflow(frame: &Frame, text: &str, advance: impl Fn(char) -> f32) -> ReflowPlan {
    lay(frame, text, &advance, 0.0)
}

/// The overflow choices of `text` in `block`'s `frame`, or `None` when it fits. `others` are the
/// page's blocks (the block itself among them is skipped) and `page` the page's box in page
/// space.
#[must_use]
pub fn overflow(
    block: &TextBlock,
    frame: &Frame,
    text: &str,
    advance: impl Fn(char) -> f32,
    others: &[TextBlock],
    page: CharBox,
) -> Option<OverflowPlan> {
    let plan = lay(frame, text, &advance, 0.0);
    let over = plan.over();
    if over == 0 {
        return None;
    }
    Some(OverflowPlan {
        over,
        extend: extend(block, frame, over, others, page),
        tighten: tighten(frame, text, &advance),
        keep: Keep { hidden: over },
    })
}

/// The three choices for a block whose text needs more lines than its frame holds.
#[derive(Debug, Clone, PartialEq)]
pub struct OverflowPlan {
    /// How many lines go past the frame.
    pub over: usize,
    /// "Extend block by N line(s)", or why it is disabled.
    pub extend: Result<Extend, ExtendBlocked>,
    /// "Tighten spacing slightly (−x%)", or why it is disabled.
    pub tighten: Result<Tighten, TightenShort>,
    /// "Keep and warn", always available.
    pub keep: Keep,
}

/// The frame grown to hold every line.
#[derive(Debug, Clone, PartialEq)]
pub struct Extend {
    /// How many lines it grows by: the N of the label.
    pub lines: usize,
    /// The grown frame.
    pub frame: Frame,
    /// The area the new lines take, in page space, `[left, top, right, bottom]`.
    pub area: CharBox,
}

/// Why the frame cannot grow.
#[derive(Debug, Clone, PartialEq)]
pub enum ExtendBlocked {
    /// The new lines would cover another block: a3-18's "The IBAN line sits right below this
    /// block.", worded by the UI from the block's text.
    Block {
        /// The block in the way.
        id: BlockId,
        /// Its first line.
        text: String,
    },
    /// The new lines would leave the page.
    PageEdge,
}

/// The tracking that makes the text fit.
#[derive(Debug, Clone, PartialEq)]
pub struct Tighten {
    /// The amount in percent of the em, one decimal: the 0.6 of "(−0.6%)".
    pub percent: f32,
    /// The length every glyph's advance shrinks by, in points: `Tc` in page space.
    pub tracking: f32,
    /// The text laid out with it.
    pub plan: ReflowPlan,
}

/// Why tightening is disabled: a3-18's "Even the tightest allowed spacing leaves N line(s) over."
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TightenShort {
    /// The N: the lines still past the frame at [`TIGHTEN_CAP`].
    pub over: usize,
}

/// The lines kept past the frame, clipped, for the "+N line hidden" warning.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Keep {
    /// How many lines are hidden.
    pub hidden: usize,
}

fn extend(
    block: &TextBlock,
    frame: &Frame,
    over: usize,
    others: &[TextBlock],
    page: CharBox,
) -> Result<Extend, ExtendBlocked> {
    let last = block.lines.last().map_or(block.bbox, |line| line.bbox);
    // The last line's band across the lines, as long as the block along them.
    // shortcut: an axis-aligned band, so a turned (not quarter-turned) block's area is too large;
    // exact quads when such a block needs extending.
    let band = if frame.along[0].abs() >= frame.along[1].abs() {
        [block.bbox[0], last[1], block.bbox[2], last[3]]
    } else {
        [last[0], block.bbox[1], last[2], block.bbox[3]]
    };
    let near = shift(band, scale(frame.across, frame.pitch));
    #[allow(clippy::cast_precision_loss)]
    let far = shift(band, scale(frame.across, frame.pitch * over as f32));
    let area = [
        near[0].min(far[0]),
        near[1].min(far[1]),
        near[2].max(far[2]),
        near[3].max(far[3]),
    ];
    // shortcut: only text blocks are obstacles; images and paths join when the text model
    // records their boxes.
    if let Some(other) = others
        .iter()
        .find(|other| other.id != block.id && overlaps(area, other.bbox))
    {
        return Err(ExtendBlocked::Block {
            id: other.id,
            text: other
                .lines
                .first()
                .map(|line| line.text.clone())
                .unwrap_or_default(),
        });
    }
    if area[0] < page[0] || area[1] < page[1] || area[2] > page[2] || area[3] > page[3] {
        return Err(ExtendBlocked::PageEdge);
    }
    Ok(Extend {
        lines: over,
        frame: Frame {
            lines: frame.lines.saturating_add(over),
            ..*frame
        },
        area,
    })
}

fn tighten(
    frame: &Frame,
    text: &str,
    advance: &dyn Fn(char) -> f32,
) -> Result<Tighten, TightenShort> {
    let mut over = 0;
    // Whole steps, so the amount tried is the amount shown.
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    let steps = (TIGHTEN_CAP / TIGHTEN_STEP).round() as u32;
    for step in 1..=steps {
        #[allow(clippy::cast_precision_loss)]
        let percent = (step as f32 * TIGHTEN_STEP * 10.0).round() / 10.0;
        let tracking = percent / 100.0 * frame.size;
        let plan = lay(frame, text, advance, tracking);
        over = plan.over();
        if over == 0 {
            return Ok(Tighten {
                percent,
                tracking,
                plan,
            });
        }
    }
    Err(TightenShort { over })
}

fn lay(frame: &Frame, text: &str, advance: &dyn Fn(char) -> f32, tracking: f32) -> ReflowPlan {
    let measure = |range: Range<usize>| -> f32 {
        text.get(range)
            .unwrap_or_default()
            .chars()
            .map(|c| advance(c) - tracking)
            .sum()
    };
    // The line's text without the spaces after it, and its length for fitting.
    let content = |range: Range<usize>| -> (Range<usize>, f32) {
        let piece = text.get(range.clone()).unwrap_or_default();
        let trimmed = piece.trim_end();
        let end = range.start.saturating_add(trimmed.len());
        // One comma or full stop hangs, as letter-ja-vertical hangs it.
        let fitted = if frame.hanging {
            trimmed
                .strip_suffix(|c| HANGING.contains(c))
                .unwrap_or(trimmed)
        } else {
            trimmed
        };
        let width = measure(range.start..range.start.saturating_add(fitted.len()));
        (range.start..end, width)
    };
    let mut lines = Vec::new();
    let mut place = |range: Range<usize>, last: bool| {
        let (range, width) = content(range);
        let index = lines.len();
        lines.push(planned(frame, text, range, width, last, index));
    };
    let (mut start, mut end) = (0, 0);
    for (at, kind) in breaks(text) {
        if end > start && content(start..at).1 > frame.width + FIT {
            place(start..end, false);
            start = end;
        }
        end = at;
        if kind == Break::Mandatory {
            place(start..at, true);
            start = at;
        }
    }
    ReflowPlan {
        lines,
        frame_lines: frame.lines,
    }
}

fn planned(
    frame: &Frame,
    text: &str,
    range: Range<usize>,
    width: f32,
    last: bool,
    index: usize,
) -> PlannedLine {
    let room = frame.width - width;
    let offset = match frame.alignment {
        Alignment::Left | Alignment::Justified => 0.0,
        Alignment::Right => room,
        Alignment::Center => room / 2.0,
    };
    let piece = text.get(range.clone()).unwrap_or_default();
    let stretch = frame
        .justification
        .filter(|_| frame.alignment == Alignment::Justified && !last && room > FIT)
        .and_then(|method| {
            let gaps = match method {
                Justification::WordSpacing | Justification::Adjustments => {
                    piece.chars().filter(|&c| c == ' ').count()
                }
                Justification::Glyphs => piece.chars().count().saturating_sub(1),
            };
            #[allow(clippy::cast_precision_loss)]
            (gaps > 0).then(|| Stretch {
                method,
                gaps,
                per_gap: room / gaps as f32,
            })
        });
    #[allow(clippy::cast_precision_loss)]
    let down = frame.pitch * index as f32;
    PlannedLine {
        range,
        start: add(
            add(frame.origin, scale(frame.along, offset)),
            scale(frame.across, down),
        ),
        width,
        stretch,
        last,
    }
}

fn sub(a: [f32; 2], b: [f32; 2]) -> [f32; 2] {
    [a[0] - b[0], a[1] - b[1]]
}

fn add(a: [f32; 2], b: [f32; 2]) -> [f32; 2] {
    [a[0] + b[0], a[1] + b[1]]
}

fn scale(a: [f32; 2], by: f32) -> [f32; 2] {
    [a[0] * by, a[1] * by]
}

fn dot(a: [f32; 2], b: [f32; 2]) -> f32 {
    a[0] * b[0] + a[1] * b[1]
}

fn unit(a: [f32; 2]) -> Option<[f32; 2]> {
    let length = dot(a, a).sqrt();
    (length > f32::EPSILON).then(|| scale(a, 1.0 / length))
}

fn shift(rect: CharBox, by: [f32; 2]) -> CharBox {
    [
        rect[0] + by[0],
        rect[1] + by[1],
        rect[2] + by[0],
        rect[3] + by[1],
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A horizontal frame at (100, 200), `width` long, holding `lines` lines 12 points apart, at
    /// 10 points.
    fn frame(width: f32, lines: usize, alignment: Alignment) -> Frame {
        Frame {
            origin: [100.0, 200.0],
            along: [1.0, 0.0],
            across: [0.0, 1.0],
            width,
            pitch: 12.0,
            lines,
            size: 10.0,
            alignment,
            justification: None,
            hanging: false,
        }
    }

    /// Latin letters 5 points wide, spaces 2.5, ideographs and kana 10.
    fn advance(c: char) -> f32 {
        match c {
            ' ' => 2.5,
            c if c.is_ascii() => 5.0,
            _ => 10.0,
        }
    }

    fn texts<'a>(plan: &ReflowPlan, text: &'a str) -> Vec<&'a str> {
        plan.lines
            .iter()
            .map(|line| &text[line.range.clone()])
            .collect()
    }

    #[test]
    fn lines_fill_the_frame_and_line_feeds_end_paragraphs() {
        let text = "aaa bbb ccc\nddd";
        let plan = reflow(&frame(40.0, 3, Alignment::Left), text, advance);
        assert_eq!(texts(&plan, text), ["aaa bbb", "ccc", "ddd"]);
        assert_eq!(
            plan.lines.iter().map(|line| line.last).collect::<Vec<_>>(),
            [false, true, true]
        );
        assert_eq!(plan.lines[0].width, 32.5);
        assert_eq!(plan.lines[1].start, [100.0, 212.0]);
        assert_eq!(plan.lines[2].start, [100.0, 224.0]);
        assert_eq!(plan.over(), 0);
    }

    #[test]
    fn turkish_text_breaks_at_spaces_only() {
        let text = "Kiracı, aylık kira bedeli olan 18.500 TL’yi öder.";
        let plan = reflow(&frame(60.0, 9, Alignment::Left), text, advance);
        assert_eq!(
            texts(&plan, text),
            [
                "Kiracı,",
                "aylık kira",
                "bedeli olan",
                "18.500",
                "TL’yi",
                "öder."
            ]
        );
    }

    #[test]
    fn a_word_wider_than_the_frame_gets_a_line_of_its_own() {
        let text = "a bbbbbbbbbbbb c";
        let plan = reflow(&frame(30.0, 3, Alignment::Left), text, advance);
        assert_eq!(texts(&plan, text), ["a", "bbbbbbbbbbbb", "c"]);
        assert_eq!(plan.lines[1].width, 60.0);
    }

    #[test]
    fn right_aligned_lines_keep_the_end_and_centred_ones_the_centre() {
        let text = "aaa bbb ccc";
        let right = reflow(&frame(40.0, 2, Alignment::Right), text, advance);
        for line in &right.lines {
            assert_eq!(line.start[0] + line.width, 140.0);
        }
        let center = reflow(&frame(40.0, 2, Alignment::Center), text, advance);
        for line in &center.lines {
            assert_eq!(line.start[0] + line.width / 2.0, 120.0);
        }
    }

    #[test]
    fn justified_lines_stretch_by_the_blocks_method_but_the_last() {
        let text = "aa bb cc dd";
        for method in [Justification::WordSpacing, Justification::Adjustments] {
            let mut justified = frame(40.0, 2, Alignment::Justified);
            justified.justification = Some(method);
            let plan = reflow(&justified, text, advance);
            assert_eq!(texts(&plan, text), ["aa bb cc", "dd"]);
            // 3 × 10 + 2 × 2.5 = 35 points: 5 to share between 2 spaces.
            assert_eq!(
                plan.lines[0].stretch,
                Some(Stretch {
                    method,
                    gaps: 2,
                    per_gap: 2.5
                })
            );
            assert_eq!(plan.lines[1].stretch, None);
        }
    }

    #[test]
    fn text_without_spaces_stretches_glyph_by_glyph() {
        let text = "工事は五日間";
        let mut justified = frame(35.0, 2, Alignment::Justified);
        justified.justification = Some(Justification::Glyphs);
        let plan = reflow(&justified, text, advance);
        assert_eq!(texts(&plan, text), ["工事は", "五日間"]);
        assert_eq!(
            plan.lines[0].stretch,
            Some(Stretch {
                method: Justification::Glyphs,
                gaps: 2,
                per_gap: 2.5
            })
        );
    }

    #[test]
    fn kinsoku_pushes_a_character_on_and_vertical_text_hangs_the_comma() {
        let text = "工事は五日間、です";
        // Horizontal: "間、" does not fit, so "間" goes with its comma (oidashi).
        let plan = reflow(&frame(60.0, 2, Alignment::Left), text, advance);
        assert_eq!(texts(&plan, text), ["工事は五日", "間、です"]);
        // Vertical: the comma hangs below the full column (burasage).
        let mut vertical = frame(60.0, 2, Alignment::Left);
        vertical.hanging = true;
        let plan = reflow(&vertical, text, advance);
        assert_eq!(texts(&plan, text), ["工事は五日間、", "です"]);
        assert_eq!(plan.lines[0].width, 60.0);
        // Only one mark hangs; two push the last character on, as the corpus sets them.
        let text = "工事は五日間。。です";
        let plan = reflow(&vertical, text, advance);
        assert_eq!(texts(&plan, text), ["工事は五日", "間。。です"]);
    }

    fn block(text: &str) -> TextBlock {
        TextBlock {
            id: BlockId(1),
            bbox: [100.0, 190.0, 200.0, 203.0],
            lines: vec![crate::layout::Line {
                text: text.to_owned(),
                chars: Vec::new(),
                words: Vec::new(),
                bbox: [100.0, 190.0, 200.0, 203.0],
                baseline: [[100.0, 200.0], [200.0, 200.0]],
                size: 10.0,
                direction: TextDirection::LeftToRight,
            }],
            alignment: Alignment::Left,
            justification: None,
            direction: TextDirection::LeftToRight,
            column: 0,
            cell: None,
            editability: crate::Editability::Editable,
        }
    }

    const PAGE: CharBox = [0.0, 0.0, 595.0, 842.0];

    #[test]
    fn tightening_takes_the_smallest_step_that_fits() {
        // 21 glyphs, 102.5 points, in a 100-point frame: 1.2% of the em (0.12 points a glyph)
        // makes 99.98 points.
        let text = "aaaaaaaaaa aaaaaaaaaa";
        let plan = overflow(
            &block(text),
            &frame(100.0, 1, Alignment::Left),
            text,
            advance,
            &[],
            PAGE,
        )
        .unwrap();
        assert_eq!(plan.over, 1);
        let tighten = plan.tighten.unwrap();
        assert_eq!(tighten.percent, 1.2);
        assert!((tighten.tracking - 0.12).abs() < 1e-6);
        assert_eq!(tighten.plan.lines.len(), 1);
        assert_eq!(plan.keep, Keep { hidden: 1 });
        let extend = plan.extend.unwrap();
        assert_eq!(extend.lines, 1);
        assert_eq!(extend.frame.lines, 2);
        assert_eq!(extend.area, [100.0, 202.0, 200.0, 215.0]);
    }

    #[test]
    fn tightening_past_the_cap_says_how_many_lines_are_left_over() {
        // 41 glyphs, 202.5 points: 2% takes 8.2 points off, not enough for 190.
        let text = "aaaaaaaaaaaaaaaaaaaa aaaaaaaaaaaaaaaaaaaa";
        let plan = overflow(
            &block(text),
            &frame(190.0, 1, Alignment::Left),
            text,
            advance,
            &[],
            PAGE,
        )
        .unwrap();
        assert_eq!(plan.tighten, Err(TightenShort { over: 1 }));
        assert_eq!(plan.keep, Keep { hidden: 1 });
        // Exactly at the cap it fits: 202.5 − 8.2 = 194.3.
        let plan = overflow(
            &block(text),
            &frame(194.3, 1, Alignment::Left),
            text,
            advance,
            &[],
            PAGE,
        )
        .unwrap();
        assert_eq!(plan.tighten.unwrap().percent, 2.0);
    }

    #[test]
    fn extending_into_another_block_or_off_the_page_is_blocked() {
        let text = "aaaaaaaaaa aaaaaaaaaa aaaaaaaaaa";
        let mut below = block("IBAN: TR12");
        below.id = BlockId(2);
        below.bbox = [100.0, 210.0, 160.0, 223.0];
        let edited = block(text);
        let plan = overflow(
            &edited,
            &frame(100.0, 1, Alignment::Left),
            text,
            advance,
            &[edited.clone(), below],
            PAGE,
        )
        .unwrap();
        assert_eq!(plan.over, 2);
        assert_eq!(
            plan.extend,
            Err(ExtendBlocked::Block {
                id: BlockId(2),
                text: "IBAN: TR12".to_owned()
            })
        );
        let plan = overflow(
            &edited,
            &frame(100.0, 1, Alignment::Left),
            text,
            advance,
            &[],
            [0.0, 0.0, 595.0, 210.0],
        )
        .unwrap();
        assert_eq!(plan.extend, Err(ExtendBlocked::PageEdge));
    }

    #[test]
    fn text_that_fits_has_no_overflow() {
        let text = "aa";
        assert!(
            overflow(
                &block(text),
                &frame(100.0, 1, Alignment::Left),
                text,
                advance,
                &[],
                PAGE
            )
            .is_none()
        );
    }
}
