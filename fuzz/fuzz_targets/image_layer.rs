//! The image layer (`ferman_ops::images`): `load` and `decode_dct` on arbitrary bytes, with a small
//! pixel limit. What they give fits the size they report and stays within the limit.
#![no_main]

use ferman_core::limits::Limits;
use ferman_ops::images::{Colour, Image, Pixels, decode_dct, load};
use libfuzzer_sys::fuzz_target;

const MAX_PIXELS: u64 = 1 << 20;

fn check(image: &Image) {
    let pixels = u64::from(image.width) * u64::from(image.height);
    assert!(pixels > 0 && pixels <= MAX_PIXELS, "size outside the limit");
    let components = match image.colour {
        Colour::Gray => 1,
        Colour::Rgb => 3,
        Colour::Cmyk { .. } => 4,
    };
    if let Pixels::Samples(samples) = &image.pixels {
        assert_eq!(samples.len() as u64, pixels * components, "samples");
    }
    if let Some(alpha) = &image.alpha {
        assert_eq!(alpha.len() as u64, pixels, "alpha");
    }
}

fuzz_target!(|input: &[u8]| {
    let mut limits = Limits::default();
    limits.max_image_pixels = MAX_PIXELS;
    for image in [load(input, &limits), decode_dct(input, &limits)]
        .iter()
        .flatten()
    {
        check(image);
    }
});
