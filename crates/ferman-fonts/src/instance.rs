//! A subset of a variable font at a named instance, as a static TrueType program. subsetter's
//! own instancing needs its `variable-fonts` feature, which brings a second fontations copy into
//! the shipped engine (docs/DEPENDENCIES.md), so the instance's outlines are drawn through skrifa
//! and written here as simple glyphs: `glyf`, `loca`, `hmtx` and the fields of `head`, `hhea` and
//! `maxp` that depend on them. Composites come out flattened and no glyph keeps instructions, so
//! `cvt `, `fpgm` and `prep` go with the other tables a PDF's `/FontFile2` does not need.
// A parser module: the program comes from a file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use skrifa::instance::{LocationRef, Size};
use skrifa::outline::{DrawSettings, OutlinePen};
use skrifa::raw::types::Tag;
use skrifa::{FontRef, MetadataProvider};

use crate::FontError;

/// The contours of one glyph: each point's x, y and whether it is on the curve.
#[derive(Default)]
struct Contours {
    contours: Vec<Vec<(i16, i16, bool)>>,
    /// A cubic segment or a coordinate past 16 bits, which a simple glyph cannot hold.
    failed: bool,
}

impl Contours {
    fn point(&mut self, x: f32, y: f32, on: bool) {
        // The casts saturate; 16 bits are checked by the conversions.
        #[allow(clippy::cast_possible_truncation)]
        let point = (
            i16::try_from(x.round() as i32),
            i16::try_from(y.round() as i32),
        );
        match (point, self.contours.last_mut()) {
            ((Ok(x), Ok(y)), Some(contour)) => contour.push((x, y, on)),
            _ => self.failed = true,
        }
    }
}

impl OutlinePen for Contours {
    fn move_to(&mut self, x: f32, y: f32) {
        self.contours.push(Vec::new());
        self.point(x, y, true);
    }

    fn line_to(&mut self, x: f32, y: f32) {
        self.point(x, y, true);
    }

    fn quad_to(&mut self, cx0: f32, cy0: f32, x: f32, y: f32) {
        self.point(cx0, cy0, false);
        self.point(x, y, true);
    }

    fn curve_to(&mut self, _: f32, _: f32, _: f32, _: f32, _: f32, _: f32) {
        self.failed = true;
    }

    fn close(&mut self) {
        // The pen comes back to the start; a contour closes itself.
        if let Some(contour) = self.contours.last_mut()
            && contour.len() > 1
            && contour.first().map(|p| (p.0, p.1)) == contour.last().map(|p| (p.0, p.1))
            && contour.last().is_some_and(|p| p.2)
        {
            contour.pop();
        }
    }
}

fn put16(out: &mut Vec<u8>, value: u16) {
    out.extend_from_slice(&value.to_be_bytes());
}

/// Writes `value` at `at` of `table`.
fn set16(table: &mut [u8], at: usize, value: u16) -> Option<()> {
    table
        .get_mut(at..at.checked_add(2)?)?
        .copy_from_slice(&value.to_be_bytes());
    Some(())
}

/// The simple glyph of `contours` with its left side bearing and point count; empty for no
/// outline.
fn simple_glyph(contours: &[Vec<(i16, i16, bool)>]) -> Option<(Vec<u8>, i16, usize)> {
    let points = || contours.iter().flatten();
    let Some(x_min) = points().map(|p| p.0).min() else {
        return Some((Vec::new(), 0, 0));
    };
    let x_max = points().map(|p| p.0).max()?;
    let y_min = points().map(|p| p.1).min()?;
    let y_max = points().map(|p| p.1).max()?;
    let mut out = Vec::new();
    put16(&mut out, u16::try_from(contours.len()).ok()?);
    for value in [x_min, y_min, x_max, y_max] {
        out.extend_from_slice(&value.to_be_bytes());
    }
    let mut end = 0_usize;
    for contour in contours {
        end = end.checked_add(contour.len())?;
        put16(&mut out, u16::try_from(end.checked_sub(1)?).ok()?);
    }
    put16(&mut out, 0); // No instructions.
    // On the curve or not, and overlaps allowed: a variable font's contours often overlap.
    for (at, point) in points().enumerate() {
        out.push(u8::from(point.2) | if at == 0 { 0x40 } else { 0 });
    }
    let mut last = 0_i32;
    for point in points() {
        let delta = i32::from(point.0).checked_sub(last)?;
        out.extend_from_slice(&i16::try_from(delta).ok()?.to_be_bytes());
        last = i32::from(point.0);
    }
    last = 0;
    for point in points() {
        let delta = i32::from(point.1).checked_sub(last)?;
        out.extend_from_slice(&i16::try_from(delta).ok()?.to_be_bytes());
        last = i32::from(point.1);
    }
    if out.len() % 2 != 0 {
        out.push(0);
    }
    Some((out, x_min, end))
}

/// A TrueType table's checksum.
fn checksum(table: &[u8]) -> u32 {
    table.chunks(4).fold(0_u32, |sum, chunk| {
        let mut word = [0_u8; 4];
        for (slot, byte) in word.iter_mut().zip(chunk) {
            *slot = *byte;
        }
        sum.wrapping_add(u32::from_be_bytes(word))
    })
}

/// `program`, a TrueType subset of `font` whose glyphs are `glyphs` (the source font's glyph of
/// each new id, with its advance in font units), with its outlines drawn at `location`.
pub(crate) fn instanced(
    program: &[u8],
    font: &FontRef<'_>,
    location: LocationRef<'_>,
    glyphs: &[(u16, f32)],
) -> Result<Vec<u8>, FontError> {
    build(program, font, location, glyphs).ok_or(FontError::Subsetting)
}

fn build(
    program: &[u8],
    font: &FontRef<'_>,
    location: LocationRef<'_>,
    glyphs: &[(u16, f32)],
) -> Option<Vec<u8>> {
    let outlines = font.outline_glyphs();
    let mut glyf = Vec::new();
    let mut loca = Vec::new();
    let mut hmtx = Vec::new();
    let (mut most_points, mut most_contours) = (0_usize, 0_usize);
    let mut widest = 0_u16;
    for &(old, advance) in glyphs {
        let mut pen = Contours::default();
        if let Some(outline) = outlines.get(skrifa::GlyphId::new(u32::from(old))) {
            outline
                .draw(DrawSettings::unhinted(Size::unscaled(), location), &mut pen)
                .ok()?;
        }
        if pen.failed {
            return None;
        }
        let (glyph, lsb, points) = simple_glyph(&pen.contours)?;
        loca.extend_from_slice(&u32::try_from(glyf.len()).ok()?.to_be_bytes());
        glyf.extend_from_slice(&glyph);
        // The saturating cast clamps a damaged advance to the field.
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let advance = advance.round() as u16;
        widest = widest.max(advance);
        put16(&mut hmtx, advance);
        hmtx.extend_from_slice(&lsb.to_be_bytes());
        most_points = most_points.max(points);
        most_contours = most_contours.max(pen.contours.len());
    }
    loca.extend_from_slice(&u32::try_from(glyf.len()).ok()?.to_be_bytes());
    let count = u16::try_from(glyphs.len()).ok()?;

    let source = FontRef::new(program).ok()?;
    let table = |tag: &[u8; 4]| {
        source
            .table_data(Tag::new(tag))
            .map(|data| data.as_bytes().to_vec())
    };
    let mut head = table(b"head")?;
    set16(&mut head, 8, 0)?; // checkSumAdjustment, filled in last.
    set16(&mut head, 10, 0)?;
    set16(&mut head, 50, 1)?; // Long offsets in loca.
    let mut hhea = table(b"hhea")?;
    set16(&mut hhea, 10, widest)?;
    set16(&mut hhea, 34, count)?;
    let mut maxp = table(b"maxp")?;
    set16(&mut maxp, 4, count)?;
    set16(&mut maxp, 6, u16::try_from(most_points).ok()?)?;
    set16(&mut maxp, 8, u16::try_from(most_contours).ok()?)?;
    // Composites and instructions are gone.
    for at in [10, 12, 26, 28, 30] {
        set16(&mut maxp, at, 0)?;
    }

    // In tag order, as the directory wants them.
    let tables: [(&[u8; 4], &[u8]); 6] = [
        (b"glyf", &glyf),
        (b"head", &head),
        (b"hhea", &hhea),
        (b"hmtx", &hmtx),
        (b"loca", &loca),
        (b"maxp", &maxp),
    ];
    let mut out = vec![0, 1, 0, 0];
    // numTables 6, searchRange 4 × 16, entrySelector 2, rangeShift 2 × 16.
    for value in [6_u16, 64, 2, 32] {
        put16(&mut out, value);
    }
    let mut offset = 12_usize.checked_add(16_usize.checked_mul(tables.len())?)?;
    let mut head_at = 0_usize;
    for (tag, data) in tables {
        out.extend_from_slice(tag);
        out.extend_from_slice(&checksum(data).to_be_bytes());
        out.extend_from_slice(&u32::try_from(offset).ok()?.to_be_bytes());
        out.extend_from_slice(&u32::try_from(data.len()).ok()?.to_be_bytes());
        if tag == b"head" {
            head_at = offset;
        }
        offset = offset
            .checked_add(data.len())?
            .checked_next_multiple_of(4)?;
    }
    for (_, data) in tables {
        out.extend_from_slice(data);
        out.resize(out.len().checked_next_multiple_of(4)?, 0);
    }
    let adjustment = 0xB1B0_AFBA_u32.wrapping_sub(checksum(&out));
    out.get_mut(head_at.checked_add(8)?..head_at.checked_add(12)?)?
        .copy_from_slice(&adjustment.to_be_bytes());
    Some(out)
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use skrifa::instance::{LocationRef, Size};
    use skrifa::{FontRef, MetadataProvider};

    use crate::matching::{SameFont, SameFontQuery, find_same_font};
    use crate::program::{FontProgram, GlyphId};
    use crate::subset::{Embedding, SubsetProgram, subset_at};
    use crate::system::{FaceInstance, FontLibrary, FontOrigin};
    use crate::test_fonts::{corpus_font, plex};

    /// The design's typed signatures use Caveat and Dancing Script at 500. Caveat has no named
    /// instance there (its names are Regular and Bold), so a signature gives the coordinates.
    #[test]
    fn the_bundled_handwriting_fonts_subset_at_weight_500() {
        for (path, name) in [
            ("caveat/Caveat-VariableFont_wght.ttf", "Caveat-Medium"),
            (
                "dancing-script/DancingScript-VariableFont_wght.ttf",
                "DancingScript-Medium",
            ),
        ] {
            let data = plex(path);
            assert!(Embedding::of(&data, 0).allows_subset(), "{name}");
            let program = FontProgram::parse(&data).unwrap();
            let glyph = program.glyph_for_char('ş').unwrap();
            let glyphs = [(GlyphId(glyph.0), "ş".to_owned())];
            let at = |wght: i32| FaceInstance {
                postscript_name: name.to_owned(),
                coordinates: vec![(*b"wght", wght * 65536)],
            };
            let medium = subset_at(&data, 0, &glyphs, Some(&at(500))).unwrap();
            let regular = subset_at(&data, 0, &glyphs, Some(&at(400))).unwrap();
            assert!(medium.base_font.ends_with(name), "{}", medium.base_font);
            let (SubsetProgram::TrueType(medium), SubsetProgram::TrueType(regular)) =
                (medium.program, regular.program)
            else {
                panic!("TrueType subsets");
            };
            assert_ne!(medium, regular, "{name}: the outlines follow the weight");
        }
    }

    /// EB Garamond's Bold instance, found by its name, subsets to bold outlines.
    #[test]
    fn a_named_instance_is_found_and_subset_at_its_location() {
        let Some(data) = corpus_font("EBGaramond-VF.ttf") else {
            return;
        };
        let mut library = FontLibrary::new();
        library
            .add_bytes(data.clone(), FontOrigin::Installed)
            .unwrap();
        let font = FontRef::new(&data).unwrap();
        let bold = font
            .named_instances()
            .iter()
            .find(|named| named.user_coords().next() == Some(700.0))
            .unwrap()
            .location();
        let metrics = font.glyph_metrics(Size::unscaled(), LocationRef::from(&bold));
        let program = FontProgram::parse(&data).unwrap();
        let a = program.glyph_for_char('a').unwrap();
        let advance = metrics.advance_width(skrifa::GlyphId::new(a.0)).unwrap();
        let widths = [('a', advance * 1000.0 / f32::from(program.units_per_em()))];
        let query = SameFontQuery {
            postscript_name: "WOGQOY+EBGaramond-Bold",
            family: None,
            weight: 700,
            italic: false,
            stretch: 5,
            units_per_em: Some(program.units_per_em()),
            widths: &widths,
        };
        let SameFont::Found { face, .. } = find_same_font(&library, &query) else {
            panic!("the Bold instance was not found");
        };
        assert_eq!(face.postscript_name, "EBGaramond-Bold");
        assert_eq!(face.weight, 700);
        let instance = face.instance.unwrap();

        let glyphs = [(GlyphId(a.0), "a".to_owned())];
        let subset = subset_at(&data, 0, &glyphs, Some(&instance)).unwrap();
        assert!(subset.base_font.ends_with("+EBGaramond-Bold"));
        assert!((subset.glyphs[1].width - widths[0].1).abs() < 0.01);
        let SubsetProgram::TrueType(written) = subset.program else {
            panic!("a TrueType subset");
        };
        // The written glyph is the instance's: the same extent as its outline at that location.
        let written = FontRef::new(&written).unwrap();
        let area = |font: &FontRef<'_>, glyph: u32, location: LocationRef<'_>| {
            let mut bounds = crate::instance::Contours::default();
            font.outline_glyphs()
                .get(skrifa::GlyphId::new(glyph))
                .unwrap()
                .draw(
                    skrifa::outline::DrawSettings::unhinted(Size::unscaled(), location),
                    &mut bounds,
                )
                .unwrap();
            bounds.contours
        };
        let expected = area(&font, a.0, LocationRef::from(&bold));
        let found = area(&written, 1, LocationRef::default());
        assert_eq!(found.len(), expected.len());
        let regular = area(&font, a.0, LocationRef::default());
        assert_ne!(found, regular, "the default instance's outline");
        assert_eq!(
            found.iter().map(Vec::len).sum::<usize>(),
            expected.iter().map(Vec::len).sum::<usize>()
        );
    }
}
