//! Every corpus file opens, or fails, as its README row says (ROADMAP §6 step 2): healthy files
//! fully, `kira-tr-damaged` repaired, `truncated` not at all, the payslips with their passwords,
//! `kira-tr-restricted` with its restrictions until its owner password.
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::path::PathBuf;

use ferman_core::security::Method;
use ferman_core::structure::{Direction, FontKind};
use ferman_core::{
    Access, CoreError, Document, LikelyCause, OpenOptions, Password, Repair, Source, XrefProblem,
    open,
};

fn path(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/corpus/generated")
        .join(format!("{name}.pdf"))
}

fn source(name: &str) -> Option<Source> {
    let path = path(name);
    // Files over 1 MB are not committed; `tools/corpus generate` makes them.
    path.exists().then(|| Source::read(&path).unwrap())
}

fn open_with(name: &str, password: Option<&str>) -> Result<Document, CoreError> {
    let source = source(name).unwrap_or_else(|| panic!("{name} is missing"));
    let options = OpenOptions {
        password: password.map(|password| Password::new(password.to_owned())),
        ..OpenOptions::default()
    };
    open(&source, &options)
}

fn healthy(name: &str, pages: usize) -> Document {
    let document = open_with(name, None).unwrap_or_else(|err| panic!("{name}: {err}"));
    assert_eq!(document.page_count(), pages, "{name}");
    assert!(
        document.repair().is_none(),
        "{name}: {:?}",
        document.repair()
    );
    document
}

#[test]
fn healthy_files_open_fully() {
    for (name, pages) in [
        ("kira-tr", 3),
        ("nda-en", 4),
        ("mietvertrag-de", 6),
        ("report-ar", 12),
        ("letter-ja-vertical", 1),
        ("scan-tr", 3),
        ("quote-ja-scan", 2),
        ("form-aks1-flat", 1),
        ("form-aks1-tr", 1),
        ("js-openaction", 1),
        ("ocg-plan", 1),
        ("xfa-visa", 1),
        ("tez-tr", 64),
        // lopdf requires /Type /Page, so the page without it is not one (G102).
        ("disagree-pages", 2),
    ] {
        let document = healthy(name, pages);
        assert!(document.encryption().is_none(), "{name}");
        assert_eq!(document.access(), Access::Owner);
    }
}

#[test]
fn large_generated_files_open_when_present() {
    for (name, pages) in [("long-500", 500), ("imar-2400", 2400)] {
        if source(name).is_some() {
            healthy(name, pages);
        }
    }
}

#[test]
fn the_damaged_copy_is_repaired_with_its_fixes_listed() {
    let document = open_with("kira-tr-damaged", None).unwrap();
    assert_eq!(document.page_count(), 3);
    let report = document.repair().expect("a repair report");
    match report.repairs.first() {
        Some(Repair::CrossReferenceRebuilt { objects, problem }) => {
            assert!(*objects > 3, "{objects} objects");
            assert!(
                matches!(problem, XrefProblem::WrongOffset { .. }),
                "{problem:?}"
            );
        }
        other => panic!("{other:?}"),
    }
    assert!(
        !report
            .repairs
            .iter()
            .any(|repair| matches!(repair, Repair::ObjectsUnreadable { .. })),
        "{report:?}"
    );
    // Page 3's Times New Roman is named, not embedded.
    let times: Vec<_> = document
        .structure()
        .fonts
        .iter()
        .filter(|font| font.name.starts_with("TimesNewRomanPS"))
        .collect();
    assert_eq!(times.len(), 2, "{:?}", document.structure().fonts);
    for font in times {
        assert!(!font.embedded);
        assert_eq!(font.pages, [2]);
        assert_eq!(font.kind, FontKind::TrueType);
    }
}

#[test]
fn the_truncated_scan_cannot_be_opened() {
    match open_with("truncated", None) {
        Err(CoreError::Damaged(diagnosis)) => {
            assert_eq!(diagnosis.likely_cause, LikelyCause::Truncated);
            assert_eq!(diagnosis.file_size, 18 * 1024);
            assert_eq!(diagnosis.last_complete_object, Some((12, 0)));
            assert!(!diagnosis.has_trailer);
            assert_eq!(diagnosis.objects_found, 12);
        }
        other => panic!("{other:?}"),
    }
}

#[test]
fn payslips_need_their_password() {
    for (name, password, method, revision) in [
        ("payslip-rc4-40", "bordro2026", Method::Rc4 { bits: 40 }, 2),
        (
            "payslip-rc4-128",
            "bordro2026",
            Method::Rc4 { bits: 128 },
            3,
        ),
        ("payslip-aes128", "bordro2026", Method::Aes128, 4),
        ("payslip-aes256", "Eylül2026maaşı", Method::Aes256, 6),
    ] {
        assert!(
            matches!(open_with(name, None), Err(CoreError::PasswordRequired)),
            "{name}"
        );
        assert!(
            matches!(
                open_with(name, Some("eylul2026")),
                Err(CoreError::WrongPassword)
            ),
            "{name}"
        );
        let document =
            open_with(name, Some(password)).unwrap_or_else(|err| panic!("{name}: {err}"));
        assert_eq!(document.page_count(), 1, "{name}");
        assert!(
            document.repair().is_none(),
            "{name}: {:?}",
            document.repair()
        );
        let encryption = document.encryption().unwrap();
        assert_eq!(encryption.method, method, "{name}");
        assert_eq!(encryption.revision, revision, "{name}");
        assert!(encryption.user_password_required);
        assert_eq!(document.access(), Access::User);
        // The information dictionary's strings decrypt to the generator's text.
        let structure = document.structure();
        assert_eq!(
            structure.info.title.as_deref(),
            Some("Maaş bordrosu Eylül 2026"),
            "{name}"
        );
        assert_eq!(structure.language.as_deref(), Some("tr-TR"), "{name}");
        // The owner password opens it with owner access.
        let owner = open_with(name, Some("bordro-yonetim-2026")).unwrap();
        assert_eq!(owner.access(), Access::Owner, "{name}");
    }
}

#[test]
fn the_restricted_contract_opens_with_its_restrictions() {
    let mut document = open_with("kira-tr-restricted", None).unwrap();
    assert_eq!(document.page_count(), 3);
    let encryption = *document.encryption().unwrap();
    assert!(!encryption.user_password_required);
    assert_eq!(encryption.method, Method::Aes128);
    assert_eq!(document.access(), Access::User);
    let permissions = document.permissions();
    assert!(permissions.print() && permissions.extract_for_accessibility());
    assert!(!permissions.modify() && !permissions.copy());
    assert!(!permissions.annotate() && !permissions.fill_forms());
    // A wrong owner password changes nothing; the right one lifts the restrictions.
    assert!(
        !document
            .unlock_owner(&Password::new("kaya".to_owned()))
            .unwrap()
    );
    assert_eq!(document.access(), Access::User);
    assert!(
        document
            .unlock_owner(&Password::new("Kaya-Moda-18".to_owned()))
            .unwrap()
    );
    assert_eq!(document.access(), Access::Owner);
    assert!(document.permissions().all());
}

#[test]
fn the_structure_scan_finds_what_the_generators_wrote() {
    let tez = healthy("tez-tr", 64);
    let labels: Vec<String> = tez
        .structure()
        .pages
        .iter()
        .map(|page| page.label.clone().unwrap_or_default())
        .collect();
    assert_eq!(labels[0], "i");
    assert_eq!(labels[7], "viii");
    assert_eq!(labels[8], "1");
    assert_eq!(labels[63], "56");
    assert!(!tez.structure().outline.is_empty());
    assert!(
        tez.structure()
            .outline
            .iter()
            .any(|chapter| !chapter.children.is_empty())
    );
    assert!(
        tez.structure()
            .outline
            .iter()
            .all(|item| item.page.is_some())
    );

    let report = healthy("report-ar", 12);
    assert_eq!(report.structure().direction, Direction::RightToLeft);

    let plan = healthy("ocg-plan", 1);
    let layers = &plan.structure().layers;
    assert_eq!(layers.len(), 6, "{layers:?}");
    let pipes = layers.iter().find(|layer| layer.name == "Tesisat").unwrap();
    assert!(!pipes.visible);

    let visa = healthy("xfa-visa", 1);
    assert!(visa.structure().forms.xfa_only);

    let form = healthy("form-aks1-tr", 1);
    assert_eq!(form.structure().forms.fields, 20);
    assert!(!form.structure().forms.has_xfa);
    assert_eq!(form.structure().signatures.len(), 1);
    assert!(!form.structure().signatures[0].signed);
    assert!(form.structure().scripts.count > 0);

    let script = healthy("js-openaction", 1);
    let scripts = script.structure().scripts;
    assert_eq!((scripts.document, scripts.pages), (2, 1), "{scripts:?}");

    let kira = healthy("kira-tr", 3);
    assert!(kira.structure().fonts.iter().all(|font| font.embedded));
    assert!(kira.structure().scripts.count == 0);
}
