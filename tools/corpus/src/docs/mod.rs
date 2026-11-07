//! The generators of the first wave (ADR 0020) and what they share: a [`Doc`] that loads faces
//! once and makes the font resources a producer would, and helpers for page decorations.

mod annotations;
mod combine;
mod contracts;
mod damaged;
mod edits;
mod encodings;
mod files;
mod form_cases;
mod forms;
mod images;
mod invoice;
mod kira;
mod letter;
mod long;
mod pages_tree;
mod paragraphs;
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
use crate::text::{Align, Expected, FontKey, Fonts, PageText, Paragraph, Style, expected, lay_out};
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
    kira::KIRA_TR_SIGNED,
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
    invoice::FATURA_TR,
    paragraphs::FA_ZWNJ,
    paragraphs::HE_PARA,
    paragraphs::ZH_HANS,
    paragraphs::ZH_HANT,
    paragraphs::KO_PARA,
    encodings::EDIT_E04_DIFFERENCES,
    encodings::EDIT_E05_FSTYPE,
    encodings::EDIT_E15_HELVETICA,
    encodings::EDIT_E16_TYPE3,
    edits::EDIT_E19_ROTATE,
    edits::EDIT_E20_FORM_TWICE,
    edits::EDIT_E21_ACTUALTEXT,
    edits::EDIT_E22_SPLIT_CONTENTS,
    edits::EDIT_E23_SHARED_CONTENTS,
    edits::EDIT_E26_INLINE_IMAGE,
    encodings::EDIT_MACROMAN,
    encodings::EDIT_90MS_RKSJ,
    encodings::EDIT_CFF_CID,
    edits::EDIT_E14_LATEX_STANDIN,
    edits::EDIT_E17_KERNED_STANDIN,
    edits::EDIT_E18_COLUMNS_STANDIN,
    paragraphs::JA_PARA,
    annotations::ANNOTS_OTHER_PRODUCER,
    form_cases::CERT_P1,
    form_cases::CERT_P2,
    form_cases::CERT_P3,
    form_cases::FORM_SIGNED,
    form_cases::FORM_HYBRID_XFA,
    form_cases::FORM_NEED_APPEARANCES,
    form_cases::FORM_SCRIPT,
    form_cases::FORM_LISTS_COMB,
    combine::COMBINE_OUTLINE,
    images::IMAGES_COMPRESS,
    pages_tree::PAGES_TREE,
];

pub use images::PROBES;

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

    /// A style in a simple embedded font of its own, without a fallback, justified with `TJ`.
    /// [`Fonts::get_mut`] sets how it is written (encoding, kept glyphs, `fsType`, Type3).
    ///
    /// # Errors
    ///
    /// A message when the font cannot be read.
    pub fn simple_style(
        &mut self,
        sources: &Sources,
        file: FontFile,
        size: f64,
    ) -> Result<Style, String> {
        let face = self.face(sources, file)?;
        let font = SimpleFont::new(&mut self.pdf, face);
        let key = self.fonts.add(PdfFont::Simple(font));
        Ok(Style::new(key, size))
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

    /// Adds `pages` and returns their objects, expected text and blocks. Fonts are written later,
    /// by [`Doc::close`].
    pub fn add_pages(
        &mut self,
        pages: Vec<PageText>,
        size: (f64, f64),
    ) -> (Vec<ObjectId>, Expected) {
        let mut ids = Vec::with_capacity(pages.len());
        let mut texts = Vec::with_capacity(pages.len());
        let mut truth = Vec::with_capacity(pages.len());
        for mut page in pages {
            texts.push(std::mem::take(&mut page.lines));
            truth.push(page.truth());
            let extra = std::mem::take(&mut page.extra);
            let mut page = page.into_page(&self.fonts, size);
            page.extra = extra;
            ids.push(self.pdf.add_page(page));
        }
        (ids, expected(&texts, &truth))
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
pub fn generated(pdf: Vec<u8>, expected: impl Into<Expected>) -> Generated {
    let Expected { text, blocks } = expected.into();
    Generated {
        pdf,
        expected_text: text,
        blocks,
        extras: Vec::new(),
    }
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
        let (_, pdf) = generator
            .outputs(&Sources::new(&root))
            .unwrap()
            .swap_remove(0);
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

    /// The dictionaries of `pdf` (streams' too) that have `key` set to the name `value`.
    fn dicts_with(pdf: &[u8], key: &[u8], value: &[u8]) -> Vec<(lopdf::Document, ObjectId)> {
        let doc = lopdf::Document::load_mem(pdf).unwrap();
        let ids: Vec<ObjectId> = doc
            .objects
            .iter()
            .filter(|(_, object)| {
                let dict = match object {
                    Object::Dictionary(dict) => dict,
                    Object::Stream(stream) => &stream.dict,
                    _ => return false,
                };
                dict.get(key)
                    .and_then(Object::as_name)
                    .is_ok_and(|name| name == value)
            })
            .map(|(id, _)| *id)
            .collect();
        ids.into_iter().map(|id| (doc.clone(), id)).collect()
    }

    #[test]
    fn the_edit_fonts_are_written_as_their_cases_need() {
        let fonts =
            |generator: &Generator, value: &[u8]| dicts_with(&make(generator), b"Subtype", value);
        // E15: Helvetica with neither widths nor a descriptor.
        let found = fonts(&encodings::EDIT_E15_HELVETICA, b"Type1");
        let (doc, id) = &found[0];
        let font = doc.get_dictionary(*id).unwrap();
        assert!(font.get(b"Widths").is_err() && font.get(b"FontDescriptor").is_err());
        // E16: a glyph procedure per character.
        let found = fonts(&encodings::EDIT_E16_TYPE3, b"Type3");
        let (doc, id) = &found[0];
        let procs = doc.get_dictionary(*id).unwrap().get(b"CharProcs").unwrap();
        assert!(procs.as_dict().unwrap().len() > 20);
        // The CFF font: CIDFontType0 with a CIDFontType0C program.
        assert_eq!(fonts(&encodings::EDIT_CFF_CID, b"CIDFontType0").len(), 1);
        assert_eq!(fonts(&encodings::EDIT_CFF_CID, b"CIDFontType0C").len(), 1);
        // The predefined CMap.
        let found = dicts_with(
            &make(&encodings::EDIT_90MS_RKSJ),
            b"Encoding",
            b"90ms-RKSJ-H",
        );
        assert_eq!(found.len(), 1);
        // The MacRoman font.
        let found = dicts_with(
            &make(&encodings::EDIT_MACROMAN),
            b"Encoding",
            b"MacRomanEncoding",
        );
        assert_eq!(found.len(), 1);
    }

    /// The embedded TrueType program of the first `/FontFile2` in `pdf`.
    fn font_program(pdf: &[u8]) -> Vec<u8> {
        let found = dicts_with(pdf, b"Type", b"FontDescriptor");
        let (doc, id) = &found[0];
        let file = doc.get_dictionary(*id).unwrap().get(b"FontFile2").unwrap();
        let stream = doc.get_object(file.as_reference().unwrap()).unwrap();
        stream.as_stream().unwrap().decompressed_content().unwrap()
    }

    #[test]
    fn the_programs_keep_gbreve_and_forbid_embedding() {
        use skrifa::MetadataProvider as _;
        use skrifa::raw::TableProvider as _;
        let program = font_program(&make(&encodings::EDIT_E04_DIFFERENCES));
        let font = skrifa::FontRef::new(&program).unwrap();
        assert!(font.charmap().map('ğ').is_some());
        let program = font_program(&make(&encodings::EDIT_E05_FSTYPE));
        let font = skrifa::FontRef::new(&program).unwrap();
        assert_eq!(font.os2().unwrap().fs_type(), 2);
        assert!(font.charmap().map('ğ').is_none());
    }

    #[test]
    fn the_edit_pages_have_their_structures() {
        let load = |generator: &Generator| lopdf::Document::load_mem(&make(generator)).unwrap();
        let contents = |doc: &lopdf::Document, page: ObjectId| {
            doc.get_dictionary(page)
                .unwrap()
                .get(b"Contents")
                .unwrap()
                .clone()
        };
        let doc = load(&edits::EDIT_E22_SPLIT_CONTENTS);
        let page = doc.get_pages()[&1];
        assert_eq!(contents(&doc, page).as_array().unwrap().len(), 2);
        let doc = load(&edits::EDIT_E23_SHARED_CONTENTS);
        let pages = doc.get_pages();
        assert_eq!(contents(&doc, pages[&1]), contents(&doc, pages[&2]));
        let doc = load(&edits::EDIT_E19_ROTATE);
        let page = doc.get_dictionary(doc.get_pages()[&1]).unwrap();
        assert_eq!(page.get(b"Rotate").unwrap().as_i64().unwrap(), 90);
        let doc = load(&edits::EDIT_E26_INLINE_IMAGE);
        let content = doc.get_page_content(doc.get_pages()[&1]);
        let has = |needle: &[u8]| content.windows(needle.len()).any(|w| w == needle);
        assert!(has(b"\nBI\n") && has(b"\nID ") && has(b"\nEI\n"));
        let doc = load(&edits::EDIT_E21_ACTUALTEXT);
        let content = doc.get_page_content(doc.get_pages()[&1]);
        assert!(content.windows(11).any(|w| w == b"/ActualText"));
        let doc = load(&edits::EDIT_E20_FORM_TWICE);
        let content = doc.get_page_content(doc.get_pages()[&1]);
        assert_eq!(content.windows(7).filter(|w| *w == b"/Fm1 Do").count(), 2);
    }

    /// The subtypes of `page`'s annotations, direct or not.
    fn annotation_types(doc: &lopdf::Document, page: ObjectId) -> Vec<String> {
        doc.get_dictionary(page)
            .unwrap()
            .get(b"Annots")
            .unwrap()
            .as_array()
            .unwrap()
            .iter()
            .map(|annot| {
                let dict = match annot {
                    Object::Reference(id) => doc.get_dictionary(*id).unwrap(),
                    other => other.as_dict().unwrap(),
                };
                let subtype = dict.get(b"Subtype").unwrap().as_name().unwrap();
                String::from_utf8_lossy(subtype).into_owned()
            })
            .collect()
    }

    #[test]
    fn the_other_producers_file_has_every_type_with_and_without_appearances() {
        let pdf = make(&annotations::ANNOTS_OTHER_PRODUCER);
        let doc = lopdf::Document::load_mem(&pdf).unwrap();
        let pages = doc.get_pages();
        let types = annotation_types(&doc, pages[&1]);
        for subtype in [
            "Highlight",
            "Underline",
            "StrikeOut",
            "Squiggly",
            "Text",
            "Popup",
            "FreeText",
            "Ink",
            "Square",
            "Circle",
            "Line",
            "Polygon",
            "Stamp",
            "Caret",
            "ACME_Mark",
        ] {
            assert!(types.iter().any(|t| t == subtype), "{subtype}: {types:?}");
        }
        let second = doc.get_dictionary(pages[&2]).unwrap();
        assert_eq!(second.get(b"Rotate").unwrap().as_i64().unwrap(), 90);
        let has = |needle: &[u8]| pdf.windows(needle.len()).any(|w| w == needle);
        assert!(has(b"/RC") && has(b"/IRT") && has(b"/State") && has(b"/ACME_Data"));
        // Both with and without an appearance.
        let dicts: Vec<&Dictionary> = doc
            .objects
            .values()
            .filter_map(|object| object.as_dict().ok())
            .filter(|dict| dict.has(b"NM"))
            .collect();
        assert!(dicts.iter().any(|dict| dict.has(b"AP")));
        assert!(dicts.iter().any(|dict| !dict.has(b"AP")));
    }

    #[test]
    fn the_certified_files_declare_their_levels() {
        for (generator, level) in [
            (&form_cases::CERT_P1, 1),
            (&form_cases::CERT_P2, 2),
            (&form_cases::CERT_P3, 3),
        ] {
            let doc = lopdf::Document::load_mem(&make(generator)).unwrap();
            let perms = doc.catalog().unwrap().get(b"Perms").unwrap();
            let value = perms.as_dict().unwrap().get(b"DocMDP").unwrap();
            let value = doc.get_dictionary(value.as_reference().unwrap()).unwrap();
            let reference = value.get(b"Reference").unwrap().as_array().unwrap();
            let params = reference[0]
                .as_dict()
                .unwrap()
                .get(b"TransformParams")
                .unwrap()
                .as_dict()
                .unwrap();
            assert_eq!(params.get(b"P").unwrap().as_i64().unwrap(), level);
        }
    }

    /// A form's `/AcroForm`, as a dictionary of the loaded document.
    fn acro_form(doc: &lopdf::Document) -> &Dictionary {
        doc.catalog()
            .unwrap()
            .get(b"AcroForm")
            .unwrap()
            .as_dict()
            .unwrap()
    }

    #[test]
    fn the_signed_form_locks_two_fields_through_field_mdp() {
        let pdf = make(&form_cases::FORM_SIGNED);
        let doc = lopdf::Document::load_mem(&pdf).unwrap();
        let root = doc.trailer.get(b"Root").unwrap().as_reference().unwrap();
        let value = doc
            .objects
            .values()
            .filter_map(|object| object.as_dict().ok())
            .find(|dict| dict.has(b"ByteRange"))
            .unwrap();
        let reference = value.get(b"Reference").unwrap().as_array().unwrap();
        let reference = reference[0].as_dict().unwrap();
        assert_eq!(
            reference
                .get(b"TransformMethod")
                .unwrap()
                .as_name()
                .unwrap(),
            b"FieldMDP"
        );
        assert_eq!(
            reference.get(b"Data").unwrap().as_reference().unwrap(),
            root
        );
        let flags = acro_form(&doc).get(b"SigFlags").unwrap();
        assert_eq!(flags.as_i64().unwrap(), 3);
    }

    #[test]
    fn the_form_cases_have_what_they_are_for() {
        let doc = lopdf::Document::load_mem(&make(&form_cases::FORM_HYBRID_XFA)).unwrap();
        assert!(acro_form(&doc).has(b"XFA"));
        assert!(
            !acro_form(&doc)
                .get(b"Fields")
                .unwrap()
                .as_array()
                .unwrap()
                .is_empty()
        );
        assert!(!doc.catalog().unwrap().has(b"NeedsRendering"));

        let doc = lopdf::Document::load_mem(&make(&form_cases::FORM_NEED_APPEARANCES)).unwrap();
        assert_eq!(
            acro_form(&doc).get(b"NeedAppearances").unwrap(),
            &Object::Boolean(true)
        );
        let pages = doc.get_pages();
        let page = doc.get_dictionary(pages[&1]).unwrap();
        for widget in page.get(b"Annots").unwrap().as_array().unwrap() {
            let widget = doc.get_dictionary(widget.as_reference().unwrap()).unwrap();
            assert!(!widget.has(b"AP"));
        }

        let pdf = make(&form_cases::FORM_SCRIPT);
        for script in [&b"/AA"[..], b"AFSimple_Calculate", b"/CO", b"/JavaScript"] {
            assert!(pdf.windows(script.len()).any(|w| w == script));
        }

        let pdf = make(&form_cases::FORM_LISTS_COMB);
        let doc = lopdf::Document::load_mem(&pdf).unwrap();
        let flags: Vec<i64> = doc
            .objects
            .values()
            .filter_map(|object| object.as_dict().ok())
            .filter_map(|dict| dict.get(b"Ff").ok())
            .filter_map(|flags| flags.as_i64().ok())
            .collect();
        assert!(flags.contains(&(1 << 21)), "a multiple-selection list");
        assert!(flags.contains(&(1 << 24)), "a comb field");
    }

    #[test]
    fn the_combine_fixture_has_two_pages_an_outline_and_a_jpeg() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
        let outputs = combine::COMBINE_OUTLINE
            .outputs(&Sources::new(&root))
            .unwrap();
        let doc = lopdf::Document::load_mem(&outputs[0].1).unwrap();
        assert_eq!(doc.get_pages().len(), 2);
        assert!(doc.catalog().unwrap().has(b"Outlines"));
        let (name, jpeg) = outputs.last().unwrap();
        assert_eq!(name, "generated/combine-photo.jpg");
        assert_eq!(&jpeg[..2], &[0xFF, 0xD8]);
    }

    #[test]
    fn the_page_tree_file_leaves_its_attributes_to_its_nodes() {
        let doc = lopdf::Document::load_mem(&make(&pages_tree::PAGES_TREE)).unwrap();
        let pages = doc.get_pages();
        assert_eq!(pages.len(), 6);
        let page = doc.get_dictionary(pages[&1]).unwrap();
        for key in [&b"MediaBox"[..], b"CropBox", b"Resources", b"Rotate"] {
            assert!(!page.has(key));
        }
        let Ok(parent) = page.get(b"Parent").and_then(lopdf::Object::as_reference) else {
            panic!("a page without its parent");
        };
        assert!(doc.get_dictionary(parent).unwrap().has(b"Rotate"));
        assert!(doc.get_dictionary(pages[&6]).unwrap().has(b"MediaBox"));
        assert!(doc.catalog().unwrap().has(b"PageLabels"));
    }

    #[test]
    fn the_image_file_has_every_kind_of_image() {
        let pdf = make(&images::IMAGES_COMPRESS);
        let has = |needle: &[u8]| pdf.windows(needle.len()).any(|w| w == needle);
        for key in [
            &b"/DCTDecode"[..],
            b"/FlateDecode",
            b"/JPXDecode",
            b"/DeviceCMYK",
            b"/SMask",
            b"/ImageMask",
            b"/Indexed",
            b"/Pattern",
        ] {
            assert!(has(key), "{}", String::from_utf8_lossy(key));
        }
    }

    /// The object a top-level outline item points at, as a page number from 0.
    fn top_level_pages(doc: &lopdf::Document) -> Vec<usize> {
        let order: Vec<ObjectId> = doc.get_pages().into_values().collect();
        let outlines = doc.catalog().unwrap().get(b"Outlines").unwrap();
        let outlines = doc
            .get_dictionary(outlines.as_reference().unwrap())
            .unwrap();
        let mut item = outlines.get(b"First").ok().cloned();
        let mut pages = Vec::new();
        while let Some(Object::Reference(id)) = item {
            let dict = doc.get_dictionary(id).unwrap();
            let dest = dict.get(b"Dest").unwrap().as_array().unwrap();
            let page = dest[0].as_reference().unwrap();
            pages.push(order.iter().position(|id| *id == page).unwrap());
            item = dict.get(b"Next").ok().cloned();
        }
        pages
    }

    #[test]
    fn splitting_the_thesis_by_chapter_adds_up_to_its_pages() {
        // Decision 4: pages before the first top-level bookmark are a file of their own.
        let doc = lopdf::Document::load_mem(&make(&tez::TEZ_TR)).unwrap();
        let starts = top_level_pages(&doc);
        assert_eq!(starts[0], 2, "the cover and KABUL VE ONAY have no entry");
        assert!(
            starts.windows(2).all(|pair| pair[0] < pair[1]),
            "{starts:?}"
        );
        let mut bounds = vec![0];
        bounds.extend(&starts);
        bounds.push(doc.get_pages().len());
        let sizes: Vec<usize> = bounds.windows(2).map(|pair| pair[1] - pair[0]).collect();
        assert_eq!(sizes.iter().sum::<usize>(), 64);
        assert!(sizes.iter().all(|size| *size > 0), "{sizes:?}");
    }

    #[test]
    fn the_restricted_contract_is_encrypted_without_a_user_password() {
        let doc = lopdf::Document::load_mem(&make(&kira::KIRA_TR_RESTRICTED)).unwrap();
        assert!(doc.is_encrypted() || doc.encryption_state.is_some());
        assert_eq!(doc.get_pages().len(), 3);
    }
}
