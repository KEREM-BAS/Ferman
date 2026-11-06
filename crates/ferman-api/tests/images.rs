//! An image's own page as PDFium draws it: a JPEG passed through, a mask from alpha and a CMYK JPEG
//! with and without Adobe's inverted samples, each on a page that replaces kira-tr's first, saved
//! and opened from the update's bytes.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;
use std::sync::Arc;

use ferman_api::facade::block_on;
use ferman_core::limits::Limits;
use ferman_core::revision::RevisionStore;
use ferman_core::write::Value;
use ferman_core::{OpenOptions, Source, open};
use ferman_ops::images::{Paper, image_page, load};
use ferman_render::{PageSize, RenderConfig, RenderThread, render_page};

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

/// kira-tr with its first page turned into `file`'s page.
fn with_image_page(file: &[u8]) -> Vec<u8> {
    let path = root().join("tests/corpus/generated/kira-tr.pdf");
    let doc = open(&Source::read(&path).unwrap(), &OpenOptions::default()).unwrap();
    let mut store = RevisionStore::new(&doc);
    let image = load(file, &Limits::default()).unwrap();
    store.begin().unwrap();
    let page = image_page(&doc, &mut store, &image, Paper::Letter).unwrap();
    let Some(Value::Dictionary(entries)) = store.object(&doc, page).unwrap() else {
        panic!("not a dictionary");
    };
    for (key, value) in entries {
        store.set_page_entry(&doc, 0, &key, value).unwrap();
    }
    store.commit().unwrap();
    store.incremental_update(&doc).unwrap()
}

/// `[blue, green, red]` of each point `(x, y)` from the page's top left, at 72 dpi.
fn colours(render: &RenderThread, pdf: Vec<u8>, points: &[(usize, usize)]) -> Vec<[u8; 3]> {
    let opened = block_on(render.open_document(Arc::from(pdf), None)).unwrap();
    let size = PageSize {
        width: 612.0,
        height: 792.0,
    };
    let page = block_on(render_page(render, opened.id, 0, size, 72)).unwrap();
    block_on(render.close_document(opened.id)).unwrap();
    points
        .iter()
        .map(|&(x, y)| {
            let at = (y * page.width as usize + x) * 4;
            [page.pixels[at], page.pixels[at + 1], page.pixels[at + 2]]
        })
        .collect()
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn pdfium_draws_each_kind_of_image_page() {
    let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
    let render = RenderThread::start(RenderConfig {
        pdfium_library: Some(PathBuf::from(library)),
        tile_cache_bytes: 0,
        ..RenderConfig::default()
    })
    .unwrap();
    let seed = |name: &str| std::fs::read(root().join("fuzz/seeds/images").join(name)).unwrap();
    let middle = |name: &str| colours(&render, with_image_page(&seed(name)), &[(306, 396)])[0];

    let bgr = middle("rgb.jpg");
    assert!(bgr[2] > 150 && bgr[1] < 90 && bgr[0] < 70, "JPEG: {bgr:?}");

    // Every stored sample is 255: no ink when Adobe's inverted, full ink when not.
    let bgr = middle("cmyk-adobe.jpg");
    assert!(bgr.iter().all(|&value| value > 240), "Adobe CMYK: {bgr:?}");
    let bgr = middle("cmyk-plain.jpg");
    assert!(bgr.iter().all(|&value| value < 60), "plain CMYK: {bgr:?}");

    // alpha.png, 5 × 3 and filling the page's width: near-black, its middle pixel at a quarter
    // over the page's white, which also shows above the image.
    let grid = colours(
        &render,
        with_image_page(&seed("alpha.png")),
        &[(61, 396), (306, 396), (306, 200)],
    );
    assert!(grid[0].iter().all(|&value| value < 30), "{grid:?}");
    assert!(grid[1].iter().all(|&value| value > 150), "{grid:?}");
    assert!(grid[2].iter().all(|&value| value > 240), "{grid:?}");
}
