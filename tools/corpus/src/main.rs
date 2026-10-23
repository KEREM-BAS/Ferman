//! `ferman-corpus`: makes and checks Ferman's test corpus (tools/corpus/README.md).
#![forbid(unsafe_code)]

use ferman_corpus::{CORPUS_DIR, GENERATORS, Generator, check, generate};
use std::io::Write;
use std::path::PathBuf;
use std::process::ExitCode;

const USAGE: &str = "\
Usage: ferman-corpus [generate | check | list] [--only <name>]... [--root <dir>]

  generate  write the generated files that are missing or differ (the default)
  check     exit 1 if a generated file is stale or a corpus file and its README row disagree
  list      print the generators

  --only <name>  one generator (repeatable); check still reads every corpus file
  --root <dir>   the repository root (default: the checkout this tool was built in)";

/// Exit codes, as the other tools use them.
const STALE: u8 = 1;
const FAILED: u8 = 2;
const USAGE_ERROR: u8 = 64;

#[derive(Debug, PartialEq, Eq)]
enum Command {
    Generate,
    Check,
    List,
}

#[derive(Debug)]
struct Options {
    command: Command,
    only: Vec<String>,
    root: PathBuf,
}

fn parse(args: &[String]) -> Result<Option<Options>, String> {
    let mut command = None;
    let mut only = Vec::new();
    let mut root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
    let mut args = args.iter();
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-h" | "--help" => return Ok(None),
            "--only" => only.push(args.next().ok_or("--only needs a generator name")?.clone()),
            "--root" => root = PathBuf::from(args.next().ok_or("--root needs a directory")?),
            "generate" | "check" | "list" if command.is_none() => {
                command = Some(match arg.as_str() {
                    "check" => Command::Check,
                    "list" => Command::List,
                    _ => Command::Generate,
                });
            }
            other => return Err(format!("unexpected argument: {other}")),
        }
    }
    Ok(Some(Options {
        command: command.unwrap_or(Command::Generate),
        only,
        root,
    }))
}

fn select(only: &[String]) -> Result<Vec<Generator>, String> {
    if only.is_empty() {
        return Ok(GENERATORS.to_vec());
    }
    only.iter()
        .map(|name| {
            GENERATORS
                .iter()
                .find(|generator| generator.name == name)
                .copied()
                .ok_or_else(|| format!("no generator named {name}"))
        })
        .collect()
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut out = std::io::stdout().lock();
    let mut err = std::io::stderr().lock();
    let options = match parse(&args) {
        Ok(Some(options)) => options,
        Ok(None) => {
            let _ = writeln!(out, "{USAGE}");
            return ExitCode::SUCCESS;
        }
        Err(message) => {
            let _ = writeln!(err, "ferman-corpus: {message}\n\n{USAGE}");
            return ExitCode::from(USAGE_ERROR);
        }
    };
    let generators = match select(&options.only) {
        Ok(generators) => generators,
        Err(message) => {
            let _ = writeln!(err, "ferman-corpus: {message}");
            return ExitCode::from(USAGE_ERROR);
        }
    };
    match options.command {
        Command::List => {
            for generator in &generators {
                let _ = writeln!(out, "{}", generator.name);
            }
            ExitCode::SUCCESS
        }
        Command::Generate => match generate(&options.root, &generators) {
            Ok(written) => {
                for path in &written {
                    let _ = writeln!(out, "wrote {CORPUS_DIR}/{path}");
                }
                let _ = writeln!(out, "{} file(s) written", written.len());
                ExitCode::SUCCESS
            }
            Err(message) => {
                let _ = writeln!(err, "ferman-corpus: {message}");
                ExitCode::from(FAILED)
            }
        },
        Command::Check => match check(&options.root, &generators) {
            Ok(problems) if problems.is_empty() => {
                let _ = writeln!(
                    out,
                    "corpus ok: every file has its row, {} generator(s) current",
                    generators.len()
                );
                ExitCode::SUCCESS
            }
            Ok(problems) => {
                for problem in &problems {
                    let _ = writeln!(err, "{CORPUS_DIR}/{problem}");
                }
                ExitCode::from(STALE)
            }
            Err(message) => {
                let _ = writeln!(err, "ferman-corpus: {message}");
                ExitCode::from(FAILED)
            }
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(list: &[&str]) -> Vec<String> {
        list.iter().map(|arg| (*arg).to_owned()).collect()
    }

    #[test]
    fn generate_is_the_default_command() {
        let options = parse(&[]).unwrap().unwrap();
        assert_eq!(options.command, Command::Generate);
    }

    #[test]
    fn reads_the_command_and_its_options() {
        let options = parse(&args(&["check", "--only", "kira-tr", "--root", "/r"]))
            .unwrap()
            .unwrap();
        assert_eq!(options.command, Command::Check);
        assert_eq!(options.only, ["kira-tr"]);
        assert_eq!(options.root, PathBuf::from("/r"));
    }

    #[test]
    fn rejects_unknown_arguments_and_missing_values() {
        assert!(parse(&args(&["check", "list"])).is_err());
        assert!(parse(&args(&["--only"])).is_err());
        assert!(parse(&args(&["--frobnicate"])).is_err());
        assert!(parse(&args(&["--help"])).unwrap().is_none());
    }

    #[test]
    fn an_unknown_generator_is_a_usage_error() {
        assert!(select(&args(&["no-such-file"])).is_err());
    }
}
