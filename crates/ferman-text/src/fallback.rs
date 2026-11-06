//! Missing glyphs, steps 2 and 3 (docs/ARCHITECTURE.md §6.7, ADR 0006, G36, G37): characters no
//! font of their line draws, even through `/Differences` (step 1, in [`rewrite`](crate::rewrite)),
//! get glyphs from another font, embedded as a new Type0 font used only by them.
//!
//! - **Step 2.** The same font as the document's ([`find_same_font`]: PostScript name, then
//!   family and style, confirmed by the units per em and the PDF's widths) among the installed
//!   and bundled fonts of [`FontSources::library`]. Its glyphs are subset and embedded, and the
//!   rewrite carries a [`Substitution`] of kind [`SubstitutionKind::SameFont`], which the UI says
//!   once (a3-17). A font whose `fsType` forbids new text is skipped with the reason
//!   ([`MissingReason::NotEmbeddable`], E05).
//! - **Step 3.** Otherwise the [`MissingGlyphs`] with ranked [`FontCandidate`]s from the fonts
//!   embedded in the page, the installed and the bundled ones ([`rank_similar`]): coverage of the
//!   missing characters first, then metric similarity, of the original's slant and weight class
//!   only, so bold and italic are never faked. Nothing is substituted silently: with
//!   [`FontSources::ask`] the text is not applied until the caller chooses
//!   ([`FontChoice`]); without it the closest candidate (the first one whose licence allows a
//!   subset and that covers every character) draws the characters provisionally and the
//!   rewrite carries the [`MissingGlyphs`] as [`Rewrite::pending`](crate::Rewrite::pending), so
//!   the caller can still choose, or keep it ([`FontChoice::KeepAsIs`]). With
//!   [`FontSources::mark`] the characters stay in their own font instead, with a code that draws
//!   no glyph and reads back as the character, and the rewrite says so with a [`Substitution`] of
//!   kind [`SubstitutionKind::Marked`], so nothing waits for a choice and no font is embedded.
//!
//! **Scope.** The substitute draws only the missing characters (the a3-3b scope "Missing
//! characters only"); every other character keeps its font. "Whole block" is not offered yet.
//! A substitute must cover every missing character it is asked for; a partial candidate is listed
//! with its coverage but not used.
//! Shaped text is the exception where a font has no usable copy: all its text in the block goes to
//! the similar font ([`similar_shaper`]), because a glyph kept in the subset cannot be shaped or
//! joined to a new one.
//!
//! **Fonts restricted by `fsType`** (Q09): when the document's own program allows at most preview
//! and print, its glyphs are not reused for new text, and the reason says so
//! ([`MissingReason::Restricted`]).
// Font data and the PDF's widths come from files (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::HashMap;

use ferman_core::revision::{EmbeddedFont, EmbeddedProgram};
use ferman_fonts::{
    Candidate, Coverage, Direction, Embedding, FaceId, FaceInfo, FaceInstance, FontLibrary,
    FontOrigin, FontProgram, GlyphId, SameFont, SameFontQuery, ShapeRequest, ShapingFont,
    SimilarQuery, StyleMetrics, SubsetProgram, find_same_font, rank_similar, strip_subset_tag,
    subset_at, with_text,
};

use crate::extract::{Glyph, PdfFont, single};
use crate::style::BlockFont;

/// The most candidates step 3 lists.
pub const MAX_CANDIDATES: usize = 12;

/// The Turkish letters each candidate's preview shows, as far as it covers them (a3-3b).
pub const PREVIEW: &str = "Ğğ İı Şş Çç Öö Üü";

/// Where missing glyphs may come from, and what the caller decided for step 3.
#[derive(Debug, Clone, Copy, Default)]
pub struct FontSources<'a> {
    /// The installed and bundled fonts for steps 2 and 3; `None` looks nowhere but the page.
    pub library: Option<&'a FontLibrary>,
    /// "Ask each time" (a11-1c): step 3 stops at the choice instead of drawing the closest
    /// candidate provisionally.
    pub ask: bool,
    /// "Keep the original font and mark the character" (a11-1c): step 3 keeps the characters in
    /// their font without a glyph. A [`choice`](Self::choice) goes first.
    pub mark: bool,
    /// Reflow while typing turned off (a11-1c): only a line feed ends a line, so a line longer
    /// than the frame runs past it instead of wrapping.
    pub keep_lines: bool,
    /// The caller's step 3 choice.
    pub choice: Option<&'a FontChoice>,
}

/// The caller's choice for the characters step 3 draws.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FontChoice {
    /// The candidate with this origin and PostScript name ("Choose a font…", a3-3b).
    Font {
        /// Its group.
        origin: FontOrigin,
        /// Its PostScript name.
        postscript_name: String,
    },
    /// "Keep as is": the closest candidate, the one drawn provisionally.
    KeepAsIs,
}

/// Characters that need step 3, and what it offers.
#[derive(Debug, Clone, PartialEq)]
pub struct MissingGlyphs {
    /// Each missing character with its byte offset in the new text, in text order.
    pub chars: Vec<(char, usize)>,
    /// The font they are missing from: its PostScript name, the subset tag removed.
    pub font: String,
    /// Why step 2 did not draw them.
    pub reason: MissingReason,
    /// Whether the font is bold, so only bold candidates are offered.
    pub bold: bool,
    /// Whether it is italic, so only italic candidates are offered.
    pub italic: bool,
    /// The candidates, best first; empty when no font of the original's style covers any of
    /// the characters.
    pub candidates: Vec<FontCandidate>,
}

/// Why step 2 did not draw the missing characters.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MissingReason {
    /// The same font is neither installed nor bundled (or it lacks the characters).
    NotInstalled,
    /// The same font is installed, but its `fsType` forbids new text (E05).
    NotEmbeddable {
        /// Its PostScript name.
        font: String,
        /// Its permission.
        embedding: Embedding,
    },
    /// The document's own program allows at most preview and print, so its glyphs are not
    /// reused for new text (Q09).
    Restricted {
        /// Its permission.
        embedding: Embedding,
    },
}

/// A font step 3 offers.
#[derive(Debug, Clone, PartialEq)]
pub struct FontCandidate {
    /// Its group in the a3-3b picker.
    pub origin: FontOrigin,
    /// Its PostScript name, which a [`FontChoice::Font`] gives back.
    pub postscript_name: String,
    /// Its family.
    pub family: String,
    /// How many of the missing characters it covers.
    pub coverage: Coverage,
    /// How close its metrics are to the original's, 0 to 1.
    pub similarity: f32,
    /// Its permission; one that does not allow a subset is listed with it and never used.
    pub embedding: Embedding,
    /// The letters of [`PREVIEW`] it covers, pairs it has none of left out.
    pub preview: String,
}

impl FontCandidate {
    /// Whether it can draw every missing character as a subset.
    #[must_use]
    pub fn usable(&self) -> bool {
        self.coverage.is_full() && self.embedding.allows_subset()
    }
}

/// Which step drew substituted characters.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SubstitutionKind {
    /// Step 2: the same font, installed or bundled.
    SameFont,
    /// Step 3: a similar font.
    Similar,
    /// Step 3's "Keep the original font and mark the character": no other font, and no glyph.
    /// [`Substitution::to`] is the document's font.
    Marked,
}

/// Characters an edit draws in another font than their line's: what the review list (a3-12) and
/// the "Font substituted" toast (a11-6) show.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Substitution {
    /// The step.
    pub kind: SubstitutionKind,
    /// The characters, each once, in text order.
    pub chars: String,
    /// The document's font, its PostScript name without the subset tag.
    pub from: String,
    /// The font they are drawn in, its PostScript name.
    pub to: String,
    /// Where that font came from.
    pub origin: FontOrigin,
}

/// A character no font of its line draws.
#[derive(Debug, Clone)]
pub(crate) struct Miss {
    pub(crate) c: char,
    /// Its byte offset in the new text.
    pub(crate) at: usize,
    /// The font it would have been in (the one before it, else after it), and that font's
    /// name in the resources.
    pub(crate) font: u64,
    pub(crate) name: Vec<u8>,
}

/// A new font the rewrite sets substituted characters in.
#[derive(Debug, Clone)]
pub(crate) struct Substitute {
    pub(crate) key: u64,
    /// The font whose characters it draws, whose size it is set at.
    pub(crate) base: u64,
    pub(crate) name: Vec<u8>,
    /// Its characters: code bytes and advance per unit of font size.
    pub(crate) glyphs: Vec<(char, Vec<u8>, f32)>,
    /// Whether it is a font of the page ([`PageFont`]), which encodes the characters with its
    /// own codes: `glyphs` is empty and nothing new is embedded.
    pub(crate) existing: bool,
    /// The characters that stay in the font `base` without a glyph ([`FontSources::mark`]); then
    /// this is `base` itself, not another font.
    pub(crate) marks: Vec<char>,
}

/// What [`resolve`] gives the second pass of the rewrite.
#[derive(Debug, Default)]
pub(crate) struct Resolved {
    pub(crate) substitutes: Vec<Substitute>,
    pub(crate) fonts: Vec<EmbeddedFont>,
    pub(crate) substitutions: Vec<Substitution>,
    pub(crate) pending: Option<MissingGlyphs>,
}

/// Steps 2 and 3 for `misses`, in the fonts `fonts` of a page whose glyphs are `glyphs`, with
/// the page's fonts of other faces that encode some of them (`lenders`). `name` gives a free
/// resource name for a new font, from its base font's.
pub(crate) fn resolve(
    fonts: &HashMap<u64, PdfFont>,
    glyphs: &[Glyph],
    misses: &[Miss],
    lenders: &[PageFont],
    sources: &FontSources<'_>,
    name: &mut dyn FnMut(&[u8]) -> Option<Vec<u8>>,
) -> Result<Resolved, MissingGlyphs> {
    let mut resolved = Resolved::default();
    // Grouped by font, in the order they first appear.
    let mut groups: Vec<(u64, Vec<u8>, Vec<char>)> = Vec::new();
    for miss in misses {
        let at = match groups.iter().position(|(font, ..)| *font == miss.font) {
            Some(at) => at,
            None => {
                groups.push((miss.font, miss.name.clone(), Vec::new()));
                groups.len().saturating_sub(1)
            }
        };
        if let Some((_, _, chars)) = groups.get_mut(at)
            && !chars.contains(&miss.c)
        {
            chars.push(miss.c);
        }
    }
    let mut similar: Vec<(u64, Vec<u8>, Vec<char>)> = Vec::new();
    let mut reason = MissingReason::NotInstalled;
    let mut first_font: Option<u64> = None;
    for (font, resource, chars) in groups {
        let pdf = fonts.get(&font);
        first_font.get_or_insert(font);
        let restricted = pdf.and_then(restriction);
        if let Some(embedding) = restricted {
            reason = MissingReason::Restricted { embedding };
        }
        let mut left = chars.clone();
        if let (Some(library), Some(pdf)) = (sources.library, pdf) {
            match same_font(library, pdf, font, glyphs, false) {
                SameFont::Found { face, .. } => {
                    if let Some(new_name) = name(&resource)
                        && let Some((substitute, embedded, drawn)) =
                            substitute(library, &face, &chars, font, new_name, &mut resolved)
                    {
                        left.retain(|c| !drawn.contains(c));
                        resolved.substitutions.push(Substitution {
                            kind: SubstitutionKind::SameFont,
                            chars: drawn.iter().collect(),
                            from: font_name(Some(pdf)),
                            to: face.postscript_name.clone(),
                            origin: face.origin,
                        });
                        resolved.substitutes.push(substitute);
                        resolved.fonts.push(embedded);
                    }
                }
                SameFont::NotEmbeddable { face, embedding } => {
                    reason = MissingReason::NotEmbeddable {
                        font: face.postscript_name,
                        embedding,
                    };
                }
                SameFont::NotFound => {}
            }
        }
        if !left.is_empty() {
            similar.push((font, resource, left));
        }
    }
    if similar.is_empty() {
        return Ok(resolved);
    }
    if sources.mark && sources.choice.is_none() {
        for (font, resource, chars) in similar {
            let from = font_name(fonts.get(&font));
            resolved.substitutions.push(Substitution {
                kind: SubstitutionKind::Marked,
                chars: chars.iter().collect(),
                to: from.clone(),
                from,
                origin: FontOrigin::Embedded,
            });
            resolved.substitutes.push(Substitute {
                key: font,
                base: font,
                name: resource,
                glyphs: Vec::new(),
                existing: true,
                marks: chars,
            });
        }
        return Ok(resolved);
    }

    // Step 3, for every character left, in the style of the first font that lacks one.
    let font = similar
        .first()
        .map(|(font, ..)| *font)
        .or(first_font)
        .unwrap_or_default();
    let pdf = fonts.get(&font);
    let style = pdf.map_or(DEFAULT_STYLE, style_of);
    let mut text = String::new();
    for (_, _, chars) in &similar {
        for &c in chars {
            if !text.contains(c) {
                text.push(c);
            }
        }
    }
    let ranked = ranked_fonts(fonts, style, &text, lenders, sources);
    let chars: Vec<(char, usize)> = misses
        .iter()
        .filter(|miss| similar.iter().any(|(_, _, left)| left.contains(&miss.c)))
        .map(|miss| (miss.c, miss.at))
        .collect();
    let missing = MissingGlyphs {
        chars,
        font: font_name(pdf),
        reason,
        bold: style.weight >= 600,
        italic: style.italic,
        candidates: ranked
            .iter()
            .map(|(candidate, _)| candidate.clone())
            .collect(),
    };
    let Some((candidate, lender)) = picked(&missing, sources).and_then(|at| ranked.get(at)) else {
        return Err(missing);
    };
    for (font, resource, chars) in &similar {
        match lender {
            Lender::Page(lender) => resolved.substitutes.push(Substitute {
                key: lender.key,
                base: *font,
                name: lender.name.clone(),
                glyphs: Vec::new(),
                existing: true,
                marks: Vec::new(),
            }),
            Lender::Library(library, face) => {
                let Some(new_name) = name(resource) else {
                    return Err(missing);
                };
                let Some((substitute, embedded, _)) =
                    substitute(library, face, chars, *font, new_name, &mut resolved)
                        .filter(|(_, _, drawn)| drawn.len() == chars.len())
                else {
                    return Err(missing);
                };
                resolved.substitutes.push(substitute);
                resolved.fonts.push(embedded);
            }
        }
        resolved.substitutions.push(Substitution {
            kind: SubstitutionKind::Similar,
            chars: chars.iter().collect(),
            from: font_name(fonts.get(font)),
            to: candidate.postscript_name.clone(),
            origin: candidate.origin,
        });
    }
    if sources.choice.is_none() {
        resolved.pending = Some(missing);
    }
    Ok(resolved)
}

/// The candidate step 3 draws with: the caller's choice, or the closest, the first that can be
/// used (one its licence forbids is only listed). `None` waits for a choice.
fn picked(missing: &MissingGlyphs, sources: &FontSources<'_>) -> Option<usize> {
    let closest = missing.candidates.iter().position(FontCandidate::usable);
    let picked = match sources.choice {
        Some(FontChoice::Font {
            origin,
            postscript_name,
        }) => missing.candidates.iter().position(|candidate| {
            candidate.origin == *origin && candidate.postscript_name == *postscript_name
        }),
        Some(FontChoice::KeepAsIs) => closest,
        None if sources.ask => None,
        None => closest,
    };
    picked.filter(|&at| {
        missing
            .candidates
            .get(at)
            .is_some_and(FontCandidate::usable)
    })
}

/// `candidate` as a3-3b lists it.
fn listed(library: &FontLibrary, candidate: &Candidate) -> FontCandidate {
    FontCandidate {
        origin: candidate.face.origin,
        postscript_name: candidate.face.postscript_name.clone(),
        family: candidate.face.family.clone(),
        coverage: candidate.coverage,
        similarity: candidate.similarity,
        embedding: candidate.embedding,
        preview: preview(library, candidate.face.id),
    }
}

/// Step 3 for shaped text, drawn only in a font with its layout tables, so a font of the page
/// lends nothing: the face that shapes `text`, the characters `chars` of the fonts' `font` wait
/// for, and the pending choice when none was made.
pub(crate) fn similar_shaper(
    library: &FontLibrary,
    font: Option<&PdfFont>,
    text: &str,
    chars: Vec<(char, usize)>,
    reason: MissingReason,
    sources: &FontSources<'_>,
) -> Result<(FaceInfo, Option<MissingGlyphs>), MissingGlyphs> {
    let style = font.map_or(DEFAULT_STYLE, style_of);
    // Coverage by the decomposed letters, which a shaper composes or draws apart: a font need not
    // have U+FB1D's glyph. Hangul syllables stay, since few fonts have the jamo.
    let mut wanted = String::new();
    for c in text.chars() {
        if ('\u{AC00}'..='\u{D7A3}').contains(&c) {
            wanted.push(c);
        } else {
            unicode_normalization::char::decompose_canonical(c, |part| wanted.push(part));
        }
    }
    let query = SimilarQuery {
        text: &wanted,
        style,
        max_results: MAX_CANDIDATES,
    };
    let ranked = rank_similar(library, &query);
    let missing = MissingGlyphs {
        chars,
        font: font_name(font),
        reason,
        bold: style.weight >= 600,
        italic: style.italic,
        candidates: ranked
            .iter()
            .map(|candidate| listed(library, candidate))
            .collect(),
    };
    let Some(candidate) = picked(&missing, sources).and_then(|at| ranked.get(at)) else {
        return Err(missing);
    };
    let face = candidate.face.clone();
    Ok((face, sources.choice.is_none().then_some(missing)))
}

/// The installed and bundled fonts in `style` that cover some of `text`, and the page's own fonts
/// that already encode some of it, best first.
fn ranked_fonts<'a>(
    fonts: &HashMap<u64, PdfFont>,
    style: StyleMetrics,
    text: &str,
    lenders: &'a [PageFont],
    sources: &FontSources<'a>,
) -> Vec<(FontCandidate, Lender<'a>)> {
    let mut ranked: Vec<(FontCandidate, Lender<'a>)> = Vec::new();
    if let Some(library) = sources.library {
        let query = SimilarQuery {
            text,
            style,
            max_results: MAX_CANDIDATES,
        };
        ranked.extend(rank_similar(library, &query).into_iter().map(|candidate| {
            let listed = listed(library, &candidate);
            (listed, Lender::Library(library, candidate.face))
        }));
    }
    let needed: Vec<char> = text.chars().filter(|c| !c.is_whitespace()).collect();
    for lender in lenders {
        let covered = needed.iter().filter(|c| lender.chars.contains(c)).count();
        let other = fonts.get(&lender.key).map_or(DEFAULT_STYLE, style_of);
        if covered == 0
            || other.italic != style.italic
            || (other.weight >= 600) != (style.weight >= 600)
        {
            continue;
        }
        ranked.push((
            FontCandidate {
                origin: FontOrigin::Embedded,
                postscript_name: lender.postscript_name.clone(),
                family: lender.family.clone(),
                coverage: Coverage {
                    covered,
                    needed: needed.len(),
                },
                similarity: rough_similarity(&style, &other),
                // Its glyphs are in the document already: nothing new is embedded.
                embedding: Embedding::Installable,
                preview: lender.preview.clone(),
            },
            Lender::Page(lender),
        ));
    }
    ranked.sort_by(|(a, _), (b, _)| {
        b.coverage
            .covered
            .cmp(&a.coverage.covered)
            .then(b.similarity.total_cmp(&a.similarity))
            .then_with(|| a.family.cmp(&b.family))
            .then_with(|| a.postscript_name.cmp(&b.postscript_name))
    });
    ranked.truncate(MAX_CANDIDATES);
    ranked
}

/// The fonts a3-2's font field offers for a block in `pdf`'s style with the text `text`.
pub(crate) fn block_candidates(
    fonts: &HashMap<u64, PdfFont>,
    pdf: &PdfFont,
    text: &str,
    lenders: &[PageFont],
    sources: &FontSources<'_>,
) -> Vec<FontCandidate> {
    ranked_fonts(fonts, style_of(pdf), text, lenders, sources)
        .into_iter()
        .map(|(candidate, _)| candidate)
        .collect()
}

/// The whole of `text` in the font `choice`, for the block whose first font is `base`, named
/// `resource` on the page. The person chose it, so nothing here is a substitution to announce. A
/// font that cannot draw it all, or may not be embedded, answers with the characters it lacks.
#[allow(clippy::too_many_arguments)]
pub(crate) fn whole_block(
    fonts: &HashMap<u64, PdfFont>,
    base: u64,
    resource: &[u8],
    text: &str,
    lenders: &[PageFont],
    sources: &FontSources<'_>,
    choice: &BlockFont,
    name: &mut dyn FnMut(&[u8]) -> Option<Vec<u8>>,
) -> Result<Resolved, MissingGlyphs> {
    let mut chars: Vec<char> = Vec::new();
    let mut places: Vec<(char, usize)> = Vec::new();
    for (at, c) in text.char_indices() {
        if !c.is_control() {
            let c = if c.is_whitespace() { ' ' } else { c };
            places.push((c, at));
            if !chars.contains(&c) {
                chars.push(c);
            }
        }
    }
    let style = fonts.get(&base).map_or(DEFAULT_STYLE, style_of);
    let refused = |left: &[char], reason: MissingReason| MissingGlyphs {
        chars: places
            .iter()
            .copied()
            .filter(|(c, _)| left.contains(c))
            .collect(),
        font: choice.postscript_name.clone(),
        reason,
        bold: style.weight >= 600,
        italic: style.italic,
        candidates: Vec::new(),
    };
    let mut resolved = Resolved::default();
    if choice.origin == FontOrigin::Embedded {
        let Some(lender) = lenders
            .iter()
            .find(|lender| lender.postscript_name == choice.postscript_name)
        else {
            return Err(refused(&chars, MissingReason::NotInstalled));
        };
        let left: Vec<char> = chars
            .iter()
            .copied()
            .filter(|c| *c != ' ' && !lender.chars.contains(c))
            .collect();
        if !left.is_empty() {
            return Err(refused(&left, MissingReason::NotInstalled));
        }
        resolved.substitutes.push(Substitute {
            key: lender.key,
            base,
            name: lender.name.clone(),
            glyphs: Vec::new(),
            existing: true,
            marks: Vec::new(),
        });
        return Ok(resolved);
    }
    let not_there = || refused(&chars, MissingReason::NotInstalled);
    let library = sources.library.ok_or_else(not_there)?;
    let face = library
        .faces()
        .find(|face| face.origin == choice.origin && face.postscript_name == choice.postscript_name)
        .ok_or_else(not_there)?;
    let embedding = embedding_of(library, face.id).ok_or_else(not_there)?;
    if !embedding.allows_subset() {
        return Err(refused(
            &chars,
            MissingReason::NotEmbeddable {
                font: choice.postscript_name.clone(),
                embedding,
            },
        ));
    }
    let new_name = name(resource).ok_or_else(not_there)?;
    let (substitute, embedded, drawn) =
        substitute(library, &face, &chars, base, new_name, &mut resolved).ok_or_else(not_there)?;
    let left: Vec<char> = chars
        .iter()
        .copied()
        .filter(|c| *c != ' ' && !drawn.contains(c))
        .collect();
    if !left.is_empty() {
        return Err(refused(&left, MissingReason::NotInstalled));
    }
    resolved.substitutes.push(substitute);
    resolved.fonts.push(embedded);
    Ok(resolved)
}

fn embedding_of(library: &FontLibrary, id: FaceId) -> Option<Embedding> {
    library
        .with_data(id, |data, _index| {
            FontProgram::parse(data)
                .ok()
                .map(|program| Embedding::from_fs_type(program.fs_type()))
        })
        .flatten()
}

/// `postscript_name` without its subset tag, style and foundry suffixes: what the faces of a family
/// share (`ABCDEF+Arial-BoldMT` and `ArialMT` both give `arial`).
fn family_stem(postscript_name: &str) -> String {
    let name = strip_subset_tag(postscript_name);
    let stem = name.split(['-', ',']).next().unwrap_or(name);
    let stem = stem.strip_suffix("MT").unwrap_or(stem);
    let stem = stem.strip_suffix("PS").unwrap_or(stem);
    stem.to_ascii_lowercase()
}

/// The face of `pdf`'s family that is `bold` and `italic`: a font of the page, else an installed or
/// bundled one, that can draw all of `text` and may be embedded; `None` when no such face exists,
/// since bold and italic are never faked.
pub(crate) fn toggled_face(
    fonts: &HashMap<u64, PdfFont>,
    pdf: &PdfFont,
    text: &str,
    lenders: &[PageFont],
    library: Option<&FontLibrary>,
    bold: bool,
    italic: bool,
) -> Option<BlockFont> {
    let stem = family_stem(pdf.resource.base_font.as_deref().unwrap_or_default());
    let needed: Vec<char> = text.chars().filter(|c| !c.is_whitespace()).collect();
    let on_page = lenders.iter().find(|lender| {
        let other = fonts.get(&lender.key).map_or(DEFAULT_STYLE, style_of);
        family_stem(&lender.postscript_name) == stem
            && other.italic == italic
            && (other.weight >= 600) == bold
            && needed.iter().all(|c| lender.chars.contains(c))
    });
    if let Some(lender) = on_page {
        return Some(BlockFont {
            origin: FontOrigin::Embedded,
            postscript_name: lender.postscript_name.clone(),
        });
    }
    let library = library?;
    let goal: u16 = if bold { 700 } else { 400 };
    let mut faces: Vec<_> = library
        .faces()
        .filter(|face| {
            family_stem(&face.postscript_name) == stem
                && face.italic == italic
                && (face.weight >= 600) == bold
                && face.stretch == 5
        })
        .collect();
    faces.sort_by_key(|face| face.weight.abs_diff(goal));
    faces.into_iter().find_map(|face| {
        let usable = library
            .with_data(face.id, |data, _index| {
                let program = FontProgram::parse(data).ok()?;
                let draws = needed
                    .iter()
                    .all(|&c| program.glyph_for_char(c).is_some_and(|glyph| glyph.0 != 0));
                Some(draws && Embedding::from_fs_type(program.fs_type()).allows_subset())
            })
            .flatten()?;
        usable.then_some(BlockFont {
            origin: face.origin,
            postscript_name: face.postscript_name,
        })
    })
}

/// Step 2's search for `pdf` (key `key`) of a page whose glyphs are `glyphs`, confirmed by the
/// PDF's widths. With `contextual`, the characters a shaper gives contextual forms (Arabic letters
/// and marks) are left out of the widths: the first glyph the page sets for one may be any of its
/// forms, whose width is not the character's nominal glyph's.
pub(crate) fn same_font(
    library: &FontLibrary,
    pdf: &PdfFont,
    key: u64,
    glyphs: &[Glyph],
    contextual: bool,
) -> SameFont {
    let style = style_of(pdf);
    let mut widths = widths_of(pdf, key, glyphs);
    if contextual {
        widths.retain(|&(c, _)| {
            !matches!(
                unicode_bidi::bidi_class(c),
                unicode_bidi::BidiClass::AL | unicode_bidi::BidiClass::NSM
            )
        });
    }
    let family = pdf
        .program()
        .and_then(|program| program.family_name())
        .or_else(|| pdf.resource.base_font.clone());
    let query = SameFontQuery {
        postscript_name: pdf.resource.base_font.as_deref().unwrap_or_default(),
        family: family.as_deref(),
        weight: style.weight,
        italic: style.italic,
        stretch: 5,
        units_per_em: pdf.program().map(|program| program.units_per_em()),
        widths: &widths,
    };
    find_same_font(library, &query)
}

/// A font of the page that already encodes some of the missing characters through its own
/// codes: an "embedded in this document" candidate (a3-3b).
#[derive(Debug, Clone)]
pub(crate) struct PageFont {
    pub(crate) key: u64,
    /// Its name in the page's resources.
    pub(crate) name: Vec<u8>,
    pub(crate) postscript_name: String,
    pub(crate) family: String,
    /// The missing characters it encodes.
    pub(crate) chars: Vec<char>,
    /// The letters of [`PREVIEW`] it encodes.
    pub(crate) preview: String,
}

/// Where a candidate's glyphs come from.
enum Lender<'a> {
    Library(&'a FontLibrary, FaceInfo),
    Page(&'a PageFont),
}

/// 1 minus the mean difference of serif against sans (twice) and weight, for the page's fonts,
/// whose subsets rarely keep the tables [`rank_similar`] reads.
fn rough_similarity(a: &StyleMetrics, b: &StyleMetrics) -> f32 {
    let weight = (f32::from(a.weight) - f32::from(b.weight)).abs() / 900.0;
    match (a.serif, b.serif) {
        (Some(x), Some(y)) => 1.0 - (if x == y { 0.0 } else { 2.0 } + weight) / 3.0,
        _ => 1.0 - weight,
    }
}

const DEFAULT_STYLE: StyleMetrics = StyleMetrics {
    x_height: None,
    cap_height: None,
    average_width: None,
    serif: None,
    weight: 400,
    italic: false,
};

/// The permission of `font`'s embedded program when it allows at most preview and print (Q09).
pub(crate) fn restriction(font: &PdfFont) -> Option<Embedding> {
    let embedding = Embedding::from_fs_type(font.program()?.fs_type());
    matches!(
        embedding,
        Embedding::Restricted | Embedding::PreviewAndPrint
    )
    .then_some(embedding)
}

/// The PostScript name of `font` without its subset tag.
pub(crate) fn font_name(font: Option<&PdfFont>) -> String {
    font.and_then(|font| font.resource.base_font.as_deref())
        .map(|name| strip_subset_tag(name).to_owned())
        .unwrap_or_default()
}

/// The style of `font`: its program's metrics, bold and italic also from its name.
pub(crate) fn style_of(font: &PdfFont) -> StyleMetrics {
    let mut style = font
        .resource
        .font_program
        .as_deref()
        .and_then(|data| StyleMetrics::of(data, 0).ok())
        .unwrap_or(DEFAULT_STYLE);
    let name = font.resource.base_font.as_deref().unwrap_or_default();
    if name.contains("Bold") || name.contains("Black") || name.contains("Heavy") {
        style.weight = style.weight.max(700);
    }
    if name.contains("Italic") || name.contains("Oblique") {
        style.italic = true;
    }
    if style.serif.is_none() {
        style.serif = serif_by_name(name);
    }
    style
}

/// Serif or sans by the font's name, for programs without the tables that say: subsets often
/// drop `OS/2`.
pub(crate) fn serif_by_name(name: &str) -> Option<bool> {
    let name = strip_subset_tag(name).to_ascii_lowercase();
    const SANS: [&str; 8] = [
        "sans",
        "arial",
        "helvetica",
        "grotesk",
        "gothic",
        "verdana",
        "calibri",
        "mono",
    ];
    const SERIF: [&str; 9] = [
        "serif",
        "times",
        "garamond",
        "georgia",
        "roman",
        "minion",
        "caslon",
        "baskerville",
        "cambria",
    ];
    if SANS.iter().any(|word| name.contains(word)) {
        Some(false)
    } else if SERIF.iter().any(|word| name.contains(word)) {
        Some(true)
    } else {
        None
    }
}

/// The PDF's widths of the characters the page sets in `font` (key `key`), in thousandths of an
/// em, each once.
fn widths_of(font: &PdfFont, key: u64, glyphs: &[Glyph]) -> Vec<(char, f32)> {
    let mut widths: Vec<(char, f32)> = Vec::new();
    for glyph in glyphs.iter().filter(|glyph| glyph.font == key) {
        if let Some(c) = single(&glyph.text)
            && !c.is_whitespace()
            && !widths.iter().any(|(seen, _)| *seen == c)
        {
            widths.push((c, font.width(glyph.code, glyph.length) * 1000.0));
        }
    }
    widths
}

/// The letters of [`PREVIEW`] face `id` covers.
fn preview(library: &FontLibrary, id: FaceId) -> String {
    library
        .with_data(id, |data, _index| {
            // shortcut: the first face of a collection answers for all; read the face's own
            // cmap when a collection's faces differ in coverage.
            let program = FontProgram::parse(data).ok()?;
            let has = |c: char| program.glyph_for_char(c).is_some_and(|glyph| glyph.0 != 0);
            let pairs: Vec<String> = PREVIEW
                .split(' ')
                .map(|pair| pair.chars().filter(|&c| has(c)).collect::<String>())
                .filter(|pair| !pair.is_empty())
                .collect();
            Some(pairs.join(" "))
        })
        .flatten()
        .unwrap_or_default()
}

/// The new font that draws `chars` from face `id`, for the characters of `base`: the substitute,
/// its objects and the characters it draws (those the face has).
fn substitute(
    library: &FontLibrary,
    face: &FaceInfo,
    chars: &[char],
    base: u64,
    name: Vec<u8>,
    resolved: &mut Resolved,
) -> Option<(Substitute, EmbeddedFont, Vec<char>)> {
    library
        .with_data(face.id, |data, index| {
            let instance = face.instance.as_ref();
            let shaper = ShapingFont::new_at(data.to_vec(), index, instance).ok()?;
            // Each character on its own, so each glyph stands for exactly one.
            let mut wanted: Vec<(char, ferman_fonts::GlyphId)> = Vec::new();
            for &c in chars {
                let text = c.to_string();
                let run = shaper
                    .shape(&ShapeRequest::new(&text, Direction::LeftToRight))
                    .ok()?;
                if let [glyph] = run.glyphs.as_slice()
                    && glyph.glyph.0 != 0
                {
                    wanted.push((c, glyph.glyph));
                }
            }
            if wanted.is_empty() {
                return None;
            }
            let texts: Vec<(ferman_fonts::GlyphId, String)> = wanted
                .iter()
                .map(|(c, glyph)| (*glyph, c.to_string()))
                .collect();
            let (embedded, codes) = embed(data, index, instance, &texts, name.clone())?;
            let mut drawn = Vec::new();
            let mut glyphs = Vec::new();
            for ((c, _), (_, code, width)) in wanted.into_iter().zip(codes) {
                glyphs.push((c, code, width));
                drawn.push(c);
            }
            // Keys are hashes of font dictionaries; a substitute's is derived from its base's and
            // its place among the substitutes.
            let key = base
                ^ 0x5B57_0F0C_0FFE_E000
                ^ u64::try_from(resolved.substitutes.len()).unwrap_or_default();
            Some((
                Substitute {
                    key,
                    base,
                    name,
                    glyphs,
                    existing: false,
                    marks: Vec::new(),
                },
                embedded,
                drawn,
            ))
        })
        .flatten()
}

/// Glyphs with their codes in a new font and their advances per unit of font size.
pub type GlyphCodes = Vec<(GlyphId, Vec<u8>, f32)>;

/// A new Type0 font named `name` (on the page) with the glyphs `wanted` of the font at `index` of
/// `data` (at `instance` of a variable font), each with the text its ToUnicode entry gives (an empty one reads as nothing): the font, and
/// each wanted glyph's code and advance per unit of font size, in order.
#[must_use]
pub fn embed(
    data: &[u8],
    index: u32,
    instance: Option<&FaceInstance>,
    wanted: &[(GlyphId, String)],
    name: Vec<u8>,
) -> Option<(EmbeddedFont, GlyphCodes)> {
    let subset = subset_at(data, index, wanted, instance).ok()?;
    let mut codes = Vec::new();
    let mut widths = Vec::new();
    let mut texts: Vec<(Vec<u8>, String)> = Vec::new();
    for (old, text) in wanted {
        let new = subset.new_glyph(*old)?;
        let width = subset.glyphs.iter().find(|glyph| glyph.new == new)?.width;
        let code = new.to_be_bytes().to_vec();
        if !widths.iter().any(|(cid, _)| *cid == u32::from(new)) {
            widths.push((u32::from(new), width));
        }
        match texts.iter_mut().find(|(seen, _)| *seen == code) {
            // The first non-empty text a glyph is listed with.
            Some((_, seen)) if seen.is_empty() => seen.clone_from(text),
            Some(_) => {}
            None => texts.push((code.clone(), text.clone())),
        }
        codes.push((*old, code, width / 1000.0));
    }
    let descriptor = subset.descriptor;
    let embedded = EmbeddedFont {
        name,
        base_font: subset.base_font,
        program: match subset.program {
            SubsetProgram::TrueType(data) => EmbeddedProgram::TrueType(data),
            SubsetProgram::Cff(data) => EmbeddedProgram::Cff(data),
        },
        widths,
        to_unicode: with_text(None, &texts),
        ascent: descriptor.ascent,
        descent: descriptor.descent,
        cap_height: descriptor.cap_height,
        x_height: descriptor.x_height,
        bbox: descriptor.bbox,
        italic_angle: descriptor.italic_angle,
        flags: descriptor.flags,
        stem_v: descriptor.stem_v,
    };
    Some((embedded, codes))
}

#[cfg(test)]
mod tests {
    use super::family_stem;

    #[test]
    fn the_faces_of_a_family_share_a_stem() {
        assert_eq!(family_stem("ABCDEF+Arial-BoldMT"), "arial");
        assert_eq!(family_stem("ArialMT"), "arial");
        assert_eq!(family_stem("Arial,Italic"), "arial");
        assert_eq!(family_stem("IBMPlexSerif-Bold"), "ibmplexserif");
        assert_eq!(family_stem("TimesNewRomanPS-BoldMT"), "timesnewroman");
        assert_ne!(
            family_stem("IBMPlexSans-Bold"),
            family_stem("IBMPlexSerif-Bold")
        );
    }
}
