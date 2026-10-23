//! A small rasteriser for the scanned pages: glyph outlines (from skrifa) and rectangles filled
//! into a greyscale bitmap with 4 × 4 coverage, the page turned slightly as it lies on a
//! scanner's glass, and the result written as a Flate image the way scanners write it: greyscale
//! with PNG predictors, or one bit per pixel.
//!
//! Only additions, multiplications, divisions and comparisons of floating-point numbers are
//! used, whose results IEEE 754 fixes, so the bitmaps are the same on every system.

use crate::font::Face;
use lopdf::{Dictionary, Stream, dictionary};
use skrifa::outline::OutlinePen;

/// Sub-scanlines per pixel row.
const SAMPLES: usize = 4;
/// Line segments per quadratic curve, and per cubic one.
const QUAD_STEPS: usize = 8;
const CUBIC_STEPS: usize = 12;

/// A greyscale bitmap, 0 black and 255 white, rows from the top.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Gray {
    /// The width in pixels.
    pub width: usize,
    /// The height in pixels.
    pub height: usize,
    /// The pixels, row by row.
    pub pixels: Vec<u8>,
}

/// An outline flattened into line segments, in device pixels (y down).
#[derive(Debug, Default)]
struct Edges {
    segments: Vec<(f64, f64, f64, f64)>,
    start: (f64, f64),
    pen: (f64, f64),
    origin: (f64, f64),
    scale: f64,
}

impl Edges {
    fn device(&self, x: f32, y: f32) -> (f64, f64) {
        (
            self.origin.0 + f64::from(x) * self.scale,
            self.origin.1 - f64::from(y) * self.scale,
        )
    }

    fn to(&mut self, point: (f64, f64)) {
        if point != self.pen {
            self.segments
                .push((self.pen.0, self.pen.1, point.0, point.1));
        }
        self.pen = point;
    }
}

impl OutlinePen for Edges {
    fn move_to(&mut self, x: f32, y: f32) {
        self.close();
        let point = self.device(x, y);
        self.start = point;
        self.pen = point;
    }

    fn line_to(&mut self, x: f32, y: f32) {
        let point = self.device(x, y);
        self.to(point);
    }

    fn quad_to(&mut self, cx0: f32, cy0: f32, x: f32, y: f32) {
        let (p0, p1, p2) = (self.pen, self.device(cx0, cy0), self.device(x, y));
        for step in 1..=QUAD_STEPS {
            #[allow(clippy::cast_precision_loss)]
            let t = step as f64 / QUAD_STEPS as f64;
            let u = 1.0 - t;
            self.to((
                u * u * p0.0 + 2.0 * u * t * p1.0 + t * t * p2.0,
                u * u * p0.1 + 2.0 * u * t * p1.1 + t * t * p2.1,
            ));
        }
    }

    fn curve_to(&mut self, cx0: f32, cy0: f32, cx1: f32, cy1: f32, x: f32, y: f32) {
        let (p0, p1, p2, p3) = (
            self.pen,
            self.device(cx0, cy0),
            self.device(cx1, cy1),
            self.device(x, y),
        );
        for step in 1..=CUBIC_STEPS {
            #[allow(clippy::cast_precision_loss)]
            let t = step as f64 / CUBIC_STEPS as f64;
            let u = 1.0 - t;
            let (a, b, c, d) = (u * u * u, 3.0 * u * u * t, 3.0 * u * t * t, t * t * t);
            self.to((
                a * p0.0 + b * p1.0 + c * p2.0 + d * p3.0,
                a * p0.1 + b * p1.1 + c * p2.1 + d * p3.1,
            ));
        }
    }

    fn close(&mut self) {
        let start = self.start;
        self.to(start);
    }
}

/// `value` rounded to a pixel value.
fn to_pixel(value: f64) -> u8 {
    let value = (value + 0.5).floor();
    if value <= 0.0 {
        0
    } else if value >= 255.0 {
        255
    } else {
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let value = value as u8;
        value
    }
}

/// `value` as a pixel index, clamped to `0..=limit`.
fn index(value: f64, limit: usize) -> usize {
    if value <= 0.0 {
        return 0;
    }
    #[allow(clippy::cast_precision_loss)]
    let top = limit as f64;
    if value >= top {
        return limit;
    }
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    let value = value as usize;
    value
}

impl Gray {
    /// A bitmap of `width` × `height` pixels of `paper`.
    #[must_use]
    pub fn new(width: usize, height: usize, paper: u8) -> Self {
        Self {
            width,
            height,
            pixels: vec![paper; width * height],
        }
    }

    /// Darkens the pixel at (`x`, `y`) towards `ink` by `coverage`.
    fn blend(&mut self, x: usize, y: usize, ink: u8, coverage: f64) {
        if let Some(pixel) = self.pixels.get_mut(y * self.width + x) {
            let coverage = coverage.clamp(0.0, 1.0);
            let blended =
                to_pixel(f64::from(*pixel) * (1.0 - coverage) + f64::from(ink) * coverage);
            *pixel = (*pixel).min(blended);
        }
    }

    /// Fills the rectangle from (`x0`, `y0`) to (`x1`, `y1`) in pixels with `ink`, its edges
    /// partly covered.
    pub fn fill_rect(&mut self, (x0, y0): (f64, f64), (x1, y1): (f64, f64), ink: u8) {
        let (left, right) = (x0.min(x1), x0.max(x1));
        let (top, bottom) = (y0.min(y1), y0.max(y1));
        for y in index(top.floor(), self.height)..index(bottom.ceil(), self.height) {
            #[allow(clippy::cast_precision_loss)]
            let row = y as f64;
            let vertical = bottom.min(row + 1.0) - top.max(row);
            for x in index(left.floor(), self.width)..index(right.ceil(), self.width) {
                #[allow(clippy::cast_precision_loss)]
                let column = x as f64;
                let horizontal = right.min(column + 1.0) - left.max(column);
                self.blend(x, y, ink, vertical * horizontal);
            }
        }
    }

    /// Fills glyph `gid` of `face` at `size` pixels per em with its origin at `origin` (pixels,
    /// y down), with the non-zero winding rule.
    pub fn fill_glyph(&mut self, face: &Face, gid: u16, size: f64, origin: (f64, f64), ink: u8) {
        let mut edges = Edges {
            origin,
            scale: size / face.units_per_em(),
            ..Edges::default()
        };
        if !face.draw_outline(gid, &mut edges) {
            return;
        }
        edges.close();
        let segments = edges.segments;
        let (mut top, mut bottom) = (f64::INFINITY, f64::NEG_INFINITY);
        let (mut left, mut right) = (f64::INFINITY, f64::NEG_INFINITY);
        for (x0, y0, x1, y1) in &segments {
            top = top.min(y0.min(*y1));
            bottom = bottom.max(y0.max(*y1));
            left = left.min(x0.min(*x1));
            right = right.max(x0.max(*x1));
        }
        if segments.is_empty() {
            return;
        }
        let first = index(left.floor(), self.width);
        let last = index(right.ceil() + 1.0, self.width);
        let mut coverage = vec![0.0f64; last.saturating_sub(first)];
        let mut crossings: Vec<(f64, i32)> = Vec::new();
        for y in index(top.floor(), self.height)..index(bottom.ceil(), self.height) {
            coverage.iter_mut().for_each(|value| *value = 0.0);
            for sample in 0..SAMPLES {
                #[allow(clippy::cast_precision_loss)]
                let line = y as f64 + (sample as f64 + 0.5) / SAMPLES as f64;
                crossings.clear();
                for (x0, y0, x1, y1) in &segments {
                    let (upper, lower, winding) = if y0 < y1 {
                        (*y0, *y1, 1)
                    } else {
                        (*y1, *y0, -1)
                    };
                    if line < upper || line >= lower {
                        continue;
                    }
                    crossings.push((x0 + (line - y0) * (x1 - x0) / (y1 - y0), winding));
                }
                crossings.sort_by(|a, b| a.0.total_cmp(&b.0));
                let mut winding = 0;
                for pair in crossings.windows(2) {
                    winding += pair[0].1;
                    if winding == 0 {
                        continue;
                    }
                    let (start, end) = (pair[0].0, pair[1].0);
                    for x in index(start.floor(), self.width)..index(end.ceil(), self.width) {
                        #[allow(clippy::cast_precision_loss)]
                        let (column, samples) = (x as f64, SAMPLES as f64);
                        let covered = end.min(column + 1.0) - start.max(column);
                        if let Some(value) =
                            x.checked_sub(first).and_then(|at| coverage.get_mut(at))
                        {
                            *value += covered / samples;
                        }
                    }
                }
            }
            for (column, value) in coverage.iter().enumerate() {
                if *value > 0.0 {
                    self.blend(first + column, y, ink, *value);
                }
            }
        }
    }

    /// The bitmap turned about its centre by the angle whose sine and cosine are given
    /// (clockwise for a positive sine), sampled bilinearly, with `paper` outside it.
    #[must_use]
    pub fn turned(&self, sine: f64, cosine: f64, paper: u8) -> Self {
        let mut out = Self::new(self.width, self.height, paper);
        #[allow(clippy::cast_precision_loss)]
        let (cx, cy) = (self.width as f64 / 2.0, self.height as f64 / 2.0);
        let sample = |x: isize, y: isize| -> f64 {
            if x < 0 || y < 0 {
                return f64::from(paper);
            }
            let (x, y) = (x.unsigned_abs(), y.unsigned_abs());
            if x >= self.width || y >= self.height {
                return f64::from(paper);
            }
            self.pixels
                .get(y * self.width + x)
                .map_or(f64::from(paper), |pixel| f64::from(*pixel))
        };
        for y in 0..self.height {
            for x in 0..self.width {
                #[allow(clippy::cast_precision_loss)]
                let (dx, dy) = (x as f64 + 0.5 - cx, y as f64 + 0.5 - cy);
                let sx = cx + dx * cosine + dy * sine - 0.5;
                let sy = cy - dx * sine + dy * cosine - 0.5;
                let (fx, fy) = (sx.floor(), sy.floor());
                let (tx, ty) = (sx - fx, sy - fy);
                #[allow(clippy::cast_possible_truncation)]
                let (ix, iy) = (fx as isize, fy as isize);
                let value = sample(ix, iy) * (1.0 - tx) * (1.0 - ty)
                    + sample(ix + 1, iy) * tx * (1.0 - ty)
                    + sample(ix, iy + 1) * (1.0 - tx) * ty
                    + sample(ix + 1, iy + 1) * tx * ty;
                if let Some(pixel) = out.pixels.get_mut(y * self.width + x) {
                    *pixel = to_pixel(value);
                }
            }
        }
        out
    }

    /// An image XObject of the bitmap: greyscale, Flate with the PNG Up predictor on every row.
    ///
    /// # Errors
    ///
    /// A message when the image does not compress.
    pub fn gray_image(&self) -> Result<Stream, String> {
        let mut data = Vec::with_capacity((self.width + 1) * self.height);
        let mut previous = vec![0u8; self.width];
        for row in self.pixels.chunks(self.width.max(1)) {
            data.push(2);
            data.extend(row.iter().zip(&previous).map(|(a, b)| a.wrapping_sub(*b)));
            previous.copy_from_slice(row);
        }
        let parms = dictionary! {
            "Predictor" => 15,
            "Colors" => 1,
            "BitsPerComponent" => 8,
            "Columns" => i64::try_from(self.width).map_err(|err| err.to_string())?,
        };
        self.image(data, 8, Some(parms))
    }

    /// An image XObject of the bitmap at one bit per pixel, black where it is darker than
    /// `threshold`.
    ///
    /// # Errors
    ///
    /// A message when the image does not compress.
    pub fn bilevel_image(&self, threshold: u8) -> Result<Stream, String> {
        let row_bytes = self.width.div_ceil(8);
        let mut data = vec![0u8; row_bytes * self.height];
        for (y, row) in self.pixels.chunks(self.width.max(1)).enumerate() {
            for (x, pixel) in row.iter().enumerate() {
                if *pixel >= threshold
                    && let Some(byte) = data.get_mut(y * row_bytes + x / 8)
                {
                    *byte |= 0x80 >> (x % 8);
                }
            }
        }
        self.image(data, 1, None)
    }

    fn image(&self, data: Vec<u8>, bits: i64, parms: Option<Dictionary>) -> Result<Stream, String> {
        let mut dict = dictionary! {
            "Type" => "XObject",
            "Subtype" => "Image",
            "Width" => i64::try_from(self.width).map_err(|err| err.to_string())?,
            "Height" => i64::try_from(self.height).map_err(|err| err.to_string())?,
            "ColorSpace" => "DeviceGray",
            "BitsPerComponent" => bits,
        };
        if let Some(parms) = parms {
            dict.set("DecodeParms", parms);
        }
        let mut stream = Stream::new(dict, data);
        stream.compress().map_err(|err| err.to_string())?;
        if stream.dict.get(b"Filter").is_err() {
            return Err("the scan did not compress".to_owned());
        }
        Ok(stream)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rectangles_cover_their_pixels_and_part_of_their_edges() {
        let mut gray = Gray::new(4, 2, 255);
        gray.fill_rect((1.0, 0.0), (2.5, 1.0), 0);
        assert_eq!(gray.pixels, [255, 0, 128, 255, 255, 255, 255, 255]);
    }

    #[test]
    fn a_quarter_turn_moves_a_corner_to_the_next_one() {
        let mut gray = Gray::new(2, 2, 255);
        gray.pixels[0] = 0;
        let turned = gray.turned(1.0, 0.0, 255);
        assert_eq!(turned.pixels, [255, 0, 255, 255]);
    }

    #[test]
    fn bilevel_rows_are_padded_to_a_byte() {
        let mut gray = Gray::new(10, 40, 255);
        gray.pixels[0] = 0;
        let mut stream = gray.bilevel_image(128).unwrap();
        assert_eq!(
            stream
                .dict
                .get(b"BitsPerComponent")
                .unwrap()
                .as_i64()
                .unwrap(),
            1
        );
        stream.decompress().unwrap();
        assert_eq!(stream.content.len(), 2 * 40);
        assert_eq!(stream.content[..3], [0x7F, 0xC0, 0xFF]);
    }
}
