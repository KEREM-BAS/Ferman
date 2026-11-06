//! The write API (docs/ARCHITECTURE.md §2.3, question 11 of the M4 plan): what an operation above
//! ferman-core needs to change a document inside a transaction of its [`RevisionStore`], with no
//! lopdf type leaving this crate. [`Value`] is a PDF object as plain data; `add_object`,
//! `replace_object`, `allocate` and `object` work on whole objects, `set_page_entry` and the
//! `/Annots` primitives on a page. Saving, recovery and undo need nothing new: they work on the
//! objects a revision holds.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use lopdf::{Dictionary, Object, ObjectId, StringFormat};

use crate::revision::{RevisionStore, compressed, decoded, free};
use crate::{CoreError, Document};

/// An object's number and generation, opaque above ferman-core.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct ObjectRef(ObjectId);

/// A PDF object as plain data.
#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    /// `null`.
    Null,
    /// `true` or `false`.
    Boolean(bool),
    /// An integer.
    Integer(i64),
    /// A real number.
    Real(f32),
    /// A name, without its slash.
    Name(Vec<u8>),
    /// A string's bytes; an encrypted document's writer encrypts them.
    String(Vec<u8>),
    /// An array.
    Array(Vec<Value>),
    /// A dictionary, in its keys' order.
    Dictionary(Vec<(Vec<u8>, Value)>),
    /// A stream: its dictionary and its decoded data, written compressed with Flate. Its
    /// `/Filter`, `/DecodeParms` and `/Length` are the writer's.
    Stream {
        /// The dictionary.
        dict: Vec<(Vec<u8>, Value)>,
        /// The decoded data.
        data: Vec<u8>,
    },
    /// A reference to another object.
    Reference(ObjectRef),
}

impl Value {
    /// The model's object for this value.
    fn into_object(self) -> Result<Object, CoreError> {
        Ok(match self {
            Self::Null => Object::Null,
            Self::Boolean(value) => Object::Boolean(value),
            Self::Integer(value) => Object::Integer(value),
            Self::Real(value) => Object::Real(value),
            Self::Name(name) => Object::Name(name),
            Self::String(bytes) => Object::String(bytes, StringFormat::Literal),
            Self::Array(items) => Object::Array(
                items
                    .into_iter()
                    .map(Self::into_object)
                    .collect::<Result<_, _>>()?,
            ),
            Self::Dictionary(entries) => Object::Dictionary(dictionary(entries)?),
            Self::Stream { dict, data } => {
                let mut dict = dictionary(dict)?;
                for key in [&b"Filter"[..], b"DecodeParms", b"Length"] {
                    dict.remove(key);
                }
                Object::Stream(compressed(dict, &data)?)
            }
            Self::Reference(ObjectRef(id)) => Object::Reference(id),
        })
    }

    /// This value for the model's `object`, a stream's data decoded within `doc`'s limits.
    fn of(object: &Object, doc: &Document) -> Result<Self, CoreError> {
        Ok(match object {
            Object::Null => Self::Null,
            Object::Boolean(value) => Self::Boolean(*value),
            Object::Integer(value) => Self::Integer(*value),
            Object::Real(value) => Self::Real(*value),
            Object::Name(name) => Self::Name(name.clone()),
            Object::String(bytes, _) => Self::String(bytes.clone()),
            Object::Array(items) => Self::Array(
                items
                    .iter()
                    .map(|item| Self::of(item, doc))
                    .collect::<Result<_, _>>()?,
            ),
            Object::Dictionary(dict) => Self::Dictionary(entries(dict, doc)?),
            Object::Stream(stream) => Self::Stream {
                dict: entries(&stream.dict, doc)?,
                data: decoded(stream, doc)?,
            },
            Object::Reference(id) => Self::Reference(ObjectRef(*id)),
        })
    }
}

fn dictionary(entries: Vec<(Vec<u8>, Value)>) -> Result<Dictionary, CoreError> {
    let mut dict = Dictionary::new();
    for (key, value) in entries {
        dict.set(key, value.into_object()?);
    }
    Ok(dict)
}

fn entries(dict: &Dictionary, doc: &Document) -> Result<Vec<(Vec<u8>, Value)>, CoreError> {
    dict.iter()
        .map(|(key, value)| Ok((key.clone(), Value::of(value, doc)?)))
        .collect()
}

impl RevisionStore {
    /// Takes a new object's number in the open transaction, for objects that name each other; it
    /// reads as null until [`replace_object`](Self::replace_object) fills it.
    ///
    /// # Errors
    ///
    /// [`crate::WriteError::NoTransaction`] and [`crate::WriteError::ObjectNumbers`].
    pub fn allocate(&mut self) -> Result<ObjectRef, CoreError> {
        let id = (free(self.next_number())?, 0);
        self.put(id, Object::Null)?;
        Ok(ObjectRef(id))
    }

    /// Adds `value` as a new object in the open transaction.
    ///
    /// # Errors
    ///
    /// As [`allocate`](Self::allocate), and those of [`replace_object`](Self::replace_object).
    pub fn add_object(&mut self, doc: &Document, value: Value) -> Result<ObjectRef, CoreError> {
        // Not allocate: on an error the transaction stays as it was.
        let id = (free(self.next_number())?, 0);
        self.replace_object(doc, ObjectRef(id), value)?;
        Ok(ObjectRef(id))
    }

    /// Makes `value` the new version of object `id` in the open transaction.
    ///
    /// # Errors
    ///
    /// [`crate::WriteError::NoTransaction`], [`CoreError::OutOfMemory`] and
    /// [`CoreError::ResourceLimit`] past the decoded size per revision.
    pub fn replace_object(
        &mut self,
        doc: &Document,
        id: ObjectRef,
        value: Value,
    ) -> Result<(), CoreError> {
        self.put_counted(doc, vec![(id.0, value.into_object()?)])
    }

    /// Object `id` as these revisions and the open transaction leave it, `None` when it does not
    /// exist.
    ///
    /// # Errors
    ///
    /// The errors of decoding a stream within the document's limits.
    pub fn object(&self, doc: &Document, id: ObjectRef) -> Result<Option<Value>, CoreError> {
        self.scope(doc)
            .object(id.0)
            .map(|object| Value::of(object, doc))
            .transpose()
    }

    /// Sets `key` of page `index`'s own dictionary to `value` in the open transaction: a value
    /// the page inherited is overridden for it alone.
    ///
    /// # Errors
    ///
    /// [`crate::WriteError::NoTransaction`] and [`crate::WriteError::NoSuchPage`].
    pub fn set_page_entry(
        &mut self,
        doc: &Document,
        index: usize,
        key: &[u8],
        value: Value,
    ) -> Result<(), CoreError> {
        let page = self.page_id(doc, index)?;
        let mut dict = self.dictionary(doc, page)?;
        dict.set(key.to_vec(), value.into_object()?);
        self.put(page, Object::Dictionary(dict))
    }

    /// Adds `annotation` to the end of page `index`'s `/Annots` in the open transaction.
    ///
    /// # Errors
    ///
    /// As [`set_page_entry`](Self::set_page_entry).
    pub fn append_annotation(
        &mut self,
        doc: &Document,
        index: usize,
        annotation: ObjectRef,
    ) -> Result<(), CoreError> {
        self.change_annots(doc, index, |items| {
            items.push(Object::Reference(annotation.0));
            true
        })
        .map(drop)
    }

    /// Takes `annotation` out of page `index`'s `/Annots` in the open transaction; `false`, with
    /// the transaction as it was, when the page does not name it.
    ///
    /// # Errors
    ///
    /// As [`set_page_entry`](Self::set_page_entry).
    pub fn remove_annotation(
        &mut self,
        doc: &Document,
        index: usize,
        annotation: ObjectRef,
    ) -> Result<bool, CoreError> {
        self.change_annots(doc, index, |items| {
            let before = items.len();
            items.retain(|item| item.as_reference().ok() != Some(annotation.0));
            items.len() != before
        })
    }

    /// Runs `change` on page `index`'s `/Annots` and writes them back when it says it changed
    /// them: an indirect array that only this page names as itself, any other as a direct array
    /// of the page, so another page's annotations stay.
    fn change_annots(
        &mut self,
        doc: &Document,
        index: usize,
        change: impl FnOnce(&mut Vec<Object>) -> bool,
    ) -> Result<bool, CoreError> {
        let page = self.page_id(doc, index)?;
        let mut dict = self.dictionary(doc, page)?;
        let (holder, mut items) = {
            let scope = self.scope(doc);
            let entry = dict.get(b"Annots").ok();
            let holder = entry.and_then(|annots| annots.as_reference().ok());
            let items = entry
                .and_then(|annots| scope.resolve(annots))
                .and_then(|annots| annots.as_array().ok())
                .cloned()
                .unwrap_or_default();
            (holder, items)
        };
        if !change(&mut items) {
            return Ok(false);
        }
        let array = Object::Array(items);
        match holder.filter(|&id| !self.annots_shared(doc, page, id)) {
            Some(id) => self.put(id, array)?,
            None => {
                dict.set("Annots", array);
                self.put(page, Object::Dictionary(dict))?;
            }
        }
        Ok(true)
    }

    /// Whether a page other than `page` names the array `id` as its `/Annots`.
    fn annots_shared(&self, doc: &Document, page: ObjectId, id: ObjectId) -> bool {
        let scope = self.scope(doc);
        self.pages(doc)
            .iter()
            .filter(|other| other.id != page)
            .filter_map(|other| scope.dictionary(other.id))
            .any(|other| {
                other
                    .get(b"Annots")
                    .is_ok_and(|annots| annots.as_reference().ok() == Some(id))
            })
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::dictionary;

    use super::*;
    use crate::structure::tests::doc_with;
    use crate::{OpenOptions, Source, WriteError, open};

    /// A document with the given page dictionaries, saved and opened.
    fn opened(pages: Vec<Dictionary>, extra: impl FnOnce(&mut lopdf::Document)) -> Document {
        let mut doc = doc_with(pages, dictionary! {});
        extra(&mut doc);
        let mut bytes = Vec::new();
        doc.save_to(&mut bytes).unwrap();
        open(
            &Source::from_bytes(Arc::from(&bytes[..])),
            &OpenOptions::default(),
        )
        .unwrap()
    }

    fn annots(store: &RevisionStore, doc: &Document, index: usize) -> Vec<ObjectId> {
        let scope = store.scope(doc);
        let page = store.page_id(doc, index).unwrap();
        scope
            .get_array(scope.dictionary(page).unwrap(), b"Annots")
            .map(|items| {
                items
                    .iter()
                    .map(|item| item.as_reference().unwrap())
                    .collect()
            })
            .unwrap_or_default()
    }

    #[test]
    fn annotations_join_a_missing_a_direct_and_an_indirect_array() {
        let doc = opened(
            vec![
                dictionary! {},
                dictionary! { "Annots" => vec![Object::Reference((900, 0))] },
                dictionary! { "Annots" => (901, 0) },
            ],
            |model| {
                model
                    .objects
                    .insert((901, 0), Object::Array(vec![Object::Reference((900, 0))]));
                model
                    .objects
                    .insert((900, 0), Object::Dictionary(dictionary! {}));
            },
        );
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let note = store
            .add_object(
                &doc,
                Value::Dictionary(vec![(b"T".to_vec(), Value::Integer(1))]),
            )
            .unwrap();
        for page in 0..3 {
            store.append_annotation(&doc, page, note).unwrap();
            assert_eq!(annots(&store, &doc, page).last(), Some(&note.0));
        }
        // The indirect array changes as itself; the page dictionary stays.
        assert_eq!(store.lookup((901, 0)).unwrap().as_array().unwrap().len(), 2);
        assert!(store.lookup(store.page_id(&doc, 2).unwrap()).is_none());
        for page in 0..3 {
            assert!(store.remove_annotation(&doc, page, note).unwrap());
            assert!(!store.remove_annotation(&doc, page, note).unwrap());
            assert!(!annots(&store, &doc, page).contains(&note.0));
        }
    }

    #[test]
    fn an_indirect_array_two_pages_share_is_not_changed_for_the_other() {
        let doc = opened(
            vec![
                dictionary! { "Annots" => (901, 0) },
                dictionary! { "Annots" => (901, 0) },
            ],
            |model| {
                model.objects.insert((901, 0), Object::Array(Vec::new()));
            },
        );
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let note = store.add_object(&doc, Value::Null).unwrap();
        store.append_annotation(&doc, 0, note).unwrap();
        assert_eq!(annots(&store, &doc, 0), [note.0]);
        assert!(annots(&store, &doc, 1).is_empty());
    }

    #[test]
    fn allocated_numbers_differ_and_objects_read_back() {
        let doc = opened(vec![dictionary! {}], |_| {});
        let mut store = RevisionStore::new(&doc);
        assert!(matches!(
            store.allocate(),
            Err(CoreError::Write(WriteError::NoTransaction))
        ));
        store.begin().unwrap();
        let first = store.allocate().unwrap();
        let second = store.allocate().unwrap();
        assert_ne!(first, second);
        assert_eq!(store.object(&doc, first).unwrap(), Some(Value::Null));
        let value = Value::Stream {
            dict: vec![(b"Subtype".to_vec(), Value::Name(b"Form".to_vec()))],
            data: b"q Q".to_vec(),
        };
        store.replace_object(&doc, first, value.clone()).unwrap();
        let Some(Value::Stream { data, dict }) = store.object(&doc, first).unwrap() else {
            panic!("not a stream");
        };
        assert_eq!(data, b"q Q");
        assert!(dict.iter().any(|(key, _)| key == b"Subtype"));
        store.commit().unwrap();
        store.undo().unwrap();
        assert_eq!(store.object(&doc, first).unwrap(), None);
    }
}
