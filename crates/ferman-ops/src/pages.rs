//! Page operations: what each one writes, inside the open transaction of a document's
//! [`RevisionStore`].

use ferman_core::revision::RevisionStore;
use ferman_core::write::Value;
use ferman_core::{CoreError, Document, WriteError};

use crate::OpsError;

/// Turns page `index` clockwise by `quarter_turns` quarter turns, counter-clockwise when negative,
/// through `/Rotate` in its own dictionary; a page that ends where it was changes nothing.
///
/// # Errors
///
/// [`WriteError::NoSuchPage`] and [`WriteError::NoTransaction`], as [`OpsError::Core`].
pub fn rotate(
    document: &Document,
    revisions: &mut RevisionStore,
    index: usize,
    quarter_turns: i32,
) -> Result<(), OpsError> {
    let page = revisions
        .pages(document)
        .get(index)
        .ok_or(CoreError::Write(WriteError::NoSuchPage))?;
    let before = i64::from(page.rotation);
    let after = (before + i64::from(quarter_turns) * 90).rem_euclid(360);
    if after != before {
        revisions.set_page_entry(document, index, b"Rotate", Value::Integer(after))?;
    }
    Ok(())
}

#[cfg(test)]
#[allow(clippy::indexing_slicing)]
mod tests {
    use std::path::PathBuf;

    use ferman_core::{OpenOptions, Source, open};

    use super::*;

    fn kira() -> Document {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated/kira-tr.pdf");
        open(&Source::read(&path).unwrap(), &OpenOptions::default()).unwrap()
    }

    #[test]
    fn a_turn_goes_through_rotate_and_comes_back_with_undo() {
        let doc = kira();
        let mut store = RevisionStore::new(&doc);
        let (width, height) = store.pages(&doc)[1].size;
        store.begin().unwrap();
        rotate(&doc, &mut store, 1, 1).unwrap();
        store.commit().unwrap();
        assert_eq!(store.pages(&doc)[1].rotation, 90);
        assert_eq!(store.pages(&doc)[1].size, (height, width));
        assert_eq!(store.pages(&doc)[0].rotation, 0);
        store.begin().unwrap();
        rotate(&doc, &mut store, 1, -3).unwrap();
        assert_eq!(store.pages(&doc)[1].rotation, 180);
        store.commit().unwrap();
        store.undo().unwrap();
        store.undo().unwrap();
        assert_eq!(store.pages(&doc)[1].rotation, 0);
        assert_eq!(store.pages(&doc)[1].size, (width, height));

        // The saved update carries it.
        store.redo().unwrap();
        let saved = store.incremental_update(&doc).unwrap();
        let again = open(&Source::from_bytes(saved.into()), &OpenOptions::default()).unwrap();
        assert_eq!(again.structure().pages[1].rotation, 90);
    }

    #[test]
    fn four_turns_write_nothing_and_a_missing_page_is_refused() {
        let doc = kira();
        let mut store = RevisionStore::new(&doc);
        store.begin().unwrap();
        rotate(&doc, &mut store, 0, 4).unwrap();
        assert_eq!(store.commit().unwrap(), 0);
        store.begin().unwrap();
        assert!(matches!(
            rotate(&doc, &mut store, 9, 1),
            Err(OpsError::Core(CoreError::Write(WriteError::NoSuchPage)))
        ));
    }
}
