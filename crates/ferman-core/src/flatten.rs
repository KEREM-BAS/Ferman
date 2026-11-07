//! Flattening (a4-5b, M4 plan W2, forms' Finish in W3): selected annotations of a page, of any
//! type, widgets too, become page content as their normal appearances, and leave `/Annots`.
//!
//! Every byte of the page's content stays: its streams are not rewritten, and new streams go around
//! them in `/Contents`, so a graphics state the page leaves behind does not reach the appearances.
//! An appearance is placed as a reader places it (ISO 32000-2 §12.5.5, algorithm 8): `/BBox` through
//! `/Matrix`, then that box onto `/Rect`.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeSet;
use std::fmt::Write as _;

use lopdf::{Dictionary, Object, ObjectId};

use crate::annotations::{MAX_PER_PAGE, direct_handle, handle_of};
use crate::content;
use crate::limits::Limits;
use crate::revision::{RevisionStore, compressed, decoded, free};
use crate::structure::{Scope, number};
use crate::write::Value;
use crate::{CoreError, Document};

/// `/F`: hidden and no view, which a reader does not draw on screen.
const NOT_DRAWN: i64 = 2 | 32;
/// `/F`: stays upright on a turned page.
const NO_ROTATE: i64 = 16;

/// One appearance to draw.
struct Draw {
    form: ObjectId,
    rect: [f32; 4],
    matrix: [f32; 6],
    /// `/OC` of the annotation, which the appearance on the page must keep obeying.
    layer: Option<Object>,
}

fn four(scope: &Scope<'_>, dict: &Dictionary, key: &[u8]) -> Option<[f32; 4]> {
    let items = dict
        .get(key)
        .ok()
        .and_then(|value| scope.resolve(value))?
        .as_array()
        .ok()?;
    let mut numbers = items.iter().filter_map(|item| {
        let item = scope.resolve(item)?;
        number(item)
    });
    let found = [
        numbers.next()?,
        numbers.next()?,
        numbers.next()?,
        numbers.next()?,
    ];
    let [x0, y0, x1, y1] = found;
    Some([x0.min(x1), y0.min(y1), x0.max(x1), y0.max(y1)])
}

/// The stream `/AP /N` draws: the entry itself, or the one `/AS` names (else `/Off`).
fn normal_appearance(scope: &Scope<'_>, annotation: &Dictionary) -> Option<ObjectId> {
    let appearance = scope.get_dict(annotation, b"AP")?;
    let normal = appearance.get(b"N").ok()?;
    let id = normal.as_reference().ok();
    let target = scope.resolve(normal)?;
    if matches!(target, Object::Stream(_)) {
        return id;
    }
    let states = target.as_dict().ok()?;
    let state = scope.get_name(annotation, b"AS").unwrap_or(b"Off");
    let state = if states.has(state) { state } else { b"Off" };
    states.get(state).ok()?.as_reference().ok()
}

/// How `form` lands on `rect`: `/BBox` through `/Matrix`, the box that gives scaled and moved onto
/// `rect`, as PDFium's `MatchRect` does it with a side under 0.001 kept at scale 1.
fn placement(scope: &Scope<'_>, form: ObjectId, rect: [f32; 4]) -> Option<[f32; 6]> {
    let Some(Object::Stream(stream)) = scope.object(form) else {
        return None;
    };
    let [l, b, r, t] = four(scope, &stream.dict, b"BBox")?;
    let [ma, mb, mc, md, me, mf] = stream
        .dict
        .get(b"Matrix")
        .ok()
        .and_then(|value| scope.resolve(value))
        .and_then(|value| value.as_array().ok())
        .and_then(|items| {
            let mut numbers = items.iter().filter_map(|item| number(scope.resolve(item)?));
            Some([
                numbers.next()?,
                numbers.next()?,
                numbers.next()?,
                numbers.next()?,
                numbers.next()?,
                numbers.next()?,
            ])
        })
        .unwrap_or([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
    #[allow(clippy::arithmetic_side_effects)] // Floats.
    let corners = [(l, b), (r, b), (l, t), (r, t)].map(|(x, y)| {
        let (x, y) = (f64::from(x), f64::from(y));
        (
            f64::from(ma) * x + f64::from(mc) * y + f64::from(me),
            f64::from(mb) * x + f64::from(md) * y + f64::from(mf),
        )
    });
    let least = |of: fn(&(f64, f64)) -> f64| corners.iter().map(of).fold(f64::INFINITY, f64::min);
    let most =
        |of: fn(&(f64, f64)) -> f64| corners.iter().map(of).fold(f64::NEG_INFINITY, f64::max);
    let (left, right) = (least(|c| c.0), most(|c| c.0));
    let (bottom, top) = (least(|c| c.1), most(|c| c.1));
    let [rl, rb, rr, rt] = rect.map(f64::from);
    #[allow(clippy::arithmetic_side_effects)] // Floats.
    let (a, d, e, f) = {
        let a = if (right - left).abs() < 0.001 {
            1.0
        } else {
            (rr - rl) / (right - left)
        };
        let d = if (top - bottom).abs() < 0.001 {
            1.0
        } else {
            (rt - rb) / (top - bottom)
        };
        (a, d, rl - left * a, rb - bottom * d)
    };
    #[allow(clippy::cast_possible_truncation)] // Page coordinates.
    Some([a as f32, 0.0, 0.0, d as f32, e as f32, f as f32])
}

/// `matrix` turned against the page's `rotation` around `rect`'s top left, as a reader draws an
/// annotation with the NoRotate flag.
fn upright(matrix: [f32; 6], rect: [f32; 4], rotation: u16) -> [f32; 6] {
    let (cos, sin) = match rotation % 360 {
        90 => (0.0, 1.0),
        180 => (-1.0, 0.0),
        270 => (0.0, -1.0),
        _ => return matrix,
    };
    let [left, _, _, top] = rect;
    let [a, b, c, d, e, f] = matrix;
    let (x, y) = (e - left, f - top);
    #[allow(clippy::arithmetic_side_effects)] // Floats.
    [
        a * cos - b * sin,
        a * sin + b * cos,
        c * cos - d * sin,
        c * sin + d * cos,
        x * cos - y * sin + left,
        x * sin + y * cos + top,
    ]
}

/// `q` and `Q` for the page's content, so that it starts and ends each stream's state at the same
/// level whatever it leaves open or closes too often: how many `q` before it, and `Q` after.
fn balance(data: &[u8], limits: &Limits) -> Result<(usize, usize), CoreError> {
    let mut depth = 0isize;
    let mut least = 0isize;
    for operator in content::operators(data, limits)? {
        match operator.name.as_slice() {
            b"q" => depth = depth.saturating_add(1),
            b"Q" => {
                depth = depth.saturating_sub(1);
                least = least.min(depth);
            }
            _ => {}
        }
    }
    let open = least.unsigned_abs().saturating_add(1);
    let close = depth.saturating_sub(least).unsigned_abs().saturating_add(1);
    Ok((open, close))
}

fn numbers(out: &mut String, values: &[f32]) {
    for value in values {
        let value = if value.is_finite() { *value } else { 0.0 };
        let _ = write!(out, "{value} ");
    }
}

impl RevisionStore {
    /// Draws annotations `handles` of page `index` into its content, in `/Annots` order, and takes
    /// them and their popups out of `/Annots`, in the open transaction. One that has no normal
    /// appearance, is hidden or has no view draws nothing. A handle the page does not name is
    /// skipped. The page gets its own `/Resources`; other pages and every content stream stay.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::NoSuchPage`], [`WriteError::ObjectNumbers`],
    /// and those of reading the page's content within the document's limits.
    pub fn flatten_annotations(
        &mut self,
        doc: &Document,
        index: usize,
        handles: &[u64],
    ) -> Result<(), CoreError> {
        self.transaction_open()?;
        let page = self.page_id(doc, index)?;
        let rotation = self.pages(doc).get(index).map_or(0, |page| page.rotation);
        let selected: BTreeSet<u64> = handles.iter().copied().collect();
        let mut draws = Vec::new();
        let mut gone = BTreeSet::new();
        let mut gone_direct = BTreeSet::new();
        {
            let scope = self.scope(doc);
            let items = scope
                .dictionary(page)
                .and_then(|dict| scope.get_array(dict, b"Annots"));
            let mut direct = 0usize;
            for item in items.into_iter().flatten().take(MAX_PER_PAGE) {
                let id = item.as_reference().ok();
                let handle = id.map_or_else(
                    || {
                        let handle = direct_handle(page, direct);
                        direct = direct.saturating_add(1);
                        handle
                    },
                    handle_of,
                );
                if !selected.contains(&handle) {
                    continue;
                }
                match id {
                    Some(id) => {
                        gone.insert(id);
                    }
                    None => {
                        gone_direct.insert(handle);
                    }
                }
                let Some(annotation) = scope.dict(item) else {
                    continue;
                };
                if let Some(popup) = annotation
                    .get(b"Popup")
                    .ok()
                    .and_then(|popup| popup.as_reference().ok())
                {
                    gone.insert(popup);
                }
                let flags = scope.get_int(annotation, b"F").unwrap_or(0);
                if flags & NOT_DRAWN != 0 {
                    continue;
                }
                let Some(form) = normal_appearance(&scope, annotation) else {
                    continue;
                };
                let Some(rect) = four(&scope, annotation, b"Rect") else {
                    continue;
                };
                let Some(mut matrix) = placement(&scope, form, rect) else {
                    continue;
                };
                if flags & NO_ROTATE != 0 {
                    matrix = upright(matrix, rect, rotation);
                }
                draws.push(Draw {
                    form,
                    rect,
                    matrix,
                    layer: annotation.get(b"OC").ok().cloned(),
                });
            }
        }
        if gone.is_empty() && gone_direct.is_empty() {
            return Ok(());
        }
        let mut direct = 0usize;
        self.change_annots(doc, index, |items| {
            items.retain(|item| match item.as_reference() {
                Ok(id) => !gone.contains(&id),
                Err(_) => {
                    let handle = direct_handle(page, direct);
                    direct = direct.saturating_add(1);
                    !gone_direct.contains(&handle)
                }
            });
            true
        })?;
        if draws.is_empty() {
            return Ok(());
        }
        self.draw_on_page(doc, page, &draws)
    }

    /// Puts `draws` after page `page`'s content.
    fn draw_on_page(
        &mut self,
        doc: &Document,
        page: ObjectId,
        draws: &[Draw],
    ) -> Result<(), CoreError> {
        let streams = self.contents(doc, page);
        let mut joined = Vec::new();
        for id in &streams {
            if let Some(Object::Stream(stream)) = self.scope(doc).object(*id) {
                joined.extend(decoded(stream, doc)?);
                joined.push(b'\n');
            }
        }
        let (open, close) = balance(&joined, doc.limits())?;
        let (mut resources, mut xobjects) = self.page_resources(doc, page, b"XObject");
        let mut drawn = String::new();
        let mut next = 0u32;
        let mut free_name = || -> Vec<u8> {
            loop {
                let name = format!("FmFlat{next}").into_bytes();
                next = next.saturating_add(1);
                if !xobjects.has(&name) {
                    break name;
                }
            }
        };
        let mut names = Vec::with_capacity(draws.len());
        for draw in draws {
            let name = free_name();
            let target = match &draw.layer {
                Some(layer) => self.layer_form(doc, draw, layer.clone())?,
                None => draw.form,
            };
            drawn.push_str("q ");
            if draw.layer.is_none() {
                numbers(&mut drawn, &draw.matrix);
                drawn.push_str("cm ");
            }
            let _ = writeln!(drawn, "/{} Do Q", String::from_utf8_lossy(&name));
            names.push((name, target));
        }
        for (name, target) in names {
            xobjects.set(name, Object::Reference(target));
        }
        resources.set("XObject", xobjects);
        let plain = |data: Vec<u8>| Value::Stream {
            dict: Vec::new(),
            data,
        };
        let mut items = Vec::with_capacity(streams.len().saturating_add(3));
        if !streams.is_empty() {
            let before = self.add_object(doc, plain("q ".repeat(open).into_bytes()))?;
            items.push(Object::Reference(before.0));
            items.extend(streams.into_iter().map(Object::Reference));
            let after = self.add_object(
                doc,
                plain(format!("\n{}\n", "Q ".repeat(close)).into_bytes()),
            )?;
            items.push(Object::Reference(after.0));
        }
        let flat = self.add_object(doc, plain(drawn.into_bytes()))?;
        items.push(Object::Reference(flat.0));
        let mut dict = self.dictionary(doc, page)?;
        dict.set("Contents", items);
        dict.set("Resources", resources);
        self.put(page, Object::Dictionary(dict))
    }

    /// A form that draws `draw` placed on its `/Rect`, under its annotation's `/OC`.
    fn layer_form(
        &mut self,
        doc: &Document,
        draw: &Draw,
        layer: Object,
    ) -> Result<ObjectId, CoreError> {
        let mut data = String::new();
        numbers(&mut data, &draw.matrix);
        data.push_str("cm /Fm0 Do");
        let mut xobjects = Dictionary::new();
        xobjects.set("Fm0", Object::Reference(draw.form));
        let mut resources = Dictionary::new();
        resources.set("XObject", xobjects);
        let mut dict = Dictionary::new();
        dict.set("Type", Object::Name(b"XObject".to_vec()));
        dict.set("Subtype", Object::Name(b"Form".to_vec()));
        dict.set(
            "BBox",
            draw.rect
                .iter()
                .copied()
                .map(Object::Real)
                .collect::<Vec<_>>(),
        );
        dict.set("Resources", resources);
        dict.set("OC", layer);
        let id = (free(self.next_number())?, 0);
        self.put_counted(
            doc,
            vec![(id, Object::Stream(compressed(dict, data.as_bytes())?))],
        )?;
        Ok(id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn balance_counts_what_a_page_leaves_open_and_closes_too_often() {
        let limits = Limits::default();
        assert_eq!(balance(b"q 1 w Q", &limits).unwrap(), (1, 1));
        assert_eq!(balance(b"q q", &limits).unwrap(), (1, 3));
        assert_eq!(balance(b"Q Q q", &limits).unwrap(), (3, 2));
    }
}
