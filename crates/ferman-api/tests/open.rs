//! Opening the corpus through the facade (ROADMAP §6 step 2, ADR 0004, G102): every file opens,
//! or fails, with the kind its README row implies; lopdf and PDFium agree on the pages of every
//! file but `disagree-pages`, made for this check, whose second page lacks `/Type /Page` and which
//! therefore opens read-only; a view gets its thumbnail; and showing or hiding a layer changes the
//! pixels, and changing it back gives the first render again; and a search streams its matches
//! and ends, or stops when cancelled.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;
use std::sync::{OnceLock, mpsc};
use std::time::Duration;

use ferman_api::facade::{
    Agreement, ApiError, Engine, EngineConfig, ErrorKind, Item, MAX_THUMBNAIL_SIZE, OpenedDocument,
    Password, PdfiumLibrary, Priority, ReadOnly, Rendered, SearchEvent, SearchOptions, SearchSink,
    ThumbnailRequest, ViewEvent, ViewSink, Wanted, block_on,
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
const FILES: [(&str, Option<&str>); 34] = [
    ("disagree-pages", None),
    ("form-aks1-flat", None),
    ("form-aks1-tr", None),
    ("js-openaction", None),
    ("kira-tr", None),
    ("kira-tr-damaged", None),
    ("kira-tr-restricted", None),
    ("kira-tr-signed", None),
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
    ("annots-other-producer", None),
    ("cert-p1", None),
    ("cert-p2", None),
    ("cert-p3", None),
    ("form-signed", None),
    ("form-hybrid-xfa", None),
    ("form-need-appearances", None),
    ("form-script", None),
    ("form-lists-comb", None),
    ("combine-outline", None),
    ("images-compress", None),
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
fn the_open_carries_the_sidebar_lists() {
    let kira = open("kira-tr", None).unwrap();
    assert_eq!(kira.attachments.len(), 3);
    assert_eq!(kira.signatures.len(), 2);
    assert!(kira.signatures.iter().all(|field| !field.signed));
    let nda = open("nda-en", None).unwrap();
    assert!(nda.signatures.iter().any(|field| field.signed));
    let plan = open("ocg-plan", None).unwrap();
    assert_eq!(plan.layers.len(), 6);
    assert_eq!(plan.layers.iter().filter(|layer| !layer.visible).count(), 1);
    let tez = open("tez-tr", None).unwrap();
    assert!(tez.outline.iter().any(|item| !item.children.is_empty()));
    for document in [kira, nda, plan, tez] {
        block_on(engine().close(document.id)).unwrap();
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn the_open_carries_the_properties_and_the_owner_unlock_lifts_restrictions() {
    let kira = open("kira-tr", None).unwrap();
    assert!(!kira.version.is_empty());
    assert_eq!(
        kira.file_size,
        std::fs::metadata(path("kira-tr")).unwrap().len()
    );
    assert!(!kira.fonts.is_empty());
    assert!(kira.fonts.iter().all(|font| font.embedded));
    assert!(kira.security.is_none());
    assert_eq!(kira.scripts.count, 0);
    assert!(open("tez-tr", None).unwrap().tagged);
    assert!(open("js-openaction", None).unwrap().scripts.count > 0);

    let payslip = open("payslip-rc4-40", Some("bordro2026")).unwrap();
    let security = payslip.security.unwrap();
    assert!(security.user_password_required);

    let restricted = open("kira-tr-restricted", None).unwrap();
    let security = restricted.security.unwrap();
    assert!(!security.user_password_required && !security.owner);
    assert!(security.restricted());
    assert!(security.permissions.print() && !security.permissions.modify());
    let wrong = block_on(engine().unlock_owner(restricted.id, Password::new("kaya".to_owned())))
        .unwrap_err();
    assert_eq!(wrong.kind, ErrorKind::WrongPassword);
    let unlocked =
        block_on(engine().unlock_owner(restricted.id, Password::new("Kaya-Moda-18".to_owned())))
            .unwrap()
            .unwrap();
    assert!(unlocked.owner && !unlocked.restricted());
    assert_eq!(unlocked.permissions, security.permissions);
    // Not encrypted: nothing to lift.
    assert_eq!(
        block_on(engine().unlock_owner(kira.id, Password::new(String::new()))).unwrap(),
        None
    );
    for id in [kira.id, payslip.id, restricted.id] {
        block_on(engine().close(id)).unwrap();
    }
    let gone = block_on(engine().unlock_owner(kira.id, Password::new(String::new()))).unwrap_err();
    assert_eq!(gone.kind, ErrorKind::NotFound);
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn files_that_do_not_open_say_why() {
    let kind = |name: &str, password: Option<&str>| open(name, password).unwrap_err().kind;
    assert_eq!(kind("truncated", None), ErrorKind::Damaged);
    // a1-9b's sentence and its technical details.
    let truncated = open("truncated", None).unwrap_err();
    assert_eq!(truncated.message_key.as_str(), "errorDamagedTruncated");
    let details = truncated.details.unwrap();
    assert!(details.contains("last complete object"), "{details}");
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

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn showing_and_hiding_a_layer_renders_the_page_again() {
    let plan = open("ocg-plan", None).unwrap();
    assert!(plan.layers_switchable);
    let defaults: Vec<bool> = plan.layers.iter().map(|layer| layer.visible).collect();
    // "Tesisat", off by default, holds only lines; "Duvarlar" the walls.
    assert_eq!(defaults, [true, true, true, true, true, false]);
    let (events, received) = mpsc::channel();
    let view = block_on(engine().open_view(plan.id, Box::new(Sink(events)))).unwrap();
    let mut generation = 0;
    let mut render = || -> Rendered {
        generation += 1;
        let wanted = vec![Wanted {
            item: Item::Thumbnail(ThumbnailRequest {
                page: 0,
                size: MAX_THUMBNAIL_SIZE,
            }),
            priority: Priority::VisibleThumbnail,
        }];
        engine().request(view, generation, wanted).unwrap();
        match received.recv_timeout(Duration::from_secs(10)).unwrap() {
            ViewEvent::Rendered(rendered) => rendered,
            ViewEvent::Failed(failed) => panic!("{failed:?}"),
        }
    };
    let first = render();
    assert_eq!(first.render_key, 0);
    let show =
        |visible: &[bool]| block_on(engine().show_layers(plan.id, visible.to_vec())).unwrap();

    let key = show(&[true; 6]);
    let pipes = render();
    assert_eq!(pipes.render_key, key);
    assert_ne!(
        pipes.pixels, first.pixels,
        "showing Tesisat draws its lines"
    );

    let again = show(&defaults);
    assert!(again > key);
    let back = render();
    assert_eq!(back.render_key, again);
    assert_eq!(
        back.pixels, first.pixels,
        "the default state renders as the file does"
    );

    show(&[false, true, true, true, true, false]);
    assert_ne!(
        render().pixels,
        first.pixels,
        "hiding Duvarlar removes the walls"
    );

    let wrong = block_on(engine().show_layers(plan.id, vec![true])).unwrap_err();
    assert_eq!(wrong.kind, ErrorKind::InvalidInput);
    let kira = open("kira-tr", None).unwrap();
    assert!(!kira.layers_switchable);
    let none = block_on(engine().show_layers(kira.id, Vec::new())).unwrap_err();
    assert_eq!(none.kind, ErrorKind::Unsupported);
    for document in [plan, kira] {
        block_on(engine().close(document.id)).unwrap();
    }
}

/// A search's events, sent to this test's thread.
struct Found(mpsc::Sender<SearchEvent>);

impl SearchSink for Found {
    fn deliver(&mut self, event: SearchEvent) -> bool {
        self.0.send(event).is_ok()
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_search_streams_its_matches_and_ends() {
    let kira = open("kira-tr", None).unwrap();
    let (events, received) = mpsc::channel();
    let id = engine()
        .search(
            kira.id,
            "kira".to_owned(),
            SearchOptions::default(),
            false,
            Box::new(Found(events)),
        )
        .unwrap();
    let next = || received.recv_timeout(Duration::from_secs(10)).unwrap();
    assert_eq!(next(), SearchEvent::Started(id));
    let mut matches = Vec::new();
    loop {
        match next() {
            SearchEvent::Matches(page) => matches.extend(page),
            SearchEvent::Progress { searched, pages } => assert!(searched <= pages),
            SearchEvent::Done {
                cancelled,
                textless,
            } => {
                assert!(!cancelled && !textless);
                break;
            }
            SearchEvent::Started(_) => panic!("started twice"),
        }
    }
    let first = &matches[0];
    assert_eq!(first.page, 0);
    let snippet: Vec<char> = first.snippet.chars().collect();
    let range = first.snippet_range.start as usize..first.snippet_range.end as usize;
    assert_eq!(snippet[range].iter().collect::<String>(), "KİRA");
    let [left, top, right, bottom] = first.rects[0];
    let (width, height) = (kira.pages[0].size.width, kira.pages[0].size.height);
    assert!(
        0.0 < left && left < right && right < width && 0.0 < top && top < bottom && bottom < height
    );
    assert!(matches.len() > 5, "{} matches", matches.len());

    // A cancelled search ends as cancelled, or as done if it was quicker. A committed file: CI
    // has no long-500.
    let long = open("tez-tr", None).unwrap();
    let (events, received) = mpsc::channel();
    let id = engine()
        .search(
            long.id,
            "e".to_owned(),
            SearchOptions::default(),
            false,
            Box::new(Found(events)),
        )
        .unwrap();
    engine().cancel_search(id);
    let ended = received
        .iter()
        .find_map(|event| match event {
            SearchEvent::Done { cancelled, .. } => Some(cancelled),
            _ => None,
        })
        .unwrap();
    assert!(ended || received.try_recv().is_err());
    for document in [kira, long] {
        block_on(engine().close(document.id)).unwrap();
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_search_of_a_scan_ends_textless() {
    let scan = open("scan-tr", None).unwrap();
    let (events, received) = mpsc::channel();
    engine()
        .search(
            scan.id,
            "kira".to_owned(),
            SearchOptions::default(),
            false,
            Box::new(Found(events)),
        )
        .unwrap();
    let done = received
        .iter()
        .find_map(|event| match event {
            SearchEvent::Done {
                cancelled,
                textless,
            } => Some((cancelled, textless)),
            _ => None,
        })
        .unwrap();
    assert_eq!(done, (false, true));
    block_on(engine().close(scan.id)).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_search_can_look_in_the_bookmarks() {
    let tez = open("tez-tr", None).unwrap();
    let item = tez.outline.iter().find(|item| item.page.is_some()).unwrap();
    let word = item.title.split_whitespace().next().unwrap().to_owned();
    let matches = |bookmarks: bool| {
        let (events, received) = mpsc::channel();
        engine()
            .search(
                tez.id,
                word.clone(),
                SearchOptions::default(),
                bookmarks,
                Box::new(Found(events)),
            )
            .unwrap();
        let mut found = Vec::new();
        for event in received.iter() {
            match event {
                SearchEvent::Matches(page) => found.extend(page),
                SearchEvent::Done { .. } => break,
                _ => {}
            }
        }
        found
    };
    let with = matches(true);
    let titled = with
        .iter()
        .find(|found| found.bookmark && found.snippet == item.title)
        .unwrap();
    assert_eq!(Some(titled.page), item.page);
    assert!(titled.rects.is_empty());
    // A bookmark's match comes before its page's text, in page order.
    assert!(with.windows(2).all(|pair| pair[0].page <= pair[1].page));
    assert!(matches(false).iter().all(|found| !found.bookmark));
    block_on(engine().close(tez.id)).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn the_open_says_what_the_start_screen_badges_need() {
    let scan = open("scan-tr", None).unwrap();
    let kira = open("kira-tr", None).unwrap();
    let form = open("form-aks1-tr", None).unwrap();
    assert!(scan.scanned && !kira.scanned && !form.scanned);
    assert_eq!(scan.form_fields, 0);
    assert!(form.form_fields > 0);
    for document in [scan, kira, form] {
        block_on(engine().close(document.id)).unwrap();
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn font_coverage_says_what_pdfium_draws_and_what_a_subset_lacks() {
    // Standard 14 Helvetica, not embedded: PDFium's face is named or is the same face.
    let helvetica = open("edit-e15-helvetica", None).unwrap();
    let coverage = block_on(engine().font_coverage(helvetica.id, "abc".to_owned())).unwrap();
    assert!(coverage.iter().all(|font| font.missing_letters.is_empty()));
    assert!(
        coverage
            .iter()
            .all(|font| font.shown_as.as_deref() != Some(""))
    );
    block_on(engine().close(helvetica.id)).unwrap();

    // A Turkish contract's subsets: Cyrillic is in none of them, its own letters in one at least.
    let kira = open("kira-tr", None).unwrap();
    let coverage = block_on(engine().font_coverage(kira.id, "\u{416}\u{15f}".to_owned())).unwrap();
    assert!(!coverage.is_empty());
    assert!(coverage.iter().all(|font| font.name.contains('+')));
    assert!(
        coverage
            .iter()
            .all(|font| font.missing_letters.contains('\u{416}'))
    );
    assert!(
        coverage
            .iter()
            .any(|font| !font.missing_letters.contains('\u{15f}'))
    );
    block_on(engine().close(kira.id)).unwrap();
}
