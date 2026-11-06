//! A block's style as the text panel changes it (a3-2, FmEditPanel): its font through a face that
//! exists, never a faked bold or italic; its size, colour, alignment, spacing, place and size.
//!
//! [`rewrite_block_styled`](crate::rewrite_block_styled) lays the block out again in its frame with
//! a [`BlockStyle`]; [`block_style`](crate::block_style) reads what the panel shows.
//!
//! A PDF has no underline in its fonts and no spacing around a paragraph, so neither is here: the
//! panel keeps those controls disabled with the reason.

use ferman_fonts::FontOrigin;

use crate::extract::CharBox;
use crate::layout::{Alignment, Line, TextBlock};
use crate::reflow::Frame;

/// The most a font size may be, in points: the largest page PDF allows is not much larger.
pub const MAX_SIZE: f32 = 1000.0;
/// The least a font size may be, in points.
pub const MIN_SIZE: f32 = 1.0;
/// The least a frame may be across or along its lines, in points.
pub const MIN_FRAME: f32 = 1.0;

/// A font a block is set in: what a [`crate::FontCandidate`] or a toggle of [`BlockStyleInfo`] names.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BlockFont {
    /// Its group.
    pub origin: FontOrigin,
    /// Its PostScript name.
    pub postscript_name: String,
}

/// What to change in a block; what is `None` stays as it is.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct BlockStyle {
    /// The font the whole block is set in.
    pub font: Option<BlockFont>,
    /// The font size in points.
    pub size: Option<f32>,
    /// The fill colour, `0xRRGGBB`.
    pub colour: Option<u32>,
    /// How the lines sit.
    pub alignment: Option<Alignment>,
    /// The space between characters, in percent of the em.
    pub char_spacing: Option<f32>,
    /// The distance between baselines, in multiples of the font size.
    pub line_spacing: Option<f32>,
    /// The block's box in page space, `[left, top, right, bottom]`: its first baseline moves with
    /// the top left, and the text reflows in the new width and height.
    pub frame: Option<CharBox>,
}

impl BlockStyle {
    /// Whether it changes nothing.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        *self == Self::default()
    }

    /// This style with what `other` sets replaced.
    #[must_use]
    pub fn merged(&self, other: Self) -> Self {
        Self {
            font: other.font.or_else(|| self.font.clone()),
            size: other.size.or(self.size),
            colour: other.colour.or(self.colour),
            alignment: other.alignment.or(self.alignment),
            char_spacing: other.char_spacing.or(self.char_spacing),
            line_spacing: other.line_spacing.or(self.line_spacing),
            frame: other.frame.or(self.frame),
        }
    }

    /// Whether its numbers can be written: finite and in range. They come from the UI, not files.
    #[must_use]
    pub fn valid(&self) -> bool {
        self.size
            .is_none_or(|size| (MIN_SIZE..=MAX_SIZE).contains(&size))
            && self.colour.is_none_or(|colour| colour <= 0x00FF_FFFF)
            && self
                .char_spacing
                .is_none_or(|percent| (-50.0..=200.0).contains(&percent))
            && self
                .line_spacing
                .is_none_or(|multiple| (0.5..=10.0).contains(&multiple))
            && self.frame.is_none_or(|[left, top, right, bottom]| {
                [left, top, right, bottom].iter().all(|v| v.is_finite())
                    && right - left >= MIN_FRAME
                    && bottom - top >= MIN_FRAME
            })
    }
}

/// What the text panel shows of a block.
#[derive(Debug, Clone, PartialEq)]
pub struct BlockStyleInfo {
    /// Its first font's PostScript name, without the subset tag.
    pub font: String,
    /// Its first font's family.
    pub family: String,
    /// Whether its first font is bold.
    pub bold: bool,
    /// Whether its first font is italic.
    pub italic: bool,
    /// The face with the bold state turned over, of the same family and italic state, that can
    /// draw the whole block; `None` disables Bold (never faked).
    pub bold_toggle: Option<BlockFont>,
    /// The same for Italic.
    pub italic_toggle: Option<BlockFont>,
    /// Its largest font size in points.
    pub size: f32,
    /// Its fill colour, `0xRRGGBB`; `None` for a pattern or a colour space without a known
    /// conversion.
    pub colour: Option<u32>,
    /// The page's text colours, the most used first, at most eight.
    pub document_colours: Vec<u32>,
    /// How its lines sit.
    pub alignment: Alignment,
    /// The space between characters, in percent of the em.
    pub char_spacing: f32,
    /// The distance between baselines, in multiples of the font size.
    pub line_spacing: f32,
    /// Its box in page space.
    pub frame: CharBox,
}

/// `block`'s text for a new layout: a line feed only where a line ended before the frame did, so
/// a line that wrapped wraps again in a new width. A justified block is one paragraph.
#[must_use]
pub fn paragraph_text(block: &TextBlock) -> String {
    let Some(frame) = Frame::of(block) else {
        return block.text();
    };
    let justified = block.alignment == Alignment::Justified;
    let mut text = String::new();
    let mut lines = block.lines.iter().peekable();
    while let Some(line) = lines.next() {
        text.push_str(&line.text);
        let Some(next) = lines.peek() else {
            break;
        };
        text.push(
            if justified || first_word(next) + line.size / 4.0 > frame.width - length(line) {
                ' '
            } else {
                '\n'
            },
        );
    }
    text
}

fn length(line: &Line) -> f32 {
    let [[x0, y0], [x1, y1]] = line.baseline;
    (x1 - x0).hypot(y1 - y0)
}

/// The width of `line`'s first word.
fn first_word(line: &Line) -> f32 {
    line.words
        .first()
        .and_then(|word| line.chars.get(word.clone()))
        .unwrap_or_default()
        .iter()
        .filter_map(|c| c.bbox)
        .map(|[left, _, right, _]| right - left)
        .sum()
}

/// The red, green and blue of `0xRRGGBB`, from 0 to 1.
pub(crate) fn components(colour: u32) -> [f32; 3] {
    let channel = |shift: u32| ((colour >> shift) & 0xFF) as f32 / 255.0;
    [channel(16), channel(8), channel(0)]
}

/// `0xRRGGBB` of a colour's numbers in a device colour space, for showing it.
pub(crate) fn rgb(space: &[u8], numbers: &[f32]) -> Option<u32> {
    let channel = |value: f32| -> u32 {
        // In 0..=255 after the clamp.
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let byte = (value.clamp(0.0, 1.0) * 255.0).round() as u32;
        byte
    };
    let [r, g, b] = match (space, numbers) {
        (b"DeviceGray", &[gray]) => [gray, gray, gray],
        (b"DeviceRGB", &[r, g, b]) => [r, g, b],
        // The plain conversion PDF's readers fall back on; a press profile would differ a little.
        (b"DeviceCMYK", &[c, m, y, k]) => [
            (1.0 - c) * (1.0 - k),
            (1.0 - m) * (1.0 - k),
            (1.0 - y) * (1.0 - k),
        ],
        _ => return None,
    };
    Some(channel(r) << 16 | channel(g) << 8 | channel(b))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn colours_read_and_write() {
        assert_eq!(rgb(b"DeviceGray", &[0.0]), Some(0));
        assert_eq!(rgb(b"DeviceRGB", &[1.0, 0.0, 0.0]), Some(0x00FF_0000));
        assert_eq!(rgb(b"DeviceCMYK", &[0.0, 0.0, 0.0, 1.0]), Some(0));
        assert_eq!(rgb(b"Pattern", &[]), None);
        assert_eq!(components(0x00FF_0000), [1.0, 0.0, 0.0]);
    }

    #[test]
    fn numbers_out_of_range_are_refused() {
        assert!(BlockStyle::default().valid());
        let style = |edit: fn(&mut BlockStyle)| {
            let mut style = BlockStyle::default();
            edit(&mut style);
            style
        };
        for bad in [
            style(|s| s.size = Some(0.0)),
            style(|s| s.size = Some(f32::NAN)),
            style(|s| s.colour = Some(0x0100_0000)),
            style(|s| s.line_spacing = Some(0.0)),
            style(|s| s.frame = Some([10.0, 10.0, 10.0, 20.0])),
            style(|s| s.frame = Some([f32::NAN, 0.0, 10.0, 20.0])),
        ] {
            assert!(!bad.valid(), "{bad:?}");
        }
    }

    #[test]
    fn merging_keeps_what_the_later_style_leaves_out() {
        let first = BlockStyle {
            size: Some(10.0),
            colour: Some(1),
            ..BlockStyle::default()
        };
        let later = BlockStyle {
            colour: Some(2),
            ..BlockStyle::default()
        };
        let merged = first.merged(later);
        assert_eq!((merged.size, merged.colour), (Some(10.0), Some(2)));
    }
}
