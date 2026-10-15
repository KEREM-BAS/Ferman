# ADR 0011: Flutter state, navigation and components

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §6
- **Supersedes:** none
- **Superseded by:** none

## Context

The brief sets the Flutter conventions ([brief §6](../BRIEF.md)):

- State management: Riverpod with code generation. Navigation: go_router.
- Before building screens, build a Ferman component library in `app/lib/design/components` that mirrors
  the design system 1:1 (same names, variants and states).
- Dialogs and popups: custom popup-style widgets from the design system; never default Material or
  Cupertino dialog implementations; no GetX.
- Tabs: never TabBarView. Mode tabs and sidebar tabs are custom segmented controls with IndexedStack to
  preserve state.
- Form validators return bool and explicitly check null and empty values.
- Desktop: custom title bars, keyboard shortcuts through Shortcuts and Actions shown in tooltips and
  menus, focus traversal, Semantics labels.
- Features not implemented yet stay visible exactly as designed, disabled, with the tooltip "Available
  in a future version" and an entry in [BACKLOG.md](../BACKLOG.md).
- very_good_analysis lints, `flutter analyze` clean ([brief §5](../BRIEF.md)).

The design system has 45 components plus 3 internal pieces (Field, Popover, Scrim) and 15 `Fm*` shell
building blocks ([DESIGN_INVENTORY.md](../DESIGN_INVENTORY.md)). Its component sources are missing from
the export; the props and states are recoverable from `_ds_bundle.js` and `_adherence.oxlintrc.json`
([G02](../DESIGN_GAPS.md#g02)). Related gaps: the eighth "Tools" mode ([G09](../DESIGN_GAPS.md#g09)), no
drawn disabled state with the future-version tooltip ([G10](../DESIGN_GAPS.md#g10)), missing focus and
tooltip states ([G22](../DESIGN_GAPS.md#g22)), narrow-window behaviour ([G21](../DESIGN_GAPS.md#g21)), and
a Material date picker in a mobile note ([G55](../DESIGN_GAPS.md#g55)).

Package facts (verified 2026-10-13): flutter_riverpod 3.4.3, riverpod_annotation 4.0.7,
riverpod_generator 4.0.9, riverpod_lint 3.1.9 (now a native analyzer plugin), go_router 18.0.2 (M1 uses
18.1.0), very_good_analysis 11.0.0, build_runner 2.16.2 (2.17 conflicts with riverpod_generator 4.0.9). custom_lint 0.8.1 is stale and pins an analyzer version
that conflicts with riverpod_generator 4. golden_toolkit is discontinued.

## Decision

### State

- **Riverpod 3 with code generation**: flutter_riverpod 3.4, riverpod_annotation 4 and
  riverpod_generator 4, run by build_runner. Providers are written with `@riverpod`; hand-written
  providers need a reason in review.
- **riverpod_lint 3.1.9** runs as an analyzer plugin, enabled under `plugins:` in
  `analysis_options.yaml`. We do **not** add custom_lint.
- Engine state stays in Rust. Dart providers wrap engine handles and streams from `app/lib/engine/`
  services (per-document state in family providers keyed by `DocumentId`). Widgets never import the
  generated bridge code.
- Data classes use Dart 3 records and sealed classes. freezed is not added unless a clear need appears.
- Where settings are stored (an engine-side file shared with the CLI, or shared_preferences with its
  async API) is decided in M1 and recorded in [ARCHITECTURE.md](../ARCHITECTURE.md).

### Navigation

- **go_router 18** for top-level places: start, the editor with its open documents, settings panes,
  onboarding and recovery. Routes are typed. Deep links matter later for the web build (P5).
- Modes, document tabs and sidebar tabs are state, not routes.

### Component library

- `app/lib/design/components/` mirrors the design system 1:1: **the same names, variants and states**
  (Button with primary, secondary, ghost and danger; IconButton; Tooltip with shortcut; ModeTabs;
  SegmentedControl; ToolButton; PageThumbnail; TextEditBox; Dialog; Menu; CommandPalette; Toast; Banner;
  and the rest). Variants are Dart enums with the design's values.
- Dart class names are the design-system names, as brief §6 asks ("same names"). Files that also need
  Material import it with a prefix or `hide`, so the names never clash. The widgets library has its own
  `Icon` (for font glyphs), so every file that uses Ferman's `Icon` imports `package:flutter/widgets.dart`
  with `hide Icon`. The `Fm*` shell pieces keep their
  `Fm` names. Data constants become enums or generated data: `FERMAN_MODES` becomes the `FermanMode`
  enum (with the eight modes below), `ANNOTATION_TOOLS` the `AnnotationTool` enum (with the 11 tools the
  boards draw, [G62](../DESIGN_GAPS.md#g62)) and `ICON_PATHS` the generated `IconName` enum with its
  path data, which the Icon widget paints ([ADR 0013](0013-fonts-and-icons.md),
  [DESIGN_INVENTORY.md](../DESIGN_INVENTORY.md)). The props, variants and states of every component are
  specified in [COMPONENTS.md](../COMPONENTS.md).
- Every value comes from the generated tokens ([ADR 0012](0012-design-token-pipeline.md)), read through
  `context.ferman`. No colour, size, radius or duration is hard-coded in a widget (the `s6_literals`
  check).
- Every component has a widget test and goldens for each variant and state in light and dark
  ([ADR 0017](0017-testing-and-ci.md)).
- Interactive components support keyboard focus with the design's focus ring, hover, pressed, disabled
  and **disabled with a reason**. ToolButton, menu items and segmented options take an optional disabled
  reason; for later-phase features it is the localized "Available in a future version"
  ([G10](../DESIGN_GAPS.md#g10), [G22](../DESIGN_GAPS.md#g22)).
- The library is built before any screen (M1, after the token pipeline).

### Mode tabs and IndexedStack

- The shell has **eight mode tabs**, as FmWindow and every desktop and tablet artboard show: View, Edit,
  Comment, Fill & Sign, Organize, Convert, Protect, Tools. The design-system constant `FERMAN_MODES`
  lists seven and is stale. The owner confirmed the eight tabs on 2026-10-15
  ([G09](../DESIGN_GAPS.md#g09), [Q05](../QUESTIONS.md#q05)). Later-phase items inside a mode are
  shown disabled with the future-version tooltip.
- Mode tabs and sidebar tabs are the design's ModeTabs and SegmentedControl components over an
  `IndexedStack`, so each keeps its state. Open documents are kept in an IndexedStack too.
- `TabBar` and `TabBarView` are never used.

### Dialogs, popups and overlays

- Every dialog, menu, popover, sheet, toast, tooltip and command palette is a Ferman component, shown
  through widgets-layer primitives (`Overlay`, `OverlayPortal`, our own `PopupRoute` subclasses).
- Never used: `showDialog`, `AlertDialog`, `SimpleDialog`, `Dialog` from Material, `showCupertinoDialog`,
  `CupertinoAlertDialog`, `showModalBottomSheet`, `showDatePicker`, `showTimePicker`, `SnackBar`,
  Material `Tooltip` and `PopupMenuButton`. Date fields use Ferman's own picker, on mobile too
  ([G55](../DESIGN_GAPS.md#g55)).
- No GetX, in any form.
- The only proposed exception is OS-native file pickers ([ADR 0018](0018-native-file-pickers.md),
  Proposed).
- A CI script (`tools/`) fails the build when feature code uses the forbidden APIs above. custom_lint is
  not used for this. In M1 these are the `tools/checks` S6 checks: `s6_forbidden_api` (the APIs above and
  their close relatives, such as `showAdaptiveDialog`, `showCupertinoSheet`, `showMenu` and `TabBar`,
  wherever they resolve to Material or Cupertino, and GetX imports, in all of `app/lib/`) and
  `s6_material_imports` (only `app/lib/design/` and `app/lib/app/app.dart` import Material or
  Cupertino; nothing re-exports them), with reviewed exceptions in `s6_allowlist.dart`.

### Forms, keyboard and accessibility

- Form validators return `bool` and check null and empty values explicitly.
- Every command is a Shortcuts and Actions pair, with the shortcut shown in its tooltip and menu entry,
  per platform (⌘ on macOS, Ctrl on Windows and Linux). Shortcut collisions are checked from one source
  table ([G44](../DESIGN_GAPS.md#g44)).
- Focus traversal follows reading order; every control has a Semantics label.
- Custom title bars use window_manager (f6, f6a). Linux gets a custom title bar too: client-side
  decorations drawn by Ferman, caption buttons at the end, Ctrl shortcuts and Cancel on the left in
  dialogs, as the owner decided on 2026-10-15 ([G15](../DESIGN_GAPS.md#g15),
  [Q12](../QUESTIONS.md#q12)).

### Lints

- very_good_analysis 11 plus riverpod_lint. `flutter analyze` must be clean in CI, and so must
  `dart analyze --fatal-infos`, because the riverpod_lint 3.1.9 plugin reports only through
  `dart analyze` (found in M1).
- very_good_analysis 11 enforces `unnecessary_type_name_in_constructor`, so constructors use Dart 3.13's
  `new` form (`const new(...)`).

## Consequences

### Positive

- The UI matches the design exactly and looks the same on every platform.
- Riverpod's generated providers are type-safe and testable; riverpod_lint catches misuse early.
- Mode and sidebar state survive switching, as users expect from a document editor.
- One place (the component library) to fix a visual bug.

### Negative

- We build and maintain components Material would give us for free, including focus, semantics and
  RTL behaviour for each.
- Using Material and our own names side by side needs import discipline.
- build_runner adds a code-generation step to the developer loop and to CI.
- Riverpod and go_router release major versions often; upgrades are deliberate and tested.

### Follow-up

- M1: Riverpod and go_router setup, the component library with goldens, the shell with eight mode tabs,
  the forbidden-API check.
- Every milestone: new components follow this ADR; disabled future features get BACKLOG.md entries.

## Alternatives considered

- **Material or Cupertino widgets restyled.** Faster at first, but their dialogs, tabs and menus do not
  match the design system and are forbidden by the brief for dialogs.
- **Other state management** (Bloc, Provider, plain `ChangeNotifier`). The brief chooses Riverpod with
  code generation.
- **Riverpod without code generation.** Allowed by Riverpod, but the brief asks for generation and it
  gives better type safety.
- **custom_lint for project rules.** Stale and incompatible with the analyzer that riverpod_generator 4
  needs. A small script covers our few rules.
- **Navigator 1.0 only.** Workable on desktop, but go_router is required by the brief and needed for web
  deep links.

## References

- [Brief](../BRIEF.md) §5, §6
- [ARCHITECTURE.md](../ARCHITECTURE.md), section 2.5
- [DESIGN_INVENTORY.md](../DESIGN_INVENTORY.md) (components and their planned Flutter counterparts)
- [ADR 0012](0012-design-token-pipeline.md), [ADR 0014](0014-localization-and-rtl.md),
  [ADR 0017](0017-testing-and-ci.md), [ADR 0018](0018-native-file-pickers.md)
- [G02](../DESIGN_GAPS.md#g02), [G09](../DESIGN_GAPS.md#g09), [G10](../DESIGN_GAPS.md#g10),
  [G15](../DESIGN_GAPS.md#g15), [G21](../DESIGN_GAPS.md#g21), [G22](../DESIGN_GAPS.md#g22),
  [G44](../DESIGN_GAPS.md#g44), [G55](../DESIGN_GAPS.md#g55)
- [Q05](../QUESTIONS.md#q05), [Q12](../QUESTIONS.md#q12)
