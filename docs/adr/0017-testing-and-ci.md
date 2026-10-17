# ADR 0017: Testing and continuous integration

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §4, §5 and §9. The checks Proposed in M1 (the crate graph, the pub deny list,
  the web stub build and the pseudo-locale tests) were approved by the owner on 2026-10-16. The fuzz
  durations and the benchmark budgets below stay **Proposed** with the
  [M2 plan](../PROGRESS.md#m2-plan).
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
| Rust | `cargo fmt --check`; `cargo clippy --workspace --all-targets -- -D warnings`; `cargo test --workspace`; the tests that need PDFium (`#[ignore]` by default) with `cargo test --workspace -- --ignored` against the pinned library for the runner's platform (`tools/pdfium/fetch.sh`, an absolute `FERMAN_PDFIUM_PATH`), then `ferman info --json --pdfium`, which must report `loaded`, on all three systems |
| Licences and advisories | `cargo deny check` (licences, bans, advisories, sources), plus a dev-dependency run; pub licence check with very_good_cli ([ADR 0016](0016-dependency-licence-policy.md)) |
| Repository checks (Linux) | `tools/checks` (`dart run bin/check_all.dart`): the repository rules CI enforces, among them the crate graph (`crate_graph`, [ADR 0003](0003-crate-layout-and-api-boundary.md)) and the pub network deny list (`pub_denylist`, [ADR 0015](0015-privacy-and-network.md)), both approved on 2026-10-16, `design/` unchanged against the pull request's base and every commit of the pull request signed off by its author (`dco_signoff`, [Q14](../QUESTIONS.md#q14)) ([ARCHITECTURE.md §2.4](../ARCHITECTURE.md#24-tools-corpus-and-fuzzing)) |
| Generated code | regenerate FRB bindings, `tokens.g.dart`, l10n and icon assets; fail on any diff; check that FRB's crate, package and codegen versions match |
| Flutter | `flutter analyze` (the brief's check) and `dart analyze --fatal-infos` (the riverpod_lint 3.1.9 plugin reports only there); `flutter test` (widget tests everywhere; goldens on Linux only, below); project checks for forbidden APIs, literal design values, left-or-right layout APIs and direct `toUpperCase` ([ADR 0011](0011-flutter-state-navigation-components.md), [ADR 0012](0012-design-token-pipeline.md), [ADR 0014](0014-localization-and-rtl.md)) |
| Desktop build | `flutter build macos`, `flutter build windows`, `flutter build linux` with the native engine and the pinned PDFium; on Linux also `flutter build web` with the engine stubbed, so the web path stays buildable until phase 5 (approved on 2026-10-16) |
| Fuzz smoke (Linux) | a short run of every fuzz target (**Proposed** with the M2 plan: 60 s per target) |
| Benchmarks (Linux) | criterion benchmarks compared with stored baselines |

A nightly workflow runs longer fuzzing sessions (Linux and macOS; **Proposed** with the M2 plan: 1 h
per target, one job per target) and the full corpus suite.

**Pinning and hygiene:**

- Every third-party action is pinned by **full commit SHA**, with the version in a comment:
  actions/checkout (v7.0.1), subosito/flutter-action (v2.23.0, with `flutter-version: 3.47.7`),
  EmbarkStudios/cargo-deny-action (v2.1.1), and Swatinem/rust-cache (v2.9.2) for the Cargo cache;
  the design-reference workflow adds actions/setup-node and actions/upload-artifact. rust-cache is
  LGPL-3.0; it runs only in CI, is never distributed or copied, and was approved by the owner on
  2026-10-15 ([Q17](../QUESTIONS.md#q17), [ADR 0016](0016-dependency-licence-policy.md)).
- Toolchains are pinned: Rust from `rust-toolchain.toml` (1.99), installed by `rustup toolchain
  install`, which reads that file, so no third-party toolchain action is needed; Flutter 3.47.7;
  Node 24.22.0 LTS and playwright-core 1.56.1 for the tools
  ([DEPENDENCIES.md](../DEPENDENCIES.md#6-toolchain)).
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
  Windows support is limited). `libfuzzer-sys` never enters the shipped graph. Its NCSA licence is a
  named exception the owner approved on 2026-10-15 ([Q17](../QUESTIONS.md#q17)); the workspace is
  created with the first parser in M2.
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
- Small files are committed; larger ones are produced by `tools/corpus` and checked against pinned
  hashes (the size threshold is set in [ARCHITECTURE.md](../ARCHITECTURE.md) section 2.4; the
  generators, the 1 MB threshold and the first wave are **Proposed** in
  [ADR 0020](0020-test-corpus.md) with the M2 plan).

### Flutter tests

- Widget tests for every component and screen.
- **Goldens with alchemist** (not golden_toolkit, which is discontinued) for every implemented screen and
  component state, in **light and dark × en, tr and ar**, with the real bundled fonts loaded and text not
  obscured. Goldens are generated and compared on the Linux runner only, so font rasterisation is stable;
  platform chrome variants (macOS, Windows) are rendered there by setting the target platform in the test.
  Golden tests carry the `golden` tag (`app/dart_test.yaml`): Linux runs `flutter test`, macOS and
  Windows run `flutter test --exclude-tags golden`, and a failed golden run uploads its failure images.
  Every golden test also passes `skip: !isGoldenHost` (`app/test/helpers/golden_config.dart`): off
  Linux alchemist's test variant has no values, and flutter_test fails such a test while its file
  loads, before `--exclude-tags golden` applies. The first goldens (M1 step 5) were generated in the
  development container and match on the CI Linux runner.
- **integration_test** runs desktop flows against the real engine from M3, starting with Flow A (open,
  fix a typo, save). From M1, one file (`app/integration_test/app_test.dart`) checks the engine through
  the bridge on each system, with the bundled PDFium loaded.

### Design-reference comparison

- `tools/design-refs` (Node 24.22.0, playwright-core 1.56.1) renders every artboard to
  `build/design-refs/<id>.png` (gitignored). playwright-core is pinned to the Chromium revision (1194)
  preinstalled in the development container, where the Playwright CDN is blocked, and CI uses the same
  pin. CI never runs the Playwright installer, because it also downloads Playwright's ffmpeg build
  (LGPL-2.1) with every Chromium; it downloads the revision 1194 headless shell directly, checks its
  SHA-256 (pinned from the first CI download on 2026-10-15) and passes its path to the renderer. The renderer runs offline: the React and Babel runtime
  scripts and the fonts come from npm packages pinned in its lockfile and are served locally, and all
  other network requests fail the run, so the design's Google Fonts import never loads.
- Capture rule (export `519d42a`, 253 boards): 242 of the 244 product boards are captured from the
  first `.fm-root` inside the element with the id `<id>`, or from that element itself when it
  carries `.fm-root` (the seven sidebar boards `a2-3p` to `a2-3x`). `a2-3m` is captured as the box
  around all six of its sidebar frames, and the region-format table `a12-0`, which has no
  `.fm-root`, as the whole element with the id. The nine fix boards `f1` to `f6a` are captured as
  the whole element with the id: the `section` for `f1` to `f6`, and the nested `div` for `f4a`,
  `f4b` and `f6a` (inside the sections `f4` and `f6`). The 29 boards with the design's
  board-language switch are also rendered in Turkish and Arabic (58 variants). Every board and
  variant is rendered on its own freshly loaded page.
- A comparison script lines up each golden with its artboard and reports a perceptual difference score.
  In M1 the score is reviewed by a person in the pull request, not used as a gate; a gate is considered
  once the scores are understood.

### Performance budgets

- criterion benchmarks for open, page sizes, first-page render, tile render, text model, edit apply and
  save; integration tests with frame timings for scrolling and zooming.
- The brief's three budgets are measured on reference hardware before each milestone sign-off
  ([ARCHITECTURE.md](../ARCHITECTURE.md) section 14). CI runners are slower and have no GPU, so CI
  compares against stored baselines with a calibration factor and fails on sustained regressions (from
  M2). **Proposed** ([ARCHITECTURE.md](../ARCHITECTURE.md) section 14, with the M2 plan): each CI
  budget is the reference budget times a calibration factor measured per runner type, provisional
  until R1 numbers exist, and a benchmark more than 15% slower than its baseline for three runs in a
  row fails the job.

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
