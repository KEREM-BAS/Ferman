//! What Compress reads and changes in a document (a9-1, decisions 25 and 26 of the M4 plan), as
//! primitives for ferman-ops, which plans and recompresses.
//!
//! - [`RevisionStore::image_scan`]: the image XObjects the pages draw, with the largest size each
//!   is drawn at (pages, forms and annotation appearances, through `cm` and form matrices), and
//!   the counts of those left as they are: images in a format or colour Compress does not decode
//!   (JPX, JBIG2, CCITT, filter chains, CMYK, indexed, other than 8 bits, a `/Decode`), masks
//!   (`/ImageMask`, an image another names as `/SMask` or `/Mask`, and an image with a colour-key
//!   `/Mask`, which a lossy encoding would break), and images reached only through patterns.
//! - [`RevisionStore::merge_duplicate_fonts`]: font descriptors that embed byte-identical font
//!   programs point at one of them, so a rewrite writes it once.
//! - [`RevisionStore::remove_thumbnails`]: `/Thumb` goes from every page.
//!
//! Inline images are part of their content stream and stay as they are.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet};

use lopdf::{Dictionary, Object, ObjectId};
use sha2::{Digest, Sha256};

use crate::content;
use crate::revision::{RevisionStore, decoded};
use crate::structure::{Scope, inherited};
use crate::write::ObjectRef;
use crate::{CoreError, Document};

/// How deep forms nest inside forms before the walk stops.
const MAX_FORM_DEPTH: u32 = 16;

/// The font program keys of a font descriptor.
const FONT_FILES: [&[u8]; 3] = [b"FontFile", b"FontFile2", b"FontFile3"];

/// How an image's data is stored.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ImageFilter {
    /// No filter.
    None,
    /// `/FlateDecode`, without a predictor that changes the samples' layout.
    Flate,
    /// `/DCTDecode`: a JPEG.
    Dct,
}

/// An image's colour.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ImageColour {
    /// One component.
    Gray,
    /// Three components.
    Rgb,
}

/// An image Compress may recompress.
#[derive(Debug, Clone, PartialEq)]
pub struct ImageFacts {
    /// The image XObject.
    pub id: ObjectRef,
    /// Its width and height in samples.
    pub width: u32,
    /// See `width`.
    pub height: u32,
    /// Its stored data's length in bytes.
    pub bytes: u64,
    /// How its data is stored.
    pub filter: ImageFilter,
    /// Its colour.
    pub colour: ImageColour,
    /// The largest width and height it is drawn at, in points.
    pub drawn: (f32, f32),
}

/// The images of a document as Compress sees them.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ImageScan {
    /// The images it may recompress, in object order.
    pub images: Vec<ImageFacts>,
    /// Images in a format or colour it does not decode.
    pub unreadable: u32,
    /// Masks, and images with a colour-key mask.
    pub masks: u32,
    /// Images drawn only through a pattern.
    pub patterns: u32,
}

/// An image the walk met: its facts, or why it stays.
enum Seen {
    Candidate(ImageFacts),
    Unreadable,
    Mask,
}

/// The walk's state: what was drawn and how large.
struct Walk<'a> {
    store: &'a RevisionStore,
    doc: &'a Document,
    drawn: BTreeMap<ObjectId, (f32, f32)>,
    /// Images in a pattern's resources, and masks named by images.
    in_patterns: BTreeSet<ObjectId>,
    masks: BTreeSet<ObjectId>,
    forms: BTreeSet<(ObjectId, [i64; 6])>,
}

type Matrix = [f32; 6];

const IDENTITY: Matrix = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

/// `a` then `b`.
#[allow(clippy::arithmetic_side_effects)] // Floating point.
fn multiply(a: &Matrix, b: &Matrix) -> Matrix {
    [
        a[0] * b[0] + a[1] * b[2],
        a[0] * b[1] + a[1] * b[3],
        a[2] * b[0] + a[3] * b[2],
        a[2] * b[1] + a[3] * b[3],
        a[4] * b[0] + a[5] * b[2] + b[4],
        a[4] * b[1] + a[5] * b[3] + b[5],
    ]
}

fn matrix_of(operands: &[Object]) -> Option<Matrix> {
    let values: Vec<f32> = operands
        .iter()
        .filter_map(crate::structure::number)
        .collect();
    <[f32; 6]>::try_from(values.as_slice())
        .ok()
        .filter(|matrix| matrix.iter().all(|value| value.is_finite()))
}

impl Walk<'_> {
    /// Walks `data` drawn with `resources` under `ctm`.
    fn content(
        &mut self,
        data: &[u8],
        resources: Option<&Dictionary>,
        ctm: Matrix,
        depth: u32,
    ) -> Result<(), CoreError> {
        let operators = content::operators(data, self.doc.limits())?;
        let mut stack = Vec::new();
        let mut ctm = ctm;
        for operator in operators {
            match operator.name.as_slice() {
                b"q" => stack.push(ctm),
                b"Q" => ctm = stack.pop().unwrap_or(ctm),
                b"cm" => {
                    if let Some(matrix) = matrix_of(&operator.operands) {
                        ctm = multiply(&matrix, &ctm);
                    }
                }
                b"Do" => {
                    if let [Object::Name(name)] = operator.operands.as_slice() {
                        self.draw(name, resources, ctm, depth)?;
                    }
                }
                _ => {}
            }
        }
        if let Some(resources) = resources {
            self.patterns(resources, depth)?;
        }
        Ok(())
    }

    /// The XObject `name` of `resources` drawn under `ctm`.
    fn draw(
        &mut self,
        name: &[u8],
        resources: Option<&Dictionary>,
        ctm: Matrix,
        depth: u32,
    ) -> Result<(), CoreError> {
        let scope = self.store.scope(self.doc);
        let Some(id) = resources
            .and_then(|resources| scope.get_dict(resources, b"XObject"))
            .and_then(|xobjects| xobjects.get(name).ok())
            .and_then(|item| item.as_reference().ok())
        else {
            return Ok(());
        };
        let Some(Object::Stream(stream)) = scope.object(id) else {
            return Ok(());
        };
        match scope.get_name(&stream.dict, b"Subtype") {
            Some(b"Image") => {
                let size = (ctm[0].hypot(ctm[1]), ctm[2].hypot(ctm[3]));
                let entry = self.drawn.entry(id).or_insert((0.0, 0.0));
                *entry = (entry.0.max(size.0), entry.1.max(size.1));
                for key in [&b"SMask"[..], b"Mask"] {
                    if let Ok(Object::Reference(mask)) = stream.dict.get(key) {
                        self.masks.insert(*mask);
                    }
                }
            }
            Some(b"Form") => {
                let matrix = stream
                    .dict
                    .get(b"Matrix")
                    .ok()
                    .and_then(|matrix| scope.resolve(matrix))
                    .and_then(|matrix| matrix.as_array().ok())
                    .and_then(|matrix| matrix_of(matrix))
                    .unwrap_or(IDENTITY);
                let ctm = multiply(&matrix, &ctm);
                self.form(
                    id,
                    stream.dict.get(b"Resources").ok(),
                    resources,
                    ctm,
                    depth,
                )?;
            }
            _ => {}
        }
        Ok(())
    }

    /// Form `id` drawn under `ctm`, with its own resources or else its parent's.
    fn form(
        &mut self,
        id: ObjectId,
        own: Option<&Object>,
        parent: Option<&Dictionary>,
        ctm: Matrix,
        depth: u32,
    ) -> Result<(), CoreError> {
        let Some(depth) = depth
            .checked_add(1)
            .filter(|&depth| depth <= MAX_FORM_DEPTH)
        else {
            return Ok(());
        };
        // The same form at the same size is walked once.
        #[allow(clippy::cast_possible_truncation)] // A key, not a value.
        let key = ctm.map(|value| (value * 100.0) as i64);
        if !self.forms.insert((id, key)) {
            return Ok(());
        }
        let scope = self.store.scope(self.doc);
        let Some(Object::Stream(stream)) = scope.object(id) else {
            return Ok(());
        };
        let data = decoded(stream, self.doc).unwrap_or_default();
        let resources = own.and_then(|own| scope.dict(own)).or(parent);
        self.content(&data, resources, ctm, depth)
    }

    /// Every image in the patterns of `resources`, and in their own resources, as reached through
    /// a pattern.
    fn patterns(&mut self, resources: &Dictionary, depth: u32) -> Result<(), CoreError> {
        let scope = self.store.scope(self.doc);
        let Some(patterns) = scope.get_dict(resources, b"Pattern") else {
            return Ok(());
        };
        let mut stack: Vec<(&Dictionary, u32)> = patterns
            .iter()
            .filter_map(|(_, pattern)| scope.dict(pattern))
            .filter_map(|pattern| scope.get_dict(pattern, b"Resources"))
            .map(|resources| (resources, depth))
            .collect();
        let mut seen = BTreeSet::new();
        while let Some((resources, depth)) = stack.pop() {
            if depth > MAX_FORM_DEPTH {
                continue;
            }
            let Some(xobjects) = scope.get_dict(resources, b"XObject") else {
                continue;
            };
            for (_, item) in xobjects {
                let Ok(id) = item.as_reference() else {
                    continue;
                };
                if !seen.insert(id) {
                    continue;
                }
                let Some(Object::Stream(stream)) = scope.object(id) else {
                    continue;
                };
                match scope.get_name(&stream.dict, b"Subtype") {
                    Some(b"Image") => {
                        self.in_patterns.insert(id);
                    }
                    Some(b"Form") => {
                        if let Some(inner) = scope.get_dict(&stream.dict, b"Resources") {
                            stack.push((inner, depth.saturating_add(1)));
                        }
                    }
                    _ => {}
                }
            }
        }
        Ok(())
    }
}

/// What image `id` is to Compress.
fn facts(scope: &Scope<'_>, id: ObjectId, drawn: (f32, f32)) -> Seen {
    let Some(Object::Stream(stream)) = scope.object(id) else {
        return Seen::Unreadable;
    };
    let dict = &stream.dict;
    if scope
        .get(dict, b"ImageMask")
        .is_some_and(|mask| mask.as_bool().unwrap_or(false))
    {
        return Seen::Mask;
    }
    if scope
        .get(dict, b"Mask")
        .is_some_and(|mask| mask.as_array().is_ok())
    {
        return Seen::Mask;
    }
    let filter = match scope.get(dict, b"Filter") {
        None => ImageFilter::None,
        Some(Object::Name(name)) => match name.as_slice() {
            b"FlateDecode" | b"Fl" => ImageFilter::Flate,
            b"DCTDecode" | b"DCT" => ImageFilter::Dct,
            _ => return Seen::Unreadable,
        },
        Some(Object::Array(items)) => match items.as_slice() {
            [Object::Name(name)] if name.as_slice() == b"FlateDecode" => ImageFilter::Flate,
            [Object::Name(name)] if name.as_slice() == b"DCTDecode" => ImageFilter::Dct,
            _ => return Seen::Unreadable,
        },
        Some(_) => return Seen::Unreadable,
    };
    let colour = match scope.get(dict, b"ColorSpace") {
        Some(Object::Name(name)) => match name.as_slice() {
            b"DeviceGray" | b"G" | b"CalGray" => Some(ImageColour::Gray),
            b"DeviceRGB" | b"RGB" | b"CalRGB" => Some(ImageColour::Rgb),
            _ => None,
        },
        Some(Object::Array(items)) => match items.as_slice() {
            [Object::Name(kind), _] if kind.as_slice() == b"CalGray" => Some(ImageColour::Gray),
            [Object::Name(kind), _] if kind.as_slice() == b"CalRGB" => Some(ImageColour::Rgb),
            [Object::Name(kind), profile] if kind.as_slice() == b"ICCBased" => scope
                .dict(profile)
                .and_then(|profile| scope.get_int(profile, b"N"))
                .and_then(|n| match n {
                    1 => Some(ImageColour::Gray),
                    3 => Some(ImageColour::Rgb),
                    _ => None,
                }),
            _ => None,
        },
        _ => None,
    };
    let int = |key: &[u8]| {
        scope
            .get_int(dict, key)
            .and_then(|value| u32::try_from(value).ok())
    };
    let predictor = scope
        .get_dict(dict, b"DecodeParms")
        .and_then(|parms| scope.get_int(parms, b"Predictor"));
    let (Some(colour), Some(width), Some(height), Some(8)) = (
        colour,
        int(b"Width"),
        int(b"Height"),
        int(b"BitsPerComponent"),
    ) else {
        return Seen::Unreadable;
    };
    if width == 0
        || height == 0
        || dict.has(b"Decode")
        || (filter == ImageFilter::Dct && dict.has(b"DecodeParms"))
        || predictor.is_some_and(|predictor| predictor > 1 && predictor < 10)
    {
        return Seen::Unreadable;
    }
    Seen::Candidate(ImageFacts {
        id: ObjectRef(id),
        width,
        height,
        bytes: u64::try_from(stream.content.len()).unwrap_or(u64::MAX),
        filter,
        colour,
        drawn,
    })
}

impl RevisionStore {
    /// The images the current revision draws, as Compress sees them.
    ///
    /// # Errors
    ///
    /// The content lexer's [`CoreError::ResourceLimit`].
    pub fn image_scan(&self, doc: &Document) -> Result<ImageScan, CoreError> {
        let scope = self.scope(doc);
        let mut walk = Walk {
            store: self,
            doc,
            drawn: BTreeMap::new(),
            in_patterns: BTreeSet::new(),
            masks: BTreeSet::new(),
            forms: BTreeSet::new(),
        };
        for page in self.pages(doc) {
            let Some(Object::Dictionary(dict)) = scope.object(page.id) else {
                continue;
            };
            let mut data = Vec::new();
            for stream in self.contents(doc, page.id) {
                if let Some(Object::Stream(stream)) = scope.object(stream) {
                    data.extend(decoded(stream, doc).unwrap_or_default());
                    data.push(b'\n');
                }
            }
            let resources = inherited(&scope, dict, b"Resources").and_then(|r| scope.dict(r));
            walk.content(&data, resources, IDENTITY, 0)?;
            // Annotation appearances, in their own space.
            for annotation in scope.get_array(dict, b"Annots").into_iter().flatten() {
                let appearance = scope
                    .dict(annotation)
                    .and_then(|annotation| scope.get_dict(annotation, b"AP"))
                    .and_then(|ap| ap.get(b"N").ok());
                let mut forms: Vec<ObjectId> = Vec::new();
                match appearance {
                    Some(Object::Reference(id)) => {
                        if matches!(scope.object(*id), Some(Object::Stream(_))) {
                            forms.push(*id);
                        } else if let Some(states) = scope.object(*id).and_then(|o| scope.dict(o)) {
                            forms.extend(states.iter().filter_map(|(_, s)| s.as_reference().ok()));
                        }
                    }
                    Some(Object::Dictionary(states)) => {
                        forms.extend(states.iter().filter_map(|(_, s)| s.as_reference().ok()));
                    }
                    _ => {}
                }
                for form in forms {
                    let own = match scope.object(form) {
                        Some(Object::Stream(stream)) => stream.dict.get(b"Resources").ok(),
                        _ => None,
                    };
                    walk.form(form, own, None, IDENTITY, 0)?;
                }
            }
        }
        let mut scan = ImageScan::default();
        let masks = walk.masks.clone();
        for (id, drawn) in &walk.drawn {
            if masks.contains(id) {
                scan.masks = scan.masks.saturating_add(1);
                continue;
            }
            match facts(&scope, *id, *drawn) {
                Seen::Candidate(facts) => scan.images.push(facts),
                Seen::Unreadable => scan.unreadable = scan.unreadable.saturating_add(1),
                Seen::Mask => scan.masks = scan.masks.saturating_add(1),
            }
        }
        // A mask no drawn image names as such was counted with the masks already.
        scan.masks = scan.masks.saturating_add(
            u32::try_from(
                masks
                    .iter()
                    .filter(|mask| !walk.drawn.contains_key(mask))
                    .count(),
            )
            .unwrap_or(u32::MAX),
        );
        scan.patterns = u32::try_from(
            walk.in_patterns
                .iter()
                .filter(|id| !walk.drawn.contains_key(id) && !masks.contains(id))
                .count(),
        )
        .unwrap_or(u32::MAX);
        Ok(scan)
    }

    /// Points the font descriptors that embed byte-identical font programs at one of them, in the
    /// open transaction; how many copies became unused.
    ///
    /// # Errors
    ///
    /// [`crate::WriteError::NoTransaction`].
    pub fn merge_duplicate_fonts(&mut self, doc: &Document) -> Result<u32, CoreError> {
        self.transaction_open()?;
        let mut ids: BTreeSet<ObjectId> = doc.model().objects.keys().copied().collect();
        ids.extend(self.committed().keys());
        let mut first: BTreeMap<[u8; 32], ObjectId> = BTreeMap::new();
        let mut canonical: BTreeMap<ObjectId, ObjectId> = BTreeMap::new();
        let mut descriptors = Vec::new();
        {
            let scope = self.scope(doc);
            for id in ids {
                let Some(Object::Dictionary(dict)) = scope.object(id) else {
                    continue;
                };
                if scope.get_name(dict, b"Type") != Some(b"FontDescriptor") {
                    continue;
                }
                let mut repoint = false;
                for key in FONT_FILES {
                    let Ok(Object::Reference(file)) = dict.get(key) else {
                        continue;
                    };
                    let Some(Object::Stream(stream)) = scope.object(*file) else {
                        continue;
                    };
                    if canonical.contains_key(file) {
                        repoint |= canonical.get(file) != Some(file);
                        continue;
                    }
                    let mut hash = Sha256::new();
                    let mut keys = stream.dict.clone();
                    keys.remove(b"Length");
                    let mut header = Vec::new();
                    crate::appendix::object(&mut header, &Object::Dictionary(keys));
                    hash.update(&header);
                    hash.update(b"\0");
                    hash.update(&stream.content);
                    let digest: [u8; 32] = hash.finalize().into();
                    let kept = *first.entry(digest).or_insert(*file);
                    canonical.insert(*file, kept);
                    repoint |= kept != *file;
                }
                if repoint {
                    descriptors.push((id, dict.clone()));
                }
            }
        }
        let mut merged = BTreeSet::new();
        for (id, mut dict) in descriptors {
            for key in FONT_FILES {
                if let Ok(Object::Reference(file)) = dict.get(key).cloned()
                    && let Some(&kept) = canonical.get(&file)
                    && kept != file
                {
                    merged.insert(file);
                    dict.set(key.to_vec(), Object::Reference(kept));
                }
            }
            self.put(id, Object::Dictionary(dict))?;
        }
        Ok(u32::try_from(merged.len()).unwrap_or(u32::MAX))
    }

    /// Takes `/Thumb` out of every page in the open transaction; how many pages had one.
    ///
    /// # Errors
    ///
    /// [`crate::WriteError::NoTransaction`].
    pub fn remove_thumbnails(&mut self, doc: &Document) -> Result<u32, CoreError> {
        self.transaction_open()?;
        let pages: Vec<(ObjectId, Dictionary)> = {
            let scope = self.scope(doc);
            self.pages(doc)
                .iter()
                .filter_map(|page| match scope.object(page.id) {
                    Some(Object::Dictionary(dict)) if dict.has(b"Thumb") => {
                        Some((page.id, dict.clone()))
                    }
                    _ => None,
                })
                .collect()
        };
        let count = u32::try_from(pages.len()).unwrap_or(u32::MAX);
        for (id, mut dict) in pages {
            dict.remove(b"Thumb");
            self.put(id, Object::Dictionary(dict))?;
        }
        Ok(count)
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::path::PathBuf;

    use super::*;
    use crate::{OpenOptions, Source, open};

    fn opened(name: &str) -> Document {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(format!("{name}.pdf"));
        let bytes = std::fs::read(path).unwrap();
        open(&Source::from_bytes(bytes.into()), &OpenOptions::default()).unwrap()
    }

    #[test]
    fn the_image_file_counts_what_compress_leaves() {
        let doc = opened("images-compress");
        let scan = RevisionStore::new(&doc).image_scan(&doc).unwrap();
        // Flate RGB (drawn twice, once), grey with predictors (left: predictor 15 is fine), DCT
        // grey and YCbCr; the image in a form.
        assert!(!scan.images.is_empty());
        assert!(scan.unreadable >= 3, "JPX, CMYK, indexed: {scan:?}");
        assert!(
            scan.masks >= 3,
            "SMask, Mask, colour key, ImageMask: {scan:?}"
        );
        assert_eq!(scan.patterns, 1, "{scan:?}");
        for image in &scan.images {
            assert!(image.drawn.0 > 0.0 && image.drawn.1 > 0.0, "{image:?}");
        }
    }

    #[test]
    fn thumbnails_and_duplicate_fonts_go_in_a_transaction() {
        let doc = opened("kira-tr");
        let mut store = RevisionStore::new(&doc);
        assert!(store.remove_thumbnails(&doc).is_err(), "no transaction");
        store.begin().unwrap();
        assert_eq!(store.remove_thumbnails(&doc).unwrap(), 0);
        assert_eq!(store.merge_duplicate_fonts(&doc).unwrap(), 0);
        store.commit().unwrap();
        assert_eq!(store.current(), 0, "nothing changed");
    }
}
