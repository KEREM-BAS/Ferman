# ADR 0002: Rust engine and one Flutter UI, connected by flutter_rust_bridge v2

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §3
- **Supersedes:** none
- **Superseded by:** none

## Context

Ferman must edit any text in any PDF and match Acrobat over time ([brief §1](../BRIEF.md)). It ships on
desktop first (macOS and Windows, Linux best effort), then the web, then iOS, Android and tablets, from
one codebase. The interface must match the design exactly on every platform: custom title bars for
macOS and Windows (f6, f6a), light and dark themes, touch density for tablets and phones, full
right-to-left mirroring (a12-1ar, a12-2a, a12-2c) and 21 UI languages.

Two very different workloads meet here:

- **The engine** parses untrusted files, interprets content streams, shapes and subsets fonts, renders
  through PDFium and writes files that must never be corrupted. It needs native speed, predictable
  memory and protection against malformed input.
- **The UI** is a large custom component library (45 design-system components plus 15 `Fm*` shell
  building blocks) that must look the same everywhere and pass golden tests in en, tr and ar, light and
  dark.

The brief fixes the answer: "Rust engine + one Flutter UI, connected with flutter_rust_bridge v2"
([brief §3](../BRIEF.md)). This ADR records that decision and pins the details.

## Decision

- **Engine:** Rust, in `crates/` (layout in [ADR 0003](0003-crate-layout-and-api-boundary.md)). Memory
  safety by default; `unsafe` only inside dependencies such as pdfium-render, or as a documented,
  reviewed exception.
- **UI:** one Flutter app in `app/`, with `macos`, `windows`, `linux` and `web` targets from M1 and
  `ios` and `android` added in P5 ([brief §3](../BRIEF.md), [§7](../BRIEF.md)).
- **Bridge:** flutter_rust_bridge (FRB) v2, pinned to **2.13.0** for all three parts, which must match
  exactly:
  - the Rust crate `flutter_rust_bridge = "=2.13.0"` (in ferman-api only, behind its `frb` feature);
  - the Dart package `flutter_rust_bridge: 2.13.0` (exact, no caret);
  - the code generator, installed with `cargo install flutter_rust_bridge_codegen --locked --version 2.13.0`.
  A CI check compares the three versions. Upgrades move all three in one commit.
- **Generated code** is committed (`app/lib/bridge/` and the matching Rust file). CI regenerates it and
  fails if anything changes. Nobody edits it by hand.
- **Calls are async.** Every engine call returns a Future or a Stream. The only synchronous call is the
  API version check at start-up. Tiles and job progress arrive as streams (FRB `StreamSink`). Details of
  the threading model are in [ADR 0009](0009-threading-and-jobs.md) (Proposed).
- **Toolchains** (verified 2026-10-13):
  - Rust stable **1.99**, pinned in `rust-toolchain.toml` in M1. The crates' minimum supported Rust
    version is declared in the workspace and is at least 1.88 for the core set.
  - Flutter **3.47.7** with Dart **3.13.5**. Several chosen packages need Dart 3.13 or later.
  - Node **24 LTS** for tools only (the design-reference renderer). Node is never part of the app.
- **PDFium** is a native shared library loaded at run time by ferman-render
  ([ADR 0004](0004-lopdf-model-pdfium-renderer.md)) and bundled per platform.

## Consequences

### Positive

- One UI codebase for every platform in the brief, so the design is implemented once.
- Rust gives memory safety on untrusted input, real threads for rendering and jobs, and access to the
  Rust PDF and font ecosystem (lopdf, skrifa, subsetter, fontdb) and to PDFium through pdfium-render.
- FRB v2 generates the glue for async calls, streams and structs, and supports the web through
  WebAssembly, which keeps P5 open without a second engine.
- The same engine runs under the `ferman` CLI ([ADR 0003](0003-crate-layout-and-api-boundary.md)), so
  most engine behaviour is tested without the UI.

### Negative

- Two languages, two toolchains and two package managers. Contributors need both. CI builds both on
  three operating systems ([ADR 0017](0017-testing-and-ci.md)).
- The FFI boundary has a cost. Large pixel buffers must cross without extra copies. FRB v2 hands
  primitive vectors to Dart as external typed data on native platforms; an M1 benchmark must confirm
  this, with a platform texture as the fallback.
- FRB's three parts must move together. 2.14 is in beta; we stay on 2.13.0 until a stable release has
  been tested.
- FRB pulls in a few dependencies that need attention: `allo-isolate` declares its licence as a file,
  so cargo-deny needs a clarify entry ([ADR 0016](0016-dependency-licence-policy.md)), and `threadpool`
  has had no release since 2020.
- Each platform build must bundle and sign a native Rust library and the PDFium library. Signing needs
  the publisher name ([Q02](../QUESTIONS.md#q02)); minimum OS versions decide which OS APIs we can use
  ([Q03](../QUESTIONS.md#q03)). Linux packaging is open ([Q12](../QUESTIONS.md#q12)).

### Follow-up

- M1: Cargo workspace, `rust-toolchain.toml`, FRB integration for macOS, Windows and Linux, the version
  check in CI, and the tile-transfer benchmark.
- P5: web build (FRB WebAssembly), then iOS and Android.

## Alternatives considered

- **Native UI per platform** (AppKit or SwiftUI, WinUI, GTK). Best platform fit, but three or more UI
  codebases. The brief asks for one.
- **Web UI in a desktop shell** (Electron or Tauri). One codebase, but heavier, and the brief fixes
  Flutter for the UI. The shortcut of reusing the design's HTML is ruled out too: the design is never
  shipped ([brief §2](../BRIEF.md)). Tauri has no mature mobile story for an app this size.
- **Rust UI toolkits** (egui, iced, Slint, Dioxus). Promising, but not yet mature enough for a large
  custom desktop and mobile UI with RTL, IME, accessibility and golden testing. Slint's licence options
  also need separate review.
- **Flutter with the engine in Dart.** No mature PDF parsing, font or writing stack exists in Dart. We
  would build all of it ourselves, without Rust's guarantees for untrusted input.
- **Hand-written FFI** (`dart:ffi` with cbindgen). No generator for async calls, streams or structs; more
  code to maintain and more room for memory errors.
- **UniFFI.** Mozilla's binding generator has no first-party Dart backend.

## References

- [Brief](../BRIEF.md) §1, §2, §3, §7
- [ADR 0003](0003-crate-layout-and-api-boundary.md), [ADR 0004](0004-lopdf-model-pdfium-renderer.md),
  [ADR 0009](0009-threading-and-jobs.md), [ADR 0016](0016-dependency-licence-policy.md),
  [ADR 0017](0017-testing-and-ci.md)
- [ARCHITECTURE.md](../ARCHITECTURE.md), section 3 (API boundary)
- [DEPENDENCIES.md](../DEPENDENCIES.md) for versions and licences
- [Q02](../QUESTIONS.md#q02), [Q03](../QUESTIONS.md#q03), [Q12](../QUESTIONS.md#q12)
