//! Repair (docs/ARCHITECTURE.md §5.2, a1-9 and a1-9b): when a file's cross-reference data is
//! missing or points at the wrong places, the objects are found by scanning the file and the
//! table is rebuilt from them. A repaired document is read-only until "Save repaired copy…"
//! writes it as a new file (M3); Ferman never edits on top of rebuilt data. A file in which no
//! catalog can be found cannot be opened, and [`Diagnosis`] says what was found instead.
// A parser module: offsets and sizes come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet};

use lopdf::{Dictionary, Object, ObjectId};

use crate::CoreError;
use crate::limits::Limits;
use crate::syntax::{self, Parser, is_regular, is_whitespace};
use crate::xref::{Entry, Xref};

pub use crate::xref::XrefProblem;

/// What repair did, for the notice of a1-9 and the technical details.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct RepairReport {
    /// Each repair, in the order it was made.
    pub repairs: Vec<Repair>,
}

/// One repair.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[non_exhaustive]
pub enum Repair {
    /// The cross-reference table was rebuilt from the objects found in the file ("Rebuilt from
    /// the 48 objects found in the file.").
    CrossReferenceRebuilt {
        /// The objects found.
        objects: u32,
        /// What was wrong with the file's own table.
        problem: XrefProblem,
    },
    /// The trailer was missing, and the catalog was found among the objects.
    TrailerRebuilt,
    /// Streams whose `/Length` was wrong were read up to their `endstream`.
    StreamLengthsCorrected {
        /// How many.
        streams: u32,
    },
    /// Objects that the cross-reference data names could not be read; the pages and features
    /// that use them may be incomplete.
    ObjectsUnreadable {
        /// How many.
        objects: u32,
        /// The lowest object number among them, for the technical details.
        first: u32,
    },
}

/// Why a file cannot be opened at all (a1-9b): structural facts only, never document text.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Diagnosis {
    /// The likely cause, for the sentence.
    pub likely_cause: LikelyCause,
    /// The size of the file, from the `%PDF-` header.
    pub file_size: u64,
    /// The size the file says it has (a linearized file's `/L`), when it says so.
    pub expected_size: Option<u64>,
    /// The last object read to its `endobj`, for "last complete object 12 0 obj".
    pub last_complete_object: Option<ObjectId>,
    /// How many objects were found.
    pub objects_found: u32,
    /// Whether a trailer was found.
    pub has_trailer: bool,
}

/// The likely cause of a file that cannot be opened.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum LikelyCause {
    /// The file stops inside an object: "It was probably cut off while downloading or copying."
    Truncated,
    /// The file has objects but no document catalog to start from.
    NoCatalog,
    /// No objects were found.
    NoObjects,
    /// The cross-reference data reads, but lopdf cannot load the document from it.
    Unreadable,
}

/// What a scan of the whole file found.
#[derive(Debug, Default)]
pub(crate) struct Scan {
    /// Each object number's last definition in the file: where it starts and its generation.
    pub(crate) objects: BTreeMap<u32, (usize, u16)>,
    /// Object streams among them.
    pub(crate) object_streams: BTreeSet<u32>,
    /// Object headers read, counting repeated numbers once per definition.
    pub(crate) headers: u32,
    /// Trailer dictionaries and cross-reference stream dictionaries, in file order.
    pub(crate) trailers: Vec<Dictionary>,
    /// Whether a `trailer` keyword was found.
    pub(crate) has_trailer: bool,
    /// The last object whose dictionary is a `/Catalog` with `/Pages`.
    pub(crate) catalog: Option<ObjectId>,
    /// The last object read to its `endobj`.
    pub(crate) last_complete: Option<ObjectId>,
    /// Whether the last object header in the file starts an object that the file cuts off.
    pub(crate) ends_inside_object: bool,
    /// Streams whose declared `/Length` was wrong.
    pub(crate) lengths_corrected: u32,
    /// A linearized file's `/L`.
    pub(crate) linearized_length: Option<u64>,
}

/// Where the object header `n g obj` ending with the `obj` at `at` starts, if it is one.
fn header_start(data: &[u8], at: usize) -> Option<usize> {
    // `obj` must end at a token boundary.
    if data
        .get(at.checked_add(3)?)
        .is_some_and(|&byte| is_regular(byte))
    {
        return None;
    }
    let mut i = at;
    let skip_back = |i: &mut usize, digits: bool| -> usize {
        let mut count = 0usize;
        while let Some(previous) = i.checked_sub(1) {
            let byte = data.get(previous).copied().unwrap_or(b'x');
            let wanted = if digits {
                byte.is_ascii_digit()
            } else {
                is_whitespace(byte)
            };
            if !wanted {
                break;
            }
            *i = previous;
            count = count.saturating_add(1);
        }
        count
    };
    if skip_back(&mut i, false) == 0 || skip_back(&mut i, true) == 0 {
        return None;
    }
    if skip_back(&mut i, false) == 0 || skip_back(&mut i, true) == 0 {
        return None;
    }
    // The object number must start at a token boundary.
    match i.checked_sub(1).and_then(|previous| data.get(previous)) {
        Some(&byte) if is_regular(byte) => None,
        _ => Some(i),
    }
}

/// Scans `data`, which starts at the `%PDF-` header, for objects and trailers.
///
/// # Errors
///
/// [`CoreError::OutOfMemory`] only: objects that cannot be read are skipped.
pub(crate) fn scan(data: &[u8], limits: &Limits) -> Result<Scan, CoreError> {
    let mut scan = Scan::default();
    // Where each object's definition starts, for the order of trailers.
    let mut positioned: Vec<(usize, Dictionary)> = Vec::new();
    let mut pos = 0usize;
    let mut last_header = None;
    while let Some(at) = syntax::find(data, b"obj", pos) {
        pos = at.saturating_add(3);
        let Some(start) = header_start(data, at) else {
            continue;
        };
        last_header = Some(start);
        let indirect = match Parser::new(data, start, limits).indirect(&|_| None) {
            Ok(indirect) => indirect,
            Err(CoreError::OutOfMemory { context }) => {
                return Err(CoreError::OutOfMemory { context });
            }
            Err(_) => continue,
        };
        scan.headers = scan.headers.saturating_add(1);
        scan.objects.insert(indirect.id.0, (start, indirect.id.1));
        if indirect.complete {
            scan.last_complete = Some(indirect.id);
        }
        if indirect.length_corrected {
            scan.lengths_corrected = scan.lengths_corrected.saturating_add(1);
        }
        if let Object::Dictionary(dict) = &indirect.object {
            let is_type = |name: &[u8]| {
                dict.get(b"Type").ok().and_then(|kind| kind.as_name().ok()) == Some(name)
            };
            if is_type(b"Catalog") && dict.has(b"Pages") {
                scan.catalog = Some(indirect.id);
            }
            if is_type(b"ObjStm") && indirect.data.is_some() {
                scan.object_streams.insert(indirect.id.0);
            } else {
                scan.object_streams.remove(&indirect.id.0);
            }
            if is_type(b"XRef") && dict.has(b"Root") {
                positioned.push((start, dict.clone()));
            }
            if scan.headers == 1
                && dict.has(b"Linearized")
                && let Ok(length) = dict.get(b"L").and_then(Object::as_i64)
            {
                scan.linearized_length = u64::try_from(length).ok();
            }
        }
        pos = pos.max(indirect.end);
    }
    let mut pos = 0usize;
    while let Some(at) = syntax::find(data, b"trailer", pos) {
        pos = at.saturating_add(7);
        scan.has_trailer = true;
        if let Ok(Object::Dictionary(dict)) = Parser::new(data, pos, limits).object() {
            positioned.push((at, dict));
        }
    }
    positioned.sort_by_key(|(at, _)| *at);
    scan.trailers = positioned.into_iter().map(|(_, dict)| dict).collect();
    // The file is cut off when its last object header starts an object that does not end.
    scan.ends_inside_object = match (last_header, scan.last_complete) {
        (Some(start), Some(id)) => scan.objects.get(&id.0).is_none_or(|(at, _)| *at < start),
        (Some(_), None) => true,
        (None, _) => false,
    } || !ends_with_eof(data);
    Ok(scan)
}

/// Whether `%%EOF` is near the end of `data`.
fn ends_with_eof(data: &[u8]) -> bool {
    syntax::rfind(data, b"%%EOF", data.len())
        .is_some_and(|at| data.len().saturating_sub(at) <= 1024)
}

/// A cross-reference table rebuilt from `scan`, with the repairs made, or why it cannot be.
pub(crate) fn rebuild(
    scan: &Scan,
    data: &[u8],
    problem: XrefProblem,
) -> Result<(Xref, RepairReport), Diagnosis> {
    let found = |id: ObjectId| scan.objects.get(&id.0).is_some_and(|(_, g)| *g == id.1);
    let mut report = RepairReport::default();
    let mut trailer = Dictionary::new();
    // The last trailer whose /Root is among the objects.
    let chosen = scan.trailers.iter().rev().find(|dict| {
        dict.get(b"Root")
            .ok()
            .and_then(|root| root.as_reference().ok())
            .is_some_and(found)
    });
    match (chosen, scan.catalog) {
        (Some(dict), _) => {
            for key in [&b"Root"[..], b"Info", b"ID", b"Encrypt"] {
                if let Ok(value) = dict.get(key) {
                    trailer.set(key.to_vec(), value.clone());
                }
            }
        }
        (None, Some(catalog)) => {
            trailer.set("Root", Object::Reference(catalog));
            report.repairs.push(Repair::TrailerRebuilt);
        }
        (None, None) => {
            let likely_cause = if scan.headers == 0 {
                LikelyCause::NoObjects
            } else if scan.ends_inside_object {
                LikelyCause::Truncated
            } else {
                LikelyCause::NoCatalog
            };
            return Err(Diagnosis {
                likely_cause,
                file_size: u64::try_from(data.len()).unwrap_or(u64::MAX),
                expected_size: scan.linearized_length,
                last_complete_object: scan.last_complete,
                objects_found: u32::try_from(scan.objects.len()).unwrap_or(u32::MAX),
                has_trailer: scan.has_trailer,
            });
        }
    }
    let mut xref = Xref {
        entries: scan
            .objects
            .iter()
            .map(|(&number, &(offset, generation))| (number, Entry::Normal { offset, generation }))
            .collect(),
        trailer,
        sections: 0,
        size: 0,
    };
    xref.size = crate::xref::size_of(&xref);
    let objects = u32::try_from(scan.objects.len()).unwrap_or(u32::MAX);
    report
        .repairs
        .insert(0, Repair::CrossReferenceRebuilt { objects, problem });
    if scan.lengths_corrected > 0 {
        report.repairs.push(Repair::StreamLengthsCorrected {
            streams: scan.lengths_corrected,
        });
    }
    Ok((xref, report))
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;
    use crate::xref::tests::simple;

    #[test]
    fn headers_are_found_only_at_token_boundaries() {
        let data = b"12 0 obj x endobj 3 1 obj a3 0 obj 4 0 objx";
        let starts: Vec<usize> = [5usize, 14, 22, 31, 39]
            .iter()
            .filter_map(|&at| header_start(data, at))
            .collect();
        assert_eq!(starts, [0, 18]);
        assert_eq!(header_start(b"0 obj", 2), None);
    }

    #[test]
    fn early_offsets_are_rebuilt_from_the_objects() {
        let data = simple(|offset| offset - 2);
        let found = scan(&data, &Limits::default()).unwrap();
        assert_eq!(found.headers, 3);
        assert_eq!(found.catalog, Some((1, 0)));
        assert!(!found.ends_inside_object);
        let problem = XrefProblem::WrongOffset { object: 1 };
        let (xref, report) = rebuild(&found, &data, problem).unwrap();
        assert_eq!(xref.in_use().count(), 3);
        assert_eq!(xref.offset_of((1, 0)), Some(9));
        assert_eq!(
            report.repairs,
            [Repair::CrossReferenceRebuilt {
                objects: 3,
                problem
            }]
        );
        // The rebuilt table reads back clean through the flat copy.
        let flat = crate::xref::flatten(&data, &xref, &BTreeSet::new()).unwrap();
        let reread = crate::xref::read(&flat, &Limits::default())
            .unwrap()
            .unwrap();
        assert_eq!(reread.in_use().count(), 3);
    }

    #[test]
    fn a_missing_trailer_is_rebuilt_from_the_catalog() {
        let data = simple(|offset| offset);
        let cut = data
            .windows(7)
            .position(|window| window == b"xref\n0 ")
            .unwrap();
        let data = &data[..cut];
        let found = scan(data, &Limits::default()).unwrap();
        assert!(!found.has_trailer);
        let (xref, report) = rebuild(&found, data, XrefProblem::NoStartxref).unwrap();
        assert_eq!(
            xref.trailer.get(b"Root").unwrap().as_reference().unwrap(),
            (1, 0)
        );
        assert!(report.repairs.contains(&Repair::TrailerRebuilt));
    }

    #[test]
    fn a_file_cut_inside_an_object_is_truncated() {
        let mut data =
            b"%PDF-1.4\n1 0 obj\n<< /A 1 >>\nendobj\n2 0 obj\n<< /Length 900 >>\nstream\nabc"
                .to_vec();
        data.extend(std::iter::repeat_n(b'x', 50));
        let found = scan(&data, &Limits::default()).unwrap();
        let diagnosis = rebuild(&found, &data, XrefProblem::NoStartxref).unwrap_err();
        assert_eq!(diagnosis.likely_cause, LikelyCause::Truncated);
        assert_eq!(diagnosis.last_complete_object, Some((1, 0)));
        assert_eq!(diagnosis.objects_found, 1);
        assert!(!diagnosis.has_trailer);
        assert_eq!(diagnosis.file_size, data.len() as u64);
    }

    #[test]
    fn nothing_found_is_no_objects() {
        let data = b"%PDF-1.4\nnothing here\n%%EOF\n";
        let found = scan(data, &Limits::default()).unwrap();
        let diagnosis = rebuild(&found, data, XrefProblem::NoStartxref).unwrap_err();
        assert_eq!(diagnosis.likely_cause, LikelyCause::NoObjects);
        let data = b"%PDF-1.4\n1 0 obj\n<< /Type /Pages >>\nendobj\n%%EOF\n";
        let found = scan(data, &Limits::default()).unwrap();
        let diagnosis = rebuild(&found, data, XrefProblem::NoStartxref).unwrap_err();
        assert_eq!(diagnosis.likely_cause, LikelyCause::NoCatalog);
    }

    #[test]
    fn the_last_definition_of_an_object_wins() {
        let data = b"%PDF-1.4\n1 0 obj\n(old)\nendobj\n1 0 obj\n(new)\nendobj\n";
        let found = scan(data, &Limits::default()).unwrap();
        assert_eq!(found.headers, 2);
        assert_eq!(found.objects.get(&1), Some(&(30, 0)));
    }
}
