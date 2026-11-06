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

use ferman_core::structure::FontUse;
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
    /// Its language tag, else the document's.
    pub language: Option<String>,
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

/// What Properties says about a font beyond its status (a2-7, FmDocPanel, B122).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FontCoverage {
    /// Its `/BaseFont`, a subset's tag included.
    pub name: String,
    /// The family PDFium draws a font that is not embedded in, when it is another font.
    pub shown_as: Option<String>,
    /// For a subset, the letters asked about that an edit cannot draw in it.
    pub missing_letters: String,
}

/// The pages [`Engine::font_coverage`] reads for each of its two answers. A font first used
/// beyond them has no answer, so a document whose every page has its own font stays quick.
const COVERAGE_PAGES: usize = 16;

/// Whether `family`, which PDFium reports, is the font named `name`: "Times New Roman" is
/// `TimesNewRomanPSMT`, "Arial" is `Arial,Bold`.
fn same_face(family: &str, name: &str) -> bool {
    let plain = |text: &str| -> String {
        text.chars()
            .filter(char::is_ascii_alphanumeric)
            .map(|c| c.to_ascii_lowercase())
            .collect()
    };
    plain(name).starts_with(&plain(family))
}

/// Whether `name` carries a subset's tag: six capital letters and `+`.
fn is_subset(name: &str) -> bool {
    name.split_once('+')
        .is_some_and(|(tag, _)| tag.len() == 6 && tag.bytes().all(|b| b.is_ascii_uppercase()))
}

/// The first page each of `fonts` that is `wanted` is used on, at most [`COVERAGE_PAGES`].
fn first_pages(fonts: &[FontUse], wanted: impl Fn(&FontUse) -> bool) -> Vec<u32> {
    let mut pages: Vec<u32> = fonts
        .iter()
        .filter(|font| wanted(font))
        .filter_map(|font| font.pages.first().copied())
        .collect();
    pages.sort_unstable();
    pages.dedup();
    pages.truncate(COVERAGE_PAGES);
    pages
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

    /// What the fonts of `document` need said beyond their status, from the first page each is
    /// used on: the family PDFium draws a font that is not embedded in, and which of `letters` a
    /// subset cannot draw in an edit. A font with nothing to say has no entry.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open, or `Internal` when its thread cannot
    /// start or the render thread has stopped.
    pub async fn font_coverage(
        &self,
        document: DocumentId,
        letters: String,
    ) -> Result<Vec<FontCoverage>, ApiError> {
        guard_async(async move {
            let model = self
                .models()?
                .get(&document)
                .cloned()
                .ok_or_else(|| ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL))?;
            let fonts = &model.document.structure().fonts;
            // The fonts' pages are the file's; PDFium has the pages as the revisions left them.
            let store = Arc::clone(&model.revised().store);
            let pages: Vec<u32> = first_pages(fonts, |font| !font.embedded)
                .into_iter()
                .filter_map(|page| {
                    let page = model
                        .document
                        .structure()
                        .pages
                        .get(usize::try_from(page).ok()?)?;
                    u32::try_from(store.page_index(&model.document, page.handle())?).ok()
                })
                .collect();
            let drawn = if pages.is_empty() {
                Vec::new()
            } else {
                self.render()?.page_fonts(document, pages).await?
            };
            let mut coverage: Vec<FontCoverage> = fonts
                .iter()
                .filter(|font| !font.embedded)
                .filter_map(|font| {
                    let (_, family) = drawn.iter().find(|(name, _)| *name == font.name)?;
                    let family = family.trim();
                    (!family.is_empty() && !same_face(family, &font.name)).then(|| FontCoverage {
                        name: font.name.clone(),
                        shown_as: Some(family.to_owned()),
                        missing_letters: String::new(),
                    })
                })
                .collect();

            let pages = first_pages(fonts, |font| font.embedded && is_subset(&font.name));
            let shared = Arc::clone(&model);
            let (reply, receiver) = futures_channel::oneshot::channel();
            thread::Builder::new()
                .name("ferman-text".to_owned())
                .stack_size(LAYOUT_STACK)
                .spawn(move || {
                    let result = guard(AssertUnwindSafe(|| {
                        let mut subsets: Vec<(String, String)> = Vec::new();
                        for page in pages {
                            let Ok(index) = usize::try_from(page) else {
                                continue;
                            };
                            // A page a limit stops leaves its fonts without an answer.
                            let Ok(found) =
                                ferman_text::missing_letters(&shared.document, index, &letters)
                            else {
                                continue;
                            };
                            for font in found {
                                if is_subset(&font.0)
                                    && !subsets.iter().any(|(name, _)| *name == font.0)
                                {
                                    subsets.push(font);
                                }
                            }
                        }
                        Ok::<_, ApiError>(subsets)
                    }));
                    let _ = reply.send(result);
                })
                .map_err(|_| ApiError::internal("cannot start the text thread"))?;
            let subsets = receiver
                .await
                .map_err(|_canceled| ApiError::internal("the text thread stopped"))??;
            coverage.extend(
                subsets
                    .into_iter()
                    .filter(|(_, missing)| !missing.is_empty())
                    .map(|(name, missing_letters)| FontCoverage {
                        name,
                        shown_as: None,
                        missing_letters,
                    }),
            );
            Ok(coverage)
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
        let (store, generation) = {
            let revised = model.revised();
            (Arc::clone(&revised.store), revised.generation)
        };
        let found = usize::try_from(page).ok().and_then(|index| {
            let handle = store.pages(&model.document).get(index)?.handle();
            Some((index, handle))
        });
        let (index, handle) = found.ok_or_else(|| {
            ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                .with_details("no such page")
        })?;
        {
            let revised = model.revised();
            if revised.generation == generation
                && let Some(text) = revised.blocks.get(&handle)
            {
                return Ok((Arc::clone(&model), Arc::clone(text)));
            }
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
                    if revised.generation == generation {
                        revised.blocks.insert(handle, Arc::clone(&text));
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
                language: block
                    .language
                    .clone()
                    .or_else(|| model.document.structure().language.clone()),
            })
            .collect(),
        empty: text.empty,
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn a_family_of_the_same_name_is_no_substitute() {
        assert!(super::same_face("Times New Roman", "TimesNewRomanPSMT"));
        assert!(super::same_face("Arial", "Arial,Bold"));
        assert!(!super::same_face("Helvetica Neue", "Helvetica"));
        assert!(!super::same_face("Arial", "Helvetica"));
    }
}
