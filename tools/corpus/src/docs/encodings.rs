//! One-page files for the font and encoding cases of the edit corpus (ROADMAP §7), each a title and
//! a few lines in the font the case is about:
//!
//! - `edit-e04-differences`: IBM Plex Sans as a simple TrueType WinAnsi subset whose program and
//!   `cmap` keep "ğ", which no code shows: typing it takes `/Differences` (`/gbreve`) in a new
//!   font dictionary (E04).
//! - `edit-e05-fstype`: EB Garamond as a simple TrueType subset without "ğ", as in `kira-tr`'s
//!   Madde 6, with `OS/2.fsType` 2 (Restricted License embedding) patched into the embedded
//!   program: the missing glyph falls to step 3 with the reason (E05). The licence of EB Garamond
//!   allows embedding; only the patched bytes say otherwise.
//! - `edit-e15-helvetica`: standard 14 Helvetica, not embedded, with only `/BaseFont` and
//!   `/Encoding`: no `/Widths`, so a reader takes the standard metrics (E15). The lines are
//!   broken with IBM Plex Sans's widths.
//! - `edit-e16-type3`: a Type3 font whose glyph procedures fill IBM Plex Sans's outlines for every
//!   character of the text, named `uniXXXX` in `/Differences`, with a `/ToUnicode` CMap (E16).
//! - `edit-macroman`: IBM Plex Serif as a simple TrueType subset with `/MacRomanEncoding`.
//! - `edit-90ms-rksj`: kana in Noto Serif JP through the predefined CMap `90ms-RKSJ-H` (Shift-JIS
//!   codes to Adobe-Japan1 CIDs), as a `CIDFontType2` with the subset embedded and a
//!   `/CIDToGIDMap` stream from the Adobe-Japan1 CIDs to its glyphs. Embedding keeps the file the
//!   same on every reader; the CIDs follow JIS X 0208 rows 1, 4 and 5, which Adobe-Japan1 numbers
//!   in order (633, 842 and 925 for their first cells).
//! - `edit-cff-cid`: Source Sans 3, an OpenType font with CFF outlines, as an `Identity-H`
//!   `CIDFontType0` font whose `FontFile3` is a CID-keyed `CIDFontType0C` subset.

use super::{Doc, generated, info, open_first, opens};
use crate::font::{PdfFont, subset_tag, to_unicode};
use crate::pdf::{self, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Flow, Frame, PageText, Paragraph, Style};
use crate::{Generated, Generator};
use lopdf::{Dictionary, Object, dictionary};
use std::collections::BTreeMap;
use subsetter::GlyphRemapper;

/// Glyph in the program, not in the encoding.
pub const EDIT_E04_DIFFERENCES: Generator = Generator {
    name: "edit-e04-differences",
    build: e04,
    expect: opens(),
};

/// A subset whose `fsType` forbids embedding.
pub const EDIT_E05_FSTYPE: Generator = Generator {
    name: "edit-e05-fstype",
    build: e05,
    expect: opens(),
};

/// Standard 14 Helvetica, not embedded.
pub const EDIT_E15_HELVETICA: Generator = Generator {
    name: "edit-e15-helvetica",
    build: e15,
    expect: opens(),
};

/// A Type3 font.
pub const EDIT_E16_TYPE3: Generator = Generator {
    name: "edit-e16-type3",
    build: e16,
    expect: opens(),
};

/// `/MacRomanEncoding`.
pub const EDIT_MACROMAN: Generator = Generator {
    name: "edit-macroman",
    build: macroman,
    expect: opens(),
};

/// The predefined CMap `90ms-RKSJ-H`.
pub const EDIT_90MS_RKSJ: Generator = Generator {
    name: "edit-90ms-rksj",
    build: rksj,
    expect: opens(),
};

/// A CID-keyed CFF font.
pub const EDIT_CFF_CID: Generator = Generator {
    name: "edit-cff-cid",
    build: cff,
    expect: opens(),
};

/// The text column.
fn flow() -> Flow {
    Flow::new(Frame {
        x: 72.0,
        top: pdf::A4.1 - 80.0,
        bottom: 80.0,
        width: pdf::A4.0 - 144.0,
    })
}

/// A page of `title` and `lines` in `style`, left aligned, written as `name`.
fn page_of(
    mut doc: Doc,
    style: &Style,
    name: &str,
    lang: &str,
    title: &str,
    lines: &[&str],
) -> Result<Generated, String> {
    let mut flow = flow();
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(&style.sized(16.0), title)
            .aligned(Align::Left)
            .spaced(0.0, 14.0),
    )?;
    for line in lines {
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(style, line)
                .aligned(Align::Left)
                .spaced(0.0, 6.0)
                .leading(1.4),
        )?;
    }
    close(doc, flow.into_pages(), name, lang)
}

/// Adds `pages` and writes the file as `name`.
fn close(mut doc: Doc, pages: Vec<PageText>, name: &str, lang: &str) -> Result<Generated, String> {
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let catalog = dictionary! { "Lang" => text(lang), "OpenAction" => open_first(ids.first().copied().ok_or("no page")?) };
    let bytes = doc.close(
        catalog,
        &info(
            name,
            "Ferman test corpus",
            "tools/corpus",
            "D:20261102120000+03'00'",
        ),
        name,
        None,
    )?;
    Ok(generated(bytes, expected))
}

/// A simple font style, with `setup` applied to its font.
fn simple(
    doc: &mut Doc,
    sources: &Sources,
    file: FontFile,
    setup: impl FnOnce(&mut crate::font::SimpleFont),
) -> Result<Style, String> {
    let style = doc.simple_style(sources, file, 11.0)?;
    if let Some(PdfFont::Simple(font)) = doc.fonts.get_mut(style.font) {
        setup(font);
    }
    Ok(style)
}

fn e04(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = simple(&mut doc, sources, FontFile::PlexSans, |font| {
        font.kept = vec!['ğ'];
    })?;
    page_of(
        doc,
        &style,
        "edit-e04-differences",
        "tr-TR",
        "Ödeme Bildirimi",
        &[
            "Mülk: Moda Cad. No: 18 D: 4, Üsküdar",
            "Kira bedeli: 18.500 TL",
            "Son ödeme günü: 5 Ekim 2026",
            "Hesap: Moda Gayrimenkul, Üsküdar Merkez",
            "Not: Gecikme hâlinde bedel yüzde 2 artar.",
        ],
    )
}

fn e05(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = simple(&mut doc, sources, FontFile::EbGaramond, |font| {
        font.fs_type = Some(2);
    })?;
    page_of(
        doc,
        &style.sized(12.0),
        "edit-e05-fstype",
        "tr-TR",
        "Ek Protokol",
        &[
            "Madde 6 – Ortak Giderler",
            "Ortak giderler her ay kira bedeli ile birlikte ödenir.",
            "Pay: 1.250 TL / ay",
        ],
    )
}

fn e15(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.4");
    let style = doc.standard_style(
        sources,
        FontFile::PlexSans,
        "Helvetica",
        "Type1",
        false,
        11.0,
    )?;
    if let Some(PdfFont::Standard(font)) = doc.fonts.get_mut(style.font) {
        font.bare = true;
    }
    page_of(
        doc,
        &style,
        "edit-e15-helvetica",
        "en-GB",
        "Meeting room booking",
        &[
            "Room 3.14 is booked for the budget review on Monday, 9 November 2026.",
            "The meeting starts at 10:00 and ends at 12:30.",
            "Please return the key to the front desk afterwards.",
        ],
    )
}

fn e16(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = simple(&mut doc, sources, FontFile::PlexSans, |font| {
        font.type3 = true;
    })?;
    page_of(
        doc,
        &style,
        "edit-e16-type3",
        "en-GB",
        "Delivery note",
        &[
            "Received in good order: 12 boxes of printer paper.",
            "Signed for the store by M. Kaya on 2 November 2026.",
        ],
    )
}

fn macroman(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = simple(&mut doc, sources, FontFile::PlexSerif, |font| {
        font.mac_roman = true;
    })?;
    page_of(
        doc,
        &style,
        "edit-macroman",
        "de-DE",
        "Lieferbestätigung",
        &[
            "Die Lieferung für das Café Müller in der Hauptstraße 12 ist am 2. November 2026 eingegangen.",
            "Geprüft von: Jérôme Dubois – “vollständig und unbeschädigt”.",
            "Bitte bewahren Sie diese Bestätigung für Ihre Unterlagen auf.",
        ],
    )
}

fn cff(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = doc.composite_style(sources, FontFile::SourceSans3, 11.0)?;
    page_of(
        doc,
        &style,
        "edit-cff-cid",
        "tr-TR",
        "Teslim Tutanağı",
        &[
            "Kadıköy şubesine 2 Kasım 2026 günü 12 koli yazıcı kâğıdı teslim edilmiştir.",
            "Teslim alan: Şule Işık, İdari İşler",
        ],
    )
}

/// The JIS X 0208 row and cell of the characters `edit-90ms-rksj` uses, and their Adobe-Japan1
/// CIDs: the ideographic space and comma and full stop (row 1), hiragana (row 4) and katakana
/// (row 5), in Unicode's order, which is the rows' order.
fn jis(c: char) -> Option<(u8, u8, u16)> {
    let code = u32::from(c);
    let (row, first, base) = match code {
        0x3000..=0x3002 => (1, 0x3000, 633_u32),
        0x3041..=0x3093 => (4, 0x3041, 842),
        0x30A1..=0x30F6 => (5, 0x30A1, 925),
        _ => return None,
    };
    let index = code - first;
    let cell = u8::try_from(index + 1).ok()?;
    let cid = u16::try_from(base + index).ok()?;
    Some((row, cell, cid))
}

/// The Shift-JIS bytes of JIS X 0208 `row` and `cell`.
fn shift_jis(row: u8, cell: u8) -> [u8; 2] {
    if row % 2 == 1 {
        let trail = cell + 0x3F;
        [
            row.div_ceil(2) + 0x80,
            if trail >= 0x7F { trail + 1 } else { trail },
        ]
    } else {
        [row / 2 + 0x80, cell + 0x9E]
    }
}

fn rksj(sources: &Sources) -> Result<Generated, String> {
    const TITLE: &str = "おしらせ";
    const LINES: [&str; 3] = [
        "マンションのけいやくこうしんについて、おしらせします。",
        "こうしんのてつづきは、かんりじむしょでおこないます。",
        "ごふめいなてんは、おといあわせください。",
    ];
    let mut doc = Doc::new("1.7");
    let face = doc.face(sources, FontFile::NotoSerifJp)?;
    let mut remap = GlyphRemapper::new();
    let mut by_cid: BTreeMap<u16, (u16, f64)> = BTreeMap::new();
    let mut unicode = BTreeMap::new();
    let mut page = PageText::default();
    let mut y = pdf::A4.1 - 96.0;
    for (index, line) in std::iter::once(TITLE).chain(LINES).enumerate() {
        let size = if index == 0 { 16.0 } else { 12.0 };
        // The three lines under the title are one block.
        page.group = (index > 0).then(|| "body".to_owned());
        let mut codes = String::new();
        for c in line.chars() {
            let (row, cell, cid) = jis(c).ok_or_else(|| format!("{c:?} is not in rows 1, 4, 5"))?;
            let gid = face.glyph(c).ok_or_else(|| format!("no glyph for {c:?}"))?;
            let sjis = shift_jis(row, cell);
            by_cid.insert(cid, (remap.remap(gid), face.advance(gid)));
            unicode.insert(sjis.to_vec(), c.to_string());
            codes.push_str(&format!("{:02X}{:02X}", sjis[0], sjis[1]));
        }
        page.content.op(&format!(
            "BT\n/F1 {} Tf\n72 {} Td\n<{codes}> Tj\nET",
            pdf::num(size),
            pdf::num(y)
        ));
        let advance: f64 = line
            .chars()
            .filter_map(|c| face.glyph(c))
            .map(|gid| face.advance(gid))
            .sum();
        page.record(
            vec![crate::text::TruthLine {
                text: line.to_owned(),
                start: (72.0, y),
                end: (72.0 + advance * size / 1000.0, y),
                size,
                vertical: false,
            }],
            "left",
        );
        page.lines.push(line.to_owned());
        y -= if index == 0 { 32.0 } else { 22.0 };
        page.group = None;
    }

    let gids: Vec<u16> = remap.remapped_gids().collect();
    let base_font = format!(
        "{}+{}",
        subset_tag(&format!("{}{gids:?}", face.postscript_name)),
        face.postscript_name
    );
    let program = face.subset(&remap)?;
    let length = i64::try_from(program.len()).map_err(|err| err.to_string())?;
    let file = doc.pdf.stream(dictionary! { "Length1" => length }, program);
    let mut descriptor = face.descriptor(&base_font, true);
    descriptor.set("FontFile2", file);
    let descriptor = doc.pdf.add(descriptor);
    let last = by_cid.keys().last().copied().unwrap_or(0);
    let mut map = Vec::with_capacity(usize::from(last) * 2 + 2);
    let mut widths = Vec::new();
    for cid in 0..=last {
        let (gid, width) = by_cid.get(&cid).copied().unwrap_or((0, 1000.0));
        map.extend_from_slice(&gid.to_be_bytes());
        if by_cid.contains_key(&cid) && (width.round() - 1000.0).abs() > 0.0 {
            widths.push(Object::Integer(i64::from(cid)));
            widths.push(vec![pdf::real(width.round())].into());
        }
    }
    let cid_to_gid = doc.pdf.stream(Dictionary::new(), map);
    let mut cid_font = dictionary! {
        "Type" => "Font",
        "Subtype" => "CIDFontType2",
        "BaseFont" => pdf::name(&base_font),
        "CIDSystemInfo" => dictionary! {
            "Registry" => Object::string_literal("Adobe"),
            "Ordering" => Object::string_literal("Japan1"),
            "Supplement" => 2,
        },
        "FontDescriptor" => descriptor,
        "DW" => 1000,
        "CIDToGIDMap" => cid_to_gid,
    };
    if !widths.is_empty() {
        cid_font.set("W", widths);
    }
    let cid_font = doc.pdf.add(cid_font);
    let cmap = doc
        .pdf
        .stream(Dictionary::new(), to_unicode(&unicode, true));
    let font = doc.pdf.add(dictionary! {
        "Type" => "Font",
        "Subtype" => "Type0",
        "BaseFont" => pdf::name(&format!("{base_font}-90ms-RKSJ-H")),
        "Encoding" => "90ms-RKSJ-H",
        "DescendantFonts" => vec![Object::Reference(cid_font)],
        "ToUnicode" => cmap,
    });
    page.resources.set("Font", dictionary! { "F1" => font });
    close(doc, vec![page], "edit-90ms-rksj", "ja-JP")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn kana_have_their_shift_jis_codes_and_cids() {
        assert_eq!(jis('\u{3000}'), Some((1, 1, 633)));
        assert_eq!(jis('。'), Some((1, 3, 635)));
        let (row, cell, cid) = jis('あ').unwrap();
        assert_eq!((shift_jis(row, cell), cid), ([0x82, 0xA0], 843));
        let (row, cell, cid) = jis('ン').unwrap();
        assert_eq!((shift_jis(row, cell), cid), ([0x83, 0x93], 1007));
        let (row, cell, _) = jis('ミ').unwrap();
        assert_eq!(shift_jis(row, cell), [0x83, 0x7E]);
        let (row, cell, _) = jis('ム').unwrap();
        assert_eq!(shift_jis(row, cell), [0x83, 0x80]);
        assert_eq!(jis('A'), None);
    }
}
