//! Content streams (ISO 32000-2 §8.4 to §8.11, §9.3, §9.4, §9.6.4 and §14.6): the interpreter
//! walks a page's content and its form XObjects, keeps the graphics and text state, and hands
//! each show operator, and then every operator, to a [`TextSink`] with the fonts it uses as plain
//! data, so no lopdf type leaves ferman-core (docs/ARCHITECTURE.md §6.1).
//!
//! ferman-text implements the sink: it knows the fonts' widths, so it returns each show's
//! displacement, and the interpreter moves the text matrix by it. The interpreter keeps `q` and
//! `Q`, `cm`, clipping (`W`, `W*`), colour, `gs` (its `/Font`), the text state, the positioning
//! and showing operators, marked content (`BMC`, `BDC`, `EMC`) and `Do` for forms, with cycle
//! detection and the recursion limit. Every operator has a [`Span`]: the stream of the page's
//! `/Contents` or the form it is in, and its bytes in that stream's decoded data. Type3 fonts come
//! with their glyph procedures' names and `d0` or `d1` metrics; the procedures are not drawn.
// The interpreter reads values from files (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet};
use std::ops::Range;

use lopdf::{Dictionary, Object, ObjectId};

use crate::content::{self, Operator};
use crate::filters;
use crate::limits::{LimitKind, Limits};
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
    /// A Type1 font's embedded program (`/FontFile`), decoded up to
    /// [`Limits::max_font_program`](crate::limits::Limits::max_font_program), when its encoding
    /// names no base encoding: the program's built-in encoding is the base then (ISO 32000-2
    /// §9.6.5).
    pub font_program: Option<Vec<u8>>,
    /// A composite font's predefined CMap, such as `Identity-H`.
    pub cmap_name: Option<Vec<u8>>,
    /// A composite font's embedded CMap, decoded.
    pub cmap: Option<Vec<u8>>,
    /// The CMaps the embedded one uses through `/UseCMap` streams, decoded, nearest first: each
    /// adds its mappings under the ones before it. At most [`Limits::max_usecmap_depth`].
    ///
    /// [`Limits::max_usecmap_depth`]: crate::limits::Limits::max_usecmap_depth
    pub cmap_parents: Vec<Vec<u8>>,
    /// The CID font's `/W`: first and last CID, and their width.
    pub cid_widths: Vec<(u32, u32, f32)>,
    /// `/DW`, 1000 without one.
    pub default_width: f32,
    /// `/W2`: first and last CID, and their vertical displacement and position vector.
    pub vertical_metrics: Vec<(u32, u32, [f32; 3])>,
    /// `/DW2`: the default position vector's y and vertical displacement, `[880 -1000]` without
    /// one.
    pub default_vertical: [f32; 2],
    /// A Type3 font's `/CharProcs`, in the dictionary's order.
    pub char_procs: Vec<CharProc>,
}

/// PDF 1.7's limits (ISO 32000-1 Annex C): a name has at most 127 bytes and a colour at most 32
/// components (`DeviceN`). Longer ones stay out of [`GraphicsState`], which every `q` copies.
const MAX_NAME: usize = 127;
const MAX_COMPONENTS: usize = 32;
/// [`GraphicsState::ext_g_states`] holds at most this many names, for the same reason.
const MAX_EXT_G_STATES: usize = 32;

/// `name` when it is within [`MAX_NAME`].
fn short(name: &[u8]) -> Option<Vec<u8>> {
    (name.len() <= MAX_NAME).then(|| name.to_vec())
}

/// One glyph procedure of a Type3 font, read for its first operator only.
#[derive(Debug, Clone, PartialEq)]
pub struct CharProc {
    /// Its glyph name, the key in `/CharProcs`.
    pub name: String,
    /// `d0`'s or `d1`'s `wx wy`, in glyph space; `None` when the procedure starts with neither.
    pub width: Option<[f32; 2]>,
    /// `d1`'s glyph box `[llx lly urx ury]`; `None` for `d0`, a glyph with its own colour.
    pub bbox: Option<[f32; 4]>,
}

/// One item of a show operator.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ShowItem<'a> {
    /// A string of codes.
    Text(&'a [u8]),
    /// A `TJ` number: thousandths of text space against the writing direction.
    Adjust(f32),
}

/// The content an operator is in.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SpanSource {
    /// One stream of the page's `/Contents`.
    Page {
        /// The stream's object.
        stream: ObjectId,
    },
    /// A form XObject.
    Form {
        /// The form's object.
        form: ObjectId,
    },
}

/// Where an operator is: from its first operand, or the operator when it has none, to the
/// operator's end.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Span {
    /// The stream it is in.
    pub source: SpanSource,
    /// Its bytes in the source's decoded data.
    pub range: Range<usize>,
    /// Whether some of its operands are at the end of the page streams before `source`'s: the
    /// streams of a `/Contents` array split anywhere between tokens (ISO 32000-2 §7.8.2). `range`
    /// then starts at 0 and holds only the part in `source`.
    pub carried: bool,
}

/// A fill or stroke colour.
#[derive(Debug, Clone, PartialEq)]
pub struct Colour {
    /// The colour space: `DeviceGray`, `DeviceRGB` or `DeviceCMYK` after `G`, `RG` or `K` and
    /// their lower-case forms, otherwise the name `CS` or `cs` gave (a device space, `Pattern` or a
    /// `/ColorSpace` resource).
    pub space: Vec<u8>,
    /// The numbers of the last colour operator, at most 32; after `CS` or `cs` a device space's
    /// initial colour, and none for other spaces (their initial colour).
    pub components: Vec<f32>,
    /// `SCN`'s or `scn`'s pattern name.
    pub pattern: Option<Vec<u8>>,
}

impl Default for Colour {
    fn default() -> Self {
        Self {
            space: b"DeviceGray".to_vec(),
            components: vec![0.0],
            pattern: None,
        }
    }
}

/// The state an operator leaves behind: the graphics state that matters to text, the text state
/// and the text and line matrices (docs/ARCHITECTURE.md §6.6, the state invariant).
#[derive(Debug, Clone, PartialEq)]
pub struct GraphicsState {
    /// The current transformation matrix.
    pub ctm: Matrix,
    /// The text matrix; `BT` resets it, `Q` does not restore it.
    pub text_matrix: Matrix,
    /// The line matrix, which `Td`, `TD` and `T*` move from.
    pub line_matrix: Matrix,
    /// The font's [`FontResource::key`].
    pub font: Option<u64>,
    /// The `/Font` resource name `Tf` gave; `None` for a font `gs` set or a name over 127 bytes.
    pub font_name: Option<Vec<u8>>,
    /// `Tf`'s size.
    pub size: f32,
    /// `Tc`.
    pub char_spacing: f32,
    /// `Tw`, which applies to the single-byte code 32 only.
    pub word_spacing: f32,
    /// `Tz`, as a factor.
    pub horizontal_scaling: f32,
    /// `TL`.
    pub leading: f32,
    /// `Ts`.
    pub rise: f32,
    /// `Tr`; 3 is invisible text, such as an OCR layer.
    pub render_mode: u8,
    /// The fill colour.
    pub fill: Colour,
    /// The stroke colour.
    pub stroke: Colour,
    /// Whether `W` or `W*` added a clip in this graphics state.
    pub clipped: bool,
    /// The `/ExtGState` names `gs` applied in this graphics state, each once, in the order last
    /// applied; at most 32, the oldest dropped first.
    pub ext_g_states: Vec<Vec<u8>>,
    /// How many `q` are open in the content the operator is in (a form starts at 0).
    pub q_depth: u32,
}

impl Default for GraphicsState {
    fn default() -> Self {
        Self {
            ctm: IDENTITY,
            text_matrix: IDENTITY,
            line_matrix: IDENTITY,
            font: None,
            font_name: None,
            size: 0.0,
            char_spacing: 0.0,
            word_spacing: 0.0,
            horizontal_scaling: 1.0,
            leading: 0.0,
            rise: 0.0,
            render_mode: 0,
            fill: Colour::default(),
            stroke: Colour::default(),
            clipped: false,
            ext_g_states: Vec::new(),
            q_depth: 0,
        }
    }
}

/// One open marked-content sequence (`BMC` or `BDC`, ISO 32000-2 §14.6).
#[derive(Debug, Clone, Default, PartialEq)]
pub struct MarkedContent {
    /// Its tag, such as `Span`, `P`, `Artifact` or `OC`.
    pub tag: Vec<u8>,
    /// `/MCID`.
    pub mcid: Option<i64>,
    /// `/ActualText`, the text the content stands for.
    pub actual_text: Option<String>,
    /// `/Lang`.
    pub lang: Option<String>,
    /// For the tag `OC`: the optional content group or membership dictionary its `/Properties`
    /// resource names.
    pub optional_content: Option<ObjectId>,
}

impl MarkedContent {
    /// Whether the tag is `Artifact`: page furniture such as headers and page numbers.
    #[must_use]
    pub fn is_artifact(&self) -> bool {
        self.tag == b"Artifact"
    }
}

/// One `Tj`, `TJ`, `'` or `"` and the state it draws with.
#[derive(Debug, Clone, PartialEq)]
pub struct TextShow<'a> {
    /// The font's [`FontResource::key`].
    pub font: u64,
    /// The text matrix times the current transformation matrix: text space to page space.
    pub matrix: Matrix,
    /// Its strings and adjustments.
    pub items: &'a [ShowItem<'a>],
    /// Where the operator is.
    pub span: Span,
    /// The state it draws with: before the show moves the text matrix, after `'` or `"` moved to
    /// the next line.
    pub state: &'a GraphicsState,
    /// The marked content it is in, outermost first.
    pub marked: &'a [MarkedContent],
}

/// One operator, after it took effect.
#[derive(Debug, Clone, PartialEq)]
pub struct OperatorEvent<'a> {
    /// The operator, such as `Tf`; an inline image is `BI`.
    pub name: &'a [u8],
    /// Where it is.
    pub span: &'a Span,
    /// The state after it.
    pub state: &'a GraphicsState,
    /// The marked content open after it, outermost first.
    pub marked: &'a [MarkedContent],
}

/// Receives a page's content from the interpreter.
pub trait TextSink {
    /// A font, before the first show that uses it.
    fn font(&mut self, font: &FontResource);

    /// A show; returns how far it moves the text matrix, in text space: `(tx, 0)` for horizontal
    /// writing, `(0, ty)` for vertical.
    fn show(&mut self, show: &TextShow<'_>) -> (f32, f32);

    /// Every operator in content order, shows included (after [`show`](Self::show)), and `Do`
    /// after the form's own operators. Nothing by default.
    fn operator(&mut self, _operator: &OperatorEvent<'_>) {}
}

impl Document {
    /// Interprets page `index` and the forms it draws, and hands its text to `sink`.
    ///
    /// # Errors
    ///
    /// [`CoreError::ResourceLimit`] past the operators per page, the form recursion, the `q`
    /// or marked-content nesting, the `usecmap` depth, the decoded size per revision (counted over what this
    /// interpretation holds at once: the page's content, the forms being drawn and the fonts'
    /// CMaps) or another of the document's [`Limits`](crate::limits::Limits); a content stream
    /// that cannot be decoded is skipped.
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
        let mut used = 0;
        let streams: Vec<&Object> = match scope.get(dict, b"Contents") {
            Some(Object::Array(items)) => items.iter().collect(),
            Some(_) => dict.get(b"Contents").into_iter().collect(),
            None => Vec::new(),
        };
        for stream in streams {
            // A stream is always an indirect object.
            let Ok(id) = stream.as_reference() else {
                continue;
            };
            if let Some(data) = decoded(&scope, &mut used, stream)? {
                content.push((SpanSource::Page { stream: id }, data));
            }
        }
        let mut walk = Walk {
            scope: &scope,
            sink,
            announced: BTreeSet::new(),
            forms: Vec::new(),
            marked: Vec::new(),
            operators: 0,
            decoded: used,
        };
        walk.run(&content, resources, GraphicsState::default())
    }
}

/// A stream's decoded bytes, or `None` when it cannot be decoded; their size is added to `used`.
///
/// # Errors
///
/// [`CoreError::ResourceLimit`] when `used` passes [`Limits::max_revision_decoded`].
///
/// [`Limits::max_revision_decoded`]: crate::limits::Limits::max_revision_decoded
fn decoded(
    scope: &Scope<'_>,
    used: &mut u64,
    object: &Object,
) -> Result<Option<Vec<u8>>, CoreError> {
    let Some(Object::Stream(stream)) = scope.resolve(object) else {
        return Ok(None);
    };
    let Some(data) = filters::chain_of(&stream.dict)
        .ok()
        .and_then(|steps| filters::decode_chain(&steps, &stream.content, scope.limits).ok())
    else {
        return Ok(None);
    };
    *used = used.saturating_add(u64::try_from(data.len()).unwrap_or(u64::MAX));
    if *used > scope.limits.max_revision_decoded {
        return Err(CoreError::ResourceLimit {
            limit: LimitKind::RevisionDecodedSize,
            max: scope.limits.max_revision_decoded,
        });
    }
    Ok(Some(data))
}

/// A stream's decoded bytes within `limits`, or `None` when it cannot be decoded: a font program,
/// read only for its built-in encoding, or a Type3 glyph procedure, read only for its metrics,
/// under the font program size limit.
fn decoded_within(scope: &Scope<'_>, object: &Object, limits: &Limits) -> Option<Vec<u8>> {
    let Object::Stream(stream) = scope.resolve(object)? else {
        return None;
    };
    let steps = filters::chain_of(&stream.dict).ok()?;
    filters::decode_chain(&steps, &stream.content, limits).ok()
}

/// One page's interpretation.
struct Walk<'a, 's> {
    scope: &'a Scope<'a>,
    sink: &'s mut dyn TextSink,
    announced: BTreeSet<u64>,
    /// The forms being drawn, outermost first.
    forms: Vec<ObjectId>,
    /// The open marked content, outermost first.
    marked: Vec<MarkedContent>,
    operators: u64,
    /// Decoded bytes held now, for [`Limits::max_revision_decoded`].
    ///
    /// [`Limits::max_revision_decoded`]: crate::limits::Limits::max_revision_decoded
    decoded: u64,
}

impl<'a> Walk<'a, '_> {
    /// Interprets `streams` as one content stream: the state, the `q` stack and operands left at
    /// a stream's end flow into the next.
    fn run(
        &mut self,
        streams: &[(SpanSource, Vec<u8>)],
        resources: Option<&'a Dictionary>,
        mut state: GraphicsState,
    ) -> Result<(), CoreError> {
        let limits = self.scope.limits;
        let mut saved: Vec<GraphicsState> = Vec::new();
        // A form's unbalanced marked content ends with it.
        let base = self.marked.len();
        let mut carried = Vec::new();
        for (source, data) in streams {
            let (operators, left) =
                content::operators_after(data, limits, std::mem::take(&mut carried))?;
            carried = left;
            for op in &operators {
                self.operators = self.operators.saturating_add(1);
                if self.operators > limits.max_operators_per_page {
                    return Err(CoreError::ResourceLimit {
                        limit: LimitKind::OperatorsPerPage,
                        max: limits.max_operators_per_page,
                    });
                }
                let span = Span {
                    source: *source,
                    range: op.span.clone(),
                    carried: op.carried,
                };
                self.step(op, &span, resources, &mut state, &mut saved, base)?;
                self.sink.operator(&OperatorEvent {
                    name: &op.name,
                    span: &span,
                    state: &state,
                    marked: &self.marked,
                });
            }
        }
        self.marked.truncate(base);
        Ok(())
    }

    /// Applies one operator to `state`.
    fn step(
        &mut self,
        op: &Operator,
        span: &Span,
        resources: Option<&'a Dictionary>,
        state: &mut GraphicsState,
        saved: &mut Vec<GraphicsState>,
        base: usize,
    ) -> Result<(), CoreError> {
        let limits = self.scope.limits;
        let n = |at: usize| op.operands.get(at).and_then(number);
        let numbers = || -> Vec<f32> {
            op.operands
                .iter()
                .filter_map(number)
                .take(MAX_COMPONENTS)
                .collect()
        };
        match op.name.as_slice() {
            b"q" => {
                if u32::try_from(saved.len()).map_or(true, |depth| depth >= limits.max_q_nesting) {
                    return Err(CoreError::ResourceLimit {
                        limit: LimitKind::QNesting,
                        max: u64::from(limits.max_q_nesting),
                    });
                }
                saved.push(state.clone());
                state.q_depth = state.q_depth.saturating_add(1);
            }
            b"Q" => {
                if let Some(previous) = saved.pop() {
                    // The text matrices are not part of the graphics state.
                    let (tm, tlm) = (state.text_matrix, state.line_matrix);
                    *state = previous;
                    (state.text_matrix, state.line_matrix) = (tm, tlm);
                }
            }
            b"cm" => {
                if let Some(m) = matrix(&op.operands) {
                    state.ctm = multiply(m, state.ctm);
                }
            }
            b"W" | b"W*" => state.clipped = true,
            b"CS" | b"cs" => {
                if let Some(space) = op
                    .operands
                    .first()
                    .and_then(|space| space.as_name().ok())
                    .filter(|space| space.len() <= MAX_NAME)
                {
                    let components = match space {
                        b"DeviceGray" | b"G" => vec![0.0],
                        b"DeviceRGB" | b"RGB" => vec![0.0; 3],
                        b"DeviceCMYK" | b"CMYK" => vec![0.0, 0.0, 0.0, 1.0],
                        _ => Vec::new(),
                    };
                    *colour(state, op) = Colour {
                        space: space.to_vec(),
                        components,
                        pattern: None,
                    };
                }
            }
            b"SC" | b"sc" | b"SCN" | b"scn" => {
                let pattern = op
                    .operands
                    .last()
                    .and_then(|name| name.as_name().ok())
                    .and_then(short);
                let components = numbers();
                let target = colour(state, op);
                target.components = components;
                target.pattern = pattern;
            }
            b"G" | b"g" | b"RG" | b"rg" | b"K" | b"k" => {
                let space: &[u8] = match op.name.as_slice() {
                    b"G" | b"g" => b"DeviceGray",
                    b"RG" | b"rg" => b"DeviceRGB",
                    _ => b"DeviceCMYK",
                };
                let components = numbers();
                *colour(state, op) = Colour {
                    space: space.to_vec(),
                    components,
                    pattern: None,
                };
            }
            b"gs" => {
                if let Some(Ok(name)) = op.operands.first().map(Object::as_name) {
                    self.ext_g_state(resources, name, state)?;
                    if let Some(name) = short(name) {
                        let names = &mut state.ext_g_states;
                        names.retain(|applied| *applied != name);
                        if names.len() >= MAX_EXT_G_STATES {
                            names.remove(0);
                        }
                        names.push(name);
                    }
                }
            }
            b"BMC" | b"BDC" => {
                // Marked content nests no deeper than `q`.
                if u32::try_from(self.marked.len())
                    .map_or(true, |depth| depth >= limits.max_q_nesting)
                {
                    return Err(CoreError::ResourceLimit {
                        limit: LimitKind::QNesting,
                        max: u64::from(limits.max_q_nesting),
                    });
                }
                let marked = self.marked_content(resources, &op.operands);
                self.marked.push(marked);
            }
            b"EMC" => {
                if self.marked.len() > base {
                    self.marked.pop();
                }
            }
            b"BT" => (state.text_matrix, state.line_matrix) = (IDENTITY, IDENTITY),
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
                state.font = match name {
                    Some(name) => self.font(resources, name)?,
                    None => None,
                };
                state.font_name = name.and_then(short);
                state.size = n(1).unwrap_or(state.size);
            }
            b"Td" | b"TD" => {
                if let (Some(tx), Some(ty)) = (n(0), n(1)) {
                    if op.name == b"TD" {
                        state.leading = -ty;
                    }
                    state.line_matrix = multiply([1.0, 0.0, 0.0, 1.0, tx, ty], state.line_matrix);
                    state.text_matrix = state.line_matrix;
                }
            }
            b"Tm" => {
                if let Some(m) = matrix(&op.operands) {
                    (state.text_matrix, state.line_matrix) = (m, m);
                }
            }
            b"T*" => next_line(state),
            b"Tj" | b"'" | b"\"" => {
                if op.name != b"Tj" {
                    if op.name == b"\"" {
                        state.word_spacing = n(0).unwrap_or(state.word_spacing);
                        state.char_spacing = n(1).unwrap_or(state.char_spacing);
                    }
                    next_line(state);
                }
                if let Some(Ok(text)) = op.operands.last().map(Object::as_str) {
                    state.text_matrix = self.show(span, state, &[ShowItem::Text(text)]);
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
                    state.text_matrix = self.show(span, state, &items);
                }
            }
            b"Do" => {
                if let Some(Ok(name)) = op.operands.first().map(Object::as_name) {
                    self.form(resources, name, state)?;
                }
            }
            _ => {}
        }
        Ok(())
    }

    /// Hands a show to the sink and returns the text matrix after it.
    fn show(&mut self, span: &Span, state: &GraphicsState, items: &[ShowItem<'_>]) -> Matrix {
        let tm = state.text_matrix;
        let Some(font) = state.font else {
            return tm;
        };
        let (tx, ty) = self.sink.show(&TextShow {
            font,
            matrix: multiply(tm, state.ctm),
            items,
            span: span.clone(),
            state,
            marked: &self.marked,
        });
        if !(tx.is_finite() && ty.is_finite()) {
            return tm;
        }
        multiply([1.0, 0.0, 0.0, 1.0, tx, ty], tm)
    }

    /// The font `name` of `resources`, announced to the sink the first time.
    fn font(
        &mut self,
        resources: Option<&'a Dictionary>,
        name: &[u8],
    ) -> Result<Option<u64>, CoreError> {
        let scope = self.scope;
        match resources
            .and_then(|resources| scope.get_dict(resources, b"Font"))
            .and_then(|fonts| fonts.get(name).ok())
        {
            Some(entry) => self.announce(entry),
            None => Ok(None),
        }
    }

    /// The font dictionary `entry`, announced to the sink the first time.
    fn announce(&mut self, entry: &'a Object) -> Result<Option<u64>, CoreError> {
        let scope = self.scope;
        let Some(dict) = scope.dict(entry) else {
            return Ok(None);
        };
        let key = match entry {
            Object::Reference((number, generation)) => {
                (u64::from(*number) << 16) | u64::from(*generation)
            }
            // A direct font dictionary is keyed by where it is, which is stable for a model.
            _ => u64::try_from(std::ptr::from_ref(dict).addr()).unwrap_or(0) | (1 << 63),
        };
        if !self.announced.contains(&key) {
            let font = font_resource(scope, dict, key, &mut self.decoded)?;
            self.announced.insert(key);
            self.sink.font(&font);
        }
        Ok(Some(key))
    }

    /// Applies the `/ExtGState` resource `name`: of its parameters, only `/Font` places text.
    fn ext_g_state(
        &mut self,
        resources: Option<&'a Dictionary>,
        name: &[u8],
        state: &mut GraphicsState,
    ) -> Result<(), CoreError> {
        let scope = self.scope;
        let Some(font) = resources
            .and_then(|resources| scope.get_dict(resources, b"ExtGState"))
            .and_then(|states| scope.get_dict(states, name))
            .and_then(|params| scope.get_array(params, b"Font"))
        else {
            return Ok(());
        };
        if let (Some(entry), Some(size)) = (font.first(), font.get(1).and_then(number)) {
            state.font = self.announce(entry)?;
            state.font_name = None;
            state.size = size;
        }
        Ok(())
    }

    /// The marked content `BMC` or `BDC` opens with `operands`: a tag, and for `BDC` a property
    /// list, inline or named in the resources' `/Properties`.
    fn marked_content(
        &self,
        resources: Option<&'a Dictionary>,
        operands: &[Object],
    ) -> MarkedContent {
        let scope = self.scope;
        let tag = operands
            .first()
            .and_then(|tag| tag.as_name().ok())
            .unwrap_or_default()
            .to_vec();
        let entry = match operands.get(1) {
            Some(Object::Name(name)) => resources
                .and_then(|resources| scope.get_dict(resources, b"Properties"))
                .and_then(|properties| properties.get(name).ok()),
            other => other,
        };
        let properties = entry.and_then(|entry| scope.dict(entry));
        let optional_content = (tag == b"OC")
            .then(|| entry.and_then(|entry| entry.as_reference().ok()))
            .flatten();
        MarkedContent {
            mcid: properties.and_then(|p| scope.get_int(p, b"MCID")),
            actual_text: properties.and_then(|p| scope.get_text(p, b"ActualText")),
            lang: properties.and_then(|p| scope.get_text(p, b"Lang")),
            optional_content,
            tag,
        }
    }

    /// Draws the form XObject `name` of `resources`.
    fn form(
        &mut self,
        resources: Option<&'a Dictionary>,
        name: &[u8],
        state: &GraphicsState,
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
        let Some(content) = decoded(scope, &mut self.decoded, entry)? else {
            return Ok(());
        };
        let mut state = state.clone();
        if let Some(m) = scope
            .get_array(&stream.dict, b"Matrix")
            .and_then(|m| matrix(m))
        {
            state.ctm = multiply(m, state.ctm);
        }
        state.q_depth = 0;
        // A form's text starts with its own `BT`; one drawn inside a text object starts afresh.
        (state.text_matrix, state.line_matrix) = (IDENTITY, IDENTITY);
        let own = scope.get_dict(&stream.dict, b"Resources").or(resources);
        let size = u64::try_from(content.len()).unwrap_or(u64::MAX);
        self.forms.push(id);
        let result = self.run(&[(SpanSource::Form { form: id }, content)], own, state);
        self.forms.pop();
        // The form's content is dropped here, so it no longer counts.
        self.decoded = self.decoded.saturating_sub(size);
        result
    }
}

/// The colour an operator sets: upper-case operators stroke, lower-case ones fill.
fn colour<'s>(state: &'s mut GraphicsState, op: &Operator) -> &'s mut Colour {
    if op.name.first().is_some_and(u8::is_ascii_uppercase) {
        &mut state.stroke
    } else {
        &mut state.fill
    }
}

/// `T*`: the start of the next line, one leading down.
fn next_line(state: &mut GraphicsState) {
    state.line_matrix = multiply([1.0, 0.0, 0.0, 1.0, 0.0, -state.leading], state.line_matrix);
    state.text_matrix = state.line_matrix;
}

/// Six numbers as a matrix.
fn matrix(operands: &[Object]) -> Option<Matrix> {
    let values: Vec<f32> = operands.iter().filter_map(number).collect();
    values.try_into().ok()
}

/// A font dictionary as plain data; its decoded streams are added to `used`.
///
/// # Errors
///
/// [`CoreError::ResourceLimit`] past [`Limits::max_usecmap_depth`] or the decoded size per
/// revision.
///
/// [`Limits::max_usecmap_depth`]: crate::limits::Limits::max_usecmap_depth
fn font_resource(
    scope: &Scope<'_>,
    dict: &Dictionary,
    key: u64,
    used: &mut u64,
) -> Result<FontResource, CoreError> {
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
    let mut cmap_parents = Vec::new();
    match encoding {
        Some(Object::Name(name)) if kind == FontKind::Type0 => cmap_name = Some(name.clone()),
        Some(Object::Name(name)) => base_encoding = Some(name.clone()),
        Some(Object::Stream(stream)) => {
            let value = dict.get(b"Encoding").ok();
            cmap = match value {
                Some(value) => decoded(scope, used, value)?,
                None => None,
            };
            let mut seen: Vec<ObjectId> = value
                .and_then(|value| value.as_reference().ok())
                .into_iter()
                .collect();
            let mut parent = stream.dict.get(b"UseCMap").ok();
            // A `/UseCMap` name is a predefined CMap, which M2 does not bundle (extraction reads
            // it as Identity), so only embedded streams are followed.
            while let Some(next) = parent {
                let Some(Object::Stream(next_stream)) = scope.resolve(next) else {
                    break;
                };
                if let Ok(id) = next.as_reference() {
                    if seen.contains(&id) {
                        break;
                    }
                    seen.push(id);
                }
                if u32::try_from(cmap_parents.len())
                    .map_or(true, |depth| depth >= scope.limits.max_usecmap_depth)
                {
                    return Err(CoreError::ResourceLimit {
                        limit: LimitKind::UsecmapDepth,
                        max: u64::from(scope.limits.max_usecmap_depth),
                    });
                }
                let Some(data) = decoded(scope, used, next)? else {
                    break;
                };
                cmap_parents.push(data);
                parent = next_stream.dict.get(b"UseCMap").ok();
            }
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
    let program_limits = Limits {
        max_stream_decoded: scope
            .limits
            .max_stream_decoded
            .min(scope.limits.max_font_program),
        ..scope.limits.clone()
    };
    let font_program =
        if matches!(kind, FontKind::Type1 | FontKind::MultipleMaster) && base_encoding.is_none() {
            descriptor
                .and_then(|descriptor| descriptor.get(b"FontFile").ok())
                .and_then(|program| decoded_within(scope, program, &program_limits))
        } else {
            None
        };
    let char_procs = if kind == FontKind::Type3 {
        char_procs(scope, dict, &program_limits)
    } else {
        Vec::new()
    };
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
    let to_unicode = match dict.get(b"ToUnicode").ok() {
        Some(value) => decoded(scope, used, value)?,
        None => None,
    };
    Ok(FontResource {
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
        to_unicode,
        font_program,
        cmap_name,
        cmap,
        cmap_parents,
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
        char_procs,
    })
}

/// A Type3 font's glyph procedures with the metrics their `d0` or `d1` gives; each is decoded
/// within `limits`, and only its first operator is read.
fn char_procs(scope: &Scope<'_>, dict: &Dictionary, limits: &Limits) -> Vec<CharProc> {
    let Some(procs) = scope.get_dict(dict, b"CharProcs") else {
        return Vec::new();
    };
    procs
        .iter()
        .map(|(name, proc)| {
            let first = decoded_within(scope, proc, limits)
                // `d0` or `d1` comes first, so a prefix is enough.
                .and_then(|data| content::operators(data.get(..1024).unwrap_or(&data), limits).ok())
                .and_then(|ops| ops.into_iter().next());
            let values: Vec<f32> = first
                .as_ref()
                .map(|op| op.operands.iter().filter_map(number).collect())
                .unwrap_or_default();
            let (width, bbox) = match (first.as_ref().map(|op| op.name.as_slice()), &values[..]) {
                (Some(b"d0"), &[wx, wy]) => (Some([wx, wy]), None),
                (Some(b"d1"), &[wx, wy, llx, lly, urx, ury]) => {
                    (Some([wx, wy]), Some([llx, lly, urx, ury]))
                }
                _ => (None, None),
            };
            CharProc {
                name: String::from_utf8_lossy(name).into_owned(),
                width,
                bbox,
            }
        })
        .collect()
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

    /// Records the fonts, shows and operators; every code is 500 units wide.
    #[derive(Default)]
    struct Recorder {
        fonts: Vec<FontResource>,
        shows: Vec<(String, Matrix, f32)>,
        show_spans: Vec<Span>,
        ops: Vec<(String, Span, GraphicsState, Vec<MarkedContent>)>,
    }

    impl TextSink for Recorder {
        fn font(&mut self, font: &FontResource) {
            self.fonts.push(font.clone());
        }

        fn show(&mut self, show: &TextShow<'_>) -> (f32, f32) {
            let mut text = String::new();
            let mut advance = 0.0;
            let size = show.state.size;
            for item in show.items {
                match item {
                    ShowItem::Text(bytes) => {
                        text.push_str(&String::from_utf8_lossy(bytes));
                        advance += bytes.len() as f32 * 0.5 * size;
                    }
                    ShowItem::Adjust(n) => advance -= n / 1000.0 * size,
                }
            }
            self.shows
                .push((text, show.matrix, show.state.word_spacing));
            self.show_spans.push(show.span.clone());
            (advance, 0.0)
        }

        fn operator(&mut self, op: &OperatorEvent<'_>) {
            self.ops.push((
                String::from_utf8_lossy(op.name).into_owned(),
                op.span.clone(),
                op.state.clone(),
                op.marked.to_vec(),
            ));
        }
    }

    impl Recorder {
        /// The state after the last operator `name`.
        fn after(&self, name: &str) -> &GraphicsState {
            &self.ops.iter().rev().find(|op| op.0 == name).unwrap().2
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
        opened(doc, resources, content)
    }

    /// `doc` with `content` and `resources` on its first page, saved and opened.
    fn opened(mut doc: lopdf::Document, resources: Dictionary, content: &[u8]) -> Document {
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

    /// The font a page using only the font `build` adds announces.
    fn announced(build: impl FnOnce(&mut lopdf::Document) -> Dictionary) -> FontResource {
        let mut doc = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let font = build(&mut doc);
        let font = doc.add_object(font);
        let page = doc.page_iter().next().unwrap();
        let contents = doc.add_object(Stream::new(
            dictionary! {},
            b"BT /F1 9 Tf (a) Tj ET".to_vec(),
        ));
        let page = doc.get_dictionary_mut(page).unwrap();
        page.set(
            "Resources",
            dictionary! { "Font" => dictionary! { "F1" => font } },
        );
        page.set("Contents", contents);
        let mut bytes = Vec::new();
        doc.save_to(&mut bytes).unwrap();
        let doc = open(
            &Source::from_bytes(Arc::from(&bytes[..])),
            &OpenOptions::default(),
        )
        .unwrap();
        let mut recorder = Recorder::default();
        doc.page_text(0, &mut recorder).unwrap();
        recorder.fonts.remove(0)
    }

    #[test]
    fn a_type1_program_comes_along_only_without_a_base_encoding() {
        let type1 = |encoding: Option<Object>| {
            announced(|doc| {
                let program = doc.add_object(Stream::new(
                    dictionary! {},
                    b"/Encoding StandardEncoding def".to_vec(),
                ));
                let mut font = dictionary! {
                    "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Test",
                    "FontDescriptor" => dictionary! {
                        "FontFile" => program,
                    },
                };
                if let Some(encoding) = encoding {
                    font.set("Encoding", encoding);
                }
                font
            })
            .font_program
        };
        assert_eq!(
            type1(None).as_deref(),
            Some(&b"/Encoding StandardEncoding def"[..])
        );
        assert!(
            type1(Some(
                dictionary! { "Differences" => vec![65.into(), "B".into()] }.into()
            ))
            .is_some()
        );
        assert_eq!(type1(Some("WinAnsiEncoding".into())), None);
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

    fn limit_of(result: Result<(), CoreError>) -> Option<LimitKind> {
        match result {
            Err(CoreError::ResourceLimit { limit, .. }) => Some(limit),
            other => {
                other.unwrap();
                None
            }
        }
    }

    /// A page that draws a chain of `depth` distinct forms, each drawing the next.
    fn form_chain(depth: usize) -> Document {
        let mut doc = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let mut next: Option<ObjectId> = None;
        for _ in 0..depth {
            let resources = next.map_or_else(Dictionary::new, |id| {
                dictionary! { "XObject" => dictionary! { "X" => id } }
            });
            next = Some(doc.add_object(Stream::new(
                dictionary! { "Type" => "XObject", "Subtype" => "Form", "Resources" => resources },
                b"/X Do".to_vec(),
            )));
        }
        let resources = dictionary! { "XObject" => dictionary! { "X" => next.unwrap() } };
        opened(doc, resources, b"/X Do")
    }

    #[test]
    fn form_recursion_past_the_limit_is_a_resource_limit() {
        let limit = Limits::default().max_recursion as usize;
        let page = |depth| limit_of(form_chain(depth).page_text(0, &mut Recorder::default()));
        assert_eq!(page(limit), None);
        assert_eq!(page(limit + 1), Some(LimitKind::Recursion));
    }

    #[test]
    fn q_nesting_past_the_limit_is_a_resource_limit() {
        let limit = Limits::default().max_q_nesting as usize;
        let page = |depth: usize| {
            let content = format!("{} BT /F1 10 Tf (A) Tj ET", "q ".repeat(depth));
            let mut recorder = Recorder::default();
            let result = document(content.as_bytes(), b"").page_text(0, &mut recorder);
            limit_of(result)
        };
        assert_eq!(page(limit), None);
        assert_eq!(page(limit + 1), Some(LimitKind::QNesting));
        // `Q` gives the level back, so balanced pairs never reach it.
        let balanced = "q Q ".repeat(limit + 1);
        assert_eq!(
            limit_of(document(balanced.as_bytes(), b"").page_text(0, &mut Recorder::default())),
            None
        );
    }

    #[test]
    fn the_decoded_size_per_revision_counts_what_a_page_holds() {
        let form = b"BT /F1 10 Tf (A) Tj ET";
        let content = b"/X1 Do /X1 Do";
        let to_unicode = b"beginbfchar <41> <0041> endbfchar".len();
        let with = |max: usize| {
            let mut doc = document(content, form);
            doc.limits = Limits {
                max_revision_decoded: max as u64,
                ..Limits::default()
            };
            limit_of(doc.page_text(0, &mut Recorder::default()))
        };
        // The page holds its content, the form while it is drawn, and the font's ToUnicode; a
        // form's content is dropped after it, so the second `Do` adds nothing.
        let peak = content.len() + form.len() + to_unicode;
        assert_eq!(with(peak), None);
        assert_eq!(with(peak - 1), Some(LimitKind::RevisionDecodedSize));
        assert_eq!(
            with(content.len() - 1),
            Some(LimitKind::RevisionDecodedSize)
        );
    }

    /// A page with a Type0 font whose embedded CMap uses a chain of `depth` CMap streams;
    /// `cycle` makes the last one use the first again.
    fn usecmap_chain(depth: usize, cycle: bool) -> Document {
        let mut doc = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let ids: Vec<ObjectId> = (0..=depth).map(|_| doc.new_object_id()).collect();
        for (at, id) in ids.iter().enumerate() {
            let mut dict = dictionary! { "Type" => "CMap" };
            match ids.get(at + 1) {
                Some(parent) => dict.set("UseCMap", *parent),
                None if cycle => dict.set("UseCMap", ids[0]),
                None => {}
            }
            let data = format!("1 begincidchar <{at:02X}> {at} endcidchar");
            doc.objects
                .insert(*id, Object::Stream(Stream::new(dict, data.into_bytes())));
        }
        let font = doc.add_object(dictionary! {
            "Type" => "Font", "Subtype" => "Type0", "BaseFont" => "Plex",
            "Encoding" => ids[0],
            "DescendantFonts" => vec![dictionary! { "Subtype" => "CIDFontType2" }.into()],
        });
        let resources = dictionary! { "Font" => dictionary! { "F1" => font } };
        opened(doc, resources, b"BT /F1 10 Tf <00> Tj ET")
    }

    #[test]
    fn usecmap_chains_are_followed_to_the_limit() {
        let limit = Limits::default().max_usecmap_depth as usize;
        let mut recorder = Recorder::default();
        usecmap_chain(limit, false)
            .page_text(0, &mut recorder)
            .unwrap();
        let font = &recorder.fonts[0];
        assert_eq!(
            font.cmap.as_deref(),
            Some(&b"1 begincidchar <00> 0 endcidchar"[..])
        );
        assert_eq!(font.cmap_parents.len(), limit);
        assert_eq!(
            font.cmap_parents[0],
            b"1 begincidchar <01> 1 endcidchar".to_vec(),
            "nearest first"
        );
        assert_eq!(
            limit_of(usecmap_chain(limit + 1, false).page_text(0, &mut Recorder::default())),
            Some(LimitKind::UsecmapDepth)
        );
        // A loop stops at the CMap it started from.
        let mut recorder = Recorder::default();
        usecmap_chain(2, true).page_text(0, &mut recorder).unwrap();
        assert_eq!(recorder.fonts[0].cmap_parents.len(), 2);
    }

    /// The state after the last operator `name` of a page with `content`.
    fn after(content: &[u8], name: &str) -> GraphicsState {
        record(content, b"").after(name).clone()
    }

    #[test]
    fn q_saves_the_graphics_state() {
        assert_eq!(after(b"q", "q").q_depth, 1);
        assert_eq!(after(b"q q Q", "Q").q_depth, 1);
    }

    #[test]
    fn big_q_restores_all_but_the_text_matrices() {
        let state = after(b"q 2 0 0 2 0 0 cm 0.5 g BT 1 0 0 1 5 5 Tm Q", "Q");
        assert_eq!(
            (state.ctm, state.fill.clone()),
            (IDENTITY, Colour::default())
        );
        assert_eq!(state.text_matrix, [1.0, 0.0, 0.0, 1.0, 5.0, 5.0]);
        assert_eq!(state.q_depth, 0);
        // An unbalanced `Q` changes nothing.
        assert_eq!(after(b"2 0 0 2 0 0 cm Q", "Q").ctm[0], 2.0);
    }

    #[test]
    fn cm_concatenates_to_the_ctm() {
        let state = after(b"2 0 0 2 0 0 cm 1 0 0 1 5 7 cm", "cm");
        assert_eq!(state.ctm, [2.0, 0.0, 0.0, 2.0, 10.0, 14.0]);
    }

    #[test]
    fn bt_resets_the_text_matrices() {
        let state = after(b"BT 1 0 0 1 5 5 Tm ET BT", "BT");
        assert_eq!((state.text_matrix, state.line_matrix), (IDENTITY, IDENTITY));
    }

    #[test]
    fn et_ends_the_text_object_with_its_span() {
        let content = b"BT ET";
        let recorder = record(content, b"");
        let (name, span, _, _) = &recorder.ops[1];
        assert_eq!(
            (name.as_str(), &content[span.range.clone()]),
            ("ET", &b"ET"[..])
        );
    }

    #[test]
    fn tf_sets_the_font_and_size() {
        let state = after(b"/F1 9 Tf", "Tf");
        assert!(state.font.is_some());
        assert_eq!(
            (state.font_name.as_deref(), state.size),
            (Some(&b"F1"[..]), 9.0)
        );
        // A font the resources do not have sets none.
        assert_eq!(after(b"/F1 9 Tf /F9 8 Tf", "Tf").font, None);
    }

    #[test]
    fn tm_sets_both_matrices() {
        let state = after(b"BT 2 0 0 2 5 6 Tm", "Tm");
        let m = [2.0, 0.0, 0.0, 2.0, 5.0, 6.0];
        assert_eq!((state.text_matrix, state.line_matrix), (m, m));
    }

    #[test]
    fn td_moves_from_the_line_start() {
        let state = after(b"BT /F1 10 Tf 1 0 0 1 10 10 Tm (ab) Tj 5 -12 Td", "Td");
        let m = [1.0, 0.0, 0.0, 1.0, 15.0, -2.0];
        assert_eq!((state.text_matrix, state.line_matrix), (m, m));
        assert_eq!(state.leading, 0.0);
    }

    #[test]
    fn big_td_also_sets_the_leading() {
        let state = after(b"BT 0 -12 TD", "TD");
        assert_eq!((state.leading, state.line_matrix[5]), (12.0, -12.0));
    }

    #[test]
    fn t_star_goes_one_leading_down() {
        let state = after(b"BT 14 TL 0 100 Td T*", "T*");
        assert_eq!((state.text_matrix[5], state.line_matrix[5]), (86.0, 86.0));
    }

    #[test]
    fn the_text_state_operators_set_their_parameter() {
        assert_eq!(after(b"14 TL", "TL").leading, 14.0);
        assert_eq!(after(b"0.5 Tc", "Tc").char_spacing, 0.5);
        assert_eq!(after(b"2 Tw", "Tw").word_spacing, 2.0);
        assert_eq!(after(b"50 Tz", "Tz").horizontal_scaling, 0.5);
        assert_eq!(after(b"3 Ts", "Ts").rise, 3.0);
        assert_eq!(after(b"3 Tr", "Tr").render_mode, 3);
        // A mode that is no number keeps the last one.
        assert_eq!(after(b"7 Tr 1.5 Tr", "Tr").render_mode, 7);
    }

    #[test]
    fn tj_shows_with_its_span_and_moves_the_text_matrix() {
        let content = b"BT /F1 10 Tf (Ab) Tj ET";
        let recorder = record(content, b"");
        assert_eq!(recorder.shows[0].0, "Ab");
        assert_eq!(&content[recorder.show_spans[0].range.clone()], b"(Ab) Tj");
        // 2 codes × 5 points.
        assert_eq!(recorder.after("Tj").text_matrix[4], 10.0);
    }

    #[test]
    fn big_tj_applies_its_adjustments() {
        let content = b"BT /F1 10 Tf [(a) -1000 (b)] TJ ET";
        let recorder = record(content, b"");
        assert_eq!(recorder.shows[0].0, "ab");
        assert_eq!(
            &content[recorder.show_spans[0].range.clone()],
            b"[(a) -1000 (b)] TJ"
        );
        // 5 + 10 + 5 points.
        assert_eq!(recorder.after("TJ").text_matrix[4], 20.0);
    }

    #[test]
    fn quote_goes_to_the_next_line_and_shows() {
        let recorder = record(b"BT /F1 10 Tf 12 TL 0 100 Td (a) ' ET", b"");
        assert_eq!(recorder.shows[0].1[5], 88.0);
        assert_eq!(recorder.after("'").line_matrix[5], 88.0);
    }

    #[test]
    fn double_quote_sets_the_spacing_first() {
        let recorder = record(b"BT /F1 10 Tf 12 TL 3 1 (a) \" ET", b"");
        assert_eq!(recorder.shows[0].2, 3.0);
        let state = recorder.after("\"");
        assert_eq!((state.word_spacing, state.char_spacing), (3.0, 1.0));
        assert_eq!(state.line_matrix[5], -12.0);
    }

    #[test]
    fn a_clip_lasts_until_its_graphics_state_ends() {
        assert!(after(b"q 0 0 10 10 re W n", "n").clipped);
        assert!(after(b"0 0 10 10 re W* n", "W*").clipped);
        assert!(!after(b"q 0 0 10 10 re W n Q", "Q").clipped);
    }

    #[test]
    fn colours_keep_their_space_and_operands() {
        let state = after(b"/DeviceRGB cs 1 0 0 sc 0.5 G", "G");
        assert_eq!(state.fill.space, b"DeviceRGB");
        assert_eq!(state.fill.components, [1.0, 0.0, 0.0]);
        assert_eq!(
            (&state.stroke.space[..], &state.stroke.components[..]),
            (&b"DeviceGray"[..], &[0.5][..])
        );
        let state = after(b"0 0 0 1 k 1 0 0 RG /Pattern cs /P1 scn", "scn");
        assert_eq!(
            (&state.fill.space[..], state.fill.pattern.as_deref()),
            (&b"Pattern"[..], Some(&b"P1"[..]))
        );
        assert_eq!(state.stroke.space, b"DeviceRGB");
        assert_eq!(
            after(b"/DeviceCMYK CS", "CS").stroke.components,
            [0.0, 0.0, 0.0, 1.0]
        );
        assert_eq!(after(b"0.2 0.4 0.6 0.8 K", "K").stroke.space, b"DeviceCMYK");
        assert_eq!(after(b"/CS0 cs 0.3 scn", "scn").fill.components, [0.3]);
        assert_eq!(after(b"/CS0 CS 0.3 SC", "SC").stroke.space, b"CS0");
        assert_eq!(after(b"0 1 0 rg", "rg").fill.space, b"DeviceRGB");
    }

    /// A page whose `/Contents` is an array of `streams`, with the font `F1` and the resources
    /// `extra` adds; returns it and the streams' objects.
    fn page_of(
        streams: &[&[u8]],
        extra: impl FnOnce(&mut lopdf::Document, &mut Dictionary),
    ) -> (Document, Vec<ObjectId>) {
        let mut doc = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let font = doc.add_object(dictionary! {
            "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Helvetica",
        });
        let mut resources = dictionary! { "Font" => dictionary! { "F1" => font } };
        extra(&mut doc, &mut resources);
        let ids: Vec<ObjectId> = streams
            .iter()
            .map(|data| doc.add_object(Stream::new(dictionary! {}, data.to_vec())))
            .collect();
        let page = doc.page_iter().next().unwrap();
        let page = doc.get_dictionary_mut(page).unwrap();
        page.set("Resources", resources);
        page.set(
            "Contents",
            ids.iter()
                .map(|id| Object::Reference(*id))
                .collect::<Vec<_>>(),
        );
        let mut bytes = Vec::new();
        doc.save_to(&mut bytes).unwrap();
        let opened = open(
            &Source::from_bytes(Arc::from(&bytes[..])),
            &OpenOptions::default(),
        )
        .unwrap();
        (opened, ids)
    }

    fn record_page(doc: &Document) -> Recorder {
        let mut recorder = Recorder::default();
        doc.page_text(0, &mut recorder).unwrap();
        recorder
    }

    #[test]
    fn gs_applies_its_font_and_is_named() {
        let (doc, _) = page_of(&[b"/GS1 gs BT (a) Tj ET"], |doc, resources| {
            let font = doc.add_object(dictionary! {
                "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Courier",
            });
            resources.set(
                "ExtGState",
                dictionary! { "GS1" => dictionary! { "Font" => vec![font.into(), 7.into()] } },
            );
        });
        let recorder = record_page(&doc);
        let state = recorder.after("gs");
        assert_eq!((state.size, state.font_name.clone()), (7.0, None));
        assert_eq!(state.ext_g_states, [b"GS1".to_vec()]);
        assert_eq!(recorder.shows.len(), 1, "the gs font draws");
        assert_eq!(recorder.fonts[0].base_font.as_deref(), Some("Courier"));
    }

    #[test]
    fn marked_content_nests_with_its_properties() {
        let content: &[u8] = b"/Artifact BMC EMC \
            /Span << /MCID 3 /ActualText (fi) /Lang (tr-TR) >> BDC \
            /OC /L1 BDC BT /F1 10 Tf (a) Tj ET EMC EMC EMC";
        let (doc, _) = page_of(&[content], |doc, resources| {
            let layer = doc.add_object(dictionary! { "Type" => "OCG", "Name" => "L" });
            resources.set("Properties", dictionary! { "L1" => layer });
        });
        let recorder = record_page(&doc);
        let bmc = &recorder.ops.iter().find(|op| op.0 == "BMC").unwrap().3;
        assert!(bmc.len() == 1 && bmc[0].is_artifact());
        let (_, _, _, marked) = recorder.ops.iter().find(|op| op.0 == "Tj").unwrap();
        assert_eq!(marked.len(), 2);
        assert_eq!(
            (
                marked[0].mcid,
                marked[0].actual_text.as_deref(),
                marked[0].lang.as_deref()
            ),
            (Some(3), Some("fi"), Some("tr-TR"))
        );
        assert_eq!(marked[1].tag, b"OC");
        assert!(marked[1].optional_content.is_some());
        // The extra `EMC` closes nothing.
        assert!(recorder.ops.last().unwrap().3.is_empty());
    }

    #[test]
    fn an_inline_image_reports_its_span_and_ctm() {
        let content = b"q 1 0 0 1 5 5 cm BI /W 1 /H 1 /BPC 8 /CS /G ID x EI Q";
        let recorder = record(content, b"");
        let (_, span, state, _) = recorder.ops.iter().find(|op| op.0 == "BI").unwrap();
        assert!(content[span.range.clone()].starts_with(b"BI"));
        assert!(content[span.range.clone()].ends_with(b"EI"));
        assert_eq!(state.ctm, [1.0, 0.0, 0.0, 1.0, 5.0, 5.0]);
    }

    #[test]
    fn spans_of_a_contents_array_name_their_stream() {
        let second: &[u8] = b"  10 Tf (A) Tj ET";
        let (doc, ids) = page_of(&[b"BT /F1", second], |_, _| {});
        let recorder = record_page(&doc);
        let span = &recorder.show_spans[0];
        assert_eq!(span.source, SpanSource::Page { stream: ids[1] });
        assert_eq!(&second[span.range.clone()], b"(A) Tj");
        // `Tf`'s name operand is in the first stream.
        let (_, tf, state, _) = recorder.ops.iter().find(|op| op.0 == "Tf").unwrap();
        assert!(tf.carried && tf.source == SpanSource::Page { stream: ids[1] });
        assert_eq!(&second[tf.range.clone()], b"  10 Tf");
        assert_eq!(state.size, 10.0);
        let bt = &recorder.ops[0].1;
        assert_eq!(
            (bt.source, bt.carried),
            (SpanSource::Page { stream: ids[0] }, false)
        );
    }

    #[test]
    fn a_form_span_names_its_form() {
        let form: &[u8] = b"BT /F1 10 Tf (in) Tj ET";
        let recorder = record(b"q /X1 Do Q", form);
        let span = &recorder.show_spans[0];
        assert!(matches!(span.source, SpanSource::Form { .. }), "{span:?}");
        assert_eq!(&form[span.range.clone()], b"(in) Tj");
        // The form's operators come before its `Do`, which is the page's; q depth restarts.
        let names: Vec<&str> = recorder.ops.iter().map(|op| op.0.as_str()).collect();
        assert_eq!(names, ["q", "BT", "Tf", "Tj", "ET", "Do", "Q"]);
        assert_eq!(recorder.ops[1].2.q_depth, 0);
        assert!(matches!(recorder.ops[5].1.source, SpanSource::Page { .. }));
    }

    #[test]
    fn a_type3_font_lists_its_glyph_procedures() {
        let font = announced(|doc| {
            let a = doc.add_object(Stream::new(dictionary! {}, b"500 0 d0 0 0 m".to_vec()));
            let b = doc.add_object(Stream::new(
                dictionary! {},
                b"600 0 0 0 500 700 d1 0 0 500 700 re f".to_vec(),
            ));
            let c = doc.add_object(Stream::new(dictionary! {}, b"0 0 m".to_vec()));
            dictionary! {
                "Type" => "Font", "Subtype" => "Type3",
                "FontMatrix" => vec![0.001.into(), 0.into(), 0.into(), 0.001.into(), 0.into(), 0.into()],
                "CharProcs" => dictionary! { "a" => a, "b" => b, "c" => c },
                "Encoding" => dictionary! { "Differences" => vec![97.into(), "a".into(), "b".into()] },
                "FirstChar" => 97, "Widths" => vec![500.into(), 600.into()],
            }
        });
        assert_eq!(font.kind, FontKind::Type3);
        assert_eq!(
            font.char_procs,
            [
                CharProc {
                    name: "a".to_owned(),
                    width: Some([500.0, 0.0]),
                    bbox: None
                },
                CharProc {
                    name: "b".to_owned(),
                    width: Some([600.0, 0.0]),
                    bbox: Some([0.0, 0.0, 500.0, 700.0]),
                },
                CharProc {
                    name: "c".to_owned(),
                    width: None,
                    bbox: None
                },
            ]
        );
    }

    #[test]
    fn a_form_inside_a_text_object_starts_with_its_own_text_matrices() {
        let recorder = record(b"BT 1 0 0 1 50 60 Tm /X1 Do ET", b"BT");
        let state = &recorder.ops[2].2;
        assert_eq!(recorder.ops[2].0, "BT");
        // The form's text starts afresh, and the page's text matrix is back after `Do`.
        assert_eq!(state.text_matrix, IDENTITY);
        assert_eq!(recorder.after("Do").text_matrix[4], 50.0);
    }

    #[test]
    fn marked_content_nesting_past_the_limit_is_a_resource_limit() {
        let mut content = b"/P BMC ".repeat(257);
        assert_eq!(
            limit_of(document(&content, b"").page_text(0, &mut Recorder::default())),
            Some(LimitKind::QNesting)
        );
        content.truncate(7 * 256);
        assert!(
            document(&content, b"")
                .page_text(0, &mut Recorder::default())
                .is_ok()
        );
    }

    #[test]
    fn the_state_q_copies_stays_small() {
        let numbers = "1 ".repeat(40);
        let long = "N".repeat(128);
        let content = format!("{numbers}sc /{long} cs /{long} Tf /a gs /b gs /a gs");
        let state = after(content.as_bytes(), "gs");
        assert_eq!(state.fill.components.len(), 32);
        assert_eq!(
            state.fill.space, b"DeviceGray",
            "a long name is no colour space"
        );
        assert_eq!(state.font_name, None);
        // Each name once, in the order last applied, and only the last 32.
        assert_eq!(state.ext_g_states, [b"b".to_vec(), b"a".to_vec()]);
        let many: String = (0..40).map(|i| format!("/G{i} gs ")).collect();
        let names = after(many.as_bytes(), "gs").ext_g_states;
        assert_eq!((names.len(), &names[0][..]), (32, &b"G8"[..]));
    }

    #[test]
    fn matrices_compose_in_pdf_order() {
        let scale = [2.0, 0.0, 0.0, 2.0, 0.0, 0.0];
        let shift = [1.0, 0.0, 0.0, 1.0, 5.0, 7.0];
        assert_eq!(multiply(scale, shift), [2.0, 0.0, 0.0, 2.0, 5.0, 7.0]);
        assert_eq!(multiply(shift, scale), [2.0, 0.0, 0.0, 2.0, 10.0, 14.0]);
    }
}
