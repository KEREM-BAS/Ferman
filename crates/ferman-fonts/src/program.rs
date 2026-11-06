//! Embedded font programs (ISO 32000-2 §9.9): TrueType (`/FontFile2`), CFF and OpenType
//! (`/FontFile3` with `/Subtype` `Type1C`, `CIDFontType0C` or `OpenType`) and Type1 (`/FontFile`).
//!
//! TrueType and OpenType go through skrifa, bare CFF and Type1 through read-fonts' PostScript
//! readers (Type1 decrypted, for its `/CharStrings` names and widths); they check every offset, so
//! a damaged program fails with [`FontError`] or reads as missing data, never a panic. The kind is told from the bytes, not from the PDF's subtype, which documents get wrong.
//! Values are in font units, at the default instance of a variable font.
//!
//! A bare CFF or Type1 program has no cmap, so [`FontProgram::glyph_for_char`] finds nothing in
//! it: its glyphs are reached by name ([`FontProgram::glyph_for_name`]) or, in a CID-keyed program,
//! by CID through the caller's CMap. A Type1 program's built-in encoding stays with
//! [`crate::type1`]; a Type1 glyph id is the program's own order with `.notdef` moved to 0.
// A parser module: the program comes from a file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::sync::Arc;

use read_fonts::ps::cff::CffFontRef;
use read_fonts::ps::string::Sid;
use read_fonts::ps::type1::Type1Font;
use skrifa::instance::{LocationRef, Size};
use skrifa::raw::TableProvider;
use skrifa::string::StringId;
use skrifa::{FontRef, MetadataProvider};

use crate::FontError;
use crate::type1::MAX_PROGRAM;

/// A glyph of a font program, by its index.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct GlyphId(pub u32);

/// A parsed embedded font program, borrowing its bytes.
#[derive(Clone)]
pub struct FontProgram<'a> {
    repr: Repr<'a>,
}

#[derive(Clone)]
enum Repr<'a> {
    /// TrueType, or OpenType with `glyf`, `CFF ` or `CFF2` outlines.
    Sfnt(FontRef<'a>),
    /// A bare CFF program, name-keyed or CID-keyed.
    Cff(CffFontRef<'a>),
    /// A Type1 program, PFA or PFB; decrypted, so owned.
    Type1(Arc<Type1Font>),
}

impl std::fmt::Debug for FontProgram<'_> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let kind = match self.repr {
            Repr::Sfnt(_) => "sfnt",
            Repr::Cff(_) => "cff",
            Repr::Type1(_) => "type1",
        };
        f.debug_struct("FontProgram")
            .field("kind", &kind)
            .field("glyphs", &self.glyph_count())
            .finish()
    }
}

impl<'a> FontProgram<'a> {
    /// Reads the program in `data`: an sfnt (TrueType or OpenType), a bare CFF font or a Type1
    /// font.
    ///
    /// # Errors
    ///
    /// [`FontError::ProgramTooLarge`] for a program over [`MAX_PROGRAM`], and
    /// [`FontError::Malformed`] for bytes that are neither, or a CFF font matrix whose units per
    /// em do not fit.
    pub fn parse(data: &'a [u8]) -> Result<Self, FontError> {
        if data.len() > MAX_PROGRAM {
            return Err(FontError::ProgramTooLarge {
                size: u64::try_from(data.len()).unwrap_or(u64::MAX),
                max: u64::try_from(MAX_PROGRAM).unwrap_or(u64::MAX),
            });
        }
        let repr = if let Ok(font) = FontRef::new(data) {
            Repr::Sfnt(font)
        } else if data.starts_with(b"%!") || data.starts_with(&[0x80, 0x01]) {
            let font = Type1Font::new(data).map_err(|_| FontError::Malformed {
                context: "Type1 program",
            })?;
            if u16::try_from(font.upem()).map_or(true, |upem| upem == 0) {
                return Err(FontError::Malformed {
                    context: "Type1 font matrix",
                });
            }
            Repr::Type1(Arc::new(font))
        } else {
            // CFF2 lives only inside OpenType; a bare program is CFF version 1.
            let cff = CffFontRef::new_cff(data, 0, None).map_err(|_| FontError::Malformed {
                context: "font program",
            })?;
            if u16::try_from(cff.upem()).map_or(true, |upem| upem == 0) {
                return Err(FontError::Malformed {
                    context: "CFF font matrix",
                });
            }
            Repr::Cff(cff)
        };
        Ok(Self { repr })
    }

    /// The units per em: `head` for an sfnt, the font matrix for CFF and Type1 (1000 without
    /// one). 0 for an sfnt without `head`.
    #[must_use]
    pub fn units_per_em(&self) -> u16 {
        match &self.repr {
            Repr::Sfnt(font) => font.head().map_or(0, |head| head.units_per_em()),
            Repr::Cff(cff) => u16::try_from(cff.upem()).unwrap_or(0),
            Repr::Type1(font) => u16::try_from(font.upem()).unwrap_or(0),
        }
    }

    /// The ascent and descent (negative below the baseline): an sfnt's `hhea` or `OS/2` line, as
    /// FreeType chooses it, else its `head` bounding box; a CFF or Type1 program's `FontBBox`.
    #[must_use]
    pub fn ascent_descent(&self) -> (f32, f32) {
        match &self.repr {
            Repr::Sfnt(font) => {
                let metrics = font.metrics(Size::unscaled(), LocationRef::default());
                match metrics.bounds {
                    Some(bounds) if metrics.ascent == 0.0 && metrics.descent == 0.0 => {
                        (bounds.y_max, bounds.y_min)
                    }
                    _ => (metrics.ascent, metrics.descent),
                }
            }
            Repr::Cff(cff) => cff.metadata().map_or((0.0, 0.0), |meta| {
                let bbox = meta.bbox();
                (bbox.y_max.to_f32(), bbox.y_min.to_f32())
            }),
            Repr::Type1(font) => {
                let bbox = font.bbox();
                (bbox.y_max.to_f32(), bbox.y_min.to_f32())
            }
        }
    }

    /// The number of glyphs: `maxp` for an sfnt, the CharStrings for CFF and Type1.
    #[must_use]
    pub fn glyph_count(&self) -> u32 {
        match &self.repr {
            Repr::Sfnt(font) => font.maxp().map_or(0, |maxp| u32::from(maxp.num_glyphs())),
            Repr::Cff(cff) => cff.num_glyphs(),
            Repr::Type1(font) => font.num_glyphs(),
        }
    }

    /// The glyph the program's cmap gives `c`. A symbol cmap (3,0) also maps U+0000 to U+00FF
    /// through U+F000 to U+F0FF, as Windows does. A bare CFF or Type1 program has no cmap.
    #[must_use]
    pub fn glyph_for_char(&self, c: char) -> Option<GlyphId> {
        match &self.repr {
            Repr::Sfnt(font) => font.charmap().map(c).map(|gid| GlyphId(gid.to_u32())),
            Repr::Cff(_) | Repr::Type1(_) => None,
        }
    }

    /// The glyph named `name`: from `post` (or the `CFF ` table) of an sfnt, from the charset of
    /// a name-keyed CFF program, from the `/CharStrings` of Type1. Names a program does not store (`gid12`) find nothing, nor does a
    /// CID-keyed CFF program, whose charset holds CIDs.
    #[must_use]
    pub fn glyph_for_name(&self, name: &str) -> Option<GlyphId> {
        match &self.repr {
            Repr::Sfnt(font) => font
                .glyph_names()
                .iter()
                .find(|(_, glyph)| !glyph.is_synthesized() && glyph.as_str() == name)
                .map(|(gid, _)| GlyphId(gid.to_u32())),
            Repr::Cff(cff) if !cff.is_cid() => cff
                .charset()?
                .iter()
                .find(|&(_, sid)| cff.string(sid) == Some(name.as_bytes()))
                .map(|(gid, _)| GlyphId(gid.to_u32())),
            Repr::Cff(_) => None,
            Repr::Type1(font) => font
                .glyph_names()
                .find(|&(_, glyph)| glyph == name)
                .map(|(gid, _)| GlyphId(gid.to_u32())),
        }
    }

    /// The name of `glyph` that an sfnt's `post` (or `CFF `) table stores, the inverse of
    /// [`glyph_for_name`](Self::glyph_for_name): how a shaped glyph of an installed font is found
    /// in a subset of it. `None` for a name the program does not store, and for bare CFF and Type1
    /// programs.
    #[must_use]
    pub fn glyph_name(&self, glyph: GlyphId) -> Option<String> {
        match &self.repr {
            Repr::Sfnt(font) => font
                .glyph_names()
                .get(skrifa::GlyphId::new(glyph.0))
                .filter(|name| !name.is_synthesized())
                .map(|name| name.as_str().to_owned()),
            Repr::Cff(_) | Repr::Type1(_) => None,
        }
    }

    /// The glyph of CID `cid` in a CID-keyed CFF program, through its charset; in any other
    /// program the CID is the glyph's index (a TrueType program's `/CIDToGIDMap` is the
    /// caller's). `None` past the program's glyphs.
    #[must_use]
    pub fn glyph_for_cid(&self, cid: u32) -> Option<GlyphId> {
        let glyph = match &self.repr {
            Repr::Cff(cff) if cff.is_cid() => GlyphId(
                cff.charset()?
                    .glyph_id(Sid::new(u16::try_from(cid).ok()?))?
                    .to_u32(),
            ),
            _ => GlyphId(cid),
        };
        (glyph.0 < self.glyph_count()).then_some(glyph)
    }

    /// The CID of `glyph`, the inverse of [`glyph_for_cid`](Self::glyph_for_cid).
    #[must_use]
    pub fn cid_for_glyph(&self, glyph: GlyphId) -> Option<u32> {
        if glyph.0 >= self.glyph_count() {
            return None;
        }
        match &self.repr {
            Repr::Cff(cff) if cff.is_cid() => cff
                .charset()?
                .string_id(skrifa::GlyphId::new(glyph.0))
                .map(|cid| u32::from(cid.to_u16())),
            _ => Some(glyph.0),
        }
    }

    /// The advance width of `glyph`: `hmtx` for an sfnt, the charstring's width (or the private
    /// dictionary's default) for CFF, the `hsbw` or `sbw` for Type1. `None` for a glyph the program does not have.
    #[must_use]
    pub fn advance_width(&self, glyph: GlyphId) -> Option<f32> {
        if glyph.0 >= self.glyph_count() {
            return None;
        }
        let gid = skrifa::GlyphId::new(glyph.0);
        match &self.repr {
            Repr::Sfnt(font) => font
                .glyph_metrics(Size::unscaled(), LocationRef::default())
                .advance_width(gid),
            Repr::Cff(cff) => {
                let subfont = cff.subfont(cff.subfont_index(gid)?, &[]).ok()?;
                cff.evaluate_width(&subfont, gid, &[])
                    .ok()
                    .flatten()
                    .map(|width| width.to_f32())
            }
            Repr::Type1(font) => font
                .evaluate_width(gid)
                .ok()
                .flatten()
                .map(|width| width.to_f32()),
        }
    }

    /// The `OS/2` table's `fsType`, the embedding permissions (OpenType §OS/2). A CFF or Type1
    /// program and an sfnt without `OS/2` state none.
    #[must_use]
    pub fn fs_type(&self) -> Option<u16> {
        match &self.repr {
            Repr::Sfnt(font) => font.os2().ok().map(|os2| os2.fs_type()),
            Repr::Cff(_) | Repr::Type1(_) => None,
        }
    }

    /// The PostScript name: name ID 6 of an sfnt, the CFF Name INDEX entry, Type1's `/FontName`.
    #[must_use]
    pub fn postscript_name(&self) -> Option<String> {
        match &self.repr {
            Repr::Sfnt(font) => name(font, &[StringId::POSTSCRIPT_NAME]),
            Repr::Cff(cff) => cff.metadata()?.name().map(String::from),
            Repr::Type1(font) => font.name().map(String::from),
        }
    }

    /// The family name: the typographic family (16) or family (1) of an sfnt, `FamilyName` of CFF
    /// and Type1.
    #[must_use]
    pub fn family_name(&self) -> Option<String> {
        match &self.repr {
            Repr::Sfnt(font) => name(
                font,
                &[StringId::TYPOGRAPHIC_FAMILY_NAME, StringId::FAMILY_NAME],
            ),
            Repr::Cff(cff) => cff.metadata()?.family_name().map(String::from),
            Repr::Type1(font) => font.family_name().map(String::from),
        }
    }

    /// The style name: the typographic subfamily (17) or subfamily (2) of an sfnt, `Weight` of CFF
    /// and Type1.
    #[must_use]
    pub fn style_name(&self) -> Option<String> {
        match &self.repr {
            Repr::Sfnt(font) => name(
                font,
                &[
                    StringId::TYPOGRAPHIC_SUBFAMILY_NAME,
                    StringId::SUBFAMILY_NAME,
                ],
            ),
            Repr::Cff(cff) => cff.metadata()?.weight().map(String::from),
            Repr::Type1(font) => font.weight().map(String::from),
        }
    }
}

/// The first of `ids` the `name` table holds, in English if it has English.
fn name(font: &FontRef<'_>, ids: &[StringId]) -> Option<String> {
    ids.iter().find_map(|&id| {
        font.localized_strings(id)
            .english_or_first()
            .map(|name| name.chars().collect())
    })
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    const PLEX_SANS: &[u8] =
        include_bytes!("../../../app/assets/fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf");

    fn be16(out: &mut Vec<u8>, values: &[u16]) {
        for value in values {
            out.extend_from_slice(&value.to_be_bytes());
        }
    }

    /// An sfnt of `tables`, each a tag and its data, in tag order.
    fn sfnt(tables: &[(&[u8; 4], Vec<u8>)]) -> Vec<u8> {
        let count = u16::try_from(tables.len()).unwrap();
        let mut font = vec![0, 1, 0, 0];
        be16(&mut font, &[count, 0, 0, 0]);
        let mut offset = 12 + 16 * tables.len();
        let mut data = Vec::new();
        for (tag, table) in tables {
            font.extend_from_slice(*tag);
            font.extend_from_slice(&[0; 4]);
            font.extend_from_slice(&u32::try_from(offset).unwrap().to_be_bytes());
            font.extend_from_slice(&u32::try_from(table.len()).unwrap().to_be_bytes());
            let mut padded = table.clone();
            padded.resize(table.len().next_multiple_of(4), 0);
            offset += padded.len();
            data.extend(padded);
        }
        font.extend(data);
        font
    }

    /// Three glyphs: `.notdef`, U+F041 (`alpha.sym`) and U+F042 (`uniF042`), behind a symbol cmap;
    /// `hhea` and the typo line are zero, so the win line applies, or the `head` box without `OS/2`.
    fn symbol_font(with_os2: bool) -> Vec<u8> {
        let mut cmap = Vec::new();
        be16(&mut cmap, &[0, 1, 3, 0, 0, 12]);
        be16(&mut cmap, &[4, 32, 0, 4, 4, 1, 0]);
        be16(&mut cmap, &[0xF042, 0xFFFF, 0, 0xF041, 0xFFFF]);
        be16(&mut cmap, &[1_u16.wrapping_sub(0xF041), 1, 0, 0]);
        let mut head = vec![0; 54];
        head[12..16].copy_from_slice(&0x5F0F_3CF5_u32.to_be_bytes());
        head[18..20].copy_from_slice(&2048_u16.to_be_bytes());
        head[38..40].copy_from_slice(&(-400_i16).to_be_bytes());
        head[42..44].copy_from_slice(&1800_u16.to_be_bytes());
        let mut hhea = vec![0, 1, 0, 0];
        hhea.resize(34, 0);
        be16(&mut hhea, &[3]);
        let mut hmtx = Vec::new();
        be16(&mut hmtx, &[500, 0, 1200, 0, 900, 0]);
        let mut maxp = vec![0, 0, 0x50, 0];
        be16(&mut maxp, &[3]);
        let mut post = vec![0, 2, 0, 0];
        post.resize(32, 0);
        be16(&mut post, &[3, 0, 258, 259]);
        for name in ["alpha.sym", "uniF042"] {
            post.push(u8::try_from(name.len()).unwrap());
            post.extend_from_slice(name.as_bytes());
        }
        let mut os2 = vec![0; 78];
        os2[8..10].copy_from_slice(&0x0004_u16.to_be_bytes());
        os2[74..76].copy_from_slice(&1900_u16.to_be_bytes());
        os2[76..78].copy_from_slice(&500_u16.to_be_bytes());
        let mut tables = vec![(b"OS/2", os2), (b"cmap", cmap), (b"head", head)];
        if !with_os2 {
            tables.remove(0);
        }
        tables.extend([
            (b"hhea", hhea),
            (b"hmtx", hmtx),
            (b"maxp", maxp),
            (b"post", post),
        ]);
        sfnt(&tables)
    }

    fn dict_int(out: &mut Vec<u8>, value: i32) {
        out.push(29);
        out.extend_from_slice(&value.to_be_bytes());
    }

    /// A one-byte-offset INDEX of `items`.
    fn index(items: &[&[u8]]) -> Vec<u8> {
        let mut out = Vec::new();
        be16(&mut out, &[u16::try_from(items.len()).unwrap()]);
        if items.is_empty() {
            return out;
        }
        out.push(1);
        let mut offset = 1;
        out.push(1);
        for item in items {
            offset += item.len();
            out.push(u8::try_from(offset).unwrap());
        }
        for item in items {
            out.extend_from_slice(item);
        }
        out
    }

    /// A name-keyed CFF program: `.notdef` (the default width 250), `A` (width 100 + 500) and
    /// `uni011F` (100 + 100); family "Fixture", weight "Bold", FontBBox -200 to 800.
    fn cff_font() -> Vec<u8> {
        // Charstrings: endchar; 500 endchar; 100 0 hmoveto endchar.
        let charstrings = index(&[&[14], &[248, 136, 14], &[239, 139, 22, 14]]);
        let strings = index(&[b"Fixture", b"uni011F"]);
        // defaultWidthX 250, nominalWidthX 100.
        let private = [247, 142, 20, 239, 21];
        let mut charset = vec![0];
        be16(&mut charset, &[34, 392]);
        let header = [1, 0, 4, 1];
        let name = index(&[b"Fixture-Bold"]);
        // The Top DICT has a fixed size: five-byte integers for every offset.
        let top_len = 6 + 6 + 21 + 6 + 6 + 11;
        let top_index_len = 2 + 1 + 2 + top_len;
        let strings_at = header.len() + name.len() + top_index_len;
        let charset_at = strings_at + strings.len() + 2;
        let charstrings_at = charset_at + charset.len();
        let private_at = charstrings_at + charstrings.len();
        let mut top = Vec::new();
        dict_int(&mut top, 391);
        top.push(3);
        dict_int(&mut top, 384);
        top.push(4);
        for value in [0, -200, 1000, 800] {
            dict_int(&mut top, value);
        }
        top.push(5);
        dict_int(&mut top, i32::try_from(charset_at).unwrap());
        top.push(15);
        dict_int(&mut top, i32::try_from(charstrings_at).unwrap());
        top.push(17);
        dict_int(&mut top, i32::try_from(private.len()).unwrap());
        dict_int(&mut top, i32::try_from(private_at).unwrap());
        top.push(18);
        assert_eq!(top.len(), top_len);
        let mut font = header.to_vec();
        font.extend(name);
        font.extend(index(&[&top]));
        font.extend(strings);
        font.extend([0, 0]);
        font.extend(charset);
        font.extend(charstrings);
        font.extend(private);
        font
    }

    /// Type1 encryption (Adobe Type 1 Font Format §7.1) of `plain` after four zero bytes.
    fn encrypt(plain: &[u8], mut key: u16) -> Vec<u8> {
        let mut out = Vec::new();
        for &byte in [0; 4].iter().chain(plain) {
            let cipher = byte ^ u8::try_from(key >> 8).unwrap();
            key = (u16::from(cipher).wrapping_add(key))
                .wrapping_mul(52845)
                .wrapping_add(22719);
            out.push(cipher);
        }
        out
    }

    /// A Type1 program, as a PFA or a PFB: `A` (width 600), `.notdef` (250) and `gbreve` (500),
    /// in that order; family "Fixture", weight "Bold", FontBBox -200 to 800.
    fn type1_font(pfb: bool) -> Vec<u8> {
        let clear = b"%!PS-AdobeFont-1.0: Fixture-Bold 001.000
11 dict begin
/FontInfo 2 dict dup begin
/FamilyName (Fixture) readonly def
/Weight (Bold) readonly def
end readonly def
/FontName /Fixture-Bold def
/Encoding StandardEncoding def
/FontMatrix [0.001 0 0 0.001 0 0] readonly def
/FontBBox {-50 -200 1000 800} readonly def
currentdict end
currentfile eexec
";
        let mut private = b"dup /Private 5 dict dup begin
/RD{string currentfile exch readstring pop}executeonly def
/ND{noaccess def}executeonly def
/NP{noaccess put}executeonly def
/lenIV 4 def
2 index /CharStrings 3 dict dup begin
"
        .to_vec();
        // 0 <width> hsbw endchar.
        for (name, width) in [
            ("A", [248, 236]),
            (".notdef", [247, 142]),
            ("gbreve", [248, 136]),
        ] {
            let charstring = encrypt(&[139, width[0], width[1], 13, 14], 4330);
            private.extend(format!("/{name} {} RD ", charstring.len()).bytes());
            private.extend(charstring);
            private.extend(b" ND\n");
        }
        private.extend(
            b"end\nend\nreadonly put\nnoaccess put\ndup /FontName get exch definefont pop\n",
        );
        let private = encrypt(&private, 55665);
        if !pfb {
            return [clear.as_slice(), &private].concat();
        }
        let mut font = Vec::new();
        for (kind, segment) in [(1, clear.as_slice()), (2, &private)] {
            font.extend([0x80, kind]);
            font.extend(u32::try_from(segment.len()).unwrap().to_le_bytes());
            font.extend_from_slice(segment);
        }
        font.extend([0x80, 3]);
        font
    }

    #[test]
    fn a_type1_program_gives_its_glyph_names_and_widths() {
        for pfb in [false, true] {
            let data = type1_font(pfb);
            let font = FontProgram::parse(&data).unwrap();
            assert_eq!(font.units_per_em(), 1000);
            assert_eq!(font.glyph_count(), 3);
            assert_eq!(font.ascent_descent(), (800.0, -200.0));
            assert_eq!(font.postscript_name().as_deref(), Some("Fixture-Bold"));
            assert_eq!(font.family_name().as_deref(), Some("Fixture"));
            assert_eq!(font.style_name().as_deref(), Some("Bold"));
            assert_eq!(
                font.glyph_for_name(".notdef"),
                Some(GlyphId(0)),
                "moved to 0"
            );
            assert_eq!(font.glyph_for_name("A"), Some(GlyphId(1)));
            assert_eq!(font.glyph_for_name("gbreve"), Some(GlyphId(2)));
            assert_eq!(font.glyph_for_name("B"), None);
            assert_eq!(font.glyph_for_char('A'), None, "Type1 has no cmap");
            assert_eq!(font.advance_width(GlyphId(0)), Some(250.0));
            assert_eq!(font.advance_width(GlyphId(1)), Some(600.0));
            assert_eq!(font.advance_width(GlyphId(2)), Some(500.0));
            assert_eq!(font.advance_width(GlyphId(3)), None);
            assert_eq!(font.fs_type(), None);
        }
    }

    #[test]
    fn a_truetype_program_gives_its_metrics_names_and_glyphs() {
        let font = FontProgram::parse(PLEX_SANS).unwrap();
        assert_eq!(font.units_per_em(), 1000);
        assert_eq!(font.ascent_descent(), (1025.0, -275.0));
        assert!(font.glyph_count() > 500);
        assert_eq!(font.postscript_name().as_deref(), Some("IBMPlexSans"));
        assert_eq!(font.family_name().as_deref(), Some("IBM Plex Sans"));
        assert_eq!(font.style_name().as_deref(), Some("Regular"));
        assert_eq!(font.fs_type(), Some(0));
        let gbreve = font.glyph_for_char('ğ').unwrap();
        assert_ne!(gbreve, GlyphId(0));
        assert_eq!(font.glyph_for_name("gbreve"), Some(gbreve));
        assert_eq!(font.glyph_for_name("no-such-glyph"), None);
        assert_eq!(font.glyph_name(gbreve).as_deref(), Some("gbreve"));
        assert!(font.advance_width(gbreve).unwrap() > 0.0);
        assert_eq!(font.advance_width(GlyphId(font.glyph_count())), None);
        assert_eq!(font.glyph_for_char('\u{F041}'), None);
    }

    #[test]
    fn a_symbol_cmap_maps_latin_1_through_f000() {
        let data = symbol_font(true);
        let font = FontProgram::parse(&data).unwrap();
        assert_eq!(font.glyph_for_char('\u{F041}'), Some(GlyphId(1)));
        assert_eq!(font.glyph_for_char('A'), Some(GlyphId(1)));
        assert_eq!(font.glyph_for_char('B'), Some(GlyphId(2)));
        assert_eq!(font.glyph_for_char('C'), None);
        assert_eq!(font.glyph_for_name("alpha.sym"), Some(GlyphId(1)));
        assert_eq!(font.glyph_for_name("uniF042"), Some(GlyphId(2)));
        assert_eq!(
            font.glyph_for_name("gid1"),
            None,
            "synthesized names find nothing"
        );
        assert_eq!(font.glyph_name(GlyphId(1)).as_deref(), Some("alpha.sym"));
        assert_eq!(font.advance_width(GlyphId(2)), Some(900.0));
        assert_eq!(font.units_per_em(), 2048);
        assert_eq!(font.fs_type(), Some(4));
        // hhea and the typo line are zero: the win line applies.
        assert_eq!(font.ascent_descent(), (1900.0, -500.0));
        assert_eq!(font.postscript_name(), None);
    }

    #[test]
    fn without_a_line_the_head_box_gives_ascent_and_descent() {
        let data = symbol_font(false);
        let font = FontProgram::parse(&data).unwrap();
        assert_eq!(font.ascent_descent(), (1800.0, -400.0));
        assert_eq!(font.fs_type(), None);
    }

    #[test]
    fn a_cff_program_gives_its_metrics_names_and_widths() {
        let data = cff_font();
        let font = FontProgram::parse(&data).unwrap();
        assert_eq!(font.units_per_em(), 1000);
        assert_eq!(font.glyph_count(), 3);
        assert_eq!(font.ascent_descent(), (800.0, -200.0));
        assert_eq!(font.postscript_name().as_deref(), Some("Fixture-Bold"));
        assert_eq!(font.family_name().as_deref(), Some("Fixture"));
        assert_eq!(font.style_name().as_deref(), Some("Bold"));
        assert_eq!(font.glyph_for_name("A"), Some(GlyphId(1)));
        assert_eq!(font.glyph_for_name("uni011F"), Some(GlyphId(2)));
        assert_eq!(font.glyph_for_name(".notdef"), Some(GlyphId(0)));
        assert_eq!(font.glyph_for_name("B"), None);
        assert_eq!(font.glyph_for_char('A'), None, "bare CFF has no cmap");
        assert_eq!(font.advance_width(GlyphId(0)), Some(250.0));
        assert_eq!(font.advance_width(GlyphId(1)), Some(600.0));
        assert_eq!(font.advance_width(GlyphId(2)), Some(200.0));
        assert_eq!(font.advance_width(GlyphId(3)), None);
        assert_eq!(font.fs_type(), None);
        // A name-keyed program's CIDs are its glyph indices.
        assert_eq!(font.glyph_for_cid(2), Some(GlyphId(2)));
        assert_eq!(font.glyph_for_cid(3), None);
        assert_eq!(font.cid_for_glyph(GlyphId(1)), Some(1));
        assert_eq!(font.cid_for_glyph(GlyphId(3)), None);
    }

    /// Every query on a program that parsed, so a damaged table shows up as a panic.
    fn query_everything(font: &FontProgram<'_>) {
        let _ = (font.units_per_em(), font.ascent_descent(), font.fs_type());
        let _ = (
            font.postscript_name(),
            font.family_name(),
            font.style_name(),
        );
        let _ = (font.glyph_for_char('A'), font.glyph_for_name("A"));
        let _ = (font.glyph_for_cid(1), font.cid_for_glyph(GlyphId(1)));
        for glyph in 0..font.glyph_count().min(8) {
            let _ = font.advance_width(GlyphId(glyph));
        }
        let _ = format!("{font:?}");
    }

    #[test]
    fn damaged_programs_fail_or_read_as_missing_data() {
        for data in [
            cff_font(),
            symbol_font(true),
            type1_font(false),
            type1_font(true),
        ] {
            for end in 0..data.len() {
                if let Ok(font) = FontProgram::parse(&data[..end]) {
                    query_everything(&font);
                }
            }
            // A byte flipped anywhere.
            for at in 0..data.len() {
                let mut damaged = data.clone();
                damaged[at] ^= 0xA5;
                if let Ok(font) = FontProgram::parse(&damaged) {
                    query_everything(&font);
                }
            }
        }
        for end in (0..PLEX_SANS.len()).step_by(997) {
            if let Ok(font) = FontProgram::parse(&PLEX_SANS[..end]) {
                query_everything(&font);
            }
        }
        assert!(matches!(
            FontProgram::parse(b"%!PS-AdobeFont-1.0"),
            Err(FontError::Malformed { .. })
        ));
        assert!(matches!(
            FontProgram::parse(b""),
            Err(FontError::Malformed { .. })
        ));
        let garbage: Vec<u8> = (0..4096_u32).map(|i| (i * 7919 % 251) as u8).collect();
        let _ = FontProgram::parse(&garbage);
    }

    #[test]
    fn an_oversized_program_is_refused() {
        let program = vec![0; MAX_PROGRAM + 1];
        assert!(matches!(
            FontProgram::parse(&program),
            Err(FontError::ProgramTooLarge { .. })
        ));
    }
}
