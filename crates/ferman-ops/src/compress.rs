//! Compress (a9-1, ROADMAP §8 step 5, decisions 25 and 26 of the M4 plan): the plan of what a
//! preset changes, an estimate that samples the images by their bytes, and the compressed file.
//!
//! A preset sets a resolution and a JPEG quality. An image drawn finer than 1.25 times the
//! resolution is resampled to it and written as a JPEG; a JPEG that is not resampled is encoded
//! again at the preset's quality. A recompressed image replaces the old one only when it is
//! smaller, and keeps its mask and colour space. Images ferman-core's scan leaves out stay as they
//! are and are counted ([`ImageScan`]); so is an image whose data does not decode. Then
//! byte-identical font programs are merged, `/Thumb` goes, and the result is the
//! [packed rewrite](RevisionStore::packed_rewrite): no earlier revision, no unused object, objects
//! in object streams. A signed document is written without its signatures, which the caller asks
//! about first (decision 25); the original is never touched.
//!
//! The estimate writes the file with fonts merged and thumbnails gone, recompresses a sample of
//! the images of at most [`SAMPLE_BYTES`], every image when they are fewer bytes, and scales the
//! saving it found to all the images' bytes.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use ferman_core::compress::{ImageColour, ImageFacts, ImageFilter, ImageScan};
use ferman_core::limits::Limits;
use ferman_core::revision::RevisionStore;
use ferman_core::write::Value;
use ferman_core::{CoreError, Document};
use image::codecs::jpeg::JpegEncoder;
use image::imageops::FilterType;
use image::{ExtendedColorType, GrayImage, ImageEncoder, RgbImage};

use crate::OpsError;
use crate::images::{Pixels, decode_dct};

/// The image bytes the estimate recompresses at most.
pub const SAMPLE_BYTES: u64 = 16 * 1024 * 1024;

/// An image is resampled when drawn finer than this many times the preset's resolution.
const RESAMPLE_ABOVE: f32 = 1.25;

/// a9-1's presets; Custom… has no form drawn (B182).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Preset {
    /// Images at 300 ppi, for printing.
    HighQuality,
    /// Images at 150 ppi, for sharing and reading on screen.
    Balanced,
    /// Images at 96 ppi, for e-mail.
    Smallest,
}

impl Preset {
    /// The resolution images are resampled to, in pixels per inch.
    #[must_use]
    pub fn ppi(self) -> f32 {
        match self {
            Self::HighQuality => 300.0,
            Self::Balanced => 150.0,
            Self::Smallest => 96.0,
        }
    }

    /// The JPEG quality, 1 to 100.
    #[must_use]
    pub fn quality(self) -> u8 {
        match self {
            Self::HighQuality => 85,
            Self::Balanced => 72,
            Self::Smallest => 55,
        }
    }
}

/// What Compress would change in a document, for every preset.
#[derive(Debug, Clone, PartialEq)]
pub struct Plan {
    /// The images and what stays.
    pub scan: ImageScan,
    /// The images' stored bytes.
    pub image_bytes: u64,
    /// Font program copies that would go.
    pub duplicate_fonts: u32,
    /// Pages with a thumbnail.
    pub thumbnails: u32,
    /// The size of the file now: the original, or the save of the current revision.
    pub before: u64,
}

/// What a preset would make of the file.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Estimate {
    /// The size now.
    pub before: u64,
    /// The size estimated after.
    pub after: u64,
    /// How many images the estimate recompressed.
    pub sampled: u32,
    /// Whether it recompressed every image, so `after` is exact but for rounding.
    pub exact: bool,
}

/// A compressed file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Compressed {
    /// Its bytes.
    pub bytes: Vec<u8>,
    /// The images replaced by a smaller recompression.
    pub recompressed: u32,
    /// Images that the scan listed but whose data did not decode, left as they are.
    pub unreadable: u32,
}

/// What Compress would change in `doc` as `store` leaves it.
///
/// # Errors
///
/// The scan's and the incremental writer's errors.
pub fn plan(doc: &Document, store: &RevisionStore) -> Result<Plan, OpsError> {
    let scan = store.image_scan(doc)?;
    let mut probe = store.clone();
    probe.begin()?;
    let duplicate_fonts = probe.merge_duplicate_fonts(doc)?;
    let thumbnails = probe.remove_thumbnails(doc)?;
    probe.rollback();
    let before = if store.current() == 0 {
        doc.source().bytes().len()
    } else {
        store.incremental_update(doc)?.len()
    };
    Ok(Plan {
        image_bytes: scan.images.iter().map(|image| image.bytes).sum(),
        scan,
        duplicate_fonts,
        thumbnails,
        before: u64::try_from(before).unwrap_or(u64::MAX),
    })
}

/// The estimate of `preset` for `plan`; `unsign` writes a signed document without its
/// signatures, as [`compress`] would. `step` runs before each sampled image and may stop.
///
/// # Errors
///
/// The rewrite's errors, and what `step` returns.
pub fn estimate<E: From<OpsError>>(
    doc: &Document,
    store: &RevisionStore,
    plan: &Plan,
    preset: Preset,
    unsign: bool,
    limits: &Limits,
    step: &mut impl FnMut() -> Result<(), E>,
) -> Result<Estimate, E> {
    sampled_estimate(doc, store, plan, preset, unsign, limits, SAMPLE_BYTES, step)
}

/// [`estimate`] with a sample of at most `budget` image bytes.
#[allow(clippy::too_many_arguments)]
fn sampled_estimate<E: From<OpsError>>(
    doc: &Document,
    store: &RevisionStore,
    plan: &Plan,
    preset: Preset,
    unsign: bool,
    limits: &Limits,
    budget: u64,
    step: &mut impl FnMut() -> Result<(), E>,
) -> Result<Estimate, E> {
    let base = finished(doc, store, unsign)
        .and_then(|working| Ok(working.packed_rewrite(doc)?))
        .map_err(E::from)?;
    let base = u64::try_from(base.len()).unwrap_or(u64::MAX);
    let exact = plan.image_bytes <= budget;
    let stride = if exact {
        1
    } else {
        usize::try_from(plan.image_bytes.div_ceil(budget.max(1))).unwrap_or(usize::MAX)
    };
    let (mut old, mut new, mut sampled) = (0u64, 0u64, 0u32);
    for image in plan.scan.images.iter().step_by(stride.max(1)) {
        step()?;
        sampled = sampled.saturating_add(1);
        old = old.saturating_add(image.bytes);
        let size = match recompressed(doc, store, image, preset, limits) {
            Ok(Some(Value::Encoded { data, .. })) => u64::try_from(data.len()).unwrap_or(u64::MAX),
            _ => image.bytes,
        };
        new = new.saturating_add(size);
    }
    // The saving the sample found, scaled to every image's bytes.
    let saved = if old == 0 {
        0
    } else {
        let ratio = (old.saturating_sub(new)) as f64 / old as f64;
        // A fraction of a byte count: precision does not matter.
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let saved = (plan.image_bytes as f64 * ratio) as u64;
        saved
    };
    Ok(Estimate {
        before: plan.before,
        after: base.saturating_sub(saved),
        sampled,
        exact,
    })
}

/// `doc` as `store` leaves it, compressed with `preset`; `unsign` as [`estimate`] says. `step`
/// runs before each image and may stop.
///
/// # Errors
///
/// The rewrite's errors, and what `step` returns.
pub fn compress<E: From<OpsError>>(
    doc: &Document,
    store: &RevisionStore,
    plan: &Plan,
    preset: Preset,
    unsign: bool,
    limits: &Limits,
    step: &mut impl FnMut() -> Result<(), E>,
) -> Result<Compressed, E> {
    let mut working = store.clone();
    working.begin().map_err(OpsError::from)?;
    let (mut recompressed_count, mut unreadable) = (0u32, 0u32);
    for image in &plan.scan.images {
        step()?;
        match recompressed(doc, store, image, preset, limits) {
            Ok(Some(value)) => {
                working
                    .replace_object(doc, image.id, value)
                    .map_err(OpsError::from)?;
                recompressed_count = recompressed_count.saturating_add(1);
            }
            Ok(None) => {}
            Err(OpsError::UnreadableImage | OpsError::Core(CoreError::Unsupported(_))) => {
                unreadable = unreadable.saturating_add(1);
            }
            Err(other) => return Err(other.into()),
        }
    }
    working.commit().map_err(OpsError::from)?;
    let bytes = finished(doc, &working, unsign)
        .and_then(|working| Ok(working.packed_rewrite(doc)?))
        .map_err(E::from)?;
    Ok(Compressed {
        bytes,
        recompressed: recompressed_count,
        unreadable,
    })
}

/// `store` with duplicate fonts merged and thumbnails gone, unsigned when asked.
fn finished(
    doc: &Document,
    store: &RevisionStore,
    unsign: bool,
) -> Result<RevisionStore, OpsError> {
    let mut working = store.clone();
    working.begin()?;
    working.merge_duplicate_fonts(doc)?;
    working.remove_thumbnails(doc)?;
    working.commit()?;
    Ok(if unsign {
        working.unsigned(doc)?
    } else {
        working
    })
}

/// The new size of an image drawn at `points` with `pixels` along one side, or `None` when it is
/// not drawn finer than [`RESAMPLE_ABOVE`] times `ppi`.
fn resampled(pixels: u32, points: f32, ppi: f32) -> Option<u32> {
    if points < 1.0 {
        return None;
    }
    // Image sizes are far below f32's exact range.
    #[allow(clippy::cast_precision_loss, clippy::arithmetic_side_effects)]
    let drawn_ppi = pixels as f32 * 72.0 / points;
    if drawn_ppi <= ppi * RESAMPLE_ABOVE {
        return None;
    }
    #[allow(
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        clippy::arithmetic_side_effects
    )]
    let target = (points * ppi / 72.0).ceil() as u32;
    Some(target.clamp(1, pixels))
}

/// The recompressed image `facts`, or `None` when it would not change or not shrink.
fn recompressed(
    doc: &Document,
    store: &RevisionStore,
    facts: &ImageFacts,
    preset: Preset,
    limits: &Limits,
) -> Result<Option<Value>, OpsError> {
    let width = resampled(facts.width, facts.drawn.0, preset.ppi());
    let height = resampled(facts.height, facts.drawn.1, preset.ppi());
    let resample = width.is_some() || height.is_some();
    // Lossless images stay lossless unless they shrink.
    if !resample && facts.filter != ImageFilter::Dct {
        return Ok(None);
    }
    let Some(value) = store.object(doc, facts.id)? else {
        return Ok(None);
    };
    let (dict, samples) = match (value, facts.filter) {
        (Value::Encoded { dict, data }, ImageFilter::Dct) => {
            let image = decode_dct(&data, limits)?;
            match image.pixels {
                Pixels::Samples(samples)
                    if (image.width, image.height) == (facts.width, facts.height) =>
                {
                    (dict, samples)
                }
                _ => return Err(OpsError::UnreadableImage),
            }
        }
        (Value::Stream { dict, data }, ImageFilter::Flate | ImageFilter::None) => (dict, data),
        _ => return Err(OpsError::UnreadableImage),
    };
    let (new_width, new_height) = (width.unwrap_or(facts.width), height.unwrap_or(facts.height));
    let mut jpeg = Vec::new();
    let encoder = JpegEncoder::new_with_quality(&mut jpeg, preset.quality());
    let encoded = match facts.colour {
        ImageColour::Gray => {
            let image = GrayImage::from_raw(facts.width, facts.height, samples)
                .ok_or(OpsError::UnreadableImage)?;
            let image = if resample {
                image::imageops::resize(&image, new_width, new_height, FilterType::Triangle)
            } else {
                image
            };
            encoder.write_image(image.as_raw(), new_width, new_height, ExtendedColorType::L8)
        }
        ImageColour::Rgb => {
            let image = RgbImage::from_raw(facts.width, facts.height, samples)
                .ok_or(OpsError::UnreadableImage)?;
            let image = if resample {
                image::imageops::resize(&image, new_width, new_height, FilterType::Triangle)
            } else {
                image
            };
            encoder.write_image(
                image.as_raw(),
                new_width,
                new_height,
                ExtendedColorType::Rgb8,
            )
        }
    };
    encoded.map_err(|_| OpsError::Internal {
        context: "a JPEG encoder",
    })?;
    if u64::try_from(jpeg.len()).unwrap_or(u64::MAX) >= facts.bytes {
        return Ok(None);
    }
    let mut dict: Vec<(Vec<u8>, Value)> = dict
        .into_iter()
        .filter(|(key, _)| {
            !matches!(
                key.as_slice(),
                b"Filter"
                    | b"DecodeParms"
                    | b"Length"
                    | b"DL"
                    | b"Width"
                    | b"Height"
                    | b"BitsPerComponent"
            )
        })
        .collect();
    dict.extend([
        (b"Width".to_vec(), Value::Integer(i64::from(new_width))),
        (b"Height".to_vec(), Value::Integer(i64::from(new_height))),
        (b"BitsPerComponent".to_vec(), Value::Integer(8)),
        (b"Filter".to_vec(), Value::Name(b"DCTDecode".to_vec())),
    ]);
    Ok(Some(Value::Encoded { dict, data: jpeg }))
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::path::PathBuf;

    use ferman_core::{OpenOptions, Source, open};

    use super::*;

    fn opened(name: &str) -> Document {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(format!("{name}.pdf"));
        let bytes = std::fs::read(path).unwrap();
        open(&Source::from_bytes(bytes.into()), &OpenOptions::default()).unwrap()
    }

    #[test]
    fn resampling_starts_past_a_quarter_over_the_resolution() {
        // 300 pixels over an inch: 300 ppi.
        assert_eq!(resampled(300, 72.0, 300.0), None);
        assert_eq!(resampled(300, 72.0, 150.0), Some(150));
        assert_eq!(resampled(180, 72.0, 150.0), None, "1.2 times");
        assert_eq!(resampled(300, 0.5, 150.0), None, "not drawn");
    }

    #[test]
    fn every_preset_shrinks_the_image_file_as_estimated_and_reads_back() {
        let doc = opened("images-compress");
        let store = RevisionStore::new(&doc);
        let plan = plan(&doc, &store).unwrap();
        assert!(plan.image_bytes > 0);
        let limits = OpenOptions::default().limits;
        let mut go = || Ok::<(), OpsError>(());
        let mut last = u64::MAX;
        for preset in [Preset::HighQuality, Preset::Balanced, Preset::Smallest] {
            let estimate = estimate(&doc, &store, &plan, preset, false, &limits, &mut go).unwrap();
            assert!(estimate.exact);
            let done = compress(&doc, &store, &plan, preset, false, &limits, &mut go).unwrap();
            let after = done.bytes.len() as u64;
            assert!(
                after < plan.before,
                "{preset:?}: {after} of {}",
                plan.before
            );
            assert!(after <= last, "a smaller preset is no larger");
            last = after;
            let error = (estimate.after as f64 - after as f64).abs() / after as f64;
            assert!(error <= 0.15, "{preset:?}: {} for {after}", estimate.after);
            let again = open(
                &Source::from_bytes(done.bytes.into()),
                &OpenOptions::default(),
            )
            .unwrap();
            assert_eq!(again.page_count(), doc.page_count());
            let rescan = RevisionStore::new(&again).image_scan(&again).unwrap();
            assert_eq!(rescan.unreadable, plan.scan.unreadable + done.unreadable);
            assert_eq!(rescan.masks, plan.scan.masks);
            assert_eq!(rescan.patterns, plan.scan.patterns);
        }
    }

    #[test]
    fn a_large_document_is_estimated_from_a_sample() {
        let doc = opened("images-compress");
        let store = RevisionStore::new(&doc);
        let plan = plan(&doc, &store).unwrap();
        let limits = OpenOptions::default().limits;
        let mut go = || Ok::<(), OpsError>(());
        let budget = plan.image_bytes / 3;
        let estimate = sampled_estimate(
            &doc,
            &store,
            &plan,
            Preset::Smallest,
            false,
            &limits,
            budget,
            &mut go,
        )
        .unwrap();
        assert!(!estimate.exact);
        assert!((estimate.sampled as usize) < plan.scan.images.len());
        assert!(estimate.after < estimate.before);
        let exact = estimate_all(&doc, &store, &plan);
        assert!(
            estimate.after + plan.image_bytes >= exact,
            "{estimate:?} against {exact}"
        );
    }

    fn estimate_all(doc: &Document, store: &RevisionStore, plan: &Plan) -> u64 {
        let limits = OpenOptions::default().limits;
        let mut go = || Ok::<(), OpsError>(());
        estimate(doc, store, plan, Preset::Smallest, false, &limits, &mut go)
            .unwrap()
            .after
    }

    #[test]
    fn a_stop_ends_the_work() {
        let doc = opened("images-compress");
        let store = RevisionStore::new(&doc);
        let plan = plan(&doc, &store).unwrap();
        let limits = OpenOptions::default().limits;
        let mut stop = || Err::<(), OpsError>(OpsError::Internal { context: "stop" });
        assert!(
            compress(
                &doc,
                &store,
                &plan,
                Preset::Balanced,
                false,
                &limits,
                &mut stop
            )
            .is_err()
        );
    }
}
