//! The assembler (M4 plan, W1): pages of one document copied into another, for Insert, Replace,
//! Extract, Split and Combine.
//!
//! [`PageImport`] walks the object graph from each page it copies and gives the objects new
//! numbers in the target's open transaction. The walk stops at everything that would bring in what
//! was not selected: `/Parent`, other pages, the catalog, outline, structure tree and threads, and
//! the annotations of pages left out. A form field keeps only the kids that lead to a widget it
//! copies. References to a stopped object become null, and destinations follow the copied pages:
//! a named destination is written out, so a copied link needs no name tree.
//!
//! [`finish`](PageImport::finish) merges what belongs to the document: bookmarks of the copied
//! pages, attachments and named destinations (a key that clashes gets a number), form fields (a
//! root field whose name clashes is renamed, since readers treat one name as one value) and layers.
//! A signature does not travel: a signature field arrives empty (question 6 of the M4 plan).
//!
//! Stream data is copied as it is stored, never decoded, so a stream the renderer can read is not
//! refused because Ferman cannot.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet};
use std::sync::Arc;

use lopdf::{Dictionary, Object, ObjectId, StringFormat, dictionary};

use crate::appendix::indirect;
use crate::limits::{LimitKind, Limits};
use crate::pages::{PageSlot, page_default, widgets_leave_form};
use crate::revision::{RevisionStore, free};
use crate::structure::navigation::{Named, name_tree, names};
use crate::structure::{Scope, inherited_entry};
use crate::write::ObjectRef;
use crate::{CoreError, Document, OpenOptions, Source, WriteError, open, text_string};

/// The attributes a page inherits from its `/Pages` ancestors.
const INHERITED: [&[u8]; 4] = [b"MediaBox", b"CropBox", b"Resources", b"Rotate"];

/// The types a walk from a page never enters: they lead to the whole document.
const STOPS: [&[u8]; 8] = [
    b"Page",
    b"Pages",
    b"Catalog",
    b"Outlines",
    b"StructTreeRoot",
    b"StructElem",
    b"Thread",
    b"Bead",
];

/// The entries of a page that tie it to its document.
const PAGE_ONLY: [&[u8]; 3] = [b"Parent", b"StructParents", b"B"];

/// The arrays that hold references a reader must not see as null.
const LISTS: [&[u8]; 2] = [b"Kids", b"Annots"];

/// The fit names of a destination (ISO 32000-2 §12.3.2.2).
const FITS: [&[u8]; 8] = [
    b"XYZ", b"Fit", b"FitH", b"FitV", b"FitR", b"FitB", b"FitBH", b"FitBV",
];

/// The most copies of one name a merge numbers.
const MOST_COPIES: u32 = 1000;

/// What a written object costs beyond itself: its cross-reference entry.
const XREF_ENTRY: u64 = 20;

/// The most a compressed stream grows by, before its data's own growth: `/Filter /FlateDecode` and
/// the zlib wrapper.
const COMPRESS_COST: u64 = 40;

/// What goes with the copied pages.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ImportOptions {
    /// Form fields and their widgets; without it no widget is copied.
    pub keep_forms: bool,
    /// The attachments and named destinations of the document, which Combine and Insert keep.
    /// Extract and Split leave them, since they belong to no page.
    pub document_parts: bool,
}

/// One bookmark on its way to the target.
struct Node {
    title: Vec<u8>,
    /// `/Dest` or `/A`, `/C` and `/F`, rewritten.
    entries: Vec<(&'static [u8], Object)>,
    open: bool,
    kids: Vec<Node>,
}

/// A document with one placeholder page, the start of a new file: the first
/// [`arrange_pages`](RevisionStore::arrange_pages) without it drops it. Unencrypted, whatever the
/// sources were (question 6 of the M4 plan).
///
/// # Errors
///
/// [`CoreError::Internal`] if it cannot read itself back.
pub fn new_document(limits: &Limits) -> Result<Document, CoreError> {
    // shortcut: always version 1.7, which readers do not hold against a 2.0 feature; take the
    // highest of the sources if one proves otherwise.
    let mut model = lopdf::Document::with_version("1.7");
    model.objects.insert(
        (1, 0),
        Object::Dictionary(dictionary! { "Type" => "Catalog", "Pages" => (2, 0) }),
    );
    model.objects.insert(
        (2, 0),
        Object::Dictionary(dictionary! {
            "Type" => "Pages", "Count" => 1, "Kids" => vec![Object::Reference((3, 0))],
        }),
    );
    model.objects.insert(
        (3, 0),
        Object::Dictionary(dictionary! {
            "Type" => "Page", "Parent" => (2, 0),
            "MediaBox" => vec![0.into(), 0.into(), 612.into(), 792.into()],
        }),
    );
    model.max_id = 3;
    model.trailer.set("Root", (1, 0));
    let mut bytes = Vec::new();
    model.save_to(&mut bytes).map_err(|_| CoreError::Internal {
        context: "a new document",
    })?;
    open(
        &Source::from_bytes(Arc::from(&bytes[..])),
        &OpenOptions {
            password: None,
            limits: limits.clone(),
        },
    )
}

/// The most a new file of `pages` of `source` comes to, in bytes, with no other input: it is
/// assembled as it would be, with stream data counted and not copied, so bookmarks, form parts and
/// the page tree are all in the figure. A stream with no filter counts as stored, though the full
/// rewrite compresses it.
///
/// # Errors
///
/// Those of assembling, but not the limit on a revision's size: a job refuses that.
pub fn assembled_size(
    source: &Document,
    revisions: &RevisionStore,
    pages: &[usize],
    options: ImportOptions,
) -> Result<u64, CoreError> {
    let doc = new_document(source.limits())?;
    let mut store = RevisionStore::new(&doc);
    store.begin()?;
    let mut import = PageImport::new(source, revisions, pages, options)?;
    let targets = import.start(&mut store, &[])?;
    import.weighing = true;
    for position in 0..import.page_count() {
        import.copy_page(&doc, &mut store, position)?;
    }
    import.finish_parts(&doc, &mut store, None)?;
    let order: Vec<PageSlot> = targets.into_iter().map(PageSlot::New).collect();
    store.arrange_pages(&doc, &order)?;
    store.commit()?;
    let file = store.full_rewrite(&doc)?;
    // The data's bytes also lengthen the number after `startxref`, to at most this.
    Ok(u64::try_from(file.len())
        .unwrap_or(u64::MAX)
        .saturating_add(import.stream_bytes)
        .saturating_add(XREF_ENTRY))
}

/// What `stream` adds to a written file beyond a copy of its dictionary with `/Length 0`: its data,
/// the rest of the length's digits, and when it has no filter what compressing it can add.
fn stored_cost(stream: &lopdf::Stream) -> u64 {
    let stored = u64::try_from(stream.content.len()).unwrap_or(u64::MAX);
    let mut cost = stored.saturating_add(u64::from(stored.checked_ilog10().unwrap_or(0)));
    if !stream.dict.has(b"Filter") {
        cost = cost
            .saturating_add(COMPRESS_COST)
            .saturating_add(stored / 1000);
    }
    cost
}

/// `depth` one deeper, or the nesting limit's error.
fn deeper(depth: u32, limits: &Limits) -> Result<u32, CoreError> {
    if depth > limits.max_nesting {
        return Err(CoreError::ResourceLimit {
            limit: LimitKind::Nesting,
            max: u64::from(limits.max_nesting),
        });
    }
    Ok(depth.saturating_add(1))
}

/// Pages of one document on their way into a target's open transaction, one by one so a job can
/// stop between them; or, without a target, weighed for an estimate.
pub struct PageImport<'s> {
    scope: Scope<'s>,
    named: Named<'s>,
    options: ImportOptions,
    /// Every page's object, by index.
    all: Vec<ObjectId>,
    /// The pages it copies, in their order.
    selected: Vec<ObjectId>,
    /// What each source object became.
    map: BTreeMap<ObjectId, ObjectId>,
    /// Annotations and form fields a reference must not reach.
    blocked: BTreeSet<ObjectId>,
    /// The annotations of the selected pages.
    annotations: BTreeSet<ObjectId>,
    /// The fields that lead to a copied widget, the widgets among them.
    fields: BTreeSet<ObjectId>,
    /// Those of a signed signature field, which arrive empty.
    signatures: BTreeSet<ObjectId>,
    /// The fields with no parent, in first-seen order.
    roots: Vec<ObjectId>,
    queue: Vec<ObjectId>,
    next: u32,
    weighing: bool,
    /// The stored bytes of the streams of the last walk.
    stored: u64,
    /// What every stream reached so far costs in a written file, at most.
    stream_bytes: u64,
}

impl<'s> PageImport<'s> {
    /// Plans copying `pages` (indices, in their new order, once each) of `source` as `revisions`
    /// leave them.
    ///
    /// # Errors
    ///
    /// [`WriteError::PagePlan`] for no page or a page named twice, [`WriteError::NoSuchPage`], and
    /// [`WriteError::TransactionOpen`].
    pub fn new(
        source: &'s Document,
        revisions: &'s RevisionStore,
        pages: &[usize],
        options: ImportOptions,
    ) -> Result<Self, CoreError> {
        revisions.closed()?;
        let plan = || CoreError::Write(WriteError::PagePlan);
        let listed = revisions.pages(source);
        let all: Vec<ObjectId> = listed.iter().map(|page| page.id).collect();
        let mut scope = revisions.scope(source);
        scope.page_of = listed.iter().map(|page| (page.id, page.index)).collect();
        let selected = pages
            .iter()
            .map(|index| {
                all.get(*index)
                    .copied()
                    .ok_or(CoreError::Write(WriteError::NoSuchPage))
            })
            .collect::<Result<Vec<_>, _>>()?;
        let unique: BTreeSet<ObjectId> = selected.iter().copied().collect();
        if selected.is_empty() || unique.len() != selected.len() {
            return Err(plan());
        }
        let named = Named::new(&scope);
        let mut import = Self {
            map: selected.iter().map(|id| (*id, *id)).collect(),
            scope,
            named,
            options,
            all,
            selected,
            blocked: BTreeSet::new(),
            annotations: BTreeSet::new(),
            fields: BTreeSet::new(),
            signatures: BTreeSet::new(),
            roots: Vec::new(),
            queue: Vec::new(),
            next: 1,
            weighing: true,
            stored: 0,
            stream_bytes: 0,
        };
        import.plan_stops(&unique);
        Ok(import)
    }

    /// How many pages it copies.
    #[must_use]
    pub fn page_count(&self) -> usize {
        self.selected.len()
    }

    /// Which annotations and fields the walk may reach, and which it must not.
    fn plan_stops(&mut self, selected: &BTreeSet<ObjectId>) {
        let scope = &self.scope;
        let mut left_out = BTreeSet::new();
        let mut widgets = Vec::new();
        for page in &self.all {
            let Some(items) = scope
                .dictionary(*page)
                .and_then(|dict| scope.get_array(dict, b"Annots"))
            else {
                continue;
            };
            let chosen = selected.contains(page);
            for id in items.iter().filter_map(|item| item.as_reference().ok()) {
                let widget = scope
                    .dictionary(id)
                    .and_then(|annotation| scope.get_name(annotation, b"Subtype"))
                    == Some(b"Widget");
                if chosen && (self.options.keep_forms || !widget) {
                    self.annotations.insert(id);
                    if widget {
                        widgets.push(id);
                    }
                } else {
                    left_out.insert(id);
                }
            }
        }
        left_out.retain(|id| !self.annotations.contains(id));
        self.blocked = left_out;

        for widget in widgets {
            self.climb(widget);
        }
        // Each field keeps only the kids that lead to a copied widget.
        let mut stack = self.roots.clone();
        let mut seen = BTreeSet::new();
        while let Some(id) = stack.pop() {
            if !seen.insert(id) {
                continue;
            }
            let Some(kids) = self
                .scope
                .dictionary(id)
                .and_then(|field| self.scope.get_array(field, b"Kids"))
            else {
                continue;
            };
            for kid in kids.iter().filter_map(|kid| kid.as_reference().ok()) {
                if self.fields.contains(&kid) {
                    stack.push(kid);
                } else {
                    self.blocked.insert(kid);
                }
            }
        }
    }

    /// Keeps `widget`'s line of fields up to its root.
    fn climb(&mut self, widget: ObjectId) {
        let mut chain = Vec::new();
        let mut kind = None;
        let mut node = widget;
        let scope = &self.scope;
        for _ in 0..=scope.limits.max_nesting {
            if chain.contains(&node) {
                break;
            }
            let Some(field) = scope.dictionary(node) else {
                break;
            };
            if is_stop(scope, field) {
                break;
            }
            chain.push(node);
            kind = kind.or_else(|| scope.get_name(field, b"FT"));
            match field.get(b"Parent").and_then(Object::as_reference) {
                Ok(parent) => node = parent,
                Err(_) => break,
            }
        }
        let Some(root) = chain.last().copied() else {
            return;
        };
        let named = scope
            .dictionary(root)
            .is_some_and(|field| field.has(b"T") || field.has(b"FT"));
        if named && !self.fields.contains(&root) {
            self.roots.push(root);
        }
        // An empty signature field keeps what it draws; a signature does not travel.
        let signed = chain
            .iter()
            .any(|node| scope.dictionary(*node).is_some_and(|field| field.has(b"V")));
        if kind == Some(b"Sig") && signed {
            self.signatures.extend(chain.iter().copied());
        }
        self.fields.extend(chain);
    }

    /// Whether a reference to `id` stops: `from` is the key it stands under.
    fn stopped(&self, id: ObjectId, from: Option<&[u8]>) -> bool {
        if from == Some(b"Parent") && !self.fields.contains(&id) && !self.annotations.contains(&id)
        {
            return true;
        }
        if self.blocked.contains(&id) || self.scope.page_of.contains_key(&id) {
            return true;
        }
        match self.scope.object(id) {
            Some(Object::Dictionary(dict)) => is_stop(&self.scope, dict),
            Some(_) => false,
            None => true,
        }
    }

    fn reference(&mut self, id: ObjectId, from: Option<&[u8]>) -> Result<Object, CoreError> {
        if let Some(target) = self.map.get(&id) {
            return Ok(Object::Reference(*target));
        }
        if self.stopped(id, from) {
            return Ok(Object::Null);
        }
        let target = (free(self.next)?, 0);
        self.next = self.next.saturating_add(1);
        self.map.insert(id, target);
        self.queue.push(id);
        Ok(Object::Reference(target))
    }

    /// `object` with its references in the target's numbers, read under the key `from`.
    fn rewritten(
        &mut self,
        object: &'s Object,
        from: Option<&[u8]>,
        depth: u32,
    ) -> Result<Object, CoreError> {
        let depth = deeper(depth, self.scope.limits)?;
        Ok(match object {
            Object::Reference(id) => {
                let list = from.is_some_and(|from| LISTS.contains(&from));
                match self.scope.object(*id) {
                    // A list behind a reference is written direct, as the page's own.
                    Some(array @ Object::Array(_)) if list => self.rewritten(array, from, depth)?,
                    _ => self.reference(*id, from)?,
                }
            }
            Object::Array(items) => {
                if let Some(destination) = self.integer_destination(items) {
                    return Ok(destination);
                }
                let mut out = Vec::with_capacity(items.len());
                for item in items {
                    out.push(self.rewritten(item, from, depth)?);
                }
                if from.is_some_and(|from| LISTS.contains(&from)) {
                    out.retain(|item| !matches!(item, Object::Null));
                }
                Object::Array(out)
            }
            Object::Dictionary(dict) => Object::Dictionary(self.dictionary(dict, &[], depth)?),
            Object::Stream(stream) => {
                let dict = self.dictionary(&stream.dict, &[&b"Length"[..]], depth)?;
                let stored = u64::try_from(stream.content.len()).unwrap_or(u64::MAX);
                self.stored = self.stored.saturating_add(stored);
                self.stream_bytes = self.stream_bytes.saturating_add(stored_cost(stream));
                let content = if self.weighing {
                    Vec::new()
                } else {
                    stream.content.clone()
                };
                Object::Stream(lopdf::Stream::new(dict, content))
            }
            other => other.clone(),
        })
    }

    /// `items` as a destination of the target, when it is one with a page index.
    fn integer_destination(&self, items: &[Object]) -> Option<Object> {
        let [Object::Integer(page), Object::Name(fit), rest @ ..] = items else {
            return None;
        };
        if !FITS.contains(&fit.as_slice()) {
            return None;
        }
        let target = usize::try_from(*page)
            .ok()
            .and_then(|page| self.all.get(page))
            .and_then(|id| self.map.get(id))
            .map_or(Object::Null, |id| Object::Reference(*id));
        let mut out = vec![target, Object::Name(fit.clone())];
        out.extend(rest.iter().cloned());
        Some(Object::Array(out))
    }

    /// `dict` rewritten without `skip`. Another file's destination stays as it is; a name for
    /// this file's is written out.
    fn dictionary(
        &mut self,
        dict: &'s Dictionary,
        skip: &[&[u8]],
        depth: u32,
    ) -> Result<Dictionary, CoreError> {
        let action = dict.get(b"S").ok().and_then(|kind| kind.as_name().ok());
        let remote = matches!(action, Some(b"GoToR" | b"GoToE"));
        let local = action == Some(b"GoTo");
        let mut out = Dictionary::new();
        for (key, value) in dict {
            let key = key.as_slice();
            if skip.contains(&key) {
                continue;
            }
            let value = if key == b"D" && remote {
                value.clone()
            } else if key == b"Dest" || (key == b"D" && local) {
                self.destination(value, depth)?
            } else {
                self.rewritten(value, Some(key), depth)?
            };
            out.set(key.to_vec(), value);
        }
        Ok(out)
    }

    /// A destination as an explicit array; null when it goes nowhere.
    fn destination(&mut self, value: &'s Object, depth: u32) -> Result<Object, CoreError> {
        let mut resolved = self.scope.resolve(value);
        if let Some(Object::Name(name) | Object::String(name, _)) = resolved {
            resolved = self
                .named
                .by_name
                .get(name.as_slice())
                .copied()
                .and_then(|named| self.scope.resolve(named));
        }
        if let Some(Object::Dictionary(dict)) = resolved {
            resolved = self.scope.get(dict, b"D");
        }
        match resolved {
            Some(array @ Object::Array(_)) => self.rewritten(array, None, depth),
            _ => Ok(Object::Null),
        }
    }

    /// The page at `position` with what its annotations and fields need written out: it and every
    /// object newly reached.
    fn walk(&mut self, position: usize) -> Result<Vec<(ObjectId, Object)>, CoreError> {
        let missing = || CoreError::Write(WriteError::NoSuchPage);
        let source = *self.selected.get(position).ok_or_else(missing)?;
        let target = *self.map.get(&source).ok_or_else(missing)?;
        let page = self.scope.dictionary(source).ok_or_else(missing)?;
        let mut dict = self.dictionary(page, &PAGE_ONLY, 0)?;
        for key in INHERITED {
            if !dict.has(key)
                && let Some(value) = inherited_entry(&self.scope, page, key)
            {
                let value = self.rewritten(value, Some(key), 0)?;
                dict.set(key.to_vec(), value);
            }
        }
        let mut written = vec![(target, Object::Dictionary(dict))];
        written.append(&mut self.drain()?);
        Ok(written)
    }

    /// The objects the queue names, and those they reach.
    fn drain(&mut self) -> Result<Vec<(ObjectId, Object)>, CoreError> {
        let mut written = Vec::new();
        while let Some(id) = self.queue.pop() {
            let target = *self.map.get(&id).ok_or(CoreError::Internal {
                context: "an object queued without its number",
            })?;
            let Some(object) = self.scope.object(id) else {
                continue;
            };
            let object = match object {
                Object::Dictionary(dict) if self.signatures.contains(&id) => {
                    Object::Dictionary(self.dictionary(dict, &[&b"V"[..], b"AP"], 0)?)
                }
                Object::Dictionary(dict) if self.annotations.contains(&id) => {
                    Object::Dictionary(self.dictionary(dict, &[&b"StructParent"[..]], 0)?)
                }
                other => self.rewritten(other, None, 0)?,
            };
            written.push((target, object));
        }
        Ok(written)
    }

    /// What the page at `position` adds, in bytes, to a file already holding what was weighed
    /// since [`reset_weights`](Self::reset_weights). Stream data counts as stored. A rough figure:
    /// the file's bookmarks, form and page tree are left out, which [`assembled_size`] counts.
    ///
    /// # Errors
    ///
    /// [`CoreError::ResourceLimit`] past the nesting limit, [`WriteError::NoSuchPage`].
    pub fn weigh(&mut self, position: usize) -> Result<u64, CoreError> {
        self.stored = 0;
        let written = self.walk(position)?;
        Ok(self.weight(&written))
    }

    /// What the attachments add, in bytes, as [`weigh`](Self::weigh) counts.
    ///
    /// # Errors
    ///
    /// [`CoreError::ResourceLimit`] past the nesting limit.
    pub fn weigh_attachments(&mut self) -> Result<u64, CoreError> {
        self.stored = 0;
        self.name_entries(b"EmbeddedFiles")?;
        let written = self.drain()?;
        Ok(self.weight(&written))
    }

    /// The bytes of `written`, whose stream data is in [`stored`](Self::stored).
    fn weight(&self, written: &[(ObjectId, Object)]) -> u64 {
        let mut bytes = self.stored;
        let mut out = Vec::new();
        for (id, object) in written {
            out.clear();
            indirect(&mut out, *id, object);
            let size = u64::try_from(out.len()).unwrap_or(u64::MAX);
            bytes = bytes.saturating_add(size).saturating_add(XREF_ENTRY);
        }
        bytes
    }

    /// Starts weighing another file.
    pub fn reset_weights(&mut self) {
        let pages = &self.scope.page_of;
        self.map.retain(|id, _| pages.contains_key(id));
    }

    /// Takes the pages' numbers in `store`'s open transaction: the first ones take over the
    /// objects of `replacing`, whose references stay, the rest are new. Returns them, in order.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`] and [`WriteError::ObjectNumbers`].
    pub fn start(
        &mut self,
        store: &mut RevisionStore,
        replacing: &[ObjectRef],
    ) -> Result<Vec<ObjectRef>, CoreError> {
        self.weighing = false;
        let mut targets = Vec::with_capacity(self.selected.len());
        for (index, source) in self.selected.iter().enumerate() {
            let target = match replacing.get(index) {
                Some(page) => *page,
                None => store.allocate()?,
            };
            self.map.insert(*source, target.0);
            targets.push(target);
        }
        Ok(targets)
    }

    /// Copies the page at `position` into `store`'s open transaction, after
    /// [`start`](Self::start). A page taking over an object keeps its place in the page tree.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::NoSuchPage`], [`WriteError::ObjectNumbers`],
    /// and [`CoreError::ResourceLimit`] past the nesting limit or the size of a revision.
    pub fn copy_page(
        &mut self,
        doc: &Document,
        store: &mut RevisionStore,
        position: usize,
    ) -> Result<(), CoreError> {
        store.transaction_open()?;
        self.next = store.next_number();
        self.stored = 0;
        let mut written = self.walk(position)?;
        let mut form = BTreeMap::new();
        if let Some((target, Object::Dictionary(page))) = written.first_mut() {
            let scope = store.scope(doc);
            let parent = scope
                .dictionary(*target)
                .and_then(|old| old.get(b"Parent").ok().cloned());
            if let Some(parent) = parent {
                page.set("Parent", parent);
                // It draws as it did in its source, whatever its new ancestors hold.
                for key in INHERITED {
                    if !page.has(key) && inherited_entry(&scope, page, key).is_some() {
                        let default = page_default(page, key);
                        page.set(key.to_vec(), default);
                    }
                }
                let others: Vec<ObjectId> = store
                    .pages(doc)
                    .iter()
                    .map(|other| other.id)
                    .filter(|other| other != target)
                    .collect();
                widgets_leave_form(doc, &scope, &[*target], &others, &mut form);
            }
        }
        if let Some((target, _)) = written.first()
            && !self.weighing
        {
            store.count_open(doc, *target, self.stored)?;
        }
        for (id, object) in form {
            store.put(id, object)?;
        }
        for (id, object) in written {
            store.put(id, object)?;
        }
        Ok(())
    }

    /// Bookmarks of the copied pages under `parent`.
    fn outline_nodes(
        &mut self,
        parent: &'s Dictionary,
        depth: u32,
        seen: &mut BTreeSet<ObjectId>,
    ) -> Result<Vec<Node>, CoreError> {
        let mut out = Vec::new();
        if depth >= self.scope.limits.max_nesting {
            return Ok(out);
        }
        let whole = self.selected.len() == self.all.len();
        let mut next = parent.get(b"First").ok();
        while let Some(link) = next.take() {
            let Ok(id) = link.as_reference() else {
                break;
            };
            if !seen.insert(id) {
                break;
            }
            let Some(item) = self.scope.dict(link) else {
                break;
            };
            let kids = self.outline_nodes(item, depth.saturating_add(1), seen)?;
            let target = self.named.target(&self.scope, item);
            let action = self.scope.get_dict(item, b"A");
            let keep = match target {
                Some(index) => usize::try_from(index)
                    .ok()
                    .and_then(|index| self.all.get(index))
                    .is_some_and(|page| self.map.contains_key(page)),
                // A web link belongs to no page: it stays with the whole document.
                None => {
                    whole
                        && action
                            .and_then(|action| self.scope.get_name(action, b"S"))
                            .is_some_and(|kind| kind != b"GoTo")
                }
            };
            if keep || !kids.is_empty() {
                let mut entries: Vec<(&'static [u8], Object)> = Vec::new();
                if keep {
                    if let Ok(dest) = item.get(b"Dest") {
                        entries.push((&b"Dest"[..], self.destination(dest, 0)?));
                    } else if let Ok(action) = item.get(b"A") {
                        entries.push((&b"A"[..], self.rewritten(action, None, 0)?));
                    }
                }
                for key in [&b"C"[..], b"F"] {
                    if let Some(value) = self.scope.get(item, key) {
                        entries.push((key, self.rewritten(value, None, 0)?));
                    }
                }
                let title = self
                    .scope
                    .get(item, b"Title")
                    .and_then(|title| title.as_str().ok())
                    .map(<[u8]>::to_vec)
                    .unwrap_or_default();
                out.push(Node {
                    title,
                    entries,
                    open: self.scope.get_int(item, b"Count").is_some_and(|c| c > 0),
                    kids,
                });
            }
            next = item.get(b"Next").ok();
        }
        Ok(out)
    }

    /// The entries of the source's name tree `name`, for the pages copied.
    fn name_entries(&mut self, name: &[u8]) -> Result<Vec<(Vec<u8>, Object)>, CoreError> {
        let mut out = Vec::new();
        for (key, value) in names(&self.scope, name) {
            let value = if name == b"Dests" {
                let destination = self.destination(value, 0)?;
                let page_kept = matches!(
                    &destination,
                    Object::Array(items) if matches!(items.first(), Some(Object::Reference(_)))
                );
                if !page_kept {
                    continue;
                }
                destination
            } else {
                self.rewritten(value, None, 0)?
            };
            out.push((key.to_vec(), value));
        }
        Ok(out)
    }

    /// The source's layers among the objects copied.
    fn layers(&self) -> Option<Layers> {
        let scope = &self.scope;
        let properties = scope
            .catalog()
            .and_then(|catalog| scope.get_dict(catalog, b"OCProperties"))?;
        let groups: Vec<ObjectId> = scope
            .get_array(properties, b"OCGs")
            .into_iter()
            .flatten()
            .filter_map(|group| group.as_reference().ok())
            .filter(|group| self.map.contains_key(group))
            .collect();
        if groups.is_empty() {
            return None;
        }
        let config = scope.get_dict(properties, b"D");
        let listed = |key: &[u8]| -> BTreeSet<ObjectId> {
            config
                .and_then(|config| scope.get_array(config, key))
                .into_iter()
                .flatten()
                .filter_map(|group| group.as_reference().ok())
                .collect()
        };
        let base_off =
            config.and_then(|config| scope.get_name(config, b"BaseState")) == Some(b"OFF");
        let (on, off) = (listed(b"ON"), listed(b"OFF"));
        let target = |group: &ObjectId| self.map.get(group).copied();
        Some(Layers {
            groups: groups.iter().filter_map(target).collect(),
            off: groups
                .iter()
                .filter(|group| {
                    if base_off {
                        !on.contains(group)
                    } else {
                        off.contains(group)
                    }
                })
                .filter_map(target)
                .collect(),
            order: config
                .and_then(|config| scope.get_array(config, b"Order"))
                .map(|order| self.layer_order(order, 0))
                // With no list every layer must still show in the panel, next to others' lists.
                .unwrap_or_else(|| {
                    groups
                        .iter()
                        .filter_map(target)
                        .map(Object::Reference)
                        .collect()
                }),
        })
    }

    /// `/Order` with what was not copied left out; a nested list that keeps no layer goes too.
    fn layer_order(&self, order: &'s [Object], depth: u32) -> Vec<Object> {
        let mut out = Vec::new();
        if depth >= self.scope.limits.max_nesting {
            return out;
        }
        for item in order {
            match item {
                Object::Reference(id) => {
                    if let Some(target) = self.map.get(id) {
                        out.push(Object::Reference(*target));
                    }
                }
                Object::Array(nested) => {
                    let nested = self.layer_order(nested, depth.saturating_add(1));
                    if nested
                        .iter()
                        .any(|item| !matches!(item, Object::String(..)))
                    {
                        out.push(Object::Array(nested));
                    }
                }
                Object::String(..) => out.push(item.clone()),
                _ => {}
            }
        }
        out
    }

    /// Merges into `store`'s open transaction what belongs to the document, after every
    /// [`copy_page`](Self::copy_page): the bookmarks of the copied pages, under one titled
    /// `bookmark` that goes to the first page when given; attachments and named destinations with
    /// [`ImportOptions::document_parts`]; form fields and layers.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::ObjectNumbers`], and
    /// [`CoreError::ResourceLimit`] past the nesting limit.
    pub fn finish(
        mut self,
        doc: &Document,
        store: &mut RevisionStore,
        bookmark: Option<&str>,
    ) -> Result<(), CoreError> {
        self.finish_parts(doc, store, bookmark)
    }

    /// What [`finish`](Self::finish) does.
    fn finish_parts(
        &mut self,
        doc: &Document,
        store: &mut RevisionStore,
        bookmark: Option<&str>,
    ) -> Result<(), CoreError> {
        store.transaction_open()?;
        self.next = store.next_number();
        let mut nodes = match self
            .scope
            .catalog()
            .and_then(|catalog| self.scope.get_dict(catalog, b"Outlines"))
        {
            Some(root) => self.outline_nodes(root, 0, &mut BTreeSet::new())?,
            None => Vec::new(),
        };
        if let Some(title) = bookmark {
            let first = self
                .selected
                .first()
                .and_then(|page| self.map.get(page))
                .copied()
                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
            nodes = vec![file_bookmark(title, first, nodes)];
        }
        let (files, dests) = if self.options.document_parts {
            (
                self.name_entries(b"EmbeddedFiles")?,
                self.name_entries(b"Dests")?,
            )
        } else {
            (Vec::new(), Vec::new())
        };
        let form = self.form()?;
        let layers = self.layers();
        for (id, object) in self.drain()? {
            store.put(id, object)?;
        }

        append_outline(doc, store, nodes)?;
        let root = doc
            .model()
            .trailer
            .get(b"Root")
            .and_then(Object::as_reference)
            .map_err(|_| CoreError::Internal {
                context: "a document without /Root",
            })?;
        let mut catalog = store.dictionary(doc, root)?;
        merge_names(doc, store, &mut catalog, b"EmbeddedFiles", files);
        merge_names(doc, store, &mut catalog, b"Dests", dests);
        if let Some(form) = form {
            merge_form(doc, store, &mut catalog, form)?;
        }
        if let Some(layers) = layers {
            merge_layers(doc, store, &mut catalog, layers);
        }
        store.put(root, Object::Dictionary(catalog))
    }

    /// What the target's form needs of the source's.
    fn form(&mut self) -> Result<Option<FormParts>, CoreError> {
        let roots: Vec<ObjectId> = self
            .roots
            .iter()
            .filter_map(|root| self.map.get(root))
            .copied()
            .collect();
        if roots.is_empty() {
            return Ok(None);
        }
        let Some(source) = self
            .scope
            .catalog()
            .and_then(|catalog| self.scope.get_dict(catalog, b"AcroForm"))
        else {
            return Ok(Some(FormParts {
                roots,
                ..FormParts::default()
            }));
        };
        let map = &self.map;
        let order = self
            .scope
            .get_array(source, b"CO")
            .into_iter()
            .flatten()
            .filter_map(|field| field.as_reference().ok())
            .filter_map(|field| map.get(&field))
            .map(|field| Object::Reference(*field))
            .collect();
        let resources = match source.get(b"DR") {
            Ok(resources) => Some(self.rewritten(resources, None, 0)?),
            Err(_) => None,
        };
        let scope = &self.scope;
        let inherited = [&b"DA"[..], b"Q"]
            .into_iter()
            .filter_map(|key| Some((key.to_vec(), scope.get(source, key)?.clone())))
            .collect();
        let need_appearances = matches!(
            scope.get(source, b"NeedAppearances"),
            Some(Object::Boolean(true))
        );
        Ok(Some(FormParts {
            roots,
            order,
            resources,
            inherited,
            need_appearances,
        }))
    }
}

/// `dict` is an object the walk stops at.
fn is_stop(scope: &Scope<'_>, dict: &Dictionary) -> bool {
    scope
        .get_name(dict, b"Type")
        .is_some_and(|kind| STOPS.contains(&kind))
}

/// The layers a source brings.
struct Layers {
    groups: Vec<ObjectId>,
    off: Vec<ObjectId>,
    order: Vec<Object>,
}

/// What a source's `/AcroForm` brings.
#[derive(Default)]
struct FormParts {
    roots: Vec<ObjectId>,
    order: Vec<Object>,
    resources: Option<Object>,
    /// `/DA` and `/Q`, which a field inherited from the form and takes along.
    inherited: Vec<(Vec<u8>, Object)>,
    need_appearances: bool,
}

/// A bookmark titled `title` for a file's first page.
fn file_bookmark(title: &str, page: ObjectId, kids: Vec<Node>) -> Node {
    let destination = vec![Object::Reference(page), Object::Name(b"Fit".to_vec())];
    Node {
        title: text_string::encode(title),
        entries: vec![(&b"Dest"[..], Object::Array(destination))],
        open: true,
        kids,
    }
}

/// Writes `nodes` as the items under `parent`; their first and last, and how many show.
fn write_nodes(
    store: &mut RevisionStore,
    parent: ObjectId,
    nodes: Vec<Node>,
) -> Result<(Option<(ObjectId, ObjectId)>, i64), CoreError> {
    let mut ids = Vec::with_capacity(nodes.len());
    for _ in &nodes {
        ids.push(store.allocate()?.0);
    }
    let mut showing = 0i64;
    for (index, node) in nodes.into_iter().enumerate() {
        let id = *ids.get(index).ok_or(CoreError::Internal {
            context: "an outline item without its number",
        })?;
        let (span, below) = write_nodes(store, id, node.kids)?;
        let mut dict = Dictionary::new();
        dict.set("Title", Object::String(node.title, StringFormat::Literal));
        dict.set("Parent", parent);
        for (key, value) in node.entries {
            dict.set(key.to_vec(), value);
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
                if node.open {
                    below
                } else {
                    below.saturating_neg()
                },
            );
        }
        store.put(id, Object::Dictionary(dict))?;
        showing = showing
            .saturating_add(1)
            .saturating_add(if node.open { below } else { 0 });
    }
    let span = ids.first().copied().zip(ids.last().copied());
    Ok((span, showing))
}

/// Appends `nodes` to the target's top-level bookmarks.
fn append_outline(
    doc: &Document,
    store: &mut RevisionStore,
    nodes: Vec<Node>,
) -> Result<(), CoreError> {
    if nodes.is_empty() {
        return Ok(());
    }
    let root = doc
        .model()
        .trailer
        .get(b"Root")
        .and_then(Object::as_reference)
        .map_err(|_| CoreError::Internal {
            context: "a document without /Root",
        })?;
    let mut catalog = store.dictionary(doc, root)?;
    let held = catalog
        .get(b"Outlines")
        .ok()
        .and_then(|outlines| outlines.as_reference().ok());
    let mut outlines = {
        let scope = store.scope(doc);
        scope
            .get_dict(&catalog, b"Outlines")
            .cloned()
            .unwrap_or_default()
    };
    let id = match held {
        Some(id) => id,
        None => store.allocate()?.0,
    };
    let last = outlines
        .get(b"Last")
        .ok()
        .and_then(|last| last.as_reference().ok());
    let (span, showing) = write_nodes(store, id, nodes)?;
    let Some((first, new_last)) = span else {
        return Ok(());
    };
    match last {
        Some(last) => {
            if let Ok(mut before) = store.dictionary(doc, last) {
                before.set("Next", first);
                store.put(last, Object::Dictionary(before))?;
            }
            let mut after = store.dictionary(doc, first)?;
            after.set("Prev", last);
            store.put(first, Object::Dictionary(after))?;
        }
        None => outlines.set("First", first),
    }
    outlines.set("Type", "Outlines");
    outlines.set("Last", new_last);
    let before = outlines
        .get(b"Count")
        .and_then(Object::as_i64)
        .unwrap_or(0)
        .max(0);
    outlines.set("Count", before.saturating_add(showing));
    store.put(id, Object::Dictionary(outlines))?;
    catalog.set("Outlines", id);
    store.put(root, Object::Dictionary(catalog))
}

/// A bookmark titled `title` for `page`, appended to the target's top level, for a page that came
/// from no document.
///
/// # Errors
///
/// [`WriteError::NoTransaction`] and [`WriteError::ObjectNumbers`].
pub fn add_bookmark(
    doc: &Document,
    store: &mut RevisionStore,
    title: &str,
    page: ObjectRef,
) -> Result<(), CoreError> {
    store.transaction_open()?;
    append_outline(doc, store, vec![file_bookmark(title, page.0, Vec::new())])
}

/// `key` with a number that makes it free, keeping an extension at the end; `None` after
/// [`MOST_COPIES`] tries, which only a file made to do this reaches.
fn free_key(key: &[u8], taken: impl Fn(&[u8]) -> bool) -> Option<Vec<u8>> {
    if !taken(key) {
        return Some(key.to_vec());
    }
    let text = text_string::decode(key);
    let (stem, extension) = match text.rfind('.') {
        Some(at) if at > 0 => text.split_at(at),
        _ => (text.as_str(), ""),
    };
    (2..=MOST_COPIES)
        .map(|number| text_string::encode(&format!("{stem} ({number}){extension}")))
        .find(|candidate| !taken(candidate))
}

/// Adds `entries` to the name tree `name` of `catalog`, which becomes one sorted leaf.
pub(crate) fn merge_names(
    doc: &Document,
    store: &RevisionStore,
    catalog: &mut Dictionary,
    name: &[u8],
    entries: Vec<(Vec<u8>, Object)>,
) {
    if entries.is_empty() {
        return;
    }
    let scope = store.scope(doc);
    let mut names = scope
        .get_dict(catalog, b"Names")
        .cloned()
        .unwrap_or_default();
    let mut tree: BTreeMap<Vec<u8>, Object> = scope
        .get_dict(&names, name)
        .map(|root| name_tree(&scope, root))
        .unwrap_or_default()
        .into_iter()
        .map(|(key, value)| (key.to_vec(), value.clone()))
        .collect();
    for (key, value) in entries {
        if let Some(key) = free_key(&key, |candidate| tree.contains_key(candidate)) {
            tree.insert(key, value);
        }
    }
    let mut pairs = Vec::with_capacity(tree.len().saturating_mul(2));
    for (key, value) in tree {
        pairs.push(Object::String(key, StringFormat::Literal));
        pairs.push(value);
    }
    let mut leaf = Dictionary::new();
    leaf.set("Names", pairs);
    names.set(name.to_vec(), leaf);
    catalog.set("Names", names);
}

/// Adds a source's fields to `catalog`'s form. A root field whose name another root has is
/// renamed, since a reader would otherwise treat both as one value.
fn merge_form(
    doc: &Document,
    store: &mut RevisionStore,
    catalog: &mut Dictionary,
    parts: FormParts,
) -> Result<(), CoreError> {
    let (mut form, mut fields, mut taken) = {
        let scope = store.scope(doc);
        let form = scope
            .get_dict(catalog, b"AcroForm")
            .cloned()
            .unwrap_or_default();
        let fields = scope
            .get_array(&form, b"Fields")
            .cloned()
            .unwrap_or_default();
        let taken: BTreeSet<Vec<u8>> = fields
            .iter()
            .filter_map(|field| scope.dict(field))
            .filter_map(|field| scope.get(field, b"T")?.as_str().ok())
            .map(<[u8]>::to_vec)
            .collect();
        (form, fields, taken)
    };
    let mut renamed: BTreeMap<Vec<u8>, Vec<u8>> = BTreeMap::new();
    for root in &parts.roots {
        let mut field = store.dictionary(doc, *root)?;
        let name = field
            .get(b"T")
            .ok()
            .and_then(|name| name.as_str().ok())
            .map(<[u8]>::to_vec);
        if let Some(name) = name {
            let free = match renamed.get(&name) {
                Some(free) => free.clone(),
                None => {
                    let free = free_key(&name, |candidate| taken.contains(candidate))
                        .unwrap_or_else(|| name.clone());
                    taken.insert(free.clone());
                    renamed.insert(name.clone(), free.clone());
                    free
                }
            };
            if free != name {
                field.set("T", Object::String(free, StringFormat::Literal));
            }
        }
        for (key, value) in &parts.inherited {
            if !field.has(key) {
                field.set(key.clone(), value.clone());
            }
        }
        store.put(*root, Object::Dictionary(field))?;
        fields.push(Object::Reference(*root));
    }
    form.set("Fields", fields);
    if !parts.order.is_empty() {
        let mut order = {
            let scope = store.scope(doc);
            scope.get_array(&form, b"CO").cloned().unwrap_or_default()
        };
        order.extend(parts.order);
        form.set("CO", order);
    }
    if parts.need_appearances {
        form.set("NeedAppearances", true);
    }
    // The new fields are not in the XFA packet (question 12 of the M4 plan).
    form.remove(b"XFA");
    if let Some(resources) = parts.resources {
        // shortcut: a resource name both forms use keeps the first; the /AP streams carry their own
        // resources, so this only touches an appearance regenerated later (W3).
        // The source's /DR or a category of it may be its own object, written by now.
        let scope = store.scope(doc);
        let mut merged = scope.get_dict(&form, b"DR").cloned().unwrap_or_default();
        for (category, entries) in scope.dict(&resources).into_iter().flatten() {
            let Some(entries) = scope.dict(entries) else {
                if !merged.has(category) {
                    merged.set(category.clone(), entries.clone());
                }
                continue;
            };
            let mut held = scope
                .get_dict(&merged, category)
                .cloned()
                .unwrap_or_default();
            for (key, value) in entries {
                if !held.has(key) {
                    held.set(key.clone(), value.clone());
                }
            }
            merged.set(category.clone(), held);
        }
        form.set("DR", merged);
    }
    catalog.set("AcroForm", form);
    Ok(())
}

/// Adds a source's layers to `catalog`, with those off in the source off here.
// shortcut: /AS, /RBGroups and /Locked of the source go; a reader then lets each layer be toggled
// on its own. Merge them when a file that relies on them appears.
fn merge_layers(doc: &Document, store: &RevisionStore, catalog: &mut Dictionary, layers: Layers) {
    let scope = store.scope(doc);
    let mut properties = scope
        .get_dict(catalog, b"OCProperties")
        .cloned()
        .unwrap_or_default();
    let mut config = scope
        .get_dict(&properties, b"D")
        .cloned()
        .unwrap_or_default();
    let list =
        |dict: &Dictionary, key: &[u8]| scope.get_array(dict, key).cloned().unwrap_or_default();
    let mut groups = list(&properties, b"OCGs");
    let mut order = list(&config, b"Order");
    let base_off = scope.get_name(&config, b"BaseState") == Some(b"OFF");
    let mut switched = list(&config, if base_off { b"ON" } else { b"OFF" });
    for group in layers.groups {
        groups.push(Object::Reference(group));
        if layers.off.contains(&group) != base_off {
            switched.push(Object::Reference(group));
        }
    }
    order.extend(layers.order);
    config.set(if base_off { "ON" } else { "OFF" }, switched);
    if !order.is_empty() {
        config.set("Order", order);
    }
    properties.set("OCGs", groups);
    properties.set("D", config);
    catalog.set("OCProperties", properties);
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use lopdf::Stream;

    use super::*;

    const ALL: ImportOptions = ImportOptions {
        keep_forms: true,
        document_parts: true,
    };

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

    /// Two pages under a root: each with its own content, marked 10 and 20, and what `extra` adds
    /// to the first page's dictionary and to the catalog.
    fn source(
        extra_page: Dictionary,
        catalog_extra: Dictionary,
        objects: Vec<(ObjectId, Object)>,
    ) -> Document {
        let mut model = lopdf::Document::with_version("1.7");
        let mut catalog = dictionary! { "Type" => "Catalog", "Pages" => (2, 0) };
        catalog.extend(&catalog_extra);
        model.objects.insert((1, 0), Object::Dictionary(catalog));
        model.objects.insert(
            (2, 0),
            Object::Dictionary(dictionary! {
                "Type" => "Pages", "Count" => 2,
                "Kids" => vec![Object::Reference((3, 0)), Object::Reference((4, 0))],
                "MediaBox" => vec![0.into(), 0.into(), 200.into(), 300.into()],
                "Rotate" => 90,
            }),
        );
        let mut first = dictionary! {
            "Type" => "Page", "Parent" => (2, 0), "Contents" => (5, 0),
        };
        first.extend(&extra_page);
        model.objects.insert((3, 0), Object::Dictionary(first));
        model.objects.insert(
            (4, 0),
            Object::Dictionary(dictionary! {
                "Type" => "Page", "Parent" => (2, 0), "Contents" => (6, 0),
            }),
        );
        for (id, text) in [((5, 0), "% first page\n"), ((6, 0), "% second page\n")] {
            model.objects.insert(
                id,
                // A filter of its own keeps the text readable in the output's bytes.
                Object::Stream(Stream::new(
                    dictionary! { "Filter" => "ASCII85Decode" },
                    text.as_bytes().to_vec(),
                )),
            );
        }
        for (id, object) in objects {
            model.objects.insert(id, object);
        }
        model.max_id = 100;
        opened(&mut model)
    }

    /// `pages` of `from` in a new file.
    fn assembled(from: &Document, pages: &[usize], options: ImportOptions) -> Vec<u8> {
        assembled_with(&[(from, pages, None)], options)
    }

    fn assembled_with(
        sources: &[(&Document, &[usize], Option<&str>)],
        options: ImportOptions,
    ) -> Vec<u8> {
        let doc = new_document(&Limits::default()).unwrap();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let mut order = Vec::new();
        for (from, pages, bookmark) in sources {
            let revisions = RevisionStore::new(from);
            let mut import = PageImport::new(from, &revisions, pages, options).unwrap();
            let targets = import.start(&mut store, &[]).unwrap();
            for position in 0..import.page_count() {
                import.copy_page(&doc, &mut store, position).unwrap();
            }
            import.finish(&doc, &mut store, *bookmark).unwrap();
            order.extend(targets.into_iter().map(crate::pages::PageSlot::New));
        }
        store.arrange_pages(&doc, &order).unwrap();
        store.commit().unwrap();
        store.full_rewrite(&doc).unwrap()
    }

    fn reopened(bytes: Vec<u8>) -> Document {
        open(&Source::from_bytes(bytes.into()), &OpenOptions::default()).unwrap()
    }

    fn contains(bytes: &[u8], needle: &[u8]) -> bool {
        bytes.windows(needle.len()).any(|window| window == needle)
    }

    /// Whether `bytes` hold the string `text`, which the writer puts down in hexadecimal.
    fn holds_string(bytes: &[u8], text: &[u8]) -> bool {
        let needle: Vec<u8> = text
            .iter()
            .flat_map(|byte| format!("{byte:02X}").into_bytes())
            .collect();
        contains(bytes, &needle)
    }

    #[test]
    fn a_page_takes_what_it_inherited_and_leaves_the_others_out() {
        let from = source(Dictionary::new(), Dictionary::new(), Vec::new());
        let bytes = assembled(&from, &[1], ALL);
        assert!(contains(&bytes, b"second page"));
        assert!(!contains(&bytes, b"first page"));
        let out = reopened(bytes);
        let page = &out.structure().pages[0];
        assert_eq!(out.page_count(), 1);
        assert_eq!(page.rotation, 90);
        assert_eq!(page.media_box.width(), 200.0);
    }

    #[test]
    fn what_refers_to_a_left_out_page_does_not_bring_it() {
        // A link to the other page, an annotation with a /P to it, and a font-like object with a
        // /Parent into the tree: none of them brings page 2's content.
        let from = source(
            dictionary! {
                "Annots" => vec![Object::Reference((10, 0)), Object::Reference((11, 0))],
            },
            Dictionary::new(),
            vec![
                (
                    (10, 0),
                    Object::Dictionary(dictionary! {
                        "Type" => "Annot", "Subtype" => "Link", "P" => (4, 0),
                        "Dest" => vec![Object::Reference((4, 0)), Object::Name(b"Fit".to_vec())],
                    }),
                ),
                (
                    (11, 0),
                    Object::Dictionary(dictionary! {
                        "Type" => "Annot", "Subtype" => "Text", "Parent" => (2, 0), "IRT" => (12, 0),
                    }),
                ),
                (
                    (12, 0),
                    Object::Dictionary(dictionary! {
                        "Type" => "Annot", "Subtype" => "Text", "P" => (4, 0),
                    }),
                ),
            ],
        );
        let bytes = assembled(&from, &[0], ALL);
        assert!(contains(&bytes, b"first page"));
        assert!(!contains(&bytes, b"second page"));
        let out = reopened(bytes);
        assert_eq!(out.page_count(), 1);
    }

    #[test]
    fn a_cycle_in_the_graph_ends_and_a_deep_tree_stops_at_the_limit() {
        let from = source(
            dictionary! { "Resources" => (10, 0) },
            Dictionary::new(),
            vec![
                (
                    (10, 0),
                    Object::Dictionary(dictionary! { "XObject" => dictionary! { "A" => (11, 0) } }),
                ),
                (
                    (11, 0),
                    Object::Dictionary(dictionary! { "Self" => (11, 0), "Back" => (10, 0) }),
                ),
            ],
        );
        assert_eq!(reopened(assembled(&from, &[0], ALL)).page_count(), 1);

        let limits = Limits {
            max_nesting: 8,
            ..Limits::default()
        };
        let mut deep = Object::Integer(1);
        for _ in 0..32 {
            deep = Object::Array(vec![deep]);
        }
        let mut model = lopdf::Document::with_version("1.7");
        model.objects.insert(
            (1, 0),
            Object::Dictionary(dictionary! { "Type" => "Catalog", "Pages" => (2, 0) }),
        );
        model.objects.insert(
            (2, 0),
            Object::Dictionary(dictionary! {
                "Type" => "Pages", "Count" => 1, "Kids" => vec![Object::Reference((3, 0))],
            }),
        );
        model.objects.insert(
            (3, 0),
            Object::Dictionary(
                dictionary! { "Type" => "Page", "Parent" => (2, 0), "Deep" => deep },
            ),
        );
        model.max_id = 3;
        model.trailer.set("Root", (1, 0));
        let mut bytes = Vec::new();
        model.save_to(&mut bytes).unwrap();
        let from = open(
            &Source::from_bytes(bytes.into()),
            &OpenOptions {
                password: None,
                limits: limits.clone(),
            },
        )
        .unwrap();
        let revisions = RevisionStore::new(&from);
        let doc = new_document(&limits).unwrap();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let mut import = PageImport::new(&from, &revisions, &[0], ALL).unwrap();
        import.start(&mut store, &[]).unwrap();
        assert!(matches!(
            import.copy_page(&doc, &mut store, 0),
            Err(CoreError::ResourceLimit {
                limit: LimitKind::Nesting,
                ..
            })
        ));
    }

    /// Two pages each with a widget of one text field `shared`, and a signature field on page 1.
    fn with_form() -> Document {
        source(
            dictionary! { "Annots" => vec![Object::Reference((11, 0)), Object::Reference((13, 0))] },
            dictionary! { "AcroForm" => dictionary! {
                "Fields" => vec![Object::Reference((10, 0)), Object::Reference((13, 0))],
                "DA" => Object::String(b"/Helv 0 Tf".to_vec(), StringFormat::Literal),
                "SigFlags" => 3,
            }},
            vec![
                (
                    (10, 0),
                    Object::Dictionary(dictionary! {
                        "T" => Object::String(b"shared".to_vec(), StringFormat::Literal),
                        "FT" => "Tx",
                        "V" => Object::String(b"value".to_vec(), StringFormat::Literal),
                        "Kids" => vec![Object::Reference((11, 0)), Object::Reference((12, 0))],
                    }),
                ),
                (
                    (11, 0),
                    Object::Dictionary(dictionary! {
                        "Subtype" => "Widget", "Parent" => (10, 0), "P" => (3, 0),
                    }),
                ),
                (
                    (12, 0),
                    Object::Dictionary(dictionary! {
                        "Subtype" => "Widget", "Parent" => (10, 0), "P" => (4, 0),
                        "MK" => dictionary! {
                            "CA" => Object::String(b"on the other page".to_vec(), StringFormat::Literal),
                        },
                    }),
                ),
                (
                    (13, 0),
                    Object::Dictionary(dictionary! {
                        "Subtype" => "Widget", "FT" => "Sig", "P" => (3, 0),
                        "T" => Object::String(b"sig".to_vec(), StringFormat::Literal),
                        "V" => dictionary! {
                            "Contents" => Object::String(b"signature bytes".to_vec(), StringFormat::Hexadecimal),
                        },
                    }),
                ),
            ],
        )
    }

    /// A target with /Helv in its form, and a source whose /DR is held in objects of their own.
    #[test]
    fn a_source_with_indirect_form_resources_adds_to_what_the_target_has() {
        let helv = dictionary! { "Type" => "Font", "BaseFont" => "Helvetica" };
        let other = dictionary! { "Type" => "Font", "BaseFont" => "Courier" };
        let widget = |page: ObjectId| {
            Object::Dictionary(dictionary! {
                "Subtype" => "Widget", "FT" => "Tx", "P" => page,
                "T" => Object::String(b"field".to_vec(), StringFormat::Literal),
            })
        };
        let annots = dictionary! { "Annots" => vec![Object::Reference((10, 0))] };
        let target = source(
            annots.clone(),
            dictionary! { "AcroForm" => dictionary! {
                "Fields" => vec![Object::Reference((10, 0))],
                "DR" => dictionary! { "Font" => dictionary! { "Helv" => (41, 0) } },
            }},
            vec![
                ((10, 0), widget((3, 0))),
                ((41, 0), Object::Dictionary(helv)),
            ],
        );
        // Both ways of holding it: the whole /DR, or only its /Font.
        for (dr, extra) in [
            (
                Object::Reference((30, 0)),
                (
                    (30, 0),
                    Object::Dictionary(dictionary! {
                        "Font" => dictionary! { "Other" => (55, 0) },
                    }),
                ),
            ),
            (
                Object::Dictionary(dictionary! { "Font" => (30, 0) }),
                (
                    (30, 0),
                    Object::Dictionary(dictionary! { "Other" => (55, 0) }),
                ),
            ),
        ] {
            let from = source(
                annots.clone(),
                dictionary! { "AcroForm" => dictionary! {
                    "Fields" => vec![Object::Reference((10, 0))],
                    "DR" => dr,
                }},
                vec![
                    ((10, 0), widget((3, 0))),
                    ((55, 0), Object::Dictionary(other.clone())),
                    extra,
                ],
            );
            let revisions = RevisionStore::new(&from);
            let mut store = RevisionStore::new(&target);
            store.begin().unwrap();
            let mut import = PageImport::new(&from, &revisions, &[0], ALL).unwrap();
            import.start(&mut store, &[]).unwrap();
            import.copy_page(&target, &mut store, 0).unwrap();
            import.finish(&target, &mut store, None).unwrap();
            store.commit().unwrap();
            let scope = store.scope(&target);
            let form = scope
                .get_dict(scope.catalog().unwrap(), b"AcroForm")
                .unwrap();
            let resources = scope.get_dict(form, b"DR").unwrap();
            let fonts = scope.get_dict(resources, b"Font").unwrap();
            assert!(fonts.has(b"Helv"), "the target keeps its own font");
            assert!(fonts.has(b"Other"), "the source's font comes along");
        }
    }

    /// A page taking over an object under a /Pages node that rotates and crops draws as in its
    /// source, and the widgets of the page it replaced leave the form with their values.
    #[test]
    fn a_replacing_page_takes_nothing_from_its_new_parent_and_the_old_widgets_go() {
        let mut model = lopdf::Document::with_version("1.7");
        model.objects.insert(
            (1, 0),
            Object::Dictionary(dictionary! {
                "Type" => "Catalog", "Pages" => (2, 0),
                "AcroForm" => dictionary! { "Fields" => vec![Object::Reference((10, 0))] },
            }),
        );
        model.objects.insert(
            (2, 0),
            Object::Dictionary(dictionary! {
                "Type" => "Pages", "Count" => 1, "Kids" => vec![Object::Reference((3, 0))],
                "Rotate" => 90,
                "MediaBox" => vec![0.into(), 0.into(), 100.into(), 100.into()],
                "CropBox" => vec![0.into(), 0.into(), 50.into(), 50.into()],
            }),
        );
        model.objects.insert(
            (3, 0),
            Object::Dictionary(dictionary! {
                "Type" => "Page", "Parent" => (2, 0),
                "Annots" => vec![Object::Reference((10, 0))],
            }),
        );
        model.objects.insert(
            (10, 0),
            Object::Dictionary(dictionary! {
                "Subtype" => "Widget", "FT" => "Tx", "P" => (3, 0),
                "T" => Object::String(b"old".to_vec(), StringFormat::Literal),
                "V" => Object::String(b"SECRET-VALUE".to_vec(), StringFormat::Literal),
            }),
        );
        model.max_id = 20;
        let target = opened(&mut model);

        let mut model = lopdf::Document::with_version("1.7");
        model.objects.insert(
            (1, 0),
            Object::Dictionary(dictionary! { "Type" => "Catalog", "Pages" => (2, 0) }),
        );
        model.objects.insert(
            (2, 0),
            Object::Dictionary(dictionary! {
                "Type" => "Pages", "Count" => 1, "Kids" => vec![Object::Reference((3, 0))],
            }),
        );
        model.objects.insert(
            (3, 0),
            Object::Dictionary(dictionary! {
                "Type" => "Page", "Parent" => (2, 0),
                "MediaBox" => vec![0.into(), 0.into(), 200.into(), 300.into()],
            }),
        );
        model.max_id = 3;
        let from = opened(&mut model);

        let revisions = RevisionStore::new(&from);
        let mut store = RevisionStore::new(&target);
        store.begin().unwrap();
        let refs = store.page_refs(&target, &[0]).unwrap();
        let mut import = PageImport::new(&from, &revisions, &[0], ALL).unwrap();
        import.start(&mut store, &refs).unwrap();
        import.copy_page(&target, &mut store, 0).unwrap();
        import.finish(&target, &mut store, None).unwrap();
        store
            .arrange_pages(&target, &[crate::pages::PageSlot::Page(0)])
            .unwrap();
        store.commit().unwrap();
        let page = &store.pages(&target)[0];
        assert_eq!(page.rotation, 0);
        assert_eq!(page.size, (200.0, 300.0));
        let bytes = store.full_rewrite(&target).unwrap();
        assert!(!holds_string(&bytes, b"SECRET-VALUE"));
        store.undo().unwrap();
        assert_eq!(store.pages(&target)[0].rotation, 90);
        assert!(holds_string(
            &store.full_rewrite(&target).unwrap(),
            b"SECRET-VALUE"
        ));
    }

    /// What the file's size says holds on what has no filter too, tiny or not.
    #[test]
    fn the_assembled_size_is_never_below_the_file() {
        let plain = |text: &[u8]| Object::Stream(Stream::new(Dictionary::new(), text.to_vec()));
        let from = source(
            dictionary! { "Contents" => vec![
                Object::Reference((20, 0)),
                Object::Reference((5, 0)),
                Object::Reference((21, 0)),
            ] },
            Dictionary::new(),
            vec![((20, 0), plain(b"q")), ((21, 0), plain(&[b'Q'; 3000]))],
        );
        let revisions = RevisionStore::new(&from);
        for pages in [&[0usize][..], &[1], &[0, 1]] {
            let size = assembled_size(&from, &revisions, pages, ALL).unwrap();
            let real = assembled(&from, pages, ALL).len() as u64;
            assert!(size >= real, "{pages:?}: {size} against {real}");
            assert!(size <= real * 2 + 4096, "{pages:?}: {size} against {real}");
        }
    }

    fn field_names(doc: &Document) -> Vec<String> {
        let store = RevisionStore::new(doc);
        let scope = store.scope(doc);
        let form = scope
            .get_dict(scope.catalog().unwrap(), b"AcroForm")
            .unwrap();
        scope
            .get_array(form, b"Fields")
            .unwrap()
            .iter()
            .map(|field| scope.get_text(scope.dict(field).unwrap(), b"T").unwrap())
            .collect()
    }

    #[test]
    fn a_field_keeps_only_the_widgets_of_the_copied_pages_and_a_signature_goes() {
        let from = with_form();
        let bytes = assembled(&from, &[0], ALL);
        assert!(!holds_string(&bytes, b"on the other page"));
        let out = reopened(bytes);
        assert_eq!(field_names(&out), ["shared", "sig"]);
        assert!(!out.structure().signed());
        let store = RevisionStore::new(&out);
        let scope = store.scope(&out);
        let form = scope
            .get_dict(scope.catalog().unwrap(), b"AcroForm")
            .unwrap();
        let shared = scope
            .dict(&scope.get_array(form, b"Fields").unwrap()[0])
            .unwrap();
        assert_eq!(scope.get_array(shared, b"Kids").unwrap().len(), 1);
        assert_eq!(scope.get_text(shared, b"DA").unwrap(), "/Helv 0 Tf");
    }

    #[test]
    fn the_same_file_twice_gets_its_second_fields_renamed() {
        let from = with_form();
        let out = reopened(assembled_with(
            &[(&from, &[0, 1], None), (&from, &[0, 1], None)],
            ALL,
        ));
        assert_eq!(out.page_count(), 4);
        assert_eq!(
            field_names(&out),
            ["shared", "sig", "shared (2)", "sig (2)"]
        );
    }

    #[test]
    fn without_forms_no_widget_or_field_comes() {
        let from = with_form();
        let bytes = assembled(
            &from,
            &[0, 1],
            ImportOptions {
                keep_forms: false,
                document_parts: true,
            },
        );
        assert!(!contains(&bytes, b"Widget"));
        assert!(!contains(&bytes, b"AcroForm"));
    }

    #[test]
    fn a_named_destination_is_written_out_and_kept_only_for_a_copied_page() {
        let from = source(
            dictionary! { "Annots" => vec![Object::Reference((10, 0)), Object::Reference((11, 0))] },
            dictionary! { "Names" => dictionary! { "Dests" => dictionary! { "Names" => vec![
                Object::String(b"one".to_vec(), StringFormat::Literal),
                Object::Array(vec![Object::Reference((3, 0)), Object::Name(b"Fit".to_vec())]),
                Object::String(b"two".to_vec(), StringFormat::Literal),
                Object::Array(vec![Object::Reference((4, 0)), Object::Name(b"Fit".to_vec())]),
            ]}}},
            vec![
                (
                    (10, 0),
                    Object::Dictionary(dictionary! {
                        "Subtype" => "Link",
                        "Dest" => Object::String(b"one".to_vec(), StringFormat::Literal),
                    }),
                ),
                (
                    (11, 0),
                    Object::Dictionary(dictionary! {
                        "Subtype" => "Link",
                        "A" => dictionary! {
                            "S" => "GoTo",
                            "D" => Object::String(b"two".to_vec(), StringFormat::Literal),
                        },
                    }),
                ),
            ],
        );
        let out = reopened(assembled(&from, &[0], ALL));
        let store = RevisionStore::new(&out);
        let scope = store.scope(&out);
        let dests = names(&scope, b"Dests");
        assert_eq!(dests.len(), 1);
        assert_eq!(dests[0].0, b"one");
        let page = scope.dictionary(out.structure().pages[0].id).unwrap();
        let annots = scope.get_array(page, b"Annots").unwrap();
        let first = scope.dict(&annots[0]).unwrap();
        assert!(matches!(
            scope.get(first, b"Dest"),
            Some(Object::Array(items)) if matches!(items[0], Object::Reference(_))
        ));
        let second = scope.dict(&annots[1]).unwrap();
        let action = scope.get_dict(second, b"A").unwrap();
        assert!(matches!(
            scope.get(action, b"D"),
            Some(Object::Array(items)) if items[0] == Object::Null
        ));
    }

    #[test]
    fn attachments_are_kept_with_a_number_for_a_clash_and_only_when_asked() {
        let from = source(
            Dictionary::new(),
            dictionary! { "Names" => dictionary! { "EmbeddedFiles" => dictionary! { "Names" => vec![
                Object::String(b"a.txt".to_vec(), StringFormat::Literal),
                Object::Reference((10, 0)),
            ]}}},
            vec![
                (
                    (10, 0),
                    Object::Dictionary(dictionary! {
                        "Type" => "Filespec",
                        "F" => Object::String(b"a.txt".to_vec(), StringFormat::Literal),
                        "EF" => dictionary! { "F" => (11, 0) },
                    }),
                ),
                (
                    (11, 0),
                    Object::Stream(Stream::new(Dictionary::new(), b"attached".to_vec())),
                ),
            ],
        );
        let out = reopened(assembled_with(
            &[(&from, &[0], None), (&from, &[1], None)],
            ALL,
        ));
        let store = RevisionStore::new(&out);
        let scope = store.scope(&out);
        let keys: Vec<&[u8]> = names(&scope, b"EmbeddedFiles")
            .into_iter()
            .map(|(key, _)| key)
            .collect();
        assert_eq!(keys, [&b"a (2).txt"[..], b"a.txt"]);
        assert_eq!(out.structure().attachments.len(), 2);

        let without = assembled(
            &from,
            &[0],
            ImportOptions {
                keep_forms: true,
                document_parts: false,
            },
        );
        assert!(!contains(&without, b"Filespec"));
    }

    #[test]
    fn layers_of_the_copied_pages_merge_with_their_state() {
        let group = |number: u32| {
            (
                (number, 0),
                Object::Dictionary(dictionary! {
                    "Type" => "OCG",
                    "Name" => Object::String(format!("layer {number}").into_bytes(), StringFormat::Literal),
                }),
            )
        };
        let from = source(
            dictionary! { "Resources" => dictionary! {
                "Properties" => dictionary! { "A" => (10, 0), "B" => (11, 0) },
            }},
            dictionary! { "OCProperties" => dictionary! {
                "OCGs" => vec![Object::Reference((10, 0)), Object::Reference((11, 0)), Object::Reference((12, 0))],
                "D" => dictionary! {
                    "OFF" => vec![Object::Reference((11, 0))],
                    "Order" => vec![
                        Object::Reference((10, 0)),
                        Object::Reference((11, 0)),
                        Object::Array(vec![
                            Object::String(b"nested".to_vec(), StringFormat::Literal),
                            Object::Reference((12, 0)),
                        ]),
                    ],
                },
            }},
            vec![group(10), group(11), group(12)],
        );
        let out = reopened(assembled_with(
            &[(&from, &[0], None), (&from, &[0, 1], None)],
            ALL,
        ));
        let layers = &out.structure().layers;
        assert_eq!(layers.len(), 4);
        assert_eq!(layers.iter().filter(|layer| !layer.visible).count(), 2);
    }

    #[test]
    fn bookmarks_follow_the_copied_pages_under_a_file_bookmark() {
        let title = |text: &str| Object::String(text.as_bytes().to_vec(), StringFormat::Literal);
        let from = source(
            Dictionary::new(),
            dictionary! { "Outlines" => (10, 0) },
            vec![
                (
                    (10, 0),
                    Object::Dictionary(dictionary! {
                        "Type" => "Outlines", "First" => (11, 0), "Last" => (12, 0), "Count" => 2,
                    }),
                ),
                (
                    (11, 0),
                    Object::Dictionary(dictionary! {
                        "Title" => title("one"), "Parent" => (10, 0), "Next" => (12, 0),
                        "Dest" => vec![Object::Reference((3, 0)), Object::Name(b"Fit".to_vec())],
                    }),
                ),
                (
                    (12, 0),
                    Object::Dictionary(dictionary! {
                        "Title" => title("two"), "Parent" => (10, 0), "Prev" => (11, 0),
                        "Next" => (11, 0),
                        "Dest" => vec![Object::Reference((4, 0)), Object::Name(b"Fit".to_vec())],
                    }),
                ),
            ],
        );
        let out = reopened(assembled_with(
            &[(&from, &[1], Some("First file")), (&from, &[0, 1], None)],
            ALL,
        ));
        let outline = &out.structure().outline;
        assert_eq!(
            outline
                .iter()
                .map(|item| item.title.as_str())
                .collect::<Vec<_>>(),
            ["First file", "one", "two"]
        );
        assert_eq!(outline[0].page, Some(0));
        assert_eq!(outline[0].children.len(), 1);
        assert_eq!(outline[0].children[0].title, "two");
        assert_eq!(outline[1].page, Some(1));
        assert_eq!(outline[2].page, Some(2));
    }

    #[test]
    fn a_page_taking_over_an_object_keeps_its_place_and_references() {
        let target = source(Dictionary::new(), Dictionary::new(), Vec::new());
        let from = source(
            dictionary! { "Rotate" => 180 },
            Dictionary::new(),
            Vec::new(),
        );
        let revisions = RevisionStore::new(&from);
        let mut store = RevisionStore::new(&target);
        store.begin().unwrap();
        let old = store.page_refs(&target, &[0]).unwrap();
        let mut import = PageImport::new(&from, &revisions, &[0], ALL).unwrap();
        assert_eq!(import.start(&mut store, &old).unwrap(), old);
        import.copy_page(&target, &mut store, 0).unwrap();
        import.finish(&target, &mut store, None).unwrap();
        store.commit().unwrap();
        let pages = store.pages(&target);
        assert_eq!(pages.len(), 2);
        assert_eq!(pages[0].rotation, 180);
        assert_eq!(pages[0].id, (3, 0));
        store.undo().unwrap();
        assert_eq!(store.pages(&target)[0].rotation, 90);
    }

    #[test]
    fn weighing_counts_shared_objects_once_per_file() {
        let from = source(Dictionary::new(), Dictionary::new(), Vec::new());
        let revisions = RevisionStore::new(&from);
        let mut import = PageImport::new(&from, &revisions, &[0, 1], ALL).unwrap();
        let first = import.weigh(0).unwrap();
        let second = import.weigh(1).unwrap();
        import.reset_weights();
        assert_eq!(import.weigh(0).unwrap(), first);
        assert!(first > 0 && second > 0);
        let real = assembled(&from, &[0, 1], ALL).len() as u64;
        assert!(first + second < real, "{first} + {second} against {real}");
    }

    /// The decoded streams of `doc`, whatever they are.
    fn streams(doc: &Document) -> Vec<Vec<u8>> {
        doc.model()
            .objects
            .values()
            .filter_map(|object| match object {
                Object::Stream(stream) => crate::revision::decoded(stream, doc).ok(),
                _ => None,
            })
            .collect()
    }

    /// M4 plan's risk: pages left out of an extract must not come along, through links, bookmarks,
    /// form fields or anything else. On the two corpus files with the most that leads elsewhere.
    #[test]
    fn nothing_of_a_page_left_out_is_in_the_file() {
        for (name, kept) in [("tez-tr", 20), ("form-aks1-tr", 0), ("kira-tr", 1)] {
            let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
                .join("../../tests/corpus/generated")
                .join(format!("{name}.pdf"));
            let from = open(&Source::read(&path).unwrap(), &OpenOptions::default()).unwrap();
            let revisions = RevisionStore::new(&from);
            let out = reopened(assembled(
                &from,
                &[kept],
                ImportOptions {
                    keep_forms: true,
                    document_parts: false,
                },
            ));
            let written = streams(&out);
            assert!(!written.is_empty());
            let kept_id = from.structure().pages[kept].id;
            let mine = revisions.contents(&from, kept_id);
            for page in &from.structure().pages {
                if page.id == kept_id {
                    continue;
                }
                for id in revisions.contents(&from, page.id) {
                    if mine.contains(&id) {
                        continue;
                    }
                    let Some(Object::Stream(stream)) = from.model().objects.get(&id) else {
                        continue;
                    };
                    let content = crate::revision::decoded(stream, &from).unwrap();
                    assert!(
                        !written.contains(&content),
                        "{name}: the content of page {} came along",
                        page.index
                    );
                }
            }
        }
    }

    #[test]
    fn an_empty_or_repeated_selection_is_refused() {
        let from = source(Dictionary::new(), Dictionary::new(), Vec::new());
        let revisions = RevisionStore::new(&from);
        for pages in [&[][..], &[0, 0]] {
            assert!(matches!(
                PageImport::new(&from, &revisions, pages, ALL),
                Err(CoreError::Write(WriteError::PagePlan))
            ));
        }
        assert!(matches!(
            PageImport::new(&from, &revisions, &[9], ALL),
            Err(CoreError::Write(WriteError::NoSuchPage))
        ));
    }
}
