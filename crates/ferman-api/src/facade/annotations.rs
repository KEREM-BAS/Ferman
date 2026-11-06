//! Annotations through the facade (M4 plan, W2): the list, and create, change, delete, reply and
//! resolve, each one step of the history behind the Comment gate (`annotate` and G35's notice).
//! Geometry crosses in displayed points, as a page's text blocks do: on a turned page the engine
//! turns it, so the app never meets `/Rotate`.

use std::time::{SystemTime, UNIX_EPOCH};

use ferman_core::annotations::{Annotation, AnnotationKind, LineEnd};
use ferman_core::structure::{Page, PdfDate};
use ferman_core::{CoreError, DocumentOp, WriteError};
use ferman_ops::annotations::{self as ops, AnnotationChange, NewAnnotation};
use ferman_render::DocumentId;

use super::edit::RevisionInfo;
use super::engine::Engine;
use super::error::ApiError;
use super::guard::guard_async;

/// One annotation for the panel and the overlay. Geometry is in displayed points.
#[derive(Debug, Clone, PartialEq)]
pub struct AnnotationInfo {
    /// Its identity for the other calls. It stays through edits, undo and saves; an annotation
    /// written directly in the file's page gets a new one with its first change.
    pub handle: u64,
    /// Its page's handle ([`PageInfo::handle`](super::PageInfo::handle)).
    pub page: u64,
    /// What it is.
    pub kind: AnnotationKind,
    /// `/Subtype` as the file has it, which names an [`AnnotationKind::Other`].
    pub subtype: String,
    /// `[left, top, right, bottom]`.
    pub rect: [f32; 4],
    /// As [`NewAnnotation::points`]: quads, strokes, a line's two ends, vertices or a leader.
    pub points: Vec<Vec<[f32; 2]>>,
    /// A line or callout ends in an arrow.
    pub arrow: bool,
    /// `/C` as red, green and blue.
    pub color: Option<[f32; 3]>,
    /// `/CA`.
    pub opacity: f32,
    /// The stroke, in points.
    pub stroke: f32,
    /// A text box's font size.
    pub font_size: Option<f32>,
    /// `/T`.
    pub author: Option<String>,
    /// `/Contents`.
    pub contents: Option<String>,
    /// Whether rich text (`/RC`) goes with it; replacing the text removes it.
    pub rich: bool,
    /// `/CreationDate`.
    pub created: Option<PdfDate>,
    /// `/M`.
    pub modified: Option<PdfDate>,
    /// `/Name`: a note's icon or a stamp's name.
    pub icon: Option<String>,
    /// The annotation it replies to.
    pub replies_to: Option<u64>,
    /// The top of its thread, its own handle when it is no reply.
    pub thread: u64,
    /// The review or other state it sets, for a state reply, which the panel does not list.
    pub state: Option<String>,
    /// On top of a resolved thread: whether it is, by whom and when.
    pub resolved: bool,
    /// Who resolved it.
    pub resolved_by: Option<String>,
    /// When.
    pub resolved_at: Option<PdfDate>,
    /// The people of the file its text mentions.
    pub mentions: Vec<String>,
}

/// A document's annotations.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct AnnotationList {
    /// In page order.
    pub annotations: Vec<AnnotationInfo>,
    /// The names in the file, for mentions (a4-2).
    pub people: Vec<String>,
    /// Whether a limit cut the list or a text short.
    pub truncated: bool,
}

/// What a commit that names an annotation returns.
#[derive(Debug, Clone, PartialEq)]
pub struct AnnotationCommit {
    /// The annotation's handle.
    pub handle: u64,
    /// Where the history stands.
    pub revision: RevisionInfo,
}

fn to_display(page: &Page, [x, y]: [f32; 2]) -> [f32; 2] {
    let (x, y) = page.display_point(x, y);
    [x, y]
}

fn to_user(page: &Page, [x, y]: [f32; 2]) -> [f32; 2] {
    let (x, y) = page.user_point(x, y);
    [x, y]
}

/// A user-space box as displayed `[left, top, right, bottom]`.
fn rect_to_display(page: &Page, [l, b, r, t]: [f32; 4]) -> [f32; 4] {
    let [x0, y0] = to_display(page, [l, b]);
    let [x1, y1] = to_display(page, [r, t]);
    [x0.min(x1), y0.min(y1), x0.max(x1), y0.max(y1)]
}

/// A displayed `[left, top, right, bottom]` as a user-space box.
fn rect_to_user(page: &Page, [l, t, r, b]: [f32; 4]) -> [f32; 4] {
    let [x0, y0] = to_user(page, [l, t]);
    let [x1, y1] = to_user(page, [r, b]);
    [x0.min(x1), y0.min(y1), x0.max(x1), y0.max(y1)]
}

/// Whether a reader keeps annotation `flags` upright on `page`: NoRotate on a turned page. It
/// then turns the box about the top-left corner of `/Rect`.
fn unturned(page: &Page, flags: u32) -> bool {
    const NO_ROTATE: u32 = 16;
    flags & NO_ROTATE != 0 && page.rotation != 0
}

/// The displayed box of a NoRotate annotation on a turned page.
fn rect_unturned_to_display(page: &Page, [l, b, r, t]: [f32; 4]) -> [f32; 4] {
    let [x, y] = to_display(page, [l, t]);
    [x, y, x + (r - l), y + (t - b)]
}

/// Its `/Rect` for a displayed box.
fn rect_unturned_to_user(page: &Page, [l, t, r, b]: [f32; 4]) -> [f32; 4] {
    let [x, y] = to_user(page, [l, t]);
    [x, y - (b - t), x + (r - l), y]
}

fn points_to_user(page: &Page, points: &[Vec<[f32; 2]>]) -> Vec<Vec<[f32; 2]>> {
    points
        .iter()
        .map(|part| part.iter().map(|point| to_user(page, *point)).collect())
        .collect()
}

/// The geometry of `annotation` as [`NewAnnotation::points`] orders it.
fn display_points(page: &Page, annotation: &Annotation) -> Vec<Vec<[f32; 2]>> {
    let shown = |points: &[[f32; 2]]| -> Vec<[f32; 2]> {
        points
            .iter()
            .map(|point| to_display(page, *point))
            .collect()
    };
    if !annotation.quads.is_empty() {
        return annotation
            .quads
            .iter()
            .map(|quad| shown(quad.as_chunks::<2>().0))
            .collect();
    }
    if !annotation.ink.is_empty() {
        return annotation.ink.iter().map(|stroke| shown(stroke)).collect();
    }
    if let Some([x0, y0, x1, y1]) = annotation.line {
        return vec![shown(&[[x0, y0], [x1, y1]])];
    }
    if !annotation.vertices.is_empty() {
        return vec![shown(&annotation.vertices)];
    }
    if !annotation.callout.is_empty() {
        return vec![shown(&annotation.callout)];
    }
    Vec::new()
}

fn info(page: &Page, annotation: Annotation) -> AnnotationInfo {
    AnnotationInfo {
        handle: annotation.handle,
        page: page.handle(),
        kind: annotation.kind,
        rect: if unturned(page, annotation.flags) {
            rect_unturned_to_display(page, annotation.rect)
        } else {
            rect_to_display(page, annotation.rect)
        },
        points: display_points(page, &annotation),
        arrow: annotation.line_ends != [LineEnd::None; 2],
        color: annotation.color,
        opacity: annotation.opacity,
        stroke: annotation.stroke,
        font_size: annotation.font_size,
        rich: annotation.rich,
        created: annotation.created,
        modified: annotation.modified,
        replies_to: annotation.replies_to,
        thread: annotation.thread,
        resolved: annotation.resolved.is_some(),
        resolved_at: annotation.resolved.as_ref().and_then(|done| done.at),
        resolved_by: annotation.resolved.and_then(|done| done.by),
        subtype: annotation.subtype,
        author: annotation.author,
        contents: annotation.contents,
        icon: annotation.icon,
        state: annotation.state,
        mentions: annotation.mentions,
    }
}

/// `seconds` since the Unix epoch as a PDF date in UTC: readers show it in their own zone.
fn pdf_date(seconds: u64) -> String {
    let days = i64::try_from(seconds / 86_400).unwrap_or(0);
    let rest = seconds % 86_400;
    // Civil from days (Howard Hinnant's algorithm), for a date after 1970.
    let z = days + 719_468;
    let era = z / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = yoe + era * 400 + i64::from(month <= 2);
    format!(
        "D:{year:04}{month:02}{day:02}{:02}{:02}{:02}Z",
        rest / 3600,
        rest % 3600 / 60,
        rest % 60
    )
}

fn now() -> String {
    pdf_date(
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |since| since.as_secs()),
    )
}

fn no_step_texts() -> (String, String) {
    (String::new(), String::new())
}

impl Engine {
    /// The annotations as the committed revisions leave them, from a snapshot: this waits for no
    /// edit. Links, form widgets and popups are not listed.
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open.
    pub async fn annotations(&self, document: DocumentId) -> Result<AnnotationList, ApiError> {
        guard_async(async move {
            let snapshot = self.job_snapshot(document)?;
            let (base, store) = (snapshot.base(), snapshot.store());
            let list = store.annotations(base);
            let pages = store.pages(base);
            Ok(AnnotationList {
                annotations: list
                    .annotations
                    .into_iter()
                    .filter_map(|annotation| Some(info(pages.get(annotation.page)?, annotation)))
                    .collect(),
                people: list.people,
                truncated: list.truncated,
            })
        })
        .await
    }

    /// Creates `new`, in displayed points, on the page `page` by its handle, as one step `name`.
    /// Its dates are now; its `/NM` is new. A text box's or stamp's text is set in the bundled
    /// fonts, then the installed ones.
    ///
    /// # Errors
    ///
    /// `NotEditable` with the reason for a document whose permissions forbid comments or that
    /// cannot be changed, `ConfirmationRequired` for a signed document before its confirmation,
    /// `InvalidInput` for a page it does not have, a kind not created, a value out of range or
    /// while a transaction is open, `Unsupported` for text no font here has, and `NotFound` for a
    /// document that is not open. So do the other annotation calls, for what they name.
    pub async fn add_annotation(
        &self,
        document: DocumentId,
        page: u64,
        new: NewAnnotation,
        name: String,
    ) -> Result<AnnotationCommit, ApiError> {
        guard_async(async move {
            let (current, reload, handle) = self
                .ask(document, move |session| {
                    let index = session
                        .page_indices(&[page])?
                        .first()
                        .copied()
                        .ok_or_else(|| ApiError::from(CoreError::Write(WriteError::NoSuchPage)))?;
                    let library = matches!(
                        new.kind,
                        AnnotationKind::FreeText | AnnotationKind::Callout | AnnotationKind::Stamp
                    )
                    .then(|| session.font_library());
                    let date = now();
                    let mut handle = 0;
                    let (current, reload) = session.commit_change(
                        DocumentOp::Comment,
                        &[],
                        name,
                        &[index],
                        no_step_texts(),
                        |doc, working| {
                            let page = working
                                .pages(doc)
                                .get(index)
                                .cloned()
                                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
                            let new = NewAnnotation {
                                rect: rect_to_user(&page, new.rect),
                                points: points_to_user(&page, &new.points),
                                ..new
                            };
                            handle =
                                ops::create(doc, working, index, &new, &date, library.as_deref())?;
                            Ok(())
                        },
                    )?;
                    Ok((current, reload, handle))
                })
                .await?;
            Ok(AnnotationCommit {
                handle,
                revision: self.revision_info(document, current, reload).await,
            })
        })
        .await
    }

    /// Applies `change`, in displayed points, to annotation `handle` as one step `name`. Only
    /// what changes is written: its other keys, rich text included until its text is replaced,
    /// stay as they came, and its appearance is made again only if what it draws changes.
    ///
    /// # Errors
    ///
    /// As [`add_annotation`](Self::add_annotation).
    pub async fn update_annotation(
        &self,
        document: DocumentId,
        handle: u64,
        change: AnnotationChange,
        name: String,
    ) -> Result<AnnotationCommit, ApiError> {
        guard_async(async move {
            let (current, reload, handle) = self
                .ask(document, move |session| {
                    let annotation = session.annotation(handle)?;
                    let index = annotation.page;
                    let library = matches!(
                        annotation.kind,
                        AnnotationKind::FreeText | AnnotationKind::Callout
                    )
                    .then(|| session.font_library());
                    let date = now();
                    let mut made = handle;
                    let (current, reload) = session.commit_change(
                        DocumentOp::Comment,
                        &[],
                        name,
                        &[index],
                        no_step_texts(),
                        |doc, working| {
                            let page = working
                                .pages(doc)
                                .get(index)
                                .cloned()
                                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
                            let change = AnnotationChange {
                                rect: change.rect.map(|rect| {
                                    if unturned(&page, annotation.flags) {
                                        rect_unturned_to_user(&page, rect)
                                    } else {
                                        rect_to_user(&page, rect)
                                    }
                                }),
                                points: change
                                    .points
                                    .as_deref()
                                    .map(|points| points_to_user(&page, points)),
                                ..change
                            };
                            made = ops::update(
                                doc,
                                working,
                                handle,
                                &change,
                                &date,
                                library.as_deref(),
                            )?;
                            Ok(())
                        },
                    )?;
                    Ok((current, reload, made))
                })
                .await?;
            Ok(AnnotationCommit {
                handle,
                revision: self.revision_info(document, current, reload).await,
            })
        })
        .await
    }

    /// Deletes annotation `handle`, with its popup and its replies, as one step `name`.
    ///
    /// # Errors
    ///
    /// As [`add_annotation`](Self::add_annotation).
    pub async fn delete_annotation(
        &self,
        document: DocumentId,
        handle: u64,
        name: String,
    ) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self
                .ask(document, move |session| {
                    let index = session.annotation(handle)?.page;
                    session.commit_change(
                        DocumentOp::Comment,
                        &[],
                        name,
                        &[index],
                        no_step_texts(),
                        |doc, working| Ok(ops::delete(doc, working, handle)?),
                    )
                })
                .await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }

    /// Replies to annotation `handle` as `author`, as one step `name`. Mentions are text: nothing
    /// is sent to anyone.
    ///
    /// # Errors
    ///
    /// As [`add_annotation`](Self::add_annotation).
    pub async fn reply_to_annotation(
        &self,
        document: DocumentId,
        handle: u64,
        author: String,
        text: String,
        name: String,
    ) -> Result<AnnotationCommit, ApiError> {
        guard_async(async move {
            let (current, reload, reply) = self
                .ask(document, move |session| {
                    let index = session.annotation(handle)?.page;
                    let date = now();
                    let mut reply = 0;
                    let (current, reload) = session.commit_change(
                        DocumentOp::Comment,
                        &[],
                        name,
                        &[index],
                        no_step_texts(),
                        |doc, working| {
                            reply = ops::reply(doc, working, handle, &author, &text, &date)?;
                            Ok(())
                        },
                    )?;
                    Ok((current, reload, reply))
                })
                .await?;
            Ok(AnnotationCommit {
                handle: reply,
                revision: self.revision_info(document, current, reload).await,
            })
        })
        .await
    }

    /// Resolves or reopens the thread of annotation `handle` as `author`, as one step `name`; a
    /// thread already so adds no step.
    ///
    /// # Errors
    ///
    /// As [`add_annotation`](Self::add_annotation).
    pub async fn set_annotation_resolved(
        &self,
        document: DocumentId,
        handle: u64,
        author: String,
        resolved: bool,
        name: String,
    ) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self
                .ask(document, move |session| {
                    let index = session.annotation(handle)?.page;
                    let date = now();
                    session.commit_change(
                        DocumentOp::Comment,
                        &[],
                        name,
                        &[index],
                        no_step_texts(),
                        |doc, working| {
                            Ok(ops::set_resolved(
                                doc, working, handle, &author, resolved, &date,
                            )?)
                        },
                    )
                })
                .await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_pdf_date_reads_back() {
        // 2026-11-06 12:34:56 UTC.
        let text = pdf_date(1_793_968_496);
        assert_eq!(text, "D:20261106123456Z");
        let date = PdfDate::parse(&text).unwrap();
        assert_eq!((date.year, date.month, date.day), (2026, 11, 6));
        assert_eq!(date.offset_minutes, Some(0));
    }
}
