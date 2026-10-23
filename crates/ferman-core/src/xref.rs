//! Cross-reference data (ISO 32000-2 §7.5.4 to §7.5.8): tables and streams, followed from
//! `startxref` through `/Prev` and the `/XRefStm` of hybrid files, then checked against the
//! objects they point at. ferman-core reads it itself, before lopdf parses the objects, so that a
//! broken table is found and rebuilt (lopdf 0.45 accepts a table whose offsets are wrong and
//! loads no objects), a `/Prev` loop or chain past [`Limits::max_xref_sections`] stops, and an
//! encrypted file can be decrypted by ferman-core's own security handler.
// A parser module: offsets and sizes come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet};
use std::io::Write as _;

use lopdf::{Dictionary, Object, ObjectId};

use crate::CoreError;
use crate::filters;
use crate::limits::{LimitKind, Limits};
use crate::syntax::{self, Lexer, Parser, Token};

/// How far from the end `startxref` is looked for.
const STARTXREF_WINDOW: usize = 64 * 1024;

/// One cross-reference entry.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Entry {
    /// A free or deleted object.
    Free,
    /// An object at `offset` from the header.
    Normal {
        /// Where `n g obj` starts.
        offset: usize,
        /// The generation.
        generation: u16,
    },
    /// An object inside the object stream `container`.
    Compressed {
        /// The object stream's number.
        container: u32,
        /// The object's place in it.
        index: u32,
    },
}

/// The cross-reference data of a file, newest entries first.
#[derive(Debug, Clone, Default)]
pub(crate) struct Xref {
    /// Every object number's newest entry.
    pub(crate) entries: BTreeMap<u32, Entry>,
    /// The trailer: the newest section's keys, with older sections' keys it lacks.
    pub(crate) trailer: Dictionary,
    /// The sections read.
    pub(crate) sections: u32,
    /// The highest object number plus one, from `/Size` or the entries.
    pub(crate) size: u32,
}

impl Xref {
    /// The object ids in use, from normal and compressed entries.
    pub(crate) fn in_use(&self) -> impl Iterator<Item = ObjectId> + '_ {
        self.entries
            .iter()
            .filter(|(number, _)| **number != 0)
            .filter_map(|(&number, entry)| match *entry {
                Entry::Normal { generation, .. } => Some((number, generation)),
                Entry::Compressed { .. } => Some((number, 0)),
                Entry::Free => None,
            })
    }

    /// Where object `id` starts, if it is a normal entry.
    pub(crate) fn offset_of(&self, id: ObjectId) -> Option<usize> {
        match self.entries.get(&id.0) {
            Some(Entry::Normal { offset, generation }) if *generation == id.1 => Some(*offset),
            _ => None,
        }
    }

    /// The object streams that hold compressed entries.
    pub(crate) fn containers(&self) -> BTreeSet<u32> {
        self.entries
            .values()
            .filter_map(|entry| match entry {
                Entry::Compressed { container, .. } => Some(*container),
                _ => None,
            })
            .collect()
    }
}

/// Why a file's own cross-reference data cannot be used, so that it is rebuilt.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum XrefProblem {
    /// No `startxref` near the end of the file.
    NoStartxref,
    /// `startxref` points outside the file.
    StartxrefOutside,
    /// `startxref` or `/Prev` points at something that is not cross-reference data.
    NotAnXref {
        /// The offset, from the header.
        offset: u64,
    },
    /// Cross-reference data that cannot be read.
    Malformed {
        /// Where, from the header.
        offset: u64,
    },
    /// An entry points where its object is not.
    WrongOffset {
        /// The object number.
        object: u32,
    },
    /// A compressed object's object stream has no entry.
    MissingContainer {
        /// The compressed object's number.
        object: u32,
    },
    /// The trailer has no `/Root`, or it names no object.
    NoRoot,
}

fn offset_u64(offset: usize) -> u64 {
    u64::try_from(offset).unwrap_or(u64::MAX)
}

/// One section: its entries and its trailer.
struct Section {
    entries: BTreeMap<u32, Entry>,
    trailer: Dictionary,
}

/// Reads and checks the cross-reference data of `data`, which starts at the `%PDF-` header.
///
/// `Ok(Err(problem))` when it is missing, broken or points at the wrong places, so the caller
/// rebuilds it.
///
/// # Errors
///
/// [`CoreError::ResourceLimit`] past [`Limits::max_xref_sections`] or another limit, and
/// [`CoreError::OutOfMemory`].
pub(crate) fn read(data: &[u8], limits: &Limits) -> Result<Result<Xref, XrefProblem>, CoreError> {
    let Some(start) = startxref(data) else {
        return Ok(Err(XrefProblem::NoStartxref));
    };
    if start >= data.len() {
        return Ok(Err(XrefProblem::StartxrefOutside));
    }
    let mut xref = Xref::default();
    let mut visited = BTreeSet::new();
    let mut next = Some(start);
    while let Some(offset) = next.take() {
        // A loop through /Prev ends the chain: every section in it has been read.
        if !visited.insert(offset) {
            break;
        }
        count_section(&mut xref, limits)?;
        let mut section = match section_at(data, offset, limits)? {
            Ok(section) => section,
            Err(problem) => return Ok(Err(problem)),
        };
        // A hybrid file: the hidden stream's entries fill the table's free entries.
        if let Some(stream) = integer_entry(&section.trailer, b"XRefStm")
            && visited.insert(stream)
        {
            count_section(&mut xref, limits)?;
            match section_at(data, stream, limits)? {
                Ok(hidden) => {
                    for (number, entry) in hidden.entries {
                        let slot = section.entries.entry(number).or_insert(entry);
                        if *slot == Entry::Free {
                            *slot = entry;
                        }
                    }
                }
                Err(problem) => return Ok(Err(problem)),
            }
        }
        next = integer_entry(&section.trailer, b"Prev");
        for (number, entry) in section.entries {
            xref.entries.entry(number).or_insert(entry);
        }
        for (key, value) in section.trailer.iter() {
            if !xref.trailer.has(key) {
                xref.trailer.set(key.clone(), value.clone());
            }
        }
    }
    xref.size = size_of(&xref);
    Ok(check(data, &xref).map(|()| xref))
}

fn count_section(xref: &mut Xref, limits: &Limits) -> Result<(), CoreError> {
    xref.sections = xref.sections.saturating_add(1);
    if xref.sections > limits.max_xref_sections {
        return Err(CoreError::ResourceLimit {
            limit: LimitKind::XrefSections,
            max: u64::from(limits.max_xref_sections),
        });
    }
    Ok(())
}

/// `/Size`, or one past the highest entry when that is larger.
pub(crate) fn size_of(xref: &Xref) -> u32 {
    let declared = xref
        .trailer
        .get(b"Size")
        .ok()
        .and_then(|size| size.as_i64().ok())
        .and_then(|size| u32::try_from(size).ok())
        .unwrap_or(0);
    let highest = xref
        .entries
        .keys()
        .next_back()
        .map_or(1, |number| number.saturating_add(1));
    declared.max(highest)
}

/// A non-negative integer entry of a trailer as an offset.
fn integer_entry(dict: &Dictionary, key: &[u8]) -> Option<usize> {
    dict.get(key)
        .ok()
        .and_then(|value| value.as_i64().ok())
        .and_then(|value| usize::try_from(value).ok())
}

/// The offset after the last `startxref` near the end of `data`.
fn startxref(data: &[u8]) -> Option<usize> {
    let from = data.len().saturating_sub(STARTXREF_WINDOW);
    let tail = data.get(from..)?;
    let at = syntax::rfind(tail, b"startxref", tail.len())?;
    let keyword = from.checked_add(at)?.checked_add(9)?;
    let mut lexer = Lexer::new(data, keyword);
    match lexer.next_token() {
        Ok(Some((Token::Integer(offset), _))) => usize::try_from(offset).ok(),
        _ => None,
    }
}

/// The section at `offset`: a table with its trailer, or a stream.
fn section_at(
    data: &[u8],
    offset: usize,
    limits: &Limits,
) -> Result<Result<Section, XrefProblem>, CoreError> {
    if offset >= data.len() {
        return Ok(Err(XrefProblem::NotAnXref {
            offset: offset_u64(offset),
        }));
    }
    let mut lexer = Lexer::new(data, offset);
    lexer.skip_whitespace();
    let at = lexer.pos();
    if data.get(at..).is_some_and(|rest| rest.starts_with(b"xref")) {
        return table(data, at.saturating_add(4), limits);
    }
    stream(data, at, limits)
}

fn malformed_at(offset: usize) -> XrefProblem {
    XrefProblem::Malformed {
        offset: offset_u64(offset),
    }
}

/// A cross-reference table after its `xref` keyword, with its trailer.
fn table(
    data: &[u8],
    after_keyword: usize,
    limits: &Limits,
) -> Result<Result<Section, XrefProblem>, CoreError> {
    let mut parser = Parser::new(data, after_keyword, limits);
    let mut entries = BTreeMap::new();
    loop {
        if parser.eat_keyword(b"trailer").unwrap_or(false) {
            break;
        }
        let at = parser.pos();
        let (Ok(Some(first)), Ok(Some(count))) = (parser.integer(), parser.integer()) else {
            return Ok(Err(malformed_at(at)));
        };
        let (Ok(first), Ok(count)) = (u32::try_from(first), u32::try_from(count)) else {
            return Ok(Err(malformed_at(at)));
        };
        for index in 0..count {
            let at = parser.pos();
            let (Ok(Some(offset)), Ok(Some(generation))) = (parser.integer(), parser.integer())
            else {
                return Ok(Err(malformed_at(at)));
            };
            let in_use = if parser.eat_keyword(b"n").unwrap_or(false) {
                true
            } else if parser.eat_keyword(b"f").unwrap_or(false) {
                false
            } else {
                return Ok(Err(malformed_at(at)));
            };
            let Some(number) = first.checked_add(index) else {
                return Ok(Err(malformed_at(at)));
            };
            let entry = match (in_use, usize::try_from(offset), u16::try_from(generation)) {
                (true, Ok(offset), Ok(generation)) => Entry::Normal { offset, generation },
                (true, _, _) => return Ok(Err(malformed_at(at))),
                (false, _, _) => Entry::Free,
            };
            // Within one table the first entry for a number counts.
            entries.entry(number).or_insert(entry);
        }
    }
    let at = parser.pos();
    let trailer = match parser.object() {
        Ok(Object::Dictionary(trailer)) => trailer,
        Ok(_) => return Ok(Err(malformed_at(at))),
        Err(CoreError::Syntax { .. }) => return Ok(Err(malformed_at(at))),
        Err(other) => return Err(other),
    };
    Ok(Ok(Section { entries, trailer }))
}

/// A cross-reference stream at `offset`.
fn stream(
    data: &[u8],
    offset: usize,
    limits: &Limits,
) -> Result<Result<Section, XrefProblem>, CoreError> {
    let not_an_xref = || {
        Ok(Err(XrefProblem::NotAnXref {
            offset: offset_u64(offset),
        }))
    };
    let indirect = match Parser::new(data, offset, limits).indirect(&|_| None) {
        Ok(indirect) => indirect,
        Err(CoreError::Syntax { .. }) => return not_an_xref(),
        Err(other) => return Err(other),
    };
    let (Object::Dictionary(dict), Some(range)) = (indirect.object, indirect.data) else {
        return not_an_xref();
    };
    if !dict.has(b"W") {
        return not_an_xref();
    }
    let Some(encoded) = data.get(range) else {
        return Ok(Err(malformed_at(offset)));
    };
    let decoded = match filters::chain_of(&dict)
        .and_then(|steps| filters::decode_chain(&steps, encoded, limits))
    {
        Ok(decoded) => decoded,
        Err(
            CoreError::Syntax { .. }
            | CoreError::DamagedStream { .. }
            | CoreError::InvalidDecodeParams { .. }
            | CoreError::Unsupported(_),
        ) => return Ok(Err(malformed_at(offset))),
        Err(other) => return Err(other),
    };
    let Some(entries) = stream_entries(&dict, &decoded) else {
        return Ok(Err(malformed_at(offset)));
    };
    let mut trailer = dict;
    for key in [
        &b"Length"[..],
        b"Filter",
        b"DecodeParms",
        b"W",
        b"Index",
        b"Type",
    ] {
        trailer.remove(key);
    }
    Ok(Ok(Section { entries, trailer }))
}

/// The entries of a decoded cross-reference stream, or `None` when `/W` or `/Index` is invalid.
fn stream_entries(dict: &Dictionary, decoded: &[u8]) -> Option<BTreeMap<u32, Entry>> {
    let widths: Vec<usize> = dict
        .get(b"W")
        .ok()?
        .as_array()
        .ok()?
        .iter()
        .map(|width| width.as_i64().ok().and_then(|w| usize::try_from(w).ok()))
        .collect::<Option<_>>()?;
    let [w0, w1, w2] = <[usize; 3]>::try_from(widths).ok()?;
    if w0 > 8 || w1 > 8 || w2 > 8 {
        return None;
    }
    let row = w0.checked_add(w1)?.checked_add(w2)?;
    if row == 0 {
        return None;
    }
    let size = dict.get(b"Size").ok()?.as_i64().ok()?;
    let index: Vec<i64> = match dict.get(b"Index") {
        Ok(Object::Array(items)) => items
            .iter()
            .map(|item| item.as_i64().ok())
            .collect::<Option<_>>()?,
        _ => vec![0, size],
    };
    let mut entries = BTreeMap::new();
    let mut rows = decoded.chunks_exact(row);
    for &[first, count] in index.as_chunks::<2>().0 {
        let first = u32::try_from(first).ok()?;
        let count = u32::try_from(count).ok()?;
        for index in 0..count {
            // A stream shorter than its /Index ends the entries.
            let Some(bytes) = rows.next() else {
                return Some(entries);
            };
            let number = first.checked_add(index)?;
            let field = |from: usize, width: usize| -> Option<u64> {
                let bytes = bytes.get(from..from.checked_add(width)?)?;
                Some(
                    bytes
                        .iter()
                        .fold(0u64, |value, &byte| value.wrapping_shl(8) | u64::from(byte)),
                )
            };
            let kind = if w0 == 0 { 1 } else { field(0, w0)? };
            let second = field(w0, w1)?;
            let third = field(w0.checked_add(w1)?, w2)?;
            let entry = match kind {
                0 => Entry::Free,
                1 => Entry::Normal {
                    offset: usize::try_from(second).ok()?,
                    generation: u16::try_from(third).ok()?,
                },
                2 => Entry::Compressed {
                    container: u32::try_from(second).ok()?,
                    index: u32::try_from(third).ok()?,
                },
                // Other types are references to the null object (ISO 32000-2 §7.5.8.3).
                _ => continue,
            };
            entries.entry(number).or_insert(entry);
        }
    }
    Some(entries)
}

/// Whether every entry points at its object and the trailer names a catalog.
fn check(data: &[u8], xref: &Xref) -> Result<(), XrefProblem> {
    for (&number, entry) in &xref.entries {
        if number == 0 {
            continue;
        }
        match *entry {
            Entry::Normal { offset, generation } => {
                if !syntax::header_at(data, offset, (number, generation)) {
                    return Err(XrefProblem::WrongOffset { object: number });
                }
            }
            Entry::Compressed { container, .. } => {
                if !matches!(xref.entries.get(&container), Some(Entry::Normal { .. })) {
                    return Err(XrefProblem::MissingContainer { object: number });
                }
            }
            Entry::Free => {}
        }
    }
    let root = xref
        .trailer
        .get(b"Root")
        .ok()
        .and_then(|root| root.as_reference().ok());
    match root.and_then(|root| xref.entries.get(&root.0)) {
        Some(Entry::Normal { .. } | Entry::Compressed { .. }) => Ok(()),
        _ => Err(XrefProblem::NoRoot),
    }
}

/// `base` with a cross-reference table of `xref`'s normal entries appended, leaving out
/// `exclude`, and a trailer with only `/Size`, `/Root`, `/Info` and `/ID`. lopdf reads it as a
/// file with one clean section, so it parses each object where ferman-core found it, and an
/// encrypted file's objects as they stand, for ferman-core to decrypt.
///
/// # Errors
///
/// [`CoreError::OutOfMemory`] when the copy cannot be reserved.
pub(crate) fn flatten(
    base: &[u8],
    xref: &Xref,
    exclude: &BTreeSet<u32>,
) -> Result<Vec<u8>, CoreError> {
    let normal: Vec<(u32, usize, u16)> = xref
        .entries
        .iter()
        .filter(|(number, _)| **number != 0 && !exclude.contains(number))
        .filter_map(|(&number, entry)| match *entry {
            Entry::Normal { offset, generation } => Some((number, offset, generation)),
            _ => None,
        })
        .collect();
    let table = normal.len().saturating_mul(20).saturating_add(256);
    let mut out = Vec::new();
    out.try_reserve_exact(base.len().saturating_add(table))
        .map_err(|_| CoreError::OutOfMemory {
            context: "the copy for lopdf",
        })?;
    out.extend_from_slice(base);
    let xref_at = out.len().saturating_add(1);
    // Writing into a Vec cannot fail.
    let _ = write!(out, "\nxref\n0 1\n0000000000 65535 f\r\n");
    let mut run = 0usize;
    while let Some(&(first, _, _)) = normal.get(run) {
        let mut end = run.saturating_add(1);
        while let (Some(&(previous, _, _)), Some(&(number, _, _))) =
            (normal.get(end.saturating_sub(1)), normal.get(end))
        {
            if previous.checked_add(1) != Some(number) {
                break;
            }
            end = end.saturating_add(1);
        }
        let _ = writeln!(out, "{first} {}", end.saturating_sub(run));
        for &(_, offset, generation) in normal.get(run..end).unwrap_or_default() {
            let _ = write!(out, "{offset:010} {generation:05} n\r\n");
        }
        run = end;
    }
    let _ = write!(out, "trailer\n<< /Size {}", xref.size.max(1));
    for key in [&b"Root"[..], b"Info"] {
        if let Ok(Object::Reference((number, generation))) = xref.trailer.get(key) {
            let _ = write!(
                out,
                " /{} {number} {generation} R",
                String::from_utf8_lossy(key)
            );
        }
    }
    if let Ok(Object::Array(ids)) = xref.trailer.get(b"ID") {
        let strings: Vec<&[u8]> = ids.iter().filter_map(|id| id.as_str().ok()).collect();
        if strings.len() == 2 {
            out.extend_from_slice(b" /ID [");
            for id in strings {
                out.push(b'<');
                for byte in id {
                    let _ = write!(out, "{byte:02X}");
                }
                out.push(b'>');
            }
            out.push(b']');
        }
    }
    let _ = write!(out, " >>\nstartxref\n{xref_at}\n%%EOF\n");
    Ok(out)
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
pub(crate) mod tests {
    use super::*;
    use std::fmt::Write as _;

    /// A file with objects 1 to 3 (catalog, pages, page) and a correct table, with `extra` before
    /// the table and `mangle` applied to the offsets.
    pub(crate) fn simple(mangle: impl Fn(usize) -> usize) -> Vec<u8> {
        let mut out = String::from("%PDF-1.7\n");
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>",
        ];
        let mut offsets = Vec::new();
        for (index, body) in objects.iter().enumerate() {
            offsets.push(out.len());
            let _ = write!(out, "{} 0 obj\n{body}\nendobj\n", index + 1);
        }
        let start = out.len();
        out.push_str("xref\n0 4\n0000000000 65535 f\r\n");
        for offset in offsets {
            let _ = write!(out, "{:010} 00000 n\r\n", mangle(offset));
        }
        let _ = write!(
            out,
            "trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n{start}\n%%EOF\n"
        );
        out.into_bytes()
    }

    #[test]
    fn a_correct_table_is_read() {
        let data = simple(|offset| offset);
        let xref = read(&data, &Limits::default()).unwrap().unwrap();
        assert_eq!(xref.sections, 1);
        assert_eq!(xref.size, 4);
        assert_eq!(xref.in_use().collect::<Vec<_>>(), [(1, 0), (2, 0), (3, 0)]);
        assert_eq!(
            xref.trailer.get(b"Root").unwrap().as_reference().unwrap(),
            (1, 0)
        );
        assert_eq!(xref.offset_of((1, 0)), Some(9));
        assert_eq!(xref.offset_of((1, 1)), None);
    }

    #[test]
    fn offsets_two_bytes_early_are_wrong() {
        let data = simple(|offset| offset - 2);
        assert_eq!(
            read(&data, &Limits::default()).unwrap().unwrap_err(),
            XrefProblem::WrongOffset { object: 1 }
        );
    }

    #[test]
    fn offsets_at_white_space_before_the_header_are_right() {
        // An offset at the newline before "2 0 obj" still finds it.
        let data = simple(|offset| if offset > 9 { offset - 1 } else { offset });
        assert!(read(&data, &Limits::default()).unwrap().is_ok());
    }

    #[test]
    fn a_missing_or_wrong_startxref_is_a_problem() {
        let data = simple(|offset| offset);
        let text = String::from_utf8(data.clone()).unwrap();
        let none = text.replace("startxref", "startxrex");
        assert_eq!(
            read(none.as_bytes(), &Limits::default())
                .unwrap()
                .unwrap_err(),
            XrefProblem::NoStartxref
        );
        let start = text.find("xref\n0 4").unwrap();
        let outside = text.replace(&format!("startxref\n{start}"), "startxref\n999999");
        assert_eq!(
            read(outside.as_bytes(), &Limits::default())
                .unwrap()
                .unwrap_err(),
            XrefProblem::StartxrefOutside
        );
        let elsewhere = text.replace(&format!("startxref\n{start}"), "startxref\n12");
        assert!(matches!(
            read(elsewhere.as_bytes(), &Limits::default())
                .unwrap()
                .unwrap_err(),
            XrefProblem::NotAnXref { .. }
        ));
    }

    /// A chain of `sections` table sections, each `/Prev` pointing at the one before; with
    /// `loop_back`, the first points at the last.
    pub(crate) fn chain(sections: usize, loop_back: bool) -> Vec<u8> {
        let mut out = String::from("%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n");
        let mut previous: Option<usize> = None;
        let mut first = 0;
        for index in 0..sections {
            let at = out.len();
            if index == 0 {
                first = at;
            }
            let _ = write!(
                out,
                "xref\n0 2\n0000000000 65535 f\r\n0000000009 00000 n\r\ntrailer\n<< /Size 2 /Root 1 0 R"
            );
            match previous {
                Some(previous) => {
                    let _ = write!(out, " /Prev {previous}");
                }
                None if loop_back => {
                    // Filled in below: the first section points at the last.
                    out.push_str(" /Prev LAST");
                }
                None => {}
            }
            out.push_str(" >>\n");
            previous = Some(at);
        }
        let last = previous.unwrap_or(first);
        let _ = write!(out, "startxref\n{last}\n%%EOF\n");
        out.replace("LAST", &format!("{last:>4}")).into_bytes()
    }

    #[test]
    fn a_prev_chain_past_the_limit_is_a_resource_limit() {
        let limits = Limits {
            max_xref_sections: 10,
            ..Limits::default()
        };
        assert_eq!(
            read(&chain(10, false), &limits).unwrap().unwrap().sections,
            10
        );
        assert!(matches!(
            read(&chain(11, false), &limits),
            Err(CoreError::ResourceLimit {
                limit: LimitKind::XrefSections,
                max: 10
            })
        ));
    }

    #[test]
    fn a_prev_loop_ends_the_chain() {
        let xref = read(&chain(3, true), &Limits::default()).unwrap().unwrap();
        assert_eq!(xref.sections, 3);
    }

    #[test]
    fn stream_entries_read_every_type() {
        // /W [1 2 1]: a free entry, object 1 at offset 9, object 2 in stream 5 at index 3.
        let mut dict = Dictionary::new();
        dict.set("W", vec![1.into(), 2.into(), 1.into()]);
        dict.set("Size", 3);
        let rows = [0, 0, 0, 255, 1, 0, 9, 0, 2, 0, 5, 3];
        let entries = stream_entries(&dict, &rows).unwrap();
        assert_eq!(entries.get(&0), Some(&Entry::Free));
        assert_eq!(
            entries.get(&1),
            Some(&Entry::Normal {
                offset: 9,
                generation: 0
            })
        );
        assert_eq!(
            entries.get(&2),
            Some(&Entry::Compressed {
                container: 5,
                index: 3
            })
        );
        // /Index and a type field of width 0, which means type 1.
        dict.set("W", vec![0.into(), 1.into(), 0.into()]);
        dict.set("Index", vec![7.into(), 2.into()]);
        let entries = stream_entries(&dict, &[20, 30]).unwrap();
        assert_eq!(
            entries.get(&8),
            Some(&Entry::Normal {
                offset: 30,
                generation: 0
            })
        );
        dict.set("W", vec![9.into(), 1.into(), 0.into()]);
        assert!(stream_entries(&dict, &[]).is_none());
    }

    #[test]
    fn the_flat_copy_has_one_clean_table() {
        let data = simple(|offset| offset - 2);
        let mut xref = Xref::default();
        for (number, offset) in [(1u32, 9usize), (2, 52), (3, 104)] {
            xref.entries.insert(
                number,
                Entry::Normal {
                    offset,
                    generation: 0,
                },
            );
        }
        xref.trailer.set("Root", Object::Reference((1, 0)));
        xref.trailer.set(
            "ID",
            vec![
                Object::String(vec![0xAB, 1], lopdf::StringFormat::Hexadecimal),
                Object::String(vec![0xAB, 1], lopdf::StringFormat::Hexadecimal),
            ],
        );
        xref.size = 4;
        let flat = flatten(&data, &xref, &BTreeSet::from([3])).unwrap();
        let text = String::from_utf8_lossy(&flat[data.len()..]).into_owned();
        assert!(
            text.starts_with("\nxref\n0 1\n0000000000 65535 f\r\n1 2\n0000000009 00000 n\r\n0000000052 00000 n\r\ntrailer\n<< /Size 4 /Root 1 0 R /ID [<AB01><AB01>] >>\nstartxref\n"),
            "{text}"
        );
        assert!(text.ends_with("%%EOF\n"));
    }
}
