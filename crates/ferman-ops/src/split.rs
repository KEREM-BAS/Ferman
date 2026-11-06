//! Split planning (a6-2, G142): which pages each file holds, what it is called and about how large
//! it comes out, before anything is written.

use std::collections::BTreeSet;

use ferman_core::assemble::{ImportOptions, PageImport, assembled_size};
use ferman_core::revision::RevisionStore;
use ferman_core::{CoreError, Document, WriteError};

use crate::OpsError;

/// What Split keeps of a document: form fields, but not what belongs to no page.
const PAGES_ONLY: ImportOptions = ImportOptions {
    keep_forms: true,
    document_parts: false,
};

/// The longest file name before its extension, in bytes: file systems stop at 255.
const LONGEST_STEM: usize = 200;

/// The share of a page's pixels, 1 in this many, that may be marks and still count as blank:
/// a scanned blank page has dust.
const DUST: usize = 1000;

/// A pixel with every channel at this or above counts as white.
const WHITE: u8 = 250;

/// The four ways a6-2 draws.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SplitMode {
    /// A new file every so many pages.
    EveryPages(u32),
    /// One file per top-level bookmark; the pages before the first are a file of their own.
    TopBookmarks,
    /// Files of at most so many bytes; a single page over that is a file of its own.
    Size(u64),
    /// A new file at each blank page, which goes.
    BlankPages,
}

/// One file of a plan.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SplitFile {
    /// Its name, with `.pdf`, safe in any folder.
    pub name: String,
    /// Its first page, as an index.
    pub first: usize,
    /// Its last page, as an index.
    pub last: usize,
    /// The most it comes to, in bytes: stream data with no filter counts as stored, though the
    /// file compresses it.
    pub bytes: u64,
    /// Whether it is one page that alone is over the size asked for.
    pub over_limit: bool,
}

/// What a plan found.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SplitPlan {
    /// The files, in page order.
    pub files: Vec<SplitFile>,
    /// How many top-level bookmarks go to a page ("6 bookmarks found").
    pub bookmarks: u32,
    /// How many pages count as blank, which [`SplitMode::BlankPages`] leaves out.
    pub blank_pages: u32,
}

/// What names the files.
#[derive(Debug, Clone, Copy)]
pub struct Naming<'a> {
    /// The document's name, without its extension.
    pub document: &'a str,
    /// The template, with `{document}`, `{bookmark}` and `{n}`. With no bookmark to fill it,
    /// as for the pages before the first, `{bookmark}` becomes the file's page labels.
    pub template: &'a str,
}

/// Whether a raster of a page shows nothing but white and a little dust. `pixels` is 8-bit BGRA,
/// `width × 4` bytes per row.
#[must_use]
pub fn is_blank(pixels: &[u8]) -> bool {
    let (rows, _) = pixels.as_chunks::<4>();
    let marks = rows
        .iter()
        .filter(|pixel| pixel.iter().take(3).any(|channel| *channel < WHITE))
        .count();
    marks <= rows.len() / DUST
}

/// One file's pages and what fills `{bookmark}`.
type Span = (usize, usize, Option<String>);

/// A span every `count` pages of `pages`.
fn every(pages: usize, count: u32) -> Vec<Span> {
    let count = usize::try_from(count).unwrap_or(usize::MAX).max(1);
    (0..pages)
        .step_by(count)
        .map(|first| {
            let last = first.saturating_add(count - 1).min(pages - 1);
            (first, last, None)
        })
        .collect()
}

/// One span per top-level bookmark, in page order; of two on one page the first names it.
fn at_bookmarks(document: &Document, revisions: &RevisionStore, pages: usize) -> Vec<Span> {
    let mut starts: Vec<(usize, String)> = revisions
        .outline(document)
        .iter()
        .filter_map(|item| {
            let page = usize::try_from(item.page?).ok()?;
            (page < pages).then(|| (page, item.title.clone()))
        })
        .collect();
    starts.sort_by_key(|(page, _)| *page);
    starts.dedup_by_key(|(page, _)| *page);
    let mut spans = Vec::with_capacity(starts.len() + 1);
    match starts.first() {
        Some((first, _)) if *first > 0 => spans.push((0, first - 1, None)),
        None if pages > 0 => spans.push((0, pages - 1, None)),
        _ => {}
    }
    for (index, (first, title)) in starts.iter().enumerate() {
        let last = starts
            .get(index + 1)
            .map_or(pages - 1, |(next, _)| next - 1);
        spans.push((*first, last, Some(title.clone())));
    }
    spans
}

/// The runs of pages between the blank ones.
fn between_blanks(pages: usize, blank: &[usize]) -> Vec<Span> {
    let blank: BTreeSet<usize> = blank.iter().copied().collect();
    let mut spans = Vec::new();
    let mut first = None;
    for page in 0..pages {
        if blank.contains(&page) {
            if let Some(first) = first.take() {
                spans.push((first, page - 1, None));
            }
        } else {
            first = first.or(Some(page));
        }
    }
    if let Some(first) = first {
        spans.push((first, pages - 1, None));
    }
    spans
}

/// What the file of the pages `first..=last` comes to.
fn file_bytes(
    document: &Document,
    revisions: &RevisionStore,
    first: usize,
    last: usize,
) -> Result<u64, OpsError> {
    let pages: Vec<usize> = (first..=last).collect();
    Ok(assembled_size(document, revisions, &pages, PAGES_ONLY)?)
}

/// Spans as large as `limit` allows. Weights leave out what a whole file adds, so they say how far
/// a file can reach, and what it really comes to takes pages back off.
fn by_size(
    weighing: &mut PageImport<'_>,
    document: &Document,
    revisions: &RevisionStore,
    pages: usize,
    limit: u64,
) -> Result<Vec<Span>, OpsError> {
    let mut spans = Vec::new();
    let mut first = 0;
    while first < pages {
        weighing.reset_weights();
        let mut bytes = 0u64;
        let mut last = first;
        for page in first..pages {
            bytes = bytes.saturating_add(weighing.weigh(page)?);
            if page > first && bytes > limit {
                break;
            }
            last = page;
        }
        while last > first && file_bytes(document, revisions, first, last)? > limit {
            last -= 1;
        }
        spans.push((first, last, None));
        first = last + 1;
    }
    Ok(spans)
}

/// `text` as a file name's stem: nothing a file system or a reader of the name could trip on.
/// Text from a document is untrusted.
fn safe_stem(text: &str, fallback: usize) -> String {
    let cleaned: String = text
        .chars()
        .filter(|c| {
            !c.is_control() && !matches!(*c, '\u{202A}'..='\u{202E}' | '\u{2066}'..='\u{2069}')
        })
        .map(|c| {
            if matches!(c, '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|') {
                '-'
            } else {
                c
            }
        })
        .collect();
    let mut stem = cleaned
        .trim_start_matches(['.', ' '])
        .trim_end_matches(['.', ' '])
        .to_owned();
    if stem.len() > LONGEST_STEM {
        let mut end = LONGEST_STEM;
        while !stem.is_char_boundary(end) {
            end -= 1;
        }
        stem.truncate(end);
        stem.truncate(stem.trim_end_matches(['.', ' ']).len());
    }
    if stem.is_empty() {
        return fallback.to_string();
    }
    let device = stem
        .split('.')
        .next()
        .unwrap_or_default()
        .to_ascii_uppercase();
    let numbered = |prefix: &str| {
        device
            .strip_prefix(prefix)
            .is_some_and(|digit| digit.len() == 1 && digit.chars().all(|c| c.is_ascii_digit()))
    };
    if matches!(device.as_str(), "CON" | "PRN" | "AUX" | "NUL")
        || numbered("COM")
        || numbered("LPT")
    {
        stem.insert(0, '_');
    }
    stem
}

/// The name of file `number` (from 1), free among `used` and in the folder: names differing only in
/// case are one file on macOS and Windows.
fn file_name(
    naming: Naming<'_>,
    labels: &str,
    bookmark: Option<&str>,
    number: usize,
    used: &mut Vec<String>,
    taken: &dyn Fn(&str) -> bool,
) -> String {
    let filled = naming
        .template
        .replace("{document}", naming.document)
        .replace("{bookmark}", bookmark.unwrap_or(labels))
        .replace("{n}", &number.to_string());
    let stem = safe_stem(&filled, number);
    let mut candidate = format!("{stem}.pdf");
    let mut suffix = 2u32;
    while used.contains(&candidate.to_lowercase()) || taken(&candidate) {
        candidate = format!("{stem} ({suffix}).pdf");
        suffix = suffix.saturating_add(1);
    }
    used.push(candidate.to_lowercase());
    candidate
}

/// The plan for `mode`. `blank` holds the pages that show nothing, found from pixels by the caller
/// ([`is_blank`]); `taken` says whether a name is in use where the files go.
///
/// # Errors
///
/// [`WriteError::PagePlan`], as [`OpsError::Core`], for no pages to split or a size of nothing, and
/// those of weighing the pages.
pub fn plan(
    document: &Document,
    revisions: &RevisionStore,
    mode: SplitMode,
    blank: &[usize],
    naming: Naming<'_>,
    taken: &dyn Fn(&str) -> bool,
) -> Result<SplitPlan, OpsError> {
    let plan_error = || OpsError::from(CoreError::Write(WriteError::PagePlan));
    let listed = revisions.pages(document);
    let pages = listed.len();
    let indices: Vec<usize> = (0..pages).collect();
    let mut weighing = PageImport::new(document, revisions, &indices, PAGES_ONLY)?;
    let spans = match mode {
        SplitMode::EveryPages(0) | SplitMode::Size(0) => return Err(plan_error()),
        SplitMode::EveryPages(count) => every(pages, count),
        SplitMode::TopBookmarks => at_bookmarks(document, revisions, pages),
        SplitMode::Size(limit) => by_size(&mut weighing, document, revisions, pages, limit)?,
        SplitMode::BlankPages => between_blanks(pages, blank),
    };
    let mut files = Vec::with_capacity(spans.len());
    let mut used = Vec::with_capacity(spans.len());
    for (index, (first, last, bookmark)) in spans.into_iter().enumerate() {
        let bytes = file_bytes(document, revisions, first, last)?;
        let label = |page: usize| {
            listed
                .get(page)
                .and_then(|page| page.label.clone())
                .unwrap_or_else(|| page.saturating_add(1).to_string())
        };
        let labels = if first == last {
            label(first)
        } else {
            format!("{}\u{2013}{}", label(first), label(last))
        };
        let name = file_name(
            naming,
            &labels,
            bookmark.as_deref(),
            index.saturating_add(1),
            &mut used,
            taken,
        );
        let over_limit = first == last && matches!(mode, SplitMode::Size(limit) if bytes > limit);
        files.push(SplitFile {
            name,
            first,
            last,
            bytes,
            over_limit,
        });
    }
    let bookmarks = revisions
        .outline(document)
        .iter()
        .filter(|item| item.page.is_some())
        .count();
    Ok(SplitPlan {
        files,
        bookmarks: u32::try_from(bookmarks).unwrap_or(u32::MAX),
        blank_pages: u32::try_from(blank.len()).unwrap_or(u32::MAX),
    })
}

#[cfg(test)]
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
mod tests {
    use std::path::PathBuf;

    use ferman_core::{OpenOptions, Source, open};

    use super::*;
    use crate::combine::Assembly;

    fn corpus(name: &str) -> Document {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tests/corpus/generated")
            .join(format!("{name}.pdf"));
        open(&Source::read(&path).unwrap(), &OpenOptions::default()).unwrap()
    }

    const NAMING: Naming<'_> = Naming {
        document: "Tez",
        template: "{document} — {bookmark}",
    };

    fn planned(name: &str, mode: SplitMode, blank: &[usize]) -> SplitPlan {
        let document = corpus(name);
        let revisions = RevisionStore::new(&document);
        plan(&document, &revisions, mode, blank, NAMING, &|_| false).unwrap()
    }

    fn page_total(plan: &SplitPlan) -> usize {
        plan.files
            .iter()
            .map(|file| file.last - file.first + 1)
            .sum()
    }

    #[test]
    fn by_chapter_covers_tez_with_its_front_pages_named_by_the_template() {
        let plan = planned("tez-tr", SplitMode::TopBookmarks, &[]);
        assert_eq!(page_total(&plan), 64);
        let front = &plan.files[0];
        assert_eq!((front.first, front.last), (0, 1));
        assert_eq!(front.name, "Tez — i–ii.pdf");
        assert!(plan.bookmarks > 0);
        assert_eq!(plan.files.len(), plan.bookmarks as usize + 1);
        for pair in plan.files.windows(2) {
            assert_eq!(pair[0].last + 1, pair[1].first);
        }
    }

    #[test]
    fn every_few_pages_and_the_last_file_takes_what_is_left() {
        let plan = planned("tez-tr", SplitMode::EveryPages(30), &[]);
        let spans: Vec<_> = plan
            .files
            .iter()
            .map(|file| (file.first, file.last))
            .collect();
        assert_eq!(spans, [(0, 29), (30, 59), (60, 63)]);
        assert_eq!(plan.files[1].name, "Tez — 23–52.pdf");
    }

    #[test]
    fn a_blank_page_goes_and_ends_a_file() {
        let plan = planned("tez-tr", SplitMode::BlankPages, &[0, 10, 11, 63]);
        let spans: Vec<_> = plan
            .files
            .iter()
            .map(|file| (file.first, file.last))
            .collect();
        assert_eq!(spans, [(1, 9), (12, 62)]);
        assert_eq!(plan.blank_pages, 4);
    }

    #[test]
    fn by_size_stays_under_the_limit_and_a_large_page_stands_alone() {
        let whole = planned("tez-tr", SplitMode::EveryPages(64), &[]).files[0].bytes;
        let limit = whole / 3;
        let plan = planned("tez-tr", SplitMode::Size(limit), &[]);
        assert!(plan.files.len() >= 3);
        assert_eq!(page_total(&plan), 64);
        for file in &plan.files {
            assert!(file.bytes <= limit || file.first == file.last);
            assert_eq!(file.over_limit, file.bytes > limit);
        }
        let tiny = planned("tez-tr", SplitMode::Size(10), &[]);
        assert_eq!(tiny.files.len(), 64);
        assert!(tiny.files.iter().all(|file| file.over_limit));
    }

    /// The planned files, written as the job writes them, are within what the plan says.
    #[test]
    fn no_file_comes_out_larger_than_planned_or_than_the_size_asked_for() {
        for name in [
            "tez-tr",
            "pages-tree",
            "kira-tr",
            "combine-outline",
            "form-aks1-tr",
        ] {
            let document = corpus(name);
            let revisions = RevisionStore::new(&document);
            let whole = file_bytes(
                &document,
                &revisions,
                0,
                revisions.pages(&document).len() - 1,
            )
            .unwrap();
            let limit = whole / 3 + 1;
            let plan = plan(
                &document,
                &revisions,
                SplitMode::Size(limit),
                &[],
                NAMING,
                &|_| false,
            )
            .unwrap();
            for file in &plan.files {
                let pages: Vec<usize> = (file.first..=file.last).collect();
                let mut assembly = Assembly::new(&ferman_core::limits::Limits::default()).unwrap();
                assembly
                    .add_pages::<OpsError>(
                        &document,
                        &revisions,
                        &pages,
                        PAGES_ONLY,
                        None,
                        &mut || Ok(()),
                    )
                    .unwrap();
                let written = assembly.finish().unwrap().len() as u64;
                assert!(
                    written <= file.bytes,
                    "{name} {file:?}: wrote {written} over the plan"
                );
                assert!(
                    written <= limit || file.first == file.last,
                    "{name} {file:?}: wrote {written} over {limit}"
                );
            }
        }
    }

    #[test]
    fn a_size_or_count_of_nothing_is_refused() {
        let document = corpus("kira-tr");
        let revisions = RevisionStore::new(&document);
        for mode in [SplitMode::Size(0), SplitMode::EveryPages(0)] {
            assert!(plan(&document, &revisions, mode, &[], NAMING, &|_| false).is_err());
        }
    }

    #[test]
    fn a_name_from_a_document_cannot_leave_its_folder_or_trick_the_eye() {
        assert_eq!(safe_stem("../../etc/passwd", 1), "-..-etc-passwd");
        assert_eq!(safe_stem("a\u{202E}fdp.exe\n", 1), "afdp.exe");
        assert_eq!(safe_stem("con", 1), "_con");
        assert_eq!(safe_stem("COM1.report", 1), "_COM1.report");
        assert_eq!(safe_stem("...", 7), "7");
        let long = "ş".repeat(300);
        let stem = safe_stem(&long, 1);
        assert!(stem.len() <= LONGEST_STEM);
        assert!(stem.chars().all(|c| c == 'ş'));
    }

    #[test]
    fn a_name_in_use_gets_a_number_also_in_another_case() {
        let mut used = vec!["a.pdf".to_owned()];
        let naming = Naming {
            document: "A",
            template: "{document}",
        };
        let taken = |name: &str| name == "A (2).pdf";
        assert_eq!(
            file_name(naming, "1", None, 1, &mut used, &taken),
            "A (3).pdf"
        );
    }

    #[test]
    fn dust_is_blank_and_a_mark_is_not() {
        let white = [255u8; 4];
        let mut page = white.repeat(10_000);
        assert!(is_blank(&page));
        page[..40].fill(0);
        assert!(is_blank(&page));
        page[..4 * 11].fill(0);
        assert!(!is_blank(&page));
    }
}
