//! The incremental writer (ISO 32000-2 §7.5.6, docs/ARCHITECTURE.md §7.3, ADR 0008): the
//! revisions' objects appended to the original bytes as one update section, so the original
//! file stays an exact prefix of the new one.
//!
//! The section holds the newest version of every object the current revisions change, then a
//! cross-reference section in the form of the file's newest one: a classic table after a table,
//! a cross-reference stream after a stream, and a table that keeps the trailer's `/XRefStm` after
//! a hybrid file's. Its trailer has `/Prev` at the last `startxref`, `/Size` past every object,
//! the original `/Root`, `/Info` and `/Encrypt`, and `/ID` with the first string kept and a new
//! second one. In an encrypted document every written string and stream is encrypted with the
//! file key, AES with a random initialisation vector; the encryption dictionary, the
//! cross-reference stream, the `/ID` and a signature's `/Contents` never are. Saving the bytes
//! (temp file, verify, atomic replace) is the caller's.
// Offsets and sizes are checked (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::io::Write as _;

use lopdf::{Dictionary, Object, ObjectId, StringFormat};

use crate::appendix::{indirect, object, offset};
use crate::revision::RevisionStore;
use crate::security::{Random, system_random};
use crate::xref::XrefForm;
use crate::{CoreError, Document, WriteError, sniff};

impl RevisionStore {
    /// The bytes of `doc` with the current revision appended as an incremental update; the
    /// original bytes when no revision applies.
    ///
    /// # Errors
    ///
    /// [`WriteError::TransactionOpen`], [`WriteError::Repaired`] for a repaired document,
    /// [`WriteError::Random`], [`CoreError::Unsupported`] past the 4 GiB a cross-reference
    /// offset can address, and [`CoreError::OutOfMemory`].
    pub fn incremental_update(&self, doc: &Document) -> Result<Vec<u8>, CoreError> {
        self.write_update(doc, &mut system_random)
    }

    /// [`incremental_update`](Self::incremental_update) with the random bytes from `random`.
    pub(crate) fn write_update(
        &self,
        doc: &Document,
        random: &mut Random<'_>,
    ) -> Result<Vec<u8>, CoreError> {
        self.closed()?;
        if doc.repair().is_some() {
            return Err(CoreError::Write(WriteError::Repaired));
        }
        let original: &[u8] = doc.source().bytes();
        let objects = self.committed();
        let mut out = Vec::new();
        out.try_reserve(original.len().saturating_add(4096))
            .map_err(|_| CoreError::OutOfMemory {
                context: "an incremental update",
            })?;
        out.extend_from_slice(original);
        if objects.is_empty() {
            return Ok(out);
        }
        // Offsets count from the header.
        let header = sniff::header_offset(original).unwrap_or(0);
        let start = original.len().saturating_sub(header);
        let at = |out: &Vec<u8>| offset(start, out.len().saturating_sub(original.len()));
        let encryption = doc.decrypter();
        out.push(b'\n');
        let mut entries: Vec<(ObjectId, u32)> = Vec::new();
        for (id, value) in objects {
            if encryption.is_some_and(|(_, encrypt)| encrypt == Some(id)) {
                continue;
            }
            let mut value = value.clone();
            if let Some((decrypter, _)) = encryption {
                decrypter.encrypt_object(id, &mut value, random, doc.limits())?;
            }
            entries.push((id, at(&out)?));
            indirect(&mut out, id, &value);
        }

        let xref = doc.xref();
        let size = self.next_number();
        let mut trailer = Dictionary::new();
        trailer.set("Size", i64::from(size));
        trailer.set("Prev", i64::try_from(xref.start).unwrap_or(i64::MAX));
        for key in [&b"Root"[..], b"Info", b"Encrypt"] {
            if let Ok(value) = xref.trailer.get(key) {
                trailer.set(key.to_vec(), value.clone());
            }
        }
        if let Some(ids) = new_id(xref.trailer.get(b"ID").ok(), encryption.is_some(), random)? {
            trailer.set("ID", ids);
        }
        let form = xref.forms.first().copied().unwrap_or(XrefForm::Table);
        if form == XrefForm::Hybrid
            && let Ok(stream) = xref.trailer.get(b"XRefStm")
        {
            trailer.set("XRefStm", stream.clone());
        }
        let xref_at = at(&out)?;
        if form == XrefForm::Stream {
            // The stream lists itself, as the newest object.
            let own = (size, 0);
            entries.push((own, xref_at));
            let size = size.checked_add(1).ok_or(CoreError::Internal {
                context: "the cross-reference stream's object number",
            })?;
            trailer.set("Size", i64::from(size));
            let mut rows = Vec::new();
            let mut index = Vec::new();
            for run in runs(&entries) {
                index.push(Object::Integer(i64::from(run.0)));
                index.push(Object::Integer(i64::try_from(run.1.len()).unwrap_or(0)));
                for &((_, generation), position) in run.1 {
                    rows.push(1);
                    rows.extend(position.to_be_bytes());
                    rows.extend(generation.to_be_bytes());
                }
            }
            trailer.set("Type", "XRef");
            trailer.set("W", vec![1.into(), 4.into(), 2.into()]);
            trailer.set("Index", index);
            let stream = Object::Stream(lopdf::Stream::new(trailer, rows));
            indirect(&mut out, own, &stream);
        } else {
            out.extend_from_slice(b"xref\n");
            for (first, run) in runs(&entries) {
                let _ = writeln!(out, "{first} {}", run.len());
                for &((_, generation), position) in run {
                    let _ = write!(out, "{position:010} {generation:05} n\r\n");
                }
            }
            out.extend_from_slice(b"trailer\n");
            object(&mut out, &Object::Dictionary(trailer));
            out.push(b'\n');
        }
        let _ = write!(out, "startxref\n{xref_at}\n%%EOF\n");
        Ok(out)
    }
}

/// The update's `/ID`: the first string kept and a new random second one. A file without one
/// gets two new strings, unless it is encrypted: its key was derived from the missing `/ID`.
fn new_id(
    old: Option<&Object>,
    encrypted: bool,
    random: &mut Random<'_>,
) -> Result<Option<Object>, CoreError> {
    let first = old
        .and_then(|ids| ids.as_array().ok())
        .and_then(|ids| ids.first())
        .and_then(|id| id.as_str().ok())
        .map(<[u8]>::to_vec);
    let mut second = vec![0u8; 16];
    random(&mut second)?;
    let first = match first {
        Some(first) => first,
        None if encrypted => return Ok(None),
        None => {
            let mut first = vec![0u8; 16];
            random(&mut first)?;
            first
        }
    };
    let hex = |bytes| Object::String(bytes, StringFormat::Hexadecimal);
    Ok(Some(Object::Array(vec![hex(first), hex(second)])))
}

/// `entries`, which are in object order, as runs of consecutive object numbers with the first
/// number.
fn runs(entries: &[(ObjectId, u32)]) -> Vec<(u32, &[(ObjectId, u32)])> {
    let mut out = Vec::new();
    let mut from = 0;
    while let Some(&((first, _), _)) = entries.get(from) {
        let mut end = from.saturating_add(1);
        while let (Some(((previous, _), _)), Some(((number, _), _))) =
            (entries.get(end.saturating_sub(1)), entries.get(end))
        {
            if previous.checked_add(1) != Some(*number) {
                break;
            }
            end = end.saturating_add(1);
        }
        out.push((first, entries.get(from..end).unwrap_or_default()));
        from = end;
    }
    out
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::fmt::Write as _;
    use std::sync::Arc;

    use super::*;
    use crate::limits::Limits;
    use crate::xref::{self, tests::simple};
    use crate::{OpenOptions, Password, Source, open};

    fn document(bytes: &[u8], password: Option<&str>) -> Document {
        let options = OpenOptions {
            password: password.map(|password| Password::new(password.to_owned())),
            ..OpenOptions::default()
        };
        open(&Source::from_bytes(Arc::from(bytes)), &options).unwrap()
    }

    /// Fixed bytes instead of random ones.
    fn fixed(out: &mut [u8]) -> Result<(), CoreError> {
        out.fill(0x5A);
        Ok(())
    }

    /// `doc` with page 0 turned by 90 degrees, a new string on it and a new object, written with
    /// fixed random bytes.
    fn turned(doc: &Document) -> Vec<u8> {
        let mut store = RevisionStore::new(doc);
        store.begin().unwrap();
        let page = doc.structure().pages[0].id;
        let mut dict = doc.model().get_dictionary(page).unwrap().clone();
        dict.set("Rotate", 90);
        dict.set("PieceInfo", Object::string_literal("Ferman"));
        store.put(page, Object::Dictionary(dict)).unwrap();
        store.add(Object::Integer(7)).unwrap();
        store.commit().unwrap();
        store.write_update(doc, &mut fixed).unwrap()
    }

    /// Objects 1 to 3 as [`simple`] writes them, then a cross-reference stream as object 4,
    /// alone or, with `hybrid`, named by a table's `/XRefStm`.
    fn with_stream(hybrid: bool) -> Vec<u8> {
        let base = simple(|offset| offset);
        let end = base.windows(4).position(|w| w == b"xref").unwrap();
        let mut out = base[..end].to_vec();
        let find = |out: &[u8], needle: &str| {
            out.windows(needle.len())
                .position(|w| w == needle.as_bytes())
                .unwrap() as u32
        };
        let offsets: Vec<u32> = (1..=3).map(|n| find(&out, &format!("{n} 0 obj"))).collect();
        let stream_at = out.len() as u32;
        let mut rows = vec![0u8, 0, 0, 0, 0, 0xFF, 0xFF];
        // A hybrid file's hidden stream lists the objects only (lopdf reads no more).
        let own = (!hybrid).then_some(stream_at);
        for at in offsets.iter().copied().chain(own) {
            rows.push(1);
            rows.extend(at.to_be_bytes());
            rows.extend([0, 0]);
        }
        let mut text = format!(
            "4 0 obj\n<< /Type /XRef /Size {} /W [1 4 2] /Root 1 0 R /Length {} >>\nstream\n",
            rows.len() / 7,
            rows.len()
        );
        out.extend(text.as_bytes());
        out.extend(&rows);
        out.extend(b"\nendstream\nendobj\n");
        if hybrid {
            let table = out.len();
            text = String::from("xref\n0 4\n0000000000 65535 f\r\n");
            for at in &offsets {
                let _ = write!(text, "{at:010} 00000 n\r\n");
            }
            let _ = write!(
                text,
                "trailer\n<< /Size 5 /Root 1 0 R /XRefStm {stream_at} >>\nstartxref\n{table}\n%%EOF\n"
            );
        } else {
            text = format!("startxref\n{stream_at}\n%%EOF\n");
        }
        out.extend(text.as_bytes());
        out
    }

    fn check_update(original: &[u8], expected: &[XrefForm]) {
        let doc = document(original, None);
        let saved = turned(&doc);
        assert_eq!(&saved[..original.len()], original);
        let xref = xref::read(&saved, &Limits::default()).unwrap().unwrap();
        assert_eq!(xref.forms, expected);
        let old = xref::read(original, &Limits::default()).unwrap().unwrap();
        assert_eq!(
            xref.trailer.get(b"Prev").unwrap().as_i64().unwrap(),
            old.start as i64
        );
        let added = (old.size, 0);
        let stream = u32::from(expected[0] == XrefForm::Stream);
        assert_eq!(xref.size, old.size + 1 + stream);
        let reopened = document(&saved, None);
        assert!(reopened.repair().is_none());
        let page = reopened.structure().pages[0].id;
        let dict = reopened.model().get_dictionary(page).unwrap();
        assert_eq!(dict.get(b"Rotate").unwrap().as_i64().unwrap(), 90);
        assert_eq!(
            reopened.model().get_object(added).unwrap(),
            &Object::Integer(7)
        );
        // Every other object reads back as it was.
        for (id, object) in &doc.model().objects {
            if *id != page {
                assert_eq!(reopened.model().get_object(*id).unwrap(), object, "{id:?}");
            }
        }
        // A file without an /ID gets a new one.
        let ids = xref.trailer.get(b"ID").unwrap().as_array().unwrap();
        assert_eq!(ids[1].as_str().unwrap(), &[0x5A; 16]);
    }

    #[test]
    fn an_update_keeps_the_form_of_the_newest_section() {
        check_update(
            &simple(|offset| offset),
            &[XrefForm::Table, XrefForm::Table],
        );
        check_update(&with_stream(false), &[XrefForm::Stream, XrefForm::Stream]);
        check_update(&with_stream(true), &[XrefForm::Hybrid, XrefForm::Hybrid]);
    }

    #[test]
    fn a_hybrid_update_keeps_the_xrefstm() {
        let original = with_stream(true);
        let saved = turned(&document(&original, None));
        let tail = String::from_utf8_lossy(&saved[original.len()..]).into_owned();
        let at = String::from_utf8_lossy(&original).find("4 0 obj").unwrap();
        assert!(tail.contains(&format!("/XRefStm {at} ")), "{tail}");
        assert!(tail.contains("xref\n3 1\n"), "{tail}");
    }

    #[test]
    fn nothing_committed_writes_the_original_and_open_or_repaired_documents_fail() {
        let original = simple(|offset| offset);
        let doc = document(&original, None);
        let mut store = RevisionStore::new(&doc);
        assert_eq!(store.incremental_update(&doc).unwrap(), original);
        store.begin().unwrap();
        assert!(matches!(
            store.incremental_update(&doc),
            Err(CoreError::Write(WriteError::TransactionOpen))
        ));
        let repaired = document(&simple(|offset| offset - 2), None);
        assert!(matches!(
            RevisionStore::new(&repaired).incremental_update(&repaired),
            Err(CoreError::Write(WriteError::Repaired))
        ));
    }

    #[test]
    fn revisions_stack_undo_and_redo() {
        let doc = document(&simple(|offset| offset), None);
        let mut store = RevisionStore::new(&doc);
        assert!(matches!(
            store.undo(),
            Err(CoreError::Write(WriteError::NothingToUndo))
        ));
        assert!(matches!(
            store.commit(),
            Err(CoreError::Write(WriteError::NoTransaction))
        ));
        let page = (3, 0);
        for rotate in [90, 180] {
            store.begin().unwrap();
            let mut dict = doc.model().get_dictionary(page).unwrap().clone();
            dict.set("Rotate", rotate);
            store.put(page, Object::Dictionary(dict)).unwrap();
            store.commit().unwrap();
        }
        let rotate = |store: &RevisionStore| {
            store.lookup(page).map(|page| {
                page.as_dict()
                    .unwrap()
                    .get(b"Rotate")
                    .unwrap()
                    .as_i64()
                    .unwrap()
            })
        };
        assert_eq!(rotate(&store), Some(180));
        assert_eq!(store.undo().unwrap(), 1);
        assert_eq!(rotate(&store), Some(90));
        assert_eq!(store.undo().unwrap(), 0);
        assert_eq!(rotate(&store), None);
        assert_eq!(store.redo().unwrap(), 1);
        assert_eq!(rotate(&store), Some(90));
        // A new object takes the first free number; a commit drops the redo branch.
        store.begin().unwrap();
        assert_eq!(store.add(Object::Null).unwrap(), (4, 0));
        assert!(matches!(
            store.begin(),
            Err(CoreError::Write(WriteError::TransactionOpen))
        ));
        store.rollback();
        store.begin().unwrap();
        assert_eq!(
            store.commit().unwrap(),
            1,
            "an empty transaction adds no revision"
        );
        assert_eq!(store.revisions().len(), 2);
        store.begin().unwrap();
        store.add(Object::Null).unwrap();
        assert_eq!(store.commit().unwrap(), 2);
        assert_eq!(store.revisions().len(), 2);
        assert!(matches!(
            store.redo(),
            Err(CoreError::Write(WriteError::NothingToRedo))
        ));
        assert_eq!(rotate(&store), Some(90));
    }

    #[test]
    fn an_encrypted_update_uses_the_file_key_and_is_reproducible_with_fixed_ivs() {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated/payslip-aes256.pdf");
        let original = std::fs::read(path).unwrap();
        let doc = document(&original, Some("Eylül2026maaşı"));
        let saved = turned(&doc);
        assert_eq!(saved, turned(&doc));
        let tail = &saved[original.len()..];
        // The page's new string is not in the file as it stands, nor in hex.
        assert!(!tail.windows(6).any(|w| w == b"Ferman"));
        assert!(!tail.windows(12).any(|w| w == b"4665726D616E"));
        // The /ID's first string is kept, so the key is the same.
        let ids = |bytes: &[u8]| {
            xref::read(bytes, &Limits::default())
                .unwrap()
                .unwrap()
                .trailer
                .get(b"ID")
                .unwrap()
                .clone()
        };
        let (old, new) = (ids(&original), ids(&saved));
        assert_eq!(old.as_array().unwrap()[0], new.as_array().unwrap()[0]);
        let reopened = document(&saved, Some("Eylül2026maaşı"));
        let page = reopened.structure().pages[0].id;
        let dict = reopened.model().get_dictionary(page).unwrap();
        assert_eq!(dict.get(b"PieceInfo").unwrap().as_str().unwrap(), b"Ferman");
        assert_eq!(
            reopened.structure().info.title.as_deref(),
            Some("Maaş bordrosu Eylül 2026")
        );
    }
}
