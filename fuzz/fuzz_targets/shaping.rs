//! Shaping (`ferman_fonts::shape`): a damaged font and arbitrary text, in each direction, with and
//! without a script, language and features. Every cluster is a place in the text.
#![no_main]

use ferman_fonts::{Direction, FeatureSetting, ShapeRequest, ShapingFont};
use ferman_fuzz::{font_case, text_from};
use libfuzzer_sys::fuzz_target;

fuzz_target!(|input: &[u8]| {
    let Some((font, rest)) = font_case(input) else {
        return;
    };
    let Some((&control, rest)) = rest.split_first() else {
        return;
    };
    let Ok(font) = ShapingFont::new(font, 0) else {
        return;
    };
    let text = text_from(rest);
    let off = [
        FeatureSetting {
            tag: *b"liga",
            value: 0,
        },
        FeatureSetting {
            tag: *b"kern",
            value: 0,
        },
    ];
    let request = ShapeRequest {
        text: &text,
        direction: match control & 3 {
            1 => Direction::RightToLeft,
            2 => Direction::TopToBottom,
            _ => Direction::LeftToRight,
        },
        script: (control & 4 != 0).then_some(*b"Arab"),
        language: [None, Some("fa"), Some("tr"), Some("ja")][usize::from(control >> 3 & 3)],
        features: if control & 32 != 0 { &off } else { &[] },
    };
    if let Ok(run) = font.shape(&request) {
        for glyph in &run.glyphs {
            assert!(
                text.is_char_boundary(glyph.cluster),
                "cluster {} in {} bytes",
                glyph.cluster,
                text.len()
            );
        }
        let _ = run.missing_clusters();
        assert_eq!(run.glyph_texts(&text).len(), run.glyphs.len());
    }
});
