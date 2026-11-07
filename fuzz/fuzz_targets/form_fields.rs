//! The form reader (`ferman_core::forms`), the literal `AF*` arguments of decision 17 and, on what
//! the reader finds, setting values, Clear and Finish (`ferman_ops::forms`): the input as a file,
//! as objects from 10 on under a form whose `/Fields` is object 10 and a page whose `/Annots` is
//! object 11, and as a script. Cyclic, deep and huge field trees stop at the limits; nothing runs.
#![no_main]

use std::collections::HashSet;
use std::sync::OnceLock;

use ferman_core::forms::read_script;
use ferman_core::limits::Limits;
use ferman_core::revision::RevisionStore;
use ferman_core::{OpenOptions, Source, open};
use ferman_fonts::{FontLibrary, FontOrigin};
use ferman_ops::forms::{MissingFont, clear, finish, problem, set_value};
use libfuzzer_sys::fuzz_target;

const HEAD: &[u8] = b"%PDF-1.7\n\
1 0 obj<</Type/Catalog/Pages 2 0 R/AcroForm<</Fields 10 0 R/DA(/Helv 0 Tf 0 g)>>>>endobj\n\
2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n\
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Annots 11 0 R>>endobj\n";

/// The fields changed per input: each writes a transaction.
const MOST_CHANGED: usize = 16;

/// A library with one bundled face, once for all inputs.
fn library() -> &'static FontLibrary {
    static LIBRARY: OnceLock<FontLibrary> = OnceLock::new();
    LIBRARY.get_or_init(|| {
        let mut library = FontLibrary::new();
        let face =
            include_bytes!("../../app/assets/fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf").to_vec();
        library
            .add_bytes(face, FontOrigin::Bundled)
            .expect("a bundled font");
        library
    })
}

fuzz_target!(|input: &[u8]| {
    let script = String::from_utf8_lossy(input);
    let declared = read_script(&script);
    if let (Some(min), Some(max)) = (declared.min, declared.max) {
        assert!(min.is_finite() && max.is_finite());
    }
    let mut wrapped = HEAD.to_vec();
    wrapped.extend_from_slice(input);
    wrapped.extend_from_slice(b"\ntrailer<</Root 1 0 R>>\n");
    for file in [input, &wrapped] {
        let mut limits = Limits::default();
        limits.max_stream_decoded = 1 << 20;
        limits.max_xref_sections = 64;
        let options = OpenOptions {
            password: None,
            limits,
        };
        let Ok(document) = open(&Source::from_bytes(file.into()), &options) else {
            continue;
        };
        let store = RevisionStore::new(&document);
        let list = store.form_fields(&document);
        let handles: HashSet<u64> = list.fields.iter().map(|f| f.handle).collect();
        assert_eq!(handles.len(), list.fields.len(), "identities repeat");
        for field in &list.fields {
            assert!(!field.widgets.is_empty());
            for widget in &field.widgets {
                assert!(widget.page < store.pages(&document).len());
            }
            let _ = problem(field, &script);
        }
        for field in list.fields.iter().take(MOST_CHANGED) {
            let value = field
                .options
                .first()
                .map(|option| option.export.clone())
                .or_else(|| {
                    let state = field.widgets.iter().find_map(|w| w.on_state.as_deref())?;
                    Some(String::from_utf8_lossy(state).into_owned())
                })
                .unwrap_or_else(|| "Yeni değer ıŞ".to_owned());
            let values = vec![value];
            for missing in [MissingFont::Bundled, MissingFont::Keep] {
                let mut working = store.clone();
                if working.begin().is_ok() {
                    let _ = set_value(
                        &document,
                        &mut working,
                        field.handle,
                        &values,
                        library(),
                        missing,
                    );
                    let _ = working.commit();
                    let _ = working.form_fields(&document);
                }
            }
        }
        for step in [clear, finish] {
            let mut working = store.clone();
            if working.begin().is_ok() {
                let _ = step(&document, &mut working, library());
                let _ = working.commit();
                let _ = working.form_fields(&document);
            }
        }
    }
});
