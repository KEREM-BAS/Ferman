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
| Milestone | **M1, foundations: in progress.** Started on 2026-10-15 on the branch `m1-foundations`, with draft pull request #2 to `main` |
| Previous | M0 approved on 2026-10-15: pull request #1 merged into `main` (merge commit `fe99894`) and the owner's go-ahead |
| Next | Phase G10 (the component gallery, and how goldens draw the macOS key symbols, [G87](DESIGN_GAPS.md#g87)), phase H6 (narrow windows, Proposed), phase J2 (right-to-left, region-format and pseudo-locale tests), phase K (the golden matrix and its comparison with the design references) and phase L (closing M1); see the [M1 plan](#m1-plan) |
| Application code | committed on `m1-foundations`: phases A to F (the app skeleton, the Rust workspace, `tools/checks`, the tool packages, fonts, icons and tokens, the bridge and PDFium bundling, the theme layer and the S6 checks), phase G (the component library: four groups, each reviewed and fixed, and the spec walker), phases H1 to H5 (Ferman's own title bar, the shell, the shortcut table), phases I1 to I4 (the settings store, first run, the start screen, the settings skeleton) and phase J1 (Turkish complete and Arabic for every M1 string, pending native review) |
| Questions | 19 entries: 4 answered (Q01, Q03, Q04, Q05), 4 answered in part (Q08, Q12, Q14, Q17), 11 open (Q02, Q06, Q07, Q09, Q10, Q11, Q13, Q15, Q16, Q18, Q19); see [QUESTIONS.md](QUESTIONS.md#summary) |
| Proposed ADRs | 0009 and 0018; the Proposed details in 0003, 0004, 0006 and 0008; the reading of "GPL-compatible" in 0016 ([Q17](QUESTIONS.md#q17) part 4) (see [ADR status](#adr-status)) |
| Design gaps | 93 recorded: 81 Decided, 12 Needs owner, 0 Resolved (G62 to G93 found in M1) |
| Backlog | 91 open and 1 done: B001 to B005 from the casing and region-format work, B006 and B007 from the bridge and bundling work, B008 and B009 from the title bars, B010 to B017 from the component library, B018 to B092 from the shell, first run, the start screen and Settings; B003 (parsing region numbers) shipped in M1 |
| Owner actions | 1 open (see [Owner actions](#owner-actions)) |
| Last updated | 2026-10-16 |

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

- [ ] Step 1. Cargo workspace, crate skeletons, toolchain, cargo-deny, CI matrix. Committed; CI run
  [38802741500](https://github.com/KEREM-BAS/Ferman/actions/runs/38802741500) (pull request #2, head `18c7471`) was green on the three systems and
  evidences every ROADMAP box except the Proposed crate-graph check, which waits for the owner.
- [ ] Step 2. Flutter app skeleton. Committed with its CI (phase C4); run [38802741500](https://github.com/KEREM-BAS/Ferman/actions/runs/38802741500) was green on the three
  systems, with the Ubuntu 22.04 floor build. Open: the platform-projects box (arm64 builds and
  Windows 10 are owner checks) and the two Proposed boxes.
- [ ] Step 3. flutter_rust_bridge wiring. `tools/pdfium` (phase D1) and the render thread and engine
  facade (phases E1 and E2: PDFium binds on its own thread, async `engine_info()`, `ferman info
  --pdfium`, the `frb` mirrors) committed. Phase E3 committed (`0ae4f29`, `1554fb2`, `4b8c5c3`,
  `16eae39`): flutter_rust_bridge 2.13.0 through vendored cargokit, the generated bindings, the engine
  services with the start-up API-version check, the one-file integration test, the CI codegen check
  and the `bridge_imports` check; the engine library is opened by absolute path beside the executable
  (`b9b14ec`). The macOS PDFium fetch is fixed (`9393190`), and run
  [38822085341](https://github.com/KEREM-BAS/Ferman/actions/runs/38822085341) (head `7914bfc`) passed the PDFium tests in the Rust jobs on the three systems and the
  bridge integration test on Linux and Windows; on macOS the test found no engine library, which
  `b9b14ec` fixes. Profile builds now carry the bridge too (`ba9f6d2`: `cargokit.yaml` lists debug,
  profile and release), the Ubuntu 22.04 job checks that the release engine exports it (`99a75e1`), and
  `app/test_driver/integration_test.dart` runs the integration test in profile mode (`be0a04b`). Phase
  E4 (PDFium bundled in the app) is committed (`3e7bf8e`, `52603cb`) and verified on Linux in the
  development container: the release bundle holds `lib/libpdfium.so`, byte-identical to the pinned
  library, and the 5 integration tests pass with PDFium loaded through the bridge. CI run
  [38823480726](https://github.com/KEREM-BAS/Ferman/actions/runs/38823480726) (head `52603cb`) was green on the three systems, so the ROADMAP boxes it
  evidences are ticked, and run [38824955001](https://github.com/KEREM-BAS/Ferman/actions/runs/38824955001) (head `0d2b562`) ticked the version box
  (`dcdf8a3`); only the zero-copy box stays open. The bridge
  byte transfer misses its target in debug and profile builds; the options are in ADR 0009 and the
  decision is [Q19](QUESTIONS.md#q19) ([Measurements](#measurements)).
- [ ] Step 4. Token generator. `tools/tokens` and `tokens.g.dart` done (phase D2, 125 tests); the
  theme layer, the live theme switch and reduced-motion widget tests and the S6 checks done (phases
  F1 and F2: 67 theme tests, 83 S6 fixture tests); `check_all` now runs 15 checks, `bridge_imports`
  included, and all pass; ticked when CI is green.
- [ ] Step 5. Fonts and icons. `tools/fonts` with the 18 committed TTFs and `tools/icons` with the 229
  SVGs, `IconName` and the provenance table done (phases D3 and D4); the pubspec declarations came
  with the fonts (`67fd234`). Phase F3 added the Icon widget and its painter, the LicenseRegistry
  entries (registered by `bootstrap()`), and the script-coverage and icon goldens, which match on the
  CI Linux runner (run [38819082054](https://github.com/KEREM-BAS/Ferman/actions/runs/38819082054)). The script-coverage golden led to the `--font-ui` order for every
  UI language but CJK ([G64](DESIGN_GAPS.md#g64)). The CJK check on R1, R2 and Linux is a pending
  owner check.
- [ ] Step 6. Design references. `tools/design-refs` renders all 224 PNGs offline and deterministically
  in the development container. The design-reference workflow (phase D5) renders the M1 boards twice
  on pull requests and every board twice on demand; its pull-request runs are green, with the
  Chromium hash pinned from the first. A full on-demand run in CI and the build-output scan are
  pending.
- [ ] Step 7. Component library. The component spec is done ([COMPONENTS.md](COMPONENTS.md),
  phase G0). Phase G1 committed the foundations (`b2a22af`): `FermanInteractive` (states,
  activation, disabled with a reason), `FocusRing`, `FermanForcedStates`, `FermanAnchoredLayout`,
  `Kbd`, `Tooltip` and the localized "Available in a future version" (`093dfd0`), with 45 widget
  tests. The four component groups are committed: A (buttons, feedback, the drop zone and the panel
  section; `d2211d7`), B (forms, the popover, the overlays, the date picker, the mention list and
  FmNumber; `4374b53`), C (navigation, the annotation tools, document tabs, window controls and the
  save indicator; `e7176e5`) and D (the page thumbnail, the editing marks and boxes, the annotation
  marks, the form field, the signature pad, the comment card and the thumbnail badges; `4e4eebf`).
  Each group had an adversarial review and its confirmed findings fixed: A (21, `0d9ccb5`), C (32,
  `7e7b455`), D (39, `1ac9344`) and B (64, `567da58`). A second check of the riskiest B fixes found
  11 regressions, all fixed (`505653d`): popups inside modals, modals left over a pushed route,
  number parsing and picker focus. Every group's Flutter-only parameters are in the spec, with
  decisions 20 to 41 in [COMPONENTS.md](COMPONENTS.md#ambiguities-and-decisions), G67 to G80 and
  B010 to B017. The spec walker (`tools/checks` `component_spec`) runs in `check_all` (16 checks).
  CI runs [38852612065](https://github.com/KEREM-BAS/Ferman/actions/runs/38852612065),
  [38855104204](https://github.com/KEREM-BAS/Ferman/actions/runs/38855104204) and
  [38861303299](https://github.com/KEREM-BAS/Ferman/actions/runs/38861303299) were green on the
  three systems. The component gallery (G10) is pending.
- [ ] Step 8. App shell. Phase H1, the title bars: the native parts are in `1a39443` (macOS
  light placement, Windows snap layouts, the Linux header bar), and CI run
  [38831554960](https://github.com/KEREM-BAS/Ferman/actions/runs/38831554960) built and ran them on
  the three systems. The Flutter side hides the system title bar at start-up and frames every
  screen with Ferman's own (`TitleBar` in `WindowFrame`, [ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration)):
  drag and double-click, the caption buttons, the snap-layout area and the Windows top resize edge.
  A review of H1 confirmed 9 findings, all fixed (`1d50128`, `7e7b455`, `567da58`): among them
  double-clicks counted with the system's interval and distance, no window move on a trackpad
  scroll, no system title bar flashing at launch on macOS, and modals above the title bar (the root
  overlay, with the title bar giving the snap-layout area back while a modal is open). Phases H2 to
  H5 built the shell (`app/lib/features/shell/`): the title-bar content per screen
  ([G88](DESIGN_GAPS.md#g88)), the eight mode tabs over an `IndexedStack`, the tool rows of every
  mode with their future features disabled, the sidebar, the canvas, the right panel, the status
  bar and one shortcut table with its collision test ([G81](DESIGN_GAPS.md#g81) to
  [G87](DESIGN_GAPS.md#g87)); a review confirmed 19 findings, all fixed or recorded. The disabled
  controls are B018 to B092 in [BACKLOG.md](BACKLOG.md). The shell is reachable at `/debug/shell`
  until M2 opens documents. H6 (narrow windows) is Proposed and pending.
- [ ] Step 9. Start screen and settings skeleton. Phase I1 committed the settings store
  (`a2f1988`): `settings.json` in the app support directory through a temporary file and a rename,
  loaded before the first frame; the theme choice persists across restarts (22 tests). Phases I2 to
  I4 built first run (the language picker of a1-1 with all 21 languages, a1-2b with the four
  network uses, a1-2c with Apache-2.0 and the unshipped features marked), the start screen of a1-5
  (its entry points disabled until their milestones) and Settings with its 11 panes (General,
  Language and region and Privacy built, the others present and disabled). Settings is a
  window-styled surface inside the main window, because Flutter 3.47.7 has no stable desktop
  multi-window support ([ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration),
  [G89](DESIGN_GAPS.md#g89), B090); a failed save shows a warning ([G90](DESIGN_GAPS.md#g90)); the
  region picker lists every CLDR territory, named in the UI language and in its own
  ([G91](DESIGN_GAPS.md#g91)). A review confirmed 43 findings, all fixed or recorded. Goldens come
  with step 11.
- [ ] Step 10. Localization en, tr and ar, right to left, locale-aware casing. Casing
  (`LocaleCasing`) and region formats (`Region`, `RegionFormat`, with percentages) are done, and the
  region follows the region setting, not the UI language ([G34](DESIGN_GAPS.md#g34)). Phase J1:
  Turkish is complete and Arabic covers every M1 string (297 keys); every string waits for a
  native speaker (gate S5, [pending owner checks](#pending-owner-checks)).
  `tools/checks` `arb_parity` now fails when a Turkish value repeats the English one, unless the key
  is on its reviewed list (names, file formats, paper sizes). Arabic, Persian and Hebrew switch the
  UI to right to left at once; Persian and Hebrew show English strings until they are translated
  ([G93](DESIGN_GAPS.md#g93)). Phase J2 (the right-to-left, region-format and pseudo-locale tests)
  is pending.
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

- Branch `m1-foundations`, created from `origin/main` after the M0 merge. **Draft pull request #2** to
  `main`, opened on 2026-10-15, runs CI on every push; the owner merges it when M1 is done.
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
- **The first golden (phase F3) must pass on the CI Linux runner before component work starts.** It
  does: the Flutter Linux job of run [38819082054](https://github.com/KEREM-BAS/Ferman/actions/runs/38819082054) passed the script-coverage and icon goldens.
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
- **UI font order:** every UI language but CJK uses the design's `--font-ui` order, IBM Plex Sans
  first, ar, fa, he and hi included, as the Arabic boards do. The Arabic, Hebrew and Devanagari fonts
  lack İ, ş and ế, and with one of them first Flutter builds those letters from base plus mark with
  misplaced marks ([G64](DESIGN_GAPS.md#g64), [ARCHITECTURE.md §11.5](ARCHITECTURE.md#115-fonts-in-the-ui),
  [ADR 0013](adr/0013-fonts-and-icons.md)).
- **Start-up order:** `bootstrap()` calls `registerLicenses()` and `initializeRegionFormats()` before
  `setUpWindow()`, so the region formats are loaded before the localization delegates.
- **CI:** the Rust tests that need PDFium run on all three systems (`tools/pdfium/fetch.sh` for the
  runner's platform, an absolute `FERMAN_PDFIUM_PATH`, and `ferman info --json --pdfium` must report
  `loaded`); goldens run on Linux only, and macOS and Windows run `flutter test --exclude-tags
  golden`. Every golden test also passes `skip: !isGoldenHost` (`app/test/helpers/golden_config.dart`,
  `7914bfc`): off Linux alchemist's test variant has no values, and flutter_test failed both golden
  files while loading them, before `--exclude-tags golden` applies. The PDFium archives are downloaded
  before they are verified (`18c7471`), and the Chromium headless shell's SHA-256 is pinned in
  `tools/design-refs/fetch-chromium.sh` (`d745c721…c91f`) from the first CI download on 2026-10-15
  (`9b7fcec`). The Flutter jobs and the Ubuntu 22.04 job fetch PDFium (cached) before the desktop
  build, and the Dart licence step runs the full command of
  [DEPENDENCIES.md §8](DEPENDENCIES.md#8-dart-licence-check) (`52603cb`).
- **`s6_literals` skips `app/lib/engine/`:** it holds engine services and no widgets; the other S6
  checks still cover it.
- **The Arabic boards are the Saudi Arabia region:** both draw Arabic-Indic digits, and the United
  Arab Emirates region writes Latin digits as CLDR does ([G34](DESIGN_GAPS.md#g34)).
- **`FERMAN_PDFIUM_PATH` is honoured in every build**, release included, as specified: it lets
  packagers and developers point the app at another PDFium build, and anyone who can set a process's
  environment can already run code as the user.
- **cargokit is vendored** from the flutter_rust_bridge 2.13.0 template with two changes marked
  "Ferman patch" (the toolchain from `rust-toolchain.toml`; the library name with `-` turned into `_`).
  Precompiled binaries are not configured, so it always builds the engine from source
  ([app/rust_builder/README.md](../app/rust_builder/README.md)).
- **The engine library is opened by absolute path** beside the executable (`b9b14ec`), not through
  flutter_rust_bridge's default loader, which first tries a folder relative to the current directory
  and on macOS looks for a framework named after the crate
  ([ARCHITECTURE.md §3.9](ARCHITECTURE.md#39-versioning)).
- **One integration-test file:** Linux desktop cannot launch the app a second time for a second file,
  so every integration test lives in `app/integration_test/app_test.dart`.
- **Settings inside the main window:** Flutter 3.47.7's windowing API is not stable, so Settings is a
  window-styled surface at `/settings` with its own close button, Esc and ⌘W
  ([ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration), [G89](DESIGN_GAPS.md#g89), B090).
- **Modals in the root overlay:** modal dialogs and the command palette cover Ferman's title bar
  too, and the title bar gives the Windows snap-layout area back while one is open
  ([COMPONENTS.md](COMPONENTS.md) decision 41).
- **Turkish values that repeat the English fail `arb_parity`,** unless the key is on the check's
  reviewed list with its reason, so English copied in as a stand-in cannot pass for a translation.
- **Persian and Hebrew mirror the UI** with English strings: the direction follows the chosen
  language, not the locale of the strings ([G93](DESIGN_GAPS.md#g93), ARCHITECTURE §11.4).

### Honest recording

- **Implemented is not verified.** A box whose evidence needs hardware, people or builds that the
  development container and CI do not have stays unticked. It is marked "implemented, pending owner
  check", with a BACKLOG row or an owner action and a link to the CI artefact the owner can try.
- **Measurements are labelled with the machine** they came from (for example "GitHub ubuntu-24.04
  runner" or "development container, 4 vCPU"). They are never presented as R1 or R2 numbers.

### Pending owner checks

Checks this environment cannot do. Each is ticked only with the owner's result.

- [ ] Native-speaker review of the Turkish and Arabic strings (gate S5, step 10). Every string in
  `app/lib/l10n/app_tr.arb` and `app_ar.arb` (297 keys). The M1 summary carries a review table (key,
  English, Turkish, Arabic, where the translation came from, the translator's note).
- [ ] R1 and R2 hardware checks: macOS traffic lights (placement in left to right and right to left,
  after resizing and in and out of full screen) and the title-bar double-click setting; Windows 11
  snap layouts on hover over maximize, its hover and press, and the top resize edge, both giving way
  to the scrim while a dialog is open; CJK system fonts with the right regional forms (step 5); the bridge zero-copy
  timing (step 3, in profile mode: `flutter drive --profile -d <linux|windows|macos> --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart` from `app/`); the start-screen
  budget (step 9).
- [ ] arm64 app builds: the arm64 slice of the macOS universal app on Apple silicon, Windows on arm64
  and Linux on arm64.
- [ ] Windows 10 22H2: the app starts and the shell works (Q03 floor).
- [ ] The Linux title bar on GNOME and KDE.
- [ ] Screen readers: VoiceOver on macOS, Narrator or NVDA on Windows, Orca on Linux.
- [ ] Goldens: the first goldens (script coverage and icons) were generated in the development
  container, not on the CI runner as ROADMAP §5 step 11 asks; the CI Linux runner proves them (they
  passed in the Flutter Linux job of run [38819082054](https://github.com/KEREM-BAS/Ferman/actions/runs/38819082054)). The owner accepts this or asks for
  goldens generated by CI.

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

M1 step 3 records the bridge numbers. Every number names the machine it came from: R1 and R2 numbers
come from the owner's runs on the reference machines, other numbers are labelled with their CI
runner or development machine ([honest recording](#honest-recording)). From M2 on, every performance
budget that applies to a milestone is measured on R1 and R2 and recorded here
([ARCHITECTURE.md](ARCHITECTURE.md), section 14; gate S8 in [ROADMAP.md](ROADMAP.md)).

| Date | Milestone | Measure | Budget | Machine | Result | Evidence |
|---|---|---|---|---|---|---|
| 2026-10-15 | M1 | `debug_bytes`: a 1 MiB `Vec<u8>` from Rust to Dart, round trip timed in Dart | under 0.2 ms on R1 and R2, profile or release build | development container, Linux x64, Xvfb, debug build of app and engine (not R1 or R2) | 52–63 ms over four runs, one cold call each; **does not meet the target** | integration test "a 1 MiB byte vector crosses the bridge" (`app/integration_test/app_test.dart`), `flutter test integration_test -d linux` before `be0a04b` |
| 2026-10-15 | M1 | `debug_bytes`: a 1 MiB `Vec<u8>` from Rust to Dart, round trip timed in Dart | under 0.2 ms on R1 and R2, profile or release build | development container, Linux x64, Xvfb, profile build of app and engine (not R1 or R2) | 20 warm calls after one warm-up: minimum 3,310 µs, median 5,915 µs; **does not meet the target** | the same test since `be0a04b`, run with `flutter drive --profile -d <linux|windows|macos> --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart` |
| 2026-10-15 | M1 | `debug_bytes`: a 1 MiB `Vec<u8>` from Rust to Dart, round trip timed in Dart | under 0.2 ms on R1 and R2, profile or release build | CI runner `macos-15`, debug build of app and engine (not R1 or R2) | 46,351 µs, one cold call; **does not meet the target** | run [38823480726](https://github.com/KEREM-BAS/Ferman/actions/runs/38823480726), Flutter (macos-15), step "Integration test (macOS and Windows)" (before `be0a04b`) |

Both results are far over the target, because the transfer copies. With codegen 2.13's default
`full_dep: false` the generated glue uses the SSE codec: its Rust encoder writes the `Vec<u8>` one byte
at a time into a serialisation buffer, and Dart copies it out with `getUint8List`. `full_dep: true`
(the Dco codec) needs ffigen as a dev dependency and libclang for codegen; tried in a scratch copy, it
generated bindings whose Dart did not compile (ffigen's C struct `ApiVersion` clashes with the Dart
mirror). The options (the Dco codec, an opaque pixel buffer read through a pointer view, the texture
registry) and a proposal are in
[ADR 0009](adr/0009-threading-and-jobs.md#tile-transfer-m1-measurements-and-options-proposed); the
owner decides in [Q19](QUESTIONS.md#q19), before M2 step 3. The ROADMAP zero-copy box stays open until
R1 and R2 are measured.

## Session log

Newest last. One row per session.

| Date | Milestone | What happened | Commits |
|---|---|---|---|
| 2026-10-13 to 2026-10-14 | M0 | Read-only discovery of `design/`: all 223 boards inventoried (214 artboards and 9 fix boards), and 60 gaps and conflicts verified against the files; a 61st (G61, search defaults) came from the review of the documents against the brief. The brief saved verbatim as `docs/BRIEF.md`; the only change is that its repository-tree block is wrapped in a `text` code fence so it renders. Wrote the M0 documents: inventory, architecture, ADRs 0001 to 0018, roadmap, this file, dependencies, design gaps, questions, backlog, CLAUDE.md and the rules files, README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY and `.gitignore`. Removed the tracked `.DS_Store` and ignored it. `design/` unchanged; no application code. | see `git log` |
| 2026-10-14 | M0 | Review pass over all M0 documents against the brief, the design and each other: 72 findings, all addressed. Main changes: the file-picker interim aligned with ADR 0018 everywhere; component names follow the design system, with `Fm` kept only for the `Fm*` building blocks; G61 (accent-insensitive search on by default for every document); Q17 (three licence exceptions and the reading of "GPL-compatible") and the sign-off sub-question in Q14; the PDFium licence files and the Lucide icon provenance re-checked against the upstream archives; [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) added with the OFL-1.1, ISC and MIT texts for the third-party material already in `design/`. At the owner's request the commits were rewritten without AI attribution and the branch was renamed to `m0-plan`. Deleting the old remote branch `claude/gracious-curie-uhjwhl` was refused by the session's git access (HTTP 403), so the owner deletes it on GitHub ([Owner actions](#owner-actions)). `design/` unchanged; no application code. | see `git log` |
| 2026-10-15 | M1 | The owner approved M0 (pull request #1 merged as `fe99894`) and gave the go-ahead for M1, answering Q01, Q03, Q04 and Q05 and parts of Q08, Q12, Q14 and Q17. The answers were recorded in every document that mentions them: ADR 0007 and ADR 0013 Accepted, G06, G07, G09 and G15 Decided, rustybuzz rejected as a direct dependency, the three licence exceptions approved. Added Q18 (macOS App Sandbox), the rule against AI attribution in pull requests, the tooling pins (Node 24.22.0, playwright-core 1.56.1) and the design-reference capture rule. Wrote the [M1 plan](#m1-plan) and started M1 on `m1-foundations`; the draft pull request to `main` is opened once phase B is pushed. The owner had deleted the old remote branches. `design/` unchanged. | see `git log` |
| 2026-10-15 | M1 | Wave 1. Committed the app skeleton (`23a09c3`) and the switch from flutter_svg to path_parsing (`246d6df`). Built in the working tree, each with passing tests in the development container: the Rust workspace with the seven crate skeletons, ferman-cli and `deny.toml`; `tools/checks`; `tools/tokens` and `tokens.g.dart`; `tools/pdfium` and `tools/fonts` with the 18 IBM Plex TTFs and the PDFium licence files; `tools/icons` with the 229 SVGs, `IconName`, the provenance table and the component spec ([COMPONENTS.md](COMPONENTS.md)); `tools/design-refs` (224 PNGs offline, identical over six full renders); the first CI workflow. Reviews corrected the capture rule (the fix boards `f4a`, `f4b` and `f6a` are `div`s), dropped flutter_svg (`http`), kept the Playwright installer out of CI (LGPL ffmpeg), and added G62 and G63. The docs, CLAUDE.md commands and DEPENDENCIES rows now describe what exists. Committed by phase (A: `946e50d`, `8c6150a`; B: `249d76b` to `f0e2c06`; D: `993bb16` to `879b5e7`; CI: `0096014`), pushed, and draft pull request #2 opened. The first CI run was cancelled by the next push; the Chromium hash was then pinned from the first design-reference run, and CI downloads the PDFium archives before verifying them. CI run [38802741500](https://github.com/KEREM-BAS/Ferman/actions/runs/38802741500) (head `18c7471`) was green in all ten jobs on Ubuntu, macOS and Windows, so the evidenced boxes of ROADMAP §5 steps 1 and 2 are ticked. `design/` unchanged. | `23a09c3`, `246d6df`, `946e50d` to `0096014`, `9b7fcec`, `18c7471`, `19c4beb` |
| 2026-10-15 | M1 | Wave 2 (phases E1, E2 and F1 to F4), each part reviewed and fixed before its commit: the render thread binds PDFium on its own thread and reports it loaded only after a real call; the engine facade with async `engine_info()` and the test-only debug calls, with the facade hidden from bridge codegen and `Box::pin` instead of `pin!`; the S6 checks in `tools/checks`; the theme layer over the tokens with a live theme switch and reduced motion; the Icon widget, the licence registry and the first two goldens; locale-aware casing and region formats; CI runs the PDFium tests on three systems and goldens on Linux only. The script-coverage golden showed misplaced marks with a script font first, so every UI language but CJK uses `--font-ui` (G64); G65 recorded; G34 corrected (both Arabic boards draw Arabic-Indic digits); five BACKLOG rows; the docs updated. CI run [38819082054](https://github.com/KEREM-BAS/Ferman/actions/runs/38819082054) (head `41613ea`) failed on macOS (the PDFium fetch in the Rust job) and on macOS and Windows (the golden test files do not load under `--exclude-tags golden`); Linux passed, goldens included. Fixing it comes first. `design/` unchanged. | `41b80c5`, `0e52fc5`, `27f9e9e`, `9750c83`, `8e1a891`, `069d3f2`, `41613ea` |
| 2026-10-15 | M1 | Wave 2, phases E3 and E4, and the red CI. The red run 38819082054 was fixed: `fetch.sh` reads the Mach-O header without `od -j` and awk arithmetic, which failed with the BSD tools on macOS, and CI runs `tools/pdfium/selftest.sh` in the Rust jobs on macOS and Linux (`9393190`); every golden test passes `skip: !isGoldenHost`, so macOS and Windows declare no golden test (`7914bfc`); `app/analysis_options.yaml` leaves the vendored cargokit build tool out, after run 38821129509 reported 51 issues there (`a704ce2`). Phase E3: flutter_rust_bridge 2.13.0 through cargokit (the `rust_lib_ferman` FFI plugin, two marked patches), the generated bindings, the engine services and providers with the start-up API-version check and a web stub, and the one-file integration test (`0ae4f29`); the CI codegen check with cached flutter_rust_bridge_codegen 2.13.0 and cargo-expand 1.0.127 (`1554fb2`); the `bridge_imports` check, the 15th in `tools/checks` (`4b8c5c3`); the cargokit patches listed in the rust_builder README (`16eae39`). Run [38822085341](https://github.com/KEREM-BAS/Ferman/actions/runs/38822085341) (head `7914bfc`) was green in every job but Flutter (macos-15): the build worked through CocoaPods, with Flutter's warning that `rust_lib_ferman` does not support Swift Package Manager (B007), but the integration test found no engine library, because the bridge's default macOS loader looks for `ferman_api.framework`. The app now opens the engine library by absolute path beside the executable (`b9b14ec`). Phase E4: PDFium bundled in the app on each system, with the integration test asserting `loaded` and `chromium/7881`; CI fetches PDFium before the desktop builds and runs the full Dart licence check (`3e7bf8e`, `52603cb`). Verified on Linux in the development container: the bundle holds the pinned `libpdfium.so`, the 5 integration tests pass, and the 1 MiB bridge transfer measured 52–63 ms in a debug build, far over the 0.2 ms target; the codec decision is open. Profile builds shipped the engine without the bridge (the app reported `libraryMissing`, undefined symbol `frb_get_rust_content_hash`) because `cargokit.yaml` listed only debug and release; it now lists all three modes (`ba9f6d2`), and the Ubuntu 22.04 job checks the export with `nm -D` (`99a75e1`). The transfer test now times 20 warm calls, and `app/test_driver/integration_test.dart` with flutter_driver runs it in profile mode (`be0a04b`): minimum 3,310 µs, median 5,915 µs in the container, still far over the target. Run [38823480726](https://github.com/KEREM-BAS/Ferman/actions/runs/38823480726) (head `52603cb`) was green in every job on the three systems, the full Dart licence check (107 packages), the 22.04 bundle check and PDFium loaded in all three integration tests included, so ROADMAP step 2 boxes 1, 2 and 6 were ticked again and step 3's evidenced boxes were ticked. The Dco codec (`full_dep: true`) was tried in a scratch worktree; its Dart did not compile, so the options and a proposal went into ADR 0009 and the decision became Q19. CI now also compares the codegen's version with the crate (`dcdf8a3`). The PR description lost an attribution footer that CLAUDE.md forbids. The docs record these changes: DEPENDENCIES (the codegen tools, cargokit and its build tool, `rust_lib_ferman`, flutter_driver, jni), BACKLOG B006 and B007, the Turkish percent form in G34. `design/` unchanged. | `0ae4f29`, `1554fb2`, `9393190`, `a704ce2`, `7914bfc`, `4b8c5c3`, `16eae39`, `b9b14ec`, `3e7bf8e`, `52603cb`, `ba9f6d2`, `be0a04b`, `99a75e1`, `dcdf8a3` |
| 2026-10-16 | M1 | Wave 3 (phase G) and wave 4 (phases H1 to H5, I2 to I4) with phase J1. Component agents built groups A, B, C and D under the component spec; each group had an adversarial review (A 21, B 64, C 32, D 39 confirmed findings) whose fixes were verified (format, both analyzers, the whole suite, `tools/checks`) in a clean worktree of HEAD and committed by the lead; a second check of the riskiest B fixes found 11 regressions (popups inside modals, modals left over a pushed route, number parsing, picker focus), all fixed. The spec walker passes for all 56 spec components and runs in `check_all` (16 checks); decisions 20 to 41, G67 to G80 and B010 to B017 recorded. Phase H1: Ferman's own title bar on every route, the Windows top resize edge and snap layouts, the macOS double-click setting, modals above the title bar; its review's 9 findings fixed. Phases H2 to H5: the shell with its eight modes, tool rows, sidebar, canvas, panel, status bar and one shortcut table; phases I2 to I4: first run, the start screen and Settings (a window-styled surface). Reviews of the shell (19) and the screens (43) were fixed or recorded: G81 to G93, B018 to B092, ARCHITECTURE §2.5, §11 and §12, DEPENDENCIES (shared_preferences not chosen; the region-name table). Phase J1: Turkish complete and Arabic for every M1 string (297 keys, pending native review), and `arb_parity` rejects Turkish that repeats the English. CI failures fixed on the way: a stale `router.g.dart` hash, and a host-dependent test expectation (window_manager asks `isFullScreen` before a drag on Windows; `bc0842d`'s message blamed a leaked refresh, `9e66c95` corrects it). The container restarted once; the work in the tree survived. CI runs on `7e7b455`, `2b81a0a`, `1ac9344`, `23e1696`, `408e11e` and `505653d` were green on the three systems. `design/` unchanged. | `914e1d3` to the head of this push |
