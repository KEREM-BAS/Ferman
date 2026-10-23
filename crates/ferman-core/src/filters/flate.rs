//! FlateDecode (ISO 32000-2 §7.4.4): zlib (RFC 1950) around deflate (RFC 1951).

use super::{Filter, Sink, damaged, out_of_memory};
use crate::CoreError;
use flate2::{Decompress, FlushDecompress, Status};

/// The first output buffer, and the least the buffer grows by.
const CHUNK: usize = 64 * 1024;

/// FlateDecode. The zlib header is checked; the deflate data after it is decoded until its end
/// block. A stream that ends before its end block gives what it decoded, and the Adler-32
/// checksum is not checked, as PDFium decodes such streams (see the module notes).
pub(super) fn decode(data: &[u8], out: &mut Sink) -> Result<(), CoreError> {
    let Some((header, deflate)) = data.split_first_chunk::<2>() else {
        // Empty, or cut short inside the header: no data.
        return Ok(());
    };
    check_header(*header)?;
    inflate(deflate, out)
}

/// Checks the two zlib header bytes: deflate, a window of at most 32 KiB, the check bits, and no
/// preset dictionary (PDF has no way to supply one).
fn check_header([cmf, flg]: [u8; 2]) -> Result<(), CoreError> {
    let method = cmf & 0x0F;
    let window = cmf.wrapping_shr(4);
    let checked = u16::from_be_bytes([cmf, flg]).checked_rem(31) == Some(0);
    if method != 8 || window > 7 || !checked {
        return Err(damaged(Filter::Flate, 0, "no zlib header"));
    }
    if flg & 0x20 != 0 {
        return Err(damaged(Filter::Flate, 1, "zlib preset dictionary"));
    }
    Ok(())
}

/// Raw deflate into `out`, bounded by its limit.
fn inflate(deflate: &[u8], out: &mut Sink) -> Result<(), CoreError> {
    let mut inflater = Decompress::new(false);
    let mut buffer: Vec<u8> = Vec::new();
    loop {
        let consumed = usize::try_from(inflater.total_in()).unwrap_or(usize::MAX);
        let input = deflate.get(consumed..).unwrap_or_default();
        if buffer.len() == buffer.capacity() {
            grow(&mut buffer, out)?;
        }
        let (before_in, before_out) = (inflater.total_in(), inflater.total_out());
        let status = inflater
            .decompress_vec(input, &mut buffer, FlushDecompress::None)
            .map_err(|_| {
                let at = usize::try_from(inflater.total_in()).unwrap_or(usize::MAX);
                damaged(Filter::Flate, at.saturating_add(2), "invalid deflate data")
            })?;
        if buffer.len() > out.room() {
            return Err(out.over_limit());
        }
        match status {
            Status::StreamEnd => break,
            Status::Ok | Status::BufError => {
                let stalled =
                    inflater.total_in() == before_in && inflater.total_out() == before_out;
                if stalled && buffer.len() < buffer.capacity() {
                    // No end block, and no more input to find it in.
                    break;
                }
            }
        }
    }
    out.adopt(buffer)
}

/// Grows the inflate buffer geometrically, up to one byte past the room under the limit, so a
/// stream that decodes to more than the limit is caught.
fn grow(buffer: &mut Vec<u8>, out: &Sink) -> Result<(), CoreError> {
    let ceiling = out.room().saturating_add(1);
    let wanted = buffer.len().max(CHUNK);
    let additional = wanted.min(ceiling.saturating_sub(buffer.len()));
    if additional == 0 {
        return Err(out.over_limit());
    }
    buffer
        .try_reserve_exact(additional)
        .map_err(|_| out_of_memory())
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use crate::CoreError;
    use crate::filters::{DecodeParams, Filter, decode};
    use crate::limits::LimitKind;
    use flate2::Compression;
    use flate2::write::ZlibEncoder;
    use std::io::Write;

    fn zlib(data: &[u8]) -> Vec<u8> {
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(data).unwrap();
        encoder.finish().unwrap()
    }

    fn fl(data: &[u8], max: u64) -> Result<Vec<u8>, CoreError> {
        decode(Filter::Flate, &DecodeParams::default(), data, max)
    }

    fn text(len: usize) -> Vec<u8> {
        (0..len)
            .map(|i| b"Kira sozlesmesi, madde "[i % 23])
            .collect()
    }

    #[test]
    fn decodes_a_zlib_stream() {
        let original = text(300_000);
        assert_eq!(fl(&zlib(&original), u64::MAX).unwrap(), original);
        assert_eq!(fl(&zlib(b""), u64::MAX).unwrap(), b"");
    }

    #[test]
    fn a_stream_cut_short_gives_what_it_holds() {
        let original = text(100_000);
        let encoded = zlib(&original);
        let decoded = fl(&encoded[..encoded.len() / 2], u64::MAX).unwrap();
        assert!(!decoded.is_empty());
        assert!(original.starts_with(&decoded));
        assert_eq!(fl(&[], u64::MAX).unwrap(), b"");
        assert_eq!(fl(&[0x78], u64::MAX).unwrap(), b"");
    }

    #[test]
    fn a_wrong_checksum_is_not_an_error() {
        let mut encoded = zlib(b"checksum");
        let last = encoded.len() - 1;
        encoded[last] ^= 0xFF;
        assert_eq!(fl(&encoded, u64::MAX).unwrap(), b"checksum");
    }

    #[test]
    fn rejects_a_missing_header_and_a_preset_dictionary() {
        assert!(matches!(
            fl(b"BT /F1 12 Tf ET", u64::MAX).unwrap_err(),
            CoreError::DamagedStream {
                filter: Filter::Flate,
                offset: 0,
                ..
            }
        ));
        // 0x78 0xBB: deflate, 32 KiB window, FDICT set, check bits valid.
        assert!(matches!(
            fl(&[0x78, 0xBB, 0, 0, 0, 0], u64::MAX).unwrap_err(),
            CoreError::DamagedStream { offset: 1, .. }
        ));
    }

    #[test]
    fn rejects_invalid_deflate_data() {
        // Block type 3 is reserved.
        assert!(matches!(
            fl(&[0x78, 0x9C, 0xFF, 0xFF, 0xFF], u64::MAX).unwrap_err(),
            CoreError::DamagedStream {
                filter: Filter::Flate,
                ..
            }
        ));
    }

    #[test]
    fn a_decompression_bomb_stops_at_the_limit() {
        let bomb = zlib(&vec![0; 10_000_000]);
        assert!(bomb.len() < 20_000);
        let err = fl(&bomb, 1_000_000).unwrap_err();
        assert!(matches!(
            err,
            CoreError::ResourceLimit {
                limit: LimitKind::StreamDecodedSize,
                max: 1_000_000
            }
        ));
        assert_eq!(fl(&bomb, 10_000_000).unwrap().len(), 10_000_000);
    }
}
