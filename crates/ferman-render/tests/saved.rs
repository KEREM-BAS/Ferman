//! Files saved by ferman-core's incremental writer open in PDFium with every page (ROADMAP §7
//! step 3): each corpus file gets one splice on its first shown text, is written as an
//! incremental update and opened again by PDFium, encrypted files with their user password.
//!
//! Every test needs the PDFium library (`tools/pdfium/fetch.sh`, then an absolute
//! `FERMAN_PDFIUM_PATH`), so each is `#[ignore]`d. ferman-core's own round trip
//! (`revision::tests`) checks the bytes and writes the saved files into `FERMAN_SAVED_DIR` for
//! qpdf in CI.
#![allow(clippy::panic, clippy::expect_used, clippy::unwrap_used)]

use std::future::Future;
use std::path::PathBuf;
use std::sync::Arc;
use std::task::{Context, Poll, Wake, Waker};
use std::thread;
use std::time::Duration;

use ferman_core::interpret::{FontResource, OperatorEvent, Span, SpanSource, TextShow, TextSink};
use ferman_core::revision::{RevisionStore, Splice};
use ferman_core::{OpenOptions, Password, Source, open};
use ferman_render::{PdfiumStatus, RenderConfig, RenderThread};

struct Unpark(thread::Thread);

impl Wake for Unpark {
    fn wake(self: Arc<Self>) {
        self.0.unpark();
    }
}

/// Runs a future to completion on this thread, parked between polls.
fn block_on<F: Future>(future: F) -> F::Output {
    let waker = Waker::from(Arc::new(Unpark(thread::current())));
    let mut cx = Context::from_waker(&waker);
    let mut future = Box::pin(future);
    loop {
        if let Poll::Ready(output) = future.as_mut().poll(&mut cx) {
            return output;
        }
        thread::park_timeout(Duration::from_millis(50));
    }
}

/// The first show of a page stream: `Tj` or `TJ`, not split across streams.
#[derive(Default)]
struct FirstShow(Option<Span>);

impl TextSink for FirstShow {
    fn font(&mut self, _font: &FontResource) {}

    fn show(&mut self, _show: &TextShow<'_>) -> (f32, f32) {
        (0.0, 0.0)
    }

    fn operator(&mut self, operator: &OperatorEvent<'_>) {
        let span = operator.span;
        if self.0.is_none()
            && matches!(operator.name, b"Tj" | b"TJ")
            && !span.carried
            && matches!(span.source, SpanSource::Page { .. })
        {
            self.0 = Some(span.clone());
        }
    }
}

fn password(name: &str) -> Option<&'static str> {
    match name {
        "payslip-aes256" => Some("Eylül2026maaşı"),
        _ if name.starts_with("payslip-") => Some("bordro2026"),
        _ => None,
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn saved_corpus_files_open_in_pdfium_with_every_page() {
    let path = std::env::var_os("FERMAN_PDFIUM_PATH")
        .filter(|value| !value.is_empty())
        .expect("FERMAN_PDFIUM_PATH must name the PDFium library (tools/pdfium/fetch.sh)");
    let render = RenderThread::start(RenderConfig {
        pdfium_library: Some(PathBuf::from(path)),
        ..RenderConfig::default()
    })
    .unwrap();
    assert!(matches!(
        block_on(render.status()).unwrap(),
        PdfiumStatus::Loaded { .. }
    ));
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/corpus/generated");
    let mut files: Vec<PathBuf> = std::fs::read_dir(&dir)
        .unwrap()
        .map(|entry| entry.unwrap().path())
        .filter(|path| path.extension().is_some_and(|ext| ext == "pdf"))
        .collect();
    files.sort();
    let mut saved = 0;
    for path in files {
        let name = path.file_stem().unwrap().to_string_lossy().into_owned();
        let options = OpenOptions {
            password: password(&name).map(|password| Password::new(password.to_owned())),
            ..OpenOptions::default()
        };
        let Ok(doc) = open(&Source::read(&path).unwrap(), &options) else {
            continue;
        };
        if doc.repair().is_some() {
            continue;
        }
        let Some((page, span)) = (0..doc.page_count()).find_map(|page| {
            let mut sink = FirstShow::default();
            doc.page_text(page, &mut sink).unwrap();
            sink.0.map(|span| (page, span))
        }) else {
            continue;
        };
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        let splice = Splice {
            source: span.source,
            range: span.range,
            bytes: b"(Ferman) Tj".to_vec(),
        };
        store.splice(&doc, page, &[splice], &[]).unwrap();
        store.commit().unwrap();
        let bytes = store.incremental_update(&doc).unwrap();
        // As many pages as PDFium finds in the original (disagree-pages has one lopdf does not).
        let pages = |bytes: Arc<[u8]>| {
            let password = password(&name).map(|password| Password::new(password.to_owned()));
            let opened = block_on(render.open_document(bytes, password))
                .unwrap_or_else(|err| panic!("{name}: {err}"));
            block_on(render.close_document(opened.id)).unwrap();
            opened.pages.len()
        };
        assert_eq!(
            pages(Arc::from(bytes)),
            pages(doc.source().bytes().clone()),
            "{name}"
        );
        saved += 1;
    }
    assert!(saved > 30, "{saved} files saved");
}
