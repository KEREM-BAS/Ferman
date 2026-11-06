//! Rewriting blocks in simple fonts (ROADMAP §7 step 3) on the edit corpus and on small files
//! built here. For every edit: the new text reads back through the font's ToUnicode CMap or
//! encoding; the splices cover only the block's own operators; and after the splices are applied
//! to the decoded streams (by a small helper here: the core splicer is separate), every glyph and
//! every operator outside them draws as before, from the same place and with the same state.
// Test helpers fail loudly.
#![allow(
    clippy::panic,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::io::Read;
use std::ops::Range;
use std::path::PathBuf;
use std::sync::Arc;

use ferman_core::interpret::{
    FontResource, GraphicsState, OperatorEvent, Span, SpanSource, TextShow, TextSink,
};
use ferman_core::{Document, OpenOptions, Source, open};
use ferman_text::{
    Choice, EditContext, Outcome, Rewrite, Splice, TextBlock, TextDirection, Unsupported,
    rewrite_block, rewrite_block_with, text_page,
};
use unicode_normalization::UnicodeNormalization;

fn corpus(name: &str) -> Vec<u8> {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"));
    std::fs::read(path).unwrap()
}

fn document(bytes: &[u8]) -> Document {
    open(
        &Source::from_bytes(Arc::from(bytes)),
        &OpenOptions::default(),
    )
    .unwrap()
}

fn squeeze(text: &str) -> String {
    text.nfc().filter(|c| !c.is_whitespace()).collect()
}

fn find(hay: &[u8], needle: &[u8], from: usize) -> Option<usize> {
    hay.get(from..)?
        .windows(needle.len())
        .position(|window| window == needle)
        .map(|at| at + from)
}

fn rfind(hay: &[u8], needle: &[u8]) -> Option<usize> {
    hay.windows(needle.len())
        .rposition(|window| window == needle)
}

/// The number after `key` in `text`.
fn number_after(text: &[u8], key: &[u8]) -> usize {
    let at = find(text, key, 0).unwrap() + key.len();
    let digits: String = text[at..]
        .iter()
        .skip_while(|byte| byte.is_ascii_whitespace())
        .take_while(|byte| byte.is_ascii_digit())
        .map(|&byte| char::from(byte))
        .collect();
    digits.parse().unwrap()
}

/// Object `id`'s latest stream: its dictionary and decoded data. Enough for the files
/// `tools/corpus` writes and the ones built here: a direct `/Length`, Flate or no filter.
fn stream(pdf: &[u8], id: u16) -> (String, Vec<u8>) {
    let start = rfind(pdf, format!("\n{id} 0 obj").as_bytes()).unwrap();
    let open = find(pdf, b"<<", start).unwrap();
    let keyword = find(pdf, b"stream", open).unwrap();
    let dict = String::from_utf8(pdf[open..keyword].to_vec()).unwrap();
    let mut body = keyword + b"stream".len();
    if pdf[body] == b'\r' {
        body += 1;
    }
    if pdf[body] == b'\n' {
        body += 1;
    }
    let raw = &pdf[body..body + number_after(dict.as_bytes(), b"/Length")];
    let data = if dict.contains("FlateDecode") {
        let mut out = Vec::new();
        flate2::read::ZlibDecoder::new(raw)
            .read_to_end(&mut out)
            .unwrap();
        out
    } else {
        raw.to_vec()
    };
    (dict, data)
}

/// `pdf` with the streams `edits` names replaced by unfiltered data, as an incremental update.
fn patch(pdf: &[u8], edits: &[(u16, Vec<u8>)]) -> Vec<u8> {
    let mut out = pdf.to_vec();
    if !out.ends_with(b"\n") {
        out.push(b'\n');
    }
    let mut offsets = Vec::new();
    for (id, data) in edits {
        let (dict, _) = stream(pdf, *id);
        let dict = dict
            .replace("/Filter/FlateDecode", "")
            .replace("/Filter /FlateDecode", "");
        let at = dict.find("/Length").unwrap() + "/Length".len();
        let digits = dict[at..]
            .trim_start()
            .chars()
            .take_while(char::is_ascii_digit)
            .count();
        let skip = dict[at..].len() - dict[at..].trim_start().len();
        let dict = format!(
            "{} {}{}",
            &dict[..at],
            data.len(),
            &dict[at + skip + digits..]
        );
        offsets.push((*id, out.len()));
        out.extend_from_slice(format!("{id} 0 obj\n{}stream\n", dict.trim_end()).as_bytes());
        out.extend_from_slice(data);
        out.extend_from_slice(b"\nendstream\nendobj\n");
    }
    let xref = out.len();
    out.extend_from_slice(b"xref\n");
    for (id, offset) in &offsets {
        out.extend_from_slice(format!("{id} 1\n{offset:010} 00000 n \n").as_bytes());
    }
    let trailer = rfind(pdf, b"trailer").unwrap();
    let start = find(pdf, b"<<", trailer).unwrap();
    let end = find(pdf, b"startxref", trailer).unwrap();
    let dict = String::from_utf8(pdf[start..end].to_vec()).unwrap();
    assert!(!dict.contains("/Prev"), "one update only");
    let prev = number_after(&pdf[end..], b"startxref");
    out.extend_from_slice(
        format!(
            "trailer\n<</Prev {prev}{}\nstartxref\n{xref}\n%%EOF\n",
            &dict.trim_end()[2..]
        )
        .as_bytes(),
    );
    out
}

fn object(source: SpanSource) -> u16 {
    let (SpanSource::Page { stream: (id, _) } | SpanSource::Form { form: (id, _) }) = source;
    u16::try_from(id).unwrap()
}

/// Each replacement in its new stream, and how far the bytes after it moved.
type Placed = Vec<(SpanSource, Range<usize>, isize)>;

/// `pdf` with `splices` applied, and where each replacement is in its new stream.
fn apply(pdf: &[u8], splices: &[Splice]) -> (Vec<u8>, Placed) {
    let mut sources: Vec<SpanSource> = splices.iter().map(|splice| splice.source).collect();
    sources.dedup();
    let mut edits = Vec::new();
    let mut placed = Vec::new();
    for source in sources {
        let (_, data) = stream(pdf, object(source));
        let mut mine: Vec<&Splice> = splices.iter().filter(|s| s.source == source).collect();
        mine.sort_by_key(|splice| splice.range.start);
        let mut out = Vec::new();
        let mut at = 0;
        let mut delta = 0_isize;
        for splice in mine {
            assert!(splice.range.start >= at, "splices overlap");
            out.extend_from_slice(&data[at..splice.range.start]);
            let start = out.len();
            out.extend_from_slice(&splice.bytes);
            delta += splice.bytes.len() as isize - splice.range.len() as isize;
            placed.push((source, start..out.len(), delta));
            at = splice.range.end;
        }
        out.extend_from_slice(&data[at..]);
        edits.push((object(source), out));
    }
    (patch(pdf, &edits), placed)
}

/// Every operator with its state; shows move nothing (only the state that is not the text
/// matrices is compared).
#[derive(Default)]
struct Record {
    events: Vec<(Vec<u8>, Span, GraphicsState)>,
}

impl TextSink for Record {
    fn font(&mut self, _font: &FontResource) {}

    fn show(&mut self, _show: &TextShow<'_>) -> (f32, f32) {
        (0.0, 0.0)
    }

    fn operator(&mut self, operator: &OperatorEvent<'_>) {
        self.events.push((
            operator.name.to_vec(),
            operator.span.clone(),
            operator.state.clone(),
        ));
    }
}

fn events(document: &Document, page: usize) -> Vec<(Vec<u8>, Span, GraphicsState)> {
    let mut record = Record::default();
    document.page_text(page, &mut record).unwrap();
    record.events
}

/// The page's characters drawn by glyphs, by content position: source, offset, index in the
/// show, the character and its box.
fn glyph_chars(
    document: &Document,
    page: usize,
) -> Vec<(SpanSource, usize, usize, char, [f32; 4])> {
    let model = text_page(document, page, &EditContext::default()).unwrap();
    let mut out = Vec::new();
    for block in &model.blocks {
        for line in &block.lines {
            for c in &line.chars {
                if let (Some(link), Some(bbox)) = (&c.glyph, c.bbox) {
                    out.push((
                        link.span.source,
                        link.span.range.start,
                        link.index,
                        c.ch,
                        bbox,
                    ));
                }
            }
        }
    }
    out.sort_by(|a, b| {
        (object(a.0), a.1, a.2, a.3)
            .cmp(&(object(b.0), b.1, b.2, b.3))
            .then(a.4[0].total_cmp(&b.4[0]))
            .then(a.4[1].total_cmp(&b.4[1]))
    });
    out.dedup();
    out
}

/// The block with a line containing `needle`.
fn block(document: &Document, page: usize, needle: &str) -> TextBlock {
    let model = text_page(document, page, &EditContext::default()).unwrap();
    model
        .blocks
        .into_iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains(needle)))
        .unwrap_or_else(|| panic!("no block with {needle:?}"))
}

/// The block's text with `from` replaced by `to` in its line containing `from`.
fn edited(block: &TextBlock, from: &str, to: &str) -> String {
    let lines: Vec<String> = block
        .lines
        .iter()
        .map(|line| line.text.replacen(from, to, 1))
        .collect();
    lines.join("\n")
}

/// Rewrites the block with `from` on `page` of `pdf` to say `to`, checks the result and returns
/// the rewrite and the new file.
fn edit(pdf: &[u8], page: usize, from: &str, to: &str) -> (Rewrite, Vec<u8>) {
    let before = document(pdf);
    let target = block(&before, page, from);
    let text = edited(&target, from, to);
    let outcome = rewrite_block(&before, page, &target, &text).unwrap();
    let Outcome::Rewritten(rewrite) = outcome else {
        panic!("{from:?} → {to:?}: {outcome:?}");
    };
    assert!(!rewrite.splices.is_empty());
    let (after_pdf, placed) = apply(pdf, &rewrite.splices);
    let after = document(&after_pdf);
    check(&before, &after, page, &target, &text, &rewrite, &placed);
    (rewrite, after_pdf)
}

/// Whether `span` is inside one of `ranges` of its source.
fn inside(span: &Span, ranges: &[(SpanSource, Range<usize>)]) -> bool {
    ranges.iter().any(|(source, range)| {
        *source == span.source && range.start <= span.range.start && span.range.end <= range.end
    })
}

/// An offset of the new stream at the old stream's place.
fn old_offset(
    source: SpanSource,
    at: usize,
    placed: &[(SpanSource, Range<usize>, isize)],
) -> usize {
    let delta = placed
        .iter()
        .rev()
        .find(|(s, range, _)| *s == source && range.end <= at)
        .map_or(0, |(_, _, delta)| *delta);
    usize::try_from(at as isize - delta).unwrap()
}

fn close(a: [f32; 4], b: [f32; 4]) -> bool {
    a.iter().zip(b).all(|(x, y)| (x - y).abs() < 0.01)
}

fn check(
    before: &Document,
    after: &Document,
    page: usize,
    target: &TextBlock,
    text: &str,
    rewrite: &Rewrite,
    placed: &[(SpanSource, Range<usize>, isize)],
) {
    // The splices cover only the block's operators: its shows, and positioning and text state
    // between them.
    let old_ranges: Vec<(SpanSource, Range<usize>)> = rewrite
        .splices
        .iter()
        .map(|splice| (splice.source, splice.range.clone()))
        .collect();
    let block_shows: Vec<&Span> = target
        .lines
        .iter()
        .flat_map(|line| &line.chars)
        .filter_map(|c| c.glyph.as_ref().map(|link| &link.span))
        .collect();
    let old_events = events(before, page);
    for (name, span, _) in &old_events {
        let overlaps = old_ranges.iter().any(|(source, range)| {
            *source == span.source && span.range.start < range.end && range.start < span.range.end
        });
        if !overlaps {
            continue;
        }
        assert!(inside(span, &old_ranges), "{name:?} straddles a splice");
        let show = matches!(name.as_slice(), b"Tj" | b"TJ" | b"'" | b"\"");
        assert!(
            !show || block_shows.contains(&span),
            "a show of another block in a splice"
        );
        assert!(
            show || [
                &b"Td"[..],
                b"TD",
                b"Tm",
                b"T*",
                b"Tc",
                b"Tw",
                b"Tz",
                b"TL",
                b"Ts",
                b"Tf"
            ]
            .contains(&name.as_slice()),
            "{} in a splice",
            String::from_utf8_lossy(name)
        );
    }
    // Every operator outside the splices leaves the same state but for the text matrices, which
    // the glyphs check.
    let new_ranges: Vec<(SpanSource, Range<usize>)> = placed
        .iter()
        .map(|(source, range, _)| (*source, range.clone()))
        .collect();
    let outside_old: Vec<_> = old_events
        .iter()
        .filter(|(_, span, _)| !inside(span, &old_ranges))
        .collect();
    let new_events = events(after, page);
    let outside_new: Vec<_> = new_events
        .iter()
        .filter(|(_, span, _)| !inside(span, &new_ranges))
        .collect();
    assert_eq!(outside_old.len(), outside_new.len());
    for ((name, _, old), (new_name, _, new)) in outside_old.iter().zip(&outside_new) {
        assert_eq!(name, new_name);
        let strip = |state: &GraphicsState| GraphicsState {
            text_matrix: [0.0; 6],
            line_matrix: [0.0; 6],
            ..state.clone()
        };
        assert_eq!(strip(old), strip(new), "{}", String::from_utf8_lossy(name));
    }
    // Every glyph outside the splices is where it was: the edited lines' glyphs that a splice
    // replaces (all of them where the block is reflowed; a vertical column's one show).
    let edited_lines: Vec<usize> = target
        .lines
        .iter()
        .enumerate()
        .filter(|(_, line)| {
            line.chars.iter().any(|c| {
                c.glyph
                    .as_ref()
                    .is_some_and(|link| inside(&link.span, &old_ranges))
            })
        })
        .map(|(at, _)| at)
        .collect();
    let line_by_line = text.split('\n').count() == target.lines.len();
    let edited_spans: Vec<&Span> = edited_lines
        .iter()
        .flat_map(|&at| &target.lines[at].chars)
        .filter_map(|c| c.glyph.as_ref().map(|link| &link.span))
        .filter(|span| inside(span, &old_ranges))
        .collect();
    let old_chars: Vec<_> = glyph_chars(before, page)
        .into_iter()
        .filter(|(source, start, ..)| {
            !edited_spans
                .iter()
                .any(|span| span.source == *source && span.range.start == *start)
        })
        .collect();
    let new_chars = glyph_chars(after, page);
    let replaced = |source: &SpanSource, start: &usize| {
        new_ranges
            .iter()
            .any(|(s, range)| s == source && range.contains(start))
    };
    let outer: Vec<_> = new_chars
        .into_iter()
        .filter(|(source, start, ..)| !replaced(source, start))
        .collect();
    let outer: Vec<_> = outer
        .into_iter()
        .map(|(source, start, index, c, bbox)| {
            (source, old_offset(source, start, placed), index, c, bbox)
        })
        .collect();
    assert_eq!(old_chars.len(), outer.len(), "glyphs outside the block");
    for (old, new) in old_chars.iter().zip(&outer) {
        assert_eq!(
            (old.0, old.1, old.2, old.3),
            (new.0, new.1, new.2, new.3),
            "a glyph outside the block"
        );
        assert!(
            close(old.4, new.4),
            "{:?} moved: {:?} → {:?}",
            old.3,
            old.4,
            new.4
        );
    }
    // The new lines read back as the new text, once per placement of a form: the codes decode
    // to it.
    let wanted: String = if line_by_line {
        squeeze(
            &edited_lines
                .iter()
                .map(|&at| text.split('\n').nth(at).unwrap())
                .collect::<String>(),
        )
    } else {
        squeeze(text)
    };
    let model = text_page(after, page, &EditContext::default()).unwrap();
    let is_replaced = |c: &&ferman_text::TextChar| {
        c.glyph
            .as_ref()
            .is_some_and(|link| replaced(&link.span.source, &link.span.range.start))
    };
    // A vertical column writes only the show the change is in, so its whole line is read.
    let vertical = target.direction == TextDirection::Vertical;
    let got: String = squeeze(
        &model
            .blocks
            .iter()
            .flat_map(|block| &block.lines)
            .filter(|line| !vertical || line.chars.iter().any(|c| is_replaced(&c)))
            .flat_map(|line| &line.chars)
            .filter(|c| vertical || is_replaced(c))
            .map(|c| c.ch)
            .collect::<String>(),
    );
    let placements = got.chars().count() / wanted.chars().count().max(1);
    assert!(
        placements >= 1 && got == wanted.repeat(placements),
        "{got:?} for {wanted:?}"
    );
}

#[test]
fn standard_14_helvetica_edits_with_its_metrics() {
    // E15: no /Widths and no program; the AFM widths place the text after the change.
    let (rewrite, after) = edit(&corpus("edit-e15-helvetica"), 0, "Monday", "Wednesday");
    assert_eq!(
        rewrite.overflowing,
        [0],
        "the longest line grows past the frame"
    );
    let doc = document(&after);
    let line = block(&doc, 0, "Wednesday").lines[0].clone();
    // Helvetica's "Room 3.14 is booked for the budget review on Wednesday, 9 November 2026." at
    // 11 points, from the standard metrics.
    let length = line.baseline[1][0] - line.baseline[0][0];
    let expected: f32 = 11.0 * 0.001 * {
        let widths = [
            ('R', 722),
            ('o', 556),
            ('m', 833),
            (' ', 278),
            ('3', 556),
            ('.', 278),
            ('1', 556),
            ('4', 556),
            ('i', 222),
            ('s', 500),
            ('b', 556),
            ('k', 500),
            ('e', 556),
            ('d', 556),
            ('f', 278),
            ('r', 333),
            ('t', 278),
            ('h', 556),
            ('u', 556),
            ('g', 556),
            ('v', 500),
            ('w', 722),
            ('n', 556),
            ('W', 944),
            ('a', 556),
            ('y', 500),
            (',', 278),
            ('9', 556),
            ('N', 722),
            ('2', 556),
            ('0', 556),
            ('6', 556),
        ];
        "Room 3.14 is booked for the budget review on Wednesday, 9 November 2026."
            .chars()
            .map(|c| widths.iter().find(|(w, _)| *w == c).unwrap().1 as f32)
            .sum::<f32>()
    };
    assert!((length - expected).abs() < 0.05, "{length} {expected}");
}

/// The characters of a [`Outcome::MissingGlyphs`], each once; empty for another outcome.
fn missing(outcome: &Outcome) -> Vec<char> {
    let Outcome::MissingGlyphs(missing) = outcome else {
        return Vec::new();
    };
    let mut chars: Vec<char> = Vec::new();
    for &(c, _) in &missing.chars {
        if !chars.contains(&c) {
            chars.push(c);
        }
    }
    chars
}

#[test]
fn win_ansi_truetype_subset_edits_and_adds_a_code_through_differences() {
    // E01 on E04's file: same length, then shorter. WinAnsi has no code for "ğ", but the
    // program has the glyph: step 1 gives it a free code in a copy of the font.
    edit(&corpus("edit-e04-differences"), 0, "18.500", "18.600");
    edit(
        &corpus("edit-e04-differences"),
        0,
        "Moda Cad. No: 18",
        "Moda Cd. 18",
    );
    let pdf = corpus("edit-e04-differences");
    let doc = document(&pdf);
    let target = block(&doc, 0, "Kira bedeli");
    let text = edited(&target, "bedeli", "bedeliğğ");
    let Outcome::Rewritten(rewrite) = rewrite_block(&doc, 0, &target, &text).unwrap() else {
        panic!("not rewritten");
    };
    assert!(rewrite.fonts.is_empty() && rewrite.new_fonts.is_empty());
    let [copy] = rewrite.simple_fonts.as_slice() else {
        panic!("{:?}", rewrite.simple_fonts);
    };
    // One code for both, the first WinAnsi leaves unused, named for the glyph.
    let [(code, name, width)] = copy.codes.as_slice() else {
        panic!("{:?}", copy.codes);
    };
    assert_eq!((*code, name.as_str()), (129, "gbreve"));
    assert!(*width > 0.0);
    let splice = String::from_utf8_lossy(&rewrite.splices[0].bytes).into_owned();
    let name = String::from_utf8(copy.name.clone()).unwrap();
    assert!(splice.contains(&format!("/{name} ")), "{splice}");
    assert!(splice.contains("\\201\\201"), "{splice}");
    assert!(rewrite.substitutions.is_empty() && rewrite.pending.is_none());
}

#[test]
fn kira_tr_edits_an_amount() {
    // E01.
    edit(&corpus("kira-tr"), 0, "18.500", "18.600");
}

#[test]
fn type3_edits_within_its_char_procs() {
    // E16: digits and letters the glyph procedures have; "z" and "Q" they have not.
    edit(&corpus("edit-e16-type3"), 0, "12 boxes", "21 boxes");
    edit(&corpus("edit-e16-type3"), 0, "M. Kaya", "M. Kaya ve");
    let pdf = corpus("edit-e16-type3");
    let doc = document(&pdf);
    let target = block(&doc, 0, "12 boxes");
    let text = edited(&target, "boxes", "Qboxez");
    assert_eq!(
        missing(&rewrite_block(&doc, 0, &target, &text).unwrap()),
        ['Q', 'z']
    );
}

#[test]
fn mac_roman_edits() {
    edit(&corpus("edit-macroman"), 0, "Müller", "Müllers");
    edit(
        &corpus("edit-macroman"),
        0,
        "Hauptstraße 12",
        "Hauptstraße 21",
    );
}

#[test]
fn mixed_simple_and_composite_lines_keep_their_composite_glyphs() {
    // A Turkish line drawn in a WinAnsi font with "ı" from a composite one: the composite runs
    // keep their codes, and a new "ı" takes the composite font's code (step 4).
    edit(&corpus("edit-e21-actualtext"), 0, "Pazartesi", "Pazar");
    let (rewrite, _) = edit(&corpus("edit-e21-actualtext"), 0, "Pazartesi", "Pazarı");
    assert!(rewrite.fonts.is_empty(), "the font's own code, no copy");
}

#[test]
fn identity_h_truetype_cid_fonts_edit_with_their_own_codes() {
    // E12: CIDFontType2 subsets with Identity-H, characters of the subsets reordered.
    for (file, from, to) in [
        ("zh-hans", "一万九千五百元", "一万五千九百元"),
        ("zh-hant", "十一月十五日", "十一月五十日"),
        ("ko-para", "11월 30일에", "11월 03일에"),
    ] {
        let (rewrite, after) = edit(&corpus(file), 0, from, to);
        assert!(rewrite.fonts.is_empty(), "{file}");
        // Composite strings are hex, two bytes a code.
        let splice = String::from_utf8(rewrite.splices[0].bytes.clone()).unwrap();
        assert!(
            splice.contains('<') && !splice.contains('('),
            "{file}: {splice}"
        );
        assert!(
            squeeze(&ferman_text::page_text(&document(&after), 0).unwrap()).contains(&squeeze(to))
        );
    }
}

#[test]
fn a_cff_cid_font_edits_through_its_charset() {
    // CIDFontType0 with a CID-keyed CFF program (FontFile3/CIDFontType0C).
    let (rewrite, _) = edit(&corpus("edit-cff-cid"), 0, "2 Kasım 2026", "6 Kasım 2022");
    assert!(rewrite.fonts.is_empty());
    edit(&corpus("edit-cff-cid"), 0, "Şule Işık", "Işık Şule");
}

#[test]
fn a_predefined_cmap_encodes_shift_jis() {
    // 90ms-RKSJ-H: two-byte Shift-JIS codes whose Adobe-Japan1 CIDs the CIDToGIDMap stream
    // maps to the subset's glyphs.
    let (rewrite, _) = edit(&corpus("edit-90ms-rksj"), 0, "マンションの", "ションマンの");
    let splice = String::from_utf8(rewrite.splices[0].bytes.clone()).unwrap();
    // "シ" is JIS row 5, cell 23: Shift-JIS 83 56.
    assert!(splice.contains("<8356"), "{splice}");
    edit(&corpus("edit-90ms-rksj"), 0, "おしらせ", "おしらせします");
}

#[test]
fn a_character_a_composite_subset_lacks_is_missing() {
    // The subset has no cmap and no glyph for it: reported, never substituted.
    let pdf = corpus("zh-hans");
    let doc = document(&pdf);
    let target = block(&doc, 0, "一万九千五百元");
    let text = edited(&target, "一万九千五百元", "一万九千五百龘");
    assert_eq!(
        missing(&rewrite_block(&doc, 0, &target, &text).unwrap()),
        ['龘']
    );
}

/// The line with `needle` of the block holding it in `pdf`.
fn line_of(pdf: &[u8], needle: &str) -> ferman_text::Line {
    let doc = document(pdf);
    block(&doc, 0, needle)
        .lines
        .into_iter()
        .find(|line| line.text.contains(needle))
        .unwrap()
}

#[test]
fn a_vertical_column_keeps_its_cells() {
    // E13: Identity-V, each new character in the cell of the one it replaces; only the
    // column's show is written again.
    let pdf = corpus("letter-ja-vertical");
    let (rewrite, after) = edit(&pdf, 0, "十月十三日", "十月十二日");
    assert_eq!(rewrite.splices.len(), 1);
    assert!(rewrite.fonts.is_empty() && rewrite.overflowing.is_empty());
    let (old, new) = (line_of(&pdf, "十月十三日"), line_of(&after, "十月十二日"));
    assert_eq!(old.baseline, new.baseline);
    for (a, b) in old.chars.iter().zip(&new.chars) {
        assert!(close(a.bbox.unwrap(), b.bbox.unwrap()), "{a:?} {b:?}");
    }
}

#[test]
fn a_column_grown_past_its_frame_is_overflowing() {
    // The date block's one column, one cell longer than its frame.
    let pdf = corpus("letter-ja-vertical");
    let (rewrite, _) = edit(&pdf, 0, "十月十三日", "十月十三日日");
    assert_eq!(rewrite.overflowing, [0]);
}

#[test]
fn a_top_aligned_column_grows_by_its_pitch() {
    // The body's last column, one character longer: the full stop moves down a cell.
    let pdf = corpus("letter-ja-vertical");
    let (rewrite, after) = edit(&pdf, 0, "です。", "でした。");
    assert!(rewrite.overflowing.is_empty());
    let (old, new) = (line_of(&pdf, "です。"), line_of(&after, "でした。"));
    let pitch = old.chars[1].bbox.unwrap()[1] - old.chars[0].bbox.unwrap()[1];
    let moved = new.chars[3].bbox.unwrap()[1] - old.chars[2].bbox.unwrap()[1];
    assert!((moved - pitch).abs() < 0.01, "{moved} {pitch}");
}

#[test]
fn an_upright_run_is_written_whole_and_centred() {
    // Tate-chu-yoko: "19" across the column, in its Identity-H font, centred in its cell.
    let pdf = corpus("letter-ja-vertical");
    let centre = |line: &ferman_text::Line, from: usize| {
        let [left, _, _, _] = line.chars[from].bbox.unwrap();
        let [_, _, right, _] = line.chars[from + 1].bbox.unwrap();
        (left + right) / 2.0
    };
    let old = line_of(&pdf, "19万");
    let at = old.chars.iter().position(|c| c.ch == '1').unwrap();
    let (_, after) = edit(&pdf, 0, "19万", "91万");
    let new = line_of(&after, "91万");
    assert!((centre(&old, at) - centre(&new, at)).abs() < 0.01);
    // Digits the subset lacks are missing glyphs (steps 2 and 3), never a vertical font.
    let doc = document(&pdf);
    let target = block(&doc, 0, "19万");
    let text = edited(&target, "19万", "20万");
    assert_eq!(
        missing(&rewrite_block(&doc, 0, &target, &text).unwrap()),
        ['2', '0']
    );
}

#[test]
fn vertical_text_that_is_not_one_show_or_reflows_is_not_rewritten_yet() {
    let pdf = corpus("letter-ja-vertical");
    let doc = document(&pdf);
    // Across the upright run and the vertical runs around it.
    let target = block(&doc, 0, "19万");
    let text = edited(&target, "賃料は 19万五", "賃料も 19円五");
    assert_eq!(
        rewrite_block(&doc, 0, &target, &text).unwrap(),
        Outcome::Unsupported(Unsupported::Direction)
    );
    // A reflow of columns (kinsoku, columns from the right) is not written yet.
    let text = target
        .lines
        .iter()
        .map(|line| line.text.as_str())
        .collect::<String>();
    assert_eq!(
        rewrite_block(&doc, 0, &target, &text).unwrap(),
        Outcome::Unsupported(Unsupported::Direction)
    );
    // A bottom-aligned column keeps its length.
    let target = block(&doc, 0, "敬具");
    assert_eq!(
        rewrite_block(&doc, 0, &target, "敬具具").unwrap(),
        Outcome::Unsupported(Unsupported::Direction)
    );
}

#[test]
fn marked_content_with_actual_text_is_kept() {
    // E21: the /ActualText around the line stays as it is.
    let pdf = corpus("edit-e21-actualtext");
    let (rewrite, after) = edit(&pdf, 0, "0216 555", "0612 555");
    let (_, before) = stream(&pdf, object(rewrite.splices[0].source));
    let (_, now) = stream(&after, object(rewrite.splices[0].source));
    let bdc = find(&before, b"BDC", 0).unwrap();
    assert_eq!(before[..bdc], now[..bdc]);
}

#[test]
fn rotated_pages_and_split_contents_and_inline_images() {
    // E19, E22 and E26.
    edit(&corpus("edit-e19-rotate"), 0, "Duyuru", "Duyurular");
    edit(&corpus("edit-e22-split-contents"), 0, "bildirir", "duyurur");
    edit(&corpus("edit-e22-split-contents"), 0, "Duyuru", "Duyurular");
    let pdf = corpus("edit-e26-inline-image");
    let (rewrite, after) = edit(&pdf, 0, "Duyuru", "Duyurular");
    let (_, before) = stream(&pdf, object(rewrite.splices[0].source));
    let (_, now) = stream(&after, object(rewrite.splices[0].source));
    let image = |data: &[u8]| {
        let start = find(data, b"BI", 0).unwrap();
        data[start..find(data, b"EI", start).unwrap()].to_vec()
    };
    assert_eq!(image(&before), image(&now), "the inline image's bytes");
}

#[test]
fn word_spaced_lines_keep_their_word_spacing() {
    // A justified line by Tw: the new words' spaces stretch by the same Tw.
    let (rewrite, _) = edit(&corpus("edit-e19-rotate"), 0, "nedeniyle", "sebebiyle");
    assert!(!String::from_utf8_lossy(&rewrite.splices[0].bytes).contains("Tw"));
}

#[test]
fn text_in_a_form_rewrites_the_form() {
    // E20: the form's own stream; copying it for one placement is the caller's (§6.5).
    let (rewrite, _) = edit(&corpus("edit-e20-form-twice"), 0, "ALINDI", "ALIN");
    assert!(matches!(rewrite.splices[0].source, SpanSource::Form { .. }));
}

/// A one-page file with font `F1` and `content`, objects from 5 on being `extra`.
fn fixture(font: &str, extra: &[Vec<u8>], content: &[u8]) -> Vec<u8> {
    let mut objects: Vec<Vec<u8>> = vec![
        b"<</Type/Catalog/Pages 2 0 R>>".to_vec(),
        b"<</Type/Pages/Kids[3 0 R]/Count 1>>".to_vec(),
        b"<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Resources<</Font<</F1 4 0 R>>>>/Contents 5 0 R>>"
            .to_vec(),
        font.as_bytes().to_vec(),
    ];
    let mut body = format!("<</Length {}>>stream\n", content.len()).into_bytes();
    body.extend_from_slice(content);
    body.extend_from_slice(b"\nendstream");
    objects.push(body);
    objects.extend(extra.iter().cloned());
    let mut out = b"%PDF-1.7\n".to_vec();
    let mut offsets = Vec::new();
    for (at, object) in objects.iter().enumerate() {
        offsets.push(out.len());
        out.extend_from_slice(format!("{} 0 obj\n", at + 1).as_bytes());
        out.extend_from_slice(object);
        out.extend_from_slice(b"\nendobj\n");
    }
    let xref = out.len();
    out.extend_from_slice(
        format!("xref\n0 {}\n0000000000 65535 f \n", objects.len() + 1).as_bytes(),
    );
    for offset in offsets {
        out.extend_from_slice(format!("{offset:010} 00000 n \n").as_bytes());
    }
    out.extend_from_slice(
        format!(
            "trailer\n<</Size {}/Root 1 0 R>>\nstartxref\n{xref}\n%%EOF\n",
            objects.len() + 1
        )
        .as_bytes(),
    );
    out
}

const TIMES: &str = "<</Type/Font/Subtype/Type1/BaseFont/Times-Roman/Encoding<</Type/Encoding/BaseEncoding/WinAnsiEncoding/Differences[200/Scedilla/gbreve/dotlessi]>>>>";

#[test]
fn standard_14_with_differences_encodes_through_them() {
    let pdf = fixture(
        TIMES,
        &[],
        b"BT /F1 12 Tf 72 700 Td (Kar\\310 kap\\312) Tj 0 -16 Td (Next line) Tj ET",
    );
    edit(&pdf, 0, "KarŞ", "Kağıt");
    // "İ" has no code: WinAnsi lacks it and /Differences does not name it.
    let doc = document(&pdf);
    let target = block(&doc, 0, "KarŞ");
    let text = edited(&target, "KarŞ", "İŞ");
    assert_eq!(
        missing(&rewrite_block(&doc, 0, &target, &text).unwrap()),
        ['İ']
    );
}

#[test]
fn standard_encoding_is_a_type1_fonts_default() {
    // No /Encoding: StandardEncoding, where "’" is 0x27 and "fi" 0xAE.
    let pdf = fixture(
        "<</Type/Font/Subtype/Type1/BaseFont/Helvetica-Bold>>",
        &[],
        b"BT /F1 12 Tf 72 700 Td (Its office) Tj ET",
    );
    let (rewrite, _) = edit(&pdf, 0, "Its office", "It’s \u{FB01}ne");
    let bytes = String::from_utf8_lossy(&rewrite.splices[0].bytes).into_owned();
    assert_eq!(bytes, "(It's \\256ne) Tj");
}

#[test]
fn text_after_the_block_that_continues_from_it_stays_put() {
    // "Right" is placed by the text matrix "Left" leaves, 240 points on: another line, which
    // must not move when "Left" grows (the state invariant, an empty TJ restores the matrix).
    let pdf = fixture(
        TIMES,
        &[],
        b"BT /F1 12 Tf 72 700 Td (Left) Tj [-20000 (Right)] TJ ET",
    );
    let (rewrite, _) = edit(&pdf, 0, "Left", "Leftover");
    let bytes = String::from_utf8_lossy(&rewrite.splices[0].bytes).into_owned();
    assert!(bytes.contains("Tm") && bytes.ends_with("] TJ"), "{bytes}");
}

#[test]
fn a_move_inside_a_line_is_undone_for_the_next_line() {
    // The `Td` inside "AB" moved the line matrix, which the next line's `Td` starts from.
    let pdf = fixture(
        TIMES,
        &[],
        b"BT /F1 12 Tf 72 700 Td (A) Tj 10 0 Td (B) Tj 0 -20 Td (Below) Tj ET",
    );
    let (rewrite, _) = edit(&pdf, 0, "AB", "ABC");
    let bytes = String::from_utf8_lossy(&rewrite.splices[0].bytes).into_owned();
    assert!(bytes.ends_with("1 0 0 1 82 700 Tm"), "{bytes}");
}

#[test]
fn kerning_of_the_unchanged_text_is_kept() {
    let pdf = fixture(
        TIMES,
        &[],
        b"BT /F1 12 Tf 72 700 Td [(W) 80 (ave) -20 (s)] TJ ET",
    );
    let (rewrite, _) = edit(&pdf, 0, "Waves", "Wavy");
    let bytes = String::from_utf8_lossy(&rewrite.splices[0].bytes).into_owned();
    assert_eq!(bytes, "[(W) 80 (avy)] TJ");
}

#[test]
fn lines_justified_by_adjustments_give_new_spaces_the_mean_adjustment() {
    let pdf = fixture(
        TIMES,
        &[],
        b"BT /F1 12 Tf 14 TL 72 700 Td [(Aaaa) ( ) -800 (bbbb) ( ) -800 (cccc) ( ) -800 (dddd)] TJ (Aaaa bbbb) ' ET",
    );
    let doc = document(&pdf);
    assert_eq!(
        block(&doc, 0, "Aaaa").justification,
        Some(ferman_text::Justification::Adjustments)
    );
    // Shorter, so the line stays in its frame and is rewritten line by line.
    let (rewrite, _) = edit(&pdf, 0, "cccc dddd", "cc dd e");
    let bytes = String::from_utf8_lossy(&rewrite.splices[0].bytes).into_owned();
    assert_eq!(bytes.matches("-800").count(), 4, "{bytes}");
}

#[test]
fn a_line_started_by_a_quote_operator_keeps_its_move() {
    let pdf = fixture(
        TIMES,
        &[],
        b"BT /F1 12 Tf 14 TL 72 700 Td (First line) Tj (Second line) ' 3 1 (Third line) \" ET",
    );
    edit(&pdf, 0, "Second", "2nd");
    edit(&pdf, 0, "Third", "3rd");
}

#[test]
fn symbolic_truetype_encodes_through_its_cmap_and_to_unicode() {
    let program = std::fs::read(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../app/assets/fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf"),
    )
    .unwrap();
    let mut file = format!("<</Length {}>>stream\n", program.len()).into_bytes();
    file.extend_from_slice(&program);
    file.extend_from_slice(b"\nendstream");
    let cmap = b"/CIDInit /ProcSet findresource begin 12 dict begin begincmap
1 begincodespacerange <00> <FF> endcodespacerange
1 beginbfrange <20> <7E> <0020> endbfrange endcmap end end";
    let mut to_unicode = format!("<</Length {}>>stream\n", cmap.len()).into_bytes();
    to_unicode.extend_from_slice(cmap);
    to_unicode.extend_from_slice(b"\nendstream");
    let descriptor =
        b"<</Type/FontDescriptor/FontName/IBMPlexSans/Flags 4/FontBBox[0 -200 1000 900]/ItalicAngle 0/Ascent 780/Descent -220/CapHeight 700/StemV 80/FontFile2 6 0 R>>".to_vec();
    let widths: Vec<String> = (32..=126).map(|_| "600".to_owned()).collect();
    let font = format!(
        "<</Type/Font/Subtype/TrueType/BaseFont/IBMPlexSans/FirstChar 32/LastChar 126/Widths[{}]/FontDescriptor 8 0 R/ToUnicode 7 0 R>>",
        widths.join(" ")
    );
    let pdf = fixture(
        &font,
        &[file, to_unicode, descriptor],
        b"BT /F1 12 Tf 72 700 Td (Symbolic text) Tj ET",
    );
    edit(&pdf, 0, "Symbolic", "Plain");
}

#[test]
fn what_w1_does_not_rewrite_says_why() {
    let pdf = fixture(TIMES, &[], b"BT /F1 12 Tf 72 700 Td (One line) Tj ET");
    let doc = document(&pdf);
    let target = block(&doc, 0, "One line");
    assert_eq!(
        rewrite_block(&doc, 0, &target, "One line").unwrap(),
        Outcome::Rewritten(Rewrite::default())
    );
    // A colour change inside the line.
    let pdf = fixture(
        TIMES,
        &[],
        b"BT /F1 12 Tf 72 700 Td (Red) Tj 1 0 0 rg (Blue) Tj ET",
    );
    let doc = document(&pdf);
    let target = block(&doc, 0, "Red");
    let text = edited(&target, "Red", "Rot");
    assert_eq!(
        rewrite_block(&doc, 0, &target, &text).unwrap(),
        Outcome::Unsupported(Unsupported::Operators)
    );
}

#[test]
fn a_line_past_its_frame_is_written_and_flagged() {
    let pdf = fixture(
        TIMES,
        &[],
        b"BT /F1 12 Tf 14 TL 72 700 Td (A first line of some length) Tj (Short) ' ET",
    );
    let (rewrite, _) = edit(
        &pdf,
        0,
        "Short",
        "Short no more, now far longer than the first",
    );
    assert_eq!(rewrite.overflowing, [1]);
}

#[test]
fn a_replacement_character_is_never_written_as_an_unmapped_code() {
    // Arial, not embedded and without /Widths: every code counts as drawn, and WinAnsi's unused
    // codes read as U+FFFD; that is no code for a typed U+FFFD.
    let pdf = fixture(
        "<</Type/Font/Subtype/TrueType/BaseFont/Arial/Encoding/WinAnsiEncoding>>",
        &[],
        b"BT /F1 12 Tf 72 700 Td (Price) Tj ET",
    );
    let doc = document(&pdf);
    let target = block(&doc, 0, "Price");
    let text = edited(&target, "Price", "Pr\u{FFFD}ce");
    assert_eq!(
        missing(&rewrite_block(&doc, 0, &target, &text).unwrap()),
        ['\u{FFFD}']
    );
}

/// Reflows the block with `needle` on `page` of `pdf` to `text` with `choice`, checks the result
/// as [`edit`] does and returns the rewrite, the new file and the block's lines after.
fn reflow_edit(
    pdf: &[u8],
    page: usize,
    needle: &str,
    text: &str,
    choice: Option<Choice>,
) -> (Rewrite, Vec<u8>, Vec<String>) {
    let before = document(pdf);
    let model = text_page(&before, page, &EditContext::default()).unwrap();
    let target = block(&before, page, needle);
    let outcome =
        rewrite_block_with(&before, None, page, &target, text, &model.blocks, choice).unwrap();
    let Outcome::Rewritten(rewrite) = outcome else {
        panic!("{needle:?} → {text:?}: {outcome:?}");
    };
    assert!(!rewrite.splices.is_empty());
    let (after_pdf, placed) = apply(pdf, &rewrite.splices);
    let after = document(&after_pdf);
    check(&before, &after, page, &target, text, &rewrite, &placed);
    let first = text.split_whitespace().next().unwrap();
    let lines = text_page(&after, page, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| {
            block
                .lines
                .first()
                .is_some_and(|l| l.text.starts_with(first))
        })
        .map(|block| block.lines.into_iter().map(|line| line.text).collect())
        .unwrap_or_default();
    (rewrite, after_pdf, lines)
}

const PARAGRAPH: &[u8] = b"BT /F1 12 Tf 14 TL 72 700 Td (The quick brown fox jumps over the) Tj T* \
(lazy dog and runs far away to) Tj T* (the green hills.) Tj ET BT /F1 12 Tf 72 600 Td (Below) Tj ET";

#[test]
fn a_paragraph_reflows_into_fewer_lines() {
    let pdf = fixture(TIMES, &[], PARAGRAPH);
    let (rewrite, _, lines) = reflow_edit(
        &pdf,
        0,
        "quick",
        "The quick brown fox jumps over the lazy dog.",
        None,
    );
    assert_eq!(rewrite.overflow, None);
    assert_eq!(rewrite.chosen, None);
    assert_eq!(lines, ["The quick brown fox jumps over the", "lazy dog."]);
}

#[test]
fn overflow_offers_the_three_choices_and_writes_each() {
    let pdf = fixture(TIMES, &[], PARAGRAPH);
    let text = "The quick brown fox jumps over the lazy dog and runs far away to the green \
                hills, where it sleeps until the morning comes.";
    // No choice yet: Keep and warn, the line past the frame written invisible.
    let (rewrite, after, lines) = reflow_edit(&pdf, 0, "quick", text, None);
    let plan = rewrite.overflow.clone().unwrap();
    assert_eq!(plan.over, 1);
    assert_eq!(plan.keep.hidden, 1);
    assert_eq!(plan.extend.as_ref().unwrap().lines, 1);
    assert_eq!(rewrite.chosen, Some(Choice::Keep));
    assert_eq!(rewrite.hidden, 1);
    assert_eq!(lines.len(), 4, "{lines:?}");
    let (_, data) = stream(&after, 5);
    assert!(find(&data, b" 3 Tr", 0).is_some());
    // The hidden text is still in the file.
    let extracted = ferman_text::extract::page_text(&document(&after), 0).unwrap();
    assert!(extracted.contains("morning"), "{extracted}");

    let (rewrite, _, lines) = reflow_edit(&pdf, 0, "quick", text, Some(Choice::Extend));
    assert_eq!((rewrite.chosen, rewrite.hidden), (Some(Choice::Extend), 0));
    assert_eq!(lines.len(), 4);

    // Too much for tightening: the choice falls back to Keep.
    assert!(plan.tighten.is_err());
    let (rewrite, ..) = reflow_edit(&pdf, 0, "quick", text, Some(Choice::Tighten));
    assert_eq!(rewrite.chosen, Some(Choice::Keep));
}

#[test]
fn tightening_writes_the_planned_tracking() {
    let pdf = fixture(TIMES, &[], PARAGRAPH);
    let text = "The quick brown fox jumps over the lazy dog and runs far away to the green hills.";
    // A word of the last line growing a letter at a time: the first overflow is less than a
    // letter, which tightening within the cap fits.
    let (longer, rewrite) = (1..60)
        .find_map(|n| {
            let longer = text.replace("green", &format!("green{}", "x".repeat(n)));
            let (rewrite, ..) = reflow_edit(&pdf, 0, "quick", &longer, None);
            rewrite
                .overflow
                .as_ref()
                .is_some_and(|plan| plan.tighten.is_ok())
                .then_some((longer, rewrite))
        })
        .expect("an overflow that tightening fits");
    let tighten = rewrite.overflow.unwrap().tighten.unwrap();
    assert!(tighten.percent > 0.0 && tighten.percent <= 2.0);
    assert_eq!(rewrite.hidden, 1);
    let (rewrite, after, lines) = reflow_edit(&pdf, 0, "quick", &longer, Some(Choice::Tighten));
    assert_eq!((rewrite.chosen, rewrite.hidden), (Some(Choice::Tighten), 0));
    assert_eq!(lines.len(), 3, "{lines:?}");
    let (_, data) = stream(&after, 5);
    assert!(find(&data, b" Tc", 0).is_some());
}

#[test]
fn a_right_aligned_cell_keeps_its_right_edge() {
    // E07: the amounts of fatura-tr's table are right-aligned cells.
    let pdf = corpus("fatura-tr");
    let target = block(&document(&pdf), 0, "1.250,00");
    assert_eq!(target.alignment, ferman_text::Alignment::Right);
    let end = target.lines[0].baseline[1];
    let (rewrite, after, lines) = reflow_edit(&pdf, 0, "1.250,00", "11.250,00", None);
    assert_eq!((rewrite.overflow, lines.len()), (None, 1));
    let moved = block(&document(&after), 0, "11.250,00");
    let new_end = moved.lines[0].baseline[1];
    assert!(
        (new_end[0] - end[0]).abs() < 0.05 && (new_end[1] - end[1]).abs() < 0.05,
        "{end:?} → {new_end:?}"
    );
}

#[test]
fn a_one_line_cell_grows_along_its_line_and_never_wraps() {
    // A longer amount with a space (thousands spaced), in a right-aligned cell whose frame is its old text: the
    // cell stays one line, its right edge kept, and nothing overflows into hiding.
    let pdf = corpus("fatura-tr");
    let end = block(&document(&pdf), 0, "1.250,00").lines[0].baseline[1];
    let (rewrite, after, lines) = reflow_edit(&pdf, 0, "1.250,00", "11 250,00", None);
    assert_eq!(
        (rewrite.overflow, rewrite.hidden, lines.len()),
        (None, 0, 1)
    );
    let new_end = block(&document(&after), 0, "11 250,00").lines[0].baseline[1];
    assert!((new_end[0] - end[0]).abs() < 0.05, "{end:?} → {new_end:?}");
}

#[test]
fn a_paragraph_justified_by_adjustments_stretches_its_spaces_by_tj() {
    // E08: tez-tr's ÖZET, an Identity-H font whose space is a two-byte code, justified by TJ.
    let pdf = corpus("tez-tr");
    let doc = document(&pdf);
    let target = block(&doc, 2, "Bu tez");
    assert_eq!(
        target.justification,
        Some(ferman_text::Justification::Adjustments)
    );
    let text = target
        .lines
        .iter()
        .map(|line| line.text.clone())
        .collect::<Vec<_>>()
        .join(" ")
        .replacen("üç ilçesinde", "dört ilçesinde", 1);
    let outcome = rewrite_block_with(&doc, None, 2, &target, &text, &[], None).unwrap();
    let Outcome::Rewritten(rewrite) = outcome else {
        panic!("{outcome:?}")
    };
    let bytes = String::from_utf8_lossy(&rewrite.splices[0].bytes).into_owned();
    let first = bytes.split(" Tm ").nth(1).unwrap();
    assert!(first.starts_with('[') && first.contains("> -"), "{first}");
}

#[test]
fn kira_tr_madde_4_grows_past_the_iban_line() {
    // E06 at the text level: the sentence needs a third line, and the IBAN line blocks Extend.
    let pdf = corpus("kira-tr");
    let target = block(&document(&pdf), 0, "aylık kira bedeli olan");
    let text = target
        .lines
        .iter()
        .map(|line| line.text.clone())
        .collect::<Vec<_>>()
        .join(" ")
        + " Kiracı, gecikme hâlinde kiraya verene yazılı bildirimde bulunur.";
    let (rewrite, _, lines) = reflow_edit(&pdf, 0, "aylık kira bedeli olan", &text, None);
    let plan = rewrite.overflow.unwrap_or_else(|| panic!("{lines:?}"));
    assert_eq!(plan.over, 1);
    assert!(matches!(
        plan.extend,
        Err(ferman_text::ExtendBlocked::Block { ref text, .. }) if text.starts_with("IBAN")
    ));
}

#[test]
fn a_glyph_an_actual_text_covers_in_its_own_show_leaves_the_line_unsupported() {
    // Replacing only the first show would leave the second glyph drawn beside the new text.
    let content =
        b"/Span <</ActualText (fi)>> BDC BT /F1 12 Tf 72 700 Td (\\001) Tj (\\001) Tj ET EMC";
    let mut bytes = b"%PDF-1.7\n1 0 obj <</Type/Catalog/Pages 2 0 R>> endobj\n\
        2 0 obj <</Type/Pages/Kids[3 0 R]/Count 1>> endobj\n\
        3 0 obj <</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R\
        /Resources<</Font<</F1<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>>>>>>> endobj\n"
        .to_vec();
    bytes.extend_from_slice(format!("4 0 obj <</Length {}>> stream\n", content.len()).as_bytes());
    bytes.extend_from_slice(content);
    bytes.extend_from_slice(b"\nendstream endobj\ntrailer <</Root 1 0 R>>\n");
    let doc = document(&bytes);
    let target = block(&doc, 0, "fi");
    assert!(matches!(
        rewrite_block(&doc, 0, &target, "fo").unwrap(),
        Outcome::Unsupported(Unsupported::Operators)
    ));
}
