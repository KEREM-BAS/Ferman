//! Raster images: a file's bytes to an [`Image`] within [`Limits::max_image_pixels`], and an image
//! to a PDF image XObject or a page of its own, inside the open transaction of a [`RevisionStore`].
//!
//! Bytes here are untrusted. A JPEG passes through as `DCTDecode` without re-encoding; everything
//! else is decoded to 8-bit samples, written with Flate, its alpha as an `/SMask`. An image's own
//! page turns it as its EXIF orientation says, through the page's matrix, and a profile fit for its
//! colours goes along as an `/ICCBased` space (B187).
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::io::Cursor;

use ferman_core::CoreError;
use ferman_core::Document;
use ferman_core::limits::{LimitKind, Limits};
use ferman_core::revision::RevisionStore;
use ferman_core::write::{ObjectRef, Value};
use image::metadata::Orientation;
use image::{DynamicImage, ImageDecoder, ImageError, ImageFormat, ImageReader};

use crate::OpsError;

/// How an [`Image`]'s pixels hold colour.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Colour {
    /// One component a pixel.
    Gray,
    /// Three components a pixel.
    Rgb,
    /// Four components a pixel, only ever in a passed-through JPEG.
    Cmyk {
        /// Stored inverted, as Adobe's programs write it: the XObject needs a reversed `/Decode`.
        inverted: bool,
    },
}

/// An [`Image`]'s pixels.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Pixels {
    /// A whole JPEG file.
    Dct(Vec<u8>),
    /// 8-bit samples by row, with no padding.
    Samples(Vec<u8>),
}

/// An image ready for a PDF.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Image {
    /// Width in pixels, at least 1.
    pub width: u32,
    /// Height in pixels, at least 1.
    pub height: u32,
    /// How [`pixels`](Self::pixels) hold colour.
    pub colour: Colour,
    /// The pixels.
    pub pixels: Pixels,
    /// One 8-bit alpha sample a pixel, `None` when the image has none or is wholly opaque.
    pub alpha: Option<Vec<u8>>,
    /// How the stored pixels turn to show upright.
    pub orientation: Orientation,
    /// The ICC profile, when it describes [`colour`](Self::colour).
    pub icc: Option<Vec<u8>>,
}

/// The paper of an image's own page, which the caller picks from the region setting (G152).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Paper {
    /// 595.28 × 841.89 pt.
    A4,
    /// 612 × 792 pt.
    Letter,
}

impl Paper {
    /// Width and height in points.
    #[must_use]
    pub fn size(self) -> (f32, f32) {
        match self {
            Self::A4 => (595.28, 841.89),
            Self::Letter => (612.0, 792.0),
        }
    }
}

/// `bytes` of a PNG, JPEG, TIFF, WebP or GIF file as an image: a JPEG as it is, the others decoded,
/// a GIF's or WebP's animation by its first frame.
///
/// # Errors
///
/// [`OpsError::UnreadableImage`], and [`CoreError::ResourceLimit`] past
/// [`Limits::max_image_pixels`], which stops the work before pixels are decoded.
pub fn load(bytes: &[u8], limits: &Limits) -> Result<Image, OpsError> {
    let reader = ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()
        .map_err(|_| OpsError::UnreadableImage)?;
    match reader.format() {
        Some(ImageFormat::Jpeg) => pass_through(bytes, limits),
        Some(ImageFormat::Png | ImageFormat::Tiff | ImageFormat::WebP | ImageFormat::Gif) => {
            decoded(reader, limits)
        }
        _ => Err(OpsError::UnreadableImage),
    }
}

/// A JPEG's pixels as gray or RGB samples, for what must see them, such as Compress. A CMYK JPEG
/// with the Adobe marker comes out as RGB.
///
/// # Errors
///
/// As [`load`], and [`OpsError::UnreadableImage`] for a CMYK JPEG without the marker: the decoder
/// takes every CMYK as Adobe's inverted kind, which would turn this one into its negative, and
/// inverting its RGB afterwards is not the same conversion. Compress leaves such an image as it
/// is (decision 26).
pub fn decode_dct(bytes: &[u8], limits: &Limits) -> Result<Image, OpsError> {
    let header = jpeg_header(bytes).ok_or(OpsError::UnreadableImage)?;
    if header.colour == (Colour::Cmyk { inverted: false }) {
        return Err(OpsError::UnreadableImage);
    }
    decoded(
        ImageReader::with_format(Cursor::new(bytes), ImageFormat::Jpeg),
        limits,
    )
}

fn within(width: u32, height: u32, limits: &Limits) -> Result<(), OpsError> {
    let max = limits.max_image_pixels;
    if u64::from(width).saturating_mul(u64::from(height)) > max {
        return Err(too_many_pixels(max));
    }
    Ok(())
}

fn too_many_pixels(max: u64) -> OpsError {
    CoreError::ResourceLimit {
        limit: LimitKind::ImagePixels,
        max,
    }
    .into()
}

fn pass_through(bytes: &[u8], limits: &Limits) -> Result<Image, OpsError> {
    let header = jpeg_header(bytes).ok_or(OpsError::UnreadableImage)?;
    within(header.width, header.height, limits)?;
    // Headers only; a file its decoder refuses is drawn as stored, by whoever can read it.
    let (orientation, icc) = ImageReader::with_format(Cursor::new(bytes), ImageFormat::Jpeg)
        .into_decoder()
        .map_or((Orientation::NoTransforms, None), |mut decoder| {
            metadata(&mut decoder)
        });
    Ok(Image {
        width: header.width,
        height: header.height,
        colour: header.colour,
        pixels: Pixels::Dct(bytes.to_vec()),
        alpha: None,
        orientation,
        icc: icc.filter(|profile| describes(profile, header.colour)),
    })
}

/// A decoder's orientation and ICC profile. A file that says neither clearly says nothing.
fn metadata(decoder: &mut impl ImageDecoder) -> (Orientation, Option<Vec<u8>>) {
    (
        decoder.orientation().unwrap_or(Orientation::NoTransforms),
        decoder.icc_profile().ok().flatten(),
    )
}

/// Whether an ICC `profile`'s header names `colour`'s space: a reader would misread it otherwise.
fn describes(profile: &[u8], colour: Colour) -> bool {
    /// Where an ICC header holds the data colour space.
    const SPACE: std::ops::Range<usize> = 16..20;
    const HEADER: usize = 128;
    let wanted: &[u8] = match colour {
        Colour::Gray => b"GRAY",
        Colour::Rgb => b"RGB ",
        Colour::Cmyk { .. } => b"CMYK",
    };
    profile.len() >= HEADER && profile.get(SPACE) == Some(wanted)
}

fn decoded(mut reader: ImageReader<Cursor<&[u8]>>, limits: &Limits) -> Result<Image, OpsError> {
    let max = limits.max_image_pixels;
    let mut allocation = image::Limits::default();
    // Eight bytes a pixel is the widest output these formats' decoders give but floats, which only
    // TIFF has; the decoder refuses the rest. Past the image crate's default of 512 MiB on purpose:
    // `max_image_pixels` is what decides here.
    allocation.max_alloc = Some(max.saturating_mul(8));
    reader.limits(allocation);
    let unreadable = |error| match error {
        ImageError::Limits(_) => too_many_pixels(max),
        _ => OpsError::UnreadableImage,
    };
    let mut decoder = reader.into_decoder().map_err(unreadable)?;
    let (orientation, icc) = metadata(&mut decoder);
    let (width, height) = decoder.dimensions();
    if width == 0 || height == 0 {
        return Err(OpsError::UnreadableImage);
    }
    within(width, height, limits)?;
    let image = DynamicImage::from_decoder(decoder).map_err(unreadable)?;
    let kind = image.color();
    let alpha = kind
        .has_alpha()
        .then(|| {
            image
                .to_luma_alpha8()
                .pixels()
                .map(|pixel| pixel.0[1])
                .collect::<Vec<u8>>()
        })
        .filter(|alpha| alpha.iter().any(|&sample| sample != u8::MAX));
    let (colour, samples) = if kind.has_color() {
        (Colour::Rgb, image.into_rgb8().into_raw())
    } else {
        (Colour::Gray, image.into_luma8().into_raw())
    };
    Ok(Image {
        width,
        height,
        colour,
        pixels: Pixels::Samples(samples),
        alpha,
        orientation,
        icc: icc.filter(|profile| describes(profile, colour)),
    })
}

struct JpegHeader {
    width: u32,
    height: u32,
    colour: Colour,
}

/// What a PDF needs from a JPEG's segments, `None` unless it has a baseline, extended or
/// progressive 8-bit frame and a scan: the image crate reports CMYK as RGB, and this says which.
fn jpeg_header(bytes: &[u8]) -> Option<JpegHeader> {
    let mut rest = bytes.strip_prefix(&[0xFF, 0xD8])?;
    let mut frame = None;
    let mut adobe = false;
    loop {
        // A marker is 0xFF, any fill bytes, then its code.
        let code_at = rest
            .iter()
            .position(|&byte| byte != 0xFF)
            .filter(|&at| at > 0)?;
        let code = *rest.get(code_at)?;
        rest = rest.get(code_at.checked_add(1)?..)?;
        let &[high, low, ..] = rest else { return None };
        let length = usize::from(u16::from_be_bytes([high, low]));
        let body = rest.get(2..length)?;
        match code {
            0xC0..=0xC2 => {
                let &[8, h1, h0, w1, w0, components, ..] = body else {
                    return None;
                };
                if frame.is_some() {
                    return None;
                }
                frame = Some((
                    u16::from_be_bytes([w1, w0]),
                    u16::from_be_bytes([h1, h0]),
                    components,
                ));
            }
            // Lossless, hierarchical and arithmetic frames; the codes among them that are not
            // frames (C4 tables, C8 reserved, CC arithmetic tables) carry nothing for us.
            0xC3 | 0xC5..=0xC7 | 0xC9..=0xCB | 0xCD..=0xCF => return None,
            0xEE if body.starts_with(b"Adobe") => adobe = true,
            0xDA => {
                let (width, height, components) = frame?;
                if width == 0 || height == 0 {
                    return None;
                }
                let colour = match components {
                    1 => Colour::Gray,
                    3 => Colour::Rgb,
                    4 => Colour::Cmyk { inverted: adobe },
                    _ => return None,
                };
                return Some(JpegHeader {
                    width: width.into(),
                    height: height.into(),
                    colour,
                });
            }
            _ => {}
        }
        rest = rest.get(length..)?;
    }
}

/// Adds `image` as an image XObject in the open transaction, with its alpha as an `/SMask`.
///
/// # Errors
///
/// Those of [`RevisionStore::add_object`], as [`OpsError::Core`]; samples past
/// [`Limits::max_stream_decoded`] are among them.
pub fn image_xobject(
    document: &Document,
    revisions: &mut RevisionStore,
    image: &Image,
) -> Result<ObjectRef, OpsError> {
    let frame = |space: &[u8]| {
        vec![
            (b"Type".to_vec(), Value::Name(b"XObject".to_vec())),
            (b"Subtype".to_vec(), Value::Name(b"Image".to_vec())),
            (b"Width".to_vec(), Value::Integer(image.width.into())),
            (b"Height".to_vec(), Value::Integer(image.height.into())),
            (b"ColorSpace".to_vec(), Value::Name(space.to_vec())),
            (b"BitsPerComponent".to_vec(), Value::Integer(8)),
        ]
    };
    let mut dict = frame(match image.colour {
        Colour::Gray => b"DeviceGray",
        Colour::Rgb => b"DeviceRGB",
        Colour::Cmyk { .. } => b"DeviceCMYK",
    });
    if matches!(image.colour, Colour::Cmyk { inverted: true }) {
        let decode = [1, 0, 1, 0, 1, 0, 1, 0].map(Value::Integer).to_vec();
        dict.push((b"Decode".to_vec(), Value::Array(decode)));
    }
    if let Some(profile) = &image.icc {
        let components = match image.colour {
            Colour::Gray => 1,
            Colour::Rgb => 3,
            Colour::Cmyk { .. } => 4,
        };
        let profile = revisions.add_object(
            document,
            Value::Stream {
                dict: vec![(b"N".to_vec(), Value::Integer(components))],
                data: profile.clone(),
            },
        )?;
        let space = Value::Array(vec![
            Value::Name(b"ICCBased".to_vec()),
            Value::Reference(profile),
        ]);
        dict.retain(|(key, _)| key != b"ColorSpace");
        dict.push((b"ColorSpace".to_vec(), space));
    }
    if let Some(alpha) = &image.alpha {
        let mask = Value::Stream {
            dict: frame(b"DeviceGray"),
            data: alpha.clone(),
        };
        let mask = revisions.add_object(document, mask)?;
        dict.push((b"SMask".to_vec(), Value::Reference(mask)));
    }
    let value = match &image.pixels {
        Pixels::Samples(samples) => Value::Stream {
            dict,
            data: samples.clone(),
        },
        Pixels::Dct(jpeg) => {
            dict.push((b"Filter".to_vec(), Value::Name(b"DCTDecode".to_vec())));
            Value::Encoded {
                dict,
                data: jpeg.clone(),
            }
        }
    };
    Ok(revisions.add_object(document, value)?)
}

/// Adds a page of `paper` with `image` scaled to fit it and centred, with its XObject and content,
/// in the open transaction. The page has no `/Parent` and is in no page tree yet: inserting it is
/// the caller's.
///
/// # Errors
///
/// As [`image_xobject`].
pub fn image_page(
    document: &Document,
    revisions: &mut RevisionStore,
    image: &Image,
    paper: Paper,
) -> Result<ObjectRef, OpsError> {
    let xobject = image_xobject(document, revisions, image)?;
    let (page_width, page_height) = paper.size();
    let content = Value::Stream {
        dict: Vec::new(),
        data: placement(image, paper).into_bytes(),
    };
    let content = revisions.add_object(document, content)?;
    let page = Value::Dictionary(vec![
        (b"Type".to_vec(), Value::Name(b"Page".to_vec())),
        (
            b"MediaBox".to_vec(),
            Value::Array(vec![
                Value::Integer(0),
                Value::Integer(0),
                Value::Real(page_width),
                Value::Real(page_height),
            ]),
        ),
        (
            b"Resources".to_vec(),
            Value::Dictionary(vec![(
                b"XObject".to_vec(),
                Value::Dictionary(vec![(b"Im0".to_vec(), Value::Reference(xobject))]),
            )]),
        ),
        (b"Contents".to_vec(), Value::Reference(content)),
    ]);
    Ok(revisions.add_object(document, page)?)
}

/// The content that draws `/Im0` upright, as large as `paper` allows, keeping its shape, in the
/// middle.
#[allow(clippy::arithmetic_side_effects)] // Floats.
fn placement(image: &Image, paper: Paper) -> String {
    use Orientation::{
        FlipHorizontal, FlipVertical, NoTransforms, Rotate90, Rotate90FlipH, Rotate180, Rotate270,
        Rotate270FlipH,
    };
    let (page_width, page_height) = paper.size();
    let (page_width, page_height) = (f64::from(page_width), f64::from(page_height));
    let (mut width, mut height) = (f64::from(image.width), f64::from(image.height));
    if matches!(
        image.orientation,
        Rotate90 | Rotate270 | Rotate90FlipH | Rotate270FlipH
    ) {
        std::mem::swap(&mut width, &mut height);
    }
    let scale = (page_width / width).min(page_height / height);
    let (w, h) = (width * scale, height * scale);
    let (x, y) = ((page_width - w) / 2.0, (page_height - h) / 2.0);
    // The image space's unit square, top row at 1, to the box: `a b c d e f` of `cm`.
    let [a, b, c, d, e, f] = match image.orientation {
        NoTransforms => [w, 0.0, 0.0, h, x, y],
        Rotate90 => [0.0, -h, w, 0.0, x, y + h],
        Rotate180 => [-w, 0.0, 0.0, -h, x + w, y + h],
        Rotate270 => [0.0, h, -w, 0.0, x + w, y],
        FlipHorizontal => [-w, 0.0, 0.0, h, x + w, y],
        FlipVertical => [w, 0.0, 0.0, -h, x, y + h],
        Rotate90FlipH => [0.0, -h, -w, 0.0, x + w, y + h],
        Rotate270FlipH => [0.0, h, w, 0.0, x, y],
    };
    format!("q {a:.4} {b:.4} {c:.4} {d:.4} {e:.4} {f:.4} cm /Im0 Do Q\n")
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::path::PathBuf;

    use ferman_core::{OpenOptions, Password, Source, open};
    use image::{GrayImage, ImageBuffer, Luma, Rgb, RgbImage, Rgba, RgbaImage};

    use super::*;

    fn encoded(image: impl Into<DynamicImage>, format: ImageFormat) -> Vec<u8> {
        let mut bytes = Cursor::new(Vec::new());
        image.into().write_to(&mut bytes, format).unwrap();
        bytes.into_inner()
    }

    fn rgb(width: u32, height: u32) -> RgbImage {
        RgbImage::from_pixel(width, height, Rgb([200, 40, 10]))
    }

    fn limited(max_image_pixels: u64) -> Limits {
        let mut limits = Limits::default();
        limits.max_image_pixels = max_image_pixels;
        limits
    }

    /// A baseline 8×8 JPEG of 3 or 4 `components` by hand, every sample 255, with Adobe's marker or
    /// not. The image crate has no CMYK encoder.
    fn handmade_jpeg(components: u8, adobe: bool) -> Vec<u8> {
        let mut jpeg = vec![0xFF, 0xD8];
        if adobe {
            jpeg.extend([0xFF, 0xEE, 0, 14]);
            jpeg.extend(b"Adobe\0\x64\0\0\0\0\0");
        }
        jpeg.extend([0xFF, 0xDB, 0, 67, 0]);
        jpeg.extend([1; 64]);
        let frame = 8 + 3 * u16::from(components);
        jpeg.extend([0xFF, 0xC0, 0, frame as u8, 8, 0, 8, 0, 8, components]);
        for id in 1..=components {
            jpeg.extend([id, 0x11, 0]);
        }
        // One code of one bit in each table: a DC difference of 10 bits, AC end of block.
        for (class, symbol) in [(0x00, 10), (0x10, 0)] {
            jpeg.extend([0xFF, 0xC4, 0, 20, class, 1]);
            jpeg.extend([0; 15]);
            jpeg.push(symbol);
        }
        let scan = 6 + 2 * u16::from(components);
        jpeg.extend([0xFF, 0xDA, 0, scan as u8, components]);
        for id in 1..=components {
            jpeg.extend([id, 0]);
        }
        jpeg.extend([0, 63, 0]);
        // Each block: DC code 0, the difference 1016 (sample 255 with a quantiser of 1), AC code 0;
        // the last byte padded with ones.
        jpeg.extend(if components == 3 {
            &[0x7F, 0x07, 0xF0, 0x7F, 0x0F][..]
        } else {
            &[0x7F, 0x07, 0xF0, 0x7F, 0x07, 0xF0][..]
        });
        jpeg.extend([0xFF, 0xD9]);
        jpeg
    }

    #[test]
    fn a_jpeg_passes_through_byte_for_byte() {
        let jpeg = encoded(rgb(9, 5), ImageFormat::Jpeg);
        let image = load(&jpeg, &Limits::default()).unwrap();
        assert_eq!((image.width, image.height), (9, 5));
        assert_eq!(image.colour, Colour::Rgb);
        assert_eq!(image.pixels, Pixels::Dct(jpeg));

        let gray = encoded(GrayImage::new(3, 3), ImageFormat::Jpeg);
        assert_eq!(
            load(&gray, &Limits::default()).unwrap().colour,
            Colour::Gray
        );
    }

    #[test]
    fn a_cmyk_jpeg_is_told_from_rgb_and_decodes_without_a_panic() {
        let plain = load(&handmade_jpeg(4, false), &Limits::default()).unwrap();
        assert_eq!(plain.colour, Colour::Cmyk { inverted: false });
        let adobe = handmade_jpeg(4, true);
        let image = load(&adobe, &Limits::default()).unwrap();
        assert_eq!(image.colour, Colour::Cmyk { inverted: true });

        let decoded = decode_dct(&adobe, &Limits::default()).unwrap();
        assert_eq!(decoded.colour, Colour::Rgb);
        assert_eq!(decoded.pixels, Pixels::Samples(decoded_samples(&decoded)));
        assert_eq!(decoded_samples(&decoded).len(), 8 * 8 * 3);
    }

    #[test]
    fn only_an_adobe_cmyk_jpeg_decodes_to_rgb() {
        let seed = |name: &str| {
            std::fs::read(
                std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
                    .join("../../fuzz/seeds/images")
                    .join(name),
            )
            .unwrap()
        };
        // Every sample 255: no ink with the marker, full ink without it.
        let adobe = decode_dct(&seed("cmyk-adobe.jpg"), &Limits::default()).unwrap();
        assert!(decoded_samples(&adobe).iter().all(|&sample| sample == 255));
        assert!(matches!(
            decode_dct(&seed("cmyk-plain.jpg"), &Limits::default()),
            Err(OpsError::UnreadableImage)
        ));
    }

    fn decoded_samples(image: &Image) -> Vec<u8> {
        match &image.pixels {
            Pixels::Samples(samples) => samples.clone(),
            Pixels::Dct(_) => panic!("not decoded"),
        }
    }

    #[test]
    fn the_other_formats_decode_to_samples() {
        for format in [
            ImageFormat::Png,
            ImageFormat::Tiff,
            ImageFormat::WebP,
            ImageFormat::Gif,
        ] {
            let image = load(&encoded(rgb(4, 2), format), &Limits::default()).unwrap();
            assert_eq!((image.width, image.height), (4, 2), "{format:?}");
            assert_eq!(image.colour, Colour::Rgb, "{format:?}");
            assert_eq!(decoded_samples(&image).len(), 4 * 2 * 3, "{format:?}");
            assert_eq!(image.alpha, None, "{format:?}");
        }
    }

    #[test]
    fn alpha_is_kept_unless_it_is_wholly_opaque_and_sixteen_bits_become_eight() {
        let mut clear = RgbaImage::from_pixel(2, 2, Rgba([1, 2, 3, 255]));
        clear.put_pixel(1, 1, Rgba([1, 2, 3, 64]));
        let image = load(&encoded(clear, ImageFormat::Png), &Limits::default()).unwrap();
        assert_eq!(image.alpha, Some(vec![255, 255, 255, 64]));
        assert_eq!(decoded_samples(&image)[..3], [1, 2, 3]);

        let opaque = RgbaImage::from_pixel(2, 2, Rgba([1, 2, 3, 255]));
        let image = load(&encoded(opaque, ImageFormat::Png), &Limits::default()).unwrap();
        assert_eq!(image.alpha, None);

        let deep: ImageBuffer<Luma<u16>, Vec<u16>> = ImageBuffer::from_pixel(2, 1, Luma([0xFFFF]));
        let image = load(&encoded(deep, ImageFormat::Png), &Limits::default()).unwrap();
        assert_eq!(image.colour, Colour::Gray);
        assert_eq!(decoded_samples(&image), [255, 255]);
    }

    /// B131: the limit is crossed by one pixel, on both paths, and on a header alone.
    #[test]
    fn the_pixel_limit_stops_exactly_where_it_is() {
        let over = |result: Result<Image, OpsError>| {
            assert!(matches!(
                result,
                Err(OpsError::Core(CoreError::ResourceLimit {
                    limit: LimitKind::ImagePixels,
                    max: 15,
                }))
            ));
        };
        let png = encoded(rgb(4, 4), ImageFormat::Png);
        let jpeg = encoded(rgb(4, 4), ImageFormat::Jpeg);
        load(&png, &limited(16)).unwrap();
        over(load(&png, &limited(15)));
        load(&jpeg, &limited(16)).unwrap();
        over(load(&jpeg, &limited(15)));
        decode_dct(&jpeg, &limited(16)).unwrap();
        over(decode_dct(&jpeg, &limited(15)));

        // A header that claims 65535 × 65535 stops before anything is allocated for it.
        let mut bomb = handmade_jpeg(3, false);
        let sof = bomb
            .windows(2)
            .position(|pair| pair == [0xFF, 0xC0])
            .unwrap();
        bomb[sof + 5..sof + 9].copy_from_slice(&[255, 255, 255, 255]);
        for result in [
            load(&bomb, &Limits::default()),
            decode_dct(&bomb, &Limits::default()),
        ] {
            assert!(matches!(
                result,
                Err(OpsError::Core(CoreError::ResourceLimit {
                    limit: LimitKind::ImagePixels,
                    ..
                }))
            ));
        }
    }

    #[test]
    fn bad_headers_are_errors() {
        let good = handmade_jpeg(3, false);
        let sof = good
            .windows(2)
            .position(|pair| pair == [0xFF, 0xC0])
            .unwrap();
        let patched = |at: usize, value: u8| {
            let mut bytes = good.clone();
            bytes[at] = value;
            bytes
        };
        for bad in [
            &b""[..],
            b"not an image",
            b"\xFF\xD8",
            b"\xFF\xD8\xFF",
            b"\xFF\xD8\xFF\xE0\x00",
            b"\xFF\xD8\xFF\xE0\x00\x01",
            b"\xFF\xD8\xFF\xDA\x00\x02",
            b"\xFF\xD8\xFF\xD9",
            &good[..sof],
            &good[..sof + 6],
            // 12 bits a sample, a height of zero, two components, an arithmetic frame.
            &patched(sof + 4, 12),
            &patched(sof + 6, 0),
            &patched(sof + 9, 2),
            &patched(sof + 1, 0xC9),
        ] {
            assert!(
                matches!(
                    load(bad, &Limits::default()),
                    Err(OpsError::UnreadableImage)
                ),
                "{bad:?}"
            );
            let _ = decode_dct(bad, &Limits::default());
        }
        let mut twice = good.clone();
        let frame = good[sof..sof + 19].to_vec();
        twice.splice(sof..sof, frame);
        assert!(load(&twice, &Limits::default()).is_err());
        // A file the guess takes for something else with no decoder here.
        assert!(load(b"BM\0\0\0\0\0\0", &Limits::default()).is_err());
    }

    /// Every seed of the `image_layer` fuzz target stays one that gets past the header.
    #[test]
    fn the_fuzz_seeds_load() {
        let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fuzz/seeds/images");
        let mut seeds = 0;
        for file in std::fs::read_dir(dir).unwrap() {
            let bytes = std::fs::read(file.unwrap().path()).unwrap();
            load(&bytes, &Limits::default()).unwrap();
            seeds += 1;
        }
        assert_eq!(seeds, 8);
    }

    fn kira() -> Document {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated/kira-tr.pdf");
        open(&Source::read(&path).unwrap(), &OpenOptions::default()).unwrap()
    }

    fn entry<'a>(dict: &'a [(Vec<u8>, Value)], key: &[u8]) -> Option<&'a Value> {
        dict.iter()
            .find(|(name, _)| name == key)
            .map(|(_, value)| value)
    }

    #[test]
    fn a_jpeg_xobject_holds_the_file_and_alpha_becomes_a_mask() {
        let doc = kira();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();

        let jpeg = handmade_jpeg(4, true);
        let image = load(&jpeg, &Limits::default()).unwrap();
        let id = image_xobject(&doc, &mut store, &image).unwrap();
        let Some(Value::Encoded { dict, data }) = store.object(&doc, id).unwrap() else {
            panic!("not left encoded");
        };
        assert_eq!(data, jpeg);
        assert_eq!(
            entry(&dict, b"Filter"),
            Some(&Value::Name(b"DCTDecode".to_vec()))
        );
        assert_eq!(
            entry(&dict, b"ColorSpace"),
            Some(&Value::Name(b"DeviceCMYK".to_vec()))
        );
        assert!(entry(&dict, b"Decode").is_some());

        let mut clear = RgbaImage::from_pixel(1, 2, Rgba([9, 8, 7, 255]));
        clear.put_pixel(0, 1, Rgba([9, 8, 7, 0]));
        let image = load(&encoded(clear, ImageFormat::Png), &Limits::default()).unwrap();
        let id = image_xobject(&doc, &mut store, &image).unwrap();
        let Some(Value::Stream { dict, data }) = store.object(&doc, id).unwrap() else {
            panic!("not a stream");
        };
        assert_eq!(data, [9, 8, 7, 9, 8, 7]);
        let Some(Value::Reference(mask)) = entry(&dict, b"SMask") else {
            panic!("no mask");
        };
        let Some(Value::Stream { dict, data }) = store.object(&doc, *mask).unwrap() else {
            panic!("not a stream");
        };
        assert_eq!(data, [255, 0]);
        assert_eq!(
            entry(&dict, b"ColorSpace"),
            Some(&Value::Name(b"DeviceGray".to_vec()))
        );
        assert_eq!(entry(&dict, b"SMask"), None);
    }

    /// `jpeg` with `segment`, whole, right after its start.
    fn with_segment(jpeg: &[u8], marker: u8, body: &[u8]) -> Vec<u8> {
        let mut out = jpeg[..2].to_vec();
        out.extend([0xFF, marker]);
        out.extend(u16::try_from(body.len() + 2).unwrap().to_be_bytes());
        out.extend(body);
        out.extend(&jpeg[2..]);
        out
    }

    /// An EXIF block with `orientation`, big-endian.
    fn exif(orientation: u8) -> Vec<u8> {
        let mut body = b"Exif\0\0MM\0*\0\0\0\x08\0\x01\x01\x12\0\x03\0\0\0\x01\0".to_vec();
        body.extend([orientation, 0, 0, 0, 0, 0, 0]);
        body
    }

    #[test]
    fn a_jpeg_keeps_its_orientation_and_a_profile_of_its_colours() {
        let jpeg = encoded(rgb(4, 2), ImageFormat::Jpeg);
        let image = load(&with_segment(&jpeg, 0xE1, &exif(6)), &Limits::default()).unwrap();
        assert_eq!(image.orientation, Orientation::Rotate90);
        assert_eq!(image.width, 4);

        let mut profile = vec![0u8; 128];
        profile[16..20].copy_from_slice(b"RGB ");
        let chunk = |profile: &[u8]| {
            let mut body = b"ICC_PROFILE\0\x01\x01".to_vec();
            body.extend(profile);
            body
        };
        let image = load(
            &with_segment(&jpeg, 0xE2, &chunk(&profile)),
            &Limits::default(),
        )
        .unwrap();
        assert_eq!(image.icc.as_deref(), Some(&profile[..]));
        let doc = kira();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let object = image_xobject(&doc, &mut store, &image).unwrap();
        let Some(Value::Encoded { dict, .. }) = store.object(&doc, object).unwrap() else {
            panic!("not a passed-through stream");
        };
        assert!(matches!(
            entry(&dict, b"ColorSpace"),
            Some(Value::Array(space)) if space[0] == Value::Name(b"ICCBased".to_vec())
        ));

        // One that names other colours is left out.
        profile[16..20].copy_from_slice(b"CMYK");
        let image = load(
            &with_segment(&jpeg, 0xE2, &chunk(&profile)),
            &Limits::default(),
        )
        .unwrap();
        assert_eq!(image.icc, None);
    }

    #[test]
    fn a_turned_image_fits_its_page_as_it_shows() {
        let image = Image {
            width: 200,
            height: 100,
            colour: Colour::Gray,
            pixels: Pixels::Samples(vec![0; 20_000]),
            alpha: None,
            orientation: Orientation::Rotate90,
            icc: None,
        };
        // Shown 100 by 200, so it grows to the page's height; the stored top row runs down the
        // right side.
        assert_eq!(
            placement(&image, Paper::Letter),
            "q 0.0000 -792.0000 396.0000 0.0000 108.0000 792.0000 cm /Im0 Do Q\n"
        );
        let turned = Image {
            orientation: Orientation::Rotate270,
            ..image.clone()
        };
        assert_eq!(
            placement(&turned, Paper::Letter),
            "q 0.0000 792.0000 -396.0000 0.0000 504.0000 0.0000 cm /Im0 Do Q\n"
        );
    }

    #[test]
    fn a_page_has_its_paper_and_the_image_fits_in_the_middle() {
        let wide = Image {
            width: 200,
            height: 100,
            colour: Colour::Gray,
            pixels: Pixels::Samples(vec![0; 20_000]),
            alpha: None,
            orientation: Orientation::NoTransforms,
            icc: None,
        };
        assert_eq!(
            placement(&wide, Paper::Letter),
            "q 612.0000 0.0000 0.0000 306.0000 0.0000 243.0000 cm /Im0 Do Q\n"
        );
        let tall = Image {
            width: 1,
            height: 2,
            pixels: Pixels::Samples(vec![0; 2]),
            ..wide.clone()
        };
        // Small images grow to fit too.
        assert_eq!(
            placement(&tall, Paper::Letter),
            "q 396.0000 0.0000 0.0000 792.0000 108.0000 0.0000 cm /Im0 Do Q\n"
        );

        let doc = kira();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let page = image_page(&doc, &mut store, &wide, Paper::A4).unwrap();
        let Some(Value::Dictionary(dict)) = store.object(&doc, page).unwrap() else {
            panic!("not a dictionary");
        };
        let Some(Value::Array(media)) = entry(&dict, b"MediaBox") else {
            panic!("no media box");
        };
        assert_eq!(media[2], Value::Real(595.28));
        assert_eq!(media[3], Value::Real(841.89));
        assert_eq!(entry(&dict, b"Parent"), None);
    }

    /// An encrypted document's writer encrypts the JPEG, and opening gives back its bytes.
    #[test]
    fn a_jpeg_survives_an_encrypted_save() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated/payslip-aes128.pdf");
        let options = OpenOptions {
            password: Some(Password::new("bordro2026".to_owned())),
            ..OpenOptions::default()
        };
        let doc = open(&Source::read(&path).unwrap(), &options).unwrap();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let jpeg = encoded(rgb(3, 3), ImageFormat::Jpeg);
        let image = load(&jpeg, &Limits::default()).unwrap();
        let id = image_xobject(&doc, &mut store, &image).unwrap();
        store.commit().unwrap();
        let saved = store.incremental_update(&doc).unwrap();
        assert!(!saved.windows(jpeg.len()).any(|bytes| bytes == jpeg));

        let again = open(&Source::from_bytes(saved.into()), &options).unwrap();
        let store = RevisionStore::new(&again);
        let Some(Value::Encoded { data, .. }) = store.object(&again, id).unwrap() else {
            panic!("not left encoded");
        };
        assert_eq!(data, jpeg);
    }
}
