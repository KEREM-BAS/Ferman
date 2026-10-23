//! The forms:
//!
//! - **form-aks1-tr:** the e-Devlet address declaration of the design's `DocForm` (Form AKS-1,
//!   one A4 page): 20 fields, 15 of them required, in the design's order and names: ten text
//!   fields, three dates with `AFDate` format and keystroke actions (`GG.AA.YYYY`), a radio
//!   group, three combo boxes, two check boxes and a signature field. The household size has
//!   an `AFRange_Validate(1, 20)` action. Unfilled.
//! - **form-aks1-flat:** the same page with no fields: the boxes are only drawn ("Fill
//!   anything", `a5-4`).
//! - **xfa-visa:** a dynamic XFA-only form ("Vize başvuru formu.pdf", `a11-7c`): the XDP in
//!   `/AcroForm /XFA`, `/NeedsRendering`, and a page that only says the form needs an XFA
//!   viewer.

use super::{Doc, generated, info, open_first, opens};
use crate::pdf::{self, Content, Pdf, name, num, rect, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, PageText, Style};
use crate::{Generated, Generator};
use lopdf::{Dictionary, Object, ObjectId, dictionary};

/// The form with its fields.
pub const FORM_AKS1_TR: Generator = Generator {
    name: "form-aks1-tr",
    build: |sources| aks1(sources, true),
    expect: opens(),
};

/// The same page without fields.
pub const FORM_AKS1_FLAT: Generator = Generator {
    name: "form-aks1-flat",
    build: |sources| aks1(sources, false),
    expect: opens(),
};

/// The XFA-only form.
pub const XFA_VISA: Generator = Generator {
    name: "xfa-visa",
    build: xfa,
    expect: opens(),
};

const LEFT: f64 = 48.0;
const WIDTH: f64 = pdf::A4.0 - 96.0;
const SECONDARY: (u8, u8, u8) = (0x57, 0x53, 0x4C);
const TERTIARY: (u8, u8, u8) = (0x8A, 0x85, 0x7C);
const REQUIRED: (u8, u8, u8) = (0xB4, 0x3A, 0x2E);
const BOX: (u8, u8, u8) = (0x8A, 0x85, 0x7C);
const BAND: (u8, u8, u8) = (0xEF, 0xEC, 0xE6);

/// How a field is filled.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Kind {
    Text,
    Date,
    Number,
    Radio,
    Choice(&'static [&'static str]),
    Check,
    Signature,
}

/// One field of the design's table: kind, label, width in design pixels, required, name.
type Spec = (Kind, &'static str, f64, bool, &'static str);

const MARITAL: &[&str] = &["Bekâr", "Evli", "Boşanmış", "Dul"];
const PROVINCES: &[&str] = &["ADANA", "ANKARA", "BURSA", "İSTANBUL", "İZMİR", "KOCAELİ"];
const DISTRICTS: &[&str] = &["ATAŞEHİR", "BEŞİKTAŞ", "KADIKÖY", "MALTEPE", "ÜSKÜDAR"];

const SECTIONS: [(&str, &[&[Spec]]); 3] = [
    (
        "1. KİŞİSEL BİLGİLER",
        &[
            &[
                (Kind::Number, "T.C. Kimlik No", 200.0, true, "tc_kimlik_no"),
                (Kind::Date, "Doğum tarihi", 130.0, true, "dogum_tarihi"),
            ],
            &[
                (Kind::Text, "Adı", 250.0, true, "adi"),
                (Kind::Text, "Soyadı", 250.0, true, "soyadi"),
            ],
            &[
                (Kind::Radio, "Cinsiyeti", 0.0, true, "cinsiyet"),
                (
                    Kind::Choice(MARITAL),
                    "Medeni hâli",
                    170.0,
                    false,
                    "medeni_hal",
                ),
            ],
            &[
                (Kind::Text, "Telefon", 180.0, false, "telefon"),
                (Kind::Text, "E-posta", 290.0, false, "eposta"),
            ],
        ],
    ),
    (
        "2. YENİ ADRES BİLGİLERİ",
        &[
            &[
                (Kind::Choice(PROVINCES), "İl", 160.0, true, "il"),
                (Kind::Choice(DISTRICTS), "İlçe", 160.0, true, "ilce"),
                (Kind::Text, "Mahalle", 230.0, true, "mahalle"),
            ],
            &[
                (Kind::Text, "Cadde / Sokak", 330.0, true, "cadde_sokak"),
                (Kind::Text, "Dış kapı no", 90.0, true, "dis_kapi_no"),
                (Kind::Text, "İç kapı no", 90.0, false, "ic_kapi_no"),
            ],
            &[
                (Kind::Date, "Taşınma tarihi", 130.0, true, "tasinma_tarihi"),
                (
                    Kind::Number,
                    "Hanede yaşayan kişi sayısı",
                    120.0,
                    true,
                    "hane_kisi_sayisi",
                ),
            ],
        ],
    ),
    (
        "3. BEYAN VE İMZA",
        &[
            &[(
                Kind::Check,
                "Yukarıdaki bilgilerin doğru olduğunu beyan ederim.",
                0.0,
                true,
                "beyan_dogruluk",
            )],
            &[(
                Kind::Check,
                "Adres değişikliğimin bağlı olduğum kurumlara bildirilmesini kabul ediyorum.",
                0.0,
                false,
                "beyan_kurum",
            )],
            &[
                (Kind::Date, "Tarih", 130.0, true, "beyan_tarihi"),
                (Kind::Signature, "İmza", 240.0, true, "imza"),
            ],
        ],
    ),
];

/// A field drawn on the page, for the form.
struct Placed {
    kind: Kind,
    label: &'static str,
    required: bool,
    name: &'static str,
    rects: Vec<[f64; 4]>,
}

struct Styles {
    small_caps: Style,
    title: Style,
    body: Style,
    label: Style,
    required: Style,
    mono: Style,
    footer: Style,
}

fn draw_label(
    doc: &mut Doc,
    page: &mut PageText,
    styles: &Styles,
    label: &str,
    required: bool,
    x: f64,
    y: f64,
) -> Result<(), String> {
    // The label and its asterisk are one line of text in two colours.
    let mut spans = vec![crate::text::Span::new(&styles.label, label)];
    if required {
        spans.push(crate::text::Span::new(&styles.required, " *"));
    }
    let paragraph = crate::text::Paragraph {
        spans,
        ..crate::text::Paragraph::new(&styles.label, label)
            .aligned(Align::Left)
            .leading(1.0)
    };
    let lines = crate::text::lay_out(&mut doc.fonts, &paragraph.spans, f64::INFINITY)?;
    page.draw(
        &doc.fonts,
        &lines,
        &paragraph,
        x,
        400.0,
        y + 8.25 * 0.78,
        true,
    );
    Ok(())
}

fn aks1(sources: &Sources, fields: bool) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let sans = doc.word_style(sources, FontFile::PlexSans, 8.25)?;
    let mut small_caps = doc.word_style(sources, FontFile::PlexSansSemiBold, 8.25)?;
    small_caps.char_spacing = 0.66;
    let mut title = doc.word_style(sources, FontFile::PlexSerifSemiBold, 14.25)?;
    title.char_spacing = 0.285;
    let body = doc.word_style(sources, FontFile::PlexSerif, 9.0)?;
    let mono = doc.word_style(sources, FontFile::PlexMono, 9.75)?;
    let styles = Styles {
        small_caps,
        title,
        body: body.clone(),
        label: sans.colored(SECONDARY),
        required: sans.colored(REQUIRED),
        mono,
        footer: sans.sized(7.875).colored(TERTIARY),
    };
    let mut page = PageText::default();
    let top = pdf::A4.1 - 42.0;
    let mut tc = styles.small_caps.colored(SECONDARY);
    tc.char_spacing = 0.99;
    doc.line(
        &mut page,
        &tc,
        "T.C.",
        (LEFT, top - 8.0),
        WIDTH,
        Align::Left,
    )?;
    doc.line(
        &mut page,
        &styles.title,
        "YERLEŞİM YERİ ADRESİ BEYAN FORMU",
        (LEFT, top - 26.0),
        WIDTH,
        Align::Left,
    )?;
    doc.line(
        &mut page,
        &styles.body.colored(SECONDARY),
        "Adres Kayıt Sistemi · Form AKS-1 · Lütfen büyük harfle ve okunaklı doldurunuz.",
        (LEFT, top - 41.0),
        WIDTH,
        Align::Left,
    )?;
    doc.line(
        &mut page,
        &styles.label,
        "Başvuru No",
        (LEFT, top - 8.0),
        WIDTH,
        Align::Right,
    )?;
    doc.line(
        &mut page,
        &styles.mono,
        "2026-0047812",
        (LEFT, top - 21.0),
        WIDTH,
        Align::Right,
    )?;
    page.content
        .line_width(1.5)
        .line((LEFT, top - 52.0), (LEFT + WIDTH, top - 52.0))
        .line_width(1.0);

    let mut placed = Vec::new();
    let mut y = top - 52.0;
    for (section, rows) in SECTIONS {
        y -= 13.5;
        page.content
            .fill_rgb(BAND)
            .fill_rect(LEFT, y - 16.0, WIDTH, 16.0)
            .fill_rgb((0, 0, 0));
        doc.line(
            &mut page,
            &styles.small_caps,
            section,
            (LEFT + 6.0, y - 11.5),
            WIDTH,
            Align::Left,
        )?;
        y -= 16.0 + 9.0;
        for row in rows.iter() {
            let mut x = LEFT + 1.5;
            let mut height: f64 = 0.0;
            for (kind, label, width, required, field_name) in row.iter() {
                let width = width * 0.75;
                let mut rects = Vec::new();
                match kind {
                    Kind::Check => {
                        page.content
                            .stroke_rgb(BOX)
                            .line_width(0.75)
                            .stroke_rect(x, y - 11.0, 10.0, 10.0)
                            .stroke_rgb((0, 0, 0));
                        rects.push([x, y - 11.0, x + 10.0, y - 1.0]);
                        doc.line(
                            &mut page,
                            &styles.body,
                            label,
                            (x + 16.0, y - 9.0),
                            WIDTH,
                            Align::Left,
                        )?;
                        height = height.max(14.0);
                    }
                    Kind::Radio => {
                        draw_label(&mut doc, &mut page, &styles, label, *required, x, y - 8.25)?;
                        let mut option_x = x;
                        for option in ["Kadın", "Erkek"] {
                            page.content.stroke_rgb(BOX).line_width(0.75);
                            circle(&mut page.content, option_x + 5.0, y - 20.0, 5.0);
                            page.content.op("S").stroke_rgb((0, 0, 0));
                            rects.push([option_x, y - 25.0, option_x + 10.0, y - 15.0]);
                            doc.line(
                                &mut page,
                                &styles.body,
                                option,
                                (option_x + 14.0, y - 23.0),
                                60.0,
                                Align::Left,
                            )?;
                            option_x += 60.0;
                        }
                        height = height.max(30.0);
                    }
                    _ => {
                        draw_label(&mut doc, &mut page, &styles, label, *required, x, y - 8.25)?;
                        let box_height = if *kind == Kind::Signature { 36.0 } else { 17.0 };
                        page.content
                            .stroke_rgb(BOX)
                            .line_width(0.75)
                            .stroke_rect(x, y - 13.0 - box_height, width, box_height)
                            .stroke_rgb((0, 0, 0));
                        if matches!(kind, Kind::Choice(_)) {
                            // The drop-down arrow.
                            let (ax, ay) = (x + width - 10.0, y - 13.0 - box_height / 2.0);
                            page.content
                                .fill_rgb(SECONDARY)
                                .op(&format!(
                                    "{} {} m {} {} l {} {} l f",
                                    num(ax - 3.0),
                                    num(ay + 1.5),
                                    num(ax + 3.0),
                                    num(ay + 1.5),
                                    num(ax),
                                    num(ay - 2.0)
                                ))
                                .fill_rgb((0, 0, 0));
                        }
                        rects.push([x, y - 13.0 - box_height, x + width, y - 13.0]);
                        height = height.max(13.0 + box_height);
                    }
                }
                placed.push(Placed {
                    kind: *kind,
                    label,
                    required: *required,
                    name: field_name,
                    rects,
                });
                x += if *kind == Kind::Radio {
                    120.0
                } else {
                    width + 16.5
                };
            }
            y -= height + 10.5;
        }
    }
    doc.line(
        &mut page,
        &styles.footer,
        "Bu form e-Devlet Kapısı üzerinden doğrulanabilir · Doğrulama kodu AKS-7F3K-91QD",
        (LEFT, 30.0),
        WIDTH,
        Align::Left,
    )?;
    doc.line(
        &mut page,
        &styles.footer,
        "1 / 1",
        (LEFT, 30.0),
        WIDTH,
        Align::Right,
    )?;

    let (ids, expected) = doc.add_pages(vec![page], pdf::A4);
    let mut catalog = dictionary! { "Lang" => text("tr-TR"), "OpenAction" => open_first(ids[0]) };
    if fields {
        let (annots, acro) = acro_form(&mut doc.pdf, ids[0], &placed);
        super::kira::set_page_entry(&mut doc.pdf, ids[0], "Annots", Object::Array(annots));
        catalog.set("AcroForm", acro);
    }
    let title = "T.C. Yerleşim Yeri Adresi Beyan Formu";
    let name = if fields {
        "form-aks1-tr"
    } else {
        "form-aks1-flat"
    };
    let bytes = doc.close(
        catalog,
        &info(
            title,
            "Adres Kayıt Sistemi",
            "Form tasarımcısı",
            "D:20261001100000+03'00'",
        ),
        name,
        None,
    )?;
    Ok(generated(bytes, expected))
}

/// A circle as four Bézier curves (the usual 0.5523 control distance).
fn circle(content: &mut Content, cx: f64, cy: f64, r: f64) {
    let k = r * 0.552_284_75;
    content.op(&format!(
        "{} {} m {} {} {} {} {} {} c {} {} {} {} {} {} c {} {} {} {} {} {} c {} {} {} {} {} {} c",
        num(cx + r),
        num(cy),
        num(cx + r),
        num(cy + k),
        num(cx + k),
        num(cy + r),
        num(cx),
        num(cy + r),
        num(cx - k),
        num(cy + r),
        num(cx - r),
        num(cy + k),
        num(cx - r),
        num(cy),
        num(cx - r),
        num(cy - k),
        num(cx - k),
        num(cy - r),
        num(cx),
        num(cy - r),
        num(cx + k),
        num(cy - r),
        num(cx + r),
        num(cy - k),
        num(cx + r),
        num(cy),
    ));
}

/// A JavaScript action.
fn js(script: &str) -> Dictionary {
    dictionary! { "S" => "JavaScript", "JS" => Object::string_literal(script) }
}

/// An appearance stream of `width` × `height` with `content`.
fn appearance(
    pdf: &mut Pdf,
    width: f64,
    height: f64,
    content: Content,
    resources: Dictionary,
) -> ObjectId {
    pdf.stream(
        dictionary! {
            "Type" => "XObject",
            "Subtype" => "Form",
            "BBox" => rect(0.0, 0.0, width, height),
            "Resources" => resources,
        },
        content.into_bytes(),
    )
}

/// The AcroForm: one field per placed field, widgets merged into them except the radio
/// buttons, which are kids of their group.
fn acro_form(pdf: &mut Pdf, page: ObjectId, placed: &[Placed]) -> (Vec<Object>, Dictionary) {
    let helv = pdf.add(dictionary! {
        "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Helvetica", "Encoding" => "WinAnsiEncoding",
    });
    let zadb = pdf
        .add(dictionary! { "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "ZapfDingbats" });
    let fonts = || dictionary! { "Font" => dictionary! { "Helv" => helv, "ZaDb" => zadb } };
    let mut annots = Vec::new();
    let mut fields = Vec::new();
    for field in placed {
        let required = if field.required { 2 } else { 0 };
        let first = field.rects.first().copied().unwrap_or([0.0; 4]);
        let [x1, y1, x2, y2] = first;
        let mut dict = dictionary! {
            "T" => text(field.name),
            "TU" => text(field.label),
        };
        let widget = |dict: &mut Dictionary, area: [f64; 4]| {
            dict.set("Type", "Annot");
            dict.set("Subtype", "Widget");
            dict.set("Rect", rect(area[0], area[1], area[2], area[3]));
            dict.set("F", 4);
            dict.set("P", page);
        };
        match field.kind {
            Kind::Text | Kind::Date | Kind::Number => {
                dict.set("FT", "Tx");
                dict.set("Ff", required);
                dict.set("DA", Object::string_literal("/Helv 9 Tf 0 g"));
                if field.name == "tc_kimlik_no" {
                    dict.set("MaxLen", 11);
                }
                match field.kind {
                    Kind::Date => {
                        dict.set(
                            "AA",
                            dictionary! {
                                "K" => js("AFDate_KeystrokeEx(\"dd.mm.yyyy\");"),
                                "F" => js("AFDate_FormatEx(\"dd.mm.yyyy\");"),
                            },
                        );
                    }
                    Kind::Number if field.name == "hane_kisi_sayisi" => {
                        dict.set(
                            "AA",
                            dictionary! {
                                "K" => js("AFNumber_Keystroke(0, 0, 0, 0, \"\", true);"),
                                "V" => js("AFRange_Validate(true, 1, true, 20);"),
                            },
                        );
                    }
                    Kind::Number => {
                        dict.set("AA", dictionary! { "K" => js("AFNumber_Keystroke(0, 0, 0, 0, \"\", true);") });
                    }
                    _ => {}
                }
                let mut content = Content::new();
                content.op("/Tx BMC EMC");
                dict.set(
                    "AP",
                    dictionary! { "N" => appearance(pdf, x2 - x1, y2 - y1, content, fonts()) },
                );
                widget(&mut dict, first);
                let id = pdf.add(dict);
                annots.push(Object::Reference(id));
                fields.push(Object::Reference(id));
            }
            Kind::Choice(options) => {
                dict.set("FT", "Ch");
                dict.set("Ff", required | (1 << 17));
                dict.set(
                    "Opt",
                    Object::Array(options.iter().map(|option| text(option)).collect()),
                );
                dict.set("DA", Object::string_literal("/Helv 9 Tf 0 g"));
                let mut content = Content::new();
                content.op("/Tx BMC EMC");
                dict.set(
                    "AP",
                    dictionary! { "N" => appearance(pdf, x2 - x1, y2 - y1, content, fonts()) },
                );
                widget(&mut dict, first);
                let id = pdf.add(dict);
                annots.push(Object::Reference(id));
                fields.push(Object::Reference(id));
            }
            Kind::Check => {
                dict.set("FT", "Btn");
                dict.set("Ff", required);
                dict.set("V", "Off");
                dict.set("AS", "Off");
                dict.set("DA", Object::string_literal("/ZaDb 0 Tf 0 g"));
                dict.set("MK", dictionary! { "CA" => Object::string_literal("4") });
                let mut on = Content::new();
                on.op("q BT /ZaDb 8 Tf 0 g 1.2 2 Td (4) Tj ET Q");
                let on = appearance(pdf, x2 - x1, y2 - y1, on, fonts());
                let off = appearance(pdf, x2 - x1, y2 - y1, Content::new(), Dictionary::new());
                dict.set(
                    "AP",
                    dictionary! { "N" => dictionary! { "Yes" => on, "Off" => off } },
                );
                widget(&mut dict, first);
                let id = pdf.add(dict);
                annots.push(Object::Reference(id));
                fields.push(Object::Reference(id));
            }
            Kind::Radio => {
                dict.set("FT", "Btn");
                dict.set("Ff", required | (1 << 14) | (1 << 15));
                dict.set("V", "Off");
                let parent = pdf.reserve();
                let mut kids = Vec::new();
                for (area, state) in field.rects.iter().zip(["Kadin", "Erkek"]) {
                    let mut on = Content::new();
                    on.op("q 0 g");
                    circle(&mut on, 5.0, 5.0, 2.5);
                    on.op("f Q");
                    let on = appearance(pdf, 10.0, 10.0, on, Dictionary::new());
                    let off = appearance(pdf, 10.0, 10.0, Content::new(), Dictionary::new());
                    let mut kid = dictionary! {
                        "Parent" => parent,
                        "AS" => "Off",
                        "AP" => dictionary! { "N" => dictionary! { state => on, "Off" => off } },
                    };
                    widget(&mut kid, *area);
                    let kid = pdf.add(kid);
                    annots.push(Object::Reference(kid));
                    kids.push(Object::Reference(kid));
                }
                dict.set("Kids", kids);
                pdf.set(parent, dict);
                fields.push(Object::Reference(parent));
            }
            Kind::Signature => {
                dict.set("FT", "Sig");
                dict.set("Ff", required);
                let empty = appearance(pdf, x2 - x1, y2 - y1, Content::new(), Dictionary::new());
                dict.set("AP", dictionary! { "N" => empty });
                widget(&mut dict, first);
                let id = pdf.add(dict);
                annots.push(Object::Reference(id));
                fields.push(Object::Reference(id));
            }
        }
    }
    let acro = dictionary! {
        "Fields" => fields,
        "DR" => fonts(),
        "DA" => Object::string_literal("/Helv 0 Tf 0 g"),
    };
    (annots, acro)
}

/// The XDP packets of the visa form.
const XDP: [(&str, &str); 5] = [
    (
        "preamble",
        r#"<?xml version="1.0" encoding="UTF-8"?><xdp:xdp xmlns:xdp="http://ns.adobe.com/xdp/" timeStamp="2026-10-01T10:00:00Z" uuid="7f3c1a2e-4b5d-4e6f-8a9b-0c1d2e3f4a5b">"#,
    ),
    (
        "config",
        r#"<config xmlns="http://www.xfa.org/schema/xci/3.1/"><agent name="designer"><destination>pdf</destination></agent><present><pdf><version>1.7</version><adobeExtensionLevel>8</adobeExtensionLevel></pdf><xdp><packets>*</packets></xdp></present></config>"#,
    ),
    (
        "template",
        r#"<template xmlns="http://www.xfa.org/schema/xfa-template/3.3/"><subform name="vize" layout="tb" locale="tr_TR" restoreState="auto"><pageSet><pageArea name="Sayfa1" id="Sayfa1"><contentArea x="15mm" y="15mm" w="180mm" h="267mm"/><medium stock="a4" short="210mm" long="297mm"/></pageArea></pageSet><subform name="basvuran" layout="tb" w="180mm"><draw name="baslik" w="180mm" h="12mm"><value><text>VİZE BAŞVURU FORMU</text></value><font typeface="IBM Plex Sans" size="16pt" weight="bold"/></draw><field name="soyadi" w="88mm" h="10mm"><caption placement="top"><value><text>Soyadı</text></value></caption><ui><textEdit/></ui></field><field name="adi" w="88mm" h="10mm"><caption placement="top"><value><text>Adı</text></value></caption><ui><textEdit/></ui></field><field name="dogum_tarihi" w="50mm" h="10mm"><caption placement="top"><value><text>Doğum tarihi</text></value></caption><ui><dateTimeEdit/></ui><format><picture>date{DD.MM.YYYY}</picture></format></field><field name="pasaport_no" w="60mm" h="10mm"><caption placement="top"><value><text>Pasaport numarası</text></value></caption><ui><textEdit/></ui></field><subform name="seyahatler" layout="tb" occur="1"><occur min="1" max="10"/><field name="ulke" w="88mm" h="10mm"><caption placement="top"><value><text>Daha önce gidilen ülke</text></value></caption><ui><textEdit/></ui></field></subform></subform></subform></template>"#,
    ),
    (
        "datasets",
        r#"<xfa:datasets xmlns:xfa="http://www.xfa.org/schema/xfa-data/1.0/"><xfa:data><vize><basvuran><soyadi/><adi/><dogum_tarihi/><pasaport_no/><seyahatler><ulke/></seyahatler></basvuran></vize></xfa:data></xfa:datasets>"#,
    ),
    ("postamble", "</xdp:xdp>"),
];

fn xfa(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let heading = doc.word_style(sources, FontFile::PlexSansSemiBold, 13.0)?;
    let body = doc.word_style(sources, FontFile::PlexSans, 10.0)?;
    let mut page = PageText::default();
    let lines = [
        (&heading, "Lütfen bekleyin…"),
        (
            &body,
            "Bu belge dinamik bir XFA formudur. Görüntüleyiciniz XFA formlarını desteklemiyorsa",
        ),
        (&body, "bu ileti formun içeriğiyle değişmez."),
        (
            &body,
            "This document is a dynamic XFA form. If your viewer does not support XFA forms,",
        ),
        (
            &body,
            "this message is not replaced by the contents of the form.",
        ),
    ];
    let mut y = pdf::A4.1 - 80.0;
    for (style, line) in lines {
        doc.line(
            &mut page,
            style,
            line,
            (56.0, y),
            pdf::A4.0 - 112.0,
            Align::Left,
        )?;
        y -= if style.size > 11.0 { 22.0 } else { 15.0 };
    }
    let (ids, expected) = doc.add_pages(vec![page], pdf::A4);
    let mut packets = Vec::new();
    for (packet, xml) in XDP {
        let stream = doc
            .pdf
            .make_stream(Dictionary::new(), xml.as_bytes().to_vec());
        packets.push(Object::string_literal(packet));
        packets.push(Object::Reference(doc.pdf.add(stream)));
    }
    let catalog = dictionary! {
        "Lang" => text("tr-TR"),
        "OpenAction" => open_first(ids[0]),
        "NeedsRendering" => true,
        "AcroForm" => dictionary! { "Fields" => Object::Array(Vec::new()), "XFA" => packets },
        "Extensions" => dictionary! { "ADBE" => dictionary! { "BaseVersion" => name("1.7"), "ExtensionLevel" => 8 } },
    };
    let bytes = doc.close(
        catalog,
        &info(
            "Vize başvuru formu",
            "Konsolosluk",
            "XFA form tasarımcısı",
            "D:20261001100000+03'00'",
        ),
        "xfa-visa",
        None,
    )?;
    Ok(generated(bytes, expected))
}
