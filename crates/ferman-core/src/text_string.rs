//! PDF text strings (ISO 32000-2 §7.9.2.2): titles, names and descriptions in UTF-16BE with a
//! byte order mark, UTF-8 with a byte order mark (PDF 2.0), or PDFDocEncoding (Annex D.2).
// A decoder module: lengths come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

/// PDFDocEncoding's code points for 0x18 to 0x1F, where it differs from Latin-1.
const LOW: [u32; 8] = [
    0x02D8, 0x02C7, 0x02C6, 0x02D9, 0x02DD, 0x02DB, 0x02DA, 0x02DC,
];

/// PDFDocEncoding's code points for 0x80 to 0xA0; 0x9F is undefined.
const HIGH: [u32; 33] = [
    0x2022, 0x2020, 0x2021, 0x2026, 0x2014, 0x2013, 0x0192, 0x2044, 0x2039, 0x203A, 0x2212, 0x2030,
    0x201E, 0x201C, 0x201D, 0x2018, 0x2019, 0x201A, 0x2122, 0xFB01, 0xFB02, 0x0141, 0x0152, 0x0160,
    0x0178, 0x017D, 0x0131, 0x0142, 0x0153, 0x0161, 0x017E, 0xFFFD, 0x20AC,
];

/// The character of one PDFDocEncoding byte; the undefined codes give U+FFFD.
pub(crate) fn pdf_doc_char(byte: u8) -> char {
    let code = match byte {
        0x18..=0x1F => LOW
            .get(usize::from(byte.wrapping_sub(0x18)))
            .copied()
            .unwrap_or(0xFFFD),
        0x80..=0xA0 => HIGH
            .get(usize::from(byte.wrapping_sub(0x80)))
            .copied()
            .unwrap_or(0xFFFD),
        0xAD => 0xFFFD,
        other => u32::from(other),
    };
    char::from_u32(code).unwrap_or(char::REPLACEMENT_CHARACTER)
}

/// The PDFDocEncoding byte of `c`, if it has one.
pub(crate) fn pdf_doc_byte(c: char) -> Option<u8> {
    let code = u32::from(c);
    if let Some(index) = LOW.iter().position(|&low| low == code) {
        return u8::try_from(index).ok().and_then(|i| i.checked_add(0x18));
    }
    if code != 0xFFFD
        && let Some(index) = HIGH.iter().position(|&high| high == code)
    {
        return u8::try_from(index).ok().and_then(|i| i.checked_add(0x80));
    }
    match code {
        0x18..=0x1F | 0x80..=0xA0 | 0xAD => None,
        0..=0xFF => u8::try_from(code).ok(),
        _ => None,
    }
}

/// A text string's bytes as text. UTF-16 language escapes (U+001B … U+001B) are dropped, and
/// unpaired surrogates and invalid UTF-8 become U+FFFD.
pub(crate) fn decode(bytes: &[u8]) -> String {
    if let Some(rest) = bytes.strip_prefix(&[0xFE, 0xFF]) {
        let units = rest
            .as_chunks::<2>()
            .0
            .iter()
            .map(|pair| u16::from_be_bytes(*pair));
        let mut out = String::new();
        let mut escaped = false;
        for c in char::decode_utf16(units) {
            let c = c.unwrap_or(char::REPLACEMENT_CHARACTER);
            if c == '\u{1B}' {
                escaped = !escaped;
            } else if !escaped {
                out.push(c);
            }
        }
        return out;
    }
    if let Some(rest) = bytes.strip_prefix(&[0xEF, 0xBB, 0xBF]) {
        return String::from_utf8_lossy(rest).into_owned();
    }
    bytes.iter().map(|&byte| pdf_doc_char(byte)).collect()
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    #[test]
    fn utf16_with_a_byte_order_mark() {
        let bytes = [0xFE, 0xFF, 0x00, 0x4B, 0x01, 0x30, 0x00, 0x52, 0x00, 0x41];
        assert_eq!(decode(&bytes), "KİRA");
        // A surrogate pair and an unpaired one.
        assert_eq!(decode(&[0xFE, 0xFF, 0xD8, 0x3D, 0xDE, 0x00]), "😀");
        assert_eq!(decode(&[0xFE, 0xFF, 0xD8, 0x3D]), "\u{FFFD}");
        // A language escape: U+001B "tr" U+001B.
        let tagged = [
            0xFE, 0xFF, 0x00, 0x1B, 0x00, 0x74, 0x00, 0x72, 0x00, 0x1B, 0x00, 0x41,
        ];
        assert_eq!(decode(&tagged), "A");
    }

    #[test]
    fn utf8_with_a_byte_order_mark() {
        assert_eq!(
            decode(b"\xEF\xBB\xBFKira s\xC3\xB6zle\xC5\x9Fmesi"),
            "Kira sözleşmesi"
        );
    }

    #[test]
    fn pdf_doc_encoding() {
        assert_eq!(decode(b"Caf\xE9 \x80 \x93 \x9A \x18"), "Café • ﬁ ı ˘");
        assert_eq!(decode(b"\x9F\xAD"), "\u{FFFD}\u{FFFD}");
    }

    #[test]
    fn every_defined_byte_round_trips() {
        for byte in 0u8..=255 {
            let c = pdf_doc_char(byte);
            if c == char::REPLACEMENT_CHARACTER {
                assert_eq!(pdf_doc_byte(c), None);
            } else {
                assert_eq!(pdf_doc_byte(c), Some(byte), "{byte:#x}");
            }
        }
        assert_eq!(pdf_doc_byte('ş'), None);
        assert_eq!(pdf_doc_byte('ı'), Some(0x9A));
    }
}
