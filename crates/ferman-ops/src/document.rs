//! The document's own parts (M4 plan W6): its outline (a2-3a), its information (a2-7) and its
//! attached files (a2-3b). ferman-core writes each; nothing here needs planning yet.

use ferman_core::Document;
use ferman_core::attach::NewAttachment;
use ferman_core::metadata::InfoEdit;
use ferman_core::outline::OutlineEdit;
use ferman_core::revision::RevisionStore;

use crate::OpsError;

/// Makes `items` the outline.
///
/// # Errors
///
/// Those of [`RevisionStore::set_outline`].
pub fn set_outline(
    document: &Document,
    revisions: &mut RevisionStore,
    items: &[OutlineEdit],
) -> Result<(), OpsError> {
    Ok(revisions.set_outline(document, items)?)
}

/// Makes `info` the document information.
///
/// # Errors
///
/// Those of [`RevisionStore::set_info`].
pub fn set_info(
    document: &Document,
    revisions: &mut RevisionStore,
    info: &InfoEdit,
) -> Result<(), OpsError> {
    Ok(revisions.set_info(document, info)?)
}

/// Attaches `file`.
///
/// # Errors
///
/// Those of [`RevisionStore::attach_file`].
pub fn attach_file(
    document: &Document,
    revisions: &mut RevisionStore,
    file: NewAttachment,
) -> Result<(), OpsError> {
    Ok(revisions.attach_file(document, file)?)
}

/// Takes attachment `index` out.
///
/// # Errors
///
/// Those of [`RevisionStore::remove_attachment`].
pub fn remove_attachment(
    document: &Document,
    revisions: &mut RevisionStore,
    index: usize,
) -> Result<(), OpsError> {
    Ok(revisions.remove_attachment(document, index)?)
}
