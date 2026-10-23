//! The Files table of `tests/corpus/README.md`: one row per corpus file, with its source, licence,
//! SHA-256, what it covers and the milestone that added it.

/// The table's columns, in order.
pub const COLUMNS: [&str; 6] = ["File", "Source", "Licence", "SHA-256", "Covers", "Added"];

/// The heading the table follows.
const HEADING: &str = "## Files";

/// One row of the Files table.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Row {
    /// The path relative to `tests/corpus/`, with `/` separators.
    pub file: String,
    /// A URL, or `tools/corpus <generator>` for a generated file.
    pub source: String,
    /// An SPDX identifier, or `generated`.
    pub licence: String,
    /// The lowercase hex SHA-256 of the file.
    pub sha256: String,
    /// What the file exercises.
    pub covers: String,
    /// The milestone that added it.
    pub added: String,
    /// The row's line in the README, from 1.
    pub line: usize,
}

/// Reads the rows of the Files table.
///
/// # Errors
///
/// A message when the heading or the table header is missing, the header's columns differ from
/// [`COLUMNS`], or a row has the wrong number of cells.
pub fn rows(text: &str) -> Result<Vec<Row>, String> {
    let mut lines = text.lines().enumerate();
    if !lines.any(|(_, line)| line.trim_end() == HEADING) {
        return Err(format!("README.md has no \"{HEADING}\" heading"));
    }
    let mut table = lines
        .skip_while(|(_, line)| !line.starts_with('|'))
        .take_while(|(_, line)| line.starts_with('|'));
    let Some((_, header)) = table.next() else {
        return Err("README.md has no table under \"## Files\"".to_owned());
    };
    if cells(header) != COLUMNS {
        return Err(format!(
            "the Files table's columns are not {}",
            COLUMNS.join(", ")
        ));
    }
    let _separator = table.next();
    table
        .map(|(index, line)| {
            let number = index.saturating_add(1);
            let [file, source, licence, sha256, covers, added] =
                <[String; 6]>::try_from(cells(line)).map_err(|cells| {
                    format!(
                        "README.md line {number}: {} cells, not {}",
                        cells.len(),
                        COLUMNS.len()
                    )
                })?;
            Ok(Row {
                file: unquote(&file),
                source,
                licence,
                sha256: unquote(&sha256),
                covers,
                added,
                line: number,
            })
        })
        .collect()
}

/// The trimmed cells of a table line `| a | b |`.
fn cells(line: &str) -> Vec<String> {
    let inner = line.trim().trim_start_matches('|').trim_end_matches('|');
    inner
        .split('|')
        .map(|cell| cell.trim().to_owned())
        .collect()
}

/// A cell without the backticks of inline code.
fn unquote(cell: &str) -> String {
    cell.trim_matches('`').to_owned()
}

/// Whether `text` is a lowercase hex SHA-256.
#[must_use]
pub fn is_sha256(text: &str) -> bool {
    text.len() == 64 && text.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f'))
}

#[cfg(test)]
mod tests {
    use super::*;

    const HEAD: &str = "# Test corpus\n\n## Files\n\n| File | Source | Licence | SHA-256 | Covers | Added |\n|---|---|---|---|---|---|\n";

    #[test]
    fn reads_rows_and_strips_inline_code() {
        let text = format!(
            "{HEAD}| `generated/a.pdf` | tools/corpus a | generated | `{}` | text | M2 |\n\nAfter.\n",
            "0".repeat(64)
        );
        let rows = rows(&text).unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].file, "generated/a.pdf");
        assert_eq!(rows[0].sha256, "0".repeat(64));
        assert_eq!(rows[0].added, "M2");
        assert_eq!(rows[0].line, 7);
    }

    #[test]
    fn an_empty_table_has_no_rows() {
        assert_eq!(rows(HEAD).unwrap(), []);
    }

    #[test]
    fn rejects_a_missing_heading_other_columns_and_short_rows() {
        assert!(rows("# Test corpus\n").unwrap_err().contains("heading"));
        assert!(
            rows("## Files\n\n| File | Licence |\n|---|---|\n")
                .unwrap_err()
                .contains("columns")
        );
        let short = format!("{HEAD}| a.pdf | b |\n");
        assert!(rows(&short).unwrap_err().contains("line 7: 2 cells"));
    }

    #[test]
    fn checks_the_hash_format() {
        assert!(is_sha256(&"ab".repeat(32)));
        assert!(!is_sha256(&"AB".repeat(32)));
        assert!(!is_sha256("abc"));
    }
}
