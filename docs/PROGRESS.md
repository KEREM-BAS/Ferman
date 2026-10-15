# Progress

> **Start every session by reading this file.** Then read [CLAUDE.md](../CLAUDE.md) and the part of
> the [brief](BRIEF.md) that covers the task (brief §9).

This file holds the current status, the milestone checklist, the plan for the current milestone, the
measurements and the session log. Detail for each milestone (scope, steps, acceptance criteria,
exit checks) is in [ROADMAP.md](ROADMAP.md).

Related: [roadmap](ROADMAP.md) · [questions](QUESTIONS.md) · [design gaps](DESIGN_GAPS.md) ·
[backlog](BACKLOG.md) · [architecture](ARCHITECTURE.md) · [ADRs](adr/README.md)

## Current status

| Topic | State |
|---|---|
| Milestone | **M1, foundations: in progress.** Started on 2026-10-15 on the branch `m1-foundations`, with a draft pull request to `main` (opened once phase B is pushed) |
| Previous | M0 approved on 2026-10-15: pull request #1 merged into `main` (merge commit `fe99894`) and the owner's go-ahead |
| Next | Commit phase A (the owner's answers, this plan), phase B (Rust workspace, `tools/checks`, CI) and phase D (tools), push, open the draft pull request; then wave 2 (phases E and F); see the [M1 plan](#m1-plan) |
| Application code | the Flutter app skeleton (`23a09c3`, phases C1 and C2) and the switch from flutter_svg to path_parsing (`246d6df`) are committed; the Rust workspace, `tools/checks`, the tool packages, the committed fonts and icons, `tokens.g.dart` and the first CI workflow are in the working tree and committed by phase |
| Questions | 18 entries: 4 answered (Q01, Q03, Q04, Q05), 4 answered in part (Q08, Q12, Q14, Q17), 10 open (Q02, Q06, Q07, Q09, Q10, Q11, Q13, Q15, Q16, Q18); see [QUESTIONS.md](QUESTIONS.md#summary) |
| Proposed ADRs | 0009 and 0018; the Proposed details in 0003, 0004, 0006 and 0008; the reading of "GPL-compatible" in 0016 ([Q17](QUESTIONS.md#q17) part 4) (see [ADR status](#adr-status)) |
| Design gaps | 63 recorded: 51 Decided, 12 Needs owner, 0 Resolved (G62 and G63 found in M1) |
| Backlog | empty: M1 adds the first entries as it disables features |
| Owner actions | 1 open (see [Owner actions](#owner-actions)) |
| Last updated | 2026-10-15 |

## Owner actions

Things only the owner can do on GitHub. Each is ticked when done.

- [ ] Enable private vulnerability reporting (in the repository's Settings, under Security in the
  sidebar). [SECURITY.md](../SECURITY.md) and [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) send
  reports through the **Report a vulnerability** form, which GitHub leaves off until it is enabled.
  Not known to be done on 2026-10-15; the session cannot read the repository settings.
- [x] Delete the old remote branch `claude/gracious-curie-uhjwhl` on GitHub. Done by the owner: on
  2026-10-15, before M1 started, `git ls-remote` showed only `main`; the old branches, `m0-plan`
  included, are gone.

## Milestone checklist

| Milestone | Status | Details |
|---|---|---|
| M0 Discovery and plan | Complete (approved 2026-10-15) | [ROADMAP.md](ROADMAP.md), section 4 |
| M1 Foundations | In progress | [ROADMAP.md](ROADMAP.md), section 5; [M1 plan](#m1-plan) |
| M2 Open and view | Not started | [ROADMAP.md](ROADMAP.md), section 6 |
| M3 Edit text core | Not started | [ROADMAP.md](ROADMAP.md), section 7 |
| M4 Rest of phase 1 | Not started | [ROADMAP.md](ROADMAP.md), section 8 |
| M5 Release pipeline | Not started | [ROADMAP.md](ROADMAP.md), section 9 |
| Phase 2 | Not started | [ROADMAP.md](ROADMAP.md), section 10 |
| Phase 3 | Not started | [ROADMAP.md](ROADMAP.md), section 11 |
| Phase 4 | Not started | [ROADMAP.md](ROADMAP.md), section 12 |
| Phase 5 | Not started | [ROADMAP.md](ROADMAP.md), section 13 |

A box is ticked only when its evidence exists: a file, a commit, a CI run, a test or a measurement.

### M0 · Discovery and plan (docs only)

The seven items of brief §8:

- [x] 1. The brief, saved verbatim: [docs/BRIEF.md](BRIEF.md).
- [x] 2. Inventory of `design/`: [docs/DESIGN_INVENTORY.md](DESIGN_INVENTORY.md). All 223 boards (214
  artboards and 9 fix boards) mapped to feature, milestone and engine capability, with tokens,
  components, icons, fonts, flows, sample documents, and the missing screens and states.
- [x] 3. Architecture and ADRs: [docs/ARCHITECTURE.md](ARCHITECTURE.md) and
  [ADRs 0001 to 0018](adr/README.md).
- [x] 4. Planning and tracking files: [ROADMAP.md](ROADMAP.md), this file,
  [DEPENDENCIES.md](DEPENDENCIES.md), [DESIGN_GAPS.md](DESIGN_GAPS.md) (61 verified entries, filled at
  the owner's request), [QUESTIONS.md](QUESTIONS.md) (17 questions, filled at the owner's request)
  and [BACKLOG.md](BACKLOG.md) (empty template).
- [x] 5. [CLAUDE.md](../CLAUDE.md) under 200 lines, with the path-scoped rules
  [.claude/rules/rust.md](../.claude/rules/rust.md) and
  [.claude/rules/flutter.md](../.claude/rules/flutter.md).
- [x] 6. Community files: [README.md](../README.md), [LICENSE](../LICENSE) (Apache-2.0),
  [CONTRIBUTING.md](../CONTRIBUTING.md), [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md),
  [SECURITY.md](../SECURITY.md), [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) (licence texts
  for the third-party material inside `design/`) and [.gitignore](../.gitignore).
- [x] 7. Committed and pushed to `m0-plan` in Conventional Commits (see `git log`), and the summary
  and the questions in [QUESTIONS.md](QUESTIONS.md) sent to the owner on 2026-10-14.
- [x] The owner approves M0. Evidence: pull request #1 (`m0-plan`) merged into `main` as `fe99894`,
  and the owner's go-ahead for M1 on 2026-10-15.

### M1 · Foundations

Workspace, Flutter app, bridge, token pipeline, component library, light and dark themes, l10n
(en, tr, ar), app shell, start screen, settings skeleton, CI green (brief §7). Steps from
[ROADMAP.md](ROADMAP.md), section 5; how they are executed is in the [M1 plan](#m1-plan):

- [ ] Step 1. Cargo workspace, crate skeletons, toolchain, cargo-deny, CI matrix. Implemented in the
  working tree (fmt, clippy, the workspace tests and `cargo deny check` pass in the development
  container); ticked when CI is green.
- [ ] Step 2. Flutter app skeleton. Skeleton committed (`23a09c3`); the Flutter CI job, the builds and
  the Ubuntu 22.04 floor come with phase C4.
- [ ] Step 3. flutter_rust_bridge wiring
- [ ] Step 4. Token generator. `tools/tokens` and `tokens.g.dart` done (phase D2, 125 tests);
  `theme.dart`, the reduced-motion test and the S6 literal check follow in phase F.
- [ ] Step 5. Fonts and icons. `tools/fonts` with the 18 committed TTFs and `tools/icons` with the 229
  SVGs, `IconName` and the provenance table done (phases D3 and D4); the pubspec declarations, the Icon
  widget, the coverage golden and LicenseRegistry follow in phase F.
- [ ] Step 6. Design references. `tools/design-refs` renders all 224 PNGs offline and deterministically
  in the development container; the CI workflow (phase D5) and the build-output scan are pending.
- [ ] Step 7. Component library. The component spec is done ([COMPONENTS.md](COMPONENTS.md),
  phase G0).
- [ ] Step 8. App shell
- [ ] Step 9. Start screen and settings skeleton
- [ ] Step 10. Localization en, tr and ar, right to left, locale-aware casing
- [ ] Step 11. Golden matrix
- [ ] Acceptance criteria, standard gates and exit checks met
- [ ] [Pending owner checks](#pending-owner-checks) done by the owner, or carried forward with the
  owner's agreement
- [ ] The owner approves M1

### M2 · Open and view

- [ ] Open (dialog, drag and drop, recent files, "open with"), password unlock, repair notice,
  rendering (tiles, zoom modes, continuous, spread and book), thumbnails, outline, attachments,
  search (diacritic-insensitive, İ and ı aware), document properties, multiple tabs.
  [ROADMAP.md](ROADMAP.md), section 6.
- [ ] The owner approves M2

### M3 · Edit text core

- [ ] Editing existing text as brief §4 describes, save and save as, undo and redo, edit review
  list. [ROADMAP.md](ROADMAP.md), section 7.
- [ ] The owner approves M3

### M4 · Rest of phase 1

- [ ] Organize pages, combine and split, comments and annotations, form filling, simple signatures,
  compress, version history, command palette, toasts, background tasks, full settings.
  [ROADMAP.md](ROADMAP.md), section 8.
- [ ] The owner approves M4

### M5 · Release pipeline

- [ ] Notarized macOS DMG, signed Windows installer, GitHub Releases, auto-update, Homebrew and
  winget manifests. [ROADMAP.md](ROADMAP.md), section 9.
- [ ] The owner signs off phase 1

### Phase 2

- [ ] Add text and images, find and replace, watermark, header, footer and Bates numbering,
  redaction with verification, remove hidden information. [ROADMAP.md](ROADMAP.md), section 10.

### Phase 3

- [ ] OCR, PDF to and from Office conversion, certificate signatures, Turkish e-imza (PKCS#11),
  signature validation, compare. [ROADMAP.md](ROADMAP.md), section 11.

### Phase 4

- [ ] Form authoring, PDF/A and preflight, accessibility (PDF/UA) tools, batch actions, in-place
  translation, local AI assistant. [ROADMAP.md](ROADMAP.md), section 12.

### Phase 5

- [ ] Print production, plugins, then the web build, then tablet and mobile apps (iOS,
  Android) from the same Flutter code. [ROADMAP.md](ROADMAP.md), section 13.

## M1 plan

M1 builds the foundations of [ROADMAP.md](ROADMAP.md) section 5, whose 11 steps carry the
deliverables and acceptance criteria. It opens no PDFs. This section records how the steps are
executed.

### Delivery

- Branch `m1-foundations`, created from `origin/main` after the M0 merge. A **draft pull request** to
  `main`, opened once phase B is pushed, runs CI on every push; the owner merges it when M1 is done.
- Small Conventional Commits, pushed per phase, authored as the owner, with no AI attribution in
  commits or in pull request titles and bodies ([CLAUDE.md](../CLAUDE.md), How to work).
- Helper agents never commit. The lead reviews each chunk and commits it with explicit paths. At most
  three agents work in `app/` at once.
- Hub files have one writer, the lead: `docs/*`, `CLAUDE.md`, `.github/workflows/*`,
  `app/pubspec.yaml` (all M1 packages are added in phase C2), the ARB files, the components barrel,
  the router and the `[workspace.dependencies]` table in `Cargo.toml`. Agents return the changes they
  need in these files.
- Each commit updates its docs in the same change: DEPENDENCIES rows and hashes, DESIGN_GAPS notes,
  BACKLOG rows for disabled features, and the CLAUDE.md commands as they become real.
- A ROADMAP box is ticked only with evidence: a CI run URL, a test name or a labelled measurement.
- Development container: Ubuntu 24.04, 4 CPUs, Rust 1.99.0, Flutter 3.47.7 with Dart 3.13.5,
  Node 24.22.0, playwright-core 1.56.1 with the preinstalled Chromium 1194. The Playwright CDN and
  api.github.com are blocked there; crates.io, pub.dev, npm and GitHub release downloads work.

### Order and waves

Sequential dependencies:

- The Rust workspace (step 1) and the app skeleton (step 2) come before the bridge (step 3).
- Tokens (step 4) and fonts and icons (step 5) come before components (step 7).
- **The first golden (phase F3) must pass on the CI Linux runner before component work starts.**
- Then components (7) → shell (8) → start screen and settings (9) → l10n (10) → golden matrix (11).
- Design references (step 6) are needed only for the step 11 comparison report.

| Wave | Parallel work |
|---|---|
| 0 | lead: phase A docs (the draft pull request follows the phase B push) |
| 1 | Rust workspace, CLI and checks · `tools/tokens` · `tools/pdfium` and `tools/fonts` · `tools/design-refs` · component spec and `tools/icons` · lead: `flutter create`, app skeleton, CI |
| 2 | render thread and facade · lead: bridge (cargokit) and PDFium bundling · theme from tokens · Icon widget, licence registry and the first golden · casing and region-format utilities |
| 3 | components: the lead builds the foundations (G1), then up to three agents by group (G2 to G9), then the spec walker and gallery (G10) |
| 4 | lead: title bars (native Swift, C++ and GTK parts), then the shell agent (tabs, modes, tool rows, panels, shortcuts) alongside the start and settings agent |
| 5 | lead: translations; agents: golden matrix, golden-versus-reference report |

### Commit phases

| Phase | Commits |
|---|---|
| A docs | A1 record the owner's answers (QUESTIONS, ADR 0007 and 0013 Accepted, DEPENDENCIES, CLAUDE.md with the pull request rule, rules files, ROADMAP, ARCHITECTURE, DESIGN_GAPS, Q18) · A2 this plan → push; the draft pull request is opened once phase B is pushed |
| B Rust | B1 workspace, toolchain, lints, crate skeletons · B2 `deny.toml` · B3 CLI · B4 `tools/checks` · B5 CI (repo checks, Rust on three systems, cargo-deny) |
| C app | C1 `flutter create` and platform metadata · C2 lints, Riverpod, go_router, gen-l10n, window setup, all M1 packages · C3 pub, ARB and version checks · C4 CI for Flutter, codegen and the Ubuntu 22.04 floor |
| D tools | D1 PDFium fetch · D2 token generator · D3 icons · D4 fonts · D5 design references and their workflow |
| E bridge | E1 render thread · E2 `engine_info`, panic guard, message keys · E3 FRB and cargokit · E4 PDFium bundling · E5 CI bridge checks, integration tests, labelled measurements |
| F theme | F1 `tokens.g.dart` and theme · F2 S6 checks · F3 Icon widget, licence registry, script-coverage golden (container and CI parity proven) · F4 casing and region formatting |
| G components | G0 spec · G1 foundations and feature registry · G2 to G9 one commit per group · G10 spec walker and gallery |
| H shell | H1 title bars · H2 tabs and mode bar (IndexedStack) · H3 tool rows (future features disabled, BACKLOG rows) · H4 sidebar, canvas, panel, status bar · H5 shortcut table · H6 narrow windows (Proposed) |
| I screens | I1 settings store · I2 onboarding (language picker, welcome steps 2 and 3) · I3 start screen · I4 Settings General, Language and region, Privacy |
| J l10n | J1 Turkish complete and Arabic for every M1 string · J2 right-to-left, region-format and pseudo-locale tests |
| K goldens | K1 golden matrix · K2 golden-versus-reference report |
| L close | L1 commands in CLAUDE.md, CONTRIBUTING and README (fresh-clone dry run) · L2 close M1 (PROGRESS, ROADMAP E1 to E8, DESIGN_GAPS, BACKLOG, ARCHITECTURE) |

### Owner decisions in force (2026-10-15)

Given with the M0 go-ahead and recorded in [QUESTIONS.md](QUESTIONS.md):

- [Q01](QUESTIONS.md#q01): bundle identifier `io.github.kerembas.ferman`. Note for M5: Flathub
  verifies `io.github.<user>` against a GitHub account, and the repository's account is `KEREM-BAS`.
- [Q03](QUESTIONS.md#q03): macOS 12 or later (universal), Windows 10 22H2 and Windows 11 (x64,
  arm64), Linux best effort on Ubuntu 22.04 or later (glibc).
- [Q04](QUESTIONS.md#q04): harfrust. [ADR 0007](adr/0007-harfrust-instead-of-rustybuzz.md) is
  Accepted; rustybuzz is banned except as krilla's wrapper from the first `deny.toml`.
- [Q05](QUESTIONS.md#q05): eight mode tabs, including Tools ([G09](DESIGN_GAPS.md#g09) Decided).
- [Q08](QUESTIONS.md#q08) groups 1 and 2: Plex Sans Hebrew and Plex Sans Devanagari are bundled; CJK
  uses system fonts. [ADR 0013](adr/0013-fonts-and-icons.md) is Accepted. Groups 3 and 4 stay open.
- [Q12](QUESTIONS.md#q12): a custom Linux title bar (client-side decorations, caption buttons at the
  end, Ctrl shortcuts, Cancel-left dialogs; [G15](DESIGN_GAPS.md#g15) Decided). Packaging stays open
  until M5.
- [Q14](QUESTIONS.md#q14): "Copyright The Ferman Authors". The sign-off part stays open.
- [Q17](QUESTIONS.md#q17) parts 1 to 3: Swatinem/rust-cache in CI, `dbus` through desktop_drop (M2),
  `libfuzzer-sys` in `fuzz/` only. Part 4 stays open, and the stricter reading applies.
- Delivery: the `m1-foundations` branch and an early draft pull request, as above.
- No AI attribution in commits or in pull request titles and bodies.
- New [Q18](QUESTIONS.md#q18): the macOS App Sandbox stays on in M1, as Flutter's template sets it;
  the owner is asked before M2.

### Still Proposed in M1

Not approved, so built only as reversible tooling, kept marked **Proposed**, and listed in the M1
summary:

- [ADR 0009](adr/0009-threading-and-jobs.md) (threading and jobs) and
  [ADR 0018](adr/0018-native-file-pickers.md) (native pickers; M1 builds no picker).
- The Proposed details in ADRs 0003, 0004, 0006 and 0008.
- ROADMAP items marked Proposed: the crate-graph check and the pub deny list (both built as
  `tools/checks` checks, still Proposed), the web stub build, the feature registry, the pseudo-locale,
  the 1024 px minimum window width and the 1.5 s start budget.

### Decisions taken during M1

Taken by the lead within the approved architecture, reversible, and listed in the M1 summary:

- **flutter_svg dropped** (`246d6df`): flutter_svg and vector_graphics depend on `http`, which the pub
  deny list forbids. The 229 icons are painted by a `CustomPainter` from generated path data through
  path_parsing 1.1.0 (MIT); the SVGs in `app/assets/icons/` stay as the exported, provenance-tracked set
  ([ADR 0013](adr/0013-fonts-and-icons.md), [DEPENDENCIES.md](DEPENDENCIES.md#4-rejected)).
- **Both analyzers in CI:** `flutter analyze` (the brief's check) and `dart analyze --fatal-infos`,
  because the riverpod_lint 3.1.9 plugin's diagnostics appear only in `dart analyze` (verified with a
  deliberate `missing_provider_scope` violation).
- **Dart 3.13 constructors:** Ferman's Dart uses the `const new(...)` form, because very_good_analysis 11
  enforces `unnecessary_type_name_in_constructor` ([.claude/rules/flutter.md](../.claude/rules/flutter.md)).
- **No Playwright installer:** it also downloads an LGPL-2.1 ffmpeg build, so CI downloads the
  revision 1194 headless shell directly and passes its path to `tools/design-refs`
  ([DEPENDENCIES.md](DEPENDENCIES.md#9-known-risks)).
- **build_runner stays at 2.16.2:** 2.17 conflicts with riverpod_generator 4.0.9.
- **Message keys are lowerCamelCase ARB keys** (`errorInternal`), not dotted names, because gen-l10n
  rejects dots ([ADR 0010](adr/0010-error-handling-no-panics.md)).

### Honest recording

- **Implemented is not verified.** A box whose evidence needs hardware, people or builds that the
  development container and CI do not have stays unticked. It is marked "implemented, pending owner
  check", with a BACKLOG row or an owner action and a link to the CI artefact the owner can try.
- **Measurements are labelled with the machine** they came from (for example "GitHub ubuntu-24.04
  runner" or "development container, 4 vCPU"). They are never presented as R1 or R2 numbers.

### Pending owner checks

Checks this environment cannot do. Each is ticked only with the owner's result.

- [ ] Native-speaker review of the Turkish and Arabic strings (gate S5, step 10).
- [ ] R1 and R2 hardware checks: macOS traffic lights and full screen; Windows 11 snap layouts on
  hover over maximize; CJK system fonts with the right regional forms (step 5); the bridge zero-copy
  timing (step 3); the start-screen budget (step 9).
- [ ] arm64 app builds: the arm64 slice of the macOS universal app on Apple silicon, Windows on arm64
  and Linux on arm64.
- [ ] Windows 10 22H2: the app starts and the shell works (Q03 floor).
- [ ] The Linux title bar on GNOME and KDE.
- [ ] Screen readers: VoiceOver on macOS, Narrator or NVDA on Windows, Orca on Linux.

The design gaps to settle in M1 are listed in [ROADMAP.md](ROADMAP.md), section 5, under "Design
gaps to settle in M1".

## ADR status

Decisions taken from the brief are "Accepted (brief)". New ones stay "Proposed" until the owner
approves them ([ADR 0001](adr/0001-record-architecture-decisions.md)). Each milestone review lists
the ADRs that changed status here.

| ADR | Status | Waiting for |
|---|---|---|
| [0007 harfrust instead of rustybuzz](adr/0007-harfrust-instead-of-rustybuzz.md) | Accepted (owner, [Q04](QUESTIONS.md#q04), 2026-10-15) | — |
| [0009 threading and jobs](adr/0009-threading-and-jobs.md) | Proposed | the owner's review; M2 stops before step 1 without it |
| [0013 fonts and icons](adr/0013-fonts-and-icons.md) | Accepted: brief parts, plus Plex Sans Hebrew and Devanagari (owner, [Q08](QUESTIONS.md#q08), 2026-10-15) | — |
| [0018 native file pickers](adr/0018-native-file-pickers.md) | Proposed | [Q07](QUESTIONS.md#q07) |
| [0003](adr/0003-crate-layout-and-api-boundary.md), [0004](adr/0004-lopdf-model-pdfium-renderer.md), [0008](adr/0008-file-safety-and-saving.md) | Accepted (brief), each with one Proposed detail | the owner's review (not approved at the M0 go-ahead) |
| [0006 font pipeline](adr/0006-font-pipeline-and-missing-glyphs.md) | Accepted (brief), with one Proposed detail (`fsType`) | [Q09](QUESTIONS.md#q09) |
| [0016 licence policy](adr/0016-dependency-licence-policy.md) | Accepted (brief); three licence exceptions approved on 2026-10-15; the reading of "GPL-compatible" open | [Q17](QUESTIONS.md#q17) part 4 |
| All others | Accepted (brief) | — |

## Measurements

None yet. M1 step 3 records the bridge numbers. Every number names the machine it came from: R1 and
R2 numbers come from the owner's runs on the reference machines, other numbers are labelled with
their CI runner or development machine ([honest recording](#honest-recording)). From M2 on, every
performance budget that applies to a milestone is measured on R1 and R2 and recorded here
([ARCHITECTURE.md](ARCHITECTURE.md), section 14; gate S8 in [ROADMAP.md](ROADMAP.md)).

| Date | Milestone | Measure | Budget | Machine | Result | Evidence |
|---|---|---|---|---|---|---|

## Session log

Newest last. One row per session.

| Date | Milestone | What happened | Commits |
|---|---|---|---|
| 2026-10-13 to 2026-10-14 | M0 | Read-only discovery of `design/`: all 223 boards inventoried (214 artboards and 9 fix boards), and 60 gaps and conflicts verified against the files; a 61st (G61, search defaults) came from the review of the documents against the brief. The brief saved verbatim as `docs/BRIEF.md`; the only change is that its repository-tree block is wrapped in a `text` code fence so it renders. Wrote the M0 documents: inventory, architecture, ADRs 0001 to 0018, roadmap, this file, dependencies, design gaps, questions, backlog, CLAUDE.md and the rules files, README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY and `.gitignore`. Removed the tracked `.DS_Store` and ignored it. `design/` unchanged; no application code. | see `git log` |
| 2026-10-14 | M0 | Review pass over all M0 documents against the brief, the design and each other: 72 findings, all addressed. Main changes: the file-picker interim aligned with ADR 0018 everywhere; component names follow the design system, with `Fm` kept only for the `Fm*` building blocks; G61 (accent-insensitive search on by default for every document); Q17 (three licence exceptions and the reading of "GPL-compatible") and the sign-off sub-question in Q14; the PDFium licence files and the Lucide icon provenance re-checked against the upstream archives; [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) added with the OFL-1.1, ISC and MIT texts for the third-party material already in `design/`. At the owner's request the commits were rewritten without AI attribution and the branch was renamed to `m0-plan`. Deleting the old remote branch `claude/gracious-curie-uhjwhl` was refused by the session's git access (HTTP 403), so the owner deletes it on GitHub ([Owner actions](#owner-actions)). `design/` unchanged; no application code. | see `git log` |
| 2026-10-15 | M1 | The owner approved M0 (pull request #1 merged as `fe99894`) and gave the go-ahead for M1, answering Q01, Q03, Q04 and Q05 and parts of Q08, Q12, Q14 and Q17. The answers were recorded in every document that mentions them: ADR 0007 and ADR 0013 Accepted, G06, G07, G09 and G15 Decided, rustybuzz rejected as a direct dependency, the three licence exceptions approved. Added Q18 (macOS App Sandbox), the rule against AI attribution in pull requests, the tooling pins (Node 24.22.0, playwright-core 1.56.1) and the design-reference capture rule. Wrote the [M1 plan](#m1-plan) and started M1 on `m1-foundations`; the draft pull request to `main` is opened once phase B is pushed. The owner had deleted the old remote branches. `design/` unchanged. | see `git log` |
| 2026-10-15 | M1 | Wave 1. Committed the app skeleton (`23a09c3`) and the switch from flutter_svg to path_parsing (`246d6df`). Built in the working tree, each with passing tests in the development container: the Rust workspace with the seven crate skeletons, ferman-cli and `deny.toml`; `tools/checks`; `tools/tokens` and `tokens.g.dart`; `tools/pdfium` and `tools/fonts` with the 18 IBM Plex TTFs and the PDFium licence files; `tools/icons` with the 229 SVGs, `IconName`, the provenance table and the component spec ([COMPONENTS.md](COMPONENTS.md)); `tools/design-refs` (224 PNGs offline, identical over six full renders); the first CI workflow. Reviews corrected the capture rule (the fix boards `f4a`, `f4b` and `f6a` are `div`s), dropped flutter_svg (`http`), kept the Playwright installer out of CI (LGPL ffmpeg), and added G62 and G63. The docs, CLAUDE.md commands and DEPENDENCIES rows now describe what exists. `design/` unchanged. | `23a09c3`, `246d6df`; the rest by phase |
