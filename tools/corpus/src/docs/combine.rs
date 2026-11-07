//! The Combine acceptance's fixture (ROADMAP §8), since `kira-tr` has attachments but no outline:
//!
//! - **combine-outline:** a 2-page Turkish annex with a nested outline, and
//! - **combine-photo.jpg:** a standalone JPEG, an extra of the same generator.

use super::files::jpeg_components;
use super::{Doc, generated, info, open_first, opens};
use crate::pdf::{self, name, real, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Flow, Frame, Paragraph};
use crate::{Generated, Generator};
use lopdf::{Object, ObjectId, dictionary};

/// The 2-page PDF with an outline, and the JPG.
pub const COMBINE_OUTLINE: Generator = Generator {
    name: "combine-outline",
    build,
    expect: opens(),
};

const TOP: f64 = pdf::A4.1 - 80.0;

/// An outline item's destination: the top of `page`.
fn dest(page: ObjectId) -> Object {
    Object::Array(vec![
        page.into(),
        name("XYZ"),
        Object::Null,
        real(TOP + 20.0),
        Object::Null,
    ])
}

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = doc.word_style(sources, FontFile::PlexSans, 11.0)?;
    let mut flow = Flow::new(Frame {
        x: 72.0,
        top: TOP,
        bottom: 80.0,
        width: pdf::A4.0 - 144.0,
    });
    for (index, (heading, body)) in [
        (
            "Ek A: Teslim tutanağı",
            "Kiracı, dairenin anahtarlarını ve sayaç okumalarını bu tutanakla teslim almıştır.",
        ),
        (
            "Ek B: Demirbaş listesi",
            "Dairede bulunan demirbaşlar, teslim tarihindeki durumlarıyla bu listede yer alır.",
        ),
    ]
    .into_iter()
    .enumerate()
    {
        if index > 0 {
            flow.break_page();
        }
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(&style.sized(16.0), heading).spaced(0.0, 12.0),
        )?;
        flow.paragraph(&mut doc.fonts, &Paragraph::new(&style, body))?;
    }
    let (ids, expected) = doc.add_pages(flow.into_pages(), pdf::A4);

    let root = doc.pdf.reserve();
    let (first, nested, second) = (doc.pdf.reserve(), doc.pdf.reserve(), doc.pdf.reserve());
    doc.pdf.set(
        first,
        dictionary! {
            "Title" => text("Ek A: Teslim tutanağı"),
            "Parent" => root,
            "Next" => second,
            "First" => nested,
            "Last" => nested,
            "Count" => 1,
            "Dest" => dest(ids[0]),
        },
    );
    doc.pdf.set(
        nested,
        dictionary! {
            "Title" => text("Sayaç okumaları"),
            "Parent" => first,
            "Dest" => dest(ids[0]),
        },
    );
    doc.pdf.set(
        second,
        dictionary! {
            "Title" => text("Ek B: Demirbaş listesi"),
            "Parent" => root,
            "Prev" => first,
            "Dest" => dest(ids[1]),
        },
    );
    doc.pdf.set(
        root,
        dictionary! { "Type" => "Outlines", "First" => first, "Last" => second, "Count" => 3 },
    );
    let catalog = dictionary! {
        "Lang" => text("tr-TR"),
        "OpenAction" => open_first(ids[0]),
        "Outlines" => root,
        "PageMode" => "UseOutlines",
    };
    let bytes = doc.close(
        catalog,
        &info(
            "Kira sözleşmesi ekleri",
            "Mert Kaya",
            "Kelime işlemci",
            "D:20261013093000+03'00'",
        ),
        "combine-outline",
        None,
    )?;
    let mut files = generated(bytes, expected.text);
    // 640 × 480 at 150 dpi, a landscape picture.
    let photo = jpeg_components(640, 480, 150, 3, |x, y, component| match component {
        0 => u8::try_from(60 + (x + y) / 8).unwrap_or(255),
        1 => u8::try_from(100 + x / 16).unwrap_or(255),
        _ => u8::try_from(160 - y / 16).unwrap_or(0),
    })?;
    files.extras.push(("combine-photo.jpg".to_owned(), photo));
    Ok(files)
}
