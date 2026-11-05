//! Finding fonts for missing glyphs (ADR 0006, ROADMAP §7 step 6).
//!
//! - Step 2, [`find_same_font`]: the same font as the document's, found by PostScript name (the
//!   subset tag removed), then by family and style, and confirmed by its metrics: the units per
//!   em agree and the advance widths of the glyphs both have are within 1/1000 em of the PDF's.
//!   A font whose `fsType` forbids new text is reported with the reason, never used.
//! - Step 3 and the a3-3b picker, [`rank_similar`]: candidates from the embedded, installed and
//!   bundled fonts, ranked by coverage of the needed text first, then by metric similarity
//!   (x-height, cap height, average width, weight, serif or sans). Italic and bold must match the
//!   original: an upright font is never offered for italic text, nor a regular one for bold, so
//!   neither is ever faked.
//!
//! The work per query is bounded: at most [`MAX_FACES_OPENED`] faces are opened, after a
//! filter on what the index already knows, and at most [`MAX_BYTES_READ`] bytes of font files
//! are read. A face that does not parse is skipped.

use skrifa::instance::{LocationRef, Size};
use skrifa::raw::TableProvider;
use skrifa::{FontRef, MetadataProvider};

use crate::FontError;
use crate::subset::Embedding;
use crate::system::{FaceInfo, FontLibrary};

/// The most faces one query opens.
pub const MAX_FACES_OPENED: usize = 256;

/// The most bytes of font files one query reads; the face that crosses it is the last opened.
pub const MAX_BYTES_READ: usize = 1024 * 1024 * 1024;

/// The document's font, as step 2 looks for it.
#[derive(Debug, Clone, Copy)]
pub struct SameFontQuery<'a> {
    /// The PostScript name, with or without a subset tag (`ABCDEF+`).
    pub postscript_name: &'a str,
    /// The family, when the document names one (`/FontFamily`) or the embedded program has one.
    pub family: Option<&'a str>,
    /// The weight class, 100 to 900.
    pub weight: u16,
    /// Italic or oblique.
    pub italic: bool,
    /// The width class, 1 to 9 (5 normal).
    pub stretch: u16,
    /// The units per em of the embedded program, when the document embeds one.
    pub units_per_em: Option<u16>,
    /// The PDF's widths of the characters the document sets in the font, in thousandths of an
    /// em: `/Widths` or `/W` through the encoding.
    pub widths: &'a [(char, f32)],
}

/// What step 2 found.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SameFont {
    /// The same font, usable for the new glyphs.
    Found {
        /// The face.
        face: FaceInfo,
        /// Its permission, which allows new text.
        embedding: Embedding,
    },
    /// The same font, but its `fsType` forbids new text: the flow goes to step 3 with the reason.
    NotEmbeddable {
        /// The face.
        face: FaceInfo,
        /// Its permission, which forbids new text.
        embedding: Embedding,
    },
    /// No font in the library is the same.
    NotFound,
}

/// The PostScript name without a subset tag: `ABCDEF+Name` becomes `Name`.
#[must_use]
pub fn strip_subset_tag(name: &str) -> &str {
    match name.split_once('+') {
        Some((tag, rest)) if tag.len() == 6 && tag.bytes().all(|b| b.is_ascii_uppercase()) => rest,
        _ => name,
    }
}

/// Step 2: the same font as `query` in `library`, by PostScript name first, then by family and
/// style, each confirmed by its metrics.
#[must_use]
pub fn find_same_font(library: &FontLibrary, query: &SameFontQuery<'_>) -> SameFont {
    let name = strip_subset_tag(query.postscript_name);
    let by_name = library.faces().filter(|face| face.postscript_name == name);
    let by_style = library.faces().filter(|face| {
        face.postscript_name != name
            && query
                .family
                .is_some_and(|family| face.family.eq_ignore_ascii_case(family))
            && face.weight == query.weight
            && face.italic == query.italic
            && face.stretch == query.stretch
    });
    let mut forbidden = None;
    let mut read = 0usize;
    for face in by_name.chain(by_style).take(MAX_FACES_OPENED) {
        if read > MAX_BYTES_READ {
            break;
        }
        let confirmed = library.with_data(face.id, |data, index| {
            read = read.saturating_add(data.len());
            let font = FontRef::from_index(data, index).ok()?;
            confirms(&font, query).then(|| Embedding::of(data, index))
        });
        match confirmed.flatten() {
            Some(embedding) if embedding.allows_new_text() => {
                return SameFont::Found { face, embedding };
            }
            Some(embedding) => {
                forbidden.get_or_insert(SameFont::NotEmbeddable { face, embedding });
            }
            None => {}
        }
    }
    forbidden.unwrap_or(SameFont::NotFound)
}

/// Whether `font` has the metrics `query` gives: the same units per em, and every width of a
/// character both have within 1/1000 em. With widths given, at least one must be compared.
fn confirms(font: &FontRef<'_>, query: &SameFontQuery<'_>) -> bool {
    let Ok(head) = font.head() else {
        return false;
    };
    let upem = head.units_per_em();
    if upem == 0 || query.units_per_em.is_some_and(|expected| expected != upem) {
        return false;
    }
    let charmap = font.charmap();
    let metrics = font.glyph_metrics(Size::unscaled(), LocationRef::default());
    let mut compared = 0usize;
    for &(c, width) in query.widths {
        let Some(glyph) = charmap.map(c).filter(|glyph| glyph.to_u32() != 0) else {
            continue;
        };
        let Some(advance) = metrics.advance_width(glyph) else {
            continue;
        };
        if (advance * 1000.0 / f32::from(upem) - width).abs() > 1.0 {
            return false;
        }
        compared = compared.saturating_add(1);
    }
    query.widths.is_empty() || compared > 0
}

/// The style of a font, for [`rank_similar`]. Lengths are in thousandths of an em.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct StyleMetrics {
    /// The x-height, when the font says.
    pub x_height: Option<f32>,
    /// The cap height, when the font says.
    pub cap_height: Option<f32>,
    /// The average character width (`OS/2.xAvgCharWidth`), when the font says.
    pub average_width: Option<f32>,
    /// Serif (true) or sans (false), from `OS/2.sFamilyClass` or PANOSE; `None` when unknown.
    pub serif: Option<bool>,
    /// The weight class, 100 to 900.
    pub weight: u16,
    /// Italic or oblique.
    pub italic: bool,
}

impl StyleMetrics {
    /// The style of the font at `index` of `data`.
    ///
    /// # Errors
    ///
    /// [`FontError::Malformed`] for bytes that are not an sfnt or a font without units per em.
    pub fn of(data: &[u8], index: u32) -> Result<Self, FontError> {
        let font = FontRef::from_index(data, index).map_err(|_| FontError::Malformed {
            context: "font program for its style",
        })?;
        style_of(&font).ok_or(FontError::Malformed {
            context: "units per em",
        })
    }
}

fn style_of(font: &FontRef<'_>) -> Option<StyleMetrics> {
    let metrics = font.metrics(Size::unscaled(), LocationRef::default());
    if metrics.units_per_em == 0 {
        return None;
    }
    let scale = 1000.0 / f32::from(metrics.units_per_em);
    let attributes = font.attributes();
    Some(StyleMetrics {
        x_height: metrics.x_height.filter(|v| *v > 0.0).map(|v| v * scale),
        cap_height: metrics.cap_height.filter(|v| *v > 0.0).map(|v| v * scale),
        average_width: metrics
            .average_width
            .filter(|v| *v > 0.0)
            .map(|v| v * scale),
        serif: is_serif(font),
        // The weight class fits u16; a damaged value is clamped to the scale's ends.
        weight: attributes.weight.value().clamp(1.0, 1000.0) as u16,
        italic: attributes.style != skrifa::attribute::Style::Normal,
    })
}

/// Serif or sans from `OS/2.sFamilyClass` (classes 1 to 5 and 7 are serifs, 8 sans serif), else
/// from PANOSE's serif style for Latin text faces.
pub(crate) fn is_serif(font: &FontRef<'_>) -> Option<bool> {
    let os2 = font.os2().ok()?;
    match os2.s_family_class() >> 8 {
        1..=5 | 7 => return Some(true),
        8 => return Some(false),
        _ => {}
    }
    match os2.panose_10() {
        [2, 2..=10, ..] => Some(true),
        [2, 11..=15, ..] => Some(false),
        _ => None,
    }
}

/// What step 3 needs: the text the font must draw and the style of the original font.
#[derive(Debug, Clone, Copy)]
pub struct SimilarQuery<'a> {
    /// The text the substitute must cover (the characters of the edited runs).
    pub text: &'a str,
    /// The style of the original font, from its program ([`StyleMetrics::of`]) or descriptor.
    pub style: StyleMetrics,
    /// The most candidates returned.
    pub max_results: usize,
}

/// How much of the needed text a candidate covers, in distinct characters (spaces and controls
/// not counted).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Coverage {
    /// The characters it has.
    pub covered: usize,
    /// The characters needed.
    pub needed: usize,
}

impl Coverage {
    /// Whether it covers every needed character.
    #[must_use]
    pub fn is_full(self) -> bool {
        self.covered == self.needed
    }
}

/// A candidate for step 3 and the a3-3b picker.
#[derive(Debug, Clone, PartialEq)]
pub struct Candidate {
    /// The face, with its origin (embedded, installed or bundled).
    pub face: FaceInfo,
    /// How much of the text it covers.
    pub coverage: Coverage,
    /// How close its metrics are to the original's, 0 (unlike) to 1 (the same).
    pub similarity: f32,
    /// Its embedding permission; a candidate that forbids new text is listed with the reason.
    pub embedding: Embedding,
}

/// Step 3: the faces of `library` that could draw `query.text`, best first: full coverage before
/// partial, then the most similar. Faces of another slant or weight class (bold is 600 and over)
/// are left out, and so are faces that cover none of the text.
#[must_use]
pub fn rank_similar(library: &FontLibrary, query: &SimilarQuery<'_>) -> Vec<Candidate> {
    let mut needed: Vec<char> = query
        .text
        .chars()
        .filter(|c| !c.is_whitespace() && !c.is_control())
        .collect();
    needed.sort_unstable();
    needed.dedup();
    let bold = |weight: u16| weight >= 600;
    let read = std::cell::Cell::new(0usize);
    let mut candidates: Vec<Candidate> = library
        .faces()
        .filter(|face| face.italic == query.style.italic)
        .filter(|face| bold(face.weight) == bold(query.style.weight))
        .take(MAX_FACES_OPENED)
        .take_while(|_| read.get() <= MAX_BYTES_READ)
        .filter_map(|face| {
            library
                .with_data(face.id, |data, index| {
                    read.set(read.get().saturating_add(data.len()));
                    let font = FontRef::from_index(data, index).ok()?;
                    let style = style_of(&font)?;
                    // The index reads fsSelection; the metrics read the same tables, but check
                    // again in case the face disagrees with itself.
                    if style.italic != query.style.italic
                        || bold(style.weight) != bold(query.style.weight)
                    {
                        return None;
                    }
                    let charmap = font.charmap();
                    let covered = needed
                        .iter()
                        .filter(|&&c| charmap.map(c).is_some_and(|glyph| glyph.to_u32() != 0))
                        .count();
                    Some(Candidate {
                        coverage: Coverage {
                            covered,
                            needed: needed.len(),
                        },
                        similarity: similarity(&query.style, &style),
                        embedding: Embedding::of(data, index),
                        face: face.clone(),
                    })
                })
                .flatten()
        })
        .filter(|candidate| candidate.coverage.needed == 0 || candidate.coverage.covered > 0)
        .collect();
    candidates.sort_by(|a, b| {
        b.coverage
            .covered
            .cmp(&a.coverage.covered)
            .then(b.similarity.total_cmp(&a.similarity))
            .then_with(|| a.face.family.cmp(&b.face.family))
            .then_with(|| a.face.postscript_name.cmp(&b.face.postscript_name))
    });
    candidates.truncate(query.max_results);
    candidates
}

/// 1 minus the weighted mean of the relative differences: x-height, cap height, average width
/// and weight once each, serif against sans twice. Metrics one side lacks are left out.
fn similarity(a: &StyleMetrics, b: &StyleMetrics) -> f32 {
    fn relative(a: Option<f32>, b: Option<f32>) -> Option<f32> {
        let (a, b) = (a?, b?);
        let largest = a.max(b);
        (largest > 0.0).then(|| (a - b).abs() / largest)
    }
    let mut terms = vec![(
        1.0,
        (f32::from(a.weight) - f32::from(b.weight)).abs() / 800.0,
    )];
    for difference in [
        relative(a.x_height, b.x_height),
        relative(a.cap_height, b.cap_height),
        relative(a.average_width, b.average_width),
    ]
    .into_iter()
    .flatten()
    {
        terms.push((1.0, difference));
    }
    if let (Some(a), Some(b)) = (a.serif, b.serif) {
        terms.push((2.0, if a == b { 0.0 } else { 1.0 }));
    }
    let weights: f32 = terms.iter().map(|(weight, _)| weight).sum();
    let distance: f32 = terms
        .iter()
        .map(|(weight, d)| weight * d.min(1.0))
        .sum::<f32>()
        / weights;
    (1.0 - distance).clamp(0.0, 1.0)
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;
    use crate::program::FontProgram;
    use crate::system::{FontOrigin, ScanLimits};
    use crate::test_fonts::{corpus_font, e05_font, plex, plex_dir};

    fn bundled() -> FontLibrary {
        let mut library = FontLibrary::new();
        library.add_dir(&plex_dir(), FontOrigin::Bundled, &ScanLimits::default());
        library
    }

    /// The widths of `text` in `data`, as a PDF would give them.
    fn widths(data: &[u8], text: &str, delta: f32) -> Vec<(char, f32)> {
        let program = FontProgram::parse(data).unwrap();
        let upem = f32::from(program.units_per_em());
        text.chars()
            .map(|c| {
                let advance = program
                    .advance_width(program.glyph_for_char(c).unwrap())
                    .unwrap();
                (c, (advance * 1000.0 / upem).round() + delta)
            })
            .collect()
    }

    fn query<'a>(name: &'a str, widths: &'a [(char, f32)]) -> SameFontQuery<'a> {
        SameFontQuery {
            postscript_name: name,
            family: None,
            weight: 400,
            italic: false,
            stretch: 5,
            units_per_em: Some(1000),
            widths,
        }
    }

    fn found_name(result: &SameFont) -> &str {
        match result {
            SameFont::Found { face, .. } => &face.postscript_name,
            other => panic!("expected a match, got {other:?}"),
        }
    }

    #[test]
    fn subset_tags_are_removed() {
        assert_eq!(
            strip_subset_tag("WOGQOY+EBGaramond-Regular"),
            "EBGaramond-Regular"
        );
        assert_eq!(strip_subset_tag("Arial"), "Arial");
        assert_eq!(strip_subset_tag("abc+Name"), "abc+Name");
    }

    #[test]
    fn the_same_font_by_postscript_name_with_widths_in_tolerance() {
        let library = bundled();
        let data = plex("ibm-plex-serif/IBMPlexSerif-Regular.ttf");
        let close = widths(&data, "Madde ğ", 0.0);
        let result = find_same_font(&library, &query("ABCDEF+IBMPlexSerif-Regular", &close));
        assert_eq!(found_name(&result), "IBMPlexSerif-Regular");
        // Within 1/1000 em is accepted, beyond it rejected.
        let edge = widths(&data, "Madde", 0.9);
        assert!(matches!(
            find_same_font(&library, &query("IBMPlexSerif-Regular", &edge)),
            SameFont::Found { .. }
        ));
        let far = widths(&data, "Madde", 1.5);
        assert_eq!(
            find_same_font(&library, &query("IBMPlexSerif-Regular", &far)),
            SameFont::NotFound
        );
        // Another units per em is another font.
        let other_upem = SameFontQuery {
            units_per_em: Some(2048),
            ..query("IBMPlexSerif-Regular", &close)
        };
        assert_eq!(find_same_font(&library, &other_upem), SameFont::NotFound);
    }

    #[test]
    fn family_and_style_when_the_name_differs() {
        let library = bundled();
        let data = plex("ibm-plex-sans/IBMPlexSans-SemiBold.ttf");
        let bold_widths = widths(&data, "Kira", 0.0);
        let result = find_same_font(
            &library,
            &SameFontQuery {
                family: Some("IBM Plex Sans"),
                weight: 600,
                ..query("PlexSans,Bold", &bold_widths)
            },
        );
        assert_eq!(found_name(&result), "IBMPlexSans-SmBld");
        // The italic is another style: no match.
        let italic = SameFontQuery {
            family: Some("IBM Plex Sans"),
            weight: 600,
            italic: true,
            ..query("PlexSans,Bold", &bold_widths)
        };
        assert!(!matches!(
            find_same_font(&library, &italic),
            SameFont::Found { face, .. } if face.postscript_name == "IBMPlexSans-SmBld"
        ));
    }

    #[test]
    fn e05_restricted_embedding_is_rejected_with_the_reason() {
        // The embedded program of edit-e05-fstype.pdf: an EB Garamond subset with fsType 2.
        let (program, pdf_widths) = e05_font();
        assert_eq!(Embedding::of(&program, 0), Embedding::Restricted);
        let mut library = FontLibrary::new();
        library.add_bytes(program, FontOrigin::Embedded).unwrap();
        let result = find_same_font(&library, &query("WOGQOY+EBGaramond-Regular", &pdf_widths));
        match result {
            SameFont::NotEmbeddable { face, embedding } => {
                assert_eq!(face.postscript_name, "EBGaramond-Regular");
                assert_eq!(embedding, Embedding::Restricted);
            }
            other => panic!("expected the restricted font, got {other:?}"),
        }
        // The installed EB Garamond, whose own licence allows embedding, is the same font.
        let Some(installed) = corpus_font("EBGaramond-VF.ttf") else {
            return;
        };
        library.add_bytes(installed, FontOrigin::Installed).unwrap();
        let result = find_same_font(&library, &query("WOGQOY+EBGaramond-Regular", &pdf_widths));
        match result {
            SameFont::Found { face, embedding } => {
                assert_eq!(face.origin, FontOrigin::Installed);
                assert!(embedding.allows_new_text());
            }
            other => panic!("expected the installed font, got {other:?}"),
        }
    }

    #[test]
    fn ranking_puts_coverage_first_and_never_changes_the_slant_or_weight() {
        let library = bundled();
        let serif = StyleMetrics::of(&plex("ibm-plex-serif/IBMPlexSerif-Regular.ttf"), 0).unwrap();
        assert_eq!(serif.serif, Some(true));
        let ranked = rank_similar(
            &library,
            &SimilarQuery {
                text: "Kira ğ",
                style: serif,
                max_results: 50,
            },
        );
        assert!(!ranked.is_empty());
        assert_eq!(ranked[0].face.postscript_name, "IBMPlexSerif-Regular");
        assert!((ranked[0].similarity - 1.0).abs() < 1e-6);
        assert!(ranked.iter().all(|c| !c.face.italic && c.face.weight < 600));
        // Full coverage before partial: Plex Sans Arabic has Latin, but every full one comes first.
        let first_partial = ranked.iter().position(|c| !c.coverage.is_full());
        if let Some(first) = first_partial {
            assert!(ranked[first..].iter().all(|c| !c.coverage.is_full()));
        }
        // Among the full ones, the serif ranks above the sans.
        let sans = ranked
            .iter()
            .position(|c| c.face.postscript_name == "IBMPlexSans")
            .unwrap();
        assert!(sans > 0);
        assert!(ranked.windows(2).all(|pair| {
            pair[0].coverage.covered > pair[1].coverage.covered
                || pair[0].similarity >= pair[1].similarity
        }));

        // Italic text gets italic faces only, bold text bold faces only.
        let italic = StyleMetrics::of(&plex("ibm-plex-serif/IBMPlexSerif-Italic.ttf"), 0).unwrap();
        let ranked = rank_similar(
            &library,
            &SimilarQuery {
                text: "ğ",
                style: italic,
                max_results: 50,
            },
        );
        assert!(!ranked.is_empty());
        assert!(ranked.iter().all(|c| c.face.italic));
        let bold = StyleMetrics::of(&plex("ibm-plex-sans/IBMPlexSans-SemiBold.ttf"), 0).unwrap();
        let ranked = rank_similar(
            &library,
            &SimilarQuery {
                text: "ğ",
                style: bold,
                max_results: 50,
            },
        );
        assert!(!ranked.is_empty());
        assert!(
            ranked
                .iter()
                .all(|c| c.face.weight >= 600 && !c.face.italic)
        );
    }

    #[test]
    fn ranking_leaves_out_fonts_without_the_script() {
        let library = bundled();
        let style = StyleMetrics::of(
            &plex("ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf"),
            0,
        )
        .unwrap();
        let ranked = rank_similar(
            &library,
            &SimilarQuery {
                text: "سلام",
                style,
                max_results: 10,
            },
        );
        assert!(!ranked.is_empty());
        assert!(ranked.iter().all(|c| c.face.family.contains("Arabic")));
        assert!(ranked[0].coverage.is_full());
        assert_eq!(ranked[0].embedding, Embedding::Installable);
    }

    #[test]
    fn malformed_style_input_is_an_error() {
        assert!(matches!(
            StyleMetrics::of(b"\0\x01\0\0junk", 0),
            Err(FontError::Malformed { .. })
        ));
        let mut library = FontLibrary::new();
        assert!(
            library
                .add_bytes(vec![0; 64], FontOrigin::Installed)
                .is_err()
        );
        assert_eq!(
            find_same_font(&library, &query("X", &[])),
            SameFont::NotFound
        );
    }
}
