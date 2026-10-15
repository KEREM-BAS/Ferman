#!/usr/bin/env bash
# Downloads the Chromium headless shell that playwright-core 1.56.1 drives (revision 1194,
# Chromium 141.0.7390.37) for Linux x64, checks its SHA-256, unpacks it into a cache folder and
# prints the path of the executable on stdout. Progress and warnings go to stderr.
#
# It replaces "npx playwright-core install", which also downloads Playwright's ffmpeg build
# (LGPL-2.1) with every Chromium; the renderer never needs it.
#
# Usage: tools/design-refs/fetch-chromium.sh [--zip <file>] [<cache-dir>]
#   <cache-dir>   default: $XDG_CACHE_HOME/ferman/design-refs, else ~/.cache/ferman/design-refs.
#                 The browser goes to <cache-dir>/chromium_headless_shell-1194/, the folder layout
#                 Playwright uses, so PLAYWRIGHT_BROWSERS_PATH=<cache-dir> finds it too.
#   --zip <file>  check and unpack a chromium-headless-shell-linux.zip downloaded before,
#                 instead of downloading it.
# Then: node tools/design-refs --chromium "$(tools/design-refs/fetch-chromium.sh)"
#
# CHROMIUM_SHA256 pins the zip. While it is UNPINNED (until the first CI run has downloaded the
# zip), the script prints the computed SHA-256 with a loud warning and carries on; copy the hash
# from that CI log into CHROMIUM_SHA256 below. Once pinned, a different zip is refused.

set -euo pipefail

readonly REVISION=1194
readonly CHROMIUM_SHA256=d745c7210cc88b73c7991a22c9624819960d84bc3de77ac7336d2de841a8c91f
readonly ZIP_NAME=chromium-headless-shell-linux.zip
readonly URLS=(
  "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/${REVISION}/${ZIP_NAME}"
  "https://playwright.download.prss.microsoft.com/dbazure/download/playwright/builds/chromium/${REVISION}/${ZIP_NAME}"
)

log() { printf 'fetch-chromium: %s\n' "$*" >&2; }
die() {
  log "error: $*"
  exit 1
}

usage() {
  sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0" >&2
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" | cut -d' ' -f1
  else
    shasum -a 256 -- "$1" | cut -d' ' -f1
  fi
}

# Loud on purpose: an unpinned download is only acceptable until the first CI run.
warn_unpinned() {
  local text
  text="CHROMIUM_SHA256 is not pinned. SHA-256 of ${ZIP_NAME} (revision ${REVISION}): $1."
  text+=" Pin it in tools/design-refs/fetch-chromium.sh."
  log '############################################################################'
  log "WARNING: ${text}"
  log '############################################################################'
  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    printf '::warning title=Chromium download not pinned::%s\n' "${text}" >&2
  fi
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '### Chromium download not pinned\n\n%s\n\n%s%s%s\n' "${text}" '`' "$1" '`' >>"${GITHUB_STEP_SUMMARY}"
  fi
}

zip_file=""
cache_dir=""
while (($# > 0)); do
  case "$1" in
    --zip)
      (($# >= 2)) || die "--zip needs a file"
      zip_file=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) die "unknown option $1 (see --help)" ;;
    *)
      [[ -z "${cache_dir}" ]] || die "only one cache folder, please"
      cache_dir=$1
      shift
      ;;
  esac
done

os=$(uname -s)
arch=$(uname -m)
if [[ "${os}" != Linux || "${arch}" != x86_64 ]]; then
  die "this script fetches the Linux x64 build only;" \
    "elsewhere pass a chromium-headless-shell ${REVISION} executable with --chromium"
fi
if [[ -n "${zip_file}" && ! -f "${zip_file}" ]]; then
  die "no such file: ${zip_file}"
fi

cache_dir=${cache_dir:-${XDG_CACHE_HOME:-${HOME}/.cache}/ferman/design-refs}
target="${cache_dir}/chromium_headless_shell-${REVISION}"
exe="${target}/chrome-linux/headless_shell"
stamp="${target}/ZIP_SHA256"

# Unpacked before: reuse it when it came from the pinned zip (or, while unpinned, from any zip).
if [[ -z "${zip_file}" && -x "${exe}" && -f "${target}/INSTALLATION_COMPLETE" && -f "${stamp}" ]]; then
  cached=$(<"${stamp}")
  if [[ "${CHROMIUM_SHA256}" == UNPINNED ]]; then
    warn_unpinned "${cached}"
    printf '%s\n' "${exe}"
    exit 0
  fi
  if [[ "${cached}" == "${CHROMIUM_SHA256}" ]]; then
    log "cached: ${exe}"
    printf '%s\n' "${exe}"
    exit 0
  fi
  log "the cached copy came from a zip with SHA-256 ${cached}, not the pinned one: fetching again"
fi

command -v unzip >/dev/null 2>&1 || die "unzip is needed"
mkdir -p -- "${cache_dir}"
work=$(mktemp -d "${cache_dir}/.fetch-XXXXXX")
trap 'rm -rf -- "${work}"' EXIT

if [[ -n "${zip_file}" ]]; then
  zip="${zip_file}"
else
  command -v curl >/dev/null 2>&1 || die "curl is needed"
  zip="${work}/${ZIP_NAME}"
  fetched=""
  for url in "${URLS[@]}"; do
    log "downloading ${url}"
    if curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 \
      --connect-timeout 30 --retry 3 --retry-delay 5 --output "${zip}" "${url}"; then
      fetched=yes
      break
    fi
    log "download failed: ${url}"
  done
  [[ -n "${fetched}" ]] || die "could not download ${ZIP_NAME} from any host"
fi

actual=$(sha256_of "${zip}")
if [[ "${CHROMIUM_SHA256}" == UNPINNED ]]; then
  warn_unpinned "${actual}"
elif [[ "${actual}" != "${CHROMIUM_SHA256}" ]]; then
  die "SHA-256 mismatch for ${ZIP_NAME}: expected ${CHROMIUM_SHA256}, got ${actual}"
else
  log "SHA-256 ok: ${actual}"
fi

unzip -q "${zip}" -d "${work}/unpacked"
[[ -x "${work}/unpacked/chrome-linux/headless_shell" ]] || die "${ZIP_NAME} holds no chrome-linux/headless_shell"
printf '%s\n' "${actual}" >"${work}/unpacked/ZIP_SHA256"
: >"${work}/unpacked/INSTALLATION_COMPLETE"
rm -rf -- "${target}"
mv -- "${work}/unpacked" "${target}"
log "unpacked into ${target}"
printf '%s\n' "${exe}"
