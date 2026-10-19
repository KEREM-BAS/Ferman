//! The PDFium oracle (ADR 0020): PDFium, a reader independent of lopdf, opens every generated
//! file as its generator says. A file that opens has one page per page of its expected text
//! and that text, compared without whitespace (PDFium inserts its own spaces and line breaks).
//! An encrypted file does not open without its password. A file that should not open, does
//! not.
//!
//! Needs PDFium: `tools/pdfium/fetch.sh`, then `FERMAN_PDFIUM_PATH` with the library's absolute
//! path. `FERMAN_CORPUS_ONLY=<name>` limits the run to one generator.
#![allow(clippy::unwrap_used, clippy::expect_used)]

use ferman_corpus::sources::Sources;
use ferman_corpus::{Expect, GENERATORS};
use pdfium_render::prelude::*;
use std::path::Path;

/// `text` without whitespace.
fn squeeze(text: &str) -> String {
    text.chars().filter(|c| !c.is_whitespace()).collect()
}

/// Where two texts first differ, with some context.
fn difference(got: &str, expected: &str) -> String {
    let got: Vec<char> = got.chars().collect();
    let expected: Vec<char> = expected.chars().collect();
    let at = got
        .iter()
        .zip(&expected)
        .position(|(a, b)| a != b)
        .unwrap_or(got.len().min(expected.len()));
    let start = at.saturating_sub(20);
    let context = |chars: &[char]| chars.iter().skip(start).take(60).collect::<String>();
    format!(
        "at character {at}: PDFium reads {:?}, the text says {:?}",
        context(&got),
        context(&expected)
    )
}

fn check(pdfium: &Pdfium, expect: Expect, pdf: &[u8], text: &str) -> Result<(), String> {
    let password = match expect {
        Expect::Fails => {
            return match pdfium.load_pdf_from_byte_slice(pdf, None) {
                Ok(_) => Err("PDFium opens it".to_owned()),
                Err(_) => Ok(()),
            };
        }
        Expect::Opens { password } => password,
    };
    if password.is_some() && pdfium.load_pdf_from_byte_slice(pdf, None).is_ok() {
        return Err("it opens without its password".to_owned());
    }
    let document = pdfium
        .load_pdf_from_byte_slice(pdf, password)
        .map_err(|err| format!("PDFium cannot open it: {err}"))?;
    let expected: Vec<&str> = text.split('\u{c}').collect();
    let pages = document.pages();
    let count = usize::try_from(pages.len()).unwrap_or(0);
    if count != expected.len() {
        return Err(format!(
            "PDFium finds {count} pages, the expected text has {}",
            expected.len()
        ));
    }
    for (index, page) in pages.iter().enumerate() {
        let got = page
            .text()
            .map_err(|err| format!("page {}: no text: {err}", index + 1))?
            .all();
        let (got, want) = (squeeze(&got), squeeze(expected[index]));
        if got != want {
            return Err(format!("page {}: {}", index + 1, difference(&got, &want)));
        }
    }
    Ok(())
}

#[test]
#[ignore = "needs PDFium: set FERMAN_PDFIUM_PATH (tools/pdfium/fetch.sh)"]
fn pdfium_reads_every_generated_file_as_its_generator_says() {
    let path = std::env::var("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH names PDFium");
    let pdfium = Pdfium::new(Pdfium::bind_to_library(&path).expect("PDFium binds"));
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let sources = Sources::new(&root);
    let only = std::env::var("FERMAN_CORPUS_ONLY").ok();
    let mut failures = Vec::new();
    let mut checked = 0;
    for generator in GENERATORS {
        if only.as_deref().is_some_and(|name| name != generator.name) {
            continue;
        }
        let [(_, pdf), (_, text)] = generator.outputs(&sources).expect("the generator runs");
        let text = String::from_utf8(text).expect("the expected text is UTF-8");
        if let Err(problem) = check(&pdfium, generator.expect, &pdf, &text) {
            failures.push(format!("{}: {problem}", generator.name));
        }
        checked += 1;
    }
    assert!(checked > 0, "no generator named {only:?}");
    assert!(failures.is_empty(), "\n{}", failures.join("\n"));
}
