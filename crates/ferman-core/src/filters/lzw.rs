//! LZWDecode (ISO 32000-2 §7.4.4): variable-width codes of 9 to 12 bits, most significant bit
//! first, with clear code 256 and end-of-data code 257.

use super::{Filter, Sink, damaged};
use crate::CoreError;
use weezl::decode::Decoder;
use weezl::{BitOrder, LzwStatus};

/// Decoded bytes taken from the decoder per call.
const CHUNK: usize = 16 * 1024;

/// LZWDecode. `early_change` is `/EarlyChange 1`, the default: the code width grows one code
/// early, the variant weezl calls the TIFF size switch. Data without the end-of-data code ends
/// where the stream ends.
pub(super) fn decode(data: &[u8], early_change: bool, out: &mut Sink) -> Result<(), CoreError> {
    let mut decoder = if early_change {
        Decoder::with_tiff_size_switch(BitOrder::Msb, 8)
    } else {
        Decoder::new(BitOrder::Msb, 8)
    };
    let mut chunk = vec![0; CHUNK];
    let mut rest = data;
    loop {
        let result = decoder.decode_bytes(rest, &mut chunk);
        rest = rest.get(result.consumed_in..).unwrap_or_default();
        out.extend(chunk.get(..result.consumed_out).unwrap_or_default())?;
        let offset = data.len().saturating_sub(rest.len());
        match result.status {
            Ok(LzwStatus::Done) | Ok(LzwStatus::NoProgress) => break,
            Ok(LzwStatus::Ok) if result.consumed_in == 0 && result.consumed_out == 0 => break,
            Ok(LzwStatus::Ok) => {}
            Err(_) => return Err(damaged(Filter::Lzw, offset, "invalid LZW code")),
        }
    }
    Ok(())
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use crate::CoreError;
    use crate::filters::{DecodeParams, Filter, decode};
    use crate::limits::LimitKind;
    use weezl::BitOrder;
    use weezl::encode::Encoder;

    fn lzw(data: &[u8], early_change: bool, max: u64) -> Result<Vec<u8>, CoreError> {
        let params = DecodeParams {
            early_change,
            ..DecodeParams::default()
        };
        decode(Filter::Lzw, &params, data, max)
    }

    fn encode(data: &[u8], early_change: bool) -> Vec<u8> {
        let mut encoder = if early_change {
            Encoder::with_tiff_size_switch(BitOrder::Msb, 8)
        } else {
            Encoder::new(BitOrder::Msb, 8)
        };
        encoder.encode(data).unwrap()
    }

    #[test]
    fn decodes_the_example_of_the_pdf_standard() {
        // ISO 32000-2 §7.4.4.2: codes 256 45 258 258 65 259 66 257.
        let encoded = [0x80, 0x0B, 0x60, 0x50, 0x22, 0x0C, 0x0C, 0x85, 0x01];
        assert_eq!(lzw(&encoded, true, u64::MAX).unwrap(), b"-----A---B");
    }

    #[test]
    fn decodes_long_data_with_either_code_width_switch() {
        let original: Vec<u8> = (0..200_000_u32)
            .map(|i| (i.wrapping_mul(2_654_435_761) >> 27) as u8)
            .collect();
        for early_change in [true, false] {
            let encoded = encode(&original, early_change);
            assert_eq!(lzw(&encoded, early_change, u64::MAX).unwrap(), original);
        }
    }

    #[test]
    fn data_without_the_end_code_gives_what_it_holds() {
        let original = b"LZW without its end-of-data code".repeat(50);
        let encoded = encode(&original, true);
        let decoded = lzw(&encoded[..encoded.len() / 2], true, u64::MAX).unwrap();
        assert!(!decoded.is_empty());
        assert!(original.starts_with(&decoded));
    }

    #[test]
    fn rejects_a_code_that_is_not_in_the_table() {
        // 256 (clear), then 300: no table entry yet.
        let encoded = [0x80, 0x4B, 0x00];
        assert!(matches!(
            lzw(&encoded, true, u64::MAX).unwrap_err(),
            CoreError::DamagedStream {
                filter: Filter::Lzw,
                ..
            }
        ));
    }

    #[test]
    fn stops_at_the_decoded_size_limit() {
        let encoded = encode(&vec![b'x'; 100_000], true);
        assert!(matches!(
            lzw(&encoded, true, 1_000).unwrap_err(),
            CoreError::ResourceLimit {
                limit: LimitKind::StreamDecodedSize,
                max: 1_000
            }
        ));
    }
}
