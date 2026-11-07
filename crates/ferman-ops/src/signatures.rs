//! Simple signatures and initials (M4 plan, W3, decisions 20 to 23, G148, G149, G158): typed in
//! a handwriting style, drawn, or from a photo or scan, placed as a stamp annotation. On a
//! signature field the stamp carries [`SIGNED_FIELD_KEY`] naming it; `/V` is never written, so the
//! file never reads as digitally signed and a certificate signature can still follow.
//!
//! A typed signature is drawn only in its own style: a letter the style lacks refuses the
//! signature, and [`handwriting_styles`] says beforehand which styles can draw a name. An image
//! goes through the image layer's limits, loses its paper (light pixels become transparent) and is
//! cropped to its ink.

use ferman_core::forms::{FieldKind, SIGNED_FIELD_KEY};
use ferman_core::limits::Limits;
use ferman_core::revision::RevisionStore;
use ferman_core::write::{Value, text_value};
use ferman_core::{CoreError, Document, WriteError};
use ferman_fonts::{FaceInstance, FontLibrary, FontProgram};
use image::metadata::Orientation;
use image::{DynamicImage, GenericImageView, GrayImage, RgbImage};

use crate::OpsError;
use crate::annotations::{
    Faces, Ops, SetLine, appearance_entry, check_coordinates, common_entries, form_with, name,
    normalized, numbers, page_turn, plan_error, right_to_left, set_text, tilted,
};
use crate::images::{self, Colour, Image, Pixels};

/// The handwriting styles of a typed signature (a5-3): family, and the PostScript name and weight
/// of the instance a variable one is drawn at. Caveat and Dancing Script are drawn at 500, as the
/// design draws them; Homemade Apple has one weight.
pub const HANDWRITING: [(&str, Option<(&str, u16)>); 3] = [
    ("Caveat", Some(("Caveat-Medium", 500))),
    ("Dancing Script", Some(("DancingScript-Medium", 500))),
    ("Homemade Apple", None),
];

/// `/Name` of a signature's stamp, and of initials'.
pub const SIGNATURE_NAME: &str = "FermanSignature";
/// See [`SIGNATURE_NAME`].
pub const INITIALS_NAME: &str = "FermanInitials";

/// The longest typed signature, in bytes.
const LONGEST_TEXT: usize = 256;
/// The most points of a drawn one.
const MOST_POINTS: usize = 100_000;
/// Drawn coordinates and widths past this are no pad's.
const LARGEST_DRAWN: f32 = 100_000.0;
/// A typed signature's size against its box's height, and its width's share of the box.
const TYPED_HEIGHT: f32 = 0.62;
const TYPED_WIDTH: f32 = 0.94;
/// Pixels at least this light are paper; at most [`INK`], ink; between, partly both.
const PAPER: f32 = 225.0;
const INK: f32 = 150.0;
/// The least opacity a pixel needs to count as ink when cropping.
const INKED: u8 = 24;

/// What a signature is drawn from.
#[derive(Debug, Clone, PartialEq)]
pub enum Ink {
    /// A name typed in one of [`HANDWRITING`]'s families.
    Typed {
        /// The name.
        text: String,
        /// The family.
        family: String,
    },
    /// Strokes from a pad, in its units with y down; cropped to their ink.
    Drawn {
        /// Each stroke's points.
        strokes: Vec<Vec<[f32; 2]>>,
        /// The pen's width, in the pad's units.
        width: f32,
    },
    /// The bytes of a PNG, JPEG, TIFF, WebP or GIF file.
    Image(Vec<u8>),
}

/// A signature to place, in user space.
#[derive(Debug, Clone, PartialEq)]
pub struct NewSignature {
    /// Its box before its tilt; the ink is fitted into it, keeping its shape.
    pub rect: [f32; 4],
    /// What it is drawn from.
    pub ink: Ink,
    /// A typed or drawn signature's colour.
    pub color: [f32; 3],
    /// Its turn in degrees; negative turns anticlockwise.
    pub tilt: f32,
    /// Initials rather than a signature.
    pub initials: bool,
    /// The full name of the signature field it signs (decisions 20 and 21).
    pub field: Option<String>,
    /// `/T`.
    pub author: String,
}

/// Whether each of [`HANDWRITING`]'s families can draw every letter of `text`, in order (decision
/// 23). A family the library does not have cannot.
#[must_use]
pub fn handwriting_styles(library: &FontLibrary, text: &str) -> Vec<(&'static str, bool)> {
    HANDWRITING
        .iter()
        .map(|(family, _)| {
            let covered = library
                .faces()
                .find(|face| face.family == *family && !face.italic && face.instance.is_none())
                .and_then(|face| {
                    library.with_data(face.id, |data, _| {
                        FontProgram::parse(data).is_ok_and(|program| {
                            text.chars()
                                .filter(|c| !c.is_whitespace() && !c.is_control())
                                .all(|c| program.glyph_for_char(c).is_some())
                        })
                    })
                })
                .unwrap_or(false);
            (*family, covered)
        })
        .collect()
}

/// `image` upright, its paper made transparent and cut away to the ink.
fn inked(image: Image, limits: &Limits) -> Result<Image, OpsError> {
    let samples = match image.pixels {
        Pixels::Samples(samples) => samples,
        Pixels::Dct(jpeg) => match images::decode_dct(&jpeg, limits)?.pixels {
            Pixels::Samples(samples) => samples,
            Pixels::Dct(_) => return Err(OpsError::UnreadableImage),
        },
    };
    let (width, height) = (image.width, image.height);
    let mut picture = match image.colour {
        Colour::Gray => GrayImage::from_raw(width, height, samples).map(DynamicImage::ImageLuma8),
        Colour::Rgb => RgbImage::from_raw(width, height, samples).map(DynamicImage::ImageRgb8),
        // decode_dct gives no CMYK.
        Colour::Cmyk { .. } => None,
    }
    .ok_or(OpsError::UnreadableImage)?
    .into_rgba8();
    if let Some(alpha) = &image.alpha {
        for (pixel, kept) in picture.pixels_mut().zip(alpha) {
            pixel.0[3] = *kept;
        }
    }
    let mut picture = DynamicImage::ImageRgba8(picture);
    picture.apply_orientation(image.orientation);
    let mut picture = picture.into_rgba8();
    let mut bounds: Option<[u32; 4]> = None;
    for (x, y, pixel) in picture.enumerate_pixels_mut() {
        let [r, g, b, a] = pixel.0;
        let light = 0.299 * f32::from(r) + 0.587 * f32::from(g) + 0.114 * f32::from(b);
        let ink = ((PAPER - light) / (PAPER - INK)).clamp(0.0, 1.0);
        // A share of 255.
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let alpha = (f32::from(a) * ink).round() as u8;
        pixel.0[3] = alpha;
        if alpha >= INKED {
            bounds = Some(bounds.map_or([x, y, x, y], |[l, t, r, b]| {
                [l.min(x), t.min(y), r.max(x), b.max(y)]
            }));
        }
    }
    let [l, t, r, b] = bounds.ok_or(OpsError::UnreadableImage)?;
    let cropped = picture.view(l, t, r - l + 1, b - t + 1).to_image();
    let (width, height) = cropped.dimensions();
    let mut rgb = Vec::with_capacity(cropped.len() / 4 * 3);
    let mut alpha = Vec::with_capacity(cropped.len() / 4);
    for pixel in cropped.pixels() {
        rgb.extend_from_slice(&pixel.0[..3]);
        alpha.push(pixel.0[3]);
    }
    Ok(Image {
        width,
        height,
        colour: Colour::Rgb,
        pixels: Pixels::Samples(rgb),
        alpha: Some(alpha),
        orientation: Orientation::NoTransforms,
        icc: image.icc.filter(|_| image.colour == Colour::Rgb),
    })
}

/// The scale and offset that fit `[l, t, r, b]` in a box `w` by `h` about the origin, keeping its
/// shape, y turned up.
fn fit([l, t, r, b]: [f32; 4], w: f32, h: f32) -> (f32, [f32; 2]) {
    let (iw, ih) = ((r - l).max(1e-3), (b - t).max(1e-3));
    let scale = (w / iw).min(h / ih);
    (scale, [f32::midpoint(l, r), f32::midpoint(t, b)])
}

/// The operators of `ink` in a box `w` by `h` whose middle is the origin, and the resources they
/// need.
fn draw(
    document: &Document,
    revisions: &mut RevisionStore,
    ops: &mut Ops,
    new: &NewSignature,
    (w, h): (f32, f32),
    library: &FontLibrary,
    limits: &Limits,
) -> Result<Vec<(Vec<u8>, Value)>, OpsError> {
    match &new.ink {
        Ink::Typed { text, family } => {
            let text = text.trim();
            let style = HANDWRITING
                .iter()
                .find(|(name, _)| name == family)
                .ok_or_else(plan_error)?;
            if text.is_empty() || text.len() > LONGEST_TEXT || text.contains(['\n', '\r']) {
                return Err(plan_error());
            }
            let instance = style.1.map(|(postscript_name, weight)| FaceInstance {
                postscript_name: postscript_name.to_owned(),
                coordinates: vec![(*b"wght", i32::from(weight) * 65_536)],
            });
            let mut faces = Faces::only(library, style.0, 400, instance);
            let (glyphs, wide) = faces.shape_line(text, right_to_left(text), 0.0)?;
            let size = (h * TYPED_HEIGHT).min(w * TYPED_WIDTH / wide.max(1e-3));
            let line = SetLine {
                glyphs,
                x: -wide * size / 2.0,
                baseline: -size * 0.25,
                size,
                color: new.color,
            };
            let fonts = set_text(document, revisions, ops, &faces, &[line], (0.0, 0.0))?;
            Ok(vec![(b"Font".to_vec(), fonts)])
        }
        Ink::Drawn { strokes, width } => {
            let points = strokes.iter().map(Vec::len).sum::<usize>();
            if points == 0
                || points > MOST_POINTS
                || !(width.is_finite() && *width > 0.0 && *width <= LARGEST_DRAWN)
                || strokes
                    .iter()
                    .flatten()
                    .flatten()
                    .any(|v| !v.is_finite() || v.abs() > LARGEST_DRAWN)
            {
                return Err(plan_error());
            }
            let half = width / 2.0;
            let mut area = [f32::MAX, f32::MAX, f32::MIN, f32::MIN];
            for [x, y] in strokes.iter().flatten() {
                area = [
                    area[0].min(x - half),
                    area[1].min(y - half),
                    area[2].max(x + half),
                    area[3].max(y + half),
                ];
            }
            let (scale, [cx, cy]) = fit(area, w, h);
            ops.stroke_colour(new.color)
                .nums(&[width * scale], "w")
                .op("1 J 1 j");
            for stroke in strokes.iter().filter(|stroke| !stroke.is_empty()) {
                let at = |[x, y]: [f32; 2]| [(x - cx) * scale, (cy - y) * scale];
                let mut points = stroke.iter().map(|point| at(*point));
                if let Some(first) = points.next() {
                    ops.moved(first);
                    // A dot is a stroke to itself, which the round cap draws.
                    ops.line(first);
                    for point in points {
                        ops.line(point);
                    }
                    ops.op("S");
                }
            }
            Ok(Vec::new())
        }
        Ink::Image(bytes) => {
            let image = inked(images::load(bytes, limits)?, limits)?;
            let xobject = images::image_xobject(document, revisions, &image)?;
            #[allow(clippy::cast_precision_loss)]
            let (iw, ih) = (image.width as f32, image.height as f32);
            let (scale, _) = fit([0.0, 0.0, iw, ih], w, h);
            let (dw, dh) = (iw * scale, ih * scale);
            ops.op("q")
                .nums(&[dw, 0.0, 0.0, dh, -dw / 2.0, -dh / 2.0], "cm")
                .op("/Im0 Do")
                .op("Q");
            Ok(vec![(
                b"XObject".to_vec(),
                Value::Dictionary(vec![(b"Im0".to_vec(), Value::Reference(xobject))]),
            )])
        }
    }
}

/// Places `new` on page `page` as a stamp annotation with its appearance, and returns its handle.
/// `now` is a PDF date; `library` has the handwriting fonts; `limits` bound an image.
///
/// # Errors
///
/// [`WriteError::AnnotationPlan`] for a box, colour, text, stroke or style out of range, or a
/// field that is no signature field, is signed or has a simple signature already;
/// [`OpsError::NoFontForText`] for a letter the style cannot draw; [`OpsError::UnreadableImage`]
/// for an image with no ink or none Ferman reads, [`CoreError::ResourceLimit`] for one past the
/// limits; and the errors of the transaction.
pub fn place(
    document: &Document,
    revisions: &mut RevisionStore,
    page: usize,
    new: &NewSignature,
    now: &str,
    library: &FontLibrary,
    limits: &Limits,
) -> Result<u64, OpsError> {
    check_coordinates(new.rect)?;
    let [l, b, r, t] = normalized(new.rect);
    if r - l <= 0.0
        || t - b <= 0.0
        || !new.tilt.is_finite()
        || !new.color.iter().all(|v| (0.0..=1.0).contains(v))
        || new.author.len() > LONGEST_TEXT * 4
    {
        return Err(plan_error());
    }
    if let Some(field) = &new.field {
        let form = revisions.form_fields(document);
        let fine = form.fields.iter().any(|candidate| {
            candidate.name == *field
                && candidate.kind == FieldKind::Signature
                && !candidate.signed
                && candidate.signature.is_none()
        });
        if !fine {
            return Err(plan_error());
        }
    }
    let turn = page_turn(document, revisions, page)?;
    let page_ref = revisions
        .page_refs(document, &[page])?
        .first()
        .copied()
        .ok_or(CoreError::Write(WriteError::NoSuchPage))?;

    let mut ops = Ops::default();
    ops.op("q");
    let (rect, w, h) = tilted(&mut ops, new.rect, new.tilt, turn, 0.0);
    let resources = draw(document, revisions, &mut ops, new, (w, h), library, limits)?;
    ops.op("Q");
    let form = form_with(document, revisions, rect, ops, resources)?;

    let id = revisions.allocate()?;
    let mut entries = common_entries(b"Stamp", page_ref, id, &new.author, now);
    let icon = if new.initials {
        INITIALS_NAME
    } else {
        SIGNATURE_NAME
    };
    entries.push((b"Name".to_vec(), name(icon.as_bytes())));
    entries.push((b"F".to_vec(), Value::Integer(4)));
    entries.push((b"C".to_vec(), numbers(new.color)));
    // An integer turn, as a stamp's.
    #[allow(clippy::cast_possible_truncation)]
    let turned = (i64::from(turn) - new.tilt.round() as i64).rem_euclid(360);
    if turned != 0 {
        entries.push((b"Rotate".to_vec(), Value::Integer(turned)));
    }
    if let Some(field) = &new.field {
        entries.push((SIGNED_FIELD_KEY.to_vec(), text_value(field)));
    }
    entries.push((b"Rect".to_vec(), numbers(rect)));
    entries.push((b"AP".to_vec(), appearance_entry(form)));
    revisions.replace_object(document, id, Value::Dictionary(entries))?;
    revisions.append_annotation(document, page, id)?;
    Ok(id.handle())
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;
    use std::path::PathBuf;
    use std::sync::Arc;

    use ferman_core::{OpenOptions, Source, open};
    use ferman_fonts::{FontOrigin, ScanLimits};
    use image::{ImageFormat, Rgb};

    use super::*;

    const NOW: &str = "D:20261107120000Z";

    fn library() -> FontLibrary {
        let mut library = FontLibrary::new();
        library.add_dir(
            &PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../app/assets/fonts"),
            FontOrigin::Bundled,
            &ScanLimits::default(),
        );
        library
    }

    fn form() -> (Document, RevisionStore) {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated/form-aks1-tr.pdf");
        let bytes = std::fs::read(path).unwrap();
        let doc = open(
            &Source::from_bytes(Arc::from(&bytes[..])),
            &OpenOptions::default(),
        )
        .unwrap();
        let store = RevisionStore::new(&doc);
        (doc, store)
    }

    fn signature(ink: Ink) -> NewSignature {
        NewSignature {
            rect: [100.0, 100.0, 260.0, 140.0],
            ink,
            color: [0.1, 0.1, 0.4],
            tilt: -2.0,
            initials: false,
            field: None,
            author: "Ayşe Yılmaz".to_owned(),
        }
    }

    #[test]
    fn the_styles_say_which_can_write_a_name() {
        let library = library();
        let covered = |text| -> Vec<bool> {
            handwriting_styles(&library, text)
                .into_iter()
                .map(|(_, covered)| covered)
                .collect()
        };
        assert_eq!(covered("Ayse Yilmaz"), [true, true, true]);
        // G158: Homemade Apple has no ş.
        assert_eq!(covered("Ayşe Yılmaz"), [true, true, false]);
        // Decision 23: none draws Arabic.
        assert_eq!(covered("أحمد"), [false, false, false]);
    }

    #[test]
    fn a_typed_signature_is_drawn_only_in_its_style() {
        let library = library();
        let (doc, mut store) = form();
        store.begin().unwrap();
        let typed = |text: &str, family: &str| {
            signature(Ink::Typed {
                text: text.to_owned(),
                family: family.to_owned(),
            })
        };
        let limits = Limits::default();
        let placed = place(
            &doc,
            &mut store,
            0,
            &typed("Ayşe Yılmaz", "Caveat"),
            NOW,
            &library,
            &limits,
        );
        assert!(placed.is_ok(), "{placed:?}");
        assert!(matches!(
            place(
                &doc,
                &mut store,
                0,
                &typed("Ayşe Yılmaz", "Homemade Apple"),
                NOW,
                &library,
                &limits
            ),
            Err(OpsError::NoFontForText)
        ));
        for bad in [typed("", "Caveat"), typed("Ayşe", "Comic Sans")] {
            assert!(place(&doc, &mut store, 0, &bad, NOW, &library, &limits).is_err());
        }
    }

    #[test]
    fn a_field_is_signed_once_and_only_a_signature_field() {
        let library = library();
        let (doc, mut store) = form();
        store.begin().unwrap();
        let limits = Limits::default();
        let on = |field: &str| NewSignature {
            field: Some(field.to_owned()),
            ..signature(Ink::Drawn {
                strokes: vec![vec![[0.0, 0.0], [10.0, 5.0]], vec![[3.0, 3.0]]],
                width: 1.0,
            })
        };
        assert!(place(&doc, &mut store, 0, &on("adi"), NOW, &library, &limits).is_err());
        let handle = place(&doc, &mut store, 0, &on("imza"), NOW, &library, &limits).unwrap();
        let fields = store.form_fields(&doc);
        let signed = fields.fields.iter().find(|f| f.name == "imza").unwrap();
        assert_eq!(signed.signature, Some(handle));
        assert!(!signed.signed);
        assert!(place(&doc, &mut store, 0, &on("imza"), NOW, &library, &limits).is_err());
    }

    #[test]
    fn an_image_loses_its_paper_and_is_cut_to_its_ink() {
        let mut picture = RgbImage::from_pixel(40, 20, Rgb([250, 248, 240]));
        for x in 10..30 {
            picture.put_pixel(x, 8, Rgb([20, 20, 120]));
            picture.put_pixel(x, 9, Rgb([20, 20, 120]));
        }
        let mut png = Cursor::new(Vec::new());
        DynamicImage::ImageRgb8(picture)
            .write_to(&mut png, ImageFormat::Png)
            .unwrap();
        let limits = Limits::default();
        let image = inked(images::load(png.get_ref(), &limits).unwrap(), &limits).unwrap();
        assert_eq!((image.width, image.height), (20, 2));
        assert!(image.alpha.as_ref().unwrap().iter().all(|a| *a == 255));

        let blank = RgbImage::from_pixel(8, 8, Rgb([255, 255, 255]));
        let mut png = Cursor::new(Vec::new());
        DynamicImage::ImageRgb8(blank)
            .write_to(&mut png, ImageFormat::Png)
            .unwrap();
        let blank = images::load(png.get_ref(), &limits).unwrap();
        assert!(matches!(
            inked(blank, &limits),
            Err(OpsError::UnreadableImage)
        ));
    }
}
