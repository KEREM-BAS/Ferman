//! The scripts a face can draw, a11-1d's coverage chips: read from the font's character map, never
//! guessed from its name.

use skrifa::{FontRef, MetadataProvider};

/// A script of a11-1d's chips, in their order.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Script {
    /// TR: the Turkish letters.
    Turkish,
    /// LX: Latin Extended-A.
    LatinExtended,
    /// CY: Cyrillic.
    Cyrillic,
    /// GR: Greek.
    Greek,
    /// AR: Arabic.
    Arabic,
    /// HE: Hebrew.
    Hebrew,
    /// DV: Devanagari.
    Devanagari,
    /// CJK: Chinese, Japanese and Korean Han characters.
    Cjk,
}

impl Script {
    /// Every script, in the chips' order.
    pub const ALL: [Self; 8] = [
        Self::Turkish,
        Self::LatinExtended,
        Self::Cyrillic,
        Self::Greek,
        Self::Arabic,
        Self::Hebrew,
        Self::Devanagari,
        Self::Cjk,
    ];

    /// The letters a face must draw to cover the script: the script's basic alphabet, or for
    /// Latin Extended-A the letters of the Central European languages, and for CJK common Han
    /// characters.
    fn letters(self) -> &'static str {
        match self {
            Self::Turkish => "ÇçĞğİıÖöŞşÜü",
            Self::LatinExtended => "ĀāĂăĄąĆćČčĎďĐđĒēĘęĚěĹĺĽľŁłŃńŇňŐőŔŕŘřŚśŠšŢţŤťŮůŰűŹźŻżŽž",
            Self::Cyrillic => "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя",
            Self::Greek => "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩαβγδεζηθικλμνξοπρστυφχψως",
            Self::Arabic => "ءآأؤإئابةتثجحخدذرزسشصضطظعغفقكلمنهوىي",
            Self::Hebrew => "אבגדהוזחטיךכלםמןנסעףפץצקרשת",
            Self::Devanagari => "अआइईउऊएऐओऔकखगघङचछजझञटठडढणतथदधनपफबभमयरलवशषसह",
            Self::Cjk => "的一是不了人我在有他这中大来上国个到说们日本語",
        }
    }
}

/// The scripts the face `index` of the font file `data` covers: those whose every letter its
/// character map draws. None for data that is not a font.
#[must_use]
pub fn scripts_of(data: &[u8], index: u32) -> Vec<Script> {
    let Ok(font) = FontRef::from_index(data, index) else {
        return Vec::new();
    };
    let charmap = font.charmap();
    Script::ALL
        .into_iter()
        .filter(|script| {
            script
                .letters()
                .chars()
                .all(|c| charmap.map(c).is_some_and(|glyph| glyph.to_u32() != 0))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_fonts::plex;

    #[test]
    fn coverage_is_read_from_the_character_map() {
        assert_eq!(
            scripts_of(&plex("ibm-plex-sans/IBMPlexSans-Regular.ttf"), 0),
            [
                Script::Turkish,
                Script::LatinExtended,
                Script::Cyrillic,
                Script::Greek
            ]
        );
        // The Arabic face carries ASCII and Latin-1 but not the Turkish letters (G64).
        let arabic = scripts_of(
            &plex("ibm-plex-sans-arabic/IBMPlexSansArabic-Regular.ttf"),
            0,
        );
        assert!(arabic.contains(&Script::Arabic));
        assert!(!arabic.contains(&Script::Turkish));
    }

    #[test]
    fn data_that_is_not_a_font_covers_nothing() {
        assert!(scripts_of(b"not a font", 0).is_empty());
    }
}
