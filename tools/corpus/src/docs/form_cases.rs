//! The forms and certified files M4's Fill & Sign and gates test on (ROADMAP §8), each one page:
//!
//! - **cert-p1, cert-p2, cert-p3:** certified with `/Perms /DocMDP` at each `/P`, with an empty
//!   text field: no changes, filling and signing, and those with comments.
//! - **form-signed:** two filled fields locked by a signature's FieldMDP (`/Lock` and `/Reference`
//!   with `Include`), one free field and an empty second signature field.
//! - **form-hybrid-xfa:** AcroForm fields with values and XFA packets holding the same values,
//!   without `/NeedsRendering`, so not XFA-only.
//! - **form-need-appearances:** `/NeedAppearances true` and no `/AP` anywhere, with values.
//! - **form-script:** values next to scripts that would change them: `/AA` calculate, format,
//!   validate, keystroke and blur actions, `AFSimple_Calculate`, a button's `/A`, the catalog's
//!   `/OpenAction` and the `/JavaScript` name tree. Nothing may run.
//! - **form-lists-comb:** list boxes, single and multiple, with a selection and a scroll position,
//!   combo boxes with export values, one editable, and comb fields, one filled.
//!
//! Every text is ASCII or Latin-1 where an appearance stream shows it (`/Helv` is WinAnsi), and
//! the signatures are [`crate::pades`]'s.

use super::forms::{appearance, js, xfa_packets};
use super::{Doc, generated, info, open_first, opens};
use crate::pades;
use crate::pdf::{self, Content, Pdf, literal, num, rect, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, PageText, Style};
use crate::{Generated, Generator};
use lopdf::{Dictionary, Object, ObjectId, dictionary};

/// Certified, no changes allowed.
pub const CERT_P1: Generator = Generator {
    name: "cert-p1",
    build: |sources| certified(sources, 1),
    expect: opens(),
};

/// Certified, filling and signing allowed.
pub const CERT_P2: Generator = Generator {
    name: "cert-p2",
    build: |sources| certified(sources, 2),
    expect: opens(),
};

/// Certified, filling, signing and comments allowed.
pub const CERT_P3: Generator = Generator {
    name: "cert-p3",
    build: |sources| certified(sources, 3),
    expect: opens(),
};

/// A signed form.
pub const FORM_SIGNED: Generator = Generator {
    name: "form-signed",
    build: signed_form,
    expect: opens(),
};

/// AcroForm and XFA together.
pub const FORM_HYBRID_XFA: Generator = Generator {
    name: "form-hybrid-xfa",
    build: hybrid,
    expect: opens(),
};

/// `/NeedAppearances` with no `/AP`.
pub const FORM_NEED_APPEARANCES: Generator = Generator {
    name: "form-need-appearances",
    build: need_appearances,
    expect: opens(),
};

/// A form whose scripts would change its values.
pub const FORM_SCRIPT: Generator = Generator {
    name: "form-script",
    build: scripted,
    expect: opens(),
};

/// List boxes, combo boxes and comb fields.
pub const FORM_LISTS_COMB: Generator = Generator {
    name: "form-lists-comb",
    build: lists,
    expect: opens(),
};

const LEFT: f64 = 72.0;
const WIDTH: f64 = pdf::A4.0 - 144.0;
const CREATED: &str = "D:20261013093000+03'00'";
const BOX: (u8, u8, u8) = (0x8A, 0x85, 0x7C);
/// `/Ff` bits.
const RADIO: i64 = (1 << 14) | (1 << 15);
const PUSH: i64 = 1 << 16;
const COMBO: i64 = 1 << 17;
const EDIT: i64 = 1 << 18;
const MULTI_SELECT: i64 = 1 << 21;
const COMB: i64 = 1 << 24;

/// The page: a title, a note, and labelled boxes going down.
struct Sheet {
    doc: Doc,
    page: PageText,
    label: Style,
    y: f64,
}

impl Sheet {
    fn new(sources: &Sources, title: &str, note: &str) -> Result<Self, String> {
        let mut doc = Doc::new("1.7");
        let body = doc.word_style(sources, FontFile::PlexSans, 10.0)?;
        let heading = doc.word_style(sources, FontFile::PlexSansSemiBold, 14.0)?;
        let mut page = PageText::default();
        let top = pdf::A4.1 - 72.0;
        doc.line(&mut page, &heading, title, (LEFT, top), WIDTH, Align::Left)?;
        doc.line(
            &mut page,
            &body,
            note,
            (LEFT, top - 20.0),
            WIDTH,
            Align::Left,
        )?;
        Ok(Self {
            doc,
            page,
            label: body.sized(9.0),
            y: top - 48.0,
        })
    }

    /// Draws a label and a box under it, and returns the box.
    fn field(&mut self, label: &str, width: f64, height: f64) -> Result<[f64; 4], String> {
        self.doc.line(
            &mut self.page,
            &self.label,
            label,
            (LEFT, self.y),
            WIDTH,
            Align::Left,
        )?;
        let bottom = self.y - 5.0 - height;
        self.page
            .content
            .stroke_rgb(BOX)
            .line_width(0.75)
            .stroke_rect(LEFT, bottom, width, height)
            .stroke_rgb((0, 0, 0));
        self.y = bottom - 16.0;
        Ok([LEFT, bottom, LEFT + width, bottom + height])
    }

    /// Adds the page, and returns the document, the page and the expected text.
    fn finish(mut self) -> (Doc, ObjectId, String) {
        let (ids, expected) = self.doc.add_pages(vec![self.page], pdf::A4);
        (self.doc, ids[0], expected.text)
    }
}

/// The form's widgets and fields as they are added.
struct Acro {
    page: ObjectId,
    helv: ObjectId,
    annots: Vec<Object>,
    fields: Vec<Object>,
}

impl Acro {
    fn new(pdf: &mut Pdf, page: ObjectId) -> Self {
        let helv = pdf.add(dictionary! {
            "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Helvetica",
            "Encoding" => "WinAnsiEncoding",
        });
        Self {
            page,
            helv,
            annots: Vec::new(),
            fields: Vec::new(),
        }
    }

    fn resources(&self) -> Dictionary {
        dictionary! { "Font" => dictionary! { "Helv" => self.helv } }
    }

    /// The entries of a field merged with its widget.
    fn widget(&self, name: &str, kind: &str, area: [f64; 4]) -> Dictionary {
        dictionary! {
            "Type" => "Annot",
            "Subtype" => "Widget",
            "FT" => pdf::name(kind),
            "T" => text(name),
            "Rect" => rect(area[0], area[1], area[2], area[3]),
            "F" => 4,
            "P" => self.page,
        }
    }

    /// Adds a field merged with its widget.
    fn add(&mut self, pdf: &mut Pdf, dict: Dictionary) -> ObjectId {
        let id = pdf.add(dict);
        self.annots.push(id.into());
        self.fields.push(id.into());
        id
    }

    /// A text field with `/DA`, `/V` and, unless `bare`, a normal appearance showing the value.
    fn text_field(
        &mut self,
        pdf: &mut Pdf,
        name: &str,
        area: [f64; 4],
        value: &str,
        extra: Dictionary,
        bare: bool,
    ) -> ObjectId {
        let mut dict = self.widget(name, "Tx", area);
        dict.set("DA", Object::string_literal("/Helv 9 Tf 0 g"));
        if !value.is_empty() {
            dict.set("V", text(value));
        }
        for (key, value) in extra {
            dict.set(key, value);
        }
        if !bare {
            let shown = text_appearance(pdf, self, area, value);
            dict.set("AP", dictionary! { "N" => shown });
        }
        self.add(pdf, dict)
    }

    /// `/AcroForm`.
    fn form(&self) -> Dictionary {
        dictionary! {
            "Fields" => self.fields.clone(),
            "DR" => self.resources(),
            "DA" => Object::string_literal("/Helv 0 Tf 0 g"),
        }
    }

    /// Sets the page's `/Annots`.
    fn set_annots(&self, pdf: &mut Pdf) {
        super::kira::set_page_entry(pdf, self.page, "Annots", Object::Array(self.annots.clone()));
    }
}

/// `value` in Latin-1, which WinAnsi agrees with below U+0080 and from U+00A0.
fn latin1(value: &str) -> Vec<u8> {
    value
        .chars()
        .map(|c| u8::try_from(u32::from(c)).unwrap_or(b'?'))
        .collect()
}

/// A line of text, as a text field's `/Tx` marked content.
fn text_appearance(pdf: &mut Pdf, acro: &Acro, area: [f64; 4], value: &str) -> ObjectId {
    let (width, height) = (area[2] - area[0], area[3] - area[1]);
    let mut content = Content::new();
    content.op("/Tx BMC");
    if !value.is_empty() {
        content.op(&format!(
            "q BT /Helv 9 Tf 0 g 3 {} Td {} Tj ET Q",
            num((height - 6.5) / 2.0),
            literal(&latin1(value))
        ));
    }
    content.op("EMC");
    appearance(pdf, width, height, content, acro.resources())
}

/// The characters of `value`, each centred in one of `cells`, as a comb field shows them.
fn comb_appearance(
    pdf: &mut Pdf,
    acro: &Acro,
    area: [f64; 4],
    value: &str,
    cells: u32,
) -> ObjectId {
    let (width, height) = (area[2] - area[0], area[3] - area[1]);
    let cell = width / f64::from(cells);
    let mut content = Content::new();
    content.op("/Tx BMC q BT /Helv 9 Tf 0 g");
    let mut at = 0.0;
    for (index, code) in (0u32..).zip(latin1(value)) {
        let x = (f64::from(index) + 0.5) * cell - 2.5;
        content.op(&format!(
            "{} {} Td {} Tj",
            num(x - at),
            if index == 0 { "6" } else { "0" },
            literal(&[code])
        ));
        at = x;
    }
    content.op("ET Q EMC");
    appearance(pdf, width, height, content, acro.resources())
}

/// Lines from `first`, the `selected` ones on a band, as a list box shows them.
fn list_appearance(
    pdf: &mut Pdf,
    acro: &Acro,
    area: [f64; 4],
    options: &[&str],
    first: usize,
    selected: &[usize],
) -> ObjectId {
    let (width, height) = (area[2] - area[0], area[3] - area[1]);
    let mut content = Content::new();
    content.op("/Tx BMC q");
    let mut y = height - 12.0;
    for (index, option) in options.iter().enumerate().skip(first) {
        if y < 0.0 {
            break;
        }
        if selected.contains(&index) {
            content.op(&format!(
                "0.6 0.75 0.85 rg 0 {} {} 12 re f",
                num(y),
                num(width)
            ));
        }
        content.op(&format!(
            "BT /Helv 9 Tf 0 g 3 {} Td {} Tj ET",
            num(y + 3.0),
            literal(&latin1(option))
        ));
        y -= 12.0;
    }
    content.op("Q EMC");
    appearance(pdf, width, height, content, acro.resources())
}

/// Integers as an array.
fn indices(values: &[usize]) -> Object {
    Object::Array(
        values
            .iter()
            .map(|value| Object::Integer(i64::try_from(*value).unwrap_or(0)))
            .collect(),
    )
}

/// `/Lang` and the opening view every form has.
fn catalog(page: ObjectId, acro: Dictionary) -> Dictionary {
    dictionary! { "Lang" => text("tr-TR"), "OpenAction" => open_first(page), "AcroForm" => acro }
}

fn certified(sources: &Sources, level: i64) -> Result<Generated, String> {
    let name = format!("cert-p{level}");
    let note = match level {
        1 => "Bu belge sertifikalıdır: hiçbir değişikliğe izin verilmez.",
        2 => "Bu belge sertifikalıdır: yalnızca form doldurma ve imzaya izin verilir.",
        _ => "Bu belge sertifikalıdır: form doldurma, imza ve yorumlara izin verilir.",
    };
    let mut sheet = Sheet::new(sources, "Sertifikalı onay yazısı", note)?;
    let area = sheet.field("Onay notu", 300.0, 18.0)?;
    let (mut doc, page, expected) = sheet.finish();
    let mut acro = Acro::new(&mut doc.pdf, page);
    acro.text_field(
        &mut doc.pdf,
        "onay_notu",
        area,
        "",
        Dictionary::new(),
        false,
    );
    let value = doc.pdf.add(pades::value(dictionary! {
        "Name" => text("Mert Kaya"),
        "Reason" => text("Belgeyi onaylıyorum."),
        "Location" => text("İstanbul"),
        "M" => text(pades::SIGNED_AT),
        "Reference" => vec![Object::Dictionary(dictionary! {
            "Type" => "SigRef",
            "TransformMethod" => "DocMDP",
            "TransformParams" => dictionary! { "Type" => "TransformParams", "P" => level, "V" => "1.2" },
        })],
    }));
    // The certification's field: an invisible signature.
    let mut signature = acro.widget("sertifika_imzasi", "Sig", [0.0, 0.0, 0.0, 0.0]);
    signature.set("F", 132);
    signature.set("V", value);
    acro.add(&mut doc.pdf, signature);
    acro.set_annots(&mut doc.pdf);
    let mut form = acro.form();
    form.set("SigFlags", 3);
    let mut root = catalog(page, form);
    root.set("Perms", dictionary! { "DocMDP" => value });
    let bytes = doc.close(
        root,
        &info(
            "Sertifikalı onay yazısı",
            "Mert Kaya",
            "Kelime işlemci",
            CREATED,
        ),
        &name,
        None,
    )?;
    Ok(generated(pades::sign(bytes)?, expected))
}

fn signed_form(sources: &Sources) -> Result<Generated, String> {
    let mut sheet = Sheet::new(
        sources,
        "Taahhütname",
        "Ad ve kimlik numarası imzayla kilitlenmiştir; adres ve ikinci imza açıktır.",
    )?;
    let name_area = sheet.field("Adı soyadı", 300.0, 18.0)?;
    let id_area = sheet.field("T.C. Kimlik No", 200.0, 18.0)?;
    let address_area = sheet.field("Adres", 400.0, 18.0)?;
    let first_area = sheet.field("Birinci imza", 240.0, 40.0)?;
    let second_area = sheet.field("İkinci imza", 240.0, 40.0)?;
    let (mut doc, page, expected) = sheet.finish();
    let mut acro = Acro::new(&mut doc.pdf, page);
    let locked = vec![text("adi_soyadi"), text("tc_kimlik_no")];
    acro.text_field(
        &mut doc.pdf,
        "adi_soyadi",
        name_area,
        "Mert Kaya",
        Dictionary::new(),
        false,
    );
    acro.text_field(
        &mut doc.pdf,
        "tc_kimlik_no",
        id_area,
        "10000000146",
        Dictionary::new(),
        false,
    );
    acro.text_field(
        &mut doc.pdf,
        "adres",
        address_area,
        "",
        Dictionary::new(),
        false,
    );
    let value = doc.pdf.add(pades::value(dictionary! {
        "Name" => text("Mert Kaya"),
        "Reason" => text("Bilgilerimi onaylıyorum."),
        "Location" => text("İstanbul"),
        "M" => text(pades::SIGNED_AT),
    }));
    let mut first = acro.widget("birinci_imza", "Sig", first_area);
    first.set("V", value);
    first.set(
        "Lock",
        dictionary! { "Type" => "SigFieldLock", "Action" => "Include", "Fields" => locked.clone() },
    );
    let mut shown = Content::new();
    shown.op("BT /Helv 9 Tf 0 g 6 16 Td (Mert Kaya) Tj ET");
    let shown = appearance(&mut doc.pdf, 240.0, 40.0, shown, acro.resources());
    first.set("AP", dictionary! { "N" => shown });
    acro.add(&mut doc.pdf, first);
    let second = acro.widget("ikinci_imza", "Sig", second_area);
    acro.add(&mut doc.pdf, second);
    acro.set_annots(&mut doc.pdf);
    let mut form = acro.form();
    form.set("SigFlags", 3);
    let root = catalog(page, form);
    doc.fonts.finish(&mut doc.pdf)?;
    let mut pdf = doc.pdf;
    pdf.close(
        root,
        &info("Taahhütname", "Mert Kaya", "Form tasarımcısı", CREATED),
        "form-signed",
    )?;
    // FieldMDP's `/Data` is the catalog, which exists only now.
    let root = pdf
        .doc
        .trailer
        .get(b"Root")
        .and_then(Object::as_reference)
        .map_err(|err| err.to_string())?;
    if let Some(Object::Dictionary(dict)) = pdf.doc.objects.get_mut(&value) {
        dict.set(
            "Reference",
            vec![Object::Dictionary(dictionary! {
                "Type" => "SigRef",
                "TransformMethod" => "FieldMDP",
                "TransformParams" => dictionary! {
                    "Type" => "TransformParams", "Action" => "Include", "Fields" => locked, "V" => "1.2",
                },
                "Data" => root,
            })],
        );
    }
    Ok(generated(pades::sign(pdf.save()?)?, expected))
}

/// The XDP packets of the hybrid form, with the AcroForm's values in `datasets`.
const HYBRID_XDP: [(&str, &str); 4] = [
    (
        "preamble",
        r#"<?xml version="1.0" encoding="UTF-8"?><xdp:xdp xmlns:xdp="http://ns.adobe.com/xdp/">"#,
    ),
    (
        "template",
        r#"<template xmlns="http://www.xfa.org/schema/xfa-template/3.3/"><subform name="basvuru" layout="position" locale="tr_TR"><pageSet><pageArea name="Sayfa1"><contentArea x="0mm" y="0mm" w="210mm" h="297mm"/><medium stock="a4" short="210mm" long="297mm"/></pageArea></pageSet><field name="adi" x="25mm" y="50mm" w="100mm" h="7mm"><ui><textEdit/></ui></field><field name="sehir" x="25mm" y="65mm" w="100mm" h="7mm"><ui><textEdit/></ui></field></subform></template>"#,
    ),
    (
        "datasets",
        r#"<xfa:datasets xmlns:xfa="http://www.xfa.org/schema/xfa-data/1.0/"><xfa:data><basvuru><adi>Mert Kaya</adi><sehir>Bursa</sehir></basvuru></xfa:data></xfa:datasets>"#,
    ),
    ("postamble", "</xdp:xdp>"),
];

fn hybrid(sources: &Sources) -> Result<Generated, String> {
    let mut sheet = Sheet::new(
        sources,
        "Başvuru formu",
        "Bu form hem AcroForm alanları hem XFA paketleri taşır.",
    )?;
    let name_area = sheet.field("Adı", 300.0, 18.0)?;
    let city_area = sheet.field("Şehir", 300.0, 18.0)?;
    let (mut doc, page, expected) = sheet.finish();
    let mut acro = Acro::new(&mut doc.pdf, page);
    acro.text_field(
        &mut doc.pdf,
        "adi",
        name_area,
        "Mert Kaya",
        Dictionary::new(),
        false,
    );
    acro.text_field(
        &mut doc.pdf,
        "sehir",
        city_area,
        "Bursa",
        Dictionary::new(),
        false,
    );
    acro.set_annots(&mut doc.pdf);
    let mut form = acro.form();
    form.set("XFA", xfa_packets(&mut doc.pdf, &HYBRID_XDP));
    let bytes = doc.close(
        catalog(page, form),
        &info(
            "Başvuru formu",
            "Konsolosluk",
            "XFA form tasarımcısı",
            CREATED,
        ),
        "form-hybrid-xfa",
        None,
    )?;
    Ok(generated(bytes, expected))
}

fn need_appearances(sources: &Sources) -> Result<Generated, String> {
    let mut sheet = Sheet::new(
        sources,
        "Üyelik formu",
        "Bu formun alanlarının görünüm akışı yoktur; değerler yine de doludur.",
    )?;
    let name_area = sheet.field("Adı soyadı", 300.0, 18.0)?;
    let empty_area = sheet.field("Telefon", 200.0, 18.0)?;
    let check_area = sheet.field("Bültene abone", 12.0, 12.0)?;
    let radio_areas = [
        sheet.field("Üyelik: bireysel", 12.0, 12.0)?,
        sheet.field("Üyelik: kurumsal", 12.0, 12.0)?,
    ];
    let city_area = sheet.field("Şehir", 200.0, 18.0)?;
    let branch_area = sheet.field("Şube", 200.0, 40.0)?;
    let (mut doc, page, expected) = sheet.finish();
    let mut acro = Acro::new(&mut doc.pdf, page);
    acro.text_field(
        &mut doc.pdf,
        "adi_soyadi",
        name_area,
        "Ayşe Yılmaz",
        Dictionary::new(),
        true,
    );
    acro.text_field(
        &mut doc.pdf,
        "telefon",
        empty_area,
        "",
        Dictionary::new(),
        true,
    );
    let mut check = acro.widget("bulten", "Btn", check_area);
    check.set("V", "Yes");
    check.set("AS", "Yes");
    acro.add(&mut doc.pdf, check);
    let group = doc.pdf.reserve();
    let mut kids = Vec::new();
    for (area, state) in radio_areas.into_iter().zip(["Bireysel", "Kurumsal"]) {
        let kid = dictionary! {
            "Type" => "Annot",
            "Subtype" => "Widget",
            "Parent" => group,
            "Rect" => rect(area[0], area[1], area[2], area[3]),
            "F" => 4,
            "P" => page,
            "AS" => if state == "Kurumsal" { state } else { "Off" },
            "MK" => dictionary! { "CA" => Object::string_literal("l") },
        };
        let kid = doc.pdf.add(kid);
        acro.annots.push(kid.into());
        kids.push(Object::from(kid));
    }
    doc.pdf.set(
        group,
        dictionary! {
            "FT" => "Btn", "T" => text("uyelik"), "Ff" => RADIO, "V" => "Kurumsal", "Kids" => kids,
        },
    );
    acro.fields.push(group.into());
    let mut city = acro.widget("sehir", "Ch", city_area);
    city.set("Ff", COMBO);
    city.set("Opt", vec![text("Bursa"), text("İzmir"), text("Van")]);
    city.set("V", text("İzmir"));
    city.set("DA", Object::string_literal("/Helv 9 Tf 0 g"));
    acro.add(&mut doc.pdf, city);
    let mut branch = acro.widget("sube", "Ch", branch_area);
    branch.set("Opt", vec![text("Merkez"), text("Batı"), text("Doğu")]);
    branch.set("V", text("Batı"));
    branch.set("I", indices(&[1]));
    branch.set("DA", Object::string_literal("/Helv 9 Tf 0 g"));
    acro.add(&mut doc.pdf, branch);
    acro.set_annots(&mut doc.pdf);
    let mut form = acro.form();
    form.set("NeedAppearances", true);
    let bytes = doc.close(
        catalog(page, form),
        &info("Üyelik formu", "Dernek", "Form tasarımcısı", CREATED),
        "form-need-appearances",
        None,
    )?;
    Ok(generated(bytes, expected))
}

fn scripted(sources: &Sources) -> Result<Generated, String> {
    let mut sheet = Sheet::new(
        sources,
        "Sipariş formu",
        "Bu formun betikleri değerleri değiştirmek ister; Ferman betik çalıştırmaz.",
    )?;
    let price_area = sheet.field("Birim fiyat", 120.0, 18.0)?;
    let count_area = sheet.field("Adet", 120.0, 18.0)?;
    let subtotal_area = sheet.field("Ara toplam (AFSimple_Calculate)", 120.0, 18.0)?;
    let total_area = sheet.field("Toplam (hesap betiği)", 120.0, 18.0)?;
    let status_area = sheet.field("Durum (açılış betiği)", 200.0, 18.0)?;
    let button_area = sheet.field("Hesapla", 90.0, 20.0)?;
    let (mut doc, page, expected) = sheet.finish();
    let mut acro = Acro::new(&mut doc.pdf, page);
    acro.text_field(
        &mut doc.pdf,
        "birim_fiyat",
        price_area,
        "100",
        dictionary! {
            "AA" => dictionary! {
                "K" => js("event.value = event.value.replace(\",\", \".\");"),
                "F" => js("event.value = \"TL \" + event.value;"),
                "V" => js("if (event.value > 50) event.value = 50;"),
            },
        },
        false,
    );
    acro.text_field(
        &mut doc.pdf,
        "adet",
        count_area,
        "2",
        dictionary! {
            "AA" => dictionary! { "Bl" => js("this.getField(\"durum\").value = \"Degisti\";") },
        },
        false,
    );
    let subtotal = acro.text_field(
        &mut doc.pdf,
        "ara_toplam",
        subtotal_area,
        "1",
        dictionary! {
            "AA" => dictionary! { "C" => js("AFSimple_Calculate(\"SUM\", new Array (\"birim_fiyat\", \"adet\"));") },
        },
        false,
    );
    let total = acro.text_field(
        &mut doc.pdf,
        "toplam",
        total_area,
        "1",
        dictionary! {
            "AA" => dictionary! {
                "C" => js("event.value = this.getField(\"birim_fiyat\").value * this.getField(\"adet\").value;"),
            },
        },
        false,
    );
    acro.text_field(
        &mut doc.pdf,
        "durum",
        status_area,
        "Bekliyor",
        Dictionary::new(),
        false,
    );
    let mut button = acro.widget("hesapla", "Btn", button_area);
    button.set("Ff", PUSH);
    button.set("MK", dictionary! { "CA" => text("Hesapla") });
    button.set(
        "A",
        js("this.getField(\"durum\").value = \"Hesaplandi\"; this.calculateNow();"),
    );
    let mut face = Content::new();
    face.op("BT /Helv 9 Tf 0 g 12 6 Td (Hesapla) Tj ET");
    let face = appearance(&mut doc.pdf, 90.0, 20.0, face, acro.resources());
    button.set("AP", dictionary! { "N" => face });
    acro.add(&mut doc.pdf, button);
    acro.set_annots(&mut doc.pdf);
    let mut form = acro.form();
    form.set("CO", vec![Object::from(subtotal), Object::from(total)]);
    let open = doc
        .pdf
        .add(js("this.getField(\"durum\").value = \"Acildi\";"));
    let init = doc.pdf.add(js("this.getField(\"adet\").value = 99;"));
    let names = doc
        .pdf
        .add(dictionary! { "Names" => vec![text("baslangic"), init.into()] });
    let root = dictionary! {
        "Lang" => text("tr-TR"),
        "OpenAction" => open,
        "AcroForm" => form,
        "Names" => dictionary! { "JavaScript" => names },
    };
    let bytes = doc.close(
        root,
        &info("Sipariş formu", "Satış", "Form tasarımcısı", CREATED),
        "form-script",
        None,
    )?;
    Ok(generated(bytes, expected))
}

fn lists(sources: &Sources) -> Result<Generated, String> {
    const CITIES: [&str; 8] = [
        "Adana", "Ankara", "Bursa", "Izmir", "Konya", "Mersin", "Samsun", "Van",
    ];
    const LANGUAGES: [&str; 4] = ["English", "Deutsch", "Français", "Español"];
    let mut sheet = Sheet::new(
        sources,
        "Başvuru seçimleri",
        "Liste kutuları, açılır kutular ve kutucuklu alanlar.",
    )?;
    let city_area = sheet.field("Şehir (liste, tek seçim, kaydırılmış)", 200.0, 48.0)?;
    let language_area = sheet.field("Diller (liste, çoklu seçim)", 200.0, 48.0)?;
    let country_area = sheet.field("Ülke (açılır, dışa aktarım değeri)", 200.0, 18.0)?;
    let job_area = sheet.field("Meslek (düzenlenebilir açılır)", 200.0, 18.0)?;
    let id_area = sheet.field("T.C. Kimlik No (11 kutucuk, dolu)", 220.0, 20.0)?;
    let code_area = sheet.field("Posta kodu (5 kutucuk, boş)", 100.0, 20.0)?;
    let (mut doc, page, expected) = sheet.finish();
    let mut acro = Acro::new(&mut doc.pdf, page);
    let da = || Object::string_literal("/Helv 9 Tf 0 g");

    let mut city = acro.widget("sehir", "Ch", city_area);
    city.set(
        "Opt",
        CITIES.iter().map(|city| text(city)).collect::<Vec<_>>(),
    );
    city.set("V", text("Konya"));
    city.set("I", indices(&[4]));
    city.set("TI", 3);
    city.set("DA", da());
    let shown = list_appearance(&mut doc.pdf, &acro, city_area, &CITIES, 3, &[4]);
    city.set("AP", dictionary! { "N" => shown });
    acro.add(&mut doc.pdf, city);

    let mut language = acro.widget("diller", "Ch", language_area);
    language.set("Ff", MULTI_SELECT);
    language.set(
        "Opt",
        LANGUAGES
            .iter()
            .map(|language| text(language))
            .collect::<Vec<_>>(),
    );
    language.set("V", vec![text("English"), text("Français")]);
    language.set("I", indices(&[0, 2]));
    language.set("DA", da());
    let shown = list_appearance(&mut doc.pdf, &acro, language_area, &LANGUAGES, 0, &[0, 2]);
    language.set("AP", dictionary! { "N" => shown });
    acro.add(&mut doc.pdf, language);

    // Export values: `/V` holds the export value, the appearance the display one.
    let mut country = acro.widget("ulke", "Ch", country_area);
    country.set("Ff", COMBO);
    country.set(
        "Opt",
        vec![
            Object::Array(vec![text("TR"), text("Türkiye")]),
            Object::Array(vec![text("DE"), text("Almanya")]),
            Object::Array(vec![text("FR"), text("Fransa")]),
        ],
    );
    country.set("V", text("TR"));
    country.set("I", indices(&[0]));
    country.set("DA", da());
    let shown = text_appearance(&mut doc.pdf, &acro, country_area, "Türkiye");
    country.set("AP", dictionary! { "N" => shown });
    acro.add(&mut doc.pdf, country);

    let mut job = acro.widget("meslek", "Ch", job_area);
    job.set("Ff", COMBO | EDIT);
    job.set("Opt", vec![text("Avukat"), text("Muhasebeci")]);
    job.set("V", text("Mimar"));
    job.set("DA", da());
    let shown = text_appearance(&mut doc.pdf, &acro, job_area, "Mimar");
    job.set("AP", dictionary! { "N" => shown });
    acro.add(&mut doc.pdf, job);

    let mut id = acro.widget("tc_kimlik_no", "Tx", id_area);
    id.set("Ff", COMB);
    id.set("MaxLen", 11);
    id.set("V", text("10000000146"));
    id.set("DA", da());
    let shown = comb_appearance(&mut doc.pdf, &acro, id_area, "10000000146", 11);
    id.set("AP", dictionary! { "N" => shown });
    acro.add(&mut doc.pdf, id);

    acro.text_field(
        &mut doc.pdf,
        "posta_kodu",
        code_area,
        "",
        dictionary! { "Ff" => COMB, "MaxLen" => 5 },
        false,
    );
    acro.set_annots(&mut doc.pdf);
    let bytes = doc.close(
        catalog(page, acro.form()),
        &info("Başvuru seçimleri", "Dernek", "Form tasarımcısı", CREATED),
        "form-lists-comb",
        None,
    )?;
    Ok(generated(bytes, expected))
}
