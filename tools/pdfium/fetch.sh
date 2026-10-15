#!/usr/bin/env bash
# Downloads the pinned PDFium prebuilt binaries (bblanchon/pdfium-binaries) and checks
# them against tools/pdfium/pdfium.lock. See tools/pdfium/README.md.
#
# Portable on purpose: bash 3.2 (macOS), Git Bash (Windows) and Linux, using only curl,
# tar, od, awk, sed and sha256sum or shasum. curl honours HTTPS_PROXY.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)

lock="$script_dir/pdfium.lock"
licenses_dir="$repo_root/app/assets/licenses/pdfium"
cache="$repo_root/build/pdfium/cache"
dest=""
platforms=""
all=false
do_verify=false
do_licenses=false
show_host=false

usage() {
  cat <<'EOF'
Usage: tools/pdfium/fetch.sh [--platform <id>]... [--all] [options]

Without --verify or --check-licenses, downloads each selected archive into the cache
(skipped when a cached copy already matches its pinned SHA-256), checks it, and unpacks
it into the destination. Without --platform or --all, the host platform is selected
(mac-univ on macOS).

The destination must be missing, empty, or an earlier unpack by this script, which
writes a .ferman-pdfium marker file into every unpack. Anything else is refused (exit 1)
and left untouched; nothing outside the destination is ever replaced. Unpacking goes to
a hidden sibling directory first, so a failed check leaves the destination as it was.

Platform ids: mac-arm64 mac-x64 mac-univ win-x64 win-arm64 linux-x64 linux-arm64

Options:
  --platform <id>   Select a platform; repeat for several.
  --all             Select every platform in pdfium.lock.
  --verify          Only check the SHA-256 of the cached archives. No download.
  --check-licenses  Only check that the licence files inside each cached archive are
                    identical to the committed copies in app/assets/licenses/pdfium/.
                    No download. Combine with --verify to run both checks.
  --dest <dir>      Unpack into <dir>, replacing an earlier unpack there (one platform
                    only; a trailing slash is fine). Default: build/pdfium/<id>/
  --cache <dir>     Archive cache. Default: build/pdfium/cache/
  --lock <file>     Use another lock file (for tests). Default: tools/pdfium/pdfium.lock
  --licenses <dir>  Committed licence copies to compare against (for tests).
  --host            Print the host platform id and exit.
  -h, --help        Show this help.

Exit status: 0 on success, 1 when a check or download fails, 2 on a usage error.
EOF
}

die() {
  echo "fetch.sh: error: $*" >&2
  exit 1
}

usage_error() {
  echo "fetch.sh: $*" >&2
  echo "Run 'tools/pdfium/fetch.sh --help' for usage." >&2
  exit 2
}

need_value() {
  if [ "$2" -lt 2 ]; then
    usage_error "$1 needs a value"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --platform) need_value "$1" $#; platforms="$platforms $2"; shift 2 ;;
    --all) all=true; shift ;;
    --verify) do_verify=true; shift ;;
    --check-licenses) do_licenses=true; shift ;;
    --dest) need_value "$1" $#; dest=$2; shift 2 ;;
    --cache) need_value "$1" $#; cache=$2; shift 2 ;;
    --lock) need_value "$1" $#; lock=$2; shift 2 ;;
    --licenses) need_value "$1" $#; licenses_dir=$2; shift 2 ;;
    --host) show_host=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage_error "unknown argument: $1" ;;
  esac
done

# ---------------------------------------------------------------------------------------
# Temporary files, removed on exit.

work=""
part_file=""
staging_dir=""

# Written into every unpack; only a directory holding it may be replaced.
marker=.ferman-pdfium

cleanup() {
  if [ -n "$work" ]; then rm -rf "$work"; fi
  if [ -n "$part_file" ]; then rm -f "$part_file"; fi
  if [ -n "$staging_dir" ]; then rm -rf "$staging_dir"; fi
  return 0
}
trap cleanup EXIT

work_dir() {
  if [ -z "$work" ]; then
    work=$(mktemp -d "${TMPDIR:-/tmp}/ferman-pdfium.XXXXXX")
  fi
}

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

# The lock without comments or carriage returns (a Windows checkout may add CRs).
lock_records() {
  tr -d '\r' <"$lock" | sed -e 's/#.*//'
}

# lock_value <key>: the second field of the first "<key> <value>" record.
lock_value() {
  lock_records | awk -v k="$1" '$1 == k && !found { print $2; found = 1 }'
}

# lock_field <id> <n>: field n of the "archive <id> ..." record (3 = archive SHA-256,
# 4 = library path, 5 = library SHA-256).
lock_field() {
  lock_records | awk -v id="$1" -v n="$2" '$1 == "archive" && $2 == id && !found { print $n; found = 1 }'
}

lock_ids() {
  lock_records | awk '$1 == "archive" { print $2 }'
}

is_sha256() {
  case "$1" in
    *[!0-9a-f]*) return 1 ;;
  esac
  [ ${#1} -eq 64 ]
}

check_lock() {
  [ -f "$lock" ] || die "lock file not found: $lock"
  [ -n "$(lock_value tag)" ] || die "$lock has no 'tag' record"
  [ -n "$(lock_value url)" ] || die "$lock has no 'url' record"
  [ -n "$(lock_ids)" ] || die "$lock has no 'archive' records"
  local bad
  bad=$(lock_records | awk '$1 == "archive" && NF != 5 { print $2 }')
  [ -z "$bad" ] || die "malformed archive record(s) in $lock: $bad"
  local id
  for id in $(lock_ids); do
    is_sha256 "$(lock_field "$id" 3)" || die "bad archive SHA-256 for $id in $lock"
    is_sha256 "$(lock_field "$id" 5)" || die "bad library SHA-256 for $id in $lock"
  done
}

# ---------------------------------------------------------------------------------------
# Platform selection.

host_platform() {
  local os arch
  os=$(uname -s)
  arch=$(uname -m)
  case "$os" in
    Darwin) echo mac-univ ;;
    Linux)
      case "$arch" in
        x86_64 | amd64) echo linux-x64 ;;
        aarch64 | arm64) echo linux-arm64 ;;
        *) die "no PDFium build for Linux on $arch" ;;
      esac
      ;;
    MINGW* | MSYS* | CYGWIN*)
      if [ "$arch" = aarch64 ] || [ "${PROCESSOR_ARCHITECTURE:-}" = ARM64 ]; then
        echo win-arm64
      else
        echo win-x64
      fi
      ;;
    *) die "unknown host system '$os'; pass --platform" ;;
  esac
}

select_platforms() {
  if [ "$all" = true ]; then
    lock_ids
    return
  fi
  if [ -z "$platforms" ]; then
    platforms=$(host_platform)
  fi
  local id
  for id in $platforms; do
    [ -n "$(lock_field "$id" 3)" ] || usage_error "unknown platform id: $id (see pdfium.lock)"
    echo "$id"
  done
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

archive_path() {
  echo "$cache/pdfium-$1.tgz"
}

# verify_archive <id>: the cached archive exists and matches the lock.
verify_archive() {
  local id=$1 path
  path=$(archive_path "$id")
  if [ ! -f "$path" ]; then
    fail "pdfium-$id.tgz is not in the cache ($cache); run tools/pdfium/fetch.sh --platform $id"
    return 1
  fi
  check_hash "pdfium-$id.tgz" "$(lock_field "$id" 3)" "$(sha256_file "$path")" || return 1
  echo "OK   pdfium-$id.tgz"
}

# be32 <file> <offset>: the big-endian unsigned 32-bit integer at offset, in decimal.
be32() {
  od -An -tu1 -j "$2" -N 4 "$1" | awk '{ printf "%.0f\n", (($1 * 256 + $2) * 256 + $3) * 256 + $4 }'
}

# check_universal <dylib>: the universal (fat) Mach-O holds exactly the mac-x64 and
# mac-arm64 libraries of the lock as its two slices, byte for byte (what
# "lipo -create" of the two thin builds produces).
check_universal() {
  local lib=$1 i base cpu off size arch want got seen=""
  if [ "$(be32 "$lib" 0)" != 3405691582 ]; then # 0xcafebabe, FAT_MAGIC
    fail "$lib is not a universal Mach-O library"
    return 1
  fi
  if [ "$(be32 "$lib" 4)" != 2 ]; then
    fail "$lib does not have exactly two slices"
    return 1
  fi
  for i in 0 1; do
    base=$((8 + 20 * i))
    cpu=$(be32 "$lib" "$base")
    off=$(be32 "$lib" $((base + 8)))
    size=$(be32 "$lib" $((base + 12)))
    case "$cpu" in
      16777223) arch=x86_64; want=$(lock_field mac-x64 5) ;;  # CPU_TYPE_X86_64
      16777228) arch=arm64; want=$(lock_field mac-arm64 5) ;; # CPU_TYPE_ARM64
      *) fail "$lib has an unexpected slice (CPU type $cpu)"; return 1 ;;
    esac
    # tail may be stopped by SIGPIPE once head has its bytes; the hash decides.
    got=$({ tail -c +"$((off + 1))" "$lib" || true; } | head -c "$size" | sha256_stream)
    check_hash "the $arch slice of $lib" "$want" "$got" || return 1
    seen="$seen $arch"
  done
  case "$seen" in
    *x86_64*arm64* | *arm64*x86_64*) ;;
    *) fail "$lib does not hold both an x86_64 and an arm64 slice"; return 1 ;;
  esac
  echo "OK   universal library = mac-x64 + mac-arm64 slices"
}

# Prints a licence file in a comparable form: Windows archives use CRLF line endings, and
# the macOS archives carry pdfium.txt as a C++ comment ("// " before every line).
normalised() {
  tr -d '\r' <"$1" | sed -E 's#^// ?##'
}

# check_licenses <id>: LICENSE and licenses/* in the cached archive equal the committed
# copies (LICENSE as LICENSE, licenses/<name> as <name>), and nothing is missing or extra.
check_licenses() {
  local id=$1 dir archive_files committed_files name src
  work_dir
  dir="$work/licenses-$id"
  mkdir -p "$dir"
  if ! tar -xzf - -C "$dir" LICENSE licenses <"$(archive_path "$id")"; then
    fail "could not unpack the licence files of pdfium-$id.tgz"
    return 1
  fi
  [ -d "$licenses_dir" ] || die "committed licence copies not found: $licenses_dir"
  archive_files=$( (cd "$dir" && find LICENSE licenses -type f) | sed 's#^licenses/##' | LC_ALL=C sort)
  committed_files=$(list_files "$licenses_dir")
  if [ "$archive_files" != "$committed_files" ]; then
    fail "licence file list of pdfium-$id.tgz differs from $licenses_dir"
    diff <(echo "$archive_files") <(echo "$committed_files") | sed 's/^/  /' >&2 || true
    return 1
  fi
  local bad=0
  for name in $archive_files; do
    if [ "$name" = LICENSE ]; then src="$dir/LICENSE"; else src="$dir/licenses/$name"; fi
    normalised "$src" >"$work/a"
    normalised "$licenses_dir/$name" >"$work/b"
    if ! cmp -s "$work/a" "$work/b"; then
      fail "pdfium-$id.tgz: $name differs from the committed copy"
      bad=1
    fi
  done
  [ "$bad" -eq 0 ] || return 1
  echo "OK   pdfium-$id.tgz licence files ($(echo "$archive_files" | wc -l | tr -d ' ') files) match the committed copies"
}

# ---------------------------------------------------------------------------------------
# Download and unpack.

# ensure_archive <id>: a cached archive that matches the lock, downloading it if needed.
ensure_archive() {
  local id=$1 path expected url actual
  path=$(archive_path "$id")
  expected=$(lock_field "$id" 3)
  if [ -f "$path" ]; then
    if [ "$(sha256_file "$path")" = "$expected" ]; then
      echo "OK   pdfium-$id.tgz (cached)"
      return 0
    fi
    echo "warning: cached pdfium-$id.tgz does not match the lock; downloading it again" >&2
    rm -f "$path"
  fi
  mkdir -p "$cache"
  url="$(lock_value url)/pdfium-$id.tgz"
  part_file="$path.part.$$"
  echo "GET  $url"
  if ! curl --fail --location --silent --show-error --retry 3 --retry-delay 2 \
    --proto '=https,file' --proto-redir '=https' --output "$part_file" "$url"; then
    die "download failed: $url"
  fi
  actual=$(sha256_file "$part_file")
  if ! check_hash "downloaded pdfium-$id.tgz ($url)" "$expected" "$actual"; then
    exit 1
  fi
  mv -f "$part_file" "$path"
  part_file=""
  echo "OK   pdfium-$id.tgz"
}

# dest_dir <dir>: prints <dir> without trailing slashes (so the staging directory beside
# it is a sibling, never inside it) after checking that it may be replaced: it must be
# missing, empty, or an earlier unpack holding the marker file. Anything else is refused.
dest_dir() {
  local target=$1
  while [ "$target" != / ] && [ "${target%/}" != "$target" ]; do target=${target%/}; done
  case "$(basename "$target")" in
    / | . | ..) die "the destination must name a directory: '$1'" ;;
  esac
  if [ -L "$target" ] || { [ -e "$target" ] && [ ! -d "$target" ]; }; then
    die "refusing to replace $target: it is not a plain directory"
  fi
  # (An unreadable directory counts as not empty: ls then prints an error.)
  if [ -d "$target" ] && [ ! -f "$target/$marker" ] && [ -n "$(ls -A "$target" 2>&1)" ]; then
    die "refusing to replace $target: it is not empty and holds no $marker file from an earlier unpack; remove it or choose another --dest"
  fi
  echo "$target"
}

# unpack <id> <dir>: unpacks into a staging directory beside <dir>, checks the library,
# then puts the result in place of <dir> (see dest_dir for what may be replaced).
unpack() {
  local id=$1 target parent base lib old=""
  target=$(dest_dir "$2")
  parent=$(dirname "$target")
  base=$(basename "$target")
  mkdir -p "$parent"
  staging_dir="$parent/.$base.partial.$$"
  rm -rf "$staging_dir"
  mkdir -p "$staging_dir"
  tar -xzf - -C "$staging_dir" <"$(archive_path "$id")" || die "could not unpack pdfium-$id.tgz"
  lib="$staging_dir/$(lock_field "$id" 4)"
  [ -f "$lib" ] || die "pdfium-$id.tgz has no $(lock_field "$id" 4)"
  check_hash "$(lock_field "$id" 4) in pdfium-$id.tgz" "$(lock_field "$id" 5)" "$(sha256_file "$lib")" || exit 1
  if [ "$id" = mac-univ ]; then
    check_universal "$lib" || exit 1
  fi
  printf 'tag %s\nplatform %s\n' "$(lock_value tag)" "$id" >"$staging_dir/$marker"
  # Renames either happen or not, so a failure (a library in use on Windows, for example)
  # leaves the earlier unpack where it was.
  if [ -d "$target" ]; then
    old="$parent/.$base.old.$$"
    mv "$target" "$old" || die "could not move $target aside"
  fi
  if ! mv "$staging_dir" "$target"; then
    if [ -n "$old" ]; then mv "$old" "$target" || true; fi
    die "could not move the unpacked files to $target"
  fi
  staging_dir=""
  if [ -n "$old" ]; then rm -rf "$old"; fi
  echo "OK   $target/$(lock_field "$id" 4)"
}

# ---------------------------------------------------------------------------------------

if [ "$show_host" = true ]; then
  host_platform
  exit 0
fi

check_lock
selected=$(select_platforms)
count=$(echo "$selected" | wc -w | tr -d ' ')

if [ "$do_verify" = false ] && [ "$do_licenses" = false ]; then
  if [ -n "$dest" ] && [ "$count" -ne 1 ]; then
    usage_error "--dest needs exactly one platform"
  fi
  echo "PDFium $(lock_value tag) ($(lock_value version))"
  for id in $selected; do
    target=$(dest_dir "${dest:-$repo_root/build/pdfium/$id}") # refuse before downloading
    ensure_archive "$id"
    unpack "$id" "$target"
  done
  exit 0
fi

for id in $selected; do
  if verify_archive "$id" && [ "$do_licenses" = true ]; then
    check_licenses "$id" || true
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "fetch.sh: $failures check(s) failed" >&2
  exit 1
fi
