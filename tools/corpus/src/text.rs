//! Text set into pages: spans of styled text broken into lines, aligned or justified, flowed
//! down a frame from page to page. Every line drawn is also recorded, in drawing order, as the
//! page's expected text.
//!
//! Justification is done the two ways producers do it: `Tw` word spacing when the spaces are in
//! a simple font (Word), and `TJ` adjustments after each space otherwise (LaTeX, any composite
//! font).
//!
//! Right-to-left paragraphs get their levels from the Unicode bidi algorithm (UAX #9); each line
//! is drawn in visual order, as producers write it, so numbers and Latin words inside Arabic
//! read left to right. Text without spaces between words (Japanese) breaks at U+200B, which is
//! not drawn.

use crate::font::{Face, Glyph, PdfFont};
use crate::pdf::{self, Content, Page, Pdf, num};
use harfrust::{Feature, Tag};
use lopdf::{Dictionary, Object};
use std::collections::BTreeSet;
use std::rc::Rc;
use unicode_bidi::{Level, ParagraphBidiInfo};

/// A break opportunity that is not drawn, between characters of text without spaces.
pub const BREAK: char = '\u{200B}';

/// A font's index in [`Fonts`]; its resource name is `/F<index + 1>`.
pub type FontKey = usize;

/// The fonts of one document.
#[derive(Debug, Default)]
pub struct Fonts {
    list: Vec<PdfFont>,
}

impl Fonts {
    /// No fonts yet.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Adds a font.
    pub fn add(&mut self, font: PdfFont) -> FontKey {
        self.list.push(font);
        self.list.len() - 1
    }

    /// The resource name of `key`, without the slash.
    #[must_use]
    pub fn resource_name(key: FontKey) -> String {
        format!("F{}", key + 1)
    }

    /// A `/Font` resource dictionary for `keys`.
    #[must_use]
    pub fn resources(&self, keys: &BTreeSet<FontKey>) -> Dictionary {
        let mut fonts = Dictionary::new();
        for key in keys {
            if let Some(font) = self.list.get(*key) {
                fonts.set(Self::resource_name(*key), font.id());
            }
        }
        fonts
    }

    /// Writes every font.
    ///
    /// # Errors
    ///
    /// A message when a font cannot be written.
    pub fn finish(self, pdf: &mut Pdf) -> Result<(), String> {
        for font in self.list {
            font.finish(pdf)?;
        }
        Ok(())
    }

    fn two_byte(&self, key: FontKey) -> bool {
        self.list.get(key).is_some_and(PdfFont::two_byte)
    }

    /// The face of `key`.
    #[must_use]
    pub fn face(&self, key: FontKey) -> Option<Rc<Face>> {
        self.list.get(key).map(PdfFont::face)
    }

    fn is_simple(&self, key: FontKey) -> bool {
        self.list.get(key).is_some_and(|font| !font.two_byte())
    }

    /// The glyphs of `text` in `style` at bidi `level` (odd for right to left): shaped in a
    /// composite font, encoded one by one in a simple one, with the characters it lacks taken
    /// from the style's fallback and the characters it borrows from the borrowed font.
    ///
    /// # Errors
    ///
    /// A message when a character can be set in no font, or when right-to-left text is not in
    /// a composite font.
    pub fn runs(&mut self, style: &Style, text: &str, level: u8) -> Result<Vec<Run>, String> {
        let features = style.features();
        let rtl = level % 2 == 1;
        if let Some(PdfFont::Type0(_)) = self.list.get(style.font) {
            let glyphs = self.shape(style.font, text, &features, rtl)?;
            return Ok(vec![style.run(style.font, glyphs, level)]);
        }
        if rtl {
            return Err(format!(
                "right-to-left text needs a composite font: {text:?}"
            ));
        }
        let mut runs: Vec<Run> = Vec::new();
        let mut pending = String::new();
        let mut pending_font = None;
        for c in text.chars() {
            let borrowed = style
                .borrowed
                .filter(|(_, chars)| chars.contains(c))
                .map(|(key, _)| key);
            let glyph = if borrowed.is_some() {
                None
            } else {
                match self.list.get_mut(style.font) {
                    Some(PdfFont::Simple(font)) => font.encode(c),
                    Some(PdfFont::Standard(font)) => font.encode(c),
                    _ => None,
                }
            };
            let target = match (glyph.is_some(), borrowed, style.fallback) {
                (true, _, _) => None,
                (false, Some(key), _) | (false, None, Some(key)) => Some(key),
                (false, None, None) => return Err(format!("no glyph for {c:?} in {text:?}")),
            };
            if target != pending_font && !pending.is_empty() {
                if let Some(key) = pending_font {
                    let glyphs = self.shape(key, &pending, &features, false)?;
                    runs.push(style.run(key, glyphs, 0));
                }
                pending.clear();
            }
            pending_font = target;
            match glyph {
                Some(glyph) => match runs.last_mut() {
                    Some(last) if last.font == style.font => last.glyphs.push(glyph),
                    _ => runs.push(style.run(style.font, vec![glyph], 0)),
                },
                None => pending.push(c),
            }
        }
        if let Some(key) = pending_font.filter(|_| !pending.is_empty()) {
            let glyphs = self.shape(key, &pending, &features, false)?;
            runs.push(style.run(key, glyphs, 0));
        }
        Ok(runs)
    }

    /// The glyphs of `text` in the composite font `key`, in visual order.
    ///
    /// # Errors
    ///
    /// A message when `key` is not a composite font or shaping fails.
    pub fn shape(
        &mut self,
        key: FontKey,
        text: &str,
        features: &[Feature],
        rtl: bool,
    ) -> Result<Vec<Glyph>, String> {
        match self.list.get_mut(key) {
            Some(PdfFont::Type0(font)) => font.shape(text, features, rtl),
            _ => Err(format!("font {key} is not a composite font")),
        }
    }
}

/// How a span of text looks.
#[derive(Debug, Clone)]
pub struct Style {
    /// The font.
    pub font: FontKey,
    /// A composite font for the characters a simple `font` cannot encode.
    pub fallback: Option<FontKey>,
    /// The size in points.
    pub size: f64,
    /// The fill colour.
    pub color: (u8, u8, u8),
    /// Whether the shaper may form ligatures.
    pub ligatures: bool,
    /// Whether justified lines use `Tw` (when their spaces are in a simple font).
    pub word_spacing: bool,
    /// Extra space after every glyph, in points (`Tc`).
    pub char_spacing: f64,
    /// A composite font that sets these characters, as a producer does for glyphs its font
    /// lacks.
    pub borrowed: Option<(FontKey, &'static str)>,
    /// Whether the text is in a right-to-left paragraph: the bidi algorithm orders it, and a
    /// justified paragraph's last line sits on the right.
    pub rtl: bool,
}

impl Style {
    /// Black text in `font` at `size`, without ligatures, justified with `TJ`.
    #[must_use]
    pub fn new(font: FontKey, size: f64) -> Self {
        Self {
            font,
            fallback: None,
            size,
            color: (0, 0, 0),
            ligatures: false,
            word_spacing: false,
            char_spacing: 0.0,
            borrowed: None,
            rtl: false,
        }
    }

    /// The features the shaper turns off: ligatures, unless the style allows them.
    #[must_use]
    pub fn features(&self) -> Vec<Feature> {
        if self.ligatures {
            Vec::new()
        } else {
            vec![
                Feature::new(Tag::new(b"liga"), 0, ..),
                Feature::new(Tag::new(b"clig"), 0, ..),
            ]
        }
    }

    fn run(&self, font: FontKey, glyphs: Vec<Glyph>, level: u8) -> Run {
        Run {
            font,
            size: self.size,
            color: self.color,
            spacing: self.char_spacing,
            glyphs,
            level,
        }
    }

    /// The same style at another size.
    #[must_use]
    pub fn sized(&self, size: f64) -> Self {
        Self {
            size,
            ..self.clone()
        }
    }

    /// The same style in another colour.
    #[must_use]
    pub fn colored(&self, color: (u8, u8, u8)) -> Self {
        Self {
            color,
            ..self.clone()
        }
    }

    /// The same style in a right-to-left paragraph.
    #[must_use]
    pub fn right_to_left(&self) -> Self {
        Self {
            rtl: true,
            ..self.clone()
        }
    }
}

/// Glyphs in one font at one size.
#[derive(Debug, Clone)]
pub struct Run {
    /// The font.
    pub font: FontKey,
    /// The size in points.
    pub size: f64,
    /// The fill colour.
    pub color: (u8, u8, u8),
    /// The character spacing in points.
    pub spacing: f64,
    /// The glyphs, in visual order.
    pub glyphs: Vec<Glyph>,
    /// Its bidi level: 0 in left-to-right text, odd where it reads right to left.
    pub level: u8,
}

impl Run {
    /// The advance of the run in points.
    #[must_use]
    pub fn width(&self) -> f64 {
        #[allow(clippy::cast_precision_loss)]
        let spacing = self.spacing * self.glyphs.len() as f64;
        self.glyphs.iter().map(|glyph| glyph.advance).sum::<f64>() * self.size / 1000.0 + spacing
    }
}

/// A piece of styled text.
#[derive(Debug, Clone)]
pub struct Span {
    /// Its style.
    pub style: Style,
    /// Its text.
    pub text: String,
}

impl Span {
    /// `text` in `style`.
    #[must_use]
    pub fn new(style: &Style, text: &str) -> Self {
        Self {
            style: style.clone(),
            text: text.to_owned(),
        }
    }
}

#[derive(Debug, Clone)]
enum Item {
    Word { runs: Vec<Run>, text: String },
    Space(Run),
}

impl Item {
    fn width(&self) -> f64 {
        match self {
            Self::Word { runs, .. } => runs.iter().map(Run::width).sum(),
            Self::Space(run) => run.width(),
        }
    }
}

/// One line of a paragraph.
#[derive(Debug, Clone)]
pub struct Line {
    items: Vec<Item>,
    /// The largest size on the line.
    pub size: f64,
    /// Whether it belongs to a right-to-left paragraph.
    pub rtl: bool,
}

impl Line {
    /// The natural width in points.
    #[must_use]
    pub fn width(&self) -> f64 {
        self.items.iter().map(Item::width).sum()
    }

    /// The runs in visual order, each with whether it is a space (UAX #9 rule L2: from the
    /// highest level down to the lowest odd one, every sequence at that level or above is
    /// reversed). A run's own glyphs are already in visual order.
    fn visual_runs(&self) -> Vec<(&Run, bool)> {
        let mut runs: Vec<(&Run, bool)> = Vec::new();
        for item in &self.items {
            match item {
                Item::Word { runs: word, .. } => runs.extend(word.iter().map(|run| (run, false))),
                Item::Space(run) => runs.push((run, true)),
            }
        }
        let highest = runs.iter().map(|(run, _)| run.level).max().unwrap_or(0);
        let lowest_odd = runs
            .iter()
            .map(|(run, _)| run.level)
            .filter(|level| level % 2 == 1)
            .min();
        if let Some(lowest_odd) = lowest_odd {
            for level in (lowest_odd..=highest).rev() {
                let mut index = 0;
                while index < runs.len() {
                    if runs[index].0.level < level {
                        index += 1;
                        continue;
                    }
                    let start = index;
                    while index < runs.len() && runs[index].0.level >= level {
                        index += 1;
                    }
                    runs[start..index].reverse();
                }
            }
        }
        runs
    }

    /// Where the line starts in `width` from `x`, and the space added after each space.
    fn start_and_extra(&self, x: f64, width: f64, align: Align, last: bool) -> (f64, f64) {
        let natural = self.width();
        let spaces = self
            .items
            .iter()
            .filter(|item| matches!(item, Item::Space(_)))
            .count();
        match align {
            Align::Left => (x, 0.0),
            Align::Center => (x + (width - natural) / 2.0, 0.0),
            Align::Right => (x + width - natural, 0.0),
            Align::Justify if (last || spaces == 0) && self.rtl => (x + width - natural, 0.0),
            Align::Justify if last || spaces == 0 => (x, 0.0),
            #[allow(clippy::cast_precision_loss)]
            Align::Justify => (x, (width - natural) / spaces as f64),
        }
    }

    /// Every glyph of the line with its pen position, as [`draw_line`] would place it in
    /// `width` points from `x`: for drawing the line other than in a content stream.
    #[must_use]
    pub fn placements(&self, x: f64, width: f64, align: Align, last: bool) -> Vec<Placed> {
        let (mut pen, extra) = self.start_and_extra(x, width, align, last);
        let mut placed = Vec::new();
        for (run, is_space) in self.visual_runs() {
            for glyph in &run.glyphs {
                placed.push(Placed {
                    font: run.font,
                    gid: glyph.gid,
                    x: pen,
                    size: run.size,
                    color: run.color,
                });
                pen += glyph.advance * run.size / 1000.0 + run.spacing;
            }
            if is_space {
                pen += extra;
            }
        }
        placed
    }

    /// The text of the line, in logical order.
    #[must_use]
    pub fn text(&self) -> String {
        let mut text = String::new();
        for item in &self.items {
            match item {
                Item::Word { text: word, .. } => text.push_str(word),
                Item::Space(_) => text.push(' '),
            }
        }
        text
    }
}

/// A glyph of a line at its pen position.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Placed {
    /// Its font.
    pub font: FontKey,
    /// The glyph in the font file.
    pub gid: u16,
    /// The pen position from the left, in points.
    pub x: f64,
    /// The size in points.
    pub size: f64,
    /// The fill colour.
    pub color: (u8, u8, u8),
}

/// Breaks `spans` into lines no wider than `width` points, at spaces and at [`BREAK`]. The
/// first span's style says whether the paragraph is right to left.
///
/// # Errors
///
/// A message when a character cannot be set.
pub fn lay_out(fonts: &mut Fonts, spans: &[Span], width: f64) -> Result<Vec<Line>, String> {
    let rtl = spans.first().is_some_and(|span| span.style.rtl);
    // The bidi level of every byte of the paragraph (none for left-to-right text).
    let levels: Vec<u8> = if rtl {
        let whole: String = spans.iter().map(|span| span.text.as_str()).collect();
        ParagraphBidiInfo::new(&whole, Some(Level::rtl()))
            .levels
            .iter()
            .map(Level::number)
            .collect()
    } else {
        Vec::new()
    };
    let level_at = |offset: usize| levels.get(offset).copied().unwrap_or(0);
    // Words and spaces in order; a word may cross spans.
    let mut items: Vec<Item> = Vec::new();
    let mut word_runs: Vec<Run> = Vec::new();
    let mut word_text = String::new();
    let mut offset = 0;
    for span in spans {
        let mut rest = span.text.as_str();
        while !rest.is_empty() {
            if let Some(after) = rest.strip_prefix(' ') {
                if !word_text.is_empty() {
                    items.push(Item::Word {
                        runs: std::mem::take(&mut word_runs),
                        text: std::mem::take(&mut word_text),
                    });
                }
                if !matches!(items.last(), Some(Item::Space(_)) | None) {
                    let mut runs = fonts.runs(&span.style, " ", level_at(offset))?;
                    if let Some(run) = runs.pop() {
                        items.push(Item::Space(run));
                    }
                }
                offset += 1;
                rest = after;
                continue;
            }
            if let Some(after) = rest.strip_prefix(BREAK) {
                if !word_text.is_empty() {
                    items.push(Item::Word {
                        runs: std::mem::take(&mut word_runs),
                        text: std::mem::take(&mut word_text),
                    });
                }
                offset += BREAK.len_utf8();
                rest = after;
                continue;
            }
            let end = rest.find([' ', BREAK]).unwrap_or(rest.len());
            let piece = &rest[..end];
            // One run per bidi level inside the word.
            let mut start = 0;
            while start < piece.len() {
                let level = level_at(offset + start);
                let stop = piece[start..]
                    .char_indices()
                    .find(|(at, _)| level_at(offset + start + at) != level)
                    .map_or(piece.len(), |(at, _)| start + at);
                word_runs.extend(fonts.runs(&span.style, &piece[start..stop], level)?);
                start = stop;
            }
            word_text.push_str(piece);
            offset += end;
            rest = &rest[end..];
        }
    }
    if !word_text.is_empty() {
        items.push(Item::Word {
            runs: word_runs,
            text: word_text,
        });
    }
    if matches!(items.last(), Some(Item::Space(_))) {
        items.pop();
    }

    let size_of = |item: &Item| match item {
        Item::Word { runs, .. } => runs.iter().map(|run| run.size).fold(0.0, f64::max),
        Item::Space(run) => run.size,
    };
    let mut lines = Vec::new();
    let mut current: Vec<Item> = Vec::new();
    let mut current_width = 0.0;
    let mut pending_space: Option<Item> = None;
    for item in items {
        match item {
            Item::Space(_) => pending_space = Some(item),
            Item::Word { .. } => {
                let space_width = pending_space.as_ref().map_or(0.0, Item::width);
                if !current.is_empty() && current_width + space_width + item.width() > width {
                    let size = current.iter().map(size_of).fold(0.0, f64::max);
                    lines.push(Line {
                        items: std::mem::take(&mut current),
                        size,
                        rtl,
                    });
                    current_width = 0.0;
                    pending_space = None;
                }
                if let Some(space) = pending_space.take() {
                    current_width += space.width();
                    current.push(space);
                }
                current_width += item.width();
                current.push(item);
            }
        }
    }
    if !current.is_empty() {
        let size = current.iter().map(size_of).fold(0.0, f64::max);
        lines.push(Line {
            items: current,
            size,
            rtl,
        });
    }
    Ok(lines)
}

/// How a line sits in its width.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Align {
    /// Flush left.
    Left,
    /// Centred.
    Center,
    /// Flush right.
    Right,
    /// Flush left and right, except a paragraph's last line.
    Justify,
}

/// Draws `line` with its baseline at `y`, in `width` points from `x`, and returns the fonts it
/// used. `last` marks a paragraph's last line, which is never justified. The runs go in visual
/// order.
#[allow(clippy::too_many_arguments)]
pub fn draw_line(
    content: &mut Content,
    fonts: &Fonts,
    line: &Line,
    origin: (f64, f64),
    width: f64,
    align: Align,
    last: bool,
    word_spacing: bool,
) -> BTreeSet<FontKey> {
    let (x, extra) = line.start_and_extra(origin.0, width, align, last);
    let use_tw = extra > 0.0
        && word_spacing
        && line.items.iter().all(|item| match item {
            Item::Space(run) => fonts.is_simple(run.font),
            Item::Word { .. } => true,
        });

    let mut used = BTreeSet::new();
    content.op("BT");
    if use_tw {
        content.op(&format!("{} Tw", num(extra)));
    }
    content.op(&format!("{} {} Td", num(x), num(origin.1)));
    let mut state: Option<(FontKey, f64)> = None;
    let mut color = (0u8, 0u8, 0u8);
    let mut spacing = 0.0;
    let mut array = String::new();
    let flush = |content: &mut Content, array: &mut String| {
        if !array.is_empty() {
            content.op(&format!("[{array}] TJ"));
            array.clear();
        }
    };
    for (run, is_space) in line.visual_runs() {
        {
            if state != Some((run.font, run.size)) {
                flush(content, &mut array);
                content.op(&format!(
                    "/{} {} Tf",
                    Fonts::resource_name(run.font),
                    num(run.size)
                ));
                state = Some((run.font, run.size));
            }
            if run.color != color {
                flush(content, &mut array);
                content.fill_rgb(run.color);
                color = run.color;
            }
            if (run.spacing - spacing).abs() > f64::EPSILON {
                flush(content, &mut array);
                content.op(&format!("{} Tc", num(run.spacing)));
                spacing = run.spacing;
            }
            used.insert(run.font);
            push_glyphs(&mut array, fonts.two_byte(run.font), &run.glyphs);
            if is_space && extra > 0.0 && !use_tw {
                array.push_str(&num(-extra * 1000.0 / run.size));
            }
        }
    }
    flush(content, &mut array);
    if use_tw {
        content.op("0 Tw");
    }
    if spacing != 0.0 {
        content.op("0 Tc");
    }
    if color != (0, 0, 0) {
        content.fill_rgb((0, 0, 0));
    }
    content.op("ET");
    used
}

/// Appends `glyphs` to a `TJ` array: strings of codes, with a number wherever the shaped
/// advance differs from the width.
fn push_glyphs(array: &mut String, two_byte: bool, glyphs: &[Glyph]) {
    let mut codes: Vec<u8> = Vec::new();
    let close = |array: &mut String, codes: &mut Vec<u8>| {
        if codes.is_empty() {
            return;
        }
        if two_byte {
            array.push('<');
            for byte in codes.iter() {
                array.push_str(&format!("{byte:02X}"));
            }
            array.push('>');
        } else {
            array.push_str(&pdf::literal(codes));
        }
        codes.clear();
    };
    for glyph in glyphs {
        codes.extend_from_slice(&glyph.code);
        let adjust = glyph.width - glyph.advance;
        if adjust.abs() >= 0.5 {
            close(array, &mut codes);
            array.push_str(&num(adjust.round()));
        }
    }
    close(array, &mut codes);
}

/// A paragraph to flow.
#[derive(Debug, Clone)]
pub struct Paragraph {
    /// Its text.
    pub spans: Vec<Span>,
    /// Its alignment.
    pub align: Align,
    /// The line height as a multiple of the largest size.
    pub leading: f64,
    /// Space above, in points.
    pub before: f64,
    /// Space below, in points.
    pub after: f64,
    /// Whether justified lines use `Tw`.
    pub word_spacing: bool,
    /// Whether its lines stay on one page.
    pub keep_together: bool,
    /// The structure type (such as `P` or `H1`) its lines are marked with, as tagged PDF does.
    pub tag: Option<&'static str>,
}

impl Paragraph {
    /// One span, justified, with a line height of 1.5.
    #[must_use]
    pub fn new(style: &Style, text: &str) -> Self {
        Self {
            spans: vec![Span::new(style, text)],
            align: Align::Justify,
            leading: 1.5,
            before: 0.0,
            after: 0.0,
            word_spacing: style.word_spacing,
            keep_together: false,
            tag: None,
        }
    }

    /// The same paragraph marked as structure type `tag`.
    #[must_use]
    pub fn tagged(mut self, tag: &'static str) -> Self {
        self.tag = Some(tag);
        self
    }

    /// The same paragraph aligned otherwise.
    #[must_use]
    pub fn aligned(mut self, align: Align) -> Self {
        self.align = align;
        self
    }

    /// The same paragraph with space above and below.
    #[must_use]
    pub fn spaced(mut self, before: f64, after: f64) -> Self {
        self.before = before;
        self.after = after;
        self
    }

    /// The same paragraph with another line height.
    #[must_use]
    pub fn leading(mut self, leading: f64) -> Self {
        self.leading = leading;
        self
    }

    /// The same paragraph kept on one page.
    #[must_use]
    pub fn kept(mut self) -> Self {
        self.keep_together = true;
        self
    }
}

/// A page being written: its content, the fonts it uses and its text.
#[derive(Debug, Default)]
pub struct PageText {
    /// The content stream.
    pub content: Content,
    /// The fonts it uses.
    pub fonts: BTreeSet<FontKey>,
    /// Its lines of text in drawing order.
    pub lines: Vec<String>,
    /// More resources, such as `/XObject` or `/Properties`.
    pub resources: Dictionary,
    /// More page entries, such as `/Annots`.
    pub extra: Dictionary,
    /// The next marked-content id.
    pub next_mcid: i64,
}

impl PageText {
    /// Draws `lines` of `paragraph` from `top` in the column at `x`, and returns the position
    /// below the last line. `ends` says whether the paragraph's last line is among them.
    #[allow(clippy::too_many_arguments)]
    pub fn draw(
        &mut self,
        fonts: &Fonts,
        lines: &[Line],
        paragraph: &Paragraph,
        x: f64,
        width: f64,
        top: f64,
        ends: bool,
    ) -> f64 {
        let mut y = top;
        for (index, line) in lines.iter().enumerate() {
            let height = line.size * paragraph.leading;
            let baseline = y - height + (height - line.size) / 2.0 + line.size * 0.22;
            let last = ends && index + 1 == lines.len();
            let used = draw_line(
                &mut self.content,
                fonts,
                line,
                (x, baseline),
                width,
                paragraph.align,
                last,
                paragraph.word_spacing,
            );
            self.fonts.extend(used);
            self.lines.push(line.text());
            y -= height;
        }
        y
    }

    /// The page for `pdf`, with its `/Font` resources.
    #[must_use]
    pub fn into_page(self, fonts: &Fonts, size: (f64, f64)) -> Page {
        let mut resources = self.resources;
        if !self.fonts.is_empty() {
            resources.set("Font", fonts.resources(&self.fonts));
        }
        resources.set(
            "ProcSet",
            Object::Array(vec![pdf::name("PDF"), pdf::name("Text")]),
        );
        Page {
            size,
            content: self.content.into_bytes(),
            resources,
            extra: Dictionary::new(),
        }
    }
}

/// The text column paragraphs flow down.
#[derive(Debug, Clone, Copy)]
pub struct Frame {
    /// The left edge.
    pub x: f64,
    /// The top edge.
    pub top: f64,
    /// The bottom edge.
    pub bottom: f64,
    /// The width.
    pub width: f64,
}

/// Paragraphs flowed through a frame, a new page whenever one fills.
#[derive(Debug)]
pub struct Flow {
    frame: Frame,
    /// The finished pages and the current one, last.
    pub pages: Vec<PageText>,
    y: f64,
}

impl Flow {
    /// An empty flow with one page.
    #[must_use]
    pub fn new(frame: Frame) -> Self {
        Self {
            frame,
            pages: vec![PageText::default()],
            y: frame.top,
        }
    }

    /// The current page.
    pub fn page(&mut self) -> &mut PageText {
        if self.pages.is_empty() {
            self.pages.push(PageText::default());
        }
        let last = self.pages.len() - 1;
        &mut self.pages[last]
    }

    /// The current position from the top of the frame.
    #[must_use]
    pub fn y(&self) -> f64 {
        self.y
    }

    /// Moves down by `points`.
    pub fn skip(&mut self, points: f64) {
        self.y -= points;
    }

    /// Starts a new page.
    pub fn break_page(&mut self) {
        self.pages.push(PageText::default());
        self.y = self.frame.top;
    }

    /// Lays out and draws `paragraph`, breaking pages between lines (or before it, when it is
    /// kept together). When it is tagged, returns each (page index, marked-content id) its
    /// lines were marked with.
    ///
    /// # Errors
    ///
    /// A message when a character cannot be set.
    pub fn paragraph(
        &mut self,
        fonts: &mut Fonts,
        paragraph: &Paragraph,
    ) -> Result<Vec<(usize, i64)>, String> {
        let mut marks = Vec::new();
        let lines = lay_out(fonts, &paragraph.spans, self.frame.width)?;
        let fonts: &Fonts = fonts;
        if self.y < self.frame.top {
            self.y -= paragraph.before;
        }
        if paragraph.keep_together {
            let height: f64 = lines.iter().map(|line| line.size * paragraph.leading).sum();
            if self.y - height < self.frame.bottom && self.y < self.frame.top {
                self.break_page();
            }
        }
        let mut start = 0;
        while start < lines.len() {
            let mut end = start;
            let mut y = self.y;
            while end < lines.len() {
                let height = lines[end].size * paragraph.leading;
                if y - height < self.frame.bottom && end > start {
                    break;
                }
                if y - height < self.frame.bottom && self.y < self.frame.top {
                    break;
                }
                y -= height;
                end += 1;
            }
            if end == start {
                self.break_page();
                continue;
            }
            let frame = self.frame;
            let top = self.y;
            let ends = end == lines.len();
            let index = self.pages.len().saturating_sub(1);
            let page = self.page();
            if let Some(tag) = paragraph.tag {
                let mcid = page.next_mcid;
                page.next_mcid += 1;
                page.content.op(&format!("/{tag} <</MCID {mcid}>> BDC"));
                marks.push((index, mcid));
            }
            let y = page.draw(
                fonts,
                &lines[start..end],
                paragraph,
                frame.x,
                frame.width,
                top,
                ends,
            );
            if paragraph.tag.is_some() {
                page.content.op("EMC");
            }
            self.y = y;
            start = end;
            if start < lines.len() {
                self.break_page();
            }
        }
        self.y -= paragraph.after;
        Ok(marks)
    }

    /// Like [`Flow::paragraph`], in another column (an indented block) from the current
    /// position.
    ///
    /// # Errors
    ///
    /// A message when a character cannot be set.
    pub fn paragraph_in(
        &mut self,
        fonts: &mut Fonts,
        paragraph: &Paragraph,
        frame: Frame,
    ) -> Result<Vec<(usize, i64)>, String> {
        let saved = std::mem::replace(&mut self.frame, frame);
        let marks = self.paragraph(fonts, paragraph);
        self.frame = saved;
        marks
    }

    /// The pages.
    #[must_use]
    pub fn into_pages(self) -> Vec<PageText> {
        self.pages
    }
}

/// The expected text of `pages`: lines joined by line feeds, pages by form feeds.
#[must_use]
pub fn expected_text(pages: &[Vec<String>]) -> String {
    pages
        .iter()
        .map(|lines| lines.join("\n"))
        .collect::<Vec<_>>()
        .join("\u{c}")
}
