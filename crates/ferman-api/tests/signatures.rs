//! Simple signatures and Fill anything through the facade (M4 plan, W3, decisions 20 to 23): a
//! typed, a drawn and an image signature placed on `form-aks1-tr`, saved, reopened and rendered.
//! Pixels change only inside each one's box; the file never reads as signed; the required count
//! reads the stamp on `imza` as filled after reopening. Fill anything finds the lines, boxes and
//! comb of `form-aks1-flat`, and an image past the pixel limit is refused. A hostile page's walk is
//! ferman-ops' unit test (`fill`).
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use ferman_api::facade::{
    AnnotationChange, AnnotationKind, DocumentId, Engine, EngineConfig, ErrorKind, FontSettings,
    Ink, NewAnnotation, NewSignature, OpenedDocument, PageInfo, PageRaster, PdfiumLibrary,
    TargetKind, block_on, compare, device_region,
};

const DPI: u32 = 110;
const FORM: &str = "form-aks1-tr";

fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
        let engine = Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Path(library.into()),
        });
        block_on(engine.set_font_settings(FontSettings {
            bundled_dir: Some(
                PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../app/assets/fonts"),
            ),
            ..FontSettings::default()
        }))
        .unwrap();
        engine
    })
}

fn corpus(name: &str, extension: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.{extension}"))
}

fn copy(test: &str, name: &str) -> (PathBuf, PathBuf) {
    let dir = std::env::temp_dir().join(format!("ferman-signatures-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!("{name}.pdf"));
    std::fs::copy(corpus(name, "pdf"), &path).unwrap();
    (dir, path)
}

fn open(path: &Path) -> OpenedDocument {
    block_on(engine().open(path.to_path_buf(), None)).unwrap()
}

fn draw(doc: DocumentId, pages: &[PageInfo]) -> PageRaster {
    block_on(engine().render_page(doc, 0, pages[0].size, DPI)).unwrap()
}

/// A CRC-32 of PNG chunks (ISO 3309), bit by bit.
fn crc32(bytes: &[u8]) -> u32 {
    let mut crc = u32::MAX;
    for byte in bytes {
        crc ^= u32::from(*byte);
        for _ in 0..8 {
            crc = if crc & 1 == 1 {
                (crc >> 1) ^ 0xEDB8_8320
            } else {
                crc >> 1
            };
        }
    }
    !crc
}

/// A grey PNG of `width` × `height` with stored (uncompressed) deflate blocks, from `pixel`.
fn png(width: u32, height: u32, pixel: impl Fn(u32, u32) -> u8) -> Vec<u8> {
    let mut raw = Vec::new();
    for y in 0..height {
        raw.push(0);
        raw.extend((0..width).map(|x| pixel(x, y)));
    }
    let mut zlib = vec![0x78, 0x01];
    let chunks: Vec<&[u8]> = raw.chunks(65_535).collect();
    for (at, block) in chunks.iter().enumerate() {
        zlib.push(u8::from(at + 1 == chunks.len()));
        let length = u16::try_from(block.len()).unwrap();
        zlib.extend(length.to_le_bytes());
        zlib.extend((!length).to_le_bytes());
        zlib.extend(*block);
    }
    let (mut a, mut b) = (1u32, 0u32);
    for byte in &raw {
        a = (a + u32::from(*byte)) % 65_521;
        b = (b + a) % 65_521;
    }
    zlib.extend(((b << 16) | a).to_be_bytes());
    let mut out = b"\x89PNG\r\n\x1a\n".to_vec();
    let mut chunk = |kind: &[u8], data: &[u8]| {
        out.extend(u32::try_from(data.len()).unwrap().to_be_bytes());
        let mut body = kind.to_vec();
        body.extend(data);
        out.extend(&body);
        out.extend(crc32(&body).to_be_bytes());
    };
    let mut header = width.to_be_bytes().to_vec();
    header.extend(height.to_be_bytes());
    header.extend([8, 0, 0, 0, 0]);
    chunk(b"IHDR", &header);
    chunk(b"IDAT", &zlib);
    chunk(b"IEND", &[]);
    out
}

fn signature(rect: [f32; 4], ink: Ink, field: Option<&str>, tilt: f32) -> NewSignature {
    NewSignature {
        rect,
        ink,
        color: [0.1, 0.1, 0.45],
        tilt,
        initials: false,
        field: field.map(str::to_owned),
        author: "Ayşe Yılmaz".to_owned(),
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn typed_drawn_and_image_signatures_are_placed_saved_and_reopened() {
    let (dir, path) = copy("place", FORM);
    let original = std::fs::read(&path).unwrap();
    let opened = open(&path);
    let doc = opened.id;
    let page = opened.pages[0].handle;
    assert!(!opened.signed);
    let form = block_on(engine().form_fields(doc)).unwrap();
    assert_eq!((form.required, form.required_left), (15, 15));
    let field = form.fields.iter().find(|f| f.name == "imza").unwrap();
    let field_box = field.widgets[0].rect;

    let ink = png(120, 40, |x, y| {
        if (18..22).contains(&y) && (10..110).contains(&x) || (x == 60 && y > 5) {
            30
        } else {
            245
        }
    });
    let cases = [
        (
            "typed",
            signature(
                field_box,
                Ink::Typed {
                    text: "Ayşe Yılmaz".to_owned(),
                    family: "Caveat".to_owned(),
                },
                Some("imza"),
                0.0,
            ),
        ),
        (
            "drawn",
            signature(
                [60.0, 40.0, 220.0, 80.0],
                Ink::Drawn {
                    strokes: vec![
                        vec![[0.0, 30.0], [20.0, 0.0], [40.0, 30.0], [60.0, 10.0]],
                        vec![[70.0, 20.0]],
                    ],
                    width: 3.0,
                },
                None,
                -2.0,
            ),
        ),
        (
            "image",
            signature([300.0, 40.0, 450.0, 90.0], Ink::Image(ink), None, 0.0),
        ),
    ];
    for (name, new) in cases {
        let before = draw(doc, &opened.pages);
        let commit =
            block_on(engine().add_signature(doc, page, new, format!("Sign {name}"))).unwrap();
        assert_eq!(commit.revision.changed_pages, Some(vec![0]), "{name}");
        let placed = block_on(engine().annotations(doc))
            .unwrap()
            .annotations
            .into_iter()
            .find(|a| a.handle == commit.handle)
            .unwrap();
        assert_eq!(placed.icon.as_deref(), Some("FermanSignature"), "{name}");
        let after = draw(doc, &opened.pages);
        let region = device_region(&[placed.rect], f64::from(DPI) / 72.0).unwrap();
        let diff = compare(&before, &after, Some(region), 2).unwrap();
        assert!(diff.passed(), "{name}: {diff:?} outside {:?}", placed.rect);
        assert!(diff.differing > 0, "{name}: nothing was drawn");
    }
    let form = block_on(engine().form_fields(doc)).unwrap();
    assert_eq!(form.required_left, 14);
    let shown = draw(doc, &opened.pages);
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();

    let saved = std::fs::read(&path).unwrap();
    assert_eq!(saved[..original.len()], original[..]);
    let again = open(&path);
    assert!(!again.signed, "a simple signature is no digital one");
    assert!(again.signatures.iter().all(|s| !s.signed));
    let form = block_on(engine().form_fields(again.id)).unwrap();
    assert_eq!(form.required_left, 14);
    let imza = form.fields.iter().find(|f| f.name == "imza").unwrap();
    assert!(imza.signature.is_some() && !imza.signed && imza.filled);
    let diff = compare(&shown, &draw(again.id, &again.pages), None, 0).unwrap();
    assert_eq!(diff.differing, 0, "reopens as it showed: {diff:?}");
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn refusals_write_nothing() {
    let (dir, path) = copy("refused", FORM);
    let opened = open(&path);
    let doc = opened.id;
    let page = opened.pages[0].handle;
    let rect = [300.0, 40.0, 450.0, 90.0];

    // A JPEG whose header claims 65535 × 65535 stops at the pixel limit.
    let mut bomb = std::fs::read(corpus("combine-photo", "jpg")).unwrap();
    let sof = bomb
        .windows(2)
        .position(|pair| pair == [0xFF, 0xC0])
        .unwrap();
    bomb[sof + 5..sof + 9].copy_from_slice(&[255, 255, 255, 255]);
    let refused = block_on(engine().add_signature(
        doc,
        page,
        signature(rect, Ink::Image(bomb), None, 0.0),
        "Sign".to_owned(),
    ))
    .unwrap_err();
    assert_eq!(refused.kind, ErrorKind::ResourceLimit);

    // A blank page has no ink; Homemade Apple has no ş (G158); a text field takes no signature.
    let blank = png(20, 20, |_, _| 255);
    let typed = |family: &str| Ink::Typed {
        text: "Ayşe".to_owned(),
        family: family.to_owned(),
    };
    for (new, kind) in [
        (
            signature(rect, Ink::Image(blank), None, 0.0),
            ErrorKind::Unsupported,
        ),
        (
            signature(rect, typed("Homemade Apple"), None, 0.0),
            ErrorKind::Unsupported,
        ),
        (
            signature(rect, typed("Caveat"), Some("adi"), 0.0),
            ErrorKind::InvalidInput,
        ),
    ] {
        let refused =
            block_on(engine().add_signature(doc, page, new, "Sign".to_owned())).unwrap_err();
        assert_eq!(refused.kind, kind);
    }
    assert!(block_on(engine().history(doc)).unwrap().steps.is_empty());
    let styles = block_on(engine().handwriting_styles("Ayşe".to_owned())).unwrap();
    assert_eq!(
        styles,
        [
            ("Caveat".to_owned(), true),
            ("Dancing Script".to_owned(), true),
            ("Homemade Apple".to_owned(), false)
        ]
    );
    block_on(engine().close(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn fill_anything_finds_the_flat_forms_places() {
    let opened = open(&corpus("form-aks1-flat", "pdf"));
    let found = block_on(engine().fill_targets(opened.id, opened.pages[0].handle)).unwrap();
    assert!(!found.truncated);
    let of = |kind| found.targets.iter().filter(|t| t.kind == kind).count();
    assert_eq!(of(TargetKind::Comb), 1);
    assert_eq!(of(TargetKind::Line), 3);
    assert_eq!(of(TargetKind::Check), 2);
    assert_eq!(of(TargetKind::Box), 14);
    let comb = found
        .targets
        .iter()
        .find(|t| t.kind == TargetKind::Comb)
        .unwrap();
    assert_eq!(comb.cells, 11);
    // Displayed points: top above bottom.
    assert!(comb.rect[1] < comb.rect[3]);
    assert!(block_on(engine().fill_targets(opened.id, u64::MAX)).is_err());
    block_on(engine().close(opened.id)).unwrap();

    // The comb takes W2's text box, one digit a cell, and keeps its cells through an edit.
    let (dir, path) = copy("comb", "form-aks1-flat");
    let opened = open(&path);
    let doc = opened.id;
    let before = draw(doc, &opened.pages);
    let digits = |text: &str| NewAnnotation {
        kind: AnnotationKind::FreeText,
        rect: comb.rect,
        points: Vec::new(),
        color: [0.0, 0.0, 0.0],
        stroke: 0.0,
        opacity: 1.0,
        contents: text.to_owned(),
        author: String::new(),
        font_size: 10.0,
        arrow: false,
        label: String::new(),
        meta: None,
        tilt: 0.0,
        icon: None,
        comb: Some(comb.cells),
    };
    let commit = block_on(engine().add_annotation(
        doc,
        opened.pages[0].handle,
        digits("10000000146"),
        "Fill".to_owned(),
    ))
    .unwrap();
    let after = draw(doc, &opened.pages);
    let region = device_region(&[comb.rect], f64::from(DPI) / 72.0).unwrap();
    let diff = compare(&before, &after, Some(region), 2).unwrap();
    assert!(diff.passed() && diff.differing > 0, "{diff:?}");
    block_on(engine().update_annotation(
        doc,
        commit.handle,
        AnnotationChange {
            contents: Some("2".to_owned()),
            ..AnnotationChange::default()
        },
        "Fill".to_owned(),
    ))
    .unwrap();
    let edited = draw(doc, &opened.pages);
    let diff = compare(&before, &edited, Some(region), 2).unwrap();
    assert!(diff.passed() && diff.differing > 0, "{diff:?}");
    assert!(compare(&after, &edited, None, 0).unwrap().differing > 0);
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();

    // The edit kept the comb: "2" sits in the first cell, as a new comb box of "2" draws it.
    let fresh = open(&corpus("form-aks1-flat", "pdf"));
    block_on(engine().add_annotation(
        fresh.id,
        fresh.pages[0].handle,
        digits("2"),
        "Fill".to_owned(),
    ))
    .unwrap();
    let diff = compare(&draw(fresh.id, &fresh.pages), &edited, None, 0).unwrap();
    assert_eq!(diff.differing, 0, "the comb after the edit: {diff:?}");
    block_on(engine().close_discarding(fresh.id)).unwrap();

    // Saved as an annotation, it survives reopening and draws the same.
    let again = open(&path);
    let list = block_on(engine().annotations(again.id)).unwrap();
    let text = list
        .annotations
        .iter()
        .find(|a| a.kind == AnnotationKind::FreeText)
        .unwrap();
    assert_eq!(text.contents.as_deref(), Some("2"));
    let diff = compare(&edited, &draw(again.id, &again.pages), None, 0).unwrap();
    assert_eq!(diff.differing, 0, "reopened: {diff:?}");
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}
