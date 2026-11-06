//! The cells of a table that likely depend on an edited cell (a3-9, ROADMAP E07): flagged for
//! the user, never changed.
//!
//! - **Amounts.** The cells of right-aligned columns (layout's amount columns) whose text is a
//!   number, in Turkish or English form ("1.234,56", "1,234.56"), with a currency before or after
//!   it ("TL", "₺", "$", "€" and their codes). A single separator followed by exactly three
//!   digits groups thousands ("18.500" is 18500), as Turkish amounts write it.
//! - **In a row.** An amount right of two others that equals their product or sum: Tutar =
//!   Miktar × Birim fiyat.
//! - **In a column.** Down the column, an amount that equals the sum of at least two amounts since
//!   the last total (Ara toplam), or that total plus the amounts after it (Genel toplam = Ara
//!   toplam + KDV), or an amount above it times a rate its row names ("KDV %20", "VAT 20%"). Such
//!   a total counts only in a row whose other amounts are totals too, so a quantity that happens
//!   to be the sum of the ones above it is not one.
//!
//! Dependence is followed on: editing a price flags its row's amount, the subtotal, the tax and
//! the grand total. Values are compared to the cent.

use std::collections::{BTreeSet, HashMap};

use crate::layout::{Alignment, BlockId, PageText};

/// How far two amounts may differ and still be equal: half a cent, and rounding.
const CENT: f64 = 0.0051;
/// Rows with more amounts than this are not searched for products and sums: a hostile table
/// would make the search cubic.
const MAX_ROW_AMOUNTS: usize = 32;
/// Currencies around an amount.
const CURRENCIES: [&str; 9] = ["TRY", "USD", "EUR", "GBP", "TL", "₺", "$", "€", "£"];

/// The blocks of `page`'s table cells that likely depend on the cell `edited` (module
/// documentation), from the top, each row from the left; empty when `edited` is not an amount in
/// a table.
#[must_use]
pub fn dependent_cells(page: &PageText, edited: BlockId) -> Vec<BlockId> {
    let Some(table) = page
        .blocks
        .iter()
        .find(|block| block.id == edited)
        .and_then(|block| block.cell)
        .map(|cell| cell.table)
    else {
        return Vec::new();
    };
    let cells: Vec<Cell> = page
        .blocks
        .iter()
        .filter_map(|block| {
            let cell = block.cell.filter(|cell| cell.table == table)?;
            let text = block.text();
            Some(Cell {
                id: block.id,
                row: cell.row,
                column: cell.column,
                value: (block.alignment == Alignment::Right)
                    .then(|| amount(&text))
                    .flatten(),
                rate: rate(&text),
            })
        })
        .collect();
    // Each source's dependents, so following them is linear in the edges, not quadratic.
    let mut dependents_of: HashMap<BlockId, BTreeSet<BlockId>> = HashMap::new();
    for (source, target) in edges(&cells) {
        dependents_of.entry(source).or_default().insert(target);
    }
    let mut found = BTreeSet::new();
    let mut queue = vec![edited];
    while let Some(from) = queue.pop() {
        for &target in dependents_of.get(&from).into_iter().flatten() {
            if target != edited && found.insert(target) {
                queue.push(target);
            }
        }
    }
    let mut dependents: Vec<&Cell> = cells
        .iter()
        .filter(|cell| found.contains(&cell.id))
        .collect();
    dependents.sort_by_key(|cell| (cell.row, cell.column));
    dependents.iter().map(|cell| cell.id).collect()
}

/// The number `text` writes, with its currency, in Turkish or English form; `None` for other
/// text.
#[must_use]
pub fn amount(text: &str) -> Option<f64> {
    let mut rest = text.trim();
    for currency in CURRENCIES {
        rest = rest
            .strip_prefix(currency)
            .or_else(|| rest.strip_suffix(currency))
            .unwrap_or(rest)
            .trim();
    }
    let (negative, digits) = match rest.strip_prefix(['-', '\u{2212}']) {
        Some(digits) => (true, digits.trim_start()),
        None => (false, rest),
    };
    let first = digits.chars().next()?;
    let last = digits.chars().next_back()?;
    if !first.is_ascii_digit()
        || !last.is_ascii_digit()
        || !digits
            .chars()
            .all(|c| c.is_ascii_digit() || c == '.' || c == ',')
    {
        return None;
    }
    let decimal = match (digits.rfind('.'), digits.rfind(',')) {
        (Some(dot), Some(comma)) => Some(dot.max(comma)),
        (Some(at), None) | (None, Some(at)) => {
            let separator = if digits.contains('.') { '.' } else { ',' };
            let once = digits.matches(separator).count() == 1;
            let after = digits.len().saturating_sub(at).saturating_sub(1);
            (once && after != 3).then_some(at)
        }
        (None, None) => None,
    };
    let plain: String = digits
        .char_indices()
        .filter_map(|(at, c)| match c {
            '.' | ',' if Some(at) == decimal => Some('.'),
            '.' | ',' => None,
            c => Some(c),
        })
        .collect();
    let value: f64 = plain.parse().ok()?;
    Some(if negative { -value } else { value })
}

/// The percentage `text` names, "%20" or "20%", as a fraction.
fn rate(text: &str) -> Option<f64> {
    let at = text.find('%')?;
    let number = |piece: &str| amount(piece).map(|value| value / 100.0);
    let after: String = text
        .get(at.saturating_add(1)..)?
        .chars()
        .take_while(|c| c.is_ascii_digit() || *c == ',' || *c == '.')
        .collect();
    let before: String = {
        let mut digits: Vec<char> = text
            .get(..at)?
            .chars()
            .rev()
            .take_while(|c| c.is_ascii_digit() || *c == ',' || *c == '.')
            .collect();
        digits.reverse();
        digits.into_iter().collect()
    };
    number(&after).or_else(|| number(&before))
}

struct Cell {
    id: BlockId,
    row: usize,
    column: usize,
    value: Option<f64>,
    rate: Option<f64>,
}

fn equal(a: f64, b: f64) -> bool {
    (a - b).abs() <= CENT + 1e-12 * a.abs().max(b.abs())
}

/// The dependencies between the cells, as (source, dependent) pairs.
fn edges(cells: &[Cell]) -> Vec<(BlockId, BlockId)> {
    let amounts: Vec<(&Cell, f64)> = cells
        .iter()
        .filter_map(|cell| cell.value.map(|value| (cell, value)))
        .collect();
    let mut rows: HashMap<usize, Vec<(&Cell, f64)>> = HashMap::new();
    for &(cell, value) in &amounts {
        rows.entry(cell.row).or_default().push((cell, value));
    }
    let mut edges = Vec::new();
    for row in rows.values().filter(|row| row.len() <= MAX_ROW_AMOUNTS) {
        for &(x, value) in row {
            if value.abs() < CENT {
                continue;
            }
            for (i, &(a, first)) in row.iter().enumerate() {
                for &(b, second) in row.iter().skip(i.saturating_add(1)) {
                    let left = a.column < x.column && b.column < x.column;
                    if left && (equal(value, first * second) || equal(value, first + second)) {
                        edges.push((a.id, x.id));
                        edges.push((b.id, x.id));
                    }
                }
            }
        }
    }
    let rates: HashMap<usize, f64> = cells
        .iter()
        .filter_map(|cell| cell.rate.map(|rate| (cell.row, rate)))
        .collect();
    let mut columns: HashMap<usize, Vec<(&Cell, f64)>> = HashMap::new();
    for &(cell, value) in &amounts {
        columns.entry(cell.column).or_default().push((cell, value));
    }
    // A total's sources, each column on its own; kept below only where the rest of its row are
    // totals too.
    let mut totals: Vec<(BlockId, Vec<BlockId>)> = Vec::new();
    for column in columns.values_mut() {
        column.sort_by_key(|(cell, _)| cell.row);
        let mut last: Option<(&Cell, f64)> = None;
        let mut run: Vec<(&Cell, f64)> = Vec::new();
        for (at, &(x, value)) in column.iter().enumerate() {
            let sum: f64 = run.iter().map(|(_, value)| value).sum();
            let mut sources: Vec<BlockId> = Vec::new();
            if run.len() >= 2 && equal(value, sum) {
                sources.extend(run.iter().map(|(cell, _)| cell.id));
            } else if let Some((total, subtotal)) = last.filter(|_| !run.is_empty())
                && equal(value, subtotal + sum)
            {
                sources.push(total.id);
                sources.extend(run.iter().map(|(cell, _)| cell.id));
            }
            if !sources.is_empty() {
                totals.push((x.id, sources));
                last = Some((x, value));
                run.clear();
                continue;
            }
            if let Some(rate) = rates.get(&x.row)
                && let Some((above, _)) = column
                    .get(..at)
                    .unwrap_or_default()
                    .iter()
                    .rev()
                    .find(|(_, above)| equal(value, above * rate))
            {
                totals.push((x.id, vec![above.id]));
            }
            run.push((x, value));
        }
    }
    let total_ids: BTreeSet<BlockId> = totals.iter().map(|(id, _)| *id).collect();
    for (target, sources) in totals {
        let row_of_totals = amounts
            .iter()
            .find(|(cell, _)| cell.id == target)
            .and_then(|(cell, _)| rows.get(&cell.row))
            .is_some_and(|row| row.iter().all(|(cell, _)| total_ids.contains(&cell.id)));
        if row_of_totals {
            edges.extend(sources.into_iter().map(|source| (source, target)));
        }
    }
    edges
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn amounts_in_turkish_and_english_form() {
        assert_eq!(amount("18.500,00"), Some(18_500.0));
        assert_eq!(amount("1,234.56"), Some(1_234.56));
        assert_eq!(amount("1.250"), Some(1_250.0));
        assert_eq!(amount("12,5"), Some(12.5));
        assert_eq!(amount("1.234.567"), Some(1_234_567.0));
        assert_eq!(amount("4.590,00 TL"), Some(4_590.0));
        assert_eq!(amount("₺750,00"), Some(750.0));
        assert_eq!(amount("$ 1,250.00"), Some(1_250.0));
        assert_eq!(amount("−42"), Some(-42.0));
        assert_eq!(amount("7"), Some(7.0));
        for text in ["Tutar (TL)", "KDV %20", "", "1.", "TR64 0001"] {
            assert_eq!(amount(text), None, "{text}");
        }
    }

    /// A page of one table, `rows` of cell texts, every cell right-aligned but the first column.
    fn table(rows: &[&[&str]]) -> PageText {
        let mut blocks = Vec::new();
        for (row, texts) in rows.iter().enumerate() {
            for (column, text) in texts.iter().enumerate() {
                blocks.push(crate::layout::TextBlock {
                    id: BlockId(u64::try_from(blocks.len()).unwrap_or(u64::MAX)),
                    bbox: [0.0; 4],
                    lines: vec![crate::layout::Line {
                        text: (*text).to_owned(),
                        chars: Vec::new(),
                        words: Vec::new(),
                        bbox: [0.0; 4],
                        baseline: [[0.0; 2]; 2],
                        size: 10.0,
                        direction: crate::layout::TextDirection::LeftToRight,
                    }],
                    alignment: if column == 0 {
                        Alignment::Left
                    } else {
                        Alignment::Right
                    },
                    justification: None,
                    direction: crate::layout::TextDirection::LeftToRight,
                    column: 0,
                    cell: Some(crate::layout::TableCell {
                        table: 0,
                        row,
                        column,
                    }),
                    editability: crate::Editability::Editable,
                });
            }
        }
        PageText {
            blocks,
            ..PageText::default()
        }
    }

    /// The id of the cell at `row`, `column` of a [`table`] with `width` columns.
    fn id(width: u64, row: u64, column: u64) -> BlockId {
        BlockId(row * width + column)
    }

    #[test]
    fn an_english_invoice_flags_its_amount_and_totals() {
        let page = table(&[
            &["Item", "Qty", "Price", "Amount"],
            &["Design", "3", "$1,250.00", "$3,750.00"],
            &["Hosting", "12", "$20.00", "$240.00"],
            &["Subtotal", "", "", "$3,990.00"],
            &["VAT 20%", "", "", "$798.00"],
            &["Total", "", "", "$4,788.00"],
        ]);
        assert_eq!(
            dependent_cells(&page, id(4, 1, 2)),
            [id(4, 1, 3), id(4, 3, 3), id(4, 4, 3), id(4, 5, 3)]
        );
        // A label and a header depend on nothing and have no dependents.
        assert!(dependent_cells(&page, id(4, 1, 0)).is_empty());
        assert!(dependent_cells(&page, id(4, 0, 3)).is_empty());
    }

    #[test]
    fn a_hostile_grid_of_equal_amounts_stays_fast() {
        // Every cell is a product of any two to its left: the edges are many, following them must
        // stay linear in them.
        let row: Vec<&str> = std::iter::repeat_n("1", MAX_ROW_AMOUNTS).collect();
        let rows: Vec<&[&str]> = std::iter::repeat_n(row.as_slice(), 100).collect();
        let page = table(&rows);
        let started = std::time::Instant::now();
        let found = dependent_cells(&page, id(32, 0, 1));
        assert!(!found.is_empty());
        assert!(started.elapsed().as_secs() < 10, "{:?}", started.elapsed());
    }

    #[test]
    fn rates_before_or_after_the_number() {
        assert_eq!(rate("KDV %20"), Some(0.2));
        assert_eq!(rate("VAT 7.5%"), Some(0.075));
        assert_eq!(rate("Toplam"), None);
    }
}
