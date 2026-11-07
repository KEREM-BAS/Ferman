//! The comment summary (a4-4): the comments of a document as CSV for spreadsheets (RFC 4180, decision
//! 14) or as a new PDF in three layouts. A comment's text is untrusted: in a CSV no cell can become
//! a spreadsheet formula, and in a PDF it is only ever set as text.

use std::collections::{BTreeMap, BTreeSet};

use ferman_core::annotations::{Annotation, AnnotationKind, instant};
use ferman_core::limits::Limits;
use ferman_core::revision::RevisionStore;
use ferman_core::structure::{Page, PdfDate};
use ferman_core::write::Value;
use ferman_core::{CoreError, Document, WriteError};
use ferman_fonts::FontLibrary;

use crate::OpsError;
use crate::annotations::{
    FaceCodes, Faces, LINE_HEIGHT, Ops, SetLine, flatten, set_lines, text_ops,
};
use crate::combine::Assembly;

/// The margin of a summary page, in points.
const MARGIN: f32 = 40.0;
/// The width of the page beside its comments, per unit of the width inside the margins.
const PICTURE_SHARE: f32 = 0.4;
/// The space between the page and the comments, in points.
const GUTTER: f32 = 14.0;
/// A page's heading, a comment's text, in points.
const HEADING: f32 = 11.0;
const BODY: f32 = 9.0;
/// The space before a comment, and how far a reply is indented, in points.
const ENTRY_GAP: f32 = 7.0;
const REPLY_INDENT: f32 = 10.0;
/// The board's preview: text, secondary text and the page's outline.
const INK: [f32; 3] = [0.122, 0.114, 0.102];
const SECONDARY: [f32; 3] = [0.341, 0.325, 0.298];
const OUTLINE: [f32; 3] = [0.871, 0.855, 0.824];
/// `--annot-yellow`, a marker of a comment with no colour of its own.
const MARKER: [f32; 3] = [0.992, 0.890, 0.451];
/// A marker's side, and its number's size, in points.
const MARKER_SIDE: f32 = 12.0;
const MARKER_TEXT: f32 = 7.0;
/// Any height: text flows over pages here, so no box stops it.
const UNBOUNDED: f32 = 1.0e7;

/// The order of the comments.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SummarySort {
    /// Page order.
    Page,
    /// Oldest first.
    Date,
    /// By author, then page order.
    Author,
}

/// A PDF summary's layout (a4-4).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SummaryLayout {
    /// Numbered markers on each page, with its comments beside it.
    PageAndComments,
    /// A list, grouped by page.
    CommentsOnly,
    /// The full page followed by its comments.
    PageThenList,
}

/// The words a summary uses, in the app's language: no localized text is the engine's.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SummaryLabels {
    /// A page's heading, with `{n}` for its number: "Page {n}".
    pub page: String,
    /// The CSV's header row: page, type, author, date, text, replies, status.
    pub columns: Vec<String>,
    /// Each kind's name; a kind not here shows its `/Subtype`.
    pub kinds: Vec<(AnnotationKind, String)>,
    /// The status of an open comment.
    pub open: String,
    /// The status of a resolved one.
    pub resolved: String,
    /// What a page, or a summary, with no comment says.
    pub no_comments: String,
    /// Dates by the region: `yyyy`, `MM`, `dd`, `HH` and `mm` are replaced, as `dd.MM.yyyy HH:mm`.
    pub date_pattern: String,
}

/// What a summary holds.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SummaryOptions {
    /// Open comments.
    pub open: bool,
    /// Resolved comments.
    pub resolved: bool,
    /// Replies under each.
    pub replies: bool,
    /// Pages without comments.
    pub empty_pages: bool,
    /// The order.
    pub sort: SummarySort,
    /// The words.
    pub labels: SummaryLabels,
}

/// One comment of a summary.
struct Entry<'a> {
    annotation: &'a Annotation,
    replies: Vec<&'a Annotation>,
}

fn date_text(date: Option<PdfDate>, pattern: &str) -> String {
    let Some(date) = date else {
        return String::new();
    };
    pattern
        .replace("yyyy", &format!("{:04}", date.year))
        .replace("MM", &format!("{:02}", date.month))
        .replace("dd", &format!("{:02}", date.day))
        .replace("HH", &format!("{:02}", date.hour))
        .replace("mm", &format!("{:02}", date.minute))
}

fn when(annotation: &Annotation) -> Option<PdfDate> {
    annotation.created.or(annotation.modified)
}

fn author(annotation: &Annotation) -> &str {
    annotation.author.as_deref().unwrap_or_default()
}

fn text(annotation: &Annotation) -> &str {
    annotation.contents.as_deref().unwrap_or_default()
}

fn status<'a>(annotation: &Annotation, labels: &'a SummaryLabels) -> &'a str {
    if annotation.resolved.is_some() {
        &labels.resolved
    } else {
        &labels.open
    }
}

/// The comments `options` asks for, in its order: each thread's top with its replies; state replies
/// say only what a status says.
fn entries<'a>(list: &'a [Annotation], options: &SummaryOptions) -> Vec<Entry<'a>> {
    let mut replies: BTreeMap<u64, Vec<&Annotation>> = BTreeMap::new();
    for annotation in list {
        if annotation.handle != annotation.thread && annotation.state.is_none() {
            replies
                .entry(annotation.thread)
                .or_default()
                .push(annotation);
        }
    }
    let mut out: Vec<Entry<'a>> = list
        .iter()
        .filter(|annotation| {
            annotation.handle == annotation.thread
                && annotation.state.is_none()
                && if annotation.resolved.is_some() {
                    options.resolved
                } else {
                    options.open
                }
        })
        .map(|annotation| Entry {
            annotation,
            replies: if options.replies {
                replies.remove(&annotation.handle).unwrap_or_default()
            } else {
                Vec::new()
            },
        })
        .collect();
    match options.sort {
        SummarySort::Page => {}
        SummarySort::Date => out.sort_by_key(|entry| when(entry.annotation).map(|d| instant(&d))),
        SummarySort::Author => {
            out.sort_by(|a, b| author(a.annotation).cmp(author(b.annotation)));
        }
    }
    out
}

/// One cell as RFC 4180 quotes it, with what a spreadsheet would run neutralised: a text that starts
/// with `=`, `+`, `-` or `@`, after anything it would skip, gets an apostrophe first (decision 14).
fn cell(out: &mut String, value: &str) {
    let start = value.trim_start_matches(|c: char| c.is_whitespace() || c.is_control());
    let formula = start.starts_with(['=', '+', '-', '@', '＝', '＋', '－', '＠']);
    out.push('"');
    if formula {
        out.push('\'');
    }
    for c in value.chars() {
        if c == '"' {
            out.push('"');
        }
        out.push(c);
    }
    out.push('"');
}

fn row<'a>(out: &mut String, cells: impl IntoIterator<Item = &'a str>) {
    for (at, value) in cells.into_iter().enumerate() {
        if at > 0 {
            out.push(',');
        }
        cell(out, value);
    }
    out.push_str("\r\n");
}

fn kind_name<'a>(annotation: &'a Annotation, labels: &'a SummaryLabels) -> &'a str {
    labels
        .kinds
        .iter()
        .find(|(kind, _)| *kind == annotation.kind)
        .map_or(annotation.subtype.as_str(), |(_, name)| name.as_str())
}

/// The summary as CSV, one comment per row under `labels.columns`, in UTF-8 with a byte order mark
/// so that a spreadsheet reads Turkish and Arabic as they are.
#[must_use]
pub fn csv(list: &[Annotation], options: &SummaryOptions) -> Vec<u8> {
    let labels = &options.labels;
    let mut out = String::from("\u{FEFF}");
    row(&mut out, labels.columns.iter().map(String::as_str));
    for entry in entries(list, options) {
        let annotation = entry.annotation;
        let replies = entry
            .replies
            .iter()
            .map(|reply| format!("{}: {}", author(reply), text(reply)))
            .collect::<Vec<_>>()
            .join("\n");
        row(
            &mut out,
            [
                annotation.page.saturating_add(1).to_string().as_str(),
                kind_name(annotation, labels),
                author(annotation),
                date_text(when(annotation), &labels.date_pattern).as_str(),
                text(annotation),
                replies.as_str(),
                status(annotation, labels),
            ],
        );
    }
    out.into_bytes()
}

/// A page of the summary before its fonts are embedded.
#[derive(Default)]
struct Sheet {
    regular: Vec<SetLine>,
    bold: Vec<SetLine>,
    /// The page drawn on it: its index and its form's matrix and displayed box on the paper.
    picture: Option<(usize, [f32; 6], [f32; 4])>,
    /// The markers: box, colour.
    markers: Vec<([f32; 4], [f32; 3])>,
}

/// What goes into the file next.
enum Item {
    Sheet(Sheet),
    Page(usize),
}

/// Text flowing down sheets.
struct Flow<'a> {
    regular: Faces<'a>,
    bold: Faces<'a>,
    paper: (f32, f32),
    /// The column's left edge and width.
    column: (f32, f32),
    y: f32,
    sheets: Vec<Sheet>,
}

impl Flow<'_> {
    fn sheet(&mut self) {
        self.sheets.push(Sheet::default());
        self.y = self.paper.1 - MARGIN;
    }

    fn set(
        &mut self,
        value: &str,
        strong: bool,
        size: f32,
        color: [f32; 3],
        indent: f32,
    ) -> Result<(), OpsError> {
        if value.trim().is_empty() {
            return Ok(());
        }
        let faces = if strong {
            &mut self.bold
        } else {
            &mut self.regular
        };
        let width = self.column.1 - indent;
        let lines = set_lines(faces, value, (width, UNBOUNDED), size, color)?;
        for mut line in lines {
            if self.y - size * LINE_HEIGHT < MARGIN || self.sheets.is_empty() {
                self.sheet();
            }
            self.y -= size * LINE_HEIGHT;
            line.x += self.column.0 + indent;
            line.baseline = self.y;
            let Some(sheet) = self.sheets.last_mut() else {
                continue;
            };
            if strong {
                sheet.bold.push(line);
            } else {
                sheet.regular.push(line);
            }
        }
        Ok(())
    }

    fn entry(
        &mut self,
        number: usize,
        entry: &Entry<'_>,
        labels: &SummaryLabels,
        arrow: &str,
    ) -> Result<(), OpsError> {
        let annotation = entry.annotation;
        self.y -= ENTRY_GAP;
        let mut head = format!("{number} · {}", author(annotation));
        let date = date_text(when(annotation), &labels.date_pattern);
        if !date.is_empty() {
            head.push_str(" · ");
            head.push_str(&date);
        }
        if annotation.resolved.is_some() {
            head.push_str(" · ");
            head.push_str(&labels.resolved);
        }
        self.set(&head, true, BODY, INK, 0.0)?;
        self.set(text(annotation), false, BODY, INK, 0.0)?;
        for reply in &entry.replies {
            let line = format!("{arrow}{}: {}", author(reply), text(reply));
            self.set(&line, false, BODY, SECONDARY, REPLY_INDENT)?;
        }
        Ok(())
    }

    /// Ends the sheets so far: they go into `items`, and the next text starts a new one.
    fn close(&mut self, items: &mut Vec<Item>) {
        items.extend(self.sheets.drain(..).map(Item::Sheet));
    }
}

/// The form matrix and the box on the paper that draw `page` at `scale` from `(left, top)`.
fn placed(page: &Page, scale: f32, left: f32, top: f32) -> ([f32; 6], [f32; 4]) {
    let on_paper = |x: f32, y: f32| {
        let (x, y) = page.display_point(x, y);
        (left + x * scale, top - y * scale)
    };
    let (e, f) = on_paper(0.0, 0.0);
    let (x1, y1) = on_paper(1.0, 0.0);
    let (x2, y2) = on_paper(0.0, 1.0);
    let crop = &page.crop_box;
    let (a, b) = on_paper(crop.left, crop.bottom);
    let (c, d) = on_paper(crop.right, crop.top);
    (
        [x1 - e, y1 - f, x2 - e, y2 - f, e, f],
        [a.min(c), b.min(d), a.max(c), b.max(d)],
    )
}

/// Writes one sheet.
fn drawn(
    assembly: &mut Assembly,
    sheet: &Sheet,
    forms: &BTreeMap<usize, ferman_core::write::ObjectRef>,
    paper: (f32, f32),
    (regular, bold): (&FaceCodes, &FaceCodes),
) -> Result<(), OpsError> {
    let mut ops = Ops::default();
    let mut resources = Vec::new();
    if let Some((page, matrix, [l, b, r, t])) = sheet.picture
        && let Some(form) = forms.get(&page)
    {
        ops.op("q");
        ops.nums(&matrix, "cm");
        ops.op("/Page Do").op("Q");
        ops.stroke_colour(OUTLINE).nums(&[0.75], "w");
        ops.nums(&[l, b, r - l, t - b], "re").op("S");
        resources.push((
            b"XObject".to_vec(),
            Value::Dictionary(vec![(b"Page".to_vec(), Value::Reference(*form))]),
        ));
    }
    for ([l, b, r, t], color) in &sheet.markers {
        ops.fill_colour(*color);
        ops.nums(&[*l, *b, r - l, t - b], "re").op("f");
    }
    text_ops(&mut ops, regular, &sheet.regular, (0.0, 0.0));
    text_ops(&mut ops, bold, &sheet.bold, (0.0, 0.0));
    let mut fonts = regular.fonts.clone();
    fonts.extend(bold.fonts.iter().cloned());
    resources.push((b"Font".to_vec(), Value::Dictionary(fonts)));
    assembly.add_drawn(paper, ops.0.into_bytes(), Value::Dictionary(resources))
}

/// The summary as a new PDF on `paper`, in `layout`, headed by `title`, calling `step` between its
/// comments and pages. The file is unencrypted, as Extract's is.
///
/// # Errors
///
/// What `step` returns; [`OpsError::NoFontForText`] for text no font here has; those of building
/// the file.
#[allow(clippy::too_many_arguments)]
pub fn pdf<E: From<OpsError>>(
    document: &Document,
    revisions: &RevisionStore,
    limits: &Limits,
    options: &SummaryOptions,
    layout: SummaryLayout,
    paper: (f32, f32),
    title: &str,
    library: &FontLibrary,
    step: &mut impl FnMut() -> Result<(), E>,
) -> Result<Vec<u8>, E> {
    let list = revisions.annotations(document).annotations;
    let pages = revisions.pages(document);
    let chosen = entries(&list, options);
    let labels = &options.labels;
    let mut flow = Flow {
        regular: Faces::new(library, 400),
        bold: Faces::new(library, 600),
        paper,
        column: (MARGIN, paper.0 - MARGIN * 2.0),
        y: paper.1 - MARGIN,
        sheets: Vec::new(),
    };
    let arrow = if flow.regular.for_char('↳', None).is_ok() {
        "↳ "
    } else {
        ""
    };
    // Pictures keep the pages' order; a list keeps the order asked for.
    let mut by_page: BTreeMap<usize, Vec<&Entry<'_>>> = BTreeMap::new();
    for entry in &chosen {
        by_page
            .entry(entry.annotation.page)
            .or_default()
            .push(entry);
    }
    if options.empty_pages {
        for page in 0..pages.len() {
            by_page.entry(page).or_default();
        }
    }
    let heading = |page: usize| {
        let number = page.saturating_add(1).to_string();
        let name = labels.page.replace("{n}", &number);
        if title.is_empty() {
            name
        } else {
            format!("{title} · {name}")
        }
    };
    let mut items = Vec::new();
    if layout == SummaryLayout::CommentsOnly && options.sort != SummarySort::Page {
        let mut current = None;
        for (at, entry) in chosen.iter().enumerate() {
            step()?;
            if current != Some(entry.annotation.page) {
                current = Some(entry.annotation.page);
                flow.y -= ENTRY_GAP;
                flow.set(&heading(entry.annotation.page), true, HEADING, INK, 0.0)?;
            }
            flow.entry(at.saturating_add(1), entry, labels, arrow)?;
        }
    } else {
        let inner = paper.0 - MARGIN * 2.0;
        for (&index, group) in &by_page {
            step()?;
            let Some(page) = pages.get(index) else {
                continue;
            };
            match layout {
                SummaryLayout::CommentsOnly => {
                    flow.y -= ENTRY_GAP;
                }
                SummaryLayout::PageThenList => {
                    flow.close(&mut items);
                    items.push(Item::Page(index));
                }
                SummaryLayout::PageAndComments => {
                    flow.close(&mut items);
                    flow.sheet();
                    let side = inner * PICTURE_SHARE;
                    let crop = &page.crop_box;
                    let (width, height) = if page.rotation % 180 == 0 {
                        (crop.right - crop.left, crop.top - crop.bottom)
                    } else {
                        (crop.top - crop.bottom, crop.right - crop.left)
                    };
                    let scale =
                        (side / width.max(1.0)).min((paper.1 - MARGIN * 2.0) / height.max(1.0));
                    let top = paper.1 - MARGIN;
                    let (matrix, frame) = placed(page, scale, MARGIN, top);
                    flow.column = (MARGIN + side + GUTTER, inner - side - GUTTER);
                    if let Some(sheet) = flow.sheets.last_mut() {
                        sheet.picture = Some((index, matrix, frame));
                    }
                }
            }
            flow.set(&heading(index), true, HEADING, INK, 0.0)?;
            if group.is_empty() {
                flow.set(&labels.no_comments, false, BODY, SECONDARY, 0.0)?;
            }
            for (at, entry) in group.iter().enumerate() {
                let number = at.saturating_add(1);
                if layout == SummaryLayout::PageAndComments {
                    marker(&mut flow, entry.annotation, number)?;
                }
                flow.entry(number, entry, labels, arrow)?;
            }
            if layout == SummaryLayout::PageAndComments {
                flow.column = (MARGIN, inner);
            }
        }
    }
    if flow.sheets.is_empty() && items.is_empty() {
        flow.set(&labels.no_comments, false, BODY, SECONDARY, 0.0)?;
    }
    flow.close(&mut items);

    let mut assembly = Assembly::new(limits).map_err(E::from)?;
    let wanted: Vec<usize> = items
        .iter()
        .filter_map(|item| match item {
            Item::Page(page) => Some(*page),
            Item::Sheet(sheet) => sheet.picture.map(|(page, ..)| page),
        })
        .collect();
    let mut copies = BTreeMap::new();
    if !wanted.is_empty() {
        // The marks go into the copy's content, whatever the file's own hold.
        let mut marked = revisions.clone();
        marked.begin().map_err(|err| E::from(err.into()))?;
        let on_wanted: BTreeSet<usize> = wanted.iter().copied().collect();
        let handles: Vec<u64> = list
            .iter()
            .filter(|annotation| on_wanted.contains(&annotation.page))
            .map(|annotation| annotation.handle)
            .collect();
        flatten(document, &mut marked, &handles, Some(library)).map_err(E::from)?;
        marked.commit().map_err(|err| E::from(err.into()))?;
        let targets = assembly.copy(document, &marked, &wanted, step)?;
        copies = wanted.iter().copied().zip(targets).collect();
    }
    let mut forms = BTreeMap::new();
    for item in &items {
        if let Item::Sheet(Sheet {
            picture: Some((index, ..)),
            ..
        }) = item
            && let (Some(copy), Some(page)) = (copies.get(index), pages.get(*index))
        {
            let crop = &page.crop_box;
            let bbox = [crop.left, crop.bottom, crop.right, crop.top];
            forms.insert(*index, assembly.page_form(*copy, bbox).map_err(E::from)?);
        }
    }
    let regular = assembly.embed(&flow.regular, "F").map_err(E::from)?;
    let bold = assembly.embed(&flow.bold, "B").map_err(E::from)?;
    for item in &items {
        match item {
            Item::Page(page) => {
                let copy = copies
                    .get(page)
                    .copied()
                    .ok_or(CoreError::Write(WriteError::NoSuchPage))
                    .map_err(|err| E::from(err.into()))?;
                assembly.place(copy);
            }
            Item::Sheet(sheet) => {
                drawn(&mut assembly, sheet, &forms, paper, (&regular, &bold)).map_err(E::from)?;
            }
        }
    }
    assembly.finish().map_err(E::from)
}

/// A comment's numbered marker on the page drawn on the current sheet.
fn marker(flow: &mut Flow<'_>, annotation: &Annotation, number: usize) -> Result<(), OpsError> {
    let [x0, _, _, y1] = annotation.rect;
    let (shaped, width) = flow.bold.shape_line(&number.to_string(), false, 0.0)?;
    let Some(sheet) = flow.sheets.first_mut() else {
        return Ok(());
    };
    let Some((_, [a, b, c, d, e, f], frame)) = sheet.picture else {
        return Ok(());
    };
    let (user_x, user_y) = (x0, y1);
    let x = (a * user_x + c * user_y + e).clamp(frame[0], frame[2] - MARKER_SIDE);
    let y = (b * user_x + d * user_y + f).clamp(frame[1] + MARKER_SIDE, frame[3]);
    sheet.markers.push((
        [x, y - MARKER_SIDE, x + MARKER_SIDE, y],
        annotation.color.unwrap_or(MARKER),
    ));
    sheet.bold.push(SetLine {
        glyphs: shaped,
        x: x + (MARKER_SIDE - width * MARKER_TEXT) / 2.0,
        baseline: y - MARKER_SIDE + (MARKER_SIDE - MARKER_TEXT) / 2.0 + 1.0,
        size: MARKER_TEXT,
        color: INK,
    });
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cells(value: &str) -> String {
        let mut out = String::new();
        cell(&mut out, value);
        out
    }

    #[test]
    fn a_cell_is_quoted_and_no_formula() {
        assert_eq!(cells("düz metin"), "\"düz metin\"");
        assert_eq!(cells("a \"b\", c\nd"), "\"a \"\"b\"\", c\nd\"");
        for formula in [
            "=1+1", "+1", "-1", "@SUM(A1)", "  =1", "\t=1", "\r\n@x", "＝1",
        ] {
            assert_eq!(cells(formula), format!("\"'{formula}\""), "{formula:?}");
        }
    }

    #[test]
    fn a_pattern_gives_the_region_s_date() {
        let date = PdfDate::parse("D:20261013101259Z");
        assert_eq!(date_text(date, "dd.MM.yyyy HH:mm"), "13.10.2026 10:12");
        assert_eq!(date_text(None, "dd"), "");
    }
}
