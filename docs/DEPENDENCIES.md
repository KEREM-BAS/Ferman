# Dependencies

This file lists every dependency Ferman uses or plans to use, with its licence. The brief requires it
([brief §3](BRIEF.md)): "list every dependency with its licence in docs/DEPENDENCIES.md". The policy
behind it is [ADR 0016](adr/0016-dependency-licence-policy.md).

Versions, licences and release dates were checked on 2026-10-13 against crates.io, pub.dev, npm and the
upstream repositories. A few items were re-checked on 2026-10-14 or 2026-10-15; they say so. The
dependencies in use (section 2) come from the lockfiles, and their pub.dev licences were re-checked on
2026-10-15. The owner's decisions of 2026-10-15 ([Q04](QUESTIONS.md#q04), [Q08](QUESTIONS.md#q08),
[Q17](QUESTIONS.md#q17)) and 2026-10-16 ([Q06](QUESTIONS.md#q06), [Q07](QUESTIONS.md#q07), Q08
groups 3 and 4, [Q10](QUESTIONS.md#q10), [Q12](QUESTIONS.md#q12), [Q15](QUESTIONS.md#q15),
[Q16](QUESTIONS.md#q16), Q17 part 4) are recorded in the rows they affect. "First milestone" follows
the brief's roadmap as detailed in [ROADMAP.md](ROADMAP.md). The dependency research guessed its own
phases; every row here has been remapped to the roadmap.

## Contents

1. [Policy](#1-policy)
2. [In use today](#2-in-use-today)
3. [Planned dependencies](#3-planned-dependencies)
4. [Rejected](#4-rejected)
5. [Bundled binaries and assets](#5-bundled-binaries-and-assets)
6. [Toolchain](#6-toolchain)
7. [deny.toml](#7-denytoml)
8. [Dart licence check](#8-dart-licence-check)
9. [Known risks](#9-known-risks)
10. [What could not be verified](#10-what-could-not-be-verified)
11. [Adding or changing a dependency](#11-adding-or-changing-a-dependency)

## 1. Policy

The brief: "permissive or GPL-compatible licences only. Never AGPL or non-commercial (no MuPDF, no
Ghostscript). Enforce with cargo-deny" ([brief §3](BRIEF.md)).

Ferman is Apache-2.0 ([brief §1](BRIEF.md)). That narrows "GPL-compatible":

- **GPL-2.0-only** code cannot be combined with Apache-2.0 code in a distributed binary. The FSF treats
  Apache-2.0's patent-termination and indemnity terms as incompatible with GPLv2.
- **GPL-3.0** accepts Apache-2.0 code, but only one way. A binary that contains GPL-3.0 code must be
  distributed under GPL-3.0 as a whole. That would relicense Ferman, so GPL-3.0 code is out too.
- **LGPL** as a sole licence is out. Rust and Flutter link statically by default, and relinking
  obligations are hard to meet in signed bundles and app stores.
- **MPL-2.0** is weak copyleft at file level. Unmodified MPL-2.0 files can ship inside an Apache-2.0
  product with a notice and a pointer to their source.

So in practice: **permissive licences, plus MPL-2.0 for unmodified dependencies after the owner's review.**

This reading of "GPL-compatible" (no GPL-3.0 code, no LGPL-only code) is ours; the brief does not spell
it out. The owner confirmed it on 2026-10-16 ([Q17](QUESTIONS.md#q17) part 4): no GPL code of any
version, no LGPL-only code, and MPL-2.0 only per package after the owner's review.

**Allowed for code (Rust and Dart):** Apache-2.0, Apache-2.0 WITH LLVM-exception, MIT, MIT-0,
BSD-2-Clause, BSD-3-Clause, ISC, Zlib, 0BSD, BSL-1.0, CC0-1.0, Unicode-3.0, Unicode-DFS-2016. An OR
expression is fine when one side is on this list. Examples: `MIT OR Apache-2.0 OR LGPL-2.1-or-later`
(r-efi) and `Apache-2.0 OR GPL-2.0-only` (self_cell); cargo-deny takes the permissive side.

**Allowed only per package, after review:**

- MPL-2.0 for an unmodified dependency, with a notice, once the owner approves that package. One case
  is approved (2026-10-15, [Q17](QUESTIONS.md#q17)): `dbus`, which desktop_drop depends on for every
  platform ([section 3.11](#311-flutter-and-dart-packages)). It arrives with desktop_drop in M2 and is
  skipped by name in the pub licence check ([section 8](#8-dart-licence-check)).
- NCSA for `libfuzzer-sys`, only in the separate `fuzz/` workspace, which never ships. Approved on
  2026-10-15 ([Q17](QUESTIONS.md#q17)); `fuzz/` is created with the first parser in M2.
- OFL-1.1 (and Apache-2.0 for Homemade Apple, which ships for typed signatures from M4,
  [Q08](QUESTIONS.md#q08) group 3) for font files only, never as a code licence.
- Tools that run only in CI (for example the LGPL-3.0 Swatinem/rust-cache action). They are never
  distributed, and their code is never vendored or copied. Swatinem/rust-cache was approved on
  2026-10-15 ([Q17](QUESTIONS.md#q17)).

**Never:** AGPL (any version), GPL-2.0-only, GPL-2.0-or-later, GPL-3.0 (any), LGPL as a sole licence,
EUPL, SSPL, BUSL, Elastic, Commons Clause, any non-commercial licence (CC-BY-NC, PolyForm
Noncommercial), and anything with no licence or a licence we cannot identify. Never MuPDF, Ghostscript,
poppler or xpdf in any form, including tools that shell out to them.

**Owner approval.** Any unusual licence goes to the owner first ([brief §9](BRIEF.md)): anything outside
the allow-list, every MPL-2.0 case, model weights and data files, and anything whose licence cannot be
verified. The question goes into [QUESTIONS.md](QUESTIONS.md), and work continues without that
dependency.

**Enforcement.**

- Rust: cargo-deny checks licences, bans, advisories and sources on every pull request
  ([section 7](#7-denytoml)).
- Dart: cargo-deny does not see pub packages, so CI runs very_good_cli's licence check with the same
  allow-list ([section 8](#8-dart-licence-check)).
- Bundled binaries, fonts and icons sit outside both package managers. They are listed by hand in
  [section 5](#5-bundled-binaries-and-assets) and shown in the app's licences screen
  ([G14](DESIGN_GAPS.md#g14)).

**Same commit.** This file is updated in the same commit as any dependency change. A pull request that
adds, removes or upgrades a dependency without updating this file is not merged.

**Status key** used in the tables:

- **ok**: fine to use as planned.
- **caution**: usable only under the condition in the notes.
- **reject**: must not be used; banned or replaced.

## 2. In use today

What M1 has added so far, read from `Cargo.lock`, `app/pubspec.lock`, the tool lockfiles and
`.github/workflows/ci.yml` on 2026-10-15. Everything listed here is committed on `m1-foundations`
([PROGRESS.md](PROGRESS.md#m1-plan)).

### 2.1 Rust crates

| Name | Purpose | Version (Cargo.lock) | SPDX licence | Status | Since | Notes |
|---|---|---|---|---|---|---|
| thiserror | Error enum in every crate | 2.0.21 | MIT OR Apache-2.0 | ok | M1 | [ADR 0010](adr/0010-error-handling-no-panics.md). MSRV 1.77. |
| tracing | ferman-api: records caught panics; ferman-render: the render thread's start and the PDFium load, with the library path (no subscriber yet) | 0.1.44 | MIT | ok | M1 | Logs never leave the device ([ADR 0015](adr/0015-privacy-and-network.md)). File paths may appear in the local log, never in `engine_info()` ([ARCHITECTURE.md §8.4](ARCHITECTURE.md#84-logs)). tracing-subscriber is added with the first log file ([section 3.1](#31-bridge-errors-and-logging)). MSRV 1.65. |
| serde (derive) | ferman-api: `Serialize` on `EngineInfo` and its parts | 1.0.229 | MIT OR Apache-2.0 | ok | M1 | Derived directly, with no feature flag. |
| serde_json | ferman-cli: `info --json`; ferman-api (dev): the PDFium status JSON test | 1.0.154 | MIT OR Apache-2.0 | ok | M1 | |
| clap (`derive`, `string`) | ferman-cli argument parser | 4.6.7 | MIT OR Apache-2.0 | ok | M1 | Chosen in M1 step 1. MSRV 1.85. Pulls anstream, anstyle*, clap_lex, strsim and heck (MIT, or MIT OR Apache-2.0). |
| flutter_rust_bridge (crate) | Rust side of the Dart–Rust bridge, behind ferman-api's optional `frb` feature | `=2.13.0` | MIT | ok | M1 | The crate, the Dart package and the codegen must be the same version ([ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md)); `tools/checks` compares the crate and the Dart package, and the CI codegen job installs the codegen at exactly 2.13.0 (its cache key names the version). 2.14.0-beta.2 exists and is not used. Its default features add about 75 crates, among them tokio 1.53.3, futures 0.3.34, backtrace 0.3.76, allo-isolate 0.1.27 (clarify hash `0x0a6d4ed6`, [section 7](#7-denytoml)), dart-sys 4.1.5, threadpool 1.8.1, anyhow 1.0.104, dashmap 5.5.3 and md-5 0.10.6. MSRV 1.70. |
| pdfium-render | ferman-render: binds PDFium at run time on the render thread; read-only rasteriser from M2 | `=0.9.4` | MIT OR Apache-2.0 | ok | M1 | `default-features = false` with `pdfium_7881` and `thread_safe` (checked in the 0.9.4 manifest: `pdfium_latest = ["pdfium_7881"]`, `image_latest = ["image_025"]`; the API level is named so a pdfium-render update cannot move it). **Proposed** with the M2 plan: `image_025` ([ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md)) stays off, because the tiles take PDFium's bitmap bytes through `PdfBitmap::as_raw_bytes`, which no feature gates. Pinned exactly: it moves with the PDFium tag in one commit. Binds with `bind_to_library` from an explicit, absolute path; its bindings are process-wide and never unbound, so ferman-render binds once per process behind a lock. Pulls on the desktop targets: libloading 0.9.0 (ISC, MSRV 1.88), chrono 0.4.45 (default features), iana-time-zone 0.1.65 (Linux, macOS), core-foundation-sys 0.8.7 (macOS), windows-link 0.2.1 (Windows), itertools 0.15.0, either 1.19.0, num-traits 0.2.19, autocfg 1.5.1 (build), bitflags 2.13.2, bytemuck 1.25.2 (Zlib OR Apache-2.0 OR MIT), bytes 1.12.1 (MIT), log 0.4.34, once_cell 1.21.4, maybe-owned 0.3.4, utf16string 0.2.0, vecmath 1.0.0 and piston-float 1.0.1 (MIT); 22 packages are new in `Cargo.lock`. MSRV 1.61. Upgrade check: reusing a binding relies on `Pdfium::default()` taking pdfium-render's reuse branch (`library.rs`). pdfium-render panics if its global lock is poisoned, which ends the render thread (status "failed: the render thread has stopped"). It never calls `FPDF_DestroyLibrary`. |
| futures-channel | ferman-render: oneshot replies from the render thread, awaited by async API functions without blocking | 0.3.34 | MIT OR Apache-2.0 | ok | M1 | Default features (`std`). Already in the graph through flutter_rust_bridge's futures 0.3.34. Requests use `std::sync::mpsc`; crossbeam-channel ([section 3.5](#35-concurrency-and-caching)) is not added before M2. MSRV 1.71. |
| flate2 | ferman-core: FlateDecode (`filters`) | 1.1.10 | MIT OR Apache-2.0 | ok | M2 | Default features: the pure-Rust miniz_oxide 0.9.1 backend (`MIT OR Zlib OR Apache-2.0`), with crc32fast 1.5.2 (MIT OR Apache-2.0) and simd-adler32 0.3.10 (MIT); no C zlib. Its low-level `Decompress` is used on the raw deflate data after ferman-core checks the zlib header, so the decoded-size limit holds and a wrong Adler-32 is tolerated as PDFium tolerates it. The encoder serves the tests; the M3 writer will use it too. MSRV 1.67. |
| weezl | ferman-core: LZWDecode (`filters`), with `/EarlyChange` as weezl's TIFF size switch | 0.2.1 | MIT OR Apache-2.0 | ok | M2 | Default features (`std`). Decodes into a bounded buffer per call, so the limit holds. MSRV 1.88. |
| proptest (dev) | ferman-core: property tests of the filters (round trips, the decoded-size limit) | 1.12.0 | MIT OR Apache-2.0 | ok | M2 | First use of the M1 pin. Pulls bit-set, bit-vec, bitflags, chacha20, core_detect, num-traits, rand, rand_xorshift, regex-syntax, rusty-fork (with quick-error and wait-timeout), tempfile and unarray, all MIT, Apache-2.0 or both; the dev-dependency licence run passes. MSRV 1.88. |
| insta (dev) | ferman-cli snapshot test | 1.49.0 | Apache-2.0 | ok | M1 | Pulls console 0.16.6 (MIT), similar 2.7.0 (Apache-2.0) and tempfile 3.27.0 (MIT OR Apache-2.0). MSRV 1.66. |

Notable transitive licences: memchr 2.8.3 and byteorder 1.5.0 are `Unlicense OR MIT` (the MIT side
applies), miniz_oxide 0.8.9 and 0.9.1 are `MIT OR Zlib OR Apache-2.0`, bytemuck 1.25.2 is
`Zlib OR Apache-2.0 OR MIT`, libloading 0.9.0 is ISC, and unicode-ident 1.0.27 adds Unicode-3.0.
console_log 1.1.0, android_system_properties 0.1.6, iana-time-zone-haiku 0.1.2 and windows-core
0.62.2 (with windows-implement, windows-interface, windows-result and windows-strings) are in
`Cargo.lock` through pdfium-render and chrono but are built for none of the desktop targets.
`cargo deny check` (0.20.2) passes for advisories, bans, licences and sources, and the dev-dependency
licence run passes too; pdfium-render's tree needed no `[[licenses.clarify]]` entry. It prints four
expected warnings: the `libfuzzer-sys` exception (met only in `fuzz/`) and the rustybuzz wrapper are
not met here, syn appears twice (2.0.119 and 3.0.9), and so does miniz_oxide (0.8.9 through
backtrace from flutter_rust_bridge, 0.9.1 through flate2). Every MSRV in the graph is 1.88 or lower
(libloading 0.9.0 and weezl 0.2.1 are exactly 1.88). `Cargo.lock` also lists optional crates that
no enabled feature builds, such as zlib-rs (flate2's other backend) and borsh; `cargo tree` shows
neither.

### 2.2 Dart and Flutter packages (app)

Licences re-checked on pub.dev on 2026-10-15. `very_good packages check licenses` over
`app/pubspec.lock` (the full command of [section 8](#8-dart-licence-check): direct, dev and transitive
dependencies) passes: 111 packages, BSD-3-Clause (82), MIT (23) and Apache-2.0 (6), since ffigen
arrived on 2026-10-19 (107 before). `rust_lib_ferman` is a path package and is not counted.

| Name | Purpose | Version (pubspec.lock) | SPDX licence | Status | Since | Notes |
|---|---|---|---|---|---|---|
| flutter_riverpod | State management | 3.4.3 | MIT | ok | M1 | Publisher dash-overflow.net. [ADR 0011](adr/0011-flutter-state-navigation-components.md). |
| riverpod_annotation | Annotations for Riverpod code generation | 4.0.7 | MIT | ok | M1 | Locked to riverpod 3.4.3. |
| go_router | Navigation | 18.1.0 (2026-10-14) | BSD-3-Clause | ok | M1 | Publisher flutter.dev. |
| intl | Messages, dates and numbers | 0.20.3 | BSD-3-Clause | ok | M1 | flutter_localizations requires `^0.20.3`. Publisher dart.dev. |
| flutter_localizations | Framework localisations and RTL support | SDK (Flutter 3.47.7) | BSD-3-Clause | ok | M1 | Used with gen-l10n ([ADR 0014](adr/0014-localization-and-rtl.md)). |
| path_provider | App support, cache and data directories; the settings file lives in the app support directory | 2.1.6 | BSD-3-Clause | ok | M1 | Publisher flutter.dev. Pulls path_provider_android 2.3.1 and through it jni 1.1.0, jni_flutter 1.0.4+1 and jni_util 1.0.0; jni's build hook puts `libdartjni.so` into the Linux bundle, unused on desktop ([section 3.14](#314-notable-transitive-dependencies), [B006](BACKLOG.md#open)). |
| window_manager | Custom title bars, window size and state | 0.5.2 | MIT | ok | M1 | Publisher leanflutter.dev. Windows, macOS and Linux only. Pulls screen_retriever 0.2.2 (MIT). |
| path_parsing | Parses the icons' SVG path data for the Icon widget's `CustomPainter` | 1.1.0 (2024-11-01) | MIT | ok | M1 | Publisher flutter.dev (flutter/packages, `third_party/packages/path_parsing`); its LICENSE is the MIT text. Depends on meta and vector_math 2.4.0 (both BSD-3-Clause). Replaces flutter_svg ([section 4](#4-rejected), [ADR 0013](adr/0013-fonts-and-icons.md)). |
| flutter_rust_bridge (Dart) | Dart side of the bridge | 2.13.0 | MIT | ok | M1 | Same version as the crate and the codegen. Publisher cjycode.com. |
| rust_lib_ferman | FFI plugin with no Dart code: builds ferman-api (`frb` feature) through cargokit and bundles the library with the app | path package `app/rust_builder` (0.1.0) | Apache-2.0 | ok | M1 | Ferman's own code. Linux and Windows build through CMake, macOS through CocoaPods; Flutter warns that it does not support Swift Package Manager ([section 9](#9-known-risks), [B007](BACKLOG.md#open)). Its vendored cargokit is in [section 2.3](#23-tools-never-shipped). |
| riverpod_generator (dev) | Riverpod code generator | 4.0.9 | MIT | ok | M1 | Needs analyzer >=13 <15, which is why custom_lint cannot be used. |
| build_runner (dev) | Runs the code generators | 2.16.2 | BSD-3-Clause | ok | M1 | Publisher tools.dart.dev. 2.17.1 (2026-10-14) exists, but build_runner 2.17 conflicts with riverpod_generator 4.0.9. |
| alchemist (dev) | Golden tests | 0.14.1 | MIT | ok | M1 | Publisher betterment.dev. Replaces golden_toolkit. Goldens load the real fonts ([brief §5](BRIEF.md)). |
| mocktail (dev) | Mocks for tests | 1.0.5 | MIT | ok | M1 | Publisher felangel.dev. |
| ffigen (dev) | Generates the Dart side of the bridge's Dco codec (`full_dep: true`, [Q19](QUESTIONS.md#q19)) from the C header the codegen writes | 20.1.1 | BSD-3-Clause | ok | M2 | Publisher labs.dart.dev. The version flutter_rust_bridge 2.13.0 itself is built with (`^20.1.1`; 23.0.0 exists). Codegen only, never in an app build; it needs libclang ([section 2.3](#23-tools-never-shipped)). Brings no `http` (`pub_denylist` passes). Pulls cli_util 0.4.2, quiver 3.2.2 (Apache-2.0) and yaml_edit 2.2.4 (both others BSD-3-Clause), and holds package_config at 2.2.0 instead of 3.0.0, which only the build tools use. |
| very_good_analysis (dev) | Lint rule set | 11.0.0 | MIT | ok | M1 | Required by [brief §5](BRIEF.md). It enforces `unnecessary_type_name_in_constructor`, so Ferman's Dart uses Dart 3.13's `new` constructor form. |
| flutter_test, integration_test, flutter_driver (dev) | Widget and integration tests; flutter_driver runs the integration test in profile mode | SDK (Flutter 3.47.7) | BSD-3-Clause | ok | M1 | flutter_driver was already transitive through integration_test; since `be0a04b` it is a direct dev dependency for `app/test_driver/integration_test.dart` (`flutter drive --profile`). The lockfile changed only its dependency type, so the licence count stays at 107. |
| riverpod_lint | Riverpod lints | 3.1.9 | MIT | ok | M1 | A native analyzer plugin under `plugins:` in `app/analysis_options.yaml`, not a pubspec dependency, so it is not in `pubspec.lock` and the licence check above does not see it; its licence was checked on pub.dev. No verified publisher. Its diagnostics appear only in `dart analyze`, so CI runs `dart analyze --fatal-infos` as well as `flutter analyze`. |

`http` is not in `app/pubspec.lock`: the pub deny list (`tools/checks` `pub_denylist`, approved by
the owner on 2026-10-16) fails on it, which is why flutter_svg was dropped.

### 2.3 Tools (never shipped)

| Name | Purpose | Version | SPDX licence | Status | Since | Notes |
|---|---|---|---|---|---|---|
| cargo-deny | Licence, ban, advisory and source gate | 0.20.2 | MIT OR Apache-2.0 | ok | M1 | Since 0.18.4, GNU licences are matched strictly; only the allow-list and exceptions apply. The pinned cargo-deny-action bundles the same version. MSRV 1.88. |
| cargo-fuzz | Builds and runs the fuzz targets in `fuzz/` ([fuzz/README.md](../fuzz/README.md)) | 0.13.2 | MIT OR Apache-2.0 | ok | M2 | `cargo install --locked cargo-fuzz@0.13.2`; the CI fuzz job caches the binary. Runs on the pinned nightly ([section 6](#6-toolchain)). |
| libfuzzer-sys | The libFuzzer runtime of the fuzz targets, in `fuzz/` only | 0.4.13 | (MIT OR Apache-2.0) AND NCSA | caution | M2 | The NCSA part (LLVM's vendored libFuzzer) is the exception the owner approved on 2026-10-15 ([Q17](QUESTIONS.md#q17)), for this crate in `fuzz/` only. Pulls arbitrary 1.5.0 (MIT OR Apache-2.0) and cc (MIT OR Apache-2.0), which builds libFuzzer's C++ sources. `cargo deny --manifest-path fuzz/Cargo.toml check` passes in CI. The fuzz workspace's own Cargo.lock pins it. |
| sha2, tempfile (dev) | `tools/corpus`: the SHA-256 of corpus files; temporary corpora in its tests | 0.11.1; 3.27.0 | MIT OR Apache-2.0 | ok | M2 | The corpus tool's own Cargo.lock pins them; `cargo deny --manifest-path tools/corpus/Cargo.toml check` and its dev-dependency licence run pass in CI. sha2 enters the shipped graph separately with ferman-core's fingerprints. |
| lopdf (tools/corpus) | `tools/corpus`: the object structure of the generated PDFs | `=0.45.0` | MIT | ok | M2 | `default-features = false` (no rayon, no clock); the pin ferman-core takes. Its own encryption draws initialisation vectors and salts from the system's random number generator, so the corpus tool encrypts with its own handler ([ADR 0020](adr/0020-test-corpus.md)). Its object streams are written in object order, so `tez-tr` stays reproducible. Pulls aes 0.9.2, cbc 0.2.1, ecb 0.2.1, md-5 0.11.0, sha2 0.11.1, flate2 1.1.10 (miniz_oxide 0.9.1), weezl 0.2.1, nom 8.0.0, brotli-decompressor 5.0.3 (BSD-3-Clause OR MIT), encoding_rs 0.8.42, stringprep 0.1.5, rand 0.10.3 and getrandom 0.4.3. |
| harfrust, skrifa, subsetter (tools/corpus) | `tools/corpus`: shapes the text of composite fonts, reads font metrics, subsets the embedded fonts | `=0.14.0`; `=0.48.0`; `=0.2.6` | MIT; MIT OR Apache-2.0; MIT OR Apache-2.0 | ok | M2 | The pins of the engine's font stack ([section 3.3](#33-fonts-and-text)), on one read-fonts 0.45.1. subsetter has `default-features = false`: its `variable-fonts` feature would add skrifa 0.42, write-fonts and kurbo. subsetter leaves out the `cmap` table, which the tool adds back for simple TrueType fonts. |
| aes, md-5, rc4, stringprep (tools/corpus) | `tools/corpus`: its standard security handler (AES blocks with CBC written out, MD5 key derivation, RC4, SASLprep for revision 6 passwords) | 0.9.2; 0.11.0; 0.2.0; 0.1.5 | MIT OR Apache-2.0 | ok | M2 | RustCrypto (aes, md-5, rc4; aes and md-5 are the versions lopdf uses). stringprep pulls unicode-bidi 0.3.18, unicode-normalization 0.1.26 and unicode-properties 0.1.4. |
| pdfium-render (dev, tools/corpus) | The PDFium oracle test of the corpus (`tools/corpus/tests/oracle.rs`) | `=0.9.4` | MIT OR Apache-2.0 | ok | M2 | The pin and features of ferman-render ([section 2.1](#21-rust-crates)); binds the library `FERMAN_PDFIUM_PATH` names. |
| very_good_cli | Licence gate for Dart packages | 1.5.0 | MIT | ok | M1 | `very_good packages check licenses` ([section 8](#8-dart-licence-check)). Needs Dart 3.13. |
| flutter_rust_bridge_codegen | Generates the bridge bindings (`app/lib/bridge/`, `crates/ferman-api/src/frb_generated.rs`) | 2.13.0 | MIT | ok | M1 | In use since M1 step 3 (`0ae4f29`). `cargo install --locked flutter_rust_bridge_codegen@2.13.0`, matching the runtime crate and package. The CI codegen job installs it, caches the binary (actions/cache, [section 2.4](#24-github-actions)), regenerates the bindings and fails on any diff. MSRV 1.74. |
| cargo-expand | Expands ferman-api's macros for the codegen | 1.0.127 | MIT OR Apache-2.0 | ok | M1 | flutter_rust_bridge_codegen 2.13.0 calls it. `cargo install --locked cargo-expand@1.0.127`; cached with the codegen in CI. |
| libclang | Parses the bridge's C header for ffigen (the Dco codec, [Q19](QUESTIONS.md#q19)) | Ubuntu 24.04's `libclang-dev` (LLVM 18) in the CI codegen job; Xcode's own on macOS | Apache-2.0 WITH LLVM-exception | ok | M2 | A system library of the developer machine or runner, found by ffigen (`llvm_path` in `app/flutter_rust_bridge.yaml` names `/usr/lib/llvm-18`; elsewhere ffigen's own search, which finds Xcode's). Never linked into Ferman or shipped. |
| cargokit (vendored in `app/rust_builder/cargokit/`) | Builds ferman-api during `flutter build` and hands the library to the plugin (CMake on Linux and Windows, CocoaPods on macOS) | from the flutter_rust_bridge 2.13.0 integration template | MIT OR Apache-2.0 | ok | M1 | Copyright Matej Knopp; both texts in `cargokit/LICENSE`. Two changes, each marked "Ferman patch": `build_tool/lib/src/builder.dart` builds with the toolchain from `rust-toolchain.toml` instead of `stable`, and `cargo.dart` `libraryName` turns `-` into `_`, so cargokit finds `libferman_api`. Precompiled binaries are not configured, so it never downloads an engine library and always builds from source ([app/rust_builder/README.md](../app/rust_builder/README.md)). `crates/ferman-api/cargokit.yaml` turns on the `frb` feature for the debug, profile and release modes, which cargokit reads separately (`ba9f6d2`). Its scripts run at build time and are not in the app bundle. |
| cargokit build tool's pub packages | Run cargokit's build tool (`app/rust_builder/cargokit/build_tool/`) | 54 packages pinned in its `pubspec.yaml` and `pubspec.lock`: logging 1.2.0, path 1.8.0, version 3.0.0, collection 1.18.0, ed25519_edwards 0.3.1, hex 0.2.0, yaml 3.1.2, source_span 1.10.0, github 9.17.0, args 2.4.2, crypto 3.0.3, convert 3.1.1, http 1.1.0 and toml 0.14.0, plus transitive packages | BSD-3-Clause (48), MIT (6), Apache-2.0 (1) | ok | M1 | `very_good packages check licenses` over `build_tool/` passes: 55 licences for 54 packages. Fetched from pub.dev at the first native build; build time only, never shipped. They include `http` and `github`, which serve the precompiled-binary code that is not configured. `pub_denylist` reads only `app/pubspec.lock`, so these are a known build-time exception to the network deny list ([section 8](#8-dart-licence-check)). |
| args | Command-line options of `tools/checks`, `tools/tokens`, `tools/icons` and `tools/l10n` | 2.7.0 | BSD-3-Clause | ok | M1 | Publisher dart.dev. Each tool commits its own `pubspec.lock`. |
| path | Path handling in the three Dart tools | 1.9.1 | BSD-3-Clause | ok | M1 | |
| yaml | `tools/checks` (pubspec and lock files) and `tools/tokens/supplement.yaml` | 3.1.4 | MIT | ok | M1 | Transitive: collection 1.19.1, meta 1.19.0, source_span 1.10.2, string_scanner 1.4.1 and term_glyph 1.2.2 (all BSD-3-Clause). |
| crypto | SHA-512 tarball integrity and SHA-256 licence checks in `tools/icons` | 3.0.7 | BSD-3-Clause | ok | M1 | Pulls typed_data 1.4.0 (BSD-3-Clause). |
| test, very_good_analysis (dev) | Tests and lints of the four Dart tools | 1.33.0; 11.0.0 | BSD-3-Clause; MIT | ok | M1 | The licence check over `tools/tokens/pubspec.lock` passes: 50 packages, BSD-3-Clause and MIT. |
| playwright-core | Drives Chromium to render every artboard to PNG | 1.56.1 (re-checked 2026-10-15) | Apache-2.0 | ok | M1 | `tools/design-refs`, pinned exactly in its lockfile (lockfileVersion 3, 22 packages from registry.npmjs.org with sha512 integrity). **Pinned to 1.56.1, not the newest release (1.64.1, published 2026-10-14),** because its Chromium revision (1194, Chromium 141.0.7390.37) is the browser preinstalled in the development container, where the Playwright download CDN is blocked. CI uses the same revision, so local and CI renders come from the same browser. playwright-core installs no browser itself, and Ferman never runs the Playwright installer ([section 9](#9-known-risks)). Upgrading means moving the container browser and the pin together. |
| Chromium headless shell, revision 1194 | The browser the renderer drives | 141.0.7390.37 | BSD-3-Clause, plus the licences of its components | ok | M1 | On developer machines and CI runners only; never shipped. The development container has it in `/opt/pw-browsers`. CI downloads `chromium-headless-shell-linux.zip` for revision 1194 directly with `tools/design-refs/fetch-chromium.sh`, which checks its SHA-256 (pinned as `d745c721…c91f` from the first CI download on 2026-10-15) and prints the path the renderer takes with `--chromium`. |
| fonts-dejavu-core, fonts-noto-cjk (Ubuntu packages) | System fonts the Flutter tests load on Linux: DejaVu Sans Mono for the macOS key symbols ⌘ ⌥ ⇧ ⌃ ⌫ ⌦ ↵ and Noto Sans CJK JP for CJK text, standing in for the system font fallback that `flutter test` lacks, and DejaVu Serif (`DejaVuSerif.ttf`, in fonts-dejavu-core itself) standing in for Georgia and Times New Roman, the system fonts the FontPicker gallery sample names, in the component goldens ([G87](DESIGN_GAPS.md#g87), [G96](DESIGN_GAPS.md#g96)) | 2.37-8; 1:20230817+repack1-3 (Ubuntu 24.04) | Bitstream-Vera (DejaVu's changes are public domain); OFL-1.1 | ok | M1 | Installed with apt on the Linux CI runner (the Flutter job's step "System fonts for the goldens", which fails when either version changes, since that would move golden pixels) and in the development container; `app/test/helpers/fonts.dart` and `app/test/helpers/component_golden.dart` (`loadSystemFontStandIns`) read them from `/usr/share/fonts`. On Ubuntu 24.04 `DejaVuSansMono.ttf` ships in fonts-dejavu-mono, which fonts-dejavu-core depends on; both are built from the same source at the same version, so the version check on fonts-dejavu-core covers it. Never in the repository and never in an app build: the app bundles only the Plex files and leaves these characters to the user's system ([ADR 0013](adr/0013-fonts-and-icons.md)). The Debian packaging files of fonts-noto-cjk are GPL-3.0-or-later; Ferman uses only the font files. |
| React, ReactDOM | Runtime the design export needs to render | 18.3.1 | MIT | ok | M1 | The export loads them from unpkg.com at run time (`design/support.js`). Installed from npm, pinned in the `tools/design-refs` lockfile and served from those local copies, so rendering works offline. Every run checks that the local files' SHA-384 equals the SRI hashes in `design/support.js`. Dependencies: scheduler 0.23.2, loose-envify 1.4.0 and js-tokens 4.0.0 (all MIT). Never in the app ([brief §2](BRIEF.md)). |
| @babel/standalone | JSX transform the design export can load | 7.29.0 (2026-01-31) | MIT | ok | M1 | Same as React, SRI checked; the export loads it only for JSX imports, which no board uses. |
| Design-reference fonts | The 13 families the export loads from Google Fonts | @fontsource/{ibm-plex-sans-jp, ibm-plex-sans-kr, ibm-plex-sans-hebrew, ibm-plex-sans-devanagari, noto-sans-sc, noto-serif-jp, noto-naskh-arabic, eb-garamond, cormorant-garamond, crimson-pro, caveat, dancing-script, homemade-apple} 5.3.0 (2026-07-19) | OFL-1.1; homemade-apple Apache-2.0 | ok | M1 | Pinned in the `tools/design-refs` lockfile; each package's LICENSE holds the font licence. Served locally as generated `@font-face` CSS, with the families and weights of the `fm-additions.css` import, so the renderer never touches the network ([G07](DESIGN_GAPS.md#g07)). 5.3.1 of the three CJK packages (2026-10-11) was too new to pin, so all use 5.3.0. Never in the app. |
| pixelmatch | Pixel diff for `--twice` and the `compare` report (goldens against the references) | 7.2.0 (2026-04-29) | ISC | ok | M1 | `tools/design-refs` only. 8.0.0 (2026-10-06) was too new to pin. |
| pngjs | PNG decoding and encoding for pixelmatch | 7.0.0 (2023-02-20) | MIT | ok | M1 | `tools/design-refs` only. |
| Google Chrome or Chromium (installed) | Renders the app icons from the logo export (`tools/app-icons`) | the developer's installed browser; the committed icons were rendered with Google Chrome 155.0.8059.80 (recorded in `tools/app-icons/manifest.json`) | BSD-3-Clause (Chromium), plus the licences of its components; Google Chrome's terms | ok | M2 | A browser already on the developer machine, launched headless with `--screenshot`; `--chromium`, `FERMAN_CHROMIUM` or the usual install places pick it. Nothing is downloaded and `tools/app-icons` has no npm dependencies. Only the icons it renders are committed; `--check` (no browser) compares them with the manifest. Never shipped. |
| lucide-static (npm tarballs 0.300.0, 0.460.0, 0.500.0, 1.56.0) | Icon provenance comparison and the shipped Lucide licence texts | pinned by npm integrity in `tools/icons/lib/src/lucide.dart` | ISC (Feather portions MIT) | ok | M1 | Downloaded with curl to `build/lucide` only with `dart run icons --lucide`; never shipped. Only the two LICENSE files are copied to `app/assets/icons/` ([section 5.3](#53-icons)). |

`fuzz/` and `tools/corpus` are Cargo workspaces of their own, excluded from the root workspace, each
with its own `Cargo.lock`; nothing in them ships. `tools/pdfium` and `tools/fonts` are bash scripts that use only bash, curl, tar, unzip and the Python
standard library; they add no dependency. `tools/corpus/fetch-fonts.sh` uses only bash, curl, awk and
`sha256sum` or `shasum`. `tools/app-icons` is a Node script with no npm dependencies; it needs only the installed browser above.

### 2.4 GitHub Actions

Pinned by full commit SHA in `.github/workflows/ci.yml` and `design-refs.yml`, with the version in a
comment; `tools/checks` fails on an unpinned action ([ADR 0017](adr/0017-testing-and-ci.md)).

| Name | Purpose | Version and SHA | SPDX licence | Status | Since | Notes |
|---|---|---|---|---|---|---|
| actions/checkout | Checkout | v7.0.1, `3d3c42e5aac5ba805825da76410c181273ba90b1` | MIT | ok | M1 | |
| subosito/flutter-action | Installs Flutter | v2.23.0, `1a449444c387b1966244ae4d4f8c696479add0b2` | MIT | ok | M1 | `flutter-version: 3.47.7`. |
| Swatinem/rust-cache | Cargo build cache | v2.9.2, `6323deb102c322ba6fcbdcafc7e3dddab59af2b6` | LGPL-3.0 | caution | M1 | **Approved by the owner on 2026-10-15** ([Q17](QUESTIONS.md#q17)). Runs only in CI and is never distributed with Ferman, so it creates no obligation for users. Never vendor or copy its code. |
| EmbarkStudios/cargo-deny-action | Runs cargo-deny | v2.1.1, `3c6349835b2b7b196a839186cb8b78e02f7b5f25` | MIT OR Apache-2.0 | ok | M1 | Bundles cargo-deny 0.20.2. |
| actions/cache | The PDFium archive caches, keyed on `tools/pdfium/pdfium.lock` (all seven archives in the repository-checks job; one archive per system in the Rust jobs, the Flutter jobs and the Ubuntu 22.04 job), and the flutter_rust_bridge_codegen and cargo-expand binaries in the codegen job, keyed on their versions | v6.1.0, `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | MIT | ok | M1 | Not used for Cargo, which rust-cache handles. |
| actions/setup-node | Installs Node for `tools/design-refs` | v7.1.0, `949feb2413d6458794dcd2491c4babbbce0c15c1` | MIT | ok | M1 | `node-version-file: tools/design-refs/.nvmrc` (24.22.0), in the repository-checks job and the design-reference workflow. |
| actions/upload-artifact | Uploads the design-reference PNGs and, when a Linux golden test fails, its failure images | v7.0.2, `cf430e030ddbb5b0abf93d22962f4752f3646cd9` | MIT | ok | M1 | |

The Rust toolchain comes from `rustup toolchain install`, which reads `rust-toolchain.toml`; no
toolchain action is used ([section 4](#4-rejected)).

### 2.5 Bundled assets in the repository

The IBM Plex fonts ([section 5.2](#52-fonts)), the icon SVGs with their provenance table and Lucide
licence files ([section 5.3](#53-icons)) and the PDFium licence files
([section 5.1](#51-pdfium)) are committed under `app/assets/`. The PDFium libraries themselves are
downloaded by `tools/pdfium` and never committed.

## 3. Planned dependencies

Versions are the latest releases on 2026-10-13. The exact pin is set when the dependency is added, and
the row then moves to [section 2](#2-in-use-today). MSRV is the minimum Rust version a crate declares.

### 3.1 Bridge, errors and logging

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| tracing-subscriber | Writes the local log files | version set when the first log file is written | MIT | ok | M1 | Logs never leave the device ([ADR 0015](adr/0015-privacy-and-network.md)). flutter_rust_bridge, thiserror and tracing are in use ([section 2.1](#21-rust-crates)). |

### 3.2 PDF and rendering

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| lopdf | Document model: parsing, incremental and full writes. The source of truth | 0.45.0 (2026-09-08) | MIT | ok | M2 | Pin `=0.45`: breaking minor releases come almost monthly (0.41 to 0.45 between June and September 2026). Wrapped inside ferman-core so an upgrade touches one crate. `embed_image` and `async` features off. Pulls aes, cbc, ecb, md-5, sha2 0.11, brotli-decompressor, encoding_rs and stringprep. MSRV 1.88. [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md). |
| pdfium-render | Safe Rust binding to PDFium, used as a read-only rasteriser | 0.9.4 (2026-09-06) | MIT OR Apache-2.0 | ok | M1 | `default-features = false` with `pdfium_7881` and `thread_safe` since M1 step 3 ([section 2.1](#21-rust-crates)); **Proposed** with the M2 plan: `image_025` stays off, because tiles take PDFium's bitmap bytes through `PdfBitmap::as_raw_bytes`, which needs no feature. PDFium is not thread-safe: `thread_safe` puts every call behind one global lock, and Ferman also keeps PDFium on one render thread ([ADR 0009](adr/0009-threading-and-jobs.md)). Binds at run time (`bind_to_library`), because the prebuilt builds are shared libraries only. Never used to edit or save. Not the GPL-3.0 `pdfium` crate. MSRV 1.61. In use since M1 step 3: the render thread binds PDFium and reports it loaded, with the pinned tag, only after a real call; `tools/pdfium` pins a SHA-256 per archive and per library ([section 5.1](#51-pdfium)). Page rendering starts in M2. |
| PDFium (prebuilt, bblanchon/pdfium-binaries) | Native renderer loaded by pdfium-render | tag `chromium/7881`; newest tag is `chromium/8100` | BSD-3-Clause AND Apache-2.0; the packager's notice is MIT; plus bundled third-party licences | caution | M1 | Caution is for the notice obligations and the supply chain, not the licence. Details in [section 5.1](#51-pdfium). |
| image | Raster decode and encode: compress, insert images, OCR input | 0.25.10 (2026-03-10) | MIT OR Apache-2.0 | caution | M4 | `default-features = false` with `png`, `jpeg`, `tiff`, `webp`, `gif` and `rayon`. The defaults pull the AVIF encoder (ravif and rav1e, BSD-2-Clause), exr and the unmaintained `paste` (RUSTSEC-2024-0436). pdfium-render would bring `image` with default features off (JPEG only) through its `image_025` feature, which stays off (Proposed with the M2 plan); `image` arrives in M4. MSRV 1.88. |
| hayro | Optional pure-Rust rasteriser: web fallback and cross-checks | 0.8.0 (2026-10-04) | Apache-2.0 OR MIT | ok | P5 | By the krilla author. Does not match PDFium's fidelity yet. Considered only for the web build. |

### 3.3 Fonts and text

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| skrifa | Font metadata, outlines and glyph metrics (fontations) | 0.48.0 (2026-10-03) | MIT OR Apache-2.0 | ok | M2 | Pin exactly. Pre-1.0, with breaking changes every few weeks. Upgrade together with read-fonts, the shaper and subsetter. MSRV 1.85. |
| read-fonts | Low-level OpenType table parsing; the base of skrifa and harfrust | 0.45.0 (2026-10-03) | MIT OR Apache-2.0 | ok | M2 | Used instead of ttf-parser for any direct table access. MSRV 1.85. |
| harfrust | Text shaping (Rust port of HarfBuzz) | 0.14.0 (2026-10-04) | MIT | ok | M3 | The shaper: [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md), accepted by the owner on 2026-10-15 ([Q04](QUESTIONS.md#q04)). Official successor to rustybuzz in the harfbuzz organisation. Built on read-fonts 0.45, the same version skrifa 0.48 uses. Sits behind ferman-fonts' `Shaper` trait. Pin exactly. MSRV 1.85. rustybuzz, which brief §3 names, is [rejected](#4-rejected) as a direct dependency. |
| subsetter | TrueType and CFF subsetting for fonts embedded in PDFs | 0.2.6 (2026-06-04) | MIT OR Apache-2.0 | ok | M3 | From the typst project. Keep the `variable-fonts` feature off: it pulls skrifa 0.42, write-fonts 0.48 and kurbo, a second fontations stack. MSRV 1.85. |
| fontdb | System font discovery and fallback | 0.24.0 (2026-07-29) | MIT | ok | M3 | Missing-glyph step 2 and notices such as "Garamond isn't installed" ([ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md)). Pulls ttf-parser, memmap2, slotmap (Zlib) and, on Linux, fontconfig-parser. MSRV 1.71. |
| ttf-parser | Font parsing, transitive only | 0.25.1 (2024-11-29) | MIT OR Apache-2.0 | caution | M3 | Arrives through fontdb (and, from P4, through krilla's copy of rustybuzz). Never a direct dependency; use read-fonts or skrifa. No release since November 2024. |

### 3.4 Unicode and i18n

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| unicode-normalization | NFC and NFKC for search and text edits | 0.1.25 (2025-10-30) | MIT OR Apache-2.0 | ok | M2 | icu_normalizer, already present through ICU4X, could replace it. |
| unicode-segmentation | Grapheme and word boundaries for caret, selection and search | 1.13.3 (2026-06-01) | MIT OR Apache-2.0 | ok | M2 | icu_segmenter (Unicode-3.0) if Thai or CJK dictionary segmentation is needed. MSRV 1.85. |
| unicode-bidi | Bidi algorithm for Arabic, Persian and Hebrew text and selection | 0.3.18 (2024-12-16) | MIT OR Apache-2.0 | ok | M2 | From servo. Slow releases (last in December 2024) but widely used. ICU4X has bidi data if needed. |
| icu_casemap | Locale-aware case mapping (Turkish İ and ı) for search folding | 2.3.0 (2026-08-13) | Unicode-3.0 | ok | M2 | Its data and support crates (zerovec, yoke, tinystr, litemap, writeable, potential_utf) are Unicode-3.0 too, so Unicode-3.0 is on the allow-list. MSRV 1.88. |
| icu_collator | Locale collation (Turkish order) for recent files and font lists | 2.3.1 (2026-08-20) | Unicode-3.0 | ok | M2 | Brings icu_normalizer and icu_properties data. Binary size is checked when it is added. MSRV 1.88. |

### 3.5 Concurrency and caching

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| rayon | Data-parallel work: thumbnails, search, batch steps | 1.12.0 (2026-04-14) | MIT OR Apache-2.0 | ok | M2 | PDFium calls never run on rayon threads; they stay on the render thread. MSRV 1.80. |
| crossbeam-channel | Queues between the bridge, document actors and the render thread | 0.5.17 (2026-09-05) | MIT OR Apache-2.0 | ok | M2 | Alternatives: `std::sync::mpsc` or flume 0.12.0 (Apache-2.0 OR MIT). The M1 render thread uses `std::sync::mpsc` with futures-channel replies ([section 2.1](#21-rust-crates)). MSRV 1.60. |
| lru | Tile, page and thumbnail caches | 0.18.5 (2026-09-23) | MIT | ok | M2 | RUSTSEC-2021-0130 was fixed in 0.7.1. For a concurrent cache: quick_cache 0.7.0 (MIT) or hashlink 0.12.2 (MIT OR Apache-2.0). MSRV 1.85. |

### 3.6 File safety

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| tempfile | Temp file in the target directory for atomic save; test files | 3.27.0 (2026-03-11) | MIT OR Apache-2.0 | ok | M2 (dev), M3 (runtime) | `NamedTempFile::persist` plus a directory fsync covers the replace on macOS and Linux; Windows uses `ReplaceFileW` ([ARCHITECTURE.md §7.2](ARCHITECTURE.md#72-atomic-replace), [ADR 0008](adr/0008-file-safety-and-saving.md)). MSRV 1.63. |
| atomic-write-file | Atomic file replace on save | 0.3.1 (2026-08-11) | BSD-3-Clause | ok | M3 | Under evaluation. Used only if it covers `ReplaceFileW` and metadata preservation; otherwise ferman-core implements the sequence. Pulls nix 0.31 (MIT) and rand 0.10. atomicwrites 0.4.4 (MIT) has had no release since 2024. MSRV 1.85. |
| sha2 | File fingerprints, external-change detection, cache keys; later signature digests | 0.11.1 (2026-10-12) | MIT OR Apache-2.0 | ok | M2 | Uses the digest 0.11 API. cms 0.2 would add digest 0.10 as a second copy ([section 9](#9-known-risks)). MSRV 1.88. |

### 3.7 Crypto and signatures (P3)

Certificate signatures, Turkish e-imza and signature validation are phase 3 ([brief §7](BRIEF.md)).
Simple signatures in M4 are not cryptographic and need none of these.

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| cms | CMS SignedData for PDF signatures (PAdES) | 0.2.3 (2024-01-08) stable; 0.3.0-rc.0 (2026-10-13) | Apache-2.0 OR MIT | caution | P3 | 0.2.3 depends on x509-cert 0.2, der 0.7, spki 0.7 and digest 0.10, which do not mix with x509-cert 0.3, der 0.8 and sha2 0.11. Use 0.3.0 once released, or the release candidate after review. Upstream (RustCrypto/formats) is active. Brief §3: verify before use. |
| x509-cert (with der, spki) | Certificate parsing and chain building | 0.3.0 (2026-07-09); der 0.8.2; spki 0.8.1 | Apache-2.0 OR MIT | ok | P3 | MSRV 1.85. |
| cryptoki | PKCS#11 for hardware tokens and smart cards (Turkish e-imza) | 0.12.1 (2026-09-16) | Apache-2.0 | ok | P3 | Loads the vendor's PKCS#11 module at run time through libloading (ISC). The vendor middleware is proprietary, installed by the user and never redistributed by Ferman. Pulls cryptoki-sys and secrecy. MSRV 1.77. |
| rsa | RSA signature verification | 0.9.10 (2026-01-06) | MIT OR Apache-2.0 | caution | P3 | RUSTSEC-2023-0071 (Marvin timing side channel) has no fix. Verification only. Private keys stay on the token or in the OS keystore; aws-lc-rs (ISC AND (Apache-2.0 OR ISC)) is the option if software signing is ever needed. p256 0.14 and ecdsa 0.17 (Apache-2.0 OR MIT) cover ECDSA. |

### 3.8 Standards (P4)

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| krilla | PDF generation for PDF/A, PDF/UA and tagged output | 0.8.2 (2026-06-04) | MIT OR Apache-2.0 | caution | P4 | MSRV 1.92. 0.8.2 pulls the archived rustybuzz (default `simple-text` feature) and skrifa 0.42, a second fontations stack; the cargo-deny ban lets rustybuzz in only through krilla. krilla's main branch has moved to harfrust and newer skrifa; prefer the next release. The `pdf` feature uses hayro-write (Apache-2.0 OR MIT). Brief §3: verify before use. |

### 3.9 OCR (P3)

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| ocrs | On-device text recognition for scans | 0.13.1 (2026-09-13) | MIT OR Apache-2.0 | caution | P3 | Early preview that recognises the Latin alphabet only, so Turkish ğ, ş, ı and İ are unproven and Arabic and CJK are not covered. Models are downloaded separately; they were trained on HierText (CC-BY-SA-4.0) and no licence for the weights is published. The engine is chosen at the start of phase 3 after a fresh check ([Q16](QUESTIONS.md#q16), answered on 2026-10-16), with a licence review before any model ships or downloads. |
| rten | Inference runtime used by ocrs | 0.27.0 (2026-10-02); ocrs 0.13.1 needs 0.26.x | MIT OR Apache-2.0 | ok | P3 | Pin 0.26.x to match ocrs and avoid two copies. 0.27 needs Rust 1.94. Its flatbuffers dependency is Apache-2.0. |
| Tesseract with Leptonica (alternative) | OCR engine, native | not checked | Apache-2.0; Leptonica BSD-2-Clause | caution | P3 | The fallback the owner named in Q16 (2026-10-16). Adds a native build per platform; the licences of language data files are checked before use. |

### 3.10 Dev and test (Rust)

None of these ship. They never appear in the shipped dependency graph
([ARCHITECTURE.md §2.2](ARCHITECTURE.md#22-dependency-graph)).

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| proptest | Property tests for parser and edit invariants | 1.12.0 (2026-10-10) | MIT OR Apache-2.0 | ok | M1 | Pinned in `[workspace.dependencies]` in M1; it enters `Cargo.lock` with its first use. MSRV 1.88. insta is in use ([section 2.1](#21-rust-crates)). |
| criterion | Benchmarks for render, text and save | 0.8.2 (2026-02-04) | Apache-2.0 OR MIT | ok | M2 | Now under the criterion-rs organisation. Pulls plotters (MIT), ciborium (Apache-2.0) and tinytemplate. MSRV 1.86. |
| cargo-fuzz (tool) | Fuzz targets for every parser | 0.13.2 (2026-06-09) | MIT OR Apache-2.0 | ok | M2 | From the first parser in M2 ([brief §5](BRIEF.md)); libfuzzer-sys was approved in [Q17](QUESTIONS.md#q17). Needs nightly. Linux and macOS are first-class; Windows needs MSVC ASan and has limits. Targets live in the separate `fuzz/` workspace. |
| libfuzzer-sys | libFuzzer runtime for the fuzz targets | 0.4.13 (2026-06-04) | (MIT OR Apache-2.0) AND NCSA | caution | M2 | NCSA covers the vendored LLVM libFuzzer and is permissive, but it is outside the allow-list. **Approved by the owner on 2026-10-15** ([Q17](QUESTIONS.md#q17)) as a cargo-deny exception for this crate only, in `fuzz/` only, which never ships. `fuzz/` is created with the first parser in M2. |

### 3.11 Flutter and Dart packages

The M1 packages are in use ([section 2.2](#22-dart-and-flutter-packages-app)); flutter_svg was
dropped and shared_preferences was not chosen ([section 4](#4-rejected)).

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| desktop_drop | Drag and drop onto the window | 0.8.4 (2026-09-01) | Apache-2.0 | caution | M2 | Depends on `dbus` (Canonical, 0.7.x, MPL-2.0) on every platform: the dependency is unconditional in its pubspec, and `lib/src/channel.dart` imports `package:dbus` unconditionally and checks the platform only at run time, using it on Linux. **`dbus` was approved by the owner on 2026-10-15** ([brief §9](BRIEF.md), [Q17](QUESTIONS.md#q17)), so desktop_drop is added in M2, unmodified. The `dbus` notice and source location ship with every build that includes desktop_drop, and `dbus` gets a named skip in the pub licence check ([section 8](#8-dart-licence-check)). No iOS support. |
| file_selector | OS-native open, save and folder pickers | 1.1.0 (2025-11-21) | BSD-3-Clause | ok | M2 | [ADR 0018](adr/0018-native-file-pickers.md), Accepted by the owner on 2026-10-16 ([Q07](QUESTIONS.md#q07)). Flutter >=3.35. All six platforms. Slow releases. |
| freezed, freezed_annotation | Data classes and unions | 4.0.2 (2026-09-18); 3.1.0 | MIT | caution | not planned | Added only if a clear need appears ([ADR 0011](adr/0011-flutter-state-navigation-components.md)). Dart 3 records, sealed classes and the FRB-generated classes cover most cases. freezed_annotation has had no release since 2025-07. |

### 3.12 Tooling

None of these ship with the app. Toolchains are in [section 6](#6-toolchain). The tools in use since M1
(cargo-deny, very_good_cli, flutter_rust_bridge_codegen, cargo-expand, cargokit, the Dart tool
packages, playwright-core and the other design-reference packages) are in
[section 2.3](#23-tools-never-shipped).

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| cargo-about | Generates the Rust third-party notices | 0.9.2 (2026-08-18) | MIT OR Apache-2.0 | ok | M4 | Feeds the licences screen in M4 ([G14](DESIGN_GAPS.md#g14)); every release from M5 bundles its output. PDFium, fonts and icons are merged in by hand. MSRV 1.88. |

### 3.13 GitHub Actions

Every third-party action is pinned by full commit SHA, with the version in a comment
([ADR 0017](adr/0017-testing-and-ci.md)). The actions in use are in
[section 2.4](#24-github-actions).

No further action is planned: actions/setup-node, actions/upload-artifact and actions/cache, planned
here in M0, are in use and listed in section 2.4 with the versions CI pins.

### 3.14 Notable transitive dependencies

The full transitive graph comes from the lockfiles once they exist. These are listed because they carry a
licence or maintenance detail worth knowing.

| Name | Comes from | SPDX licence | Notes |
|---|---|---|---|
| allo-isolate 0.1.27 | flutter_rust_bridge | Apache-2.0 (licence file) | crates.io shows "non-standard" because `license-file` points at the Apache-2.0 text. `deny.toml` clarifies it, pinned to the file's hash `0x0a6d4ed6`. |
| threadpool 1.8.1 | flutter_rust_bridge | MIT OR Apache-2.0 | Last released in 2020. |
| brotli-decompressor | lopdf | BSD-3-Clause OR MIT | |
| encoding_rs | lopdf | (Apache-2.0 OR MIT) AND BSD-3-Clause | |
| slotmap | fontdb | Zlib | |
| nix 0.31 | atomic-write-file | MIT | |
| libloading 0.9.0 | pdfium-render (M1), cryptoki (P3) | ISC | Loads PDFium at run time. MSRV 1.88, the workspace floor. |
| chrono 0.4.45 | pdfium-render (`chrono = "0"`, default features) | MIT OR Apache-2.0 | Brings iana-time-zone (Linux, macOS) with core-foundation-sys (macOS), and windows-link (Windows). |
| vecmath 1.0.0, piston-float 1.0.1 | pdfium-render | MIT | Small and rarely released. |
| console_log 1.1.0 | pdfium-render, wasm only | `MIT/Apache-2.0` (old-style string) | Not built for the desktop targets; check the licence string again when the wasm targets join `deny.toml` in phase 5. |
| flatbuffers | rten | Apache-2.0 | |
| hayro-write | krilla (`pdf` feature) | Apache-2.0 OR MIT | |
| ICU4X support crates (zerovec, yoke, tinystr, litemap, writeable, potential_utf) | icu_casemap, icu_collator | Unicode-3.0 | |
| ravif, rav1e, exr, paste | `image` default features | BSD-2-Clause and others | Avoided by turning `image` default features off. `paste` is unmaintained (RUSTSEC-2024-0436). |
| dbus 0.7.x (pub) | desktop_drop, on every platform (unconditional import; used only on Linux at run time) | MPL-2.0 | **Approved by the owner on 2026-10-15** ([Q17](QUESTIONS.md#q17)), unmodified. From M2 its notice and source location ship with every build that includes desktop_drop. It is the only MPL-2.0 package, skipped by name in the pub licence check. |
| screen_retriever 0.2.2 (pub) | window_manager | MIT | |
| meta, vector_math 2.4.0 (pub) | path_parsing | BSD-3-Clause | |
| jni 1.1.0, jni_flutter 1.0.4+1, jni_util 1.0.0 (pub) | path_provider, through path_provider_android 2.3.1 | BSD-3-Clause | Publisher dart.dev. jni's build hook builds `libdartjni.so` (about 150 KB, BSD-3-Clause) into the Linux bundle's `lib/`, although desktop never uses it. Dropping unused native assets from desktop bundles is [B006](BACKLOG.md#open) (M5). |

**Proposed:** from M1, a script generates a full list of crates and pub packages with their licences from
`Cargo.lock` and `pubspec.lock` (through `cargo deny list` and very_good_cli's report) and appends it
to this file. CI fails if the generated list is out of date.

### 3.15 Not chosen yet

These needs are known. The dependency is picked, and its licence checked, in the milestone shown.

| Need | First milestone | Notes |
|---|---|---|
| UAX #14 line breaker | M3 | Chosen in M3 step 5. |
| File-change notification | M3 | **Proposed** for external-change detection; chosen in M3 step 8. |
| Adobe Glyph List, standard-14 AFM metrics, predefined CJK CMaps | M3 | Data files. Added only after their licences are checked and listed here. |
| Independent PDF structure checker for CI, for example qpdf (Apache-2.0) | M3 | **Proposed.** CI only; never shipped. |
| Similar-font candidates for missing glyphs | M3 | Cormorant Garamond and Crimson Pro (OFL-1.1), as a3-3b shows, bundled as unmodified upstream files ([Q08](QUESTIONS.md#q08) group 4, 2026-10-16); see [section 5.2](#52-fonts). Their release and embedding permissions are checked when they are added. |
| Printing package or platform channel | M4 | Basic system print comes in M4 ([Q10](QUESTIONS.md#q10), accepted on 2026-10-16). |
| Handwriting fonts for typed signatures | M4 | Caveat, Dancing Script and Homemade Apple ([Q08](QUESTIONS.md#q08) group 3, 2026-10-16); see [section 5.2](#52-fonts). |
| Regular-expression engine for find and replace patterns | P2 | Only if needed. |
| HTTP client with TLS for the network gateway | M5 | Uses the OS trust store. Only ferman-api's gateway may depend on it ([ARCHITECTURE.md §10.2](ARCHITECTURE.md#102-one-gateway)). Revocation lookups (OCSP, CRL) go through it from phase 3, off until first use; Ferman does no local-network discovery ([Q06](QUESTIONS.md#q06)). |
| Update framework for macOS and Windows | M5 | Reads a static, signed manifest per channel served from GitHub (Releases or Pages) ([Q15](QUESTIONS.md#q15)). Update packages are signature-checked. |
| Signing, notarization and installer tooling; Linux packaging | M5 | CI only. Linux formats: a Flatpak on Flathub and an AppImage ([Q12](QUESTIONS.md#q12)). |
| Office format readers and writers | P3 | Chosen in the conversion ADR. |
| Software PKCS#11 token for tests, for example SoftHSM2 | P3 | CI only. |
| PDF/A and PDF/UA validator | P4 | CI only; licence reviewed before use. |
| Local inference runtime and model for the AI assistant | P4 | Runtime and weight licences reviewed with the owner before bundling or offering a download. |
| Mobile platform packages | P5 | Chosen per step. |

## 4. Rejected

| Name | Ecosystem | Version seen | Licence | Why | How it is kept out |
|---|---|---|---|---|---|
| rustybuzz (as a direct dependency) | crate | 0.20.1 | MIT | Archived upstream; harfrust replaces it ([ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md), accepted on 2026-10-15, [Q04](QUESTIONS.md#q04)). krilla 0.8.2 may still pull it in for its own use. | cargo-deny ban `{ crate = "rustybuzz", wrappers = ["krilla"] }`, active from M1 step 1 |
| mupdf, mupdf-sys | crate | 0.8.0 | AGPL-3.0 | MuPDF and AGPL, both excluded by the brief. | cargo-deny ban |
| pdfium (crate) | crate | 0.10.4 | GPL-3.0 | A different PDFium wrapper whose name looks like the binding we want. GPL-3.0 would force the whole binary to GPL-3.0. | cargo-deny ban |
| jbig2dec (crate) | crate | 0.3.1 | GPL-3.0 | Wraps Artifex jbig2dec (AGPL, Ghostscript family). PDFium has its own permissive JBIG2 decoder. | cargo-deny ban |
| poppler-rs, poppler-sys-rs | crate | 0.26.0 | MIT bindings to GPL poppler | Link poppler (GPL-2.0-or-later or GPL-3.0, derived from xpdf). | cargo-deny ban |
| magick_rust | crate | not checked | links ImageMagick | ImageMagick renders PDF through its Ghostscript delegate (AGPL). | cargo-deny ban |
| libheif-sys, libheif-rs | crate | not checked | links LGPL-3.0 libheif | LGPL as the effective licence. | cargo-deny ban on libheif-sys |
| ffmpeg-sys-next | crate | not checked | links FFmpeg | FFmpeg is LGPL or GPL. | cargo-deny ban |
| Ghostscript, in any form | native | n/a | AGPL-3.0 | Excluded by the brief. No crate exists; watch for wrappers that shell out to `gs`, and for libvips (LGPL, loads PDF through poppler or PDFium). | review |
| custom_lint | pub | 0.8.1 | Apache-2.0 | Licence is fine, but it is stale: it pins analyzer ^8, which conflicts with riverpod_generator 4, and riverpod_lint 3 no longer uses it. | not in `pubspec.yaml`; review |
| golden_toolkit | pub | 0.15.0 | BSD-3-Clause | Discontinued and unlisted; its SDK constraint is below Dart 3. alchemist replaces it. | review |
| lucide_icons | pub | 0.257.0 | MIT | Stale (2023), Dart 2 SDK constraint. | review |
| lucide_icons_flutter | pub | 3.1.25 | MIT | A single-maintainer repackaging as an icon font, with Lucide's default 2 px stroke. The design system says "No icon font, no PNG icons, no sprite sheet." ([ADR 0013](adr/0013-fonts-and-icons.md)). | review |
| google_fonts | pub | not checked | not checked | Fetches fonts at run time, a network use the brief does not allow ([ADR 0015](adr/0015-privacy-and-network.md)). | pub deny list in CI since M1 step 2 (`pub_denylist`, approved on 2026-10-16, [section 8](#8-dart-licence-check)) |
| @ibm/plex npm packages | npm | 6.4.1 | OFL-1.1 | They hold only CSS, SCSS, WOFF and WOFF2 files (no TTF or OTF) and run an IBM telemetry script on install. Fonts come from IBM's GitHub releases instead. | review |
| flutter_svg, vector_graphics | pub | 2.3.0; 1.2.3 | MIT; BSD-3-Clause | Both depend on `http` (`^1.0.0`) and import `package:http` for their network loaders (`SvgPicture.network`), and the network deny list forbids HTTP clients in the app graph ([ADR 0015](adr/0015-privacy-and-network.md)). Dropped in M1 (`246d6df`, lead decision of 2026-10-15): the icons are painted from generated path data with path_parsing ([section 2.2](#22-dart-and-flutter-packages-app), [ADR 0013](adr/0013-fonts-and-icons.md)). | `tools/checks` `pub_denylist` fails on `http` in `app/pubspec.lock` (approved on 2026-10-16) |
| shared_preferences | pub | 2.5.6 | BSD-3-Clause | The licence is fine, but M1 step 9 chose its own settings file instead. On macOS shared_preferences writes to the user's preferences domain, outside the app data directory. `FileSettingsStore` (`app/lib/settings/settings_store_io.dart`) keeps `AppSettings` as versioned JSON in `settings.json` in the app support directory that path_provider reports, written with dart:io through a temporary file, a flush and a rename ([ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration)). The web build keeps settings in memory until phase 5. | not in `pubspec.yaml`; review |
| Playwright's ffmpeg build | CDN download | 1011 | LGPL-2.1 | `npx playwright-core install` downloads it with every Chromium, the headless shell included. The renderer never records video, so it is not needed, and an LGPL download is avoided rather than reviewed. | Ferman never runs the Playwright installer; `tools/design-refs/fetch-chromium.sh` downloads only the headless shell |
| dtolnay/rust-toolchain | GitHub Action | no versioned releases | MIT | Not needed: `rustup toolchain install` reads `rust-toolchain.toml`, so CI has one third-party action fewer. | review |

## 5. Bundled binaries and assets

These ship inside the app. Each one's licence text ships with it and appears in the licences screen
([G14](DESIGN_GAPS.md#g14)). Flutter's `LicenseRegistry` carries the texts to that screen.

### 5.1 PDFium

| Item | Value |
|---|---|
| Source | github.com/bblanchon/pdfium-binaries releases |
| Tag | `chromium/7881` (Chromium 151.0.7881.0, from each archive's `VERSION` file), the PDFium API level pdfium-render 0.9.4 targets. The newest tag, `chromium/8100`, is not used until it passes the full corpus and pixel-diff suite with a matching pdfium-render. PDFium has no runtime version API, so `engine_info()` reports this tag from the pin. |
| Variant | The plain build: no V8 (JavaScript) and no XFA. The V8 variant adds V8 (BSD-3-Clause), fdlibm and more attack surface. |
| Archives | `pdfium-mac-univ.tgz` on macOS: its two slices are byte-identical to the libraries of `pdfium-mac-x64.tgz` and `pdfium-mac-arm64.tgz` (`tools/pdfium/fetch.sh` checks this every time it unpacks it), so no `lipo` step is needed. `pdfium-win-x64.tgz` and `pdfium-win-arm64.tgz` (`bin/pdfium.dll`, which imports only KERNEL32, USER32, GDI32 and ADVAPI32, so no MSVC runtime), `pdfium-linux-x64.tgz` and `pdfium-linux-arm64.tgz` (`lib/libpdfium.so`; glibc 2.16 or 2.17). The macOS library needs macOS 12.0 and links only system frameworks. |
| SHA-256 per archive | Pinned in `tools/pdfium/pdfium.lock`, together with the SHA-256 of the library inside each archive (table below). `fetch.sh` refuses a mismatch and leaves nothing behind. |
| Signing | Upstream builds are unsigned. The library is signed with the app's identity when the app is packaged (M5, [Q02](QUESTIONS.md#q02)). |
| Licence | PDFium: BSD-3-Clause AND Apache-2.0. In the bblanchon archive, PDFium's own licence (both texts) is `licenses/pdfium.txt`. The top-level `LICENSE` is the packager's MIT notice (Copyright Benoit Blanchon), and it also ships, because it is part of the redistributed package. |
| Ship with the app | The library, bundled per platform since M1 phase E4 (`3e7bf8e`): `lib/libpdfium.so` in the Linux bundle next to `libferman_api.so`, `pdfium.dll` next to `ferman.exe` on Windows (both installed by the app's CMake files, which stop at configure time when the fetched library is missing), and `Contents/Frameworks/libpdfium.dylib` on macOS (the Runner target's Bundle Framework phase, with CodeSignOnCopy). The build takes it from `build/pdfium/<id>/`, so a desktop build needs `tools/pdfium/fetch.sh --platform <id>` first ([ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration)). With it, the archive's `LICENSE` (packager MIT notice) and its `licenses/` directory (15 files for chromium/7881), unchanged, committed flattened in `app/assets/licenses/pdfium/` (copied byte for byte from linux-x64). The upstream texts contain contributor contact details; licence texts ship unaltered. |

| Archive | Archive SHA-256 | Library SHA-256 |
|---|---|---|
| mac-arm64 | `52e94ca5aa8847934330daf3f8150c190682c5ca93831468794f8b90d4392e40` | `1bc45b15466b34cef96641ce25c77a876e70010c6b114f909dda2f5325fc5bd7` |
| mac-x64 | `6dedf83990e0e3d6b7c93c9e7589c5a126b0ae14b7464d76120cff7a26afb18b` | `4eaad6c3e8d786cf6f66a45d7d014edf5c65f372f98c3070e66595ebb50e43d9` |
| mac-univ | `df451a413c3609585e84a4a91110a9bc889cff05fe3b2db0ed817c9e90c3f7d3` | `3858ed6a6e785d87402287bcafbcea9e5777718c8a64ce266fed78ed1fbdfdae` |
| win-x64 | `73cc0de638ac2095e7445bf56a38200a5b7c7ca0e9f4ba144598f2457377ac08` | `79d4676b656cfb1abcea88f9ade3b4b0826c5200382db5f4ec72a636c598c118` |
| win-arm64 | `d3035d4d2cacac6ecd1a2ece197a3d702a1b2a58466276b9f870b8cb278a9d84` | `267a6f08a9c854d9949754a53b7630f23c0b67de5c7ca273b6abf178b49158c2` |
| linux-x64 | `1470e21b8b4a3b4ad7f85684e2da11d94f3b69a86d81dee11b9b6709d927ac1d` | `f728930966f503652b92acc89b9374a2eeca00ce42e26dccd3e4b5c5161b2d64` |
| linux-arm64 | `ee7f7b7d5468958336a818c1cd580bdd20972846b7377b13f9a923d92d1d4674` | `6252fce3da45e7f0dc5b27f4d4e1a1456ca3f7734cdb04f927967df772127478` |

Licence files in the `licenses/` directory of the `chromium/7881` archives. All seven archives hold the
same 15 files with the same wording, but not the same bytes: the Windows archives use CRLF line
endings, and in the macOS archives the BSD part of `pdfium.txt` (its first 27 lines) starts each line
with `// `. Linux and macOS are otherwise byte-identical. `fetch.sh --check-licenses` compares every
archive with the committed copies after turning CRLF into LF and removing a leading `// `.

| File in `licenses/` | Component | Licence | Obligation |
|---|---|---|---|
| `pdfium.txt` | PDFium | BSD-3-Clause AND Apache-2.0 | Notice; both texts ship |
| `abseil.txt` | Abseil | Apache-2.0 | Notice |
| `agg23.txt` | Anti-Grain Geometry 2.3 | AGG 2.3 permissive licence: the copyright notice must appear in all copies | Notice |
| `fast_float.txt` | fast_float | MIT (the text in the file) | Notice |
| `freetype.txt` | FreeType | FTL (FreeType is dual FTL or GPL-2.0-or-later; the archive carries the FTL text, and it is used under FTL) | The FTL credit line in the documentation and notices |
| `icu.txt` | ICU | Unicode-3.0 | Notice |
| `lcms.txt` | Little CMS | MIT | Notice |
| `libjpeg_turbo.ijg`, `libjpeg_turbo.md` | libjpeg-turbo | IJG AND BSD-3-Clause (its SIMD code is Zlib, covered by the IJG terms) | The IJG statement in the notices |
| `libopenjpeg.txt` | OpenJPEG | BSD-2-Clause | Notice |
| `libpng.txt` | libpng | libpng-2.0 | Notice |
| `libtiff.txt` | LibTIFF | libtiff | Notice |
| `llvm-libc.txt` | LLVM libc | Apache-2.0 WITH LLVM-exception | Notice |
| `simdutf.txt` | simdutf | MIT (the text in the file) | Notice |
| `zlib.txt` | zlib | Zlib | Notice (recommended) |

The 2026-10-13 check, made from PDFium's source tree, also named HarfBuzz, highway, dragonbox, libc++
and libunwind, and bigint. The 7881 archives carry no licence file for them (checked again for all seven
archives when `tools/pdfium` landed), so they are not listed. They are added here if a build ships them.

No GPL or AGPL code is in the shipped library. The obligations are attribution only.

### 5.2 Fonts

Fonts follow [ADR 0013](adr/0013-fonts-and-icons.md). The rules:

- We ship **IBM's unmodified static TTF files** from the IBM/plex GitHub releases
  (`fonts/complete/ttf`). We never subset, convert, rename or otherwise modify them, because the licence
  reserves the font name "Plex". Subsets that Ferman embeds into a user's PDF are document embedding,
  which OFL-1.1 allows.
- The design's woff2 subsets are not used ([G06](DESIGN_GAPS.md#g06)). The design's runtime Google Fonts
  `@import` is never used by the app ([G07](DESIGN_GAPS.md#g07)).
- Each family's `LICENSE.txt` ships next to its files in `app/assets/fonts/` and is registered with
  `LicenseRegistry`. The texts are missing from the design export ([G08](DESIGN_GAPS.md#g08));
  [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) carries them for the copies inside `design/`.
- `tools/fonts/fetch.sh` downloads the release zips, checks every SHA-256 in `tools/fonts/fonts.lock`
  (zip, licence and each TTF) and installs the files unmodified; `--verify-committed` is the offline
  check CI runs. The 18 TTFs and 6 licence files (3,919,740 bytes) are committed in `app/assets/fonts/`.
- All six `LICENSE.txt` files are identical (SHA-256
  `7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da`, with CRLF line endings as
  released).
- The weights are the design system's `@font-face` set in `tokens/fonts.css`, plus Plex Sans Italic 400
  for the font picker's missing state (`forms.css`), which the boards synthesise as an oblique
  ([G06](DESIGN_GAPS.md#g06)). Mono 600 appears only in the boards' own section numbers and weight 700
  only in a mobile large title, so neither is bundled.
- The licence opens with `Copyright © 2017 IBM Corp. with Reserved Font Name "Plex"`, followed by the
  full SIL Open Font License 1.1.

| Family | Source (IBM release) | Zip SHA-256 | Files | Licence | Status | First milestone |
|---|---|---|---|---|---|---|
| IBM Plex Sans | `@ibm/plex-sans@1.1.0` | `fb365d910566e6d199cc2c15579a7dd9a267128e18431a394ed81f1970c69200` | Regular, Italic, Medium, SemiBold (400, 400 italic, 500, 600); revision 3.005. Covers Latin, Turkish, Vietnamese, Cyrillic and Greek | OFL-1.1, Reserved Font Name "Plex" | Accepted (brief) | M1 |
| IBM Plex Serif | `@ibm/plex-serif@2.0.0` | `c006b095c47b919c6c8d78319e9e628745033f5db94507c1c9dfe4b35dd51f1e` | Regular, Italic, SemiBold (400, 400 italic, 600; the wordmark at 600); revision 3.006 | OFL-1.1, Reserved Font Name "Plex" | Accepted (brief) | M1 |
| IBM Plex Mono | `@ibm/plex-mono@2.5.0` | `6d23f01257663d8cc49a0d64c22ced630b79e0e2a0ac08a0da86e9a38bbc481c` | Regular, Medium (400, 500); revision 2.005 | OFL-1.1, Reserved Font Name "Plex" | Accepted (brief) | M1 |
| IBM Plex Sans Arabic | `@ibm/plex-sans-arabic@1.1.0` | `f03915581aea37d82792c188b08064023a73494d679b8e19f85f5971db714013` | Regular, Medium, SemiBold; revision 1.005. Also covers Persian (پ چ ژ گ ک ی and the Persian digits); does not map U+200C | OFL-1.1, Reserved Font Name "Plex" | Accepted (brief) | M1 |
| IBM Plex Sans Hebrew | `@ibm/plex-sans-hebrew@1.1.0` | `d7d490b8a767b972a7f361055fdcf60ad7cb7c270b38ff1bf859562a021369fd` | Regular, Medium, SemiBold; revision 1.003 | OFL-1.1, Reserved Font Name "Plex" | Accepted (owner, [Q08](QUESTIONS.md#q08), 2026-10-15) | M1 |
| IBM Plex Sans Devanagari | `@ibm/plex-sans-devanagari@1.1.0` | `effc4a35b2908c80806c97a4d5033e63f437611d17a3e09b237edd5c33d8ac94` | Regular, Medium, SemiBold; revision 1.002 | OFL-1.1, Reserved Font Name "Plex" | Accepted (owner, [Q08](QUESTIONS.md#q08), 2026-10-15) | M1 |
| Japanese, Korean, Simplified and Traditional Chinese | System fonts | n/a | Not bundled: IBM's CJK releases are 73 to 523 MB as zips. No font packs ([Q08](QUESTIONS.md#q08) group 2) | n/a | Accepted (brief; owner, Q08, 2026-10-15) | M1 |
| Caveat, Dancing Script (typed signatures) | Release chosen in M4 | n/a | Unmodified upstream files | OFL-1.1 | Accepted (owner, [Q08](QUESTIONS.md#q08) group 3, 2026-10-16) | M4 |
| Homemade Apple (typed signatures) | Release chosen in M4 | n/a | Unmodified upstream file | Apache-2.0 (not OFL) | Accepted (owner, [Q08](QUESTIONS.md#q08) group 3, 2026-10-16) | M4 |
| Cormorant Garamond, Crimson Pro (similar fonts for missing glyphs, a3-3b) | Release chosen in M3 | n/a | Unmodified upstream files; embedding must be allowed | OFL-1.1 | Accepted (owner, [Q08](QUESTIONS.md#q08) group 4, 2026-10-16) | M3 |
| EB Garamond (test corpus only) | `ofl/ebgaramond/EBGaramond[wght].ttf` and `OFL.txt` from google/fonts at commit `47d54ca` (2026-10-16), fetched by `tools/corpus/fetch-fonts.sh` into `build/corpus-fonts/` and pinned in `tools/corpus/fonts.lock` | `ef9512f9…5369027` (the TTF) | The variable font at its default instance; never committed, never shipped. Subsets of it are embedded in `kira-tr` (Madde 6), which OFL-1.1 allows | OFL-1.1, no Reserved Font Name | ok | M2 |

The per-TTF SHA-256 values are the `font` lines of `tools/fonts/fonts.lock`. Every pinned version is
the newest IBM release tag of its package (checked on 2026-10-15).

Script coverage, measured with `tools/fonts/coverage.py` (cmap of each file): Plex Sans covers Turkish,
Vietnamese U+1EA0 to U+1EF9, Cyrillic and Greek. Plex Sans Arabic, Hebrew and Devanagari each carry
full ASCII (95 of 95) and all Latin-1 letters (64 of 64), but not Latin Extended-A (only one of
İ ı Ğ ğ Ş ş), so Plex Sans comes first in every UI fallback chain (the `--font-ui` order,
[ARCHITECTURE.md §11.5](ARCHITECTURE.md#115-fonts-in-the-ui)), and Latin inside Arabic, Hebrew and
Devanagari text comes from Plex Sans.

### 5.3 Icons

| Item | Value |
|---|---|
| What ships | The design's exact path data for **229 icons**, drawn at a 1.5 px stroke ([ADR 0013](adr/0013-fonts-and-icons.md)). `tools/icons` writes them as SVG assets in `app/assets/icons/` (the design's markup byte for byte, the exported and provenance-tracked set) and as generated Dart path data, which the Icon widget paints with a `CustomPainter` through path_parsing. The SVGs are not loaded at run time. |
| Where they come from | 145 from `ICON_PATHS` in the design bundle (all match Lucide 0.460.0) and 84 from `ds-additions/fm-icons.js`: 77 match Lucide 0.460.0; bell, grid-2x2 and funnel match Lucide 1.56.0; paperclip matches 0.469.0 and 0.500.0; expand matches 0.500.0; file-signature matches 0.263.0 and 0.300.0; only ellipse matches no Lucide release ([G04](DESIGN_GAPS.md#g04), [G60](DESIGN_GAPS.md#g60)). |
| Provenance | `app/assets/icons/PROVENANCE.md`, generated: the Lucide release each glyph matches ("Lucide 0.460.0", "Lucide 1.56.0", "Lucide 0.500.0" or "Lucide 0.300.0"), or "Ferman design" for ellipse alone. That one glyph is project work and stays marked pending until the design re-export settles it ([Q11](QUESTIONS.md#q11)). The M1 run confirmed 222 glyphs from 0.460.0; bell, funnel and grid-2x2 from 1.56.0; expand and paperclip from 0.500.0; file-signature from 0.300.0 (`tools/icons/lucide_matches.json`). |
| Licences | Lucide: ISC. Icons derived from Feather: MIT (Cole Bemis). |
| Ship with the app | Both Lucide licence files, copied verbatim from the npm tarballs, which `tools/icons` checks against pinned hashes: `app/assets/icons/LICENSE-lucide-0.460.0.txt` (ISC; its copyright line names the Feather portions as MIT; byte-identical to the files of 0.263.0, 0.300.0, 0.469.0 and 0.500.0, so one copy covers the glyphs from those releases) and `app/assets/icons/LICENSE-lucide-1.56.0.txt` (ISC, plus the list of Feather-derived icons and the full MIT text). Both are registered with `LicenseRegistry` under "Lucide". |
| Not used | An icon font, lucide_icons_flutter, lucide_icons, flutter_svg ([section 4](#4-rejected)). |

### 5.4 Other notices

| What | Licence | How it reaches the licences screen | First milestone |
|---|---|---|---|
| Ferman itself | Apache-2.0 | Shown as Apache-2.0. The design says GPL-3.0 in a1-2c and a11-5; the app does not copy that ([G13](DESIGN_GAPS.md#g13)). | M1 |
| Flutter engine and framework, Dart packages | BSD-3-Clause and the packages' own licences | Flutter's build collects package and engine licences into the app's notices; `LicenseRegistry` reads them. | M1 |
| `dbus` (through desktop_drop, on every platform) | MPL-2.0 | Approved on 2026-10-15 ([Q17](QUESTIONS.md#q17)). Its notice names the licence and where the source is available (pub.dev), in every build that includes desktop_drop. | M2 |
| Rust crates | per crate | Generated by cargo-about. | M4 |
| PDFium, fonts, icons | sections 5.1 to 5.3 | Added by hand and registered with `LicenseRegistry` by `registerLicenses()` (`app/lib/app/licenses.dart`, 24 texts), which `bootstrap()` calls. | M1 to M4 |
| Unicode Character Database 15.0 and CLDR data (case tables in app/lib/l10n/casing.dart, territory lists in app/lib/l10n/region.dart, territory display names and their order per language in app/lib/l10n/region_names.dart (CLDR 48 read through ICU 78.3 in Node.js 24.22.0), grouping and date-time tables in app/lib/l10n/format.dart, SpecialCasing lines, ICU results and CLDR 48 formats in app/test/l10n/) | Unicode-3.0 | The Unicode License V3 that opens assets/licenses/pdfium/icu.txt, also registered under "Unicode data (UCD and CLDR)" | M1 |

## 6. Toolchain

| Tool | Version (verified 2026-10-13) | Licence | Used for | Notes |
|---|---|---|---|---|
| Rust stable | 1.99.0 (built 2026-09-28) | MIT OR Apache-2.0 | Engine and CLI | Pinned in `rust-toolchain.toml` (channel 1.99.0, profile minimal, with rustfmt and clippy). CI installs it with `rustup toolchain install`, which reads that file. The M0 container had 1.97.0. |
| Minimum Rust version (`rust-version`) | 1.88 (set in the workspace `Cargo.toml`) | n/a | Workspace manifest | 1.88 is set by lopdf 0.45, image 0.25.10, ICU4X 2.3, sha2 0.11, proptest 1.12 and cargo-deny 0.20. It rises to 1.92 with krilla 0.8 (P4) and to 1.94 with rten 0.27 (only if ocrs moves to it, P3). The pinned 1.99 toolchain is what builds Ferman; `rust-version` records the floor. |
| Rust nightly | `nightly-2026-10-15` (rustc 1.101.0-nightly, chosen in M2) | MIT OR Apache-2.0 | cargo-fuzz only | Pinned in `fuzz/rust-toolchain.toml`, which rustup reads inside `fuzz/`. Never used for shipped builds; formatting and Clippy of `fuzz/` use the stable 1.99.0. |
| Flutter | 3.47.7 stable (2026-10-08) | BSD-3-Clause | App | Beta 3.49.0-0.2.pre is not used. |
| Dart | 3.13.5 (bundled with Flutter 3.47.7) | BSD-3-Clause | App | very_good_analysis 11, riverpod_lint 3.1.9 and very_good_cli 1.5 need Dart 3.13 or later, so Flutter stays at 3.47 or later. |
| Node.js | 24.22.0 LTS "Krypton" (re-checked 2026-10-15) | MIT | Tools only (`tools/design-refs`) | The M1 pin, used in the development container and in CI. 26.x is the Current line; 22.x is in maintenance. Node is never part of the app. |
| playwright-core | 1.56.1 | Apache-2.0 | Design-reference renderer | Pinned to the Chromium revision 1194 preinstalled in the development container, where the Playwright CDN is blocked; CI uses the same revision, downloaded directly rather than through the Playwright installer ([section 2.3](#23-tools-never-shipped)). Needs Node 18 or later. |

## 7. deny.toml

`deny.toml` at the repository root is the file cargo-deny 0.20 reads. It follows
[ADR 0016](adr/0016-dependency-licence-policy.md), landed with the Cargo workspace in M1 step 1, and
passes `cargo deny check` (advisories, bans, licences, sources) with cargo-deny 0.20.2. The file itself
is the record; in short:

- `[graph]`: the six desktop targets (macOS, Windows and Linux on x64 and arm64; web and mobile targets
  join in phase 5) and `all-features = true`, so ferman-api's optional `frb` graph is checked too.
- `[licenses]`: confidence threshold 0.93; the allow-list of [section 1](#1-policy); one exception,
  NCSA for `libfuzzer-sys` only (approved in [Q17](QUESTIONS.md#q17), reachable only from `fuzz/`); a
  clarification for allo-isolate (Apache-2.0, pinned to the hash `0x0a6d4ed6` of its LICENSE, so a
  changed file stops matching and must be checked again); Ferman's own crates are checked too.
- `[bans]`: duplicate versions warn; wildcards are denied, except path dependencies between Ferman's
  unpublished crates (`allow-wildcard-paths`); denied crates: mupdf, mupdf-sys, pdfium (the GPL-3.0
  wrapper), jbig2dec, poppler-rs, poppler-sys-rs, magick_rust, libheif-sys, ffmpeg-sys-next, and
  rustybuzz except as krilla's wrapper (`{ crate = "rustybuzz", wrappers = ["krilla"] }`,
  [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md)). The HTTP client of the network gateway gets
  a ban with ferman-api as its only wrapper in M5 ([ADR 0015](adr/0015-privacy-and-network.md)).
- `[advisories]`: yanked crates are denied; `unmaintained = "workspace"` fails only for direct
  dependencies; every ignore needs a reason in the file and a note here (none so far).
- `[sources]`: crates.io only; unknown registries and git sources are denied.

Changes from the M0 proposal: the allo-isolate hash is set (the XXH32 of the normalised LICENSE text,
computed as cargo-deny does); the rustybuzz ban is active from M1 step 1; the `libfuzzer-sys` comment
records the owner's approval.

Notes:

- `include-dev = false` keeps the main licence check on the shipped graph; bans, advisories and sources
  still see dev-dependencies. Dev-dependency licences are checked by a second run on a copy with
  `include-dev = true`, which CI runs as the second step of the cargo-deny job:

  ```sh
  sed 's/^include-dev = false/include-dev = true/' deny.toml > deny-dev.toml
  cargo deny --all-features --config deny-dev.toml check licenses
  ```

- Since M2, CI also runs `cargo deny check` with this file for the `fuzz/` and `tools/corpus` workspaces
  (`--manifest-path`), and the dev-dependency licence run for `tools/corpus`
  ([ADR 0017](adr/0017-testing-and-ci.md), [ADR 0020](adr/0020-test-corpus.md)).
- With `unmaintained = "workspace"`, an unmaintained transitive crate (for example `paste` if `image`
  defaults slipped back in) does not fail CI. Such crates are caught by review and listed in
  [section 9](#9-known-risks).
- Every crate in the resolved M1 graph has a licence on the allow-list or an allowed side of an OR
  expression; the notable ones are listed in [section 2.1](#21-rust-crates). The rest of the allow-list
  is there so the planned crates resolve.

## 8. Dart licence check

cargo-deny does not see pub packages, so very_good_cli checks them with the same allow-list. On
2026-10-15 the check passes for `app/pubspec.lock` (107 packages), `tools/tokens/pubspec.lock`
(`tools/l10n/pubspec.lock` too, on 2026-10-16) and cargokit's build tool (54 packages, [section 2.3](#23-tools-never-shipped)). CI runs the command below
for `app/` in the Linux Flutter job (since `52603cb`).
MPL-2.0 is not on the list. The M1 graph has no MPL-2.0 package, so M1 runs the check without
`--skip-packages`. The owner approved `dbus` on 2026-10-15 ([Q17](QUESTIONS.md#q17),
[section 3.11](#311-flutter-and-dart-packages)), so `--skip-packages=dbus` is added in the same commit as
desktop_drop in M2, and any other MPL-2.0 package still fails the check. The flags were checked against very_good_cli's documentation on 2026-10-14. The
default dependency type is `direct-main` only, so the types are set explicitly.

```sh
very_good packages check licenses \
  --dependency-type=direct-main,direct-dev,transitive \
  --allowed=Apache-2.0,MIT,MIT-0,BSD-2-Clause,BSD-3-Clause,ISC,Zlib,0BSD,BSL-1.0,CC0-1.0,Unicode-3.0,Unicode-DFS-2016
# From M2, in the commit that adds desktop_drop (dbus approved in Q17): add --skip-packages=dbus
```

**Approved by the owner on 2026-10-16** (Proposed for M1 step 2 of [ROADMAP.md](ROADMAP.md) until
then): a second check fails if `pubspec.lock` contains an HTTP client, a font downloader such as
google_fonts, or an analytics or crash-reporting SDK ([ADR 0015](adr/0015-privacy-and-network.md)). It exists as `pub_denylist` in `tools/checks`, which
fails on direct and transitive entries alike (its map of transitive exceptions is empty). It caught
`http` arriving through flutter_svg, which was then dropped ([section 4](#4-rejected)). It reads only
`app/pubspec.lock`: the `http` and `github` packages of cargokit's build tool run at build time, never
ship, and are a known build-time exception.

## 9. Known risks

| Risk | Effect | What we do | When |
|---|---|---|---|
| **Fontations version split.** harfrust 0.14 and skrifa 0.48 use read-fonts 0.45. krilla 0.8.2 and subsetter 0.2.6 (with `variable-fonts`) use skrifa 0.42, read-fonts 0.39 and write-fonts 0.48. | Two copies in the binary; font handles cannot be passed between the APIs. | Pin exact versions. Upgrade skrifa, read-fonts, the shaper, subsetter and krilla together. Keep subsetter's `variable-fonts` off. Prefer a krilla release that has moved to harfrust. cargo-deny warns on duplicates. | M2 to P4 |
| **Shaper.** The brief names rustybuzz, which is archived upstream; harfrust replaces it, but it is pre-1.0. | Without the switch, no fixes for shaping bugs, new Unicode versions or font-parsing security issues; with harfrust, frequent breaking releases. | [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md), accepted on 2026-10-15 ([Q04](QUESTIONS.md#q04)): harfrust pinned exactly and upgraded with the font stack, rustybuzz banned except through krilla. The `Shaper` trait keeps the shaper in one module. | M3 |
| **cms 0.2 versus 0.3 release candidate.** 0.2.3 (2024) uses der 0.7, x509-cert 0.2, spki 0.7 and digest 0.10; the current crates are x509-cert 0.3, der 0.8 and sha2 0.11. | Two RustCrypto stacks in one build, or a release candidate in production. | Wait for cms 0.3.0, or pin the release candidate after review. | P3 |
| **rsa timing advisory** (RUSTSEC-2023-0071, no fix). | Private-key operations could leak through timing. | rsa for verification only; sign through PKCS#11 (cryptoki), the OS keystore or aws-lc-rs. | P3 |
| **`image` default features.** They pull ravif, rav1e, exr and the unmaintained `paste`. | Heavier builds; the advisory gate trips. | `default-features = false` with `png`, `jpeg`, `tiff`, `webp`, `gif` and `rayon`. | M4 |
| **ocrs is Latin-only and its model licence is unclear.** Weights trained on HierText (CC-BY-SA-4.0) with no published licence. | Turkish, Arabic and CJK recognition poor or missing; models we may not be able to ship. | The engine is chosen at the start of phase 3 after a fresh check ([Q16](QUESTIONS.md#q16)); licence review before any model ships; Tesseract with Leptonica is the fallback. | P3 |
| **PDFium tag pinning and SHA verification.** Builds are weekly, third-party and unsigned; the newest tag (8100) is ahead of what pdfium-render 0.9.4 targets (7881). | Supply-chain risk; API mismatches. | Pin `chromium/7881`; verify a SHA-256 per archive in CI; non-V8, non-XFA build; sign with the app in M5; upgrade PDFium and pdfium-render together, in one commit, after the corpus and pixel-diff suite passes. | M1 |
| **PDFium is not thread-safe and runs in-process.** pdfium-render's `thread_safe` feature is one global lock. | One render thread limits throughput; a PDFium crash ends the app. | One render thread with the lock as a second guard; caches and prefetch; helper processes if M2 measurements demand it ([ADR 0009](adr/0009-threading-and-jobs.md)). | M2 |
| **lopdf churn.** Breaking releases almost monthly. | Upgrades break the build. | Pin `=0.45`; wrap it inside ferman-core; upgrade on purpose with the corpus as the safety net. | M2 |
| **Slow-moving crates and packages.** unicode-bidi (last release 2024-12), ttf-parser (2024-11), threadpool through flutter_rust_bridge (2020), freezed_annotation (2025-07), file_selector (2025-11), atomicwrites (2024). | Unfixed bugs; future unmaintained advisories. | Prefer maintained alternatives where they exist (ICU4X bidi data, read-fonts instead of ttf-parser); avoid atomicwrites and freezed; watch advisories. | M1 onwards |
| **flutter_rust_bridge version lockstep.** The crate, the Dart package and the codegen must match exactly; 2.14 is in beta. | A mismatch fails at run time or generates wrong bindings. | Pin all three to 2.13.0; `tools/checks` compares the crate and the package, and the CI codegen job installs exactly 2.13.0 (no separate `--version` comparison); generated code is committed and regenerated in CI; all three move in one commit. | M1 |
| **allo-isolate licence metadata.** Declared through a licence file, shown as "non-standard". | cargo-deny cannot classify it. | `[[licenses.clarify]]` with the file hash (`0x0a6d4ed6`); a changed file fails the check, so every FRB upgrade re-checks it. | M1 |
| **desktop_drop pulls MPL-2.0 `dbus` on every platform** (unconditional import; used only on Linux at run time). | A notice obligation in every desktop build; a licence outside the allow-list. | Approved by the owner on 2026-10-15 ([Q17](QUESTIONS.md#q17)). Ship its notice with the source location in every build that includes desktop_drop, and skip it by name in the pub check so no other MPL-2.0 package passes. | M2 |
| **Swatinem/rust-cache is LGPL-3.0.** | None for users: it runs only in CI and is never distributed. | Approved by the owner on 2026-10-15 ([Q17](QUESTIONS.md#q17)). Pin by SHA; never vendor or copy its code. | M1 |
| **playwright-core is pinned behind the newest release** (1.56.1, while 1.64.1 exists) to match the browser in the development container. | Missing newer Playwright fixes; renders tied to Chromium 141. | Renders are references for review, not shipped code. Move the container browser and the pin together, in one commit, and re-render. | M1 |
| **The Playwright installer also downloads an LGPL-2.1 ffmpeg build** with every Chromium, the headless shell included. | An LGPL download on CI runners and developer machines that the licence policy would have to review, for a component the renderer never runs. | Never run `npx playwright-core install`. CI downloads only the revision 1194 headless shell with `tools/design-refs/fetch-chromium.sh`, checks its SHA-256 and passes its path with `--chromium`; nothing needs owner review. The script's hash is pinned from the first CI download. | M1 |
| **The pub deny list and SVG rendering.** flutter_svg and vector_graphics depend on `http`. | An HTTP client in the app graph, against [ADR 0015](adr/0015-privacy-and-network.md). | flutter_svg dropped; icons painted from path data with path_parsing; `pub_denylist` keeps `http` out. | M1 |
| **Plex Reserved Font Name.** | Shipping a modified or subset Plex file under the "Plex" name would breach the licence. | Ship IBM's unmodified TTFs only ([section 5.2](#52-fonts)). | M1 |
| **Minimum Rust version rises.** 1.88 for the core set, 1.92 with krilla, 1.94 with rten 0.27. | Builds fail on older toolchains. | The toolchain is pinned (1.99); `rust-version` is raised in the same commit as the crate that needs it. | M1 onwards |
| **rust_lib_ferman has no Swift Package Manager support.** On macOS cargokit builds the plugin through CocoaPods, and Flutter 3.47.7 warns that the plugin does not support Swift Package Manager, which "will become an error in a future version of Flutter". | A later Flutter upgrade could fail the macOS build. | Add a `Package.swift` to `app/rust_builder` ([B007](BACKLOG.md#open)) before the Flutter upgrade that makes it an error, by M5 at the latest. | M5 |
| **Lucide naming drift.** The design pinned Lucide 0.460.0; the current release is 1.56.0. | Icon names may differ between releases. | Ferman ships path data, not names; the provenance table records the source version of each glyph. | M1 |

## 10. What could not be verified

From the environment used on 2026-10-13, api.github.com, osv.dev, Hugging Face and
pdfium.googlesource.com were blocked. As a result:

- The release dates of the bblanchon/pdfium-binaries tags and of the GitHub Actions versions are not
  confirmed. The tags were listed with `git ls-remote`. On 2026-10-14 the `chromium/7881` archives for
  linux-x64, mac-arm64 and win-x64 were downloaded to check their licence files
  ([section 5.1](#51-pdfium)).
- The ocrs model card could not be read, so the licence of the model weights is unknown.
- No full RustSec scan was run. Known advisories were spot-checked: `paste`, `rsa`, `lru`, `dashmap`.
- The transitive licence scan resolved about 356 runtime crates and 100 dev crates from the crates.io
  sparse index, with default features, every target and the newest matching versions. Every licence was
  on the allow-list or offered an allowed option inside an OR, apart from the two anomalies in this file
  (allo-isolate, libfuzzer-sys). No GPL-only, LGPL-only, AGPL, MPL or non-commercial crate appeared, and
  nothing derived from MuPDF or Ghostscript. The resolver is an approximation: `cargo deny check` is
  re-run on the first real `Cargo.lock` in M1. It was: `cargo deny check` passes on the M1 graph
  ([section 2.1](#21-rust-crates)).

## 11. Adding or changing a dependency

1. Check the licence of the dependency and of everything it pulls in: `cargo deny check` for Rust, the
   very_good_cli check for Dart, the upstream licence files for anything else.
2. If the licence is outside the allow-list, is MPL-2.0, covers data or model weights, or cannot be
   verified, stop and ask the owner in [QUESTIONS.md](QUESTIONS.md). Continue without the dependency.
3. Prefer maintained, widely used crates and packages. Turn off default features you do not need.
4. Pin exactly where releases break often: lopdf, the fontations stack (skrifa, read-fonts, the shaper,
   subsetter, krilla) and flutter_rust_bridge.
5. In the same commit, update this file: name, purpose, exact version, SPDX licence, status, first
   milestone and notes. Move the row from "Planned" to "In use" when it lands.
6. For bundled binaries, fonts, icons and data files, also record the source, version or tag, SHA-256
   and where the licence file ships, and register the licence with `LicenseRegistry`.
7. Upgrades that move together go in one commit: PDFium with pdfium-render; the flutter_rust_bridge
   crate, Dart package and codegen; the fontations stack.
8. A new licence on the global allow-list, or a change to this policy, needs an ADR the owner approves.

See also: [ARCHITECTURE.md](ARCHITECTURE.md), [ROADMAP.md](ROADMAP.md),
[ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md), [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md),
[ADR 0013](adr/0013-fonts-and-icons.md), [ADR 0016](adr/0016-dependency-licence-policy.md),
[ADR 0017](adr/0017-testing-and-ci.md), [CONTRIBUTING.md](../CONTRIBUTING.md).
