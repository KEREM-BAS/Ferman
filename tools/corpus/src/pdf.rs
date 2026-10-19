//! A small PDF writer on lopdf: objects, compressed streams, pages, the document information
//! dictionary and a fixed `/ID`. Every number is written with at most three decimals and every
//! dictionary keeps its insertion order, so the same calls give the same bytes on every system.

use crate::sha256_hex;
use lopdf::xref::XrefType;
use lopdf::{Dictionary, Document, Object, ObjectId, Stream, StringFormat, dictionary};
use std::fmt::Write as _;

/// A4 in points.
pub const A4: (f64, f64) = (595.276, 841.89);

/// A number as a PDF content-stream operand: at most three decimals, no trailing zeros.
#[must_use]
pub fn num(value: f64) -> String {
    let rounded = (value * 1000.0).round() / 1000.0;
    let mut text = format!("{rounded:.3}");
    while text.ends_with('0') {
        text.pop();
    }
    if text.ends_with('.') {
        text.pop();
    }
    if text == "-0" { "0".to_owned() } else { text }
}

/// A real number object, rounded like [`num`].
#[must_use]
pub fn real(value: f64) -> Object {
    let rounded = (value * 1000.0).round() / 1000.0;
    if rounded.fract() == 0.0 && rounded.abs() < 1e9 {
        #[allow(clippy::cast_possible_truncation)]
        Object::Integer(rounded as i64)
    } else {
        #[allow(clippy::cast_possible_truncation)]
        Object::Real(rounded as f32)
    }
}

/// A rectangle `[x1 y1 x2 y2]`.
#[must_use]
pub fn rect(x1: f64, y1: f64, x2: f64, y2: f64) -> Object {
    Object::Array(vec![real(x1), real(y1), real(x2), real(y2)])
}

/// A PDF name object.
#[must_use]
pub fn name(text: &str) -> Object {
    Object::Name(text.as_bytes().to_vec())
}

/// A text string (ISO 32000-1 §7.9.2.2): PDFDocEncoding when every character is ASCII, else
/// UTF-16BE with a byte order mark.
#[must_use]
pub fn text(value: &str) -> Object {
    if value.is_ascii() {
        Object::String(value.as_bytes().to_vec(), StringFormat::Literal)
    } else {
        let mut bytes = vec![0xFE, 0xFF];
        for unit in value.encode_utf16() {
            bytes.extend_from_slice(&unit.to_be_bytes());
        }
        Object::String(bytes, StringFormat::Hexadecimal)
    }
}

/// A byte string written as hex.
#[must_use]
pub fn hex(bytes: &[u8]) -> Object {
    Object::String(bytes.to_vec(), StringFormat::Hexadecimal)
}

/// A literal string for a content stream, escaped, with bytes outside printable ASCII in octal.
#[must_use]
pub fn literal(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() + 2);
    out.push('(');
    for &byte in bytes {
        match byte {
            b'(' | b')' | b'\\' => {
                out.push('\\');
                out.push(char::from(byte));
            }
            0x20..=0x7E => out.push(char::from(byte)),
            _ => {
                let _ = write!(out, "\\{byte:03o}");
            }
        }
    }
    out.push(')');
    out
}

/// The document information dictionary. Dates are PDF date strings such as
/// `D:20261013093000+03'00'`: fixed, never the time of generation.
#[derive(Debug, Clone, Default)]
pub struct Info {
    /// `/Title`.
    pub title: String,
    /// `/Author`.
    pub author: String,
    /// `/Subject`, when not empty.
    pub subject: String,
    /// `/Creator`, the application the document was made in.
    pub creator: String,
    /// `/Producer`, the program that wrote the PDF.
    pub producer: String,
    /// `/CreationDate`.
    pub created: String,
    /// `/ModDate`; the creation date when empty.
    pub modified: String,
}

impl Info {
    fn dictionary(&self) -> Dictionary {
        let mut info = Dictionary::new();
        info.set("Title", text(&self.title));
        if !self.author.is_empty() {
            info.set("Author", text(&self.author));
        }
        if !self.subject.is_empty() {
            info.set("Subject", text(&self.subject));
        }
        if !self.creator.is_empty() {
            info.set("Creator", text(&self.creator));
        }
        info.set("Producer", text(&self.producer));
        info.set("CreationDate", text(&self.created));
        let modified = if self.modified.is_empty() {
            &self.created
        } else {
            &self.modified
        };
        info.set("ModDate", text(modified));
        info
    }
}

/// The file identifier: 16 bytes from the SHA-256 of `seed`, the same in both halves, as a
/// writer that never saved the file before would make it.
#[must_use]
pub fn file_id(seed: &str) -> [u8; 16] {
    let digest = sha256_hex(seed.as_bytes());
    let mut id = [0u8; 16];
    for (index, byte) in id.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&digest[index * 2..index * 2 + 2], 16).unwrap_or(0);
    }
    id
}

/// A page to add: its size, content and resources.
#[derive(Debug, Clone, Default)]
pub struct Page {
    /// Width and height in points.
    pub size: (f64, f64),
    /// The content stream, uncompressed.
    pub content: Vec<u8>,
    /// The `/Resources` dictionary.
    pub resources: Dictionary,
    /// More page entries, such as `/Annots` or `/Rotate`.
    pub extra: Dictionary,
}

/// A document being written.
#[derive(Debug)]
pub struct Pdf {
    /// The lopdf document.
    pub doc: Document,
    pages_id: ObjectId,
    pages: Vec<ObjectId>,
    /// Whether streams are compressed with FlateDecode.
    pub compress: bool,
    /// Whether the file is written with object streams and a cross-reference stream.
    pub modern: bool,
}

impl Pdf {
    /// An empty document of `version` with a classic cross-reference table.
    #[must_use]
    pub fn new(version: &str) -> Self {
        let mut doc = Document::with_version(version);
        doc.reference_table.cross_reference_type = XrefType::CrossReferenceTable;
        doc.binary_mark = vec![0xE2, 0xE3, 0xCF, 0xD3];
        let pages_id = doc.new_object_id();
        Self {
            doc,
            pages_id,
            pages: Vec::new(),
            compress: true,
            modern: false,
        }
    }

    /// The page tree's root.
    #[must_use]
    pub fn pages_id(&self) -> ObjectId {
        self.pages_id
    }

    /// The pages added so far.
    #[must_use]
    pub fn pages(&self) -> &[ObjectId] {
        &self.pages
    }

    /// Reserves an object number for an object written later with [`Pdf::set`].
    pub fn reserve(&mut self) -> ObjectId {
        self.doc.new_object_id()
    }

    /// Adds an object and returns its reference.
    pub fn add(&mut self, object: impl Into<Object>) -> ObjectId {
        self.doc.add_object(object)
    }

    /// Writes an object at a reserved number.
    pub fn set(&mut self, id: ObjectId, object: impl Into<Object>) {
        self.doc.objects.insert(id, object.into());
    }

    /// A stream with `dict`, compressed when [`Pdf::compress`] is on.
    #[must_use]
    pub fn make_stream(&self, dict: Dictionary, content: Vec<u8>) -> Stream {
        let mut stream = Stream::new(dict, content);
        if self.compress {
            stream = compressed(stream);
        }
        stream
    }

    /// Adds a stream, compressed when [`Pdf::compress`] is on.
    pub fn stream(&mut self, dict: Dictionary, content: Vec<u8>) -> ObjectId {
        let stream = self.make_stream(dict, content);
        self.add(stream)
    }

    /// Adds a page at the end of the page tree.
    pub fn add_page(&mut self, page: Page) -> ObjectId {
        let content = self.stream(Dictionary::new(), page.content);
        let mut dict = dictionary! {
            "Type" => "Page",
            "Parent" => self.pages_id,
            "MediaBox" => rect(0.0, 0.0, page.size.0, page.size.1),
            "Resources" => page.resources,
            "Contents" => content,
        };
        for (key, value) in page.extra {
            dict.set(key, value);
        }
        let id = self.add(dict);
        self.pages.push(id);
        id
    }

    /// Writes the page tree, the catalog with `catalog`'s extra entries, the information
    /// dictionary and the `/ID`, and returns the file.
    ///
    /// # Errors
    ///
    /// A message when lopdf cannot write the document.
    pub fn finish(
        mut self,
        catalog: Dictionary,
        info: &Info,
        id_seed: &str,
    ) -> Result<Vec<u8>, String> {
        self.close(catalog, info, id_seed)?;
        self.save()
    }

    /// Writes the page tree, the catalog with `catalog`'s extra entries, the information
    /// dictionary and the `/ID`, ready for [`Pdf::save`].
    ///
    /// # Errors
    ///
    /// A message when the page count does not fit.
    pub fn close(&mut self, catalog: Dictionary, info: &Info, id_seed: &str) -> Result<(), String> {
        let kids: Vec<Object> = self.pages.iter().map(|id| Object::Reference(*id)).collect();
        let count = i64::try_from(kids.len()).map_err(|err| err.to_string())?;
        self.set(
            self.pages_id,
            dictionary! { "Type" => "Pages", "Kids" => kids, "Count" => count },
        );
        let mut root = dictionary! { "Type" => "Catalog", "Pages" => self.pages_id };
        for (key, value) in catalog {
            root.set(key, value);
        }
        let root = self.add(root);
        let info = self.add(info.dictionary());
        self.doc.trailer.set("Root", root);
        self.doc.trailer.set("Info", info);
        let id = file_id(id_seed);
        self.doc
            .trailer
            .set("ID", Object::Array(vec![hex(&id), hex(&id)]));
        Ok(())
    }

    /// Writes the document as it is, with its trailer.
    ///
    /// # Errors
    ///
    /// A message when lopdf cannot write the document.
    pub fn save(mut self) -> Result<Vec<u8>, String> {
        let mut out = Vec::new();
        if self.modern {
            let options = lopdf::SaveOptions::builder()
                .use_object_streams(true)
                .use_xref_streams(true)
                .build();
            self.doc
                .save_with_options(&mut out, options)
                .map_err(|err| err.to_string())?;
        } else {
            self.doc.save_to(&mut out).map_err(|err| err.to_string())?;
        }
        out.push(b'\n');
        Ok(out)
    }
}

/// `stream` compressed with FlateDecode (lopdf's zlib at the best level, which is deterministic).
#[must_use]
pub fn compressed(mut stream: Stream) -> Stream {
    if stream.compress().is_err() {
        return stream;
    }
    stream
}

/// A content stream written operator by operator.
#[derive(Debug, Default, Clone)]
pub struct Content {
    out: String,
}

impl Content {
    /// An empty content stream.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Appends one line, such as `q` or `0.5 w`.
    pub fn op(&mut self, line: &str) -> &mut Self {
        self.out.push_str(line);
        self.out.push('\n');
        self
    }

    /// Sets the fill colour as RGB from 0 to 255.
    pub fn fill_rgb(&mut self, rgb: (u8, u8, u8)) -> &mut Self {
        let line = format!("{} {} {} rg", unit(rgb.0), unit(rgb.1), unit(rgb.2));
        self.op(&line)
    }

    /// Sets the stroke colour as RGB from 0 to 255.
    pub fn stroke_rgb(&mut self, rgb: (u8, u8, u8)) -> &mut Self {
        let line = format!("{} {} {} RG", unit(rgb.0), unit(rgb.1), unit(rgb.2));
        self.op(&line)
    }

    /// A filled rectangle.
    pub fn fill_rect(&mut self, x: f64, y: f64, width: f64, height: f64) -> &mut Self {
        let line = format!("{} {} {} {} re f", num(x), num(y), num(width), num(height));
        self.op(&line)
    }

    /// A stroked rectangle.
    pub fn stroke_rect(&mut self, x: f64, y: f64, width: f64, height: f64) -> &mut Self {
        let line = format!("{} {} {} {} re S", num(x), num(y), num(width), num(height));
        self.op(&line)
    }

    /// A stroked line.
    pub fn line(&mut self, from: (f64, f64), to: (f64, f64)) -> &mut Self {
        let line = format!(
            "{} {} m {} {} l S",
            num(from.0),
            num(from.1),
            num(to.0),
            num(to.1)
        );
        self.op(&line)
    }

    /// Sets the line width.
    pub fn line_width(&mut self, width: f64) -> &mut Self {
        let line = format!("{} w", num(width));
        self.op(&line)
    }

    /// The stream's bytes.
    #[must_use]
    pub fn into_bytes(self) -> Vec<u8> {
        self.out.into_bytes()
    }

    /// Appends another content's operators.
    pub fn append(&mut self, other: &Content) -> &mut Self {
        self.out.push_str(&other.out);
        self
    }
}

/// A colour component from 0 to 255 as a number from 0 to 1.
fn unit(value: u8) -> String {
    num(f64::from(value) / 255.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn numbers_have_at_most_three_decimals() {
        assert_eq!(num(1.0), "1");
        assert_eq!(num(10.5), "10.5");
        assert_eq!(num(0.123_456), "0.123");
        assert_eq!(num(-0.0001), "0");
        assert_eq!(num(595.276), "595.276");
    }

    #[test]
    fn literal_strings_escape_and_use_octal() {
        assert_eq!(literal(b"a(b)\\"), "(a\\(b\\)\\\\)");
        assert_eq!(literal(&[0xFC, b'x']), "(\\374x)");
    }

    #[test]
    fn text_strings_use_utf16_outside_ascii() {
        assert_eq!(
            text("Kira"),
            Object::String(b"Kira".to_vec(), StringFormat::Literal)
        );
        let Object::String(bytes, StringFormat::Hexadecimal) = text("ş") else {
            unreachable!("UTF-16 is written as hex");
        };
        assert_eq!(bytes, [0xFE, 0xFF, 0x01, 0x5F]);
    }

    #[test]
    fn the_same_document_gives_the_same_bytes() {
        let make = || {
            let mut pdf = Pdf::new("1.7");
            pdf.add_page(Page {
                size: A4,
                content: b"0 0 m 10 10 l S".to_vec(),
                ..Page::default()
            });
            let info = Info {
                title: "Test".to_owned(),
                producer: "tools/corpus".to_owned(),
                created: "D:20261013093000+03'00'".to_owned(),
                ..Info::default()
            };
            pdf.finish(Dictionary::new(), &info, "test")
        };
        let first = make();
        assert!(first.is_ok());
        assert_eq!(first, make());
    }
}
