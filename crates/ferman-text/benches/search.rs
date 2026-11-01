//! The engine's part of "Search, 500 pages" (docs/ARCHITECTURE.md §14): reading every page's text
//! of the generated `long-500` in order, as the search job does on its first run (its index), and
//! finding a word in the text read, as each later search does. No PDFium.
//!
//! Needs `long-500.pdf`, which is over 1 MB and so not committed:
//! `cargo run --manifest-path tools/corpus/Cargo.toml -- generate` makes it. Without it the
//! benchmark says so and measures nothing.
//!
//! With `FERMAN_BENCH_GUARD=1` (CI) it then times one cold run and fails above the budgets: the
//! first page's matches under 200 ms and at least 100 pages a second read.
//!
//! ```sh
//! cargo bench -p ferman-text --bench search
//! ```
// A benchmark is a program: it reports on stderr and fails loudly.
#![allow(
    clippy::print_stderr,
    clippy::expect_used,
    clippy::unwrap_used,
    clippy::panic
)]

use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use criterion::Criterion;
use ferman_core::{Document, OpenOptions, Source, open};
use ferman_text::{SearchOptions, find, page_text};

/// Pages a second the first search reads at least (ARCHITECTURE §14: indexing at least 100).
const PAGES_PER_SECOND: f64 = 100.0;

/// The first page's matches (ARCHITECTURE §14: the first match under 200 ms).
const FIRST_MATCH: Duration = Duration::from_millis(200);

fn document(path: &Path) -> Document {
    let source = Source::read(path).unwrap();
    open(&source, &OpenOptions::default()).unwrap()
}

/// Every page's text, in order.
fn read_all(document: &Document) -> Vec<String> {
    (0..document.page_count())
        .map(|index| page_text(document, index).unwrap())
        .collect()
}

fn main() {
    let path =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/corpus/generated/long-500.pdf");
    if !path.exists() {
        eprintln!(
            "search: {} is missing; run `cargo run --manifest-path tools/corpus/Cargo.toml -- generate`",
            path.display()
        );
        return;
    }
    let options = SearchOptions::default();
    let pages = read_all(&document(&path));
    assert_eq!(pages.len(), 500);

    let mut criterion = Criterion::default().configure_from_args();
    let mut group = criterion.benchmark_group("search");
    group.sample_size(10);
    group.bench_function("read_500_pages", |bench| {
        bench.iter_with_setup(|| document(&path), |document| read_all(&document));
    });
    group.bench_function("find_in_500_pages", |bench| {
        bench.iter(|| {
            pages
                .iter()
                .map(|text| find(text, "caretaker", &options).len())
                .sum::<usize>()
        });
    });
    group.finish();
    criterion.final_summary();

    if std::env::var_os("FERMAN_BENCH_GUARD").is_none() {
        return;
    }
    // One cold run, as the search job's first: open, then page after page.
    let start = Instant::now();
    let document = document(&path);
    let first = page_text(&document, 0).unwrap();
    let found = find(&first, "maintenance", &options);
    let first_match = start.elapsed();
    let all = read_all(&document);
    let elapsed = start.elapsed();
    let rate = all.len() as f64 / elapsed.as_secs_f64();
    eprintln!(
        "search guard: first page's matches {first_match:?} ({} found), 500 pages in {elapsed:?}, {rate:.0} pages/s",
        found.len()
    );
    assert!(!found.is_empty(), "the first page has \"Maintenance\"");
    assert!(
        first_match < FIRST_MATCH,
        "the first match took {first_match:?}, over {FIRST_MATCH:?}"
    );
    assert!(
        rate >= PAGES_PER_SECOND,
        "{rate:.0} pages a second, under {PAGES_PER_SECOND}"
    );
}
