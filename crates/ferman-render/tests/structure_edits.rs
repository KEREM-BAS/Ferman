//! Outline, information and attachment edits (M4 plan W6) as another reader sees them: ferman-core
//! writes them as an incremental update, and PDFium's own bookmark, metadata and attachment APIs
//! read the result. The original stays an exact prefix of the saved file.
//!
//! Needs the PDFium library (`tools/pdfium/fetch.sh`, then an absolute `FERMAN_PDFIUM_PATH`), so
//! the test is `#[ignore]`d. One test, as PDFium binds once per process.
#![allow(clippy::panic, clippy::expect_used, clippy::unwrap_used)]

use std::path::PathBuf;
use std::sync::Arc;

use ferman_core::attach::NewAttachment;
use ferman_core::metadata::InfoEdit;
use ferman_core::outline::OutlineEdit;
use ferman_core::revision::RevisionStore;
use ferman_core::{OpenOptions, Source, open};
use pdfium_render::prelude::{PdfDocumentMetadataTagType, Pdfium};

fn corpus(name: &str) -> Vec<u8> {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"));
    std::fs::read(path).unwrap()
}

fn edit(item: Option<usize>, page: Option<usize>, title: &str, depth: u32) -> OutlineEdit {
    OutlineEdit {
        item,
        page,
        title: title.to_owned(),
        depth,
        open: true,
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn pdfium_reads_the_edited_outline_information_and_attachments() {
    let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
    let pdfium = Pdfium::new(Pdfium::bind_to_library(PathBuf::from(library)).unwrap());

    for name in ["combine-outline", "kira-tr"] {
        let original = corpus(name);
        let doc = open(
            &Source::from_bytes(Arc::from(original.clone())),
            &OpenOptions::default(),
        )
        .unwrap();
        let mut store = RevisionStore::new(&doc);
        let before: Vec<String> = store
            .outline(&doc)
            .iter()
            .map(|i| i.title.clone())
            .collect();
        let pages = store.pages(&doc).len();
        let attached = store.attachments(&doc).len();

        // A new chapter on the last page, the first item renamed and nested under it, the last
        // top-level item kept after it; everything else deleted.
        let mut items = vec![edit(None, Some(pages - 1), "Yeni bölüm", 0)];
        if !before.is_empty() {
            items.push(edit(Some(0), None, "Birinci kısım", 1));
        }
        store.begin().unwrap();
        store.set_outline(&doc, &items).unwrap();
        store
            .set_info(
                &doc,
                &InfoEdit {
                    title: "Kira sözleşmesi — İzmir".to_owned(),
                    author: "Ayşe Yılmaz".to_owned(),
                    subject: String::new(),
                    keywords: "kira, ğüşıöç".to_owned(),
                },
            )
            .unwrap();
        let data: Vec<u8> = (0..20_000u32).map(|n| (n * 7 % 251) as u8).collect();
        store
            .attach_file(
                &doc,
                NewAttachment {
                    name: "ek-ödeme.bin".to_owned(),
                    data: data.clone(),
                    media_type: None,
                    modified: None,
                },
            )
            .unwrap();
        store.commit().unwrap();
        let saved = store.incremental_update(&doc).unwrap();
        assert!(
            saved.starts_with(&original),
            "{name}: the original is a prefix"
        );

        let read = pdfium.load_pdf_from_byte_vec(saved, None).unwrap();
        let root = read.bookmarks().root().unwrap();
        assert_eq!(root.title().as_deref(), Some("Yeni bölüm"), "{name}");
        assert_eq!(
            usize::try_from(root.destination().unwrap().page_index().unwrap()).unwrap(),
            pages - 1
        );
        assert!(root.next_sibling().is_none(), "{name}");
        if before.is_empty() {
            assert!(root.first_child().is_none());
        } else {
            let child = root.first_child().unwrap();
            assert_eq!(child.title().as_deref(), Some("Birinci kısım"), "{name}");
            assert!(child.next_sibling().is_none());
        }

        let metadata = read.metadata();
        let tag = |kind| metadata.get(kind).map(|tag| tag.value().to_owned());
        assert_eq!(
            tag(PdfDocumentMetadataTagType::Title).as_deref(),
            Some("Kira sözleşmesi — İzmir")
        );
        assert_eq!(
            tag(PdfDocumentMetadataTagType::Author).as_deref(),
            Some("Ayşe Yılmaz")
        );
        assert_eq!(
            tag(PdfDocumentMetadataTagType::Keywords).as_deref(),
            Some("kira, ğüşıöç")
        );
        assert!(tag(PdfDocumentMetadataTagType::Subject).is_none_or(|s| s.is_empty()));

        let attachments = read.attachments();
        assert_eq!(usize::from(attachments.len()), attached + 1, "{name}");
        let ours = attachments
            .iter()
            .find(|attachment| attachment.name() == "ek-ödeme.bin")
            .unwrap();
        assert_eq!(ours.save_to_bytes().unwrap(), data, "{name}: byte for byte");
    }
}
