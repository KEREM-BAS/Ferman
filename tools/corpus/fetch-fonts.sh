#!/usr/bin/env bash
# Downloads the fonts in tools/corpus/fonts.lock into build/corpus-fonts/ and checks their
# SHA-256. A file already there with the right hash is kept. See tools/corpus/README.md.
#
# Portable on purpose: bash 3.2 (macOS), Git Bash (Windows) and Linux, using only curl, awk and
# sha256sum or shasum. curl honours HTTPS_PROXY.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
lock="$script_dir/fonts.lock"
dest="$repo_root/build/corpus-fonts"

if [ $# -gt 0 ]; then
  echo "Usage: tools/corpus/fetch-fonts.sh (no options)" >&2
  exit 2
fi

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

mkdir -p "$dest"
failed=0
while read -r kind name hash url; do
  case "$kind" in
    file) ;;
    *) continue ;;
  esac
  target="$dest/$name"
  if [ -f "$target" ] && [ "$(sha256 "$target")" = "$hash" ]; then
    echo "ok       $name"
    continue
  fi
  part="$target.part"
  rm -f "$part"
  if ! curl --fail --silent --show-error --location --retry 3 --output "$part" "$url"; then
    echo "fetch-fonts.sh: error: could not download $name from $url" >&2
    rm -f "$part"
    failed=1
    continue
  fi
  actual=$(sha256 "$part")
  if [ "$actual" != "$hash" ]; then
    echo "fetch-fonts.sh: error: $name has SHA-256 $actual, not $hash" >&2
    rm -f "$part"
    failed=1
    continue
  fi
  mv "$part" "$target"
  echo "fetched  $name"
done < <(grep -v '^[[:space:]]*#' "$lock")

exit "$failed"
