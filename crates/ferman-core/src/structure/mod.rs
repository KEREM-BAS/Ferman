//! The structure scan (docs/ARCHITECTURE.md §2.3 and §5.1): what a document holds besides its
//! page content, read from the lopdf model into Ferman's own types, so lopdf objects never leave
//! ferman-core (ADR 0004).
//!
//! - **Pages** in lopdf's page-tree order, with inherited boxes and rotation, the size PDFium
//!   gives them (for the two-parser check of G102), and their labels.
//! - **Navigation:** the outline and the attachments ([`navigation`]).
//! - **Interactive content:** layers, form fields and XFA, signatures and certification, and
//!   document JavaScript, which Ferman never runs ([`interactive`]).
//! - **Fonts** used by each page's resources, and whether each is embedded ([`fonts`]).
//! - **Document information**, `/Lang` and `/ViewerPreferences /Direction`.
//!
//! Every walk is bounded: page-tree and outline depth by [`Limits::max_nesting`], references by
//! cycle detection. A part that cannot be read is left empty, never an error: the document still
//! opens, and the scan reports what it found.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet};

use lopdf::{Dictionary, Object, ObjectId};

use crate::limits::Limits;
use crate::text_string;

pub mod fonts;
pub mod interactive;
pub mod navigation;

pub use fonts::{FontKind, FontUse};
pub use interactive::{Forms, Layer, Scripts, Signature};
pub use navigation::{Attachment, OutlineItem};

/// US Letter, PDFium's page size when `/MediaBox` is missing or empty.
const LETTER: Rect = Rect {
    left: 0.0,
    bottom: 0.0,
    right: 612.0,
    top: 792.0,
};

/// A rectangle in page space, normalized: left ≤ right and bottom ≤ top.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Rect {
    /// The left edge.
    pub left: f32,
    /// The bottom edge.
    pub bottom: f32,
    /// The right edge.
    pub right: f32,
    /// The top edge.
    pub top: f32,
}

impl Rect {
    /// The width.
    #[must_use]
    pub fn width(&self) -> f32 {
        self.right - self.left
    }

    /// The height.
    #[must_use]
    pub fn height(&self) -> f32 {
        self.top - self.bottom
    }

    /// Whether it has no area, as PDFium decides it.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.left >= self.right || self.bottom >= self.top
    }

    /// The intersection, or a zero rectangle when they do not overlap (PDFium's `Intersect`).
    #[must_use]
    pub fn intersect(&self, other: &Self) -> Self {
        let out = Self {
            left: self.left.max(other.left),
            bottom: self.bottom.max(other.bottom),
            right: self.right.min(other.right),
            top: self.top.min(other.top),
        };
        if out.is_empty() {
            Self {
                left: 0.0,
                bottom: 0.0,
                right: 0.0,
                top: 0.0,
            }
        } else {
            out
        }
    }
}

/// One page.
#[derive(Debug, Clone, PartialEq)]
pub struct Page {
    /// Its index, from 0.
    pub index: u32,
    /// Its label (`/PageLabels`), such as "iv" or "A-3", when the document has labels.
    pub label: Option<String>,
    /// `/MediaBox`, inherited; US Letter when missing or empty.
    pub media_box: Rect,
    /// `/CropBox`, inherited and clipped to the media box; the media box when missing.
    pub crop_box: Rect,
    /// `/Rotate`, inherited, as 0, 90, 180 or 270.
    pub rotation: u16,
    /// The width and height as displayed: the crop box, turned by the rotation. This is what
    /// PDFium's `FPDF_GetPageSizeByIndexF` gives.
    pub size: (f32, f32),
    /// The page object.
    pub(crate) id: ObjectId,
}

/// The order of pages in spreads and books (`/ViewerPreferences /Direction`, G32).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub enum Direction {
    /// Left to right, the default.
    #[default]
    LeftToRight,
    /// Right to left: page 1 sits on the right of a spread.
    RightToLeft,
}

/// A date in a PDF date string (ISO 32000-2 §7.9.4), as written.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct PdfDate {
    /// The year.
    pub year: u16,
    /// The month, 1 to 12.
    pub month: u8,
    /// The day, 1 to 31.
    pub day: u8,
    /// The hour, 0 to 23.
    pub hour: u8,
    /// The minute, 0 to 59.
    pub minute: u8,
    /// The second, 0 to 59.
    pub second: u8,
    /// The offset from UTC in minutes, when the string gives one.
    pub offset_minutes: Option<i16>,
}

impl PdfDate {
    /// Parses `D:YYYYMMDDHHmmSSOHH'mm'`, leniently: everything after the year is optional, and
    /// the `D:` prefix too.
    #[must_use]
    pub fn parse(text: &str) -> Option<Self> {
        let text = text.trim();
        let text = text.strip_prefix("D:").unwrap_or(text);
        let bytes = text.as_bytes();
        let field = |from: usize, len: usize| -> Option<u32> {
            let digits = bytes.get(from..from.checked_add(len)?)?;
            if !digits.iter().all(u8::is_ascii_digit) {
                return None;
            }
            std::str::from_utf8(digits).ok()?.parse().ok()
        };
        let year = u16::try_from(field(0, 4)?).ok()?;
        let mut date = Self {
            year,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            offset_minutes: None,
        };
        let mut at = 4usize;
        for (slot, max) in [
            (&mut date.month, 12u32),
            (&mut date.day, 31),
            (&mut date.hour, 23),
            (&mut date.minute, 59),
            (&mut date.second, 59),
        ] {
            let Some(value) = field(at, 2) else {
                break;
            };
            let min = u32::from(max == 12 || max == 31);
            if !(min..=max).contains(&value) {
                return None;
            }
            *slot = u8::try_from(value).ok()?;
            at = at.saturating_add(2);
        }
        match bytes.get(at) {
            Some(b'Z') => date.offset_minutes = Some(0),
            Some(&sign @ (b'+' | b'-')) => {
                let hours = field(at.saturating_add(1), 2)?;
                let minutes = field(at.saturating_add(4), 2)
                    .or_else(|| field(at.saturating_add(3), 2))
                    .unwrap_or(0);
                if hours > 23 || minutes > 59 {
                    return None;
                }
                let total = i16::try_from(hours.checked_mul(60)?.checked_add(minutes)?).ok()?;
                date.offset_minutes = Some(if sign == b'-' {
                    total.checked_neg()?
                } else {
                    total
                });
            }
            _ => {}
        }
        Some(date)
    }
}

/// The document information dictionary (`/Info`), as text.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Info {
    /// `/Title`.
    pub title: Option<String>,
    /// `/Author`.
    pub author: Option<String>,
    /// `/Subject`.
    pub subject: Option<String>,
    /// `/Keywords`.
    pub keywords: Option<String>,
    /// `/Creator`: the application that made the original.
    pub creator: Option<String>,
    /// `/Producer`: the application that wrote the PDF.
    pub producer: Option<String>,
    /// `/CreationDate`.
    pub created: Option<PdfDate>,
    /// `/ModDate`.
    pub modified: Option<PdfDate>,
}

/// Everything the structure scan found.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Structure {
    /// The pages.
    pub pages: Vec<Page>,
    /// The outline (bookmarks).
    pub outline: Vec<OutlineItem>,
    /// Embedded files and file attachment annotations.
    pub attachments: Vec<Attachment>,
    /// Optional content groups (layers), in the order the document gives them.
    pub layers: Vec<Layer>,
    /// Form fields and XFA.
    pub forms: Forms,
    /// Signature fields.
    pub signatures: Vec<Signature>,
    /// The certification signature's `/DocMDP` permission level (1 to 3), when certified.
    pub certification: Option<u8>,
    /// Document JavaScript, which Ferman never runs (Q13, G100).
    pub scripts: Scripts,
    /// The fonts that pages use.
    pub fonts: Vec<FontUse>,
    /// The page order of spreads.
    pub direction: Direction,
    /// `/Lang`, the document's language tag.
    pub language: Option<String>,
    /// `/Info`.
    pub info: Info,
}

/// Whether the two parsers agree (ADR 0004, G102): lopdf's model and PDFium.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Agreement {
    /// The same page count and page sizes.
    Agree,
    /// Different page counts.
    PageCount {
        /// lopdf's.
        model: usize,
        /// PDFium's.
        renderer: usize,
    },
    /// The first page whose size differs.
    PageSize {
        /// Its index.
        page: u32,
    },
}

/// How far page sizes may differ, in points: f32 rounding of the same numbers.
const SIZE_TOLERANCE: f32 = 0.05;

impl Structure {
    /// Compares the pages with the sizes PDFium gives, in page order.
    #[must_use]
    pub fn agrees_with(&self, renderer: &[(f32, f32)]) -> Agreement {
        if self.pages.len() != renderer.len() {
            return Agreement::PageCount {
                model: self.pages.len(),
                renderer: renderer.len(),
            };
        }
        for (page, &(width, height)) in self.pages.iter().zip(renderer) {
            if (page.size.0 - width).abs() > SIZE_TOLERANCE
                || (page.size.1 - height).abs() > SIZE_TOLERANCE
            {
                return Agreement::PageSize { page: page.index };
            }
        }
        Agreement::Agree
    }
}

/// What the scans share: the model, the limits and the page index of each page object.
pub(crate) struct Scope<'a> {
    pub(crate) doc: &'a lopdf::Document,
    pub(crate) limits: &'a Limits,
    pub(crate) page_of: BTreeMap<ObjectId, u32>,
    /// Each annotation's page, from the pages' `/Annots`.
    pub(crate) annotation_page: BTreeMap<ObjectId, u32>,
}

impl<'a> Scope<'a> {
    /// `object` with references followed.
    pub(crate) fn resolve(&self, object: &'a Object) -> Option<&'a Object> {
        self.doc.dereference(object).ok().map(|(_, object)| object)
    }

    /// `object` as a dictionary, references followed.
    pub(crate) fn dict(&self, object: &'a Object) -> Option<&'a Dictionary> {
        match self.resolve(object)? {
            Object::Dictionary(dict) => Some(dict),
            Object::Stream(stream) => Some(&stream.dict),
            _ => None,
        }
    }

    /// `dict[key]`, references followed.
    pub(crate) fn get(&self, dict: &'a Dictionary, key: &[u8]) -> Option<&'a Object> {
        self.resolve(dict.get(key).ok()?)
    }

    /// `dict[key]` as a dictionary.
    pub(crate) fn get_dict(&self, dict: &'a Dictionary, key: &[u8]) -> Option<&'a Dictionary> {
        self.dict(dict.get(key).ok()?)
    }

    /// `dict[key]` as an array.
    pub(crate) fn get_array(&self, dict: &'a Dictionary, key: &[u8]) -> Option<&'a Vec<Object>> {
        self.get(dict, key)?.as_array().ok()
    }

    /// `dict[key]` as a name.
    pub(crate) fn get_name(&self, dict: &'a Dictionary, key: &[u8]) -> Option<&'a [u8]> {
        self.get(dict, key)?.as_name().ok()
    }

    /// `dict[key]` as a text string.
    pub(crate) fn get_text(&self, dict: &'a Dictionary, key: &[u8]) -> Option<String> {
        Some(text_string::decode(self.get(dict, key)?.as_str().ok()?))
    }

    /// `dict[key]` as an integer.
    pub(crate) fn get_int(&self, dict: &'a Dictionary, key: &[u8]) -> Option<i64> {
        self.get(dict, key)?.as_i64().ok()
    }

    /// `dict[key]` as a date.
    pub(crate) fn get_date(&self, dict: &'a Dictionary, key: &[u8]) -> Option<PdfDate> {
        PdfDate::parse(&self.get_text(dict, key)?)
    }

    /// The catalog.
    pub(crate) fn catalog(&self) -> Option<&'a Dictionary> {
        self.doc.catalog().ok()
    }
}

/// A number, integer or real.
pub(crate) fn number(object: &Object) -> Option<f32> {
    object.as_float().ok().filter(|value| value.is_finite())
}

/// A rectangle from an array of four numbers, normalized.
fn rect(scope: &Scope<'_>, object: &Object) -> Option<Rect> {
    let items = scope.resolve(object)?.as_array().ok()?;
    let values: Vec<f32> = items
        .iter()
        .map(|item| scope.resolve(item).and_then(number))
        .collect::<Option<_>>()?;
    let [x0, y0, x1, y1] = <[f32; 4]>::try_from(values).ok()?;
    Some(Rect {
        left: x0.min(x1),
        bottom: y0.min(y1),
        right: x0.max(x1),
        top: y0.max(y1),
    })
}

/// A page attribute, inherited through `/Parent` (ISO 32000-2 §7.7.3.4).
pub(crate) fn inherited<'a>(
    scope: &Scope<'a>,
    page: &'a Dictionary,
    key: &[u8],
) -> Option<&'a Object> {
    let mut node = page;
    let mut seen = BTreeSet::new();
    for _ in 0..=scope.limits.max_nesting {
        if let Ok(value) = node.get(key) {
            return scope.resolve(value);
        }
        let parent = node.get(b"Parent").ok()?;
        let id = parent.as_reference().ok()?;
        if !seen.insert(id) {
            return None;
        }
        node = scope.dict(parent)?;
    }
    None
}

/// Scans `doc`. A part that cannot be read is left empty.
pub(crate) fn scan(doc: &lopdf::Document, limits: &Limits) -> Structure {
    let ids: Vec<ObjectId> = doc.page_iter().collect();
    let mut scope = Scope {
        doc,
        limits,
        page_of: BTreeMap::new(),
        annotation_page: BTreeMap::new(),
    };
    for (index, id) in ids.iter().enumerate() {
        let Ok(index) = u32::try_from(index) else {
            break;
        };
        scope.page_of.entry(*id).or_insert(index);
    }
    for (index, id) in ids.iter().enumerate() {
        let (Ok(index), Ok(page)) = (u32::try_from(index), doc.get_dictionary(*id)) else {
            continue;
        };
        if let Some(annotations) = scope.get_array(page, b"Annots") {
            for annotation in annotations {
                if let Ok(annotation) = annotation.as_reference() {
                    scope.annotation_page.entry(annotation).or_insert(index);
                }
            }
        }
    }
    let labels = labels(&scope, ids.len());
    let pages = ids
        .iter()
        .enumerate()
        .filter_map(|(index, id)| {
            let index = u32::try_from(index).ok()?;
            let label = labels.get(usize::try_from(index).ok()?).cloned().flatten();
            Some(page(&scope, *id, index, label))
        })
        .collect();
    let catalog = scope.catalog();
    let direction = catalog
        .and_then(|catalog| scope.get_dict(catalog, b"ViewerPreferences"))
        .and_then(|preferences| scope.get_name(preferences, b"Direction"))
        .map_or(Direction::LeftToRight, |direction| {
            if direction == b"R2L" {
                Direction::RightToLeft
            } else {
                Direction::LeftToRight
            }
        });
    let (forms, signatures) = interactive::forms(&scope);
    Structure {
        pages,
        outline: navigation::outline(&scope),
        attachments: navigation::attachments(&scope),
        layers: interactive::layers(&scope),
        forms,
        signatures,
        certification: interactive::certification(&scope),
        scripts: interactive::scripts(&scope),
        fonts: fonts::fonts(&scope, &ids),
        direction,
        language: catalog.and_then(|catalog| scope.get_text(catalog, b"Lang")),
        info: info(&scope),
    }
}

/// One page's boxes, rotation and displayed size, as PDFium computes them.
fn page(scope: &Scope<'_>, id: ObjectId, index: u32, label: Option<String>) -> Page {
    let dict = scope.doc.get_dictionary(id).ok();
    let boxed = |key: &[u8]| {
        dict.and_then(|dict| inherited(scope, dict, key))
            .and_then(|value| rect(scope, value))
            .filter(|rect| !rect.is_empty())
    };
    let media_box = boxed(b"MediaBox").unwrap_or(LETTER);
    let crop_box = boxed(b"CropBox").map_or(media_box, |crop| crop.intersect(&media_box));
    let rotate = dict
        .and_then(|dict| inherited(scope, dict, b"Rotate"))
        .and_then(|value| value.as_i64().ok())
        .unwrap_or(0);
    // PDFium: (rotate / 90) % 4, made positive.
    let quarter = (rotate.wrapping_div(90)).rem_euclid(4);
    let rotation = u16::try_from(quarter.saturating_mul(90)).unwrap_or(0);
    let (width, height) = (crop_box.width(), crop_box.height());
    let size = if quarter % 2 == 1 {
        (height, width)
    } else {
        (width, height)
    };
    Page {
        index,
        label,
        media_box,
        crop_box,
        rotation,
        size,
        id,
    }
}

/// The labels of `count` pages from `/PageLabels` (ISO 32000-2 §12.4.2), or none.
fn labels(scope: &Scope<'_>, count: usize) -> Vec<Option<String>> {
    let Some(root) = scope
        .catalog()
        .and_then(|catalog| scope.get_dict(catalog, b"PageLabels"))
    else {
        return Vec::new();
    };
    let mut ranges: Vec<(i64, &Dictionary)> = navigation::number_tree(scope, root)
        .into_iter()
        .filter_map(|(start, value)| Some((start, scope.dict(value)?)))
        .collect();
    ranges.sort_by_key(|(start, _)| *start);
    (0..count)
        .map(|index| {
            let index = i64::try_from(index).ok()?;
            let (start, range) = ranges.iter().rev().find(|(start, _)| *start <= index)?;
            let prefix = scope.get_text(range, b"P").unwrap_or_default();
            let first = scope.get_int(range, b"St").unwrap_or(1).max(1);
            let value = first.checked_add(index.checked_sub(*start)?)?;
            let number = match scope.get_name(range, b"S") {
                Some(b"D") => value.to_string(),
                Some(b"R") => roman(value).to_uppercase(),
                Some(b"r") => roman(value),
                Some(b"A") => letters(value).to_uppercase(),
                Some(b"a") => letters(value),
                _ => String::new(),
            };
            Some(format!("{prefix}{number}"))
        })
        .collect()
}

/// `value` in lowercase roman numerals; thousands repeat `m`.
fn roman(value: i64) -> String {
    const DIGITS: [(i64, &str); 13] = [
        (1000, "m"),
        (900, "cm"),
        (500, "d"),
        (400, "cd"),
        (100, "c"),
        (90, "xc"),
        (50, "l"),
        (40, "xl"),
        (10, "x"),
        (9, "ix"),
        (5, "v"),
        (4, "iv"),
        (1, "i"),
    ];
    // Bounded, so a crafted /St cannot make a huge string.
    let mut rest = value.clamp(1, 100_000);
    let mut out = String::new();
    for (step, digits) in DIGITS {
        while rest >= step {
            out.push_str(digits);
            rest = rest.saturating_sub(step);
        }
    }
    out
}

/// `value` as letters: a to z, then aa to zz, then aaa…
fn letters(value: i64) -> String {
    let value = value.clamp(1, 26 * 1000);
    let index = value.saturating_sub(1);
    let letter = char::from(b'a'.saturating_add(u8::try_from(index % 26).unwrap_or(0)));
    let count = usize::try_from(index / 26).unwrap_or(0).saturating_add(1);
    std::iter::repeat_n(letter, count).collect()
}

/// The document information dictionary.
fn info(scope: &Scope<'_>) -> Info {
    let Some(dict) = scope
        .doc
        .trailer
        .get(b"Info")
        .ok()
        .and_then(|info| scope.dict(info))
    else {
        return Info::default();
    };
    Info {
        title: scope.get_text(dict, b"Title"),
        author: scope.get_text(dict, b"Author"),
        subject: scope.get_text(dict, b"Subject"),
        keywords: scope.get_text(dict, b"Keywords"),
        creator: scope.get_text(dict, b"Creator"),
        producer: scope.get_text(dict, b"Producer"),
        created: scope.get_date(dict, b"CreationDate"),
        modified: scope.get_date(dict, b"ModDate"),
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
pub(crate) mod tests {
    use super::*;
    use lopdf::{Document, dictionary};

    /// A document with `pages` page dictionaries under one /Pages node with `inherit`.
    pub(crate) fn doc_with(pages: Vec<Dictionary>, inherit: Dictionary) -> Document {
        let mut doc = Document::with_version("1.7");
        let pages_id = doc.new_object_id();
        let mut kids = Vec::new();
        for mut page in pages {
            page.set("Type", "Page");
            page.set("Parent", pages_id);
            kids.push(Object::Reference(doc.add_object(page)));
        }
        let mut node = dictionary! { "Type" => "Pages", "Count" => i64::try_from(kids.len()).unwrap(), "Kids" => kids };
        for (key, value) in inherit.iter() {
            node.set(key.clone(), value.clone());
        }
        doc.objects.insert(pages_id, Object::Dictionary(node));
        let catalog = doc.add_object(dictionary! { "Type" => "Catalog", "Pages" => pages_id });
        doc.trailer.set("Root", catalog);
        doc
    }

    fn rect_object(values: [f32; 4]) -> Object {
        Object::Array(values.iter().map(|value| Object::Real(*value)).collect())
    }

    #[test]
    fn page_sizes_follow_pdfium() {
        let doc = doc_with(
            vec![
                dictionary! {},
                dictionary! { "Rotate" => 90 },
                dictionary! { "CropBox" => rect_object([10.0, 10.0, 110.0, 60.0]) },
                dictionary! { "MediaBox" => rect_object([0.0, 0.0, 0.0, 0.0]), "Rotate" => -90 },
                dictionary! { "MediaBox" => rect_object([200.0, 300.0, 0.0, 0.0]), "Rotate" => 45 },
            ],
            dictionary! { "MediaBox" => rect_object([0.0, 0.0, 595.0, 842.0]) },
        );
        let structure = scan(&doc, &Limits::default());
        let sizes: Vec<(f32, f32)> = structure.pages.iter().map(|page| page.size).collect();
        assert_eq!(
            sizes,
            [
                (595.0, 842.0),
                (842.0, 595.0),
                (100.0, 50.0),
                (792.0, 612.0),
                (200.0, 300.0)
            ]
        );
        assert_eq!(structure.pages[3].rotation, 270);
        assert_eq!(structure.pages[4].rotation, 0);
        assert_eq!(structure.agrees_with(&sizes), Agreement::Agree);
        assert_eq!(
            structure.agrees_with(&sizes[..4]),
            Agreement::PageCount {
                model: 5,
                renderer: 4
            }
        );
        let mut other = sizes.clone();
        other[2].0 += 1.0;
        assert_eq!(
            structure.agrees_with(&other),
            Agreement::PageSize { page: 2 }
        );
    }

    #[test]
    fn page_labels_number_their_ranges() {
        let mut doc = doc_with(vec![dictionary! {}; 7], dictionary! {});
        let labels = dictionary! { "Nums" => vec![
            0.into(), Object::Dictionary(dictionary! { "S" => "r" }),
            3.into(), Object::Dictionary(dictionary! { "S" => "D", "St" => 1 }),
            5.into(), Object::Dictionary(dictionary! { "S" => "A", "P" => Object::string_literal("Ek-"), "St" => 26 }),
        ]};
        let labels = doc.add_object(labels);
        let catalog = doc.trailer.get(b"Root").unwrap().as_reference().unwrap();
        doc.get_dictionary_mut(catalog)
            .unwrap()
            .set("PageLabels", labels);
        let structure = scan(&doc, &Limits::default());
        let labels: Vec<String> = structure
            .pages
            .iter()
            .map(|page| page.label.clone().unwrap())
            .collect();
        assert_eq!(labels, ["i", "ii", "iii", "1", "2", "Ek-Z", "Ek-AA"]);
    }

    #[test]
    fn roman_numerals_and_letters() {
        assert_eq!(roman(1994), "mcmxciv");
        assert_eq!(roman(4), "iv");
        assert_eq!(letters(1), "a");
        assert_eq!(letters(27), "aa");
        assert_eq!(letters(53), "aaa");
    }

    #[test]
    fn dates_parse_leniently() {
        assert_eq!(
            PdfDate::parse("D:20261002094112+03'00'"),
            Some(PdfDate {
                year: 2026,
                month: 10,
                day: 2,
                hour: 9,
                minute: 41,
                second: 12,
                offset_minutes: Some(180),
            })
        );
        assert_eq!(PdfDate::parse("D:2026").map(|date| date.month), Some(1));
        assert_eq!(
            PdfDate::parse("20261006170000-05'30").and_then(|date| date.offset_minutes),
            Some(-330)
        );
        assert_eq!(
            PdfDate::parse("D:20261006Z").and_then(|date| date.offset_minutes),
            Some(0)
        );
        assert_eq!(PdfDate::parse("D:20261306"), None);
        assert_eq!(PdfDate::parse("yesterday"), None);
    }

    #[test]
    fn inheritance_stops_at_a_parent_loop() {
        let mut doc = doc_with(vec![dictionary! {}], dictionary! {});
        let pages = doc
            .catalog()
            .unwrap()
            .get(b"Pages")
            .unwrap()
            .as_reference()
            .unwrap();
        // The /Pages node names itself as its parent.
        doc.get_dictionary_mut(pages).unwrap().set("Parent", pages);
        let structure = scan(&doc, &Limits::default());
        assert_eq!(structure.pages[0].size, (612.0, 792.0));
    }
}
