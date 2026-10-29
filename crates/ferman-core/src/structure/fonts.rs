//! The fonts that pages use and whether each is embedded (a1-9: "TimesNewRomanPSMT isn't
//! embedded"). Only each page's own `/Resources` are read here; fonts inside form XObjects come
//! with the content-stream interpreter (M3).
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::BTreeMap;

use lopdf::{Dictionary, Object, ObjectId};

use super::{Scope, inherited};

/// A font's type (`/Subtype`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum FontKind {
    /// `Type1`, the standard 14 included.
    Type1,
    /// `MMType1`.
    MultipleMaster,
    /// `TrueType`.
    TrueType,
    /// `Type0`, a composite font.
    Type0,
    /// `Type3`, glyphs drawn by content streams.
    Type3,
    /// Anything else.
    Other,
}

/// One font and the pages that use it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FontUse {
    /// `/BaseFont`, as written (a subset keeps its `ABCDEF+` tag).
    pub name: String,
    /// Its type.
    pub kind: FontKind,
    /// Whether its program is in the file. Type3 fonts always are.
    pub embedded: bool,
    /// The pages that use it, from 0.
    pub pages: Vec<u32>,
}

pub(crate) fn kind(name: Option<&[u8]>) -> FontKind {
    match name {
        Some(b"Type1") => FontKind::Type1,
        Some(b"MMType1") => FontKind::MultipleMaster,
        Some(b"TrueType") => FontKind::TrueType,
        Some(b"Type0") => FontKind::Type0,
        Some(b"Type3") => FontKind::Type3,
        _ => FontKind::Other,
    }
}

/// Whether a font's descriptor holds a font program.
fn embedded<'a>(scope: &Scope<'a>, font: &'a Dictionary, kind: FontKind) -> bool {
    let descriptor = match kind {
        FontKind::Type3 => return true,
        FontKind::Type0 => scope
            .get_array(font, b"DescendantFonts")
            .and_then(|fonts| fonts.first())
            .and_then(|descendant| scope.dict(descendant))
            .and_then(|descendant| scope.get_dict(descendant, b"FontDescriptor")),
        _ => scope.get_dict(font, b"FontDescriptor"),
    };
    descriptor.is_some_and(|descriptor| {
        [&b"FontFile"[..], b"FontFile2", b"FontFile3"]
            .iter()
            .any(|key| descriptor.has(key))
    })
}

/// The fonts of the pages `ids`, in the order they are first used.
pub(crate) fn fonts(scope: &Scope<'_>, ids: &[ObjectId]) -> Vec<FontUse> {
    // Keyed by the font object, or by the page and resource name for a direct dictionary.
    let mut order: Vec<FontUse> = Vec::new();
    let mut index: BTreeMap<(ObjectId, Vec<u8>), usize> = BTreeMap::new();
    for (page_index, id) in ids.iter().enumerate() {
        let (Ok(page_index), Ok(page)) = (u32::try_from(page_index), scope.doc.get_dictionary(*id))
        else {
            continue;
        };
        let Some(fonts) = inherited(scope, page, b"Resources")
            .and_then(|resources| resources.as_dict().ok())
            .and_then(|resources| scope.get_dict(resources, b"Font"))
        else {
            continue;
        };
        for (resource, font) in fonts {
            let key = match font {
                Object::Reference(font) => (*font, Vec::new()),
                _ => (*id, resource.clone()),
            };
            let Some(dict) = scope.dict(font) else {
                continue;
            };
            let slot = *index.entry(key).or_insert_with(|| {
                let font_kind = kind(scope.get_name(dict, b"Subtype"));
                order.push(FontUse {
                    name: scope
                        .get_name(dict, b"BaseFont")
                        .map(|name| String::from_utf8_lossy(name).into_owned())
                        .unwrap_or_default(),
                    kind: font_kind,
                    embedded: embedded(scope, dict, font_kind),
                    pages: Vec::new(),
                });
                order.len().saturating_sub(1)
            });
            if let Some(font) = order.get_mut(slot)
                && font.pages.last() != Some(&page_index)
            {
                font.pages.push(page_index);
            }
        }
    }
    order
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::super::scan;
    use super::super::tests::doc_with;
    use super::*;
    use crate::limits::Limits;
    use lopdf::{Stream, dictionary};

    #[test]
    fn fonts_are_listed_once_with_their_pages() {
        let mut doc = doc_with(vec![dictionary! {}, dictionary! {}], dictionary! {});
        let pages: Vec<ObjectId> = doc.page_iter().collect();
        let program = doc.add_object(Stream::new(dictionary! {}, vec![0; 4]));
        let embedded_font = doc.add_object(dictionary! {
            "Type" => "Font", "Subtype" => "TrueType", "BaseFont" => "ABCDEF+IBMPlexSerif",
            "FontDescriptor" => dictionary! { "FontFile2" => program },
        });
        let missing = doc.add_object(dictionary! {
            "Type" => "Font", "Subtype" => "TrueType", "BaseFont" => "TimesNewRomanPSMT",
            "FontDescriptor" => dictionary! { "FontName" => "TimesNewRomanPSMT" },
        });
        let composite = doc.add_object(dictionary! {
            "Type" => "Font", "Subtype" => "Type0", "BaseFont" => "GHIJKL+IBMPlexSerif",
            "DescendantFonts" => vec![Object::Dictionary(dictionary! { "FontDescriptor" => dictionary! { "FontFile2" => program } })],
        });
        let standard =
            dictionary! { "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Helvetica" };
        doc.get_dictionary_mut(pages[0]).unwrap().set(
            "Resources",
            dictionary! { "Font" => dictionary! { "F1" => embedded_font, "F2" => composite } },
        );
        doc.get_dictionary_mut(pages[1]).unwrap().set(
            "Resources",
            dictionary! { "Font" => dictionary! { "F1" => embedded_font, "F3" => missing, "F4" => standard } },
        );
        let fonts = scan(&doc, &Limits::default()).fonts;
        let summary: Vec<(&str, bool, Vec<u32>)> = fonts
            .iter()
            .map(|font| (font.name.as_str(), font.embedded, font.pages.clone()))
            .collect();
        assert_eq!(
            summary,
            [
                ("ABCDEF+IBMPlexSerif", true, vec![0, 1]),
                ("GHIJKL+IBMPlexSerif", true, vec![0]),
                ("TimesNewRomanPSMT", false, vec![1]),
                ("Helvetica", false, vec![1]),
            ]
        );
        assert_eq!(fonts[1].kind, FontKind::Type0);
    }
}
