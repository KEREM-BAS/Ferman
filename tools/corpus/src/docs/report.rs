//! `report-ar`: the 12-page Arabic annual report of `a2-15` ("التقرير السنوي 2025.pdf") of an
//! invented housing cooperative in Amman, in IBM Plex Sans Arabic, the board's second font, as
//! composite subsets. `/ViewerPreferences /Direction /R2L` puts page 1 on the right of a spread
//! (G32).
//!
//! Every line is written in visual order, as producers write Arabic: shaped right to left, with
//! the runs the bidi algorithm makes left to right (numbers, an IBAN, "ISO 9001", an e-mail
//! address) kept in their own order inside it. The text has lam-alef ligatures, marks on their
//! base letters (shadda, tanween, damma), mirrored parentheses, a conjunction joined to a number
//! ("و2,318"), Western digits in the text and Arabic-Indic digits in the page numbers. The
//! expected text is in logical order.

use super::{Doc, generated, info, open_first};
use crate::pdf::{self, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Flow, Frame, Paragraph, Style};
use crate::{Expect, Generated, Generator};
use lopdf::dictionary;

/// The Arabic report.
pub const REPORT_AR: Generator = Generator {
    name: "report-ar",
    build,
    expect: Expect::OpensUnordered,
};

const LEFT: f64 = 72.0;
const WIDTH: f64 = pdf::A4.0 - 144.0;
const SECONDARY: (u8, u8, u8) = (0x57, 0x53, 0x4C);
const RULE: (u8, u8, u8) = (0xC9, 0xC4, 0xBA);
const SHADE: (u8, u8, u8) = (0xF3, 0xF1, 0xEC);
const COOPERATIVE: &str = "جمعية الإسكان التعاوني في عمّان";
const TITLE: &str = "التقرير السنوي 2025";

/// A section: its heading and its blocks, on pages of its own.
enum Block {
    /// A paragraph.
    Text(&'static str),
    /// A subheading.
    Heading(&'static str),
    /// A table: its column widths from the right, which columns hold numbers, and its rows (the
    /// first is the header, the last is bold when `total`).
    Table {
        widths: &'static [f64],
        numbers: &'static [bool],
        rows: &'static [&'static [&'static str]],
        total: bool,
    },
    /// The signature of the chairman's word, on the left.
    Signature(&'static [&'static str]),
    /// The table of contents.
    Contents,
    /// A page break inside the section.
    Break,
}

const CONTENTS: [(&str, &str); 8] = [
    ("كلمة رئيس مجلس الإدارة", "2"),
    ("نبذة عن الجمعية", "4"),
    ("الأعضاء", "5"),
    ("مشاريع الإسكان", "6"),
    ("التمويل والتسجيل", "8"),
    ("الوضع المالي", "9"),
    ("خطة عام 2026", "11"),
    ("معلومات الاتصال", "12"),
];

const SECTIONS: [(&str, &[Block]); 9] = [
    (
        "كلمة رئيس مجلس الإدارة",
        &[
            Block::Text(
                "شهد عام 2025 تسليم 214 وحدة سكنية جديدة لأعضاء الجمعية، وهو أعلى عدد منذ تأسيسها. وواصلنا العمل على خفض كلفة التمويل وتسريع إجراءات التسجيل.",
            ),
            Block::Text(
                "وانضم إلى الجمعية خلال العام 312 عضوًا جديدًا، فبلغ عدد الأعضاء في نهاية السنة 3,480 عضوًا. ويعكس هذا النمو ثقة الأسر بالعمل التعاوني طريقًا إلى السكن اللائق.",
            ),
            Block::Text(
                "وقد حققت الجمعية فائضًا قدره 2,156,500 دينار، يُخصص جزء منه لتمويل مشروعها الجديد في مأدبا الذي يبدأ العمل فيه عام 2026.",
            ),
            Block::Text("نشكر الأعضاء والعاملين على ثقتهم، ونتطلع إلى عام جديد من العمل المشترك."),
            Block::Signature(&["م. سامر الحداد", "رئيس مجلس الإدارة"]),
        ],
    ),
    ("المحتويات", &[Block::Contents]),
    (
        "نبذة عن الجمعية",
        &[
            Block::Text(
                "تأسست جمعية الإسكان التعاوني في عمّان عام 1998 بمبادرة من 45 عضوًا مؤسسًا، بهدف توفير مساكن ملائمة بكلفة معقولة لأسر الدخل المتوسط.",
            ),
            Block::Text(
                "تعمل الجمعية وفق مبدأ التعاون: يساهم الأعضاء في رأس المال، وتتولى الجمعية شراء الأراضي والتعاقد على البناء، ثم توزيع الوحدات على الأعضاء وفق أولوية التسجيل.",
            ),
            Block::Text(
                "يدير الجمعية مجلس إدارة من سبعة أعضاء تنتخبهم الهيئة العامة لمدة أربع سنوات، ويعمل فيها 38 موظفًا في المكتب الرئيسي وفي مواقع المشاريع.",
            ),
            Block::Heading("رسالتنا"),
            Block::Text(
                "أن يجد كل عضو مسكنًا لائقًا بكلفة يستطيع تحملها، في حي تتوافر فيه المدارس والمواصلات والخدمات الأساسية.",
            ),
            Block::Heading("قيمنا"),
            Block::Text(
                "الشفافية في عرض الحسابات على الأعضاء، والعدالة في توزيع الوحدات، والجودة في البناء، والمسؤولية تجاه البيئة والمجتمع المحلي.",
            ),
        ],
    ),
    (
        "الأعضاء",
        &[
            Block::Text(
                "بلغ عدد أعضاء الجمعية في 31 كانون الأول 2025 ما مجموعه 3,480 عضوًا، منهم 1,162 عضوًا تسلموا وحداتهم، و2,318 عضوًا على قائمة الانتظار.",
            ),
            Block::Text("ويبين الجدول التالي تطور عدد الأعضاء خلال السنوات الخمس الأخيرة."),
            Block::Table {
                widths: &[90.0, 120.0, 100.0, 141.276],
                numbers: &[true, true, true, true],
                rows: &[
                    &["السنة", "الأعضاء الجدد", "المنسحبون", "مجموع الأعضاء"],
                    &["2021", "210", "25", "2,580"],
                    &["2022", "236", "26", "2,790"],
                    &["2023", "198", "33", "2,955"],
                    &["2024", "245", "8", "3,192"],
                    &["2025", "312", "24", "3,480"],
                ],
                total: false,
            },
            Block::Text(
                "وارتفع متوسط مدة الانتظار من 50 شهرًا إلى 55 شهرًا بسبب زيادة الطلب، ونعمل على خفضها بطرح مشاريع جديدة.",
            ),
        ],
    ),
    (
        "مشاريع الإسكان",
        &[
            Block::Text(
                "نفذت الجمعية خلال عام 2025 أربعة مشاريع في عمّان والزرقاء، اكتمل ثلاثة منها وسُلمت وحداتها إلى الأعضاء، ويستمر العمل في المشروع الرابع.",
            ),
            Block::Table {
                widths: &[130.0, 90.0, 75.0, 75.0, 81.276],
                numbers: &[false, false, true, true, true],
                rows: &[
                    &["المشروع", "المدينة", "الوحدات", "الإنجاز", "التسليم"],
                    &["حي الياسمين", "عمّان", "96", "100%", "2025"],
                    &["ضاحية الرشيد", "عمّان", "64", "100%", "2025"],
                    &["الهاشمية", "الزرقاء", "54", "100%", "2025"],
                    &["أبراج الجبيهة", "عمّان", "120", "65%", "2026"],
                    &["المجموع", "", "334", "", ""],
                ],
                total: true,
            },
            Block::Text(
                "بلغ مجموع الوحدات المسلمة 214 وحدة، تتراوح مساحاتها بين 110 و165 مترًا مربعًا، وبلغ متوسط كلفة المتر المربع 285 دينارًا.",
            ),
            Block::Break,
            Block::Heading("أبراج الجبيهة"),
            Block::Text(
                "يضم مشروع أبراج الجبيهة ثلاثة مبانٍ من تسعة طوابق، فيها 120 وحدة سكنية ومواقف للسيارات وحديقة مشتركة. وبلغت نسبة الإنجاز في نهاية العام 65%، ويتوقع تسليم الوحدات في الربع الثالث من عام 2026.",
            ),
            Block::Text(
                "وتطبق الشركة المنفذة نظام إدارة الجودة ISO 9001 في جميع مراحل العمل، ويشرف مهندسو الجمعية على الموقع يوميًا.",
            ),
            Block::Text(
                "واعتمدت الجمعية في هذا المشروع عزلًا حراريًا للجدران والأسطح، وسخانات شمسية للمياه في جميع الوحدات، مما يخفض استهلاك الطاقة بنحو 30%.",
            ),
        ],
    ),
    (
        "التمويل والتسجيل",
        &[
            Block::Text(
                "موّلت الجمعية مشاريعها من مساهمات الأعضاء ومن قروض ميسرة من ثلاثة بنوك محلية بلغ مجموعها 4,750,000 دينار. وانخفض متوسط سعر الفائدة على قروض الأعضاء من 7.25% إلى 6.4%.",
            ),
            Block::Text(
                "يسدد العضو قرضه على أقساط شهرية لمدة تصل إلى 20 سنة، ولا يتجاوز القسط 35% من دخل الأسرة.",
            ),
            Block::Text(
                "وفي مجال التسجيل، تقلصت مدة نقل ملكية الوحدة إلى اسم العضو من 90 يومًا إلى 35 يومًا، بعد ربط الجمعية بنظام التسجيل الإلكتروني لدى الجهات المختصة.",
            ),
            Block::Text(
                "ويمكن للأعضاء الآن متابعة طلباتهم ودفع أقساطهم عبر الموقع الإلكتروني للجمعية.",
            ),
        ],
    ),
    (
        "الوضع المالي",
        &[
            Block::Text(
                "تعرض البيانات التالية إيرادات الجمعية ومصاريفها لعامي 2024 و2025 بالدينار الأردني. وقد دققت البيانات المالية شركة تدقيق مستقلة، وأبدت رأيًا غير متحفظ.",
            ),
            Block::Table {
                widths: &[211.276, 120.0, 120.0],
                numbers: &[false, true, true],
                rows: &[
                    &["البند", "2024", "2025"],
                    &["مساهمات الأعضاء", "2,180,400", "2,512,900"],
                    &["إيرادات بيع الوحدات", "9,846,000", "11,342,500"],
                    &["إيرادات أخرى", "164,300", "198,700"],
                    &["مجموع الإيرادات", "12,190,700", "14,054,100"],
                    &["تكاليف البناء", "8,912,600", "10,207,300"],
                    &["المصاريف الإدارية", "1,045,200", "1,118,400"],
                    &["تكاليف التمويل", "612,800", "571,900"],
                    &["مجموع المصاريف", "10,570,600", "11,897,600"],
                    &["الفائض", "1,620,100", "2,156,500"],
                ],
                total: true,
            },
            Block::Text(
                "ارتفع مجموع الإيرادات بنسبة 15.3% نتيجة زيادة عدد الوحدات المسلمة، بينما ارتفعت المصاريف بنسبة 12.6%.",
            ),
            Block::Break,
            Block::Heading("حساب الجمعية"),
            Block::Text(
                "تودع مساهمات الأعضاء وأقساطهم في حساب الجمعية، ولا تقبل الجمعية أي دفعات نقدية في مكاتبها.",
            ),
            Block::Text("رقم الحساب الدولي (IBAN): JO14 AHCB 0010 0000 0000 0131 0012 34"),
            Block::Text("اسم المستفيد: جمعية الإسكان التعاوني في عمّان"),
            Block::Text("الرقم الضريبي للجمعية: 10458732"),
            Block::Text("يرجى كتابة رقم العضوية في خانة البيان عند كل تحويل، مثل: 2025/0418."),
        ],
    ),
    (
        "خطة عام 2026",
        &[
            Block::Text("حدد مجلس الإدارة الأهداف التالية للعام المقبل:"),
            Block::Text("1. تسليم وحدات أبراج الجبيهة (120 وحدة) قبل نهاية الربع الثالث."),
            Block::Text("2. إطلاق مشروع جديد في مأدبا يضم 80 وحدة على أرض مساحتها 9,400 متر مربع."),
            Block::Text("3. خفض مدة نقل الملكية إلى 21 يومًا."),
            Block::Text("4. فتح باب التسجيل الإلكتروني للأعضاء الجدد بالكامل."),
            Block::Text(
                "5. رفع نسبة الوحدات المزودة بالطاقة الشمسية إلى 100% في المشاريع الجديدة.",
            ),
            Block::Text("وتقدر الموازنة التقديرية لعام 2026 بمبلغ 15,800,000 دينار."),
        ],
    ),
    (
        "معلومات الاتصال",
        &[
            Block::Text("العنوان: عمّان، شارع الياسمين، مبنى رقم 14، الطابق الثالث"),
            Block::Text("الهاتف: 065550142"),
            Block::Text("الفاكس: 065550143"),
            Block::Text("البريد الإلكتروني: info@iskan-amman.example"),
            Block::Text("الموقع الإلكتروني: www.iskan-amman.example"),
            Block::Text("ساعات العمل: من الأحد إلى الخميس، 8:00 - 15:30"),
            Block::Text(
                "صدر هذا التقرير عن مجلس إدارة جمعية الإسكان التعاوني في عمّان، ويعرض على الهيئة العامة في اجتماعها السنوي يوم 28 نيسان 2026.",
            ),
        ],
    ),
];

/// `number` in Arabic-Indic digits, as the page numbers are.
fn arabic_indic(number: usize) -> String {
    number
        .to_string()
        .chars()
        .map(|digit| {
            digit
                .to_digit(10)
                .and_then(|value| char::from_u32(0x0660 + value))
                .unwrap_or(digit)
        })
        .collect()
}

/// Draws a table at the flow's position, its columns from the right edge.
#[allow(clippy::too_many_arguments)]
fn table(
    doc: &mut Doc,
    flow: &mut Flow,
    body: &Style,
    bold: &Style,
    widths: &[f64],
    numbers: &[bool],
    rows: &[&[&str]],
    total: bool,
) -> Result<(), String> {
    let height = 22.0;
    let mut y = flow.y() - 6.0;
    for (index, row) in rows.iter().enumerate() {
        let header = index == 0;
        let bold_row = header || (total && index + 1 == rows.len());
        let page = flow.page();
        if header {
            page.content
                .fill_rgb(SHADE)
                .fill_rect(LEFT, y - height, WIDTH, height)
                .fill_rgb((0, 0, 0));
        }
        let style = if bold_row { bold } else { body };
        let mut right = LEFT + WIDTH;
        for (column, cell) in row.iter().enumerate() {
            let width = widths.get(column).copied().unwrap_or(80.0);
            let x = right - width;
            if !cell.is_empty() {
                let number = numbers.get(column).copied().unwrap_or(false);
                let align = if number { Align::Center } else { Align::Right };
                let (x, width) = if number {
                    (x, width)
                } else {
                    (x + 6.0, width - 12.0)
                };
                doc.line(page, style, cell, (x, y - 15.0), width, align)?;
            }
            right = x;
        }
        page.content
            .stroke_rgb(RULE)
            .line_width(0.5)
            .line((LEFT, y - height), (LEFT + WIDTH, y - height))
            .stroke_rgb((0, 0, 0));
        y -= height;
    }
    flow.skip(flow.y() - y + 14.0);
    Ok(())
}

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let body = doc
        .composite_style(sources, FontFile::PlexSansArabic, 12.0)?
        .right_to_left();
    let bold = doc
        .composite_style(sources, FontFile::PlexSansArabicSemiBold, 12.0)?
        .right_to_left();
    let small = body.sized(9.0).colored(SECONDARY);
    let frame = Frame {
        x: LEFT,
        top: pdf::A4.1 - 96.0,
        bottom: 84.0,
        width: WIDTH,
    };

    // Page 1: the cover.
    let mut flow = Flow::new(frame);
    doc.line(
        flow.page(),
        &bold.sized(13.0).colored(SECONDARY),
        COOPERATIVE,
        (LEFT, 700.0),
        WIDTH,
        Align::Center,
    )?;
    doc.line(
        flow.page(),
        &bold.sized(32.0),
        TITLE,
        (LEFT, 520.0),
        WIDTH,
        Align::Center,
    )?;
    flow.skip(frame.top - 480.0);
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(
            &body.sized(13.0),
            "يعرض هذا التقرير أعمال الجمعية خلال عام 2025، ومشاريع الإسكان التي أُنجزت، والوضع المالي في نهاية السنة.",
        )
        .aligned(Align::Center)
        .leading(1.9),
    )?;
    doc.line(
        flow.page(),
        &small.sized(11.0),
        "عمّان، آذار 2026",
        (LEFT, 120.0),
        WIDTH,
        Align::Center,
    )?;

    // Pages 2 to 12: the sections, each from a new page.
    for (heading, blocks) in &SECTIONS {
        flow.break_page();
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(&bold.sized(18.0), heading)
                .aligned(Align::Right)
                .leading(1.8)
                .spaced(0.0, 12.0),
        )?;
        for block in *blocks {
            match block {
                Block::Text(paragraph) => {
                    flow.paragraph(
                        &mut doc.fonts,
                        &Paragraph::new(&body, paragraph)
                            .leading(1.9)
                            .spaced(0.0, 8.0),
                    )?;
                }
                Block::Heading(subheading) => {
                    flow.paragraph(
                        &mut doc.fonts,
                        &Paragraph::new(&bold.sized(14.0), subheading)
                            .aligned(Align::Right)
                            .leading(1.8)
                            .spaced(10.0, 4.0),
                    )?;
                }
                Block::Table {
                    widths,
                    numbers,
                    rows,
                    total,
                } => table(
                    &mut doc, &mut flow, &body, &bold, widths, numbers, rows, *total,
                )?,
                Block::Signature(lines) => {
                    flow.skip(18.0);
                    for line in *lines {
                        flow.paragraph(
                            &mut doc.fonts,
                            &Paragraph::new(&body, line)
                                .aligned(Align::Left)
                                .leading(1.7),
                        )?;
                    }
                }
                Block::Contents => {
                    let mut y = flow.y() - 10.0;
                    for (title, page_number) in CONTENTS {
                        let page = flow.page();
                        doc.line(page, &body, title, (LEFT, y), WIDTH - 40.0, Align::Right)?;
                        doc.line(page, &body, page_number, (LEFT, y), 30.0, Align::Left)?;
                        page.content
                            .stroke_rgb(RULE)
                            .line_width(0.5)
                            .line((LEFT, y - 9.0), (LEFT + WIDTH, y - 9.0))
                            .stroke_rgb((0, 0, 0));
                        y -= 30.0;
                    }
                    flow.skip(flow.y() - y);
                }
                Block::Break => flow.break_page(),
            }
        }
    }

    // The running head and the page number of every page but the cover.
    let mut pages = flow.into_pages();
    for (index, page) in pages.iter_mut().enumerate().skip(1) {
        doc.line(
            page,
            &small,
            COOPERATIVE,
            (LEFT, pdf::A4.1 - 56.0),
            WIDTH,
            Align::Right,
        )?;
        doc.line(
            page,
            &small,
            TITLE,
            (LEFT, pdf::A4.1 - 56.0),
            WIDTH,
            Align::Left,
        )?;
        page.content
            .stroke_rgb(RULE)
            .line_width(0.5)
            .line((LEFT, pdf::A4.1 - 64.0), (LEFT + WIDTH, pdf::A4.1 - 64.0))
            .stroke_rgb((0, 0, 0));
        doc.line(
            page,
            &small.sized(10.0),
            &arabic_indic(index + 1),
            (LEFT, 48.0),
            WIDTH,
            Align::Center,
        )?;
    }
    if pages.len() != 12 {
        return Err(format!("the report has {} pages, not 12", pages.len()));
    }
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let catalog = dictionary! {
        "Lang" => text("ar-JO"),
        "ViewerPreferences" => dictionary! { "Direction" => "R2L" },
        "OpenAction" => open_first(ids[0]),
    };
    let bytes = doc.close(
        catalog,
        &info(TITLE, COOPERATIVE, "معالج نصوص", "D:20260315100000+03'00'"),
        "report-ar",
        None,
    )?;
    Ok(generated(bytes, expected))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn page_numbers_are_arabic_indic() {
        assert_eq!(arabic_indic(12), "١٢");
    }
}
