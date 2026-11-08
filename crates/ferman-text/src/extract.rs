//! A page's text in reading order (docs/ARCHITECTURE.md §6.2 to §6.4, §6.10 and §6.11): fonts
//! from their resources, glyphs placed by the interpreter, lines by baseline, right-to-left lines
//! in logical order, and vertical text in columns.
//!
//! Lines follow the content order, which is the reading order of the documents Ferman makes and of
//! most others; columns and blocks are M3's (`layout`). A word break goes where a space glyph is,
//! or where the gap to the next glyph passes a fifth of the font size. A right-to-left line is
//! stored in visual order, so it is read back with the bidi algorithm (UAX #9), which sees the line
//! from the right, as it was typed: each glyph keeps its own text (a lam-alef ligature stays "لا"),
//! and brackets at right-to-left levels are mirrored. `/ActualText` replaces the glyphs it covers
//! where it orders right-to-left text or their text is unknown.
// Positions and widths come from files (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::HashMap;

use ferman_core::Document;
use ferman_core::interpret::{
    FontResource, Matrix, OperatorEvent, ShowItem, Span, SpanSource, TextShow, TextSink,
};
use ferman_core::revision::RevisionStore;
use ferman_core::structure::FontKind;
use ferman_fonts::{
    BaseEncoding, BuiltinEncoding, CMap, FontProgram, GlyphId, SimpleEncoding, builtin_encoding,
    glyph_names,
};
use unicode_bidi::{BidiClass, BidiInfo, Level, bidi_class};

use crate::TextError;
use crate::standard14;

/// The gap, as a share of the font size, from which two glyphs are two words.
const WORD_GAP: f32 = 0.2;

/// The bytes of `/ActualText` a page may add: one large string that a file's `/Properties` resource
/// shares among many sequences must not grow the text without bound. Past it, glyphs read as
/// their own text.
const ACTUAL_TEXT_LIMIT: usize = 1 << 20;

/// A box `[left, top, right, bottom]`.
pub type CharBox = [f32; 4];

/// A page's text with the box of every character in displayed points: from the page's top-left
/// corner as it shows after its crop box and `/Rotate`, y down, as the canvas lays pages out. A
/// space or line break no glyph drew has no box.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct PageText {
    /// Lines separated by `\n`, words by spaces.
    pub text: String,
    /// One per character of `text`.
    pub boxes: Vec<Option<CharBox>>,
}

/// The text of page `index`: lines separated by `\n`, words by spaces.
///
/// # Errors
///
/// [`TextError::Core`] when a limit stops the interpreter.
pub fn page_text(document: &Document, index: usize) -> Result<String, TextError> {
    Ok(page_layout(document, index)?.text)
}

/// The text of page `index` with its characters' boxes.
///
/// # Errors
///
/// [`TextError::Core`] when a limit stops the interpreter.
pub fn page_layout(document: &Document, index: usize) -> Result<PageText, TextError> {
    page_layout_through(document, None, index)
}

/// [`page_layout`] of the document as `revisions` changed it.
///
/// # Errors
///
/// As [`page_layout`].
pub fn page_layout_revised(
    document: &Document,
    revisions: &RevisionStore,
    index: usize,
) -> Result<PageText, TextError> {
    page_layout_through(document, Some(revisions), index)
}

fn page_layout_through(
    document: &Document,
    revisions: Option<&RevisionStore>,
    index: usize,
) -> Result<PageText, TextError> {
    let mut collector = Collector::default();
    match revisions {
        Some(revisions) => revisions.page_text(document, index, &mut collector)?,
        None => document.page_text(index, &mut collector)?,
    }
    collector.finish();
    let page = document.pages_through(revisions).get(index);
    let glyphs = &collector.glyphs;
    let mut out = PageText::default();
    for (n, line) in lines(glyphs).into_iter().enumerate() {
        if n > 0 {
            out.text.push('\n');
            out.boxes.push(None);
        }
        for (c, found) in line {
            out.text.push(c);
            out.boxes.push(
                found
                    .and_then(|at| glyphs.get(at))
                    .map(|glyph| displayed(page, glyph_box(glyph))),
            );
        }
    }
    Ok(out)
}

/// A box of user space, `[left, bottom, right, top]`, in displayed points `[left, top, right,
/// bottom]`.
pub(crate) fn displayed(
    page: Option<&ferman_core::structure::Page>,
    [left, bottom, right, top]: CharBox,
) -> CharBox {
    let Some(page) = page else {
        return [left, top, right, bottom];
    };
    let corners = [
        page.display_point(left, bottom),
        page.display_point(right, top),
    ];
    let xs = corners.map(|(x, _)| x);
    let ys = corners.map(|(_, y)| y);
    [
        xs[0].min(xs[1]),
        ys[0].min(ys[1]),
        xs[0].max(xs[1]),
        ys[0].max(ys[1]),
    ]
}

/// A line's characters, each with the index of the glyph that drew it.
pub(crate) type Line = Vec<(char, Option<usize>)>;

/// Where a glyph comes from: its show operator and its place in it (docs/ARCHITECTURE.md §6.6).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct GlyphLink {
    /// The show operator's span: its stream or form and its bytes in that stream's decoded data.
    pub span: Span,
    /// The glyph's code among the show's codes, from 0, across the strings of a `TJ`.
    pub index: usize,
}

/// A font, ready to split strings into codes and give their widths and text.
pub(crate) struct PdfFont {
    /// A composite font's CMap; a simple font's codes are single bytes.
    pub(crate) cmap: Option<CMap>,
    /// Whether `cmap` is the font's own: false for a predefined CMap Ferman does not bundle,
    /// read as `Identity-H`.
    pub(crate) cmap_known: bool,
    encoding: SimpleEncoding,
    pub(crate) to_unicode: Option<CMap>,
    pub(crate) resource: FontResource,
    /// A simple font's glyph names by code: its program's built-in encoding, then `/Differences`.
    names: Vec<(u8, String)>,
    /// A simple font without `/Widths`: each code's width in thousandths of an em, from the
    /// standard 14 metrics or the embedded program (docs/ARCHITECTURE.md §6.2).
    fallback: Vec<Option<f32>>,
    /// The ascent and descent per unit of font size (descent negative).
    ascent: f32,
    descent: f32,
}

impl PdfFont {
    pub(crate) fn new(resource: &FontResource) -> Self {
        let mut cmap_known = true;
        let cmap = (resource.kind == FontKind::Type0).then(|| {
            match (&resource.cmap, resource.cmap_name.as_deref()) {
                (Some(bytes), _) => {
                    let mut cmap = CMap::parse(bytes);
                    for parent in &resource.cmap_parents {
                        cmap.inherit(&CMap::parse(parent));
                    }
                    cmap
                }
                (None, Some(name)) if let Some(cmap) = CMap::predefined(name) => cmap,
                // shortcut: a predefined CMap that is not bundled reads as Identity-H, and its
                // lines are not rewritten; bundle it from Adobe's cmap-resources when a
                // document needs it.
                _ => {
                    cmap_known = false;
                    CMap::identity(false)
                }
            }
        });
        let named = resource
            .base_encoding
            .as_deref()
            .and_then(BaseEncoding::from_name);
        // Without a named base, an embedded Type1 program's built-in encoding is the base
        // (ISO 32000-2 §9.6.5); a damaged program falls back to the default.
        let type1 = matches!(resource.kind, FontKind::Type1 | FontKind::MultipleMaster);
        let builtin = resource
            .font_program
            .as_deref()
            .filter(|_| named.is_none() && type1)
            .and_then(|program| builtin_encoding(program).ok().flatten());
        let (base, builtin_codes) = match builtin {
            Some(BuiltinEncoding::Standard) => (Some(BaseEncoding::Standard), Vec::new()),
            Some(BuiltinEncoding::Codes(codes)) => (None, codes),
            None => (
                named.or((!resource.symbolic).then_some(BaseEncoding::Standard)),
                Vec::new(),
            ),
        };
        let names: Vec<(u8, String)> = builtin_codes
            .into_iter()
            .chain(resource.differences.iter().cloned())
            .collect();
        let differences = names.iter().map(|(code, name)| (*code, name.as_str()));
        let (ascent, descent) = ascent_descent(resource);
        let mut font = Self {
            cmap,
            cmap_known,
            encoding: SimpleEncoding::new(base, differences),
            to_unicode: resource.to_unicode.as_deref().map(CMap::parse),
            resource: resource.clone(),
            names,
            fallback: Vec::new(),
            ascent,
            descent,
        };
        if font.cmap.is_none() && resource.widths.is_empty() {
            font.fallback = font.fallback_widths();
        }
        font
    }

    /// The width of every code of a simple font without `/Widths`: a standard 14 font's metrics
    /// by the code's character, else the embedded program's advance.
    fn fallback_widths(&self) -> Vec<Option<f32>> {
        let standard = standard14::widths(self.resource.base_font.as_deref());
        let program = self.program();
        let units = program
            .as_ref()
            .map_or(0.0, |program| f32::from(program.units_per_em()));
        (0..=u8::MAX)
            .map(|code| {
                let standard = standard
                    .zip(single(&self.text(u32::from(code))))
                    .and_then(|(table, c)| standard14::width(table, c));
                standard.or_else(|| {
                    let program = program.as_ref().filter(|_| units > 0.0)?;
                    let advance = program.advance_width(self.glyph(program, code)?)?;
                    Some(advance * 1000.0 / units)
                })
            })
            .collect()
    }

    /// The embedded program, when it parses.
    pub(crate) fn program(&self) -> Option<FontProgram<'_>> {
        FontProgram::parse(self.resource.font_program.as_deref()?).ok()
    }

    /// The glyph name a simple font's encoding gives `code`, when its program or `/Differences`
    /// name one.
    fn name(&self, code: u8) -> Option<&str> {
        self.names
            .iter()
            .rev()
            .find(|(at, _)| *at == code)
            .map(|(_, name)| name.as_str())
    }

    /// The glyph of a simple font's `code` in its embedded `program`, not `.notdef`: a symbolic
    /// TrueType font's through its symbol or Macintosh cmap, otherwise the one the code's glyph
    /// name or its character finds (ISO 32000-2 §9.6.5.4).
    pub(crate) fn glyph(&self, program: &FontProgram<'_>, code: u8) -> Option<GlyphId> {
        let found = |glyph: Option<GlyphId>| glyph.filter(|glyph| glyph.0 != 0);
        if self.resource.kind == FontKind::TrueType && self.resource.symbolic {
            return found(program.glyph_for_char(char::from(code)));
        }
        if let Some(glyph) = found(
            self.name(code)
                .and_then(|name| program.glyph_for_name(name)),
        ) {
            return Some(glyph);
        }
        let c = single(&self.text(u32::from(code)))?;
        found(program.glyph_for_char(c)).or_else(|| {
            glyph_names(c)
                .into_iter()
                .find_map(|name| found(program.glyph_for_name(&name)))
        })
    }

    /// Whether a simple font draws `code` with a glyph of its own, not `.notdef`: a Type3 font
    /// through its `/CharProcs`, an embedded program through [`glyph`](Self::glyph), a standard
    /// 14 font through its metrics, another font by its widths. `program` is
    /// [`program`](Self::program)'s, parsed once by the caller.
    pub(crate) fn has_glyph(&self, program: Option<&FontProgram<'_>>, code: u8) -> bool {
        let resource = &self.resource;
        if resource.kind == FontKind::Type3 {
            return self
                .name(code)
                .is_some_and(|name| resource.char_procs.iter().any(|proc| proc.name == name));
        }
        if let Some(program) = program {
            return self.glyph(program, code).is_some();
        }
        if resource.font_program.is_none()
            && resource.widths.is_empty()
            && let Some(table) = standard14::widths(resource.base_font.as_deref())
        {
            return single(&self.text(u32::from(code)))
                .and_then(|c| standard14::width(table, c))
                .is_some();
        }
        // A program that does not parse, or a font the reader finds on the system: its widths
        // tell the codes it uses.
        resource.widths.is_empty()
            || u32::from(code)
                .checked_sub(resource.first_char)
                .and_then(|at| usize::try_from(at).ok())
                .and_then(|at| resource.widths.get(at))
                .is_some_and(|&width| width > 0.0)
    }

    /// The glyph of a composite font's `cid` in its embedded `program`, not `.notdef`: through
    /// a `CIDFontType2` font's `/CIDToGIDMap` stream, else the program's own CIDs (a TrueType
    /// program's are its glyph indices, `/Identity`).
    pub(crate) fn cid_glyph(&self, program: &FontProgram<'_>, cid: u32) -> Option<GlyphId> {
        let glyph = match &self.resource.cid_to_gid {
            Some(map) => {
                let at = usize::try_from(cid).ok()?.checked_mul(2)?;
                let pair = map.get(at..at.checked_add(2)?)?;
                let [high, low] = <[u8; 2]>::try_from(pair).ok()?;
                GlyphId(u32::from(u16::from_be_bytes([high, low])))
            }
            None => program.glyph_for_cid(cid)?,
        };
        (glyph.0 != 0 && glyph.0 < program.glyph_count()).then_some(glyph)
    }

    /// The CID whose glyph is `glyph`, the inverse of [`cid_glyph`](Self::cid_glyph): the
    /// lowest one a `/CIDToGIDMap` stream gives it.
    pub(crate) fn glyph_cid(&self, program: &FontProgram<'_>, glyph: GlyphId) -> Option<u32> {
        match &self.resource.cid_to_gid {
            Some(map) => (0_u32..)
                .zip(map.as_chunks::<2>().0)
                .find(|(_, pair)| u32::from(u16::from_be_bytes(**pair)) == glyph.0)
                .map(|(cid, _)| cid),
            None => program.cid_for_glyph(glyph),
        }
    }

    pub(crate) fn vertical(&self) -> bool {
        self.cmap.as_ref().is_some_and(CMap::is_vertical)
    }

    pub(crate) fn codes(&self, bytes: &[u8]) -> Vec<(u32, usize)> {
        match &self.cmap {
            Some(cmap) => cmap.codes(bytes).collect(),
            None => bytes.iter().map(|&byte| (u32::from(byte), 1)).collect(),
        }
    }

    /// The horizontal advance of `code`, per unit of font size.
    pub(crate) fn width(&self, code: u32, length: usize) -> f32 {
        let font = &self.resource;
        if let Some(cmap) = &self.cmap {
            let cid = cmap.cid(code, length).unwrap_or(0);
            let width = font
                .cid_widths
                .iter()
                .find(|(first, last, _)| (first..=last).contains(&&cid))
                .map_or(font.default_width, |&(_, _, width)| width);
            return width / 1000.0;
        }
        let width = code
            .checked_sub(font.first_char)
            .and_then(|at| usize::try_from(at).ok())
            .and_then(|at| font.widths.get(at))
            .or_else(|| {
                usize::try_from(code)
                    .ok()
                    .and_then(|at| self.fallback.get(at))
                    .and_then(Option::as_ref)
            })
            .copied()
            .unwrap_or(font.missing_width);
        if font.kind == FontKind::Type3 {
            let [a, ..] = font.font_matrix;
            return width * a;
        }
        // A font without /Widths whose metrics no source gives gets half an em.
        if width == 0.0 && font.widths.is_empty() {
            return 0.5;
        }
        width / 1000.0
    }

    /// The vertical advance of `code`, per unit of font size (negative: down the column).
    pub(crate) fn vertical_advance(&self, code: u32, length: usize) -> f32 {
        let font = &self.resource;
        let cid = self
            .cmap
            .as_ref()
            .and_then(|cmap| cmap.cid(code, length))
            .unwrap_or(0);
        let w1y = font
            .vertical_metrics
            .iter()
            .find(|(first, last, _)| (first..=last).contains(&&cid))
            .map_or(font.default_vertical[1], |&(_, _, [w1y, _, _])| w1y);
        w1y / 1000.0
    }

    /// The text of `code`: its ToUnicode entry, the encoding's glyph name, or U+FFFD.
    pub(crate) fn text(&self, code: u32) -> String {
        if let Some(text) = self.to_unicode.as_ref().and_then(|cmap| cmap.text(code)) {
            return text;
        }
        if self.cmap.is_none()
            && let Some(text) = u8::try_from(code)
                .ok()
                .and_then(|code| self.encoding.text(code))
        {
            return text.to_owned();
        }
        char::REPLACEMENT_CHARACTER.to_string()
    }
}

/// The character of `text` when it is one.
pub(crate) fn single(text: &str) -> Option<char> {
    let mut chars = text.chars();
    chars.next().filter(|_| chars.next().is_none())
}

/// The ascent and descent of `font` per unit of font size: from its embedded program, its
/// descriptor's `/Ascent` and `/Descent`, a standard 14 font's metrics, its `/FontBBox`, or
/// four fifths above the baseline and one fifth below.
fn ascent_descent(font: &FontResource) -> (f32, f32) {
    let scale = if font.kind == FontKind::Type3 {
        font.font_matrix[3]
    } else {
        0.001
    };
    let program = font
        .font_program
        .as_deref()
        .and_then(|bytes| FontProgram::parse(bytes).ok())
        .and_then(|program| {
            let (ascent, descent) = program.ascent_descent();
            let units = f32::from(program.units_per_em());
            (units > 0.0).then(|| (ascent / units, descent / units))
        });
    let descriptor = (font.ascent != 0.0 || font.descent != 0.0)
        .then_some((font.ascent * scale, font.descent * scale));
    let bbox = font
        .font_bbox
        .map(|[_, bottom, _, top]| (top * scale, bottom * scale));
    [
        program,
        descriptor,
        standard_metrics(font.base_font.as_deref()),
        bbox,
    ]
    .into_iter()
    .flatten()
    // A hostile or broken font's metrics beyond four ems fall through to the next source.
    .find(|&(ascent, descent)| ascent > descent && ascent.abs() <= 4.0 && descent.abs() <= 4.0)
    .unwrap_or((0.8, -0.2))
}

/// The ascender and descender of a standard 14 font, from Adobe's Core14 AFM files.
fn standard_metrics(base_font: Option<&str>) -> Option<(f32, f32)> {
    let name = base_font?;
    // A subset tag such as `ABCDEF+` comes before the name.
    let name = name.split_once('+').map_or(name, |(_, name)| name);
    let (ascent, descent) = [
        ("Courier", (629.0, -157.0)),
        ("Helvetica", (718.0, -207.0)),
        ("Times", (683.0, -217.0)),
        ("Symbol", (1010.0, -293.0)),
        ("ZapfDingbats", (820.0, -143.0)),
    ]
    .into_iter()
    .find(|(family, _)| name.starts_with(family))?
    .1;
    Some((ascent / 1000.0, descent / 1000.0))
}

/// One glyph on the page.
#[derive(Debug, Clone, PartialEq)]
pub(crate) struct Glyph {
    pub(crate) text: String,
    /// Its origin and the point its advance reaches, in page space.
    pub(crate) start: [f32; 2],
    pub(crate) end: [f32; 2],
    /// Its font size in page space.
    pub(crate) size: f32,
    pub(crate) vertical: bool,
    /// Its font's ascent and descent per unit of size (descent negative).
    pub(crate) ascent: f32,
    pub(crate) descent: f32,
    /// Its show operator and its place in it.
    pub(crate) link: GlyphLink,
    /// Its code and the code's length in bytes.
    pub(crate) code: u32,
    pub(crate) length: usize,
    /// Where it starts along its show in the show's text space, and how far it advances there
    /// (spacing included).
    pub(crate) offset: f32,
    pub(crate) step: f32,
    /// The show it is in, counted from 0 on the page.
    pub(crate) show: usize,
    /// The font's key.
    pub(crate) font: u64,
    /// `Tr`.
    pub(crate) render_mode: u8,
    /// Whether it is the single-byte code 32, which `Tw` widens.
    pub(crate) space: bool,
    /// The word spacing `Tw` added to it, in text space.
    pub(crate) word_spacing: f32,
    /// The `TJ` number right after it, in thousandths of text space against the writing
    /// direction (negative widens); 0 without one.
    pub(crate) adjust: f32,
    /// `Tc`, in text space.
    pub(crate) char_spacing: f32,
    /// Whether text space is sheared in page space, so its boxes are not rectangles.
    pub(crate) skewed: bool,
    /// The `/ActualText` of the marked content this glyph opens: it stands for the sequence.
    pub(crate) actual: Option<String>,
    /// Whether a sequence's `/ActualText` stands for this glyph, on an earlier glyph.
    pub(crate) covered: bool,
}

impl Glyph {
    /// The text it reads as.
    fn reads(&self) -> &str {
        match &self.actual {
            Some(text) => text,
            None if self.covered => "",
            None => &self.text,
        }
    }
}

/// The sink that places glyphs.
#[derive(Default)]
pub(crate) struct Collector {
    pub(crate) fonts: HashMap<u64, PdfFont>,
    pub(crate) glyphs: Vec<Glyph>,
    shows: usize,
    /// Whether the page draws an image (`Do` of an XObject that is not a form with content, or
    /// `BI`), and whether it paints a path.
    pub(crate) images: bool,
    pub(crate) paths: bool,
    /// The stream or form of the operator before this one.
    last_source: Option<SpanSource>,
    /// The glyph the open `/ActualText` sits on, and the bytes placed on this page.
    actual_at: Option<usize>,
    actual_bytes: usize,
    /// The innermost `/Lang` and `/MCID` of the marked content around each show that has one,
    /// by the show's stream and offset.
    pub(crate) show_languages: HashMap<(SpanSource, usize), String>,
    pub(crate) show_mcids: HashMap<(SpanSource, usize), i64>,
}

impl Collector {
    /// Ends a sequence left open at the end of the page.
    pub(crate) fn finish(&mut self) {
        if let Some(at) = self.actual_at.take() {
            self.close_actual(at);
        }
    }

    /// Ends the `/ActualText` on glyph `at`. It counts where it gives the logical order of the
    /// right-to-left characters the glyphs draw, or where the glyphs' own text is unknown.
    /// Otherwise each glyph reads as itself and keeps its own box and font: other text is out of
    /// date, since an edit keeps the marked content around a line (E21).
    // shortcut: an edit to an anagram of a right-to-left sequence reads as the old text; upgrade
    // when the rewrite updates `/ActualText`.
    fn close_actual(&mut self, at: usize) {
        let Some(glyphs) = self.glyphs.get_mut(at..) else {
            return;
        };
        let says: Vec<char> = glyphs
            .first()
            .and_then(|glyph| glyph.actual.as_deref())
            .unwrap_or_default()
            .chars()
            .filter(|c| !c.is_whitespace())
            .collect();
        let draws: Vec<char> = glyphs
            .iter()
            .flat_map(|glyph| glyph.text.chars())
            .filter(|c| !c.is_whitespace())
            .collect();
        let unknown = draws.is_empty() || draws.contains(&char::REPLACEMENT_CHARACTER);
        let sorted = |chars: &[char]| {
            let mut chars = chars.to_vec();
            chars.sort_unstable();
            chars
        };
        let orders = says != draws
            && says.iter().copied().any(right_to_left)
            && sorted(&says) == sorted(&draws);
        if !unknown && !orders {
            for glyph in glyphs {
                glyph.actual = None;
                glyph.covered = false;
            }
        }
    }
}

impl TextSink for Collector {
    fn font(&mut self, font: &FontResource) {
        self.fonts.insert(font.key, PdfFont::new(font));
    }

    fn operator(&mut self, operator: &OperatorEvent<'_>) {
        let source = operator.span.source;
        match operator.name {
            // A form's `Do` comes after the form's own operators, from another source; an
            // image's comes alone.
            b"Do" if self.last_source.is_none_or(|last| last == source) => self.images = true,
            b"BI" => self.images = true,
            b"f" | b"F" | b"f*" | b"B" | b"B*" | b"b" | b"b*" | b"S" | b"s" => {
                self.paths = true;
            }
            _ => {}
        }
        self.last_source = Some(source);
        if !operator.marked.iter().any(|m| m.actual_text.is_some())
            && let Some(at) = self.actual_at.take()
        {
            self.close_actual(at);
        }
    }

    fn show(&mut self, show: &TextShow<'_>) -> (f32, f32) {
        let Some(font) = self.fonts.get(&show.font) else {
            return (0.0, 0.0);
        };
        let state = show.state;
        let vertical = font.vertical();
        let scale = if vertical {
            1.0
        } else {
            state.horizontal_scaling
        };
        let [a, b, c, d, _, _] = show.matrix;
        let size = state.size * d.hypot(c);
        let skewed =
            (a * c + b * d).abs() > 1e-3 * (a.hypot(b) * c.hypot(d)).max(f32::MIN_POSITIVE);
        // The outermost sequence's text stands for everything inside it.
        let actual = show
            .marked
            .iter()
            .find_map(|marked| marked.actual_text.as_deref())
            .filter(|text| {
                self.actual_at.is_some()
                    || self.actual_bytes.saturating_add(text.len()) <= ACTUAL_TEXT_LIMIT
            });
        let show_index = self.shows;
        self.shows = self.shows.saturating_add(1);
        let key = (show.span.source, show.span.range.start);
        if let Some(lang) = show.marked.iter().rev().find_map(|m| m.lang.as_ref()) {
            self.show_languages.insert(key, lang.clone());
        }
        if let Some(mcid) = show.marked.iter().rev().find_map(|m| m.mcid) {
            self.show_mcids.insert(key, mcid);
        }
        let mut advance = 0.0_f32;
        let mut index = 0_usize;
        for item in show.items {
            let bytes = match item {
                ShowItem::Adjust(n) => {
                    advance -= n / 1000.0 * state.size * scale;
                    if let Some(last) = self
                        .glyphs
                        .last_mut()
                        .filter(|glyph| glyph.show == show_index)
                    {
                        last.adjust += n;
                    }
                    continue;
                }
                ShowItem::Text(bytes) => bytes,
            };
            for (code, length) in font.codes(bytes) {
                let space = length == 1 && code == 32;
                let word_spacing = if space { state.word_spacing } else { 0.0 };
                let spacing = state.char_spacing + word_spacing;
                let (origin, step) = if vertical {
                    (
                        [0.0, advance],
                        font.vertical_advance(code, length) * state.size + spacing,
                    )
                } else {
                    (
                        [advance, state.rise],
                        (font.width(code, length) * state.size + spacing) * scale,
                    )
                };
                let reach = if vertical {
                    [0.0, advance + step]
                } else {
                    [advance + step, state.rise]
                };
                let opens = actual
                    .filter(|_| self.actual_at.is_none())
                    .map(str::to_owned);
                if let Some(text) = &opens {
                    self.actual_at = Some(self.glyphs.len());
                    self.actual_bytes = self.actual_bytes.saturating_add(text.len());
                }
                self.glyphs.push(Glyph {
                    covered: actual.is_some() && opens.is_none(),
                    actual: opens,
                    text: font.text(code),
                    start: apply(show.matrix, origin),
                    end: apply(show.matrix, reach),
                    size,
                    vertical,
                    ascent: font.ascent,
                    descent: font.descent,
                    link: GlyphLink {
                        span: show.span.clone(),
                        index,
                    },
                    code,
                    length,
                    offset: advance,
                    step,
                    show: show_index,
                    font: show.font,
                    render_mode: state.render_mode,
                    space,
                    word_spacing,
                    adjust: 0.0,
                    char_spacing: state.char_spacing,
                    skewed,
                });
                index = index.saturating_add(1);
                advance += step;
            }
        }
        if vertical {
            (0.0, advance)
        } else {
            (advance, 0.0)
        }
    }
}

/// A point of text space in page space.
fn apply(m: Matrix, [x, y]: [f32; 2]) -> [f32; 2] {
    let [a, b, c, d, e, f] = m;
    [x * a + y * c + e, x * b + y * d + f]
}

/// The glyphs as lines in content order.
pub(crate) fn lines(glyphs: &[Glyph]) -> Vec<Line> {
    line_groups(glyphs).iter().map(|line| words(line)).collect()
}

/// The glyphs, with their indices, grouped into lines by baseline in content order.
pub(crate) fn line_groups(glyphs: &[Glyph]) -> Vec<Vec<(usize, &Glyph)>> {
    let mut out: Vec<Vec<(usize, &Glyph)>> = Vec::new();
    for (at, glyph) in glyphs.iter().enumerate() {
        let joins = out
            .last()
            .and_then(|line| line.last())
            .is_some_and(|(_, last)| {
                let size = last.size.max(glyph.size);
                if last.vertical {
                    (glyph.start[0] - last.start[0]).abs() < size * 0.6
                        && glyph.start[1] < last.start[1] + size
                } else {
                    (glyph.start[1] - last.start[1]).abs() < size * 0.5
                        && glyph.start[0] > last.start[0] - size
                }
            });
        match out.last_mut() {
            Some(line) if joins => line.push((at, glyph)),
            _ => out.push(vec![(at, glyph)]),
        }
    }
    out
}

/// One line's characters, with spaces at word gaps, in logical order.
pub(crate) fn words(line: &[(usize, &Glyph)]) -> Line {
    let rtl = line
        .iter()
        .any(|(_, glyph)| glyph.reads().chars().any(right_to_left));
    // A combining mark comes before its base in a right-to-left line's visual order; it stays
    // with that base. Such a line is read left to right, as it shows, whatever order drew it.
    let mut units: Vec<(Vec<&Glyph>, usize, &Glyph)> = Vec::new();
    let mut marks = Vec::new();
    for &(at, glyph) in line {
        if rtl && !glyph.reads().is_empty() && glyph.reads().chars().all(is_mark) {
            marks.push((at, glyph));
        } else {
            let marks = std::mem::take(&mut marks)
                .into_iter()
                .map(|(_, mark)| mark)
                .collect();
            units.push((marks, at, glyph));
        }
    }
    if rtl && !line.iter().any(|(_, glyph)| glyph.vertical) {
        units.sort_by(|(_, _, a), (_, _, b)| a.start[0].total_cmp(&b.start[0]));
    }
    let mut visual: Line = Vec::new();
    // `/ActualText` is logical already: one character stands for it through the reordering.
    let mut actual: HashMap<usize, &str> = HashMap::new();
    let mut previous: Option<&Glyph> = None;
    for (marks, at, glyph) in &units {
        if let Some(last) = previous.filter(|_| !glyph.covered) {
            let gap = if last.vertical {
                last.end[1] - glyph.start[1]
            } else {
                glyph.start[0] - last.end[0]
            };
            let spaced = visual.last().is_some_and(|(c, _)| c.is_whitespace())
                || glyph.reads().starts_with(char::is_whitespace);
            if !spaced && gap > glyph.size.max(last.size) * WORD_GAP {
                visual.push((' ', None));
            }
        }
        let area = Some(*at);
        if let Some(text) = &glyph.actual {
            for mark in marks {
                visual.extend(mark.reads().chars().map(|c| (c, area)));
            }
            if let Some(stand_in) = stand_in(text) {
                visual.push((stand_in, area));
                actual.insert(*at, text);
            }
        } else {
            let logical = with_marks(glyph, marks);
            // A right-to-left unit is reversed here, so reading the line back restores it.
            if logical.chars().any(right_to_left) {
                visual.extend(logical.chars().rev().map(|c| (c, area)));
            } else {
                visual.extend(logical.chars().map(|c| (c, area)));
            }
        }
        previous = Some(glyph);
    }
    for (at, mark) in marks {
        visual.extend(mark.reads().chars().map(|c| (c, Some(at))));
    }
    let read = if rtl { logical(&visual) } else { visual };
    if actual.is_empty() {
        return read;
    }
    read.into_iter()
        .flat_map(|(c, area)| {
            let text = area.and_then(|at| actual.get(&at).copied());
            let chars: Vec<char> = text.map_or_else(|| vec![c], |text| text.chars().collect());
            chars.into_iter().map(move |c| (c, area))
        })
        .collect()
}

/// The character whose direction stands for `text`: its first strong one, or its first.
fn stand_in(text: &str) -> Option<char> {
    text.chars()
        .find(|&c| matches!(bidi_class(c), BidiClass::L | BidiClass::R | BidiClass::AL))
        .or_else(|| text.chars().next())
}

/// The box a glyph covers in page space, `[left, bottom, right, top]`: its advance across, and
/// from its font's descent below the baseline to its ascent above; a vertical glyph is an em
/// wide.
pub(crate) fn glyph_box(glyph: &Glyph) -> CharBox {
    let [x0, y0] = glyph.start;
    let [x1, y1] = glyph.end;
    let size = glyph.size;
    if glyph.vertical {
        [x0 - size / 2.0, y0.min(y1), x0 + size / 2.0, y0.max(y1)]
    } else {
        [
            x0.min(x1),
            y0 + size * glyph.descent,
            x0.max(x1),
            y0 + size * glyph.ascent,
        ]
    }
}

/// A right-to-left glyph's text in logical order with the marks drawn on it. On a ligature
/// (lam-alef, ta-ra) a mark goes after the letter it sits over, whose share of the width holds it
/// (the first letter is on the right), or before an alef.
fn with_marks(glyph: &Glyph, marks: &[&Glyph]) -> String {
    let letters: Vec<char> = glyph.reads().chars().collect();
    let last = letters.len().saturating_sub(1);
    let width = glyph.end[0] - glyph.start[0];
    let mut after: Vec<Vec<char>> = vec![Vec::new(); letters.len().max(1)];
    for mark in marks {
        let from_left = if width > 0.0 {
            ((mark.start[0] - glyph.start[0]) / width).clamp(0.0, 1.0)
        } else {
            0.0
        };
        // Truncation picks the letter whose share of the width holds the mark.
        #[allow(
            clippy::cast_possible_truncation,
            clippy::cast_sign_loss,
            clippy::cast_precision_loss
        )]
        let mut letter = (((1.0 - from_left) * letters.len() as f32) as usize).min(last);
        // Tanween on an alef is typed before it (ISO 8859-6 practice, "ًا").
        if letter > 0 && letters.get(letter) == Some(&'ا') {
            letter = letter.saturating_sub(1);
        }
        if let Some(slot) = after.get_mut(letter) {
            slot.extend(mark.reads().chars());
        }
    }
    letters
        .iter()
        .zip(after)
        .flat_map(|(&letter, marks)| std::iter::once(letter).chain(marks))
        .collect()
}

/// Whether `c` is a combining mark (bidi class NSM).
fn is_mark(c: char) -> bool {
    bidi_class(c) == BidiClass::NSM
}

/// Whether `c` is a strong right-to-left character.
pub(crate) fn right_to_left(c: char) -> bool {
    matches!(bidi_class(c), BidiClass::R | BidiClass::AL)
}

/// A right-to-left line in visual order, read back into logical order with each character's box,
/// its brackets mirrored at right-to-left levels.
///
/// The algorithm's rules look back along the typed text, so it runs on the line from the right:
/// a number after Arabic letters is an Arabic number whose "%" stays outside it (W2, W5), and a
/// bracket takes its direction from what comes before it (N0). Left-to-right runs come out
/// reversed, and are turned back.
fn logical(visual: &[(char, Option<usize>)]) -> Line {
    let text: String = stand_ins(visual).into_iter().rev().collect();
    let info = BidiInfo::new(&text, Some(Level::rtl()));
    let Some(paragraph) = info.paragraphs.first() else {
        return visual.to_vec();
    };
    // Levels per byte, then one per character, with the line rules (L1) applied.
    let levels = info.reordered_levels_per_char(paragraph, paragraph.range.clone());
    let typed: Vec<((char, Option<usize>), bool)> = visual
        .iter()
        .rev()
        .zip(&levels)
        .map(|(&(c, area), level)| {
            let rtl = level.is_rtl();
            ((if rtl { mirror(c) } else { c }, area), rtl)
        })
        .collect();
    typed
        .chunk_by(|(_, a), (_, b)| a == b)
        .flat_map(|run| {
            let rtl = run.first().is_some_and(|&(_, rtl)| rtl);
            let chars = run.iter().map(|&(item, _)| item);
            if rtl {
                chars.collect::<Vec<_>>()
            } else {
                chars.rev().collect()
            }
        })
        .collect()
}

/// What the algorithm reads for each character of a visual line, one for one, in the same order:
/// brackets as typed (a right-to-left line shows them mirrored), a paragraph separator as a space
/// (the line is one paragraph), and a number that stands right of Latin letters as a letter.
/// "ISO 9001" and the typed "9001 ISO" draw alike; the left-to-right reading is the common one,
/// and from the right the number would come first and lose the letters' context.
fn stand_ins(visual: &[(char, Option<usize>)]) -> Vec<char> {
    let mut latin = false;
    let mut digit = false;
    visual
        .iter()
        .map(|&(c, _)| {
            let class = bidi_class(c);
            let joins = match class {
                BidiClass::L => {
                    latin = true;
                    false
                }
                BidiClass::EN => latin,
                // A sign is part of a Latin number after its digits only.
                BidiClass::ET => {
                    latin = latin && digit;
                    latin
                }
                BidiClass::WS | BidiClass::CS | BidiClass::ES => false,
                _ => {
                    latin = false;
                    false
                }
            };
            digit = class == BidiClass::EN;
            match class {
                _ if joins => 'a',
                BidiClass::B => ' ',
                _ => mirror(c),
            }
        })
        .collect()
}

/// The bracket that mirrors `c`, or `c`.
pub(crate) fn mirror(c: char) -> char {
    match c {
        '(' => ')',
        ')' => '(',
        '[' => ']',
        ']' => '[',
        '{' => '}',
        '}' => '{',
        '<' => '>',
        '>' => '<',
        '«' => '»',
        '»' => '«',
        other => other,
    }
}

/// A horizontal glyph at `start`, 10 points in size, for tests.
#[cfg(test)]
pub(crate) fn test_glyph(text: &str, start: [f32; 2]) -> Glyph {
    Glyph {
        text: text.to_owned(),
        start,
        end: start,
        size: 10.0,
        vertical: false,
        ascent: 0.8,
        descent: -0.2,
        link: GlyphLink {
            span: Span {
                source: SpanSource::Page { stream: (1, 0) },
                range: 0..0,
                carried: false,
            },
            index: 0,
        },
        code: 0,
        length: 1,
        offset: 0.0,
        step: 0.0,
        show: 0,
        font: 0,
        render_mode: 0,
        space: text == " ",
        word_spacing: 0.0,
        adjust: 0.0,
        char_spacing: 0.0,
        skewed: false,
        actual: None,
        covered: false,
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    fn glyph(text: &str, x: f32, y: f32) -> Glyph {
        Glyph {
            end: [x + 5.0, y],
            ..test_glyph(text, [x, y])
        }
    }

    fn text(lines: Vec<Line>) -> Vec<String> {
        lines
            .into_iter()
            .map(|line| line.into_iter().map(|(c, _)| c).collect())
            .collect()
    }

    #[test]
    fn a_type1_font_without_an_encoding_reads_through_its_program() {
        let program = b"/Encoding 256 array 0 1 255 {1 index exch /.notdef put} for
dup 65 /Gbreve put dup 66 /idieresis put readonly def currentfile eexec";
        let mut resource = FontResource {
            key: 1,
            kind: FontKind::Type1,
            base_font: Some("ABCDEF+Test".to_owned()),
            base_encoding: None,
            differences: Vec::new(),
            first_char: 0,
            widths: Vec::new(),
            missing_width: 0.0,
            symbolic: false,
            font_matrix: [0.001, 0.0, 0.0, 0.001, 0.0, 0.0],
            to_unicode: None,
            font_program: Some(program.to_vec()),
            ascent: 0.0,
            descent: 0.0,
            font_bbox: None,
            cmap_name: None,
            cmap: None,
            cmap_parents: Vec::new(),
            cid_widths: Vec::new(),
            default_width: 1000.0,
            vertical_metrics: Vec::new(),
            default_vertical: [880.0, -1000.0],
            cid_to_gid: None,
            char_procs: Vec::new(),
        };
        let font = PdfFont::new(&resource);
        // The program's codes, and nothing of StandardEncoding's.
        assert_eq!([font.text(65), font.text(66)], ["Ğ", "ï"]);
        assert_eq!(font.text(67), "\u{FFFD}");
        // /Differences go on top of the built-in encoding.
        resource.differences = vec![(66, "Scedilla".to_owned())];
        let font = PdfFont::new(&resource);
        assert_eq!([font.text(65), font.text(66)], ["Ğ", "Ş"]);
    }

    #[test]
    fn a_composite_font_joins_its_usecmap_parents_and_its_own_codes_win() {
        let child = b"/CIDInit /ProcSet findresource begin 12 dict begin begincmap
1 begincodespacerange <0000> <FFFF> endcodespacerange
1 begincidchar <0001> 100 endcidchar endcmap";
        let parent = b"/CIDInit /ProcSet findresource begin 12 dict begin begincmap
1 begincodespacerange <0000> <FFFF> endcodespacerange
2 begincidchar <0001> 7 <0002> 200 endcidchar endcmap";
        let resource = FontResource {
            key: 1,
            kind: FontKind::Type0,
            base_font: None,
            base_encoding: None,
            differences: Vec::new(),
            first_char: 0,
            widths: Vec::new(),
            missing_width: 0.0,
            symbolic: false,
            font_matrix: [0.001, 0.0, 0.0, 0.001, 0.0, 0.0],
            to_unicode: None,
            font_program: None,
            ascent: 0.0,
            descent: 0.0,
            font_bbox: None,
            cmap_name: None,
            cmap: Some(child.to_vec()),
            cmap_parents: vec![parent.to_vec()],
            cid_widths: Vec::new(),
            default_width: 1000.0,
            vertical_metrics: Vec::new(),
            default_vertical: [880.0, -1000.0],
            cid_to_gid: None,
            char_procs: Vec::new(),
        };
        let font = PdfFont::new(&resource);
        let cmap = font.cmap.as_ref().unwrap();
        // The child's own code wins; the parent's other code comes through.
        assert_eq!(cmap.cid(1, 2), Some(100));
        assert_eq!(cmap.cid(2, 2), Some(200));
        // And back: the parent's shadowed CID has no code.
        assert_eq!(cmap.code_for_cid(200), Some((2, 2)));
        assert_eq!(cmap.code_for_cid(7), None);
        assert!(font.cmap_known);

        // A CIDToGIDMap stream maps CIDs to glyphs, and back; without one a CID is its glyph.
        let program =
            include_bytes!("../../../app/assets/fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf");
        let mapped = PdfFont::new(&FontResource {
            cid_to_gid: Some(vec![0, 0, 0, 5, 0, 3]),
            font_program: Some(program.to_vec()),
            ..resource.clone()
        });
        let parsed = mapped.program().unwrap();
        assert_eq!(mapped.cid_glyph(&parsed, 1), Some(GlyphId(5)));
        assert_eq!(mapped.cid_glyph(&parsed, 0), None, ".notdef");
        assert_eq!(mapped.cid_glyph(&parsed, 3), None, "past the map");
        assert_eq!(mapped.glyph_cid(&parsed, GlyphId(3)), Some(2));
        assert_eq!(mapped.glyph_cid(&parsed, GlyphId(4)), None);
        let identity = PdfFont::new(&FontResource {
            font_program: Some(program.to_vec()),
            ..resource.clone()
        });
        assert_eq!(identity.cid_glyph(&parsed, 3), Some(GlyphId(3)));
        assert_eq!(identity.glyph_cid(&parsed, GlyphId(3)), Some(3));
        // A predefined CMap Ferman does not bundle reads as Identity-H, and is known not to be
        // the font's.
        let unknown = PdfFont::new(&FontResource {
            cmap: None,
            cmap_parents: Vec::new(),
            cmap_name: Some(b"GBK-EUC-H".to_vec()),
            ..resource
        });
        assert!(!unknown.cmap_known);
    }

    #[test]
    fn glyph_boxes_take_the_font_ascent_and_descent() {
        let font = |base: &str, kind: FontKind| FontResource {
            key: 1,
            kind,
            base_font: Some(base.to_owned()),
            base_encoding: None,
            differences: Vec::new(),
            first_char: 0,
            widths: Vec::new(),
            missing_width: 0.0,
            symbolic: false,
            font_matrix: [0.01, 0.0, 0.0, 0.01, 0.0, 0.0],
            to_unicode: None,
            font_program: None,
            ascent: 0.0,
            descent: 0.0,
            font_bbox: None,
            cmap_name: None,
            cmap: None,
            cmap_parents: Vec::new(),
            cid_widths: Vec::new(),
            default_width: 1000.0,
            vertical_metrics: Vec::new(),
            default_vertical: [880.0, -1000.0],
            cid_to_gid: None,
            char_procs: Vec::new(),
        };
        let close = |got: (f32, f32), want: (f32, f32)| {
            assert!(
                (got.0 - want.0).abs() < 1e-6 && (got.1 - want.1).abs() < 1e-6,
                "{got:?} {want:?}"
            );
        };
        // Nothing known: four fifths up, one fifth down.
        close(
            ascent_descent(&font("Unknown", FontKind::TrueType)),
            (0.8, -0.2),
        );
        // A standard 14 font, subset tag or not.
        close(
            ascent_descent(&font("ABCDEF+Helvetica-Bold", FontKind::Type1)),
            (0.718, -0.207),
        );
        // The standard metrics win over the box; without them the box counts, and the
        // descriptor wins over both.
        let mut boxed = font("Helvetica", FontKind::Type1);
        boxed.font_bbox = Some([0.0, -300.0, 1000.0, 900.0]);
        close(ascent_descent(&boxed), (0.718, -0.207));
        boxed.base_font = None;
        close(ascent_descent(&boxed), (0.9, -0.3));
        boxed.ascent = 750.0;
        boxed.descent = -250.0;
        close(ascent_descent(&boxed), (0.75, -0.25));
        // A Type3 font's box is in its glyph space, scaled by its font matrix.
        let mut type3 = font("", FontKind::Type3);
        type3.base_font = None;
        type3.font_bbox = Some([0.0, -10.0, 100.0, 70.0]);
        close(ascent_descent(&type3), (0.7, -0.1));
        // A damaged program falls through to what the descriptor says.
        boxed.font_program = Some(b"not a font".to_vec());
        close(ascent_descent(&boxed), (0.75, -0.25));
        // Metrics beyond four ems are not believed.
        boxed.ascent = 1.0e9;
        close(ascent_descent(&boxed), (0.9, -0.3));
        let glyph = Glyph {
            end: [10.0, 100.0],
            ascent: 0.75,
            descent: -0.25,
            ..test_glyph("a", [0.0, 100.0])
        };
        assert_eq!(glyph_box(&glyph), [0.0, 97.5, 10.0, 107.5]);
    }

    #[test]
    fn glyphs_become_words_and_lines() {
        let glyphs = [
            glyph("K", 0.0, 700.0),
            glyph("i", 5.0, 700.0),
            glyph("r", 30.0, 700.0),
            glyph("a", 0.0, 680.0),
        ];
        assert_eq!(text(lines(&glyphs)), ["Ki r", "a"]);
    }

    #[test]
    fn a_right_to_left_line_reads_in_logical_order() {
        // "عام 2025 (جديد)" drawn in visual order, the ligature "لا" as one glyph.
        let visual = [
            "(", "د", "ي", "د", "ج", ")", " ", "2", "0", "2", "5", " ", "م", "ا", "ع",
        ];
        let glyphs: Vec<Glyph> = (0_u8..)
            .zip(visual)
            .map(|(i, text)| glyph(text, f32::from(i) * 5.0, 0.0))
            .collect();
        assert_eq!(text(lines(&glyphs)), ["عام 2025 (جديد)"]);
        let ligature = [glyph("لا", 0.0, 0.0), glyph("ب", 5.0, 0.0)];
        assert_eq!(text(lines(&ligature)), ["بلا"]);
    }

    /// A line as a generator draws it from the left, one glyph per character.
    fn drawn(visual: &str) -> Vec<Glyph> {
        (0_u8..)
            .zip(visual.chars())
            .map(|(i, c)| glyph(&c.to_string(), f32::from(i) * 5.0, 0.0))
            .collect()
    }

    #[test]
    fn a_right_to_left_line_is_read_from_the_right() {
        for (visual, typed) in [
            // A sign at the sentence's end: the number is an Arabic number (W2), the sign outside.
            (".%30 وحنب", "بنحو 30%."),
            (".%6.4 ىلإ %7.25 نم", "من 7.25% إلى 6.4%."),
            // The bracket opens after Arabic letters; the IBAN is a run of its own.
            ("JO14 AHCB 34 :(IBAN) يلودلا", "الدولي (IBAN): JO14 AHCB 34"),
            // Letters with digits stay one run, with a Latin number's sign after its digits.
            ("ISO 9001 ةداهش", "شهادة ISO 9001"),
            ("Price 30% off رعس", "سعر Price 30% off"),
            ("ىلإ A-1/2 نم", "من A-1/2 إلى"),
            // Hebrew digits are European numbers: the sign stays with them (W5).
            (".30% לש", "של 30%."),
            ("2,156,500 رانيد", "دينار 2,156,500"),
            ("20-10 نم", "من 10-20"),
        ] {
            assert_eq!(text(lines(&drawn(visual))), [typed], "{visual}");
        }
    }

    #[test]
    fn a_line_break_in_a_glyphs_text_stays_one_paragraph() {
        let glyphs = [
            glyph("ب", 0.0, 0.0),
            glyph("\n", 5.0, 0.0),
            glyph("ا", 10.0, 0.0),
        ];
        let read: Vec<char> = lines(&glyphs)[0].iter().map(|&(c, _)| c).collect();
        assert_eq!(read, ['ا', '\n', 'ب']);
    }

    #[test]
    fn actual_text_replaces_the_glyphs_it_covers() {
        let covered = |text: &str, x: f32| Glyph {
            covered: true,
            ..glyph(text, x, 0.0)
        };
        // In a right-to-left line it is logical already, whatever order drew it, and the words
        // around it read as they do; a gap inside the sequence is no word break.
        let glyphs = [
            Glyph {
                actual: Some("30%.".to_owned()),
                ..glyph("x", 0.0, 0.0)
            },
            covered("y", 20.0),
            glyph("ب", 30.0, 0.0),
        ];
        let line = &lines(&glyphs)[0];
        let read: String = line.iter().map(|&(c, _)| c).collect();
        assert_eq!(read, "ب 30%.");
        // Every character of it has the box of the glyph it sits on.
        assert_eq!(line.get(2), Some(&('3', Some(0))));
        // In a left-to-right line too; an empty one hides its glyphs.
        let glyphs = [
            glyph("a", 0.0, 0.0),
            Glyph {
                actual: Some("fi".to_owned()),
                ..glyph("x", 5.0, 0.0)
            },
            Glyph {
                actual: Some(String::new()),
                ..glyph("x", 10.0, 0.0)
            },
            covered("y", 15.0),
        ];
        assert_eq!(text(lines(&glyphs)), ["afi"]);
    }

    #[test]
    fn actual_text_counts_where_it_orders_the_glyphs_or_they_are_unknown() {
        let closed = |says: &str, first: &str, second: &str| {
            let mut collector = Collector {
                glyphs: vec![
                    Glyph {
                        actual: Some(says.to_owned()),
                        ..glyph(first, 0.0, 0.0)
                    },
                    Glyph {
                        covered: true,
                        ..glyph(second, 5.0, 0.0)
                    },
                ],
                actual_at: Some(0),
                ..Collector::default()
            };
            collector.finish();
            let [opens, follows] = collector.glyphs.as_slice() else {
                panic!("two glyphs");
            };
            assert_eq!(opens.actual.is_some(), follows.covered, "{says}");
            opens.actual.is_some()
        };
        assert!(closed("بن", "ن", "ب"), "the logical order");
        assert!(closed("xy", "\u{FFFD}", "b"), "unknown glyphs");
        assert!(!closed("a b", "a", "b"), "the same text and order");
        // An edit changed the glyphs; the old text no longer says what the page shows, even
        // with the same digits.
        assert!(!closed("cd", "a", "b"));
        assert!(!closed("ba", "a", "b"));
        assert!(!closed("", "a", "b"));
    }

    #[test]
    fn vertical_glyphs_make_columns() {
        let column = |x: f32, y: f32, text: &str| Glyph {
            end: [x, y - 10.0],
            vertical: true,
            ..test_glyph(text, [x, y])
        };
        let glyphs = [
            column(100.0, 700.0, "拝"),
            column(100.0, 690.0, "啓"),
            column(80.0, 700.0, "秋"),
        ];
        assert_eq!(text(lines(&glyphs)), ["拝啓", "秋"]);
    }
}
