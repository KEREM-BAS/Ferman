//! `images-compress`: the image-heavy file of the Compress acceptance (ROADMAP §8, decision 26 of
//! the M4 plan), one kind of image per slot on four A4 pages with a caption each:
//!
//! 1. Flate: RGB drawn twice from one object, and greyscale with PNG predictors.
//! 2. DCT: greyscale, YCbCr, and CMYK with an Adobe marker and an inverting `/Decode`.
//! 3. Masks: `/SMask`, an explicit `/Mask`, a colour-key `/Mask` and an `/ImageMask` stencil.
//! 4. JPX; Flate CMYK; Indexed; an image inside a Form XObject; an image reached only through a
//!    tiling pattern.
//!
//! The Flate images carry low-amplitude noise, so Flate holds them badly and JPEG can make them
//! smaller. shortcut: the JPEGs hold DC coefficients only, so recompressing them may save
//! nothing; give them AC coefficients if Compress's tests need that. shortcut: the JPX image is
//! flat grey from an empty packet, as Compress only has to leave it untouched and count it; add
//! a real codestream if a later milestone decodes JPX.

use super::files::jpeg_components;
use super::tez::Random;
use super::{Doc, generated, info, open_first, opens};
use crate::pdf::{self, num, rect, text};
use crate::raster::Gray;
use crate::sources::{FontFile, Sources};
use crate::text::{Align, PageText};
use crate::{Generated, Generator};
use lopdf::{Dictionary, Object, ObjectId, Stream, dictionary};

/// The image-heavy file.
pub const IMAGES_COMPRESS: Generator = Generator {
    name: "images-compress",
    build,
    expect: opens(),
};

const SLOT: (f64, f64) = (230.0, 172.0);

/// The lower left corner of a slot.
const fn corner(column: u8, row: u8) -> (f64, f64) {
    (60.0 + 250.0 * column as f64, 560.0 - 210.0 * row as f64)
}

/// A slot's centre in points from the page's lower left corner.
const fn centre(column: u8, row: u8) -> (f64, f64) {
    let (x, y) = corner(column, row);
    (x + SLOT.0 / 2.0, y + SLOT.1 / 2.0)
}

/// What each slot's centre should show, for the oracle: page index, point and RGB. CMYK colours
/// are approximate, as is everything the noise touches.
pub const PROBES: &[(u16, (f64, f64), [u8; 3])] = &[
    (0, centre(0, 0), [180, 120, 80]),
    (0, centre(1, 0), [180, 120, 80]),
    (0, centre(0, 1), [140, 140, 140]),
    (1, centre(0, 0), [150, 150, 150]),
    (1, centre(1, 0), [179, 103, 53]),
    (1, centre(0, 1), [240, 130, 40]),
    (2, centre(0, 0), [70, 130, 170]),
    (2, centre(1, 0), [150, 150, 150]),
    (2, centre(0, 1), [90, 150, 90]),
    (2, centre(1, 1), [51, 102, 204]),
    (3, centre(0, 0), [128, 128, 128]),
    (3, centre(1, 0), [5, 163, 221]),
    (3, centre(0, 1), [30, 160, 90]),
    (3, centre(1, 1), [90, 90, 200]),
    (3, centre(0, 2), [200, 60, 120]),
];

/// Samples, `base.len()` per pixel: each of `base` with a left-to-right ramp and some noise.
fn noisy(width: u32, height: u32, base: &[u8], seed: u64) -> Vec<u8> {
    let mut random = Random::new(seed);
    let mut data = Vec::with_capacity((width * height) as usize * base.len());
    for _ in 0..height {
        for x in 0..width {
            for &value in base {
                let ramp = i64::from(x) * 48 / i64::from(width) - 24;
                let noise = i64::try_from(random.below(8)).unwrap_or(0) - 4;
                let sample = (i64::from(value) + ramp + noise).clamp(0, 255);
                data.push(u8::try_from(sample).unwrap_or(0));
            }
        }
    }
    data
}

/// An image dictionary.
fn image_dict(width: u32, height: u32, bits: u8, space: Option<&str>) -> Dictionary {
    let mut dict = dictionary! {
        "Type" => "XObject",
        "Subtype" => "Image",
        "Width" => i64::from(width),
        "Height" => i64::from(height),
        "BitsPerComponent" => i64::from(bits),
    };
    if let Some(space) = space {
        dict.set("ColorSpace", pdf::name(space));
    }
    dict
}

/// A stream whose bytes are already coded with `filter`.
fn coded(pdf: &mut pdf::Pdf, mut dict: Dictionary, filter: &str, data: Vec<u8>) -> ObjectId {
    dict.set("Filter", pdf::name(filter));
    pdf.add(Stream::new(dict, data))
}

/// A DCT image of the `noisy` samples of `base`, at 300 dpi.
fn dct(
    pdf: &mut pdf::Pdf,
    dict: Dictionary,
    (width, height): (u16, u16),
    base: &[u8],
    seed: u64,
) -> Result<ObjectId, String> {
    let (w, h) = (u32::from(width), u32::from(height));
    let samples = noisy(w, h, base, seed);
    let count = u8::try_from(base.len()).map_err(|err| err.to_string())?;
    let bytes = jpeg_components(width, height, 300, count, |x, y, component| {
        samples[((y * w + x) * u32::from(count) + u32::from(component)) as usize]
    })?;
    Ok(coded(pdf, dict, "DCTDecode", bytes))
}

/// A one-bit bitmap, rows padded to bytes; a set bit where `set` says.
fn bitmap(width: u32, height: u32, set: impl Fn(u32, u32) -> bool) -> Vec<u8> {
    let row = width.div_ceil(8) as usize;
    let mut data = vec![0u8; row * height as usize];
    for y in 0..height {
        for x in 0..width {
            if set(x, y) {
                data[y as usize * row + (x / 8) as usize] |= 0x80 >> (x % 8);
            }
        }
    }
    data
}

/// A JP2 file of one 8-bit grey component whose single packet is empty, so every sample decodes
/// to mid-grey.
fn jp2(width: u32, height: u32) -> Vec<u8> {
    fn boxed(kind: &[u8; 4], body: &[u8]) -> Vec<u8> {
        let mut out = u32::try_from(body.len() + 8)
            .unwrap_or(0)
            .to_be_bytes()
            .to_vec();
        out.extend_from_slice(kind);
        out.extend_from_slice(body);
        out
    }
    let mut code = vec![0xFF, 0x4F];
    // SIZ: one tile, one 8-bit unsigned component.
    code.extend_from_slice(&[0xFF, 0x51, 0, 41, 0, 0]);
    for value in [width, height, 0, 0, width, height, 0, 0] {
        code.extend_from_slice(&value.to_be_bytes());
    }
    code.extend_from_slice(&[0, 1, 7, 1, 1]);
    // COD: LRCP, one layer, no decomposition, 64 × 64 code blocks, the reversible wavelet.
    code.extend_from_slice(&[0xFF, 0x52, 0, 12, 0, 0, 0, 1, 0, 0, 4, 4, 0, 1]);
    // QCD: no quantisation, two guard bits, exponent 8.
    code.extend_from_slice(&[0xFF, 0x5C, 0, 4, 0x40, 0x40]);
    // SOT and SOD, then one empty packet.
    code.extend_from_slice(&[0xFF, 0x90, 0, 10, 0, 0, 0, 0, 0, 15, 0, 1, 0xFF, 0x93, 0x00]);
    code.extend_from_slice(&[0xFF, 0xD9]);

    let mut header = Vec::new();
    header.extend_from_slice(&height.to_be_bytes());
    header.extend_from_slice(&width.to_be_bytes());
    header.extend_from_slice(&[0, 1, 7, 7, 0, 0]);
    let mut boxes = boxed(b"ihdr", &header);
    boxes.extend(boxed(b"colr", &[1, 0, 0, 0, 0, 0, 17]));

    let mut out = boxed(b"jP  ", &[0x0D, 0x0A, 0x87, 0x0A]);
    out.extend(boxed(b"ftyp", b"jp2 \0\0\0\0jp2 "));
    out.extend(boxed(b"jp2h", &boxes));
    out.extend(boxed(b"jp2c", &code));
    out
}

/// Draws the XObject `name` in a slot.
fn place(page: &mut PageText, name: &str, column: u8, row: u8) {
    let (x, y) = corner(column, row);
    page.content.op(&format!(
        "q {} 0 0 {} {} {} cm /{name} Do Q",
        num(SLOT.0),
        num(SLOT.1),
        num(x),
        num(y)
    ));
}

/// Page 1: Flate.
fn flate_page(doc: &mut Doc, page: &mut PageText) -> Result<(), String> {
    let rgb = doc.pdf.stream(
        image_dict(420, 320, 8, Some("DeviceRGB")),
        noisy(420, 320, &[180, 120, 80], 1),
    );
    let mut scan = Gray::new(480, 360, 255);
    scan.pixels = noisy(480, 360, &[140], 2);
    let gray = doc.pdf.add(scan.gray_image()?);
    place(page, "Im1", 0, 0);
    place(page, "Im1", 1, 0);
    place(page, "Im2", 0, 1);
    page.resources
        .set("XObject", dictionary! { "Im1" => rgb, "Im2" => gray });
    Ok(())
}

/// Page 2: DCT.
fn dct_page(doc: &mut Doc, page: &mut PageText) -> Result<(), String> {
    let gray = image_dict(1200, 800, 8, Some("DeviceGray"));
    let gray = dct(&mut doc.pdf, gray, (1200, 800), &[150], 3)?;
    let color = image_dict(1600, 1200, 8, Some("DeviceRGB"));
    let color = dct(&mut doc.pdf, color, (1600, 1200), &[120, 90, 170], 4)?;
    // Adobe's CMYK is stored inverted: this is C 0, M 128, Y 255, K 0.
    let mut cmyk = image_dict(800, 600, 8, Some("DeviceCMYK"));
    cmyk.set(
        "Decode",
        [1, 0, 1, 0, 1, 0, 1, 0]
            .map(Object::Integer)
            .into_iter()
            .collect::<Vec<_>>(),
    );
    let cmyk = dct(&mut doc.pdf, cmyk, (800, 600), &[255, 127, 0, 255], 5)?;
    place(page, "Im1", 0, 0);
    place(page, "Im2", 1, 0);
    place(page, "Im3", 0, 1);
    page.resources.set(
        "XObject",
        dictionary! { "Im1" => gray, "Im2" => color, "Im3" => cmyk },
    );
    Ok(())
}

/// Page 3: masks. Every mask leaves the slot's centre painted.
fn masks_page(doc: &mut Doc, page: &mut PageText) -> Result<(), String> {
    const WIDTH: u32 = 320;
    const HEIGHT: u32 = 240;
    let inner = |x: u32, y: u32| {
        (WIDTH / 4..WIDTH * 3 / 4).contains(&x) && (HEIGHT / 4..HEIGHT * 3 / 4).contains(&y)
    };
    let mut alpha = Vec::with_capacity((WIDTH * HEIGHT) as usize);
    for y in 0..HEIGHT {
        for x in 0..WIDTH {
            alpha.push(if inner(x, y) { 255 } else { 64 });
        }
    }
    let soft = doc
        .pdf
        .stream(image_dict(WIDTH, HEIGHT, 8, Some("DeviceGray")), alpha);
    let mut dict = image_dict(WIDTH, HEIGHT, 8, Some("DeviceRGB"));
    dict.set("SMask", soft);
    let with_soft = doc
        .pdf
        .stream(dict, noisy(WIDTH, HEIGHT, &[70, 130, 170], 6));

    // A set bit of a mask masks out.
    let mut stencil = image_dict(WIDTH, HEIGHT, 1, None);
    stencil.set("ImageMask", true);
    let frame = bitmap(WIDTH, HEIGHT, |x, y| !inner(x, y));
    let explicit = doc.pdf.stream(stencil.clone(), frame.clone());
    let mut dict = image_dict(WIDTH, HEIGHT, 8, Some("DeviceGray"));
    dict.set("Mask", explicit);
    let with_mask = dct(&mut doc.pdf, dict, (320, 240), &[150], 7)?;

    // The colour key removes the white frame.
    let mut keyed = noisy(WIDTH, HEIGHT, &[90, 150, 90], 8);
    for y in 0..HEIGHT {
        for x in 0..WIDTH {
            if !inner(x, y) {
                let at = ((y * WIDTH + x) * 3) as usize;
                keyed[at..at + 3].fill(255);
            }
        }
    }
    let mut dict = image_dict(WIDTH, HEIGHT, 8, Some("DeviceRGB"));
    dict.set(
        "Mask",
        [250, 255, 250, 255, 250, 255]
            .map(Object::Integer)
            .into_iter()
            .collect::<Vec<_>>(),
    );
    let with_key = doc.pdf.stream(dict, keyed);

    let painted = doc.pdf.stream(stencil, frame);
    place(page, "Im1", 0, 0);
    place(page, "Im2", 1, 0);
    place(page, "Im3", 0, 1);
    page.content.op("0.2 0.4 0.8 rg");
    place(page, "Im4", 1, 1);
    page.content.op("0 g");
    page.resources.set(
        "XObject",
        dictionary! { "Im1" => with_soft, "Im2" => with_mask, "Im3" => with_key, "Im4" => painted },
    );
    Ok(())
}

/// Page 4: JPX, CMYK, Indexed, and images not in the page's own resources.
fn other_page(doc: &mut Doc, page: &mut PageText) {
    let jpx = coded(
        &mut doc.pdf,
        image_dict(256, 256, 8, Some("DeviceGray")),
        "JPXDecode",
        jp2(256, 256),
    );
    let cmyk = doc.pdf.stream(
        image_dict(240, 180, 8, Some("DeviceCMYK")),
        noisy(240, 180, &[200, 40, 0, 0], 9),
    );
    let mut dict = image_dict(160, 120, 8, None);
    dict.set(
        "ColorSpace",
        Object::Array(vec![
            pdf::name("Indexed"),
            pdf::name("DeviceRGB"),
            Object::Integer(3),
            pdf::hex(&[255, 255, 255, 30, 160, 90, 210, 180, 60, 40, 40, 40]),
        ]),
    );
    let mut indices = Vec::with_capacity(160 * 120);
    for y in 0..120u32 {
        for x in 0..160u32 {
            // Bands of the palette around a centre of index 1.
            let band = x.abs_diff(80).max(y.abs_diff(60)) / 16;
            indices.push(u8::try_from(1 + band % 3).unwrap_or(1));
        }
    }
    let indexed = doc.pdf.stream(dict, indices);

    let nested = doc.pdf.stream(
        image_dict(160, 120, 8, Some("DeviceRGB")),
        noisy(160, 120, &[90, 90, 200], 10),
    );
    let form = doc.pdf.stream(
        dictionary! {
            "Type" => "XObject",
            "Subtype" => "Form",
            "BBox" => rect(0.0, 0.0, 1.0, 1.0),
            "Resources" => dictionary! { "XObject" => dictionary! { "Im1" => nested } },
        },
        b"/Im1 Do".to_vec(),
    );

    let tile = doc.pdf.stream(
        image_dict(64, 64, 8, Some("DeviceRGB")),
        noisy(64, 64, &[200, 60, 120], 11),
    );
    let pattern = doc.pdf.stream(
        dictionary! {
            "Type" => "Pattern",
            "PatternType" => 1,
            "PaintType" => 1,
            "TilingType" => 1,
            "BBox" => rect(0.0, 0.0, 64.0, 64.0),
            "XStep" => 64,
            "YStep" => 64,
            "Resources" => dictionary! { "XObject" => dictionary! { "Im1" => tile } },
        },
        b"64 0 0 64 0 0 cm /Im1 Do".to_vec(),
    );

    place(page, "Im1", 0, 0);
    place(page, "Im2", 1, 0);
    place(page, "Im3", 0, 1);
    place(page, "Fm1", 1, 1);
    let (x, y) = corner(0, 2);
    page.content.op(&format!(
        "q /Pattern cs /P1 scn {} {} {} {} re f Q",
        num(x),
        num(y),
        num(SLOT.0),
        num(SLOT.1)
    ));
    page.resources.set(
        "XObject",
        dictionary! { "Im1" => jpx, "Im2" => cmyk, "Im3" => indexed, "Fm1" => form },
    );
    page.resources
        .set("Pattern", dictionary! { "P1" => pattern });
}

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = doc.word_style(sources, FontFile::PlexSans, 11.0)?;
    let mut pages = Vec::new();
    for caption in [
        "Flate images",
        "DCT images",
        "Masked images",
        "JPX, CMYK, Indexed, form and pattern images",
    ] {
        let mut page = PageText::default();
        doc.line(
            &mut page,
            &style,
            caption,
            (60.0, 780.0),
            480.0,
            Align::Left,
        )?;
        pages.push(page);
    }
    let [first, second, third, fourth] = pages.as_mut_slice() else {
        return Err("four pages".to_owned());
    };
    flate_page(&mut doc, first)?;
    dct_page(&mut doc, second)?;
    masks_page(&mut doc, third)?;
    other_page(&mut doc, fourth);
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let catalog = dictionary! { "Lang" => text("en-GB"), "OpenAction" => open_first(ids[0]) };
    let bytes = doc.close(
        catalog,
        &info(
            "Images for Compress",
            "Ferman test corpus",
            "Layout program",
            "D:20261013093000+03'00'",
        ),
        "images-compress",
        None,
    )?;
    Ok(generated(bytes, expected.text))
}
