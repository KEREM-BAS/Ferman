//! `payslip-aes256` and its RC4 40, RC4 128 and AES-128 twins: the September 2026 payslip of
//! the design ("Maaş bordrosu Eylül 2026.pdf", `a1-8`), one page set in IBM Plex Sans as a
//! composite font, with invented figures that add up. The AES-256 file's password has ı, ş and
//! ü, so typing it on a keyboard without them fails (`a1-8b`); revisions 2 to 4 cannot carry
//! those letters, so the twins use an ASCII password.

use super::{Doc, generated, info, open_first};
use crate::crypt::{ALL, Method, Security};
use crate::pdf::{self, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, PageText, Style};
use crate::{Expect, Generated, Generator};
use lopdf::dictionary;

/// The AES-256 password, with ı, ş and ü.
pub const PASSWORD_AES256: &str = "Eylül2026maaşı";
/// The password of the RC4 and AES-128 twins.
pub const PASSWORD_LEGACY: &str = "bordro2026";
const OWNER: &str = "bordro-yonetim-2026";

/// AES-256 (revision 6).
pub const PAYSLIP_AES256: Generator = Generator {
    name: "payslip-aes256",
    build: |sources| build(sources, Method::Aes256, "payslip-aes256"),
    expect: Expect::Opens {
        password: Some(PASSWORD_AES256),
    },
};

/// RC4 with a 40-bit key (revision 2).
pub const PAYSLIP_RC4_40: Generator = Generator {
    name: "payslip-rc4-40",
    build: |sources| build(sources, Method::Rc4_40, "payslip-rc4-40"),
    expect: Expect::Opens {
        password: Some(PASSWORD_LEGACY),
    },
};

/// RC4 with a 128-bit key (revision 3).
pub const PAYSLIP_RC4_128: Generator = Generator {
    name: "payslip-rc4-128",
    build: |sources| build(sources, Method::Rc4_128, "payslip-rc4-128"),
    expect: Expect::Opens {
        password: Some(PASSWORD_LEGACY),
    },
};

/// AES-128 (revision 4).
pub const PAYSLIP_AES128: Generator = Generator {
    name: "payslip-aes128",
    build: |sources| build(sources, Method::Aes128, "payslip-aes128"),
    expect: Expect::Opens {
        password: Some(PASSWORD_LEGACY),
    },
};

const LEFT: f64 = 56.0;
const RIGHT: f64 = pdf::A4.0 - 56.0;
const WIDTH: f64 = RIGHT - LEFT;
const ACCENT: (u8, u8, u8) = (0x2A, 0x4D, 0xAF);
const SECONDARY: (u8, u8, u8) = (0x57, 0x53, 0x4C);
const RULE: (u8, u8, u8) = (0xC9, 0xC4, 0xBA);

/// Earnings and deductions: description, quantity, amount in TL.
const EARNINGS: [(&str, &str, &str); 3] = [
    ("Normal çalışma", "30 gün", "85.000,00"),
    ("Fazla mesai (%50 zamlı)", "6 saat", "3.187,50"),
    ("Yemek yardımı", "22 gün", "3.960,00"),
];
const DEDUCTIONS: [(&str, &str, &str); 4] = [
    ("SGK işçi payı", "%14", "12.900,65"),
    ("İşsizlik sigortası işçi payı", "%1", "921,48"),
    ("Gelir vergisi", "%15", "11.748,81"),
    ("Damga vergisi", "%0,759", "699,40"),
];

fn row(
    doc: &mut Doc,
    page: &mut PageText,
    style: &Style,
    y: f64,
    cells: [&str; 3],
) -> Result<(), String> {
    doc.line(page, style, cells[0], (LEFT + 6.0, y), 300.0, Align::Left)?;
    doc.line(page, style, cells[1], (LEFT + 300.0, y), 90.0, Align::Right)?;
    doc.line(
        page,
        style,
        cells[2],
        (RIGHT - 126.0, y),
        120.0,
        Align::Right,
    )?;
    Ok(())
}

fn build(sources: &Sources, method: Method, name: &str) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let regular = doc.composite_style(sources, FontFile::PlexSans, 9.5)?;
    let medium = doc.composite_style(sources, FontFile::PlexSansMedium, 9.5)?;
    let bold = doc.composite_style(sources, FontFile::PlexSansSemiBold, 9.5)?;
    let small = regular.sized(8.0).colored(SECONDARY);
    let mut page = PageText::default();

    page.content
        .fill_rgb(ACCENT)
        .fill_rect(LEFT, 770.0, WIDTH, 3.0)
        .fill_rgb((0, 0, 0));
    doc.line(
        &mut page,
        &bold.sized(16.0),
        "ÜCRET BORDROSU",
        (LEFT, 744.0),
        WIDTH,
        Align::Left,
    )?;
    doc.line(
        &mut page,
        &medium.sized(10.0),
        "Dönem: Eylül 2026 (01.09.2026 – 30.09.2026)",
        (LEFT, 728.0),
        WIDTH,
        Align::Left,
    )?;
    doc.line(
        &mut page,
        &small,
        "Belge No: BRD-2026-09-0187",
        (LEFT, 744.0),
        WIDTH,
        Align::Right,
    )?;

    let blocks: [(&str, [&str; 4]); 2] = [
        (
            "İŞVEREN",
            [
                "Boğaziçi Lojistik A.Ş.",
                "Kozyatağı Mah. Değirmen Sok. No: 9, Kadıköy, İstanbul",
                "SGK işyeri sicil no: 2 5229 01 01 1234567 034",
                "Vergi dairesi: Kozyatağı · VKN 1790456823",
            ],
        ),
        (
            "ÇALIŞAN",
            [
                "Ayşe Yılmaz · Muhasebe Uzmanı",
                "T.C. Kimlik No: 41239876516",
                "Sicil no: 2024-0187 · İşe giriş: 02.09.2024",
                "Ücret türü: Aylık brüt",
            ],
        ),
    ];
    for (index, (heading, lines)) in blocks.iter().enumerate() {
        #[allow(clippy::cast_precision_loss)]
        let x = LEFT + (WIDTH / 2.0 + 8.0) * index as f64;
        let mut label = small.clone();
        label.char_spacing = 0.6;
        doc.line(
            &mut page,
            &label,
            heading,
            (x, 698.0),
            WIDTH / 2.0 - 8.0,
            Align::Left,
        )?;
        let mut y = 684.0;
        for (line_index, line) in lines.iter().enumerate() {
            let style = if line_index == 0 { &medium } else { &regular };
            doc.line(
                &mut page,
                style,
                line,
                (x, y),
                WIDTH / 2.0 - 8.0,
                Align::Left,
            )?;
            y -= 13.0;
        }
    }

    let mut y = 610.0;
    for (title, rows, total_label, total) in [
        ("KAZANÇLAR", &EARNINGS[..], "Brüt toplam", "92.147,50"),
        (
            "KESİNTİLER",
            &DEDUCTIONS[..],
            "Kesinti toplamı",
            "26.270,34",
        ),
    ] {
        page.content
            .fill_rgb((0xF3, 0xF1, 0xEC))
            .fill_rect(LEFT, y - 6.0, WIDTH, 18.0)
            .fill_rgb((0, 0, 0));
        row(
            &mut doc,
            &mut page,
            &bold.sized(8.5),
            y,
            [title, "Miktar", "Tutar (TL)"],
        )?;
        y -= 20.0;
        for (description, quantity, amount) in rows {
            row(
                &mut doc,
                &mut page,
                &regular,
                y,
                [description, quantity, amount],
            )?;
            page.content
                .stroke_rgb(RULE)
                .line_width(0.5)
                .line((LEFT, y - 5.0), (RIGHT, y - 5.0))
                .stroke_rgb((0, 0, 0));
            y -= 17.0;
        }
        row(&mut doc, &mut page, &bold, y, [total_label, "", total])?;
        y -= 34.0;
    }
    page.content
        .fill_rgb(ACCENT)
        .fill_rect(LEFT, y - 10.0, WIDTH, 26.0)
        .fill_rgb((0, 0, 0));
    let white = bold.sized(11.0).colored((0xFF, 0xFF, 0xFF));
    doc.line(
        &mut page,
        &white,
        "NET ÖDENEN",
        (LEFT + 6.0, y),
        300.0,
        Align::Left,
    )?;
    doc.line(
        &mut page,
        &white,
        "65.877,16 TL",
        (RIGHT - 206.0, y),
        200.0,
        Align::Right,
    )?;
    y -= 40.0;
    for line in [
        "Ödeme tarihi: 30.09.2026 · IBAN: TR33 0006 1005 1978 6457 8413 26",
        "Bu bordro, 5510 sayılı Kanun ve 193 sayılı Gelir Vergisi Kanunu uyarınca düzenlenmiştir.",
        "Belge elektronik ortamda oluşturulmuştur; ıslak imza gerektirmez.",
    ] {
        doc.line(&mut page, &small, line, (LEFT, y), WIDTH, Align::Left)?;
        y -= 12.0;
    }

    let (ids, expected) = doc.add_pages(vec![page], pdf::A4);
    let catalog = dictionary! { "Lang" => text("tr-TR"), "OpenAction" => open_first(ids[0]) };
    let security = Security {
        method,
        user: if method == Method::Aes256 {
            PASSWORD_AES256
        } else {
            PASSWORD_LEGACY
        }
        .to_owned(),
        owner: OWNER.to_owned(),
        permissions: ALL,
        seed: name.to_owned(),
    };
    let bytes = doc.close(
        catalog,
        &info(
            "Maaş bordrosu Eylül 2026",
            "Boğaziçi Lojistik A.Ş.",
            "Bordro yazılımı",
            "D:20260930180000+03'00'",
        ),
        name,
        Some(&security),
    )?;
    Ok(generated(bytes, expected))
}
