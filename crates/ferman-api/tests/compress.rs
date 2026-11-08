//! M4 W4's acceptance through the facade, with PDFium: Compress on the corpus's image file and
//! long-500, Optimize and clean as a job, version history, Save as's options and printing.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::sync::mpsc;
use std::time::Duration;

use ferman_api::facade::{
    DocumentId, Engine, EngineConfig, ErrorKind, JobEvent, JobResult, JobSink, LOW_PRINT_DPI,
    OpenedDocument, PRINT_DPI, PdfiumLibrary, Preset, PrintPage, PrintSink, SaveOptions,
    VersionKind, block_on,
};

fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
        Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Path(library.into()),
        })
    })
}

fn pdf(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"))
}

fn folder(test: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("ferman-w4-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

/// A copy of corpus file `name` in `dir`, opened.
fn open_copy(dir: &Path, name: &str) -> (PathBuf, OpenedDocument) {
    let path = dir.join(format!("{name}.pdf"));
    std::fs::copy(pdf(name), &path).unwrap();
    let opened = block_on(engine().open(path.clone(), None)).unwrap();
    (path, opened)
}

struct Events(mpsc::Sender<JobEvent>, bool);

impl JobSink for Events {
    fn deliver(&mut self, event: JobEvent) {
        // Cancels at the first progress when asked to.
        if self.1 && event.progress.is_some() {
            engine().cancel_job(event.job);
        }
        let _ = self.0.send(event);
    }
}

/// Waits for the job's last event.
fn last(events: &mpsc::Receiver<JobEvent>) -> JobEvent {
    loop {
        let event = events.recv_timeout(Duration::from_secs(600)).unwrap();
        if event.result.is_some() {
            return event;
        }
    }
}

fn fact(event: &JobEvent, key: &str) -> String {
    event
        .params
        .iter()
        .find(|(name, _)| name == key)
        .map(|(_, value)| value.clone())
        .unwrap()
}

fn compress(document: DocumentId, preset: Preset, output: &Path, cancel: bool) -> JobEvent {
    let (sender, events) = mpsc::channel();
    engine()
        .compress_job(
            document,
            preset,
            false,
            output.to_path_buf(),
            None,
            Box::new(Events(sender, cancel)),
        )
        .unwrap();
    last(&events)
}

/// The mean absolute difference of two rasters' samples, 0 to 255.
fn mean_difference(a: &[u8], b: &[u8]) -> f64 {
    assert_eq!(a.len(), b.len());
    let sum: u64 = a
        .iter()
        .zip(b)
        .map(|(x, y)| u64::from(x.abs_diff(*y)))
        .sum();
    sum as f64 / a.len() as f64
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn compress_estimates_within_15_percent_renders_alike_and_leaves_the_original() {
    let dir = folder("compress");
    for name in ["images-compress", "long-500"] {
        // long-500 is generated, not committed: only the bench job has it.
        if !pdf(name).exists() {
            continue;
        }
        let (path, doc) = open_copy(&dir, name);
        let original = std::fs::read(&path).unwrap();
        let analysis = block_on(engine().compress_analysis(doc.id)).unwrap();
        assert_eq!(analysis.before, original.len() as u64);
        assert!(!analysis.signed);
        if name == "images-compress" {
            assert!(analysis.images > 0);
            assert!(analysis.unreadable > 0 && analysis.masks > 0 && analysis.patterns > 0);
        }
        for (preset, estimate) in &analysis.estimates {
            let output = dir.join(format!("{name}-{preset:?}.pdf"));
            let event = compress(doc.id, *preset, &output, false);
            let JobResult::Done { outputs, .. } = event.result.clone().unwrap() else {
                panic!("{name} {preset:?}: {:?}", event.result);
            };
            let after: u64 = fact(&event, "after").parse().unwrap();
            let written = fact(&event, "written") == "true";
            assert_eq!(written, after < analysis.before, "{name} {preset:?}");
            assert_eq!(output.exists(), written, "a larger result writes nothing");
            assert_eq!(outputs.len(), usize::from(written));
            let error = (estimate.after as f64 - after as f64).abs() / after as f64;
            assert!(
                error <= 0.15,
                "{name} {preset:?}: estimated {} for {after}",
                estimate.after
            );
            if !written {
                continue;
            }
            // The output opens and renders like the input within the preset's quality.
            let compressed = block_on(engine().open(output.clone(), None)).unwrap();
            assert_eq!(compressed.pages.len(), doc.pages.len());
            for index in [0, doc.pages.len() - 1] {
                let page = u32::try_from(index).unwrap();
                let size = doc.pages[index].size;
                let before = block_on(engine().render_page(doc.id, page, size, 72)).unwrap();
                let after = block_on(engine().render_page(compressed.id, page, size, 72)).unwrap();
                let mean = mean_difference(&before.pixels, &after.pixels);
                assert!(mean < 6.0, "{name} {preset:?} page {page}: {mean}");
            }
            block_on(engine().close(compressed.id)).unwrap();
        }
        assert_eq!(
            std::fs::read(&path).unwrap(),
            original,
            "the original is not touched"
        );
        block_on(engine().close(doc.id)).unwrap();
    }
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_cancelled_compress_leaves_no_file_and_a_signed_one_asks_first() {
    let dir = folder("compress-cancel");
    let (_, doc) = open_copy(&dir, "images-compress");
    let output = dir.join("no.pdf");
    let event = compress(doc.id, Preset::Smallest, &output, true);
    assert_eq!(event.result, Some(JobResult::Cancelled));
    assert!(!output.exists());
    block_on(engine().close(doc.id)).unwrap();

    let (path, signed) = open_copy(&dir, "kira-tr-signed");
    let (sender, _events) = mpsc::channel();
    let err = engine()
        .compress_job(
            signed.id,
            Preset::Balanced,
            false,
            output.clone(),
            None,
            Box::new(Events(sender, false)),
        )
        .unwrap_err();
    assert_eq!(err.kind, ErrorKind::ConfirmationRequired);
    let (sender, events) = mpsc::channel();
    engine()
        .compress_job(
            signed.id,
            Preset::Balanced,
            true,
            output.clone(),
            None,
            Box::new(Events(sender, false)),
        )
        .unwrap();
    let event = last(&events);
    assert!(matches!(event.result, Some(JobResult::Done { .. })));
    if output.exists() {
        let copy = block_on(engine().open(output.clone(), None)).unwrap();
        assert!(!copy.signed, "the copy has no signatures");
        block_on(engine().close(copy.id)).unwrap();
    }
    assert_eq!(
        std::fs::read(&path).unwrap(),
        std::fs::read(pdf("kira-tr-signed")).unwrap()
    );
    block_on(engine().close(signed.id)).unwrap();
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn versions_are_written_listed_previewed_restored_and_optimize_runs_as_a_job() {
    let dir = folder("versions");
    engine().start_versions(dir.join("Versions"));
    let (path, doc) = open_copy(&dir, "kira-tr");
    let original = std::fs::read(&path).unwrap();
    assert!(block_on(engine().versions(doc.id)).unwrap().is_empty());

    block_on(engine().rotate_page(doc.id, 0, 1, "Rotate page 1".to_owned())).unwrap();
    block_on(engine().save(doc.id, None)).unwrap();
    let saved = std::fs::read(&path).unwrap();
    let list = block_on(engine().versions(doc.id)).unwrap();
    let kinds: Vec<VersionKind> = list.iter().map(|version| version.kind).collect();
    assert_eq!(kinds, [VersionKind::Saved, VersionKind::Opened]);
    assert_eq!(list[0].edits, 1);
    assert_eq!(list[0].names, ["Rotate page 1"]);
    assert_eq!(list[1].size, original.len() as u64);

    // The preview opens from the version's bytes, read-only.
    let preview = block_on(engine().open_version(doc.id, list[1].id, None)).unwrap();
    assert_eq!(preview.pages.len(), doc.pages.len());
    assert_ne!(preview.pages[0].rotation, 90);
    block_on(engine().close(preview.id)).unwrap();

    // Unsaved work becomes a version, then the restore replaces the file whole.
    block_on(engine().rotate_page(doc.id, 1, 1, "Rotate page 2".to_owned())).unwrap();
    assert_eq!(
        block_on(engine().restore_version(doc.id, list[1].id, None)).unwrap(),
        None
    );
    assert_eq!(std::fs::read(&path).unwrap(), original);
    let kinds: Vec<VersionKind> = block_on(engine().versions(doc.id))
        .unwrap()
        .iter()
        .map(|version| version.kind)
        .collect();
    assert_eq!(
        kinds,
        [
            VersionKind::Restored,
            VersionKind::Unsaved,
            VersionKind::Saved,
            VersionKind::Opened
        ]
    );
    block_on(engine().close(doc.id)).unwrap();

    // Reopened, as the app does, Optimize and clean rewrites the file in a job.
    let doc = block_on(engine().open(path.clone(), None)).unwrap();
    let (sender, events) = mpsc::channel();
    engine()
        .optimize_and_clean_job(doc.id, None, Box::new(Events(sender, false)))
        .unwrap();
    let JobResult::Done { outputs, .. } = last(&events).result.unwrap() else {
        panic!("Optimize and clean failed");
    };
    assert_eq!(outputs.len(), 1);
    assert_eq!(outputs[0].path, path);
    let cleaned = std::fs::read(&path).unwrap();
    assert!(cleaned.windows(7).any(|window| window == b"/ObjStm"));
    assert_ne!(cleaned, saved);
    assert_eq!(
        block_on(engine().versions(doc.id)).unwrap()[0].kind,
        VersionKind::Saved
    );
    block_on(engine().close(doc.id)).unwrap();
    let again = block_on(engine().open(path, None)).unwrap();
    assert_eq!(again.pages.len(), doc.pages.len());
    block_on(engine().close(again.id)).unwrap();
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn remove_edit_history_leaves_no_earlier_revision_and_comments_can_stay_out() {
    let dir = folder("save-options");
    // A committed file: CI's Rust jobs have no long-500.
    let (path, doc) = open_copy(&dir, "tez-tr");
    let pages: Vec<u64> = doc.pages[..10].iter().map(|page| page.handle).collect();
    block_on(engine().delete_pages(doc.id, pages, "Delete pages".to_owned())).unwrap();
    let clean = dir.join("clean.pdf");
    let options = SaveOptions {
        include_comments: true,
        remove_history: true,
    };
    block_on(engine().save_as(doc.id, clean.clone(), options, None)).unwrap();
    let bytes = std::fs::read(&clean).unwrap();
    let original = std::fs::read(&path).unwrap();
    assert_eq!(bytes.windows(5).filter(|w| w == b"%%EOF").count(), 1);
    assert!(!bytes.windows(5).any(|window| window == b"/Prev"));
    assert!(bytes.len() < original.len());
    let reopened = block_on(engine().open(clean.clone(), None)).unwrap();
    assert_eq!(reopened.pages.len(), 54);
    block_on(engine().close(reopened.id)).unwrap();
    // The document moved to the clean file, which later saves rewrite.
    block_on(engine().rotate_page(doc.id, 0, 1, "Rotate".to_owned())).unwrap();
    block_on(engine().save(doc.id, None)).unwrap();
    let bytes = std::fs::read(&clean).unwrap();
    assert_eq!(bytes.windows(5).filter(|w| w == b"%%EOF").count(), 1);
    block_on(engine().close(doc.id)).unwrap();

    let (path, doc) = open_copy(&dir, "annots-other-producer");
    let markup = |id| {
        block_on(engine().annotations(id))
            .unwrap()
            .annotations
            .iter()
            .filter(|annotation| {
                // A private subtype is no markup and stays.
                [
                    "Text",
                    "FreeText",
                    "Line",
                    "Square",
                    "Circle",
                    "Polygon",
                    "PolyLine",
                    "Highlight",
                    "Underline",
                    "Squiggly",
                    "StrikeOut",
                    "Stamp",
                    "Caret",
                    "Ink",
                ]
                .contains(&annotation.subtype.as_str())
            })
            .count()
    };
    assert!(markup(doc.id) > 0);
    let without = dir.join("without.pdf");
    let options = SaveOptions {
        include_comments: false,
        remove_history: false,
    };
    block_on(engine().save_as(doc.id, without.clone(), options, None)).unwrap();
    let copy = block_on(engine().open(without, None)).unwrap();
    assert_eq!(markup(copy.id), 0);
    block_on(engine().close(copy.id)).unwrap();
    // Without comments the document keeps its own file and its comments.
    assert!(markup(doc.id) > 0);
    assert_eq!(
        std::fs::read(&path).unwrap(),
        std::fs::read(pdf("annots-other-producer")).unwrap()
    );
    block_on(engine().close(doc.id)).unwrap();
    let _ = std::fs::remove_dir_all(dir);
}

struct Pages(mpsc::Sender<PrintPage>);

impl PrintSink for Pages {
    fn deliver(&mut self, page: PrintPage) -> bool {
        self.0.send(page).is_ok()
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn printing_streams_pages_and_follows_the_print_permission() {
    let doc = block_on(engine().open(
        pdf("payslip-aes256"),
        Some(ferman_api::facade::Password::new(
            "Eylül2026maaşı".to_owned(),
        )),
    ))
    .unwrap();
    let (sender, pages) = mpsc::channel();
    block_on(engine().print_pages(doc.id, Vec::new(), true, Box::new(Pages(sender)))).unwrap();
    let printed: Vec<PrintPage> = pages.try_iter().collect();
    assert_eq!(printed.len(), doc.pages.len());
    for (index, page) in printed.iter().enumerate() {
        assert_eq!(page.index as usize, index);
        assert_eq!(page.dpi, PRINT_DPI);
        let width = (f64::from(page.size.width) * f64::from(PRINT_DPI) / 72.0).ceil();
        assert!((f64::from(page.width) - width).abs() <= 1.0);
        assert_eq!(
            page.pixels.len(),
            page.width as usize * page.height as usize * 4
        );
        assert!(
            page.pixels.iter().any(|&sample| sample < 128),
            "something is drawn"
        );
    }
    block_on(engine().close(doc.id)).unwrap();

    // One page by its handle; a closed sink ends the print.
    let kira = block_on(engine().open(pdf("kira-tr"), None)).unwrap();
    let (sender, pages) = mpsc::channel();
    let handle = kira.pages[1].handle;
    block_on(engine().print_pages(kira.id, vec![handle], false, Box::new(Pages(sender)))).unwrap();
    let printed: Vec<PrintPage> = pages.try_iter().collect();
    assert_eq!(
        printed.iter().map(|page| page.index).collect::<Vec<_>>(),
        [1]
    );
    let (sender, pages) = mpsc::channel();
    drop(pages);
    block_on(engine().print_pages(kira.id, Vec::new(), true, Box::new(Pages(sender)))).unwrap();
    block_on(engine().close(kira.id)).unwrap();

    // Printing forbidden: refused until the owner password lifts it.
    let locked = block_on(engine().open(pdf("kira-tr-no-print"), None)).unwrap();
    let (sender, pages) = mpsc::channel();
    let refused =
        block_on(engine().print_pages(locked.id, Vec::new(), true, Box::new(Pages(sender))));
    assert_eq!(refused.unwrap_err().kind, ErrorKind::NotEditable);
    assert_eq!(pages.try_iter().count(), 0);
    block_on(engine().unlock_owner(
        locked.id,
        ferman_api::facade::Password::new("Kaya-Moda-18".to_owned()),
    ))
    .unwrap();
    let (sender, pages) = mpsc::channel();
    let handle = locked.pages[0].handle;
    block_on(engine().print_pages(locked.id, vec![handle], true, Box::new(Pages(sender)))).unwrap();
    assert_eq!(pages.try_iter().next().unwrap().dpi, PRINT_DPI);
    block_on(engine().close(locked.id)).unwrap();

    // Low quality only: pages come at LOW_PRINT_DPI.
    let low = block_on(engine().open(pdf("kira-tr-low-print"), None)).unwrap();
    let (sender, pages) = mpsc::channel();
    let handle = low.pages[0].handle;
    block_on(engine().print_pages(low.id, vec![handle], true, Box::new(Pages(sender)))).unwrap();
    let page = pages.try_iter().next().unwrap();
    assert_eq!(page.dpi, LOW_PRINT_DPI);
    let width = (f64::from(page.size.width) * f64::from(LOW_PRINT_DPI) / 72.0).ceil();
    assert!((f64::from(page.width) - width).abs() <= 1.0);
    block_on(engine().close(low.id)).unwrap();
}
