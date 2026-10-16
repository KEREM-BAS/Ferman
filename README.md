# Ferman

A free, open-source PDF editor. Click any text in any PDF and edit it like a Word document.

## Status

**Pre-alpha. Milestone 1: foundations, complete and waiting for the maintainer's approval.**

The maintainer approved the plan (Milestone 0) on 2026-10-15. Milestone 1 built the foundations: the
Rust workspace and engine facade, the Flutter app with its shell in eight modes, first run, the start
screen and a settings skeleton, the bridge between them with PDFium bundled, the design tokens, fonts,
icons and component library, English, Turkish and Arabic with right to left, and CI on macOS, Windows
and Linux. There is nothing to download yet, and the app opens no PDFs until Milestone 2.
[docs/PROGRESS.md](docs/PROGRESS.md) shows where the work stands, and
[CONTRIBUTING.md](CONTRIBUTING.md#development-setup) how to build and run it.

## What Ferman will be

- **Edit text in place.** Click any text in any PDF and edit it like a Word document. Only the block
  you edit changes. The rest of the page stays exactly as it was.
- **Free.** Nothing is locked behind a paywall.
- **Private.** No account and no telemetry. Your documents never leave your device. The one exception
  is the optional AI assistant: if you turn it on with your own key for an online provider, only your
  question and the parts of the open document needed to answer it go to that provider, and Ferman
  says so before anything is sent. A local model sends nothing.
- **Safe with your files.** Ferman saves through a temporary file and an atomic rename, and adds
  changes as an incremental update by default. A failed save never damages the original.
- **Calm and fast.** Built for people who work with documents for hours: lawyers, accountants,
  students, office and public-sector staff. The document is always the focus.

The long-term goal is to match and then exceed Adobe Acrobat.

Ferman uses the network for four things only, each listed in Settings → Privacy:

1. the update check, which you can turn off;
2. optional language-pack downloads;
3. the optional AI assistant, with a local model or your own key;
4. signature timestamp servers, only when you sign with a timestamp.

## Platforms

In priority order, from one codebase:

1. Desktop: macOS and Windows first, Linux on a best-effort basis.
2. Web.
3. iOS, Android and tablets.

Minimum operating systems: macOS 12 or later (universal), Windows 10 22H2 and Windows 11 (x64,
arm64), and Linux on a best-effort basis from Ubuntu 22.04 ([Q03](docs/QUESTIONS.md#q03)). Linux
packaging formats ([Q12](docs/QUESTIONS.md#q12)) are decided before the first release.

## Languages

Ferman is planned in 21 languages: English, Turkish, German, French, Spanish, Portuguese (Brazil),
Italian, Dutch, Polish, Russian, Ukrainian, Arabic, Persian, Hebrew, Hindi, Japanese, Korean,
Simplified Chinese, Traditional Chinese, Indonesian and Vietnamese.

- English is the source language. Turkish is always complete.
- Other languages fall back to English until volunteers translate them. Nothing is machine-translated
  silently.
- Arabic, Persian and Hebrew get full right-to-left support. The interface mirrors; the PDF page never
  does.
- Casing follows the language, so Turkish shows "İMZALA". Numbers, dates, paper sizes and units
  follow the region, so a Turkish region shows "10,5 pt".

## How it is built

Ferman is a Rust engine with one Flutter UI on top, connected by
[flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) v2. The engine owns every byte
of every PDF. [lopdf](https://github.com/J-F-Liu/lopdf) is the document model and the source of
truth for parsing, editing and saving. [PDFium](https://pdfium.googlesource.com/pdfium/), through
pdfium-render and prebuilt binaries bundled per platform, only turns pages into pixels and never
writes a file. The UI calls a single crate, `ferman-api`, and never sees PDF internals. Rendering and
heavy work never run on the UI thread. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) describes the
design, and the [architecture decision records](docs/adr/README.md) explain why.

## Repository layout

Milestone 1 added the engine, app, tools and CI folders; `fuzz/` arrives in Milestone 2.

```text
ferman/
├── design/              the design export: design system and every product screen (read-only)
├── crates/
│   ├── ferman-core/     document model, parsing and writing (lopdf), content-stream interpreter,
│   │                    incremental save
│   ├── ferman-render/   page rendering with pdfium-render, tiles, thumbnails, caches
│   ├── ferman-text/     glyphs → words → lines → paragraphs and columns; hit testing; editing; reflow
│   ├── ferman-fonts/    font parsing, shaping, subsetting, system fonts, coverage and substitution
│   ├── ferman-ops/      organize pages, annotations, forms, watermark, redaction, compress
│   ├── ferman-api/      the only crate the UI calls
│   └── ferman-cli/      the `ferman` command line, with the same operations
├── app/                 Flutter app: macOS, Windows, Linux and web now; iOS and Android later
├── tools/               token generator, icon export, localization fallback generator, font and
│                        PDFium fetch scripts, design-reference renderer and comparison,
│                        repository checks and the build scanner
├── tests/corpus/        test PDFs, with their provenance in tests/corpus/README.md
├── fuzz/                cargo-fuzz targets, one per parser (from Milestone 2)
├── docs/                brief, architecture, ADRs, roadmap, progress, inventory, component spec,
│                        gaps, dependencies, questions, backlog, translation review
├── .github/workflows/   CI on macOS, Windows and Linux
├── .claude/rules/       path-scoped working rules for the Rust and Flutter code
├── build/               local output such as design-reference renders (never committed)
├── CLAUDE.md            working rules and commands for every coding session
└── README.md  LICENSE  THIRD_PARTY_NOTICES.md  CONTRIBUTING.md  CODE_OF_CONDUCT.md  SECURITY.md  .gitignore
```

`design/` is the visual source of truth. Nobody edits it, and the app never ships or loads its HTML,
JavaScript or font files.

## Documentation

| Document | What it holds |
|---|---|
| [docs/BRIEF.md](docs/BRIEF.md) | The maintainer's brief. It is authoritative: when another document disagrees, the brief wins. |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Every milestone and phase, with scope and acceptance criteria |
| [docs/PROGRESS.md](docs/PROGRESS.md) | Milestone checklist, current status and session log |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Crates, API boundary, threading, data flow, file safety, errors, security, testing, performance budgets |
| [docs/adr/](docs/adr/README.md) | Architecture decision records and their status |
| [docs/DESIGN_INVENTORY.md](docs/DESIGN_INVENTORY.md) | Every artboard, component, token, icon and font, mapped to a feature, a milestone and an engine capability |
| [docs/COMPONENTS.md](docs/COMPONENTS.md) | The component spec: props, variants and states of every design-system component |
| [docs/DESIGN_GAPS.md](docs/DESIGN_GAPS.md) | Gaps and conflicts in the design, with the option chosen for each |
| [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) | Every dependency in use or planned and every bundled asset, with its licence |
| [docs/QUESTIONS.md](docs/QUESTIONS.md) | Open questions for the maintainer |
| [docs/BACKLOG.md](docs/BACKLOG.md) | Work that is disabled, deferred or skipped |
| [docs/TRANSLATION_REVIEW.md](docs/TRANSLATION_REVIEW.md) | Every UI string in English, Turkish and Arabic with the note for translators, for native-speaker review |
| [CLAUDE.md](CLAUDE.md) | The short version of the rules, the commands and the definition of done |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | How we treat each other |
| [SECURITY.md](SECURITY.md) | How to report a vulnerability |
| [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) | Licence texts for the third-party fonts and icons inside `design/` |

## Roadmap

| Code | Milestone | What it delivers |
|---|---|---|
| M0 | Discovery and plan | Design inventory, architecture and plans. Docs only. Done, approved on 2026-10-15. |
| M1 | Foundations | Workspace, Flutter app, bridge, design tokens, component library, light and dark themes, en/tr/ar, app shell, start screen, settings skeleton, green CI. Complete, waiting for the maintainer's approval. |
| M2 | Open and view | Open from the dialog, drag and drop, recent files and "Open with"; password unlock and repair notice; tiled rendering, zoom modes and page layouts; thumbnails, outline, attachments, search; document properties; several documents in tabs |
| M3 | Edit text core | Click any text and edit it; save and save as; undo and redo; a review list of edits |
| M4 | Rest of phase 1 | Organize pages, combine and split, comments and annotations, form filling, simple signatures, compress, version history, command palette, toasts, background tasks, full settings |
| M5 | Release pipeline | Notarized macOS DMG, signed Windows installer, GitHub Releases, auto-update, Homebrew and winget |
| P2 | Phase 2 | Add text and images, find and replace, watermark, header, footer and Bates numbers, redaction with verification, remove hidden information |
| P3 | Phase 3 | OCR, PDF ↔ Office conversion, certificate signatures, Turkish e-imza, signature validation, compare |
| P4 | Phase 4 | Form authoring, PDF/A and preflight, accessibility (PDF/UA) tools, batch actions, in-place translation, a local AI assistant |
| P5 | Phase 5 | Print production and plugins, then the web build, then tablet and mobile apps |

One milestone at a time. A feature that is not built yet stays visible as designed but disabled, with
the tooltip "Available in a future version". [docs/ROADMAP.md](docs/ROADMAP.md) has the details and
the acceptance criteria, and lists the proposed place of drawn features the roadmap does not name yet.

## Contributing

The foundations are still being laid, so the most useful help right now is reading the documents
and opening an issue when something is wrong, missing or unclear. Please read [CONTRIBUTING.md](CONTRIBUTING.md)
first. Everyone who takes part follows the [code of conduct](CODE_OF_CONDUCT.md).

Do not report security problems in public issues. [SECURITY.md](SECURITY.md) explains how to report
them privately.

## Licence

Ferman is licensed under the [Apache License 2.0](LICENSE). Contributions are accepted under the same
licence.

The app will bundle third-party components under their own licences: the IBM Plex fonts (SIL Open
Font License 1.1), icons based on Lucide (ISC licence; the icons derived from Feather are under the
MIT licence) and PDFium (BSD-3-Clause and Apache-2.0, plus the notices of the libraries inside it).
Their licence texts will ship with the app and appear on its licences screen.
[docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) lists every dependency and asset with its licence.
There is no app yet, so nothing is bundled yet.

The design export in `design/` contains IBM Plex font subsets (SIL Open Font License 1.1) and icon
path data from Lucide (ISC licence; icons derived from Feather are under the MIT licence). The export
ships no licence files ([G08](docs/DESIGN_GAPS.md#g08)) and is never edited, so
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) carries the full licence texts for this material.
The app ships its own licence files in `app/assets`: the unmodified IBM Plex fonts with their
OFL-1.1 texts, the Lucide licence files for the icons, and the PDFium notices.

Copyright The Ferman Authors ([Q14](docs/QUESTIONS.md#q14)).
