//! Type1 programs past their encryption (`FontProgram` through read-fonts): a mutated `eexec`
//! section decrypts to noise, so the arbitrary bytes are the plain parts and this target encrypts
//! them. `input`: a flags byte, then parts split on a zero byte: text for the clear header, text
//! for `/Private`, and each glyph's charstring.
#![no_main]

use ferman_fonts::{BuiltinEncoding, FontProgram, GlyphId, builtin_encoding};
use libfuzzer_sys::fuzz_target;

/// Type1 encryption (Adobe Type 1 Font Format §7.1) after four zero bytes.
fn encrypt(plain: &[u8], mut key: u16) -> Vec<u8> {
    let mut out = Vec::with_capacity(plain.len() + 4);
    for &byte in [0; 4].iter().chain(plain) {
        let cipher = byte ^ key.to_be_bytes()[0];
        key = u16::from(cipher)
            .wrapping_add(key)
            .wrapping_mul(52845)
            .wrapping_add(22719);
        out.push(cipher);
    }
    out
}

fn program(pfb: bool, parts: &[&[u8]]) -> Vec<u8> {
    let mut parts = parts.iter().copied();
    let mut clear = b"%!PS-AdobeFont-1.0: Fuzz 001.000\n11 dict begin\n".to_vec();
    clear.extend_from_slice(parts.next().unwrap_or_default());
    clear.extend_from_slice(
        b"\n/FontName /Fuzz def\n/FontBBox {0 -200 1000 800} readonly def\n\
currentdict end\ncurrentfile eexec\n",
    );
    let mut private = b"dup /Private 5 dict dup begin\n\
/RD{string currentfile exch readstring pop}executeonly def\n\
/ND{noaccess def}executeonly def\n/NP{noaccess put}executeonly def\n/lenIV 4 def\n"
        .to_vec();
    private.extend_from_slice(parts.next().unwrap_or_default());
    private.extend_from_slice(b"\n2 index /CharStrings 3 dict dup begin\n");
    for (index, charstring) in parts.enumerate() {
        let name = if index == 0 {
            ".notdef".to_owned()
        } else {
            format!("g{index}")
        };
        let charstring = encrypt(charstring, 4330);
        private.extend(format!("/{name} {} RD ", charstring.len()).bytes());
        private.extend(charstring);
        private.extend_from_slice(b" ND\n");
    }
    private.extend_from_slice(b"end\nend\nreadonly put\nnoaccess put\n");
    let private = encrypt(&private, 55665);
    if !pfb {
        return [clear, private].concat();
    }
    let mut font = Vec::new();
    for (kind, segment) in [(1, &clear), (2, &private)] {
        font.extend([0x80, kind]);
        font.extend(
            u32::try_from(segment.len())
                .unwrap_or_default()
                .to_le_bytes(),
        );
        font.extend_from_slice(segment);
    }
    font.extend([0x80, 3]);
    font
}

fuzz_target!(|input: &[u8]| {
    let Some((&flags, rest)) = input.split_first() else {
        return;
    };
    let parts: Vec<&[u8]> = rest.split(|&byte| byte == 0).collect();
    let data = program(flags & 1 != 0, &parts);
    if let Ok(Some(BuiltinEncoding::Codes(codes))) = builtin_encoding(&data) {
        assert!(
            codes.windows(2).all(|pair| pair[0].0 < pair[1].0),
            "codes out of order"
        );
    }
    let Ok(font) = FontProgram::parse(&data) else {
        return;
    };
    let _ = (font.units_per_em(), font.ascent_descent(), font.fs_type());
    let _ = (
        font.postscript_name(),
        font.family_name(),
        font.style_name(),
    );
    let _ = font.glyph_for_char('A');
    for id in 0..font.glyph_count().min(64) {
        let _ = font.advance_width(GlyphId(id));
    }
    for index in 1..parts.len().min(64) {
        let _ = font.glyph_for_name(&format!("g{index}"));
    }
});
