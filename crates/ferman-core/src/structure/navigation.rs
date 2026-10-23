//! The outline, destinations and attachments, with the name and number trees they live in
//! (ISO 32000-2 §7.9.6, §7.9.7, §12.3 and §7.11.4).
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use std::collections::{BTreeMap, BTreeSet};

use lopdf::{Dictionary, Object, ObjectId};

use super::{PdfDate, Scope};
use crate::text_string;

/// One outline item (bookmark).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OutlineItem {
    /// Its title.
    pub title: String,
    /// The page it goes to, when it goes to a page of this document.
    pub page: Option<u32>,
    /// Whether it is shown open (a positive `/Count`).
    pub open: bool,
    /// Its children.
    pub children: Vec<OutlineItem>,
}

/// An embedded file (a2-3b): from the `/EmbeddedFiles` name tree, or a file attachment
/// annotation on a page. Embedded files are never opened automatically.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Attachment {
    /// The file name: `/UF`, `/F` or the name tree's key.
    pub name: String,
    /// `/Desc`.
    pub description: Option<String>,
    /// The size in bytes, as `/Params /Size` gives it.
    pub size: Option<u64>,
    /// `/Params /CreationDate`.
    pub created: Option<PdfDate>,
    /// `/Params /ModDate`.
    pub modified: Option<PdfDate>,
    /// The media type, from the stream's `/Subtype`.
    pub media_type: Option<String>,
    /// The page of its annotation, for one attached to a page.
    pub page: Option<u32>,
    /// The embedded file stream.
    pub(crate) file: Option<ObjectId>,
}

/// The entries of a name or number tree (`kind` is `Names` or `Nums`), in tree order; keys of
/// the wrong type are skipped.
fn tree<'a>(scope: &Scope<'a>, root: &'a Dictionary, kind: &[u8]) -> Vec<(&'a Object, &'a Object)> {
    let mut out = Vec::new();
    let mut seen = BTreeSet::new();
    let mut stack: Vec<(&Dictionary, u32)> = vec![(root, 0)];
    let cap = scope.doc.objects.len().saturating_add(1);
    while let Some((node, depth)) = stack.pop() {
        if let Some(pairs) = scope.get_array(node, kind) {
            for [key, value] in pairs.as_chunks::<2>().0 {
                out.push((key, value));
            }
        }
        if depth >= scope.limits.max_nesting || seen.len() > cap {
            continue;
        }
        if let Some(kids) = scope.get_array(node, b"Kids") {
            // Pushed in reverse, so the leftmost kid is read first.
            for kid in kids.iter().rev() {
                let Ok(id) = kid.as_reference() else {
                    continue;
                };
                if seen.insert(id)
                    && let Some(kid) = scope.dict(kid)
                {
                    stack.push((kid, depth.saturating_add(1)));
                }
            }
        }
    }
    out
}

/// A number tree's entries.
pub(crate) fn number_tree<'a>(scope: &Scope<'a>, root: &'a Dictionary) -> Vec<(i64, &'a Object)> {
    tree(scope, root, b"Nums")
        .into_iter()
        .filter_map(|(key, value)| Some((scope.resolve(key)?.as_i64().ok()?, value)))
        .collect()
}

/// A name tree's entries, keys as bytes.
pub(crate) fn name_tree<'a>(
    scope: &Scope<'a>,
    root: &'a Dictionary,
) -> Vec<(&'a [u8], &'a Object)> {
    tree(scope, root, b"Names")
        .into_iter()
        .filter_map(|(key, value)| Some((scope.resolve(key)?.as_str().ok()?, value)))
        .collect()
}

/// The catalog's `/Names` tree called `name`.
pub(crate) fn names<'a>(scope: &Scope<'a>, name: &[u8]) -> Vec<(&'a [u8], &'a Object)> {
    scope
        .catalog()
        .and_then(|catalog| scope.get_dict(catalog, b"Names"))
        .and_then(|names| scope.get_dict(names, name))
        .map(|root| name_tree(scope, root))
        .unwrap_or_default()
}

/// Named destinations: the `/Dests` name tree and the older `/Dests` dictionary of the catalog.
struct Named<'a> {
    by_name: BTreeMap<&'a [u8], &'a Object>,
}

impl<'a> Named<'a> {
    fn new(scope: &Scope<'a>) -> Self {
        let mut by_name: BTreeMap<&[u8], &Object> = names(scope, b"Dests").into_iter().collect();
        if let Some(dests) = scope
            .catalog()
            .and_then(|catalog| scope.get_dict(catalog, b"Dests"))
        {
            for (key, value) in dests {
                by_name.entry(key.as_slice()).or_insert(value);
            }
        }
        Self { by_name }
    }

    /// The page a destination goes to: an explicit `[page …]` array, a dictionary with `/D`,
    /// or a name or string looked up once.
    fn page(&self, scope: &Scope<'a>, dest: &'a Object, named: bool) -> Option<u32> {
        match scope.resolve(dest)? {
            Object::Array(items) => {
                let first = items.first()?;
                match first {
                    Object::Reference(id) => scope.page_of.get(id).copied(),
                    // PDFium takes an integer as a page index.
                    Object::Integer(index) => {
                        let index = u32::try_from(*index).ok()?;
                        (usize::try_from(index).ok()? < scope.page_of.len()).then_some(index)
                    }
                    _ => None,
                }
            }
            Object::Dictionary(dict) => self.page(scope, dict.get(b"D").ok()?, named),
            Object::Name(name) | Object::String(name, _) if !named => {
                self.page(scope, self.by_name.get(name.as_slice())?, true)
            }
            _ => None,
        }
    }

    /// The page an outline item or link goes to: its `/Dest`, or a `/GoTo` action's `/D`.
    fn target(&self, scope: &Scope<'a>, item: &'a Dictionary) -> Option<u32> {
        if let Ok(dest) = item.get(b"Dest") {
            return self.page(scope, dest, false);
        }
        let action = scope.get_dict(item, b"A")?;
        if scope.get_name(action, b"S")? != b"GoTo" {
            return None;
        }
        self.page(scope, action.get(b"D").ok()?, false)
    }
}

/// The outline, depth bounded by [`Limits::max_nesting`](crate::limits::Limits::max_nesting),
/// each item read once.
pub(crate) fn outline(scope: &Scope<'_>) -> Vec<OutlineItem> {
    let Some(root) = scope
        .catalog()
        .and_then(|catalog| scope.get_dict(catalog, b"Outlines"))
    else {
        return Vec::new();
    };
    let named = Named::new(scope);
    let mut seen = BTreeSet::new();
    items(scope, &named, root, 0, &mut seen)
}

fn items<'a>(
    scope: &Scope<'a>,
    named: &Named<'a>,
    parent: &'a Dictionary,
    depth: u32,
    seen: &mut BTreeSet<ObjectId>,
) -> Vec<OutlineItem> {
    let mut out = Vec::new();
    if depth >= scope.limits.max_nesting {
        return out;
    }
    let mut next = parent.get(b"First").ok();
    while let Some(link) = next.take() {
        let Ok(id) = link.as_reference() else {
            break;
        };
        if !seen.insert(id) {
            break;
        }
        let Some(item) = scope.dict(link) else {
            break;
        };
        out.push(OutlineItem {
            title: scope.get_text(item, b"Title").unwrap_or_default(),
            page: named.target(scope, item),
            open: scope.get_int(item, b"Count").is_some_and(|count| count > 0),
            children: items(scope, named, item, depth.saturating_add(1), seen),
        });
        next = item.get(b"Next").ok();
    }
    out
}

/// The embedded files of the `/EmbeddedFiles` tree, then file attachment annotations.
pub(crate) fn attachments(scope: &Scope<'_>) -> Vec<Attachment> {
    let mut out = Vec::new();
    for (key, spec) in names(scope, b"EmbeddedFiles") {
        if let Some(spec) = scope.dict(spec) {
            out.push(attachment(
                scope,
                spec,
                Some(text_string::decode(key)),
                None,
            ));
        }
    }
    for (annotation, page) in &scope.annotation_page {
        let Ok(annotation) = scope.doc.get_dictionary(*annotation) else {
            continue;
        };
        if scope.get_name(annotation, b"Subtype") != Some(b"FileAttachment") {
            continue;
        }
        if let Some(spec) = scope.get_dict(annotation, b"FS") {
            out.push(attachment(scope, spec, None, Some(*page)));
        }
    }
    out
}

fn attachment(
    scope: &Scope<'_>,
    spec: &Dictionary,
    key: Option<String>,
    page: Option<u32>,
) -> Attachment {
    let embedded = scope.get_dict(spec, b"EF");
    let file_ref = embedded.and_then(|ef| {
        ef.get(b"UF")
            .or_else(|_| ef.get(b"F"))
            .ok()
            .and_then(|file| file.as_reference().ok())
    });
    let file = embedded.and_then(|ef| {
        scope
            .get_dict(ef, b"UF")
            .or_else(|| scope.get_dict(ef, b"F"))
    });
    let params = file.and_then(|file| scope.get_dict(file, b"Params"));
    Attachment {
        name: scope
            .get_text(spec, b"UF")
            .or_else(|| scope.get_text(spec, b"F"))
            .or(key)
            .unwrap_or_default(),
        description: scope.get_text(spec, b"Desc"),
        size: params
            .and_then(|params| scope.get_int(params, b"Size"))
            .and_then(|size| u64::try_from(size).ok()),
        created: params.and_then(|params| scope.get_date(params, b"CreationDate")),
        modified: params.and_then(|params| scope.get_date(params, b"ModDate")),
        media_type: file
            .and_then(|file| scope.get_name(file, b"Subtype"))
            .map(|name| String::from_utf8_lossy(name).into_owned()),
        page,
        file: file_ref,
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use super::super::tests::doc_with;
    use super::super::{Structure, scan};
    use crate::limits::Limits;
    use lopdf::{Dictionary, Document, Object, Stream, dictionary};

    fn catalog_set(doc: &mut Document, key: &str, value: impl Into<Object>) {
        let catalog = doc.trailer.get(b"Root").unwrap().as_reference().unwrap();
        doc.get_dictionary_mut(catalog).unwrap().set(key, value);
    }

    fn pages(doc: &Document) -> Vec<lopdf::ObjectId> {
        doc.page_iter().collect()
    }

    #[test]
    fn the_outline_nests_and_resolves_its_destinations() {
        let mut doc = doc_with(vec![dictionary! {}; 3], dictionary! {});
        let ids = pages(&doc);
        let outlines = doc.new_object_id();
        let chapter = doc.new_object_id();
        let section = doc.new_object_id();
        let named = doc.new_object_id();
        doc.objects.insert(
            section,
            Object::Dictionary(dictionary! {
                "Title" => Object::string_literal("1.1 Kapsam"),
                "Parent" => chapter,
                "A" => dictionary! { "S" => "GoTo", "D" => vec![ids[2].into(), "Fit".into()] },
            }),
        );
        doc.objects.insert(
            chapter,
            Object::Dictionary(dictionary! {
                "Title" => Object::String(vec![0xFE, 0xFF, 0, b'B', 0, b'1'], lopdf::StringFormat::Hexadecimal),
                "Parent" => outlines,
                "Dest" => vec![ids[1].into(), "XYZ".into(), Object::Null, Object::Null, Object::Null],
                "First" => section, "Last" => section, "Count" => 1,
                "Next" => named,
            }),
        );
        doc.objects.insert(
            named,
            Object::Dictionary(dictionary! {
                "Title" => Object::string_literal("Ek"),
                "Parent" => outlines,
                "Dest" => Object::string_literal("ek-a"),
                // A loop back to the first item ends the list.
                "Next" => chapter,
            }),
        );
        doc.objects.insert(
            outlines,
            Object::Dictionary(dictionary! { "First" => chapter, "Last" => named }),
        );
        let dests = doc.add_object(dictionary! { "Names" => vec![
            Object::string_literal("ek-a"), Object::Dictionary(dictionary! { "D" => vec![ids[0].into(), "Fit".into()] }),
        ]});
        let names = doc.add_object(dictionary! { "Dests" => dests });
        catalog_set(&mut doc, "Outlines", outlines);
        catalog_set(&mut doc, "Names", names);
        let Structure { outline, .. } = scan(&doc, &Limits::default());
        assert_eq!(outline.len(), 2);
        assert_eq!(outline[0].title, "B1");
        assert_eq!(outline[0].page, Some(1));
        assert!(outline[0].open);
        assert_eq!(outline[0].children[0].title, "1.1 Kapsam");
        assert_eq!(outline[0].children[0].page, Some(2));
        assert_eq!(outline[1].page, Some(0));
        assert!(!outline[1].open);
    }

    #[test]
    fn attachments_come_from_the_name_tree_and_annotations() {
        let mut doc = doc_with(vec![dictionary! {}], dictionary! {});
        let page = pages(&doc)[0];
        let file = doc.add_object(Stream::new(
            dictionary! { "Type" => "EmbeddedFile", "Subtype" => "text/csv", "Params" => dictionary! {
                "Size" => 1204, "ModDate" => Object::string_literal("D:20261001120000+03'00'"),
            }},
            b"a,b\n".to_vec(),
        ));
        let spec = doc.add_object(dictionary! {
            "Type" => "Filespec", "F" => Object::string_literal("ekler.csv"),
            "UF" => Object::string_literal("ekler.csv"), "Desc" => Object::string_literal("Ek liste"),
            "EF" => dictionary! { "F" => file },
        });
        // A leaf under /Kids, to read through the tree.
        let leaf = doc.add_object(
            dictionary! { "Names" => vec![Object::string_literal("ekler.csv"), spec.into()] },
        );
        let embedded = doc.add_object(dictionary! { "Kids" => vec![leaf.into()] });
        let names = doc.add_object(dictionary! { "EmbeddedFiles" => embedded });
        catalog_set(&mut doc, "Names", names);
        let annotation = doc.add_object(dictionary! {
            "Type" => "Annot", "Subtype" => "FileAttachment",
            "FS" => dictionary! { "F" => Object::string_literal("not.txt") },
        });
        doc.get_dictionary_mut(page)
            .unwrap()
            .set("Annots", vec![annotation.into()]);
        let structure = scan(&doc, &Limits::default());
        assert_eq!(structure.attachments.len(), 2);
        let first = &structure.attachments[0];
        assert_eq!(first.name, "ekler.csv");
        assert_eq!(first.description.as_deref(), Some("Ek liste"));
        assert_eq!(first.size, Some(1204));
        assert_eq!(first.media_type.as_deref(), Some("text/csv"));
        assert_eq!(first.modified.map(|date| date.day), Some(1));
        assert_eq!(first.file, Some(file));
        assert_eq!(first.page, None);
        assert_eq!(structure.attachments[1].name, "not.txt");
        assert_eq!(structure.attachments[1].page, Some(0));
        assert_eq!(structure.attachments[1].file, None);
        let _ = Dictionary::new();
    }
}
