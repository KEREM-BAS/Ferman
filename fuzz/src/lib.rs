//! The checks Ferman's fuzz targets share.
//!
//! A target finds a bug when the code under test panics, overflows the stack, reads out of bounds
//! (AddressSanitizer), runs past libFuzzer's time or memory limits, or breaks a promise checked
//! here with `assert!`.
#![forbid(unsafe_code)]

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
