//! The `ferman` command line.
//!
//! A tool for tests and power users on the same facade as the app (ADR 0003). It uses ferman-api
//! with the `frb` feature off, so it carries no bridge code. Output is human-readable by default
//! and JSON with `--json`; the JSON carries the API version (docs/ARCHITECTURE.md §2.3).
//!
//! M1 has two commands: `ferman --version` and `ferman info [--json] [--pdfium <path>]`. `info`
//! starts an engine of its own and reports whether PDFium loaded; a missing or broken library is
//! reported, not an error. Errors print one short line to standard error and exit with status 1;
//! argument errors exit with status 2. A failed write, including of `--version` or `--help`, exits
//! with status 1.
#![forbid(unsafe_code)]

use std::error::Error;
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::ExitCode;

use clap::{CommandFactory, FromArgMatches, Parser, Subcommand};
use ferman_api::facade::{self, Engine, EngineConfig, EngineInfo, PdfiumLibrary, PdfiumStatus};

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
}

fn main() -> ExitCode {
    let cli = match parse_args() {
        Ok(cli) => cli,
        Err(code) => return code,
    };
    match run(&cli) {
        Ok(()) => ExitCode::SUCCESS,
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

fn run(cli: &Cli) -> Result<(), Box<dyn Error>> {
    match &cli.command {
        Command::Info { json, pdfium } => {
            let pdfium = pdfium
                .clone()
                .map_or(PdfiumLibrary::Find, PdfiumLibrary::Path);
            // An engine of its own, so `--pdfium` applies; dropping it stops the render thread.
            let engine = Engine::start(EngineConfig { pdfium });
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
