//! Files damaged on purpose:
//!
//! - **truncated:** "Tarama_0042.pdf" of `a1-9b`: a four-page scan whose writer put the page
//!   objects first and the page tree and catalog last, cut off after 18 KB, inside object 13
//!   (the first page image). Objects 1 to 12 are complete; there is no catalog and no trailer,
//!   so it cannot be repaired.
//! - **disagree-pages:** three pages, the second without `/Type /Page`. PDFium takes the page
//!   tree's `/Count` and any leaf as a page and finds three; a reader that requires the type,
//!   as lopdf 0.45 does, finds two. The two-parser check of G102 opens it read-only.

use super::files::jpeg;
use super::{Doc, generated, info, open_first, opens};
use crate::pdf::{self, Pdf, num, rect};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Flow, Frame, Paragraph};
use crate::{Expect, Generated, Generator};
use lopdf::{Dictionary, Object, Stream, dictionary};

/// The scan cut off after 18 KB.
pub const TRUNCATED: Generator = Generator {
    name: "truncated",
    build: truncated,
    expect: Expect::Fails,
};

/// The file whose page count depends on the reader.
pub const DISAGREE_PAGES: Generator = Generator {
    name: "disagree-pages",
    build: disagree,
    expect: opens(),
};

/// Where the file is cut: 18 KB.
pub const CUT_AT: usize = 18 * 1024;

/// A scanned page: a pale sheet with lines of "text" as dark blocks.
fn scan(page: u32) -> Result<Vec<u8>, String> {
    jpeg(1240, 1752, 150, move |x, y| {
        let line = (160..1600).contains(&y) && (y - 160) % 44 < 14 && (120..1120).contains(&x);
        let gap = (x / 9 + y / 44 + page).is_multiple_of(6);
        if line && !gap { 64 } else { 236 }
    })
}

/// The XMP packet, padded as scanners pad it so the metadata can grow in place.
fn xmp(padding: usize) -> Vec<u8> {
    let mut packet = String::from(
        "<?xpacket begin=\"\u{feff}\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n<rdf:Description rdf:about=\"\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\" xmlns:pdf=\"http://ns.adobe.com/pdf/1.3/\">\n<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">Tarama_0042</rdf:li></rdf:Alt></dc:title>\n<xmp:CreateDate>2026-10-02T09:41:12+03:00</xmp:CreateDate>\n<xmp:CreatorTool>Tarayıcı</xmp:CreatorTool>\n<pdf:Producer>Ferman tools/corpus</pdf:Producer>\n</rdf:Description>\n</rdf:RDF>\n</x:xmpmeta>\n",
    );
    for _ in 0..padding / 100 {
        packet.push_str(&" ".repeat(99));
        packet.push('\n');
    }
    packet.push_str("<?xpacket end=\"w\"?>");
    packet.into_bytes()
}

/// The whole scan as its writer would have finished it, with the XMP padded by `padding`.
/// Objects 1 to 12 are small: the metadata, the four contents, the four page dictionaries,
/// the information dictionary and two thumbnails. The page images are 13 to 16; the page
/// tree and the catalog come last.
fn full_scan(padding: usize) -> Result<Vec<u8>, String> {
    let mut pdf = Pdf::new("1.4");
    // The writer's first object is the metadata.
    let metadata = pdf.pages_id();
    pdf.set(
        metadata,
        Stream::new(
            dictionary! { "Type" => "Metadata", "Subtype" => "XML" },
            xmp(padding),
        ),
    );
    let mut contents = Vec::new();
    for _ in 0..4 {
        let content = format!(
            "q {} 0 0 {} 0 0 cm /Im0 Do Q",
            num(pdf::A4.0),
            num(pdf::A4.1)
        );
        contents.push(pdf.stream(Dictionary::new(), content.into_bytes()));
    }
    let page_ids: Vec<_> = (0..4).map(|_| pdf.reserve()).collect();
    let info = pdf.add(dictionary! {
        "Title" => pdf::text("Tarama_0042"),
        "Creator" => pdf::text("Tarayıcı"),
        "Producer" => pdf::text(super::PRODUCER),
        "CreationDate" => pdf::text("D:20261002094112+03'00'"),
    });
    let mut thumbs = Vec::new();
    for index in 0..2u32 {
        let small = jpeg(104, 144, 18, move |x, y| {
            let line = (16..128).contains(&y)
                && (y - 16) % 6 < 2
                && (12..92).contains(&x)
                && (x / 4 + index) % 5 != 0;
            if line { 96 } else { 232 }
        })?;
        thumbs.push(pdf.add(Stream::new(
            dictionary! { "Width" => 104, "Height" => 144, "ColorSpace" => "DeviceGray", "BitsPerComponent" => 8, "Filter" => "DCTDecode" },
            small,
        )));
    }
    let images: Vec<_> = (0..4).map(|_| pdf.reserve()).collect();
    let pages_id = pdf.reserve();
    for (index, content) in contents.iter().enumerate() {
        let mut page = dictionary! {
            "Type" => "Page",
            "Parent" => pages_id,
            "MediaBox" => rect(0.0, 0.0, pdf::A4.0, pdf::A4.1),
            "Resources" => dictionary! { "XObject" => dictionary! { "Im0" => images[index] } },
            "Contents" => *content,
        };
        if let Some(thumb) = thumbs.get(index) {
            page.set("Thumb", *thumb);
        }
        pdf.set(page_ids[index], page);
    }
    for (index, image) in images.iter().enumerate() {
        let bytes = scan(u32::try_from(index).unwrap_or(0))?;
        pdf.set(
            *image,
            Stream::new(
                dictionary! {
                    "Type" => "XObject",
                    "Subtype" => "Image",
                    "Width" => 1240,
                    "Height" => 1752,
                    "ColorSpace" => "DeviceGray",
                    "BitsPerComponent" => 8,
                    "Filter" => "DCTDecode",
                },
                bytes,
            ),
        );
    }
    let kids: Vec<Object> = page_ids.iter().map(|id| Object::Reference(*id)).collect();
    pdf.set(
        pages_id,
        dictionary! { "Type" => "Pages", "Kids" => kids, "Count" => 4 },
    );
    let catalog =
        pdf.add(dictionary! { "Type" => "Catalog", "Pages" => pages_id, "Metadata" => metadata });
    pdf.doc.trailer.set("Root", catalog);
    pdf.doc.trailer.set("Info", info);
    let id = pdf::file_id("truncated");
    pdf.doc
        .trailer
        .set("ID", Object::Array(vec![pdf::hex(&id), pdf::hex(&id)]));
    pdf.save()
}

/// The offset of `N 0 obj` in `file`.
fn object_at(file: &[u8], number: u32) -> Option<usize> {
    let marker = format!("\n{number} 0 obj");
    file.windows(marker.len())
        .position(|window| window == marker.as_bytes())
        .map(|at| at + 1)
}

fn truncated(_: &Sources) -> Result<Generated, String> {
    // Write it once, then size the XMP so object 13 starts about 1 KB before the cut.
    let probe = full_scan(0)?;
    let start = object_at(&probe, 13).ok_or("no object 13")?;
    let padding = (CUT_AT - 1024).saturating_sub(start);
    let file = full_scan(padding)?;
    let start = object_at(&file, 13).ok_or("no object 13")?;
    if !(CUT_AT - 1200..CUT_AT - 100).contains(&start) {
        return Err(format!(
            "object 13 starts at {start}, not just before the cut"
        ));
    }
    if file[..CUT_AT]
        .windows(7)
        .any(|window| window == b"Catalog" || window == b"/Pages ")
    {
        return Err("the page tree or the catalog is inside the first 18 KB".to_owned());
    }
    let mut cut = file;
    cut.truncate(CUT_AT);
    Ok(generated(cut, String::new()))
}

fn disagree(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let heading = doc.word_style(sources, FontFile::PlexSansSemiBold, 14.0)?;
    let body = doc.word_style(sources, FontFile::PlexSans, 10.5)?;
    let frame = Frame {
        x: 72.0,
        top: pdf::A4.1 - 72.0,
        bottom: 72.0,
        width: pdf::A4.0 - 144.0,
    };
    let mut pages = Vec::new();
    for (index, (title, text)) in [
        ("Toplantı tutanağı — Sayfa 1", "Yönetim kurulu 6 Ekim 2026 tarihinde toplanmış ve gündemdeki maddeleri görüşmüştür. Toplantıya yedi üyenin altısı katılmıştır."),
        ("Toplantı tutanağı — Sayfa 2", "Bu sayfanın sözlüğünde /Type girdisi yoktur. Sayfa ağacının /Count değeri 3 olduğu için bazı okuyucular bu sayfayı gösterir, bazıları atlar."),
        ("Toplantı tutanağı — Sayfa 3", "Gündemdeki bütün maddeler oy birliğiyle kabul edilmiştir. Bir sonraki toplantı 3 Kasım 2026 tarihinde yapılacaktır."),
    ]
    .iter()
    .enumerate()
    {
        let mut flow = Flow::new(frame);
        flow.paragraph(&mut doc.fonts, &Paragraph::new(&heading, title).aligned(Align::Left).spaced(0.0, 10.0))?;
        flow.paragraph(&mut doc.fonts, &Paragraph::new(&body, text).leading(1.5))?;
        let mut page = flow.into_pages().pop().unwrap_or_default();
        doc.line(&mut page, &body.sized(9.0), &format!("{} / 3", index + 1), (72.0, 40.0), pdf::A4.0 - 144.0, Align::Center)?;
        pages.push(page);
    }
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    if let Some(Object::Dictionary(page)) = doc.pdf.doc.objects.get_mut(&ids[1]) {
        page.remove(b"Type");
    }
    let catalog = dictionary! { "Lang" => pdf::text("tr-TR"), "OpenAction" => open_first(ids[0]) };
    let bytes = doc.close(
        catalog,
        &info(
            "Toplantı tutanağı",
            "Yönetim kurulu",
            "Kelime işlemci",
            "D:20261006170000+03'00'",
        ),
        "disagree-pages",
        None,
    )?;
    Ok(generated(bytes, expected))
}
