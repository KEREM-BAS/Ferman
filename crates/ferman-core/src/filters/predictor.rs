//! The predictors of LZWDecode and FlateDecode (ISO 32000-2 §7.4.4.4): TIFF predictor 2 and the
//! PNG predictors, applied to the decompressed data.

use super::{DecodeParams, Filter, damaged, out_of_memory};
use crate::CoreError;

/// Checks the predictor parameters before the data is decompressed. With `/Predictor 1` the other
/// entries are not used and not checked.
pub(super) fn check(filter: Filter, params: &DecodeParams) -> Result<(), CoreError> {
    if params.predictor == 1 {
        return Ok(());
    }
    Layout::new(filter, params).map(|_| ())
}

/// Undoes the predictor of `params` on `data`, the decompressed rows.
pub(super) fn apply(
    filter: Filter,
    params: &DecodeParams,
    data: Vec<u8>,
) -> Result<Vec<u8>, CoreError> {
    if params.predictor == 1 {
        return Ok(data);
    }
    let layout = Layout::new(filter, params)?;
    if params.predictor == 2 {
        Ok(tiff(&layout, data))
    } else {
        png(filter, &layout, &data)
    }
}

fn invalid(filter: Filter, problem: &'static str) -> CoreError {
    CoreError::InvalidDecodeParams { filter, problem }
}

/// The row geometry the parameters describe.
struct Layout {
    /// Bytes per row, without the PNG filter byte.
    row: usize,
    /// Bytes per pixel, at least 1: the distance to the "left" byte of the PNG filters.
    pixel: usize,
    /// Samples per pixel.
    colors: usize,
    /// Samples per row.
    samples: usize,
    /// Bits per sample.
    bits: u32,
}

impl Layout {
    fn new(filter: Filter, params: &DecodeParams) -> Result<Self, CoreError> {
        if !matches!(params.predictor, 2 | 10..=15) {
            return Err(invalid(filter, "/Predictor is not 1, 2 or 10 to 15"));
        }
        if !(1..=32).contains(&params.colors) {
            return Err(invalid(filter, "/Colors is not 1 to 32"));
        }
        if !matches!(params.bits_per_component, 1 | 2 | 4 | 8 | 16) {
            return Err(invalid(filter, "/BitsPerComponent is not 1, 2, 4, 8 or 16"));
        }
        if params.columns == 0 {
            return Err(invalid(filter, "/Columns is 0"));
        }
        let pixel_bits =
            u64::from(params.colors).saturating_mul(u64::from(params.bits_per_component));
        let row_bits = pixel_bits.saturating_mul(u64::from(params.columns));
        let samples = u64::from(params.colors).saturating_mul(u64::from(params.columns));
        let to_bytes = |bits: u64| usize::try_from(bits.div_ceil(8)).ok();
        let (Some(row), Some(pixel), Ok(samples), Ok(colors)) = (
            to_bytes(row_bits),
            to_bytes(pixel_bits),
            usize::try_from(samples),
            usize::try_from(params.colors),
        ) else {
            return Err(invalid(filter, "rows too long"));
        };
        Ok(Self {
            row,
            pixel,
            colors,
            samples,
            bits: params.bits_per_component,
        })
    }
}

/// The PNG predictors: every row starts with its filter type (None, Sub, Up, Average or Paeth),
/// whatever `/Predictor` 10 to 15 says. A last row cut short is decoded as far as it goes.
fn png(filter: Filter, layout: &Layout, data: &[u8]) -> Result<Vec<u8>, CoreError> {
    let mut out = Vec::new();
    out.try_reserve_exact(data.len())
        .map_err(|_| out_of_memory())?;
    let mut previous: Vec<u8> = Vec::new();
    let mut offset = 0_usize;
    for chunk in data.chunks(layout.row.saturating_add(1)) {
        let Some((&kind, raw)) = chunk.split_first() else {
            break;
        };
        if kind > 4 {
            return Err(damaged(filter, offset, "PNG row filter is not 0 to 4"));
        }
        let mut row: Vec<u8> = Vec::new();
        row.try_reserve_exact(raw.len())
            .map_err(|_| out_of_memory())?;
        for (i, &byte) in raw.iter().enumerate() {
            let back = i.checked_sub(layout.pixel);
            let left = back.and_then(|j| row.get(j)).copied().unwrap_or(0);
            let up = previous.get(i).copied().unwrap_or(0);
            let up_left = back.and_then(|j| previous.get(j)).copied().unwrap_or(0);
            let predicted = match kind {
                1 => left,
                2 => up,
                3 => average(left, up),
                4 => paeth(left, up, up_left),
                _ => 0,
            };
            row.push(byte.wrapping_add(predicted));
        }
        out.extend_from_slice(&row);
        previous = row;
        offset = offset.saturating_add(chunk.len());
    }
    Ok(out)
}

/// The floor of the mean of two bytes, without overflow.
fn average(a: u8, b: u8) -> u8 {
    a.wrapping_shr(1)
        .wrapping_add(b.wrapping_shr(1))
        .wrapping_add(a & b & 1)
}

/// The Paeth predictor of PNG (RFC 2083 §6.6).
fn paeth(left: u8, up: u8, up_left: u8) -> u8 {
    let to_left = u16::from(up.abs_diff(up_left));
    let to_up = u16::from(left.abs_diff(up_left));
    let to_up_left = u16::from(left)
        .wrapping_add(u16::from(up))
        .abs_diff(u16::from(up_left).wrapping_mul(2));
    if to_left <= to_up && to_left <= to_up_left {
        left
    } else if to_up <= to_up_left {
        up
    } else {
        up_left
    }
}

/// TIFF predictor 2: each sample is stored as the difference to the same colour's sample one pixel
/// to the left, within a row. A last row cut short is decoded as far as it goes.
fn tiff(layout: &Layout, mut data: Vec<u8>) -> Vec<u8> {
    for row in data.chunks_mut(layout.row.max(1)) {
        match layout.bits {
            8 => {
                for i in layout.colors..row.len() {
                    let left = i
                        .checked_sub(layout.colors)
                        .and_then(|j| row.get(j))
                        .copied();
                    if let (Some(left), Some(byte)) = (left, row.get_mut(i)) {
                        *byte = byte.wrapping_add(left);
                    }
                }
            }
            16 => {
                let samples = (row.len().wrapping_shr(1)).min(layout.samples);
                for k in layout.colors..samples {
                    let left = k
                        .checked_sub(layout.colors)
                        .and_then(|j| wide_sample(row, j));
                    if let (Some(left), Some(value)) = (left, wide_sample(row, k)) {
                        set_wide_sample(row, k, value.wrapping_add(left));
                    }
                }
            }
            bits => {
                let available = row.len().saturating_mul(8).checked_div(bits as usize);
                let samples = available.unwrap_or(0).min(layout.samples);
                for k in layout.colors..samples {
                    let left = k
                        .checked_sub(layout.colors)
                        .and_then(|j| sample(row, j, bits));
                    if let (Some(left), Some(value)) = (left, sample(row, k, bits)) {
                        set_sample(row, k, bits, value.wrapping_add(left));
                    }
                }
            }
        }
    }
    data
}

/// The 16-bit big-endian sample `index` of `row`.
fn wide_sample(row: &[u8], index: usize) -> Option<u16> {
    let at = index.checked_mul(2)?;
    let bytes = row.get(at..at.checked_add(2)?)?;
    Some(u16::from_be_bytes([*bytes.first()?, *bytes.get(1)?]))
}

fn set_wide_sample(row: &mut [u8], index: usize, value: u16) {
    let Some(at) = index.checked_mul(2) else {
        return;
    };
    let [high, low] = value.to_be_bytes();
    if let Some(byte) = row.get_mut(at) {
        *byte = high;
    }
    if let Some(byte) = at.checked_add(1).and_then(|at| row.get_mut(at)) {
        *byte = low;
    }
}

/// Where sample `index` of `bits` bits sits: its byte, its shift from the right and its mask.
/// Samples of 1, 2 and 4 bits never cross a byte.
fn locate(index: usize, bits: u32) -> Option<(usize, u32, u8)> {
    let bit = index.checked_mul(bits as usize)?;
    let byte = bit.checked_div(8)?;
    let within = u32::try_from(bit.checked_rem(8)?).ok()?;
    let shift = 8_u32.checked_sub(bits)?.checked_sub(within)?;
    let mask = u8::MAX.wrapping_shr(8_u32.checked_sub(bits)?);
    Some((byte, shift, mask))
}

fn sample(row: &[u8], index: usize, bits: u32) -> Option<u8> {
    let (byte, shift, mask) = locate(index, bits)?;
    Some(row.get(byte)?.wrapping_shr(shift) & mask)
}

/// Writes sample `index`, keeping only its low `bits` bits (the sum wraps within the sample).
fn set_sample(row: &mut [u8], index: usize, bits: u32, value: u8) {
    if let Some((byte, shift, mask)) = locate(index, bits)
        && let Some(byte) = row.get_mut(byte)
    {
        *byte = (*byte & !mask.wrapping_shl(shift)) | (value & mask).wrapping_shl(shift);
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::{average, paeth};
    use crate::CoreError;
    use crate::filters::{DecodeParams, Filter, decode};
    use flate2::Compression;
    use flate2::write::ZlibEncoder;
    use std::io::Write;

    fn zlib(data: &[u8]) -> Vec<u8> {
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::fast());
        encoder.write_all(data).unwrap();
        encoder.finish().unwrap()
    }

    fn params(predictor: u32, colors: u32, bits: u32, columns: u32) -> DecodeParams {
        DecodeParams {
            predictor,
            colors,
            bits_per_component: bits,
            columns,
            ..DecodeParams::default()
        }
    }

    fn flate(params: &DecodeParams, rows: &[u8]) -> Result<Vec<u8>, CoreError> {
        decode(Filter::Flate, params, &zlib(rows), u64::MAX)
    }

    #[test]
    fn png_rows_undo_each_filter_type() {
        // Two rows of three one-byte pixels; the second row uses each filter in turn.
        let first = [0, 10, 20, 30];
        let cases: [(u8, [u8; 3], [u8; 3]); 5] = [
            (0, [1, 2, 3], [1, 2, 3]),
            (1, [1, 2, 3], [1, 3, 6]),
            (2, [1, 2, 3], [11, 22, 33]),
            (3, [1, 2, 3], [6, 15, 25]),
            (4, [1, 2, 3], [11, 22, 33]),
        ];
        for (kind, raw, expected) in cases {
            let mut rows = first.to_vec();
            rows.push(kind);
            rows.extend_from_slice(&raw);
            let decoded = flate(&params(12, 1, 8, 3), &rows).unwrap();
            assert_eq!(decoded[..3], [10, 20, 30], "filter {kind}");
            assert_eq!(decoded[3..], expected, "filter {kind}");
        }
    }

    #[test]
    fn png_sub_looks_one_pixel_back() {
        // Two-byte pixels: Sub adds the byte two places back.
        let decoded = flate(&params(11, 2, 8, 2), &[1, 5, 6, 1, 1]).unwrap();
        assert_eq!(decoded, [5, 6, 6, 7]);
    }

    #[test]
    fn png_decodes_a_last_row_cut_short() {
        let decoded = flate(&params(12, 1, 8, 4), &[0, 1, 2, 3, 4, 2, 1]).unwrap();
        assert_eq!(decoded, [1, 2, 3, 4, 2]);
    }

    #[test]
    fn png_rejects_an_unknown_row_filter() {
        let err = flate(&params(10, 1, 8, 2), &[0, 1, 2, 7, 1, 2]).unwrap_err();
        assert!(matches!(
            err,
            CoreError::DamagedStream {
                filter: Filter::Flate,
                offset: 3,
                ..
            }
        ));
    }

    #[test]
    fn tiff_adds_the_sample_to_the_left_at_8_bits() {
        // Two colours, three pixels per row, two rows.
        let decoded = flate(&params(2, 2, 8, 3), &[1, 2, 1, 1, 1, 1, 9, 9, 0, 1, 0, 1]).unwrap();
        assert_eq!(decoded, [1, 2, 2, 3, 3, 4, 9, 9, 9, 10, 9, 11]);
    }

    #[test]
    fn tiff_adds_whole_samples_at_16_bits() {
        let decoded = flate(&params(2, 1, 16, 2), &[0x01, 0xFF, 0x00, 0x01]).unwrap();
        assert_eq!(decoded, [0x01, 0xFF, 0x02, 0x00]);
    }

    #[test]
    fn tiff_adds_packed_samples_and_wraps_within_them() {
        // One colour, 2-bit samples, four per row: 1, +1, +1, +2 gives 1, 2, 3, 1 (5 wraps to 1).
        let decoded = flate(&params(2, 1, 2, 4), &[0b01_01_01_10]).unwrap();
        assert_eq!(decoded, [0b01_10_11_01]);
        // 1-bit samples: each bit is the running XOR along the row.
        let decoded = flate(&params(2, 1, 1, 8), &[0b1000_0001]).unwrap();
        assert_eq!(decoded, [0b1111_1110]);
    }

    #[test]
    fn invalid_parameters_are_refused_before_decoding() {
        for bad in [
            params(3, 1, 8, 1),
            params(16, 1, 8, 1),
            params(12, 0, 8, 1),
            params(12, 33, 8, 1),
            params(12, 1, 3, 1),
            params(12, 1, 8, 0),
        ] {
            let err = decode(Filter::Lzw, &bad, b"", u64::MAX).unwrap_err();
            assert!(
                matches!(
                    err,
                    CoreError::InvalidDecodeParams {
                        filter: Filter::Lzw,
                        ..
                    }
                ),
                "{bad:?}"
            );
        }
        // With /Predictor 1 the other entries are not read.
        assert!(decode(Filter::Flate, &params(1, 0, 3, 0), &zlib(b"ok"), u64::MAX).is_ok());
    }

    #[test]
    fn average_and_paeth_match_their_definitions() {
        for a in 0..=255_u8 {
            for b in [0, 1, 127, 128, 254, 255] {
                assert_eq!(u16::from(average(a, b)), (u16::from(a) + u16::from(b)) / 2);
                for c in [0, 100, 255] {
                    let p = i16::from(a) + i16::from(b) - i16::from(c);
                    let (pa, pb, pc) = (
                        (p - i16::from(a)).abs(),
                        (p - i16::from(b)).abs(),
                        (p - i16::from(c)).abs(),
                    );
                    let expected = if pa <= pb && pa <= pc {
                        a
                    } else if pb <= pc {
                        b
                    } else {
                        c
                    };
                    assert_eq!(paeth(a, b, c), expected, "{a} {b} {c}");
                }
            }
        }
    }
}
