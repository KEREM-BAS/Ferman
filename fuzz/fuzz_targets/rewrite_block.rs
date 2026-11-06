//! Re-encoding through the whole rewrite (`ferman_text`): a one-page file built here with arbitrary
//! shown bytes, ToUnicode, encoding choice and font program, and arbitrary new text for each of its
//! blocks. The splices must stay inside the page's content, in order and apart.
//!
//! `input`: flags, three lengths (new text, shown bytes, CMap), those parts, then the font program.
//! Flags: bit 0 composite, bit 1 with ToUnicode, bits 2-3 the encoding, bits 4-5 the program's key,
//! bit 6 reflow rather than line by line.
#![no_main]

use std::sync::Arc;

use ferman_core::{OpenOptions, Source, open};
use ferman_text::{EditContext, Outcome, TextError, rewrite_block_with, text_page};
use libfuzzer_sys::fuzz_target;

fn stream(dict: &str, data: &[u8]) -> Vec<u8> {
    let mut out = format!("<<{dict} /Length {} >>\nstream\n", data.len()).into_bytes();
    out.extend_from_slice(data);
    out.extend_from_slice(b"\nendstream");
    out
}

fn font(flags: u8, program: &[u8]) -> String {
    let to_unicode = if flags & 2 != 0 {
        " /ToUnicode 6 0 R"
    } else {
        ""
    };
    if flags & 1 != 0 {
        let encoding = match (flags >> 2) & 3 {
            0 => "/Identity-H",
            1 => "/Identity-V",
            2 => "/UniGB-UTF16-H",
            _ => "6 0 R",
        };
        return format!(
            "<< /Type /Font /Subtype /Type0 /BaseFont /Fuzz /Encoding {encoding} \
/DescendantFonts [9 0 R]{to_unicode} >>"
        );
    }
    let descriptor = if program.is_empty() {
        ""
    } else {
        " /FontDescriptor 7 0 R"
    };
    let base = match (flags >> 2) & 3 {
        0 => "WinAnsiEncoding",
        1 => "MacRomanEncoding",
        2 => "StandardEncoding",
        _ => "PDFDocEncoding",
    };
    format!(
        "<< /Type /Font /Subtype /TrueType /BaseFont /Helvetica{descriptor}{to_unicode} \
/Encoding << /BaseEncoding /{base} \
/Differences [128 /Scedilla /gbreve /idotless /afii57409 /uni4E2D /g7] >> >>"
    )
}

/// The file, with a correct cross-reference table so the repair path stays out of the way.
fn pdf(flags: u8, content: &[u8], cmap: &[u8], program: &[u8]) -> Vec<u8> {
    let (key, subtype) = match (flags >> 4) & 3 {
        0 => ("FontFile2", ""),
        1 => ("FontFile", ""),
        2 if flags & 1 != 0 => ("FontFile3", " /Subtype /CIDFontType0C"),
        2 => ("FontFile3", " /Subtype /Type1C"),
        _ => ("FontFile3", " /Subtype /OpenType"),
    };
    let descriptor = if program.is_empty() {
        ""
    } else {
        " /FontDescriptor 7 0 R"
    };
    let objects: [Vec<u8>; 9] = [
        b"<< /Type /Catalog /Pages 2 0 R >>".to_vec(),
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>".to_vec(),
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R \
/Resources << /Font << /F1 5 0 R >> >> >>"
            .to_vec(),
        stream("", content),
        font(flags, program).into_bytes(),
        stream("", cmap),
        format!("<< /Type /FontDescriptor /FontName /Fuzz /Flags 4 /{key} 8 0 R >>").into_bytes(),
        stream(subtype, program),
        format!(
            "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Fuzz /DW 500{descriptor} \
/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> >>"
        )
        .into_bytes(),
    ];
    let mut out = b"%PDF-1.7\n".to_vec();
    let mut xref = String::from("0000000000 65535 f \n");
    for (index, object) in objects.iter().enumerate() {
        xref.push_str(&format!("{:010} 00000 n \n", out.len()));
        out.extend(format!("{} 0 obj\n", index + 1).bytes());
        out.extend_from_slice(object);
        out.extend_from_slice(b"\nendobj\n");
    }
    let start = out.len();
    out.extend(
        format!(
            "xref\n0 10\n{xref}trailer\n<< /Size 10 /Root 1 0 R >>\nstartxref\n{start}\n%%EOF\n"
        )
        .bytes(),
    );
    out
}

fuzz_target!(|input: &[u8]| {
    let Some((&[flags, text, show, cmap], rest)) = input.split_first_chunk::<4>() else {
        return;
    };
    let Some((text, rest)) = rest.split_at_checked(usize::from(text)) else {
        return;
    };
    let Some((show, rest)) = rest.split_at_checked(usize::from(show)) else {
        return;
    };
    let Some((cmap, program)) = rest.split_at_checked(usize::from(cmap)) else {
        return;
    };
    let text = String::from_utf8_lossy(text);
    let hex = |bytes: &[u8]| -> String { bytes.iter().map(|b| format!("{b:02X}")).collect() };
    let (first, second) = show.split_at(show.len() / 2);
    let content = format!(
        "BT /F1 12 Tf 72 700 Td 14 TL <{}> Tj T* <{}> Tj ET",
        hex(first),
        hex(second)
    )
    .into_bytes();
    let file = pdf(flags, &content, cmap, program);
    let options = OpenOptions {
        limits: ferman_core::fuzzing::limits(),
        ..OpenOptions::default()
    };
    let Ok(document) = open(&Source::from_bytes(Arc::from(file)), &options) else {
        return;
    };
    let internal = |err: &TextError| matches!(err, TextError::Internal { .. });
    let page = match text_page(&document, 0, &EditContext::default()) {
        Ok(page) => page,
        Err(err) => {
            assert!(!internal(&err), "text_page: {err}");
            return;
        }
    };
    for block in &page.blocks {
        let lines = vec![text.as_ref(); block.lines.len()].join("\n");
        let new = if flags & 0x40 != 0 {
            text.as_ref()
        } else {
            lines.as_str()
        };
        match rewrite_block_with(&document, None, 0, block, new, &page.blocks, None) {
            Ok(Outcome::Rewritten(rewrite)) => {
                let mut ranges: Vec<_> = rewrite.splices.iter().map(|s| s.range.clone()).collect();
                ranges.sort_by_key(|range| range.start);
                assert!(
                    ranges
                        .iter()
                        .all(|range| range.start <= range.end && range.end <= content.len()),
                    "{ranges:?}"
                );
                assert!(
                    ranges.windows(2).all(|pair| pair[0].end <= pair[1].start),
                    "{ranges:?}"
                );
            }
            Ok(_) => {}
            Err(err) => assert!(!internal(&err), "rewrite_block: {err}"),
        }
    }
});
