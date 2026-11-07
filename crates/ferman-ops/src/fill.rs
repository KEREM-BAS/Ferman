//! Fill anything (a5-4, M4 plan, W3): the lines, boxes, check boxes and combs drawn on a page
//! without form fields, found in its content so a click can put text or a mark on them. What is
//! placed there is W2's text box and marks: this module only finds where.
//!
//! The walk is the interpreter's, under the document's limits; what it keeps is capped too, so a
//! hostile page gives a short list that says so, never an unbounded one.

use ferman_core::CoreError;
use ferman_core::Document;
use ferman_core::interpret::{Matrix, OperatorEvent, TextShow, TextSink};
use ferman_core::revision::RevisionStore;

use crate::OpsError;

/// The most shapes kept from one page.
const MAX_SHAPES: usize = 100_000;
/// The most pieces of one path; a longer one is no line or box.
const MAX_PATH: usize = 4096;
/// The most saved line widths (`q`), past which a `q` keeps the width it has.
const MAX_SAVED: usize = 256;
/// The most targets returned.
pub const MAX_TARGETS: usize = 2_000;
/// The shortest line written on, in points.
const SHORTEST_LINE: f32 = 24.0;
/// The thickest stroke or bar that is still a line, in points.
const THICKEST_LINE: f32 = 2.5;
/// A check box's sides, in points.
const CHECK_SIDES: std::ops::RangeInclusive<f32> = 5.0..=24.0;
/// A box written in: its least height and width, and its greatest height, in points.
const BOX_HEIGHTS: std::ops::RangeInclusive<f32> = 8.0..=200.0;
const NARROWEST_BOX: f32 = 20.0;
/// How far two sizes or edges may differ and still be the same, in points.
const SAME: f32 = 0.75;
/// The fewest cells of a comb.
const FEWEST_CELLS: usize = 3;

/// What a target is.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TargetKind {
    /// A line to write on: text goes on its baseline.
    Line,
    /// A box to write in.
    Box,
    /// A small square: a click checks it.
    Check,
    /// A row of equal cells, one character each.
    Comb,
}

/// One place to fill, in user space.
#[derive(Debug, Clone, PartialEq)]
pub struct Target {
    /// What it is.
    pub kind: TargetKind,
    /// Its box: a line's is its stroke, a comb's all its cells.
    pub rect: [f32; 4],
    /// A comb's cells; 1 for the others.
    pub cells: u32,
}

/// The targets of a page.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct Targets {
    /// From the top of the page down, then left to right.
    pub targets: Vec<Target>,
    /// Whether a limit cut the walk or the list short.
    pub truncated: bool,
}

/// A path piece in user space.
#[derive(Clone, Copy)]
enum Piece {
    Move([f32; 2]),
    Line([f32; 2]),
    Rect([f32; 4]),
}

/// A painted shape kept for classing.
#[derive(Clone, Copy)]
enum Shape {
    /// A stroked rectangle.
    Frame([f32; 4]),
    /// A line: a stroked horizontal segment or a thin filled bar, as its box.
    Rule([f32; 4]),
}

#[derive(Default)]
struct Finder {
    path: Vec<Piece>,
    /// A curve or a rectangle the matrix turns at an angle: the path is no line or box.
    spoiled: bool,
    width: f32,
    saved: Vec<f32>,
    shapes: Vec<Shape>,
    truncated: bool,
}

fn apply(m: Matrix, x: f32, y: f32) -> [f32; 2] {
    [m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]]
}

impl Finder {
    fn keep(&mut self, shape: Shape) {
        if self.shapes.len() < MAX_SHAPES {
            self.shapes.push(shape);
        } else {
            self.truncated = true;
        }
    }

    fn piece(&mut self, piece: Piece) {
        if self.path.len() < MAX_PATH {
            self.path.push(piece);
        } else {
            self.spoiled = true;
        }
    }

    fn paint(&mut self, stroke: bool, fill: bool, ctm: Matrix) {
        let path = std::mem::take(&mut self.path);
        let spoiled = std::mem::take(&mut self.spoiled);
        if spoiled || !(stroke || fill) {
            return;
        }
        let scale = (ctm[0] * ctm[3] - ctm[1] * ctm[2]).abs().sqrt();
        let width = self.width.max(0.0) * scale;
        let mut from: Option<[f32; 2]> = None;
        for piece in path {
            match piece {
                Piece::Rect([l, b, r, t]) => {
                    let (w, h) = (r - l, t - b);
                    if fill && !stroke && h <= THICKEST_LINE && w >= SHORTEST_LINE {
                        self.keep(Shape::Rule([l, b, r, t]));
                    } else if stroke && h <= THICKEST_LINE && w >= SHORTEST_LINE {
                        let half = width / 2.0;
                        self.keep(Shape::Rule([l - half, b - half, r + half, t + half]));
                    } else if stroke {
                        self.keep(Shape::Frame([l, b, r, t]));
                    }
                    from = None;
                }
                Piece::Move(at) => from = Some(at),
                Piece::Line(to) => {
                    if stroke
                        && width <= THICKEST_LINE
                        && let Some([x0, y0]) = from
                        && (to[1] - y0).abs() < 0.5
                        && (to[0] - x0).abs() >= SHORTEST_LINE
                    {
                        let half = width.max(0.5) / 2.0;
                        let y = f32::midpoint(y0, to[1]);
                        self.keep(Shape::Rule([
                            x0.min(to[0]),
                            y - half,
                            x0.max(to[0]),
                            y + half,
                        ]));
                    }
                    from = Some(to);
                }
            }
        }
    }
}

impl TextSink for Finder {
    fn font(&mut self, _font: &ferman_core::interpret::FontResource) {}

    fn show(&mut self, _show: &TextShow<'_>) -> (f32, f32) {
        (0.0, 0.0)
    }

    fn operator(&mut self, event: &OperatorEvent<'_>) {
        let ctm = event.state.ctm;
        let numbers = event.numbers;
        match (event.name, numbers) {
            (b"w", [width, ..]) => self.width = *width,
            (b"q", _) => {
                if self.saved.len() < MAX_SAVED {
                    self.saved.push(self.width);
                }
            }
            (b"Q", _) => {
                if let Some(width) = self.saved.pop() {
                    self.width = width;
                }
            }
            (b"m", [x, y, ..]) => self.piece(Piece::Move(apply(ctm, *x, *y))),
            (b"l", [x, y, ..]) => self.piece(Piece::Line(apply(ctm, *x, *y))),
            (b"re", [x, y, w, h, ..]) => {
                // Only a matrix that keeps edges level keeps a rectangle one.
                let level = (ctm[1].abs() < 1e-4 && ctm[2].abs() < 1e-4)
                    || (ctm[0].abs() < 1e-4 && ctm[3].abs() < 1e-4);
                if !level {
                    self.spoiled = true;
                    return;
                }
                let [x0, y0] = apply(ctm, *x, *y);
                let [x1, y1] = apply(ctm, x + w, y + h);
                self.piece(Piece::Rect([
                    x0.min(x1),
                    y0.min(y1),
                    x0.max(x1),
                    y0.max(y1),
                ]));
            }
            (b"c" | b"v" | b"y", _) => self.spoiled = true,
            (b"S" | b"s", _) => self.paint(true, false, ctm),
            (b"f" | b"F" | b"f*", _) => self.paint(false, true, ctm),
            (b"B" | b"B*" | b"b" | b"b*", _) => self.paint(true, true, ctm),
            (b"n", _) => self.paint(false, false, ctm),
            _ => {}
        }
    }
}

fn same(a: f32, b: f32) -> bool {
    (a - b).abs() <= SAME
}

/// The shapes as targets: rows of equal adjacent frames are combs, small squares check boxes,
/// other frames of a line's height or a few lines' boxes. Larger frames, a page's border or a
/// table's, are no target.
// shortcut: a comb drawn as one frame with ticks, and frames drawn as four lines, are not found;
// look for them when a real form draws its combs so.
fn classed(shapes: Vec<Shape>) -> Vec<Target> {
    let mut frames: Vec<[f32; 4]> = Vec::new();
    let mut targets = Vec::new();
    for shape in shapes {
        match shape {
            Shape::Frame(rect) => frames.push(rect),
            Shape::Rule(rect) => targets.push(Target {
                kind: TargetKind::Line,
                rect,
                cells: 1,
            }),
        }
    }
    // Rows by bottom, then left to right.
    frames.sort_by(|a, b| a[1].total_cmp(&b[1]).then(a[0].total_cmp(&b[0])));
    frames.dedup_by(|a, b| a.iter().zip(b.iter()).all(|(x, y)| same(*x, *y)));
    let mut used = vec![false; frames.len()];
    let mut start = 0;
    while start < frames.len() {
        let mut end = start + 1;
        while let (Some(last), Some(next)) = (frames.get(end - 1), frames.get(end)) {
            let joined = same(next[1], last[1])
                && same(next[3], last[3])
                && same(next[2] - next[0], last[2] - last[0])
                && (next[0] - last[2]).abs() <= 1.5;
            if !joined {
                break;
            }
            end += 1;
        }
        if end - start >= FEWEST_CELLS
            && let (Some(first), Some(last)) = (frames.get(start), frames.get(end - 1))
        {
            targets.push(Target {
                kind: TargetKind::Comb,
                rect: [first[0], first[1], last[2], last[3]],
                cells: u32::try_from(end - start).unwrap_or(u32::MAX),
            });
            for flag in used.get_mut(start..end).into_iter().flatten() {
                *flag = true;
            }
        }
        start = end;
    }
    for (rect, used) in frames.iter().zip(used) {
        let [l, b, r, t] = *rect;
        let (w, h) = (r - l, t - b);
        let kind = if used {
            continue;
        } else if CHECK_SIDES.contains(&w)
            && CHECK_SIDES.contains(&h)
            && w.max(h) <= 1.34 * w.min(h)
        {
            TargetKind::Check
        } else if BOX_HEIGHTS.contains(&h) && w >= NARROWEST_BOX {
            TargetKind::Box
        } else {
            continue;
        };
        targets.push(Target {
            kind,
            rect: *rect,
            cells: 1,
        });
    }
    targets.sort_by(|a, b| {
        b.rect[3]
            .total_cmp(&a.rect[3])
            .then(a.rect[0].total_cmp(&b.rect[0]))
    });
    targets
}

/// The places to fill on page `page` as the revisions leave it.
///
/// # Errors
///
/// [`CoreError::Write`] for a page the document does not have. A limit the walk meets gives what
/// was found before it, marked [`Targets::truncated`].
pub fn targets(
    document: &Document,
    revisions: &RevisionStore,
    page: usize,
) -> Result<Targets, OpsError> {
    if revisions.pages(document).get(page).is_none() {
        return Err(CoreError::Write(ferman_core::WriteError::NoSuchPage).into());
    }
    let mut finder = Finder {
        width: 1.0,
        ..Finder::default()
    };
    let truncated = match revisions.page_text(document, page, &mut finder) {
        Ok(()) => false,
        Err(CoreError::ResourceLimit { .. }) => true,
        Err(err) => return Err(err.into()),
    };
    let mut targets = classed(finder.shapes);
    let cut = targets.len() > MAX_TARGETS;
    targets.truncate(MAX_TARGETS);
    Ok(Targets {
        targets,
        truncated: truncated || finder.truncated || cut,
    })
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use std::sync::Arc;

    use ferman_core::{OpenOptions, Source, open};

    use super::*;

    fn opened(bytes: Vec<u8>) -> (Document, RevisionStore) {
        let doc = open(
            &Source::from_bytes(Arc::from(&bytes[..])),
            &OpenOptions::default(),
        )
        .unwrap();
        let store = RevisionStore::new(&doc);
        (doc, store)
    }

    /// A one-page PDF drawing `content`, with no cross-reference table: the open path repairs it.
    fn page_of(content: &[u8]) -> Vec<u8> {
        let mut pdf = b"%PDF-1.7\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n".to_vec();
        pdf.extend(b"2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n");
        pdf.extend(
            b"3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R >> endobj\n",
        );
        pdf.extend(format!("4 0 obj << /Length {} >> stream\n", content.len()).as_bytes());
        pdf.extend(content);
        pdf.extend(b"\nendstream endobj\ntrailer << /Root 1 0 R /Size 5 >>\n%%EOF\n");
        pdf
    }

    #[test]
    fn the_flat_form_has_its_lines_boxes_checks_and_comb() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated/form-aks1-flat.pdf");
        let (doc, store) = opened(std::fs::read(path).unwrap());
        let found = targets(&doc, &store, 0).unwrap();
        assert!(!found.truncated);
        let count = |kind| found.targets.iter().filter(|t| t.kind == kind).count();
        let comb: Vec<&Target> = found
            .targets
            .iter()
            .filter(|t| t.kind == TargetKind::Comb)
            .collect();
        assert_eq!(comb.len(), 1, "{found:?}");
        assert_eq!(comb[0].cells, 11);
        // The rule under the title, the phone's and the e-mail's.
        assert_eq!(count(TargetKind::Line), 3, "{found:?}");
        assert_eq!(count(TargetKind::Check), 2);
        // Thirteen text, date, number and choice boxes, and the signature's.
        assert_eq!(count(TargetKind::Box), 14, "{found:?}");
        // Top down: the title's rule first.
        assert_eq!(found.targets[0].kind, TargetKind::Line);
    }

    #[test]
    fn a_hostile_page_gives_a_bounded_list() {
        let mut content = Vec::new();
        for at in 0..60_000u32 {
            let x = at % 500;
            let y = at / 500;
            content.extend(format!("{x} {y} 12 12 re S {x} {y} m {} {y} l S\n", x + 30).as_bytes());
        }
        // A path that never ends.
        content.extend(b"0 0 m ");
        content.extend(b"1 1 l ".repeat(10_000));
        content.extend(b"S\n");
        let (doc, store) = opened(page_of(&content));
        let found = targets(&doc, &store, 0).unwrap();
        assert!(found.truncated);
        assert!(found.targets.len() <= MAX_TARGETS);
        assert!(targets(&doc, &store, 1).is_err());
    }

    #[test]
    fn turned_curved_and_unpainted_paths_are_no_targets() {
        let content = b"q 0.7 0.7 -0.7 0.7 0 0 cm 10 10 100 20 re S Q \
            10 100 m 200 100 l 300 120 400 100 500 100 c S \
            10 200 100 20 re n 10 300 m 200 300 l n \
            10 400 100 20 re S";
        let (doc, store) = opened(page_of(content));
        let found = targets(&doc, &store, 0).unwrap();
        assert_eq!(found.targets.len(), 1, "{found:?}");
        assert_eq!(found.targets[0].kind, TargetKind::Box);
        assert_eq!(found.targets[0].rect, [10.0, 400.0, 110.0, 420.0]);
    }
}
