//! The tools a client calls (ADR 0019): each reads or runs one facade call, with a JSON schema
//! from its parameters. Read tools work for every connected client; the others only once the
//! user grants the client edit ([`Engine::as_client`] refuses otherwise). A change's step names
//! the client and reaches the app's change stream; a signed document's first change, and what
//! the UI would confirm with the user (saving, writing or reading a file, signing, restoring a
//! version), become requests the user answers in the app ([`Engine::ask_user`]).
//!
//! Pages are numbered from 1 as the user sees them; documents, blocks, comments, fields, links
//! and attachments by the ids the read tools give.

use std::collections::HashMap;
use std::future::Future;
use std::path::PathBuf;
use std::sync::PoisonError;

use futures_channel::oneshot;
use rmcp::handler::server::wrapper::Parameters;
use rmcp::model::{CallToolResult, ContentBlock};
use rmcp::{schemars, tool, tool_router};
use serde::Deserialize;
use serde_json::{Value, json};

use super::Server;
use crate::facade::{
    AnnotationCommit, AnnotationKind, ApiError, BlockId, ClientId, ClientRequestKind, CombineFile,
    CombineSource, DocumentId, ErrorKind, FieldCommit, InfoEdit, Ink, JobEvent, JobId, JobResult,
    JobSink, LinkLook, MessageKey, NewAnnotation, NewLink, NewLinkDestination, NewSignature,
    OutlineEdit, Paper, Preset, RevisionInfo, SearchEvent, SearchMatch, SearchOptions,
    SearchPlaces, SearchSink, SplitOutput,
};

/// The most search matches a tool returns.
const MAX_MATCHES: usize = 200;
/// A new page's size when the client gives none: A4 in points.
const A4: (f32, f32) = (595.0, 842.0);

/// A call that commits a step, so its change reaches the app.
trait Committed {
    fn revision(&self) -> &RevisionInfo;
}

impl Committed for RevisionInfo {
    fn revision(&self) -> &RevisionInfo {
        self
    }
}

impl Committed for AnnotationCommit {
    fn revision(&self) -> &RevisionInfo {
        &self.revision
    }
}

impl Committed for FieldCommit {
    fn revision(&self) -> &RevisionInfo {
        &self.revision
    }
}

fn invalid(details: &str) -> ApiError {
    ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL).with_details(details)
}

/// A tool's answer: its JSON, or the error as text the model reads.
fn reply(result: Result<Value, ApiError>) -> CallToolResult {
    match result {
        Ok(value) => CallToolResult::success(vec![ContentBlock::text(value.to_string())]),
        Err(err) => CallToolResult::error(vec![ContentBlock::text(err.to_string())]),
    }
}

fn revision(info: &RevisionInfo) -> Value {
    json!({ "step": info.current })
}

/// Hands a job's result to the tool that waits for it.
struct JobDone(Option<oneshot::Sender<JobResult>>);

impl JobSink for JobDone {
    fn deliver(&mut self, event: JobEvent) {
        if let Some(result) = event.result
            && let Some(done) = self.0.take()
        {
            let _ = done.send(result);
        }
    }
}

/// Collects a search's matches, up to [`MAX_MATCHES`].
struct Found {
    matches: Vec<SearchMatch>,
    done: Option<oneshot::Sender<Vec<SearchMatch>>>,
}

impl SearchSink for Found {
    fn deliver(&mut self, event: SearchEvent) -> bool {
        let finished = match event {
            SearchEvent::Matches(matches) => {
                self.matches.extend(matches);
                self.matches.len() >= MAX_MATCHES
            }
            SearchEvent::Done { .. } => true,
            SearchEvent::Started(_) | SearchEvent::Progress { .. } => false,
        };
        if finished && let Some(done) = self.done.take() {
            self.matches.truncate(MAX_MATCHES);
            let _ = done.send(std::mem::take(&mut self.matches));
        }
        // Past the cap nobody listens: the search stops.
        self.done.is_some()
    }
}

// Parameters. Each is a tool's JSON schema; the doc comments are its descriptions.

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct DocumentArg {
    /// The document's id, from list_documents.
    document: u64,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct PageArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page number, from 1.
    page: u32,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct SearchArg {
    /// The document's id, from list_documents.
    document: u64,
    /// What to find.
    query: String,
    /// Match upper and lower case exactly.
    #[serde(default)]
    match_case: bool,
    /// Match whole words only.
    #[serde(default)]
    whole_words: bool,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct EditTextArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page number, from 1.
    page: u32,
    /// The block's id, from read_page_text.
    block: u64,
    /// The block's whole new text, lines separated by newlines.
    text: String,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct PagesArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page numbers, from 1.
    pages: Vec<u32>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct RotateArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page numbers, from 1.
    pages: Vec<u32>,
    /// Quarter turns, clockwise when positive.
    quarter_turns: i32,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct MoveArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page numbers to move, from 1; they move together in document order.
    pages: Vec<u32>,
    /// The page they go before; the end when absent.
    before: Option<u32>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct BlankArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page they go after; the start when absent.
    after: Option<u32>,
    /// How many.
    count: u32,
    /// Width in points; A4 when absent.
    width: Option<f32>,
    /// Height in points; A4 when absent.
    height: Option<f32>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct CommentArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page number, from 1.
    page: u32,
    /// Where the note goes, in points from the page's left edge as displayed.
    x: f32,
    /// Where the note goes, in points from the page's top edge as displayed.
    y: f32,
    /// The comment's text.
    text: String,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct ReplyArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The comment's id, from list_comments.
    comment: u64,
    /// The reply's text.
    text: String,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct ResolveArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The comment's id, from list_comments.
    comment: u64,
    /// Resolved, or open again.
    resolved: bool,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct HandleArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The id, from the matching list tool.
    id: u64,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct LinkArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page number, from 1.
    page: u32,
    /// The link's area as displayed: left, top, right, bottom in points.
    rect: [f32; 4],
    /// A web address (https://…) or e-mail address (mailto:…) it opens.
    url: Option<String>,
    /// Or the page number, from 1, it goes to.
    to_page: Option<u32>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct FieldArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The field's id, from list_form_fields.
    field: u64,
    /// The values: the text, export values, or a button's on-state; none to empty it.
    values: Vec<String>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct InfoArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The new title; unchanged when absent.
    title: Option<String>,
    /// The new author; unchanged when absent.
    author: Option<String>,
    /// The new subject; unchanged when absent.
    subject: Option<String>,
    /// The new keywords; unchanged when absent.
    keywords: Option<String>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct Bookmark {
    /// Its title.
    title: String,
    /// The page number, from 1, it goes to.
    page: u32,
    /// Its nesting, from 0; at most one more than the bookmark before it.
    #[serde(default)]
    depth: u32,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct BookmarksArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The bookmarks, in order; they replace the document's.
    bookmarks: Vec<Bookmark>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct PathArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The file's absolute path.
    path: PathBuf,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct CompressArg {
    /// The document's id, from list_documents.
    document: u64,
    /// "high_quality", "balanced" or "smallest".
    preset: String,
    /// The new file's absolute path; it must not exist.
    output: PathBuf,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct ExtractArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page numbers, from 1.
    pages: Vec<u32>,
    /// The new file's absolute path; it must not exist.
    output: PathBuf,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct Part {
    /// The new file's name, without its folder.
    name: String,
    /// Its first page, from 1.
    first: u32,
    /// Its last page, from 1.
    last: u32,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct SplitArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The files to write.
    parts: Vec<Part>,
    /// The folder, an absolute path, they go in.
    folder: PathBuf,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct CombineArg {
    /// The PDF files' absolute paths, in order.
    files: Vec<PathBuf>,
    /// The new file's absolute path; it must not exist.
    output: PathBuf,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct SignArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The page number, from 1.
    page: u32,
    /// The signature's box as displayed: left, top, right, bottom in points.
    rect: [f32; 4],
    /// The name, written in a handwriting style.
    name: String,
    /// The signature field it signs, by its full name, if any.
    field: Option<String>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
#[schemars(crate = "rmcp::schemars")]
struct VersionArg {
    /// The document's id, from list_documents.
    document: u64,
    /// The version's id, from list_versions.
    version: u64,
}

impl Server {
    /// The connection's client, from its handshake.
    fn client(&self) -> Result<ClientId, ApiError> {
        self.client
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .ok_or_else(|| invalid("the MCP handshake has not happened"))
    }

    /// The client's name, for the author of its comments and replies.
    fn client_name(&self, client: ClientId) -> String {
        self.engine
            .connected_clients()
            .into_iter()
            .find(|connected| connected.id == client)
            .map(|connected| connected.name)
            .unwrap_or_default()
    }

    /// The handles of pages `numbers` (from 1).
    fn handles(&self, document: DocumentId, numbers: &[u32]) -> Result<Vec<u64>, ApiError> {
        let pages = self.engine.document_now(document)?.pages;
        numbers
            .iter()
            .map(|&number| {
                number
                    .checked_sub(1)
                    .and_then(|index| pages.get(usize::try_from(index).ok()?))
                    .map(|page| page.handle)
                    .ok_or_else(|| invalid("no such page"))
            })
            .collect()
    }

    fn handle(&self, document: DocumentId, number: u32) -> Result<u64, ApiError> {
        self.handles(document, &[number])
            .map(|handles| handles.first().copied().unwrap_or_default())
    }

    /// Page numbers (from 1) by page handle.
    fn numbers(&self, document: DocumentId) -> Result<HashMap<u64, usize>, ApiError> {
        Ok(self
            .engine
            .document_now(document)?
            .pages
            .iter()
            .enumerate()
            .map(|(index, page)| (page.handle, index + 1))
            .collect())
    }

    /// Runs `call` as the client's change; a signed document's first change asks the user and
    /// runs it again once allowed. The step reaches the app's change stream.
    async fn change<T, F>(&self, document: DocumentId, call: impl Fn() -> F) -> Result<T, ApiError>
    where
        T: Committed,
        F: Future<Output = Result<T, ApiError>>,
    {
        let client = self.client()?;
        let mut result = self.engine.as_client(client, call())?.await;
        if result
            .as_ref()
            .is_err_and(|err| err.kind == ErrorKind::ConfirmationRequired)
        {
            self.engine
                .ask_user(client, Some(document), ClientRequestKind::EditSigned)
                .await?;
            self.engine.confirm_client_signed(document, client).await?;
            result = self.engine.as_client(client, call())?.await;
        }
        let done = result?;
        self.engine
            .report_client_change(client, document, done.revision());
        Ok(done)
    }

    /// Asks the user for `kind`, once the client may edit.
    async fn allowed(
        &self,
        document: Option<DocumentId>,
        kind: ClientRequestKind,
    ) -> Result<ClientId, ApiError> {
        let client = self.client()?;
        self.engine.as_client(client, async {})?.await;
        self.engine.ask_user(client, document, kind).await?;
        Ok(client)
    }

    /// Starts a job for the client and waits for its result.
    async fn job(
        &self,
        client: ClientId,
        start: impl FnOnce(Box<dyn JobSink>) -> Result<JobId, ApiError>,
    ) -> Result<(JobId, Vec<String>), ApiError> {
        let (done, result) = oneshot::channel();
        let job = self
            .engine
            .as_client(client, async { start(Box::new(JobDone(Some(done)))) })?
            .await?;
        match result.await {
            Ok(JobResult::Done { outputs, .. }) => Ok((
                job,
                outputs
                    .into_iter()
                    .map(|output| output.path.to_string_lossy().into_owned())
                    .collect(),
            )),
            Ok(JobResult::Failed(err)) => Err(err),
            Ok(JobResult::Cancelled) | Err(_) => Err(ApiError::internal("the job was cancelled")),
        }
    }

    /// A job that writes new files: the user allows the path first.
    async fn write_job(
        &self,
        document: Option<DocumentId>,
        path: PathBuf,
        start: impl FnOnce(Box<dyn JobSink>) -> Result<JobId, ApiError>,
    ) -> Result<Value, ApiError> {
        if !path.is_absolute() {
            return Err(invalid("the path must be absolute"));
        }
        let client = self
            .allowed(document, ClientRequestKind::WriteFile(path))
            .await?;
        // shortcut: the job writes straight to the path, with no staging for the sandboxed macOS
        // app; give requests a picker answer that grants the path once a client meets it.
        let (_, written) = self.job(client, start).await?;
        Ok(json!({ "written": written }))
    }
}

#[tool_router(router = tool_router, vis = "pub(super)")]
impl Server {
    #[tool(description = "Lists the documents open in Ferman, with their ids.")]
    async fn list_documents(&self) -> CallToolResult {
        reply(self.client().and_then(|_| {
            Ok(json!(
                self.engine
                    .open_documents()?
                    .into_iter()
                    .map(|document| json!({
                        "document": document.id.get(),
                        "name": document.name,
                        "title": document.title,
                        "pages": document.pages,
                    }))
                    .collect::<Vec<_>>()
            ))
        }))
    }

    #[tool(
        description = "A document's pages, bookmarks, attachments and information as they stand now."
    )]
    async fn document_info(&self, Parameters(arg): Parameters<DocumentArg>) -> CallToolResult {
        reply(self.client().and_then(|_| {
            let now = self
                .engine
                .document_now(DocumentId::from_raw(arg.document))?;
            fn outline(items: &[crate::facade::OutlineItem]) -> Vec<Value> {
                items
                    .iter()
                    .map(|item| {
                        json!({
                            "title": item.title,
                            "page": item.page.map(|page| page.saturating_add(1)),
                            "children": outline(&item.children),
                        })
                    })
                    .collect()
            }
            Ok(json!({
                "pages": now.pages.iter().enumerate().map(|(index, page)| json!({
                    "page": index + 1,
                    "width": page.size.width,
                    "height": page.size.height,
                    "rotation": page.rotation,
                    "label": page.label,
                })).collect::<Vec<_>>(),
                "bookmarks": outline(&now.outline),
                "attachments": now.attachments.iter().enumerate().map(|(index, attachment)| json!({
                    "id": index,
                    "name": attachment.name,
                    "description": attachment.description,
                    "size": attachment.size,
                })).collect::<Vec<_>>(),
                "title": now.info.title,
                "author": now.info.author,
                "subject": now.info.subject,
                "keywords": now.info.keywords,
            }))
        }))
    }

    #[tool(description = "A page's text blocks, with the ids edit_text takes.")]
    async fn read_page_text(&self, Parameters(arg): Parameters<PageArg>) -> CallToolResult {
        let read = async {
            self.client()?;
            let index = arg
                .page
                .checked_sub(1)
                .ok_or_else(|| invalid("no such page"))?;
            let page = self
                .engine
                .text_blocks(DocumentId::from_raw(arg.document), index)
                .await?;
            Ok(json!(
                page.blocks
                    .iter()
                    .map(|block| json!({
                        "block": block.id.0,
                        "text": block.lines.iter().map(|line| line.text.as_str())
                            .collect::<Vec<_>>().join("\n"),
                        "editable": block.editability.is_editable(),
                    }))
                    .collect::<Vec<_>>()
            ))
        };
        reply(read.await)
    }

    #[tool(description = "Finds text in a document, bookmarks, comments and form fields included.")]
    async fn search_text(&self, Parameters(arg): Parameters<SearchArg>) -> CallToolResult {
        let read = async {
            self.client()?;
            let (done, found) = oneshot::channel();
            let options = SearchOptions {
                match_case: arg.match_case,
                whole_words: arg.whole_words,
                ignore_accents: false,
                turkish: false,
            };
            let places = SearchPlaces {
                bookmarks: true,
                comments: true,
                fields: true,
            };
            self.engine.search(
                DocumentId::from_raw(arg.document),
                arg.query,
                options,
                places,
                Box::new(Found {
                    matches: Vec::new(),
                    done: Some(done),
                }),
            )?;
            let matches = found.await.unwrap_or_default();
            Ok(json!({
                "matches": matches.iter().map(|found| json!({
                    "page": found.page.saturating_add(1),
                    "text": found.snippet,
                })).collect::<Vec<_>>(),
                "truncated": matches.len() >= MAX_MATCHES,
            }))
        };
        reply(read.await)
    }

    #[tool(description = "The document's comments and other annotations, with their replies.")]
    async fn list_comments(&self, Parameters(arg): Parameters<DocumentArg>) -> CallToolResult {
        let read = async {
            self.client()?;
            let document = DocumentId::from_raw(arg.document);
            let numbers = self.numbers(document)?;
            let list = self.engine.annotations(document).await?;
            Ok(json!(
                list.annotations
                    .iter()
                    .map(|annotation| json!({
                        "id": annotation.handle,
                        "page": numbers.get(&annotation.page),
                        "kind": format!("{:?}", annotation.kind),
                        "author": annotation.author,
                        "text": annotation.contents,
                        "quote": annotation.quote,
                        "replies_to": annotation.replies_to,
                        "resolved": annotation.resolved,
                    }))
                    .collect::<Vec<_>>()
            ))
        };
        reply(read.await)
    }

    #[tool(description = "The document's form fields and their values.")]
    async fn list_form_fields(&self, Parameters(arg): Parameters<DocumentArg>) -> CallToolResult {
        let read = async {
            self.client()?;
            let form = self
                .engine
                .form_fields(DocumentId::from_raw(arg.document))
                .await?;
            Ok(json!(
                form.fields
                    .iter()
                    .map(|field| json!({
                        "field": field.handle,
                        "name": field.name,
                        "label": field.label,
                        "kind": format!("{:?}", field.kind),
                        "values": field.values,
                        "options": field.options.iter().map(|(value, _)| value).collect::<Vec<_>>(),
                        "required": field.required,
                        "editable": field.editable,
                    }))
                    .collect::<Vec<_>>()
            ))
        };
        reply(read.await)
    }

    #[tool(description = "The document's links.")]
    async fn list_links(&self, Parameters(arg): Parameters<DocumentArg>) -> CallToolResult {
        let read = async {
            self.client()?;
            let document = DocumentId::from_raw(arg.document);
            let numbers = self.numbers(document)?;
            let list = self.engine.links(document).await?;
            Ok(json!(
                list.links
                    .iter()
                    .map(|link| json!({
                        "id": link.handle,
                        "page": numbers.get(&link.page),
                        "rect": link.rect,
                        "target": format!("{:?}", link.target),
                    }))
                    .collect::<Vec<_>>()
            ))
        };
        reply(read.await)
    }

    #[tool(description = "The document's edit history, naming the steps clients made.")]
    async fn history(&self, Parameters(arg): Parameters<DocumentArg>) -> CallToolResult {
        let read = async {
            self.client()?;
            let history = self
                .engine
                .history(DocumentId::from_raw(arg.document))
                .await?;
            Ok(json!({
                "current": history.current,
                "steps": history.steps.iter().map(|step| json!({
                    "name": step.name,
                    "client": step.client,
                })).collect::<Vec<_>>(),
            }))
        };
        reply(read.await)
    }

    #[tool(description = "The saved versions of the document's file.")]
    async fn list_versions(&self, Parameters(arg): Parameters<DocumentArg>) -> CallToolResult {
        let read = async {
            self.client()?;
            let versions = self
                .engine
                .versions(DocumentId::from_raw(arg.document))
                .await?;
            Ok(json!(
                versions
                    .iter()
                    .map(|version| json!({
                        "version": version.id,
                        "kind": format!("{:?}", version.kind),
                        "time": version.time,
                        "edits": version.edits,
                    }))
                    .collect::<Vec<_>>()
            ))
        };
        reply(read.await)
    }

    #[tool(
        description = "Replaces a text block's text, in the document's own fonts. Needs edit permission."
    )]
    async fn edit_text(&self, Parameters(arg): Parameters<EditTextArg>) -> CallToolResult {
        let edit = async {
            let client = self.client()?;
            let document = DocumentId::from_raw(arg.document);
            let index = arg
                .page
                .checked_sub(1)
                .ok_or_else(|| invalid("no such page"))?;
            let engine = self.engine;
            let transaction = engine
                .client_begin_edit(client, document, index, BlockId(arg.block))
                .await?;
            let committed = async {
                let preview = engine.client_apply(client, transaction, arg.text).await?;
                let name = "Edited text".to_owned();
                let mut result = engine
                    .client_commit(client, transaction, name.clone())
                    .await;
                if result
                    .as_ref()
                    .is_err_and(|err| err.kind == ErrorKind::ConfirmationRequired)
                {
                    engine
                        .ask_user(client, Some(document), ClientRequestKind::EditSigned)
                        .await?;
                    engine.confirm_client_signed(document, client).await?;
                    result = engine.client_commit(client, transaction, name).await;
                }
                Ok::<_, ApiError>((result?, preview))
            };
            match committed.await {
                Ok((info, preview)) => Ok(json!({
                    "step": info.current,
                    "overflowing": preview.overflowing,
                    "fonts_added": info.substitutions.iter()
                        .map(|substitution| substitution.substitution.to.clone())
                        .collect::<Vec<_>>(),
                })),
                Err(err) => {
                    // The block stays as it was; a font choice is the user's (ADR 0006).
                    let _ = engine.client_rollback(client, transaction).await;
                    Err(err)
                }
            }
        };
        reply(edit.await)
    }

    #[tool(description = "Turns pages. Needs edit permission.")]
    async fn rotate_pages(&self, Parameters(arg): Parameters<RotateArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let pages = self.handles(document, &arg.pages)?;
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.rotate_pages(
                        document,
                        pages.clone(),
                        arg.quarter_turns,
                        "Rotated pages".to_owned(),
                    )
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(description = "Deletes pages. Needs edit permission.")]
    async fn delete_pages(&self, Parameters(arg): Parameters<PagesArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let pages = self.handles(document, &arg.pages)?;
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.delete_pages(document, pages.clone(), "Deleted pages".to_owned())
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(description = "Moves pages. Needs edit permission.")]
    async fn move_pages(&self, Parameters(arg): Parameters<MoveArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let pages = self.handles(document, &arg.pages)?;
            let before = arg
                .before
                .map(|before| self.handle(document, before))
                .transpose()?;
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.move_pages(document, pages.clone(), before, "Moved pages".to_owned())
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(description = "Duplicates pages. Needs edit permission.")]
    async fn duplicate_pages(&self, Parameters(arg): Parameters<PagesArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let pages = self.handles(document, &arg.pages)?;
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.duplicate_pages(document, pages.clone(), "Duplicated pages".to_owned())
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(description = "Inserts blank pages. Needs edit permission.")]
    async fn insert_blank_pages(&self, Parameters(arg): Parameters<BlankArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let after = arg
                .after
                .map(|after| self.handle(document, after))
                .transpose()?;
            let size = (arg.width.unwrap_or(A4.0), arg.height.unwrap_or(A4.1));
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.insert_blank_pages(
                        document,
                        after,
                        arg.count,
                        size,
                        "Inserted pages".to_owned(),
                    )
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(description = "Adds a note comment on a page. Needs edit permission.")]
    async fn add_comment(&self, Parameters(arg): Parameters<CommentArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let page = self.handle(document, arg.page)?;
            let author = self.client_name(self.client()?);
            let new = NewAnnotation {
                kind: AnnotationKind::Note,
                rect: [arg.x, arg.y, arg.x + 24.0, arg.y + 24.0],
                points: Vec::new(),
                color: [1.0, 0.8, 0.2],
                stroke: 1.0,
                opacity: 1.0,
                contents: arg.text,
                author,
                font_size: 12.0,
                arrow: false,
                label: String::new(),
                meta: None,
                tilt: 0.0,
                icon: None,
                comb: None,
            };
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.add_annotation(document, page, new.clone(), "Added comment".to_owned())
                })
                .await?;
            Ok(json!({ "comment": done.handle, "step": done.revision.current }))
        };
        reply(edit.await)
    }

    #[tool(description = "Replies to a comment. Needs edit permission.")]
    async fn reply_to_comment(&self, Parameters(arg): Parameters<ReplyArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let author = self.client_name(self.client()?);
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.reply_to_annotation(
                        document,
                        arg.comment,
                        author.clone(),
                        arg.text.clone(),
                        "Replied".to_owned(),
                    )
                })
                .await?;
            Ok(json!({ "comment": done.handle, "step": done.revision.current }))
        };
        reply(edit.await)
    }

    #[tool(description = "Marks a comment's thread resolved or open. Needs edit permission.")]
    async fn set_comment_resolved(
        &self,
        Parameters(arg): Parameters<ResolveArg>,
    ) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let author = self.client_name(self.client()?);
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.set_annotation_resolved(
                        document,
                        arg.comment,
                        author.clone(),
                        arg.resolved,
                        "Resolved comment".to_owned(),
                    )
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(description = "Deletes a comment or other annotation. Needs edit permission.")]
    async fn delete_comment(&self, Parameters(arg): Parameters<HandleArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.delete_annotation(document, arg.id, "Deleted comment".to_owned())
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(
        description = "Flattens every comment and annotation into the page content. Needs edit permission."
    )]
    async fn flatten_comments(&self, Parameters(arg): Parameters<DocumentArg>) -> CallToolResult {
        let edit = async {
            let client = self.client()?;
            let document = DocumentId::from_raw(arg.document);
            let handles: Vec<u64> = self
                .engine
                .annotations(document)
                .await?
                .annotations
                .iter()
                .map(|annotation| annotation.handle)
                .collect();
            let engine = self.engine;
            let (job, _) = self
                .job(client, |sink| {
                    engine.flatten_annotations_job(
                        document,
                        handles,
                        None,
                        None,
                        "Flattened comments".to_owned(),
                        sink,
                    )
                })
                .await?;
            let done = self
                .change(document, || engine.apply_job_change(job))
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(
        description = "Adds a link to a web or e-mail address or a page. Needs edit permission."
    )]
    async fn add_link(&self, Parameters(arg): Parameters<LinkArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let page = self.handle(document, arg.page)?;
            let target = match (arg.url, arg.to_page) {
                (Some(url), None) => match url.strip_prefix("mailto:") {
                    Some(mail) => NewLinkDestination::Mail(mail.to_owned()),
                    None => NewLinkDestination::Web(url),
                },
                (None, Some(to)) => NewLinkDestination::Page(self.handle(document, to)?),
                _ => return Err(invalid("give either url or to_page")),
            };
            let new = NewLink {
                rect: arg.rect,
                quads: Vec::new(),
                target,
                look: LinkLook::Invisible,
                color: [0.0, 0.0, 1.0],
            };
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.add_link(document, page, new.clone(), "Added link".to_owned())
                })
                .await?;
            Ok(json!({ "link": done.handle, "step": done.revision.current }))
        };
        reply(edit.await)
    }

    #[tool(description = "Deletes a link. Needs edit permission.")]
    async fn delete_link(&self, Parameters(arg): Parameters<HandleArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.delete_link(document, arg.id, "Deleted link".to_owned())
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(description = "Fills a form field. Needs edit permission.")]
    async fn fill_field(&self, Parameters(arg): Parameters<FieldArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.set_field_value(
                        document,
                        arg.field,
                        arg.values.clone(),
                        None,
                        "Filled field".to_owned(),
                    )
                })
                .await?;
            Ok(json!({
                "step": done.revision.current,
                "problem": done.problem.map(|problem| format!("{problem:?}")),
                "fonts_added": done.fonts,
            }))
        };
        reply(edit.await)
    }

    #[tool(description = "Empties every form field. Needs edit permission.")]
    async fn clear_form(&self, Parameters(arg): Parameters<DocumentArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.clear_form(document, None, "Cleared form".to_owned())
                })
                .await?;
            Ok(revision(&done.revision))
        };
        reply(edit.await)
    }

    #[tool(description = "Sets the title, author, subject or keywords. Needs edit permission.")]
    async fn set_metadata(&self, Parameters(arg): Parameters<InfoArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let now = self.engine.document_now(document)?.info;
            let info = InfoEdit {
                title: arg.title.or(now.title).unwrap_or_default(),
                author: arg.author.or(now.author).unwrap_or_default(),
                subject: arg.subject.or(now.subject).unwrap_or_default(),
                keywords: arg.keywords.or(now.keywords).unwrap_or_default(),
            };
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.set_info(document, info.clone(), "Changed properties".to_owned())
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(description = "Replaces the document's bookmarks. Needs edit permission.")]
    async fn set_bookmarks(&self, Parameters(arg): Parameters<BookmarksArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let items = arg
                .bookmarks
                .into_iter()
                .map(|bookmark| {
                    let page = bookmark
                        .page
                        .checked_sub(1)
                        .and_then(|index| usize::try_from(index).ok())
                        .ok_or_else(|| invalid("no such page"))?;
                    Ok(OutlineEdit {
                        item: None,
                        page: Some(page),
                        title: bookmark.title,
                        depth: bookmark.depth,
                        open: true,
                    })
                })
                .collect::<Result<Vec<_>, ApiError>>()?;
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.set_outline(document, items.clone(), "Changed bookmarks".to_owned())
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(
        description = "Attaches a file to the document; the user allows reading it. Needs edit permission."
    )]
    async fn attach_file(&self, Parameters(arg): Parameters<PathArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            if !arg.path.is_absolute() {
                return Err(invalid("the path must be absolute"));
            }
            let file_name = arg
                .path
                .file_name()
                .map(|name| name.to_string_lossy().into_owned())
                .ok_or_else(|| invalid("the path names no file"))?;
            self.allowed(
                Some(document),
                ClientRequestKind::ReadFile(arg.path.clone()),
            )
            .await?;
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.attach_file(
                        document,
                        arg.path.clone(),
                        file_name.clone(),
                        "Attached file".to_owned(),
                    )
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(
        description = "Removes an attachment, by its id from document_info. Needs edit permission."
    )]
    async fn remove_attachment(&self, Parameters(arg): Parameters<HandleArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let index = u32::try_from(arg.id).map_err(|_| invalid("no such attachment"))?;
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.remove_attachment(document, index, "Removed attachment".to_owned())
                })
                .await?;
            Ok(revision(&done))
        };
        reply(edit.await)
    }

    #[tool(
        description = "Writes a smaller copy of the document to a new file; the user allows the path. Needs edit permission."
    )]
    async fn compress(&self, Parameters(arg): Parameters<CompressArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let preset = match arg.preset.as_str() {
                "high_quality" => Preset::HighQuality,
                "balanced" => Preset::Balanced,
                "smallest" => Preset::Smallest,
                _ => return Err(invalid("the preset is high_quality, balanced or smallest")),
            };
            // The copy drops the signatures; the signed original stays (decision 25).
            let unsign = self.engine.would_break_signatures(document).await?;
            if unsign {
                self.allowed(Some(document), ClientRequestKind::EditSigned)
                    .await?;
            }
            let engine = self.engine;
            let output = arg.output.clone();
            self.write_job(Some(document), arg.output, |sink| {
                engine.compress_job(document, preset, unsign, output, None, sink)
            })
            .await
        };
        reply(edit.await)
    }

    #[tool(
        description = "Writes pages to a new file; the user allows the path. Needs edit permission."
    )]
    async fn extract_pages(&self, Parameters(arg): Parameters<ExtractArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let pages = self.handles(document, &arg.pages)?;
            let engine = self.engine;
            let output = arg.output.clone();
            self.write_job(Some(document), arg.output, |sink| {
                engine.extract_pages_job(document, pages, output, None, sink)
            })
            .await
        };
        reply(edit.await)
    }

    #[tool(
        description = "Splits the document into new files in a folder; the user allows the folder. Needs edit permission."
    )]
    async fn split_document(&self, Parameters(arg): Parameters<SplitArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let files = arg
                .parts
                .into_iter()
                .map(|part| SplitOutput {
                    name: part.name,
                    first: part.first.saturating_sub(1),
                    last: part.last.saturating_sub(1),
                })
                .collect();
            let engine = self.engine;
            let folder = arg.folder.clone();
            self.write_job(Some(document), arg.folder, |sink| {
                engine.split_job(document, files, folder, None, sink)
            })
            .await
        };
        reply(edit.await)
    }

    #[tool(
        description = "Combines PDF files into a new file; the user allows the path. Needs edit permission."
    )]
    async fn combine_files(&self, Parameters(arg): Parameters<CombineArg>) -> CallToolResult {
        let edit = async {
            let files = arg
                .files
                .into_iter()
                .map(|path| CombineFile {
                    source: CombineSource::File {
                        path,
                        password: None,
                        pages: None,
                    },
                    bookmark: None,
                })
                .collect();
            let engine = self.engine;
            let output = arg.output.clone();
            self.write_job(None, arg.output, |sink| {
                engine.combine_job(files, true, Paper::A4, output, None, sink)
            })
            .await
        };
        reply(edit.await)
    }

    #[tool(
        description = "Places a simple signature, the name in a handwriting style; the user allows it. Needs edit permission."
    )]
    async fn add_signature(&self, Parameters(arg): Parameters<SignArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            let page = self.handle(document, arg.page)?;
            self.allowed(Some(document), ClientRequestKind::Sign)
                .await?;
            let family = self
                .engine
                .handwriting_styles(arg.name.clone())
                .await?
                .into_iter()
                .find_map(|(family, covered)| covered.then_some(family))
                .ok_or_else(|| {
                    ApiError::new(ErrorKind::Unsupported, MessageKey::INTERNAL)
                        .with_details("no handwriting style draws this name")
                })?;
            let signature = NewSignature {
                rect: arg.rect,
                ink: Ink::Typed {
                    text: arg.name.clone(),
                    family,
                },
                color: [0.0, 0.0, 0.0],
                tilt: 0.0,
                initials: false,
                field: arg.field,
                author: arg.name,
            };
            let engine = self.engine;
            let done = self
                .change(document, || {
                    engine.add_signature(document, page, signature.clone(), "Signed".to_owned())
                })
                .await?;
            Ok(json!({ "signature": done.handle, "step": done.revision.current }))
        };
        reply(edit.await)
    }

    #[tool(
        description = "Saves the document over its file: Ferman asks the user and saves in its own way. Needs edit permission."
    )]
    async fn save(&self, Parameters(arg): Parameters<DocumentArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            self.allowed(Some(document), ClientRequestKind::Save)
                .await?;
            Ok(json!({ "saved": true }))
        };
        reply(edit.await)
    }

    #[tool(
        description = "Restores a saved version over the document's file: Ferman asks the user and restores it. Needs edit permission."
    )]
    async fn restore_version(&self, Parameters(arg): Parameters<VersionArg>) -> CallToolResult {
        let edit = async {
            let document = DocumentId::from_raw(arg.document);
            self.allowed(
                Some(document),
                ClientRequestKind::RestoreVersion(arg.version),
            )
            .await?;
            Ok(json!({ "restored": true }))
        };
        reply(edit.await)
    }
}
