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
//!   CIDFont and ToUnicode objects of a font copy, and nothing else: every original font
//!   dictionary stays as it is;
//!   each edited stream's decoded bytes outside the replaced spans are identical (a placement's
//!   `Do` may only draw another name);
//! - PDFium opens the saved file with the same page count;
//! - on the edited page no pixel differs outside the union of the block's box before and after,
//!   grown by [`EDIT_MARGIN`] (M3 plan decision 6), and some pixel differs inside it at every
//!   resolution; on every other page no pixel differs at all.
//!
//! Each case prints a JSON report per page and resolution (case, page, dpi, region, differing
//! pixels, the margin they need, pixels outside and their bounds), the form `ferman verify-edit`
//! prints. A case that needs more than the margin fails with its report; the margin is never
//! widened. Saved files go to `FERMAN_SAVED_DIR` when it is set (qpdf checks them in CI), else to
//! the system's temp folder.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
//!
//! Not here yet: E04's own edit (a "ğ" that only `/Differences` in a new font dictionary can
//! encode) is missing-glyph step 1 of W3, so its file is edited within WinAnsi; kira-tr's subset
//! TrueType font is simple, so E01 runs here.
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
use ferman_core::{Document, OpenOptions, Source, open};
use ferman_render::{
    EDIT_MARGIN, PdfiumStatus, RESOLUTIONS, RenderConfig, RenderThread, compare, device_region,
    render_page,
};
use ferman_text::{EditContext, Outcome, TextBlock, rewrite_block, text_page};
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

/// The byte checks of the module documentation, for an edit that made `fonts` font copies; the
/// problems found.
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
        if old.is_none() && fonts > 0 && (font || to_unicode) {
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
    if font_objects != 3 * fonts {
        problems.push(format!(
            "{font_objects} new font objects for {fonts} font copies"
        ));
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
    let doc = open(
        &Source::from_bytes(Arc::from(original.as_slice())),
        &OpenOptions::default(),
    )
    .unwrap();
    let block: TextBlock = text_page(&doc, page, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains(from)))
        .unwrap_or_else(|| panic!("{name}: no block with {from:?}"));
    let text: Vec<String> = block
        .lines
        .iter()
        .map(|line| line.text.replacen(from, to, 1))
        .collect();
    let outcome = rewrite_block(&doc, page, &block, &text.join("\n")).unwrap();
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
    store.add_fonts(&doc, page, &rewrite.fonts).unwrap();
    store.splice(&doc, page, &splices, &placements).unwrap();
    store.commit().unwrap();
    let path = saved_dir().join(format!("{name}.pdf"));
    std::fs::write(&path, store.incremental_update(&doc).unwrap()).unwrap();

    // Everything after this reads the saved file from disk.
    let saved = std::fs::read(&path).unwrap();
    let problems = byte_problems(&original, &saved, &edits, rewrite.fonts.len());
    let saved = Saved {
        original,
        doc,
        block,
        path,
        rewrite,
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
        ..
    } = saved_case;
    let saved = std::fs::read(path).unwrap();
    let after = open(&Source::read(path).unwrap(), &OpenOptions::default()).unwrap();
    let mut boxes = vec![block.bbox];
    boxes.extend(
        text_page(&after, page, &EditContext::default())
            .unwrap()
            .blocks
            .into_iter()
            .filter(|new| {
                intersects(new.bbox, block.bbox) && new.lines.iter().any(|l| l.text.contains(to))
            })
            .map(|new| new.bbox),
    );
    if boxes.len() < 2 {
        problems.push(format!("no block with {to:?} after the edit"));
    }

    let render = render();
    let before_pdf = block_on(render.open_document(Arc::from(original.as_slice()), None)).unwrap();
    let after_pdf = block_on(render.open_document(Arc::from(saved.as_slice()), None)).unwrap();
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

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e01_kira_tr_amount_in_a_subset_truetype() {
    case("e01-kira-tr", "kira-tr", 0, "18.500", "19.500");
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
fn e20_form_placed_twice() {
    case("e20-form-twice", "edit-e20-form-twice", 0, "ALINDI", "ALIN");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e21_actual_text() {
    case(
        "e21-actualtext",
        "edit-e21-actualtext",
        0,
        "0216 555",
        "0612 555",
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn e22_two_streams() {
    case(
        "e22-split-contents",
        "edit-e22-split-contents",
        0,
        "bildirir",
        "duyurur",
    );
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
    case(
        "e26-inline-image",
        "edit-e26-inline-image",
        0,
        "Duyuru",
        "Duyurular",
    );
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

/// A page with two blocks in one composite font, `/F1`: the full IBM Plex Sans as an
/// `Identity-H` `CIDFontType2` font whose `/W` and ToUnicode CMap hold only the glyphs the page
/// draws, as producers write them. Typing a character of the program the page does not draw
/// needs a copy of the font.
fn composite_pdf() -> Vec<u8> {
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
    let stream = |dict: &str, data: &[u8]| {
        let mut out = format!("<< {dict} /Length {} >>\nstream\n", data.len()).into_bytes();
        out.extend_from_slice(data);
        out.extend_from_slice(b"\nendstream");
        out
    };
    let objects: Vec<Vec<u8>> = vec![
        b"<< /Type /Catalog /Pages 2 0 R >>".to_vec(),
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>".to_vec(),
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 200] /Resources << /Font << /F1 4 0 R >> >> /Contents 8 0 R >>".to_vec(),
        b"<< /Type /Font /Subtype /Type0 /BaseFont /IBMPlexSans /Encoding /Identity-H /DescendantFonts [5 0 R] /ToUnicode 7 0 R >>".to_vec(),
        format!("<< /Type /Font /Subtype /CIDFontType2 /BaseFont /IBMPlexSans /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor 6 0 R /DW 1000 /W [{widths}] /CIDToGIDMap /Identity >>").into_bytes(),
        b"<< /Type /FontDescriptor /FontName /IBMPlexSans /Flags 32 /FontBBox [-200 -300 1200 1100] /ItalicAngle 0 /Ascent 1025 /Descent -275 /CapHeight 698 /StemV 80 /FontFile2 9 0 R >>".to_vec(),
        stream("", cmap.as_bytes()),
        stream("", content.as_bytes()),
        stream(&format!("/Length1 {}", PLEX_SANS.len()), PLEX_SANS),
    ];
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
