---
paths:
  - "crates/**/*"
  - "fuzz/**/*"
  - "Cargo.toml"
  - "Cargo.lock"
  - "deny.toml"
  - "rust-toolchain.toml"
---

# Rust rules

These rules apply to the engine crates, the fuzz workspace and the workspace files. Everything in [CLAUDE.md](../../CLAUDE.md) still applies. Background: [ARCHITECTURE.md](../../docs/ARCHITECTURE.md) and the ADRs in [docs/adr/](../../docs/adr/README.md).

## Toolchain and pinned versions

- Rust stable 1.99, pinned with `rust-toolchain.toml` (created in M1).
- lopdf `=0.45`. It ships breaking releases almost monthly, so bump it on purpose, with a full corpus and pixel-diff run.
- pdfium-render 0.9.4 with the prebuilt bblanchon/pdfium-binaries tag `chromium/7881` (non-V8, non-XFA build). `tools/pdfium` fetches it and checks a pinned SHA-256 per archive. The PDFium `licences/` folder ships with the app.
- flutter_rust_bridge `=2.13.0`. The Rust crate, the Dart package and `flutter_rust_bridge_codegen` must have exactly the same version; CI compares them.
- Shaping: the brief names rustybuzz, which is archived upstream. [ADR 0007](../../docs/adr/0007-harfrust-instead-of-rustybuzz.md) proposes harfrust ([Q04](../../docs/QUESTIONS.md#q04)). Until the owner approves it, the brief's rustybuzz stands. Keep the shaper behind the internal `Shaper` trait in ferman-fonts, so the switch touches one module.
- Fonts otherwise use the brief's crates: skrifa and read-fonts (parsing), subsetter (subsetting), fontdb (system fonts).
- `image` is built with default features off.
- Never add the `pdfium` crate (GPL-3.0, not pdfium-render), mupdf, jbig2dec, poppler or xpdf bindings, or magick_rust.

## Errors and panics

- No `unwrap`, `expect`, `panic!`, `todo!` or `unimplemented!` in library code. Enforce it with workspace Clippy lints (`unwrap_used`, `expect_used`, `panic`, `todo`, `unimplemented` denied in library crates). Tests may unwrap (`allow-unwrap-in-tests` and `allow-expect-in-tests` in `clippy.toml`). See [ADR 0010](../../docs/adr/0010-error-handling-no-panics.md).
- No unchecked indexing or slicing: use `get` and checked arithmetic. `clippy::indexing_slicing` and `clippy::arithmetic_side_effects` are denied in parser and decoder modules (lexer, xref, filters, CMaps, font parsing, interpreter). Sizes and offsets read from files always use checked arithmetic.
- One `thiserror` error type per crate (`CoreError`, `FontError`, `TextError`, `RenderError`, …). ferman-api maps them to `ApiError { kind, message_key, details }`.
- No localized text leaves the engine. Errors and notices carry message keys with parameters; Dart formats them.
- `catch_unwind` is used only at the ferman-api actor and job entry points, as a last resort. The release profile keeps `panic = "unwind"`.
- Logs (`tracing`) stay on the device and never contain document text, typed characters, passwords or rendered content.

## Style and documentation

- `cargo fmt --all` before every commit; `cargo clippy --workspace --all-targets -- -D warnings` is clean.
- Every public item is documented. `missing_docs` is on for every library crate (`#![deny(missing_docs)]` or the workspace lint) and fails CI.
- The crate graph follows [ARCHITECTURE.md §2.2](../../docs/ARCHITECTURE.md#22-dependency-graph). ferman-core and ferman-fonts depend on no other Ferman crate. A new edge needs an ADR.

## API boundary

- Only ferman-api is UI-facing. FRB codegen scans only its `frb` module; the facade is pure Rust. ferman-cli and the integration tests use the facade with the `frb` feature off.
- Only plain data crosses: integers, floats, strings, enums, byte vectors and structs of those, plus opaque `u64` handles. Geometry is in page space. lopdf types, PDF matrices and PDFium objects never cross.
- Every API function is async or returns a stream, except `api_version()`.
- Never block in an async FRB function. It validates input, sends a message to the right actor or queue, and awaits the reply.
- The surface is the brief's: open and close, page info, tile rendering, text blocks, edit transactions (begin/apply/commit/rollback with engine-level undo and redo) and jobs (OCR, convert, compress, batch) that are async, cancellable and stream progress.

## Threading

The model is Proposed in [ADR 0009](../../docs/adr/0009-threading-and-jobs.md); the brief fixes the outcome: rendering and heavy work never run on the UI thread.

- PDFium is not thread-safe. Only ferman-render links it, and every PDFium call runs on its single render thread. pdfium-render's `thread_safe` feature (one global lock) stays on as a second guard.
- lopdf is the source of truth. PDFium only rasterises: it reloads the revised bytes after a pixel-changing commit and never writes.
- One actor per open document serialises mutations and publishes immutable snapshots. Readers (render thread, jobs, text queries) hold snapshots and never block the actor.
- Tiles go through the prioritised, cancellable tile queue. Long work runs as a job on the job pool, never on FRB worker threads.

## Text editing

Brief §4 is the hardest part and must be flawless ([ADR 0005](../../docs/adr/0005-block-scoped-text-editing.md), [ADR 0006](../../docs/adr/0006-font-pipeline-and-missing-glyphs.md), [ARCHITECTURE.md §6](../../docs/ARCHITECTURE.md#6-text-editing-pipeline)).

- **Interpreter coverage:** full graphics and text state: `q`/`Q`, `cm`, `BT`/`ET`, `Tf`, `Tm`, `Td`, `TD`, `T*`, `TL`, `Tc`, `Tw`, `Tz`, `Ts`, `Tj`, `TJ`, `'`, `"`. Form XObjects recursively, with cycle detection and a depth limit. Marked content (`BMC`, `BDC`, `EMC`, `/ActualText`). Every operator keeps its byte span.
- **Fonts and encodings:** Type1, TrueType, Type3 and Type0/CID; Standard, WinAnsi, MacRoman, `/Differences`, Identity-H/V and CMaps; ToUnicode; widths from `/Widths`, `/W` and `/DW`. Positions come from the PDF widths, not the font program.
- **Byte preservation:** an edit rewrites only the operators of the edited block. Every other byte of the page content, and every other object, stays identical. After an incremental save the original file is an exact prefix of the new one.
- **Encoding:** text is re-encoded in the font's own encoding. After the replacement, the text state, matrices, colour and `q` depth equal what the original block left behind.
- **Missing glyphs:** (1) use the embedded glyph if present (if the encoding has no code for it, add one through `/Differences` in a new font dictionary used only by the edited block); (2) if the same font is installed, take the glyph from it, re-subset and embed it in a new font used only by the edited runs, and say so once; (3) otherwise offer similar fonts exactly as the design shows (a3-3a, a3-3b, a11-1c). Never substitute silently. Never modify the original subset, and respect the font's embedding permissions.
- **Overflow:** the brief's three choices as a3-4 draws them: "Extend block by N line(s)", "Tighten spacing slightly (−x%)", "Keep and warn". The engine computes the line count and the spacing change for the block, and Extend is disabled with a reason if it would overlap other content ([G38](../../docs/DESIGN_GAPS.md#g38)).
- **Signed documents:** the first change to a signed document returns a confirmation request, so the UI warns that the signature will become invalid. The engine refuses to commit without that confirmation ([G35](../../docs/DESIGN_GAPS.md#g35)).
- **Acceptance test for every edit operation:** render before and after with PDFium (reopening the saved file from disk); zero differing pixels outside the edited region. Cases include Turkish (ğ, ş, İ, ı), Arabic with RTL shaping and CJK (Identity-H/V, vertical text). An edit operation without this test is not done.

## Untrusted input and files

- Every PDF is untrusted. Respect the `Limits` struct (nesting, recursion, decoded size, operator count, time) in [ARCHITECTURE.md §9](../../docs/ARCHITECTURE.md#9-security).
- Document JavaScript is never executed; `/Launch` actions never run; document content never triggers network access (policy to confirm in [Q13](../../docs/QUESTIONS.md#q13)).
- Write files only through ferman-core's safe save module: temp file in the target directory, flush, verify, atomic rename (`ReplaceFileW` on Windows). Never write in place. Incremental update is the default. Autosave and recovery go to the app data directory ([ADR 0008](../../docs/adr/0008-file-safety-and-saving.md)).

## Tests

- Unit tests next to the code; integration tests in `crates/*/tests/` through public APIs. The full open, edit, save and reopen path is tested through the ferman-api facade.
- A cargo-fuzz target for every parser, from the first parser in M2, including third-party parsers reached through our wrappers (lopdf through ferman-core, skrifa and read-fonts through ferman-fonts, image decoders): object lexer and parser, xref and trailer paths (including repair), content-stream lexer and interpreter, stream filters, CMap and ToUnicode, the Type1 parser and font program parsing, encryption, incremental writer round trip, and "open arbitrary bytes" through the facade. Crashes become regression files in the corpus. `fuzz/` is a separate workspace, so `libfuzzer-sys` (NCSA) never ships.
- Property tests (proptest) for every encoder and decoder: lexer round trip, encode and decode for every encoding, edit then revert gives identical bytes, written incremental updates parse back to the same objects.
- Every corpus file has its source, licence, SHA-256 and purpose in `tests/corpus/README.md`.

## Performance

- criterion benchmarks for open, page sizes, first-page render, tile render, text model, edit apply and save.
- Budgets from the brief: first page visible in under 1 s for a 500-page document; 60 fps scrolling and zooming; edit-to-render under 100 ms. The full table and CI guards are in [ARCHITECTURE.md §14](../../docs/ARCHITECTURE.md#14-performance-budgets).

## Dependencies

- Any dependency change updates [DEPENDENCIES.md](../../docs/DEPENDENCIES.md) (version, SPDX licence, milestone, purpose) in the same commit and passes `cargo deny check` (licences, bans, advisories, sources).
- Allowed licences and bans are in [ADR 0016](../../docs/adr/0016-dependency-licence-policy.md). Ask the owner before adding a dependency with an unusual licence.
- Add later-phase crates only in their phase: signing (cms, x509-cert, cryptoki, rsa) and OCR (ocrs, rten; engine choice open in [Q16](../../docs/QUESTIONS.md#q16)) in P3, krilla in P4. Verify each before use.
