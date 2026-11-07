//! The outline writer (a2-3a, M4 plan W6): the bookmarks renamed, added, nested, moved and
//! deleted in one change. An item that stays keeps its object, its destination or action as the
//! file has it (an integer destination W1 wrote stays an integer), its colour and its style; an
//! item whose dictionary would come out the same is not written again.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use lopdf::{Dictionary, Object, ObjectId, StringFormat};

use crate::revision::RevisionStore;
use crate::structure::OutlineItem;
use crate::{CoreError, Document, WriteError, text_string};

/// One item of the outline as [`RevisionStore::set_outline`] writes it, in reading order: each
/// item followed by its children.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OutlineEdit {
    /// The item it keeps, by its place in [`RevisionStore::outline`] read in the same order;
    /// `None` for a new item.
    pub item: Option<usize>,
    /// The page a new item goes to, by its index in [`RevisionStore::pages`]; an item kept keeps
    /// its own destination.
    pub page: Option<usize>,
    /// Its title.
    pub title: String,
    /// Its nesting, from 0; at most one more than the item before it.
    pub depth: u32,
    /// Whether it shows its children.
    pub open: bool,
}

/// An item to write, with its children.
struct Node<'e> {
    edit: &'e OutlineEdit,
    kids: Vec<Node<'e>>,
}

impl RevisionStore {
    /// Makes `items` the document's outline in the open transaction; none leaves it empty. Items
    /// left out are deleted with their children, unless `items` keeps those.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::StructurePlan`] for an item kept twice or
    /// past the outline, a new item without a page or past the last, a depth that skips a level
    /// or passes the nesting limit, and [`WriteError::ObjectNumbers`].
    pub fn set_outline(&mut self, doc: &Document, items: &[OutlineEdit]) -> Result<(), CoreError> {
        self.transaction_open()?;
        let plan = || CoreError::Write(WriteError::StructurePlan);
        let existing = flattened(self.outline(doc));
        let pages: Vec<ObjectId> = self.pages(doc).iter().map(|page| page.id).collect();
        let mut kept = vec![false; existing.len()];
        let mut depth = 0u32;
        for (index, edit) in items.iter().enumerate() {
            let deeper = if index == 0 {
                0
            } else {
                depth.saturating_add(1)
            };
            if edit.depth > deeper || edit.depth >= doc.limits().max_nesting {
                return Err(plan());
            }
            depth = edit.depth;
            match edit.item {
                Some(item) => {
                    let slot = kept.get_mut(item).ok_or_else(plan)?;
                    if std::mem::replace(slot, true) {
                        return Err(plan());
                    }
                }
                None => {
                    edit.page
                        .and_then(|page| pages.get(page))
                        .ok_or_else(plan)?;
                }
            }
        }
        let (root, catalog_id, mut catalog) = {
            let scope = self.scope(doc);
            let catalog_id = doc
                .model()
                .trailer
                .get(b"Root")
                .and_then(Object::as_reference)
                .map_err(|_| CoreError::Internal {
                    context: "a document without /Root",
                })?;
            let catalog = self.dictionary(doc, catalog_id)?;
            let root = catalog
                .get(b"Outlines")
                .ok()
                .and_then(|outlines| outlines.as_reference().ok());
            let outlines = scope.get_dict(&catalog, b"Outlines").cloned();
            ((root, outlines), catalog_id, catalog)
        };
        let (held, outlines) = root;
        if items.is_empty() && outlines.is_none() {
            return Ok(());
        }
        let root = match held {
            Some(id) => id,
            None => self.allocate()?.0,
        };
        let nodes = tree(items, &mut 0, 0);
        let (span, showing) = self.write_items(doc, &existing, &pages, root, &nodes)?;
        let mut outlines = outlines.unwrap_or_default();
        for key in [&b"First"[..], b"Last", b"Count"] {
            outlines.remove(key);
        }
        if let Some((first, last)) = span {
            outlines.set("Type", "Outlines");
            outlines.set("First", first);
            outlines.set("Last", last);
            outlines.set("Count", showing);
        }
        self.put_changed(doc, root, outlines)?;
        if held.is_none() {
            catalog.set("Outlines", root);
            self.put(catalog_id, Object::Dictionary(catalog))?;
        }
        Ok(())
    }

    /// Writes `nodes` as the items under `parent`; their first and last, and how many show.
    fn write_items(
        &mut self,
        doc: &Document,
        existing: &[ObjectId],
        pages: &[ObjectId],
        parent: ObjectId,
        nodes: &[Node<'_>],
    ) -> Result<(Option<(ObjectId, ObjectId)>, i64), CoreError> {
        let mut ids = Vec::with_capacity(nodes.len());
        for node in nodes {
            ids.push(match node.edit.item.and_then(|item| existing.get(item)) {
                Some(id) => *id,
                None => self.allocate()?.0,
            });
        }
        let mut showing = 0i64;
        for (index, (node, id)) in nodes.iter().zip(&ids).enumerate() {
            let (span, below) = self.write_items(doc, existing, pages, *id, &node.kids)?;
            let edit = node.edit;
            let mut dict = match edit.item {
                Some(_) => self.dictionary(doc, *id)?,
                None => {
                    let page = edit
                        .page
                        .and_then(|page| pages.get(page))
                        .ok_or(CoreError::Write(WriteError::StructurePlan))?;
                    let mut dict = Dictionary::new();
                    dict.set(
                        "Dest",
                        vec![Object::Reference(*page), Object::Name(b"Fit".to_vec())],
                    );
                    dict
                }
            };
            let same_title = dict
                .get(b"Title")
                .ok()
                .and_then(|title| title.as_str().ok())
                .is_some_and(|title| text_string::decode(title) == edit.title);
            if !same_title {
                dict.set(
                    "Title",
                    Object::String(text_string::encode(&edit.title), StringFormat::Literal),
                );
            }
            dict.set("Parent", parent);
            for key in [&b"Prev"[..], b"Next", b"First", b"Last", b"Count"] {
                dict.remove(key);
            }
            if let Some(previous) = index.checked_sub(1).and_then(|at| ids.get(at)) {
                dict.set("Prev", *previous);
            }
            if let Some(next) = ids.get(index.saturating_add(1)) {
                dict.set("Next", *next);
            }
            if let Some((first, last)) = span {
                dict.set("First", first);
                dict.set("Last", last);
                dict.set(
                    "Count",
                    if edit.open {
                        below
                    } else {
                        below.saturating_neg()
                    },
                );
            }
            self.put_changed(doc, *id, dict)?;
            showing = showing
                .saturating_add(1)
                .saturating_add(if edit.open { below } else { 0 });
        }
        Ok((ids.first().copied().zip(ids.last().copied()), showing))
    }

    /// Puts `dict` as `id`'s new version unless that is what `id` already is.
    pub(crate) fn put_changed(
        &mut self,
        doc: &Document,
        id: ObjectId,
        dict: Dictionary,
    ) -> Result<(), CoreError> {
        if self.scope(doc).object(id) == Some(&Object::Dictionary(dict.clone())) {
            return Ok(());
        }
        self.put(id, Object::Dictionary(dict))
    }
}

/// The objects of the outline's items in reading order.
fn flattened(outline: &[OutlineItem]) -> Vec<ObjectId> {
    let mut out = Vec::new();
    let mut stack: Vec<&OutlineItem> = outline.iter().rev().collect();
    while let Some(item) = stack.pop() {
        out.push(item.id);
        stack.extend(item.children.iter().rev());
    }
    out
}

/// The items of `edits` from `*next` on at `depth`, with their children; `*next` ends past them.
fn tree<'e>(edits: &'e [OutlineEdit], next: &mut usize, depth: u32) -> Vec<Node<'e>> {
    let mut nodes = Vec::new();
    while let Some(edit) = edits.get(*next).filter(|edit| edit.depth == depth) {
        *next = next.saturating_add(1);
        let kids = tree(edits, next, depth.saturating_add(1));
        nodes.push(Node { edit, kids });
    }
    nodes
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::{Object, dictionary};

    use super::OutlineEdit;
    use crate::revision::RevisionStore;
    use crate::{CoreError, Document, OpenOptions, Source, WriteError, open};

    /// Three pages and an outline: "Bir" (an integer destination, red, bold) with the child
    /// "Bir.1", then "İki".
    fn outlined() -> Document {
        let mut doc = crate::structure::tests::doc_with(vec![dictionary! {}; 3], dictionary! {});
        let ids: Vec<_> = doc.page_iter().collect();
        let root = doc.new_object_id();
        let one = doc.new_object_id();
        let child = doc.new_object_id();
        let two = doc.new_object_id();
        doc.objects.insert(
            child,
            Object::Dictionary(dictionary! {
                "Title" => Object::string_literal("Bir.1"), "Parent" => one,
                "Dest" => vec![ids[1].into(), "Fit".into()],
            }),
        );
        doc.objects.insert(
            one,
            Object::Dictionary(dictionary! {
                "Title" => Object::string_literal("Bir"), "Parent" => root,
                "Dest" => vec![0.into(), "Fit".into()], "C" => vec![1.into(), 0.into(), 0.into()],
                "F" => 2, "First" => child, "Last" => child, "Count" => 1, "Next" => two,
            }),
        );
        doc.objects.insert(
            two,
            Object::Dictionary(dictionary! {
                "Title" => Object::String(crate::text_string::encode("İki"), lopdf::StringFormat::Literal),
                "Parent" => root, "Prev" => one, "Dest" => vec![ids[2].into(), "Fit".into()],
            }),
        );
        doc.objects.insert(
            root,
            Object::Dictionary(
                dictionary! { "Type" => "Outlines", "First" => one, "Last" => two, "Count" => 3 },
            ),
        );
        let catalog = doc.trailer.get(b"Root").unwrap().as_reference().unwrap();
        doc.get_dictionary_mut(catalog)
            .unwrap()
            .set("Outlines", root);
        let mut bytes = Vec::new();
        doc.save_to(&mut bytes).unwrap();
        open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap()
    }

    fn edit(item: Option<usize>, page: Option<usize>, title: &str, depth: u32) -> OutlineEdit {
        OutlineEdit {
            item,
            page,
            title: title.to_owned(),
            depth,
            open: true,
        }
    }

    /// The outline as titles with their depths and pages, after `items` and saving.
    fn saved(doc: &Document, items: &[OutlineEdit]) -> Vec<(String, u32, Option<u32>)> {
        let mut store = RevisionStore::new(doc);
        store.begin().unwrap();
        store.set_outline(doc, items).unwrap();
        store.commit().unwrap();
        let bytes = store.incremental_update(doc).unwrap();
        assert!(bytes.starts_with(doc.source().bytes()));
        let again = open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap();
        let mut out = Vec::new();
        let mut stack: Vec<(u32, &crate::structure::OutlineItem)> = again
            .structure()
            .outline
            .iter()
            .rev()
            .map(|item| (0, item))
            .collect();
        while let Some((depth, item)) = stack.pop() {
            out.push((item.title.clone(), depth, item.page));
            stack.extend(item.children.iter().rev().map(|child| (depth + 1, child)));
        }
        out
    }

    #[test]
    fn rename_add_nest_reorder_and_delete() {
        let doc = outlined();
        // Renamed, a new item nested under it, "İki" moved first, "Bir.1" deleted.
        let result = saved(
            &doc,
            &[
                edit(Some(2), None, "İki", 0),
                edit(Some(0), None, "Birinci bölüm", 0),
                edit(None, Some(1), "Yeni", 1),
            ],
        );
        assert_eq!(
            result,
            [
                ("İki".to_owned(), 0, Some(2)),
                ("Birinci bölüm".to_owned(), 0, Some(0)),
                ("Yeni".to_owned(), 1, Some(1)),
            ]
        );
    }

    #[test]
    fn a_kept_item_keeps_its_destination_colour_and_style_and_unchanged_items_stay() {
        let doc = outlined();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let same = [
            edit(Some(0), None, "Bir", 0),
            edit(Some(1), None, "Bir.1", 1),
            edit(Some(2), None, "İki", 0),
        ];
        store.set_outline(&doc, &same).unwrap();
        // Nothing changed: nothing is written.
        assert_eq!(store.commit().unwrap(), 0);
        store.begin().unwrap();
        store
            .set_outline(
                &doc,
                &[edit(Some(0), None, "Bir", 0), edit(Some(2), None, "İki", 0)],
            )
            .unwrap();
        store.commit().unwrap();
        let first = store.outline(&doc)[0].id;
        let dict = store.dictionary(&doc, first).unwrap();
        // The integer destination stays an integer.
        assert_eq!(
            dict.get(b"Dest").unwrap().as_array().unwrap()[0],
            Object::Integer(0)
        );
        assert!(dict.get(b"C").is_ok() && dict.get(b"F").is_ok());
        assert!(dict.get(b"First").is_err() && dict.get(b"Count").is_err());
        assert_eq!(store.outline(&doc).len(), 2);
    }

    #[test]
    fn everything_deleted_and_an_outline_made_from_none() {
        let doc = outlined();
        assert!(saved(&doc, &[]).is_empty());
        let plain = crate::structure::tests::doc_with(vec![dictionary! {}; 2], dictionary! {});
        let mut bytes = Vec::new();
        plain.clone().save_to(&mut bytes).unwrap();
        let plain = open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap();
        assert_eq!(
            saved(&plain, &[edit(None, Some(1), "Ek", 0)]),
            [("Ek".to_owned(), 0, Some(1))]
        );
    }

    #[test]
    fn plans_that_cannot_apply_are_refused() {
        let doc = outlined();
        for items in [
            vec![edit(Some(0), None, "a", 1)],
            vec![edit(Some(0), None, "a", 0), edit(Some(0), None, "b", 0)],
            vec![edit(Some(9), None, "a", 0)],
            vec![edit(None, None, "a", 0)],
            vec![edit(None, Some(3), "a", 0)],
            vec![edit(None, Some(0), "a", 0), edit(None, Some(0), "b", 2)],
        ] {
            let mut store = RevisionStore::new(&doc);
            store.begin().unwrap();
            assert!(
                matches!(
                    store.set_outline(&doc, &items),
                    Err(CoreError::Write(WriteError::StructurePlan))
                ),
                "{items:?}"
            );
        }
    }
}
