//! Annotations: what creating, changing, deleting, replying to and resolving one writes, inside
//! the open transaction of a document's [`RevisionStore`], and the one appearance generator each
//! kind has, so another reader shows what Ferman wrote (M4 plan, W2).
//!
//! Everything here is in the page's user space. An appearance is a form whose `/BBox` is the
//! annotation's `/Rect`, drawn in user space; text and icons are turned inside it by the page's
//! `/Rotate`, so they read upright on a turned page. A generator runs only for a change to what the
//! annotation draws: a text edit of a highlight or a move of a drawn one keeps its appearance (a
//! form follows `/Rect`), and a stamp's or an unknown type's drawing is never replaced.

use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};
use std::fmt::Write as _;

use ferman_core::annotations::{Annotation, AnnotationKind, LineEnd, MAX_TEXT, instant};
use ferman_core::revision::RevisionStore;
use ferman_core::structure::PdfDate;
use ferman_core::write::{ObjectRef, Value, text_value};
use ferman_core::{CoreError, Document, WriteError};
use ferman_fonts::{
    Direction, FaceId, FontLibrary, FontProgram, GlyphId, ShapeRequest, ShapingFont, SimilarQuery,
    StyleMetrics, rank_similar,
};
use ferman_text::bidi::visual_runs;
use ferman_text::fallback::embed;
use ferman_text::{Break, breaks};

use crate::OpsError;

/// Coordinates past this are no page's (twice the largest page side).
const LARGEST_COORDINATE: f32 = 28_800.0;
/// The thickest stroke.
const THICKEST: f32 = 144.0;
/// The most points one annotation takes.
const MOST_POINTS: usize = 100_000;
/// The font sizes a text annotation takes.
const FONT_SIZES: std::ops::RangeInclusive<f32> = 1.0..=288.0;
/// What of a long text an appearance sets; the box could not show more, and `/Contents` keeps it.
const MOST_SET_TEXT: usize = 32 * 1024;
/// Points by which a box may change size without having been resized: a moved box's width and
/// height pick up rounding, far below what anyone can see.
const SAME_SIZE: f32 = 0.01;
/// `/F`: printed.
const PRINT: i64 = 4;
/// `/F`: printed, with no zoom and no turn, as a reply is.
const REPLY_FLAGS: i64 = 28;
/// `/F`: a state reply: also hidden, as readers write them.
const STATE_FLAGS: i64 = 30;
/// A control point of a quarter circle, per unit of radius.
const KAPPA: f32 = 0.552_284_8;
/// The space between a text box's edge and its text, in points.
const TEXT_PADDING: f32 = 4.0;
/// Text line height, per unit of font size.
pub(crate) const LINE_HEIGHT: f32 = 1.3;
/// Text ascent above the first baseline, per unit of font size.
const ASCENT: f32 = 1.0;
/// `.fm-stamp`: its opacity, border, outline with its offset, and corner.
const STAMP_OPACITY: f32 = 0.9;
const STAMP_BORDER: f32 = 2.0;
const STAMP_OUTLINE: f32 = 1.0;
const STAMP_OUTLINE_OFFSET: f32 = 2.0;
const STAMP_RADIUS: f32 = 3.0;
/// `.fm-stamp`: the label's and the meta line's letter spacing per unit of size.
const STAMP_LABEL_SPACING: f32 = 0.14;
const STAMP_META_SPACING: f32 = 0.04;
/// `.fm-stamp__meta`: its font size per unit of the label's (9 px under 18).
const STAMP_META_SIZE: f32 = 0.5;
/// `.fm-note-pin`'s side, which a note's icon is drawn on.
const PIN: f32 = 24.0;
/// `--paper-900`, the pin's icon.
const PIN_INK: [f32; 3] = [0.102, 0.086, 0.063];

/// A new annotation, in user space.
#[derive(Debug, Clone, PartialEq)]
pub struct NewAnnotation {
    /// What it is; never [`AnnotationKind::Squiggly`] or `Other` (decision 6).
    pub kind: AnnotationKind,
    /// A note's, text box's, shape's or stamp's box; a callout's text box. Others take theirs from
    /// `points`.
    pub rect: [f32; 4],
    /// Text markup: each quad's corners, top left, top right, bottom left and bottom right as the
    /// reader sees them. Ink: each stroke. Line: its two ends. Polygon: its vertices. Callout: its
    /// leader from the far end to the box.
    pub points: Vec<Vec<[f32; 2]>>,
    /// `/C`.
    pub color: [f32; 3],
    /// The stroke, in points.
    pub stroke: f32,
    /// `/CA`.
    pub opacity: f32,
    /// `/Contents`.
    pub contents: String,
    /// `/T`.
    pub author: String,
    /// A text box's, callout's or stamp label's size.
    pub font_size: f32,
    /// A line ends in an arrow.
    pub arrow: bool,
    /// A stamp's label, cased by the caller (locale-aware casing is Dart's, a4-3b).
    pub label: String,
    /// The line under a stamp's label: name, date and time as placed (decision 10).
    pub meta: Option<String>,
    /// A stamp's turn in degrees; negative turns anticlockwise, as `Stamp` draws it.
    pub tilt: f32,
    /// `/Name`: a note's icon or a stamp's name.
    pub icon: Option<String>,
}

/// What a change sets; `None` leaves it.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct AnnotationChange {
    /// New text, which replaces `/RC`: rich text no longer says the same.
    pub contents: Option<String>,
    /// A new box: its geometry follows, moved and scaled.
    pub rect: Option<[f32; 4]>,
    /// New geometry, as [`NewAnnotation::points`].
    pub points: Option<Vec<Vec<[f32; 2]>>>,
    /// `/C`.
    pub color: Option<[f32; 3]>,
    /// The stroke, in points.
    pub stroke: Option<f32>,
    /// `/CA`.
    pub opacity: Option<f32>,
    /// A text box's or callout's font size.
    pub font_size: Option<f32>,
}

pub(crate) fn plan_error() -> OpsError {
    CoreError::Write(WriteError::AnnotationPlan).into()
}

fn missing() -> OpsError {
    CoreError::Write(WriteError::NoSuchAnnotation).into()
}

pub(crate) fn check_coordinates(values: impl IntoIterator<Item = f32>) -> Result<(), OpsError> {
    if values
        .into_iter()
        .all(|value| value.is_finite() && value.abs() <= LARGEST_COORDINATE)
    {
        Ok(())
    } else {
        Err(plan_error())
    }
}

fn check_points(points: &[Vec<[f32; 2]>]) -> Result<(), OpsError> {
    if points.iter().map(Vec::len).sum::<usize>() > MOST_POINTS {
        return Err(plan_error());
    }
    check_coordinates(points.iter().flatten().flatten().copied())
}

fn check_style(
    color: Option<[f32; 3]>,
    stroke: Option<f32>,
    opacity: Option<f32>,
    size: Option<f32>,
) -> Result<(), OpsError> {
    let fine = color.is_none_or(|rgb| rgb.iter().all(|v| (0.0..=1.0).contains(v)))
        && stroke.is_none_or(|width| (0.0..=THICKEST).contains(&width))
        && opacity.is_none_or(|opacity| (0.0..=1.0).contains(&opacity))
        && size.is_none_or(|size| FONT_SIZES.contains(&size));
    if fine { Ok(()) } else { Err(plan_error()) }
}

/// Text a user typed for one annotation: within what the reader lists whole.
fn check_text(text: &str) -> Result<(), OpsError> {
    if text.len() > MAX_TEXT / 2 {
        return Err(plan_error());
    }
    Ok(())
}

pub(crate) fn normalized([x0, y0, x1, y1]: [f32; 4]) -> [f32; 4] {
    [x0.min(x1), y0.min(y1), x0.max(x1), y0.max(y1)]
}

pub(crate) fn numbers(values: impl IntoIterator<Item = f32>) -> Value {
    Value::Array(values.into_iter().map(Value::Real).collect())
}

pub(crate) fn name(value: &[u8]) -> Value {
    Value::Name(value.to_vec())
}

/// The bounds of `points`, grown by `margin`; a zero rectangle for none.
fn bounds<'a>(points: impl IntoIterator<Item = &'a [f32; 2]>, margin: f32) -> [f32; 4] {
    let mut area: Option<[f32; 4]> = None;
    for &[x, y] in points {
        area = Some(area.map_or([x, y, x, y], |[l, b, r, t]| {
            [l.min(x), b.min(y), r.max(x), t.max(y)]
        }));
    }
    let [l, b, r, t] = area.unwrap_or_default();
    [l - margin, b - margin, r + margin, t + margin]
}

fn union([a, b, c, d]: [f32; 4], [e, f, g, h]: [f32; 4]) -> [f32; 4] {
    [a.min(e), b.min(f), c.max(g), d.max(h)]
}

fn arrow_length(stroke: f32) -> f32 {
    (stroke * 4.0).max(6.0)
}

/// How far the drawing of `annotation`'s geometry reaches past its points.
fn margin(annotation: &Annotation) -> f32 {
    let arrow = annotation.line_ends != [LineEnd::None; 2];
    annotation.stroke / 2.0
        + 1.0
        + if arrow {
            arrow_length(annotation.stroke)
        } else {
            0.0
        }
}

fn set_geometry(next: &mut Annotation, points: &[Vec<[f32; 2]>]) -> Result<(), OpsError> {
    let first = || points.first().map(Vec::as_slice).unwrap_or_default();
    match next.kind {
        AnnotationKind::Highlight
        | AnnotationKind::Underline
        | AnnotationKind::StrikeOut
        | AnnotationKind::Squiggly => {
            next.quads = points
                .iter()
                .map(|quad| match quad[..] {
                    [a, b, c, d] => Ok([a[0], a[1], b[0], b[1], c[0], c[1], d[0], d[1]]),
                    _ => Err(plan_error()),
                })
                .collect::<Result<_, _>>()?;
            if next.quads.is_empty() {
                return Err(plan_error());
            }
            next.rect = bounds(points.iter().flatten(), margin(next));
        }
        AnnotationKind::Ink => {
            if points.iter().all(Vec::is_empty) {
                return Err(plan_error());
            }
            next.ink = points.to_vec();
            next.rect = bounds(points.iter().flatten(), margin(next));
        }
        AnnotationKind::Line => {
            let [a, b] = first() else {
                return Err(plan_error());
            };
            next.line = Some([a[0], a[1], b[0], b[1]]);
            next.rect = bounds([a, b], margin(next));
        }
        AnnotationKind::Polygon => {
            if first().len() < 3 {
                return Err(plan_error());
            }
            next.vertices = first().to_vec();
            next.rect = bounds(first(), margin(next));
        }
        AnnotationKind::Callout => {
            if !(2..=3).contains(&first().len()) {
                return Err(plan_error());
            }
            let [l, b, r, t] = text_box(next);
            next.callout = first().to_vec();
            let rect = union(bounds(first(), margin(next)), [l, b, r, t]);
            next.inset = [l - rect[0], b - rect[1], rect[2] - r, rect[3] - t];
            next.rect = rect;
        }
        _ => return Err(plan_error()),
    }
    Ok(())
}

/// The box a text box's or callout's text sits in: `/Rect` less `/RD`.
fn text_box(annotation: &Annotation) -> [f32; 4] {
    let [l, b, r, t] = annotation.rect;
    let [il, ib, ir, it] = annotation.inset;
    [l + il, b + ib, (r - ir).max(l + il), (t - it).max(b + ib)]
}

/// `annotation`'s geometry moved and scaled from its `/Rect` to `rect`.
fn map_geometry(annotation: &mut Annotation, rect: [f32; 4]) {
    let [l, b, r, t] = annotation.rect;
    let (old_w, old_h) = (r - l, t - b);
    let sx = if old_w > 0.0 {
        (rect[2] - rect[0]) / old_w
    } else {
        1.0
    };
    let sy = if old_h > 0.0 {
        (rect[3] - rect[1]) / old_h
    } else {
        1.0
    };
    let x = |value: f32| rect[0] + (value - l) * sx;
    let y = |value: f32| rect[1] + (value - b) * sy;
    for quad in &mut annotation.quads {
        for pair in quad.as_chunks_mut::<2>().0 {
            *pair = [x(pair[0]), y(pair[1])];
        }
    }
    for point in annotation
        .ink
        .iter_mut()
        .flatten()
        .chain(&mut annotation.vertices)
        .chain(&mut annotation.callout)
    {
        *point = [x(point[0]), y(point[1])];
    }
    if let Some(line) = &mut annotation.line {
        *line = [x(line[0]), y(line[1]), x(line[2]), y(line[3])];
    }
    let [il, ib, ir, it] = annotation.inset;
    annotation.inset = [il * sx, ib * sy, ir * sx, it * sy];
    annotation.rect = rect;
}

/// The entries `annotation`'s geometry and box write.
fn geometry_entries(annotation: &Annotation) -> Vec<(Vec<u8>, Option<Value>)> {
    let mut entries = vec![(b"Rect".to_vec(), Some(numbers(annotation.rect)))];
    let mut set = |key: &[u8], value: Value| entries.push((key.to_vec(), Some(value)));
    if !annotation.quads.is_empty() {
        set(
            b"QuadPoints",
            numbers(annotation.quads.iter().flatten().copied()),
        );
    }
    if !annotation.ink.is_empty() {
        set(
            b"InkList",
            Value::Array(
                annotation
                    .ink
                    .iter()
                    .map(|stroke| numbers(stroke.iter().flatten().copied()))
                    .collect(),
            ),
        );
    }
    if let Some(line) = annotation.line {
        set(b"L", numbers(line));
    }
    if !annotation.vertices.is_empty() {
        set(
            b"Vertices",
            numbers(annotation.vertices.iter().flatten().copied()),
        );
    }
    if !annotation.callout.is_empty() {
        set(b"CL", numbers(annotation.callout.iter().flatten().copied()));
    }
    if annotation.inset != [0.0; 4] {
        set(b"RD", numbers(annotation.inset));
    }
    entries
}

fn border_style(annotation: &Annotation) -> Value {
    let mut style = vec![(b"W".to_vec(), Value::Real(annotation.stroke))];
    if !annotation.dash.is_empty() {
        style.push((b"S".to_vec(), name(b"D")));
        style.push((b"D".to_vec(), numbers(annotation.dash.iter().copied())));
    }
    Value::Dictionary(style)
}

/// `/DA` for `annotation`'s font size and colour. The font is named as readers expect a form's
/// default font named; the appearance holds the real one.
fn default_appearance(annotation: &Annotation) -> Value {
    let [r, g, b] = annotation.text_color.unwrap_or_default();
    let size = annotation.font_size.unwrap_or(12.0);
    Value::String(format!("{r} {g} {b} rg /Helv {size} Tf").into_bytes())
}

/// Which page turns text upright: `/Rotate` as 0, 90, 180 or 270.
fn page_turn(document: &Document, revisions: &RevisionStore, page: usize) -> Result<u16, OpsError> {
    revisions
        .pages(document)
        .get(page)
        .map(|page| page.rotation)
        .ok_or_else(|| CoreError::Write(WriteError::NoSuchPage).into())
}

/// A content stream being written.
#[derive(Default)]
pub(crate) struct Ops(pub(crate) String);

impl Ops {
    fn num(&mut self, value: f32) -> &mut Self {
        let value = if value.is_finite() { value } else { 0.0 };
        let rounded = (value * 1000.0).round() / 1000.0;
        let _ = write!(self.0, "{rounded} ");
        self
    }

    pub(crate) fn nums(&mut self, values: &[f32], op: &str) -> &mut Self {
        for value in values {
            self.num(*value);
        }
        self.op(op)
    }

    pub(crate) fn op(&mut self, op: &str) -> &mut Self {
        self.0.push_str(op);
        self.0.push('\n');
        self
    }

    pub(crate) fn stroke_colour(&mut self, rgb: [f32; 3]) -> &mut Self {
        self.nums(&rgb, "RG")
    }

    pub(crate) fn fill_colour(&mut self, rgb: [f32; 3]) -> &mut Self {
        self.nums(&rgb, "rg")
    }

    pub(crate) fn moved(&mut self, [x, y]: [f32; 2]) -> &mut Self {
        self.nums(&[x, y], "m")
    }

    pub(crate) fn line(&mut self, [x, y]: [f32; 2]) -> &mut Self {
        self.nums(&[x, y], "l")
    }

    fn stroke_style(&mut self, annotation: &Annotation) -> &mut Self {
        self.nums(&[annotation.stroke], "w");
        if !annotation.dash.is_empty() {
            self.0.push('[');
            for dash in &annotation.dash {
                self.num(*dash);
            }
            self.op("] 0 d");
        }
        self
    }

    /// A rounded rectangle's path.
    fn rounded(&mut self, [l, b, r, t]: [f32; 4], radius: f32) -> &mut Self {
        let radius = radius.min((r - l) / 2.0).min((t - b) / 2.0).max(0.0);
        let c = radius * (1.0 - KAPPA);
        self.moved([l + radius, b]).line([r - radius, b]);
        self.nums(&[r - c, b, r, b + c, r, b + radius], "c");
        self.line([r, t - radius]);
        self.nums(&[r, t - c, r - c, t, r - radius, t], "c");
        self.line([l + radius, t]);
        self.nums(&[l + c, t, l, t - c, l, t - radius], "c");
        self.line([l, b + radius]);
        self.nums(&[l, b + c, l + c, b, l + radius, b], "c");
        self.op("h")
    }

    fn ellipse(&mut self, [l, b, r, t]: [f32; 4]) -> &mut Self {
        let (cx, cy) = (f32::midpoint(l, r), f32::midpoint(b, t));
        let (kx, ky) = ((r - l) / 2.0 * KAPPA, (t - b) / 2.0 * KAPPA);
        self.moved([r, cy]);
        self.nums(&[r, cy + ky, cx + kx, t, cx, t], "c");
        self.nums(&[cx - kx, t, l, cy + ky, l, cy], "c");
        self.nums(&[l, cy - ky, cx - kx, b, cx, b], "c");
        self.nums(&[cx + kx, b, r, cy - ky, r, cy], "c");
        self.op("h")
    }

    /// An arrow whose tip is `tip`, coming from `from`.
    fn arrow(&mut self, end: LineEnd, from: [f32; 2], tip: [f32; 2], length: f32) {
        let (dx, dy) = (tip[0] - from[0], tip[1] - from[1]);
        let size = dx.hypot(dy);
        if end == LineEnd::None || size <= 0.0 {
            return;
        }
        let (ux, uy) = (dx / size, dy / size);
        let wing = |side: f32| {
            [
                tip[0] - length * ux - side * length * 0.45 * uy,
                tip[1] - length * uy + side * length * 0.45 * ux,
            ]
        };
        self.moved(wing(1.0)).line(tip).line(wing(-1.0));
        self.op(if end == LineEnd::ClosedArrow {
            "h B"
        } else {
            "S"
        });
    }
}

/// `true` when `rgb`'s fill and stroke should go through `/GS0`.
fn state(opacity: f32, multiply: bool) -> Option<Value> {
    if opacity >= 1.0 && !multiply {
        return None;
    }
    let mut dict = vec![
        (b"Type".to_vec(), name(b"ExtGState")),
        (b"CA".to_vec(), Value::Real(opacity)),
        (b"ca".to_vec(), Value::Real(opacity)),
    ];
    if multiply {
        dict.push((b"BM".to_vec(), name(b"Multiply")));
    }
    Some(Value::Dictionary(dict))
}

/// A quad's corners as the file orders them: top left, top right, bottom left, bottom right.
fn corners(quad: &[f32; 8]) -> [[f32; 2]; 4] {
    [
        [quad[0], quad[1]],
        [quad[2], quad[3]],
        [quad[4], quad[5]],
        [quad[6], quad[7]],
    ]
}

fn along(from: [f32; 2], to: [f32; 2], part: f32) -> [f32; 2] {
    [
        from[0] + (to[0] - from[0]) * part,
        from[1] + (to[1] - from[1]) * part,
    ]
}

/// One generator per kind. Highlight: the quads filled, multiplied over the page.
fn highlight(ops: &mut Ops, annotation: &Annotation) {
    ops.fill_colour(annotation.color.unwrap_or([1.0, 0.82, 0.2]));
    for quad in &annotation.quads {
        let [a, b, c, d] = corners(quad);
        ops.moved(a).line(b).line(d).line(c).op("h f");
    }
}

/// Underline: the bottom edge of each quad; a stroke in proportion to the line of text.
fn underline(ops: &mut Ops, annotation: &Annotation) {
    ops.stroke_colour(annotation.color.unwrap_or_default());
    for quad in &annotation.quads {
        let [a, b, c, d] = corners(quad);
        let height = (a[0] - c[0]).hypot(a[1] - c[1]);
        ops.nums(&[(height / 16.0).max(0.75)], "w");
        const LIFT: f32 = 1.0 / 16.0;
        ops.moved(along(c, a, LIFT)).line(along(d, b, LIFT)).op("S");
    }
}

/// StrikeOut: through the middle of each quad.
fn strike_out(ops: &mut Ops, annotation: &Annotation) {
    ops.stroke_colour(annotation.color.unwrap_or_default());
    for quad in &annotation.quads {
        let [a, b, c, d] = corners(quad);
        let height = (a[0] - c[0]).hypot(a[1] - c[1]);
        ops.nums(&[(height / 16.0).max(0.75)], "w");
        ops.moved(along(c, a, 0.5)).line(along(d, b, 0.5)).op("S");
    }
}

/// Squiggly: a zigzag under each quad, for a recoloured foreign one (decision 6).
fn squiggly(ops: &mut Ops, annotation: &Annotation) {
    const MOST_TEETH: usize = 2_000;
    ops.stroke_colour(annotation.color.unwrap_or_default());
    ops.nums(&[0.75], "w");
    for quad in &annotation.quads {
        let [a, _, c, d] = corners(quad);
        let height = (a[0] - c[0]).hypot(a[1] - c[1]).max(1.0);
        let tooth = (height / 6.0).max(1.0);
        let length = (d[0] - c[0]).hypot(d[1] - c[1]);
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let teeth = ((length / tooth) as usize).clamp(1, MOST_TEETH);
        let lift = |part: f32| along(c, a, part / height);
        let mut point = lift(0.5);
        ops.moved(point);
        for tooth in 1..=teeth {
            #[allow(clippy::cast_precision_loss)]
            let part = tooth as f32 / teeth as f32;
            let base = lift(if tooth % 2 == 0 { 0.5 } else { 2.0 });
            point = [
                base[0] + (d[0] - c[0]) * part,
                base[1] + (d[1] - c[1]) * part,
            ];
            ops.line(point);
        }
        ops.op("S");
    }
}

/// Note: `.fm-note-pin`, a coloured square with a speech bubble, upright on any page.
fn note(ops: &mut Ops, annotation: &Annotation, turn: u16) {
    let (width, height) = upright(ops, annotation.rect, turn);
    let side = width.min(height).max(1.0);
    ops.nums(&[side / PIN, 0.0, 0.0, side / PIN, 0.0, 0.0], "cm");
    let color = annotation.color.unwrap_or([1.0, 0.82, 0.2]);
    ops.fill_colour(color);
    // The pin's hairline ring, rgba(0,0,0,.12) over its own colour.
    ops.stroke_colour(color.map(|value| value * 0.88))
        .nums(&[0.5], "w");
    ops.rounded([0.25, 0.25, PIN - 0.25, PIN - 0.25], 4.0)
        .op("B");
    ops.stroke_colour(PIN_INK).nums(&[1.5], "w").op("1 J 1 j");
    // Lucide's message-square on the pin, 14 of its 24.
    ops.rounded([5.0, 8.0, 19.0, 19.0], 2.0);
    ops.moved([8.0, 8.0])
        .line([5.0, 5.0])
        .line([5.0, 9.5])
        .op("S");
}

/// Ink: each stroke, rounded.
fn ink(ops: &mut Ops, annotation: &Annotation) {
    ops.stroke_colour(annotation.color.unwrap_or_default());
    ops.stroke_style(annotation).op("1 J 1 j");
    for stroke in &annotation.ink {
        let mut points = stroke.iter();
        let Some(first) = points.next() else {
            continue;
        };
        ops.moved(*first);
        for point in points {
            ops.line(*point);
        }
        // One point draws a dot.
        if stroke.len() == 1 {
            ops.line(*first);
        }
        ops.op("S");
    }
}

/// How a closed shape paints: `IC` fills it, `C` and a stroke outline it.
fn paint_shape(ops: &mut Ops, annotation: &Annotation) -> &'static str {
    let outline = annotation.stroke > 0.0 && annotation.color.is_some();
    if let Some(color) = annotation.interior {
        ops.fill_colour(color);
    }
    ops.stroke_colour(annotation.color.unwrap_or_default());
    ops.stroke_style(annotation);
    match (annotation.interior.is_some(), outline) {
        (true, true) => "B",
        (true, false) => "f",
        (false, true) => "S",
        (false, false) => "n",
    }
}

/// The box inside `/Rect` a border's middle runs on.
// shortcut: `/BE` (a cloudy border) is kept in the file but a redraw draws it straight; upgrade when
// a board offers it.
fn stroked_box(annotation: &Annotation) -> [f32; 4] {
    let [l, b, r, t] = text_box(annotation);
    let half = annotation.stroke / 2.0;
    [
        l + half,
        b + half,
        (r - half).max(l + half),
        (t - half).max(b + half),
    ]
}

/// Square.
fn square(ops: &mut Ops, annotation: &Annotation) {
    let paint = paint_shape(ops, annotation);
    let [l, b, r, t] = stroked_box(annotation);
    ops.nums(&[l, b, r - l, t - b], "re").op(paint);
}

/// Circle.
fn circle(ops: &mut Ops, annotation: &Annotation) {
    let paint = paint_shape(ops, annotation);
    ops.ellipse(stroked_box(annotation)).op(paint);
}

/// Line, with its ends.
fn line(ops: &mut Ops, annotation: &Annotation) {
    let Some([x0, y0, x1, y1]) = annotation.line else {
        return;
    };
    ops.stroke_colour(annotation.color.unwrap_or_default());
    ops.fill_colour(annotation.interior.or(annotation.color).unwrap_or_default());
    ops.stroke_style(annotation);
    ops.moved([x0, y0]).line([x1, y1]).op("S");
    let length = arrow_length(annotation.stroke);
    ops.arrow(annotation.line_ends[0], [x1, y1], [x0, y0], length);
    ops.arrow(annotation.line_ends[1], [x0, y0], [x1, y1], length);
}

/// Polygon, as drawn (decision 6).
fn polygon(ops: &mut Ops, annotation: &Annotation) {
    let paint = paint_shape(ops, annotation);
    let mut points = annotation.vertices.iter();
    let Some(first) = points.next() else {
        return;
    };
    ops.moved(*first);
    for point in points {
        ops.line(*point);
    }
    ops.op("h").op(paint);
}

/// A callout's leader, up to its box.
fn leader(ops: &mut Ops, annotation: &Annotation) {
    let mut points = annotation.callout.iter();
    let Some(first) = points.next() else {
        return;
    };
    ops.stroke_colour(annotation.color.unwrap_or_default());
    ops.fill_colour(annotation.color.unwrap_or_default());
    ops.stroke_style(annotation);
    ops.moved(*first);
    for point in points {
        ops.line(*point);
    }
    ops.op("S");
    if let Some(next) = annotation.callout.get(1) {
        ops.arrow(
            annotation.line_ends[0],
            *next,
            *first,
            arrow_length(annotation.stroke),
        );
    }
}

/// Starts drawing upright in `area` on a page turned `turn` degrees: the origin at its bottom left
/// as the reader sees it, x to their right, y up. Returns the width and height they see. A caller
/// holds a `q`.
fn upright(ops: &mut Ops, [l, b, r, t]: [f32; 4], turn: u16) -> (f32, f32) {
    let (width, height) = (r - l, t - b);
    match turn {
        90 => {
            ops.nums(&[0.0, 1.0, -1.0, 0.0, r, b], "cm");
            (height, width)
        }
        180 => {
            ops.nums(&[-1.0, 0.0, 0.0, -1.0, r, t], "cm");
            (width, height)
        }
        270 => {
            ops.nums(&[0.0, -1.0, 1.0, 0.0, l, t], "cm");
            (height, width)
        }
        _ => {
            ops.nums(&[1.0, 0.0, 0.0, 1.0, l, b], "cm");
            (width, height)
        }
    }
}

/// A font program in use for an appearance.
struct Face {
    family: String,
    data: Vec<u8>,
    index: u32,
    shaper: ShapingFont,
    wanted: Vec<(GlyphId, String)>,
}

impl Face {
    fn covers(&self, c: char) -> bool {
        FontProgram::parse(&self.data)
            .ok()
            .is_some_and(|program| program.glyph_for_char(c).is_some())
    }
}

/// The fonts of one appearance: IBM Plex by script, then what the library has for the rest.
pub(crate) struct Faces<'a> {
    library: &'a FontLibrary,
    weight: u16,
    faces: Vec<Face>,
    /// The Plex families not opened yet.
    bundled: Vec<&'static str>,
    tried: HashSet<FaceId>,
}

impl<'a> Faces<'a> {
    pub(crate) fn new(library: &'a FontLibrary, weight: u16) -> Self {
        Self {
            library,
            weight,
            faces: Vec::new(),
            bundled: vec![
                "IBM Plex Sans",
                "IBM Plex Sans Arabic",
                "IBM Plex Sans Hebrew",
                "IBM Plex Sans Devanagari",
            ],
            tried: HashSet::new(),
        }
    }

    /// As [`new`](Self::new), IBM Plex Serif tried first, for a serif field (decision 18).
    pub(crate) fn serif(library: &'a FontLibrary, weight: u16) -> Self {
        let mut faces = Self::new(library, weight);
        faces.bundled.insert(0, "IBM Plex Serif");
        faces
    }

    /// The families in use that drew something.
    pub(crate) fn families(&self) -> Vec<String> {
        let mut families = Vec::new();
        for face in self.faces.iter().filter(|face| !face.wanted.is_empty()) {
            if !families.contains(&face.family) {
                families.push(face.family.clone());
            }
        }
        families
    }

    fn open(&mut self, id: FaceId) -> Option<usize> {
        if !self.tried.insert(id) {
            return None;
        }
        let (data, index) = self
            .library
            .with_data(id, |data, index| (data.to_vec(), index))?;
        let shaper = ShapingFont::new(data.clone(), index).ok()?;
        self.faces.push(Face {
            family: self.library.face(id)?.family,
            data,
            index,
            shaper,
            wanted: Vec::new(),
        });
        Some(self.faces.len().saturating_sub(1))
    }

    /// The first face in use that has `c`, opening others in turn. Never a silent substitute: a
    /// character no font here has stops the appearance.
    pub(crate) fn for_char(&mut self, c: char, current: Option<usize>) -> Result<usize, OpsError> {
        if let Some(current) = current
            && (c.is_whitespace() || c.is_control() || self.faces[current].covers(c))
        {
            return Ok(current);
        }
        if let Some(at) = self.faces.iter().position(|face| face.covers(c)) {
            return Ok(at);
        }
        while !self.bundled.is_empty() {
            let family = self.bundled.remove(0);
            let id = self
                .library
                .faces()
                .find(|face| face.family == family && face.weight == self.weight && !face.italic)
                .map(|face| face.id);
            if let Some(at) = id.and_then(|id| self.open(id))
                && (c.is_whitespace() || c.is_control() || self.faces[at].covers(c))
            {
                return Ok(at);
            }
        }
        let style = self
            .faces
            .first()
            .and_then(|face| StyleMetrics::of(&face.data, face.index).ok())
            .unwrap_or(StyleMetrics {
                x_height: None,
                cap_height: None,
                average_width: None,
                serif: Some(false),
                weight: 400,
                italic: false,
            });
        let text = c.to_string();
        let found = rank_similar(
            self.library,
            &SimilarQuery {
                text: &text,
                style,
                max_results: 8,
            },
        );
        for candidate in found {
            if candidate.coverage.is_full()
                && candidate.embedding.allows_subset()
                && candidate.face.instance.is_none()
                && let Some(at) = self.open(candidate.face.id)
            {
                return Ok(at);
            }
        }
        Err(OpsError::NoFontForText)
    }

    /// `text`'s runs with their faces, as (face, byte range).
    fn split(&mut self, text: &str) -> Result<Vec<(usize, std::ops::Range<usize>)>, OpsError> {
        let mut runs: Vec<(usize, std::ops::Range<usize>)> = Vec::new();
        for (at, c) in text.char_indices() {
            let current = runs.last().map(|run| run.0);
            let face = self.for_char(c, current)?;
            match runs.last_mut() {
                Some(run) if run.0 == face => run.1.end = at + c.len_utf8(),
                _ => runs.push((face, at..at + c.len_utf8())),
            }
        }
        Ok(runs)
    }

    /// Lays `line` out in visual order from x = 0: each glyph's face, id and place per unit of
    /// font size, its text noted for the subset; and the line's width per unit of font size,
    /// `spacing` added after each glyph.
    pub(crate) fn shape_line(
        &mut self,
        line: &str,
        rtl: bool,
        spacing: f32,
    ) -> Result<(Vec<Placed>, f32), OpsError> {
        let mut placed = Vec::new();
        let mut pen = 0.0f32;
        for run in visual_runs(line, 0..line.len(), rtl) {
            let text = line.get(run.range.clone()).unwrap_or_default();
            let mut parts = self.split(text)?;
            if run.rtl {
                parts.reverse();
            }
            for (face_index, range) in parts {
                let part = text.get(range).unwrap_or_default();
                let direction = if run.rtl {
                    Direction::RightToLeft
                } else {
                    Direction::LeftToRight
                };
                let face = &mut self.faces[face_index];
                let shaped = face.shaper.shape(&ShapeRequest::new(part, direction))?;
                let em = f32::from(shaped.units_per_em.max(1));
                for (glyph, (id, glyph_text)) in shaped.glyphs.iter().zip(shaped.glyph_texts(part))
                {
                    if id.0 != 0 {
                        #[allow(clippy::cast_precision_loss)]
                        placed.push(Placed {
                            face: face_index,
                            glyph: id,
                            x: pen + glyph.x_offset as f32 / em,
                            y: glyph.y_offset as f32 / em,
                        });
                        face.wanted.push((id, glyph_text));
                    }
                    #[allow(clippy::cast_precision_loss)]
                    {
                        pen += glyph.x_advance as f32 / em + spacing;
                    }
                }
            }
        }
        Ok((placed, pen))
    }

    /// The width of `text` per unit of font size, without noting its glyphs.
    pub(crate) fn measure(&mut self, text: &str, rtl: bool) -> Result<f32, OpsError> {
        let marks: Vec<usize> = self.faces.iter().map(|face| face.wanted.len()).collect();
        let (_, width) = self.shape_line(text, rtl, 0.0)?;
        for (at, face) in self.faces.iter_mut().enumerate() {
            face.wanted.truncate(marks.get(at).copied().unwrap_or(0));
        }
        Ok(width)
    }
}

/// A glyph laid out.
pub(crate) struct Placed {
    face: usize,
    glyph: GlyphId,
    x: f32,
    y: f32,
}

/// A line of an appearance's text, in the reader's upright space.
pub(crate) struct SetLine {
    pub(crate) glyphs: Vec<Placed>,
    pub(crate) x: f32,
    pub(crate) baseline: f32,
    pub(crate) size: f32,
    pub(crate) color: [f32; 3],
}

/// Whether a paragraph reads right to left, by its first strong letter.
pub(crate) fn right_to_left(text: &str) -> bool {
    text.chars().find(|c| c.is_alphabetic()).is_some_and(
        |c| matches!(u32::from(c), 0x0590..=0x08FF | 0xFB1D..=0xFDFF | 0xFE70..=0xFEFF),
    )
}

/// `text`'s first part that an appearance sets, on a character's edge.
fn settable(text: &str) -> &str {
    if text.len() <= MOST_SET_TEXT {
        return text;
    }
    let mut end = MOST_SET_TEXT;
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    text.get(..end).unwrap_or_default()
}

/// `text` wrapped in a box `width` by `height`, from its top, up to the most an appearance sets.
fn wrapped(
    faces: &mut Faces<'_>,
    text: &str,
    area: (f32, f32),
    size: f32,
    color: [f32; 3],
) -> Result<Vec<SetLine>, OpsError> {
    set_lines(faces, settable(text), area, size, color)
}

/// All of `text` wrapped in a box `width` by `height`, from its top: the lines that fit.
pub(crate) fn set_lines(
    faces: &mut Faces<'_>,
    text: &str,
    (width, height): (f32, f32),
    size: f32,
    color: [f32; 3],
) -> Result<Vec<SetLine>, OpsError> {
    let mut lines = Vec::new();
    let mut baseline = height - ASCENT * size;
    let room = (width / size).max(0.0);
    for paragraph in text.split(['\n', '\r']) {
        let rtl = right_to_left(paragraph);
        let mut start = 0usize;
        let mut end = 0usize;
        let mut used = 0.0f32;
        let mut stops: Vec<usize> = breaks(paragraph)
            .into_iter()
            .filter(|(_, kind)| matches!(kind, Break::Allowed | Break::Mandatory))
            .map(|(at, _)| at)
            .collect();
        if stops.is_empty() {
            stops.push(paragraph.len());
        }
        let mut finished: Vec<(usize, usize)> = Vec::new();
        for stop in stops {
            let piece = paragraph.get(end..stop).unwrap_or_default();
            let wide = faces.measure(piece.trim_end(), rtl)?;
            if used + wide > room && end > start {
                finished.push((start, end));
                start = end;
                used = 0.0;
            }
            used += faces.measure(piece, rtl)?;
            end = stop;
            #[allow(clippy::cast_precision_loss)]
            let below = LINE_HEIGHT * size * finished.len() as f32;
            if baseline < below {
                break;
            }
        }
        finished.push((start, end));
        for (from, to) in finished {
            if baseline < 0.0 {
                return Ok(lines);
            }
            let line = paragraph.get(from..to).unwrap_or_default().trim_end();
            let (glyphs, line_width) = faces.shape_line(line, rtl, 0.0)?;
            let x = if rtl {
                (room - line_width).max(0.0) * size
            } else {
                0.0
            };
            lines.push(SetLine {
                glyphs,
                x,
                baseline,
                size,
                color,
            });
            baseline -= LINE_HEIGHT * size;
        }
    }
    Ok(lines)
}

/// Embeds `faces` as `/{prefix}0`, `/{prefix}1` and on, each a subset of what they noted. Returns
/// the `/Font` entries, and for each face the code of each glyph.
pub(crate) fn embed_faces(
    document: &Document,
    revisions: &mut RevisionStore,
    faces: &Faces<'_>,
    prefix: &str,
) -> Result<FaceCodes, OpsError> {
    let mut fonts = Vec::new();
    let mut codes: Vec<HashMap<u32, Vec<u8>>> = Vec::new();
    for (at, face) in faces.faces.iter().enumerate() {
        if face.wanted.is_empty() {
            codes.push(HashMap::new());
            continue;
        }
        let (font, glyphs) = embed(
            &face.data,
            face.index,
            None,
            &face.wanted,
            format!("{prefix}{at}").into_bytes(),
        )
        .ok_or(OpsError::NoFontForText)?;
        let id = revisions.add_embedded_font(document, &font)?;
        fonts.push((format!("{prefix}{at}").into_bytes(), Value::Reference(id)));
        codes.push(
            glyphs
                .into_iter()
                .map(|(old, code, _)| (old.0, code))
                .collect(),
        );
    }
    Ok(FaceCodes {
        fonts,
        codes,
        prefix: prefix.to_owned(),
    })
}

/// Embedded faces: what [`embed_faces`] returns.
pub(crate) struct FaceCodes {
    /// The `/Font` entries.
    pub(crate) fonts: Vec<(Vec<u8>, Value)>,
    codes: Vec<HashMap<u32, Vec<u8>>>,
    prefix: String,
}

/// Writes `lines`' operators, offset by `origin`, in `faces`.
pub(crate) fn text_ops(ops: &mut Ops, faces: &FaceCodes, lines: &[SetLine], origin: (f32, f32)) {
    ops.op("BT");
    for line in lines {
        ops.fill_colour(line.color);
        let mut current = None;
        for glyph in &line.glyphs {
            if current != Some(glyph.face) {
                let _ = write!(ops.0, "/{}{} ", faces.prefix, glyph.face);
                ops.nums(&[line.size], "Tf");
                current = Some(glyph.face);
            }
            let Some(code) = faces
                .codes
                .get(glyph.face)
                .and_then(|map| map.get(&glyph.glyph.0))
            else {
                continue;
            };
            ops.nums(
                &[
                    1.0,
                    0.0,
                    0.0,
                    1.0,
                    origin.0 + line.x + glyph.x * line.size,
                    origin.1 + line.baseline + glyph.y * line.size,
                ],
                "Tm",
            );
            let hex: String = code.iter().map(|byte| format!("{byte:02X}")).collect();
            let _ = writeln!(ops.0, "<{hex}> Tj");
        }
    }
    ops.op("ET");
}

/// Writes `lines`' operators, offset by `origin`, with `faces` embedded as `/F0`, `/F1` and on:
/// each a subset of what the lines use. Returns the `/Font` resource.
fn set_text(
    document: &Document,
    revisions: &mut RevisionStore,
    ops: &mut Ops,
    faces: &Faces<'_>,
    lines: &[SetLine],
    origin: (f32, f32),
) -> Result<Value, OpsError> {
    let embedded = embed_faces(document, revisions, faces, "F")?;
    text_ops(ops, &embedded, lines, origin);
    Ok(Value::Dictionary(embedded.fonts))
}

/// The form holding `content`: its `/BBox` is `rect`, in user space.
fn form(
    document: &Document,
    revisions: &mut RevisionStore,
    rect: [f32; 4],
    content: Ops,
    state: Option<Value>,
    fonts: Option<Value>,
) -> Result<ObjectRef, OpsError> {
    let mut resources = Vec::new();
    if let Some(state) = state {
        resources.push((
            b"ExtGState".to_vec(),
            Value::Dictionary(vec![(b"GS0".to_vec(), state)]),
        ));
    }
    if let Some(fonts) = fonts {
        resources.push((b"Font".to_vec(), fonts));
    }
    let dict = vec![
        (b"Type".to_vec(), name(b"XObject")),
        (b"Subtype".to_vec(), name(b"Form")),
        (b"FormType".to_vec(), Value::Integer(1)),
        (b"BBox".to_vec(), numbers(rect)),
        (b"Resources".to_vec(), Value::Dictionary(resources)),
    ];
    Ok(revisions.add_object(
        document,
        Value::Stream {
            dict,
            data: content.0.into_bytes(),
        },
    )?)
}

/// The appearance of `annotation` on a page turned `turn` degrees, as a new form. Not for a stamp
/// or an unknown type, whose drawing is not Ferman's to make again.
fn appearance(
    document: &Document,
    revisions: &mut RevisionStore,
    annotation: &Annotation,
    turn: u16,
    library: Option<&FontLibrary>,
) -> Result<ObjectRef, OpsError> {
    let mut ops = Ops::default();
    let multiply = annotation.kind == AnnotationKind::Highlight;
    let state = state(annotation.opacity, multiply);
    ops.op("q");
    ops.nums(
        &[
            annotation.rect[0],
            annotation.rect[1],
            annotation.rect[2] - annotation.rect[0],
            annotation.rect[3] - annotation.rect[1],
        ],
        "re",
    )
    .op("W n");
    if state.is_some() {
        ops.op("/GS0 gs");
    }
    let mut fonts = None;
    match annotation.kind {
        AnnotationKind::Highlight => highlight(&mut ops, annotation),
        AnnotationKind::Underline => underline(&mut ops, annotation),
        AnnotationKind::StrikeOut => strike_out(&mut ops, annotation),
        AnnotationKind::Squiggly => squiggly(&mut ops, annotation),
        AnnotationKind::Note => note(&mut ops, annotation, turn),
        AnnotationKind::Ink => ink(&mut ops, annotation),
        AnnotationKind::Square => square(&mut ops, annotation),
        AnnotationKind::Circle => circle(&mut ops, annotation),
        AnnotationKind::Line => line(&mut ops, annotation),
        AnnotationKind::Polygon => polygon(&mut ops, annotation),
        AnnotationKind::FreeText | AnnotationKind::Callout => {
            leader(&mut ops, annotation);
            let paint = paint_shape(&mut ops, annotation);
            let [l, b, r, t] = stroked_box(annotation);
            ops.nums(&[l, b, r - l, t - b], "re").op(paint);
            let contents = annotation.contents.as_deref().unwrap_or_default();
            if !contents.trim().is_empty() {
                let library = library.ok_or(OpsError::NoFontForText)?;
                let (width, height) = upright(&mut ops, text_box(annotation), turn);
                let pad = TEXT_PADDING + annotation.stroke;
                let mut faces = Faces::new(library, 400);
                let lines = wrapped(
                    &mut faces,
                    contents,
                    (width - pad * 2.0, height - pad * 2.0),
                    annotation.font_size.unwrap_or(12.0),
                    annotation.text_color.unwrap_or_default(),
                )?;
                fonts = Some(set_text(
                    document,
                    revisions,
                    &mut ops,
                    &faces,
                    &lines,
                    (pad, pad),
                )?);
            }
        }
        AnnotationKind::Stamp | AnnotationKind::Other => return Err(plan_error()),
    }
    ops.op("Q");
    form(document, revisions, annotation.rect, ops, state, fonts)
}

/// A new stamp's form: `new.rect` is its box before its tilt, and the returned `/Rect` bounds it
/// tilted.
fn stamp_form(
    document: &Document,
    revisions: &mut RevisionStore,
    new: &NewAnnotation,
    turn: u16,
    library: &FontLibrary,
) -> Result<(ObjectRef, [f32; 4]), OpsError> {
    let [l, b, r, t] = normalized(new.rect);
    let (w, h) = if turn % 180 == 90 {
        (t - b, r - l)
    } else {
        (r - l, t - b)
    };
    let radians = (-new.tilt).to_radians();
    let (sin, cos) = radians.sin_cos();
    let reach_x = (w * cos.abs() + h * sin.abs()) / 2.0 + STAMP_OUTLINE_OFFSET + STAMP_OUTLINE;
    let reach_y = (w * sin.abs() + h * cos.abs()) / 2.0 + STAMP_OUTLINE_OFFSET + STAMP_OUTLINE;
    let (cx, cy) = (f32::midpoint(l, r), f32::midpoint(b, t));
    let (user_x, user_y) = if turn % 180 == 90 {
        (reach_y, reach_x)
    } else {
        (reach_x, reach_y)
    };
    let rect = [cx - user_x, cy - user_y, cx + user_x, cy + user_y];

    let mut ops = Ops::default();
    let state = state(STAMP_OPACITY, true);
    ops.op("q").op("/GS0 gs");
    let (seen_w, seen_h) = upright(&mut ops, rect, turn);
    ops.nums(&[cos, sin, -sin, cos, seen_w / 2.0, seen_h / 2.0], "cm");
    let ink = new.color;
    let box_area = [-w / 2.0, -h / 2.0, w / 2.0, h / 2.0];
    ops.stroke_colour(ink).nums(&[STAMP_BORDER], "w");
    let half = STAMP_BORDER / 2.0;
    ops.rounded(
        [
            box_area[0] + half,
            box_area[1] + half,
            box_area[2] - half,
            box_area[3] - half,
        ],
        STAMP_RADIUS,
    )
    .op("S");
    ops.nums(&[STAMP_OUTLINE], "w");
    let out = STAMP_OUTLINE_OFFSET + STAMP_OUTLINE / 2.0;
    ops.rounded(
        [
            box_area[0] - out,
            box_area[1] - out,
            box_area[2] + out,
            box_area[3] + out,
        ],
        STAMP_RADIUS + out,
    )
    .op("S");

    let size = new.font_size;
    let meta_size = size * STAMP_META_SIZE;
    let meta = new.meta.as_deref().filter(|meta| !meta.trim().is_empty());
    let gap = if meta.is_some() { 3.0 + meta_size } else { 0.0 };
    let block = size * 0.72 + gap;
    let mut lines = Vec::new();
    let mut faces = Faces::new(library, 600);
    let rtl = right_to_left(&new.label);
    let (glyphs, width) = faces.shape_line(settable(&new.label), rtl, STAMP_LABEL_SPACING)?;
    lines.push(SetLine {
        glyphs,
        x: -(width - STAMP_LABEL_SPACING) * size / 2.0,
        baseline: block / 2.0 - size * 0.72,
        size,
        color: ink,
    });
    if let Some(meta) = meta {
        let rtl = right_to_left(meta);
        let (glyphs, width) = faces.shape_line(settable(meta), rtl, STAMP_META_SPACING)?;
        lines.push(SetLine {
            glyphs,
            x: -(width - STAMP_META_SPACING) * meta_size / 2.0,
            baseline: -block / 2.0,
            size: meta_size,
            color: ink,
        });
    }
    let fonts = set_text(document, revisions, &mut ops, &faces, &lines, (0.0, 0.0))?;
    ops.op("Q");
    let form = form(document, revisions, rect, ops, state, Some(fonts))?;
    Ok((form, rect))
}

fn appearance_entry(form: ObjectRef) -> Value {
    Value::Dictionary(vec![(b"N".to_vec(), Value::Reference(form))])
}

/// The annotation model of a new one, for the generators.
fn drawn(new: &NewAnnotation, kind: AnnotationKind, page: usize) -> Annotation {
    let arrow = new.arrow || kind == AnnotationKind::Callout;
    let text_kind = matches!(kind, AnnotationKind::FreeText | AnnotationKind::Callout);
    Annotation {
        handle: 0,
        page,
        kind,
        subtype: String::new(),
        rect: normalized(new.rect),
        quads: Vec::new(),
        ink: Vec::new(),
        line: None,
        vertices: Vec::new(),
        callout: Vec::new(),
        line_ends: [
            if kind == AnnotationKind::Callout && arrow {
                LineEnd::OpenArrow
            } else {
                LineEnd::None
            },
            if kind == AnnotationKind::Line && arrow {
                LineEnd::OpenArrow
            } else {
                LineEnd::None
            },
        ],
        inset: [0.0; 4],
        color: Some(new.color),
        interior: None,
        opacity: new.opacity,
        stroke: new.stroke,
        dash: Vec::new(),
        font_size: text_kind.then_some(new.font_size),
        text_color: text_kind.then_some(new.color),
        rotation: 0,
        flags: 0,
        author: None,
        subject: None,
        contents: Some(new.contents.clone()),
        rich: false,
        grouped: false,
        created: None,
        modified: None,
        unique_name: None,
        icon: None,
        replies_to: None,
        thread: 0,
        state: None,
        state_model: None,
        resolved: None,
        has_appearance: false,
        mentions: Vec::new(),
    }
}

/// `/NM`: names the annotation among all others, in this file and a copy of it.
fn unique_name(id: ObjectRef, now: &str) -> Value {
    let digits: String = now.chars().filter(char::is_ascii_digit).collect();
    text_value(&format!("ferman-{digits}-{:x}", id.handle()))
}

/// The entries every annotation Ferman writes starts from.
fn common_entries(
    kind_subtype: &[u8],
    page: ObjectRef,
    id: ObjectRef,
    author: &str,
    now: &str,
) -> Vec<(Vec<u8>, Value)> {
    let date = Value::String(now.as_bytes().to_vec());
    vec![
        (b"Type".to_vec(), name(b"Annot")),
        (b"Subtype".to_vec(), name(kind_subtype)),
        (b"P".to_vec(), Value::Reference(page)),
        (b"NM".to_vec(), unique_name(id, now)),
        (b"T".to_vec(), text_value(author)),
        (b"M".to_vec(), date.clone()),
        (b"CreationDate".to_vec(), date),
    ]
}

/// Creates `new` on page `page` as a new object with its appearance, and returns its handle. `now`
/// is a PDF date; `library` the fonts for a text box, callout or stamp.
///
/// # Errors
///
/// [`WriteError::AnnotationPlan`] for a kind not created or a value out of range,
/// [`OpsError::NoFontForText`] for text no font here has, and the errors of the transaction.
pub fn create(
    document: &Document,
    revisions: &mut RevisionStore,
    page: usize,
    new: &NewAnnotation,
    now: &str,
    library: Option<&FontLibrary>,
) -> Result<u64, OpsError> {
    let kind = new.kind;
    if matches!(kind, AnnotationKind::Squiggly | AnnotationKind::Other) {
        return Err(plan_error());
    }
    check_coordinates(new.rect)?;
    check_points(&new.points)?;
    check_style(
        Some(new.color),
        Some(new.stroke),
        Some(new.opacity),
        matches!(
            kind,
            AnnotationKind::FreeText | AnnotationKind::Callout | AnnotationKind::Stamp
        )
        .then_some(new.font_size),
    )?;
    check_text(&new.contents)?;
    check_text(&new.label)?;
    check_text(&new.author)?;
    if !new.tilt.is_finite() {
        return Err(plan_error());
    }

    let turn = page_turn(document, revisions, page)?;
    let page_ref = revisions
        .page_refs(document, &[page])?
        .first()
        .copied()
        .ok_or_else(plan_error)?;
    let id = revisions.allocate()?;
    let mut entries = common_entries(kind.subtype(), page_ref, id, &new.author, now);
    let mut set = |key: &[u8], value: Value| entries.push((key.to_vec(), value));
    if !new.contents.is_empty() {
        set(b"Contents", text_value(&new.contents));
    }
    set(b"C", numbers(new.color));
    if let Some(icon) = &new.icon {
        set(b"Name", name(icon.as_bytes()));
    }

    let rect;
    let form;
    if kind == AnnotationKind::Stamp {
        let library = library.ok_or(OpsError::NoFontForText)?;
        let [l, b, r, t] = normalized(new.rect);
        if r - l <= 0.0 || t - b <= 0.0 || new.label.trim().is_empty() {
            return Err(plan_error());
        }
        let made = stamp_form(document, revisions, new, turn, library)?;
        form = made.0;
        rect = made.1;
        let tilt = i64::from(turn) - new.tilt.round() as i64;
        if tilt.rem_euclid(360) != 0 {
            set(b"Rotate", Value::Integer(tilt.rem_euclid(360)));
        }
        set(b"F", Value::Integer(PRINT));
    } else {
        let mut model = drawn(new, kind, page);
        match kind {
            AnnotationKind::Note
            | AnnotationKind::FreeText
            | AnnotationKind::Square
            | AnnotationKind::Circle => {
                let [l, b, r, t] = model.rect;
                if r - l <= 0.0 || t - b <= 0.0 {
                    return Err(plan_error());
                }
            }
            AnnotationKind::Callout => {
                let [l, b, r, t] = model.rect;
                if r - l <= 0.0 || t - b <= 0.0 {
                    return Err(plan_error());
                }
                set_geometry(&mut model, &new.points)?;
            }
            _ => set_geometry(&mut model, &new.points)?,
        }
        form = appearance(document, revisions, &model, turn, library)?;
        rect = model.rect;
        for (key, value) in geometry_entries(&model) {
            if let Some(value) = value {
                set(&key, value);
            }
        }
        if model.opacity < 1.0 {
            set(b"CA", Value::Real(model.opacity));
        }
        if matches!(
            kind,
            AnnotationKind::Ink
                | AnnotationKind::Square
                | AnnotationKind::Circle
                | AnnotationKind::Line
                | AnnotationKind::Polygon
                | AnnotationKind::FreeText
                | AnnotationKind::Callout
        ) {
            set(b"BS", border_style(&model));
        }
        if matches!(kind, AnnotationKind::FreeText | AnnotationKind::Callout) {
            set(b"DA", default_appearance(&model));
            if turn != 0 {
                set(b"Rotate", Value::Integer(i64::from(turn)));
            }
        }
        if kind == AnnotationKind::Callout {
            set(b"IT", name(b"FreeTextCallout"));
            set(b"LE", name(b"OpenArrow"));
        }
        if kind == AnnotationKind::Line && new.arrow {
            set(b"LE", Value::Array(vec![name(b"None"), name(b"OpenArrow")]));
        }
        // Not NoRotate on a note: its appearance is upright already, and a reader would turn it
        // about its corner, away from where the pin was put.
        set(b"F", Value::Integer(PRINT));
    }
    set(b"Rect", numbers(rect));
    set(b"AP", appearance_entry(form));
    revisions.replace_object(document, id, Value::Dictionary(entries))?;
    revisions.append_annotation(document, page, id)?;
    Ok(id.handle())
}

// shortcut: an operation reads the whole list to find one annotation; keep an index by handle if a
// file with very many makes commits slow (decision 16 measures on `long-500`).
fn find(
    document: &Document,
    revisions: &RevisionStore,
    handle: u64,
) -> Result<(Annotation, Vec<Annotation>), OpsError> {
    let list = revisions.annotations(document).annotations;
    let annotation = list
        .iter()
        .find(|annotation| annotation.handle == handle)
        .cloned()
        .ok_or_else(missing)?;
    Ok((annotation, list))
}

/// Applies `change` to annotation `handle`, and returns its handle, new for one that was written
/// directly in `/Annots`. Only the keys that change are written; the appearance is made again only
/// if what it draws changes. A stamp takes a new box and text, an unknown type text only.
///
/// # Errors
///
/// [`WriteError::NoSuchAnnotation`], [`WriteError::AnnotationPlan`] for a change its kind cannot
/// take or a value out of range, [`OpsError::NoFontForText`], and the errors of the transaction.
pub fn update(
    document: &Document,
    revisions: &mut RevisionStore,
    handle: u64,
    change: &AnnotationChange,
    now: &str,
    library: Option<&FontLibrary>,
) -> Result<u64, OpsError> {
    if let Some(rect) = change.rect {
        check_coordinates(rect)?;
    }
    if let Some(points) = &change.points {
        check_points(points)?;
    }
    check_style(
        change.color,
        change.stroke,
        change.opacity,
        change.font_size,
    )?;
    if let Some(contents) = &change.contents {
        check_text(contents)?;
    }
    let (annotation, _) = find(document, revisions, handle)?;
    let styled = change.color.is_some()
        || change.stroke.is_some()
        || change.opacity.is_some()
        || change.font_size.is_some();
    let takes_geometry = !matches!(annotation.kind, AnnotationKind::Other);
    let draws_itself = !matches!(
        annotation.kind,
        AnnotationKind::Other | AnnotationKind::Stamp
    );
    if (styled && !draws_itself)
        || (change.points.is_some() && !draws_itself)
        || (change.rect.is_some() && !takes_geometry)
    {
        return Err(plan_error());
    }

    let mut next = annotation.clone();
    let mut entries: Vec<(Vec<u8>, Option<Value>)> =
        vec![(b"M".to_vec(), Some(Value::String(now.as_bytes().to_vec())))];
    let text_kind = matches!(
        annotation.kind,
        AnnotationKind::FreeText | AnnotationKind::Callout
    );
    if let Some(contents) = &change.contents
        && annotation.contents.as_deref() != Some(contents)
    {
        entries.push((b"Contents".to_vec(), Some(text_value(contents))));
        if annotation.rich {
            entries.push((b"RC".to_vec(), None));
        }
        next.contents = Some(contents.clone());
    }
    if let Some(color) = change.color {
        if annotation.text_color == annotation.color && text_kind {
            next.text_color = Some(color);
        }
        next.color = Some(color);
        entries.push((b"C".to_vec(), Some(numbers(color))));
    }
    if let Some(stroke) = change.stroke {
        next.stroke = stroke;
        entries.push((b"BS".to_vec(), Some(border_style(&next))));
    }
    if let Some(opacity) = change.opacity {
        next.opacity = opacity;
        entries.push((b"CA".to_vec(), Some(Value::Real(opacity))));
    }
    if let Some(size) = change.font_size {
        if !text_kind {
            return Err(plan_error());
        }
        next.font_size = Some(size);
    }
    if text_kind && (change.font_size.is_some() || next.text_color != annotation.text_color) {
        entries.push((b"DA".to_vec(), Some(default_appearance(&next))));
    }

    let mut moved = false;
    if let Some(rect) = change.rect {
        map_geometry(&mut next, normalized(rect));
    }
    if let Some(points) = &change.points {
        set_geometry(&mut next, points)?;
    }
    let resized = (next.rect[2] - next.rect[0] - annotation.rect[2] + annotation.rect[0]).abs()
        > SAME_SIZE
        || (next.rect[3] - next.rect[1] - annotation.rect[3] + annotation.rect[1]).abs()
            > SAME_SIZE
        || change.points.is_some();
    if next.rect != annotation.rect || change.points.is_some() {
        moved = true;
        entries.extend(geometry_entries(&next));
    }

    let text_changed = text_kind && next.contents != annotation.contents;
    let redraw = draws_itself
        && (styled || text_changed || (moved && resized) || (moved && !annotation.has_appearance));
    if redraw {
        let turn = page_turn(document, revisions, annotation.page)?;
        let form = appearance(document, revisions, &next, turn, library)?;
        entries.push((b"AP".to_vec(), Some(appearance_entry(form))));
    }
    let object = revisions.change_annotation(document, annotation.page, handle, entries)?;
    Ok(object.handle())
}

/// Deletes annotation `handle` with its popup and every reply below it, as one step.
///
/// # Errors
///
/// [`WriteError::NoSuchAnnotation`] and the errors of the transaction.
pub fn delete(
    document: &Document,
    revisions: &mut RevisionStore,
    handle: u64,
) -> Result<(), OpsError> {
    let (_, list) = find(document, revisions, handle)?;
    let mut gone = BTreeSet::from([handle]);
    loop {
        let before = gone.len();
        for annotation in &list {
            if annotation.replies_to.is_some_and(|top| gone.contains(&top)) {
                gone.insert(annotation.handle);
            }
        }
        if gone.len() == before {
            break;
        }
    }
    // Last first: a direct annotation's handle is its place among those before it.
    for annotation in list.iter().rev() {
        if gone.contains(&annotation.handle) {
            revisions.drop_annotation(document, annotation.page, annotation.handle)?;
        }
    }
    Ok(())
}

/// Draws annotations `handles` into their pages' content and takes them, their replies and popups
/// out, as one step (a4-5b). A reply carries no mark, so it goes undrawn, whatever a program gave
/// it; one of a group (`/RT /Group`) is a mark. One with no appearance gets Ferman's first, when it
/// would be drawn; a stamp or an unknown type with none has nothing to draw and stays as it came.
/// Form widgets go straight to [`RevisionStore::flatten_annotations`]. A handle not listed is
/// skipped.
///
/// # Errors
///
/// [`OpsError::NoFontForText`], and the errors of the transaction.
pub fn flatten(
    document: &Document,
    revisions: &mut RevisionStore,
    handles: &[u64],
    library: Option<&FontLibrary>,
) -> Result<(), OpsError> {
    const NOT_DRAWN: u32 = 2 | 32;
    let list = revisions.annotations(document).annotations;
    let mut chosen: BTreeSet<u64> = handles.iter().copied().collect();
    loop {
        let before = chosen.len();
        for annotation in &list {
            if annotation
                .replies_to
                .is_some_and(|top| chosen.contains(&top))
            {
                chosen.insert(annotation.handle);
            }
        }
        if chosen.len() == before {
            break;
        }
    }
    let mut pages: BTreeMap<usize, (Vec<u64>, Vec<u64>)> = BTreeMap::new();
    // Last first, each given its object: a direct annotation's handle is its place among those
    // before it, which giving an earlier one an object would change.
    for annotation in list.iter().rev() {
        if !chosen.contains(&annotation.handle) {
            continue;
        }
        let reply = annotation.replies_to.is_some() && !annotation.grouped;
        let drawn = annotation.flags & NOT_DRAWN == 0;
        let needs_appearance = !reply && drawn && !annotation.has_appearance;
        if needs_appearance
            && matches!(
                annotation.kind,
                AnnotationKind::Stamp | AnnotationKind::Other
            )
        {
            continue;
        }
        let object = revisions.annotation_object(document, annotation.page, annotation.handle)?;
        let handle = object.handle();
        if needs_appearance {
            let turn = page_turn(document, revisions, annotation.page)?;
            let form = appearance(document, revisions, annotation, turn, library)?;
            revisions.change_annotation(
                document,
                annotation.page,
                handle,
                vec![(b"AP".to_vec(), Some(appearance_entry(form)))],
            )?;
        }
        let (to_draw, undrawn) = pages.entry(annotation.page).or_default();
        if reply { undrawn } else { to_draw }.push(handle);
    }
    for (page, (to_draw, undrawn)) in pages {
        revisions.flatten_annotations(document, page, &to_draw, &undrawn)?;
    }
    Ok(())
}

/// Adds a reply or state reply under `handle`'s thread: a `/Text` annotation on its rectangle
/// with `extra` that draws nothing of its own, so no reader puts an icon over the mark.
fn add_reply(
    document: &Document,
    revisions: &mut RevisionStore,
    handle: u64,
    author: &str,
    now: &str,
    extra: Vec<(Vec<u8>, Value)>,
) -> Result<u64, OpsError> {
    check_text(author)?;
    let (annotation, list) = find(document, revisions, handle)?;
    let top = list
        .iter()
        .find(|other| other.handle == annotation.thread)
        .unwrap_or(&annotation);
    let parent = revisions.annotation_object(document, top.page, top.handle)?;
    let page_ref = revisions
        .page_refs(document, &[top.page])?
        .first()
        .copied()
        .ok_or_else(plan_error)?;
    let id = revisions.allocate()?;
    let empty = form(document, revisions, top.rect, Ops::default(), None, None)?;
    let mut entries = common_entries(b"Text", page_ref, id, author, now);
    entries.push((b"Rect".to_vec(), numbers(top.rect)));
    entries.push((b"IRT".to_vec(), Value::Reference(parent)));
    entries.push((b"Name".to_vec(), name(b"Comment")));
    entries.push((b"AP".to_vec(), appearance_entry(empty)));
    entries.extend(extra);
    revisions.replace_object(document, id, Value::Dictionary(entries))?;
    revisions.append_annotation(document, top.page, id)?;
    Ok(id.handle())
}

/// Replies to `handle` as `author`; a reply to a reply joins the thread. Mentions are names in the
/// text and travel with it: nothing is sent to anyone.
///
/// # Errors
///
/// As [`update`].
pub fn reply(
    document: &Document,
    revisions: &mut RevisionStore,
    handle: u64,
    author: &str,
    text: &str,
    now: &str,
) -> Result<u64, OpsError> {
    check_text(text)?;
    add_reply(
        document,
        revisions,
        handle,
        author,
        now,
        vec![
            (b"RT".to_vec(), name(b"R")),
            (b"Contents".to_vec(), text_value(text)),
            (b"F".to_vec(), Value::Integer(REPLY_FLAGS)),
        ],
    )
}

/// `date` as a PDF date, which reads back as the same moment.
fn date_text(date: PdfDate) -> String {
    let zone = match date.offset_minutes {
        None => String::new(),
        Some(0) => "Z".to_owned(),
        Some(minutes) => {
            let sign = if minutes < 0 { '-' } else { '+' };
            let minutes = minutes.unsigned_abs();
            format!("{sign}{:02}'{:02}'", minutes / 60, minutes % 60)
        }
    };
    format!(
        "D:{:04}{:02}{:02}{:02}{:02}{:02}{zone}",
        date.year, date.month, date.day, date.hour, date.minute, date.second
    )
}

/// Resolves or reopens `handle`'s thread as `author` (decision 9): a state reply with
/// `/StateModel /Review`, `Completed` or `None`, so other readers see it. A thread already so
/// writes nothing.
///
/// # Errors
///
/// As [`update`].
pub fn set_resolved(
    document: &Document,
    revisions: &mut RevisionStore,
    handle: u64,
    author: &str,
    resolved: bool,
    now: &str,
) -> Result<(), OpsError> {
    let (annotation, list) = find(document, revisions, handle)?;
    let top = list
        .iter()
        .find(|other| other.handle == annotation.thread)
        .unwrap_or(&annotation);
    if top.resolved.is_some() == resolved {
        return Ok(());
    }
    let state = if resolved { "Completed" } else { "None" };
    // The newest state counts and a later entry wins a tie, so a state dated after now (a clock
    // ahead, or a date with no offset) must not outlive this one.
    let newest = list
        .iter()
        .filter(|other| {
            other.thread == top.handle
                && other.replies_to.is_some()
                && other.state.is_some()
                && other.state_model.as_deref().unwrap_or("Review") == "Review"
        })
        .filter_map(|other| other.modified)
        .max_by_key(instant)
        .filter(|date| PdfDate::parse(now).is_some_and(|now| instant(date) > instant(&now)));
    let date = newest.map_or_else(|| now.to_owned(), date_text);
    add_reply(
        document,
        revisions,
        handle,
        author,
        &date,
        vec![
            (b"State".to_vec(), text_value(state)),
            (b"StateModel".to_vec(), text_value("Review")),
            (b"F".to_vec(), Value::Integer(STATE_FLAGS)),
        ],
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use std::sync::Arc;

    use ferman_core::{OpenOptions, Source, open};

    use super::*;

    const NOW: &str = "D:20261106120000Z";

    fn foreign() -> (Document, RevisionStore) {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated/annots-other-producer.pdf");
        let bytes = std::fs::read(path).unwrap();
        let doc = open(
            &Source::from_bytes(Arc::from(&bytes[..])),
            &OpenOptions::default(),
        )
        .unwrap();
        let store = RevisionStore::new(&doc);
        (doc, store)
    }

    fn pick(
        doc: &Document,
        store: &RevisionStore,
        wanted: impl Fn(&Annotation) -> bool,
    ) -> Annotation {
        store
            .annotations(doc)
            .annotations
            .into_iter()
            .find(|annotation| wanted(annotation))
            .unwrap()
    }

    /// What `store` adds to the file, for looking for what was written.
    fn written(doc: &Document, base: &RevisionStore, store: &RevisionStore) -> Vec<u8> {
        let before = base.incremental_update(doc).unwrap().len();
        store.incremental_update(doc).unwrap().split_off(before)
    }

    fn has(bytes: &[u8], needle: &[u8]) -> bool {
        bytes.windows(needle.len()).any(|window| window == needle)
    }

    #[test]
    fn a_fractional_move_keeps_every_appearance() {
        let (doc, base) = foreign();
        let list = base.annotations(&doc).annotations;
        let drawn: Vec<&Annotation> = list
            .iter()
            .filter(|a| {
                a.has_appearance && a.replies_to.is_none() && a.kind != AnnotationKind::Other
            })
            .collect();
        assert!(drawn.len() > 5);
        for annotation in drawn {
            // A hundred shifts: rounding gives some of them a width a few 1e-5 off.
            for step in 0u16..100 {
                let shift = 0.37 + f32::from(step) * 0.613;
                let [left, bottom, right, top] = annotation.rect;
                let mut store = base.clone();
                store.begin().unwrap();
                let change = AnnotationChange {
                    rect: Some([left + shift, bottom - shift, right + shift, top - shift]),
                    ..AnnotationChange::default()
                };
                // No library: a drawing made again would ask for one.
                update(&doc, &mut store, annotation.handle, &change, NOW, None).unwrap();
                store.commit().unwrap();
                let after = pick(&doc, &store, |a| a.handle == annotation.handle);
                assert_eq!(after.rich, annotation.rich);
                assert!(
                    !has(&written(&doc, &base, &store), b"BBox"),
                    "{:?} moved by {shift} got a new drawing",
                    annotation.kind
                );
            }
        }
    }

    #[test]
    fn a_reply_is_flattened_away_undrawn_and_a_group_member_is_drawn() {
        let (doc, base) = foreign();
        let reply = pick(&doc, &base, |a| a.replies_to.is_some() && a.state.is_none());
        let top = reply.replies_to.unwrap();
        let mut store = base.clone();
        store.begin().unwrap();
        flatten(&doc, &mut store, &[top], None).unwrap();
        store.commit().unwrap();
        assert!(
            store
                .annotations(&doc)
                .annotations
                .iter()
                .all(|a| a.handle != reply.handle && a.handle != top)
        );
        let bytes = written(&doc, &base, &store);
        assert!(has(&bytes, b"FmFlat0"));
        assert!(!has(&bytes, b"FmFlat1"), "a reply was drawn");

        // The same reply as a member of a group is a mark of its own.
        let mut store = base.clone();
        store.begin().unwrap();
        store
            .change_annotation(
                &doc,
                reply.page,
                reply.handle,
                vec![(b"RT".to_vec(), Some(name(b"Group")))],
            )
            .unwrap();
        store.commit().unwrap();
        store.begin().unwrap();
        flatten(&doc, &mut store, &[top], None).unwrap();
        store.commit().unwrap();
        assert!(
            has(&written(&doc, &base, &store), b"FmFlat1"),
            "a mark was lost"
        );
    }

    #[test]
    fn a_popup_entry_that_names_another_comment_does_not_take_it_along() {
        let (doc, base) = foreign();
        let list = base.annotations(&doc).annotations;
        let mut tops = list.iter().filter(|a| {
            a.page == 0 && a.replies_to.is_none() && a.kind == AnnotationKind::Highlight
        });
        let (first, other) = (tops.next().unwrap(), tops.next().unwrap());
        let mut prepared = base.clone();
        prepared.begin().unwrap();
        let target = prepared
            .annotation_object(&doc, other.page, other.handle)
            .unwrap();
        prepared
            .change_annotation(
                &doc,
                first.page,
                first.handle,
                vec![(b"Popup".to_vec(), Some(Value::Reference(target)))],
            )
            .unwrap();
        prepared.commit().unwrap();
        let there = |store: &RevisionStore, handle| {
            store
                .annotations(&doc)
                .annotations
                .iter()
                .any(|a| a.handle == handle)
        };

        let mut store = prepared.clone();
        store.begin().unwrap();
        delete(&doc, &mut store, first.handle).unwrap();
        store.commit().unwrap();
        assert!(!there(&store, first.handle));
        assert!(there(&store, other.handle), "delete took the other along");

        let mut store = prepared.clone();
        store.begin().unwrap();
        flatten(&doc, &mut store, &[first.handle], None).unwrap();
        store.commit().unwrap();
        assert!(!there(&store, first.handle));
        assert!(there(&store, other.handle), "flatten took the other along");
    }

    #[test]
    fn a_state_dated_ahead_does_not_outlive_a_reopen() {
        let (doc, mut store) = foreign();
        let note = pick(&doc, &store, |a| a.resolved.is_some());
        let state = pick(&doc, &store, |a| {
            a.thread == note.handle && a.state.as_deref() == Some("Completed")
        });
        for date in [
            "D:20991013150000",
            "D:20991013150000+03'00'",
            "D:20991013150000Z",
        ] {
            let mut store = store.clone();
            store.begin().unwrap();
            store
                .change_annotation(
                    &doc,
                    state.page,
                    state.handle,
                    vec![(b"M".to_vec(), Some(text_value(date)))],
                )
                .unwrap();
            store.commit().unwrap();
            store.begin().unwrap();
            set_resolved(&doc, &mut store, note.handle, "Elif", false, NOW).unwrap();
            store.commit().unwrap();
            let after = pick(&doc, &store, |a| a.handle == note.handle);
            assert!(after.resolved.is_none(), "{date}");
        }
        // With no such date the reply says now.
        store.begin().unwrap();
        set_resolved(&doc, &mut store, note.handle, "Elif", false, NOW).unwrap();
        store.commit().unwrap();
        let reopened = pick(&doc, &store, |a| {
            a.thread == note.handle && a.author.as_deref() == Some("Elif")
        });
        assert_eq!(reopened.modified.unwrap().year, 2026);
    }

    #[test]
    fn a_text_edit_makes_no_appearance_for_a_kind_that_does_not_draw_its_text() {
        let (doc, mut store) = foreign();
        let bare = pick(&doc, &store, |a| {
            a.kind == AnnotationKind::Highlight && !a.has_appearance
        });
        store.begin().unwrap();
        let change = AnnotationChange {
            contents: Some("Yeni".to_owned()),
            ..AnnotationChange::default()
        };
        update(&doc, &mut store, bare.handle, &change, NOW, None).unwrap();
        store.commit().unwrap();
        let after = pick(&doc, &store, |a| a.handle == bare.handle);
        assert!(!after.has_appearance);
        assert_eq!(after.contents.as_deref(), Some("Yeni"));
        assert_eq!(after.quads, bare.quads);
        assert_eq!(after.modified.unwrap().year, 2026);
    }

    #[test]
    fn a_style_change_draws_every_kind_with_a_generator() {
        let (doc, mut store) = foreign();
        for kind in [
            AnnotationKind::Highlight,
            AnnotationKind::Squiggly,
            AnnotationKind::Underline,
            AnnotationKind::StrikeOut,
            AnnotationKind::Ink,
            AnnotationKind::Square,
            AnnotationKind::Circle,
            AnnotationKind::Line,
            AnnotationKind::Polygon,
            AnnotationKind::Note,
        ] {
            let any = pick(&doc, &store, |a| a.kind == kind && a.replies_to.is_none());
            store.begin().unwrap();
            let change = AnnotationChange {
                color: Some([0.1, 0.2, 0.3]),
                ..AnnotationChange::default()
            };
            update(&doc, &mut store, any.handle, &change, NOW, None).unwrap();
            store.commit().unwrap();
            let after = pick(&doc, &store, |a| a.handle == any.handle);
            assert!(after.has_appearance, "{kind:?}");
            assert_eq!(after.rich, any.rich, "{kind:?}");
        }
    }

    #[test]
    fn a_stamp_and_an_unknown_type_keep_their_drawing() {
        let (doc, mut store) = foreign();
        let stamp = pick(&doc, &store, |a| a.kind == AnnotationKind::Stamp);
        let other = pick(&doc, &store, |a| a.subtype == "ACME_Mark");
        store.begin().unwrap();
        let color = AnnotationChange {
            color: Some([0.0; 3]),
            ..AnnotationChange::default()
        };
        let moved = AnnotationChange {
            rect: Some([10.0, 10.0, 50.0, 50.0]),
            ..AnnotationChange::default()
        };
        for handle in [stamp.handle, other.handle] {
            assert!(update(&doc, &mut store, handle, &color, NOW, None).is_err());
        }
        assert!(update(&doc, &mut store, other.handle, &moved, NOW, None).is_err());
        assert!(update(&doc, &mut store, stamp.handle, &moved, NOW, None).is_ok());
    }

    #[test]
    fn values_out_of_range_and_kinds_not_created_are_refused() {
        let (doc, mut store) = foreign();
        store.begin().unwrap();
        let new = NewAnnotation {
            kind: AnnotationKind::Square,
            rect: [10.0, 10.0, 50.0, 50.0],
            points: Vec::new(),
            color: [0.0; 3],
            stroke: 1.0,
            opacity: 1.0,
            contents: String::new(),
            author: String::new(),
            font_size: 12.0,
            arrow: false,
            label: String::new(),
            meta: None,
            tilt: 0.0,
            icon: None,
        };
        let refused = |new: NewAnnotation, store: &mut RevisionStore| {
            matches!(
                create(&doc, store, 0, &new, NOW, None),
                Err(OpsError::Core(CoreError::Write(WriteError::AnnotationPlan)))
            )
        };
        for bad in [
            NewAnnotation {
                kind: AnnotationKind::Squiggly,
                ..new.clone()
            },
            NewAnnotation {
                kind: AnnotationKind::Other,
                ..new.clone()
            },
            NewAnnotation {
                rect: [f32::NAN, 0.0, 1.0, 1.0],
                ..new.clone()
            },
            NewAnnotation {
                rect: [5.0, 5.0, 5.0, 5.0],
                ..new.clone()
            },
            NewAnnotation {
                stroke: -1.0,
                ..new.clone()
            },
            NewAnnotation {
                opacity: 2.0,
                ..new.clone()
            },
            NewAnnotation {
                kind: AnnotationKind::Highlight,
                points: vec![vec![[0.0, 0.0]; 3]],
                ..new.clone()
            },
            NewAnnotation {
                kind: AnnotationKind::Polygon,
                points: vec![vec![[0.0, 0.0]; 2]],
                ..new.clone()
            },
        ] {
            assert!(refused(bad, &mut store));
        }
        assert!(create(&doc, &mut store, 0, &new, NOW, None).is_ok());
        let text = NewAnnotation {
            kind: AnnotationKind::FreeText,
            contents: "a".to_owned(),
            ..new
        };
        assert!(matches!(
            create(&doc, &mut store, 0, &text, NOW, None),
            Err(OpsError::NoFontForText)
        ));
    }
}
