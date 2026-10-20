//! `letter-ja-vertical`: the lease-renewal letter of `a3-15` ("賃貸借契約更新のご案内.pdf"),
//! one A4 page of vertical text (縦書き) in Noto Serif JP, the board's font, with its title in
//! the SemiBold instance of the same variable font. Columns run from right to left, as the board
//! draws them: the title, the date, the addressee, the body, 敬具 and the sender, then the 記
//! section the body announces.
//!
//! The text is in `Identity-V` composite fonts with `/W2` and `/DW2`, the punctuation and the
//! brackets in their vertical forms. The rent's "19" is upright across its column
//! (tate-chu-yoko) in the same face as an `Identity-H` font. The body breaks with kinsoku: one
//! of its columns ends with a hanging comma.

use super::{Doc, generated, info, open_first};
use crate::pdf::{self, text};
use crate::sources::{FontFile, Sources};
use crate::text::PageText;
use crate::vertical::{Piece, Vertical, cells, columns, draw_column};
use crate::{Expect, Generated, Generator};
use lopdf::dictionary;

/// The vertical letter.
pub const LETTER_JA_VERTICAL: Generator = Generator {
    name: "letter-ja-vertical",
    build,
    expect: Expect::OpensUnordered,
};

/// The top of every column.
const TOP: f64 = pdf::A4.1 - 72.0;
/// The height of the text block; bottom-aligned columns end at `TOP - HEIGHT`.
const HEIGHT: f64 = 470.0;
/// The right edge of the first column and the left limit of the last.
const RIGHT: f64 = pdf::A4.0 - 66.0;
const LEFT: f64 = 66.0;
/// The space between groups of columns.
const GAP: f64 = 18.0;
const SECONDARY: (u8, u8, u8) = (0x57, 0x53, 0x4C);

const BODY: [Piece<'static>; 3] = [
    Piece::Text(
        "拝啓　秋冷の候、ますますご清祥のこととお喜び申し上げます。さて、現在ご契約いただいております賃貸借契約は、二〇二六年十一月三十日をもって期間満了となります。つきましては、契約更新の手続きについて下記のとおりご案内申し上げます。更新後の月額賃料は",
    ),
    Piece::Upright("19"),
    Piece::Text("万五千円です。"),
];

const ITEMS: [&str; 4] = [
    "一、契約期間　二〇二六年十二月一日から二〇二八年十一月三十日まで",
    "二、月額賃料　十九万五千円（管理費を含む）",
    "三、更新料　新賃料の一か月分",
    "四、ご返送期限　二〇二六年十一月十三日（金）",
];

/// How many cells of `style` fit in `height`.
fn per_column(style: &Vertical, height: f64) -> usize {
    let pitch = (1000.0 + style.tracking) * style.size / 1000.0;
    let count = ((height + style.tracking * style.size / 1000.0) / pitch).floor();
    // Bounded by the page: a few dozen cells at most.
    if (1.0..=200.0).contains(&count) {
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let count = count as usize;
        count
    } else {
        1
    }
}

/// The columns being drawn, right to left.
struct Columns {
    page: PageText,
    /// The right edge of the next column.
    x: f64,
}

impl Columns {
    /// Draws `pieces` in columns of `pitch` points from the top, or ending at the bottom of
    /// the block when `bottom` (a short line), and leaves a gap after them.
    fn add(
        &mut self,
        doc: &mut Doc,
        style: &Vertical,
        pieces: &[Piece<'_>],
        pitch: f64,
        bottom: bool,
    ) -> Result<(), String> {
        let all = cells(pieces);
        let count = all.len();
        for column in columns(all, per_column(style, HEIGHT)) {
            let top = if bottom {
                TOP - HEIGHT + style.height(count)
            } else {
                TOP
            };
            draw_column(
                &mut self.page,
                &mut doc.fonts,
                style,
                &column,
                (self.x - pitch / 2.0, top),
            )?;
            self.x -= pitch;
        }
        self.x -= GAP;
        Ok(())
    }
}

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let title = doc.vertical_style(sources, FontFile::NotoSerifJpSemiBold, 15.0, 120.0)?;
    let body = doc.vertical_style(sources, FontFile::NotoSerifJp, 10.5, 60.0)?;
    let grey = Vertical {
        color: SECONDARY,
        ..body
    };
    let line = 10.5 * 1.9;
    let pitch = 10.5 * 1.95;
    let mut page = Columns {
        page: PageText::default(),
        x: RIGHT,
    };
    page.add(
        &mut doc,
        &title,
        &[Piece::Text("賃貸借契約更新のご案内")],
        15.0 * 1.6,
        false,
    )?;
    page.add(
        &mut doc,
        &grey,
        &[Piece::Text("二〇二六年十月十三日")],
        line,
        false,
    )?;
    page.add(
        &mut doc,
        &body,
        &[Piece::Text("アイシェ・ユルマズ様")],
        line,
        false,
    )?;
    page.add(&mut doc, &body, &BODY, pitch, false)?;
    page.add(&mut doc, &body, &[Piece::Text("敬具")], line, true)?;
    page.add(
        &mut doc,
        &grey,
        &[Piece::Text("株式会社モダ不動産　管理部")],
        line,
        true,
    )?;
    // 記, centred in its column, the items one character down, and 以上 at the bottom.
    draw_column(
        &mut page.page,
        &mut doc.fonts,
        &body,
        &cells(&[Piece::Text("記")]),
        (page.x - line / 2.0, TOP - (HEIGHT - body.height(1)) / 2.0),
    )?;
    page.x -= line + GAP;
    for item in ITEMS {
        draw_column(
            &mut page.page,
            &mut doc.fonts,
            &body,
            &cells(&[Piece::Text(item)]),
            (
                page.x - pitch / 2.0,
                TOP - body.height(1) - body.tracking * 10.5 / 1000.0,
            ),
        )?;
        page.x -= pitch;
    }
    page.add(&mut doc, &body, &[Piece::Text("以上")], line, true)?;
    if page.x + GAP < LEFT {
        return Err(format!(
            "the columns reach {:.1} pt, past the left margin",
            page.x + GAP
        ));
    }

    let (ids, expected) = doc.add_pages(vec![page.page], pdf::A4);
    let catalog = dictionary! { "Lang" => text("ja-JP"), "OpenAction" => open_first(ids[0]) };
    let bytes = doc.close(
        catalog,
        &info(
            "賃貸借契約更新のご案内",
            "株式会社モダ不動産　管理部",
            "文書作成ソフト",
            "D:20261013100000+09'00'",
        ),
        "letter-ja-vertical",
        None,
    )?;
    Ok(generated(bytes, expected))
}
