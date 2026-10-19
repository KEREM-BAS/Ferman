//! Property tests for the stream filters: whatever bytes an encoder writes, the decoder gives back.
//!
//! The ASCII and RunLength encoders here are written from ISO 32000-2 independently of the
//! decoders; Flate and LZW use the encoders of flate2 and weezl, with every predictor applied by
//! the encoders below.

// The encoders are test helpers, not #[test] functions, which clippy.toml's test allowances cover.
#![allow(clippy::unwrap_used)]

use ferman_core::filters::{DecodeParams, Filter, FilterStep, decode, decode_chain};
use ferman_core::limits::Limits;
use flate2::Compression;
use flate2::write::ZlibEncoder;
use proptest::prelude::*;
use std::io::Write;
use weezl::BitOrder;
use weezl::encode::Encoder;

fn hex_encode(data: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    for (i, byte) in data.iter().enumerate() {
        if i % 32 == 31 {
            out.push(b'\n');
        }
        out.extend_from_slice(format!("{byte:02x}").as_bytes());
    }
    out.push(b'>');
    out
}

fn a85_encode(data: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    for chunk in data.chunks(4) {
        let mut word = [0_u8; 4];
        word[..chunk.len()].copy_from_slice(chunk);
        let mut value = u32::from_be_bytes(word);
        if chunk.len() == 4 && value == 0 {
            out.push(b'z');
            continue;
        }
        let mut digits = [0_u8; 5];
        for digit in digits.iter_mut().rev() {
            *digit = b'!' + (value % 85) as u8;
            value /= 85;
        }
        out.extend_from_slice(&digits[..=chunk.len()]);
    }
    out.extend_from_slice(b"~>");
    out
}

fn run_length_encode(data: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    let mut rest = data;
    while let Some(&first) = rest.first() {
        let run = rest.iter().take(128).take_while(|&&b| b == first).count();
        if run >= 2 {
            out.extend_from_slice(&[(257 - run) as u8, first]);
            rest = &rest[run..];
        } else {
            let literal = rest.len().min(128);
            out.push((literal - 1) as u8);
            out.extend_from_slice(&rest[..literal]);
            rest = &rest[literal..];
        }
    }
    out.push(128);
    out
}

fn zlib(data: &[u8]) -> Vec<u8> {
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(data).unwrap();
    encoder.finish().unwrap()
}

fn lzw(data: &[u8], early_change: bool) -> Vec<u8> {
    let mut encoder = if early_change {
        Encoder::with_tiff_size_switch(BitOrder::Msb, 8)
    } else {
        Encoder::new(BitOrder::Msb, 8)
    };
    encoder.encode(data).unwrap()
}

/// The PNG predictor with one filter type for every row, one-byte samples.
fn png_predict(data: &[u8], row: usize, pixel: usize, kind: u8) -> Vec<u8> {
    let mut out = Vec::new();
    let mut previous = vec![0_u8; row];
    for chunk in data.chunks(row) {
        out.push(kind);
        for (i, &byte) in chunk.iter().enumerate() {
            let left = if i >= pixel { chunk[i - pixel] } else { 0 };
            let up = previous[i];
            let up_left = if i >= pixel { previous[i - pixel] } else { 0 };
            let predicted = match kind {
                0 => 0,
                1 => left,
                2 => up,
                3 => ((u16::from(left) + u16::from(up)) / 2) as u8,
                _ => {
                    let p = i16::from(left) + i16::from(up) - i16::from(up_left);
                    let (pa, pb, pc) = (
                        (p - i16::from(left)).abs(),
                        (p - i16::from(up)).abs(),
                        (p - i16::from(up_left)).abs(),
                    );
                    if pa <= pb && pa <= pc {
                        left
                    } else if pb <= pc {
                        up
                    } else {
                        up_left
                    }
                }
            };
            out.push(byte.wrapping_sub(predicted));
        }
        previous[..chunk.len()].copy_from_slice(chunk);
    }
    out
}

/// TIFF predictor 2 for 8-bit samples.
fn tiff_predict(data: &[u8], row: usize, colors: usize) -> Vec<u8> {
    let mut out = data.to_vec();
    for chunk in out.chunks_mut(row) {
        for i in (colors..chunk.len()).rev() {
            chunk[i] = chunk[i].wrapping_sub(chunk[i - colors]);
        }
    }
    out
}

fn decode_all(filter: Filter, params: &DecodeParams, data: &[u8]) -> Vec<u8> {
    decode(filter, params, data, u64::MAX).unwrap()
}

proptest! {
    #[test]
    fn ascii_hex_round_trips(data in proptest::collection::vec(any::<u8>(), 0..2048)) {
        prop_assert_eq!(decode_all(Filter::AsciiHex, &DecodeParams::default(), &hex_encode(&data)), data);
    }

    #[test]
    fn ascii85_round_trips(data in proptest::collection::vec(any::<u8>(), 0..2048)) {
        prop_assert_eq!(decode_all(Filter::Ascii85, &DecodeParams::default(), &a85_encode(&data)), data);
    }

    #[test]
    fn ascii85_round_trips_zero_runs(zeros in 0_usize..64, tail in proptest::collection::vec(any::<u8>(), 0..8)) {
        let mut data = vec![0; zeros];
        data.extend(tail);
        prop_assert_eq!(decode_all(Filter::Ascii85, &DecodeParams::default(), &a85_encode(&data)), data);
    }

    #[test]
    fn run_length_round_trips(data in proptest::collection::vec(prop_oneof![Just(b'a'), Just(b'b'), any::<u8>()], 0..2048)) {
        prop_assert_eq!(decode_all(Filter::RunLength, &DecodeParams::default(), &run_length_encode(&data)), data);
    }

    #[test]
    fn flate_round_trips(data in proptest::collection::vec(any::<u8>(), 0..8192)) {
        prop_assert_eq!(decode_all(Filter::Flate, &DecodeParams::default(), &zlib(&data)), data);
    }

    #[test]
    fn lzw_round_trips(data in proptest::collection::vec(any::<u8>(), 0..8192), early_change in any::<bool>()) {
        let params = DecodeParams { early_change, ..DecodeParams::default() };
        prop_assert_eq!(decode_all(Filter::Lzw, &params, &lzw(&data, early_change)), data);
    }

    #[test]
    fn png_predictors_round_trip(
        data in proptest::collection::vec(any::<u8>(), 0..4096),
        colors in 1_u32..=4,
        columns in 1_u32..=40,
        kind in 0_u8..=4,
        predictor in 10_u32..=15,
    ) {
        let params = DecodeParams { predictor, colors, columns, ..DecodeParams::default() };
        let row = (colors * columns) as usize;
        let encoded = zlib(&png_predict(&data, row, colors as usize, kind));
        prop_assert_eq!(decode_all(Filter::Flate, &params, &encoded), data);
    }

    #[test]
    fn tiff_predictor_round_trips(
        data in proptest::collection::vec(any::<u8>(), 0..4096),
        colors in 1_u32..=4,
        columns in 1_u32..=40,
    ) {
        let params = DecodeParams { predictor: 2, colors, columns, ..DecodeParams::default() };
        let row = (colors * columns) as usize;
        let encoded = lzw(&tiff_predict(&data, row, colors as usize), true);
        prop_assert_eq!(decode_all(Filter::Lzw, &params, &encoded), data);
    }

    #[test]
    fn a_chain_of_every_filter_round_trips(data in proptest::collection::vec(any::<u8>(), 0..2048)) {
        // Encoded innermost first: the chain decodes Hex, then 85, then RunLength, LZW and Flate.
        let encoded = hex_encode(&a85_encode(&run_length_encode(&lzw(&zlib(&data), true))));
        let steps = [Filter::AsciiHex, Filter::Ascii85, Filter::RunLength, Filter::Lzw, Filter::Flate]
            .map(|filter| FilterStep { filter, params: DecodeParams::default() });
        prop_assert_eq!(decode_chain(&steps, &encoded, &Limits::default()).unwrap(), data);
    }

    #[test]
    fn arbitrary_bytes_never_exceed_the_limit(data in proptest::collection::vec(any::<u8>(), 0..1024), limit in 0_u64..4096) {
        for filter in Filter::ALL {
            if let Ok(decoded) = decode(filter, &DecodeParams::default(), &data, limit) {
                prop_assert!(decoded.len() as u64 <= limit, "{} gave {} bytes", filter, decoded.len());
            }
        }
    }
}
