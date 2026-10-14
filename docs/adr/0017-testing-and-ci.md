# ADR 0017: Testing and continuous integration

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §4, §5 and §9
- **Supersedes:** none
- **Superseded by:** none

## Context

The brief's quality bar ([brief §5](../BRIEF.md)):

- Rust: documented public APIs, `cargo fmt`, `clippy -D warnings`, unit and integration tests, cargo-fuzz
  targets for every parser.
- Flutter: very_good_analysis, `flutter analyze` clean, widget tests, golden tests for every implemented
  screen in light and dark and in en, tr and ar, with the real fonts loaded.
- A test corpus of generated PDFs plus freely licensed real-world files (Word, Google Docs, LibreOffice,
  LaTeX, scanned, forms, signed, encrypted, damaged), with provenance in `tests/corpus/README.md`.
- Performance budgets documented and measured: first page under 1 s for 500 pages, 60 fps scrolling and
  zooming, edit-to-render under 100 ms.
- CI on GitHub Actions on macOS, Windows and Linux: Rust fmt, clippy and test, cargo-deny, Flutter
  analyze and test, desktop build. CI must stay green.

And for editing: every edit passes the pixel-diff acceptance test, with Turkish, Arabic and CJK cases
([brief §4](../BRIEF.md)). Screens are compared against Playwright renders of the artboards in
`build/design-refs/` ([brief §2](../BRIEF.md)). The definition of done includes "CI green"
([brief §9](../BRIEF.md)).

The design suggests the corpus: sample documents (Turkish rental contract, bank statement, e-Devlet form,
CV, floor plan) and referenced files (an e-Arşiv invoice, a 64-page thesis, English, German, Arabic and
Japanese files, an encrypted payslip, a 2,400-page report, a truncated file, an XFA form). Two gaps
affect fixtures: Flow B is drawn on the wrong document ([G58](../DESIGN_GAPS.md#g58)) and the e-Devlet
form's page count differs between boards ([G59](../DESIGN_GAPS.md#g59)). The design runtime
(`design/support.js`) loads React 18.3.1 and Babel from unpkg.com, which matters for offline reference
renders.

## Decision

### CI workflows (GitHub Actions)

On every pull request and on `main`, on **macOS (arm64), Windows (x64) and Linux (x64)**:

| Job | Steps |
|---|---|
| Rust | `cargo fmt --check`; `cargo clippy --workspace --all-targets -- -D warnings`; `cargo test --workspace`; **proposed:** dependency-graph check ([ADR 0003](0003-crate-layout-and-api-boundary.md)) |
| Licences and advisories | `cargo deny check` (licences, bans, advisories, sources), plus a dev-dependency run; pub licence check with very_good_cli ([ADR 0016](0016-dependency-licence-policy.md)) |
| Generated code | regenerate FRB bindings, `tokens.g.dart`, l10n and icon assets; fail on any diff; check that FRB's crate, package and codegen versions match |
| Flutter | `flutter analyze`; `flutter test` (widget tests everywhere; goldens on Linux only, below); project checks for forbidden APIs, literal design values, left-or-right layout APIs and direct `toUpperCase` ([ADR 0011](0011-flutter-state-navigation-components.md), [ADR 0012](0012-design-token-pipeline.md), [ADR 0014](0014-localization-and-rtl.md)) |
| Desktop build | `flutter build macos`, `flutter build windows`, `flutter build linux` with the native engine and the pinned PDFium |
| Fuzz smoke (Linux) | a short run of every fuzz target |
| Benchmarks (Linux) | criterion benchmarks compared with stored baselines |

A nightly workflow runs longer fuzzing sessions (Linux and macOS) and the full corpus suite.

**Pinning and hygiene:**

- Every third-party action is pinned by **full commit SHA**, with the version in a comment:
  actions/checkout (v7.0.1), dtolnay/rust-toolchain, subosito/flutter-action (v2.23.0, with
  `flutter-version: 3.47.7`), EmbarkStudios/cargo-deny-action (v2.1.1), and Swatinem/rust-cache
  (v2.9.2) only if [Q17](../QUESTIONS.md#q17) approves its LGPL-3.0 licence. Until then the Cargo cache
  uses actions/cache (MIT), or CI runs without one ([ADR 0016](0016-dependency-licence-policy.md)).
- Toolchains are pinned: Rust from `rust-toolchain.toml` (1.99), Flutter 3.47.7, Node 24 LTS for tools.
- Workflows run with `permissions: contents: read` unless a job needs more.
- The PDFium archive is fetched by `tools/pdfium` and checked against its pinned SHA-256
  ([ADR 0004](0004-lopdf-model-pdfium-renderer.md)).
- A red `main` is fixed before any other work.

### Rust tests

- Unit tests next to the code; integration tests in each crate's `tests/` against the corpus through
  public APIs; the full open, edit, save and reopen path through the ferman-api facade.
- **proptest** for invariants: lexer round trips, encoding round trips, edit-then-revert gives identical
  bytes, written updates parse back to the same objects with the original bytes as a prefix.
- **insta** snapshots for object trees, extracted text and text models.

### Pixel-diff harness

The acceptance test of [ADR 0005](0005-block-scoped-text-editing.md), run for every edit case: render
before at 72, 150 and 300 dpi, edit, save incrementally, reopen from disk, render after, and assert zero
differing pixels outside the edited region, plus byte checks. On failure CI uploads the before, after and
difference images as artifacts. `ferman verify-edit` runs one case locally.

### Fuzzing

- cargo-fuzz targets live in a separate `fuzz/` workspace (nightly toolchain; Linux and macOS, since
  Windows support is limited). `libfuzzer-sys` never enters the shipped graph. Its NCSA licence is an
  exception pending [Q17](../QUESTIONS.md#q17); the workspace is created once the owner approves it,
  which is needed by M2.
- One target per parser, from the **first parser in M2**: object lexer and parser, cross-reference and
  trailer (including repair), content-stream lexer, interpreter, each stream filter, CMap and ToUnicode,
  the Type1 parser, encryption and password handling, the incremental writer round trip, and "open
  arbitrary bytes" through the facade.
- Seed corpora come from `tests/corpus`. Every crash becomes a regression test and a corpus file.

### Test corpus

- `tests/corpus/README.md` records, for every file: source, licence, SHA-256 and what it covers. Files
  without a clear free licence are not added.
- **Generated files** come from deterministic scripts in `tools/corpus`, mirroring the design's sample
  documents: the Turkish rental contract with a subset font missing "ğ" and a tight frame above the IBAN
  line, the bank statement, the **one-page** e-Devlet form ([G59](../DESIGN_GAPS.md#g59)), the CV, the
  64-page thesis with page labels, the 2,400-page report, a truncated file, an AES-256 payslip whose
  password contains Turkish letters, an XFA-only form, Arabic and Japanese files (including vertical
  text), scanned pages, signed files and a file changed after signing. Flow B acceptance tests use the
  e-Devlet form fixture ([G58](../DESIGN_GAPS.md#g58)).
- **Real-world files** under free licences, covering the producers in brief §5.
- Small files are committed; larger ones are fetched by `tools/corpus` with pinned hashes (the size
  threshold is set in [ARCHITECTURE.md](../ARCHITECTURE.md) section 2.4).

### Flutter tests

- Widget tests for every component and screen.
- **Goldens with alchemist** (not golden_toolkit, which is discontinued) for every implemented screen and
  component state, in **light and dark × en, tr and ar**, with the real bundled fonts loaded and text not
  obscured. Goldens are generated and compared on the Linux runner only, so font rasterisation is stable;
  platform chrome variants (macOS, Windows) are rendered there by setting the target platform in the test.
- **integration_test** runs desktop flows against the real engine from M3, starting with Flow A (open,
  fix a typo, save).

### Design-reference comparison

- `tools/design-refs` (Node 24, Playwright 1.64) renders every artboard to `build/design-refs/<id>.png`
  (gitignored). It runs offline: the React and Babel runtime scripts are vendored in `tools/`, fonts are
  local, and all network requests are blocked, so the design's Google Fonts import never loads.
- A comparison script lines up each golden with its artboard and reports a perceptual difference score.
  In M1 the score is reviewed by a person in the pull request, not used as a gate; a gate is considered
  once the scores are understood.

### Performance budgets

- criterion benchmarks for open, page sizes, first-page render, tile render, text model, edit apply and
  save; integration tests with frame timings for scrolling and zooming.
- The brief's three budgets are measured on reference hardware before each milestone sign-off
  ([ARCHITECTURE.md](../ARCHITECTURE.md) section 14). CI runners are slower and have no GPU, so CI
  compares against stored baselines with a calibration factor and fails on sustained regressions (from
  M2).

## Consequences

### Positive

- Every brief rule has a mechanical check.
- Editing correctness is proven per case, in pixels and in bytes.
- Goldens on one platform with real fonts are stable and still catch visual regressions in all three
  languages.
- Pinned actions and toolchains make CI reproducible and resistant to supply-chain changes.

### Negative

- CI is slow and expensive: three operating systems, two toolchains, desktop builds and goldens. Caching
  (Cargo, pub and PDFium caches) and running heavy jobs only where needed keep it manageable.
- Goldens only on Linux mean macOS- and Windows-specific rendering differences are caught by people and
  by the design-reference review, not by goldens.
- Pinned SHAs need regular updates; Dependabot or a scheduled review handles them.
- Performance numbers on CI are noisy; only trends are gated there.

### Follow-up

- M1: all workflows except fuzzing and benchmarks, alchemist goldens for the shell and components,
  `tools/design-refs`, `tools/pdfium`, corpus README skeleton.
- M2: fuzz targets with the first parsers, benchmarks and baselines, the corpus generators for viewing.
- M3: the pixel-diff harness and the editing corpus, integration tests for Flow A.

## Alternatives considered

- **Goldens on every platform.** More coverage, but three sets of reference images that differ in font
  rasterisation and constant churn.
- **Obscured-text goldens (alchemist's CI default).** Stable, but the brief requires real fonts, and
  text is where Turkish and Arabic bugs show.
- **Fuzzing on a hosted service only.** Useful later, but every parser needs targets in the repository
  first, and CI must run them.
- **Visual comparison as a hard gate from day one.** The design's HTML and Flutter will never be pixel
  identical; a gate needs calibrated thresholds first.
- **Version tags for actions.** Tags can move; commit SHAs cannot.

## References

- [Brief](../BRIEF.md) §2, §4, §5, §9
- [ARCHITECTURE.md](../ARCHITECTURE.md), sections 13 and 14
- [ADR 0003](0003-crate-layout-and-api-boundary.md), [ADR 0004](0004-lopdf-model-pdfium-renderer.md),
  [ADR 0005](0005-block-scoped-text-editing.md), [ADR 0011](0011-flutter-state-navigation-components.md),
  [ADR 0012](0012-design-token-pipeline.md), [ADR 0014](0014-localization-and-rtl.md),
  [ADR 0016](0016-dependency-licence-policy.md)
- [DEPENDENCIES.md](../DEPENDENCIES.md) (tool and action versions)
- [G58](../DESIGN_GAPS.md#g58), [G59](../DESIGN_GAPS.md#g59), [Q17](../QUESTIONS.md#q17)
