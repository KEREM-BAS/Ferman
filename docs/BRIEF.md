# Ferman — engineering brief for Claude Code

You are the lead engineer of Ferman. Read this entire brief before doing anything. Then do ONLY Milestone 0 (section 8) and stop.

## 1. Product
Ferman is a free, fully open-source PDF editor whose goal is to match and exceed Adobe Acrobat.
- Core promise: click any text in any PDF and edit it like a Word document. Nothing is locked behind a paywall. No account, no telemetry; documents never leave the device.
- Users: lawyers, accountants, students, office and public-sector staff working for hours. The UI must be calm, precise and fast; the document is always the hero.
- Platforms in strict priority order: (1) desktop: macOS and Windows (Linux best effort), (2) web, (3) iOS, Android and tablets. One codebase.
- Languages: English (source), Turkish, German, French, Spanish, Portuguese (BR), Italian, Dutch, Polish, Russian, Ukrainian, Arabic, Persian, Hebrew, Hindi, Japanese, Korean, Simplified Chinese, Traditional Chinese, Indonesian, Vietnamese. Full right-to-left support for Arabic, Persian and Hebrew.
- Licence: Apache-2.0.

## 2. The design is the source of truth: design/
design/ contains the complete Claude Design export: the Ferman Design System (tokens, components, fonts, icons) and every product screen (desktop macOS + Windows, light/dark, localization, web, tablet, iOS, Android, key user flows), e.g. design/ui_kits/desktop/index.html.
- Read-only. Never edit, move or delete anything in design/, and never ship its HTML/JS in the app. It is a reference, not code to reuse.
- Visuals (layout, spacing, typography, colour, icons, states, copy) must match the corresponding artboard. Behaviour follows this brief. Record every conflict or gap in docs/DESIGN_GAPS.md, choose the most reasonable option and keep going.
- Render every artboard to PNG with Playwright into build/design-refs/ (gitignored) and compare your Flutter screens against them.
- Fonts and icons come from the design (IBM Plex families, Lucide icons). Verify their licences (OFL / ISC) and bundle them in app/assets with their licence files. For scripts the bundled fonts don't cover (e.g. CJK), fall back to system fonts; record this in an ADR.

## 3. Architecture (fixed decisions; change only through an ADR that I approve)
Rust engine + one Flutter UI, connected with flutter_rust_bridge v2.

```text
ferman/
├── design/            # Claude Design export (read-only)
├── crates/
│   ├── ferman-core/   # document model, parsing/writing (lopdf), content-stream interpreter, incremental save
│   ├── ferman-render/ # page rendering with pdfium-render, tiles, thumbnails, caches
│   ├── ferman-text/   # text layout model: glyphs → words → lines → paragraphs/columns; hit testing; editing; reflow
│   ├── ferman-fonts/  # font parsing (skrifa/read-fonts), shaping (rustybuzz), subsetting (subsetter), system fonts (fontdb), coverage and substitution
│   ├── ferman-ops/    # organize pages, annotations, forms, watermark, redaction, compress… (split into more crates as it grows)
│   ├── ferman-api/    # the ONLY crate the UI calls (flutter_rust_bridge surface)
│   └── ferman-cli/    # `ferman` CLI exposing the same operations (testing and power users)
├── app/               # Flutter app: macos, windows, linux, web now; ios, android later
├── tools/             # token generator, design-reference renderer, corpus scripts
├── tests/corpus/      # test PDFs + README with provenance
├── docs/              # BRIEF, ARCHITECTURE, ROADMAP, PROGRESS, DESIGN_INVENTORY, DESIGN_GAPS, DEPENDENCIES, QUESTIONS, BACKLOG, adr/
└── .github/workflows/
```

Engine rules:
- The UI never touches PDF internals. ferman-api exposes: open/close documents, page info, tile rendering, text blocks, edit transactions (begin/apply/commit/rollback, which give engine-level undo/redo), and jobs (OCR, convert, compress, batch) that are async, cancellable and stream progress.
- Rendering and heavy work never run on the UI thread. Tile-based rendering for deep zoom; thumbnail and glyph caches.
- File safety: never corrupt a user's file. Save via temp file + atomic rename; incremental update by default; optional "optimize and clean" full rewrite; autosave/recovery files in the app data directory.
- Privacy: no telemetry. Network is used only for: update check (can be disabled), optional language-pack downloads, optional AI (local model or the user's own key), signature timestamp servers. List all of them in Settings → Privacy.
- Dependencies: permissive or GPL-compatible licences only. Never AGPL or non-commercial (no MuPDF, no Ghostscript). Enforce with cargo-deny and list every dependency with its licence in docs/DEPENDENCIES.md.
- PDFium: pdfium-render with prebuilt PDFium binaries (bblanchon/pdfium-binaries) bundled per platform.
- Later phases (verify each before use): ocrs (OCR), RustCrypto cms + cryptoki/PKCS#11 (digital signatures, Turkish e-imza), krilla (PDF/A, tagging).

## 4. The hardest part: editing existing text (must be flawless)
- Content-stream interpreter with full graphics and text state (q/Q, cm, BT/ET, Tf, Tm, Td, TD, T*, TL, Tc, Tw, Tz, Ts, Tj, TJ, ', "), Form XObjects (recursive) and marked content.
- Fonts: Type1, TrueType, Type3, Type0/CID; encodings (Standard, WinAnsi, MacRoman, /Differences, Identity-H/V, CMaps); ToUnicode; widths (/Widths, /W, /DW).
- Text model: rebuild words, lines, paragraphs, alignment (left/right/center/justified) and columns from glyph runs.
- Editing rewrites only the operators of the edited block; every other byte of the page content stays identical. Text is re-encoded in the font's own encoding.
- Missing glyphs (e.g. ğ, ş, İ in a subset font): (1) use the embedded glyph if present; (2) if the same font is installed, take the glyph from it, re-subset and embed; (3) otherwise offer similar fonts exactly as the design shows. Never substitute silently.
- Overflow handling follows the design ("Extend block", "Tighten spacing slightly", "Keep and warn").
- Signed documents: warn before editing that the signature will become invalid.
- Acceptance test for every edit: render before and after with PDFium; the pixel difference outside the edited region must be exactly zero. Cover Turkish, Arabic (RTL shaping) and CJK cases.

## 5. Quality bar
- Rust: no unwrap/expect/panic in library code; thiserror errors; documented public APIs; cargo fmt; clippy -D warnings; unit and integration tests; cargo-fuzz targets for every parser.
- Flutter: very_good_analysis lints, flutter analyze clean, widget tests, golden tests for every implemented screen in light and dark and in en, tr, ar (load the real fonts in goldens).
- Test corpus: generated PDFs plus freely licensed real-world files (Word, Google Docs, LibreOffice, LaTeX, scanned, forms, signed, encrypted, damaged). Provenance in tests/corpus/README.md.
- Performance budgets (document them in ARCHITECTURE.md and measure): first page visible in under 1 s for a 500-page document; smooth 60 fps scrolling and zooming; edit-to-render under 100 ms.
- CI (GitHub Actions) on macOS, Windows and Linux: Rust fmt/clippy/test, cargo-deny, Flutter analyze/test, desktop build. CI must stay green.

## 6. Flutter conventions
- State management: Riverpod with code generation. Navigation: go_router.
- Design tokens: tools/tokens reads the tokens in design/ and generates app/lib/design/tokens.g.dart, exposed through ThemeExtension. Never hardcode colours, sizes, radii or durations in widgets.
- Before building screens, build a Ferman component library in app/lib/design/components that mirrors the design system 1:1 (same names, variants and states).
- Dialogs and popups: custom popup-style widgets from the design system; never default Material/Cupertino dialog implementations; no GetX.
- Tabs: never use TabBarView. Mode tabs and sidebar tabs are custom segmented controls with IndexedStack to preserve state.
- Form validators return bool and explicitly check null and empty values.
- Localization: gen-l10n with ARB files in app/lib/l10n. English is the source and Turkish is complete; other languages fall back to English until translated (never machine-translate silently; prepare for community translation via Weblate). Dart's toUpperCase is not locale-aware: implement locale-aware casing so Turkish shows "İMZALA". Locale-aware dates, numbers (10,5 pt), paper sizes and units.
- RTL: EdgeInsetsDirectional/AlignmentDirectional everywhere; mirror directional icons; never mirror the PDF canvas.
- Desktop: custom title bars for macOS and Windows as designed; full keyboard shortcuts via Shortcuts/Actions, shown in tooltips and menus; focus traversal; Semantics labels.
- Android 12+ splash (mobile phase): use background_image.
- Features not implemented yet stay visible exactly as designed but disabled, with the tooltip "Available in a future version" and an entry in docs/BACKLOG.md.

## 7. Roadmap (detail it in docs/ROADMAP.md with acceptance criteria per milestone)
- M0 Discovery and plan (docs only).
- M1 Foundations: workspace, Flutter app, bridge, token pipeline, component library, light/dark themes, l10n (en, tr, ar), app shell (title bar, document tabs, mode tabs, tool row, sidebars, canvas, right panel, status bar), start screen, settings skeleton, CI green.
- M2 Open and view: open (dialog, drag-and-drop, recent files, "open with"), password unlock, repair notice, rendering (tiles, zoom modes, continuous/spread/book), thumbnails, outline, attachments, search (diacritic-insensitive, İ/ı aware), document properties, multiple tabs.
- M3 Edit text core (section 4), save/save as, undo/redo, edit review list.
- M4 Rest of phase 1: organize pages, combine/split, comments and annotations, form filling, simple signatures, compress, version history, command palette, toasts, background tasks, full settings.
- M5 Release pipeline: notarized macOS DMG, signed Windows installer, GitHub Releases, auto-update, Homebrew and winget manifests.
- Phase 2: add text/images, find and replace, watermark/header/footer/Bates, redaction with verification, remove hidden information.
- Phase 3: OCR, PDF ↔ Office conversion, certificate signatures, Turkish e-imza (PKCS#11), signature validation, compare.
- Phase 4: form authoring, PDF/A and preflight, accessibility (PDF/UA) tools, batch actions, in-place translation, local AI assistant.
- Phase 5: print production, plugin system, then the web build, then tablet and mobile apps (iOS, Android) from the same Flutter code.

## 8. Milestone 0 — do this now, then stop
1. Save this brief verbatim as docs/BRIEF.md.
2. Inventory design/: every artboard, component, token, icon and font. Write docs/DESIGN_INVENTORY.md mapping each screen → feature → milestone → engine capability needed. Flag missing screens and states.
3. Write docs/ARCHITECTURE.md (crates, API boundary, threading, data flow, file safety, error handling, testing strategy, performance budgets) and ADRs in docs/adr/ for the main decisions.
4. Write docs/ROADMAP.md, docs/PROGRESS.md (milestone checklist + session log), docs/DEPENDENCIES.md, and empty docs/DESIGN_GAPS.md, docs/QUESTIONS.md, docs/BACKLOG.md.
5. Write CLAUDE.md (under 200 lines): what Ferman is, repo map, commands, the non-negotiable rules from this brief, definition of done, and "start every session by reading docs/PROGRESS.md". Put Rust-only rules in .claude/rules/rust.md (frontmatter paths: crates/**) and Flutter-only rules in .claude/rules/flutter.md (frontmatter paths: app/**).
6. Add README.md, LICENSE (Apache-2.0), CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md and .gitignore.
7. Commit and push. Then give me a short summary and your questions (at least: bundle identifier, publisher name for code signing, minimum macOS/Windows versions). Do not write application code until I approve M0.

## 9. How to work in every later session
- Start by reading CLAUDE.md, docs/PROGRESS.md and the relevant part of docs/BRIEF.md.
- One milestone at a time: plan it in PROGRESS.md, implement, test, update docs, commit in small Conventional Commits, push, then stop with a summary.
- Definition of done: matches the design artboards (light/dark, en/tr/ar where relevant), tests added and passing, CI green, PROGRESS.md updated, nothing silently skipped (log it in BACKLOG.md).
- Ask me before: changing an architectural decision, adding a dependency with an unusual licence, touching design/, or deleting work you didn't create. Otherwise work autonomously; put open questions in QUESTIONS.md and continue with the safest option.
