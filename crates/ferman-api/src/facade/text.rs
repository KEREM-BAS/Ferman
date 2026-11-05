//! A page's text blocks, hit testing and selection (docs/ARCHITECTURE.md §3.5 and §6.12).
//!
//! [`Engine::text_blocks`] lays out a page with ferman-text on a thread of its own and keeps the
//! result with the document until it closes, so the caret and selection calls that follow read no
//! content stream again. The UI hit-tests the block frames itself for hover (a3-1a) and asks the
//! engine only for caret positions inside a block ([`Engine::caret_at`]) and for what a drag
//! selects ([`Engine::selection`]). Geometry is in page space: points from the top-left of the
//! displayed page, y down.
//!
//! Editability carries the document's reasons too: a repaired document, or one whose parsers
//! disagree, is [`NotEditableReason::Damaged`]; an XFA-only form is
//! [`NotEditableReason::ReadOnly`]; a document whose author's restrictions apply is
//! [`NotEditableReason::Restricted`] until the owner password unlocks it.

use std::panic::AssertUnwindSafe;
use std::sync::Arc;
use std::thread;

use ferman_render::DocumentId;
use ferman_text::extract::CharBox;
use ferman_text::{
    Alignment, BlockId, EditContext, Editability, NotEditableReason, PageText, TextDirection,
};

use super::document::Model;
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};

/// The stack of a layout thread: the interpreter recurses into nested objects, bounded by the
/// limits, as the open thread does.
const LAYOUT_STACK: usize = 64 * 1024 * 1024;

/// A page's text blocks.
#[derive(Debug, Clone, PartialEq)]
pub struct PageBlocks {
    /// Its blocks in reading order.
    pub blocks: Vec<BlockInfo>,
    /// Why a page without blocks has no text to edit: [`NotEditableReason::ImageOnly`] for a scan
    /// (a3-11) or [`NotEditableReason::OutlinedText`] for shapes only (a3-19).
    pub empty: Option<NotEditableReason>,
}

/// One block (paragraph frame) of a page.
#[derive(Debug, Clone, PartialEq)]
pub struct BlockInfo {
    /// Its id, the same for the same content.
    pub id: BlockId,
    /// Its frame, `[left, top, right, bottom]` in page space.
    pub frame: CharBox,
    /// Its lines, from the first.
    pub lines: Vec<LineInfo>,
    /// How its lines sit in the frame.
    pub alignment: Alignment,
    /// The direction its text runs in.
    pub direction: TextDirection,
    /// Whether it can be edited, and why not.
    pub editability: Editability,
}

/// One line of a block.
#[derive(Debug, Clone, PartialEq)]
pub struct LineInfo {
    /// Its text in logical order.
    pub text: String,
    /// The box of its glyphs.
    pub bbox: CharBox,
    /// Its baseline from start to end, in visual order.
    pub baseline: [[f32; 2]; 2],
}

/// A caret in a block.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Caret {
    /// Its index in the block's text (the lines joined by line feeds), in characters.
    pub index: u32,
    /// Its box, of no width across its line (no height in a vertical line).
    pub rect: CharBox,
}

/// A place in a page's text: a caret index in one block.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TextPosition {
    /// The block.
    pub block: BlockId,
    /// The caret index in its text.
    pub index: u32,
}

/// What a selection covers.
#[derive(Debug, Clone, PartialEq)]
pub struct Selection {
    /// The boxes to highlight, in page space.
    pub quads: Vec<CharBox>,
    /// Its text for copying: blocks and lines separated by line feeds.
    pub text: String,
}

impl Engine {
    /// The text blocks of `page` of `document`, laid out on a thread of its own the first time.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open, `InvalidInput` for a page it does not
    /// have, or `Internal` when the page's content cannot be read.
    pub async fn text_blocks(
        &self,
        document: DocumentId,
        page: u32,
    ) -> Result<PageBlocks, ApiError> {
        guard_async(async move {
            let (model, text) = self.page_blocks(document, page).await?;
            Ok(page_blocks_info(&model, &text))
        })
        .await
    }

    /// The caret in `block` of `page` nearest `point` (page space).
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open or a block the page does not have,
    /// `InvalidInput` for a page the document does not have.
    pub async fn caret_at(
        &self,
        document: DocumentId,
        page: u32,
        block: BlockId,
        point: [f32; 2],
    ) -> Result<Caret, ApiError> {
        guard_async(async move {
            let (_, text) = self.page_blocks(document, page).await?;
            let found = find_block(&text, block)?.1;
            let index = found.hit(point);
            let rect = found
                .caret_rect(index)
                .ok_or_else(|| ApiError::internal("a hit outside its block"))?;
            Ok(Caret {
                index: u32::try_from(index).unwrap_or(u32::MAX),
                rect,
            })
        })
        .await
    }

    /// What a selection from `anchor` to `focus` on `page` covers: the rest of the first block in
    /// reading order, every block between and the start of the last. Either end may come first.
    ///
    /// # Errors
    ///
    /// As [`caret_at`](Self::caret_at).
    pub async fn selection(
        &self,
        document: DocumentId,
        page: u32,
        anchor: TextPosition,
        focus: TextPosition,
    ) -> Result<Selection, ApiError> {
        guard_async(async move {
            let (_, text) = self.page_blocks(document, page).await?;
            let at = |position: TextPosition| -> Result<(usize, usize), ApiError> {
                let (order, _) = find_block(&text, position.block)?;
                Ok((order, usize::try_from(position.index).unwrap_or(usize::MAX)))
            };
            let (from, to) = {
                let (a, b) = (at(anchor)?, at(focus)?);
                if a <= b { (a, b) } else { (b, a) }
            };
            let mut quads = Vec::new();
            let mut parts = Vec::new();
            for (order, block) in text
                .blocks
                .iter()
                .enumerate()
                .take(to.0.saturating_add(1))
                .skip(from.0)
            {
                let start = if order == from.0 { from.1 } else { 0 };
                let end = if order == to.0 { to.1 } else { usize::MAX };
                quads.extend(block.selection_quads(start..end));
                parts.push(block.selected_text(start..end));
            }
            Ok(Selection {
                quads,
                text: parts.join("\n"),
            })
        })
        .await
    }

    /// The document's model and the text model of `page`, laid out once and kept with it.
    async fn page_blocks(
        &self,
        document: DocumentId,
        page: u32,
    ) -> Result<(Arc<Model>, Arc<PageText>), ApiError> {
        let model = self
            .models()?
            .get(&document)
            .cloned()
            .ok_or_else(|| ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL))?;
        let index = usize::try_from(page)
            .ok()
            .filter(|&index| index < model.document.page_count())
            .ok_or_else(|| {
                ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                    .with_details("no such page")
            })?;
        let (cached, store, generation) = {
            let revised = model.revised();
            let cached = revised.blocks.get(index).cloned().flatten();
            (cached, Arc::clone(&revised.store), revised.generation)
        };
        if let Some(text) = cached {
            return Ok((model, text));
        }
        let shared = Arc::clone(&model);
        let (reply, receiver) = futures_channel::oneshot::channel();
        thread::Builder::new()
            .name("ferman-text".to_owned())
            .stack_size(LAYOUT_STACK)
            .spawn(move || {
                // The layout reads the shared model and its snapshot; only its cache slot changes,
                // and only while the snapshot is still the newest.
                let result = guard(AssertUnwindSafe(|| {
                    let context = EditContext {
                        document: shared.read_only,
                        ..EditContext::default()
                    };
                    let text = Arc::new(ferman_text::text_page_revised(
                        &shared.document,
                        &store,
                        index,
                        &context,
                    )?);
                    let mut revised = shared.revised();
                    let newest = revised.generation == generation;
                    if let Some(slot) = revised.blocks.get_mut(index).filter(|_| newest) {
                        *slot = Some(Arc::clone(&text));
                    }
                    Ok(text)
                }));
                let _ = reply.send(result);
            })
            .map_err(|_| ApiError::internal("cannot start the text thread"))?;
        let text = receiver
            .await
            .map_err(|_canceled| ApiError::internal("the text thread stopped"))??;
        Ok((model, text))
    }
}

/// `block`'s place in reading order and the block, or `NotFound`.
fn find_block(
    text: &PageText,
    block: BlockId,
) -> Result<(usize, &ferman_text::TextBlock), ApiError> {
    text.blocks
        .iter()
        .enumerate()
        .find(|(_, candidate)| candidate.id == block)
        .ok_or_else(|| {
            ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL).with_details("no such block")
        })
}

/// `text` as the API gives it, with the author's restrictions of `model` applied.
pub(super) fn page_blocks_info(model: &Model, text: &PageText) -> PageBlocks {
    let restricted = model.read_only.is_none()
        && model
            .security()
            .is_some_and(|security| security.restricted());
    PageBlocks {
        blocks: text
            .blocks
            .iter()
            .map(|block| BlockInfo {
                id: block.id,
                frame: block.bbox,
                lines: block
                    .lines
                    .iter()
                    .map(|line| LineInfo {
                        text: line.text.clone(),
                        bbox: line.bbox,
                        baseline: line.baseline,
                    })
                    .collect(),
                alignment: block.alignment,
                direction: block.direction,
                editability: if restricted {
                    Editability::NotEditable(NotEditableReason::Restricted)
                } else {
                    block.editability
                },
            })
            .collect(),
        empty: text.empty,
    }
}
