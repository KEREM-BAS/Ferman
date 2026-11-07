//! `annots-other-producer`: a 2-page Turkish contract review as another program would write it,
//! for the annotation reader (ROADMAP §8 step 2). Its `/Producer` is not ours, and it carries:
//!
//! - every type `a4-1` draws: Highlight, Underline, StrikeOut, Text, FreeText, a FreeText callout,
//!   Ink, Square, Circle, Line with and without an arrow, Polygon and Stamp;
//! - Squiggly, which Ferman reads and renders but never creates (decision 6);
//! - types Ferman does not know: Caret, written directly in `/Annots`, and a private subtype with
//!   a private key, which must survive byte for byte;
//! - some with `/AP` and some without, so a reader cannot rely on one;
//! - rich text (`/RC`, `/DS`), a `/Popup`, a reply (`/IRT`, `/RT /R`) and a review state reply
//!   (`/State`, `/StateModel`);
//! - a second page with `/Rotate 90`, with a turned FreeText appearance and a note with the
//!   NoZoom and NoRotate flags.

use super::{Doc, generated, info, open_first};
use crate::pdf::{self, Pdf, real, rect, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, PageText};
use crate::{Expect, Generated, Generator};
use lopdf::{Dictionary, Object, ObjectId, dictionary};

/// The file with annotations from another producer.
pub const ANNOTS_OTHER_PRODUCER: Generator = Generator {
    name: "annots-other-producer",
    build,
    expect: Expect::OpensUnordered,
};

const AUTHOR: &str = "Av. D. Aksoy";
const LEFT: f64 = 72.0;
const WIDTH: f64 = pdf::A4.0 - 144.0;
const RED: [f64; 3] = [0.851, 0.227, 0.169];
const BLUE: [f64; 3] = [0.165, 0.302, 0.686];
const YELLOW: [f64; 3] = [1.0, 0.82, 0.2];
/// The baseline of line `index` on a page.
const fn baseline(index: u8) -> f64 {
    740.0 - 22.0 * index as f64
}
/// The turned page's first baseline: low enough to stay inside the rectangle pdfium-render reads
/// text from, which has the turned page's height.
const TURNED_TOP: f64 = 540.0;

const FIRST_PAGE: [&str; 8] = [
    "KİRA SÖZLEŞMESİ İNCELEMESİ",
    "Madde 3. Kira bedeli her ayın beşinci gününe kadar ödenir.",
    "Madde 4. Depozito üç aylık kira bedelini aşamaz.",
    "Madde 5. Kiracı, yapılan bakımın masrafını kendisi karşılar.",
    "Madde 6. Ortak alanların temizliği yönetime aittir.",
    "Madde 7. Tahliye bildirimi yazılı olarak yapılır.",
    "Madde 8. Uyuşmazlıklarda İstanbul mahkemeleri yetkilidir.",
    "Madde 9. Bu sözleşme iki nüsha olarak düzenlenmiştir.",
];

const SECOND_PAGE: [&str; 3] = [
    "EK: DEMİRBAŞ LİSTESİ",
    "Mutfak dolapları, ocak ve aspiratör teslim edilmiştir.",
    "Salondaki klima kumandası ile birlikte teslim edilmiştir.",
];

const RICH_STYLE: &str = "font: 12.0pt 'Helvetica'; color:#D93A2B";

/// `value` as `/RC` writes it: XHTML with a style attribute and a bold run.
fn rich(value: &str, bold: &str) -> Object {
    text(&format!(
        "<?xml version=\"1.0\"?><body xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:xfa=\"http://www.xfa.org/schema/xfa-data/1.0/\" xfa:APIVersion=\"Annotator:7.2.0\" xfa:spec=\"2.0.2\"><p dir=\"ltr\"><span style=\"{RICH_STYLE}\">{value} <b>{bold}</b></span></p></body>"
    ))
}

fn numbers(values: &[f64]) -> Object {
    Object::Array(values.iter().map(|value| real(*value)).collect())
}

/// The corners of a text line, in the order producers write them.
fn quad(line: f64, width: f64) -> Object {
    let (x1, x2, y1, y2) = (LEFT, LEFT + width, line - 3.0, line + 10.0);
    numbers(&[x1, y2, x2, y2, x1, y1, x2, y1])
}

/// An appearance: its operators, resources and, for a turned one, `/Matrix`.
struct Ap {
    ops: String,
    resources: Dictionary,
    matrix: Option<[f64; 6]>,
}

impl Ap {
    fn new(ops: String) -> Self {
        Self {
            ops,
            resources: Dictionary::new(),
            matrix: None,
        }
    }
}

/// A translucent multiply state, as highlight appearances use.
fn multiply() -> Dictionary {
    dictionary! {
        "ExtGState" => dictionary! {
            "R0" => dictionary! { "Type" => "ExtGState", "BM" => "Multiply", "ca" => real(0.6) },
        },
    }
}

/// `/Font` with Helvetica, named but not embedded.
fn helvetica() -> Dictionary {
    dictionary! {
        "Font" => dictionary! {
            "Helv" => dictionary! {
                "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Helvetica",
                "Encoding" => "WinAnsiEncoding",
            },
        },
    }
}

/// The annotations of one page.
struct Marks {
    page: ObjectId,
    annots: Vec<Object>,
    serial: u32,
}

impl Marks {
    fn new(page: ObjectId) -> Self {
        Self {
            page,
            annots: Vec::new(),
            serial: 0,
        }
    }

    /// The entries every annotation has, as the other program writes them.
    fn dict(
        &mut self,
        subtype: &str,
        area: [f64; 4],
        color: [f64; 3],
        contents: &str,
        extra: Dictionary,
    ) -> Dictionary {
        self.serial += 1;
        let stamp = format!("D:202610131430{:02}+03'00'", self.serial % 60);
        let mut dict = dictionary! {
            "Type" => "Annot",
            "Subtype" => pdf::name(subtype),
            "Rect" => rect(area[0], area[1], area[2], area[3]),
            "P" => self.page,
            "NM" => text(&format!("7f3c-{}-{:04}", self.page.0, self.serial)),
            "T" => text(AUTHOR),
            "F" => 4,
            "C" => numbers(&color),
            "M" => text(&stamp),
            "CreationDate" => text(&stamp),
        };
        if !contents.is_empty() {
            dict.set("Contents", text(contents));
        }
        for (key, value) in extra {
            dict.set(key, value);
        }
        dict
    }

    /// Adds an annotation with its appearance, when it has one.
    #[allow(clippy::too_many_arguments)]
    fn add(
        &mut self,
        pdf: &mut Pdf,
        subtype: &str,
        area: [f64; 4],
        color: [f64; 3],
        contents: &str,
        extra: Dictionary,
        ap: Option<Ap>,
    ) -> ObjectId {
        let mut dict = self.dict(subtype, area, color, contents, extra);
        if let Some(ap) = ap {
            let (width, height) = match ap.matrix {
                // A quarter turn swaps the box's sides.
                Some(_) => (area[3] - area[1], area[2] - area[0]),
                None => (area[2] - area[0], area[3] - area[1]),
            };
            let mut form = dictionary! {
                "Type" => "XObject",
                "Subtype" => "Form",
                "BBox" => rect(0.0, 0.0, width, height),
                "Resources" => ap.resources,
            };
            if let Some(matrix) = ap.matrix {
                form.set("Matrix", numbers(&matrix));
            }
            let form = pdf.stream(form, ap.ops.into_bytes());
            dict.set("AP", dictionary! { "N" => form });
        }
        let id = pdf.add(dict);
        self.annots.push(id.into());
        id
    }
}

/// The first page's marks: one of each type, with an appearance or without.
fn first_page(pdf: &mut Pdf, page: ObjectId) -> Vec<Object> {
    let mut marks = Marks::new(page);
    let line = |index: u8| baseline(index);

    // Text markup.
    let area = [LEFT, line(1) - 3.0, LEFT + 300.0, line(1) + 10.0];
    let mut ap = Ap::new("/R0 gs 1 0.82 0.2 rg 0 0 300 13 re f".to_owned());
    ap.resources = multiply();
    marks.add(
        pdf,
        "Highlight",
        area,
        YELLOW,
        "Ödeme günü sözleşmenin başka yerinde de geçiyor.",
        dictionary! { "QuadPoints" => quad(line(1), 300.0), "CA" => real(0.6), "Subj" => text("Vurgu") },
        Some(ap),
    );
    let area = [LEFT, line(2) - 3.0, LEFT + 260.0, line(2) + 10.0];
    marks.add(
        pdf,
        "Highlight",
        area,
        YELLOW,
        "",
        dictionary! { "QuadPoints" => quad(line(2), 260.0) },
        None,
    );
    let area = [LEFT, line(3) - 3.0, LEFT + 300.0, line(3) + 10.0];
    marks.add(
        pdf,
        "Squiggly",
        area,
        RED,
        "Yazım: \"masrafını\".",
        dictionary! { "QuadPoints" => quad(line(3), 300.0) },
        None,
    );
    let area = [LEFT, line(4) - 3.0, LEFT + 280.0, line(4) + 10.0];
    marks.add(
        pdf,
        "Underline",
        area,
        BLUE,
        "",
        dictionary! { "QuadPoints" => quad(line(4), 280.0) },
        None,
    );
    let area = [LEFT, line(5) - 3.0, LEFT + 260.0, line(5) + 10.0];
    marks.add(
        pdf,
        "StrikeOut",
        area,
        RED,
        "Bu cümle kaldırılsın.",
        dictionary! { "QuadPoints" => quad(line(5), 260.0) },
        Some(Ap::new(
            "0.851 0.227 0.169 RG 1 w 0 6 m 260 6 l S".to_owned(),
        )),
    );

    // A note with a popup, a reply and a state.
    let popup = pdf.reserve();
    let note_area = [500.0, line(2) - 4.0, 520.0, line(2) + 16.0];
    let note = marks.add(
        pdf,
        "Text",
        note_area,
        YELLOW,
        "TBK m. 342: depozito üç aylık kira bedelini aşamaz.",
        dictionary! {
            "Name" => "Comment",
            "Open" => false,
            "Popup" => popup,
            "RC" => rich("TBK m. 342:", "üç aylık"),
            "Subj" => text("Not"),
        },
        None,
    );
    let popup_dict = marks.dict(
        "Popup",
        [523.0, line(2) - 80.0, 590.0, line(2) + 16.0],
        YELLOW,
        "",
        dictionary! { "Parent" => note, "Open" => false, "F" => 28 },
    );
    pdf.set(popup, popup_dict);
    marks.annots.push(popup.into());
    marks.add(
        pdf,
        "Text",
        note_area,
        YELLOW,
        "Uygun, 37.000 TL.",
        dictionary! { "IRT" => note, "RT" => "R", "Name" => "Comment", "Open" => false },
        None,
    );
    marks.add(
        pdf,
        "Text",
        note_area,
        YELLOW,
        "Tamamlandı",
        dictionary! {
            "IRT" => note,
            "State" => text("Completed"),
            "StateModel" => text("Review"),
            "Name" => "Comment",
            "Open" => false,
            "F" => 30,
        },
        None,
    );

    // Text boxes, with and without an appearance.
    let mut ap = Ap::new(
        "1 1 1 rg 0.851 0.227 0.169 RG 1 w 0.5 0.5 219 39 re B\nBT /Helv 10 Tf 0 g 6 16 Td (Depozito uygun.) Tj ET"
            .to_owned(),
    );
    ap.resources = helvetica();
    marks.add(
        pdf,
        "FreeText",
        [LEFT, 460.0, LEFT + 220.0, 500.0],
        RED,
        "Depozito uygun.",
        dictionary! {
            "DA" => Object::string_literal("0 g /Helv 10 Tf"),
            "DS" => text("font: 10pt Helvetica; color:#000000"),
            "RC" => rich("Depozito", "uygun."),
        },
        Some(ap),
    );
    marks.add(
        pdf,
        "FreeText",
        [320.0, 430.0, 520.0, 500.0],
        RED,
        "Bu madde kira artışıyla birlikte değerlendirilmeli.",
        dictionary! {
            "IT" => "FreeTextCallout",
            "CL" => numbers(&[300.0, 560.0, 300.0, 480.0, 320.0, 480.0]),
            "LE" => "OpenArrow",
            "RD" => numbers(&[0.0, 0.0, 0.0, 30.0]),
            "DA" => Object::string_literal("0 g /Helv 10 Tf"),
            "RC" => rich("Bu madde kira artışıyla", "birlikte değerlendirilmeli."),
        },
        None,
    );

    // Freehand: one with an appearance, one without.
    let area = [80.0, 380.0, 240.0, 420.0];
    marks.add(
        pdf,
        "Ink",
        area,
        BLUE,
        "",
        dictionary! {
            "InkList" => vec![numbers(&[85.0, 400.0, 120.0, 415.0, 200.0, 418.0, 235.0, 395.0, 120.0, 385.0])],
            "BS" => dictionary! { "W" => real(2.2) },
        },
        Some(Ap::new(
            "0.165 0.302 0.686 RG 2.2 w 1 J 1 j 5 20 m 40 35 l 120 38 l 155 15 l 40 5 l S"
                .to_owned(),
        )),
    );
    marks.add(
        pdf,
        "Ink",
        [260.0, 380.0, 400.0, 420.0],
        RED,
        "",
        dictionary! {
            "InkList" => vec![
                numbers(&[265.0, 385.0, 300.0, 415.0, 330.0, 390.0]),
                numbers(&[340.0, 390.0, 395.0, 415.0]),
            ],
            "BS" => dictionary! { "W" => 2 },
        },
        None,
    );

    // Shapes.
    marks.add(
        pdf,
        "Square",
        [LEFT, 300.0, LEFT + 150.0, 360.0],
        RED,
        "",
        dictionary! { "BS" => dictionary! { "W" => 2 }, "CA" => real(1.0) },
        Some(Ap::new(
            "0.851 0.227 0.169 RG 2 w 1 1 148 58 re S".to_owned(),
        )),
    );
    marks.add(
        pdf,
        "Circle",
        [240.0, 300.0, 340.0, 360.0],
        BLUE,
        "",
        dictionary! {
            "BS" => dictionary! { "W" => real(1.5) },
            "IC" => numbers(&[1.0, 0.95, 0.8]),
            "CA" => real(0.8),
        },
        None,
    );
    marks.add(
        pdf,
        "Line",
        [360.0, 300.0, 520.0, 360.0],
        RED,
        "",
        dictionary! {
            "L" => numbers(&[365.0, 305.0, 515.0, 355.0]),
            "LE" => vec![pdf::name("None"), pdf::name("OpenArrow")],
            "BS" => dictionary! { "W" => 2 },
        },
        Some(Ap::new(
            "0.851 0.227 0.169 RG 2 w 5 5 m 155 55 l S 143 56 m 155 55 l 148 45 l S".to_owned(),
        )),
    );
    marks.add(
        pdf,
        "Line",
        [LEFT, 270.0, 300.0, 290.0],
        BLUE,
        "",
        dictionary! {
            "L" => numbers(&[LEFT + 3.0, 280.0, 297.0, 280.0]),
            "BS" => dictionary! { "W" => 1 },
        },
        None,
    );
    marks.add(
        pdf,
        "Polygon",
        [320.0, 210.0, 470.0, 290.0],
        BLUE,
        "Bu alan ortak kullanıma açık.",
        dictionary! {
            "Vertices" => numbers(&[325.0, 215.0, 465.0, 225.0, 440.0, 285.0, 350.0, 275.0]),
            "BS" => dictionary! { "W" => 2 },
        },
        Some(Ap::new(
            "0.165 0.302 0.686 RG 2 w 5 5 m 145 15 l 120 75 l 30 65 l h S".to_owned(),
        )),
    );

    // A stamp, its turn of −6° recorded in `/Rotate`, as a4-1 draws it.
    let mut ap = Ap::new(
        "0.851 0.227 0.169 RG 2 w 2 2 166 46 re S\nBT /Helv 14 Tf 0.851 0.227 0.169 rg 14 18 Td (ONAYLANDI) Tj ET"
            .to_owned(),
    );
    ap.resources = helvetica();
    marks.add(
        pdf,
        "Stamp",
        [LEFT, 200.0, LEFT + 170.0, 250.0],
        RED,
        "Onaylandı",
        dictionary! { "Name" => "Approved", "Rotate" => 354 },
        Some(ap),
    );

    // Types no reader of ours knows: one direct in the array, one with a private key.
    let caret = marks.dict(
        "Caret",
        [LEFT + 300.0, line(6) - 4.0, LEFT + 310.0, line(6) + 8.0],
        BLUE,
        "Buraya \"Kadıköy\" eklensin.",
        dictionary! { "Sy" => "P", "RD" => numbers(&[0.0, 0.0, 0.0, 0.0]) },
    );
    marks.annots.push(caret.into());
    marks.add(
        pdf,
        "ACME_Mark",
        [LEFT, 120.0, LEFT + 80.0, 160.0],
        RED,
        "",
        dictionary! {
            "ACME_Data" => dictionary! {
                "Level" => 3,
                "Tag" => Object::string_literal("internal review"),
            },
        },
        Some(Ap::new("0.5 g 0 0 80 40 re f".to_owned())),
    );
    marks.annots
}

/// The turned page's marks.
fn second_page(pdf: &mut Pdf, page: ObjectId) -> Vec<Object> {
    let mut marks = Marks::new(page);
    let line = TURNED_TOP - 22.0;
    let area = [LEFT, line - 3.0, LEFT + 280.0, line + 10.0];
    let mut ap = Ap::new("/R0 gs 1 0.82 0.2 rg 0 0 280 13 re f".to_owned());
    ap.resources = multiply();
    marks.add(
        pdf,
        "Highlight",
        area,
        YELLOW,
        "",
        dictionary! { "QuadPoints" => quad(line, 280.0) },
        Some(ap),
    );
    // A text box written for reading on the turned page: a quarter turn of its appearance.
    let mut ap = Ap::new("BT /Helv 10 Tf 0 g 6 10 Td (Teslim edildi.) Tj ET".to_owned());
    ap.resources = helvetica();
    ap.matrix = Some([0.0, 1.0, -1.0, 0.0, 30.0, 0.0]);
    marks.add(
        pdf,
        "FreeText",
        [400.0, 400.0, 430.0, 520.0],
        RED,
        "Teslim edildi.",
        dictionary! {
            "DA" => Object::string_literal("0 g /Helv 10 Tf"),
            "Rotate" => 90,
            "RC" => rich("Teslim", "edildi."),
        },
        Some(ap),
    );
    marks.add(
        pdf,
        "Text",
        [500.0, 500.0, 520.0, 520.0],
        YELLOW,
        "Kumanda eksik mi?",
        dictionary! { "Name" => "Help", "Open" => false, "F" => 28 },
        None,
    );
    marks.add(
        pdf,
        "Square",
        [LEFT, 300.0, LEFT + 120.0, 380.0],
        BLUE,
        "",
        dictionary! { "BS" => dictionary! { "W" => 2 } },
        None,
    );
    marks.annots
}

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = doc.word_style(sources, FontFile::PlexSerif, 11.0)?;
    let title = doc.word_style(sources, FontFile::PlexSerifSemiBold, 14.0)?;
    let mut pages = Vec::new();
    for (lines, shift) in [
        (&FIRST_PAGE[..], 0.0),
        (&SECOND_PAGE[..], baseline(0) - TURNED_TOP),
    ] {
        let mut page = PageText::default();
        for (index, line) in (0u8..).zip(lines) {
            let style = if index == 0 { &title } else { &style };
            doc.line(
                &mut page,
                style,
                line,
                (LEFT, baseline(index) - shift),
                WIDTH,
                Align::Left,
            )?;
        }
        pages.push(page);
    }
    pages[1].extra.set("Rotate", 90);
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let first = first_page(&mut doc.pdf, ids[0]);
    let second = second_page(&mut doc.pdf, ids[1]);
    super::kira::set_page_entry(&mut doc.pdf, ids[0], "Annots", Object::Array(first));
    super::kira::set_page_entry(&mut doc.pdf, ids[1], "Annots", Object::Array(second));
    let catalog = dictionary! { "Lang" => text("tr-TR"), "OpenAction" => open_first(ids[0]) };
    let mut info = info(
        "Kira sözleşmesi incelemesi",
        AUTHOR,
        "Other PDF Studio 7.2",
        "D:20261013093000+03'00'",
    );
    "Other PDF Studio 7.2 (annotation engine)".clone_into(&mut info.producer);
    let bytes = doc.close(catalog, &info, "annots-other-producer", None)?;
    Ok(generated(bytes, expected.text))
}
