//! Editing the document information (a2-7, M4 plan W6): title, author, subject and keywords in
//! `/Info`, and in the catalog's XMP metadata when the file has it, so readers that prefer one or
//! the other show the same.
// Values come from the file (.claude/rules/rust.md).
#![deny(clippy::indexing_slicing, clippy::arithmetic_side_effects)]

use lopdf::{Object, Stream, StringFormat};

use crate::revision::{RevisionStore, decoded};
use crate::{CoreError, Document, WriteError, text_string};

/// The information a2-7 edits; an empty value removes its entry.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct InfoEdit {
    /// `/Title`, `dc:title`.
    pub title: String,
    /// `/Author`, `dc:creator`.
    pub author: String,
    /// `/Subject`, `dc:description`.
    pub subject: String,
    /// `/Keywords`, `pdf:Keywords`.
    pub keywords: String,
}

/// The XMP properties, with their `/Info` key and the RDF container around the value.
const PROPERTIES: [(&[u8], &str, Option<&str>); 4] = [
    (b"Title", "dc:title", Some("Alt")),
    (b"Author", "dc:creator", Some("Seq")),
    (b"Subject", "dc:description", Some("Alt")),
    (b"Keywords", "pdf:Keywords", None),
];

impl InfoEdit {
    fn values(&self) -> [&str; 4] {
        [&self.title, &self.author, &self.subject, &self.keywords]
    }
}

impl RevisionStore {
    /// Makes `info` the document's information in the open transaction: the entries that differ
    /// are written, the others stay as the file has them. XMP that cannot be read as text, or
    /// has no `</rdf:RDF>`, keeps what it says.
    ///
    /// # Errors
    ///
    /// [`WriteError::NoTransaction`], [`WriteError::StructurePlan`] for a document whose
    /// trailer names no `/Info` object, and those of decoding the XMP within the limits.
    pub fn set_info(&mut self, doc: &Document, info: &InfoEdit) -> Result<(), CoreError> {
        self.transaction_open()?;
        // A file without an /Info object cannot get one (Info::editable).
        let id = doc
            .model()
            .trailer
            .get(b"Info")
            .and_then(Object::as_reference)
            .map_err(|_| CoreError::Write(WriteError::StructurePlan))?;
        let mut dict = self.dictionary(doc, id)?;
        for ((key, ..), value) in PROPERTIES.iter().zip(info.values()) {
            let now = dict
                .get(key)
                .ok()
                .and_then(|now| now.as_str().ok())
                .map(text_string::decode);
            if value.is_empty() {
                dict.remove(key);
            } else if now.as_deref() != Some(value) {
                dict.set(
                    key.to_vec(),
                    Object::String(text_string::encode(value), StringFormat::Literal),
                );
            }
        }
        self.put_changed(doc, id, dict)?;
        let (_, catalog) = self.catalog(doc)?;
        let Ok(metadata) = catalog.get(b"Metadata").and_then(Object::as_reference) else {
            return Ok(());
        };
        let Some(Object::Stream(stream)) = self.scope(doc).object(metadata).cloned() else {
            return Ok(());
        };
        let Ok(xml) = String::from_utf8(decoded(&stream, doc)?) else {
            return Ok(());
        };
        let Some(updated) = xmp_with(&xml, info) else {
            return Ok(());
        };
        if updated == xml {
            return Ok(());
        }
        // Written unfiltered, as XMP is meant to be found in the file.
        let mut dict = stream.dict;
        dict.remove(b"Filter");
        dict.remove(b"DecodeParms");
        self.put_counted(
            doc,
            vec![(
                metadata,
                Object::Stream(Stream::new(dict, updated.into_bytes())),
            )],
        )
    }
}

/// The `rdf:Description` the properties go in.
const DESCRIPTION: &str = "<rdf:Description rdf:about=\"\" \
    xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:pdf=\"http://ns.adobe.com/pdf/1.3/\">";

/// `xml` with the four properties of `info`: each one's elements or attribute taken out, and the
/// values that are not empty in an `rdf:Description` of their own before `</rdf:RDF>`. `None`
/// without `</rdf:RDF>`.
// shortcut: properties are found by the usual `dc:` and `pdf:` prefixes; parse the namespaces if
// a file binds them to others.
fn xmp_with(xml: &str, info: &InfoEdit) -> Option<String> {
    let end = xml.rfind("</rdf:RDF>")?;
    let mut out = xml.get(..end)?.to_owned();
    let tail = xml.get(end..)?;
    let mut added = String::new();
    for ((_, property, container), value) in PROPERTIES.iter().zip(info.values()) {
        out = without(&out, property);
        if value.is_empty() {
            continue;
        }
        let value = escaped(value);
        let inner = match container {
            Some("Alt") => {
                format!("<rdf:Alt><rdf:li xml:lang=\"x-default\">{value}</rdf:li></rdf:Alt>")
            }
            Some(kind) => format!("<rdf:{kind}><rdf:li>{value}</rdf:li></rdf:{kind}>"),
            None => value,
        };
        added.push_str(&format!("<{property}>{inner}</{property}>"));
    }
    // Ours from an earlier edit, emptied above.
    out = out.replace(&format!("{DESCRIPTION}</rdf:Description>"), "");
    if !added.is_empty() {
        out.push_str(&format!("{DESCRIPTION}{added}</rdf:Description>"));
    }
    out.push_str(tail);
    Some(out)
}

/// `xml` without the elements `<property …>…</property>` or `<property …/>` and the attributes
/// `property="…"`.
fn without(xml: &str, property: &str) -> String {
    let mut out = String::with_capacity(xml.len());
    let mut rest = xml;
    let open = format!("<{property}");
    let close = format!("</{property}>");
    let attribute = format!(" {property}=");
    loop {
        let element = rest.find(&open).filter(|&at| {
            rest.get(at.saturating_add(open.len())..)
                .and_then(|after| after.chars().next())
                .is_some_and(|c| c == '>' || c == '/' || c.is_whitespace())
        });
        let attr = rest.find(&attribute);
        match (element, attr) {
            (Some(at), other) if other.is_none_or(|attr| at < attr) => {
                let Some(head) = rest.get(..at) else { break };
                out.push_str(head);
                let after = rest.get(at..).unwrap_or_default();
                let tag_end = after
                    .find('>')
                    .map_or(after.len(), |end| end.saturating_add(1));
                let empty = after.get(..tag_end).is_some_and(|tag| tag.ends_with("/>"));
                let skip = if empty {
                    tag_end
                } else {
                    after
                        .find(&close)
                        .map_or(after.len(), |end| end.saturating_add(close.len()))
                };
                rest = after.get(skip..).unwrap_or_default();
            }
            (_, Some(at)) => {
                let Some(head) = rest.get(..at) else { break };
                out.push_str(head);
                let after = rest
                    .get(at.saturating_add(attribute.len())..)
                    .unwrap_or_default();
                let quote = after.chars().next().unwrap_or('"');
                let value_end = after
                    .get(1..)
                    .and_then(|value| value.find(quote))
                    .map_or(after.len(), |end| end.saturating_add(2));
                rest = after.get(value_end..).unwrap_or_default();
            }
            _ => break,
        }
    }
    out.push_str(rest);
    out
}

/// `text` as XML character data.
fn escaped(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            other => out.push(other),
        }
    }
    out
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::sync::Arc;

    use lopdf::{Object, Stream, dictionary};

    use super::{InfoEdit, xmp_with};
    use crate::revision::{RevisionStore, decoded};
    use crate::{CoreError, Document, OpenOptions, Source, WriteError, open};

    const XMP: &str = "<?xpacket begin=\"\"?><x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:RDF \
        xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"><rdf:Description rdf:about=\"\" \
        xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:pdf=\"http://ns.adobe.com/pdf/1.3/\" \
        pdf:Keywords=\"eski\" pdf:Producer=\"X\"><dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">\
        Eski</rdf:li></rdf:Alt></dc:title><dc:creator/><dc:format>application/pdf</dc:format>\
        </rdf:Description></rdf:RDF></x:xmpmeta><?xpacket end=\"w\"?>";

    fn edit() -> InfoEdit {
        InfoEdit {
            title: "Kira <sözleşmesi> & ek".to_owned(),
            author: "Ayşe Yılmaz".to_owned(),
            subject: String::new(),
            keywords: "kira, İzmir".to_owned(),
        }
    }

    #[test]
    fn xmp_takes_the_new_values_and_keeps_the_rest() {
        let xml = xmp_with(XMP, &edit()).unwrap();
        assert!(!xml.contains("Eski") && !xml.contains("eski") && !xml.contains("<dc:creator/>"));
        assert!(xml.contains("pdf:Producer=\"X\"") && xml.contains("<dc:format>"));
        assert!(xml.contains("Kira &lt;sözleşmesi&gt; &amp; ek</rdf:li>"));
        assert!(xml.contains("<dc:creator><rdf:Seq><rdf:li>Ayşe Yılmaz</rdf:li></rdf:Seq>"));
        assert!(xml.contains("<pdf:Keywords>kira, İzmir</pdf:Keywords>"));
        assert!(!xml.contains("dc:description"));
        assert!(xml.ends_with("</rdf:RDF></x:xmpmeta><?xpacket end=\"w\"?>"));
        // Again: the same.
        assert_eq!(xmp_with(&xml, &edit()).unwrap(), xml);
        assert_eq!(xmp_with("<x/>", &edit()), None);
    }

    fn with_info(xmp: bool) -> Document {
        let mut doc = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let info = doc.add_object(dictionary! {
            "Title" => Object::string_literal("Eski"), "Producer" => Object::string_literal("X"),
        });
        doc.trailer.set("Info", info);
        if xmp {
            let metadata = doc.add_object(Stream::new(
                dictionary! { "Type" => "Metadata", "Subtype" => "XML" },
                XMP.as_bytes().to_vec(),
            ));
            let catalog = doc.trailer.get(b"Root").unwrap().as_reference().unwrap();
            doc.get_dictionary_mut(catalog)
                .unwrap()
                .set("Metadata", metadata);
        }
        let mut bytes = Vec::new();
        doc.save_to(&mut bytes).unwrap();
        open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap()
    }

    #[test]
    fn info_and_xmp_are_written_together_and_survive_a_save() {
        let doc = with_info(true);
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        store.set_info(&doc, &edit()).unwrap();
        store.commit().unwrap();
        let bytes = store.incremental_update(&doc).unwrap();
        assert!(bytes.starts_with(doc.source().bytes()));
        let again = open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap();
        let info = &again.structure().info;
        assert_eq!(info.title.as_deref(), Some("Kira <sözleşmesi> & ek"));
        assert_eq!(info.author.as_deref(), Some("Ayşe Yılmaz"));
        assert_eq!(info.subject, None);
        assert_eq!(info.keywords.as_deref(), Some("kira, İzmir"));
        assert_eq!(info.producer.as_deref(), Some("X"));
        let store = RevisionStore::new(&again);
        let (_, catalog) = store.catalog(&again).unwrap();
        let id = catalog.get(b"Metadata").unwrap().as_reference().unwrap();
        let Some(Object::Stream(stream)) = store.scope(&again).object(id).cloned() else {
            panic!("no XMP");
        };
        let xml = String::from_utf8(decoded(&stream, &again).unwrap()).unwrap();
        assert!(xml.contains("Ayşe Yılmaz") && !xml.contains("Eski"));
    }

    #[test]
    fn the_same_values_write_nothing_and_no_info_is_refused() {
        let doc = with_info(false);
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let same = InfoEdit {
            title: "Eski".to_owned(),
            ..InfoEdit::default()
        };
        store.set_info(&doc, &same).unwrap();
        assert_eq!(store.commit().unwrap(), 0);
        assert!(doc.structure().info.editable);

        let plain = crate::structure::tests::doc_with(vec![dictionary! {}], dictionary! {});
        let mut bytes = Vec::new();
        plain.clone().save_to(&mut bytes).unwrap();
        let plain = open(
            &Source::from_bytes(Arc::from(bytes)),
            &OpenOptions::default(),
        )
        .unwrap();
        assert!(!plain.structure().info.editable, "a2-7 shows it read-only");
        let mut store = RevisionStore::new(&plain);
        store.begin().unwrap();
        assert!(matches!(
            store.set_info(&plain, &edit()),
            Err(CoreError::Write(WriteError::StructurePlan))
        ));
    }
}
