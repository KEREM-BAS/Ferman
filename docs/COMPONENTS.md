# Component spec

This document specifies the Ferman component library in `app/lib/design/components/`: every
design-system component, the internal Field, Popover and Scrim, and the DS additions, each with its
Flutter class, props, variants, sizes, states, keyboard behaviour, semantics and tier. It is the
deliverable of ROADMAP §5 step 7 that [G02](DESIGN_GAPS.md#g02) asks for, and it follows
[ADR 0011](adr/0011-flutter-state-navigation-components.md): the same names, variants and states as
the design system.

The spec has two forms that never drift apart:

- **`app/test/design/component_spec.json`** is the source of truth. It is machine-readable so the
  app's spec walker (ROADMAP step 7, "A test walks the spec and fails on anything missing") and the
  widget tests can iterate over it.
- **This document.** The prose above the generated reference is written by hand. Everything between
  the two `GENERATED COMPONENT REFERENCE` markers is rendered from the JSON by
  `(cd tools/icons && dart run icons:component_spec)`; `--check` fails when it is stale.

The `component_spec` check of `tools/checks` (run by `check_all`) walks the JSON against
`app/lib/design/`: classes, props, item types and their fields, enum values, and the values of
variants that no enum prop carries.

`tools/icons/test/component_spec_test.dart` checks the JSON against the design export: every
manifest entry is present, every prop and enum value the lint config declares appears with the same
values, every source reference still points at a line that contains its text, every interactive
component has a focus-visible state, and the disabled-with-reason states of
[G10](DESIGN_GAPS.md#g10) are in place.

## Contents

1. [Sources](#sources)
2. [How the spec was written](#how-the-spec-was-written)
3. [JSON schema](#json-schema)
4. [Ambiguities and decisions](#ambiguities-and-decisions)
5. [Reference (generated)](#reference-generated)

## Sources

The component sources, type definitions and cards are missing from the export
([G02](DESIGN_GAPS.md#g02)), so the spec is recovered from what is there. All paths are relative to
the repository root; `design/` is read-only.

| Source | What it gives |
|---|---|
| `design/_ds/…/_ds_manifest.json` | the 45 component names (42 widgets and the data constants `ICON_PATHS`, `FERMAN_MODES`, `ANNOTATION_TOOLS`) and their groups |
| `design/_ds/…/_adherence.oxlintrc.json` | declared prop names for 38 components and item types, and 35 enum-value rules |
| `design/_ds/…/_ds_bundle.js` | the transpiled components: defaults, roles, ARIA attributes, keyboard handlers, derived states |
| `design/_ds/…/components/*/*.css`, `tokens/base.css` | state selectors (hover, active, focus-visible, disabled, aria-pressed, aria-selected, aria-checked, data attributes) |
| `design/ds-additions/fm-additions.css` | patched components (fix 1 to fix 5) and the forced-state harness of the state sheet |
| `design/DS additions.dc.html` | new components and the "Interactive states" matrix |
| `design/FmWindow.dc.html`, `FmStart`, `FmSettings`, `FmSidebar`, `FmNumber`, `FmComments`, `DocForm`, `00 Fixes`, `01 First run and files` | the additions drawn inline (document tabs, window chrome, save indicator, date picker, mention list, comment card, thumbnail badges, FmNumber) and how the M1 screens use each component |

Line numbers in the spec refer to these files as exported. The design is read-only, so they only
change with a re-export ([Q11](QUESTIONS.md#q11)); the spec test then names every reference that
moved.

## How the spec was written

By careful reading, not by a generator: the bundle and the CSS do not encode keyboard behaviour,
Flutter names or tiers in a form a script could extract. A scratch helper resolved the line numbers
of the CSS selectors and design snippets so that every reference is exact; the JSON it produced is
now edited by hand. The prop names and enum values were cross-checked against the lint config and
against the component reference in [DESIGN_INVENTORY.md](DESIGN_INVENTORY.md) §6.

**Tier** (ROADMAP step 7 and the M1 plan): tier 1 components are used by the M1 screens and are built
to full depth first; tier 2 components are complete visually and take their data through
parameters. The M1 screens are the boards `f6`, `f6a`, `a1-1`, `a1-2b`, `a1-2c`, `a1-5`, `a11-1`,
`a11-1w`, `a11-1b` and `a12-2a` to `a12-2d`, plus the always-present parts of the `FmWindow`,
`FmStart` and `FmSettings` building blocks. Content that needs an open document (the `Doc*` sample
pages, `FmEditPanel`, the thumbnails of `FmSidebar`), FmWindow parts shown only for a later feature
(the status-bar task) and the settings panes that M1 shows disabled do not make a component tier 1.
Each component's `tierReason` says why.

## JSON schema

All keys are always present unless marked optional. Strings are English; user-facing copy in the
spec is the design's English and is localized through the ARB files.

### Top level

| Key | Type | Meaning |
|---|---|---|
| `schemaVersion` | int | 1. Raised when a key changes meaning. |
| `description` | string | What the file is. |
| `documentation` | string | This document. |
| `futureVersionTooltip` | string | "Available in a future version" (G10). |
| `manifest` | object | `path` of the manifest and its `components` count (45). |
| `adherence` | string | Path of the lint config. |
| `sourceFiles` | object | Alias → repository path for every file a reference points into. |
| `tiers` | object | `"1"` and `"2"` → the rule for that tier. |
| `stateVocabulary` | object | Common state name → meaning. Component-specific names are allowed. |
| `triggers` | object | State trigger → meaning: `none`, `pointer`, `keyboard`, `prop`, `data`, `drag`, `system`. |
| `types` | object | Named types used in `type` strings that are not Dart or Flutter types. |
| `rules` | string[] | Rules that apply to every component. |
| `enums` | object | Dart enum name → `{ds: string[], dart: string[], source: string}`; `ds[i]` maps to `dart[i]`. |
| `components` | object[] | One entry per component, grouped as the manifest groups them. |

### Component

| Key | Type | Meaning |
|---|---|---|
| `name` | string | Design-system name (`Button`, `ICON_PATHS`), or the addition's name. |
| `flutterClass` | string | Dart class or enum. DS names stay; `ICON_PATHS`, `FERMAN_MODES`, `ANNOTATION_TOOLS` become `IconName`, `FermanMode`, `AnnotationTool`. |
| `kind` | string | `widget` (DS component), `enum` (DS data constant), `internal` (Field, Popover, Scrim), `addition` (DS additions). |
| `group` | string | Manifest group (`core`, `forms`, …) or `additions`. |
| `tier` | int | 1 or 2 (see above). |
| `tierReason` | string | Why that tier. |
| `summary` | string | One sentence. |
| `source` | object | Optional keys: `bundle` `{file, lines: [first, last]}` (the section in `_ds_bundle.js`, `file` is the original `.jsx` path), `design` `[{file, lines}]` (aliases of `sourceFiles`), `css` (aliases), `generated` (path). |
| `usedIn` | string[] | Design files (`.dc.html` stems) that draw the component. |
| `interactive` | bool | Takes keyboard focus; then a focus-visible state is required. |
| `props` | Prop[] | Parameters, DS props first. |
| `itemTypes` | ItemType[] | Data shapes the component takes in lists (options, menu items, tools). |
| `variants` | object | Prop name → values for the props that select a look. |
| `sizes` | string[] | Values of the size prop, or empty. |
| `states` | State[] | Every state the widget tests and goldens cover. |
| `keyboard` | object[] | `{keys: string[], action: string}`. Keys marked "not in the bundle" are additions this spec makes. |
| `semantics` | object | `role` (the ARIA role from the bundle), `label` (where the label comes from), `properties` (Flutter Semantics properties to set). |
| `entries` | array or object | Optional, `enum` kind only: the values (`FermanMode`, `AnnotationTool`), or for `IconName` the generated enum (`generatedFile`), the element data (`dataFile`), the count and the directional names. |
| `notes` | string[] | Decisions and open points for this component. |

### Prop

| Key | Type | Meaning |
|---|---|---|
| `ds` | string or null | DS prop name; null for a Flutter-only parameter. |
| `dart` | string or null | Dart parameter name; null when the prop has no Flutter equivalent. |
| `type` | string | Intended Dart type (`n/a` when `dart` is null). |
| `required` | bool | Required in Dart. |
| `default` | JSON | For a DS prop, the bundle's default (null when it has none); for a Flutter-only parameter, the proposed Dart default. Non-JSON values are strings such as `"-Infinity"` or a bundle constant (`"FERMAN_MODES"`). |
| `dartDefault` | JSON | Optional: the Dart default when it differs from the bundle's. A string is a Dart expression (`"Duration(milliseconds: 450)"`, `"FermanMode.values"`); other values are JSON (`null` for `Icon.flipRtl`). Absent means the Dart default is `default`. |
| `declared` | bool | Listed in the lint config's declared props. |
| `dartEnum` | string | Optional: the enum in `enums`. |
| `values` | string[] | Optional: the DS values of an enum prop. |
| `omitReason` | string | Optional; required when `dart` is null. |
| `notes` | string | Optional. |

### ItemType

`{name, dart, declared, fields: Prop[], states: State[]}`. `name` is the DS name when the lint config
declares it (`SegmentOption`, `MenuItem`, `CommandItem`, `SelectOption`, `FontOption`, `RecentFile`,
`AnnotationTool`, `FermanMode`, `NoteReply`, `SignatureValue`).

### State

| Key | Type | Meaning |
|---|---|---|
| `name` | string | lowerCamelCase; see the state names in the reference. |
| `trigger` | string | A key of `triggers`. |
| `prop` | string | Optional: the prop or field that drives it. |
| `refs` | Ref[] | Where the design defines or draws it; may be empty for states the design does not draw. |
| `tooltip` | string | Optional: the tooltip text (disabled with reason). |
| `gap` | string | Optional: the DESIGN_GAPS entry that adds or settles the state. |
| `notes` | string | Optional. |

A **Ref** is `{file, line, text}`: `file` is an alias of `sourceFiles`, `line` is 1-based and `text`
occurs in that line.

## Ambiguities and decisions

The design leaves these points open or contradicts itself. Each is decided here so the library can be
built; the ones that need a design answer are also listed for the lead to record in DESIGN_GAPS.md.

1. **Disabled with a reason.** The bundle drops the tooltip of a disabled IconButton and ToolButton
   and uses native `disabled`, which removes the control from the Tab order. G10 and G22 need the
   reason to be visible and readable, so a disabled-with-reason control stays focusable, is announced
   as disabled with the reason as tooltip and hint, and ignores activation. Toolbar arrow keys stop on
   it too, so the reason can be read without Tab. Plain disabled controls (no reason) behave as in the
   bundle and are skipped. The FmWindow Save button already shows the pattern: disabled,
   with the title "No changes to save".
2. **Annotation tools.** The bundle constant `ANNOTATION_TOOLS` has nine tools; FmWindow and `a4-1`
   draw eleven (adding Callout and Measure, labelling Text "Text" and drawing Shapes with the
   `shapes` icon). `AnnotationTool` follows the drawing, as `FermanMode` does for the stale
   `FERMAN_MODES` (G09). DESIGN_GAPS records it as [G62](DESIGN_GAPS.md#g62).
3. **Icon mirroring default.** The DS default of `flipRtl` is false and boards flip single uses. The
   design flips exactly eight glyphs, so `IconName.directional` marks them and the Icon widget
   mirrors them by default: `flipRtl` is `bool?` with the Dart default `null` (`dartDefault`), which
   means "use `IconName.directional`"; a use can still pass `flipRtl: false` or `true`. The uses of these eight glyphs
   drawn without a flip (sheet navigation in `09b`, the DocForm calendar, "Go to" in `03c`,
   FmSigCard) are all on left-to-right boards, where a flip changes nothing; in right-to-left they
   mean previous and next like the flipped uses, so mirroring them is the safe default. Glyphs the
   inventory lists as possibly directional but never flipped (send, reply, the list icons,
   text-cursor, arrow-left-right, volume-2, chevrons-left and chevrons-right) are not marked.
4. **Keyboard behaviour the bundle does not have.** These are marked "not in the bundle" in the
   reference: arrow keys in the FontPicker list, Space on PdfFormField checkboxes and radios, the
   menu-button ArrowDown on ToolButton, submenus on ArrowRight (ArrowLeft in RTL), arrow keys in the
   AnnotationTools colour group, between document tabs, between sidebar thumbnails and between
   comment cards, and the whole DatePicker keyboard model. They follow the WAI-ARIA pattern that the
   bundle's roles imply.
5. **Segmented controls skip disabled options.** The bundle's arrow keys land on disabled segments;
   Flutter skips plain disabled segments and stops on disabled-with-reason ones without selecting
   them.
6. **Toolbar Tab order.** The bundle keeps every tool a Tab stop and adds arrow keys; WAI-ARIA
   suggests one Tab stop per toolbar. The spec follows the bundle.
7. **Window controls are not Tab stops**, as in native apps; the window commands have shortcuts. The
   Linux variant is not drawn (G15, Q12) and reuses the Windows layout until the owner checks GNOME
   and KDE.
8. **Select opens a Ferman popup.** The bundle restyles a native `<select>`; its open list is not
   drawn. The list reuses the Menu item look inside a Popover.
9. **`default` enum values.** `Kbd.tone` and `Dialog.tone` have the value `default`, a Dart keyword;
   the Dart value is `standard`.
10. **Controlled widgets.** React's uncontrolled `defaultValue`, `defaultChecked`, `defaultTool`,
    `defaultMode` and similar props are dropped; `defaultOpen` becomes `initiallyOpen`. The value
    lives in providers (ADR 0011).
11. **Tiers that differ from DESIGN_INVENTORY's "first needed".** `SaveIndicator` is tier 1 because
    the `f6a` golden shows "Unsaved changes" in the status bar; its behaviour arrives in M3 as the
    inventory says. `PanelSection` is tier 2 because no M1 board draws a right-panel section, although
    the inventory lists it for M1 as panel structure. `TaskProgress` and `ProgressBar` are tier 2
    because FmWindow shows the status-bar task only for a running job. `AnnotationTools` is tier 1
    because M1 draws every tool row, with the tools disabled through `disabledReasons`; `DropZone` is
    tier 1 for the Start empty state and is disabled through `disabledReason` until drops and opening
    arrive.
12. **Reduced motion and literal animations.** The reduced-motion tokens zero the durations, but the
    spinner (0.8 s), the indeterminate progress sweep (1.4 s) and the caret blink (1.05 s) are
    literal keyframe timings. Proposed: the caret stays on, the indeterminate bar shows a static
    partial fill, and the spinner keeps turning so that progress is still visible.
13. **FmNumber's `lang` prop** is a board convenience. In the app the number format follows the
    region setting, never a prop or the UI language (G34).
14. **Invented APIs.** Field, Popover and Scrim exist only as CSS, and the additions only as inline
    board markup, so their parameters are proposed names derived from the drawings. They are marked
    with `ds: null`.
15. **Badge `edited` tone.** `core.css` draws it teal (with a dark-theme `#4FC2B4`); the DS additions
    patch it to the accent. The patch wins (fix 3).
16. **Thumbnail markers.** `PageThumbnail.marker` (edited, comment) is superseded by the five
    ThumbnailBadges of fix 5; the prop stays in the spec because the lint config declares it.
17. **IconButton loading.** The state sheet draws a Spinner in place of the button; the bundle has no
    prop, so the spec adds the Flutter-only `loading` parameter (`ds: null`, as in decision 14).
18. **Turkish matching in the command palette.** The bundle lowercases with the Turkish locale
    whatever the UI language; Flutter matches with the casing rules of the app locale
    (ARCHITECTURE §11.2).
19. **Icons are painted, not loaded.** The bundle injects SVG markup. The SVG packages for Flutter
    depend on `http`, which the network deny list forbids, so `tools/icons` also generates
    `app/lib/design/icons/icon_data.g.dart`: every glyph as const instances of the sealed
    `IconElement` classes (`icon_element.dart`), with the design's attribute values unchanged. The
    Icon widget paints them with a CustomPainter (path data through path_parsing). The SVG files in
    `app/assets/icons/` remain the provenance-tracked export and are not loaded at run time.
20. **Labels come from the caller.** The bundle carries English copy: DS `label` defaults ("Mode",
    "Loading"), the DropZone `COPY` strings and footnote, hard-coded names ("Comment tools", "Color",
    "Dismiss", "Cancel", "Pause", "Resume") and the `label` of every `FERMAN_MODES` and
    `ANNOTATION_TOOLS` entry. Components hold no English strings, so each becomes a caller parameter: a
    required `String` (`ModeTabs.semanticLabel`, `AnnotationTools.semanticLabel` and
    `colorsSemanticLabel`, `DocumentTab.unsavedLabel` and `closeLabel`, the four `WindowChrome` labels,
    `SaveIndicator.label`); a label that is required, by assertion, whenever its button shows
    (`Banner.dismissLabel`, `Toast.closeLabel`, `Dialog.closeLabel`, the `TaskProgress` Cancel, Pause
    and Resume labels); a nullable text that is not shown when null (the DropZone copy;
    `Spinner.semanticLabel`, whose null makes the spinner decorative); or a `*LabelOf` callback for enum
    values (`ModeTabs.labelOf`, `AnnotationTools.toolLabelOf` and `colorLabelOf`). `FermanMode` and
    `AnnotationTool` carry no label, so their item field `label` has `dart: null`. A widget that carries
    copy is built by the caller and passed in (`DocumentTab.spinner`, the Spinner "Opening").
    `SaveIndicator` takes `savedLabel` and `region` to put the saved time, formatted with
    `RegionFormat.time`, inside the localized text ([G34](DESIGN_GAPS.md#g34)). The design's English
    stays in the spec, as the DS `default` and in the notes, as the source for the ARB files.
21. **How notices are announced.** The design's `role="status"` notices (Banner info, success and
    neutral; every Toast but danger; TaskProgress; SaveIndicator; a labelled Spinner) are polite live
    regions. Its alerts (a danger Toast; a danger or warning Banner: `role="alert"`,
    `aria-live="assertive"`) are announced assertively, but Flutter allows no live region on a node
    with the alert role. So on the web an alert has the alert role, which browsers announce on their
    own; where the platform supports announcements (`MediaQueryData.supportsAnnounce`: the desktop
    systems and iOS) it has the alert role and its text is also sent once as an assertive
    `SemanticsService` announcement when it appears and when it changes, because Flutter's desktop
    bridges do not announce roles; on Android it stays a polite live region, as Flutter's own error
    texts do. The shared piece is `FeedbackSemantics`
    (`app/lib/design/components/feedback/feedback_semantics.dart`), internal to the feedback group.
22. **Indeterminate progress.** The bundle keeps `role="progressbar"` and drops `aria-valuenow` while
    indeterminate. Flutter has a loading-spinner role for busy work of unknown length, so an
    indeterminate ProgressBar uses it, with no value, as the Spinner does; a determinate ProgressBar
    is a progress bar named by its label, with the percentage (0 to 100) as its value.
23. **Reduced motion as built.** Decision 12 holds: the Spinner (0.8 s) and the loading Button's
    loader (0.9 s) keep turning under reduced motion, as their literal CSS keyframes do, and the
    indeterminate ProgressBar's 40 % fill stays still at the start edge. Transitions that use the
    duration tokens (fills and colours, the focus-ring fade, the Toast's rise, the progress fill) take
    no time.
24. **No toolbar, group or separator roles, no `aria-haspopup`.** Flutter's semantics roles have no
    toolbar, group or separator, and there is no has-popup flag. Toolbar and ToolbarGroup are
    semantics containers named by their `semanticLabel` that keep their items as separate nodes;
    ToolbarSeparator is decorative and not announced; a ToolButton with `hasMenu` is announced as a
    button, its caret is only drawn, and ArrowDown asks for the menu (decision 4). The spec's
    `semantics.role` keeps the design's ARIA roles. Revisit when Flutter adds these roles.
25. **Toolbar arrow keys.** ArrowLeft and ArrowRight visit the items in the order they appear on
    screen, mirrored in right to left, not in the order their focus nodes were attached, so a tool
    that appears later keeps its place and the arrows agree with Tab. Inside a segmented control, tab
    strip or radio group only that group's Tab stop is visited, and the group's own arrow keys win
    while focus is in it. While focus is in a text field or a Select, the arrows are left to it, as
    `Toolbar.jsx` skips `INPUT` and `SELECT`, so focus never leaves an open select list.
26. **AnnotationTools dims each swatch.** The bundle dims the whole colour group to 0.4 opacity while
    it is disabled. Flutter dims each swatch under its focus ring instead: the swatches and their
    rings never overlap (4 px apart; a checked ring reaches 4 px), so the pixels are the same, and the
    focus ring of a group disabled with a reason keeps its full strength
    ([G71](DESIGN_GAPS.md#g71)).
27. **ModeTabs scrolls at once.** When the modes overflow, a tab the arrow keys move to is brought
    into view without an animation, as the bundle's `focus()` does.
28. **Document tabs: the close button, tooltips and the empty strip.** The close button sits inside
    the tab on screen and for screen readers, but its focus node hangs from a node above the tab's own
    (a sibling, not a child), so while the close button has focus the tab neither reports focus nor
    shows its ring; the ring is painted beside the tab's content, so showing it never rebuilds the
    close button. The design gives the whole tab a `title` (the file name) and the unsaved dot and the
    close button their own; a browser shows the innermost one, so the name tooltip covers only the
    icon and the name, and the dot (`unsavedLabel`) and the close button (`closeLabel` with ⌘W or
    Ctrl+W) have their own tooltips. `DocumentTabStrip`, which is not a design-system component,
    places the tabs and gives them their tab-list semantics and arrow keys: its tab bar ("Open
    documents") holds only the tabs, and the "+N" and "+" buttons follow it. With no tabs, as on the
    empty Start board `a1-5`, it builds no tab bar, since an empty one would be announced as a list of
    nothing and Flutter's debug role checks reject it.
29. **The focus ring is painted as bands.** CSS clips an outer `box-shadow` to the outside of the
    border box; a `BoxDecoration` shadow in Flutter also fills the inside, which shows on transparent
    controls such as a ghost button. `FocusRing` paints the outer ring (a 2 px gap, then 2 px of the
    focus colour) and the field ring (1 px) as bands outside the control's shape, with the corners
    growing by the spread as CSS spread shadows do. The outer and field rings fade and grow in over
    the component's box-shadow duration (`--dur-fast` for buttons, zero under reduced motion); the
    inset ring switches at once, because the controls that use it have no box-shadow transition. The
    ring never changes the control's size or the widget tree.

30. **StickyNote and the keyboard.** Board `a4-1d` says Escape closes the note and returns focus to
    its pin; the bundle has no Escape handler. Opening the pin from the keyboard moves focus into the
    card, a non-modal focus scope that Tab leaves at either end; Escape in the card, or Close from
    the keyboard, closes it and puts focus back on the pin. The reply fields of StickyNote and
    CommentCard keep focus after Enter or Reply sends, so a second reply can follow.
31. **TextEditBox on the page.** The frame's negative margin (`margin: -4px -5px`) is applied by a
    render object, so the block takes the room of the paragraph it wraps and its text stays where the
    unframed neighbours put it; the overhang takes the pointer where the parent's bounds cover it. The
    focus ring is page-tuned like the frame: 2 px of page white, then `--edit-box` out to 4 px, in
    both themes. The eight handles show the resize cursors of `editing.css` (mirrored in right to
    left) and resize nothing until block resizing comes in M3 (B016).
32. **TextCaret inside text.** In a baseline `WidgetSpan`, the span applies the text scaler, so the
    caret takes the unscaled em size from the ambient `DefaultTextStyle` (the caller sets it with
    `DefaultTextStyle.merge`) and is never scaled twice. It runs no blink timer while its
    `TickerMode` is muted or it sits on a hidden `IndexedStack` page.
33. **The edited underline's dots.** PageMark draws its dotted underline as square dots snapped to
    device pixels without anti-aliasing (2 × 2 px at a 4 px pitch at 1x), as Chromium draws it in the
    `a3-3a` render.
34. **PdfFormField sizes and the read-only look.** The multiline box is a fixed 60 px, the height of
    the bundle's three-row textarea with 16 px lines (the CSS `min-height` of 54 px never applies);
    longer text scrolls while editing and is clipped otherwise, since a field on a page has a fixed
    rectangle. The read-only look keeps a transparent 1 px border on every side and draws the dotted
    bottom line as 1 px squares at a 2 px pitch; a signed read-only signature keeps its solid bottom
    line, as the cascade gives it. Space toggles a form checkbox or radio and Enter does not, as in a
    browser, even under the app's default shortcuts.
35. **Replace that is not available.** With `replaceDisabledReason`, the find bar keeps the
    disclosure, the replace field and both Replace buttons visible and disabled with the reason
    ("Available in a future version" until replace ships in P2).

36. **Select's open list.** The bundle restyles a native `<select>`, whose list is a listbox. Flutter
    has no listbox role, so the open list is a menu named by the field's label, with radio menu
    items, the chosen one checked; the box stays a button that reports expanded and the value. A click
    on the box only opens or closes the list (`FermanInteractive.onTap`); Enter and Space choose the
    highlighted option. The highlight is brought into view on either side of the list as the arrow
    keys, Home and End move it, and End or Home with no option to rest on does nothing. The check
    takes the Menu check's colour ([G78](DESIGN_GAPS.md#g78)).
37. **CommandPalette's active row.** The bundle points `aria-activedescendant` at the active row.
    Flutter has no active descendant, so the arrow keys send a polite announcement of the row's label
    with its reason or hint where the platform supports announcements (not on Android); hover
    announces nothing. The list scrolls only when the active row is out of view, and then lands
    6 px clear of the edge (`CommandPalette.revealMargin`), as the bundle does; scrollables outside
    the palette never move. A disabled command shows its reason while it is the active row.
38. **Picker popovers and focus.** The ColorPicker and FontPicker popovers are focus scopes of
    their own: Tab, Shift+Tab and the arrow keys stay inside, and Escape closes the popover and
    puts focus back on the trigger. The bundle lets Tab leave in page order, which would leave an
    open popover behind. Opening from the keyboard focuses the selected swatch (the first one when
    none is selected); FontPicker's search field takes focus however it opens, as the bundle's
    `autoFocus` does. A click that opens the ColorPicker puts focus on the popover itself, so no
    swatch and not the trigger shows the focus ring; after a click opened either popover, a click
    outside or a click on a choice leaves the trigger without focus, so a pointer never leaves a
    focus ring behind ([G22](DESIGN_GAPS.md#g22)).
39. **Reading typed numbers.** `NumberStepper.parse` reads what a user types in a field of a region
    (B003): either decimal separator in every region, the region's digits, Arabic-Indic and ASCII
    digits, and the grouping the field itself shows. When the decimal separator is certain (the
    Arabic decimal sign, both "." and ",", or a single mark that is not the region's group
    separator), groups may have any length, so deleting or inserting a digit in a grouped value
    still reads ("1.34,5" is 134.5 for Germany). Otherwise grouping must be well formed, and a
    reading that may be 1000 times off ("1234.567" for Türkiye, "1,234,56" for the United States)
    is not a number. A draft that is not a number is dropped and the field shows its value again.
    The doc comment of `parse` states every rule.
40. **Space toggles, Enter does not.** Checkbox, Radio and Switch toggle with Space only, as native
    controls do, so Enter reaches the app's shortcuts, such as a dialog's default button
    (`FermanInteractive.activateOnEnter: false`). PdfFormField's checkbox and radio do the same
    (decision 34).
41. **Modals over the title bar.** A modal Dialog or CommandPalette opens in the root Overlay, so its
    scrim covers the custom title bar too, as a sheet covers a native window; it counts in
    `ModalScope` while it shows, and the title bar then gives the Windows maximize button's
    snap-layout area back to Flutter, so the scrim takes the pointer there as everywhere else. Popups
    inside the modal (tooltips, popovers, menus) open in the modal layer's own overlay, above it. A
    modal shows only while its route is current: under a route pushed above its own it hides, keeps
    its state and stops counting, and it shows again with focus inside when that route goes; closed
    while hidden, it leaves focus where it is. Inline instances do none of this. Dialog's close
    button is the core small ghost IconButton (`x`), named by `closeLabel`, which `onClose` requires
    (decision 20); Escape in an inline dialog calls `onClose` too.

42. **Narrow rows and tabs.** No board draws a narrow window ([G21](DESIGN_GAPS.md#g21)), so the
    behaviour is Ferman's ([G95](DESIGN_GAPS.md#g95)). `Toolbar` follows the width it is given:
    hints without a menu entry hide, then inline `ToolButton` labels hide behind their icons from the
    end, then items move into an overflow menu (`overflowLabel`, the design-system Menu in a Popover)
    from the end, and the items after the spacer move last; items stay in the tree, so state and
    focus survive a resize, and an item that leaves the row closes the popover it opened
    (`PopoverAnchorVisibility`). `ToolbarItem` gives an item its menu entry. `ModeTabs` falls back to
    icons all together, only when the labelled strip does not fit, with the label as the tooltip
    (through the new `Tooltip.focused`, after the usual delay) and the accessible name; it keeps its
    intrinsic sizes and dry layout. `AnnotationTools` moves its colour group last. A stacked
    `ToolButton` grows by the touch icon's extra 4 px (`stackedHeightFor`).
43. **Dialog buttons in the system's order.** The bundle leaves the order to each screen, while the
    f6a and a1-10b notes give it per system ([G15](DESIGN_GAPS.md#g15),
    [G16](DESIGN_GAPS.md#g16)). `Dialog` applies it: `cancelAction` (Cancel), `alternateAction`
    (a1-10b's "Don't save") and `actions` (the others, written in the macOS and Linux order, the
    affirmative last) are laid out by `DialogButtonOrder`, from `defaultTargetPlatform` unless
    `buttonOrder` says otherwise. macOS and Linux put the alternate apart at the start, after
    `footerStart`, then Cancel and the actions at the end; Windows puts the actions reversed, then
    the alternate, then Cancel (a1-10b: Save, Don't save, Cancel; f6a: primary, secondary, Cancel).
    Focus follows the drawn order. `footerStart` (a checkbox or a link) stays at the start
    everywhere.
44. **Tab closes a menu.** The bundle gives Menu no Tab behaviour. Tab and Shift+Tab call `onClose`,
    as Escape does, from a submenu too, so the host closes the whole menu and returns focus to its
    trigger; with `onClose` null, Tab is left to the host. The WAI-ARIA menu pattern also closes the
    menu on Tab but moves focus on past the trigger; Ferman keeps the Escape behaviour, so focus is
    never lost behind a closed popover and the next Tab moves on from the trigger.
45. **A key cap reads left to right.** Each `Kbd` cap is one key, laid out left to right in every UI
    direction, so a bracket or arrow on it is never mirrored ("⌘]" keeps its "]"); the row of caps
    follows the UI direction, as a12-1ar draws "K ⌘" ([G98](DESIGN_GAPS.md#g98)).
46. **Weekday names that fit.** `DatePicker` heads its columns with the language's short weekday
    names; where any of them is longer than `maxShortWeekday` (4) characters (whole words in Arabic
    and Persian, "יום" and a letter in Hebrew), it uses the narrow names instead
    ([G98](DESIGN_GAPS.md#g98)).

## Reference (generated)

<!-- BEGIN GENERATED COMPONENT REFERENCE: tools/icons, dart run icons:component_spec -->

### Rules

- Dart class names are the design-system names; files that also import Material or the widgets library hide or prefix the clashing names (Icon, IconButton, Tooltip, Dialog, Badge, Radio, Switch, TextField, Banner, Checkbox) (ADR 0011).
- Enum props become Dart enums whose values are the DS values in lower camel case; "default" becomes "standard" because it is a Dart keyword (see "enums").
- React "default*" props for values are dropped: Ferman widgets are controlled and the state lives in providers. "defaultOpen" becomes "initiallyOpen" for UI-local disclosure state.
- onClick becomes onPressed and onChange becomes onChanged; className, style, id, key and ref have no Flutter parameter.
- Every interactive component shows the design system focus ring on keyboard focus: 2 px ink with a 2 px gap (--focus-ring), the inset ring (--focus-ring-inset) on tabs, segments and list rows, the field ring on inputs, the ink tint inside menus (G22).
- Disabled with a reason: disabled styling, the reason as tooltip and semantics hint, still focusable so keyboard and screen-reader users can read the reason, activation does nothing. Unshipped features use the localized "Available in a future version" and get a BACKLOG.md entry (G10).
- Colours, sizes, radii and durations come from tokens.g.dart; durations drop to zero under reduced motion (tokens).
- Page-tuned components (PageMark, TextEditBox, PdfFormField, Highlight, Stamp, ThumbnailBadges) keep their colours in every theme: the page is white.
- Right to left mirrors the layout, never the PDF canvas; icons mirror only when directional.

### Tiers

- Tier 1: Used by the M1 screens: boards f6, f6a, a1-1, a1-2b, a1-2c, a1-5, a11-1, a11-1w, a11-1b, a12-2a to a12-2d, and the always-present parts of the FmWindow, FmStart and FmSettings building blocks (panes enabled in M1). Built to full depth first.
- Tier 2: Used later: inside document content (Doc* pages), later panels (FmEditPanel, FmComments, FmFormPanel), conditional FmWindow parts that need a later feature, or later boards. Built complete visually with data passed in.

### State names

| State | Meaning |
|---|---|
| `default` | At rest. |
| `hover` | Pointer over (CSS :hover). |
| `pressed` | Pointer down (CSS :active). |
| `focusVisible` | Keyboard focus ring (CSS :focus-visible, or the field ring on :focus-within) (G22). |
| `disabled` | Not interactive, no reason given. |
| `disabledWithReason` | Disabled with a tooltip and semantics hint that says why; "Available in a future version" for unshipped features (G10). |
| `toggledOn` | A toggle that is on (aria-pressed=true). |
| `selected` | The chosen tab, option or item (aria-selected). |
| `checked` | A checked checkbox, radio, segment or menu item (aria-checked). |
| `indeterminate` | Mixed checkbox. |
| `loading` | Busy (aria-busy or a spinner in place). |
| `error` | Invalid or failed. |
| `open` | A popup is shown. |
| `expanded` | Disclosed content is shown. |
| `collapsed` | Disclosed content is hidden. |
| `readOnly` | Shown but not editable. |
| `other` | Component-specific names (for example unsaved, dropBefore, metaBelow) describe a drawn state of that component only. |

| Trigger | Meaning |
|---|---|
| `none` | The resting look. |
| `pointer` | Driven by the mouse, pen or touch. |
| `keyboard` | Driven by keyboard focus or keys. |
| `prop` | Driven by a parameter (named in "prop"). |
| `data` | Driven by the data shown (value, selection, counts). |
| `drag` | Driven by a drag over the component. |
| `system` | Driven by the environment (text direction, mode, reduced motion). |

### Named types

| Type | Meaning |
|---|---|
| `KeyCaps` | List<String>: key-cap labels already resolved for the platform from the one shortcut table (⌘ ⌥ ⇧ on macOS; Ctrl, Alt, Shift on Windows and Linux). |
| `IconName` | Generated enum, app/lib/design/icons/icon_name.g.dart; its drawing is IconNameElements.elements in icon_data.g.dart. |
| `FermanMode` | Enum with id and icon; labels are localized and passed by the caller (component FERMAN_MODES). |
| `AnnotationTool` | Enum with id, icon, shortcut, colored and hasMenu; labels are localized and passed by the caller (component ANNOTATION_TOOLS). |
| `T` | The option value type of a generic component (Select, Radio, SegmentedControl). |
| `TaskAction` | Record ({String label, VoidCallback onPressed}). |
| `ToastAction` | Record ({String label, VoidCallback onPressed}). |
| `CommandGroup` | Record ({String label, List<CommandItem> items}). |
| `MentionCandidate` | Record ({String initials, String name}). |
| `CommandFooterHint` | Record ({List<String> keys, String label}): a key-cap hint in the CommandPalette footer ("↑ ↓ Move"). |
| `n/a` | The DS prop has no Flutter parameter; see omitReason. |

### Summary

56 entries. Tier 1 is built to full depth first (used by the M1 screens); tier 2 is complete visually with data passed in.

| Component | Flutter | Kind | Group | Tier | Interactive |
|---|---|---|---|---|---|
| [Icon](#icon) | `Icon` | widget | core | 1 |  |
| [ICON_PATHS](#icon_paths) | `IconName` | enum | core | 1 |  |
| [Button](#button) | `Button` | widget | core | 1 | yes |
| [IconButton](#iconbutton) | `IconButton` | widget | core | 1 | yes |
| [Tooltip](#tooltip) | `Tooltip` | widget | core | 1 |  |
| [Kbd](#kbd) | `Kbd` | widget | core | 1 |  |
| [Badge](#badge) | `Badge` | widget | core | 1 |  |
| [Field](#field) | `Field` | internal | forms | 1 |  |
| [TextField](#textfield) | `TextField` | widget | forms | 1 | yes |
| [Select](#select) | `Select` | widget | forms | 1 | yes |
| [NumberStepper](#numberstepper) | `NumberStepper` | widget | forms | 2 | yes |
| [Checkbox](#checkbox) | `Checkbox` | widget | forms | 2 | yes |
| [Radio](#radio) | `Radio` | widget | forms | 1 | yes |
| [Switch](#switch) | `Switch` | widget | forms | 1 | yes |
| [ColorPicker](#colorpicker) | `ColorPicker` | widget | forms | 2 | yes |
| [FontPicker](#fontpicker) | `FontPicker` | widget | forms | 2 | yes |
| [Popover](#popover) | `Popover` | internal | forms | 2 |  |
| [PanelSection](#panelsection) | `PanelSection` | widget | panels | 2 | yes |
| [ModeTabs](#modetabs) | `ModeTabs` | widget | navigation | 1 | yes |
| [FERMAN_MODES](#ferman_modes) | `FermanMode` | enum | navigation | 1 |  |
| [SegmentedControl](#segmentedcontrol) | `SegmentedControl` | widget | navigation | 1 | yes |
| [Toolbar](#toolbar) | `Toolbar` | widget | navigation | 1 |  |
| [ToolbarSeparator](#toolbarseparator) | `ToolbarSeparator` | widget | navigation | 1 |  |
| [ToolbarSpacer](#toolbarspacer) | `ToolbarSpacer` | widget | navigation | 1 |  |
| [ToolbarGroup](#toolbargroup) | `ToolbarGroup` | widget | navigation | 2 |  |
| [ToolButton](#toolbutton) | `ToolButton` | widget | navigation | 1 | yes |
| [PageThumbnail](#pagethumbnail) | `PageThumbnail` | widget | pages | 2 | yes |
| [PageMark](#pagemark) | `PageMark` | widget | editing | 2 |  |
| [SearchReplaceBar](#searchreplacebar) | `SearchReplaceBar` | widget | editing | 2 | yes |
| [TextEditBox](#texteditbox) | `TextEditBox` | widget | editing | 2 | yes |
| [TextCaret](#textcaret) | `TextCaret` | widget | editing | 2 |  |
| [AnnotationTools](#annotationtools) | `AnnotationTools` | widget | annotations | 1 | yes |
| [ANNOTATION_TOOLS](#annotation_tools) | `AnnotationTool` | enum | annotations | 1 |  |
| [Highlight](#highlight) | `Highlight` | widget | annotations | 2 |  |
| [StickyNote](#stickynote) | `StickyNote` | widget | annotations | 2 | yes |
| [Stamp](#stamp) | `Stamp` | widget | annotations | 2 |  |
| [PdfFormField](#pdfformfield) | `PdfFormField` | widget | fill-sign | 2 | yes |
| [SignaturePad](#signaturepad) | `SignaturePad` | widget | fill-sign | 2 | yes |
| [Banner](#banner) | `Banner` | widget | feedback | 2 |  |
| [ProgressBar](#progressbar) | `ProgressBar` | widget | feedback | 2 |  |
| [Spinner](#spinner) | `Spinner` | widget | feedback | 1 |  |
| [TaskProgress](#taskprogress) | `TaskProgress` | widget | feedback | 2 |  |
| [Toast](#toast) | `Toast` | widget | feedback | 2 |  |
| [DropZone](#dropzone) | `DropZone` | widget | empty | 1 | yes |
| [CommandPalette](#commandpalette) | `CommandPalette` | widget | overlays | 2 | yes |
| [Dialog](#dialog) | `Dialog` | widget | overlays | 2 | yes |
| [Menu](#menu) | `Menu` | widget | overlays | 2 | yes |
| [Scrim](#scrim) | `Scrim` | internal | overlays | 2 |  |
| [DocumentTab](#documenttab) | `DocumentTab` | addition | additions | 1 | yes |
| [WindowChrome](#windowchrome) | `WindowChrome` | addition | additions | 1 |  |
| [SaveIndicator](#saveindicator) | `SaveIndicator` | addition | additions | 1 |  |
| [DatePicker](#datepicker) | `DatePicker` | addition | additions | 2 | yes |
| [MentionList](#mentionlist) | `MentionList` | addition | additions | 2 | yes |
| [CommentCard](#commentcard) | `CommentCard` | addition | additions | 2 | yes |
| [ThumbnailBadges](#thumbnailbadges) | `ThumbnailBadges` | addition | additions | 2 | yes |
| [FmNumber](#fmnumber) | `FmNumber` | addition | additions | 2 | yes |

### Enums

| Dart enum | DS values | Dart values | Source |
|---|---|---|---|
| `ButtonVariant` | `primary`, `secondary`, `ghost`, `danger` | `primary`, `secondary`, `ghost`, `danger` | adherence Button.variant |
| `ButtonSize` | `sm`, `md`, `lg` | `sm`, `md`, `lg` | adherence Button.size |
| `IconButtonSize` | `xs`, `sm`, `md`, `lg` | `xs`, `sm`, `md`, `lg` | adherence IconButton.size |
| `IconButtonVariant` | `ghost`, `secondary`, `primary` | `ghost`, `secondary`, `primary` | adherence IconButton.variant |
| `TooltipSide` | `top`, `bottom`, `left`, `right` | `top`, `bottom`, `left`, `right` | adherence Tooltip.side, IconButton.tooltipSide |
| `KbdTone` | `default`, `plain`, `inverse` | `standard`, `plain`, `inverse` | adherence Kbd.tone ("default" is a Dart keyword, so it becomes "standard") |
| `BadgeTone` | `neutral`, `accent`, `success`, `warning`, `danger`, `edited` | `neutral`, `accent`, `success`, `warning`, `danger`, `edited` | adherence Badge.tone |
| `FieldSize` | `sm`, `md` | `sm`, `md` | adherence TextField.size, NumberStepper.size, ColorPicker.size; bundle Select and FontPicker |
| `BannerTone` | `info`, `success`, `warning`, `danger`, `neutral` | `info`, `success`, `warning`, `danger`, `neutral` | adherence Banner.tone |
| `BannerVariant` | `box`, `bar` | `box`, `bar` | adherence Banner.variant |
| `ProgressTone` | `accent`, `success`, `danger`, `paused` | `accent`, `success`, `danger`, `paused` | adherence ProgressBar.tone |
| `ProgressSize` | `sm`, `md` | `sm`, `md` | adherence ProgressBar.size |
| `TaskState` | `running`, `paused`, `done`, `error` | `running`, `paused`, `done`, `error` | adherence TaskProgress.state |
| `TaskProgressVariant` | `card`, `inline` | `card`, `inline` | adherence TaskProgress.variant |
| `ToastTone` | `neutral`, `success`, `warning`, `danger` | `neutral`, `success`, `warning`, `danger` | adherence Toast.tone |
| `DialogTone` | `default`, `warning`, `danger` | `standard`, `warning`, `danger` | adherence Dialog.tone ("default" becomes "standard") |
| `DialogSize` | `sm`, `md`, `lg` | `sm`, `md`, `lg` | adherence Dialog.size |
| `DialogButtonOrder` | `cancelFirst`, `cancelLast` | `cancelFirst`, `cancelLast` | Not a design-system prop: the footer orders of a1-10b (macOS, Linux by G15) and f6a (Windows, G16) |
| `ToolbarVariant` | `bar`, `floating` | `bar`, `floating` | adherence Toolbar.variant; bundle AnnotationTools.variant |
| `ToolButtonLayout` | `inline`, `stacked` | `inline`, `stacked` | adherence ToolButton.layout |
| `ModeTabsVariant` | `segmented`, `underline` | `segmented`, `underline` | bundle ModeTabs.variant |
| `PageMarkKind` | `selection`, `edited`, `missing-glyph`, `search`, `search-current`, `redact-pending`, `redact-applied` | `selection`, `edited`, `missingGlyph`, `search`, `searchCurrent`, `redactPending`, `redactApplied` | adherence PageMark.kind |
| `TextEditBoxState` | `idle`, `hover`, `selected`, `editing` | `idle`, `hover`, `selected`, `editing` | adherence TextEditBox.state |
| `MetaPlacement` | `above`, `below`, `margin` | `above`, `below`, `margin` | fm-additions.css data-meta-placement (fix 1) |
| `HighlightVariant` | `highlight`, `underline`, `strikethrough`, `squiggly` | `highlight`, `underline`, `strikethrough`, `squiggly` | adherence Highlight.variant |
| `AnnotationColor` | `yellow`, `green`, `blue`, `pink`, `orange`, `red`, `ink` | `yellow`, `green`, `blue`, `pink`, `orange`, `red`, `ink` | bundle Highlight COLORS (StickyNote uses the first five, AnnotationTools yellow, green, blue, pink, red, ink) |
| `StampTone` | `seal`, `ink`, `green`, `neutral` | `seal`, `ink`, `green`, `neutral` | adherence Stamp.tone |
| `PdfFormFieldType` | `text`, `multiline`, `date`, `dropdown`, `checkbox`, `radio`, `signature` | `text`, `multiline`, `date`, `dropdown`, `checkbox`, `radio`, `signature` | adherence PdfFormField.type |
| `PdfFormFieldState` | `empty`, `filled`, `focus`, `error`, `readonly` | `empty`, `filled`, `focus`, `error`, `readonly` | adherence PdfFormField.state |
| `SignatureMode` | `draw`, `type`, `image` | `draw`, `type`, `image` | adherence SignatureValue.mode |
| `PageThumbnailState` | `idle`, `dragging`, `placeholder` | `idle`, `dragging`, `placeholder` | adherence PageThumbnail.state |
| `DropIndicator` | `before`, `after` | `before`, `after` | adherence PageThumbnail.dropIndicator |
| `ThumbnailOrientation` | `vertical`, `horizontal` | `vertical`, `horizontal` | adherence PageThumbnail.orientation |
| `ThumbnailMarker` | `edited`, `comment` | `edited`, `comment` | adherence PageThumbnail.marker |
| `FontGroup` | `document`, `system` | `document`, `system` | adherence FontOption.group |
| `DropZoneState` | `idle`, `over`, `error` | `idle`, `over`, `error` | bundle DropZone COPY keys |
| `SearchOption` | `matchCase`, `wholeWord`, `regex` | `matchCase`, `wholeWord`, `regex` | bundle SearchReplaceBar onToggleOption keys |
| `WindowPlatform` | `mac`, `win`, `linux` | `mac`, `win`, `linux` | FmWindow platform (mac, win); linux added by Q12 (G15) |
| `SaveState` | `unsaved`, `saved`, `saving`, `error`, `readonly` | `unsaved`, `saved`, `saving`, `error`, `readOnly` | FmWindow save prop |
| `ThumbnailBadge` | `edited`, `comments`, `form-fields`, `signature`, `warnings` | `edited`, `comments`, `formFields`, `signature`, `warnings` | 00 Fixes f5 and DS additions badgeDemo (fixed order) |

### Group: core

#### Icon

`Icon` · widget · tier 1 · `_ds_bundle.js` components/core/Icon.jsx, lines 70–260

Paints one design glyph from its generated element data at the design system's 1.5 stroke; decorative unless labelled.

Tier: Every M1 screen draws icons.

Drawn in: 00 Fixes, 01 First run and files, 02 View, 03a Edit text, 03b Edit content, 03c Edit review and translate, 04 Comment, 05a Fill, 05b Sign, 06 Organize, 07 Convert, 08 Protect, 09a Tools, 09b Tools, 10 AI assistant, 11b App, 12 Localization, 13a Mobile core, 13b Mobile tasks, 14 Tablet and web, 15 Flows, DS additions, DocCv, DocPlan, FmComments, FmDocPanel, FmFormPanel, FmKeyboard, FmMHome, FmNumber, FmPhone, FmSettings, FmSidebar, FmSigCard, FmStart, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `name` | yes | `name` | `IconName` (required) |  |  | Generated enum (tools/icons). |
| `size` | yes | `size` | `double` | `16` |  | Screens use 10, 11, 12, 14, 16, 18, 20, 24 and more. |
| `strokeWidth` | yes | `strokeWidth` | `double` | `1.5` |  | In viewBox units, as the SVG attribute: 2 for 12 px glyphs and badges; FmWindow caption glyphs use 1 and 1.2, FmPhone 1.8 and 2.2. |
| `color` | yes | `color` | `Color?` | `"currentColor"`; Dart: `null` |  | null inherits the DefaultTextStyle colour (CSS color), else an IconTheme colour, like currentColor. |
| `label` | yes | `semanticLabel` | `String?` |  |  | Set: role img with this label. Null: excluded from semantics (aria-hidden). |
| `flipRtl` | yes | `flipRtl` | `bool?` | `false`; Dart: `null` |  | Null, the Dart default, uses IconName.directional; true or false overrides one use (decision 3). See notes. |
| `style` | yes | — | `n/a` |  |  | Omitted: CSS hook; use layout widgets. |
| `className` | yes | — | `n/a` |  |  | Omitted: CSS hook. |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none |  |  |
| `rtlMirrored` | system | `base.css:22`, `fm-additions.css:67` | Mirrored horizontally under right-to-left when flipped; the PDF canvas never mirrors. |

Semantics: role img (only with a label); label label; Flutter: image, label, excludeSemantics when unlabelled.

Notes:

- The DS default for flipRtl is false and boards flip individual uses with data-fm-flip. The design flips exactly the eight IconName values marked directional, so the Flutter default follows IconName.directional; the few unflipped uses of arrow-right, chevron-left and chevron-right in mobile data lists can pass flipRtl: false if a board shows them unmirrored (DESIGN_INVENTORY §7).
- An unknown name cannot happen in Dart: IconName is a closed enum.
- Painted, not loaded: a CustomPainter draws IconNameElements.elements (app/lib/design/icons/icon_data.g.dart, the sealed IconElement classes of icon_element.dart) on the 24 × 24 grid scaled to size, path data parsed with path_parsing. The stroke is strokeWidth × size / 24 wide with round caps and joins; an element is filled only when IconElement.filled is true. No SVG package (flutter_svg pulls in http); the SVG files in app/assets/icons are the provenance-tracked export and are not loaded at run time (decision 19).

#### ICON_PATHS

`IconName` · enum · tier 1 · `_ds_bundle.js` components/core/Icon.jsx, lines 70–260; generated `app/lib/design/icons/icon_name.g.dart`

The 229 glyph names (145 bundled plus 84 from fm-icons.js), generated by tools/icons with a directional flag and the element data the Icon painter draws.

Tier: Every M1 screen draws icons.

229 values in `app/lib/design/icons/icon_name.g.dart`; element data in `app/lib/design/icons/icon_data.g.dart`; directional: `arrow-left`, `arrow-right`, `chevron-left`, `chevron-right`, `redo-2`, `skip-back`, `skip-forward`, `undo-2`.

Semantics: role none; label none.

Notes:

- Drawing per glyph: IconNameElements.elements in app/lib/design/icons/icon_data.g.dart, generated from the same design source as the enum.
- Provenance per glyph: app/assets/icons/PROVENANCE.md.

#### Button

`Button` · widget · tier 1 · interactive · `_ds_bundle.js` components/core/Button.jsx, lines 378–414

Text button with an optional leading and trailing icon; primary, secondary, ghost and danger.

Tier: Onboarding (a1-1, a1-2b, a1-2c), the FmWindow Save button and title-bar Search, FmStart quick tools and DropZone actions, FmSettings.

Drawn in: 00 Fixes, 01 First run and files, 02 View, 03a Edit text, 03b Edit content, 03c Edit review and translate, 04 Comment, 05b Sign, 06 Organize, 07 Convert, 08 Protect, 09a Tools, 09b Tools, 10 AI assistant, 11b App, 13a Mobile core, 13b Mobile tasks, 14 Tablet and web, DS additions, DocForm, FmComments, FmDocPanel, FmEditPanel, FmFormPanel, FmMHome, FmSettings, FmSigCard, FmStart, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `variant` | yes | `variant` | `ButtonVariant` | `"secondary"` | `primary`, `secondary`, `ghost`, `danger` |  |
| `size` | yes | `size` | `ButtonSize` | `"md"` | `sm`, `md`, `lg` |  |
| `icon` | yes | `icon` | `IconName?` |  |  | Leading; 14 px at sm, 16 px otherwise. |
| `iconEnd` | yes | `iconEnd` | `IconName?` |  |  | Trailing; hidden while loading (the tab-overflow button uses chevron-down). |
| `loading` | yes | `loading` | `bool` | `false` |  | Replaces the leading icon with a spinning loader-circle (0.9 s linear) and marks the button busy. |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | Tooltip and semantics hint while disabled (G10); the FmWindow Save button uses "No changes to save". |
| `fullWidth` | yes | `fullWidth` | `bool` | `false` |  |  |
| `type` | yes | — | `n/a` | `"button"` | `button`, `submit`, `reset` | Omitted: HTML form submission type; Flutter has no forms to submit. |
| `children` | yes | `child` | `Widget` (required) |  |  | Usually Text; boards also put a Kbd (title-bar Search) or a Badge (Review edits) after the label. |
| — |  | `onPressed` | `VoidCallback?` |  |  | DS onClick via ...rest. |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node; one is created when null. |
| — |  | `autofocus` | `bool` | `false` |  | Whether the button takes focus when it first appears. |

Variants (variant): `primary`, `secondary`, `ghost`, `danger`. Sizes: `sm`, `md`, `lg`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `core.css:3`, `core.css:16`, `core.css:20`, `core.css:24`, `core.css:28` |  |
| `hover` | pointer | `core.css:17`, `core.css:21`, `core.css:25`, `core.css:29`, `fm-additions.css:91` |  |
| `pressed` | pointer | `core.css:18`, `core.css:22`, `core.css:26`, `core.css:30`, `fm-additions.css:92` |  |
| `focusVisible` | keyboard | `core.css:11`, `fm-additions.css:99` | G22. |
| `disabled` | prop (`disabled`) | `core.css:32`, `core.css:33` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |
| `loading` | prop (`loading`) | `core.css:34`, `core.css:35` |  |

Keyboard:

- `Enter`: onPressed
- `Space`: onPressed

Semantics: role button; label child text; Flutter: button, enabled, focusable, tooltip (disabledReason).

Notes:

- The DS additions state sheet shows the error state "Shown as toast": a failed action raises a Toast, the button has no error look.
- Loading has no Flutter "busy" flag; announce progress through the label or a live region (B012).

#### IconButton

`IconButton` · widget · tier 1 · interactive · `_ds_bundle.js` components/core/IconButton.jsx, lines 481–517

Square icon-only button with a mandatory label that doubles as its tooltip; optional toggle.

Tier: FmWindow title bar (Home, close tab, +, Settings), mode bar (sidebar, panel), tool rows (zoom, undo, redo), status bar; FmStart pins.

Drawn in: 02 View, 03a Edit text, 03b Edit content, 03c Edit review and translate, 04 Comment, 05a Fill, 05b Sign, 06 Organize, 07 Convert, 08 Protect, 09a Tools, 09b Tools, 10 AI assistant, 11b App, DS additions, DocForm, FmComments, FmDocPanel, FmEditPanel, FmFormPanel, FmSidebar, FmStart, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `icon` | yes | `icon` | `IconName` (required) |  |  |  |
| `label` | yes | `label` | `String` (required) |  |  | Semantics label and tooltip text (1-4 words, no period). |
| `size` | yes | `size` | `IconButtonSize` | `"md"` | `xs`, `sm`, `md`, `lg` | Icon 14 at xs, 20 at lg, 16 otherwise. |
| `variant` | yes | `variant` | `IconButtonVariant` | `"ghost"` | `ghost`, `secondary`, `primary` |  |
| `active` | yes | `active` | `bool?` |  |  | Null: not a toggle. true or false: a toggle (aria-pressed). |
| `shortcut` | yes | `shortcut` | `KeyCaps?` |  |  | Shown in the tooltip as an inverse Kbd. |
| `tooltip` | yes | `showTooltip` | `bool` | `true` |  |  |
| `tooltipSide` | yes | `tooltipSide` | `TooltipSide` | `"bottom"` | `top`, `bottom`, `left`, `right` |  |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | G10. |
| — |  | `onPressed` | `VoidCallback?` |  |  |  |
| — |  | `loading` | `bool` | `false` |  | A Spinner the size of the icon replaces the button's fill and icon (the state sheet); the button keeps its focus and activation does nothing. No bundle prop (decision 17). |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node; one is created when null. |
| — |  | `autofocus` | `bool` | `false` |  | Whether the button takes focus when it first appears. |

Variants (variant): `ghost`, `secondary`, `primary`. Sizes: `xs`, `sm`, `md`, `lg`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `core.css:38`, `core.css:51`, `core.css:53` |  |
| `hover` | pointer | `core.css:48`, `core.css:52`, `core.css:54`, `fm-additions.css:95` |  |
| `pressed` | pointer | `core.css:49`, `fm-additions.css:96` |  |
| `focusVisible` | keyboard | `core.css:50`, `fm-additions.css:99` | G22. |
| `toggledOn` | prop (`active`) | `core.css:55`, `core.css:56` |  |
| `disabled` | prop (`disabled`) | `core.css:57` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". The bundle drops the tooltip of a disabled IconButton (IconButton.jsx: "if (!tooltip \|\| disabled) return btn"); G10 overrides that: a disabled button with a reason shows the reason as its tooltip. The FmWindow Redo button is drawn disabled. |
| `loading` | prop (`loading`) | `DS additions.dc.html:103` | The state sheet draws loading as a 16 px Spinner in place of the button; the bundle has no prop, so the spec adds the Flutter-only loading parameter (decision 17). The button keeps its focus and ring; activation does nothing. |

Keyboard:

- `Enter`: onPressed
- `Space`: onPressed

Semantics: role button; label label; Flutter: button, enabled, focusable, toggled (when active is not null), tooltip.

#### Tooltip

`Tooltip` · widget · tier 1 · `_ds_bundle.js` components/core/Tooltip.jsx, lines 434–479

Inverse caption bubble shown after a delay on hover or keyboard focus, with an optional shortcut.

Tier: Every IconButton and icon-only ToolButton in FmWindow and FmStart, and the disabled-with-reason state (G10).

Drawn in: 00 Fixes, DS additions.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `content` | yes | `message` | `String` (required) |  |  | 1-4 words, no period; or the disabled reason. |
| `shortcut` | yes | `shortcut` | `KeyCaps?` |  |  | Inverse Kbd after the text. |
| `side` | yes | `side` | `TooltipSide` | `"bottom"` | `top`, `bottom`, `left`, `right` | Logical sides follow the layout; left and right swap in RTL. |
| `open` | yes | `open` | `bool?` |  |  | Forces the bubble open or closed (goldens, the state sheet); null follows hover and focus. |
| `delay` | yes | `delay` | `Duration` | `450`; Dart: `Duration(milliseconds: 450)` |  |  |
| `children` | yes | `child` | `Widget` (required) |  |  |  |
| — |  | `hovered` | `bool` | `false` |  | Hover the platform reports for the child while Flutter does not see the pointer (the Windows maximize button). |
| — |  | `excludeFromSemantics` | `bool` | `false` |  | Leaves message out of the child's semantics, for a child that puts it on its own semantics node (FermanInteractive). |
| — |  | `focused` | `bool` | `false` |  | Keyboard focus that the child holds on a focus node above this tooltip's own focus listener (a tab, whose tooltip sits inside its semantics node, G21). |

Variants (side): `top`, `bottom`, `left`, `right`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `hidden` | none | `core.css:72` |  |
| `visible` | pointer | `core.css:73`, `core.css:81`, `core.css:82`, `core.css:83`, `core.css:84`, `DS additions.dc.html:99` | Fades in over --dur-fast after the delay on pointer enter or focus; hides at once on leave, blur or Escape. |

Keyboard:

- `Escape`: hide
- `Tab`: focusing the child shows the tooltip after the delay

Semantics: role tooltip; label content (linked to the child by aria-describedby); Flutter: tooltip on the child.

Notes:

- Tool-button tooltips show name and platform shortcut (G22): ⌘ ⌥ ⇧ on macOS, Ctrl Alt Shift on Windows and Linux.
- Never the Material Tooltip (ADR 0011).

#### Kbd

`Kbd` · widget · tier 1 · `_ds_bundle.js` components/core/Kbd.jsx, lines 416–432

Key caps for a shortcut: keycap, plain (menus, palette) or inverse (tooltips).

Tier: FmWindow Search shortcut, FmStart action cards, FmSettings shortcuts; inside every Tooltip with a shortcut.

Drawn in: 05a Fill, 11b App, 14 Tablet and web, FmDocPanel, FmSettings, FmStart, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `keys` | yes | `keys` | `KeyCaps` (required) |  |  | One cap per key, already resolved for the platform. |
| `tone` | yes | `tone` | `KbdTone` | `"default"` | `default`, `plain`, `inverse` |  |
| `children` | yes | — | `n/a` |  |  | Omitted: Single-key shorthand for keys; Dart takes keys only. |
| — |  | `semanticLabel` | `String?` |  |  | The spoken form of the shortcut; null reads the caps joined by spaces (screen readers speak the modifier symbols themselves: VoiceOver says "command" for ⌘). |

Variants (tone): `default`, `plain`, `inverse`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `core.css:60`, `core.css:61`, `core.css:68`, `core.css:69` |  |

Semantics: role none (kbd text); label semanticLabel, else the caps joined by spaces ("⌘ K", which screen readers speak as "command K"); Flutter: label.

Notes:

- Shortcuts appear only in tooltips and menus, never inside sentences (readme).

#### Badge

`Badge` · widget · tier 1 · `_ds_bundle.js` components/core/Badge.jsx, lines 354–376

Small 18 px status label with an optional dot or 12 px icon.

Tier: FmWindow Review edits count and required-field count, FmStart file badges, FmSettings document languages.

Drawn in: 00 Fixes, 02 View, 03a Edit text, 03b Edit content, 03c Edit review and translate, 05b Sign, 07 Convert, 08 Protect, 09a Tools, 10 AI assistant, 13a Mobile core, 13b Mobile tasks, DS additions, FmComments, FmDocPanel, FmEditPanel, FmMHome, FmSettings, FmStart, FmWindow, Index.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `tone` | yes | `tone` | `BadgeTone` | `"neutral"` | `neutral`, `accent`, `success`, `warning`, `danger`, `edited` |  |
| `dot` | yes | `dot` | `bool` | `false` |  |  |
| `icon` | yes | `icon` | `IconName?` |  |  | 12 px at stroke 2. |
| `children` | yes | `label` | `String` (required) |  |  |  |

Variants (tone): `neutral`, `accent`, `success`, `warning`, `danger`, `edited`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `core.css:87`, `core.css:93`, `core.css:94`, `core.css:95`, `core.css:96`, `core.css:97`, `fm-additions.css:75`, `fm-additions.css:76` | The edited tone uses the DS additions patch (accent tint, ink-300 text in dark), not the teal of core.css. |

Semantics: role none; label label; Flutter: label.

Notes:

- Material has a Badge widget too; import it hidden or prefixed (ADR 0011).

### Group: forms

#### Field

`Field` · internal · tier 1 · CSS only (forms.css)

Internal: the label, hint or error line and the input box shared by every field.

Tier: Label, hint and error shell of TextField and Select (FmStart, FmSettings, a1-1).

Drawn in: FmEditPanel, FmNumber, FmSettings.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `label` | `String?` |  |  |  |
| — |  | `hint` | `String?` |  |  |  |
| — |  | `error` | `String?` |  |  | Replaces the hint; danger border. |
| — |  | `warning` | `bool` | `false` |  | Amber border (FontPicker missing font). |
| — |  | `size` | `FieldSize` | `"md"` | `sm`, `md` |  |
| — |  | `disabled` | `bool` | `false` |  |  |
| — |  | `child` | `Widget` (required) |  |  | The control inside the box. |
| — |  | `focused` | `bool?` |  |  | Whether the box shows focus; null tracks focus inside it. |
| — |  | `hovered` | `bool?` |  |  | Whether the box shows the hover border; null tracks the pointer. |
| — |  | `focusRingStyle` | `FocusRingStyle` | Dart: `FocusRingStyle.field` |  | The ring the box shows with focus: the field ring of `.fm-input`, or the outer `--focus-ring` of the picker triggers (`.fm-colortrigger:focus-visible`, `.fm-fonttrigger:focus-visible`). |
| — |  | `padding` | `EdgeInsetsGeometry?` |  |  | The padding inside the box; null takes the size's side padding. |
| — |  | `clip` | `bool` | `false` |  | Whether the box clips its content to its rounded shape (`.fm-stepper` `overflow: hidden`). |
| — |  | `onLabelTap` | `VoidCallback?` |  |  | Called on a click on [label] (the bundle's `<label htmlFor>`); the control focuses itself. |
| — |  | `errorIcon` | `bool` | `true` |  | Whether the error line starts with the `circle-alert` glyph (TextField's error line); false for text only (the FmNumber board, `FmNumber.dc.html`). |

Sizes: `sm`, `md`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `forms.css:9` |  |
| `hover` | pointer | `forms.css:17`, `fm-additions.css:100` |  |
| `focusVisible` | keyboard | `forms.css:18`, `base.css:15`, `fm-additions.css:101` | Fields show focus on the box (ink border plus a 1 px ring), not as an outline (readme "Focus"). |
| `error` | prop (`error`) | `forms.css:19`, `forms.css:20`, `forms.css:6` |  |
| `warning` | prop (`warning`) | `forms.css:21` |  |
| `disabled` | prop (`disabled`) | `forms.css:22`, `forms.css:30` |  |

Semantics: role none (groups label and control); label label.

Notes:

- No DS name: exists only as CSS (.fm-field, .fm-input). Where porting notes say FermanInputDecorator, read Field (DESIGN_INVENTORY §6).

#### TextField

`TextField` · widget · tier 1 · interactive · `_ds_bundle.js` components/forms/TextField.jsx, lines 1731–1781

Single-line text input with label, hint or error, a leading icon and a unit suffix.

Tier: a1-1 language search, FmStart recent search, FmSettings search, FmSidebar search.

Drawn in: 01 First run and files, 03a Edit text, 03b Edit content, 04 Comment, 05b Sign, 06 Organize, 07 Convert, 08 Protect, 09a Tools, 09b Tools, 10 AI assistant, 11b App, 13b Mobile tasks, DS additions, FmSettings, FmSidebar, FmStart.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` | yes | `label` | `String?` |  |  |  |
| `hint` | yes | `hint` | `String?` |  |  |  |
| `error` | yes | `error` | `String?` |  |  | Validators return bool and check null and empty explicitly (brief §6). |
| `icon` | yes | `icon` | `IconName?` |  |  | Leading; 14 px at sm, 16 at md. |
| `suffix` | yes | `suffix` | `String?` |  |  | Unit text such as "pt". |
| `size` | yes | `size` | `FieldSize` | `"md"` | `sm`, `md` |  |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | Settings controls (G10). |
| `inputRef` | yes | `focusNode` | `FocusNode?` |  |  |  |
| — |  | `controller` | `TextEditingController?` |  |  | Native value, defaultValue and onChange via ...rest. |
| — |  | `placeholder` | `String?` |  |  | Via ...rest; boards use it. |
| — |  | `semanticLabel` | `String?` |  |  | aria-label via ...rest when there is no visible label. |
| — |  | `onChanged` | `ValueChanged<String>?` |  |  |  |
| — |  | `onSubmitted` | `ValueChanged<String>?` |  |  |  |
| — |  | `autofocus` | `bool` | `false` |  |  |
| — |  | `inputFormatters` | `List<TextInputFormatter>?` |  |  | Formatters applied to every edit. |
| — |  | `keyboardType` | `TextInputType?` |  |  | The on-screen keyboard; null for plain text. |
| — |  | `obscureText` | `bool` | `false` |  | Whether the text is masked: the bundle's `type="password"`, passed through `...rest` (a1-8, a5-6b, a8-1, a10-2). |

Sizes: `sm`, `md`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `forms.css:9` |  |
| `hover` | pointer | `forms.css:17`, `fm-additions.css:100` |  |
| `focusVisible` | keyboard | `forms.css:18`, `base.css:15`, `fm-additions.css:101` | Fields show focus on the box (ink border plus a 1 px ring), not as an outline (readme "Focus"). |
| `placeholder` | data | `forms.css:29` |  |
| `error` | prop (`error`) | `forms.css:19`, `forms.css:20`, `forms.css:6`, `DS additions.dc.html:112` |  |
| `disabled` | prop (`disabled`) | `forms.css:22`, `forms.css:30` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |

Keyboard:

- `Enter`: onSubmitted
- `standard text editing`: edit

Semantics: role textbox; label label or semanticLabel; hint or error as description; Flutter: textField, enabled, focusable, label, hint, value.

Notes:

- Never the Material TextField: import it hidden or prefixed (ADR 0011).

#### Select

`Select` · widget · tier 1 · interactive · `_ds_bundle.js` components/forms/Select.jsx, lines 1641–1693

Field-styled picker of one option with a trailing chevron; a Ferman popup, never a Material dropdown.

Tier: FmWindow zoom select, FmStart sort, FmSettings (layout, zoom, language, region, first day of week).

Drawn in: 01 First run and files, 02 View, 03a Edit text, 03b Edit content, 03c Edit review and translate, 04 Comment, 05a Fill, 05b Sign, 06 Organize, 07 Convert, 08 Protect, 09a Tools, 09b Tools, 10 AI assistant, FmComments, FmEditPanel, FmSettings, FmStart, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` |  | `label` | `String?` |  |  |  |
| `options` |  | `options` | `List<SelectOption<T>>` (required) | `[]` |  |  |
| `value` |  | `value` | `T?` |  |  |  |
| `defaultValue` |  | — | `n/a` |  |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `onChange` |  | `onChanged` | `ValueChanged<T>?` |  |  |  |
| `size` |  | `size` | `FieldSize` | `"md"` | `sm`, `md` |  |
| `icon` |  | `icon` | `IconName?` |  |  | FmSettings app language uses languages. |
| `disabled` |  | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | Settings controls (G10). |
| — |  | `semanticLabel` | `String?` |  |  | aria-label via ...rest (zoom, sort). |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node of the box; one is created when null. |

Item type `SelectOption` → `SelectOption<T>` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `value` | yes | `value` | `T` (required) |  |  |  |
| `label` | yes | `label` | `String` (required) |  |  |  |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | G10. |
| — |  | `locale` | `Locale?` |  |  | The locale of the label's text, so Han characters take their regional forms (endonyms, region own names); steers font fallback only. |

Item states:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `selected` | data |  |  |
| `disabled` | prop (`disabled`) |  |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |

Sizes: `sm`, `md`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `forms.css:9` |  |
| `hover` | pointer | `forms.css:17`, `fm-additions.css:100` |  |
| `focusVisible` | keyboard | `forms.css:18`, `base.css:15`, `fm-additions.css:101` | Fields show focus on the box (ink border plus a 1 px ring), not as an outline (readme "Focus"). |
| `open` | pointer |  | Not drawn: the bundle uses a native <select>. The list opens as a Popover in the Menu style (DESIGN_INVENTORY §6). |
| `disabled` | prop (`disabled`) | `forms.css:22` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |

Keyboard:

- `Enter`, `Space`, `Alt+ArrowDown`: open the list
- `ArrowUp`, `ArrowDown`: move in the open list
- `Enter`: choose the highlighted option
- `Escape`: close without change

Semantics: role combobox (native select); label label or semanticLabel; value = selected option label; Flutter: button, expanded, value, enabled, focusable.

Notes:

- The open list is not drawn; it reuses the Menu item look (28 px rows, surface-selected-strong highlight, the check in the secondary icon colour, G78).
- For screen readers the open list is a menu named by the label, with radio menu items (Flutter has no listbox role, decision 36).
- No error state in the DS.

#### NumberStepper

`NumberStepper` · widget · tier 2 · interactive · `_ds_bundle.js` components/forms/NumberStepper.jsx, lines 1502–1601

Numeric field with stacked up and down arrows, step, clamp and precision.

Tier: Screens use FmNumber (locale-aware) built on it; first needed M3.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` | yes | `label` | `String?` |  |  |  |
| `value` | yes | `value` | `double` (required) |  |  |  |
| `defaultValue` | yes | — | `n/a` | `0` |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `min` | yes | `min` | `double` | `"-Infinity"` |  |  |
| `max` | yes | `max` | `double` | `"Infinity"` |  |  |
| `step` | yes | `step` | `double` | `1` |  |  |
| `unit` | yes | `unit` | `String?` |  |  |  |
| `precision` | yes | `precision` | `int` | `0` |  |  |
| `size` | yes | `size` | `FieldSize` | `"sm"` | `sm`, `md` |  |
| `width` | yes | `width` | `double` | `84` |  |  |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| `onChange` | yes | `onChanged` | `ValueChanged<double>?` |  |  |  |
| `id` | yes | — | `n/a` |  |  | Omitted: DOM id for the label link; Semantics links label and field. |
| — |  | `region` | `Region` (required) |  |  | The region whose number format the field shows and reads. |
| — |  | `error` | `String?` |  |  | The error under the box; null for none. |
| — |  | `semanticLabel` | `String?` |  |  | The accessible name when no [label] is shown. |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node of the text control; one is created when null. |
| — |  | `controlStyle` | `TextStyle?` |  |  | The value's text style; null takes the box's control style for [size] (12 px at [FieldSize.sm]). |

Sizes: `sm`, `md`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `forms.css:9` |  |
| `hover` | pointer | `forms.css:17`, `fm-additions.css:100` |  |
| `focusVisible` | keyboard | `forms.css:18`, `base.css:15`, `fm-additions.css:101` | Fields show focus on the box (ink border plus a 1 px ring), not as an outline (readme "Focus"). |
| `arrowHover` | pointer | `forms.css:92` |  |
| `arrowPressed` | pointer | `forms.css:93` |  |
| `arrowDisabled` | data | `forms.css:94` | Increase is disabled at max, Decrease at min. |
| `disabled` | prop (`disabled`) | `forms.css:22` |  |

Keyboard:

- `ArrowUp`: +step (Shift: ×10)
- `ArrowDown`: -step (Shift: ×10)
- `Enter`: commit the typed draft

Semantics: role spinbutton; label label; Flutter: textField, value, increasedValue, decreasedValue, onIncrease, onDecrease, enabled.

Notes:

- Commit rounds to step, clamps to min and max and fixes the precision; a typed draft accepts "," as the decimal mark and commits on blur.
- The arrow buttons are not Tab stops (tabIndex -1).

#### Checkbox

`Checkbox` · widget · tier 2 · interactive · `_ds_bundle.js` components/forms/Checkbox.jsx, lines 1185–1228

16 px checkbox with label and description; checked, indeterminate.

Tier: Not on an M1 board (first needed M2); built with the forms group.

Drawn in: 01 First run and files, 02 View, 03a Edit text, 03b Edit content, 04 Comment, 05b Sign, 06 Organize, 07 Convert, 08 Protect, 09a Tools, 09b Tools, DS additions.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` | yes | `label` | `String?` |  |  |  |
| `description` | yes | `description` | `String?` |  |  |  |
| `checked` | yes | `checked` | `bool` (required) |  |  |  |
| `defaultChecked` | yes | — | `n/a` |  |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `indeterminate` | yes | `indeterminate` | `bool` | `false` |  |  |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | Settings controls (G10). |
| `onChange` | yes | `onChanged` | `ValueChanged<bool>?` |  |  |  |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node; one is created when null. |
| — |  | `autofocus` | `bool` | `false` |  | Whether the box takes focus when it first appears. |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `forms.css:39`, `forms.css:41` |  |
| `hover` | pointer | `forms.css:46`, `forms.css:47`, `fm-additions.css:103` |  |
| `focusVisible` | keyboard | `forms.css:49`, `fm-additions.css:102` |  |
| `checked` | prop (`checked`) | `forms.css:48`, `forms.css:51` |  |
| `indeterminate` | prop (`indeterminate`) | `forms.css:48` | Shows minus instead of check. |
| `disabled` | prop (`disabled`) | `forms.css:52`, `forms.css:54` |  |
| `disabledChecked` | prop (`disabled`) | `forms.css:53` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |

Keyboard:

- `Space`: toggle

Semantics: role checkbox; label label (description as hint); Flutter: checked, mixed (indeterminate), enabled, focusable.

Notes:

- The whole label row is the hit target (a <label> in the bundle).

#### Radio

`Radio` · widget · tier 1 · interactive · `_ds_bundle.js` components/forms/Radio.jsx, lines 1603–1639

Round option in a named group, with label and description.

Tier: FmSettings General: "PDF pages in dark theme" (a11-1, a11-1w).

Drawn in: 01 First run and files, 03b Edit content, 03c Edit review and translate, 04 Comment, 06 Organize, 07 Convert, 09b Tools, FmSettings.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` | yes | `label` | `String?` |  |  |  |
| `description` | yes | `description` | `String?` |  |  |  |
| `checked` | yes | — | `n/a` |  |  | Omitted: Derived: groupValue == value. |
| `defaultChecked` | yes | — | `n/a` |  |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | Settings controls (G10). |
| `name` | yes | — | `n/a` |  |  | Omitted: HTML group name; Dart groups by groupValue. |
| `value` | yes | `value` | `T` (required) |  |  |  |
| — |  | `groupValue` | `T?` |  |  |  |
| `onChange` | yes | `onChanged` | `ValueChanged<T>?` |  |  |  |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node; one is created when null. |
| — |  | `autofocus` | `bool` | `false` |  | Whether the radio takes focus when it first appears. |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `forms.css:58` |  |
| `hover` | pointer | `forms.css:46` |  |
| `focusVisible` | keyboard | `forms.css:49`, `forms.css:60` |  |
| `checked` | data | `forms.css:59` |  |
| `disabled` | prop (`disabled`) | `forms.css:52`, `forms.css:54` |  |
| `disabledChecked` | prop (`disabled`) | `forms.css:53` | G79. The checkbox's strong grey; the cascade would let line 59 draw it as an enabled radio. |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |

Keyboard:

- `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`: move to and select the next option in the group
- `Space`: select

Semantics: role radio (in a radiogroup); label label (description as hint); Flutter: checked, inMutuallyExclusiveGroup, enabled, focusable.

Notes:

- Material has Radio; import it hidden or prefixed.

#### Switch

`Switch` · widget · tier 1 · interactive · `_ds_bundle.js` components/forms/Switch.jsx, lines 1695–1729

28 × 16 on/off switch with an optional label; 44 × 26 at touch density.

Tier: FmWindow tool rows (Dark reading mode, Mark edited text, Show comments) and FmSettings General and Privacy.

Drawn in: 02 View, 03a Edit text, 03b Edit content, 03c Edit review and translate, 04 Comment, 05a Fill, 05b Sign, 07 Convert, 09a Tools, 09b Tools, 13a Mobile core, 13b Mobile tasks, DS additions, FmEditPanel, FmFormPanel, FmSettings, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` | yes | `label` | `String?` |  |  |  |
| `checked` | yes | `value` | `bool` (required) |  |  |  |
| `defaultChecked` | yes | — | `n/a` |  |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | Settings → Privacy rows are disabled until their milestone (G10). |
| `onChange` | yes | `onChanged` | `ValueChanged<bool>?` |  |  |  |
| — |  | `semanticLabel` | `String?` |  |  | aria-label via ...rest (Privacy rows). |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node; one is created when null. |
| — |  | `autofocus` | `bool` | `false` |  | Whether the switch takes focus when it first appears. |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `off` | none | `forms.css:65`, `forms.css:73` |  |
| `on` | prop (`checked`) | `forms.css:70`, `forms.css:78` |  |
| `focusVisible` | keyboard | `forms.css:71`, `fm-additions.css:102` |  |
| `disabled` | prop (`disabled`) | `forms.css:72` | Opacity 0.5; the label turns text-disabled (inline style in the bundle). |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |

Keyboard:

- `Space`: toggle

Semantics: role switch; label label or semanticLabel; Flutter: toggled, enabled, focusable.

Notes:

- The thumb slides along inset-inline-start, so it mirrors in RTL.
- No hover style in the DS; the state sheet "hover" column shows none.
- Material has Switch; import it hidden or prefixed.

#### ColorPicker

`ColorPicker` · widget · tier 2 · interactive · `_ds_bundle.js` components/forms/ColorPicker.jsx, lines 1230–1365

Colour trigger that opens a popover of document colours, 16 standard swatches, a hex field and a page eyedropper.

Tier: FmEditPanel text colour (M3).

Drawn in: 00 Fixes, 03a Edit text, 03b Edit content, FmEditPanel.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` | yes | `label` | `String?` |  |  |  |
| `value` | yes | `value` | `Color?` |  |  | Null means "none" when allowNone. |
| `defaultValue` | yes | — | `n/a` | `"#1F1D1A"` |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `documentColors` | yes | `documentColors` | `List<Color>` | `[]` |  |  |
| `swatches` | yes | `swatches` | `List<Color>` | `"STANDARD (16 colours)"` |  |  |
| `allowNone` | yes | `allowNone` | `bool` | `false` |  |  |
| `open` | yes | `open` | `bool?` |  |  |  |
| `defaultOpen` | yes | `initiallyOpen` | `bool` | `false` |  |  |
| `onOpenChange` | yes | `onOpenChanged` | `ValueChanged<bool>?` |  |  |  |
| `onChange` | yes | `onChanged` | `ValueChanged<Color?>?` |  |  |  |
| `size` | yes | `size` | `FieldSize` | `"sm"` | `sm`, `md` |  |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | Why the picker is disabled (G10). |
| — |  | `noneLabel` | `String?` |  |  | The trigger text for no colour (the bundle's "None"). |
| — |  | `documentColorsLabel` | `String?` |  |  | The heading of the document colours ("In this document"). |
| — |  | `standardColorsLabel` | `String?` |  |  | The heading of the standard swatches ("Standard"). |
| — |  | `noColorLabel` | `String?` |  |  | The accessible name of the none swatch ("No color"). |
| — |  | `hexLabel` | `String?` |  |  | The visible label in the hex field ("Hex"). |
| — |  | `hexSemanticLabel` | `String?` |  |  | The accessible name of the hex field ("Hex color"). |
| — |  | `dialogLabel` | `String?` |  |  | The accessible name of the popover ("Choose color"). |
| — |  | `eyedropper` | `Widget?` |  |  | The eyedropper button after the hex field (an IconButton with `pipette`, disabled until M3); null shows none. |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node of the trigger; one is created when null. |

Sizes: `sm`, `md`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `forms.css:9` |  |
| `hover` | pointer | `forms.css:17`, `fm-additions.css:100` |  |
| `focusVisible` | keyboard | `forms.css:108`, `fm-additions.css:99` |  |
| `open` | prop (`open`) | `forms.css:99`, `forms.css:113` |  |
| `swatchHover` | pointer | `forms.css:119` |  |
| `swatchFocusVisible` | keyboard | `forms.css:120` |  |
| `swatchSelected` | data | `forms.css:121` |  |
| `none` | data | `forms.css:111` |  |
| `disabled` | prop (`disabled`) | `forms.css:22` |  |

Keyboard:

- `Enter`, `Space`: toggle the popover
- `Escape`: close
- `Enter`: in the hex field: commit

Semantics: role button (haspopup dialog) and a dialog "Choose color"; label label; swatches are labelled with their hex value; Flutter: button, expanded, selected (swatch).

Notes:

- Swatches are Tab stops in the bundle; a grid with arrow keys would be kinder but is not drawn.
- The eyedropper button (pipette, "Pick a color from the page") needs the engine (M3).
- The popover is a focus scope; a keyboard open focuses the selected swatch, a click open focuses the popover itself, and after a click open a click outside leaves the trigger without focus (decision 38, G22).

#### FontPicker

`FontPicker` · widget · tier 2 · interactive · `_ds_bundle.js` components/forms/FontPicker.jsx, lines 1367–1500

Font trigger with a searchable popover grouped "In this document" and "On this device", and a missing-font warning.

Tier: FmEditPanel font (M3).

Drawn in: 00 Fixes, 03a Edit text, 03b Edit content, DS additions, FmEditPanel.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` |  | `label` | `String?` |  |  |  |
| `value` |  | `value` | `String` (required) |  |  | Font name. |
| `fonts` |  | `fonts` | `List<FontOption>` | `[]` |  |  |
| `warning` |  | `warning` | `String?` |  |  | Overrides the missing-font note. |
| `open` |  | `open` | `bool?` |  |  |  |
| `defaultOpen` |  | `initiallyOpen` | `bool` | `false` |  |  |
| `onOpenChange` |  | `onOpenChanged` | `ValueChanged<bool>?` |  |  |  |
| `onChange` |  | `onChanged` | `ValueChanged<String>?` |  |  |  |
| `size` |  | `size` | `FieldSize` | `"sm"` | `sm`, `md` |  |
| `disabled` |  | `disabled` | `bool` | `false` |  |  |
| — |  | `glyphWarning` | `bool` | `false` |  | DS additions fix 2 ([data-fm-glyph-warning]): amber border and a triangle in the trigger only. |
| — |  | `disabledReason` | `String?` |  |  | Why the picker is disabled (G10). |
| — |  | `missingNote` | `String?` |  |  | The note shown when the current font is not installed ("Minion Pro isn't installed. Ferman is showing Source Serif instead."), built by the screen from the font and its substitute. |
| — |  | `missingBadge` | `Widget?` |  |  | The badge on missing fonts' rows (a warning Badge "Not installed"); null shows none. |
| — |  | `documentGroupLabel` | `String?` |  |  | The heading of the document's fonts ("In this document"). |
| — |  | `systemGroupLabel` | `String?` |  |  | The heading of the device's fonts ("On this device"). |
| — |  | `searchPlaceholder` | `String?` |  |  | The search field's placeholder ("Search fonts"). |
| — |  | `searchSemanticLabel` | `String?` |  |  | The search field's accessible name ("Search fonts"). |
| — |  | `listSemanticLabel` | `String?` |  |  | The list's accessible name ("Fonts"). |
| — |  | `noMatchesText` | `String Function(String query)?` |  |  | The text shown when no font matches the query ("No fonts match “query”."). |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node of the trigger; one is created when null. |

Item type `FontOption` → `FontOption` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `name` | yes | `name` | `String` (required) |  |  |  |
| `family` | yes | `family` | `String?` |  |  |  |
| `available` | yes | `available` | `bool` | `true` |  |  |
| `substitute` | yes | `substitute` | `String?` |  |  |  |
| `group` | yes | `group` | `FontGroup` | `"system"` | `document`, `system` |  |

Item states:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `selected` | data | `forms.css:138` |  |
| `missing` | data | `forms.css:140` | Warning Badge "Not installed". |
| `hover` | pointer | `forms.css:137` |  |
| `focusVisible` | keyboard | `forms.css:137` |  |

Sizes: `sm`, `md`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `forms.css:9` |  |
| `hover` | pointer | `forms.css:17`, `fm-additions.css:100` |  |
| `focusVisible` | keyboard | `forms.css:126`, `fm-additions.css:99` |  |
| `open` | prop (`open`) | `forms.css:99`, `forms.css:131` |  |
| `missing` | data | `forms.css:21`, `forms.css:128`, `forms.css:129` |  |
| `glyphWarning` | prop (`glyphWarning`) | `fm-additions.css:81`, `fm-additions.css:82` | G36. |
| `emptySearch` | data |  | "No fonts match “query”." |
| `disabled` | prop (`disabled`) | `forms.css:22` |  |

Keyboard:

- `Enter`, `Space`: toggle the popover (search field takes focus)
- `Escape`: close
- `ArrowUp`, `ArrowDown`: move between rows (not in the bundle; see notes)

Semantics: role button (haspopup listbox) and listbox "Fonts" of options; label label; rows by font name; Flutter: button, expanded, selected (row).

Notes:

- The bundle makes rows Tab stops with no arrow keys; Flutter adds Up and Down in the list, the listbox pattern the roles imply.
- Never substitute silently (ADR 0006): the missing-font note says which font is shown instead.
- The popover is a focus scope; after a click open, a click outside or on a font leaves the trigger without focus; Escape returns it (decision 38, G22).

#### Popover

`Popover` · internal · tier 2 · CSS only (forms.css)

Internal: a raised surface anchored under its trigger with a rise-in entrance.

Tier: Shell of ColorPicker and FontPicker (M3); the Select list and DatePicker reuse it.

Drawn in: FmEditPanel.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `open` | `bool` (required) |  |  |  |
| — |  | `anchor` | `Widget` (required) |  |  |  |
| — |  | `child` | `Widget` (required) |  |  |  |
| — |  | `onDismiss` | `VoidCallback?` |  |  | Outside click or Escape. |
| — |  | `surface` | `bool` | `true` |  | Whether to draw the popover surface around [child] and animate it in; false for children that draw their own. |
| — |  | `matchAnchorWidth` | `bool` | `false` |  | Whether the popover is at least as wide as the anchor (the Select list). |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `closed` | none | `forms.css:97`, `forms.css:98` |  |
| `open` | prop (`open`) | `forms.css:99`, `forms.css:104` | Rises in over --dur-base; inset-inline-start 0, 4 px below the anchor; z --z-popover. |

Keyboard:

- `Escape`: close and return focus to the trigger

Semantics: role per use (dialog or listbox); label per use; Flutter: scopesRoute, namesRoute.

Notes:

- Built on OverlayPortal; never a Material popup (ADR 0011).

### Group: panels

#### PanelSection

`PanelSection` · widget · tier 2 · interactive · `_ds_bundle.js` components/panels/PanelSection.jsx, lines 2745–2792

Collapsible right-panel section with a title, header actions and a body.

Tier: Right-panel sections appear in FmEditPanel (M3) and FmDocPanel (M2); the M1 panel slot is empty.

Drawn in: 00 Fixes, 03a Edit text, 03b Edit content, 03c Edit review and translate, 04 Comment, 05a Fill, 05b Sign, 06 Organize, 07 Convert, 08 Protect, 09a Tools, 09b Tools, FmDocPanel, FmEditPanel.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `title` | yes | `title` | `String` (required) |  |  |  |
| `collapsible` | yes | `collapsible` | `bool` | `true` |  | false renders a static heading. |
| `defaultOpen` | yes | `initiallyOpen` | `bool` | `true` |  |  |
| `open` | yes | `open` | `bool?` |  |  |  |
| `onOpenChange` | yes | `onOpenChanged` | `ValueChanged<bool>?` |  |  |  |
| `actions` | yes | `actions` | `List<Widget>` | `[]` |  |  |
| `children` | yes | `child` | `Widget` (required) |  |  |  |
| — |  | `showTopBorder` | `bool` | `true` |  | Whether the 1 px line above shows; the panel passes false for its first section, where the design drops the line (:first-child). |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `expanded` | none | `panels.css:3`, `panels.css:17` |  |
| `collapsed` | prop (`open`) | `panels.css:13`, `panels.css:14` | Chevron turns -90° (+90° in RTL) over --dur-fast; the body is removed. |
| `focusVisible` | keyboard | `panels.css:11` |  |

Keyboard:

- `Enter`, `Space`: toggle

Semantics: role region labelled by the title; the toggle is a button; label title; Flutter: button, expanded, header (static title).

Notes:

- Not drawn hover state for the toggle; none in the CSS.

### Group: navigation

#### ModeTabs

`ModeTabs` · widget · tier 1 · interactive · `_ds_bundle.js` components/navigation/ModeTabs.jsx, lines 1783–1862

Segmented tab strip for the eight modes, over an IndexedStack; never TabBar.

Tier: FmWindow mode bar on every editor board (f6, f6a).

Drawn in: FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `modes` |  | `modes` | `List<FermanMode>` | `"FERMAN_MODES"`; Dart: `FermanMode.values` |  |  |
| `value` |  | `value` | `FermanMode` (required) |  |  |  |
| `defaultValue` |  | — | `n/a` |  |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `onChange` |  | `onChanged` | `ValueChanged<FermanMode>?` |  |  |  |
| `variant` |  | `variant` | `ModeTabsVariant` | `"segmented"` | `segmented`, `underline` | underline is for the web build (readme). |
| `showIcons` |  | `showIcons` | `bool` | `false` |  |  |
| `label` |  | `semanticLabel` | `String` (required) | `"Mode"` |  | Required in Dart: the caller passes the localized "Mode"; components hold no English strings (decision 20). |
| — |  | `labelOf` | `String Function(FermanMode mode)` (required) |  |  | The localized name of a mode, shown on its tab, from the ARB files; FermanMode carries no label. |

Item type `FermanMode` → `FermanMode` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `id` | yes | `id` | `String` (required) |  |  |  |
| `label` | yes | — | `n/a` |  |  | Omitted: Localized copy; supplied through ModeTabs.labelOf. |
| `icon` | yes | `icon` | `IconName` (required) |  |  |  |

Variants (variant): `segmented`, `underline`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `navigation.css:4`, `navigation.css:6` |  |
| `hover` | pointer | `navigation.css:12` |  |
| `focusVisible` | keyboard | `navigation.css:13` | G22. Inset ring; not drawn on a board. |
| `selected` | data | `navigation.css:14`, `navigation.css:15`, `navigation.css:17` |  |
| `underlineSelected` | data | `navigation.css:22`, `navigation.css:23` | Only for the underline variant. |

Keyboard:

- `ArrowLeft`, `ArrowRight`: move and select (visual direction, wraps; RTL-aware)
- `Home`: first mode
- `End`: last mode

Semantics: role tablist of tabs; label semanticLabel; tabs by labelOf; Flutter: role: tabBar / tab, selected, focusable (only the selected tab is a Tab stop).

Notes:

- Eight modes, as every artboard shows (G09, Q05); the DS constant lists seven.
- Selection follows focus (automatic activation), with a roving Tab stop.
- Each mode keeps its state when the user switches away (IndexedStack, ADR 0011).
- When the modes do not fit, the strip scrolls without a scroll bar, clipped inside the track border; a tab the arrow keys reach is brought into view at once (decision 27). Collapsing to icons in narrow windows is not built (G21, B013).
- The track is 32 px tall (control-h-sm plus padding and border), not the 30 px size hint of FmWindow (G68).

#### FERMAN_MODES

`FermanMode` · enum · tier 1 · `_ds_bundle.js` components/navigation/ModeTabs.jsx, lines 1783–1862; `FmWindow` lines 190–191

The eight modes with label and icon, in the drawn order.

Tier: The mode bar of the M1 shell.

Drawn in: FmWindow.

| Value | Label | Icon | Details |
|---|---|---|---|
| `view` | View | `book-open` |  |
| `edit` | Edit | `file-pen-line` |  |
| `comment` | Comment | `message-square` |  |
| `sign` | Fill & Sign | `signature` |  |
| `organize` | Organize | `layout-grid` |  |
| `convert` | Convert | `refresh-cw` |  |
| `protect` | Protect | `shield` |  |
| `tools` | Tools | `wrench` |  |

Semantics: role none; label none.

Notes:

- tools (wrench) comes from FmWindow MODE_IDS and MODE_ICONS; FERMAN_MODES in the bundle is stale (G09).
- Labels are localized; mode names are proper nouns (readme "Casing"). The enum carries no label: entries list the design's English labels for the ARB files, and ModeTabs.labelOf supplies the localized ones (decision 20).

#### SegmentedControl

`SegmentedControl` · widget · tier 1 · interactive · `_ds_bundle.js` components/navigation/SegmentedControl.jsx, lines 1864–1922

Radio-group of text, icon-and-text or icon-only segments in a sunken track.

Tier: FmWindow View row (Fit, Page layout), FmStart grid or list, FmSettings Theme, paper size, units, channel; sidebar tabs (FmSidebar).

Drawn in: 02 View, 03a Edit text, 03b Edit content, 03c Edit review and translate, 04 Comment, 05a Fill, 05b Sign, 06 Organize, 07 Convert, 09a Tools, 09b Tools, 13b Mobile tasks, FmComments, FmEditPanel, FmSettings, FmSidebar, FmStart, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `options` |  | `options` | `List<SegmentOption<T>>` (required) | `[]` |  |  |
| `value` |  | `value` | `T` (required) |  |  |  |
| `defaultValue` |  | — | `n/a` |  |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `onChange` |  | `onChanged` | `ValueChanged<T>?` |  |  |  |
| `label` |  | `semanticLabel` | `String` (required) |  |  |  |
| `fullWidth` |  | `fullWidth` | `bool` | `false` |  |  |
| `disabled` |  | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | Whole control (Settings, G10). |

Item type `SegmentOption` → `SegmentOption<T>` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `value` | yes | `value` | `T` (required) |  |  |  |
| `label` | yes | `label` | `String?` |  |  |  |
| `icon` | yes | `icon` | `IconName?` |  |  |  |
| `title` | yes | `tooltip` | `String?` |  |  | Tooltip and semantics label of an icon-only segment. |
| `flipRtl` | yes | `flipRtl` | `bool?` |  |  | Passed to Icon; no board sets it. |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | G10. |

Item states:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `navigation.css:28` |  |
| `hover` | pointer | `navigation.css:35` |  |
| `focusVisible` | keyboard | `navigation.css:36` | G22. |
| `checked` | data | `navigation.css:37`, `navigation.css:38` |  |
| `disabled` | prop (`disabled`) | `navigation.css:39` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `navigation.css:26` |  |
| `fullWidth` | prop (`fullWidth`) | `navigation.css:27`, `navigation.css:28` |  |
| `iconOnly` | data | `navigation.css:34` | Segments with an icon and no label get a Tooltip from title. |
| `disabled` | prop (`disabled`) | `navigation.css:39` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |

Keyboard:

- `ArrowLeft`, `ArrowRight`: move and select (visual direction, wraps; RTL-aware)

Semantics: role radiogroup of radios; label semanticLabel; segments by label or title; Flutter: inMutuallyExclusiveGroup, checked, enabled, focusable (only the checked segment is a Tab stop), tooltip.

Notes:

- The bundle does not skip disabled segments when moving with arrows; Flutter skips plain disabled segments and stops on disabled-with-reason ones without selecting them.
- Sidebar tabs are a SegmentedControl over an IndexedStack (ADR 0011).
- fullWidth shares the width equally between the labelled segments; icon-only segments keep their 24 px and pack at the start of the track, because in the bundle their Tooltip wrapper, not the segment, is the flex item (FmSidebar a2-3p, a4-1c).
- State changes are instant: .fm-segment declares no transition, unlike .fm-modetab and .fm-toolbtn.

#### Toolbar

`Toolbar` · widget · tier 1 · `_ds_bundle.js` components/navigation/Toolbar.jsx, lines 2161–2214

Row of tools (bar: the 44 px tool row; floating: a raised pill).

Tier: One tool row per mode in FmWindow.

Drawn in: 02 View, 03a Edit text, 04 Comment, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `variant` | yes | `variant` | `ToolbarVariant` | `"bar"` | `bar`, `floating` |  |
| `label` | yes | `semanticLabel` | `String` (required) |  |  |  |
| `children` | yes | `children` | `List<Widget>` (required) |  |  |  |
| `className` | yes | — | `n/a` |  |  | Omitted: CSS hook. |
| `style` | yes | — | `n/a` |  |  | Omitted: CSS hook. |
| — |  | `overflowLabel` | `String?` |  |  | The name and tooltip of the overflow button and the name of its menu, the localized "More tools" (G21); null gives the bar no overflow menu. |

Variants (variant): `bar`, `floating`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `navigation.css:42`, `navigation.css:43`, `navigation.css:44` |  |

Keyboard:

- `ArrowLeft`, `ArrowRight`: move focus between enabled and disabled-with-reason items (visual direction, wraps; plain disabled items are skipped; skipped while focus is in a text field or select)

Semantics: role toolbar; label semanticLabel; Flutter: explicitChildNodes.

Notes:

- Items stay Tab stops as in the bundle; arrows add quicker movement. Inside a tablist or radiogroup only the Tab stop of that group is visited.
- Disabled-with-reason items stay focusable (decision 1 in COMPONENTS.md), so the arrow keys stop on them as Tab does and their reason can be read; only plain disabled items are skipped.
- Arrow keys follow the order on screen, mirrored in right to left, and leave a focused text field or Select alone, so focus never leaves an open select list (decision 25).
- No Flutter toolbar or group role exists: the toolbar is a semantics container named semanticLabel (decision 24).
- Narrow windows (G21): the row is to collapse to icons with an overflow menu; not built yet (B013).

#### ToolbarSeparator

`ToolbarSeparator` · widget · tier 1 · `_ds_bundle.js` components/navigation/Toolbar.jsx, lines 2161–2214

1 × 20 vertical rule between tool groups.

Tier: Between tool groups in every FmWindow tool row.

Drawn in: 02 View, 03a Edit text, 04 Comment, FmWindow.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `navigation.css:45`, `navigation.css:46` |  |

Semantics: role separator (vertical); label none.

#### ToolbarSpacer

`ToolbarSpacer` · widget · tier 1 · `_ds_bundle.js` components/navigation/Toolbar.jsx, lines 2161–2214

Flexible gap inside a Toolbar.

Tier: Pushes trailing switches and buttons to the end of FmWindow tool rows.

Drawn in: FmWindow.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `navigation.css:47` |  |

Semantics: role none; label none.

#### ToolbarGroup

`ToolbarGroup` · widget · tier 2 · `_ds_bundle.js` components/navigation/Toolbar.jsx, lines 2161–2214

Labelled group of tools inside a Toolbar.

Tier: No board uses it.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` |  | `semanticLabel` | `String` (required) |  |  |  |
| `children` |  | `children` | `List<Widget>` (required) |  |  |  |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `navigation.css:48` |  |

Semantics: role group; label semanticLabel.

#### ToolButton

`ToolButton` · widget · tier 1 · interactive · `_ds_bundle.js` components/navigation/ToolButton.jsx, lines 2110–2159

Tool-row button: icon and label (inline or stacked), toggle, menu caret and colour swatch.

Tier: Every tool in every FmWindow tool row; M1 shows each one, most disabled with the future-version tooltip.

Drawn in: 03a Edit text, 04 Comment, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `icon` | yes | `icon` | `IconName?` |  |  | 16 px inline, 20 px stacked. |
| `label` | yes | `label` | `String` (required) |  |  |  |
| `showLabel` | yes | `showLabel` | `bool` | `true` |  | false: icon-only with the label as tooltip and semantics label. |
| `layout` | yes | `layout` | `ToolButtonLayout` | `"inline"` | `inline`, `stacked` |  |
| `active` | yes | `active` | `bool?` |  |  | Null: not a toggle. |
| `hasMenu` | yes | `hasMenu` | `bool` | `false` |  | 12 px chevron caret; opens a Menu. |
| `swatch` | yes | `swatch` | `Color?` |  |  | 14 × 3 colour bar near the bottom (annotation colour). |
| `shortcut` | yes | `shortcut` | `KeyCaps?` |  |  |  |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | G10: later-phase tools. |
| `onClick` | yes | `onPressed` | `VoidCallback?` |  |  |  |
| — |  | `onMenuRequested` | `VoidCallback?` |  |  | Called when ArrowDown asks for the menu of a hasMenu button; null falls back to onPressed. |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node; one is created when null. |

Variants (layout): `inline`, `stacked`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `navigation.css:51`, `navigation.css:57` |  |
| `hover` | pointer | `navigation.css:59` |  |
| `pressed` | pointer | `navigation.css:60` |  |
| `focusVisible` | keyboard | `navigation.css:61` | G22. Not drawn on a board. |
| `toggledOn` | prop (`active`) | `navigation.css:62`, `navigation.css:63`, `navigation.css:64` |  |
| `disabled` | prop (`disabled`) | `navigation.css:65`, `navigation.css:66` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". The bundle shows no tooltip on a disabled ToolButton; G10 adds the reason tooltip. Nothing on the boards draws it. |
| `iconOnly` | prop (`showLabel`) | `navigation.css:58` |  |
| `withMenu` | prop (`hasMenu`) | `navigation.css:67` |  |
| `withSwatch` | prop (`swatch`) | `navigation.css:68` |  |
| `stacked` | prop (`layout`) | `navigation.css:69` |  |

Keyboard:

- `Enter`, `Space`: onPressed (opens the menu when hasMenu)
- `ArrowDown`: open the menu when hasMenu (menu-button pattern; not in the bundle)

Semantics: role button (aria-pressed when a toggle, aria-haspopup=menu with a caret); label label; Flutter: button, toggled, enabled, focusable, tooltip.

Notes:

- The bundle shows a tooltip only when icon-only or when a shortcut is given; tool-button tooltips always show the shortcut when one exists (G22).
- Flutter has no aria-haspopup: a hasMenu button is a button with the caret drawn, and ArrowDown or activation asks for the menu (decision 24). The menu itself is placed by the caller (B014).

### Group: pages

#### PageThumbnail

`PageThumbnail` · widget · tier 2 · interactive · `_ds_bundle.js` components/pages/PageThumbnail.jsx, lines 2686–2743

Selectable page preview with number, markers, drag and drop states and rotation.

Tier: Sidebar Pages tab and Organize grid (M2).

Drawn in: 06 Organize, 07 Convert, 14 Tablet and web, DS additions, FmSidebar.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `page` | yes | `page` | `int` (required) |  |  |  |
| `label` | yes | `label` | `String?` |  |  | Replaces the number (page labels such as roman numerals). |
| `selected` | yes | `selected` | `bool` | `false` |  |  |
| `state` | yes | `state` | `PageThumbnailState` | `"idle"` | `idle`, `dragging`, `placeholder` |  |
| `dropIndicator` | yes | `dropIndicator` | `DropIndicator?` |  | `before`, `after` |  |
| `orientation` | yes | `orientation` | `ThumbnailOrientation` | `"vertical"` | `vertical`, `horizontal` | Axis of the drop line. |
| `marker` | yes | `marker` | `ThumbnailMarker?` |  | `edited`, `comment` | Superseded by ThumbnailBadges (fix 5). |
| `width` | yes | `width` | `double` | `112` |  |  |
| `aspect` | yes | `aspect` | `double` | `1.4142` |  |  |
| `rotation` | yes | `rotation` | `int` | `0` |  | 0, 90, 180 or 270. |
| `children` | yes | `child` | `Widget?` |  |  | The rendered page; striped placeholder lines by default. |
| `onClick` | yes | `onPressed` | `VoidCallback?` |  |  |  |
| — |  | `badges` | `Widget?` |  |  | The page's badges (a `ThumbnailBadges`), at its top-end corner; null shows none. |
| — |  | `semanticLabel` | `String?` |  |  | The accessible name, the localized "Page N"; null takes [label] or the number. |
| — |  | `markerTooltip` | `String?` |  |  | The [marker]'s tooltip (the bundle's English "Edited" and "Has comments"); null shows none. |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node; one is created when null. |
| — |  | `autofocus` | `bool` | `false` |  | Whether the thumbnail takes focus when it first appears. |

Variants (state): `idle`, `dragging`, `placeholder`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `pages.css:4`, `pages.css:11` |  |
| `hover` | pointer | `pages.css:9`, `fm-additions.css:105` |  |
| `focusVisible` | keyboard | `pages.css:10`, `fm-additions.css:99` |  |
| `selected` | prop (`selected`) | `pages.css:19`, `pages.css:20`, `pages.css:21` |  |
| `dragging` | prop (`state`) | `pages.css:25` |  |
| `placeholder` | prop (`state`) | `pages.css:26` |  |
| `dropBefore` | prop (`dropIndicator`) | `pages.css:31`, `pages.css:35` |  |
| `dropAfter` | prop (`dropIndicator`) | `pages.css:31`, `pages.css:35` |  |
| `rotated` | prop (`rotation`) |  | Sideways rotations re-proportion the page and add a rotate-cw icon by the number. |

Keyboard:

- `Enter`, `Space`: onPressed (select)
- `ArrowUp`, `ArrowDown`: move between thumbnails in the sidebar list (not in the bundle)

Semantics: role option (in a listbox); label label or "Page N"; Flutter: selected, button, focusable.

Notes:

- Thumbnail badges and their legend (fix 5) are a separate addition: ThumbnailBadges.

### Group: editing

#### PageMark

`PageMark` · widget · tier 2 · `_ds_bundle.js` components/editing/PageMark.jsx, lines 519–544

Inline mark over page text: selection, edited, missing glyph, search hit, current hit, pending and applied redaction.

Tier: Search kinds M2, edited and missing-glyph M3, redaction P2; the FmSettings Editing pane that previews it is disabled in M1.

Drawn in: 00 Fixes, 01 First run and files, 03a Edit text, 03b Edit content, 13a Mobile core, DS additions, DocEkstre, DocKira, FmSettings.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `kind` | yes | `kind` | `PageMarkKind` | `"selection"` | `selection`, `edited`, `missing-glyph`, `search`, `search-current`, `redact-pending`, `redact-applied` |  |
| `title` | yes | `tooltip` | `String?` |  |  | Defaults per kind: edited "Edited", redact-pending "Marked for redaction. Apply redactions to remove it permanently.", redact-applied "Redacted", missing-glyph "This font has no ‘c’. Ferman will use a similar font for this character." |
| `char` | yes | `char` | `String?` |  |  | The missing character for the missing-glyph title. |
| `children` | yes | `child` | `InlineSpan` (required) |  |  | The marked text run. |

Variants (kind): `selection`, `edited`, `missing-glyph`, `search`, `search-current`, `redact-pending`, `redact-applied`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `editing.css:27`, `editing.css:28`, `fm-additions.css:74`, `editing.css:30`, `editing.css:31`, `editing.css:32`, `editing.css:33`, `editing.css:34` | Page-tuned colours, identical in both themes; edited uses the DS additions patch (dotted ink underline, no fill). |

Semantics: role none (mark); label title as tooltip; Flutter: tooltip.

Notes:

- Painted per line fragment (box-decoration-break: clone).

#### SearchReplaceBar

`SearchReplaceBar` · widget · tier 2 · interactive · `_ds_bundle.js` components/editing/SearchReplaceBar.jsx, lines 546–668

Floating find bar with match options, count, previous and next, and an optional replace row and notice.

Tier: Find in M2, replace in P2.

Drawn in: 02 View, 03b Edit content.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `query` | yes | `query` | `String` | `""` |  |  |
| `replaceWith` | yes | `replaceWith` | `String` | `""` |  |  |
| `showReplace` | yes | `showReplace` | `bool` | `false` |  |  |
| `current` | yes | `current` | `int` | `0` |  |  |
| `total` | yes | `total` | `int` | `0` |  |  |
| `matchCase` | yes | `matchCase` | `bool` | `false` |  |  |
| `wholeWord` | yes | `wholeWord` | `bool` | `false` |  |  |
| `regex` | yes | `regex` | `bool` | `false` |  |  |
| `notice` | yes | `notice` | `String?` |  |  | Warning callout (honest font notice). |
| `onQueryChange` | yes | `onQueryChanged` | `ValueChanged<String>?` |  |  |  |
| `onReplaceChange` | yes | `onReplaceChanged` | `ValueChanged<String>?` |  |  |  |
| `onToggleReplace` | yes | `onToggleReplace` | `VoidCallback?` |  |  |  |
| `onToggleOption` | yes | `onToggleOption` | `void Function(SearchOption option, bool value)?` |  |  |  |
| `onPrev` | yes | `onPrevious` | `VoidCallback?` |  |  |  |
| `onNext` | yes | `onNext` | `VoidCallback?` |  |  |  |
| `onReplace` | yes | `onReplace` | `VoidCallback?` |  |  |  |
| `onReplaceAll` | yes | `onReplaceAll` | `VoidCallback?` |  |  |  |
| `onClose` | yes | `onClose` | `VoidCallback?` |  |  |  |
| `autoFocus` | yes | `autofocus` | `bool` | `false` |  |  |
| — |  | `labels` | `SearchReplaceBarLabels` (required) |  |  | The localized texts. |
| — |  | `replaceDisabledReason` | `String?` |  |  | Why replace is unavailable: the localized "Available in a future version" until replace ships (G10). |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `findOnly` | none | `editing.css:37`, `editing.css:38` |  |
| `replaceShown` | prop (`showReplace`) |  |  |
| `noResults` | data | `editing.css:45` | "No results" in danger; previous, next, Replace and Replace all disabled. |
| `optionHover` | pointer | `editing.css:41` |  |
| `optionFocusVisible` | keyboard | `editing.css:42` |  |
| `optionOn` | prop (`matchCase`) | `editing.css:43` |  |
| `notice` | prop (`notice`) | `editing.css:46` |  |

Keyboard:

- `Escape`: onClose
- `Enter`: in the find field: next match
- `Shift+Enter`: in the find field: previous match

Semantics: role search "Find and replace"; count is a polite live region; notice is a status; label "Find and replace"; Flutter: liveRegion (count), toggled (options).

Notes:

- Count text: empty without a query, "N of M", or "No results".

#### TextEditBox

`TextEditBox` · widget · tier 2 · interactive · `_ds_bundle.js` components/editing/TextEditBox.jsx, lines 670–715

Frame around an editable text block: hover dash, selected or editing outline with handles and a font label.

Tier: Editing text on the page (M3).

Drawn in: 01 First run and files, 03a Edit text, 03b Edit content, 03c Edit review and translate, 13a Mobile core, DS additions, DocKira.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `state` | yes | `state` | `TextEditBoxState` | `"editing"` | `idle`, `hover`, `selected`, `editing` | The bundle default is editing. |
| `meta` | yes | `meta` | `String?` |  |  | Frame label such as "IBM Plex Serif · 10.5 pt"; shown when selected or editing. |
| `metaWarning` | yes | `metaWarning` | `bool` | `false` |  | Amber label with a triangle. |
| `showHandles` | yes | `showHandles` | `bool?` |  |  | Null: shown when selected or editing. |
| `width` | yes | `width` | `double?` |  |  |  |
| — |  | `metaPlacement` | `MetaPlacement` | `"above"` | `above`, `below`, `margin` | DS additions fix 1: first free side wins (above, below, margin). |
| `children` | yes | `child` | `Widget` (required) |  |  |  |
| — |  | `inert` | `bool` | `false` |  | Whether the frame is outside Edit mode: no hover frame, no focus, the default cursor. |
| — |  | `semanticLabel` | `String?` |  |  | The block's text for screen readers; null leaves it to [child]. |
| — |  | `onPressed` | `VoidCallback?` |  |  | Called when the block is clicked (the bundle's `onClick`). |
| — |  | `onStateChanged` | `ValueChanged<TextEditBoxState>?` |  |  | Called with the state the keyboard asks for: editing on Enter while selected, selected on Escape while editing. |
| — |  | `focusNode` | `FocusNode?` |  |  | The block's focus node; one is created when null. |
| — |  | `autofocus` | `bool` | `false` |  | Whether the block takes focus when it first appears. |

Variants (state): `idle`, `hover`, `selected`, `editing`. Variants (metaPlacement): `above`, `below`, `margin`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `idle` | none | `editing.css:5` |  |
| `hover` | pointer | `editing.css:6` |  |
| `selected` | prop (`state`) | `editing.css:7`, `editing.css:9` |  |
| `editing` | prop (`state`) | `editing.css:7` |  |
| `metaWarning` | prop (`metaWarning`) | `editing.css:23` |  |
| `metaBelow` | prop (`metaPlacement`) | `fm-additions.css:78` |  |
| `metaMargin` | prop (`metaPlacement`) | `fm-additions.css:79` |  |
| `inertOutsideEdit` | system | `fm-additions.css:64`, `fm-additions.css:65` |  |
| `focusVisible` | keyboard |  | G22. Not drawn for the canvas text block; selected and editing outlines double as focus. Keyboard focus on an idle block uses the hover dash plus --focus-ring. |

Keyboard:

- `Enter`: selected → editing (not in the bundle; M3 editing model)
- `Escape`: editing → selected (not in the bundle)

Semantics: role textbox (multiline) while editing; label block text; Flutter: textField, multiline.

Notes:

- Page-tuned colours (the page is white in both themes).

#### TextCaret

`TextCaret` · widget · tier 2 · `_ds_bundle.js` components/editing/TextEditBox.jsx, lines 670–715

1.5 px ink caret that blinks in hard steps.

Tier: Editing text (M3); also in the comment compose field (M4).

Drawn in: 01 First run and files, 03a Edit text, 03b Edit content, 05a Fill, 13a Mobile core, 13b Mobile tasks, DocKira, FmComments.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `blinking` | none | `editing.css:24` | Blinks every 1.05 s with steps(1); steady under reduced motion. |

Semantics: role none; label none; Flutter: excludeSemantics.

### Group: annotations

#### AnnotationTools

`AnnotationTools` · widget · tier 1 · interactive · `_ds_bundle.js` components/annotations/AnnotationTools.jsx, lines 2216–2356

Comment tool row: one ToolButton per AnnotationTool, a separator and a colour radio group.

Tier: The Comment mode tool row in FmWindow; M1 draws it with the tools disabled.

Drawn in: FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `tool` |  | `tool` | `AnnotationTool` | `"highlight"` |  | Bundle default (defaultTool) is highlight. |
| `defaultTool` |  | — | `n/a` | `"highlight"` |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `onToolChange` |  | `onToolChanged` | `ValueChanged<AnnotationTool>?` |  |  |  |
| `color` |  | `color` | `AnnotationColor` | `"yellow"` | `yellow`, `green`, `blue`, `pink`, `orange`, `red`, `ink` |  |
| `defaultColor` |  | — | `n/a` | `"yellow"` |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `onColorChange` |  | `onColorChanged` | `ValueChanged<AnnotationColor>?` |  |  |  |
| `showLabels` |  | `showLabels` | `bool` | `false` |  | FmWindow shows labels. |
| `variant` |  | `variant` | `ToolbarVariant` | `"bar"` | `bar`, `floating` |  |
| `tools` |  | `tools` | `List<AnnotationTool>` | `"ANNOTATION_TOOLS"`; Dart: `AnnotationTool.values` |  |  |
| — |  | `disabledReasons` | `Map<AnnotationTool, String>` | `{}` |  | Per-tool reason (G10): that tool renders as a disabled-with-reason ToolButton (still focusable, tooltip and hint, activation does nothing). M1 passes "Available in a future version" for every unshipped tool. |
| — |  | `colorsDisabledReason` | `String?` |  |  | Reason for the whole colour radiogroup (G10): disabled-with-reason swatches, still focusable. Independent of colorsDisabled, which follows the active tool. |
| — |  | `semanticLabel` | `String` (required) |  |  | The accessible name of the row, the localized "Comment tools" (the bundle hard-codes the English name). |
| — |  | `toolLabelOf` | `String Function(AnnotationTool tool)` (required) |  |  | The localized name of a tool: its label, tooltip and accessible name. |
| — |  | `colorsSemanticLabel` | `String` (required) |  |  | The accessible name of the colour group, the localized "Color". |
| — |  | `colorLabelOf` | `String Function(AnnotationColor color)` (required) |  |  | The localized name of a colour, its accessible name (the design names ink Black). |
| — |  | `onToolMenuRequested` | `ValueChanged<AnnotationTool>?` |  |  | Called with a tool that has a menu when ArrowDown asks for the menu; null falls back to selecting the tool. |
| — |  | `overflowLabel` | `String?` |  |  | The name of the overflow button of a narrow row, the localized "More tools" (G21); null gives the row no overflow menu. |

Item type `AnnotationTool` → `AnnotationTool` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `id` | yes | `id` | `String` (required) |  |  |  |
| `icon` | yes | `icon` | `IconName` (required) |  |  |  |
| `label` | yes | — | `n/a` |  |  | Omitted: Localized copy; supplied through AnnotationTools.toolLabelOf. |
| `key` | yes | `shortcut` | `String?` |  |  | Single-key shortcut. |
| `colored` | yes | `colored` | `bool` | `false` |  |  |
| `menu` | yes | `hasMenu` | `bool` | `false` |  |  |

Variants (variant): `bar`, `floating`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `toolActive` | prop (`tool`) | `navigation.css:62`, `navigation.css:68` | The active coloured tool shows a swatch of the current colour. |
| `colorHover` | pointer | `annotations.css:42` |  |
| `colorFocusVisible` | keyboard | `annotations.css:43` | G69. The focus ring replaces the swatch's own rings and wins over the checked rings, which the CSS cascade puts last (G22). |
| `colorChecked` | data | `annotations.css:44` |  |
| `colorsDisabled` | data | `annotations.css:39` | Opacity 0.4 and aria-disabled when the active tool is not coloured (inline style in the bundle). The swatches are then plain disabled: skipped by Tab and the arrows, inert (G69). Each swatch is dimmed under its focus ring rather than the group as a whole (decision 26). |
| `toolDisabledWithReason` | prop (`disabledReasons`) |  | G10. Tooltip: "Available in a future version". A tool with a reason renders as ToolButton disabledWithReason. The bundle has no disabled tools; M1 draws the row with every unshipped tool disabled (ROADMAP step 8). |
| `colorsDisabledWithReason` | prop (`colorsDisabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled styling of colorsDisabled with the reason as tooltip and hint; the swatches stay focusable and do not change the colour. |

Keyboard:

- `ArrowLeft`, `ArrowRight`: move focus between the tools as in Toolbar (enabled and disabled-with-reason tools; plain disabled tools are skipped)
- `V`, `H`, `U`, `S`, `N`, `X`, `C`, `P`, `R`, `M`: select the tool (single-key shortcuts from the shortcut table)
- `ArrowLeft`, `ArrowRight`: inside the colour group: move and check (radio-group pattern; not in the bundle)

Semantics: role toolbar "Comment tools" with a radiogroup "Color"; label semanticLabel ("Comment tools"); tools by toolLabelOf; the colour group by colorsSemanticLabel ("Color") and colours by colorLabelOf; Flutter: checked (colour), toggled (tool).

Notes:

- FmWindow passes its own tool list (11 tools); see AnnotationTool.
- Tool and colour names, and the names of the row and the colour group, come from the caller; the bundle hard-codes English (decision 20).
- The palette has no orange (the bundle's PALETTE): with color orange the active tool's swatch shows orange, no swatch is checked and the first one is the Tab stop (G69).
- Menus of the hasMenu tools (Shapes, Stamp, Measure) are asked for through onToolMenuRequested; the row builds none (B014).

#### ANNOTATION_TOOLS

`AnnotationTool` · enum · tier 1 · `_ds_bundle.js` components/annotations/AnnotationTools.jsx, lines 2216–2356; `FmWindow` lines 233–237

The comment tools in the drawn order, with icon, label, single-key shortcut, colour and menu flags.

Tier: The Comment tool row of the M1 shell.

Drawn in: FmWindow.

| Value | Label | Icon | Details |
|---|---|---|---|
| `select` | Select | `mouse-pointer-2` | key V |
| `highlight` | Highlight | `highlighter` | key H, coloured |
| `underline` | Underline | `underline` | key U, coloured |
| `strikethrough` | Strikethrough | `strikethrough` | key S, coloured |
| `note` | Note | `sticky-note` | key N, coloured |
| `text` | Text | `type` | key X |
| `callout` | Callout | `message-square` | key C |
| `pen` | Draw | `pen-tool` | key P, coloured |
| `shapes` | Shapes | `shapes` | key R, coloured, menu |
| `stamp` | Stamp | `stamp` | menu |
| `measure` | Measure | `ruler` | key M, menu |

Semantics: role none; label none.

Notes:

- Follows FmWindow (lines 233-237) and a4-1, which every board draws: the bundle constant has nine tools, labels text "Text box", draws shapes with the square icon, and lacks callout and measure. Like FERMAN_MODES, the constant is stale.

#### Highlight

`Highlight` · widget · tier 2 · `_ds_bundle.js` components/annotations/Highlight.jsx, lines 11–41

Text-markup annotation: highlight (multiply), underline, strikethrough or squiggly.

Tier: Annotations (M4); existing highlights are rendered by PDFium from M2.

Drawn in: 00 Fixes, DocKira.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `color` | yes | `color` | `AnnotationColor` | `"yellow"` | `yellow`, `green`, `blue`, `pink`, `orange`, `red`, `ink` | Any colour is also accepted by the bundle; Dart adds customColor. |
| — |  | `customColor` | `Color?` |  |  |  |
| `variant` | yes | `variant` | `HighlightVariant` | `"highlight"` | `highlight`, `underline`, `strikethrough`, `squiggly` |  |
| `children` | yes | `child` | `InlineSpan` (required) |  |  |  |

Variants (variant): `highlight`, `underline`, `strikethrough`, `squiggly`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `annotations.css:5`, `annotations.css:6`, `annotations.css:7`, `annotations.css:8`, `annotations.css:9` |  |

Semantics: role none (mark); label none.

Notes:

- Document colours, the same in both themes.

#### StickyNote

`StickyNote` · widget · tier 2 · interactive · `_ds_bundle.js` components/annotations/StickyNote.jsx, lines 262–352

Note annotation: a collapsed pin or an expanded card with replies and a reply field.

Tier: Comments (M4).

Drawn in: 04 Comment, DocKira.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `collapsed` |  | `collapsed` | `bool` | `false` |  |  |
| `color` |  | `color` | `AnnotationColor` | `"yellow"` | `yellow`, `green`, `blue`, `pink`, `orange`, `red`, `ink` | Bundle COLORS: yellow, green, blue, pink, orange. |
| `author` |  | `author` | `String` (required) |  |  |  |
| `time` |  | `time` | `String` (required) |  |  | Formatted by the caller from the region setting. |
| `text` |  | `text` | `String` (required) |  |  |  |
| `replies` |  | `replies` | `List<NoteReply>` | `[]` |  |  |
| `onToggle` |  | `onToggle` | `VoidCallback?` |  |  |  |
| `onReply` |  | `onReply` | `ValueChanged<String>?` |  |  | Null hides the reply field (the bundle hides it only for an explicit null). |
| `children` |  | `child` | `Widget?` |  |  |  |
| — |  | `semanticLabel` | `String` (required) |  |  | The accessible name of the pin and the card, the localized `Note from <author>`. |
| — |  | `moreLabel` | `String` (required) |  |  | The name and tooltip of the More button, the localized "More". |
| — |  | `closeLabel` | `String` (required) |  |  | The name and tooltip of the Close button, the localized "Close note". |
| — |  | `onMore` | `VoidCallback?` |  |  | Called when the card's More button is pressed; null disables it with "Available in a future version". |
| — |  | `replyPlaceholder` | `String?` |  |  | The reply field's placeholder and name, the localized "Reply"; null shows none. |

Item type `NoteReply` → `NoteReply` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `author` | yes | `author` | `String` (required) |  |  |  |
| `time` | yes | `time` | `String` (required) |  |  |  |
| `text` | yes | `text` | `String` (required) |  |  |  |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `collapsed` | prop (`collapsed`) | `annotations.css:12` |  |
| `pinFocusVisible` | keyboard | `annotations.css:13` |  |
| `expanded` | prop (`collapsed`) | `annotations.css:14`, `annotations.css:15`, `annotations.css:21` |  |
| `headButtonHover` | pointer | `annotations.css:19` |  |

Keyboard:

- `Enter`, `Space`: pin: expand, focus moves into the card
- `Enter`: reply field: send
- `Escape`: card: close and return focus to the pin (board a4-1d; not in the bundle)

Semantics: role button (pin) / dialog (card) "Note from <author>"; label "Note from <author>"; Flutter: button, namesRoute (card).

#### Stamp

`Stamp` · widget · tier 2 · `_ds_bundle.js` components/annotations/Stamp.jsx, lines 43–68

Rubber-stamp annotation with a double border, uppercase label and optional meta line.

Tier: Stamps (M4).

Drawn in: 03c Edit review and translate, 04 Comment.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `label` | yes | `label` | `String` | `"Approved"` |  |  |
| `tone` | yes | `tone` | `StampTone` | `"seal"` | `seal`, `ink`, `green`, `neutral` |  |
| `meta` | yes | `meta` | `String?` |  |  |  |
| `rotation` | yes | `rotation` | `double` | `-3` |  | Degrees. |
| `lang` | yes | `locale` | `Locale?` |  |  | Casing follows the locale: Turkish uppercases i to İ (ARCHITECTURE §11.2). |
| `size` | yes | `fontSize` | `double` | `18` |  |  |
| `style` | yes | — | `n/a` |  |  | Omitted: CSS hook. |
| — |  | `semanticLabel` | `String?` |  |  | The accessible name; null reads [label] and [meta]. |

Variants (tone): `seal`, `ink`, `green`, `neutral`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `annotations.css:26`, `annotations.css:32`, `annotations.css:33`, `annotations.css:34`, `annotations.css:35`, `annotations.css:36` |  |

Semantics: role img; label "Stamp: <label>, <meta>"; Flutter: image, label.

Notes:

- Seal red is reserved for stamps and brand moments (manifest card "Ink & seal").

### Group: fill-sign

#### PdfFormField

`PdfFormField` · widget · tier 2 · interactive · `_ds_bundle.js` components/fill-sign/PdfFormField.jsx, lines 1063–1183

On-page form field: text, multiline, date, dropdown, checkbox, radio or signature, with empty, filled, focus, error and read-only states.

Tier: Form filling (M4).

Drawn in: 05a Fill, DocForm, DocKira.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `type` | yes | `type` | `PdfFormFieldType` | `"text"` | `text`, `multiline`, `date`, `dropdown`, `checkbox`, `radio`, `signature` |  |
| `state` | yes | `state` | `PdfFormFieldState?` |  | `empty`, `filled`, `focus`, `error`, `readonly` | Null derives it: error if error is set, filled if value, checked or signedAs, else empty. |
| `value` | yes | `value` | `String?` |  |  |  |
| `placeholder` | yes | `placeholder` | `String?` |  |  |  |
| `label` | yes | `label` | `String?` |  |  |  |
| `required` | yes | `required` | `bool` | `false` |  |  |
| `error` | yes | `error` | `String?` |  |  |  |
| `options` | yes | `options` | `List<String>` | `[]` |  |  |
| `width` | yes | `width` | `double` | `160` |  |  |
| `checked` | yes | `checked` | `bool?` |  |  |  |
| `signedAs` | yes | `signedAs` | `String?` |  |  |  |
| `onChange` | yes | `onChanged` | `ValueChanged<String>?` |  |  |  |
| `onClick` | yes | `onPressed` | `VoidCallback?` |  |  |  |
| — |  | `signHereLabel` | `String?` |  |  | The signature box's call to action, the localized "Sign here". |
| — |  | `semanticLabel` | `String?` |  |  | The accessible name; null takes [label] (and for a signature, "Sign here" or [signedAs]). |
| — |  | `focusNode` | `FocusNode?` |  |  | The field's focus node; one is created when null. |
| — |  | `autofocus` | `bool` | `false` |  | Whether the field takes focus when it first appears. |

Variants (type): `text`, `multiline`, `date`, `dropdown`, `checkbox`, `radio`, `signature`. Variants (state): `empty`, `filled`, `focus`, `error`, `readonly`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `empty` | none | `fill-sign.css:6` |  |
| `hover` | pointer | `fill-sign.css:12`, `fm-additions.css:106` |  |
| `focusVisible` | keyboard | `fill-sign.css:15` | The focus state doubles as the keyboard focus look. |
| `filled` | prop (`state`) | `fill-sign.css:16` |  |
| `error` | prop (`state`) | `fill-sign.css:17`, `fill-sign.css:20` |  |
| `readOnly` | prop (`state`) | `fill-sign.css:18` |  |
| `required` | prop (`required`) | `fill-sign.css:19` |  |
| `signed` | prop (`signedAs`) | `fill-sign.css:25` |  |

Keyboard:

- `Space`: checkbox or radio: toggle (not in the bundle, which handles clicks only)
- `Enter`, `Space`: signature: start signing
- `Tab`, `Shift+Tab`: next or previous field (FmWindow field navigation)

Semantics: role per type: textbox, combobox, checkbox, radio, button (signature); label label; "Sign here" or "Signed by <name>"; Flutter: textField, checked, button, hint (error).

Notes:

- Page-tuned colours: the page is white in both themes.

#### SignaturePad

`SignaturePad` · widget · tier 2 · interactive · `_ds_bundle.js` components/fill-sign/SignaturePad.jsx, lines 1924–2108

Draw, type or image signature capture with two ink colours, Clear and "Save on this device".

Tier: Signing (M4).

Drawn in: 05a Fill.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `mode` |  | `mode` | `SignatureMode` | `"draw"` | `draw`, `type`, `image` | Bundle default (defaultMode) is draw. |
| `defaultMode` |  | — | `n/a` | `"draw"` |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `onModeChange` |  | `onModeChanged` | `ValueChanged<SignatureMode>?` |  |  |  |
| `name` |  | `initialName` | `String` | `""` |  |  |
| `ink` |  | `ink` | `Color` | `"#1F1D1A"` |  | Black #1F1D1A or Blue #1A3170. |
| `defaultInk` |  | — | `n/a` | `"#1F1D1A"` |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `saveForLater` |  | `saveForLater` | `bool` | `true` |  |  |
| `onChange` |  | `onChanged` | `ValueChanged<SignatureValue>?` |  |  |  |
| `initialStrokes` |  | `initialStrokes` | `List<List<Offset>>` | `[]` |  |  |
| — |  | `labels` | `SignaturePadLabels` (required) |  |  | The localized texts. |
| — |  | `onInkChanged` | `ValueChanged<Color>?` |  |  | Called with the ink the user picks; null makes the inks inert. |
| — |  | `onSaveForLaterChanged` | `ValueChanged<bool>?` |  |  | Called when "Save on this device" is toggled; null disables it. |

Item type `SignatureValue` → `SignatureValue` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `mode` | yes | `mode` | `SignatureMode` (required) |  | `draw`, `type`, `image` |  |
| `strokes` | yes | `strokes` | `List<List<Offset>>` | `[]` |  |  |
| `text` | yes | `text` | `String` | `""` |  |  |
| `ink` | yes | `ink` | `Color` (required) |  |  |  |
| `empty` | yes | `isEmpty` | `bool` | `true` |  |  |

Variants (mode): `draw`, `type`, `image`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `emptyDraw` | data | `fill-sign.css:35` | "Sign above the line". |
| `drawing` | pointer | `fill-sign.css:36` |  |
| `typed` | prop (`mode`) | `fill-sign.css:37` |  |
| `image` | prop (`mode`) | `fill-sign.css:39` |  |
| `areaFocusVisible` | keyboard | `fill-sign.css:32` |  |
| `inkChecked` | data | `annotations.css:44` |  |

Keyboard:

- `ArrowLeft`, `ArrowRight`: mode SegmentedControl
- `Tab`: reach the drawing area (pointer drawing only; Type mode is the keyboard alternative)

Semantics: role group with a radiogroup "Signature method" and "Ink color"; label "Signature drawing area. Draw with a mouse, trackpad, pen or finger."; Flutter: checked (ink).

Notes:

- Strokes are smoothed with quadratic midpoints at a 2.2 stroke width.

### Group: feedback

#### Banner

`Banner` · widget · tier 2 · `_ds_bundle.js` components/feedback/Banner.jsx, lines 822–862

Inline callout (box) or full-width bar with a tone icon, title, message, actions and dismiss.

Tier: Panel callouts and bars (M2 onward); the M1 boards draw none.

Drawn in: 00 Fixes, 01 First run and files, 03b Edit content, 03c Edit review and translate, 05a Fill, 05b Sign, 08 Protect, 09a Tools, 09b Tools, 11b App, FmEditPanel.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `tone` | yes | `tone` | `BannerTone` | `"info"` | `info`, `success`, `warning`, `danger`, `neutral` |  |
| `variant` | yes | `variant` | `BannerVariant` | `"box"` | `box`, `bar` |  |
| `title` | yes | `title` | `String?` |  |  |  |
| `icon` | yes | `icon` | `IconName?` |  |  | Defaults per tone: info, circle-check, triangle-alert, circle-alert, info. |
| `actions` | yes | `actions` | `List<Widget>` | `[]` |  |  |
| `onDismiss` | yes | `onDismiss` | `VoidCallback?` |  |  | Shows an xs IconButton "Dismiss" without tooltip. |
| `children` | yes | `child` | `Widget?` |  |  |  |
| — |  | `dismissLabel` | `String?` |  |  | The localized name of the Dismiss button ("Dismiss"); required with onDismiss. |

Variants (tone): `info`, `success`, `warning`, `danger`, `neutral`. Variants (variant): `box`, `bar`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `feedback.css:18`, `feedback.css:27`, `feedback.css:29`, `feedback.css:31`, `feedback.css:33`, `feedback.css:35` |  |

Semantics: role alert (danger, warning; assertive: role alert, announced through SemanticsService where supported, polite live region fallback on Android) or status (polite live region); label title and message; Flutter: role: alert, or liveRegion.

Notes:

- Material has MaterialBanner and Banner; import hidden or prefixed.
- Announcements follow decision 21.

#### ProgressBar

`ProgressBar` · widget · tier 2 · `_ds_bundle.js` components/feedback/ProgressBar.jsx, lines 864–897

4 or 6 px track with a determinate or indeterminate fill, label and percentage.

Tier: Inside TaskProgress and the Form panel (M2, M4).

Drawn in: 05b Sign, 07 Convert, 08 Protect, 09b Tools, 13b Mobile tasks, FmFormPanel.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `value` | yes | `value` | `double?` |  |  | 0 to 1. |
| `indeterminate` | yes | `indeterminate` | `bool` | `false` |  |  |
| `tone` | yes | `tone` | `ProgressTone` | `"accent"` | `accent`, `success`, `danger`, `paused` |  |
| `size` | yes | `size` | `ProgressSize` | `"sm"` | `sm`, `md` |  |
| `label` | yes | `label` | `String?` |  |  |  |
| `showValue` | yes | `showValue` | `bool` | `false` |  |  |
| — |  | `valueText` | `String?` |  |  | The percentage as the screen formats it for the region setting ("%40" in Turkish, G34); null shows "N%". |

Variants (tone): `accent`, `success`, `danger`, `paused`. Sizes: `sm`, `md`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `determinate` | none | `feedback.css:42`, `feedback.css:44` |  |
| `indeterminate` | prop (`indeterminate`) | `feedback.css:48` | Under reduced motion the 40 % fill stays still at the start edge (decision 23). |

Semantics: role progressbar; label label; Flutter: role: progressBar, or loadingSpinner while indeterminate (decision 22), value (percent, absent when indeterminate).

Notes:

- Never LinearProgressIndicator from Material.
- The bundle writes the percentage as "N%"; the screen passes valueText formatted for the region (G74, G34).

#### Spinner

`Spinner` · widget · tier 1 · `_ds_bundle.js` components/feedback/Spinner.jsx, lines 899–919

Ring spinner; border 1.5, 2 or 3 px by size; on-accent variant.

Tier: FmWindow: a document tab that is opening and the status-bar "Saving…" state.

Drawn in: 00 Fixes, 01 First run and files, 05b Sign, 07 Convert, 13b Mobile tasks, DS additions, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `size` | yes | `size` | `double` | `16` |  | Border 1.5 at ≤12, 3 at ≥32, else 2. |
| `onAccent` | yes | `onAccent` | `bool` | `false` |  |  |
| `label` | yes | `semanticLabel` | `String?` | `"Loading"`; Dart: `null` |  | The screens pass the localized label; null makes the spinner decorative, for a spinner whose surrounding text already says what is happening (decision 20). |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `spinning` | none | `feedback.css:50`, `feedback.css:51` | 0.8 s linear rotation; it keeps turning under reduced motion, as the CSS animation does (decision 23). |

Semantics: role status; label semanticLabel; Flutter: liveRegion, label.

Notes:

- Never CircularProgressIndicator from Material.

#### TaskProgress

`TaskProgress` · widget · tier 2 · `_ds_bundle.js` components/feedback/TaskProgress.jsx, lines 921–1011

Job card or inline status-bar item with state icon, title, detail, progress and actions.

Tier: Background jobs (indexing in M2, OCR and convert later); FmWindow shows it only with a task.

Drawn in: 01 First run and files, 07 Convert, 10 AI assistant, 11b App, 13b Mobile tasks, FmWindow.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `title` | yes | `title` | `String` (required) |  |  |  |
| `detail` | yes | `detail` | `String?` |  |  |  |
| `value` | yes | `value` | `double?` |  |  |  |
| `indeterminate` | yes | `indeterminate` | `bool` | `false` |  |  |
| `state` | yes | `state` | `TaskState` | `"running"` | `running`, `paused`, `done`, `error` |  |
| `icon` | yes | `icon` | `IconName` | `"scan-text"` |  |  |
| `variant` | yes | `variant` | `TaskProgressVariant` | `"card"` | `card`, `inline` |  |
| `onCancel` | yes | `onCancel` | `VoidCallback?` |  |  |  |
| `onPause` | yes | `onPause` | `VoidCallback?` |  |  |  |
| `onResume` | yes | `onResume` | `VoidCallback?` |  |  |  |
| `primaryAction` | yes | `primaryAction` | `TaskAction?` |  |  | {label, onClick}. |
| `secondaryAction` | yes | `secondaryAction` | `TaskAction?` |  |  |  |
| — |  | `cancelLabel` | `String?` |  |  | The localized name of the Cancel IconButton ("Cancel"); required with onCancel. |
| — |  | `pauseLabel` | `String?` |  |  | The localized label of the Pause button ("Pause"); required with onPause. |
| — |  | `resumeLabel` | `String?` |  |  | The localized label of the Resume button ("Resume"); required with onResume. |

Variants (state): `running`, `paused`, `done`, `error`. Variants (variant): `card`, `inline`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `running` | none | `feedback.css:53`, `feedback.css:55` |  |
| `paused` | prop (`state`) | `feedback.css:58` |  |
| `done` | prop (`state`) | `feedback.css:56` |  |
| `error` | prop (`state`) | `feedback.css:57` |  |
| `inline` | prop (`variant`) | `feedback.css:63`, `feedback.css:64` |  |

Semantics: role status (polite live region); label title and detail; Flutter: liveRegion.

Notes:

- Jobs are async, cancellable and stream progress (ARCHITECTURE.md); Cancel is an IconButton named by the localized cancelLabel, Pause and Resume are Buttons labelled by pauseLabel and resumeLabel.

#### Toast

`Toast` · widget · tier 2 · `_ds_bundle.js` components/feedback/Toast.jsx, lines 1013–1061

Floating notice with a tone icon, title, message, one action and dismiss; stacked bottom-end above the status bar.

Tier: Save failure (M3) and the toast stack (M4).

Drawn in: 00 Fixes, 11b App.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `tone` | yes | `tone` | `ToastTone` | `"neutral"` | `neutral`, `success`, `warning`, `danger` |  |
| `title` | yes | `title` | `String?` |  |  | At most four words (readme). |
| `message` | yes | `message` | `String?` |  |  |  |
| `icon` | yes | `icon` | `IconName?` |  |  | Defaults per tone: info, circle-check, triangle-alert, circle-alert. |
| `action` | yes | `action` | `ToastAction?` |  |  | {label, onClick}: a ghost sm Button in accent text. |
| `onClose` | yes | `onClose` | `VoidCallback?` |  |  |  |
| — |  | `closeLabel` | `String?` |  |  | The localized name of the Dismiss button ("Dismiss"); required with onClose. |

Variants (tone): `neutral`, `success`, `warning`, `danger`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `feedback.css:3`, `feedback.css:9`, `feedback.css:10`, `feedback.css:11`, `feedback.css:16` | Rises in over --dur-slow. |

Semantics: role alert (danger; assertive: role alert, announced through SemanticsService where supported, polite live region fallback on Android) or status (polite live region); label title and message; Flutter: role: alert, or liveRegion.

Notes:

- Never SnackBar (ADR 0011).
- Announcements follow decision 21.
- The toast stack (bottom end, above the status bar, .fm-toast-region) and the timing (errors stay until dismissed, the rest leave after six seconds unless hovered or focused, a11-6) belong to the screen that shows toasts (B011).

### Group: empty

#### DropZone

`DropZone` · widget · tier 1 · interactive · `_ds_bundle.js` components/empty/DropZone.jsx, lines 717–820

Dashed empty state: "Drop a PDF here", Open and New actions, recent files and the on-device footnote.

Tier: The Start empty state (a1-5 via FmStart empty).

Drawn in: 14 Tablet and web, FmStart.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `state` |  | `state` | `DropZoneState` | `"idle"` | `idle`, `over`, `error` | over is also entered while a drag hovers. |
| `title` |  | `title` | `String?` |  |  | Idle only; FmStart passes "Drop a PDF here". |
| `subtitle` |  | `subtitle` | `String?` |  |  |  |
| `onOpen` |  | `onOpen` | `VoidCallback?` |  |  | Primary lg Button "Open a PDF" with the shortcut. |
| `onCreate` |  | `onCreate` | `VoidCallback?` |  |  | lg Button "New blank PDF". |
| `shortcut` |  | `shortcut` | `KeyCaps` | `["⌘","O"]` |  |  |
| `recent` |  | `recent` | `List<RecentFile>` | `[]` |  |  |
| `onOpenRecent` |  | `onOpenRecent` | `ValueChanged<RecentFile>?` |  |  |  |
| `footnote` |  | `footnote` | `String?` | `"Files stay on this device. Ferman never uploads your documents."`; Dart: `null` |  | The screen passes the localized footnote; null shows none (decision 20). |
| `onFiles` |  | `onFiles` | `ValueChanged<List<String>>?` |  |  | Dropped file paths. |
| `minHeight` |  | `minHeight` | `double?` |  |  | FmStart uses 470. |
| — |  | `disabledReason` | `String?` |  |  | Disables drop handling, the Open and New buttons and the recent rows as disabled-with-reason (still focusable, the reason as tooltip and hint) (G10). |
| — |  | `overTitle` | `String?` |  |  | The title while a drag hovers ("Release to open"). |
| — |  | `overSubtitle` | `String?` |  |  | The subtitle while a drag hovers. |
| — |  | `errorTitle` | `String?` |  |  | The title of the error state ("That file isn’t a PDF"). |
| — |  | `errorSubtitle` | `String?` |  |  | The subtitle of the error state. |
| — |  | `openLabel` | `String?` |  |  | The Open button's label ("Open a PDF"); null hides the button. |
| — |  | `createLabel` | `String?` |  |  | The New button's label ("New blank PDF"); null hides the button. |
| — |  | `recentTitle` | `String?` |  |  | The heading above the recent files ("Recent"). |

Item type `RecentFile` → `RecentFile` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `name` | yes | `name` | `String` (required) |  |  |  |
| `meta` | yes | `meta` | `String` (required) |  |  |  |
| `path` | yes | `path` | `String?` |  |  |  |

Item states:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `hover` | pointer | `empty.css:21` |  |
| `focusVisible` | keyboard | `empty.css:22` |  |

Variants (state): `idle`, `over`, `error`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `idle` | none | `empty.css:3`, `empty.css:10` |  |
| `over` | drag | `empty.css:8`, `empty.css:11` | "Release to open"; actions hidden. |
| `error` | prop (`state`) | `empty.css:9`, `empty.css:12` | "That file isn’t a PDF". |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". M1 draws the strip with Open, New and drops disabled until their milestone (ROADMAP step 9); a drag over it does not enter over. Not drawn on a board. |

Keyboard:

- `Tab`: reach Open, New and each recent file (buttons; still reached when disabled with a reason)

Semantics: role region with a heading (title) and buttons; label title; Flutter: header (title).

Notes:

- Desktop drops need desktop_drop (Q17 approved); M1 shows the drop strip disabled with disabledReason "Available in a future version" until its milestone (ROADMAP step 9).
- Copy per state lives in the ARB files; every text is a parameter (overTitle, errorTitle, openLabel and the others), and a null text is not shown (decision 20).
- The dashed border is painted as 3 px dashes with 2 px gaps, and the Open shortcut joins symbol caps ("⌘O") but puts a plus between word caps ("Ctrl+O") (G73).
- Desktop file drops arrive with desktop_drop in M2 (B010).

### Group: overlays

#### CommandPalette

`CommandPalette` · widget · tier 2 · interactive · `_ds_bundle.js` components/overlays/CommandPalette.jsx, lines 2358–2495

Search-first command list in groups, with highlighted matches, hints and shortcuts, over a top scrim.

Tier: Command palette (M4); the M1 title-bar Search button is disabled with the future-version tooltip.

Drawn in: 11b App.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `open` |  | `open` | `bool` | `true` |  |  |
| `inline` |  | `inline` | `bool` | `false` |  | Without the scrim (boards, the gallery). |
| `groups` |  | `groups` | `List<CommandGroup>` | `[]` |  |  |
| `query` |  | `query` | `String?` |  |  |  |
| `defaultQuery` |  | — | `n/a` | `""` |  | Omitted: Uncontrolled React default; Ferman widgets are controlled. |
| `onQueryChange` |  | `onQueryChanged` | `ValueChanged<String>?` |  |  |  |
| `onSelect` |  | `onSelected` | `ValueChanged<CommandItem>?` |  |  |  |
| `onClose` |  | `onClose` | `VoidCallback?` |  |  |  |
| `placeholder` |  | `placeholder` | `String` | `"Search commands, pages and text"` |  |  |
| `emptyText` |  | `emptyText` | `String?` |  |  | Default "No commands match “q”. Press Enter to search the document instead." |
| — |  | `semanticLabel` | `String?` |  |  | The accessible name of the palette ("Command palette"). |
| — |  | `escapeKeys` | `List<String>?` |  |  | The key caps at the end of the input row (["Esc"]); null shows none. |
| — |  | `footerHints` | `List<CommandFooterHint>` | Dart: `const []` |  | The key hints of the footer; empty hides the footer. |

Item type `CommandItem` → `CommandItem` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `id` | yes | `id` | `String` (required) |  |  |  |
| `label` | yes | `label` | `String` (required) |  |  |  |
| `icon` | yes | `icon` | `IconName` | `"command"` |  |  |
| `hint` | yes | `hint` | `String?` |  |  |  |
| `shortcut` | yes | `shortcut` | `KeyCaps?` |  |  |  |
| `keywords` | yes | `keywords` | `String?` |  |  |  |
| — |  | `disabledReason` | `String?` |  |  | Palette items for unshipped features (G10). |

Item states:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `overlays.css:52` |  |
| `active` | keyboard | `overlays.css:54`, `overlays.css:55` | Arrow keys or pointer move. |
| `match` | data | `overlays.css:57` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `open` | prop (`open`) | `overlays.css:45`, `overlays.css:4` |  |
| `empty` | data | `overlays.css:59` |  |
| `focusVisible` | keyboard | `base.css:15` | Focus stays in the search field, which shows no ring; the active option carries the selection tint (aria-activedescendant). |

Keyboard:

- `ArrowDown`, `ArrowUp`: move the active item (stops at the ends)
- `Enter`: run the active item
- `Escape`: onClose

Semantics: role dialog "Command palette" with a combobox and a listbox of options in groups; label "Command palette"; Flutter: scopesRoute, namesRoute, textField, selected (active option).

Notes:

- Matching lowercases with the Turkish locale in the bundle (toLocaleLowerCase("tr")); Flutter matches with the casing rules of the app locale (ARCHITECTURE §11.2).
- aria-activedescendant becomes a polite announcement of the active row on arrow moves; the list scrolls only when the active row is out of view (decision 37).
- Modal like Dialog: root Overlay, ModalScope, its own overlay for popups, shown only while its route is current (decision 41).

#### Dialog

`Dialog` · widget · tier 2 · interactive · `_ds_bundle.js` components/overlays/Dialog.jsx, lines 2497–2592

Modal (or inline) dialog with glyph, question title, description, body and footer actions; focus trapped.

Tier: First dialogs appear in M2 (open errors, password).

Drawn in: 01 First run and files, 02 View, 04 Comment, 05a Fill, 05b Sign, 06 Organize, 07 Convert, 08 Protect, 09a Tools, 09b Tools, 10 AI assistant, 11b App, 14 Tablet and web.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `open` | yes | `open` | `bool` | `true` |  |  |
| `inline` | yes | `inline` | `bool` | `false` |  | Without scrim, modality or trap (boards, the gallery). |
| `title` | yes | `title` | `String` (required) |  |  | The question ("Apply 2 redactions?"). |
| `description` | yes | `description` | `String?` |  |  |  |
| `icon` | yes | `icon` | `IconName?` |  |  |  |
| `tone` | yes | `tone` | `DialogTone` | `"default"` | `default`, `warning`, `danger` |  |
| `size` | yes | `size` | `DialogSize` | `"md"` | `sm`, `md`, `lg` |  |
| `children` | yes | `child` | `Widget?` |  |  |  |
| `actions` | yes | `actions` | `List<Widget>` | `[]` |  | The footer buttons other than Cancel, written in the macOS and Linux order (the affirmative button last); buttonOrder lines them up, reversed on Windows. |
| — |  | `cancelAction` | `Widget?` |  |  | The button that dismisses without acting ("Cancel"): before actions on macOS and Linux, after them on Windows. The bundle's actions node holds it. |
| — |  | `alternateAction` | `Widget?` |  |  | The button that closes another way, without the affirmative action (a1-10b "Don't save"): apart at the start of the footer, after footerStart, on macOS and Linux; between actions and cancelAction on Windows. The bundle passes it as footerStart. |
| — |  | `buttonOrder` | `DialogButtonOrder?` |  | `cancelFirst`, `cancelLast` | The order of actions, alternateAction and cancelAction; null follows the system the app runs on (DialogButtonOrder.current: cancelLast on Windows, cancelFirst elsewhere). |
| `footerStart` | yes | `footerStart` | `Widget?` |  |  | At the start of the footer on every system (a checkbox, a link). |
| `onClose` | yes | `onClose` | `VoidCallback?` |  |  | Shows the close IconButton and enables Escape and scrim clicks. |
| `closeLabel` | yes | `closeLabel` | `String` | `"Close"` |  |  |

Variants (tone): `default`, `warning`, `danger`. Sizes: `sm`, `md`, `lg`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `open` | prop (`open`) | `overlays.css:7`, `overlays.css:3` | Rises in over --dur-slow. |
| `warning` | prop (`tone`) | `overlays.css:18` |  |
| `danger` | prop (`tone`) | `overlays.css:17` |  |
| `focusVisible` | keyboard | `overlays.css:12` | The container takes focus without a ring when nothing inside can. |

Keyboard:

- `Escape`: onClose
- `Tab`, `Shift+Tab`: cycle inside the dialog (trap)
- `initial`: focus the [data-autofocus] element, else the first tabbable in the body, else the dialog; restore focus on close

Semantics: role dialog, or alertdialog for the danger tone (modal); label title; description as hint; Flutter: scopesRoute, namesRoute, role: dialog / alertDialog.

Notes:

- Never showDialog, AlertDialog or the Material Dialog (ADR 0011); shown through Ferman routes or OverlayPortal.
- Footer button order follows the platform through buttonOrder (DialogButtonOrder.current by default): on macOS and Linux alternateAction stands apart at the start after footerStart, and the end holds cancelAction, then actions with the affirmative button last (a1-10b: "Don't save" … Cancel, Save; G15); on Windows the end holds actions reversed, the affirmative button first, then alternateAction, then cancelAction (f6a: primary, secondary, then Cancel; a1-10b: Save, Don't save, Cancel; G16). Focus moves through the buttons in the order they are drawn.
- onClose shows the close button, a small ghost core IconButton (x) named by closeLabel, which is required with onClose (decision 20).
- Modal instances open in the root Overlay, above the title bar, and count in ModalScope while shown; popups inside them open in the modal layer's own overlay; a modal shows only while its route is current (hidden, it keeps its state and stops counting); inline ones do none of this (decision 41).

#### Menu

`Menu` · widget · tier 2 · interactive · `_ds_bundle.js` components/overlays/Menu.jsx, lines 2594–2684

Popup list of items with icons, shortcuts, check marks, separators, headings and submenus.

Tier: Context menus and tool menus (M2); M1 tools with a caret are disabled.

Drawn in: 01 First run and files, 02 View, 03b Edit content, 04 Comment, 06 Organize.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `items` |  | `items` | `List<MenuItem>` | `[]` |  |  |
| `onSelect` |  | `onSelected` | `ValueChanged<MenuItem>?` |  |  |  |
| `onClose` |  | `onClose` | `VoidCallback?` |  |  |  |
| `label` |  | `semanticLabel` | `String?` |  |  |  |
| `autoFocus` |  | `autofocus` | `bool` | `false` |  |  |
| `style` |  | — | `n/a` |  |  | Omitted: CSS hook; position comes from the anchor. |

Item type `MenuItem` → `MenuItem` (declared in the lint config):

| DS field | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `id` | yes | `id` | `String?` |  |  |  |
| `label` | yes | `label` | `String` (required) |  |  |  |
| `icon` | yes | `icon` | `IconName?` |  |  |  |
| `shortcut` | yes | `shortcut` | `KeyCaps?` |  |  |  |
| `danger` | yes | `danger` | `bool` | `false` |  |  |
| `disabled` | yes | `disabled` | `bool` | `false` |  |  |
| — |  | `disabledReason` | `String?` |  |  | G10. |
| `checked` | yes | `checked` | `bool?` |  |  | Not null makes a menuitemcheckbox. |
| `submenu` | yes | `submenu` | `List<MenuItem>?` |  |  |  |
| `flipRtl` | yes | `flipRtl` | `bool?` |  |  |  |
| `separator` | yes | `separator` | `bool` | `false` |  |  |
| `heading` | yes | `heading` | `String?` |  |  |  |

Item states:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `overlays.css:30` |  |
| `hover` | pointer | `overlays.css:35`, `fm-additions.css:104` |  |
| `focusVisible` | keyboard | `overlays.css:35` | Inside menus focus is the stronger ink tint, not a ring (readme "Focus"). |
| `danger` | prop (`danger`) | `overlays.css:36`, `overlays.css:37` |  |
| `checked` | prop (`checked`) | `overlays.css:41` |  |
| `disabled` | prop (`disabled`) | `overlays.css:38`, `overlays.css:39` |  |
| `disabledWithReason` | prop (`disabledReason`) |  | G10. Tooltip: "Available in a future version". Disabled look; the reason shows as tooltip and semantics hint (the future-version text for unshipped features, the specific reason for a capability limit, as in a3-15); stays focusable; activation does nothing. |
| `submenu` | prop (`submenu`) |  | Trailing chevron-right, mirrored in RTL. |
| `separator` | prop (`separator`) | `overlays.css:42` |  |
| `heading` | prop (`heading`) | `overlays.css:43` |  |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `open` | none | `overlays.css:28` | Fades in over --dur-fast. |

Keyboard:

- `ArrowDown`, `ArrowUp`: move (wraps)
- `Home`, `End`: first or last item
- `Enter`, `Space`: activate
- `Escape`: onClose
- `Tab`, `Shift+Tab`: onClose, from a submenu too: the items are not Tab stops, so the host closes the whole menu and returns focus to its trigger, as on Escape (WAI-ARIA closes on Tab but moves focus on; not in the bundle)
- `ArrowRight`: open a submenu (ArrowLeft in RTL; not in the bundle)

Semantics: role menu of menuitem or menuitemcheckbox; label semanticLabel; Flutter: role: menu / menuItem / menuItemCheckbox, checked, enabled.

Notes:

- The bundle skips disabled items when moving; disabled-with-reason items stay reachable so the reason can be read.
- Never PopupMenuButton (ADR 0011).

#### Scrim

`Scrim` · internal · tier 2 · CSS only (overlays.css)

Internal: the dimmed layer behind a modal; the palette variant sits at the top with a lighter tint.

Tier: Behind dialogs (M2) and the palette (M4).

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `top` | `bool` | `false` |  | Command palette placement (14vh from the top). |
| — |  | `onDismiss` | `VoidCallback?` |  |  | Pointer down on the scrim. |
| — |  | `child` | `Widget` (required) |  |  |  |
| — |  | `dismissLabel` | `String?` |  |  | The accessible name of the scrim as a dismiss target ("Close"). |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `overlays.css:3` | Fades in over --dur-base; 38% warm black. |
| `top` | prop (`top`) | `overlays.css:4`, `overlays.css:5` |  |

Semantics: role none (modal barrier); label none; Flutter: ModalBarrier semantics: dismissible when onDismiss is set.

Notes:

- No backdrop blur anywhere (readme "Transparency and blur").

### Group: additions

#### DocumentTab

`DocumentTab` · addition · tier 1 · interactive · `FmWindow` lines 21–28; `DSAdditions` lines 62–65

One open document in the title-bar tab strip: active (attached to the mode bar) or idle, with unsaved dot, loading spinner, lock or repair icon, close button; plus the "+N" overflow and "+" open buttons.

Tier: FmWindow title bar on every editor board; ROADMAP step 8 requires active, idle, unsaved, loading and "+N" overflow with placeholder data.

Drawn in: FmWindow, DS additions.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `name` | `String` (required) |  |  | File name, ellipsized, dir auto; full name in the tooltip. |
| — |  | `active` | `bool` | `false` |  |  |
| — |  | `unsaved` | `bool` | `false` |  | A 7 px dot replaces the close button. |
| — |  | `loading` | `bool` | `false` |  | The spinner (the design's 12 px Spinner "Opening") replaces the icon. Also on idle tabs (G67). |
| — |  | `icon` | `IconName` | `"file-text"` |  | lock for a locked file, wrench for a repaired one, file-x for a broken one. Also on idle tabs (G67). |
| — |  | `onPressed` | `VoidCallback?` |  |  |  |
| — |  | `onClose` | `VoidCallback?` |  |  | xs IconButton "Close document" with ⌘W / Ctrl+W, shown on the active clean tab. |
| — |  | `closeDisabledReason` | `String?` |  |  | Without onClose, the close button is drawn disabled with this reason as its tooltip and semantics hint, so an unfinished close stays visible as drawn (G10). |
| — |  | `unsavedLabel` | `String` (required) |  |  | The localized "Unsaved changes": the dot's tooltip, read after the name when unsaved. |
| — |  | `closeLabel` | `String` (required) |  |  | The localized "Close document": the close button's tooltip and name. |
| — |  | `closeShortcut` | `KeyCaps?` |  |  | The close shortcut as key caps for the platform (⌘ W or Ctrl W), shown in the close button's tooltip. |
| — |  | `spinner` | `Widget?` |  |  | Shown in place of the icon while loading: the design's 12 px Spinner with the localized "Opening" as its semanticLabel, a status node inside the tab. The caller builds it because the label is copy. |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node; one is created when null (DocumentTabStrip passes its own). |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `active` | prop (`active`) | `FmWindow.dc.html:23` |  |
| `idle` | prop (`active`) | `FmWindow.dc.html:24` |  |
| `hover` | pointer | `FmWindow.dc.html:24` | Idle tabs only. |
| `unsaved` | prop (`unsaved`) | `FmWindow.dc.html:23` |  |
| `loading` | prop (`loading`) | `FmWindow.dc.html:23` |  |
| `closeDisabledWithReason` | prop (`closeDisabledReason`) |  | G10. Tooltip: "Available in a future version". The close button of the active clean tab in the disabled look, the reason as tooltip and semantics hint; it stays focusable and activation does nothing (closing documents arrives in M2). |
| `locked` | prop (`icon`) | `01 First run and files.dc.html:257` |  |
| `repaired` | prop (`icon`) | `01 First run and files.dc.html:259` |  |
| `overflow` | data | `FmWindow.dc.html:26` | Ghost sm Button "+N" with a chevron-down; opens the list of the other documents. |
| `focusVisible` | keyboard |  | G22. Not drawn: inset focus ring as on ModeTabs. |

Keyboard:

- `ArrowLeft`, `ArrowRight`: move between tabs (as ModeTabs; not drawn)
- `Enter`, `Space`: activate
- `⌘W`, `Ctrl+W`: close the active document (shortcut table)

Semantics: role tab in the tablist "Open documents"; label file name, plus unsavedLabel when unsaved; Flutter: role: tab, selected, focusable, the spinner's status node (its semanticLabel, "Opening") inside the tab while loading, the close button: a button inside the tab with focus of its own; the tab does not report focus while it has it (decision 28).

Notes:

- Tab widths use --doctab-w 188 and --doctab-w-min 112 (fm-additions.css). The active tab and the idle tab's box are 32 px tall as FmWindow draws them; --doctab-h (28 px) is the idle tab's inner row (G68).
- Idle tabs tint on hover only: FmWindow draws no pressed fill, as on ModeTabs.
- The name tooltip covers the icon and the name; the unsaved dot and the close button have their own (decision 28).
- DocumentTabStrip, not a design-system component, places the tabs and gives them the tab-list semantics and arrow keys; with no tabs it has no tab bar (decision 28).
- The "+" button is an IconButton "Open file"; disabled with the future-version tooltip until M2 (ROADMAP step 8).

#### WindowChrome

`WindowChrome` · addition · tier 1 · `FmWindow` lines 17–34

Window controls in the custom title bar: macOS traffic-light slot, Windows 46 px caption buttons with a red close hover, Linux client-side caption buttons at the end.

Tier: The M1 title bar on macOS, Windows and Linux.

Drawn in: FmWindow, DS additions.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `platform` | `WindowPlatform` (required) |  | `mac`, `win`, `linux` |  |
| — |  | `maximized` | `bool` | `false` |  | Maximize glyph becomes restore, named restoreLabel (not drawn; G66). |
| — |  | `onMinimize` | `VoidCallback?` |  |  |  |
| — |  | `onMaximize` | `VoidCallback?` |  |  |  |
| — |  | `onClose` | `VoidCallback?` |  |  |  |
| — |  | `minimizeLabel` | `String` (required) |  |  | The localized "Minimize". |
| — |  | `maximizeLabel` | `String` (required) |  |  | The localized "Maximize". |
| — |  | `restoreLabel` | `String` (required) |  |  | The localized "Restore", for a maximized window. |
| — |  | `closeLabel` | `String` (required) |  |  | The localized "Close" (the window, not a document). |
| — |  | `paintTrafficLights` | `bool` | `false` |  | Paints the design's placeholder traffic lights in the macOS slot instead of leaving room for the native ones (goldens, the gallery). |
| — |  | `maximizeButtonStates` | `Set<WidgetState>` | Dart: `const <WidgetState>{}` |  | States the maximize button shows in addition to its own, from the window integration (Windows: hover and press while the system owns the button's area for its snap layouts). |
| — |  | `onMaximizeButtonRect` | `ValueChanged<Rect>?` |  |  | Called with the maximize button's rectangle in the coordinates of the Flutter view whenever it moves or changes size, and once for a new callback (Windows snap layouts; Windows and Linux layouts only). |

Variants (platform): `mac`, `win`, `linux`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `macTrafficLights` | prop (`platform`) | `FmWindow.dc.html:18` | Drawn as a placeholder; the real lights are placed natively (Swift) where the design puts them. |
| `winCaption` | prop (`platform`) | `FmWindow.dc.html:33`, `fm-additions.css:23` |  |
| `captionHover` | pointer | `FmWindow.dc.html:33` |  |
| `closeHover` | pointer | `FmWindow.dc.html:33`, `fm-additions.css:24` |  |
| `linuxCaption` | prop (`platform`) |  | G15. Not drawn: client-side decorations with caption buttons at the end (Q12); reuses the Windows layout until the owner checks GNOME and KDE. |

Keyboard:

- `⌘M`, `Alt+F4`, `Ctrl+Q`: window commands from the platform and the shortcut table; caption buttons are not Tab stops, as in native apps

Semantics: role buttons Minimize, Maximize, Close; label minimizeLabel, maximizeLabel (restoreLabel when maximized), closeLabel; the design's t.minimize, t.maximize, t.closeWin; Flutter: button, label.

Notes:

- Windows 11 snap layouts appear on hover over maximize (WM_NCHITTEST, ROADMAP step 8).
- macOS: the 78 × 38 px light slot stays empty for the native traffic lights; paintTrafficLights paints the design's placeholder lights for goldens and the gallery (G70).
- Windows: a pressed caption button shows surface-pressed, the close button stays red; the buttons keep the arrow cursor (G70, G66).
- Linux reuses the Windows layout until GNOME and KDE boards exist (G15, B015).

#### SaveIndicator

`SaveIndicator` · addition · tier 1 · `FmWindow` lines 173–177; `Fixes` lines 67–96

Status-bar save state: unsaved (amber dot), saved on this device with time, saving (spinner), could not save, read-only.

Tier: FmWindow status bar on the M1 shell goldens (f6a shows "Unsaved changes" with placeholder data); real save states arrive in M3.

Drawn in: FmWindow, 00 Fixes.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `state` | `SaveState` | `"unsaved"` | `unsaved`, `saved`, `saving`, `error`, `readonly` |  |
| — |  | `savedAt` | `DateTime?` |  |  | Formatted with RegionFormat.time for region inside savedLabel ("14:32"); without them the caller's label is shown. |
| — |  | `label` | `String` (required) |  |  | The localized text for state ("Unsaved changes"); required, since components hold no English copy. For saved without savedAt, region and savedLabel it carries the formatted time itself. |
| — |  | `region` | `Region?` |  |  | The region whose time format savedAt is shown in (G34), from the region setting. |
| — |  | `savedLabel` | `String Function(String time)?` |  |  | The localized saved text around the formatted time, an ARB message with a placeholder ("Saved on this device · {time}"). |

Variants (state): `unsaved`, `saved`, `saving`, `error`, `readonly`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `unsaved` | prop (`state`) | `FmWindow.dc.html:173`, `00 Fixes.dc.html:88` |  |
| `saved` | prop (`state`) | `FmWindow.dc.html:174`, `00 Fixes.dc.html:90` |  |
| `saving` | prop (`state`) | `FmWindow.dc.html:175` |  |
| `error` | prop (`state`) | `FmWindow.dc.html:176` |  |
| `readOnly` | prop (`state`) | `FmWindow.dc.html:177` |  |

Semantics: role status (polite live region); label the state text; Flutter: liveRegion, label.

Notes:

- Fix 4: the Save button, the tab dot and this indicator always agree.

#### DatePicker

`DatePicker` · addition · tier 2 · interactive · `DocForm` lines 33–37

Popover calendar: month header with previous and next, weekday row, 6 × 7 day grid, format note and Today.

Tier: Date fields in forms (M4).

Drawn in: DocForm.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `value` | `DateTime?` |  |  |  |
| — |  | `month` | `DateTime` (required) |  |  | Displayed month. |
| — |  | `firstDayOfWeek` | `int` | `1` |  | From the region setting (Monday in the drawing). |
| — |  | `formatNote` | `String?` |  |  | "Format DD.MM.YYYY · from the form". |
| — |  | `onChanged` | `ValueChanged<DateTime>?` |  |  |  |
| — |  | `onMonthChanged` | `ValueChanged<DateTime>?` |  |  |  |
| — |  | `onDismiss` | `VoidCallback?` |  |  |  |
| — |  | `region` | `Region` (required) |  |  | The region whose digits the days show. |
| — |  | `semanticLabel` | `String?` |  |  | The accessible name of the calendar ("Choose a date"). |
| — |  | `monthLabel` | `String?` |  |  | The month heading; null formats [month] for the UI language. |
| — |  | `weekdayLabels` | `List<String>?` |  |  | The seven weekday names, Monday first; null takes the UI language's short names. |
| — |  | `previousMonthButton` | `Widget?` |  |  | The "Previous month" IconButton (`chevron-left`, small); null shows none. |
| — |  | `nextMonthButton` | `Widget?` |  |  | The "Next month" IconButton (`chevron-right`, small); null shows none. |
| — |  | `todayButton` | `Widget?` |  |  | The "Today" Button (small, ghost); null shows none. |
| — |  | `autofocus` | `bool` | `false` |  | Whether the day grid takes focus when the calendar appears (as it does when it opens from a date field). |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `DocForm.dc.html:33` |  |
| `selected` | data | `DocForm.dc.html:35` | Accent fill, on-accent text, weight 600. |
| `outsideMonth` | data | `DocForm.dc.html:95` |  |
| `focusVisible` | keyboard |  | G22. Not drawn: inset focus ring on the focused day. |

Keyboard:

- `ArrowLeft`, `ArrowRight`, `ArrowUp`, `ArrowDown`: move by day or week (RTL-aware)
- `PageUp`, `PageDown`: previous or next month
- `Home`, `End`: start or end of the week
- `Enter`, `Space`: choose the focused day
- `Escape`: close

Semantics: role dialog "Choose a date" with a grid of gridcells; label "Choose a date"; days by full date; Flutter: scopesRoute, namesRoute, selected, button, focusable, focused.

Notes:

- Custom popup on every platform, also on mobile where a note asks for the Material picker (G55); never showDatePicker (ADR 0011).

#### MentionList

`MentionList` · addition · tier 2 · interactive · `FmComments` lines 31–32

"@" suggestion list under the comment compose field: "People in this document", initials avatar and name.

Tier: Comment replies (M4).

Drawn in: FmComments.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `people` | `List<MentionCandidate>` (required) |  |  | {initials, name}. |
| — |  | `activeIndex` | `int` | `0` |  |  |
| — |  | `onSelected` | `ValueChanged<MentionCandidate>?` |  |  |  |
| — |  | `onDismiss` | `VoidCallback?` |  |  |  |
| — |  | `onActiveIndexChanged` | `ValueChanged<int>?` |  |  | Called with the index of the person the pointer or the arrow keys make active. |
| — |  | `heading` | `String?` |  |  | The heading above the people ("People in this document"); null shows none. |
| — |  | `semanticLabel` | `String?` |  |  | The accessible name of the list ("Mention someone"). |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `FmComments.dc.html:32` |  |
| `active` | keyboard | `FmComments.dc.html:32` |  |
| `focusVisible` | keyboard | `FmComments.dc.html:31` | Focus stays in the compose field, which shows the field ring; the active person carries the selection tint. |

Keyboard:

- `ArrowDown`, `ArrowUp`: move the active person (focus stays in the compose field)
- `Enter`, `Tab`: insert the mention
- `Escape`: close

Semantics: role listbox "Mention someone" of options; label person name; Flutter: selected.

Notes:

- Mentions travel with the file; Ferman sends no notifications (FmComments footer).

#### CommentCard

`CommentCard` · addition · tier 2 · interactive · `FmComments` lines 25–35

Comment in the panel list: type chip, author, time, quoted text, comment, replies, compose with Resolve and Reply, resolved footer with Reopen.

Tier: Comments panel (M4).

Drawn in: FmComments.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `icon` | `IconName` (required) |  |  | Annotation type: highlighter, sticky-note, square, pen-tool, underline, stamp, strikethrough, type. |
| — |  | `chipColor` | `Color` (required) |  |  |  |
| — |  | `author` | `String` (required) |  |  |  |
| — |  | `time` | `String` (required) |  |  |  |
| — |  | `quote` | `String` (required) |  |  |  |
| — |  | `text` | `String?` |  |  |  |
| — |  | `replies` | `List<NoteReply>` | `[]` |  |  |
| — |  | `expanded` | `bool` | `false` |  |  |
| — |  | `composing` | `bool` | `false` |  |  |
| — |  | `resolvedBy` | `String?` |  |  |  |
| — |  | `onPressed` | `VoidCallback?` |  |  |  |
| — |  | `onResolve` | `VoidCallback?` |  |  |  |
| — |  | `onReply` | `ValueChanged<String>?` |  |  |  |
| — |  | `onReopen` | `VoidCallback?` |  |  |  |
| — |  | `semanticLabel` | `String` (required) |  |  | The accessible name of the card. |
| — |  | `resolveLabel` | `String` (required) |  |  | The Resolve button's label. |
| — |  | `replyLabel` | `String` (required) |  |  | The Reply button's label. |
| — |  | `reopenLabel` | `String` (required) |  |  | The Reopen button's label. |
| — |  | `iconColor` | `Color?` |  |  | The chip icon's colour; null takes page ink (`#1F1D1A`). |
| — |  | `repliesLabel` | `String?` |  |  | The collapsed replies count, such as "2 replies"; null shows none. |
| — |  | `replyPlaceholder` | `String?` |  |  | The reply field's placeholder and name; null shows none. |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `collapsed` | none | `FmComments.dc.html:30` |  |
| `expanded` | prop (`expanded`) | `FmComments.dc.html:76` | Accent border and 1 px accent ring; replies shown. |
| `composing` | prop (`composing`) | `FmComments.dc.html:31` |  |
| `resolved` | prop (`resolvedBy`) | `FmComments.dc.html:76` | 0.78 opacity, green check, "Resolved by …" footer with Reopen. |
| `focusVisible` | keyboard |  | G22. Not drawn: --focus-ring around the card. |

Keyboard:

- `Enter`, `Space`: expand and select the annotation on the page
- `ArrowUp`, `ArrowDown`: move between cards (not drawn)

Semantics: role article; label "<author>, <type> on page N[, resolved][, N replies]"; Flutter: label, button.

Notes:

- Page headers group the cards ("Page 1 · 6").

#### ThumbnailBadges

`ThumbnailBadges` · addition · tier 2 · interactive · `Fixes` lines 98–114; `DSAdditions` lines 60–60; `FmSidebar` lines 38–39

Badges stacked at the thumbnail top-end corner in a fixed order (edited dot, comments, form fields, signature, warnings), each with a tooltip, plus the legend popover.

Tier: Sidebar thumbnails (M2); badges arrive with their features.

Drawn in: 00 Fixes, DS additions, FmSidebar.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| — |  | `badges` | `Set<ThumbnailBadge>` | `[]` |  | Drawn in the fixed order whatever the set order. |
| — |  | `tooltips` | `Map<ThumbnailBadge, String>` | `{}` |  | For example "1 warning · Madde 6 uses a font without ‘ğ’". |

Variants (badge): `edited`, `comments`, `form-fields`, `signature`, `warnings`.

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `edited` | data | `DS additions.dc.html:150` | 8 px accent dot (--edit-changed). |
| `neutralChip` | data | `DS additions.dc.html:151` | 16 px white chip, paper-200 ring, paper-800 icon; comments, form fields, signature. |
| `warning` | data | `DS additions.dc.html:154` | The only coloured chip: amber. |
| `focusVisible` | keyboard | `00 Fixes.dc.html:104` |  |
| `legendOpen` | prop | `FmSidebar.dc.html:39` | Opened by the info IconButton in the Pages header. |

Keyboard:

- `ArrowLeft`, `ArrowRight`, `ArrowUp`, `ArrowDown`: move between badges inside the thumbnail; each announces its tooltip (f5)

Semantics: role group of images with tooltips; label badge tooltip; Flutter: tooltip, focusable.

Notes:

- Badges sit on the white page preview, so their colours do not follow the theme; the text lines step aside (inline-end inset 24%).
- Replaces PageThumbnail.marker.

#### FmNumber

`FmNumber` · addition · tier 2 · interactive · `FmNumber` lines 16–38; `DSAdditions` lines 59–59

Locale-aware number field with the NumberStepper anatomy: formats for the region ("10,5 pt" for Türkiye) and accepts either decimal separator.

Tier: Edit panel sizes and spacing (M3).

Drawn in: FmEditPanel, DS additions.

| DS prop | Lint | Dart | Type | Default | Values | Notes |
|---|---|---|---|---|---|---|
| `value` |  | `value` | `double` | `10.5` |  |  |
| `precision` |  | `precision` | `int` | `1` |  |  |
| `unit` |  | `unit` | `String?` | `"pt"` |  |  |
| `label` |  | `label` | `String?` | `""` |  |  |
| `lang` |  | — | `n/a` | `"en"` |  | Omitted: Formatting follows the region setting, never a prop or the UI language (G34). |
| `width` |  | `width` | `double` | `84` |  |  |
| `error` |  | `error` | `String?` | `""` |  |  |
| — |  | `min` | `double` | `"-Infinity"` |  |  |
| — |  | `max` | `double` | `"Infinity"` |  |  |
| — |  | `step` | `double` | `1` |  |  |
| — |  | `onChanged` | `ValueChanged<double>?` |  |  |  |
| — |  | `region` | `Region` (required) |  |  | The region whose number format the field shows and reads. |
| — |  | `semanticLabel` | `String?` |  |  | The accessible name when no [label] is shown (the board's `aria`). |
| — |  | `disabled` | `bool` | `false` |  | Whether the field is disabled. |
| — |  | `focusNode` | `FocusNode?` |  |  | The focus node of the text control; one is created when null. |

States:

| State | Trigger | Sources | Notes |
|---|---|---|---|
| `default` | none | `FmNumber.dc.html:18` |  |
| `hover` | pointer | `forms.css:17` |  |
| `focusVisible` | keyboard | `forms.css:18` |  |
| `error` | prop (`error`) | `FmNumber.dc.html:36`, `DS additions.dc.html:59` |  |
| `rtl` | system | `DS additions.dc.html:59` |  |

Keyboard:

- `ArrowUp`, `ArrowDown`: ±step (Shift: ×10), as NumberStepper
- `Enter`: commit

Semantics: role spinbutton; label label (aria default "Value"); Flutter: textField, value (formatted), increasedValue, decreasedValue.

Notes:

- Keeps its Fm name (ROADMAP step 7).
- Where porting notes say FermanNumberField, read FmNumber.

<!-- END GENERATED COMPONENT REFERENCE -->
