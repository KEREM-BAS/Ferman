---
paths:
  - "crates/**/*"
  - "fuzz/**/*"
  - "tools/corpus/**/*"
  - "Cargo.toml"
  - "Cargo.lock"
  - "deny.toml"
  - "rust-toolchain.toml"
---

# Rust rules

These rules apply to the engine crates, the fuzz and corpus workspaces and the workspace files. Everything in [CLAUDE.md](../../CLAUDE.md) still applies. Background: [ARCHITECTURE.md](../../docs/ARCHITECTURE.md) and the ADRs in [docs/adr/](../../docs/adr/README.md).

## Toolchain and pinned versions

- Rust 1.99.0, pinned in `rust-toolchain.toml` with rustfmt and clippy; CI installs it with `rustup toolchain install`, and cargokit builds the app's engine with it (a "Ferman patch" in `app/rust_builder/`). `rust-version = "1.88"` in the workspace `Cargo.toml` is the floor, raised in the same commit as a crate that needs more.
- Ferman's own crates are path dependencies without a version requirement in `[workspace.dependencies]` (`deny.toml` sets `allow-wildcard-paths`), so a version bump touches only `[workspace.package]`.
- lopdf `=0.45`, default features off. It ships breaking releases almost monthly, so bump it on purpose, with a full corpus and pixel-diff run. Only ferman-core depends on it (a single door of the `crate_graph` check), and lopdf types never leave it. ferman-core reads the cross-reference data, repairs and decrypts itself, and hands lopdf a clean table: lopdf 0.45 loads a table with wrong offsets as an empty document and copies passwords into buffers it never wipes. Recheck both on an upgrade ([ARCHITECTURE.md §5.1](../../docs/ARCHITECTURE.md#51-open)).
- pdfium-render `=0.9.4` (default features off; `pdfium_7881` and `thread_safe`; **Proposed** with the M2 plan: `image_025` stays off, because PDFium renders tiles straight into ferman-render's own buffer through `PdfBitmap::from_bytes`, which needs no feature) with the prebuilt bblanchon/pdfium-binaries tag `chromium/7881` (non-V8, non-XFA build). Its bindings are process-wide and never unbound, so ferman-render binds one library per process, from an absolute path, behind a lock, and lets one render thread hold PDFium at a time. `tools/pdfium` fetches it and checks a pinned SHA-256 per archive. The archive's `licenses/` folder (PDFium's own licence is `licenses/pdfium.txt`) and the packager's MIT `LICENSE` ship with the app.
- flutter_rust_bridge `=2.13.0`. The Rust crate, the Dart package and `flutter_rust_bridge_codegen` must have exactly the same version; CI compares them. After a change to the `frb` module, regenerate the bindings (`src/frb_generated.rs` and `app/lib/bridge/`) with `(cd app && flutter_rust_bridge_codegen generate) && cargo fmt -p ferman-api` (codegen 2.13.0 needs cargo-expand 1.0.127); the CI codegen job fails on any diff.
- Shaping: harfrust, pinned exactly, as [ADR 0007](../../docs/adr/0007-harfrust-instead-of-rustybuzz.md) decides (accepted by the owner on 2026-10-15, [Q04](../../docs/QUESTIONS.md#q04)). Never add rustybuzz as a direct dependency: `deny.toml` bans it except as krilla's wrapper (`{ crate = "rustybuzz", wrappers = ["krilla"] }`). Keep the shaper behind the internal `Shaper` trait in ferman-fonts; nothing outside ferman-fonts names the shaping crate.
- Fonts otherwise use the brief's crates: skrifa and read-fonts (parsing), subsetter (subsetting), fontdb (system fonts).
- `image` is built with default features off.
- Never add the `pdfium` crate (GPL-3.0, not pdfium-render), mupdf, jbig2dec, poppler or xpdf bindings, or magick_rust.

## Errors and panics

- No `unwrap`, `expect`, `panic!`, `todo!` or `unimplemented!` in library code. Enforce it with workspace Clippy lints (`unwrap_used`, `expect_used`, `panic`, `todo`, `unimplemented` denied in library crates). Tests may unwrap, expect and panic (`allow-unwrap-in-tests`, `allow-expect-in-tests` and `allow-panic-in-tests` in `clippy.toml`); these cover only `#[test]` functions, so helpers in an integration-test crate need `#![allow(clippy::panic)]`. See [ADR 0010](../../docs/adr/0010-error-handling-no-panics.md).
- The workspace also denies `dbg_macro`, `print_stdout` and `print_stderr`: `println!` panics on a closed pipe, so write through `std::io` (`writeln!`) and handle the error. The FRB-generated module's allow list names these restriction lints too, because `clippy::all` does not cover them.
- No unchecked indexing or slicing: use `get` and checked arithmetic. `clippy::indexing_slicing` and `clippy::arithmetic_side_effects` are denied in parser and decoder modules (lexer, xref, filters, CMaps, font parsing, interpreter; in ferman-core since M2: `syntax`, `xref`, `repair`, `security`, `text_string`, `structure`), and allowed again only in their `#[cfg(test)]` modules. Sizes and offsets read from files always use checked arithmetic.
- One `thiserror` error type per crate (`CoreError`, `FontError`, `TextError`, `RenderError`, …), `#[non_exhaustive]`. ferman-api maps them to `ApiError { kind, message_key, details }`.
- No localized text leaves the engine. Errors and notices carry message keys with parameters; Dart formats them. Keys are lowerCamelCase ARB keys (gen-l10n rejects dots) defined only as constants of the closed `MessageKey` type and listed in `MessageKey::ALL`. A CI check that every key exists in `app_en.arb` and `app_tr.arb` arrives with the first error strings (M1 step 10); the first key, `errorInternal`, gets its ARB entries then.
- `details` holds structural facts only (sizes, offsets, object numbers), never document text or paths. A caught panic's payload never reaches `details` or the release log.
- `catch_unwind` is used only at the ferman-api actor and job entry points, as a last resort. The release profile keeps `panic = "unwind"`.
- `#![forbid(unsafe_code)]` at every crate root except ferman-api, which uses `#![deny(unsafe_code)]` and allows unsafe code only on the FRB-generated module behind the `frb` feature (an inner `allow` cannot override `forbid`). CI fails on any other `allow(unsafe_code)`. pdfium-render is the unsafe layer for PDFium; any further unsafe code is a documented, reviewed exception that the owner approves first ([ARCHITECTURE.md §8.1](../../docs/ARCHITECTURE.md#81-errors-per-crate), [ADR 0010](../../docs/adr/0010-error-handling-no-panics.md)). Memory-mapping the private snapshot of a file over 256 MB would be one; it waits for [Q21](../../docs/QUESTIONS.md#q21), so until then read every file into an owned buffer.
- Logs (`tracing`) stay on the device and never contain document text, typed characters, passwords or rendered content.
- A password is a `ferman_core::Password` from the moment it enters the engine: it wipes itself when dropped and never shows in `Debug` output or an error. Every buffer derived from it is a `zeroize::Zeroizing` buffer, and hash and cipher crates are built with their `zeroize` features. Never hand a password to lopdf; PDFium gets it only through ferman-render's `open_document` ([Q22](../../docs/QUESTIONS.md#q22)).
- A fuzz target that needs a crate-private parser goes through ferman-core's hidden `fuzzing` module, behind the `fuzzing` feature that only `fuzz/` enables; the parsers stay `pub(crate)`.

## Style and documentation

- `cargo fmt --all` before every commit; `cargo clippy --workspace --all-targets -- -D warnings` is clean.
- Every public item is documented. `missing_docs` is on for every library crate (`#![deny(missing_docs)]` or the workspace lint) and fails CI.
- The crate graph follows [ARCHITECTURE.md §2.2](../../docs/ARCHITECTURE.md#22-dependency-graph). ferman-core and ferman-fonts depend on no other Ferman crate. A new edge needs an ADR.

## API boundary

- Only ferman-api is UI-facing. FRB codegen scans only its `frb` module; the facade is pure Rust and carries `#[cfg_attr(feature = "frb", flutter_rust_bridge::frb(ignore))]`, because FRB matches types by bare name across the crate, and `#[doc = "cbindgen:ignore"]`, because the Dco codec's cbindgen pass reads the whole crate and would declare facade types such as `ApiVersion` as opaque C structs whose Dart classes clash with the mirrors. The `frb` mirrors are plain structs and enums without data. Never use `std::pin::pin!`, or any macro that expands to `super let`, in ferman-api: FRB 2.13 codegen expands the whole crate and cannot parse it; use `Box::pin`. ferman-cli and the integration tests use the facade with the `frb` feature off.
- Only plain data crosses: integers, floats, strings, enums, byte vectors and structs of those, plus opaque `u64` handles. Geometry is in page space. lopdf types, PDF matrices and PDFium objects never cross.
- Every API function is async or returns a stream, except `api_version()`.
- Never block in an async FRB function. It validates input, sends a message to the right actor or queue, and awaits the reply.
- The surface is the brief's: open and close, page info, tile rendering, text blocks, edit transactions (begin/apply/commit/rollback with engine-level undo and redo) and jobs (OCR, convert, compress, batch) that are async, cancellable and stream progress.

## Threading

The model is [ADR 0009](../../docs/adr/0009-threading-and-jobs.md), approved by the owner on 2026-10-16; the brief fixes the outcome: rendering and heavy work never run on the UI thread. Tile transfer follows the owner's order ([Q19](../../docs/QUESTIONS.md#q19)): the Dco codec first, then a pointer view only with the owner's approval of its unsafe surface, then textures.

- PDFium is not thread-safe. Only ferman-render links it, and every PDFium call runs on its single render thread. pdfium-render's `thread_safe` feature (one global lock) stays on, but it is only a partial second guard: in 0.9.4, 192 of its 481 bindings run without the lock. So one render thread of a process holds PDFium at a time; a second one is refused (`PdfiumInUse`), and tests that start render threads with PDFium take turns through a lock of their own. The render thread takes messages over crossbeam-channel and replies through `futures_channel::oneshot` futures.
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
- Document JavaScript is never executed, and the engine reports the scripts it finds so the UI can say so; `/Launch` actions never run; document content never triggers network access (confirmed by the owner, [Q13](../../docs/QUESTIONS.md#q13)).
- Write files only through ferman-core's safe save module: temp file in the target directory, flush, verify, atomic rename (`ReplaceFileW` on Windows). Never write in place. Incremental update is the default. Autosave and recovery go to the app data directory ([ADR 0008](../../docs/adr/0008-file-safety-and-saving.md)).

## Tests

- Unit tests next to the code; integration tests in `crates/*/tests/` through public APIs. The full open, edit, save and reopen path is tested through the ferman-api facade.
- Tests that need the PDFium library are `#[ignore]` by default and run with an absolute `FERMAN_PDFIUM_PATH` (`cargo test --workspace -- --ignored`; cargo runs each test binary from its crate's folder, so a relative path breaks). CI runs them on the three systems. Tests that must not depend on the caller's shell remove `FERMAN_PDFIUM_PATH` first.
- A cargo-fuzz target for every parser, from the first parser in M2, including third-party parsers reached through our wrappers (lopdf through ferman-core, skrifa and read-fonts through ferman-fonts, image decoders): object lexer and parser, xref and trailer paths (including repair), content-stream lexer and interpreter, stream filters, CMap and ToUnicode, the Type1 parser and font program parsing, encryption, incremental writer round trip, and "open arbitrary bytes" through the facade. Crashes become regression files in the corpus. `fuzz/` is a separate workspace, so `libfuzzer-sys` (NCSA) never ships. Its NCSA exception was approved by the owner on 2026-10-15 ([Q17](../../docs/QUESTIONS.md#q17)) for `fuzz/` only. `fuzz/` exists since M2, with the stream filters as the first parser; it builds with the nightly pinned in `fuzz/rust-toolchain.toml`, and its formatting and Clippy use the stable toolchain from the root (`--manifest-path fuzz/Cargo.toml`). Every new parser adds its target and a row in `fuzz/README.md`.
- Property tests (proptest) for every encoder and decoder: lexer round trip, encode and decode for every encoding, edit then revert gives identical bytes, written incremental updates parse back to the same objects.
- Every corpus file has its source, licence, SHA-256 and purpose in `tests/corpus/README.md`.
- Corpus generators (`tools/corpus`) make the same bytes on every run and every system: no clock, no random numbers (seed AES initialisation vectors from the generator's name), no transcendental floating-point functions such as `sin` or `powf` (their last bits differ between C libraries), and fonts only from `app/assets/fonts/` or `tools/corpus/fonts.lock`. A new generator gets its README row, its `Expect` for the PDFium oracle, and a regenerate-and-check run.

## Performance

- criterion benchmarks for open, page sizes, first-page render, tile render, text model, edit apply and save.
- Budgets from the brief: first page visible in under 1 s for a 500-page document; 60 fps scrolling and zooming; edit-to-render under 100 ms. The full table and CI guards are in [ARCHITECTURE.md §14](../../docs/ARCHITECTURE.md#14-performance-budgets).

## Dependencies

- Any dependency change updates [DEPENDENCIES.md](../../docs/DEPENDENCIES.md) (version, SPDX licence, milestone, purpose) in the same commit and passes `cargo deny check` (licences, bans, advisories, sources).
- Allowed licences and bans are in [ADR 0016](../../docs/adr/0016-dependency-licence-policy.md). Ask the owner before adding a dependency with an unusual licence. The approved exceptions are named, one crate each (`libfuzzer-sys` in `fuzz/` only); they never widen the allow-list. The owner confirmed the stricter reading of "GPL-compatible" on 2026-10-16 ([Q17](../../docs/QUESTIONS.md#q17) part 4): no GPL code of any version, no LGPL-only code, and MPL-2.0 only per package after the owner's review.
- Add later-phase crates only in their phase: signing (cms, x509-cert, cryptoki, rsa) and OCR (the engine chosen at the start of P3 after a fresh check, Tesseract the fallback, [Q16](../../docs/QUESTIONS.md#q16)) in P3, krilla in P4. Verify each before use.
