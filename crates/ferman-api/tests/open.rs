//! Opening the corpus through the facade (ROADMAP §6 step 2, ADR 0004, G102): every file opens,
//! or fails, with the kind its README row implies; lopdf and PDFium agree on the pages of every
//! file but `disagree-pages`, made for this check, whose second page lacks `/Type /Page` and which
//! therefore opens read-only; and a view gets its thumbnail.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;
use std::sync::{OnceLock, mpsc};
use std::time::Duration;

use ferman_api::facade::{
    Agreement, ApiError, Engine, EngineConfig, ErrorKind, Item, OpenedDocument, Password,
    PdfiumLibrary, Priority, ReadOnly, ThumbnailRequest, ViewEvent, ViewSink, Wanted, block_on,
};

/// One engine for the whole test binary: one render thread of a process may hold PDFium.
fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
        Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Path(library.into()),
        })
    })
}

fn path(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"))
}

fn open(name: &str, password: Option<&str>) -> Result<OpenedDocument, ApiError> {
    let password = password.map(|password| Password::new(password.to_owned()));
    block_on(engine().open(path(name), password))
}

/// Every corpus file that opens, with its password.
const FILES: [(&str, Option<&str>); 22] = [
    ("disagree-pages", None),
    ("form-aks1-flat", None),
    ("form-aks1-tr", None),
    ("js-openaction", None),
    ("kira-tr", None),
    ("kira-tr-damaged", None),
    ("kira-tr-restricted", None),
    ("letter-ja-vertical", None),
    ("long-500", None),
    ("imar-2400", None),
    ("mietvertrag-de", None),
    ("nda-en", None),
    ("ocg-plan", None),
    ("payslip-aes128", Some("bordro2026")),
    ("payslip-aes256", Some("Eylül2026maaşı")),
    ("payslip-rc4-128", Some("bordro2026")),
    ("payslip-rc4-40", Some("bordro2026")),
    ("quote-ja-scan", None),
    ("report-ar", None),
    ("scan-tr", None),
    ("tez-tr", None),
    ("xfa-visa", None),
];

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn the_corpus_opens_and_the_parsers_agree() {
    let mut checked = 0;
    for (name, password) in FILES {
        // Files over 1 MB are not committed; `tools/corpus generate` makes them.
        if !path(name).exists() {
            continue;
        }
        let document = open(name, password).unwrap_or_else(|err| panic!("{name}: {err}"));
        match name {
            "disagree-pages" => assert_eq!(
                document.read_only,
                Some(ReadOnly::ParsersDisagree(Agreement::PageCount {
                    model: 2,
                    renderer: 3
                }))
            ),
            "kira-tr-damaged" => assert!(
                matches!(document.read_only, Some(ReadOnly::Repaired(_))),
                "{:?}",
                document.read_only
            ),
            "xfa-visa" => assert_eq!(document.read_only, Some(ReadOnly::XfaOnly)),
            _ => assert_eq!(document.read_only, None, "{name}"),
        }
        assert!(!document.pages.is_empty(), "{name}");
        block_on(engine().close(document.id)).unwrap();
        checked += 1;
    }
    assert!(checked >= 20, "only {checked} corpus files were checked");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn pages_carry_their_labels() {
    let tez = open("tez-tr", None).unwrap();
    let labels: Vec<_> = tez.pages.iter().map(|page| page.label.as_deref()).collect();
    assert_eq!(
        (labels[0], labels[7], labels[8], labels[63]),
        (Some("i"), Some("viii"), Some("1"), Some("56"))
    );
    block_on(engine().close(tez.id)).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn files_that_do_not_open_say_why() {
    let kind = |name: &str, password: Option<&str>| open(name, password).unwrap_err().kind;
    assert_eq!(kind("truncated", None), ErrorKind::Damaged);
    assert_eq!(kind("payslip-aes256", None), ErrorKind::PasswordRequired);
    assert_eq!(
        kind("payslip-aes256", Some("eylul2026")),
        ErrorKind::WrongPassword
    );
    assert_eq!(kind("no-such-file", None), ErrorKind::NotFound);
}

/// A view's events, sent to this test's thread.
struct Sink(mpsc::Sender<ViewEvent>);

impl ViewSink for Sink {
    fn deliver(&mut self, event: ViewEvent) -> bool {
        self.0.send(event).is_ok()
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_view_gets_what_it_wants_and_ends_with_its_document() {
    let document = open("kira-tr", None).unwrap();
    let (events, received) = mpsc::channel();
    let view = block_on(engine().open_view(document.id, Box::new(Sink(events)))).unwrap();
    let thumbnail = Item::Thumbnail(ThumbnailRequest { page: 0, size: 128 });
    let wanted = vec![Wanted {
        item: thumbnail,
        priority: Priority::VisibleThumbnail,
    }];
    engine().request(view, 1, wanted).unwrap();
    match received.recv_timeout(Duration::from_secs(10)).unwrap() {
        ViewEvent::Rendered(rendered) => {
            assert_eq!(rendered.item, thumbnail);
            assert_eq!(rendered.generation, 1);
            assert_eq!(rendered.rect.height, 128);
        }
        ViewEvent::Failed(failed) => panic!("{failed:?}"),
    }
    block_on(engine().close(document.id)).unwrap();
    // Closing the document ended the view and dropped its sink.
    assert!(received.recv_timeout(Duration::from_secs(10)).is_err());
    let stale = block_on(engine().close(document.id)).unwrap_err();
    assert_eq!(stale.kind, ErrorKind::NotFound);
}
