//! `ferman-mcp` without the app: it says so and exits with status 1, at once.
// Test helpers fail loudly.
#![allow(clippy::unwrap_used)]

use std::process::{Command, Stdio};

#[test]
fn without_the_app_it_says_so_and_exits_with_status_1() {
    let folder = std::env::temp_dir().join(format!("ferman-mcp-none-{}", std::process::id()));
    let output = Command::new(env!("CARGO_BIN_EXE_ferman-mcp"))
        .arg(&folder)
        .stdin(Stdio::null())
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    assert!(output.stdout.is_empty());
    let said = String::from_utf8(output.stderr).unwrap();
    assert!(said.contains("Ferman is not running"), "{said}");
}

#[test]
fn without_its_folder_it_shows_its_usage() {
    let output = Command::new(env!("CARGO_BIN_EXE_ferman-mcp"))
        .stdin(Stdio::null())
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(2));
}
