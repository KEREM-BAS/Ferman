//! The checks Ferman's fuzz targets share.
//!
//! A target finds a bug when the code under test panics, overflows the stack, reads out of bounds
//! (AddressSanitizer), runs past libFuzzer's time or memory limits, or breaks a promise checked
//! here with `assert!`.
#![forbid(unsafe_code)]

pub mod edit_script;

use ferman_core::CoreError;
use ferman_core::filters::{DecodeParams, Filter, decode};

/// The decoded-size limit of the filter targets: small, so a decompression bomb stops quickly.
pub const MAX_DECODED: u64 = 1 << 20;

/// Decodes `data` with `filter` and checks what every decoder promises: no panic, never more than
/// the limit, and only the errors a damaged stream can cause.
pub fn check_filter(filter: Filter, params: &DecodeParams, data: &[u8]) {
    match decode(filter, params, data, MAX_DECODED) {
        Ok(decoded) => assert!(
            u64::try_from(decoded.len()).is_ok_and(|len| len <= MAX_DECODED),
            "{filter} decoded past the limit"
        ),
        Err(
            CoreError::DamagedStream { .. }
            | CoreError::InvalidDecodeParams { .. }
            | CoreError::ResourceLimit { .. },
        ) => {}
        // Out of memory below 1 MiB, or an internal error, is a bug.
        Err(other) => panic!("{filter}: unexpected error: {other}"),
    }
}

/// Splits `/DecodeParms` for LZW and Flate off the first four bytes of `input`; the rest is the
/// stream data. Mostly valid parameters, with each invalid kind reachable.
#[must_use]
pub fn split_params(input: &[u8]) -> (DecodeParams, &[u8]) {
    let Some((&[predictor, colors, bits, columns], data)) = input.split_first_chunk::<4>() else {
        return (DecodeParams::default(), input);
    };
    let predictor = match predictor & 0x0F {
        0..=3 => 1,
        4..=5 => 2,
        6 => u32::from(predictor),
        n => 10 + u32::from(n - 7).min(5),
    };
    let params = DecodeParams {
        predictor,
        colors: u32::from(colors % 34),
        bits_per_component: [1, 2, 4, 8, 16, 8, 3, 0][usize::from(bits & 0x07)],
        columns: u32::from(columns),
        early_change: bits & 0x80 == 0,
    };
    (params, data)
}

/// What the font targets start from: a bundled font with shaping tables, so patches reach `GSUB`,
/// `GPOS`, `glyf` and the rest without a seed corpus.
const BASE_FONT: &[u8] =
    include_bytes!("../../app/assets/fonts/ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf");

/// A font program from the start of `input`, and the bytes left for the target.
///
/// An even first byte patches the base font: a count byte, then that many patches of a 24-bit
/// offset and a value. An odd one takes the font whole: a 16-bit length of the bytes left for the
/// target, those bytes, then the font (how a seed brings a CFF program; see README.md).
#[must_use]
pub fn font_case(input: &[u8]) -> Option<(Vec<u8>, &[u8])> {
    let (&mode, input) = input.split_first()?;
    if mode & 1 == 1 {
        let (length, input) = input.split_first_chunk::<2>()?;
        let (rest, font) = input.split_at_checked(usize::from(u16::from_be_bytes(*length)))?;
        return Some((font.to_vec(), rest));
    }
    let (&count, input) = input.split_first()?;
    let (patches, rest) = input.split_at_checked(usize::from(count) * 4)?;
    let mut font = BASE_FONT.to_vec();
    for patch in patches.as_chunks::<4>().0 {
        let offset =
            usize::from(patch[0]) << 16 | usize::from(patch[1]) << 8 | usize::from(patch[2]);
        font[offset % BASE_FONT.len()] = patch[3];
    }
    Some((font, rest))
}

/// Text from arbitrary bytes, two for each character: its block and its place in that block.
/// Random UTF-8 is nearly all ASCII; these blocks reach the scripts the shaper and the line
/// breaker treat apart, mixed: Hebrew and Arabic, Devanagari, ZWNJ and the bidi controls, kana and
/// CJK punctuation, Hangul, emoji.
#[must_use]
pub fn text_from(bytes: &[u8]) -> String {
    const BLOCKS: [u32; 8] = [0, 0x0590, 0x0600, 0x0900, 0x2000, 0x3000, 0xAC00, 0x1_F300];
    bytes
        .as_chunks::<2>()
        .0
        .iter()
        .filter_map(|pair| char::from_u32(BLOCKS[usize::from(pair[0] & 7)] + u32::from(pair[1])))
        .collect()
}
