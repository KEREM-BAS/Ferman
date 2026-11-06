//! The annotation reader (`ferman_core::annotations`) and the appearance generators
//! (`ferman_ops::annotations`) on what it reads: the input as a file, and as objects from 10 on under
//! a page whose `/Annots` is object 10. Huge arrays, cycles and deep `/IRT` chains stop at the limits;
//! a reply's thread is in the list; and changing or deleting what was read never panics.
#![no_main]

use std::collections::HashSet;

use ferman_core::limits::Limits;
use ferman_core::revision::RevisionStore;
use ferman_core::{OpenOptions, Source, open};
use ferman_ops::annotations::{AnnotationChange, delete, reply, set_resolved, update};
use libfuzzer_sys::fuzz_target;

const HEAD: &[u8] = b"%PDF-1.7\n\
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n\
2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n\
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Annots 10 0 R>>endobj\n";

/// The annotations changed per input: each writes a transaction.
const MOST_CHANGED: usize = 32;
const NOW: &str = "D:20261106120000Z";

fuzz_target!(|input: &[u8]| {
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
        let list = store.annotations(&document);
        let handles: HashSet<u64> = list.annotations.iter().map(|a| a.handle).collect();
        assert_eq!(handles.len(), list.annotations.len(), "identities repeat");
        for annotation in &list.annotations {
            assert!(annotation.page < store.pages(&document).len());
            assert!(annotation.opacity.is_finite());
            if let Some(parent) = annotation.replies_to {
                assert!(handles.contains(&parent), "a reply to nothing listed");
                assert!(handles.contains(&annotation.thread), "a thread not listed");
            }
        }
        for annotation in list.annotations.iter().take(MOST_CHANGED) {
            let handle = annotation.handle;
            let [left, bottom, right, top] = annotation.rect;
            let changes = [
                AnnotationChange {
                    color: Some([0.1, 0.2, 0.3]),
                    ..AnnotationChange::default()
                },
                AnnotationChange {
                    contents: Some("yeni".to_owned()),
                    ..AnnotationChange::default()
                },
                AnnotationChange {
                    rect: Some([left + 1.0, bottom, right + 9.0, top]),
                    ..AnnotationChange::default()
                },
            ];
            for change in &changes {
                let mut working = store.clone();
                if working.begin().is_ok() {
                    let _ = update(&document, &mut working, handle, change, NOW, None);
                    let _ = working.commit();
                    let _ = working.annotations(&document);
                }
            }
            let mut working = store.clone();
            if working.begin().is_ok() {
                let _ = reply(&document, &mut working, handle, "a", "b", NOW);
                let _ = set_resolved(&document, &mut working, handle, "a", true, NOW);
                let _ = delete(&document, &mut working, handle);
                let _ = working.commit();
                let _ = working.annotations(&document);
            }
        }
    }
});
