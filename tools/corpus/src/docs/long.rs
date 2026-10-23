//! The two long files for the performance budgets (ARCHITECTURE §14). Both are over 1 MB, so
//! they are regenerated, not committed, and checked against the SHA-256 of their README row.
//!
//! - **long-500:** a 500-page English maintenance handbook: running text in chapters, set as
//!   Word sets it (simple TrueType fonts, `Tw` justification).
//! - **imar-2400:** a 2,400-page Turkish zoning plan report ("İmar planı açıklama raporu.pdf",
//!   `a1-7`): every page a parcel table and a plan note, so the page count is fixed.

use super::tez::Random;
use super::{Doc, generated, info, open_first, opens};
use crate::pdf::{self, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Flow, Frame, PageText, Paragraph};
use crate::{Generated, Generator};
use lopdf::dictionary;

/// The 500-page handbook.
pub const LONG_500: Generator = Generator {
    name: "long-500",
    build: long_500,
    expect: opens(),
};

/// The 2,400-page zoning report.
pub const IMAR_2400: Generator = Generator {
    name: "imar-2400",
    build: imar_2400,
    expect: opens(),
};

const HANDBOOK: [&str; 20] = [
    "Inspect the roof gutters twice a year, in spring and after the leaves have fallen, and clear any blockage before it causes water to back up under the tiles.",
    "Every boiler in the cooperative is serviced once a year by a registered engineer, who records the flue gas readings in the logbook kept in the plant room.",
    "Residents should report damp patches, mould or condensation as soon as they appear, because early treatment is cheaper and healthier than repair.",
    "The fire doors on each landing must close on their own; a door that is wedged open defeats the purpose of the compartments it protects.",
    "Smoke alarms are tested monthly by the caretaker and the batteries are replaced every year, whether or not the alarm has sounded.",
    "Shared laundry machines are descaled every quarter, and the filters are cleaned weekly to keep drying times short and energy use low.",
    "Before any work on the electrical installation, the circuit is isolated at the distribution board and a lock is fitted to the switch.",
    "Window frames are checked for rot each autumn; soft timber is cut out and replaced, and the frames are repainted every five years.",
    "The water tanks in the loft are inspected annually for corrosion, and their lids are kept closed to stop debris and insects getting in.",
    "Communal areas are cleaned daily, and the cleaning schedule is posted on the noticeboard by the main entrance.",
    "Lifts are inspected every six months under the insurance scheme, and the certificate is displayed inside each car.",
    "Contractors sign in at the office, wear identification at all times and leave their work area safe and tidy at the end of each day.",
    "Drains are rodded where slow flow is reported, and a camera survey is commissioned when the same drain blocks twice in a year.",
    "The garden committee agrees the planting plan each spring, and residents are welcome to join the monthly work mornings.",
    "Bicycle stores are checked for abandoned bicycles every winter; tagged bicycles that are not claimed within a month are donated.",
    "Asbestos surveys are kept on file, and no drilling or sanding takes place in a marked area without the advice of a specialist.",
    "Heating controls in each flat are explained to new residents when they move in, together with the meter readings for their first bill.",
    "Repairs are classed as emergency, urgent or routine, and the target times for each class are published in the residents’ handbook.",
    "Damage caused by a resident is charged at cost, but the cooperative always discusses the charge before it is added to the account.",
    "The maintenance budget is reviewed at the annual meeting, where members vote on the projects for the following year.",
];

fn long_500(sources: &Sources) -> Result<Generated, String> {
    const PAGES: usize = 500;
    let mut doc = Doc::new("1.7");
    let body = doc.word_style(sources, FontFile::PlexSerif, 10.5)?;
    let heading = doc.word_style(sources, FontFile::PlexSansSemiBold, 14.0)?;
    let folio = doc.word_style(sources, FontFile::PlexSans, 8.5)?;
    let frame = Frame {
        x: 72.0,
        top: pdf::A4.1 - 72.0,
        bottom: 80.0,
        width: pdf::A4.0 - 144.0,
    };
    let mut flow = Flow::new(frame);
    let mut random = Random::new(500);
    let mut chapter = 0;
    let mut paragraphs = 0;
    loop {
        if flow.pages.len() > PAGES {
            return Err(format!("{} pages, more than {PAGES}", flow.pages.len()));
        }
        if flow.pages.len() == PAGES && flow.y() - frame.bottom < 200.0 {
            break;
        }
        if paragraphs % 40 == 0 {
            chapter += 1;
            if chapter > 1 && flow.pages.len() < PAGES {
                flow.break_page();
            }
            let title = format!("Chapter {chapter}. Maintenance schedule, part {chapter}");
            flow.paragraph(
                &mut doc.fonts,
                &Paragraph::new(&heading, &title)
                    .aligned(Align::Left)
                    .spaced(0.0, 12.0)
                    .kept(),
            )?;
        }
        let mut sentences = Vec::new();
        while sentences.len() < 5 {
            let sentence = HANDBOOK[random.below(HANDBOOK.len())];
            if !sentences.contains(&sentence) {
                sentences.push(sentence);
            }
        }
        let text = format!(
            "{}.{} {}",
            chapter,
            paragraphs % 40 + 1,
            sentences.join(" ")
        );
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(&body, &text).spaced(0.0, 6.0).leading(1.4),
        )?;
        paragraphs += 1;
    }
    let mut pages = flow.into_pages();
    if pages.len() != PAGES {
        return Err(format!("{} pages, not {PAGES}", pages.len()));
    }
    for (index, page) in pages.iter_mut().enumerate() {
        let label = format!("Maintenance Handbook · page {} of {PAGES}", index + 1);
        doc.line(
            page,
            &folio,
            &label,
            (72.0, 44.0),
            pdf::A4.0 - 144.0,
            Align::Center,
        )?;
    }
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let catalog = dictionary! { "Lang" => text("en-GB"), "OpenAction" => open_first(ids[0]) };
    let bytes = doc.close(
        catalog,
        &info(
            "Maintenance Handbook",
            "Harbour Housing Cooperative",
            "Word processor",
            "D:20260601090000+01'00'",
        ),
        "long-500",
        None,
    )?;
    Ok(generated(bytes, expected))
}

const USES: [(&str, &str, &str, &str); 6] = [
    ("Konut", "0,30", "1,50", "15,50"),
    ("Ticaret", "0,40", "2,00", "21,50"),
    ("Konut + Ticaret", "0,35", "1,80", "18,50"),
    ("Park", "—", "—", "—"),
    ("Eğitim", "0,25", "1,00", "12,50"),
    ("Sağlık", "0,30", "1,20", "12,50"),
];

const NOTES: [&str; 8] = [
    "Plan notu: Bu adada yapılacak yapılarda bodrum katlar, yapı yaklaşma mesafeleri içinde kalmak koşuluyla emsale dâhil değildir.",
    "Plan notu: Parsellerin birleştirilmesi durumunda TAKS ve KAKS değerleri birleşen parsel alanı üzerinden hesaplanır.",
    "Plan notu: Ön bahçe mesafesi 5,00 m, yan bahçe mesafesi 3,00 m, arka bahçe mesafesi H/2 olup 3,00 m’den az olamaz.",
    "Plan notu: Ticaret kullanımlı parsellerde zemin katta en az %60 oranında ticari kullanım zorunludur.",
    "Plan notu: Park alanlarında yalnızca kamuya açık rekreasyon, oyun ve spor alanları düzenlenebilir.",
    "Plan notu: Eğitim alanlarında uygulama, ilgili kurumun görüşü alınarak avan proje onayına göre yapılır.",
    "Plan notu: Kentsel dönüşüm kapsamındaki parsellerde mevcut hak sahiplerinin barınma ihtiyacı uygulama etaplarında gözetilir.",
    "Plan notu: Otopark ihtiyacı, Otopark Yönetmeliği hükümlerine göre parsel içinde karşılanır.",
];

fn imar_2400(sources: &Sources) -> Result<Generated, String> {
    const PAGES: usize = 2400;
    const ROWS: usize = 24;
    let mut doc = Doc::new("1.7");
    let body = doc.word_style(sources, FontFile::PlexSans, 9.0)?;
    let bold = doc.word_style(sources, FontFile::PlexSansSemiBold, 9.0)?;
    let small = body.sized(7.5).colored((0x57, 0x53, 0x4C));
    let left = 56.0;
    let width = pdf::A4.0 - 112.0;
    let columns: [(f64, f64, Align); 7] = [
        (0.0, 50.0, Align::Left),
        (50.0, 50.0, Align::Left),
        (100.0, 80.0, Align::Right),
        (200.0, 120.0, Align::Left),
        (320.0, 50.0, Align::Right),
        (370.0, 50.0, Align::Right),
        (420.0, 63.0, Align::Right),
    ];
    let mut pages = Vec::with_capacity(PAGES);
    let mut random = Random::new(2400);
    for index in 0..PAGES {
        let mut page = PageText::default();
        let top = pdf::A4.1 - 56.0;
        doc.line(
            &mut page,
            &small,
            "İMAR PLANI AÇIKLAMA RAPORU · Kadıköy Merkez 1/1000 Ölçekli Uygulama İmar Planı",
            (left, top),
            width,
            Align::Left,
        )?;
        page.content
            .line_width(0.5)
            .line((left, top - 6.0), (left + width, top - 6.0));
        let block = 1000 + index;
        doc.line(
            &mut page,
            &bold.sized(12.0),
            &format!("Ada {block} — parsel listesi"),
            (left, top - 32.0),
            width,
            Align::Left,
        )?;
        let mut y = top - 58.0;
        for ((x, column_width, align), title) in columns.iter().zip([
            "Ada",
            "Parsel",
            "Alan (m²)",
            "Kullanım",
            "TAKS",
            "KAKS",
            "Hmax (m)",
        ]) {
            doc.line(
                &mut page,
                &bold,
                title,
                (left + x, y),
                *column_width,
                *align,
            )?;
        }
        page.content
            .line_width(0.75)
            .line((left, y - 5.0), (left + width, y - 5.0));
        y -= 19.0;
        for row in 0..ROWS {
            let (use_name, taks, kaks, height) = USES[random.below(USES.len())];
            let area = 180 + random.below(2400);
            let cells = [
                block.to_string(),
                (row + 1).to_string(),
                format!("{},{:02}", thousands(area), random.below(100)),
                use_name.to_owned(),
                taks.to_owned(),
                kaks.to_owned(),
                height.to_owned(),
            ];
            for ((x, column_width, align), cell) in columns.iter().zip(cells.iter()) {
                doc.line(&mut page, &body, cell, (left + x, y), *column_width, *align)?;
            }
            y -= 17.0;
        }
        y -= 12.0;
        let note = NOTES[random.below(NOTES.len())];
        let mut flow = Flow::new(Frame {
            x: left,
            top: y,
            bottom: 60.0,
            width,
        });
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(&body, note)
                .aligned(Align::Left)
                .leading(1.4),
        )?;
        for flowed in flow.into_pages() {
            page.content.append(&flowed.content);
            page.fonts.extend(flowed.fonts);
            page.lines.extend(flowed.lines);
        }
        doc.line(
            &mut page,
            &small,
            &format!("Sayfa {} / {PAGES}", index + 1),
            (left, 36.0),
            width,
            Align::Right,
        )?;
        pages.push(page);
    }
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let catalog = dictionary! { "Lang" => text("tr-TR"), "OpenAction" => open_first(ids[0]) };
    let bytes = doc.close(
        catalog,
        &info(
            "İmar planı açıklama raporu",
            "Kadıköy Belediyesi İmar ve Şehircilik Müdürlüğü",
            "Raporlama yazılımı",
            "D:20260515100000+03'00'",
        ),
        "imar-2400",
        None,
    )?;
    Ok(generated(bytes, expected))
}

/// `value` with dots between thousands, as Turkish writes numbers.
fn thousands(value: usize) -> String {
    let digits = value.to_string();
    let mut out = String::new();
    for (index, c) in digits.chars().enumerate() {
        if index > 0 && (digits.len() - index).is_multiple_of(3) {
            out.push('.');
        }
        out.push(c);
    }
    out
}
