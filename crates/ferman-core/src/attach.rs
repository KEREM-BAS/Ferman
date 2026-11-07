//! Attaching files (a2-3b, M4 plan W6): an embedded file added to the `/EmbeddedFiles` name tree,
//! or taken out of it. Its bytes are stored as they are given, so they come back byte for byte; a
//! file attachment annotation is a comment and goes with the comments.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use lopdf::{Dictionary, Object, StringFormat};

use crate::assemble::merge_names;
use crate::revision::{RevisionStore, compressed};
use crate::structure::navigation::name_tree;
use crate::{CoreError, Document, WriteError, text_string};

/// A file to attach.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewAttachment {
    /// Its file name.
    pub name: String,
    /// Its bytes.
    pub data: Vec<u8>,
    /// Its media type, such as `text/csv`.
    pub media_type: Option<String>,
    /// When it was last changed, as a PDF date string (`D:…`).
    pub modified: Option<String>,
}

impl RevisionStore {
    /// Embeds `file` in the open transaction, under its name, or a numbered one when that is
    /// taken.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::ObjectNumbers`], and
    /// [`CoreError::ResourceLimit`] past the decoded size per revision.
    pub fn attach_file(&mut self, doc: &Document, file: NewAttachment) -> Result<(), CoreError> {
        self.transaction_open()?;
        let max = doc.limits().max_revision_decoded;
        if u64::try_from(file.data.len()).unwrap_or(u64::MAX) > max {
            return Err(CoreError::ResourceLimit {
                limit: crate::limits::LimitKind::RevisionDecodedSize,
                max,
            });
        }
        let (root, mut catalog) = self.catalog(doc)?;
        let mut params = Dictionary::new();
        params.set("Size", i64::try_from(file.data.len()).unwrap_or(i64::MAX));
        if let Some(modified) = file.modified {
            params.set("ModDate", Object::string_literal(modified));
        }
        let mut dict = Dictionary::new();
        dict.set("Type", "EmbeddedFile");
        if let Some(media_type) = file.media_type {
            dict.set("Subtype", Object::Name(media_type.into_bytes()));
        }
        dict.set("Params", params);
        let stream = self.allocate()?.0;
        self.put_counted(
            doc,
            vec![(stream, Object::Stream(compressed(dict, &file.data)?))],
        )?;
        let name = text_string::encode(&file.name);
        // /F for readers before PDF 1.7: the name in PDFDocEncoding, `_` where it has no byte.
        let ascii: Vec<u8> = file
            .name
            .chars()
            .map(|c| text_string::pdf_doc_byte(c).unwrap_or(b'_'))
            .collect();
        let mut embedded = Dictionary::new();
        embedded.set("F", stream);
        embedded.set("UF", stream);
        let mut spec = Dictionary::new();
        spec.set("Type", "Filespec");
        spec.set("F", Object::String(ascii, StringFormat::Literal));
        spec.set("UF", Object::String(name.clone(), StringFormat::Literal));
        spec.set("EF", embedded);
        let spec_id = self.allocate()?.0;
        self.put(spec_id, Object::Dictionary(spec))?;
        merge_names(
            doc,
            self,
            &mut catalog,
            b"EmbeddedFiles",
            vec![(name, Object::Reference(spec_id))],
        );
        self.put(root, Object::Dictionary(catalog))
    }

    /// Takes [`attachments`](Self::attachments)`[index]` out of the `/EmbeddedFiles` tree in the
    /// open transaction; its bytes stay in the earlier revision until a rewrite (question 5).
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], and [`WriteError::StructurePlan`] for an index past the
    /// attachments or a file attachment annotation's.
    pub fn remove_attachment(&mut self, doc: &Document, index: usize) -> Result<(), CoreError> {
        self.transaction_open()?;
        let key = self
            .attachments(doc)
            .get(index)
            .and_then(|attachment| attachment.key.clone())
            .ok_or(CoreError::Write(WriteError::StructurePlan))?;
        let (root, mut catalog) = self.catalog(doc)?;
        let kept: Vec<Object> = {
            let scope = self.scope(doc);
            let names = scope
                .get_dict(&catalog, b"Names")
                .cloned()
                .unwrap_or_default();
            scope
                .get_dict(&names, b"EmbeddedFiles")
                .map(|tree| name_tree(&scope, tree))
                .unwrap_or_default()
                .into_iter()
                .filter(|(name, _)| *name != key.as_slice())
                .flat_map(|(name, value)| {
                    [
                        Object::String(name.to_vec(), StringFormat::Literal),
                        value.clone(),
                    ]
                })
                .collect()
        };
        let mut names = {
            let scope = self.scope(doc);
            scope
                .get_dict(&catalog, b"Names")
                .cloned()
                .unwrap_or_default()
        };
        if kept.is_empty() {
            names.remove(b"EmbeddedFiles");
        } else {
            let mut leaf = Dictionary::new();
            leaf.set("Names", kept);
            names.set("EmbeddedFiles", leaf);
        }
        catalog.set("Names", names);
        self.put(root, Object::Dictionary(catalog))
    }

    /// The catalog's object and its dictionary as these revisions leave it.
    pub(crate) fn catalog(
        &self,
        doc: &Document,
    ) -> Result<(lopdf::ObjectId, Dictionary), CoreError> {
        let root = doc
            .model()
            .trailer
            .get(b"Root")
            .and_then(Object::as_reference)
            .map_err(|_| CoreError::Internal {
                context: "a document without /Root",
            })?;
        Ok((root, self.dictionary(doc, root)?))
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::dictionary;

    use super::NewAttachment;
    use crate::revision::RevisionStore;
    use crate::{CoreError, Document, OpenOptions, Source, WriteError, open};

    fn plain() -> Document {
        let doc = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let mut bytes = Vec::new();
        doc.clone().save_to(&mut bytes).unwrap();
        open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap()
    }

    fn file(name: &str, data: &[u8]) -> NewAttachment {
        NewAttachment {
            name: name.to_owned(),
            data: data.to_vec(),
            media_type: Some("text/csv".to_owned()),
            modified: Some("D:20261107120000Z".to_owned()),
        }
    }

    #[test]
    fn a_file_round_trips_byte_for_byte_and_goes_again() {
        let doc = plain();
        let data: Vec<u8> = (0..=255u8).cycle().take(5000).collect();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        store.attach_file(&doc, file("bütçe.csv", &data)).unwrap();
        store
            .attach_file(&doc, file("bütçe.csv", b"a,b\n"))
            .unwrap();
        store.commit().unwrap();
        let bytes = store.incremental_update(&doc).unwrap();
        assert!(bytes.starts_with(doc.source().bytes()));
        let again = open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap();
        let list = &again.structure().attachments;
        assert_eq!(list.len(), 2);
        // The second took the free key "bütçe (2).csv", which sorts first; its name stays its own.
        assert_eq!(list[0].name, "bütçe.csv");
        assert_eq!(list[1].name, "bütçe.csv");
        assert_eq!(list[1].size, Some(5000));
        assert_eq!(list[1].media_type.as_deref(), Some("text/csv"));
        assert_eq!(list[1].modified.map(|date| date.day), Some(7));
        let fresh = RevisionStore::new(&again);
        assert_eq!(fresh.attachment_data(&again, 1).unwrap(), data);
        assert_eq!(fresh.attachment_data(&again, 0).unwrap(), b"a,b\n");

        store.begin().unwrap();
        store.remove_attachment(&doc, 0).unwrap();
        store.commit().unwrap();
        assert_eq!(store.attachments(&doc).len(), 1);
        assert_eq!(store.attachment_data(&doc, 0).unwrap(), data);
        store.begin().unwrap();
        store.remove_attachment(&doc, 0).unwrap();
        assert!(matches!(
            store.remove_attachment(&doc, 0),
            Err(CoreError::Write(WriteError::StructurePlan))
        ));
        store.commit().unwrap();
        assert!(store.attachments(&doc).is_empty());
    }
}
