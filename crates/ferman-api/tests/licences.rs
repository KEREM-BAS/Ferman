//! Settings › Licences lists exactly the Rust crates that ship (M4 plan, question 7): the crates of
//! `app/assets/licenses/rust/crates.json` (tools/licenses/generate.sh) against the graph cargo
//! resolves for a build of ferman-api with the bridge on the desktop targets.
// Test helpers fail loudly.
#![allow(clippy::panic, clippy::unwrap_used, clippy::expect_used)]

use std::collections::BTreeSet;
use std::path::PathBuf;
use std::process::Command;

use serde_json::Value;

/// tools/licenses/about.toml's targets.
const TARGETS: [&str; 6] = [
    "aarch64-apple-darwin",
    "x86_64-apple-darwin",
    "x86_64-pc-windows-msvc",
    "aarch64-pc-windows-msvc",
    "x86_64-unknown-linux-gnu",
    "aarch64-unknown-linux-gnu",
];

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

/// "name version" of every crate a build of ferman-api with `frb` links, as the app's build makes
/// it: `cargo tree -p` resolves ferman-api's features alone, where `cargo metadata` would unify the
/// whole workspace's and list crates the app never builds. Normal dependencies only; Ferman's own
/// crates are left out.
fn shipped() -> BTreeSet<String> {
    // One target at a time: features resolve per target, so a crate one system's build enables
    // (chrono's clock, through another crate, on macOS) must not count for the others.
    TARGETS.iter().flat_map(|target| tree(target)).collect()
}

fn tree(target: &str) -> BTreeSet<String> {
    let output = Command::new(env!("CARGO"))
        .current_dir(root())
        .args([
            "tree",
            "-p",
            "ferman-api",
            "--features",
            "frb",
            "-e",
            "normal",
            "--locked",
            "--offline",
            "--prefix",
            "none",
            "-f",
            "{p}",
            "--target",
            target,
        ])
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "cargo tree failed for {target}: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    String::from_utf8(output.stdout)
        .unwrap()
        .lines()
        .filter_map(|line| {
            let mut words = line.split_whitespace();
            let name = words.next()?;
            let version = words.next()?.strip_prefix('v')?;
            (!name.starts_with("ferman-")).then(|| format!("{name} {version}"))
        })
        .collect()
}

/// "name version" of every crate the licences asset names.
fn listed() -> BTreeSet<String> {
    let asset = std::fs::read(root().join("app/assets/licenses/rust/crates.json")).unwrap();
    let notices: Value = serde_json::from_slice(&asset).unwrap();
    notices["licences"]
        .as_array()
        .unwrap()
        .iter()
        .flat_map(|licence| licence["crates"].as_array().unwrap())
        .map(|name| name.as_str().unwrap().to_owned())
        .collect()
}

#[test]
fn the_licences_list_every_shipped_crate_and_no_other() {
    let shipped = shipped();
    let listed = listed();
    let missing: Vec<_> = shipped.difference(&listed).collect();
    let extra: Vec<_> = listed.difference(&shipped).collect();
    assert!(
        missing.is_empty() && extra.is_empty(),
        "run bash tools/licenses/generate.sh: missing {missing:?}, not shipped {extra:?}"
    );
    assert_eq!(listed.len(), shipped.len());
}
