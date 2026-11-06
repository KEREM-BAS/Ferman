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
//!
//! Three generated stand-ins for the real-world files of E14, E17 and E18, which the owner has not
//! made yet (`docs/PROGRESS.md`, M3 question 4). They copy what those producers write as far as
//! this tool knows it, and do not replace the real files:
//!
//! - `edit-e14-latex-standin`: as `dvips` and `pdflatex` write Type1 fonts: an embedded `/FontFile`
//!   subset (IBM Plex Serif's outlines), codes in an order of the font's own, no space glyph
//!   (spaces are `TJ` adjustments) and no ToUnicode. One font names its codes in `/Differences`, the
//!   other in the program's own encoding (E14).
//! - `edit-e17-kerned-standin`: lines with kerning numbers in `TJ`: page 1 as Word writes a simple
//!   TrueType font (a pair table of its own), page 2 as Google Docs writes a composite one (the
//!   font's own kerning, shaped) (E17).
//! - `edit-e18-columns-standin`: two columns whose lines take turns in one text object, each placed
//!   by a `Td` relative to the other column's line: an edit that keeps no state invariant moves the
//!   other column (E18).

use super::{Doc, generated, info, open_first, opens};
use crate::font::{PdfFont, Type1Encoding};
use crate::pdf::{self, Content, num, rect, text};
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

/// Stand-in for E14's LaTeX file: Type1 fonts with `/Differences` and a built-in encoding.
pub const EDIT_E14_LATEX_STANDIN: Generator = Generator {
    name: "edit-e14-latex-standin",
    build: e14,
    expect: opens(),
};

/// Stand-in for E17's Word and Google Docs files: kerning numbers in `TJ`.
pub const EDIT_E17_KERNED_STANDIN: Generator = Generator {
    name: "edit-e17-kerned-standin",
    build: e17,
    expect: opens(),
};

/// Stand-in for E18's LibreOffice file: two columns whose operators interleave.
pub const EDIT_E18_COLUMNS_STANDIN: Generator = Generator {
    name: "edit-e18-columns-standin",
    build: e18,
    expect: Expect::OpensUnordered,
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

/// A style in a Type1 font of its own, written with `encoding`.
fn type1(doc: &mut Doc, sources: &Sources, encoding: Type1Encoding) -> Result<Style, String> {
    let style = doc.simple_style(sources, FontFile::PlexSerif, 11.0)?;
    if let Some(PdfFont::Simple(font)) = doc.fonts.get_mut(style.font) {
        font.type1 = Some(encoding);
    }
    Ok(style)
}

fn e14(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.5");
    let differences = type1(&mut doc, sources, Type1Encoding::Differences)?;
    let built_in = type1(&mut doc, sources, Type1Encoding::BuiltIn)?;
    let mut flow = Flow::new(Frame {
        x: LEFT,
        top: TOP,
        bottom: 80.0,
        width: WIDTH,
    });
    for (style, paragraph) in [
        (
            &differences,
            "The committee met on 12 May and read the report on rents in three districts. The tables in the second chapter give the rents of each year, and the notes explain how they were measured.",
        ),
        (
            &built_in,
            "The second survey, made in 2025, repeats the first one in each of the same districts, so the two can be compared line by line.",
        ),
    ] {
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(style, paragraph)
                .aligned(Align::Left)
                .spaced(0.0, 10.0),
        )?;
    }
    usual(doc, flow.into_pages(), "edit-e14-latex-standin")
}

/// The pairs the Word page tightens.
const KERNING: &[(char, char, f64)] = &[
    ('T', 'o', 70.0),
    ('A', 'V', 80.0),
    ('V', 'A', 80.0),
    ('A', 'T', 60.0),
    ('T', 'A', 60.0),
    ('W', 'a', 40.0),
    ('L', 'T', 70.0),
    ('Y', 'o', 60.0),
    ('r', '.', 30.0),
];

fn e17(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let mut word = doc.simple_style(sources, FontFile::PlexSans, 11.0)?;
    word.kerning = KERNING;
    let docs = doc.composite_style(sources, FontFile::PlexSans, 11.0)?;
    let mut pages = Vec::new();
    for style in [&word, &docs] {
        let mut flow = Flow::new(Frame {
            x: LEFT,
            top: TOP,
            bottom: 80.0,
            width: WIDTH,
        });
        for paragraph in [
            "To AVATAR Travel LTD: Your Way Ahead, in a Year.",
            "To Walter AVAT: Your order, sent on 12 May, is on its Way to You.",
        ] {
            flow.paragraph(
                &mut doc.fonts,
                &Paragraph::new(style, paragraph)
                    .aligned(Align::Left)
                    .spaced(0.0, 10.0),
            )?;
        }
        pages.extend(flow.into_pages());
    }
    usual(doc, pages, "edit-e17-kerned-standin")
}

/// A line's origin and operators.
type TextObject = (f64, f64, Vec<String>);

/// `page` without its content, and the text objects it held as (x, y, the operators between the
/// `Td` and the `ET`), for lines `draw_line` wrote: `BT`, `x y Td`, then the rest.
fn text_objects(mut page: PageText) -> Result<(PageText, Vec<TextObject>), String> {
    let content = std::mem::replace(&mut page.content, Content::new()).into_bytes();
    let content = String::from_utf8_lossy(&content).into_owned();
    let mut objects = Vec::new();
    let mut lines = content.lines();
    while let Some(line) = lines.next() {
        if line != "BT" {
            return Err(format!("not a text object: {line}"));
        }
        let origin = lines.next().ok_or("no Td")?;
        let mut parts = origin.split(' ');
        let x = parts.next().and_then(|x| x.parse().ok()).ok_or("no x")?;
        let y = parts.next().and_then(|y| y.parse().ok()).ok_or("no y")?;
        let ops = lines
            .by_ref()
            .take_while(|op| *op != "ET")
            .map(str::to_owned)
            .collect();
        objects.push((x, y, ops));
    }
    Ok((page, objects))
}

fn e18(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = body(&mut doc, sources)?;
    let width = (WIDTH - 24.0) / 2.0;
    let column = |doc: &mut Doc, x: f64, paragraphs: [&str; 2]| {
        let mut flow = Flow::new(Frame {
            x,
            top: TOP,
            bottom: 80.0,
            width,
        });
        for paragraph in paragraphs {
            flow.paragraph(
                &mut doc.fonts,
                &Paragraph::new(&style, paragraph)
                    .aligned(Align::Left)
                    .spaced(0.0, 14.0),
            )?;
        }
        flow.into_pages()
            .into_iter()
            .next()
            .ok_or_else(|| "no page".to_owned())
            .and_then(text_objects)
    };
    let (mut page, left) = column(
        &mut doc,
        LEFT,
        [
            "Apartman kurulu, asansör bakımının Kasım ayında yapılmasına karar verdi. Bakım süresince asansör kullanılamayacaktır.",
            "Bakım bedeli aidatlardan karşılanır ve kat maliklerinden ayrıca ücret alınmaz.",
        ],
    )?;
    let (mut right_page, right) = column(
        &mut doc,
        LEFT + width + 24.0,
        [
            "Çatı onarımı için üç firmadan teklif alındı. Teklifler yönetim odasında incelenebilir ve toplantıda oylanacaktır.",
            "Bir sonraki toplantı 14 Aralık 2026 Pazartesi günü saat 19.00 da yapılacaktır.",
        ],
    )?;
    page.take_text(&mut right_page, unmoved);
    // The lines take turns, in one text object, each placed from the one before it.
    let (mut at_x, mut at_y) = (0.0, 0.0);
    page.content.op("BT");
    for index in 0..left.len().max(right.len()) {
        for (x, y, ops) in [left.get(index), right.get(index)].into_iter().flatten() {
            page.content
                .op(&format!("{} {} Td", num(x - at_x), num(y - at_y)));
            (at_x, at_y) = (*x, *y);
            for op in ops {
                page.content.op(op);
            }
        }
    }
    page.content.op("ET");
    usual(doc, vec![page], "edit-e18-columns-standin")
}
