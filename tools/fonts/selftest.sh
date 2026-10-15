#!/usr/bin/env bash
# Self-test for tools/fonts/fetch.sh: proves that changed, missing or extra font files are
# rejected, and that a release zip or font that does not match fonts.lock is never
# installed. Offline; works on temporary copies only.
#
# Usage: tools/fonts/selftest.sh
#
# The install-path cases build a stand-in release zip with python3 and need unzip; they
# are skipped (and reported) when either is missing.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
fetch="$script_dir/fetch.sh"
lock="$script_dir/fonts.lock"
fonts="$repo_root/app/assets/fonts"

if [ $# -gt 0 ]; then
  echo "Usage: tools/fonts/selftest.sh" >&2
  exit 2
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/ferman-fonts-selftest.XXXXXX")
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

# fresh_copy <name>: a copy of the committed fonts at $work/<name>.
fresh_copy() {
  rm -rf "${work:?}/$1"
  cp -R "$fonts" "$work/$1"
}

# file_url <path>: a file:// URL curl understands on this system.
file_url() {
  if command -v cygpath >/dev/null 2>&1; then
    echo "file:///$(cygpath -m "$1")"
  else
    echo "file://$1"
  fi
}

regular="ibm-plex-sans/IBMPlexSans-Regular.ttf"
license="ibm-plex-sans/LICENSE.txt"

# 1. The committed fonts verify.
expect 0 "--verify-committed accepts the committed fonts" "$fetch" --verify-committed

# 2. One changed byte in a font.
fresh_copy changed
size=$(wc -c <"$work/changed/$regular" | tr -d ' ')
offset=$((size / 2))
byte=$(od -An -tu1 -j "$offset" -N 1 "$work/changed/$regular" | tr -d ' ')
if [ "$byte" -eq 0 ]; then replacement='\377'; else replacement='\000'; fi
# shellcheck disable=SC2059 # the format is one of the two literal octal escapes above
printf "$replacement" | dd of="$work/changed/$regular" bs=1 seek="$offset" count=1 conv=notrunc 2>/dev/null
expect 1 "a font with one byte changed is rejected" "$fetch" --verify-committed --dest "$work/changed"
expect_output "SHA-256 mismatch for plex-sans/IBMPlexSans-Regular.ttf" "the failure names the changed font"

# 3. A missing font.
fresh_copy missing
rm "$work/missing/$regular"
expect 1 "a missing font is rejected" "$fetch" --verify-committed --dest "$work/missing"
expect_output "IBMPlexSans-Regular.ttf is missing" "the failure names the missing font"

# 4. An extra file (for example a converted or subset font).
fresh_copy extra
cp "$work/extra/$regular" "$work/extra/ibm-plex-sans/IBMPlexSans-Subset.ttf"
expect 1 "a file that fonts.lock does not pin is rejected" "$fetch" --verify-committed --dest "$work/extra"
expect_output "IBMPlexSans-Subset.ttf" "the failure names the extra file"

# 5. OS metadata files that .gitignore also ignores are not counted as extra files.
fresh_copy meta
touch "$work/meta/.DS_Store" "$work/meta/ibm-plex-sans/.DS_Store" "$work/meta/ibm-plex-mono/Thumbs.db" \
  "$work/meta/ibm-plex-serif/desktop.ini"
expect 0 ".DS_Store, Thumbs.db and desktop.ini are ignored" "$fetch" --verify-committed --dest "$work/meta"

# 6. The licence check ignores line endings but not wording.
fresh_copy lf
tr -d '\r' <"$fonts/$license" >"$work/lf/$license"
expect 0 "a licence checked out with LF line endings is accepted" "$fetch" --verify-committed --dest "$work/lf"
fresh_copy wording
sed 's/Reserved Font Name/Font Name/' "$fonts/$license" >"$work/wording/$license"
expect 1 "a licence with changed wording is rejected" "$fetch" --verify-committed --dest "$work/wording"
expect_output "SHA-256 mismatch for plex-sans/LICENSE.txt" "the failure names the licence"

# 7. The install path, offline, with a stand-in release zip for one package.
python=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -I -c 'import zipfile' 2>/dev/null; then
    python=$candidate
    break
  fi
done
if [ -z "$python" ] || ! command -v unzip >/dev/null 2>&1; then
  echo "SKIP the install-path cases need python3 and unzip"
else
  pkg=plex-sans-hebrew
  src="$work/zipsrc/ibm-$pkg"
  mkdir -p "$src/fonts/complete/ttf" "$work/release"
  cp "$fonts/ibm-$pkg/LICENSE.txt" "$src/"
  cp "$fonts/ibm-$pkg/"*.ttf "$src/fonts/complete/ttf/"
  zip="$work/release/ibm-$pkg.zip"
  "$python" -I -m zipfile -c "$zip" "$src"
  zip_sha=$(sha256_file "$zip")
  url="$(file_url "$work/release")/ibm-{package}.zip"

  # write_lock <out> <zip sha256> [<font to give a wrong hash>]: a lock with only $pkg.
  write_lock() {
    tr -d '\r' <"$lock" | awk -v pkg="$pkg" -v url="$url" -v zsha="$2" -v bad="${3:-}" '
      $1 == "url" { print "url " url; next }
      $1 == "package" && $2 == pkg { print $1, $2, $3, zsha; next }
      $1 == "font" && $2 == pkg && $3 == bad { print $1, $2, $3, "0000000000000000000000000000000000000000000000000000000000000000"; next }
      ($1 == "license" || $1 == "font") && $2 == pkg { print; next }
    ' >"$1"
  }

  write_lock "$work/good.lock" "$zip_sha"
  expect 0 "a release zip with the pinned hashes installs" \
    "$fetch" --lock "$work/good.lock" --cache "$work/cache-good" --dest "$work/dest"
  if cmp -s "$work/dest/ibm-$pkg/IBMPlexSansHebrew-Regular.ttf" "$fonts/ibm-$pkg/IBMPlexSansHebrew-Regular.ttf"; then
    pass "the installed font is byte-identical to the release file"
  else
    fail "the installed font differs from the release file"
  fi

  before=$(cd "$work/dest" && find . -type f -exec cksum {} + | LC_ALL=C sort)
  write_lock "$work/bad-zip.lock" "1111111111111111111111111111111111111111111111111111111111111111"
  expect 1 "a release zip with the wrong SHA-256 is rejected" \
    "$fetch" --lock "$work/bad-zip.lock" --cache "$work/cache-bad" --dest "$work/dest"
  expect_output "SHA-256 mismatch for downloaded ibm-$pkg" "the failure names the zip"

  write_lock "$work/bad-font.lock" "$zip_sha" IBMPlexSansHebrew-Medium.ttf
  expect 1 "a font in the zip with the wrong SHA-256 is rejected" \
    "$fetch" --lock "$work/bad-font.lock" --cache "$work/cache-good" --dest "$work/dest"
  expect_output "SHA-256 mismatch for $pkg/IBMPlexSansHebrew-Medium.ttf" "the failure names the font"

  after=$(cd "$work/dest" && find . -type f -exec cksum {} + | LC_ALL=C sort)
  if [ "$before" = "$after" ]; then
    pass "the rejected installs left the installed fonts untouched"
  else
    fail "a rejected install changed the installed fonts"
  fi
fi

# 8. Usage errors.
expect 2 "an unknown option is a usage error" "$fetch" --no-such-option

echo "selftest: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
