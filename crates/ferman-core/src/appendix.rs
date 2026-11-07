//! Render-only bytes (ADR 0009): what PDFium reads after a document's own bytes and Ferman never
//! writes to disk or keeps as a revision. [`RevisionStore::render_appendix`] is the committed
//! revisions as the writer would save them, with a catalog that shows and hides layers (a2-3c) in
//! one more revision only this copy has; [`RevisionStore::pages_changed_since`] says which pages
//! a new appendix draws differently. The writing helpers here serve the writers too.
// Offsets and sizes are checked (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeSet;

use lopdf::{Dictionary, Object, ObjectId};

use crate::annotations::MAX_PER_DOCUMENT;
use crate::revision::RevisionStore;
use crate::structure::Scope;
use crate::syntax::is_regular;
use crate::{CoreError, Document, Unsupported};

/// The objects a walk of the pages reads before it gives up and calls every page changed, so a
/// hostile file cannot hold up a commit.
const MAX_WALK: usize = 2_000_000;

/// `/F`: hidden.
const HIDDEN: i64 = 2;

/// The markup annotations (ISO 32000-2 §12.5.6.2): what Hide all hides.
const MARKUP: &[&[u8]] = &[
    b"Text",
    b"FreeText",
    b"Line",
    b"Square",
    b"Circle",
    b"Polygon",
    b"PolyLine",
    b"Highlight",
    b"Underline",
    b"Squiggly",
    b"StrikeOut",
    b"Stamp",
    b"Caret",
    b"Ink",
    b"FileAttachment",
    b"Sound",
    b"Redact",
];

impl RevisionStore {
    /// The bytes to put after `doc`'s for PDFium to render these revisions, empty when none
    /// applies and nothing else is asked. With `visible` (one value per
    /// [`Structure::layers`](crate::structure::Structure), in order) it shows those layers and
    /// hides the others; groups not listed keep their state. With `hide_comments` every markup
    /// annotation gets the hidden bit (a4-5, decision 12): widgets, links and signatures stay.
    ///
    /// # Errors
    ///
    /// [`CoreError::Internal`] for `visible` on a document without layers, and the errors of
    /// [`incremental_update`](Self::incremental_update).
    pub fn render_appendix(
        &self,
        doc: &Document,
        visible: Option<&[bool]>,
        hide_comments: bool,
    ) -> Result<Vec<u8>, CoreError> {
        let bytes = if visible.is_some() || hide_comments {
            let mut shown = self.clone();
            shown.begin()?;
            if let Some(visible) = visible {
                let (root, catalog) = self.catalog_showing(doc, visible)?;
                shown.put(root, Object::Dictionary(catalog))?;
            }
            if hide_comments {
                for (id, object) in self.markup_hidden(doc) {
                    shown.put(id, object)?;
                }
            }
            shown.commit()?;
            shown.incremental_update(doc)?
        } else {
            self.incremental_update(doc)?
        };
        Ok(bytes
            .get(doc.source().bytes().len()..)
            .unwrap_or_default()
            .to_vec())
    }

    /// Takes every markup annotation, and the pop-ups they own, out of the pages' `/Annots` in
    /// the open transaction (Save as without "Include comments and markup", a1-11): widgets,
    /// links and signatures stay. How many it took out; a rewrite then leaves them out of the
    /// file, while an incremental update keeps their objects in the earlier revision.
    ///
    /// # Errors
    ///
    /// [`crate::WriteError::NoTransaction`].
    pub fn remove_markup(&mut self, doc: &Document) -> Result<u32, CoreError> {
        self.transaction_open()?;
        let mut removed = 0u32;
        for index in 0..self.pages(doc).len() {
            let gone: Vec<bool> = {
                let scope = self.scope(doc);
                let Some(dict) = self
                    .pages(doc)
                    .get(index)
                    .and_then(|page| scope.dictionary(page.id))
                else {
                    continue;
                };
                let markup = |annotation: &Dictionary| {
                    scope
                        .get_name(annotation, b"Subtype")
                        .is_some_and(|subtype| MARKUP.contains(&subtype))
                };
                scope
                    .get_array(dict, b"Annots")
                    .into_iter()
                    .flatten()
                    .map(|item| {
                        scope.dict(item).is_some_and(|annotation| {
                            markup(annotation)
                                || (scope.get_name(annotation, b"Subtype") == Some(b"Popup")
                                    && scope.get_dict(annotation, b"Parent").is_some_and(markup))
                        })
                    })
                    .collect()
            };
            let count = gone.iter().filter(|&&gone| gone).count();
            if count == 0 {
                continue;
            }
            let mut flags = gone.into_iter();
            self.change_annots(doc, index, |items| {
                items.retain(|_| !flags.next().unwrap_or(false));
                true
            })?;
            removed = removed.saturating_add(u32::try_from(count).unwrap_or(u32::MAX));
        }
        Ok(removed)
    }

    /// The objects that hide every markup annotation still drawn: each one's own object, and a
    /// page's dictionary for those written directly in its `/Annots`.
    fn markup_hidden(&self, doc: &Document) -> Vec<(ObjectId, Object)> {
        let scope = self.scope(doc);
        let hidden = |annotation: &Dictionary| -> Option<Dictionary> {
            let subtype = scope.get_name(annotation, b"Subtype")?;
            let flags = scope.get_int(annotation, b"F").unwrap_or(0);
            if !MARKUP.contains(&subtype) || flags & HIDDEN != 0 {
                return None;
            }
            let mut annotation = annotation.clone();
            annotation.set("F", flags | HIDDEN);
            Some(annotation)
        };
        let mut queued = Vec::new();
        let mut seen = BTreeSet::new();
        let mut left = MAX_PER_DOCUMENT;
        for page in self.pages(doc) {
            let Some(dict) = scope.dictionary(page.id) else {
                continue;
            };
            let Some(items) = scope.get_array(dict, b"Annots") else {
                continue;
            };
            let mut direct = items.clone();
            let mut any_direct = false;
            for item in &mut direct {
                let Some(next) = left.checked_sub(1) else {
                    break;
                };
                left = next;
                if let Ok(id) = item.as_reference() {
                    if seen.insert(id)
                        && let Some(annotation) = scope.dict(&Object::Reference(id))
                        && let Some(annotation) = hidden(annotation)
                    {
                        queued.push((id, Object::Dictionary(annotation)));
                    }
                } else if let Ok(annotation) = item.as_dict()
                    && let Some(annotation) = hidden(annotation)
                {
                    *item = Object::Dictionary(annotation);
                    any_direct = true;
                }
            }
            if any_direct {
                let mut dict = dict.clone();
                dict.set("Annots", direct);
                queued.push((page.id, Object::Dictionary(dict)));
            }
        }
        queued
    }

    /// The catalog's id and its dictionary with `visible` as the layers' state.
    fn catalog_showing(
        &self,
        doc: &Document,
        visible: &[bool],
    ) -> Result<(ObjectId, Dictionary), CoreError> {
        let missing = || CoreError::Internal {
            context: "a layer appendix for a document without layers",
        };
        let scope = self.scope(doc);
        let root = doc
            .xref()
            .trailer
            .get(b"Root")
            .and_then(Object::as_reference)
            .map_err(|_| missing())?;
        let mut catalog = self.dictionary(doc, root).map_err(|_| missing())?;
        let mut properties = catalog
            .get(b"OCProperties")
            .ok()
            .and_then(|properties| scope.dict(properties))
            .cloned()
            .ok_or_else(missing)?;
        let mut config = properties
            .get(b"D")
            .ok()
            .and_then(|config| scope.dict(config))
            .cloned()
            .unwrap_or_default();
        let mut on = references(&scope, config.get(b"ON").ok());
        let mut off = references(&scope, config.get(b"OFF").ok());
        for (layer, &shown) in doc.structure().layers.iter().zip(visible) {
            on.retain(|id| *id != layer.id);
            off.retain(|id| *id != layer.id);
            if shown {
                on.push(layer.id);
            } else {
                off.push(layer.id);
            }
        }
        let array =
            |ids: Vec<ObjectId>| Object::Array(ids.into_iter().map(Object::Reference).collect());
        config.set("ON", array(on));
        config.set("OFF", array(off));
        // /AS would set states again by usage (ISO 32000-2 §8.11.4.4); the sidebar shows /ON and
        // /OFF.
        config.remove(b"AS");
        properties.set("D", config);
        catalog.set("OCProperties", properties);
        Ok((root, catalog))
    }

    /// The pages these revisions draw differently from `before`'s, by index, in order: those that
    /// reach a changed object through their dictionary, a page-tree node above it, `/Contents`,
    /// `/Resources` (inherited too), `/Group`, a box, an annotation or its appearance. `None`
    /// means every page: pages were added, removed or moved, the catalog changed, or the file is
    /// too tangled to walk.
    #[must_use]
    pub fn pages_changed_since(&self, doc: &Document, before: &Self) -> Option<Vec<u32>> {
        let handles = |store: &Self| -> Vec<u64> {
            let pages = store.pages(doc);
            pages.iter().map(crate::structure::Page::handle).collect()
        };
        if handles(self) != handles(before) {
            return None;
        }
        let (now, then) = (self.committed(), before.committed());
        let mut changed: BTreeSet<ObjectId> = now
            .iter()
            .filter(|&(id, object)| then.get(id) != Some(object))
            .map(|(id, _)| *id)
            .collect();
        changed.extend(then.keys().filter(|id| !now.contains_key(*id)));
        // A catalog that changed only in /AcroForm draws the same: its fonts and fields reach a page
        // through the widgets, and the walk below finds those.
        let root = doc.xref().trailer.get(b"Root").ok()?.as_reference().ok()?;
        if changed.contains(&root) {
            let without_form = |store: &Self| {
                let mut catalog = store.scope(doc).dictionary(root)?.clone();
                catalog.remove(b"AcroForm");
                Some(catalog)
            };
            if without_form(self)? != without_form(before)? {
                return None;
            }
        }
        let scope = self.scope(doc);
        let mut walk = Walk {
            scope: &scope,
            changed: &changed,
            clean: BTreeSet::new(),
            left: MAX_WALK,
        };
        let mut pages = Vec::new();
        for (index, page) in self.pages(doc).iter().enumerate() {
            if walk.page_changed(page.id)? {
                pages.push(u32::try_from(index).ok()?);
            }
        }
        Some(pages)
    }
}

/// A walk of pages for changed objects.
struct Walk<'s, 'a> {
    scope: &'s Scope<'a>,
    changed: &'s BTreeSet<ObjectId>,
    /// Objects a page came clean through, so pages that share resources walk them once.
    clean: BTreeSet<ObjectId>,
    left: usize,
}

impl<'a> Walk<'_, 'a> {
    /// Whether `page` reaches a changed object; `None` once the walk has read too much.
    fn page_changed(&mut self, page: ObjectId) -> Option<bool> {
        if self.changed.contains(&page) {
            return Some(true);
        }
        let Some(Object::Dictionary(dict)) = self.scope.object(page) else {
            return Some(true);
        };
        let mut stack: Vec<&'a Object> = [&b"Contents"[..], b"Group"]
            .iter()
            .filter_map(|key| dict.get(key).ok())
            .collect();
        // An annotation's /P, /Parent, /Dest and /A lead to other pages, which draw nothing here.
        if let Ok(annotations) = dict.get(b"Annots") {
            if self.is_changed(annotations) {
                return Some(true);
            }
            let items = self
                .scope
                .resolve(annotations)
                .and_then(|items| items.as_array().ok());
            for annotation in items.into_iter().flatten() {
                if self.is_changed(annotation) {
                    return Some(true);
                }
                if let Some(annotation) = self.scope.dict(annotation) {
                    stack.extend(
                        [&b"AP"[..], b"OC"]
                            .iter()
                            .filter_map(|key| annotation.get(key).ok()),
                    );
                }
            }
        }
        // What the page inherits, from the page itself up.
        let mut node = dict;
        let mut above = BTreeSet::new();
        let mut inherited = vec![&b"Resources"[..], b"MediaBox", b"CropBox", b"Rotate"];
        for _ in 0..=self.scope.limits.max_nesting {
            inherited.retain(|key| match node.get(key) {
                Ok(value) => {
                    stack.push(value);
                    false
                }
                Err(_) => true,
            });
            let Some(parent) = node
                .get(b"Parent")
                .ok()
                .and_then(|parent| parent.as_reference().ok())
            else {
                break;
            };
            if self.changed.contains(&parent) {
                return Some(true);
            }
            let Some(Object::Dictionary(next)) = self.scope.object(parent) else {
                break;
            };
            if !above.insert(parent) {
                break;
            }
            node = next;
        }
        self.reaches_changed(stack)
    }

    fn is_changed(&self, object: &Object) -> bool {
        object
            .as_reference()
            .is_ok_and(|id| self.changed.contains(&id))
    }

    /// Whether anything reachable from `stack` is changed, without following `/Parent`.
    fn reaches_changed(&mut self, mut stack: Vec<&'a Object>) -> Option<bool> {
        let mut seen = BTreeSet::new();
        while let Some(object) = stack.pop() {
            self.left = self.left.checked_sub(1)?;
            match object {
                Object::Reference(id) => {
                    if self.changed.contains(id) {
                        return Some(true);
                    }
                    if !self.clean.contains(id)
                        && seen.insert(*id)
                        && let Some(target) = self.scope.object(*id)
                    {
                        stack.push(target);
                    }
                }
                Object::Array(items) => stack.extend(items),
                Object::Dictionary(dict) => push_values(&mut stack, dict),
                Object::Stream(stream) => push_values(&mut stack, &stream.dict),
                _ => {}
            }
        }
        self.clean.append(&mut seen);
        Some(false)
    }
}

/// Pushes `dict`'s values but `/Parent`, which leads back up to every page.
fn push_values<'a>(stack: &mut Vec<&'a Object>, dict: &'a Dictionary) {
    stack.extend(
        dict.iter()
            .filter(|(key, _)| key.as_slice() != b"Parent")
            .map(|(_, value)| value),
    );
}

/// The references in the array `object` is or refers to.
fn references<'a>(scope: &Scope<'a>, object: Option<&'a Object>) -> Vec<ObjectId> {
    object
        .and_then(|object| scope.resolve(object))
        .and_then(|array| array.as_array().ok())
        .map(|items| {
            items
                .iter()
                .filter_map(|item| item.as_reference().ok())
                .collect()
        })
        .unwrap_or_default()
}

/// `start + at`, as a cross-reference offset.
pub(crate) fn offset(start: usize, at: usize) -> Result<u32, CoreError> {
    start
        .checked_add(at)
        .and_then(|offset| u32::try_from(offset).ok())
        .ok_or(CoreError::Unsupported(Unsupported::FileSize))
}

/// Writes `value` as the indirect object `id`; a stream with a direct `/Length` of its data.
pub(crate) fn indirect(out: &mut Vec<u8>, id: ObjectId, value: &Object) {
    out.extend(format!("{} {} obj\n", id.0, id.1).as_bytes());
    if let Object::Stream(stream) = value {
        let mut dict = stream.dict.clone();
        dict.set(
            "Length",
            i64::try_from(stream.content.len()).unwrap_or(i64::MAX),
        );
        object(out, &Object::Dictionary(dict));
        out.extend(b"\nstream\n");
        out.extend(&stream.content);
        out.extend(b"\nendstream");
    } else {
        object(out, value);
    }
    out.extend(b"\nendobj\n");
}

/// Writes a direct object. Strings are written in hex, which needs no escapes; a stream cannot be
/// direct, so it is written as `null`.
pub(crate) fn object(out: &mut Vec<u8>, value: &Object) {
    match value {
        Object::Null | Object::Stream(_) => out.extend(b"null"),
        Object::Boolean(value) => out.extend(if *value { &b"true"[..] } else { b"false" }),
        Object::Integer(value) => out.extend(value.to_string().as_bytes()),
        // Display never uses an exponent, which PDF numbers cannot have.
        Object::Real(value) if value.is_finite() => out.extend(value.to_string().as_bytes()),
        Object::Real(_) => out.push(b'0'),
        Object::Name(name) => self::name(out, name),
        Object::String(bytes, _) => {
            out.push(b'<');
            for byte in bytes {
                out.extend(format!("{byte:02X}").as_bytes());
            }
            out.push(b'>');
        }
        Object::Array(items) => {
            out.push(b'[');
            for item in items {
                object(out, item);
                out.push(b' ');
            }
            out.push(b']');
        }
        Object::Dictionary(entries) => {
            out.extend(b"<<");
            for (key, value) in entries {
                name(out, key);
                out.push(b' ');
                object(out, value);
                out.push(b' ');
            }
            out.extend(b">>");
        }
        Object::Reference((number, generation)) => {
            out.extend(format!("{number} {generation} R").as_bytes());
        }
    }
}

/// Writes a name, with `#` escapes for the bytes a name cannot hold as they are.
pub(crate) fn name(out: &mut Vec<u8>, name: &[u8]) {
    out.push(b'/');
    for &byte in name {
        if is_regular(byte) && byte != b'#' && (0x21..=0x7E).contains(&byte) {
            out.push(byte);
        } else {
            out.extend(format!("#{byte:02X}").as_bytes());
        }
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::{Object, dictionary};

    use crate::revision::RevisionStore;
    use crate::write::Value;
    use crate::{Document, OpenOptions, Source, open};

    /// A one-page file with three layers, "Notlar" off, saved by lopdf in the classic or the
    /// modern form (object streams and a cross-reference stream).
    fn layered(modern: bool) -> Vec<u8> {
        let mut doc = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let groups: Vec<Object> = ["Duvarlar", "Tesisat", "Notlar"]
            .iter()
            .map(|name| {
                doc.add_object(
                    dictionary! { "Type" => "OCG", "Name" => Object::string_literal(*name) },
                )
                .into()
            })
            .collect();
        let catalog = doc.trailer.get(b"Root").unwrap().as_reference().unwrap();
        doc.get_dictionary_mut(catalog).unwrap().set(
            "OCProperties",
            dictionary! {
                "OCGs" => groups.clone(),
                "D" => dictionary! {
                    "Name" => Object::string_literal("Varsayılan (#1)"),
                    "OFF" => vec![groups[2].clone()],
                    "AS" => vec![],
                },
            },
        );
        let mut bytes = Vec::new();
        if modern {
            doc.save_modern(&mut bytes).unwrap();
        } else {
            doc.save_to(&mut bytes).unwrap();
        }
        bytes
    }

    fn visible(bytes: &[u8]) -> Vec<bool> {
        let document = open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap();
        // A wrong offset in the appendix's table would make ferman-core repair the file.
        assert!(document.repair().is_none());
        document
            .structure()
            .layers
            .iter()
            .map(|layer| layer.visible)
            .collect()
    }

    #[test]
    fn the_appendix_sets_every_layer_and_keeps_the_original_as_a_prefix() {
        for modern in [false, true] {
            let original = layered(modern);
            assert_eq!(visible(&original), [true, true, false], "modern {modern}");
            let document = opened(&original);
            let store = RevisionStore::new(&document);
            assert!(
                store
                    .render_appendix(&document, None, false)
                    .unwrap()
                    .is_empty()
            );
            for wanted in [
                [false, true, true],
                [true, true, false],
                [false, false, false],
            ] {
                let mut copy = original.clone();
                copy.extend(
                    store
                        .render_appendix(&document, Some(&wanted), false)
                        .unwrap(),
                );
                assert!(copy.starts_with(&original));
                assert_eq!(visible(&copy), wanted, "modern {modern}");
                assert_eq!(opened(&copy).page_count(), 1);
            }
        }
    }

    #[test]
    fn the_appendix_keeps_the_revisions_it_shows_layers_over() {
        let original = layered(true);
        let document = opened(&original);
        let mut store = RevisionStore::new(&document);
        store.begin().unwrap();
        store
            .set_page_entry(&document, 0, b"Rotate", Value::Integer(90))
            .unwrap();
        store.commit().unwrap();
        let mut copy = original.clone();
        copy.extend(
            store
                .render_appendix(&document, Some(&[false, true, true]), false)
                .unwrap(),
        );
        assert_eq!(visible(&copy), [false, true, true]);
        assert_eq!(opened(&copy).structure().pages[0].rotation, 90);
        // The copy's catalog is not a revision.
        assert_eq!(store.current(), 1);
        assert_eq!(
            visible(&store.incremental_update(&document).unwrap()),
            [true, true, false]
        );
    }

    fn opened(bytes: &[u8]) -> Document {
        open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap()
    }

    /// Three pages: 0 and 1 share a font through inherited resources, 2 has its own font, an
    /// annotation with an appearance and one that points at page 0.
    fn three_pages() -> Document {
        let mut doc = crate::structure::tests::doc_with(
            vec![dictionary! {}, dictionary! {}, dictionary! {}],
            dictionary! {},
        );
        let content = doc.add_object(lopdf::Stream::new(dictionary! {}, b"q Q".to_vec()));
        let shared = doc.add_object(dictionary! { "Type" => "Font", "BaseFont" => "Shared" });
        let own = doc.add_object(dictionary! { "Type" => "Font", "BaseFont" => "Own" });
        let appearance = doc.add_object(lopdf::Stream::new(dictionary! {}, b"q Q".to_vec()));
        let pages = doc.get_pages();
        let ids: Vec<_> = pages.values().copied().collect();
        let note = doc.add_object(dictionary! {
            "Subtype" => "Square",
            "P" => ids[0],
            "AP" => dictionary! { "N" => appearance },
        });
        let parent = doc
            .get_dictionary(ids[0])
            .unwrap()
            .get(b"Parent")
            .unwrap()
            .as_reference()
            .unwrap();
        doc.get_dictionary_mut(parent).unwrap().set(
            "Resources",
            dictionary! { "Font" => dictionary! { "F" => shared } },
        );
        for id in &ids {
            doc.get_dictionary_mut(*id)
                .unwrap()
                .set("Contents", content);
        }
        let third = doc.get_dictionary_mut(ids[2]).unwrap();
        third.set(
            "Resources",
            dictionary! { "Font" => dictionary! { "F" => own } },
        );
        third.set("Annots", vec![Object::Reference(note)]);
        let mut bytes = Vec::new();
        doc.save_to(&mut bytes).unwrap();
        opened(&bytes)
    }

    /// Replaces the first object of `doc` whose dictionary has `key` = `value`, in a new revision.
    fn replace(store: &mut RevisionStore, doc: &Document, key: &[u8], value: &[u8]) {
        let id = doc
            .model()
            .objects
            .iter()
            .find(|(_, object)| {
                let dict = match object {
                    Object::Dictionary(dict) => dict,
                    Object::Stream(stream) => &stream.dict,
                    _ => return false,
                };
                dict.get(key)
                    .and_then(Object::as_name)
                    .is_ok_and(|name| name == value)
            })
            .map(|(id, _)| *id)
            .unwrap();
        let mut object = doc.model().objects.get(&id).unwrap().clone();
        match &mut object {
            Object::Dictionary(dict) => dict.set("Changed", true),
            Object::Stream(stream) => stream.dict.set("Changed", true),
            _ => unreachable!(),
        }
        store.begin().unwrap();
        store.put(id, object).unwrap();
        store.commit().unwrap();
    }

    #[test]
    fn only_the_pages_that_reach_a_changed_object_changed() {
        let doc = three_pages();
        let empty = RevisionStore::new(&doc);
        assert_eq!(empty.pages_changed_since(&doc, &empty), Some(vec![]));

        // A page's own dictionary.
        let mut store = empty.clone();
        store.begin().unwrap();
        store
            .set_page_entry(&doc, 1, b"Rotate", Value::Integer(90))
            .unwrap();
        store.commit().unwrap();
        assert_eq!(store.pages_changed_since(&doc, &empty), Some(vec![1]));
        // Undo is a change too.
        let before = store.clone();
        store.undo().unwrap();
        assert_eq!(store.pages_changed_since(&doc, &before), Some(vec![1]));

        // A font through inherited resources, and one of a page's own.
        let mut store = empty.clone();
        replace(&mut store, &doc, b"BaseFont", b"Shared");
        assert_eq!(store.pages_changed_since(&doc, &empty), Some(vec![0, 1]));
        let mut store = empty.clone();
        replace(&mut store, &doc, b"BaseFont", b"Own");
        assert_eq!(store.pages_changed_since(&doc, &empty), Some(vec![2]));

        // An annotation on page 2 that names page 0: page 0's change is not page 2's.
        let mut store = empty.clone();
        replace(&mut store, &doc, b"Subtype", b"Square");
        assert_eq!(store.pages_changed_since(&doc, &empty), Some(vec![2]));
        let mut store = empty.clone();
        store.begin().unwrap();
        store
            .set_page_entry(&doc, 0, b"Rotate", Value::Integer(90))
            .unwrap();
        store.commit().unwrap();
        assert_eq!(store.pages_changed_since(&doc, &empty), Some(vec![0]));

        // The catalog, and a page tree node above them all.
        let mut store = empty.clone();
        replace(&mut store, &doc, b"Type", b"Catalog");
        assert_eq!(store.pages_changed_since(&doc, &empty), None);
        let mut store = empty.clone();
        replace(&mut store, &doc, b"Type", b"Pages");
        assert_eq!(store.pages_changed_since(&doc, &empty), Some(vec![0, 1, 2]));
    }

    #[test]
    fn names_and_strings_are_written_so_they_read_back() {
        let mut out = Vec::new();
        super::object(
            &mut out,
            &Object::Array(vec![
                Object::Name(b"A B#(".to_vec()),
                Object::string_literal("a)b"),
                Object::Real(0.000_1),
                Object::Real(f32::NAN),
            ]),
        );
        assert_eq!(out, b"[/A#20B#23#28 <612962> 0.0001 0 ]");
    }
}
