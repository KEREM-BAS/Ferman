//! The minimal Type1 parser: a font program's built-in encoding (Adobe Type 1 Font Format §10.3,
//! ISO 32000-2 §9.6.5).
//!
//! It reads only the clear-text part, where `/Encoding` lives: the bytes before `eexec`, or a PFB
//! file's first segment (`0x80 0x01` and a little-endian length). Nothing is decrypted. The
//! encoding is either `StandardEncoding` or a 256-entry array filled with `dup <code> /<name> put`;
//! any other form (another named encoding, a computed array) reads as none. The built-in encodings
//! of the non-embedded Symbol and ZapfDingbats are not here: they need their AFM tables, which
//! arrive with the standard 14's metrics.
//!
//! The glyph names and widths a program has (its `/CharStrings`, in the encrypted part) come from
//! [`crate::FontProgram`], which decrypts it.
// A parser module: the program comes from a file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeMap;

use crate::FontError;
use crate::cmap::{Token, Tokens};

/// The largest font program read, as docs/ARCHITECTURE.md §9.1 has it: 64 MiB.
pub const MAX_PROGRAM: usize = 64 * 1024 * 1024;

/// A Type1 program's built-in encoding.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BuiltinEncoding {
    /// `/Encoding StandardEncoding def`.
    Standard,
    /// The array form: each code the program names, in code order, with its glyph name. Codes it
    /// leaves out (and `.notdef`) have no glyph.
    Codes(Vec<(u8, String)>),
}

/// The built-in encoding of the Type1 program `program`, or `None` when its clear text has no
/// `/Encoding` this parser reads.
///
/// # Errors
///
/// [`FontError::ProgramTooLarge`] for a program over [`MAX_PROGRAM`], and
/// [`FontError::Malformed`] for a PFB header that is not a clear-text segment or a segment that
/// runs past the end.
pub fn builtin_encoding(program: &[u8]) -> Result<Option<BuiltinEncoding>, FontError> {
    if program.len() > MAX_PROGRAM {
        return Err(FontError::ProgramTooLarge {
            size: u64::try_from(program.len()).unwrap_or(u64::MAX),
            max: u64::try_from(MAX_PROGRAM).unwrap_or(u64::MAX),
        });
    }
    let mut tokens = Tokens::new(clear_text(program)?);
    if !tokens.any(|token| token == Token::Name(b"Encoding")) {
        return Ok(None);
    }
    match tokens.next() {
        Some(Token::Keyword(b"StandardEncoding")) => Ok(Some(BuiltinEncoding::Standard)),
        Some(Token::Integer(_)) => Ok(Some(BuiltinEncoding::Codes(codes(tokens)))),
        _ => Ok(None),
    }
}

/// The clear-text part of `program`.
fn clear_text(program: &[u8]) -> Result<&[u8], FontError> {
    let text = match program {
        [0x80, 0x01, a, b, c, d, rest @ ..] => {
            let length = usize::try_from(u32::from_le_bytes([*a, *b, *c, *d])).map_err(|_| {
                FontError::Malformed {
                    context: "PFB segment length",
                }
            })?;
            rest.get(..length).ok_or(FontError::Malformed {
                context: "PFB segment past the end",
            })?
        }
        [0x80, ..] => {
            return Err(FontError::Malformed {
                context: "PFB header",
            });
        }
        _ => program,
    };
    let end = text
        .windows(5)
        .position(|window| window == b"eexec")
        .unwrap_or(text.len());
    Ok(text.get(..end).unwrap_or(text))
}

/// The array form's `dup <code> /<name> put` entries up to `def`; a later entry for a code wins.
fn codes(tokens: Tokens<'_>) -> Vec<(u8, String)> {
    let mut codes = BTreeMap::new();
    let mut last: [Option<Token<'_>>; 3] = [None, None, None];
    for token in tokens {
        if token == Token::Keyword(b"def") {
            break;
        }
        if token == Token::Keyword(b"put")
            && let [
                Some(Token::Keyword(b"dup")),
                Some(Token::Integer(code)),
                Some(Token::Name(name)),
            ] = &last
            && let Ok(code) = u8::try_from(*code)
            && *name != b".notdef"
        {
            codes.insert(code, String::from_utf8_lossy(name).into_owned());
        }
        last.rotate_left(1);
        if let Some(slot) = last.last_mut() {
            *slot = Some(token);
        }
    }
    codes.into_iter().collect()
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    const ARRAY: &[u8] = b"%!PS-AdobeFont-1.0: Test 001.000
11 dict begin
/FontName /Test def
/FontInfo 2 dict dup begin /Notice (an /Encoding in a string) readonly def end readonly def
/Encoding 256 array
0 1 255 {1 index exch /.notdef put} for
dup 65 /Gbreve put
dup 66 /idotaccent put
dup 67 /.notdef put
dup 300 /A put
dup 65 /Scaron put
readonly def
/PaintType 0 def
currentdict end
currentfile eexec \x8a\x01/Encoding StandardEncoding def";

    fn codes(pairs: &[(u8, &str)]) -> Option<BuiltinEncoding> {
        Some(BuiltinEncoding::Codes(
            pairs
                .iter()
                .map(|&(code, name)| (code, name.to_owned()))
                .collect(),
        ))
    }

    #[test]
    fn the_standard_form() {
        let program = b"%!FontType1\n/Encoding StandardEncoding def\ncurrentfile eexec";
        assert_eq!(
            builtin_encoding(program).unwrap(),
            Some(BuiltinEncoding::Standard)
        );
    }

    #[test]
    fn the_array_form_reads_up_to_eexec() {
        // A later entry wins; .notdef, codes past 255 and strings are dropped.
        assert_eq!(
            builtin_encoding(ARRAY).unwrap(),
            codes(&[(65, "Scaron"), (66, "idotaccent")])
        );
    }

    #[test]
    fn a_pfb_segment_holds_the_clear_text() {
        let mut pfb = vec![0x80, 0x01];
        pfb.extend_from_slice(&u32::try_from(ARRAY.len()).unwrap().to_le_bytes());
        pfb.extend_from_slice(ARRAY);
        pfb.extend_from_slice(&[0x80, 0x02, 4, 0, 0, 0, 1, 2, 3, 4, 0x80, 0x03]);
        assert_eq!(
            builtin_encoding(&pfb).unwrap(),
            codes(&[(65, "Scaron"), (66, "idotaccent")])
        );
    }

    #[test]
    fn damaged_programs_fail_or_read_as_none() {
        assert!(matches!(
            builtin_encoding(&[0x80, 0x01, 0xFF, 0, 0, 0, b'%']),
            Err(FontError::Malformed { .. })
        ));
        assert!(matches!(
            builtin_encoding(&[0x80, 0x02, 0, 0, 0, 0]),
            Err(FontError::Malformed { .. })
        ));
        assert_eq!(builtin_encoding(b"").unwrap(), None);
        assert_eq!(builtin_encoding(b"/Encoding").unwrap(), None);
        assert_eq!(
            builtin_encoding(b"/Encoding ISOLatin1Encoding def").unwrap(),
            None
        );
        assert_eq!(
            builtin_encoding(b"/Encoding 256 array dup 65 /A").unwrap(),
            codes(&[])
        );
        for end in 0..ARRAY.len() {
            let _ = builtin_encoding(&ARRAY[..end]);
        }
        let garbage: Vec<u8> = (0..4096_u32).map(|i| (i * 7919 % 251) as u8).collect();
        let _ = builtin_encoding(&garbage);
    }

    #[test]
    fn an_oversized_program_is_refused() {
        let program = vec![b' '; MAX_PROGRAM + 1];
        assert!(matches!(
            builtin_encoding(&program),
            Err(FontError::ProgramTooLarge { .. })
        ));
    }
}
