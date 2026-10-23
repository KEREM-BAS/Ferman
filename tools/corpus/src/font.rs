//! Fonts in the generated PDFs, the three kinds real producers write:
//!
//! - [`Type0Font`]: a composite font, `Identity-H` (or `Identity-V` for vertical text, with
//!   `/W2` and `/DW2`), a subset TrueType program (`CIDFontType2`), `/W` widths and a
//!   `/ToUnicode` CMap. Text is shaped with harfrust, so it has kerning, Arabic joining and the
//!   vertical forms and, when the style asks, ligatures.
//! - [`SimpleFont`]: a simple TrueType font with `/WinAnsiEncoding` and a subset program, as Word
//!   writes for text inside Windows-1252. subsetter drops the `cmap` table, so a (3,1) one for the
//!   used characters is put back ([`crate::sfnt`]).
//! - [`StandardFont`]: a font that is named but not embedded, with `/WinAnsiEncoding` or the
//!   Windows-1254 `/Differences` that older Turkish files use.
//!
//! Subset tags come from the SHA-256 of the glyphs used, so they are stable from run to run. A
//! variable font is used at one location: its metrics, its shaping and its subset (instanced by
//! subsetter) all take the same variations.

use crate::pdf::{Pdf, name, real};
use crate::{sfnt, sha256_hex};
use harfrust::{Buffer, Direction, Feature, ShapeOptions, ShaperFont};
use lopdf::{Dictionary, Object, ObjectId, dictionary};
use skrifa::instance::{Location, Size};
use skrifa::outline::{DrawSettings, OutlinePen};
use skrifa::raw::TableProvider;
use skrifa::raw::types::Tag;
use skrifa::string::StringId;
use skrifa::{FontRef, GlyphId, MetadataProvider};
use std::collections::BTreeMap;
use std::fmt::Write as _;
use std::rc::Rc;
use subsetter::GlyphRemapper;

/// A loaded font file: metrics for the PDF and a shaper.
pub struct Face {
    data: Vec<u8>,
    font: harfrust::Font,
    /// The location in a variable font, and the variations that give it.
    location: Location,
    variations: Vec<([u8; 4], f32)>,
    upem: f64,
    /// The PostScript name, such as `IBMPlexSerif`.
    pub postscript_name: String,
    serif: bool,
    italic: bool,
    weight: f64,
    ascent: f64,
    descent: f64,
    cap_height: f64,
    italic_angle: f64,
    bbox: [f64; 4],
    /// The vertical origin of a glyph without an outline: the typographic ascender.
    vertical_origin: f64,
}

impl std::fmt::Debug for Face {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Face")
            .field("postscript_name", &self.postscript_name)
            .finish_non_exhaustive()
    }
}

/// One shaped glyph, in thousandths of an em.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Shaped {
    /// The glyph in the font file.
    pub gid: u16,
    /// The byte offset of its cluster in the shaped text.
    pub cluster: usize,
    /// The advance the shaper gives it: horizontal, or downwards in vertical text.
    pub advance: f64,
}

impl Face {
    /// Loads a font file at `variations` (axis tag and value; none for a static font). `serif`
    /// sets the descriptor's Serif flag.
    ///
    /// # Errors
    ///
    /// A message when the file is not a font skrifa and harfrust can read.
    pub fn new(data: Vec<u8>, serif: bool, variations: &[([u8; 4], f32)]) -> Result<Self, String> {
        let font_ref = FontRef::new(&data).map_err(|err| format!("font: {err}"))?;
        let location = font_ref.axes().location(
            variations
                .iter()
                .map(|(tag, value)| (Tag::new(tag), *value)),
        );
        let metrics = font_ref.metrics(Size::unscaled(), &location);
        let upem = f64::from(metrics.units_per_em);
        let scale = 1000.0 / upem;
        let postscript_name = font_ref
            .localized_strings(StringId::POSTSCRIPT_NAME)
            .english_or_first()
            .map(|name| name.to_string())
            .ok_or("font: no PostScript name")?;
        let attributes = font_ref.attributes();
        let bounds = metrics.bounds.unwrap_or_default();
        let vertical_origin = font_ref.os2().map_or(f64::from(metrics.ascent), |os2| {
            f64::from(os2.s_typo_ascender())
        }) * scale;
        let font = harfrust::Font::new(data.clone(), 0).ok_or("font: harfrust cannot read it")?;
        let font = if variations.is_empty() {
            font
        } else {
            font.instance_builder()
                .variations(variations.iter().map(|(tag, value)| {
                    harfrust::font::Variation::new(harfrust::Tag::new(tag), *value)
                }))
                .build()
        };
        let face = Self {
            upem,
            postscript_name,
            serif,
            italic: attributes.style != skrifa::attribute::Style::Normal,
            weight: variations
                .iter()
                .find(|(tag, _)| tag == b"wght")
                .map_or(f64::from(attributes.weight.value()), |(_, value)| {
                    f64::from(*value)
                }),
            ascent: f64::from(metrics.ascent) * scale,
            descent: f64::from(metrics.descent) * scale,
            cap_height: f64::from(metrics.cap_height.unwrap_or(metrics.ascent * 0.7)) * scale,
            italic_angle: f64::from(metrics.italic_angle),
            bbox: [
                f64::from(bounds.x_min) * scale,
                f64::from(bounds.y_min) * scale,
                f64::from(bounds.x_max) * scale,
                f64::from(bounds.y_max) * scale,
            ],
            vertical_origin,
            font,
            location,
            variations: variations.to_vec(),
            data,
        };
        Ok(face)
    }

    fn font_ref(&self) -> Option<FontRef<'_>> {
        FontRef::new(&self.data).ok()
    }

    /// The nominal glyph of `c`.
    #[must_use]
    pub fn glyph(&self, c: char) -> Option<u16> {
        let gid = self.font_ref()?.charmap().map(c)?;
        u16::try_from(gid.to_u32()).ok().filter(|gid| *gid != 0)
    }

    /// The advance of `gid` in thousandths of an em.
    #[must_use]
    pub fn advance(&self, gid: u16) -> f64 {
        self.font_ref()
            .and_then(|font| {
                font.glyph_metrics(Size::unscaled(), &self.location)
                    .advance_width(GlyphId::new(u32::from(gid)))
            })
            .map_or(0.0, |advance| f64::from(advance) * 1000.0 / self.upem)
    }

    /// The vertical advance of `gid` and the height of its vertical origin above the baseline,
    /// in thousandths of an em: from `vmtx` and the glyph's top, as shapers place it; the
    /// typographic ascender for a glyph without an outline.
    #[must_use]
    pub fn vertical(&self, gid: u16) -> (f64, f64) {
        let scale = 1000.0 / self.upem;
        let glyph = GlyphId::new(u32::from(gid));
        let Some(font) = self.font_ref() else {
            return (1000.0, self.vertical_origin);
        };
        let vmtx = font.vmtx().ok();
        let advance = vmtx
            .as_ref()
            .and_then(|vmtx| vmtx.advance(glyph))
            .map_or(1000.0, |advance| f64::from(advance) * scale);
        let top = font
            .glyph_metrics(Size::unscaled(), &self.location)
            .bounds(glyph)
            .filter(|bounds| bounds.x_max > bounds.x_min && bounds.y_max > bounds.y_min)
            .map(|bounds| bounds.y_max);
        let side_bearing = vmtx.as_ref().and_then(|vmtx| vmtx.side_bearing(glyph));
        let origin = match (side_bearing, top) {
            (Some(side_bearing), Some(top)) => (f64::from(side_bearing) + f64::from(top)) * scale,
            _ => self.vertical_origin,
        };
        (advance, origin)
    }

    /// The vertical origin of a glyph without an outline, in thousandths of an em.
    #[must_use]
    pub fn vertical_origin(&self) -> f64 {
        self.vertical_origin
    }

    /// Draws the outline of `gid`, in font units, at the face's location. Returns false when
    /// the glyph has none.
    pub fn draw_outline(&self, gid: u16, pen: &mut impl OutlinePen) -> bool {
        let Some(font) = self.font_ref() else {
            return false;
        };
        let glyphs = font.outline_glyphs();
        glyphs
            .get(GlyphId::new(u32::from(gid)))
            .is_some_and(|glyph| {
                glyph
                    .draw(
                        DrawSettings::unhinted(Size::unscaled(), &self.location),
                        pen,
                    )
                    .is_ok()
            })
    }

    /// The units per em.
    #[must_use]
    pub fn units_per_em(&self) -> f64 {
        self.upem
    }

    /// The subset program for `remap`, instanced at the face's location.
    fn subset(&self, remap: &GlyphRemapper) -> Result<Vec<u8>, String> {
        let program = if self.variations.is_empty() {
            subsetter::subset(&self.data, 0, remap)
        } else {
            let coordinates: Vec<(subsetter::Tag, f32)> = self
                .variations
                .iter()
                .map(|(tag, value)| (subsetter::Tag::new(tag), *value))
                .collect();
            subsetter::subset_with_variations(&self.data, 0, &coordinates, remap)
        };
        program.map_err(|err| format!("subsetting {}: {err}", self.postscript_name))
    }

    /// The ascent in thousandths of an em.
    #[must_use]
    pub fn ascent(&self) -> f64 {
        self.ascent
    }

    /// Shapes `text` in `direction` with `features`. The glyphs come in visual order: right to
    /// left text comes last character first.
    ///
    /// # Errors
    ///
    /// A message when harfrust fails.
    pub fn shape(
        &self,
        text: &str,
        features: &[Feature],
        direction: Direction,
    ) -> Result<Vec<Shaped>, String> {
        let shaper = ShaperFont::new(&self.font);
        let mut buffer = Buffer::new();
        buffer.push_str(text);
        buffer.set_direction(direction);
        buffer.guess_segment_properties();
        harfrust::shape(&shaper, &mut buffer, ShapeOptions::new().features(features))
            .map_err(|err| format!("shaping {text:?}: {err:?}"))?;
        let scale = 1000.0 / self.upem;
        buffer
            .glyph_infos()
            .iter()
            .zip(buffer.glyph_positions())
            .map(|(info, position)| {
                let advance = if direction == Direction::TopToBottom {
                    -position.y_advance
                } else {
                    position.x_advance
                };
                Ok(Shaped {
                    gid: u16::try_from(info.glyph_id).map_err(|err| err.to_string())?,
                    cluster: usize::try_from(info.cluster).map_err(|err| err.to_string())?,
                    advance: f64::from(advance) * scale,
                })
            })
            .collect()
    }

    /// The font descriptor's flags: Serif (2), Symbolic (4) or Nonsymbolic (32), Italic (64).
    fn flags(&self, symbolic: bool) -> i64 {
        let mut flags = if symbolic { 4 } else { 32 };
        if self.serif {
            flags |= 2;
        }
        if self.italic {
            flags |= 64;
        }
        flags
    }

    /// A font descriptor for `font_name`, without the font program.
    fn descriptor(&self, font_name: &str, symbolic: bool) -> Dictionary {
        // A common estimate when the font does not say: 50 + (weight / 65)².
        let stem_v = 50.0 + (self.weight / 65.0) * (self.weight / 65.0);
        dictionary! {
            "Type" => "FontDescriptor",
            "FontName" => name(font_name),
            "Flags" => self.flags(symbolic),
            "FontBBox" => Object::Array(self.bbox.iter().map(|v| real(v.round())).collect()),
            "ItalicAngle" => real(self.italic_angle),
            "Ascent" => real(self.ascent.round()),
            "Descent" => real(self.descent.round()),
            "CapHeight" => real(self.cap_height.round()),
            "StemV" => real(stem_v.round()),
        }
    }
}

/// A glyph ready for a content stream.
#[derive(Debug, Clone, PartialEq)]
pub struct Glyph {
    /// The bytes that select it: one for a simple font, two for `Identity-H` and `Identity-V`.
    pub code: Vec<u8>,
    /// The glyph in the font file (0 for a font that is not embedded).
    pub gid: u16,
    /// Its width in the font's `/Widths` or `/W`, or its vertical advance in `/W2`, in
    /// thousandths of an em.
    pub width: f64,
    /// How far the shaper moves the pen after it; the difference from `width` becomes a `TJ`
    /// adjustment.
    pub advance: f64,
    /// Whether it is a space, which justification may widen.
    pub space: bool,
}

/// The mirrored form of a bracket (UAX #9 rule L4), for the pairs producers' text has.
fn mirror(c: char) -> Option<char> {
    let pair = match c {
        '(' => ')',
        ')' => '(',
        '[' => ']',
        ']' => '[',
        '{' => '}',
        '}' => '{',
        '<' => '>',
        '>' => '<',
        '«' => '»',
        '»' => '«',
        _ => return None,
    };
    Some(pair)
}

/// A six-letter subset tag from `seed`.
fn subset_tag(seed: &str) -> String {
    sha256_hex(seed.as_bytes())
        .as_bytes()
        .chunks(2)
        .take(6)
        .map(|pair| {
            let value =
                u8::from_str_radix(std::str::from_utf8(pair).unwrap_or("0"), 16).unwrap_or(0);
            char::from(b'A' + value % 26)
        })
        .collect()
}

/// A `/ToUnicode` CMap for `map` (code → text).
fn to_unicode(map: &BTreeMap<Vec<u8>, String>, two_byte: bool) -> Vec<u8> {
    let mut out = String::from(
        "/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n\
         /CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n\
         /CMapName /Adobe-Identity-UCS def\n/CMapType 2 def\n1 begincodespacerange\n",
    );
    out.push_str(if two_byte {
        "<0000> <FFFF>\n"
    } else {
        "<00> <FF>\n"
    });
    out.push_str("endcodespacerange\n");
    let entries: Vec<_> = map.iter().collect();
    for chunk in entries.chunks(100) {
        let _ = writeln!(out, "{} beginbfchar", chunk.len());
        for (code, text) in chunk {
            let code_hex: String = code.iter().map(|b| format!("{b:02X}")).collect();
            let text_hex: String = text.encode_utf16().map(|u| format!("{u:04X}")).collect();
            let _ = writeln!(out, "<{code_hex}> <{text_hex}>");
        }
        out.push_str("endbfchar\n");
    }
    out.push_str("endcmap\nCMapName currentdict /CMap defineresource pop\nend\nend\n");
    out.into_bytes()
}

/// A composite font: `Type0`, `Identity-H` or `Identity-V`, `CIDFontType2` with CIDs equal to
/// the subset's glyph ids.
#[derive(Debug)]
pub struct Type0Font {
    face: Rc<Face>,
    /// The font dictionary's object, reserved when the font is made.
    pub id: ObjectId,
    /// Whether it sets text top to bottom (`Identity-V`).
    pub vertical: bool,
    remap: GlyphRemapper,
    unicode: BTreeMap<u16, String>,
    widths: BTreeMap<u16, f64>,
    /// The vertical advance and origin of each CID, for `/W2`.
    vertical_metrics: BTreeMap<u16, (f64, f64)>,
    cache: std::collections::HashMap<(String, usize, bool), Vec<Glyph>>,
}

impl Type0Font {
    /// A horizontal font on `face`, its object reserved in `pdf`.
    pub fn new(pdf: &mut Pdf, face: Rc<Face>) -> Self {
        Self {
            face,
            id: pdf.reserve(),
            vertical: false,
            remap: GlyphRemapper::new(),
            unicode: BTreeMap::new(),
            widths: BTreeMap::new(),
            vertical_metrics: BTreeMap::new(),
            cache: std::collections::HashMap::new(),
        }
    }

    /// A vertical font (`Identity-V`) on `face`, its object reserved in `pdf`.
    pub fn vertical(pdf: &mut Pdf, face: Rc<Face>) -> Self {
        Self {
            vertical: true,
            ..Self::new(pdf, face)
        }
    }

    /// The face.
    #[must_use]
    pub fn face(&self) -> &Face {
        &self.face
    }

    /// The face, shared.
    #[must_use]
    pub fn shared_face(&self) -> Rc<Face> {
        Rc::clone(&self.face)
    }

    /// Shapes `text` and returns its glyphs in visual order, each mapped to the text of its
    /// cluster. `rtl` shapes a horizontal font right to left; a vertical font always shapes top
    /// to bottom.
    ///
    /// # Errors
    ///
    /// A message when shaping fails or the face lacks a character (glyph 0).
    pub fn shape(
        &mut self,
        text: &str,
        features: &[Feature],
        rtl: bool,
    ) -> Result<Vec<Glyph>, String> {
        let key = (text.to_owned(), features.len(), rtl);
        if let Some(glyphs) = self.cache.get(&key) {
            return Ok(glyphs.clone());
        }
        let glyphs = self.shape_uncached(text, features, rtl)?;
        self.cache.insert(key, glyphs.clone());
        Ok(glyphs)
    }

    fn shape_uncached(
        &mut self,
        text: &str,
        features: &[Feature],
        rtl: bool,
    ) -> Result<Vec<Glyph>, String> {
        let direction = match (self.vertical, rtl) {
            (true, _) => Direction::TopToBottom,
            (false, true) => Direction::RightToLeft,
            (false, false) => Direction::LeftToRight,
        };
        let shaped = self.face.shape(text, features, direction)?;
        let mut clusters: Vec<usize> = shaped.iter().map(|glyph| glyph.cluster).collect();
        clusters.sort_unstable();
        clusters.dedup();
        // The glyphs of each cluster in logical order: right to left output comes reversed.
        let mut members: BTreeMap<usize, Vec<usize>> = BTreeMap::new();
        for (index, glyph) in shaped.iter().enumerate() {
            members.entry(glyph.cluster).or_default().push(index);
        }
        let mut texts: Vec<Option<String>> = vec![None; shaped.len()];
        for (cluster, indices) in &mut members {
            if direction == Direction::RightToLeft {
                indices.reverse();
            }
            let end = clusters
                .iter()
                .find(|start| *start > cluster)
                .copied()
                .unwrap_or(text.len());
            let cluster_text = text.get(*cluster..end).unwrap_or_default();
            let chars: Vec<char> = cluster_text.chars().collect();
            if let ([index], [c]) = (indices.as_slice(), chars.as_slice()) {
                // A bracket the shaper mirrored in right-to-left text maps to the character
                // its glyph shows, as the font's cmap has it.
                let shown = mirror(*c)
                    .filter(|_| direction == Direction::RightToLeft)
                    .filter(|m| self.face.glyph(*m) == shaped.get(*index).map(|glyph| glyph.gid));
                if let Some(slot) = texts.get_mut(*index) {
                    *slot = Some(shown.unwrap_or(*c).to_string());
                }
            } else if indices.len() > 1 && indices.len() == chars.len() {
                // One glyph per character, as a base and its marks.
                for (index, c) in indices.iter().zip(chars) {
                    if let Some(slot) = texts.get_mut(*index) {
                        *slot = Some(c.to_string());
                    }
                }
            } else if let Some(slot) = indices.first().and_then(|index| texts.get_mut(*index)) {
                *slot = Some(cluster_text.to_owned());
            }
        }
        let mut glyphs = Vec::with_capacity(shaped.len());
        for (glyph, glyph_text) in shaped.into_iter().zip(texts) {
            if glyph.gid == 0 {
                return Err(format!(
                    "{} has no glyph for {:?}",
                    self.face.postscript_name,
                    text.get(glyph.cluster..).unwrap_or_default()
                ));
            }
            let cid = self.remap.remap(glyph.gid);
            let space = glyph_text.as_deref() == Some(" ");
            if let Some(glyph_text) = glyph_text {
                self.unicode.entry(cid).or_insert(glyph_text);
            }
            let horizontal = self.face.advance(glyph.gid);
            self.widths.insert(cid, horizontal);
            let width = if self.vertical {
                let metrics = self.face.vertical(glyph.gid);
                self.vertical_metrics.insert(cid, metrics);
                metrics.0
            } else {
                horizontal
            };
            glyphs.push(Glyph {
                code: cid.to_be_bytes().to_vec(),
                gid: glyph.gid,
                width,
                advance: glyph.advance,
                space,
            });
        }
        Ok(glyphs)
    }

    /// Writes the font dictionary, the CIDFont, the descriptor, the subset and the CMap.
    ///
    /// # Errors
    ///
    /// A message when subsetting fails.
    pub fn finish(self, pdf: &mut Pdf) -> Result<(), String> {
        let gids: Vec<u16> = self.remap.remapped_gids().collect();
        let tag = subset_tag(&format!("{}{gids:?}", self.face.postscript_name));
        let base_font = format!("{tag}+{}", self.face.postscript_name);
        let program = self.face.subset(&self.remap)?;
        let length = i64::try_from(program.len()).map_err(|err| err.to_string())?;
        let file = pdf.stream(dictionary! { "Length1" => length }, program);
        let mut descriptor = self.face.descriptor(&base_font, true);
        descriptor.set("FontFile2", file);
        let descriptor = pdf.add(descriptor);
        let mut widths = Vec::new();
        if let Some(first) = self.widths.keys().next() {
            widths.push(Object::Integer(i64::from(*first)));
            widths.push(Object::Array(
                (*first..=self.widths.keys().last().copied().unwrap_or(*first))
                    .map(|cid| real(self.widths.get(&cid).copied().unwrap_or(0.0).round()))
                    .collect(),
            ));
        }
        let mut cid_font = dictionary! {
            "Type" => "Font",
            "Subtype" => "CIDFontType2",
            "BaseFont" => name(&base_font),
            "CIDSystemInfo" => dictionary! {
                "Registry" => Object::string_literal("Adobe"),
                "Ordering" => Object::string_literal("Identity"),
                "Supplement" => 0,
            },
            "FontDescriptor" => descriptor,
            "W" => widths,
            "CIDToGIDMap" => "Identity",
        };
        if self.vertical {
            // The usual default, [880 -1000], and the glyphs that differ from it.
            let origin = self.face.vertical_origin().round();
            cid_font.set("DW2", vec![real(origin), real(-1000.0)]);
            let mut w2 = Vec::new();
            for (cid, (advance, glyph_origin)) in &self.vertical_metrics {
                let width = self.widths.get(cid).copied().unwrap_or(0.0);
                if (advance.round() - 1000.0).abs() > 0.0
                    || (glyph_origin.round() - origin).abs() > 0.0
                {
                    w2.push(Object::Integer(i64::from(*cid)));
                    w2.push(Object::Array(vec![
                        real(-advance.round()),
                        real((width / 2.0).round()),
                        real(glyph_origin.round()),
                    ]));
                }
            }
            if !w2.is_empty() {
                cid_font.set("W2", w2);
            }
        }
        let cid_font = pdf.add(cid_font);
        let map: BTreeMap<Vec<u8>, String> = self
            .unicode
            .iter()
            .map(|(cid, text)| (cid.to_be_bytes().to_vec(), text.clone()))
            .collect();
        let cmap = pdf.stream(Dictionary::new(), to_unicode(&map, true));
        pdf.set(
            self.id,
            dictionary! {
                "Type" => "Font",
                "Subtype" => "Type0",
                "BaseFont" => name(&base_font),
                "Encoding" => if self.vertical { "Identity-V" } else { "Identity-H" },
                "DescendantFonts" => vec![Object::Reference(cid_font)],
                "ToUnicode" => cmap,
            },
        );
        Ok(())
    }
}

/// The WinAnsiEncoding code of `c` (ISO 32000-1 Annex D.2).
#[must_use]
pub fn win_ansi(c: char) -> Option<u8> {
    let code = u32::from(c);
    if (0x20..=0x7E).contains(&code) || (0xA0..=0xFF).contains(&code) {
        return u8::try_from(code).ok();
    }
    let code = match c {
        '€' => 0x80,
        '‚' => 0x82,
        'ƒ' => 0x83,
        '„' => 0x84,
        '…' => 0x85,
        '†' => 0x86,
        '‡' => 0x87,
        'ˆ' => 0x88,
        '‰' => 0x89,
        'Š' => 0x8A,
        '‹' => 0x8B,
        'Œ' => 0x8C,
        'Ž' => 0x8E,
        '‘' => 0x91,
        '’' => 0x92,
        '“' => 0x93,
        '”' => 0x94,
        '•' => 0x95,
        '–' => 0x96,
        '—' => 0x97,
        '˜' => 0x98,
        '™' => 0x99,
        'š' => 0x9A,
        '›' => 0x9B,
        'œ' => 0x9C,
        'ž' => 0x9E,
        'Ÿ' => 0x9F,
        _ => return None,
    };
    Some(code)
}

/// The Windows-1254 letters that replace six Windows-1252 ones, with their glyph names.
const TURKISH: [(char, u8, &str); 6] = [
    ('Ğ', 0xD0, "Gbreve"),
    ('İ', 0xDD, "Idotaccent"),
    ('Ş', 0xDE, "Scedilla"),
    ('ğ', 0xF0, "gbreve"),
    ('ı', 0xFD, "dotlessi"),
    ('ş', 0xFE, "scedilla"),
];

/// A simple TrueType font with `/WinAnsiEncoding` and a subset program with a (3,1) `cmap`.
#[derive(Debug)]
pub struct SimpleFont {
    face: Rc<Face>,
    /// The font dictionary's object, reserved when the font is made.
    pub id: ObjectId,
    used: BTreeMap<u8, char>,
    cache: BTreeMap<char, Option<Glyph>>,
}

impl SimpleFont {
    /// A font on `face`, its object reserved in `pdf`.
    pub fn new(pdf: &mut Pdf, face: Rc<Face>) -> Self {
        Self {
            face,
            id: pdf.reserve(),
            used: BTreeMap::new(),
            cache: BTreeMap::new(),
        }
    }

    /// The glyph for `c`, or `None` when WinAnsiEncoding or the face lacks it.
    pub fn encode(&mut self, c: char) -> Option<Glyph> {
        if let Some(glyph) = self.cache.get(&c) {
            return glyph.clone();
        }
        let glyph = self.encode_uncached(c);
        self.cache.insert(c, glyph.clone());
        glyph
    }

    fn encode_uncached(&mut self, c: char) -> Option<Glyph> {
        let code = win_ansi(c)?;
        let gid = self.face.glyph(c)?;
        self.used.insert(code, c);
        let width = self.face.advance(gid);
        Some(Glyph {
            code: vec![code],
            gid,
            width,
            advance: width,
            space: c == ' ',
        })
    }

    /// Writes the font dictionary, the descriptor and the subset.
    ///
    /// # Errors
    ///
    /// A message when subsetting fails.
    pub fn finish(self, pdf: &mut Pdf) -> Result<(), String> {
        let mut remap = GlyphRemapper::new();
        let mut cmap = BTreeMap::new();
        for c in self.used.values() {
            if let Some(gid) = self.face.glyph(*c) {
                cmap.insert(*c, remap.remap(gid));
            }
        }
        let gids: Vec<u16> = remap.remapped_gids().collect();
        let tag = subset_tag(&format!("{}{gids:?}", self.face.postscript_name));
        let base_font = format!("{tag}+{}", self.face.postscript_name);
        let program = self.face.subset(&remap)?;
        let program = sfnt::with_cmap(&program, &cmap)?;
        let length = i64::try_from(program.len()).map_err(|err| err.to_string())?;
        let file = pdf.stream(dictionary! { "Length1" => length }, program);
        let mut descriptor = self.face.descriptor(&base_font, false);
        descriptor.set("FontFile2", file);
        let descriptor = pdf.add(descriptor);
        let first = self.used.keys().next().copied().unwrap_or(32);
        let last = self.used.keys().last().copied().unwrap_or(32);
        let widths: Vec<Object> = (first..=last)
            .map(|code| {
                let width = self
                    .used
                    .get(&code)
                    .and_then(|c| self.face.glyph(*c))
                    .map_or(0.0, |gid| self.face.advance(gid));
                real(width.round())
            })
            .collect();
        pdf.set(
            self.id,
            dictionary! {
                "Type" => "Font",
                "Subtype" => "TrueType",
                "BaseFont" => name(&base_font),
                "FirstChar" => i64::from(first),
                "LastChar" => i64::from(last),
                "Widths" => widths,
                "Encoding" => "WinAnsiEncoding",
                "FontDescriptor" => descriptor,
            },
        );
        Ok(())
    }
}

/// A font that is named but not embedded. Its widths come from a face with similar metrics.
#[derive(Debug)]
pub struct StandardFont {
    metrics: Rc<Face>,
    /// The font dictionary's object, reserved when the font is made.
    pub id: ObjectId,
    base_font: String,
    subtype: &'static str,
    turkish: bool,
    used: BTreeMap<u8, char>,
}

impl StandardFont {
    /// `base_font` (for example `TimesNewRomanPSMT`, subtype `TrueType`) with widths from
    /// `metrics`. With `turkish`, the encoding has Windows-1254's `/Differences`.
    pub fn new(
        pdf: &mut Pdf,
        metrics: Rc<Face>,
        base_font: &str,
        subtype: &'static str,
        turkish: bool,
    ) -> Self {
        Self {
            metrics,
            id: pdf.reserve(),
            base_font: base_font.to_owned(),
            subtype,
            turkish,
            used: BTreeMap::new(),
        }
    }

    /// The glyph for `c`, or `None` when the encoding lacks it.
    pub fn encode(&mut self, c: char) -> Option<Glyph> {
        let code = if self.turkish {
            match TURKISH.iter().find(|(letter, _, _)| *letter == c) {
                Some((_, code, _)) => *code,
                None => {
                    let code = win_ansi(c)?;
                    if TURKISH.iter().any(|(_, replaced, _)| *replaced == code) {
                        return None;
                    }
                    code
                }
            }
        } else {
            win_ansi(c)?
        };
        let width = self
            .metrics
            .glyph(c)
            .map_or(500.0, |gid| self.metrics.advance(gid));
        self.used.insert(code, c);
        Some(Glyph {
            code: vec![code],
            gid: 0,
            width,
            advance: width,
            space: c == ' ',
        })
    }

    /// Writes the font dictionary and its descriptor, with no font program.
    pub fn finish(self, pdf: &mut Pdf) {
        let descriptor = self.metrics.descriptor(&self.base_font, false);
        let descriptor = pdf.add(descriptor);
        let first = self.used.keys().next().copied().unwrap_or(32);
        let last = self.used.keys().last().copied().unwrap_or(32);
        let widths: Vec<Object> = (first..=last)
            .map(|code| {
                let width = self
                    .used
                    .get(&code)
                    .and_then(|c| self.metrics.glyph(*c))
                    .map_or(0.0, |gid| self.metrics.advance(gid));
                real(width.round())
            })
            .collect();
        let encoding: Object = if self.turkish {
            let mut differences = Vec::new();
            for (_, code, glyph) in TURKISH {
                differences.push(Object::Integer(i64::from(code)));
                differences.push(name(glyph));
            }
            dictionary! {
                "Type" => "Encoding",
                "BaseEncoding" => "WinAnsiEncoding",
                "Differences" => differences,
            }
            .into()
        } else {
            name("WinAnsiEncoding")
        };
        pdf.set(
            self.id,
            dictionary! {
                "Type" => "Font",
                "Subtype" => self.subtype,
                "BaseFont" => name(&self.base_font),
                "FirstChar" => i64::from(first),
                "LastChar" => i64::from(last),
                "Widths" => widths,
                "Encoding" => encoding,
                "FontDescriptor" => descriptor,
            },
        );
    }
}

/// Any of the three kinds.
#[derive(Debug)]
pub enum PdfFont {
    /// A composite font.
    Type0(Type0Font),
    /// A simple embedded TrueType font.
    Simple(SimpleFont),
    /// A font that is not embedded.
    Standard(StandardFont),
}

impl PdfFont {
    /// The font dictionary's object.
    #[must_use]
    pub fn id(&self) -> ObjectId {
        match self {
            Self::Type0(font) => font.id,
            Self::Simple(font) => font.id,
            Self::Standard(font) => font.id,
        }
    }

    /// Whether its codes are two bytes (written as hex strings).
    #[must_use]
    pub fn two_byte(&self) -> bool {
        matches!(self, Self::Type0(_))
    }

    /// The face its glyphs come from, or its metrics for a font that is not embedded.
    #[must_use]
    pub fn face(&self) -> Rc<Face> {
        match self {
            Self::Type0(font) => font.shared_face(),
            Self::Simple(font) => Rc::clone(&font.face),
            Self::Standard(font) => Rc::clone(&font.metrics),
        }
    }

    /// Writes the font's objects.
    ///
    /// # Errors
    ///
    /// A message when subsetting fails.
    pub fn finish(self, pdf: &mut Pdf) -> Result<(), String> {
        match self {
            Self::Type0(font) => font.finish(pdf),
            Self::Simple(font) => font.finish(pdf),
            Self::Standard(font) => {
                font.finish(pdf);
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn win_ansi_has_latin1_and_the_windows_extras() {
        assert_eq!(win_ansi('A'), Some(0x41));
        assert_eq!(win_ansi('ü'), Some(0xFC));
        assert_eq!(win_ansi('’'), Some(0x92));
        assert_eq!(win_ansi('ş'), None);
        assert_eq!(win_ansi('ı'), None);
    }

    #[test]
    fn subset_tags_are_six_capitals_and_stable() {
        let tag = subset_tag("IBMPlexSerif[0, 3, 4]");
        assert_eq!(tag.len(), 6);
        assert!(tag.bytes().all(|b| b.is_ascii_uppercase()));
        assert_eq!(tag, subset_tag("IBMPlexSerif[0, 3, 4]"));
    }

    #[test]
    fn to_unicode_writes_bfchar_blocks() {
        let mut map = BTreeMap::new();
        map.insert(vec![0, 1], "fi".to_owned());
        let cmap = String::from_utf8(to_unicode(&map, true)).unwrap_or_default();
        assert!(cmap.contains("1 beginbfchar\n<0001> <00660069>\n"));
    }
}
