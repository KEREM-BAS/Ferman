# Ferman architecture

Status: Milestone 0, docs only. No code exists yet.

This document covers brief §8 item 3: crates, API boundary, threading, data flow, file safety, error handling, testing strategy and performance budgets. It turns brief §3 to §6 into an engineering design.

- The decisions in the [brief](BRIEF.md) are fixed. They change only through an ADR the owner approves.
- Anything marked **Proposed** is a new decision. It waits for the owner's approval through its ADR (see the [ADR index](adr/README.md)).
- If this document and the brief disagree, the brief wins and this document has a bug.

Related: [roadmap](ROADMAP.md) · [design inventory](DESIGN_INVENTORY.md) · [design gaps](DESIGN_GAPS.md) · [dependencies](DEPENDENCIES.md) · [questions](QUESTIONS.md) · [backlog](BACKLOG.md)

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
|   UI isolate: Fm* components, features/*, Riverpod, go_router        |
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
3. **The UI isolate never waits.** Every engine call is async. Parsing, rendering, saving and jobs run on Rust threads ([ADR 0009](adr/0009-threading-and-jobs.md), Proposed).
4. **Edits are surgical.** Only the edited block's operators change. Pixels outside the edited region stay identical ([ADR 0005](adr/0005-block-scoped-text-editing.md)).
5. **Never corrupt a file.** Temp file, fsync, atomic rename, incremental update by default ([ADR 0008](adr/0008-file-safety-and-saving.md)).
6. **PDFs are hostile input.** Limits everywhere, a fuzz target for every parser, document JavaScript never runs (section 9).
7. **Local only.** No telemetry. One network gateway serves the four uses the brief allows ([ADR 0015](adr/0015-privacy-and-network.md)).

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
├── fuzz/                 cargo-fuzz workspace, one target per parser (from M2)
├── app/                  Flutter app: macos, windows, linux, web now; ios, android later
├── tools/
│   ├── tokens/           design tokens → app/lib/design/tokens.g.dart (ADR 0012)
│   ├── icons/            ICON_PATHS + fm-icons.js → SVG assets + provenance table
│   ├── design-refs/      Playwright renders of every artboard → build/design-refs/
│   ├── pdfium/           fetches pinned PDFium binaries and checks SHA-256
│   └── corpus/           corpus generators and fetch scripts
├── tests/corpus/         test PDFs + README.md with provenance
├── docs/                 brief, architecture, ADRs, roadmap, progress, …
└── .github/workflows/    CI
```

`fuzz/` is not in the brief's tree. It is the standard cargo-fuzz location, kept as a separate workspace so `libfuzzer-sys` (NCSA) never enters the shipped dependency graph.

Toolchain targets: Rust stable 1.99, pinned with `rust-toolchain.toml` in M1; Flutter 3.47.7 with Dart 3.13.5; Node 24 LTS for the tools.

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
- **Proposed:** a CI script reads `cargo metadata` and fails on any edge not in this table.

### 2.3 Crates in detail

#### ferman-core

- **Responsibility:** load bytes (with password), lopdf object model, xref repair, decryption and re-encryption on write, structure scan (page tree and inheritance, page labels, outlines, attachments, optional content, AcroForm and XFA detection, signatures and DocMDP permissions), content-stream lexer and interpreter (section 6.1) with a byte span for every operator, revision store (section 4.3), incremental writer, full rewrite, safe write (section 7), recovery journal (section 7.6), resource limits (section 9).
- **Public surface:** `Document`, `Snapshot`, `RevisionId`, `ObjectStore`, `Interpreter` with `InterpreterSink` and the `TextAdvance` trait (implemented by ferman-text, so core needs no font code), `Operator { name, operands, span }`, `ChangeSet`, `SaveMode`, `safe_write`, `RecoveryJournal`, `Limits`, `CoreError`.
- **Key dependencies:** lopdf pinned to `=0.45` (breaking releases come almost monthly), sha2, thiserror, tracing. atomic-write-file is under evaluation against section 7.

#### ferman-fonts

- **Responsibility:** font programs (TrueType and CFF/CFF2 through skrifa and read-fonts; a minimal Type1 parser for the built-in encoding and glyph names, because skrifa does not read Type1), encoding tables (Standard, WinAnsi, MacRoman, MacExpert, PDFDoc, Symbol, ZapfDingbats), glyph names to Unicode (Adobe Glyph List), CMap and ToUnicode parsing with `usecmap` chains, coverage, metric comparison for similar-font ranking, shaping, subsetting, system font discovery, the registry of fonts bundled with the app, and glyph and shaping caches.
- **Shaping:** the brief names rustybuzz, which is archived upstream. [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md) **proposes** harfrust ([Q04](QUESTIONS.md#q04)). Until the owner approves, the brief's rustybuzz stands. The shaper sits behind one internal trait so the switch touches one module.
- **Public surface:** `FontProgram`, `GlyphId`, `Coverage`, `Shaper`, `ShapedRun`, `Subset`, `SystemFonts`, `FontMatch`, `SimilarFonts`, `Encoding`, `CMap`, `ToUnicode`, `FontError`.
- **Key dependencies:** skrifa, read-fonts, harfrust (Proposed) or rustybuzz, subsetter, fontdb, unicode-normalization. Predefined CJK CMap data and the Adobe Glyph List are added only after their licences are checked and listed in [DEPENDENCIES.md](DEPENDENCIES.md).

#### ferman-text

- **Responsibility:** resolve PDF font resources into a `PdfFont` (dictionary, program, encoding, ToUnicode, widths, vertical metrics), implement `TextAdvance` for the interpreter, build glyph runs, map glyphs to Unicode, rebuild words, lines, blocks, columns, alignment and reading order, assign block ids, hit testing, decide editability, run edit operations, line breaking and reflow, bidi, re-encoding, generate a block's replacement operators, resolve missing glyphs and overflow, extract search text, keep the edit journal behind the review list (a3-12).
- **Public surface:** `PageText`, `TextBlock`, `Line`, `GlyphRun`, `BlockId`, `Editability`, `EditOp`, `BlockEditor`, `MissingGlyphPlan`, `OverflowPlan`, `SearchIndex`, `TextError`.
- **Key dependencies:** ferman-core, ferman-fonts, unicode-bidi, unicode-segmentation, unicode-normalization, icu_casemap (search folding), and a UAX #14 line breaker chosen and licence-checked in M3.

#### ferman-render

- **Responsibility:** load the PDFium library at run time from a path in `EngineConfig`, own the render thread, render tiles (clip rectangle plus matrix) and thumbnails, answer page-size queries, reload a document when a new revision changes pixels, run the prioritised tile queue, and keep the tile and thumbnail caches. Render flags are fixed and documented, because the acceptance tests depend on deterministic output.
- **Public surface:** `Renderer`, `ViewSession`, `TileRequest`, `Tile`, `TileKey`, `ZoomBucket`, `Thumbnail`, `RenderError`.
- **Key dependencies:** ferman-core, pdfium-render 0.9.4 (with `thread_safe` on as a second guard), crossbeam-channel, lru. PDFium is the prebuilt bblanchon/pdfium-binaries tag `chromium/7881`, the non-V8, non-XFA build.

#### ferman-ops

- **Responsibility:** M4 and later. Organize pages (insert, delete, rotate, move, extract, replace), combine and split, annotations, form filling with appearance streams, simple (non-cryptographic) signatures, compress, flatten, version-history snapshots. Phase 2 adds watermark, header and footer, Bates numbering, redaction with verification and removal of hidden information.
- **Public surface:** one module per operation family. Each is a function from `(Snapshot, params)` to a `ChangeSet` that the document actor commits. Long operations run as jobs.
- **Splitting:** as the brief says, it splits into more crates as it grows, for example signing (P3: cms, x509-cert, cryptoki), OCR (P3), conversion (P3) and PDF/A (P4: krilla).
- **Key dependencies:** ferman-core, ferman-text, ferman-fonts, `image` with default features off.

#### ferman-api

- **facade** (pure Rust, always built): `Engine`, `EngineConfig`, all handles and DTOs, `ApiError`, the document actors, the job manager and, from M5, the network gateway (section 10). ferman-cli and the integration tests call this module.
- **frb** (feature `frb`, on in the app build): thin wrappers that expose facade functions to Dart, stream sinks for tiles and jobs, mirrors of DTOs. Nothing else lives here. FRB codegen scans only this module, so the generated surface stays small.
- **Key dependencies:** every Ferman crate, flutter_rust_bridge `=2.13.0` (optional), thiserror, tracing. The FRB Rust crate, the Dart package and the codegen tool must have exactly the same version. A CI check compares the three.

#### ferman-cli

- **Responsibility:** the `ferman` binary for tests and power users: `info`, `pages`, `render`, `text`, `edit` (applies an edit script), `save`, `verify-edit` (runs the pixel-diff acceptance check on one case), and later `compress`, `combine` and others.
- **Output:** human-readable by default, `--json` for scripts. JSON output carries the API version.
- **Key dependencies:** ferman-api (facade only) and an argument parser chosen in M1.

### 2.4 Tools, corpus and fuzzing

- **tools/tokens** reads `tokens/*.css` and `ds-additions/fm-additions.css` (the additions are not merged into the DS files, [G05](DESIGN_GAPS.md#g05)) and generates `app/lib/design/tokens.g.dart`, exposed through `ThemeExtension`. It produces light, dark, touch density, page dim, CJK type overrides and reduced motion. The implementation language and mapping rules are in [ADR 0012](adr/0012-design-token-pipeline.md).
- **tools/icons** writes the design's exact path data for all 229 icons (ICON_PATHS plus fm-icons.js) as SVG assets drawn at 1.5 px stroke, with a provenance table that names Lucide 0.460.0, Lucide 1.56.0 or "Ferman design" for each glyph ([G04](DESIGN_GAPS.md#g04), [G60](DESIGN_GAPS.md#g60), [ADR 0013](adr/0013-fonts-and-icons.md)).
- **tools/design-refs** uses Node 24 LTS and Playwright to render every artboard to `build/design-refs/<id>.png` (gitignored). It runs offline with vendored runtime scripts and local fonts, and blocks every network request, so the export's runtime Google Fonts `@import` never loads ([G07](DESIGN_GAPS.md#g07)).
- **tools/pdfium** downloads `chromium/7881` for each platform, checks a pinned SHA-256 per archive, and unpacks the library plus its `licences/` folder.
- **tools/corpus** holds deterministic generators for the design's sample documents (section 13.3) and a fetch script for larger real-world files.
- **tests/corpus/** holds the PDFs and a README.md with provenance for every file: source, licence, SHA-256 and what it covers. **Proposed:** files up to 1 MB are committed; larger ones are fetched by tools/corpus with pinned hashes.
- **fuzz/** holds the cargo-fuzz targets (section 13.6).

### 2.5 Flutter app layout

```text
app/
├── lib/
│   ├── main.dart
│   ├── app/                 bootstrap, go_router, root providers, engine start-up
│   ├── bridge/              FRB-generated Dart (never edited by hand)
│   ├── engine/              Dart services over the bridge: documents, tiles, text, edits, jobs
│   ├── design/
│   │   ├── tokens.g.dart    generated by tools/tokens (never edited by hand)
│   │   ├── theme.dart       ThemeExtension wiring: light, dark, touch, dim, reduced motion
│   │   ├── icons/           generated icon registry for assets/icons
│   │   └── components/      Fm* component library, 1:1 with the design system
│   ├── l10n/                ARB files (app_en.arb is the source), casing and formatting utilities
│   └── features/
│       ├── shell/           title bar, document tabs, mode tabs, tool row, sidebars, status bar
│       ├── start/           start screen, recents, drop zone
│       ├── onboarding/
│       ├── viewer/          canvas, tile layer, zoom, layouts, thumbnails, outline, search
│       ├── edit/  comment/  fill_sign/  organize/  convert/  protect/  tools/
│       ├── settings/
│       └── recovery/        crash recovery prompt (a1-12)
├── assets/
│   ├── fonts/               unmodified IBM Plex TTFs + LICENSE.txt per family
│   ├── icons/               229 SVGs + Lucide ISC and Feather MIT notices + provenance
│   └── licenses/            third-party notices (PDFium licences/, Rust crates)
├── test/                    widget and golden tests (alchemist)
├── integration_test/        desktop flows against the real engine
└── macos/  windows/  linux/  web/
```

Rules for the app:

- Feature code reaches the engine only through providers in `app/lib/engine/`. Widgets never import `app/lib/bridge/`.
- State uses Riverpod with code generation, navigation uses go_router, lints are very_good_analysis plus riverpod_lint ([ADR 0011](adr/0011-flutter-state-navigation-components.md)). Per-document state lives in family providers keyed by `DocumentId`.
- The shell has eight mode tabs, as every artboard shows: View, Edit, Comment, Fill & Sign, Organize, Convert, Protect, Tools ([G09](DESIGN_GAPS.md#g09), [Q05](QUESTIONS.md#q05)). Each mode is a feature folder. Mode tabs and sidebar tabs are custom segmented controls over an `IndexedStack`, so each keeps its state; open documents are kept in an `IndexedStack` too. `TabBarView` is never used.
- Features not built yet stay visible as designed, disabled, with the tooltip "Available in a future version" ([G10](DESIGN_GAPS.md#g10)).

## 3. API boundary

What ferman-api exposes is fixed by the brief: open and close, page info, tile rendering, text blocks, edit transactions with engine-level undo and redo, and jobs. The boundary rules are in [ADR 0003](adr/0003-crate-layout-and-api-boundary.md). The DTO shapes below are **Proposed** sketches, not final code; they settle when M1 and M2 implement them.

### 3.1 Rules

- Every function is async or returns a stream, except `api_version()`. The Rust side of a call only validates input, sends a message to the right actor or queue, and awaits the reply. FRB worker threads are never held by long work.
- Data that crosses is plain: integers, floats, strings, enums, byte vectors, and structs of those.
- Geometry uses one **page space**: PDF points, origin at the top-left of the visible page after CropBox, `/Rotate` and `/UserUnit` are applied, y pointing down. The engine owns every conversion from PDF user space. The UI never sees a PDF matrix.
- No localized text crosses. The engine returns message keys with parameters. Dart formats numbers, dates and units from the region setting (section 11).

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
- **Zero copy.** A freshly rendered tile's `Vec<u8>` moves to Dart without a copy: FRB v2 hands primitive vectors to Dart as external typed data on native platforms. An M1 benchmark must confirm this (target: a 1 MB tile crosses in under 0.2 ms). If it fails, the fallback is a platform texture registry. Dart then builds a `ui.Image`, which costs one upload that is part of the frame budget. A tile served from the Rust cache costs one memcpy.
- **Thumbnails** use the same stream, requested with `request_thumbnails(view, pages, size_px)` at lower priority.

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
- **Selective revert.** "Revert" on one row of the review list (a3-12) is a new forward transaction that restores that edit's objects. If a later edit touched the same block, it is refused with a reason ([G42](DESIGN_GAPS.md#g42)).
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

### 3.9 Versioning

- `api_version()` returns `{ major, minor }`. FRB generates the Dart and Rust glue from one source in one build, so a mismatch can only mean a stale native library. The app checks at start-up (FRB also checks its own content hash) and shows an error screen instead of crashing.
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

The whole model in this section is **Proposed** in [ADR 0009](adr/0009-threading-and-jobs.md). The brief fixes only the outcome: rendering and heavy work never run on the UI thread.

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

- PDFium is not thread-safe. pdfium-render's `thread_safe` feature wraps every call in one global lock. On top of that, all PDFium calls run on the render thread, so the lock is never contended and PDFium's thread-affinity assumptions hold.
- The render thread holds one PDFium document per open document. When a revision changes pixels, it loads the revised bytes as a new PDFium document through a custom reader over the snapshot (base bytes plus the in-memory incremental section, no concatenated copy), swaps it in once loaded, and drops the old one after in-flight tiles finish.
- A small LRU of loaded pages (8 per document, Proposed) avoids reparsing the pages being scrolled. It is dropped on reload.
- One thread limits throughput. The answers are caching, low-resolution placeholders, prefetching and progressive rendering with a pause callback, so a slow tile (a large scan) can be abandoned when it goes stale (to verify in pdfium-render). If M2 measurements show this is not enough, the fallback is a pool of helper processes with one PDFium each, which also isolates PDFium crashes. It is not planned before those measurements.

### 4.5 Tile queue

- **Priority classes**, highest first: (0) visible tiles, ordered by distance from the viewport centre; (1) prefetch, one screen ahead in the scroll direction and half a screen behind; (2) visible thumbnails; (3) other thumbnails; (4) background renders (persistent thumbnails for recents).
- **Wanted-set semantics.** Each `request_tiles` call replaces the view's wanted set and carries a new generation. Queued requests that are not in the newest set are dropped before rendering. A tile that is already rendering finishes, unless progressive rendering lets it stop.
- **Stale results.** A finished tile whose generation is older than the view's newest set goes into the cache, not to the UI, unless the newest set still wants it.
- **Ordering.** The UI keeps the newest render key per page and discards any tile with an older key, so a page never flips back to an old revision.
- **Low resolution first.** When a sharp tile is missing, the UI draws the best cached lower bucket or the thumbnail, scaled ([G30](DESIGN_GAPS.md#g30) asks for this spec to be drawn).

### 4.6 Job pool and cancellation

- Jobs run on a dedicated rayon pool, separate from the global one.
- Each job has a cancel token (running, paused or cancelled) checked at page granularity and inside long loops (every few thousand operators, every decoded megabyte). Pause parks the job between steps.
- Order of preference: user-initiated work (search, save) before open indexing before background work.
- Cancelling never leaves partial output: a job writes to a temp file or a change set, and only a finished job's result is committed.

### 4.7 Caches and invalidation

| Cache | Where | Key | Cap | Invalidation |
|---|---|---|---|---|
| Tiles | Rust, CPU memory | document, render key, bucket, device pixel ratio, rect | Settings › Advanced page cache (a11-1k shows 1 GB), clamped to 25% of RAM (Proposed) | a new render key makes old entries unreachable; they age out. Closing a document drops its entries |
| Tile images | Dart | same as tiles | wanted set plus a small margin | `ui.Image.dispose()` when a tile leaves the margin |
| Thumbnails | Rust, memory | document, render key, size | count cap | as tiles |
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
2. `open(source)` creates the document actor. The engine reads the file into an owned buffer and computes its SHA-256 while reading. It never keeps reading the user's file after open. **Proposed:** files above 256 MB are copied to a private snapshot in the cache directory (a clone or reflink where the file system supports it) and memory-mapped from there. The user's file is never memory-mapped, because another process truncating it would crash Ferman, and on Windows a mapping blocks the rename used for saving.
3. The render thread loads the same bytes into PDFium. If a password is needed, the result is `NeedsPassword` and the UI shows a1-8. `unlock(id, password)` retries. A wrong password returns `WrongPassword` (a1-8b, no lockout). Only this tab is blocked.
4. PDFium returns the page count and every page size without loading the pages. The UI lays out all pages with their real sizes and requests tiles for the first visible page. This is the first-page-visible path (section 14).
5. In parallel, an indexing job parses the bytes with lopdf: object model, structure scan, signatures, permissions, outline, attachments, optional content, page labels, and search text per page. For large files the UI shows a1-7: "Page 840 of 2,400 · about 20 seconds left". Search, thumbnails and editing turn on when indexing finishes, as the a1-7 banner says. Scrolling and zooming work throughout.
6. When both parsers succeed, the engine compares page count and page sizes. **Proposed:** a mismatch opens the document read-only with a notice, because two parsers that disagree are a sign of damage or of a crafted file.

### 5.2 Damaged, restricted and unsupported files

| Situation | PDFium | lopdf | Result | Design |
|---|---|---|---|---|
| Healthy | opens | parses | full features | — |
| Damaged, repairable | opens | strict parse fails; ferman-core repair (xref rebuilt by scanning objects) succeeds | `Repaired`: read-only view with the notice listing what was fixed; Save is enabled and writes the repaired copy | a1-9 |
| Damaged, not repairable | opens | fails, repair fails | `ReadOnly`: view only; the notice explains why editing and repair are off | a1-9 wording, `save='readonly'` |
| Unopenable | fails | fails | error with likely cause, actions and technical details | a1-9b |
| XFA-only form | shows the fallback page | parses | `ReadOnly` with an explanation panel | a11-7c |
| Owner-password restrictions | opens | parses | banner; Edit, Comment and Fill disabled with the reason; optional owner-password unlock | [G27](DESIGN_GAPS.md#g27) |
| Read-only file on disk | opens | parses | read-only banner, Save as only | [G28](DESIGN_GAPS.md#g28) |

**Repair is always a full rewrite to a new file.** Ferman never edits on top of rebuilt cross-reference data and never appends to a damaged file. Save on a damaged document means "Save repaired copy…" (a1-9), which writes the repaired model as a complete new file under a new name by default. Replacing the damaged original needs an explicit confirmation. The original stays as it was until then, as a1-9 promises. The repaired copy then opens as a normal, editable document. Substitutions made during repair (for example a non-embedded TimesNewRomanPSMT shown as IBM Plex Serif) are listed in the notice and in document properties (a2-7).

### 5.3 View

- **Layout.** From `PageInfo` sizes the UI computes page rectangles for continuous, single, spread and book layouts (a2-1a to a2-1d). Spread and book order follow the document's `/ViewerPreferences/Direction`, never the UI language ([G32](DESIGN_GAPS.md#g32)).
- **Tiles.** Each frame where the visible tile set changes, the UI sends one `request_tiles` call with a new generation.
- **Zoom.** During a pinch or ⌘-scroll the UI scales the current tiles on the GPU. It requests the new bucket when the gesture settles or crosses a bucket boundary. Quarter-octave buckets keep on-screen scaling within 19% of the raster.
- **Sidebar.** Thumbnails come from the render thread. Outline, attachments, page labels and layers come from the snapshot after indexing. Empty states follow [G29](DESIGN_GAPS.md#g29).
- **Search** (M2) runs as a job over the per-page search text. Text is NFC-normalised and case-folded with Turkish-aware equivalence, so "kira" finds "KİRA" (a2-4a, a2-3e). "Ignore accents" adds diacritic folding (NFD, then marks removed). Results stream page by page so the "1 of 7" counter updates live. Highlights are quads in page space. Edited pages are re-indexed after each commit.

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

1. **External-change check** (section 7.5). If the file changed on disk, the UI shows a11-7b: Reload, Keep mine, or Compare first.
2. **Build the update.** Every object changed since the last saved revision, in its latest version only. The cross-reference section matches the original's form (classic table or xref stream), with `/Prev` pointing to the previous one. New objects are encrypted with the document's key when the file is encrypted. The first element of the `/ID` array stays, the second changes.
3. **Write** the base bytes plus the update to a temp file, then fsync, verify, rename and fsync the directory (section 7.2).
4. The saved revision becomes the new base. The recovery journal for the document is cleared. The status bar says "Saved on this device · 14:32" (f4b).

Save states follow f4: unsaved, saving, saved, error. Save stays enabled in the error state so the user can retry ([G41](DESIGN_GAPS.md#g41)). Save modes:

- **Incremental update** (default). The original bytes are an exact prefix of the new file. Signatures keep covering the bytes they signed.
- **Optimize and clean** (opt-in full rewrite, [ADR 0008](adr/0008-file-safety-and-saving.md)). It removes unreferenced objects and earlier revisions and recompresses. It invalidates signatures, so the UI warns first.
- **Save as** writes a new file with either mode. The a1-11 sheet collects options and hands off to the OS-native save picker ([ADR 0018](adr/0018-native-file-pickers.md), Proposed, [G26](DESIGN_GAPS.md#g26)). PDF/A-2b and web-optimised output are later phases and stay disabled with "Available in a future version".

### 5.6 Autosave and recovery

Recovery copies live in the app data directory, never next to the user's file (brief §3). The layout, journal format and crash handling are in section 7.6. The flow: every commit appends a record, a snapshot is written every minute while there are unsaved changes (a11-1c "Save a recovery copy every minute"), and on the next launch after a crash the UI offers a1-12.

### 5.7 Close and quit

- Closing a tab with unsaved changes shows a1-10b (Save, Don't save, Cancel; button order per platform).
- Quitting with several unsaved documents needs a review dialog that is not drawn yet ([G40](DESIGN_GAPS.md#g40)).
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

Every block carries `editable` and a reason when it is false. The UI shows the reason in a tooltip with a not-allowed cursor and in the panel ([G39](DESIGN_GAPS.md#g39)).

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
2. **The same font is installed.** fontdb finds it by PostScript name (subset tag removed), then family and style. The engine checks that it really is the same font: units per em, and advance widths of the glyphs the document uses within one unit in 1000 of `/Widths`. It respects the font's embedding permissions (OS/2 `fsType`): restricted fonts go to step 3 with the reason ([G37](DESIGN_GAPS.md#g37)), no-subsetting fonts are embedded whole. The engine builds a new subset with subsetter and embeds it as a new Type0 font with Identity-H encoding and a ToUnicode CMap, used only by the runs that need it. The original subset is not modified, so every other block is untouched. The user is told once, for example "Ferman took ‘ğ’ from Garamond Premier Pro on this computer". That notice is not drawn yet (G37).
3. **Otherwise, the design's flow.** Similar fonts are ranked by coverage of the needed characters and by metrics (x-height, cap height, average width, weight, serif or sans class), from three groups: embedded in this document, installed on this computer, included with Ferman (a3-3b). With the default "Use a similar font and say so" (a11-1c), the character is drawn in the closest match and marked once: amber wavy underline, amber frame tab, warning on the font field (a3-3a, f2). "Choose a font…" opens the a3-3b picker. "Keep as is" keeps the substitution. "Ask each time" asks first. "Keep the original font and mark the character" leaves the character undrawn and marked. The default is confirmed in [Q09](QUESTIONS.md#q09). Which similar fonts ship beyond IBM Plex is [Q08](QUESTIONS.md#q08).

Every substitution is recorded as an edit in the review list (a3-12) and announced with the "Font substituted" toast (a11-6). Bold and italic are never faked (a3-15).

### 6.8 Overflow

When the re-laid-out text needs more lines than the frame holds, the panel offers the design's three choices (a3-4):

- **Extend block by N lines.** The frame grows down. If it would overlap other content (the IBAN line under Madde 4), the option is disabled with the reason. That state is not drawn yet ([G38](DESIGN_GAPS.md#g38)).
- **Tighten spacing slightly.** Character or word spacing shrinks within a small cap (Proposed: 2%). If that is not enough, the option is disabled with the reason.
- **Keep and warn.** The block model keeps all the text. The saved content stream draws the lines that fit and writes the rest clipped to the frame, so no text is lost and nothing is drawn over neighbouring content. The warning stays in the review list and on the page thumbnail until resolved. Text clipped this way is listed by "Remove hidden information" (a8-3, P2).

The same machinery serves translation overflow later (a3-13b, P4). The labels are the brief's three labels everywhere ([G54](DESIGN_GAPS.md#g54)).

### 6.9 Signed documents

- ferman-core detects signatures at open: AcroForm `/SigFlags`, signature fields with values, DocMDP and certification signatures.
- Before the first change to a signed document (edit, comment, fill or organize), `begin_edit` returns `NeedsConfirmation` and the UI warns that the signature will become invalid. Without the confirmation token the engine refuses to commit. The dialog is not drawn yet; [G35](DESIGN_GAPS.md#g35) records the proposal ("Edit a copy" as default, "Edit anyway", "Cancel", then a persistent banner).
- An incremental update leaves the signed bytes intact, so the old revision still verifies, but validators report the document as changed after signing. A full rewrite breaks the signature outright.
- Signature validation is P3. Until then the Signatures tab lists signatures without a validity colour ([G31](DESIGN_GAPS.md#g31)).

### 6.10 Right-to-left text

- Logical text runs through the bidi algorithm per paragraph, with the base direction from the block. Numbers, dates and IBANs stay left-to-right and isolated.
- Runs are shaped with the font's GSUB and GPOS tables (rustybuzz per the brief, harfrust if [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md) is approved), producing glyph ids in visual order with advances and mark offsets.
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
- **Sandboxing (later):** if Ferman is ever sandboxed on macOS, the temp file comes from the system's item-replacement directory on the same volume and `replaceItemAtURL` performs the swap.
- atomic-write-file is evaluated against this table in M3. If it does not cover `ReplaceFileW` and metadata preservation, ferman-core implements the sequence directly.

### 7.3 Incremental update and full rewrite

- **Incremental (default).** The original bytes stay an exact prefix. It is fast, keeps signatures covering their bytes, and keeps old content inside the file. The design says so in a8-3 ("Content from before the last 2 saves is still inside the file").
- **Consequence for cropping:** content hidden by a crop is hidden, not removed, until a full rewrite or "Remove hidden information" ([G57](DESIGN_GAPS.md#g57)).
- **Optimize and clean (opt-in).** A full rewrite that drops earlier revisions, unreferenced objects and duplicate resources, and recompresses. It breaks signatures, so it warns first. Redaction (P2) always uses it (a8-2c: "rewritten without its 2 earlier saves").
- The Settings › Editing choice between the two is proposed in [G43](DESIGN_GAPS.md#g43).

### 7.4 Version history (M4)

The design keeps versions for 30 days in a hidden folder next to the file (a9-8, a11-1c). That folder is written with the same atomic sequence. Its location next to the file (sync folders, read-only directories) is decided with an ADR when M4 is planned.

### 7.5 External-change detection

- At open and after each save, the engine records size, modification time and SHA-256.
- Before saving it checks size and modification time. If either differs, it hashes the file again. If the hash differs, the save stops and the UI shows a11-7b (Reload, Keep mine, Compare first). Ferman does not pick a winner.
- **Proposed:** an OS file-change notification also triggers the check while the document is open, so the banner can appear before the user saves. The crate is chosen and licence-checked in M3.

### 7.6 Autosave journal and recovery

Location, per platform (the final folder name depends on the bundle identifier, [Q01](QUESTIONS.md#q01)):

- macOS: `~/Library/Application Support/<bundle id>/Recovery/`
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
- **Base copy (Proposed).** Recovery must not depend on the original staying unchanged. On the first unsaved change the engine stores a clone of the original (APFS `clonefile`, reflink on Btrfs, XFS or ReFS) or a plain copy for files up to 200 MB. Larger files on file systems without clones rely on the manifest hash; if the original changed, recovery reports a conflict ([G40](DESIGN_GAPS.md#g40) asks for that state in a1-12).
- **Encrypted documents.** Recovery data is written encrypted with the document's own key, as the file itself would be. Plaintext never reaches disk. Restoring asks for the password again (a1-8).
- **Privacy.** The recovery directory is created with owner-only permissions (0700 on Unix). Nothing in it is ever sent anywhere (a1-12: "Nothing was sent anywhere").
- **Cleanup.** Files for a document are deleted after a successful save, after "Don't save", and after "Discard" in a1-12.

### 7.7 Crash safety

- On launch, a session directory whose lock file names no live process belongs to a crashed session. The UI shows a1-12: "Ferman restored 2 documents", each checked; "Open 2 documents" or "Discard". Restored documents open as unsaved; files on disk are unchanged.
- A crash during step 6 of section 7.2 leaves either the old file or the new one, never a mix. A leftover temp file is deleted on the next save in that directory.
- A panic in a document actor stops that document only (section 8.3). The UI offers to reopen it from the journal.
- The crash log is written locally and copied only when the user presses "Copy crash log" (a1-12).

### 7.8 When writing fails

| Failure | Detection | Result | Design |
|---|---|---|---|
| Disk full | free-space check before writing (expected size plus margin), and `ENOSPC` or `ERROR_DISK_FULL` during the write | temp file deleted, original untouched, edits kept; "Try again" or "Save somewhere else…" | a11-7, f4 toast |
| Recovery copy also cannot be written | journal write fails | the dialog says honestly that no recovery copy exists | wording to draw ([G40](DESIGN_GAPS.md#g40)) |
| Read-only or permission denied | `EACCES`, `EROFS`, `ERROR_ACCESS_DENIED` | Save as offered | G40 |
| Locked by another app | sharing violation after retries | "Close it in the other app, or Save as…" | G40 |
| Rename failed | step 6 error | temp deleted, original untouched, Save as offered | G40 |
| Volume disappeared | I/O error on a network drive | edits kept, Save as offered | G40 |

## 8. Error handling

Fixed by brief §5 ([ADR 0010](adr/0010-error-handling-no-panics.md)).

### 8.1 Errors per crate

- Each crate has its own `thiserror` enum: `CoreError`, `FontError`, `TextError`, `RenderError`, `OpsError`. Variants carry context (object id, page, operator offset), never document text.
- No `unwrap`, `expect`, `panic`, `todo` or `unimplemented` in library code. Clippy enforces this with `unwrap_used`, `expect_used`, `panic`, `todo` and `unimplemented` denied outside tests. Parser modules also deny `indexing_slicing` and use checked arithmetic, because untrusted input must not be able to trigger a panic or a silent overflow.
- `forbid(unsafe_code)` at every crate root. pdfium-render is the unsafe layer. If ferman-render ever needs unsafe code (for example rendering into a caller-owned buffer), it is a documented, reviewed exception.
- Public items are documented. `cargo fmt` and `clippy -D warnings` run in CI.

### 8.2 Mapping to ApiError

| Kind | Typical cause | Design state |
|---|---|---|
| `NotFound` | file moved or deleted, stale handle | missing recent file ([G28](DESIGN_GAPS.md#g28)) |
| `PermissionDenied` | read-only file or folder | G28, G40 |
| `FileLocked` | open in another app | G40 |
| `DiskFull` | no space left | a11-7 |
| `FileChangedOnDisk` | external modification | a11-7b |
| `PasswordRequired`, `WrongPassword` | encrypted file | a1-8, a1-8b |
| `Restricted` | owner-password permissions | G27 |
| `Damaged` | unrecoverable file | a1-9b |
| `Unsupported` | XFA, certificate encryption, unknown filter | a11-7c |
| `NotEditable` | block cannot be edited | a3-11, G39 |
| `ConfirmationRequired` | signed document | G35 |
| `ResourceLimit` | a limit in section 9 | "too complex" message |
| `Cancelled` | job cancelled | none; expected |
| `Internal` | a bug or a caught panic | generic message plus "Copy technical details" |

- **Message keys.** The engine defines a `MessageKey` enum whose values are ARB keys (camelCase, for example `errorSaveDiskFull`). A CI test checks that every key exists in `app_en.arb` and `app_tr.arb`. The sentence states what happened and the way out; error codes never appear in it (a1-9b). Technical details stay secondary.

### 8.3 Panics at the boundary

- FRB v2 turns a panic in a Rust call into a Dart exception. ferman-api also wraps each actor and job entry point in `catch_unwind` as a last resort.
- A panic in a document actor marks that document as stopped: no more edits. The UI offers to reopen it from the recovery journal. Other documents are unaffected.
- The release profile keeps `panic = "unwind"`. With `abort`, every bug would become a crash that loses all open documents.
- A crash inside PDFium (C++) cannot be caught. The defences are fuzzing, the pinned binary, the recovery journal, and the helper-process option (section 4.4).

### 8.4 Logs

- The engine logs with `tracing`, the app with a thin Dart logger, both to local rotating files in the app's log directory (Proposed: five files of 5 MB). "Show log files" (a11-1k) opens the folder.
- Logs never contain document text, typed characters, passwords or rendered content. File paths may appear, because logs never leave the device.
- No telemetry, no crash reporting service, no analytics. Nothing is uploaded, ever.

## 9. Security

PDFs come from strangers. Every byte is untrusted.

### 9.1 Resource limits

All values are **Proposed** and live in one `Limits` struct, so tests and the CLI can tighten them.

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

- **Document JavaScript is never executed** (policy to confirm in [Q13](QUESTIONS.md#q13)). Ferman ships the non-V8, non-XFA PDFium build, so scripts cannot run. Calculated form fields therefore do not update themselves; the Fill panel will say so. Remove hidden information lists JavaScript as found ("Ferman never runs it", a8-3).
- **No network from document content.** No remote fonts, no URL file specifications fetched, no form submission, no prefetching of links.
- **Actions.** `/Launch` actions never run. A `/URI` link opens in the OS browser only when the user clicks it and sees the address first. Embedded files are never opened automatically.
- **Two parsers.** When lopdf and PDFium disagree on structure, the document opens read-only (section 5.1).
- **Passwords** are wiped from memory after key derivation. They are never logged and never written to disk.

### 9.3 Fuzzing and supply chain

- Every parser gets a cargo-fuzz target from the first parser in M2 (section 13.6). Fuzz runs in CI, and every crash becomes a regression test.
- cargo-deny checks licences, bans, advisories and sources (crates.io only) on every pull request ([ADR 0016](adr/0016-dependency-licence-policy.md)). Banned crates include `pdfium` (GPL-3.0), `mupdf`, `jbig2dec` and the poppler bindings.
- The PDFium archive is pinned by tag and SHA-256. Its builds are third-party and unsigned, so the hash check is mandatory.
- Dart packages are checked for licences with very_good_cli, because cargo-deny does not see them.

## 10. Privacy and network gateway

Fixed by brief §1 and §3: no account, no telemetry, documents never leave the device ([ADR 0015](adr/0015-privacy-and-network.md)).

### 10.1 The only network uses

| Use | In the brief | When it connects | Default | Milestone | What is sent |
|---|---|---|---|---|---|
| Update check | yes | once a day and on "Check now" | on; can be turned off (a11-1h, a11-1i) | M5 | version and platform, as a11-1h words it; endpoint and payload are [Q15](QUESTIONS.md#q15) |
| Language-pack downloads | yes, optional | only when the user starts a download (a11-1f) | used only on request | P3 (OCR packs) | the name of the pack |
| AI | yes, optional | only when the user turns on the assistant with their own key, or downloads a local model | off | P4 | the user's request, to the provider the user chose |
| Signature timestamp servers | yes | only when signing with a timestamp | allowed in a11-1h, used only when signing | P3 | a hash (RFC 3161), never the document |

UI translations are bundled with the app, not downloaded ([G52](DESIGN_GAPS.md#g52)).

The design also draws two uses the brief does not list: certificate revocation lookups (OCSP and CRL, "Signature checks" in a11-1h, [G51](DESIGN_GAPS.md#g51)) and local-network scanner discovery with phone pairing (a7-4, [G56](DESIGN_GAPS.md#g56)). Neither is enabled until the owner decides ([Q06](QUESTIONS.md#q06)). If they are built, each is off until first use and listed in Settings › Privacy.

### 10.2 One gateway

- One module in ferman-api (`net`) is the only code with an HTTP client dependency. It arrives with the update check in M5. A CI check fails if any other crate depends on an HTTP client.
- Every request names a purpose. The gateway checks the user's switch for that purpose, refuses if it is off, and writes a local entry to the network activity log linked from Settings › Privacy (a11-1h): time, purpose, host, bytes. The log never leaves the device.
- Requests carry no cookies, no identifiers and no account. They use TLS with the OS trust store and the OS proxy settings. The user agent is `Ferman/<version>`.
- The Dart side adds no networking packages. **Proposed:** CI fails if `pubspec.lock` contains a package from a deny list (HTTP clients, font downloaders such as google_fonts, analytics and crash-reporting SDKs).
- Onboarding lists all four uses (a1-2b currently lists only the update check, [G24](DESIGN_GAPS.md#g24)).
- OS-level checks the app does not control, such as code-signature checks by the OS, are outside this list.

## 11. Localization, RTL and fonts in the UI

Fixed by brief §1 and §6 ([ADR 0014](adr/0014-localization-and-rtl.md)).

### 11.1 Strings

- gen-l10n with ARB files in `app/lib/l10n/`. English is the source and Turkish is complete. Arabic is built in M1 to prove right-to-left. Other languages fall back to English until volunteers translate them through Weblate. Nothing is machine-translated silently.
- The language picker (a1-1) needs a "Not translated yet" state ([G20](DESIGN_GAPS.md#g20)).
- The engine never produces UI text (section 3.1). Strings with numbers use ICU plural and select forms.

### 11.2 Locale-aware casing

Dart's `toUpperCase` is not locale-aware, so "imzala" would become "IMZALA" instead of "İMZALA".

**Decision: a small pure-Dart casing utility in `app/lib/l10n/`.** It wraps Dart's case mapping and applies the language-specific rules of Unicode SpecialCasing for Turkish and Azerbaijani: i ↔ İ, ı ↔ I, and the combining dot above. Reasons:

- Casing happens while widgets build. A synchronous FFI call on the build path would break the rule that the UI isolate makes no sync engine calls.
- Widget tests and goldens run without the native library. A Dart utility works there; a bridge call does not.
- The rule set the 21 UI languages need is small and stable. The design uses sentence case, so title-casing rules (such as Dutch IJ) are not needed.
- It works unchanged in the web build later.

ICU4X stays in the engine (`icu_casemap` for search folding, `icu_collator` for sorting), where document text is processed. A test generates a table of cases with ICU4X and checks the Dart utility against it, so both agree. Locale-aware sorting of lists (recents, fonts) calls the engine's collator asynchronously; it is not on any per-frame path.

### 11.3 Numbers, dates and units

- Numbers, dates, paper sizes and units come from the **region setting** (a11-1b), never from the UI language ([G34](DESIGN_GAPS.md#g34)). With the Türkiye region an English UI shows "13.10.2026 · 14:32", "18.500,50" and "10,5 pt".
- The digit system follows the region (for example Arabic-Indic digits for an Arabic region, as in a12-1ar).
- The engine returns raw numbers (points, bytes, counts). Dart formats them with intl using the region locale.
- Mixed-direction values (dates and numbers inside RTL text) are isolated (a12-2c).

### 11.4 Right to left

- `EdgeInsetsDirectional` and `AlignmentDirectional` everywhere. Directional icons (chevrons, arrows, undo and redo) mirror. The list of icons to flip comes from the design.
- **The PDF canvas is never mirrored.** Page content, page order in spreads (from the document's direction, G32) and on-page marks stay as the document defines them. The frame label starts on the document block's own start side (f1). Grid and thumbnail reading order follows the UI direction, but thumbnail content is never mirrored.

### 11.5 Fonts in the UI

Bundled: IBM's unmodified static TTFs under OFL-1.1, with the Reserved Font Name "Plex" respected: never subset, renamed or modified ([ADR 0013](adr/0013-fonts-and-icons.md), [G06](DESIGN_GAPS.md#g06)). The design's woff2 subsets and its runtime Google Fonts import are never used ([G07](DESIGN_GAPS.md#g07)).

| UI language | First font | Fallback chain |
|---|---|---|
| Latin and Cyrillic (en, tr, de, fr, es, pt-BR, it, nl, pl, ru, uk, id, vi) | IBM Plex Sans 400/500/600 | system UI font |
| ar, fa | IBM Plex Sans Arabic | IBM Plex Sans (Latin inside Arabic text) → system |
| he | IBM Plex Sans Hebrew (Proposed, [Q08](QUESTIONS.md#q08)) | IBM Plex Sans → system |
| hi | IBM Plex Sans Devanagari (Proposed, Q08) | IBM Plex Sans → system |
| ja | IBM Plex Sans for Latin | Hiragino Sans (macOS), Yu Gothic UI (Windows), Noto Sans CJK JP (Linux) |
| ko | IBM Plex Sans for Latin | Apple SD Gothic Neo, Malgun Gothic, Noto Sans CJK KR |
| zh-Hans | IBM Plex Sans for Latin | PingFang SC, Microsoft YaHei UI, Noto Sans CJK SC |
| zh-Hant | IBM Plex Sans for Latin | PingFang TC, Microsoft JhengHei UI, Noto Sans CJK TC |

- The text locale is set on every text style, so Han characters take the right regional forms (Traditional Chinese must not show Simplified forms, G07).
- IBM Plex Mono is used for technical details (a1-9b). IBM Plex Serif is bundled for the design's specimens and as a similar-font candidate.
- UI fonts never affect page rendering. PDF pages are drawn by PDFium with the document's own fonts.

## 12. Platform integration

Desktop first: macOS and Windows, Linux best effort (brief §1).

- **Window chrome.** window_manager hides the native title bar. Ferman draws the title bar as designed: macOS traffic lights in place, Windows caption buttons per f6. On Windows 11, custom caption buttons lose the snap-layout flyout unless the maximize button area is reported to the OS; this needs a small native hook (risk, section 15). Linux has no drawn chrome; client-side decorations are proposed in [G15](DESIGN_GAPS.md#g15), pending [Q12](QUESTIONS.md#q12).
- **File associations and "Open with".** macOS declares PDF in `Info.plist` and receives open events from the OS, routed to Dart through a method channel. Windows registers a ProgID in the installer (M5) and receives the path on the command line. A second launch forwards its paths to the running instance over a local channel (a named pipe on Windows, a Unix socket on Linux; macOS routes to the running app itself). The file opens as a new tab, or focuses the tab if it is already open. These states are not drawn yet ([G25](DESIGN_GAPS.md#g25)).
- **Default PDF app** (a1-3, M2). macOS asks the system to make Ferman the default handler, and the system asks the user to confirm. Windows opens Settings › Default apps, because apps cannot change the default themselves.
- **Drag and drop.** desktop_drop on the start screen, the tab strip and the page grid (a1-6). Until conversion exists, non-PDF files show "Can't open yet" with "Available in a future version" ([G11](DESIGN_GAPS.md#g11)).
- **File pickers.** OS-native open, save and folder pickers through file_selector: NSOpenPanel and NSSavePanel, IFileOpenDialog and IFileSaveDialog, xdg-desktop-portal on Linux. This is the only exception to the custom-dialog rule, **proposed** in [ADR 0018](adr/0018-native-file-pickers.md) ([Q07](QUESTIONS.md#q07)). Every other dialog is a Ferman component.
- **Printing.** Basic system print is proposed for M4 ([Q10](QUESTIONS.md#q10)): Ferman hands the document to the OS print dialog, with "Use system dialog…" one click away (a9-6). Booklet, poster and separations are proposed for P5. The package is chosen and licence-checked in M4.
- **PDFium bundling.**
  - macOS: `libpdfium.dylib` (arm64 and x64 combined into one universal file) in `Contents/Frameworks`, signed with the app's Developer ID under the hardened runtime and notarized with the app.
  - Windows: `pdfium.dll` (x64, arm64) next to the executable, Authenticode-signed with the app, so security tools do not flag an unsigned third-party binary.
  - Linux: `libpdfium.so` (x64, arm64) in a `lib/` folder found through an `$ORIGIN` run path.
  - The `licences/` folder of the PDFium build ships with the app and appears in the third-party notices ([G14](DESIGN_GAPS.md#g14)). If the library is missing, Ferman shows an error screen instead of crashing.
- **Code signing** needs the publisher name ([Q02](QUESTIONS.md#q02)). Minimum OS versions ([Q03](QUESTIONS.md#q03)) decide which OS APIs above can be used without fallbacks.
- **Settings window.** a11-1 draws Settings as its own window. If desktop multi-window support is not stable in the pinned Flutter version, Settings opens as a window-styled surface inside the main window, and real windows follow later.
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
- **Generated files** (tools/corpus, deterministic) mirror the design's sample documents: the Turkish rental contract with a subset font missing "ğ" and a tight frame above the IBAN line; the bank statement; the one-page e-Devlet form ([G59](DESIGN_GAPS.md#g59)); the 2,400-page report for progressive open; a truncated file; an AES-256 payslip whose password contains Turkish letters; an XFA-only form; a 12-page Arabic report with mixed numbers; a Japanese letter with vertical text; scanned Turkish pages; signed variants, including one changed after signing.
- **Real-world files** under free licences, as brief §5 lists: Word, Google Docs, LibreOffice, LaTeX, scanned, forms, signed, encrypted, damaged.

### 13.4 Pixel-diff acceptance for every edit

The rule from brief §4: render before and after with PDFium; the pixel difference outside the edited region must be exactly zero.

1. Each case is a corpus file plus an edit script (page, block selector, operations, expected outcome).
2. Render the page before editing at fixed resolutions (72, 150 and 300 dpi) with the fixed render flags.
3. Apply the edit through the facade and save incrementally to a temp file.
4. Reopen the saved file **from disk** and render the same page.
5. The edited region is the union of the block's bounding box before and after the edit, including an extended frame, in device pixels after page rotation. **Proposed:** it grows by 2 device pixels for anti-aliasing, and that margin is documented in the test.
6. Assert zero differing pixels outside the region. Also assert: every other page renders identically, content-stream bytes outside the block's spans are identical, every other object is byte-identical, and the original file is an exact prefix of the saved file.
7. Required cases: Turkish (ğ, ş, İ, ı in WinAnsi with `/Differences`, subset TrueType and Identity-H fonts), Arabic with RTL shaping (joining forms, lam-alef, marks, IBAN isolation), Persian with ZWNJ, CJK (Identity-H and Identity-V, vertical text), justified paragraphs, `TJ` kerning, multi-column layouts, rotated pages and rotated text, text inside Form XObjects, marked content with `/ActualText`, the missing-glyph steps and the overflow choices.
8. `ferman verify-edit` runs one case from the command line.

### 13.5 Flutter tests

- Widget tests for every component and screen, with very_good_analysis lints and `flutter analyze` clean.
- **Goldens** with alchemist for every implemented screen in light and dark × en, tr and ar, with the real bundled fonts loaded (text is never obscured). Goldens are generated on the Linux CI runner only, so font rasterisation does not vary between machines. Other runners run widget tests without goldens.
- **Design-reference comparison.** tools/design-refs renders each artboard to `build/design-refs/`. A comparison script lines up each golden with its artboard and reports a perceptual difference score. **Proposed:** in M1 the score is reported in the pull request and reviewed by a person, not used as a gate.
- integration_test runs desktop flows against the real engine from M3, starting with Flow A (open, fix a typo, save).

### 13.6 Fuzz targets

One target per parser, starting with the first parser in M2: object lexer and parser, cross-reference and trailer (including repair), content-stream lexer, interpreter, each stream filter (Flate, LZW, ASCII85, ASCIIHex, RunLength), CMap and ToUnicode, Type1 parser, encryption and password handling, incremental writer round trip, and "open arbitrary bytes" through the facade. CI runs a short session on every pull request and a longer one nightly. Crashes become regression files in the corpus.

### 13.7 Benchmarks

criterion benchmarks for open, page sizes, first-page render, tile render, text model per page, edit apply and save. They feed the CI guards in section 14.

### 13.8 CI matrix

GitHub Actions on macOS, Windows and Linux: Rust fmt, clippy and test, cargo-deny, Flutter analyze and test, desktop build. Linux also runs goldens, the fuzz smoke run and benchmarks. CI stays green; a red main branch is fixed before anything else.

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
| Cold start (Proposed) | start screen interactive under 1.5 s | process start to first interactive frame | R1, R2 | tracked, not gated |

CI runners are slower and noisier than reference hardware. **Proposed:** each CI budget is the reference budget times a calibration factor measured per runner type. A benchmark more than 15% slower than the stored baseline for three runs in a row fails the job, from M2 on.

## 15. Risks and open questions

| Risk | Impact | Mitigation | Link |
|---|---|---|---|
| rustybuzz is archived upstream | no fixes for the shaper the brief names | ADR 0007 proposes harfrust behind one internal trait | [Q04](QUESTIONS.md#q04) |
| lopdf breaks its API almost monthly | upgrade churn, behaviour changes | pin `=0.45`; wrap it inside ferman-core; upgrade deliberately with the corpus as a safety net | [ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md) |
| PDFium is not thread-safe and runs in-process | throughput limit; a PDFium crash ends the app | one render thread plus the global lock; recovery journal; helper processes if M2 measurements demand it | section 4.4 |
| lopdf and PDFium disagree on damaged files | the user sees content the model does not contain | read-only on disagreement; repair is a full rewrite to a new file | section 5.2 |
| Font stack versions split (skrifa and read-fonts for harfrust versus subsetter and krilla) | two copies in the binary; handles not interchangeable | pin exact versions; upgrade the font crates together | [DEPENDENCIES.md](DEPENDENCIES.md) |
| FRB zero-copy and executor behaviour not yet measured | tile transfer could exceed the frame budget | M1 benchmark; texture-registry fallback | section 3.4 |
| One PDFium reload per edit on very large files | edit-to-render above 100 ms | custom reader without copies; render only changed pages; measure in M3 | section 14 |
| IME and caret handling on a custom canvas | broken CJK and dead-key input | `DeltaTextInputClient` from the first M3 prototype; CJK cases in integration tests | section 6.12 |
| Windows custom caption buttons lose snap layouts | platform behaviour regresses | native hit-test hook for the maximize button | section 12 |
| Version history folder next to the file (a9-8) | sync conflicts, read-only folders | decide with an ADR when M4 is planned | section 7.4 |
| OCR engine (ocrs is a Latin-only preview with an unclear model licence) | Turkish and other scripts poorly recognised | decide before P3; Tesseract is the fallback | [Q16](QUESTIONS.md#q16) |
| Unsigned third-party PDFium builds | supply-chain risk | pinned tag and SHA-256; sign with the app | section 12 |

Open questions that affect this design are all in [QUESTIONS.md](QUESTIONS.md):

- Paths, signing and OS APIs: [Q01](QUESTIONS.md#q01) bundle identifier, [Q02](QUESTIONS.md#q02) code-signing publisher name, [Q03](QUESTIONS.md#q03) minimum macOS, Windows and Linux versions.
- Fonts and text: [Q04](QUESTIONS.md#q04) harfrust instead of rustybuzz, [Q08](QUESTIONS.md#q08) bundling Plex Hebrew and Devanagari, CJK system fonts and handwriting fonts, [Q09](QUESTIONS.md#q09) missing-glyph default as designed.
- Privacy and security: [Q06](QUESTIONS.md#q06) OCSP, CRL and local-network discovery, [Q13](QUESTIONS.md#q13) document JavaScript never executed, [Q15](QUESTIONS.md#q15) update-check endpoint and payload.
- Shell and platform: [Q05](QUESTIONS.md#q05) eight mode tabs including Tools, [Q07](QUESTIONS.md#q07) OS-native file pickers, [Q12](QUESTIONS.md#q12) Linux packaging and window chrome.
- Scope: [Q10](QUESTIONS.md#q10) milestones for unscheduled drawn features, [Q11](QUESTIONS.md#q11) design re-export and design-gap decisions, [Q14](QUESTIONS.md#q14) copyright holder "The Ferman Authors", [Q16](QUESTIONS.md#q16) OCR engine choice.
