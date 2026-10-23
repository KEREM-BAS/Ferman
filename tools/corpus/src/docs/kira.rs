//! `kira-tr` and its variants: the Turkish residential rental contract of the design's
//! `DocKira` (3 A4 pages, Madde 1 to 10 and a signature page), with invented parties.
//!
//! - **kira-tr:** set as Word sets it: each face as a simple TrueType font with WinAnsiEncoding
//!   and, for ş, ı, ğ, İ, Ş and Ğ, the same face as a composite font; justified with `Tw`.
//!   Madde 6 is in EB Garamond, whose subsets lack "ğ": the one "ğ" of its text ("Olağan") comes
//!   from IBM Plex Serif, as a producer substitutes a missing glyph (ROADMAP E02). The IBAN line
//!   sits in a frame right below Madde 4 (E06). Page 3 has six form fields, two of them unsigned
//!   signature fields; the file has three attachments (xlsx, jpg, pdf).
//! - **kira-tr-damaged:** the older copy of `a1-9`: no attachments or fields, page 3 in a
//!   TimesNewRomanPSMT that is not embedded (Windows-1254 `/Differences`), and every offset of
//!   its cross-reference table two bytes early.
//! - **kira-tr-restricted:** kira-tr with an owner password only (AES-128): it opens without a
//!   password, but changes, copying, comments and form filling are not allowed (`a2-10a`).

use super::files::{Cell, jpeg, xlsx};
use super::{Doc, generated, info, open_first, opens};
use crate::crypt::{Method, PRINT_ONLY, Security};
use crate::pdf::{self, Content, Pdf, name, num, rect, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Flow, Frame, PageText, Paragraph, Style};
use crate::{Expect, Generated, Generator};
use lopdf::{Dictionary, Object, ObjectId, Stream, dictionary};

/// The contract.
pub const KIRA_TR: Generator = Generator {
    name: "kira-tr",
    build: |sources| build(sources, Variant::Full),
    expect: opens(),
};

/// The older, damaged copy.
pub const KIRA_TR_DAMAGED: Generator = Generator {
    name: "kira-tr-damaged",
    build: |sources| build(sources, Variant::Damaged),
    expect: opens(),
};

/// The contract with an owner password.
pub const KIRA_TR_RESTRICTED: Generator = Generator {
    name: "kira-tr-restricted",
    build: |sources| build(sources, Variant::Restricted),
    expect: Expect::Opens { password: None },
};

/// The owner password of kira-tr-restricted.
pub const OWNER_PASSWORD: &str = "Kaya-Moda-18";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Variant {
    Full,
    Damaged,
    Restricted,
}

const CREATED: &str = "D:20261013093000+03'00'";
const MARGIN_X: f64 = 72.0;
const TOP: f64 = pdf::A4.1 - 66.0;
const BOTTOM: f64 = 72.0;
const WIDTH: f64 = pdf::A4.0 - 2.0 * MARGIN_X;
const INK: (u8, u8, u8) = (0x1F, 0x1D, 0x1A);
const SECONDARY: (u8, u8, u8) = (0x57, 0x53, 0x4C);
const TERTIARY: (u8, u8, u8) = (0x8A, 0x85, 0x7C);
const RULE: (u8, u8, u8) = (0xC9, 0xC4, 0xBA);

/// Page 1 after the title: (heading, paragraphs).
const PAGE_1: [(&str, &[&str]); 5] = [
    (
        "Madde 1 — Taraflar",
        &[
            "Kiraya veren: Mert Kaya (T.C. Kimlik No: 35712648950), Moda Cad. No: 18, Kadıköy, İstanbul. Kiracı: Ayşe Yılmaz (T.C. Kimlik No: 41239876516), Bağdat Cad. No: 241/7, Maltepe, İstanbul.",
        ],
    ),
    (
        "Madde 2 — Kiralanan Taşınmaz",
        &[
            "Kiralanan taşınmaz, İstanbul ili, Kadıköy ilçesi, Caferağa Mahallesi, Moda Caddesi No: 18 Daire: 5 adresindeki 3+1 konuttur. Taşınmaz eşyasız olarak teslim edilmiştir.",
        ],
    ),
    (
        "Madde 3 — Kira Süresi",
        &[
            "Kira süresi 01.11.2026 tarihinde başlar ve bir (1) yıldır. Taraflardan biri süre bitiminden en az otuz gün önce yazılı bildirimde bulunmadıkça sözleşme aynı koşullarla bir yıl uzar.",
        ],
    ),
    ("Madde 4 — Kira Bedeli ve Ödeme", &[]),
    (
        "Madde 5 — Depozito",
        &[
            "Kiracı, sözleşmenin imzalanması sırasında iki aylık kira bedeli tutarında, 37.000 TL depozito öder. Depozito, taşınmazın hasarsız teslimi hâlinde 15 gün içinde iade edilir.",
        ],
    ),
];

const MADDE_4: &str = "Kiracı, aylık kira bedeli olan 18.500 TL’yi her ayın beşinci gününe kadar kiraya verenin aşağıdaki hesabına ödemekle yükümlüdür.";
const IBAN_LINE: &str = "IBAN: TR12 0006 4000 0011 2345 6789 01 · Alıcı: Mert Kaya";
const MADDE_4_AFTER: &str = "Kira bedeli her kira yılının başında, bir önceki yılın on iki aylık TÜFE ortalaması oranında artırılır.";
const MADDE_6_HEADING: &str = "Madde 6 — Kullanım ve Bakım";
const MADDE_6: &str = "Kiracı, kiralananı özenle kullanmak ve komşulara saygı göstermekle yükümlüdür. Olağan bakım ve küçük onarımlar kiracıya aittir.";

const PAGE_2: [(&str, &str); 4] = [
    (
        "Madde 7 — Tahliye",
        "Kiracı, kira süresinin bitiminde taşınmazı boş ve hasarsız olarak teslim eder. Teslim sırasında taraflarca bir teslim tutanağı düzenlenir ve sayaç değerleri bu tutanağa yazılır.",
    ),
    (
        "Madde 8 — Özel Şartlar",
        "Kiralanan taşınmazda evcil hayvan beslenebilir. Taşınmazın bir kısmı veya tamamı, kiraya verenin yazılı izni olmadan başkasına kiralanamaz ve kullandırılamaz.",
    ),
    (
        "Madde 9 — Bildirimler",
        "Taraflar, bu sözleşmeden doğan bildirimleri aşağıdaki adreslere yapar. Kiraya veren: mert.kaya@ornekposta.com.tr · 0532 418 27 63. Kiracı: ayse.yilmaz@ornekposta.com.tr · 0544 902 15 38.",
    ),
    (
        "Madde 10 — Uyuşmazlıklar",
        "Bu sözleşmeden doğan uyuşmazlıklarda İstanbul Anadolu Mahkemeleri ve İcra Daireleri yetkilidir. Sözleşme iki nüsha olarak düzenlenmiş ve taraflarca okunarak imzalanmıştır.",
    ),
];

/// The styles of the contract.
#[derive(Clone)]
struct Styles {
    title: Style,
    meta: Style,
    heading: Style,
    body: Style,
    madde_6: Style,
    folio: Style,
    label: Style,
    field_label: Style,
}

fn styles(doc: &mut Doc, sources: &Sources, variant: Variant) -> Result<Styles, String> {
    let body = doc
        .word_style(sources, FontFile::PlexSerif, 10.5)?
        .colored(INK);
    let heading = doc
        .word_style(sources, FontFile::PlexSerifSemiBold, 11.0)?
        .colored(INK);
    let mut title = heading.sized(15.75);
    title.char_spacing = 0.945;
    let madde_6 = if variant == Variant::Damaged {
        body.clone()
    } else {
        let mut style = doc
            .word_style(sources, FontFile::EbGaramond, 11.25)?
            .colored(INK);
        // EB Garamond's subsets never get "ğ" or "Ğ": they come from Plex Serif.
        style.borrowed = body.fallback.map(|key| (key, "ğĞ"));
        style
    };
    let label = {
        let mut style = doc
            .word_style(sources, FontFile::PlexSansSemiBold, 8.25)?
            .colored(SECONDARY);
        style.char_spacing = 0.66;
        style
    };
    let field_label = doc
        .word_style(sources, FontFile::PlexSans, 9.0)?
        .colored(SECONDARY);
    Ok(Styles {
        title,
        meta: body.sized(9.0).colored(SECONDARY),
        heading,
        body: body.clone(),
        madde_6,
        folio: body.sized(9.0).colored(TERTIARY),
        label,
        field_label,
    })
}

fn heading(style: &Style, text: &str, first: bool) -> Paragraph {
    Paragraph::new(style, text)
        .aligned(Align::Left)
        .spaced(if first { 0.0 } else { 16.5 }, 4.5)
        .kept()
}

fn body(style: &Style, text: &str) -> Paragraph {
    Paragraph::new(style, text).spaced(0.0, 6.0)
}

fn frame() -> Frame {
    Frame {
        x: MARGIN_X,
        top: TOP,
        bottom: BOTTOM,
        width: WIDTH,
    }
}

/// A text field or signature box on page 3, drawn on the page and listed for the form.
struct Field {
    name: &'static str,
    label: &'static str,
    value: Option<&'static str>,
    signature: bool,
    required: bool,
    rect: [f64; 4],
}

/// A field box: name, label, value, whether a signature, whether required, width, height.
type BoxSpec = (
    &'static str,
    &'static str,
    Option<&'static str>,
    bool,
    bool,
    f64,
    f64,
);

/// Pages 1 and 2: the clauses.
fn clauses(doc: &mut Doc, styles: &Styles) -> Result<Vec<PageText>, String> {
    let mut flow = Flow::new(frame());
    let title = Paragraph::new(&styles.title, "KONUT KİRA SÖZLEŞMESİ")
        .aligned(Align::Center)
        .spaced(0.0, 4.5);
    flow.paragraph(&mut doc.fonts, &title)?;
    let meta = Paragraph::new(
        &styles.meta,
        "Sözleşme No: 2026/0412 · Düzenleme tarihi: 13.10.2026",
    )
    .aligned(Align::Center)
    .spaced(0.0, 21.0);
    flow.paragraph(&mut doc.fonts, &meta)?;
    for (index, (title, paragraphs)) in PAGE_1.iter().enumerate() {
        flow.paragraph(&mut doc.fonts, &heading(&styles.heading, title, index == 0))?;
        for paragraph in *paragraphs {
            flow.paragraph(&mut doc.fonts, &body(&styles.body, paragraph))?;
        }
        if title.starts_with("Madde 4") {
            flow.paragraph(
                &mut doc.fonts,
                &body(&styles.body, MADDE_4).spaced(0.0, 2.0),
            )?;
            // The IBAN line in a frame right below the paragraph: extending it collides.
            let top = flow.y();
            let height = 10.5 * 1.5 + 4.0;
            let page = flow.page();
            page.content
                .stroke_rgb(RULE)
                .line_width(0.75)
                .stroke_rect(MARGIN_X - 4.0, top - height, WIDTH + 8.0, height)
                .stroke_rgb((0, 0, 0));
            flow.skip(2.0);
            flow.paragraph(
                &mut doc.fonts,
                &Paragraph::new(&styles.body, IBAN_LINE).aligned(Align::Left),
            )?;
            flow.skip(8.0);
            flow.paragraph(&mut doc.fonts, &body(&styles.body, MADDE_4_AFTER))?;
        }
    }
    flow.paragraph(
        &mut doc.fonts,
        &heading(&styles.heading, MADDE_6_HEADING, false),
    )?;
    flow.paragraph(&mut doc.fonts, &body(&styles.madde_6, MADDE_6))?;
    if flow.pages.len() != 1 {
        return Err("page 1 overflows".to_owned());
    }
    flow.break_page();
    for (index, (title, paragraph)) in PAGE_2.iter().enumerate() {
        flow.paragraph(&mut doc.fonts, &heading(&styles.heading, title, index == 0))?;
        flow.paragraph(&mut doc.fonts, &body(&styles.body, paragraph))?;
    }
    if flow.pages.len() != 2 {
        return Err("page 2 overflows".to_owned());
    }
    Ok(flow.into_pages())
}

/// Page 3: the signatures, with the boxes of the form fields drawn.
fn signatures(doc: &mut Doc, page3: &Styles) -> Result<(PageText, Vec<Field>), String> {
    let mut flow = Flow::new(frame());
    flow.paragraph(&mut doc.fonts, &heading(&page3.heading, "İmzalar", true))?;
    flow.paragraph(
        &mut doc.fonts,
        &body(
            &page3.body,
            "Taraflar, bu sözleşmenin tüm maddelerini okuduklarını ve kabul ettiklerini beyan eder.",
        ),
    )?;
    let mut page = flow.into_pages().pop().unwrap_or_default();
    let column = (WIDTH - 36.0) / 2.0;
    let mut fields = Vec::new();
    let top = TOP - 16.5 * 1.5 - 4.5 - 10.5 * 1.5 - 6.0 - 30.0;
    let parties: [(&str, [BoxSpec; 3]); 2] = [
        (
            "KİRAYA VEREN",
            [
                (
                    "kiraya_veren_ad_soyad",
                    "Ad Soyad",
                    Some("Mert Kaya"),
                    false,
                    false,
                    180.0,
                    22.0,
                ),
                (
                    "kiraya_veren_tarih",
                    "Tarih",
                    Some("13.10.2026"),
                    false,
                    false,
                    105.0,
                    22.0,
                ),
                ("kiraya_veren_imza", "İmza", None, true, false, 180.0, 46.0),
            ],
        ),
        (
            "KİRACI",
            [
                (
                    "kiraci_ad_soyad",
                    "Ad Soyad",
                    None,
                    false,
                    true,
                    180.0,
                    22.0,
                ),
                ("kiraci_tarih", "Tarih", None, false, true, 105.0, 22.0),
                ("kiraci_imza", "İmza", None, true, true, 180.0, 46.0),
            ],
        ),
    ];
    let mut lowest = top;
    for (index, (party, boxes)) in parties.iter().enumerate() {
        #[allow(clippy::cast_precision_loss)]
        let x = MARGIN_X + (column + 36.0) * index as f64;
        doc.line(
            &mut page,
            &page3.label,
            party,
            (x, top - 8.25),
            column,
            Align::Left,
        )?;
        let mut y = top - 8.25 - 14.0;
        for (field_name, label, value, signature, required, width, height) in boxes {
            let label_text = if *required {
                format!("{label} *")
            } else {
                (*label).to_owned()
            };
            doc.line(
                &mut page,
                &page3.field_label,
                &label_text,
                (x, y - 9.0),
                column,
                Align::Left,
            )?;
            let box_top = y - 13.0;
            page.content
                .stroke_rgb(RULE)
                .line_width(0.75)
                .stroke_rect(x, box_top - height, *width, *height)
                .stroke_rgb((0, 0, 0));
            fields.push(Field {
                name: field_name,
                label,
                value: *value,
                signature: *signature,
                required: *required,
                rect: [x, box_top - height, x + width, box_top],
            });
            y = box_top - height - 9.0;
        }
        lowest = lowest.min(y);
    }
    let attachments_y = lowest - 42.0;
    doc.line(
        &mut page,
        &page3.meta,
        "Ek-1: Demirbaş listesi (1 sayfa) · Ek-2: Tapu fotokopisi",
        (MARGIN_X, attachments_y),
        WIDTH,
        Align::Left,
    )?;
    Ok((page, fields))
}

/// The page numbers, "n / 3", centred near the foot.
fn folios(doc: &mut Doc, pages: &mut [PageText], style: &Style) -> Result<(), String> {
    let total = pages.len();
    for (index, page) in pages.iter_mut().enumerate() {
        doc.line(
            page,
            style,
            &format!("{} / {total}", index + 1),
            (MARGIN_X, 36.0),
            WIDTH,
            Align::Center,
        )?;
    }
    Ok(())
}

/// Helvetica for the form's default appearance, as form tools add it.
fn helvetica(pdf: &mut Pdf) -> ObjectId {
    pdf.add(dictionary! {
        "Type" => "Font",
        "Subtype" => "Type1",
        "BaseFont" => "Helvetica",
        "Encoding" => "WinAnsiEncoding",
    })
}

/// The form fields of page 3, each a field merged with its widget.
fn form(
    pdf: &mut Pdf,
    page: ObjectId,
    fields: &[Field],
) -> Result<(Vec<Object>, Dictionary), String> {
    let helv = helvetica(pdf);
    let mut annots = Vec::new();
    for field in fields {
        let [x1, y1, x2, y2] = field.rect;
        let (width, height) = (x2 - x1, y2 - y1);
        let mut content = Content::new();
        content.op("/Tx BMC");
        if let Some(value) = field.value {
            let encoded: Vec<u8> = value.bytes().collect();
            content.op("q BT /Helv 10 Tf 0 g");
            content.op(&format!(
                "2 {} Td {} Tj",
                num((height - 10.0) / 2.0 + 2.0),
                pdf::literal(&encoded)
            ));
            content.op("ET Q");
        }
        content.op("EMC");
        let appearance = pdf.stream(
            dictionary! {
                "Type" => "XObject",
                "Subtype" => "Form",
                "BBox" => rect(0.0, 0.0, width, height),
                "Resources" => dictionary! { "Font" => dictionary! { "Helv" => helv } },
            },
            content.into_bytes(),
        );
        let mut flags = 0;
        if field.value.is_some() {
            flags |= 1;
        }
        if field.required {
            flags |= 2;
        }
        let mut widget = dictionary! {
            "Type" => "Annot",
            "Subtype" => "Widget",
            "FT" => if field.signature { "Sig" } else { "Tx" },
            "T" => text(field.name),
            "TU" => text(field.label),
            "Rect" => rect(x1, y1, x2, y2),
            "F" => 4,
            "P" => page,
            "Ff" => flags,
            "AP" => dictionary! { "N" => appearance },
        };
        if !field.signature {
            widget.set("DA", Object::string_literal("/Helv 10 Tf 0 g"));
        }
        if let Some(value) = field.value {
            widget.set("V", text(value));
        }
        annots.push(Object::Reference(pdf.add(widget)));
    }
    let acro = dictionary! {
        "Fields" => annots.clone(),
        "DR" => dictionary! { "Font" => dictionary! { "Helv" => helv } },
        "DA" => Object::string_literal("/Helv 0 Tf 0 g"),
    };
    Ok((annots, acro))
}

/// The three attachments, as an `/EmbeddedFiles` name tree.
fn attachments(doc: &mut Doc, sources: &Sources) -> Result<Dictionary, String> {
    let rows = [
        vec![
            Cell::Text("Sıra"),
            Cell::Text("Demirbaş"),
            Cell::Text("Adet"),
            Cell::Text("Durum"),
        ],
        vec![
            Cell::Number(1.0),
            Cell::Text("Kombi (Demirdöküm)"),
            Cell::Number(1.0),
            Cell::Text("Çalışıyor"),
        ],
        vec![
            Cell::Number(2.0),
            Cell::Text("Ankastre fırın"),
            Cell::Number(1.0),
            Cell::Text("Çalışıyor"),
        ],
        vec![
            Cell::Number(3.0),
            Cell::Text("Mutfak dolabı"),
            Cell::Number(6.0),
            Cell::Text("Hasarsız"),
        ],
        vec![
            Cell::Number(4.0),
            Cell::Text("Banyo aynası"),
            Cell::Number(1.0),
            Cell::Text("Küçük çizik"),
        ],
        vec![
            Cell::Number(5.0),
            Cell::Text("Perde rayı"),
            Cell::Number(4.0),
            Cell::Text("Hasarsız"),
        ],
    ];
    let sheet = xlsx("Demirbaş listesi", &rows)?;
    // A photocopy of the title deed: a pale page with a frame, a seal and lines of text.
    let deed = jpeg(480, 640, 96, |x, y| {
        let frame = (24..30).contains(&x)
            || (450..456).contains(&x)
            || (24..30).contains(&y)
            || (610..616).contains(&y);
        let seal = (x as i64 - 380).pow(2) + (y as i64 - 520).pow(2) < 48 * 48;
        let line = (80..600).contains(&y)
            && (y - 80) % 32 < 10
            && (60..420).contains(&x)
            && (x / 8 + y / 16) % 7 != 0;
        if frame || line {
            70
        } else if seal {
            150
        } else {
            228
        }
    })?;
    let id_copy = id_copy_pdf(sources)?;
    let files: [(&str, &str, &str, Vec<u8>); 3] = [
        (
            "Ek-1 Demirbaş listesi.xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "Ek-1: Demirbaş listesi",
            sheet,
        ),
        (
            "Ek-2 Tapu fotokopisi.jpg",
            "image/jpeg",
            "Ek-2: Tapu fotokopisi",
            deed,
        ),
        (
            "Kimlik fotokopisi.pdf",
            "application/pdf",
            "Kiracının kimlik fotokopisi",
            id_copy,
        ),
    ];
    let mut names = Vec::new();
    for (file_name, mime, description, bytes) in files {
        let size = i64::try_from(bytes.len()).map_err(|err| err.to_string())?;
        let checksum = md5_of(&bytes);
        let stream = Stream::new(
            dictionary! {
                "Type" => "EmbeddedFile",
                "Subtype" => name(mime),
                "Params" => dictionary! {
                    "Size" => size,
                    "CreationDate" => text("D:20261012184500+03'00'"),
                    "ModDate" => text("D:20261012184500+03'00'"),
                    "CheckSum" => pdf::hex(&checksum),
                },
            },
            bytes,
        );
        let stream = doc.pdf.add(pdf::compressed(stream));
        let ascii: String = file_name
            .chars()
            .map(|c| if c.is_ascii() { c } else { '_' })
            .collect();
        let spec = doc.pdf.add(dictionary! {
            "Type" => "Filespec",
            "F" => Object::string_literal(ascii),
            "UF" => text(file_name),
            "Desc" => text(description),
            "EF" => dictionary! { "F" => stream, "UF" => stream },
        });
        names.push((text(file_name), spec));
    }
    names.sort_by(|a, b| {
        let key = |object: &Object| object.as_str().map(<[u8]>::to_vec).unwrap_or_default();
        key(&a.0).cmp(&key(&b.0))
    });
    let mut array = Vec::new();
    for (key, spec) in names {
        array.push(key);
        array.push(Object::Reference(spec));
    }
    let tree = doc.pdf.add(dictionary! { "Names" => array });
    Ok(dictionary! { "EmbeddedFiles" => tree })
}

fn md5_of(bytes: &[u8]) -> [u8; 16] {
    use md5::Digest as _;
    md5::Md5::digest(bytes).into()
}

/// A one-page PDF with a greyscale "photocopy" of an identity card.
fn id_copy_pdf(sources: &Sources) -> Result<Vec<u8>, String> {
    let mut doc = Doc::new("1.6");
    let style = doc.word_style(sources, FontFile::PlexSans, 9.0)?;
    let card = jpeg(344, 216, 150, |x, y| {
        let border = !(4..340).contains(&x) || !(4..212).contains(&y);
        let photo = (20..100).contains(&x) && (40..176).contains(&y);
        let line = (120..320).contains(&x) && (48..176).contains(&y) && (y - 48) % 24 < 8;
        if border || line {
            60
        } else if photo {
            120
        } else {
            214
        }
    })?;
    let image = doc.pdf.add(Stream::new(
        dictionary! {
            "Type" => "XObject",
            "Subtype" => "Image",
            "Width" => 344,
            "Height" => 216,
            "ColorSpace" => "DeviceGray",
            "BitsPerComponent" => 8,
            "Filter" => "DCTDecode",
        },
        card,
    ));
    let mut page = PageText::default();
    page.content.op("q 275.2 0 0 172.8 160 520 cm /Im1 Do Q");
    doc.line(
        &mut page,
        &style,
        "KİMLİK KARTI FOTOKOPİSİ · Aslı gibidir.",
        (160.0, 500.0),
        275.2,
        Align::Left,
    )?;
    page.resources
        .set("XObject", dictionary! { "Im1" => image });
    let (pages, _) = doc.add_pages(vec![page], pdf::A4);
    let catalog = dictionary! { "OpenAction" => open_first(pages[0]) };
    doc.close(
        catalog,
        &info(
            "Kimlik fotokopisi",
            "Ayşe Yılmaz",
            "Tarayıcı",
            "D:20261012183000+03'00'",
        ),
        "kira-tr Kimlik fotokopisi",
        None,
    )
}

fn build(sources: &Sources, variant: Variant) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let styles = styles(&mut doc, sources, variant)?;
    let mut pages = clauses(&mut doc, &styles)?;
    let (page3, fields) = if variant == Variant::Damaged {
        // Page 3 of the old copy names TimesNewRomanPSMT and does not embed it.
        let times = doc.standard_style(
            sources,
            FontFile::PlexSerif,
            "TimesNewRomanPSMT",
            "TrueType",
            true,
            10.5,
        )?;
        let times = times.colored(INK);
        let page3 = Styles {
            title: times.clone(),
            meta: times.sized(9.0).colored(SECONDARY),
            heading: {
                let bold = doc.standard_style(
                    sources,
                    FontFile::PlexSerifSemiBold,
                    "TimesNewRomanPS-BoldMT",
                    "TrueType",
                    true,
                    11.0,
                )?;
                bold.colored(INK)
            },
            body: times.clone(),
            madde_6: times.clone(),
            folio: times.sized(9.0).colored(TERTIARY),
            label: times.sized(8.25).colored(SECONDARY),
            field_label: times.sized(9.0).colored(SECONDARY),
        };
        let (page, _) = signatures(&mut doc, &page3)?;
        (page, Vec::new())
    } else {
        signatures(&mut doc, &styles)?
    };
    pages.push(page3);
    folios(&mut doc, &mut pages, &styles.folio)?;
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let mut catalog = dictionary! {
        "Lang" => text("tr-TR"),
        "OpenAction" => open_first(ids[0]),
    };
    if variant != Variant::Damaged {
        let (annots, acro) = form(&mut doc.pdf, ids[2], &fields)?;
        set_page_entry(&mut doc.pdf, ids[2], "Annots", Object::Array(annots));
        catalog.set("AcroForm", acro);
        catalog.set("Names", attachments(&mut doc, sources)?);
    }
    let name = match variant {
        Variant::Full => "kira-tr",
        Variant::Damaged => "kira-tr-damaged",
        Variant::Restricted => "kira-tr-restricted",
    };
    let title = if variant == Variant::Damaged {
        "Kira sözleşmesi (eski)"
    } else {
        "Kira sözleşmesi"
    };
    let security = Security {
        method: Method::Aes128,
        user: String::new(),
        owner: OWNER_PASSWORD.to_owned(),
        permissions: PRINT_ONLY,
        seed: name.to_owned(),
    };
    let bytes = doc.close(
        catalog,
        &info(title, "Mert Kaya", "Kelime işlemci", CREATED),
        name,
        (variant == Variant::Restricted).then_some(&security),
    )?;
    let bytes = if variant == Variant::Damaged {
        shift_xref(&bytes, 2)?
    } else {
        bytes
    };
    Ok(generated(bytes, expected))
}

/// Sets one entry of a page dictionary.
pub fn set_page_entry(pdf: &mut Pdf, page: ObjectId, key: &str, value: Object) {
    if let Some(Object::Dictionary(dict)) = pdf.doc.objects.get_mut(&page) {
        dict.set(key, value);
    }
}

/// `file` with every in-use offset of its last cross-reference table moved `early` bytes
/// earlier, so no entry points at its object.
///
/// # Errors
///
/// A message when the file has no classic cross-reference table.
pub fn shift_xref(file: &[u8], early: u64) -> Result<Vec<u8>, String> {
    let marker = b"\nxref\n";
    let start = file
        .windows(marker.len())
        .rposition(|window| window == marker)
        .ok_or("no cross-reference table")?
        + marker.len();
    let end = file[start..]
        .windows(7)
        .position(|window| window == b"trailer")
        .map(|at| start + at)
        .ok_or("no trailer")?;
    let table = std::str::from_utf8(&file[start..end]).map_err(|err| err.to_string())?;
    let mut rewritten = String::with_capacity(table.len());
    for line in table.split_inclusive('\n') {
        let fields: Vec<&str> = line.split_whitespace().collect();
        if let [offset, generation, "n"] = fields.as_slice()
            && offset.len() == 10
        {
            let value: u64 = offset.parse().map_err(|_| "bad offset")?;
            let ending = &line[line.trim_end().len()..];
            rewritten.push_str(&format!(
                "{:010} {generation} n{ending}",
                value.saturating_sub(early)
            ));
        } else {
            rewritten.push_str(line);
        }
    }
    let mut out = file[..start].to_vec();
    out.extend_from_slice(rewritten.as_bytes());
    out.extend_from_slice(&file[end..]);
    Ok(out)
}
