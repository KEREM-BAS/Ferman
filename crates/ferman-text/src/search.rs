//! Finding text (a2-4a, G61): a query and a page's text are folded the same way, and the matches
//! come back as character ranges of the page's text.
//!
//! Folding, in order: compatibility forms become their letters (NFKC: "ﬁ", Arabic presentation
//! forms), letters lose their case unless Match case is on (Turkish dotted and dotless i included:
//! "kira" finds "KİRA", "ılık" finds "ILIK"), and with Ignore accents and dotted/dotless i, on by
//! default for every document, marks go (NFD), "ı" is "i", "ß" is "ss", and the Arabic tatweel goes.
//! Runs of white space, line breaks included, are one space. Whole words needs a match to start
//! and end at a word's edges.
// Offsets index into strings the caller passes in (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::ops::Range;

use unicode_normalization::UnicodeNormalization;
use unicode_normalization::char::is_combining_mark;

/// How to match (a2-4a's options).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SearchOptions {
    /// Match case: upper and lower case differ.
    pub match_case: bool,
    /// Whole words: a match starts and ends at word edges.
    pub whole_words: bool,
    /// Ignore accents and dotted/dotless i, on by default (G61).
    pub ignore_accents: bool,
    /// Whether the document is Turkish or Azerbaijani, so that without ignoring accents "I"
    /// lowers to "ı" and "İ" to "i".
    pub turkish: bool,
}

impl Default for SearchOptions {
    fn default() -> Self {
        Self {
            match_case: false,
            whole_words: false,
            ignore_accents: true,
            turkish: false,
        }
    }
}

/// The matches of `query` in `text`, as character ranges of `text`, in order and not
/// overlapping. An empty query matches nothing.
#[must_use]
pub fn find(text: &str, query: &str, options: &SearchOptions) -> Vec<Range<usize>> {
    let (query, _) = fold(query, options);
    let query: Vec<char> = query.trim().chars().collect();
    if query.is_empty() {
        return Vec::new();
    }
    let (folded, source) = fold(text, options);
    let folded: Vec<char> = folded.chars().collect();
    let mut matches = Vec::new();
    let mut at = 0;
    while let Some(window) = folded.get(at..) {
        let Some(offset) = window
            .windows(query.len())
            .position(|w| w == query.as_slice())
        else {
            break;
        };
        let start = at.saturating_add(offset);
        let end = start.saturating_add(query.len());
        let edge = |i: Option<usize>| i.and_then(|i| folded.get(i)).is_none_or(|c| !word(*c));
        if options.whole_words && !(edge(start.checked_sub(1)) && edge(Some(end))) {
            at = start.saturating_add(1);
            continue;
        }
        if let (Some(&first), Some(&last)) = (
            source.get(start),
            end.checked_sub(1).and_then(|i| source.get(i)),
        ) {
            matches.push(first..last.saturating_add(1));
        }
        at = end;
    }
    matches
}

/// Whether `c` is part of a word.
fn word(c: char) -> bool {
    c.is_alphanumeric() || is_combining_mark(c)
}

/// `text` folded, with the index of the character of `text` each folded character came from.
fn fold(text: &str, options: &SearchOptions) -> (String, Vec<usize>) {
    let mut folded = String::new();
    let mut source = Vec::new();
    let mut space = false;
    for (index, c) in text.chars().enumerate() {
        if c.is_whitespace() {
            if !space {
                folded.push(' ');
                source.push(index);
            }
            space = true;
            continue;
        }
        space = false;
        for c in std::iter::once(c).nfkc() {
            for c in lower(c, options) {
                if options.ignore_accents {
                    for c in std::iter::once(c).nfd() {
                        if is_combining_mark(c) || c == '\u{640}' {
                            continue;
                        }
                        let plain: &[char] = match c {
                            'ı' => &['i'],
                            'ß' if !options.match_case => &['s', 's'],
                            _ => std::slice::from_ref(&c),
                        };
                        for &plain in plain {
                            folded.push(plain);
                            source.push(index);
                        }
                    }
                } else {
                    folded.push(c);
                    source.push(index);
                }
            }
        }
    }
    (folded, source)
}

/// `c` in lower case, unless Match case is on.
fn lower(c: char, options: &SearchOptions) -> Vec<char> {
    if options.match_case {
        return vec![c];
    }
    match c {
        // Rust lowers "İ" to "i" with a combining dot above.
        'İ' => vec!['i'],
        'I' if options.turkish && !options.ignore_accents => vec!['ı'],
        c => c.to_lowercase().collect(),
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    fn found(text: &str, query: &str, options: &SearchOptions) -> Vec<String> {
        let chars: Vec<char> = text.chars().collect();
        find(text, query, options)
            .into_iter()
            .map(|range| chars[range].iter().collect())
            .collect()
    }

    #[test]
    fn the_defaults_fold_turkish_and_accents_for_every_document() {
        let defaults = SearchOptions::default();
        assert_eq!(
            found("KİRA SÖZLEŞMESİ, Kira bedeli", "kira", &defaults),
            ["KİRA", "Kira"]
        );
        assert_eq!(found("ILIK su", "ılık", &defaults), ["ILIK"]);
        assert_eq!(
            found("Moda Cad., İSTANBUL", "istanbul", &defaults),
            ["İSTANBUL"]
        );
        assert_eq!(found("Herr Müller", "muller", &defaults), ["Müller"]);
        assert_eq!(found("sözleşme", "sozlesme", &defaults), ["sözleşme"]);
        // "i" finds İ, ı and î; "c" finds ç (a2-4a's description).
        assert_eq!(found("İ ı î", "i", &defaults), ["İ", "ı", "î"]);
        assert_eq!(found("çay", "c", &defaults), ["ç"]);
        assert_eq!(found("Straße", "strasse", &defaults), ["Straße"]);
        assert_eq!(found("Straße", "straße", &defaults), ["Straße"]);
    }

    #[test]
    fn without_ignoring_accents_turkish_case_folding_still_holds() {
        let turkish = SearchOptions {
            ignore_accents: false,
            turkish: true,
            ..SearchOptions::default()
        };
        assert_eq!(found("KİRA", "kira", &turkish), ["KİRA"]);
        assert_eq!(found("ILIK", "ılık", &turkish), ["ILIK"]);
        assert!(
            found("ILIK", "ilik", &turkish).is_empty(),
            "I is the capital of ı"
        );
        assert!(found("sözleşme", "sozlesme", &turkish).is_empty());
    }

    #[test]
    fn arabic_matches_without_its_marks_and_presentation_forms() {
        let defaults = SearchOptions::default();
        assert_eq!(found("جمعيّة الإسكان", "جمعية", &defaults), ["جمعيّة"]);
        // U+FEF5 is lam-alef with madda as one presentation form.
        assert_eq!(found("\u{FEF5}", "لا", &defaults).len(), 1);
    }

    #[test]
    fn match_case_whole_words_and_white_space() {
        let case = SearchOptions {
            match_case: true,
            ..SearchOptions::default()
        };
        assert_eq!(found("Kira kira", "kira", &case), ["kira"]);
        let whole = SearchOptions {
            whole_words: true,
            ..SearchOptions::default()
        };
        assert_eq!(found("kiracı kira kiralık", "kira", &whole), ["kira"]);
        assert_eq!(
            found("kira\n  bedeli", "kira bedeli", &SearchOptions::default()),
            ["kira\n  bedeli"]
        );
        assert!(found("kira", "  ", &SearchOptions::default()).is_empty());
    }
}
