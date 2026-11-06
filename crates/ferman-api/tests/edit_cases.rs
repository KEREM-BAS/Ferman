//! The pixel-diff acceptance cases of ROADMAP §7 that simple and composite fonts reach (W1 and
//! W2 of the M3 plan), through the engine crates the facade is built on: ferman-text rewrites a block, ferman-core's
//! splicer and incremental writer save it, the saved file is read back from disk, and
//! ferman-render's harness renders every page before and after at 72, 150 and 300 dpi
//! (docs/ARCHITECTURE.md §13.4).
//!
//! A case passes when:
//! - the original file is an exact prefix of the saved one, and the update's classic
//!   cross-reference table names the original's as `/Prev` and points at every object it lists;
//! - the update section holds only the edited content streams (or this page's copy of a shared
//!   one, or the copy of an edited form), the page objects that name a copy, the new Type0,
//!   CIDFont and ToUnicode objects of a font copy, the font dictionary (and ToUnicode) of a
//!   simple font copy with `/Differences`, the Type0, CIDFont, descriptor, program and ToUnicode
//!   of a new embedded font, and nothing else: every original font dictionary stays as it is;
//!   each edited stream's decoded bytes outside the replaced spans are identical (a placement's
//!   `Do` may only draw another name);
//! - PDFium opens the saved file with the same page count;
//! - on the edited page no pixel differs outside the union of the block's box before and after,
//!   grown by [`EDIT_MARGIN`] (M3 plan decision 6), and some pixel differs inside it at every
//!   resolution; on every other page no pixel differs at all. After Keep and warn the region is
//!   the box before alone: the hidden lines must draw nothing.
//!
//! The reflow cases (W2) give the whole new text: E06's three overflow choices on kira-tr, E07's
//! right-aligned amount on fatura-tr, E08's justified paragraphs on tez-tr, a paragraph that
//! loses a line and a composite-font paragraph on zh-hans.
//!
//! Each case prints a JSON report per page and resolution (case, page, dpi, region, differing
//! pixels, the margin they need, pixels outside and their bounds), the form `ferman verify-edit`
//! prints. A case that needs more than the margin fails with its report; the margin is never
//! widened. Saved files go to `FERMAN_SAVED_DIR` when it is set (qpdf checks them in CI), else to
//! the system's temp folder.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
//!
//! The missing-glyph cases (W3): E04's "ğ" through `/Differences` in a copy of its font (step 1);
//! kira-tr's Madde 6 typing a "ğ" its EB Garamond subset lacks, with the bundled fonts only (E02,
//! step 3: a chosen Plex candidate and "Keep as is") and with EB Garamond in the injected font
//! set (E03, step 2: a new Type0 font); edit-e05-fstype, whose fonts forbid embedding (E05, step 3
//! with the reason). The font libraries are filled from `app/assets/fonts` and
//! `build/corpus-fonts`, never from the machine's fonts.
//!
//! The right-to-left cases (W3), shaped in the bundled IBM Plex fonts: E09's Arabic word beside
//! report-ar's IBAN, in the subset's own glyphs and with marks the subset lacks (step 2); E10's
//! Persian word with a ZWNJ on fa-zwnj; E11's Hebrew paragraph reflowed on he-para.
//!
//! W5: step 3 for shaped text, with a similar font of the injected set (E09: the whole block when
//! the same font is not installed, one script's characters when it lacks them, the licence's
//! reason); a decomposed Hebrew letter, whose base also stands alone (E11); composed and shaped
//! Hangul on ko-para with Noto Sans KR's named Regular instance (E12).
//!
//! E25 (W4) edits the signed contract below the facade, as every case here does (the confirmation
//! a signed document needs is the facade's, tested in `edit.rs`), and checks that the signature's
//! `/ByteRange` still covers the same bytes and hashes to the digest its CMS holds.
//!
//! The panel's cases (a3-2, B016): one style at a time on kira-tr's Madde 3 and fatura-tr's price,
//! each laid out again in its frame and reopened from disk: size, colour, alignment, spacing, a
//! new font, a move and a resize that reflows.
//!
//! The vertical cases (W3, E13) on letter-ja-vertical: a date column's cells in its `Identity-V`
//! font, the body's last column one cell longer, and the upright "19" across its column, in the
//! subset's digits and in a new font of the installed Noto Serif JP's named Regular instance.
//!
//! The audit of ROADMAP §7 (W5): every case E01 to E26 is here, at the three resolutions. E14, E17
//! and E18 run on generated stand-ins (`edit-e14-latex-standin`, `edit-e17-kerned-standin`,
//! `edit-e18-columns-standin`) until the owner's real files come; a stand-in passing says nothing
//! about the producers' real output. E24 runs with the password: the update's bytes are encrypted,
//! so its byte check compares the operators each revision's interpreter reads.
//! `every_font_type_and_encoding_is_in_a_case` names the case for each font type and encoding of
//! the acceptance criteria.
// Test helpers fail loudly.
#![allow(
    clippy::panic,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects,
    clippy::print_stderr
)]

use std::collections::BTreeMap;
use std::ops::Range;
use std::path::PathBuf;
use std::sync::{Arc, OnceLock};

use ferman_api::facade::block_on;
use ferman_core::filters::{DecodeParams, Filter, decode};
use ferman_core::interpret::{OperatorEvent, Span, SpanSource, TextShow, TextSink};
use ferman_core::revision::{Placement, RevisionStore, Splice};
use ferman_core::{Document, OpenOptions, Password, Source, open};
use ferman_fonts::{FontLibrary, FontOrigin, ScanLimits};
use ferman_render::{
    EDIT_MARGIN, PdfiumStatus, RESOLUTIONS, RenderConfig, RenderThread, compare, device_region,
    render_page,
};
use ferman_text::{
    Alignment, BlockFont, BlockStyle, Choice, EditContext, ExtendBlocked, FontChoice, FontSources,
    Frame, MissingReason, Outcome, SubstitutionKind, TextBlock, dependent_cells, paragraph_text,
    rewrite_block_fonts, rewrite_block_styled, rewrite_block_with, text_page,
};
use serde_json::json;

type ObjectId = (u32, u16);

/// A replaced range of a stream's decoded data and its bytes; none for a placement's `Do`.
type Edit = (Range<usize>, Option<Vec<u8>>);

/// The edits by stream.
type Edits = BTreeMap<ObjectId, Vec<Edit>>;

/// A form, the `Do` that drew it and its shows' origins.
type Drawn = (ObjectId, Span, Vec<(f32, f32)>);

/// One render thread for the whole test binary: one render thread of a process may hold PDFium.
fn render() -> &'static RenderThread {
    static RENDER: OnceLock<RenderThread> = OnceLock::new();
    RENDER.get_or_init(|| {
        let library = std::env::var_os("FERMAN_PDFIUM_PATH")
            .filter(|value| !value.is_empty())
            .expect("FERMAN_PDFIUM_PATH must name the PDFium library (tools/pdfium/fetch.sh)");
        let render = RenderThread::start(RenderConfig {
            pdfium_library: Some(PathBuf::from(library)),
            // Every render is compared once; caching tiles only costs memory.
            tile_cache_bytes: 0,
            ..RenderConfig::default()
        })
        .unwrap();
        assert!(matches!(
            block_on(render.status()).unwrap(),
            PdfiumStatus::Loaded { .. }
        ));
        render
    })
}

fn corpus(name: &str) -> Vec<u8> {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"));
    std::fs::read(path).unwrap()
}

fn saved_dir() -> PathBuf {
    let dir = std::env::var_os("FERMAN_SAVED_DIR")
        .filter(|dir| !dir.is_empty())
        .map_or_else(
            || std::env::temp_dir().join("ferman-edit-cases"),
            PathBuf::from,
        );
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

fn intersects(a: [f32; 4], b: [f32; 4]) -> bool {
    a[0] < b[2] && b[0] < a[2] && a[1] < b[3] && b[1] < a[3]
}

/// Each form's shows by placement: the `Do` of a page stream that drew them, and where their
/// origins are in displayed points.
struct Placements<'a> {
    document: &'a Document,
    page: usize,
    pending: Vec<(ObjectId, (f32, f32))>,
    found: Vec<Drawn>,
}

impl TextSink for Placements<'_> {
    fn font(&mut self, _font: &ferman_core::interpret::FontResource) {}

    fn show(&mut self, show: &TextShow<'_>) -> (f32, f32) {
        if let SpanSource::Form { form } = show.span.source {
            let page = &self.document.structure().pages[self.page];
            let origin = page.display_point(show.matrix[4], show.matrix[5]);
            self.pending.push((form, origin));
        }
        (0.0, 0.0)
    }

    fn operator(&mut self, operator: &OperatorEvent<'_>) {
        if operator.name == b"Do" && matches!(operator.span.source, SpanSource::Page { .. }) {
            let mut forms: BTreeMap<ObjectId, Vec<(f32, f32)>> = BTreeMap::new();
            for (form, origin) in self.pending.drain(..) {
                forms.entry(form).or_default().push(origin);
            }
            for (form, origins) in forms {
                self.found.push((form, operator.span.clone(), origins));
            }
        }
    }
}

/// The placement of `form` whose shows lie nearest the block's box.
fn placement(document: &Document, page: usize, form: ObjectId, bbox: [f32; 4]) -> Placement {
    let mut sink = Placements {
        document,
        page,
        pending: Vec::new(),
        found: Vec::new(),
    };
    document.page_text(page, &mut sink).unwrap();
    let away = |(x, y): (f32, f32)| {
        let dx = (bbox[0] - x).max(x - bbox[2]).max(0.0);
        let dy = (bbox[1] - y).max(y - bbox[3]).max(0.0);
        dx.max(dy)
    };
    let (_, draw, _) = sink
        .found
        .into_iter()
        .filter(|(id, _, _)| *id == form)
        .min_by(|a, b| {
            let near =
                |origins: &[(f32, f32)]| origins.iter().map(|&o| away(o)).fold(f32::MAX, f32::min);
            near(&a.2).total_cmp(&near(&b.2))
        })
        .unwrap_or_else(|| panic!("no placement of form {form:?}"));
    Placement { form, draw }
}

/// One object of a file `tools/corpus` writes or of an update section ferman-core writes: a
/// direct `/Length`, Flate or no filter.
struct Object {
    id: ObjectId,
    dict: Vec<u8>,
    raw: Option<Vec<u8>>,
}

impl Object {
    fn is(&self, key: &[u8]) -> bool {
        self.dict.windows(key.len()).any(|window| window == key)
    }

    /// The decoded stream data.
    fn data(&self) -> Vec<u8> {
        let raw = self.raw.as_ref().expect("a stream");
        if self.is(b"FlateDecode") {
            decode(Filter::Flate, &DecodeParams::default(), raw, u64::MAX).unwrap()
        } else {
            raw.clone()
        }
    }
}

fn find(hay: &[u8], needle: &[u8], from: usize) -> Option<usize> {
    hay.get(from..)?
        .windows(needle.len())
        .position(|window| window == needle)
        .map(|at| at + from)
}

fn digits(bytes: &[u8], at: &mut usize) -> Option<u64> {
    let start = *at;
    while bytes.get(*at).is_some_and(u8::is_ascii_digit) {
        *at += 1;
    }
    std::str::from_utf8(&bytes[start..*at]).ok()?.parse().ok()
}

/// The object whose `N G obj` header starts at `at`, and where the next one may start.
fn object_at(pdf: &[u8], mut at: usize) -> Option<(Object, usize)> {
    while pdf.get(at).is_some_and(u8::is_ascii_whitespace) {
        at += 1;
    }
    let number = u32::try_from(digits(pdf, &mut at)?).ok()?;
    at += 1;
    let generation = u16::try_from(digits(pdf, &mut at)?).ok()?;
    if pdf.get(at..at + 4)? != b" obj" {
        return None;
    }
    let body = at + 4;
    let end = find(pdf, b"endobj", body)?;
    let keyword = find(pdf, b"stream", body).filter(|&keyword| keyword < end);
    let Some(keyword) = keyword else {
        let object = Object {
            id: (number, generation),
            dict: pdf[body..end].to_vec(),
            raw: None,
        };
        return Some((object, end + b"endobj".len()));
    };
    let dict = pdf[body..keyword].to_vec();
    let mut length_at = find(&dict, b"/Length", 0)? + b"/Length".len();
    // Not a font program's `/Length1`.
    while dict.get(length_at).is_some_and(u8::is_ascii_digit) {
        length_at = find(&dict, b"/Length", length_at)? + b"/Length".len();
    }
    while dict.get(length_at).is_some_and(u8::is_ascii_whitespace) {
        length_at += 1;
    }
    let length = usize::try_from(digits(&dict, &mut length_at)?).ok()?;
    let mut data = keyword + b"stream".len();
    if pdf.get(data) == Some(&b'\r') {
        data += 1;
    }
    if pdf.get(data) == Some(&b'\n') {
        data += 1;
    }
    let raw = pdf.get(data..data + length)?.to_vec();
    let next = find(pdf, b"endobj", data + length)? + b"endobj".len();
    let object = Object {
        id: (number, generation),
        dict,
        raw: Some(raw),
    };
    Some((object, next))
}

/// Every object of an update section, up to its cross-reference section.
fn section_objects(section: &[u8]) -> Vec<Object> {
    let mut objects = Vec::new();
    let mut at = 0;
    while let Some((object, next)) = object_at(section, at) {
        objects.push(object);
        at = next;
    }
    objects
}

/// Object `id` of the original file, which has one revision.
fn original_object(pdf: &[u8], id: ObjectId) -> Option<Object> {
    let header = format!("\n{} {} obj", id.0, id.1);
    let at = pdf
        .windows(header.len())
        .position(|window| window == header.as_bytes())?;
    object_at(pdf, at + 1).map(|(object, _)| object)
}

/// Whether `new` is `old` with `edits` applied: each range replaced by its bytes, or, for a
/// placement's `Do` (no bytes), by `/<name> Do`. Every other byte must be the same.
fn kept_outside(old: &[u8], new: &[u8], edits: &[Edit]) -> bool {
    let mut edits: Vec<&Edit> = edits.iter().collect();
    edits.sort_by_key(|(range, _)| range.start);
    let (mut at, mut cursor) = (0, 0);
    for (range, bytes) in edits {
        let Some(kept) = old.get(at..range.start) else {
            return false;
        };
        if new.get(cursor..cursor + kept.len()) != Some(kept) {
            return false;
        }
        cursor += kept.len();
        match bytes {
            Some(bytes) => {
                if !new[cursor..].starts_with(bytes) {
                    return false;
                }
                cursor += bytes.len();
            }
            None => {
                if new.get(cursor) != Some(&b'/') {
                    return false;
                }
                cursor += 1;
                while new.get(cursor).is_some_and(|&byte| {
                    !byte.is_ascii_whitespace() && !b"/[]<>()%".contains(&byte)
                }) {
                    cursor += 1;
                }
                if !new[cursor..].starts_with(b" Do") {
                    return false;
                }
                cursor += b" Do".len();
            }
        }
        at = range.end;
    }
    old.get(at..) == new.get(cursor..)
}

/// The offset after the last `startxref`.
fn startxref(pdf: &[u8]) -> Option<usize> {
    let mut at = pdf.windows(9).rposition(|window| window == b"startxref")? + 9;
    while pdf.get(at).is_some_and(u8::is_ascii_whitespace) {
        at += 1;
    }
    usize::try_from(digits(pdf, &mut at)?).ok()
}

/// The update's cross-reference section: a classic table after the original, `/Prev` naming the
/// original's, and every entry in use pointing at its object's header (readers repair a wrong
/// offset silently, so the renders cannot catch one).
fn xref_problems(original: &[u8], saved: &[u8]) -> Vec<String> {
    let (Some(prev), Some(xref)) = (startxref(original), startxref(saved)) else {
        return vec!["no startxref".to_owned()];
    };
    // shortcut: the update of a file with a cross-reference stream is a stream too, which this
    // check does not parse; CI's qpdf --check reads it.
    if original.get(prev..prev + 4) != Some(b"xref") {
        return Vec::new();
    }
    if xref < original.len() || saved.get(xref..xref + 4) != Some(b"xref") {
        return vec![format!(
            "startxref {xref} is not a classic table in the update"
        )];
    }
    let trailer = find(saved, b"trailer", xref).unwrap_or(saved.len());
    let mut problems = Vec::new();
    let named = find(saved, b"/Prev", trailer).map(|at| {
        let mut at = at + b"/Prev".len();
        while saved.get(at).is_some_and(u8::is_ascii_whitespace) {
            at += 1;
        }
        digits(saved, &mut at)
    });
    if named != Some(u64::try_from(prev).ok()) {
        problems.push(format!("the trailer's /Prev is not {prev}"));
    }
    let table = String::from_utf8_lossy(&saved[xref + 4..trailer]);
    let mut lines = table
        .lines()
        .map(str::split_whitespace)
        .map(Iterator::collect::<Vec<_>>);
    while let Some(header) = lines.next() {
        let [first, count] = header[..] else {
            continue;
        };
        let (first, count): (u32, u32) = (first.parse().unwrap(), count.parse().unwrap());
        for number in first..first + count {
            let entry = lines.next().unwrap_or_default();
            let [offset, generation, "n"] = entry[..] else {
                continue;
            };
            let offset: usize = offset.parse().unwrap();
            let header = format!(
                "{number} {} obj",
                generation.trim_start_matches('0').max("0")
            );
            if !saved[offset.min(saved.len())..].starts_with(header.as_bytes()) {
                problems.push(format!(
                    "the xref entry of object {number} points at {offset}"
                ));
            }
        }
    }
    problems
}

/// The new objects `rewrite`'s fonts take: three per composite copy, one per simple copy and its
/// ToUnicode, five per new font.
fn font_objects(rewrite: &ferman_text::Rewrite) -> usize {
    3 * rewrite.fonts.len()
        + rewrite
            .simple_fonts
            .iter()
            .map(|copy| 1 + usize::from(copy.to_unicode.is_some()))
            .sum::<usize>()
        + 5 * rewrite.new_fonts.len()
}

/// The byte checks of the module documentation, for an edit whose fonts take `fonts` new
/// objects; the problems found.
fn byte_problems(original: &[u8], saved: &[u8], edits: &Edits, fonts: usize) -> Vec<String> {
    if !saved.starts_with(original) {
        return vec!["the original is not a prefix of the saved file".to_owned()];
    }
    let mut problems = xref_problems(original, saved);
    let mut landed: Vec<ObjectId> = Vec::new();
    let objects = section_objects(&saved[original.len()..]);
    let copies = objects
        .iter()
        .filter(|object| original_object(original, object.id).is_none())
        .count();
    let mut font_objects = 0;
    for object in &objects {
        let old = original_object(original, object.id);
        let font = object.is(b"/Type /Font") || object.is(b"/Type/Font");
        let to_unicode = object.raw.is_some() && {
            let data = object.data();
            data.windows(9).any(|window| window == b"begincmap")
        };
        let descriptor = object.is(b"/FontDescriptor");
        let program =
            object.raw.is_some() && (object.is(b"/Length1") || object.is(b"CIDFontType0C"));
        if old.is_none() && fonts > 0 && (font || to_unicode || descriptor || program) {
            font_objects += 1;
            continue;
        }
        if object.raw.is_none() {
            let page = old
                .as_ref()
                .is_some_and(|old| old.is(b"/Type /Page") || old.is(b"/Type/Page"))
                && !old.as_ref().is_some_and(|old| old.is(b"/Pages"));
            if !page || copies == 0 {
                problems.push(format!("object {:?} rewritten", object.id));
            }
            continue;
        }
        if object.is(b"/XRef") {
            continue;
        }
        let sources: Vec<ObjectId> = match &old {
            Some(_) if edits.contains_key(&object.id) => vec![object.id],
            Some(_) => {
                problems.push(format!("stream {:?} rewritten", object.id));
                continue;
            }
            None => edits.keys().copied().collect(),
        };
        let new = object.data();
        let matched = sources.into_iter().find(|source| {
            let old = original_object(original, *source).unwrap().data();
            kept_outside(&old, &new, &edits[source])
        });
        match matched {
            Some(source) => landed.push(source),
            None => problems.push(format!(
                "stream {:?} changed outside the replaced spans",
                object.id
            )),
        }
    }
    if font_objects != fonts {
        problems.push(format!("{font_objects} new font objects, {fonts} expected"));
    }
    for source in edits.keys() {
        if !landed.contains(source) {
            problems.push(format!(
                "the edit of stream {source:?} is not in the update"
            ));
        }
    }
    problems
}

/// Rewrites the block with `from` on `page` of corpus file `file` to say `to`, saves it, and
/// runs every check; panics with the reports when one fails.
fn case(name: &str, file: &str, page: usize, from: &str, to: &str) {
    let (saved, problems) = saved_case(name, corpus(file), page, from, to);
    rendered_case(name, &saved, problems, page, to);
}

/// What [`saved_case`] keeps for [`rendered_case`].
struct Saved {
    original: Vec<u8>,
    doc: Document,
    block: TextBlock,
    path: PathBuf,
    rewrite: ferman_text::Rewrite,
    password: Option<&'static str>,
}

/// How a corpus file with `password` opens.
fn options(password: Option<&str>) -> OpenOptions {
    OpenOptions {
        password: password.map(|password| Password::new(password.to_owned())),
        ..OpenOptions::default()
    }
}

/// [`case`] up to the save: rewrites, applies the font copies and splices in one transaction,
/// writes the incremental update and runs the byte checks.
fn saved_case(
    name: &str,
    original: Vec<u8>,
    page: usize,
    from: &str,
    to: &str,
) -> (Saved, Vec<String>) {
    let lines = |block: &TextBlock| {
        block
            .lines
            .iter()
            .map(|line| line.text.replacen(from, to, 1))
            .collect::<Vec<_>>()
            .join("\n")
    };
    saved_text(
        name,
        original,
        page,
        from,
        &lines,
        None,
        &FontSources::default(),
    )
}

/// [`saved_case`] for the block with `needle`, given the whole new text and an overflow choice:
/// a reflow when the text is not one piece per line of a left-aligned or justified block.
fn saved_text(
    name: &str,
    original: Vec<u8>,
    page: usize,
    needle: &str,
    text_of: &dyn Fn(&TextBlock) -> String,
    choice: Option<Choice>,
    sources: &FontSources<'_>,
) -> (Saved, Vec<String>) {
    saved_styled(
        name,
        original,
        page,
        needle,
        text_of,
        choice,
        sources,
        &BlockStyle::default(),
    )
}

/// [`saved_text`] with the block's style changed (a3-2).
#[allow(clippy::too_many_arguments)]
fn saved_styled(
    name: &str,
    original: Vec<u8>,
    page: usize,
    needle: &str,
    text_of: &dyn Fn(&TextBlock) -> String,
    choice: Option<Choice>,
    sources: &FontSources<'_>,
    style: &BlockStyle,
) -> (Saved, Vec<String>) {
    let doc = open(
        &Source::from_bytes(Arc::from(original.as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    let blocks = text_page(&doc, page, &EditContext::default())
        .unwrap()
        .blocks;
    let block: TextBlock = blocks
        .iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains(needle)))
        .cloned()
        .unwrap_or_else(|| panic!("{name}: no block with {needle:?}"));
    let text = text_of(&block);
    let outcome = rewrite_block_styled(
        &doc, None, page, &block, &text, &blocks, choice, sources, style,
    )
    .unwrap();
    let Outcome::Rewritten(rewrite) = outcome else {
        panic!("{name}: {outcome:?}");
    };
    let mut edits = Edits::new();
    let mut splices = Vec::new();
    let mut placements: Vec<Placement> = Vec::new();
    for splice in rewrite.splices.clone() {
        let (SpanSource::Page { stream: id } | SpanSource::Form { form: id }) = splice.source;
        edits
            .entry(id)
            .or_default()
            .push((splice.range.clone(), Some(splice.bytes.clone())));
        if let SpanSource::Form { form } = splice.source
            && !placements.iter().any(|placement| placement.form == form)
        {
            let placement = placement(&doc, page, form, block.bbox);
            let SpanSource::Page { stream } = placement.draw.source else {
                unreachable!()
            };
            edits
                .entry(stream)
                .or_default()
                .push((placement.draw.range.clone(), None));
            placements.push(placement);
        }
        splices.push(Splice {
            source: splice.source,
            range: splice.range,
            bytes: splice.bytes,
        });
    }
    let mut store = RevisionStore::new(&doc);
    store.begin().unwrap();
    store
        .add_new_fonts(
            &doc,
            page,
            &rewrite.fonts,
            &rewrite.simple_fonts,
            &rewrite.new_fonts,
        )
        .unwrap();
    store.splice(&doc, page, &splices, &placements).unwrap();
    store.commit().unwrap();
    let path = saved_dir().join(format!("{name}.pdf"));
    std::fs::write(&path, store.incremental_update(&doc).unwrap()).unwrap();

    // Everything after this reads the saved file from disk.
    let saved = std::fs::read(&path).unwrap();
    let problems = byte_problems(&original, &saved, &edits, font_objects(&rewrite));
    let saved = Saved {
        original,
        doc,
        block,
        path,
        rewrite,
        password: None,
    };
    (saved, problems)
}

/// [`case`] after the save: reopens the saved file, finds the new text and compares the renders.
fn rendered_case(name: &str, saved_case: &Saved, mut problems: Vec<String>, page: usize, to: &str) {
    let Saved {
        original,
        doc,
        block,
        path,
        rewrite,
        password,
    } = saved_case;
    let saved = std::fs::read(path).unwrap();
    let after = open(&Source::read(path).unwrap(), &options(*password)).unwrap();
    let mut boxes = vec![block.bbox];
    let new_boxes: Vec<[f32; 4]> = text_page(&after, page, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .filter(|new| {
            intersects(new.bbox, block.bbox) && new.lines.iter().any(|l| l.text.contains(to))
        })
        .map(|new| new.bbox)
        .collect();
    if new_boxes.is_empty() {
        problems.push(format!("no block with {to:?} after the edit"));
    }
    // Keep and warn draws nothing past the old frame: its hidden lines are not in the region.
    if rewrite.chosen != Some(Choice::Keep) {
        boxes.extend(new_boxes);
    }

    let render = render();
    let user = || password.map(|password| Password::new(password.to_owned()));
    let before_pdf =
        block_on(render.open_document(Arc::from(original.as_slice()), user())).unwrap();
    let after_pdf = block_on(render.open_document(Arc::from(saved.as_slice()), user())).unwrap();
    if before_pdf.pages.len() != after_pdf.pages.len() || after.page_count() != doc.page_count() {
        problems.push(format!(
            "{} pages in PDFium after the save, {} before",
            after_pdf.pages.len(),
            before_pdf.pages.len()
        ));
    }
    let mut reports = Vec::new();
    // Each page at its own size after the save, so a changed size fails the comparison.
    for (index, (size, new_size)) in before_pdf.pages.iter().zip(&after_pdf.pages).enumerate() {
        let number = u32::try_from(index).unwrap();
        for dpi in RESOLUTIONS {
            let old = block_on(render_page(render, before_pdf.id, number, *size, dpi)).unwrap();
            let new = block_on(render_page(render, after_pdf.id, number, *new_size, dpi)).unwrap();
            let region = (index == page)
                .then(|| device_region(&boxes, old.scale))
                .flatten();
            let rect = |rect: Option<ferman_render::PixelRect>| {
                rect.map(|r| json!({"x": r.x, "y": r.y, "width": r.width, "height": r.height}))
            };
            let Some(diff) = compare(&old, &new, region, EDIT_MARGIN) else {
                problems.push(format!("page {index} at {dpi} dpi changed size"));
                continue;
            };
            if index == page && diff.differing == 0 {
                problems.push(format!("page {index} at {dpi} dpi: the edit drew nothing"));
            }
            if !diff.passed() {
                problems.push(format!(
                    "page {index} at {dpi} dpi: {} pixels outside",
                    diff.outside
                ));
            }
            reports.push(json!({
                "case": name,
                "page": index,
                "dpi": dpi,
                "region": rect(region),
                "margin": EDIT_MARGIN,
                "differing": diff.differing,
                "margin_needed": diff.margin_needed,
                "outside": diff.outside,
                "outside_bounds": rect(diff.outside_bounds),
                "passed": diff.passed(),
            }));
        }
    }
    block_on(render.close_document(before_pdf.id)).unwrap();
    block_on(render.close_document(after_pdf.id)).unwrap();
    let reports = serde_json::Value::Array(reports).to_string();
    eprintln!("{reports}");
    assert!(problems.is_empty(), "{name}: {problems:?}\n{reports}");
}

/// A block's language draws nothing: no pixel of any page differs (a3-14).
#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_block_language_changes_no_pixel() {
    let original = corpus("kira-tr");
    let doc = open(
        &Source::from_bytes(Arc::from(original.as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    let blocks = text_page(&doc, 0, &EditContext::default()).unwrap().blocks;
    let block = blocks
        .iter()
        .find(|block| block.lines.len() > 1 && block.editability.is_editable())
        .unwrap();
    let splices = ferman_text::with_language(&doc, None, 0, block, "en-GB", Vec::new())
        .unwrap()
        .unwrap();
    assert_eq!(splices.len() % 2, 0);
    let splices: Vec<Splice> = splices
        .into_iter()
        .map(|splice| Splice {
            source: splice.source,
            range: splice.range,
            bytes: splice.bytes,
        })
        .collect();
    let mut store = RevisionStore::new(&doc);
    store.begin().unwrap();
    store.splice(&doc, 0, &splices, &[]).unwrap();
    store.commit().unwrap();
    let saved = store.incremental_update(&doc).unwrap();
    assert_eq!(saved.get(..original.len()), Some(original.as_slice()));

    let after = open(
        &Source::from_bytes(Arc::from(saved.as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    let marked = text_page(&after, 0, &EditContext::default())
        .unwrap()
        .blocks;
    assert_eq!(marked.len(), blocks.len());
    for (new, old) in marked.iter().zip(&blocks) {
        assert_eq!(new.text(), old.text());
        let language = (new.text() == block.text()).then_some("en-GB");
        assert_eq!(new.language.as_deref(), language);
    }

    let render = render();
    let before_pdf = block_on(render.open_document(Arc::from(original.as_slice()), None)).unwrap();
    let after_pdf = block_on(render.open_document(Arc::from(saved.as_slice()), None)).unwrap();
    for (index, size) in before_pdf.pages.iter().enumerate() {
        let number = u32::try_from(index).unwrap();
        for dpi in RESOLUTIONS {
            let old = block_on(render_page(render, before_pdf.id, number, *size, dpi)).unwrap();
            let new = block_on(render_page(render, after_pdf.id, number, *size, dpi)).unwrap();
            let diff = compare(&old, &new, None, 0).unwrap();
            assert_eq!(diff.differing, 0, "page {index} at {dpi} dpi");
        }
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e01_kira_tr_amount_in_a_subset_truetype() {
    case("e01-kira-tr", "kira-tr", 0, "18.500", "19.500");
}

/// The hexadecimal string `hex`, `<` and `>` included, as bytes; the padding stays.
fn hex_string(hex: &[u8]) -> Vec<u8> {
    let digit = |byte: u8| char::from(byte).to_digit(16).unwrap() as u8;
    hex.strip_prefix(b"<")
        .and_then(|hex| hex.strip_suffix(b">"))
        .unwrap()
        .as_chunks::<2>()
        .0
        .iter()
        .map(|&[high, low]| digit(high) * 16 + digit(low))
        .collect()
}

/// The SHA-256 the signer's `messageDigest` attribute holds: the first one in the CMS (a
/// timestamp's own comes after it, in the unsigned attributes), found by its DER form: the OID
/// 1.2.840.113549.1.9.4, then a SET of one OCTET STRING of 32 bytes.
fn message_digest(cms: &[u8]) -> &[u8] {
    const ATTRIBUTE: &[u8] = &[
        0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x04, 0x31, 0x22, 0x04, 0x20,
    ];
    let at = find(cms, ATTRIBUTE, 0).expect("the CMS has a messageDigest attribute");
    &cms[at + ATTRIBUTE.len()..at + ATTRIBUTE.len() + 32]
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e25_a_signed_range_survives_an_incremental_save() {
    let name = "e25-kira-tr-signed";
    let original = corpus("kira-tr-signed");
    let (saved, problems) = saved_case(name, original.clone(), 0, "18.500", "19.500");
    let file = std::fs::read(&saved.path).unwrap();

    let structure = saved.doc.structure();
    assert!(structure.signed());
    let [start, first, second, last] = structure
        .signatures
        .iter()
        .find(|signature| signature.signed)
        .and_then(|signature| signature.byte_range)
        .unwrap()
        .map(|number| usize::try_from(number).unwrap());
    let end = second + last;
    assert_eq!(start, 0);
    assert!(file.len() > end, "the edit follows the signed bytes");
    assert_eq!(
        file[..end],
        original[..end],
        "the signed bytes are the same"
    );

    // The two ranges hash to the digest the signature signed.
    let mut signed = file[start..first].to_vec();
    signed.extend_from_slice(&file[second..end]);
    let signed = Source::from_bytes(signed.into());
    let cms = hex_string(&file[first..second]);
    assert_eq!(signed.sha256().as_slice(), message_digest(&cms));

    // The revision the signature covers still opens as it was, and the new file still says it
    // is signed.
    let old = open(
        &Source::from_bytes(file[..end].to_vec().into()),
        &OpenOptions::default(),
    )
    .unwrap();
    assert_eq!(old.page_count(), saved.doc.page_count());
    assert!(old.repair().is_none());
    assert!(
        text_page(&old, 0, &EditContext::default())
            .unwrap()
            .blocks
            .iter()
            .any(|block| block.lines.iter().any(|line| line.text.contains("18.500")))
    );
    let new = open(&Source::from_bytes(file.into()), &OpenOptions::default()).unwrap();
    assert!(new.structure().signed());

    rendered_case(name, &saved, problems, 0, "19.500");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e04_file_edited_within_win_ansi() {
    case(
        "e04-win-ansi",
        "edit-e04-differences",
        0,
        "Moda Cad. No: 18",
        "Moda Cd. 18",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e04_a_glyph_without_a_code_takes_one_through_differences() {
    let rewrite = glyph_case(
        "e04-differences",
        "edit-e04-differences",
        "Kira bedeli",
        &|block| joined(block, "\n").replacen("Kira bedeli", "Kira değeri", 1),
        &FontSources::default(),
        "Kira değeri",
    );
    assert_eq!(rewrite.simple_fonts.len(), 1);
    assert!(rewrite.new_fonts.is_empty() && rewrite.substitutions.is_empty());
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e02_step_3_draws_a_chosen_bundled_font_and_keeps_the_closest() {
    let library = library(None);
    let ask = FontSources {
        library: Some(&library),
        ask: true,
        choice: None,
        ..FontSources::default()
    };
    let doc = open(
        &Source::from_bytes(Arc::from(corpus("kira-tr").as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    let block = text_page(&doc, 0, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| block.text().contains("Olağan bakım"))
        .unwrap();
    let text = joined(&block, " ") + MADDE_6;
    // "Ask each time": the choice first, nothing written.
    let outcome = rewrite_block_fonts(&doc, None, 0, &block, &text, &[], None, &ask).unwrap();
    let Outcome::MissingGlyphs(missing) = outcome else {
        panic!("{outcome:?}");
    };
    assert_eq!(missing.reason, MissingReason::NotInstalled);
    let plex = missing
        .candidates
        .iter()
        .find(|c| c.origin == FontOrigin::Bundled && c.family == "IBM Plex Serif")
        .unwrap()
        .postscript_name
        .clone();
    let chosen = FontChoice::Font {
        origin: FontOrigin::Bundled,
        postscript_name: plex.clone(),
    };
    let rewrite = glyph_case(
        "e02-kira-tr-chosen",
        "kira-tr",
        "Olağan bakım",
        &|block| joined(block, " ") + MADDE_6,
        &FontSources {
            choice: Some(&chosen),
            ..ask
        },
        "değiştirilemez",
    );
    assert_eq!(rewrite.new_fonts.len(), 1);
    assert_eq!(rewrite.substitutions[0].kind, SubstitutionKind::Similar);
    assert_eq!(rewrite.substitutions[0].to, plex);
    assert!(rewrite.pending.is_none());
    let keep = FontChoice::KeepAsIs;
    let rewrite = glyph_case(
        "e02-kira-tr-keep",
        "kira-tr",
        "Olağan bakım",
        &|block| joined(block, " ") + MADDE_6,
        &FontSources {
            choice: Some(&keep),
            ..ask
        },
        "değiştirilemez",
    );
    assert_eq!(
        rewrite.substitutions[0].to,
        missing.candidates[0].postscript_name
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e02_the_third_choice_keeps_the_font_without_a_glyph() {
    let library = library(None);
    let rewrite = glyph_case(
        "e02-kira-tr-marked",
        "kira-tr",
        "Olağan bakım",
        &|block| joined(block, " ") + MADDE_6,
        &FontSources {
            library: Some(&library),
            mark: true,
            ..FontSources::default()
        },
        "değiştirilemez",
    );
    let [substitution] = rewrite.substitutions.as_slice() else {
        panic!("{:?}", rewrite.substitutions);
    };
    assert_eq!(substitution.kind, SubstitutionKind::Marked);
    assert_eq!(substitution.to, substitution.from);
    assert!(rewrite.new_fonts.is_empty() && rewrite.pending.is_none());
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e03_step_2_embeds_the_same_font_as_a_new_type0_font() {
    let library = library(Some(garamond()));
    let rewrite = glyph_case(
        "e03-kira-tr-installed",
        "kira-tr",
        "Olağan bakım",
        &|block| joined(block, " ") + MADDE_6,
        &FontSources {
            library: Some(&library),
            ask: true,
            choice: None,
            ..FontSources::default()
        },
        "değiştirilemez",
    );
    let [substitution] = rewrite.substitutions.as_slice() else {
        panic!("{:?}", rewrite.substitutions);
    };
    assert_eq!(substitution.kind, SubstitutionKind::SameFont);
    assert_eq!(substitution.to, "EBGaramond-Regular");
    assert!(rewrite.pending.is_none());
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e05_fs_type_falls_to_step_3_with_the_reason() {
    let library = library(Some(with_fs_type(garamond(), 2)));
    let text_of =
        |block: &TextBlock| joined(block, "\n").replacen("birlikte", "birlikte değişir", 1);
    let ask = FontSources {
        library: Some(&library),
        ask: true,
        choice: None,
        ..FontSources::default()
    };
    let doc = open(
        &Source::from_bytes(Arc::from(corpus("edit-e05-fstype").as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    let block = text_page(&doc, 0, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| block.text().contains("birlikte"))
        .unwrap();
    let outcome =
        rewrite_block_fonts(&doc, None, 0, &block, &text_of(&block), &[], None, &ask).unwrap();
    let Outcome::MissingGlyphs(missing) = outcome else {
        panic!("{outcome:?}");
    };
    assert!(
        matches!(missing.reason, MissingReason::NotEmbeddable { .. }),
        "{:?}",
        missing.reason
    );
    let keep = FontChoice::KeepAsIs;
    let rewrite = glyph_case(
        "e05-fstype",
        "edit-e05-fstype",
        "birlikte",
        &text_of,
        &FontSources {
            choice: Some(&keep),
            ..ask
        },
        "birlikte değişir",
    );
    assert_eq!(rewrite.substitutions[0].kind, SubstitutionKind::Similar);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e15_standard_14_helvetica() {
    case(
        "e15-helvetica",
        "edit-e15-helvetica",
        0,
        "Monday",
        "Wednesday",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e16_type3() {
    case("e16-type3", "edit-e16-type3", 0, "12 boxes", "21 boxes");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn mac_roman() {
    case("macroman", "edit-macroman", 0, "Müller", "Müllers");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e19_rotated_page() {
    case("e19-rotate", "edit-e19-rotate", 0, "Duyuru", "Duyurular");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e19_rotated_text() {
    // The line set with a rotating `Tm`, on the turned page.
    case(
        "e19-rotated-text",
        "edit-e19-rotate",
        0,
        "Selin Öztürk",
        "Selin Özrük",
    );
}

/// The decoded streams of the update section of `saved`.
fn update_streams(saved: &Saved) -> Vec<Vec<u8>> {
    let file = std::fs::read(&saved.path).unwrap();
    section_objects(&file[saved.original.len()..])
        .iter()
        .filter(|object| object.raw.is_some() && !object.is(b"/XRef"))
        .map(Object::data)
        .collect()
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e20_form_placed_twice() {
    case("e20-form-twice", "edit-e20-form-twice", 0, "ALINDI", "ALIN");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e21_actual_text() {
    let to = "0612 555";
    let (saved, problems) = saved_case(
        "e21-actualtext",
        corpus("edit-e21-actualtext"),
        0,
        "0216 555",
        to,
    );
    let streams = update_streams(&saved);
    assert!(
        streams.iter().any(|data| {
            find(data, b"/ActualText", 0)
                .and_then(|at| find(data, b"BDC", at))
                .and_then(|at| find(data, b"EMC", at))
                .is_some()
        }),
        "the marked content is kept"
    );
    rendered_case("e21-actualtext", &saved, problems, 0, to);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e22_two_streams() {
    let to = "duyurur";
    let (saved, problems) = saved_text(
        "e22-split-contents",
        corpus("edit-e22-split-contents"),
        0,
        "bildirir",
        // Both of the paragraph's lines, so the edit has spans in both streams.
        &|block| {
            joined(block, "\n")
                .replacen("Bina", "Bin", 1)
                .replacen("bildirir", to, 1)
        },
        None,
        &FontSources::default(),
    );
    let mut streams: Vec<_> = saved.rewrite.splices.iter().map(|s| s.source).collect();
    streams.dedup();
    assert_eq!(streams.len(), 2, "{streams:?}");
    rendered_case("e22-split-contents", &saved, problems, 0, to);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e23_shared_stream() {
    case(
        "e23-shared-contents",
        "edit-e23-shared-contents",
        0,
        "Duyuru",
        "Duyurular",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e26_inline_image() {
    let to = "Duyurular";
    let original = corpus("edit-e26-inline-image");
    let (saved, problems) = saved_case("e26-inline-image", original, 0, "Duyuru", to);
    // The image's samples, as the generator writes them.
    let mut image = b"BI\n/W 16\n/H 16\n/BPC 8\n/CS /G\nID ".to_vec();
    for y in 0u8..16 {
        for x in 0u8..16 {
            image.push(0x80 + (x + y) * 4);
        }
    }
    image.extend_from_slice(b"\nEI\n");
    let streams = update_streams(&saved);
    assert!(
        streams.iter().any(|data| find(data, &image, 0).is_some()),
        "the inline image's bytes are kept"
    );
    rendered_case("e26-inline-image", &saved, problems, 0, to);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e12_japanese_identity_h() {
    case("e12-ja-para", "ja-para", 0, "十九万五千円", "十五万九千円");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e12_zh_hans_identity_h() {
    case(
        "e12-zh-hans",
        "zh-hans",
        0,
        "一万九千五百元",
        "一万五千九百元",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e12_zh_hant_identity_h() {
    case("e12-zh-hant", "zh-hant", 0, "十一月十五日", "十一月五十日");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e12_ko_para_justified_by_tj() {
    case("e12-ko-para", "ko-para", 0, "11월 30일에", "11월 03일에");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e12_japanese_predefined_cmap() {
    case(
        "e12-90ms-rksj",
        "edit-90ms-rksj",
        0,
        "マンションの",
        "ションマンの",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn cff_cid_font() {
    case("cff-cid", "edit-cff-cid", 0, "2 Kasım 2026", "6 Kasım 2022");
}

/// Edits the right-to-left block with `needle` on `page` of `file`, `from` replaced by `to`,
/// shaped in the bundled fonts; the saved file must read back with `check` (the new text as
/// extraction gives it). Returns the rewrite.
fn rtl_case(
    name: &str,
    file: &str,
    page: usize,
    needle: &str,
    (from, to): (&str, &str),
    check: &str,
) -> ferman_text::Rewrite {
    let library = library(None);
    let sources = FontSources {
        library: Some(&library),
        ..FontSources::default()
    };
    let text_of = |block: &TextBlock| {
        let text = joined(block, "\n");
        assert!(text.contains(from), "{name}: {text:?}");
        text.replacen(from, to, 1)
    };
    let (saved, problems) = saved_text(name, corpus(file), page, needle, &text_of, None, &sources);
    rendered_case(name, &saved, problems, page, check);
    saved.rewrite
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e09_report_ar_lam_alef_reads_back_as_its_letters() {
    // Lam-alef is one glyph in the subset; the saved page reads back the two logical letters.
    rtl_case(
        "e09-report-ar-lam-alef",
        "report-ar",
        9,
        "(IBAN)",
        ("الدولي", "الاستقلال"),
        "رقم الحساب الاستقلال",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e09_report_ar_word_beside_the_iban() {
    // The IBAN and "(IBAN)" stay left to right; the new word's forms are the subset's own.
    let rewrite = rtl_case(
        "e09-report-ar",
        "report-ar",
        9,
        "(IBAN)",
        ("الدولي", "الجمعية"),
        "رقم الحساب الجمعية",
    );
    assert!(rewrite.new_fonts.is_empty());
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e09_report_ar_marks_the_subset_lacks_from_the_same_font() {
    let rewrite = rtl_case(
        "e09-report-ar-marks",
        "report-ar",
        9,
        "(IBAN)",
        ("الدولي", "الدُّوَلِيّ"),
        "الحساب الدُّوَلِيّ",
    );
    assert_eq!(rewrite.new_fonts.len(), 1);
    assert_eq!(rewrite.substitutions.len(), 1);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e10_fa_zwnj_persian_word_with_a_non_joiner() {
    // The non-joiner is not written, as in the document's own words.
    rtl_case(
        "e10-fa-zwnj",
        "fa-zwnj",
        0,
        "برای هماهنگی",
        ("تماس بگیرید", "تماس بگیرید که پاسخ داده می\u{200C}شود"),
        "پاسخ داده میشود",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e11_he_para_sentence_reflows_right_to_left() {
    rtl_case(
        "e11-he-para",
        "he-para",
        0,
        "השוכרים מתבקשים",
        ("לשנה נוספת.", "לשנה נוספת, ולשלם עד יום 15 בחודש."),
        "15 בחודש",
    );
}

/// The bundled face `path` of `app/assets/fonts` as the font set's only one.
fn only(faces: &[Vec<u8>]) -> FontLibrary {
    let mut library = FontLibrary::new();
    for face in faces {
        library
            .add_bytes(face.clone(), FontOrigin::Bundled)
            .unwrap();
    }
    library
}

fn bundled(path: &str) -> Vec<u8> {
    std::fs::read(root().join("app/assets/fonts").join(path)).unwrap()
}

const ARABIC_MEDIUM: &str = "ibm-plex-sans-arabic/IBMPlexSansArabic-Medium.ttf";
const ARABIC_REGULAR: &str = "ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf";
const HEBREW_MEDIUM: &str = "ibm-plex-sans-hebrew/IBMPlexSansHebrew-Medium.ttf";

/// The outcome of giving the block with `needle` of `file` page `page` the text `text_of` gives.
fn outcome_of(
    file: &str,
    page: usize,
    needle: &str,
    text_of: &dyn Fn(&TextBlock) -> String,
    sources: &FontSources<'_>,
) -> Outcome {
    let original = corpus(file);
    let doc = open(
        &Source::from_bytes(Arc::from(original.as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    let block = text_page(&doc, page, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains(needle)))
        .unwrap();
    rewrite_block_fonts(
        &doc,
        None,
        page,
        &block,
        &text_of(&block),
        &[],
        None,
        sources,
    )
    .unwrap()
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e09_step_3_shapes_in_a_similar_font_when_the_same_is_not_installed() {
    let library = only(&[bundled(ARABIC_MEDIUM)]);
    let new_word = |block: &TextBlock| joined(block, "\n").replacen("الدولي", "الجمعية", 1);
    // "Ask each time": the choice first, nothing written.
    let ask = FontSources {
        library: Some(&library),
        ask: true,
        mark: false,
        keep_lines: false,
        choice: None,
    };
    let outcome = outcome_of("report-ar", 9, "(IBAN)", &new_word, &ask);
    let Outcome::MissingGlyphs(missing) = outcome else {
        panic!("{outcome:?}");
    };
    assert_eq!(missing.reason, MissingReason::NotInstalled);
    assert_eq!(
        missing.candidates[0].postscript_name,
        "IBMPlexSansArabic-Medm"
    );
    assert!(missing.chars.iter().any(|&(c, _)| c == 'ج'));

    // Without asking the closest draws it, and the choice stays open.
    let sources = FontSources {
        library: Some(&library),
        ..FontSources::default()
    };
    let (saved, problems) = saved_text(
        "e09-similar-closest",
        corpus("report-ar"),
        9,
        "(IBAN)",
        &new_word,
        None,
        &sources,
    );
    rendered_case("e09-similar-closest", &saved, problems, 9, "الجمعية");
    assert!(saved.rewrite.pending.is_some());
    let [substitution] = saved.rewrite.substitutions.as_slice() else {
        panic!("{:?}", saved.rewrite.substitutions);
    };
    assert_eq!(substitution.kind, SubstitutionKind::Similar);
    assert_eq!(substitution.to, "IBMPlexSansArabic-Medm");

    // The choice is taken: no question left.
    let chosen = FontChoice::Font {
        origin: FontOrigin::Bundled,
        postscript_name: "IBMPlexSansArabic-Medm".to_owned(),
    };
    let (saved, problems) = saved_text(
        "e09-similar-chosen",
        corpus("report-ar"),
        9,
        "(IBAN)",
        &new_word,
        None,
        &FontSources {
            choice: Some(&chosen),
            ..ask
        },
    );
    rendered_case("e09-similar-chosen", &saved, problems, 9, "الجمعية");
    assert!(saved.rewrite.pending.is_none());
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e09_step_3_draws_only_the_characters_the_same_font_lacks() {
    // Hebrew in an Arabic block: the Arabic stays in the subset, the Hebrew in Plex Hebrew.
    let rewrite = rtl_case(
        "e09-hebrew-in-arabic",
        "report-ar",
        9,
        "(IBAN)",
        ("الدولي", "שלום"),
        "שלום",
    );
    let [substitution] = rewrite.substitutions.as_slice() else {
        panic!("{:?}", rewrite.substitutions);
    };
    assert_eq!(substitution.kind, SubstitutionKind::Similar);
    assert!(substitution.to.starts_with("IBMPlexSansHebrew"));
    assert_eq!(substitution.chars.chars().count(), 4);
    assert!(rewrite.pending.is_some());
}

#[test]
fn e09_a_licence_that_forbids_the_glyphs_sends_shaped_text_to_step_3() {
    let library = only(&[
        with_fs_type(bundled(ARABIC_REGULAR), 0x0002),
        bundled(ARABIC_MEDIUM),
    ]);
    let ask = FontSources {
        library: Some(&library),
        ask: true,
        mark: false,
        keep_lines: false,
        choice: None,
    };
    // Marks the subset lacks need the forbidden font.
    let marks = |block: &TextBlock| joined(block, "\n").replacen("الدولي", "الدُّوَلِيّ", 1);
    let outcome = outcome_of("report-ar", 9, "(IBAN)", &marks, &ask);
    let Outcome::MissingGlyphs(missing) = outcome else {
        panic!("{outcome:?}");
    };
    assert!(
        matches!(missing.reason, MissingReason::NotEmbeddable { .. }),
        "{:?}",
        missing.reason
    );
    assert!(!missing.candidates.is_empty());
    // The subset's own glyphs need no embedding, so the copy still shapes them.
    let word = |block: &TextBlock| joined(block, "\n").replacen("الدولي", "الجمعية", 1);
    let outcome = outcome_of("report-ar", 9, "(IBAN)", &word, &ask);
    let Outcome::Rewritten(rewrite) = outcome else {
        panic!("{outcome:?}");
    };
    assert!(rewrite.new_fonts.is_empty());
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e11_a_decomposed_letter_keeps_its_text() {
    // U+FB1D has no glyph of its own in Plex Hebrew: yod and hiriq, the character on the yod.
    let rewrite = rtl_case(
        "e11-decomposed",
        "he-para",
        0,
        "השוכרים מתבקשים",
        ("לשנה נוספת.", "לשנה נוספת \u{FB1D}."),
        "\u{FB1D}",
    );
    assert!(!rewrite.new_fonts.is_empty());
    // In a similar font every glyph is new, so the yod that also stands alone takes a second
    // font: ToUnicode is per code.
    let library = only(&[bundled(HEBREW_MEDIUM)]);
    let (saved, problems) = saved_text(
        "e11-decomposed-similar",
        corpus("he-para"),
        0,
        "השוכרים מתבקשים",
        &|block| joined(block, "\n").replacen("לשנה נוספת.", "לשנה נוספת \u{FB1D}.", 1),
        None,
        &FontSources {
            library: Some(&library),
            ..FontSources::default()
        },
    );
    rendered_case("e11-decomposed-similar", &saved, problems, 0, "\u{FB1D}");
    assert_eq!(saved.rewrite.new_fonts.len(), 2);
    assert_eq!(saved.rewrite.substitutions.len(), 1);
}

/// Noto Sans KR from `build/corpus-fonts`.
fn noto_kr() -> Vec<u8> {
    std::fs::read(root().join("build/corpus-fonts/NotoSansKR-VF.ttf"))
        .expect("build/corpus-fonts/NotoSansKR-VF.ttf (run tools/corpus/fetch-fonts.sh)")
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e12_ko_para_conjoining_jamo_compose_into_the_subset() {
    // "하" typed as its jamo: no font and no shaper needed.
    let (saved, problems) = saved_case(
        "e12-ko-composed",
        corpus("ko-para"),
        0,
        "연락해",
        "연락\u{1112}\u{1161}",
    );
    rendered_case("e12-ko-composed", &saved, problems, 0, "연락하");
    assert!(saved.rewrite.new_fonts.is_empty());
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e12_ko_para_old_hangul_is_shaped_in_the_named_instance() {
    // Old Hangul composes only through the font's GSUB; the file's Regular is a named instance
    // of the installed variable font, whose default is Thin.
    let library = library(Some(noto_kr()));
    let rewrite = glyph_case(
        "e12-ko-shaped",
        "ko-para",
        "연락해 주시기",
        &|block| joined(block, "\n").replacen("연락해", "연락\u{1112}\u{119E}\u{11AB}", 1),
        &FontSources {
            library: Some(&library),
            ..FontSources::default()
        },
        "\u{1112}\u{119E}\u{11AB}",
    );
    let [substitution] = rewrite.substitutions.as_slice() else {
        panic!("{:?}", rewrite.substitutions);
    };
    assert_eq!(substitution.kind, SubstitutionKind::SameFont);
    assert_eq!(substitution.to, "NotoSansKR-Regular");
    assert_eq!(rewrite.new_fonts.len(), 1);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e13_letter_ja_vertical_column_keeps_its_cells() {
    // Identity-V with /W2 and /DW2: the new character in the cell of the one it replaces.
    case(
        "e13-vertical-date",
        "letter-ja-vertical",
        0,
        "十月十三日",
        "十月十二日",
    );
    // The body's last column one character longer: the full stop down one cell.
    case(
        "e13-vertical-grows",
        "letter-ja-vertical",
        0,
        "です。",
        "でした。",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e13_letter_ja_vertical_upright_run() {
    // Tate-chu-yoko: "19" across its column, centred in its cell, in the subset's own digits.
    case("e13-upright", "letter-ja-vertical", 0, "19万", "91万");
    // "20": digits the subset lacks, in a new font of the installed Noto Serif JP chosen in step
    // 3 (the page's digits are half-width forms, so step 2 does not confirm the font), its named
    // Regular instance listed beside the variable font's default ExtraLight, compressed to one em
    // with Tz when wider.
    let library = library(Some(
        std::fs::read(root().join("build/corpus-fonts/NotoSerifJP-VF.ttf"))
            .expect("build/corpus-fonts/NotoSerifJP-VF.ttf (run tools/corpus/fetch-fonts.sh)"),
    ));
    let chosen = FontChoice::Font {
        origin: FontOrigin::Installed,
        postscript_name: "NotoSerifJP-Regular".to_owned(),
    };
    let rewrite = glyph_case(
        "e13-upright-step-3",
        "letter-ja-vertical",
        "19万",
        &|block| joined(block, "\n").replacen("19万", "20万", 1),
        &FontSources {
            library: Some(&library),
            ask: true,
            choice: Some(&chosen),
            ..FontSources::default()
        },
        "20万",
    );
    let [substitution] = rewrite.substitutions.as_slice() else {
        panic!("{:?}", rewrite.substitutions);
    };
    assert_eq!(substitution.kind, SubstitutionKind::Similar);
    assert_eq!(substitution.to, "NotoSerifJP-Regular");
    assert!(
        matches!(&rewrite.new_fonts[0].base_font, name if name.ends_with("+NotoSerifJP-Regular"))
    );
}

/// The block's lines joined as one paragraph by `joint`.
fn joined(block: &TextBlock, joint: &str) -> String {
    block
        .lines
        .iter()
        .map(|line| line.text.clone())
        .collect::<Vec<_>>()
        .join(joint)
}

/// Reflows the block with `needle` on `page` of `file` to `text_of`'s text with `choice`, saves
/// it and runs every check; `to` is in the new text only. Returns the rewrite.
fn reflow_case(
    name: &str,
    file: &str,
    page: usize,
    needle: &str,
    text_of: &dyn Fn(&TextBlock) -> String,
    choice: Option<Choice>,
    to: &str,
) -> ferman_text::Rewrite {
    let (saved, problems) = saved_text(
        name,
        corpus(file),
        page,
        needle,
        text_of,
        choice,
        &FontSources::default(),
    );
    rendered_case(name, &saved, problems, page, to);
    saved.rewrite
}

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

/// The fonts bundled with the app, and `installed` as installed fonts: the font set a case
/// injects, never the machine's.
fn library(installed: Option<Vec<u8>>) -> FontLibrary {
    let mut library = FontLibrary::new();
    library.add_dir(
        &root().join("app/assets/fonts"),
        FontOrigin::Bundled,
        &ScanLimits::default(),
    );
    if let Some(font) = installed {
        library.add_bytes(font, FontOrigin::Installed).unwrap();
    }
    library
}

/// EB Garamond from `build/corpus-fonts` (tools/corpus/fetch-fonts.sh).
fn garamond() -> Vec<u8> {
    std::fs::read(root().join("build/corpus-fonts/EBGaramond-VF.ttf"))
        .expect("build/corpus-fonts/EBGaramond-VF.ttf (run tools/corpus/fetch-fonts.sh)")
}

/// `font` with `OS/2.fsType` set to `fs_type`: an installed copy whose licence forbids embedding.
fn with_fs_type(mut font: Vec<u8>, fs_type: u16) -> Vec<u8> {
    let tables = u16::from_be_bytes([font[4], font[5]]) as usize;
    for at in (12..12 + 16 * tables).step_by(16) {
        if &font[at..at + 4] == b"OS/2" {
            let offset = u32::from_be_bytes(font[at + 8..at + 12].try_into().unwrap()) as usize;
            font[offset + 8..offset + 10].copy_from_slice(&fs_type.to_be_bytes());
            return font;
        }
    }
    panic!("no OS/2 table");
}

/// The sentence a3-3a types into Madde 6, whose "ğ" EB Garamond's subset lacks.
const MADDE_6: &str = " Ortak alan kuralları değiştirilemez.";

/// Saves the missing-glyph case `name`: the block with `needle` of `file` given `text_of`'s text
/// with `sources`, every check run; returns the rewrite.
fn glyph_case(
    name: &str,
    file: &str,
    needle: &str,
    text_of: &dyn Fn(&TextBlock) -> String,
    sources: &FontSources<'_>,
    to: &str,
) -> ferman_text::Rewrite {
    let (saved, problems) = saved_text(name, corpus(file), 0, needle, text_of, None, sources);
    rendered_case(name, &saved, problems, 0, to);
    saved.rewrite
}

/// How many lines the block with `to` has in case `name`'s saved file, and how many the block
/// with `needle` had in `file`.
fn line_counts(name: &str, file: &str, page: usize, needle: &str, to: &str) -> (usize, usize) {
    let count = |doc: &Document, text: &str| {
        text_page(doc, page, &EditContext::default())
            .unwrap()
            .blocks
            .into_iter()
            .find(|block| block.text().contains(text))
            .map_or(0, |block| block.lines.len())
    };
    let saved = Source::read(&saved_dir().join(format!("{name}.pdf"))).unwrap();
    let before = Source::from_bytes(Arc::from(corpus(file).as_slice()));
    (
        count(&open(&before, &OpenOptions::default()).unwrap(), needle),
        count(&open(&saved, &OpenOptions::default()).unwrap(), to),
    )
}

/// A sentence kira-tr's fonts draw, which takes Madde 3 and Madde 4 past their frames.
const SENTENCE: &str = " Kiracı, gecikme hâlinde kiraya verene yazılı bildirimde bulunur.";

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e06_keep_and_warn_hides_the_line_the_iban_line_leaves_no_room_for() {
    let rewrite = reflow_case(
        "e06-kira-tr-keep",
        "kira-tr",
        0,
        "aylık kira bedeli olan",
        &|block| joined(block, " ") + SENTENCE,
        None,
        "bildirimde bulunur",
    );
    let plan = rewrite.overflow.unwrap();
    assert_eq!(plan.over, 1);
    assert!(
        matches!(&plan.extend, Err(ExtendBlocked::Block { text, .. }) if text.starts_with("IBAN")),
        "{:?}",
        plan.extend
    );
    assert_eq!((rewrite.chosen, rewrite.hidden), (Some(Choice::Keep), 1));
    // The hidden line is still in the saved file's text.
    let saved = Source::read(&saved_dir().join("e06-kira-tr-keep.pdf")).unwrap();
    let text = ferman_text::extract::page_text(&open(&saved, &OpenOptions::default()).unwrap(), 0)
        .unwrap();
    assert!(text.contains("bildirimde bulunur."), "{text}");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e06_extend_grows_madde_3_into_the_free_space_below() {
    let rewrite = reflow_case(
        "e06-kira-tr-extend",
        "kira-tr",
        0,
        "Kira süresi 01.11.2026",
        &|block| joined(block, " ") + SENTENCE,
        Some(Choice::Extend),
        "bildirimde bulunur",
    );
    assert_eq!(rewrite.overflow.unwrap().extend.unwrap().lines, 1);
    assert_eq!((rewrite.chosen, rewrite.hidden), (Some(Choice::Extend), 0));
    assert_eq!(
        line_counts(
            "e06-kira-tr-extend",
            "kira-tr",
            0,
            "Kira süresi 01.11.2026",
            "bildirimde bulunur"
        ),
        (2, 3)
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e06_tighten_fits_madde_4_within_the_cap() {
    // The last line's word growing a letter at a time: the first overflow is less than a letter,
    // which tightening within the cap takes back.
    let doc = open(
        &Source::from_bytes(Arc::from(corpus("kira-tr").as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    let blocks = text_page(&doc, 0, &EditContext::default()).unwrap().blocks;
    let block = blocks
        .iter()
        .find(|block| block.text().contains("aylık kira bedeli olan"))
        .unwrap();
    let grown =
        |n: usize| joined(block, " ").replace("hesabına", &format!("hesab{}ına", "a".repeat(n)));
    let n = (1..80)
        .find(|&n| {
            let outcome =
                rewrite_block_with(&doc, None, 0, block, &grown(n), &blocks, None).unwrap();
            matches!(outcome, Outcome::Rewritten(ref rewrite)
                if rewrite.overflow.as_ref().is_some_and(|plan| plan.tighten.is_ok()))
        })
        .expect("an overflow that tightening fits");
    let rewrite = reflow_case(
        "e06-kira-tr-tighten",
        "kira-tr",
        0,
        "aylık kira bedeli olan",
        &|_| grown(n),
        Some(Choice::Tighten),
        "aaaı",
    );
    let percent = rewrite.overflow.unwrap().tighten.unwrap().percent;
    assert!(percent > 0.0 && percent <= ferman_text::TIGHTEN_CAP);
    assert_eq!((rewrite.chosen, rewrite.hidden), (Some(Choice::Tighten), 0));
}

/// A style case on kira-tr's Madde 3, whose free space below lets it grow.
fn style_case(name: &str, style: &BlockStyle, library: Option<&FontLibrary>) -> Saved {
    let sources = FontSources {
        library,
        ..FontSources::default()
    };
    let (saved, problems) = saved_styled(
        name,
        corpus("kira-tr"),
        0,
        "Kira süresi 01.11.2026",
        &paragraph_text,
        Some(Choice::Extend),
        &sources,
        style,
    );
    rendered_case(name, &saved, problems, 0, "Kira süresi");
    saved
}

/// The block with `needle` of page 0 of a saved case.
fn styled_block(name: &str, needle: &str) -> TextBlock {
    let saved = Source::read(&saved_dir().join(format!("{name}.pdf"))).unwrap();
    text_page(
        &open(&saved, &OpenOptions::default()).unwrap(),
        0,
        &EditContext::default(),
    )
    .unwrap()
    .blocks
    .into_iter()
    .find(|block| block.text().contains(needle))
    .unwrap()
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn style_a_new_size_scales_the_text_and_its_lines() {
    let before = Frame::of(&styled_original("Kira süresi 01.11.2026")).unwrap();
    style_case(
        "style-size",
        &BlockStyle {
            size: Some(before.size * 1.2),
            ..BlockStyle::default()
        },
        None,
    );
    let after = Frame::of(&styled_block("style-size", "Kira süresi")).unwrap();
    assert!((after.size - before.size * 1.2).abs() < 0.01, "{after:?}");
    assert!(after.pitch > before.pitch, "{after:?}");
}

fn styled_original(needle: &str) -> TextBlock {
    let doc = open(
        &Source::from_bytes(Arc::from(corpus("kira-tr").as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    text_page(&doc, 0, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| block.text().contains(needle))
        .unwrap()
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn style_a_colour_changes_the_block_and_nothing_after_it() {
    let saved = style_case(
        "style-colour",
        &BlockStyle {
            colour: Some(0x00C8_1E1E),
            ..BlockStyle::default()
        },
        None,
    );
    let splice = String::from_utf8_lossy(&saved.rewrite.splices[0].bytes).into_owned();
    assert!(splice.contains(" rg"), "{splice}");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn style_alignment_and_spacing() {
    style_case(
        "style-align",
        &BlockStyle {
            alignment: Some(Alignment::Right),
            ..BlockStyle::default()
        },
        None,
    );
    let block = styled_block("style-align", "Kira süresi");
    assert_eq!(block.alignment, Alignment::Right);
    style_case(
        "style-char",
        &BlockStyle {
            char_spacing: Some(2.0),
            ..BlockStyle::default()
        },
        None,
    );
    let before = Frame::of(&styled_original("Kira süresi 01.11.2026")).unwrap();
    style_case(
        "style-line",
        &BlockStyle {
            line_spacing: Some(before.pitch / before.size + 0.5),
            ..BlockStyle::default()
        },
        None,
    );
    let after = Frame::of(&styled_block("style-line", "Kira süresi")).unwrap();
    assert!(after.pitch > before.pitch + before.size * 0.4, "{after:?}");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn style_a_chosen_font_sets_the_whole_block() {
    let library = library(None);
    let bold = library
        .faces()
        .find(|face| face.family == "IBM Plex Sans" && face.weight >= 600 && !face.italic)
        .unwrap();
    let saved = style_case(
        "style-font",
        &BlockStyle {
            font: Some(BlockFont {
                origin: FontOrigin::Bundled,
                postscript_name: bold.postscript_name,
            }),
            ..BlockStyle::default()
        },
        Some(&library),
    );
    assert_eq!(saved.rewrite.new_fonts.len(), 1);
    assert!(saved.rewrite.substitutions.is_empty());
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn style_a_move_and_a_resize_that_reflows() {
    let original = styled_original("Kira süresi 01.11.2026");
    let [left, top, right, bottom] = original.bbox;
    style_case(
        "style-move",
        &BlockStyle {
            frame: Some([left + 12.0, top + 3.0, right + 12.0, bottom + 3.0]),
            ..BlockStyle::default()
        },
        None,
    );
    let moved = styled_block("style-move", "Kira süresi");
    assert!(
        (moved.bbox[0] - left - 12.0).abs() < 0.5,
        "{:?}",
        moved.bbox
    );
    assert!((moved.bbox[1] - top - 3.0).abs() < 0.5, "{:?}", moved.bbox);
    assert_eq!(moved.lines.len(), original.lines.len());

    let height = bottom - top;
    style_case(
        "style-resize",
        &BlockStyle {
            frame: Some([left, top, left + (right - left) * 0.6, top + height * 2.0]),
            ..BlockStyle::default()
        },
        None,
    );
    let narrow = styled_block("style-resize", "Kira süresi");
    assert!(narrow.lines.len() > original.lines.len());
    assert!(narrow.bbox[2] < right - 20.0, "{:?}", narrow.bbox);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e07_right_aligned_amount_keeps_its_edge_and_flags_the_totals() {
    let original = corpus("fatura-tr");
    let doc = open(
        &Source::from_bytes(Arc::from(original.as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    let page = text_page(&doc, 0, &EditContext::default()).unwrap();
    let price = page
        .blocks
        .iter()
        .find(|block| block.text() == "1.250,00")
        .unwrap();
    let flagged: Vec<String> = dependent_cells(&page, price.id)
        .into_iter()
        .map(|id| page.blocks.iter().find(|b| b.id == id).unwrap().text())
        .collect();
    assert_eq!(flagged, ["1.250,00", "22.950,00", "4.590,00", "27.540,00"]);
    let end = price.lines[0].baseline[1];
    reflow_case(
        "e07-fatura-tr",
        "fatura-tr",
        0,
        "1.250,00",
        &|_| "1.350,00".to_owned(),
        None,
        "1.350,00",
    );
    let saved = Source::read(&saved_dir().join("e07-fatura-tr.pdf")).unwrap();
    let after = text_page(
        &open(&saved, &OpenOptions::default()).unwrap(),
        0,
        &EditContext::default(),
    )
    .unwrap();
    let edited = after
        .blocks
        .iter()
        .find(|block| block.text() == "1.350,00")
        .unwrap();
    let new_end = edited.lines[0].baseline[1];
    assert!(
        (new_end[0] - end[0]).abs() < 0.05,
        "the right edge moved: {end:?} → {new_end:?}"
    );
    // The totals stay as they were: flagged, never changed.
    for total in ["22.950,00", "4.590,00", "27.540,00"] {
        assert!(after.blocks.iter().any(|block| block.text() == total));
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e08_justified_turkish_and_english_paragraphs_keep_their_method() {
    for (name, page, needle, from, to) in [
        (
            "e08-tez-tr-ozet",
            2,
            "Bu tez",
            "üç ilçesinde",
            "dört ilçesinde",
        ),
        (
            "e08-tez-tr-abstract",
            3,
            "This thesis",
            "three districts",
            "four districts",
        ),
    ] {
        let rewrite = reflow_case(
            name,
            "tez-tr",
            page,
            needle,
            &|block| joined(block, " ").replacen(from, to, 1),
            None,
            to,
        );
        assert_eq!(rewrite.overflow, None, "{name}");
        let saved = Source::read(&saved_dir().join(format!("{name}.pdf"))).unwrap();
        let before = open(
            &Source::from_bytes(Arc::from(corpus("tez-tr").as_slice())),
            &OpenOptions::default(),
        )
        .unwrap();
        let old = text_page(&before, page, &EditContext::default())
            .unwrap()
            .blocks
            .into_iter()
            .find(|block| block.text().contains(needle))
            .unwrap();
        let new = text_page(
            &open(&saved, &OpenOptions::default()).unwrap(),
            page,
            &EditContext::default(),
        )
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| block.text().contains(to))
        .unwrap();
        let ends = |block: &TextBlock| {
            block
                .lines
                .iter()
                .map(|line| (line.baseline[1][0], line.text.chars().count()))
                .collect::<Vec<_>>()
        };
        assert_eq!(
            new.alignment,
            ferman_text::Alignment::Justified,
            "{name}: {:?} {:?} → {:?}",
            old.justification,
            ends(&old),
            ends(&new)
        );
        assert_eq!(new.justification, old.justification, "{name}");
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_paragraph_shrinks_by_a_line() {
    let rewrite = reflow_case(
        "reflow-kira-tr-shrink",
        "kira-tr",
        0,
        "Kiraya veren: Mert Kaya",
        &|block| {
            joined(block, " ").replacen(
                " (T.C. Kimlik No: 41239876516), Bağdat Cad. No: 241/7",
                "",
                1,
            )
        },
        None,
        "Yılmaz, Maltepe",
    );
    assert_eq!(rewrite.overflow, None);
    assert_eq!(
        line_counts(
            "reflow-kira-tr-shrink",
            "kira-tr",
            0,
            "Kiraya veren: Mert Kaya",
            "Yılmaz, Maltepe"
        ),
        (3, 2)
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_composite_font_paragraph_reflows() {
    // zh-hans's notice in its Identity-H font, a clause shorter: two lines become one.
    let rewrite = reflow_case(
        "reflow-zh-hans",
        "zh-hans",
        0,
        "您好",
        &|block| joined(block, "").replacen("位于上海市徐汇区的", "", 1),
        None,
        "您目前租用的办公室",
    );
    assert_eq!(rewrite.overflow, None);
    assert_eq!(
        line_counts("reflow-zh-hans", "zh-hans", 0, "您好", "您目前租用的办公室"),
        (2, 1)
    );
}

/// A page with two blocks in one composite font, `/F1`: the full IBM Plex Sans as an
/// `Identity-H` `CIDFontType2` font whose `/W` and ToUnicode CMap hold only the glyphs the page
/// draws, as producers write them. Typing a character of the program the page does not draw
/// needs a copy of the font.
fn composite_pdf() -> Vec<u8> {
    composite_pdf_encoded("/Identity-H", Vec::new())
}

/// A stream object of [`pdf_of`].
fn stream_object(dict: &str, data: &[u8]) -> Vec<u8> {
    let mut out = format!("<< {dict} /Length {} >>\nstream\n", data.len()).into_bytes();
    out.extend_from_slice(data);
    out.extend_from_slice(b"\nendstream");
    out
}

/// A file of `objects`, numbered from 1, the first the catalog, with a classic table.
fn pdf_of(objects: &[Vec<u8>]) -> Vec<u8> {
    let mut pdf = b"%PDF-1.7\n".to_vec();
    let mut offsets = Vec::new();
    for (at, object) in objects.iter().enumerate() {
        offsets.push(pdf.len());
        pdf.extend_from_slice(format!("{} 0 obj\n", at + 1).as_bytes());
        pdf.extend_from_slice(object);
        pdf.extend_from_slice(b"\nendobj\n");
    }
    let xref = pdf.len();
    pdf.extend_from_slice(
        format!("xref\n0 {}\n0000000000 65535 f \n", objects.len() + 1).as_bytes(),
    );
    for offset in offsets {
        pdf.extend_from_slice(format!("{offset:010} 00000 n \n").as_bytes());
    }
    pdf.extend_from_slice(
        format!(
            "trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n",
            objects.len() + 1
        )
        .as_bytes(),
    );
    pdf
}

/// [`composite_pdf`] with `encoding` as the Type0 font's `/Encoding`, and `extra` objects from 10.
fn composite_pdf_encoded(encoding: &str, extra: Vec<Vec<u8>>) -> Vec<u8> {
    const PLEX_SANS: &[u8] =
        include_bytes!("../../../app/assets/fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf");
    let program = ferman_fonts::FontProgram::parse(PLEX_SANS).unwrap();
    let units = f32::from(program.units_per_em());
    let lines = [("Merhaba dünya", 140), ("Ferman", 80)];
    let mut glyphs = BTreeMap::new();
    let mut content = String::new();
    for (text, y) in lines {
        let mut hex = String::new();
        for c in text.chars() {
            let glyph = program.glyph_for_char(c).unwrap();
            let width = (program.advance_width(glyph).unwrap() * 1000.0 / units).round();
            glyphs.insert(glyph.0, (c, width));
            hex.push_str(&format!("{:04X}", glyph.0));
        }
        content.push_str(&format!("BT /F1 18 Tf 40 {y} Td <{hex}> Tj ET\n"));
    }
    let widths: String = glyphs
        .iter()
        .map(|(gid, (_, width))| format!("{gid} [{width}] "))
        .collect();
    let mut cmap = String::from(
        "/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n/CMapName /Adobe-Identity-UCS def\n/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n",
    );
    cmap.push_str(&format!("{} beginbfchar\n", glyphs.len()));
    for (gid, (c, _)) in &glyphs {
        cmap.push_str(&format!("<{gid:04X}> <{:04X}>\n", u32::from(*c)));
    }
    cmap.push_str("endbfchar\nendcmap\nCMapName currentdict /CMap defineresource pop\nend\nend\n");
    let mut objects: Vec<Vec<u8>> = vec![
        b"<< /Type /Catalog /Pages 2 0 R >>".to_vec(),
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>".to_vec(),
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 200] /Resources << /Font << /F1 4 0 R >> >> /Contents 8 0 R >>".to_vec(),
        format!("<< /Type /Font /Subtype /Type0 /BaseFont /IBMPlexSans /Encoding {encoding} /DescendantFonts [5 0 R] /ToUnicode 7 0 R >>").into_bytes(),
        format!("<< /Type /Font /Subtype /CIDFontType2 /BaseFont /IBMPlexSans /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor 6 0 R /DW 1000 /W [{widths}] /CIDToGIDMap /Identity >>").into_bytes(),
        b"<< /Type /FontDescriptor /FontName /IBMPlexSans /Flags 32 /FontBBox [-200 -300 1200 1100] /ItalicAngle 0 /Ascent 1025 /Descent -275 /CapHeight 698 /StemV 80 /FontFile2 9 0 R >>".to_vec(),
        stream_object("", cmap.as_bytes()),
        stream_object("", content.as_bytes()),
        stream_object(&format!("/Length1 {}", PLEX_SANS.len()), PLEX_SANS),
    ];
    objects.extend(extra);
    pdf_of(&objects)
}

#[test]
fn a_new_code_goes_into_a_copy_of_the_font() {
    let (saved, problems) = saved_case(
        "new-font-copy",
        composite_pdf(),
        0,
        "Merhaba dünya",
        "Merhaba güneş",
    );
    assert!(problems.is_empty(), "{problems:?}");
    // One copy of /F1 with "g" and "ş" (their widths and text), which "e" and "n" do not need.
    let [copy] = saved.rewrite.fonts.as_slice() else {
        panic!("{:?}", saved.rewrite.fonts);
    };
    assert_eq!(
        (copy.base.as_slice(), copy.name.as_slice()),
        (&b"F1"[..], &b"F1_1"[..])
    );
    assert_eq!(copy.widths.len(), 2);
    let [splice] = saved.rewrite.splices.as_slice() else {
        panic!("one line");
    };
    let names = |bytes: &[u8]| bytes.windows(6).filter(|w| w == b"/F1_1 ").count();
    assert!(names(&splice.bytes) > 0);
    // The saved file reads the new text, and the other block keeps the original font: the copy's
    // name is only in the edited line's operators.
    let after = open(&Source::read(&saved.path).unwrap(), &OpenOptions::default()).unwrap();
    let text = ferman_text::page_text(&after, 0).unwrap();
    assert!(
        text.contains("Merhaba güneş") && text.contains("Ferman"),
        "{text}"
    );
    let saved_bytes = std::fs::read(&saved.path).unwrap();
    let section = section_objects(&saved_bytes[saved.original.len()..]);
    let content = section
        .iter()
        .find(|object| object.id == (8, 0))
        .unwrap()
        .data();
    assert_eq!(names(&content), names(&splice.bytes));
    // Undo and redo take the copy with the splice: one transaction.
    let mut store = RevisionStore::new(&saved.doc);
    store.begin().unwrap();
    store
        .add_fonts(&saved.doc, 0, &saved.rewrite.fonts)
        .unwrap();
    let splices: Vec<Splice> = saved
        .rewrite
        .splices
        .iter()
        .map(|splice| Splice {
            source: splice.source,
            range: splice.range.clone(),
            bytes: splice.bytes.clone(),
        })
        .collect();
    store.splice(&saved.doc, 0, &splices, &[]).unwrap();
    store.commit().unwrap();
    let read = |store: &RevisionStore| {
        ferman_text::text_page_revised(&saved.doc, store, 0, &EditContext::default())
            .unwrap()
            .blocks
            .iter()
            .flat_map(|block| &block.lines)
            .map(|line| line.text.clone())
            .collect::<Vec<_>>()
    };
    assert_eq!(read(&store), ["Merhaba güneş", "Ferman"]);
    store.undo().unwrap();
    assert_eq!(read(&store), ["Merhaba dünya", "Ferman"]);
    store.redo().unwrap();
    assert_eq!(read(&store), ["Merhaba güneş", "Ferman"]);
    // A second copy under the same name is refused.
    store.begin().unwrap();
    assert!(
        store
            .add_fonts(&saved.doc, 0, &saved.rewrite.fonts)
            .is_err()
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e12_new_font_dictionary() {
    let to = "Merhaba güneş";
    let (saved, problems) = saved_case("e12-font-copy", composite_pdf(), 0, "Merhaba dünya", to);
    rendered_case("e12-font-copy", &saved, problems, 0, to);
}

/// The acceptance criteria's font types and encodings, each with a case above that edits it, and
/// a mark of it in that case's file. E14's Type1 and the embedded CMap have their own cases; the
/// default `StandardEncoding` has a file built in its case, which has no `/Encoding` to find.
#[test]
fn every_font_type_and_encoding_is_in_a_case() {
    for (case, file, marks) in [
        (
            "e14",
            "edit-e14-latex-standin",
            &["/Subtype/Type1", "/FontFile ", "/Differences"][..],
        ),
        (
            "e15",
            "edit-e15-helvetica",
            &["/Subtype/Type1", "/BaseFont/Helvetica"],
        ),
        ("e16", "edit-e16-type3", &["/Subtype/Type3", "/ToUnicode"]),
        ("e01", "kira-tr", &["/Subtype/TrueType", "/WinAnsiEncoding"]),
        ("mac_roman", "edit-macroman", &["/MacRomanEncoding"]),
        (
            "e04",
            "edit-e04-differences",
            &["/Subtype/TrueType", "/WinAnsiEncoding"],
        ),
        ("e12", "zh-hans", &["/CIDFontType2", "/Identity-H"]),
        ("cff_cid_font", "edit-cff-cid", &["/CIDFontType0"]),
        ("e13", "letter-ja-vertical", &["/Identity-V"]),
        ("e12", "edit-90ms-rksj", &["/90ms-RKSJ-H"]),
    ] {
        let squeezed: Vec<u8> = corpus(file)
            .into_iter()
            .filter(|byte| *byte != b'\n')
            .collect();
        let text = String::from_utf8_lossy(&squeezed).replace("/Subtype /", "/Subtype/");
        let text = text.replace("/BaseFont /", "/BaseFont/");
        for mark in marks {
            assert!(text.contains(mark), "{case}: {file} has no {mark}");
        }
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e14_stand_in_type1_with_differences() {
    case(
        "e14-standin-differences",
        "edit-e14-latex-standin",
        0,
        "on 12 May",
        "on 21 May",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e14_stand_in_type1_built_in_encoding() {
    case(
        "e14-standin-built-in",
        "edit-e14-latex-standin",
        0,
        "in 2025",
        "in 2052",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e14_stand_in_paragraph_reflows_without_a_space_glyph() {
    // The font has no space glyph: the new line breaks and spaces must not need one.
    let rewrite = reflow_case(
        "e14-standin-reflow",
        "edit-e14-latex-standin",
        0,
        "The committee met",
        &|block| joined(block, " ").replacen("in three districts", "in the districts", 1),
        None,
        "in the districts",
    );
    assert!(rewrite.new_fonts.is_empty() && rewrite.substitutions.is_empty());
}

#[test]
fn e14_stand_in_programs_are_real_type1() {
    let pdf = corpus("edit-e14-latex-standin");
    let programs: Vec<Vec<u8>> = (1..100)
        .filter_map(|number| original_object(&pdf, (number, 0)))
        .filter(|object| object.is(b"/Length2"))
        .map(|object| object.data())
        .collect();
    let [differences, built_in] = programs.as_slice() else {
        panic!("{} programs", programs.len());
    };
    for program in &programs {
        let parsed = ferman_fonts::FontProgram::parse(program).unwrap();
        let glyph = parsed.glyph_for_name("e").expect("the program draws e");
        assert!(parsed.advance_width(glyph).unwrap() > 0.0);
    }
    assert_eq!(
        ferman_fonts::builtin_encoding(differences).unwrap(),
        Some(ferman_fonts::BuiltinEncoding::Standard)
    );
    assert!(matches!(
        ferman_fonts::builtin_encoding(built_in).unwrap(),
        Some(ferman_fonts::BuiltinEncoding::Codes(_))
    ));
}

/// Whether a `TJ` in `bytes` has a kerning number after a string that `close` ends.
fn has_kerning(bytes: &[u8], close: u8) -> bool {
    bytes.iter().enumerate().any(|(at, byte)| {
        let number = |at| {
            bytes
                .get(at)
                .is_some_and(|b: &u8| *b == b'-' || b.is_ascii_digit())
        };
        *byte == close && (number(at + 1) || (bytes.get(at + 1) == Some(&b' ') && number(at + 2)))
    })
}

/// E17 on `page`: `close` ends the page's strings. The edited line and the file's other lines keep
/// their kerning numbers.
fn e17_case(name: &str, page: usize, close: u8) {
    let to = "21 May";
    let (saved, problems) = saved_case(name, corpus("edit-e17-kerned-standin"), page, "12 May", to);
    let streams = update_streams(&saved);
    assert!(
        streams.iter().any(|data| has_kerning(data, close)),
        "{name}: no kerning number left"
    );
    assert!(
        saved
            .rewrite
            .splices
            .iter()
            .any(|splice| has_kerning(&splice.bytes, close)),
        "{name}: the edited line lost its kerning"
    );
    rendered_case(name, &saved, problems, page, to);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e17_stand_in_word_kerning_in_a_simple_font() {
    e17_case("e17-standin-word", 0, b')');
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e17_stand_in_google_docs_kerning_in_a_composite_font() {
    e17_case("e17-standin-docs", 1, b'>');
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e18_stand_in_interleaved_columns_keep_the_state_invariant() {
    // Each line is placed from the other column's: both columns' edits leave the other in place.
    case(
        "e18-standin-left",
        "edit-e18-columns-standin",
        0,
        "ayrıca ücret",
        "ayrıca para",
    );
    case(
        "e18-standin-right",
        "edit-e18-columns-standin",
        0,
        "14 Aralık",
        "41 Aralık",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn standard_encoding_in_a_type1_font() {
    // No `/Encoding`: StandardEncoding, where "’" is 0x27, which WinAnsi draws as "'".
    let pdf = pdf_of(&[
        b"<< /Type /Catalog /Pages 2 0 R >>".to_vec(),
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>".to_vec(),
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 200] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>".to_vec(),
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>".to_vec(),
        stream_object("", b"BT /F1 12 Tf 40 140 Td (Its office) Tj 0 -30 Td (Next line) Tj ET"),
    ]);
    let to = "It’s office";
    let (saved, problems) = saved_case("standard-encoding", pdf, 0, "Its office", to);
    rendered_case("standard-encoding", &saved, problems, 0, to);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn embedded_cmap_with_usecmap() {
    let cmap = |name: &str, usecmap: &str, range: &str| {
        format!(
            "/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n{usecmap}/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> def\n/CMapName /{name} def\n/CMapType 1 def\n1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n1 begincidrange\n{range}\nendcidrange\nendcmap\nCMapName currentdict /CMap defineresource pop\nend\nend\n"
        )
    };
    let info =
        "/Type /CMap /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >>";
    let pdf = |child: &str| {
        composite_pdf_encoded(
            "11 0 R",
            vec![
                stream_object(
                    &format!("{info} /CMapName /FermanBase"),
                    cmap("FermanBase", "", "<0000> <7FFF> 0").as_bytes(),
                ),
                stream_object(
                    &format!("{info} /CMapName /FermanChild /UseCMap 10 0 R"),
                    cmap("FermanChild", "/FermanBase usecmap\n", child).as_bytes(),
                ),
            ],
        )
    };
    let to = "Merhaba dünaya";
    // The child repeats the parent's range: PDFium does not follow `usecmap` (it draws CID 0 for
    // what only the parent maps), so a render can compare only this form.
    let (saved, problems) = saved_case(
        "embedded-cmap",
        pdf("<0000> <7FFF> 0"),
        0,
        "Merhaba dünya",
        to,
    );
    rendered_case("embedded-cmap", &saved, problems, 0, to);
    // The page's codes only through the parent: the engine's reading and bytes, without a render.
    let (saved, problems) = saved_case(
        "embedded-cmap-parent",
        pdf("<8000> <FFFF> 32768"),
        0,
        "Merhaba dünya",
        to,
    );
    assert!(problems.is_empty(), "{problems:?}");
    let after = open(&Source::read(&saved.path).unwrap(), &OpenOptions::default()).unwrap();
    assert!(ferman_text::page_text(&after, 0).unwrap().contains(to));
}

/// The operators of `page`, by name and range in the stream's decoded data.
#[derive(Default)]
struct Operators(Vec<(Vec<u8>, Range<usize>)>);

impl TextSink for Operators {
    fn font(&mut self, _font: &ferman_core::interpret::FontResource) {}

    fn show(&mut self, _show: &TextShow<'_>) -> (f32, f32) {
        (0.0, 0.0)
    }

    fn operator(&mut self, operator: &OperatorEvent<'_>) {
        self.0
            .push((operator.name.to_vec(), operator.span.range.clone()));
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e24_edited_after_unlocking_and_still_encrypted() {
    const PASSWORD: &str = "Eylül2026maaşı";
    let (name, from, to) = ("e24-payslip-aes256", "0187", "0188");
    let original = corpus("payslip-aes256");
    let doc = open(
        &Source::from_bytes(Arc::from(original.as_slice())),
        &options(Some(PASSWORD)),
    )
    .unwrap();
    let blocks = text_page(&doc, 0, &EditContext::default()).unwrap().blocks;
    let block = blocks
        .iter()
        .find(|block| block.text().contains(from))
        .cloned()
        .unwrap();
    let text = joined(&block, "\n").replacen(from, to, 1);
    let outcome = rewrite_block_fonts(
        &doc,
        None,
        0,
        &block,
        &text,
        &blocks,
        None,
        &FontSources::default(),
    )
    .unwrap();
    let Outcome::Rewritten(rewrite) = outcome else {
        panic!("{name}: {outcome:?}");
    };
    let splices: Vec<Splice> = rewrite
        .splices
        .iter()
        .map(|splice| Splice {
            source: splice.source,
            range: splice.range.clone(),
            bytes: splice.bytes.clone(),
        })
        .collect();
    let mut store = RevisionStore::new(&doc);
    store.begin().unwrap();
    store.splice(&doc, 0, &splices, &[]).unwrap();
    store.commit().unwrap();
    let path = saved_dir().join(format!("{name}.pdf"));
    std::fs::write(&path, store.incremental_update(&doc).unwrap()).unwrap();

    let saved = std::fs::read(&path).unwrap();
    let mut problems = if saved.starts_with(&original) {
        xref_problems(&original, &saved)
    } else {
        vec!["the original is not a prefix of the saved file".to_owned()]
    };
    let update = &saved[original.len()..];
    assert!(
        find(update, b"/Encrypt", 0).is_some(),
        "the trailer keeps /Encrypt"
    );
    // Only the edited stream is new, and its bytes are AES blocks: an IV and whole blocks.
    let edited: Vec<ObjectId> = splices
        .iter()
        .map(|splice| match splice.source {
            SpanSource::Page { stream } | SpanSource::Form { form: stream } => stream,
        })
        .collect();
    for object in section_objects(update) {
        if object.is(b"/XRef") {
            continue;
        }
        if !edited.contains(&object.id) {
            problems.push(format!("object {:?} rewritten", object.id));
        }
        let raw = object.raw.as_ref().expect("a stream");
        // Both operators, since random AES bytes hold any one short pattern now and then.
        let plain = find(raw, b"BT", 0).is_some() && find(raw, b" Tf", 0).is_some();
        if raw.len() % 16 != 0 || plain {
            problems.push(format!("stream {:?} is not encrypted", object.id));
        }
    }
    assert!(
        open(&Source::read(&path).unwrap(), &OpenOptions::default()).is_err(),
        "no password, no document"
    );
    // The encrypted stream cannot be compared in the file: every operator outside the replaced
    // spans must be where it was, moved only by the replacement's length.
    let operators = |doc: &Document| {
        let mut sink = Operators::default();
        doc.page_text(0, &mut sink).unwrap();
        sink.0
    };
    let after = open(&Source::read(&path).unwrap(), &options(Some(PASSWORD))).unwrap();
    let (old, new) = (operators(&doc), operators(&after));
    let [splice] = splices.as_slice() else {
        panic!("{name}: one span expected, {}", splices.len());
    };
    let shift = splice.bytes.len() as isize - splice.range.len() as isize;
    let moved = |range: &Range<usize>| {
        range.start.wrapping_add_signed(shift)..range.end.wrapping_add_signed(shift)
    };
    let before: Vec<_> = old
        .iter()
        .filter(|(_, range)| range.end <= splice.range.start)
        .collect();
    let behind: Vec<_> = old
        .iter()
        .filter(|(_, range)| range.start >= splice.range.end)
        .map(|(name, range)| (name.clone(), moved(range)))
        .collect();
    assert_eq!(new[..before.len()].iter().collect::<Vec<_>>(), before);
    assert_eq!(new[new.len() - behind.len()..], behind[..]);

    let saved = Saved {
        original,
        doc,
        block,
        path,
        rewrite,
        password: Some(PASSWORD),
    };
    rendered_case(name, &saved, problems, 0, to);
}

#[test]
fn the_byte_check_finds_a_change_outside_the_spans() {
    let edits = [(3..9, Some(b"(B) Tj".to_vec()))];
    assert!(kept_outside(b"BT (A) Tj ET", b"BT (B) Tj ET", &edits));
    assert!(!kept_outside(b"BT (A) Tj ET", b"BT (B) Tj  ET", &edits));
    assert!(!kept_outside(b"BT (A) Tj ET", b"Bt (B) Tj ET", &edits));
    let draw = [(2..9, None)];
    assert!(kept_outside(b"q /Fm1 Do Q", b"q /Fm1_1 Do Q", &draw));
    assert!(!kept_outside(b"q /Fm1 Do Q", b"q (x) Tj Q", &draw));
}

#[test]
fn the_xref_check_finds_a_wrong_offset() {
    let original = b"%PDF-1.7\n1 0 obj\n<<>>\nendobj\nxref\n0 2\n0000000000 65535 f \n0000000009 00000 n \ntrailer\n<</Size 2>>\nstartxref\n29\n%%EOF\n";
    let update = |offset: usize, prev: usize| {
        let mut saved = original.to_vec();
        let object = saved.len();
        saved.extend_from_slice(b"1 0 obj\n<</A 1>>\nendobj\n");
        let xref = saved.len();
        saved.extend_from_slice(
            format!("xref\n1 1\n{:010} 00000 n \ntrailer\n<</Size 2 /Prev {prev}>>\nstartxref\n{xref}\n%%EOF\n", object + offset)
                .as_bytes(),
        );
        saved
    };
    assert_eq!(
        xref_problems(original, &update(0, 29)),
        Vec::<String>::new()
    );
    assert_eq!(xref_problems(original, &update(1, 29)).len(), 1);
    assert_eq!(xref_problems(original, &update(0, 30)).len(), 1);
    assert_eq!(xref_problems(original, &update(0, 290)).len(), 1);
}
