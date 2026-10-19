//! `ocg-plan`: the floor plan of the design's `DocPlan` ("Kat planı — Daire 5", Moda Cad. No:
//! 18, Kadıköy, scale 1:75, sheet A-01) on an A4 landscape page, drawn in six optional content
//! groups (layers). "Tesisat" (plumbing) is off by default and holds only lines, so the
//! extracted text does not depend on whether a reader honours layers. A `/VP` viewport with a
//! `/Measure` dictionary gives the 1:75 scale for measuring (a4-1c).

use super::{Doc, generated, info, open_first, opens};
use crate::pdf::{Content, num, real, rect, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, PageText};
use crate::{Generated, Generator};
use lopdf::{Object, ObjectId, dictionary};

/// The layered plan.
pub const OCG_PLAN: Generator = Generator {
    name: "ocg-plan",
    build,
    expect: opens(),
};

const PAGE: (f64, f64) = (841.89, 595.276);
/// Points per metre at 1:75: 1 m is 13.333 mm on paper.
const SCALE: f64 = 1000.0 / 75.0 / 25.4 * 72.0;
const ORIGIN: (f64, f64) = (60.0, 120.0);

fn at(x: f64, y: f64) -> (f64, f64) {
    (ORIGIN.0 + x * SCALE, ORIGIN.1 + y * SCALE)
}

/// A rectangle in metres.
fn room(content: &mut Content, x: f64, y: f64, w: f64, h: f64) {
    let (px, py) = at(x, y);
    content.op(&format!(
        "{} {} {} {} re",
        num(px),
        num(py),
        num(w * SCALE),
        num(h * SCALE)
    ));
}

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let label = doc.word_style(sources, FontFile::PlexSansSemiBold, 9.0)?;
    let small = doc.word_style(sources, FontFile::PlexSans, 8.0)?;
    let title = doc.word_style(sources, FontFile::PlexSansSemiBold, 14.0)?;
    let layers = [
        "Duvarlar",
        "Kapılar ve pencereler",
        "Mobilya",
        "Ölçüler",
        "Oda adları",
        "Tesisat",
    ];
    let ids: Vec<ObjectId> = layers
        .iter()
        .map(|layer| {
            doc.pdf
                .add(dictionary! { "Type" => "OCG", "Name" => text(layer) })
        })
        .collect();
    let mut page = PageText::default();
    let mut properties = lopdf::Dictionary::new();
    for (index, id) in ids.iter().enumerate() {
        properties.set(format!("oc{}", index + 1), *id);
    }

    // Walls: the outline 12.00 × 10.80 m and the inner walls.
    page.content
        .op("/OC /oc1 BDC")
        .op("q 0.12 0.11 0.1 RG 4 w 2 J");
    room(&mut page.content, 0.0, 0.0, 12.0, 10.8);
    page.content.op("S 2 w");
    for ((x1, y1), (x2, y2)) in [
        ((6.6, 5.3), (6.6, 10.8)),
        ((0.0, 5.3), (12.0, 5.3)),
        ((3.3, 0.0), (3.3, 5.3)),
        ((6.4, 0.0), (6.4, 5.3)),
        ((9.0, 0.0), (9.0, 5.3)),
    ] {
        let (a, b) = (at(x1, y1), at(x2, y2));
        page.content.op(&format!(
            "{} {} m {} {} l S",
            num(a.0),
            num(a.1),
            num(b.0),
            num(b.1)
        ));
    }
    page.content.op("Q EMC");

    // Doors as quarter arcs, windows as double lines.
    page.content
        .op("/OC /oc2 BDC")
        .op("q 0.35 0.33 0.3 RG 0.75 w");
    for (x, y) in [(5.6, 5.3), (7.0, 5.3), (3.5, 0.9), (6.6, 0.9)] {
        let (px, py) = at(x, y);
        let r = 0.9 * SCALE;
        page.content.op(&format!(
            "{} {} m {} {} l {} {} {} {} {} {} c S",
            num(px),
            num(py),
            num(px + r),
            num(py),
            num(px + r),
            num(py + r * 0.55),
            num(px + r * 0.55),
            num(py + r),
            num(px),
            num(py + r)
        ));
    }
    for (x, y, w) in [
        (1.0, 10.8, 3.0),
        (8.0, 10.8, 2.6),
        (0.6, 0.0, 1.8),
        (9.6, 0.0, 1.6),
    ] {
        let (a, b) = (at(x, y), at(x + w, y));
        page.content.op(&format!(
            "{} {} m {} {} l {} {} m {} {} l S",
            num(a.0),
            num(a.1 - 2.0),
            num(b.0),
            num(b.1 - 2.0),
            num(a.0),
            num(a.1 + 2.0),
            num(b.0),
            num(b.1 + 2.0)
        ));
    }
    page.content.op("Q EMC");

    // Furniture.
    page.content
        .op("/OC /oc3 BDC")
        .op("q 0.55 0.53 0.5 RG 0.5 w");
    for (x, y, w, h) in [
        (0.6, 6.0, 2.4, 0.9),
        (0.6, 8.6, 1.0, 1.6),
        (3.6, 7.4, 1.6, 1.0),
        (8.0, 7.6, 1.6, 2.0),
        (6.9, 9.6, 1.0, 0.8),
        (6.6, 0.3, 2.2, 0.6),
        (9.4, 0.3, 1.6, 0.8),
        (0.3, 0.3, 2.6, 0.6),
    ] {
        room(&mut page.content, x, y, w, h);
        page.content.op("S");
    }
    page.content.op("Q EMC");

    // Dimensions: the overall width and depth.
    page.content
        .op("/OC /oc4 BDC")
        .op("q 0.165 0.302 0.686 RG 0.165 0.302 0.686 rg 0.5 w");
    let (left, right) = (at(0.0, 11.4), at(12.0, 11.4));
    page.content.op(&format!(
        "{} {} m {} {} l S",
        num(left.0),
        num(left.1),
        num(right.0),
        num(right.1)
    ));
    let (bottom_right, top_right) = (at(12.6, 0.0), at(12.6, 10.8));
    page.content.op(&format!(
        "{} {} m {} {} l S",
        num(bottom_right.0),
        num(bottom_right.1),
        num(top_right.0),
        num(top_right.1)
    ));
    page.content.op("Q");
    doc.line(
        &mut page,
        &small.colored((0x2A, 0x4D, 0xAF)),
        "12,00",
        (left.0, left.1 + 4.0),
        12.0 * SCALE,
        Align::Center,
    )?;
    let (dx, dy) = at(12.75, 5.4);
    doc.line(
        &mut page,
        &small.colored((0x2A, 0x4D, 0xAF)),
        "10,80",
        (dx, dy),
        40.0,
        Align::Left,
    )?;
    page.content.op("EMC");

    // Room names and areas.
    page.content.op("/OC /oc5 BDC");
    for (name, area, x, y) in [
        ("SALON", "35,1 m²", 3.3, 8.2),
        ("YATAK ODASI", "25,9 m²", 9.3, 8.2),
        ("MUTFAK", "10,6 m²", 1.65, 2.8),
        ("ANTRE", "10,8 m²", 4.85, 2.8),
        ("BANYO", "7,4 m²", 7.7, 2.8),
        ("ÇALIŞMA", "8,1 m²", 10.5, 2.8),
    ] {
        let (px, py) = at(x, y);
        doc.line(
            &mut page,
            &label,
            name,
            (px - 50.0, py),
            100.0,
            Align::Center,
        )?;
        doc.line(
            &mut page,
            &small,
            area,
            (px - 50.0, py - 12.0),
            100.0,
            Align::Center,
        )?;
    }
    page.content.op("EMC");

    // Plumbing, off by default: lines only.
    page.content
        .op("/OC /oc6 BDC")
        .op("q 0.1 0.5 0.8 RG 1 w [4 2] 0 d");
    for ((x1, y1), (x2, y2)) in [
        ((1.0, 0.4), (1.0, 4.8)),
        ((1.0, 4.8), (7.0, 4.8)),
        ((7.0, 4.8), (7.0, 0.6)),
    ] {
        let (a, b) = (at(x1, y1), at(x2, y2));
        page.content.op(&format!(
            "{} {} m {} {} l S",
            num(a.0),
            num(a.1),
            num(b.0),
            num(b.1)
        ));
    }
    page.content.op("Q EMC");

    // The title block, outside the layers.
    page.content
        .op("q 0.75 w 600 60 m 800 60 l 800 300 l 600 300 l h S Q");
    doc.line(
        &mut page,
        &title,
        "KAT PLANI — DAİRE 5",
        (612.0, 276.0),
        180.0,
        Align::Left,
    )?;
    for (index, line) in [
        "Moda Cad. No: 18, Kadıköy, İstanbul",
        "Ölçek 1:75 · Pafta A-01",
        "Net alan: 97,9 m²",
        "Çizen: Yılmaz Mimarlık",
        "Tarih: 13.10.2026",
    ]
    .iter()
    .enumerate()
    {
        #[allow(clippy::cast_precision_loss)]
        let y = 252.0 - 16.0 * index as f64;
        doc.line(&mut page, &small, line, (612.0, y), 180.0, Align::Left)?;
    }
    page.resources.set("Properties", properties);

    let (pages, expected) = doc.add_pages(vec![page], PAGE);
    let (x2, y2) = at(12.0, 10.8);
    let metre = 1.0 / SCALE;
    let viewport = dictionary! {
        "Type" => "Viewport",
        "BBox" => rect(ORIGIN.0, ORIGIN.1, x2, y2),
        "Name" => text("Kat planı"),
        "Measure" => dictionary! {
            "Type" => "Measure",
            "Subtype" => "RL",
            "R" => text("1:75"),
            "X" => vec![dictionary! { "Type" => "NumberFormat", "U" => text("m"), "C" => real(metre), "D" => 100 }.into()],
            "D" => vec![dictionary! { "Type" => "NumberFormat", "U" => text("m"), "C" => 1, "D" => 100 }.into()],
            "A" => vec![dictionary! { "Type" => "NumberFormat", "U" => text("m²"), "C" => 1, "D" => 10 }.into()],
        },
    };
    super::kira::set_page_entry(
        &mut doc.pdf,
        pages[0],
        "VP",
        Object::Array(vec![viewport.into()]),
    );
    let all: Vec<Object> = ids.iter().map(|id| Object::Reference(*id)).collect();
    let on: Vec<Object> = ids[..5].iter().map(|id| Object::Reference(*id)).collect();
    let catalog = dictionary! {
        "Lang" => text("tr-TR"),
        "OpenAction" => open_first(pages[0]),
        "PageMode" => "UseOC",
        "OCProperties" => dictionary! {
            "OCGs" => all.clone(),
            "D" => dictionary! {
                "Name" => text("Varsayılan"),
                "Order" => all,
                "ON" => on,
                "OFF" => vec![Object::Reference(ids[5])],
            },
        },
    };
    let bytes = doc.close(
        catalog,
        &info(
            "Kat planı — Daire 5",
            "Yılmaz Mimarlık",
            "Çizim programı",
            "D:20261013110000+03'00'",
        ),
        "ocg-plan",
        None,
    )?;
    Ok(generated(bytes, expected))
}
