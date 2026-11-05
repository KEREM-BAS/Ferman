//! Right-to-left text for the rewrite (docs/ARCHITECTURE.md §6.6, ROADMAP §7 step 7): the bidi
//! algorithm (UAX #9, through unicode-bidi) splits the logical text the editor gives into
//! directional runs, per paragraph, and orders a line's runs visually; each run is then shaped
//! on its own in its direction.
//!
//! Numbers, dates and an IBAN inside a right-to-left paragraph are left-to-right runs of their
//! own (rules W and N of UAX #9), so they keep their reading order. The paragraph level is the
//! block's: right to left for a right-to-left block, whatever its first strong character is,
//! as [`extract`](crate::extract) reads such lines back.
//!
//! Characters the shaper hides (default ignorables such as ZWNJ, which only breaks a join) are
//! not written: their glyph would read back as a space ([`is_hidden`]).
// Byte offsets index the editor's text (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::ops::Range;

use unicode_bidi::{BidiInfo, Level};

/// A directional run of a line, as a byte range of the text.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Run {
    pub(crate) range: Range<usize>,
    /// Right to left (an odd embedding level).
    pub(crate) rtl: bool,
}

/// The runs of `line`, a byte range of one paragraph of `text` (paragraphs end at line feeds),
/// in visual order from the left, with the paragraph level right to left when `rtl`.
pub(crate) fn visual_runs(text: &str, line: Range<usize>, rtl: bool) -> Vec<Run> {
    if line.is_empty() {
        return Vec::new();
    }
    let level = if rtl { Level::rtl() } else { Level::ltr() };
    let info = BidiInfo::new(text, Some(level));
    let Some(paragraph) = info
        .paragraphs
        .iter()
        .find(|paragraph| paragraph.range.contains(&line.start))
    else {
        return Vec::new();
    };
    let line = line.start..line.end.min(paragraph.range.end);
    let (levels, runs) = info.visual_runs(paragraph, line);
    runs.into_iter()
        .map(|range| Run {
            rtl: levels.get(range.start).is_some_and(|level| level.is_rtl()),
            range,
        })
        .collect()
}

/// Whether `text` is only characters a shaper hides and a producer does not write: the zero
/// width joiners and non-joiners, the bidi marks and the other default ignorables of the
/// format class.
pub(crate) fn is_hidden(text: &str) -> bool {
    !text.is_empty()
        && text.chars().all(|c| {
            matches!(c, '\u{200B}'..='\u{200F}' | '\u{202A}'..='\u{202E}' | '\u{2060}'..='\u{2069}' | '\u{FEFF}')
        })
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    fn pieces<'a>(text: &'a str, runs: &[Run]) -> Vec<(&'a str, bool)> {
        runs.iter()
            .map(|run| (&text[run.range.clone()], run.rtl))
            .collect()
    }

    #[test]
    fn an_iban_and_a_number_stay_left_to_right_inside_arabic() {
        let text = "رقم الحساب الدولي (IBAN): JO14 AHCB 0010 والمبلغ 2025";
        let runs = visual_runs(text, 0..text.len(), true);
        let pieces = pieces(text, &runs);
        // Visual order from the left: the number, the Arabic between, the IBAN, the bracketed
        // "IBAN" (its brackets take the paragraph's direction, rule N0), the sentence's start.
        assert_eq!(
            pieces,
            vec![
                ("2025", false),
                (" والمبلغ ", true),
                ("JO14 AHCB 0010", false),
                ("): ", true),
                ("IBAN", false),
                ("رقم الحساب الدولي (", true),
            ]
        );
    }

    #[test]
    fn english_inside_hebrew_is_one_run_and_the_paragraph_reads_right_to_left() {
        let text = "השוכר Ferman Ltd חתם";
        let runs = visual_runs(text, 0..text.len(), true);
        assert_eq!(
            pieces(text, &runs),
            vec![(" חתם", true), ("Ferman Ltd", false), ("השוכר ", true)]
        );
    }

    #[test]
    fn a_line_takes_its_own_range_of_a_later_paragraph() {
        let text = "שלום\nעולם 12";
        let start = text.find('ע').unwrap();
        let runs = visual_runs(text, start..text.len(), true);
        assert_eq!(pieces(text, &runs), vec![("12", false), ("עולם ", true)]);
        assert!(visual_runs(text, 3..3, true).is_empty());
    }

    #[test]
    fn a_left_to_right_paragraph_keeps_its_order() {
        let text = "Kira 2025 עולם";
        let runs = visual_runs(text, 0..text.len(), false);
        assert_eq!(
            pieces(text, &runs),
            vec![("Kira 2025 ", false), ("עולם", true)]
        );
    }

    #[test]
    fn zero_width_non_joiners_are_hidden_and_letters_are_not() {
        assert!(is_hidden("\u{200C}"));
        assert!(is_hidden("\u{200D}\u{200F}"));
        assert!(!is_hidden("ی\u{200C}"));
        assert!(!is_hidden(""));
        assert!(!is_hidden(" "));
    }
}
