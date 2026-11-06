//! Shaping (ADR 0007): a run of text in one font, script, direction and language becomes glyphs
//! with their clusters, advances and offsets, through the font's `GSUB` and `GPOS` tables.
//!
//! The shaper is harfrust, behind the crate-private [`Shaper`] trait: nothing outside this module
//! names it, so a change of shaper touches this file only. Arabic gets its joining forms, lam-alef
//! ligatures and mark positions; ZWNJ breaks a join, as Persian needs; vertical text
//! ([`Direction::TopToBottom`]) gets the `vert` and `vrt2` forms; kerning is on as the font
//! defines it. Coverage is per shaped glyph ([`ShapedRun::missing_clusters`]): a contextual form a
//! subset lacks shows as `.notdef`, so it is a missing glyph like any other (ADR 0006).
// A parser module: the program and the text come from a file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use crate::FontError;
use crate::program::GlyphId;
use crate::type1::MAX_PROGRAM;

/// The longest run [`ShapingFont::shape`] takes, in bytes of UTF-8. A block's text is far
/// shorter; the limit bounds the work for a damaged or hostile document.
pub const MAX_RUN_BYTES: usize = 64 * 1024;

/// The direction a run is shaped in.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Direction {
    /// Horizontal, left to right.
    LeftToRight,
    /// Horizontal, right to left (Arabic, Persian, Hebrew).
    RightToLeft,
    /// Vertical, top to bottom (vertical CJK): the font's vertical forms and metrics.
    TopToBottom,
}

/// An OpenType feature setting for a run, such as `liga` off or `ss01` on.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct FeatureSetting {
    /// The feature tag, such as `*b"kern"`.
    pub tag: [u8; 4],
    /// 0 turns it off, 1 on; larger values pick an alternate.
    pub value: u32,
}

/// What to shape: the text and its properties.
#[derive(Debug, Clone, Copy)]
pub struct ShapeRequest<'a> {
    /// The text of the run, in logical order.
    pub text: &'a str,
    /// The direction of the run, after the bidi algorithm.
    pub direction: Direction,
    /// The ISO 15924 script tag, such as `*b"Arab"`; `None` guesses it from the text.
    pub script: Option<[u8; 4]>,
    /// The BCP 47 language, such as `"fa"` (Persian forms of the Arabic script); `None` for none.
    pub language: Option<&'a str>,
    /// Features beyond the shaper's defaults for the script and direction.
    pub features: &'a [FeatureSetting],
}

impl<'a> ShapeRequest<'a> {
    /// A request for `text` in `direction` with the script guessed, no language and the
    /// default features.
    #[must_use]
    pub fn new(text: &'a str, direction: Direction) -> Self {
        Self {
            text,
            direction,
            script: None,
            language: None,
            features: &[],
        }
    }
}

/// One shaped glyph, in font units.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ShapedGlyph {
    /// The glyph in the font program; 0 (`.notdef`) when the font has none for the cluster.
    pub glyph: GlyphId,
    /// The byte offset in the run's text where the glyph's cluster starts.
    pub cluster: usize,
    /// The horizontal advance (0 in vertical text).
    pub x_advance: i32,
    /// The vertical advance: negative downwards in vertical text, 0 in horizontal text.
    pub y_advance: i32,
    /// The horizontal offset from the pen position (mark positioning, kerning in vertical text).
    pub x_offset: i32,
    /// The vertical offset from the pen position.
    pub y_offset: i32,
}

/// The glyphs of a shaped run, in visual order: a right-to-left run comes last character first.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ShapedRun {
    /// The glyphs, in visual order.
    pub glyphs: Vec<ShapedGlyph>,
    /// The units per em of the font, the scale of the advances and offsets.
    pub units_per_em: u16,
}

impl ShapedRun {
    /// The byte offsets of the clusters with a `.notdef` glyph, ascending and without
    /// repeats. Empty when the font covers the run.
    #[must_use]
    pub fn missing_clusters(&self) -> Vec<usize> {
        let mut clusters: Vec<usize> = self
            .glyphs
            .iter()
            .filter(|glyph| glyph.glyph.0 == 0)
            .map(|glyph| glyph.cluster)
            .collect();
        clusters.sort_unstable();
        clusters.dedup();
        clusters
    }

    /// The text each glyph stands for, for a ToUnicode map: the first glyph of a cluster
    /// carries the cluster's text (a lam-alef ligature carries both letters), the other glyphs
    /// of the cluster an empty string. `text` is the run's text.
    #[must_use]
    pub fn glyph_texts(&self, text: &str) -> Vec<(GlyphId, String)> {
        let mut starts: Vec<usize> = self.glyphs.iter().map(|glyph| glyph.cluster).collect();
        starts.push(text.len());
        starts.sort_unstable();
        starts.dedup();
        let mut seen = std::collections::BTreeSet::new();
        self.glyphs
            .iter()
            .map(|glyph| {
                let start = glyph.cluster;
                let end = starts
                    .iter()
                    .copied()
                    .find(|&next| next > start)
                    .unwrap_or(text.len());
                let cluster = if seen.insert(start) {
                    text.get(start..end).unwrap_or_default().to_owned()
                } else {
                    String::new()
                };
                (glyph.glyph, cluster)
            })
            .collect()
    }
}

/// A shaper over one font program. Crate-private, so the shaping crate stays in this module
/// (ADR 0007).
trait Shaper: Send + Sync {
    fn shape(&self, request: &ShapeRequest<'_>) -> Result<ShapedRun, FontError>;
}

/// A font program ready for shaping. Build it once per font and shape many runs with it.
pub struct ShapingFont {
    shaper: Box<dyn Shaper>,
}

impl std::fmt::Debug for ShapingFont {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ShapingFont").finish_non_exhaustive()
    }
}

impl ShapingFont {
    /// Reads the font at `index` of `data` (0 unless it is a collection). An sfnt shapes with its
    /// layout tables; a bare CFF or Type1 program has none and shapes by its nominal glyphs only.
    ///
    /// # Errors
    ///
    /// [`FontError::ProgramTooLarge`] over [`MAX_PROGRAM`], [`FontError::Malformed`] for bytes
    /// that hold no font.
    pub fn new(data: Vec<u8>, index: u32) -> Result<Self, FontError> {
        Self::new_at(data, index, None)
    }

    /// [`ShapingFont::new`] at a named instance of a variable font: its advances and positions.
    ///
    /// # Errors
    ///
    /// As [`ShapingFont::new`].
    pub fn new_at(
        data: Vec<u8>,
        index: u32,
        instance: Option<&crate::FaceInstance>,
    ) -> Result<Self, FontError> {
        if data.len() > MAX_PROGRAM {
            return Err(FontError::ProgramTooLarge {
                size: u64::try_from(data.len()).unwrap_or(u64::MAX),
                max: u64::try_from(MAX_PROGRAM).unwrap_or(u64::MAX),
            });
        }
        let font = harfrust::Font::new(data, index).ok_or(FontError::Malformed {
            context: "font program for shaping",
        })?;
        if font.units_per_em() == 0 {
            return Err(FontError::Malformed {
                context: "units per em",
            });
        }
        let font = match instance {
            Some(instance) => font
                .instance_builder()
                .variations(instance.coordinates.iter().map(|(tag, _)| {
                    harfrust::font::Variation::new(
                        harfrust::Tag::new(tag),
                        instance.value(tag).unwrap_or_default(),
                    )
                }))
                .build(),
            None => font,
        };
        Ok(Self {
            shaper: Box::new(Harfrust { font }),
        })
    }

    /// Shapes one run.
    ///
    /// # Errors
    ///
    /// [`FontError::RunTooLong`] for a run over [`MAX_RUN_BYTES`], [`FontError::Shaping`] when
    /// the shaper refuses the run.
    pub fn shape(&self, request: &ShapeRequest<'_>) -> Result<ShapedRun, FontError> {
        if request.text.len() > MAX_RUN_BYTES {
            return Err(FontError::RunTooLong {
                size: request.text.len(),
                max: MAX_RUN_BYTES,
            });
        }
        self.shaper.shape(request)
    }
}

struct Harfrust {
    font: harfrust::Font,
}

impl Shaper for Harfrust {
    fn shape(&self, request: &ShapeRequest<'_>) -> Result<ShapedRun, FontError> {
        let mut buffer = harfrust::Buffer::new();
        buffer.push_str(request.text);
        // A mark keeps a cluster of its own (only ligatures merge), so each glyph's ToUnicode text
        // is exactly the characters it draws.
        buffer.set_cluster_level(harfrust::ClusterLevel::MonotoneCharacters);
        buffer.set_direction(match request.direction {
            Direction::LeftToRight => harfrust::Direction::LeftToRight,
            Direction::RightToLeft => harfrust::Direction::RightToLeft,
            Direction::TopToBottom => harfrust::Direction::TopToBottom,
        });
        if let Some(tag) = request.script {
            buffer.set_script(harfrust::Script::from_iso15924_tag(harfrust::Tag::new(
                &tag,
            )));
        }
        if let Some(language) = request.language {
            buffer.set_language(harfrust::Language::new(language));
        }
        // Fills in what the request left open (the script) and keeps what it set.
        buffer.guess_segment_properties();
        let features: Vec<harfrust::Feature> = request
            .features
            .iter()
            .map(|setting| {
                harfrust::Feature::new(harfrust::Tag::new(&setting.tag), setting.value, ..)
            })
            .collect();
        let shaper = harfrust::ShaperFont::new(&self.font);
        harfrust::shape(
            &shaper,
            &mut buffer,
            harfrust::ShapeOptions::new().features(&features),
        )
        .map_err(|_| FontError::Shaping)?;
        let glyphs = buffer
            .glyph_infos()
            .iter()
            .zip(buffer.glyph_positions())
            .map(|(info, position)| {
                Ok(ShapedGlyph {
                    glyph: GlyphId(info.glyph_id),
                    cluster: usize::try_from(info.cluster).map_err(|_| FontError::Internal {
                        context: "shaped cluster offset",
                    })?,
                    x_advance: position.x_advance,
                    y_advance: position.y_advance,
                    x_offset: position.x_offset,
                    y_offset: position.y_offset,
                })
            })
            .collect::<Result<_, FontError>>()?;
        Ok(ShapedRun {
            glyphs,
            units_per_em: self.font.units_per_em(),
        })
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;
    use crate::FontProgram;
    use crate::test_fonts::{corpus_font, plex};

    fn shape(data: &[u8], text: &str, direction: Direction, language: Option<&str>) -> ShapedRun {
        let font = ShapingFont::new(data.to_vec(), 0).unwrap();
        let request = ShapeRequest {
            language,
            ..ShapeRequest::new(text, direction)
        };
        font.shape(&request).unwrap()
    }

    fn gids(run: &ShapedRun) -> Vec<u32> {
        run.glyphs.iter().map(|glyph| glyph.glyph.0).collect()
    }

    #[test]
    fn turkish_letters_shape_to_their_nominal_glyphs() {
        let data = plex("ibm-plex-sans/IBMPlexSans-Regular.ttf");
        let program = FontProgram::parse(&data).unwrap();
        let run = shape(&data, "ğşİı", Direction::LeftToRight, Some("tr"));
        let nominal: Vec<u32> = "ğşİı"
            .chars()
            .map(|c| program.glyph_for_char(c).unwrap().0)
            .collect();
        assert_eq!(gids(&run), nominal);
        assert!(run.missing_clusters().is_empty());
        assert_eq!(run.units_per_em, 1000);
        // Byte offsets of the clusters: each letter is two bytes of UTF-8.
        let clusters: Vec<usize> = run.glyphs.iter().map(|glyph| glyph.cluster).collect();
        assert_eq!(clusters, [0, 2, 4, 6]);
        assert!(run.glyphs.iter().all(|glyph| glyph.x_advance > 0));
    }

    #[test]
    fn kerning_is_on_by_default_and_can_be_turned_off() {
        let data = plex("ibm-plex-sans/IBMPlexSans-Regular.ttf");
        let font = ShapingFont::new(data, 0).unwrap();
        let width = |features: &[FeatureSetting]| -> i32 {
            let request = ShapeRequest {
                features,
                ..ShapeRequest::new("AVATAR", Direction::LeftToRight)
            };
            font.shape(&request)
                .unwrap()
                .glyphs
                .iter()
                .map(|glyph| glyph.x_advance)
                .sum()
        };
        let off = [FeatureSetting {
            tag: *b"kern",
            value: 0,
        }];
        assert!(width(&[]) < width(&off));
    }

    #[test]
    fn arabic_joins_and_forms_the_lam_alef_ligature() {
        let data = plex("ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf");
        let program = FontProgram::parse(&data).unwrap();
        let isolated = |c: char| program.glyph_for_char(c).unwrap().0;
        // ب alone is its isolated form; inside "ببب" each one is a joining form.
        let alone = shape(&data, "ب", Direction::RightToLeft, None);
        assert_eq!(gids(&alone), [isolated('ب')]);
        let joined = shape(&data, "ببب", Direction::RightToLeft, None);
        let forms = gids(&joined);
        assert_eq!(forms.len(), 3);
        assert!(forms.iter().all(|&gid| gid != isolated('ب') && gid != 0));
        // Visual order: the final form comes first, the initial form last; they differ.
        assert_ne!(forms[0], forms[2]);
        assert_eq!(joined.glyphs[0].cluster, 4);
        assert_eq!(joined.glyphs[2].cluster, 0);
        // لا: one ligature glyph for two letters, which the ToUnicode text keeps together.
        let lam_alef = shape(&data, "لا", Direction::RightToLeft, None);
        assert_eq!(lam_alef.glyphs.len(), 1);
        assert_ne!(lam_alef.glyphs[0].glyph.0, isolated('ل'));
        assert_eq!(
            lam_alef.glyph_texts("لا"),
            [(lam_alef.glyphs[0].glyph, "لا".to_owned())]
        );
    }

    #[test]
    fn arabic_marks_are_positioned_on_their_base() {
        let data = plex("ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf");
        // بَ: the fatha is a mark with no advance of its own, offset onto the beh.
        let run = shape(&data, "بَ", Direction::RightToLeft, None);
        assert!(run.missing_clusters().is_empty());
        let mark = run
            .glyphs
            .iter()
            .find(|glyph| glyph.x_advance == 0)
            .unwrap();
        assert!(mark.x_offset != 0 || mark.y_offset != 0);
        // The mark is its own cluster: the beh's ToUnicode text never swallows the fatha.
        let texts: Vec<String> = run
            .glyph_texts("بَ")
            .into_iter()
            .map(|(_, text)| text)
            .collect();
        assert_eq!(texts.len(), 2);
        assert!(texts.contains(&"ب".to_owned()) && texts.contains(&"\u{64e}".to_owned()));
    }

    #[test]
    fn zwnj_prevents_joining_in_persian() {
        let data = plex("ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf");
        // می‌خواهم: with ZWNJ the meh stays unjoined to the khah; without it, it joins.
        let with = shape(&data, "می\u{200c}خ", Direction::RightToLeft, Some("fa"));
        let without = shape(&data, "میخ", Direction::RightToLeft, Some("fa"));
        let khah = |run: &ShapedRun, text: &str| {
            let at = text.find('خ').unwrap();
            run.glyphs
                .iter()
                .find(|glyph| glyph.cluster == at)
                .unwrap()
                .glyph
        };
        let yeh = |run: &ShapedRun| {
            run.glyphs
                .iter()
                .find(|glyph| glyph.cluster == 2)
                .unwrap()
                .glyph
        };
        assert_ne!(khah(&with, "می\u{200c}خ"), khah(&without, "میخ"));
        assert_ne!(yeh(&with), yeh(&without));
        // The ZWNJ is shaped (to an invisible glyph), never reported missing.
        assert!(with.missing_clusters().is_empty());
    }

    #[test]
    fn hebrew_comes_in_visual_order() {
        let data = plex("ibm-plex-sans-hebrew/IBMPlexSansHebrew-Regular.ttf");
        let program = FontProgram::parse(&data).unwrap();
        let run = shape(&data, "שלום", Direction::RightToLeft, Some("he"));
        let expected: Vec<u32> = "שלום"
            .chars()
            .rev()
            .map(|c| program.glyph_for_char(c).unwrap().0)
            .collect();
        assert_eq!(gids(&run), expected);
        assert_eq!(run.glyphs[0].cluster, 6);
    }

    #[test]
    fn a_glyph_the_font_lacks_is_a_missing_cluster() {
        // IBM Plex Sans has no Arabic: the beh, at byte 1, is .notdef.
        let data = plex("ibm-plex-sans/IBMPlexSans-Regular.ttf");
        let run = shape(&data, "aبc", Direction::LeftToRight, None);
        assert_eq!(run.missing_clusters(), [1]);
    }

    #[test]
    fn vertical_text_takes_the_vertical_forms() {
        let Some(data) = corpus_font("NotoSerifJP-VF.ttf") else {
            return;
        };
        // The long-vowel mark and the ideographic full stop have vertical alternates (vert).
        for text in ["ー", "。", "「"] {
            let horizontal = shape(&data, text, Direction::LeftToRight, Some("ja"));
            let vertical = shape(&data, text, Direction::TopToBottom, Some("ja"));
            assert_ne!(gids(&horizontal), gids(&vertical), "{text}");
            assert_eq!(vertical.glyphs[0].x_advance, 0);
            assert!(vertical.glyphs[0].y_advance < 0);
        }
        // Without vert and vrt2, the nominal glyph stays.
        let font = ShapingFont::new(data.clone(), 0).unwrap();
        let off = [
            FeatureSetting {
                tag: *b"vert",
                value: 0,
            },
            FeatureSetting {
                tag: *b"vrt2",
                value: 0,
            },
        ];
        let request = ShapeRequest {
            features: &off,
            ..ShapeRequest::new("ー", Direction::TopToBottom)
        };
        let horizontal = shape(&data, "ー", Direction::LeftToRight, None);
        assert_eq!(gids(&font.shape(&request).unwrap()), gids(&horizontal));
    }

    #[test]
    fn malformed_bytes_and_long_runs_are_errors() {
        assert!(matches!(
            ShapingFont::new(b"not a font at all".to_vec(), 0),
            Err(FontError::Malformed { .. })
        ));
        assert!(ShapingFont::new(Vec::new(), 0).is_err());
        let font = ShapingFont::new(plex("ibm-plex-sans/IBMPlexSans-Regular.ttf"), 0).unwrap();
        let long = "a".repeat(MAX_RUN_BYTES + 1);
        assert!(matches!(
            font.shape(&ShapeRequest::new(&long, Direction::LeftToRight)),
            Err(FontError::RunTooLong { .. })
        ));
    }
}
