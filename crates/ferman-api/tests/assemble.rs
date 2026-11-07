//! The assembler through the facade (M4 plan, W1, ROADMAP §8's acceptance): Combine, Split, Extract,
//! Insert and Replace, as jobs, with what each page draws compared to its source.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::sync::mpsc;
use std::time::Duration;

use ferman_api::facade::{
    ApiError, CombineFile, CombineSource, DocumentId, Engine, EngineConfig, ErrorKind, InputStatus,
    JOB_STALE, JobEvent, JobId, JobOutput, JobResult, JobSink, OpenedDocument, OutlineItem, Paper,
    PdfiumLibrary, SplitMode, SplitOutput, block_on, compare,
};

const DPI: u32 = 72;

fn engine() -> &'static Engine {
    static ENGINE: OnceLock<Engine> = OnceLock::new();
    ENGINE.get_or_init(|| {
        let library = std::env::var_os("FERMAN_PDFIUM_PATH").expect("FERMAN_PDFIUM_PATH");
        Engine::start(EngineConfig {
            pdfium: PdfiumLibrary::Path(library.into()),
        })
    })
}

fn corpus(file: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(file)
}

fn pdf(name: &str) -> PathBuf {
    corpus(&format!("{name}.pdf"))
}

/// A folder of `test`'s own.
fn folder(test: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("ferman-assemble-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

fn open(path: &Path) -> OpenedDocument {
    block_on(engine().open(path.to_path_buf(), None)).unwrap()
}

struct Events(mpsc::Sender<JobEvent>);

impl JobSink for Events {
    fn deliver(&mut self, event: JobEvent) {
        let _ = self.0.send(event);
    }
}

fn sink() -> (Box<dyn JobSink>, mpsc::Receiver<JobEvent>) {
    let (sender, events) = mpsc::channel();
    (Box::new(Events(sender)), events)
}

fn ended(events: &mpsc::Receiver<JobEvent>) -> JobResult {
    loop {
        let event = events.recv_timeout(Duration::from_secs(120)).unwrap();
        if let Some(result) = event.result {
            return result;
        }
    }
}

/// Waits for the job's end and returns what it wrote and the revision it read.
fn done(events: &mpsc::Receiver<JobEvent>) -> (Vec<JobOutput>, Option<u32>) {
    match ended(events) {
        JobResult::Done {
            outputs, revision, ..
        } => (outputs, revision),
        other => panic!("the job ended as {other:?}"),
    }
}

fn file(name: &str, bookmark: Option<&str>) -> CombineFile {
    CombineFile {
        source: CombineSource::File {
            path: corpus(name),
            password: None,
            pages: None,
        },
        bookmark: bookmark.map(str::to_owned),
    }
}

/// Runs Combine on `files` into `output`.
fn combine(files: Vec<CombineFile>, keep_forms: bool, output: &Path) -> JobResult {
    let (events_sink, events) = sink();
    engine()
        .combine_job(
            files,
            keep_forms,
            Paper::A4,
            output.to_path_buf(),
            None,
            events_sink,
        )
        .unwrap();
    ended(&events)
}

/// Page `from` of `a` draws exactly as page `to` of `b`, at the size each lists.
fn same_page(a: &OpenedDocument, from: usize, b: &OpenedDocument, to: usize) -> bool {
    let draw = |document: &OpenedDocument, index: usize| {
        let size = document.pages[index].size;
        block_on(engine().render_page(document.id, u32::try_from(index).unwrap(), size, DPI))
            .unwrap()
    };
    compare(&draw(a, from), &draw(b, to), None, 0).is_some_and(|diff| diff.differing == 0)
}

fn titles(items: &[OutlineItem]) -> Vec<String> {
    let mut out = Vec::new();
    for item in items {
        out.push(item.title.clone());
        out.extend(titles(&item.children));
    }
    out
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn combining_a_contract_a_pdf_and_a_photo_keeps_pages_outline_attachments_and_pixels() {
    let dir = folder("combine");
    let output = dir.join("all.pdf");
    let files = vec![
        file("kira-tr.pdf", Some("Kira")),
        file("combine-outline.pdf", None),
        file("combine-photo.jpg", Some("Photo")),
    ];
    let sources: Vec<CombineSource> = files.iter().map(|file| file.source.clone()).collect();
    let preview = block_on(engine().combine_preview(sources, true)).unwrap();
    assert_eq!(preview.pages, 6);
    assert!(
        preview
            .files
            .iter()
            .all(|row| row.status == InputStatus::Ready)
    );
    assert!(preview.files[2].image);
    assert!(preview.files[0].bytes > 0);

    assert!(matches!(
        combine(files, true, &output),
        JobResult::Done { revision: None, .. }
    ));
    let written = u64::try_from(std::fs::read(&output).unwrap().len()).unwrap();
    assert!(
        preview.bytes * 10 >= written * 9,
        "{} vs {written}",
        preview.bytes
    );

    let kira = open(&pdf("kira-tr"));
    let annex = open(&pdf("combine-outline"));
    let all = open(&output);
    assert_eq!(all.pages.len(), 6);
    for page in 0..3 {
        assert!(same_page(&kira, page, &all, page), "kira page {page}");
    }
    for page in 0..2 {
        assert!(same_page(&annex, page, &all, 3 + page), "annex page {page}");
    }

    // Each file's bookmark, then the annex's own outline as it was, then the photo.
    assert_eq!(all.outline.first().unwrap().title, "Kira");
    assert_eq!(all.outline.first().unwrap().page, Some(0));
    assert_eq!(all.outline.last().unwrap().title, "Photo");
    assert_eq!(all.outline.last().unwrap().page, Some(5));
    let mut expected = vec!["Kira".to_owned()];
    expected.extend(titles(&annex.outline));
    expected.push("Photo".to_owned());
    assert_eq!(titles(&all.outline), expected);
    let annex_target = all.outline[1].page.unwrap();
    assert_eq!(annex_target, annex.outline[0].page.unwrap() + 3);

    assert_eq!(all.attachments.len(), kira.attachments.len());
    assert!(!kira.attachments.is_empty());
    assert_eq!(all.form_fields, kira.form_fields);
    assert_eq!(all.signatures.len(), kira.signatures.len());
    assert!(!all.signed);

    // The photo's page: A4, and it draws.
    let photo = &all.pages[5];
    assert!((photo.size.width - 595.28).abs() < 0.01 && (photo.size.height - 841.89).abs() < 0.01);
    let margins = block_on(engine().white_margins(all.id, vec![photo.handle])).unwrap();
    assert!(margins[0].is_some());
    for opened in [kira, annex, all] {
        block_on(engine().close(opened.id)).unwrap();
    }
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_form_added_twice_gets_its_second_fields_renamed_and_draws_the_same() {
    let dir = folder("form-twice");
    let output = dir.join("forms.pdf");
    let files = vec![
        file("form-aks1-tr.pdf", None),
        file("form-aks1-tr.pdf", None),
    ];
    assert!(matches!(
        combine(files, true, &output),
        JobResult::Done { .. }
    ));
    let source = open(&pdf("form-aks1-tr"));
    assert!(source.form_fields > 0);
    let twice = open(&output);
    let pages = source.pages.len();
    assert_eq!(twice.pages.len(), pages * 2);
    assert_eq!(twice.form_fields, source.form_fields * 2);
    for page in 0..pages {
        assert!(same_page(&source, page, &twice, page));
        assert!(same_page(&source, page, &twice, pages + page));
    }

    // Without forms, no field comes.
    let plain = dir.join("plain.pdf");
    assert!(matches!(
        combine(vec![file("form-aks1-tr.pdf", None)], false, &plain),
        JobResult::Done { .. }
    ));
    let without = open(&plain);
    assert_eq!(without.form_fields, 0);
    for opened in [source, twice, without] {
        block_on(engine().close(opened.id)).unwrap();
    }
    let _ = std::fs::remove_dir_all(dir);
}

/// Starts splitting `document` into `files` in `dir`.
fn split(
    document: DocumentId,
    files: &[ferman_api::facade::SplitFile],
    dir: &Path,
    events: Box<dyn JobSink>,
) -> JobId {
    let outputs = files
        .iter()
        .map(|file| SplitOutput {
            name: file.name.clone(),
            first: u32::try_from(file.first).unwrap(),
            last: u32::try_from(file.last).unwrap(),
        })
        .collect();
    engine()
        .split_job(document, outputs, dir.to_path_buf(), None, events)
        .unwrap()
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn splitting_a_thesis_by_chapter_adds_up_to_its_64_pages_with_each_chapter_as_it_was() {
    let dir = folder("split");
    let tez = open(&pdf("tez-tr"));
    assert_eq!(tez.pages.len(), 64);
    let preview = block_on(engine().split_preview(
        tez.id,
        SplitMode::TopBookmarks,
        "{document} — {bookmark}".to_owned(),
        Some(dir.clone()),
    ))
    .unwrap();
    assert!(!preview.encrypted && !preview.signed);
    assert_eq!(preview.files.len(), preview.bookmarks as usize + 1);
    let (events_sink, events) = sink();
    split(tez.id, &preview.files, &dir, events_sink);
    let (outputs, revision) = done(&events);
    assert_eq!(revision, Some(0));
    assert_eq!(outputs.len(), preview.files.len());
    let mut total = 0;
    for (plan, output) in preview.files.iter().zip(&outputs) {
        assert_eq!(output.path, dir.join(&plan.name));
        let written = u64::try_from(std::fs::read(&output.path).unwrap().len()).unwrap();
        // The estimate is at the high end, and not far off.
        assert!(
            plan.bytes >= written,
            "{}: {} vs {written}",
            plan.name,
            plan.bytes
        );
        assert!(
            plan.bytes <= written * 2,
            "{}: {} vs {written}",
            plan.name,
            plan.bytes
        );
        let part = open(&output.path);
        assert_eq!(part.pages.len(), plan.last - plan.first + 1);
        assert!(same_page(&tez, plan.first, &part, 0), "{}", plan.name);
        assert!(same_page(&tez, plan.last, &part, part.pages.len() - 1));
        total += part.pages.len();
        block_on(engine().close(part.id)).unwrap();
    }
    assert_eq!(total, 64);

    // The names are in use now: the plan for the same folder takes others.
    let again = block_on(engine().split_preview(
        tez.id,
        SplitMode::TopBookmarks,
        "{document} — {bookmark}".to_owned(),
        Some(dir.clone()),
    ))
    .unwrap();
    assert!(again.files[0].name.ends_with(" (2).pdf"));
    // The old plan is refused before it starts.
    let (other_sink, _events) = sink();
    let outputs = preview
        .files
        .iter()
        .map(|file| SplitOutput {
            name: file.name.clone(),
            first: 0,
            last: 0,
        })
        .collect();
    let refused: ApiError = engine()
        .split_job(tez.id, outputs, dir.clone(), None, other_sink)
        .unwrap_err();
    assert_eq!(refused.kind, ErrorKind::InvalidInput);
    block_on(engine().close(tez.id)).unwrap();
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_blank_page_found_from_its_pixels_ends_a_file() {
    let dir = folder("blank");
    let kira = open(&pdf("kira-tr"));
    let handle = kira.pages[0].handle;
    block_on(engine().insert_blank_pages(kira.id, Some(handle), 1, (595.0, 842.0), "Blank".into()))
        .unwrap();
    let preview = block_on(engine().split_preview(
        kira.id,
        SplitMode::BlankPages,
        "{document} {n}".to_owned(),
        None,
    ))
    .unwrap();
    assert_eq!(preview.blank_pages, 1);
    let spans: Vec<_> = preview.files.iter().map(|f| (f.first, f.last)).collect();
    assert_eq!(spans, [(0, 0), (2, 3)]);
    assert_eq!(preview.files[1].name, "kira-tr 2.pdf");
    block_on(engine().close(kira.id)).unwrap();
    let _ = std::fs::remove_dir_all(dir);
}

/// Cancels its job at the first page it reports.
struct CancelAtFirstPage(mpsc::Sender<JobEvent>);

impl JobSink for CancelAtFirstPage {
    fn deliver(&mut self, event: JobEvent) {
        if event.progress.is_some() {
            engine().cancel_job(event.job);
        }
        let _ = self.0.send(event);
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_job_cancelled_midway_leaves_no_file() {
    let dir = folder("cancel");
    let output = dir.join("no.pdf");
    let (sender, events) = mpsc::channel();
    engine()
        .combine_job(
            vec![file("tez-tr.pdf", None)],
            true,
            Paper::A4,
            output.clone(),
            None,
            Box::new(CancelAtFirstPage(sender)),
        )
        .unwrap();
    assert_eq!(ended(&events), JobResult::Cancelled);
    assert!(!output.exists());

    let tez = open(&pdf("tez-tr"));
    let preview = block_on(engine().split_preview(
        tez.id,
        SplitMode::EveryPages(4),
        "{document} {n}".to_owned(),
        Some(dir.clone()),
    ))
    .unwrap();
    let (sender, events) = mpsc::channel();
    split(
        tez.id,
        &preview.files,
        &dir,
        Box::new(CancelAtFirstPage(sender)),
    );
    assert_eq!(ended(&events), JobResult::Cancelled);
    assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 0);
    block_on(engine().close(tez.id)).unwrap();
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn an_extract_reports_the_revision_it_read_and_takes_its_edits() {
    let dir = folder("extract");
    let output = dir.join("part.pdf");
    let kira = open(&pdf("kira-tr"));
    let handles: Vec<u64> = kira.pages.iter().map(|page| page.handle).collect();
    let turned =
        block_on(engine().rotate_pages(kira.id, vec![handles[2]], 1, "Rotated".into())).unwrap();
    let pages = turned.structure.unwrap().pages;
    let (events_sink, events) = sink();
    engine()
        .extract_pages_job(
            kira.id,
            vec![handles[2], handles[0]],
            output.clone(),
            None,
            events_sink,
        )
        .unwrap();
    let (outputs, revision) = done(&events);
    assert_eq!(revision, Some(1));
    assert_eq!(outputs[0].path, output);
    let part = open(&output);
    assert_eq!(part.pages.len(), 2);
    assert_eq!(part.pages[0].size, pages[2].size);
    let mut current = kira.clone();
    current.pages = pages;
    assert!(same_page(&current, 2, &part, 0));
    assert!(same_page(&current, 0, &part, 1));
    assert!(part.attachments.is_empty(), "attachments belong to no page");
    block_on(engine().close(part.id)).unwrap();

    // A file there already is not replaced.
    let (other_sink, _events) = sink();
    let err = engine()
        .extract_pages_job(kira.id, vec![handles[0]], output, None, other_sink)
        .unwrap_err();
    assert_eq!(err.kind, ErrorKind::InvalidInput);
    block_on(engine().close(kira.id)).unwrap();
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn an_insert_is_one_undoable_step_and_refused_if_the_document_moved() {
    let dir = folder("insert");
    let path = dir.join("tree.pdf");
    std::fs::copy(pdf("pages-tree"), &path).unwrap();
    let tree = open(&path);
    let annex = open(&pdf("combine-outline"));
    let handles: Vec<u64> = tree.pages.iter().map(|page| page.handle).collect();
    let (sink1, events) = sink();
    let job = engine()
        .insert_pages_job(
            tree.id,
            pdf("combine-outline"),
            None,
            None,
            Some(handles[1]),
            Paper::A4,
            "Inserted".to_owned(),
            sink1,
        )
        .unwrap();
    assert!(matches!(
        ended(&events),
        JobResult::Done { change: true, .. }
    ));
    let info = block_on(engine().apply_job_change(job)).unwrap();
    let after = info.structure.unwrap();
    assert_eq!(after.pages.len(), handles.len() + 2);
    assert_eq!(after.pages[1].handle, handles[1]);
    assert_eq!(after.pages[4].handle, handles[2]);
    let mut current = tree.clone();
    current.pages.clone_from(&after.pages);
    assert!(same_page(&annex, 0, &current, 2));
    assert!(same_page(&annex, 1, &current, 3));
    let inserted = titles(&after.outline);
    assert!(titles(&annex.outline).iter().all(|t| inserted.contains(t)));
    let undone = block_on(engine().undo(tree.id)).unwrap();
    assert_eq!(undone.structure.unwrap().pages.len(), handles.len());

    // A job whose document moved on before its change is applied.
    let (sink2, events) = sink();
    let job = engine()
        .insert_pages_job(
            tree.id,
            corpus("combine-photo.jpg"),
            None,
            None,
            None,
            Paper::Letter,
            "Photo".to_owned(),
            sink2,
        )
        .unwrap();
    assert!(matches!(
        ended(&events),
        JobResult::Done { change: true, .. }
    ));
    block_on(engine().rotate_pages(tree.id, vec![handles[0]], 1, "Rotated".into())).unwrap();
    let stale = block_on(engine().apply_job_change(job)).unwrap_err();
    assert_eq!(stale.details.as_deref(), Some(JOB_STALE));

    for opened in [tree, annex] {
        block_on(engine().close(opened.id)).unwrap();
    }
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_replaced_page_keeps_its_place_and_what_went_to_it_and_undo_brings_it_back() {
    let dir = folder("replace");
    let path = dir.join("tez.pdf");
    std::fs::copy(pdf("tez-tr"), &path).unwrap();
    let tez = open(&path);
    let annex = open(&pdf("combine-outline"));
    let target = tez.outline[1].page.unwrap() as usize;
    let handle = tez.pages[target].handle;
    let (sink1, events) = sink();
    let job = engine()
        .replace_pages_job(
            tez.id,
            vec![handle],
            pdf("combine-outline"),
            None,
            Some(vec![1]),
            "Replaced".to_owned(),
            sink1,
        )
        .unwrap();
    done(&events);
    let info = block_on(engine().apply_job_change(job)).unwrap();
    let after = info.structure.unwrap();
    assert_eq!(after.pages.len(), 64);
    assert_eq!(after.pages[target].handle, handle);
    assert_eq!(after.pages[target].label, tez.pages[target].label);
    assert_eq!(after.outline[1].page, tez.outline[1].page);
    let mut current = tez.clone();
    current.pages.clone_from(&after.pages);
    assert!(same_page(&annex, 1, &current, target));

    let saved = dir.join("saved.pdf");
    block_on(engine().save_as(
        tez.id,
        saved.clone(),
        ferman_api::facade::SaveOptions::default(),
        None,
    ))
    .unwrap();
    let reopened = open(&saved);
    assert_eq!(reopened.pages.len(), 64);
    assert!(same_page(&annex, 1, &reopened, target));
    block_on(engine().close(reopened.id)).unwrap();

    let undone = block_on(engine().undo(tez.id)).unwrap();
    assert_eq!(undone.structure.unwrap().pages[target].handle, handle);
    let original = open(&pdf("tez-tr"));
    assert!(same_page(&original, target, &tez, target));
    block_on(engine().close(original.id)).unwrap();
    for opened in [tez, annex] {
        block_on(engine().close(opened.id)).unwrap();
    }
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_replaced_page_draws_as_its_source_under_a_node_that_rotates_or_crops() {
    let annex = open(&pdf("combine-outline"));
    for target in [0, 3] {
        let tree = open(&pdf("pages-tree"));
        let (events_sink, events) = sink();
        let job = engine()
            .replace_pages_job(
                tree.id,
                vec![tree.pages[target].handle],
                pdf("combine-outline"),
                None,
                Some(vec![0]),
                "Replaced".to_owned(),
                events_sink,
            )
            .unwrap();
        done(&events);
        let after = block_on(engine().apply_job_change(job)).unwrap();
        let mut current = tree.clone();
        current.pages.clone_from(&after.structure.unwrap().pages);
        assert_eq!(current.pages[target].rotation, annex.pages[0].rotation);
        assert_eq!(current.pages[target].size, annex.pages[0].size);
        assert!(same_page(&annex, 0, &current, target), "page {target}");
        block_on(engine().close(tree.id)).unwrap();
    }
    block_on(engine().close(annex.id)).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_locked_input_says_so_and_a_signature_or_protection_does_not_travel() {
    let dir = folder("locked");
    let row = |name: &str, password: Option<&str>| {
        let source = CombineSource::File {
            path: corpus(name),
            password: password
                .map(|password| ferman_api::facade::Password::new(password.to_owned())),
            pages: None,
        };
        block_on(engine().combine_preview(vec![source], true))
            .unwrap()
            .files
            .remove(0)
    };
    assert_eq!(
        row("kira-tr-restricted.pdf", None).status,
        InputStatus::OwnerPasswordRequired
    );
    assert_eq!(
        row("does-not-exist.pdf", None).status,
        InputStatus::Unreadable
    );
    assert_eq!(
        row("kira-tr.expected.txt", None).status,
        InputStatus::Unreadable
    );
    let signed = row("kira-tr-signed.pdf", None);
    assert_eq!(signed.status, InputStatus::Ready);
    assert!(signed.signed);

    // A range past its pages or naming a page twice.
    for pages in [vec![99], vec![0, 0], vec![]] {
        let source = CombineSource::File {
            path: pdf("kira-tr"),
            password: None,
            pages: Some(pages),
        };
        let preview = block_on(engine().combine_preview(vec![source], true)).unwrap();
        assert_eq!(preview.files[0].status, InputStatus::BadRange);
    }

    let output = dir.join("unsigned.pdf");
    assert!(matches!(
        combine(vec![file("kira-tr-signed.pdf", None)], true, &output),
        JobResult::Done { .. }
    ));
    let source = ferman_core::Source::read(&output).unwrap();
    let document = ferman_core::open(&source, &ferman_core::OpenOptions::default()).unwrap();
    assert!(!document.structure().signed());
    assert!(document.encryption().is_none());

    // Protection does not travel: pages of a file opened with its password, as they drew.
    let protected = dir.join("plain.pdf");
    let input = CombineFile {
        source: CombineSource::File {
            path: pdf("payslip-aes128"),
            password: Some(ferman_api::facade::Password::new("bordro2026".to_owned())),
            pages: None,
        },
        bookmark: None,
    };
    assert!(matches!(
        combine(vec![input], true, &protected),
        JobResult::Done { .. }
    ));
    let plain = open(&protected);
    assert!(plain.security.is_none());
    let source = block_on(engine().open(
        pdf("payslip-aes128"),
        Some(ferman_api::facade::Password::new("bordro2026".to_owned())),
    ))
    .unwrap();
    assert!(same_page(&source, 0, &plain, 0));
    for opened in [source, plain] {
        block_on(engine().close(opened.id)).unwrap();
    }

    let refused = dir.join("refused.pdf");
    match combine(vec![file("kira-tr-restricted.pdf", None)], true, &refused) {
        JobResult::Failed(err) => assert_eq!(err.kind, ErrorKind::NotEditable),
        other => panic!("{other:?}"),
    }
    assert!(!refused.exists());
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn create_pdf_from_a_blank_page_writes_a_new_file() {
    let dir = folder("create");
    let output = dir.join("new.pdf");
    let blank = CombineFile {
        source: CombineSource::Blank(612.0, 792.0),
        bookmark: None,
    };
    assert!(matches!(
        combine(vec![blank], true, &output),
        JobResult::Done { .. }
    ));
    let created = open(&output);
    assert_eq!(created.pages.len(), 1);
    assert_eq!(created.pages[0].size.width, 612.0);
    let margins =
        block_on(engine().white_margins(created.id, vec![created.pages[0].handle])).unwrap();
    assert!(margins[0].is_none());
    block_on(engine().close(created.id)).unwrap();
    let (other_sink, _events) = sink();
    assert!(
        engine()
            .combine_job(
                Vec::new(),
                true,
                Paper::A4,
                dir.join("none.pdf"),
                None,
                other_sink
            )
            .is_err()
    );
    let _ = std::fs::remove_dir_all(dir);
}
