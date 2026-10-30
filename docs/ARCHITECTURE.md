# Ferman architecture

Status: Milestone 1 (foundations) is complete (approved by the owner on 2026-10-16); Milestone 2 (open and view) is planned and starts on the owner's go-ahead. This document describes the target design; [PROGRESS.md](PROGRESS.md) records what has been built so far.

This document covers brief §8 item 3: crates, API boundary, threading, data flow, file safety, error handling, testing strategy and performance budgets. It turns brief §3 to §6 into an engineering design.

- The decisions in the [brief](BRIEF.md) are fixed. They change only through an ADR the owner approves.
- Anything marked **Proposed** is a new decision. It waits for the owner's approval through its ADR (see the [ADR index](adr/README.md)). Decisions taken from the [M2 plan](PROGRESS.md#m2-plan) are marked **Proposed** and wait with the plan.
- If this document and the brief disagree, the brief wins and this document has a bug.

Related: [roadmap](ROADMAP.md) · [design inventory](DESIGN_INVENTORY.md) · [component spec](COMPONENTS.md) · [design gaps](DESIGN_GAPS.md) · [dependencies](DEPENDENCIES.md) · [questions](QUESTIONS.md) · [backlog](BACKLOG.md)

## Contents

1. [Overview](#1-overview)
2. [Crates and repository layout](#2-crates-and-repository-layout)
3. [API boundary](#3-api-boundary)
4. [Threading and concurrency](#4-threading-and-concurrency)
5. [Data flow](#5-data-flow)
6. [Text editing pipeline](#6-text-editing-pipeline)
7. [File safety](#7-file-safety)
8. [Error handling](#8-error-handling)
9. [Security](#9-security)
10. [Privacy and network gateway](#10-privacy-and-network-gateway)
11. [Localization, RTL and fonts in the UI](#11-localization-rtl-and-fonts-in-the-ui)
12. [Platform integration](#12-platform-integration)
13. [Testing strategy](#13-testing-strategy)
14. [Performance budgets](#14-performance-budgets)
15. [Risks and open questions](#15-risks-and-open-questions)

## 1. Overview

Ferman is a Rust engine with one Flutter UI on top, connected by flutter_rust_bridge v2 ([ADR 0002](adr/0002-rust-engine-flutter-ui-frb.md)). The engine owns every byte of every PDF. The UI owns layout, input, the pixels on screen and every word the user reads.

```text
+----------------------------------------------------------------------+
| Flutter app (app/)                                                   |
|                                                                      |
|   UI isolate: Ferman components, features/*, Riverpod, go_router     |
|   draws tiles and overlays, never blocks, never sees PDF objects     |
|                                                                      |
|   app/lib/engine/   the only Dart code that imports app/lib/bridge/  |
+------------------------------+-------------------^-------------------+
                               | Future calls      | Stream<TileEvent> (pixels, zero-copy)
                               | (all async)       | Stream<JobEvent>, results, ApiError
+------------------------------v-------------------+-------------------+
| flutter_rust_bridge 2.13.0: generated Dart and Rust glue             |
+------------------------------+-------------------^-------------------+
                               |                   |
+------------------------------v-------------------+-------------------+
| ferman-api                                                           |
|   frb      FRB-annotated wrappers, DTO mirrors, stream sinks         |
|   facade   pure Rust: Engine, handles, actors, transactions, jobs <--+---- ferman-cli
+------------------------------+---------------------------------------+     (same facade,
                               |                                             no FRB)
                               v
+----------------------------------------------------------------------+
| engine crates (exact edges in section 2.2)                           |
|   ferman-ops    organize, annotations, forms, compress, ...          |
|   ferman-text   PDF fonts, text model, hit testing, editing, reflow  |
|   ferman-fonts  font programs, encodings, shaping, subsetting        |
|   ferman-render tiles, thumbnails, caches ---------------------------+---> PDFium (prebuilt
|   ferman-core   lopdf model (source of truth), interpreter,          |     chromium/7881,
|                 revisions, incremental save, safe write, recovery    |     one thread,
+----------------------------------------------------------------------+     read-only)
```

Principles, each backed by an ADR:

1. **One source of truth.** lopdf holds the document model. PDFium only turns bytes into pixels and never writes ([ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md)).
2. **One boundary.** The UI calls ferman-api only. It sees handles and plain data, never PDF objects ([ADR 0003](adr/0003-crate-layout-and-api-boundary.md)).
3. **The UI isolate never waits.** Every engine call is async. Parsing, rendering, saving and jobs run on Rust threads ([ADR 0009](adr/0009-threading-and-jobs.md)).
4. **Edits are surgical.** Only the edited block's operators change. Pixels outside the edited region stay identical ([ADR 0005](adr/0005-block-scoped-text-editing.md)).
5. **Never corrupt a file.** Temp file, fsync, atomic rename, incremental update by default ([ADR 0008](adr/0008-file-safety-and-saving.md)).
6. **PDFs are hostile input.** Limits everywhere, a fuzz target for every parser, document JavaScript never runs (section 9).
7. **Local only.** No telemetry. One network gateway serves the four uses the brief allows and the revocation lookups the owner added ([ADR 0015](adr/0015-privacy-and-network.md)).

## 2. Crates and repository layout

### 2.1 Repository map

```text
ferman/
├── design/               read-only design export (never edited, never shipped)
├── crates/
│   ├── ferman-core/      lopdf model, parse/write, interpreter, revisions, save, recovery
│   ├── ferman-fonts/     font programs, encodings and CMaps, shaping, subsetting, system fonts
│   ├── ferman-text/      PDF fonts, glyphs → words → lines → blocks, hit testing, editing, reflow
│   ├── ferman-render/    PDFium thread, tiles, thumbnails, caches
│   ├── ferman-ops/       organize, annotations, forms, compress, … (splits as it grows)
│   ├── ferman-api/       the only crate the UI calls: facade + FRB surface
│   └── ferman-cli/       `ferman` command line on the same facade
├── fuzz/                 cargo-fuzz workspace, one target per parser (since M2)
├── app/                  Flutter app: macos, windows, linux, web now; ios, android later
├── tools/
│   ├── tokens/           design tokens → app/lib/design/tokens.g.dart (ADR 0012)
│   ├── icons/            ICON_PATHS + fm-icons.js → SVG assets, IconName enum, provenance table
│   ├── fonts/            fetches the pinned IBM Plex release zips, checks SHA-256 and coverage
│   ├── design-refs/      Playwright renders of every artboard → build/design-refs/
│   ├── pdfium/           fetches pinned PDFium binaries and checks SHA-256
│   ├── checks/           repository checks CI runs (pins, ARB parity, crate graph, design/ untouched, …)
│   └── corpus/           corpus generators and fetch scripts (M2)
├── tests/corpus/         test PDFs + README.md with provenance
├── docs/                 brief, architecture, ADRs, roadmap, progress, …
└── .github/workflows/    CI
```

`fuzz/` is not in the brief's tree. It is the standard cargo-fuzz location, kept as a separate workspace so `libfuzzer-sys` (NCSA) never enters the shipped dependency graph. The owner approved the NCSA exception on 2026-10-15 ([Q17](QUESTIONS.md#q17)); `fuzz/` is created with the first parser in M2.

Toolchain targets: Rust stable 1.99, pinned with `rust-toolchain.toml` (1.99.0); Flutter 3.47.7 with Dart 3.13.5; Node 24.22.0 LTS and playwright-core 1.56.1 for the tools ([DEPENDENCIES.md §6](DEPENDENCIES.md#6-toolchain)).

### 2.2 Dependency graph

```text
level 4   ferman-cli ──────► ferman-api (facade only, default-features = false)
level 3   ferman-api ──────► ferman-ops, ferman-render, ferman-text, ferman-fonts, ferman-core
                             (+ flutter_rust_bridge 2.13.0 behind the `frb` feature)
level 2   ferman-ops ──────► ferman-text, ferman-fonts, ferman-core
level 1   ferman-text ─────► ferman-fonts, ferman-core
          ferman-render ───► ferman-core                    (+ pdfium-render 0.9.4 → PDFium)
level 0   ferman-core ─────► no Ferman crate                (+ lopdf =0.45)
          ferman-fonts ────► no Ferman crate                (+ skrifa, read-fonts, shaper, subsetter, fontdb)
```

Rules:

- ferman-core and ferman-fonts depend on no other Ferman crate. ferman-fonts is PDF-agnostic: it works on font program bytes, encoding tables and CMap bytes, so it can be tested and fuzzed alone.
- ferman-render is the only crate that links PDFium. Only ferman-api depends on ferman-render.
- Operations that need pixels (OCR, the redaction pixel check in a8-2c, visual compare in a9-2) get them from ferman-api, which composes ferman-render and ferman-ops. PDFium stays behind one door.
- ferman-cli uses ferman-api with the `frb` feature off, so the CLI has no FRB code.
- Dev-dependencies (criterion, proptest, insta) never appear in the shipped graph.
- **Approved by the owner on 2026-10-16** (Proposed until then): a CI script reads `cargo metadata` and fails on any edge not in this table. It runs as the `crate_graph` check in `tools/checks` ([ADR 0003](adr/0003-crate-layout-and-api-boundary.md)).

### 2.3 Crates in detail

#### ferman-core

- **Responsibility:** load bytes (with password), lopdf object model, xref repair, decryption and re-encryption on write, structure scan (page tree and inheritance, page labels, outlines, attachments, optional content, AcroForm and XFA detection, signatures and DocMDP permissions), content-stream lexer and interpreter (section 6.1) with a byte span for every operator, revision store (section 4.3), incremental writer, full rewrite, safe write (section 7), recovery journal (section 7.6), resource limits (section 9), and the stream filters it decodes itself (ASCIIHex, ASCII85, LZW, Flate and RunLength, with the PNG and TIFF predictors; the image codecs stay with PDFium).
- **Public surface:** `Document`, `Snapshot`, `RevisionId`, `ObjectStore`, `Interpreter` with `InterpreterSink` and the `TextAdvance` trait (implemented by ferman-text, so core needs no font code), `Operator { name, operands, span }`, `ChangeSet`, `SaveMode`, `safe_write`, `RecoveryJournal`, `Limits` and `LimitKind` (`limits`, since M2), `Filter`, `DecodeParams`, `decode` and `decode_chain` (`filters`, since M2), `CoreError`. Since M2's open path: `Source` (the bytes and their SHA-256), `open` with `OpenOptions` into a `Document` (version, `RepairReport`, `EncryptionInfo`, `Access`, `Permissions`, `unlock_owner`), `Password`, `Diagnosis` and `LikelyCause` for a file that cannot be opened, `sniff::FileKind` for one that is not a PDF, and `structure::Structure` (pages with labels, boxes and displayed sizes; outline; attachments; layers; forms and XFA; signatures and certification; scripts; fonts; direction; language; information) with the two-parser `Agreement`. Since commit 10b of M2: `Document::layer_appendix`, the first render-only appendix (§5.3). Since commit 11: `interpret` with `Document::page_text`, `TextSink`, `TextShow`, `ShowItem`, `FontResource` and `Matrix` (§6.1); the planned `TextAdvance` is the sink's `show`, which returns the displacement.
- **Key dependencies:** lopdf pinned to `=0.45` with default features off (breaking releases come almost monthly; only ferman-core may depend on it, a single door of the `crate_graph` check), sha2, thiserror, tracing, flate2 (on the pure-Rust miniz_oxide) and weezl for the filters, and for the security handler md-5, aes, rc4 (the versions lopdf uses, with their `zeroize` features), stringprep's tables with unicode-normalization for SASLprep, and zeroize. atomic-write-file is under evaluation against section 7.

#### ferman-fonts

- **Responsibility:** font programs (TrueType and CFF/CFF2 through skrifa and read-fonts; a minimal Type1 parser for the built-in encoding and glyph names, because skrifa does not read Type1), encoding tables (Standard, WinAnsi, MacRoman, MacExpert, PDFDoc, Symbol, ZapfDingbats), glyph names to Unicode (Adobe Glyph List), CMap and ToUnicode parsing with `usecmap` chains, coverage, metric comparison for similar-font ranking, shaping, subsetting, system font discovery, the registry of fonts bundled with the app, and glyph and shaping caches.
- **Shaping:** harfrust ([ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md), accepted by the owner on 2026-10-15, [Q04](QUESTIONS.md#q04)) instead of the archived rustybuzz the brief names. cargo-deny bans rustybuzz except as krilla's wrapper. The shaper sits behind one internal trait, so nothing outside ferman-fonts names the shaping crate.
- **Public surface:** `FontProgram`, `GlyphId`, `Coverage`, `Shaper`, `ShapedRun`, `Subset`, `SystemFonts`, `FontMatch`, `SimilarFonts`, `Encoding`, `CMap`, `ToUnicode`, `FontError`.
- **Key dependencies:** skrifa, read-fonts, harfrust, subsetter, fontdb, unicode-normalization. Predefined CJK CMap data and the Adobe Glyph List are added only after their licences are checked and listed in [DEPENDENCIES.md](DEPENDENCIES.md).

#### ferman-text

- **Responsibility:** resolve PDF font resources into a `PdfFont` (dictionary, program, encoding, ToUnicode, widths, vertical metrics), implement `TextAdvance` for the interpreter, build glyph runs, map glyphs to Unicode, rebuild words, lines, blocks, columns, alignment and reading order, assign block ids, hit testing, decide editability, run edit operations, line breaking and reflow, bidi, re-encoding, generate a block's replacement operators, resolve missing glyphs and overflow, extract search text, keep the edit journal behind the review list (a3-12).
- **Public surface:** `PageText`, `TextBlock`, `Line`, `GlyphRun`, `BlockId`, `Editability`, `EditOp`, `BlockEditor`, `MissingGlyphPlan`, `OverflowPlan`, `SearchIndex`, `TextError`. Since commit 11 of M2: `extract::page_text`, a page's text in reading order (lines by baseline in content order, right-to-left lines read back with UAX #9, marks kept with their letters, vertical columns); it implements the interpreter's `TextSink`.
- **Key dependencies:** ferman-core, ferman-fonts, unicode-bidi, unicode-segmentation, unicode-normalization, icu_casemap (search folding), and a UAX #14 line breaker chosen and licence-checked in M3.

#### ferman-render

- **Responsibility:** load the PDFium library at run time from a path in `EngineConfig`, own the render thread, render tiles (clip rectangle plus matrix) and thumbnails, answer page-size queries, reload a document when a new revision changes pixels, run the prioritised tile queue, and keep the tile and thumbnail caches. Render flags are fixed and documented, because the acceptance tests depend on deterministic output.
- **Public surface:** M1: `RenderThread`, `RenderConfig`, `PdfiumStatus`, `PDFIUM_TAG`, `THREAD_NAME`, `RenderError`. Since M2 the `RenderThread` handle also opens and closes documents (`open_document` returns a `DocumentId` and every `PageSize`) and views (`open_view` with a `ViewSink`, `request` with a generation and a list of `Wanted`, `close_view`), and the tile types are `ZoomBucket`, `TileRequest` (a `TilePosition` on the grid of `TILE_SIZE`), `ThumbnailRequest`, `Item`, `Priority`, `Wanted`, `Rendered`, `Failed` with `FailReason`, and `ViewEvent`. Since commit 10b of M2, `reload` loads a document again with a render-only appendix after its bytes and gives every page a new render key (layers); reloading a revised document follows in M3.
- **Key dependencies:** ferman-core, pdfium-render `=0.9.4` (default features off; `pdfium_7881` and `thread_safe`, its global lock kept as a partial second guard, section 4.4; **Proposed** with the M2 plan: `image_025` stays off, because PDFium renders each tile straight into ferman-render's own buffer through `PdfBitmap::from_bytes`, which needs no feature), futures-channel (oneshot replies from the render thread), tracing, crossbeam-channel (the message channel) and lru (the caches), both since M2. PDFium is the prebuilt bblanchon/pdfium-binaries tag `chromium/7881`, the non-V8, non-XFA build.

#### ferman-ops

- **Responsibility:** M4 and later. Organize pages (insert, delete, rotate, move, extract, replace), combine and split, annotations, form filling with appearance streams, simple (non-cryptographic) signatures, compress, flatten, version-history snapshots. Phase 2 adds watermark, header and footer, Bates numbering, redaction with verification and removal of hidden information.
- **Public surface:** one module per operation family. Each is a function from `(Snapshot, params)` to a `ChangeSet` that the document actor commits. Long operations run as jobs.
- **Splitting:** as the brief says, it splits into more crates as it grows, for example signing (P3: cms, x509-cert, cryptoki), OCR (P3), conversion (P3) and PDF/A (P4: krilla).
- **Key dependencies:** ferman-core, ferman-text, ferman-fonts, `image` with default features off.

#### ferman-api

- **facade** (pure Rust, always built): `Engine`, `EngineConfig`, all handles and DTOs, `ApiError`, the document actors, the job manager and, from M5, the network gateway (section 10). ferman-cli and the integration tests call this module.
- **frb** (feature `frb`, on in the app build): thin wrappers that expose facade functions to Dart, stream sinks for tiles and jobs, mirrors of DTOs. Nothing else lives here. FRB codegen scans only this module (the facade module carries `frb(ignore)`, section 3.1), so the generated surface stays small. The Rust glue that FRB generates sits beside it, behind the same feature. It is never edited by hand, and it is the only place in Ferman's own crates where unsafe code is allowed (section 8.1).
- **Key dependencies:** every Ferman crate, flutter_rust_bridge `=2.13.0` (optional), thiserror, tracing, serde (derive). The FRB Rust crate, the Dart package and the codegen tool must have exactly the same version. A CI check compares the three.

#### ferman-cli

- **Responsibility:** the `ferman` binary for tests and power users: `info`, `pages`, `render`, `text`, `edit` (applies an edit script), `save`, `verify-edit` (runs the pixel-diff acceptance check on one case), and later `compress`, `combine` and others.
- **Output:** human-readable by default, `--json` for scripts. JSON output carries the API version.
- **Key dependencies:** ferman-api (facade only), clap 4.6 (derive), chosen in M1 step 1, and serde_json for `--json`. Output is written with `writeln!` and checked, because `println!` panics on a closed pipe.

### 2.4 Tools, corpus and fuzzing

- **tools/tokens** reads `tokens/*.css` and `ds-additions/fm-additions.css` (the additions are not merged into the DS files, [G05](DESIGN_GAPS.md#g05)) and generates `app/lib/design/tokens.g.dart`: plain `const` value classes named `Ferman*Tokens`, with a `lerp` for those that have variants. `app/lib/design/theme.dart` and `app/lib/design/theme/` wrap the sets that vary in one `ThemeExtension`, `FermanTheme`, which widgets read through `context.ferman`. The variants cover light, dark, touch density, page dim, CJK type overrides and reduced motion. The implementation language, the class names and the mapping rules are in [ADR 0012](adr/0012-design-token-pipeline.md); `dart run tokens --check` fails if the committed file is stale.
- **tools/icons** writes the design's exact path data for all 229 icons (ICON_PATHS plus fm-icons.js) as SVG assets in `app/assets/icons/` (viewBox 24, 1.5 px stroke, the design's markup byte for byte), the generated `IconName` enum with the 8 directional icons marked, and a provenance table that names, for each glyph, the Lucide release its geometry matches (0.460.0 for 222 glyphs; 1.56.0, 0.500.0 or 0.300.0 for six more), or "Ferman design" for ellipse alone ([G04](DESIGN_GAPS.md#g04), [G60](DESIGN_GAPS.md#g60), [ADR 0013](adr/0013-fonts-and-icons.md)). The app paints icons from generated path data with a `CustomPainter` (path_parsing); the SVG files are the exported, provenance-tracked set and are not loaded at run time. It also renders the reference part of [COMPONENTS.md](COMPONENTS.md) from `app/test/design/component_spec.json`.
- **tools/l10n** reads the abstract members of the gen-l10n class `AppLocalizations` (`app/lib/l10n/gen/app_localizations.dart`) after `flutter gen-l10n` and generates `app/lib/l10n/isolated_fallback.g.dart`: a subclass of the English localizations that wraps every string in a left-to-right isolate, and its delegate, for right-to-left languages without a translation (section 11.4, [G93](DESIGN_GAPS.md#g93)); `dart run l10n --check` fails if the committed file is stale. Its second command, `dart run l10n:review_table`, renders the table of [TRANSLATION_REVIEW.md](TRANSLATION_REVIEW.md) from the ARB files (every English message in file order, with its Turkish and Arabic translations and the note for translators) for the native-speaker review; `--check` fails if the table is stale.
- **tools/fonts** downloads the pinned IBM Plex release zips, checks every SHA-256 in `fonts.lock` and installs the unmodified TTFs and licence files into `app/assets/fonts/`; `--verify-committed` is the offline CI check, and `coverage.py` reads each font's cmap for the scripts each family must cover (Plex Sans: Basic Latin and the Latin-1 letters as well as Turkish, Vietnamese, Cyrillic and Greek); CI runs both in the repository checks.
- **tools/design-refs** uses Node 24.22.0 LTS and playwright-core 1.56.1 to render every artboard to `build/design-refs/<id>.png` (gitignored). playwright-core is pinned to the Chromium revision (1194) preinstalled in the development container, where the Playwright CDN is blocked, and CI uses the same revision. CI does not run the Playwright installer, which also downloads Playwright's ffmpeg build (LGPL-2.1): it downloads the revision 1194 headless shell directly (`tools/design-refs/fetch-chromium.sh`, which checks the SHA-256 pinned from the first CI download on 2026-10-15) and passes its path with `--chromium`. The renderer runs offline: the runtime scripts and fonts the export loads from unpkg.com and Google Fonts come from npm packages pinned in its lockfile and are served locally, and every other network request fails the run, so the export's runtime Google Fonts `@import` never loads ([G07](DESIGN_GAPS.md#g07)). Capture rule (export `519d42a`, 253 boards): 242 of the 244 product boards are captured from the first `.fm-root` inside the element with the id `<id>`, or from that element itself when it carries `.fm-root` (the seven sidebar boards `a2-3p` to `a2-3x`); `a2-3m` is captured as the box around all six of its sidebar frames, and the region-format table `a12-0`, which has no `.fm-root`, as the whole element with the id (`CAPTURE_OVERRIDES` in `boards.mjs`); the nine fix boards `f1` to `f6a` are captured as the whole element with the id: the `section` for `f1` to `f6`, and the nested `div` for `f4a`, `f4b` and `f6a`. The 29 boards with the design's board-language switch are also rendered in Turkish and Arabic, as `<id>.tr.png` and `<id>.ar.png` (58 variants). Every board and variant is rendered on its own freshly loaded page. The count check and the exit status are `countCheck` and `runStatus` in `outcome.mjs`, tested without a browser: a requested board without a PNG, or a blocked request, fails the run.
- **tools/app-icons** (M2) draws the app icons from the owner's logo export in `design/assets/logo/` ([G112](DESIGN_GAPS.md#g112)). It writes the macOS asset catalog's seven PNGs, the Windows `app_icon.ico` (ten PNG entries from 16 to 256 px), the Linux window icon (`app/linux/runner/resources/app_icon.png`, installed as `data/app_icon.png` and set by the runner) and the web favicon and PWA icons. It is a Node script with no npm dependencies; an installed Chrome or Chromium renders each icon headless at its exact size. `tools/app-icons/manifest.json` records the logo files' and icons' SHA-256, and `--check` compares them without a browser.
- **tools/pdfium** downloads `chromium/7881` for each platform, checks the pinned SHA-256 of each archive and of the library inside it (`pdfium.lock`), and unpacks the library, its `licenses/` folder (PDFium's own licence is `licenses/pdfium.txt`) and the packager's MIT `LICENSE`. On macOS it uses upstream's universal archive, whose two slices it checks against the pinned thin libraries, so no `lipo` step is needed. In CI the repository-checks job downloads all seven archives first (cached on `pdfium.lock`) and then runs `--verify --check-licenses` over them, because `--verify` checks only archives already in the cache; each Rust job fetches its own platform's library for the PDFium tests.
- **tools/checks** is a Dart command (`dart run bin/check_all.dart`) with the 18 repository checks CI runs: action pins, ARB parity, untracked build output, the crate graph, `design/` unchanged, the DCO sign-off of every commit after the base by its author (`dco_signoff`, merge commits aside; [Q14](QUESTIONS.md#q14)), FRB versions, the pub deny list, unsafe roots, version sync, `bridge_imports`, `component_spec` (every component of `app/test/design/component_spec.json` exists in `app/lib/design/` as a class or enum of the spec's kind, with every spec prop as a parameter of one of its constructor declarations, default values and calls never counting; every item type, such as MenuItem, SelectOption or SignatureValue, as a class or enum with a parameter for each field; every Dart enum value the props and fields name; and every value of a variant no enum prop carries, such as ThumbnailBadges' badge kinds), `feature_registry` (ROADMAP gate S9: every value of the `Feature` enum in `app/lib/app/feature_registry.dart` reads as `name('B018')` and names a row of [BACKLOG.md](BACKLOG.md)'s Open table that is not also under Done, a row under Done meaning the feature shipped and its value must go; every value is used as `Feature.<name>` by a hand-written file of `app/lib/` other than the gallery; `futureVersionReason` is used only by the registry, the gallery and the component files the check lists with a reason (`componentReasons`), and its string's getter only by `future_version.dart`; BACKLOG rows in fenced blocks do not count), and the five S6 Flutter checks over `app/lib/`: `s6_material_imports`, `s6_forbidden_api`, `s6_literals` (not over `app/lib/design/` or `app/lib/engine/`), `s6_directional` and `s6_casing`, with reviewed exceptions, each with a reason, in `s6_allowlist.dart` ([ADR 0011](adr/0011-flutter-state-navigation-components.md), [ADR 0012](adr/0012-design-token-pipeline.md)). `bridge_imports` scans `app/lib/`, `app/test/` and `app/integration_test/` and fails on any import or export of `package:ferman/bridge/...`, or of a relative URI that resolves into `app/lib/bridge/`, outside `app/lib/engine/`; conditional URIs count too. A second command, `dart run bin/scan_bundle.dart --root ../.. <build folder>...`, needs build output and so is not one of the 18: it fails (exit 1) on any file in a build that comes from the design export or its tooling, by name (`*.dc.html`, `_ds_bundle.js`, `support.js`, `fm-additions.css`, `fm-icons.js`, the React, ReactDOM and Babel scripts), by content (a React or Babel licence header under another name), any `.woff` or `.woff2` file or `@fontsource` path (the app ships only IBM's TTFs), or a SHA-256 equal to any file of 64 bytes or more under `design/`; a missing folder is a usage error (exit 64).
- **tools/corpus** is a Rust workspace of its own, excluded from the root one and never shipped ([ADR 0020](adr/0020-test-corpus.md)). It holds:
  - **The generators.** They are deterministic and write the design's sample documents (section 13.3). The first wave arrived in M2 step 1.
  - **A small PDF writer on lopdf.** Its fonts are composite subsets shaped by harfrust, simple TrueType WinAnsi subsets (subsetter, with the `cmap` added back) and fonts named but not embedded.
  - **Its own standard security handler.** It writes RC4 40 and 128, AES-128 and AES-256 with seeded initialisation vectors, because lopdf draws them at random.
  - **`check`, which CI runs on the three systems.** Every file in `tests/corpus/` has its README row with the right SHA-256; a generated PDF's expected text shares its row. Every generator makes the same bytes twice, and its committed files are current. A generator whose PDF is over 1 MB commits neither file: the PDF is checked against the hash of its row, and both files must be in `generated/.gitignore`.
  - **The PDFium oracle test.** It is `#[ignore]`d and runs in CI on the three systems. Every generated file opens or fails in PDFium as its generator says, with the right page count and its expected text (compared without whitespace), and an encrypted one does not open without its password.

  Fonts that Ferman does not bundle (EB Garamond) are fetched by `tools/corpus/fetch-fonts.sh` against the SHA-256 in `tools/corpus/fonts.lock`. A fetch script for larger real-world files follows when the first one is listed.
- **tests/corpus/** holds the PDFs and a README.md with provenance for every file: source, licence, SHA-256 and what it covers. Under [ADR 0020](adr/0020-test-corpus.md), files up to 1 MB are committed. Larger generated ones are regenerated by tools/corpus and checked against a SHA-256 pinned in the README. `.gitattributes` keeps `generated/` from line-ending conversion.
- **fuzz/** holds the cargo-fuzz targets (section 13.6): a workspace of its own on a pinned nightly (`fuzz/rust-toolchain.toml`), so libfuzzer-sys never enters the shipped graph.

### 2.5 Flutter app layout

```text
app/
├── lib/
│   ├── main.dart
│   ├── app/                 bootstrap, go_router routes, window frame and title bar, theme mode, root providers, engine start-up
│   ├── bridge/              FRB-generated Dart (never edited by hand)
│   ├── engine/              Dart services over the bridge: documents, tiles, text, edits, jobs; the only importer of bridge/
│   ├── design/
│   │   ├── tokens.g.dart    generated by tools/tokens (never edited by hand)
│   │   ├── theme.dart       ThemeExtension wiring: light, dark, touch, dim, reduced motion
│   │   ├── theme/           FermanTheme, context.ferman, FermanThemeScope, type roles per locale
│   │   ├── icons/           generated IconName enum and path data, the Icon widget and its painter (not SVG)
│   │   └── components/      Ferman component library, 1:1 with the design system (DS names)
│   ├── settings/            AppSettings, its settings-file store and settingsProvider (section 12)
│   ├── l10n/                ARB files (app_en.arb is the source) and gen/; app languages, locale providers, casing, region formats and names
│   └── features/
│       ├── shell/           title-bar content, mode bar, tool rows, sidebar, canvas, right panel, status bar, shortcut table
│       ├── start/           start screen, recents, drop zone
│       ├── onboarding/      first run: language picker, privacy and free-forever steps (a1-1, a1-2b, a1-2c)
│       ├── gallery/         the component gallery at /debug/gallery (a developer tool)
│       ├── viewer/          canvas, tile layer, zoom, layouts, thumbnails, outline, search
│       ├── edit/  comment/  fill_sign/  organize/  convert/  protect/  tools/
│       ├── settings/        the Settings surface and its panes (a11-1)
│       └── recovery/        crash recovery prompt (a1-12)
├── assets/
│   ├── fonts/               unmodified IBM Plex TTFs + LICENSE.txt per family
│   ├── icons/               229 SVGs (provenance-tracked, not loaded) + Lucide notices + provenance
│   └── licenses/            third-party notices (PDFium licenses/ and packager LICENSE, Rust crates)
├── test/                    widget and golden tests (alchemist)
├── integration_test/        one file (app_test.dart): the engine through the bridge (M1), desktop flows from M3
├── rust_builder/            FFI plugin rust_lib_ferman: builds ferman-api (frb feature) through vendored cargokit, two marked patches
└── macos/  windows/  linux/  web/
```

Rules for the app:

- Feature code reaches the engine only through providers in `app/lib/engine/`. Only `app/lib/engine/` imports `app/lib/bridge/`; `tools/checks` `bridge_imports` enforces it over `app/lib/`, `app/test/` and `app/integration_test/`.
- `app/rust_builder/` vendors cargokit from the flutter_rust_bridge 2.13.0 template with two changes marked "Ferman patch": it builds with the toolchain from `rust-toolchain.toml` instead of `stable`, and it looks for the library under cargo's name with `-` turned into `_` (`libferman_api`). Precompiled binaries are not configured, so it always builds the engine from source and never downloads one. It is its own package and is left out of `flutter analyze`. `crates/ferman-api/cargokit.yaml` turns on the `frb` feature for the debug, profile and release modes: cargokit reads each Flutter build mode separately, and a mode left out builds an engine without the bridge (profile builds did, until `ba9f6d2`).
- State uses Riverpod with code generation, navigation uses go_router, lints are very_good_analysis plus riverpod_lint ([ADR 0011](adr/0011-flutter-state-navigation-components.md)). Per-document state lives in family providers keyed by `DocumentId`. The view providers (`viewerProvider`, `layerVisibilityProvider`, `findProvider`) follow the active tab's document (`openDocumentProvider`) and keep what each document last showed in `documentMemoryProvider(id)` (`app/lib/features/viewer/viewer_state.dart`), so a tab comes back with its view, layers and search; an entry stays until closing documents ships (B029).
- The shell has eight mode tabs, as every artboard shows: View, Edit, Comment, Fill & Sign, Organize, Convert, Protect, Tools ([G09](DESIGN_GAPS.md#g09), [Q05](QUESTIONS.md#q05)). Each mode is a feature folder. Mode tabs and sidebar tabs are custom segmented controls over an `IndexedStack`, so each keeps its state; open documents are kept in an `IndexedStack` too. `TabBarView` is never used.
- Features not built yet stay visible as designed, disabled, with the tooltip "Available in a future version" ([G10](DESIGN_GAPS.md#g10)). One feature registry drives these states (ROADMAP gate S9): the `Feature` enum in `app/lib/app/feature_registry.dart` holds the features that are visible but do not work yet, each with its open [BACKLOG.md](BACKLOG.md) row, and every such control takes its reason from its value (`Feature.zoom.disabledReason(context)`, the localized "Available in a future version"). A feature ships by leaving the registry: deleting its value makes every control that still names it a compile error, so none stays disabled, or turns enabled without its handler, by mistake. A feature whose entry points ship at different times is split into a value and a row per part first. Keyboard commands of these features stay disabled by having no handler (`ShellCommandAction`). `tools/checks` `feature_registry` keeps the registry, BACKLOG and the controls in step.
- Components keep their design-system names, so Ferman's `Icon` hides the framework's: every file that uses it imports `package:flutter/widgets.dart` with `hide Icon`, and Material only with a prefix or `hide` ([ADR 0011](adr/0011-flutter-state-navigation-components.md)).

## 3. API boundary

What ferman-api exposes is fixed by the brief: open and close, page info, tile rendering, text blocks, edit transactions with engine-level undo and redo, and jobs. The boundary rules are in [ADR 0003](adr/0003-crate-layout-and-api-boundary.md). The DTO shapes below are **Proposed** sketches, not final code; they settle when M1 and M2 implement them.

### 3.1 Rules

- Every function is async or returns a stream, except `api_version()`. The Rust side of a call only validates input, sends a message to the right actor or queue, and awaits the reply. FRB worker threads are never held by long work.
- Data that crosses is plain: integers, floats, strings, enums, byte vectors, and structs of those.
- Geometry uses one **page space**: PDF points, origin at the top-left of the visible page after CropBox, `/Rotate` and `/UserUnit` are applied, y pointing down. The engine owns every conversion from PDF user space. The UI never sees a PDF matrix.
- No localized text crosses. The engine returns message keys with parameters. Dart formats numbers, dates and units from the region setting (section 11).
- The `frb` module mirrors the facade's data types as plain structs and enums without data. A facade enum that carries data (such as `PdfiumStatus`) crosses as a struct with a state enum and optional fields, so the generated Dart needs no freezed code generation; `MessageKey` crosses as a `String`. The facade module carries `#[cfg_attr(feature = "frb", flutter_rust_bridge::frb(ignore))]`, so codegen sees only `crate::frb`: FRB matches types by bare name across the crate, and without the attribute it takes the facade's `EngineInfo` or `ApiError` for the mirror of the same name and the glue does not compile. With the facade hidden, the mirrors may reuse its names. The facade module also carries `#[doc = "cbindgen:ignore"]`: the Dco codec's cbindgen pass reads the whole crate, and the facade's public constant `API_VERSION` made it declare the facade's `ApiVersion` as an opaque C struct, which ffigen turned into a Dart class that clashes with the mirror (the M1 trial's failure). ferman-api must not use `std::pin::pin!` or any other macro that expands to `super let`: FRB 2.13 codegen expands the whole crate and its syn parser rejects it; use `Box::pin`. Synchronous Rust callers (ferman-cli, tests) await facade futures with `facade::block_on`, never inside an FRB function.

### 3.2 Handles

- `DocumentId`, `ViewId`, `TxnId`, `JobId`, `RevisionId` and `BlockId` are `u64` newtypes created by the engine. They are never reused within a process.
- They are plain integers, not FRB opaque pointers. Closing a document has visible effects (the unsaved-changes prompt, a1-10b), so a Dart finalizer must never decide when it happens. `close()` is explicit.
- A stale or unknown handle returns `ApiError` with kind `NotFound`. It is never undefined behaviour.

### 3.3 Documents and pages

```rust
// Sketch, not final API.
pub enum OpenSource { Path(String), Bytes { name: String, data: Vec<u8> } } // Bytes: CLI, tests, web later
pub struct OpenOutcome { pub id: DocumentId, pub state: OpenState, pub page_count: u32, pub revision: RevisionId }
pub enum OpenState {
    Indexing,                             // pages viewable, model still loading (a1-7)
    Ready,                                // full model loaded, every feature on
    NeedsPassword,                        // a1-8; answered with unlock(id, password)
    Repaired { report: RepairReport },    // a1-9: view only until a repaired copy is saved
    ReadOnly { reason: ReadOnlyReason },  // damaged but renderable, XFA (a11-7c), restricted (G27), read-only file (G28)
}
pub struct PageInfo {
    pub index: u32,
    pub label: Option<String>,            // page labels such as i, ii, 1 (a2-1d)
    pub width_pt: f32, pub height_pt: f32,// in page space
    pub rotation: u16,
    pub render_key: u64,                  // changes only when this page's pixels can change
    pub flags: PageFlags,                 // has_text, edited, comments, form_fields, signature, warnings (f5 badges)
}
```

**Built in M2** (the API commit). `Engine::open(path, password)` returns an `OpenedDocument`: its `DocumentId`, why it opened read-only if it did (`ReadOnly::Repaired` with the repair report, `ParsersDisagree` with what differs, or `XfaOnly`), the page order of spreads (`Direction`) and every page's size as PDFium lays it out, with its label. There is no `NeedsPassword` state and no `unlock`: an encrypted file opened without its password fails with `PasswordRequired`, and the UI opens it again with the password, so no half-open document exists. A document does not change in M2, so the open result carries everything the viewer needs and there is no `page_info` yet; it arrives with the render keys of M3. `close(id)` ends the document and its views. Since the sidebar commit the open result also carries the outline, attachments, layers and signature fields the structure scan found, for the same reason; the bridge flattens the outline in reading order with each item's depth and passes dates as the file writes them. The calls the later screens need (an attachment's bytes, owner unlock, jobs) arrive with those screens. Since commit 12 `search(document, query, options, sink)` runs a search on a thread of its own: `Started` with its handle, each page's matches (one rectangle per line in displayed points, and the line as the snippet) with the progress every 25 pages, then `Done`; `cancel_search` stops it, and in the bridge cancelling the stream does (`search` there is a stream function). The engine keeps every open document's model and each page's text once read, so a second search reads no content stream again. Since commit 10b `show_layers(document, visible)` shows and hides layers in every view and returns every page's new render key; the open result's `layers_switchable` says whether it can (not for a repaired document, or one opened with its password, B111), and the engine keeps the parsed model of such a document until it closes. The bridge mirrors the calls as `open`, `close`, `open_view`, `request_view` and `close_view`: `open_view` returns a stream whose first event carries the view's handle (a flutter_rust_bridge stream function returns only its stream), and the stream ends when the view closes. Handles cross as `u64`, which Dart sees as `BigInt`; the app's `EngineService` (`app/lib/engine/`) holds them as `int` and turns every result into its own models. `ferman open <file> [--json]` prints the same through the CLI.

### 3.4 Tiles

```rust
// Sketch, not final API.
pub struct TileRequest {
    pub page: u32,
    pub zoom_bucket: i16,          // logical zoom = 2^(bucket / 4), quarter-octave steps
    pub device_pixel_ratio: f32,   // raster scale = logical zoom × device pixel ratio
    pub rect: TileRect,            // device pixels of that raster, on a 512 × 512 grid
    pub generation: u64,           // set by the view; newer sets replace older ones
}
pub struct TileEvent {
    pub page: u32, pub zoom_bucket: i16, pub device_pixel_ratio: f32, pub rect: TileRect,
    pub render_key: u64, pub generation: u64,
    pub width: u32, pub height: u32, pub stride: u32,
    pub pixels: Vec<u8>,           // 8-bit BGRA, opaque
}
```

- **Delivery.** `open_view(doc)` returns a `ViewId` and a `Stream<TileEvent>`. `request_tiles(view, generation, tiles)` replaces the view's wanted set. `close_view(view)` ends it. One stream per view avoids thousands of pending futures.
- **Several views per document.** The canvas, the thumbnail strip, split view (a2-8a, P2), compare (a9-2, P3) and version preview (a9-8, M4) each open their own view.
- **Pixel format.** PDFium renders BGRA. Flutter accepts it as `PixelFormat.bgra8888`, so no channel swizzle is needed. Tiles are opaque (the page background is painted first), so premultiplication never matters.
- **Zero copy.** A freshly rendered tile's `Vec<u8>` should move to Dart without a copy: FRB v2 can hand primitive vectors to Dart as external typed data on native platforms. The M1 benchmark checked this (target: a 1 MB tile crosses in under 0.2 ms). It depends on the codec: with codegen 2.13's `full_dep: false` the generated glue uses the SSE codec, which copies a `Vec<u8>` byte by byte (checked in M1 step 3); `full_dep: true` (the Dco codec from Rust to Dart) hands it over as external typed data, through allo-isolate's `zero-copy` feature, which flutter_rust_bridge turns on (checked on 2026-10-19). The measurement records the codec it used. First measurements of a 1 MiB round trip through `debug_bytes` (development container, Linux x64, Xvfb, SSE codec; not R1 or R2): a profile build of app and engine took 3,310 µs at the minimum and 5,915 µs at the median of 20 warm calls, and a debug build 52–63 ms (one cold call in each of four runs); a debug build on the macOS CI runner took 46 ms. All are far over the target ([PROGRESS.md](PROGRESS.md#measurements)). The SSE path copies: the generated Rust encoder writes the `Vec<u8>` one byte at a time into a serialisation buffer, and Dart copies it out with `getUint8List`. `full_dep: true` (the Dco codec) needs ffigen as a dev dependency and libclang for codegen; tried in a scratch copy in M1, its generated Dart did not compile (a name clash, fixed in M2 with `cbindgen:ignore` on the facade). **Since 2026-10-19 the bridge uses the Dco codec**: with a profile build on the owner's MacBook Pro (Apple M5 Pro, not R1 or R2), 1 MiB took 26 µs at the minimum and 73 µs at the median of 20 warm calls, against 665 µs and 1,053 µs with SSE on the same Mac, so it meets the target there; R1 and R2 are an owner check ([ADR 0009](adr/0009-threading-and-jobs.md#tile-transfer-m1-measurements-and-options-proposed)). The options (the Dco codec, an opaque pixel buffer read through a pointer view, a platform texture registry) are in [ADR 0009](adr/0009-threading-and-jobs.md#tile-transfer-m1-measurements-and-options-proposed). The owner chose the order on 2026-10-16 ([Q19](QUESTIONS.md#q19)): the Dco codec first, tried at the start of M2 step 3 before tiles are built and measured on R1 and R2 (section 14); if it misses the budget, the pointer view, built only once the owner approves its hand-written unsafe surface (section 8.1); the texture registry only if both fail. The texture-registry fallback, which ROADMAP §5 step 3 asks to be designed because the benchmark misses its budget, is designed there too: per-platform pixel-buffer textures in the `rust_lib_ferman` plugin, double-buffered tile slots that the render thread fills, a small C surface of ferman-api that needs the owner's approval, and a test path for the canvas goldens. With the texture registry, Dart builds no `ui.Image`; with the other options it builds one, which costs one upload that is part of the frame budget. A tile served from the Rust cache costs one memcpy.
- **Thumbnails** use the same stream, requested with `request_thumbnails(view, pages, size_px)` at lower priority.
- **Underneath, since M2.** ferman-render's render thread implements this model: a view's wanted set is one list of `Wanted` tiles and thumbnails, each with its priority class, and `request(view, generation, wanted)` replaces it; each bitmap comes back as a `Rendered` event on the view's sink, or a `Failed` one with its reason (no such page, out of range, a damaged page, out of memory). A tile is addressed by its column and row on the 512-pixel grid, at a `ZoomBucket` from 6.25% (bucket −16) to 12,800% (bucket 28) and a device pixel ratio from 0.5 to 4; tiles of the last column and row are cut to the page's raster; thumbnails fit the whole page into a square of 16 to 1,024 pixels. ferman-api mirrors these types in M2's API commit.

### 3.5 Text blocks

```rust
// Sketch, not final API.
pub struct TextBlock {
    pub id: BlockId,
    pub page: u32,
    pub bbox: Rect,                        // page space, points
    pub reading_order: u32,
    pub role: BlockRole,                   // paragraph, heading, list item, table cell, …
    pub direction: TextDirection,          // ltr, rtl, vertical_rl
    pub alignment: Alignment,              // left, right, center, justified
    pub lines: Vec<LineInfo>,              // baseline, bbox, text, caret stops per glyph cluster
    pub font: FontInfo,                    // family (subset tag removed), size_pt, weight, italic, colour, embedding
    pub language: Option<String>,          // from /Lang or marked content (a3-2)
    pub editable: bool,
    pub not_editable_reason: Option<NotEditableReason>, // drives the tooltip and panel callout (G39)
}
```

Blocks for a page are fetched lazily, when Edit mode shows the page or the pointer needs hover frames. The UI hit-tests block boxes itself for hover (a3-1a), which takes well under a millisecond, and asks the engine only for caret positions inside a block.

### 3.6 Edit transactions and undo

```rust
// Sketch, not final API.
async fn begin_edit(doc: DocumentId, target: EditTarget, confirm: Option<ConfirmToken>) -> Result<TxnStart, ApiError>;
async fn apply(txn: TxnId, op: EditOp) -> Result<EditPreview, ApiError>;
async fn commit(txn: TxnId) -> Result<RevisionInfo, ApiError>;
async fn rollback(txn: TxnId) -> Result<RevisionInfo, ApiError>;
async fn undo(doc: DocumentId) -> Result<RevisionInfo, ApiError>;
async fn redo(doc: DocumentId) -> Result<RevisionInfo, ApiError>;
```

- **begin_edit** opens the only transaction a document can have at a time. For a signed document without confirmation it returns `TxnStart::NeedsConfirmation { signatures }` and the UI shows the warning (section 6.9). It also refuses targets that are not editable, with the reason.
- **apply** takes an `EditOp`: insert, delete or replace text, set composing text (IME), set font, size, colour, alignment or spacing, resize the frame, resolve overflow, resolve a missing glyph. It returns an `EditPreview`: the updated block, changed page render keys, overflow state, missing-glyph state and warnings. The preview is rendered (section 5.4) but is not on the undo stack.
- **commit** creates a new revision and pushes it on the document's revision stack. A new commit drops the redo branch.
- **rollback** discards the transaction. The current revision does not change.
- **undo and redo** are engine-level: they move the document's current-revision pointer. Revision labels are message keys with parameters ("Edited text · Madde 4"), which feed the undo history panel (a3-10).
- **Coalescing (Proposed).** Typing in one block is one transaction. It commits on blur, Esc, mode switch, save, or after 1.5 s without input. So ⌘Z undoes a typing burst, as in a word processor. Inside an open transaction, ⌘Z steps back through its own applies.
- **Selective revert.** "Revert" on one row of the review list (a3-12) is a new forward transaction that restores that edit's objects. If a later edit builds on it, the UI names the later edit and reverts both or neither, as a3-12b draws it ([G42](DESIGN_GAPS.md#g42)).
- **Lifetime.** The revision stack lives until the document closes, as a3-10 says. Saved versions belong to Version history (a9-8, M4).

### 3.7 Jobs

```rust
// Sketch, not final API.
fn start_job(spec: JobSpec) -> (JobId, Stream<JobEvent>);
async fn cancel_job(job: JobId) -> Result<(), ApiError>;
async fn pause_job(job: JobId) -> Result<(), ApiError>;   // a11-6b, M4
async fn resume_job(job: JobId) -> Result<(), ApiError>;
pub struct JobEvent {
    pub job: JobId,
    pub progress: Option<f32>,             // 0.0..=1.0, None when unknown
    pub message_key: String,               // "Page 840 of 2,400" is a key plus parameters
    pub params: Vec<(String, String)>,
    pub result: Option<JobResult>,         // set on the last event: Done(output), Failed(ApiError) or Cancelled
}
```

- Jobs include indexing after open, search, OCR (P3), conversion (P3), compress (M4), batch (P4) and large full rewrites.
- Progress events are throttled to at most 10 per second.
- A job holds its own snapshot. It keeps running when its document tab or dialog closes, and its result stays available for an hour (a11-6b).

### 3.8 Errors

Every fallible call returns `ApiError { kind, message_key, details }`. `details` holds parameters for the message (file name, page), a `technical` string for "Copy technical details" (a1-9b), and a `retryable` flag. Section 8 lists the kinds and how they map to design states.

In M1, `details` is an `Option<String>` of structural facts (for a caught panic, the fixed text "panic at the API boundary"). The message parameters and the retry flag are added with the first call that needs them.

### 3.9 Versioning

- `api_version()` returns `{ major, minor }`. FRB generates the Dart and Rust glue from one source in one build, so a mismatch can only mean a stale native library. The app checks at start-up (FRB also checks its own content hash) and shows an error screen instead of crashing.
- **Engine start-up (M1).** `bootstrap()` starts the engine through `startEngine()` (`app/lib/engine/engine_start.dart`, a conditional export: `FrbEngineService` on desktop, a stub on the web). `FrbEngineService.start()` opens the bundled engine library by absolute path next to the running executable (`bundledEngineLibraryPath`, from `Platform.resolvedExecutable`): `lib/libferman_api.so` on Linux, `ferman_api.dll` beside `ferman.exe` on Windows, and `../Frameworks/rust_lib_ferman.framework/rust_lib_ferman` on macOS, where cargokit links the engine into the plugin's framework. flutter_rust_bridge's default loader is not used: it first tries a folder relative to the current directory (`../crates/ferman-api/target/release/`), so a packaged app could load a library from wherever it was started, and on macOS it looks for a `ferman_api.framework` that does not exist. Then the service checks the API version. A library that does not load, a version the app does not accept, or a platform without an engine gives an `EngineUnavailableException` (`libraryMissing`, `apiMismatch`, `unsupportedPlatform`); `bootstrap()` then installs `UnavailableEngineService`, so the app still opens and can say what is wrong. `app/test/engine/engine_library_path_test.dart` covers the paths.
- Before 1.0, breaking changes are allowed and recorded in the changelog with a version bump. From 1.0 on, the facade, the CLI's JSON output and the later plugin surface (P5) follow semantic versioning.
- Persistent formats (recovery journal, settings, caches) carry their own format version. An unknown cache version is discarded. An unknown journal version is refused with a message and kept on disk.

### 3.10 What the UI never sees

- lopdf objects, object numbers, dictionaries, raw content streams or operators.
- Font programs, glyph ids or encodings. The UI sees font names and coverage results.
- PDFium handles, file descriptors, byte offsets, absolute PDF matrices.
- Passwords after unlock. The engine wipes them from memory after deriving the key ("Ferman forgets it when you close the file", a1-8).
- Localized strings or formatted numbers from the engine.

One exception is planned. The developer object inspector in Settings › Advanced (a11-1k, M4, off by default) receives a read-only, display-only text projection that the engine builds. The UI cannot change PDF objects through it.

## 4. Threading and concurrency

The model in this section is [ADR 0009](adr/0009-threading-and-jobs.md), approved by the owner on 2026-10-16 with the other Proposed items of M1. The brief fixes only the outcome: rendering and heavy work never run on the UI thread. The cache caps marked Proposed below are still Proposed.

### 4.1 Threads

```text
  Dart                    Rust
  ----                    ----
  UI isolate ──FFI──► FRB worker pool (short calls only)
                              │  messages (crossbeam-channel)
           ┌──────────────────┼────────────────────────┬────────────────────────┐
           ▼                  ▼                        ▼                        ▼
  document actor 1    document actor N        render thread              job pool (rayon)
  (one per open       serialises mutations,   owns PDFium and every      indexing, search, text
   document)          publishes snapshots     PDFium document, runs      models, OCR, compress,
                                              the tile queue             full rewrites
```

| Thread | Count | Owns | Never does |
|---|---|---|---|
| UI isolate | 1 | widgets, input, tile images | block, call sync FFI (except `api_version`), run a task over 4 ms |
| FRB workers | FRB's pool | nothing | work longer than about 1 ms |
| Document actor | 1 per open document, parked when idle | working model, revision stack, open transaction | render, touch PDFium |
| Render thread | 1 per process | PDFium library, one PDFium document per open document, loaded-page cache | parse with lopdf, write files |
| Job pool | cores − 2, at least 1 | nothing shared; jobs hold snapshots | mutate a document directly (jobs submit a `ChangeSet` to the actor) |

**M1:** the render thread existed as a skeleton; the document actors and the job pool are built from M2. **Since M2** `Engine::open` reads and parses a file on a thread of its own, `ferman-open`, with a 64 MB stack, under the panic guard, and then hands the bytes to the render thread. A document does not change in M2, so it has no actor yet: **Proposed**, the actor arrives with the first change, M3's edit transactions; the job pool arrives with search. **Since M2** each search runs on a thread of its own (`ferman-search`, the same 64 MB stack) with a cancel flag; shortcut: no pool yet, which OCR, conversion and batch jobs need (P3, P4). Each reply comes back through a `futures_channel::oneshot` future, which async FRB functions await without blocking a worker. **Since M2** the render thread takes its messages over crossbeam-channel (M1 used `std::sync::mpsc`), loads documents and runs the tile queue.

### 4.2 One actor per document

- Each open document has an actor with a mailbox: begin, apply, commit, rollback, undo, redo, save, apply change set (from ops jobs), close.
- Messages run one at a time. That gives a total order of mutations with no locks on the model.
- Every commit publishes a new `Arc<Snapshot>` through an atomic pointer swap. Readers never block the writer and the writer never blocks readers.
- Saves and recovery writes run on the actor, so a save always sees a consistent revision. Large full rewrites run as a job on a snapshot while the actor keeps serving edits. The result is saved only if no newer revision exists, otherwise the user is asked.

### 4.3 Snapshots and revisions

A snapshot is an immutable view of one revision:

- the **base**: the bytes of the file as last opened or saved (`Arc<[u8]>`), plus its object index;
- an **overlay**: a persistent map from object id to the changed or new object, with structural sharing, so a revision costs memory only for what it changed;
- the page table with each page's render key;
- per-page text models and search text, built lazily (one `OnceLock` per page) and shared with later revisions when the page did not change.

Readers resolve an object through the overlay first, then the base. The render thread, jobs and text queries hold an `Arc<Snapshot>` as long as they need it. Memory is freed when the last reader drops it.

The **render key** of a page is a hash over the page object's version and the versions of every object reachable from its `/Contents`, `/Resources` (fonts, XObjects, patterns, shadings, graphics states) and annotation appearance streams. A re-embedded shared font changes the key of every page that uses it. Untouched pages keep their key, so their tiles stay valid.

### 4.4 PDFium confinement

- PDFium is not thread-safe. All PDFium calls run on the render thread, so PDFium's thread-affinity assumptions hold. pdfium-render's `thread_safe` feature adds one global lock, but only around part of its bindings: in 0.9.4, 192 of its 481 functions run without it (`FPDF_GetPageSizeByIndexF` among them), as M2's tests found when several render threads of one test process opened documents at once. So **one render thread of a process holds PDFium at a time** (since M2): a second render thread that asks while the first has it gets the status "PDFium is in use by another render thread of this process". The app has one engine and so one render thread; tests that start several take turns.
- The render thread holds one PDFium document per open document. When a revision changes pixels, it loads the revised bytes as a new PDFium document through a custom reader over the snapshot (base bytes plus the in-memory incremental section, no concatenated copy), swaps it in once loaded, and drops the old one after in-flight tiles finish.
- A small LRU of loaded pages (8 per document, Proposed) avoids reparsing the pages being scrolled. It is dropped on reload.
- **Layer visibility.** Approved with the M2 plan: PDFium has no public call to show or hide an optional-content group, so the Layers tab (a2-3c) reaches it through a render-only appendix: ferman-core builds an in-memory incremental section that changes the group's state, and the render thread reloads that document through the same reader. The appendix is never written to disk and never becomes a revision ([ADR 0009](adr/0009-threading-and-jobs.md)). **Built in M2** (W2, commit 10b): `Document::layer_appendix` writes the catalog again with the new `/ON` and `/OFF` (and without `/AS`, whose usage rules would override the choice), then a cross-reference stream that names every object, so no `/Prev` is needed after any kind of table; in an encrypted document the catalog's strings are written decrypted, which PDFium reads as noise that no pixel depends on. ferman-render's `reload` reads the bytes and the appendix as one file without a copy. Every page gets a new render key (shortcut: only the pages that use the layer need one; M3's interpreter can find them). The canvas and the Pages tab keep their bitmaps until the new ones arrive and ignore older keys.
- **Tiles** (since M2): PDFium renders each tile with a matrix and a clip into a white BGRA buffer of ferman-render's own, with the fixed flags documented in `crates/ferman-render/src/document.rs`, and with a margin of 32 device pixels on every side that is cut away. PDFium draws a glyph that crosses the edge of its bitmap differently from the same glyph inside it (by up to 136 of 255 levels in a few pixels), so without the margin text would show a seam at tile edges; with it, tiles put together match one render of the whole page to within two levels of antialiasing (glyphs come from PDFium's glyph cache up to about 50 pixels, and larger text is drawn as paths). A full tile costs about 27% more raster area. Edge tiles are cut to the page's raster, so a tile never shows anything outside its page.
- One thread limits throughput. The answers are caching, low-resolution placeholders and prefetching. Progressive rendering with a pause callback, so a slow tile (a large scan) could be abandoned when it goes stale, is out of reach: pdfium-render 0.9.4 has it only in its raw, unsafe bindings (`FPDF_RenderPageBitmap_Start`), which ferman-render does not use, so a tile always finishes once started (checked in M2). If M2 measurements show this is not enough, the fallback is a pool of helper processes with one PDFium each, which also isolates PDFium crashes. It is not planned before those measurements.

### 4.5 Tile queue

- **Priority classes**, highest first: (0) visible tiles, ordered by distance from the viewport centre; (1) prefetch, one screen ahead in the scroll direction and half a screen behind; (2) visible thumbnails; (3) other thumbnails; (4) background renders (persistent thumbnails for recents).
- **Wanted-set semantics.** Each `request_tiles` call replaces the view's wanted set and carries a new generation. Queued requests that are not in the newest set are dropped before rendering. A tile that is already rendering finishes, unless progressive rendering lets it stop.
- **Stale results.** A finished tile whose generation is older than the view's newest set goes into the cache, not to the UI, unless the newest set still wants it.
- **Ordering.** The UI keeps the newest render key per page and discards any tile with an older key, so a page never flips back to an old revision.
- **Low resolution first.** When a sharp tile is missing, the UI draws the best cached lower bucket or the thumbnail, scaled, and the tile sharpens in place without a layout shift, as a2-13 draws it ([G30](DESIGN_GAPS.md#g30)). A page that fails to render shows a2-13's placeholder with Try again; the rest of the document keeps working.

### 4.6 Job pool and cancellation

- Jobs run on a dedicated rayon pool, separate from the global one.
- Each job has a cancel token (running, paused or cancelled) checked at page granularity and inside long loops (every few thousand operators, every decoded megabyte). Pause parks the job between steps.
- Order of preference: user-initiated work (search, save) before open indexing before background work.
- Cancelling never leaves partial output: a job writes to a temp file or a change set, and only a finished job's result is committed.

### 4.7 Caches and invalidation

| Cache | Where | Key | Cap | Invalidation |
|---|---|---|---|---|
| Tiles | Rust, CPU memory | document, render key, bucket, device pixel ratio, rect | Settings › Advanced page cache (a11-1k shows 1 GB), clamped to 25% of RAM (Proposed); ferman-render's own default is 256 MiB until ferman-api sets it | a new render key makes old entries unreachable; they age out. Closing a document drops its entries |
| Tile images | Dart | same as tiles | wanted set plus a small margin | `ui.Image.dispose()` when a tile leaves the margin |
| Thumbnails | Rust, memory | document, render key, size | 64 MiB of pixels (Proposed, since M2) | as tiles |
| Recent-file thumbnails | app cache directory | file SHA-256, size | count cap | removed with the recent entry or "Clear list" (a1-4). Never stored for encrypted documents (Proposed) |
| Loaded PDFium pages | render thread | document, page | 8 per document | dropped on reload |
| Text models, search text | snapshot | page content key | shared across revisions | rebuilt only for pages whose content or resources changed |
| Glyphs and shaping | ferman-fonts | font program hash; for shaping also text, script, language, direction, features | LRU | a new font program has a new hash |
| System font index | app cache directory | font file paths and modification times | none | rebuilt when a font file changes (Proposed) |

### 4.8 Shutdown

- Closing a document: the actor finishes its current message, cancels the document's jobs except those the user left running (a11-6b), and drops its snapshots.
- Quitting: the app waits for in-flight saves. A save is never killed between write and rename. The recovery journal is flushed.

## 5. Data flow

### 5.1 Open

1. The user picks a file: native picker, drag and drop, recent files, or "Open with" from the OS (section 12).
2. `open(source)` creates the document actor. The engine reads the file into an owned buffer and computes its SHA-256 while reading. It never keeps reading the user's file after open. **Approved by the owner on 2026-10-16** (Proposed until then, [ADR 0008](adr/0008-file-safety-and-saving.md)): files above 256 MB are copied to a private snapshot in the cache directory (a clone or reflink where the file system supports it) and memory-mapped from there. The user's file is never memory-mapped, because another process truncating it would crash Ferman, and on Windows a mapping blocks the rename used for saving. Mapping the snapshot needs one `unsafe` call, an exception to section 8.1 that [Q21](QUESTIONS.md#q21) asks the owner to allow. Until it is answered, M2 reads every file into an owned buffer, so a file over 256 MB costs its size in memory while it is open ([BACKLOG.md](BACKLOG.md) B105).
3. The render thread loads the same bytes into PDFium. If a password is needed, the open fails with `PasswordRequired` and the UI shows a1-8; it opens the file again with the password (since M2, section 3.3). A wrong password returns `WrongPassword` (a1-8b, no lockout). Only this tab is blocked.
4. PDFium returns the page count and every page size without loading the pages. The UI lays out all pages with their real sizes and requests tiles for the first visible page. This is the first-page-visible path (section 14).
5. In parallel, an indexing job parses the bytes with lopdf: object model, structure scan, signatures, permissions, outline, attachments, optional content, page labels, and search text per page. For large files the UI shows a1-7: "Page 840 of 2,400 · about 20 seconds left". Search, thumbnails and editing turn on when indexing finishes, as the a1-7 banner says. Scrolling and zooming work throughout. **Proposed** with the M2 plan ([G104](DESIGN_GAPS.md#g104)): a1-7's rules apply above a threshold of more than 1,000 pages or an indexing estimate over 2 s; below it, thumbnails render from PDFium once the first page is visible, without waiting for indexing, and only search (and editing, from M3) waits for the index.
6. When both parsers succeed, the engine compares page count and page sizes. **Approved by the owner on 2026-10-16** (Proposed until then, [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md)): a mismatch opens the document read-only with a notice, because two parsers that disagree are a sign of damage or of a crafted file. No board draws the notice; its wording is Proposed with the M2 plan ([G102](DESIGN_GAPS.md#g102)).

**Underneath, since M2.** ferman-core reads the cross-reference data itself before lopdf parses the objects (`xref`): tables and streams from `startxref`, through `/Prev` (a loop ends the chain; more than 1,000 sections is a `ResourceLimit`) and the `/XRefStm` of hybrid files, then checks that every entry points at its `n g obj` header and that `/Root` names an object. lopdf 0.45 accepts a table whose offsets are wrong and loads no objects, and a password-protected file without its password as a document of one object, so neither check can be left to it. A healthy unencrypted file is handed to lopdf in place. A repaired or encrypted one goes through a copy with one clean table appended (`xref::flatten`): only `/Size`, `/Root`, `/Info` and `/ID` in its trailer, no `/Encrypt`, so lopdf parses each object as it stands and ferman-core decrypts it afterwards with its own security handler (`security`), the object streams of an encrypted file included, which ferman-core reads and decrypts before lopdf's `ObjectStream` parses them. The password therefore never reaches lopdf. Objects the cross-reference data names that are missing from the model afterwards (lopdf skips what it cannot read) are reported as a repair, `ObjectsUnreadable`, so such a document opens read-only. The page count and sizes for the two-parser check come from lopdf's page tree, which requires `/Type /Page`, with PDFium's rule for the size: the inherited crop box clipped to the media box (US Letter when that is missing or empty), turned by `/Rotate`. On the corpus the two agree to 0.05 pt on every file but `disagree-pages`, made to differ (`crates/ferman-api/tests/open.rs`).

### 5.2 Damaged, restricted and unsupported files

| Situation | PDFium | lopdf | Result | Design |
|---|---|---|---|---|
| Healthy | opens | parses | full features | — |
| Damaged, repairable | opens | strict parse fails; ferman-core repair (xref rebuilt by scanning objects) succeeds | `Repaired`: read-only view with the notice listing what was fixed; Save is enabled and writes the repaired copy (from M3, below) | a1-9 |
| Damaged, not repairable | opens | fails, repair fails | `ReadOnly`: view only; the notice explains why editing and repair are off | a1-9 wording, `save='readonly'` |
| Unopenable, or certificate-encrypted until P3 | fails | fails | error with likely cause, actions and technical details | a1-9b |
| Not a PDF (Office and image files until conversion, P3) | fails | fails | error tab "That file isn't a PDF."; Convert to PDF… disabled until P3 | a1-9c ([G28](DESIGN_GAPS.md#g28)) |
| XFA-only form | shows the fallback page | parses | `ReadOnly` with an explanation panel | a11-7c |
| Owner-password restrictions | opens | parses | banner; Edit, Comment and Fill disabled with the reason; optional owner-password unlock | a2-10a, a2-10b ([G27](DESIGN_GAPS.md#g27)) |
| Read-only file on disk | opens | parses | read-only banner, Save as only | a1-9d ([G28](DESIGN_GAPS.md#g28)) |

**How repair works, since M2.** When the file's own table is missing, unreadable or points at the wrong places (`XrefProblem`), the file is scanned for `n g obj` headers at token boundaries; each object's last definition wins, a stream is skipped to its `endstream`, and the last trailer or cross-reference stream dictionary whose `/Root` is among the objects gives the trailer, or else the last `/Catalog` with `/Pages` (`TrailerRebuilt`). The report lists `CrossReferenceRebuilt` with the number of objects found and the problem, `StreamLengthsCorrected` and `ObjectsUnreadable`. With no catalog, the file cannot be opened: `CoreError::Damaged` carries a `Diagnosis` of structural facts for a1-9b's technical details, never document text: the likely cause (`Truncated` when the last object header starts an object the file cuts off or `%%EOF` is missing, `NoCatalog`, `NoObjects`, or `Unreadable` when lopdf cannot load what the table names), the size, the size a linearized file declares in `/L`, the last object read to its `endobj`, the objects found and whether a trailer was. `truncated` gives `Truncated`, 18,432 bytes, last complete object 12 0 and no trailer.

**Repair is always a full rewrite to a new file.** Ferman never edits on top of rebuilt cross-reference data and never appends to a damaged file. Save on a damaged document means "Save repaired copy…" (a1-9), which writes the repaired model as a complete new file under a new name by default. Replacing the damaged original needs an explicit confirmation. The original stays as it was until then, as a1-9 promises. The repaired copy then opens as a normal, editable document. The writer arrives in M3, so in M2 "Save repaired copy…" and Save stay visible and disabled with "Available in a future version", and so does a1-9d's "Save a copy…" (**Proposed** with the M2 plan; [BACKLOG.md](BACKLOG.md) B103). Substitutions made during repair (for example a non-embedded TimesNewRomanPSMT shown as IBM Plex Serif) are listed in the notice and in document properties (a2-7).

### 5.3 View

- **Layout.** From `PageInfo` sizes the UI computes page rectangles for continuous, single, spread and book layouts (a2-1a to a2-1d). Spread and book order follow the document's `/ViewerPreferences/Direction`, never the UI language: with `/R2L` page 1 sits on the right, as a2-15 draws it ([G32](DESIGN_GAPS.md#g32)). Built in M2 (`app/lib/features/viewer/`): single page and two-page spread show one row at a time, centred; continuous and book scroll. 100 % is the design's 96 dpi, 4/3 logical pixels per point.
- **Tiles.** Each frame where the wanted set changes, the UI sends one `request_view` call with a new generation: the tiles in view at the zoom's bucket, nearest the centre first, the tiles half a window beyond, and each page's 256-pixel preview thumbnail. Bitmaps it has decoded (as BGRA, into a 256 MiB cache that keeps what is wanted) are left out. A page draws its preview, then other buckets' tiles, then its own, so it sharpens in place; a failed item shows a2-13's placeholder on its page until Try again.
- **Zoom.** During a pinch or ⌘-scroll the UI scales the current tiles on the GPU. It requests the new bucket when the gesture settles or crosses a bucket boundary. Quarter-octave buckets keep on-screen scaling within 19% of the raster. The UI computes a bucket's scale with the engine's own constants and rounds the device pixel ratio to `f32`, so both sides cut the same tile grid.
- **Sidebar.** Thumbnails come from the render thread, through an engine view of the Pages tab's own that asks only for the thumbnails the list has built, at the canvas's preview size. Outline, attachments, page labels, layers and signature fields come with the open result (§3.3). Empty tabs use a2-3m's EmptyState ([G29](DESIGN_GAPS.md#g29)), and signatures are shown in a2-14's neutral state until validation ships in P3 ([G31](DESIGN_GAPS.md#g31)). **Built in M2** (W2, commit 10; the eye buttons in commit 10b); Save attachment as… comes with W3's open picker.
- **Search** (M2) runs as a job over the per-page search text. Text is NFC-normalised and case-folded with Turkish-aware equivalence, so "kira" finds "KİRA" (a2-4a, a2-3e). The a2-4a option "Ignore accents and dotted/dotless i" adds diacritic folding (NFD, then marks removed) and dotted/dotless i matching, so "i" finds İ, ı and î. It is on by default for every document, whatever its language ([G61](DESIGN_GAPS.md#g61)), so "muller" finds "Müller". Results stream page by page so the "1 of 7" counter updates live; a search that takes more than a moment shows its progress and Cancel under the find bar (a2-4c), and no result reads as a2-4d draws it. Highlights are quads in page space. Edited pages are re-indexed after each commit.

### 5.4 Edit

```text
UI              ferman-api actor        ferman-text            ferman-core           render thread
--              ----------------        -----------            -----------           -------------
click block ──► begin_edit: check
                permissions, signatures
type "ğ"    ──► apply ────────────────► relayout block,
                                        re-encode, build
                                        replacement ops ─────► splice into content
                                                               stream, new object
                                                               in overlay
            ◄── preview ◄─── publish preview snapshot ───────────────────────────────► reload revised bytes
tiles       ◄───────────────────────────────────────────────────────────────────────── render edited tiles first
blur        ──► commit: new revision on the stack, journal record appended
```

1. `begin_edit` captures the block's operator spans and the full state at the block's start and end (section 6.6).
2. `apply` sends the operation to ferman-text, which updates the block's logical text, lays it out again inside its frame, and re-encodes it in the font's own encoding.
3. ferman-text generates the replacement operators for the block. Every other operator keeps its bytes.
4. ferman-core splices them into the content stream. The result is a new version of the content stream object, kept in the revision overlay under the same object number and appended in the next incremental update. If the stream is shared with other pages, it becomes a new object and only this page's `/Contents` changes.
5. The actor publishes a preview snapshot. The render thread loads the revised bytes and re-renders tiles only for pages whose render key changed, the edited region first. The UI keeps showing the old tile until the new one arrives, so nothing flickers.
6. `commit` turns the preview into a revision on the undo stack and appends a record to the recovery journal (section 7.6).

When the user saves, all changes since the last save become one incremental update (section 5.5). The in-memory preview bytes and the saved bytes are built by the same writer.

### 5.5 Save

1. **External-change check** (section 7.5). If the file changed on disk, the UI shows a11-7b with its three choices, "Compare", "Keep mine" and "Reload".
2. **Build the update.** Every object changed since the last saved revision, in its latest version only. The cross-reference section matches the original's form (classic table or xref stream), with `/Prev` pointing to the previous one. New objects are encrypted with the document's key when the file is encrypted. The first element of the `/ID` array stays, the second changes.
3. **Write** the base bytes plus the update to a temp file, then fsync, verify, rename and fsync the directory (section 7.2).
4. The saved revision becomes the new base. The recovery journal for the document is cleared. The status bar says "Saved on this device · 14:32" (f4b).

Save states follow f4: unsaved, saving, saved, error. Save stays enabled in the error state so the user can retry ([G41](DESIGN_GAPS.md#g41)). Save modes:

- **Incremental update** (default). The original bytes are an exact prefix of the new file. Signatures keep covering the bytes they signed.
- **Optimize and clean** (opt-in full rewrite, [ADR 0008](adr/0008-file-safety-and-saving.md)). It removes unreferenced objects and earlier revisions and recompresses. It invalidates signatures, so the UI warns first.
- **Save as** writes a new file with either mode. The a1-11 sheet collects options and hands off to the OS-native save picker for "Other location…", then shows the chosen folder, as a1-11b draws it ([ADR 0018](adr/0018-native-file-pickers.md), Accepted on 2026-10-16; [G26](DESIGN_GAPS.md#g26)). The "PDF/A-2b, for archiving" and "Optimized for web" formats are later phases and stay disabled with "Available in a future version".

### 5.6 Autosave and recovery

Recovery copies live in the app data directory, never next to the user's file (brief §3). The layout, journal format and crash handling are in section 7.6. The flow: every commit appends a record, a snapshot is written every minute while there are unsaved changes (a11-1c "Save a recovery copy every minute"), and on the next launch after a crash the UI offers a1-12.

### 5.7 Close and quit

- Closing a tab with unsaved changes shows a1-10b (Save, Don't save, Cancel; button order per platform).
- Quitting with unsaved changes in more than one document asks once, as a11-7e draws it: one checked row per document, then Save and quit, Quit without saving and Cancel, in the platform's button order ([G40](DESIGN_GAPS.md#g40)).
- After a clean close or explicit discard, the document's recovery files are deleted.

## 6. Text editing pipeline

This is brief §4, the hardest part. It is fixed by the brief and described in [ADR 0005](adr/0005-block-scoped-text-editing.md) and [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md). Work starts in M3.

### 6.1 Content-stream interpreter (ferman-core)

- **Graphics state:** `q`/`Q` stack, `cm`, clipping (`W`, `W*`), colour operators (kept so re-encoded text keeps its fill and stroke colour, and so a3-2 can offer document colours first), `gs` parameters that affect text.
- **Text state:** `BT`/`ET`, `Tf`, `Tc`, `Tw`, `Tz`, `TL`, `Ts`, `Tr`; positioning `Td`, `TD`, `Tm`, `T*`; showing `Tj`, `TJ`, `'`, `"`. The text matrix and the line matrix are tracked separately, because `Td` and `T*` are relative to the line matrix.
- **Subtle rules:** `Tw` applies only to the single-byte code 32, also in composite fonts. `Tr 3` is invisible text (OCR layers). Clip render modes 4 to 7 add to the clip. `TJ` numbers are in thousandths of text space.
- **Form XObjects:** recursive, with `/Matrix`, `/BBox` clipping and their own resources, cycle detection and a depth limit (section 9).
- **Marked content:** `BMC`, `BDC`, `EMC` with `/MCID`, `/ActualText`, `/Lang`, `/Artifact` and `/OC` (optional content).
- **Inline images:** `BI … ID … EI` parsed carefully, since the end marker can appear inside image data.
- **Type3 glyph procedures** (`d0`, `d1`) are interpreted for extraction.
- **Output:** a stream of events to an `InterpreterSink`. Each operator carries a span: content stream object, byte start and byte end. A page's `/Contents` may be an array of streams, and a split may fall between an operator and its operands, so spans can cross stream boundaries.
- **Advances:** after a show operator the interpreter must move the text matrix, which needs glyph widths. It asks the `TextAdvance` trait, implemented by ferman-text. This keeps ferman-core free of font code.

### 6.2 Fonts and encodings (ferman-text over ferman-fonts)

| Font type | Program | Codes to glyphs | Widths |
|---|---|---|---|
| Type1, including the standard 14 | FontFile (minimal Type1 parser), FontFile3/Type1C (CFF), or none (standard 14) | built-in encoding, `/Encoding` base plus `/Differences`, glyph names | `/Widths`, `/FirstChar`, `/LastChar`, `/MissingWidth`; standard 14 metrics from AFM data (licence checked before adding) |
| TrueType | FontFile2 | symbolic flag decides: (3,0) cmap with the F0xx range or (1,0) cmap; otherwise names through the `post` table or Unicode cmap | as Type1 |
| Type3 | glyph procedures in `/CharProcs` | `/Encoding` with `/Differences` | `/Widths` scaled by `/FontMatrix` |
| Type0 (CIDFontType0, CIDFontType2) | CFF CID-keyed or TrueType | CMap: Identity-H, Identity-V, embedded CMaps with `usecmap`, predefined CMaps; CID to GID through `/CIDToGIDMap` | `/W`, `/DW`; vertical `/W2`, `/DW2` |

Positions always come from the PDF widths, not the font program, because that is what viewers do. Re-encoded text uses the same widths, so the layout model and the rendered result agree.

### 6.3 From glyphs to Unicode

Priority, first match wins:

1. `/ActualText` of the enclosing marked content.
2. The font's ToUnicode CMap (`bfchar`, `bfrange` including the array form, UTF-16BE with surrogate pairs, one code to several characters for ligatures).
3. The encoding's glyph names through the Adobe Glyph List, plus `uniXXXX` and `uXXXXX` names.
4. A reverse lookup in the font program's cmap.
5. Unknown: U+FFFD. Such a block is not editable, with the reason "This text can't be read reliably".

Arabic presentation forms (U+FBxx to U+FExx) are normalised with NFKC to logical letters for the text model and search.

### 6.4 Text model

- **Glyphs to words:** a word break where a space glyph appears, or where the gap (including `TJ` displacement) exceeds a threshold relative to the font size.
- **Words to lines:** baseline clustering along the writing direction, done in text space so rotated text groups correctly.
- **Lines to blocks:** consistent leading, indentation, font and size continuity, and alignment detected from line edges (left, right, center, justified). Justification records its method (`Tw` or `TJ` adjustments) so edits reproduce it.
- **Columns and reading order:** whitespace gutters with recursive XY cuts, column-major order, right-to-left aware for Arabic, Persian and Hebrew documents. Content streams often store RTL text in visual order, so lines are resolved to logical order with the bidi algorithm (UAX #9).
- **Tables:** column detection for in-cell edits (a3-9, M3). Row insertion is later.
- **Block identity:** `BlockId` stays stable within a session. The actor maps old ids to new ones after a commit, so a block keeps its id after its own edit.

### 6.5 Editability

Every block carries `editable` and a reason when it is false. The UI shows the reason in a tooltip with a not-allowed cursor and in the panel, as a3-11 and a3-19 draw it ([G39](DESIGN_GAPS.md#g39)).

| Reason | Example | What the user can do |
|---|---|---|
| Image only | scanned page (a3-11) | text recognition, shown disabled until P3 |
| Unknown text | no usable Unicode mapping | nothing in M3 |
| Outlined text | glyphs drawn as paths | nothing in M3 |
| Restricted by the author | owner-password permissions (G27) | unlock with the owner password |
| Read-only file or damaged document | G28, section 5.2 | Save as, or save a repaired copy |
| Signature appearance | text inside a signature field | none; signatures are never edited |
| Annotation or form field | not page content | Comment or Fill & Sign modes |
| Too complex | limits hit (section 9) | none; the reason says so |

Text inside a Form XObject used in several places is editable. The edited placement gets its own copy of the XObject (copy-on-write): its `Do` operator, which belongs to the block, names the copy, and the page's resources gain one entry. Every other placement keeps the original.

### 6.6 Transaction, re-encoding and operator rewriting

1. **Layout.** The edited logical text is broken into lines inside the frame with UAX #14 line breaking (and later hyphenation from the block's language, a3-2). Lines before the first change keep their original operator bytes when their layout is unchanged.
2. **Shaping.** Complex scripts are shaped (section 6.10). Simple Latin text uses the font's advance widths directly.
3. **Re-encoding.** Each character becomes a code in the font's own encoding: the reverse of the effective simple-font encoding, or the reverse CMap plus `/CIDToGIDMap` for Type0 fonts. A character with no code goes to the missing-glyph steps (section 6.7).
4. **Operator generation.** The replacement starts with the text state the original block started with (`Tf`, `Tc`, `Tw`, `Tz`, `TL`, `Ts`, `Tr`, colour) and positions lines with `Td` or `Tm` relative to the original line origins. `TJ` carries kerning and justification. Numbers are written with deterministic precision.
5. **State invariant.** After the replacement, every piece of state that later operators can observe must equal what the original block left behind: text matrix, line matrix, text state parameters, colour and `q` depth. The generator ends with explicit operators that restore them (for example a final `Tm` with the original end matrix). Without this, a following `Td` relative to the line matrix would shift text outside the block.
6. **Interleaved blocks.** When a block's operators are interleaved with other blocks' operators (common in multi-column output), all new text goes into the first span. The other spans are replaced with only the state-setting operators needed to keep the invariant.
7. **Splice.** ferman-core replaces exactly the block's byte spans. The stream is re-encoded with its original filter where Ferman can encode it (Flate, LZW, ASCII85, ASCIIHex, RunLength, none), otherwise with Flate.
8. **Proof.** A test asserts that the bytes outside the spans are identical and that the pixels outside the edited region are identical (section 13.4).

### 6.7 Missing glyphs

The design is not silent: it says so once, marks the character, and offers "Choose a font…" or "Keep as is". Settings has "Ask each time" (a11-1c). The three steps of brief §4, as decided in [G36](DESIGN_GAPS.md#g36) and [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md):

1. **The embedded font has the glyph.** Use it. If the program contains the glyph but the encoding has no code for it (for example `/gbreve` in a WinAnsi-encoded font), the engine assigns an unused code through `/Differences` in a new font dictionary used only by the edited block. The original dictionary stays untouched, so other text keeps its bytes and its rendering.
2. **The same font is installed.** fontdb finds it by PostScript name (subset tag removed), then family and style. The engine checks that it really is the same font: units per em, and advance widths of the glyphs the document uses within one unit in 1000 of `/Widths`. It respects the font's embedding permissions (OS/2 `fsType`): restricted fonts go to step 3 with the reason ([G37](DESIGN_GAPS.md#g37)), no-subsetting fonts are embedded whole. The engine builds a new subset with subsetter and embeds it as a new Type0 font with Identity-H encoding and a ToUnicode CMap, used only by the runs that need it. The original subset is not modified, so every other block is untouched. The user is told once, in the panel callout a3-17 draws: "Character added from this computer", "Ferman took ‘ğ’ from Garamond Premier Pro installed on this computer and added it to the document’s font." (G37).
3. **Otherwise, the design's flow.** Similar fonts are ranked by coverage of the needed characters and by metrics (x-height, cap height, average width, weight, serif or sans class), from three groups: embedded in this document, installed on this computer, included with Ferman (a3-3b). With the default "Use a similar font and say so" (a11-1c), the character is drawn in the closest match and marked once: amber wavy underline, amber frame tab, warning on the font field (a3-3a, f2). "Choose a font…" opens the a3-3b picker. "Keep as is" keeps the substitution. "Ask each time" asks first. "Keep the original font and mark the character" leaves the character undrawn and marked. The default is confirmed in [Q09](QUESTIONS.md#q09). Beyond IBM Plex, Ferman bundles Cormorant Garamond and Crimson Pro as similar fonts, the two a3-3b shows ([Q08](QUESTIONS.md#q08) group 4, 2026-10-16).

Every substitution is recorded as an edit in the review list (a3-12) and announced with the "Font substituted" toast (a11-6). Bold and italic are never faked (a3-15).

### 6.8 Overflow

When the re-laid-out text needs more lines than the frame holds, the panel offers the design's three choices (a3-4):

- **Extend block by N lines.** The frame grows down. If it would overlap other content (the IBAN line under Madde 4), the option is disabled with the reason, as a3-18 draws it ([G38](DESIGN_GAPS.md#g38)).
- **Tighten spacing slightly.** Character or word spacing shrinks within a small cap (Proposed: 2%). If that is not enough, the option is disabled with the reason.
- **Keep and warn.** The block model keeps all the text. The saved content stream draws the lines that fit and writes the rest clipped to the frame, so no text is lost and nothing is drawn over neighbouring content. The warning stays in the review list and on the page thumbnail until resolved. Text clipped this way is listed by "Remove hidden information" (a8-3, P2).

The same machinery serves translation overflow later (a3-13b, P4). The labels are the brief's three labels everywhere ([G54](DESIGN_GAPS.md#g54)).

### 6.9 Signed documents

- ferman-core detects signatures at open: AcroForm `/SigFlags`, signature fields with values, DocMDP and certification signatures.
- Before the first change to a signed document (edit, comment, fill or organize), `begin_edit` returns `NeedsConfirmation` and the UI warns that the signature will become invalid. Without the confirmation token the engine refuses to commit. a3-16a draws the dialog ("Edit a copy" as the default, "Edit anyway", "Cancel"), and a3-16b the banner that stays after "Edit anyway" ([G35](DESIGN_GAPS.md#g35)).
- An incremental update leaves the signed bytes intact, so the old revision still verifies, but validators report the document as changed after signing. A full rewrite breaks the signature outright.
- Signature validation is P3. Until then signatures appear in a2-14's neutral state, without a validity colour or a check ([G31](DESIGN_GAPS.md#g31)).

### 6.10 Right-to-left text

- Logical text runs through the bidi algorithm per paragraph, with the base direction from the block. Numbers, dates and IBANs stay left-to-right and isolated.
- Runs are shaped with the font's GSUB and GPOS tables (harfrust, [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md)), producing glyph ids in visual order with advances and mark offsets.
- Glyph ids map to codes through the font's encoding (often CID equals GID under Identity-H). Horizontal offsets go into `TJ`. Vertical mark offsets need `Ts` or a new `Tm`.
- A subset font often lacks contextual forms the original text never used (initial, medial, final forms, lam-alef ligatures). So coverage is checked per shaped glyph, not per character, and a missing form goes through section 6.7.
- Persian text with ZWNJ is tested explicitly, because some fonts do not map it.

### 6.11 CJK and vertical text

- Type0 CID fonts with Identity-H or Identity-V or predefined CMaps. Vertical metrics come from `/W2` and `/DW2` (default vertical displacement −1000, default position vector from half the width and 880).
- Vertical writing (a3-15): columns right to left, vertical alternates through the `vert` feature, tate-chu-yoko for short numbers such as "19", kinsoku rules so punctuation never starts a column, a horizontal caret moving down the column.
- Line breaking uses UAX #14 plus kinsoku rules. Bold and italic are disabled with the reasons a3-15 shows.
- CJK fonts are not bundled ([ADR 0013](adr/0013-fonts-and-icons.md)). Step 2 finds installed fonts; step 3 lists installed CJK fonts.
- Ruby annotations are out of scope for M3.

### 6.12 The UI side of editing

- **Input.** The canvas editing surface implements Flutter's `DeltaTextInputClient`. Composing text from an IME (Japanese, Chinese, Korean, dead keys) goes to the engine as `SetComposing` and is rendered provisionally, without an undo step.
- **Caret and selection.** The engine returns caret stops and selection quads in page space. Flutter draws them as overlays.
- **Edit marks** (dotted underline and margin bar, f3) are a UI overlay from the engine's changed ranges. They are never saved or printed.
- **Accessibility.** Each block is a semantics node in reading order ("Text block, Madde 3, paragraph", a3-1a). An active block behaves as a multi-line text field (a3-1b).
- **Review list** (a3-12) and undo history (a3-10) come from the engine's edit journal and revision labels.

## 7. File safety

Brief §3: never corrupt a user's file. Save through a temp file and an atomic rename, incremental update by default, optional "optimize and clean" full rewrite, autosave and recovery files in the app data directory. Details in [ADR 0008](adr/0008-file-safety-and-saving.md).

### 7.1 Rules

1. Never write in place. Every save writes a new file and replaces the old one atomically.
2. Never memory-map or keep open the user's file after open (section 5.1).
3. The temp file lives in the same directory as the target, so the rename stays on one volume and is atomic.
4. A failed save leaves the original untouched and deletes the temp file.
5. Edits are never lost because a save failed: they stay in memory and in the recovery journal.

### 7.2 Atomic replace

| Step | Linux | macOS | Windows |
|---|---|---|---|
| 1. Create temp file | `.<name>.ferman-<random>.tmp` in the target directory, exclusive create | same | same, hidden attribute |
| 2. Write | all bytes | same | same |
| 3. Flush file | `fsync` | `F_FULLFSYNC` (what Rust's `sync_all` does on Apple platforms) | `FlushFileBuffers` |
| 4. Verify | re-read the trailer and cross-reference data; for incremental saves check that the original bytes are an exact prefix | same | same |
| 5. Copy metadata | mode bits and, where allowed, owner and group | `fcopyfile` with `COPYFILE_METADATA` (ACLs, extended attributes, Finder tags, flags) | handled by `ReplaceFileW` |
| 6. Replace | `rename(2)` | `rename(2)` | `ReplaceFileW`; fallback `MoveFileExW` with `MOVEFILE_REPLACE_EXISTING` and `MOVEFILE_WRITE_THROUGH` |
| 7. Flush directory | `fsync` on the directory | `fsync` on the directory | not needed (`MOVEFILE_WRITE_THROUGH`) |

- `ReplaceFileW` keeps the original's attributes, ACLs and creation time. It can fail on some network shares and FAT volumes, which is when the `MoveFileExW` fallback applies.
- A file opened by another app without delete sharing causes a sharing violation on Windows. Ferman retries briefly with backoff, then reports `FileLocked` ([G40](DESIGN_GAPS.md#g40)).
- **Symbolic links:** the link is resolved and the target is replaced; the link stays.
- **Hard links:** a file with more than one link would lose them on rename. Ferman detects this and offers Save as instead of replacing silently (a state to draw under G40).
- **Ownership:** if the user does not own the file and cannot restore its owner, Ferman offers Save as.
- **macOS App Sandbox.** The owner answered [Q18](QUESTIONS.md#q18) on 2026-10-16: the sandbox stays on in every macOS build if M2 shows that this write and security-scoped bookmarks work under it; otherwise the Developer ID build drops it and keeps the hardened runtime. Under the sandbox the temp file comes from the system's item-replacement directory on the same volume (`FileManager.url(for: .itemReplacementDirectory, …)`) and `replaceItemAt` (`replaceItemAtURL` in Objective-C) performs the swap. **Proposed** with the M2 plan: M2 builds this path for "Save attachment as…" (a2-3b), the first file Ferman writes for the user, and M3 uses it again for the document writer ([ADR 0008](adr/0008-file-safety-and-saving.md)).
- atomic-write-file is evaluated against this table in M3. If it does not cover `ReplaceFileW` and metadata preservation, ferman-core implements the sequence directly.

### 7.3 Incremental update and full rewrite

- **Incremental (default).** The original bytes stay an exact prefix. It is fast, keeps signatures covering their bytes, and keeps old content inside the file. The design says so in a8-3 ("Content from before the last 2 saves is still inside the file").
- **Consequence for cropping:** content hidden by a crop is hidden, not removed, until a full rewrite or "Remove hidden information" ([G57](DESIGN_GAPS.md#g57)).
- **Optimize and clean (opt-in).** A full rewrite that drops earlier revisions, unreferenced objects and duplicate resources, and recompresses. It breaks signatures, so it warns first. Redaction (P2) always uses it (a8-2c: "rewritten without its 2 earlier saves").
- Settings › Editing explains the default in its Saving group and offers no switch between the two: Optimize and clean is a command that warns first and is never the default, as a11-1c draws it since export `519d42a` ([G43](DESIGN_GAPS.md#g43)).

### 7.4 Version history (M4)

The design keeps versions for 30 days in a hidden folder next to the file (a9-8, a11-1c). That folder is written with the same atomic sequence. Its location next to the file (sync folders, read-only directories) is decided with an ADR when M4 is planned.

### 7.5 External-change detection

- At open and after each save, the engine records size, modification time and SHA-256.
- Before saving it checks size and modification time. If either differs, it hashes the file again. If the hash differs, the save stops and the UI shows a11-7b ("Compare", "Keep mine", "Reload"). Ferman does not pick a winner.
- **Proposed:** an OS file-change notification also triggers the check while the document is open, so the banner can appear before the user saves. The crate is chosen and licence-checked in M3.

### 7.6 Autosave journal and recovery

Location, per platform (the bundle identifier is `io.github.kerembas.ferman`, [Q01](QUESTIONS.md#q01)):

- macOS: `~/Library/Application Support/io.github.kerembas.ferman/Recovery/`. While the App Sandbox is on ([Q18](QUESTIONS.md#q18)), that path lies inside the app container, `~/Library/Containers/io.github.kerembas.ferman/Data/`.
- Windows: `%LOCALAPPDATA%\Ferman\Recovery\`
- Linux: `$XDG_STATE_HOME/ferman/recovery/` (default `~/.local/state/ferman/recovery/`)

```text
Recovery/
└── <session id>/
    ├── instance.lock            PID of the running instance
    └── <document id>/
        ├── manifest.json        original path, size, mtime, SHA-256, encrypted flag, last saved revision
        ├── base.pdf             clone or copy of the original, when cheap (see below)
        ├── snapshot-<rev>.bin   one incremental section with every unsaved change at that revision
        └── journal.log          length-prefixed, checksummed records of commits after the snapshot
```

- **Physical log.** A journal record holds the objects a commit changed, serialised as PDF objects, plus the revision label. Replay is pure data. It does not depend on installed fonts or on engine behaviour, so it cannot diverge.
- **Write cadence.** Records are appended and synced at most once per second. A snapshot is written every minute while there are unsaved changes, using the atomic sequence, and the journal restarts after it. The "Save a recovery copy every minute" switch (a11-1c) turns both off.
- **Base copy (Proposed).** Recovery must not depend on the original staying unchanged. On the first unsaved change the engine stores a clone of the original (APFS `clonefile`, reflink on Btrfs, XFS or ReFS) or a plain copy for files up to 200 MB. Larger files on file systems without clones rely on the manifest hash; if the original changed, recovery marks it and opens the restored version under a new name, so neither is overwritten, as a11-7f draws it ([G40](DESIGN_GAPS.md#g40)).
- **Encrypted documents.** Recovery data is written encrypted with the document's own key, as the file itself would be. Plaintext never reaches disk. Restoring asks for the password again (a1-8).
- **Privacy.** The recovery directory is created with owner-only permissions (0700 on Unix). Nothing in it is ever sent anywhere (a1-12: "Nothing was sent anywhere").
- **Cleanup.** Files for a document are deleted after a successful save, after "Don't save", and after "Discard" in a1-12.

### 7.7 Crash safety

- On launch, a session directory whose lock file names no live process belongs to a crashed session. The UI shows a1-12: "Ferman restored 2 documents", each checked; "Open 2 documents" or "Discard". Restored documents open as unsaved; files on disk are unchanged.
- A crash during step 6 of section 7.2 leaves either the old file or the new one, never a mix. A leftover temp file is deleted on the next save in that directory.
- A panic in a document actor stops that document only (section 8.3). The UI offers to reopen it from the journal.
- The crash log is written locally and copied only when the user presses "Copy crash log" (a1-12). The copy replaces paths and file names with placeholders (section 8.4).

### 7.8 When writing fails

| Failure | Detection | Result | Design |
|---|---|---|---|
| Disk full | free-space check before writing (expected size plus margin), and `ENOSPC` or `ERROR_DISK_FULL` during the write | temp file deleted, original untouched, edits kept; "Try again" or "Save somewhere else…" | a11-7, f4 toast |
| Recovery copy also cannot be written | journal write fails | the dialog says honestly that no recovery copy exists | wording to draw ([G40](DESIGN_GAPS.md#g40)) |
| Read-only or permission denied | `EACCES`, `EROFS`, `ERROR_ACCESS_DENIED` | Save as offered | a11-7d (G40) |
| Locked by another app | sharing violation after retries | "Close it in the other app, or Save as…" | a11-7d (G40) |
| Rename failed | step 6 error | temp deleted, original untouched, Save as offered | a11-7d, "Couldn't replace the original" (G40) |
| Volume disappeared | I/O error on a network drive | edits kept, Save as offered | a11-7d, "Drive disconnected" (G40) |

## 8. Error handling

Fixed by brief §5 ([ADR 0010](adr/0010-error-handling-no-panics.md)).

### 8.1 Errors per crate

- Each crate has its own `thiserror` enum: `CoreError`, `FontError`, `TextError`, `RenderError`, `OpsError`. Variants carry context (object id, page, operator offset), never document text.
- No `unwrap`, `expect`, `panic`, `todo` or `unimplemented` in library code. Clippy enforces this with `unwrap_used`, `expect_used`, `panic`, `todo` and `unimplemented` denied outside tests. Parser modules also deny `indexing_slicing` and use checked arithmetic, because untrusted input must not be able to trigger a panic or a silent overflow.
- `forbid(unsafe_code)` at every crate root except ferman-api. ferman-api uses `deny(unsafe_code)` and allows unsafe code only on the FRB-generated module behind the `frb` feature. That glue needs `extern "C"` exports and `unsafe` blocks, it is never edited by hand, and an inner `allow` cannot override `forbid`, hence the exception. A CI check fails on any `allow(unsafe_code)` outside that module ([roadmap](ROADMAP.md), M1 steps 1 and 3).
- pdfium-render is the other unsafe layer. Any further unsafe code (for example if ferman-render ever renders into a caller-owned buffer) is a documented, reviewed exception.
- Public items are documented. `cargo fmt` and `clippy -D warnings` run in CI.

### 8.2 Mapping to ApiError

| Kind | Typical cause | Design state |
|---|---|---|
| `NotFound` | file moved or deleted, stale handle | missing recent file, a1-9e ([G28](DESIGN_GAPS.md#g28)) |
| `PermissionDenied` | read-only file or folder | a1-9d on open, a11-7d on save (G28, G40) |
| `FileLocked` | open in another app | a11-7d (G40) |
| `DiskFull` | no space left | a11-7 |
| `FileChangedOnDisk` | external modification | a11-7b |
| `PasswordRequired`, `WrongPassword` | encrypted file | a1-8, a1-8b |
| `Restricted` | owner-password permissions | a2-10a (G27) |
| `Damaged` | unrecoverable file | a1-9b |
| `Unsupported` | not a PDF, XFA, certificate encryption, unknown filter | a1-9c (not a PDF), a11-7c (XFA), a1-9b (certificate encryption until P3) |
| `NotEditable` | block cannot be edited | a3-11, a3-19 (G39) |
| `ConfirmationRequired` | signed document | a3-16a (G35) |
| `ResourceLimit` | a limit in section 9, or memory that a check before allocating finds short | "too complex" message; out of memory closes only that document's tab, a1-9f (**Proposed** with the M2 plan, [ADR 0010](adr/0010-error-handling-no-panics.md)) |
| `Cancelled` | job cancelled | none; expected |
| `Internal` | a bug or a caught panic | generic message plus "Copy technical details" |

- **Message keys.** The engine defines one closed `MessageKey` type whose values are ARB keys (lowerCamelCase, as gen-l10n requires, for example `errorSaveDiskFull`): a newtype with a private field, one constant per key and `MessageKey::ALL`. The first key is `errorInternal`. Its `&'static str` field cannot cross FRB, so the `frb` layer mirrors it as a `String`. A CI test checks that every key in `MessageKey::ALL` exists in `app_en.arb` and `app_tr.arb`; it is added with the first error strings in the ARB files (M1 step 10). The sentence states what happened and the way out; error codes never appear in it (a1-9b). Technical details stay secondary. **Since M2** the open path maps ferman-core's and ferman-render's errors to `NotFound`, `PermissionDenied`, `PasswordRequired`, `WrongPassword`, `Damaged` (with the `Diagnosis` as details), `Unsupported` (a file that is not a PDF has its own key), `ResourceLimit`, `Io` and `Internal`, with the keys `errorFileNotFound`, `errorFilePermissionDenied`, `errorFileRead`, `errorNotPdf`, `errorPasswordRequired`, `errorWrongPassword`, `errorDamaged`, `errorUnsupported`, `errorTooComplex` and `errorOutOfMemory`. `Restricted`, `Cancelled` and the save kinds arrive with the calls that produce them. The keys reach the ARB files, and the test that checks them, with the screens that show them.

### 8.3 Panics at the boundary

- FRB v2 turns a panic in a Rust call into a Dart exception. ferman-api also wraps each actor and job entry point in `catch_unwind` as a last resort (`guard()` in the facade). A panic payload is free text from any crate and can embed document text, so it never reaches `details` or the release log; only debug builds log it.
- A panic in a document actor marks that document as stopped: no more edits. The UI offers to reopen it from the recovery journal. Other documents are unaffected.
- The release profile keeps `panic = "unwind"`. With `abort`, every bug would become a crash that loses all open documents.
- A crash inside PDFium (C++) cannot be caught. The defences are fuzzing, the pinned binary, the recovery journal, and the helper-process option (section 4.4).

### 8.4 Logs

- The engine logs with `tracing`, the app with a thin Dart logger, both to local rotating files in the app's log directory (Proposed: five files of 5 MB). "Show log files" (a11-1k) opens the folder.
- Logs never contain document text, typed characters, passwords or rendered content. File paths may appear in the local log files, because they help explain open and save failures. Ferman never sends a log anywhere.
- **Copy crash log** (the placeholders approved by the owner on 2026-10-17). "Copy crash log" (a1-12) puts the log on the clipboard so the user can paste it into a report, often a public GitHub issue. Paths can hold client names and document titles. So the copied text replaces the home folder, folder names and file names with placeholders. The extension and file size stay, and one file keeps one placeholder, so the log still reads well (for example `<home>/<folder 1>/<file 1>.pdf, 2.4 MB`). The confirmation toast asks the user to check the text before sharing it. That toast is not drawn yet.
- "Copy technical details" (a1-9b) carries structural facts only, as drawn ("Expected about 2.4 MB, found 18 KB · last complete object 12 0 obj · no trailer"). It never holds paths or document text.
- No telemetry, no crash reporting service, no analytics. Nothing is uploaded, ever.

## 9. Security

PDFs come from strangers. Every byte is untrusted.

### 9.1 Resource limits

All values are **Proposed** and live in one `Limits` struct (`ferman_core::limits`, since M2), so tests, the fuzz targets and the CLI can tighten them. A limit that stops the work is `CoreError::ResourceLimit` with its `LimitKind`.

Since M2's open path, each limit ferman-core enforces has a test that crosses it: nesting in ferman-core's own parser (trailers, cross-reference streams, the encryption dictionary, the repair scan), the decoded size of a cross-reference stream (a bomb in one stops the open), the filter chain, and the `/Prev` chain. lopdf parses the document's objects with its own nesting bound of 100, below the 256 here: an object nested deeper is skipped, counted as unreadable, and the document opens repaired and read-only, without a crash at any depth (tested to 100,000). lopdf's object streams are bounded by the decoded size per stream through its `max_decompressed_size`; one that crosses it is skipped the same way. The decoded size per revision is enforced where streams are decoded in bulk, with extraction (M2 W3). The other limits (`q` nesting, recursion, operators, CMaps, fonts, images, time) arrive with the interpreter, fonts and extraction.

| Limit | Default | Why |
|---|---|---|
| Nesting of arrays and dictionaries | 256 | recursive-descent parsing can exhaust the stack; parsing threads also get large stacks (64 MB) |
| Form XObject, Type3 and pattern recursion | depth 32, plus cycle detection | infinite or exponential recursion |
| `q` nesting | 256 | unbounded state stacks |
| Operators per page | 10 million | interpretation beyond this marks the page "too complex"; PDFium still renders it |
| Decoded size per stream | 256 MB | decompression bombs |
| Decoded size per document revision | 2 GB, and never more than half of physical RAM | many small bombs |
| Filter chain length | 8 | filter loops |
| `/Prev` chain and object streams | 1,000 sections, loop detection | crafted xref loops |
| CMap `usecmap` depth | 8 | CMap loops |
| Font program size | 64 MB | oversized fonts |
| Image size decoded by Ferman | 2^28 pixels | memory exhaustion in compress and OCR |
| Interpretation time per page | 2 s, cooperative | slow pages become "too complex" for editing, never a hang |

### 9.2 Untrusted content rules

- **Document JavaScript is never executed**, and Ferman tells the user when a document contains scripts (confirmed by the owner on 2026-10-16, [Q13](QUESTIONS.md#q13)). Ferman ships the non-V8, non-XFA PDFium build, so scripts cannot run. Calculated form fields therefore do not update themselves; the Fill panel will say so. Remove hidden information lists JavaScript as found ("Ferman never runs it", a8-3). No board draws the notice at open. **Proposed** with the M2 plan ([G100](DESIGN_GAPS.md#g100)): the structure scan finds the scripts, and the document opens with an info banner that counts them and reuses a8-4's sentence "Ferman never runs scripts; other apps might.", with a row in document properties.
- **No network from document content.** No remote fonts, no URL file specifications fetched, no form submission, no prefetching of links.
- **Actions.** `/Launch` actions never run. A `/URI` link opens in the OS browser only when the user clicks it and sees the address first. Embedded files are never opened automatically.
- **Two parsers.** When lopdf and PDFium disagree on structure, the document opens read-only (section 5.1).
- **Passwords** are wiped from memory after key derivation. They are never logged and never written to disk. Since M2, a password is a `ferman_core::Password`, which wipes itself when dropped and never shows in `Debug` output or an error. The standard security handler is ferman-core's own (revisions 2 to 6: RC4 40 and 128, AES-128 and AES-256, crypt filters, unencrypted metadata, and a signature's `/Contents` left as it is), so lopdf never sees the password: it would copy it into strings it frees without wiping them. Every buffer derived from the password (PDFDocEncoding or SASLprep output, the padded password, the hashes, the file key and each object's key) is a `Zeroizing` buffer, and the hash and cipher crates are built with their `zeroize` features. SASLprep runs on stringprep's tables into a reserved buffer, because stringprep's own function returns the prepared password in a plain `String`. PDFium must have the password too, to render the document; pdfium-render copies it into a C string and PDFium keeps it while the document is open, which Ferman cannot wipe ([Q22](QUESTIONS.md#q22)). The Dart string the password arrives as cannot be wiped either; the UI drops it as soon as the call returns.

### 9.3 Fuzzing and supply chain

- Every parser gets a cargo-fuzz target from the first parser in M2 (section 13.6). Fuzz runs in CI, and every crash becomes a regression test.
- cargo-deny checks licences, bans, advisories and sources (crates.io only) on every pull request ([ADR 0016](adr/0016-dependency-licence-policy.md)). Banned crates include `pdfium` (GPL-3.0), `mupdf`, `jbig2dec` and the poppler bindings.
- The PDFium archive is pinned by tag and SHA-256. Its builds are third-party and unsigned, so the hash check is mandatory.
- Dart packages are checked for licences with very_good_cli, because cargo-deny does not see them.

## 10. Privacy and network gateway

Fixed by brief §1 and §3: no account, no telemetry, documents never leave the device ([ADR 0015](adr/0015-privacy-and-network.md)). The one exception is the optional AI assistant, off by default: with the user's own key for an online provider, the question and the passages of the open document needed to answer it go to that provider and nowhere else, and the setup (a10-2) says so first. A local model sends nothing.

### 10.1 The only network uses

| Use | In the brief | When it connects | Default | Milestone | What is sent |
|---|---|---|---|---|---|
| Update check | yes | once a day and on "Check now" | on; can be turned off (a11-1h, a11-1i) | M5 | version and platform, as a11-1h words it, in one request for a static, signed manifest per channel served from GitHub (Releases or Pages); the versions are compared on the device ([Q15](QUESTIONS.md#q15)) |
| Language-pack downloads | yes, optional | only when the user starts a download (a11-1f) | used only on request | P3 (OCR packs) | the name of the pack |
| AI | yes, optional | only when the user turns on the assistant with their own key, or downloads a local model | off | P4 | the user's question and the passages of the open document needed to answer it, to the provider the user chose and nowhere else (a10-2); a local model sends nothing |
| Signature timestamp servers | yes | only when signing with a timestamp | allowed in a11-1h, used only when signing | P3 | a hash (RFC 3161), never the document |
| Revocation lookups (OCSP and CRL) | no; added by the owner on 2026-10-16 ([Q06](QUESTIONS.md#q06)) | only when a signature is checked or made with "Signature checks" on | off until first use | P3 | a status request for the certificate (OCSP) or a fetch of its issuer's revocation list (CRL), never the document |

UI translations are bundled with the app, not downloaded ([G52](DESIGN_GAPS.md#g52)).

The design draws two uses the brief does not list, and the owner decided both on 2026-10-16 ([Q06](QUESTIONS.md#q06)). Certificate revocation lookups ("Signature checks" in a11-1h, [G51](DESIGN_GAPS.md#g51)) are allowed as a fifth use, the last row above: off until first use, with their own switch in Settings › Privacy and an entry in the network activity log. Local-network scanner discovery and phone pairing (a7-4, [G56](DESIGN_GAPS.md#g56)) are not built: Scan to PDF offers only the scanners the operating system provides, and pairing is reconsidered with the mobile apps in phase 5.

### 10.2 One gateway

- One module in ferman-api (`net`) is the only code with an HTTP client dependency. It arrives with the update check in M5. A CI check fails if any other crate depends on an HTTP client.
- Every request names a purpose. The gateway checks the user's switch for that purpose, refuses if it is off, and writes a local entry to the network activity log linked from Settings › Privacy (a11-1h): time, purpose, host, bytes. The log never leaves the device.
- Requests carry no cookies, no identifiers and no account. They use TLS with the OS trust store and the OS proxy settings. The user agent is `Ferman/<version> (<os>; <arch>)`: the version and platform that a11-1h discloses, and nothing else, as the owner settled for the update check on 2026-10-16 ([Q15](QUESTIONS.md#q15)).
- The Dart side adds no networking packages. **Approved by the owner on 2026-10-16** (Proposed until then): CI fails if `pubspec.lock` contains a package from a deny list (HTTP clients, font downloaders such as google_fonts, analytics and crash-reporting SDKs); it runs as the `pub_denylist` check in `tools/checks`.
- Onboarding lists the brief's four uses, as a1-2b draws them since export `519d42a` ([G24](DESIGN_GAPS.md#g24)); revocation lookups join the list when phase 3 builds them.
- OS-level checks the app does not control, such as code-signature checks by the OS, are outside this list.

## 11. Localization, RTL and fonts in the UI

Fixed by brief §1 and §6 ([ADR 0014](adr/0014-localization-and-rtl.md)).

### 11.1 Strings

- gen-l10n with ARB files in `app/lib/l10n/`. English is the source and Turkish is complete. Arabic is built in M1 to prove right-to-left. Other languages fall back to English until volunteers translate them through Weblate. Nothing is machine-translated silently.
- The language picker (a1-1) and Settings › Language and region list all 21 languages (`AppLanguage`, `app/lib/l10n/app_language.dart`). The 18 without a translation say "Not translated yet" and show English strings ([G20](DESIGN_GAPS.md#g20)); the direction still follows the language (section 11.4).
- The engine never produces UI text (section 3.1). Strings with numbers use ICU plural and select forms.

### 11.2 Locale-aware casing

Dart's `toUpperCase` is not locale-aware, so "imzala" would become "IMZALA" instead of "İMZALA".

**Decision: a small pure-Dart casing utility in `app/lib/l10n/`.** It wraps Dart's case mapping and applies the language-specific rules of Unicode SpecialCasing for Turkish and Azerbaijani: i ↔ İ, ı ↔ I, and the combining dot above. Reasons:

- Casing happens while widgets build. A synchronous FFI call on the build path would break the rule that the UI isolate makes no sync engine calls.
- Widget tests and goldens run without the native library. A Dart utility works there; a bridge call does not.
- The rule set the 21 UI languages need is small and stable. The design uses sentence case, so title-casing rules (such as Dutch IJ) are not needed.
- It works unchanged in the web build later.

Built in M1 as `LocaleCasing` (`app/lib/l10n/casing.dart`): `upper`, `lower` and `capitalize` (sentence case), chosen by the UI locale with `LocaleCasing.of(context)`. It implements Unicode 15.0 full case mapping with every SpecialCasing rule: the unconditional full mappings and Final_Sigma for every language, Turkish and Azerbaijani (i ↔ İ, ı ↔ I, I + U+0307 → i) and Lithuanian (the dot above i and j). The Dart VM's `toUpperCase` applies only simple mappings from tables older than Unicode 7 ("ß" stays "ß"), so the utility carries the full mappings and the 829 missing simple mappings itself and every platform gives the same result. Greek accent removal (`el`), Dutch "IJ" and Armenian "և" are CLDR tailorings outside SpecialCasing and are not implemented. When written it matched ICU4C 74.2 for every code point and for 30,000 random context strings per locale; a 160-string ICU fixture stays in the tests until the ICU4X table test (M2). The scripts that generated its tables are not in the repository yet ([BACKLOG.md](BACKLOG.md)).

ICU4X stays in the engine (`icu_casemap` for search folding, `icu_collator` for sorting), where document text is processed. A test generates a table of cases with ICU4X and checks the Dart utility against it, so both agree. Locale-aware sorting of lists (recents, fonts) calls the engine's collator asynchronously; it is not on any per-frame path.

### 11.3 Numbers, dates and units

- Numbers, dates, paper sizes and units come from the **region setting** (a11-1b), never from the UI language ([G34](DESIGN_GAPS.md#g34)). With the Türkiye region an English UI shows "13.10.2026 · 14:32", "18.500,50" and "10,5 pt".
- The region setting is `Region` (`app/lib/l10n/region.dart`): an ISO 3166-1 code and one intl locale for its formats. The setting offers 45 regions whose numeric dates, times and numbers match CLDR 48 (exceptions in the `Region` doc); another OS country is built from the OS language. The default comes from the OS locale: its country, with the OS language's own intl locale for that country when intl has one (fr_CA, en_IN), else CLDR's likely country for the language, else the United States.
- The region picker (a11-1b) lists those 45 regions, plus the system's region and the chosen one when they are not among them. Each shows its CLDR name in the UI language, then the region's own name in parentheses when the two differ: "Türkiye", "Germany (Deutschland)", and in Arabic "تركيا (Türkiye)" as a12-2c draws it ([G91](DESIGN_GAPS.md#g91)). The list is sorted in the UI language's alphabetical order. The names and the order are a CLDR 48 table in `app/lib/l10n/region_names.dart` (read through ICU 78.3 in Node.js 24.22.0, with English, Turkish and Arabic names for 257 territories); other UI languages take the English names and order, as their UI does. A precomputed order is used because the engine's collator (section 11.2) arrives in M2. The script that generated the table is not in the repository yet ([BACKLOG.md](BACKLOG.md) B092). The system's region is always offered, and choosing it stores no region, so the formats follow the system again.
- The digit system follows the region's CLDR numbering system: Arabic-Indic for Saudi Arabia and Egypt (a12-1ar, a12-2a), Persian for Iran, Latin for the United Arab Emirates and elsewhere. Iran keeps the Gregorian calendar (intl has no Solar Hijri calendar).
- Paper size, length unit and first day of the week default from CLDR territory data (Letter in the 14 US-Letter countries, inches only in the United States and Liberia, first day from CLDR 48 `weekData`); each can be changed in a11-1b.
- `RegionFormat` (`app/lib/l10n/format.dart`) formats numeric dates (CLDR `yMd`), times (`jm`), integers, decimals, font sizes ("10,5 pt"), lengths and paper sizes ("210 × 297 mm"), decimal file sizes ("24,6 MB") and percentages (`percent`: "%40" for Türkiye, "40%" for the United States, "40 %" with U+00A0 for Germany, "٤٠٪؜" for Saudi Arabia, the sign and its place as CLDR writes them for the region, grouped like other numbers: "%6.400" in Türkiye, "6400 %" in Spain); a unit follows its number after U+00A0 and unit symbols are international. It applies CLDR's `minimumGroupingDigits`, which intl ignores ("1500" but "15.000" in Spain). `bootstrap()` calls `initializeRegionFormats()` before `setUpWindow()` and `runApp`, because flutter_localizations would otherwise load only its own locales (it has no ar_EG). flutter_localizations still replaces the date symbols of its own locales when its delegates load, so `RegionFormat` takes the digits from the region's number symbols and fixes the date-time pattern where the two data sets disagree; tests cover both load orders. The zoom level in the status bar, the zoom steps of the View tool row and the "100%" zoom option in Settings › General use `percent` ([G34](DESIGN_GAPS.md#g34), [G74](DESIGN_GAPS.md#g74)).
- The engine returns raw numbers (points, bytes, counts). Dart formats them with intl using the region locale.
- Formatted values are isolated with `bidiIsolate` (format.dart): U+2068 FIRST STRONG ISOLATE before the value and U+2069 POP DIRECTIONAL ISOLATE after it, so the value keeps its own order inside text of the other direction (a12-2c). It is needed when a value sits inside a longer right-to-left string, and also when it stands alone in a `Text` under a right-to-left `Directionality`, which would otherwise show "pt 10,5". M1 isolates the region examples in Settings › Language and region, the zoom percentages (status bar, zoom steps, Settings › General) and the status bar's saved time, so "2:32 PM" keeps its order in Arabic. `RegionFormat` adds no direction marks of its own beyond CLDR's (U+200F after the day and month of the Arabic date; U+061C after the Arabic percent sign for Saudi Arabia; U+200E around the percent sign for the Emirates).

### 11.4 Right to left

- **The direction follows the chosen language, not the locale of the strings.** `appLanguageProvider` (`app/lib/l10n/locale_providers.dart`) is the app language: the stored choice, else the first of the system's preferred languages that is one of the 21, else English. `appLocaleProvider` gives `MaterialApp.locale` that language's `uiLocale`: its own locale for English, Turkish and Arabic, and English for the 18 languages without a translation ([G20](DESIGN_GAPS.md#g20)). It is always one of `AppLocalizations.supportedLocales`, so the framework's fallback to the first supported locale (Arabic) never applies. `FermanApp` (`app/lib/app/app.dart`) reads `AppLanguage.textDirection` (right to left for ar, fa and he, `app/lib/l10n/app_language.dart`), and its `MaterialApp.router` builder wraps the router (the builder's child) in a `Directionality` with that direction. The builder runs below the framework's `Localizations`, which sets the direction of the string locale, and above the router. So every route, the title bar and the modals and popups of the root Overlay take the language's direction.
- Persian and Hebrew need this override. They have no ARB file, so their locale resolves to English, and `Localizations` alone would keep the UI left to right. With it they mirror the UI at once, with English strings, as G20 decides ([G93](DESIGN_GAPS.md#g93)).
- An English string in a right-to-left paragraph reorders: "1 of 2" would read "of 2 1", and "Open file…" "…Open file". So while the chosen language is right to left and has no translation (`AppLanguage.isolatesFallbackStrings`: Persian and Hebrew), `FermanApp` gives `MaterialApp` the localization delegates of `IsolatedFallbackLocalizations` (generated by tools/l10n) first. `Localizations` loads the first delegate of each type, so that class replaces `AppLocalizations.delegate`, and every string comes wrapped in U+2066 LEFT-TO-RIGHT ISOLATE and U+2069 POP DIRECTIONAL ISOLATE: it keeps its own order and sits at the start of its line. The swap happens inside the one app-level `Localizations`, so choosing or leaving Persian or Hebrew reloads the strings in place and keeps every route's state; a nested `Localizations.override` would bring its own `Directionality` from the English locale. A language's own name inside a string keeps its script's direction. English, Turkish, Arabic and the left-to-right languages get no isolates. Tests: `app/test/l10n/isolated_fallback_test.dart`. For English, Turkish and Arabic the two directions agree; German and the other left-to-right languages stay left to right. Tests: `app/test/app/app_test.dart` (Persian and Hebrew chosen or from the system, German, Arabic), `app/test/features/onboarding/onboarding_test.dart` (choosing فارسی or עברית in first run) and `app/test/features/settings/settings_screen_test.dart` (choosing فارسی in Settings).
- `EdgeInsetsDirectional` and `AlignmentDirectional` everywhere. Directional icons (chevrons, arrows, undo and redo) mirror. The list of icons to flip comes from the design.
- **The PDF canvas is never mirrored.** Page content, page order in spreads (from the document's direction, G32) and on-page marks stay as the document defines them. The frame label starts on the document block's own start side (f1). Grid and thumbnail reading order follows the UI direction, but thumbnail content is never mirrored.

### 11.5 Fonts in the UI

Bundled: IBM's unmodified static TTFs under OFL-1.1, with the Reserved Font Name "Plex" respected: never subset, renamed or modified ([ADR 0013](adr/0013-fonts-and-icons.md), [G06](DESIGN_GAPS.md#g06)). The families are Plex Sans, Serif, Mono, Sans Arabic, Sans Hebrew and Sans Devanagari. CJK uses system fonts, with no font packs ([Q08](QUESTIONS.md#q08), groups 1 and 2). Handwriting faces for typed signatures (Caveat, Dancing Script and Homemade Apple, M4) and similar fonts for missing glyphs (Cormorant Garamond and Crimson Pro, M3) are bundled too, as unmodified upstream files with their licences (Q08 groups 3 and 4, 2026-10-16); they are document fonts, not UI fonts. The design's woff2 subsets and its runtime Google Fonts import are never used ([G07](DESIGN_GAPS.md#g07)).

| UI language | First font | Fallback chain |
|---|---|---|
| Latin and Cyrillic (en, tr, de, fr, es, pt-BR, it, nl, pl, ru, uk, id, vi) | IBM Plex Sans 400/500/600 | IBM Plex Sans Arabic → IBM Plex Sans Hebrew → IBM Plex Sans Devanagari → system |
| ar, fa | IBM Plex Sans (the `--font-ui` order, as the 12 Localization boards draw ar; [G64](DESIGN_GAPS.md#g64)) | IBM Plex Sans Arabic → IBM Plex Sans Hebrew → IBM Plex Sans Devanagari → system |
| he | IBM Plex Sans (the `--font-ui` order; Plex Sans Hebrew bundled: owner, [Q08](QUESTIONS.md#q08), 2026-10-15) | IBM Plex Sans Arabic → IBM Plex Sans Hebrew → IBM Plex Sans Devanagari → system |
| hi | IBM Plex Sans (the `--font-ui` order; Plex Sans Devanagari bundled: owner, Q08, 2026-10-15) | IBM Plex Sans Arabic → IBM Plex Sans Hebrew → IBM Plex Sans Devanagari → system |
| ja | IBM Plex Sans for Latin | Hiragino Sans (macOS), Yu Gothic UI (Windows), Noto Sans CJK JP (Linux) |
| ko | IBM Plex Sans for Latin | Apple SD Gothic Neo, Malgun Gothic, Noto Sans CJK KR |
| zh-Hans | IBM Plex Sans for Latin | PingFang SC, Microsoft YaHei UI, Noto Sans CJK SC |
| zh-Hant | IBM Plex Sans for Latin | PingFang TC, Microsoft JhengHei UI, Noto Sans CJK TC |

- No script font is first in a chain. Plex Sans Arabic, Hebrew and Devanagari carry full ASCII and the Latin-1 letters but not Latin Extended-A (only one of İ ı Ğ ğ Ş ş) or ế, and they do carry I, s, ê and the combining marks U+0307, U+0327 and U+0301 (checked by `tools/fonts/coverage.py`). With one of them first, Flutter draws İ, ş and ế from it as base plus mark instead of falling back to Plex Sans: Plex Sans Devanagari misplaces all three marks, and Plex Sans Arabic and Hebrew place İ and ş correctly but set the acute of ế beside the circumflex (script-coverage golden, 2026-10-15). With Plex Sans first, Arabic, Persian, Hebrew and Devanagari text renders pixel-identically to the script font first (checked at 11 to 40 px, with digits and punctuation); a wrapped line that holds only digits and punctuation then takes Plex Sans's line metrics, as in the browser. The design's `--font-arabic` stack (Plex Sans Arabic first) appears once, on a mock document page in 03c, and is not used for UI text ([G64](DESIGN_GAPS.md#g64)).
- Every chain is built by `FermanFontFamilies.uiChain` (`app/lib/design/theme/typography.dart`) from the generated `--font-ui` stack. For CJK the system families of the language come right after IBM Plex Sans and the rest of `--font-ui` follows them. Flutter cannot switch synthetic bold off as the design's `font-synthesis: none` asks; naming the system families picks real bold faces where the system has them ([G65](DESIGN_GAPS.md#g65)).
- The text locale is set on every text style, so Han characters take the right regional forms (Traditional Chinese must not show Simplified forms, G07).
- IBM Plex Mono is used for technical details (a1-9b). IBM Plex Serif is bundled for the design's specimens and as a similar-font candidate.
- UI fonts never affect page rendering. PDF pages are drawn by PDFium with the document's own fonts.

## 12. Platform integration

Desktop first: macOS and Windows, Linux best effort (brief §1).

- **Supported systems** ([Q03](QUESTIONS.md#q03), answered on 2026-10-15). macOS 12 Monterey or later, one universal build (arm64 and x86_64), deployment target 12.0. Windows 10 22H2 and Windows 11, on x64 and arm64. Linux best effort on glibc-based distributions from Ubuntu 22.04 on; CI also builds on Ubuntu 22.04 to prove the floor. These minimums decide which OS APIs below can be used without fallbacks. The bundle identifier is `io.github.kerembas.ferman` on every platform ([Q01](QUESTIONS.md#q01)).
- **Window chrome.** window_manager hides the native title bar. Ferman draws the title bar as designed: macOS traffic lights in place, Windows caption buttons per f6. On Windows 11, custom caption buttons lose the snap-layout flyout unless the maximize button area is reported to the OS; this needs a small native hook (risk, section 15). Linux gets a custom title bar too, as the owner decided ([Q12](QUESTIONS.md#q12), [G15](DESIGN_GAPS.md#g15)): client-side decorations drawn by Ferman, caption buttons at the end, Ctrl shortcuts and Cancel on the left in dialogs; the window drags and resizes from the drawn areas. Built in M1 phase H1:
  - `bootstrap()` starts a `WindowManagerDesktopWindow` (`app/lib/app/desktop_window.dart`) on the desktop, which calls window_manager's `setTitleBarStyle(hidden)` and follows maximize and full screen; `desktopWindowProvider` holds it, and the web and mobile get a `NoDesktopWindow` (no title bar of Ferman's own). Every route sits in a go_router `ShellRoute` whose `WindowFrame` (`app/lib/app/window_frame.dart`) puts the `TitleBar` above the screen, so a modal in the root Overlay covers the title bar too (see **Modals over the title bar** below).
  - The title bar is `--titlebar-h` (38) on `--surface-sunken` with a 1 px `--border-subtle` line, the `WindowChrome` component at the start (macOS slot) or end (Windows and Linux caption buttons), and the screen's content between them. On the start screen that is the home header of a1-5: the "Ferman" tab, no document tabs before M2, "+" and Search disabled with the future-version tooltip, and Settings. In the shell it is the house button, the document tabs with "+N" and "+" (both disabled until M2), Search (disabled until the command palette, M4) and Settings. First run and Settings keep the bare bar their boards draw (`app/lib/app/router.dart`, [G88](DESIGN_GAPS.md#g88)). Its empty space moves the window (`startDragging`) once a pressed pointer moves; a trackpad's two-finger scroll or pinch never moves it, and controls in it keep their own clicks. The empty space is left out of the semantics tree. A double-click is counted from the presses with the system's double-click interval and distance, which every runner reports (`doubleClickSettings`: `NSEvent.doubleClickInterval` on macOS; `GetDoubleClickTime` and `SM_CXDOUBLECLK` on Windows; `gtk-double-click-time` and `gtk-double-click-distance` on Linux; Flutter's double-tap values where none answers). It does what the system does: on macOS the runner reads "Double-click a window's title bar to" (`AppleActionOnDoubleClick`: zoom, minimize or nothing); on Windows and Linux it maximizes or restores ([G66](DESIGN_GAPS.md#g66)).
  - The `ferman/window` channel (`PlatformWindowChannel`) carries what window_manager lacks. macOS (`MainFlutterWindow.swift`): the window takes the hidden-title-bar shape in `awakeFromNib`, before it first shows, so the system title bar never flashes at launch; `setTrafficLightLayout` resizes the system's title-bar container to the bar's height above its line (37 pt) and places the close, minimize and zoom buttons as the design draws its lights (12 pt, 8 pt apart, 14 pt from the leading edge; at the right edge in right to left; on whole device pixels), again after every resize, key and main change, appearance change and full-screen or Dock transition; `titleBarDoubleClicked` applies the system setting. Windows (`title_bar.cpp`): `setMaximizeButtonRect` gets the maximize button's rectangle (WindowChrome reports it after every frame in which it moved); the Flutter view answers that area as `HTTRANSPARENT` and the top-level window as `HTMAXBUTTON`, so Windows 11 shows its snap layouts, and the runner reports hover and press back (`maximizeButtonState`) and maximizes or restores on release. Because window_manager's hidden style removes the system's top frame, the runner also answers the top strip of the window (the system resize-frame height at the window's DPI) as `HTTOP`, `HTTOPLEFT` and `HTTOPRIGHT` while the window is resizable and not maximized. Linux (`my_application.cc`): the window always has a GTK header bar, which window_manager hides, so GTK keeps the client-side frame (shadow and resize edges); the runner answers `doubleClickSettings` on the `ferman/window` channel and reports the other calls as not implemented.
  - Widget tests cover the bar on the three systems (`app/test/app/window_frame_test.dart`, with `FakeDesktopWindow`) and the window controller against window_manager's channel (`desktop_window_test.dart`); the integration test checks that the built app starts with its title bar (Linux in the development container). The native behaviour (light placement, snap layouts, the top edge, the double-click setting) is a [pending owner check](PROGRESS.md#pending-owner-checks) on R1 and R2.
- **Narrow windows** (M1 phase H6, [G95](DESIGN_GAPS.md#g95)). `bootstrap()` calls `applyWindowLimits`, which sets the window's minimum size through `DesktopWindow.setMinimumSize` (window_manager's `setMinimumSize`): 1024 × 640 px (`WindowMetrics.minimumWidth`, approved by the owner on 2026-10-16, and `minimumHeight`). Below the width the shell needs, it gives way in a fixed order, driven by the width it is given and never by the platform: the tool rows hide labels and then move tools into "More tools" (`Toolbar`), the mode tabs fall back to icons, and a side panel steps aside once the canvas would drop below `WindowMetrics.canvasMinWidth` (640 px, approved by the owner on 2026-10-17), the right panel first. `ShellPanels` (`app/lib/features/shell/shell_state.dart`) resolves what is visible from the open state, the user's last choice and the width; the title-bar toggles and their shortcuts follow it. The canvas runs its subtree left to right in every UI direction (ADR 0014).
- **Window commands** (M1 phases H and I). The window's own keys come from the one shortcut table (`ShellCommand` in `app/lib/features/shell/shortcuts.dart`, its `windowCommands`): ⌘M and ⌘Q on macOS, Alt+F4 on Windows and Linux, and Ctrl+Q on Linux ([G83](DESIGN_GAPS.md#g83)). `WindowFrame` binds them on every route through `WindowCommandScope` (`app/lib/features/shell/shell_commands.dart`), with an intent type of its own. Minimize minimizes the window; close and quit close it, as the caption buttons do. Closing the one window ends the app (on macOS `applicationShouldTerminateAfterLastWindowClosed` returns true); asking about unsaved documents first comes with saving in M3 ([section 5.7](#57-close-and-quit), [G40](DESIGN_GAPS.md#g40)). Nothing is bound where the system draws the window. The table's other window-wide keys are bound by `ShellCommandScope` around the title-bar content and the screen, on the start screen and in the shell; it leaves the window commands out. On the start screen only Settings (⌘, or Ctrl+,) and Open (⌘O or Ctrl+O, M2) work. Settings binds Esc and the table's `closeDocument` keys to close itself. Tests: `app/test/app/window_frame_test.dart` (group "WindowFrame") and `app/test/features/shell/shell_route_test.dart` (the window keys on the start screen, first run and Settings).
- **Modals over the title bar.** Ferman's modal `Dialog` and `CommandPalette` (`app/lib/design/components/overlays/`) show in the root `Overlay` through an `OverlayPortal` at `OverlayChildLocation.rootOverlay`, never as Material routes. The root Overlay belongs to the root navigator, which holds the `ShellRoute` page with `WindowFrame`, so their scrim covers the title bar too, wherever the modal sits in the tree.
  - The modal layer has an overlay of its own (`Overlay.wrap`). Tooltips, popovers and menus inside a dialog, and the reason tooltips of the palette, open in it, above the box, even when the modal sits under a nested navigator.
  - While a modal shows, it holds a handle from `ModalScope` (`app/lib/design/components/foundation/modal_scope.dart`), a count of the open modals; the surface closes the handle when it hides or goes away. A change made while a frame is built, laid out or painted reaches the listeners after that frame.
  - A modal shows only while its route is the current one and its tickers run (`ModalRoute.isCurrentOf` and `TickerMode`). Under a route pushed above its own, such as Settings pushed over a screen with an open dialog, it hides: it stays in the root Overlay and keeps its state (the palette keeps its query), but it is not painted, hit tested or read, its tickers stop, it stops counting in `ModalScope`, and focus stays with the route above. When that route goes, it shows again, counts again and takes focus inside it (in the palette, the search field). A modal opened while such a route covers its own waits for that route to go. Closing a modal while it is hidden leaves focus alone; closing it while it shows gives focus back to where it was when it first opened.
  - The title bar (`_TitleBarState` in `window_frame.dart`) listens to `ModalScope.openCount`. On Windows, when a modal opens, it withdraws the maximize button's rectangle (`setMaximizeButtonRect(null)`) and stops reporting it. The runner then answers neither that area as `HTMAXBUTTON` nor the top strip over the bar as `HTTOP`: the snap-layout area and the top resize edge go back to Flutter, and the scrim takes the pointer there as everywhere else. When the last modal closes, the button reports its rectangle again.
  - Tests: `app/test/design/components/overlays/dialog_test.dart` (popups under a nested navigator, a route pushed above, closing while hidden, opening under a route above), `command_palette_test.dart` (the reason tooltip under a nested navigator, a route pushed above) and `window_frame_test.dart` ("gives the snap-layout area back while a modal is open").
- **Routes** (`app/lib/app/router.dart`, M1 phases H and I). One `ShellRoute` holds every screen in `WindowFrame`: `/` the start screen, `/welcome` first run (a1-1, a1-2b, a1-2c), `/settings` and `/settings/<pane>` Settings, `/editor` the editor shell with the open documents (M2: opening from the start screen goes there), `/debug/shell` the same shell, kept for the M1 placeholder documents, and `/debug/gallery` the component gallery: every component of the library with its variants, sizes and forced states, previewed in light, dark or dim, standard or touch density, reduced motion, either direction and en, tr or ar without changing the app's own settings (`app/lib/features/gallery/`). Modes, document tabs and sidebar tabs are state, not routes. Until first run is done (`AppSettings.onboardingCompleted`), the redirect sends `/` to `/welcome`; once it is done, it sends `/welcome` to `/`. The redirect reads the settings without watching them, so a change never rebuilds the router; finishing first run goes to `/` itself. An unknown location (a web address, a mistyped path) goes to `/` through `onException`, and so through the redirect: first run until it is done, the start screen after. No undesigned error page with untranslated text appears. Tests: `app/test/app/app_test.dart` (the first-run redirect and the group "an unknown location").
- **macOS App Sandbox.** Flutter's macOS template turns on the App Sandbox entitlement, and M1 kept it on. Under it, Ferman reaches only its container and the files the user grants (open and save panels, drag and drop, "Open with"); recent files need security-scoped bookmarks, and the atomic save of section 7.2 uses the system's replacement directory. The owner answered [Q18](QUESTIONS.md#q18) on 2026-10-16: the sandbox stays on in every macOS build if M2 shows that both work under it; otherwise the Developer ID build (DMG and Homebrew) drops it and keeps the hardened runtime, with the reason recorded. **Proposed** with the M2 plan ([ADR 0021](adr/0021-open-from-the-os.md)): both entitlement files gain `files.user-selected.read-write` and `files.bookmarks.app-scope`; M2 builds the bookmarks for recent files and the replacement-directory write for "Save attachment as…"; CI proves them on paths inside the container, and the owner on files granted through the panel, before the decision at the M2 review.
- **File associations and "Open with".** macOS declares PDF in `Info.plist` and receives open events from the OS, routed to Dart through a method channel. Windows registers a ProgID in the installer (M5) and receives the path on the command line. The file opens as a new active tab, or focuses its tab if it is already open, and a cold launch with a file skips Start, as a1-13's note says ([G25](DESIGN_GAPS.md#g25)). **Proposed** with the M2 plan ([ADR 0021](adr/0021-open-from-the-os.md)): a second launch forwards its paths to the running instance through each platform's own mechanism, a named mutex and a named pipe per user on Windows, GApplication's D-Bus uniqueness on Linux (instead of the Unix socket this section named before; without a session bus each launch is its own instance), while macOS routes it to the running app itself; macOS declares `com.adobe.pdf` with the rank Alternate. Built in W3: every request reaches Dart over the `ferman/open` channel (`PlatformOpenRequests` in `app/lib/platform/open_requests.dart`, `openRequestsProvider`). The runners keep what the system asks for until Dart calls `ready`, which answers with the paths kept so far, and from then on call `open` with each request's paths. macOS (`MainFlutterWindow.swift`) takes `application(_:open:)` through `FlutterAppDelegate`'s lifecycle delegates (`handleOpen`), with `CFBundleDocumentTypes` for `com.adobe.pdf` (role Editor, rank Alternate). Windows (`open_requests.cpp`) makes the command line's paths absolute; the launch that owns the mutex `Local\io.github.kerembas.ferman-<user SID>` serves the pipe `\\.\pipe\io.github.kerembas.ferman-<user SID>-<session>` on a thread of its own, with a DACL that admits only the user's SID, and posts each request to the window (`OpenRequestMessage`, a registered window message), which comes forward. A later launch opens the pipe at identification level, checks that the server runs as the same user, sends its paths (a 4-byte length, then NUL-separated UTF-8, waiting up to 5 s for the pipe), lets the first take the foreground, and exits once the first answers that its window took them; otherwise it runs on its own and takes over the mutex and the pipe when the first has gone. Linux (`my_application.cc`) sets `G_APPLICATION_HANDLES_OPEN` instead of `G_APPLICATION_NON_UNIQUE`; `local_command_line` makes the paths absolute (`g_file_new_for_commandline_arg`) and skips names that are not UTF-8, which the channel and Dart cannot carry, and a remote instance forwards them with `g_application_open` (or activates the first one when it has none); the first one's `open` handler presents the window (once its first frame has shown it) and sends the paths. Debug builds use their own names (`io.github.kerembas.ferman.debug` on Linux, `.debug` on the Windows mutex and pipe), so `flutter run` and the integration test never forward to an installed Ferman; a profile or release build, such as the `flutter drive --profile` timing run, does, so close Ferman first. The command line's paths reach Dart as `main`'s arguments. `FermanApp` opens the launch's files before the first frame shows (`deferFirstFrame`, for at most 500 ms; a slower file opens in the editor once it lands), so a cold launch with a file skips Start, then each later request as it comes; finishing first run shows the editor when files arrived meanwhile. `DocumentOpener.open` keeps the engine opens under way by path: a file asked for while it opens waits for that open and shows its tab, and different files do not wait for each other. macOS also brings a minimized window back. The integration test checks that each runner answers `ready`.
- **Default PDF app** (a1-3, M2). macOS asks the system to make Ferman the default handler, and the system asks the user to confirm. Windows opens Settings › Default apps, because apps cannot change the default themselves. Until the system lookup exists, Settings › General says what the button does and keeps it disabled, as a11-1-m1 and a11-1w-m1 draw it ([G89](DESIGN_GAPS.md#g89)). **Proposed** with the M2 plan ([G103](DESIGN_GAPS.md#g103)): on Windows the button opens Settings › Default apps only once Ferman is registered for PDF files, which the M5 installer does; on Linux it stays disabled until packaging (M5); the first-run prompt a1-3 shows only where the button can act.
- **Drag and drop.** desktop_drop on the start screen and in the document window (a1-6). desktop_drop depends on MPL-2.0 `dbus` on every platform; the owner approved that exception on 2026-10-15 ([Q17](QUESTIONS.md#q17)), so desktop_drop is added in M2 with the `dbus` notice in every build. **Proposed** with the M2 plan ([G105](DESIGN_GAPS.md#g105)): in M2 the start screen (the whole window) and a document window (its canvas and its tab strip) take drops, and each PDF opens in a new tab; a1-6's "Combine into one PDF" target stays visible and disabled until M4, and a drop on the page grid inserts pages with Organize in M4. Until conversion exists (P3), a file that isn't a PDF opens as a1-9c's error tab ([G11](DESIGN_GAPS.md#g11), [G28](DESIGN_GAPS.md#g28)); until the error tabs (B115) it is reported after the drop as [G116](DESIGN_GAPS.md#g116) says. The note "Can't open yet" while it is dragged is dropped: the files are named only on the drop ([G117](DESIGN_GAPS.md#g117)). Built in W3: `FileDrop` (`app/lib/features/shell/file_drop.dart`) wraps the title bar and the screen in `WindowFrame`; the router sets `takesFiles` for the start screen and the editor, so first run and Settings take none, and no screen takes drops while opening is disabled. While files are dragged it shows a1-6's overlay over the screen below the title bar, without a count or a row per file, since desktop_drop names the files only on the drop ([G117](DESIGN_GAPS.md#g117)); a drop goes to `DocumentOpener.open`. The `dbus` licence text ships through Flutter's collected notices and its source location as a licence entry (`assets/licenses/dbus/SOURCE.txt`).
- **File pickers.** OS-native open, save and folder pickers through file_selector: NSOpenPanel and NSSavePanel, IFileOpenDialog and IFileSaveDialog, xdg-desktop-portal on Linux. This is the only exception to the custom-dialog rule: [ADR 0018](adr/0018-native-file-pickers.md), Accepted on 2026-10-16 ([Q07](QUESTIONS.md#q07)). Every other dialog is a Ferman component. M1 built no picker. M2 builds the open picker: ⌘O (Ctrl+O), "Open file…" and "Open a PDF" hand off to the system open panel for PDF files, several at once, each opening as a new active tab (a1-13); a1-9e's "Locate…" uses it too. M2 also uses the save panel for "Save attachment as…" (a2-3b). M3 builds the a1-11 sheet's hand-off to the save panel for "Other location…" (a1-11b), and the folder picker comes with the milestone that needs one ([G25](DESIGN_GAPS.md#g25), [G26](DESIGN_GAPS.md#g26)).
- **Recent files.** **Proposed** with the M2 plan ([ADR 0021](adr/0021-open-from-the-os.md)): a Dart `RecentFilesStore` in the app support directory, beside `settings.json` and written the same way (versioned JSON, a temp file, a flush and a rename). An entry holds the path, the display name, the last-opened time, the pin and, on macOS, a security-scoped bookmark; never document text. The engine supplies what Dart cannot: locale-aware sorting through `sort_keys` and thumbnails rendered at background priority, kept in the app cache directory and never made for a file that needs a password ([G109](DESIGN_GAPS.md#g109)). A missing file offers "Locate…" and "Remove from list" (a1-9e).
- **Printing.** Basic system print comes in M4 ([Q10](QUESTIONS.md#q10), accepted on 2026-10-16): Ferman hands the document to the OS print dialog, with "Use system dialog…" one click away (a9-6). Booklet, poster and separations come in P5. The package is chosen and licence-checked in M4.
- **PDFium loading.** The engine configuration names the library (`EngineConfig { pdfium: PdfiumLibrary::Find | Path(path) | Disabled }`; `ferman info --pdfium <path>`). `Find` takes the file named by `FERMAN_PDFIUM_PATH` if it is set, otherwise the bundled location below if that file exists: `<exe dir>/lib/libpdfium.so` on Linux, `<exe dir>/pdfium.dll` on Windows, `<exe dir>/../Frameworks/libpdfium.dylib` on macOS. A relative path is made absolute first, so the dynamic loader never searches its library path. The render thread binds the library and then proves it works with a real call (create an empty document, count its pages, close it). pdfium-render's bindings are process-wide and never unbound, so a process binds one file: a later render thread reuses it for the same file and reports a failure for another. `engine_info()` reports `{"state": "loaded", "tag": "chromium/7881"}` only after that call succeeds; `not_loaded` when no library was found or configured; `failed` with a technical `reason` when a library was found or named but did not bind or did not work. The reason never contains the library path (it is replaced by `<pdfium library>`; the local log keeps it). PDFium has no runtime version API, so the tag is the pin recorded with `tools/pdfium` (a ferman-render test compares the two), not a version read from the library. `FERMAN_PDFIUM_PATH` is honoured in every build, release included (development, CI and the Rust tests use it): it lets packagers and developers point the app at another PDFium build, and anyone who can set a process's environment can already run code as the user.
- **PDFium bundling.** Built in M1 phase E4 (`3e7bf8e`); the build takes the library that `tools/pdfium/fetch.sh` unpacked into `build/pdfium/<id>/`, so a desktop build needs `bash tools/pdfium/fetch.sh --platform <id>` first.
  - macOS: `libpdfium.dylib` (arm64 and x64 combined into one universal file) in `Contents/Frameworks`: the Runner target's existing "Bundle Framework" copy phase copies `../../build/pdfium/mac-univ/lib/libpdfium.dylib` with `CodeSignOnCopy`. From M5 it is signed with the app's Developer ID under the hardened runtime and notarized with the app.
  - Windows: `pdfium.dll` (x64, arm64) next to `ferman.exe`, installed by `app/windows/CMakeLists.txt` from `build/pdfium/<win-x64|win-arm64>/bin/`. From M5 it is Authenticode-signed with the app, so security tools do not flag an unsigned third-party binary.
  - Linux: `libpdfium.so` (x64, arm64) in the bundle's `lib/` folder next to `libferman_api.so`, installed by `app/linux/CMakeLists.txt` from `build/pdfium/<linux-x64|linux-arm64>/lib/`. ferman-api loads it by absolute path, so no run path is involved.
  - Both CMake files pick the platform from `FLUTTER_TARGET_PLATFORM` and stop at configure time with "PDFium is missing … run bash tools/pdfium/fetch.sh --platform <id>" when the file is absent, so no build ships without it. CI fetches the library (cached) before every desktop build; the Ubuntu 22.04 job checks that the bundle holds `libferman_api.so` and `libpdfium.so`, and that the release `libferman_api.so` exports `frb_get_rust_content_hash` (`nm -D`); the integration test asserts `PdfiumState.loaded` with the tag `chromium/7881`. Verified on Linux x64 in the development container (the release bundle's `lib/libpdfium.so` is byte-identical to the pinned library, and the integration test passes), and CI run [38823480726](https://github.com/KEREM-BAS/Ferman/actions/runs/38823480726) (head `52603cb`) passed the integration test with PDFium loaded on the three systems.
  - The archive's `licenses/` folder (including `licenses/pdfium.txt`) and the packager's MIT `LICENSE` ship with the app and appear in the third-party notices ([G14](DESIGN_GAPS.md#g14)). If the library is missing, Ferman shows an error screen instead of crashing.
- **Code signing** (M5) uses one publisher name on both platforms ([Q02](QUESTIONS.md#q02), 2026-10-16): an individual Apple Developer Program membership unless an organisation exists, and on Windows Azure Trusted Signing or an organisation-validated certificate in the same name if available, SignPath Foundation otherwise. Development and CI builds stay unsigned until then.
- **Settings window** (decided in M1 step 9). a11-1 draws Settings as its own window: its note says "Settings open in their own window (⌘,)", and FmSettings draws it in a bare FmWindow. Flutter 3.47.7 has no stable desktop multi-window support. Checked in the pinned SDK: the window controllers (`RegularWindowController`, `DialogWindowController` and others) are in `packages/flutter/lib/src/widgets/_window.dart`, which `package:flutter/widgets.dart` does not export. The file's header says not to import it in production apps, because Flutter will make breaking changes to it "even in patch versions". It requires every API in the file to be private or `@internal` (most are) and to throw `UnsupportedError` unless the build's `windowing` feature flag is on. The flutter tool offers that flag only on the master channel (`windowingFeature` in `packages/flutter_tools/lib/src/features.dart`).
  - So in M1 Settings is a window-styled surface inside the main window: the route `/settings` or `/settings/<pane>` (`general`, `language`, `privacy`; any other pane opens General), under the main window's bare title bar. It is pushed over the screen it was opened from: the title bar's Settings button or ⌘, (Ctrl+, on Windows and Linux) on the start screen and in the shell, and the privacy step's link to `/settings/privacy` on first run.
  - The caption buttons there close the whole app, so the surface has its own "Close settings" button at its top end, and Esc and ⌘W (Ctrl+W on Windows and Linux, the shortcut table's `closeDocument` keys) close it too. Closing returns to the screen below, or to the start screen when Settings was opened directly. Settings takes focus when it opens, so Esc works at once. A modal open on the screen below hides while Settings is above it (see **Modals over the title bar**).
  - Real windows follow once Flutter's multi-window support is stable ([BACKLOG.md](BACKLOG.md) B090). The close button, Esc and ⌘W, which the boards do not draw, are recorded in [G89](DESIGN_GAPS.md#g89); the window keys in [G83](DESIGN_GAPS.md#g83).
- **Settings storage** (decided in M1 step 9, as [ADR 0011](adr/0011-flutter-state-navigation-components.md) asks). `AppSettings` (theme, app language, region and its paper-size, unit and first-day overrides, first run done) is stored by `FileSettingsStore` (`app/lib/settings/`) as versioned JSON in `settings.json` in the app support directory that path_provider reports (inside the container while the macOS App Sandbox is on, [Q18](QUESTIONS.md#q18)). Each save writes `settings.json.tmp`, flushes it and renames it over the file, one save at a time; an unreadable file is moved aside to `settings.json.unreadable` and the defaults are used, so the app always starts; keys and a newer format version written by a later build are kept. `bootstrap()` loads the settings before the first frame, so the first frame has the user's theme and language, and `settingsProvider` applies a change at once and then stores it. When the file cannot be written, the change still applies for the session. Settings then shows a warning Banner at the top of the pane until the next change is stored or the person dismisses it (`settingsSaveFailedProvider`, `app/lib/features/settings/settings_save_failure.dart`, [G90](DESIGN_GAPS.md#g90)). First run reports no failure: a language choice that cannot be stored still switches the UI for the session, and when the end of first run cannot be stored, first run shows again at the next launch. Not shared_preferences: on macOS it writes to the user's preferences domain outside the app data directory. Not a file owned by the Rust core yet: the CLI reads no settings in M1, and moving the file behind ferman-api later keeps its format. The web build keeps settings in memory until phase 5.
- **Web (phase 5).** The engine compiles to WebAssembly (FRB v2 supports the web). Rendering uses a PDFium WebAssembly build (experimental today) or hayro as a pure-Rust fallback. Threads need cross-origin isolation. Files come from the browser's file APIs, and recents are remembered by name only (a14-2b). There is no atomic rename on the web, so saving writes a new file through the browser.
- **Mobile (phase 5).** iOS and Android from the same Flutter code. PDFium binaries exist for both (iOS 17, Android API 23 as built). The touch density tokens already exist in the design.

## 13. Testing strategy

Fixed by brief §4 and §5 ([ADR 0017](adr/0017-testing-and-ci.md)).

### 13.1 Rust unit and integration tests

- Unit tests next to the code in every crate.
- Integration tests in `crates/*/tests/` run against the corpus through public APIs. The full open, edit, save and reopen path is tested through the ferman-api facade.
- insta snapshots for object trees, extracted text and text models (as JSON).

### 13.2 Property tests (proptest)

- Lexer round trip: tokenize, serialise, tokenize again gives the same tokens.
- Encodings: for every supported encoding, decoding then encoding returns the original codes.
- Edits: applying an edit then reverting it returns a byte-identical content stream.
- Writer: parsing a written incremental update returns the same objects; the original bytes are a prefix.
- Text model: every glyph belongs to exactly one block; reading order is a permutation.

### 13.3 Corpus

- `tests/corpus/README.md` records provenance for every file: source, licence, SHA-256, what it covers.
- **Generated files** (tools/corpus, deterministic, [ADR 0020](adr/0020-test-corpus.md)) mirror the design's sample documents. The first wave is listed in `tests/corpus/README.md` since M2 step 1. The documents are: the Turkish rental contract with a subset font missing "ğ" and a tight frame above the IBAN line; the bank statement; the one-page e-Devlet form ([G59](DESIGN_GAPS.md#g59)); the 2,400-page report for progressive open; a truncated file; an AES-256 payslip whose password contains Turkish letters; an XFA-only form; a 12-page Arabic report with mixed numbers; a Japanese letter with vertical text; scanned Turkish pages; signed variants, including one changed after signing.
- **Real-world files** under free licences, as brief §5 lists: Word, Google Docs, LibreOffice, LaTeX, scanned, forms, signed, encrypted, damaged.

### 13.4 Pixel-diff acceptance for every edit

The rule from brief §4: render before and after with PDFium; the pixel difference outside the edited region must be exactly zero.

1. Each case is a corpus file plus an edit script (page, block selector, operations, expected outcome).
2. Render the page before editing at fixed resolutions (72, 150 and 300 dpi) with the fixed render flags. Before and after are rendered the same way, tile for tile: tiles put together match a render of the whole page only to within two levels of antialiasing (section 4.4).
3. Apply the edit through the facade and save incrementally to a temp file.
4. Reopen the saved file **from disk** and render the same page.
5. The edited region is the union of the block's bounding box before and after the edit, including an extended frame, in device pixels after page rotation. **Proposed:** it grows by 2 device pixels for anti-aliasing, and that margin is documented in the test.
6. Assert zero differing pixels outside the region. Also assert: every other page renders identically, content-stream bytes outside the block's spans are identical, every other object is byte-identical, and the original file is an exact prefix of the saved file.
7. Required cases: Turkish (ğ, ş, İ, ı in WinAnsi with `/Differences`, subset TrueType and Identity-H fonts), Arabic with RTL shaping (joining forms, lam-alef, marks, IBAN isolation), Persian with ZWNJ, CJK (Identity-H and Identity-V, vertical text), justified paragraphs, `TJ` kerning, multi-column layouts, rotated pages and rotated text, text inside Form XObjects, marked content with `/ActualText`, the missing-glyph steps and the overflow choices.
8. `ferman verify-edit` runs one case from the command line.

### 13.5 Flutter tests

- Widget tests for every component and screen, with very_good_analysis lints, and `flutter analyze` and `dart analyze --fatal-infos` clean (the riverpod_lint plugin reports only through `dart analyze`).
- **Goldens** with alchemist for every implemented screen in light and dark × en, tr and ar, with the real bundled fonts loaded (text is never obscured). Goldens are compared on the Linux CI runner only, so font rasterisation does not vary between machines: golden tests carry the `golden` tag (`app/dart_test.yaml`), Linux runs `flutter test`, and macOS and Windows run `flutter test --exclude-tags golden`. Every golden test also passes `skip: !isGoldenHost` (`app/test/helpers/golden_config.dart`): off Linux alchemist's test variant has no values, and flutter_test fails such a test while its file loads, before `--exclude-tags golden` applies. `app/test/flutter_test_config.dart` loads the bundled fonts from the font manifest. `flutter test` has no system font fallback, so it also loads two system fonts of the Linux runner and appends them to every UI font chain through the test-only hook `FermanFontFamilies.debugExtraFallback`, which the app never sets: DejaVu Sans Mono (`fonts-dejavu-core` 2.37-8) for the macOS key symbols ⌘ ⌥ ⇧ ⌃ ⌫ ⌦ ↵ that the Plex files lack ([G87](DESIGN_GAPS.md#g87)), and Noto Sans CJK JP (`fonts-noto-cjk` 1:20230817+repack1-3) for the language picker's CJK names. The CI step that installs them fails when either version changes, since that would move pixels, and a window golden that shows such a character fails before writing anything when its font is missing. Without them the goldens that show neither are byte-identical. The first goldens (script coverage and the 229 icons) were generated in the development container and match on the CI Linux runner; a golden that differs there is regenerated from CI.
- **Component goldens** (`app/test/goldens/components_golden_test.dart`, `app/test/helpers/component_golden.dart`): every section of the component gallery (`galleryEntries`, 57) in light and dark, and the 46 sections with directional content also in the gallery's Arabic right-to-left preview (Egypt, CLDR's likely region for `ar`, so weeks start on Saturday; the window goldens use Saudi Arabia, [G34](DESIGN_GAPS.md#g34)), 206 goldens named `component_<Entry>_<light|dark>[_rtl].png`, 1200 px wide at the content's height, at desktop density with macOS key caps. Symmetric components, page content and the icon grid have no right-to-left golden (`noRtlGolden`, with reasons). The same settling and freezing rules as the window goldens apply. A golden fails on text in any font family the run has not loaded, as flutter_test would draw boxes; DejaVu Serif from fonts-dejavu-core stands in for Georgia and Times New Roman, the system fonts the FontPicker sample names, loaded by name and never appended to the UI chains.
- **The golden matrix** (`app/test/goldens/screens_golden_test.dart`, `shell_golden_test.dart`): 144 whole-window goldens of 1440 × 900 at a device pixel ratio of 1, the size of the design references, named `<screen>_<mac|win>_<light|dark>_<en|tr|ar>.png`, the contract with the comparison report. They are first run's language picker and steps 2 and 3, the empty start screen and Settings' General, Language and region and Privacy panes with macOS chrome (General also with Windows chrome), and the shell in each of the eight modes with macOS and Windows chrome, each in light and dark × en, tr and ar. `app/test/helpers/window_golden.dart` starts the whole app (`FermanApp`, the router, Ferman's title bar) on fixed settings and a fixed system locale, runs the platform as macOS or Windows for desktop density, lets every animation that ends finish, brings the spinners to the start of a turn and stops every ticker before the capture, and shows the caret without blinking. macOS goldens paint the native traffic lights where the window places them (`app/test/helpers/traffic_lights.dart`, repeating the Swift layout; [G96](DESIGN_GAPS.md#g96)). Regions: Türkiye for Turkish, Saudi Arabia for Arabic (the Arabic boards draw Arabic-Indic digits), the United Kingdom for English, and Türkiye for Language and region in every language, as a11-1b and a12-2c show ([G34](DESIGN_GAPS.md#g34)).
- **Localization tests** (`app/test/l10n/`): Arabic and Turkish have every key and placeholder of `app_en.arb`, and every English message has a description for translators; region formats follow the region in a real screen ("13.10.2026 · 14:32" and "10,5 pt" for an English UI with the Türkiye region); every M1 screen mirrors in Arabic, Persian and Hebrew, with directional icons mirrored and the others not; the localizations are app code, loaded at once and never from the network. **Approved by the owner on 2026-10-16** (Proposed until then): a test-only pseudo-locale (`app/test/helpers/pseudo_locale.dart`) stretches every English string to 140 % with accented letters, and every M1 screen must render in it, and in en, tr and ar, at 1440 × 900 and 1024 × 768 without an overflow or a cut-off text (`app/test/helpers/text_fit.dart`); it stands in for the German boards a12-2b and a12-2d.
- **Design-reference comparison.** tools/design-refs renders each artboard to `build/design-refs/`, and `node tools/design-refs compare` lines up each golden with its artboard through `tools/design-refs/compare-map.json` (34 pairs: the boards ROADMAP §5 step 11 names, the macOS shell boards a2-1b and a3-1d, the Turkish and Arabic editors a12-1tr and a12-1ar, and Settings Privacy; since export `519d42a` first run's last step, the start screen and Settings' General (macOS and Windows) and Privacy are compared with the M1 build boards a1-2c-m1, a1-5-m1, a11-1-m1, a11-1w-m1 and a11-1h-m1, each in English, Turkish and Arabic, and the five boards they supersede are listed as not compared, as are the German a12-2b and a12-2d; the crops of the fix boards f6 and f6a; and masks for what M1 cannot show, such as the canvas before M2). For each pair it reports the share of differing pixels (pixelmatch's YIQ threshold, anti-aliasing left out) and one minus the SSIM of the luma, writes a diff and a side-by-side image, and writes `build/design-compare/report.md`. The design-references workflow appends the report to the step summary, uploads the images and keeps one pull-request comment up to date. **Proposed:** in M1 the score is reviewed by a person, not used as a gate.
- integration_test runs desktop flows against the real engine from M3, starting with Flow A (open, fix a typo, save). From M1, `app/integration_test/app_test.dart` starts the built app and checks the engine through the bridge: the API version, `engine_info()` with `PdfiumState.loaded` and the tag `chromium/7881` (the bundled PDFium), a Rust panic arriving as an error, and the 1 MiB byte transfer of section 3.4. It is one file because Linux desktop cannot launch the app a second time for a second file. `flutter test integration_test` runs it in debug mode only; for profile numbers, `app/test_driver/integration_test.dart` runs the same file with `flutter drive --profile -d <linux|windows|macos> --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart` (from `app/`).

### 13.6 Fuzz targets

One target per parser, starting with the first parser in M2: object lexer and parser, cross-reference and trailer (including repair), content-stream lexer, interpreter, each stream filter (Flate, LZW, ASCII85, ASCIIHex, RunLength), CMap and ToUnicode, Type1 parser, encryption and password handling, incremental writer round trip, and "open arbitrary bytes" through the facade. CI runs a short session on every pull request and a longer one nightly (**Proposed** with the M2 plan: 60 s per target on pull requests, 1 h per target nightly). Crashes become regression files in the corpus.

Since M2 the targets are `filter_ascii_hex`, `filter_ascii85`, `filter_lzw`, `filter_flate` and `filter_run_length`, and with the open path `syntax_object` (the object parser), `xref_repair` (cross-reference data, `/Prev` chains and repair, whose rebuilt table must read back clean from the flat copy lopdf gets), `security_handler` (an encryption dictionary, password handling for revisions 2 to 6, and decryption) and `open_document` (the whole open path, lopdf included, on arbitrary bytes), and with text `content_lexer` (the content-stream lexer: operators, operands, spans and inline images) `cmap` (ferman-fonts' CMap reader, then splitting a string into codes and looking each up) and `interpreter` (the text interpreter on arbitrary content, drawn by a page and by a form that draws itself) ([fuzz/README.md](../fuzz/README.md)). They reach ferman-core's internals through its hidden `fuzzing` module, behind a feature only `fuzz/` enables. LZW and Flate take their `/DecodeParms` from the first four input bytes, so every predictor and every invalid parameter is reachable. Each target checks what every decoder promises: no panic, never more than its 1 MiB decoded-size limit, and only the errors a damaged stream can cause. The pull-request job runs each target for 60 s on Linux; the nightly job comes with M2's CI commit.

### 13.7 Benchmarks

criterion benchmarks for open, page sizes, first-page render, tile render, text model per page, edit apply and save. They feed the CI guards in section 14. The first, since M2, is ferman-render's `first_page` (`benches/first_page.rs`): opening the generated 500-page `long-500` with every page size, the first tile of page 1 at 100% and a device pixel ratio of 2 from cold caches, and a tile of a page already loaded. CI runs it from M2's CI commit.

### 13.8 CI matrix

GitHub Actions on macOS, Windows and Linux: Rust fmt, clippy and test, cargo-deny, Flutter analyze and test, desktop build. The Rust tests that need PDFium (`#[ignore]` by default) run on all three systems against the pinned library: `tools/pdfium/fetch.sh` for the runner's platform, an absolute `FERMAN_PDFIUM_PATH`, and `ferman info --json --pdfium` must report `loaded`. A codegen job regenerates the bridge bindings (flutter_rust_bridge_codegen 2.13.0 and cargo-expand 1.0.127, cached), the localizations, the build_runner output, the isolated fallback strings and the translation table of [TRANSLATION_REVIEW.md](TRANSLATION_REVIEW.md), and fails on any diff. The Flutter jobs and the Ubuntu 22.04 job fetch PDFium for their platform before the desktop build, and the integration test runs against the built app on each system. After the release build, every Flutter job scans its output with `tools/checks/bin/scan_bundle.dart` (and Linux the web build too), so no design-export file ships; on macOS a step asserts with `lipo` that the app executable, the engine framework and PDFium are universal (x86_64 and arm64) and with `vtool` or `otool` that the app targets macOS 12.0 and neither library needs anything newer (Q03). The repository-checks job also checks the bundled fonts' hashes and script coverage. Linux also runs goldens, the fuzz smoke run and benchmarks. CI stays green; a red main branch is fixed before anything else.

## 14. Performance budgets

The first three rows come from brief §5. Rows marked **Proposed** are new and need approval. Flutter measurements use profile builds; Rust benchmarks use release builds.

**Reference hardware (Proposed):**

- R1: MacBook Air, Apple M1, 8 GB.
- R2: Windows 11 laptop with a four-core x64 CPU from 2020 (Core i5-1135G7 class), 8 GB, NVMe SSD, integrated graphics.
- R3: Linux on R2-class hardware (best effort).

| Budget | Target | How measured | Reference | CI guard |
|---|---|---|---|---|
| First page visible (brief) | under 1 s for a 500-page document | from the open request to the frame that shows page 1's first sharp tile; timeline events on both sides; cold engine caches | R1, R2 | criterion bench of the engine part (load, page sizes, first tile) on every pull request; fails above the CI budget |
| Smooth scrolling and zooming (brief) | 60 fps: frame build plus raster under 16.6 ms at the 99th percentile; no UI-isolate task over 4 ms | integration_test with frame timings during a scripted scroll through 500 pages and a pinch from 25% to 800% | R1, R2 | profile-mode perf test on CI tracks regressions; absolute targets are checked on reference hardware before each milestone sign-off, because CI runners have no GPU |
| Edit-to-render (brief) | under 100 ms from key press to the frame showing the edited block | timeline spans. Planned split: apply and layout 10 ms, encode and splice 5 ms, PDFium reload 30 ms, render 30 ms, transfer and frame 20 ms | R1, R2 | criterion bench of the engine part (apply to rendered tiles, 75 ms on reference hardware) against its calibrated CI budget |
| Thumbnail strip (Proposed) | first 12 visible thumbnails within 300 ms after the first page is visible; never delays canvas tiles | timeline events; queue priority test | R1, R2 | bench of thumbnail render; unit test of queue order |
| Search, 500 pages (Proposed) | first match under 200 ms and all matches counted under 1 s once indexed; indexing at least 100 pages per second | bench over a generated 500-page text PDF | R1, R2 | criterion bench |
| Large file, 2,400 pages (Proposed, a1-7) | first page under 1.5 s; full indexing under 25 s; 60 fps while indexing | integration test on the generated report | R1 | bench of indexing throughput |
| Memory (Proposed) | engine memory for an idle 500-page text PDF under 400 MB, tile cache excluded; tile cache within its cap (section 4.7) | resident-set sampling in integration tests | R1, R2 | test fails above the limit |
| Save (Proposed) | incremental save of a 20 MB, 500-page file with 10 edits under 500 ms including fsync; full rewrite at least 30 MB/s; UI never blocks | bench on a temp directory | R1, R2 | criterion bench |
| Cold start (approved by the owner on 2026-10-16) | start screen interactive under 1.5 s | process start to first interactive frame | R1, R2 | tracked, not gated |
| Bridge byte transfer (M1 step 3, section 3.4) | a 1 MB byte vector from Rust to Dart under 0.2 ms | the integration test "a 1 MiB byte vector crosses the bridge": one warm-up call, then the minimum and median of 20 timed `debug_bytes` calls, in a profile build: `flutter drive --profile -d <linux|windows|macos> --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart` from `app/` | R1, R2 | none yet; the CI integration test logs a debug-build number |

The bridge transfer's first numbers come from the development container, not R1 or R2, and miss the target by more than an order of magnitude (section 3.4, [PROGRESS.md](PROGRESS.md#measurements)).

CI runners are slower and noisier than reference hardware. **Proposed:** each CI budget is the reference budget times a calibration factor measured per runner type. A benchmark more than 15% slower than the stored baseline for three runs in a row fails the job, from M2 on.

## 15. Risks and open questions

| Risk | Impact | Mitigation | Link |
|---|---|---|---|
| The shaper: rustybuzz, which the brief names, is archived upstream; harfrust, which replaces it, is pre-1.0 | shaping regressions on upgrades | ADR 0007 accepted (harfrust): exact pin, joint upgrades with the font stack, shaping and pixel-diff suites on every upgrade, one internal trait; rustybuzz banned except through krilla | [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md), [Q04](QUESTIONS.md#q04) |
| lopdf breaks its API almost monthly | upgrade churn, behaviour changes | pin `=0.45`; wrap it inside ferman-core; upgrade deliberately with the corpus as a safety net | [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md) |
| PDFium is not thread-safe and runs in-process | throughput limit; a PDFium crash ends the app | one render thread plus the global lock; recovery journal; helper processes if M2 measurements demand it | section 4.4 |
| lopdf and PDFium disagree on damaged files | the user sees content the model does not contain | read-only on disagreement; repair is a full rewrite to a new file | section 5.2 |
| Font stack versions split (skrifa and read-fonts for harfrust versus subsetter and krilla) | two copies in the binary; handles not interchangeable | pin exact versions; upgrade the font crates together | [DEPENDENCIES.md](DEPENDENCIES.md) |
| FRB tile transfer: the M1 benchmark copies (SSE codec) and misses 0.2 ms per MiB | tile transfer could exceed the frame budget | the owner's order ([Q19](QUESTIONS.md#q19)): the Dco codec first, measured on R1 and R2 at the start of M2 step 3; then the pointer view, with the owner's approval of its unsafe surface; the texture registry last | section 3.4 |
| Out of memory: Rust aborts the process when an allocation fails | a1-9f's "only its tab closes" holds only where the engine checks first | **Proposed** with the M2 plan: `try_reserve` and the limits before large allocations, reported as `ResourceLimit`; out of memory inside PDFium cannot be caught ([ADR 0010](adr/0010-error-handling-no-panics.md)) | section 8.2 |
| PDFium substitutes non-embedded fonts with each machine's system fonts | a1-9's "shown as IBM Plex Serif" may differ between machines | look for a safe pdfium-render route to Ferman's own font files in M2; otherwise record a design gap and decide in M3 (pixel diffs on one machine are unaffected) | section 5.2 |
| One PDFium reload per edit on very large files | edit-to-render above 100 ms | custom reader without copies; render only changed pages; measure in M3 | section 14 |
| IME and caret handling on a custom canvas | broken CJK and dead-key input | `DeltaTextInputClient` from the first M3 prototype; CJK cases in integration tests | section 6.12 |
| Windows custom caption buttons lose snap layouts | platform behaviour regresses | native hit-test hook for the maximize button | section 12 |
| macOS App Sandbox restricts file access | recent files and the atomic save need extra platform code | the owner's answer: bookmarks and the system replacement directory, proven in M2; if they do not work, the Developer ID build drops the sandbox | [Q18](QUESTIONS.md#q18) |
| Version history folder next to the file (a9-8) | sync conflicts, read-only folders | decide with an ADR when M4 is planned | section 7.4 |
| OCR engine (ocrs is a Latin-only preview with an unclear model licence) | Turkish and other scripts poorly recognised | chosen at the start of P3 after a fresh check; Tesseract is the fallback | [Q16](QUESTIONS.md#q16) |
| Unsigned third-party PDFium builds | supply-chain risk | pinned tag and SHA-256; sign with the app | section 12 |

Open questions that affect this design are all in [QUESTIONS.md](QUESTIONS.md). The owner answered [Q01](QUESTIONS.md#q01) to [Q20](QUESTIONS.md#q20) on 2026-10-15 and 2026-10-16, and the answers are recorded in the sections above. One question is open, from the M2 planning on 2026-10-17:

- [Q21](QUESTIONS.md#q21): may ferman-core memory-map the private snapshot of a file over 256 MB through one reviewed `memmap2` call site, an exception to the no-`unsafe` rule (section 5.1)? Until it is answered, M2 reads every file into an owned buffer.
