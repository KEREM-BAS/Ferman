//! The pixel-diff harness of the edit acceptance tests (docs/ARCHITECTURE.md §13.4, ROADMAP §7):
//! a whole page rendered as the canvas renders it, and the pixels that differ between two such
//! renders, measured against the edited region.
//!
//! - **Rendering.** [`render_page`] asks the render thread for every tile of a page at one of the
//!   fixed [`RESOLUTIONS`] and puts them together, so before and after are rendered tile for tile
//!   with the flags of the `document` module, exactly as the canvas gets them. A resolution maps
//!   to a zoom bucket that is a whole octave and a device pixel ratio from 1 to 2.
//! - **Region.** [`device_region`] turns boxes in displayed points (y down, after `/Rotate`, as
//!   ferman-text gives a block's box) into the device pixels they touch.
//! - **Comparison.** [`compare`] counts the differing pixels, their bounds, the margin around the
//!   region they need, and those outside the region grown by a margin. An edit passes when none is
//!   outside the region grown by [`EDIT_MARGIN`].

use futures_channel::oneshot;

use crate::RenderError;
use crate::thread::{DocumentId, RenderThread};
use crate::tiles::{
    FailReason, Item, PageSize, PixelRect, Priority, TILE_SIZE, TilePosition, TileRequest,
    ViewEvent, ViewSink, Wanted, ZoomBucket,
};

/// The margin, in device pixels, the edited region grows by for antialiasing (M3 plan decision 6):
/// measured on the edit corpus. A case that needs more fails; the margin never widens silently.
pub const EDIT_MARGIN: u32 = 2;

/// The resolutions, in dots per inch, every edit case is rendered at (docs/ARCHITECTURE.md §13.4).
pub const RESOLUTIONS: [u32; 3] = [72, 150, 300];

/// A whole page's raster.
#[derive(Debug, Clone, PartialEq)]
pub struct PageRaster {
    /// The width in device pixels.
    pub width: u32,
    /// The height in device pixels.
    pub height: u32,
    /// Device pixels per displayed point.
    pub scale: f64,
    /// 8-bit BGRA, opaque, `width × 4` bytes per row, the top row first.
    pub pixels: Vec<u8>,
}

/// The zoom bucket and device pixel ratio that render at `dpi`: a whole octave and a ratio from 1
/// to 2, or `None` for a resolution the tiles cannot have.
#[must_use]
pub fn tiles_at(dpi: u32) -> Option<(ZoomBucket, f32)> {
    if dpi == 0 {
        return None;
    }
    let scale = f64::from(dpi) / 72.0;
    let mut octave: i16 = 0;
    let mut zoom = 1.0_f64;
    while zoom * 2.0 <= scale {
        zoom *= 2.0;
        octave = octave.checked_add(1)?;
    }
    while zoom > scale {
        zoom /= 2.0;
        octave = octave.checked_sub(1)?;
    }
    // From 1 to 2, so exact enough in f32.
    #[allow(clippy::cast_possible_truncation)]
    let ratio = (scale / zoom) as f32;
    Some((ZoomBucket::new(octave.checked_mul(4)?)?, ratio))
}

/// Renders page `page` of `document`, whose size is `size`, at `dpi` (one of [`RESOLUTIONS`] or
/// any other [`tiles_at`] takes), through a view of its own that asks for every tile.
///
/// # Errors
///
/// [`RenderError::Damaged`] when the resolution or the page raster is out of range or PDFium
/// cannot render a tile, [`RenderError::OutOfMemory`], [`RenderError::NotFound`] for a document
/// that is not open, and [`RenderError::ThreadStopped`].
pub async fn render_page(
    render: &RenderThread,
    document: DocumentId,
    page: u32,
    size: PageSize,
    dpi: u32,
) -> Result<PageRaster, RenderError> {
    let damaged = |reason: &str| RenderError::Damaged {
        reason: format!("page {page} at {dpi} dpi: {reason}"),
    };
    let (zoom, device_pixel_ratio) = tiles_at(dpi).ok_or_else(|| damaged("no such resolution"))?;
    let tile = |column, row| TileRequest {
        page,
        zoom,
        device_pixel_ratio,
        position: TilePosition { column, row },
    };
    let scale = tile(0, 0)
        .scale()
        .ok_or_else(|| damaged("no such resolution"))?;
    let (width, height) = size
        .raster(scale)
        .ok_or_else(|| damaged("raster out of range"))?;
    let (columns, rows) = (width.div_ceil(TILE_SIZE), height.div_ceil(TILE_SIZE));
    let mut wanted = Vec::new();
    for row in 0..rows {
        for column in 0..columns {
            wanted.push(Wanted {
                item: Item::Tile(tile(column, row)),
                priority: Priority::Visible,
            });
        }
    }
    let length = usize::try_from(width)
        .ok()
        .zip(usize::try_from(height).ok())
        .and_then(|(width, height)| width.checked_mul(height)?.checked_mul(4))
        .ok_or_else(|| damaged("raster out of range"))?;
    let mut pixels = Vec::new();
    pixels
        .try_reserve_exact(length)
        .map_err(|_| RenderError::OutOfMemory {
            context: "a page raster",
        })?;
    pixels.resize(length, 0);
    let (reply, done) = oneshot::channel();
    let sink = Stitch {
        raster: Some(PageRaster {
            width,
            height,
            scale,
            pixels,
        }),
        page,
        left: vec![true; wanted.len()],
        columns,
        reply: Some(reply),
    };
    let view = render.open_view(document, Box::new(sink)).await?;
    render.request(view, 1, wanted)?;
    let raster = done.await.map_err(|_canceled| RenderError::ThreadStopped);
    // The sink closed the view when it answered; this only covers a stopped thread.
    let _ = render.close_view(view);
    match raster? {
        Ok(raster) => Ok(raster),
        Err(FailReason::OutOfMemory) => Err(RenderError::OutOfMemory { context: "a tile" }),
        Err(reason) => Err(damaged(&format!("a tile failed: {reason:?}"))),
    }
}

/// A view's sink that puts the page's tiles into one raster and answers when it has them all.
struct Stitch {
    raster: Option<PageRaster>,
    page: u32,
    /// Per tile, row by row: whether it is still to come.
    left: Vec<bool>,
    columns: u32,
    reply: Option<oneshot::Sender<Result<PageRaster, FailReason>>>,
}

impl Stitch {
    /// Copies a tile's rows into the raster; `false` when it does not fit, a bug.
    fn place(raster: &mut PageRaster, rect: PixelRect, stride: u32, pixels: &[u8]) -> bool {
        let to_usize = |value: u32| usize::try_from(value).ok();
        let (Some(x), Some(width), Some(stride), Some(raster_width)) = (
            to_usize(rect.x),
            to_usize(rect.width),
            to_usize(stride),
            to_usize(raster.width),
        ) else {
            return false;
        };
        for line in 0..rect.height {
            let Some(y) = rect.y.checked_add(line).and_then(to_usize) else {
                return false;
            };
            let row = to_usize(line).and_then(|line| line.checked_mul(stride));
            let from = row
                .zip(width.checked_mul(4))
                .and_then(|(start, length)| pixels.get(start..start.checked_add(length)?));
            let at = y
                .checked_mul(raster_width)
                .and_then(|at| at.checked_add(x))
                .and_then(|at| at.checked_mul(4));
            let to = at.zip(width.checked_mul(4)).and_then(|(start, length)| {
                raster.pixels.get_mut(start..start.checked_add(length)?)
            });
            match (from, to) {
                (Some(from), Some(to)) => to.copy_from_slice(from),
                _ => return false,
            }
        }
        true
    }

    fn answer(&mut self, result: Result<PageRaster, FailReason>) -> bool {
        if let Some(reply) = self.reply.take() {
            let _ = reply.send(result);
        }
        false
    }
}

impl ViewSink for Stitch {
    fn deliver(&mut self, event: ViewEvent) -> bool {
        let (item, outcome) = match event {
            ViewEvent::Rendered(rendered) => (rendered.item, Ok(rendered)),
            ViewEvent::Failed(failed) => (failed.item, Err(failed.reason)),
        };
        let Item::Tile(tile) = item else {
            return true;
        };
        if tile.page != self.page {
            return true;
        }
        let at = tile
            .position
            .row
            .checked_mul(self.columns)
            .and_then(|at| at.checked_add(tile.position.column))
            .and_then(|at| usize::try_from(at).ok());
        let Some(slot) = at.and_then(|at| self.left.get_mut(at)) else {
            return true;
        };
        let rendered = match outcome {
            Ok(rendered) => rendered,
            Err(reason) => return self.answer(Err(reason)),
        };
        let Some(raster) = self.raster.as_mut() else {
            return false;
        };
        if !Self::place(raster, rendered.rect, rendered.stride, &rendered.pixels) {
            return self.answer(Err(FailReason::Internal));
        }
        *slot = false;
        if self.left.iter().any(|&left| left) {
            return true;
        }
        match self.raster.take() {
            Some(raster) => self.answer(Ok(raster)),
            None => false,
        }
    }
}

/// The device pixels that `boxes`, each `[left, top, right, bottom]` in displayed points, touch
/// at `scale` pixels per point: their union, cut at the page's top-left corner. `None` when there
/// is no box with a finite, non-negative extent.
#[must_use]
pub fn device_region(boxes: &[[f32; 4]], scale: f64) -> Option<PixelRect> {
    let mut union: Option<[f64; 4]> = None;
    for &[left, top, right, bottom] in boxes {
        let edges = [left, top, right, bottom].map(|edge| f64::from(edge) * scale);
        if edges.iter().any(|edge| !edge.is_finite()) || edges[2] < edges[0] || edges[3] < edges[1]
        {
            continue;
        }
        union = Some(match union {
            None => edges,
            Some(u) => [
                u[0].min(edges[0]),
                u[1].min(edges[1]),
                u[2].max(edges[2]),
                u[3].max(edges[3]),
            ],
        });
    }
    let [left, top, right, bottom] = union?;
    // Whole pixels, clamped to the raster limit's range.
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    let pixel = |edge: f64| edge.clamp(0.0, f64::from(u32::MAX)) as u32;
    let (x, y) = (pixel(left.floor()), pixel(top.floor()));
    Some(PixelRect {
        x,
        y,
        width: pixel(right.ceil()).saturating_sub(x),
        height: pixel(bottom.ceil()).saturating_sub(y),
    })
}

/// The pixels that differ between two renders of a page, measured against the edited region.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct PixelDiff {
    /// How many pixels differ.
    pub differing: u64,
    /// The bounds of every differing pixel.
    pub bounds: Option<PixelRect>,
    /// How far, in device pixels, the farthest differing pixel lies outside the region (0 when
    /// all are inside); `None` without a region.
    pub margin_needed: Option<u32>,
    /// How many differing pixels lie outside the region grown by the margin; without a region,
    /// all of them.
    pub outside: u64,
    /// Their bounds.
    pub outside_bounds: Option<PixelRect>,
}

impl PixelDiff {
    /// Whether no differing pixel lies outside the region grown by the margin.
    #[must_use]
    pub fn passed(&self) -> bool {
        self.outside == 0
    }
}

/// The pixels that differ between `before` and `after`, measured against `region` grown by
/// `margin` pixels on every side; `None` when the rasters have different sizes, which no edit
/// may cause.
#[must_use]
pub fn compare(
    before: &PageRaster,
    after: &PageRaster,
    region: Option<PixelRect>,
    margin: u32,
) -> Option<PixelDiff> {
    if (before.width, before.height) != (after.width, after.height)
        || before.pixels.len() != after.pixels.len()
    {
        return None;
    }
    let width = usize::try_from(before.width).ok()?.max(1);
    let mut diff = PixelDiff {
        margin_needed: region.map(|_| 0),
        ..PixelDiff::default()
    };
    let mut bounds = Bounds::default();
    let mut outside = Bounds::default();
    for (at, (old, new)) in before
        .pixels
        .as_chunks::<4>()
        .0
        .iter()
        .zip(after.pixels.as_chunks::<4>().0)
        .enumerate()
    {
        if old == new {
            continue;
        }
        let x = u32::try_from(at % width).ok()?;
        let y = u32::try_from(at / width).ok()?;
        diff.differing = diff.differing.saturating_add(1);
        bounds.add(x, y);
        let distance = region.map(|region| distance(region, x, y));
        if let (Some(needed), Some(distance)) = (diff.margin_needed.as_mut(), distance) {
            *needed = (*needed).max(distance);
        }
        if distance.is_none_or(|distance| distance > margin) {
            diff.outside = diff.outside.saturating_add(1);
            outside.add(x, y);
        }
    }
    diff.bounds = bounds.rect();
    diff.outside_bounds = outside.rect();
    Some(diff)
}

/// How many pixels `(x, y)` lies outside `region`, the larger of the two ways (0 inside).
fn distance(region: PixelRect, x: u32, y: u32) -> u32 {
    let away = |at: u32, start: u32, length: u32| {
        let end = start.saturating_add(length);
        if at < start {
            start - at
        } else if at >= end {
            // `end` is past the last pixel inside.
            at.saturating_sub(end).saturating_add(1)
        } else {
            0
        }
    };
    away(x, region.x, region.width).max(away(y, region.y, region.height))
}

/// The bounds of the pixels added, inclusive.
#[derive(Default)]
struct Bounds(Option<[u32; 4]>);

impl Bounds {
    fn add(&mut self, x: u32, y: u32) {
        self.0 = Some(match self.0 {
            None => [x, y, x, y],
            Some([left, top, right, bottom]) => {
                [left.min(x), top.min(y), right.max(x), bottom.max(y)]
            }
        });
    }

    fn rect(&self) -> Option<PixelRect> {
        let [left, top, right, bottom] = self.0?;
        Some(PixelRect {
            x: left,
            y: top,
            width: right.saturating_sub(left).saturating_add(1),
            height: bottom.saturating_sub(top).saturating_add(1),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn raster(width: u32, height: u32) -> PageRaster {
        PageRaster {
            width,
            height,
            scale: 1.0,
            pixels: vec![0xFF; (width * height * 4) as usize],
        }
    }

    fn set(raster: &mut PageRaster, x: u32, y: u32) {
        let at = ((y * raster.width + x) * 4) as usize;
        raster.pixels[at] = 0;
    }

    fn rect(x: u32, y: u32, width: u32, height: u32) -> PixelRect {
        PixelRect {
            x,
            y,
            width,
            height,
        }
    }

    #[test]
    fn resolutions_are_whole_octaves_and_a_ratio_from_one_to_two() {
        assert_eq!(tiles_at(72), Some((ZoomBucket::new(0).unwrap(), 1.0)));
        let (zoom, ratio) = tiles_at(150).unwrap();
        assert_eq!(zoom.get(), 4);
        assert!((f64::from(ratio) * zoom.zoom() - 150.0 / 72.0).abs() < 1e-6);
        let (zoom, ratio) = tiles_at(300).unwrap();
        assert_eq!(zoom.get(), 8);
        assert!((f64::from(ratio) * zoom.zoom() - 300.0 / 72.0).abs() < 1e-6);
        assert_eq!(tiles_at(36), Some((ZoomBucket::new(-4).unwrap(), 1.0)));
        assert_eq!(tiles_at(0), None);
        assert_eq!(tiles_at(u32::MAX), None);
    }

    #[test]
    fn a_region_covers_every_pixel_its_boxes_touch() {
        assert_eq!(
            device_region(&[[10.2, 5.0, 20.0, 9.5], [15.0, 2.0, 18.0, 4.0]], 2.0),
            Some(rect(20, 4, 20, 15))
        );
        assert_eq!(
            device_region(&[[-3.0, -1.0, 2.0, 2.0]], 1.0),
            Some(rect(0, 0, 2, 2))
        );
        assert_eq!(device_region(&[[f32::NAN, 0.0, 1.0, 1.0]], 1.0), None);
        assert_eq!(device_region(&[], 1.0), None);
    }

    #[test]
    fn differing_pixels_are_measured_against_the_region_and_its_margin() {
        let before = raster(20, 10);
        let mut after = before.clone();
        assert_eq!(
            compare(&before, &after, Some(rect(5, 5, 2, 2)), EDIT_MARGIN),
            Some(PixelDiff {
                margin_needed: Some(0),
                ..PixelDiff::default()
            })
        );
        set(&mut after, 5, 5);
        set(&mut after, 8, 6);
        set(&mut after, 10, 1);
        let diff = compare(&before, &after, Some(rect(5, 5, 2, 2)), EDIT_MARGIN).unwrap();
        assert_eq!(diff.differing, 3);
        assert_eq!(diff.bounds, Some(rect(5, 1, 6, 6)));
        // (8, 6) is 2 pixels right of the region, (10, 1) 4 right and 4 up.
        assert_eq!(diff.margin_needed, Some(4));
        assert_eq!(diff.outside, 1);
        assert_eq!(diff.outside_bounds, Some(rect(10, 1, 1, 1)));
        assert!(!diff.passed());
        assert!(
            compare(&before, &after, Some(rect(5, 5, 2, 2)), 4)
                .unwrap()
                .passed()
        );
        let whole = compare(&before, &after, None, EDIT_MARGIN).unwrap();
        assert_eq!((whole.outside, whole.margin_needed), (3, None));
        assert_eq!(compare(&before, &raster(10, 20), None, 0), None);
    }

    #[test]
    fn tiles_are_stitched_row_by_row() {
        let mut page = raster(4, 3);
        let tile: Vec<u8> = (0..2 * 2 * 4).map(|byte| byte as u8).collect();
        assert!(Stitch::place(&mut page, rect(2, 1, 2, 2), 8, &tile));
        assert_eq!(&page.pixels[(4 + 2) * 4..(4 + 4) * 4], &tile[..8]);
        assert_eq!(&page.pixels[(8 + 2) * 4..(8 + 4) * 4], &tile[8..]);
        assert!(!Stitch::place(&mut page, rect(3, 2, 2, 2), 8, &tile));
    }
}
