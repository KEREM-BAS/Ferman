#!/usr/bin/env bash
# Installs IBM's unmodified IBM Plex TTFs into app/assets/fonts/ from the release zips
# pinned in tools/fonts/fonts.lock, and checks the committed copies offline.
# See tools/fonts/README.md.
#
# Portable on purpose: bash 3.2 (macOS), Git Bash (Windows) and Linux, using only curl,
# unzip, awk, sed and sha256sum or shasum. curl honours HTTPS_PROXY.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)

lock="$script_dir/fonts.lock"
dest="$repo_root/app/assets/fonts"
cache="$repo_root/build/fonts/cache"
verify_committed=false

usage() {
  cat <<'EOF'
Usage: tools/fonts/fetch.sh [--verify-committed] [options]

Without options, downloads each pinned IBM Plex release zip into the cache (skipped when
a cached copy already matches its SHA-256), checks it, extracts the pinned TTFs and
LICENSE.txt, checks every file's SHA-256, and installs them unmodified in
app/assets/fonts/ibm-<package>/, replacing those folders.

Options:
  --verify-committed  Only check that the destination holds exactly the pinned files,
                      each with its pinned SHA-256. Offline; CI runs this. OS metadata
                      files (.DS_Store, Thumbs.db, desktop.ini) are ignored.
  --dest <dir>        Font directory. Default: app/assets/fonts/
  --cache <dir>       Zip cache. Default: build/fonts/cache/
  --lock <file>       Use another lock file (for tests). Default: tools/fonts/fonts.lock
  -h, --help          Show this help.

Exit status: 0 on success, 1 when a check or download fails, 2 on a usage error.
EOF
}

die() {
  echo "fetch.sh: error: $*" >&2
  exit 1
}

usage_error() {
  echo "fetch.sh: $*" >&2
  echo "Run 'tools/fonts/fetch.sh --help' for usage." >&2
  exit 2
}

need_value() {
  if [ "$2" -lt 2 ]; then
    usage_error "$1 needs a value"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --verify-committed) verify_committed=true; shift ;;
    --dest) need_value "$1" $#; dest=$2; shift 2 ;;
    --cache) need_value "$1" $#; cache=$2; shift 2 ;;
    --lock) need_value "$1" $#; lock=$2; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage_error "unknown argument: $1" ;;
  esac
done

# ---------------------------------------------------------------------------------------
# Temporary files, removed on exit.

part_file=""
staging=""

cleanup() {
  if [ -n "$part_file" ]; then rm -f "$part_file"; fi
  if [ -n "$staging" ]; then rm -rf "$staging"; fi
  return 0
}
trap cleanup EXIT

# ---------------------------------------------------------------------------------------
# Hashing and the lock file.

# Prints the lowercase hex SHA-256 of standard input.
sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  else
    die "neither sha256sum nor shasum is installed"
  fi
}

sha256_file() {
  sha256_stream <"$1"
}

# list_files <dir>: the files under <dir>, relative to it and sorted, leaving out the OS
# metadata files that .gitignore also ignores (.DS_Store, Thumbs.db, desktop.ini).
list_files() {
  (cd "$1" && find . -type f ! -name .DS_Store ! -name Thumbs.db ! -name desktop.ini) |
    sed 's#^\./##' | LC_ALL=C sort
}

# The SHA-256 of a licence text with CRLF line endings, as IBM releases it, whatever line
# endings the checkout gave the file.
sha256_crlf() {
  tr -d '\r' <"$1" | LC_ALL=C awk '{ printf "%s\r\n", $0 }' | sha256_stream
}

# The lock without comments or carriage returns (a Windows checkout may add CRs).
lock_records() {
  tr -d '\r' <"$lock" | sed -e 's/#.*//'
}

lock_packages() {
  lock_records | awk '$1 == "package" { print $2 }'
}

# package_field <package> <n>: field n of the package record (3 = version, 4 = zip SHA-256).
package_field() {
  lock_records | awk -v p="$1" -v n="$2" '$1 == "package" && $2 == p && !found { print $n; found = 1 }'
}

# files_of <package>: "<kind> <file> <sha256>" for the licence and every font.
files_of() {
  lock_records | awk -v p="$1" '($1 == "license" || $1 == "font") && $2 == p { print $1, $3, $4 }'
}

is_sha256() {
  case "$1" in
    *[!0-9a-f]*) return 1 ;;
  esac
  [ ${#1} -eq 64 ]
}

check_lock() {
  [ -f "$lock" ] || die "lock file not found: $lock"
  [ -n "$(lock_records | awk '$1 == "url" && !found { print $2; found = 1 }')" ] || die "$lock has no 'url' record"
  [ -n "$(lock_packages)" ] || die "$lock has no 'package' records"
  local bad pkg file sha
  bad=$(lock_records | awk '
    ($1 == "package" || $1 == "license" || $1 == "font") && NF != 4 { print NR }
    $1 == "license" && $3 != "LICENSE.txt" { print NR }
  ')
  [ -z "$bad" ] || die "malformed record(s) in $lock (lines without comments: $bad)"
  for pkg in $(lock_packages); do
    is_sha256 "$(package_field "$pkg" 4)" || die "bad zip SHA-256 for $pkg in $lock"
    [ "$(files_of "$pkg" | awk '$1 == "license"' | wc -l | tr -d ' ')" -eq 1 ] ||
      die "$pkg needs exactly one license record in $lock"
    [ "$(files_of "$pkg" | awk '$1 == "font"' | wc -l | tr -d ' ')" -gt 0 ] ||
      die "$pkg has no font records in $lock"
    while read -r _ file sha; do
      is_sha256 "$sha" || die "bad SHA-256 for $pkg/$file in $lock"
    done <<EOF
$(files_of "$pkg")
EOF
  done
  bad=$(lock_records | awk '
    $1 == "package" { known[$2] = 1 }
    ($1 == "license" || $1 == "font") { used[$2] = 1 }
    END { for (p in used) if (!(p in known)) print p }
  ')
  [ -z "$bad" ] || die "records for unknown package(s) in $lock: $bad"
}

# ---------------------------------------------------------------------------------------
# Checks.

failures=0

fail() {
  echo "FAIL $*" >&2
  failures=$((failures + 1))
}

# check_hash <label> <expected> <actual>: reports a mismatch and returns 1.
check_hash() {
  if [ "$2" = "$3" ]; then
    return 0
  fi
  fail "SHA-256 mismatch for $1"
  echo "  expected $2" >&2
  echo "  actual   $3" >&2
  return 1
}

# check_files <dir> <package>: every pinned file of <package> is in <dir> with its hash.
check_files() {
  local dir=$1 pkg=$2 kind file sha actual bad=0
  while read -r kind file sha; do
    if [ ! -f "$dir/$file" ]; then
      fail "$pkg: $file is missing from $dir"
      bad=1
      continue
    fi
    if [ "$kind" = license ]; then
      actual=$(sha256_crlf "$dir/$file")
    else
      actual=$(sha256_file "$dir/$file")
    fi
    check_hash "$pkg/$file" "$sha" "$actual" || bad=1
  done <<EOF
$(files_of "$pkg")
EOF
  return "$bad"
}

verify_committed_fonts() {
  [ -d "$dest" ] || die "font directory not found: $dest"
  local pkg expected present extra bytes
  for pkg in $(lock_packages); do
    if check_files "$dest/ibm-$pkg" "$pkg"; then
      echo "OK   ibm-$pkg ($(files_of "$pkg" | awk '$1 == "font"' | wc -l | tr -d ' ') fonts + LICENSE.txt)"
    fi
  done
  expected=$(for pkg in $(lock_packages); do
    files_of "$pkg" | awk -v p="$pkg" '{ print "ibm-" p "/" $2 }'
  done | LC_ALL=C sort)
  present=$(list_files "$dest")
  extra=$(echo "$present" | LC_ALL=C comm -13 <(echo "$expected") -)
  if [ -n "$extra" ]; then
    fail "files in $dest that fonts.lock does not pin:"
    echo "$extra" | awk '{ print "  " $0 }' >&2
  fi
  if [ "$failures" -eq 0 ]; then
    bytes=$( (cd "$dest" && for f in $expected; do wc -c <"$f"; done) | awk '{ s += $1 } END { printf "%.0f", s }')
    echo "OK   $(echo "$expected" | wc -l | tr -d ' ') files, $bytes bytes, match fonts.lock"
  fi
}

# ---------------------------------------------------------------------------------------
# Download and install.

zip_url() {
  lock_records | awk '$1 == "url" && !found { print $2; found = 1 }' |
    sed -e "s/{package}/$1/g" -e "s/{version}/$2/g"
}

# ensure_zip <package>: a cached zip that matches the lock, downloading it if needed.
ensure_zip() {
  local pkg=$1 version expected path url
  version=$(package_field "$pkg" 3)
  expected=$(package_field "$pkg" 4)
  path="$cache/ibm-$pkg-$version.zip"
  if [ -f "$path" ]; then
    if [ "$(sha256_file "$path")" = "$expected" ]; then
      echo "OK   ibm-$pkg-$version.zip (cached)"
      return 0
    fi
    echo "warning: cached ibm-$pkg-$version.zip does not match the lock; downloading it again" >&2
    rm -f "$path"
  fi
  mkdir -p "$cache"
  url=$(zip_url "$pkg" "$version")
  part_file="$path.part.$$"
  echo "GET  $url"
  if ! curl --fail --location --silent --show-error --retry 3 --retry-delay 2 \
    --proto '=https,file' --proto-redir '=https' --output "$part_file" "$url"; then
    die "download failed: $url"
  fi
  check_hash "downloaded ibm-$pkg-$version.zip ($url)" "$expected" "$(sha256_file "$part_file")" || exit 1
  mv -f "$part_file" "$path"
  part_file=""
  echo "OK   ibm-$pkg-$version.zip"
}

# stage <package>: extracts the pinned files into $staging/ibm-<package> and checks them.
stage() {
  local pkg=$1 zip kind file sha member out
  zip="$cache/ibm-$pkg-$(package_field "$pkg" 3).zip"
  out="$staging/ibm-$pkg"
  mkdir -p "$out"
  while read -r kind file sha; do
    if [ "$kind" = license ]; then
      member="ibm-$pkg/$file"
    else
      member="ibm-$pkg/fonts/complete/ttf/$file"
    fi
    unzip -q -j -o "$zip" "$member" -d "$out" || die "$member is not in $(basename "$zip")"
  done <<EOF
$(files_of "$pkg")
EOF
  # The zips mark some files executable; assets are plain files (content is unchanged).
  chmod 0644 "$out"/*
  check_files "$out" "$pkg" || exit 1
  echo "OK   ibm-$pkg: $(files_of "$pkg" | awk '{ printf "%s%s", sep, $2; sep = " " }')"
}

install_fonts() {
  command -v unzip >/dev/null 2>&1 || die "unzip is not installed"
  local pkg
  mkdir -p "$dest"
  staging=$(cd "$dest" && pwd)/.staging.$$
  mkdir -p "$staging"
  for pkg in $(lock_packages); do
    ensure_zip "$pkg"
    stage "$pkg"
  done
  # Everything is checked; swap the family folders in.
  for pkg in $(lock_packages); do
    rm -rf "${dest:?}/ibm-$pkg"
    mv "$staging/ibm-$pkg" "$dest/ibm-$pkg"
  done
  rm -rf "$staging"
  staging=""
  verify_committed_fonts
}

# ---------------------------------------------------------------------------------------

check_lock
if [ "$verify_committed" = true ]; then
  verify_committed_fonts
else
  install_fonts
fi

if [ "$failures" -gt 0 ]; then
  echo "fetch.sh: $failures check(s) failed" >&2
  exit 1
fi
