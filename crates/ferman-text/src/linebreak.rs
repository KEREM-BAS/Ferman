//! Where an edited block's text may break into lines (docs/ARCHITECTURE.md §6.6, ROADMAP §7
//! step 4): the Unicode line breaking algorithm (UAX #14, through unicode-linebreak) with
//! Ferman's own tailoring.
//!
//! - **UAX #14.** Latin, Turkish and other European text breaks after spaces and hyphens, never
//!   inside a word, a number ("18.500,00") or before closing punctuation. Ideographs and kana
//!   break between characters.
//! - **Kinsoku (禁則, JIS X 4051).** A line never starts with closing punctuation, small kana, the
//!   long vowel mark or an iteration mark, and never ends with an opening bracket: the classes
//!   `tools/corpus` breaks the corpus's Chinese and Japanese text with, which UAX #14 alone leaves
//!   open in places (small kana are breakable in its default tailoring).
//! - **Korean** breaks at spaces only, as Korean is set (and as `ko-para` is), not between
//!   syllables.
//! - **Mandatory breaks** at line feeds, the editor's paragraph ends, and at the end of the text.
//!
//! No hyphenation (M4). Hanging punctuation is the reflow's business ([`HANGING`]).

use unicode_linebreak::BreakOpportunity;

/// Characters a line may not start with (JIS X 4051's closing punctuation, small kana, the long
/// vowel and iteration marks), as `tools/corpus` has them.
pub const NO_START: &str = "、。，．・：；？！ー）」』】〕〉》ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ々ゝゞヽヾ…‥";
/// Characters a line may not end with: the opening brackets.
pub const NO_END: &str = "（「『【〔〈《";
/// Punctuation that may hang past the end of a full vertical line (burasage), as
/// `letter-ja-vertical` hangs it.
pub const HANGING: &str = "、。，．";

/// A place where a line may end.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Break {
    /// The line may end here.
    Allowed,
    /// The line ends here: after a line feed, and at the end of the text.
    Mandatory,
}

/// The places `text` may break, as byte offsets after which a line ends, in order; the last is
/// always the end of the text, [`Break::Mandatory`].
#[must_use]
pub fn breaks(text: &str) -> Vec<(usize, Break)> {
    let mut found: Vec<(usize, Break)> = unicode_linebreak::linebreaks(text)
        .filter_map(|(at, kind)| match kind {
            BreakOpportunity::Mandatory => Some((at, Break::Mandatory)),
            BreakOpportunity::Allowed => {
                let before = text.get(..at).and_then(|head| head.chars().next_back());
                let after = text.get(at..).and_then(|tail| tail.chars().next());
                let kept = match (before, after) {
                    (Some(before), Some(after)) => {
                        NO_START.contains(after)
                            || NO_END.contains(before)
                            || (hangul(before) && hangul(after))
                    }
                    _ => false,
                };
                (!kept).then_some((at, Break::Allowed))
            }
        })
        .collect();
    // unicode-linebreak gives an empty text no break at all.
    if found.is_empty() {
        found.push((0, Break::Mandatory));
    }
    found
}

/// Hangul syllables and jamo.
fn hangul(c: char) -> bool {
    matches!(c, '\u{AC00}'..='\u{D7A3}' | '\u{1100}'..='\u{11FF}' | '\u{3130}'..='\u{318F}')
}

#[cfg(test)]
mod tests {
    use super::*;

    /// `text` cut at its break opportunities.
    fn pieces(text: &str) -> Vec<&str> {
        let mut start = 0;
        breaks(text)
            .into_iter()
            .map(|(at, _)| {
                let piece = &text[start..at];
                start = at;
                piece
            })
            .collect()
    }

    #[test]
    fn turkish_breaks_after_spaces_and_keeps_numbers_whole() {
        assert_eq!(
            pieces("Kiracı, aylık kira bedeli olan 18.500 TL’yi öder."),
            [
                "Kiracı, ",
                "aylık ",
                "kira ",
                "bedeli ",
                "olan ",
                "18.500 ",
                "TL’yi ",
                "öder."
            ]
        );
    }

    #[test]
    fn japanese_breaks_between_characters_but_not_before_punctuation() {
        // tools/corpus's kinsoku test, but for UAX #14's LB25, which keeps a closing mark with
        // the currency sign after it.
        assert_eq!(
            pieces("工事は五日間、¥45,000です。"),
            ["工", "事", "は", "五", "日", "間、¥45,000", "で", "す。"]
        );
    }

    #[test]
    fn kinsoku_keeps_small_kana_and_brackets_with_their_neighbours() {
        assert_eq!(pieces("ちょっと「契約」"), ["ちょっ", "と", "「契", "約」"]);
    }

    #[test]
    fn korean_breaks_at_spaces_only() {
        assert_eq!(pieces("임대차 계약서를"), ["임대차 ", "계약서를"]);
    }

    #[test]
    fn line_feeds_are_mandatory_and_the_end_always_is() {
        assert_eq!(
            breaks("Madde 1\nMadde 2"),
            [
                (6, Break::Allowed),
                (8, Break::Mandatory),
                (14, Break::Allowed),
                (15, Break::Mandatory)
            ]
        );
        assert_eq!(breaks(""), [(0, Break::Mandatory)]);
    }
}
