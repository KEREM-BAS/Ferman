#!/usr/bin/env bash
# Downloads the four Unicode Character Database 15.0.0 files the casing tables come from into
# build/unicode/15.0.0/ and checks each against its pinned SHA-256 (skipped when a copy there
# already matches). See tools/unicode/README.md.
#
# Portable: bash 3.2 (macOS), Git Bash (Windows) and Linux, with curl and sha256sum or shasum.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dest="$script_dir/../../build/unicode/15.0.0"
base="https://www.unicode.org/Public/15.0.0/ucd"

pins="UnicodeData.txt 806e9aed65037197f1ec85e12be6e8cd870fc5608b4de0fffd990f689f376a73
SpecialCasing.txt 78b29c64b5840d25c11a9f31b665ee551b8a499eca6c70d770fcad7dd710f494
PropList.txt e05c0a2811d113dae4abd832884199a3ea8d187ee1b872d8240a788a96540bfd
DerivedCoreProperties.txt d367290bc0867e6b484c68370530bdd1a08b6b32404601b8c7accaf83e05628d"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

mkdir -p "$dest"
echo "$pins" | while read -r name pin; do
  file="$dest/$name"
  if [ -f "$file" ] && [ "$(sha256 "$file")" = "$pin" ]; then
    continue
  fi
  curl -sSfL --retry 3 -o "$file.part" "$base/$name"
  actual=$(sha256 "$file.part")
  if [ "$actual" != "$pin" ]; then
    rm -f "$file.part"
    echo "fetch.sh: $name has SHA-256 $actual, not the pinned $pin" >&2
    exit 1
  fi
  mv "$file.part" "$file"
done
echo "UCD 15.0.0 files are in build/unicode/15.0.0/."
