//! The render thread with PDFium: documents, tiles, thumbnails, the queue and its caches, the
//! determinism ROADMAP §6 step 1 asks for, and a stress run of three views at once.
//!
//! Every test needs the PDFium library (`tools/pdfium/fetch.sh`, then an absolute
//! `FERMAN_PDFIUM_PATH`), so each is `#[ignore]`d and CI runs them on the three systems. The corpus
//! files come from `tests/corpus/generated/` (ADR 0020). The stress run lasts
//! `FERMAN_RENDER_STRESS_SECONDS` seconds, 20 by default; the 10-minute run of the acceptance
//! criterion sets it to 600.
#![allow(clippy::panic, clippy::expect_used, clippy::unwrap_used)]

use std::future::Future;
use std::path::PathBuf;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::task::{Context, Poll, Wake, Waker};
use std::thread;
use std::time::{Duration, Instant};

use crossbeam_channel::{Receiver, RecvTimeoutError, unbounded};
use ferman_render::{
    DocumentId, FailReason, Item, PageSize, PdfiumStatus, PixelRect, Priority, RenderConfig,
    RenderError, RenderThread, Rendered, ThumbnailRequest, TilePosition, TileRequest, ViewEvent,
    ViewId, Wanted, ZoomBucket,
};

/// How long a test waits for one event before it calls the render thread stuck.
const PATIENCE: Duration = Duration::from_secs(60);

struct Unpark(thread::Thread);

impl Wake for Unpark {
    fn wake(self: Arc<Self>) {
        self.0.unpark();
    }
}

/// Runs a future to completion on this thread, parked between polls.
fn block_on<F: Future>(future: F) -> F::Output {
    let waker = Waker::from(Arc::new(Unpark(thread::current())));
    let mut cx = Context::from_waker(&waker);
    let mut future = std::pin::pin!(future);
    loop {
        if let Poll::Ready(output) = future.as_mut().poll(&mut cx) {
            return output;
        }
        thread::park_timeout(Duration::from_millis(50));
    }
}

fn config() -> RenderConfig {
    let path = std::env::var_os("FERMAN_PDFIUM_PATH")
        .filter(|value| !value.is_empty())
        .expect("FERMAN_PDFIUM_PATH must name the PDFium library (tools/pdfium/fetch.sh)");
    RenderConfig {
        pdfium_library: Some(PathBuf::from(path)),
        ..RenderConfig::default()
    }
}

/// Taken by every test before it starts a render thread: only one render thread of a process may
/// hold PDFium at a time.
fn serial() -> MutexGuard<'static, ()> {
    static SERIAL: Mutex<()> = Mutex::new(());
    SERIAL.lock().unwrap_or_else(PoisonError::into_inner)
}

fn start(config: RenderConfig) -> RenderThread {
    let render = RenderThread::start(config).unwrap();
    assert!(matches!(
        block_on(render.status()).unwrap(),
        PdfiumStatus::Loaded { .. }
    ));
    render
}

/// A file of `tests/corpus/generated/`.
fn corpus(name: &str) -> Arc<[u8]> {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"));
    std::fs::read(&path)
        .unwrap_or_else(|err| panic!("{}: {err}", path.display()))
        .into()
}

/// A PDF with one page per `(width, height, rotate, content)`, written with a correct
/// cross-reference table. The content may use `/F1`, Helvetica.
fn pdf(pages: &[(f32, f32, i32, &str)]) -> Arc<[u8]> {
    let mut objects: Vec<String> = Vec::new();
    let kids: Vec<String> = (0..pages.len())
        .map(|index| format!("{} 0 R", 4 + 2 * index))
        .collect();
    objects.push("<< /Type /Catalog /Pages 2 0 R >>".to_owned());
    objects.push(format!(
        "<< /Type /Pages /Kids [{}] /Count {} >>",
        kids.join(" "),
        pages.len()
    ));
    objects.push("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>".to_owned());
    for (index, (width, height, rotate, content)) in pages.iter().enumerate() {
        objects.push(format!(
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {width} {height}] /Rotate {rotate} \
             /Resources << /Font << /F1 3 0 R >> >> /Contents {} 0 R >>",
            5 + 2 * index
        ));
        objects.push(format!(
            "<< /Length {} >>\nstream\n{content}\nendstream",
            content.len() + 1
        ));
    }
    let mut out = b"%PDF-1.7\n".to_vec();
    let mut offsets = Vec::new();
    for (index, object) in objects.iter().enumerate() {
        offsets.push(out.len());
        out.extend_from_slice(format!("{} 0 obj\n{object}\nendobj\n", index + 1).as_bytes());
    }
    let xref = out.len();
    out.extend_from_slice(
        format!("xref\n0 {}\n0000000000 65535 f \n", objects.len() + 1).as_bytes(),
    );
    for offset in offsets {
        out.extend_from_slice(format!("{offset:010} 00000 n \n").as_bytes());
    }
    out.extend_from_slice(
        format!(
            "trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n",
            objects.len() + 1
        )
        .as_bytes(),
    );
    out.into()
}

/// A red square over the top-left quarter of a 200 × 100 page, as PDF content.
const RED_CORNER: &str = "1 0 0 rg 0 50 100 50 re f";

fn tile(page: u32, zoom: i16, ratio: f32, column: u32, row: u32) -> Item {
    Item::Tile(TileRequest {
        page,
        zoom: ZoomBucket::new(zoom).unwrap(),
        device_pixel_ratio: ratio,
        position: TilePosition { column, row },
    })
}

fn visible(items: &[Item]) -> Vec<Wanted> {
    items
        .iter()
        .map(|item| Wanted {
            item: *item,
            priority: Priority::Visible,
        })
        .collect()
}

/// Every tile of `page` at `zoom` and `ratio`, row by row.
fn all_tiles(size: PageSize, page: u32, zoom: i16, ratio: f32) -> Vec<Item> {
    let scale = ZoomBucket::new(zoom).unwrap().zoom() * f64::from(ratio);
    let (width, height) = size.raster(scale).unwrap();
    let columns = width.div_ceil(ferman_render::TILE_SIZE);
    let rows = height.div_ceil(ferman_render::TILE_SIZE);
    (0..rows)
        .flat_map(|row| (0..columns).map(move |column| tile(page, zoom, ratio, column, row)))
        .collect()
}

/// An open view and its events.
struct View {
    id: ViewId,
    events: Receiver<ViewEvent>,
    generation: u64,
}

impl View {
    fn open(render: &RenderThread, document: DocumentId) -> Self {
        let (sender, events) = unbounded();
        let id = block_on(render.open_view(document, Box::new(sender))).unwrap();
        Self {
            id,
            events,
            generation: 0,
        }
    }

    fn want(&mut self, render: &RenderThread, wanted: Vec<Wanted>) {
        self.generation += 1;
        render.request(self.id, self.generation, wanted).unwrap();
    }

    fn next(&self) -> ViewEvent {
        self.events
            .recv_timeout(PATIENCE)
            .expect("the render thread sent nothing in time")
    }

    /// Renders `items` and returns them in the order asked.
    fn render(&mut self, render: &RenderThread, items: &[Item]) -> Vec<Rendered> {
        self.want(render, visible(items));
        let mut got: Vec<Option<Rendered>> = vec![None; items.len()];
        for _ in items {
            match self.next() {
                ViewEvent::Rendered(rendered) => {
                    let index = items
                        .iter()
                        .position(|item| *item == rendered.item)
                        .unwrap();
                    got[index] = Some(rendered);
                }
                ViewEvent::Failed(failed) => panic!("{failed:?}"),
            }
        }
        got.into_iter().map(Option::unwrap).collect()
    }
}

fn pixel(bitmap: &Rendered, x: u32, y: u32) -> [u8; 4] {
    let at = usize::try_from(y * bitmap.stride + x * 4).unwrap();
    bitmap.pixels[at..at + 4].try_into().unwrap()
}

/// `tiles` copied into one bitmap the size of `whole`.
fn assemble(tiles: &[Rendered], whole: &Rendered) -> Vec<u8> {
    let mut assembled = vec![0u8; whole.pixels.len()];
    for part in tiles {
        for row in 0..part.rect.height {
            let from = usize::try_from(row * part.stride).unwrap();
            let to = usize::try_from((part.rect.y + row) * whole.stride + part.rect.x * 4).unwrap();
            let length = usize::try_from(part.stride).unwrap();
            assembled[to..to + length].copy_from_slice(&part.pixels[from..from + length]);
        }
    }
    assembled
}

/// Tiles are rendered with a margin, so put together they are the page rendered whole, up to two
/// levels of antialiasing where PDFium's clip moves the rounding of an edge drawn as a path, in
/// fewer than one pixel in a hundred.
fn assert_within_two_levels(assembled: &[u8], whole: &[u8], what: &str) {
    let mut differing = 0;
    for (index, (a, b)) in assembled.chunks(4).zip(whole.chunks(4)).enumerate() {
        if a != b {
            differing += 1;
            let most = a
                .iter()
                .zip(b)
                .map(|(a, b)| a.abs_diff(*b))
                .max()
                .unwrap_or(0);
            assert!(
                most <= 2,
                "{what}: pixel {index} differs by {most}: {a:?} and {b:?}"
            );
        }
    }
    assert!(
        differing < whole.len() / 4 / 100,
        "{what}: {differing} pixels differ between the tiles and the page"
    );
}

const RED: [u8; 4] = [0, 0, 255, 255];
const WHITE: [u8; 4] = [255, 255, 255, 255];

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn page_sizes_are_as_displayed() {
    let _serial = serial();
    let render = start(config());
    let document = block_on(render.open_document(pdf(&[
        (200.0, 100.0, 0, RED_CORNER),
        (200.0, 100.0, 90, RED_CORNER),
    ])))
    .unwrap();
    assert_eq!(
        document.pages,
        [
            PageSize {
                width: 200.0,
                height: 100.0
            },
            PageSize {
                width: 100.0,
                height: 200.0
            },
        ]
    );
    let kira = block_on(render.open_document(corpus("kira-tr"))).unwrap();
    assert!(kira.pages.len() > 1);
    for size in &kira.pages {
        assert!((size.width - 595.28).abs() < 0.01, "{size:?}");
        assert!((size.height - 841.89).abs() < 0.01, "{size:?}");
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_tile_is_opaque_bgra_with_the_top_left_first() {
    let _serial = serial();
    let render = start(config());
    let document = block_on(render.open_document(pdf(&[
        (200.0, 100.0, 0, RED_CORNER),
        (200.0, 100.0, 90, RED_CORNER),
    ])))
    .unwrap();
    let mut view = View::open(&render, document.id);
    let [upright, turned] = view
        .render(&render, &[tile(0, 0, 1.0, 0, 0), tile(1, 0, 1.0, 0, 0)])
        .try_into()
        .unwrap();
    assert_eq!(
        upright.rect,
        PixelRect {
            x: 0,
            y: 0,
            width: 200,
            height: 100
        }
    );
    assert_eq!(upright.stride, 800);
    assert_eq!(upright.pixels.len(), 200 * 100 * 4);
    assert!(upright.pixels.chunks(4).all(|bgra| bgra[3] == 255));
    assert_eq!(pixel(&upright, 10, 10), RED);
    assert_eq!(pixel(&upright, 90, 40), RED);
    assert_eq!(pixel(&upright, 150, 10), WHITE);
    assert_eq!(pixel(&upright, 10, 80), WHITE);
    // /Rotate 90 turns the page clockwise: its top-left corner is now at the top right.
    assert_eq!((turned.rect.width, turned.rect.height), (100, 200));
    assert_eq!(pixel(&turned, 90, 10), RED);
    assert_eq!(pixel(&turned, 10, 10), WHITE);
    assert_eq!(pixel(&turned, 90, 150), WHITE);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn tiles_put_together_are_the_whole_page() {
    let _serial = serial();
    // At scale 1 a 1000 × 600 page is a 1000-pixel thumbnail and four tiles; text, curves and
    // thin lines cross the tile seams.
    let content = "0 0 1 RG 0.6 w 10 10 m 990 590 l S 10 590 m 990 10 l S \
                   0 0.5 0 rg 300 300 m 300 450 450 512 600 512 c 750 512 800 400 800 300 c f \
                   0 g BT /F1 37 Tf 380 500 Td (Ferman tiles: seams 512) Tj ET \
                   BT /F1 9 Tf 500 85 Td (small text across the seam at x = 512) Tj ET";
    let render = start(config());
    let document = block_on(render.open_document(pdf(&[(1000.0, 600.0, 0, content)]))).unwrap();
    let mut view = View::open(&render, document.id);
    let thumbnail = Item::Thumbnail(ThumbnailRequest {
        page: 0,
        size: 1000,
    });
    let tiles = all_tiles(document.pages[0], 0, 0, 1.0);
    assert_eq!(tiles.len(), 4);
    let whole = view.render(&render, &[thumbnail]).remove(0);
    assert_eq!((whole.rect.width, whole.rect.height), (1000, 600));
    let assembled = assemble(&view.render(&render, &tiles), &whole);
    assert_within_two_levels(&assembled, &whole.pixels, "lines, a curve and text");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn text_across_tile_edges_has_no_seam() {
    let _serial = serial();
    let render = start(config());
    // Lines of text from 3 to 35 points, at device pixel ratios 1, 2 and 4: glyphs from PDFium's
    // glyph cache cross every tile edge, and the largest are drawn as paths.
    for ratio in [1.0f32, 2.0, 4.0] {
        let side = 1000.0 / ratio;
        let mut content = String::new();
        let mut y = side - 10.0 / ratio;
        let mut size = 3.0f32;
        while y > 10.0 / ratio {
            let x = (3.0 + (y * 7.3 * ratio) % 40.0) / ratio;
            content.push_str(&format!(
                "BT /F1 {size} Tf {x} {y} Td (The quick brown fox jumps over the lazy dog \
                 0123456789 WWW mmm) Tj ET "
            ));
            y -= size * 1.13;
            size = if size > 30.0 { 3.0 } else { size * 1.17 };
        }
        let document = block_on(render.open_document(pdf(&[(side, side, 0, &content)]))).unwrap();
        let mut view = View::open(&render, document.id);
        let thumbnail = Item::Thumbnail(ThumbnailRequest {
            page: 0,
            size: 1000,
        });
        let whole = view.render(&render, &[thumbnail]).remove(0);
        assert_eq!((whole.rect.width, whole.rect.height), (1000, 1000));
        let tiles = view.render(&render, &all_tiles(document.pages[0], 0, 0, ratio));
        assert_eq!(tiles.len(), 4);
        assert_within_two_levels(
            &assemble(&tiles, &whole),
            &whole.pixels,
            &format!("ratio {ratio}"),
        );
        block_on(render.close_document(document.id)).unwrap();
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn rendering_is_deterministic_in_ten_runs() {
    let _serial = serial();
    // No caches, and the document reopened for every run, so each run renders afresh.
    let render = start(RenderConfig {
        tile_cache_bytes: 0,
        thumbnail_cache_bytes: 0,
        loaded_pages: 1,
        ..config()
    });
    for name in [
        "kira-tr",
        "report-ar",
        "letter-ja-vertical",
        "scan-tr",
        "quote-ja-scan",
        "form-aks1-tr",
        "ocg-plan",
        "tez-tr",
    ] {
        let mut first: Option<Vec<Rendered>> = None;
        for run in 0..10 {
            let document = block_on(render.open_document(corpus(name))).unwrap();
            let size = document.pages[0];
            let mut items = all_tiles(size, 0, 0, 2.0);
            // A deep-zoom tile in the middle of the page, and a thumbnail.
            items.push(tile(0, 12, 1.0, 5, 7));
            items.push(Item::Thumbnail(ThumbnailRequest { page: 0, size: 240 }));
            let mut view = View::open(&render, document.id);
            let bitmaps = view.render(&render, &items);
            block_on(render.close_document(document.id)).unwrap();
            match &first {
                None => first = Some(bitmaps),
                Some(first) => {
                    for (a, b) in first.iter().zip(&bitmaps) {
                        assert_eq!(a.rect, b.rect, "{name}, run {run}: {:?}", a.item);
                        assert!(
                            a.pixels == b.pixels,
                            "{name}, run {run}: {:?} differs",
                            a.item
                        );
                    }
                }
            }
        }
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn the_corpus_opens_as_pdfium_opens_it() {
    let _serial = serial();
    let render = start(config());
    for name in [
        "kira-tr",
        "kira-tr-damaged",
        "kira-tr-restricted",
        "xfa-visa",
        "js-openaction",
    ] {
        let document = block_on(render.open_document(corpus(name)))
            .unwrap_or_else(|err| panic!("{name}: {err}"));
        assert!(!document.pages.is_empty(), "{name}");
        block_on(render.close_document(document.id)).unwrap();
    }
    for name in [
        "payslip-aes256",
        "payslip-aes128",
        "payslip-rc4-40",
        "payslip-rc4-128",
    ] {
        assert!(
            matches!(
                block_on(render.open_document(corpus(name))),
                Err(RenderError::PasswordRequired)
            ),
            "{name}"
        );
    }
    assert!(matches!(
        block_on(render.open_document(corpus("truncated"))),
        Err(RenderError::Damaged { .. })
    ));
    assert!(matches!(
        block_on(render.open_document(Arc::from(&b"this is not a PDF"[..]))),
        Err(RenderError::Damaged { .. })
    ));
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn items_out_of_range_fail_at_once() {
    let _serial = serial();
    let render = start(config());
    let document = block_on(render.open_document(pdf(&[(200.0, 100.0, 0, RED_CORNER)]))).unwrap();
    let mut view = View::open(&render, document.id);
    view.want(
        &render,
        visible(&[
            tile(5, 0, 1.0, 0, 0),
            tile(0, 0, 1.0, 1, 0),
            tile(0, 0, 9.0, 0, 0),
            Item::Thumbnail(ThumbnailRequest { page: 0, size: 4 }),
        ]),
    );
    let mut reasons = Vec::new();
    for _ in 0..4 {
        match view.next() {
            ViewEvent::Failed(failed) => {
                assert_eq!(failed.generation, 1);
                reasons.push(failed.reason);
            }
            ViewEvent::Rendered(rendered) => panic!("rendered {:?}", rendered.item),
        }
    }
    assert_eq!(
        reasons,
        [
            FailReason::NoSuchPage,
            FailReason::OutOfRange,
            FailReason::OutOfRange,
            FailReason::OutOfRange
        ]
    );
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_newer_wanted_set_replaces_the_older_one() {
    let _serial = serial();
    let render = start(RenderConfig {
        tile_cache_bytes: 0,
        ..config()
    });
    let document = block_on(render.open_document(corpus("tez-tr"))).unwrap();
    let mut view = View::open(&render, document.id);
    // Many deep-zoom tiles, then at once a set of one: only the tiles rendered before the second
    // set arrived reach the view, which is one unless the system holds this thread back.
    let many: Vec<Item> = (0..30).map(|column| tile(0, 16, 2.0, column, 3)).collect();
    view.want(&render, visible(&many));
    let wanted = tile(1, 0, 1.0, 0, 0);
    view.want(&render, visible(&[wanted]));
    let mut old = 0;
    loop {
        match view.next() {
            ViewEvent::Rendered(rendered) if rendered.item == wanted => {
                assert_eq!(rendered.generation, 2);
                break;
            }
            ViewEvent::Rendered(rendered) => {
                assert!(many.contains(&rendered.item));
                old += 1;
            }
            ViewEvent::Failed(failed) => panic!("{failed:?}"),
        }
    }
    assert!(old <= 3, "{old} tiles of the replaced set were delivered");
    // An older generation than the newest is ignored.
    render.request(view.id, 1, visible(&many)).unwrap();
    assert!(matches!(
        view.events.recv_timeout(Duration::from_millis(500)),
        Err(RecvTimeoutError::Timeout)
    ));
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn cached_bitmaps_are_the_rendered_ones() {
    let _serial = serial();
    let render = start(config());
    let document = block_on(render.open_document(corpus("kira-tr"))).unwrap();
    let mut first = View::open(&render, document.id);
    let mut second = View::open(&render, document.id);
    let items = [
        tile(0, 0, 2.0, 1, 1),
        Item::Thumbnail(ThumbnailRequest { page: 1, size: 180 }),
    ];
    let rendered = first.render(&render, &items);
    let cached = second.render(&render, &items);
    let again = first.render(&render, &items);
    for ((a, b), c) in rendered.iter().zip(&cached).zip(&again) {
        assert_eq!(a.pixels, b.pixels);
        assert_eq!(a.pixels, c.pixels);
        assert_eq!(a.render_key, 0);
    }
    assert_eq!(again[0].generation, 2);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn closing_a_document_ends_its_views() {
    let _serial = serial();
    let render = start(config());
    let document = block_on(render.open_document(corpus("kira-tr"))).unwrap();
    let mut view = View::open(&render, document.id);
    view.want(&render, visible(&all_tiles(document.pages[0], 0, 0, 2.0)));
    block_on(render.close_document(document.id)).unwrap();
    // Whatever was delivered before the close, the stream then ends.
    let deadline = Instant::now() + PATIENCE;
    loop {
        match view.events.recv_deadline(deadline) {
            Ok(_) => {}
            Err(RecvTimeoutError::Disconnected) => break,
            Err(RecvTimeoutError::Timeout) => panic!("the view did not end"),
        }
    }
    assert!(matches!(
        block_on(render.close_document(document.id)),
        Err(RenderError::NotFound { what: "document" })
    ));
    let (sender, _events) = unbounded();
    assert!(matches!(
        block_on(render.open_view(document.id, Box::new(sender))),
        Err(RenderError::NotFound { .. })
    ));
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn dropping_the_handle_while_rendering_stops_the_thread() {
    let _serial = serial();
    let render = start(config());
    let document = block_on(render.open_document(corpus("tez-tr"))).unwrap();
    let mut view = View::open(&render, document.id);
    let many: Vec<Item> = (0..30).map(|column| tile(0, 16, 2.0, column, 3)).collect();
    view.want(&render, visible(&many));
    let started = Instant::now();
    drop(render);
    // The thread finished at most the tile it was rendering, closed the document and exited.
    assert!(started.elapsed() < Duration::from_secs(20));
    let deadline = Instant::now() + PATIENCE;
    while view.events.recv_deadline(deadline).is_ok() {}
}

/// A small deterministic generator, so the stress run is the same on every system.
struct Lcg(u64);

impl Lcg {
    fn next(&mut self, below: u32) -> u32 {
        self.0 = self
            .0
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(1_442_695_040_888_963_407);
        u32::try_from((self.0 >> 33) % u64::from(below)).unwrap()
    }
}

/// One client of the stress run: keeps replacing its view's wanted set with tiles and thumbnails
/// of random pages, zooms and positions, reads what arrives, and now and then closes its view and
/// opens a new one. Returns how many bitmaps it got.
fn client(
    render: &RenderThread,
    document: DocumentId,
    pages: &[PageSize],
    seed: u64,
    until: Instant,
) -> u64 {
    let mut random = Lcg(seed);
    let mut view = View::open(render, document);
    let mut rendered = 0;
    let mut rounds = 0u64;
    while Instant::now() < until {
        rounds += 1;
        if rounds.is_multiple_of(50) {
            render.close_view(view.id).unwrap();
            view = View::open(render, document);
        }
        let mut wanted = Vec::new();
        for _ in 0..1 + random.next(12) {
            let page = random.next(u32::try_from(pages.len()).unwrap());
            let zoom = i16::try_from(random.next(13)).unwrap() - 4;
            let ratio = [1.0, 1.5, 2.0][usize::try_from(random.next(3)).unwrap()];
            let scale = ZoomBucket::new(zoom).unwrap().zoom() * f64::from(ratio);
            let (width, height) = pages[usize::try_from(page).unwrap()].raster(scale).unwrap();
            let item = if random.next(5) == 0 {
                Item::Thumbnail(ThumbnailRequest {
                    page,
                    size: 64 + random.next(200),
                })
            } else {
                tile(
                    page,
                    zoom,
                    ratio,
                    random.next(width.div_ceil(512)),
                    random.next(height.div_ceil(512)),
                )
            };
            let priority = [Priority::Visible, Priority::Prefetch, Priority::Thumbnail]
                [usize::try_from(random.next(3)).unwrap()];
            wanted.push(Wanted { item, priority });
        }
        view.want(render, wanted);
        // Read for a moment, then replace the set, often before it is done.
        let wait = Duration::from_millis(u64::from(random.next(40)));
        let deadline = Instant::now() + wait;
        loop {
            match view.events.recv_deadline(deadline) {
                Ok(ViewEvent::Rendered(bitmap)) => {
                    assert!(bitmap.pixels.chunks(4).all(|bgra| bgra[3] == 255));
                    rendered += 1;
                }
                Ok(ViewEvent::Failed(failed)) => panic!("{failed:?}"),
                Err(RecvTimeoutError::Timeout) => break,
                Err(RecvTimeoutError::Disconnected) => panic!("the view ended"),
            }
        }
    }
    rendered
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn three_views_render_at_once_without_a_crash_or_a_deadlock() {
    let _serial = serial();
    let seconds = std::env::var("FERMAN_RENDER_STRESS_SECONDS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(20);
    // Small caps, so the caches evict all the time.
    let render = Arc::new(start(RenderConfig {
        tile_cache_bytes: 16 * 1024 * 1024,
        thumbnail_cache_bytes: 1024 * 1024,
        loaded_pages: 3,
        ..config()
    }));
    let kira = block_on(render.open_document(corpus("kira-tr"))).unwrap();
    let report = block_on(render.open_document(corpus("report-ar"))).unwrap();
    let until = Instant::now() + Duration::from_secs(seconds);
    // Two views of one document and one of another, each from its own thread.
    let clients: Vec<_> = [(kira.clone(), 1), (kira.clone(), 2), (report.clone(), 3)]
        .into_iter()
        .map(|(document, seed)| {
            let render = Arc::clone(&render);
            thread::spawn(move || client(&render, document.id, &document.pages, seed, until))
        })
        .collect();
    // Meanwhile documents open and close on the same thread.
    let mut opened = 0;
    while Instant::now() < until {
        let document = block_on(render.open_document(corpus("scan-tr"))).unwrap();
        let mut view = View::open(&render, document.id);
        view.render(&render, &[tile(0, 0, 1.0, 0, 0)]);
        block_on(render.close_document(document.id)).unwrap();
        opened += 1;
        thread::sleep(Duration::from_millis(200));
    }
    for (index, client) in clients.into_iter().enumerate() {
        let rendered = client.join().expect("a client panicked");
        assert!(rendered > 0, "client {index} got nothing");
    }
    assert!(opened > 0);
    // Still answering.
    assert!(matches!(
        block_on(render.status()).unwrap(),
        PdfiumStatus::Loaded { .. }
    ));
}
