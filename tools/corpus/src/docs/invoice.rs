//! `fatura-tr`: a one-page Turkish invoice for an office's November rent, set as Word sets it
//! (IBM Plex Sans as simple TrueType WinAnsi subsets, with composite subsets of the same face for
//! ş, ı, ğ and İ). Its table has a right-aligned amount column and three total rows that depend
//! on it: an edit of an amount keeps the alignment and flags the totals (ROADMAP E07).

use super::{Doc, generated, info, open_first, opens};
use crate::pdf::{self, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, PageText};
use crate::{Generated, Generator};
use lopdf::dictionary;

/// The invoice.
pub const FATURA_TR: Generator = Generator {
    name: "fatura-tr",
    build,
    expect: opens(),
};

const LEFT: f64 = 64.0;
const WIDTH: f64 = pdf::A4.0 - 128.0;
const RULE: (u8, u8, u8) = (0xC9, 0xC4, 0xBA);

/// The columns: left edge from `LEFT`, width, alignment, header.
const COLUMNS: [(f64, f64, Align, &str); 5] = [
    (0.0, 30.0, Align::Left, "Sıra"),
    (34.0, 200.0, Align::Left, "Açıklama"),
    (238.0, 50.0, Align::Right, "Miktar"),
    (292.0, 85.0, Align::Right, "Birim fiyat"),
    (381.0, 86.276, Align::Right, "Tutar (TL)"),
];

/// The items; each amount is the quantity times the unit price.
const ITEMS: [[&str; 5]; 4] = [
    [
        "1",
        "Ofis kirası, Kasım 2026",
        "1",
        "18.500,00",
        "18.500,00",
    ],
    ["2", "Site aidatı", "1", "1.250,00", "1.250,00"],
    ["3", "Kapalı otopark yeri", "2", "750,00", "1.500,00"],
    ["4", "Ortak alan temizliği", "4", "425,00", "1.700,00"],
];

/// The totals under the amount column: the sum, the VAT on it, and both.
const TOTALS: [(&str, &str); 3] = [
    ("Ara toplam", "22.950,00"),
    ("KDV %20", "4.590,00"),
    ("Genel toplam", "27.540,00"),
];

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let body = doc.word_style(sources, FontFile::PlexSans, 10.0)?;
    let bold = doc.word_style(sources, FontFile::PlexSansSemiBold, 10.0)?;
    let mut page = PageText::default();
    let mut y = pdf::A4.1 - 72.0;
    doc.line(
        &mut page,
        &bold.sized(20.0),
        "FATURA",
        (LEFT, y),
        WIDTH,
        Align::Left,
    )?;
    y -= 30.0;
    // The sender's address and the invoice's details are two blocks side by side.
    for (left, right) in [
        ("Moda Gayrimenkul Yönetimi A.Ş.", "Fatura no: MGY2026000418"),
        (
            "Caferağa Mah. Moda Cad. No: 18",
            "Fatura tarihi: 02.11.2026",
        ),
        ("34710 Kadıköy/İstanbul", "Son ödeme tarihi: 16.11.2026"),
        ("Vergi dairesi: Kadıköy, VKN 6120458731", ""),
    ] {
        page.group = Some("sender".to_owned());
        doc.line(&mut page, &body, left, (LEFT, y), WIDTH / 2.0, Align::Left)?;
        if !right.is_empty() {
            page.group = Some("details".to_owned());
            let half = (LEFT + WIDTH / 2.0, y);
            doc.line(&mut page, &body, right, half, WIDTH / 2.0, Align::Right)?;
        }
        y -= 15.0;
    }
    page.group = None;
    y -= 15.0;
    // The recipient's name and address are one block.
    doc.line(
        &mut page,
        &bold,
        "Sayın Ayşe Yılmaz",
        (LEFT, y),
        WIDTH,
        Align::Left,
    )?;
    y -= 15.0;
    doc.line(
        &mut page,
        &body,
        "Bağdat Cad. No: 211 D: 7, 34728 Kadıköy/İstanbul",
        (LEFT, y),
        WIDTH,
        Align::Left,
    )?;
    y -= 34.0;

    page.content.fill_rgb((0xF3, 0xF1, 0xEC));
    page.content.fill_rect(LEFT, y - 6.0, WIDTH, 20.0);
    page.content.fill_rgb((0, 0, 0));
    // The table: its header, the items and the totals under the last two columns.
    for (column, (offset, width, align, title)) in COLUMNS.into_iter().enumerate() {
        page.cell = Some([0, 0, column]);
        doc.line(&mut page, &bold, title, (LEFT + offset, y), width, align)?;
    }
    y -= 22.0;
    for (row, item) in ITEMS.iter().enumerate() {
        for (column, ((offset, width, align, _), cell)) in COLUMNS.iter().zip(item).enumerate() {
            page.cell = Some([0, row + 1, column]);
            doc.line(&mut page, &body, cell, (LEFT + offset, y), *width, *align)?;
        }
        page.content
            .stroke_rgb(RULE)
            .line_width(0.5)
            .line((LEFT, y - 7.0), (LEFT + WIDTH, y - 7.0));
        y -= 20.0;
    }
    page.content.stroke_rgb((0, 0, 0));
    y -= 4.0;
    let (label_x, label_width) = (
        LEFT + COLUMNS[2].0,
        COLUMNS[3].0 + COLUMNS[3].1 - COLUMNS[2].0,
    );
    let (amount_x, amount_width) = (LEFT + COLUMNS[4].0, COLUMNS[4].1);
    for (index, (label, amount)) in TOTALS.iter().enumerate() {
        let style = if index + 1 == TOTALS.len() {
            &bold
        } else {
            &body
        };
        page.cell = Some([0, ITEMS.len() + 1 + index, 3]);
        doc.line(
            &mut page,
            style,
            label,
            (label_x, y),
            label_width,
            Align::Right,
        )?;
        page.cell = Some([0, ITEMS.len() + 1 + index, 4]);
        doc.line(
            &mut page,
            style,
            amount,
            (amount_x, y),
            amount_width,
            Align::Right,
        )?;
        y -= 17.0;
    }
    page.cell = None;
    page.content
        .line_width(0.75)
        .line((amount_x, y + 30.0), (LEFT + WIDTH, y + 30.0));
    y -= 20.0;
    page.group = Some("payment".to_owned());
    for line in [
        "Yalnız yirmi yedi bin beş yüz kırk Türk lirasıdır.",
        "Ödemenizi son ödeme tarihine kadar TR64 0001 2009 4520 0058 0012 34 numaralı hesaba,",
        "açıklamaya fatura numarasını yazarak yapabilirsiniz.",
    ] {
        doc.line(&mut page, &body, line, (LEFT, y), WIDTH, Align::Left)?;
        y -= 15.0;
    }
    page.group = None;

    let (ids, expected) = doc.add_pages(vec![page], pdf::A4);
    let catalog = dictionary! { "Lang" => text("tr-TR"), "OpenAction" => open_first(ids[0]) };
    let bytes = doc.close(
        catalog,
        &info(
            "Fatura MGY2026000418",
            "Moda Gayrimenkul Yönetimi A.Ş.",
            "Kelime işlemci",
            "D:20261102094500+03'00'",
        ),
        "fatura-tr",
        None,
    )?;
    Ok(generated(bytes, expected))
}
