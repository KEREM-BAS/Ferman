//! What a view asks the render thread for, and what it gets back.
//!
//! A page is rastered at a scale of `zoom × device pixel ratio` pixels per point, where the zoom is
//! a quarter-octave [`ZoomBucket`]. The raster is cut into tiles on a grid of [`TILE_SIZE`] device
//! pixels from its top-left corner; the tiles of the last column and row are cut to the raster, so
//! a tile never shows anything outside its page. Thumbnails are one bitmap of the whole page.
//!
//! Page sizes are in points as the page is displayed, after its `/Rotate`, with the origin at the
//! top left (docs/ARCHITECTURE.md §3.4, ADR 0009).

use std::hash::{Hash, Hasher};

/// The side of a full tile, in device pixels.
pub const TILE_SIZE: u32 = 512;

/// The smallest thumbnail side, in device pixels.
pub const MIN_THUMBNAIL_SIZE: u32 = 16;

/// The largest thumbnail side, in device pixels.
pub const MAX_THUMBNAIL_SIZE: u32 = 1024;

/// The smallest device pixel ratio a request may carry.
pub const MIN_DEVICE_PIXEL_RATIO: f32 = 0.5;

/// The largest device pixel ratio a request may carry.
pub const MAX_DEVICE_PIXEL_RATIO: f32 = 4.0;

/// The largest raster side, in device pixels: PDFium takes sizes and offsets as `int`, and a page
/// matrix keeps whole pixels exact in `f32` below 2^24.
const MAX_RASTER_SIDE: u64 = 1 << 24;

/// `2^(k/4)` for `k` in `0..4`: the steps inside one octave.
const QUARTER_OCTAVES: [f64; 4] = [
    1.0,
    1.189_207_115_002_721,
    std::f64::consts::SQRT_2,
    1.681_792_830_507_429,
];

/// A quarter-octave zoom level: the logical zoom is `2^(bucket / 4)`, so bucket 0 is 100 % and
/// bucket 4 is 200 %. The UI scales the nearest bucket's tiles on the GPU, which stays within 19 %
/// of the raster (docs/ARCHITECTURE.md §5.3).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct ZoomBucket(i16);

impl ZoomBucket {
    /// The smallest bucket: 6.25 %.
    pub const MIN: Self = Self(-16);
    /// The largest bucket: 12,800 %.
    pub const MAX: Self = Self(28);

    /// The bucket, or `None` outside [`ZoomBucket::MIN`] to [`ZoomBucket::MAX`].
    #[must_use]
    pub fn new(bucket: i16) -> Option<Self> {
        (Self::MIN.0..=Self::MAX.0)
            .contains(&bucket)
            .then_some(Self(bucket))
    }

    /// The bucket number.
    #[must_use]
    pub fn get(self) -> i16 {
        self.0
    }

    /// The logical zoom, `2^(bucket / 4)`, computed exactly the same way on every system: a
    /// power of two times one of four constants.
    #[must_use]
    pub fn zoom(self) -> f64 {
        let octave = i32::from(self.0.div_euclid(4));
        let step = usize::from(self.0.rem_euclid(4).unsigned_abs());
        2f64.powi(octave) * QUARTER_OCTAVES.get(step).copied().unwrap_or(1.0)
    }
}

/// The size of a page in points, as displayed (after `/Rotate`).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PageSize {
    /// The width in points.
    pub width: f32,
    /// The height in points.
    pub height: f32,
}

impl PageSize {
    /// The size of this page's raster at `scale` pixels per point, at least one pixel each way,
    /// or `None` when a side would exceed the largest raster.
    #[must_use]
    pub fn raster(self, scale: f64) -> Option<(u32, u32)> {
        let side = |points: f32| {
            let pixels = (f64::from(points) * scale).round();
            // The comparison also rejects NaN.
            if pixels >= 1.0 && pixels <= MAX_RASTER_SIDE as f64 {
                #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
                let pixels = pixels as u32;
                Some(pixels)
            } else if pixels < 1.0 && scale > 0.0 && points > 0.0 {
                Some(1)
            } else {
                None
            }
        };
        Some((side(self.width)?, side(self.height)?))
    }
}

/// A rectangle of device pixels in a page's raster.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct PixelRect {
    /// The left edge.
    pub x: u32,
    /// The top edge.
    pub y: u32,
    /// The width.
    pub width: u32,
    /// The height.
    pub height: u32,
}

/// A tile's place on the grid: column and row from the raster's top-left corner.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct TilePosition {
    /// The column, counted from the left.
    pub column: u32,
    /// The row, counted from the top.
    pub row: u32,
}

/// One tile of one page.
#[derive(Debug, Clone, Copy)]
pub struct TileRequest {
    /// The page index, from 0.
    pub page: u32,
    /// The zoom bucket.
    pub zoom: ZoomBucket,
    /// The display's device pixel ratio, from [`MIN_DEVICE_PIXEL_RATIO`] to
    /// [`MAX_DEVICE_PIXEL_RATIO`].
    pub device_pixel_ratio: f32,
    /// The tile on the grid.
    pub position: TilePosition,
}

impl TileRequest {
    /// The raster scale in pixels per point, or `None` for a device pixel ratio out of range.
    #[must_use]
    pub fn scale(&self) -> Option<f64> {
        let ratio = self.device_pixel_ratio;
        // The range check also rejects NaN.
        (MIN_DEVICE_PIXEL_RATIO..=MAX_DEVICE_PIXEL_RATIO)
            .contains(&ratio)
            .then(|| self.zoom.zoom() * f64::from(ratio))
    }

    /// The tile's pixels in the raster of `page`, or `None` when the request is out of range: a
    /// device pixel ratio outside its limits, or a position outside the raster.
    #[must_use]
    pub fn rect(&self, page: PageSize) -> Option<PixelRect> {
        let (width, height) = page.raster(self.scale()?)?;
        let x = self.position.column.checked_mul(TILE_SIZE)?;
        let y = self.position.row.checked_mul(TILE_SIZE)?;
        (x < width && y < height).then(|| PixelRect {
            x,
            y,
            width: (width - x).min(TILE_SIZE),
            height: (height - y).min(TILE_SIZE),
        })
    }
}

// The device pixel ratio is compared by its bits, so a request is a map key; requests only ever
// carry ratios in range, never NaN.
impl PartialEq for TileRequest {
    fn eq(&self, other: &Self) -> bool {
        self.page == other.page
            && self.zoom == other.zoom
            && self.device_pixel_ratio.to_bits() == other.device_pixel_ratio.to_bits()
            && self.position == other.position
    }
}

impl Eq for TileRequest {}

impl Hash for TileRequest {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.page.hash(state);
        self.zoom.hash(state);
        self.device_pixel_ratio.to_bits().hash(state);
        self.position.hash(state);
    }
}

/// A thumbnail of one page: the whole page fitted into a square of `size` device pixels.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ThumbnailRequest {
    /// The page index, from 0.
    pub page: u32,
    /// The longer side in device pixels, from [`MIN_THUMBNAIL_SIZE`] to [`MAX_THUMBNAIL_SIZE`].
    pub size: u32,
}

impl ThumbnailRequest {
    /// The raster scale in pixels per point and the thumbnail's pixels, or `None` for a size out
    /// of range or an empty page.
    #[must_use]
    pub fn raster(&self, page: PageSize) -> Option<(f64, PixelRect)> {
        if !(MIN_THUMBNAIL_SIZE..=MAX_THUMBNAIL_SIZE).contains(&self.size) {
            return None;
        }
        let longer = page.width.max(page.height);
        if longer.is_nan() || longer <= 0.0 {
            return None;
        }
        let scale = f64::from(self.size) / f64::from(longer);
        let (width, height) = page.raster(scale)?;
        Some((
            scale,
            PixelRect {
                x: 0,
                y: 0,
                width: width.min(self.size),
                height: height.min(self.size),
            },
        ))
    }
}

/// Something a view wants rendered.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Item {
    /// A tile of a page.
    Tile(TileRequest),
    /// A thumbnail of a page.
    Thumbnail(ThumbnailRequest),
}

impl Item {
    /// The page the item shows.
    #[must_use]
    pub fn page(&self) -> u32 {
        match self {
            Self::Tile(tile) => tile.page,
            Self::Thumbnail(thumbnail) => thumbnail.page,
        }
    }

    /// The raster scale and the pixels the item covers on `page`, or `None` when the item is out
    /// of range.
    #[must_use]
    pub fn raster(&self, page: PageSize) -> Option<(f64, PixelRect)> {
        match self {
            Self::Tile(tile) => Some((tile.scale()?, tile.rect(page)?)),
            Self::Thumbnail(thumbnail) => thumbnail.raster(page),
        }
    }
}

/// The priority classes of the queue, highest first (docs/ARCHITECTURE.md §4.5). Within a class,
/// items are rendered in the order the view lists them: the UI puts visible tiles nearest the
/// viewport centre first.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Priority {
    /// Tiles on screen.
    Visible,
    /// Tiles one screen ahead in the scroll direction and half a screen behind.
    Prefetch,
    /// Thumbnails on screen.
    VisibleThumbnail,
    /// Other thumbnails.
    Thumbnail,
    /// Background work, such as thumbnails for recent files.
    Background,
}

/// One entry of a view's wanted set.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Wanted {
    /// What to render.
    pub item: Item,
    /// How urgent it is.
    pub priority: Priority,
}

/// A rendered tile or thumbnail.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Rendered {
    /// What was asked for.
    pub item: Item,
    /// The page's render key when it was rendered. The UI keeps the newest key per page and drops
    /// a bitmap with an older one, so a page never flips back to an old revision.
    pub render_key: u64,
    /// The generation of the wanted set this answers: the newest one that still wanted it.
    pub generation: u64,
    /// Where the pixels sit in the page's raster (for a thumbnail, at the origin).
    pub rect: PixelRect,
    /// Bytes per row: `rect.width × 4`.
    pub stride: u32,
    /// 8-bit BGRA, opaque: the page background is painted white first, so the alpha is always 255.
    pub pixels: Vec<u8>,
}

/// Why an item was not rendered. The UI shows a2-13's placeholder with Try again for the page.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum FailReason {
    /// The document has no such page.
    NoSuchPage,
    /// The request is out of range: a zoom, device pixel ratio, position or size the page's raster
    /// does not have.
    OutOfRange,
    /// PDFium could not load or render the page.
    PageDamaged,
    /// Memory for the bitmap could not be reserved.
    OutOfMemory,
    /// Rendering failed for a reason that is a bug in Ferman.
    Internal,
}

/// An item the render thread could not render.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Failed {
    /// What was asked for.
    pub item: Item,
    /// The generation of the wanted set this answers.
    pub generation: u64,
    /// Why it failed.
    pub reason: FailReason,
}

/// What a view receives.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ViewEvent {
    /// A bitmap is ready.
    Rendered(Rendered),
    /// An item could not be rendered.
    Failed(Failed),
}

/// Where a view's events go. It is called on the render thread, so it must hand the event on
/// without waiting: a channel, or the bridge's stream sink.
pub trait ViewSink: Send + 'static {
    /// Hands on one event. Returns `false` when the receiver is gone, which closes the view.
    fn deliver(&mut self, event: ViewEvent) -> bool;
}

impl ViewSink for crossbeam_channel::Sender<ViewEvent> {
    fn deliver(&mut self, event: ViewEvent) -> bool {
        self.send(event).is_ok()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const A4: PageSize = PageSize {
        width: 595.0,
        height: 842.0,
    };

    fn tile(zoom: i16, ratio: f32, column: u32, row: u32) -> TileRequest {
        TileRequest {
            page: 0,
            zoom: ZoomBucket::new(zoom).unwrap(),
            device_pixel_ratio: ratio,
            position: TilePosition { column, row },
        }
    }

    #[test]
    fn buckets_are_quarter_octaves() {
        assert_eq!(ZoomBucket::new(0).unwrap().zoom(), 1.0);
        assert_eq!(ZoomBucket::new(4).unwrap().zoom(), 2.0);
        assert_eq!(ZoomBucket::new(-4).unwrap().zoom(), 0.5);
        assert_eq!(ZoomBucket::new(2).unwrap().zoom(), std::f64::consts::SQRT_2);
        assert_eq!(
            ZoomBucket::new(-2).unwrap().zoom(),
            std::f64::consts::FRAC_1_SQRT_2
        );
        assert_eq!(ZoomBucket::MIN.zoom(), 0.0625);
        assert_eq!(ZoomBucket::MAX.zoom(), 128.0);
        for bucket in ZoomBucket::MIN.get()..ZoomBucket::MAX.get() {
            let ratio = ZoomBucket(bucket + 1).zoom() / ZoomBucket(bucket).zoom();
            assert!((ratio - 2f64.powf(0.25)).abs() < 1e-12, "{bucket}: {ratio}");
        }
        assert_eq!(ZoomBucket::new(-17), None);
        assert_eq!(ZoomBucket::new(29), None);
    }

    #[test]
    fn edge_tiles_are_cut_to_the_raster() {
        // A4 at 100 % and a ratio of 2: 1190 × 1684 pixels, so 3 columns and 4 rows.
        assert_eq!(A4.raster(2.0), Some((1190, 1684)));
        assert_eq!(
            tile(0, 2.0, 0, 0).rect(A4),
            Some(PixelRect {
                x: 0,
                y: 0,
                width: 512,
                height: 512
            })
        );
        assert_eq!(
            tile(0, 2.0, 2, 3).rect(A4),
            Some(PixelRect {
                x: 1024,
                y: 1536,
                width: 166,
                height: 148
            })
        );
        assert_eq!(tile(0, 2.0, 3, 0).rect(A4), None);
        assert_eq!(tile(0, 2.0, 0, 4).rect(A4), None);
    }

    #[test]
    fn ratios_out_of_range_are_rejected() {
        assert_eq!(tile(0, 0.25, 0, 0).rect(A4), None);
        assert_eq!(tile(0, 5.0, 0, 0).rect(A4), None);
        assert_eq!(tile(0, f32::NAN, 0, 0).rect(A4), None);
        assert!(tile(0, 1.5, 0, 0).rect(A4).is_some());
    }

    #[test]
    fn huge_positions_do_not_overflow() {
        assert_eq!(tile(0, 1.0, u32::MAX, 0).rect(A4), None);
        assert_eq!(tile(28, 4.0, 0, u32::MAX).rect(A4), None);
        // 12,800 % at a ratio of 4 is still a valid raster.
        assert!(tile(28, 4.0, 0, 0).rect(A4).is_some());
    }

    #[test]
    fn a_tiny_page_has_at_least_one_pixel() {
        let speck = PageSize {
            width: 0.1,
            height: 0.1,
        };
        assert_eq!(speck.raster(1.0), Some((1, 1)));
        let empty = PageSize {
            width: 0.0,
            height: 10.0,
        };
        assert_eq!(empty.raster(1.0), None);
    }

    #[test]
    fn thumbnails_fit_their_square() {
        let thumbnail = ThumbnailRequest { page: 0, size: 200 };
        let (scale, rect) = thumbnail.raster(A4).unwrap();
        assert!((scale - 200.0 / 842.0).abs() < 1e-12);
        assert_eq!((rect.width, rect.height), (141, 200));
        let landscape = PageSize {
            width: 842.0,
            height: 595.0,
        };
        let (_, rect) = thumbnail.raster(landscape).unwrap();
        assert_eq!((rect.width, rect.height), (200, 141));
        assert_eq!(ThumbnailRequest { page: 0, size: 8 }.raster(A4), None);
        assert_eq!(
            ThumbnailRequest {
                page: 0,
                size: 2048
            }
            .raster(A4),
            None
        );
    }

    #[test]
    fn requests_compare_their_ratio_by_bits() {
        assert_eq!(tile(0, 2.0, 1, 1), tile(0, 2.0, 1, 1));
        assert_ne!(tile(0, 2.0, 1, 1), tile(0, 1.5, 1, 1));
        let mut set = std::collections::HashSet::new();
        set.insert(Item::Tile(tile(0, 2.0, 1, 1)));
        assert!(set.contains(&Item::Tile(tile(0, 2.0, 1, 1))));
    }

    #[test]
    fn priorities_order_visible_first() {
        assert!(Priority::Visible < Priority::Prefetch);
        assert!(Priority::Prefetch < Priority::VisibleThumbnail);
        assert!(Priority::VisibleThumbnail < Priority::Thumbnail);
        assert!(Priority::Thumbnail < Priority::Background);
    }
}
