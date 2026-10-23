//! Resource limits for untrusted input (docs/ARCHITECTURE.md §9.1).
//!
//! Every bound on the work one document may cause lives in [`Limits`], so tests, the fuzz targets
//! and the CLI can tighten them. The defaults are the table of §9.1 (**Proposed**: the values are
//! reviewed with the M2 performance budgets).

use std::fmt;
use std::time::Duration;

/// One mebibyte.
const MIB: u64 = 1024 * 1024;

/// Bounds on the work one document may cause.
///
/// Built with [`Limits::default`] and tightened field by field:
///
/// ```
/// let mut limits = ferman_core::limits::Limits::default();
/// limits.max_stream_decoded = 1024 * 1024;
/// ```
#[derive(Debug, Clone, PartialEq, Eq)]
#[non_exhaustive]
pub struct Limits {
    /// Nesting of arrays and dictionaries. Default 256.
    pub max_nesting: u32,
    /// Depth of form XObject, Type3 and pattern recursion, on top of cycle detection. Default 32.
    pub max_recursion: u32,
    /// Nesting of `q` in a content stream. Default 256.
    pub max_q_nesting: u32,
    /// Operators interpreted on one page before it counts as too complex. Default 10 million.
    pub max_operators_per_page: u64,
    /// Decoded size of one stream, in bytes, against decompression bombs. Default 256 MiB.
    pub max_stream_decoded: u64,
    /// Decoded size of all streams of one revision, in bytes. Default 2 GiB, and never more than
    /// half of physical memory ([`Limits::capped_by_memory`]).
    pub max_revision_decoded: u64,
    /// Filters in one stream's filter chain. Default 8.
    pub max_filter_chain: u32,
    /// Cross-reference sections followed through `/Prev`, and object streams. Default 1,000.
    pub max_xref_sections: u32,
    /// Depth of CMap `usecmap` chains. Default 8.
    pub max_usecmap_depth: u32,
    /// Size of one embedded font program, in bytes. Default 64 MiB.
    pub max_font_program: u64,
    /// Pixels of one image that Ferman decodes itself. Default 2^28.
    pub max_image_pixels: u64,
    /// Interpretation time per page, checked cooperatively. Default 2 s.
    pub page_time: Duration,
}

impl Default for Limits {
    fn default() -> Self {
        Self {
            max_nesting: 256,
            max_recursion: 32,
            max_q_nesting: 256,
            max_operators_per_page: 10_000_000,
            max_stream_decoded: 256 * MIB,
            max_revision_decoded: 2048 * MIB,
            max_filter_chain: 8,
            max_xref_sections: 1_000,
            max_usecmap_depth: 8,
            max_font_program: 64 * MIB,
            max_image_pixels: 1 << 28,
            page_time: Duration::from_secs(2),
        }
    }
}

impl Limits {
    /// Lowers the per-revision decoded size to half of `physical_memory` bytes when that is less.
    #[must_use]
    pub fn capped_by_memory(mut self, physical_memory: u64) -> Self {
        self.max_revision_decoded = self.max_revision_decoded.min(physical_memory / 2);
        self
    }
}

/// Which limit of [`Limits`] stopped the work.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum LimitKind {
    /// [`Limits::max_nesting`].
    Nesting,
    /// [`Limits::max_recursion`].
    Recursion,
    /// [`Limits::max_q_nesting`].
    QNesting,
    /// [`Limits::max_operators_per_page`].
    OperatorsPerPage,
    /// [`Limits::max_stream_decoded`].
    StreamDecodedSize,
    /// [`Limits::max_revision_decoded`].
    RevisionDecodedSize,
    /// [`Limits::max_filter_chain`].
    FilterChain,
    /// [`Limits::max_xref_sections`].
    XrefSections,
    /// [`Limits::max_usecmap_depth`].
    UsecmapDepth,
    /// [`Limits::max_font_program`].
    FontProgramSize,
    /// [`Limits::max_image_pixels`].
    ImagePixels,
    /// [`Limits::page_time`].
    PageTime,
}

impl fmt::Display for LimitKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Self::Nesting => "nesting of arrays and dictionaries",
            Self::Recursion => "XObject, Type3 and pattern recursion",
            Self::QNesting => "q nesting",
            Self::OperatorsPerPage => "operators per page",
            Self::StreamDecodedSize => "decoded size per stream",
            Self::RevisionDecodedSize => "decoded size per revision",
            Self::FilterChain => "filter chain length",
            Self::XrefSections => "cross-reference sections",
            Self::UsecmapDepth => "usecmap depth",
            Self::FontProgramSize => "font program size",
            Self::ImagePixels => "image pixels",
            Self::PageTime => "interpretation time per page",
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_are_the_architecture_table() {
        let limits = Limits::default();
        assert_eq!(limits.max_nesting, 256);
        assert_eq!(limits.max_recursion, 32);
        assert_eq!(limits.max_q_nesting, 256);
        assert_eq!(limits.max_operators_per_page, 10_000_000);
        assert_eq!(limits.max_stream_decoded, 256 * 1024 * 1024);
        assert_eq!(limits.max_revision_decoded, 2 * 1024 * 1024 * 1024);
        assert_eq!(limits.max_filter_chain, 8);
        assert_eq!(limits.max_xref_sections, 1_000);
        assert_eq!(limits.max_usecmap_depth, 8);
        assert_eq!(limits.max_font_program, 64 * 1024 * 1024);
        assert_eq!(limits.max_image_pixels, 268_435_456);
        assert_eq!(limits.page_time, Duration::from_secs(2));
    }

    #[test]
    fn memory_caps_the_revision_size_at_half() {
        let small = Limits::default().capped_by_memory(1024 * MIB);
        assert_eq!(small.max_revision_decoded, 512 * MIB);
        let large = Limits::default().capped_by_memory(64 * 1024 * MIB);
        assert_eq!(large.max_revision_decoded, 2048 * MIB);
    }

    #[test]
    fn limit_names_read_as_text() {
        assert_eq!(
            LimitKind::StreamDecodedSize.to_string(),
            "decoded size per stream"
        );
    }
}
