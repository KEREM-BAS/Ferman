# Ferman

Ferman is a free, fully open-source PDF editor whose goal is to match and exceed Adobe Acrobat. The core promise: click any text in any PDF and edit it like a Word document. Nothing is locked behind a paywall. There is no account and no telemetry, and documents never leave the device. Users are lawyers, accountants, students and office and public-sector staff who work for hours, so the UI is calm, precise and fast, and the document is always the hero. Platforms in strict order: desktop (macOS and Windows, Linux best effort), then web, then iOS, Android and tablets, all from one codebase: a Rust engine and one Flutter UI joined by flutter_rust_bridge v2. English is the source language and Turkish is complete; 19 more languages follow, with full right-to-left support for Arabic, Persian and Hebrew. Licence: Apache-2.0.

## Start here

Start every session by reading docs/PROGRESS.md.

Then read this file and the part of [docs/BRIEF.md](docs/BRIEF.md) that covers your task ([brief §9](docs/BRIEF.md#9-how-to-work-in-every-later-session)). The brief is authoritative. If any other doc disagrees with it, the brief wins and the doc gets fixed. [docs/PROGRESS.md](docs/PROGRESS.md) holds the current milestone, the next step and the session log.

The owner approved M0 on 2026-10-15 (pull request #1). M1 (foundations) is in progress; PROGRESS.md holds its plan. The next milestone waits for the owner's go-ahead.

## Repo map

```text
ferman/
├── design/                read-only design export, the visual source of truth (never edited, never shipped)
│   ├── *.dc.html          section boards (00 Fixes … 15 Flows, DS additions, Index), Fm*/Doc* building blocks
│   ├── _ds/…/             design system: tokens/*.css, components, assets, _ds_bundle.js
│   ├── ds-additions/      fm-additions.css (extra tokens and overrides), fm-icons.js (84 extra icons)
│   └── shots/             partial 924×540 JPEG previews from the design session (not a reference; compare against build/design-refs/)
├── docs/                  brief, architecture, ADRs, roadmap, progress, inventory, component spec, gaps, questions, backlog
├── .claude/rules/         path-scoped rules: rust.md, flutter.md
├── CLAUDE.md  README.md  LICENSE  THIRD_PARTY_NOTICES.md  CONTRIBUTING.md  CODE_OF_CONDUCT.md  SECURITY.md  .gitignore
├── Cargo.toml  Cargo.lock  rust-toolchain.toml  clippy.toml  deny.toml
│
│  Built during M1, phase by phase (app/ is committed, the rest is landing); fuzz/ comes in M2:
├── crates/                Rust workspace; all seven crates exist from M1
│   ├── ferman-core/       document model, parsing/writing (lopdf), content-stream interpreter, incremental save
│   ├── ferman-render/     page rendering with pdfium-render, tiles, thumbnails, caches
│   ├── ferman-text/       glyphs → words → lines → paragraphs/columns; hit testing; editing; reflow
│   ├── ferman-fonts/      font parsing, shaping, subsetting, system fonts, coverage and substitution
│   ├── ferman-ops/        organize pages, annotations, forms, watermark, redaction, compress…
│   ├── ferman-api/        the ONLY crate the UI calls (Rust facade + flutter_rust_bridge surface)
│   └── ferman-cli/        `ferman` CLI on the same facade
├── fuzz/                  (M2) cargo-fuzz workspace, one target per parser
├── app/                   Flutter app: macos, windows, linux, web now; ios, android later
├── tools/                 checks/, tokens/, icons/, fonts/, pdfium/, design-refs/ (M1); corpus/ (M2)
├── tests/corpus/          README.md with provenance (M1); test PDFs from M2
├── .github/workflows/     CI on macOS, Windows and Linux
└── build/                 gitignored output, including build/design-refs/
```

The brief cites `design/ui_kits/desktop/index.html`, which is missing from the export ([G01](docs/DESIGN_GAPS.md#g01)). Use the section boards, `FmWindow.dc.html` and `_ds_bundle.js` instead. [docs/DESIGN_INVENTORY.md](docs/DESIGN_INVENTORY.md) maps every board to a feature, milestone and engine capability.

## Commands

Commands marked "planned" arrive with their M1 step; the others work today. Phase L1 checks the list on a fresh clone.

```sh
# Rust
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo clippy -p ferman-api --features frb --all-targets -- -D warnings
cargo test --workspace
cargo deny check
cargo run -p ferman-cli -- --version            # ferman 0.1.0 (api 0.1); also: info --json

# Flutter (run both analyzers: riverpod_lint reports only through dart analyze)
(cd app && flutter analyze && dart analyze --fatal-infos && flutter test)
(cd app && dart run build_runner build --delete-conflicting-outputs)   # Riverpod and other codegen
flutter_rust_bridge_codegen generate                                  # bridge bindings (FRB 2.13.0; planned, step 3)
(cd app && very_good packages check licenses)                         # Dart licence check (flags: DEPENDENCIES.md §8)

# Tools
(cd tools/checks && dart run bin/check_all.dart --root ../..)   # repository checks CI runs
(cd tools/tokens && dart run)                 # design tokens → app/lib/design/tokens.g.dart (ADR 0012); CI: dart run tokens --check
(cd tools/icons && dart run)                  # icons → app/assets/icons, IconName, PROVENANCE.md (ADR 0013); CI: dart run icons --check
(cd tools/icons && dart run icons:component_spec)   # docs/COMPONENTS.md reference from app/test/design/component_spec.json
tools/fonts/fetch.sh --verify-committed && python3 -I tools/fonts/coverage.py   # font hashes and script coverage (offline)
tools/pdfium/fetch.sh [--platform <id> | --all] [--verify --check-licenses]     # pinned PDFium → build/pdfium/<id>/
(cd tools/design-refs && npm ci && npm test)
node tools/design-refs [--only @m1] [--twice]  # every board → build/design-refs/<id>.png, offline
```

Each tool's README has the full options and its self-tests. The renderer needs the Chromium 1194 headless shell: the development container has it in `/opt/pw-browsers`; on Linux x64 `tools/design-refs/fetch-chromium.sh` downloads it and prints the path for `--chromium`. Never use the Playwright installer: it also downloads an LGPL ffmpeg build.

Toolchain: Rust 1.99.0 (`rust-toolchain.toml`), Flutter 3.47.7 with Dart 3.13.5, Node 24.22.0 LTS and playwright-core 1.56.1 for the tools.

## Non-negotiable rules

**Design**
- `design/` is read-only: never edit, move or delete anything in it. Never ship its HTML or JS, and never load anything from it at run time. It is a reference, not code to reuse.
- Visuals (layout, spacing, typography, colour, icons, states, copy) match the corresponding artboard. Behaviour follows the brief.
- Record every conflict or gap in [docs/DESIGN_GAPS.md](docs/DESIGN_GAPS.md), choose the most reasonable option and keep going.
- Design copy that must change in the app: the licence is Apache-2.0, not GPL-3.0 (a1-2c, a11-5, [G13](docs/DESIGN_GAPS.md#g13)); onboarding lists all four network uses ([G24](docs/DESIGN_GAPS.md#g24)); later-phase features are never shown as "Included" ([G12](docs/DESIGN_GAPS.md#g12)).
- The shell has eight mode tabs, as every artboard shows and the owner confirmed: View, Edit, Comment, Fill & Sign, Organize, Convert, Protect, Tools ([G09](docs/DESIGN_GAPS.md#g09), [Q05](docs/QUESTIONS.md#q05)).
- Custom title bars on macOS, Windows and Linux; on Linux, client-side decorations with the caption buttons at the end ([G15](docs/DESIGN_GAPS.md#g15), [Q12](docs/QUESTIONS.md#q12)).

**Architecture**
- The decisions in [brief §3](docs/BRIEF.md#3-architecture-fixed-decisions-change-only-through-an-adr-that-i-approve) are fixed. Change them only through an ADR the owner approves. A Proposed ADR is not in force until approved (0009 threading, 0018 pickers). Nor are the details marked **Proposed:** inside Accepted (brief) ADRs. Accepted by the owner on 2026-10-15: 0007 (harfrust instead of rustybuzz) and the Plex Sans Hebrew and Devanagari part of 0013. [ADR 0018](docs/adr/0018-native-file-pickers.md) (native pickers) has its own interim rule: M1 builds no picker, and if M2 starts before the owner answers [Q07](docs/QUESTIONS.md#q07), the OS-native picker is used as the safest option and flagged again.
- The UI never touches PDF internals. It calls only `ferman-api`: open and close, page info, tile rendering, text blocks, edit transactions (begin/apply/commit/rollback, giving engine-level undo and redo) and jobs.
- lopdf is the document model and source of truth. PDFium (pdfium-render with prebuilt bblanchon/pdfium-binaries bundled per platform) is a read-only rasteriser, used only inside `ferman-render`.
- Rendering and heavy work never run on the UI thread. Tiles for deep zoom; thumbnail and glyph caches. Jobs (OCR, convert, compress, batch) are async, cancellable and stream progress.
- PDFs are untrusted input: resource limits and fuzzing. Document JavaScript is never executed (policy to confirm in [Q13](docs/QUESTIONS.md#q13)).

**File safety**
- Never corrupt a user's file. Save through a temp file and an atomic rename. Incremental update is the default; "optimize and clean" is an optional full rewrite. Autosave and recovery files live in the app data directory.

**Privacy**
- No telemetry, no analytics, no crash reporting service. Logs stay on the device.
- The network is used only for: the update check (can be disabled), optional language-pack downloads, optional AI (a local model or the user's own key), and signature timestamp servers. All of them are listed in Settings → Privacy.
- OCSP/CRL lookups and local-network discovery (a7-4) are drawn but not in the brief. They stay off until the owner decides ([Q06](docs/QUESTIONS.md#q06)).

**Dependencies**
- Permissive licences only. The brief's "permissive or GPL-compatible", applied to an Apache-2.0 product, rules out GPL (any version), LGPL as a sole licence and AGPL. MPL-2.0 is allowed only per package after owner review. Never non-commercial; no MuPDF, no Ghostscript. Enforced with cargo-deny and the Dart licence check ([ADR 0016](docs/adr/0016-dependency-licence-policy.md)).
- Three named licence exceptions are approved ([Q17](docs/QUESTIONS.md#q17), 2026-10-15): MPL-2.0 `dbus` through desktop_drop (from M2, unmodified, notice in every build, skipped by name in the pub check), NCSA `libfuzzer-sys` in `fuzz/` only, LGPL-3.0 Swatinem/rust-cache in CI only. They widen nothing else. The reading of "GPL-compatible" is still open, so the stricter reading above applies.
- Every dependency is listed with its licence in [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md), updated in the same change.

**Text editing** ([brief §4](docs/BRIEF.md#4-the-hardest-part-editing-existing-text-must-be-flawless))
- Editing rewrites only the operators of the edited block. Every other byte of the page content stays identical.
- Text is re-encoded in the font's own encoding.
- Acceptance test for every edit: render before and after with PDFium; the pixel difference outside the edited region is exactly zero. Cover Turkish, Arabic (RTL shaping) and CJK.
- Missing glyphs: (1) use the embedded glyph; (2) if the same font is installed, take the glyph, re-subset, embed, and say so; (3) otherwise offer similar fonts exactly as the design shows. Never substitute silently ([ADR 0006](docs/adr/0006-font-pipeline-and-missing-glyphs.md), [G36](docs/DESIGN_GAPS.md#g36)).
- Overflow offers the brief's three choices as a3-4 draws them: "Extend block by N line(s)", "Tighten spacing slightly (−x%)", "Keep and warn", with the amounts computed for the block.
- Signed documents: warn before editing that the signature will become invalid ([G35](docs/DESIGN_GAPS.md#g35)).

**Fonts and icons**
- Fonts are IBM Plex (Sans, Serif, Mono, Sans Arabic, Sans Hebrew and Sans Devanagari, [Q08](docs/QUESTIONS.md#q08)), bundled as IBM's unmodified static TTFs with their OFL-1.1 licence files in `app/assets`. The Reserved Font Name "Plex" is respected: never subset, rename or modify the files we ship. Embedding a subset into a user's PDF is document embedding, which OFL-1.1 allows. Scripts the bundled fonts don't cover (CJK) fall back to system fonts ([ADR 0013](docs/adr/0013-fonts-and-icons.md)). The design's woff2 subsets and its runtime Google Fonts import are never used.
- Icons use the design's exact path data (229 icons), painted by a `CustomPainter` through path_parsing, shipped with the Lucide ISC and Feather MIT notices and a provenance table. No flutter_svg: it and vector_graphics pull in `http`.

**Unfinished features**
- Features not implemented yet stay visible exactly as designed, disabled, with the tooltip "Available in a future version" and an entry in [docs/BACKLOG.md](docs/BACKLOG.md).

**Localization**
- English is the source; Turkish is complete. Other languages fall back to English until translated. Never machine-translate silently; community translation goes through Weblate.
- Casing is locale-aware (Turkish shows "İMZALA"). Numbers, dates, paper sizes and units follow the region setting ("10,5 pt").
- Right to left mirrors the UI, never the PDF canvas.

**Code**
- No `unwrap`, `expect` or `panic` in Rust library code.
- Generated files (`tokens.g.dart`, bridge bindings, `*.g.dart`) are never edited by hand.
- Never commit `build/design-refs/` or anything else under `build/`.
- CI (macOS, Windows, Linux) stays green. A red build is fixed before anything else.
- Every test PDF has its provenance in `tests/corpus/README.md`.

## Ask the owner before

- changing an architectural decision;
- adding a dependency with an unusual licence;
- touching `design/`;
- deleting work you didn't create.

Otherwise work autonomously. Put open questions in [docs/QUESTIONS.md](docs/QUESTIONS.md) and continue with the safest option.

## How to work

1. One milestone at a time. The next milestone waits for the owner's go-ahead.
2. Plan the milestone in [docs/PROGRESS.md](docs/PROGRESS.md) from its acceptance criteria in [docs/ROADMAP.md](docs/ROADMAP.md).
3. Implement and test in small steps. A new decision gets a Proposed ADR from [docs/adr/template.md](docs/adr/template.md).
4. Update the docs as you go: PROGRESS, ARCHITECTURE and ADRs, DEPENDENCIES, DESIGN_GAPS, QUESTIONS, BACKLOG and the commands in this file.
5. Commit in small Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `build:`, `ci:`, `chore:`) and push. Commits, pull request titles and pull request bodies carry no AI attribution: no `Co-Authored-By` or `Claude-Session` lines, no "Generated with" lines, and never an AI author. Author them as the owner: in a fresh clone, set the local `git config user.name` and `user.email` to the owner's identity from the earlier commits (`git log -1 --format='%an <%ae>' 7f3945b`). M1 work lives on the branch `m1-foundations`, with a draft pull request to `main` (opened once phase B is pushed) that the owner merges when M1 is done.
6. Stop with a short summary for the owner: what was done, what is disabled or deferred, open questions.

## Definition of done

From [brief §9](docs/BRIEF.md#9-how-to-work-in-every-later-session), plus the gates and exit checks in [ROADMAP §3](docs/ROADMAP.md#3-rules-for-every-milestone):

- Matches the design artboards (light and dark, en/tr/ar where relevant), checked against `build/design-refs/`.
- Tests added and passing: Rust unit and integration tests, pixel-diff tests for edits, fuzz targets for new parsers, widget tests, and goldens for every implemented screen in light and dark × en, tr, ar with the real fonts.
- CI green on macOS, Windows and Linux.
- Performance budgets that apply are measured ([ARCHITECTURE §14](docs/ARCHITECTURE.md#14-performance-budgets)).
- PROGRESS.md updated (checklist and session log); the docs describe what was built.
- Nothing silently skipped: every skipped, deferred or disabled item is in BACKLOG.md.

## Pointers

- [docs/BRIEF.md](docs/BRIEF.md): the owner's brief (authoritative)
- [docs/PROGRESS.md](docs/PROGRESS.md): milestone checklist and session log
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): crates, API boundary, threading, data flow, file safety, errors, testing, budgets
- [docs/ROADMAP.md](docs/ROADMAP.md): milestones with acceptance criteria
- [docs/DESIGN_INVENTORY.md](docs/DESIGN_INVENTORY.md): every board, component, token, icon and font
- [docs/COMPONENTS.md](docs/COMPONENTS.md): the component spec (props, variants, states) for the Flutter library
- [docs/DESIGN_GAPS.md](docs/DESIGN_GAPS.md): design gaps and conflicts with the option chosen
- [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md): every dependency and asset with its licence
- [docs/QUESTIONS.md](docs/QUESTIONS.md): open questions for the owner
- [docs/BACKLOG.md](docs/BACKLOG.md): disabled, deferred and skipped items
- [docs/adr/](docs/adr/README.md): architecture decision records

Rust-only rules load from [.claude/rules/rust.md](.claude/rules/rust.md) and Flutter-only rules from [.claude/rules/flutter.md](.claude/rules/flutter.md) when you work in those paths.
