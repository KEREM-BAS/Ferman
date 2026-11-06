//! The text model against the generators' ground truth (ROADMAP §7 step 1): for every generated
//! file with a `<name>.blocks.json`, every page's blocks in reading order, their lines (text and
//! baseline), alignment, justification method, column and table cell match what `tools/corpus` drew, 100%.
//!
//! The 95% check of step 1 counts the blocks that match over the corpus and over the hand-labelled
//! real-world files in `tests/corpus/real-world/` (`<name>.pdf` and `<name>.blocks.json`). That
//! folder does not exist until the owner's files come (M3 question 4), so today the check sees only
//! generated files and proves no more than the 100% test does; it fails on a real file's labels
//! the day they arrive.
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::Arc;

use ferman_core::{OpenOptions, Password, Source, open};
use ferman_text::{Alignment, EditContext, Justification, NotEditableReason, text_page};
use serde_json::Value;
use unicode_normalization::UnicodeNormalization;

/// The encrypted files' passwords, as `tools/corpus` writes them.
const PASSWORDS: [(&str, &str); 4] = [
    ("payslip-aes128", "bordro2026"),
    ("payslip-aes256", "Eylül2026maaşı"),
    ("payslip-rc4-128", "bordro2026"),
    ("payslip-rc4-40", "bordro2026"),
];

/// Files whose ground truth measures other widths than the ones a reader draws: `edit-e15-helvetica`
/// names Helvetica without `/Widths` but breaks its lines with IBM Plex Sans's widths, so only where
/// its lines start is compared.
const KNOWN_WIDTHS: [&str; 1] = ["edit-e15-helvetica"];

fn squeeze(text: &str) -> String {
    text.nfc().filter(|c| !c.is_whitespace()).collect()
}

fn alignment(name: &str) -> Alignment {
    match name {
        "left" => Alignment::Left,
        "right" => Alignment::Right,
        "center" => Alignment::Center,
        "justified" => Alignment::Justified,
        other => panic!("alignment {other}"),
    }
}

fn justification(value: &Value) -> Option<Justification> {
    match value.as_str() {
        None => None,
        Some("tw") => Some(Justification::WordSpacing),
        Some("tj") => Some(Justification::Adjustments),
        Some(other) => panic!("justify {other}"),
    }
}

fn point(value: &Value) -> (f32, f32) {
    let x = value[0].as_f64().unwrap();
    let y = value[1].as_f64().unwrap();
    #[allow(clippy::cast_possible_truncation)]
    (x as f32, y as f32)
}

/// What the files of `dir` with a `<name>.blocks.json` match.
#[derive(Default)]
struct Tally {
    /// Blocks in the ground truth.
    blocks: usize,
    /// The ground truth's blocks found as drawn.
    matched: usize,
    /// Pages all of whose blocks match.
    pages: usize,
    /// Every mismatch, to file as a case.
    failures: Vec<String>,
}

/// The model of every file of `dir` against its block ground truth.
fn tally(dir: &Path) -> Tally {
    // The files too large to commit are performance files, not layout cases.
    let large = std::fs::read_to_string(dir.join(".gitignore")).unwrap_or_default();
    let Ok(entries) = std::fs::read_dir(dir) else {
        return Tally::default();
    };
    let mut names: Vec<String> = entries
        .filter_map(|entry| {
            let name = entry.unwrap().file_name().into_string().unwrap();
            name.strip_suffix(".blocks.json").map(str::to_owned)
        })
        // lopdf sees two of `disagree-pages`'s three pages, which is what that file tests (G102).
        .filter(|name| {
            name != "disagree-pages"
                && !large.lines().any(|line| line == format!("{name}.pdf"))
                && dir.join(format!("{name}.pdf")).exists()
        })
        .collect();
    names.sort();
    let only = std::env::var("FERMAN_LAYOUT_ONLY").ok();
    let mut tally = Tally::default();
    for name in &names {
        if only.as_deref().is_some_and(|only| only != name) {
            continue;
        }
        let bytes = std::fs::read(dir.join(format!("{name}.pdf"))).unwrap();
        let truth: Value = serde_json::from_str(
            &std::fs::read_to_string(dir.join(format!("{name}.blocks.json"))).unwrap(),
        )
        .unwrap();
        let password = PASSWORDS
            .iter()
            .find(|(file, _)| file == name)
            .map(|(_, password)| Password::new((*password).to_owned()));
        let options = OpenOptions {
            password,
            ..OpenOptions::default()
        };
        let document = open(&Source::from_bytes(Arc::from(&bytes[..])), &options).unwrap();
        let pages = truth["pages"].as_array().unwrap();
        assert_eq!(document.page_count(), pages.len(), "{name}");
        for (index, want) in pages.iter().enumerate() {
            let page = index + 1;
            let model = text_page(&document, index, &EditContext::default()).unwrap();
            let structure = &document.structure().pages[index];
            let blocks = want["blocks"].as_array().unwrap();
            if want["empty"] == "image" {
                if !model.blocks.is_empty() || model.empty != Some(NotEditableReason::ImageOnly) {
                    tally
                        .failures
                        .push(format!("{name} page {page}: not an image-only page"));
                }
                continue;
            }
            tally.blocks += blocks.len();
            if model.blocks.len() != blocks.len() {
                let got: Vec<String> = model
                    .blocks
                    .iter()
                    .map(|b| b.lines.first().map(|l| l.text.clone()).unwrap_or_default())
                    .collect();
                let wanted: Vec<&str> = blocks
                    .iter()
                    .map(|b| b["lines"][0]["text"].as_str().unwrap_or_default())
                    .collect();
                tally.failures.push(format!(
                    "{name} page {page}: {} blocks, {} expected\n  got {got:?}\n  want {wanted:?}",
                    model.blocks.len(),
                    blocks.len()
                ));
                continue;
            }
            for (at, (got, want)) in model.blocks.iter().zip(blocks).enumerate() {
                let lines = want["lines"].as_array().unwrap();
                let head = lines[0]["text"].as_str().unwrap_or_default();
                let mut problems = Vec::new();
                if got.alignment != alignment(want["align"].as_str().unwrap()) {
                    problems.push(format!(
                        "alignment {:?}, want {}",
                        got.alignment, want["align"]
                    ));
                }
                if got.justification != justification(&want["justify"]) {
                    problems.push(format!(
                        "justification {:?}, want {}",
                        got.justification, want["justify"]
                    ));
                }
                if got.column != usize::try_from(want["column"].as_u64().unwrap()).unwrap() {
                    problems.push(format!("column {}, want {}", got.column, want["column"]));
                }
                let cell = got.cell.map(|c| vec![c.table, c.row, c.column]);
                let want_cell = want["cell"].as_array().map(|c| {
                    c.iter()
                        .map(|n| usize::try_from(n.as_u64().unwrap()).unwrap())
                        .collect::<Vec<_>>()
                });
                if cell != want_cell {
                    problems.push(format!("cell {cell:?}, want {want_cell:?}"));
                }
                if got.lines.len() != lines.len() {
                    problems.push(format!("{} lines, want {}", got.lines.len(), lines.len()));
                } else {
                    for (n, (line, want)) in got.lines.iter().zip(lines).enumerate() {
                        let text = want["text"].as_str().unwrap();
                        if squeeze(&line.text) != squeeze(text) {
                            problems.push(format!("line {n}: «{}», want «{text}»", line.text));
                        }
                        #[allow(clippy::cast_possible_truncation)]
                        let tol = want["size"].as_f64().unwrap() as f32 * 0.15;
                        let ends = if KNOWN_WIDTHS.contains(&name.as_str()) {
                            1
                        } else {
                            2
                        };
                        for (got, want) in line
                            .baseline
                            .iter()
                            .zip([&want["start"], &want["end"]])
                            .take(ends)
                        {
                            let (x, y) = point(want);
                            let (x, y) = structure.display_point(x, y);
                            if (got[0] - x).abs() > tol || (got[1] - y).abs() > tol {
                                problems.push(format!(
                                    "line {n}: baseline point {got:?}, want [{x}, {y}]"
                                ));
                            }
                        }
                    }
                }
                if problems.is_empty() {
                    tally.matched += 1;
                } else {
                    tally.failures.push(format!(
                        "{name} page {page} block {at} «{head}»: {}",
                        problems.join("; ")
                    ));
                }
            }
            tally.pages += 1;
        }
    }
    tally
}

fn corpus_dir(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus")
        .join(name)
}

#[test]
fn every_generated_file_lays_out_as_its_generator_drew_it() {
    let files = std::fs::read_dir(corpus_dir("generated"))
        .unwrap()
        .filter(|entry| {
            let entry = entry.as_ref().unwrap();
            entry
                .file_name()
                .to_string_lossy()
                .ends_with(".blocks.json")
        })
        .count();
    assert!(files >= 30, "{files} files with ground truth");
    let tally = tally(&corpus_dir("generated"));
    assert!(tally.pages >= 30, "{} pages", tally.pages);
    assert!(
        tally.failures.is_empty(),
        "{} failures ({} pages matched):\n{}",
        tally.failures.len(),
        tally.pages,
        tally.failures.join("\n")
    );
}

#[test]
#[ignore = "needs tests/corpus/real-world, which waits for the owner's files"]
fn at_least_95_percent_of_the_corpus_blocks_match_their_ground_truth() {
    let (generated, real) = (
        tally(&corpus_dir("generated")),
        tally(&corpus_dir("real-world")),
    );
    let blocks = generated.blocks + real.blocks;
    let matched = generated.matched + real.matched;
    assert!(blocks > 0);
    assert!(
        matched * 100 >= blocks * 95,
        "{matched} of {blocks} blocks match:\n{}\n{}",
        generated.failures.join("\n"),
        real.failures.join("\n")
    );
}

/// A generated file, opened.
fn generated(name: &str) -> ferman_core::Document {
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
fn every_glyph_links_to_its_show_and_ids_are_stable() {
    use ferman_core::interpret::SpanSource;
    let document = generated("edit-e22-split-contents");
    let model = text_page(&document, 0, &EditContext::default()).unwrap();
    let again = text_page(&document, 0, &EditContext::default()).unwrap();
    let ids: Vec<_> = model.blocks.iter().map(|block| block.id).collect();
    assert_eq!(
        ids,
        again
            .blocks
            .iter()
            .map(|block| block.id)
            .collect::<Vec<_>>()
    );
    // The paragraph's lines come from both streams of the split `/Contents`.
    let mut streams = Vec::new();
    for c in model
        .blocks
        .iter()
        .flat_map(|b| &b.lines)
        .flat_map(|l| &l.chars)
    {
        if let Some(link) = &c.glyph {
            assert!(link.span.range.start < link.span.range.end);
            if let SpanSource::Page { stream } = link.span.source
                && !streams.contains(&stream)
            {
                streams.push(stream);
            }
        } else {
            assert!(c.ch.is_whitespace(), "{:?} has no glyph", c.ch);
        }
    }
    assert_eq!(streams.len(), 2, "{streams:?}");

    // A form placed twice: the same operators, two blocks with ids of their own.
    let form = text_page(
        &generated("edit-e20-form-twice"),
        0,
        &EditContext::default(),
    )
    .unwrap();
    let stamps: Vec<_> = form
        .blocks
        .iter()
        .filter(|block| block.text() == "TESLİM ALINDI")
        .collect();
    assert_eq!(stamps.len(), 2);
    assert_ne!(stamps[0].id, stamps[1].id);
    assert_eq!(
        stamps[0].lines[0].chars[0].glyph,
        stamps[1].lines[0].chars[0].glyph
    );
}

#[test]
fn a_click_finds_its_caret_and_a_selection_its_text() {
    let document = generated("kira-tr");
    let model = text_page(&document, 0, &EditContext::default()).unwrap();
    let block = model
        .blocks
        .iter()
        .find(|block| block.lines.len() > 2)
        .unwrap();
    let line = &block.lines[1];
    let start = block.lines[0].chars.len() + 1;
    // The middle of the line's fourth character's left half is before it.
    let [left, top, right, bottom] = line.chars[3].bbox.unwrap();
    let index = block.hit([left + (right - left) / 4.0, (top + bottom) / 2.0]);
    assert_eq!(index, start + 3);
    let caret = block.caret_rect(index).unwrap();
    assert!((caret[0] - left).abs() < 0.01, "{caret:?} {left}");
    let all = 0..block.text().chars().count();
    assert_eq!(block.selected_text(all.clone()), block.text());
    assert_eq!(block.selection_quads(all).len(), block.lines.len());
    let stops = block.caret_stops();
    assert_eq!(stops.first().map(|stop| stop.index), Some(0));
    assert_eq!(
        stops.last().map(|stop| stop.index),
        Some(block.text().chars().count())
    );
}

#[test]
fn the_document_and_its_fields_make_blocks_not_editable() {
    let document = generated("kira-tr");
    let restricted = EditContext {
        document: Some(NotEditableReason::Restricted),
        ..EditContext::default()
    };
    let model = text_page(&document, 0, &restricted).unwrap();
    assert!(model.blocks.iter().all(|block| block.editability
        == ferman_text::Editability::NotEditable(NotEditableReason::Restricted)));
    let page = text_page(&document, 2, &EditContext::default()).unwrap();
    assert!(
        page.blocks
            .iter()
            .all(|block| block.editability.is_editable())
    );
    let label = page
        .blocks
        .iter()
        .find(|block| block.text() == "İmza")
        .unwrap();
    let signed = EditContext {
        signature_areas: vec![label.bbox],
        ..EditContext::default()
    };
    let page = text_page(&document, 2, &signed).unwrap();
    let label = page
        .blocks
        .iter()
        .find(|block| block.text() == "İmza")
        .unwrap();
    assert_eq!(
        label.editability,
        ferman_text::Editability::NotEditable(NotEditableReason::SignatureAppearance)
    );
}
