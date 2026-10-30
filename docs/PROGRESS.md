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
| Milestone | **M2, open and view: in progress** (since 2026-10-19). Pull request #4 brought wave W0 (the feature registry) and the Dco trial of W1 into `main` (`6ce74df`), and pull request #5 the app icons (`8031ddd`). Pull request #6 brought the rest of W1 (merged as `d66e28e` on 2026-10-23), pull request #7 brought W2's API, engine services and viewer (merged as `652365d` on 2026-10-30), pull request #8 the sidebar, layers, text extraction and search (merged as `34d444d` on 2026-10-30), and M2 continues on the branch `m2-open-and-view` in pull request #9 to `main`. The owner approved the [M2 plan](#m2-plan) on 2026-10-17. W1: the Dco trial; the fuzz and corpus workspaces with ferman-core's stream filters; the corpus's first wave of 23 generated files with the PDFium oracle test; the render thread with tiles, its queue and caches, and the start screen's warning when PDFium is missing; and ferman-core's open path (cross-reference reading and repair, the security handler, lopdf, the structure scan) with the two-parser check and four more fuzz targets. W2: the API's open, close and views with the open path's errors, the bridge and the app's `EngineService` for them, the viewer on the canvas, the sidebar's tabs, showing and hiding layers, text extraction and search. W3 so far: opening files through the system open panel, a drop on the window and the system (double-click, "Open with", the command line, a second launch), into tabs that keep their view |
| Previous | Phase 0 of M2 (the design sync): pull request #3 merged into `main` on 2026-10-17 (merge commit `b6fd215`; CI on `main` green, run [39022269403](https://github.com/KEREM-BAS/Ferman/actions/runs/39022269403)). M1 approved on 2026-10-16 (pull request #2, `aa7ad21`); M0 on 2026-10-15 (pull request #1, `fe99894`) |
| Next | Wave W3, the rest of opening: the recent files' page previews (B118), tabs that keep their place past twenty documents, and document properties. Documents open from the open panel, a drop on the window and the system (double-click, "Open with", the command line, a second launch) since commit 13. The Dco codec is in use and met the target on the owner's Mac; its R1 and R2 run is an owner check. [Q21](QUESTIONS.md#q21), [Q22](QUESTIONS.md#q22) and strace are asked before anything relies on them |
| Application code | in `main` since the M1 merge: phases A to F (the app skeleton, the Rust workspace, `tools/checks`, the tool packages, fonts, icons and tokens, the bridge and PDFium bundling, the theme layer and the S6 checks), phase G (the component library: four groups, each reviewed and fixed, and the spec walker), phases H1 to H5 (Ferman's own title bar, the shell, the shortcut table), phases I1 to I4 (the settings store, first run, the start screen, the settings skeleton), phase H6 (narrow windows), phases J1 and J2 (Turkish complete and Arabic for every M1 string, pending native review; the localization tests), phase K (the golden matrix and its comparison with the design references) and the first part of phase L (the CI checks, component and screen tests, the component goldens, the spec walker and the `Fm*` names) |
| Questions | 22 entries: Q01 to Q20 answered (the last ones on 2026-10-16, as proposed, with the release files for macOS, Windows and Linux on GitHub Releases, [Q15](QUESTIONS.md#q15)); [Q21](QUESTIONS.md#q21) (memory-mapping files over 256 MB) open since 2026-10-17, and [Q22](QUESTIONS.md#q22) (the password copy PDFium keeps) since 2026-10-21; see [QUESTIONS.md](QUESTIONS.md#summary) |
| Proposed ADRs | none waiting. 0020 (test corpus) and 0021 (opening files from the OS), and the details the M2 plan adds to 0008, 0009 and 0010, were approved with the [M2 plan](#m2-plan) on 2026-10-17. The crash-log placeholders of 0010 and the 640 px canvas minimum ([G95](DESIGN_GAPS.md#g95)) were approved on 2026-10-17; 0009 and 0018, the Proposed details in 0003, 0004, 0006, 0008 and 0019, and the reading of "GPL-compatible" in 0016 on 2026-10-16 (see [ADR status](#adr-status)) |
| Design gaps | 119 recorded: 96 Decided, 0 Needs owner, 23 Resolved (G62 to G99 found in M1; the last Needs owner entries decided on 2026-10-16; on 2026-10-17 export `519d42a` resolved 22 entries and settled five in part; G100 to G111 were found while planning M2, G112 with the app icons, G113 with the corpus, G114 with the open path, G115 with search, G116 with the open panel, G117 with drag and drop and G118 with the recent files, G119 with the error tabs, which resolved G116) |
| Backlog | 114 open and 6 done: B001 to B005 from the casing and region-format work, B006 and B007 from the bridge and bundling work, B008 and B009 from the title bars, B010 to B017 from the component library, B018 to B092 from the shell, first run, the start screen and Settings, B093 to B096 from narrow windows, B097 and B098 from the golden comparison, B099 and B100 from closing M1, B101 to B106 from the M2 plan (Proposed with it), B107 and B108 from the app icons, B109 from the API commit, B110 and B111 from the sidebar, B112 from text extraction, B113 and B114 from search, B115 to B118 from opening, B119 and B120 from the error tabs; B003 (parsing region numbers) and B013 (narrow windows) shipped in M1, B018 (opening files), B028 (the "+N" menu), B010 (desktop file drops) and B115 (error tabs and the unlock dialog) in M2 |
| Owner actions | 1 open (see [Owner actions](#owner-actions)) |
| Last updated | 2026-10-30 |

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
| M1 Foundations | Complete (approved 2026-10-16) | [ROADMAP.md](ROADMAP.md), section 5; [M1 plan](#m1-plan) |
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
  evidences every ROADMAP box except the crate-graph check (Proposed in M1, approved on 2026-10-16).
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
  three systems. Phase G10 built the component gallery at `/debug/gallery` (`app/lib/features/gallery/`):
  every spec component with its variants, sizes and forced states, previewed in light, dark or dim,
  standard or touch density, reduced motion, either direction and en, tr or ar; a test fails when a
  spec component has no gallery section. It found an inline TaskProgress overflowing a narrow slot
  (fixed) and a stacked ToolButton 2 px too tall at touch density (fixed in H6: 52 px at touch).
  Phase L closed the gaps an audit of the step's boxes found: 206 component goldens (every gallery
  section in light and dark, and the 46 directional ones in right to left; ARCHITECTURE §13.5);
  every interactive component reached with a real Tab key or shown to take focus on open, with the
  keys its role implies; the future-version tooltip on a single SegmentedControl option; the hover
  and focus-visible looks of NumberStepper and FmNumber; Dialog's buttons in the system's order
  (decision 43); Tab closing a Menu (decision 44, a bug the new tests found); key caps that read
  left to right and Arabic weekday names that fit (decisions 45 and 46, G98); the spec walker also
  checks item types, their fields and the variants no enum prop carries; and the `Fm*` building
  blocks keep their names as ADR 0011 says: `FmWindow`, `FmSidebar`, `FmDocPanel`, `FmStart`,
  `FmSettings` (they were `ShellScreen`, `ShellSidebar`, `ShellPanel`, `StartScreen` and
  `SettingsScreen`).
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
  until M2 opens documents. Phase H6 built narrow windows ([G95](DESIGN_GAPS.md#g95)): tool rows hide
  labels and then move tools into "More tools", mode tabs fall back to icons, side panels step aside
  before the canvas drops below 640 px, and the window's minimum is 1024 × 640 px (the width
  Proposed); the canvas never mirrors. An adversarial review confirmed 8 findings in H6 (focus
  return, the plan keyed by index, a popover left open, a lost count, a tooltip without its delay,
  relayout on colour animations, intrinsic sizes, toggles that did nothing), all fixed with tests.
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
  Turkish is complete and Arabic covers every M1 string (300 keys); every string waits for a
  native speaker (gate S5, [pending owner checks](#pending-owner-checks)).
  `tools/checks` `arb_parity` now fails when a Turkish value repeats the English one, unless the key
  is on its reviewed list (names, file formats, paper sizes). Arabic, Persian and Hebrew switch the
  UI to right to left at once; Persian and Hebrew show English strings until they are translated
  ([G93](DESIGN_GAPS.md#g93)). Phase J2 added the acceptance tests of step 10
  ([ARCHITECTURE.md §13.5](ARCHITECTURE.md#135-flutter-tests)): Arabic and placeholder parity,
  descriptions for translators, region formats in a real screen, every M1 screen mirrored in
  Arabic, Persian and Hebrew, bundled localizations, and the Proposed pseudo-locale at 140 % on
  every M1 screen at 1440 × 900 and 1024 × 768. They found the first-run feature tiles cutting off
  their labels (now wrapping, [G12](DESIGN_GAPS.md#g12)) and English strings reordering inside the
  mirrored Persian and Hebrew UI, now wrapped in left-to-right isolates by a generated class
  (`tools/l10n`, [G93](DESIGN_GAPS.md#g93)).
- [ ] Step 11. Golden matrix. Phase K1 added the 144 whole-window goldens (1440 × 900 at 1x): first
  run's language picker and steps 2 and 3, the empty start screen and Settings General (macOS and
  Windows), Language and region and Privacy, and the shell in each of the eight modes with macOS and Windows
  chrome, each in light and dark × en, tr and ar (`app/test/goldens/screens_golden_test.dart`,
  `shell_golden_test.dart`, `app/test/helpers/window_golden.dart`). macOS goldens paint simulated
  traffic lights, and the tests load DejaVu Sans Mono and Noto Sans CJK from the Linux runner for the
  macOS key symbols and the CJK language names through a test-only hook, which settles the goldens
  part of [G87](DESIGN_GAPS.md#g87) ([G96](DESIGN_GAPS.md#g96)); CI installs both and fails if their
  versions change. Two consecutive runs and a regeneration gave byte-identical PNGs. Phase K2 built
  the comparison report: `node tools/design-refs compare` lines up each golden with its board
  (`tools/design-refs/compare-map.json`: 19 pairs, f6 and f6a cropped, the canvas masked until M2,
  the Turkish and Arabic editors a12-1tr and a12-1ar and Settings Privacy a11-1h added with K1),
  scores the differing pixels and 1 − SSIM, and writes a report that the design-references workflow
  puts in the step summary and one pull-request comment (informative, not a gate). In the development
  container 17 pairs compare with a median of 1.6 % differing pixels and at most 10.7 % (a3-1d, the
  dark editor with a document);
  [G97](DESIGN_GAPS.md#g97) lists the drawn and token-built variants and the expected differences.
  The German boards are not compared (B097).
- [ ] Acceptance criteria, standard gates and exit checks met
- [ ] [Pending owner checks](#pending-owner-checks) done by the owner, or carried forward with the
  owner's agreement
- [x] The owner approves M1. Evidence: pull request #2 (`m1-foundations`) merged into `main` as
  `aa7ad21` on 2026-10-16.

### M2 · Open and view

- [ ] Open (dialog, drag and drop, recent files, "open with"), password unlock, repair notice,
  rendering (tiles, zoom modes, continuous, spread and book), thumbnails, outline, attachments,
  search (diacritic-insensitive, İ and ı aware), document properties, multiple tabs.
  [ROADMAP.md](ROADMAP.md), section 6. Progress by wave of the [M2 plan](#m2-plan):
  - W0, the feature registry (before step 1): committed. The `Feature` enum in
    `app/lib/app/feature_registry.dart` has 68 values, the features that are visible but do not work
    yet, each naming its open BACKLOG row, and every control disabled for a future version (the tool
    rows, the title bar, the mode and status bars, the sidebar and panel, the canvas, the start
    screen, first run and Settings) takes its reason from its value; a feature ships by leaving the
    registry. `tools/checks` `feature_registry`, the 18th repository check, keeps them in step.
  - W1, the Dco trial (the lead's part, before step 3): committed. The bridge uses the Dco codec
    (`full_dep: true`, ffigen 20.1.1); the M1 name clash is fixed with `cbindgen:ignore` on the
    facade; a 1 MiB transfer meets the 0.2 ms target on the owner's Mac (see
    [Measurements](#measurements)), and R1 and R2 are an owner check.
  - W1, the fuzz and corpus workspaces (commit 2 of the map): committed. Both are Cargo workspaces
    of their own, excluded from the root one. `fuzz/` builds with a pinned nightly
    (`nightly-2026-10-15`, in `fuzz/rust-toolchain.toml`) and starts with five targets, one per
    stream filter of ferman-core, the first parser (see
    [Decisions taken during M2](#decisions-taken-during-m2)). `tools/corpus` holds the generator
    registry, empty until the corpus commit, and `check`, which CI runs: every file in
    `tests/corpus/` has its README row with the right SHA-256, and generated files are current.
    ferman-core gained `limits` (the `Limits` struct of ARCHITECTURE §9.1) and `filters`. CI runs
    each fuzz target for 60 s on Linux, the corpus tool on all three systems, and cargo-deny for
    both workspaces.
  - W1, the corpus, first part (commit 3 of the map, split in two): committed. 19 generators in
    `tools/corpus` make the first wave of ADR 0020 except report-ar, letter-ja-vertical, scan-tr and
    quote-ja-scan, which came in the second part:
    - the kira-tr family (with the damaged copy and the owner-password copy);
    - truncated and disagree-pages;
    - the payslip in AES-256, RC4 40, RC4 128 and AES-128;
    - xfa-visa and the two e-Devlet forms;
    - mietvertrag-de and nda-en;
    - tez-tr, ocg-plan and js-openaction;
    - long-500 and imar-2400.

    Seventeen are committed with their expected texts and README rows. The two long ones are over
    1 MB: they are regenerated and checked by hash. The tool has its own PDF writer on lopdf, with
    composite and simple subset fonts (harfrust, skrifa, subsetter) and a standard security handler
    with seeded initialisation vectors. The PDFium oracle test (`tools/corpus/tests/oracle.rs`)
    opens every file as its generator says, and CI runs it on the three systems.
  - W1, the corpus, second part (one of the two commits kept for CI fixes): committed. Four more
    generators complete the first wave:
    - report-ar: 12 Arabic pages, shaped right to left and laid out with the bidi algorithm, in
      visual order, `/Direction /R2L`;
    - letter-ja-vertical: the `a3-15` letter in vertical text (`Identity-V`, `/W2`), with
      tate-chu-yoko and kinsoku;
    - scan-tr and quote-ja-scan: image-only scans, greyscale and one bit per pixel, made by a small
      rasteriser.

    All four are committed with their README rows. The oracle compares the Arabic and the vertical
    file by characters, because PDFium guesses their order.
  - W1, the render thread (commit 4 of the map): committed.
    - ferman-render loads a document into PDFium from its bytes without a copy and reads every
      page size. Views take wanted sets of tiles and thumbnails, with priority classes and
      generations, and each bitmap goes to every view that still wants it.
    - Tiles are 512 × 512 BGRA in quarter-octave zoom buckets, cut to the page at its edges and
      rendered with a 32-pixel margin, so text shows no seam at tile edges.
    - The caches are capped by bytes, least recently used first: tiles 256 MiB and thumbnails
      64 MiB by default, with 8 loaded pages per document.
    - The PDFium tests (`crates/ferman-render/tests/pdfium.rs`, on the three systems in CI) check
      geometry and `/Rotate`, the seams, ten identical runs over eight corpus files, the
      wanted-set rules, the caches, closing, and three views at once: 20 s in CI, and 10 minutes
      on the owner's Mac without a crash or a deadlock (see [Measurements](#measurements)).
    - The `first_page` benchmark measures opening `long-500` and its first tile.
    - The start screen shows [G101](DESIGN_GAPS.md#g101)'s warning banner when the engine library
      or PDFium is missing, and Open file… and the drop area take its title as their reason.

    Still to come in M2: the integration test with PDFium missing and the banner's goldens (the CI
    and goldens commits), and the benchmark job in CI (W4).
  - W1, the open path (commit 5 of the map): committed. The engine side of ROADMAP step 2; the
    states the UI draws for it come with the API and the open commits.
    - ferman-core reads a file into an owned buffer with its SHA-256 (`Source`), and opens it
      (`open`): a file without a `%PDF-` header in its first kilobyte is not a PDF, with its kind
      for the details; the cross-reference data is read and checked by ferman-core itself, and
      rebuilt from a scan of the objects when it is broken, with a report of what was fixed; a
      file without a catalog cannot be opened, with a `Diagnosis` of structural facts.
    - Its own standard security handler (revisions 2 to 6, crypt filters) unlocks with the empty
      user password or the one given, owner first, and decrypts the objects after lopdf has parsed
      them through a copy with one clean table, so the password never reaches lopdf. Passwords and
      every buffer derived from them are wiped when dropped. `unlock_owner` lifts the restrictions
      for the session.
    - The structure scan reads the pages (labels, boxes, the size PDFium gives), the outline, the
      attachments, the layers, the form fields and XFA, the signatures and certification, the
      scripts, the fonts, the direction, the language and the information dictionary.
    - The two-parser check: lopdf and PDFium agree to 0.05 pt on every corpus file but
      `disagree-pages` (`crates/ferman-api/tests/open.rs`, with PDFium). ferman-render's
      `open_document` takes the password and tells a wrong one from a missing one.
    - Tests: 107 unit tests in ferman-core, the corpus test (every corpus file opens or fails as
      its README row says, with every password) and the limit tests through `open`. Four more fuzz
      targets: `syntax_object`, `xref_repair`, `security_handler` and `open_document`.

    Still to come in M2: the states and the two-parser read-only notice on the screens (commits 13
    and 15); the read-only check of a file on disk
    with the platform's file access (the open commit); the decoded-size limit per revision with
    extraction (W3); fonts inside form XObjects with the interpreter (M3).
  - W2, the API (commit 7 of the map): committed.
    - `Engine::open(path, password)` reads and parses the file on a thread of its own (64 MB stack,
      panic guard), loads it into PDFium and compares the parsers. It returns the document's id,
      why it opened read-only (repaired, the parsers disagree, an XFA-only form), its direction and
      every page's size and label. `close` ends it; `open_view`, `request` and `close_view` run a
      view's tiles and thumbnails over the render thread.
    - The open path's error kinds and message keys (ARCHITECTURE §8.2), mirrored in the `frb`
      module's `ErrorKind`.
    - `ferman open <file> [--json]`.
    - Tests: `crates/ferman-api/tests/open.rs` (with PDFium) opens the corpus through the facade:
      the read-only reasons, the labels, the errors of `truncated`, a payslip without and with a
      wrong password and a missing file, and a view that gets its thumbnail and ends with its
      document; the CLI's `open`, with and without PDFium; the error mapping.

    Still to come in M2: the calls of the later screens with those screens (an attachment's bytes with Save attachment as…, search and
    the job pool with search, the owner unlock and `Restricted` with the restricted unlock); the
    message keys in the ARB files with their check (the open screens).
  - W2, the app's engine services (commit 8 of the map): committed.
    - The bridge mirrors `open`, `close`, `open_view` (a stream whose first event names the view),
      `request_view` and `close_view`; ferman-render's ids take a number back from the bridge.
    - `EngineService` gains the same calls with plain Dart models (documents, pages, tiles and
      thumbnails, wanted items, rendered and failed updates) and the error kinds on
      `EngineException`; the fake opens the documents it is given and its views render nothing.
    - Tests: the integration test opens a one-page PDF it writes to the temporary directory (the
      sandboxed macOS app reads only its container), renders its thumbnail through the bridge,
      closes it and gets `notFound` for a missing file and a closed document; Rust tests of the
      item conversions; Dart tests of item equality and the fake.
  - W2, the viewer (commit 9 of the map): committed.
    - The canvas shows the open document (`openDocumentProvider`, which W3's open sets) through
      one engine view: single page and two-page spread one row at a time, centred; continuous
      scroll and book with its cover alone in one scrolling column; spreads and the cover follow
      the document's direction (a2-1a to a2-1d, a2-15, G32).
    - Tiles: each frame whose wanted set changes asks for the tiles in view at the zoom's
      quarter-octave bucket, nearest the centre first, the tiles half a window beyond and each
      page's preview thumbnail; bitmaps already decoded are not asked for again. A page shows its
      preview and other buckets' tiles scaled until its sharp tiles arrive; a page that fails shows
      a2-13's placeholder with Try again while the others work (G30). Bitmaps decode as BGRA into
      a cache of 256 MiB.
    - Zoom: the View row's zoom field (it names Fit width or Fit page while one is on, a2-13),
      zoom buttons and steps (10 % to 1,600 %), Fit width, Fit page and Actual size with ⌘2, ⌘0
      and ⌘1, Marquee zoom with a2-2's "Release to zoom to N%" label, ⌘ or Ctrl with the wheel and
      the trackpad's pinch, each around the pointer.
    - Select (the default pointer), Hand and Marquee zoom with V, H and Z; the wheel, the
      trackpad, ↑, ↓, Page Up, Page Down, Space, Home and End scroll; ← and → turn pages, and a
      paged layout turns when a scroll keeps pushing past its end.
    - Status bar: Previous and Next page; the page text is a field that a click or ⌘G (Ctrl+G)
      opens, which takes a page label or a number in any digits (a2-13); the zoom with its
      buttons. The canvas names the page in its semantics.
    - The View row, the status bar and the keys work only with a document open; the shell's
      placeholder documents keep them disabled with their reasons, so the M1 goldens hold.
    - Tests: layout, zoom and tile selection; the view state (fits, anchoring, page turns,
      layouts, the page field's input); the canvas in the shell with the fake engine, which now
      renders white bitmaps (tiles and previews asked and painted, a failed page and Try again,
      Ctrl+G with numbers and labels, the status bar's zoom, Ctrl and the wheel, Hand, Marquee
      zoom, layout and Fit page); the integration test decodes a red page's bitmap from the real
      engine as the canvas does.

  - W2, the sidebar (commit 10 of the map): committed.
    - The open result also carries the document's outline, attachments, layers and signature
      fields (ferman-core's structure scan), and the bridge mirrors them (the outline flattened in
      reading order with each item's depth, dates as the file writes them).
    - Pages (a2-3p): a thumbnail of every page with its label, the reader's page selected; a
      click or Enter goes to the page and the arrow keys move between thumbnails. The thumbnails
      come through an engine view of their own, only for those built, so a long document never
      holds every bitmap. Badges arrive with their features (f5), so the legend stays disabled.
    - Outline (a2-3o): nested bookmarks, open as the document says until the chevron or → and ←
      toggle them (mirrored in right to left); the last shown bookmark at or before the reader's
      page is tinted; a click or Enter goes to its page.
    - Attachments (a2-3b): name, size and date with the file type's icon and the design's note;
      Save attachment as… stays disabled until the save panel (B110, W3).
    - Layers (a2-3c): the document's default visibility, dimmed when hidden, and its locks, with
      the note on printing; the eye buttons came with commit 10b.
    - Signatures (a2-14, G31): the signer's name as written, "Signature checking is available in
      a future version.", the date and the page; an unsigned field says so with its page.
    - Empty tabs show one `EmptyState` (a2-3m, G29), a new component in `design/components/empty/`.
    - Each heading counts its list; the contents are keyed by the document. The placeholder
      documents keep the M1 sidebar, so the M1 goldens hold.
    - Tests: an API test on the corpus (kira-tr's three attachments and two empty signature
      fields, nda-en's signature, ocg-plan's six layers with one hidden, tez-tr's nested outline);
      widget tests of every tab with the fake engine, folding with the keys and the empty states.

  - W2, showing and hiding layers (commit 10b of the map): committed.
    - ferman-core's first render-only appendix (`Document::layer_appendix`, ADR 0009): the
      catalog again with the layers' state in `/OCProperties /D` (`/ON` and `/OFF`, `/AS`
      dropped), then a cross-reference stream naming every object, so it needs no `/Prev` after a
      classic table, a cross-reference stream or a hybrid file. The original bytes stay an exact
      prefix; nothing reaches the disk.
    - ferman-render's `reload`: PDFium loads the bytes and the appendix through one reader without
      a copy, swaps the document in under the same id and views, and gives every page a new render
      key; the old bitmaps leave the caches.
    - The API's `show_layers`, the bridge and `EngineService.showLayers`; the open result says
      whether the layers can be switched (`layers_switchable`): not for a repaired document,
      whose rebuilt table cannot place objects inside object streams, or one that needed a
      password, which PDFium would need again (Q22). There the eye buttons stay disabled (B111).
    - The eye buttons show and hide layers in every view, one call after another; a locked
      layer's button stays disabled with "Locked". The canvas and the Pages tab keep their
      bitmaps until the new ones arrive and ignore older render keys.
    - Tests: the appendix read back by ferman-core after a classic and a modern lopdf file; the
      appended reader; a PDFium test on ocg-plan (showing Tesisat and hiding Duvarlar change the
      pixels, the defaults render byte for byte as the file does; wrong lengths and a document
      without layers fail); widget tests of the buttons, the lock, a document that cannot switch
      and the views asking again.

    Still to come in M2: Settings › General's layout, zoom
    and page look for new documents, with the open commit, where they first take effect; Save
    attachment as… with the open picker, which brings file_selector and the sandbox experiment of
    Q18 (W3); the features leave the registry when documents open from the UI and the placeholder
    documents go (W3); the status bar's task progress with the first job (search); the viewer and
    sidebar goldens and EmptyState's gallery entry (W4).
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
  uses system fonts. [ADR 0013](adr/0013-fonts-and-icons.md) is Accepted. Groups 3 and 4 stayed open
  (answered 2026-10-16, below).
- [Q12](QUESTIONS.md#q12): a custom Linux title bar (client-side decorations, caption buttons at the
  end, Ctrl shortcuts, Cancel-left dialogs; [G15](DESIGN_GAPS.md#g15) Decided). Packaging stayed
  open (answered 2026-10-16, below).
- [Q14](QUESTIONS.md#q14): "Copyright The Ferman Authors". The sign-off part stayed open (answered
  2026-10-16, below).
- [Q17](QUESTIONS.md#q17) parts 1 to 3: Swatinem/rust-cache in CI, `dbus` through desktop_drop (M2),
  `libfuzzer-sys` in `fuzz/` only. Part 4 stayed open (answered 2026-10-16, below).
- Delivery: the `m1-foundations` branch and an early draft pull request, as above.
- No AI attribution in commits or in pull request titles and bodies.
- New [Q18](QUESTIONS.md#q18): the macOS App Sandbox stays on in M1, as Flutter's template sets it;
  the owner was asked before M2 (answered 2026-10-16, below).
- [Q20](QUESTIONS.md#q20), 2026-10-16, during M1: AI clients such as Claude and ChatGPT will work on
  the documents open in Ferman through a local MCP server, after M3 (ROADMAP M4 step 11). The app
  stays open and does the work locally; Settings gives a connection link for each supported client,
  or opens it already set up. [ADR 0019](adr/0019-ai-clients-through-mcp.md) is Accepted for the
  direction; its details (transport, pairing, tools, saving) were approved on 2026-10-16, below.
- 2026-10-16, after the M1 merge: the owner answered every open question as proposed:
  [Q02](QUESTIONS.md#q02), [Q06](QUESTIONS.md#q06), [Q07](QUESTIONS.md#q07), [Q08](QUESTIONS.md#q08)
  groups 3 and 4, [Q09](QUESTIONS.md#q09) to [Q13](QUESTIONS.md#q13), [Q14](QUESTIONS.md#q14) (DCO
  sign-off from M2), [Q15](QUESTIONS.md#q15) (the release files for macOS, Windows and Linux on
  GitHub Releases), [Q16](QUESTIONS.md#q16), [Q17](QUESTIONS.md#q17) part 4,
  [Q18](QUESTIONS.md#q18), [Q19](QUESTIONS.md#q19) and the details of [Q20](QUESTIONS.md#q20). The
  owner also approved every item under [Still Proposed in M1](#still-proposed-in-m1) and kept the
  United Kingdom region for the English goldens. All [DESIGN_GAPS.md](DESIGN_GAPS.md) entries are
  now Decided.
- 2026-10-16, at the end of M1: at most 15 to 20 commits per pull request from M2 on (pull request
  #2 has 92), so work is committed and pushed in checked batches rather than fix by fix; this narrows
  the "small Conventional Commits" of brief §9. Work goes on in cloud sessions, and the owner is told
  plainly when a pull request is ready to merge (with a merge commit, so the commit ids cited as
  evidence stay in `main`).

### Still Proposed in M1

Approved by the owner on 2026-10-16, when M1 was merged. They were built in M1 only as reversible
tooling, marked **Proposed**:

- [ADR 0009](adr/0009-threading-and-jobs.md) (threading and jobs) and
  [ADR 0018](adr/0018-native-file-pickers.md) (native pickers; M1 builds no picker).
- The Proposed details in ADRs 0003, 0004, 0006 and 0008.
- ROADMAP items marked Proposed: the crate-graph check and the pub deny list (both built as
  `tools/checks` checks), the web stub build, the feature registry, the pseudo-locale,
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
  `app/lib/l10n/app_tr.arb` and `app_ar.arb` (300 keys) is in
  [TRANSLATION_REVIEW.md](TRANSLATION_REVIEW.md): key, English, Turkish, Arabic and the note for
  translators, with how to send corrections. `tools/l10n` generates the table from the ARB files and
  CI keeps it current.
- [ ] R1 and R2 hardware checks: macOS traffic lights (placement in left to right and right to left,
  after resizing and in and out of full screen) and the title-bar double-click setting; Windows 11
  snap layouts on hover over maximize, its hover and press, the 8 px window corners, and the top
  resize edge, both giving way to the scrim while a dialog is open; CJK system fonts with the right regional forms (step 5); the bridge zero-copy
  timing (step 3, in profile mode: `flutter drive --profile -d <linux|windows|macos> --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart` from `app/`); the start-screen
  budget (step 9).
- [ ] arm64 and x86_64 app builds: CI builds the macOS app universal and runs its arm64 slice (the
  macos-15 runner is Apple silicon; the step "Universal app for macOS 12.0 (Q03)" checks both slices
  and the 12.0 minimum), so the x86_64 slice on an Intel Mac or under Rosetta, Windows on arm64 and
  Linux on arm64 are the owner's to run (BACKLOG B100).
- [ ] Windows 10 22H2: the app starts and the shell works (Q03 floor).
- [ ] The Linux title bar on GNOME and KDE: its look, and dragging and resizing from the window's
  edges.
- [ ] Screen readers: VoiceOver on macOS, Narrator or NVDA on Windows, Orca on Linux.
- [ ] Opening from the OS (M2, [ADR 0021](adr/0021-open-from-the-os.md)): on Windows and Linux
  (GNOME and KDE) a cold launch with a file, "Open with", and a second launch while Ferman runs,
  which brings the window forward and opens its files there; on Linux also without a session bus
  (each launch its own instance). On macOS a file dragged from Finder opens under the sandbox, and
  a1-6's overlay shows while files are dragged. CI builds the Windows and Linux runners and checks
  that each answers the open channel, but nothing there launches a second instance or drags a file.
- [ ] Goldens: every golden (script coverage, the icons, the 144 window goldens and the 206 component
  goldens) was generated in
  the development container (Ubuntu 24.04, with the same two font packages as the runner), not on the
  CI runner as ROADMAP §5 step 11 asks; the CI Linux runner proves them (the first ones passed in the
  Flutter Linux job of run [38819082054](https://github.com/KEREM-BAS/Ferman/actions/runs/38819082054)). The owner accepts this or asks for
  goldens generated by CI. The English goldens use the United Kingdom region, so the clock reads
  "14:32" as the boards draw it; the owner kept the United Kingdom on 2026-10-16
  ([G34](DESIGN_GAPS.md#g34)).

The design gaps to settle in M1 are listed in [ROADMAP.md](ROADMAP.md), section 5, under "Design
gaps to settle in M1".

## M2 plan

**Approved by the owner on 2026-10-17**, which is the go-ahead for M2. Written from
[ROADMAP.md](ROADMAP.md) section 6 after the owner's design export (`519d42a`). With the plan,
every decision the documents mark "Proposed (M2 plan)", "Proposed with the M2 plan" or "part of the M2 plan" was approved with it, except the items under [Still Proposed at the M2 review](#still-proposed-at-the-m2-review), [Q21](QUESTIONS.md#q21) and strace, which still wait for the owner. The individual mentions are reworded in M2's closing documentation commit. The owner chose
to continue M2 in a Claude Code session on their own computer.

### Delivery

- **Phase 0, pull request #3** from `m2-open-and-view` to `main`: CI on `main` green again after the
  export (the moved design lines, 253 boards, the `design/` check on pushes), Turkish and Arabic
  variants of the design references and the `@m1`, `@m2` and `@langs` sets, the app matched to the
  M1 build boards, the DCO check, and the documents brought in line with the export, the owner's
  answers and this plan. About 8 commits. The owner merges it with a merge commit.
- **M2, pull request #4**, from the same branch after pull request #3 is merged (`main` merged in with
  a sign-off): 18 commits planned, 2 kept for CI fixes, at most 20.
- Every commit is authored as the owner, signed off ([Q14](QUESTIONS.md#q14), the `dco_signoff`
  check) and carries no AI attribution. Each wave ends with an adversarial review and one checked,
  batched push.
- At most three agents work in `app/` at once. The lead alone writes the shared files: `pubspec.yaml`,
  the ARB files, the router, the components barrel, `[workspace.dependencies]`, the workflows and
  `docs/`.

### Architecture

Written into [ARCHITECTURE.md](ARCHITECTURE.md) sections 3 and 4 with the API commit.

- **ferman-core:** `source` (the file read into an owned `Arc<[u8]>` with its SHA-256, never
  memory-mapped until [Q21](QUESTIONS.md#q21) is answered), `limits`, `filters`, `security`
  (passwords zeroized), `parse` (lopdf under `catch_unwind` on a thread with a 64 MB stack),
  `repair`, `structure` (labels, outline, attachments, layers, AcroForm and XFA, signatures, scripts,
  `/Direction`, fonts), `text_string`, `content`, `snapshot` and a render-only `appendix` for layer
  visibility, never written to disk.
- **ferman-render:** requests over crossbeam channels, a priority queue with wanted sets and
  generations, 512 × 512 BGRA tiles in quarter-octave zoom buckets, LRU tile and page caches,
  thumbnails, documents loaded from the snapshot bytes without a copy.
- **ferman-fonts:** encodings, the Adobe Glyph List, CMap and ToUnicode, Type1 built-in encodings,
  the reverse cmap through skrifa.
- **ferman-text:** glyph runs, Unicode order, words and lines with bidi, a search index, Turkish and
  accent folding with icu_casemap, collation with icu_collator.
- **ferman-api:** one actor per document, views with a tile stream, a rayon job pool and events.
  Error kinds NotFound, PermissionDenied, PasswordRequired, WrongPassword, Restricted, Damaged,
  Unsupported, ResourceLimit and Cancelled, with message keys a test checks against the ARB files.
  Calls: `open`, `unlock`, `unlock_owner`, `close`, `page_info`, `document_info`, `outline`,
  `attachments`, `save_attachment`, `layers`, `set_layer_visible`, `document_events`, `open_view`,
  `request_tiles`, `request_thumbnails`, `close_view`, `search`, `cancel_job`, `sort_keys`.
- **ferman-cli:** `open`, `pages`, `render`, `text`, `search`, with `--timings --json`.
- **The crate-graph check** gets single-door rules: lopdf, skrifa and read-fonts, icu and rayon each
  enter through one crate.
- **Dart:** `app/lib/engine/` (document, view with a `TileTransport` and `ImageDescriptor.raw` for
  BGRA, search and collation services, each with an FRB implementation, a fake and a web stub);
  `app/lib/platform/` (pickers through file_selector, drag and drop through desktop_drop, open
  requests, file access with macOS bookmarks and the replacement directory, the default app,
  "Show in"); the features `documents/` (replacing the placeholder `ShellDocuments`), `viewer/`, the
  sidebar tabs and `recents/`; a new EmptyState component.

### Waves

| Wave | Contents | ROADMAP step | Boards |
|---|---|---|---|
| W0 | The feature registry (`Feature` enum and a BACKLOG-parity check), approved in M1 | — | — |
| W1 | `fuzz/` and `tools/corpus` workspaces; the corpus generators with the PDFium oracle test ([ADR 0020](adr/0020-test-corpus.md)); the render thread with tiles, queue and caches; determinism and stress tests; the `first_page` bench; the PDFium-missing banner ([G101](DESIGN_GAPS.md#g101)) | 1 | — |
| W1 | The open path, limits, security, repair and structure; the two-parser check ([G102](DESIGN_GAPS.md#g102)); 9 fuzz targets | 2 | a1-8, a1-8b, a1-9, a1-9b, a1-9c, a1-9d, a1-9f, a11-7c, a2-10a |
| W1, lead | **The Dco trial first** (the critical path): `full_dep`, ffigen, the `ApiVersion` rename, measured; if Dco fails or misses the target, stop for the owner ([Q19](QUESTIONS.md#q19) option b) | 3 | — |
| W2 | The API, actors, views, jobs and bridge; the engine services and fakes; the viewer layouts including right to left, zoom, marquee, pinch and the hand tool; the status-bar page field with ⌘G; the M2 controls of Settings › General | 3 | a2-1a to a2-1d, a2-2, a2-13, a2-15, a11-1 |
| W2 | The sidebar: EmptyState; Pages with the badge legend; Outline; Attachments with Save as (the replacement-directory atomic write, the experiment [Q18](QUESTIONS.md#q18) asks for); Layers; Signatures in the neutral state | 4 | a2-3a, a2-3p, a2-3o, a2-3b, a2-3c, a2-3x, a2-3m, a2-14, f5 |
| W3 | Fonts and extraction (4 more fuzz targets, 13 in all); the index and the search job; the find bar, Look in, Show all and the live count; folding tests; search benches | 5 | a2-4a to a2-4d, a2-3e, a2-3m |
| W3 | The open picker, drag and drop, open events from the OS ([ADR 0021](adr/0021-open-from-the-os.md)), arguments and cold start; recent files (grid, list, pins, search, collation, missing file, bookmarks, thumbnails, no preview when encrypted); reopen; the default-app prompt; progressive open; 20 tabs with overflow and per-document state; properties; the restricted unlock; the scripts banner ([G100](DESIGN_GAPS.md#g100)) | 6 | a1-3, a1-4, a1-4b, a1-4c, a1-4-m2, a1-6, a1-7, a1-9e, a1-10, a1-13, a2-7, a2-10b, a12-0 (as the `RegionFormat` test oracle) |
| W4 | M2 goldens (light and dark × en, tr and ar, including a dark View window); `@m2` compare pairs; the canvas and recent-files comparisons unmasked (B098); the integration group "M2 budgets"; a no-network strace job; a bench job; closing M2 (E1 to E8) | close | — |

Critical paths: the Dco trial, then the tile API, the canvas and the first-page bench; the corpus,
then step 2's acceptance, extraction and search; the native open-from-the-OS code starts in W1.

### Commit map

1. the feature registry; 2. the fuzz and corpus workspaces; 3. the corpus; 4. render; 5. core;
6. the Dco codec; 7. the API; 8. the app's engine services; 9. the viewer; 10. the sidebar
(10b: showing and hiding layers, split off on 2026-10-30); 11. text; 12. search; 13. open; 14. start and recent files; 15. documents and properties;
16. goldens; 17. CI, integration tests and budgets; 18. closing documents. Two more are kept for CI
fixes.

### Decisions in this plan

Each is Proposed with the plan and recorded where the last column says.

| # | Question | Decision | Recorded in |
|---|---|---|---|
| 1 | Saving before the writer exists | "Save repaired copy…" (a1-9) and a read-only file's "Save a copy…" (a1-9d) stay visible and disabled until M3, as the unfinished-features rule already requires | BACKLOG B103; ARCHITECTURE §5.2; [G28](DESIGN_GAPS.md#g28) |
| 2 | Tile size and pixel format | 512 × 512 BGRA; ADR 0009's 256 px RGBA applies only to the texture fallback; if a platform rejects BGRA, `FPDF_REVERSE_BYTE_ORDER` | ADR 0009 |
| 3 | Thumbnails and indexing | Thumbnails come from PDFium without waiting for indexing; above the progressive-open threshold (more than 1,000 pages, or an indexing estimate over 2 s) a1-7's rules apply | [G104](DESIGN_GAPS.md#g104) |
| 4 | The scripts notice of [Q13](QUESTIONS.md#q13) has no board | An info banner reusing a8-4's copy, and a row in Properties | [G100](DESIGN_GAPS.md#g100) |
| 5 | DCO sign-off | Required on every commit from M2, checked on pull requests | ROADMAP E7; CONTRIBUTING |
| 6 | [Q18](QUESTIONS.md#q18) needs a save, and the writer is M3 | M2 builds bookmarks (recent files) and the replacement-directory write (attachment Save as); CI proves them inside the container, the owner on R1; the decision is taken at the M2 review | ADR 0008 |
| 7 | An unsupported file | A file that arrives gets a1-9c's error tab; while dragging, the note reads "Can't open yet" | ROADMAP §6 step 6 |
| 8 | Drop targets | The start screen and the document window or tab strip; a1-6's Combine target and the page-grid insert stay disabled until M4 | [G105](DESIGN_GAPS.md#g105); BACKLOG |
| 9 | The default app | Works on macOS; on Windows the Settings link only once registered (the M5 installer), on Linux disabled until packaging | [G103](DESIGN_GAPS.md#g103); BACKLOG |
| 10 | Where recent files live | A Dart `RecentFilesStore`; the engine supplies collation and thumbnails | [ADR 0021](adr/0021-open-from-the-os.md) |
| 11 | Collation | icu_collator in ferman-text through `sort_keys` (also unblocks B092) | DEPENDENCIES |
| 12 | The feature registry | The first M2 commit | ROADMAP §6 |
| 13 | Corpus tooling | A Rust `tools/corpus` workspace, checked by PDFium; no qpdf or pyHanko in M2 | [ADR 0020](adr/0020-test-corpus.md) |
| 14 | Stale Proposed and open mentions | Swept in phase 0 | — |
| 15 | Gaps the new boards settle | Resolved or partly resolved in phase 0 | DESIGN_GAPS |
| 16 | The approved 256 MB snapshot needs an `unsafe` mapping | An owned buffer until the owner answers | [Q21](QUESTIONS.md#q21); BACKLOG |
| 17 | a1-9f's "one tab closed" on out of memory | Pre-checks with `try_reserve` and the limits; out of memory inside PDFium cannot be caught | ADR 0010 |
| 18 | a1-9's "shown as IBM Plex Serif" with PDFium's system fonts | Look for a safe route to our font paths in pdfium-render, else record a gap and decide in M3 | risk |
| 19 | `image_025` in M2 | Not needed; raw bitmap bytes are enough | ARCHITECTURE §2.3 |
| 20 | Linux forwarding | GApplication D-Bus uniqueness instead of a Unix socket | [ADR 0021](adr/0021-open-from-the-os.md) |
| 21 | a11-1-m1 draws M2 controls enabled | Disabled until they work, as the unfinished-features rule already requires (M1 does so); M2 step 3 enables them | [G108](DESIGN_GAPS.md#g108) |
| 22 | PDFium cannot toggle a layer | The render-only appendix in ferman-core | ADR 0009 |
| 23 | "Show in Finder" on Windows and Linux | "Show in Explorer", the design's own Windows label (FmSettings), and "Show in folder" on Linux | [G107](DESIGN_GAPS.md#g107) |
| 24 | Text selection with the Select tool | Select is the default pointer in M2; selection and copy arrive with M3's hit testing | BACKLOG |

### New dependencies

Only one needs the owner first: strace (LGPL-2.1-or-later, a CI tool for the no-network check,
never shipped), asked before it is added, as rust-cache was in [Q17](QUESTIONS.md#q17). Already
planned in [DEPENDENCIES.md](DEPENDENCIES.md): lopdf, skrifa and
read-fonts, sha2, rayon, crossbeam-channel, lru, the unicode crates, icu_casemap and icu_collator,
criterion, tempfile, cargo-fuzz and libfuzzer-sys (NCSA, approved in [Q17](QUESTIONS.md#q17)),
file_selector, and desktop_drop (with dbus under MPL-2.0, approved; the pub check skips `dbus`). New,
all MIT or Apache-2.0 or BSD-3-Clause: zeroize; flate2 and weezl as direct dependencies; png for the
CLI; arbitrary for the fuzz targets; ffigen as a Dart dev dependency, checked to bring no `http`;
Noto Sans CJK (OFL-1.1, test data only, pinned hash, never shipped) and the Adobe Glyph List
(BSD-3-Clause); `libclang-dev` as a CI package, never shipped.

### Still Proposed at the M2 review

The R1 and R2 budgets; the fuzz durations (60 s per target on pull requests, 1 h per target nightly);
the cache caps (25 % of RAM for tiles, 8 loaded pages per document); the progressive-open threshold
([G104](DESIGN_GAPS.md#g104)); the M2 performance budgets; the document actor waiting for M3's
first change (a decision of the API commit, under [Decisions taken during M2](#decisions-taken-during-m2)).

### Pending owner checks (M2)

Each gets one command that prints labelled JSON (`flutter drive --profile … --dart-define=FERMAN_CORPUS=…`
from `app/`, or `ferman open --timings --json`) and links to the CI artefacts.

- [ ] R1 and R2 budgets: first page under 1 s, 60 fps at p99 while scrolling, 12 thumbnails in
  300 ms, the imar plan's first page under 1.5 s and fully indexed under 25 s, memory under 400 MB,
  and the Dco transfer under 0.2 ms per MiB.
- [ ] The macOS sandbox with files granted through the panel: bookmarks after a restart and the
  `replaceItemAt` save ([Q18](QUESTIONS.md#q18)).
- [ ] Opening from the OS: double-click, "Open with", the Dock and the taskbar, a second launch on all
  three systems, cold start; Linux D-Bus uniqueness on GNOME and KDE.
- [ ] The default-app dialogs; the native pickers; drag and drop from Finder, File Explorer and
  Nautilus.
- [ ] Screen readers, fractional display scaling, Windows 10 and arm64.
- [ ] Native-speaker review of the new Turkish and Arabic strings.
- [ ] A native reader looks over the invented text of `report-ar` (Arabic) and `letter-ja-vertical`
  and `quote-ja-scan` (Japanese) in `tools/corpus`; a fix changes only the generated files and their
  README hashes.

### Risks

- **The Dco codec fails, or ffigen pulls in `http`.** The trial runs first; the `TileTransport` seam
  and the copying codec remain as a fallback.
- **Text extraction is deeper than planned.** Generator-controlled inputs and the PDFium cross-check.
- **lopdf's stack use and panics.** The big-stack thread, `catch_unwind` and fuzzing.
- **Native open-from-the-OS code on three systems.** Starts in W1.
- **Out of memory or a crash inside PDFium takes the app down.** Pre-checks; a helper process is
  assessed only if a budget misses.
- **CI time.** Separate jobs, a nightly fuzz matrix, design references for `@m1` and `@m2` only.
- **Large commits under the 20-commit limit.** A review per wave and the commit map in the pull
  request body.

### Decisions taken during M2

Taken by the lead within the approved plan, reversible, and listed in the M2 summary:

- **A feature ships by leaving the registry** (W0). The `Feature` enum holds only the features that
  are visible but do not work yet; it has no `available` flag. Deleting a shipped feature's value
  makes every control that still names it a compile error, so none is left disabled without its
  reason, or enabled without its handler, by mistake (the W0 review found both risks with a flag).
  ROADMAP's "an available one still has one" is checked as a value whose BACKLOG row is under Done.
  A feature whose entry points ship at different times is split into a value and a row per part.
- **The start screen's drop zone takes one reason** (W0): `DropZone` has one disabled reason for
  the zone and both buttons, so its drop target (B010) and New blank PDF (B019) share
  `Feature.openFiles` until opening ships and the zone gets a reason per part (M2 step 6).
- **Two component files keep the future-version reason themselves** (W0), on the check's reviewed
  list with their reasons: StickyNote's More while a screen passes no `onMore`, and SignaturePad's
  Choose image until M4's signature dialog (B024).
- **The title bar's Settings button always has its callback** (W0): Settings shipped in M1, so the
  test-only state "disabled until it has somewhere to go" is gone with its test.
- **M2 continues in a second pull request** (W1): pull request #4 was merged with W0 and the Dco
  trial, so the rest of M2 goes on `m2-open-and-view`, opened again from `main`, in a new pull
  request. The limit of 20 commits applies to each pull request; the commit map's numbers stay.
- **The stream filters are the first parser** (W1, commit 2 instead of 5): cargo-fuzz needs a
  target, and `fuzz/` is created with the first parser, so ferman-core's `filters` (ASCIIHex,
  ASCII85, LZW, Flate and RunLength, with the PNG and TIFF predictors, on flate2 and weezl) and the
  `Limits` struct they need come with the fuzz workspace. They depend on nothing else in the open
  path. Data a filter cannot decode is an error with its offset; a stream that ends early (no
  end-of-data marker, a truncated last group, run or row, a Flate stream without its end block or
  with a wrong Adler-32 checksum) gives the data it holds, as PDFium decodes it.
- **A generated PDF's expected text shares its README row** (W1): `tests/corpus/README.md` lists
  `<name>.pdf`, and `tools/corpus check` accepts `<name>.expected.txt` beside it without a row of
  its own; regenerating proves the text.
- **The corpus comes in two commits** (W1, the owner, 2026-10-19): first the tooling, the Latin and
  Turkish files, the encrypted and damaged files and the oracle; then the Arabic report, the Japanese
  letter and the two scans. The second part takes one of the two commits kept for CI fixes.
- **The corpus tool has its own security handler** (W1): lopdf 0.45 encrypts with random
  initialisation vectors and salts, so its files would change on every run. `tools/corpus/src/crypt.rs`
  writes RC4 40 and 128, AES-128 and AES-256 with vectors seeded from the generator's name (ADR 0020,
  "Implementation").
- **EB Garamond for Madde 6** (W1): kira-tr's Madde 6 needs a font Ferman does not bundle, so the
  missing-glyph path of M3 is real ([G113](DESIGN_GAPS.md#g113)). It is OFL-1.1 test data like the
  Noto Sans CJK of the plan: fetched with a pinned SHA-256 by `tools/corpus/fetch-fonts.sh`, never
  committed or shipped.
- **Noto Serif JP for the Japanese files** (W1): the M2 plan named Noto Sans CJK as the Japanese
  test font; `a3-15` sets the letter in Noto Serif JP, of the same Noto CJK family under the same
  terms (OFL-1.1, test data only, pinned, never committed or shipped). google/fonts has it only as a
  variable font whose default instance is ExtraLight (200), so the generators use it at `wght` 400
  and 600. subsetter's `variable-fonts` feature instances the subsets; it brings write-fonts, kurbo,
  polycool, euclid, arrayvec and second versions of skrifa, read-fonts and font-types, all MIT OR
  Apache-2.0 and in `tools/corpus` only.
- **IBM Plex Sans Arabic for the Arabic report** (W1): `a2-15` names Noto Naskh Arabic first and
  IBM Plex Sans Arabic second. The report uses the bundled second font, so it needs no download.
- **The oracle compares right-to-left and vertical text by characters** (W1): PDFium recovers the
  logical order of Arabic from the visual one by a heuristic (it reverses the text of a ligature
  glyph and moves neutral characters at the edge of a number), and it puts vertical columns in an
  order of its own. Those generators say `Expect::OpensUnordered`, and each page is compared by its
  characters. Ferman's own extraction is held to the logical order (ROADMAP, M2 step 5).
- **One render thread holds PDFium at a time** (W1): pdfium-render's `thread_safe` lock covers only
  part of its bindings: in 0.9.4, 192 of its 481 functions run without it, `FPDF_GetPageSizeByIndexF`
  among them. The first parallel run of the render tests showed it: with several render threads in
  one test process, valid corpus files failed to open. ferman-render now refuses a second render
  thread while the first holds PDFium (`PdfiumInUse`). The app has one engine, so one render thread;
  the test binaries take turns through a lock, and ferman-api's PDFium test uses the global engine
  only.
- **Tiles are rendered with a margin of 32 pixels** (W1): PDFium draws a glyph that crosses the
  edge of its bitmap differently. On a test page of text from 3 to 35 points at device pixel ratios
  1, 2 and 4, tiles without a margin differed from one render of the whole page in 572 to 1,539
  pixels, by up to 137 levels, all at tile edges; with a 16-pixel margin 112 such pixels remained,
  with 32 none. What is left is at most two levels of antialiasing on paths. A full tile costs about
  27 % more raster area. The pixel-diff test of M3 compares renders made the same way, tile for
  tile (ARCHITECTURE §13.4).
- **The render API is on `RenderThread`** (W1): ARCHITECTURE planned `Renderer` and `ViewSession`;
  the M1 handle carries documents and views instead, so ferman-api keeps one handle. A wanted set is
  one list of tiles and thumbnails (`Item`), so the thumbnail strip is a view like the canvas. A
  tile is addressed by column and row on the grid; buckets run from 6.25 % to 12,800 % and device
  pixel ratios from 0.5 to 4. Thumbnails are capped by bytes (64 MiB, Proposed) instead of by count.
- **No progressive rendering** (W1): pdfium-render 0.9.4 offers PDFium's pause callback only
  through its raw, unsafe bindings, so a tile always finishes once started. The thread takes every
  waiting message before each tile and again after it, so a replaced set loses at most the tile in
  progress.
- **lru 0.19.0 with default features off** (W1): the release current at M2, instead of the planned
  0.18.5, on the standard `HashMap`, so it brings no crates. criterion 0.8.2 is built without its
  default features (no plotters, no rayon).
- **The app's test hosts get a working fake engine** (W1): seven hosts pumped the whole app without
  an engine, which reads as "library missing" and would now show G101's banner. They override the
  engine with `FakeEngineService` (PDFium loaded), so the M1 goldens stay as they are; the G101
  tests pass a broken engine to `pumpFermanApp`. The banner reads an error in every state, because
  Riverpod retries a failed status and keeps the error while it does.
- **ferman-core reads the cross-reference data itself and hands lopdf a clean table** (W1): lopdf
  0.45 accepts a table whose offsets are wrong and loads no objects (kira-tr-damaged gave 0 objects
  and 0 pages), and opens a password-protected file without its password as a document of one
  object. So ferman-core reads and checks the table, rebuilds it from a scan when it is broken, and
  gives lopdf a repaired or encrypted file as a copy with one clean table appended
  (ARCHITECTURE §5.1). lopdf stays the parser of every object and the model (ADR 0004: "what lopdf
  lacks, ferman-core adds"). A healthy unencrypted file is parsed in place, without the copy.
- **ferman-core decrypts with its own security handler** (W1): lopdf copies the password into
  strings it frees without wiping them, so the password never reaches it: the copy for lopdf has no
  `/Encrypt`, and ferman-core decrypts the parsed objects and the object streams. ROADMAP's "wiped
  after key derivation" then holds for Ferman's copies; PDFium's is [Q22](QUESTIONS.md#q22).
- **Objects lopdf cannot read make the document repaired** (W1): an object the table names but the
  model lacks (lopdf skips what it cannot read, including nesting past its own bound of 100) is
  reported as `ObjectsUnreadable`, so the document opens read-only like a repaired one instead of
  silently missing content.
- **The model's pages are lopdf's** (W1): the page tree requires `/Type /Page`, as lopdf's does, so
  later page operations and the two-parser check see the same pages; `disagree-pages` disagrees as
  its README row says. Page sizes follow PDFium's rule, so the check compares like with like.
- **Fuzz targets reach ferman-core's internals through a hidden module** (W1): `fuzzing`, behind a
  feature only `fuzz/` enables, so the parsers stay crate-private.
- **lopdf enters through ferman-core only** (W1): the `crate_graph` check's single doors gained
  lopdf, the first of the M2 plan's single-door rules.
- **A large generated file commits neither of its files** (W1): long-500's expected text alone is
  1.7 MB, so a generator whose PDF is over 1 MB keeps both files out of git, listed in
  `tests/corpus/generated/.gitignore`, which `check` requires. `.gitattributes` keeps the generated
  files from line-ending conversion, so `check` passes on a Windows checkout.
- **No `unlock` call** (W2): an encrypted file opened without its password fails with
  `PasswordRequired`, and the UI opens it again with the password, so the engine never holds a
  half-open document. ARCHITECTURE §3 left the API's shapes to M2.
- **The open result carries the pages** (W2): a document does not change in M2, so `open` returns
  every page's size and label and the direction, and `page_info` waits for M3's render keys.
- **Calls arrive with their callers** (W2): the API commit builds what the viewer uses; each later
  call comes in the commit of the screen that calls it, and the `frb` mirrors with the app's
  engine services, so no call exists without a caller and a test.
- **The document actor waits for the first change** (W2, **Proposed**): ROADMAP §6 lists document
  actors for M2, but a document does not change before M3's edit transactions, so an actor would
  serialise nothing. M2 opens on a thread of its own and keeps the document immutable; the actor
  arrives with M3's first transaction. The owner decides at the M2 review.
- **ferman-core parses before PDFium loads** (W2): the open is sequential, which costs the parse
  time (2.8 ms for `long-500` on the owner's Mac) before the first page; the two run side by side
  only if the first-page bench misses its budget.
- **A file only PDFium can read does not open yet** (W2): no corpus file has the case, so the
  view-only state of ARCHITECTURE §5.2 for it waits ([BACKLOG](BACKLOG.md) B109).
- **One `EngineService` grows** (W2): the plan named separate document, view, search and collation
  services; the app keeps its one engine interface with its bridge implementation, the fake and
  the unavailable service, and adds each call to it, so one fake serves every widget test.
- **No `TileTransport` seam** (W2): it was the plan's way to swap the Dco codec for a pointer view or
  textures if Dco missed its target; Dco met it on the owner's Mac, so pixels arrive as a
  `Uint8List`, and a seam waits until R1 or R2 shows it is needed. Turning them into images is the
  viewer's work.
- **A view's stream names the view first** (W2): a flutter_rust_bridge stream function returns
  only the stream, so the view's handle is its first event; nothing renders before the first
  request, which needs the handle.
- **Handles are `int` in Dart** (W2): the bridge gives `u64` as `BigInt`; ids and generations are
  counters, and a render key is wrapped to 64 bits, never clamped, so keys stay distinct.
- **100 % is 96 dpi** (W2): the design draws an A4 page 794 px wide at 100 % (`DocKira`), CSS's
  96 pixels per inch, so the canvas shows 4/3 logical pixels per point at 100 % and picks the
  tile bucket for that scale. Fit width and Fit page leave the layout's padding around the pages.
- **Single page and two-page spread show one row at a time** (W2): a2-1a and a2-1c draw them
  without a next row, a2-1d draws book mode scrolling, so single and two-page are paged and
  continuous and book scroll; a wheel that keeps pushing past a paged row's end turns the page.
- **A page label wins in the page field** (W2): a thesis whose ninth page is labelled "1" opens
  there when "1" is typed, as the labels are what the pages print; a number that is no label goes
  to that page.
- **The viewer arrives before the open** (W2): documents open from the UI in W3, so the viewer
  shows the document `openDocumentProvider` holds, and the View row, the status bar and their
  keys work only while one is open. The shell's placeholder documents keep the M1 controls,
  disabled with their reasons, and the features stay in the registry until W3 replaces the
  placeholders; Settings › General's defaults for new documents come with the open, where they
  first take effect.
- **No scrollbars on the canvas** (W2): no board draws one; the wheel, the trackpad, the keys, the
  Hand tool and the page field move through the document.
- **Touch pinch waits for the touch platforms** (W2): the desktop canvas zooms with ⌘ or Ctrl and
  the wheel and with the trackpad's pinch; a touchscreen's two fingers come with the tablet
  phase.
- **The sidebar in three parts** (W2, the owner, 2026-10-30): the lists come in commit 10; showing
  and hiding layers, which needs ferman-core's render-only appendix and its own pixel test, is
  commit 10b; Save attachment as… comes with W3's open picker, so file_selector and Q18's
  sandbox experiment arrive once.
- **The open result carries the sidebar's lists** (W2): as with the pages, a document does not
  change in M2, so `open` returns the outline, attachments, layers and signature fields the
  structure scan found, and no call fetches them later. Commit 10b and Save attachment as… need
  the document again (its optional content, an embedded file's bytes) and keep it then.
- **Layers switch through a render-only appendix, every page re-rendered** (W2, commit 10b): the
  appendix ends in a full cross-reference stream rather than a section with `/Prev`, so the same
  bytes work after every kind of table. Every page gets a new render key, not only those that use
  the layer as ADR 0009 says: finding them needs the content interpreter (M3). A repaired
  document, or one opened with its password, keeps its layers as they are until the writer (M3)
  or Q22's answer; ferman-core does not keep the password to reload.
- **The Pages tab has its own engine view** (W2): it asks only for the thumbnails it has built,
  at the canvas's preview size, so the render thread's thumbnail cache serves both.
- **The sidebar's state while hidden waits for W3** (W2): hiding the sidebar still drops it, with
  the outline's folds and the thumbnails' scroll; W3's per-document state of tabs keeps them
  (B091).

## ADR status

Decisions taken from the brief are "Accepted (brief)". New ones stay "Proposed" until the owner
approves them ([ADR 0001](adr/0001-record-architecture-decisions.md)). Each milestone review lists
the ADRs that changed status here.

| ADR | Status | Waiting for |
|---|---|---|
| [0007 harfrust instead of rustybuzz](adr/0007-harfrust-instead-of-rustybuzz.md) | Accepted (owner, [Q04](QUESTIONS.md#q04), 2026-10-15) | — |
| [0009 threading and jobs](adr/0009-threading-and-jobs.md) | Accepted (owner, 2026-10-16; the tile-transfer order through [Q19](QUESTIONS.md#q19)); the tile wording and the render-only appendix approved with the M2 plan on 2026-10-17 | — |
| [0013 fonts and icons](adr/0013-fonts-and-icons.md) | Accepted: brief parts, plus Plex Sans Hebrew and Devanagari (owner, [Q08](QUESTIONS.md#q08), 2026-10-15) | — |
| [0018 native file pickers](adr/0018-native-file-pickers.md) | Accepted (owner, [Q07](QUESTIONS.md#q07), 2026-10-16) | — |
| [0019 AI clients through MCP](adr/0019-ai-clients-through-mcp.md) | Accepted (owner, [Q20](QUESTIONS.md#q20), 2026-10-16): the direction, then the details | — |
| [0020 test corpus](adr/0020-test-corpus.md) | Accepted (owner, with the [M2 plan](#m2-plan), 2026-10-17) | — |
| [0021 opening files from the OS](adr/0021-open-from-the-os.md) | Accepted (owner, with the [M2 plan](#m2-plan), 2026-10-17) | — |
| [0010 error handling](adr/0010-error-handling-no-panics.md) | Accepted (brief); the crash-log placeholders approved by the owner on 2026-10-17, and the out-of-memory note with the M2 plan the same day | — |
| [0003](adr/0003-crate-layout-and-api-boundary.md), [0004](adr/0004-lopdf-model-pdfium-renderer.md), [0008](adr/0008-file-safety-and-saving.md) | Accepted (brief); the Proposed detail of each approved by the owner on 2026-10-16; ADR 0008's new details (the attachment write path, files over 256 MB) approved with the M2 plan on 2026-10-17; memory-mapping waits for [Q21](QUESTIONS.md#q21) | Q21, for memory-mapping |
| [0006 font pipeline](adr/0006-font-pipeline-and-missing-glyphs.md) | Accepted (brief); the `fsType` detail approved by the owner on 2026-10-16 ([Q09](QUESTIONS.md#q09)) | — |
| [0016 licence policy](adr/0016-dependency-licence-policy.md) | Accepted (brief); three licence exceptions approved on 2026-10-15; the reading of "GPL-compatible" confirmed on 2026-10-16 ([Q17](QUESTIONS.md#q17) part 4) | — |
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
| 2026-10-16 | M1 | `debug_bytes`: a 1 MiB `Vec<u8>` from Rust to Dart, round trip timed in Dart | under 0.2 ms on R1 and R2, profile or release build | development container, Linux x64, Xvfb, profile build of a fresh clone at `f41d789` (not R1 or R2) | 20 warm calls after one warm-up: minimum 4,570 µs, median 8,726 µs; **does not meet the target** | the fresh-clone run of CLAUDE.md's commands, `flutter drive --profile -d linux …` |
| 2026-10-19 | M2 | `debug_bytes`, SSE codec (before the change) | under 0.2 ms on R1 and R2, profile or release build | the owner's MacBook Pro, Apple M5 Pro, 48 GB, macOS 26.5, profile build at `9644ea9` (not R1 or R2) | 20 warm calls: minimum 665 µs, median 1,053 µs; **does not meet the target** | `flutter drive --profile -d macos …` |
| 2026-10-19 | M2 | `debug_bytes`, **Dco codec** (`full_dep: true`) | under 0.2 ms on R1 and R2, profile or release build | the same Mac, profile build (not R1 or R2) | 20 warm calls: minimum 26 µs, median 73 µs; **meets the target on this Mac** | the same command, with the Dco bindings |
| 2026-10-19 | M2 | `debug_bytes`, Dco codec | (debug builds do not count) | the same Mac, debug build | 20 warm calls: minimum 5,932 µs, median 6,148 µs | `flutter test integration_test -d macos` |
| 2026-10-20 | M2 | Three views requesting tiles at once, with documents opening and closing beside them (ROADMAP §6 step 1) | no crash and no deadlock in 10 minutes | the owner's MacBook Pro, Apple M5 Pro (not R1 or R2), release build | passed in 600 s; the test process's peak memory was 137 MB after 30 s, 160 MB after 120 s and 161 MB after 300 s, so it does not grow | `FERMAN_RENDER_STRESS_SECONDS=600 cargo test --release -p ferman-render --test pdfium -- --ignored three_views` |
| 2026-10-20 | M2 | `first_page/open_and_first_tile`: PDFium loads `long-500` with all 500 page sizes, then page 1's first tile at 100 % and a ratio of 2 | the engine's part of "first page under 1 s" (ARCHITECTURE §14) | the same Mac, `cargo bench` (not R1 or R2) | 2.71 ms (30 samples, 2.69–2.73 ms); loading with the page sizes alone 1.87 ms; a tile of a page already loaded 0.54 ms | `cargo bench -p ferman-render --bench first_page` |
| 2026-10-21 | M2 | `ferman_core::open` on the corpus: the model and the structure scan, best of 7 | the imar plan "fully indexed under 25 s" includes this part (ARCHITECTURE §14) | the owner's Mac, release build (not R1 or R2) | `imar-2400` (4.0 MB, 2,400 pages) 15.5 ms; `long-500` 2.8 ms; `tez-tr` (object streams) 1.4 ms; `kira-tr-damaged` with repair 0.3 ms; `payslip-aes256` with its password 2.8 ms, most of it the revision 6 hash | a temporary timing test over `open`, not committed |

Both results are far over the target, because the transfer copies. With codegen 2.13's default
`full_dep: false` the generated glue uses the SSE codec: its Rust encoder writes the `Vec<u8>` one
byte at a time into a serialisation buffer, and Dart copies it out with `getUint8List`. `full_dep:
true` (the Dco codec) needs ffigen as a dev dependency and libclang for codegen; tried in a scratch
copy, it generated bindings whose Dart did not compile (ffigen's C struct `ApiVersion` clashes with
the Dart mirror). The options (the Dco codec, an opaque pixel buffer read through a pointer view,
the texture registry) and a proposal are in [ADR
0009](adr/0009-threading-and-jobs.md#tile-transfer-m1-measurements-and-options-proposed); the owner
chose in [Q19](QUESTIONS.md#q19) on 2026-10-16: (a) first, measured on R1 and R2 before M2 step 3.
On 2026-10-19 the Dco codec went into use: the name clash came from the codegen's cbindgen pass
reading the facade, now hidden from it, and a `Vec<u8>` crosses as external typed data, about 15
to 25 times faster than SSE on the owner's Mac and under the target there. The ROADMAP zero-copy box
stays open until R1 and R2 are measured.

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
| 2026-10-16 | M1 | Phases J2, G10, H6 and K, and the owner's MCP decision. J2: the localization acceptance tests (casing, region formats, right to left with the canvas never mirrored, the Proposed 140 % pseudo-locale on every M1 screen); they found the first-run tiles cutting off their labels and English strings reordering in the mirrored Persian and Hebrew UI, now kept in order by the generated `IsolatedFallbackLocalizations` (`tools/l10n`, G93). G10: the component gallery at `/debug/gallery`, which found the TaskProgress inline overflow (fixed). The owner asked for AI clients through a local MCP server in the running app after M3: ADR 0019 (direction Accepted, details Proposed), Q20, ROADMAP M4 step 11, G94. H6: narrow windows (tool-row overflow, icon-only mode tabs, panels stepping aside, a 1024 × 640 minimum, the width Proposed), with an adversarial review's 8 findings fixed (G95, B093 to B096). K2: `node tools/design-refs compare` and its report in the pull request (B097, B098). K1: the whole-window goldens (138, then 144 with the Privacy pane after a review of the matrix) with simulated traffic lights and the test-only system fallback fonts (G96), the English goldens on the United Kingdom region (G34), the variant matrix and expected differences (G97), CI installing `fonts-dejavu-core` and `fonts-noto-cjk` with a version check, and a12-1tr and a12-1ar added to the comparison (18 pairs, 17 boards in `@m1`). CI runs on `78992e3`, `db7e6da`, `1973bc0`, `2696728`, `c5fda08` and `b358281` were green on the three systems. `design/` unchanged. | `78992e3` to the head of this push |
| 2026-10-16 | M1 | Phase L, closing M1, first part. An audit of the 53 unticked boxes of steps 1 to 10 in ROADMAP §5 (an agent per group of steps, each checked by a second agent) found 23 met, 10 met but waiting on the owner (hardware, native review, or the approval of a Proposed item), 18 partly met and 2 not met; the other 10 unticked M1 boxes (step 11, the acceptance criteria and the exit checks) are settled at the close of M1. A workflow closed the gaps, each part reviewed and its findings fixed: CI proves the universal macOS app for macOS 12.0 and scans every release and web build for design files (`97963ff`); the font coverage check runs in CI; the design-refs failure paths have tests; component tests (Tab reach, keys, states), Dialog's button order, Tab closing a Menu; screen tests (every control's key caps on three systems, where settings are stored and that they never reach the network, the Arabic strings the boards draw, the shell in the pseudo-locale); 206 component goldens; the spec walker over item types and variants; the `Fm*` names (ADR 0011). The lead fixed what the component goldens showed: key caps mirrored in right to left, the Arabic DatePicker header, the gallery's ProgressBar sample, and keys FmWindow does not draw on Duplicate, Extract and Find & redact (G98, G99). The golden matrix gained the Privacy pane (144 window goldens, 19 comparison pairs), the texture-registry fallback is designed in ADR 0009, and a manual design-references run rendered all 224 PNGs offline twice, identical (run 38892774885). CI runs on `c9475fb`, `d7fd363` and `97963ff` were green on the three systems. `design/` unchanged. | `44cfe93` to the head of this push |
| 2026-10-16 | M1 | Phase L, closing M1. A review of the batch found four minor problems (the spec walker skipped Dart 3.13 factories; the component goldens' Arabic region; the audit count in this log; DejaVu Serif in the Flutter rules), all fixed with a test where code changed. A one-off GitHub GraphQL error failed the comparison comment on `54d2ef9`; one re-run passed and the step now retries, then only warns (`acc4b4d`). The ROADMAP §5 boxes are ticked with their evidence: 67 of 84, the rest waiting on the owner (Proposed items, R1, R2 and arm64 checks, native review; B100). A fresh clone at `f41d789` ran all 30 CLAUDE.md commands on Linux; CLAUDE.md, CONTRIBUTING and README gained the build, run and web commands and the M1 status. A check found all 144 controls disabled for a future version listed in BACKLOG with their milestones. CI runs on `54d2ef9` and `f41d789` were green on the three systems. M1 is complete and waits for the owner's approval; pull request #2 is ready for review. `design/` unchanged. | `f41d789` to the head of this push |
| 2026-10-16 | M1 | The owner asked for the translation review table in the repository. [TRANSLATION_REVIEW.md](TRANSLATION_REVIEW.md) holds every message in English, Turkish and Arabic with the note for translators, how to review and how to send corrections; the table is generated from the ARB files by `dart run l10n:review_table` (`tools/l10n`), and CI fails when it is stale. The column that said where each translation came from is not carried over: it needed scratch data from phase J1 and was incomplete for the strings of phases F to I. `design/` unchanged. | `42daf76`; CI green on all 11 checks |
| 2026-10-16 | M1 | The owner set two working rules: at most 15 to 20 commits per pull request from M2 on, pushed in checked batches, and a plain message when a pull request is ready to merge (CLAUDE.md "How to work", ROADMAP §3.1 and E7, the owner decisions above). `design/` unchanged. | the head of this push |
| 2026-10-16 | M2 prep | The owner merged M1 (pull request #2, `aa7ad21`) and answered every open question as proposed, with the release files for macOS, Windows and Linux on GitHub Releases (Q15), and approved every item under Still Proposed in M1. QUESTIONS.md has all 20 entries answered; the 12 Needs owner entries of DESIGN_GAPS.md are Decided (G01 to G03, G25, G26, G33, G36, G51 to G53, G56, G60); ADRs 0009 and 0018 are Accepted, with the Proposed details of 0003, 0004, 0006, 0008 and 0019 and the reading of "GPL-compatible" in 0016; CLAUDE.md, ROADMAP's M1 status and this file follow. At the owner's request this pass changed only the answers and their status lines: the other mentions in ROADMAP, ARCHITECTURE, DEPENDENCIES, DESIGN_INVENTORY, BACKLOG, the body text of ADRs 0015 and 0017, CONTRIBUTING, SECURITY and the rules files follow in the M2 planning pass, after the owner adds a corrected design export. On the branch `m2-open-and-view`. `design/` unchanged. | the head of this push |
| 2026-10-17 | M2 phase 0 | The owner approved the crash-log placeholders of ADR 0010 and the 640 px canvas minimum (G95), pushed a corrected design export to `main` (`519d42a`: 253 boards, 30 new, of which five are M1 builds, 15 are for M2 including the region-format table `a12-0` and 10 are for M3; 29 carry an EN/TR/AR switch) and chose a small design-sync pull request before M2: pull request #3. `main` merged in with a sign-off. CI on `main`, red since the export, fixed: two moved design lines in the component spec, the 253 boards with two special captures (`a12-0` as the element, `a2-3m` as the box around its six sidebars), and the `design/` check on pushes, which had flagged the owner's own export. `tools/design-refs` renders the 58 Turkish and Arabic variants and has the sets `@m1`, `@m2` and `@langs`; a full `--twice` render of all 312 PNGs was identical; the comparison pairs moved to the M1 build boards in three languages. The app matched to the new boards: the free step's 6 px tile padding (a two-line Turkish tile is 50 px, as the board measures) and its accessible name, two Turkish strings, and a1-2b's settings link (body-strong, a trailing arrow mirrored right to left); 12 goldens regenerated, 1983 tests pass. The 17th repository check, `dco_signoff`. The documents: an agent workflow (one writer and one adversarial reviewer per group, 47 review findings fixed) synced the inventory, the roadmap and the design gaps (22 resolved, five in part, G100 to G111 new) and swept the approvals through ARCHITECTURE, DEPENDENCIES, BACKLOG (B101 to B106), ADRs 0004, 0008, 0009, 0010, 0015 and 0017, CONTRIBUTING, SECURITY, the rules files and code comments; the six approved M1 boxes are ticked. The M2 plan above, Proposed ADRs 0020 and 0021, and Q21 (memory-mapping) added. CI green on three systems at `70b1ea2`. `design/` unchanged by this work. | `e6e6200` to the head of this push |
| 2026-10-17 | M2 | The owner approved the M2 plan (the go-ahead for M2) and chose to continue M2 in a Claude Code session on their own computer. Recorded: the plan approved, with every decision it marks Proposed except the items still Proposed at the M2 review, Q21 and strace; ADRs 0020 and 0021 Accepted; the plan's details in ADRs 0008, 0009 and 0010 approved. Pull request #3 waits only on the owner's merge. | the head of this push |
| 2026-10-19 | M2 | Pull request #3 was merged as `b6fd215`, and CI on `main` was green (run [39022269403](https://github.com/KEREM-BAS/Ferman/actions/runs/39022269403)). The branch `m2-open-and-view` was opened again from `origin/main` (the local copy, fully merged into it, deleted first) and pushed; GitHub opens no pull request for a branch without commits, so draft pull request #4 followed the first commit. Wave W0: the feature registry, the `Feature` enum in `app/lib/app/feature_registry.dart` with 68 values, the features that are visible but do not work yet, each naming its open BACKLOG row, and `tools/checks` `feature_registry`, the 18th repository check (a value without an open row, a value whose row is under Done, a value that names no control, and the future-version reason passed without the registry all fail). Every control disabled for a future version takes its reason from its value; the Comment row's Measure follows Measure (B051), the other tools Comments (B050); the default-app button follows each system's own row (B080, B101, B102); a first-run tile takes every feature it covers ("Edit text and images": B041 and B043). An adversarial review of the first version found no change in behaviour or in the goldens and 7 problems, all fixed before the push: an `available` flag could enable controls without their handlers or leave them disabled without a reason, so a feature now ships by leaving the registry; the drop zone's shared reason (recorded, B010); per-tile feature sets (G12); a reviewed list instead of every component file; fenced blocks and rows both open and under Done in the BACKLOG parser; gallery uses no longer count as controls; stale line citations in BACKLOG and DESIGN_GAPS. The title bar's Settings button now always has its callback. Checked on the owner's Mac (MacBook Pro, Apple M5 Pro, macOS 26.5): both analyzers clean, the Flutter tests with the goldens excluded (goldens run on the Linux CI runner), the `tools/checks` tests, and all 18 repository checks pass. The owner's local CocoaPods changes in `app/macos/` are left uncommitted. `design/` unchanged. Then the Dco trial of W1, the critical path ([Q19](QUESTIONS.md#q19) option a), in a scratch worktree first: `full_dep: true` with ffigen 20.1.1 generated bindings that `flutter analyze` passed only because it leaves `lib/bridge/` out; analyzed on their own, they showed the M1 clash. Its cause was the codegen's cbindgen pass, which read the facade's public `API_VERSION` and declared the facade's `ApiVersion` as an opaque C struct; `cbindgen:ignore` on the facade module fixes it without renaming anything. Measured in profile builds on the owner's Mac: 1 MiB in 26 µs at the minimum and 73 µs at the median with Dco, against 665 µs and 1,053 µs with SSE (debug, Dco: 5,932 µs). The app builds for macOS and the web, the integration test passes in debug and profile, clippy, the Rust tests, the Dart licence check (111 packages) and all 18 checks pass; the CI codegen job installs `libclang-dev`, which `llvm_path` names. ADR 0009, Q19, ARCHITECTURE §3.1 and §3.4, DEPENDENCIES (ffigen, libclang), CONTRIBUTING, CLAUDE.md and the rules files record it. | the head of this push |
| 2026-10-19 | M2 | Pull request #4 was merged. On the owner's MacBook Pro, `flutter run -d macos` first needed PDFium (`tools/pdfium/fetch.sh --platform mac-univ`), then crashed in Impeller about 15 s after launch (`impeller::Canvas::SetupRenderPass`, "The texture and its descriptor disagree about its size"). This is the open Flutter bug [flutter/flutter#185394](https://github.com/flutter/flutter/issues/185394); its fix, [flutter/flutter#192522](https://github.com/flutter/flutter/pull/192522), is still in review. With `--no-enable-impeller` (Skia) the app opens and draws; the owner keeps that as a local flag, not a repository setting, until a Flutter update carries the fix. The owner added a logo export to `design/` (`94e596d`: the board `Ferman Logo.dc.html` and `design/assets/logo/`, direction 1a "Mühür"). New `tools/app-icons` draws from it the macOS, Windows, Linux and web icons ([G112](DESIGN_GAPS.md#g112)); the Linux runner now sets its window icon, and the web favicon follows the browser's theme. iOS and Android icons (B107) and the macOS dark and tinted icons (B108) wait for their projects and the release pipeline. Checked on the owner's Mac: the tool's tests, `--check`, the macOS debug build (the new icon in `AppIcon.icns`) and the web release build with the bundle scan. The Linux runner change is checked by CI. | `94e596d` (the logo export); `edac9a4` (the icons, pull request #5, merged as `8031ddd`) |
| 2026-10-19 | M2 | Pull requests #4 and #5 were merged. `m2-open-and-view` was opened again from `origin/main` at `8031ddd` for the rest of M2. W1, commit 2: the fuzz and corpus workspaces, both excluded from the root workspace. ferman-core gained `limits`, the `Limits` struct with the defaults of ARCHITECTURE §9.1, and `filters`, its first parser: ASCIIHexDecode, ASCII85Decode, LZWDecode (weezl, with `/EarlyChange`), FlateDecode (flate2 on miniz_oxide; the zlib header is checked, the Adler-32 is not) and RunLengthDecode, with the PNG and TIFF predictors, each bounded by the decoded-size limit and the filter chain by its length, in modules that deny unchecked indexing and arithmetic. 42 unit tests (the ISO 32000 LZW example, the ASCII85 edge cases, bombs, truncation, every PNG filter type, TIFF at 1, 2, 8 and 16 bits) and 10 property tests (round trips through independent encoders, a five-filter chain, and arbitrary bytes never past the limit). `fuzz/` (pinned `nightly-2026-10-15`, cargo-fuzz 0.13.2, libfuzzer-sys 0.4.13 under its approved NCSA exception) has one target per filter; on the owner's Mac each ran 60 s with AddressSanitizer, about 92 million inputs in all, with no crash. `tools/corpus` has the generator registry (empty until the corpus commit), `generate`, `list` and `check` (every corpus file has its README row with the right SHA-256, a generated PDF's expected text shares its row, generators are deterministic and current, files over 1 MB are checked by hash), with 17 tests. CI: a fuzz smoke job (60 s per target on Linux), the corpus tool on the three systems, and cargo-deny for both workspaces (also the corpus tool's dev-dependencies). Checked on the owner's Mac: fmt, clippy and the tests of all three workspaces, cargo-deny for all three, and all 18 repository checks. | `f67020a` |
| 2026-10-19 | M2 | W1, commit 3, first part (the owner split the corpus commit in two). CI on draft pull request #6 was green at `f67020a` (Rust, cargo-deny, the fuzz smoke run and Flutter on all three systems). `tools/corpus` gained its generators and their tooling:<br>- **A small PDF writer on lopdf 0.45.** Fixed `/ID`, fixed dates, compressed streams; object streams with a cross-reference stream for tez-tr.<br>- **Fonts.** Composite `Identity-H` subsets shaped by harfrust 0.14 with `/W` and `/ToUnicode`; simple TrueType WinAnsi subsets, the `cmap` that subsetter 0.2.6 leaves out put back; fonts named but not embedded, with WinAnsi or the Windows-1254 `/Differences`.<br>- **Text.** Lines justified with `Tw` or `TJ`, character spacing, marked content for tagged PDF.<br>- **A standard security handler.** RC4 40 (R2), RC4 128 (R3), AES-128 (R4), AES-256 (R6 with SASLprep), its vectors seeded; it matches the published RC4 and FIPS-197 vectors.<br>- **The attachments.** A stored zip for an xlsx, and JPEGs coded with DC coefficients only.<br><br>19 generators: kira-tr (`DocKira`: Word-like font pairs, Madde 6 in EB Garamond without "ğ", [G113](DESIGN_GAPS.md#g113), the IBAN frame, six fields on page 3, three attachments), kira-tr-damaged (every cross-reference offset two bytes early, page 3 in a TimesNewRomanPSMT that is not embedded), kira-tr-restricted (owner password, AES-128), truncated (cut at 18 KB inside object 13), disagree-pages (lopdf 2 pages, PDFium 3), the payslip in four encryption methods (the AES-256 password `Eylül2026maaşı`), xfa-visa, form-aks1-tr (the design's 20 fields, 15 required, with date and range actions) and its flat twin, mietvertrag-de (6 pages), nda-en (4 pages, a signature structure with a correct `/ByteRange`), tez-tr (64 tagged pages, nested outline, page labels i–viii and 1–56), ocg-plan (six layers, one off, a 1:75 `/Measure`), js-openaction (scripts in three places), long-500 and imar-2400.<br><br>The rules: a generator whose PDF is over 1 MB commits neither file and both are listed in `tests/corpus/generated/.gitignore`, which `check` requires; `.gitattributes` keeps `generated/` from line-ending conversion. EB Garamond is fetched by `tools/corpus/fetch-fonts.sh` with a pinned SHA-256, and CI caches it.<br><br>The PDFium oracle test (`tools/corpus/tests/oracle.rs`, `#[ignore]`) runs in CI on the three systems: every file opens or fails as its generator says, with its page count and its expected text compared without whitespace, and no encrypted file opens without its password. Unit tests check the damage with lopdf.<br><br>Seen while checking: macOS PDFKit renders every file but does not open the AES-256 payslip with its Turkish password, though it opens an ASCII one; PDFium follows the standard (SASLprep, then UTF-8).<br><br>Checked on the owner's Mac: the oracle passes for all 19 generators. The tool's 37 tests, fmt, Clippy, `check` and cargo-deny (also with the dev-dependencies) pass; generating everything takes about 4 s. | `33d9836` |
| 2026-10-20 | M2 | W1, commit 3, second part. CI on `33d9836` was green on all 11 checks. Four generators complete the first wave:<br>- **report-ar** (`a2-15`): 12 Arabic pages in IBM Plex Sans Arabic composite subsets, `/Direction /R2L`. Paragraphs get their levels from unicode-bidi; each run is shaped in its own direction, and each line is drawn in visual order (UAX #9 rule L2). Numbers, an IBAN, "ISO 9001" and an e-mail address read left to right inside the Arabic. The page has lam-alef ligatures, marks on their letters, mirrored parentheses (their glyphs map to the bracket they show), Arabic-Indic page numbers and three tables. Hyphenated numbers were avoided, because in Arabic text the bidi algorithm reverses "2025-0418".<br>- **letter-ja-vertical** (`a3-15`): one page of vertical text in Noto Serif JP at 400 and 600, `Identity-V` fonts with `/W2` and `/DW2` and the `vert` forms; "19" upright in an `Identity-H` font of the same face; kinsoku (a hanging comma ends one column; oidashi is unit-tested); letter spacing as `TJ` adjustments.<br>- **scan-tr** (`a3-11`, three pages, greyscale at 200 dpi, PNG Up predictor) and **quote-ja-scan** (two pages, one bit per pixel at 300 dpi): image-only. A small rasteriser fills skrifa outlines with 4 × 4 coverage, turns the page by sines written as constants, and encodes it. Its black-and-white threshold is 176, because 128 dropped the one-pixel horizontals of the Mincho face where the turn spread them over two rows.<br><br>Noto Serif JP is fetched like EB Garamond and instanced by subsetter's `variable-fonts` feature. The oracle gained `Expect::OpensUnordered`: PDFium reverses the text of Arabic ligature glyphs, moves neutral characters at the edge of numbers and orders vertical columns its own way, so those pages are compared by characters.<br><br>Checked on the owner's Mac: the oracle passes for all 23 generators; the tool's 45 tests, fmt, Clippy, `check` and cargo-deny (also with the dev-dependencies) pass; PDFKit renders of all four files look right. | the head of this push |
| 2026-10-20 | M2 | W1, commit 4 (render). CI on `42daf76` was green on all 11 checks.<br>- **ferman-render** gained documents and views on its render thread: `open_document` loads the bytes through a reader without a copy and reads every page size; `open_view`, `request` and `close_view` run the wanted sets, with the priority classes of ARCHITECTURE §4.5, generations, and delivery to every view that still wants a bitmap; the tile and thumbnail caches are LRU caches capped by bytes, and each document keeps 8 pages loaded. Messages go over crossbeam-channel.<br>- **Tiles** are 512 × 512 BGRA in quarter-octave buckets, rendered into Ferman's own white buffer with a matrix, a clip, fixed flags and a 32-pixel margin.<br>- **Two PDFium findings**, both measured: pdfium-render's lock leaves 192 of 481 bindings unguarded, so one render thread holds PDFium at a time; and a glyph crossing a bitmap edge renders differently, hence the margin.<br>- **Tests:** 42 unit tests (the grid, the buckets, the queue's order, the caches) and 12 PDFium tests, among them ten identical runs over eight corpus files and the three-view stress run (20 s by default; 10 minutes passed on the owner's Mac with flat memory). The `first_page` benchmark: 2.71 ms for opening `long-500` and its first tile on the owner's Mac.<br>- **G101:** the start screen's warning banner with "Copy technical details" when the engine or PDFium is missing, in English, Turkish and Arabic, with 10 tests; seven app test hosts now get a working fake engine.<br><br>Checked on the owner's Mac: fmt and Clippy (with and without `frb`), every workspace test and every PDFium test, cargo-deny (also with the dev-dependencies), both Dart analyzers and 1,644 Flutter tests. | `2111baf` (CI green on all 12 checks) |
| 2026-10-21 | M2 | W1, commit 5 (core). CI on `2111baf` was green on all 12 checks, so ROADMAP §6 step 1's determinism and stress boxes were ticked.<br>- **The open path** in ferman-core: `Source` (an owned buffer and its SHA-256), `open` and `Document`, `sniff` for files that are not PDFs, and ferman-core's own cross-reference reader (`xref`: tables, streams, `/Prev` with loop detection and the section limit, hybrid files, every entry checked against its header). A broken table is rebuilt from a scan of the objects (`repair`), with a report for a1-9 and, without a catalog, a `Diagnosis` for a1-9b. lopdf parses a healthy file in place and a repaired or encrypted one through a copy with one clean table.<br>- **The security handler** (`security`): revisions 2 to 6, RC4 and AES, crypt filters, the owner password first, SASLprep into a wiped buffer, decryption after lopdf's parse (object streams included), so lopdf never sees the password. `Password` wipes itself; the hash and cipher crates use their `zeroize` features. PDFium's copy of the password is [Q22](QUESTIONS.md#q22). ferman-render's `open_document` takes the password and tells `WrongPassword` from `PasswordRequired`.<br>- **The structure scan** (`structure`): pages with labels, boxes and PDFium's size rule; outline with named destinations; attachments; layers in `/Order`; fields, XFA and `xfa_only`; signatures and certification; scripts by place; fonts with embedding; direction, language and information.<br>- **The two-parser check** agrees on every corpus file but `disagree-pages` (2 pages against PDFium's 3), with PDFium in a ferman-api test.<br>- **Fuzzing:** `syntax_object`, `xref_repair`, `security_handler` and `open_document`, through ferman-core's hidden `fuzzing` module; 60 s each on the owner's Mac found nothing.<br>- **Found on the way:** lopdf 0.45 loads a table with wrong offsets as an empty document and a locked file as one object (hence the reader and the handler); lopdf bounds nesting at 100 by itself, so an object nested deeper counts as unreadable and the document opens repaired (G114 records a1-9b's expected size, known only from a linearized file).<br>- **Dependencies:** lopdf, sha2, md-5, aes, rc4, stringprep, unicode-normalization and zeroize in ferman-core (30 crates new in `Cargo.lock`), and lopdf behind a single door of the `crate_graph` check.<br><br>Checked on the owner's Mac: fmt and Clippy (with and without `frb`, and the fuzz workspace), every workspace test with the PDFium tests, the two-parser test, cargo-deny, the repository checks. | `5bf026d` (CI failed on the format of `crate_graph_test.dart`, fixed in the next commit, and on a Chromium download that did not resolve) |
| 2026-10-23 | M2 | CI on `5bf026d` failed on the format of `crate_graph_test.dart` and on a Chromium download that did not resolve; `cfc3715` fixed the format. The owner chose to merge pull request #6 once it is green and to continue W2 in a new pull request.<br><br>W2, commit 7 (the API):<br>- **Open:** `Engine::open(path, password)` reads and parses on a `ferman-open` thread with a 64 MB stack under the panic guard, loads the bytes into PDFium and compares the parsers. It returns the id, the read-only reason (repaired, the parsers disagree, XFA only), the direction and every page's size and label. There is no `unlock` and no `page_info`: open again with the password, and the pages come with the open.<br>- **Close and views:** `close`, and `open_view`, `request` and `close_view` over the render thread.<br>- **Errors:** the open path's kinds and message keys (`NotFound`, `PermissionDenied`, `PasswordRequired`, `WrongPassword`, `Damaged`, `Unsupported`, `ResourceLimit`, `Io`, `Internal`), mirrored in the `frb` module; the bindings regenerated.<br>- **CLI:** `ferman open <file> [--json]`.<br>- **Scope:** each later call comes with the screen that calls it; the document actor waits for M3's first change (Proposed, for the M2 review); B109 records the file only PDFium can read.<br>- **Tests:** `crates/ferman-api/tests/open.rs` (renamed from `two_parsers.rs`, now through the facade) and the CLI's `open`.<br><br>Checked on the owner's Mac: fmt and Clippy (with and without `frb`), every workspace test with the PDFium tests, cargo-deny, both Dart analyzers, the repository checks. | `2512258` |
| 2026-10-23 | M2 | The owner merged pull request #6 as `d66e28e`; `2512258` (commit 7) opened draft pull request #7, with Auto-fix on.<br><br>W2, commit 8 (the app's engine services):<br>- **Bridge:** `open`, `close`, `open_view` (its first event is the view's handle), `request_view` and `close_view`, with plain mirrors of pages, items, priorities and updates; bindings regenerated.<br>- **App:** `EngineService` gains the same calls and Dart models, `EngineException` its kind; the fake and the unavailable service follow.<br>- **Scope:** one service instead of four, no `TileTransport` seam (Dco met its target), images left to the viewer.<br>- **Tests:** the integration test opens a PDF it writes, renders its thumbnail, closes it, and checks `notFound`; Rust and Dart unit tests.<br><br>Checked on the owner's Mac: fmt and Clippy (with and without `frb`), the workspace and `frb` tests, both Dart analyzers, the engine tests, the integration test on macOS (debug build; the 1 MiB round trip took 5.5 ms at the minimum, a debug figure, not a budget), the repository checks. | `57d4c83` |
| 2026-10-23 | M2 | W2, commit 9 (the viewer):<br>- **Canvas:** the open document through one engine view, in four layouts (single and two-page one row at a time, continuous and book scrolling), spreads and the cover in the document's direction (a2-1a to a2-1d, a2-15).<br>- **Tiles:** the tiles in view at the zoom's bucket, nearest the centre first, then the tiles around and the previews; previews and other buckets stand in until the sharp tiles arrive; a failed page shows a2-13's placeholder with Try again.<br>- **Zoom and tools:** the zoom field, steps, fits, Actual size, Marquee zoom, ⌘ or Ctrl with the wheel and the trackpad's pinch; Select, Hand and Marquee zoom; scrolling keys and page turns.<br>- **Status bar:** page turns, the page field (⌘G, numbers and labels) and the zoom.<br>- **Scope:** 100 % is 96 dpi as the design draws it; the controls work only with a document open, so the placeholder documents and the M1 goldens keep theirs; Settings › General's defaults come with the open in W3; no scrollbars, as no board draws one.<br>- **Tests:** layout, zoom and tile selection, the view state, the canvas in the shell with the fake engine, and the integration test's BGRA decode of a red page.<br><br>Checked on the owner's Mac: both Dart analyzers, `flutter test --exclude-tags golden`, the integration test on macOS (debug build, 7 of 7), the repository checks. | `94d2222`, `f70a586` |
| 2026-10-30 | M2 | CI on `f70a586` was green on all 12 checks (`f70a586` regenerated a stale provider hash), and the owner merged pull request #7 as `652365d`. The owner split the sidebar in three: the lists now, showing and hiding layers as commit 10b, Save attachment as… with W3's open picker.<br><br>W2, commit 10 (the sidebar):<br>- **API:** the open result carries the outline, attachments, layers and signature fields; the bridge mirrors them, the outline flattened with depths, dates as written.<br>- **Tabs:** Pages through a thumbnail view of its own, Outline with folding and the current section, Attachments, Layers and Signatures in a2-14's neutral state, each empty tab with the new `EmptyState` (a2-3m); headings count their lists.<br>- **Scope:** the legend, Save attachment as… (B110) and the eye buttons (B111) stay disabled; the placeholder documents keep the M1 sidebar; the sidebar's state while hidden waits for W3 (B091); goldens in W4.<br>- **Tests:** an API test on four corpus files; widget tests of every tab.<br><br>Checked on the owner's Mac: rustfmt, Clippy, the API tests with PDFium (5 of 5), both Dart analyzers, `flutter test --exclude-tags golden` (1,676 pass), the integration test on macOS (debug build, 7 of 7), the repository checks (18 of 18). | `6fc7e52` |
| 2026-10-30 | M2 | CI on `6fc7e52` was green on all 12 checks. W2, commit 10b (showing and hiding layers, B111):<br>- **Core:** `Document::layer_appendix`, the first render-only appendix (ADR 0009): the catalog with the new `/OCProperties /D`, then a cross-reference stream that names every object.<br>- **Render:** `reload` loads the bytes and the appendix through one reader without a copy and gives every page a new render key (shortcut: all pages, until M3's interpreter finds the layer's users).<br>- **API and app:** `show_layers`, the bridge, `EngineService.showLayers` and `layerVisibilityProvider`; the eye buttons work; a locked layer, a repaired document and one opened with its password keep their layers (B111 stays open for the last two, waiting on M3 or Q22).<br>- **Tests:** the appendix read back by ferman-core (classic and modern files); a PDFium test on ocg-plan; widget tests of the buttons and the views asking again.<br><br>Checked on the owner's Mac: rustfmt, Clippy (workspace and frb), the Rust tests with and without PDFium (the API tests 6 of 6), both Dart analyzers, `flutter test --exclude-tags golden` (1,678 pass), the integration test on macOS (debug build, 7 of 7), the repository checks (18 of 18). Not checked here: the Linux goldens (no screen changed), and PDFium reading the appendix after a file with object streams (ferman-core reads it back; the corpus has no such file with layers). | `8dfe72d` |
| 2026-10-30 | M2 | W2, commit 11 (text), first part: ferman-core's content-stream lexer (`content`): operators with their operands and byte spans, read as leniently as PDFium reads them (a bad token goes with the operands before it; data that ends inside an object ends the stream, in linear time), inline images as one `BI` operator with their dictionary, and the operator limit per page. The 10th fuzz target, `content_lexer`, ran 2.4 million inputs in 60 s clean on the owner's Mac. | `02fe245` |
| 2026-10-30 | M2 | W2, commit 11 (text), second part: ferman-fonts' first module, `cmap`: one `CMap` for encoding and ToUnicode CMaps, read leniently (what cannot be read is skipped; parsing never fails): codespace ranges of mixed lengths split a string so every byte belongs to a code, `cidchar` and `cidrange`, `bfchar` and `bfrange` in both forms with UTF-16 surrogates and ligatures, `/WMode`, `usecmap` recorded for the caller's depth limit and joined with `inherit`, `Identity-H` and `Identity-V`. Ranges stay ranges. The 11th fuzz target, `cmap`, ran 3.2 million inputs in 60 s clean on the owner's Mac. | `b139810` |
| 2026-10-30 | M2 | W2, commit 11 (text), third part: ferman-fonts' `encoding`: StandardEncoding, WinAnsiEncoding (code page 1252, unused codes the bullet) and MacRomanEncoding (with `currency` at 0xDB, as ISO 32000-2 has it) as characters; `SimpleEncoding`, a base with `/Differences`; glyph names as text by the glyph list's rules (suffixes, `_` ligatures, `uniXXXX` and `uXXXX`) and a table of the Latin-1 and Latin Extended-A names in Unicode order, which covers the corpus's Turkish `/Differences` (DEPENDENCIES §5.4 records the names' BSD-3-Clause source). Symbol, ZapfDingbats and embedded Type1 encodings follow with the fonts that need them. | `92e455d` |
| 2026-10-30 | M2 | W2, commit 11 (text), fourth part: ferman-core's text interpreter (`interpret`, `Document::page_text`): a page's content streams joined, `q` and `Q`, `cm`, `BT`, the text state (`Tc`, `Tw`, `Tz`, `TL`, `Ts`, `Tr`, `Tf`), `Td`, `TD`, `Tm`, `T*`, `Tj`, `TJ`, `'` and `"`, and forms through `Do` with their `/Matrix` and resources, a cycle skipped and the recursion and operator limits. Each font dictionary reaches the sink once as plain data (`FontResource`: type, base font, base encoding and `/Differences`, widths, `/MissingWidth`, symbolic flag, Type3 matrix, decoded ToUnicode, the composite font's CMap by name or decoded, `/W`, `/DW`, `/W2`, `/DW2`), so no lopdf type leaves ferman-core; each show reaches it with its matrix and state, and the sink returns the displacement (the planned `TextAdvance`). The 12th fuzz target, `interpreter`, ran 265,000 inputs in 60 s clean on the owner's Mac. Clipping, colour, marked content with `/ActualText` and Type3 procedures wait for M3. | `593fa7a` |
| 2026-10-30 | M2 | W2, commit 11 (text), fifth part: ferman-text's `extract::page_text`. Fonts come from the interpreter's resources (a composite font's CMap, ToUnicode, the simple encoding with `/Differences`, `/Widths`, `/W`, `/W2`); each show places its glyphs in page space with `Tc`, `Tw` on code 32 only, `Tz` and `Ts`. Lines follow the content order by baseline, or by column for vertical text; a word break goes at a space glyph or a gap over a fifth of the font size. A right-to-left line is read back with unicode-bidi from its visual order: marks stay with their letters, a mark on a ligature goes after the letter it sits over (before an alef: tanween is typed before it), brackets at right-to-left levels are mirrored. Acceptance (ROADMAP §6 step 5, first box): every page of every generated file reads as the generator's source text after NFC, compared without whitespace as the PDFium oracle compares (`crates/ferman-text/tests/corpus.rs`), the Turkish files, `letter-ja-vertical`, `mietvertrag-de`, the four encrypted payslips and `long-500` included, except four pages of `report-ar` listed in the test (B112: a percentage ending a sentence and "(IBAN):" read back out of order). unicode-bidi 0.3.18 joins ferman-text (DEPENDENCIES; no new package in `Cargo.lock`). Search (the index, Turkish folding, the find bar) is commit 12. | `c37b7e8` |
| 2026-10-30 | M2 | W2, commit 12 (search), first part: ferman-text's `search::find` with a2-4a's `SearchOptions` (Match case, Whole words, Ignore accents and dotted/dotless i on by default for every document as G61 says, and Turkish case folding when accents count). A query and a page's text fold the same way (NFKC, case with İ and ı, then without marks, "ı" as "i", "ß" as "ss", no tatweel; white space runs as one space), and matches come back as character ranges of the page's text. Tests: a2-4a's examples ("i" finds İ, ı and î; "c" finds ç; "kira" finds KİRA), Arabic without its marks and presentation forms, and on the corpus "kira" finding KİRA and Kira, "istanbul" finding İstanbul in kira-tr (it has no upper-case İSTANBUL), "ILIK" finding ılık in tez-tr, "muller" and "gleimstrasse" in mietvertrag-de and "الاسكان" in report-ar. | `f7bfdbe` |
| 2026-10-30 | M2 | W2, commit 12 (search), second part: match quads. ferman-text's `extract::page_layout` gives a page's text with the box of every character in displayed points (from the page's top-left corner after its crop box and `/Rotate`, y down, as the canvas lays pages out; `Page::display_point` in ferman-core), and a right-to-left line carries its boxes through the bidi reordering (`reordered_levels_per_char` and `reorder_visual`, the same result as before). A space or line break no glyph drew has no box. | `c1ffcff` |
| 2026-10-30 | M2 | W2, commit 12 (search), third part: the search job. `Engine::search` runs on a thread of its own and streams `Started` (before any match), each page's matches (a rectangle per line, the line as the snippet) and the progress every 25 pages, then `Done`; `cancel_search` stops it. The document's language turns on Turkish case folding when accents count. The engine now keeps every open document's model (with the layers' flag) and each page's text once read. The bridge's `search` is a stream function (cancelling the stream stops the search), and the app's `EngineService.search` gives `SearchMatches`, `SearchProgress` and `SearchDone`, with `SearchOptions` defaulting to Ignore accents on (G61); the fake answers from a table. Tests: the facade with PDFium on kira-tr (events in order, "KİRA" in its snippet, its rectangle on the page, more than five matches) and a cancelled search on long-500; the integration test searches a PDF through the bridge on macOS. | `1be7803` |
| 2026-10-30 | M2 | W2, commit 12 (search), fourth part: the find bar. ⌘F or Ctrl+F opens it over the canvas at the UI's end (a2-4a): the `SearchReplaceBar` with the live count, ↵ and ⇧↵ through the matches (the page follows; after the last back to the first), and under it the search options, which a2-4c's progress (a search past its first 25 pages, with Cancel, also Esc) or a2-4d's no results (what was searched and how) replace ([G115](DESIGN_GAPS.md#g115)). The matches show on the canvas, the current one orange with its ring, the rest yellow. `findProvider` searches as one types (each page's text is kept, so only the first search reads content) and starts over with the document. Regular expressions (B113) and the other places to look (B114) are disabled for a future version; the bar's regex toggle gained a disabled reason (`regexDisabledReason`, in the component spec). 29 new strings in English, Turkish and Arabic, the a2-4c and a2-4d copy from the boards' own Turkish and Arabic. Tests: the bar's widget tests with the fake engine. | `f0a142a` |
| 2026-10-30 | M2 | W2, commit 12 (search), fifth part: the sidebar's Search results tab (a2-3e, a2-4b). ⌥↵ in the find bar opens it (the bar's component now leaves Alt+Enter to the app); its own field shares the query with the bar, a summary counts the matches and pages, the results come grouped by page with each line as a snippet, the match marked and the current one tinted, and a click goes to it; a search with no match shows a2-3m's empty state with a2-4d's words, and the tab's heading counts the matches. The isolated-fallback test now accepts a long call that the formatter splits with a trailing comma. Still open in B071: ↑ and ↓ through the results and the no-text-layer state. Tests: 1,681 widget and unit tests pass. | `4c55e0c` |
| 2026-10-30 | M2 | CI on `4c55e0c`: the Rust jobs failed on all three systems, because the search test cancelled a search on long-500, which is over 1 MB and not committed. The cancel case now uses the committed tez-tr; the whole workspace, PDFium tests included, passes with the uncommitted files moved away. The owner chose to close pull request #8 here and continue M2 in a new pull request. | `1b5fe23` |
| 2026-10-30 | M2 | CI on `1b5fe23` was green on all 12 checks. At the owner's request pull request #8 was marked ready and merged with a merge commit as `34d444d`. M2 continues on `m2-open-and-view` in pull request #9. | `34d444d` |
| 2026-10-30 | M2 | W3, commit 13 (open), first part: the system open panel (a1-13, ADR 0018), ahead of the rest so the owner can try the app. The title bar's "+" (start screen and editor), ⌘O or Ctrl+O, Start › Open file… and Open a PDF show it through file_selector, filtered to PDF, several files at once; each file opens in a new active tab, a file already open shows its tab, the first one replaces the M1 placeholder tabs, and opening from the start screen goes to the editor (`/editor`) when one opened. A document just opened shows "Saved on this device" without a time. Each tab keeps its view, layers and search: the view providers follow the active tab and keep each document's state in `documentMemoryProvider(id)`, a family keyed by the document (ADR 0011); a layer change or search event that arrives after a tab switch stays with its document. The title bar shows as many tabs as fit at 112 px, the active one kept, and "+N" (its width measured) opens a1-10's menu of the hidden documents (B028 Done; Show all open documents is B117); the strip's focus nodes follow their tabs. A file that does not open is reported where the pick was made: a danger banner on the start screen, a danger toast at the bottom end of the editor's canvas (G116), until the error tabs and the unlock dialog (B115); the web build keeps the future-version reason (B116). file_selector's platform interface declares `http` without importing it: the owner approved it on 2026-10-30 as `pub_denylist`'s first transitive exception, bound to that package; the check fails on any `package:http` URI in `app/lib/` and, in a new step of CI's Linux Flutter job, on any other resolved package that depends on it. macOS: both entitlement files gain `files.user-selected.read-write`; the debug build shows the panel with the PDF filter (the owner's MacBook Pro M5 Pro, not R1/R2; choosing a file in it was not driven, since the window sat on another Space). DropZone gained `createDisabledReason`; the engine providers no longer retry a failed status. Two adversarial review workflows (4 and 3 reviewers, two skeptics per finding) checked the batch: 19 and then 10 confirmed findings, all fixed, each race and layout fix with a test that fails without it. Tests: 1,696 widget and unit tests pass; the web build and its bundle scan pass; the start and shell goldens change ("+", Open and the strip) and are regenerated on Linux. | `98ab6bc` |
| 2026-10-30 | M2 | W3, commit 13 (open), second part: drag and drop and files from the OS. desktop_drop 0.8.4 arrives with its MPL-2.0 `dbus` (approved in Q17): the licence check skips `dbus` by name in CI, and its source location ships as a licence entry. Files dropped on the start screen or the editor, title bar included, open each in a new tab (B010 Done); while they are dragged a1-6's overlay covers the screen below the title bar, without a count or a row per file, since desktop_drop names the files only on the drop (G117), and "Combine into one PDF" is disabled with its reason as its line (`Feature.combineDropped`, B104). First run and Settings take no drops. Files from the system reach Dart over `ferman/open` (`PlatformOpenRequests`): macOS through `FlutterAppDelegate`'s lifecycle delegates with `CFBundleDocumentTypes` for `com.adobe.pdf` (Editor, Alternate); Windows through a mutex and a named pipe per user and session, the command line made absolute; Linux through GApplication's D-Bus uniqueness (`G_APPLICATION_HANDLES_OPEN`). `main` takes the command line; the launch's files open before the first frame shows (for at most 500 ms), so a cold launch with a file skips Start, and finishing first run shows the editor when files arrived meanwhile; a file asked for while it opens waits for that open, so it opens once, and different files do not wait for each other. On Windows only the owner of the mutex serves; the pipe admits only the user's SID, a later launch checks that the server runs as the same user, sends a length-prefixed request and exits only once the first instance's window has taken it; a launch that cannot forward runs on its own and takes over serving when it can. Debug builds use their own instance names (`.debug`) on Windows and Linux, so `flutter run` and the integration test never forward to an installed Ferman. Linux skips file names that are not UTF-8. The Q18 experiment moves to recent files, where bookmarks have their first use. Checked on the owner's MacBook Pro M5 Pro (not R1/R2), sandboxed debug build: a cold launch with `kira-tr.pdf` went straight to the editor with it rendered, and a second `open` with a new file and the open one added a tab and showed the open one's, in the same process; a drop from Finder was not driven. An adversarial review workflow (4 reviewers, a skeptic per dimension) confirmed 25 findings, all fixed: the Windows runner's local name shadowed `wWinMain`'s parameter (it would not have compiled), the pipe's squatting and impersonation risk, the mutex held without serving, non-UTF-8 names on Linux, the unbounded first-frame wait, the global queue behind a slow file, a minimized macOS window, a Linux window shown before its first frame, debug builds sharing the instance key, a1-6's 6/4 dash pattern for its 2 px frame, and stale docs. Tests: the open requests, the cold launch (the first frame waits for the engine, at most 500 ms), later requests after the launch, a file asked for twice at once, first run ending in the editor, the overlay with the Combine target disabled and only the tabs target ringed, drops on Start and in the editor, none on Settings or without an engine; the timer and the dedupe were each removed once to see their tests fail; the integration test checks that each runner answers the channel. | — |
| 2026-10-30 | M2 | W3, commit 14 (start and recent files). ferman-text gains `collate::collation_order` on icu_collator 2.4.0 (Unicode-3.0, compiled data; +1.34 MiB on the release engine library): Turkish puts "Ç" after "C" and "ı" before "i", digits compare by value; the API's `collation_order` returns indices and `EngineService.collationOrder` carries it (`3a15703`). The recent files: a Dart store beside the settings, most recent first, at most 50 besides the pins, each file that opens put first with its page count, its signatures and on macOS a security-scoped bookmark (`files.bookmarks.app-scope` in both entitlement files, the `ferman/files` channel). The start screen shows a1-4-m2 once there are recent files: the drop strip, pinned files with their unpin, recent files with search (case-insensitive in the UI language), sort (last opened, name, location through the collator) and grid or list (a1-4c), the on-device note and Clear list; a file that is gone opens a1-9e with Remove from list and Locate… (G118 records the pin button, the empty search, Clear list keeping the pins and a1-9e's close button). Under the sandbox `HOME` is the container, so "~" comes from the part before `/Library/Containers/`. Q18, first half: on the owner's MacBook Pro M5 Pro (not R1/R2), sandboxed debug build, a file from `~/Documents` opened with "Open with" was kept with its bookmark and, after a restart, opened from the recent files, while one kept without a bookmark could not be read; the replacement-directory half comes with Save attachment as… (B110, W3). The page previews and the Form and Scanned badges are B118. An adversarial review workflow (4 reviewers, a skeptic per dimension) confirmed 31 findings, all fixed: bookmarks resolved without mounting or UI, the Trash counted as gone, access started once, relocation merging pins and Locate starting fresh with one file, pinned files in the recent list as the boards draw them, the sort and view kept for the session, calendar days for "Today", one composed label per card, the hidden pin in the semantics tree and without pointer hits, no focus ring around a focused pin, file names in their own direction, the search folding "İ", the previous order kept while the collator answers, and stale docs and weak tests. Tests: the store's round trip with bookmarks, unreadable file, skipped entries, limit, pins, merge and Clear list; the bookmark channel; the start screen's sections, search, collator sort, list, pin on hover and on Tab, "~", opening a recent file, a1-9e's Remove, Locate and Escape, a bookmark made on open, and one that follows a moved file and is renewed; the semantics and renewal fixes were each removed once to see their tests fail. | `3a15703` |
| 2026-10-30 | M2 | CI on `98ab6bc` (pull request #9, Auto-fix on at the owner's request): two checks failed as expected or by a slip. The layer provider's generated hash was stale (`LayerVisibility.show` changed after the last build_runner run), now regenerated. The goldens changed only where the open controls are enabled: 96 shell views ("+" and "+3") and 6 start screens ("+", Open file… and Open a PDF), checked in the isolated diffs and replaced with the Linux run's renderings (artifact `golden-failures`). The new `pub_denylist` step passed in the Linux Flutter job. | the head of this push |
| 2026-10-30 | M2 | W3, error tabs and the unlock dialog (B115). A file that needs its password opens as a locked tab (`lock`) with a1-8's unlock dialog over the empty canvas; Open (or Enter) tries the password, a wrong one shows a1-8b's error with the attempt selected, Cancel closes the tab (the start screen shows when none is left). A file that does not open gets an error tab (`file-x`) that shows only the canvas: a1-9c's drop-zone error for a file that is not a PDF (DropZone gains an `actions` slot; Convert to PDF… disabled, B019), a1-9b's page for the rest, with a sentence per engine message key, Open another file…, Show in Finder (disabled, B119), the technical details and "Copy technical details"; opening the file again tries again. A file that runs out of memory or past a limit gets no tab: a1-9f's toast in the editor, a banner on the start screen, each with Try again. The engine names a damaged file's likely cause (`errorDamagedTruncated`, `errorDamagedEmpty`) and gives its facts as readable details; `arb_parity` now fails on an engine message key without its sentence in `app_en.arb`, so the first error strings arrive with their check. a1-9d's read-only banner waits for saving (B120). G116 resolved, [G119](DESIGN_GAPS.md#g119) records the rest. The owner asked on 2026-10-30 for no manual runs of the app until the end: the checks that need the running app are kept for one pass then. Checked on the owner's Mac: rustfmt, Clippy (workspace and frb), the API tests with PDFium (7 of 7), both Dart analyzers, `flutter test --exclude-tags golden` (1,739 pass), the tool tests, the repository checks (18 of 18). Not checked: the goldens of the new screens (none yet: step 16), the dialog and tabs in the running app. | pending |
