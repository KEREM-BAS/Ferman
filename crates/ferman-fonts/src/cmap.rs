//! CMaps (ISO 32000-2 §9.7.5 and §9.10.3, Adobe Technical Note #5014): the codespace that splits a
//! string into codes, the CIDs of a composite font's codes, and the text of a ToUnicode CMap, read
//! as leniently as viewers read them: what cannot be read is skipped, and parsing never fails.
//!
//! `usecmap` is recorded, not followed: the caller finds the parent CMap and joins it with
//! [`CMap::inherit`] under its own depth limit (ferman-core follows embedded `/UseCMap` streams up
//! to `Limits::max_usecmap_depth`, and ferman-text joins them). A range is kept as a range, so
//! `<0000> <FFFF>` costs no more than one code.
//!
//! Back from text or a CID to a code ([`CMap::code_for_text`], [`CMap::code_for_cid`]): several
//! codes may stand for one, and the shortest, then the lowest, is taken.
//!
//! Predefined CMaps ([`CMap::predefined`]): `Identity-H` and `Identity-V`, and the ones bundled
//! from Adobe's cmap-resources (BSD-3-Clause, `data/cmap-resources/`, files unmodified): only
//! those a test document needs, `90ms-RKSJ-H` so far. A ToUnicode CMap gains entries through
//! [`with_text`].
// A parser module: offsets and values come from the data (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::HashMap;

/// The longest code a CMap has, in bytes.
const MAX_CODE: usize = 4;

/// The predefined CMaps bundled from Adobe's cmap-resources, by name.
const PREDEFINED: [(&[u8], &[u8]); 1] = [(
    b"90ms-RKSJ-H",
    include_bytes!("../data/cmap-resources/90ms-RKSJ-H"),
)];

/// How deep a predefined CMap's `usecmap` chain is followed.
const MAX_PREDEFINED_DEPTH: usize = 4;

/// A CMap: an encoding CMap of a composite font, or a ToUnicode CMap.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CMap {
    /// Codespace ranges: the low and the high code, of the same length.
    codespace: Vec<(Vec<u8>, Vec<u8>)>,
    /// CID ranges: the low and the high code, their length, and the low code's CID.
    cids: Vec<(u32, u32, usize, u32)>,
    /// `bfchar` entries: each code's length and text.
    text: HashMap<u32, (usize, String)>,
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
        length: usize,
        start: Vec<u16>,
    },
    /// Each code has its own text, in order.
    Listed {
        low: u32,
        high: u32,
        length: usize,
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
                        if let [Token::Hex(bytes), Token::Hex(text)] = pair
                            && let Some(code) = number(bytes)
                        {
                            cmap.text.insert(code, (bytes.len(), utf16(text)));
                        }
                    }
                }
                b"endbfrange" => {
                    for triple in stack.as_chunks::<3>().0 {
                        let [Token::Hex(low), Token::Hex(high), target] = triple else {
                            continue;
                        };
                        let length = low.len();
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
                                length,
                                start: units(start),
                            }),
                            Token::Array(texts) => cmap.text_ranges.push(TextRange::Listed {
                                low,
                                high,
                                length,
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

    /// The predefined CMap `name`: `Identity-H`, `Identity-V` or one bundled from Adobe's
    /// cmap-resources, with the predefined CMaps it uses; `None` for one not bundled.
    #[must_use]
    pub fn predefined(name: &[u8]) -> Option<Self> {
        match name {
            b"Identity-H" => return Some(Self::identity(false)),
            b"Identity-V" => return Some(Self::identity(true)),
            _ => {}
        }
        let find = |name: &[u8]| {
            PREDEFINED
                .iter()
                .find(|(known, _)| *known == name)
                .map(|(_, data)| Self::parse(data))
        };
        let mut cmap = find(name)?;
        for _ in 0..MAX_PREDEFINED_DEPTH {
            let Some(parent) = cmap.parent().and_then(find) else {
                break;
            };
            cmap.inherit(&parent);
        }
        Some(cmap)
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
        if let Some((_, text)) = self.text.get(&code) {
            return Some(text.clone());
        }
        self.text_ranges.iter().find_map(|range| match range {
            TextRange::Counting {
                low, high, start, ..
            } if (low..=high).contains(&&code) => {
                let mut units = start.clone();
                let last = units.last_mut()?;
                *last = last.checked_add(u16::try_from(code.checked_sub(*low)?).ok()?)?;
                Some(decode(&units))
            }
            TextRange::Listed {
                low, high, texts, ..
            } if (low..=high).contains(&&code) => texts
                .get(usize::try_from(code.checked_sub(*low)?).ok()?)
                .cloned(),
            _ => None,
        })
    }

    /// The code, with its length in bytes, whose ToUnicode text is `text`.
    #[must_use]
    pub fn code_for_text(&self, text: &str) -> Option<(u32, usize)> {
        let target: Vec<u16> = text.encode_utf16().collect();
        let chars = self
            .text
            .iter()
            .filter(|(_, (_, mapped))| mapped == text)
            .map(|(&code, &(length, _))| Some((code, length)));
        let ranges = self.text_ranges.iter().flat_map(|range| match range {
            TextRange::Counting {
                low,
                high,
                length,
                start,
            } => {
                let found = (|| {
                    let (last, prefix) = start.split_last()?;
                    let (target_last, target_prefix) = target.split_last()?;
                    if prefix != target_prefix {
                        return None;
                    }
                    let code = low.checked_add(u32::from(target_last.checked_sub(*last)?))?;
                    (code <= *high).then_some((code, *length))
                })();
                vec![found]
            }
            TextRange::Listed {
                low, length, texts, ..
            } => (0_u32..)
                .zip(texts)
                .filter(|(_, mapped)| *mapped == text)
                .map(|(offset, _)| Some((low.checked_add(offset)?, *length)))
                .collect(),
        });
        chars
            .chain(ranges)
            .flatten()
            // An earlier entry for the same code wins, as in `text`.
            .filter(|&(code, _)| self.text(code).as_deref() == Some(text))
            .min_by_key(|&(code, length)| (length, code))
    }

    /// The code, with its length in bytes, whose CID is `cid`.
    #[must_use]
    pub fn code_for_cid(&self, cid: u32) -> Option<(u32, usize)> {
        self.cids
            .iter()
            .filter_map(|&(low, high, length, first)| {
                let code = low.checked_add(cid.checked_sub(first)?)?;
                (code <= high && self.cid(code, length) == Some(cid)).then_some((code, length))
            })
            .min_by_key(|&(code, length)| (length, code))
    }
}

/// The ToUnicode CMap `original` (or, without one, a new CMap) with `added` codes, each its bytes
/// and its text, as `bfchar` entries. Every code must be one `original` has no text for, so the
/// new entries never change the text of a code it maps; a code of one to four bytes.
#[must_use]
pub fn with_text(original: Option<&[u8]>, added: &[(Vec<u8>, String)]) -> Vec<u8> {
    let mut entries = Vec::new();
    for chunk in added.chunks(100) {
        entries.extend_from_slice(format!("{} beginbfchar\n", chunk.len()).as_bytes());
        for (code, text) in chunk {
            hex(&mut entries, code);
            entries.push(b' ');
            let units: Vec<u8> = text.encode_utf16().flat_map(u16::to_be_bytes).collect();
            hex(&mut entries, &units);
            entries.push(b'\n');
        }
        entries.extend_from_slice(b"endbfchar\n");
    }
    let Some(original) = original else {
        let mut out = b"/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n\
/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n\
/CMapName /Adobe-Identity-UCS def\n/CMapType 2 def\n"
            .to_vec();
        let mut lengths: Vec<usize> = added
            .iter()
            .map(|(code, _)| code.len())
            .filter(|length| (1..=MAX_CODE).contains(length))
            .collect();
        lengths.sort_unstable();
        lengths.dedup();
        out.extend_from_slice(format!("{} begincodespacerange\n", lengths.len()).as_bytes());
        for length in lengths {
            hex(&mut out, &vec![0; length]);
            out.push(b' ');
            hex(&mut out, &vec![0xFF; length]);
            out.push(b'\n');
        }
        out.extend_from_slice(b"endcodespacerange\n");
        out.extend(entries);
        out.extend_from_slice(
            b"endcmap\nCMapName currentdict /CMap defineresource pop\nend\nend\n",
        );
        return out;
    };
    // The entries go before the last `endcmap`, or at the end of a CMap without one.
    let at = original
        .windows(b"endcmap".len())
        .rposition(|window| window == b"endcmap")
        .unwrap_or(original.len());
    let (head, tail) = original.split_at_checked(at).unwrap_or((original, &[]));
    let mut out = head.to_vec();
    if !out.ends_with(b"\n") {
        out.push(b'\n');
    }
    out.extend(entries);
    out.extend_from_slice(tail);
    out
}

/// `<…>` with `bytes` in upper-case hex.
fn hex(out: &mut Vec<u8>, bytes: &[u8]) {
    out.push(b'<');
    for byte in bytes {
        out.extend_from_slice(format!("{byte:02X}").as_bytes());
    }
    out.push(b'>');
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
pub(crate) enum Token<'a> {
    Hex(Vec<u8>),
    Integer(i64),
    Name(&'a [u8]),
    Keyword(&'a [u8]),
    /// An array of hex strings; anything else in it is dropped.
    Array(Vec<Vec<u8>>),
}

/// The tokens of a CMap or a Type1 program's clear text. Strings, dictionaries' brackets,
/// procedures and real numbers are skipped.
pub(crate) struct Tokens<'a> {
    data: &'a [u8],
    at: usize,
}

impl<'a> Tokens<'a> {
    pub(crate) fn new(data: &'a [u8]) -> Self {
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
    fn a_to_unicode_cmap_maps_text_back_to_the_shortest_lowest_code() {
        let cmap = CMap::parse(
            b"2 begincodespacerange <00> <7F> <8000> <FFFF> endcodespacerange
4 beginbfchar
<8001> <0041>
<41> <0041>
<9000> <00660069>
<31> <0131>
endbfchar
3 beginbfrange
<8100> <810F> <0100>
<8200> <8202> [<011F> <015F> <011F>]
<30> <32> <0130>
endbfrange",
        );
        assert_eq!(
            cmap.code_for_text("A"),
            Some((0x41, 1)),
            "one byte before two"
        );
        assert_eq!(cmap.code_for_text("fi"), Some((0x9000, 2)));
        assert_eq!(
            cmap.code_for_text("ğ"),
            Some((0x8200, 2)),
            "the lowest of two listed codes"
        );
        assert_eq!(cmap.code_for_text("ş"), Some((0x8201, 2)));
        assert_eq!(cmap.code_for_text("İ"), Some((0x30, 1)));
        assert_eq!(
            cmap.code_for_text("ı"),
            Some((0x31, 1)),
            "bfchar overrides the range"
        );
        assert_eq!(cmap.code_for_text("Ĳ"), Some((0x32, 1)));
        assert_eq!(cmap.code_for_text("ď"), Some((0x810F, 2)));
        assert_eq!(cmap.code_for_text("Đ"), None, "past the range's end");
        assert_eq!(cmap.code_for_text("B"), None);
        assert_eq!(cmap.code_for_text(""), None);
        // Every code of the shared ToUnicode comes back, ligatures and surrogates included; 0x32
        // and 0x21 are both "ı", and the lower wins.
        let shared = CMap::parse(TO_UNICODE);
        for code in [3, 0x11, 0x12, 0x20, 0x21, 0x22, 0x30, 0x31, 0x32] {
            let text = shared.text(code).unwrap();
            let expected = if code == 0x32 { 0x21 } else { code };
            assert_eq!(
                shared.code_for_text(&text),
                Some((expected, 2)),
                "{code:#x}"
            );
        }
    }

    #[test]
    fn an_encoding_cmap_maps_cids_back_to_the_shortest_lowest_code() {
        let cmap = CMap::parse(
            b"2 begincodespacerange <00> <80> <8140> <9FFC> endcodespacerange
2 begincidrange <8140> <817E> 633 <9000> <9010> 640 endcidrange
2 begincidchar <41> 640 <8150> 7 endcidchar",
        );
        assert_eq!(cmap.code_for_cid(633), Some((0x8140, 2)));
        assert_eq!(
            cmap.code_for_cid(640),
            Some((0x41, 1)),
            "one byte before two"
        );
        assert_eq!(
            cmap.code_for_cid(641),
            Some((0x8148, 2)),
            "the lowest of two codes"
        );
        assert_eq!(
            cmap.code_for_cid(649),
            Some((0x8150, 2)),
            "the range wins over cidchar"
        );
        assert_eq!(
            cmap.code_for_cid(7),
            None,
            "an earlier range shadows the cidchar"
        );
        assert_eq!(cmap.code_for_cid(10_000), None);
        assert_eq!(
            CMap::identity(false).code_for_cid(0x0102),
            Some((0x0102, 2))
        );
        assert_eq!(CMap::identity(false).code_for_cid(0x1_0000), None);
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
    fn predefined_cmaps_split_shift_jis_into_adobe_japan1_cids() {
        let cmap = CMap::predefined(b"90ms-RKSJ-H").unwrap();
        assert!(!cmap.is_vertical());
        // "A", hiragana "あ" (JIS row 4, cell 2) and katakana "ア" (row 5, cell 2).
        let codes: Vec<(u32, usize)> = cmap.codes(b"A\x82\xa0\x83\x41").collect();
        assert_eq!(codes, [(0x41, 1), (0x82A0, 2), (0x8341, 2)]);
        assert_eq!(cmap.cid(0x41, 1), Some(231 + 0x41 - 0x20));
        assert_eq!(cmap.cid(0x82A0, 2), Some(843));
        assert_eq!(cmap.cid(0x8341, 2), Some(926));
        assert_eq!(cmap.code_for_cid(843), Some((0x82A0, 2)));
        assert!(CMap::predefined(b"Identity-V").unwrap().is_vertical());
        assert_eq!(CMap::predefined(b"Identity-H"), Some(CMap::identity(false)));
        assert_eq!(CMap::predefined(b"GBK-EUC-H"), None, "not bundled");
    }

    #[test]
    fn a_to_unicode_cmap_gains_entries_and_keeps_its_own() {
        let added = [
            (vec![0x00, 0x40], "ğ".to_owned()),
            (vec![0x01, 0x00], "😀".to_owned()),
        ];
        let extended = CMap::parse(&with_text(Some(TO_UNICODE), &added));
        assert_eq!(extended.text(0x40).as_deref(), Some("ğ"));
        assert_eq!(extended.text(0x100).as_deref(), Some("😀"));
        // Every code the original maps reads as before.
        let original = CMap::parse(TO_UNICODE);
        for code in [3, 0x11, 0x12, 0x20, 0x21, 0x22, 0x30, 0x31, 0x32, 0x33] {
            assert_eq!(extended.text(code), original.text(code), "{code:#x}");
        }
        // Without an original, a CMap of its own with a codespace for the codes' lengths.
        let fresh = CMap::parse(&with_text(None, &added));
        assert_eq!(fresh.text(0x40).as_deref(), Some("ğ"));
        assert_eq!(fresh.codes(b"\x00\x40").collect::<Vec<_>>(), [(0x40, 2)]);
        // More than a hundred entries go in blocks of a hundred.
        let many: Vec<(Vec<u8>, String)> = (0_u16..250)
            .map(|code| (code.to_be_bytes().to_vec(), "x".to_owned()))
            .collect();
        let data = with_text(None, &many);
        let text = String::from_utf8(data.clone()).unwrap();
        assert_eq!(text.matches("beginbfchar").count(), 3);
        assert_eq!(CMap::parse(&data).text(249).as_deref(), Some("x"));
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
