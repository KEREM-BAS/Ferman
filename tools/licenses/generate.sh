#!/usr/bin/env bash
# The Rust crates' notices for Settings › Licences: cargo-about 0.9.2 over ferman-api with the
# bridge (what the app links), kept to the crates a desktop build links (cargo tree per target)
# and reduced to app/assets/licenses/rust/crates.json.
#
#   bash tools/licenses/generate.sh           # write the asset
#   bash tools/licenses/generate.sh --check   # fail when it is stale
#
# Needs cargo-about 0.9.2 (cargo install cargo-about --version 0.9.2 --locked --features cli).
# ferman-api's test `licences` checks the asset against the same graph.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
about="$(mktemp)"
tree="$(mktemp)"
trap 'rm -f "$about" "$tree"' EXIT

cargo about generate --format json --offline --locked \
  -c "$root/tools/licenses/about.toml" \
  -m "$root/crates/ferman-api/Cargo.toml" --features frb \
  -o "$about"
# about.toml's targets, one at a time: features resolve per target.
for target in aarch64-apple-darwin x86_64-apple-darwin x86_64-pc-windows-msvc \
  aarch64-pc-windows-msvc x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu; do
  cargo tree --manifest-path "$root/Cargo.toml" -p ferman-api --features frb -e normal \
    --locked --offline --prefix none -f '{p}' --target "$target" >>"$tree"
done
python3 -I "$root/tools/licenses/notices.py" "$about" "$tree" \
  "$root/app/assets/licenses/rust/crates.json" "$@"
