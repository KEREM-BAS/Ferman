//! Simple fonts' encodings (ISO 32000-2 §9.6.5 and Annex D): the base encodings' codes as
//! characters, `/Differences` on top of them, and glyph names as text.
//!
//! Glyph names are read the way ISO 32000-2 §9.10.2 and the Adobe Glyph List specification read
//! them: a suffix after `.` is dropped, `_` joins the parts of a ligature, `uniXXXX` holds groups
//! of four hex digits and `uXXXX` to `uXXXXXX` one code point. Other names come from a table of
//! the Latin names: the base encodings' names and Latin Extended-A, in Unicode order. A font's
//! built-in encoding (an embedded Type1 program, Symbol and ZapfDingbats) arrives with the Type1
//! parser.
// A parser module: names and codes come from files (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::HashMap;
use std::sync::OnceLock;

/// A base encoding a simple font names in `/Encoding` or `/BaseEncoding`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BaseEncoding {
    /// `StandardEncoding`, Type1 fonts' default.
    Standard,
    /// `WinAnsiEncoding`, Windows code page 1252.
    WinAnsi,
    /// `MacRomanEncoding`, Mac OS Roman with `currency` at 0xDB as the PDF standard has it.
    MacRoman,
}

impl BaseEncoding {
    /// The encoding a PDF name such as `WinAnsiEncoding` names.
    #[must_use]
    pub fn from_name(name: &[u8]) -> Option<Self> {
        match name {
            b"StandardEncoding" => Some(Self::Standard),
            b"WinAnsiEncoding" => Some(Self::WinAnsi),
            b"MacRomanEncoding" => Some(Self::MacRoman),
            _ => None,
        }
    }

    /// The character of `code`, or `None` for a code the encoding leaves empty.
    #[must_use]
    pub fn char(self, code: u8) -> Option<char> {
        match (self, code) {
            (_, 0..=0x1F) => None,
            (Self::Standard, 0x27) => Some('\u{2019}'),
            (Self::Standard, 0x60) => Some('\u{2018}'),
            (_, 0x20..=0x7E) => Some(char::from(code)),
            (Self::WinAnsi, 0x80..=0x9F) => WIN_ANSI_HIGH
                .chars()
                .nth(usize::from(code.wrapping_sub(0x80))),
            // Unused codes above 0x20 are the bullet in WinAnsiEncoding (Annex D, note 6).
            (Self::WinAnsi, 0x7F) => Some('•'),
            (Self::WinAnsi, _) => Some(char::from(code)),
            (Self::MacRoman, 0x80..=0xFF) => MAC_ROMAN_HIGH
                .chars()
                .nth(usize::from(code.wrapping_sub(0x80)))
                .filter(|&c| c != '\0'),
            (Self::Standard, _) => STANDARD_HIGH
                .iter()
                .find(|(at, _)| *at == code)
                .map(|&(_, c)| c),
            (Self::MacRoman, _) => None,
        }
    }
}

/// WinAnsiEncoding's 0x80 to 0x9F; the five unused codes are the bullet.
const WIN_ANSI_HIGH: &str = "€•‚ƒ„…†‡ˆ‰Š‹Œ•Ž••‘’“”•–—˜™š›œ•žŸ";

/// MacRomanEncoding's 0x80 to 0xFF; `\0` marks the unused 0xF0.
const MAC_ROMAN_HIGH: &str = "ÄÅÇÉÑÖÜáàâäãåçéèêëíìîïñóòôöõúùûü†°¢£§•¶ß®©™´¨≠ÆØ∞±≤≥¥µ∂∑∏π∫ªºΩæø¿¡¬√ƒ≈∆«»…\u{A0}ÀÃÕŒœ–—“”‘’÷◊ÿŸ⁄¤‹›ﬁﬂ‡·‚„‰ÂÊÁËÈÍÎÏÌÓÔ\0ÒÚÛÙıˆ˜¯˘˙˚¸˝˛ˇ";

/// StandardEncoding's codes from 0xA1.
const STANDARD_HIGH: [(u8, char); 54] = [
    (0xA1, '¡'),
    (0xA2, '¢'),
    (0xA3, '£'),
    (0xA4, '⁄'),
    (0xA5, '¥'),
    (0xA6, 'ƒ'),
    (0xA7, '§'),
    (0xA8, '¤'),
    (0xA9, '\''),
    (0xAA, '“'),
    (0xAB, '«'),
    (0xAC, '‹'),
    (0xAD, '›'),
    (0xAE, 'ﬁ'),
    (0xAF, 'ﬂ'),
    (0xB1, '–'),
    (0xB2, '†'),
    (0xB3, '‡'),
    (0xB4, '·'),
    (0xB6, '¶'),
    (0xB7, '•'),
    (0xB8, '‚'),
    (0xB9, '„'),
    (0xBA, '”'),
    (0xBB, '»'),
    (0xBC, '…'),
    (0xBD, '‰'),
    (0xBF, '¿'),
    (0xC1, '`'),
    (0xC2, '´'),
    (0xC3, 'ˆ'),
    (0xC4, '˜'),
    (0xC5, '¯'),
    (0xC6, '˘'),
    (0xC7, '˙'),
    (0xC8, '¨'),
    (0xCA, '˚'),
    (0xCB, '¸'),
    (0xCD, '˝'),
    (0xCE, '˛'),
    (0xCF, 'ˇ'),
    (0xD0, '—'),
    (0xE1, 'Æ'),
    (0xE3, 'ª'),
    (0xE8, 'Ł'),
    (0xE9, 'Ø'),
    (0xEA, 'Œ'),
    (0xEB, 'º'),
    (0xF1, 'æ'),
    (0xF5, 'ı'),
    (0xF8, 'ł'),
    (0xF9, 'ø'),
    (0xFA, 'œ'),
    (0xFB, 'ß'),
];

/// A simple font's codes as text: a base encoding with `/Differences` on top.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SimpleEncoding {
    texts: Vec<Option<String>>,
}

impl SimpleEncoding {
    /// `base` (none for a symbolic font without one) with `differences`, each a code and the glyph
    /// name it now has.
    #[must_use]
    pub fn new<'a>(
        base: Option<BaseEncoding>,
        differences: impl IntoIterator<Item = (u8, &'a str)>,
    ) -> Self {
        let mut texts: Vec<Option<String>> = (0..=u8::MAX)
            .map(|code| base.and_then(|base| base.char(code)).map(String::from))
            .collect();
        for (code, name) in differences {
            if let Some(slot) = texts.get_mut(usize::from(code)) {
                *slot = glyph_text(name);
            }
        }
        Self { texts }
    }

    /// The text of `code`.
    #[must_use]
    pub fn text(&self, code: u8) -> Option<&str> {
        self.texts.get(usize::from(code))?.as_deref()
    }
}

/// The text a glyph name stands for, or `None` for a name it cannot tell (such as `g123`).
#[must_use]
pub fn glyph_text(name: &str) -> Option<String> {
    let name = name.split('.').next().unwrap_or_default();
    if name.is_empty() {
        return None;
    }
    let mut text = String::new();
    for part in name.split('_') {
        text.push_str(&component(part)?);
    }
    Some(text)
}

/// One part of a ligature's name.
fn component(part: &str) -> Option<String> {
    if let Some(&c) = names().get(part) {
        return Some(c.to_string());
    }
    if let Some(hex) = part.strip_prefix("uni")
        && !hex.is_empty()
        && hex.len() % 4 == 0
    {
        return hex
            .as_bytes()
            .chunks(4)
            .map(|four| scalar(std::str::from_utf8(four).ok()?))
            .collect();
    }
    if let Some(hex) = part.strip_prefix('u')
        && (4..=6).contains(&hex.len())
    {
        return scalar(hex).map(String::from);
    }
    None
}

/// The character with the hex code point `hex`, not a surrogate.
fn scalar(hex: &str) -> Option<char> {
    if !hex
        .bytes()
        .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_lowercase())
    {
        return None;
    }
    char::from_u32(u32::from_str_radix(hex, 16).ok()?)
}

/// Latin-1's names from U+00A0, in order.
const LATIN_1: [&str; 96] = [
    "nbspace",
    "exclamdown",
    "cent",
    "sterling",
    "currency",
    "yen",
    "brokenbar",
    "section",
    "dieresis",
    "copyright",
    "ordfeminine",
    "guillemotleft",
    "logicalnot",
    "sfthyphen",
    "registered",
    "macron",
    "degree",
    "plusminus",
    "twosuperior",
    "threesuperior",
    "acute",
    "mu",
    "paragraph",
    "periodcentered",
    "cedilla",
    "onesuperior",
    "ordmasculine",
    "guillemotright",
    "onequarter",
    "onehalf",
    "threequarters",
    "questiondown",
    "Agrave",
    "Aacute",
    "Acircumflex",
    "Atilde",
    "Adieresis",
    "Aring",
    "AE",
    "Ccedilla",
    "Egrave",
    "Eacute",
    "Ecircumflex",
    "Edieresis",
    "Igrave",
    "Iacute",
    "Icircumflex",
    "Idieresis",
    "Eth",
    "Ntilde",
    "Ograve",
    "Oacute",
    "Ocircumflex",
    "Otilde",
    "Odieresis",
    "multiply",
    "Oslash",
    "Ugrave",
    "Uacute",
    "Ucircumflex",
    "Udieresis",
    "Yacute",
    "Thorn",
    "germandbls",
    "agrave",
    "aacute",
    "acircumflex",
    "atilde",
    "adieresis",
    "aring",
    "ae",
    "ccedilla",
    "egrave",
    "eacute",
    "ecircumflex",
    "edieresis",
    "igrave",
    "iacute",
    "icircumflex",
    "idieresis",
    "eth",
    "ntilde",
    "ograve",
    "oacute",
    "ocircumflex",
    "otilde",
    "odieresis",
    "divide",
    "oslash",
    "ugrave",
    "uacute",
    "ucircumflex",
    "udieresis",
    "yacute",
    "thorn",
    "ydieresis",
];

/// Latin Extended-A's names from U+0100, in order.
const LATIN_EXTENDED_A: [&str; 128] = [
    "Amacron",
    "amacron",
    "Abreve",
    "abreve",
    "Aogonek",
    "aogonek",
    "Cacute",
    "cacute",
    "Ccircumflex",
    "ccircumflex",
    "Cdotaccent",
    "cdotaccent",
    "Ccaron",
    "ccaron",
    "Dcaron",
    "dcaron",
    "Dcroat",
    "dcroat",
    "Emacron",
    "emacron",
    "Ebreve",
    "ebreve",
    "Edotaccent",
    "edotaccent",
    "Eogonek",
    "eogonek",
    "Ecaron",
    "ecaron",
    "Gcircumflex",
    "gcircumflex",
    "Gbreve",
    "gbreve",
    "Gdotaccent",
    "gdotaccent",
    "Gcommaaccent",
    "gcommaaccent",
    "Hcircumflex",
    "hcircumflex",
    "Hbar",
    "hbar",
    "Itilde",
    "itilde",
    "Imacron",
    "imacron",
    "Ibreve",
    "ibreve",
    "Iogonek",
    "iogonek",
    "Idotaccent",
    "dotlessi",
    "IJ",
    "ij",
    "Jcircumflex",
    "jcircumflex",
    "Kcommaaccent",
    "kcommaaccent",
    "kgreenlandic",
    "Lacute",
    "lacute",
    "Lcommaaccent",
    "lcommaaccent",
    "Lcaron",
    "lcaron",
    "Ldot",
    "ldot",
    "Lslash",
    "lslash",
    "Nacute",
    "nacute",
    "Ncommaaccent",
    "ncommaaccent",
    "Ncaron",
    "ncaron",
    "napostrophe",
    "Eng",
    "eng",
    "Omacron",
    "omacron",
    "Obreve",
    "obreve",
    "Ohungarumlaut",
    "ohungarumlaut",
    "OE",
    "oe",
    "Racute",
    "racute",
    "Rcommaaccent",
    "rcommaaccent",
    "Rcaron",
    "rcaron",
    "Sacute",
    "sacute",
    "Scircumflex",
    "scircumflex",
    "Scedilla",
    "scedilla",
    "Scaron",
    "scaron",
    "Tcommaaccent",
    "tcommaaccent",
    "Tcaron",
    "tcaron",
    "Tbar",
    "tbar",
    "Utilde",
    "utilde",
    "Umacron",
    "umacron",
    "Ubreve",
    "ubreve",
    "Uring",
    "uring",
    "Uhungarumlaut",
    "uhungarumlaut",
    "Uogonek",
    "uogonek",
    "Wcircumflex",
    "wcircumflex",
    "Ycircumflex",
    "ycircumflex",
    "Ydieresis",
    "Zacute",
    "zacute",
    "Zdotaccent",
    "zdotaccent",
    "Zcaron",
    "zcaron",
    "longs",
];

/// ASCII's punctuation and digit names, by character; the letters are their own names.
const ASCII: [(&str, char); 43] = [
    ("space", ' '),
    ("exclam", '!'),
    ("quotedbl", '"'),
    ("numbersign", '#'),
    ("dollar", '$'),
    ("percent", '%'),
    ("ampersand", '&'),
    ("quotesingle", '\''),
    ("parenleft", '('),
    ("parenright", ')'),
    ("asterisk", '*'),
    ("plus", '+'),
    ("comma", ','),
    ("hyphen", '-'),
    ("period", '.'),
    ("slash", '/'),
    ("zero", '0'),
    ("one", '1'),
    ("two", '2'),
    ("three", '3'),
    ("four", '4'),
    ("five", '5'),
    ("six", '6'),
    ("seven", '7'),
    ("eight", '8'),
    ("nine", '9'),
    ("colon", ':'),
    ("semicolon", ';'),
    ("less", '<'),
    ("equal", '='),
    ("greater", '>'),
    ("question", '?'),
    ("at", '@'),
    ("bracketleft", '['),
    ("backslash", '\\'),
    ("bracketright", ']'),
    ("asciicircum", '^'),
    ("underscore", '_'),
    ("grave", '`'),
    ("braceleft", '{'),
    ("bar", '|'),
    ("braceright", '}'),
    ("asciitilde", '~'),
];

/// The other names of the base encodings, Symbol's that MacRoman borrows, and the ligatures.
const OTHERS: [(&str, char); 45] = [
    ("quoteleft", '‘'),
    ("quoteright", '’'),
    ("quotedblleft", '“'),
    ("quotedblright", '”'),
    ("quotesinglbase", '‚'),
    ("quotedblbase", '„'),
    ("guilsinglleft", '‹'),
    ("guilsinglright", '›'),
    ("Euro", '€'),
    ("florin", 'ƒ'),
    ("ellipsis", '…'),
    ("dagger", '†'),
    ("daggerdbl", '‡'),
    ("circumflex", 'ˆ'),
    ("perthousand", '‰'),
    ("bullet", '•'),
    ("endash", '–'),
    ("emdash", '—'),
    ("tilde", '˜'),
    ("trademark", '™'),
    ("fraction", '⁄'),
    ("fi", 'ﬁ'),
    ("fl", 'ﬂ'),
    ("breve", '˘'),
    ("dotaccent", '˙'),
    ("ring", '˚'),
    ("hungarumlaut", '˝'),
    ("ogonek", '˛'),
    ("caron", 'ˇ'),
    ("minus", '−'),
    ("Delta", '∆'),
    ("lozenge", '◊'),
    ("notequal", '≠'),
    ("infinity", '∞'),
    ("lessequal", '≤'),
    ("greaterequal", '≥'),
    ("partialdiff", '∂'),
    ("summation", '∑'),
    ("product", '∏'),
    ("pi", 'π'),
    ("integral", '∫'),
    ("Omega", 'Ω'),
    ("radical", '√'),
    ("approxequal", '≈'),
    ("nonbreakingspace", '\u{A0}'),
];

/// Every name of the table, built once.
fn names() -> &'static HashMap<&'static str, char> {
    static NAMES: OnceLock<HashMap<&'static str, char>> = OnceLock::new();
    NAMES.get_or_init(|| {
        let mut names: HashMap<&'static str, char> = LETTERS
            .char_indices()
            .filter_map(|(at, c)| Some((LETTERS.get(at..at.checked_add(1)?)?, c)))
            .collect();
        names.extend(ASCII);
        names.extend(OTHERS);
        for (start, table) in [(0xA0_u32, &LATIN_1[..]), (0x100, &LATIN_EXTENDED_A[..])] {
            for (offset, name) in (0_u32..).zip(table) {
                if let Some(c) = start.checked_add(offset).and_then(char::from_u32) {
                    names.insert(name, c);
                }
            }
        }
        names
    })
}

/// The letters, whose names are themselves.
const LETTERS: &str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;

    #[test]
    fn base_encodings_give_their_characters() {
        assert_eq!(
            BaseEncoding::from_name(b"WinAnsiEncoding"),
            Some(BaseEncoding::WinAnsi)
        );
        assert_eq!(BaseEncoding::WinAnsi.char(0x80), Some('€'));
        assert_eq!(BaseEncoding::WinAnsi.char(0x81), Some('•'));
        assert_eq!(BaseEncoding::WinAnsi.char(0x9F), Some('Ÿ'));
        assert_eq!(BaseEncoding::WinAnsi.char(0xFC), Some('ü'));
        assert_eq!(BaseEncoding::WinAnsi.char(0x27), Some('\''));
        assert_eq!(BaseEncoding::Standard.char(0x27), Some('’'));
        assert_eq!(BaseEncoding::Standard.char(0xF5), Some('ı'));
        assert_eq!(BaseEncoding::Standard.char(0xF6), None);
        assert_eq!(BaseEncoding::MacRoman.char(0x80), Some('Ä'));
        assert_eq!(BaseEncoding::MacRoman.char(0xDB), Some('¤'));
        assert_eq!(BaseEncoding::MacRoman.char(0xF0), None);
        assert_eq!(BaseEncoding::MacRoman.char(0xFF), Some('ˇ'));
        assert_eq!(WIN_ANSI_HIGH.chars().count(), 32);
        assert_eq!(MAC_ROMAN_HIGH.chars().count(), 128);
    }

    #[test]
    fn differences_name_the_glyphs_turkish_needs() {
        let turkish = SimpleEncoding::new(
            Some(BaseEncoding::WinAnsi),
            [
                (0xD0, "Gbreve"),
                (0xDD, "Idotaccent"),
                (0xDE, "Scedilla"),
                (0xF0, "gbreve"),
                (0xFD, "dotlessi"),
                (0xFE, "scedilla"),
                (0x41, "g42"),
            ],
        );
        let text: String = [0xD0, 0xDD, 0xDE, 0xF0, 0xFD, 0xFE, 0x61]
            .iter()
            .filter_map(|&code| turkish.text(code))
            .collect();
        assert_eq!(text, "ĞİŞğışa");
        assert_eq!(turkish.text(0x41), None, "an unknown name has no text");
        assert_eq!(SimpleEncoding::new(None, []).text(0x41), None);
    }

    #[test]
    fn glyph_names_follow_the_glyph_list_rules() {
        assert_eq!(glyph_text("A").as_deref(), Some("A"));
        assert_eq!(glyph_text("seven").as_deref(), Some("7"));
        assert_eq!(glyph_text("a.sc").as_deref(), Some("a"));
        assert_eq!(glyph_text("f_f_i").as_deref(), Some("ffi"));
        assert_eq!(glyph_text("uni0130").as_deref(), Some("İ"));
        assert_eq!(glyph_text("uni00660069").as_deref(), Some("fi"));
        assert_eq!(glyph_text("u1F600").as_deref(), Some("😀"));
        assert_eq!(
            glyph_text("uniD800"),
            None,
            "a surrogate is not a character"
        );
        assert_eq!(glyph_text("uni0130a"), None);
        assert_eq!(glyph_text("unic0de"), None, "hex digits are upper case");
        assert_eq!(glyph_text("longs").as_deref(), Some("ſ"));
        // The tables run in Unicode order, so a slip shifts every later name.
        assert_eq!(glyph_text("Lslash").as_deref(), Some("\u{141}"));
        assert_eq!(glyph_text("Tcaron").as_deref(), Some("\u{164}"));
        assert_eq!(glyph_text("Thorn").as_deref(), Some("\u{DE}"));
        assert_eq!(glyph_text("multiply").as_deref(), Some("\u{D7}"));
        assert_eq!(glyph_text("ydieresis").as_deref(), Some("ÿ"));
        assert_eq!(glyph_text(".notdef"), None);
    }
}
