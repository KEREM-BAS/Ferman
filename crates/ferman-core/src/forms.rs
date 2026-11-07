//! Form fields in the revisions of a document (M4 plan, W3, decisions 17 to 21): the reader, the
//! literal `AF*` arguments of decision 17, and the primitives ferman-ops writes through.
//!
//! The reader walks `/AcroForm /Fields` through the open revisions without recursion and stops at
//! the limits below however cyclic, deep or wide the tree is; a list cut short says so. It writes
//! nothing and generates nothing, so opening changes nothing (decision 19). A write sets only the
//! keys it names in an object's own dictionary, so a field not changed is not in the update.
//!
//! Scripts never run ([Q13](../../../docs/QUESTIONS.md#q13)). A script is read only when all of it
//! is one call of a known function with literal arguments; anything else declares nothing.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeSet, HashMap, HashSet};

use lopdf::{Dictionary, Object, ObjectId};

use crate::annotations::{MAX_PER_DOCUMENT, MAX_PER_PAGE, MAX_TEXTS, colour, default_appearance};
use crate::interpret::{FontResource, font_resource};
use crate::revision::{RevisionStore, decoded};
use crate::structure::{Scope, number};
use crate::write::{ObjectRef, Value};
use crate::{CoreError, Document, text_string};

/// The private key a simple signature's stamp carries: the full name of the field it signs
/// (decisions 20 and 21, G148). Never `/V` on a signature field.
pub const SIGNED_FIELD_KEY: &[u8] = b"FermanSignedField";
/// The most field nodes read from a document.
pub const MAX_NODES: usize = 100_000;
/// How deep the field tree is followed.
pub const MAX_DEPTH: u32 = 64;
/// The most options read from one field.
pub const MAX_OPTIONS: usize = 10_000;
/// The most options read from a document.
const MAX_ALL_OPTIONS: usize = 1_000_000;
/// The longest full name, in bytes.
const MAX_NAME: usize = 4096;
/// The longest script read for its declaration, in bytes.
const MAX_SCRIPT: usize = 16 * 1024;
/// Arguments of a call read.
const MAX_ARGUMENTS: usize = 8;

const READ_ONLY: i64 = 1;
const REQUIRED: i64 = 1 << 1;
const MULTILINE: i64 = 1 << 12;
const PASSWORD: i64 = 1 << 13;
const RADIO: i64 = 1 << 15;
const PUSH: i64 = 1 << 16;
const COMBO: i64 = 1 << 17;
const EDIT: i64 = 1 << 18;
const MULTI_SELECT: i64 = 1 << 21;
const COMB: i64 = 1 << 24;

/// What a field is.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum FieldKind {
    /// `/Tx`.
    Text,
    /// `/Btn`, a check box.
    Check,
    /// `/Btn` with the radio flag.
    Radio,
    /// `/Btn` with the push-button flag: nothing to fill.
    Push,
    /// `/Ch` with the combo flag.
    Combo,
    /// `/Ch`, a list box.
    List,
    /// `/Sig`.
    Signature,
    /// No known `/FT`.
    Other,
}

/// One choice of a combo or list box.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldOption {
    /// What `/V` holds.
    pub export: String,
    /// What the field shows.
    pub display: String,
}

/// The format a script's literal arguments declare (decision 17).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DeclaredFormat {
    /// A date in this `AFDate` pattern.
    Date(String),
    /// `AFNumber`: decimals, and the separator style 0 to 4.
    Number {
        /// Decimals.
        decimals: i32,
        /// `sepStyle`.
        separators: i32,
    },
    /// `AFPercent`, as [`Number`](Self::Number).
    Percent {
        /// Decimals.
        decimals: i32,
        /// `sepStyle`.
        separators: i32,
    },
}

/// What a field's scripts declare, read and never run.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Declared {
    /// `AFDate_*`, `AFNumber_*` or `AFPercent_*`.
    pub format: Option<DeclaredFormat>,
    /// `AFRange_Validate`'s least value.
    pub min: Option<f64>,
    /// `AFRange_Validate`'s greatest value.
    pub max: Option<f64>,
}

/// One widget of a field: a place on a page. Coordinates are in user space.
#[derive(Debug, Clone, PartialEq)]
pub struct Widget {
    /// Its object.
    pub object: ObjectRef,
    /// Its page's index.
    pub page: usize,
    /// `/Rect`, as left, bottom, right and top.
    pub rect: [f32; 4],
    /// `/F`.
    pub flags: u32,
    /// The state that turns a check box or radio button on: a key of `/AP /N` other than `/Off`,
    /// or one made up for a widget with no appearance. None for other fields.
    pub on_state: Option<Vec<u8>>,
    /// Whether `/AP` has `/N`.
    pub has_appearance: bool,
    /// `/MK /BG` as red, green and blue.
    pub background: Option<[f32; 3]>,
    /// `/MK /BC` as red, green and blue.
    pub border: Option<[f32; 3]>,
    /// `/BS /W`, else the third of `/Border`, else 1.
    pub border_width: f32,
    /// `/MK /R`.
    pub turn: i64,
}

/// One field: the nodes that share a full name, with all their widgets, in tab order.
#[derive(Debug, Clone, PartialEq)]
pub struct Field {
    /// Its identity: its first node's. It stays through edits, undo and saves.
    pub handle: u64,
    /// Its full name.
    pub name: String,
    /// `/TU`.
    pub label: Option<String>,
    /// What it is.
    pub kind: FieldKind,
    /// `/Ff`'s read-only flag.
    pub read_only: bool,
    /// `/Ff`'s required flag.
    pub required: bool,
    /// A text field's multi-line flag.
    pub multiline: bool,
    /// A text field's password flag.
    pub password: bool,
    /// A text field's comb flag, with a `/MaxLen`.
    pub comb: bool,
    /// A list box's multiple-selection flag.
    pub multi_select: bool,
    /// A combo box's edit flag.
    pub editable: bool,
    /// A text field's or choice's value, a choice's export values, or the state a button is in.
    /// Empty when it holds nothing; `/Off` counts as nothing.
    pub values: Vec<String>,
    /// A choice's options.
    pub options: Vec<FieldOption>,
    /// `/TI`: the first option a list box shows.
    pub top_index: usize,
    /// `/MaxLen`.
    pub max_len: Option<u32>,
    /// The font name `/DA` sets.
    pub font: Option<Vec<u8>>,
    /// The font size `/DA` sets; none for automatic.
    pub font_size: Option<f32>,
    /// The colour `/DA` sets.
    pub text_color: [f32; 3],
    /// `/Q`: 0 left, 1 centre, 2 right.
    pub align: u8,
    /// Its widgets, in tab order.
    pub widgets: Vec<Widget>,
    /// The nodes that carry its value.
    pub nodes: Vec<ObjectRef>,
    /// The entries of `/Fields` its nodes come from.
    pub roots: Vec<ObjectRef>,
    /// What its scripts declare.
    pub declared: Declared,
    /// Whether a signature field holds a digital signature (`/V`).
    pub signed: bool,
    /// The stamp of a simple signature that names this field (decisions 20 and 21).
    pub signature: Option<u64>,
}

impl Field {
    /// Whether it counts as filled: it holds a value, or for a signature field either kind of
    /// signature.
    #[must_use]
    pub fn filled(&self) -> bool {
        if self.kind == FieldKind::Signature {
            return self.signed || self.signature.is_some();
        }
        !self.values.is_empty()
    }
}

/// A document's form as the revisions leave it.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct FormFields {
    /// In tab order: by page, then `/Tabs` (decision of a5-1).
    pub fields: Vec<Field>,
    /// Whether `/AcroForm` has `/XFA`.
    pub has_xfa: bool,
    /// `/NeedAppearances`.
    pub need_appearances: bool,
    /// Whether a limit cut the list short.
    pub truncated: bool,
    /// The entries of `/Fields` under which a node was not read: a limit, a widget on no page or
    /// a node that is neither field nor widget. What they hold may be in no field here.
    pub partial_roots: Vec<ObjectRef>,
}

/// A font of `/AcroForm /DR`, for writing a field's text in.
#[derive(Debug, Clone, PartialEq)]
pub struct FormFont {
    /// What a form's `/Resources` names it by.
    pub value: Value,
    /// Its description.
    pub resource: FontResource,
}

/// What a field inherits on the way down.
#[derive(Clone, Copy, Default)]
struct Inherited<'a> {
    kind: Option<&'a [u8]>,
    flags: Option<i64>,
    value: Option<&'a Object>,
    da: Option<&'a [u8]>,
    align: Option<i64>,
    max_len: Option<i64>,
}

/// The bytes of a name's on-state, by how a state dictionary lists them.
fn on_state(scope: &Scope<'_>, widget: &Dictionary) -> Option<Vec<u8>> {
    let normal = scope.get_dict(scope.get_dict(widget, b"AP")?, b"N")?;
    normal
        .iter()
        .map(|(key, _)| key)
        .find(|key| key.as_slice() != b"Off")
        .cloned()
}

fn has_normal(scope: &Scope<'_>, widget: &Dictionary) -> bool {
    scope
        .get_dict(widget, b"AP")
        .is_some_and(|appearance| appearance.has(b"N"))
}

fn numbers(scope: &Scope<'_>, dict: &Dictionary, key: &[u8]) -> Vec<f32> {
    const MOST: usize = 8;
    scope
        .get_array(dict, key)
        .map(|items| {
            items
                .iter()
                .take(MOST)
                .filter_map(|item| scope.resolve(item).and_then(number))
                .collect()
        })
        .unwrap_or_default()
}

fn widget_of(
    scope: &Scope<'_>,
    object: ObjectId,
    dict: &Dictionary,
    page: usize,
    ordinal: usize,
    button: bool,
    field_value: Option<&[u8]>,
) -> Widget {
    let mk = scope.get_dict(dict, b"MK");
    let colour_of = |key: &[u8]| mk.and_then(|mk| colour(&numbers(scope, mk, key)));
    let [l, b, r, t] = match *numbers(scope, dict, b"Rect").as_slice() {
        [a, b, c, d] => [a.min(c), b.min(d), a.max(c), b.max(d)],
        _ => [0.0; 4],
    };
    let border_width = scope
        .get_dict(dict, b"BS")
        .and_then(|style| style.get(b"W").ok())
        .and_then(|width| scope.resolve(width))
        .and_then(number)
        .or_else(|| numbers(scope, dict, b"Border").get(2).copied())
        .unwrap_or(1.0)
        .clamp(0.0, 144.0);
    let on = button.then(|| on_state(scope, dict)).flatten().or_else(|| {
        if !button {
            return None;
        }
        // No appearance: its own state, the field's, or one made up, so it can be told apart.
        scope
            .get_name(dict, b"AS")
            .filter(|state| *state != b"Off")
            .or(field_value)
            .map_or_else(
                || Some(format!("Choice{ordinal}").into_bytes()),
                |state| Some(state.to_vec()),
            )
    });
    Widget {
        object: ObjectRef(object),
        page,
        rect: [l, b, r, t],
        flags: scope
            .get_int(dict, b"F")
            .and_then(|flags| u32::try_from(flags).ok())
            .unwrap_or(0),
        on_state: on,
        has_appearance: has_normal(scope, dict),
        background: colour_of(b"BG"),
        border: colour_of(b"BC"),
        border_width,
        turn: mk
            .and_then(|mk| scope.get_int(mk, b"R"))
            .map_or(0, |turn| turn.rem_euclid(360)),
    }
}

/// `object`'s text, a string or a stream, within `left`. A stream decodes through `doc`'s limits.
fn text_of(
    scope: &Scope<'_>,
    doc: &Document,
    object: &Object,
    longest: usize,
    left: &mut usize,
    truncated: &mut bool,
) -> Option<String> {
    let owned;
    let raw: &[u8] = match scope.resolve(object)? {
        Object::String(bytes, _) => bytes,
        Object::Stream(stream) => {
            owned = decoded(stream, doc).ok()?;
            &owned
        }
        _ => return None,
    };
    let keep = raw.len().min(longest);
    if keep < raw.len() {
        *truncated = true;
    }
    let Some(rest) = left.checked_sub(keep) else {
        *truncated = true;
        return None;
    };
    *left = rest;
    Some(text_string::decode(raw.get(..keep)?))
}

/// The values `value` holds for a field of `kind`.
fn values_of(
    scope: &Scope<'_>,
    doc: &Document,
    value: Option<&Object>,
    left: &mut usize,
    truncated: &mut bool,
) -> Vec<String> {
    let Some(value) = value.and_then(|value| scope.resolve(value)) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    match value {
        Object::Name(name) if name.as_slice() != b"Off" => {
            out.push(String::from_utf8_lossy(name).into_owned());
        }
        Object::Array(items) => {
            for item in items.iter().take(MAX_OPTIONS) {
                if let Some(text) = text_of(scope, doc, item, MAX_NAME, left, truncated) {
                    out.push(text);
                }
            }
        }
        Object::Name(_) => {}
        other => {
            if let Some(text) = text_of(
                scope,
                doc,
                other,
                crate::annotations::MAX_TEXT,
                left,
                truncated,
            ) && !text.is_empty()
            {
                out.push(text);
            }
        }
    }
    out
}

fn options_of(
    scope: &Scope<'_>,
    doc: &Document,
    dict: &Dictionary,
    budget: &mut Reading,
) -> Vec<FieldOption> {
    let Some(items) = scope.get_array(dict, b"Opt") else {
        return Vec::new();
    };
    if items.len() > MAX_OPTIONS || items.len() > budget.options {
        budget.truncated = true;
    }
    let keep = items.len().min(MAX_OPTIONS).min(budget.options);
    budget.options = budget.options.saturating_sub(keep);
    let Reading {
        text, truncated, ..
    } = budget;
    items
        .iter()
        .take(keep)
        .filter_map(|item| {
            let item = scope.resolve(item)?;
            if let Ok(pair) = item.as_array() {
                let export = text_of(scope, doc, pair.first()?, MAX_NAME, text, truncated)?;
                let display = text_of(scope, doc, pair.get(1)?, MAX_NAME, text, truncated)?;
                return Some(FieldOption { export, display });
            }
            let export = text_of(scope, doc, item, MAX_NAME, text, truncated)?;
            Some(FieldOption {
                display: export.clone(),
                export,
            })
        })
        .collect()
}

/// What the walk may still read.
struct Reading {
    nodes: usize,
    options: usize,
    text: usize,
    truncated: bool,
}

/// `dict`'s `/AA` entry `key` as a script, as text.
fn script(
    scope: &Scope<'_>,
    doc: &Document,
    additional: &Dictionary,
    key: &[u8],
    budget: &mut Reading,
) -> Option<String> {
    let action = scope.get_dict(additional, key)?;
    if scope.get_name(action, b"S") != Some(b"JavaScript") {
        return None;
    }
    let Reading {
        text, truncated, ..
    } = budget;
    text_of(
        scope,
        doc,
        action.get(b"JS").ok()?,
        MAX_SCRIPT,
        text,
        truncated,
    )
}

fn declared_of(
    scope: &Scope<'_>,
    doc: &Document,
    dict: &Dictionary,
    budget: &mut Reading,
) -> Declared {
    let mut declared = Declared::default();
    let Some(additional) = scope.get_dict(dict, b"AA") else {
        return declared;
    };
    for key in [&b"F"[..], b"K", b"V"] {
        let Some(script) = script(scope, doc, additional, key, budget) else {
            continue;
        };
        let read = read_script(&script);
        declared.format = declared.format.take().or(read.format);
        declared.min = declared.min.or(read.min);
        declared.max = declared.max.or(read.max);
    }
    declared
}

/// The font name a `/DA` string's `Tf` sets.
fn font_name(da: &[u8]) -> Option<Vec<u8>> {
    const LONGEST: usize = 4096;
    let mut name = None;
    let mut found = None;
    for token in da
        .get(..da.len().min(LONGEST))?
        .split(u8::is_ascii_whitespace)
        .filter(|token| !token.is_empty())
    {
        if let Some(rest) = token.strip_prefix(b"/") {
            name = Some(rest);
        } else if token == b"Tf" {
            found = name.map(<[u8]>::to_vec);
        }
    }
    found
}

fn kind_of(kind: Option<&[u8]>, flags: i64) -> FieldKind {
    match kind {
        Some(b"Tx") => FieldKind::Text,
        Some(b"Btn") if flags & PUSH != 0 => FieldKind::Push,
        Some(b"Btn") if flags & RADIO != 0 => FieldKind::Radio,
        Some(b"Btn") => FieldKind::Check,
        Some(b"Ch") if flags & COMBO != 0 => FieldKind::Combo,
        Some(b"Ch") => FieldKind::List,
        Some(b"Sig") => FieldKind::Signature,
        _ => FieldKind::Other,
    }
}

/// Where each annotation sits, and the stamps that name a signed field.
struct Places {
    at: HashMap<ObjectId, (usize, usize)>,
    /// A page's `/Tabs`.
    tabs: Vec<Option<Vec<u8>>>,
    /// Stamps by the field they name.
    stamps: HashMap<String, u64>,
}

fn places(scope: &Scope<'_>, pages: &[crate::structure::Page], budget: &mut Reading) -> Places {
    let mut found = Places {
        at: HashMap::new(),
        tabs: Vec::with_capacity(pages.len()),
        stamps: HashMap::new(),
    };
    let mut left = MAX_PER_DOCUMENT;
    for (index, page) in pages.iter().enumerate() {
        let dict = scope.dictionary(page.id);
        found.tabs.push(
            dict.and_then(|dict| scope.get_name(dict, b"Tabs"))
                .map(<[u8]>::to_vec),
        );
        let items = dict.and_then(|dict| scope.get_array(dict, b"Annots"));
        for (ordinal, item) in items.into_iter().flatten().take(MAX_PER_PAGE).enumerate() {
            let Some(rest) = left.checked_sub(1) else {
                budget.truncated = true;
                return found;
            };
            left = rest;
            let Ok(id) = item.as_reference() else {
                continue;
            };
            found.at.entry(id).or_insert((index, ordinal));
            if let Some(annotation) = scope.dict(item)
                && annotation.has(SIGNED_FIELD_KEY)
                && scope.get_name(annotation, b"Subtype") == Some(b"Stamp")
                && let Some(name) = scope.get_text(annotation, SIGNED_FIELD_KEY)
            {
                found
                    .stamps
                    .entry(name)
                    .or_insert_with(|| crate::annotations::handle_of(id));
            }
        }
    }
    found
}

/// The widgets of `pages` in tab order: `(page, rank)` for each object.
fn tab_ranks(
    pages: &[crate::structure::Page],
    places: &Places,
    fields: &[Field],
) -> HashMap<ObjectRef, (usize, usize)> {
    /// How far apart two tops or lefts may be and still share a row or column, in points.
    const SAME_LINE: f32 = 3.0;
    let mut by_page: HashMap<usize, Vec<(ObjectRef, [f32; 4], usize)>> = HashMap::new();
    for field in fields {
        for widget in &field.widgets {
            let ordinal = places
                .at
                .get(&widget.object.0)
                .map_or(usize::MAX, |at| at.1);
            let [l, b, r, t] = widget.rect;
            let shown = pages.get(widget.page).map_or([l, t, r, b], |page| {
                let (x0, y0) = page.display_point(l, t);
                let (x1, y1) = page.display_point(r, b);
                [x0.min(x1), y0.min(y1), x0.max(x1), y0.max(y1)]
            });
            by_page
                .entry(widget.page)
                .or_default()
                .push((widget.object, shown, ordinal));
        }
    }
    let mut ranks = HashMap::new();
    for (page, mut widgets) in by_page {
        widgets.sort_by_key(|widget| widget.2);
        let tabs = places.tabs.get(page).and_then(Option::as_deref);
        // Row order; column order swaps the axes. shortcut: /Tabs /S takes /Annots order, not the
        // structure tree's; read that tree if a tagged form tabs wrongly.
        let axes = match tabs {
            Some(b"R") => Some((1, 0)),
            Some(b"C") => Some((0, 1)),
            _ => None,
        };
        if let Some((line, along)) = axes {
            let at = |frame: &[f32; 4], axis: usize| frame.get(axis).copied().unwrap_or(0.0);
            widgets.sort_by(|a, b| at(&a.1, line).total_cmp(&at(&b.1, line)));
            let mut lines: Vec<Vec<(ObjectRef, [f32; 4], usize)>> = Vec::new();
            for widget in widgets {
                match lines.last_mut() {
                    Some(current)
                        if current.first().is_some_and(|first| {
                            at(&widget.1, line) - at(&first.1, line) <= SAME_LINE
                        }) =>
                    {
                        current.push(widget);
                    }
                    _ => lines.push(vec![widget]),
                }
            }
            for current in &mut lines {
                current.sort_by(|a, b| at(&a.1, along).total_cmp(&at(&b.1, along)));
            }
            widgets = lines.into_iter().flatten().collect();
        }
        for (rank, widget) in widgets.into_iter().enumerate() {
            ranks.insert(widget.0, (page, rank));
        }
    }
    ranks
}

impl RevisionStore {
    /// The form as these revisions and the open transaction leave it.
    #[must_use]
    #[allow(clippy::too_many_lines)]
    pub fn form_fields(&self, doc: &Document) -> FormFields {
        let scope = self.scope(doc);
        let Some(form) = scope
            .catalog()
            .and_then(|catalog| scope.get_dict(catalog, b"AcroForm"))
        else {
            return FormFields::default();
        };
        let mut list = FormFields {
            has_xfa: form.has(b"XFA"),
            need_appearances: matches!(
                scope.get(form, b"NeedAppearances"),
                Some(Object::Boolean(true))
            ),
            ..FormFields::default()
        };
        let pages = self.pages(doc);
        let mut budget = Reading {
            nodes: MAX_NODES,
            options: MAX_ALL_OPTIONS,
            text: MAX_TEXTS,
            truncated: false,
        };
        let places = places(&scope, pages, &mut budget);
        let form_da = scope.get(form, b"DA").and_then(|da| da.as_str().ok());
        let form_align = scope.get_int(form, b"Q");
        // (node, full name of its parent, what it inherits, depth, its root).
        type Frame<'a> = (ObjectId, String, Inherited<'a>, u32, Option<ObjectId>);
        let mut stack: Vec<Frame<'_>> = scope
            .get_array(form, b"Fields")
            .map(|fields| {
                let keep = fields.len().min(MAX_NODES);
                if keep < fields.len() {
                    budget.truncated = true;
                }
                fields
                    .iter()
                    .take(keep)
                    .rev()
                    .filter_map(|field| field.as_reference().ok())
                    .map(|id| (id, String::new(), Inherited::default(), 0, None))
                    .collect()
            })
            .unwrap_or_default();
        let mut seen = BTreeSet::new();
        let mut named: HashMap<String, usize> = HashMap::new();
        let mut unread: BTreeSet<ObjectId> = BTreeSet::new();
        while let Some((id, parent, above, depth, root)) = stack.pop() {
            if !seen.insert(id) {
                continue;
            }
            let Some(rest) = budget.nodes.checked_sub(1) else {
                budget.truncated = true;
                unread.insert(root.unwrap_or(id));
                unread.extend(stack.iter().map(|frame| frame.4.unwrap_or(frame.0)));
                break;
            };
            budget.nodes = rest;
            let Some(dict) = scope.dictionary(id) else {
                continue;
            };
            let partial = scope.get_text(dict, b"T");
            let name = match (&partial, parent.is_empty()) {
                (Some(partial), true) => partial.clone(),
                (Some(partial), false) => format!("{parent}.{partial}"),
                (None, _) => parent.clone(),
            };
            if name.len() > MAX_NAME {
                budget.truncated = true;
                unread.insert(root.unwrap_or(id));
                continue;
            }
            let here = Inherited {
                kind: scope.get_name(dict, b"FT").or(above.kind),
                flags: scope.get_int(dict, b"Ff").or(above.flags),
                value: dict.get(b"V").ok().or(above.value),
                da: scope
                    .get(dict, b"DA")
                    .and_then(|da| da.as_str().ok())
                    .or(above.da),
                align: scope.get_int(dict, b"Q").or(above.align),
                max_len: scope.get_int(dict, b"MaxLen").or(above.max_len),
            };
            let root = root.unwrap_or(id);
            let kids: Vec<ObjectId> = scope
                .get_array(dict, b"Kids")
                .map(|kids| {
                    if kids.len() > budget.nodes {
                        unread.insert(root);
                    }
                    kids.iter()
                        .take(budget.nodes)
                        .filter_map(|kid| kid.as_reference().ok())
                        .collect()
                })
                .unwrap_or_default();
            // Kids with a /T are fields; kids without are its widgets.
            let (fields, widgets): (Vec<ObjectId>, Vec<ObjectId>) = kids
                .into_iter()
                .partition(|kid| scope.dictionary(*kid).is_some_and(|kid| kid.has(b"T")));
            if depth < MAX_DEPTH {
                for kid in fields.iter().rev() {
                    stack.push((
                        *kid,
                        name.clone(),
                        here,
                        depth.saturating_add(1),
                        Some(root),
                    ));
                }
            } else if !fields.is_empty() {
                budget.truncated = true;
                unread.insert(root);
            }
            let own_widget =
                dict.has(b"Rect") && scope.get_name(dict, b"Subtype") == Some(b"Widget");
            if !fields.is_empty() && widgets.is_empty() && !own_widget {
                continue;
            }
            let mut placed: Vec<ObjectId> = widgets;
            if own_widget {
                placed.insert(0, id);
            }
            let flags = here.flags.unwrap_or(0);
            let kind = kind_of(here.kind, flags);
            let button = matches!(kind, FieldKind::Check | FieldKind::Radio);
            let value_name = here
                .value
                .and_then(|value| scope.resolve(value))
                .and_then(|value| value.as_name().ok())
                .filter(|state| *state != b"Off");
            let found: Vec<Widget> = placed
                .iter()
                .enumerate()
                .filter_map(|(ordinal, widget)| {
                    let (page, _) = places.at.get(widget)?;
                    let widget_dict = scope.dictionary(*widget)?;
                    let radio = flags & RADIO != 0 && placed.len() > 1;
                    Some(widget_of(
                        &scope,
                        *widget,
                        widget_dict,
                        *page,
                        ordinal,
                        button,
                        value_name.filter(|_| !radio),
                    ))
                })
                .collect();
            if found.len() < placed.len() || found.is_empty() {
                // A widget on no page, such as an invisible signature's with only /P, a kid that is
                // no widget, or none at all: what it holds stays where it is.
                unread.insert(root);
            }
            if let Some(&at) = named.get(&name).filter(|_| !name.is_empty())
                && let Some(field) = list.fields.get_mut(at)
            {
                // The same name again: one field, one value (ISO 32000-2 §12.7.4.1).
                field.nodes.push(ObjectRef(id));
                if !field.roots.contains(&ObjectRef(root)) {
                    field.roots.push(ObjectRef(root));
                }
                field.widgets.extend(found);
                continue;
            }
            if found.is_empty() {
                // On no page: nothing to fill, and a reader shows nothing for it.
                continue;
            }
            let (_, colour) = here.da.map_or((None, None), default_appearance);
            let da = here.da.or(form_da);
            let (size, form_colour) = da.map_or((None, None), default_appearance);
            let Reading {
                text, truncated, ..
            } = &mut budget;
            let values = if kind == FieldKind::Signature {
                Vec::new()
            } else {
                values_of(&scope, doc, here.value, text, truncated)
            };
            let options = if matches!(kind, FieldKind::Combo | FieldKind::List) {
                options_of(&scope, doc, dict, &mut budget)
            } else {
                Vec::new()
            };
            let declared = if kind == FieldKind::Text {
                declared_of(&scope, doc, dict, &mut budget)
            } else {
                Declared::default()
            };
            let label = {
                let Reading {
                    text, truncated, ..
                } = &mut budget;
                dict.get(b"TU")
                    .ok()
                    .and_then(|label| text_of(&scope, doc, label, MAX_NAME, text, truncated))
            };
            named.insert(name.clone(), list.fields.len());
            list.fields.push(Field {
                handle: crate::annotations::handle_of(id),
                label,
                kind,
                read_only: flags & READ_ONLY != 0,
                required: flags & REQUIRED != 0,
                multiline: flags & MULTILINE != 0,
                password: flags & PASSWORD != 0,
                comb: flags & COMB != 0 && here.max_len.is_some_and(|max| max > 0),
                multi_select: flags & MULTI_SELECT != 0,
                editable: flags & EDIT != 0,
                values,
                options,
                top_index: scope
                    .get_int(dict, b"TI")
                    .and_then(|top| usize::try_from(top).ok())
                    .unwrap_or(0),
                max_len: here.max_len.and_then(|max| u32::try_from(max).ok()),
                font: da.and_then(font_name),
                font_size: size,
                text_color: colour.or(form_colour).unwrap_or([0.0; 3]),
                align: match here.align.or(form_align) {
                    Some(1) => 1,
                    Some(2) => 2,
                    _ => 0,
                },
                widgets: found,
                nodes: vec![ObjectRef(id)],
                roots: vec![ObjectRef(root)],
                declared,
                signed: kind == FieldKind::Signature && here.value.is_some(),
                signature: places.stamps.get(&name).copied(),
                name,
            });
        }
        list.truncated = budget.truncated;
        list.partial_roots = unread.into_iter().map(ObjectRef).collect();
        let ranks = tab_ranks(pages, &places, &list.fields);
        let rank = |widget: &Widget| {
            ranks
                .get(&widget.object)
                .copied()
                .unwrap_or((usize::MAX, usize::MAX))
        };
        for field in &mut list.fields {
            field.widgets.sort_by_key(rank);
        }
        list.fields
            .sort_by_key(|field| field.widgets.first().map_or((usize::MAX, usize::MAX), rank));
        list
    }

    /// Sets or removes `entries` of the dictionary `object` in the open transaction; its other
    /// keys stay. Nothing is written when that changes nothing.
    ///
    /// # Errors
    ///
    /// [`crate::WriteError::NoTransaction`], and [`crate::WriteError::NoSuchPage`] when it is no
    /// dictionary.
    pub fn change_entries(
        &mut self,
        doc: &Document,
        object: ObjectRef,
        entries: Vec<(Vec<u8>, Option<Value>)>,
    ) -> Result<(), CoreError> {
        let before = self.dictionary(doc, object.0)?;
        let mut dict = before.clone();
        apply(&mut dict, entries)?;
        if dict != before {
            self.put(object.0, Object::Dictionary(dict))?;
        }
        Ok(())
    }

    /// `/AcroForm`'s own object, or the catalog's when it is written there, with a copy of it.
    fn form_dictionary(&self, doc: &Document) -> Option<(ObjectId, bool, Dictionary)> {
        let root = doc.xref().trailer.get(b"Root").ok()?.as_reference().ok()?;
        let scope = self.scope(doc);
        let catalog = scope.dictionary(root)?;
        match catalog.get(b"AcroForm").ok()? {
            Object::Reference(id) => Some((*id, false, scope.dictionary(*id)?.clone())),
            direct => Some((root, true, direct.as_dict().ok()?.clone())),
        }
    }

    /// Sets or removes `entries` of `/AcroForm` in the open transaction; a document with no form
    /// stays as it is. The change is written to the object that holds `/AcroForm`.
    ///
    /// # Errors
    ///
    /// [`crate::WriteError::NoTransaction`].
    pub fn change_form(
        &mut self,
        doc: &Document,
        entries: Vec<(Vec<u8>, Option<Value>)>,
    ) -> Result<(), CoreError> {
        let Some((id, in_catalog, before)) = self.form_dictionary(doc) else {
            return Ok(());
        };
        let mut dict = before.clone();
        apply(&mut dict, entries)?;
        if dict == before {
            return Ok(());
        }
        if in_catalog {
            let mut catalog = self.dictionary(doc, id)?;
            catalog.set("AcroForm", Object::Dictionary(dict));
            self.put(id, Object::Dictionary(catalog))
        } else {
            self.put(id, Object::Dictionary(dict))
        }
    }

    /// The entries of `/Fields` that are references, in order.
    #[must_use]
    pub fn form_roots(&self, doc: &Document) -> Vec<ObjectRef> {
        let scope = self.scope(doc);
        scope
            .catalog()
            .and_then(|catalog| scope.get_dict(catalog, b"AcroForm"))
            .and_then(|form| scope.get_array(form, b"Fields"))
            .map(|fields| {
                fields
                    .iter()
                    .filter_map(|field| field.as_reference().ok())
                    .map(ObjectRef)
                    .collect()
            })
            .unwrap_or_default()
    }

    /// Makes `roots` all of `/Fields` in the open transaction, for Finish.
    ///
    /// # Errors
    ///
    /// As [`change_form`](Self::change_form).
    pub fn set_form_roots(&mut self, doc: &Document, roots: &[ObjectRef]) -> Result<(), CoreError> {
        let roots = roots.iter().map(|root| Value::Reference(*root)).collect();
        self.change_form(doc, vec![(b"Fields".to_vec(), Some(Value::Array(roots)))])
    }

    /// The font `/AcroForm /DR /Font` names `name`, read through the document's limits.
    ///
    /// # Errors
    ///
    /// The errors of decoding its streams.
    pub fn form_font(&self, doc: &Document, name: &[u8]) -> Result<Option<FormFont>, CoreError> {
        let scope = self.scope(doc);
        let Some(entry) = scope
            .catalog()
            .and_then(|catalog| scope.get_dict(catalog, b"AcroForm"))
            .and_then(|form| scope.get_dict(form, b"DR"))
            .and_then(|resources| scope.get_dict(resources, b"Font"))
            .and_then(|fonts| fonts.get(name).ok())
        else {
            return Ok(None);
        };
        let Some(font) = scope.dict(entry) else {
            return Ok(None);
        };
        let mut used = 0;
        let resource = font_resource(&scope, font, 0, &mut used, None)?;
        Ok(Some(FormFont {
            value: Value::of(entry, doc)?,
            resource,
        }))
    }

    /// A prefix no font of `/AcroForm /DR /Font` starts with.
    #[must_use]
    pub fn free_form_font_prefix(&self, doc: &Document) -> String {
        let scope = self.scope(doc);
        let fonts = scope
            .catalog()
            .and_then(|catalog| scope.get_dict(catalog, b"AcroForm"))
            .and_then(|form| scope.get_dict(form, b"DR"))
            .and_then(|resources| scope.get_dict(resources, b"Font"));
        // The numbers n of keys that start with `Fm{n}F`, read once: a hostile /DR may hold many.
        let taken: HashSet<u64> = fonts
            .into_iter()
            .flat_map(|fonts| fonts.iter())
            .filter_map(|(key, _)| {
                let rest = key.strip_prefix(b"Fm")?;
                let digits = rest.iter().take_while(|byte| byte.is_ascii_digit()).count();
                let (number, after) = rest.split_at_checked(digits)?;
                // Leading zeros name no prefix this makes: Fm01F is not Fm1F.
                let plain = number.first() != Some(&b'0') || number.len() == 1;
                (after.first() == Some(&b'F') && plain)
                    .then(|| std::str::from_utf8(number).ok()?.parse().ok())
                    .flatten()
            })
            .collect();
        // At most taken.len() + 1 tries.
        let free = (0u64..).find(|number| !taken.contains(number)).unwrap_or(0);
        format!("Fm{free}F")
    }

    /// Adds `fonts` to `/AcroForm /DR /Font` in the open transaction (decision 18). `/DR` and its
    /// `/Font` are written direct in the form, never through a reference that may name a page's
    /// resources.
    ///
    /// # Errors
    ///
    /// As [`change_form`](Self::change_form).
    pub fn add_form_fonts(
        &mut self,
        doc: &Document,
        fonts: Vec<(Vec<u8>, Value)>,
    ) -> Result<(), CoreError> {
        let Some((_, _, form)) = self.form_dictionary(doc) else {
            return Ok(());
        };
        let scope = self.scope(doc);
        let mut resources = scope.get_dict(&form, b"DR").cloned().unwrap_or_default();
        let mut entries = scope
            .get_dict(&resources, b"Font")
            .cloned()
            .unwrap_or_default();
        for (key, value) in fonts {
            entries.set(key, value.into_object()?);
        }
        resources.set("Font", Object::Dictionary(entries));
        let resources = Value::of(&Object::Dictionary(resources), doc)?;
        self.change_form(doc, vec![(b"DR".to_vec(), Some(resources))])
    }
}

fn apply(dict: &mut Dictionary, entries: Vec<(Vec<u8>, Option<Value>)>) -> Result<(), CoreError> {
    for (key, value) in entries {
        match value {
            Some(value) => dict.set(key, value.into_object()?),
            None => {
                dict.remove(&key);
            }
        }
    }
    Ok(())
}

/// One literal argument of a call.
#[derive(Debug, Clone, PartialEq)]
enum Argument {
    Number(f64),
    Boolean(bool),
    Text(String),
}

/// A script as one call with literal arguments; `None` for anything else, a second statement
/// included.
fn one_call(script: &str) -> Option<(&str, Vec<Argument>)> {
    if script.len() > MAX_SCRIPT {
        return None;
    }
    let (name, rest) = script.trim().split_once('(')?;
    let name = name.trim();
    if name.is_empty()
        || !name
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'_')
    {
        return None;
    }
    let mut chars = rest.chars().peekable();
    let mut arguments = Vec::new();
    let skip = |chars: &mut std::iter::Peekable<std::str::Chars<'_>>| {
        while chars.next_if(|c| c.is_whitespace()).is_some() {}
    };
    skip(&mut chars);
    if chars.next_if_eq(&')').is_none() {
        loop {
            if arguments.len() >= MAX_ARGUMENTS {
                return None;
            }
            skip(&mut chars);
            let argument = match chars.peek()? {
                '"' | '\'' => {
                    let quote = chars.next()?;
                    let mut text = String::new();
                    loop {
                        match chars.next()? {
                            '\\' => match chars.next()? {
                                'n' => text.push('\n'),
                                't' => text.push('\t'),
                                other => text.push(other),
                            },
                            c if c == quote => break,
                            c => text.push(c),
                        }
                    }
                    Argument::Text(text)
                }
                _ => {
                    let mut word = String::new();
                    while let Some(c) =
                        chars.next_if(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '+' | '.'))
                    {
                        word.push(c);
                    }
                    match word.as_str() {
                        "true" => Argument::Boolean(true),
                        "false" => Argument::Boolean(false),
                        // Digits only: no 1e400, Infinity or NaN.
                        _ => Argument::Number(
                            word.bytes()
                                .all(|byte| {
                                    byte.is_ascii_digit() || matches!(byte, b'-' | b'+' | b'.')
                                })
                                .then(|| word.parse::<f64>().ok())
                                .flatten()
                                .filter(|value| value.is_finite())?,
                        ),
                    }
                }
            };
            arguments.push(argument);
            skip(&mut chars);
            match chars.next()? {
                ',' => {}
                ')' => break,
                _ => return None,
            }
        }
    }
    skip(&mut chars);
    chars.next_if_eq(&';');
    skip(&mut chars);
    chars.next().is_none().then_some((name, arguments))
}

/// `AFDate_Format`'s table of patterns, as Acrobat's scripts number them.
const DATE_PATTERNS: [&str; 14] = [
    "m/d",
    "m/d/yy",
    "mm/dd/yy",
    "mm/yy",
    "d-mmm",
    "d-mmm-yy",
    "dd-mmm-yy",
    "yy-mm-dd",
    "mmm-yy",
    "mmmm-yy",
    "mmm d, yyyy",
    "mmmm d, yyyy",
    "m/d/yy h:MM tt",
    "m/d/yy HH:MM",
];

/// The longest date pattern kept.
const MAX_PATTERN: usize = 64;

fn whole(value: f64) -> Option<i32> {
    // Within the range the casts below keep, so `as` loses nothing but a fraction.
    #[allow(clippy::cast_possible_truncation)]
    (value.abs() <= 1_000.0 && value.fract() == 0.0).then_some(value as i32)
}

/// What `script` declares when all of it is one call of AFDate, AFNumber, AFPercent or AFRange
/// with literal arguments (decision 17). Nothing runs, and everything else declares nothing,
/// `AFSimple_Calculate` included.
#[must_use]
pub fn read_script(script: &str) -> Declared {
    let mut declared = Declared::default();
    let Some((name, arguments)) = one_call(script) else {
        return declared;
    };
    let number = |at: usize| match arguments.get(at) {
        Some(Argument::Number(value)) => Some(*value),
        _ => None,
    };
    match name {
        "AFDate_FormatEx" | "AFDate_KeystrokeEx" => {
            if let Some(Argument::Text(pattern)) = arguments.first()
                && pattern.len() <= MAX_PATTERN
                && !pattern.is_empty()
            {
                declared.format = Some(DeclaredFormat::Date(pattern.clone()));
            }
        }
        "AFDate_Format" | "AFDate_Keystroke" => {
            declared.format = number(0)
                .and_then(whole)
                .and_then(|at| usize::try_from(at).ok())
                .and_then(|at| DATE_PATTERNS.get(at))
                .map(|pattern| DeclaredFormat::Date((*pattern).to_owned()));
        }
        "AFNumber_Format" | "AFNumber_Keystroke" => {
            if let (Some(decimals), Some(separators)) =
                (number(0).and_then(whole), number(1).and_then(whole))
            {
                declared.format = Some(DeclaredFormat::Number {
                    decimals,
                    separators,
                });
            }
        }
        "AFPercent_Format" | "AFPercent_Keystroke" => {
            if let (Some(decimals), Some(separators)) =
                (number(0).and_then(whole), number(1).and_then(whole))
            {
                declared.format = Some(DeclaredFormat::Percent {
                    decimals,
                    separators,
                });
            }
        }
        "AFRange_Validate" => {
            if let (
                Some(Argument::Boolean(has_min)),
                Some(Argument::Number(min)),
                Some(Argument::Boolean(has_max)),
                Some(Argument::Number(max)),
            ) = (
                arguments.first(),
                arguments.get(1),
                arguments.get(2),
                arguments.get(3),
            ) {
                declared.min = has_min.then_some(*min);
                declared.max = has_max.then_some(*max);
            }
        }
        _ => {}
    }
    declared
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::dictionary;

    use super::*;
    use crate::{OpenOptions, Source, open};

    fn document(build: impl FnOnce(&mut lopdf::Document, ObjectId) -> Object) -> Document {
        let mut pdf = lopdf::Document::with_version("1.7");
        let pages = pdf.new_object_id();
        let page = pdf.add_object(dictionary! {
            "Type" => "Page", "Parent" => pages, "MediaBox" => vec![0.into(), 0.into(), 200.into(), 200.into()],
        });
        pdf.objects.insert(
            pages,
            Object::Dictionary(dictionary! {
                "Type" => "Pages", "Count" => 1, "Kids" => vec![page.into()],
            }),
        );
        let form = build(&mut pdf, page);
        let catalog = pdf.add_object(dictionary! {
            "Type" => "Catalog", "Pages" => pages, "AcroForm" => form,
        });
        pdf.trailer.set("Root", catalog);
        let mut bytes = Vec::new();
        pdf.save_to(&mut bytes).unwrap();
        open(
            &Source::from_bytes(Arc::from(bytes.as_slice())),
            &OpenOptions::default(),
        )
        .unwrap()
    }

    fn widget(page: ObjectId, extra: Dictionary) -> Dictionary {
        let mut dict = dictionary! {
            "Type" => "Annot", "Subtype" => "Widget", "P" => page,
            "Rect" => vec![10.into(), 10.into(), 50.into(), 30.into()], "F" => 4,
        };
        for (key, value) in extra {
            dict.set(key, value);
        }
        dict
    }

    fn annots(pdf: &mut lopdf::Document, page: ObjectId, ids: Vec<ObjectId>) {
        let mut dict = pdf.get_dictionary(page).unwrap().clone();
        dict.set(
            "Annots",
            ids.into_iter().map(Object::from).collect::<Vec<_>>(),
        );
        pdf.objects.insert(page, Object::Dictionary(dict));
    }

    #[test]
    fn a_cycle_in_the_tree_stops_and_reads_once() {
        let doc = document(|pdf, page| {
            let child = pdf.new_object_id();
            let parent = pdf.add_object(dictionary! {
                "T" => Object::string_literal("a"), "FT" => "Tx", "Kids" => vec![child.into()],
            });
            let mut kid = widget(
                page,
                dictionary! { "T" => Object::string_literal("b"), "Parent" => parent },
            );
            // A kid naming its parent again, and itself.
            kid.set("Kids", vec![parent.into(), child.into()]);
            pdf.objects.insert(child, Object::Dictionary(kid));
            annots(pdf, page, vec![child]);
            Object::Dictionary(dictionary! { "Fields" => vec![parent.into(), parent.into()] })
        });
        let list = RevisionStore::new(&doc).form_fields(&doc);
        assert_eq!(list.fields.len(), 1);
        assert_eq!(list.fields[0].name, "a.b");
    }

    #[test]
    fn a_deep_tree_stops_at_the_limit_and_says_so() {
        let doc = document(|pdf, page| {
            let leaf = pdf.add_object(widget(
                page,
                dictionary! { "T" => Object::string_literal("x"), "FT" => "Tx" },
            ));
            annots(pdf, page, vec![leaf]);
            let mut top = leaf;
            for _ in 0..1000 {
                top = pdf.add_object(dictionary! {
                    "T" => Object::string_literal("n"), "Kids" => vec![top.into()],
                });
            }
            Object::Dictionary(dictionary! { "Fields" => vec![top.into()] })
        });
        let list = RevisionStore::new(&doc).form_fields(&doc);
        assert!(list.truncated);
        assert!(list.fields.is_empty());
    }

    #[test]
    fn a_huge_tree_stops_at_the_limit_and_says_so() {
        let doc = document(|pdf, _page| {
            let kids: Vec<Object> = (0..MAX_NODES + 10)
                .map(|n| {
                    Object::from(pdf.add_object(dictionary! {
                        "T" => Object::string_literal(n.to_string()), "FT" => "Tx",
                    }))
                })
                .collect();
            Object::Dictionary(dictionary! { "Fields" => kids })
        });
        let list = RevisionStore::new(&doc).form_fields(&doc);
        assert!(list.truncated);
    }

    #[test]
    fn same_names_are_one_field_and_tabs_order_the_list() {
        let doc = document(|pdf, page| {
            let low = pdf.add_object(widget(
                page,
                dictionary! { "T" => Object::string_literal("low"), "FT" => "Tx",
                "Rect" => vec![10.into(), 10.into(), 50.into(), 30.into()] },
            ));
            let high = pdf.add_object(widget(
                page,
                dictionary! { "T" => Object::string_literal("same"), "FT" => "Tx",
                "Rect" => vec![10.into(), 150.into(), 50.into(), 170.into()] },
            ));
            let again = pdf.add_object(widget(
                page,
                dictionary! { "T" => Object::string_literal("same"), "FT" => "Tx",
                "Rect" => vec![60.into(), 150.into(), 90.into(), 170.into()] },
            ));
            annots(pdf, page, vec![low, again, high]);
            let mut dict = pdf.get_dictionary(page).unwrap().clone();
            dict.set("Tabs", "R");
            pdf.objects.insert(page, Object::Dictionary(dict));
            Object::Dictionary(
                dictionary! { "Fields" => vec![low.into(), high.into(), again.into()] },
            )
        });
        let list = RevisionStore::new(&doc).form_fields(&doc);
        let names: Vec<&str> = list.fields.iter().map(|f| f.name.as_str()).collect();
        assert_eq!(names, ["same", "low"]);
        assert_eq!(list.fields[0].widgets.len(), 2);
        assert_eq!(list.fields[0].nodes.len(), 2);
        assert!(list.fields[0].widgets[0].rect[0] < list.fields[0].widgets[1].rect[0]);
    }

    #[test]
    fn a_stamp_with_the_key_fills_a_signature_field() {
        let doc = document(|pdf, page| {
            let field = pdf.add_object(widget(
                page,
                dictionary! { "T" => Object::string_literal("imza"), "FT" => "Sig", "Ff" => 2 },
            ));
            let stamp = pdf.add_object(dictionary! {
                "Type" => "Annot", "Subtype" => "Stamp",
                "Rect" => vec![10.into(), 10.into(), 50.into(), 30.into()],
                "FermanSignedField" => Object::string_literal("imza"),
            });
            annots(pdf, page, vec![field, stamp]);
            Object::Dictionary(dictionary! { "Fields" => vec![field.into()] })
        });
        let list = RevisionStore::new(&doc).form_fields(&doc);
        let field = &list.fields[0];
        assert!(field.required && field.filled() && !field.signed);
        assert!(field.signature.is_some());
    }

    #[test]
    fn a_free_font_prefix_reads_the_keys_once() {
        const MANY: usize = 50_000;
        let doc = document(|_, _| {
            let mut fonts = Dictionary::new();
            for n in 0..MANY {
                fonts.set(format!("Fm{n}F0"), Object::Null);
            }
            fonts.set("Fm0100000F0", Object::Null);
            Object::Dictionary(
                dictionary! { "Fields" => vec![], "DR" => dictionary! { "Font" => fonts } },
            )
        });
        let store = RevisionStore::new(&doc);
        let started = std::time::Instant::now();
        assert_eq!(store.free_form_font_prefix(&doc), format!("Fm{MANY}F"));
        // Reading every key for every number tried took minutes here.
        assert!(started.elapsed() < std::time::Duration::from_secs(2));
    }

    #[test]
    fn a_field_with_a_widget_on_no_page_leaves_its_root_unread() {
        let doc = document(|pdf, page| {
            let shown = pdf.add_object(widget(
                page,
                dictionary! { "T" => Object::string_literal("a"), "FT" => "Tx" },
            ));
            // An invisible signature: its widget has only /P.
            let hidden = pdf.add_object(widget(
                page,
                dictionary! { "T" => Object::string_literal("s"), "FT" => "Sig", "V" => dictionary! {} },
            ));
            annots(pdf, page, vec![shown]);
            Object::Dictionary(dictionary! { "Fields" => vec![shown.into(), hidden.into()] })
        });
        let store = RevisionStore::new(&doc);
        let list = store.form_fields(&doc);
        assert_eq!(list.fields.len(), 1);
        let roots = store.form_roots(&doc);
        assert_eq!(roots.len(), 2);
        assert_eq!(list.partial_roots, [roots[1]]);
    }

    #[test]
    fn literal_arguments_are_read_and_nothing_else_is() {
        assert_eq!(
            read_script("AFDate_FormatEx(\"dd.mm.yyyy\");").format,
            Some(DeclaredFormat::Date("dd.mm.yyyy".to_owned()))
        );
        assert_eq!(
            read_script("AFDate_Format(2)").format,
            Some(DeclaredFormat::Date("mm/dd/yy".to_owned()))
        );
        assert_eq!(
            read_script(" AFNumber_Keystroke(0, 2, 0, 0, \"\", true); ").format,
            Some(DeclaredFormat::Number {
                decimals: 0,
                separators: 2
            })
        );
        assert_eq!(
            read_script("AFPercent_Format(1, 0)").format,
            Some(DeclaredFormat::Percent {
                decimals: 1,
                separators: 0
            })
        );
        let range = read_script("AFRange_Validate(true, 1, false, 20);");
        assert_eq!((range.min, range.max), (Some(1.0), None));
        for refused in [
            "AFRange_Validate(true, 1, true, 20); app.alert(1);",
            "AFNumber_Format(1e400, 0)",
            "AFRange_Validate(true, x, true, 20)",
            "AFSimple_Calculate(\"SUM\", new Array (\"a\", \"b\"));",
            "if (true) AFRange_Validate(true, 1, true, 2);",
            "AFDate_Format(99)",
            "AFDate_FormatEx(\"unterminated",
            "",
            "(",
        ] {
            assert_eq!(read_script(refused), Declared::default(), "{refused}");
        }
    }

    #[test]
    fn a_change_that_changes_nothing_is_not_written() {
        let doc = document(|pdf, page| {
            let field = pdf.add_object(widget(
                page,
                dictionary! { "T" => Object::string_literal("a"), "FT" => "Tx" },
            ));
            annots(pdf, page, vec![field]);
            Object::Dictionary(dictionary! { "Fields" => vec![field.into()] })
        });
        let mut store = RevisionStore::new(&doc);
        let object = store.form_fields(&doc).fields[0].nodes[0];
        store.begin().unwrap();
        store
            .change_entries(&doc, object, vec![(b"V".to_vec(), None)])
            .unwrap();
        assert_eq!(store.commit().unwrap(), 0);
    }
}
