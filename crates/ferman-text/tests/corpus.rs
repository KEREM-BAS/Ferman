//! Text extraction on the generated corpus (ROADMAP §6 step 5): every page of every generated file
//! reads as the generator's source text, after NFC and compared without whitespace, as the PDFium
//! oracle compares (`tools/corpus/tests/oracle.rs`): spaces and line breaks follow the layout.
//! And the queries of ROADMAP §6 step 5 find their words with the default options.
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;
use std::sync::Arc;

use ferman_core::{Document, OpenOptions, Password, Source, open};
use ferman_text::{SearchOptions, find};
use unicode_normalization::UnicodeNormalization;

/// The encrypted files' passwords, as `tools/corpus` writes them.
const PASSWORDS: [(&str, &str); 4] = [
    ("payslip-aes128", "bordro2026"),
    ("payslip-aes256", "Eylül2026maaşı"),
    ("payslip-rc4-128", "bordro2026"),
    ("payslip-rc4-40", "bordro2026"),
];

/// Files that are not about text: `truncated` does not open, and lopdf sees two of
/// `disagree-pages`'s three pages, which is what that file tests (G102).
const SKIPPED: [&str; 2] = ["disagree-pages", "truncated"];

/// Pages known to differ: `edit-e18-columns-standin` reads in drawing order, its two columns' lines
/// taking turns (BACKLOG B163). A page that starts to match fails the test, so this list stays
/// true.
const KNOWN: [(&str, usize); 1] = [("edit-e18-columns-standin", 1)];

fn squeeze(text: &str) -> String {
    text.nfc().filter(|c| !c.is_whitespace()).collect()
}

#[test]
fn every_generated_file_reads_as_its_source_text() {
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/corpus/generated");
    let mut names: Vec<String> = std::fs::read_dir(&dir)
        .unwrap()
        .filter_map(|entry| {
            let name = entry.unwrap().file_name().into_string().unwrap();
            name.strip_suffix(".expected.txt").map(str::to_owned)
        })
        .collect();
    names.sort();
    assert!(names.len() >= 20, "{names:?}");
    let mut failures = Vec::new();
    for name in names
        .iter()
        .filter(|name| !SKIPPED.contains(&name.as_str()))
    {
        let bytes = std::fs::read(dir.join(format!("{name}.pdf"))).unwrap();
        let expected = std::fs::read_to_string(dir.join(format!("{name}.expected.txt"))).unwrap();
        let password = PASSWORDS
            .iter()
            .find(|(file, _)| file == name)
            .map(|(_, password)| Password::new((*password).to_owned()));
        let options = OpenOptions {
            password,
            ..OpenOptions::default()
        };
        let Ok(document) = open(&Source::from_bytes(Arc::from(&bytes[..])), &options) else {
            failures.push(format!("{name}: does not open"));
            continue;
        };
        let pages: Vec<&str> = expected.split('\u{c}').collect();
        if document.page_count() != pages.len() {
            failures.push(format!(
                "{name}: {} pages, {} expected",
                document.page_count(),
                pages.len()
            ));
            continue;
        }
        for (index, want) in pages.iter().enumerate() {
            let got = ferman_text::page_text(&document, index).unwrap();
            let (got, want) = (squeeze(&got), squeeze(want));
            let known = KNOWN.contains(&(name.as_str(), index + 1));
            if known && got == want {
                failures.push(format!(
                    "{name} page {}: matches now; remove it from KNOWN",
                    index + 1
                ));
            }
            if got != want && !known {
                let at = got
                    .chars()
                    .zip(want.chars())
                    .take_while(|(a, b)| a == b)
                    .count();
                let around = |text: &str| {
                    text.chars()
                        .skip(at.saturating_sub(10))
                        .take(30)
                        .collect::<String>()
                };
                failures.push(format!(
                    "{name} page {}: differs at character {at}: got «{}», want «{}»",
                    index + 1,
                    around(&got),
                    around(&want)
                ));
            }
        }
    }
    assert!(
        failures.is_empty(),
        "{} failures:\n{}",
        failures.len(),
        failures.join("\n")
    );
}

/// A generated file, opened.
fn generated(name: &str) -> Document {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"));
    let bytes = std::fs::read(path).unwrap();
    open(
        &Source::from_bytes(Arc::from(&bytes[..])),
        &OpenOptions::default(),
    )
    .unwrap()
}

#[test]
fn actual_text_counts_only_where_it_still_says_what_the_page_shows() {
    // A sequence over a code without text in two shows; one whose text is not what its glyphs
    // draw, as after an edit; and plain text. The file has no table of cross references, which
    // the opener repairs.
    let content = b"/Span <</ActualText (fi)>> BDC \
        BT /F1 12 Tf 72 700 Td (\\001) Tj ET BT /F1 12 Tf 80 700 Td (\\001) Tj ET EMC \
        /Span <</ActualText (old)>> BDC BT /F1 12 Tf 72 680 Td (new) Tj ET EMC \
        BT /F1 12 Tf 72 660 Td (plain) Tj ET";
    let mut bytes = b"%PDF-1.7\n1 0 obj <</Type/Catalog/Pages 2 0 R>> endobj\n\
        2 0 obj <</Type/Pages/Kids[3 0 R]/Count 1>> endobj\n\
        3 0 obj <</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R\
        /Resources<</Font<</F1<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>>>>>>> endobj\n"
        .to_vec();
    bytes.extend_from_slice(format!("4 0 obj <</Length {}>> stream\n", content.len()).as_bytes());
    bytes.extend_from_slice(content);
    bytes.extend_from_slice(b"\nendstream endobj\ntrailer <</Root 1 0 R>>\n");
    let document = open(
        &Source::from_bytes(Arc::from(&bytes[..])),
        &OpenOptions::default(),
    )
    .unwrap();
    let text = ferman_text::page_text(&document, 0).unwrap();
    assert_eq!(text, "fi\nnew\nplain");
}

#[test]
fn the_roadmap_queries_find_their_words() {
    for (name, query, word) in [
        ("kira-tr", "kira", "KİRA"),
        ("kira-tr", "kira", "Kira"),
        // kira-tr writes the city in title case; the query folds both.
        ("kira-tr", "istanbul", "İstanbul"),
        ("tez-tr", "ILIK", "ılık"),
        ("mietvertrag-de", "muller", "Müller"),
        ("mietvertrag-de", "gleimstrasse", "Gleimstraße"),
        ("report-ar", "الاسكان", "الإسكان"),
    ] {
        let document = generated(name);
        let found: Vec<String> = (0..document.page_count())
            .flat_map(|page| {
                let text = ferman_text::page_text(&document, page).unwrap();
                let chars: Vec<char> = text.chars().collect();
                find(&text, query, &SearchOptions::default())
                    .into_iter()
                    .map(|range| chars[range].iter().collect::<String>())
                    .collect::<Vec<_>>()
            })
            .collect();
        assert!(
            found.iter().any(|hit| hit == word),
            "{name}: {query} found {found:?}"
        );
    }
}

#[test]
fn every_character_has_its_box_where_the_page_shows_it() {
    let document = generated("kira-tr");
    let layout = ferman_text::extract::page_layout(&document, 0).unwrap();
    assert_eq!(layout.text.chars().count(), layout.boxes.len());
    let (width, height) = document.structure().pages[0].size;
    // The title is the first line, near the top of an A4 page, in displayed points (y down).
    let [left, top, right, bottom] = layout.boxes[0].unwrap();
    assert!(
        left > 0.0 && right < width && left < right,
        "{left} {right}"
    );
    assert!(
        top > 0.0 && top < bottom && bottom < height / 4.0,
        "{top} {bottom}"
    );
    // Line breaks have no box; every other character of a line of text has one.
    for (c, area) in layout.text.chars().zip(&layout.boxes) {
        match c {
            '\n' => assert!(area.is_none()),
            ' ' => {}
            _ => assert!(area.is_some(), "{c:?} has no box"),
        }
    }
}
