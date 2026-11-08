#!/bin/sh
# Builds ferman-mcp, the byte pump an AI client starts (ADR 0019), for each architecture of the
# build and puts it in Ferman.app/Contents/MacOS. It holds no PDF code. The Runner target's
# "Build ferman-mcp" phase runs it; signing for distribution waits for M5, so it is signed here
# with the build's identity, ad hoc when there is none, as the app's seal needs.
set -eu
export PATH="$HOME/.cargo/bin:$PATH"
repo="$PROJECT_DIR/../.."
target_dir="$TARGET_TEMP_DIR/ferman-mcp"
out="$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/ferman-mcp"
slices=""
for arch in $ARCHS; do
  case "$arch" in
    arm64) triple=aarch64-apple-darwin ;;
    x86_64) triple=x86_64-apple-darwin ;;
    *) echo "error: ferman-mcp: no Rust target for $arch" >&2; exit 1 ;;
  esac
  # From the repository root, so rust-toolchain.toml picks the toolchain.
  (cd "$repo" && cargo build --release --locked -p ferman-mcp --target "$triple" --target-dir "$target_dir")
  slices="$slices $target_dir/$triple/release/ferman-mcp"
done
mkdir -p "$(dirname "$out")"
# shellcheck disable=SC2086
lipo -create $slices -output "$out"
codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$out"
