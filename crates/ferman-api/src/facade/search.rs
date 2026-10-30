//! Searching a document's text (a2-4a to a2-4d, docs/ARCHITECTURE.md §5.4): each search is a job
//! on a thread of its own that reads the pages in order, streams each page's matches as it finds
//! them with its progress, and stops when cancelled. A page's text is kept once read, so the next
//! search on the document reads no content stream again.
//!
//! Matching is ferman-text's ([`SearchOptions`]); the engine adds the document's language, so
//! Turkish case folding applies to a Turkish document when accents count. A match comes back as
//! one rectangle per line it covers, in displayed points, with its line as the snippet.

use std::ops::Range;
use std::panic::AssertUnwindSafe;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, PoisonError};
use std::thread;

use ferman_render::DocumentId;
use ferman_text::SearchOptions;
use ferman_text::extract::{CharBox, PageText};

use super::document::Model;
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::guard;

/// The stack of a search thread: the interpreter recurses into nested objects, bounded by the
/// limits, as the open thread does.
const SEARCH_STACK: usize = 64 * 1024 * 1024;

/// How many pages pass between two progress events.
const PROGRESS_EVERY: u32 = 25;

/// A running search. Never reused within a process.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct SearchId(u64);

impl SearchId {
    /// The number behind the id.
    #[must_use]
    pub fn get(self) -> u64 {
        self.0
    }

    /// The id behind a number from [`get`](Self::get), as a handle that crossed the bridge.
    #[must_use]
    pub fn from_raw(raw: u64) -> Self {
        Self(raw)
    }
}

/// One match.
#[derive(Debug, Clone, PartialEq)]
pub struct SearchMatch {
    /// Its page, from 0.
    pub page: u32,
    /// One rectangle per line it covers, `[left, top, right, bottom]` in displayed points.
    pub rects: Vec<CharBox>,
    /// The line it starts on, for the sidebar's snippet (a2-3e).
    pub snippet: String,
    /// Where it is in the snippet, in characters.
    pub snippet_range: Range<u32>,
}

/// What a search reports, in order: `Started`, then `Matches` and `Progress` as pages are read,
/// then `Done`.
#[derive(Debug, Clone, PartialEq)]
pub enum SearchEvent {
    /// The search runs; its handle cancels it.
    Started(SearchId),
    /// The matches of one page.
    Matches(Vec<SearchMatch>),
    /// Pages read so far, of all of them (a2-4c: "Searching · page 840 of 2,400").
    Progress {
        /// Pages read.
        searched: u32,
        /// Pages in the document.
        pages: u32,
    },
    /// The search ended, all pages read or cancelled.
    Done {
        /// Whether it was cancelled.
        cancelled: bool,
    },
}

/// Receives a search's events on its thread; returns false when nobody listens any more, which
/// stops the search.
pub trait SearchSink: Send {
    /// Delivers one event.
    fn deliver(&mut self, event: SearchEvent) -> bool;
}

impl Engine {
    /// Searches `document` for `query` with `options` on a thread of its own; `sink` receives
    /// `Started` before any match.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open, or `Internal` when the thread does
    /// not start.
    pub fn search(
        &self,
        document: DocumentId,
        query: String,
        mut options: SearchOptions,
        mut sink: Box<dyn SearchSink>,
    ) -> Result<SearchId, ApiError> {
        // The state a panic could leave is the searches' map, whose lock is taken as it is.
        guard(AssertUnwindSafe(|| {
            let model = self
                .models()?
                .get(&document)
                .cloned()
                .ok_or_else(|| ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL))?;
            let language = model.document.structure().language.as_deref().unwrap_or("");
            options.turkish = ["tr", "az"].iter().any(|code| {
                language
                    .get(..2)
                    .is_some_and(|start| start.eq_ignore_ascii_case(code))
            });
            static NEXT: AtomicU64 = AtomicU64::new(1);
            let id = SearchId(NEXT.fetch_add(1, Ordering::Relaxed));
            let cancel = Arc::new(AtomicBool::new(false));
            {
                let mut searches = self.searches.lock().unwrap_or_else(PoisonError::into_inner);
                // A finished search's thread has let its flag go.
                searches.retain(|_, flag| Arc::strong_count(flag) > 1);
                searches.insert(id, Arc::clone(&cancel));
            }
            if !sink.deliver(SearchEvent::Started(id)) {
                return Ok(id);
            }
            thread::Builder::new()
                .name("ferman-search".to_owned())
                .stack_size(SEARCH_STACK)
                .spawn(move || {
                    // A panic ends the search; the sink is dropped and the stream ends.
                    let _ = guard(AssertUnwindSafe(|| {
                        run(&model, &query, &options, &cancel, sink.as_mut());
                        Ok(())
                    }));
                })
                .map_err(|_| ApiError::internal("cannot start the search thread"))?;
            Ok(id)
        }))
    }

    /// Cancels a search; it ends with `Done { cancelled: true }`. A search that ended already
    /// ignores it.
    pub fn cancel_search(&self, search: SearchId) {
        let searches = self.searches.lock().unwrap_or_else(PoisonError::into_inner);
        if let Some(flag) = searches.get(&search) {
            flag.store(true, Ordering::Relaxed);
        }
    }
}

/// The search itself.
fn run(
    model: &Model,
    query: &str,
    options: &SearchOptions,
    cancel: &AtomicBool,
    sink: &mut dyn SearchSink,
) {
    let pages = u32::try_from(model.document.page_count()).unwrap_or(u32::MAX);
    for page in 0..pages {
        if cancel.load(Ordering::Relaxed) {
            sink.deliver(SearchEvent::Done { cancelled: true });
            return;
        }
        let text = page_text(model, page);
        let matches: Vec<SearchMatch> = ferman_text::find(&text.text, query, options)
            .into_iter()
            .map(|range| found(page, &text, range))
            .collect();
        if !matches.is_empty() && !sink.deliver(SearchEvent::Matches(matches)) {
            return;
        }
        let searched = page.saturating_add(1);
        if (searched % PROGRESS_EVERY == 0 || searched == pages)
            && !sink.deliver(SearchEvent::Progress { searched, pages })
        {
            return;
        }
    }
    sink.deliver(SearchEvent::Done { cancelled: false });
}

/// The text of `page`, read once; a page whose content cannot be read has none.
fn page_text(model: &Model, page: u32) -> Arc<PageText> {
    let index = usize::try_from(page).unwrap_or(usize::MAX);
    let cached = model
        .pages
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
        .get(index)
        .cloned()
        .flatten();
    if let Some(text) = cached {
        return text;
    }
    let text = Arc::new(
        ferman_text::extract::page_layout(&model.document, index).unwrap_or_else(|err| {
            tracing::warn!(page, error = %err, "a page's text could not be read");
            PageText::default()
        }),
    );
    if let Some(slot) = model
        .pages
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
        .get_mut(index)
    {
        *slot = Some(Arc::clone(&text));
    }
    text
}

/// A match of `range`'s characters on `page`: a rectangle per line, and its first line.
fn found(page: u32, text: &PageText, range: Range<usize>) -> SearchMatch {
    let chars: Vec<char> = text.text.chars().collect();
    let mut rects: Vec<CharBox> = Vec::new();
    let mut open = false;
    for at in range.clone() {
        match text.boxes.get(at).copied().flatten() {
            Some([left, top, right, bottom]) => match rects.last_mut() {
                Some(rect) if open => {
                    *rect = [
                        rect[0].min(left),
                        rect[1].min(top),
                        rect[2].max(right),
                        rect[3].max(bottom),
                    ];
                }
                _ => {
                    rects.push([left, top, right, bottom]);
                    open = true;
                }
            },
            None if chars.get(at) == Some(&'\n') => open = false,
            None => {}
        }
    }
    let line_start = chars
        .get(..range.start)
        .and_then(|before| before.iter().rposition(|&c| c == '\n'))
        .map_or(0, |at| at.saturating_add(1));
    let line_end = chars
        .get(range.start..)
        .and_then(|after| after.iter().position(|&c| c == '\n'))
        .map_or(chars.len(), |at| at.saturating_add(range.start));
    let snippet: String = chars
        .get(line_start..line_end)
        .unwrap_or_default()
        .iter()
        .collect();
    let offset = |at: usize| u32::try_from(at.saturating_sub(line_start)).unwrap_or(u32::MAX);
    SearchMatch {
        page,
        rects,
        snippet,
        snippet_range: offset(range.start)..offset(range.end.min(line_end)),
    }
}
