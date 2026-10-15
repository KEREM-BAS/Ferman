//! End-to-end tests of the `ferman` binary.

// Test code may panic (clippy.toml), but clippy exempts only `#[test]` functions, not the helpers
// of an integration-test crate.
#![allow(clippy::panic)]

use std::process::{Command, Output, Stdio};

use ferman_api::facade::{API_VERSION, APP_VERSION};

fn ferman(args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_ferman"))
        .args(args)
        .output()
        .unwrap_or_else(|err| panic!("cannot run ferman: {err}"))
}

fn stdout(output: &Output) -> &str {
    std::str::from_utf8(&output.stdout).unwrap_or_else(|err| panic!("stdout is not UTF-8: {err}"))
}

fn stderr(output: &Output) -> &str {
    std::str::from_utf8(&output.stderr).unwrap_or_else(|err| panic!("stderr is not UTF-8: {err}"))
}

#[test]
fn version_prints_app_and_api_version() {
    let expected = format!(
        "ferman {APP_VERSION} (api {}.{})\n",
        API_VERSION.major, API_VERSION.minor
    );
    for flag in ["--version", "-V"] {
        let output = ferman(&[flag]);
        assert!(output.status.success(), "{flag}: {}", stderr(&output));
        assert_eq!(stdout(&output), expected, "{flag}");
        assert_eq!(stderr(&output), "", "{flag}");
    }
}

#[test]
fn version_and_help_fail_when_stdout_is_closed() {
    for flag in ["--version", "--help"] {
        // A pipe whose read end is already closed: every write to it fails.
        let (reader, writer) =
            std::io::pipe().unwrap_or_else(|err| panic!("cannot create a pipe: {err}"));
        drop(reader);
        let status = Command::new(env!("CARGO_BIN_EXE_ferman"))
            .arg(flag)
            .stdout(writer)
            .stderr(Stdio::null())
            .status()
            .unwrap_or_else(|err| panic!("cannot run ferman: {err}"));
        assert_eq!(status.code(), Some(1), "{flag}");
    }
}

#[test]
fn version_is_the_workspace_version() {
    assert_eq!(APP_VERSION, env!("CARGO_PKG_VERSION"));
}

#[test]
fn info_json_matches_the_snapshot() {
    let output = ferman(&["info", "--json"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let text = stdout(&output);

    // Check the values that change between builds, then redact them for the snapshot.
    let json: serde_json::Value = serde_json::from_str(text).unwrap();
    assert_eq!(json["app_version"], APP_VERSION);
    assert_eq!(json["api_version"]["major"], API_VERSION.major);
    assert_eq!(json["api_version"]["minor"], API_VERSION.minor);
    let crates = json["crates"].as_array().unwrap();
    assert_eq!(crates.len(), 6);
    assert!(crates.iter().all(|c| c["version"] == APP_VERSION));
    let profile = json["build_profile"].as_str().unwrap();
    assert!(matches!(profile, "debug" | "release"), "{profile}");

    let redacted = text
        .replace(&format!("\"{APP_VERSION}\""), "\"[version]\"")
        .replace(
            &format!("\"build_profile\": \"{profile}\""),
            "\"build_profile\": \"[profile]\"",
        );
    insta::assert_snapshot!("info_json", redacted);
}

#[test]
fn info_prints_text_by_default() {
    let output = ferman(&["info"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let text = stdout(&output);
    assert!(
        text.starts_with(&format!("ferman {APP_VERSION} (api {API_VERSION})\n")),
        "{text}"
    );
    assert!(text.contains("\npdfium: not loaded\n"), "{text}");
    assert!(
        text.contains(&format!("\n  ferman-core {APP_VERSION}\n")),
        "{text}"
    );
}

#[test]
fn an_unknown_command_fails_without_a_panic() {
    let output = ferman(&["frobnicate"]);
    assert_eq!(output.status.code(), Some(2));
    assert_eq!(stdout(&output), "");
    let err = stderr(&output);
    assert!(err.contains("error"), "{err}");
    assert!(!err.contains("panicked"), "{err}");
}

#[test]
fn no_arguments_print_usage_and_fail() {
    let output = ferman(&[]);
    assert_eq!(output.status.code(), Some(2));
    assert!(
        stderr(&output).contains("Usage: ferman"),
        "{}",
        stderr(&output)
    );
}
