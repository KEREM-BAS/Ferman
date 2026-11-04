//! A page's text blocks through the facade (ROADMAP §7 step 1, docs/ARCHITECTURE.md §3.5): the
//! blocks of kira-tr, a hit test and a selection across blocks; the document's reasons
//! (restricted until the owner password, damaged); a scan and a Type3 page.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;
use std::sync::OnceLock;

use ferman_api::facade::{
    Alignment, BlockId, Editability, Engine, EngineConfig, ErrorKind, NotEditableReason,
    OpenedDocument, Password, PdfiumLibrary, TextPosition, block_on,
};

/// One engine for the whole test binary: one render thread of a process may hold PDFium.
fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
        Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Path(library.into()),
        })
    })
}

fn open(name: &str) -> OpenedDocument {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"));
    block_on(engine().open(path, None)).unwrap()
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn kira_has_its_blocks_a_caret_and_a_selection() {
    let kira = open("kira-tr");
    let page = block_on(engine().text_blocks(kira.id, 0)).unwrap();
    assert_eq!(page.empty, None);
    let title = page.blocks.first().unwrap();
    assert_eq!(title.lines.first().unwrap().text, "KONUT KİRA SÖZLEŞMESİ");
    assert_eq!(title.alignment, Alignment::Center);
    assert!(
        page.blocks
            .iter()
            .all(|block| block.editability.is_editable())
    );
    let parties = page
        .blocks
        .iter()
        .find(|block| block.lines.len() == 3 && block.alignment == Alignment::Justified)
        .unwrap();
    // The frame is in page space, y down: the title sits above the parties.
    assert!(title.frame[3] <= parties.frame[1]);

    // A click before the second line's first letter puts the caret at its start.
    let second = parties.lines.get(1).unwrap();
    let point = [
        second.bbox[0] + 0.5,
        (second.bbox[1] + second.bbox[3]) / 2.0,
    ];
    let caret = block_on(engine().caret_at(kira.id, 0, parties.id, point)).unwrap();
    let first_len = u32::try_from(parties.lines.first().unwrap().text.chars().count()).unwrap();
    assert_eq!(caret.index, first_len + 1);
    assert!((caret.rect[0] - second.bbox[0]).abs() < 1.0);
    assert!(caret.rect[1] >= second.bbox[1] - 0.01 && caret.rect[3] <= second.bbox[3] + 0.01);

    // From the title's fifth character to the parties' first word, either way round.
    let from = TextPosition {
        block: title.id,
        index: 6,
    };
    let to = TextPosition {
        block: parties.id,
        index: 7,
    };
    let selection = block_on(engine().selection(kira.id, 0, from, to)).unwrap();
    assert!(selection.text.starts_with("KİRA SÖZLEŞMESİ\n"));
    assert!(selection.text.ends_with("\nKiraya "));
    assert!(selection.quads.len() >= 3);
    let back = block_on(engine().selection(kira.id, 0, to, from)).unwrap();
    assert_eq!(back, selection);

    let unknown = block_on(engine().caret_at(kira.id, 0, BlockId(1), point)).unwrap_err();
    assert_eq!(unknown.kind, ErrorKind::NotFound);
    let no_page = block_on(engine().text_blocks(kira.id, 99)).unwrap_err();
    assert_eq!(no_page.kind, ErrorKind::InvalidInput);
    block_on(engine().close(kira.id)).unwrap();
    let closed = block_on(engine().text_blocks(kira.id, 0)).unwrap_err();
    assert_eq!(closed.kind, ErrorKind::NotFound);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn the_document_reasons_reach_every_block() {
    let restricted = open("kira-tr-restricted");
    let page = block_on(engine().text_blocks(restricted.id, 0)).unwrap();
    assert!(!page.blocks.is_empty());
    assert!(
        page.blocks
            .iter()
            .all(|block| block.editability
                == Editability::NotEditable(NotEditableReason::Restricted))
    );
    block_on(engine().unlock_owner(restricted.id, Password::new("Kaya-Moda-18".to_owned())))
        .unwrap();
    let page = block_on(engine().text_blocks(restricted.id, 0)).unwrap();
    assert!(
        page.blocks
            .iter()
            .all(|block| block.editability.is_editable())
    );

    let damaged = open("kira-tr-damaged");
    let page = block_on(engine().text_blocks(damaged.id, 0)).unwrap();
    assert!(!page.blocks.is_empty());
    assert!(
        page.blocks
            .iter()
            .all(|block| block.editability == Editability::NotEditable(NotEditableReason::Damaged))
    );
    for id in [restricted.id, damaged.id] {
        block_on(engine().close(id)).unwrap();
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_scan_has_no_blocks_and_type3_text_has_its_lines() {
    let scan = open("scan-tr");
    let page = block_on(engine().text_blocks(scan.id, 0)).unwrap();
    assert!(page.blocks.is_empty());
    assert_eq!(page.empty, Some(NotEditableReason::ImageOnly));

    let type3 = open("edit-e16-type3");
    let page = block_on(engine().text_blocks(type3.id, 0)).unwrap();
    let lines: Vec<&str> = page
        .blocks
        .iter()
        .flat_map(|block| block.lines.iter().map(|line| line.text.as_str()))
        .collect();
    assert_eq!(
        lines,
        [
            "Delivery note",
            "Received in good order: 12 boxes of printer paper.",
            "Signed for the store by M. Kaya on 2 November 2026.",
        ]
    );
    for id in [scan.id, type3.id] {
        block_on(engine().close(id)).unwrap();
    }
}
