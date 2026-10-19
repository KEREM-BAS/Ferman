//! Ferman's test corpus: deterministic generators and the provenance check
//! ([ADR 0020](../../../docs/adr/0020-test-corpus.md)).
//!
//! Each generator makes `tests/corpus/generated/<name>.pdf` and `<name>.expected.txt` (the expected
//! text, one page per form feed), byte for byte the same on every run. Files up to
//! [`COMMIT_LIMIT`] are committed; larger ones are regenerated and checked against the SHA-256 of
//! their README row. [`check`] proves both, and that every file in `tests/corpus/` has its row.
#![forbid(unsafe_code)]

pub mod readme;

use readme::Row;
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;

/// The corpus folder, relative to the repository root.
pub const CORPUS_DIR: &str = "tests/corpus";

/// The folder of generated files, relative to [`CORPUS_DIR`].
pub const GENERATED_DIR: &str = "generated";

/// The suffix of a generated PDF's expected-text file. It shares the PDF's README row.
pub const EXPECTED_SUFFIX: &str = ".expected.txt";

/// Files up to this many bytes are committed (ADR 0020: up to 1 MB).
pub const COMMIT_LIMIT: usize = 1_000_000;

/// What a generator makes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Generated {
    /// The PDF.
    pub pdf: Vec<u8>,
    /// The text a reader should extract, one page per form feed (U+000C).
    pub expected_text: String,
}

/// A corpus generator.
#[derive(Debug, Clone, Copy)]
pub struct Generator {
    /// The file name without extension, such as `kira-tr`.
    pub name: &'static str,
    /// Makes the files. The same bytes on every call.
    pub build: fn() -> Result<Generated, String>,
}

impl Generator {
    /// The PDF's path relative to [`CORPUS_DIR`].
    #[must_use]
    pub fn pdf_path(&self) -> String {
        format!("{GENERATED_DIR}/{}.pdf", self.name)
    }

    /// The expected text's path relative to [`CORPUS_DIR`].
    #[must_use]
    pub fn text_path(&self) -> String {
        format!("{GENERATED_DIR}/{}{EXPECTED_SUFFIX}", self.name)
    }

    /// The generator's files as (path relative to [`CORPUS_DIR`], bytes).
    fn outputs(&self) -> Result<[(String, Vec<u8>); 2], String> {
        let generated = (self.build)().map_err(|err| format!("{}: {err}", self.name))?;
        Ok([
            (self.pdf_path(), generated.pdf),
            (self.text_path(), generated.expected_text.into_bytes()),
        ])
    }
}

/// Every generator, in the order of the README's rows. The first wave arrives in M2 step 1.
pub const GENERATORS: &[Generator] = &[];

/// The lowercase hex SHA-256 of `bytes`.
#[must_use]
pub fn sha256_hex(bytes: &[u8]) -> String {
    Sha256::digest(bytes)
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

/// Writes the files of `generators` under `root`'s corpus that are missing or differ, and
/// returns their paths relative to [`CORPUS_DIR`].
///
/// # Errors
///
/// A message when a generator fails or a file cannot be written.
pub fn generate(root: &Path, generators: &[Generator]) -> Result<Vec<String>, String> {
    let corpus = root.join(CORPUS_DIR);
    let mut written = Vec::new();
    for generator in generators {
        for (path, bytes) in generator.outputs()? {
            let target = corpus.join(&path);
            if fs::read(&target).is_ok_and(|current| current == bytes) {
                continue;
            }
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent).map_err(|err| format!("{path}: {err}"))?;
            }
            fs::write(&target, &bytes).map_err(|err| format!("{path}: {err}"))?;
            written.push(path);
        }
    }
    Ok(written)
}

/// Checks the corpus under `root` against its README and `generators`, and returns the problems.
///
/// - Every file in `tests/corpus/` but the README has a row, except a generated PDF's expected
///   text, which shares the PDF's row; the row's hash is the file's.
/// - Every row names a file that exists, or one a generator makes above [`COMMIT_LIMIT`].
/// - Every generator gives the same bytes twice, its PDF has a row, its files up to the limit are
///   committed as it makes them, and a larger PDF has the hash of its row.
/// - Nothing in `generated/` is a file no generator makes.
///
/// # Errors
///
/// A message when the README cannot be read or its table is malformed, or a generator fails.
pub fn check(root: &Path, generators: &[Generator]) -> Result<Vec<String>, String> {
    let corpus = root.join(CORPUS_DIR);
    let text = fs::read_to_string(corpus.join("README.md"))
        .map_err(|err| format!("{CORPUS_DIR}/README.md: {err}"))?;
    let rows = readme::rows(&text)?;
    let mut problems = Vec::new();

    let mut by_file: BTreeMap<&str, &Row> = BTreeMap::new();
    for row in &rows {
        if by_file.insert(row.file.as_str(), row).is_some() {
            problems.push(format!(
                "README.md line {}: {} has two rows",
                row.line, row.file
            ));
        }
        if !readme::is_sha256(&row.sha256) {
            problems.push(format!(
                "README.md line {}: {}: the SHA-256 is not 64 lowercase hex digits",
                row.line, row.file
            ));
        }
    }

    let files = corpus_files(&corpus)?;
    for (path, bytes) in &files {
        if let Some(pdf) = path.strip_suffix(EXPECTED_SUFFIX) {
            if !by_file.contains_key(format!("{pdf}.pdf").as_str()) {
                problems.push(format!(
                    "{path}: no row for {pdf}.pdf, the PDF it belongs to"
                ));
            }
            continue;
        }
        match by_file.get(path.as_str()) {
            None => problems.push(format!("{path}: no row in README.md")),
            Some(row) if row.sha256 != sha256_hex(bytes) => problems.push(format!(
                "{path}: SHA-256 {} differs from README.md line {}",
                sha256_hex(bytes),
                row.line
            )),
            Some(_) => {}
        }
    }

    let mut made = BTreeSet::new();
    for generator in generators {
        let outputs = generator.outputs()?;
        if generator.outputs()? != outputs {
            problems.push(format!("{}: two runs made different bytes", generator.name));
        }
        for (path, bytes) in outputs {
            check_output(&path, &bytes, &files, &by_file, &mut problems);
            made.insert(path);
        }
    }

    for row in &rows {
        if !files.contains_key(&row.file) && !made.contains(&row.file) {
            problems.push(format!(
                "README.md line {}: {} does not exist",
                row.line, row.file
            ));
        }
    }
    let generated_prefix = format!("{GENERATED_DIR}/");
    for path in files.keys() {
        if path.starts_with(&generated_prefix) && !made.contains(path) {
            problems.push(format!("{path}: no generator makes it"));
        }
    }
    Ok(problems)
}

/// Checks one generated file against the tree and the README.
fn check_output(
    path: &str,
    bytes: &[u8],
    files: &BTreeMap<String, Vec<u8>>,
    by_file: &BTreeMap<&str, &Row>,
    problems: &mut Vec<String>,
) {
    let is_text = path.ends_with(EXPECTED_SUFFIX);
    if !is_text && !by_file.contains_key(path) {
        problems.push(format!(
            "{path}: the generator's PDF has no row in README.md"
        ));
    }
    if bytes.len() <= COMMIT_LIMIT {
        match files.get(path) {
            None => problems.push(format!(
                "{path}: not generated; run `cargo run --manifest-path tools/corpus/Cargo.toml -- generate`"
            )),
            Some(committed) if committed.as_slice() != bytes => problems.push(format!(
                "{path}: stale; the generator makes other bytes"
            )),
            Some(_) => {}
        }
    } else if is_text {
        problems.push(format!(
            "{path}: {} bytes, too large to commit",
            bytes.len()
        ));
    } else if let Some(row) = by_file.get(path)
        && row.sha256 != sha256_hex(bytes)
    {
        problems.push(format!(
            "{path}: the generator makes SHA-256 {}, not README.md line {}",
            sha256_hex(bytes),
            row.line
        ));
    }
}

/// Every file under the corpus but its README, by path relative to it with `/` separators. Hidden
/// files, such as a `.gitignore`, are not corpus files.
fn corpus_files(corpus: &Path) -> Result<BTreeMap<String, Vec<u8>>, String> {
    let mut files = BTreeMap::new();
    let mut folders = vec![corpus.to_path_buf()];
    while let Some(folder) = folders.pop() {
        let entries =
            fs::read_dir(&folder).map_err(|err| format!("{}: {err}", folder.display()))?;
        for entry in entries {
            let entry = entry.map_err(|err| format!("{}: {err}", folder.display()))?;
            let path = entry.path();
            if entry.file_name().to_string_lossy().starts_with('.') {
                continue;
            }
            if path.is_dir() {
                folders.push(path);
                continue;
            }
            let Ok(relative) = path.strip_prefix(corpus) else {
                continue;
            };
            let relative: Vec<String> = relative
                .components()
                .map(|part| part.as_os_str().to_string_lossy().into_owned())
                .collect();
            let relative = relative.join("/");
            if relative == "README.md" {
                continue;
            }
            let bytes = fs::read(&path).map_err(|err| format!("{relative}: {err}"))?;
            files.insert(relative, bytes);
        }
    }
    Ok(files)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU8, Ordering};

    const README: &str = "# Test corpus\n\n## Files\n\n| File | Source | Licence | SHA-256 | Covers | Added |\n|---|---|---|---|---|---|\n";

    fn small() -> Result<Generated, String> {
        Ok(Generated {
            pdf: b"%PDF-1.7 small".to_vec(),
            expected_text: "Page one\u{c}Page two".to_owned(),
        })
    }

    fn large() -> Result<Generated, String> {
        Ok(Generated {
            pdf: vec![b'x'; COMMIT_LIMIT + 1],
            expected_text: "Large".to_owned(),
        })
    }

    fn changing() -> Result<Generated, String> {
        static RUNS: AtomicU8 = AtomicU8::new(0);
        Ok(Generated {
            pdf: vec![RUNS.fetch_add(1, Ordering::Relaxed)],
            expected_text: String::new(),
        })
    }

    const SMALL: Generator = Generator {
        name: "small",
        build: small,
    };
    const LARGE: Generator = Generator {
        name: "large",
        build: large,
    };

    fn row(file: &str, sha256: &str) -> String {
        format!("| `{file}` | tools/corpus | generated | `{sha256}` | test | M2 |\n")
    }

    /// A repository root with the corpus README and `rows`.
    fn root(rows: &[String]) -> tempfile::TempDir {
        let root = tempfile::tempdir().unwrap();
        let corpus = root.path().join(CORPUS_DIR);
        fs::create_dir_all(&corpus).unwrap();
        fs::write(
            corpus.join("README.md"),
            format!("{README}{}", rows.concat()),
        )
        .unwrap();
        root
    }

    fn small_row() -> String {
        row("generated/small.pdf", &sha256_hex(b"%PDF-1.7 small"))
    }

    #[test]
    fn generate_writes_the_files_check_accepts() {
        let root = root(&[small_row()]);
        let before = check(root.path(), &[SMALL]).unwrap();
        assert!(
            before.iter().any(|p| p.contains("not generated")),
            "{before:?}"
        );

        let written = generate(root.path(), &[SMALL]).unwrap();
        assert_eq!(
            written,
            ["generated/small.pdf", "generated/small.expected.txt"]
        );
        assert_eq!(check(root.path(), &[SMALL]).unwrap(), Vec::<String>::new());
        assert_eq!(
            generate(root.path(), &[SMALL]).unwrap(),
            Vec::<String>::new()
        );
        let text = fs::read(root.path().join(CORPUS_DIR).join(SMALL.text_path())).unwrap();
        assert_eq!(text, "Page one\u{c}Page two".as_bytes());
    }

    #[test]
    fn a_changed_file_is_stale_and_its_hash_wrong() {
        let root = root(&[small_row()]);
        generate(root.path(), &[SMALL]).unwrap();
        fs::write(
            root.path().join(CORPUS_DIR).join(SMALL.pdf_path()),
            b"edited",
        )
        .unwrap();
        let problems = check(root.path(), &[SMALL]).unwrap();
        assert!(problems.iter().any(|p| p.contains("stale")), "{problems:?}");
        assert!(
            problems
                .iter()
                .any(|p| p.contains("differs from README.md line 7"))
        );
    }

    #[test]
    fn a_file_without_a_row_and_a_row_without_a_file_are_problems() {
        let root = root(&[row("real/missing.pdf", &"0".repeat(64))]);
        let corpus = root.path().join(CORPUS_DIR);
        fs::create_dir_all(corpus.join("real")).unwrap();
        fs::write(corpus.join("real/unlisted.pdf"), b"%PDF").unwrap();
        fs::write(corpus.join(".gitignore"), b"").unwrap();
        let problems = check(root.path(), &[]).unwrap();
        assert_eq!(
            problems,
            [
                "real/unlisted.pdf: no row in README.md",
                "README.md line 7: real/missing.pdf does not exist",
            ]
        );
    }

    #[test]
    fn a_generator_needs_a_row_and_its_leftovers_are_found() {
        let root = root(&[]);
        let corpus = root.path().join(CORPUS_DIR);
        generate(root.path(), &[SMALL]).unwrap();
        fs::write(corpus.join("generated/old.pdf"), b"%PDF").unwrap();
        let problems = check(root.path(), &[SMALL]).unwrap();
        assert!(problems.contains(
            &"generated/small.pdf: the generator's PDF has no row in README.md".to_owned()
        ));
        assert!(problems.contains(&"generated/old.pdf: no generator makes it".to_owned()));
        assert!(problems.contains(&"generated/small.pdf: no row in README.md".to_owned()));
    }

    #[test]
    fn a_large_pdf_is_checked_by_its_hash_without_the_file() {
        let pdf = vec![b'x'; COMMIT_LIMIT + 1];
        let good = root(&[row("generated/large.pdf", &sha256_hex(&pdf))]);
        let problems = check(good.path(), &[LARGE]).unwrap();
        assert_eq!(
            problems,
            [
                "generated/large.expected.txt: not generated; run `cargo run --manifest-path tools/corpus/Cargo.toml -- generate`"
            ]
        );
        let bad = root(&[row("generated/large.pdf", &"0".repeat(64))]);
        let problems = check(bad.path(), &[LARGE]).unwrap();
        assert!(
            problems
                .iter()
                .any(|p| p.contains("the generator makes SHA-256")),
            "{problems:?}"
        );
    }

    #[test]
    fn a_generator_that_changes_between_runs_is_a_problem() {
        let root = root(&[]);
        let changing = Generator {
            name: "changing",
            build: changing,
        };
        let problems = check(root.path(), &[changing]).unwrap();
        assert!(problems.contains(&"changing: two runs made different bytes".to_owned()));
    }

    #[test]
    fn rows_need_well_formed_hashes_and_one_row_per_file() {
        let root = root(&[row("a.pdf", "ABC"), row("a.pdf", &"0".repeat(64))]);
        let problems = check(root.path(), &[]).unwrap();
        assert!(problems.iter().any(|p| p.contains("64 lowercase hex")));
        assert!(problems.iter().any(|p| p.contains("a.pdf has two rows")));
    }

    #[test]
    fn hashes_are_lowercase_hex() {
        assert_eq!(
            sha256_hex(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn the_repository_corpus_passes() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
        assert_eq!(check(&root, GENERATORS).unwrap(), Vec::<String>::new());
    }
}
