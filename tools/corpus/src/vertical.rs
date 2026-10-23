//! Vertical Japanese text (縦書き), as a vertical layout program writes it: each column is a
//! `BT` block in an `Identity-V` composite font, shaped top to bottom (so the `vert` forms of
//! punctuation and the long vowel mark are used), with the letter spacing as `TJ` adjustments.
//! Columns go from right to left.
//!
//! - **Tate-chu-yoko (縦中横):** a short run of digits set upright across the column, in the
//!   same face as a horizontal (`Identity-H`) font with half-width forms, in one em.
//! - **Kinsoku (禁則):** a column never starts with closing punctuation, small kana or the long
//!   vowel mark, and never ends with an opening bracket. The comma and the full stop hang below
//!   the column (burasage); any other character that may not start a column takes the last
//!   character of the previous one with it (oidashi).

use crate::font::Glyph;
use crate::kinsoku::{HANGING, NO_END, NO_START};
use crate::pdf::num;
use crate::text::{FontKey, Fonts, PageText};
use harfrust::{Feature, Tag};

/// A piece of vertical text.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Piece<'a> {
    /// Characters set top to bottom.
    Text(&'a str),
    /// A short run set upright across the column (tate-chu-yoko).
    Upright(&'a str),
}

/// One cell of a column: a character, or an upright run that takes one em.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Cell {
    /// A character.
    Char(char),
    /// An upright run.
    Upright(String),
}

impl Cell {
    fn is(&self, set: &str) -> bool {
        matches!(self, Self::Char(c) if set.contains(*c))
    }
}

/// The cells of `pieces`.
#[must_use]
pub fn cells(pieces: &[Piece<'_>]) -> Vec<Cell> {
    let mut cells = Vec::new();
    for piece in pieces {
        match piece {
            Piece::Text(text) => cells.extend(text.chars().map(Cell::Char)),
            Piece::Upright(text) => cells.push(Cell::Upright((*text).to_owned())),
        }
    }
    cells
}

/// Breaks `cells` into columns of `per_column` cells, with the kinsoku rules: a hanging comma
/// or full stop makes a column one cell longer, oidashi makes it shorter.
#[must_use]
pub fn columns(cells: Vec<Cell>, per_column: usize) -> Vec<Vec<Cell>> {
    let mut columns = Vec::new();
    let mut current: Vec<Cell> = Vec::new();
    for cell in cells {
        if current.len() < per_column.max(2) {
            current.push(cell);
            continue;
        }
        if cell.is(HANGING) {
            current.push(cell);
            columns.push(std::mem::take(&mut current));
            continue;
        }
        let mut next = vec![cell];
        while current.len() > 1
            && (next.first().is_some_and(|first| first.is(NO_START))
                || current.last().is_some_and(|last| last.is(NO_END)))
        {
            if let Some(last) = current.pop() {
                next.insert(0, last);
            }
        }
        columns.push(std::mem::replace(&mut current, next));
    }
    if !current.is_empty() {
        columns.push(current);
    }
    columns
}

/// The fonts and spacing of vertical text.
#[derive(Debug, Clone, Copy)]
pub struct Vertical {
    /// The `Identity-V` font.
    pub font: FontKey,
    /// The same face as an `Identity-H` font, for upright runs.
    pub upright: FontKey,
    /// The size in points.
    pub size: f64,
    /// The space after each cell, in thousandths of an em.
    pub tracking: f64,
    /// The fill colour.
    pub color: (u8, u8, u8),
    /// How far the baseline of an upright run is below the top of its cell, in thousandths of
    /// an em (the face's vertical origin).
    pub origin: f64,
}

impl Vertical {
    /// The height of `count` cells in points, without the space after the last.
    #[must_use]
    pub fn height(&self, count: usize) -> f64 {
        #[allow(clippy::cast_precision_loss)]
        let count = count as f64;
        (count * (1000.0 + self.tracking) - self.tracking) * self.size / 1000.0
    }
}

/// A `TJ` array for vertical `glyphs`: in vertical writing a positive number moves the next
/// glyph down, so the space after a glyph is its advance plus the tracking less its `/W2` height.
fn vertical_array(glyphs: &[Glyph], tracking: f64) -> String {
    let mut array = String::new();
    let mut codes = String::new();
    for (index, glyph) in glyphs.iter().enumerate() {
        for byte in &glyph.code {
            codes.push_str(&format!("{byte:02X}"));
        }
        let adjust = (glyph.advance + tracking - glyph.width).round();
        if index + 1 < glyphs.len() && adjust.abs() >= 0.5 {
            array.push_str(&format!("<{codes}>{}", num(adjust)));
            codes.clear();
        }
    }
    if !codes.is_empty() {
        array.push_str(&format!("<{codes}>"));
    }
    array
}

/// Draws one column with the top of its first cell at `top`, centred on `x`, records its text
/// and returns the position below its last cell.
///
/// # Errors
///
/// A message when a character cannot be set.
pub fn draw_column(
    page: &mut PageText,
    fonts: &mut Fonts,
    style: &Vertical,
    cells: &[Cell],
    (x, top): (f64, f64),
) -> Result<f64, String> {
    let mut y = top;
    let mut text = String::new();
    let mut index = 0;
    let colored = style.color != (0, 0, 0);
    if colored {
        page.content.fill_rgb(style.color);
    }
    while index < cells.len() {
        match &cells[index] {
            Cell::Char(_) => {
                let mut run = String::new();
                while let Some(Cell::Char(c)) = cells.get(index) {
                    run.push(*c);
                    index += 1;
                }
                let glyphs = fonts.shape(style.font, &run, &[], false)?;
                page.content
                    .op("BT")
                    .op(&format!(
                        "/{} {} Tf",
                        Fonts::resource_name(style.font),
                        num(style.size)
                    ))
                    .op(&format!("{} {} Td", num(x), num(y)))
                    .op(&format!("[{}] TJ", vertical_array(&glyphs, style.tracking)))
                    .op("ET");
                page.fonts.insert(style.font);
                y -= glyphs
                    .iter()
                    .map(|glyph| (glyph.advance + style.tracking) * style.size / 1000.0)
                    .sum::<f64>();
                text.push_str(&run);
            }
            Cell::Upright(run) => {
                index += 1;
                let half_width = [Feature::new(Tag::new(b"hwid"), 1, ..)];
                let glyphs = fonts.shape(style.upright, run, &half_width, false)?;
                let width: f64 = glyphs.iter().map(|glyph| glyph.advance).sum();
                let codes: String = glyphs
                    .iter()
                    .flat_map(|glyph| glyph.code.iter().map(|byte| format!("{byte:02X}")))
                    .collect();
                // Compressed to one em when the half-width forms are wider.
                let scale = if width > 1000.0 { 1000.0 / width } else { 1.0 };
                let drawn = width * scale * style.size / 1000.0;
                page.content.op("BT").op(&format!(
                    "/{} {} Tf",
                    Fonts::resource_name(style.upright),
                    num(style.size)
                ));
                if scale < 1.0 {
                    page.content.op(&format!("{} Tz", num(scale * 100.0)));
                }
                page.content
                    .op(&format!(
                        "{} {} Td",
                        num(x - drawn / 2.0),
                        num(y - style.origin * style.size / 1000.0)
                    ))
                    .op(&format!("<{codes}> Tj"))
                    .op("ET");
                page.fonts.insert(style.upright);
                y -= (1000.0 + style.tracking) * style.size / 1000.0;
                text.push_str(run);
            }
        }
    }
    if colored {
        page.content.fill_rgb((0, 0, 0));
    }
    page.lines.push(text);
    Ok(y + style.tracking * style.size / 1000.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn text(columns: &[Vec<Cell>]) -> Vec<String> {
        columns
            .iter()
            .map(|column| {
                column
                    .iter()
                    .map(|cell| match cell {
                        Cell::Char(c) => c.to_string(),
                        Cell::Upright(run) => format!("[{run}]"),
                    })
                    .collect()
            })
            .collect()
    }

    #[test]
    fn full_stops_and_commas_hang_below_the_column() {
        let hanging = columns(cells(&[Piece::Text("あいう。えお")]), 3);
        assert_eq!(text(&hanging), ["あいう。", "えお"]);
    }

    #[test]
    fn small_kana_and_closing_brackets_take_a_character_along() {
        let small = columns(cells(&[Piece::Text("あいうっえ")]), 3);
        assert_eq!(text(&small), ["あい", "うっえ"]);
        let brackets = columns(cells(&[Piece::Text("あい「うえ」お")]), 3);
        assert_eq!(text(&brackets), ["あい", "「う", "え」お"]);
        let two = columns(cells(&[Piece::Text("あいう」」え")]), 3);
        assert_eq!(text(&two), ["あい", "う」」", "え"]);
    }

    #[test]
    fn an_upright_run_is_one_cell() {
        let upright = columns(
            cells(&[
                Piece::Text("賃料は"),
                Piece::Upright("19"),
                Piece::Text("万円"),
            ]),
            4,
        );
        assert_eq!(text(&upright), ["賃料は[19]", "万円"]);
    }
}
