//! The revision store (docs/ARCHITECTURE.md §3.6 and §6.6, ADR 0005): the changes made to an
//! opened document, kept as an overlay over its lopdf model, which never changes.
//!
//! A [`ChangeSet`] is the set of objects one commit replaces or adds. The store keeps a stack of
//! them: [`begin`](RevisionStore::begin) opens a transaction, the splicer puts objects into it,
//! [`commit`](RevisionStore::commit) makes it the newest revision (dropping the redo branch) and
//! [`rollback`](RevisionStore::rollback) discards it. Undo and redo move the current revision;
//! reading an object goes through the open transaction, then the revisions up to the current one,
//! newest first, then the model. New objects take numbers above the trailer's `/Size` and every
//! object the revisions hold.
//!
//! The splicer ([`RevisionStore::splice`]) replaces byte ranges of content streams' decoded data
//! and writes each changed stream back as a new version, compressed with Flate: every byte
//! outside the ranges stays identical. A page's content stream that another page shares becomes a
//! new object, and only this page's `/Contents` points at it. A form is copied for the one
//! placement edited (copy-on-write, ADR 0005): the copy gets a new name in the page's resources
//! and the placement's `Do` draws it, so the form's other placements stay as they were.
//!
//! The incremental writer ([`RevisionStore::incremental_update`]) is in the `incremental` module.
// Ranges come from the caller and lengths from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeMap;
use std::io::Write as _;
use std::ops::Range;

use lopdf::{Dictionary, Object, ObjectId, Stream};

use crate::interpret::{Span, SpanSource, TextSink};
use crate::structure::{Scope, inherited};
use crate::{CoreError, Document, WriteError, appendix, content, filters};

/// The objects one commit replaces or adds, by object id.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ChangeSet {
    objects: BTreeMap<ObjectId, Object>,
}

impl ChangeSet {
    /// The ids of the objects it changes, in order.
    pub fn ids(&self) -> impl Iterator<Item = ObjectId> + '_ {
        self.objects.keys().copied()
    }

    /// How many objects it changes.
    #[must_use]
    pub fn len(&self) -> usize {
        self.objects.len()
    }

    /// Whether it changes nothing.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.objects.is_empty()
    }
}

/// One replacement in a content stream: `range` of the decoded data of `source`, as the
/// interpreter's [`Span`]s give it, becomes `bytes`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Splice {
    /// The stream.
    pub source: SpanSource,
    /// The bytes replaced, in the stream's decoded data.
    pub range: Range<usize>,
    /// What replaces them.
    pub bytes: Vec<u8>,
}

/// Where a form whose content is spliced is drawn: its `Do` operator, in one of the page's
/// content streams.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Placement {
    /// The form.
    pub form: ObjectId,
    /// The `Do` operator that draws it.
    pub draw: Span,
}

/// The revisions of one opened document. It belongs to that document: every method takes the
/// [`Document`] it was made for.
#[derive(Debug, Clone, Default)]
pub struct RevisionStore {
    /// The committed revisions, oldest first; those after `current` are the redo branch.
    revisions: Vec<ChangeSet>,
    /// How many revisions apply.
    current: usize,
    /// The open transaction.
    open: Option<ChangeSet>,
    /// The first number past the document's objects.
    base_size: u32,
}

impl RevisionStore {
    /// An empty store for `doc`.
    #[must_use]
    pub fn new(doc: &Document) -> Self {
        let highest = doc
            .model()
            .objects
            .keys()
            .next_back()
            .map_or(1, |(number, _)| number.saturating_add(1));
        Self {
            base_size: doc.xref().size.max(highest),
            ..Self::default()
        }
    }

    /// Opens a transaction.
    ///
    /// # Errors
    ///
    /// [`WriteError::TransactionOpen`] when one is open already.
    pub fn begin(&mut self) -> Result<(), CoreError> {
        if self.open.is_some() {
            return Err(CoreError::Write(WriteError::TransactionOpen));
        }
        self.open = Some(ChangeSet::default());
        Ok(())
    }

    /// Whether a transaction is open.
    #[must_use]
    pub fn in_transaction(&self) -> bool {
        self.open.is_some()
    }

    /// Makes the open transaction the newest revision and drops the redo branch; a transaction
    /// that changed nothing adds no revision. Returns the current revision.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`].
    pub fn commit(&mut self) -> Result<usize, CoreError> {
        let changes = self
            .open
            .take()
            .ok_or(CoreError::Write(WriteError::NoTransaction))?;
        if !changes.is_empty() {
            self.revisions.truncate(self.current);
            self.revisions.push(changes);
            self.current = self.revisions.len();
        }
        Ok(self.current)
    }

    /// Discards the open transaction, if any.
    pub fn rollback(&mut self) {
        self.open = None;
    }

    /// Steps back one revision; returns the current one.
    ///
    /// # Errors
    ///
    /// [`WriteError::TransactionOpen`] and [`WriteError::NothingToUndo`].
    pub fn undo(&mut self) -> Result<usize, CoreError> {
        self.closed()?;
        self.current = self
            .current
            .checked_sub(1)
            .ok_or(CoreError::Write(WriteError::NothingToUndo))?;
        Ok(self.current)
    }

    /// Steps forward one revision of the redo branch; returns the current one.
    ///
    /// # Errors
    ///
    /// [`WriteError::TransactionOpen`] and [`WriteError::NothingToRedo`].
    pub fn redo(&mut self) -> Result<usize, CoreError> {
        self.closed()?;
        if self.current >= self.revisions.len() {
            return Err(CoreError::Write(WriteError::NothingToRedo));
        }
        self.current = self.current.saturating_add(1);
        Ok(self.current)
    }

    /// How many revisions apply: 0 is the document as opened.
    #[must_use]
    pub fn current(&self) -> usize {
        self.current
    }

    /// The committed revisions, oldest first, the redo branch included.
    #[must_use]
    pub fn revisions(&self) -> &[ChangeSet] {
        &self.revisions
    }

    /// Interprets page `index` as [`Document::page_text`] does, with the current revision's
    /// objects and the open transaction's.
    ///
    /// # Errors
    ///
    /// Those of [`Document::page_text`].
    pub fn page_text(
        &self,
        doc: &Document,
        index: usize,
        sink: &mut dyn TextSink,
    ) -> Result<(), CoreError> {
        doc.page_text_through(Some(self), index, sink)
    }

    /// Replaces `splices` in page `index`'s content, in the open transaction. Each changed
    /// stream is written back as a new version compressed with Flate; a page stream that another
    /// page shares becomes a new object that only this page's `/Contents` names. A form is
    /// copied for its placement in `placements`, which then draws the copy; a copy made earlier
    /// changes in place. On an error the transaction stays as it was.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::NoSuchPage`],
    /// [`WriteError::OverlappingSplices`], [`WriteError::SpliceOutsideStream`],
    /// [`WriteError::NotAStream`], [`WriteError::Placement`], [`WriteError::NotOnPage`],
    /// [`WriteError::ObjectNumbers`], and the errors of decoding a stream within the
    /// document's limits.
    pub fn splice(
        &mut self,
        doc: &Document,
        index: usize,
        splices: &[Splice],
        placements: &[Placement],
    ) -> Result<(), CoreError> {
        if self.open.is_none() {
            return Err(CoreError::Write(WriteError::NoTransaction));
        }
        let page = doc
            .structure()
            .pages
            .get(index)
            .map(|page| page.id)
            .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
        let on_page = self.contents(doc, page);
        let mut streams: Vec<(ObjectId, Edits)> = Vec::new();
        let mut forms: Vec<(ObjectId, Edits)> = Vec::new();
        for splice in splices {
            let (list, id) = match splice.source {
                SpanSource::Page { stream } => (&mut streams, stream),
                SpanSource::Form { form } => (&mut forms, form),
            };
            group(list, id, splice.range.clone(), splice.bytes.clone());
        }

        // The changes enter the transaction only when the whole splice succeeds.
        let mut queued: Vec<(ObjectId, Object)> = Vec::new();
        let mut next = self.next_number();
        // Each form edited becomes a copy that its placement draws under a new name.
        let mut names: Vec<(Vec<u8>, ObjectId)> = Vec::new();
        for (form, edits) in forms {
            let placement = placements
                .iter()
                .find(|placement| placement.form == form)
                .ok_or(CoreError::Write(WriteError::Placement))?;
            let (SpanSource::Page { stream }, false) =
                (placement.draw.source, placement.draw.carried)
            else {
                // shortcut: a form drawn inside another form is not copied; ferman-text reports
                // such blocks as not editable until the copy follows the chain of placements.
                return Err(CoreError::Write(WriteError::Placement));
            };
            if !on_page.contains(&stream) {
                return Err(CoreError::Write(WriteError::NotOnPage));
            }
            let name = self.drawn_name(doc, page, stream, &placement.draw.range, form)?;
            let copy = Object::Stream(respliced(&self.stream(doc, form)?, &edits, doc)?);
            // A copy this store made is drawn by this placement only, so it changes in place.
            if form.0 >= self.base_size {
                queued.push((form, copy));
                continue;
            }
            let copy = queue_new(&mut queued, &mut next, copy)?;
            let fresh = self.fresh_name(doc, page, &name, &names)?;
            let mut draw = Vec::new();
            appendix::name(&mut draw, &fresh);
            draw.extend_from_slice(b" Do");
            group(&mut streams, stream, placement.draw.range.clone(), draw);
            names.push((fresh, copy));
        }

        let mut dict = self.dictionary(doc, page)?;
        let mut page_changed = !names.is_empty();
        for (stream, edits) in streams {
            if !on_page.contains(&stream) {
                return Err(CoreError::Write(WriteError::NotOnPage));
            }
            let new = Object::Stream(respliced(&self.stream(doc, stream)?, &edits, doc)?);
            let shared =
                doc.structure().pages.iter().any(|other| {
                    other.id != page && self.contents(doc, other.id).contains(&stream)
                });
            if shared {
                let id = queue_new(&mut queued, &mut next, new)?;
                let contents = match dict.get(b"Contents") {
                    Ok(Object::Reference(old)) if *old == stream => Object::Reference(id),
                    Ok(contents) => {
                        let mut items = self
                            .scope(doc)
                            .resolve(contents)
                            .and_then(|items| items.as_array().ok())
                            .cloned()
                            .unwrap_or_default();
                        for item in &mut items {
                            if item.as_reference().ok() == Some(stream) {
                                *item = Object::Reference(id);
                            }
                        }
                        Object::Array(items)
                    }
                    Err(_) => Object::Reference(id),
                };
                dict.set("Contents", contents);
                page_changed = true;
            } else {
                queued.push((stream, new));
            }
        }
        if !names.is_empty() {
            let (mut resources, mut xobjects) = self.page_xobjects(doc, page);
            for (name, id) in names {
                xobjects.set(name, Object::Reference(id));
            }
            resources.set("XObject", xobjects);
            dict.set("Resources", resources);
        }
        if page_changed {
            queued.push((page, Object::Dictionary(dict)));
        }
        for (id, object) in queued {
            self.put(id, object)?;
        }
        Ok(())
    }

    /// Object `id` in the open transaction or the current revisions, without the model's.
    pub(crate) fn lookup(&self, id: ObjectId) -> Option<&Object> {
        self.open
            .iter()
            .chain(
                self.revisions
                    .get(..self.current)
                    .unwrap_or_default()
                    .iter()
                    .rev(),
            )
            .find_map(|changes| changes.objects.get(&id))
    }

    /// The newest version of every object the current revisions change.
    pub(crate) fn committed(&self) -> BTreeMap<ObjectId, &Object> {
        let mut objects = BTreeMap::new();
        for changes in self.revisions.get(..self.current).unwrap_or_default() {
            for (id, object) in &changes.objects {
                objects.insert(*id, object);
            }
        }
        objects
    }

    /// Fails while a transaction is open.
    pub(crate) fn closed(&self) -> Result<(), CoreError> {
        if self.open.is_some() {
            return Err(CoreError::Write(WriteError::TransactionOpen));
        }
        Ok(())
    }

    /// The first object number no object uses: past the document's and the revisions'.
    pub(crate) fn next_number(&self) -> u32 {
        self.open
            .iter()
            .chain(self.revisions.get(..self.current).unwrap_or_default())
            .filter_map(|changes| changes.objects.keys().next_back())
            .map(|(number, _)| number.saturating_add(1))
            .fold(self.base_size, u32::max)
    }

    /// Puts `object` as the new version of `id` in the open transaction.
    pub(crate) fn put(&mut self, id: ObjectId, object: Object) -> Result<(), CoreError> {
        let open = self
            .open
            .as_mut()
            .ok_or(CoreError::Write(WriteError::NoTransaction))?;
        open.objects.insert(id, object);
        Ok(())
    }

    /// Adds `object` as a new object in the open transaction (the splicer queues its own).
    #[cfg(test)]
    pub(crate) fn add(&mut self, object: Object) -> Result<ObjectId, CoreError> {
        let id = (free(self.next_number())?, 0);
        self.put(id, object)?;
        Ok(id)
    }

    /// A scope that reads through this store.
    fn scope<'a>(&'a self, doc: &'a Document) -> Scope<'a> {
        Scope {
            doc: doc.model(),
            limits: doc.limits(),
            page_of: BTreeMap::new(),
            annotation_page: BTreeMap::new(),
            overlay: Some(self),
        }
    }

    /// A copy of stream `id`'s newest version.
    fn stream(&self, doc: &Document, id: ObjectId) -> Result<Stream, CoreError> {
        match self.scope(doc).object(id) {
            Some(Object::Stream(stream)) => Ok(stream.clone()),
            _ => Err(CoreError::Write(WriteError::NotAStream { object: id.0 })),
        }
    }

    /// A copy of page `id`'s newest dictionary.
    fn dictionary(&self, doc: &Document, id: ObjectId) -> Result<Dictionary, CoreError> {
        match self.scope(doc).object(id) {
            Some(Object::Dictionary(dict)) => Ok(dict.clone()),
            _ => Err(CoreError::Write(WriteError::NoSuchPage)),
        }
    }

    /// The streams of page `id`'s `/Contents`.
    fn contents(&self, doc: &Document, id: ObjectId) -> Vec<ObjectId> {
        let scope = self.scope(doc);
        let Some(Object::Dictionary(dict)) = scope.object(id) else {
            return Vec::new();
        };
        match dict.get(b"Contents") {
            Ok(Object::Reference(stream))
                if matches!(scope.object(*stream), Some(Object::Stream(_))) =>
            {
                vec![*stream]
            }
            Ok(contents) => scope
                .resolve(contents)
                .and_then(|items| items.as_array().ok())
                .map(|items| {
                    items
                        .iter()
                        .filter_map(|item| item.as_reference().ok())
                        .collect()
                })
                .unwrap_or_default(),
            Err(_) => Vec::new(),
        }
    }

    /// Copies of page `id`'s inherited `/Resources` and of their `/XObject`, both direct.
    fn page_xobjects(&self, doc: &Document, id: ObjectId) -> (Dictionary, Dictionary) {
        let scope = self.scope(doc);
        let Some(Object::Dictionary(dict)) = scope.object(id) else {
            return (Dictionary::new(), Dictionary::new());
        };
        let resources =
            inherited(&scope, dict, b"Resources").and_then(|value| value.as_dict().ok());
        let xobjects = resources
            .and_then(|resources| scope.get_dict(resources, b"XObject"))
            .cloned()
            .unwrap_or_default();
        (resources.cloned().unwrap_or_default(), xobjects)
    }

    /// The name the `Do` at `range` of page stream `stream` draws, checked to be `form`.
    fn drawn_name(
        &self,
        doc: &Document,
        page: ObjectId,
        stream: ObjectId,
        range: &Range<usize>,
        form: ObjectId,
    ) -> Result<Vec<u8>, CoreError> {
        let wrong = || CoreError::Write(WriteError::Placement);
        let data = decoded(&self.stream(doc, stream)?, doc)?;
        let bytes = data.get(range.clone()).ok_or_else(wrong)?;
        let operators = content::operators(bytes, doc.limits())?;
        let [operator] = operators.as_slice() else {
            return Err(wrong());
        };
        let name = match (operator.name.as_slice(), operator.operands.as_slice()) {
            (b"Do", [Object::Name(name)]) => name.clone(),
            _ => return Err(wrong()),
        };
        let (_, xobjects) = self.page_xobjects(doc, page);
        match xobjects.get(&name) {
            Ok(Object::Reference(id)) if *id == form => Ok(name),
            _ => Err(wrong()),
        }
    }

    /// A name for a form copy that page `page`'s `/XObject` resources and `taken` do not use:
    /// `name` with a numbered suffix.
    fn fresh_name(
        &self,
        doc: &Document,
        page: ObjectId,
        name: &[u8],
        taken: &[(Vec<u8>, ObjectId)],
    ) -> Result<Vec<u8>, CoreError> {
        let (_, xobjects) = self.page_xobjects(doc, page);
        for suffix in 1..=10_000u32 {
            let mut candidate = name.to_vec();
            let _ = write!(candidate, "_{suffix}");
            if !xobjects.has(&candidate) && taken.iter().all(|(used, _)| *used != candidate) {
                return Ok(candidate);
            }
        }
        Err(CoreError::Internal {
            context: "a free resource name for a form copy",
        })
    }
}

/// `number` as a new object's number; the last two are kept for the writer's `/Size` and its
/// cross-reference stream.
fn free(number: u32) -> Result<u32, CoreError> {
    if number >= u32::MAX.saturating_sub(1) {
        return Err(CoreError::Write(WriteError::ObjectNumbers));
    }
    Ok(number)
}

/// Queues `object` as a new object numbered `next`, and moves `next` on.
fn queue_new(
    queued: &mut Vec<(ObjectId, Object)>,
    next: &mut u32,
    object: Object,
) -> Result<ObjectId, CoreError> {
    let id = (free(*next)?, 0);
    *next = next.saturating_add(1);
    queued.push((id, object));
    Ok(id)
}

/// A stream's replacements: ranges of its decoded data and their new bytes.
type Edits = Vec<(Range<usize>, Vec<u8>)>;

/// Adds an edit of `id` to `list`, keeping one entry per stream.
fn group(list: &mut Vec<(ObjectId, Edits)>, id: ObjectId, range: Range<usize>, bytes: Vec<u8>) {
    match list.iter_mut().find(|(other, _)| *other == id) {
        Some((_, edits)) => edits.push((range, bytes)),
        None => list.push((id, vec![(range, bytes)])),
    }
}

/// `stream`'s decoded data, within `doc`'s limits.
fn decoded(stream: &Stream, doc: &Document) -> Result<Vec<u8>, CoreError> {
    let steps = filters::chain_of(&stream.dict)?;
    filters::decode_chain(&steps, &stream.content, doc.limits())
}

/// `stream` with `edits` applied to its decoded data, compressed with Flate: `/Filter` becomes
/// `/FlateDecode`, `/DecodeParms` goes, `/DL` is updated, and every other key stays.
fn respliced(
    stream: &Stream,
    edits: &[(Range<usize>, Vec<u8>)],
    doc: &Document,
) -> Result<Stream, CoreError> {
    let data = splice_bytes(&decoded(stream, doc)?, edits)?;
    let mut encoder = flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::default());
    let compressed = encoder
        .write_all(&data)
        .and_then(|()| encoder.finish())
        .map_err(|_| CoreError::Internal {
            context: "compressing a content stream",
        })?;
    let mut dict = stream.dict.clone();
    dict.remove(b"DecodeParms");
    dict.set("Filter", Object::Name(b"FlateDecode".to_vec()));
    if dict.has(b"DL") {
        dict.set("DL", i64::try_from(data.len()).unwrap_or(i64::MAX));
    }
    Ok(Stream::new(dict, compressed))
}

/// `data` with each range of `edits` replaced by its bytes. Every other byte stays as it is.
fn splice_bytes(data: &[u8], edits: &[(Range<usize>, Vec<u8>)]) -> Result<Vec<u8>, CoreError> {
    let mut sorted: Vec<&(Range<usize>, Vec<u8>)> = edits.iter().collect();
    sorted.sort_by_key(|(range, _)| (range.start, range.end));
    let mut out = Vec::new();
    out.try_reserve(
        data.len()
            .saturating_add(edits.iter().map(|(_, bytes)| bytes.len()).sum::<usize>()),
    )
    .map_err(|_| CoreError::OutOfMemory {
        context: "a spliced content stream",
    })?;
    let mut at = 0;
    for (range, bytes) in sorted {
        if range.start > range.end || range.end > data.len() {
            return Err(CoreError::Write(WriteError::SpliceOutsideStream));
        }
        let kept = data
            .get(at..range.start)
            .ok_or(CoreError::Write(WriteError::OverlappingSplices))?;
        out.extend_from_slice(kept);
        out.extend_from_slice(bytes);
        at = range.end;
    }
    out.extend_from_slice(data.get(at..).unwrap_or_default());
    Ok(out)
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    #[test]
    fn splices_replace_their_ranges_only() {
        let data = b"BT /F1 12 Tf (Merhaba) Tj ET";
        let out = splice_bytes(
            data,
            &[(14..21, b"Selam".to_vec()), (0..2, b"BT\n".to_vec())],
        )
        .unwrap();
        assert_eq!(out, b"BT\n /F1 12 Tf (Selam) Tj ET");
        // An insertion at the end, and nothing at all.
        assert_eq!(
            splice_bytes(b"ab", &[(2..2, b"c".to_vec())]).unwrap(),
            b"abc"
        );
        assert_eq!(splice_bytes(b"ab", &[]).unwrap(), b"ab");
    }

    #[test]
    fn overlapping_or_outside_splices_are_errors() {
        assert!(matches!(
            splice_bytes(b"abcdef", &[(1..4, vec![]), (3..5, vec![])]),
            Err(CoreError::Write(WriteError::OverlappingSplices))
        ));
        assert!(matches!(
            splice_bytes(b"abc", &[(2..4, vec![])]),
            Err(CoreError::Write(WriteError::SpliceOutsideStream))
        ));
        #[allow(clippy::reversed_empty_ranges)]
        let backwards = 2..1;
        assert!(matches!(
            splice_bytes(b"abc", &[(backwards, vec![])]),
            Err(CoreError::Write(WriteError::SpliceOutsideStream))
        ));
    }

    #[test]
    fn new_objects_keep_two_numbers_for_the_writer() {
        assert_eq!(free(u32::MAX - 2).unwrap(), u32::MAX - 2);
        for number in [u32::MAX - 1, u32::MAX] {
            assert!(matches!(
                free(number),
                Err(CoreError::Write(WriteError::ObjectNumbers))
            ));
        }
    }

    use std::path::{Path, PathBuf};
    use std::sync::Arc;

    use crate::interpret::{OperatorEvent, TextShow};
    use crate::{OpenOptions, Password, Source, open};

    /// Every operator of a page in content order, by name, with its span.
    #[derive(Default)]
    struct Operators(Vec<(Vec<u8>, Span)>);

    impl TextSink for Operators {
        fn font(&mut self, _font: &crate::interpret::FontResource) {}

        fn show(&mut self, _show: &TextShow<'_>) -> (f32, f32) {
            (0.0, 0.0)
        }

        fn operator(&mut self, operator: &OperatorEvent<'_>) {
            self.0.push((operator.name.to_vec(), operator.span.clone()));
        }
    }

    fn operators(doc: &Document, store: Option<&RevisionStore>, page: usize) -> Operators {
        let mut sink = Operators::default();
        doc.page_text_through(store, page, &mut sink).unwrap();
        sink
    }

    fn corpus(name: &str) -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(name)
    }

    fn open_bytes(bytes: &[u8], password: Option<&str>) -> Result<Document, CoreError> {
        let options = OpenOptions {
            password: password.map(|password| Password::new(password.to_owned())),
            ..OpenOptions::default()
        };
        open(&Source::from_bytes(Arc::from(bytes)), &options)
    }

    fn password(name: &str) -> Option<&'static str> {
        match name {
            "payslip-aes256" => Some("Eylül2026maaşı"),
            _ if name.starts_with("payslip-") => Some("bordro2026"),
            _ => None,
        }
    }

    fn fixed(out: &mut [u8]) -> Result<(), CoreError> {
        out.fill(0xA5);
        Ok(())
    }

    /// Writes `bytes` as `name` into `FERMAN_SAVED_DIR` when it is set, so CI can run an
    /// independent structure checker (`qpdf --check`) over every file these tests save.
    fn keep(name: &str, bytes: &[u8]) {
        if let Some(dir) = std::env::var_os("FERMAN_SAVED_DIR").filter(|dir| !dir.is_empty()) {
            let dir = PathBuf::from(dir);
            std::fs::create_dir_all(&dir).unwrap();
            std::fs::write(dir.join(format!("{name}.pdf")), bytes).unwrap();
        }
    }

    /// The decoded data of stream `id` in `doc`'s model.
    fn data(doc: &Document, id: ObjectId) -> Vec<u8> {
        let Ok(Object::Stream(stream)) = doc.model().get_object(id) else {
            panic!("{id:?} is not a stream");
        };
        decoded(stream, doc).unwrap()
    }

    /// Saves `store`'s revisions of `doc`, checks that the original is a prefix and reopens it.
    fn saved(
        doc: &Document,
        store: &RevisionStore,
        name: &str,
        password: Option<&str>,
    ) -> Document {
        let bytes = store.write_update(doc, &mut fixed).unwrap();
        let original: &[u8] = doc.source().bytes();
        assert_eq!(&bytes[..original.len()], original, "{name}");
        keep(name, &bytes);
        let reopened = open_bytes(&bytes, password).unwrap();
        assert!(reopened.repair().is_none(), "{name}");
        assert_eq!(reopened.page_count(), doc.page_count(), "{name}");
        // Every object the revisions do not change reads back as it was.
        let changed = store.committed();
        for (id, object) in &doc.model().objects {
            if !changed.contains_key(id) {
                assert_eq!(
                    reopened.model().get_object(*id).ok(),
                    Some(object),
                    "{name} {id:?}"
                );
            }
        }
        reopened
    }

    /// The first show of a page stream in `doc`: its page and span.
    fn first_show(doc: &Document) -> Option<(usize, Span)> {
        (0..doc.page_count()).find_map(|page| {
            operators(doc, None, page)
                .0
                .into_iter()
                .find(|(name, span)| {
                    matches!(name.as_slice(), b"Tj" | b"TJ")
                        && !span.carried
                        && matches!(span.source, SpanSource::Page { .. })
                })
                .map(|(_, span)| (page, span))
        })
    }

    #[test]
    fn every_corpus_file_round_trips_a_splice() {
        let mut files: Vec<PathBuf> = std::fs::read_dir(corpus(""))
            .unwrap()
            .map(|entry| entry.unwrap().path())
            .filter(|path| path.extension().is_some_and(|ext| ext == "pdf"))
            .collect();
        files.sort();
        let mut edited = Vec::new();
        for path in files {
            let name = path.file_stem().unwrap().to_string_lossy().into_owned();
            let bytes = std::fs::read(&path).unwrap();
            let Ok(doc) = open_bytes(&bytes, password(&name)) else {
                assert_eq!(name, "truncated");
                continue;
            };
            let Some((page, span)) = first_show(&doc) else {
                continue;
            };
            let SpanSource::Page { stream } = span.source else {
                unreachable!()
            };
            let before = data(&doc, stream);
            let changed = b"(Ferman) Tj".to_vec();
            for (suffix, replacement) in [
                ("same", before[span.range.clone()].to_vec()),
                ("changed", changed.clone()),
            ] {
                let mut store = RevisionStore::new(&doc);
                store.begin().unwrap();
                let splice = Splice {
                    source: span.source,
                    range: span.range.clone(),
                    bytes: replacement.clone(),
                };
                store.splice(&doc, page, &[splice], &[]).unwrap();
                store.commit().unwrap();
                if doc.repair().is_some() {
                    assert!(matches!(
                        store.write_update(&doc, &mut fixed),
                        Err(CoreError::Write(WriteError::Repaired))
                    ));
                    continue;
                }
                let reopened = saved(&doc, &store, &format!("{name}-{suffix}"), password(&name));
                let mut expected = before[..span.range.start].to_vec();
                expected.extend(&replacement);
                expected.extend(&before[span.range.end..]);
                // The page reads its edited stream, which decrypts and decodes to the splice.
                let streams = store.contents(&reopened, reopened.structure().pages[page].id);
                let now: Vec<u8> = streams.iter().flat_map(|id| data(&reopened, *id)).collect();
                let was: Vec<u8> = store
                    .contents(&doc, doc.structure().pages[page].id)
                    .iter()
                    .flat_map(|id| {
                        if *id == stream || doc.model().get_object(*id).is_err() {
                            expected.clone()
                        } else {
                            data(&doc, *id)
                        }
                    })
                    .collect();
                assert_eq!(now, was, "{name}-{suffix}");
                // The text reads through the store as it reads from the saved file.
                assert_eq!(
                    operators(&doc, Some(&store), page).0,
                    operators(&reopened, None, page).0,
                    "{name}-{suffix}"
                );
            }
            edited.push(name);
        }
        // Every cipher, a cross-reference stream (tez-tr) and a repaired file are among them.
        for name in [
            "payslip-rc4-40",
            "payslip-rc4-128",
            "payslip-aes128",
            "payslip-aes256",
            "kira-tr-restricted",
            "tez-tr",
            "kira-tr-damaged",
            "edit-e23-shared-contents",
        ] {
            assert!(edited.iter().any(|edited| edited == name), "{name}");
        }
        assert!(edited.len() > 30, "{edited:?}");
    }

    /// The operators of page `page` with their source streams' decoded bytes.
    fn bytes_of(doc: &Document, span: &Span) -> Vec<u8> {
        let id = match span.source {
            SpanSource::Page { stream } => stream,
            SpanSource::Form { form } => form,
        };
        data(doc, id)[span.range.clone()].to_vec()
    }

    #[test]
    fn a_block_split_across_two_streams_changes_both_and_nothing_else() {
        let name = "edit-e22-split-contents";
        let doc = open_bytes(
            &std::fs::read(corpus(&format!("{name}.pdf"))).unwrap(),
            None,
        )
        .unwrap();
        let page = doc.structure().pages[0].id;
        let mut store = RevisionStore::new(&doc);
        let streams = store.contents(&doc, page);
        assert_eq!(streams.len(), 2);
        let ops = operators(&doc, None, 0).0;
        // The last `Tf` of the first stream and the first show of the second.
        let tf = ops
            .iter()
            .rfind(|(name, span)| {
                name == b"Tf" && span.source == SpanSource::Page { stream: streams[0] }
            })
            .unwrap()
            .1
            .clone();
        let show = ops
            .iter()
            .find(|(name, span)| {
                matches!(name.as_slice(), b"Tj" | b"TJ")
                    && span.source == SpanSource::Page { stream: streams[1] }
            })
            .unwrap()
            .1
            .clone();
        store.begin().unwrap();
        let mut tf_bytes = bytes_of(&doc, &tf);
        tf_bytes.extend(b" ");
        let splices = [
            Splice {
                source: tf.source,
                range: tf.range.clone(),
                bytes: tf_bytes.clone(),
            },
            Splice {
                source: show.source,
                range: show.range.clone(),
                bytes: b"(Ferman) Tj".to_vec(),
            },
        ];
        store.splice(&doc, 0, &splices, &[]).unwrap();
        store.commit().unwrap();
        // Both streams are new versions of the same objects; the page is unchanged.
        assert_eq!(
            store.committed().keys().copied().collect::<Vec<_>>(),
            streams
        );
        let reopened = saved(&doc, &store, name, None);
        for (stream, span, bytes) in [
            (streams[0], &tf, tf_bytes),
            (streams[1], &show, b"(Ferman) Tj".to_vec()),
        ] {
            let (old, new) = (data(&doc, stream), data(&reopened, stream));
            assert_eq!(new[..span.range.start], old[..span.range.start]);
            assert_eq!(
                new[span.range.start..span.range.start + bytes.len()],
                bytes[..]
            );
            assert_eq!(new[span.range.start + bytes.len()..], old[span.range.end..]);
        }
    }

    #[test]
    fn a_stream_shared_by_two_pages_is_copied_for_the_edited_one() {
        let name = "edit-e23-shared-contents";
        let doc = open_bytes(
            &std::fs::read(corpus(&format!("{name}.pdf"))).unwrap(),
            None,
        )
        .unwrap();
        let (first, second) = (doc.structure().pages[0].id, doc.structure().pages[1].id);
        let mut store = RevisionStore::new(&doc);
        let shared = store.contents(&doc, first);
        assert_eq!(shared, store.contents(&doc, second));
        let (page, span) = first_show(&doc).unwrap();
        assert_eq!(page, 0);
        store.begin().unwrap();
        let splice = Splice {
            source: span.source,
            range: span.range.clone(),
            bytes: b"(Ferman) Tj".to_vec(),
        };
        store.splice(&doc, 0, &[splice], &[]).unwrap();
        store.commit().unwrap();
        let changed: Vec<ObjectId> = store.committed().keys().copied().collect();
        // The first page and a new stream; not the shared stream, nor the second page.
        assert_eq!(changed.len(), 2);
        assert!(changed.contains(&first));
        assert!(!changed.contains(&shared[0]) && !changed.contains(&second));
        let copy = store.contents(&doc, first);
        assert_eq!(copy.len(), 1);
        assert!(copy[0].0 >= doc.xref().size);
        let reopened = saved(&doc, &store, name, None);
        assert_eq!(store.contents(&reopened, second), shared);
        assert_eq!(operators(&reopened, None, 1).0, operators(&doc, None, 1).0);
        let old = data(&doc, shared[0]);
        let new = data(&reopened, copy[0]);
        assert_eq!(new[..span.range.start], old[..span.range.start]);
        assert_eq!(new[span.range.start + 11..], old[span.range.end..]);
        // A second edit of the first page changes its own copy in place.
        store.begin().unwrap();
        let again = Splice {
            source: SpanSource::Page { stream: copy[0] },
            range: 0..0,
            bytes: b" ".to_vec(),
        };
        store.splice(&doc, 0, &[again], &[]).unwrap();
        store.commit().unwrap();
        assert_eq!(store.contents(&doc, first), copy);
    }

    #[test]
    fn a_form_placed_twice_is_copied_for_the_edited_placement() {
        let name = "edit-e20-form-twice";
        let doc = open_bytes(
            &std::fs::read(corpus(&format!("{name}.pdf"))).unwrap(),
            None,
        )
        .unwrap();
        let ops = operators(&doc, None, 0).0;
        let (at, show) = ops
            .iter()
            .enumerate()
            .find(|(_, (name, span))| {
                matches!(name.as_slice(), b"Tj" | b"TJ")
                    && matches!(span.source, SpanSource::Form { .. })
            })
            .map(|(at, (_, span))| (at, span.clone()))
            .unwrap();
        let SpanSource::Form { form } = show.source else {
            unreachable!()
        };
        // Its placement is the next `Do` of the page.
        let draw = ops[at..]
            .iter()
            .find(|(name, span)| name == b"Do" && matches!(span.source, SpanSource::Page { .. }))
            .unwrap()
            .1
            .clone();
        let SpanSource::Page { stream } = draw.source else {
            unreachable!()
        };
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let splice = Splice {
            source: show.source,
            range: show.range.clone(),
            bytes: b"(Ferman) Tj".to_vec(),
        };
        // Without its placement, or with a placement of another form, it is refused.
        for placements in [
            vec![],
            vec![Placement {
                form: (1, 0),
                draw: draw.clone(),
            }],
        ] {
            assert!(matches!(
                store.splice(&doc, 0, std::slice::from_ref(&splice), &placements),
                Err(CoreError::Write(WriteError::Placement))
            ));
        }
        let placement = Placement {
            form,
            draw: draw.clone(),
        };
        store.splice(&doc, 0, &[splice], &[placement]).unwrap();
        store.commit().unwrap();
        let page = doc.structure().pages[0].id;
        let changed: Vec<ObjectId> = store.committed().keys().copied().collect();
        assert_eq!(changed.len(), 3, "{changed:?}");
        assert!(changed.contains(&page) && changed.contains(&stream) && !changed.contains(&form));
        let reopened = saved(&doc, &store, name, None);
        // The page draws the copy at the edited placement and the form at the other.
        let old = data(&doc, stream);
        let new = data(&reopened, stream);
        assert_eq!(bytes_of(&doc, &draw), b"/Fm1 Do");
        assert_eq!(new[..draw.range.start], old[..draw.range.start]);
        assert_eq!(new[draw.range.start..draw.range.start + 9], *b"/Fm1_1 Do");
        assert_eq!(new[draw.range.start + 9..], old[draw.range.end..]);
        let forms: Vec<ObjectId> = operators(&reopened, None, 0)
            .0
            .iter()
            .filter_map(|(name, span)| match span.source {
                SpanSource::Form { form } if matches!(name.as_slice(), b"Tj" | b"TJ") => Some(form),
                _ => None,
            })
            .collect();
        assert!(forms.contains(&form));
        let copy = *forms.iter().find(|id| **id != form).unwrap();
        let (old, new) = (data(&doc, form), data(&reopened, copy));
        assert_eq!(new[..show.range.start], old[..show.range.start]);
        assert_eq!(new[show.range.start + 11..], old[show.range.end..]);

        // A second edit changes the copy in place; the page and its stream stay.
        let redraw = Span {
            range: draw.range.start..draw.range.start + 9,
            ..draw.clone()
        };
        store.begin().unwrap();
        let again = Splice {
            source: SpanSource::Form { form: copy },
            range: 0..0,
            bytes: b" ".to_vec(),
        };
        let placement = Placement {
            form: copy,
            draw: redraw,
        };
        store.splice(&doc, 0, &[again], &[placement]).unwrap();
        store.commit().unwrap();
        assert_eq!(
            store.revisions()[1].ids().collect::<Vec<_>>(),
            vec![copy],
            "{changed:?}"
        );
        assert_eq!(
            data(&saved(&doc, &store, &format!("{name}-again"), None), copy)[0],
            b' '
        );
    }

    #[test]
    fn a_failed_splice_leaves_the_transaction_as_it_was() {
        let doc = open_bytes(
            &std::fs::read(corpus("edit-e20-form-twice.pdf")).unwrap(),
            None,
        )
        .unwrap();
        let (page, span) = first_show(&doc).unwrap();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let good = Splice {
            source: span.source,
            range: span.range.clone(),
            bytes: b"(Ferman) Tj".to_vec(),
        };
        // A form's stream named as a page stream is not on the page.
        let form = operators(&doc, None, page)
            .0
            .into_iter()
            .find_map(|(_, span)| match span.source {
                SpanSource::Form { form } => Some(form),
                SpanSource::Page { .. } => None,
            })
            .unwrap();
        let stray = Splice {
            source: SpanSource::Page { stream: form },
            range: 0..0,
            bytes: b" ".to_vec(),
        };
        let outside = Splice {
            range: 0..usize::MAX,
            ..good.clone()
        };
        for (bad, error) in [
            (stray, WriteError::NotOnPage),
            (outside, WriteError::SpliceOutsideStream),
        ] {
            let result = store.splice(&doc, page, &[good.clone(), bad], &[]);
            assert!(matches!(result, Err(CoreError::Write(found)) if found == error));
        }
        assert_eq!(
            store.commit().unwrap(),
            0,
            "nothing entered the transaction"
        );
    }
}
