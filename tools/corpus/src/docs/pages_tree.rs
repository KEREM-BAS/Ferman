//! `pages-tree`: what Organize must keep while pages move (M4 plan, W1, decision 2): a page tree of
//! three levels whose pages inherit their `/Resources`, boxes and `/Rotate`, `/PageLabels`, and an
//! outline with both an integer destination and a page reference.

use super::{Doc, generated, info};
use crate::pdf::{self, name, real, rect, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Flow, Frame, Paragraph};
use crate::{Expect, Generated, Generator};
use lopdf::{Dictionary, Object, dictionary};

/// The file. Two pages are turned, which PDFium puts in an order of its own.
pub const PAGES_TREE: Generator = Generator {
    name: "pages-tree",
    build,
    expect: Expect::OpensUnordered,
};

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let style = doc.word_style(sources, FontFile::PlexSans, 14.0)?;
    let mut flow = Flow::new(Frame {
        x: 72.0,
        // Low enough for a turned page: pdfium-render's whole-page text reads a rectangle of the
        // displayed size in the page's own coordinates.
        top: 500.0,
        bottom: 80.0,
        width: pdf::A4.0 - 144.0,
    });
    for (index, body) in [
        "Birinci sayfa, ağacın sola dönen kolunda.",
        "İkinci sayfa, aynı kolda ve aynı dönüşle.",
        "Üçüncü sayfa, kök düğümün boyutunu alır.",
        "Dördüncü sayfa, kırpılan düğümde.",
        "Beşinci sayfa, aynı düğümde.",
        "Altıncı sayfa, kaynakları kendisinde tutar.",
    ]
    .into_iter()
    .enumerate()
    {
        if index > 0 {
            flow.break_page();
        }
        flow.paragraph(&mut doc.fonts, &Paragraph::new(&style, body))?;
    }
    let (ids, expected) = doc.add_pages(flow.into_pages(), pdf::A4);
    let [first, second, third, fourth, fifth, sixth] = ids[..] else {
        return Err("six pages expected".to_owned());
    };

    let root = doc.pdf.pages_id();
    let (turned, plain, deep) = (doc.pdf.reserve(), doc.pdf.reserve(), doc.pdf.reserve());
    let mut resources = None;
    // Every page but the last leaves its boxes and resources to its ancestors.
    for (page, parent) in [
        (first, turned),
        (second, turned),
        (third, plain),
        (fourth, deep),
        (fifth, deep),
        (sixth, plain),
    ] {
        let Some(Object::Dictionary(dict)) = doc.pdf.doc.objects.get_mut(&page) else {
            return Err("a page that is no dictionary".to_owned());
        };
        dict.set("Parent", parent);
        if page != sixth {
            dict.remove(b"MediaBox");
            resources = dict.remove(b"Resources").or(resources);
        }
    }
    doc.fonts.finish(&mut doc.pdf)?;

    let outline = doc.pdf.reserve();
    let by_index = doc.pdf.add(dictionary! {
        "Title" => text("Üçüncü sayfa"),
        "Parent" => outline,
        "Dest" => Object::Array(vec![2.into(), name("XYZ"), Object::Null, real(700.0), Object::Null]),
    });
    let by_reference = doc.pdf.add(dictionary! {
        "Title" => text("Beşinci sayfa"),
        "Parent" => outline,
        "Prev" => by_index,
        "Dest" => Object::Array(vec![fifth.into(), name("Fit")]),
    });
    if let Some(Object::Dictionary(dict)) = doc.pdf.doc.objects.get_mut(&by_index) {
        dict.set("Next", by_reference);
    }
    doc.pdf.set(
        outline,
        dictionary! { "Type" => "Outlines", "First" => by_index, "Last" => by_reference, "Count" => 2 },
    );
    let catalog = dictionary! {
        "Lang" => text("tr-TR"),
        "Outlines" => outline,
        "PageLabels" => dictionary! { "Nums" => vec![
            0.into(), Object::Dictionary(dictionary! { "S" => "r" }),
            2.into(), Object::Dictionary(dictionary! { "S" => "D" }),
            5.into(), Object::Dictionary(dictionary! { "S" => "D", "P" => text("Ek-") }),
        ]},
    };
    doc.pdf.close(
        catalog,
        &info(
            "Sayfa ağacı",
            "Ferman",
            "Kelime işlemci",
            "D:20261106120000+03'00'",
        ),
        "pages-tree",
    )?;

    // `close` wrote a flat tree; the nodes take its place.
    let kids = |ids: &[lopdf::ObjectId]| -> Vec<Object> {
        ids.iter().map(|id| Object::Reference(*id)).collect()
    };
    let mut root_node: Dictionary = dictionary! {
        "Type" => "Pages",
        "Kids" => kids(&[turned, plain]),
        "Count" => 6,
        "MediaBox" => rect(0.0, 0.0, pdf::A4.0, pdf::A4.1),
    };
    if let Some(resources) = resources {
        root_node.set("Resources", resources);
    }
    doc.pdf.set(root, root_node);
    doc.pdf.set(
        turned,
        dictionary! {
            "Type" => "Pages",
            "Parent" => root,
            "Kids" => kids(&[first, second]),
            "Count" => 2,
            "Rotate" => 90,
        },
    );
    doc.pdf.set(
        plain,
        dictionary! {
            "Type" => "Pages",
            "Parent" => root,
            "Kids" => kids(&[third, deep, sixth]),
            "Count" => 4,
        },
    );
    doc.pdf.set(
        deep,
        dictionary! {
            "Type" => "Pages",
            "Parent" => plain,
            "Kids" => kids(&[fourth, fifth]),
            "Count" => 2,
            // From the origin: pdfium-render's whole-page text ignores a crop box's offset.
            "CropBox" => rect(0.0, 0.0, pdf::A4.0 - 20.0, pdf::A4.1 - 40.0),
        },
    );
    Ok(generated(doc.pdf.save()?, expected.text))
}
