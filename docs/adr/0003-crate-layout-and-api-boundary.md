# ADR 0003: Crate layout and the ferman-api boundary

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §3
- **Supersedes:** none
- **Superseded by:** none

## Context

The brief gives the repository tree and the responsibility of each crate ([brief §3](../BRIEF.md)):

```text
crates/
├── ferman-core/   document model, parsing/writing (lopdf), content-stream interpreter, incremental save
├── ferman-render/ page rendering with pdfium-render, tiles, thumbnails, caches
├── ferman-text/   text layout model: glyphs → words → lines → paragraphs/columns; hit testing; editing; reflow
├── ferman-fonts/  font parsing (skrifa/read-fonts), shaping (rustybuzz), subsetting (subsetter), system fonts (fontdb), coverage and substitution
├── ferman-ops/    organize pages, annotations, forms, watermark, redaction, compress… (split into more crates as it grows)
├── ferman-api/    the ONLY crate the UI calls (flutter_rust_bridge surface)
└── ferman-cli/    `ferman` CLI exposing the same operations (testing and power users)
```

Its engine rules: the UI never touches PDF internals, and ferman-api exposes open and close, page
info, tile rendering, text blocks, edit transactions (begin, apply, commit, rollback, which give
engine-level undo and redo) and jobs (OCR, convert, compress, batch) that are async, cancellable and
stream progress.

Two things need settling that the tree leaves open: which crate depends on which, and how the CLI can
offer "the same operations" without going through the Flutter bridge.

## Decision

### The crates

We will create exactly the seven crates of the brief, with the brief's names and responsibilities, in
one Cargo workspace at the repository root (from M1). Shared versions live in
`[workspace.dependencies]` and shared lints in `[workspace.lints]` ([ADR 0010](0010-error-handling-no-panics.md)).

### Dependency graph

```text
ferman-cli ─────► ferman-api (facade only; the frb feature is off)
ferman-api ─────► ferman-ops, ferman-render, ferman-text, ferman-fonts, ferman-core
ferman-ops ─────► ferman-text, ferman-fonts, ferman-core
ferman-text ────► ferman-fonts, ferman-core
ferman-render ──► ferman-core
ferman-core ────► no Ferman crate
ferman-fonts ───► no Ferman crate (works on font program bytes; PDF-agnostic)
```

- Edges only point down this list. No cycles.
- ferman-render is the only crate that links PDFium, and only ferman-api depends on it. Operations that
  need pixels (OCR, the redaction check, visual compare) get them through ferman-api.
- ferman-core needs glyph widths to move the text matrix. It asks through a trait that ferman-text
  implements, so core holds no font code.
- **Proposed:** a CI script reads `cargo metadata` and fails on any edge not in this table (from M1,
  as in [ARCHITECTURE.md](../ARCHITECTURE.md) section 2.2).

### ferman-api is the only boundary

- ferman-api has two layers:
  - **facade**: plain Rust, always built. The `Engine`, handles, data types, `ApiError`, document
    actors, the job manager and, from M5, the network gateway ([ADR 0015](0015-privacy-and-network.md)).
  - **frb**: behind the `frb` feature, on in the app build. Thin wrappers that expose facade functions to
    Dart, plus stream sinks. Nothing else lives there. FRB codegen scans only this module.
- Only ferman-api depends on flutter_rust_bridge. The Flutter app imports only the generated bindings
  for ferman-api, and only through its `app/lib/engine/` services.
- What crosses the boundary is plain data: integers, floats, strings, enums, byte vectors and structs
  of those. Handles (`DocumentId`, `ViewId`, `TxnId`, `JobId`, `RevisionId`, `BlockId`) are integer
  newtypes created by the engine, never pointers. Closing a document is explicit, never left to a
  finalizer, because it has visible effects (the unsaved-changes prompt, a1-10b).
- The UI never sees lopdf objects, object numbers, content streams, operators, font programs, glyph
  ids, PDFium handles or PDF matrices. Geometry crosses in one page space (points, top-left origin,
  after CropBox, rotation and UserUnit).
- No localized text crosses. The engine returns message keys with parameters
  ([ADR 0010](0010-error-handling-no-panics.md), [ADR 0014](0014-localization-and-rtl.md)).
- Every call is async or a stream, except the API version check.

### The CLI uses the same facade

ferman-cli depends on ferman-api with the `frb` feature off and calls the facade directly. It never goes
through FFI. Anything the app can do through ferman-api, the CLI can expose with the same code path,
which makes the CLI the main harness for integration tests and the pixel-diff acceptance runs
([ADR 0005](0005-block-scoped-text-editing.md)).

### Growing ferman-ops

As the brief says, ferman-ops splits into more crates as it grows. A split is due when a family of
operations brings a heavy or sensitive dependency set, or grows large enough to slow builds. Expected
splits: signing (P3: cms, x509-cert, cryptoki), OCR (P3), conversion (P3) and PDF/A (P4: krilla). Each
new crate sits at the ferman-ops level of the graph and is reached only through ferman-api. A split is
recorded in [ARCHITECTURE.md](../ARCHITECTURE.md). It needs no owner approval because the brief
allows it, but it must not move responsibilities between the other six crates. Moving those is an
architectural change and needs a Proposed ADR.

### Outside crates/

- `fuzz/` is a separate cargo-fuzz workspace, so fuzzing dependencies never enter the shipped graph
  ([ADR 0017](0017-testing-and-ci.md)). It is not in the brief's tree; it is the standard cargo-fuzz
  location.
- `tools/` holds the token generator, the icon exporter, the design-reference renderer, the PDFium
  fetcher and corpus scripts. `tests/corpus/` holds test PDFs with provenance.

## Consequences

### Positive

- One door to the engine. The UI cannot depend on PDF internals, so engine refactors do not ripple into
  Dart.
- ferman-fonts and ferman-core build and test alone, which keeps fuzz targets small and fast.
- PDFium stays behind one crate, which limits where its thread-safety rules matter
  ([ADR 0009](0009-threading-and-jobs.md)).
- The CLI exercises the real code path, so engine tests do not need Flutter.

### Negative

- Data types are defined twice in practice: once in the internal crates and once as facade types. The
  mapping code is boring but necessary.
- Integer handles need explicit lifetime management on both sides. A stale handle must return
  `NotFound`, never undefined behaviour.
- Composition in ferman-api (for example pixels for OCR) makes that crate large. We keep its modules thin
  and push logic down into the lower crates.

### Follow-up

- M1: workspace skeleton with all seven crates, the proposed dependency check, and the FRB surface
  `api_version()` and `engine_info()` (plus settings only if M1 step 9 keeps settings in the Rust core,
  [ROADMAP.md](../ROADMAP.md)). Recent files arrive in M2.
- M2 onward: the API grows feature by feature. The data type sketches in
  [ARCHITECTURE.md](../ARCHITECTURE.md) section 3 settle as they are implemented.

## Alternatives considered

- **One big engine crate.** Simpler to start, but slower builds, no enforced layering and harder
  fuzzing.
- **Let the UI call several crates.** Breaks the brief's rule and would spread FRB annotations across
  the engine.
- **CLI through FFI or a separate service.** Adds a layer with no benefit; the facade is already plain
  Rust.
- **FRB opaque handles for documents.** Convenient, but closing a document must be an explicit user
  action, not garbage collection. Integer handles keep that control.

## References

- [Brief](../BRIEF.md) §3, §5
- [ARCHITECTURE.md](../ARCHITECTURE.md), sections 2 and 3
- [ADR 0002](0002-rust-engine-flutter-ui-frb.md), [ADR 0004](0004-lopdf-model-pdfium-renderer.md),
  [ADR 0005](0005-block-scoped-text-editing.md), [ADR 0009](0009-threading-and-jobs.md),
  [ADR 0010](0010-error-handling-no-panics.md), [ADR 0015](0015-privacy-and-network.md),
  [ADR 0017](0017-testing-and-ci.md)
