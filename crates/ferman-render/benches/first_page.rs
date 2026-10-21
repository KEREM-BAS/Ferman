//! The engine's part of "first page visible" (docs/ARCHITECTURE.md §14): PDFium loads the
//! 500-page `long-500` and reads every page size, and the first sharp tile of page 1 renders, at
//! 100 % with a device pixel ratio of 2 and cold caches. Also the parts on their own, and a tile of
//! a page already loaded.
//!
//! Needs the PDFium library (`FERMAN_PDFIUM_PATH`, absolute) and `long-500.pdf`, which is over
//! 1 MB and so not committed: `cargo run --manifest-path tools/corpus/Cargo.toml -- generate`
//! makes it. Without either the benchmark says so and measures nothing.
//!
//! ```sh
//! FERMAN_PDFIUM_PATH="$PWD/build/pdfium/<id>/lib/<libpdfium>" cargo bench -p ferman-render --bench first_page
//! ```
// A benchmark is a program: it reports on stderr and fails loudly.
#![allow(
    clippy::print_stderr,
    clippy::expect_used,
    clippy::unwrap_used,
    clippy::panic
)]

use std::future::Future;
use std::path::PathBuf;
use std::sync::Arc;
use std::task::{Context, Poll, Wake, Waker};
use std::thread;
use std::time::Duration;

use criterion::Criterion;
use crossbeam_channel::{Receiver, unbounded};
use ferman_render::{
    DocumentId, Item, PdfiumStatus, Priority, RenderConfig, RenderThread, TilePosition,
    TileRequest, ViewEvent, ViewId, Wanted, ZoomBucket,
};

struct Unpark(thread::Thread);

impl Wake for Unpark {
    fn wake(self: Arc<Self>) {
        self.0.unpark();
    }
}

fn block_on<F: Future>(future: F) -> F::Output {
    let waker = Waker::from(Arc::new(Unpark(thread::current())));
    let mut cx = Context::from_waker(&waker);
    let mut future = std::pin::pin!(future);
    loop {
        if let Poll::Ready(output) = future.as_mut().poll(&mut cx) {
            return output;
        }
        thread::park_timeout(Duration::from_millis(10));
    }
}

/// The first tile of page 1 at 100 % and a device pixel ratio of 2.
fn first_tile(column: u32, row: u32) -> Wanted {
    Wanted {
        item: Item::Tile(TileRequest {
            page: 0,
            zoom: ZoomBucket::new(0).unwrap(),
            device_pixel_ratio: 2.0,
            position: TilePosition { column, row },
        }),
        priority: Priority::Visible,
    }
}

/// Opens a view, asks for `wanted` and waits for its bitmap.
fn render(render: &RenderThread, document: DocumentId, wanted: Wanted) {
    let (sender, events): (_, Receiver<ViewEvent>) = unbounded();
    let view: ViewId = block_on(render.open_view(document, Box::new(sender))).unwrap();
    render.request(view, 1, vec![wanted]).unwrap();
    match events.recv_timeout(Duration::from_secs(30)).unwrap() {
        ViewEvent::Rendered(rendered) => assert_eq!(rendered.rect.width, 512),
        ViewEvent::Failed(failed) => panic!("{failed:?}"),
    }
    render.close_view(view).unwrap();
}

fn main() {
    let Some(library) = std::env::var_os("FERMAN_PDFIUM_PATH").filter(|path| !path.is_empty())
    else {
        eprintln!("first_page: FERMAN_PDFIUM_PATH is not set, so nothing is measured");
        return;
    };
    let path =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/corpus/generated/long-500.pdf");
    let Ok(bytes) = std::fs::read(&path) else {
        eprintln!(
            "first_page: {} is missing (tools/corpus generate makes it), so nothing is measured",
            path.display()
        );
        return;
    };
    let bytes: Arc<[u8]> = bytes.into();
    // No caches: every iteration renders.
    let thread = RenderThread::start(RenderConfig {
        pdfium_library: Some(PathBuf::from(library)),
        tile_cache_bytes: 0,
        thumbnail_cache_bytes: 0,
        loaded_pages: 1,
    })
    .unwrap();
    assert!(matches!(
        block_on(thread.status()).unwrap(),
        PdfiumStatus::Loaded { .. }
    ));

    let mut criterion = Criterion::default()
        .sample_size(30)
        .measurement_time(Duration::from_secs(10))
        .configure_from_args();
    criterion.bench_function("first_page/open_500_pages", |bench| {
        bench.iter(|| {
            let document = block_on(thread.open_document(Arc::clone(&bytes), None)).unwrap();
            assert_eq!(document.pages.len(), 500);
            block_on(thread.close_document(document.id)).unwrap();
        });
    });
    criterion.bench_function("first_page/open_and_first_tile", |bench| {
        bench.iter(|| {
            let document = block_on(thread.open_document(Arc::clone(&bytes), None)).unwrap();
            render(&thread, document.id, first_tile(0, 0));
            block_on(thread.close_document(document.id)).unwrap();
        });
    });
    let document = block_on(thread.open_document(Arc::clone(&bytes), None)).unwrap();
    criterion.bench_function("first_page/tile_of_a_loaded_page", |bench| {
        bench.iter(|| render(&thread, document.id, first_tile(1, 1)));
    });
    criterion.final_summary();
}
