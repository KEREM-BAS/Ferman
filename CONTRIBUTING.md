# Contributing to Ferman

Thank you for your interest in Ferman. Ferman is a free, open-source PDF editor: click any text in any
PDF and edit it like a Word document. Everyone is welcome to help, whether you write Rust or Dart,
translate, test with real-world PDFs, or point out mistakes in the documents.

## Contents

1. [Project status](#project-status)
2. [Before you start](#before-you-start)
3. [Ground rules](#ground-rules)
4. [Workflow](#workflow)
5. [Licensing of contributions](#licensing-of-contributions)
6. [Dependencies](#dependencies)
7. [Development setup](#development-setup)
8. [Quality bar](#quality-bar)
9. [Text-editing changes](#text-editing-changes)
10. [Translations](#translations)
11. [Reporting bugs](#reporting-bugs)
12. [Security issues](#security-issues)
13. [Code of conduct](#code-of-conduct)

## Project status

Ferman is between **Milestone 1: foundations** and **Milestone 2: open and view**. The maintainer
approved the plan (Milestone 0) on 2026-10-15 and Milestone 1 on 2026-10-16: the Rust workspace, the
Flutter app with its shell, first run, start screen and settings skeleton, the design tooling and CI
are in `main`. The app opens no PDFs until Milestone 2, whose plan waits for the maintainer's
approval.

What helps most right now:

- Read the documents and open an issue when something is wrong, missing or unclear.
- Comment on the open question in [docs/QUESTIONS.md](docs/QUESTIONS.md) (Q21), the Proposed ADRs
  in [docs/adr/](docs/adr/README.md) and the [plan for Milestone 2](docs/PROGRESS.md#m2-plan).
- Tell us about freely licensed PDFs that would make good test files (see
  [Reporting bugs](#reporting-bugs) for what we can accept).

Please wait with pull requests for application code until Milestone 2 has started, so changes can
be reviewed against the engine API it adds.

## Before you start

Read these, in this order:

1. [docs/BRIEF.md](docs/BRIEF.md): the maintainer's brief. It is authoritative. When another
   document disagrees with it, the brief wins and the other document gets fixed.
2. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and the
   [architecture decision records](docs/adr/README.md): how the engine and the app fit together, and
   why.
3. [docs/ROADMAP.md](docs/ROADMAP.md): what each milestone includes and how it is accepted.
4. [docs/PROGRESS.md](docs/PROGRESS.md): the current milestone and the next step.

Also useful: [docs/DESIGN_INVENTORY.md](docs/DESIGN_INVENTORY.md) maps every screen in the design to a
feature and a milestone, [docs/DESIGN_GAPS.md](docs/DESIGN_GAPS.md) records what the design leaves
open, and [docs/BACKLOG.md](docs/BACKLOG.md) lists work that is deferred.

## Ground rules

**The design**

- `design/` is read-only. Never edit, move or delete anything in it, never ship its HTML or
  JavaScript, and never load anything from it at run time. It is a reference, not code to reuse.
- `design/` is the visual source of truth. Layout, spacing, typography, colour, icons, states and
  copy match the corresponding artboard.
- If you find a gap or a conflict in the design, record it in
  [docs/DESIGN_GAPS.md](docs/DESIGN_GAPS.md) with the option you chose, and keep going.

**Behaviour and architecture**

- Behaviour follows the [brief](docs/BRIEF.md). Where the design and the brief disagree about
  behaviour, the brief wins. For example, the design shows the licence as GPL-3.0; the app shows
  Apache-2.0 ([G13](docs/DESIGN_GAPS.md#g13)).
- Architecture changes only through an ADR that the maintainer approves. Copy
  [docs/adr/template.md](docs/adr/template.md), mark it **Proposed**, and add a question to
  [docs/QUESTIONS.md](docs/QUESTIONS.md). Until it is approved, the brief and the accepted ADRs stand.
- The UI never touches PDF internals. It calls only `ferman-api`.
- Never corrupt a user's file. Saving goes through a temporary file and an atomic rename.
- No telemetry and no new network use. Ferman connects only for the update check, optional
  language-pack downloads, the optional AI assistant and signature timestamp servers
  ([ADR 0015](docs/adr/0015-privacy-and-network.md)). Anything else needs an approved ADR.
- A feature that is not built yet stays visible exactly as designed, but disabled, with the tooltip
  "Available in a future version" and an entry in [docs/BACKLOG.md](docs/BACKLOG.md).

**Ask the maintainer first** (in an issue) before you:

- change an architectural decision;
- add a dependency with an unusual licence;
- touch `design/`;
- delete work you did not create.

## Workflow

1. **Issue first.** For anything beyond a typo or a small, obvious fix, open an issue before you write
   code. Say what you want to change and why, which milestone it belongs to, and which artboards it
   touches (by id, for example `a3-3a`).
2. **One milestone at a time.** Work belongs to the current milestone in
   [docs/PROGRESS.md](docs/PROGRESS.md). Work for a later milestone waits, or goes into
   [docs/BACKLOG.md](docs/BACKLOG.md).
3. **Small, focused pull requests.** One topic per pull request. Update the documents in the same
   pull request: PROGRESS, ARCHITECTURE and the ADRs, DEPENDENCIES, DESIGN_GAPS, BACKLOG, and the
   commands in [CLAUDE.md](CLAUDE.md) when they change.
4. **Conventional Commits.** Write commit messages as `type(scope): summary`. Write the summary in
   the imperative, start it with a lower-case letter and leave out the full stop. Types: `feat`,
   `fix`, `docs`, `test`, `refactor`, `build`, `ci`, `chore`. The scope is optional: a crate name or
   an app area. Mark a breaking change with `!` after the type and a `BREAKING CHANGE:` footer.
   Examples:

   ```text
   feat(ferman-core): parse cross-reference streams
   fix(app): keep the sidebar tab when switching documents
   test(ferman-text): add a pixel-diff case for a Turkish subset font
   docs: record the overflow wording decision in DESIGN_GAPS
   build: pin PDFium to chromium/7881
   ci: run the fuzz smoke test on pull requests
   ```

5. **Green CI.** A pull request is merged only when CI is green on macOS, Windows and Linux.
6. **Review.** The maintainer reviews every pull request. Expect questions about the brief, the
   design and the tests.

## Licensing of contributions

Ferman is licensed under the [Apache License 2.0](LICENSE).

- **Inbound equals outbound.** Under section 5 of the licence, unless you explicitly state otherwise,
  any contribution you intentionally submit for inclusion in Ferman is under the Apache License 2.0,
  without any additional terms or conditions. Contributions offered under other terms are not
  accepted.
- **No contributor licence agreement.** You keep the copyright in your contribution. The project's
  copyright line is "Copyright The Ferman Authors" ([Q14](docs/QUESTIONS.md#q14)).
- Submit only work you have the right to submit. Do not copy code from projects whose licences are
  not compatible (see [Dependencies](#dependencies)) or from proprietary SDKs.

**Sign-off (required; the maintainer's decision of 2026-10-16, [Q14](docs/QUESTIONS.md#q14)).**
Every commit is signed off to certify the
[Developer Certificate of Origin](https://developercertificate.org/): that you wrote the change, or
otherwise have the right to submit it under the project's licence. Use `git commit -s`. It adds a
`Signed-off-by:` line with the name and email address from your git configuration, which must be
the commit's author; GitHub's no-reply address works if you prefer not to publish yours. CI checks
every commit of a pull request (merge commits aside) with the `dco_signoff` check of
`tools/checks`. To add missing sign-offs to your own branch, run `git rebase --signoff origin/main`
and force-push it.

## Dependencies

The full policy is in [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md#1-policy) and
[ADR 0016](docs/adr/0016-dependency-licence-policy.md). In short:

- **Permissive licences only**, such as MIT, Apache-2.0, BSD, ISC and Zlib. The brief allows
  "permissive or GPL-compatible" licences; because Ferman is Apache-2.0, that rules out GPL code of any
  version. MPL-2.0 is allowed only for an unmodified dependency, after review. This reading of
  "GPL-compatible" is the project's. The maintainer approved three named exceptions on 2026-10-15
  (MPL-2.0 `dbus` through desktop_drop, NCSA `libfuzzer-sys` in `fuzz/` only, LGPL-3.0
  Swatinem/rust-cache in CI only), and the reading itself is still to be confirmed
  ([Q17](docs/QUESTIONS.md#q17)).
- **Never** AGPL, GPL, LGPL as the only licence, non-commercial licences, or code with no clear
  licence. **Never** MuPDF, Ghostscript, poppler or xpdf, including tools that call them. Tools that
  run only in CI and are never distributed are reviewed separately
  ([DEPENDENCIES.md §1](docs/DEPENDENCIES.md#1-policy)).
- An unusual licence goes to the maintainer first. Work continues without that dependency until the
  answer comes.
- **Update [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) in the same pull request** that adds, removes
  or upgrades a dependency: version, licence, why it is needed and its first milestone. A pull request
  without that update is not merged.
- **cargo-deny** checks licences, bans, advisories and sources for Rust on every pull request. A
  licence check with very_good_cli does the same for Dart packages. Both run in CI from Milestone 1.
- Bundled binaries, fonts and icons ship with their licence texts. Bundled fonts are the upstream
  files, unmodified: never subset, rename or convert the files we ship. Embedding a subset of a font
  into a user's PDF is document embedding, which OFL-1.1 allows.

## Development setup

The commands below build, test and check everything Milestone 1 made. At the end of Milestone 1 each
one ran on a fresh clone on Linux, and CI runs them on macOS and Windows; [CLAUDE.md](CLAUDE.md#commands)
keeps the same list for coding sessions.

**Toolchain**

- **Rust** stable 1.99, installed with [rustup](https://rustup.rs/). The repository pins the version
  in `rust-toolchain.toml`, with rustfmt and clippy. A pinned nightly is used only for cargo-fuzz,
  from Milestone 2.
- **Flutter** 3.47.7 stable, which includes Dart 3.13.5, with desktop support for your system and the
  platform tools Flutter needs: Xcode on macOS, Visual Studio with the C++ desktop workload on
  Windows, the GTK development packages and a C++ toolchain on Linux.
- **Node.js** 24.22.0 LTS, for the tools only (the design-reference renderer, pinned to
  playwright-core 1.56.1 and its Chromium revision 1194). Node is never part of the app.
- **cargo-deny**, **flutter_rust_bridge_codegen** 2.13.0 and **cargo-expand** 1.0.127, which the
  codegen needs. The codegen, the Rust crate and the Dart package must be the same version.
- **PDFium** comes from `tools/pdfium/fetch.sh`, which downloads the pinned prebuilt binaries and
  checks their SHA-256. Desktop builds bundle it, so run
  `bash tools/pdfium/fetch.sh --platform <linux-x64|win-x64|mac-univ>` before the first
  `flutter build` or integration test; on Linux and Windows the build stops with a message naming
  that command when the library is missing. The IBM Plex fonts are committed; `tools/fonts/fetch.sh`
  re-fetches and checks them.
- **Goldens** are generated and compared on Linux only. They need two Ubuntu font packages that stand
  in for the system font fallback `flutter test` lacks: `sudo apt-get install fonts-dejavu-core
  fonts-noto-cjk` (CI pins their versions).

**Commands**

```sh
# Rust
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo clippy -p ferman-api --features frb --all-targets -- -D warnings
cargo test --workspace
cargo deny check
cargo run -p ferman-cli -- --version                # ferman 0.1.0 (api 0.1); also: info --json
# Tests that need PDFium: run tools/pdfium/fetch.sh first; the path must be absolute
FERMAN_PDFIUM_PATH="$PWD/build/pdfium/linux-x64/lib/libpdfium.so" cargo test --workspace -- --ignored

# Flutter (both analyzers: the riverpod_lint plugin reports only through dart analyze)
(cd app && flutter analyze && dart analyze --fatal-infos && flutter test)
(cd app && flutter test --exclude-tags golden)            # on macOS and Windows: goldens are Linux only
(cd app && flutter test --update-goldens --tags golden)   # regenerate goldens, on Linux only
(cd app && dart run build_runner build)                   # Riverpod and other codegen
(cd app && very_good packages check licenses)             # Dart licence check (flags: docs/DEPENDENCIES.md §8)

# Desktop builds and the integration test bundle PDFium: fetch it for your system first
bash tools/pdfium/fetch.sh --platform linux-x64     # or win-x64, mac-univ
(cd app && flutter build linux --release)           # or windows, macos
(cd app && flutter run -d linux)                    # or windows, macos
(cd app && flutter build web --release)             # the web build, with the engine stubbed
(cd app && flutter test integration_test -d linux)  # the engine through the bridge; on Linux under xvfb-run -a
# The same test in profile mode, for the bridge timing (use your system for -d)
(cd app && flutter drive --profile -d linux --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart)

# Tools
(cd tools/checks && dart run bin/check_all.dart --root ../..)   # the repository checks CI runs
(cd tools/checks && dart run bin/scan_bundle.dart --root ../.. ../../app/build/web)   # no design file in a build
(cd tools/tokens && dart run)        # design tokens → app/lib/design/tokens.g.dart
(cd tools/icons && dart run)         # design icons → app/assets/icons and the IconName enum
(cd tools/l10n && dart run)          # after flutter gen-l10n: the isolated fallback strings
(cd tools/l10n && dart run l10n:review_table)   # after an ARB change: docs/TRANSLATION_REVIEW.md
(cd tools/icons && dart run icons:component_spec)   # docs/COMPONENTS.md from the component spec
tools/fonts/fetch.sh --verify-committed && python3 -I tools/fonts/coverage.py   # font hashes and script coverage
(cd tools/design-refs && npm ci && npm test)
node tools/design-refs --only @m1    # renders the M1 boards to build/design-refs/ (all boards without --only)
node tools/design-refs compare       # goldens against the references → build/design-compare/report.md
```

The bridge bindings (`app/lib/bridge/` and `crates/ferman-api/src/frb_generated.rs`) are generated by
flutter_rust_bridge_codegen 2.13.0, which needs cargo-expand 1.0.127. After a change to the `frb`
module of `ferman-api`, regenerate and format them; CI fails if the committed bindings differ:

```sh
cargo install --locked flutter_rust_bridge_codegen@2.13.0
cargo install --locked cargo-expand@1.0.127
(cd app && flutter_rust_bridge_codegen generate) && cargo fmt -p ferman-api
```

Generated files (`tokens.g.dart`, the bridge bindings and other `*.g.dart` files) are never edited by
hand. Nothing under `build/` is committed.

## Quality bar

From [brief §5](docs/BRIEF.md#5-quality-bar) and [§6](docs/BRIEF.md#6-flutter-conventions). The
[roadmap](docs/ROADMAP.md#3-rules-for-every-milestone) turns these into gates for every milestone.

**Rust**

- No `unwrap`, `expect` or `panic` in library code. Errors use `thiserror`.
- Every public API is documented.
- `cargo fmt` and `cargo clippy -- -D warnings` are clean.
- New code has unit and integration tests.
- Every parser has a cargo-fuzz target, from the first parser in Milestone 2.

**Flutter**

- very_good_analysis lints, and `flutter analyze` and `dart analyze --fatal-infos` with zero issues.
- Widget tests for every component and screen.
- Golden tests for every implemented screen in **light and dark × en, tr and ar**, with the real
  bundled fonts loaded. Goldens use alchemist and are compared with the design-reference renders.
- State with Riverpod and code generation; navigation with go_router.
- Colours, sizes, radii and durations come from the generated design tokens, never from literals in
  widgets. Screens use the Ferman component library in `app/lib/design/components`.
- No Material or Cupertino dialog implementations, no `TabBarView`, no GetX.
- `EdgeInsetsDirectional` and `AlignmentDirectional` everywhere.
- Keyboard shortcuts through `Shortcuts` and `Actions`, shown in tooltips and menus; working focus
  traversal; `Semantics` labels.
- Form validators return `bool` and check null and empty values explicitly.

**Tests and CI**

- Every test PDF lives in `tests/corpus/` with its source, licence and SHA-256 in
  `tests/corpus/README.md`. Only freely licensed files are added.
- Changes on a hot path are measured against the performance budgets in
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#14-performance-budgets): first page visible in under
  1 s for a 500-page document, smooth 60 fps scrolling and zooming, edit-to-render under 100 ms.
- CI runs on macOS, Windows and Linux: Rust fmt, clippy and test, cargo-deny, Flutter analyze and
  test, and the desktop build. CI stays green. A red build is fixed before anything else.

## Text-editing changes

Editing existing text is the hardest part of Ferman and must be flawless
([brief §4](docs/BRIEF.md#4-the-hardest-part-editing-existing-text-must-be-flawless),
[ADR 0005](docs/adr/0005-block-scoped-text-editing.md)). Any change that touches the content-stream
interpreter, fonts and encodings, the text model, editing, missing glyphs, overflow or saving needs
pixel-diff tests:

- Render the page before and after the edit with PDFium. The pixel difference outside the edited
  region must be **exactly zero**.
- Only the operators of the edited block change. Every other byte of the page content stays
  identical, and the original file stays an exact prefix of an incremental save.
- Cover Turkish, Arabic (right-to-left shaping) and CJK cases.
- Never substitute a glyph silently. Missing glyphs follow the three steps in
  [ADR 0006](docs/adr/0006-font-pipeline-and-missing-glyphs.md).

## Translations

- **English is the source** (`app_en.arb`). **Turkish is complete**: a pull request that adds or
  changes a UI string updates Turkish too, and CI checks that the keys match.
- Arabic exists for every string in the goldens.
- The Turkish and Arabic strings of Milestone 1 wait for a native speaker's review: every string,
  in English, Turkish and Arabic with the note for translators, is in
  [docs/TRANSLATION_REVIEW.md](docs/TRANSLATION_REVIEW.md), with how to send corrections. A pull
  request that changes an ARB file regenerates that table (`dart run l10n:review_table` in
  `tools/l10n/`); CI fails when it is stale.
- Other languages fall back to English until they are translated. Community translation will run
  through **Weblate** (planned, after Milestone 1); this section will explain how to join.
- **Never machine-translate silently.** Machine output may enter only as a suggestion that a person
  reviews.
- Never build a sentence by joining strings. Use ICU plural and select forms.
- Casing, numbers, dates, paper sizes and units are locale-aware: Turkish shows "İMZALA", and a
  Turkish region shows "10,5 pt".
- Right-to-left languages mirror the interface, never the PDF page.

## Reporting bugs

Search the existing issues first. Then open an issue with:

- the Ferman version, once releases exist, or the commit you built;
- your operating system and its version;
- the interface language and region;
- the steps to reproduce, what you expected and what happened;
- screenshots, with any private content blurred;
- a log, if it helps. "Copy crash log" replaces folder and file names with placeholders, but read the
  text before you paste it. The log files themselves (opened with "Show log files" in Settings) can
  contain file paths that name clients or documents, so remove them before you post: issues are
  public.

**About PDFs.** A minimal PDF that shows the problem helps a lot, but attach one **only if you are
allowed to share it**. Issue attachments are public. **Never attach confidential documents**:
contracts, bank statements, identity documents, medical records, or anything with personal data. If
you cannot share the file, tell us which program produced it, its PDF version, whether it is signed or
encrypted, and the fonts involved. Even better, recreate the problem in a new file you are free to
share.

Ferman has no telemetry, so your reports are how we find out what goes wrong.

## Security issues

Do not report vulnerabilities in public issues. This includes a PDF that crashes Ferman in a way that
looks exploitable. Follow [SECURITY.md](SECURITY.md) to report privately.

## Code of conduct

Everyone who takes part in Ferman follows the [code of conduct](CODE_OF_CONDUCT.md). It also explains
how to report a conduct problem privately.
