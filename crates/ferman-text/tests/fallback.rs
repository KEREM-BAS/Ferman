//! Missing-glyph steps 2 and 3 (ROADMAP §7 step 6, ADR 0006) on the edit corpus, with font
//! libraries filled here from `app/assets/fonts` and `build/corpus-fonts`, never from the
//! machine's fonts: kira-tr's Madde 6 in EB Garamond, whose subsets have no "ğ" (E02, E03), and
//! edit-e05-fstype, whose program forbids embedding (E05). The saved files and their renders are
//! checked in ferman-api's `edit_cases`.
// Test helpers fail loudly.
#![allow(
    clippy::panic,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::path::PathBuf;
use std::sync::Arc;

use ferman_core::{Document, OpenOptions, Source, open};
use ferman_fonts::{FontLibrary, FontOrigin, ScanLimits};
use ferman_text::{
    EditContext, FontChoice, FontSources, MissingReason, Outcome, SubstitutionKind, TextBlock,
    Unsupported, rewrite_block_fonts, text_page,
};

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn document(name: &str) -> Document {
    let bytes = std::fs::read(root().join(format!("tests/corpus/generated/{name}.pdf"))).unwrap();
    open(
        &Source::from_bytes(Arc::from(bytes)),
        &OpenOptions::default(),
    )
    .unwrap()
}

/// The bundled fonts.
fn bundled() -> FontLibrary {
    let mut library = FontLibrary::new();
    library.add_dir(
        &root().join("app/assets/fonts"),
        FontOrigin::Bundled,
        &ScanLimits::default(),
    );
    library
}

/// EB Garamond from `build/corpus-fonts`, or `None` (with a note) before
/// `tools/corpus/fetch-fonts.sh` fetched it.
fn garamond() -> Option<Vec<u8>> {
    let path = root().join("build/corpus-fonts/EBGaramond-VF.ttf");
    let data = std::fs::read(&path).ok();
    if data.is_none() {
        use std::io::Write as _;
        let _ = writeln!(
            std::io::stderr(),
            "skipped: EBGaramond-VF.ttf is not in build/corpus-fonts (run tools/corpus/fetch-fonts.sh)"
        );
    }
    data
}

/// `font` with `OS/2.fsType` set to `fs_type`.
fn with_fs_type(mut font: Vec<u8>, fs_type: u16) -> Vec<u8> {
    let tables = u16::from_be_bytes([font[4], font[5]]) as usize;
    for at in (12..12 + 16 * tables).step_by(16) {
        if &font[at..at + 4] == b"OS/2" {
            let offset = u32::from_be_bytes(font[at + 8..at + 12].try_into().unwrap()) as usize;
            font[offset + 8..offset + 10].copy_from_slice(&fs_type.to_be_bytes());
            return font;
        }
    }
    panic!("no OS/2 table");
}

fn block(doc: &Document, needle: &str) -> TextBlock {
    text_page(doc, 0, &EditContext::default())
        .unwrap()
        .blocks
        .into_iter()
        .find(|block| block.lines.iter().any(|line| line.text.contains(needle)))
        .unwrap()
}

/// Madde 6 with the sentence a3-3a types, whose "ğ" EB Garamond's subset lacks.
fn madde_6(block: &TextBlock) -> String {
    let text: Vec<&str> = block.lines.iter().map(|line| line.text.as_str()).collect();
    format!("{} Ortak alan kuralları değiştirilemez.", text.join(" "))
}

fn rewrite(doc: &Document, block: &TextBlock, text: &str, sources: &FontSources<'_>) -> Outcome {
    rewrite_block_fonts(doc, None, 0, block, text, &[], None, sources).unwrap()
}

#[test]
fn e02_step_3_offers_similar_fonts_and_draws_the_closest_until_chosen() {
    let doc = document("kira-tr");
    let target = block(&doc, "Olağan bakım");
    let text = madde_6(&target);
    let library = bundled();
    let ask = FontSources {
        library: Some(&library),
        ask: true,
        choice: None,
        ..FontSources::default()
    };
    // "Ask each time": nothing is written.
    let Outcome::MissingGlyphs(missing) = rewrite(&doc, &target, &text, &ask) else {
        panic!("written without a choice");
    };
    let at = text.rfind('ğ').unwrap();
    assert_eq!(missing.chars, [('ğ', at)]);
    assert_eq!(missing.font, "EBGaramond-Regular");
    assert_eq!(missing.reason, MissingReason::NotInstalled);
    assert!(!missing.bold && !missing.italic);
    let first = &missing.candidates[0];
    assert!(first.usable(), "{first:?}");
    // The page's own Plex Serif is offered among the embedded fonts, the bundled one too.
    for origin in [FontOrigin::Embedded, FontOrigin::Bundled] {
        assert!(
            missing
                .candidates
                .iter()
                .any(|c| c.origin == origin && c.family == "IBM Plex Serif"),
            "{origin:?}: {:?}",
            missing.candidates
        );
    }
    let plex = missing
        .candidates
        .iter()
        .find(|c| c.origin == FontOrigin::Bundled && c.family == "IBM Plex Serif")
        .unwrap();
    assert_eq!(plex.preview, "Ğğ İı Şş Çç Öö Üü");
    // Never bold or italic for regular text.
    assert!(
        missing
            .candidates
            .iter()
            .all(|c| !c.postscript_name.contains("Italic") && !c.postscript_name.contains("Semi"))
    );

    // The default draws the closest candidate and says the choice is still open.
    let closest = FontSources { ask: false, ..ask };
    let Outcome::Rewritten(provisional) = rewrite(&doc, &target, &text, &closest) else {
        panic!("not drawn");
    };
    assert_eq!(provisional.pending.as_ref(), Some(&missing));
    let [substitution] = provisional.substitutions.as_slice() else {
        panic!("{:?}", provisional.substitutions);
    };
    assert_eq!(substitution.kind, SubstitutionKind::Similar);
    assert_eq!(substitution.chars, "ğ");
    assert_eq!(substitution.from, "EBGaramond-Regular");
    assert_eq!(substitution.to, first.postscript_name);
    assert_eq!(provisional.new_fonts.len(), 1);

    // Choosing the bundled Plex Serif, and keeping the closest, write without a pending choice.
    let chosen = FontChoice::Font {
        origin: FontOrigin::Bundled,
        postscript_name: plex.postscript_name.clone(),
    };
    for choice in [chosen, FontChoice::KeepAsIs] {
        let sources = FontSources {
            choice: Some(&choice),
            ..ask
        };
        let Outcome::Rewritten(written) = rewrite(&doc, &target, &text, &sources) else {
            panic!("{choice:?} not written");
        };
        assert!(written.pending.is_none());
        assert_eq!(written.substitutions.len(), 1);
        let font = &written.new_fonts[0];
        assert!(font.base_font.contains('+'), "{}", font.base_font);
        assert_eq!(font.widths.len(), 1);
    }
}

#[test]
fn e03_step_2_takes_the_glyph_from_the_same_font() {
    let Some(garamond) = garamond() else {
        return;
    };
    let doc = document("kira-tr");
    let target = block(&doc, "Olağan bakım");
    let text = madde_6(&target);
    let mut library = bundled();
    library.add_bytes(garamond, FontOrigin::Installed).unwrap();
    let sources = FontSources {
        library: Some(&library),
        ask: true,
        choice: None,
        ..FontSources::default()
    };
    let Outcome::Rewritten(rewrite) = rewrite(&doc, &target, &text, &sources) else {
        panic!("not written");
    };
    assert!(rewrite.pending.is_none());
    let [substitution] = rewrite.substitutions.as_slice() else {
        panic!("{:?}", rewrite.substitutions);
    };
    assert_eq!(substitution.kind, SubstitutionKind::SameFont);
    assert_eq!(substitution.origin, FontOrigin::Installed);
    assert_eq!(substitution.chars, "ğ");
    assert_eq!(substitution.to, "EBGaramond-Regular");
}

#[test]
fn e05_a_font_that_forbids_embedding_falls_to_step_3_with_the_reason() {
    let Some(garamond) = garamond() else {
        return;
    };
    let doc = document("edit-e05-fstype");
    let target = block(&doc, "Ortak giderler");
    let text: Vec<String> = target
        .lines
        .iter()
        .map(|line| line.text.replacen("birlikte", "birlikte değişir", 1))
        .collect();
    let text = text.join("\n");
    let mut library = bundled();
    library
        .add_bytes(with_fs_type(garamond, 2), FontOrigin::Installed)
        .unwrap();
    let sources = FontSources {
        library: Some(&library),
        ask: true,
        choice: None,
        ..FontSources::default()
    };
    let Outcome::MissingGlyphs(missing) = rewrite(&doc, &target, &text, &sources) else {
        panic!("written");
    };
    assert!(
        matches!(&missing.reason, MissingReason::NotEmbeddable { font, .. } if font == "EBGaramond-Regular"),
        "{:?}",
        missing.reason
    );
    // The program's own fsType: no glyph of it is reused, so every new character is missing.
    let new: String = missing.chars.iter().map(|(c, _)| *c).collect();
    assert_eq!(new, "değişir");
    assert!(
        missing
            .candidates
            .iter()
            .all(|c| c.origin != FontOrigin::Embedded)
    );
    // The installed copy is listed with its permission, and the closest usable one is drawn.
    assert!(
        !missing.candidates[0].usable(),
        "{:?}",
        missing.candidates[0]
    );
    let closest = FontChoice::KeepAsIs;
    let keep = FontSources {
        choice: Some(&closest),
        ..sources
    };
    let Outcome::Rewritten(written) = rewrite(&doc, &target, &text, &keep) else {
        panic!("not written");
    };
    assert_eq!(written.substitutions[0].to, "IBMPlexSerif-Regular");
    assert_eq!(written.substitutions[0].chars, "değişr");
}

#[test]
fn a_block_of_a_form_gets_no_new_font() {
    // A new font goes into the page's resources, which the form's content cannot name.
    let doc = document("edit-e20-form-twice");
    let target = block(&doc, "ALINDI");
    let text: Vec<&str> = target.lines.iter().map(|line| line.text.as_str()).collect();
    let text = text.join("\n").replacen("ALINDI", "ALINDIЖ", 1);
    let library = bundled();
    let sources = FontSources {
        library: Some(&library),
        ask: false,
        choice: None,
        ..FontSources::default()
    };
    let outcome = rewrite(&doc, &target, &text, &sources);
    assert_eq!(
        outcome,
        Outcome::Unsupported(Unsupported::CompositeFont),
        "{outcome:?}"
    );
}
