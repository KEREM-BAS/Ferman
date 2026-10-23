//! The generators of the first wave (ADR 0020) and what they share: a [`Doc`] that loads faces
//! once and makes the font resources a producer would, and helpers for page decorations.

mod contracts;
mod damaged;
mod files;
mod forms;
mod kira;
mod letter;
mod long;
mod payslip;
mod plan;
mod report;
mod scans;
mod scripts;
mod tez;

use crate::crypt::{self, Security};
use crate::font::{Face, PdfFont, SimpleFont, StandardFont, Type0Font};
use crate::pdf::{self, Info, Pdf};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, FontKey, Fonts, PageText, Paragraph, Style, expected_text, lay_out};
use crate::vertical::Vertical;
use crate::{Expect, Generated, Generator};
use lopdf::{Dictionary, Object, ObjectId};
use std::collections::BTreeMap;
use std::rc::Rc;

/// Every generator, in the order of the README's rows.
pub const GENERATORS: &[Generator] = &[
    kira::KIRA_TR,
    kira::KIRA_TR_DAMAGED,
    kira::KIRA_TR_RESTRICTED,
    damaged::TRUNCATED,
    damaged::DISAGREE_PAGES,
    payslip::PAYSLIP_AES256,
    payslip::PAYSLIP_RC4_40,
    payslip::PAYSLIP_RC4_128,
    payslip::PAYSLIP_AES128,
    forms::XFA_VISA,
    forms::FORM_AKS1_TR,
    forms::FORM_AKS1_FLAT,
    contracts::MIETVERTRAG_DE,
    contracts::NDA_EN,
    report::REPORT_AR,
    letter::LETTER_JA_VERTICAL,
    tez::TEZ_TR,
    plan::OCG_PLAN,
    scripts::JS_OPENACTION,
    scans::SCAN_TR,
    scans::QUOTE_JA_SCAN,
    long::LONG_500,
    long::IMAR_2400,
];

/// The `/Producer` of every generated file.
pub const PRODUCER: &str = "Ferman tools/corpus";

/// A document being generated.
pub struct Doc {
    /// The writer.
    pub pdf: Pdf,
    /// Its fonts.
    pub fonts: Fonts,
    faces: BTreeMap<FontFile, Rc<Face>>,
    word: BTreeMap<FontFile, (FontKey, FontKey)>,
    composite: BTreeMap<FontFile, FontKey>,
    vertical: BTreeMap<FontFile, FontKey>,
}

impl Doc {
    /// An empty document of `version`.
    #[must_use]
    pub fn new(version: &str) -> Self {
        Self {
            pdf: Pdf::new(version),
            fonts: Fonts::new(),
            faces: BTreeMap::new(),
            word: BTreeMap::new(),
            composite: BTreeMap::new(),
            vertical: BTreeMap::new(),
        }
    }

    /// The face of `file`, loaded once.
    ///
    /// # Errors
    ///
    /// A message when the font cannot be read.
    pub fn face(&mut self, sources: &Sources, file: FontFile) -> Result<Rc<Face>, String> {
        if let Some(face) = self.faces.get(&file) {
            return Ok(Rc::clone(face));
        }
        let serif = matches!(
            file,
            FontFile::PlexSerif
                | FontFile::PlexSerifItalic
                | FontFile::PlexSerifSemiBold
                | FontFile::EbGaramond
                | FontFile::NotoSerifJp
                | FontFile::NotoSerifJpSemiBold
        );
        let mut face = Face::new(sources.font(file)?, serif, file.variations())?;
        if let Some(name) = file.instance_name() {
            name.clone_into(&mut face.postscript_name);
        }
        let face = Rc::new(face);
        self.faces.insert(file, Rc::clone(&face));
        Ok(face)
    }

    /// A style as Word writes it: a simple TrueType font with WinAnsiEncoding, and the same face
    /// as a composite font for the characters outside Windows-1252. Justified with `Tw`.
    ///
    /// # Errors
    ///
    /// A message when the font cannot be read.
    pub fn word_style(
        &mut self,
        sources: &Sources,
        file: FontFile,
        size: f64,
    ) -> Result<Style, String> {
        let (simple, composite) = match self.word.get(&file) {
            Some(keys) => *keys,
            None => {
                let face = self.face(sources, file)?;
                let simple = SimpleFont::new(&mut self.pdf, Rc::clone(&face));
                let simple = self.fonts.add(PdfFont::Simple(simple));
                let composite = Type0Font::new(&mut self.pdf, face);
                let composite = self.fonts.add(PdfFont::Type0(composite));
                self.word.insert(file, (simple, composite));
                (simple, composite)
            }
        };
        let mut style = Style::new(simple, size);
        style.fallback = Some(composite);
        style.word_spacing = true;
        Ok(style)
    }

    /// A style in one composite font, shaped, justified with `TJ`.
    ///
    /// # Errors
    ///
    /// A message when the font cannot be read.
    pub fn composite_style(
        &mut self,
        sources: &Sources,
        file: FontFile,
        size: f64,
    ) -> Result<Style, String> {
        let key = match self.composite.get(&file) {
            Some(key) => *key,
            None => {
                let face = self.face(sources, file)?;
                let font = Type0Font::new(&mut self.pdf, face);
                let key = self.fonts.add(PdfFont::Type0(font));
                self.composite.insert(file, key);
                key
            }
        };
        Ok(Style::new(key, size))
    }

    /// Vertical text in `file`: the face as an `Identity-V` font and as an `Identity-H` one for
    /// upright runs. `tracking` is the space after each cell in thousandths of an em.
    ///
    /// # Errors
    ///
    /// A message when the font cannot be read.
    pub fn vertical_style(
        &mut self,
        sources: &Sources,
        file: FontFile,
        size: f64,
        tracking: f64,
    ) -> Result<Vertical, String> {
        let face = self.face(sources, file)?;
        let font = match self.vertical.get(&file) {
            Some(key) => *key,
            None => {
                let font = Type0Font::vertical(&mut self.pdf, Rc::clone(&face));
                let key = self.fonts.add(PdfFont::Type0(font));
                self.vertical.insert(file, key);
                key
            }
        };
        let upright = self.composite_style(sources, file, size)?.font;
        Ok(Vertical {
            font,
            upright,
            size,
            tracking,
            color: (0, 0, 0),
            origin: face.vertical_origin(),
        })
    }

    /// A style in a font that is named but not embedded, with widths from `metrics`.
    ///
    /// # Errors
    ///
    /// A message when the metrics font cannot be read.
    pub fn standard_style(
        &mut self,
        sources: &Sources,
        metrics: FontFile,
        base_font: &str,
        subtype: &'static str,
        turkish: bool,
        size: f64,
    ) -> Result<Style, String> {
        let face = self.face(sources, metrics)?;
        let font = StandardFont::new(&mut self.pdf, face, base_font, subtype, turkish);
        let key = self.fonts.add(PdfFont::Standard(font));
        Ok(Style::new(key, size))
    }

    /// Draws a single line of text at a baseline, aligned in `width` from `x`, and records it.
    ///
    /// # Errors
    ///
    /// A message when a character cannot be set.
    pub fn line(
        &mut self,
        page: &mut PageText,
        style: &Style,
        text: &str,
        (x, baseline): (f64, f64),
        width: f64,
        align: Align,
    ) -> Result<(), String> {
        let paragraph = Paragraph::new(style, text).aligned(align).leading(1.0);
        let lines = lay_out(&mut self.fonts, &paragraph.spans, f64::INFINITY)?;
        let top = baseline + style.size * 0.78;
        page.draw(&self.fonts, &lines, &paragraph, x, width, top, true);
        Ok(())
    }

    /// Adds `pages` and returns their objects and expected text. Fonts are written later, by
    /// [`Doc::close`].
    pub fn add_pages(&mut self, pages: Vec<PageText>, size: (f64, f64)) -> (Vec<ObjectId>, String) {
        let mut ids = Vec::with_capacity(pages.len());
        let mut texts = Vec::with_capacity(pages.len());
        for mut page in pages {
            texts.push(std::mem::take(&mut page.lines));
            let extra = std::mem::take(&mut page.extra);
            let mut page = page.into_page(&self.fonts, size);
            page.extra = extra;
            ids.push(self.pdf.add_page(page));
        }
        (ids, expected_text(&texts))
    }

    /// Writes the fonts, the catalog and the information dictionary, encrypts the document when
    /// asked, and returns the file.
    ///
    /// # Errors
    ///
    /// A message when a font cannot be subset or the file cannot be written.
    pub fn close(
        mut self,
        catalog: Dictionary,
        info: &Info,
        seed: &str,
        security: Option<&Security>,
    ) -> Result<Vec<u8>, String> {
        self.fonts.finish(&mut self.pdf)?;
        let mut pdf = self.pdf;
        pdf.close(catalog, info, seed)?;
        if let Some(security) = security {
            crypt::encrypt(&mut pdf.doc, security)?;
        }
        pdf.save()
    }
}

/// The information dictionary every generator starts from.
#[must_use]
pub fn info(title: &str, author: &str, creator: &str, created: &str) -> Info {
    Info {
        title: title.to_owned(),
        author: author.to_owned(),
        creator: creator.to_owned(),
        producer: PRODUCER.to_owned(),
        created: created.to_owned(),
        ..Info::default()
    }
}

/// The generated files.
#[must_use]
pub fn generated(pdf: Vec<u8>, expected_text: String) -> Generated {
    Generated { pdf, expected_text }
}

/// An `/OpenAction` that shows the first page at its top.
#[must_use]
pub fn open_first(page: ObjectId) -> Object {
    Object::Array(vec![
        page.into(),
        pdf::name("XYZ"),
        Object::Null,
        Object::Null,
        Object::Null,
    ])
}

/// A generator that opens without a password.
#[must_use]
pub const fn opens() -> Expect {
    Expect::Opens { password: None }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    fn make(generator: &Generator) -> Vec<u8> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
        let [(_, pdf), _] = generator.outputs(&Sources::new(&root)).unwrap();
        pdf
    }

    #[test]
    fn lopdf_finds_two_pages_where_pdfium_finds_three() {
        let doc = lopdf::Document::load_mem(&make(&damaged::DISAGREE_PAGES)).unwrap();
        assert_eq!(doc.get_pages().len(), 2);
        let pages = doc
            .catalog()
            .unwrap()
            .get(b"Pages")
            .unwrap()
            .as_reference()
            .unwrap();
        let count = doc.get_dictionary(pages).unwrap().get(b"Count").unwrap();
        assert_eq!(count.as_i64().unwrap(), 3);
    }

    #[test]
    fn the_scan_stops_inside_object_13_with_12_complete() {
        let file = make(&damaged::TRUNCATED);
        assert_eq!(file.len(), damaged::CUT_AT);
        let has = |needle: &[u8]| file.windows(needle.len()).any(|window| window == needle);
        assert!(has(b"\n12 0 obj"));
        assert!(has(b"\n13 0 obj"));
        assert!(!has(b"\n14 0 obj"));
        assert!(!has(b"trailer"));
        assert!(!has(b"/Catalog"));
        // Object 12 is complete: an endstream follows it before object 13.
        let twelve = file.windows(9).position(|w| w == b"\n12 0 obj").unwrap();
        let thirteen = file.windows(9).position(|w| w == b"\n13 0 obj").unwrap();
        assert!(file[twelve..thirteen].windows(6).any(|w| w == b"endobj"));
    }

    #[test]
    fn no_offset_of_the_damaged_copy_points_at_its_object() {
        let file = make(&kira::KIRA_TR_DAMAGED);
        let table = file.windows(6).rposition(|w| w == b"\nxref\n").unwrap() + 6;
        let text = String::from_utf8_lossy(&file[table..]).into_owned();
        let mut lines = text.lines();
        let header: Vec<usize> = lines
            .next()
            .unwrap()
            .split(' ')
            .map(|n| n.parse().unwrap())
            .collect();
        let mut checked = 0;
        for (index, line) in lines.take(header[1]).enumerate() {
            if !line.trim_end().ends_with('n') {
                continue;
            }
            let offset: usize = line[..10].parse().unwrap();
            let object = format!("{} 0 obj", header[0] + index);
            assert!(
                !file[offset..].starts_with(object.as_bytes()),
                "{object} at {offset}"
            );
            assert!(
                file[offset + 2..].starts_with(object.as_bytes()),
                "{object} two bytes on"
            );
            checked += 1;
        }
        assert!(checked > 40, "{checked} entries");
    }

    #[test]
    fn the_restricted_contract_is_encrypted_without_a_user_password() {
        let doc = lopdf::Document::load_mem(&make(&kira::KIRA_TR_RESTRICTED)).unwrap();
        assert!(doc.is_encrypted() || doc.encryption_state.is_some());
        assert_eq!(doc.get_pages().len(), 3);
    }
}
