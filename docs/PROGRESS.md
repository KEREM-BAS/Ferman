# Progress

> **Start every session by reading this file.** Then read [CLAUDE.md](../CLAUDE.md) and the part of
> the [brief](BRIEF.md) that covers the task (brief §9).

This file holds the current status, the milestone checklist, the plan for the next session, the
measurements and the session log. Detail for each milestone (scope, steps, acceptance criteria,
exit checks) is in [ROADMAP.md](ROADMAP.md).

Related: [roadmap](ROADMAP.md) · [questions](QUESTIONS.md) · [design gaps](DESIGN_GAPS.md) ·
[backlog](BACKLOG.md) · [architecture](ARCHITECTURE.md) · [ADRs](adr/README.md)

## Current status

| Topic | State |
|---|---|
| Milestone | **M0, discovery and plan: documents complete, waiting for the owner's approval** |
| Next | M1, foundations, once the owner approves M0. No application code is written before that (brief §8). |
| Application code | none |
| Open questions | 16 ([Q01](QUESTIONS.md#q01) to [Q16](QUESTIONS.md#q16)), including the three brief §8 requires: Q01 bundle identifier, Q02 code-signing publisher name, Q03 minimum OS versions |
| Proposed ADRs | 0007, 0009, 0013 in part, 0018 (see [ADR status](#adr-status)) |
| Design gaps | 61 recorded: 45 Decided, 16 Needs owner, 0 Resolved |
| Backlog | empty: nothing is disabled yet |
| Last updated | 2026-10-14 |

## Milestone checklist

| Milestone | Status | Details |
|---|---|---|
| M0 Discovery and plan | Documents complete, pending owner approval | [ROADMAP.md](ROADMAP.md), section 4 |
| M1 Foundations | Not started | [ROADMAP.md](ROADMAP.md), section 5 |
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
  the owner's request), [QUESTIONS.md](QUESTIONS.md) (16 questions, filled at the owner's request)
  and [BACKLOG.md](BACKLOG.md) (empty template).
- [x] 5. [CLAUDE.md](../CLAUDE.md) under 200 lines, with the path-scoped rules
  [.claude/rules/rust.md](../.claude/rules/rust.md) and
  [.claude/rules/flutter.md](../.claude/rules/flutter.md).
- [x] 6. Community files: [README.md](../README.md), [LICENSE](../LICENSE) (Apache-2.0),
  [CONTRIBUTING.md](../CONTRIBUTING.md), [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md),
  [SECURITY.md](../SECURITY.md) and [.gitignore](../.gitignore).
- [ ] 7. Committed and pushed in Conventional Commits (see `git log`), and the summary and the
  questions in [QUESTIONS.md](QUESTIONS.md) sent to the owner. Ticked only once the push and the
  summary exist, together with the matching exit check in [ROADMAP.md](ROADMAP.md), section 4.
- [ ] The owner approves M0.

### M1 · Foundations

Workspace, Flutter app, bridge, token pipeline, component library, light and dark themes, l10n
(en, tr, ar), app shell, start screen, settings skeleton, CI green (brief §7). Steps from
[ROADMAP.md](ROADMAP.md), section 5:

- [ ] Step 1. Cargo workspace, crate skeletons, toolchain, cargo-deny, CI matrix
- [ ] Step 2. Flutter app skeleton
- [ ] Step 3. flutter_rust_bridge wiring
- [ ] Step 4. Token generator
- [ ] Step 5. Fonts and icons
- [ ] Step 6. Design references
- [ ] Step 7. Component library
- [ ] Step 8. App shell
- [ ] Step 9. Start screen and settings skeleton
- [ ] Step 10. Localization en, tr and ar, right to left, locale-aware casing
- [ ] Step 11. Golden matrix
- [ ] Acceptance criteria, standard gates and exit checks met
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

- [ ] Print production, plugin system, then the web build, then tablet and mobile apps (iOS,
  Android) from the same Flutter code. [ROADMAP.md](ROADMAP.md), section 13.

## Next session: M1, after the owner approves M0

**Before starting**

1. Check that the owner has approved M0. If not, stop: no application code before approval.
2. Read the answers in [QUESTIONS.md](QUESTIONS.md), record them in their entries, and update the
   ADRs, DESIGN_GAPS entries, ROADMAP and DEPENDENCIES that depend on them.
3. Check the toolchain: Rust 1.99.0 (the M0 environment had 1.97.0; step 1 pins 1.99.0 in
   `rust-toolchain.toml`), Flutter 3.47.7 with Dart 3.13.5, Node 24 LTS for the tools,
   flutter_rust_bridge_codegen 2.13.0 and cargo-deny.
4. Write the M1 plan here, from the acceptance criteria in [ROADMAP.md](ROADMAP.md), section 5.

**First steps** (details and acceptance criteria in [ROADMAP.md](ROADMAP.md), section 5)

1. Step 1: Cargo workspace with the seven crates of brief §3, `rust-toolchain.toml`, workspace lints
   (no `unwrap`, `expect` or `panic` in library code), `deny.toml` from
   [DEPENDENCIES.md](DEPENDENCIES.md), CI on macOS, Windows and Linux, and the
   `tests/corpus/README.md` skeleton.
2. Step 2: Flutter app for macOS, Windows, Linux and web, with very_good_analysis 11, the
   riverpod_lint 3.1.9 analyzer plugin, Riverpod code generation, go_router and gen-l10n.
3. Step 3: flutter_rust_bridge 2.13.0 (crate, Dart package and codegen at the same version), the
   first two API calls, `tools/pdfium` with the pinned `chromium/7881` binaries, and the skeleton
   render thread.
4. Then steps 4 to 11: tokens, fonts and icons, design references, components, shell, start screen
   and settings, localization, goldens.

**Questions and M1**

[ROADMAP.md](ROADMAP.md) asks for Q01 and Q03 before M1 step 2. If they are not answered by then,
step 2 does not wait: it uses a marked placeholder for Q01 and the proposal for Q03, each with a
BACKLOG entry, and both must be final before M5 (signing and release). Q02 is needed only for M5.
Q04, Q05 and Q08 are needed during M1; until they are answered, M1 uses the defaults below.

| Question | Where M1 needs it | Until answered |
|---|---|---|
| [Q01](QUESTIONS.md#q01) bundle identifier | step 2, platform projects | a marked placeholder with a BACKLOG entry; final before M5 |
| [Q02](QUESTIONS.md#q02) code-signing publisher | not in M1; M5 | unsigned development builds |
| [Q03](QUESTIONS.md#q03) minimum OS versions | step 2, deployment targets and CI | the proposal: macOS 12, Windows 10 22H2 and 11, Ubuntu 22.04 or later, with a BACKLOG entry; final before M5 |
| [Q04](QUESTIONS.md#q04) harfrust (ADR 0007) | step 1, ferman-fonts dependencies and cargo-deny bans | the brief's rustybuzz; the shaper behind one interface |
| [Q05](QUESTIONS.md#q05) eight mode tabs | step 8, app shell | eight tabs, as drawn |
| [Q08](QUESTIONS.md#q08) fonts to bundle | step 5, fonts | Hebrew, Hindi and CJK use system fonts |
| [Q11](QUESTIONS.md#q11) design re-export | step 7, component library | the `Fm*` blocks, `_ds_bundle.js` and `_adherence.oxlintrc.json` |
| [Q12](QUESTIONS.md#q12) Linux chrome | step 8, title bar | system decorations with a BACKLOG entry |
| [Q14](QUESTIONS.md#q14) copyright holder | app metadata, About | "The Ferman Authors" |

The design gaps to settle in M1 are listed in [ROADMAP.md](ROADMAP.md), section 5, under "Design
gaps to settle in M1".

## ADR status

Decisions taken from the brief are "Accepted (brief)". New ones stay "Proposed" until the owner
approves them ([ADR 0001](adr/0001-record-architecture-decisions.md)). Each milestone review lists
the ADRs that changed status here.

| ADR | Status | Waiting for |
|---|---|---|
| [0007 harfrust instead of rustybuzz](adr/0007-harfrust-instead-of-rustybuzz.md) | Proposed | [Q04](QUESTIONS.md#q04) |
| [0009 threading and jobs](adr/0009-threading-and-jobs.md) | Proposed | the owner's M0 review |
| [0013 fonts and icons](adr/0013-fonts-and-icons.md) | Accepted (brief) in part, Proposed in part | [Q08](QUESTIONS.md#q08) (Plex Sans Hebrew and Devanagari) |
| [0018 native file pickers](adr/0018-native-file-pickers.md) | Proposed | [Q07](QUESTIONS.md#q07) |
| All others, 0001 to 0017 | Accepted (brief) | — |

## Measurements

None yet. M1 step 3 records the bridge numbers. From M2 on, every performance budget that applies
to a milestone is measured on the reference machines R1 and R2 and recorded here
([ARCHITECTURE.md](ARCHITECTURE.md), section 14; gate S8 in [ROADMAP.md](ROADMAP.md)).

| Date | Milestone | Measure | Budget | R1 | R2 | Evidence |
|---|---|---|---|---|---|---|

## Session log

Newest last. One row per session.

| Date | Milestone | What happened | Commits |
|---|---|---|---|
| 2026-10-13 to 2026-10-14 | M0 | Read-only discovery of `design/`: all 223 boards inventoried (214 artboards and 9 fix boards), and 60 gaps and conflicts verified against the files; a 61st (G61, search defaults) came from the review of the documents against the brief. The brief saved verbatim as `docs/BRIEF.md`; the only change is that its repository-tree block is wrapped in a `text` code fence so it renders. Wrote the M0 documents: inventory, architecture, ADRs 0001 to 0018, roadmap, this file, dependencies, design gaps, questions, backlog, CLAUDE.md and the rules files, README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY and `.gitignore`. Removed the tracked `.DS_Store` and ignored it. `design/` unchanged; no application code. | see `git log` |
