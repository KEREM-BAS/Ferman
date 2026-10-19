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
| Milestone | **M2, open and view: in progress** (since 2026-10-19) on the branch `m2-open-and-view`, opened again from `origin/main` at `b6fd215`, with draft pull request #4 to `main`. The owner approved the [M2 plan](#m2-plan) on 2026-10-17. Wave W0 (the feature registry) and the Dco trial of W1 are done |
| Previous | Phase 0 of M2 (the design sync): pull request #3 merged into `main` on 2026-10-17 (merge commit `b6fd215`; CI on `main` green, run [39022269403](https://github.com/KEREM-BAS/Ferman/actions/runs/39022269403)). M1 approved on 2026-10-16 (pull request #2, `aa7ad21`); M0 on 2026-10-15 (pull request #1, `fe99894`) |
| Next | The rest of wave W1: the fuzz and corpus workspaces, the corpus, the render thread with tiles, and the open path. The Dco codec is in use and met the target on the owner's Mac; its R1 and R2 run is an owner check. [Q21](QUESTIONS.md#q21) and strace are asked before anything relies on them |
| Application code | in `main` since the M1 merge: phases A to F (the app skeleton, the Rust workspace, `tools/checks`, the tool packages, fonts, icons and tokens, the bridge and PDFium bundling, the theme layer and the S6 checks), phase G (the component library: four groups, each reviewed and fixed, and the spec walker), phases H1 to H5 (Ferman's own title bar, the shell, the shortcut table), phases I1 to I4 (the settings store, first run, the start screen, the settings skeleton), phase H6 (narrow windows), phases J1 and J2 (Turkish complete and Arabic for every M1 string, pending native review; the localization tests), phase K (the golden matrix and its comparison with the design references) and the first part of phase L (the CI checks, component and screen tests, the component goldens, the spec walker and the `Fm*` names) |
| Questions | 21 entries: Q01 to Q20 answered (the last ones on 2026-10-16, as proposed, with the release files for macOS, Windows and Linux on GitHub Releases, [Q15](QUESTIONS.md#q15)); [Q21](QUESTIONS.md#q21) (memory-mapping files over 256 MB) open since 2026-10-17; see [QUESTIONS.md](QUESTIONS.md#summary) |
| Proposed ADRs | none waiting. 0020 (test corpus) and 0021 (opening files from the OS), and the details the M2 plan adds to 0008, 0009 and 0010, were approved with the [M2 plan](#m2-plan) on 2026-10-17. The crash-log placeholders of 0010 and the 640 px canvas minimum ([G95](DESIGN_GAPS.md#g95)) were approved on 2026-10-17; 0009 and 0018, the Proposed details in 0003, 0004, 0006, 0008 and 0019, and the reading of "GPL-compatible" in 0016 on 2026-10-16 (see [ADR status](#adr-status)) |
| Design gaps | 111 recorded: 89 Decided, 0 Needs owner, 22 Resolved (G62 to G99 found in M1; the last Needs owner entries decided on 2026-10-16; on 2026-10-17 export `519d42a` resolved 22 entries and settled five in part, and G100 to G111 were found while planning M2) |
| Backlog | 106 open and 2 done: B001 to B005 from the casing and region-format work, B006 and B007 from the bridge and bundling work, B008 and B009 from the title bars, B010 to B017 from the component library, B018 to B092 from the shell, first run, the start screen and Settings, B093 to B096 from narrow windows, B097 and B098 from the golden comparison, B099 and B100 from closing M1, B101 to B106 from the M2 plan (Proposed with it), B107 and B108 from the app icons; B003 (parsing region numbers) and B013 (narrow windows) shipped in M1 |
| Owner actions | 1 open (see [Owner actions](#owner-actions)) |
| Last updated | 2026-10-19 |

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
6. the Dco codec; 7. the API; 8. the app's engine services; 9. the viewer; 10. the sidebar;
11. text; 12. search; 13. open; 14. start and recent files; 15. documents and properties;
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
([G104](DESIGN_GAPS.md#g104)); the M2 performance budgets.

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
| 2026-10-16 | M1 | The owner asked for the translation review table in the repository. [TRANSLATION_REVIEW.md](TRANSLATION_REVIEW.md) holds every message in English, Turkish and Arabic with the note for translators, how to review and how to send corrections; the table is generated from the ARB files by `dart run l10n:review_table` (`tools/l10n`), and CI fails when it is stale. The column that said where each translation came from is not carried over: it needed scratch data from phase J1 and was incomplete for the strings of phases F to I. `design/` unchanged. | the head of this push |
| 2026-10-16 | M1 | The owner set two working rules: at most 15 to 20 commits per pull request from M2 on, pushed in checked batches, and a plain message when a pull request is ready to merge (CLAUDE.md "How to work", ROADMAP §3.1 and E7, the owner decisions above). `design/` unchanged. | the head of this push |
| 2026-10-16 | M2 prep | The owner merged M1 (pull request #2, `aa7ad21`) and answered every open question as proposed, with the release files for macOS, Windows and Linux on GitHub Releases (Q15), and approved every item under Still Proposed in M1. QUESTIONS.md has all 20 entries answered; the 12 Needs owner entries of DESIGN_GAPS.md are Decided (G01 to G03, G25, G26, G33, G36, G51 to G53, G56, G60); ADRs 0009 and 0018 are Accepted, with the Proposed details of 0003, 0004, 0006, 0008 and 0019 and the reading of "GPL-compatible" in 0016; CLAUDE.md, ROADMAP's M1 status and this file follow. At the owner's request this pass changed only the answers and their status lines: the other mentions in ROADMAP, ARCHITECTURE, DEPENDENCIES, DESIGN_INVENTORY, BACKLOG, the body text of ADRs 0015 and 0017, CONTRIBUTING, SECURITY and the rules files follow in the M2 planning pass, after the owner adds a corrected design export. On the branch `m2-open-and-view`. `design/` unchanged. | the head of this push |
| 2026-10-17 | M2 phase 0 | The owner approved the crash-log placeholders of ADR 0010 and the 640 px canvas minimum (G95), pushed a corrected design export to `main` (`519d42a`: 253 boards, 30 new, of which five are M1 builds, 15 are for M2 including the region-format table `a12-0` and 10 are for M3; 29 carry an EN/TR/AR switch) and chose a small design-sync pull request before M2: pull request #3. `main` merged in with a sign-off. CI on `main`, red since the export, fixed: two moved design lines in the component spec, the 253 boards with two special captures (`a12-0` as the element, `a2-3m` as the box around its six sidebars), and the `design/` check on pushes, which had flagged the owner's own export. `tools/design-refs` renders the 58 Turkish and Arabic variants and has the sets `@m1`, `@m2` and `@langs`; a full `--twice` render of all 312 PNGs was identical; the comparison pairs moved to the M1 build boards in three languages. The app matched to the new boards: the free step's 6 px tile padding (a two-line Turkish tile is 50 px, as the board measures) and its accessible name, two Turkish strings, and a1-2b's settings link (body-strong, a trailing arrow mirrored right to left); 12 goldens regenerated, 1983 tests pass. The 17th repository check, `dco_signoff`. The documents: an agent workflow (one writer and one adversarial reviewer per group, 47 review findings fixed) synced the inventory, the roadmap and the design gaps (22 resolved, five in part, G100 to G111 new) and swept the approvals through ARCHITECTURE, DEPENDENCIES, BACKLOG (B101 to B106), ADRs 0004, 0008, 0009, 0010, 0015 and 0017, CONTRIBUTING, SECURITY, the rules files and code comments; the six approved M1 boxes are ticked. The M2 plan above, Proposed ADRs 0020 and 0021, and Q21 (memory-mapping) added. CI green on three systems at `70b1ea2`. `design/` unchanged by this work. | `e6e6200` to the head of this push |
| 2026-10-17 | M2 | The owner approved the M2 plan (the go-ahead for M2) and chose to continue M2 in a Claude Code session on their own computer. Recorded: the plan approved, with every decision it marks Proposed except the items still Proposed at the M2 review, Q21 and strace; ADRs 0020 and 0021 Accepted; the plan's details in ADRs 0008, 0009 and 0010 approved. Pull request #3 waits only on the owner's merge. | the head of this push |
| 2026-10-19 | M2 | Pull request #3 was merged as `b6fd215`, and CI on `main` was green (run [39022269403](https://github.com/KEREM-BAS/Ferman/actions/runs/39022269403)). The branch `m2-open-and-view` was opened again from `origin/main` (the local copy, fully merged into it, deleted first) and pushed; GitHub opens no pull request for a branch without commits, so draft pull request #4 followed the first commit. Wave W0: the feature registry, the `Feature` enum in `app/lib/app/feature_registry.dart` with 68 values, the features that are visible but do not work yet, each naming its open BACKLOG row, and `tools/checks` `feature_registry`, the 18th repository check (a value without an open row, a value whose row is under Done, a value that names no control, and the future-version reason passed without the registry all fail). Every control disabled for a future version takes its reason from its value; the Comment row's Measure follows Measure (B051), the other tools Comments (B050); the default-app button follows each system's own row (B080, B101, B102); a first-run tile takes every feature it covers ("Edit text and images": B041 and B043). An adversarial review of the first version found no change in behaviour or in the goldens and 7 problems, all fixed before the push: an `available` flag could enable controls without their handlers or leave them disabled without a reason, so a feature now ships by leaving the registry; the drop zone's shared reason (recorded, B010); per-tile feature sets (G12); a reviewed list instead of every component file; fenced blocks and rows both open and under Done in the BACKLOG parser; gallery uses no longer count as controls; stale line citations in BACKLOG and DESIGN_GAPS. The title bar's Settings button now always has its callback. Checked on the owner's Mac (MacBook Pro, Apple M5 Pro, macOS 26.5): both analyzers clean, the Flutter tests with the goldens excluded (goldens run on the Linux CI runner), the `tools/checks` tests, and all 18 repository checks pass. The owner's local CocoaPods changes in `app/macos/` are left uncommitted. `design/` unchanged. Then the Dco trial of W1, the critical path ([Q19](QUESTIONS.md#q19) option a), in a scratch worktree first: `full_dep: true` with ffigen 20.1.1 generated bindings that `flutter analyze` passed only because it leaves `lib/bridge/` out; analyzed on their own, they showed the M1 clash. Its cause was the codegen's cbindgen pass, which read the facade's public `API_VERSION` and declared the facade's `ApiVersion` as an opaque C struct; `cbindgen:ignore` on the facade module fixes it without renaming anything. Measured in profile builds on the owner's Mac: 1 MiB in 26 µs at the minimum and 73 µs at the median with Dco, against 665 µs and 1,053 µs with SSE (debug, Dco: 5,932 µs). The app builds for macOS and the web, the integration test passes in debug and profile, clippy, the Rust tests, the Dart licence check (111 packages) and all 18 checks pass; the CI codegen job installs `libclang-dev`, which `llvm_path` names. ADR 0009, Q19, ARCHITECTURE §3.1 and §3.4, DEPENDENCIES (ffigen, libclang), CONTRIBUTING, CLAUDE.md and the rules files record it. | the head of this push |
| 2026-10-19 | M2 | Pull request #4 was merged. On the owner's MacBook Pro, `flutter run -d macos` first needed PDFium (`tools/pdfium/fetch.sh --platform mac-univ`), then crashed in Impeller about 15 s after launch (`impeller::Canvas::SetupRenderPass`, "The texture and its descriptor disagree about its size"). This is the open Flutter bug [flutter/flutter#185394](https://github.com/flutter/flutter/issues/185394); its fix, [flutter/flutter#192522](https://github.com/flutter/flutter/pull/192522), is still in review. With `--no-enable-impeller` (Skia) the app opens and draws; the owner keeps that as a local flag, not a repository setting, until a Flutter update carries the fix. The owner added a logo export to `design/` (`94e596d`: the board `Ferman Logo.dc.html` and `design/assets/logo/`, direction 1a "Mühür"). New `tools/app-icons` draws from it the macOS, Windows, Linux and web icons ([G112](DESIGN_GAPS.md#g112)); the Linux runner now sets its window icon, and the web favicon follows the browser's theme. iOS and Android icons (B107) and the macOS dark and tinted icons (B108) wait for their projects and the release pipeline. Checked on the owner's Mac: the tool's tests, `--check`, the macOS debug build (the new icon in `AppIcon.icns`) and the web release build with the bundle scan. The Linux runner change is checked by CI. | `94e596d` (the logo export, on `main`); the icons on the branch `app-icons` |
