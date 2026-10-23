//! Scanned documents: image-only pages, as a scanner writes them, with no text layer, for
//! scanned-page detection (`a3-11`) and, in phase 3, OCR.
//!
//! - **scan-tr:** "Kira artış bildirimi (tarama).pdf", the rent-increase letter of `a3-11` with
//!   its two enclosures: three A4 pages in IBM Plex Serif, greyscale at 200 dpi on cream paper,
//!   turned 0.6° anticlockwise as the board draws it, Flate with the PNG Up predictor.
//! - **quote-ja-scan:** "見積書_2026-10.pdf", a two-page Japanese quotation for restoring a
//!   flat, in Noto Serif JP, black and white at 300 dpi, turned 0.4° clockwise, one bit per pixel
//!   with Flate.
//!
//! The pages are laid out with the same text code as the other generators and filled by
//! [`crate::raster`]. The text drawn is in this file; the expected text is empty, one form feed
//! between pages.

use super::{Doc, generated, info, open_first, opens};
use crate::kinsoku::breakable;
use crate::pdf::{self, Content, num, text};
use crate::raster::Gray;
use crate::sources::{FontFile, Sources};
use crate::text::{Align, PageText, Paragraph, Style, lay_out};
use crate::{Generated, Generator};
use lopdf::{Dictionary, Stream, dictionary};

/// The Turkish scan.
pub const SCAN_TR: Generator = Generator {
    name: "scan-tr",
    build: scan_tr,
    expect: opens(),
};

/// The Japanese scan.
pub const QUOTE_JA_SCAN: Generator = Generator {
    name: "quote-ja-scan",
    build: quote_ja,
    expect: opens(),
};

/// The sine and cosine of 0.6° and of 0.4°, written out: no transcendental function runs.
const SIN_0_6: f64 = 0.010_471_784_116_245_792;
const COS_0_6: f64 = 0.999_945_169_365_512_1;
const SIN_0_4: f64 = 0.006_981_260_297_961_084;
const COS_0_4: f64 = 0.999_975_630_705_216_6;

/// A page being scanned: a bitmap and the fonts its text is laid out with. Positions are in
/// points from the top-left corner.
struct Sheet {
    gray: Gray,
    /// Pixels per point.
    scale: f64,
    ink: u8,
}

impl Sheet {
    fn new(dpi: f64, paper: u8, ink: u8) -> Self {
        let scale = dpi / 72.0;
        let pixels = |points: f64| {
            let value = (points * scale).round();
            #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
            let value = value as usize;
            value
        };
        Self {
            gray: Gray::new(pixels(pdf::A4.0), pixels(pdf::A4.1), paper),
            scale,
            ink,
        }
    }

    /// Lays out `text` in `style` in `width` points from `x` and fills its lines from `top`.
    /// Returns the position below the last line.
    #[allow(clippy::too_many_arguments)]
    fn paragraph(
        &mut self,
        doc: &mut Doc,
        style: &Style,
        text: &str,
        (x, top): (f64, f64),
        width: f64,
        align: Align,
        leading: f64,
    ) -> Result<f64, String> {
        let lines = lay_out(&mut doc.fonts, &Paragraph::new(style, text).spans, width)?;
        let mut y = top;
        for (index, line) in lines.iter().enumerate() {
            let height = line.size * leading;
            let baseline = y + height - (height - line.size) / 2.0 - line.size * 0.22;
            let last = index + 1 == lines.len();
            for placed in line.placements(x, width, align, last) {
                let Some(face) = doc.fonts.face(placed.font) else {
                    continue;
                };
                let ink = if placed.color == (0, 0, 0) {
                    self.ink
                } else {
                    // Grey text in the original prints lighter.
                    self.ink.saturating_add(40)
                };
                self.gray.fill_glyph(
                    &face,
                    placed.gid,
                    placed.size * self.scale,
                    (placed.x * self.scale, baseline * self.scale),
                    ink,
                );
            }
            y += height;
        }
        Ok(y)
    }

    /// One line of text with its baseline at `baseline`.
    fn line(
        &mut self,
        doc: &mut Doc,
        style: &Style,
        text: &str,
        (x, baseline): (f64, f64),
        width: f64,
        align: Align,
    ) -> Result<(), String> {
        let top = baseline - style.size * 0.78;
        self.paragraph(doc, style, text, (x, top), width, align, 1.0)?;
        Ok(())
    }

    /// A horizontal rule.
    fn rule(&mut self, (x0, y): (f64, f64), x1: f64, thickness: f64) {
        self.gray.fill_rect(
            (x0 * self.scale, (y - thickness / 2.0) * self.scale),
            (x1 * self.scale, (y + thickness / 2.0) * self.scale),
            self.ink,
        );
    }

    /// A vertical rule.
    fn post(&mut self, x: f64, (y0, y1): (f64, f64), thickness: f64) {
        self.gray.fill_rect(
            ((x - thickness / 2.0) * self.scale, y0 * self.scale),
            ((x + thickness / 2.0) * self.scale, y1 * self.scale),
            self.ink,
        );
    }
}

/// The output document: one image per page, drawn over the whole page.
fn image_pages(doc: &mut Doc, images: Vec<Stream>) -> Vec<PageText> {
    images
        .into_iter()
        .map(|image| {
            let id = doc.pdf.add(image);
            let mut page = PageText::default();
            let mut content = Content::new();
            content.op(&format!(
                "q {} 0 0 {} 0 0 cm /Im1 Do Q",
                num(pdf::A4.0),
                num(pdf::A4.1)
            ));
            page.content = content;
            let mut xobjects = Dictionary::new();
            xobjects.set("Im1", id);
            page.resources.set("XObject", xobjects);
            page
        })
        .collect()
}

const TR_LEFT: f64 = 75.0;
const TR_WIDTH: f64 = pdf::A4.0 - 150.0;

/// A table of label and amount rows, ruled, from `top`; returns the position below it.
fn tr_table(
    sheet: &mut Sheet,
    layout: &mut Doc,
    body: &Style,
    bold: &Style,
    rows: &[(&str, &str)],
    top: f64,
) -> Result<f64, String> {
    let height = 24.0;
    let mut y = top;
    sheet.rule((TR_LEFT, y), TR_LEFT + TR_WIDTH, 0.8);
    for (index, (label, amount)) in rows.iter().enumerate() {
        let style = if index == 0 || index + 1 == rows.len() {
            bold
        } else {
            body
        };
        sheet.line(
            layout,
            style,
            label,
            (TR_LEFT + 6.0, y + 16.0),
            300.0,
            Align::Left,
        )?;
        sheet.line(
            layout,
            style,
            amount,
            (TR_LEFT + TR_WIDTH - 156.0, y + 16.0),
            150.0,
            Align::Right,
        )?;
        y += height;
        sheet.rule(
            (TR_LEFT, y),
            TR_LEFT + TR_WIDTH,
            if index == 0 { 0.8 } else { 0.4 },
        );
    }
    Ok(y)
}

fn scan_tr(sources: &Sources) -> Result<Generated, String> {
    let mut layout = Doc::new("1.4");
    let body = layout.composite_style(sources, FontFile::PlexSerif, 10.9)?;
    let bold = layout.composite_style(sources, FontFile::PlexSerifSemiBold, 10.9)?;
    let grey = body.sized(9.4).colored((0x4A, 0x46, 0x3F));
    let paper = 238;
    let ink = 41;
    let mut images = Vec::new();

    // Page 1: the letter.
    let mut sheet = Sheet::new(200.0, paper, ink);
    sheet.line(
        &mut layout,
        &grey,
        "Kaya Gayrimenkul Yönetimi",
        (TR_LEFT, 92.0),
        TR_WIDTH,
        Align::Left,
    )?;
    sheet.line(
        &mut layout,
        &grey,
        "Kadıköy, 06.10.2026",
        (TR_LEFT, 92.0),
        TR_WIDTH,
        Align::Right,
    )?;
    sheet.line(
        &mut layout,
        &bold.sized(13.5),
        "Konu: Kira artış bildirimi",
        (TR_LEFT, 138.0),
        TR_WIDTH,
        Align::Left,
    )?;
    let mut y = 160.0;
    for (paragraph, align) in [
        ("Sayın Ayşe Yılmaz,", Align::Left),
        (
            "01.11.2026 tarihinden itibaren geçerli olmak üzere, Moda Caddesi No: 18 Daire: 5 adresindeki konutun aylık kira bedeli, sözleşmenin 4. maddesi uyarınca 19.500 TL olarak belirlenmiştir.",
            Align::Justify,
        ),
        (
            "Yeni bedel, bir önceki yılın on iki aylık TÜFE ortalaması esas alınarak hesaplanmıştır. Ödemelerin her ayın beşinci gününe kadar aynı hesaba yapılmasını rica ederiz.",
            Align::Justify,
        ),
        ("Saygılarımızla,", Align::Left),
    ] {
        y = sheet.paragraph(
            &mut layout,
            &body,
            paragraph,
            (TR_LEFT, y),
            TR_WIDTH,
            align,
            1.55,
        )?;
        y += 9.0;
    }
    y += 30.0;
    sheet.line(
        &mut layout,
        &body,
        "Mert Kaya",
        (TR_LEFT, y),
        TR_WIDTH,
        Align::Left,
    )?;
    sheet.line(
        &mut layout,
        &grey,
        "Ekler: Kira bedeli hesaplaması (1 sayfa), Ödeme bilgileri (1 sayfa)",
        (TR_LEFT, y + 40.0),
        TR_WIDTH,
        Align::Left,
    )?;
    sheet.rule((TR_LEFT, 772.0), TR_LEFT + TR_WIDTH, 0.4);
    sheet.line(
        &mut layout,
        &grey.sized(8.0),
        "Kaya Gayrimenkul Yönetimi · Moda Cad. No: 22/1 Kadıköy/İstanbul · Tel: 0216 555 01 42",
        (TR_LEFT, 786.0),
        TR_WIDTH,
        Align::Center,
    )?;
    images.push(sheet.gray.turned(-SIN_0_6, COS_0_6, paper).gray_image()?);

    // Page 2: how the new rent was worked out.
    let mut sheet = Sheet::new(200.0, paper, ink);
    sheet.line(
        &mut layout,
        &bold.sized(13.5),
        "Ek-1: Kira bedeli hesaplaması",
        (TR_LEFT, 110.0),
        TR_WIDTH,
        Align::Left,
    )?;
    let mut y = sheet.paragraph(
        &mut layout,
        &body,
        "Kira bedeli, 6098 sayılı Türk Borçlar Kanunu’nun 344. maddesi ve sözleşmenin 4. maddesi uyarınca, bir önceki kira yılının on iki aylık tüketici fiyat endeksi ortalamasındaki değişim oranında artırılmıştır.",
        (TR_LEFT, 130.0),
        TR_WIDTH,
        Align::Justify,
        1.55,
    )?;
    y = tr_table(
        &mut sheet,
        &mut layout,
        &body,
        &bold,
        &[
            ("Kalem", "Tutar"),
            ("Mevcut aylık kira bedeli", "18.500,00 TL"),
            ("On iki aylık TÜFE ortalaması değişimi", "%5,41"),
            ("Artış tutarı (18.500,00 × %5,41)", "1.000,85 TL"),
            ("Yeni aylık kira bedeli (yuvarlanmış)", "19.500,00 TL"),
        ],
        y + 18.0,
    )?;
    sheet.paragraph(
        &mut layout,
        &body,
        "Yeni bedel 01.11.2026 tarihinden başlayarak bir yıl süreyle geçerlidir. Depozito tutarı değişmemiştir.",
        (TR_LEFT, y + 18.0),
        TR_WIDTH,
        Align::Justify,
        1.55,
    )?;
    sheet.line(
        &mut layout,
        &grey,
        "Sayfa 2 / 3",
        (TR_LEFT, 786.0),
        TR_WIDTH,
        Align::Center,
    )?;
    images.push(sheet.gray.turned(-SIN_0_6, COS_0_6, paper).gray_image()?);

    // Page 3: where to pay.
    let mut sheet = Sheet::new(200.0, paper, ink);
    sheet.line(
        &mut layout,
        &bold.sized(13.5),
        "Ek-2: Ödeme bilgileri",
        (TR_LEFT, 110.0),
        TR_WIDTH,
        Align::Left,
    )?;
    let mut y = 140.0;
    for (label, value) in [
        ("Alıcı", "Mert Kaya"),
        ("Banka", "Boğaziçi Bankası, Kadıköy Şubesi"),
        ("IBAN", "TR12 0006 4000 0011 2345 6789 01"),
        ("Açıklama", "Kira bedeli, Moda Caddesi No: 18 Daire: 5"),
        ("Ödeme günü", "Her ayın beşinci günü"),
    ] {
        sheet.line(&mut layout, &bold, label, (TR_LEFT, y), 110.0, Align::Left)?;
        sheet.line(
            &mut layout,
            &body,
            value,
            (TR_LEFT + 110.0, y),
            TR_WIDTH - 110.0,
            Align::Left,
        )?;
        y += 22.0;
    }
    y += 10.0;
    for paragraph in [
        "Ödemenin geç yapılması hâlinde sözleşmenin 7. maddesindeki hükümler uygulanır. Sorularınız için bize 0216 555 01 42 numaralı telefondan ya da bilgi@kayagayrimenkul.example adresinden ulaşabilirsiniz.",
        "Bu bildirim iki nüsha olarak düzenlenmiş, bir nüshası kiracıya teslim edilmiştir.",
    ] {
        y = sheet.paragraph(
            &mut layout,
            &body,
            paragraph,
            (TR_LEFT, y),
            TR_WIDTH,
            Align::Justify,
            1.55,
        )?;
        y += 9.0;
    }
    sheet.line(
        &mut layout,
        &grey,
        "Sayfa 3 / 3",
        (TR_LEFT, 786.0),
        TR_WIDTH,
        Align::Center,
    )?;
    images.push(sheet.gray.turned(-SIN_0_6, COS_0_6, paper).gray_image()?);

    close(
        images,
        "Kira artış bildirimi (tarama)",
        "Tarayıcı",
        "tr-TR",
        "D:20261006112000+03'00'",
        "scan-tr",
    )
}

/// The black-and-white threshold of the Japanese scan: light, as scanners set it for thin
/// strokes, so a one-pixel horizontal of the Mincho face that the turn spreads over two rows
/// stays black.
const THRESHOLD: u8 = 176;

const JA_LEFT: f64 = 60.0;
const JA_WIDTH: f64 = pdf::A4.0 - 120.0;

/// The quotation's items: name, quantity, unit, unit price and amount in yen.
const ITEMS: [(&str, &str, &str, &str, &str); 10] = [
    ("クロス張替え（壁・天井）", "68", "㎡", "1,200", "81,600"),
    ("クッションフロア張替え", "22", "㎡", "3,500", "77,000"),
    ("ハウスクリーニング", "1", "式", "45,000", "45,000"),
    ("エアコン洗浄", "2", "台", "12,000", "24,000"),
    ("網戸張替え", "4", "枚", "3,000", "12,000"),
    ("鍵交換", "1", "式", "18,000", "18,000"),
    ("建具補修", "3", "箇所", "8,000", "24,000"),
    ("キッチン水栓交換", "1", "式", "28,000", "28,000"),
    ("照明器具交換", "3", "台", "9,000", "27,000"),
    ("諸経費", "1", "式", "73,400", "73,400"),
];

/// A ruled table with columns of `widths` from `JA_LEFT`; the first row is the header.
fn ja_table(
    sheet: &mut Sheet,
    layout: &mut Doc,
    body: &Style,
    widths: &[f64],
    aligns: &[Align],
    rows: &[Vec<&str>],
    top: f64,
) -> Result<f64, String> {
    let height = 22.0;
    let mut y = top;
    let right = JA_LEFT + widths.iter().sum::<f64>();
    sheet.rule((JA_LEFT, y), right, 0.8);
    for (index, row) in rows.iter().enumerate() {
        let mut x = JA_LEFT;
        for (column, cell) in row.iter().enumerate() {
            let width = widths.get(column).copied().unwrap_or(60.0);
            let align = if index == 0 {
                Align::Center
            } else {
                aligns.get(column).copied().unwrap_or(Align::Left)
            };
            sheet.line(layout, body, cell, (x + 5.0, y + 15.5), width - 10.0, align)?;
            x += width;
        }
        y += height;
        sheet.rule((JA_LEFT, y), right, if index == 0 { 0.8 } else { 0.4 });
    }
    let mut x = JA_LEFT;
    sheet.post(x, (top, y), 0.6);
    for width in widths {
        x += width;
        sheet.post(x, (top, y), 0.6);
    }
    Ok(y)
}

fn quote_ja(sources: &Sources) -> Result<Generated, String> {
    let mut layout = Doc::new("1.4");
    let body = layout.composite_style(sources, FontFile::NotoSerifJp, 10.0)?;
    let bold = layout.composite_style(sources, FontFile::NotoSerifJpSemiBold, 10.0)?;
    let paper = 250;
    let ink = 20;
    let mut images = Vec::new();

    // Page 1: the quotation.
    let mut sheet = Sheet::new(300.0, paper, ink);
    let mut title = bold.sized(22.0);
    title.char_spacing = 12.0;
    sheet.line(
        &mut layout,
        &title,
        "御見積書",
        (JA_LEFT, 96.0),
        JA_WIDTH,
        Align::Center,
    )?;
    sheet.line(
        &mut layout,
        &body,
        "見積番号　Q-2026-0918",
        (JA_LEFT, 128.0),
        JA_WIDTH,
        Align::Right,
    )?;
    sheet.line(
        &mut layout,
        &body,
        "発行日　2026年9月18日",
        (JA_LEFT, 144.0),
        JA_WIDTH,
        Align::Right,
    )?;
    sheet.line(
        &mut layout,
        &bold.sized(13.0),
        "株式会社モダ不動産　管理部　御中",
        (JA_LEFT, 150.0),
        280.0,
        Align::Left,
    )?;
    sheet.rule((JA_LEFT, 156.0), JA_LEFT + 280.0, 0.8);
    sheet.line(
        &mut layout,
        &body,
        "下記のとおりお見積り申し上げます。",
        (JA_LEFT, 182.0),
        280.0,
        Align::Left,
    )?;
    sheet.line(
        &mut layout,
        &body,
        "件名：賃貸住宅　原状回復工事（505号室）",
        (JA_LEFT, 202.0),
        280.0,
        Align::Left,
    )?;
    sheet.line(
        &mut layout,
        &bold.sized(15.0),
        "御見積金額　¥451,000（税込）",
        (JA_LEFT, 236.0),
        280.0,
        Align::Left,
    )?;
    sheet.rule((JA_LEFT, 243.0), JA_LEFT + 280.0, 1.2);
    let sender_x = JA_LEFT + JA_WIDTH - 190.0;
    let mut y = 176.0;
    for (index, line) in [
        "有限会社みどり内装",
        "東京都杉並区天沼三丁目",
        "TEL 03-5555-0198",
        "担当　佐藤",
    ]
    .iter()
    .enumerate()
    {
        let style = if index == 0 { &bold } else { &body };
        sheet.line(&mut layout, style, line, (sender_x, y), 190.0, Align::Left)?;
        y += 16.0;
    }
    let mut rows: Vec<Vec<&str>> = vec![vec!["品名", "数量", "単位", "単価", "金額"]];
    for (name, quantity, unit, price, amount) in ITEMS {
        rows.push(vec![name, quantity, unit, price, amount]);
    }
    let widths = [205.0, 50.0, 50.0, 85.0, 85.276];
    let aligns = [
        Align::Left,
        Align::Right,
        Align::Center,
        Align::Right,
        Align::Right,
    ];
    let y = ja_table(
        &mut sheet,
        &mut layout,
        &body,
        &widths,
        &aligns,
        &rows,
        270.0,
    )?;
    let mut y = y + 8.0;
    for (label, amount) in [
        ("小計", "410,000"),
        ("消費税（10%）", "41,000"),
        ("合計", "451,000"),
    ] {
        let style = if label == "合計" { &bold } else { &body };
        sheet.line(
            &mut layout,
            style,
            label,
            (JA_LEFT + 310.0, y + 15.0),
            90.0,
            Align::Left,
        )?;
        sheet.line(
            &mut layout,
            style,
            amount,
            (JA_LEFT + 395.0, y + 15.0),
            80.276,
            Align::Right,
        )?;
        y += 20.0;
        sheet.rule((JA_LEFT + 305.0, y), JA_LEFT + JA_WIDTH, 0.4);
    }
    sheet.line(
        &mut layout,
        &body,
        "1 / 2",
        (JA_LEFT, 800.0),
        JA_WIDTH,
        Align::Center,
    )?;
    images.push(
        sheet
            .gray
            .turned(SIN_0_4, COS_0_4, paper)
            .bilevel_image(THRESHOLD)?,
    );

    // Page 2: the notes and the work by room.
    let mut sheet = Sheet::new(300.0, paper, ink);
    sheet.line(
        &mut layout,
        &bold.sized(13.0),
        "備考",
        (JA_LEFT, 96.0),
        JA_WIDTH,
        Align::Left,
    )?;
    let mut y = 108.0;
    for note in [
        "一、本見積書の有効期限は、発行日から三十日間です。",
        "二、工事期間は、ご発注後およそ五日間を予定しております。入居者様の退去後に着工いたします。",
        "三、既存の設備に想定外の損傷が見つかった場合は、別途お見積りのうえ、ご相談させていただきます。",
        "四、お支払いは、工事完了後の月末締め、翌月末までに下記の口座へお振り込みください。振込手数料は貴社にてご負担をお願いいたします。",
    ] {
        y = sheet.paragraph(
            &mut layout,
            &body,
            &breakable(note),
            (JA_LEFT, y),
            JA_WIDTH,
            Align::Left,
            1.8,
        )?;
        y += 4.0;
    }
    y += 10.0;
    for line in [
        "振込先　やまなみ銀行　天沼支店　普通　1234567",
        "口座名義　ユ）ミドリナイソウ",
    ] {
        sheet.line(
            &mut layout,
            &body,
            line,
            (JA_LEFT + 20.0, y + 12.0),
            JA_WIDTH,
            Align::Left,
        )?;
        y += 18.0;
    }
    sheet.line(
        &mut layout,
        &bold.sized(13.0),
        "工事内容明細",
        (JA_LEFT, y + 40.0),
        JA_WIDTH,
        Align::Left,
    )?;
    let rows: Vec<Vec<&str>> = vec![
        vec!["箇所", "作業内容"],
        vec!["洋室（6帖）", "クロス張替え、照明器具交換"],
        vec![
            "リビング・ダイニング",
            "クロス張替え、クッションフロア張替え、エアコン洗浄",
        ],
        vec!["キッチン", "水栓交換、レンジフード清掃"],
        vec!["浴室・洗面所", "ハウスクリーニング"],
        vec!["玄関", "鍵交換、建具補修"],
        vec!["バルコニー", "網戸張替え"],
    ];
    let y = ja_table(
        &mut sheet,
        &mut layout,
        &body,
        &[150.0, 325.276],
        &[Align::Left, Align::Left],
        &rows,
        y + 54.0,
    )?;
    sheet.line(
        &mut layout,
        &body,
        "以上",
        (JA_LEFT, y + 30.0),
        JA_WIDTH,
        Align::Right,
    )?;
    sheet.line(
        &mut layout,
        &body,
        "2 / 2",
        (JA_LEFT, 800.0),
        JA_WIDTH,
        Align::Center,
    )?;
    images.push(
        sheet
            .gray
            .turned(SIN_0_4, COS_0_4, paper)
            .bilevel_image(THRESHOLD)?,
    );

    close(
        images,
        "見積書_2026-10",
        "スキャナー",
        "ja-JP",
        "D:20260918143000+09'00'",
        "quote-ja-scan",
    )
}

/// The file: one page per image, no fonts and no text.
fn close(
    images: Vec<Stream>,
    title: &str,
    creator: &str,
    lang: &str,
    created: &str,
    seed: &str,
) -> Result<Generated, String> {
    let mut doc = Doc::new("1.4");
    let pages = image_pages(&mut doc, images);
    let count = pages.len();
    let (ids, _) = doc.add_pages(pages, pdf::A4);
    let catalog = dictionary! { "Lang" => text(lang), "OpenAction" => open_first(ids[0]) };
    let bytes = doc.close(catalog, &info(title, "", creator, created), seed, None)?;
    Ok(generated(bytes, "\u{c}".repeat(count.saturating_sub(1))))
}
