//! One-page files for the structure cases of the edit corpus (ROADMAP §7), in IBM Plex Sans as
//! Word sets it (simple TrueType WinAnsi subsets, composite ones for ş, ı, ğ and İ):
//!
//! - `edit-e19-rotate`: a page with `/Rotate 90`, and on it a line set with a rotating `Tm`
//!   ([0.8 0.6 -0.6 0.8], about 36.87°, exact without trigonometry) (E19). PDFium reads a turned
//!   page only inside its turned size, so the text stays below 595 pt, and in an order of its
//!   own, so the oracle compares its characters.
//! - `edit-e20-form-twice`: a stamp's text in a Form XObject, placed twice on the page (E20).
//! - `edit-e21-actualtext`: a line inside `/Span` marked content with an `/ActualText` that
//!   matches it (E21).
//! - `edit-e22-split-contents`: a paragraph whose operators run across the two streams of a
//!   `/Contents` array; the boundary falls inside the text object of its second line, between
//!   `Tf` and `TJ` (E22).
//! - `edit-e23-shared-contents`: two pages with one content stream and one resource dictionary
//!   (E23).
//! - `edit-e26-inline-image`: lines beside an inline image (`BI … ID … EI`), 16 by 16 grey
//!   pixels whose bytes are all above 0x7F, so none reads as `EI` (E26).

use super::{Doc, generated, info, open_first, opens};
use crate::pdf::{self, num, rect, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Expected, Flow, Frame, PageText, PageTruth, Paragraph, Style, expected};
use crate::{Expect, Generated, Generator};
use lopdf::{Dictionary, Object, ObjectId, dictionary};

/// A rotated page with rotated text.
pub const EDIT_E19_ROTATE: Generator = Generator {
    name: "edit-e19-rotate",
    build: e19,
    expect: Expect::OpensUnordered,
};

/// A Form XObject placed twice.
pub const EDIT_E20_FORM_TWICE: Generator = Generator {
    name: "edit-e20-form-twice",
    build: e20,
    expect: opens(),
};

/// Marked content with `/ActualText`.
pub const EDIT_E21_ACTUALTEXT: Generator = Generator {
    name: "edit-e21-actualtext",
    build: e21,
    expect: opens(),
};

/// A paragraph across two content streams.
pub const EDIT_E22_SPLIT_CONTENTS: Generator = Generator {
    name: "edit-e22-split-contents",
    build: e22,
    expect: opens(),
};

/// One content stream on two pages.
pub const EDIT_E23_SHARED_CONTENTS: Generator = Generator {
    name: "edit-e23-shared-contents",
    build: e23,
    expect: opens(),
};

/// Text beside an inline image.
pub const EDIT_E26_INLINE_IMAGE: Generator = Generator {
    name: "edit-e26-inline-image",
    build: e26,
    expect: opens(),
};

const LEFT: f64 = 72.0;
const WIDTH: f64 = pdf::A4.0 - 144.0;
const TOP: f64 = pdf::A4.1 - 80.0;

const NOTICE: &str = "Bina yönetimi, asansör bakımı nedeniyle 9 Kasım 2026 Pazartesi günü 09.00 ile 13.00 arasında asansörün kullanılamayacağını bildirir. Anlayışınız için teşekkür ederiz.";

fn body(doc: &mut Doc, sources: &Sources) -> Result<Style, String> {
    doc.word_style(sources, FontFile::PlexSans, 11.0)
}

/// `paragraphs` flowed down a page from `top`, the first as a title.
fn flowed(doc: &mut Doc, style: &Style, paragraphs: &[&str], top: f64) -> Result<PageText, String> {
    let mut flow = Flow::new(Frame {
        x: LEFT,
        top,
        bottom: 80.0,
        width: WIDTH,
    });
    for (index, paragraph) in paragraphs.iter().enumerate() {
        let paragraph = if index == 0 {
            Paragraph::new(&style.sized(16.0), paragraph)
                .aligned(Align::Left)
                .spaced(0.0, 12.0)
        } else {
            Paragraph::new(style, paragraph).spaced(0.0, 8.0)
        };
        flow.paragraph(&mut doc.fonts, &paragraph)?;
    }
    flow.into_pages()
        .into_iter()
        .next()
        .ok_or_else(|| "no page".to_owned())
}

/// A page's content without its text record: the lines and blocks, and the `/Resources` and
/// content bytes it would have.
fn parts(doc: &Doc, mut page: PageText) -> (Vec<String>, PageTruth, Dictionary, Vec<u8>) {
    let lines = std::mem::take(&mut page.lines);
    let truth = page.truth();
    let page = page.into_page(&doc.fonts, pdf::A4);
    (lines, truth, page.resources, page.content)
}

/// The catalog, the information dictionary and the file.
fn finish(doc: Doc, first: ObjectId, expected: Expected, name: &str) -> Result<Generated, String> {
    let catalog = dictionary! { "Lang" => text("tr-TR"), "OpenAction" => open_first(first) };
    let bytes = doc.close(
        catalog,
        &info(
            name,
            "Ferman test corpus",
            "tools/corpus",
            "D:20261102120000+03'00'",
        ),
        name,
        None,
    )?;
    Ok(generated(bytes, expected))
}

/// Adds `pages` the usual way and writes the file.
fn usual(mut doc: Doc, pages: Vec<PageText>, name: &str) -> Result<Generated, String> {
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let first = ids.first().copied().ok_or("no page")?;
    finish(doc, first, expected, name)
}

/// The operators `doc.line` writes for `line` at `origin`, apart from the page.
fn line_content(
    doc: &mut Doc,
    style: &Style,
    line: &str,
    origin: (f64, f64),
) -> Result<PageText, String> {
    let mut part = PageText::default();
    doc.line(&mut part, style, line, origin, WIDTH, Align::Left)?;
    Ok(part)
}

/// Moves what `part` draws and records onto `page`, its operators changed by `rewrite` and the
/// points of its blocks by `place`.
fn merge(
    page: &mut PageText,
    mut part: PageText,
    rewrite: impl Fn(&str) -> String,
    place: impl Fn((f64, f64)) -> (f64, f64),
) {
    page.take_text(&mut part, place);
    let content = String::from_utf8_lossy(&part.content.into_bytes()).into_owned();
    for op in content.lines() {
        page.content.op(&rewrite(op));
    }
}

/// Where a point stays.
fn unmoved(point: (f64, f64)) -> (f64, f64) {
    point
}

fn e19(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = body(&mut doc, sources)?;
    // Below 595 pt: PDFium reads a page turned by 90° only inside its turned size.
    let mut page = flowed(&mut doc, &style, &["Duyuru", NOTICE], 540.0)?;
    let part = line_content(
        &mut doc,
        &style,
        "Yönetim Kurulu adına: Selin Öztürk",
        (LEFT, 300.0),
    )?;
    // The line's `x y Td` becomes the same origin in a rotating text matrix. From 300 pt the
    // turned line, about 190 pt long, rises to some 420 pt, clear of the paragraph above it.
    let rotate = |(x, y): (f64, f64)| {
        let (dx, dy) = (x - LEFT, y - 300.0);
        (LEFT + 0.8 * dx - 0.6 * dy, 300.0 + 0.6 * dx + 0.8 * dy)
    };
    merge(
        &mut page,
        part,
        |op| match op.strip_suffix(" Td") {
            Some(origin) => format!("0.8 0.6 -0.6 0.8 {origin} Tm"),
            None => op.to_owned(),
        },
        rotate,
    );
    page.extra.set("Rotate", 90);
    usual(doc, vec![page], "edit-e19-rotate")
}

fn e20(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = body(&mut doc, sources)?;
    let mut page = flowed(
        &mut doc,
        &style,
        &[
            "Teslim Formu",
            "Aşağıdaki iki kutu, belgenin asıl ve suret nüshalarının teslim kaydıdır.",
        ],
        TOP,
    )?;
    let mut stamp = line_content(&mut doc, &style, "TESLİM ALINDI", (10.0, 52.0))?;
    let part = line_content(
        &mut doc,
        &style.sized(9.0),
        "Moda Gayrimenkul, Kadıköy şubesi",
        (10.0, 34.0),
    )?;
    merge(&mut stamp, part, str::to_owned, unmoved);
    let part = line_content(
        &mut doc,
        &style.sized(9.0),
        "Tarih: 2 Kasım 2026",
        (10.0, 18.0),
    )?;
    merge(&mut stamp, part, str::to_owned, unmoved);
    // The branch and the date are one block under the stamp's title.
    stamp.join_last();
    stamp
        .content
        .line_width(1.0)
        .stroke_rect(2.0, 2.0, 216.0, 76.0);
    let (stamp_lines, stamp_truth, resources, content) = parts(&doc, stamp);
    let form = doc.pdf.stream(
        dictionary! {
            "Type" => "XObject",
            "Subtype" => "Form",
            "BBox" => rect(0.0, 0.0, 220.0, 80.0),
            "Resources" => resources,
        },
        content,
    );
    for y in [560.0, 440.0] {
        page.content.op(&format!(
            "q\n1 0 0 1 {} {} cm\n/Fm1 Do\nQ",
            num(LEFT),
            num(y)
        ));
        let mut placed = PageText {
            lines: stamp_lines.clone(),
            blocks: stamp_truth.blocks.clone(),
            ..PageText::default()
        };
        page.take_text(&mut placed, |(x, at)| (x + LEFT, at + y));
    }
    page.resources.set("XObject", dictionary! { "Fm1" => form });
    usual(doc, vec![page], "edit-e20-form-twice")
}

fn e21(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = body(&mut doc, sources)?;
    let mut page = flowed(&mut doc, &style, &["Duyuru", NOTICE], TOP)?;
    const MARKED: &str = "İletişim: yonetim@modagayrimenkul.example, 0216 555 01 18";
    let part = line_content(&mut doc, &style, MARKED, (LEFT, 600.0))?;
    let utf16: String = std::iter::once(0xFEFF)
        .chain(MARKED.encode_utf16())
        .map(|unit| format!("{unit:04X}"))
        .collect();
    page.content
        .op(&format!("/Span <</ActualText <{utf16}>>> BDC"));
    merge(&mut page, part, str::to_owned, unmoved);
    page.content.op("EMC");
    usual(doc, vec![page], "edit-e21-actualtext")
}

fn e22(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = body(&mut doc, sources)?;
    let page = flowed(&mut doc, &style, &["Duyuru", NOTICE], TOP)?;
    let (lines, truth, resources, content) = parts(&doc, page);
    // After the first `Tf` of the third text object (the title, then the paragraph's lines).
    let find = |from: usize, needle: &[u8]| {
        content
            .get(from..)?
            .windows(needle.len())
            .position(|window| window == needle)
            .map(|at| from + at + needle.len())
    };
    let third = find(0, b"BT\n")
        .and_then(|at| find(at, b"BT\n"))
        .and_then(|at| find(at, b"BT\n"))
        .ok_or("the paragraph has fewer than two lines")?;
    let split = find(third, b" Tf\n").ok_or("a line without Tf")?;
    let (first, second) = content.split_at(split);
    let first = doc.pdf.stream(Dictionary::new(), first.to_vec());
    let second = doc.pdf.stream(Dictionary::new(), second.to_vec());
    let id = doc.pdf.push_page(dictionary! {
        "MediaBox" => rect(0.0, 0.0, pdf::A4.0, pdf::A4.1),
        "Resources" => resources,
        "Contents" => vec![Object::Reference(first), Object::Reference(second)],
    });
    finish(
        doc,
        id,
        expected(&[lines], &[truth]),
        "edit-e22-split-contents",
    )
}

fn e23(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = body(&mut doc, sources)?;
    let page = flowed(
        &mut doc,
        &style,
        &["Duyuru", NOTICE, "Bu duyuru her kat panosuna asılmıştır."],
        TOP,
    )?;
    let (lines, truth, resources, content) = parts(&doc, page);
    let content = doc.pdf.stream(Dictionary::new(), content);
    let resources = doc.pdf.add(resources);
    let mut ids = Vec::new();
    for _ in 0..2 {
        ids.push(doc.pdf.push_page(dictionary! {
            "MediaBox" => rect(0.0, 0.0, pdf::A4.0, pdf::A4.1),
            "Resources" => resources,
            "Contents" => content,
        }));
    }
    let first = ids.first().copied().ok_or("no page")?;
    finish(
        doc,
        first,
        expected(&[lines.clone(), lines], &[truth.clone(), truth]),
        "edit-e23-shared-contents",
    )
}

fn e26(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = body(&mut doc, sources)?;
    let mut page = flowed(&mut doc, &style, &["Duyuru", NOTICE], TOP)?;
    let part = line_content(
        &mut doc,
        &style,
        "Onaylayan: Bina Yönetimi",
        (LEFT + 48.0, 612.0),
    )?;
    merge(&mut page, part, str::to_owned, unmoved);
    let (lines, truth, resources, mut content) = parts(&doc, page);
    content.extend_from_slice(
        format!(
            "q\n40 0 0 40 {} 600 cm\nBI\n/W 16\n/H 16\n/BPC 8\n/CS /G\nID ",
            num(LEFT)
        )
        .as_bytes(),
    );
    for y in 0u8..16 {
        for x in 0u8..16 {
            content.push(0x80 + (x + y) * 4);
        }
    }
    content.extend_from_slice(b"\nEI\nQ\n");
    let content = doc.pdf.stream(Dictionary::new(), content);
    let id = doc.pdf.push_page(dictionary! {
        "MediaBox" => rect(0.0, 0.0, pdf::A4.0, pdf::A4.1),
        "Resources" => resources,
        "Contents" => content,
    });
    finish(
        doc,
        id,
        expected(&[lines], &[truth]),
        "edit-e26-inline-image",
    )
}
