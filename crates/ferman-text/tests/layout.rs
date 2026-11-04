//! The text model against the generators' ground truth (ROADMAP §7 step 1): for every generated
//! file with a `<name>.blocks.json`, every page's blocks in reading order, their lines (text and
//! baseline), alignment, justification method, column and table cell match what `tools/corpus` drew, 100%.
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;
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

/// Pages whose text extraction is known to differ (BACKLOG B112, as in `corpus.rs`): their
/// lines' text is not compared.
const KNOWN_TEXT: [(&str, usize); 4] = [
    ("report-ar", 7),
    ("report-ar", 8),
    ("report-ar", 9),
    ("report-ar", 10),
];

/// Files whose glyph widths the engine does not know yet (BACKLOG: the standard 14 fonts'
/// metrics), so only where their lines start is compared.
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

#[test]
fn every_generated_file_lays_out_as_its_generator_drew_it() {
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/corpus/generated");
    // The files too large to commit are performance files, not layout cases.
    let large = std::fs::read_to_string(dir.join(".gitignore")).unwrap();
    let mut names: Vec<String> = std::fs::read_dir(&dir)
        .unwrap()
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
    assert!(names.len() >= 30, "{names:?}");
    let only = std::env::var("FERMAN_LAYOUT_ONLY").ok();
    let mut failures = Vec::new();
    let mut checked = 0_usize;
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
                    failures.push(format!("{name} page {page}: not an image-only page"));
                }
                continue;
            }
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
                failures.push(format!(
                    "{name} page {page}: {} blocks, {} expected\n  got {got:?}\n  want {wanted:?}",
                    model.blocks.len(),
                    blocks.len()
                ));
                continue;
            }
            let known = KNOWN_TEXT.contains(&(name.as_str(), page));
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
                        if !known && squeeze(&line.text) != squeeze(text) {
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
                if !problems.is_empty() {
                    failures.push(format!(
                        "{name} page {page} block {at} «{head}»: {}",
                        problems.join("; ")
                    ));
                }
            }
            checked += 1;
        }
    }
    assert!(
        failures.is_empty(),
        "{} failures ({checked} pages matched):\n{}",
        failures.len(),
        failures.join("\n")
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
