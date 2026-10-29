//! Render-only appendices (ADR 0009): an incremental section after a document's bytes that PDFium
//! renders and Ferman never writes to disk or keeps as a revision. The first one shows and hides
//! layers (a2-3c); it is also the first piece of the M3 incremental writer.
//!
//! The section redefines the catalog with the layers' new state in its `/OCProperties /D`, and
//! ends with a cross-reference stream that names every object, so it needs no `/Prev` and reads
//! the same after a classic table, a cross-reference stream or a hybrid file. The original bytes
//! stay an exact prefix. The catalog is written from the decrypted model: in an encrypted
//! document PDFium decrypts its strings (such as `/Lang`) into noise, which no page's pixels
//! depend on.
// Offsets and sizes are checked (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use lopdf::{Dictionary, Object, ObjectId, dictionary};

use crate::structure::Layer;
use crate::syntax::is_regular;
use crate::xref::{self, Entry, Xref};
use crate::{CoreError, Unsupported};

/// The appendix that shows each of `layers` whose `visible` is true and hides the others; groups
/// not among `layers` keep their state. `start` is where it begins, counted from the `%PDF-`
/// header as cross-reference offsets are.
pub(crate) fn layers(
    model: &lopdf::Document,
    xref: &Xref,
    start: usize,
    layers: &[Layer],
    visible: &[bool],
) -> Result<Vec<u8>, CoreError> {
    let missing = || CoreError::Internal {
        context: "a layer appendix for a document without layers",
    };
    let root = xref
        .trailer
        .get(b"Root")
        .and_then(Object::as_reference)
        .map_err(|_| missing())?;
    let mut catalog = model.get_dictionary(root).map_err(|_| missing())?.clone();
    let mut properties =
        dictionary(model, catalog.get(b"OCProperties").ok()).ok_or_else(missing)?;
    let mut config = dictionary(model, properties.get(b"D").ok()).unwrap_or_default();
    let mut on = references(model, config.get(b"ON").ok());
    let mut off = references(model, config.get(b"OFF").ok());
    for (layer, &shown) in layers.iter().zip(visible) {
        on.retain(|id| *id != layer.id);
        off.retain(|id| *id != layer.id);
        if shown {
            on.push(layer.id);
        } else {
            off.push(layer.id);
        }
    }
    let array =
        |ids: Vec<ObjectId>| Object::Array(ids.into_iter().map(Object::Reference).collect());
    config.set("ON", array(on));
    config.set("OFF", array(off));
    // /AS would set states again by usage (ISO 32000-2 §8.11.4.4); the sidebar shows /ON and /OFF.
    config.remove(b"AS");
    properties.set("D", config);
    catalog.set("OCProperties", properties);

    let mut out = b"\n".to_vec();
    let catalog_at = offset(start, out.len())?;
    indirect(&mut out, root, &Object::Dictionary(catalog));
    let number = xref::size_of(xref);
    let size = number.checked_add(1).ok_or(CoreError::Internal {
        context: "the appendix's object number",
    })?;
    let stream_at = offset(start, out.len())?;
    let mut table = Vec::new();
    for n in 0..size {
        let (kind, second, third) = if n == root.0 {
            (1, catalog_at, u32::from(root.1))
        } else if n == number {
            (1, stream_at, 0)
        } else {
            match xref.entries.get(&n) {
                Some(Entry::Normal { offset, generation }) => (
                    1,
                    u32::try_from(*offset)
                        .map_err(|_| CoreError::Unsupported(Unsupported::FileSize))?,
                    u32::from(*generation),
                ),
                Some(Entry::Compressed { container, index }) => (2, *container, *index),
                Some(Entry::Free) | None => (0, 0, if n == 0 { 0xFFFF } else { 0 }),
            }
        };
        table.push(kind);
        table.extend(second.to_be_bytes());
        table.extend(third.to_be_bytes());
    }
    let mut trailer = dictionary! {
        "Type" => "XRef",
        "Size" => i64::from(size),
        "W" => vec![1.into(), 4.into(), 4.into()],
        "Length" => i64::try_from(table.len()).unwrap_or(i64::MAX),
    };
    for key in [&b"Root"[..], b"Info", b"ID", b"Encrypt"] {
        if let Ok(value) = xref.trailer.get(key) {
            trailer.set(key.to_vec(), value.clone());
        }
    }
    out.extend(format!("{number} 0 obj\n").as_bytes());
    object(&mut out, &Object::Dictionary(trailer));
    out.extend(b"\nstream\n");
    out.extend(table);
    out.extend(format!("\nendstream\nendobj\nstartxref\n{stream_at}\n%%EOF\n").as_bytes());
    Ok(out)
}

/// The dictionary `object` is or refers to.
fn dictionary(model: &lopdf::Document, object: Option<&Object>) -> Option<Dictionary> {
    let (_, object) = model.dereference(object?).ok()?;
    object.as_dict().ok().cloned()
}

/// The references in the array `object` is or refers to.
fn references(model: &lopdf::Document, object: Option<&Object>) -> Vec<ObjectId> {
    object
        .and_then(|object| model.dereference(object).ok())
        .and_then(|(_, array)| array.as_array().ok())
        .map(|items| {
            items
                .iter()
                .filter_map(|item| item.as_reference().ok())
                .collect()
        })
        .unwrap_or_default()
}

/// `start + at`, as a cross-reference offset.
fn offset(start: usize, at: usize) -> Result<u32, CoreError> {
    start
        .checked_add(at)
        .and_then(|offset| u32::try_from(offset).ok())
        .ok_or(CoreError::Unsupported(Unsupported::FileSize))
}

/// Writes `value` as the indirect object `id`.
fn indirect(out: &mut Vec<u8>, id: ObjectId, value: &Object) {
    out.extend(format!("{} {} obj\n", id.0, id.1).as_bytes());
    object(out, value);
    out.extend(b"\nendobj\n");
}

/// Writes a direct object. Strings are written in hex, which needs no escapes; a stream cannot be
/// direct, so it is written as `null`.
fn object(out: &mut Vec<u8>, value: &Object) {
    match value {
        Object::Null | Object::Stream(_) => out.extend(b"null"),
        Object::Boolean(value) => out.extend(if *value { &b"true"[..] } else { b"false" }),
        Object::Integer(value) => out.extend(value.to_string().as_bytes()),
        // Display never uses an exponent, which PDF numbers cannot have.
        Object::Real(value) if value.is_finite() => out.extend(value.to_string().as_bytes()),
        Object::Real(_) => out.push(b'0'),
        Object::Name(name) => self::name(out, name),
        Object::String(bytes, _) => {
            out.push(b'<');
            for byte in bytes {
                out.extend(format!("{byte:02X}").as_bytes());
            }
            out.push(b'>');
        }
        Object::Array(items) => {
            out.push(b'[');
            for item in items {
                object(out, item);
                out.push(b' ');
            }
            out.push(b']');
        }
        Object::Dictionary(entries) => {
            out.extend(b"<<");
            for (key, value) in entries {
                name(out, key);
                out.push(b' ');
                object(out, value);
                out.push(b' ');
            }
            out.extend(b">>");
        }
        Object::Reference((number, generation)) => {
            out.extend(format!("{number} {generation} R").as_bytes());
        }
    }
}

/// Writes a name, with `#` escapes for the bytes a name cannot hold as they are.
fn name(out: &mut Vec<u8>, name: &[u8]) {
    out.push(b'/');
    for &byte in name {
        if is_regular(byte) && byte != b'#' && (0x21..=0x7E).contains(&byte) {
            out.push(byte);
        } else {
            out.extend(format!("#{byte:02X}").as_bytes());
        }
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::{Object, dictionary};

    use crate::{OpenOptions, Source, open};

    /// A one-page file with three layers, "Notlar" off, saved by lopdf in the classic or the
    /// modern form (object streams and a cross-reference stream).
    fn layered(modern: bool) -> Vec<u8> {
        let mut doc = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let groups: Vec<Object> = ["Duvarlar", "Tesisat", "Notlar"]
            .iter()
            .map(|name| {
                doc.add_object(
                    dictionary! { "Type" => "OCG", "Name" => Object::string_literal(*name) },
                )
                .into()
            })
            .collect();
        let catalog = doc.trailer.get(b"Root").unwrap().as_reference().unwrap();
        doc.get_dictionary_mut(catalog).unwrap().set(
            "OCProperties",
            dictionary! {
                "OCGs" => groups.clone(),
                "D" => dictionary! {
                    "Name" => Object::string_literal("Varsayılan (#1)"),
                    "OFF" => vec![groups[2].clone()],
                    "AS" => vec![],
                },
            },
        );
        let mut bytes = Vec::new();
        if modern {
            doc.save_modern(&mut bytes).unwrap();
        } else {
            doc.save_to(&mut bytes).unwrap();
        }
        bytes
    }

    fn visible(bytes: &[u8]) -> Vec<bool> {
        let document = open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap();
        // A wrong offset in the appendix's table would make ferman-core repair the file.
        assert!(document.repair().is_none());
        document
            .structure()
            .layers
            .iter()
            .map(|layer| layer.visible)
            .collect()
    }

    #[test]
    fn the_appendix_sets_every_layer_and_keeps_the_original_as_a_prefix() {
        for modern in [false, true] {
            let original = layered(modern);
            assert_eq!(visible(&original), [true, true, false], "modern {modern}");
            let document = open(
                &Source::from_bytes(Arc::from(&original[..])),
                &OpenOptions::default(),
            )
            .unwrap();
            for wanted in [
                [false, true, true],
                [true, true, false],
                [false, false, false],
            ] {
                let mut copy = original.clone();
                copy.extend(document.layer_appendix(&wanted).unwrap());
                assert!(copy.starts_with(&original));
                assert_eq!(visible(&copy), wanted, "modern {modern}");
                assert_eq!(
                    open(
                        &Source::from_bytes(Arc::from(&copy[..])),
                        &OpenOptions::default()
                    )
                    .unwrap()
                    .page_count(),
                    1
                );
            }
        }
    }

    #[test]
    fn names_and_strings_are_written_so_they_read_back() {
        let mut out = Vec::new();
        super::object(
            &mut out,
            &Object::Array(vec![
                Object::Name(b"A B#(".to_vec()),
                Object::string_literal("a)b"),
                Object::Real(0.000_1),
                Object::Real(f32::NAN),
            ]),
        );
        assert_eq!(out, b"[/A#20B#23#28 <612962> 0.0001 0 ]");
    }
}
