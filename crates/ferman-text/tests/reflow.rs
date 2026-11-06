//! Reflow, overflow plans and dependent totals on the edit corpus (ROADMAP §7 steps 4 and 5,
//! E06 and E07): `kira-tr`'s Madde 4 grows into the IBAN line (a3-18), Madde 6 into free space;
//! `fatura-tr`'s amounts keep their right edge and flag the totals that depend on them (a3-9).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;
use std::sync::Arc;

use ferman_core::{Document, OpenOptions, Source, open};
use ferman_text::{
    Alignment, BlockId, EditContext, ExtendBlocked, Frame, Justification, PageText, TextBlock,
    dependent_cells, overflow, reflow, text_page,
};

fn document(name: &str) -> Document {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"));
    let bytes = std::fs::read(path).unwrap();
    open(
        &Source::from_bytes(Arc::from(&bytes[..])),
        &OpenOptions::default(),
    )
    .unwrap()
}

fn block<'a>(page: &'a PageText, starts: &str) -> &'a TextBlock {
    page.blocks
        .iter()
        .find(|block| block.text().starts_with(starts))
        .unwrap_or_else(|| panic!("no block starts with {starts:?}"))
}

/// An advance for every character, from the block's last (unstretched) line: its length over
/// its characters.
fn uniform(block: &TextBlock) -> impl Fn(char) -> f32 {
    let line = block.lines.last().unwrap();
    let width = line.baseline[1][0] - line.baseline[0][0];
    #[allow(clippy::cast_precision_loss)]
    let advance = width / line.text.chars().count() as f32;
    move |_| advance
}

fn page_box(document: &Document, index: usize) -> [f32; 4] {
    let (width, height) = document.structure().pages[index].size;
    [0.0, 0.0, width, height]
}

#[test]
fn madde_4_cannot_grow_into_the_iban_line() {
    let document = document("kira-tr");
    let page = text_page(&document, 0, &EditContext::default()).unwrap();
    let madde = block(&page, "Kiracı, aylık kira bedeli");
    let frame = Frame::of(madde).unwrap();
    assert_eq!(frame.alignment, Alignment::Justified);
    assert_eq!(frame.justification, Some(Justification::WordSpacing));
    assert_eq!(frame.lines, 2);
    assert!((frame.width - 451.28).abs() < 0.5, "{}", frame.width);
    assert!((frame.pitch - 15.75).abs() < 0.05, "{}", frame.pitch);

    let advance = uniform(madde);
    let text = format!(
        "{} Ödemede gecikme olursa kiracı, geciken her ay için aylık yüzde iki gecikme faizi öder.",
        madde.text().replace('\n', " ")
    );
    let plan = overflow(
        madde,
        &frame,
        &text,
        &advance,
        &page.blocks,
        page_box(&document, 0),
    )
    .unwrap();
    assert_eq!(plan.over, 1);
    match &plan.extend {
        Err(ExtendBlocked::Block { text, .. }) => assert!(text.starts_with("IBAN:"), "{text}"),
        other => panic!("{other:?}"),
    }
    assert_eq!(plan.keep.hidden, 1);
    // A whole sentence more is far past what 2% of the em can take back.
    assert_eq!(plan.tighten.unwrap_err().over, 1);

    // The justified lines but the last fill the frame by `Tw`.
    let laid = reflow(&frame, &text, &advance);
    assert_eq!(laid.lines.len(), 3);
    for line in &laid.lines[..2] {
        let stretch = line.stretch.unwrap();
        assert_eq!(stretch.method, Justification::WordSpacing);
        #[allow(clippy::cast_precision_loss)]
        let filled = line.width + stretch.per_gap * stretch.gaps as f32;
        assert!((filled - frame.width).abs() < 1e-3);
    }
    assert_eq!(laid.lines[2].stretch, None);
}

#[test]
fn madde_6_grows_into_the_free_space_below_it() {
    let document = document("kira-tr");
    let page = text_page(&document, 0, &EditContext::default()).unwrap();
    let madde = block(&page, "Kiracı, kiralananı özenle");
    let frame = Frame::of(madde).unwrap();
    let advance = uniform(madde);
    let text = format!(
        "{} Kiracı, yapacağı her değişikliği önceden kiraya verene yazıyla bildirir ve kiraya verenin yazılı onayı olmadan taşınmazda tadilat yapmaz.",
        madde.text().replace('\n', " ")
    );
    let plan = overflow(
        madde,
        &frame,
        &text,
        &advance,
        &page.blocks,
        page_box(&document, 0),
    )
    .unwrap();
    assert_eq!(plan.over, 1);
    let extend = plan.extend.unwrap();
    assert_eq!(extend.lines, 1);
    assert_eq!(extend.frame.lines, frame.lines + plan.over);
}

#[test]
fn a_longer_amount_keeps_its_right_edge() {
    let document = document("fatura-tr");
    let page = text_page(&document, 0, &EditContext::default()).unwrap();
    let cell = page
        .blocks
        .iter()
        .find(|block| block.text() == "1.250,00" && block.cell.is_some_and(|c| c.column == 3))
        .unwrap();
    assert_eq!(cell.alignment, Alignment::Right);
    let frame = Frame::of(cell).unwrap();
    let plan = reflow(&frame, "12.500,00", |_| 5.0);
    let line = &plan.lines[0];
    assert!(
        (line.start[0] + line.width - 441.0).abs() < 0.05,
        "{line:?}"
    );
    assert_eq!(plan.over(), 0);
}

/// The ids of the cells `rows` (row, column) of table 0.
fn cells(page: &PageText, rows: &[(usize, usize)]) -> Vec<BlockId> {
    rows.iter()
        .map(|&(row, column)| {
            page.blocks
                .iter()
                .find(|block| {
                    block
                        .cell
                        .is_some_and(|cell| cell.row == row && cell.column == column)
                })
                .unwrap()
                .id
        })
        .collect()
}

#[test]
fn edited_invoice_cells_flag_the_totals_that_depend_on_them() {
    let document = document("fatura-tr");
    let page = text_page(&document, 0, &EditContext::default()).unwrap();
    // Every cell of the amount columns is right-aligned.
    for block in &page.blocks {
        if let Some(cell) = block.cell
            && cell.column >= 2
        {
            assert_eq!(block.alignment, Alignment::Right, "{}", block.text());
        }
    }
    let totals = [(5, 4), (6, 4), (7, 4)];
    let dependents = |row, column| dependent_cells(&page, cells(&page, &[(row, column)])[0]);
    // Miktar and Birim fiyat: the row's Tutar, then Ara toplam, KDV and Genel toplam.
    for column in [2, 3] {
        assert_eq!(
            dependents(3, column),
            cells(&page, &[(3, 4), totals[0], totals[1], totals[2]])
        );
    }
    // A Tutar: the totals.
    assert_eq!(dependents(1, 4), cells(&page, &totals));
    assert_eq!(dependents(5, 4), cells(&page, &totals[1..]));
    assert_eq!(dependents(6, 4), cells(&page, &totals[2..]));
    assert!(dependents(7, 4).is_empty());
    // The row number, the description, a label, a header: nothing.
    for (row, column) in [(1, 0), (1, 1), (5, 3), (0, 4)] {
        assert!(dependents(row, column).is_empty(), "{row} {column}");
    }
    // Not a cell.
    let title = block(&page, "FATURA");
    assert!(dependent_cells(&page, title.id).is_empty());
}
