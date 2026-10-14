---
paths:
  - "app/**/*"
  - "tools/tokens/**/*"
  - "tools/design-refs/**/*"
---

# Flutter rules

These rules apply to the Flutter app, the token generator and the design-reference renderer. Everything in [CLAUDE.md](../../CLAUDE.md) still applies. Background: [brief §6](../../docs/BRIEF.md#6-flutter-conventions), [ARCHITECTURE.md §2.5](../../docs/ARCHITECTURE.md#25-flutter-app-layout) and [ADR 0011](../../docs/adr/0011-flutter-state-navigation-components.md).

## Toolchain and packages

- Flutter 3.47.7 with Dart 3.13.5. Node 24 LTS only for `tools/design-refs`.
- State: flutter_riverpod 3.4, riverpod_annotation 4 and riverpod_generator 4, run by build_runner. Providers use `@riverpod`.
- Lints: very_good_analysis 11 plus riverpod_lint 3.1.9 as an analyzer plugin under `plugins:` in `analysis_options.yaml`. Do not add custom_lint.
- Navigation: go_router 18. Modes, document tabs and sidebar tabs are state, not routes.
- Goldens: alchemist. Do not use golden_toolkit (discontinued).
- Desktop and assets: window_manager, desktop_drop, file_selector, flutter_svg. Localization: intl and flutter_localizations.
- flutter_rust_bridge 2.13.0, the same version as the Rust crate and the codegen.
- No GetX in any form. No networking, font-downloading (google_fonts), analytics or crash-reporting packages.
- Every new package goes into [DEPENDENCIES.md](../../docs/DEPENDENCIES.md) with its licence and passes `very_good packages check licenses`.

## Engine boundary

- The UI never touches PDF internals. It calls only ferman-api through flutter_rust_bridge.
- Feature code reaches the engine only through the services and providers in `app/lib/engine/`. Widgets never import `app/lib/bridge/`.
- No synchronous engine calls on the build path (only `api_version()` is sync). Rendering and heavy work never run on the UI isolate.
- Generated files (`app/lib/bridge/`, `tokens.g.dart`, `*.g.dart`) are never edited by hand.

## Design fidelity

- Every screen matches its artboard in layout, spacing, typography, colour, icons, states and copy. Record any conflict or gap in [DESIGN_GAPS.md](../../docs/DESIGN_GAPS.md) and follow the option chosen there.
- Design copy that must change in the app: the licence is Apache-2.0, not GPL-3.0 ([G13](../../docs/DESIGN_GAPS.md#g13)); onboarding lists all four network uses ([G24](../../docs/DESIGN_GAPS.md#g24)); later-phase features are never marked "Included" ([G12](../../docs/DESIGN_GAPS.md#g12)).

## Brief §6 conventions

- **State and navigation:** Riverpod with code generation; go_router.
- **Design tokens:** `tools/tokens` reads the tokens in `design/` (`tokens/*.css` plus `ds-additions/fm-additions.css`, [G05](../../docs/DESIGN_GAPS.md#g05)) and generates `app/lib/design/tokens.g.dart`, exposed through a `ThemeExtension` ([ADR 0012](../../docs/adr/0012-design-token-pipeline.md)). Widgets read tokens only through that ThemeExtension. Never hardcode colours, sizes, radii or durations in widgets.
- **Component library first:** before building screens, build the Ferman component library in `app/lib/design/components/`. It mirrors the design system 1:1: the same names, variants and states. Screens are built from it.
- **Dialogs and popups:** custom popup-style widgets from the design system. Never the default Material or Cupertino dialog implementations (`showDialog`, `AlertDialog`, `showCupertinoDialog`, `showModalBottomSheet`, `showDatePicker`, `SnackBar`, Material `Tooltip`, `PopupMenuButton`). No GetX.
- **File pickers:** OS-native open, save and folder pickers through file_selector are the only proposed exception ([ADR 0018](../../docs/adr/0018-native-file-pickers.md), Proposed, [Q07](../../docs/QUESTIONS.md#q07)). Until the owner answers, M1 builds no picker and features that need one stay disabled with "Available in a future version". If M2 starts before an answer, the OS-native picker is used as the safest option ([brief §9](../../docs/BRIEF.md#9-how-to-work-in-every-later-session)) and flagged again in the M2 summary. All picker calls go through one `FilePickerService` with a fake for tests.
- **Tabs:** never `TabBarView`. Mode tabs and sidebar tabs are custom segmented controls over an `IndexedStack`, which preserves their state. There are eight mode tabs: View, Edit, Comment, Fill & Sign, Organize, Convert, Protect, Tools ([G09](../../docs/DESIGN_GAPS.md#g09), [Q05](../../docs/QUESTIONS.md#q05)).
- **Form validators** return `bool` and explicitly check null and empty values.
- **Localization:** gen-l10n with ARB files in `app/lib/l10n/`. English (`app_en.arb`) is the source and Turkish (`app_tr.arb`) is complete. Every user-facing string lives in the ARB files. Other languages fall back to English until translated. Never machine-translate silently; prepare for community translation through Weblate.
- **Casing:** Dart's `toUpperCase` is not locale-aware. Use the locale-aware casing utility in `app/lib/l10n/`, so Turkish shows "İMZALA".
- **Formats:** locale-aware dates, numbers ("10,5 pt"), paper sizes and units, taken from the region setting, not the UI language ([G34](../../docs/DESIGN_GAPS.md#g34)).
- **Right to left:** `EdgeInsetsDirectional` and `AlignmentDirectional` everywhere. Mirror directional icons. Never mirror the PDF canvas.
- **Desktop:** custom title bars for macOS and Windows as designed (window_manager). Linux chrome is open ([G15](../../docs/DESIGN_GAPS.md#g15), [Q12](../../docs/QUESTIONS.md#q12)). Full keyboard shortcuts through Shortcuts and Actions, shown in tooltips and menus. Focus traversal in reading order. Semantics labels on every control.
- **Android 12+ splash** (mobile phase): use `background_image`.
- **Unfinished features:** features not implemented yet stay visible exactly as designed but disabled, with the tooltip "Available in a future version" and an entry in [BACKLOG.md](../../docs/BACKLOG.md).

## Fonts and icons

- Bundle IBM's unmodified static Plex TTFs in `app/assets/fonts/` with their OFL-1.1 licence files: Plex Sans 400/500/600, Plex Serif, Plex Mono, Plex Sans Arabic, and Plex Sans Hebrew and Devanagari if approved ([Q08](../../docs/QUESTIONS.md#q08)). Never subset, rename or modify them (Reserved Font Name "Plex").
- CJK falls back to system fonts ([ADR 0013](../../docs/adr/0013-fonts-and-icons.md)). Set the text locale on text styles so Han characters take the right regional forms.
- Never use the design's woff2 subsets or its runtime Google Fonts import. The app never fetches fonts.
- Icons are SVG assets generated from the design's exact path data (229 icons), drawn at 1.5 px stroke, with the Lucide ISC and Feather MIT notices and a provenance table. Every licence text appears through Flutter's LicenseRegistry.

## Tests

- `flutter analyze` is clean. Widget tests for every component and screen.
- alchemist goldens for every implemented screen in light and dark × en, tr and ar, with the real bundled fonts loaded. Goldens are generated on the Linux CI runner only.
- Compare goldens against the artboard renders in `build/design-refs/` (made by `tools/design-refs`). Never commit `build/design-refs/` or golden failure output.
- `tools/design-refs` runs offline with vendored runtime scripts and blocks every other network request. It reads `design/` and never writes to it.
- `tools/tokens` has its own tests (`dart test`) for value mapping, environments and `var()` resolution.
