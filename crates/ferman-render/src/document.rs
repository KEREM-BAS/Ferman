//! A document loaded into PDFium, its loaded pages, and rendering with Ferman's fixed flags.
//!
//! PDFium reads the document through a reader over the snapshot's shared bytes, so loading makes no
//! copy (docs/ARCHITECTURE.md §4.4). A small LRU keeps the pages being scrolled loaded; it is
//! dropped with the document, pages first, because PDFium must close a page before its document.
//!
//! # Render flags
//!
//! Every bitmap is rendered the same way, because the pixel-diff acceptance tests of M3 compare
//! renders byte for byte (ROADMAP §6 step 1):
//!
//! - **Into Ferman's own buffer**, filled opaque white first, in BGRA (no
//!   `FPDF_REVERSE_BYTE_ORDER`), as Flutter's `bgra8888` takes it. PDFium writes straight into the
//!   tile's `Vec`, so no copy follows.
//! - **With a matrix and a clip** (`FPDF_RenderPageBitmapWithMatrix`): the matrix scales the page
//!   as displayed (PDFium applies `/Rotate` first) and moves the tile's corner to the bitmap's
//!   origin; the clip is the whole bitmap. PDFium's form-fill overlay is off, which this path
//!   requires; widgets draw from their appearance streams like other annotations.
//! - **With a margin around each tile**, [`TILE_MARGIN`] pixels on every side, cut away after
//!   rendering. PDFium draws a glyph that crosses the edge of its bitmap differently from the same
//!   glyph inside it (by up to 136 of 255 levels in a few pixels next to the edge), so without the
//!   margin text would show a seam wherever it crosses a tile edge. Glyphs come from PDFium's glyph
//!   cache up to about 50 pixels; larger text and other paths are only moved by a level or two of
//!   antialiasing by a clip. With the margin, tiles put together match one render of the whole
//!   page to within two levels (the PDFium tests check text at device pixel ratios 1, 2 and 4). A
//!   full tile costs about 27 % more raster area. Thumbnails are whole pages and need none.
//! - **`FPDF_ANNOT`** on: annotations draw from their appearance streams.
//! - **Off:** `FPDF_LCD_TEXT` (subpixel text depends on the display), `FPDF_GRAYSCALE`,
//!   `FPDF_PRINTING`, `FPDF_RENDER_LIMITEDIMAGECACHE`, `FPDF_RENDER_FORCEHALFTONE`,
//!   `FPDF_CONVERT_FILL_TO_STROKE`, and the three `FPDF_RENDER_NO_SMOOTH*` flags, so text, images
//!   and paths are antialiased.
//! - **`FPDF_NO_NATIVETEXT`** on: text never goes through a platform text renderer.
//!
//! pdfium-render 0.9.4 exposes PDFium's progressive rendering (`FPDF_RenderPageBitmap_Start` with
//! a pause callback) only through its raw, unsafe bindings, which this crate does not use
//! (`#![forbid(unsafe_code)]`), so a slow tile always finishes once started.

use std::io::Cursor;
use std::num::NonZeroUsize;
use std::sync::Arc;

use lru::LruCache;
use pdfium_render::prelude::{
    PdfBitmap, PdfBitmapFormat, PdfDocument, PdfPage, PdfPageIndex, PdfRenderConfig, Pdfium,
    PdfiumError, PdfiumInternalError,
};

use crate::RenderError;
use crate::cache::Bitmap;
use crate::tiles::{FailReason, Item, PageSize, PixelRect};

/// The pixels rendered around a tile on every side and cut away, so no glyph the tile shows
/// crosses the edge of PDFium's bitmap (module documentation).
const TILE_MARGIN: u32 = 32;

/// One document in PDFium.
pub(crate) struct LoadedDocument<'p> {
    // Declared before `document`, so it is dropped first: PDFium closes pages before documents.
    pages: LruCache<u32, PdfPage<'p>>,
    document: PdfDocument<'p>,
    sizes: Vec<PageSize>,
    /// Each page's render key. Every page of a freshly loaded document has key 0; a reload of a
    /// revised document (M3) sets new keys for the pages whose pixels can change.
    render_keys: Vec<u64>,
}

impl Drop for LoadedDocument<'_> {
    fn drop(&mut self) {
        self.pages.clear();
    }
}

impl<'p> LoadedDocument<'p> {
    /// Loads `bytes` into PDFium and reads every page size without loading the pages.
    pub(crate) fn load(
        pdfium: &'p Pdfium,
        bytes: Arc<[u8]>,
        loaded_pages: NonZeroUsize,
    ) -> Result<Self, RenderError> {
        let document = pdfium
            .load_pdf_from_reader(Cursor::new(bytes), None)
            .map_err(open_error)?;
        let pages = document.pages();
        let count = pages.len();
        let mut sizes = Vec::new();
        sizes
            .try_reserve_exact(usize::try_from(count).unwrap_or(0))
            .map_err(|_| RenderError::OutOfMemory {
                context: "page sizes",
            })?;
        for index in 0..count {
            let rect = pages.page_size(index).map_err(|err| RenderError::Damaged {
                reason: format!("page {index} has no size: {err:?}"),
            })?;
            sizes.push(PageSize {
                width: rect.width().value,
                height: rect.height().value,
            });
        }
        let render_keys = vec![0; sizes.len()];
        Ok(Self {
            pages: LruCache::new(loaded_pages),
            document,
            sizes,
            render_keys,
        })
    }

    /// The size of every page, in points as displayed.
    pub(crate) fn sizes(&self) -> &[PageSize] {
        &self.sizes
    }

    /// The render key of `page`; 0 for a page the document does not have.
    pub(crate) fn render_key(&self, page: u32) -> u64 {
        usize::try_from(page)
            .ok()
            .and_then(|page| self.render_keys.get(page))
            .copied()
            .unwrap_or(0)
    }

    /// Checks that the document can render `item`.
    pub(crate) fn check(&self, item: &Item) -> Result<(), FailReason> {
        let size = self.size(item.page())?;
        item.raster(size).map(|_| ()).ok_or(FailReason::OutOfRange)
    }

    /// Renders `item`.
    pub(crate) fn render(&mut self, item: &Item) -> Result<Bitmap, FailReason> {
        let size = self.size(item.page())?;
        let (scale, rect) = item.raster(size).ok_or(FailReason::OutOfRange)?;
        let margin = match item {
            Item::Tile(_) => TILE_MARGIN,
            Item::Thumbnail(_) => 0,
        };
        let page = self.page(item.page())?;
        render(page, scale, rect, margin)
    }

    fn size(&self, page: u32) -> Result<PageSize, FailReason> {
        usize::try_from(page)
            .ok()
            .and_then(|page| self.sizes.get(page))
            .copied()
            .ok_or(FailReason::NoSuchPage)
    }

    /// The loaded page `index`, loading it (and closing the least recently used one) if needed.
    fn page(&mut self, index: u32) -> Result<&PdfPage<'p>, FailReason> {
        if !self.pages.contains(&index) {
            let pdfium_index = PdfPageIndex::try_from(index).map_err(|_| FailReason::NoSuchPage)?;
            let page = self
                .document
                .pages()
                .get(pdfium_index)
                .map_err(|_| FailReason::PageDamaged)?;
            self.pages.put(index, page);
        }
        self.pages.get(&index).ok_or(FailReason::Internal)
    }
}

/// Renders the pixels `rect` of `page`'s raster at `scale` pixels per point, drawn with `margin`
/// more pixels on every side that are then cut away.
fn render(
    page: &PdfPage<'_>,
    scale: f64,
    rect: PixelRect,
    margin: u32,
) -> Result<Bitmap, FailReason> {
    let grown = |side: u32| {
        side.checked_add(margin.checked_mul(2)?)
            .and_then(|side| i32::try_from(side).ok())
    };
    let width = grown(rect.width).ok_or(FailReason::OutOfRange)?;
    let height = grown(rect.height).ok_or(FailReason::OutOfRange)?;
    let mut canvas = white(width, height)?;
    {
        let mut bitmap = PdfBitmap::from_bytes(width, height, PdfBitmapFormat::BGRA, &mut canvas)
            .map_err(|_| FailReason::Internal)?;
        // Whole pixels below 2^24 (the raster limit) are exact in f32.
        #[allow(clippy::cast_possible_truncation, clippy::cast_precision_loss)]
        let (scale, left, top, margin) =
            (scale as f32, rect.x as f32, rect.y as f32, margin as f32);
        let config = configuration()
            .transform(scale, 0.0, 0.0, scale, margin - left, margin - top)
            .map_err(|_| FailReason::OutOfRange)?
            .clip(0, 0, width, height);
        page.render_into_bitmap_with_config(&mut bitmap, &config)
            .map_err(|_| FailReason::PageDamaged)?;
    }
    if margin == 0 {
        return Ok(Bitmap {
            rect,
            pixels: canvas,
        });
    }
    let row = bytes(rect.width, 1).ok_or(FailReason::OutOfRange)?;
    let canvas_row = usize::try_from(width).map_err(|_| FailReason::OutOfRange)?;
    let margin = usize::try_from(margin).map_err(|_| FailReason::OutOfRange)?;
    let mut pixels = Vec::new();
    pixels
        .try_reserve_exact(bytes(rect.width, rect.height).ok_or(FailReason::OutOfRange)?)
        .map_err(|_| FailReason::OutOfMemory)?;
    for line in 0..usize::try_from(rect.height).map_err(|_| FailReason::OutOfRange)? {
        let start = line
            .checked_add(margin)
            .and_then(|line| line.checked_mul(canvas_row))
            .and_then(|at| at.checked_add(margin))
            .and_then(|at| at.checked_mul(4))
            .ok_or(FailReason::OutOfRange)?;
        let source = start
            .checked_add(row)
            .and_then(|end| canvas.get(start..end))
            .ok_or(FailReason::Internal)?;
        pixels.extend_from_slice(source);
    }
    Ok(Bitmap { rect, pixels })
}

/// An opaque white BGRA buffer of `width × height` pixels: the page background, under everything
/// PDFium draws.
fn white(width: i32, height: i32) -> Result<Vec<u8>, FailReason> {
    let length = u32::try_from(width)
        .ok()
        .zip(u32::try_from(height).ok())
        .and_then(|(width, height)| bytes(width, height))
        .ok_or(FailReason::OutOfRange)?;
    let mut pixels = Vec::new();
    pixels
        .try_reserve_exact(length)
        .map_err(|_| FailReason::OutOfMemory)?;
    pixels.resize(length, 0xFF);
    Ok(pixels)
}

/// The bytes of `width × height` BGRA pixels.
fn bytes(width: u32, height: u32) -> Option<usize> {
    usize::try_from(width)
        .ok()?
        .checked_mul(usize::try_from(height).ok()?)?
        .checked_mul(4)
}

/// The fixed render flags of the module documentation.
fn configuration() -> PdfRenderConfig {
    PdfRenderConfig::new()
        .set_format(PdfBitmapFormat::BGRA)
        .set_reverse_byte_order(false)
        .clear_before_rendering(false)
        .render_form_data(false)
        .render_annotations(true)
        .use_lcd_text_rendering(false)
        .disable_native_text_rendering(true)
        .use_grayscale_rendering(false)
        .use_print_quality(false)
        .limit_render_image_cache_size(false)
        .force_half_tone(false)
        .render_fills_as_strokes(false)
        .set_text_smoothing(true)
        .set_image_smoothing(true)
        .set_path_smoothing(true)
}

/// The error for a document PDFium does not open.
fn open_error(err: PdfiumError) -> RenderError {
    match err {
        PdfiumError::PdfiumLibraryInternalError(PdfiumInternalError::PasswordError) => {
            RenderError::PasswordRequired
        }
        PdfiumError::PdfiumLibraryInternalError(PdfiumInternalError::SecurityError) => {
            RenderError::UnsupportedSecurity
        }
        other => RenderError::Damaged {
            reason: format!("PDFium cannot open it: {other:?}"),
        },
    }
}
