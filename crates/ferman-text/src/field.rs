//! A form field's font, as text is written in it (M4 plan, decision 18): the codes of a simple font
//! that draw a character and read back as it, and their widths. A composite font offers none: a
//! field's text in one goes through the bundled fonts, which say so.

use std::collections::HashMap;

use ferman_core::interpret::FontResource;
use ferman_core::structure::FontKind;

use crate::extract::PdfFont;
use crate::rewrite::encode;

/// A simple font's codes by the character each draws.
#[derive(Debug, Clone, Default)]
pub struct FieldFont {
    codes: HashMap<char, (u8, f32)>,
}

impl FieldFont {
    /// What `resource` can draw; nothing for a composite or Type3 font.
    #[must_use]
    pub fn new(resource: &FontResource) -> Self {
        if matches!(resource.kind, FontKind::Type0 | FontKind::Type3) {
            return Self::default();
        }
        let font = PdfFont::new(resource);
        let program = font.program();
        let mut codes = HashMap::new();
        for code in 0..=u8::MAX {
            if let Some(c) = crate::extract::single(&font.text(u32::from(code)))
                && encode(&font, program.as_ref(), c) == Some(code)
            {
                codes.insert(c, (code, font.width(u32::from(code), 1)));
            }
        }
        Self { codes }
    }

    /// The code that draws `c` and its advance per unit of font size.
    #[must_use]
    pub fn code(&self, c: char) -> Option<(u8, f32)> {
        self.codes.get(&c).copied()
    }
}
