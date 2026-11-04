//! End-to-end tests of the `ferman` binary.

// Test code may panic (clippy.toml), but clippy exempts only `#[test]` functions, not the helpers
// of an integration-test crate.
#![allow(clippy::panic, clippy::unwrap_used)]

use std::process::{Command, Output, Stdio};

use ferman_api::facade::{API_VERSION, APP_VERSION, PDFIUM_PATH_ENV};

/// Runs ferman without FERMAN_PDFIUM_PATH, so the result does not depend on the caller's shell:
/// PDFium then loads only through `--pdfium` (nothing is bundled next to the test binary).
fn ferman(args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_ferman"))
        .args(args)
        .env_remove(PDFIUM_PATH_ENV)
        .output()
        .unwrap_or_else(|err| panic!("cannot run ferman: {err}"))
}

/// The PDFium library named by FERMAN_PDFIUM_PATH, for the tests that need it.
fn pdfium_path() -> String {
    std::env::var(PDFIUM_PATH_ENV)
        .ok()
        .filter(|path| !path.is_empty())
        .unwrap_or_else(|| panic!("{PDFIUM_PATH_ENV} must name the PDFium library"))
}

/// The JSON of `ferman info --json` with the values that change between builds checked and then
/// redacted, for a snapshot.
fn redacted_info_json(output: &Output) -> String {
    assert!(output.status.success(), "{}", stderr(output));
    let text = stdout(output);

    let json: serde_json::Value = serde_json::from_str(text)
        .unwrap_or_else(|err| panic!("info --json printed invalid JSON: {err}"));
    assert_eq!(json["app_version"], APP_VERSION);
    assert_eq!(json["api_version"]["major"], API_VERSION.major);
    assert_eq!(json["api_version"]["minor"], API_VERSION.minor);
    let crates = json["crates"]
        .as_array()
        .unwrap_or_else(|| panic!("no crates array: {json}"));
    assert_eq!(crates.len(), 6);
    assert!(crates.iter().all(|c| c["version"] == APP_VERSION));
    let profile = json["build_profile"]
        .as_str()
        .unwrap_or_else(|| panic!("no build profile: {json}"));
    assert!(matches!(profile, "debug" | "release"), "{profile}");

    text.replace(&format!("\"{APP_VERSION}\""), "\"[version]\"")
        .replace(
            &format!("\"build_profile\": \"{profile}\""),
            "\"build_profile\": \"[profile]\"",
        )
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
    insta::assert_snapshot!("info_json", redacted_info_json(&output));
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn info_json_with_pdfium_matches_the_snapshot() {
    let output = ferman(&["info", "--json", "--pdfium", &pdfium_path()]);
    insta::assert_snapshot!("info_json_pdfium_loaded", redacted_info_json(&output));
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn info_finds_pdfium_through_the_environment() {
    let output = Command::new(env!("CARGO_BIN_EXE_ferman"))
        .args(["info"])
        .env(PDFIUM_PATH_ENV, pdfium_path())
        .output()
        .unwrap();
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stdout(&output).contains("\npdfium: loaded (chromium/7881)\n"),
        "{}",
        stdout(&output)
    );
}

#[test]
fn info_reports_a_missing_pdfium_and_still_succeeds() {
    let missing = std::env::temp_dir()
        .join(format!("ferman-cli-missing-{}", std::process::id()))
        .join("libpdfium.so");
    let missing = missing.to_str().unwrap();
    let output = ferman(&["info", "--json", "--pdfium", missing]);
    assert!(output.status.success(), "{}", stderr(&output));
    let json: serde_json::Value = serde_json::from_str(stdout(&output)).unwrap();
    assert_eq!(json["pdfium"]["state"], "failed");
    let reason = json["pdfium"]["reason"].as_str().unwrap();
    assert!(
        reason.starts_with("cannot load the PDFium library"),
        "{reason}"
    );
    assert!(!reason.contains("ferman-cli-missing"), "{reason}");

    let output = ferman(&["info", "--pdfium", missing]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stdout(&output).contains("\npdfium: failed: cannot load the PDFium library"),
        "{}",
        stdout(&output)
    );
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

fn corpus(name: &str) -> String {
    format!(
        "{}/../../tests/corpus/generated/{name}.pdf",
        env!("CARGO_MANIFEST_DIR")
    )
}

#[test]
fn open_reports_why_a_file_does_not_open() {
    let output = ferman(&["open", &corpus("no-such-file")]);
    assert_eq!(output.status.code(), Some(1));
    assert_eq!(stdout(&output), "");
    let err = stderr(&output);
    assert!(err.contains("not_found [errorFileNotFound]"), "{err}");
    assert!(!err.contains("no-such-file"), "{err}");
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn open_prints_pages_and_the_read_only_reason() {
    let pdfium = pdfium_path();
    let output = ferman(&["open", &corpus("tez-tr"), "--pdfium", &pdfium]);
    assert!(output.status.success(), "{}", stderr(&output));
    let text = stdout(&output);
    assert!(text.starts_with("pages: 64\n1\t"), "{text}");
    assert!(text.contains(" pt\ti\n"), "{text}");

    let output = ferman(&[
        "open",
        &corpus("disagree-pages"),
        "--json",
        "--pdfium",
        &pdfium,
    ]);
    assert!(output.status.success(), "{}", stderr(&output));
    let json: serde_json::Value = serde_json::from_str(stdout(&output))
        .unwrap_or_else(|err| panic!("open --json printed invalid JSON: {err}"));
    assert_eq!(json["read_only"], "parsers_disagree");
    assert_eq!(json["direction"], "left_to_right");
    assert_eq!(json["api_version"]["major"], API_VERSION.major);
    assert_eq!(json["pages"].as_array().map(Vec::len), Some(3));
}

#[test]
fn edit_commands_reject_bad_arguments() {
    let file = corpus("edit-e04-differences");
    for args in [
        &["blocks", &file, "--page", "0"][..],
        &["edit", &file, "--page", "1", "--block", "x", "--text", "a"],
        &["verify-edit", &file, "--page", "1", "--text", "a"],
        &["save", &file],
    ] {
        let output = ferman(args);
        assert_eq!(output.status.code(), Some(2), "{args:?}");
        assert!(!stderr(&output).contains("panicked"), "{args:?}");
    }
}

#[test]
fn edit_and_save_report_a_missing_file() {
    let missing = corpus("no-such-file");
    let out = std::env::temp_dir().join(format!("ferman-cli-unsaved-{}.pdf", std::process::id()));
    let out = out.to_str().unwrap();
    for args in [
        &["save", &missing, "-o", out][..],
        &[
            "edit", &missing, "--page", "1", "--block", "1", "--text", "a", "-o", out,
        ],
        &[
            "verify-edit",
            &missing,
            "--page",
            "1",
            "--block",
            "1",
            "--text",
            "a",
        ],
    ] {
        let output = ferman(args);
        assert_eq!(output.status.code(), Some(1), "{args:?}");
        assert!(stderr(&output).contains("not_found"), "{}", stderr(&output));
    }
    assert!(!std::path::Path::new(out).exists());
}

/// The E04 file's block that holds `needle`: its id and text, from `ferman blocks --json`.
fn e04_block(file: &str, pdfium: &str, needle: &str) -> (String, String) {
    let output = ferman(&["blocks", file, "--page", "1", "--json", "--pdfium", pdfium]);
    assert!(output.status.success(), "{}", stderr(&output));
    let json: serde_json::Value = serde_json::from_str(stdout(&output)).unwrap();
    assert_eq!(json["api_version"]["major"], API_VERSION.major);
    let block = json["blocks"]
        .as_array()
        .unwrap()
        .iter()
        .find(|block| block["text"].as_str().unwrap().contains(needle))
        .unwrap_or_else(|| panic!("no block with {needle:?}: {json}"));
    assert_eq!(block["editable"], true);
    assert_eq!(block["bbox"].as_array().map(Vec::len), Some(4));
    (
        block["id"].as_u64().unwrap().to_string(),
        block["text"].as_str().unwrap().to_owned(),
    )
}

fn temp_pdf(name: &str) -> std::path::PathBuf {
    std::env::temp_dir().join(format!("ferman-cli-{name}-{}.pdf", std::process::id()))
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn edit_saves_an_incremental_update() {
    let pdfium = pdfium_path();
    let file = corpus("edit-e04-differences");
    let (id, text) = e04_block(&file, &pdfium, "Moda Cad. No: 18");
    let new = text.replacen("Moda Cad. No: 18", "Moda Cd. 18", 1);
    let out = temp_pdf("edited");
    let out_str = out.to_str().unwrap();
    let output = ferman(&[
        "edit", &file, "--page", "1", "--block", &id, "--text", &new, "-o", out_str, "--pdfium",
        &pdfium,
    ]);
    assert!(output.status.success(), "{}", stderr(&output));
    let original = std::fs::read(&file).unwrap();
    let saved = std::fs::read(&out).unwrap();
    assert!(saved.len() > original.len() && saved.starts_with(&original));
    let (_, after) = e04_block(out_str, &pdfium, "Moda Cd. 18");
    assert_eq!(after, new);

    // Without -o the file itself gets the update.
    let in_place = temp_pdf("in-place");
    std::fs::copy(&file, &in_place).unwrap();
    let in_place_str = in_place.to_str().unwrap();
    let output = ferman(&[
        "edit",
        in_place_str,
        "--page",
        "1",
        "--block",
        &id,
        "--text",
        &new,
        "--pdfium",
        &pdfium,
    ]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(std::fs::read(&in_place).unwrap().starts_with(&original));
    assert_eq!(e04_block(in_place_str, &pdfium, "Moda Cd. 18").1, new);
    std::fs::remove_file(&in_place).unwrap();

    // A block the page does not have.
    let output = ferman(&[
        "edit", &file, "--page", "1", "--block", "1", "--text", "a", "-o", out_str, "--pdfium",
        &pdfium,
    ]);
    assert_eq!(output.status.code(), Some(1));
    assert!(stderr(&output).contains("not_found"), "{}", stderr(&output));
    std::fs::remove_file(&out).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn save_writes_a_copy_that_opens() {
    let pdfium = pdfium_path();
    let file = corpus("edit-e04-differences");
    let out = temp_pdf("copy");
    let out_str = out.to_str().unwrap();
    let output = ferman(&["save", &file, "-o", out_str, "--pdfium", &pdfium]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        std::fs::read(&out)
            .unwrap()
            .starts_with(&std::fs::read(&file).unwrap())
    );
    let output = ferman(&["open", out_str, "--pdfium", &pdfium]);
    assert!(output.status.success(), "{}", stderr(&output));
    std::fs::remove_file(&out).unwrap();
}

#[test]
#[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
fn verify_edit_passes_an_edit_and_fails_one_that_draws_nothing() {
    let pdfium = pdfium_path();
    let file = corpus("edit-e04-differences");
    let (id, text) = e04_block(&file, &pdfium, "Moda Cad. No: 18");
    let new = text.replacen("Moda Cad. No: 18", "Moda Cd. 18", 1);
    let verify = |text: &str| {
        ferman(&[
            "verify-edit",
            &file,
            "--page",
            "1",
            "--block",
            &id,
            "--text",
            text,
            "--json",
            "--pdfium",
            &pdfium,
        ])
    };

    let output = verify(&new);
    assert!(output.status.success(), "{}", stdout(&output));
    let json: serde_json::Value = serde_json::from_str(stdout(&output)).unwrap();
    assert_eq!(json["passed"], true, "{json}");
    let renders = json["renders"].as_array().unwrap();
    assert_eq!(renders.len(), 3);
    for render in renders {
        assert_eq!(render["outside"], 0, "{render}");
        assert_eq!(render["passed"], true, "{render}");
        assert!(render["differing"].as_u64().unwrap() > 0, "{render}");
        assert!(render["region"].is_object(), "{render}");
    }
    let dpis: Vec<_> = renders.iter().map(|render| render["dpi"].clone()).collect();
    assert_eq!(dpis, [72, 150, 300]);

    // The same text again changes nothing, so the check has nothing to test.
    let output = verify(&text);
    assert_eq!(output.status.code(), Some(1), "{}", stdout(&output));
    let json: serde_json::Value = serde_json::from_str(stdout(&output)).unwrap();
    assert_eq!(json["passed"], false);
    for render in json["renders"].as_array().unwrap() {
        assert_eq!(render["passed"], false, "{render}");
    }
    assert!(
        json["problems"].to_string().contains("drew nothing"),
        "{json}"
    );
}
