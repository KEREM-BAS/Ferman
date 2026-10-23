//! Kinsoku (禁則), the Japanese line-breaking rules (JIS X 4051), for vertical columns and for
//! horizontal lines: a line never starts with closing punctuation, small kana or the long vowel
//! mark, and never ends with an opening bracket.

use crate::text::BREAK;

/// Characters a line may not start with (the classes of JIS X 4051 letters use).
pub const NO_START: &str = "、。，．・：；？！ー）」』】〕〉》ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ々ゝゞヽヾ…‥";
/// Characters a line may not end with.
pub const NO_END: &str = "（「『【〔〈《";
/// Punctuation that may hang past the end of a full line (burasage).
pub const HANGING: &str = "、。，．";

/// `text` with a [`BREAK`] wherever a horizontal line may break: between any two characters,
/// except before one that may not start a line, after one that may not end it, and inside a
/// run of Latin letters, digits and their punctuation.
#[must_use]
pub fn breakable(text: &str) -> String {
    let latin = |c: char| c.is_ascii_alphanumeric() || ",.%-/:()¥".contains(c);
    let mut out = String::with_capacity(text.len() * 2);
    let mut previous: Option<char> = None;
    for c in text.chars() {
        if let Some(before) = previous {
            let keep =
                NO_START.contains(c) || NO_END.contains(before) || (latin(before) && latin(c));
            if !keep {
                out.push(BREAK);
            }
        }
        out.push(c);
        previous = Some(c);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn breaks_go_between_characters_but_not_before_punctuation() {
        let text = breakable("工事は五日間、¥45,000です。");
        let pieces: Vec<&str> = text.split(BREAK).collect();
        assert_eq!(
            pieces,
            [
                "工", "事", "は", "五", "日", "間、", "¥45,000", "で", "す。"
            ]
        );
    }
}
