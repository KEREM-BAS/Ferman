//! Subsetting (`ferman_fonts::subset`): a damaged font and arbitrary glyphs with their text. A
//! subset has `.notdef` first, every glyph asked for, and new ids in order without a gap.
#![no_main]

use ferman_fonts::{GlyphId, subset};
use ferman_fuzz::{font_case, text_from};
use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    let Some((font, rest)) = font_case(input) else {
        return;
    };
    let glyphs: Vec<(GlyphId, String)> = rest
        .as_chunks::<4>()
        .0
        .iter()
        .map(|chunk| {
            // Nine bits: the base font has that many glyphs, and one past the end refuses the lot.
            let id = u16::from_be_bytes([chunk[0] & 1, chunk[1]]);
            (GlyphId(u32::from(id)), text_from(&chunk[2..]))
        })
        .collect();
    let Ok(result) = subset(&font, 0, &glyphs) else {
        return;
    };
    assert_eq!(
        result.glyphs.first().map(|glyph| glyph.old),
        Some(GlyphId(0))
    );
    for (at, glyph) in result.glyphs.iter().enumerate() {
        assert_eq!(usize::from(glyph.new), at, "new ids in order");
    }
    for (old, _) in &glyphs {
        assert!(result.new_glyph(*old).is_some(), "{old:?} dropped");
    }
});
