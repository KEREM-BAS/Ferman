//! The page tree inside a transaction of a [`RevisionStore`] (M4 plan, W1, decisions 2 and 3).
//!
//! [`arrange_pages`](RevisionStore::arrange_pages) is what moves, deletes and inserts pages: it
//! takes the whole new order and edits as little as gives it. Pages that keep their place keep
//! their object; of a sound tree only the `/Pages` nodes whose `/Kids` or `/Count` change are
//! written, and a page that leaves its node takes its inherited `/Resources`, boxes and `/Rotate`
//! with it. A tree that is not sound (shared nodes, a cycle, a wrong `/Count` or `/Parent`, a kid
//! that is neither page nor node) is rebuilt flat under its root from the pages the app shows.
//!
//! Page labels travel with their pages, integer destinations follow them, and every reference to
//! a deleted page becomes null. A deleted page's own object stays in the file until a full rewrite
//! (question 5 of the M4 plan).
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet};

use lopdf::{Dictionary, Object, ObjectId, StringFormat};

use crate::revision::RevisionStore;
use crate::structure::{LETTER, LabelRange, LabelStyle, Scope, inherited_entry, label_ranges};
use crate::write::{ObjectRef, Value};
use crate::{CoreError, Document, WriteError, text_string};

/// The attributes a page inherits from its `/Pages` ancestors, the media box before the crop box
/// that falls back to it.
const INHERITED: [&[u8]; 4] = [b"MediaBox", b"CropBox", b"Resources", b"Rotate"];

/// How deep a sound page tree may go; `structure`'s walk stops there too.
const DEPTH: usize = 256;

/// The fit names of a destination (ISO 32000-2 §12.3.2.2).
const FITS: [&[u8]; 8] = [
    b"XYZ", b"Fit", b"FitH", b"FitV", b"FitR", b"FitB", b"FitBH", b"FitBV",
];

/// The annotation entries that hold pairs of page coordinates.
const POINTS: [&[u8]; 5] = [b"Rect", b"QuadPoints", b"Vertices", b"L", b"CL"];

/// A place in the new order of [`RevisionStore::arrange_pages`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PageSlot {
    /// The page now at this index.
    Page(usize),
    /// A page object made in this transaction.
    New(ObjectRef),
}

impl RevisionStore {
    /// Makes `order` the document's pages in the open transaction: a page it does not name is
    /// deleted, one it names elsewhere is moved. An order that changes nothing writes nothing.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::NoSuchPage`] for an index the document does
    /// not have, and [`WriteError::PagePlan`] for an empty order or a page named twice.
    pub fn arrange_pages(&mut self, doc: &Document, order: &[PageSlot]) -> Result<(), CoreError> {
        self.transaction_open()?;
        let queued = self.arranged(doc, order)?;
        for (id, object) in queued {
            self.put(id, object)?;
        }
        Ok(())
    }

    /// What [`arrange_pages`](Self::arrange_pages) writes.
    fn arranged(
        &self,
        doc: &Document,
        order: &[PageSlot],
    ) -> Result<BTreeMap<ObjectId, Object>, CoreError> {
        let plan = || CoreError::Write(WriteError::PagePlan);
        let ids: Vec<ObjectId> = self.pages(doc).iter().map(|page| page.id).collect();
        let mut named = BTreeSet::new();
        let mut wanted = Vec::with_capacity(order.len());
        for slot in order {
            match slot {
                PageSlot::Page(index) => {
                    if !named.insert(*index) {
                        return Err(plan());
                    }
                    let id = ids
                        .get(*index)
                        .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
                    wanted.push(*id);
                }
                PageSlot::New(page) => wanted.push(page.0),
            }
        }
        if wanted.is_empty() {
            return Err(plan());
        }
        if wanted == ids {
            return Ok(BTreeMap::new());
        }
        let scope = self.scope(doc);
        let root = scope
            .catalog()
            .and_then(|catalog| catalog.get(b"Pages").ok())
            .and_then(|root| root.as_reference().ok())
            .ok_or(CoreError::Write(WriteError::NoSuchPage))?;

        let sound = Tree::read(&scope, root, &ids);
        let stay = if sound.is_some() {
            stationary(order)
        } else {
            BTreeSet::new()
        };
        let mut tree = sound.unwrap_or_else(|| Tree::flat(root));
        let parents = tree.parent.clone();
        tree.place(&wanted, &stay).ok_or_else(plan)?;

        let mut queued = BTreeMap::new();
        tree.write_nodes(&scope, &mut queued);
        for id in &wanted {
            if parents.get(id) != tree.parent.get(id) {
                queued.insert(*id, Object::Dictionary(tree.placed(&scope, *id)?));
            }
        }
        write_labels(doc, &scope, ids.len(), order, &mut queued);
        follow(self, doc, &scope, &ids, order, &wanted, &mut queued);
        Ok(queued)
    }

    /// Adds a blank page of `width` by `height` points in the open transaction, for
    /// [`arrange_pages`](Self::arrange_pages) to place.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`] and [`WriteError::ObjectNumbers`].
    pub fn blank_page(
        &mut self,
        doc: &Document,
        width: f32,
        height: f32,
    ) -> Result<ObjectRef, CoreError> {
        let media = [0.0, 0.0, width, height]
            .into_iter()
            .map(Value::Real)
            .collect();
        self.add_object(
            doc,
            Value::Dictionary(vec![
                (b"Type".to_vec(), Value::Name(b"Page".to_vec())),
                (b"MediaBox".to_vec(), Value::Array(media)),
                (b"Resources".to_vec(), Value::Dictionary(Vec::new())),
            ]),
        )
    }

    /// Adds a copy of `page` in the open transaction, for
    /// [`arrange_pages`](Self::arrange_pages) to place. It draws from the same streams, which a
    /// later edit copies for the page it edits. Its annotations are copies of their own; a form
    /// field's widget stays on the original, and the copy has no place in the structure tree.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::NoSuchPage`] and
    /// [`WriteError::ObjectNumbers`].
    pub fn copy_page(&mut self, doc: &Document, page: ObjectRef) -> Result<ObjectRef, CoreError> {
        self.transaction_open()?;
        let source = page.0;
        let copy = self.allocate()?;
        let (mut dict, annotations) = {
            let scope = self.scope(doc);
            let original = scope
                .dictionary(source)
                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
            let mut dict = original.clone();
            for key in INHERITED {
                if !dict.has(key)
                    && let Some(value) = inherited_entry(&scope, original, key)
                {
                    dict.set(key.to_vec(), value.clone());
                }
            }
            for key in [&b"Parent"[..], b"StructParents", b"B", b"Annots"] {
                dict.remove(key);
            }
            let annotations = scope
                .get_array(original, b"Annots")
                .map(|items| annotation_copies(&scope, items))
                .unwrap_or_default();
            (dict, annotations)
        };
        let mut copies = BTreeMap::new();
        let mut numbered = Vec::with_capacity(annotations.len());
        for (from, annotation) in annotations {
            let new = self.allocate()?;
            if let Some(from) = from {
                copies.insert(from, new.0);
            }
            numbered.push((new, annotation));
        }
        let mut items = Vec::with_capacity(numbered.len());
        for (new, mut annotation) in numbered {
            annotation.set("P", copy.0);
            for key in [&b"Popup"[..], b"Parent", b"IRT"] {
                let target = annotation.get(key).ok().map(Object::as_reference);
                match target.map(|target| target.ok().and_then(|id| copies.get(&id))) {
                    Some(Some(id)) => annotation.set(key.to_vec(), *id),
                    Some(None) => {
                        annotation.remove(key);
                    }
                    None => {}
                }
            }
            self.put(new.0, Object::Dictionary(annotation))?;
            items.push(Object::Reference(new.0));
        }
        if !items.is_empty() {
            dict.set("Annots", items);
        }
        self.put(copy.0, Object::Dictionary(dict))?;
        Ok(copy)
    }

    /// Draws the content of `page` at `scale`, then shifted by `dx` and `dy` in the open
    /// transaction, through two new streams around its `/Contents`; its annotations' and boxes'
    /// coordinates follow.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::NoSuchPage`] and
    /// [`WriteError::ObjectNumbers`].
    // shortcut: destinations to the page keep their coordinates, so they land a little off; map
    // them when a scaled page's bookmarks prove wrong.
    pub fn scale_page(
        &mut self,
        doc: &Document,
        page: ObjectRef,
        scale: f32,
        dx: f32,
        dy: f32,
    ) -> Result<(), CoreError> {
        self.transaction_open()?;
        let page = page.0;
        let mut dict = self.dictionary(doc, page)?;
        let contents = self.contents(doc, page);
        if !contents.is_empty() {
            let open = format!("q {scale} 0 0 {scale} {dx} {dy} cm\n").into_bytes();
            let close = b"\nQ\n".to_vec();
            let mut streams = Vec::with_capacity(contents.len().saturating_add(2));
            let stream = |data| Value::Stream {
                dict: Vec::new(),
                data,
            };
            streams.push(Object::Reference(self.add_object(doc, stream(open))?.0));
            streams.extend(contents.into_iter().map(Object::Reference));
            streams.push(Object::Reference(self.add_object(doc, stream(close))?.0));
            dict.set("Contents", streams);
        }
        let map = |x: f32, y: f32| (x * scale + dx, y * scale + dy);
        let mut queued = Vec::new();
        {
            let scope = self.scope(doc);
            for key in [&b"BleedBox"[..], b"TrimBox", b"ArtBox"] {
                if let Some(points) = scaled_points(&scope, dict.get(key).ok(), &map) {
                    dict.set(key.to_vec(), points);
                }
            }
            if let Some(items) = dict
                .get(b"Annots")
                .ok()
                .and_then(|items| scope.resolve(items))
                .and_then(|items| items.as_array().ok())
            {
                let mut scaled = Vec::with_capacity(items.len());
                for item in items {
                    match (item.as_reference().ok(), scope.dict(item)) {
                        (Some(id), Some(annotation)) => {
                            queued.push((id, scaled_annotation(&scope, annotation, &map)));
                            scaled.push(item.clone());
                        }
                        (None, Some(annotation)) => {
                            let annotation = scaled_annotation(&scope, annotation, &map);
                            scaled.push(Object::Dictionary(annotation));
                        }
                        _ => scaled.push(item.clone()),
                    }
                }
                dict.set("Annots", scaled);
            }
        }
        for (id, annotation) in queued {
            self.put(id, Object::Dictionary(annotation))?;
        }
        self.put(page, Object::Dictionary(dict))
    }

    /// The document's page label ranges as these revisions leave them, in page order.
    #[must_use]
    pub fn label_ranges(&self, doc: &Document) -> Vec<LabelRange> {
        label_ranges(&self.scope(doc))
    }

    /// Makes `ranges` the document's page labels in the open transaction; none removes them. Pages
    /// before the first range get no number.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], and [`WriteError::PagePlan`] for ranges out of order, past
    /// the last page or numbered from 0.
    pub fn set_label_ranges(
        &mut self,
        doc: &Document,
        ranges: &[LabelRange],
    ) -> Result<(), CoreError> {
        self.transaction_open()?;
        let count = self.pages(doc).len();
        let in_order = ranges.windows(2).all(|pair| match pair {
            [a, b] => a.start < b.start,
            _ => true,
        });
        let inside = ranges.iter().all(|range| {
            range.first >= 1 && usize::try_from(range.start).is_ok_and(|start| start < count)
        });
        if !in_order || !inside {
            return Err(CoreError::Write(WriteError::PagePlan));
        }
        let (id, catalog) = {
            let scope = self.scope(doc);
            let id = catalog_id(doc).ok_or(CoreError::Write(WriteError::NoSuchPage))?;
            let catalog = scope
                .dictionary(id)
                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
            (id, labelled(catalog.clone(), ranges))
        };
        self.put(id, Object::Dictionary(catalog))
    }

    /// Fails with no open transaction, before anything is read for a change that may write nothing.
    fn transaction_open(&self) -> Result<(), CoreError> {
        if self.in_transaction() {
            Ok(())
        } else {
            Err(CoreError::Write(WriteError::NoTransaction))
        }
    }
}

/// The catalog's object.
fn catalog_id(doc: &Document) -> Option<ObjectId> {
    doc.model().trailer.get(b"Root").ok()?.as_reference().ok()
}

/// `catalog` with `ranges` as its `/PageLabels`, a flat number tree.
fn labelled(mut catalog: Dictionary, ranges: &[LabelRange]) -> Dictionary {
    if ranges.is_empty() {
        catalog.remove(b"PageLabels");
        return catalog;
    }
    let mut numbers = Vec::with_capacity(ranges.len().saturating_mul(2).saturating_add(2));
    // The tree must start at the first page (ISO 32000-2 §12.4.2).
    if ranges.first().is_some_and(|range| range.start > 0) {
        numbers.push(Object::Integer(0));
        numbers.push(Object::Dictionary(Dictionary::new()));
    }
    for range in ranges {
        let mut entry = Dictionary::new();
        if let Some(name) = range.style.name() {
            entry.set("S", Object::Name(name.to_vec()));
        }
        if !range.prefix.is_empty() {
            entry.set(
                "P",
                Object::String(text_string::encode(&range.prefix), StringFormat::Literal),
            );
        }
        if range.first != 1 {
            entry.set("St", i64::from(range.first));
        }
        numbers.push(Object::Integer(i64::from(range.start)));
        numbers.push(Object::Dictionary(entry));
    }
    let mut tree = Dictionary::new();
    tree.set("Nums", numbers);
    catalog.set("PageLabels", tree);
    catalog
}

/// The ranges that give `labels` page by page: `(style, prefix, number)`.
fn compressed_labels(labels: &[(LabelStyle, String, u32)]) -> Vec<LabelRange> {
    let mut out: Vec<LabelRange> = Vec::new();
    let mut previous: Option<&(LabelStyle, String, u32)> = None;
    for (index, label) in labels.iter().enumerate() {
        let continues = previous.is_some_and(|before| {
            before.0 == label.0
                && before.1 == label.1
                && (label.0 == LabelStyle::None || before.2.checked_add(1) == Some(label.2))
        });
        if !continues {
            out.push(LabelRange {
                start: u32::try_from(index).unwrap_or(u32::MAX),
                style: label.0,
                prefix: label.1.clone(),
                first: label.2,
            });
        }
        previous = Some(label);
    }
    out
}

/// Each page's label in `order`: an old page keeps its own, whatever moves around it, and a new
/// page continues the range before it. A first new page starts the first page's range over.
fn labels_in_order(ranges: &[LabelRange], order: &[PageSlot]) -> Vec<(LabelStyle, String, u32)> {
    let label = |index: usize| {
        let index = u32::try_from(index).unwrap_or(u32::MAX);
        ranges
            .iter()
            .rev()
            .find(|range| range.start <= index)
            .map_or((LabelStyle::None, String::new(), 1), |range| {
                let number = range
                    .first
                    .saturating_add(index.saturating_sub(range.start));
                (range.style, range.prefix.clone(), number)
            })
    };
    let mut out: Vec<(LabelStyle, String, u32)> = Vec::with_capacity(order.len());
    for slot in order {
        let next = match slot {
            PageSlot::Page(index) => label(*index),
            PageSlot::New(_) => match out.last() {
                Some((style, prefix, number)) => (*style, prefix.clone(), number.saturating_add(1)),
                None => {
                    let (style, prefix, _) = label(0);
                    (style, prefix, 1)
                }
            },
        };
        out.push(next);
    }
    out
}

/// Queues the catalog with the labels of `order`, when the document has labels and they change.
fn write_labels(
    doc: &Document,
    scope: &Scope<'_>,
    count: usize,
    order: &[PageSlot],
    queued: &mut BTreeMap<ObjectId, Object>,
) {
    let ranges = label_ranges(scope);
    if ranges.is_empty() {
        return;
    }
    let same: Vec<PageSlot> = (0..count).map(PageSlot::Page).collect();
    let before = compressed_labels(&labels_in_order(&ranges, &same));
    let after = compressed_labels(&labels_in_order(&ranges, order));
    if before == after {
        return;
    }
    if let Some(id) = catalog_id(doc)
        && let Some(catalog) = scope.dictionary(id)
    {
        queued.insert(id, Object::Dictionary(labelled(catalog.clone(), &after)));
    }
}

/// The positions in `order` of the longest run of old pages already in order: these need not move.
fn stationary(order: &[PageSlot]) -> BTreeSet<usize> {
    let old: Vec<(usize, usize)> = order
        .iter()
        .enumerate()
        .filter_map(|(position, slot)| match slot {
            PageSlot::Page(index) => Some((position, *index)),
            PageSlot::New(_) => None,
        })
        .collect();
    // Patience: `tails[n]` ends the best run of length n + 1 with the smallest index.
    let mut tails: Vec<(usize, usize)> = Vec::new();
    let mut links: Vec<Option<usize>> = Vec::with_capacity(old.len());
    for (at, (_, index)) in old.iter().enumerate() {
        let length = tails.partition_point(|(_, tail)| tail < index);
        links.push(
            length
                .checked_sub(1)
                .and_then(|before| tails.get(before))
                .map(|(entry, _)| *entry),
        );
        match tails.get_mut(length) {
            Some(tail) => *tail = (at, *index),
            None => tails.push((at, *index)),
        }
    }
    let mut out = BTreeSet::new();
    let mut next = tails.last().map(|(entry, _)| *entry);
    while let Some(entry) = next {
        if let Some((position, _)) = old.get(entry) {
            out.insert(*position);
        }
        next = links.get(entry).copied().flatten();
    }
    out
}

/// A page tree in memory, each kid under one parent.
struct Tree {
    root: ObjectId,
    /// The kids of each `/Pages` node.
    kids: BTreeMap<ObjectId, Vec<ObjectId>>,
    /// The kids as read; a node without an entry was not read.
    kids_before: BTreeMap<ObjectId, Vec<ObjectId>>,
    /// The nodes, each before its kids.
    walk: Vec<ObjectId>,
    /// The parent of each page and node.
    parent: BTreeMap<ObjectId, ObjectId>,
}

impl Tree {
    /// An empty tree of the root alone, whatever the root's kids are in the file.
    fn flat(root: ObjectId) -> Self {
        Self {
            root,
            kids: BTreeMap::from([(root, Vec::new())]),
            kids_before: BTreeMap::new(),
            walk: vec![root],
            parent: BTreeMap::new(),
        }
    }

    /// The tree under `root`, or `None` unless it is sound and gives the pages `pages`.
    fn read(scope: &Scope<'_>, root: ObjectId, pages: &[ObjectId]) -> Option<Self> {
        let mut tree = Self {
            root,
            kids: BTreeMap::new(),
            kids_before: BTreeMap::new(),
            walk: Vec::new(),
            parent: BTreeMap::new(),
        };
        let mut found = Vec::with_capacity(pages.len());
        tree.visit(scope, root, 0, &mut found)?;
        tree.kids_before.clone_from(&tree.kids);
        (found == pages).then_some(tree)
    }

    /// Reads node `id`; returns how many pages it holds. `None` for anything unsound. Each object
    /// is entered once, so a cycle or a shared node ends the walk.
    fn visit(
        &mut self,
        scope: &Scope<'_>,
        id: ObjectId,
        depth: usize,
        found: &mut Vec<ObjectId>,
    ) -> Option<i64> {
        if depth >= DEPTH || self.kids.contains_key(&id) {
            return None;
        }
        self.walk.push(id);
        let node = scope.dictionary(id)?;
        let items = scope.get_array(node, b"Kids")?;
        let mut kids = Vec::with_capacity(items.len());
        let mut count = 0_i64;
        self.kids.insert(id, Vec::new());
        for item in items {
            let kid = item.as_reference().ok()?;
            let dict = scope.dictionary(kid)?;
            if self.parent.insert(kid, id).is_some()
                || dict.get(b"Parent").ok()?.as_reference().ok()? != id
            {
                return None;
            }
            kids.push(kid);
            count = count.checked_add(match dict.get_type().ok()? {
                b"Page" => {
                    found.push(kid);
                    1
                }
                b"Pages" => self.visit(scope, kid, depth.saturating_add(1), found)?,
                _ => return None,
            })?;
        }
        self.kids.insert(id, kids);
        (scope.get_int(node, b"Count")? == count).then_some(count)
    }

    /// Takes out every page but those at the positions `stay` of `wanted`, and puts the others
    /// in place, each right after the page before it. `None` if a place cannot be found.
    fn place(&mut self, wanted: &[ObjectId], stay: &BTreeSet<usize>) -> Option<()> {
        let nodes: BTreeSet<ObjectId> = self.kids.keys().copied().collect();
        let staying: BTreeSet<ObjectId> = stay
            .iter()
            .filter_map(|position| wanted.get(*position).copied())
            .collect();
        for kids in self.kids.values_mut() {
            kids.retain(|kid| nodes.contains(kid) || staying.contains(kid));
        }
        let first_staying = stay
            .first()
            .and_then(|position| wanted.get(*position))
            .copied();
        let mut spot: Option<(ObjectId, usize)> = None;
        let mut previous = None;
        for (position, page) in wanted.iter().enumerate() {
            if stay.contains(&position) {
                spot = None;
            } else {
                let (node, at) = match spot {
                    Some(spot) => spot,
                    None => match (previous, first_staying) {
                        (Some(previous), _) => {
                            let node = *self.parent.get(&previous)?;
                            let at = self.kid_position(node, previous)?;
                            (node, at.saturating_add(1))
                        }
                        (None, Some(first)) => {
                            let node = *self.parent.get(&first)?;
                            (node, self.kid_position(node, first)?)
                        }
                        (None, None) => (self.root, 0),
                    },
                };
                self.kids.get_mut(&node)?.insert(at, *page);
                self.parent.insert(*page, node);
                spot = Some((node, at.saturating_add(1)));
            }
            previous = Some(*page);
        }
        Some(())
    }

    fn kid_position(&self, node: ObjectId, kid: ObjectId) -> Option<usize> {
        self.kids.get(&node)?.iter().position(|item| *item == kid)
    }

    /// Queues the nodes whose `/Kids` or `/Count` change. A node the change emptied leaves its
    /// parent; one that was empty already stays.
    fn write_nodes(&mut self, scope: &Scope<'_>, queued: &mut BTreeMap<ObjectId, Object>) {
        let mut counts: BTreeMap<ObjectId, i64> = BTreeMap::new();
        for node in self.walk.iter().rev() {
            let Some(kids) = self.kids.get(node) else {
                continue;
            };
            let count = kids.iter().fold(0_i64, |sum, kid| {
                sum.saturating_add(counts.get(kid).copied().unwrap_or(1))
            });
            counts.insert(*node, count);
            let emptied = count == 0
                && *node != self.root
                && self
                    .kids_before
                    .get(node)
                    .is_some_and(|before| !before.is_empty());
            if emptied {
                if let Some(parent) = self.parent.get(node).copied()
                    && let Some(siblings) = self.kids.get_mut(&parent)
                {
                    siblings.retain(|kid| kid != node);
                }
                continue;
            }
            let same = self.kids_before.get(node) == Some(kids);
            if same {
                let held = scope
                    .dictionary(*node)
                    .and_then(|dict| scope.get_int(dict, b"Count"));
                if held == Some(count) {
                    continue;
                }
            }
            if let Some(dict) = scope.dictionary(*node) {
                let mut dict = dict.clone();
                dict.set("Type", "Pages");
                let items: Vec<Object> = kids.iter().copied().map(Object::Reference).collect();
                dict.set("Kids", items);
                dict.set("Count", count);
                queued.insert(*node, Object::Dictionary(dict));
            }
        }
    }

    /// Whether `node` or an ancestor holds `key`.
    fn chain_has(&self, scope: &Scope<'_>, node: ObjectId, key: &[u8]) -> bool {
        let mut next = Some(node);
        for _ in 0..=DEPTH {
            let Some(id) = next else {
                return false;
            };
            if scope.dictionary(id).is_some_and(|dict| dict.has(key)) {
                return true;
            }
            next = self.parent.get(&id).copied();
        }
        false
    }

    /// Page `id`'s dictionary under its new parent, drawing as it did: what it inherited is its
    /// own now, and what the new parent would give it is overridden with the default it had.
    fn placed(&self, scope: &Scope<'_>, id: ObjectId) -> Result<Dictionary, CoreError> {
        let original = scope
            .dictionary(id)
            .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
        let node = self
            .parent
            .get(&id)
            .copied()
            .ok_or(CoreError::Write(WriteError::PagePlan))?;
        let mut dict = original.clone();
        for key in INHERITED {
            if dict.has(key) {
                continue;
            }
            if let Some(value) = inherited_entry(scope, original, key) {
                dict.set(key.to_vec(), value.clone());
            } else if self.chain_has(scope, node, key) {
                let letter = || {
                    let values = [LETTER.left, LETTER.bottom, LETTER.right, LETTER.top];
                    Object::Array(values.into_iter().map(Object::Real).collect())
                };
                let default = match key {
                    b"Rotate" => Object::Integer(0),
                    b"Resources" => Object::Dictionary(Dictionary::new()),
                    b"CropBox" => dict.get(b"MediaBox").cloned().unwrap_or_else(|_| letter()),
                    _ => letter(),
                };
                dict.set(key.to_vec(), default);
            }
        }
        dict.set("Parent", node);
        Ok(dict)
    }
}

/// What a page's references become: integer destinations follow their page, and destinations and
/// other references to a deleted page become null.
struct Followed {
    deleted: BTreeSet<ObjectId>,
    /// The new index of each old page; `None` once deleted.
    moved: Vec<Option<i64>>,
    nesting: u32,
}

impl Followed {
    /// `object` as it must become, or `None` if it stays.
    fn of(&self, object: &Object, depth: u32) -> Option<Object> {
        if depth >= self.nesting {
            return None;
        }
        let depth = depth.saturating_add(1);
        match object {
            Object::Reference(id) => self.deleted.contains(id).then_some(Object::Null),
            Object::Array(items) => {
                let mut out: Option<Vec<Object>> = self.destination(items);
                for (index, item) in items.iter().enumerate() {
                    if let Some(new) = self.of(item, depth) {
                        let target = out.get_or_insert_with(|| items.clone()).get_mut(index);
                        if let Some(target) = target {
                            *target = new;
                        }
                    }
                }
                out.map(Object::Array)
            }
            Object::Dictionary(dict) => self.of_dictionary(dict, depth).map(Object::Dictionary),
            Object::Stream(stream) => self.of_dictionary(&stream.dict, depth).map(|dict| {
                let mut stream = stream.clone();
                stream.dict = dict;
                Object::Stream(stream)
            }),
            _ => None,
        }
    }

    /// `items` as a destination with its integer page changed. The shape names it: nothing else
    /// in a PDF starts with an integer and a fit.
    fn destination(&self, items: &[Object]) -> Option<Vec<Object>> {
        let [Object::Integer(page), Object::Name(fit), ..] = items else {
            return None;
        };
        if !FITS.contains(&fit.as_slice()) {
            return None;
        }
        let new = self.moved.get(usize::try_from(*page).ok()?)?;
        if *new == Some(*page) {
            return None;
        }
        let mut out = items.to_vec();
        if let Some(first) = out.first_mut() {
            *first = new.map_or(Object::Null, Object::Integer);
        }
        Some(out)
    }

    fn of_dictionary(&self, dict: &Dictionary, depth: u32) -> Option<Dictionary> {
        // Another file's page numbers are that file's.
        // shortcut: a remote destination held in an object of its own is read as this file's; look
        // at who names it if such a file appears.
        let remote = matches!(
            dict.get(b"S").ok().and_then(|kind| kind.as_name().ok()),
            Some(b"GoToR" | b"GoToE")
        );
        let mut out = None;
        for (key, value) in dict {
            if remote && key == b"D" {
                continue;
            }
            if let Some(new) = self.of(value, depth) {
                out.get_or_insert_with(|| dict.clone())
                    .set(key.clone(), new);
            }
        }
        out
    }
}

/// Queues every object whose references must follow the new order, over what is queued already.
// shortcut: a deleted page's widgets stay in /AcroForm /Fields, with no page; W3's form reader takes
// them out of the required count when it reads fields page by page.
fn follow(
    store: &RevisionStore,
    doc: &Document,
    scope: &Scope<'_>,
    ids: &[ObjectId],
    order: &[PageSlot],
    wanted: &[ObjectId],
    queued: &mut BTreeMap<ObjectId, Object>,
) {
    let kept: BTreeSet<ObjectId> = wanted.iter().copied().collect();
    let mut moved = vec![None; ids.len()];
    for (position, slot) in order.iter().enumerate() {
        if let PageSlot::Page(index) = slot
            && let Some(entry) = moved.get_mut(*index)
        {
            *entry = i64::try_from(position).ok();
        }
    }
    let followed = Followed {
        deleted: ids
            .iter()
            .copied()
            .filter(|id| !kept.contains(id))
            .collect(),
        moved,
        nesting: scope.limits.max_nesting,
    };
    let mut every: BTreeSet<ObjectId> = doc.model().objects.keys().copied().collect();
    every.extend(store.changed_ids());
    for id in every {
        if followed.deleted.contains(&id) {
            continue;
        }
        let Some(object) = queued.get(&id).or_else(|| scope.object(id)) else {
            continue;
        };
        // The tree is written already; what it held of a deleted page is its own business.
        if let Object::Dictionary(dict) = object
            && matches!(dict.get_type(), Ok(b"Pages"))
        {
            continue;
        }
        if let Some(new) = followed.of(object, 0) {
            queued.insert(id, new);
        }
    }
}

/// `items`, a page's annotations, as what a copy of the page gets: each annotation's object, when
/// it has one, and a dictionary without what ties it to that page. Widgets stay with their field.
fn annotation_copies(scope: &Scope<'_>, items: &[Object]) -> Vec<(Option<ObjectId>, Dictionary)> {
    items
        .iter()
        .filter_map(|item| {
            let annotation = scope.dict(item)?;
            if scope.get_name(annotation, b"Subtype") == Some(b"Widget") {
                return None;
            }
            let mut copy = annotation.clone();
            for key in [&b"StructParent"[..], b"NM"] {
                copy.remove(key);
            }
            Some((item.as_reference().ok(), copy))
        })
        .collect()
}

/// `dict` with the coordinates of its annotation entries mapped.
fn scaled_annotation(
    scope: &Scope<'_>,
    annotation: &Dictionary,
    map: &impl Fn(f32, f32) -> (f32, f32),
) -> Dictionary {
    let mut out = annotation.clone();
    for key in POINTS {
        if let Some(points) = scaled_points(scope, annotation.get(key).ok(), map) {
            out.set(key.to_vec(), points);
        }
    }
    if let Some(lists) = scope.get_array(annotation, b"InkList") {
        let scaled: Vec<Object> = lists
            .iter()
            .map(|list| scaled_points(scope, Some(list), map).unwrap_or_else(|| list.clone()))
            .collect();
        out.set("InkList", scaled);
    }
    out
}

/// An array of x and y pairs with `map` applied, or `None` if `points` is not one.
fn scaled_points(
    scope: &Scope<'_>,
    points: Option<&Object>,
    map: &impl Fn(f32, f32) -> (f32, f32),
) -> Option<Object> {
    let items = scope.resolve(points?)?.as_array().ok()?;
    let mut out = Vec::with_capacity(items.len());
    for pair in items.chunks(2) {
        let [x, y] = pair else {
            return None;
        };
        let x = scope.resolve(x).and_then(crate::structure::number)?;
        let y = scope.resolve(y).and_then(crate::structure::number)?;
        let (x, y) = map(x, y);
        out.push(Object::Real(x));
        out.push(Object::Real(y));
    }
    Some(Object::Array(out))
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::dictionary;

    use super::*;
    use crate::{OpenOptions, Source, open};

    const NODE_A: ObjectId = (2, 0);
    const NODE_B: ObjectId = (3, 0);

    fn opened(model: &mut lopdf::Document) -> Document {
        model.trailer.set("Root", (1, 0));
        let mut bytes = Vec::new();
        model.save_to(&mut bytes).unwrap();
        open(
            &Source::from_bytes(Arc::from(&bytes[..])),
            &OpenOptions::default(),
        )
        .unwrap()
    }

    /// Root over node A (pages 10, 11; rotated, with a box and resources) and node B (12, 13).
    fn nested() -> lopdf::Document {
        let mut model = lopdf::Document::with_version("1.7");
        let root = (4, 0);
        model.objects.insert(
            (1, 0),
            Object::Dictionary(dictionary! { "Type" => "Catalog", "Pages" => root }),
        );
        model.objects.insert(
            root,
            Object::Dictionary(dictionary! {
                "Type" => "Pages", "Count" => 4,
                "Kids" => vec![Object::Reference(NODE_A), Object::Reference(NODE_B)],
                "MediaBox" => vec![0.into(), 0.into(), 200.into(), 300.into()],
            }),
        );
        model.objects.insert(
            NODE_A,
            Object::Dictionary(dictionary! {
                "Type" => "Pages", "Count" => 2, "Parent" => root, "Rotate" => 90,
                "Kids" => vec![Object::Reference((10, 0)), Object::Reference((11, 0))],
                "Resources" => dictionary! { "A" => 1 },
            }),
        );
        model.objects.insert(
            NODE_B,
            Object::Dictionary(dictionary! {
                "Type" => "Pages", "Count" => 2, "Parent" => root,
                "Kids" => vec![Object::Reference((12, 0)), Object::Reference((13, 0))],
            }),
        );
        for (number, parent) in [(10, NODE_A), (11, NODE_A), (12, NODE_B), (13, NODE_B)] {
            model.objects.insert(
                (number, 0),
                Object::Dictionary(dictionary! { "Type" => "Page", "Parent" => parent }),
            );
        }
        model.max_id = 20;
        model
    }

    fn numbers(store: &RevisionStore, doc: &Document) -> Vec<u32> {
        store.pages(doc).iter().map(|page| page.id.0).collect()
    }

    fn slots(indices: &[usize]) -> Vec<PageSlot> {
        indices.iter().copied().map(PageSlot::Page).collect()
    }

    fn arrange(store: &mut RevisionStore, doc: &Document, indices: &[usize]) {
        store.begin().unwrap();
        store.arrange_pages(doc, &slots(indices)).unwrap();
        store.commit().unwrap();
    }

    /// The page tree under the catalog is what a reader needs: /Count and /Parent true everywhere.
    fn assert_sound(store: &RevisionStore, doc: &Document) {
        let scope = store.scope(doc);
        let root = scope
            .catalog()
            .unwrap()
            .get(b"Pages")
            .unwrap()
            .as_reference()
            .unwrap();
        let ids: Vec<ObjectId> = store.pages(doc).iter().map(|page| page.id).collect();
        assert!(Tree::read(&scope, root, &ids).is_some());
    }

    #[test]
    fn a_move_in_one_node_writes_that_node_alone() {
        let doc = opened(&mut nested());
        let mut store = RevisionStore::new(&doc);
        arrange(&mut store, &doc, &[1, 0, 2, 3]);
        assert_eq!(numbers(&store, &doc), [11, 10, 12, 13]);
        assert_sound(&store, &doc);
        let changed: Vec<ObjectId> = store.revisions()[0].ids().collect();
        assert_eq!(changed, [NODE_A]);
    }

    #[test]
    fn a_page_leaving_its_node_keeps_what_it_inherited() {
        let doc = opened(&mut nested());
        let before = store_page(&doc, &RevisionStore::new(&doc), 0);
        let mut store = RevisionStore::new(&doc);
        arrange(&mut store, &doc, &[1, 2, 0, 3]);
        assert_eq!(numbers(&store, &doc), [11, 12, 10, 13]);
        assert_sound(&store, &doc);
        let after = store_page(&doc, &store, 2);
        assert_eq!(after, before);
        let scope = store.scope(&doc);
        let page = scope.dictionary((10, 0)).unwrap();
        assert_eq!(page.get(b"Rotate").unwrap().as_i64().unwrap(), 90);
        assert_eq!(page.get(b"Parent").unwrap().as_reference().unwrap(), NODE_B);
        assert!(page.has(b"Resources"));
        // Untouched: the page that stayed and the root.
        let changed: Vec<ObjectId> = store.revisions()[0].ids().collect();
        assert_eq!(changed, [NODE_A, NODE_B, (10, 0)]);
    }

    /// A page's rotation and boxes as the structure gives them.
    fn store_page(
        doc: &Document,
        store: &RevisionStore,
        index: usize,
    ) -> (u16, (f32, f32), crate::structure::Rect) {
        let page = &store.pages(doc)[index];
        (page.rotation, page.size, page.media_box)
    }

    #[test]
    fn a_page_entering_a_node_does_not_take_up_its_attributes() {
        let doc = opened(&mut nested());
        let mut store = RevisionStore::new(&doc);
        let before = store_page(&doc, &store, 2);
        // Page 12, not rotated, goes into the node that rotates its pages.
        arrange(&mut store, &doc, &[2, 0, 1, 3]);
        assert_eq!(numbers(&store, &doc)[0], 12);
        assert_eq!(store_page(&doc, &store, 0), before);
        assert_sound(&store, &doc);
    }

    #[test]
    fn a_node_emptied_by_a_delete_leaves_its_parent_and_undo_brings_it_back() {
        let doc = opened(&mut nested());
        let mut store = RevisionStore::new(&doc);
        arrange(&mut store, &doc, &[2, 3]);
        assert_eq!(numbers(&store, &doc), [12, 13]);
        assert_sound(&store, &doc);
        let scope = store.scope(&doc);
        let root = scope.dictionary((4, 0)).unwrap();
        assert_eq!(scope.get_int(root, b"Count"), Some(2));
        assert_eq!(scope.get_array(root, b"Kids").unwrap().len(), 1);
        store.undo().unwrap();
        assert_eq!(numbers(&store, &doc), [10, 11, 12, 13]);
        store.redo().unwrap();
        let saved = store.incremental_update(&doc).unwrap();
        let again = open(&Source::from_bytes(saved.into()), &OpenOptions::default()).unwrap();
        assert_eq!(again.page_count(), 2);
    }

    #[test]
    fn an_order_with_no_page_or_a_page_twice_is_refused_and_a_same_order_writes_nothing() {
        let doc = opened(&mut nested());
        let mut store = RevisionStore::new(&doc);
        assert!(matches!(
            store.arrange_pages(&doc, &slots(&[0])),
            Err(CoreError::Write(WriteError::NoTransaction))
        ));
        store.begin().unwrap();
        for bad in [&[][..], &[0, 0, 1, 2, 3]] {
            assert!(matches!(
                store.arrange_pages(&doc, &slots(bad)),
                Err(CoreError::Write(WriteError::PagePlan))
            ));
        }
        assert!(matches!(
            store.arrange_pages(&doc, &slots(&[9])),
            Err(CoreError::Write(WriteError::NoSuchPage))
        ));
        store.arrange_pages(&doc, &slots(&[0, 1, 2, 3])).unwrap();
        assert_eq!(store.commit().unwrap(), 0);
    }

    #[test]
    fn a_hostile_tree_is_rebuilt_flat_and_stays_bounded() {
        // A wrong /Count, a cycle, a shared node, a /Parent that lies.
        let wrong_count = |model: &mut lopdf::Document| {
            let node = model.objects.get_mut(&NODE_A).unwrap();
            node.as_dict_mut().unwrap().set("Count", 999_999);
        };
        let cycle = |model: &mut lopdf::Document| {
            let node = model.objects.get_mut(&NODE_B).unwrap();
            let kids = vec![
                Object::Reference((12, 0)),
                Object::Reference((13, 0)),
                Object::Reference((4, 0)),
            ];
            node.as_dict_mut().unwrap().set("Kids", kids);
        };
        let shared = |model: &mut lopdf::Document| {
            let node = model.objects.get_mut(&(4, 0)).unwrap();
            let kids = vec![
                Object::Reference(NODE_A),
                Object::Reference(NODE_B),
                Object::Reference(NODE_A),
            ];
            node.as_dict_mut().unwrap().set("Kids", kids);
        };
        let lying_parent = |model: &mut lopdf::Document| {
            let page = model.objects.get_mut(&(12, 0)).unwrap();
            page.as_dict_mut().unwrap().set("Parent", NODE_A);
        };
        let hostile: [&dyn Fn(&mut lopdf::Document); 4] =
            [&wrong_count, &cycle, &shared, &lying_parent];
        for (case, damage) in hostile.into_iter().enumerate() {
            let mut model = nested();
            damage(&mut model);
            let doc = opened(&mut model);
            let mut store = RevisionStore::new(&doc);
            let count = store.pages(&doc).len();
            assert!(count >= 4, "case {case}");
            let mut order: Vec<usize> = (0..count).collect();
            order.remove(1);
            order.reverse();
            arrange(&mut store, &doc, &order);
            assert_eq!(store.pages(&doc).len(), count - 1, "case {case}");
            let scope = store.scope(&doc);
            let root = scope.dictionary((4, 0)).unwrap();
            assert_eq!(
                scope.get_int(root, b"Count"),
                i64::try_from(count - 1).ok(),
                "case {case}"
            );
        }
    }

    #[test]
    fn moved_labels_travel_and_new_pages_continue_the_range_before() {
        let mut model = nested();
        let labels = dictionary! { "Nums" => vec![
            0.into(), Object::Dictionary(dictionary! { "S" => "r" }),
            2.into(), Object::Dictionary(dictionary! { "S" => "D", "P" => Object::string_literal("Ek-") }),
        ]};
        model
            .objects
            .get_mut(&(1, 0))
            .unwrap()
            .as_dict_mut()
            .unwrap()
            .set("PageLabels", labels);
        let doc = opened(&mut model);
        let label_list = |store: &RevisionStore| -> Vec<String> {
            store
                .pages(&doc)
                .iter()
                .map(|page| page.label.clone().unwrap())
                .collect()
        };
        let mut store = RevisionStore::new(&doc);
        assert_eq!(label_list(&store), ["i", "ii", "Ek-1", "Ek-2"]);
        arrange(&mut store, &doc, &[3, 0, 1, 2]);
        assert_eq!(label_list(&store), ["Ek-2", "i", "ii", "Ek-1"]);
        store.undo().unwrap();
        arrange(&mut store, &doc, &[0, 2, 3]);
        assert_eq!(label_list(&store), ["i", "Ek-1", "Ek-2"]);
        store.undo().unwrap();

        store.begin().unwrap();
        let blank = store.blank_page(&doc, 100.0, 100.0).unwrap();
        let order = [
            PageSlot::Page(0),
            PageSlot::New(blank),
            PageSlot::Page(1),
            PageSlot::Page(2),
            PageSlot::Page(3),
        ];
        store.arrange_pages(&doc, &order).unwrap();
        store.commit().unwrap();
        assert_eq!(label_list(&store), ["i", "ii", "ii", "Ek-1", "Ek-2"]);
        assert_sound(&store, &doc);
    }

    #[test]
    fn label_ranges_can_be_set_read_and_removed() {
        let doc = opened(&mut nested());
        let mut store = RevisionStore::new(&doc);
        let bad_order = [
            LabelRange {
                start: 2,
                style: LabelStyle::Decimal,
                prefix: String::new(),
                first: 1,
            },
            LabelRange {
                start: 2,
                style: LabelStyle::Decimal,
                prefix: String::new(),
                first: 1,
            },
        ];
        store.begin().unwrap();
        assert!(store.set_label_ranges(&doc, &bad_order).is_err());
        let ranges = [
            LabelRange {
                start: 1,
                style: LabelStyle::LettersUpper,
                prefix: "Şubat ".to_owned(),
                first: 3,
            },
            LabelRange {
                start: 3,
                style: LabelStyle::None,
                prefix: "Kapak".to_owned(),
                first: 1,
            },
        ];
        store.set_label_ranges(&doc, &ranges).unwrap();
        store.commit().unwrap();
        let labels: Vec<_> = store
            .pages(&doc)
            .iter()
            .map(|page| page.label.clone().unwrap())
            .collect();
        assert_eq!(labels, ["", "Şubat C", "Şubat D", "Kapak"]);
        assert_eq!(store.label_ranges(&doc).len(), 3);
        store.begin().unwrap();
        store.set_label_ranges(&doc, &[]).unwrap();
        store.commit().unwrap();
        assert_eq!(store.pages(&doc)[0].label, None);
    }

    #[test]
    fn integer_destinations_follow_and_references_to_deleted_pages_become_null() {
        let mut model = nested();
        let catalog = model.objects.get_mut(&(1, 0)).unwrap();
        let catalog = catalog.as_dict_mut().unwrap();
        catalog.set("OpenAction", vec![3.into(), "Fit".into()]);
        model.objects.insert(
            (15, 0),
            Object::Dictionary(dictionary! {
                "Dest" => vec![Object::Integer(0), "XYZ".into()],
                "Other" => vec![Object::Integer(0), Object::Integer(3)],
                "A" => dictionary! { "S" => "GoToR", "D" => vec![Object::Integer(3), "Fit".into()] },
                "Link" => dictionary! { "Dest" => vec![Object::Reference((11, 0)), "Fit".into()] },
            }),
        );
        model.objects.insert(
            (16, 0),
            Object::Array(vec![Object::Integer(1), "Fit".into()]),
        );
        let doc = opened(&mut model);
        let mut store = RevisionStore::new(&doc);
        arrange(&mut store, &doc, &[3, 0, 2]);
        let scope = store.scope(&doc);
        let holder = scope.dictionary((15, 0)).unwrap();
        let first =
            |dict: &Dictionary, key: &[u8]| dict.get(key).unwrap().as_array().unwrap()[0].clone();
        assert_eq!(first(holder, b"Dest"), Object::Integer(1));
        assert_eq!(first(holder, b"Other"), Object::Integer(0));
        let remote = holder.get(b"A").unwrap().as_dict().unwrap();
        assert_eq!(first(remote, b"D"), Object::Integer(3));
        let link = holder.get(b"Link").unwrap().as_dict().unwrap();
        assert_eq!(first(link, b"Dest"), Object::Null);
        assert_eq!(
            first(scope.catalog().unwrap(), b"OpenAction"),
            Object::Integer(0)
        );
        // The array of its own, to the deleted page 1.
        assert_eq!(
            scope.object((16, 0)).unwrap().as_array().unwrap()[0],
            Object::Null
        );
        // The deleted page stays until a full rewrite.
        assert!(scope.dictionary((11, 0)).is_some());
        let rewritten = store.full_rewrite(&doc).unwrap();
        let again = open(
            &Source::from_bytes(rewritten.into()),
            &OpenOptions::default(),
        )
        .unwrap();
        assert_eq!(again.page_count(), 3);
        assert!(!again.model().objects.contains_key(&(11, 0)));
    }

    #[test]
    fn a_copy_has_its_own_annotations_and_no_widget() {
        let mut model = nested();
        model.objects.insert(
            (15, 0),
            Object::Dictionary(dictionary! {
                "Subtype" => "Text", "P" => (10, 0), "Popup" => (16, 0), "StructParent" => 7,
                "Rect" => vec![0.into(), 0.into(), 1.into(), 1.into()],
            }),
        );
        model.objects.insert(
            (16, 0),
            Object::Dictionary(
                dictionary! { "Subtype" => "Popup", "Parent" => (15, 0), "IRT" => (99, 0) },
            ),
        );
        model.objects.insert(
            (17, 0),
            Object::Dictionary(dictionary! { "Subtype" => "Widget", "P" => (10, 0) }),
        );
        let page = model.objects.get_mut(&(10, 0)).unwrap();
        let page = page.as_dict_mut().unwrap();
        page.set(
            "Annots",
            vec![
                Object::Reference((15, 0)),
                Object::Reference((16, 0)),
                Object::Reference((17, 0)),
            ],
        );
        page.set("StructParents", 3);
        let doc = opened(&mut model);
        let mut store = RevisionStore::new(&doc);
        let before = store_page(&doc, &store, 0);
        store.begin().unwrap();
        let copy = store.copy_page(&doc, ObjectRef((10, 0))).unwrap();
        let order = [
            PageSlot::Page(0),
            PageSlot::New(copy),
            PageSlot::Page(1),
            PageSlot::Page(2),
            PageSlot::Page(3),
        ];
        store.arrange_pages(&doc, &order).unwrap();
        store.commit().unwrap();
        assert_sound(&store, &doc);
        assert_eq!(store_page(&doc, &store, 1), before);
        let scope = store.scope(&doc);
        let new = scope.dictionary(copy.0).unwrap();
        assert!(!new.has(b"StructParents"));
        let items = scope.get_array(new, b"Annots").unwrap();
        assert_eq!(items.len(), 2);
        let note = items[0].as_reference().unwrap();
        let popup = items[1].as_reference().unwrap();
        assert!(note != (15, 0) && popup != (16, 0));
        let note = scope.dictionary(note).unwrap();
        assert_eq!(note.get(b"P").unwrap().as_reference().unwrap(), copy.0);
        assert_eq!(note.get(b"Popup").unwrap().as_reference().unwrap(), popup);
        assert!(!note.has(b"StructParent"));
        assert!(!scope.dictionary(popup).unwrap().has(b"IRT"));
    }

    #[test]
    fn a_scaled_page_wraps_its_contents_and_maps_its_annotations() {
        let mut model = nested();
        model.objects.insert(
            (15, 0),
            Object::Dictionary(dictionary! {
                "Subtype" => "Ink",
                "Rect" => vec![10.into(), 20.into(), 30.into(), 40.into()],
                "InkList" => vec![Object::Array(vec![10.into(), 20.into()])],
            }),
        );
        model.objects.insert(
            (16, 0),
            Object::Stream(lopdf::Stream::new(dictionary! {}, b"0 0 m".to_vec())),
        );
        let page = model.objects.get_mut(&(10, 0)).unwrap();
        let page = page.as_dict_mut().unwrap();
        page.set("Annots", vec![Object::Reference((15, 0))]);
        page.set("Contents", (16, 0));
        let doc = opened(&mut model);
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        store
            .scale_page(&doc, ObjectRef((10, 0)), 0.5, 1.0, 2.0)
            .unwrap();
        let open_stream = {
            let scope = store.scope(&doc);
            let page = scope.dictionary((10, 0)).unwrap();
            let contents = scope.get_array(page, b"Contents").unwrap();
            assert_eq!(contents.len(), 3);
            assert_eq!(contents[1].as_reference().unwrap(), (16, 0));
            let annotation = scope.dictionary((15, 0)).unwrap();
            let rect = annotation.get(b"Rect").unwrap().as_array().unwrap();
            assert_eq!(rect[0], Object::Real(6.0));
            assert_eq!(rect[3], Object::Real(22.0));
            let ink = annotation.get(b"InkList").unwrap().as_array().unwrap();
            assert_eq!(
                ink[0].as_array().unwrap()[1],
                Object::Real(12.0),
                "the ink's y"
            );
            contents[0].as_reference().unwrap()
        };
        let Some(Value::Stream { data, .. }) = store.object(&doc, ObjectRef(open_stream)).unwrap()
        else {
            panic!("not a stream");
        };
        assert_eq!(data, b"q 0.5 0 0 0.5 1 2 cm\n");
    }
}
