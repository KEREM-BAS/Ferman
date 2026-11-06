//! Subsets for embedding (ADR 0006 steps 2 and 3): the glyphs edited text needs, taken from an
//! installed, bundled or embedded font, through subsetter (`variable-fonts` off; a named instance
//! is written by the `instance` module), with what a PDF writer needs beside the program: the new glyph ids, their widths for `/W`, the text of each
//! glyph for a ToUnicode CMap, a `ABCDEF+Name` font name and the font descriptor's metrics.
//!
//! subsetter makes every subset CID-keyed with CID = new glyph id and drops the `cmap`, so the
//! result is written as a Type0 font with `Identity-H` (or `-V`): a TrueType subset as
//! `/FontFile2` of a `CIDFontType2`, a CFF subset as a bare CID-keyed `/FontFile3` program
//! (`CIDFontType0C`) of a `CIDFontType0`. Embedding permissions (`OS/2.fsType`) are respected: a
//! font that forbids it is refused with the reason ([`Embedding`]).
// A parser module: the program comes from a file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeMap;

use skrifa::instance::{LocationRef, Size};
use skrifa::raw::TableProvider;
use skrifa::raw::types::Tag;
use skrifa::{FontRef, MetadataProvider};

use crate::FontError;
use crate::program::GlyphId;
use crate::type1::MAX_PROGRAM;

/// What a font's `OS/2.fsType` allows (OpenType §OS/2; ADR 0006's table). Where the usage bits
/// are combined, the least restrictive one applies.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Embedding {
    /// 0: installable embedding; also a font without an `OS/2` table.
    Installable,
    /// Bit 3 (0x0008): editable embedding.
    Editable,
    /// Bit 2 (0x0004) alone: preview and print. Never used for new edited text (ADR 0006).
    PreviewAndPrint,
    /// Bit 1 (0x0002) alone: restricted licence embedding. Never embedded.
    Restricted,
    /// Bit 8 (0x0100) with an embeddable usage: the whole font may be embedded, not a subset.
    NoSubsetting,
    /// Bit 9 (0x0200): bitmap embedding only. Ferman embeds outlines, so it is never embedded.
    BitmapOnly,
}

impl Embedding {
    /// The permission of `fs_type`; `None` (no `OS/2` table) is installable.
    #[must_use]
    pub fn from_fs_type(fs_type: Option<u16>) -> Self {
        let Some(fs_type) = fs_type else {
            return Self::Installable;
        };
        if fs_type & 0x0200 != 0 {
            return Self::BitmapOnly;
        }
        let usage = if fs_type & 0x000e == 0 {
            Self::Installable
        } else if fs_type & 0x0008 != 0 {
            Self::Editable
        } else if fs_type & 0x0004 != 0 {
            Self::PreviewAndPrint
        } else {
            Self::Restricted
        };
        if usage.allows_subset() && fs_type & 0x0100 != 0 {
            Self::NoSubsetting
        } else {
            usage
        }
    }

    /// The permission of the font at `index` of `data`; a program without an `OS/2` table (or
    /// that is not an sfnt) is installable.
    #[must_use]
    pub fn of(data: &[u8], index: u32) -> Self {
        Self::from_fs_type(
            FontRef::from_index(data, index)
                .ok()
                .and_then(|font| font.os2().ok())
                .map(|os2| os2.fs_type()),
        )
    }

    /// Whether new edited text may be set in the font: as a subset, or as the whole font for
    /// [`Embedding::NoSubsetting`].
    #[must_use]
    pub fn allows_new_text(self) -> bool {
        matches!(
            self,
            Self::Installable | Self::Editable | Self::NoSubsetting
        )
    }

    /// Whether [`subset`] takes the font.
    #[must_use]
    pub fn allows_subset(self) -> bool {
        matches!(self, Self::Installable | Self::Editable)
    }
}

/// The font program of a [`Subset`], as the PDF embeds it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SubsetProgram {
    /// A TrueType program for `/FontFile2` (`CIDFontType2`).
    TrueType(Vec<u8>),
    /// A bare CID-keyed CFF program for `/FontFile3` with `/Subtype /CIDFontType0C`
    /// (`CIDFontType0`).
    Cff(Vec<u8>),
}

/// One glyph of a [`Subset`].
#[derive(Debug, Clone, PartialEq)]
pub struct SubsetGlyph {
    /// The glyph id in the subset, which is also its CID.
    pub new: u16,
    /// The glyph id in the source font.
    pub old: GlyphId,
    /// The advance width in thousandths of an em, for `/W`.
    pub width: f32,
    /// The text the glyph stands for, for the ToUnicode CMap; empty for none (`.notdef`, the
    /// second glyph of a cluster).
    pub text: String,
}

/// The font descriptor's metrics (ISO 32000-2 §9.8), in thousandths of an em.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Descriptor {
    /// `/Ascent`.
    pub ascent: f32,
    /// `/Descent`, negative below the baseline.
    pub descent: f32,
    /// `/CapHeight`; 70% of the ascent when the font does not say.
    pub cap_height: f32,
    /// `/XHeight`, when the font says.
    pub x_height: Option<f32>,
    /// `/FontBBox`: left, bottom, right, top.
    pub bbox: [f32; 4],
    /// `/ItalicAngle` in degrees, counter-clockwise from vertical.
    pub italic_angle: f32,
    /// `/Flags`: FixedPitch (1), Serif (2), Symbolic (4, always: the subset is a CID font
    /// outside the standard Latin set), Italic (64).
    pub flags: u32,
    /// `/StemV`, estimated from the weight: 50 + (weight / 65)².
    pub stem_v: f32,
}

/// A subset of a font for embedding.
#[derive(Debug, Clone, PartialEq)]
pub struct Subset {
    /// The program.
    pub program: SubsetProgram,
    /// The font name for `/BaseFont` and `/FontName`: a six-letter tag from the glyph set, `+`
    /// and the PostScript name, such as `KQWXRB+IBMPlexSans`.
    pub base_font: String,
    /// The glyphs by new id, `.notdef` (0) first.
    pub glyphs: Vec<SubsetGlyph>,
    /// The descriptor's metrics.
    pub descriptor: Descriptor,
}

impl Subset {
    /// The new id of `old`, if the subset has it.
    #[must_use]
    pub fn new_glyph(&self, old: GlyphId) -> Option<u16> {
        self.glyphs
            .iter()
            .find(|glyph| glyph.old == old)
            .map(|glyph| glyph.new)
    }
}

/// Subsets the font at `index` of `data` (0 unless it is a collection) to `glyphs`, each with the
/// text it stands for ([`crate::ShapedRun::glyph_texts`] gives them). `.notdef` is always kept as
/// glyph 0, with no text. A glyph listed with several texts keeps the shortest non-empty one
/// (the first of equal length). A variable font is subset at its default instance;
/// [`subset_at`] takes a named one.
///
/// # Errors
///
/// [`FontError::ProgramTooLarge`] over [`MAX_PROGRAM`]; [`FontError::Malformed`] for bytes that
/// are not an sfnt, a glyph past the font's glyphs or more than 65,535 glyphs;
/// [`FontError::EmbeddingNotAllowed`] when the font's `fsType` forbids a subset;
/// [`FontError::Subsetting`] when subsetter fails (a `CFF2` font, damaged tables).
pub fn subset(data: &[u8], index: u32, glyphs: &[(GlyphId, String)]) -> Result<Subset, FontError> {
    subset_at(data, index, glyphs, None)
}

/// [`subset`] at the named instance `instance` of a variable font: its outlines, advances,
/// metrics and name.
///
/// # Errors
///
/// As [`subset`].
pub fn subset_at(
    data: &[u8],
    index: u32,
    glyphs: &[(GlyphId, String)],
    instance: Option<&crate::FaceInstance>,
) -> Result<Subset, FontError> {
    if data.len() > MAX_PROGRAM {
        return Err(FontError::ProgramTooLarge {
            size: u64::try_from(data.len()).unwrap_or(u64::MAX),
            max: u64::try_from(MAX_PROGRAM).unwrap_or(u64::MAX),
        });
    }
    let font = FontRef::from_index(data, index).map_err(|_| FontError::Malformed {
        context: "font program for subsetting",
    })?;
    let embedding = Embedding::from_fs_type(font.os2().ok().map(|os2| os2.fs_type()));
    if !embedding.allows_subset() {
        return Err(FontError::EmbeddingNotAllowed { embedding });
    }
    let count = font
        .maxp()
        .map(|maxp| maxp.num_glyphs())
        .map_err(|_| FontError::Malformed { context: "maxp" })?;
    let location = instance.map(|instance| instance.location(&font));
    let location = location
        .as_ref()
        .map_or_else(LocationRef::default, LocationRef::from);
    let metrics = font.metrics(Size::unscaled(), location);
    let upem = f32::from(metrics.units_per_em);
    if metrics.units_per_em == 0 {
        return Err(FontError::Malformed {
            context: "units per em",
        });
    }
    let scale = 1000.0 / upem;

    // Old glyph -> text, .notdef first.
    let mut texts: BTreeMap<u16, String> = BTreeMap::from([(0, String::new())]);
    for (glyph, text) in glyphs {
        let old = u16::try_from(glyph.0)
            .ok()
            .filter(|&old| old < count)
            .ok_or(FontError::Malformed {
                context: "glyph past the font's glyphs",
            })?;
        // .notdef draws nothing, so it never stands for text. A glyph listed with two texts
        // (a decomposed letter's base, also set alone) keeps the shorter one: ToUnicode is per
        // glyph, and the longer text would show up wherever the glyph stands alone.
        let entry = texts.entry(old).or_default();
        if old != 0
            && !text.is_empty()
            && (entry.is_empty() || text.chars().count() < entry.chars().count())
        {
            entry.clone_from(text);
        }
    }
    let mut remapper = subsetter::GlyphRemapper::new();
    for &old in texts.keys() {
        remapper.remap(old);
    }
    let program = subsetter::subset(data, index, &remapper).map_err(|_| FontError::Subsetting)?;
    let advances = font.glyph_metrics(Size::unscaled(), location);
    let program = if font.cff().is_ok() {
        SubsetProgram::Cff(table(&program, Tag::new(b"CFF "))?)
    } else if location.is_default() {
        SubsetProgram::TrueType(program)
    } else {
        // In new-id order: every kept glyph has one, from 0 up.
        let mut order: Vec<(u16, u16)> = Vec::with_capacity(texts.len());
        for &old in texts.keys() {
            let new = remapper.get(old).ok_or(FontError::Internal {
                context: "subset glyph without a new id",
            })?;
            order.push((new, old));
        }
        order.sort_unstable();
        let glyphs: Vec<(u16, f32)> = order
            .iter()
            .map(|&(_, old)| {
                let glyph = skrifa::GlyphId::new(u32::from(old));
                (old, advances.advance_width(glyph).unwrap_or(0.0))
            })
            .collect();
        SubsetProgram::TrueType(crate::instance::instanced(
            &program, &font, location, &glyphs,
        )?)
    };

    let mut subset_glyphs = Vec::with_capacity(texts.len());
    for (old, text) in texts {
        let new = remapper.get(old).ok_or(FontError::Internal {
            context: "subset glyph without a new id",
        })?;
        let width = advances
            .advance_width(skrifa::GlyphId::new(u32::from(old)))
            .unwrap_or(0.0)
            * scale;
        subset_glyphs.push(SubsetGlyph {
            new,
            old: GlyphId(u32::from(old)),
            width,
            text,
        });
    }
    subset_glyphs.sort_by_key(|glyph| glyph.new);

    let postscript_name = instance
        .map(|instance| instance.postscript_name.clone())
        .or_else(|| {
            font.localized_strings(skrifa::string::StringId::POSTSCRIPT_NAME)
                .english_or_first()
                .map(|name| name.to_string())
        })
        .map(|name| {
            name.chars()
                .filter(|c| c.is_ascii_graphic())
                .collect::<String>()
        })
        .filter(|name| !name.is_empty())
        .unwrap_or_else(|| "Font".to_owned());
    let old_ids: Vec<u32> = subset_glyphs.iter().map(|glyph| glyph.old.0).collect();
    let base_font = format!(
        "{}+{postscript_name}",
        subset_tag(&postscript_name, &old_ids)
    );

    Ok(Subset {
        program,
        base_font,
        glyphs: subset_glyphs,
        descriptor: descriptor(
            &font,
            &metrics,
            scale,
            instance.and_then(|instance| instance.value(b"wght")),
        ),
    })
}

/// The descriptor of `font`, scaled to thousandths of an em.
fn descriptor(
    font: &FontRef<'_>,
    metrics: &skrifa::metrics::Metrics,
    scale: f32,
    weight: Option<f32>,
) -> Descriptor {
    let attributes = font.attributes();
    let italic = attributes.style != skrifa::attribute::Style::Normal;
    let mut flags = 4;
    if metrics.is_monospace {
        flags |= 1;
    }
    if crate::matching::is_serif(font) == Some(true) {
        flags |= 2;
    }
    if italic {
        flags |= 64;
    }
    let weight = weight.unwrap_or(attributes.weight.value());
    let bounds = metrics.bounds.unwrap_or_default();
    Descriptor {
        ascent: (metrics.ascent * scale).round(),
        descent: (metrics.descent * scale).round(),
        cap_height: (metrics.cap_height.unwrap_or(metrics.ascent * 0.7) * scale).round(),
        x_height: metrics.x_height.map(|height| (height * scale).round()),
        bbox: [
            (bounds.x_min * scale).round(),
            (bounds.y_min * scale).round(),
            (bounds.x_max * scale).round(),
            (bounds.y_max * scale).round(),
        ],
        italic_angle: metrics.italic_angle,
        flags,
        stem_v: (50.0 + (weight / 65.0) * (weight / 65.0)).round(),
    }
}

/// The table `tag` of the sfnt `program`, copied.
fn table(program: &[u8], tag: Tag) -> Result<Vec<u8>, FontError> {
    let font = FontRef::new(program).map_err(|_| FontError::Subsetting)?;
    font.table_data(tag)
        .map(|data| data.as_bytes().to_vec())
        .ok_or(FontError::Subsetting)
}

/// Six capital letters from the PostScript name and the glyph set, the same for the same glyphs
/// on every run and system (FNV-1a; the standard hasher's output may change between releases).
fn subset_tag(postscript_name: &str, glyphs: &[u32]) -> String {
    let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
    let bytes = postscript_name
        .bytes()
        .chain(glyphs.iter().flat_map(|glyph| glyph.to_le_bytes()));
    for byte in bytes {
        hash ^= u64::from(byte);
        hash = hash.wrapping_mul(0x0100_0000_01b3);
    }
    (0..6)
        .map(|_| {
            let letter = (hash % 26) as u8;
            hash /= 26;
            char::from(b'A'.wrapping_add(letter))
        })
        .collect()
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;
    use crate::program::FontProgram;
    use crate::shape::{Direction, ShapeRequest, ShapingFont};
    use crate::test_fonts::{corpus_font, plex};
    use skrifa::outline::DrawSettings;
    use skrifa::outline::pen::ControlBoundsPen;

    fn glyphs_of(program: &FontProgram<'_>, text: &str) -> Vec<(GlyphId, String)> {
        text.chars()
            .map(|c| (program.glyph_for_char(c).unwrap(), c.to_string()))
            .collect()
    }

    fn has_outline(font: &FontRef<'_>, gid: u16) -> bool {
        let glyph = font
            .outline_glyphs()
            .get(skrifa::GlyphId::new(u32::from(gid)))
            .unwrap();
        let mut pen = ControlBoundsPen::default();
        glyph
            .draw(
                DrawSettings::unhinted(Size::unscaled(), LocationRef::default()),
                &mut pen,
            )
            .unwrap();
        pen.bounding_box().is_some()
    }

    #[test]
    fn embedding_follows_the_fs_type_table() {
        use Embedding::*;
        assert_eq!(Embedding::from_fs_type(None), Installable);
        assert_eq!(Embedding::from_fs_type(Some(0)), Installable);
        assert_eq!(Embedding::from_fs_type(Some(0x0002)), Restricted);
        assert_eq!(Embedding::from_fs_type(Some(0x0004)), PreviewAndPrint);
        assert_eq!(Embedding::from_fs_type(Some(0x0008)), Editable);
        // The least restrictive usage bit applies.
        assert_eq!(Embedding::from_fs_type(Some(0x0006)), PreviewAndPrint);
        assert_eq!(Embedding::from_fs_type(Some(0x000c)), Editable);
        assert_eq!(Embedding::from_fs_type(Some(0x0100)), NoSubsetting);
        assert_eq!(Embedding::from_fs_type(Some(0x0102)), Restricted);
        assert_eq!(Embedding::from_fs_type(Some(0x0200)), BitmapOnly);
        assert_eq!(Embedding::from_fs_type(Some(0x0208)), BitmapOnly);
        assert!(Installable.allows_subset() && Editable.allows_subset());
        assert!(NoSubsetting.allows_new_text() && !NoSubsetting.allows_subset());
        for denied in [PreviewAndPrint, Restricted, BitmapOnly] {
            assert!(!denied.allows_new_text());
        }
    }

    #[test]
    fn truetype_subset_round_trips() {
        let data = plex("ibm-plex-serif/IBMPlexSerif-Regular.ttf");
        let program = FontProgram::parse(&data).unwrap();
        let wanted = glyphs_of(&program, "ğşİ");
        let subset = subset(&data, 0, &wanted).unwrap();
        let SubsetProgram::TrueType(bytes) = &subset.program else {
            panic!("a TrueType source gives a TrueType subset");
        };
        let font = FontRef::new(bytes).unwrap();
        // subsetter also keeps the components of composite glyphs (ğ is g and a breve), after them.
        assert!(font.maxp().unwrap().num_glyphs() >= 4);
        assert_eq!(subset.glyphs.len(), 4);
        assert_eq!(subset.glyphs[0].old, GlyphId(0));
        assert_eq!(subset.glyphs[0].text, "");
        for (old, text) in &wanted {
            let new = subset.new_glyph(*old).unwrap();
            assert!(new > 0);
            assert!(has_outline(&font, new), "{text}");
            let glyph = &subset.glyphs[usize::from(new)];
            assert_eq!(&glyph.text, text);
            // IBM Plex is 1000 units per em: the width is the advance.
            assert_eq!(glyph.width, program.advance_width(*old).unwrap());
        }
        assert!(subset.base_font.ends_with("+IBMPlexSerif-Regular"));
        let tag = &subset.base_font[..6];
        assert!(tag.bytes().all(|b| b.is_ascii_uppercase()));
        assert_eq!(&subset.base_font[6..7], "+");
        let d = subset.descriptor;
        assert_eq!(d.flags & 2, 2, "IBM Plex Serif is a serif");
        assert_eq!(d.flags & 64, 0);
        assert!(d.ascent > 0.0 && d.descent < 0.0 && d.cap_height > 0.0);
        assert!(d.bbox[2] > d.bbox[0] && d.bbox[3] > d.bbox[1]);
        assert_eq!(d.stem_v, 88.0);
    }

    #[test]
    fn the_tag_depends_on_the_glyph_set_only() {
        let data = plex("ibm-plex-sans/IBMPlexSans-Regular.ttf");
        let program = FontProgram::parse(&data).unwrap();
        let a = subset(&data, 0, &glyphs_of(&program, "ab")).unwrap();
        let b = subset(&data, 0, &glyphs_of(&program, "ba")).unwrap();
        let c = subset(&data, 0, &glyphs_of(&program, "abc")).unwrap();
        assert_eq!(a.base_font, b.base_font);
        assert_ne!(a.base_font, c.base_font);
        assert_eq!(a.descriptor.flags & 2, 0, "IBM Plex Sans is a sans");
    }

    #[test]
    fn italic_sets_the_flag_and_angle() {
        let data = plex("ibm-plex-sans/IBMPlexSans-Italic.ttf");
        let program = FontProgram::parse(&data).unwrap();
        let d = subset(&data, 0, &glyphs_of(&program, "a"))
            .unwrap()
            .descriptor;
        assert_eq!(d.flags & 64, 64);
        assert!(d.italic_angle < 0.0);
    }

    #[test]
    fn a_lam_alef_ligature_keeps_both_letters_for_to_unicode() {
        let data = plex("ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf");
        let shaper = ShapingFont::new(data.clone(), 0).unwrap();
        let text = "سلام";
        let run = shaper
            .shape(&ShapeRequest::new(text, Direction::RightToLeft))
            .unwrap();
        let subset = subset(&data, 0, &run.glyph_texts(text)).unwrap();
        let texts: Vec<&str> = subset
            .glyphs
            .iter()
            .map(|glyph| glyph.text.as_str())
            .collect();
        assert!(texts.contains(&"لا"), "{texts:?}");
        assert!(texts.contains(&"س") && texts.contains(&"م"));
        for glyph in &run.glyphs {
            assert!(subset.new_glyph(glyph.glyph).is_some());
        }
    }

    #[test]
    fn notdef_has_no_text_and_a_glyph_keeps_its_shortest_text() {
        let data = plex("ibm-plex-sans/IBMPlexSans-Regular.ttf");
        let program = FontProgram::parse(&data).unwrap();
        let g = program.glyph_for_char('g').unwrap();
        let listed = [
            (GlyphId(0), "\u{628}".to_owned()),
            (g, "g\u{306}".to_owned()),
            (g, "g".to_owned()),
            (g, String::new()),
        ];
        let subset = subset(&data, 0, &listed).unwrap();
        assert_eq!(subset.glyphs.len(), 2);
        assert_eq!(subset.glyphs[0].text, "");
        assert_eq!(subset.glyphs[1].text, "g");
    }

    #[test]
    fn truncated_and_corrupted_fonts_never_panic() {
        let data = plex("ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf");
        let program = FontProgram::parse(&data).unwrap();
        let wanted = glyphs_of(&program, "سa");
        let mut damaged: Vec<Vec<u8>> = [16, 300, data.len() / 3, data.len() / 2]
            .iter()
            .map(|&len| data[..len].to_vec())
            .collect();
        // Every 997th byte flipped: the table directory survives, the tables do not.
        let mut flipped = data.clone();
        for byte in flipped.iter_mut().skip(400).step_by(997) {
            *byte ^= 0xff;
        }
        damaged.push(flipped);
        for bytes in damaged {
            let _ = subset(&bytes, 0, &wanted);
            let _ = crate::StyleMetrics::of(&bytes, 0);
            let _ = Embedding::of(&bytes, 0);
            if let Ok(font) = ShapingFont::new(bytes.clone(), 0) {
                let _ = font.shape(&ShapeRequest::new("سلام abc", Direction::RightToLeft));
            }
            let mut library = crate::FontLibrary::new();
            let _ = library.add_bytes(bytes, crate::FontOrigin::Embedded);
        }
    }

    #[test]
    fn cff_subset_is_a_bare_cid_keyed_program() {
        let Some(data) = corpus_font("SourceSans3-Regular.otf") else {
            return;
        };
        let program = FontProgram::parse(&data).unwrap();
        let wanted = glyphs_of(&program, "ğİ");
        let subset = subset(&data, 0, &wanted).unwrap();
        let SubsetProgram::Cff(cff) = &subset.program else {
            panic!("a CFF source gives a CFF subset");
        };
        let parsed = FontProgram::parse(cff).unwrap();
        assert_eq!(parsed.glyph_count(), 3);
        for (old, _) in &wanted {
            let new = subset.new_glyph(*old).unwrap();
            // CID = new glyph id.
            assert_eq!(
                parsed.glyph_for_cid(u32::from(new)),
                Some(GlyphId(u32::from(new)))
            );
            let width = subset.glyphs[usize::from(new)].width;
            assert_eq!(width, program.advance_width(*old).unwrap());
            assert_eq!(parsed.advance_width(GlyphId(u32::from(new))), Some(width));
        }
        assert!(subset.base_font.ends_with("+SourceSans3-Regular"));
    }

    #[test]
    fn a_variable_font_is_subset_at_its_default_instance() {
        // Step 2 for kira-tr's Madde 6: the installed EB Garamond is a variable font.
        let Some(data) = corpus_font("EBGaramond-VF.ttf") else {
            return;
        };
        let program = FontProgram::parse(&data).unwrap();
        let wanted = glyphs_of(&program, "ğ");
        let subset = subset(&data, 0, &wanted).unwrap();
        let SubsetProgram::TrueType(bytes) = &subset.program else {
            panic!("a TrueType source gives a TrueType subset");
        };
        let font = FontRef::new(bytes).unwrap();
        let new = subset.new_glyph(wanted[0].0).unwrap();
        assert!(has_outline(&font, new));
        let upem = f32::from(program.units_per_em());
        let expected = program.advance_width(wanted[0].0).unwrap() * 1000.0 / upem;
        assert!((subset.glyphs[usize::from(new)].width - expected).abs() < 1e-3);
    }

    #[test]
    fn restricted_fonts_and_bad_input_are_refused() {
        let mut data = plex("ibm-plex-sans/IBMPlexSans-Regular.ttf");
        // Patch OS/2.fsType (offset 8 in the table) to 2, restricted licence embedding.
        let font = FontRef::new(&data).unwrap();
        let os2 = font
            .table_directory
            .table_records()
            .iter()
            .find(|record| record.tag() == Tag::new(b"OS/2"))
            .unwrap()
            .offset() as usize;
        data[os2 + 8..os2 + 10].copy_from_slice(&2u16.to_be_bytes());
        assert!(matches!(
            subset(&data, 0, &[]),
            Err(FontError::EmbeddingNotAllowed {
                embedding: Embedding::Restricted
            })
        ));
        assert!(matches!(
            subset(b"garbage", 0, &[]),
            Err(FontError::Malformed { .. })
        ));
        let data = plex("ibm-plex-sans/IBMPlexSans-Regular.ttf");
        assert!(matches!(
            subset(&data, 0, &[(GlyphId(70_000), String::new())]),
            Err(FontError::Malformed { .. })
        ));
    }
}
