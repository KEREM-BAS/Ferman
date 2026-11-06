//! One-page notices in the scripts of the edit corpus (ROADMAP E10 to E12), each a title and three
//! paragraphs in one composite `Identity-H` font, shaped:
//!
//! - `fa-zwnj`: Persian in IBM Plex Sans Arabic, which covers Persian, with zero width
//!   non-joiners (U+200C) inside words ("می‌رساند"). The shaper keeps the letters before them
//!   unjoined; the non-joiner itself is not drawn, as producers write it, so the expected text, as
//!   a reader extracts it, has none (E10).
//! - `he-para`: Hebrew in IBM Plex Sans Hebrew, right to left with a number inside (E11).
//! - `zh-hans`, `zh-hant`, `ko-para`: Simplified Chinese, Traditional Chinese and Korean in Noto
//!   Sans SC, TC and KR at `wght` 400, horizontal (E12). Chinese breaks between characters with
//!   the kinsoku rules; Korean breaks at spaces.
//! - `ja-para`: Japanese in Noto Serif JP at `wght` 400, horizontal (E12), broken as Chinese is.

use super::{Doc, generated, info, open_first, opens};
use crate::kinsoku::breakable;
use crate::pdf::{self, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Expected, Flow, Frame, Paragraph};
use crate::{Expect, Generated, Generator};
use lopdf::dictionary;

/// The Persian notice.
pub const FA_ZWNJ: Generator = Generator {
    name: "fa-zwnj",
    build: fa,
    expect: Expect::OpensUnordered,
};

/// The Hebrew notice.
pub const HE_PARA: Generator = Generator {
    name: "he-para",
    build: he,
    expect: Expect::OpensUnordered,
};

/// The Simplified Chinese notice.
pub const ZH_HANS: Generator = Generator {
    name: "zh-hans",
    build: zh_hans,
    expect: opens(),
};

/// The Traditional Chinese notice.
pub const ZH_HANT: Generator = Generator {
    name: "zh-hant",
    build: zh_hant,
    expect: opens(),
};

/// The Korean notice.
pub const KO_PARA: Generator = Generator {
    name: "ko-para",
    build: ko,
    expect: opens(),
};

/// The Japanese notice.
pub const JA_PARA: Generator = Generator {
    name: "ja-para",
    build: ja,
    expect: opens(),
};

const ZWNJ: char = '\u{200C}';

/// A notice: its language, font, whether it reads right to left, whether its lines break
/// between characters, title and paragraphs, and the information dictionary's title, author and
/// date.
struct Notice {
    name: &'static str,
    lang: &'static str,
    font: FontFile,
    rtl: bool,
    cjk: bool,
    title: &'static str,
    paragraphs: [&'static str; 3],
    author: &'static str,
    created: &'static str,
}

fn notice(sources: &Sources, notice: &Notice) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let mut body = doc.composite_style(sources, notice.font, 12.0)?;
    if notice.rtl {
        body = body.right_to_left();
    }
    let align = if notice.rtl {
        Align::Right
    } else {
        Align::Left
    };
    let mut flow = Flow::new(Frame {
        x: 72.0,
        top: pdf::A4.1 - 80.0,
        bottom: 80.0,
        width: pdf::A4.0 - 144.0,
    });
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(&body.sized(18.0), notice.title)
            .aligned(align)
            .spaced(0.0, 18.0),
    )?;
    for paragraph in notice.paragraphs {
        let paragraph = if notice.cjk {
            breakable(paragraph)
        } else {
            paragraph.to_owned()
        };
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(&body, &paragraph)
                .spaced(0.0, 10.0)
                .leading(1.7),
        )?;
    }
    let (ids, expected) = doc.add_pages(flow.into_pages(), pdf::A4);
    let mut catalog =
        dictionary! { "Lang" => text(notice.lang), "OpenAction" => open_first(ids[0]) };
    if notice.rtl {
        catalog.set("ViewerPreferences", dictionary! { "Direction" => "R2L" });
    }
    let bytes = doc.close(
        catalog,
        &info(
            notice.title,
            notice.author,
            "Word processor",
            notice.created,
        ),
        notice.name,
        None,
    )?;
    // ZWNJ draws no glyph, so a reader finds none.
    let expected = Expected {
        text: expected.text.replace(ZWNJ, ""),
        blocks: expected.blocks.map(|blocks| blocks.replace(ZWNJ, "")),
    };
    Ok(generated(bytes, expected))
}

fn fa(sources: &Sources) -> Result<Generated, String> {
    notice(
        sources,
        &Notice {
            name: "fa-zwnj",
            lang: "fa-IR",
            font: FontFile::PlexSansArabic,
            rtl: true,
            cjk: false,
            title: "اطلاعیه‌ی تمدید قرارداد اجاره",
            paragraphs: [
                "به اطلاع می‌رساند که قرارداد اجاره‌ی واحد شماره ۱۲ این ساختمان در پایان آبان ماه به پایان می‌رسد.",
                "مستأجران گرامی می‌توانند درخواست تمدید را تا پایان هفته‌ی آینده به دفتر مدیریت ساختمان تحویل دهند.",
                "برای هماهنگی بیشتر با دفتر مدیریت تماس بگیرید یا نامه‌ی خود را در صندوق دفتر بگذارید.",
            ],
            author: "دفتر مدیریت ساختمان",
            created: "D:20261102100000+03'30'",
        },
    )
}

fn he(sources: &Sources) -> Result<Generated, String> {
    notice(
        sources,
        &Notice {
            name: "he-para",
            lang: "he-IL",
            font: FontFile::PlexSansHebrew,
            rtl: true,
            cjk: false,
            title: "הודעה על חידוש חוזה השכירות",
            paragraphs: [
                "חוזה השכירות של הדירה ברחוב הרצל 24 בתל אביב מסתיים בסוף חודש נובמבר.",
                "השוכרים מתבקשים להודיע למשרד הניהול עד סוף השבוע הבא אם ברצונם לחדש את החוזה לשנה נוספת.",
                "לפרטים נוספים ניתן לפנות למשרד הניהול בכל יום חול.",
            ],
            author: "משרד הניהול",
            created: "D:20261102100000+02'00'",
        },
    )
}

fn ja(sources: &Sources) -> Result<Generated, String> {
    notice(
        sources,
        &Notice {
            name: "ja-para",
            lang: "ja-JP",
            font: FontFile::NotoSerifJp,
            rtl: false,
            cjk: true,
            title: "賃貸契約更新のお知らせ",
            paragraphs: [
                "拝啓、現在ご利用中の東京都品川区の事務所について、賃貸借契約は二〇二六年十一月三十日に満了します。",
                "更新をご希望の場合は、十一月十五日までに管理事務所へご連絡ください。",
                "更新後の月額賃料は十九万五千円です。",
            ],
            author: "管理事務所",
            created: "D:20261102100000+09'00'",
        },
    )
}

fn zh_hans(sources: &Sources) -> Result<Generated, String> {
    notice(
        sources,
        &Notice {
            name: "zh-hans",
            lang: "zh-CN",
            font: FontFile::NotoSansSc,
            rtl: false,
            cjk: true,
            title: "租赁合同续签通知",
            paragraphs: [
                "您好，您目前租用的位于上海市徐汇区的办公室，租赁合同将于二〇二六年十一月三十日到期。",
                "如需续签，请在十一月十五日前联系物业管理处，并携带有效身份证件及原合同。",
                "续签后的月租金为一万九千五百元，物业管理费另计。",
            ],
            author: "物业管理处",
            created: "D:20261102100000+08'00'",
        },
    )
}

fn zh_hant(sources: &Sources) -> Result<Generated, String> {
    notice(
        sources,
        &Notice {
            name: "zh-hant",
            lang: "zh-TW",
            font: FontFile::NotoSansTc,
            rtl: false,
            cjk: true,
            title: "租賃合約續約通知",
            paragraphs: [
                "您好，您目前承租位於臺北市大安區的辦公室，租賃合約將於二〇二六年十一月三十日到期。",
                "如需續約，請於十一月十五日前聯絡物業管理處，並攜帶有效身分證件及原合約。",
                "續約後的每月租金為新臺幣六萬五千元，管理費另計。",
            ],
            author: "物業管理處",
            created: "D:20261102100000+08'00'",
        },
    )
}

fn ko(sources: &Sources) -> Result<Generated, String> {
    notice(
        sources,
        &Notice {
            name: "ko-para",
            lang: "ko-KR",
            font: FontFile::NotoSansKr,
            rtl: false,
            cjk: false,
            title: "임대차 계약 갱신 안내",
            paragraphs: [
                "안녕하십니까. 귀하께서 현재 임차 중인 서울특별시 마포구 소재 사무실의 임대차 계약이 2026년 11월 30일에 만료됩니다.",
                "계약 갱신을 원하시면 11월 15일까지 관리사무소로 연락해 주시기 바랍니다.",
                "갱신 후 월 임대료는 195만 원이며 관리비는 별도입니다.",
            ],
            author: "관리사무소",
            created: "D:20261102100000+09'00'",
        },
    )
}
