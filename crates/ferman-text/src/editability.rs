//! Whether a block can be edited, and why not (docs/ARCHITECTURE.md §6.5, G39).
//!
//! The page model works out what the page content says: no text but images or shapes, glyphs
//! without a Unicode mapping, invisible text, operators it cannot rewrite safely and the limits of
//! section 9. What only the document or the caller knows (the author's permissions, a read-only or
//! damaged file, where the signature fields and form fields are) comes in through an
//! [`EditContext`].

use crate::extract::CharBox;

/// Whether a block can be edited.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub enum Editability {
    /// It can.
    #[default]
    Editable,
    /// It cannot, for this reason; the UI shows it in a tooltip and the panel (a3-11, a3-19).
    NotEditable(NotEditableReason),
}

impl Editability {
    /// Whether the block can be edited.
    #[must_use]
    pub fn is_editable(self) -> bool {
        self == Self::Editable
    }
}

/// Why text cannot be edited, as the table of docs/ARCHITECTURE.md §6.5 lists it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum NotEditableReason {
    /// The page has no text, only images: a scan (a3-11). Text recognition is P3.
    ImageOnly,
    /// The glyphs have no usable Unicode mapping (no ToUnicode entry, no glyph name).
    UnknownText,
    /// The text is drawn as vector shapes, not glyphs (a3-19): a page with paths and no text or
    /// images.
    OutlinedText,
    /// The text is invisible (`Tr` 3 or 7), such as the recognised text over a scan.
    InvisibleText,
    /// The author's permissions forbid changes until the owner password unlocks them (G27).
    Restricted,
    /// The file is read-only on disk (G28): Save as.
    ReadOnly,
    /// The document was repaired or its readers disagree (section 5.2): save a repaired copy.
    Damaged,
    /// The text is inside a signature field's area; signatures are never edited.
    SignatureAppearance,
    /// The text is inside an annotation or a form field: Comment or Fill & Sign mode.
    AnnotationOrField,
    /// The engine cannot rewrite it safely; the reason says why.
    TooComplex(Complexity),
}

/// What makes a block too complex to rewrite.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum Complexity {
    /// The page hit a resource limit (docs/ARCHITECTURE.md §9.1), so its text is incomplete.
    Limits,
    /// An operator's operands are split across two streams of the page's `/Contents`.
    SplitOperator,
    /// The text is sheared, so its glyph boxes are not rectangles.
    Skewed,
}

/// What the caller knows about the document and the page, in page space (points from the
/// top-left of the displayed page, y down).
#[derive(Debug, Clone, Default, PartialEq)]
pub struct EditContext {
    /// A reason that holds for the whole document: [`NotEditableReason::Restricted`],
    /// [`NotEditableReason::ReadOnly`] or [`NotEditableReason::Damaged`].
    pub document: Option<NotEditableReason>,
    /// The areas of the page's signature fields.
    pub signature_areas: Vec<CharBox>,
    /// The areas of the page's other form fields and annotations.
    pub field_areas: Vec<CharBox>,
}

/// Whether two boxes `[left, top, right, bottom]` overlap.
pub(crate) fn overlaps(a: CharBox, b: CharBox) -> bool {
    a[0] < b[2] && b[0] < a[2] && a[1] < b[3] && b[1] < a[3]
}
