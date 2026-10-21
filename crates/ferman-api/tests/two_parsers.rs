//! The two-parser check (ADR 0004, G102): lopdf's model and PDFium agree on the page count and
//! page sizes of every corpus file, except `disagree-pages`, made for this check, whose second
//! page lacks `/Type /Page`. A document whose parsers disagree opens read-only (the API commit
//! acts on it; this test holds the comparison to the corpus).
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::future::Future;
use std::path::PathBuf;
use std::sync::Arc;
use std::task::{Context, Poll, Wake, Waker};
use std::thread;
use std::time::Duration;

use ferman_core::structure::Agreement;
use ferman_core::{OpenOptions, Password, Source, open};
use ferman_render::{PdfiumStatus, RenderConfig, RenderThread};

struct Unpark(thread::Thread);

impl Wake for Unpark {
    fn wake(self: Arc<Self>) {
        self.0.unpark();
    }
}

/// Runs a future to completion on this thread. `Box::pin`, not `pin!`: ferman-api's code avoids
/// `super let` (.claude/rules/rust.md).
fn block_on<F: Future>(future: F) -> F::Output {
    let waker = Waker::from(Arc::new(Unpark(thread::current())));
    let mut cx = Context::from_waker(&waker);
    let mut future = Box::pin(future);
    loop {
        if let Poll::Ready(output) = future.as_mut().poll(&mut cx) {
            return output;
        }
        thread::park_timeout(Duration::from_millis(20));
    }
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
fn lopdf_and_pdfium_agree_on_the_corpus() {
    let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
    let render = RenderThread::start(RenderConfig {
        pdfium_library: Some(PathBuf::from(library)),
        ..RenderConfig::default()
    })
    .unwrap();
    assert!(matches!(
        block_on(render.status()).unwrap(),
        PdfiumStatus::Loaded { .. }
    ));
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/corpus/generated");
    let mut checked = 0;
    for (name, password) in FILES {
        let path = dir.join(format!("{name}.pdf"));
        // Files over 1 MB are not committed; `tools/corpus generate` makes them.
        if !path.exists() {
            continue;
        }
        let source = Source::read(&path).unwrap();
        let options = OpenOptions {
            password: password.map(|password| Password::new(password.to_owned())),
            ..OpenOptions::default()
        };
        let model = open(&source, &options).unwrap_or_else(|err| panic!("{name}: {err}"));
        let rendered = block_on(render.open_document(
            Arc::clone(source.bytes()),
            password.map(|password| Password::new(password.to_owned())),
        ))
        .unwrap_or_else(|err| panic!("{name}: {err}"));
        let sizes: Vec<(f32, f32)> = rendered
            .pages
            .iter()
            .map(|page| (page.width, page.height))
            .collect();
        let agreement = model.structure().agrees_with(&sizes);
        if name == "disagree-pages" {
            assert_eq!(
                agreement,
                Agreement::PageCount {
                    model: 2,
                    renderer: 3
                }
            );
        } else {
            assert_eq!(agreement, Agreement::Agree, "{name}");
        }
        block_on(render.close_document(rendered.id)).unwrap();
        checked += 1;
    }
    assert!(checked >= 20, "only {checked} corpus files were checked");
}
