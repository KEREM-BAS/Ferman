//! Form fields through the facade (M4 plan, W3) on the corpus's forms, `form-aks1-tr` first: every
//! field type read, set, saved, reopened and rendered. Pixels change only inside the field, only
//! its page gets a new render key, an untouched field's bytes stay in the original's prefix,
//! opening changes nothing, radio kids stay in step, a Turkish letter the field's WinAnsi font
//! cannot draw takes bundled Plex and says so, Finish leaves the page looking the same with no
//! widgets left and follows the font policy, and the script form's scripts never run. Hostile field trees are core's unit tests (`ferman_core::forms`).
//!
//! PDFium draws no widget in Ferman's render path (it draws widgets only through its form-fill
//! overlay, which tiles cannot use: B203), so what a reader shows of a form is drawn here through
//! Finish, which places each widget's appearance as PDFium places an annotation's, and then
//! undone.
//!
//! Needs PDFium: `FERMAN_PDFIUM_PATH`, absolute (tools/pdfium/fetch.sh).
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::{Path, PathBuf};
use std::sync::{OnceLock, mpsc};

use ferman_api::facade::{
    DocumentId, Engine, EngineConfig, ErrorKind, FieldInfo, FieldKind, FieldProblem, FontSettings,
    Ink, MissingFont, NewSignature, OpGate, OpenedDocument, PageInfo, PageRaster, PdfiumLibrary,
    SearchEvent, SearchOptions, SearchPlaces, SearchSink, block_on, compare, device_region,
};
use ferman_core::DocumentOp;

const DPI: u32 = 110;
const FORM: &str = "form-aks1-tr";
/// form-aks1-tr's 20 fields in tab order.
const ORDER: [&str; 20] = [
    "tc_kimlik_no",
    "dogum_tarihi",
    "adi",
    "soyadi",
    "cinsiyet",
    "medeni_hal",
    "telefon",
    "eposta",
    "il",
    "ilce",
    "mahalle",
    "cadde_sokak",
    "dis_kapi_no",
    "ic_kapi_no",
    "tasinma_tarihi",
    "hane_kisi_sayisi",
    "beyan_dogruluk",
    "beyan_kurum",
    "beyan_tarihi",
    "imza",
];

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

fn corpus(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"))
}

fn copy(test: &str, name: &str) -> (PathBuf, PathBuf) {
    let dir = std::env::temp_dir().join(format!("ferman-forms-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(format!("{name}.pdf"));
    std::fs::copy(corpus(name), &path).unwrap();
    (dir, path)
}

fn open(path: &Path) -> OpenedDocument {
    block_on(engine().open(path.to_path_buf(), None)).unwrap()
}

fn draw(doc: DocumentId, pages: &[PageInfo], index: usize) -> PageRaster {
    let page = u32::try_from(index).unwrap();
    block_on(engine().render_page(doc, page, pages[index].size, DPI)).unwrap()
}

/// The page as a reader shows its fields: drawn after Finish, which is then undone.
fn seen(doc: DocumentId, pages: &[PageInfo]) -> PageRaster {
    block_on(engine().finish_form(doc, None, "Finish".to_owned())).unwrap();
    let shown = draw(doc, pages, 0);
    block_on(engine().undo(doc)).unwrap();
    shown
}

fn fields(doc: DocumentId) -> Vec<FieldInfo> {
    block_on(engine().form_fields(doc)).unwrap().fields
}

fn field(doc: DocumentId, name: &str) -> FieldInfo {
    fields(doc).into_iter().find(|f| f.name == name).unwrap()
}

/// The box around every widget of `field`.
fn around(field: &FieldInfo) -> [f32; 4] {
    field.widgets.iter().fold(
        [f32::MAX, f32::MAX, f32::MIN, f32::MIN],
        |[l, t, r, b], widget| {
            [
                l.min(widget.rect[0]),
                t.min(widget.rect[1]),
                r.max(widget.rect[2]),
                b.max(widget.rect[3]),
            ]
        },
    )
}

/// Asserts `before` and `after` differ, and only inside `rect` (displayed points).
fn only_inside(before: &PageRaster, after: &PageRaster, rect: [f32; 4], context: &str) {
    let scale = f64::from(DPI) / 72.0;
    let region = device_region(&[rect], scale).unwrap();
    let diff = compare(before, after, Some(region), 2).unwrap();
    assert!(diff.passed(), "{context}: {diff:?} outside {rect:?}");
    assert!(diff.differing > 0, "{context}: nothing was drawn");
}

fn set(doc: DocumentId, name: &str, values: &[&str]) -> ferman_api::facade::FieldCommit {
    let handle = field(doc, name).handle;
    let values = values.iter().map(|value| (*value).to_owned()).collect();
    block_on(engine().set_field_value(doc, handle, values, None, format!("Fill {name}"))).unwrap()
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn opening_and_reading_change_nothing() {
    let (dir, path) = copy("open", FORM);
    let original = std::fs::read(&path).unwrap();
    let opened = open(&path);
    let form = block_on(engine().form_fields(opened.id)).unwrap();
    assert_eq!(form.fields.len(), 20);
    assert_eq!((form.required, form.required_left), (15, 15));
    assert_eq!(
        block_on(engine().history(opened.id)).unwrap().steps.len(),
        0
    );
    block_on(engine().close(opened.id)).unwrap();
    assert_eq!(std::fs::read(&path).unwrap(), original);
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
#[allow(clippy::too_many_lines)]
fn every_field_type_is_set_saved_reopened_and_rendered() {
    let (dir, path) = copy("types", FORM);
    let original = std::fs::read(&path).unwrap();
    let opened = open(&path);
    let doc = opened.id;
    let pages = opened.pages.clone();
    let list = fields(doc);
    let kinds = |kind| list.iter().filter(|f| f.kind == kind).count();
    assert_eq!(kinds(FieldKind::Radio), 1);
    assert_eq!(kinds(FieldKind::Check), 2);
    assert_eq!(kinds(FieldKind::Signature), 1);
    assert!(kinds(FieldKind::Combo) >= 3);
    // Tab order: row by row down the page, left to right.
    let order: Vec<&str> = list.iter().map(|f| f.name.as_str()).collect();
    assert_eq!(order, ORDER);
    let radio = list.iter().find(|f| f.kind == FieldKind::Radio).unwrap();
    let states: Vec<String> = radio
        .widgets
        .iter()
        .map(|w| w.on_state.clone().unwrap())
        .collect();
    assert_eq!(states, ["Kadin", "Erkek"]);
    let check = list.iter().find(|f| f.name == "beyan_dogruluk").unwrap();
    let on = check.widgets[0].on_state.clone().unwrap();
    let province = list.iter().find(|f| f.name == "il").unwrap();
    let chosen = province.options[1].0.clone();

    let cases: Vec<(&str, Vec<String>, bool)> = vec![
        ("tc_kimlik_no", vec!["10000000146".to_owned()], false),
        // ş and ı are not in the field's WinAnsi /Helv: bundled Plex, said so.
        ("adi", vec!["Ayşe".to_owned()], true),
        ("soyadi", vec!["Yılmaz".to_owned()], true),
        ("eposta", vec!["ayse@example.com".to_owned()], false),
        ("tasinma_tarihi", vec!["01.11.2026".to_owned()], false),
        ("hane_kisi_sayisi", vec!["3".to_owned()], false),
        ("cinsiyet", vec!["Kadin".to_owned()], false),
        ("beyan_dogruluk", vec![on.clone()], false),
        ("il", vec![chosen.clone()], false),
    ];
    for (name, values, bundled) in &cases {
        let before = seen(doc, &pages);
        let target = field(doc, name);
        let commit = block_on(engine().set_field_value(
            doc,
            target.handle,
            values.clone(),
            None,
            format!("Fill {name}"),
        ))
        .unwrap();
        assert_eq!(commit.revision.changed_pages, Some(vec![0]), "{name}");
        assert!(!commit.asks_font && !commit.marked, "{name}");
        assert_eq!(
            commit.fonts.iter().any(|f| f == "IBM Plex Sans"),
            *bundled,
            "{name}: {:?}",
            commit.fonts
        );
        assert_eq!(field(doc, name).values, *values, "{name}");
        only_inside(&before, &seen(doc, &pages), around(&target), name);
    }

    // Radio kids stay in step: the other kid turns on, the first off.
    let before = seen(doc, &pages);
    set(doc, "cinsiyet", &["Erkek"]);
    only_inside(&before, &seen(doc, &pages), around(radio), "radio");
    assert_eq!(field(doc, "cinsiyet").values, ["Erkek"]);

    // Declared formats and ranges (decision 17).
    let commit = set(doc, "hane_kisi_sayisi", &["25"]);
    assert_eq!(
        commit.problem,
        Some(FieldProblem::OutOfRange {
            min: Some(1.0),
            max: Some(20.0)
        })
    );
    let commit = set(doc, "beyan_tarihi", &["31.02.2026"]);
    assert!(matches!(
        commit.problem,
        Some(FieldProblem::NotADate { .. })
    ));
    let form = block_on(engine().form_fields(doc)).unwrap();
    assert_eq!(form.problems, 2);
    set(doc, "hane_kisi_sayisi", &["3"]);
    set(doc, "beyan_tarihi", &["07.11.2026"]);
    let form = block_on(engine().form_fields(doc)).unwrap();
    assert_eq!(form.problems, 0);
    // Required filled: T.C., Adı, Soyadı, cinsiyet, il, taşınma, hane, beyan, beyan tarihi.
    assert_eq!(form.required_left, 15 - 9);

    // The same value adds no step.
    let steps = block_on(engine().history(doc)).unwrap().steps.len();
    set(doc, "eposta", &["ayse@example.com"]);
    assert_eq!(block_on(engine().history(doc)).unwrap().steps.len(), steps);

    let shown = seen(doc, &pages);
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();

    // The original is an exact prefix, and no untouched field is in the update.
    let saved = std::fs::read(&path).unwrap();
    assert_eq!(saved[..original.len()], original[..]);
    let update = &saved[original.len()..];
    for untouched in [&b"(telefon)"[..], b"(mahalle)", b"(imza)", b"(beyan_kurum)"] {
        assert!(
            !update.windows(untouched.len()).any(|w| w == untouched),
            "{}",
            String::from_utf8_lossy(untouched)
        );
    }
    assert!(update.windows(12).any(|w| w == b"+IBMPlexSans"));

    let again = open(&path);
    for (name, values, _) in cases.iter().filter(|(name, ..)| *name != "cinsiyet") {
        assert_eq!(field(again.id, name).values, *values, "{name}");
    }
    assert_eq!(field(again.id, "cinsiyet").values, ["Erkek"]);
    let diff = compare(&shown, &seen(again.id, &again.pages), None, 0).unwrap();
    assert_eq!(diff.differing, 0, "reopens as it showed: {diff:?}");

    // The rest of the 20: every value field, and a simple signature on imza.
    let doc = again.id;
    let marital = field(doc, "medeni_hal").options[1].0.clone();
    let district = field(doc, "ilce").options[2].0.clone();
    let kurum = field(doc, "beyan_kurum").widgets[0]
        .on_state
        .clone()
        .unwrap();
    let rest: Vec<(&str, Vec<String>)> = vec![
        ("dogum_tarihi", vec!["15.03.1990".to_owned()]),
        ("medeni_hal", vec![marital]),
        ("telefon", vec!["0532 000 00 00".to_owned()]),
        ("ilce", vec![district]),
        ("mahalle", vec!["Merkez".to_owned()]),
        ("cadde_sokak", vec!["Atatürk Caddesi".to_owned()]),
        ("dis_kapi_no", vec!["12".to_owned()]),
        ("ic_kapi_no", vec!["4".to_owned()]),
        ("beyan_kurum", vec![kurum]),
    ];
    for (name, values) in &rest {
        let values: Vec<&str> = values.iter().map(String::as_str).collect();
        set(doc, name, &values);
    }
    let imza = field(doc, "imza");
    block_on(engine().add_signature(
        doc,
        again.pages[0].handle,
        NewSignature {
            rect: imza.widgets[0].rect,
            ink: Ink::Typed {
                text: "Ayşe Yılmaz".to_owned(),
                family: "Caveat".to_owned(),
            },
            color: [0.1, 0.1, 0.45],
            tilt: 0.0,
            initials: false,
            field: Some("imza".to_owned()),
            author: "Ayşe Yılmaz".to_owned(),
        },
        "Sign".to_owned(),
    ))
    .unwrap();
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();

    let last = open(&path);
    let form = block_on(engine().form_fields(last.id)).unwrap();
    let order: Vec<&str> = form.fields.iter().map(|f| f.name.as_str()).collect();
    assert_eq!(order, ORDER);
    assert!(
        form.fields.iter().all(|f| f.filled),
        "all 20 filled after reopening"
    );
    assert_eq!((form.required_left, form.problems), (0, 0));
    for (name, values) in &rest {
        assert_eq!(field(last.id, name).values, *values, "{name}");
    }
    block_on(engine().close(last.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn undo_redo_revert_clear_and_the_font_policy() {
    let (dir, path) = copy("history", FORM);
    let opened = open(&path);
    let doc = opened.id;
    let start = seen(doc, &opened.pages);
    set(doc, "adi", &["Mehmet"]);
    set(doc, "soyadi", &["Kaya"]);
    block_on(engine().undo(doc)).unwrap();
    assert!(field(doc, "soyadi").values.is_empty());
    block_on(engine().redo(doc)).unwrap();
    assert_eq!(field(doc, "soyadi").values, ["Kaya"]);
    let reverted = block_on(engine().revert(doc, 0, false, "Reverted".to_owned())).unwrap();
    assert!(reverted.reverted);
    assert!(field(doc, "adi").values.is_empty());
    assert_eq!(field(doc, "soyadi").values, ["Kaya"]);

    // Clear empties every field in one step; undo brings them back.
    set(doc, "adi", &["Mehmet"]);
    block_on(engine().clear_form(doc, None, "Clear".to_owned())).unwrap();
    assert!(fields(doc).iter().all(|f| f.values.is_empty()));
    block_on(engine().undo(doc)).unwrap();
    assert_eq!(field(doc, "adi").values, ["Mehmet"]);
    block_on(engine().revert_all(doc, "Reverted all".to_owned())).unwrap();
    assert_eq!(
        compare(&start, &seen(doc, &opened.pages), None, 0)
            .unwrap()
            .differing,
        0
    );

    // Ask each time writes nothing and asks; Keep marks the field.
    let handle = field(doc, "adi").handle;
    let steps = block_on(engine().history(doc)).unwrap().steps.len();
    let asked = block_on(engine().set_field_value(
        doc,
        handle,
        vec!["Ayşe".to_owned()],
        Some(MissingFont::Ask),
        "Fill".to_owned(),
    ))
    .unwrap();
    assert!(asked.asks_font);
    assert_eq!(block_on(engine().history(doc)).unwrap().steps.len(), steps);
    assert!(field(doc, "adi").values.is_empty());
    let kept = block_on(engine().set_field_value(
        doc,
        handle,
        vec!["Ayşe".to_owned()],
        Some(MissingFont::Keep),
        "Fill".to_owned(),
    ))
    .unwrap();
    assert!(kept.marked && kept.fonts.is_empty());
    assert_eq!(field(doc, "adi").values, ["Ayşe"]);

    // A read-only or unknown value is refused.
    let radio = field(doc, "cinsiyet").handle;
    let refused = block_on(engine().set_field_value(
        doc,
        radio,
        vec!["Belki".to_owned()],
        None,
        "Fill".to_owned(),
    ))
    .unwrap_err();
    assert_eq!(refused.kind, ErrorKind::InvalidInput);
    block_on(engine().close_discarding(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn finish_leaves_each_form_looking_the_same_with_no_widgets() {
    // Nothing filled: every widget of form-aks1-tr draws nothing, so the page is as it was.
    let (dir, path) = copy("finish", FORM);
    let opened = open(&path);
    let before = draw(opened.id, &opened.pages, 0);
    block_on(engine().finish_form(opened.id, None, "Finish".to_owned())).unwrap();
    assert!(fields(opened.id).is_empty());
    let diff = compare(&before, &draw(opened.id, &opened.pages, 0), None, 0).unwrap();
    assert_eq!(diff.differing, 0, "{diff:?}");
    block_on(engine().close_discarding(opened.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();

    // Filled forms: what the widgets show lands inside them, and the saved file reopens so.
    for name in [FORM, "form-lists-comb", "form-script"] {
        let (dir, path) = copy("finish", name);
        let opened = open(&path);
        let doc = opened.id;
        if name == FORM {
            set(doc, "adi", &["Ayşe"]);
            set(doc, "cinsiyet", &["Kadin"]);
        }
        let boxes: Vec<[f32; 4]> = fields(doc)
            .iter()
            .flat_map(|f| f.widgets.iter().map(|w| w.rect))
            .collect();
        let before = draw(doc, &opened.pages, 0);
        block_on(engine().finish_form(doc, None, "Finish".to_owned())).unwrap();
        assert!(fields(doc).is_empty(), "{name}");
        let after = draw(doc, &opened.pages, 0);
        let region = device_region(&boxes, f64::from(DPI) / 72.0);
        let diff = compare(&before, &after, region, 2).unwrap();
        assert!(diff.passed(), "{name}: {diff:?}");
        block_on(engine().save(doc, None)).unwrap();
        block_on(engine().close(doc)).unwrap();
        let again = open(&path);
        assert!(fields(again.id).is_empty(), "{name}");
        let diff = compare(&after, &draw(again.id, &again.pages, 0), None, 0).unwrap();
        assert_eq!(diff.differing, 0, "{name} reopened: {diff:?}");
        block_on(engine().close(again.id)).unwrap();
        std::fs::remove_dir_all(&dir).unwrap();
    }
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn other_forms_lists_combs_hybrid_xfa_and_no_appearances() {
    let (dir, path) = copy("lists", "form-lists-comb");
    let opened = open(&path);
    let doc = opened.id;
    let comb = field(doc, "posta_kodu");
    assert!(comb.comb && comb.max_len == Some(5));
    let languages = field(doc, "diller");
    assert!(languages.multi_select);
    assert_eq!(languages.values, ["English", "Français"]);
    let country = field(doc, "ulke");
    assert_eq!(country.values, ["TR"]);
    for (name, values) in [
        ("posta_kodu", vec!["34000"]),
        ("diller", vec!["Deutsch", "Español"]),
        ("ulke", vec!["DE"]),
        ("meslek", vec!["Öğretmen"]),
        ("sehir", vec!["Van"]),
    ] {
        let target = field(doc, name);
        let before = seen(doc, &opened.pages);
        set(doc, name, &values);
        assert_eq!(field(doc, name).values, values, "{name}");
        only_inside(&before, &seen(doc, &opened.pages), around(&target), name);
    }
    block_on(engine().close_discarding(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();

    let (dir, path) = copy("xfa", "form-hybrid-xfa");
    let opened = open(&path);
    let doc = opened.id;
    assert!(block_on(engine().form_fields(doc)).unwrap().has_xfa);
    let first = fields(doc)
        .into_iter()
        .find(|f| f.kind == FieldKind::Text)
        .unwrap();
    let commit = block_on(engine().set_field_value(
        doc,
        first.handle,
        vec!["Yeni".to_owned()],
        None,
        "Fill".to_owned(),
    ))
    .unwrap();
    assert!(commit.xfa_removed);
    assert!(!block_on(engine().form_fields(doc)).unwrap().has_xfa);
    block_on(engine().close_discarding(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();

    // No appearance anywhere: none is made by opening, and a change makes the field's own.
    let (dir, path) = copy("bare", "form-need-appearances");
    let original = std::fs::read(&path).unwrap();
    let opened = open(&path);
    let doc = opened.id;
    let list = fields(doc);
    assert!(list.iter().all(|f| !f.widgets.is_empty()));
    let radio = list.iter().find(|f| f.kind == FieldKind::Radio).unwrap();
    assert_eq!(radio.values, ["Kurumsal"]);
    let other = radio
        .widgets
        .iter()
        .filter_map(|w| w.on_state.clone())
        .find(|state| state != "Kurumsal")
        .unwrap();
    set(doc, "uyelik", &[&other]);
    assert_eq!(field(doc, "uyelik").values, [other]);
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    let saved = std::fs::read(&path).unwrap();
    assert_eq!(saved[..original.len()], original[..]);
    std::fs::remove_dir_all(&dir).unwrap();
}

/// Decision 18 at Finish: a value with no appearance ("Ayşe Yılmaz" in a WinAnsi /Helv) is drawn
/// as the font policy says, and the fonts it took are said.
#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn finish_follows_the_font_policy_and_says_so() {
    let (dir, path) = copy("finish-fonts", "form-need-appearances");
    let opened = open(&path);
    let doc = opened.id;
    let asked =
        block_on(engine().finish_form(doc, Some(MissingFont::Ask), "Finish".to_owned())).unwrap();
    assert!(asked.asks_font);
    assert!(block_on(engine().history(doc)).unwrap().steps.is_empty());
    assert!(!fields(doc).is_empty());
    let done = block_on(engine().finish_form(doc, Some(MissingFont::Bundled), "Finish".to_owned()))
        .unwrap();
    assert!(!done.asks_font);
    assert_eq!(done.fonts, ["IBM Plex Sans"]);
    assert!(fields(doc).is_empty());
    block_on(engine().close_discarding(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

/// Decision 17 on section 8's test form: setting the fields whose scripts would format, validate,
/// calculate or react on blur runs none of them, before or after saving.
#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn the_script_form_runs_nothing() {
    let (dir, path) = copy("script", "form-script");
    let opened = open(&path);
    assert!(
        opened.scripts.count > 0,
        "the scripts notice has something to say"
    );
    let doc = opened.id;
    let values = |doc| -> Vec<(String, Vec<String>)> {
        fields(doc)
            .into_iter()
            .map(|f| (f.name, f.values))
            .collect()
    };
    let start = values(doc);
    // Above the validate script's 50, no "TL " from its format, and the calculated fields set
    // to what their sums are not.
    let set_to = [
        ("birim_fiyat", "75,5"),
        ("adet", "3"),
        ("ara_toplam", "7"),
        ("toplam", "8"),
    ];
    for (name, value) in set_to {
        set(doc, name, &[value]);
    }
    let expected: Vec<(String, Vec<String>)> = start
        .iter()
        .map(|(name, before)| {
            let after = set_to
                .iter()
                .find(|(set, _)| set == name)
                .map_or_else(|| before.clone(), |(_, value)| vec![(*value).to_owned()]);
            (name.clone(), after)
        })
        .collect();
    assert_eq!(values(doc), expected);
    assert_eq!(field(doc, "durum").values, ["Bekliyor"]);
    block_on(engine().save(doc, None)).unwrap();
    block_on(engine().close(doc)).unwrap();
    let again = open(&path);
    assert_eq!(values(again.id), expected);
    block_on(engine().close(again.id)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn a_signed_form_asks_first_and_says_what_filling_does() {
    let opened = open(&corpus("form-signed"));
    let doc = opened.id;
    let list = fields(doc);
    let locked = list.iter().find(|f| f.kind == FieldKind::Text).unwrap();
    assert_eq!(
        block_on(engine().op_gate(doc, DocumentOp::Fill, vec![locked.name.clone()])).unwrap(),
        OpGate::BreaksSignatures
    );
    let refused = block_on(engine().set_field_value(
        doc,
        locked.handle,
        vec!["Yeni".to_owned()],
        None,
        "Fill".to_owned(),
    ))
    .unwrap_err();
    assert_eq!(refused.kind, ErrorKind::ConfirmationRequired);
    assert!(
        list.iter()
            .any(|f| f.kind == FieldKind::Signature && f.signed)
    );
    block_on(engine().close_discarding(doc)).unwrap();
}

struct Found(mpsc::Sender<SearchEvent>);

impl SearchSink for Found {
    fn deliver(&mut self, event: SearchEvent) -> bool {
        self.0.send(event).is_ok()
    }
}

fn search(
    doc: DocumentId,
    query: &str,
    places: SearchPlaces,
) -> Vec<ferman_api::facade::SearchMatch> {
    let (events, received) = mpsc::channel();
    engine()
        .search(
            doc,
            query.to_owned(),
            SearchOptions::default(),
            places,
            Box::new(Found(events)),
        )
        .unwrap();
    let mut found = Vec::new();
    for event in received {
        match event {
            SearchEvent::Matches(matches) => found.extend(matches),
            SearchEvent::Done { .. } => break,
            _ => {}
        }
    }
    found
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn search_finds_field_values_and_reads_columns_in_order() {
    let (dir, path) = copy("search", FORM);
    let opened = open(&path);
    let doc = opened.id;
    set(doc, "mahalle", &["Kızılay Mahallesi"]);
    let handle = field(doc, "mahalle").handle;
    let fields_too = SearchPlaces {
        fields: true,
        ..SearchPlaces::default()
    };
    assert!(search(doc, "kizilay", SearchPlaces::default()).is_empty());
    let found = search(doc, "kizilay", fields_too);
    assert_eq!(found.len(), 1);
    assert_eq!(found[0].field, Some(handle));
    assert_eq!(found[0].snippet, "Kızılay Mahallesi");
    block_on(engine().close_discarding(doc)).unwrap();
    std::fs::remove_dir_all(&dir).unwrap();

    // B163: two columns whose lines interleave in the content read column by column.
    let columns = open(&corpus("edit-e18-columns-standin"));
    let found = search(
        columns.id,
        "Kasım ayında yapılmasına",
        SearchPlaces::default(),
    );
    assert_eq!(found.len(), 1, "{found:?}");
    assert_eq!(found[0].rects.len(), 2, "over two lines of one column");
    block_on(engine().close(columns.id)).unwrap();
}

/// Decisions 20 and 21 on form-aks1-tr: a stamp with the private key naming `imza` fills the
/// required signature field, which stays without `/V`.
#[test]
fn a_simple_signature_fills_the_required_signature_field() {
    use ferman_core::forms::{FieldKind as Kind, SIGNED_FIELD_KEY};
    use ferman_core::revision::RevisionStore;
    use ferman_core::write::{Value, text_value};

    let bytes = std::fs::read(corpus(FORM)).unwrap();
    let doc = ferman_core::open(
        &ferman_core::Source::from_bytes(bytes.into()),
        &ferman_core::OpenOptions::default(),
    )
    .unwrap();
    let mut store = RevisionStore::new(&doc);
    let before = store.form_fields(&doc);
    let (required, left) = ferman_ops::forms::required_count(&before);
    assert_eq!((required, left), (15, 15));
    let signature = before
        .fields
        .iter()
        .find(|f| f.kind == Kind::Signature)
        .unwrap();
    assert_eq!(signature.name, "imza");
    let name = |n: &[u8]| Value::Name(n.to_vec());
    store.begin().unwrap();
    let stamp = store
        .add_object(
            &doc,
            Value::Dictionary(vec![
                (b"Type".to_vec(), name(b"Annot")),
                (b"Subtype".to_vec(), name(b"Stamp")),
                (
                    b"Rect".to_vec(),
                    Value::Array(signature.widgets[0].rect.map(Value::Real).to_vec()),
                ),
                (SIGNED_FIELD_KEY.to_vec(), text_value("imza")),
            ]),
        )
        .unwrap();
    store.append_annotation(&doc, 0, stamp).unwrap();
    store.commit().unwrap();
    let after = store.form_fields(&doc);
    let signed = after.fields.iter().find(|f| f.name == "imza").unwrap();
    assert_eq!(signed.signature, Some(stamp.handle()));
    assert!(signed.filled() && !signed.signed);
    assert_eq!(ferman_ops::forms::required_count(&after), (15, 14));
}
