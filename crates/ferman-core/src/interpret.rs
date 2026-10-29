//! Text in content streams (ISO 32000-2 §8.4, §9.3, §9.4 and §8.10): the interpreter walks a
//! page's content and its form XObjects, keeps the graphics and text state that place text, and
//! hands each show operator to a [`TextSink`] with the fonts it uses as plain data, so no lopdf
//! type leaves ferman-core (docs/ARCHITECTURE.md §6.1).
//!
//! ferman-text implements the sink: it knows the fonts' widths, so it returns each show's
//! displacement, and the interpreter moves the text matrix by it. In M2 the interpreter keeps what
//! extraction needs: `q` and `Q`, `cm`, the text state, the positioning and showing operators, and
//! `Do` for forms, with cycle detection and the recursion limit. Clipping, colour, marked content
//! (with `/ActualText`) and Type3 glyph procedures arrive with editing (M3).
// The interpreter reads values from files (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet};
use std::ops::Range;

use lopdf::{Dictionary, Object, ObjectId};

use crate::content::{self, Operator};
use crate::filters;
use crate::limits::LimitKind;
use crate::structure::{FontKind, Scope, inherited, number};
use crate::{CoreError, Document};

/// A PDF matrix `[a b c d e f]`, applied to row vectors.
pub type Matrix = [f32; 6];

/// The identity matrix.
pub const IDENTITY: Matrix = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

/// `a` then `b`: the matrix that applies `a` first.
#[must_use]
pub fn multiply(a: Matrix, b: Matrix) -> Matrix {
    let [a0, a1, a2, a3, a4, a5] = a;
    let [b0, b1, b2, b3, b4, b5] = b;
    [
        a0 * b0 + a1 * b2,
        a0 * b1 + a1 * b3,
        a2 * b0 + a3 * b2,
        a2 * b1 + a3 * b3,
        a4 * b0 + a5 * b2 + b4,
        a4 * b1 + a5 * b3 + b5,
    ]
}

/// A font as its dictionary describes it, for ferman-text to build its widths and its text from.
#[derive(Debug, Clone, PartialEq)]
pub struct FontResource {
    /// The same for every use of one font dictionary in a document.
    pub key: u64,
    /// Its type.
    pub kind: FontKind,
    /// `/BaseFont`.
    pub base_font: Option<String>,
    /// A simple font's base encoding: `/Encoding`'s name, or its dictionary's `/BaseEncoding`.
    pub base_encoding: Option<Vec<u8>>,
    /// A simple font's `/Differences`: codes and their glyph names.
    pub differences: Vec<(u8, String)>,
    /// `/FirstChar`.
    pub first_char: u32,
    /// `/Widths`, from `/FirstChar`.
    pub widths: Vec<f32>,
    /// The descriptor's `/MissingWidth`.
    pub missing_width: f32,
    /// Whether the descriptor's `/Flags` say symbolic.
    pub symbolic: bool,
    /// Type3's `/FontMatrix`; glyph space is 1/1000 of text space otherwise.
    pub font_matrix: Matrix,
    /// `/ToUnicode`, decoded.
    pub to_unicode: Option<Vec<u8>>,
    /// A composite font's predefined CMap, such as `Identity-H`.
    pub cmap_name: Option<Vec<u8>>,
    /// A composite font's embedded CMap, decoded.
    pub cmap: Option<Vec<u8>>,
    /// The CID font's `/W`: first and last CID, and their width.
    pub cid_widths: Vec<(u32, u32, f32)>,
    /// `/DW`, 1000 without one.
    pub default_width: f32,
    /// `/W2`: first and last CID, and their vertical displacement and position vector.
    pub vertical_metrics: Vec<(u32, u32, [f32; 3])>,
    /// `/DW2`: the default position vector's y and vertical displacement, `[880 -1000]` without
    /// one.
    pub default_vertical: [f32; 2],
}

/// One item of a show operator.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ShowItem<'a> {
    /// A string of codes.
    Text(&'a [u8]),
    /// A `TJ` number: thousandths of text space against the writing direction.
    Adjust(f32),
}

/// One `Tj`, `TJ`, `'` or `"` and the state it draws with.
#[derive(Debug, Clone, PartialEq)]
pub struct TextShow<'a> {
    /// The font's [`FontResource::key`].
    pub font: u64,
    /// `Tf`'s size.
    pub size: f32,
    /// `Tc`.
    pub char_spacing: f32,
    /// `Tw`, which applies to the single-byte code 32 only.
    pub word_spacing: f32,
    /// `Tz`, as a factor.
    pub horizontal_scaling: f32,
    /// `Ts`.
    pub rise: f32,
    /// `Tr`; 3 is invisible text, such as an OCR layer.
    pub render_mode: u8,
    /// The text matrix times the current transformation matrix: text space to page space.
    pub matrix: Matrix,
    /// Its strings and adjustments.
    pub items: &'a [ShowItem<'a>],
    /// Where the operator is, in the content it came from.
    pub span: Range<usize>,
}

/// Receives a page's text from the interpreter.
pub trait TextSink {
    /// A font, before the first show that uses it.
    fn font(&mut self, font: &FontResource);

    /// A show; returns how far it moves the text matrix, in text space: `(tx, 0)` for horizontal
    /// writing, `(0, ty)` for vertical.
    fn show(&mut self, show: &TextShow<'_>) -> (f32, f32);
}

impl Document {
    /// Interprets page `index` and the forms it draws, and hands its text to `sink`.
    ///
    /// # Errors
    ///
    /// [`CoreError::ResourceLimit`] past the operators per page, the form recursion or another
    /// of the document's [`Limits`](crate::limits::Limits); a content stream that cannot be
    /// decoded is skipped.
    pub fn page_text(&self, index: usize, sink: &mut dyn TextSink) -> Result<(), CoreError> {
        let Some(page) = self.structure().pages.get(index) else {
            return Ok(());
        };
        let limits = self.limits();
        let scope = Scope {
            doc: self.model(),
            limits,
            page_of: BTreeMap::new(),
            annotation_page: BTreeMap::new(),
        };
        let Ok(dict) = scope.doc.get_dictionary(page.id) else {
            return Ok(());
        };
        let resources =
            inherited(&scope, dict, b"Resources").and_then(|value| value.as_dict().ok());
        let mut content = Vec::new();
        let streams: Vec<&Object> = match scope.get(dict, b"Contents") {
            Some(Object::Array(items)) => items.iter().collect(),
            Some(_) => dict.get(b"Contents").into_iter().collect(),
            None => Vec::new(),
        };
        for stream in streams {
            if let Some(data) = decoded(&scope, stream) {
                // Streams of an array join as one, with white space between (§7.8.2).
                content.extend(data);
                content.push(b'\n');
            }
        }
        let mut walk = Walk {
            scope: &scope,
            sink,
            announced: BTreeSet::new(),
            forms: Vec::new(),
            operators: 0,
        };
        walk.run(&content, resources, State::default())
    }
}

/// A stream's decoded bytes, or `None` when it cannot be decoded.
fn decoded(scope: &Scope<'_>, object: &Object) -> Option<Vec<u8>> {
    let Object::Stream(stream) = scope.resolve(object)? else {
        return None;
    };
    let steps = filters::chain_of(&stream.dict).ok()?;
    filters::decode_chain(&steps, &stream.content, scope.limits).ok()
}

/// The graphics state's part that places text.
#[derive(Debug, Clone, Copy, PartialEq)]
struct State {
    ctm: Matrix,
    font: Option<u64>,
    size: f32,
    char_spacing: f32,
    word_spacing: f32,
    horizontal_scaling: f32,
    leading: f32,
    rise: f32,
    render_mode: u8,
}

impl Default for State {
    fn default() -> Self {
        Self {
            ctm: IDENTITY,
            font: None,
            size: 0.0,
            char_spacing: 0.0,
            word_spacing: 0.0,
            horizontal_scaling: 1.0,
            leading: 0.0,
            rise: 0.0,
            render_mode: 0,
        }
    }
}

/// One page's interpretation.
struct Walk<'a, 's> {
    scope: &'a Scope<'a>,
    sink: &'s mut dyn TextSink,
    announced: BTreeSet<u64>,
    /// The forms being drawn, outermost first.
    forms: Vec<ObjectId>,
    operators: u64,
}

impl<'a> Walk<'a, '_> {
    fn run(
        &mut self,
        content: &[u8],
        resources: Option<&'a Dictionary>,
        mut state: State,
    ) -> Result<(), CoreError> {
        let limits = self.scope.limits;
        let operators = content::operators(content, limits)?;
        let mut saved: Vec<State> = Vec::new();
        let (mut tm, mut tlm) = (IDENTITY, IDENTITY);
        for op in &operators {
            self.operators = self.operators.saturating_add(1);
            if self.operators > limits.max_operators_per_page {
                return Err(CoreError::ResourceLimit {
                    limit: LimitKind::OperatorsPerPage,
                    max: limits.max_operators_per_page,
                });
            }
            let n = |at: usize| op.operands.get(at).and_then(number);
            match op.name.as_slice() {
                b"q" => {
                    if u32::try_from(saved.len()).is_ok_and(|depth| depth < limits.max_q_nesting) {
                        saved.push(state);
                    }
                }
                b"Q" => {
                    if let Some(previous) = saved.pop() {
                        state = previous;
                    }
                }
                b"cm" => {
                    if let Some(m) = matrix(&op.operands) {
                        state.ctm = multiply(m, state.ctm);
                    }
                }
                b"BT" => (tm, tlm) = (IDENTITY, IDENTITY),
                b"Tc" => state.char_spacing = n(0).unwrap_or(state.char_spacing),
                b"Tw" => state.word_spacing = n(0).unwrap_or(state.word_spacing),
                b"Tz" => {
                    state.horizontal_scaling = n(0).map_or(state.horizontal_scaling, |z| z / 100.0);
                }
                b"TL" => state.leading = n(0).unwrap_or(state.leading),
                b"Ts" => state.rise = n(0).unwrap_or(state.rise),
                b"Tr" => {
                    state.render_mode = n(0)
                        .and_then(cid)
                        .and_then(|mode| u8::try_from(mode).ok())
                        .unwrap_or(state.render_mode);
                }
                b"Tf" => {
                    let name = op.operands.first().and_then(|name| name.as_name().ok());
                    state.font = name.and_then(|name| self.font(resources, name));
                    state.size = n(1).unwrap_or(state.size);
                }
                b"Td" | b"TD" => {
                    if let (Some(tx), Some(ty)) = (n(0), n(1)) {
                        if op.name == b"TD" {
                            state.leading = -ty;
                        }
                        tlm = multiply([1.0, 0.0, 0.0, 1.0, tx, ty], tlm);
                        tm = tlm;
                    }
                }
                b"Tm" => {
                    if let Some(m) = matrix(&op.operands) {
                        (tm, tlm) = (m, m);
                    }
                }
                b"T*" => {
                    tlm = multiply([1.0, 0.0, 0.0, 1.0, 0.0, -state.leading], tlm);
                    tm = tlm;
                }
                b"Tj" | b"'" | b"\"" => {
                    if op.name != b"Tj" {
                        if op.name == b"\"" {
                            state.word_spacing = n(0).unwrap_or(state.word_spacing);
                            state.char_spacing = n(1).unwrap_or(state.char_spacing);
                        }
                        tlm = multiply([1.0, 0.0, 0.0, 1.0, 0.0, -state.leading], tlm);
                        tm = tlm;
                    }
                    if let Some(Ok(text)) = op.operands.last().map(Object::as_str) {
                        tm = self.show(op, &state, tm, &[ShowItem::Text(text)]);
                    }
                }
                b"TJ" => {
                    if let Some(Ok(array)) = op.operands.first().map(Object::as_array) {
                        let items: Vec<ShowItem<'_>> = array
                            .iter()
                            .filter_map(|item| match item {
                                Object::String(text, _) => Some(ShowItem::Text(text)),
                                other => number(other).map(ShowItem::Adjust),
                            })
                            .collect();
                        tm = self.show(op, &state, tm, &items);
                    }
                }
                b"Do" => {
                    if let Some(Ok(name)) = op.operands.first().map(Object::as_name) {
                        self.form(resources, name, state)?;
                    }
                }
                _ => {}
            }
        }
        Ok(())
    }

    /// Hands a show to the sink and returns the text matrix after it.
    fn show(&mut self, op: &Operator, state: &State, tm: Matrix, items: &[ShowItem<'_>]) -> Matrix {
        let Some(font) = state.font else {
            return tm;
        };
        let (tx, ty) = self.sink.show(&TextShow {
            font,
            size: state.size,
            char_spacing: state.char_spacing,
            word_spacing: state.word_spacing,
            horizontal_scaling: state.horizontal_scaling,
            rise: state.rise,
            render_mode: state.render_mode,
            matrix: multiply(tm, state.ctm),
            items,
            span: op.span.clone(),
        });
        if !(tx.is_finite() && ty.is_finite()) {
            return tm;
        }
        multiply([1.0, 0.0, 0.0, 1.0, tx, ty], tm)
    }

    /// The font `name` of `resources`, announced to the sink the first time.
    fn font(&mut self, resources: Option<&'a Dictionary>, name: &[u8]) -> Option<u64> {
        let scope = self.scope;
        let fonts = scope.get_dict(resources?, b"Font")?;
        let entry = fonts.get(name).ok()?;
        let dict = scope.dict(entry)?;
        let key = match entry {
            Object::Reference((number, generation)) => {
                (u64::from(*number) << 16) | u64::from(*generation)
            }
            // A direct font dictionary is keyed by where it is, which is stable for a model.
            _ => u64::try_from(std::ptr::from_ref(dict).addr()).unwrap_or(0) | (1 << 63),
        };
        if self.announced.insert(key) {
            self.sink.font(&font_resource(scope, dict, key));
        }
        Some(key)
    }

    /// Draws the form XObject `name` of `resources`.
    fn form(
        &mut self,
        resources: Option<&'a Dictionary>,
        name: &[u8],
        mut state: State,
    ) -> Result<(), CoreError> {
        let scope = self.scope;
        let Some(entry) = resources
            .and_then(|resources| scope.get_dict(resources, b"XObject"))
            .and_then(|xobjects| xobjects.get(name).ok())
        else {
            return Ok(());
        };
        let Ok(id) = entry.as_reference() else {
            return Ok(());
        };
        let Some(Object::Stream(stream)) = scope.resolve(entry) else {
            return Ok(());
        };
        if scope.get_name(&stream.dict, b"Subtype") != Some(b"Form") || self.forms.contains(&id) {
            return Ok(());
        }
        if u32::try_from(self.forms.len()).map_or(true, |depth| depth >= scope.limits.max_recursion)
        {
            return Err(CoreError::ResourceLimit {
                limit: LimitKind::Recursion,
                max: u64::from(scope.limits.max_recursion),
            });
        }
        let Some(content) = decoded(scope, entry) else {
            return Ok(());
        };
        if let Some(m) = scope
            .get_array(&stream.dict, b"Matrix")
            .and_then(|m| matrix(m))
        {
            state.ctm = multiply(m, state.ctm);
        }
        let own = scope.get_dict(&stream.dict, b"Resources").or(resources);
        self.forms.push(id);
        let result = self.run(&content, own, state);
        self.forms.pop();
        result
    }
}

/// Six numbers as a matrix.
fn matrix(operands: &[Object]) -> Option<Matrix> {
    let values: Vec<f32> = operands.iter().filter_map(number).collect();
    values.try_into().ok()
}

/// A font dictionary as plain data.
fn font_resource(scope: &Scope<'_>, dict: &Dictionary, key: u64) -> FontResource {
    let kind = crate::structure::fonts::kind(scope.get_name(dict, b"Subtype"));
    let numbers = |dict: &Dictionary, key: &[u8]| -> Vec<f32> {
        scope
            .get_array(dict, key)
            .map(|items| {
                items
                    .iter()
                    .filter_map(|item| scope.resolve(item).and_then(number))
                    .collect()
            })
            .unwrap_or_default()
    };
    let descendant = scope
        .get_array(dict, b"DescendantFonts")
        .and_then(|fonts| fonts.first())
        .and_then(|font| scope.dict(font));
    let descriptor = scope.get_dict(descendant.unwrap_or(dict), b"FontDescriptor");
    let flags = descriptor
        .and_then(|descriptor| scope.get_int(descriptor, b"Flags"))
        .unwrap_or(0);
    let encoding = dict
        .get(b"Encoding")
        .ok()
        .and_then(|value| scope.resolve(value));
    let (mut base_encoding, mut differences, mut cmap_name, mut cmap) =
        (None, Vec::new(), None, None);
    match encoding {
        Some(Object::Name(name)) if kind == FontKind::Type0 => cmap_name = Some(name.clone()),
        Some(Object::Name(name)) => base_encoding = Some(name.clone()),
        Some(Object::Stream(_)) => {
            cmap = dict
                .get(b"Encoding")
                .ok()
                .and_then(|value| decoded(scope, value));
        }
        Some(Object::Dictionary(encoding)) => {
            base_encoding = scope
                .get_name(encoding, b"BaseEncoding")
                .map(<[u8]>::to_vec);
            let mut code = 0_i64;
            for item in scope
                .get_array(encoding, b"Differences")
                .into_iter()
                .flatten()
            {
                match scope.resolve(item) {
                    Some(Object::Integer(at)) => code = *at,
                    Some(Object::Name(name)) => {
                        if let Ok(at) = u8::try_from(code) {
                            differences.push((at, String::from_utf8_lossy(name).into_owned()));
                        }
                        code = code.saturating_add(1);
                    }
                    _ => {}
                }
            }
        }
        _ => {}
    }
    let (cid_widths, vertical_metrics) = descendant.map_or_else(Default::default, |font| {
        (
            cid_ranges::<1>(scope, scope.get_array(font, b"W")),
            cid_ranges::<3>(scope, scope.get_array(font, b"W2")),
        )
    });
    let font_matrix = <Matrix>::try_from(numbers(dict, b"FontMatrix"))
        .unwrap_or([0.001, 0.0, 0.0, 0.001, 0.0, 0.0]);
    let default_vertical = match numbers(descendant.unwrap_or(dict), b"DW2").as_slice() {
        &[vy, w1y] => [vy, w1y],
        _ => [880.0, -1000.0],
    };
    FontResource {
        key,
        kind,
        base_font: scope
            .get_name(dict, b"BaseFont")
            .map(|name| String::from_utf8_lossy(name).into_owned()),
        base_encoding,
        differences,
        first_char: scope
            .get_int(dict, b"FirstChar")
            .and_then(|first| u32::try_from(first).ok())
            .unwrap_or(0),
        widths: numbers(dict, b"Widths"),
        missing_width: descriptor
            .and_then(|descriptor| scope.get(descriptor, b"MissingWidth"))
            .and_then(number)
            .unwrap_or(0.0),
        symbolic: flags & 4 != 0,
        font_matrix,
        to_unicode: dict
            .get(b"ToUnicode")
            .ok()
            .and_then(|value| decoded(scope, value)),
        cmap_name,
        cmap,
        cid_widths: cid_widths
            .into_iter()
            .map(|(first, last, [width])| (first, last, width))
            .collect(),
        default_width: descendant
            .and_then(|font| scope.get(font, b"DW"))
            .and_then(number)
            .unwrap_or(1000.0),
        vertical_metrics,
        default_vertical,
    }
}

/// `/W` (with `N` = 1) or `/W2` (with `N` = 3): runs `c [v…]` of consecutive CIDs and ranges
/// `first last v`.
fn cid_ranges<const N: usize>(
    scope: &Scope<'_>,
    array: Option<&Vec<Object>>,
) -> Vec<(u32, u32, [f32; N])> {
    let mut out = Vec::new();
    let items: Vec<&Object> = array
        .into_iter()
        .flatten()
        .filter_map(|item| scope.resolve(item))
        .collect();
    let mut at = 0_usize;
    while let Some(&first) = items.get(at) {
        let Some(first) = number(first).and_then(cid) else {
            break;
        };
        match items.get(at.saturating_add(1)) {
            Some(Object::Array(values)) => {
                let values: Vec<f32> = values
                    .iter()
                    .filter_map(|value| scope.resolve(value).and_then(number))
                    .collect();
                for (offset, group) in (0_u32..).zip(values.as_chunks::<N>().0) {
                    if let Some(code) = first.checked_add(offset) {
                        out.push((code, code, *group));
                    }
                }
                at = at.saturating_add(2);
            }
            Some(last) => {
                let Some(last) = number(last).and_then(cid) else {
                    break;
                };
                let values: Option<Vec<f32>> = (0..N)
                    .map(|i| {
                        items
                            .get(at.saturating_add(2).saturating_add(i))
                            .copied()
                            .and_then(number)
                    })
                    .collect();
                if let Some(Ok(values)) = values.map(<[f32; N]>::try_from) {
                    out.push((first, last.max(first), values));
                }
                at = at.saturating_add(2).saturating_add(N);
            }
            None => break,
        }
    }
    out
}

/// A whole, non-negative number below 2^24 (which an `f32` holds exactly), such as a CID.
fn cid(value: f32) -> Option<u32> {
    // Whole values below 2^24 convert exactly.
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    ((0.0..16_777_216.0).contains(&value) && value.fract() == 0.0).then_some(value as u32)
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::{Stream, dictionary};

    use super::*;
    use crate::limits::Limits;
    use crate::{OpenOptions, Source, open};

    /// Records the fonts and shows; every code is 500 units wide.
    #[derive(Default)]
    struct Recorder {
        fonts: Vec<FontResource>,
        shows: Vec<(String, Matrix, f32)>,
    }

    impl TextSink for Recorder {
        fn font(&mut self, font: &FontResource) {
            self.fonts.push(font.clone());
        }

        fn show(&mut self, show: &TextShow<'_>) -> (f32, f32) {
            let mut text = String::new();
            let mut advance = 0.0;
            for item in show.items {
                match item {
                    ShowItem::Text(bytes) => {
                        text.push_str(&String::from_utf8_lossy(bytes));
                        advance += bytes.len() as f32 * 0.5 * show.size;
                    }
                    ShowItem::Adjust(n) => advance -= n / 1000.0 * show.size,
                }
            }
            self.shows.push((text, show.matrix, show.word_spacing));
            (advance, 0.0)
        }
    }

    fn document(content: &[u8], form: &[u8]) -> Document {
        let mut doc = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let to_unicode = doc.add_object(Stream::new(
            dictionary! {},
            b"beginbfchar <41> <0041> endbfchar".to_vec(),
        ));
        let font = doc.add_object(dictionary! {
            "Type" => "Font", "Subtype" => "TrueType", "BaseFont" => "Plex",
            "FirstChar" => 32, "Widths" => vec![250.into(), 600.into()],
            "Encoding" => dictionary! {
                "BaseEncoding" => "WinAnsiEncoding",
                "Differences" => vec![0xD0.into(), "Gbreve".into(), "Idotaccent".into()],
            },
            "ToUnicode" => to_unicode,
        });
        let form_id = doc.new_object_id();
        let resources = dictionary! {
            "Font" => dictionary! { "F1" => font },
            "XObject" => dictionary! { "X1" => form_id },
        };
        doc.objects.insert(
            form_id,
            Object::Stream(Stream::new(
                dictionary! {
                    "Type" => "XObject", "Subtype" => "Form",
                    "Matrix" => vec![2.into(), 0.into(), 0.into(), 2.into(), 10.into(), 20.into()],
                    "Resources" => resources.clone(),
                },
                form.to_vec(),
            )),
        );
        let page = doc.page_iter().next().unwrap();
        let contents = doc.add_object(Stream::new(dictionary! {}, content.to_vec()));
        let page = doc.get_dictionary_mut(page).unwrap();
        page.set("Resources", resources);
        page.set("Contents", contents);
        let mut bytes = Vec::new();
        doc.save_to(&mut bytes).unwrap();
        open(
            &Source::from_bytes(Arc::from(&bytes[..])),
            &OpenOptions::default(),
        )
        .unwrap()
    }

    fn record(content: &[u8], form: &[u8]) -> Recorder {
        let mut recorder = Recorder::default();
        document(content, form).page_text(0, &mut recorder).unwrap();
        recorder
    }

    #[test]
    fn shows_carry_their_matrices_and_move_the_text_matrix() {
        let recorder = record(
            b"1 0 0 1 5 5 cm BT /F1 10 Tf 12 TL 100 700 Td (Ab) Tj [(c) -500 (d)] TJ T* (e) ' 3 1 (f) \" ET",
            b"",
        );
        let shows: Vec<(&str, [f32; 2], f32)> = recorder
            .shows
            .iter()
            .map(|(text, m, tw)| (text.as_str(), [m[4], m[5]], *tw))
            .collect();
        assert_eq!(
            shows,
            [
                ("Ab", [105.0, 705.0], 0.0),
                // 2 codes × 5 points.
                ("cd", [115.0, 705.0], 0.0),
                // T* goes back to the line's start, one leading down; ' does it again.
                ("e", [105.0, 681.0], 0.0),
                ("f", [105.0, 669.0], 3.0),
            ]
        );
        assert_eq!(recorder.fonts.len(), 1, "a font is announced once");
    }

    #[test]
    fn a_font_dictionary_becomes_plain_data() {
        let font = &record(b"BT /F1 9 Tf (a) Tj ET", b"").fonts[0];
        assert_eq!(font.kind, FontKind::TrueType);
        assert_eq!(font.base_font.as_deref(), Some("Plex"));
        assert_eq!(font.base_encoding.as_deref(), Some(&b"WinAnsiEncoding"[..]));
        assert_eq!(
            font.differences,
            [(0xD0, "Gbreve".to_owned()), (0xD1, "Idotaccent".to_owned())]
        );
        assert_eq!(
            (font.first_char, font.widths.clone()),
            (32, vec![250.0, 600.0])
        );
        assert_eq!(
            font.to_unicode.as_deref(),
            Some(&b"beginbfchar <41> <0041> endbfchar"[..])
        );
        assert_eq!(font.default_width, 1000.0);
    }

    #[test]
    fn forms_draw_with_their_matrix_and_a_cycle_stops() {
        // The form draws itself again; the second time is skipped.
        let recorder = record(
            b"q 1 0 0 1 100 0 cm /X1 Do Q",
            b"BT /F1 10 Tf 1 2 Td (in) Tj ET /X1 Do",
        );
        assert_eq!(recorder.shows.len(), 1);
        let (text, m, _) = &recorder.shows[0];
        assert_eq!(text, "in");
        // Form matrix [2 0 0 2 10 20], then the page's translation by 100.
        assert_eq!(*m, [2.0, 0.0, 0.0, 2.0, 112.0, 24.0]);
    }

    #[test]
    fn the_operator_limit_covers_forms() {
        let mut doc = document(b"/X1 Do /X1 Do", b"q Q q Q");
        doc.limits = Limits {
            max_operators_per_page: 4,
            ..Limits::default()
        };
        assert!(matches!(
            doc.page_text(0, &mut Recorder::default()),
            Err(CoreError::ResourceLimit {
                limit: LimitKind::OperatorsPerPage,
                ..
            })
        ));
    }

    #[test]
    fn matrices_compose_in_pdf_order() {
        let scale = [2.0, 0.0, 0.0, 2.0, 0.0, 0.0];
        let shift = [1.0, 0.0, 0.0, 1.0, 5.0, 7.0];
        assert_eq!(multiply(scale, shift), [2.0, 0.0, 0.0, 2.0, 5.0, 7.0]);
        assert_eq!(multiply(shift, scale), [2.0, 0.0, 0.0, 2.0, 10.0, 14.0]);
    }
}
