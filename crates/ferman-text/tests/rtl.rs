//! Right-to-left editing (ROADMAP §7 step 7, E09 to E11) on the edit corpus: the new text is
//! split by the bidi algorithm, shaped in the bundled IBM Plex fonts (the same fonts as the
//! documents' subsets) and written as the subsets' own glyphs, found again by name. Each edit is
//! applied in a revision and read back: the text is the logical text, right-aligned lines keep
//! their right edge. The fonts come from `app/assets/fonts`, never from the machine. The saved
//! files and their renders are checked in ferman-api's `edit_cases`.
// Test helpers fail loudly.
#![allow(
    clippy::panic,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::path::PathBuf;
use std::sync::Arc;

use ferman_core::revision::{RevisionStore, Splice};
use ferman_core::{Document, OpenOptions, Source, open};
use ferman_fonts::{FontLibrary, FontOrigin, ScanLimits};
use ferman_text::{
    EditContext, FontSources, Outcome, Rewrite, SubstitutionKind, TextBlock, Unsupported,
    rewrite_block, rewrite_block_fonts, text_page, text_page_revised,
};
use unicode_normalization::UnicodeNormalization;

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn document(name: &str) -> Document {
    let bytes = std::fs::read(root().join(format!("tests/corpus/generated/{name}.pdf"))).unwrap();
    open(
        &Source::from_bytes(Arc::from(bytes)),
        &OpenOptions::default(),
    )
    .unwrap()
}

fn bundled() -> FontLibrary {
    let mut library = FontLibrary::new();
    library.add_dir(
        &root().join("app/assets/fonts"),
        FontOrigin::Bundled,
        &ScanLimits::default(),
    );
    library
}

fn block(doc: &Document, page: usize, needle: &str) -> TextBlock {
    text_page(doc, page, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains(needle)))
        .unwrap()
}

/// The block's text with `from` replaced by `to`, its lines joined by line feeds.
fn edited(block: &TextBlock, from: &str, to: &str) -> String {
    let text: Vec<&str> = block.lines.iter().map(|line| line.text.as_str()).collect();
    let text = text.join("\n");
    assert!(text.contains(from), "{text:?}");
    text.replacen(from, to, 1)
}

/// Rewrites `target` to `text` with the bundled fonts, applies it in a revision and returns the
/// rewrite and the block that holds `needle` afterwards.
fn apply(
    doc: &Document,
    page: usize,
    target: &TextBlock,
    text: &str,
    needle: &str,
) -> (Rewrite, TextBlock) {
    let library = bundled();
    let sources = FontSources {
        library: Some(&library),
        ..FontSources::default()
    };
    let outcome = rewrite_block_fonts(doc, None, page, target, text, &[], None, &sources).unwrap();
    let Outcome::Rewritten(rewrite) = outcome else {
        panic!("{outcome:?}");
    };
    let mut store = RevisionStore::new(doc);
    store.begin().unwrap();
    store
        .add_new_fonts(
            doc,
            page,
            &rewrite.fonts,
            &rewrite.simple_fonts,
            &rewrite.new_fonts,
        )
        .unwrap();
    let splices: Vec<Splice> = rewrite
        .splices
        .iter()
        .map(|splice| Splice {
            source: splice.source,
            range: splice.range.clone(),
            bytes: splice.bytes.clone(),
        })
        .collect();
    store.splice(doc, page, &splices, &[]).unwrap();
    store.commit().unwrap();
    let after = text_page_revised(doc, &store, page, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| squeeze(&block.text()).contains(&squeeze(needle)))
        .unwrap_or_else(|| panic!("no block with {needle:?} after the edit"));
    (rewrite, after)
}

fn squeeze(text: &str) -> String {
    text.nfc().filter(|c| !c.is_whitespace()).collect()
}

fn right_edge(block: &TextBlock) -> f32 {
    block
        .lines
        .iter()
        .map(|line| line.baseline[0][0].max(line.baseline[1][0]))
        .fold(f32::MIN, f32::max)
}

#[test]
fn without_a_font_library_right_to_left_text_asks_for_one() {
    let doc = document("he-para");
    let target = block(&doc, 0, "הרצל 24");
    let text = edited(&target, "הרצל 24", "הרצל 26");
    assert_eq!(
        rewrite_block(&doc, 0, &target, &text).unwrap(),
        Outcome::Unsupported(Unsupported::Shaping)
    );
}

#[test]
fn e09_an_arabic_word_beside_the_iban_takes_the_subsets_own_glyphs() {
    // Page 10: "رقم الحساب الدولي (IBAN): JO14 …", right-aligned. The new word is set on the
    // same page, so its joining forms are in the subset: nothing new is embedded.
    let doc = document("report-ar");
    let target = block(&doc, 9, "(IBAN)");
    let text = edited(&target, "الدولي", "الجمعية");
    let (rewrite, after) = apply(&doc, 9, &target, &text, "رقم الحساب");
    assert!(rewrite.new_fonts.is_empty(), "{:?}", rewrite.substitutions);
    assert!(rewrite.substitutions.is_empty());
    // The IBAN and the number stay left to right, the text reads back logically.
    assert_eq!(squeeze(&after.text()), squeeze(&text));
    assert!((right_edge(&after) - right_edge(&target)).abs() < 0.05);
}

#[test]
fn e09_a_form_the_subset_lacks_comes_from_the_same_font_and_is_said() {
    // A fully vowelled word: the marks the report never sets come from the bundled IBM Plex
    // Sans Arabic in a new font, said once; its letters stay the subset's.
    let doc = document("report-ar");
    let target = block(&doc, 9, "(IBAN)");
    let text = edited(&target, "الدولي", "الدُّوَلِيّ ظظظ");
    let (rewrite, after) = apply(&doc, 9, &target, &text, "ظظظ");
    assert_eq!(squeeze(&after.text()), squeeze(&text));
    assert_eq!(rewrite.new_fonts.len(), 1);
    let [substitution] = rewrite.substitutions.as_slice() else {
        panic!("{:?}", rewrite.substitutions);
    };
    assert_eq!(substitution.kind, SubstitutionKind::SameFont);
    assert_eq!(substitution.from, "IBMPlexSansArabic");
    assert_eq!(substitution.to, "IBMPlexSansArabic");
    assert_eq!(substitution.origin, FontOrigin::Bundled);
    assert!(substitution.chars.contains('\u{651}'), "{substitution:?}");
    assert!(!substitution.chars.contains('ظ'), "{substitution:?}");
}

#[test]
fn e10_a_persian_word_with_a_zero_width_non_joiner() {
    // "می‌شود": the non-joiner keeps "می" unjoined and is not written, as the document's own
    // words are, so the text reads back without it.
    let doc = document("fa-zwnj");
    let target = block(&doc, 0, "برای هماهنگی");
    let text = edited(
        &target,
        "تماس بگیرید",
        "تماس بگیرید که پاسخ داده می\u{200C}شود",
    );
    let (rewrite, after) = apply(&doc, 0, &target, &text, "پاسخ داده");
    assert_eq!(
        squeeze(&after.text()),
        squeeze(&text.replace('\u{200C}', ""))
    );
    assert!((right_edge(&after) - right_edge(&target)).abs() < 0.05);
    // No glyph of the new text is the non-joiner's: every written code reads as a letter.
    assert!(!after.text().contains('\u{200C}'));
    assert!(rewrite.splices.len() == 1);
}

#[test]
fn e11_a_hebrew_sentence_reflows_right_to_left() {
    // The justified two-line paragraph gets a longer sentence: it reflows, its last line keeps
    // the right edge, and the house number stays left to right.
    let doc = document("he-para");
    let target = block(&doc, 0, "השוכרים מתבקשים");
    let text = edited(&target, "לשנה נוספת.", "לשנה נוספת, ולשלם עד יום 15 בחודש.");
    let (_, after) = apply(&doc, 0, &target, &text, "15 בחודש");
    assert_eq!(squeeze(&after.text()), squeeze(&text));
    assert_eq!(after.lines.len(), 2);
    let last = after.lines.last().unwrap();
    assert!(
        (last.baseline[0][0].max(last.baseline[1][0]) - right_edge(&target)).abs() < 0.05,
        "{:?}",
        last.baseline
    );
}

#[test]
fn e11_hebrew_words_swapped_reuse_the_subsets_glyphs() {
    let doc = document("he-para");
    let target = block(&doc, 0, "הרצל 24");
    let text = edited(&target, "ברחוב הרצל 24", "ברחוב הרצל 42");
    let (rewrite, after) = apply(&doc, 0, &target, &text, "הרצל 42");
    assert!(rewrite.new_fonts.is_empty());
    assert_eq!(squeeze(&after.text()), squeeze(&text));
    assert!((right_edge(&after) - right_edge(&target)).abs() < 0.05);
}
