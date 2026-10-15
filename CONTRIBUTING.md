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

Ferman is at **Milestone 1: foundations**. The maintainer approved the plan (Milestone 0) on
2026-10-15. Milestone 1 is setting up the Rust workspace, the Flutter app, the design tooling and CI,
on the branch `m1-foundations`; the app opens no PDFs until Milestone 2.

What helps most right now:

- Read the documents and open an issue when something is wrong, missing or unclear.
- Comment on the open questions in [docs/QUESTIONS.md](docs/QUESTIONS.md) and the Proposed ADRs in
  [docs/adr/](docs/adr/README.md).
- Tell us about freely licensed PDFs that would make good test files (see
  [Reporting bugs](#reporting-bugs) for what we can accept).

Please wait with pull requests for application code until Milestone 1 is merged into `main`. Until
then the workspace, the app and CI are still being laid out, and changes cannot be reviewed against a
stable base.

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

**Sign-off (the project's proposal, waiting for the maintainer's decision; see
[Q14](docs/QUESTIONS.md#q14)).** We propose that every commit is signed off to certify the
[Developer Certificate of Origin](https://developercertificate.org/): that you wrote the change, or
otherwise have the right to submit it under the project's licence. Use `git commit -s`. It adds a
`Signed-off-by:` line with the name and email address from your git configuration; GitHub's no-reply
address works if you prefer not to publish yours. Until the maintainer decides, sign-off is welcome
but not required.

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

Milestone 1 is creating the workspace and the app. The commands below are the ones that exist so far;
[CLAUDE.md](CLAUDE.md#commands) keeps the full list, and the end of Milestone 1 checks it on a fresh
clone and updates this section.

**Toolchain**

- **Rust** stable 1.99, installed with [rustup](https://rustup.rs/). The repository pins the version
  in `rust-toolchain.toml`, with rustfmt and clippy. A pinned nightly is used only for cargo-fuzz,
  from Milestone 2.
- **Flutter** 3.47.7 stable, which includes Dart 3.13.5, with desktop support for your system and the
  platform tools Flutter needs: Xcode on macOS, Visual Studio with the C++ desktop workload on
  Windows, the GTK development packages and a C++ toolchain on Linux.
- **Node.js** 24.22.0 LTS, for the tools only (the design-reference renderer, pinned to
  playwright-core 1.56.1 and its Chromium revision 1194). Node is never part of the app.
- **cargo-deny**, and **flutter_rust_bridge_codegen** 2.13.0. The codegen, the Rust crate and the Dart
  package must be the same version.
- **PDFium** comes from `tools/pdfium/fetch.sh`, which downloads the pinned prebuilt binaries and
  checks their SHA-256. The IBM Plex fonts are committed; `tools/fonts/fetch.sh` re-fetches and checks
  them.

**Commands**

```sh
# Rust
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo deny check

# Flutter (both analyzers: the riverpod_lint plugin reports only through dart analyze)
(cd app && flutter analyze && dart analyze --fatal-infos && flutter test)
(cd app && dart run build_runner build --delete-conflicting-outputs)   # Riverpod and other codegen
(cd app && very_good packages check licenses)                         # Dart licence check

# Tools
(cd tools/checks && dart run bin/check_all.dart --root ../..)   # the repository checks CI runs
(cd tools/tokens && dart run)        # design tokens → app/lib/design/tokens.g.dart
(cd tools/icons && dart run)         # design icons → app/assets/icons and the IconName enum
node tools/design-refs               # renders every artboard to build/design-refs/
```

The bridge bindings (`flutter_rust_bridge_codegen generate`) arrive with Milestone 1 step 3.

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
- Arabic exists for every string in the goldens, written or reviewed by a person.
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
