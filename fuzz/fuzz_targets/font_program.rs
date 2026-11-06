//! Font programs from arbitrary bytes, every way an edit reads one: `FontProgram`'s metrics and
//! glyph lookups (sfnt, bare CFF, Type1), the built-in encoding, shaping and subsetting. The font
//! comes from `font_case`, so it gets past the table directory without a seed; CI adds `seeds/fonts`
//! for CFF.
#![no_main]

use ferman_fonts::{
    Direction, Embedding, FontProgram, GlyphId, ShapeRequest, ShapingFont, StyleMetrics,
    SubsetProgram, builtin_encoding, subset,
};
use ferman_fuzz::font_case;
use libfuzzer_sys::fuzz_target;

/// The characters an edit asks for most: Latin, Turkish, Arabic and CJK.
const TEXTS: [(&str, Direction); 3] = [
    ("Aİğ fi", Direction::LeftToRight),
    ("سلام", Direction::RightToLeft),
    ("字", Direction::TopToBottom),
];

fuzz_target!(|input: &[u8]| {
    let Some((font, _)) = font_case(input) else {
        return;
    };
    let data = font.as_slice();
    let _ = builtin_encoding(data);
    let _ = (Embedding::of(data, 0), StyleMetrics::of(data, 0));
    let Ok(font) = FontProgram::parse(data) else {
        return;
    };
    let _ = (font.units_per_em(), font.ascent_descent(), font.fs_type());
    let _ = (
        font.postscript_name(),
        font.family_name(),
        font.style_name(),
    );
    for (text, _) in TEXTS {
        for c in text.chars() {
            let _ = font.glyph_for_char(c);
        }
    }
    let mut glyphs = Vec::new();
    for id in 0..font.glyph_count().min(32) {
        let glyph = GlyphId(id);
        let _ = font.advance_width(glyph);
        if let Some(cid) = font.cid_for_glyph(glyph) {
            let _ = font.glyph_for_cid(cid);
        }
        if let Some(name) = font.glyph_name(glyph) {
            let _ = font.glyph_for_name(&name);
        }
        glyphs.push((glyph, "x".to_owned()));
    }

    if let Ok(shaper) = ShapingFont::new(data.to_vec(), 0) {
        for (text, direction) in TEXTS {
            if let Ok(run) = shaper.shape(&ShapeRequest::new(text, direction)) {
                let _ = (run.missing_clusters(), run.glyph_texts(text));
            }
        }
    }

    if let Ok(result) = subset(data, 0, &glyphs) {
        assert!(
            result.glyphs.first().is_some_and(|glyph| glyph.new == 0),
            "no .notdef first"
        );
        let (SubsetProgram::TrueType(program) | SubsetProgram::Cff(program)) = &result.program;
        // The subset goes into the user's file: the engine must read what it wrote.
        assert!(
            FontProgram::parse(program).is_ok(),
            "a subset that does not parse"
        );
    }
});
