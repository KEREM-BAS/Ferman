//! Page operations: what each one writes, inside the open transaction of a document's
//! [`RevisionStore`]. Pages are named by their index as the store leaves them; each function
//! takes them in any order, once each, and treats them in document order.

use std::collections::BTreeSet;

use ferman_core::pages::PageSlot;
use ferman_core::revision::RevisionStore;
use ferman_core::structure::{LabelRange, Page, Rect};
use ferman_core::write::Value;
use ferman_core::{CoreError, Document, WriteError};

use crate::OpsError;

/// The largest page side PDF readers take, in points (ISO 32000-2 Annex C).
const LARGEST_SIDE: f32 = 14_400.0;

/// The smallest page side a crop or a new size may leave, in points.
const SMALLEST_SIDE: f32 = 1.0;

/// The most blank pages one operation inserts.
const MOST_BLANK_PAGES: u32 = 10_000;

/// A pixel with every channel at this or above counts as white: scans are rarely pure white.
const WHITE: u8 = 250;

/// What each side of a page gives up, in displayed points: after `/Rotate`, whatever the page's
/// own coordinates.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct Margins {
    /// The top side.
    pub top: f32,
    /// The bottom side.
    pub bottom: f32,
    /// The left side.
    pub left: f32,
    /// The right side.
    pub right: f32,
}

/// What a new page size does to the content (a6-4).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PageFit {
    /// Stays at its size, in the middle of the new page.
    Centre,
    /// Scaled, keeping its proportions, to fit the new page, and centred on it.
    Scale,
}

fn plan_error() -> OpsError {
    CoreError::Write(WriteError::PagePlan).into()
}

fn no_such_page() -> OpsError {
    CoreError::Write(WriteError::NoSuchPage).into()
}

/// A new page's side that a reader can show.
pub(crate) fn checked_side(side: f32) -> Result<f32, OpsError> {
    if side.is_finite() && (SMALLEST_SIDE..=LARGEST_SIDE).contains(&side) {
        Ok(side)
    } else {
        Err(plan_error())
    }
}

/// `rect` as a `/…Box` value.
fn box_value(rect: &Rect) -> Value {
    Value::Array(
        [rect.left, rect.bottom, rect.right, rect.top]
            .into_iter()
            .map(Value::Real)
            .collect(),
    )
}

/// The document's page indices.
fn all(document: &Document, revisions: &RevisionStore) -> Vec<usize> {
    (0..revisions.pages(document).len()).collect()
}

fn slots(indices: impl IntoIterator<Item = usize>) -> Vec<PageSlot> {
    indices.into_iter().map(PageSlot::Page).collect()
}

/// Turns `pages` clockwise by `quarter_turns` quarter turns, counter-clockwise when negative,
/// through `/Rotate` in each one's own dictionary; a page that ends where it was changes nothing.
///
/// # Errors
///
/// [`WriteError::NoSuchPage`] and [`WriteError::NoTransaction`], as [`OpsError::Core`].
pub fn rotate(
    document: &Document,
    revisions: &mut RevisionStore,
    pages: &[usize],
    quarter_turns: i32,
) -> Result<(), OpsError> {
    let pages: Vec<usize> = pages
        .iter()
        .copied()
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect();
    let refs = revisions.page_refs(document, &pages)?;
    let rotations: Vec<u16> = pages
        .iter()
        .filter_map(|index| revisions.pages(document).get(*index))
        .map(|page| page.rotation)
        .collect();
    for (page, rotation) in refs.into_iter().zip(rotations) {
        let before = i64::from(rotation);
        let after = (before + i64::from(quarter_turns) * 90).rem_euclid(360);
        if after != before {
            revisions.set_entry(document, page, b"Rotate", Value::Integer(after))?;
        }
    }
    Ok(())
}

/// Deletes `pages`. Their objects stay in the file until a full rewrite (question 5 of the M4
/// plan); what referred to them no longer does.
///
/// # Errors
///
/// [`WriteError::PagePlan`] when no page would be left, and those of
/// [`RevisionStore::arrange_pages`].
pub fn delete(
    document: &Document,
    revisions: &mut RevisionStore,
    pages: &[usize],
) -> Result<(), OpsError> {
    let gone: BTreeSet<usize> = pages.iter().copied().collect();
    let order = slots(
        all(document, revisions)
            .into_iter()
            .filter(|index| !gone.contains(index)),
    );
    Ok(revisions.arrange_pages(document, &order)?)
}

/// Moves `pages`, together and in their order, before page `before`, or to the end when `None`.
/// When `before` is one of them, before the first page after it that is not.
///
/// # Errors
///
/// [`WriteError::NoSuchPage`] for a page the document does not have, and those of
/// [`RevisionStore::arrange_pages`].
pub fn move_before(
    document: &Document,
    revisions: &mut RevisionStore,
    pages: &[usize],
    before: Option<usize>,
) -> Result<(), OpsError> {
    let moving: BTreeSet<usize> = pages.iter().copied().collect();
    let every = all(document, revisions);
    if moving.iter().any(|index| *index >= every.len()) {
        return Err(no_such_page());
    }
    if before.is_some_and(|index| index >= every.len()) {
        return Err(no_such_page());
    }
    let rest: Vec<usize> = every
        .iter()
        .copied()
        .filter(|index| !moving.contains(index))
        .collect();
    let at = before
        .and_then(|before| rest.iter().position(|index| *index >= before))
        .unwrap_or(rest.len());
    let (head, tail) = rest.split_at(at);
    let order = slots(head.iter().chain(moving.iter()).chain(tail.iter()).copied());
    Ok(revisions.arrange_pages(document, &order)?)
}

/// Copies `pages`: the copies of pages next to each other follow the last of them, in their order.
///
/// # Errors
///
/// [`WriteError::NoSuchPage`] for a page the document does not have, and those of
/// [`RevisionStore::arrange_pages`] and [`RevisionStore::copy_page`].
pub fn duplicate(
    document: &Document,
    revisions: &mut RevisionStore,
    pages: &[usize],
) -> Result<(), OpsError> {
    let copied: BTreeSet<usize> = pages.iter().copied().collect();
    let every = all(document, revisions);
    if copied.iter().any(|index| *index >= every.len()) {
        return Err(no_such_page());
    }
    let mut order = Vec::with_capacity(every.len().saturating_add(copied.len()));
    let refs = revisions.page_refs(document, &every)?;
    let mut run = Vec::new();
    for (index, page) in every.into_iter().zip(refs) {
        order.push(PageSlot::Page(index));
        if copied.contains(&index) {
            run.push(revisions.copy_page(document, page)?);
        }
        if !copied.contains(&index.saturating_add(1)) {
            order.extend(run.drain(..).map(PageSlot::New));
        }
    }
    Ok(revisions.arrange_pages(document, &order)?)
}

/// Inserts `count` blank pages of `width` by `height` points after page `after`, or first when
/// `None`.
///
/// # Errors
///
/// [`WriteError::PagePlan`] for no pages or a size a reader cannot show,
/// [`WriteError::NoSuchPage`] for a page the document does not have, and those of
/// [`RevisionStore::arrange_pages`].
pub fn insert_blank(
    document: &Document,
    revisions: &mut RevisionStore,
    after: Option<usize>,
    count: u32,
    (width, height): (f32, f32),
) -> Result<(), OpsError> {
    let (width, height) = (checked_side(width)?, checked_side(height)?);
    let every = all(document, revisions);
    if count == 0 || count > MOST_BLANK_PAGES {
        return Err(plan_error());
    }
    let at = match after {
        Some(after) if after >= every.len() => return Err(no_such_page()),
        Some(after) => after.saturating_add(1),
        None => 0,
    };
    let (head, tail) = every.split_at(at);
    let mut order = slots(head.iter().copied());
    for _ in 0..count {
        order.push(PageSlot::New(
            revisions.blank_page(document, width, height)?,
        ));
    }
    order.extend(tail.iter().copied().map(PageSlot::Page));
    Ok(revisions.arrange_pages(document, &order)?)
}

/// Gives `pages` the displayed size `width` by `height` points; a page that has it already changes
/// nothing. [`PageFit::Centre`] writes the boxes alone. [`PageFit::Scale`] draws the content
/// through a new matrix, and maps the annotations.
///
/// # Errors
///
/// [`WriteError::PagePlan`] for a size a reader cannot show, [`WriteError::NoSuchPage`], and those
/// of [`RevisionStore::scale_page`].
pub fn set_size(
    document: &Document,
    revisions: &mut RevisionStore,
    pages: &[usize],
    (width, height): (f32, f32),
    fit: PageFit,
) -> Result<(), OpsError> {
    let (width, height) = (checked_side(width)?, checked_side(height)?);
    let refs = revisions.page_refs(document, pages)?;
    let before: Vec<Page> = pages
        .iter()
        .filter_map(|index| revisions.pages(document).get(*index).cloned())
        .collect();
    for (reference, page) in refs.into_iter().zip(before) {
        if (page.size.0 - width).abs() < 0.01 && (page.size.1 - height).abs() < 0.01 {
            continue;
        }
        // The boxes are in the page's own coordinates, which `/Rotate` turns.
        let (user_width, user_height) = if page.rotation % 180 == 0 {
            (width, height)
        } else {
            (height, width)
        };
        let crop = page.crop_box;
        let media = match fit {
            PageFit::Centre => {
                let (x, y) = (
                    (crop.left + crop.right) / 2.0,
                    (crop.bottom + crop.top) / 2.0,
                );
                Rect {
                    left: x - user_width / 2.0,
                    bottom: y - user_height / 2.0,
                    right: x + user_width / 2.0,
                    top: y + user_height / 2.0,
                }
            }
            PageFit::Scale => {
                let scale = (user_width / crop.width()).min(user_height / crop.height());
                let dx = (user_width - crop.width() * scale) / 2.0 - crop.left * scale;
                let dy = (user_height - crop.height() * scale) / 2.0 - crop.bottom * scale;
                revisions.scale_page(document, reference, scale, dx, dy)?;
                Rect {
                    left: 0.0,
                    bottom: 0.0,
                    right: user_width,
                    top: user_height,
                }
            }
        };
        revisions.set_entry(document, reference, b"MediaBox", box_value(&media))?;
        revisions.set_entry(document, reference, b"CropBox", box_value(&media))?;
    }
    Ok(())
}

/// Takes each page's margins off its crop box, or gives them back up to the media box when
/// negative: what is outside stays in the file, hidden (G57), and undo is the way back. Margins of
/// nothing change nothing.
///
/// # Errors
///
/// [`WriteError::PagePlan`] when less than a point would be left of a page, and
/// [`WriteError::NoSuchPage`].
pub fn crop(
    document: &Document,
    revisions: &mut RevisionStore,
    crops: &[(usize, Margins)],
) -> Result<(), OpsError> {
    let indices: Vec<usize> = crops.iter().map(|(index, _)| *index).collect();
    let refs = revisions.page_refs(document, &indices)?;
    let boxes: Vec<(Rect, Rect)> = crops
        .iter()
        .filter_map(|(index, margins)| {
            let page = revisions.pages(document).get(*index)?;
            Some((cropped_box(page, *margins), page.crop_box))
        })
        .collect();
    for (page, (cropped, before)) in refs.into_iter().zip(boxes) {
        if cropped == before {
            continue;
        }
        if !cropped.width().is_finite()
            || !cropped.height().is_finite()
            || cropped.width() < SMALLEST_SIDE
            || cropped.height() < SMALLEST_SIDE
        {
            return Err(plan_error());
        }
        revisions.set_entry(document, page, b"CropBox", box_value(&cropped))?;
    }
    Ok(())
}

/// The crop box `margins` leave of `page`.
fn cropped_box(page: &Page, margins: Margins) -> Rect {
    let Margins {
        top,
        bottom,
        left,
        right,
    } = margins;
    // `/Rotate` turns the page clockwise: at 90 its left side shows on top.
    let (left, bottom, right, top) = match page.rotation {
        90 => (top, left, bottom, right),
        180 => (right, top, left, bottom),
        270 => (bottom, right, top, left),
        _ => (left, bottom, right, top),
    };
    let crop = page.crop_box;
    Rect {
        left: crop.left + left,
        bottom: crop.bottom + bottom,
        right: crop.right - right,
        top: crop.top - top,
    }
    .intersect(&page.media_box)
}

/// Makes `ranges` the document's page labels (a6-5).
///
/// # Errors
///
/// Those of [`RevisionStore::set_label_ranges`].
pub fn set_labels(
    document: &Document,
    revisions: &mut RevisionStore,
    ranges: &[LabelRange],
) -> Result<(), OpsError> {
    Ok(revisions.set_label_ranges(document, ranges)?)
}

/// The white around a page's content in a raster of it, in displayed points, rounded towards the
/// content so that no mark is cut; `None` for a page with no content. `pixels` is 8-bit BGRA,
/// `width × 4` bytes per row from the top row, at `scale` pixels per point.
#[must_use]
pub fn white_margins(pixels: &[u8], width: u32, scale: f64) -> Option<Margins> {
    let columns = usize::try_from(width).ok().filter(|width| *width > 0)?;
    let inked = |pixel: &[u8; 4]| pixel.iter().take(3).any(|channel| *channel < WHITE);
    let (mut left, mut right) = (columns, 0);
    let (mut top, mut bottom) = (None, 0);
    let rows = pixels.chunks_exact(columns.checked_mul(4)?);
    let count = rows.len();
    for (y, row) in rows.enumerate() {
        let row = row.as_chunks::<4>().0;
        let Some(first) = row.iter().position(inked) else {
            continue;
        };
        top = top.or(Some(y));
        bottom = y;
        left = left.min(first);
        right = right.max(row.iter().rposition(inked).unwrap_or(first));
    }
    let top = top?;
    let points = |pixels: usize| (u32::try_from(pixels).map_or(0.0, f64::from) / scale) as f32;
    Some(Margins {
        top: points(top),
        bottom: points(count.saturating_sub(bottom).saturating_sub(1)),
        left: points(left),
        right: points(columns.saturating_sub(right).saturating_sub(1)),
    })
}

#[cfg(test)]
#[allow(clippy::indexing_slicing)]
mod tests {
    use std::path::PathBuf;

    use ferman_core::{OpenOptions, Source, open};

    use super::*;

    fn kira() -> Document {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated/kira-tr.pdf");
        open(&Source::read(&path).unwrap(), &OpenOptions::default()).unwrap()
    }

    #[test]
    fn a_turn_goes_through_rotate_and_comes_back_with_undo() {
        let doc = kira();
        let mut store = RevisionStore::new(&doc);
        let (width, height) = store.pages(&doc)[1].size;
        store.begin().unwrap();
        rotate(&doc, &mut store, &[1, 1], 1).unwrap();
        store.commit().unwrap();
        assert_eq!(store.pages(&doc)[1].rotation, 90);
        assert_eq!(store.pages(&doc)[1].size, (height, width));
        assert_eq!(store.pages(&doc)[0].rotation, 0);
        store.begin().unwrap();
        rotate(&doc, &mut store, &[1], -3).unwrap();
        assert_eq!(store.pages(&doc)[1].rotation, 180);
        store.commit().unwrap();
        store.undo().unwrap();
        store.undo().unwrap();
        assert_eq!(store.pages(&doc)[1].rotation, 0);
        assert_eq!(store.pages(&doc)[1].size, (width, height));

        // The saved update carries it.
        store.redo().unwrap();
        let saved = store.incremental_update(&doc).unwrap();
        let again = open(&Source::from_bytes(saved.into()), &OpenOptions::default()).unwrap();
        assert_eq!(again.structure().pages[1].rotation, 90);
    }

    fn in_a_transaction(
        doc: &Document,
        change: impl FnOnce(&mut RevisionStore) -> Result<(), OpsError>,
    ) -> RevisionStore {
        let mut store = RevisionStore::new(doc);
        store.begin().unwrap();
        change(&mut store).unwrap();
        store.commit().unwrap();
        store
    }

    fn order(store: &RevisionStore, doc: &Document) -> Vec<u64> {
        store.pages(doc).iter().map(Page::handle).collect()
    }

    #[test]
    fn delete_move_duplicate_and_blank_give_the_order_they_say() {
        let doc = kira();
        let first = RevisionStore::new(&doc);
        let handles = order(&first, &doc);
        let [a, b, c] = handles[..] else {
            panic!("kira-tr has three pages");
        };

        let store = in_a_transaction(&doc, |store| delete(&doc, store, &[1]));
        assert_eq!(order(&store, &doc), [a, c]);

        let store = in_a_transaction(&doc, |store| move_before(&doc, store, &[2], Some(0)));
        assert_eq!(order(&store, &doc), [c, a, b]);
        let store = in_a_transaction(&doc, |store| move_before(&doc, store, &[0], None));
        assert_eq!(order(&store, &doc), [b, c, a]);
        // Onto one of the pages moved: the next page that stays.
        let store = in_a_transaction(&doc, |store| move_before(&doc, store, &[2, 0], Some(0)));
        assert_eq!(order(&store, &doc), [a, c, b]);

        let store = in_a_transaction(&doc, |store| duplicate(&doc, store, &[0, 1]));
        let copied = order(&store, &doc);
        assert_eq!(copied.len(), 5);
        assert_eq!((copied[0], copied[1], copied[4]), (a, b, c));
        assert!(!handles.contains(&copied[2]) && !handles.contains(&copied[3]));

        let store = in_a_transaction(&doc, |store| {
            insert_blank(&doc, store, Some(0), 2, (100.0, 200.0))
        });
        let pages = store.pages(&doc);
        assert_eq!(pages.len(), 5);
        assert_eq!(pages[1].size, (100.0, 200.0));
        assert_eq!(pages[3].handle(), b);
        let store = in_a_transaction(&doc, |store| {
            insert_blank(&doc, store, None, 1, (100.0, 200.0))
        });
        assert_eq!(store.pages(&doc)[1].handle(), a);
    }

    #[test]
    fn what_cannot_apply_is_refused() {
        let doc = kira();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        for result in [
            delete(&doc, &mut store, &[0, 1, 2]),
            insert_blank(&doc, &mut store, None, 0, (100.0, 100.0)),
            insert_blank(&doc, &mut store, None, 1, (0.0, 100.0)),
            insert_blank(&doc, &mut store, None, 1, (f32::NAN, 100.0)),
            set_size(&doc, &mut store, &[0], (20_000.0, 100.0), PageFit::Centre),
            crop(
                &doc,
                &mut store,
                &[(
                    0,
                    Margins {
                        top: 5000.0,
                        ..Margins::default()
                    },
                )],
            ),
        ] {
            assert!(matches!(
                result,
                Err(OpsError::Core(CoreError::Write(WriteError::PagePlan)))
            ));
        }
        for result in [
            move_before(&doc, &mut store, &[9], None),
            move_before(&doc, &mut store, &[0], Some(9)),
            duplicate(&doc, &mut store, &[9]),
            insert_blank(&doc, &mut store, Some(9), 1, (100.0, 100.0)),
        ] {
            assert!(matches!(
                result,
                Err(OpsError::Core(CoreError::Write(WriteError::NoSuchPage)))
            ));
        }
    }

    #[test]
    fn a_crop_takes_each_displayed_side_whatever_the_rotation() {
        let doc = kira();
        let margins = Margins {
            top: 1.0,
            bottom: 2.0,
            left: 3.0,
            right: 4.0,
        };
        for turns in 0..4 {
            let store = in_a_transaction(&doc, |store| {
                rotate(&doc, store, &[0], turns)?;
                crop(&doc, store, &[(0, margins)])
            });
            let page = &store.pages(&doc)[0];
            let (width, height) = page.size;
            // Where the media box's corner shows says what each displayed side lost.
            let seen = page.display_point(page.media_box.left, page.media_box.bottom);
            let want = match turns {
                0 => (-3.0, height + 2.0),
                1 => (-3.0, -1.0),
                2 => (width + 4.0, -1.0),
                _ => (width + 4.0, height + 2.0),
            };
            assert!(
                (seen.0 - want.0).abs() < 0.01 && (seen.1 - want.1).abs() < 0.01,
                "{turns}: {seen:?} {want:?}"
            );
        }
    }

    #[test]
    fn a_negative_margin_gives_back_up_to_the_media_box() {
        let doc = kira();
        let inset = Margins {
            top: 10.0,
            ..Margins::default()
        };
        let store = in_a_transaction(&doc, |store| {
            crop(&doc, store, &[(0, inset)])?;
            let back = Margins {
                top: -100.0,
                ..Margins::default()
            };
            crop(&doc, store, &[(0, back)])
        });
        let page = &store.pages(&doc)[0];
        assert_eq!(page.crop_box, page.media_box);
    }

    #[test]
    fn a_new_size_centres_or_scales_on_a_turned_page_too() {
        let doc = kira();
        let store = in_a_transaction(&doc, |store| {
            set_size(&doc, store, &[0], (400.0, 400.0), PageFit::Centre)
        });
        let centred = &store.pages(&doc)[0];
        let before = &doc.structure().pages[0];
        assert_eq!(centred.size, (400.0, 400.0));
        assert!(
            (centred.crop_box.left + centred.crop_box.right
                - before.crop_box.left
                - before.crop_box.right)
                .abs()
                < 0.01
        );

        let store = in_a_transaction(&doc, |store| {
            rotate(&doc, store, &[0], 1)?;
            set_size(&doc, store, &[0], (400.0, 300.0), PageFit::Scale)
        });
        let scaled = &store.pages(&doc)[0];
        assert_eq!(scaled.size, (400.0, 300.0));
        assert_eq!(scaled.media_box.width(), 300.0);

        // Asked for the size it has, nothing is written.
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        set_size(&doc, &mut store, &[0], before.size, PageFit::Scale).unwrap();
        assert_eq!(store.commit().unwrap(), 0);
    }

    #[test]
    fn white_margins_find_the_marks_and_round_towards_them() {
        let white = [255_u8; 4];
        let mut pixels = vec![white; 10 * 8];
        assert_eq!(white_margins(pixels.as_flattened(), 10, 2.0), None);
        // A faint scan's paper is white; a mark is not.
        pixels[2 * 10 + 1] = [251, 252, 250, 255];
        assert_eq!(white_margins(pixels.as_flattened(), 10, 2.0), None);
        pixels[2 * 10 + 3] = [0, 0, 0, 255];
        pixels[5 * 10 + 6] = [255, 249, 255, 255];
        assert_eq!(
            white_margins(pixels.as_flattened(), 10, 2.0),
            Some(Margins {
                top: 1.0,
                bottom: 1.0,
                left: 1.5,
                right: 1.5,
            })
        );
        assert_eq!(white_margins(&[], 0, 1.0), None);
    }

    #[test]
    fn four_turns_write_nothing_and_a_missing_page_is_refused() {
        let doc = kira();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        rotate(&doc, &mut store, &[0], 4).unwrap();
        assert_eq!(store.commit().unwrap(), 0);
        store.begin().unwrap();
        assert!(matches!(
            rotate(&doc, &mut store, &[9], 1),
            Err(OpsError::Core(CoreError::Write(WriteError::NoSuchPage)))
        ));
    }
}
