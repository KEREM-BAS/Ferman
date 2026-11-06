//! Combine, Extract, Insert and Replace above ferman-core's assembler: a new file put together
//! from pages ([`Assembly`]), or pages of another document brought into an open one.

use ferman_core::assemble::{ImportOptions, PageImport, add_bookmark, new_document};
use ferman_core::limits::Limits;
use ferman_core::pages::PageSlot;
use ferman_core::revision::RevisionStore;
use ferman_core::write::ObjectRef;
use ferman_core::{CoreError, Document, WriteError};

use crate::OpsError;
use crate::images::{Image, Paper, image_page};
use crate::pages::checked_side;

/// Copies `pages` of `source` into the open transaction of `revisions`, calling `step` before each.
/// The first ones take over the objects of `replacing`; the others are new, for the caller to place.
///
/// # Errors
///
/// What `step` returns, and those of [`PageImport`], as [`OpsError::Core`].
#[allow(clippy::too_many_arguments)]
pub fn copy_pages<E: From<OpsError>>(
    document: &Document,
    revisions: &mut RevisionStore,
    source: &Document,
    source_revisions: &RevisionStore,
    pages: &[usize],
    options: ImportOptions,
    bookmark: Option<&str>,
    replacing: &[ObjectRef],
    step: &mut impl FnMut() -> Result<(), E>,
) -> Result<Vec<ObjectRef>, E> {
    let core = |err: CoreError| E::from(err.into());
    let mut import = PageImport::new(source, source_revisions, pages, options).map_err(core)?;
    let targets = import.start(revisions, replacing).map_err(core)?;
    for position in 0..import.page_count() {
        step()?;
        import
            .copy_page(document, revisions, position)
            .map_err(core)?;
    }
    import.finish(document, revisions, bookmark).map_err(core)?;
    Ok(targets)
}

/// Places `new` pages after the page `after`, or first when `None`.
///
/// # Errors
///
/// [`WriteError::NoSuchPage`] and those of [`RevisionStore::arrange_pages`], as
/// [`OpsError::Core`].
pub fn place_after(
    document: &Document,
    revisions: &mut RevisionStore,
    new: &[ObjectRef],
    after: Option<usize>,
) -> Result<(), OpsError> {
    let count = revisions.pages(document).len();
    let at = match after {
        Some(after) if after >= count => {
            return Err(CoreError::Write(WriteError::NoSuchPage).into());
        }
        Some(after) => after.saturating_add(1),
        None => 0,
    };
    let order: Vec<PageSlot> = (0..at)
        .map(PageSlot::Page)
        .chain(new.iter().copied().map(PageSlot::New))
        .chain((at..count).map(PageSlot::Page))
        .collect();
    Ok(revisions.arrange_pages(document, &order)?)
}

/// The page order after `replaced` (indices, in document order) gave their objects to the first of
/// `new`: fewer new pages delete the replaced pages left over, more go after the last replaced one.
///
/// # Errors
///
/// Those of [`RevisionStore::arrange_pages`], as [`OpsError::Core`].
pub fn place_replacing(
    document: &Document,
    revisions: &mut RevisionStore,
    replaced: &[usize],
    new: &[ObjectRef],
) -> Result<(), OpsError> {
    let count = revisions.pages(document).len();
    let mut order = Vec::with_capacity(count.saturating_add(new.len()));
    for index in 0..count {
        match replaced.iter().position(|page| *page == index) {
            Some(position) if position >= new.len() => {}
            _ => order.push(PageSlot::Page(index)),
        }
        if replaced.last() == Some(&index) {
            order.extend(new.iter().skip(replaced.len()).copied().map(PageSlot::New));
        }
    }
    Ok(revisions.arrange_pages(document, &order)?)
}

/// A new file on its way, unencrypted, with no signature (question 6 of the M4 plan).
pub struct Assembly {
    document: Document,
    revisions: RevisionStore,
    order: Vec<PageSlot>,
}

impl Assembly {
    /// Starts one.
    ///
    /// # Errors
    ///
    /// [`CoreError::Internal`], as [`OpsError::Core`], if its first document cannot be made.
    pub fn new(limits: &Limits) -> Result<Self, OpsError> {
        let document = new_document(limits)?;
        let mut revisions = RevisionStore::new(&document);
        revisions.begin()?;
        Ok(Self {
            document,
            revisions,
            order: Vec::new(),
        })
    }

    /// Adds `pages` of `source`, calling `step` before each, under a bookmark `bookmark` when given.
    ///
    /// # Errors
    ///
    /// As [`copy_pages`].
    pub fn add_pages<E: From<OpsError>>(
        &mut self,
        source: &Document,
        source_revisions: &RevisionStore,
        pages: &[usize],
        options: ImportOptions,
        bookmark: Option<&str>,
        step: &mut impl FnMut() -> Result<(), E>,
    ) -> Result<(), E> {
        let targets = copy_pages(
            &self.document,
            &mut self.revisions,
            source,
            source_revisions,
            pages,
            options,
            bookmark,
            &[],
            step,
        )?;
        self.order.extend(targets.into_iter().map(PageSlot::New));
        Ok(())
    }

    /// Adds a page of `paper` with `image` scaled to fit (G152).
    ///
    /// # Errors
    ///
    /// Those of [`image_page`] and of a bookmark.
    pub fn add_image(
        &mut self,
        image: &Image,
        paper: Paper,
        bookmark: Option<&str>,
    ) -> Result<(), OpsError> {
        let page = image_page(&self.document, &mut self.revisions, image, paper)?;
        self.add_page(page, bookmark)
    }

    /// Adds a blank page of `width` by `height` points, which is what Create PDF starts from.
    ///
    /// # Errors
    ///
    /// [`WriteError::PagePlan`] for a size out of range, as [`OpsError::Core`].
    pub fn add_blank(
        &mut self,
        (width, height): (f32, f32),
        bookmark: Option<&str>,
    ) -> Result<(), OpsError> {
        let (width, height) = (checked_side(width)?, checked_side(height)?);
        let page = self.revisions.blank_page(&self.document, width, height)?;
        self.add_page(page, bookmark)
    }

    fn add_page(&mut self, page: ObjectRef, bookmark: Option<&str>) -> Result<(), OpsError> {
        if let Some(title) = bookmark {
            add_bookmark(&self.document, &mut self.revisions, title, page)?;
        }
        self.order.push(PageSlot::New(page));
        Ok(())
    }

    /// The file's bytes.
    ///
    /// # Errors
    ///
    /// [`WriteError::PagePlan`] with no page added, and those of the full rewrite, as
    /// [`OpsError::Core`].
    pub fn finish(mut self) -> Result<Vec<u8>, OpsError> {
        self.revisions.arrange_pages(&self.document, &self.order)?;
        self.revisions.commit()?;
        Ok(self.revisions.full_rewrite(&self.document)?)
    }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::path::PathBuf;

    use ferman_core::{OpenOptions, Source, open};

    use super::*;

    const ALL: ImportOptions = ImportOptions {
        keep_forms: true,
        document_parts: true,
    };

    fn corpus(name: &str) -> Document {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(format!("{name}.pdf"));
        open(&Source::read(&path).unwrap(), &OpenOptions::default()).unwrap()
    }

    fn no_step() -> impl FnMut() -> Result<(), OpsError> {
        || Ok(())
    }

    /// `replaced` of pages-tree given to `count` pages of combine-outline: the page numbers left.
    fn replace(replaced: &[usize], count: usize) -> (usize, Vec<u64>, Vec<u64>) {
        let document = corpus("pages-tree");
        let source = corpus("combine-outline");
        let source_revisions = RevisionStore::new(&source);
        let mut revisions = RevisionStore::new(&document);
        let before: Vec<u64> = revisions
            .pages(&document)
            .iter()
            .map(|p| p.handle())
            .collect();
        revisions.begin().unwrap();
        let refs = revisions.page_refs(&document, replaced).unwrap();
        let pages: Vec<usize> = (0..count).collect();
        let new = copy_pages(
            &document,
            &mut revisions,
            &source,
            &source_revisions,
            &pages,
            ALL,
            None,
            &refs,
            &mut no_step(),
        )
        .unwrap();
        place_replacing(&document, &mut revisions, replaced, &new).unwrap();
        revisions.commit().unwrap();
        let after: Vec<u64> = revisions
            .pages(&document)
            .iter()
            .map(|p| p.handle())
            .collect();
        (before.len(), before, after)
    }

    #[test]
    fn replacing_as_many_pages_keeps_their_handles_and_order() {
        let (_, before, after) = replace(&[1, 2], 2);
        assert_eq!(before, after);
    }

    #[test]
    fn replacing_with_fewer_deletes_what_is_left_and_with_more_adds_after_the_last() {
        let (count, before, after) = replace(&[1, 2], 1);
        assert_eq!(after.len(), count - 1);
        assert_eq!(after[1], before[1]);
        assert_eq!(after[2], before[3]);

        let (count, before, after) = replace(&[1], 2);
        assert_eq!(after.len(), count + 1);
        assert_eq!(after[1], before[1]);
        assert_eq!(after[3], before[2]);
    }

    #[test]
    fn a_replaced_page_shows_as_its_source_under_a_node_that_rotates_or_crops() {
        let document = corpus("pages-tree");
        let source = corpus("combine-outline");
        let source_revisions = RevisionStore::new(&source);
        let wanted = &source_revisions.pages(&source)[0];
        for replaced in [0, 3] {
            let mut revisions = RevisionStore::new(&document);
            revisions.begin().unwrap();
            let refs = revisions.page_refs(&document, &[replaced]).unwrap();
            let new = copy_pages(
                &document,
                &mut revisions,
                &source,
                &source_revisions,
                &[0],
                ALL,
                None,
                &refs,
                &mut no_step(),
            )
            .unwrap();
            place_replacing(&document, &mut revisions, &[replaced], &new).unwrap();
            revisions.commit().unwrap();
            let page = &revisions.pages(&document)[replaced];
            assert_eq!(page.rotation, wanted.rotation, "page {replaced}");
            assert_eq!(page.size, wanted.size, "page {replaced}");
        }
    }

    #[test]
    fn an_insert_goes_after_its_page_and_first_without_one() {
        let document = corpus("pages-tree");
        let source = corpus("combine-outline");
        let source_revisions = RevisionStore::new(&source);
        for (after, at) in [(Some(0), 1), (None, 0)] {
            let mut revisions = RevisionStore::new(&document);
            let before = revisions.pages(&document).len();
            revisions.begin().unwrap();
            let new = copy_pages(
                &document,
                &mut revisions,
                &source,
                &source_revisions,
                &[0, 1],
                ALL,
                Some("Annex"),
                &[],
                &mut no_step(),
            )
            .unwrap();
            place_after(&document, &mut revisions, &new, after).unwrap();
            revisions.commit().unwrap();
            assert_eq!(revisions.pages(&document).len(), before + 2);
            let outline = revisions.outline(&document);
            let annex = outline.iter().find(|item| item.title == "Annex").unwrap();
            assert_eq!(annex.page, Some(at));
        }
    }

    #[test]
    fn an_assembly_with_no_page_is_refused() {
        let assembly = Assembly::new(&Limits::default()).unwrap();
        assert!(assembly.finish().is_err());
    }

    #[test]
    fn a_step_that_fails_stops_the_copy() {
        let source = corpus("combine-outline");
        let source_revisions = RevisionStore::new(&source);
        let mut assembly = Assembly::new(&Limits::default()).unwrap();
        let result =
            assembly.add_pages(&source, &source_revisions, &[0, 1], ALL, None, &mut || {
                Err(OpsError::UnreadableImage)
            });
        assert!(matches!(result, Err(OpsError::UnreadableImage)));
    }

    #[test]
    fn a_blank_and_an_extract_read_back() {
        let source = corpus("combine-outline");
        let source_revisions = RevisionStore::new(&source);
        let mut assembly = Assembly::new(&Limits::default()).unwrap();
        assembly.add_blank((100.0, 200.0), Some("Blank")).unwrap();
        assembly
            .add_pages(
                &source,
                &source_revisions,
                &[1],
                ImportOptions {
                    keep_forms: true,
                    document_parts: false,
                },
                None,
                &mut no_step(),
            )
            .unwrap();
        let bytes = assembly.finish().unwrap();
        let out = open(&Source::from_bytes(bytes.into()), &OpenOptions::default()).unwrap();
        assert_eq!(out.page_count(), 2);
        assert_eq!(out.structure().pages[0].size, (100.0, 200.0));
        assert_eq!(out.structure().outline[0].title, "Blank");
    }
}
