//! ASCIIHexDecode and ASCII85Decode (ISO 32000-2 §7.4.2 and §7.4.3).

use super::{Filter, Sink, damaged, is_whitespace};
use crate::CoreError;

/// ASCIIHexDecode: pairs of hex digits, whitespace ignored, `>` ends the data. An odd last digit
/// is followed by an implied 0. Data without `>` ends where the stream ends.
pub(super) fn decode_hex(data: &[u8], out: &mut Sink) -> Result<(), CoreError> {
    let mut high: Option<u8> = None;
    for (offset, &byte) in data.iter().enumerate() {
        if is_whitespace(byte) {
            continue;
        }
        if byte == b'>' {
            break;
        }
        let Some(value) = hex_value(byte) else {
            return Err(damaged(Filter::AsciiHex, offset, "not a hex digit"));
        };
        match high.take() {
            None => high = Some(value),
            Some(first) => out.push(first.wrapping_shl(4) | value)?,
        }
    }
    if let Some(first) = high {
        out.push(first.wrapping_shl(4))?;
    }
    Ok(())
}

fn hex_value(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte.wrapping_sub(b'0')),
        b'a'..=b'f' => Some(byte.wrapping_sub(b'a').wrapping_add(10)),
        b'A'..=b'F' => Some(byte.wrapping_sub(b'A').wrapping_add(10)),
        _ => None,
    }
}

/// ASCII85Decode: groups of five characters `!` to `u` for four bytes, `z` for four zero bytes
/// between groups, whitespace ignored, `~>` ends the data. A last group of two to four characters
/// gives one to three bytes; a single last character gives none (it cannot hold a byte). Data
/// without `~>` ends where the stream ends.
pub(super) fn decode_85(data: &[u8], out: &mut Sink) -> Result<(), CoreError> {
    let mut group = Group::default();
    for (offset, &byte) in data.iter().enumerate() {
        match byte {
            b'~' => break,
            b'z' if group.count == 0 => out.extend(&[0; 4])?,
            b'z' => return Err(damaged(Filter::Ascii85, offset, "z inside a group")),
            b'!'..=b'u' => {
                group.add(byte.wrapping_sub(b'!'));
                if group.count == 5 {
                    let Some(bytes) = group.take() else {
                        return Err(damaged(Filter::Ascii85, offset, "group above 2^32 - 1"));
                    };
                    out.extend(&bytes)?;
                }
            }
            _ if is_whitespace(byte) => {}
            _ => return Err(damaged(Filter::Ascii85, offset, "not a base-85 digit")),
        }
    }
    if group.count >= 2 {
        let kept = usize::from(group.count.wrapping_sub(1));
        while group.count < 5 {
            group.add(84);
        }
        let Some(bytes) = group.take() else {
            return Err(damaged(
                Filter::Ascii85,
                data.len(),
                "last group above 2^32 - 1",
            ));
        };
        for &byte in bytes.iter().take(kept) {
            out.push(byte)?;
        }
    }
    Ok(())
}

/// The digits of one ASCII85 group read so far.
#[derive(Default)]
struct Group {
    value: u64,
    count: u8,
}

impl Group {
    /// Adds a digit from 0 to 84. At most five digits are added, so the value stays below 85^5.
    fn add(&mut self, digit: u8) {
        self.value = self
            .value
            .saturating_mul(85)
            .saturating_add(u64::from(digit));
        self.count = self.count.saturating_add(1);
    }

    /// The group's four bytes, or `None` if its value does not fit in 32 bits. Resets the group.
    fn take(&mut self) -> Option<[u8; 4]> {
        let value = u32::try_from(self.value).ok();
        *self = Self::default();
        value.map(u32::to_be_bytes)
    }
}

#[cfg(test)]
mod tests {
    use crate::CoreError;
    use crate::filters::{DecodeParams, Filter, decode};

    fn hex(data: &[u8]) -> Result<Vec<u8>, CoreError> {
        decode(Filter::AsciiHex, &DecodeParams::default(), data, u64::MAX)
    }

    fn a85(data: &[u8]) -> Result<Vec<u8>, CoreError> {
        decode(Filter::Ascii85, &DecodeParams::default(), data, u64::MAX)
    }

    #[test]
    fn hex_reads_digit_pairs_in_either_case_across_whitespace() {
        assert_eq!(hex(b"48 65\n6c6C\t6F>").unwrap(), b"Hello");
    }

    #[test]
    fn hex_pads_an_odd_last_digit_with_zero() {
        assert_eq!(hex(b"414>").unwrap(), b"A@");
    }

    #[test]
    fn hex_stops_at_the_end_marker_or_the_end_of_data() {
        assert_eq!(hex(b"41>zz").unwrap(), b"A");
        assert_eq!(hex(b"4142").unwrap(), b"AB");
        assert_eq!(hex(b">").unwrap(), b"");
    }

    #[test]
    fn hex_rejects_a_non_digit_with_its_offset() {
        let err = hex(b"41 4G>").unwrap_err();
        assert!(matches!(
            err,
            CoreError::DamagedStream {
                filter: Filter::AsciiHex,
                offset: 4,
                ..
            }
        ));
    }

    #[test]
    fn a85_decodes_full_groups_and_zero_groups() {
        assert_eq!(a85(b"9jqo^~>").unwrap(), b"Man ");
        assert_eq!(a85(b"z~>").unwrap(), [0; 4]);
        assert_eq!(a85(b"s8W-!~>").unwrap(), [0xFF; 4]);
        assert_eq!(a85(b"9jq\no^ z").unwrap(), b"Man \0\0\0\0");
    }

    #[test]
    fn a85_decodes_a_short_last_group() {
        assert_eq!(a85(b"9jqo~>").unwrap(), b"Man");
        assert_eq!(a85(b"9j~>").unwrap(), b"M");
        // A single last character holds no byte.
        assert_eq!(a85(b"9jqo^9~>").unwrap(), b"Man ");
    }

    #[test]
    fn a85_rejects_z_inside_a_group_and_values_above_32_bits() {
        assert!(matches!(
            a85(b"9jzqo^~>").unwrap_err(),
            CoreError::DamagedStream { offset: 2, .. }
        ));
        assert!(matches!(
            a85(b"s8W-\"~>").unwrap_err(),
            CoreError::DamagedStream { offset: 4, .. }
        ));
        assert!(matches!(
            a85(b"uuuu~>").unwrap_err(),
            CoreError::DamagedStream { .. }
        ));
    }

    #[test]
    fn a85_rejects_characters_outside_its_alphabet() {
        assert!(matches!(
            a85(b"9jqo^v~>").unwrap_err(),
            CoreError::DamagedStream {
                filter: Filter::Ascii85,
                offset: 5,
                ..
            }
        ));
    }
}
