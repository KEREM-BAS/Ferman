# Dependencies

This file lists every dependency Ferman uses or plans to use, with its licence. The brief requires it
([brief §3](BRIEF.md)): "list every dependency with its licence in docs/DEPENDENCIES.md". The policy
behind it is [ADR 0016](adr/0016-dependency-licence-policy.md).

Versions, licences and release dates were checked on 2026-10-13 against crates.io, pub.dev, npm and the
upstream repositories. A few items were re-checked on 2026-10-14; they say so. "First milestone" follows
the brief's roadmap as detailed in [ROADMAP.md](ROADMAP.md). The dependency research guessed its own
phases; every row here has been remapped to the roadmap.

## Contents

1. [Policy](#1-policy)
2. [In use today](#2-in-use-today)
3. [Planned dependencies](#3-planned-dependencies)
4. [Rejected](#4-rejected)
5. [Bundled binaries and assets](#5-bundled-binaries-and-assets)
6. [Toolchain](#6-toolchain)
7. [Proposed deny.toml](#7-proposed-denytoml)
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
it out. The owner is asked to confirm it in [Q17](QUESTIONS.md#q17), the same question as the first
MPL-2.0 case, `dbus` (below). Until the owner answers, the stricter reading applies.

**Allowed for code (Rust and Dart):** Apache-2.0, Apache-2.0 WITH LLVM-exception, MIT, MIT-0,
BSD-2-Clause, BSD-3-Clause, ISC, Zlib, 0BSD, BSL-1.0, CC0-1.0, Unicode-3.0, Unicode-DFS-2016. An OR
expression is fine when one side is on this list. Examples: `MIT OR Apache-2.0 OR LGPL-2.1-or-later`
(r-efi) and `Apache-2.0 OR GPL-2.0-only` (self_cell); cargo-deny takes the permissive side.

**Allowed only per package, after review:**

- MPL-2.0 for an unmodified dependency, with a notice, once the owner approves that package. One case
  is pending owner approval: `dbus`, which desktop_drop depends on for every platform
  ([Q17](QUESTIONS.md#q17), [section 3.11](#311-flutter-and-dart-packages)). None is approved yet.
- NCSA for `libfuzzer-sys`, only in the separate `fuzz/` workspace, which never ships. Pending
  [Q17](QUESTIONS.md#q17); `fuzz/` is not created until then.
- OFL-1.1 (and Apache-2.0 for Homemade Apple, if it ships) for font files only, never as a code licence.
- Tools that run only in CI (for example the LGPL-3.0 Swatinem/rust-cache action). They are never
  distributed, and their code is never vendored or copied. Swatinem/rust-cache is pending
  [Q17](QUESTIONS.md#q17); until then CI caches with actions/cache (MIT) or not at all.

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
  ([section 7](#7-proposed-denytoml)).
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

None — M0 is documentation only. There is no `Cargo.toml`, `pubspec.yaml`, lockfile, bundled binary,
font or icon in the repository yet. The first real entries arrive with M1 step 1.

## 3. Planned dependencies

Versions are the latest releases on 2026-10-13. The exact pin is set when the dependency is added and
recorded here. MSRV is the minimum Rust version a crate declares.

### 3.1 Bridge, errors and logging

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| flutter_rust_bridge (crate) | Rust side of the Dart–Rust bridge | 2.13.0 (2026-08-23) | MIT | ok | M1 | Pin `=2.13.0`. The crate, the Dart package and the codegen must be the same version; CI compares them ([ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md)). 2.14.0-beta.2 exists and is not used. Optional, behind ferman-api's `frb` feature. Pulls allo-isolate (needs a cargo-deny clarify entry), dart-sys, threadpool, backtrace, oslog and android_logger. MSRV 1.70. |
| thiserror | Error types in every crate | 2.0.21 (2026-09-23) | MIT OR Apache-2.0 | ok | M1 | [ADR 0010](adr/0010-error-handling-no-panics.md). MSRV 1.77. |
| tracing, tracing-subscriber | Structured logs and spans, kept on the device | tracing 0.1.44 (2025-12-18); tracing-subscriber version set in M1 | MIT | ok | M1 | Logs never leave the device ([ADR 0015](adr/0015-privacy-and-network.md)). tracing MSRV 1.65. |

### 3.2 PDF and rendering

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| lopdf | Document model: parsing, incremental and full writes. The source of truth | 0.45.0 (2026-09-08) | MIT | ok | M2 | Pin `=0.45`: breaking minor releases come almost monthly (0.41 to 0.45 between June and September 2026). Wrapped inside ferman-core so an upgrade touches one crate. `embed_image` and `async` features off. Pulls aes, cbc, ecb, md-5, sha2 0.11, brotli-decompressor, encoding_rs and stringprep. MSRV 1.88. [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md). |
| pdfium-render | Safe Rust binding to PDFium, used as a read-only rasteriser | 0.9.4 (2026-09-06) | MIT OR Apache-2.0 | ok | M1 | `default-features = false` with `pdfium_7881`, `thread_safe` and `image_025`. PDFium is not thread-safe: `thread_safe` puts every call behind one global lock, and Ferman also keeps PDFium on one render thread ([ADR 0009](adr/0009-threading-and-jobs.md), Proposed). Binds at run time (`bind_to_library`), because the prebuilt builds are shared libraries only. Never used to edit or save. Not the GPL-3.0 `pdfium` crate. MSRV 1.61. M1 step 3 ([ROADMAP.md](ROADMAP.md)): `tools/pdfium` with a pinned SHA-256 per archive, and a skeleton render thread that loads PDFium and reports its version. Page rendering starts in M2. |
| PDFium (prebuilt, bblanchon/pdfium-binaries) | Native renderer loaded by pdfium-render | tag `chromium/7881`; newest tag is `chromium/8100` | BSD-3-Clause AND Apache-2.0; the packager's notice is MIT; plus bundled third-party licences | caution | M1 | Caution is for the notice obligations and the supply chain, not the licence. Details in [section 5.1](#51-pdfium). |
| image | Raster decode and encode: compress, insert images, OCR input | 0.25.10 (2026-03-10) | MIT OR Apache-2.0 | caution | M4 | `default-features = false` with `png`, `jpeg`, `tiff`, `webp`, `gif` and `rayon`. The defaults pull the AVIF encoder (ravif and rav1e, BSD-2-Clause), exr and the unmaintained `paste` (RUSTSEC-2024-0436). pdfium-render already brings `image` with default features off (JPEG only) from M1. MSRV 1.88. |
| hayro | Optional pure-Rust rasteriser: web fallback and cross-checks | 0.8.0 (2026-10-04) | Apache-2.0 OR MIT | ok | P5 | By the krilla author. Does not match PDFium's fidelity yet. Considered only for the web build. |

### 3.3 Fonts and text

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| skrifa | Font metadata, outlines and glyph metrics (fontations) | 0.48.0 (2026-10-03) | MIT OR Apache-2.0 | ok | M2 | Pin exactly. Pre-1.0, with breaking changes every few weeks. Upgrade together with read-fonts, the shaper and subsetter. MSRV 1.85. |
| read-fonts | Low-level OpenType table parsing; the base of skrifa and harfrust | 0.45.0 (2026-10-03) | MIT OR Apache-2.0 | ok | M2 | Used instead of ttf-parser for any direct table access. MSRV 1.85. |
| rustybuzz | Text shaping, as named in brief §3 | 0.20.1 (2024-11-12) | MIT | caution | M3 | Archived upstream; its README points to HarfRust. It stays the shaper until the owner decides on [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md) ([Q04](QUESTIONS.md#q04)). Sits behind ferman-fonts' `Shaper` trait, so a switch touches one module. Moves to [section 4](#4-rejected) if ADR 0007 is approved; the cargo-deny ban, with `wrappers = ["krilla"]` so krilla may still pull it in, is added then ([section 7](#7-proposed-denytoml)). |
| harfrust | Text shaping (Rust port of HarfBuzz) | 0.14.0 (2026-10-04) | MIT | ok | M3 | **Proposed** in ADR 0007; needs the owner's approval ([Q04](QUESTIONS.md#q04)). Official successor to rustybuzz in the harfbuzz organisation. Built on read-fonts 0.45, the same version skrifa 0.48 uses. Pin exactly. MSRV 1.85. |
| subsetter | TrueType and CFF subsetting for fonts embedded in PDFs | 0.2.6 (2026-06-04) | MIT OR Apache-2.0 | ok | M3 | From the typst project. Keep the `variable-fonts` feature off: it pulls skrifa 0.42, write-fonts 0.48 and kurbo, a second fontations stack. MSRV 1.85. |
| fontdb | System font discovery and fallback | 0.24.0 (2026-07-29) | MIT | ok | M3 | Missing-glyph step 2 and notices such as "Garamond isn't installed" ([ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md)). Pulls ttf-parser, memmap2, slotmap (Zlib) and, on Linux, fontconfig-parser. MSRV 1.71. |
| ttf-parser | Font parsing, transitive only | 0.25.1 (2024-11-29) | MIT OR Apache-2.0 | caution | M3 | Arrives through fontdb (and rustybuzz). Never a direct dependency; use read-fonts or skrifa. No release since November 2024. |

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
| crossbeam-channel | Queues between the bridge, document actors and the render thread | 0.5.17 (2026-09-05) | MIT OR Apache-2.0 | ok | M2 | Alternatives: `std::sync::mpsc` or flume 0.12.0 (Apache-2.0 OR MIT). MSRV 1.60. |
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
| krilla | PDF generation for PDF/A, PDF/UA and tagged output | 0.8.2 (2026-06-04) | MIT OR Apache-2.0 | caution | P4 | MSRV 1.92. 0.8.2 pulls the archived rustybuzz (default `simple-text` feature) and skrifa 0.42, a second fontations stack. krilla's main branch has moved to harfrust and newer skrifa; prefer the next release. The `pdf` feature uses hayro-write (Apache-2.0 OR MIT). Brief §3: verify before use. |

### 3.9 OCR (P3)

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| ocrs | On-device text recognition for scans | 0.13.1 (2026-09-13) | MIT OR Apache-2.0 | caution | P3 | Early preview that recognises the Latin alphabet only, so Turkish ğ, ş, ı and İ are unproven and Arabic and CJK are not covered. Models are downloaded separately; they were trained on HierText (CC-BY-SA-4.0) and no licence for the weights is published. Needs the owner's decision ([Q16](QUESTIONS.md#q16)) and a licence review before any model ships or downloads. |
| rten | Inference runtime used by ocrs | 0.27.0 (2026-10-02); ocrs 0.13.1 needs 0.26.x | MIT OR Apache-2.0 | ok | P3 | Pin 0.26.x to match ocrs and avoid two copies. 0.27 needs Rust 1.94. Its flatbuffers dependency is Apache-2.0. |
| Tesseract with Leptonica (alternative) | OCR engine, native | not checked | Apache-2.0; Leptonica BSD-2-Clause | caution | P3 | The fallback if Q16 rules out ocrs. Adds a native build per platform; the licences of language data files are checked before use. |

### 3.10 Dev and test (Rust)

None of these ship. They never appear in the shipped dependency graph
([ARCHITECTURE.md §2.2](ARCHITECTURE.md#22-dependency-graph)).

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| proptest | Property tests for parser and edit invariants | 1.12.0 (2026-10-10) | MIT OR Apache-2.0 | ok | M1 | MSRV 1.88. |
| insta | Snapshot tests: object trees, extracted text | 1.49.0 (2026-10-03) | Apache-2.0 | ok | M1 | Pulls similar (Apache-2.0) and console (MIT). MSRV 1.66. |
| criterion | Benchmarks for render, text and save | 0.8.2 (2026-02-04) | Apache-2.0 OR MIT | ok | M2 | Now under the criterion-rs organisation. Pulls plotters (MIT), ciborium (Apache-2.0) and tinytemplate. MSRV 1.86. |
| cargo-fuzz (tool) | Fuzz targets for every parser | 0.13.2 (2026-06-09) | MIT OR Apache-2.0 | ok | M2 | From the first parser in M2 ([brief §5](BRIEF.md)), once [Q17](QUESTIONS.md#q17) approves libfuzzer-sys. Needs nightly. Linux and macOS are first-class; Windows needs MSVC ASan and has limits. Targets live in the separate `fuzz/` workspace. |
| libfuzzer-sys | libFuzzer runtime for the fuzz targets | 0.4.13 (2026-06-04) | (MIT OR Apache-2.0) AND NCSA | caution | M2 | NCSA covers the vendored LLVM libFuzzer and is permissive, but it is outside the allow-list, so it is **pending owner approval** ([Q17](QUESTIONS.md#q17)). If approved, it is a cargo-deny exception for this crate only, in `fuzz/` only. `fuzz/` is not created until then. |

### 3.11 Flutter and Dart packages

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| flutter_rust_bridge (Dart) | Dart side of the bridge | 2.13.0 (2026-08-23) | MIT | ok | M1 | Same version as the crate and the codegen. Its dependencies (args, async, build_cli_annotations, logging, meta, path, web) are MIT or BSD-3-Clause. |
| flutter_riverpod | State management | 3.4.3 (2026-09-03) | MIT | ok | M1 | Dart ^3.12. Verified publisher dash-overflow.net. [ADR 0011](adr/0011-flutter-state-navigation-components.md). |
| riverpod_annotation | Annotations for Riverpod code generation | 4.0.7 (2026-09-03) | MIT | ok | M1 | Locked to riverpod 3.4.3. |
| riverpod_generator | Riverpod code generator (dev) | 4.0.9 (2026-09-03) | MIT | ok | M1 | Needs analyzer >=13 <15, which is why custom_lint cannot be used. |
| build_runner | Runs the code generators (dev) | 2.16.2 (2026-10-07) | BSD-3-Clause | ok | M1 | Dart ^3.11. Publisher tools.dart.dev. |
| riverpod_lint | Riverpod lints (dev) | 3.1.9 (2026-09-03) | MIT | ok | M1 | A native analyzer plugin (analysis_server_plugin), enabled under `plugins:` in `analysis_options.yaml`. Not custom_lint. Needs Dart 3.13. No verified publisher. |
| go_router | Navigation | 18.0.2 (2026-09-28) | BSD-3-Clause | ok | M1 | Flutter >=3.44. Publisher flutter.dev. |
| very_good_analysis | Lint rule set (dev) | 11.0.0 (2026-09-03) | MIT | ok | M1 | Dart ^3.13. Required by [brief §5](BRIEF.md). |
| intl | Messages, dates and numbers | 0.20.3 (2026-06-25) | BSD-3-Clause | ok | M1 | flutter_localizations requires `^0.20.3`. |
| flutter_localizations | Framework localisations and RTL support | SDK (Flutter 3.47.7) | BSD-3-Clause | ok | M1 | Part of the Flutter SDK; used with gen-l10n ([ADR 0014](adr/0014-localization-and-rtl.md)). |
| window_manager | Custom title bars, window size and state | 0.5.2 (2026-07-04) | MIT | ok | M1 | Windows, macOS and Linux only. Pulls screen_retriever (MIT). |
| flutter_svg | Renders the icon SVGs | 2.3.0 (2026-05-08) | MIT | ok | M1 | Flutter >=3.35. Publisher flutter.dev. Pulls vector_graphics (BSD-3-Clause), xml and petitparser (MIT). Precompiling with vector_graphics_compiler is optional; its licence is checked before use. |
| path_provider | App support, cache and data directories (autosave, recovery) | 2.1.6 (2026-06-15) | BSD-3-Clause | ok | M1 | Flutter >=3.38. |
| shared_preferences | UI preferences, if chosen | 2.5.6 (2026-10-05) | BSD-3-Clause | ok | M1 | Only if M1 step 9 chooses it. The alternative is a settings file owned by the Rust core and shared with the CLI ([ADR 0011](adr/0011-flutter-state-navigation-components.md)). Use the `SharedPreferencesAsync` API. |
| alchemist | Golden tests (dev) | 0.14.1 (2026-10-08) | MIT | ok | M1 | Publisher betterment.dev. Replaces golden_toolkit. Goldens load the real fonts ([brief §5](BRIEF.md)). |
| mocktail | Mocks for tests (dev) | 1.0.5 (2026-04-10) | MIT | ok | M1 | |
| desktop_drop | Drag and drop onto the window | 0.8.4 (2026-09-01) | Apache-2.0 | caution | M2 | Depends on `dbus` (Canonical, 0.7.x, MPL-2.0) on every platform: the dependency is unconditional in its pubspec, and `lib/src/channel.dart` imports `package:dbus` unconditionally and checks the platform only at run time, using it on Linux. **`dbus` is pending owner approval** ([brief §9](BRIEF.md), [Q17](QUESTIONS.md#q17)), so desktop_drop is not added until the owner approves. If approved, the `dbus` notice and source location ship with every build that includes desktop_drop, and `dbus` gets a named skip in the pub licence check ([section 8](#8-dart-licence-check)). If not, drag and drop needs another package or a platform channel. No iOS support. |
| file_selector | OS-native open, save and folder pickers | 1.1.0 (2025-11-21) | BSD-3-Clause | ok | M2 | [ADR 0018](adr/0018-native-file-pickers.md) (Proposed, [Q07](QUESTIONS.md#q07)). Flutter >=3.35. All six platforms. Slow releases. |
| freezed, freezed_annotation | Data classes and unions | 4.0.2 (2026-09-18); 3.1.0 | MIT | caution | not planned | Added only if a clear need appears ([ADR 0011](adr/0011-flutter-state-navigation-components.md)). Dart 3 records, sealed classes and the FRB-generated classes cover most cases. freezed_annotation has had no release since 2025-07. |

### 3.12 Tooling

None of these ship with the app. Toolchains are in [section 6](#6-toolchain).

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| flutter_rust_bridge_codegen | Generates the bridge bindings | 2.13.0 | MIT | ok | M1 | `cargo install flutter_rust_bridge_codegen --locked --version 2.13.0`, matching the runtime. MSRV 1.74. |
| cargo-deny | Licence, ban, advisory and source gate | 0.20.2 (2026-07-09) | MIT OR Apache-2.0 | ok | M1 | Since 0.18.4, GNU licences are matched strictly. The old `deny`, `copyleft`, `allow-osi-fsf-free` and `default` keys are gone; only the allow-list and exceptions apply. MSRV 1.88. |
| very_good_cli | Licence gate for Dart packages | 1.5.0 (2026-09-08) | MIT | ok | M1 | `very_good packages check licenses` ([section 8](#8-dart-licence-check)). Needs Dart 3.13. |
| cargo-about | Generates the Rust third-party notices | 0.9.2 (2026-08-18) | MIT OR Apache-2.0 | ok | M4 | Feeds the licences screen in M4 ([G14](DESIGN_GAPS.md#g14)); every release from M5 bundles its output. PDFium, fonts and icons are merged in by hand. MSRV 1.88. |
| Playwright | Renders every artboard to PNG for comparison | 1.64.0 | Apache-2.0 | ok | M1 | `tools/design-refs`, with a lockfile. Needs Node 20 or later. Browsers it downloads stay on dev machines and CI. |
| React, ReactDOM | Runtime the design export needs to render | 18.3.1 | MIT | ok | M1 | The export loads them from unpkg.com at run time (`design/support.js`). Vendored in `tools/design-refs` so rendering works offline. Never in the app ([brief §2](BRIEF.md)). |
| @babel/standalone | JSX transform the design export needs to render | 7.29.0 | MIT | ok | M1 | Same as React. |
| Design-reference fonts | The 13 families the export loads from Google Fonts | not chosen | OFL-1.1; Homemade Apple Apache-2.0 | ok | M1 | Vendored for `tools/design-refs` only, with their licences, so the renderer never touches the network ([G07](DESIGN_GAPS.md#g07)). Never in the app. |

### 3.13 GitHub Actions

Every third-party action is pinned by full commit SHA, with the version in a comment
([ADR 0017](adr/0017-testing-and-ci.md)).

| Name | Purpose | Version (verified 2026-10-13) | SPDX licence | Status | First milestone | Notes |
|---|---|---|---|---|---|---|
| actions/checkout | Checkout | v7.0.1 | MIT | ok | M1 | |
| dtolnay/rust-toolchain | Installs the Rust toolchain | no versioned releases (branch refs; the only tag is `v1`) | MIT | ok | M1 | Pin a commit SHA; the toolchain itself comes from `rust-toolchain.toml`. |
| subosito/flutter-action | Installs Flutter | v2.23.0 | MIT | ok | M1 | `flutter-version: 3.47.7`. |
| EmbarkStudios/cargo-deny-action | Runs cargo-deny | v2.1.1 | MIT OR Apache-2.0 | ok | M1 | |
| Swatinem/rust-cache | Cargo build cache | v2.9.2 | LGPL-3.0 | caution | M1 | **Pending owner approval** ([Q17](QUESTIONS.md#q17)). Runs only in CI and is never distributed with Ferman, so it creates no obligation for users. Never vendor or copy its code. Until approved, CI caches with actions/cache or not at all. |
| actions/cache | Cargo build cache while rust-cache waits for [Q17](QUESTIONS.md#q17) | version set in M1 | MIT | ok | M1 | Pinned by commit SHA like every action. Used only if Q17 does not approve rust-cache; CI may also run without a cache. |

### 3.14 Notable transitive dependencies

The full transitive graph comes from the lockfiles once they exist. These are listed because they carry a
licence or maintenance detail worth knowing.

| Name | Comes from | SPDX licence | Notes |
|---|---|---|---|
| allo-isolate 0.1.27 | flutter_rust_bridge | Apache-2.0 (licence file) | crates.io shows "non-standard" because `license-file` points at the Apache-2.0 text. Needs a `[[licenses.clarify]]` entry. |
| threadpool | flutter_rust_bridge | permissive | Last released in 2020. |
| brotli-decompressor | lopdf | BSD-3-Clause OR MIT | |
| encoding_rs | lopdf | (Apache-2.0 OR MIT) AND BSD-3-Clause | |
| slotmap | fontdb | Zlib | |
| nix 0.31 | atomic-write-file | MIT | |
| libloading | cryptoki | ISC | |
| flatbuffers | rten | Apache-2.0 | |
| hayro-write | krilla (`pdf` feature) | Apache-2.0 OR MIT | |
| ICU4X support crates (zerovec, yoke, tinystr, litemap, writeable, potential_utf) | icu_casemap, icu_collator | Unicode-3.0 | |
| ravif, rav1e, exr, paste | `image` default features | BSD-2-Clause and others | Avoided by turning `image` default features off. `paste` is unmaintained (RUSTSEC-2024-0436). |
| dbus 0.7.x (pub) | desktop_drop, on every platform (unconditional import; used only on Linux at run time) | MPL-2.0 | **Pending owner approval** ([Q17](QUESTIONS.md#q17)). If approved, its notice and source location ship with every build that includes desktop_drop, and it is the only MPL-2.0 package. |
| screen_retriever (pub) | window_manager | MIT | |
| vector_graphics (pub) | flutter_svg | BSD-3-Clause | |
| xml, petitparser (pub) | flutter_svg | MIT | |

**Proposed:** from M1, a script generates a full list of crates and pub packages with their licences from
`Cargo.lock` and `pubspec.lock` (through `cargo deny list` and very_good_cli's report) and appends it
to this file. CI fails if the generated list is out of date.

### 3.15 Not chosen yet

These needs are known. The dependency is picked, and its licence checked, in the milestone shown.

| Need | First milestone | Notes |
|---|---|---|
| Argument parser and JSON output for ferman-cli | M1 | Chosen in M1 step 1. |
| Settings storage | M1 | shared_preferences, or a Rust-side settings file shared with the CLI (M1 step 9). |
| UAX #14 line breaker | M3 | Chosen in M3 step 5. |
| File-change notification | M3 | **Proposed** for external-change detection; chosen in M3 step 8. |
| Adobe Glyph List, standard-14 AFM metrics, predefined CJK CMaps | M3 | Data files. Added only after their licences are checked and listed here. |
| Independent PDF structure checker for CI, for example qpdf (Apache-2.0) | M3 | **Proposed.** CI only; never shipped. |
| Similar-font candidates for missing glyphs | M3 | Decided with [Q08](QUESTIONS.md#q08). Any font chosen must allow embedding. |
| Printing package or platform channel | M4 | Basic system print is proposed for M4 ([Q10](QUESTIONS.md#q10)). |
| Handwriting fonts for typed signatures | M4 | Pending [Q08](QUESTIONS.md#q08); see [section 5.2](#52-fonts). |
| Regular-expression engine for find and replace patterns | P2 | Only if needed. |
| HTTP client with TLS for the network gateway | M5 | Uses the OS trust store. Only ferman-api's gateway may depend on it ([ARCHITECTURE.md §10.2](ARCHITECTURE.md#102-one-gateway)). Revocation lookups (OCSP, CRL) and local-network discovery are not enabled until the owner decides ([Q06](QUESTIONS.md#q06)). |
| Update framework for macOS and Windows | M5 | Endpoint and payload are [Q15](QUESTIONS.md#q15). Update packages are signature-checked. |
| Signing, notarization and installer tooling; Linux packaging | M5 | CI only. Linux formats are [Q12](QUESTIONS.md#q12). |
| Office format readers and writers | P3 | Chosen in the conversion ADR. |
| Software PKCS#11 token for tests, for example SoftHSM2 | P3 | CI only. |
| PDF/A and PDF/UA validator | P4 | CI only; licence reviewed before use. |
| Local inference runtime and model for the AI assistant | P4 | Runtime and weight licences reviewed with the owner before bundling or offering a download. |
| Mobile platform packages | P5 | Chosen per step. |

## 4. Rejected

rustybuzz is not listed here. It stays the brief's shaper until the owner answers
[Q04](QUESTIONS.md#q04), and joins this table only if ADR 0007 is approved
([section 3.3](#33-fonts-and-text)).

| Name | Ecosystem | Version seen | Licence | Why | How it is kept out |
|---|---|---|---|---|---|
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
| google_fonts | pub | not checked | not checked | Fetches fonts at run time, a network use the brief does not allow ([ADR 0015](adr/0015-privacy-and-network.md)). | **Proposed** pub deny list in CI from M1 step 2 ([section 8](#8-dart-licence-check)) |
| @ibm/plex npm packages | npm | 6.4.1 | OFL-1.1 | They hold only CSS, SCSS, WOFF and WOFF2 files (no TTF or OTF) and run an IBM telemetry script on install. Fonts come from IBM's GitHub releases instead. | review |

## 5. Bundled binaries and assets

These ship inside the app. Each one's licence text ships with it and appears in the licences screen
([G14](DESIGN_GAPS.md#g14)). Flutter's `LicenseRegistry` carries the texts to that screen.

### 5.1 PDFium

| Item | Value |
|---|---|
| Source | github.com/bblanchon/pdfium-binaries releases |
| Tag | `chromium/7881`, the PDFium API level pdfium-render 0.9.4 targets. The newest tag, `chromium/8100`, is not used until it passes the full corpus and pixel-diff suite with a matching pdfium-render. |
| Variant | The plain build: no V8 (JavaScript) and no XFA. The V8 variant adds V8 (BSD-3-Clause), fdlibm and more attack surface. |
| Archives | `pdfium-mac-arm64.tgz` and `pdfium-mac-x64.tgz` (combined into one universal file; upstream also publishes `pdfium-mac-univ.tgz`), `pdfium-win-x64.tgz`, `pdfium-win-arm64.tgz`, `pdfium-linux-x64.tgz`, `pdfium-linux-arm64.tgz`. All seven names were confirmed to exist for the tag on 2026-10-14. |
| SHA-256 per archive | Recorded here in the commit that adds `tools/pdfium`. CI fails on a mismatch. |
| Signing | Upstream builds are unsigned. The library is signed with the app's identity when the app is packaged (M5, [Q02](QUESTIONS.md#q02)). |
| Licence | PDFium: BSD-3-Clause AND Apache-2.0. In the bblanchon archive, PDFium's own licence (both texts) is `licenses/pdfium.txt`. The top-level `LICENSE` is the packager's MIT notice (Copyright Benoit Blanchon), and it also ships, because it is part of the redistributed package. |
| Ship with the app | The archive's `LICENSE` (packager MIT notice) and its `licenses/` directory (15 files for chromium/7881), unchanged. |

Licence files in the `licenses/` directory of the `chromium/7881` archives (linux-x64, mac-arm64 and
win-x64 downloaded and checked on 2026-10-14; the three hold the same 15 files). The list is checked
again for every archive when `tools/pdfium` is added.

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
and libunwind, and bigint. The 7881 archives carry no licence file for them, so they are not listed. They
are checked again when `tools/pdfium` lands, and added here if a build ships them.

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
- A download script with pinned SHA-256 values fetches the release zips in M1.
- The licence opens with `Copyright © 2017 IBM Corp. with Reserved Font Name "Plex"`, followed by the
  full SIL Open Font License 1.1.

| Family | Source (IBM release) | Files | Licence | Status | First milestone |
|---|---|---|---|---|---|
| IBM Plex Sans | `@ibm/plex-sans@1.1.0` (TTF revision 3.005) | 400, 500, 600. The complete files cover Latin, Turkish, Vietnamese, Cyrillic and Greek | OFL-1.1, Reserved Font Name "Plex" | Accepted (brief) | M1 |
| IBM Plex Serif | `@ibm/plex-serif@2.0.0` | The weights the tokens use (the wordmark at 600) | same | Accepted (brief) | M1 |
| IBM Plex Mono | `@ibm/plex-mono@2.5.0` | The weights the tokens use | same | Accepted (brief) | M1 |
| IBM Plex Sans Arabic | `@ibm/plex-sans-arabic@1.1.0` | 400, 500, 600; also covers Persian. No Latin, so Plex Sans follows it in the fallback chain | same | Accepted (brief) | M1 |
| IBM Plex Sans Hebrew | `@ibm/plex-sans-hebrew@1.1.0` (1.7 MB zip) | 400, 500, 600 | same | **Proposed** ([Q08](QUESTIONS.md#q08)); system fonts until approved | M1, if approved |
| IBM Plex Sans Devanagari | `@ibm/plex-sans-devanagari@1.1.0` (5.3 MB zip) | 400, 500, 600 | same | **Proposed** ([Q08](QUESTIONS.md#q08)); system fonts until approved | M1, if approved |
| Japanese, Korean, Simplified and Traditional Chinese | System fonts | Not bundled: IBM's CJK releases are 73 to 523 MB as zips | n/a | Accepted (brief) | M1 |
| Caveat, Dancing Script (typed signatures) | Not chosen | Unmodified upstream files | OFL-1.1 | Pending [Q08](QUESTIONS.md#q08) | M4 |
| Homemade Apple (typed signatures) | Not chosen | Unmodified upstream file | Apache-2.0 (not OFL) | Pending [Q08](QUESTIONS.md#q08) | M4 |

### 5.3 Icons

| Item | Value |
|---|---|
| What ships | The design's exact path data for **229 icons**, written by `tools/icons` as SVG assets in `app/assets/icons/`, drawn at a 1.5 px stroke ([ADR 0013](adr/0013-fonts-and-icons.md)). |
| Where they come from | 145 from `ICON_PATHS` in the design bundle (all match Lucide 0.460.0) and 84 from `ds-additions/fm-icons.js`: 77 match Lucide 0.460.0; bell, grid-2x2 and funnel match Lucide 1.56.0; paperclip matches 0.469.0 and 0.500.0; expand matches 0.500.0; file-signature matches 0.263.0 and 0.300.0; only ellipse matches no Lucide release ([G04](DESIGN_GAPS.md#g04), [G60](DESIGN_GAPS.md#g60)). |
| Provenance | `app/assets/icons/PROVENANCE.md`, generated: the Lucide release each glyph matches ("Lucide 0.460.0", "Lucide 1.56.0", "Lucide 0.500.0" or "Lucide 0.300.0"), or "Ferman design" for ellipse alone. That one glyph is project work and stays marked pending until the design re-export settles it ([Q11](QUESTIONS.md#q11)). |
| Licences | Lucide: ISC. Icons derived from Feather: MIT (Cole Bemis). |
| Ship with the app | Both Lucide licence files, checked on 2026-10-14: the 0.460.0 `LICENSE` (ISC; its copyright line names the Feather portions as MIT; byte-identical to the files of 0.263.0, 0.300.0, 0.469.0 and 0.500.0, so one copy covers the glyphs from those releases) and the 1.56.0 `LICENSE` (ISC, plus the list of Feather-derived icons and the full MIT text). |
| Not used | An icon font, lucide_icons_flutter, lucide_icons ([section 4](#4-rejected)). |

### 5.4 Other notices

| What | Licence | How it reaches the licences screen | First milestone |
|---|---|---|---|
| Ferman itself | Apache-2.0 | Shown as Apache-2.0. The design says GPL-3.0 in a1-2c and a11-5; the app does not copy that ([G13](DESIGN_GAPS.md#g13)). | M1 |
| Flutter engine and framework, Dart packages | BSD-3-Clause and the packages' own licences | Flutter's build collects package and engine licences into the app's notices; `LicenseRegistry` reads them. | M1 |
| `dbus` (through desktop_drop, on every platform) | MPL-2.0 | **Pending owner approval** ([Q17](QUESTIONS.md#q17)). If approved, its notice names the licence and where the source is available (pub.dev), in every build that includes desktop_drop. | M2 |
| Rust crates | per crate | Generated by cargo-about. | M4 |
| PDFium, fonts, icons | sections 5.1 to 5.3 | Added by hand and registered with `LicenseRegistry`. | M1 to M4 |

## 6. Toolchain

| Tool | Version (verified 2026-10-13) | Licence | Used for | Notes |
|---|---|---|---|---|
| Rust stable | 1.99.0 (built 2026-09-28) | MIT OR Apache-2.0 | Engine and CLI | Pinned in `rust-toolchain.toml` in M1, with rustfmt and clippy. CI reads the toolchain from that file. The M0 container had 1.97.0. |
| Minimum Rust version (`rust-version`) | 1.88 or higher | n/a | Workspace manifest | 1.88 is set by lopdf 0.45, image 0.25.10, ICU4X 2.3, sha2 0.11, proptest 1.12 and cargo-deny 0.20. It rises to 1.92 with krilla 0.8 (P4) and to 1.94 with rten 0.27 (only if ocrs moves to it, P3). The pinned 1.99 toolchain is what builds Ferman; `rust-version` records the floor. |
| Rust nightly | a pinned date, chosen in M2 | MIT OR Apache-2.0 | cargo-fuzz only | Never used for shipped builds. |
| Flutter | 3.47.7 stable (2026-10-08) | BSD-3-Clause | App | Beta 3.49.0-0.2.pre is not used. |
| Dart | 3.13.5 (bundled with Flutter 3.47.7) | BSD-3-Clause | App | very_good_analysis 11, riverpod_lint 3.1.9 and very_good_cli 1.5 need Dart 3.13 or later, so Flutter stays at 3.47 or later. |
| Node.js | 24.21.0 LTS "Krypton" (2026-09-07) | MIT | Tools only (`tools/design-refs`) | 26.11.1 is the Current line; 22.x is in maintenance. The M0 container had 22.22.0. Node is never part of the app. |
| Playwright | 1.64.0 | Apache-2.0 | Design-reference renderer | Needs Node 20 or later. |

## 7. Proposed deny.toml

Proposed — added in M1, together with the Cargo workspace. It follows
[ADR 0016](adr/0016-dependency-licence-policy.md). The keys were checked against the cargo-deny
documentation on 2026-10-14; the file is run with cargo-deny 0.20.2 before it is committed.

```toml
# deny.toml (proposed — added in M1). cargo-deny 0.20.
# Policy and reasons: docs/DEPENDENCIES.md, docs/adr/0016-dependency-licence-policy.md

[graph]
# Desktop first (brief §1). Web and mobile targets are added when phase 5 starts.
targets = [
  "aarch64-apple-darwin",
  "x86_64-apple-darwin",
  "x86_64-pc-windows-msvc",
  "aarch64-pc-windows-msvc",
  "x86_64-unknown-linux-gnu",
  "aarch64-unknown-linux-gnu",
  # Phase 5: "wasm32-unknown-unknown", "aarch64-apple-ios", "aarch64-apple-ios-sim",
  # "aarch64-linux-android", "armv7-linux-androideabi", "x86_64-linux-android",
]
all-features = true                # also check optional features, such as ferman-api's `frb`

[licenses]
confidence-threshold = 0.93
include-dev = false                # shipped graph; the dev-dependency CI job uses a copy with include-dev = true
unused-allowed-license = "allow"
allow = [
  "Apache-2.0",
  "Apache-2.0 WITH LLVM-exception",
  "MIT",
  "MIT-0",
  "BSD-2-Clause",
  "BSD-3-Clause",
  "ISC",
  "Zlib",
  "0BSD",
  "BSL-1.0",
  "CC0-1.0",
  "Unicode-3.0",                   # ICU4X, unicode-ident
  "Unicode-DFS-2016",              # older unicode-* crates
]
# Never add globally: AGPL-*, GPL-*, LGPL-*, MPL-2.0, EUPL-*, SSPL-1.0, BUSL-1.1, Elastic-2.0,
# CC-BY-NC-*, PolyForm-Noncommercial-*, Commons-Clause, OFL-1.1.
# A licence joins this list only through an ADR the owner approves.
exceptions = [
  # Reachable only from the separate fuzz/ workspace, which is checked with this file and never ships.
  # Pending owner approval (Q17).
  { crate = "libfuzzer-sys", allow = ["NCSA"] },
  # Per crate, after the owner's review and an entry in DEPENDENCIES.md, for example:
  # { crate = "option-ext", allow = ["MPL-2.0"] },   # only if dirs or dirs-sys appears
]

[[licenses.clarify]]
crate = "allo-isolate"             # from flutter_rust_bridge; crates.io shows "non-standard"
expression = "Apache-2.0"          # its licence file is the Apache-2.0 text
license-files = [{ path = "LICENSE", hash = 0x00000000 }]   # set to the hash cargo-deny reports in M1

[licenses.private]
ignore = false                     # Ferman's own crates are checked too; each declares license = "Apache-2.0"

[bans]
multiple-versions = "warn"         # expected later: skrifa and read-fonts (subsetter, krilla), rten (ocrs)
wildcards = "deny"
allow-wildcard-paths = true        # path dependencies between Ferman's unpublished workspace crates
deny = [
  { crate = "mupdf", reason = "AGPL-3.0; MuPDF is excluded by the brief" },
  { crate = "mupdf-sys", reason = "AGPL-3.0; MuPDF is excluded by the brief" },
  { crate = "pdfium", reason = "GPL-3.0 wrapper; use pdfium-render" },
  { crate = "jbig2dec", reason = "GPL-3.0 binding to Artifex jbig2dec (AGPL); PDFium decodes JBIG2" },
  { crate = "poppler-rs", reason = "links GPL poppler" },
  { crate = "poppler-sys-rs", reason = "links GPL poppler" },
  { crate = "magick_rust", reason = "ImageMagick renders PDF through Ghostscript (AGPL)" },
  { crate = "libheif-sys", reason = "links LGPL-3.0 libheif" },
  { crate = "ffmpeg-sys-next", reason = "FFmpeg is LGPL or GPL" },
  # Added only when the owner approves ADR 0007 (Q04):
  # { crate = "rustybuzz", wrappers = ["krilla"], reason = "archived upstream; use harfrust" },
  # Added with the network gateway in M5 (ADR 0015), for the HTTP client chosen then:
  # { crate = "<http client>", wrappers = ["ferman-api"], reason = "network only through the gateway" },
]

[advisories]
yanked = "deny"
unmaintained = "workspace"         # fail when a direct dependency is unmaintained
ignore = []                        # every ignore needs a reason here and a note in DEPENDENCIES.md

[sources]
unknown-registry = "deny"
unknown-git = "deny"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
```

Notes:

- CI runs `cargo deny check` (licences, bans, advisories, sources) on every pull request, once for the
  main workspace and once for `fuzz/`, plus the dev-dependency licence job
  ([ADR 0017](adr/0017-testing-and-ci.md)).
- With `unmaintained = "workspace"`, an unmaintained transitive crate (for example `paste` if `image`
  defaults slipped back in) does not fail CI. Such crates are caught by review and listed in
  [section 9](#9-known-risks).
- The resolved graph checked on 2026-10-13 needs only Apache-2.0, MIT, BSD-2-Clause, BSD-3-Clause, ISC,
  Zlib and Unicode-3.0. The rest of the allow-list is there so common OR expressions resolve.

## 8. Dart licence check

Proposed — added in M1. cargo-deny does not see pub packages, so CI runs very_good_cli with the same
allow-list. MPL-2.0 is not on it. The M1 graph has no MPL-2.0 package, so M1 runs the check without
`--skip-packages`. If the owner approves `dbus` (pending [Q17](QUESTIONS.md#q17),
[section 3.11](#311-flutter-and-dart-packages)), `--skip-packages=dbus` is added in the same commit as desktop_drop in M2, so any other MPL-2.0 package
still fails the check. The flags were checked against very_good_cli's documentation on 2026-10-14. The
default dependency type is `direct-main` only, so the types are set explicitly.

```sh
very_good packages check licenses \
  --dependency-type=direct-main,direct-dev,transitive \
  --allowed=Apache-2.0,MIT,MIT-0,BSD-2-Clause,BSD-3-Clause,ISC,Zlib,0BSD,BSL-1.0,CC0-1.0,Unicode-3.0,Unicode-DFS-2016
# From M2, only if the owner approves dbus: add --skip-packages=dbus
```

**Proposed** for M1 step 2 ([ROADMAP.md](ROADMAP.md)): a second check fails if `pubspec.lock` contains
an HTTP client, a font downloader such as google_fonts, or an analytics or crash-reporting SDK
([ADR 0015](adr/0015-privacy-and-network.md)).

## 9. Known risks

| Risk | Effect | What we do | When |
|---|---|---|---|
| **Fontations version split.** harfrust 0.14 and skrifa 0.48 use read-fonts 0.45. krilla 0.8.2 and subsetter 0.2.6 (with `variable-fonts`) use skrifa 0.42, read-fonts 0.39 and write-fonts 0.48. | Two copies in the binary; font handles cannot be passed between the APIs. | Pin exact versions. Upgrade skrifa, read-fonts, the shaper, subsetter and krilla together. Keep subsetter's `variable-fonts` off. Prefer a krilla release that has moved to harfrust. cargo-deny warns on duplicates. | M2 to P4 |
| **Shaper.** The brief names rustybuzz, which is archived upstream. | No fixes for shaping bugs, new Unicode versions or font-parsing security issues. | [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md) proposes harfrust ([Q04](QUESTIONS.md#q04)). Decide before M3. The `Shaper` trait keeps a switch to one module. | M3 |
| **cms 0.2 versus 0.3 release candidate.** 0.2.3 (2024) uses der 0.7, x509-cert 0.2, spki 0.7 and digest 0.10; the current crates are x509-cert 0.3, der 0.8 and sha2 0.11. | Two RustCrypto stacks in one build, or a release candidate in production. | Wait for cms 0.3.0, or pin the release candidate after review. | P3 |
| **rsa timing advisory** (RUSTSEC-2023-0071, no fix). | Private-key operations could leak through timing. | rsa for verification only; sign through PKCS#11 (cryptoki), the OS keystore or aws-lc-rs. | P3 |
| **`image` default features.** They pull ravif, rav1e, exr and the unmaintained `paste`. | Heavier builds; the advisory gate trips. | `default-features = false` with `png`, `jpeg`, `tiff`, `webp`, `gif` and `rayon`. | M4 |
| **ocrs is Latin-only and its model licence is unclear.** Weights trained on HierText (CC-BY-SA-4.0) with no published licence. | Turkish, Arabic and CJK recognition poor or missing; models we may not be able to ship. | Owner decision in [Q16](QUESTIONS.md#q16) before phase 3; licence review before any model ships; Tesseract with Leptonica is the fallback. | P3 |
| **PDFium tag pinning and SHA verification.** Builds are weekly, third-party and unsigned; the newest tag (8100) is ahead of what pdfium-render 0.9.4 targets (7881). | Supply-chain risk; API mismatches. | Pin `chromium/7881`; verify a SHA-256 per archive in CI; non-V8, non-XFA build; sign with the app in M5; upgrade PDFium and pdfium-render together, in one commit, after the corpus and pixel-diff suite passes. | M1 |
| **PDFium is not thread-safe and runs in-process.** pdfium-render's `thread_safe` feature is one global lock. | One render thread limits throughput; a PDFium crash ends the app. | One render thread with the lock as a second guard; caches and prefetch; helper processes if M2 measurements demand it ([ADR 0009](adr/0009-threading-and-jobs.md)). | M2 |
| **lopdf churn.** Breaking releases almost monthly. | Upgrades break the build. | Pin `=0.45`; wrap it inside ferman-core; upgrade on purpose with the corpus as the safety net. | M2 |
| **Slow-moving crates and packages.** unicode-bidi (last release 2024-12), ttf-parser (2024-11), threadpool through flutter_rust_bridge (2020), freezed_annotation (2025-07), file_selector (2025-11), atomicwrites (2024). | Unfixed bugs; future unmaintained advisories. | Prefer maintained alternatives where they exist (ICU4X bidi data, read-fonts instead of ttf-parser); avoid atomicwrites and freezed; watch advisories. | M1 onwards |
| **flutter_rust_bridge version lockstep.** The crate, the Dart package and the codegen must match exactly; 2.14 is in beta. | A mismatch fails at run time or generates wrong bindings. | Pin all three to 2.13.0; a CI check compares them; generated code is committed and regenerated in CI; all three move in one commit. | M1 |
| **allo-isolate licence metadata.** Declared through a licence file, shown as "non-standard". | cargo-deny cannot classify it. | `[[licenses.clarify]]` with the file hash; a changed file fails the check, so every FRB upgrade re-checks it. | M1 |
| **desktop_drop pulls MPL-2.0 `dbus` on every platform** (unconditional import; used only on Linux at run time). | A notice obligation in every desktop build; a licence outside the allow-list. | Pending owner approval ([Q17](QUESTIONS.md#q17)): ask before desktop_drop lands ([brief §9](BRIEF.md)). If approved, ship its notice with the source location in every build that includes desktop_drop, and skip it by name in the pub check so no other MPL-2.0 package passes. If not, use another package or a platform channel. | M2 |
| **Swatinem/rust-cache is LGPL-3.0.** | None for users: it runs only in CI and is never distributed. | Pending [Q17](QUESTIONS.md#q17); until then actions/cache or no cache. If approved: pin by SHA; never vendor or copy its code. | M1 |
| **Plex Reserved Font Name.** | Shipping a modified or subset Plex file under the "Plex" name would breach the licence. | Ship IBM's unmodified TTFs only ([section 5.2](#52-fonts)). | M1 |
| **Minimum Rust version rises.** 1.88 for the core set, 1.92 with krilla, 1.94 with rten 0.27. | Builds fail on older toolchains. | The toolchain is pinned (1.99); `rust-version` is raised in the same commit as the crate that needs it. | M1 onwards |
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
  re-run on the first real `Cargo.lock` in M1.

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
