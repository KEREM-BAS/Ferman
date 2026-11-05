//! The full rewrite (docs/ARCHITECTURE.md §7.3, ADR 0008): Optimize and clean, and the copy of a
//! repaired document, whose rebuilt cross-reference data cannot be extended.
//!
//! The new file holds the objects reached from the trailer's `/Root` and `/Info` in
//! their newest version, numbered again from 1 in the order they are reached, with generation 0;
//! everything else goes: earlier revisions, unreferenced objects, object and cross-reference
//! streams (their objects are written on their own), a linearization dictionary. A reference to
//! an object that does not exist becomes `null`, which is what it reads as. Streams without a
//! filter are compressed with Flate (but XMP metadata, which stays readable); filtered streams keep
//! their data. One classic cross-reference table ends the file. An encrypted document stays
//! encrypted with its own key and ciphers, its encryption dictionary written last as the file has
//! it: every string and stream is encrypted again for its
//! new object number, AES with a random initialisation vector, and `/ID` keeps its first string,
//! from which the key was derived. Signatures do not survive a rewrite, which is why the UI warns
//! first. Duplicate streams are not merged.
//!
//! [`RevisionStore::without_signatures`] is the same rewrite for the working copy of a signed
//! document (a3-16a, G35): the signature fields stay, empty, and nothing in the copy claims a
//! signature, so editing it asks nothing. The signed original is not touched.
// Offsets and sizes are checked (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::io::Write as _;

use flate2::Compression;
use flate2::write::ZlibEncoder;
use lopdf::{Dictionary, Object, ObjectId, Stream};

use crate::appendix::{indirect, object, offset};
use crate::incremental::new_id;
use crate::limits::{LimitKind, Limits};
use crate::revision::RevisionStore;
use crate::security::{Random, system_random};
use crate::structure::Scope;
use crate::{CoreError, Document, WriteError};

impl RevisionStore {
    /// `doc` with the current revision written as a new file: only the live objects, numbered
    /// again, streams compressed, encrypted with the document's key when it is encrypted.
    ///
    /// # Errors
    ///
    /// [`WriteError::TransactionOpen`], [`WriteError::Random`], [`CoreError::ResourceLimit`]
    /// past the nesting limit, [`CoreError::Internal`] for a trailer without `/Root`,
    /// [`CoreError::Unsupported`] past the 4 GiB a cross-reference offset can address, and
    /// [`CoreError::OutOfMemory`].
    pub fn full_rewrite(&self, doc: &Document) -> Result<Vec<u8>, CoreError> {
        self.write_full(doc, &mut system_random)
    }

    /// `doc` with the current revision written as [`full_rewrite`](Self::full_rewrite) does,
    /// unsigned: every signature field loses its value and its widgets' appearance (which draws
    /// the signature), and the catalog its `/Perms` and `/DSS` and the form its `/SigFlags`.
    ///
    /// # Errors
    ///
    /// As [`full_rewrite`](Self::full_rewrite).
    pub fn without_signatures(&self, doc: &Document) -> Result<Vec<u8>, CoreError> {
        let mut unsigned = self.clone();
        unsigned.begin()?;
        for (id, object) in unsigned_objects(&self.scope(doc), doc) {
            unsigned.put(id, object)?;
        }
        unsigned.commit()?;
        unsigned.full_rewrite(doc)
    }

    /// [`full_rewrite`](Self::full_rewrite) with the random bytes from `random`.
    pub(crate) fn write_full(
        &self,
        doc: &Document,
        random: &mut Random<'_>,
    ) -> Result<Vec<u8>, CoreError> {
        self.closed()?;
        let limits = doc.limits();
        let committed = self.committed();
        let get = |id: ObjectId| {
            committed
                .get(&id)
                .copied()
                .or_else(|| doc.model().objects.get(&id))
        };
        let trailer = &doc.xref().trailer;
        if !matches!(trailer.get(b"Root"), Ok(Object::Reference(_))) {
            return Err(CoreError::Internal {
                context: "a full rewrite of a document without /Root",
            });
        }
        let encryption = doc.decrypter();
        let encrypt_id = encryption.and_then(|(_, id)| id);

        // Every live object, numbered in the order it is reached.
        let mut numbers: BTreeMap<ObjectId, u32> = BTreeMap::new();
        let mut order: Vec<ObjectId> = Vec::new();
        let mut queue = VecDeque::new();
        for key in [&b"Root"[..], b"Info"] {
            if let Ok(Object::Reference(id)) = trailer.get(key) {
                queue.push_back(*id);
            }
        }
        while let Some(id) = queue.pop_front() {
            // The encryption dictionary is written last, never encrypted.
            if numbers.contains_key(&id) || Some(id) == encrypt_id {
                continue;
            }
            let Some(value) = get(id) else {
                continue;
            };
            let number = u32::try_from(order.len())
                .ok()
                .and_then(|count| count.checked_add(1))
                .ok_or(CoreError::Write(WriteError::ObjectNumbers))?;
            numbers.insert(id, number);
            order.push(id);
            references(value, &mut queue, 0, limits)?;
        }

        let mut out = Vec::new();
        out.try_reserve(doc.source().len().saturating_add(4096))
            .map_err(|_| CoreError::OutOfMemory {
                context: "a full rewrite",
            })?;
        let _ = write!(out, "%PDF-{}\n%\u{e2}\u{e3}\u{cf}\u{d3}\n", doc.version());
        let mut offsets = Vec::with_capacity(order.len());
        for (old, number) in order.iter().zip(1u32..) {
            let Some(value) = get(*old) else {
                continue;
            };
            let mut value = value.clone();
            renumber(&mut value, &numbers, 0, limits)?;
            let id = (number, 0);
            if let Object::Stream(stream) = &mut value {
                compress(stream)?;
            }
            if let Some((decrypter, _)) = encryption {
                decrypter.encrypt_object(id, &mut value, random, limits)?;
            }
            offsets.push(offset(0, out.len())?);
            indirect(&mut out, id, &value);
        }
        // The encryption dictionary last, as the file has it.
        let mut encrypt = None;
        if let Some(dict) = doc.encryption_dictionary() {
            let number = u32::try_from(offsets.len())
                .ok()
                .and_then(|count| count.checked_add(1))
                .ok_or(CoreError::Write(WriteError::ObjectNumbers))?;
            offsets.push(offset(0, out.len())?);
            indirect(&mut out, (number, 0), &Object::Dictionary(dict.clone()));
            encrypt = Some(Object::Reference((number, 0)));
        }

        let size = u32::try_from(offsets.len())
            .ok()
            .and_then(|count| count.checked_add(1))
            .ok_or(CoreError::Write(WriteError::ObjectNumbers))?;
        let xref_at = offset(0, out.len())?;
        let _ = write!(out, "xref\n0 {size}\n0000000000 65535 f\r\n");
        for position in offsets {
            let _ = write!(out, "{position:010} 00000 n\r\n");
        }
        let mut new_trailer = lopdf::Dictionary::new();
        new_trailer.set("Size", i64::from(size));
        for key in [&b"Root"[..], b"Info"] {
            if let Ok(value) = trailer.get(key) {
                let mut value = value.clone();
                renumber(&mut value, &numbers, 0, limits)?;
                if value != Object::Null {
                    new_trailer.set(key.to_vec(), value);
                }
            }
        }
        if let Some(encrypt) = encrypt {
            new_trailer.set("Encrypt", encrypt);
        }
        if let Some(ids) = new_id(trailer.get(b"ID").ok(), encryption.is_some(), random)? {
            new_trailer.set("ID", ids);
        }
        out.extend_from_slice(b"trailer\n");
        object(&mut out, &Object::Dictionary(new_trailer));
        let _ = write!(out, "\nstartxref\n{xref_at}\n%%EOF\n");
        Ok(out)
    }
}

/// The objects that change when `doc`'s signatures go: the catalog, the form and every signature
/// field and widget reached from `/Fields`, whose entries the specification makes references.
fn unsigned_objects(scope: &Scope<'_>, doc: &Document) -> BTreeMap<ObjectId, Object> {
    let mut changes = BTreeMap::new();
    let Ok(Object::Reference(root)) = doc.xref().trailer.get(b"Root") else {
        return changes;
    };
    let Some(mut catalog) = scope
        .object(*root)
        .and_then(|catalog| scope.dict(catalog))
        .cloned()
    else {
        return changes;
    };
    let _ = catalog.remove(b"Perms");
    let _ = catalog.remove(b"DSS");
    if let Some(mut form) = scope.get_dict(&catalog, b"AcroForm").cloned() {
        let mut stack: Vec<(ObjectId, Option<&[u8]>)> = references_in(scope, &form, b"Fields")
            .into_iter()
            .map(|field| (field, None))
            .collect();
        let mut seen = BTreeSet::new();
        while let Some((id, parent)) = stack.pop() {
            if !seen.insert(id) {
                continue;
            }
            let Some(field) = scope.object(id).and_then(|field| scope.dict(field)) else {
                continue;
            };
            let kind = scope.get_name(field, b"FT").or(parent);
            stack.extend(
                references_in(scope, field, b"Kids")
                    .into_iter()
                    .map(|kid| (kid, kind)),
            );
            if kind == Some(b"Sig") {
                let mut field = field.clone();
                let _ = field.remove(b"V");
                let _ = field.remove(b"AP");
                changes.insert(id, Object::Dictionary(field));
            }
        }
        let _ = form.remove(b"SigFlags");
        match catalog.get(b"AcroForm") {
            Ok(Object::Reference(id)) => {
                changes.insert(*id, Object::Dictionary(form));
            }
            _ => catalog.set("AcroForm", form),
        }
    }
    changes.insert(*root, Object::Dictionary(catalog));
    changes
}

/// The references in the array `dict[key]`.
fn references_in(scope: &Scope<'_>, dict: &Dictionary, key: &[u8]) -> Vec<ObjectId> {
    scope
        .get_array(dict, key)
        .into_iter()
        .flatten()
        .filter_map(|entry| entry.as_reference().ok())
        .collect()
}

/// Queues the objects `value` refers to; a stream's `/Length` is written direct, so its object
/// is not needed.
fn references(
    value: &Object,
    queue: &mut VecDeque<ObjectId>,
    depth: u32,
    limits: &Limits,
) -> Result<(), CoreError> {
    let deeper = deeper(depth, limits)?;
    match value {
        Object::Reference(id) => queue.push_back(*id),
        Object::Array(items) => {
            for item in items {
                references(item, queue, deeper, limits)?;
            }
        }
        Object::Dictionary(dict) => {
            for (_, item) in dict {
                references(item, queue, deeper, limits)?;
            }
        }
        Object::Stream(stream) => {
            for (key, item) in &stream.dict {
                if key.as_slice() != b"Length" {
                    references(item, queue, deeper, limits)?;
                }
            }
        }
        _ => {}
    }
    Ok(())
}

/// Replaces every reference in `value` with its new number, or `null` for an object that is not
/// written.
fn renumber(
    value: &mut Object,
    numbers: &BTreeMap<ObjectId, u32>,
    depth: u32,
    limits: &Limits,
) -> Result<(), CoreError> {
    let deeper = deeper(depth, limits)?;
    match value {
        Object::Reference(id) => {
            *value = numbers
                .get(id)
                .map_or(Object::Null, |&number| Object::Reference((number, 0)));
        }
        Object::Array(items) => {
            for item in items {
                renumber(item, numbers, deeper, limits)?;
            }
        }
        Object::Dictionary(dict) => {
            for (_, item) in dict.iter_mut() {
                renumber(item, numbers, deeper, limits)?;
            }
        }
        Object::Stream(stream) => {
            stream.dict.remove(b"Length");
            for (_, item) in stream.dict.iter_mut() {
                renumber(item, numbers, deeper, limits)?;
            }
        }
        _ => {}
    }
    Ok(())
}

fn deeper(depth: u32, limits: &Limits) -> Result<u32, CoreError> {
    if depth > limits.max_nesting {
        return Err(CoreError::ResourceLimit {
            limit: LimitKind::Nesting,
            max: u64::from(limits.max_nesting),
        });
    }
    Ok(depth.saturating_add(1))
}

/// Compresses a stream without a filter with Flate; XMP metadata stays readable.
fn compress(stream: &mut Stream) -> Result<(), CoreError> {
    let kind = stream.dict.get(b"Type").and_then(Object::as_name).ok();
    if stream.dict.has(b"Filter") || kind == Some(b"Metadata") || stream.content.is_empty() {
        return Ok(());
    }
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder
        .write_all(&stream.content)
        .and_then(|()| encoder.finish())
        .map(|data| {
            stream.dict.set("Filter", "FlateDecode");
            stream.dict.remove(b"DecodeParms");
            stream.set_content(data);
        })
        .map_err(|_| CoreError::OutOfMemory {
            context: "a compressed stream",
        })
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::path::PathBuf;

    use super::*;
    use crate::{OpenOptions, Password, Source, open};

    fn corpus(name: &str) -> Vec<u8> {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(format!("{name}.pdf"));
        std::fs::read(path).unwrap()
    }

    fn opened(bytes: Vec<u8>, password: Option<&str>) -> Document {
        let options = OpenOptions {
            password: password.map(|p| Password::new(p.to_owned())),
            ..OpenOptions::default()
        };
        open(&Source::from_bytes(bytes.into()), &options).unwrap()
    }

    fn fixed(out: &mut [u8]) -> Result<(), CoreError> {
        out.fill(7);
        Ok(())
    }

    #[test]
    fn a_rewrite_keeps_the_pages_and_drops_unreferenced_objects() {
        let original = corpus("kira-tr");
        let doc = opened(original.clone(), None);
        let store = RevisionStore::new(&doc);
        let rewritten = store.write_full(&doc, &mut fixed).unwrap();
        assert_eq!(rewritten, store.write_full(&doc, &mut fixed).unwrap());
        assert!(rewritten.starts_with(b"%PDF-"));
        let again = opened(rewritten, None);
        assert!(
            again.repair().is_none(),
            "the new table reads without repair"
        );
        assert_eq!(again.page_count(), doc.page_count());
        assert!(again.model().objects.len() <= doc.model().objects.len());
        let numbers: Vec<u32> = again.model().objects.keys().map(|id| id.0).collect();
        assert_eq!(numbers, (1..=numbers.len() as u32).collect::<Vec<_>>());
        assert!(again.model().objects.keys().all(|id| id.1 == 0));
    }

    #[test]
    fn a_copy_without_signatures_keeps_its_empty_fields() {
        let doc = opened(corpus("kira-tr-signed"), None);
        assert!(doc.structure().signed());
        let fields = doc.structure().signatures.len();
        let copy = RevisionStore::new(&doc).without_signatures(&doc).unwrap();
        assert!(!copy.windows(10).any(|window| window == b"/ByteRange"));
        let again = opened(copy, None);
        assert!(!again.structure().signed());
        assert_eq!(again.structure().signatures.len(), fields);
        assert_eq!(again.page_count(), doc.page_count());
        // A document without signatures reads the same.
        let plain = opened(corpus("kira-tr"), None);
        assert!(!plain.structure().signed(), "empty fields are not signed");
        let copy = RevisionStore::new(&plain)
            .without_signatures(&plain)
            .unwrap();
        assert_eq!(
            opened(copy, None).structure().signatures,
            plain.structure().signatures
        );
    }

    #[test]
    fn an_encrypted_document_stays_encrypted_with_its_key() {
        for (name, password) in [
            ("payslip-aes256", "Eylül2026maaşı"),
            ("payslip-aes128", "bordro2026"),
        ] {
            let doc = opened(corpus(name), Some(password));
            let store = RevisionStore::new(&doc);
            for rewritten in [
                store.full_rewrite(&doc).unwrap(),
                store.without_signatures(&doc).unwrap(),
            ] {
                let again = opened(rewritten.clone(), Some(password));
                assert!(again.encryption().is_some(), "{name}");
                assert_eq!(again.page_count(), doc.page_count());
                let without = open(
                    &Source::from_bytes(rewritten.into()),
                    &OpenOptions::default(),
                );
                assert!(
                    matches!(without, Err(CoreError::PasswordRequired)),
                    "{name} still needs its password"
                );
            }
        }
    }

    #[test]
    fn a_repaired_document_is_written_whole() {
        let doc = opened(corpus("kira-tr-damaged"), None);
        assert!(doc.repair().is_some());
        let rewritten = RevisionStore::new(&doc).full_rewrite(&doc).unwrap();
        let again = opened(rewritten, None);
        assert!(again.repair().is_none());
        assert_eq!(again.page_count(), doc.page_count());
    }
}
