# tools/pdfium

Downloads the prebuilt PDFium libraries Ferman bundles and checks them against pinned
SHA-256 values ([ADR 0004](../../docs/adr/0004-lopdf-model-pdfium-renderer.md),
[DEPENDENCIES.md §5.1](../../docs/DEPENDENCIES.md#51-pdfium)).

| | |
|---|---|
| Source | [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries) releases |
| Tag | `chromium/7881` (the API level of pdfium-render 0.9.4, feature `pdfium_7881`) |
| Version | 151.0.7881.0, from the archives' `VERSION` file |
| Variant | Plain build: `pdf_enable_v8 = false`, `pdf_enable_xfa = false`, `is_component_build = false` (from `args.gn`) |
| Archives | `pdfium-<id>.tgz` for `mac-arm64`, `mac-x64`, `mac-univ`, `win-x64`, `win-arm64`, `linux-x64`, `linux-arm64` |

PDFium has no runtime version API. The tag in `pdfium.lock` is the version pin, and that is
what `engine_info()` reports next to `loaded = true`.

## Usage

Run from any directory; paths default to the repository.

```sh
tools/pdfium/fetch.sh                        # the host platform (mac-univ on macOS) into build/pdfium/<id>/
tools/pdfium/fetch.sh --platform win-x64     # one platform; repeat --platform for more
tools/pdfium/fetch.sh --all                  # all seven
tools/pdfium/fetch.sh --all --verify --check-licenses   # offline checks of the cached archives
tools/pdfium/fetch.sh --host                 # print the host platform id
tools/pdfium/selftest.sh                     # proves that a damaged archive is rejected
```

- A download goes to `build/pdfium/cache/pdfium-<id>.tgz.part.<pid>`, is hashed, and is renamed
  into place only if the SHA-256 matches. A mismatch exits with status 1 and leaves nothing behind.
- A cached archive that already matches is not downloaded again; one that does not match is
  downloaded again with a warning.
- `--dest <dir>` unpacks one platform somewhere else; a trailing slash is fine. The destination
  must be missing, an empty directory, or an earlier unpack by `fetch.sh`, which writes a
  `.ferman-pdfium` marker file (tag and platform id) into every unpack. Anything else (a
  directory with other files, a file, a symlink) is refused with status 1 before any download
  and left untouched. Point `--dest` at a directory of its own, never at a bundle directory
  that holds other files; the bundling step copies the library out of it.
- Unpacking goes to a hidden staging directory beside the destination (`.<name>.partial.<pid>`,
  never inside it). The library's own SHA-256 is checked (and, for `mac-univ`, both slices,
  below) before anything is replaced; the earlier unpack is then renamed aside, the new one
  renamed into place, and only then is the earlier one deleted. A failed check or rename leaves
  the destination as it was.
- `--verify` and `--check-licenses` never use the network. Missing archives fail.
- Exit status: 0 success, 1 a check or download failed, 2 usage error.
- Needs bash (3.2 or later), curl, tar with gzip, od, awk, sed, cmp and `sha256sum` or
  `shasum`. curl honours `HTTPS_PROXY`. Works on macOS, Linux and Git Bash on Windows.

`--lock <file>` and `--licenses <dir>` exist for the self-test, which runs every case on
temporary copies (34 checks, offline once the host archive is cached):

- a good archive verifies; one changed byte, a missing archive, and a download whose hash does
  not match all fail, and the rejected download leaves nothing behind;
- a download that matches is unpacked with the marker; a destination with a trailing slash, an
  empty directory and an earlier unpack are accepted, and no staging directory is left; a
  non-empty directory without the marker and a file are refused and stay untouched;
- an archive whose own hash is pinned but whose library differs from the lock is not unpacked;
- `--check-licenses` accepts the real archive, ignores `.DS_Store`, `Thumbs.db` and
  `desktop.ini` beside the committed copies, and rejects an extra committed file and an
  altered licence text;
- the `mac-univ` slice check, on every host, with a small stand-in universal library: slices
  equal to the pinned thin libraries pass, a changed arm64 slice fails;
- an unknown platform is a usage error.

## pdfium.lock

One record per line, fields separated by spaces, `#` starts a comment:

```text
tag      <release tag>
version  <Chromium version>
url      <release download base; "/pdfium-<id>.tgz" is appended>
archive  <id> <SHA-256 of the .tgz> <library path in the archive> <SHA-256 of the library>
```

Other tools can read the tag with `awk '$1 == "tag" { print $2 }' tools/pdfium/pdfium.lock`.

## Archive layout (chromium/7881)

Every archive holds `LICENSE`, `licenses/` (15 files), `VERSION`, `args.gn`,
`PDFiumConfig.cmake`, `include/` and the library; `fetch.sh` adds `.ferman-pdfium` to each
unpack. The library path inside `build/pdfium/<id>/` (or the `--dest` directory) is:

| id | Library | Size (bytes) | Identity and dependencies |
|---|---|---|---|
| `mac-arm64` | `lib/libpdfium.dylib` | 7,732,336 | Mach-O arm64; install name `./libpdfium.dylib`; minimum macOS 12.0; links only system frameworks (AppKit, CoreFoundation, CoreGraphics, Foundation) and libSystem |
| `mac-x64` | `lib/libpdfium.dylib` | 7,471,800 | Mach-O x86_64; same install name, minimum and links |
| `mac-univ` | `lib/libpdfium.dylib` | 15,219,824 | Universal (x86_64 + arm64); the slices are byte-identical to the two thin libraries |
| `win-x64` | `bin/pdfium.dll` (+ import library `lib/pdfium.dll.lib`) | 7,211,520 | PE32+ x86-64; imports only KERNEL32, USER32, GDI32 and ADVAPI32 (no MSVC runtime DLL) |
| `win-arm64` | `bin/pdfium.dll` (+ `lib/pdfium.dll.lib`) | 6,658,048 | PE32+ AArch64; same imports |
| `linux-x64` | `lib/libpdfium.so` | 7,645,184 | ELF x86-64; SONAME `libpdfium.so`; needs glibc 2.16 or later (libc, libm, libpthread, libgcc_s) |
| `linux-arm64` | `lib/libpdfium.so` | 7,834,256 | ELF AArch64; SONAME `libpdfium.so`; needs glibc 2.17 or later |

Notes for bundling:

- **macOS:** bundle `mac-univ`. Upstream publishes the universal archive for this tag, and
  `fetch.sh` proves on every unpack that its two slices equal the `mac-x64` and `mac-arm64`
  libraries pinned in the lock, which is exactly what `lipo -create` of the two thin builds
  gives. No `lipo` step is needed in CI. Should a future tag lack `mac-univ`, fetch both thin
  archives and run
  `lipo -create build/pdfium/mac-x64/lib/libpdfium.dylib build/pdfium/mac-arm64/lib/libpdfium.dylib -output libpdfium.dylib`,
  then check the result with `lipo -archs` (expect `x86_64 arm64`).
  The install name is `./libpdfium.dylib`; that is fine because pdfium-render loads the library
  by full path (`bind_to_library`), so it does not need to be changed.
- **Windows:** ship `bin/pdfium.dll` next to `ferman.exe`. The import library is not needed at
  run time.
- **Linux:** ship `lib/libpdfium.so` in the bundle's `lib/` directory.

## Licence files

`app/assets/licenses/pdfium/` holds the archive's `LICENSE` (the packager's MIT notice) and
the 15 files of `licenses/`, flattened (`licenses/pdfium.txt` becomes `pdfium.txt`). They were
copied byte for byte from `pdfium-linux-x64.tgz`.

What the comparison of all seven archives found (chromium/7881, checked on 2026-10-15):

- `linux-x64`, `linux-arm64` and the three macOS archives carry byte-identical licence files,
  with one exception: in the macOS archives, `licenses/pdfium.txt` has each line of the
  BSD-3-Clause part written as a C++ comment (`// ` in front of the first 27 lines).
- The Windows archives carry the same texts with CRLF line endings.
- With CRLF turned into LF and a leading `// ` removed from each line, every archive's 16 files
  are identical to the committed copies. `--check-licenses` compares exactly that way, and it
  also fails if a file is missing or extra. OS metadata files that `.gitignore` also ignores
  (`.DS_Store`, `Thumbs.db`, `desktop.ini`) are not counted as extra. The wording of every
  licence is the same in all seven archives.

The 15 files are: `abseil.txt`, `agg23.txt`, `fast_float.txt`, `freetype.txt`, `icu.txt`,
`lcms.txt`, `libjpeg_turbo.ijg`, `libjpeg_turbo.md`, `libopenjpeg.txt`, `libpng.txt`,
`libtiff.txt`, `llvm-libc.txt`, `pdfium.txt`, `simdutf.txt` and `zlib.txt`.

## Upgrading PDFium

PDFium and pdfium-render move together, in one commit, after the corpus and pixel-diff suite
passes on the new pair (ADR 0004).

1. Change `tag`, `version` and `url` in `pdfium.lock`.
2. Download all seven archives and record each archive's and library's SHA-256 (for example
   with `sha256sum`), then run `tools/pdfium/fetch.sh --all`.
3. Copy `LICENSE` and `licenses/*` from the new `pdfium-linux-x64.tgz` into
   `app/assets/licenses/pdfium/`, and run `tools/pdfium/fetch.sh --all --verify --check-licenses`
   and `tools/pdfium/selftest.sh`.
4. Update DEPENDENCIES.md §5.1 (tag, hashes, licence list) in the same change.
