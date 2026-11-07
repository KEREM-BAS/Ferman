//! Links through the facade (a3-6, G145): the list, the hit test, and create, change and delete,
//! each one step of the history behind the Comment gate. Nothing here opens anything: a link's
//! target comes back classified, and only `Web` and `Mail` may be offered, by the app's prompt
//! with the full target showing. Geometry crosses in displayed points.

use ferman_core::links::{Link, LinkAction, LinkLook};
use ferman_core::structure::Page;
use ferman_core::{CoreError, DocumentOp, WriteError};
use ferman_ops::links::{self as ops, LinkChange, NewLinkTarget, Offered, offered};
use ferman_render::DocumentId;

use super::annotations::{rect_to_display, rect_to_user, to_display, to_user};
use super::edit::RevisionInfo;
use super::engine::Engine;
use super::error::ApiError;
use super::guard::guard_async;

/// Why a link's target is not offered.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RefusedLink {
    /// `/JavaScript`, or a `javascript:` address.
    Script,
    /// `/Launch`, which never runs.
    Launch,
    /// Another file: `/GoToR`, `/GoToE` or a `file:` address.
    File,
    /// An address of another scheme, or one that does not read cleanly.
    Address,
    /// An action Ferman does not know, kept in the file as it came.
    Action,
    /// It does nothing.
    Nothing,
}

/// Where a link goes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LinkTarget {
    /// An `http` or `https` address: ask first, showing all of it.
    Web(String),
    /// A `mailto:` address: ask first, showing all of it.
    Mail(String),
    /// A page of this document, by its handle: just go.
    Page(u64),
    /// A destination that leads nowhere; `wanted` is the page it names, from 1, when it says.
    Broken {
        /// The page it names.
        wanted: Option<u64>,
    },
    /// Not offered; `text` is what the file names, to show and never to open.
    Refused(RefusedLink, String),
}

/// One link.
#[derive(Debug, Clone, PartialEq)]
pub struct LinkInfo {
    /// Its identity for the other calls.
    pub handle: u64,
    /// Its page's handle.
    pub page: u64,
    /// `[left, top, right, bottom]`.
    pub rect: [f32; 4],
    /// Its text's lines, four corners each as [`NewLink::quads`].
    pub quads: Vec<Vec<[f32; 2]>>,
    /// Where it goes.
    pub target: LinkTarget,
    /// Its border.
    pub look: LinkLook,
    /// `/C`.
    pub color: Option<[f32; 3]>,
}

/// A document's links.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct LinkList {
    /// In page order.
    pub links: Vec<LinkInfo>,
    /// Whether a limit cut the list short.
    pub truncated: bool,
}

/// Where a new link goes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NewLinkDestination {
    /// An `http` or `https` address.
    Web(String),
    /// An address, with or without `mailto:`.
    Mail(String),
    /// A page by its handle.
    Page(u64),
}

/// A new link, in displayed points.
#[derive(Debug, Clone, PartialEq)]
pub struct NewLink {
    /// `[left, top, right, bottom]`.
    pub rect: [f32; 4],
    /// Its text's lines: top left, top right, bottom left and bottom right as the reader sees them.
    pub quads: Vec<Vec<[f32; 2]>>,
    /// Where it goes.
    pub target: NewLinkDestination,
    /// Its border.
    pub look: LinkLook,
    /// `/C`.
    pub color: [f32; 3],
}

fn classified(action: LinkAction, pages: &[Page]) -> LinkTarget {
    match action {
        LinkAction::Uri(uri) => match offered(&uri) {
            Some(Offered::Web) => LinkTarget::Web(uri),
            Some(Offered::Mail) => LinkTarget::Mail(uri),
            None => {
                let scheme = uri.split(':').next().unwrap_or_default().trim();
                let reason = if scheme.eq_ignore_ascii_case("javascript") {
                    RefusedLink::Script
                } else if scheme.eq_ignore_ascii_case("file") {
                    RefusedLink::File
                } else {
                    RefusedLink::Address
                };
                LinkTarget::Refused(reason, uri)
            }
        },
        LinkAction::Destination { page, wanted, .. } => {
            match page.and_then(|page| pages.get(page)) {
                Some(page) => LinkTarget::Page(page.handle()),
                None => LinkTarget::Broken { wanted },
            }
        }
        LinkAction::OtherFile(file) => LinkTarget::Refused(RefusedLink::File, file),
        LinkAction::Launch(file) => LinkTarget::Refused(RefusedLink::Launch, file),
        LinkAction::Script => LinkTarget::Refused(RefusedLink::Script, String::new()),
        LinkAction::Other(name) => LinkTarget::Refused(RefusedLink::Action, name),
        LinkAction::Nothing => LinkTarget::Refused(RefusedLink::Nothing, String::new()),
    }
}

fn info(page: &Page, pages: &[Page], link: Link) -> LinkInfo {
    LinkInfo {
        handle: link.handle,
        page: page.handle(),
        rect: rect_to_display(page, link.rect),
        quads: link
            .quads
            .iter()
            .map(|quad| {
                quad.as_chunks::<2>()
                    .0
                    .iter()
                    .map(|point| to_display(page, *point))
                    .collect()
            })
            .collect(),
        target: classified(link.action, pages),
        look: link.look,
        color: link.color,
    }
}

fn destination(
    page_index: impl Fn(u64) -> Option<usize>,
    target: NewLinkDestination,
) -> Result<NewLinkTarget, ApiError> {
    Ok(match target {
        NewLinkDestination::Web(url) => NewLinkTarget::Web(url),
        NewLinkDestination::Mail(address) => NewLinkTarget::Mail(address),
        NewLinkDestination::Page(handle) => {
            NewLinkTarget::Page(page_index(handle).ok_or(CoreError::Write(WriteError::NoSuchPage))?)
        }
    })
}

fn quads_to_user(page: &Page, quads: &[Vec<[f32; 2]>]) -> Result<Vec<[f32; 8]>, ApiError> {
    quads
        .iter()
        .map(|quad| {
            let &[a, b, c, d] = quad.as_slice() else {
                return Err(CoreError::Write(WriteError::AnnotationPlan).into());
            };
            let [a, b, c, d] = [a, b, c, d].map(|point| to_user(page, point));
            Ok([a[0], a[1], b[0], b[1], c[0], c[1], d[0], d[1]])
        })
        .collect()
}

impl Engine {
    /// The links as the committed revisions leave them, from a snapshot; broken ones say so (a3-6).
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open.
    pub async fn links(&self, document: DocumentId) -> Result<LinkList, ApiError> {
        guard_async(async move {
            let snapshot = self.job_snapshot(document)?;
            let (base, store) = (snapshot.base(), snapshot.store());
            let list = store.links(base, None);
            let pages = store.pages(base);
            Ok(LinkList {
                links: list
                    .links
                    .into_iter()
                    .filter_map(|link| Some(info(pages.get(link.page)?, pages, link)))
                    .collect(),
                truncated: list.truncated,
            })
        })
        .await
    }

    /// The topmost link of the page `page` by its handle at `(x, y)`, in displayed points. It
    /// follows nothing.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for a page it does not have, `NotFound` for a document that is not open.
    pub async fn link_at(
        &self,
        document: DocumentId,
        page: u64,
        x: f32,
        y: f32,
    ) -> Result<Option<LinkInfo>, ApiError> {
        guard_async(async move {
            let snapshot = self.job_snapshot(document)?;
            let (base, store) = (snapshot.base(), snapshot.store());
            let index = store
                .page_index(base, page)
                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
            let pages = store.pages(base);
            let on = pages
                .get(index)
                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
            let [x, y] = to_user(on, [x, y]);
            Ok(store
                .links(base, Some(index))
                .links
                .into_iter()
                .rev()
                .find(|link| link.contains(x, y))
                .map(|link| info(on, pages, link)))
        })
        .await
    }

    /// Creates `new` on the page `page` by its handle as one step `name`, and returns its handle.
    /// Only a web address, an e-mail address or a page of this document can be its target.
    ///
    /// # Errors
    ///
    /// `InvalidInput` for a target that cannot be offered, a page it does not have or a value out
    /// of range; else as [`add_annotation`](Self::add_annotation).
    pub async fn add_link(
        &self,
        document: DocumentId,
        page: u64,
        new: NewLink,
        name: String,
    ) -> Result<super::AnnotationCommit, ApiError> {
        guard_async(async move {
            let (current, reload, handle) = self
                .ask(document, move |session| {
                    let index = session
                        .page_indices(&[page])?
                        .first()
                        .copied()
                        .ok_or_else(|| ApiError::from(CoreError::Write(WriteError::NoSuchPage)))?;
                    let mut handle = 0;
                    let (current, reload) = session.commit_change(
                        DocumentOp::Comment,
                        &[],
                        name,
                        &[index],
                        (String::new(), String::new()),
                        |doc, working| {
                            let on = working
                                .pages(doc)
                                .get(index)
                                .cloned()
                                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
                            let target =
                                destination(|page| working.page_index(doc, page), new.target)?;
                            handle = ops::create(
                                doc,
                                working,
                                index,
                                rect_to_user(&on, new.rect),
                                &quads_to_user(&on, &new.quads)?,
                                &target,
                                new.look,
                                new.color,
                            )?;
                            Ok(())
                        },
                    )?;
                    Ok((current, reload, handle))
                })
                .await?;
            Ok(super::AnnotationCommit {
                handle,
                revision: self.revision_info(document, current, reload).await,
            })
        })
        .await
    }

    /// Changes link `handle` as one step `name`: only what is given, so an action Ferman does not
    /// know stays unless `target` replaces it.
    ///
    /// # Errors
    ///
    /// As [`add_link`](Self::add_link).
    #[allow(clippy::too_many_arguments)]
    pub async fn update_link(
        &self,
        document: DocumentId,
        handle: u64,
        rect: Option<[f32; 4]>,
        target: Option<NewLinkDestination>,
        look: Option<LinkLook>,
        color: Option<[f32; 3]>,
        name: String,
    ) -> Result<super::AnnotationCommit, ApiError> {
        guard_async(async move {
            let (current, reload, made) = self
                .ask(document, move |session| {
                    let index = session.link_page(handle)?;
                    let mut made = handle;
                    let (current, reload) = session.commit_change(
                        DocumentOp::Comment,
                        &[],
                        name,
                        &[index],
                        (String::new(), String::new()),
                        |doc, working| {
                            let on = working
                                .pages(doc)
                                .get(index)
                                .cloned()
                                .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
                            let target = target
                                .map(|target| {
                                    destination(|page| working.page_index(doc, page), target)
                                })
                                .transpose()?;
                            let change = LinkChange {
                                rect: rect.map(|rect| rect_to_user(&on, rect)),
                                target,
                                look,
                                color,
                            };
                            made = ops::update(doc, working, handle, &change)?;
                            Ok(())
                        },
                    )?;
                    Ok((current, reload, made))
                })
                .await?;
            Ok(super::AnnotationCommit {
                handle: made,
                revision: self.revision_info(document, current, reload).await,
            })
        })
        .await
    }

    /// Deletes link `handle` as one step `name`.
    ///
    /// # Errors
    ///
    /// As [`add_link`](Self::add_link).
    pub async fn delete_link(
        &self,
        document: DocumentId,
        handle: u64,
        name: String,
    ) -> Result<RevisionInfo, ApiError> {
        guard_async(async move {
            let (current, reload) = self
                .ask(document, move |session| {
                    let index = session.link_page(handle)?;
                    session.commit_change(
                        DocumentOp::Comment,
                        &[],
                        name,
                        &[index],
                        (String::new(), String::new()),
                        |doc, working| Ok(ops::delete(doc, working, handle)?),
                    )
                })
                .await?;
            Ok(self.revision_info(document, current, reload).await)
        })
        .await
    }
}
