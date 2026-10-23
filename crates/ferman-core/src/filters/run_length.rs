//! RunLengthDecode (ISO 32000-2 §7.4.5).

use super::Sink;
use crate::CoreError;

/// RunLengthDecode: a length byte 0 to 127 copies the next 1 to 128 bytes, 129 to 255 repeats
/// the next byte 257 − length times, and 128 ends the data. A run cut short by the end of the
/// stream gives the bytes that are there.
pub(super) fn decode(data: &[u8], out: &mut Sink) -> Result<(), CoreError> {
    let mut rest = data;
    while let Some((&length, tail)) = rest.split_first() {
        match length {
            128 => break,
            0..=127 => {
                let count = usize::from(length).saturating_add(1);
                let (run, after) = tail.split_at(count.min(tail.len()));
                out.extend(run)?;
                rest = after;
            }
            129..=255 => {
                let Some((&byte, after)) = tail.split_first() else {
                    break;
                };
                out.repeat(byte, 257_usize.saturating_sub(usize::from(length)))?;
                rest = after;
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use crate::filters::{DecodeParams, Filter, decode};

    fn rl(data: &[u8]) -> Vec<u8> {
        decode(Filter::RunLength, &DecodeParams::default(), data, u64::MAX).unwrap()
    }

    #[test]
    fn copies_literal_runs_and_repeats_bytes() {
        assert_eq!(rl(&[2, b'a', b'b', b'c', 254, b'x', 128]), b"abcxxx");
        assert_eq!(rl(&[129, b'-', 128]), [b'-'; 128]);
        assert_eq!(rl(&[0, b'q', 128]), b"q");
    }

    #[test]
    fn stops_at_the_end_marker_or_the_end_of_data() {
        assert_eq!(rl(&[0, b'a', 128, 0, b'b']), b"a");
        assert_eq!(rl(&[0, b'a', 0, b'b']), b"ab");
        assert_eq!(rl(&[]), b"");
    }

    #[test]
    fn a_run_cut_short_keeps_its_bytes() {
        assert_eq!(rl(&[5, b'a', b'b']), b"ab");
        assert_eq!(rl(&[0, b'a', 200]), b"a");
    }
}
