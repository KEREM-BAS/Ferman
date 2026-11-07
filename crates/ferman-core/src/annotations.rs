//! Annotations in the revisions of a document (M4 plan, W2, decisions 6 and 9): the reader and the
//! primitives ferman-ops writes through.
//!
//! The reader takes `/Annots` page by page, through the open revisions, and stops at the limits
//! below however large or cyclic the file's arrays and `/IRT` chains are; a list cut short says so.
//! It keeps what the file says: nothing it reads is written back. An edit sets only the keys it
//! names in the annotation's own dictionary, so `/RC`, `/DS`, private keys and unknown types stay
//! as they came, and another annotation is never in the update.
//!
//! An annotation's identity is its object's handle. One written directly in `/Annots` has none, so
//! it is named by its place among the page's direct ones, and the first change makes it an object
//! of its own (the change returns the new identity).
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeSet, HashMap};

use lopdf::{Dictionary, Object, ObjectId};

use crate::revision::{EmbeddedFont, RevisionStore, embedded_font, free};
use crate::structure::{Page, PdfDate, Scope, number};
use crate::write::{ObjectRef, Value};
use crate::{CoreError, Document, WriteError, text_string};

/// The most annotations read from one page's `/Annots`.
pub const MAX_PER_PAGE: usize = 50_000;
/// The most annotations read from a document.
pub const MAX_PER_DOCUMENT: usize = 200_000;
/// The most numbers read from all the annotations' geometry of a document.
pub const MAX_NUMBERS: usize = 8_000_000;
/// The longest string kept of one entry, in bytes as the file has them. A longer one is cut in the
/// list only; the file keeps it unless the user replaces that text.
pub const MAX_TEXT: usize = 1024 * 1024;
/// The most bytes of text kept of a document's annotations: one huge string can be named by many.
pub const MAX_TEXTS: usize = 64 * 1024 * 1024;
/// How far a reply is followed up its `/IRT` chain to its thread.
pub const MAX_THREAD_DEPTH: usize = 64;
/// The most names offered for mentions.
pub const MAX_PEOPLE: usize = 1_000;
/// The most comparisons of an `@` with a name, for a document.
const MAX_MENTION_CHECKS: usize = 4_000_000;
/// The bit that marks the handle of an annotation written directly in `/Annots`; it stays inside
/// the 53 bits a web build can carry, past any object's handle.
const DIRECT: u64 = 1 << 52;

/// What an annotation is. Links, widgets and popups are no comments and are not listed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum AnnotationKind {
    /// `/Highlight`.
    Highlight,
    /// `/Underline`.
    Underline,
    /// `/StrikeOut`.
    StrikeOut,
    /// `/Squiggly`: read and rendered, never created (decision 6).
    Squiggly,
    /// `/Text`: a note on the page, or a reply.
    Note,
    /// `/FreeText`: a text box.
    FreeText,
    /// `/FreeText` with `/IT /FreeTextCallout`.
    Callout,
    /// `/Ink`.
    Ink,
    /// `/Square`.
    Square,
    /// `/Circle`.
    Circle,
    /// `/Line`, with or without an arrow.
    Line,
    /// `/Polygon`.
    Polygon,
    /// `/Stamp`.
    Stamp,
    /// Any other subtype: listed, its text editable, its drawing left alone.
    Other,
}

impl AnnotationKind {
    /// The `/Subtype` this kind writes.
    #[must_use]
    pub fn subtype(self) -> &'static [u8] {
        match self {
            Self::Highlight => b"Highlight",
            Self::Underline => b"Underline",
            Self::StrikeOut => b"StrikeOut",
            Self::Squiggly => b"Squiggly",
            Self::Note => b"Text",
            Self::FreeText | Self::Callout => b"FreeText",
            Self::Ink => b"Ink",
            Self::Square => b"Square",
            Self::Circle => b"Circle",
            Self::Line => b"Line",
            Self::Polygon => b"Polygon",
            Self::Stamp => b"Stamp",
            Self::Other => b"",
        }
    }
}

/// How a line or a callout ends.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum LineEnd {
    /// Plain, or a style Ferman does not draw.
    #[default]
    None,
    /// `/OpenArrow`.
    OpenArrow,
    /// `/ClosedArrow`.
    ClosedArrow,
}

/// A review state a reply sets (`/State` with `/StateModel /Review`, decision 9).
#[derive(Debug, Clone, PartialEq)]
pub struct Resolution {
    /// Who resolved it: the reply's `/T`.
    pub by: Option<String>,
    /// When: the reply's `/M`.
    pub at: Option<PdfDate>,
}

/// One annotation, in the page's user space. Geometry the file does not give is empty.
#[derive(Debug, Clone, PartialEq)]
pub struct Annotation {
    /// Its identity, opaque above ferman-core.
    pub handle: u64,
    /// Its page's index.
    pub page: usize,
    /// What it is.
    pub kind: AnnotationKind,
    /// Its `/Subtype`, as the file has it.
    pub subtype: String,
    /// `/Rect`, as left, bottom, right and top.
    pub rect: [f32; 4],
    /// `/QuadPoints`, eight numbers each, in the file's corner order.
    pub quads: Vec<[f32; 8]>,
    /// `/InkList`'s strokes.
    pub ink: Vec<Vec<[f32; 2]>>,
    /// `/L`: the line's two ends.
    pub line: Option<[f32; 4]>,
    /// `/Vertices`.
    pub vertices: Vec<[f32; 2]>,
    /// `/CL`: the callout's leader, from its far end.
    pub callout: Vec<[f32; 2]>,
    /// `/LE`, at the line's start and end; a callout has only the first.
    pub line_ends: [LineEnd; 2],
    /// `/RD`: how far the drawing sits inside `/Rect`, as left, bottom, right and top.
    pub inset: [f32; 4],
    /// `/C` as red, green and blue; `None` for none or an empty array.
    pub color: Option<[f32; 3]>,
    /// `/IC` as red, green and blue.
    pub interior: Option<[f32; 3]>,
    /// `/CA`, 1 by default.
    pub opacity: f32,
    /// `/BS /W`, else the third of `/Border`, else 1.
    pub stroke: f32,
    /// `/BS /D` when `/BS /S` is `/D`.
    pub dash: Vec<f32>,
    /// The font size `/DA` sets.
    pub font_size: Option<f32>,
    /// The colour `/DA` sets, as red, green and blue.
    pub text_color: Option<[f32; 3]>,
    /// `/Rotate`.
    pub rotation: i64,
    /// `/F`.
    pub flags: u32,
    /// `/T`.
    pub author: Option<String>,
    /// `/Subj`.
    pub subject: Option<String>,
    /// `/Contents`.
    pub contents: Option<String>,
    /// Whether it has `/RC`, kept as it came until its text is replaced.
    pub rich: bool,
    /// `/RT /Group`: its `/IRT` groups it with a mark as one, and it draws like any other.
    pub grouped: bool,
    /// `/CreationDate`.
    pub created: Option<PdfDate>,
    /// `/M`.
    pub modified: Option<PdfDate>,
    /// `/NM`.
    pub unique_name: Option<String>,
    /// `/Name`: a note's icon or a stamp's name.
    pub icon: Option<String>,
    /// The annotation `/IRT` names, when it is listed and its chain ends within
    /// [`MAX_THREAD_DEPTH`] without a cycle.
    pub replies_to: Option<u64>,
    /// The annotation at the top of its chain, its own handle when it is no reply.
    pub thread: u64,
    /// `/State`, for a state reply.
    pub state: Option<String>,
    /// `/StateModel`, for a state reply.
    pub state_model: Option<String>,
    /// At the top of a thread whose newest review state is `Completed`: that reply's facts.
    pub resolved: Option<Resolution>,
    /// Whether `/AP` has `/N`.
    pub has_appearance: bool,
    /// The people of the file its text names with `@`, travelling with the text.
    pub mentions: Vec<String>,
}

/// The annotations of a document as the revisions leave them.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct AnnotationList {
    /// In page order, each page in `/Annots` order.
    pub annotations: Vec<Annotation>,
    /// The authors in the file, for mentions, in the order they first appear.
    pub people: Vec<String>,
    /// Whether a limit cut the list or a text short.
    pub truncated: bool,
}

/// What the reader may still take.
pub(crate) struct Budget {
    pub(crate) numbers: usize,
    pub(crate) text: usize,
    pub(crate) truncated: bool,
}

impl Budget {
    fn numbers(&mut self, count: usize) -> bool {
        if let Some(left) = self.numbers.checked_sub(count) {
            self.numbers = left;
            true
        } else {
            self.truncated = true;
            false
        }
    }
}

/// The handle of the annotation object `id`, as [`Page::handle`] makes a page's.
pub(crate) fn handle_of(id: ObjectId) -> u64 {
    (u64::from(id.0) << 16) | u64::from(id.1)
}

/// The handle of the `ordinal`th direct annotation of page object `page`.
pub(crate) fn direct_handle(page: ObjectId, ordinal: usize) -> u64 {
    let ordinal = u64::try_from(ordinal).unwrap_or(u64::MAX) & 0xFF_FFFF;
    DIRECT | ((u64::from(page.0) & 0x0FFF_FFFF) << 24) | ordinal
}

/// The popup of `annotation`, whose object is `owner` when it has one: what `/Popup` names, if that
/// is a popup and does not say it belongs to another annotation.
pub(crate) fn popup_of(
    scope: &Scope<'_>,
    annotation: &Dictionary,
    owner: Option<ObjectId>,
) -> Option<ObjectId> {
    let id = annotation.get(b"Popup").ok()?.as_reference().ok()?;
    let popup = scope.dictionary(id)?;
    if scope.get_name(popup, b"Subtype") != Some(b"Popup") {
        return None;
    }
    match popup.get(b"Parent") {
        Ok(parent) if parent.as_reference().ok() != owner => None,
        _ => Some(id),
    }
}

impl ObjectRef {
    /// A number that names the object among all others, as an annotation's handle does.
    #[must_use]
    pub fn handle(self) -> u64 {
        handle_of(self.0)
    }
}

/// The numbers of `object`, an array, within the budget; those that are not numbers are dropped.
fn numbers(scope: &Scope<'_>, object: &Object, budget: &mut Budget) -> Vec<f32> {
    let Some(items) = scope.resolve(object).and_then(|o| o.as_array().ok()) else {
        return Vec::new();
    };
    if !budget.numbers(items.len()) {
        return Vec::new();
    }
    items
        .iter()
        .filter_map(|item| scope.resolve(item).and_then(number))
        .collect()
}

pub(crate) fn entry_numbers(
    scope: &Scope<'_>,
    dict: &Dictionary,
    key: &[u8],
    budget: &mut Budget,
) -> Vec<f32> {
    dict.get(key)
        .map(|object| numbers(scope, object, budget))
        .unwrap_or_default()
}

fn pairs(values: &[f32]) -> Vec<[f32; 2]> {
    values.as_chunks::<2>().0.to_vec()
}

/// `/C` or `/IC`: no numbers for none, else gray, RGB or CMYK as red, green and blue.
pub(crate) fn colour(values: &[f32]) -> Option<[f32; 3]> {
    match *values {
        [gray] => Some([gray, gray, gray]),
        [red, green, blue] => Some([red, green, blue]),
        [cyan, magenta, yellow, black] => Some([
            (1.0 - cyan) * (1.0 - black),
            (1.0 - magenta) * (1.0 - black),
            (1.0 - yellow) * (1.0 - black),
        ]),
        _ => None,
    }
    .map(|rgb| rgb.map(|value| value.clamp(0.0, 1.0)))
}

/// A string entry as text, at most [`MAX_TEXT`] of it, within the budget.
// shortcut: a text past the limit is listed cut, so replacing it replaces the whole with what was
// shown (the list says `truncated`). Upgrade if a real comment ever comes near a megabyte.
fn text(scope: &Scope<'_>, dict: &Dictionary, key: &[u8], budget: &mut Budget) -> Option<String> {
    let raw = scope.get(dict, key)?.as_str().ok()?;
    let keep = raw.len().min(MAX_TEXT);
    if keep < raw.len() {
        budget.truncated = true;
    }
    let Some(left) = budget.text.checked_sub(keep) else {
        budget.truncated = true;
        return None;
    };
    budget.text = left;
    Some(text_string::decode(raw.get(..keep)?))
}

/// A short string or name as text, however a producer wrote it: `/State` is a string in the
/// standard and a name in some files. Long ones are no state.
fn short_text(scope: &Scope<'_>, dict: &Dictionary, key: &[u8]) -> Option<String> {
    const LONGEST: usize = 64;
    match scope.get(dict, key)? {
        Object::Name(name) if name.len() <= LONGEST => {
            Some(String::from_utf8_lossy(name).into_owned())
        }
        Object::String(raw, _) if raw.len() <= LONGEST => Some(text_string::decode(raw)),
        _ => None,
    }
}

/// The font size and colour a `/DA` string sets.
fn default_appearance(da: &[u8]) -> (Option<f32>, Option<[f32; 3]>) {
    const LONGEST: usize = 4096;
    let (mut size, mut color) = (None, None);
    let mut operands: Vec<f32> = Vec::new();
    let tokens = da
        .get(..da.len().min(LONGEST))
        .unwrap_or_default()
        .split(u8::is_ascii_whitespace);
    for token in tokens.filter(|token| !token.is_empty()) {
        match token {
            b"Tf" => size = operands.last().copied().filter(|size| *size > 0.0),
            b"g" | b"rg" | b"k" => color = colour(&operands),
            _ => {
                if let Some(value) = std::str::from_utf8(token)
                    .ok()
                    .and_then(|token| token.parse::<f32>().ok())
                    .filter(|value| value.is_finite())
                {
                    operands.push(value);
                    continue;
                }
                if token.first() == Some(&b'/') {
                    continue;
                }
            }
        }
        operands.clear();
    }
    (size, color)
}

fn kind_of(subtype: &[u8], dict: &Dictionary, scope: &Scope<'_>) -> AnnotationKind {
    match subtype {
        b"Highlight" => AnnotationKind::Highlight,
        b"Underline" => AnnotationKind::Underline,
        b"StrikeOut" => AnnotationKind::StrikeOut,
        b"Squiggly" => AnnotationKind::Squiggly,
        b"Text" => AnnotationKind::Note,
        b"FreeText" if scope.get_name(dict, b"IT") == Some(b"FreeTextCallout") => {
            AnnotationKind::Callout
        }
        b"FreeText" => AnnotationKind::FreeText,
        b"Ink" => AnnotationKind::Ink,
        b"Square" => AnnotationKind::Square,
        b"Circle" => AnnotationKind::Circle,
        b"Line" => AnnotationKind::Line,
        b"Polygon" => AnnotationKind::Polygon,
        b"Stamp" => AnnotationKind::Stamp,
        _ => AnnotationKind::Other,
    }
}

// shortcut: only the two arrow styles are told apart; Butt, Circle, Diamond and the others read as
// plain, so a redraw of a foreign line drops them. Upgrade when a board offers them.
fn line_end(name: &[u8]) -> LineEnd {
    match name {
        b"OpenArrow" => LineEnd::OpenArrow,
        b"ClosedArrow" => LineEnd::ClosedArrow,
        _ => LineEnd::None,
    }
}

fn line_ends(scope: &Scope<'_>, dict: &Dictionary) -> [LineEnd; 2] {
    match scope.get(dict, b"LE") {
        Some(Object::Name(name)) => [line_end(name), LineEnd::None],
        Some(Object::Array(names)) => {
            let end = |index: usize| {
                names
                    .get(index)
                    .and_then(|name| scope.resolve(name))
                    .and_then(|name| name.as_name().ok())
                    .map_or(LineEnd::None, line_end)
            };
            [end(0), end(1)]
        }
        _ => [LineEnd::None; 2],
    }
}

/// `/BS /W`, else the third of `/Border`, else 1; and the dash of a dashed `/BS`.
fn border(scope: &Scope<'_>, dict: &Dictionary, budget: &mut Budget) -> (f32, Vec<f32>) {
    let style = scope.get_dict(dict, b"BS");
    let width = style
        .and_then(|style| scope.get(style, b"W"))
        .and_then(number)
        .or_else(|| {
            scope
                .get_array(dict, b"Border")?
                .get(2)
                .and_then(|width| scope.resolve(width))
                .and_then(number)
        })
        .filter(|width| *width >= 0.0)
        .unwrap_or(1.0);
    let dash = style
        .filter(|style| scope.get_name(style, b"S") == Some(b"D"))
        .map(|style| entry_numbers(scope, style, b"D", budget))
        .unwrap_or_default();
    (width, dash)
}

/// One annotation, its thread and resolution not known yet.
fn read_one(
    scope: &Scope<'_>,
    dict: &Dictionary,
    subtype: &[u8],
    (handle, page): (u64, usize),
    budget: &mut Budget,
) -> Annotation {
    let rect = entry_numbers(scope, dict, b"Rect", budget);
    let rect = match *rect {
        [x0, y0, x1, y1] => [x0.min(x1), y0.min(y1), x0.max(x1), y0.max(y1)],
        _ => [0.0; 4],
    };
    let quads = entry_numbers(scope, dict, b"QuadPoints", budget)
        .as_chunks::<8>()
        .0
        .to_vec();
    let mut ink = Vec::new();
    if let Some(strokes) = scope.get_array(dict, b"InkList")
        && budget.numbers(strokes.len())
    {
        for stroke in strokes {
            let values = numbers(scope, stroke, budget);
            if !values.is_empty() {
                ink.push(pairs(&values));
            }
        }
    }
    let line = <[f32; 4]>::try_from(entry_numbers(scope, dict, b"L", budget)).ok();
    let inset = <[f32; 4]>::try_from(entry_numbers(scope, dict, b"RD", budget))
        .unwrap_or_default()
        .map(|side| side.max(0.0));
    let (stroke, dash) = border(scope, dict, budget);
    let appearance = scope
        .get(dict, b"DA")
        .and_then(|da| da.as_str().ok())
        .map(default_appearance)
        .unwrap_or_default();
    Annotation {
        handle,
        page,
        kind: kind_of(subtype, dict, scope),
        subtype: String::from_utf8_lossy(subtype).into_owned(),
        rect,
        quads,
        ink,
        line,
        vertices: pairs(&entry_numbers(scope, dict, b"Vertices", budget)),
        callout: pairs(&entry_numbers(scope, dict, b"CL", budget)),
        line_ends: line_ends(scope, dict),
        inset,
        color: colour(&entry_numbers(scope, dict, b"C", budget)),
        interior: colour(&entry_numbers(scope, dict, b"IC", budget)),
        opacity: scope
            .get(dict, b"CA")
            .and_then(number)
            .map_or(1.0, |opacity| opacity.clamp(0.0, 1.0)),
        stroke,
        dash,
        font_size: appearance.0,
        text_color: appearance.1,
        rotation: scope.get_int(dict, b"Rotate").unwrap_or(0),
        flags: scope
            .get_int(dict, b"F")
            .and_then(|flags| u32::try_from(flags).ok())
            .unwrap_or(0),
        author: text(scope, dict, b"T", budget),
        subject: text(scope, dict, b"Subj", budget),
        contents: text(scope, dict, b"Contents", budget),
        rich: dict.has(b"RC"),
        grouped: scope.get_name(dict, b"RT") == Some(b"Group"),
        created: short_date(scope, dict, b"CreationDate"),
        modified: short_date(scope, dict, b"M"),
        unique_name: text(scope, dict, b"NM", budget),
        icon: scope
            .get_name(dict, b"Name")
            .filter(|name| name.len() <= 64)
            .map(|name| String::from_utf8_lossy(name).into_owned()),
        replies_to: None,
        thread: handle,
        state: short_text(scope, dict, b"State"),
        state_model: short_text(scope, dict, b"StateModel"),
        resolved: None,
        has_appearance: scope
            .get_dict(dict, b"AP")
            .is_some_and(|appearance| appearance.has(b"N")),
        mentions: Vec::new(),
    }
}

/// A date entry, if it is short enough to be one.
fn short_date(scope: &Scope<'_>, dict: &Dictionary, key: &[u8]) -> Option<PdfDate> {
    const LONGEST: usize = 64;
    let raw = scope.get(dict, key)?.as_str().ok()?;
    if raw.len() > LONGEST {
        return None;
    }
    PdfDate::parse(&text_string::decode(raw))
}

/// A number that grows with the moment `date` names, for comparing two dates.
pub fn instant(date: &PdfDate) -> i64 {
    // A year is at most 65,535 and an offset an i16: this cannot overflow.
    #[allow(clippy::arithmetic_side_effects)]
    {
        let days = i64::from(date.year) * 372 + i64::from(date.month) * 31 + i64::from(date.day);
        let minutes = days * 1440 + i64::from(date.hour) * 60 + i64::from(date.minute);
        (minutes - i64::from(date.offset_minutes.unwrap_or(0))) * 60 + i64::from(date.second)
    }
}

/// The `/IRT` target of each annotation that has one, by handle, as the file names it.
fn link_threads(annotations: &mut [Annotation], targets: &HashMap<u64, u64>) {
    let known: HashMap<u64, usize> = annotations
        .iter()
        .enumerate()
        .map(|(index, annotation)| (annotation.handle, index))
        .collect();
    for annotation in annotations.iter_mut() {
        let Some(&parent) = targets.get(&annotation.handle) else {
            continue;
        };
        if !known.contains_key(&parent) {
            continue;
        }
        let mut top = parent;
        let mut steps = 1usize;
        let mut sound = top != annotation.handle;
        while sound && let Some(&next) = targets.get(&top).filter(|next| known.contains_key(next)) {
            steps = steps.saturating_add(1);
            // A cycle comes back within the limit, however long.
            if steps > MAX_THREAD_DEPTH || next == annotation.handle {
                sound = false;
            }
            top = next;
        }
        if sound {
            annotation.replies_to = Some(parent);
            annotation.thread = top;
        }
    }
    // The newest review state of a thread counts; a later entry wins a tie.
    let mut newest: HashMap<u64, (i64, usize)> = HashMap::new();
    for (index, annotation) in annotations.iter().enumerate() {
        let review = annotation.replies_to.is_some()
            && annotation.state.is_some()
            && annotation.state_model.as_deref().unwrap_or("Review") == "Review";
        if !review {
            continue;
        }
        let time = annotation.modified.as_ref().map_or(i64::MIN, instant);
        let slot = newest.entry(annotation.thread).or_insert((time, index));
        if time >= slot.0 {
            *slot = (time, index);
        }
    }
    for (thread, (_, index)) in newest {
        let Some(reply) = annotations.get(index) else {
            continue;
        };
        if reply.state.as_deref() != Some("Completed") {
            continue;
        }
        let resolution = Resolution {
            by: reply.author.clone(),
            at: reply.modified,
        };
        if let Some(top) = known
            .get(&thread)
            .and_then(|index| annotations.get_mut(*index))
        {
            top.resolved = Some(resolution);
        }
    }
}

/// The authors in the list, in first-seen order, and each text's mentions of them.
fn link_people(list: &mut AnnotationList) {
    for annotation in &list.annotations {
        if list.people.len() >= MAX_PEOPLE {
            list.truncated = true;
            break;
        }
        if let Some(author) = annotation.author.as_deref().map(str::trim)
            && !author.is_empty()
            && !list.people.iter().any(|person| person == author)
        {
            list.people.push(author.to_owned());
        }
    }
    let mut longest_first: Vec<&String> = list.people.iter().collect();
    longest_first.sort_by_key(|person| std::cmp::Reverse(person.len()));
    let mut checks = MAX_MENTION_CHECKS;
    for annotation in &mut list.annotations {
        let Some(contents) = &annotation.contents else {
            continue;
        };
        for (at, _) in contents.match_indices('@') {
            let after = contents.get(at.saturating_add(1)..).unwrap_or_default();
            for person in &longest_first {
                if checks == 0 {
                    list.truncated = true;
                    return;
                }
                checks = checks.saturating_sub(1);
                if after.starts_with(person.as_str()) {
                    if !annotation.mentions.iter().any(|name| name == *person) {
                        annotation.mentions.push((*person).clone());
                    }
                    break;
                }
            }
        }
    }
}

/// The list of `pages`, through `scope`.
fn read(scope: &Scope<'_>, pages: &[Page]) -> AnnotationList {
    let mut budget = Budget {
        numbers: MAX_NUMBERS,
        text: MAX_TEXTS,
        truncated: false,
    };
    let mut list = AnnotationList::default();
    let mut seen = BTreeSet::new();
    let mut targets = HashMap::new();
    'pages: for (index, page) in pages.iter().enumerate() {
        let Some(items) = scope
            .dictionary(page.id)
            .and_then(|dict| scope.get_array(dict, b"Annots"))
        else {
            continue;
        };
        if items.len() > MAX_PER_PAGE {
            budget.truncated = true;
        }
        let mut direct = 0usize;
        for item in items.iter().take(MAX_PER_PAGE) {
            if list.annotations.len() >= MAX_PER_DOCUMENT {
                budget.truncated = true;
                break 'pages;
            }
            let handle = if let Ok(id) = item.as_reference() {
                if !seen.insert(id) {
                    continue;
                }
                handle_of(id)
            } else {
                direct = direct.saturating_add(1);
                direct_handle(page.id, direct.saturating_sub(1))
            };
            let Some(dict) = scope.dict(item) else {
                continue;
            };
            let subtype = scope.get_name(dict, b"Subtype").unwrap_or_default();
            if matches!(subtype, b"Link" | b"Widget" | b"Popup") {
                continue;
            }
            if let Some(target) = dict.get(b"IRT").ok().and_then(|o| o.as_reference().ok()) {
                targets.insert(handle, handle_of(target));
            }
            let annotation = read_one(scope, dict, subtype, (handle, index), &mut budget);
            list.annotations.push(annotation);
        }
    }
    link_threads(&mut list.annotations, &targets);
    list.truncated = budget.truncated;
    link_people(&mut list);
    list
}

impl RevisionStore {
    /// The annotations as these revisions and the open transaction leave them.
    #[must_use]
    pub fn annotations(&self, doc: &Document) -> AnnotationList {
        read(&self.scope(doc), self.pages(doc))
    }

    /// Where annotation `handle` sits on page `index`: its object, or its place among the page's
    /// direct ones as a copy of its dictionary.
    fn located(&self, doc: &Document, index: usize, handle: u64) -> Result<Located, CoreError> {
        let missing = || CoreError::Write(WriteError::NoSuchAnnotation);
        let page = self.page_id(doc, index)?;
        let scope = self.scope(doc);
        let items = scope
            .dictionary(page)
            .and_then(|dict| scope.get_array(dict, b"Annots"))
            .ok_or_else(missing)?;
        let mut direct = 0usize;
        for item in items.iter().take(MAX_PER_PAGE) {
            if let Ok(id) = item.as_reference() {
                if handle_of(id) == handle {
                    return Ok(Located::Object(id));
                }
            } else {
                if direct_handle(page, direct) == handle {
                    let dict = scope.dict(item).ok_or_else(missing)?;
                    return Ok(Located::Direct(direct, dict.clone()));
                }
                direct = direct.saturating_add(1);
            }
        }
        Err(missing())
    }

    /// Changes annotation `handle` of page `index` in the open transaction: each entry is set, or
    /// removed when `None`; every other key stays as it came. A direct annotation becomes an object
    /// of its own. Returns the annotation's object.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::NoSuchPage`], [`WriteError::NoSuchAnnotation`]
    /// and [`WriteError::ObjectNumbers`].
    pub fn change_annotation(
        &mut self,
        doc: &Document,
        index: usize,
        handle: u64,
        entries: Vec<(Vec<u8>, Option<Value>)>,
    ) -> Result<ObjectRef, CoreError> {
        self.transaction_open()?;
        let missing = || CoreError::Write(WriteError::NoSuchAnnotation);
        let located = self.located(doc, index, handle)?;
        let mut dict = match &located {
            Located::Object(id) => self
                .scope(doc)
                .dict(&Object::Reference(*id))
                .cloned()
                .ok_or_else(missing)?,
            Located::Direct(_, dict) => dict.clone(),
        };
        for (key, value) in entries {
            match value {
                Some(value) => dict.set(key, value.into_object()?),
                None => {
                    dict.remove(&key);
                }
            }
        }
        match located {
            Located::Object(id) => {
                self.put(id, Object::Dictionary(dict))?;
                Ok(ObjectRef(id))
            }
            Located::Direct(place, _) => {
                let id = (free(self.next_number())?, 0);
                self.put(id, Object::Dictionary(dict))?;
                self.change_annots(doc, index, |items| {
                    replace_direct(items, place, Some(Object::Reference(id)))
                })?;
                Ok(ObjectRef(id))
            }
        }
    }

    /// Annotation `handle`'s object, for something to refer to it: one direct in `/Annots` gets an
    /// object now; one that has an object is not written.
    ///
    /// # Errors
    ///
    /// As [`change_annotation`](Self::change_annotation).
    pub fn annotation_object(
        &mut self,
        doc: &Document,
        index: usize,
        handle: u64,
    ) -> Result<ObjectRef, CoreError> {
        match self.located(doc, index, handle)? {
            Located::Object(id) => Ok(ObjectRef(id)),
            Located::Direct(..) => self.change_annotation(doc, index, handle, Vec::new()),
        }
    }

    /// Takes annotation `handle` out of page `index`'s `/Annots` in the open transaction, with
    /// its `/Popup`. Its object stays in the file until a full rewrite, as a deleted page's does.
    /// Returns whether the page named it.
    ///
    /// # Errors
    ///
    /// As [`change_annotation`](Self::change_annotation).
    pub fn drop_annotation(
        &mut self,
        doc: &Document,
        index: usize,
        handle: u64,
    ) -> Result<bool, CoreError> {
        self.transaction_open()?;
        let located = match self.located(doc, index, handle) {
            Ok(located) => located,
            Err(CoreError::Write(WriteError::NoSuchAnnotation)) => return Ok(false),
            Err(err) => return Err(err),
        };
        match located {
            Located::Object(id) => {
                let scope = self.scope(doc);
                let popup = scope
                    .dictionary(id)
                    .and_then(|dict| popup_of(&scope, dict, Some(id)));
                self.change_annots(doc, index, |items| {
                    items.retain(|item| {
                        let target = item.as_reference().ok();
                        target != Some(id) && (target.is_none() || target != popup)
                    });
                    true
                })
            }
            Located::Direct(place, dict) => {
                let popup = popup_of(&self.scope(doc), &dict, None);
                self.change_annots(doc, index, |items| {
                    replace_direct(items, place, None);
                    items.retain(|item| popup.is_none() || item.as_reference().ok() != popup);
                    true
                })
            }
        }
    }

    /// Adds `font` as new objects in the open transaction, for an appearance's `/Resources`.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::ObjectNumbers`], and those of decoding within
    /// the document's limits.
    pub fn add_embedded_font(
        &mut self,
        doc: &Document,
        font: &EmbeddedFont,
    ) -> Result<ObjectRef, CoreError> {
        self.transaction_open()?;
        let mut queued = Vec::new();
        let mut next = self.next_number();
        let id = embedded_font(font, &mut queued, &mut next)?;
        self.put_counted(doc, queued)?;
        Ok(ObjectRef(id))
    }
}

/// Where an annotation sits in its page's `/Annots`.
enum Located {
    Object(ObjectId),
    Direct(usize, Dictionary),
}

/// Puts `with` in the place of the `place`th direct item of `items`, or takes it out.
fn replace_direct(items: &mut Vec<Object>, place: usize, with: Option<Object>) -> bool {
    let Some(at) = items
        .iter()
        .enumerate()
        .filter(|(_, item)| item.as_reference().is_err())
        .nth(place)
        .map(|(at, _)| at)
    else {
        return false;
    };
    match with {
        Some(object) => {
            if let Some(item) = items.get_mut(at) {
                *item = object;
            }
        }
        None => {
            items.remove(at);
        }
    }
    true
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::{StringFormat, dictionary};

    use super::*;
    use crate::structure::tests::doc_with;
    use crate::{OpenOptions, Source, open};

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

    fn string(text: &str) -> Object {
        Object::String(text.as_bytes().to_vec(), StringFormat::Literal)
    }

    fn note(author: &str, contents: &str) -> Dictionary {
        dictionary! {
            "Subtype" => "Text",
            "Rect" => vec![10.into(), 10.into(), 30.into(), 30.into()],
            "T" => string(author),
            "Contents" => string(contents),
        }
    }

    #[test]
    fn a_reply_finds_its_thread_and_the_newest_state_counts() {
        let doc = opened(
            vec![dictionary! {
                "Annots" => vec![
                    Object::Reference((900, 0)),
                    Object::Reference((901, 0)),
                    Object::Reference((902, 0)),
                    Object::Reference((903, 0)),
                ],
            }],
            |model| {
                model.objects.insert((900, 0), note("Ali", "Bak").into());
                let mut reply = note("Veli", "Tamam @Ali");
                reply.set("IRT", Object::Reference((900, 0)));
                model.objects.insert((901, 0), reply.into());
                let mut done = note("Veli", "");
                done.set("IRT", Object::Reference((901, 0)));
                done.set("State", string("Completed"));
                done.set("StateModel", string("Review"));
                done.set("M", string("D:20261101120000Z"));
                model.objects.insert((902, 0), done.into());
                let mut again = note("Ali", "");
                again.set("IRT", Object::Reference((900, 0)));
                again.set("State", string("None"));
                again.set("StateModel", string("Review"));
                again.set("M", string("D:20261001120000Z"));
                model.objects.insert((903, 0), again.into());
            },
        );
        let list = RevisionStore::new(&doc).annotations(&doc);
        let [top, reply, done, _older] = &list.annotations[..] else {
            panic!("four annotations");
        };
        assert_eq!(reply.replies_to, Some(top.handle));
        assert_eq!(done.thread, top.handle);
        // The older reopening does not undo the newer resolution.
        assert_eq!(top.resolved.as_ref().unwrap().by.as_deref(), Some("Veli"));
        assert_eq!(list.people, ["Ali", "Veli"]);
        assert_eq!(reply.mentions, ["Ali"]);
    }

    #[test]
    fn cycles_deep_chains_and_huge_arrays_stop_at_limits() {
        let chain = u32::try_from(MAX_THREAD_DEPTH).unwrap() + 40;
        let huge = MAX_PER_PAGE + 5;
        let doc = opened(
            vec![
                dictionary! {
                    "Annots" => (1000..1000 + chain + 2)
                        .map(|number| Object::Reference((number, 0)))
                        .collect::<Vec<_>>(),
                },
                dictionary! {
                    "Annots" => vec![Object::Reference((800, 0)); huge],
                },
                dictionary! { "Annots" => (801, 0) },
            ],
            |model| {
                for number in 1000..1000 + chain {
                    let mut reply = note("A", "");
                    if number > 1000 {
                        reply.set("IRT", Object::Reference((number - 1, 0)));
                    }
                    model.objects.insert((number, 0), reply.into());
                }
                // Two that name each other, and one that names itself.
                let mut one = note("A", "");
                one.set("IRT", Object::Reference((1000 + chain + 1, 0)));
                model.objects.insert((1000 + chain, 0), one.into());
                let mut two = note("A", "");
                two.set("IRT", Object::Reference((1000 + chain, 0)));
                model.objects.insert((1000 + chain + 1, 0), two.into());
                let mut own = note("A", "");
                own.set("IRT", Object::Reference((800, 0)));
                model.objects.insert((800, 0), own.into());
                // `/Annots` that names itself.
                model
                    .objects
                    .insert((801, 0), Object::Array(vec![Object::Reference((801, 0))]));
            },
        );
        let list = RevisionStore::new(&doc).annotations(&doc);
        assert!(list.truncated, "the huge array says so");
        let cycle: Vec<&Annotation> = list
            .annotations
            .iter()
            .filter(|annotation| annotation.handle >= handle_of((1000 + chain, 0)))
            .collect();
        assert!(cycle.iter().all(|a| a.replies_to.is_none()), "{cycle:?}");
        let own = list
            .annotations
            .iter()
            .find(|a| a.handle == handle_of((800, 0)));
        assert_eq!(own.unwrap().replies_to, None);
        let deepest = list
            .annotations
            .iter()
            .find(|a| a.handle == handle_of((1000 + chain - 1, 0)))
            .unwrap();
        assert_eq!(deepest.replies_to, None, "past the limit it stands alone");
        let shallow = list
            .annotations
            .iter()
            .find(|a| a.handle == handle_of((1003, 0)))
            .unwrap();
        assert_eq!(shallow.thread, handle_of((1000, 0)));
    }

    #[test]
    fn a_change_keeps_every_other_key_and_a_direct_annotation_gets_an_object() {
        let mut rich = note("Ali", "Bak");
        rich.set("RC", string("<body>Bak</body>"));
        rich.set("ACME_Private", dictionary! { "Level" => 3 });
        let doc = opened(
            vec![dictionary! {
                "Annots" => vec![Object::Reference((900, 0)), Object::Dictionary(note("Veli", "Duz"))],
            }],
            |model| {
                model.objects.insert((900, 0), rich.into());
            },
        );
        let mut store = RevisionStore::new(&doc);
        let list = store.annotations(&doc);
        let (first, second) = (list.annotations[0].handle, list.annotations[1].handle);
        assert_ne!(second & DIRECT, 0);
        store.begin().unwrap();
        store
            .change_annotation(
                &doc,
                0,
                first,
                vec![(b"T".to_vec(), Some(Value::String(b"Yeni".to_vec())))],
            )
            .unwrap();
        let promoted = store
            .change_annotation(
                &doc,
                0,
                second,
                vec![(b"T".to_vec(), Some(Value::String(b"Yeni".to_vec())))],
            )
            .unwrap();
        store.commit().unwrap();
        let scope = store.scope(&doc);
        let dict = scope.dictionary((900, 0)).unwrap();
        assert_eq!(
            dict.get(b"RC").unwrap().as_str().unwrap(),
            b"<body>Bak</body>"
        );
        assert!(dict.has(b"ACME_Private"));
        let list = store.annotations(&doc);
        assert_eq!(list.annotations[1].handle, promoted.handle());
        assert_eq!(list.annotations[1].contents.as_deref(), Some("Duz"));
    }

    #[test]
    fn dropping_takes_the_popup_and_leaves_the_rest() {
        let mut with_popup = note("Ali", "Bak");
        with_popup.set("Popup", Object::Reference((901, 0)));
        let doc = opened(
            vec![dictionary! {
                "Annots" => vec![
                    Object::Dictionary(note("Direct", "1")),
                    Object::Reference((900, 0)),
                    Object::Reference((901, 0)),
                    Object::Dictionary(note("Direct", "2")),
                ],
            }],
            |model| {
                model.objects.insert((900, 0), with_popup.into());
                model.objects.insert(
                    (901, 0),
                    dictionary! { "Subtype" => "Popup", "Parent" => (900, 0) }.into(),
                );
            },
        );
        let mut store = RevisionStore::new(&doc);
        let list = store.annotations(&doc);
        assert_eq!(list.annotations.len(), 3, "the popup is not listed");
        let (direct, object) = (list.annotations[0].handle, list.annotations[1].handle);
        store.begin().unwrap();
        assert!(store.drop_annotation(&doc, 0, object).unwrap());
        assert!(!store.drop_annotation(&doc, 0, object).unwrap());
        assert!(store.drop_annotation(&doc, 0, direct).unwrap());
        store.commit().unwrap();
        let scope = store.scope(&doc);
        let page = store.page_id(&doc, 0).unwrap();
        let items = scope.get_array(scope.dictionary(page).unwrap(), b"Annots");
        assert_eq!(items.unwrap().len(), 1);
        assert_eq!(
            store.annotations(&doc).annotations[0].contents.as_deref(),
            Some("2")
        );
    }

    #[test]
    fn appearance_strings_give_their_size_and_colour() {
        let (size, color) = default_appearance(b"0.5 0 0 rg /Helv 10 Tf");
        assert_eq!(size, Some(10.0));
        assert_eq!(color, Some([0.5, 0.0, 0.0]));
        assert_eq!(default_appearance(b"/Helv Tf g"), (None, None));
    }
}
