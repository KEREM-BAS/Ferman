//! Text back to codes, what a rewrite re-encodes with (`ferman_fonts`): a simple encoding with
//! `/Differences` and a CMap from arbitrary bytes. A code found for a text or CID must read back
//! as that text or CID, or an edit would draw something else than the user typed.
#![no_main]

use ferman_fonts::{BaseEncoding, CMap, SimpleEncoding, glyph_names, glyph_text};
use libfuzzer_sys::fuzz_target;

/// Enough to walk a long string without timing out on large CMaps.
const MAX_CODES: usize = 256;

fn simple(input: &[u8]) {
    let base = input.first().and_then(|byte| match byte % 4 {
        0 => BaseEncoding::from_name(b"WinAnsiEncoding"),
        1 => BaseEncoding::from_name(b"MacRomanEncoding"),
        2 => BaseEncoding::from_name(b"StandardEncoding"),
        _ => None,
    });
    let _ = BaseEncoding::from_name(input);
    // Space-separated `/Differences`: a code byte, then a glyph name.
    let differences = input.split(|&byte| byte == b' ').filter_map(|part| {
        let (&code, name) = part.split_first()?;
        Some((code, std::str::from_utf8(name).ok()?))
    });
    let encoding = SimpleEncoding::new(base, differences);
    for code in 0..=u8::MAX {
        let Some(text) = encoding.text(code) else {
            continue;
        };
        if let Some(found) = encoding.code_for_text(text) {
            assert_eq!(encoding.text(found), Some(text), "code {found}");
        }
    }
    if let Ok(name) = std::str::from_utf8(input) {
        let _ = glyph_text(name);
        for c in name.chars().take(MAX_CODES) {
            let _ = glyph_names(c);
        }
    }
}

fn composite(input: &[u8]) {
    let _ = CMap::predefined(input);
    // The second half is the first's `usecmap` parent, so the two meet as a chain does.
    let (child, parent) = input.split_at(input.len() / 2);
    let mut cmap = CMap::parse(child);
    cmap.inherit(&CMap::parse(parent));
    for (code, length) in cmap.codes(input).take(MAX_CODES) {
        if let Some(cid) = cmap.cid(code, length)
            && let Some((found, size)) = cmap.code_for_cid(cid)
        {
            assert_eq!(cmap.cid(found, size), Some(cid), "code {found}");
        }
        if let Some(text) = cmap.text(code)
            && let Some((found, _)) = cmap.code_for_text(&text)
        {
            assert_eq!(cmap.text(found).as_ref(), Some(&text), "code {found}");
        }
    }
}

fuzz_target!(|input: &[u8]| {
    simple(input);
    composite(input);
});
