#!/usr/bin/env bash
# Self-test for tools/pdfium/fetch.sh: proves that a damaged or tampered archive is
# rejected. Works on temporary copies only; the real cache and lock are never changed.
#
# Usage: tools/pdfium/selftest.sh [--platform <id>]
#
# Needs one verified archive in build/pdfium/cache/ (default: the host platform's); if it
# is missing, fetch.sh downloads it first. Every other step is offline.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
fetch="$script_dir/fetch.sh"
lock="$script_dir/pdfium.lock"
cache="$repo_root/build/pdfium/cache"

platform=""
if [ $# -gt 0 ]; then
  if [ "$1" = --platform ] && [ $# -eq 2 ]; then
    platform=$2
  else
    echo "Usage: tools/pdfium/selftest.sh [--platform <id>]" >&2
    exit 2
  fi
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/ferman-pdfium-selftest.XXXXXX")
trap 'rm -rf "$work"' EXIT

passed=0
failed=0

pass() {
  echo "PASS $*"
  passed=$((passed + 1))
}

fail() {
  echo "FAIL $*" >&2
  failed=$((failed + 1))
}

# expect <status> <description> <command...>: runs the command, records its output in
# $work/out, and checks its exit status.
expect() {
  local want=$1 what=$2 got=0
  shift 2
  "$@" >"$work/out" 2>&1 || got=$?
  if [ "$got" -eq "$want" ]; then
    pass "$what (exit $got)"
  else
    fail "$what: expected exit $want, got $got"
    sed 's/^/    /' "$work/out" >&2
  fi
}

# expect_output <text> <description>: the last command's output contains <text>.
expect_output() {
  if grep -qF -- "$1" "$work/out"; then
    pass "$2"
  else
    fail "$2: output lacks '$1'"
    sed 's/^/    /' "$work/out" >&2
  fi
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum <"$1" | cut -d' ' -f1
  else
    shasum -a 256 <"$1" | cut -d' ' -f1
  fi
}

# file_url <dir>: a file:// URL curl understands on this system.
file_url() {
  if command -v cygpath >/dev/null 2>&1; then
    echo "file:///$(cygpath -m "$1")"
  else
    echo "file://$1"
  fi
}

# write_lock <out> <id> <url> <archive sha256>: a copy of the lock with another download
# URL and another archive hash for <id>.
write_lock() {
  tr -d '\r' <"$lock" | awk -v id="$2" -v url="$3" -v sha="$4" '
    $1 == "url" { print "url " url; next }
    $1 == "archive" && $2 == id { print $1, $2, sha, $4, $5; next }
    { print }
  ' >"$1"
}

# 1. Make sure a good archive is in the real cache, then copy it.
if [ -n "$platform" ]; then
  id=$platform
else
  id=$("$fetch" --host)
fi
if ! "$fetch" --platform "$id" --verify >/dev/null 2>&1; then
  "$fetch" --platform "$id" --dest "$work/unused" >/dev/null
fi
good="$cache/pdfium-$id.tgz"
[ -f "$good" ] || { echo "selftest: $good is missing" >&2; exit 1; }
echo "Self-test with pdfium-$id.tgz"

mkdir -p "$work/good" "$work/bad" "$work/empty"
cp "$good" "$work/good/"

# 2. A good copy verifies.
expect 0 "--verify accepts the pinned archive" "$fetch" --platform "$id" --cache "$work/good" --verify

# 3. One flipped byte makes --verify fail.
cp "$good" "$work/bad/"
bad="$work/bad/pdfium-$id.tgz"
size=$(wc -c <"$bad" | tr -d ' ')
offset=$((size / 2))
byte=$(od -An -tu1 -j "$offset" -N 1 "$bad" | tr -d ' ')
if [ "$byte" -eq 0 ]; then replacement='\377'; else replacement='\000'; fi
# shellcheck disable=SC2059 # the format is one of the two literal octal escapes above
printf "$replacement" | dd of="$bad" bs=1 seek="$offset" count=1 conv=notrunc 2>/dev/null
if [ "$(sha256_file "$bad")" = "$(sha256_file "$good")" ]; then
  echo "selftest: could not corrupt the copy" >&2
  exit 1
fi
expect 1 "--verify rejects a copy with one byte changed" "$fetch" --platform "$id" --cache "$work/bad" --verify
expect_output "SHA-256 mismatch" "the failure names the SHA-256 mismatch"

# 4. A missing archive makes --verify fail.
expect 1 "--verify fails when the archive is missing" "$fetch" --platform "$id" --cache "$work/empty" --verify

# 5. A download that does not match the lock fails and leaves nothing behind.
write_lock "$work/bad.lock" "$id" "$(file_url "$work/bad")" "$(sha256_file "$good")"
expect 1 "a download with the wrong SHA-256 is rejected" \
  "$fetch" --platform "$id" --lock "$work/bad.lock" --cache "$work/dl-bad" --dest "$work/dest-bad"
expect_output "SHA-256 mismatch" "the failure names the SHA-256 mismatch"
if [ -z "$(ls -A "$work/dl-bad" 2>/dev/null)" ] && [ ! -e "$work/dest-bad" ]; then
  pass "the rejected download left no archive, partial file or unpacked directory"
else
  fail "the rejected download left files behind"
  find "$work/dl-bad" "$work/dest-bad" 2>&1 | sed 's/^/    /' >&2
fi

# 6. The same download path accepts the good archive (so step 5 failed on the hash).
write_lock "$work/good.lock" "$id" "$(file_url "$work/good")" "$(sha256_file "$good")"
expect 0 "a download with the pinned SHA-256 is accepted and unpacked" \
  "$fetch" --platform "$id" --lock "$work/good.lock" --cache "$work/dl-good" --dest "$work/dest-good"
lib=$(tr -d '\r' <"$lock" | awk -v id="$id" '$1 == "archive" && $2 == id { print $4 }')
if [ -f "$work/dest-good/$lib" ] && [ -f "$work/dest-good/.ferman-pdfium" ]; then
  pass "the library is unpacked at $lib, next to the .ferman-pdfium marker"
else
  fail "the library or the marker is missing from the unpacked directory"
fi

# 7. Destinations: a trailing slash works, an earlier unpack is replaced, and anything
# else is refused and left untouched. All offline (the archive is in $work/good).
expect 0 "a destination with a trailing slash is unpacked" \
  "$fetch" --platform "$id" --cache "$work/good" --dest "$work/dest-slash/"
if [ -f "$work/dest-slash/$lib" ] && [ -z "$(cd "$work/dest-slash" && ls -d .*.partial.* .*.old.* 2>/dev/null)" ] &&
  [ -z "$(cd "$work" && ls -d .dest-slash.* 2>/dev/null)" ]; then
  pass "the library is in place and no staging directory is left inside or beside it"
else
  fail "the trailing-slash unpack is incomplete or left a staging directory"
  find "$work" -maxdepth 2 -name '*dest-slash*' 2>&1 | sed 's/^/    /' >&2
fi
echo "stale" >"$work/dest-slash/stale.txt"
expect 0 "an earlier unpack is replaced (also with a double trailing slash)" \
  "$fetch" --platform "$id" --cache "$work/good" --dest "$work/dest-slash//"
if [ -f "$work/dest-slash/$lib" ] && [ ! -e "$work/dest-slash/stale.txt" ]; then
  pass "the earlier unpack was replaced as a whole"
else
  fail "the earlier unpack was not replaced"
fi
mkdir -p "$work/empty-dest"
expect 0 "an empty directory is accepted as the destination" \
  "$fetch" --platform "$id" --cache "$work/good" --dest "$work/empty-dest"
mkdir -p "$work/foreign"
echo "mine" >"$work/foreign/mine.txt"
expect 1 "a non-empty directory without the marker is refused" \
  "$fetch" --platform "$id" --cache "$work/good" --dest "$work/foreign/"
expect_output "refusing to replace" "the failure says it refuses"
if [ "$(cd "$work/foreign" && ls -A)" = mine.txt ] && [ "$(cat "$work/foreign/mine.txt")" = mine ] &&
  [ -z "$(cd "$work" && ls -d .foreign.* 2>/dev/null)" ]; then
  pass "the refused directory is untouched and nothing was left beside it"
else
  fail "the refused directory was changed"
fi
echo "mine" >"$work/a-file"
expect 1 "a file as the destination is refused" \
  "$fetch" --platform "$id" --cache "$work/good" --dest "$work/a-file"
if [ "$(cat "$work/a-file")" = mine ]; then pass "the file is untouched"; else fail "the file was changed"; fi

# 8. An archive whose own hash is pinned but whose library differs is never unpacked.
mkdir -p "$work/libbad/src"
tar -xzf - -C "$work/libbad/src" <"$good"
printf 'x' >>"$work/libbad/src/$lib"
(cd "$work/libbad/src" && COPYFILE_DISABLE=1 tar -czf "$work/libbad/pdfium-$id.tgz" -- *)
write_lock "$work/libbad.lock" "$id" "$(file_url "$work/libbad")" "$(sha256_file "$work/libbad/pdfium-$id.tgz")"
expect 1 "an archive whose library does not match the lock is not unpacked" \
  "$fetch" --platform "$id" --lock "$work/libbad.lock" --cache "$work/libbad/cache" --dest "$work/dest-libbad"
expect_output "SHA-256 mismatch for $lib" "the failure names the library"
if [ ! -e "$work/dest-libbad" ] && [ -z "$(cd "$work" && ls -d .dest-libbad.* 2>/dev/null)" ]; then
  pass "the rejected archive left no unpacked or staging directory"
else
  fail "the rejected archive left a directory behind"
fi

# 9. The licence check accepts the real archive, ignores OS metadata files beside the
# committed copies, and rejects an extra file or an altered licence text.
expect 0 "--check-licenses accepts the pinned archive" \
  "$fetch" --platform "$id" --cache "$work/good" --check-licenses
cp -R "$repo_root/app/assets/licenses/pdfium" "$work/lic-meta"
touch "$work/lic-meta/.DS_Store" "$work/lic-meta/Thumbs.db" "$work/lic-meta/desktop.ini"
expect 0 "--check-licenses ignores .DS_Store, Thumbs.db and desktop.ini" \
  "$fetch" --platform "$id" --cache "$work/good" --check-licenses --licenses "$work/lic-meta"
echo "extra" >"$work/lic-meta/extra.txt"
expect 1 "--check-licenses rejects an extra committed file" \
  "$fetch" --platform "$id" --cache "$work/good" --check-licenses --licenses "$work/lic-meta"
expect_output "extra.txt" "the failure names the extra file"
mkdir -p "$work/repack/src" "$work/repack/cache"
tar -xzf - -C "$work/repack/src" LICENSE licenses <"$good"
echo "An extra line." >>"$work/repack/src/licenses/zlib.txt"
(cd "$work/repack/src" && COPYFILE_DISABLE=1 tar -czf "$work/repack/cache/pdfium-$id.tgz" LICENSE licenses)
write_lock "$work/repack.lock" "$id" "file:///unused" "$(sha256_file "$work/repack/cache/pdfium-$id.tgz")"
expect 1 "--check-licenses rejects an archive with an altered licence file" \
  "$fetch" --platform "$id" --lock "$work/repack.lock" --cache "$work/repack/cache" --check-licenses
expect_output "zlib.txt differs" "the failure names the altered file"

# 10. The mac-univ slice check, on any host, with a small stand-in universal library: a
# fat Mach-O header and two 16-byte slices whose hashes are pinned as the mac-x64 and
# mac-arm64 libraries.

# be32_bytes <n>: n as four big-endian bytes.
be32_bytes() {
  # shellcheck disable=SC2059 # the format is built from octal escapes only
  printf "$(printf '\\%03o\\%03o\\%03o\\%03o' $(($1 >> 24 & 255)) $(($1 >> 16 & 255)) $(($1 >> 8 & 255)) $(($1 & 255)))"
}

# fat_archive <dir> <x86_64 slice text> <arm64 slice text>: writes <dir>/pdfium-mac-univ.tgz
# holding lib/libpdfium.dylib, and the two slices as <dir>/x64 and <dir>/arm64.
fat_archive() {
  local dir=$1
  mkdir -p "$dir/src/lib"
  printf '%s' "$2" >"$dir/x64"
  printf '%s' "$3" >"$dir/arm64"
  {
    be32_bytes 3405691582 # FAT_MAGIC 0xcafebabe
    be32_bytes 2          # two slices
    # cputype, cpusubtype, offset, size, align: header 8 + 2 * 20 bytes, then the slices
    be32_bytes 16777223; be32_bytes 3; be32_bytes 48; be32_bytes 16; be32_bytes 0
    be32_bytes 16777228; be32_bytes 0; be32_bytes 64; be32_bytes 16; be32_bytes 0
    cat "$dir/x64" "$dir/arm64"
  } >"$dir/src/lib/libpdfium.dylib"
  (cd "$dir/src" && COPYFILE_DISABLE=1 tar -czf "$dir/pdfium-mac-univ.tgz" lib)
}

# univ_lock <out> <dir> <arm64 library sha256>: a lock pinning <dir>'s stand-in archive.
univ_lock() {
  local zero=0000000000000000000000000000000000000000000000000000000000000000
  {
    echo "tag chromium/0"
    echo "version 0"
    echo "url file:///unused"
    echo "archive mac-x64 $zero lib/libpdfium.dylib $(sha256_file "$2/x64")"
    echo "archive mac-arm64 $zero lib/libpdfium.dylib $3"
    echo "archive mac-univ $(sha256_file "$2/pdfium-mac-univ.tgz") lib/libpdfium.dylib $(sha256_file "$2/src/lib/libpdfium.dylib")"
  } >"$1"
}

fat_archive "$work/univ-good" "x86_64 slice 001" "arm64 slice 0002"
univ_lock "$work/univ-good.lock" "$work/univ-good" "$(sha256_file "$work/univ-good/arm64")"
expect 0 "a universal library whose slices equal the pinned thin libraries is unpacked" \
  "$fetch" --platform mac-univ --lock "$work/univ-good.lock" --cache "$work/univ-good" --dest "$work/dest-univ"
expect_output "universal library = mac-x64 + mac-arm64 slices" "the slice check ran"
fat_archive "$work/univ-bad" "x86_64 slice 001" "arm64 slice 0003"
univ_lock "$work/univ-bad.lock" "$work/univ-bad" "$(sha256_file "$work/univ-good/arm64")"
expect 1 "a universal library with a changed arm64 slice is rejected" \
  "$fetch" --platform mac-univ --lock "$work/univ-bad.lock" --cache "$work/univ-bad" --dest "$work/dest-univ-bad"
expect_output "SHA-256 mismatch for the arm64 slice" "the failure names the arm64 slice"
if [ ! -e "$work/dest-univ-bad" ]; then
  pass "the rejected universal library left no unpacked directory"
else
  fail "the rejected universal library left an unpacked directory"
fi

# 11. Usage errors.
expect 2 "an unknown platform id is a usage error" "$fetch" --platform no-such-os --verify

echo "selftest: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
