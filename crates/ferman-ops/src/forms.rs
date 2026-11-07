//! Form filling (M4 plan, W3, decisions 17 to 20): what setting a value writes, the appearance each
//! widget gets, validation from what a field declares, and Clear and Finish.
//!
//! Only what a change touches is written: the field's nodes and its widgets, with `/XFA` leaving
//! `/AcroForm` on the first change (question 12). A text field's appearance is a new form per
//! widget, its text in the field's own font when that can draw it, otherwise in bundled IBM Plex
//! (Serif for a serif field) embedded into `/AcroForm /DR` under a11-1c's policy (decision 18).
//! Scripts never run. A check box or radio button whose appearance has the state just changes
//! `/AS`.

use std::fmt::Write as _;

use ferman_core::Document;
use ferman_core::forms::{DeclaredFormat, Field, FieldKind, FormFields, Widget};
use ferman_core::revision::RevisionStore;
use ferman_core::write::{ObjectRef, Value, text_value};
use ferman_fonts::FontLibrary;
use ferman_text::field::FieldFont;
use ferman_text::{Break, breaks};

use crate::OpsError;
use crate::annotations::{
    Faces, LINE_HEIGHT, Ops, SetLine, embed_faces, name, numbers, plan_error, right_to_left,
    text_ops,
};

/// The most bytes of a value an appearance sets.
const MOST_SET_TEXT: usize = 32 * 1024;
/// The most bytes of all the values one Finish or Clear sets appearances for: a hostile file's
/// many long values stop here, and what is past it draws nothing, as it drew nothing before.
const MOST_SET_TOTAL: usize = 4 * 1024 * 1024;
/// The largest value kept.
const MOST_VALUE: usize = 1024 * 1024;
/// A font size chosen for a field that asks for automatic, at most.
const LARGEST_AUTO: f32 = 12.0;
/// And at least.
const SMALLEST_AUTO: f32 = 4.0;
/// A list box's selected row.
const SELECTED: [f32; 3] = [0.6, 0.75, 0.85];
/// A single line's ascent and descent per unit of font size, for centring it.
const ASCENT: f32 = 0.75;
const DESCENT: f32 = -0.25;

/// What to do when a value has characters its field's font cannot draw (a11-1c, decision 18).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum MissingFont {
    /// Bundled Plex, and the caller says so once.
    #[default]
    Bundled,
    /// Fail with [`OpsError::FontChoiceNeeded`], writing nothing.
    Ask,
    /// Keep the field's font: what it cannot draw is left out, and the field is marked.
    Keep,
}

/// What a value's commit did besides the value.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Filled {
    /// The bundled or installed families it drew in, for "says so" (decision 18).
    pub fonts: Vec<String>,
    /// Characters were left out under [`MissingFont::Keep`].
    pub marked: bool,
    /// `/XFA` left the form (question 12).
    pub xfa_removed: bool,
}

/// Why a value does not meet what its field declares (decision 17).
#[derive(Debug, Clone, PartialEq)]
pub enum FieldProblem {
    /// Past `/MaxLen`.
    TooLong {
        /// `/MaxLen`.
        max: u32,
    },
    /// Not a date in the pattern the field declares.
    NotADate {
        /// The pattern.
        pattern: String,
    },
    /// Not a number in the style the field declares.
    NotANumber,
    /// Outside `AFRange_Validate`'s range.
    OutOfRange {
        /// The least value.
        min: Option<f64>,
        /// The greatest value.
        max: Option<f64>,
    },
}

/// How `value` fails `field`'s declarations, if it does. An empty value fails nothing: that is the
/// required count's business.
#[must_use]
pub fn problem(field: &Field, value: &str) -> Option<FieldProblem> {
    if value.is_empty() || field.kind != FieldKind::Text {
        return None;
    }
    if let Some(max) = field.max_len
        && value.chars().count() > usize::try_from(max).unwrap_or(usize::MAX)
    {
        return Some(FieldProblem::TooLong { max });
    }
    let number = match &field.declared.format {
        Some(DeclaredFormat::Date(pattern)) => {
            return (!is_date(value, pattern)).then(|| FieldProblem::NotADate {
                pattern: pattern.clone(),
            });
        }
        Some(
            DeclaredFormat::Number { separators, .. } | DeclaredFormat::Percent { separators, .. },
        ) => parse_number(value.trim().trim_end_matches('%').trim_end(), *separators),
        None => parse_number(value.trim(), 1),
    };
    let declares_number = field.declared.format.is_some();
    let ranged = field.declared.min.is_some() || field.declared.max.is_some();
    let Some(number) = number else {
        return (declares_number || ranged).then_some(FieldProblem::NotANumber);
    };
    let (min, max) = (field.declared.min, field.declared.max);
    (min.is_some_and(|min| number < min) || max.is_some_and(|max| number > max))
        .then_some(FieldProblem::OutOfRange { min, max })
}

/// `text` as a number in `AFNumber`'s separator style: 0 `1,234.56`, 1 `1234.56`, 2 `1.234,56`,
/// 3 `1234,56`, 4 `1'234.56`. Group separators are optional.
fn parse_number(text: &str, style: i32) -> Option<f64> {
    let (group, decimal) = match style {
        0 => (Some(','), '.'),
        2 => (Some('.'), ','),
        3 => (None, ','),
        4 => (Some('\''), '.'),
        _ => (None, '.'),
    };
    let mut plain = String::new();
    let mut digits = 0usize;
    for (at, c) in text.char_indices() {
        match c {
            '-' | '+' if at == 0 => plain.push(c),
            '0'..='9' => {
                digits += 1;
                plain.push(c);
            }
            c if c == decimal => plain.push('.'),
            c if Some(c) == group => {}
            _ => return None,
        }
    }
    if digits == 0 {
        return None;
    }
    plain.parse::<f64>().ok().filter(|value| value.is_finite())
}

/// English month names, as `AFDate` patterns' `mmm` and `mmmm` read them.
const MONTHS: [&str; 12] = [
    "january",
    "february",
    "march",
    "april",
    "may",
    "june",
    "july",
    "august",
    "september",
    "october",
    "november",
    "december",
];

/// Whether `text` is a date in the `AFDate` `pattern`, each part in range for the month and year
/// it names (a year of `yy` counts as in this century's 20xx).
fn is_date(text: &str, pattern: &str) -> bool {
    let (mut day, mut month, mut year) = (None, None, 2000u32);
    let source: Vec<char> = pattern.chars().collect();
    let chars: Vec<char> = text.trim().chars().collect();
    let (mut at, mut from) = (0usize, 0usize);
    while let Some(&c) = source.get(at) {
        let run = source
            .get(at..)
            .unwrap_or_default()
            .iter()
            .take_while(|&&next| next == c)
            .count();
        at += run;
        // Numbers: one or two digits for a single letter, exactly that many otherwise.
        let mut digits = |least: usize, most: usize| -> Option<u32> {
            let found = chars
                .get(from..)
                .unwrap_or_default()
                .iter()
                .take(most)
                .take_while(|c| c.is_ascii_digit())
                .count();
            if found < least {
                return None;
            }
            let value = chars
                .get(from..from + found)?
                .iter()
                .try_fold(0u32, |sum, c| Some(sum * 10 + c.to_digit(10)?));
            from += found;
            value
        };
        let good = match (c, run) {
            ('d', 1) => digits(1, 2).inspect(|value| day = Some(*value)).is_some(),
            ('d', 2) => digits(2, 2).inspect(|value| day = Some(*value)).is_some(),
            ('m', 1) => digits(1, 2).inspect(|value| month = Some(*value)).is_some(),
            ('m', 2) => digits(2, 2).inspect(|value| month = Some(*value)).is_some(),
            ('m', 3 | 4) => {
                let word: String = chars
                    .get(from..)
                    .unwrap_or_default()
                    .iter()
                    .take_while(|c| c.is_alphabetic())
                    .flat_map(|c| c.to_lowercase())
                    .collect();
                let known = MONTHS.iter().position(|name| {
                    if run == 3 {
                        word.len() == 3 && name.starts_with(&word)
                    } else {
                        *name == word
                    }
                });
                from += word.chars().count();
                known
                    .inspect(|known| month = u32::try_from(known + 1).ok())
                    .is_some()
            }
            ('y', 2) => digits(2, 2).inspect(|value| year = 2000 + *value).is_some(),
            ('y', 4) => digits(4, 4).inspect(|value| year = *value).is_some(),
            ('H' | 'h' | 'M' | 's', 1) => digits(1, 2).is_some_and(|value| value < 60),
            ('H' | 'h' | 'M' | 's', 2) => digits(2, 2).is_some_and(|value| value < 60),
            ('t', _) => {
                let word: String = chars
                    .get(from..)
                    .unwrap_or_default()
                    .iter()
                    .take(2)
                    .flat_map(|c| c.to_lowercase())
                    .collect();
                from += word.chars().count();
                word == "am" || word == "pm"
            }
            _ => {
                let same = chars
                    .get(from..from + run)
                    .is_some_and(|part| part.iter().all(|next| *next == c));
                from += run;
                same
            }
        };
        if !good {
            return false;
        }
    }
    if from != chars.len() {
        return false;
    }
    let month_good = month.is_none_or(|month| (1..=12).contains(&month));
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    let longest = match month {
        Some(4 | 6 | 9 | 11) => 30,
        Some(2) if leap => 29,
        Some(2) => 28,
        _ => 31,
    };
    month_good && day.is_none_or(|day| (1..=longest).contains(&day))
}

/// The required fields of `list` and those still to fill: read-only ones cannot be filled by the
/// user, so they do not count (a5-1's "13 required left").
#[must_use]
pub fn required_count(list: &FormFields) -> (u32, u32) {
    let (mut required, mut left) = (0u32, 0u32);
    for field in list.fields.iter().filter(|f| f.required && !f.read_only) {
        required = required.saturating_add(1);
        if !field.filled() {
            left = left.saturating_add(1);
        }
    }
    (required, left)
}

/// What a change of fields is set with, and what it did.
struct Setting<'a> {
    library: &'a FontLibrary,
    missing: MissingFont,
    filled: Filled,
}

/// What draws a field's text.
enum Painter<'a> {
    /// The field's own font.
    Own {
        name: Vec<u8>,
        value: Value,
        font: FieldFont,
    },
    /// Fonts embedded for it.
    Faces(Box<Faces<'a>>),
}

impl Painter<'_> {
    fn measure(&mut self, text: &str, rtl: bool) -> Result<f32, OpsError> {
        match self {
            Painter::Own { font, .. } => Ok(text
                .chars()
                .filter_map(|c| font.code(c))
                .map(|(_, width)| width)
                .sum()),
            Painter::Faces(faces) => faces.measure(text, rtl),
        }
    }
}

/// A form's text as it builds: a run of own-font operators, or lines for embedded faces.
struct Drawn<'a> {
    painter: Painter<'a>,
    own: Ops,
    lines: Vec<SetLine>,
}

impl Drawn<'_> {
    /// `text` with its left edge at `x`, baseline at `y`.
    fn line(
        &mut self,
        text: &str,
        (x, y): (f32, f32),
        size: f32,
        color: [f32; 3],
        rtl: bool,
    ) -> Result<(), OpsError> {
        match &mut self.painter {
            Painter::Own { name, font, .. } => {
                let mut hex = String::new();
                for (code, _) in text.chars().filter_map(|c| font.code(c)) {
                    let _ = write!(hex, "{code:02X}");
                }
                if hex.is_empty() {
                    return Ok(());
                }
                self.own.op("BT");
                self.own.fill_colour(color);
                let label: String = name.iter().map(|byte| escape_name(*byte)).collect();
                let _ = writeln!(self.own.0, "/{label} {size} Tf");
                self.own.nums(&[x, y], "Td");
                let _ = writeln!(self.own.0, "<{hex}> Tj");
                self.own.op("ET");
            }
            Painter::Faces(faces) => {
                let (glyphs, _) = faces.shape_line(text, rtl, 0.0)?;
                self.lines.push(SetLine {
                    glyphs,
                    x,
                    baseline: y,
                    size,
                    color,
                });
            }
        }
        Ok(())
    }
}

/// A byte of a name as a content stream writes it.
fn escape_name(byte: u8) -> String {
    if byte.is_ascii_alphanumeric() {
        char::from(byte).to_string()
    } else {
        format!("#{byte:02X}")
    }
}

/// Whether `font`'s `/BaseFont` reads as serif, for the bundled family that matches it.
fn serif(base_font: Option<&str>) -> bool {
    let Some(name) = base_font else {
        return false;
    };
    let name = name.to_ascii_lowercase();
    !name.contains("sans")
        && ["times", "serif", "georgia", "garamond", "minion", "cambria"]
            .iter()
            .any(|family| name.contains(family))
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

/// The painter for `shown` in `field`, by a11-1c's policy.
fn painter<'a>(
    document: &Document,
    revisions: &RevisionStore,
    field: &Field,
    shown: &[&str],
    setting: &mut Setting<'a>,
) -> Result<Painter<'a>, OpsError> {
    let (library, missing) = (setting.library, setting.missing);
    let own = match field.font.as_deref() {
        Some(font) => revisions
            .form_font(document, font)
            .ok()
            .flatten()
            .map(|found| (font.to_vec(), found)),
        None => None,
    };
    let (mut base_font, mut weight) = (None, 400);
    if let Some((name_of, found)) = own {
        let font = FieldFont::new(&found.resource);
        let absent = shown
            .iter()
            .flat_map(|text| text.chars())
            .any(|c| !c.is_control() && font.code(c).is_none());
        let keep = match missing {
            MissingFont::Bundled => false,
            MissingFont::Ask if absent => return Err(OpsError::FontChoiceNeeded),
            MissingFont::Ask => false,
            MissingFont::Keep => true,
        };
        if !absent || keep {
            setting.filled.marked |= absent;
            return Ok(Painter::Own {
                name: name_of,
                value: found.value,
                font,
            });
        }
        base_font = found.resource.base_font;
        if base_font
            .as_deref()
            .is_some_and(|name| name.to_ascii_lowercase().contains("bold"))
        {
            weight = 700;
        }
    } else if missing == MissingFont::Ask && shown.iter().any(|text| !text.is_empty()) {
        return Err(OpsError::FontChoiceNeeded);
    }
    Ok(Painter::Faces(Box::new(if serif(base_font.as_deref()) {
        Faces::serif(library, weight)
    } else {
        Faces::new(library, weight)
    })))
}

/// The widget's box size in its form's own axes, turned by `/MK /R`, and the form's `/Matrix`.
fn form_box(widget: &Widget) -> (f32, f32, Option<[f32; 6]>) {
    let [l, b, r, t] = widget.rect;
    let (width, height) = ((r - l).max(0.0), (t - b).max(0.0));
    match widget.turn {
        90 => (height, width, Some([0.0, 1.0, -1.0, 0.0, width, 0.0])),
        180 => (width, height, Some([-1.0, 0.0, 0.0, -1.0, width, height])),
        270 => (height, width, Some([0.0, -1.0, 1.0, 0.0, 0.0, height])),
        _ => (width, height, None),
    }
}

/// `/MK`'s background and border.
fn frame(ops: &mut Ops, widget: &Widget, width: f32, height: f32) {
    if let Some(background) = widget.background {
        ops.fill_colour(background);
        ops.nums(&[0.0, 0.0, width, height], "re");
        ops.op("f");
    }
    if let Some(border) = widget.border.filter(|_| widget.border_width > 0.0) {
        // shortcut: every /BS /S draws solid; draw dashed, beveled and inset when a form needs it.
        let half = widget.border_width / 2.0;
        ops.stroke_colour(border);
        ops.nums(&[widget.border_width], "w");
        ops.nums(
            &[
                half,
                half,
                (width - widget.border_width).max(0.0),
                (height - widget.border_width).max(0.0),
            ],
            "re",
        );
        ops.op("S");
    }
}

/// The form for `ops`.
fn add_form(
    document: &Document,
    revisions: &mut RevisionStore,
    (width, height, matrix): (f32, f32, Option<[f32; 6]>),
    ops: Ops,
    fonts: Vec<(Vec<u8>, Value)>,
) -> Result<ObjectRef, OpsError> {
    let mut dict = vec![
        (b"Type".to_vec(), name(b"XObject")),
        (b"Subtype".to_vec(), name(b"Form")),
        (b"FormType".to_vec(), Value::Integer(1)),
        (b"BBox".to_vec(), numbers([0.0, 0.0, width, height])),
    ];
    if let Some(matrix) = matrix {
        dict.push((b"Matrix".to_vec(), numbers(matrix)));
    }
    let resources = if fonts.is_empty() {
        Vec::new()
    } else {
        vec![(b"Font".to_vec(), Value::Dictionary(fonts))]
    };
    dict.push((b"Resources".to_vec(), Value::Dictionary(resources)));
    Ok(revisions.add_object(
        document,
        Value::Stream {
            dict,
            data: ops.0.into_bytes(),
        },
    )?)
}

/// `widths` of `text`'s lines wrapped to `room` per unit of font size: each line's byte range.
fn wrap(
    painter: &mut Painter<'_>,
    text: &str,
    room: f32,
    rtl: bool,
) -> Result<Vec<(usize, usize)>, OpsError> {
    let (mut start, mut end, mut used) = (0usize, 0usize, 0.0f32);
    let mut lines = Vec::new();
    for (stop, kind) in breaks(text) {
        if !matches!(kind, Break::Allowed | Break::Mandatory) {
            continue;
        }
        let piece = text.get(end..stop).unwrap_or_default();
        let wide = painter.measure(piece.trim_end(), rtl)?;
        if used + wide > room && end > start {
            lines.push((start, end));
            start = end;
            used = 0.0;
        }
        used += painter.measure(piece, rtl)?;
        end = stop;
    }
    if end > start || lines.is_empty() {
        lines.push((start, text.len().max(end)));
    }
    Ok(lines)
}

/// The appearance of a text or choice widget showing `shown` as a new form.
#[allow(clippy::too_many_lines)]
fn text_form(
    document: &Document,
    revisions: &mut RevisionStore,
    field: &Field,
    widget: &Widget,
    shown: &[&str],
    setting: &mut Setting<'_>,
) -> Result<ObjectRef, OpsError> {
    let rows: Vec<&str> = if field.kind == FieldKind::List {
        field.options.iter().map(|o| o.display.as_str()).collect()
    } else {
        shown.to_vec()
    };
    let painter = painter(document, revisions, field, &rows, setting)?;
    let placed = form_box(widget);
    let (width, height, _) = placed;
    let mut ops = Ops(String::new());
    frame(&mut ops, widget, width, height);
    let pad = widget.border_width.max(1.0);
    let (inner_w, inner_h) = ((width - 2.0 * pad).max(0.0), (height - 2.0 * pad).max(0.0));
    ops.op("/Tx BMC");
    ops.op("q");
    ops.nums(&[pad, pad, inner_w, inner_h], "re");
    ops.op("W n");
    let mut drawn = Drawn {
        painter,
        own: Ops(String::new()),
        lines: Vec::new(),
    };
    let color = field.text_color;
    let align = |wide: f32, area: f32, rtl: bool| -> f32 {
        match (field.align, rtl) {
            (1, _) => (area - wide) / 2.0,
            (2, _) | (0, true) => area - wide,
            _ => 0.0,
        }
    };
    let text = shown.first().copied().unwrap_or("");
    let rtl = right_to_left(text);
    if field.kind == FieldKind::List {
        let size = field.font_size.unwrap_or(LARGEST_AUTO);
        let row = LINE_HEIGHT * size;
        let first = field.top_index.min(rows.len().saturating_sub(1));
        let mut top = height - pad;
        for option in field.options.iter().skip(first) {
            if top <= pad {
                break;
            }
            if shown.contains(&option.display.as_str()) {
                ops.fill_colour(SELECTED);
                ops.nums(&[pad, top - row, inner_w, row], "re");
                ops.op("f");
            }
            let line_rtl = right_to_left(&option.display);
            drawn.line(
                &option.display,
                (pad, top - row - DESCENT * size),
                size,
                color,
                line_rtl,
            )?;
            top -= row;
        }
    } else if field.comb {
        let cells = field.max_len.unwrap_or(1).max(1);
        #[allow(clippy::cast_precision_loss)]
        let cell = width / cells as f32;
        let size = field.font_size.unwrap_or((height * 0.6).min(cell)).max(1.0);
        let baseline = (height - (ASCENT - DESCENT) * size) / 2.0 - DESCENT * size;
        let mut x = 0.0;
        let mut piece = [0u8; 4];
        for c in text
            .chars()
            .take(usize::try_from(cells).unwrap_or(usize::MAX))
        {
            let part: &str = c.encode_utf8(&mut piece);
            let wide = drawn.painter.measure(part, false)? * size;
            drawn.line(
                part,
                (x + (cell - wide) / 2.0, baseline),
                size,
                color,
                false,
            )?;
            x += cell;
        }
    } else if field.multiline {
        // shortcut: an automatic size is the largest allowed, not fitted; fit it if a form's text
        // overflows its box in another reader's eyes.
        let size = field.font_size.unwrap_or(LARGEST_AUTO);
        let room = (inner_w / size).max(0.0);
        let mut baseline = height - pad - ASCENT * size;
        'lines: for paragraph in settable(text).split(['\n', '\r']) {
            let rtl = right_to_left(paragraph);
            for (from, to) in wrap(&mut drawn.painter, paragraph, room, rtl)? {
                if baseline < -LINE_HEIGHT * size {
                    break 'lines;
                }
                let line = paragraph.get(from..to).unwrap_or_default().trim_end();
                let wide = drawn.painter.measure(line, rtl)? * size;
                drawn.line(
                    line,
                    (pad + align(wide, inner_w, rtl), baseline),
                    size,
                    color,
                    rtl,
                )?;
                baseline -= LINE_HEIGHT * size;
            }
        }
    } else if !text.is_empty() {
        let masked;
        let line = if field.password {
            masked = "*".repeat(text.chars().count().min(MOST_SET_TEXT));
            masked.as_str()
        } else {
            settable(text)
        };
        let per_size = drawn.painter.measure(line, rtl)?;
        let size = field.font_size.unwrap_or_else(|| {
            let high = (inner_h * 0.8).min(LARGEST_AUTO);
            let wide = if per_size > 0.0 {
                inner_w / per_size
            } else {
                high
            };
            high.min(wide).max(SMALLEST_AUTO)
        });
        let baseline = (height - (ASCENT - DESCENT) * size) / 2.0 - DESCENT * size;
        let wide = per_size * size;
        drawn.line(
            line,
            (pad + align(wide, inner_w, rtl), baseline),
            size,
            color,
            rtl,
        )?;
    }
    let Drawn {
        painter,
        own,
        lines,
    } = drawn;
    let fonts = match painter {
        Painter::Own { name, value, .. } => {
            ops.0.push_str(&own.0);
            vec![(name, value)]
        }
        Painter::Faces(faces) => {
            if lines.is_empty() {
                Vec::new()
            } else {
                let prefix = revisions.free_form_font_prefix(document);
                let embedded = embed_faces(document, revisions, &faces, &prefix)?;
                text_ops(&mut ops, &embedded, &lines, (0.0, 0.0));
                revisions.add_form_fonts(document, embedded.fonts.clone())?;
                for family in faces.families() {
                    if !setting.filled.fonts.contains(&family) {
                        setting.filled.fonts.push(family);
                    }
                }
                embedded.fonts
            }
        }
    };
    ops.op("Q");
    ops.op("EMC");
    add_form(document, revisions, placed, ops, fonts)
}

/// A check box's or radio button's on and off faces, for a widget with no appearance.
fn button_forms(
    document: &Document,
    revisions: &mut RevisionStore,
    field: &Field,
    widget: &Widget,
    state: &[u8],
) -> Result<Value, OpsError> {
    let placed = form_box(widget);
    let (width, height, _) = placed;
    let mut off = Ops(String::new());
    frame(&mut off, widget, width, height);
    let mut on = Ops(off.0.clone());
    let side = width.min(height);
    let (cx, cy) = (width / 2.0, height / 2.0);
    on.fill_colour(field.text_color);
    on.stroke_colour(field.text_color);
    if field.kind == FieldKind::Radio {
        let radius = side * 0.3;
        let k = radius * 0.552_284_8;
        on.nums(&[cx + radius, cy], "m");
        on.nums(
            &[cx + radius, cy + k, cx + k, cy + radius, cx, cy + radius],
            "c",
        );
        on.nums(
            &[cx - k, cy + radius, cx - radius, cy + k, cx - radius, cy],
            "c",
        );
        on.nums(
            &[cx - radius, cy - k, cx - k, cy - radius, cx, cy - radius],
            "c",
        );
        on.nums(
            &[cx + k, cy - radius, cx + radius, cy - k, cx + radius, cy],
            "c",
        );
        on.op("f");
    } else {
        on.nums(&[(side * 0.12).max(0.5)], "w");
        on.moved([cx - side * 0.3, cy]);
        on.line([cx - side * 0.08, cy - side * 0.25]);
        on.line([cx + side * 0.32, cy + side * 0.28]);
        on.op("S");
    }
    let on = add_form(document, revisions, placed, on, Vec::new())?;
    let off = add_form(document, revisions, placed, off, Vec::new())?;
    Ok(Value::Dictionary(vec![(
        b"N".to_vec(),
        Value::Dictionary(vec![
            (state.to_vec(), Value::Reference(on)),
            (b"Off".to_vec(), Value::Reference(off)),
        ]),
    )]))
}

/// Keys of a dictionary to set, or to remove with `None`.
type Entries = Vec<(Vec<u8>, Option<Value>)>;

/// Writes `values` into `field` and its widgets.
fn apply(
    document: &Document,
    revisions: &mut RevisionStore,
    field: &Field,
    values: &[String],
    setting: &mut Setting<'_>,
) -> Result<(), OpsError> {
    let mut entries: Entries = Vec::new();
    let mut states: Vec<(ObjectRef, Entries)> = Vec::new();
    match field.kind {
        FieldKind::Text | FieldKind::Combo | FieldKind::List => {
            let value = match values {
                [] => None,
                [one] => Some(text_value(one)),
                many => Some(Value::Array(many.iter().map(|v| text_value(v)).collect())),
            };
            entries.push((b"V".to_vec(), value));
            // A rich value would still say the old text.
            entries.push((b"RV".to_vec(), None));
            if field.kind != FieldKind::Text {
                let chosen: Vec<Value> = field
                    .options
                    .iter()
                    .enumerate()
                    .filter(|(_, option)| values.contains(&option.export))
                    .filter_map(|(at, _)| i64::try_from(at).ok().map(Value::Integer))
                    .collect();
                entries.push((
                    b"I".to_vec(),
                    (!chosen.is_empty()).then_some(Value::Array(chosen)),
                ));
            }
            // shortcut: a value shows as typed, not as AFNumber_Format or AFPercent_Format would
            // dress it (B204); format it when a form's numbers need to read as another reader shows them.
            let shown: Vec<&str> = values
                .iter()
                .map(|value| {
                    field
                        .options
                        .iter()
                        .find(|option| option.export == *value)
                        .map_or(value.as_str(), |option| option.display.as_str())
                })
                .collect();
            for widget in &field.widgets {
                let form = text_form(document, revisions, field, widget, &shown, setting)?;
                states.push((
                    widget.object,
                    vec![(
                        b"AP".to_vec(),
                        Some(Value::Dictionary(vec![(
                            b"N".to_vec(),
                            Value::Reference(form),
                        )])),
                    )],
                ));
            }
        }
        FieldKind::Check | FieldKind::Radio => {
            let wanted = values.first().map(String::as_str);
            let on = field.widgets.iter().find_map(|widget| {
                let state = widget.on_state.as_deref()?;
                (wanted == Some(String::from_utf8_lossy(state).as_ref())).then(|| state.to_vec())
            });
            entries.push((
                b"V".to_vec(),
                Some(Value::Name(on.clone().unwrap_or_else(|| b"Off".to_vec()))),
            ));
            for widget in &field.widgets {
                let state = widget.on_state.as_deref().unwrap_or(b"Yes");
                let chosen = on.as_deref() == Some(state);
                let mut change = vec![(
                    b"AS".to_vec(),
                    Some(Value::Name(if chosen {
                        state.to_vec()
                    } else {
                        b"Off".to_vec()
                    })),
                )];
                if !widget.has_appearance {
                    let forms = button_forms(document, revisions, field, widget, state)?;
                    change.push((b"AP".to_vec(), Some(forms)));
                }
                states.push((widget.object, change));
            }
        }
        FieldKind::Push | FieldKind::Signature | FieldKind::Other => return Err(plan_error()),
    }
    for node in &field.nodes {
        revisions.change_entries(document, *node, entries.clone())?;
    }
    for (object, change) in states {
        revisions.change_entries(document, object, change)?;
    }
    Ok(())
}

/// Removes `/XFA` from the form on its first change (question 12).
fn drop_xfa(
    document: &Document,
    revisions: &mut RevisionStore,
    list: &FormFields,
    filled: &mut Filled,
) -> Result<(), OpsError> {
    if list.has_xfa {
        revisions.change_form(document, vec![(b"XFA".to_vec(), None)])?;
        filled.xfa_removed = true;
    }
    Ok(())
}

/// Whether `values` can go in `field`: only known options unless it is editable, only one
/// unless it allows several, only a state a widget has.
fn check_values(field: &Field, values: &[String]) -> Result<(), OpsError> {
    let fits = match field.kind {
        FieldKind::Text => values.len() <= 1,
        FieldKind::Combo => {
            values.len() <= 1
                && (field.editable
                    || values
                        .iter()
                        .all(|value| field.options.iter().any(|o| o.export == *value)))
        }
        FieldKind::List => {
            (values.len() <= 1 || field.multi_select)
                && values
                    .iter()
                    .all(|value| field.options.iter().any(|o| o.export == *value))
        }
        FieldKind::Check | FieldKind::Radio => {
            values.len() <= 1
                && values.iter().all(|value| {
                    field.widgets.iter().any(|widget| {
                        widget
                            .on_state
                            .as_deref()
                            .is_some_and(|state| String::from_utf8_lossy(state) == value.as_str())
                    })
                })
        }
        FieldKind::Push | FieldKind::Signature | FieldKind::Other => false,
    };
    let short = values.iter().all(|value| value.len() <= MOST_VALUE);
    if fits && short && !field.read_only {
        Ok(())
    } else {
        Err(plan_error())
    }
}

/// Sets field `handle` to `values` in the open transaction: text or export values, or the on-state
/// of a button, none to empty it. The same values write nothing.
///
/// # Errors
///
/// [`OpsError::FontChoiceNeeded`] under [`MissingFont::Ask`], [`OpsError::NoFontForText`] for text
/// no font here has, and an annotation plan error for a field that is read-only or takes no value,
/// or values it cannot hold.
pub fn set_value(
    document: &Document,
    revisions: &mut RevisionStore,
    handle: u64,
    values: &[String],
    library: &FontLibrary,
    missing: MissingFont,
) -> Result<Filled, OpsError> {
    let list = revisions.form_fields(document);
    let field = list
        .fields
        .iter()
        .find(|field| field.handle == handle)
        .ok_or_else(plan_error)?;
    check_values(field, values)?;
    if field.values == values {
        return Ok(Filled::default());
    }
    let mut setting = Setting {
        library,
        missing,
        filled: Filled::default(),
    };
    apply(document, revisions, field, values, &mut setting)?;
    drop_xfa(document, revisions, &list, &mut setting.filled)?;
    Ok(setting.filled)
}

/// The fields [`clear`] empties: those that hold something and can change. Signatures stay.
#[must_use]
pub fn clearable(list: &FormFields) -> Vec<&Field> {
    list.fields
        .iter()
        .filter(|field| {
            !field.values.is_empty()
                && !field.read_only
                && !matches!(
                    field.kind,
                    FieldKind::Push | FieldKind::Signature | FieldKind::Other
                )
        })
        .collect()
}

/// Empties every [`clearable`] field in the open transaction.
///
/// # Errors
///
/// As [`set_value`].
pub fn clear(
    document: &Document,
    revisions: &mut RevisionStore,
    library: &FontLibrary,
) -> Result<(), OpsError> {
    let list = revisions.form_fields(document);
    let fields = clearable(&list);
    let mut setting = Setting {
        library,
        missing: MissingFont::Bundled,
        filled: Filled::default(),
    };
    for field in &fields {
        apply(document, revisions, field, &[], &mut setting)?;
    }
    if !fields.is_empty() {
        drop_xfa(document, revisions, &list, &mut setting.filled)?;
    }
    Ok(())
}

/// The fields' pages for a change of everything a form holds.
#[must_use]
pub fn pages_of(list: &FormFields) -> Vec<usize> {
    let mut pages: Vec<usize> = list
        .fields
        .iter()
        .flat_map(|field| field.widgets.iter().map(|widget| widget.page))
        .collect();
    pages.sort_unstable();
    pages.dedup();
    pages
}

/// Finish (G47): the fields become page content as they look, in the open transaction, through the
/// flatten primitive; a field with a value and no appearance gets one first, with simple
/// signatures going down with their fields. A digitally signed field stays a field. `/Fields` keeps
/// only what stays.
///
/// # Errors
///
/// Those of writing appearances, and [`ferman_core::WriteError::PageStateLeaks`] from the flatten.
pub fn finish(
    document: &Document,
    revisions: &mut RevisionStore,
    library: &FontLibrary,
) -> Result<(), OpsError> {
    let list = revisions.form_fields(document);
    let mut setting = Setting {
        library,
        missing: MissingFont::Bundled,
        filled: Filled::default(),
    };
    let mut budget = MOST_SET_TOTAL;
    let mut pages: std::collections::BTreeMap<usize, Vec<u64>> = std::collections::BTreeMap::new();
    let mut kept: Vec<ObjectRef> = Vec::new();
    for field in &list.fields {
        if field.signed {
            for root in &field.roots {
                if !kept.contains(root) {
                    kept.push(*root);
                }
            }
            continue;
        }
        let without: Vec<&Widget> = field
            .widgets
            .iter()
            .filter(|widget| !widget.has_appearance)
            .collect();
        let size: usize = field.values.iter().map(String::len).sum();
        if !without.is_empty() && !field.values.is_empty() && size <= budget {
            budget -= size;
            // apply() writes the whole field, so every widget ends up with the same appearance.
            apply(document, revisions, field, &field.values, &mut setting)?;
        }
        for widget in &field.widgets {
            pages
                .entry(widget.page)
                .or_default()
                .push(widget.object.handle());
        }
        if let (Some(stamp), Some(widget)) = (field.signature, field.widgets.first()) {
            pages.entry(widget.page).or_default().push(stamp);
        }
    }
    for (page, handles) in pages {
        revisions.flatten_annotations(document, page, &handles, &[])?;
    }
    revisions.set_form_roots(document, &kept)?;
    let mut entries = vec![(b"NeedAppearances".to_vec(), None)];
    if list.has_xfa {
        entries.push((b"XFA".to_vec(), None));
    }
    revisions.change_form(document, entries)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn field(format: Option<DeclaredFormat>, min: Option<f64>, max: Option<f64>) -> Field {
        Field {
            handle: 1,
            name: "a".to_owned(),
            label: None,
            kind: FieldKind::Text,
            read_only: false,
            required: false,
            multiline: false,
            password: false,
            comb: false,
            multi_select: false,
            editable: false,
            values: Vec::new(),
            options: Vec::new(),
            top_index: 0,
            max_len: None,
            font: None,
            font_size: None,
            text_color: [0.0; 3],
            align: 0,
            widgets: Vec::new(),
            nodes: Vec::new(),
            roots: Vec::new(),
            declared: ferman_core::forms::Declared { format, min, max },
            signed: false,
            signature: None,
        }
    }

    fn date(pattern: &str) -> Field {
        field(Some(DeclaredFormat::Date(pattern.to_owned())), None, None)
    }

    #[test]
    fn dates_read_by_their_declared_pattern() {
        let form = date("dd.mm.yyyy");
        assert_eq!(problem(&form, "29.02.2024"), None);
        assert_eq!(problem(&form, ""), None);
        for wrong in [
            "29.02.2026",
            "31.04.2026",
            "12.13.2026",
            "1.2.2026",
            "abc",
            "01.02.2026x",
        ] {
            assert!(
                matches!(problem(&form, wrong), Some(FieldProblem::NotADate { .. })),
                "{wrong}"
            );
        }
        let form = date("mmm d, yyyy");
        assert_eq!(problem(&form, "Nov 7, 2026"), None);
        assert!(problem(&form, "Nol 7, 2026").is_some());
        let form = date("m/d/yy h:MM tt");
        assert_eq!(problem(&form, "11/7/26 3:05 pm"), None);
    }

    #[test]
    fn numbers_read_by_their_declared_style_and_range() {
        let form = field(
            Some(DeclaredFormat::Number {
                decimals: 0,
                separators: 2,
            }),
            Some(1.0),
            Some(20.0),
        );
        assert_eq!(problem(&form, "20"), None);
        assert_eq!(problem(&form, "1,5"), None);
        assert_eq!(problem(&form, "abc"), Some(FieldProblem::NotANumber));
        assert_eq!(
            problem(&form, "21"),
            Some(FieldProblem::OutOfRange {
                min: Some(1.0),
                max: Some(20.0)
            })
        );
        let form = field(
            Some(DeclaredFormat::Number {
                decimals: 2,
                separators: 0,
            }),
            None,
            None,
        );
        assert_eq!(problem(&form, "1,234.50"), None);
    }

    #[test]
    fn a_field_with_no_declaration_takes_anything_within_max_len() {
        let mut form = field(None, None, None);
        assert_eq!(problem(&form, "anything"), None);
        form.max_len = Some(3);
        assert_eq!(
            problem(&form, "abcd"),
            Some(FieldProblem::TooLong { max: 3 })
        );
    }
}
