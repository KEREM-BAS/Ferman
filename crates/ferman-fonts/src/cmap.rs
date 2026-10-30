//! CMaps (ISO 32000-2 §9.7.5 and §9.10.3, Adobe Technical Note #5014): the codespace that splits a
//! string into codes, the CIDs of a composite font's codes, and the text of a ToUnicode CMap, read
//! as leniently as viewers read them: what cannot be read is skipped, and parsing never fails.
//!
//! `usecmap` is recorded, not followed: the caller finds the parent CMap and joins it with
//! [`CMap::inherit`] under its own depth limit. A range is kept as a range, so `<0000> <FFFF>`
//! costs no more than one code.
// A parser module: offsets and values come from the data (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::HashMap;

/// The longest code a CMap has, in bytes.
const MAX_CODE: usize = 4;

/// A CMap: an encoding CMap of a composite font, or a ToUnicode CMap.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CMap {
    /// Codespace ranges: the low and the high code, of the same length.
    codespace: Vec<(Vec<u8>, Vec<u8>)>,
    /// CID ranges: the low and the high code, their length, and the low code's CID.
    cids: Vec<(u32, u32, usize, u32)>,
    /// `bfchar` entries.
    text: HashMap<u32, String>,
    /// `bfrange` entries.
    text_ranges: Vec<TextRange>,
    vertical: bool,
    parent: Option<Vec<u8>>,
}

/// One `bfrange` entry.
#[derive(Debug, Clone, PartialEq, Eq)]
enum TextRange {
    /// Each code's text is the low code's with its last UTF-16 unit counted up.
    Counting {
        low: u32,
        high: u32,
        start: Vec<u16>,
    },
    /// Each code has its own text, in order.
    Listed {
        low: u32,
        high: u32,
        texts: Vec<String>,
    },
}

impl CMap {
    /// Reads the CMap in `data`.
    #[must_use]
    pub fn parse(data: &[u8]) -> Self {
        let mut cmap = Self::default();
        let mut stack: Vec<Token<'_>> = Vec::new();
        for token in Tokens::new(data) {
            let Token::Keyword(keyword) = token else {
                stack.push(token);
                continue;
            };
            match keyword {
                b"usecmap" => {
                    if let Some(Token::Name(name)) = stack.last() {
                        cmap.parent = Some(name.to_vec());
                    }
                }
                b"def" => {
                    if let [.., Token::Name(b"WMode"), Token::Integer(mode)] = stack.as_slice() {
                        cmap.vertical = *mode == 1;
                    }
                }
                b"endcodespacerange" => {
                    for pair in stack.as_chunks::<2>().0 {
                        if let [Token::Hex(low), Token::Hex(high)] = pair
                            && low.len() == high.len()
                            && (1..=MAX_CODE).contains(&low.len())
                        {
                            cmap.codespace.push((low.clone(), high.clone()));
                        }
                    }
                }
                b"endcidchar" => {
                    for pair in stack.as_chunks::<2>().0 {
                        if let [Token::Hex(bytes), Token::Integer(cid)] = pair
                            && let (Some(code), Ok(cid)) = (number(bytes), u32::try_from(*cid))
                        {
                            cmap.cids.push((code, code, bytes.len(), cid));
                        }
                    }
                }
                b"endcidrange" => {
                    for triple in stack.as_chunks::<3>().0 {
                        if let [Token::Hex(low), Token::Hex(high), Token::Integer(cid)] = triple
                            && low.len() == high.len()
                            && let (Some(lo), Some(hi), Ok(cid)) =
                                (number(low), number(high), u32::try_from(*cid))
                            && lo <= hi
                        {
                            cmap.cids.push((lo, hi, low.len(), cid));
                        }
                    }
                }
                b"endbfchar" => {
                    for pair in stack.as_chunks::<2>().0 {
                        if let [Token::Hex(code), Token::Hex(text)] = pair
                            && let Some(code) = number(code)
                        {
                            cmap.text.insert(code, utf16(text));
                        }
                    }
                }
                b"endbfrange" => {
                    for triple in stack.as_chunks::<3>().0 {
                        let [Token::Hex(low), Token::Hex(high), target] = triple else {
                            continue;
                        };
                        let (Some(low), Some(high)) = (number(low), number(high)) else {
                            continue;
                        };
                        if low > high {
                            continue;
                        }
                        match target {
                            Token::Hex(start) => cmap.text_ranges.push(TextRange::Counting {
                                low,
                                high,
                                start: units(start),
                            }),
                            Token::Array(texts) => cmap.text_ranges.push(TextRange::Listed {
                                low,
                                high,
                                texts: texts.iter().map(|text| utf16(text)).collect(),
                            }),
                            _ => {}
                        }
                    }
                }
                // Other operators (`findresource`, `pop`, a stray word) leave the operands.
                keyword if !keyword.starts_with(b"begin") && !keyword.starts_with(b"end") => {
                    continue;
                }
                _ => {}
            }
            stack.clear();
        }
        cmap
    }

    /// `Identity-H`, or `Identity-V` when `vertical`: two-byte codes that are their own CIDs.
    #[must_use]
    pub fn identity(vertical: bool) -> Self {
        Self {
            codespace: vec![(vec![0, 0], vec![0xFF, 0xFF])],
            cids: vec![(0, 0xFFFF, 2, 0)],
            vertical,
            ..Self::default()
        }
    }

    /// Whether it writes vertically (`/WMode 1`).
    #[must_use]
    pub fn is_vertical(&self) -> bool {
        self.vertical
    }

    /// The name of the CMap it uses (`usecmap`), which the caller joins with [`CMap::inherit`].
    #[must_use]
    pub fn parent(&self) -> Option<&[u8]> {
        self.parent.as_deref()
    }

    /// Adds `parent`'s codespace and mappings under its own, which win.
    pub fn inherit(&mut self, parent: &Self) {
        self.codespace.extend(parent.codespace.iter().cloned());
        self.cids.extend(parent.cids.iter().copied());
        for (code, text) in &parent.text {
            self.text.entry(*code).or_insert_with(|| text.clone());
        }
        self.text_ranges.extend(parent.text_ranges.iter().cloned());
        self.parent.clone_from(&parent.parent);
    }

    /// Splits `bytes` into codes by the codespace, each with its length in bytes. A byte sequence
    /// no range matches is taken as one code of the shortest length, so every byte belongs to a
    /// code (§9.7.6.3).
    pub fn codes<'a>(&'a self, bytes: &'a [u8]) -> impl Iterator<Item = (u32, usize)> + 'a {
        let shortest = self
            .codespace
            .iter()
            .map(|(low, _)| low.len())
            .min()
            .or_else(|| self.cids.first().map(|&(_, _, length, _)| length))
            .unwrap_or(1);
        let mut at = 0;
        std::iter::from_fn(move || {
            let rest = bytes.get(at..).filter(|rest| !rest.is_empty())?;
            let length = (1..=MAX_CODE.min(rest.len()))
                .find(|&n| {
                    let code = rest.get(..n).unwrap_or_default();
                    self.codespace.iter().any(|(low, high)| {
                        low.len() == n
                            && code
                                .iter()
                                .zip(low.iter().zip(high))
                                .all(|(byte, (lo, hi))| (lo..=hi).contains(&byte))
                    })
                })
                .unwrap_or(shortest.min(rest.len()));
            let code = number(rest.get(..length).unwrap_or_default()).unwrap_or(0);
            at = at.saturating_add(length);
            Some((code, length))
        })
    }

    /// The CID of `code`, of `length` bytes.
    #[must_use]
    pub fn cid(&self, code: u32, length: usize) -> Option<u32> {
        self.cids
            .iter()
            .find(|&&(low, high, n, _)| n == length && (low..=high).contains(&code))
            .and_then(|&(low, _, _, first)| first.checked_add(code.checked_sub(low)?))
    }

    /// The text of `code` in a ToUnicode CMap.
    #[must_use]
    pub fn text(&self, code: u32) -> Option<String> {
        if let Some(text) = self.text.get(&code) {
            return Some(text.clone());
        }
        self.text_ranges.iter().find_map(|range| match range {
            TextRange::Counting { low, high, start } if (low..=high).contains(&&code) => {
                let mut units = start.clone();
                let last = units.last_mut()?;
                *last = last.checked_add(u16::try_from(code.checked_sub(*low)?).ok()?)?;
                Some(decode(&units))
            }
            TextRange::Listed { low, high, texts } if (low..=high).contains(&&code) => texts
                .get(usize::try_from(code.checked_sub(*low)?).ok()?)
                .cloned(),
            _ => None,
        })
    }
}

/// A code's bytes as a number, for codes of one to four bytes.
fn number(bytes: &[u8]) -> Option<u32> {
    if bytes.is_empty() || bytes.len() > MAX_CODE {
        return None;
    }
    Some(
        bytes
            .iter()
            .fold(0, |value, &byte| (value << 8) | u32::from(byte)),
    )
}

/// UTF-16BE bytes as code units; a last odd byte is a unit of its own.
fn units(bytes: &[u8]) -> Vec<u16> {
    bytes
        .chunks(2)
        .map(|pair| match *pair {
            [high, low] => u16::from_be_bytes([high, low]),
            [single] => u16::from(single),
            _ => 0,
        })
        .collect()
}

/// UTF-16 units as text, with U+FFFD for a lone surrogate.
fn decode(units: &[u16]) -> String {
    char::decode_utf16(units.iter().copied())
        .map(|unit| unit.unwrap_or(char::REPLACEMENT_CHARACTER))
        .collect()
}

fn utf16(bytes: &[u8]) -> String {
    decode(&units(bytes))
}

/// One token of a CMap's PostScript.
#[derive(Debug, Clone, PartialEq, Eq)]
enum Token<'a> {
    Hex(Vec<u8>),
    Integer(i64),
    Name(&'a [u8]),
    Keyword(&'a [u8]),
    /// An array of hex strings; anything else in it is dropped.
    Array(Vec<Vec<u8>>),
}

/// The tokens of a CMap. Strings, dictionaries' brackets, procedures and real numbers are skipped.
struct Tokens<'a> {
    data: &'a [u8],
    at: usize,
}

impl<'a> Tokens<'a> {
    fn new(data: &'a [u8]) -> Self {
        Self { data, at: 0 }
    }

    fn peek(&self) -> Option<u8> {
        self.data.get(self.at).copied()
    }

    fn bump(&mut self) {
        self.at = self.at.saturating_add(1);
    }

    /// A run of regular characters.
    fn word(&mut self) -> &'a [u8] {
        let start = self.at;
        while self.peek().is_some_and(regular) {
            self.bump();
        }
        self.data.get(start..self.at).unwrap_or_default()
    }

    /// After `<`: the bytes up to `>`, or `None` for a character that is not a hex digit.
    fn hex(&mut self) -> Option<Vec<u8>> {
        let mut digits = Vec::new();
        while let Some(byte) = self.peek() {
            self.bump();
            match byte {
                b'>' => break,
                byte if byte.is_ascii_whitespace() => {}
                byte => digits.push(char::from(byte).to_digit(16)?),
            }
        }
        if digits.len() % 2 == 1 {
            digits.push(0);
        }
        Some(
            digits
                .as_chunks::<2>()
                .0
                .iter()
                .filter_map(|&[high, low]| {
                    u8::try_from(high.checked_mul(16)?.checked_add(low)?).ok()
                })
                .collect(),
        )
    }

    /// After `(`: skips the string, its nested parentheses and escapes.
    fn skip_string(&mut self) {
        let mut depth = 1_u32;
        while let Some(byte) = self.peek() {
            self.bump();
            match byte {
                b'\\' => self.bump(),
                b'(' => depth = depth.saturating_add(1),
                b')' => {
                    depth = depth.saturating_sub(1);
                    if depth == 0 {
                        return;
                    }
                }
                _ => {}
            }
        }
    }
}

impl<'a> Iterator for Tokens<'a> {
    type Item = Token<'a>;

    fn next(&mut self) -> Option<Token<'a>> {
        loop {
            let byte = self.peek()?;
            match byte {
                b'%' => {
                    while self
                        .peek()
                        .is_some_and(|byte| byte != b'\n' && byte != b'\r')
                    {
                        self.bump();
                    }
                }
                b'(' => {
                    self.bump();
                    self.skip_string();
                }
                b'<' if self.data.get(self.at.saturating_add(1)) == Some(&b'<') => {
                    self.at = self.at.saturating_add(2);
                }
                b'<' => {
                    self.bump();
                    if let Some(bytes) = self.hex() {
                        return Some(Token::Hex(bytes));
                    }
                }
                b'/' => {
                    self.bump();
                    return Some(Token::Name(self.word()));
                }
                b'[' => {
                    self.bump();
                    return Some(Token::Array(self.array()));
                }
                byte if regular(byte) => {
                    let word = self.word();
                    return Some(
                        std::str::from_utf8(word)
                            .ok()
                            .and_then(|word| word.parse().ok())
                            .map_or(Token::Keyword(word), Token::Integer),
                    );
                }
                // White space, `]`, `>`, `{`, `}` and `)` outside a string.
                _ => self.bump(),
            }
        }
    }
}

impl Tokens<'_> {
    /// After `[`: its hex strings up to `]`.
    fn array(&mut self) -> Vec<Vec<u8>> {
        let mut items = Vec::new();
        while let Some(byte) = self.peek() {
            match byte {
                b']' => {
                    self.bump();
                    break;
                }
                b'<' => {
                    self.bump();
                    if let Some(bytes) = self.hex() {
                        items.push(bytes);
                    }
                }
                b'(' => {
                    self.bump();
                    self.skip_string();
                }
                _ => self.bump(),
            }
        }
        items
    }
}

/// Not white space and not a PostScript delimiter.
fn regular(byte: u8) -> bool {
    !byte.is_ascii_whitespace() && byte != 0 && !b"()<>[]{}/%".contains(&byte)
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    const TO_UNICODE: &[u8] = b"/CIDInit /ProcSet findresource begin 12 dict begin begincmap
/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
/CMapName /Adobe-Identity-UCS def /CMapType 2 def
1 begincodespacerange <0000> <FFFF> endcodespacerange
3 beginbfchar
<0003> <0020>
<0011> <00660069>
<0012> <D83DDE00>
endbfchar
2 beginbfrange
<0020> <0022> <0130>
<0030> <0032> [<011F> <015F> <0131>]
endbfrange
endcmap CMapName currentdict /CMap defineresource pop end end";

    #[test]
    fn a_to_unicode_cmap_maps_codes_ranges_ligatures_and_surrogates() {
        let cmap = CMap::parse(TO_UNICODE);
        assert_eq!(cmap.text(3).as_deref(), Some(" "));
        assert_eq!(cmap.text(0x11).as_deref(), Some("fi"));
        assert_eq!(cmap.text(0x12).as_deref(), Some("😀"));
        assert_eq!(cmap.text(0x21).as_deref(), Some("ı"));
        assert_eq!(cmap.text(0x22).as_deref(), Some("Ĳ"));
        assert_eq!(cmap.text(0x31).as_deref(), Some("ş"));
        assert_eq!(cmap.text(0x33), None);
        assert!(!cmap.is_vertical());
    }

    #[test]
    fn an_encoding_cmap_splits_mixed_lengths_into_cids() {
        let cmap = CMap::parse(
            b"/WMode 1 def /Base usecmap
2 begincodespacerange <00> <80> <8140> <9FFC> endcodespacerange
1 begincidrange <8140> <817E> 633 endcidrange
1 begincidchar <41> 34 endcidchar",
        );
        assert!(cmap.is_vertical());
        assert_eq!(cmap.parent(), Some(&b"Base"[..]));
        let codes: Vec<(u32, usize)> = cmap.codes(b"A\x81\x42\xff").collect();
        assert_eq!(codes, [(0x41, 1), (0x8142, 2), (0xFF, 1)]);
        assert_eq!(cmap.cid(0x41, 1), Some(34));
        assert_eq!(cmap.cid(0x8142, 2), Some(635));
        assert_eq!(cmap.cid(0x8142, 1), None);

        let mut child = CMap::parse(b"1 begincidchar <41> 7 endcidchar");
        child.inherit(&cmap);
        assert_eq!(child.cid(0x41, 1), Some(7), "the child's own mapping wins");
        assert_eq!(child.cid(0x8140, 2), Some(633));
    }

    #[test]
    fn identity_codes_are_their_own_cids() {
        let cmap = CMap::identity(true);
        assert!(cmap.is_vertical());
        let codes: Vec<(u32, usize)> = cmap.codes(b"\x01\x02\x03").collect();
        assert_eq!(codes, [(0x0102, 2), (0x03, 1)]);
        assert_eq!(cmap.cid(0x0102, 2), Some(0x0102));
    }

    #[test]
    fn damaged_cmaps_keep_what_they_can() {
        let cmap = CMap::parse(
            b"beginbfchar <01> <0041> <02> <zz> (a)b\\)c) <03> <0043> <04> endbfchar ]]>> 5",
        );
        assert_eq!(cmap.text(1).as_deref(), Some("A"));
        assert_eq!(CMap::parse(b"").codes(b"ab").count(), 2);
        // A range of every two-byte code stays one entry.
        let wide = CMap::parse(b"beginbfrange <0000> <FFFF> <0000> endbfrange");
        assert_eq!(wide.text(0x41).as_deref(), Some("A"));
        assert_eq!(wide.text_ranges.len(), 1);
    }
}
