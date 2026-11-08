//! The `ferman` command line.
//!
//! A tool for tests and power users on the same facade as the app (ADR 0003). It uses ferman-api
//! with the `frb` feature off, so it carries no bridge code. Output is human-readable by default
//! and JSON with `--json`; the JSON carries the API version (docs/ARCHITECTURE.md §2.3).
//!
//! Commands: `ferman --version`, `ferman info [--json] [--pdfium <path>]` and, since M2,
//! `ferman open <file> [--json] [--pdfium <path>]`. Each starts an engine of its own. `info`
//! reports whether PDFium loaded; a missing or broken library is reported, not an error. `open`
//! prints the pages of a PDF and why it opens read-only, if it does; it takes no password, so an
//! encrypted file fails with `password_required`. Since M3, `ferman blocks <file> --page N` lists
//! a page's text blocks (id, box, editability, text), `ferman edit` replaces one block's text and
//! saves incrementally, `ferman save` saves a copy, and `ferman verify-edit` runs the pixel-diff
//! acceptance check of one edit (docs/ARCHITECTURE.md §13.4) and exits with status 1 when it
//! fails. On a signed file a change fails with `confirmation_required` until `--confirm-signed`
//! says to go on, though the signature will no longer be valid (G35). Pages are numbered from 1,
//! as `open` lists them. Errors print one short line to standard error and exit with status 1;
//! argument errors exit with status 2. A failed write, including of `--version` or `--help`,
//! exits with status 1.
#![forbid(unsafe_code)]

use std::error::Error;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use clap::{CommandFactory, FromArgMatches, Parser, Subcommand};
use ferman_api::facade::{
    self, BlockId, BlockInfo, Direction, DocumentId, EDIT_MARGIN, Editability, Engine,
    EngineConfig, EngineInfo, OpenedDocument, PageBlocks, PdfiumLibrary, PdfiumStatus, PixelRect,
    RESOLUTIONS, ReadOnly, compare, device_region,
};

/// Ferman's engine on the command line.
#[derive(Debug, Parser)]
#[command(name = "ferman", arg_required_else_help = true)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Print the engine's versions, build profile and PDFium status.
    Info {
        /// Print JSON for scripts instead of text.
        #[arg(long)]
        json: bool,
        /// The PDFium library to load. Default: the file named by FERMAN_PDFIUM_PATH, otherwise
        /// the library bundled next to the executable.
        #[arg(long, value_name = "PATH")]
        pdfium: Option<PathBuf>,
    },
    /// Open a PDF and print its pages, and why it opens read-only if it does.
    Open {
        /// The PDF to open.
        file: PathBuf,
        /// Print JSON for scripts instead of text.
        #[arg(long)]
        json: bool,
        /// The PDFium library to load. Default: the file named by FERMAN_PDFIUM_PATH, otherwise
        /// the library bundled next to the executable.
        #[arg(long, value_name = "PATH")]
        pdfium: Option<PathBuf>,
    },
    /// List the text blocks of a page: id, box in points, editability and text.
    Blocks {
        /// The PDF to read.
        file: PathBuf,
        #[command(flatten)]
        page: PageArg,
        /// Print JSON for scripts instead of text.
        #[arg(long)]
        json: bool,
        #[command(flatten)]
        pdfium: PdfiumArg,
    },
    /// Replace the text of one block and save incrementally, to the file itself or to `-o`.
    Edit {
        /// The PDF to edit.
        file: PathBuf,
        #[command(flatten)]
        edit: EditArgs,
        /// Save to this file instead; the input stays as it is.
        #[arg(short, long, value_name = "FILE")]
        output: Option<PathBuf>,
        #[command(flatten)]
        pdfium: PdfiumArg,
    },
    /// Open a PDF and save it as another file.
    Save {
        /// The PDF to open.
        file: PathBuf,
        /// The file to save.
        #[arg(short, long, value_name = "FILE")]
        output: PathBuf,
        /// Go on when this changes a signed file (its own path as the output), though its
        /// signature will no longer be valid.
        #[arg(long)]
        confirm_signed: bool,
        #[command(flatten)]
        pdfium: PdfiumArg,
    },
    /// Apply one edit to a temporary copy and check with PDFium that no pixel changed outside the
    /// edited block, at 72, 150 and 300 dpi; exits with status 1 when the check fails.
    VerifyEdit {
        /// The PDF to edit; it is not changed.
        file: PathBuf,
        #[command(flatten)]
        edit: EditArgs,
        /// Print JSON for scripts instead of text.
        #[arg(long)]
        json: bool,
        #[command(flatten)]
        pdfium: PdfiumArg,
    },
}

#[derive(Debug, clap::Args)]
struct PageArg {
    /// The page, from 1.
    #[arg(long, value_name = "N", value_parser = clap::value_parser!(u32).range(1..))]
    page: u32,
}

impl PageArg {
    /// The engine's page index, from 0.
    fn index(&self) -> u32 {
        self.page.saturating_sub(1)
    }
}

#[derive(Debug, clap::Args)]
struct PdfiumArg {
    /// The PDFium library to load. Default: the file named by FERMAN_PDFIUM_PATH, otherwise the
    /// library bundled next to the executable.
    #[arg(long, value_name = "PATH")]
    pdfium: Option<PathBuf>,
}

#[derive(Debug, clap::Args)]
struct EditArgs {
    #[command(flatten)]
    page: PageArg,
    /// The block's id, as `ferman blocks` lists it.
    #[arg(long, value_name = "ID")]
    block: u64,
    /// The block's new text, its lines separated by line feeds, one per line of the block.
    #[arg(long)]
    text: String,
    /// Go on when the file is signed, though its signature will no longer be valid.
    #[arg(long)]
    confirm_signed: bool,
}

fn main() -> ExitCode {
    let cli = match parse_args() {
        Ok(cli) => cli,
        Err(code) => return code,
    };
    match run(&cli) {
        Ok(code) => code,
        Err(err) => {
            // If standard error is closed too, there is nowhere left to report; the exit status
            // still says it failed.
            let _ = writeln!(io::stderr().lock(), "ferman: error: {err}");
            ExitCode::FAILURE
        }
    }
}

/// Parses the arguments.
///
/// `--version`, `--help` and argument errors come back as the exit code to return, after their
/// text is printed. clap's own `Error::exit()` ignores a failed write, so a closed or full output
/// stream would still exit 0; this returns a failure instead.
fn parse_args() -> Result<Cli, ExitCode> {
    Cli::command()
        .version(version_text())
        .try_get_matches()
        .and_then(|matches| Cli::from_arg_matches(&matches))
        .map_err(|err| {
            // Standard output is line-buffered; flush it so a failed write is seen here.
            let printed = err.print().and_then(|()| io::stdout().flush());
            exit_code_after_print(printed, err.exit_code())
        })
}

/// The exit code after clap printed its output: clap's code (0 for `--version` and `--help`, 2 for
/// an argument error), or a failure if printing failed.
fn exit_code_after_print(printed: io::Result<()>, clap_code: i32) -> ExitCode {
    match (printed, u8::try_from(clap_code)) {
        (Ok(()), Ok(code)) => ExitCode::from(code),
        _ => ExitCode::FAILURE,
    }
}

/// The text after the program name in `ferman --version`, such as `0.1.0 (api 0.1)`.
fn version_text() -> String {
    format!("{} (api {})", facade::APP_VERSION, facade::api_version())
}

fn run(cli: &Cli) -> Result<ExitCode, Box<dyn Error>> {
    match &cli.command {
        Command::Info { json, pdfium } => {
            // An engine of its own, so `--pdfium` applies; dropping it stops the render thread.
            let engine = start(pdfium);
            let info = facade::block_on(engine.info())?;
            drop(engine);
            let mut out = io::stdout().lock();
            if *json {
                serde_json::to_writer_pretty(&mut out, &info)?;
                writeln!(out)?;
            } else {
                write_info_text(&mut out, &info)?;
            }
            out.flush()?;
        }
        Command::Open { file, json, pdfium } => {
            let engine = start(pdfium);
            // Dropping the engine closes the document.
            let document = facade::block_on(engine.open(file.clone(), None))?;
            drop(engine);
            let mut out = io::stdout().lock();
            if *json {
                serde_json::to_writer_pretty(&mut out, &document_json(&document))?;
                writeln!(out)?;
            } else {
                write_document_text(&mut out, &document)?;
            }
            out.flush()?;
        }
        Command::Blocks {
            file,
            page,
            json,
            pdfium,
        } => {
            let engine = start(&pdfium.pdfium);
            let document = facade::block_on(engine.open(file.clone(), None))?;
            let blocks = facade::block_on(engine.text_blocks(document.id, page.index()))?;
            drop(engine);
            let mut out = io::stdout().lock();
            if *json {
                serde_json::to_writer_pretty(&mut out, &blocks_json(&blocks))?;
                writeln!(out)?;
            } else {
                write_blocks_text(&mut out, &blocks)?;
            }
            out.flush()?;
        }
        Command::Edit {
            file,
            edit,
            output,
            pdfium,
        } => {
            let engine = start(&pdfium.pdfium);
            let document = facade::block_on(engine.open(file.clone(), None))?;
            apply_edit(&engine, document.id, edit)?;
            match output {
                Some(output) => facade::block_on(engine.save_as(
                    document.id,
                    output.clone(),
                    facade::SaveOptions::default(),
                    None,
                ))?,
                None => facade::block_on(engine.save(document.id, None))?,
            };
        }
        Command::Save {
            file,
            output,
            confirm_signed,
            pdfium,
        } => {
            let engine = start(&pdfium.pdfium);
            let document = facade::block_on(engine.open(file.clone(), None))?;
            if *confirm_signed {
                facade::block_on(engine.confirm_edit_signed(document.id))?;
            }
            facade::block_on(engine.save_as(
                document.id,
                output.clone(),
                facade::SaveOptions::default(),
                None,
            ))?;
        }
        Command::VerifyEdit {
            file,
            edit,
            json,
            pdfium,
        } => {
            let engine = start(&pdfium.pdfium);
            let saved =
                std::env::temp_dir().join(format!("ferman-verify-edit-{}.pdf", std::process::id()));
            let report = verify_edit(&engine, file, &saved, edit);
            // The saved copy is only for the check.
            let _ = std::fs::remove_file(&saved);
            let report = report?;
            let mut out = io::stdout().lock();
            if *json {
                serde_json::to_writer_pretty(&mut out, &report.json(edit))?;
                writeln!(out)?;
            } else {
                report.write_text(&mut out)?;
            }
            out.flush()?;
            if !report.passed() {
                return Ok(ExitCode::FAILURE);
            }
        }
    }
    Ok(ExitCode::SUCCESS)
}

/// Replaces the text of the block `edit` names in a transaction of its own and commits it.
fn apply_edit(
    engine: &Engine,
    document: DocumentId,
    edit: &EditArgs,
) -> Result<(), Box<dyn Error>> {
    if edit.confirm_signed {
        facade::block_on(engine.confirm_edit_signed(document))?;
    }
    let transaction =
        facade::block_on(engine.begin_edit(document, edit.page.index(), BlockId(edit.block)))?;
    let preview = match facade::block_on(engine.apply(transaction, edit.text.clone())) {
        Ok(preview) => preview,
        Err(err) => {
            let _ = facade::block_on(engine.rollback(transaction));
            return Err(err.into());
        }
    };
    if !preview.missing.is_empty() {
        let _ = facade::block_on(engine.rollback(transaction));
        let missing: String = preview.missing.iter().collect();
        return Err(format!("no font of the block can draw {missing:?}").into());
    }
    facade::block_on(engine.commit(transaction, "Edit text".to_owned()))?;
    Ok(())
}

/// One page at one resolution of a pixel-diff check.
struct PageReport {
    /// From 1.
    page: usize,
    dpi: u32,
    region: Option<PixelRect>,
    differing: u64,
    margin_needed: Option<u32>,
    outside: u64,
    outside_bounds: Option<PixelRect>,
    /// Nothing outside the region differs, and on the edited page something inside does.
    passed: bool,
}

/// What `verify-edit` found.
struct Verification {
    pages: Vec<PageReport>,
    problems: Vec<String>,
}

impl Verification {
    fn passed(&self) -> bool {
        self.problems.is_empty()
    }

    /// The report in the form the edit cases print (crates/ferman-api/tests/edit_cases.rs).
    fn json(&self, edit: &EditArgs) -> serde_json::Value {
        let rect = |rect: Option<PixelRect>| {
            rect.map(
                |r| serde_json::json!({"x": r.x, "y": r.y, "width": r.width, "height": r.height}),
            )
        };
        let renders: Vec<_> = self
            .pages
            .iter()
            .map(|report| {
                serde_json::json!({
                    "page": report.page,
                    "dpi": report.dpi,
                    "region": rect(report.region),
                    "margin": EDIT_MARGIN,
                    "differing": report.differing,
                    "margin_needed": report.margin_needed,
                    "outside": report.outside,
                    "outside_bounds": rect(report.outside_bounds),
                    "passed": report.passed,
                })
            })
            .collect();
        serde_json::json!({
            "api_version": facade::api_version(),
            "page": edit.page.page,
            "block": edit.block,
            "passed": self.passed(),
            "problems": self.problems,
            "renders": renders,
        })
    }

    fn write_text(&self, out: &mut impl Write) -> io::Result<()> {
        for report in &self.pages {
            writeln!(
                out,
                "page {} at {} dpi: {} pixels differ, {} outside the region",
                report.page, report.dpi, report.differing, report.outside
            )?;
        }
        for problem in &self.problems {
            writeln!(out, "problem: {problem}")?;
        }
        writeln!(out, "{}", if self.passed() { "passed" } else { "failed" })
    }
}

/// Applies `edit` to `file`, saves it incrementally as `saved`, reopens that from disk and
/// compares every page before and after at each of [`RESOLUTIONS`]: on the edited page no pixel
/// may differ outside the block's box before and after grown by [`EDIT_MARGIN`], and some must
/// differ inside; on every other page none may differ. The original must be an exact prefix of
/// the saved file, with the same page count.
fn verify_edit(
    engine: &Engine,
    file: &Path,
    saved: &Path,
    edit: &EditArgs,
) -> Result<Verification, Box<dyn Error>> {
    let page = edit.page.index();
    // Opened twice: the edited one shows its revision once committed, the other stays as it was.
    let before = facade::block_on(engine.open(file.to_path_buf(), None))?;
    let edited = facade::block_on(engine.open(file.to_path_buf(), None))?;
    let original = std::fs::read(file)?;
    let old_blocks = facade::block_on(engine.text_blocks(before.id, page))?.blocks;
    let block = old_blocks
        .iter()
        .find(|block| block.id == BlockId(edit.block))
        .ok_or("the page has no block with this id")?;
    apply_edit(engine, edited.id, edit)?;
    facade::block_on(engine.save_as(
        edited.id,
        saved.to_path_buf(),
        facade::SaveOptions::default(),
        None,
    ))?;
    facade::block_on(engine.close(edited.id))?;

    // Everything after this reads the saved file from disk.
    let mut problems = Vec::new();
    if !std::fs::read(saved)?.starts_with(&original) {
        problems.push("the original is not a prefix of the saved file".to_owned());
    }
    let after = facade::block_on(engine.open(saved.to_path_buf(), None))?;
    // The block's box before, and after: the box of the block over it that reads the new text.
    let mut boxes = vec![block.frame];
    boxes.extend(
        facade::block_on(engine.text_blocks(after.id, page))?
            .blocks
            .iter()
            .filter(|new| intersects(new.frame, block.frame) && block_text(new) == edit.text)
            .map(|new| new.frame),
    );
    if boxes.len() < 2 {
        problems.push("no block reads the new text after the save".to_owned());
    }
    if before.pages.len() != after.pages.len() {
        problems.push(format!(
            "{} pages after the save, {} before",
            after.pages.len(),
            before.pages.len()
        ));
    }
    let mut pages = Vec::new();
    // Each page at its own size after the save, so a changed size fails the comparison.
    for (index, (old, new)) in before.pages.iter().zip(&after.pages).enumerate() {
        let number = u32::try_from(index)?;
        let shown = index.saturating_add(1);
        for dpi in RESOLUTIONS {
            let old = facade::block_on(engine.render_page(before.id, number, old.size, dpi))?;
            let new = facade::block_on(engine.render_page(after.id, number, new.size, dpi))?;
            let region = (number == page)
                .then(|| device_region(&boxes, old.scale))
                .flatten();
            let Some(diff) = compare(&old, &new, region, EDIT_MARGIN) else {
                problems.push(format!("page {shown} at {dpi} dpi changed size"));
                continue;
            };
            let drew_nothing = number == page && diff.differing == 0;
            if drew_nothing {
                problems.push(format!("page {shown} at {dpi} dpi: the edit drew nothing"));
            }
            if !diff.passed() {
                problems.push(format!(
                    "page {shown} at {dpi} dpi: {} pixels outside the region",
                    diff.outside
                ));
            }
            pages.push(PageReport {
                page: shown,
                dpi,
                region,
                differing: diff.differing,
                margin_needed: diff.margin_needed,
                outside: diff.outside,
                outside_bounds: diff.outside_bounds,
                passed: diff.passed() && !drew_nothing,
            });
        }
    }
    facade::block_on(engine.close(before.id))?;
    facade::block_on(engine.close(after.id))?;
    Ok(Verification { pages, problems })
}

fn intersects(a: [f32; 4], b: [f32; 4]) -> bool {
    a[0] < b[2] && b[0] < a[2] && a[1] < b[3] && b[1] < a[3]
}

/// Why a block cannot be edited, or `None` when it can.
fn not_editable_name(editability: Editability) -> Option<String> {
    match editability {
        Editability::Editable => None,
        Editability::NotEditable(reason) => Some(format!("{reason:?}")),
    }
}

/// A block's text, its lines joined by line feeds: the form `--text` takes.
fn block_text(block: &BlockInfo) -> String {
    let lines: Vec<&str> = block.lines.iter().map(|line| line.text.as_str()).collect();
    lines.join("\n")
}

fn blocks_json(blocks: &PageBlocks) -> serde_json::Value {
    let list: Vec<_> = blocks
        .blocks
        .iter()
        .map(|block| {
            serde_json::json!({
                "id": block.id.0,
                "bbox": block.frame,
                "editable": block.editability == Editability::Editable,
                "not_editable": not_editable_name(block.editability),
                "text": block_text(block),
            })
        })
        .collect();
    serde_json::json!({
        "api_version": facade::api_version(),
        "empty": blocks.empty.map(|reason| format!("{reason:?}")),
        "blocks": list,
    })
}

fn write_blocks_text(out: &mut impl Write, blocks: &PageBlocks) -> io::Result<()> {
    if let Some(reason) = blocks.empty {
        writeln!(out, "no text: {reason:?}")?;
    }
    for block in &blocks.blocks {
        let [left, top, right, bottom] = block.frame;
        let editability = not_editable_name(block.editability).map_or_else(
            || "editable".to_owned(),
            |reason| format!("not editable: {reason}"),
        );
        writeln!(
            out,
            "{}\t{left:.2} {top:.2} {right:.2} {bottom:.2}\t{editability}",
            block.id.0
        )?;
        for line in &block.lines {
            writeln!(out, "  {}", line.text)?;
        }
    }
    Ok(())
}

/// An engine that loads the PDFium library `--pdfium` names, or finds one.
fn start(pdfium: &Option<PathBuf>) -> Engine {
    let pdfium = pdfium
        .clone()
        .map_or(PdfiumLibrary::Find, PdfiumLibrary::Path);
    Engine::start(EngineConfig { pdfium })
}

/// Why a document opened read-only, as a stable lowercase name.
fn read_only_name(read_only: Option<&ReadOnly>) -> Option<&'static str> {
    read_only.map(|reason| match reason {
        ReadOnly::Repaired(_) => "repaired",
        ReadOnly::ParsersDisagree(_) => "parsers_disagree",
        ReadOnly::XfaOnly => "xfa_only",
    })
}

fn document_json(document: &OpenedDocument) -> serde_json::Value {
    let pages: Vec<_> = document
        .pages
        .iter()
        .map(|page| {
            serde_json::json!({
                "width": page.size.width,
                "height": page.size.height,
                "label": page.label,
            })
        })
        .collect();
    serde_json::json!({
        "api_version": facade::api_version(),
        "read_only": read_only_name(document.read_only.as_ref()),
        "direction": match document.direction {
            Direction::LeftToRight => "left_to_right",
            Direction::RightToLeft => "right_to_left",
        },
        "pages": pages,
    })
}

fn write_document_text(out: &mut impl Write, document: &OpenedDocument) -> io::Result<()> {
    writeln!(out, "pages: {}", document.pages.len())?;
    if let Some(reason) = read_only_name(document.read_only.as_ref()) {
        writeln!(out, "read-only: {reason}")?;
    }
    for (index, page) in document.pages.iter().enumerate() {
        let number = index.saturating_add(1);
        let (width, height) = (page.size.width, page.size.height);
        match &page.label {
            Some(label) => writeln!(out, "{number}\t{width:.2} x {height:.2} pt\t{label}")?,
            None => writeln!(out, "{number}\t{width:.2} x {height:.2} pt")?,
        }
    }
    Ok(())
}

fn write_info_text(out: &mut impl Write, info: &EngineInfo) -> io::Result<()> {
    writeln!(
        out,
        "ferman {} (api {})",
        info.app_version, info.api_version
    )?;
    writeln!(out, "build profile: {}", info.build_profile.as_str())?;
    match &info.pdfium {
        PdfiumStatus::NotLoaded => writeln!(out, "pdfium: not loaded")?,
        PdfiumStatus::Loaded { tag } => writeln!(out, "pdfium: loaded ({tag})")?,
        PdfiumStatus::Failed { reason } => writeln!(out, "pdfium: failed: {reason}")?,
    }
    writeln!(out, "engine crates:")?;
    for krate in &info.crates {
        writeln!(out, "  {} {}", krate.name, krate.version)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_printed_message_keeps_clap_exit_code() {
        assert_eq!(exit_code_after_print(Ok(()), 0), ExitCode::SUCCESS);
        assert_eq!(exit_code_after_print(Ok(()), 2), ExitCode::from(2));
    }

    #[test]
    fn a_failed_print_is_a_failure() {
        let closed = io::Error::from(io::ErrorKind::BrokenPipe);
        assert_eq!(exit_code_after_print(Err(closed), 0), ExitCode::FAILURE);
    }

    #[test]
    fn an_exit_code_outside_u8_is_a_failure() {
        assert_eq!(exit_code_after_print(Ok(()), 300), ExitCode::FAILURE);
        assert_eq!(exit_code_after_print(Ok(()), -1), ExitCode::FAILURE);
    }
}
