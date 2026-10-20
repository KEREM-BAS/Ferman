# Design gaps and conflicts

The design in `design/` is the source of truth for how Ferman looks: layout, spacing, typography, colour, icons, states and copy. The [brief](BRIEF.md) is the source of truth for how Ferman behaves. Brief §2 says to record every conflict or gap between the two here, choose the most reasonable option and keep going. This file is that record.

The brief asked for this file to start empty. During planning the owner chose to fill it with the findings of Milestone 0 instead. Entries G01 to G60 were found in the read-only discovery of `design/` and then confirmed by a separate check against the files. Where that check corrected the first wording, the corrected wording is used. G61 was found when the M0 documents were reviewed against the brief, and confirmed against the design.

Related: [design inventory](DESIGN_INVENTORY.md) · [questions](QUESTIONS.md) · [roadmap](ROADMAP.md) · [architecture](ARCHITECTURE.md) · [backlog](BACKLOG.md) · [ADRs](adr/README.md)

## Contents

1. [How this file works](#how-this-file-works)
2. [Entry format](#entry-format)
3. [Summary](#summary)
4. [Entries](#entries)

## How this file works

- **`design/` is read-only.** No gap is fixed by editing the design. Where an entry asks for new or corrected boards, that is a request to the designer. The owner chose on 2026-10-16 ([Q11](QUESTIONS.md#q11)): the missing files come with the next design-system export, corrected or new boards come for the riskiest gaps, and the decisions here stand until a board replaces them; an entry a new board settles becomes Resolved. An entry a board settles only in part stays Decided, and its status says which part the board draws and what is still undrawn. Where a board draws something other than the behaviour the entry chose, the entry keeps its decision for that difference and says so. The first such export arrived on 2026-10-17 as commit 519d42a.
- **Evidence and exports.** Evidence describes the export the text was checked against: text written before 2026-10-17 cites the lines of the export that was in `design/` during M0 and M1, and what that export did not draw; text added on 2026-10-17 cites export 519d42a, which moved many lines and draws some of what was missing.
- **Visuals follow the artboards, behaviour follows the brief.** When an entry decides something the design does not draw, Ferman builds it from existing design-system components and patterns, and the goldens record the result.
- **One decision per entry.** The decision is what the app does. If it depends on the owner, the status says so and links the question; the decision is still in force meanwhile, so work does not wait.
- **Milestone** is the milestone by which the entry must be settled. Some decisions apply earlier, as the entry says. Each milestone's exit check E4 in [ROADMAP.md](ROADMAP.md) requires its entries to be decided or resolved.
- **New entries** found in later milestones are added at the end with the next free id, G62 onwards. Ids are never reused or renumbered, so links from other documents stay valid.
- **Changes.** When a decision changes, the entry is edited in place and its status line says what changed and when.

### Status values

| Status | Meaning |
|---|---|
| Decided | The option is chosen and in force. The owner can still overrule it. |
| Needs owner | The option is in force as a default, but the owner must confirm it. The status links the question in [QUESTIONS.md](QUESTIONS.md). |
| Resolved | Closed. The design was updated, or the implementation shipped with its tests. The entry stays for history. |

### Types

| Type | Meaning |
|---|---|
| export gap | Something the export should contain is missing: files, sources, licences. |
| conflict | The design contradicts the brief, or contradicts itself ("internal to design"). |
| missing screen | A whole screen or dialog that the brief or the design implies is not drawn. |
| missing state | A drawn screen lacks a state: empty, error, loading, result, disabled. |
| missing variant | A platform, theme or language variant of drawn screens is missing. |
| ambiguity | The design allows more than one reading. "Resolved" in the type means the reading is clear but needs confirmation. |

## Entry format

Each entry starts with an HTML anchor, so other documents can link to it as `DESIGN_GAPS.md#g07`:

```markdown
<a id="gNN"></a>

### GNN · Short title

- **Type:** export gap, conflict, missing screen, missing state, missing variant or ambiguity
- **Milestone:** the milestone by which it must be settled (M1 to M5, P2 to P5)
- **Area:** the part of the product
- **Artboards:** the board ids involved, as listed in DESIGN_INVENTORY.md
- **Gap or conflict:** what is missing or contradictory, with files, lines and board ids
- **Decision:** the option chosen, and what is asked of the design
- **Status:** Decided, Needs owner (with the question) or Resolved
- **Evidence:** where to look in design/
```

## Summary

113 entries: 91 Decided, 0 Needs owner, 22 Resolved. The owner's answers of 2026-10-15 moved G06, G07, G09 and G15 from Needs owner to Decided, and those of 2026-10-16 moved G01 to G03, G25, G26, G33, G36, G51 to G53, G56 and G60. G62 to G99 were found in M1. On 2026-10-17 the design export of 519d42a resolved G11 to G13, G24 to G28, G31, G34 to G38, G40 to G44, G59, G61 and G89, and settled G10, G29, G30, G32 and G39 in part (they stay Decided). G100 to G111 were found while planning M2, G112 came with the logo export of 2026-10-19, and G113 with the test corpus.

| Milestone | M1 | M2 | M3 | M4 | M5 | P2 | P3 | P4 | P5 |
|---|---|---|---|---|---|---|---|---|---|
| Entries | 59 | 24 | 11 | 11 | 1 | 1 | 2 | 1 | 1 |
| Resolved | 4 | 9 | 9 | 0 | 0 | 0 | 0 | 0 | 0 |

| ID | Type | Milestone | Area | Gap or conflict | Status |
|---|---|---|---|---|---|
| [G01](#g01) | export gap | M1 | Design system export / app shell reference | Desktop UI kit cited by the brief is missing | Decided ([Q11](QUESTIONS.md#q11)) |
| [G02](#g02) | export gap | M1 | Design system export / components | Component sources, types and cards missing | Decided ([Q11](QUESTIONS.md#q11)) |
| [G03](#g03) | export gap | M1 | Design system export / foundations | Foundation guidelines and specimens missing | Decided ([Q11](QUESTIONS.md#q11)) |
| [G04](#g04) | export gap | M1 | Design system export / iconography | Icon SVGs missing; glyphs exist only as path data | Decided |
| [G05](#g05) | export gap | M1 | Token pipeline | 31 added tokens and 3 overrides live outside the DS tokens | Decided |
| [G06](#g06) | export gap | M1 | Fonts | WOFF2 subsets unusable in Flutter; several scripts uncovered | Decided ([Q08](QUESTIONS.md#q08) groups 1 and 2) |
| [G07](#g07) | export gap | M1 | Fonts / privacy | Fonts loaded from Google Fonts at run time | Decided ([Q08](QUESTIONS.md#q08) groups 1 and 2) |
| [G08](#g08) | export gap | M1 | Fonts / licences | No licence texts for fonts or icons | Decided |
| [G09](#g09) | conflict (internal to design) | M1 | App shell / mode tabs | Artboards show 8 mode tabs; the DS constant lists 7 | Decided ([Q05](QUESTIONS.md#q05)) |
| [G10](#g10) | missing state | M1 | Shell / tool rows / start / palette / settings | No disabled "Available in a future version" state | Decided; partly resolved (the M1 and M2 build boards) |
| [G11](#g11) | conflict | M2 | Start screen / drag-and-drop | Start screen promises conversion and later tools | Resolved (`a1-4-m2`, `a1-5-m1`, `a1-9c`) |
| [G12](#g12) | conflict | M1 | First run | Onboarding marks later-phase features as included | Resolved (`a1-2c-m1`) |
| [G13](#g13) | conflict | M1 | First run / About | Licence shown as GPL-3.0, not Apache-2.0 | Resolved (`a1-2c`, `a11-5`, `a1-2c-m1`) |
| [G14](#g14) | missing screen | M4 | About / licences | No third-party notices screen | Decided |
| [G15](#g15) | missing variant | M1 | App shell / window chrome | No Linux window chrome | Decided ([Q12](QUESTIONS.md#q12)) |
| [G16](#g16) | missing variant | M1 | Windows variants of M1–M4 screens | Windows variants missing for most screens | Decided |
| [G17](#g17) | missing variant | M1 | Dark theme for M1–M4 screens | Dark variants missing for most screens | Decided |
| [G18](#g18) | missing variant | M1 | RTL (ar/fa/he) for M1–M4 screens | Right-to-left variants missing for most screens | Decided |
| [G19](#g19) | missing variant | M1 | Turkish UI locale | Turkish UI drawn only in the editor | Decided |
| [G20](#g20) | missing state | M1 | First run / language selection | Language picker has no translation states | Decided |
| [G21](#g21) | missing state | M1 | App shell responsiveness | Narrow windows and pane resizing not drawn | Decided |
| [G22](#g22) | missing state | M1 | Component library: tooltips, shortcuts, focus | Tooltip shortcuts and focus states mostly undrawn | Decided |
| [G23](#g23) | ambiguity | M1 | App accessibility | App accessibility scope and high contrast undefined | Decided |
| [G24](#g24) | conflict | M1 | First run privacy | Onboarding lists only the update check as network use | Resolved (`a1-2b`) |
| [G25](#g25) | missing screen | M2 | Open: Open with / OS dialog / cold launch | Opening files from the OS not drawn | Resolved (`a1-13`) |
| [G26](#g26) | ambiguity | M2 | Dialogs | Native or custom file pickers not specified | Resolved (`a1-13`, `a1-11b`, `a1-9e`) |
| [G27](#g27) | missing state | M2 | Encrypted / permission-restricted PDFs | Restricted and certificate-encrypted PDFs not drawn | Resolved (`a2-10a`, `a2-10b`) |
| [G28](#g28) | missing state | M2 | Open errors | Unsupported, read-only and missing files not drawn | Resolved (`a1-9c` to `a1-9f`) |
| [G29](#g29) | missing state | M2 | Sidebar and search | Empty sidebar tabs and search states not drawn | Decided; partly resolved (`a2-3m`, `a2-4c`, `a2-4d`) |
| [G30](#g30) | missing state | M2 | Rendering / zoom | Tile loading, zoom and Go to page states not drawn | Decided; partly resolved (`a2-13`) |
| [G31](#g31) | missing state | M2 | Signatures sidebar | Signatures shown as valid before validation exists | Resolved (`a2-14`, `a1-4-m2`) |
| [G32](#g32) | ambiguity | M2 | RTL documents: spread/book/organize order | Page order for right-to-left documents undefined | Decided; partly resolved (`a2-15`) |
| [G33](#g33) | ambiguity | M2 | Roadmap mapping | Drawn features with no milestone in the brief's roadmap | Decided ([Q10](QUESTIONS.md#q10)) |
| [G34](#g34) | conflict | M2 | Locale formatting in English UI | Dates and numbers mix four locale styles | Resolved (`a12-0`) |
| [G35](#g35) | missing screen | M3 | Edit: signed-document warning | No warning before editing a signed document | Resolved (`a3-16a`, `a3-16b`, `a3-12`) |
| [G36](#g36) | ambiguity (resolved) | M3 | Edit: missing glyph | Missing glyph: the design substitutes a similar font by default | Resolved (`a3-3a`, `a3-17`) |
| [G37](#g37) | missing state | M3 | Edit: missing glyph | Missing-glyph steps and outcomes not drawn | Resolved (`a3-17`) |
| [G38](#g38) | missing state | M3 | Edit: overflow | Overflow results not drawn | Resolved (`a3-18`) |
| [G39](#g39) | missing state | M3 | Edit: non-editable content | Text that cannot be edited has no state | Decided; partly resolved (`a3-19`) |
| [G40](#g40) | missing state | M3 | Save / atomic save | Most save failures not drawn | Resolved (`a11-7d` to `a11-7f`) |
| [G41](#g41) | conflict | M3 | Save button states | Save disabled in the error state | Resolved (`a11-7`, `a1-9d`) |
| [G42](#g42) | missing state | M3 | Edit review list | Review list has no empty, confirm or signature states | Resolved (`a3-12`, `a3-12b`) |
| [G43](#g43) | missing state | M3 | Settings › Editing | No saving options in Settings › Editing | Resolved (`a11-1c`) |
| [G44](#g44) | conflict | M3 | Keyboard shortcuts | ⌥⌘S bound to three commands | Resolved (`a11-1j`, `a11-2`, `a11-3`) |
| [G45](#g45) | missing screen | M4 | Organize | Insert, replace and extract dialogs not drawn | Decided |
| [G46](#g46) | missing state | M4 | Comments and annotations | Comment states and commenter name not drawn | Decided |
| [G47](#g47) | missing state | M4 | Form filling / simple signatures | Finish, clear and empty Sign states not drawn | Decided |
| [G48](#g48) | missing state | M4 | Compress / version history | Compress progress and version-history states not drawn | Decided |
| [G49](#g49) | missing state | M4 | Command palette / toasts / background tasks | Palette, toast and task drawer states incomplete | Decided |
| [G50](#g50) | missing variant | M4 | Full settings | Settings variants and follow-up dialogs missing | Decided |
| [G51](#g51) | conflict | M4 | Settings › Privacy / signatures | Revocation lookups (OCSP, CRL) not in the brief's network list | Decided ([Q06](QUESTIONS.md#q06)) |
| [G52](#g52) | ambiguity | M4 | Settings › Privacy | Language packs and local network unclear in Privacy | Decided ([Q06](QUESTIONS.md#q06)) |
| [G53](#g53) | missing state | M5 | Updates | Update states missing | Decided ([Q15](QUESTIONS.md#q15)) |
| [G54](#g54) | conflict | P4 | Overflow choices outside desktop edit | Overflow labels drift in translation and on mobile | Decided |
| [G55](#g55) | conflict | P5 | Mobile / web shell | Mobile and web boards drift from the rules | Decided |
| [G56](#g56) | conflict | P3 | Scan to PDF | Local-network scanner discovery and phone pairing | Decided ([Q06](QUESTIONS.md#q06)) |
| [G57](#g57) | conflict | P2 | Edit images (crop) | Image crop says hidden content is removed | Decided |
| [G58](#g58) | ambiguity | P3 | Flows | Flow B's e-imza steps drawn on the wrong document | Decided |
| [G59](#g59) | ambiguity | M2 | Start / sample documents | e-Devlet form shown as 2 pages; the fixture has 1 | Resolved (`a1-4-m2`) |
| [G60](#g60) | export gap | M1 | Icons | Seven added icons are not from Lucide 0.460.0 | Decided ([Q11](QUESTIONS.md#q11)) |
| [G61](#g61) | conflict | M2 | Search | Accent-insensitive search on by default only for Turkish documents | Resolved (`a2-4a`) |
| [G62](#g62) | conflict | M1 | Comment / annotation tools | The bundle's `ANNOTATION_TOOLS` lists 9 tools; the boards draw 11 | Decided |
| [G63](#g63) | missing state | M1 | Errors | No message drawn for an internal error | Decided |
| [G64](#g64) | conflict (internal to design) | M1 | Typography / localization | Arabic, Hebrew and Hindi UI text: which Plex family comes first | Decided |
| [G65](#g65) | conflict | M1 | Typography / CJK | CJK text: no synthetic bold, which Flutter cannot switch off | Decided |
| [G66](#g66) | missing state | M1 | Window chrome | Title bar states and gestures the boards do not draw | Decided |
| [G67](#g67) | conflict (internal to design) | M1 | Window chrome / document tabs | Idle tabs drawn without the spinner and icons their data carries | Decided |
| [G68](#g68) | conflict (internal to design) | M1 | Window chrome / document tabs and mode bar | Tabs drawn 32 px against `--doctab-h` (28 px) and a 30 px size hint | Decided |
| [G69](#g69) | conflict (internal to design) | M1 | Comment / annotation tools | Colour swatches: focus hidden when checked, a dimmed group still active, no orange | Decided |
| [G70](#g70) | missing state | M1 | Window chrome | Placeholder traffic lights and no pressed caption button | Decided |
| [G71](#g71) | conflict (internal to design) | M1 | Component library: focus | The CSS hides or dims the focus ring of disabled-with-reason controls | Decided |
| [G72](#g72) | conflict (internal to design) | M1 | Component library: IconButton | Pressed secondary and primary icon buttons: core.css and the state sheet disagree | Decided |
| [G73](#g73) | ambiguity | M1 | Start / empty state (DropZone) | Dash pattern unspecified; the Open shortcut runs word caps together | Decided |
| [G74](#g74) | conflict | M1 | Locale formatting / progress | Progress percentages written "N%" in every region | Decided |
| [G75](#g75) | conflict (internal to design) | M1 | Component library: forms | The cascade lets hover win over the disabled look | Decided |
| [G76](#g76) | conflict (internal to design) | M1 | Component library: SearchReplaceBar | The browser lets the find bar's rows overflow its end padding | Decided |
| [G77](#g77) | ambiguity | M1 | Component library: PageThumbnail | Drop-line ends drawn off-centre under border-box; the dim filter also dims the ring | Decided |
| [G78](#g78) | conflict (internal to design) | M1 | Component library: Menu, Select | The menu check is drawn grey, not in the accent the CSS asks for | Decided |
| [G79](#g79) | conflict (internal to design) | M1 | Component library: Checkbox, Radio | Disabled checked radio, dark checked hover and disabled indeterminate drawn wrongly | Decided |
| [G80](#g80) | missing state | M1 | Component library: text fields | No context menu designed; native inputs bring the browser's | Decided |
| [G81](#g81) | conflict (internal to design) | M1 | Keyboard shortcuts | ⌘1…⌘9 jump against the zoom keys; Delete drawn ⌫ on every system | Decided |
| [G82](#g82) | conflict (internal to design) | M3 | Keyboard shortcuts | ⌘B and ⌘K mean one thing in the shell and another in the edit box; ⌘D has three meanings | Decided |
| [G83](#g83) | missing state | M1 | Window chrome / keyboard shortcuts | No keys drawn to minimize, close the window or quit | Decided |
| [G84](#g84) | conflict (internal to design) | M1 | Window chrome / tool row | FmWindow adds a second line: the tool row is 45 px, not 44 | Decided |
| [G85](#g85) | missing state | M1 | Mode bar / document tabs | Save and the tab's close button drawn working before saving and closing exist | Decided |
| [G86](#g86) | missing state | M1 | App shell | Canvas, sidebar and panel with nothing rendered; "+N" named only "+4", in Latin digits | Decided |
| [G87](#g87) | export gap | M1 | Fonts / key caps | macOS key symbols ⌘ ⌥ ⇧ ⌃ ⌫ ⌦ missing from the bundled Plex fonts | Decided |
| [G88](#g88) | ambiguity | M1 | Window chrome / title bar content | Which title bar each screen gets in one window | Decided |
| [G89](#g89) | conflict | M1 | Settings | Settings drawn as its own window, Privacy switches on, a default-app line M1 cannot know | Resolved (`a11-1-m1`, `a11-1w-m1`, `a11-1h-m1`) |
| [G90](#g90) | missing state | M1 | Settings | No state for a settings change that cannot be saved | Decided |
| [G91](#g91) | ambiguity | M1 | Settings › Language and region | Region picker drawn with three sample regions, named inconsistently | Decided |
| [G92](#g92) | ambiguity | M1 | Settings › Language and region | Document languages drawn as Turkish and English for every region | Decided |
| [G93](#g93) | missing variant | M1 | Localization / right to left | Persian and Hebrew: a right-to-left UI with English strings | Decided |
| [G94](#g94) | missing state | M4 | Settings / AI clients | No board draws the MCP connection settings for AI clients | Decided |
| [G95](#g95) | missing state | M1 | App shell responsiveness | How tool rows, mode tabs and panels give way in a narrow window | Decided |
| [G96](#g96) | ambiguity | M1 | Goldens / window chrome / fonts | The native traffic lights and the system font fallback do not exist in `flutter test` | Decided |
| [G97](#g97) | missing variant | M1 | Golden matrix | Which golden variants have a board, which are built from tokens, and the differences expected against the boards | Decided |
| [G98](#g98) | missing variant | M1 | Component library: Kbd, DatePicker | Key caps and weekday names in right to left: no board draws them | Decided |
| [G99](#g99) | missing state | M4 | Keyboard shortcuts | Commands whose keys no M1 control shows | Decided |
| [G100](#g100) | missing state | M2 | Open / document scripts | No board tells the user that a document contains scripts | Decided |
| [G101](#g101) | missing state | M2 | Start / errors | No board draws the engine or PDFium being unavailable | Decided |
| [G102](#g102) | missing state | M2 | Open / the two parsers | No notice drawn for lopdf and PDFium disagreeing | Decided |
| [G103](#g103) | missing variant | M2 | Default PDF app | The default-app prompt is drawn for macOS; Windows and Linux cannot act before M5 | Decided |
| [G104](#g104) | ambiguity | M2 | Open / large files / thumbnails | Where a1-7's progressive open begins; thumbnails drawn waiting for indexing | Decided |
| [G105](#g105) | missing state | M2 | Drag and drop | Drops on a document window not drawn; Combine and the page-grid insert are M4 | Decided |
| [G106](#g106) | missing screen | M2 | Restricted PDFs | The owner-password unlock dialog is not drawn | Decided |
| [G107](#g107) | missing variant | M2 | File actions / platform wording | "Show in Finder" drawn on macOS only; no Linux label | Decided |
| [G108](#g108) | conflict | M1 | Settings | M1 build boards draw the M2 controls of General and every pane enabled | Decided |
| [G109](#g109) | missing state | M2 | Start / recent files | No placeholder for a recent file that needs a password | Decided |
| [G110](#g110) | missing state | M2 | Search | Comment, field and bookmark results have no drawn place; a2-3e shows page text only | Decided |
| [G111](#g111) | conflict | M3 | Saving | a1-11b draws "Optimized for web" enabled; it needs M4's image pipeline | Decided |
| [G112](#g112) | gap | M2 | App icons | The logo board draws icons on mock tiles; the platforms need files at fixed sizes and shapes | Decided |
| [G113](#g113) | conflict | M2 | Test corpus / missing glyph | Madde 6's font has no "ğ", but its drawn text says "Olağan" | Decided |

## Entries

<a id="g01"></a>

### G01 · Desktop UI kit cited by the brief is missing

- **Type:** export gap
- **Milestone:** M1
- **Area:** Design system export / app shell reference
- **Artboards:** none (export structure); shell building blocks `FmWindow`, `FmStart`, `FmSidebar`, `FmEditPanel`, `FmSettings`
- **Gap or conflict:** `design/ui_kits/desktop/index.html`, which the brief cites, does not exist, and there is no `ui_kits/` folder anywhere under `design/`. `_ds_manifest.json` lists the card `ui_kits/desktop/index.html`, and the design system `readme.md` (lines 21, 38 and 67) promises an interactive desktop recreation with JSX sources and its own README. The kit survives only as transpiled code inside `_ds_bundle.js` (App.jsx, Chrome.jsx, Panels.jsx, OrganizeGrid.jsx, Page.jsx and data.js, about 2,480 lines). That code is readable, not minified, and has a source-path comment per module, but it is not exported and no board uses it.
- **Decision:** Treat the `Fm*` building blocks as the canonical shell reference: FmWindow, FmStart, FmSidebar, FmEditPanel and FmSettings, which the Index presents as the shell. Read the transpiled kit in `_ds_bundle.js` for interaction logic only, and never ship it. Ask for a re-export that includes `ui_kits/desktop/` (index.html, JSX sources, README). BRIEF.md stays verbatim; this entry records that the path it cites does not exist.
- **Status:** Decided. The owner answered [Q11](QUESTIONS.md#q11) on 2026-10-16 with (c): the missing files come with the next design-system export, and corrected or new boards come for the riskiest gaps; the owner adds the export to `design/`. Was Needs owner.
- **Evidence:** `find` for a `ui_kits` directory finds nothing, and git history never had one. `_ds_bundle.js` lines 2794–5273 hold the kit; none of its modules is in the `__ds_ns` export list (lines 5274 onwards).

<a id="g02"></a>

### G02 · Component sources, types and cards missing

- **Type:** export gap
- **Milestone:** M1
- **Area:** Design system export / components
- **Artboards:** none (component library)
- **Gap or conflict:** Each of the 11 component folders in `_ds/.../components/` (annotations, core, editing, empty, feedback, fill-sign, forms, navigation, overlays, pages, panels) holds only its `.css` file. The manifest names 45 components with `.jsx` source paths, but no `.jsx`, `.d.ts`, `.prompt.md` or `.card.html` file exists for any of them, and all 11 component cards are missing. The template `templates/editor-screen/EditorScreen.dc.html` listed in the manifest is missing too. The component API can still be recovered: `_adherence.oxlintrc.json` keeps the declared prop names for 38 component and subtype names, with 35 enum-value rules (for example Badge tone `neutral|accent|success|warning|danger|edited`), and the transpiled component code in `_ds_bundle.js` is readable.
- **Decision:** Write the Flutter component spec in M1 from three sources: `_adherence.oxlintrc.json` for props and enums, the transpiled components in `_ds_bundle.js` for behaviour and states, and the component CSS for visuals. The Flutter library keeps the design system's names, variants and states (brief §6). Ask for a re-export with sources, type definitions and cards. Carried out in M1: the spec is `app/test/design/component_spec.json`, described and rendered in [COMPONENTS.md](COMPONENTS.md) (56 entries: the 45 manifest components, Field, Popover and Scrim, and the 8 DS additions), with the ambiguities and the decision taken for each.
- **Status:** Decided. The owner answered [Q11](QUESTIONS.md#q11) on 2026-10-16 with (c): the missing files come with the next design-system export, and corrected or new boards come for the riskiest gaps; the owner adds the export to `design/`. Was Needs owner.
- **Evidence:** Every `components/<group>/` folder holds one file. All 45 `sourcePath` entries and all 11 component cards are missing. The components are exported on `window.FermanDesignSystem_278323` and used live by the boards.

<a id="g03"></a>

### G03 · Foundation guidelines and specimens missing

- **Type:** export gap
- **Milestone:** M1
- **Area:** Design system export / foundations
- **Artboards:** none (design system foundations)
- **Gap or conflict:** The `guidelines/` folder is missing, so all 23 foundation cards in `_ds_manifest.json` have no file: brand seal, voice and wordmark, iconography, the colour cards, layout, elevation, focus, motion, radii, spacing and type. `thumbnail.html`, `SKILL.md` and `_dev/` (ds-dev-shim.js, dev-bundle.js) are missing too. What is lost is the rendered specimens, not the rules. The foundations survive as prose in the design system `readme.md` (lines 99–171), as card subtitles in the manifest, and as values in `tokens/*.css`: the focus ring, motion with reduced-motion overrides, and elevation with dark overrides. "DS additions" draws the interactive states.
- **Decision:** Use `tokens/*.css` with `fm-additions.css` on top ([G05](#g05)), the 304 token entries in the manifest and the readme's "Visual foundations" section as the source of truth for focus, motion, elevation and spacing ([ADR 0012](adr/0012-design-token-pipeline.md)). Ask for the guidelines folder in the re-export.
- **Status:** Decided. The owner answered [Q11](QUESTIONS.md#q11) on 2026-10-16 with (c): the missing files come with the next design-system export, and corrected or new boards come for the riskiest gaps; the owner adds the export to `design/`. Was Needs owner.
- **Evidence:** There is no `guidelines/` directory and all 23 `guidelines/*.html` cards are missing. Readme lines 99–140 state colour, type, spacing, shadows (5 levels), radii, focus (2 px ring, 2 px gap), motion (60, 120, 180 and 260 ms ease-out; 0 ms with reduced motion) and layout (38, 44 and 216 px).

<a id="g04"></a>

### G04 · Icon SVGs missing; glyphs exist only as path data

- **Type:** export gap
- **Milestone:** M1
- **Area:** Design system export / iconography
- **Artboards:** none (iconography)
- **Gap or conflict:** The readme promises `assets/icons/` with "145 Lucide SVGs", but the folder does not exist and there is no `.svg` file anywhere under `design/`. The glyphs exist only as path strings: 145 in `ICON_PATHS` in `_ds_bundle.js` and 84 more in `ds-additions/fm-icons.js`, merged at run time with no overlap, so 229 in total. Index.dc.html still says "Icon set (+64)". The design system draws icons with a 1.5 px stroke (Lucide's own files use 2 px) and rules out an icon font ("No icon font, no PNG icons, no sprite sheet.").
- **Decision:** Generate one SVG per icon from `ICON_PATHS` and `fm-icons.js`, with a 1.5 px `currentColor` stroke, and keep them in `app/assets/icons/` as the exported, provenance-tracked set; not an icon font. The app paints the same path data with a `CustomPainter` (path_parsing) rather than loading the SVGs, because flutter_svg and vector_graphics depend on `http`. The Lucide ISC licence and the Feather MIT notice ship with them ([ADR 0013](adr/0013-fonts-and-icons.md); provenance in [G60](#g60)). Carried out in M1 by `tools/icons`: 229 SVGs, the `IconName` enum and `PROVENANCE.md`.
- **Status:** Decided
- **Evidence:** Readme lines 41 and 146 promise the folder. `_ds_bundle.js` line 74 opens `ICON_PATHS` with exactly 145 keys; `fm-icons.js` adds 84. Readme lines 147–150 give the 1.5 px stroke and "No icon font, no PNG icons, no sprite sheet."

<a id="g05"></a>

### G05 · Added tokens and overrides not merged into the design system

- **Type:** export gap
- **Milestone:** M1
- **Area:** Token pipeline
- **Artboards:** none (token pipeline); used by `FmWindow` and most boards
- **Gap or conflict:** `ds-additions/fm-additions.css` ("additions v1.1, proposed upstream") defines 31 tokens that are not in `tokens/*.css` or in the manifest. Boards, building blocks and the bundle apply 22 of them through `var()`: shell tokens (`--doctab-w`, `--doctab-w-min`, `--win-caption-w`, `--win-close-hover`), on-page marks (`--edit-mark`, `--edit-mark-bar-w`, `--edit-mark-bar-gap`, `--overflow-mark`, `--translated-mark`, `--diff-*`, `--ocr-low*`), `--font-hand-1..3`, `--font-doc-cjk` and `--sheet-radius`. Nine are defined but never applied: `--editbox-meta-h`, `--thumb-badge` and `--doctab-h`, which only the Index and 00 Fixes name in prose, and 6 of the 7 mobile tokens (`--ios-navbar-h`, `--ios-tabbar-h`, `--android-appbar-h`, `--android-navbar-h`, `--fab-size`, `--grabber-w`); only `--sheet-radius` is used, in 13a and 13b. The file also changes 3 existing tokens: `--edit-changed` and `--edit-changed-bg` (teal becomes ink 600 and ink 8 %) and `--font-ui` (extended script stack). It overrides the `--type-*` roles for Japanese, Chinese and Korean, and holds component patches (`.fm-mark--edited`, the edit-box label placement, the FontPicker warning). A generator that reads only `tokens/*.css` would get values wrong, not just miss them. On-page marks are theme-invariant by design-system convention, so only chrome colours need dark values; the one dark rule (`--win-close-hover`) repeats the light value. `--doctab-h` (28 px) disagrees with the 32 px tab height that FmWindow hard-codes.
- **Decision:** The token generator reads `tokens/*.css` first and `fm-additions.css` on top, so additions and overrides win, and reads the component patches together with the component CSS ([ADR 0012](adr/0012-design-token-pipeline.md)). The merge happens in the generator; `design/` is never edited. On-page mark tokens stay theme-invariant. A chrome colour without a dark value is reported by the generator, not invented. Document tabs use the 32 px height that FmWindow draws (visuals follow the artboards), and `--doctab-h` is recorded as stale.
- **Status:** Decided
- **Evidence:** `fm-additions.css` `:root` declares 34 properties, 31 of them new; `--edit-mark` is applied in 9 files and `--font-hand-1` in 5; `--editbox-meta-h`, `--thumb-badge` and `--doctab-h` appear only in the Index token table and the 00 Fixes text. `colors.css` line 142 sets `--edit-changed` to teal `#0F7F72`; DS additions says "Now ink 600 (was teal)".

<a id="g06"></a>

### G06 · Export fonts unusable in Flutter; scripts uncovered

- **Type:** export gap
- **Milestone:** M1
- **Area:** Fonts
- **Artboards:** `a1-1`
- **Gap or conflict:** `assets/fonts` holds only 23 WOFF2 unicode-range subsets, and Flutter bundles TTF or OTF, not WOFF2. The IBM Plex Sans subsets are variable fonts (weight axis), so mapping weights 500 and 600 to the "-400-normal" files is correct. No Plex Sans italic is shipped, yet the FontPicker "Not installed" state sets the font name in italic UI text, which would be synthesised. Plex Serif 500 is used once, in mock document text only. Vietnamese (U+1EA0–1EF1) is not covered, although a1-1 lists "Tiếng Việt". The export has no local fonts for 6 of the 21 UI languages (he, hi, ja, ko, zh-Hans, zh-Hant) or for the signature styles `--font-hand-1..3`; those load only from Google Fonts ([G07](#g07)).
- **Decision:** Bundle IBM's unmodified static TTF files, declared per weight ([ADR 0013](adr/0013-fonts-and-icons.md)): Plex Sans 400, 500 and 600 (the complete files cover Latin, Turkish, Vietnamese, Cyrillic and Greek), Plex Serif, Plex Mono and Plex Sans Arabic (which also covers Persian), with Plex Sans first and Plex Sans Arabic after it, the design's `--font-ui` order. (Measured in M1: the Arabic, Hebrew and Devanagari fonts carry ASCII and Latin-1 but not Latin Extended-A or ế; with one of them first, Flutter builds those letters from it as base plus mark with misplaced marks, so every UI language but CJK uses the `--font-ui` order, [ARCHITECTURE.md §11.5](ARCHITECTURE.md#115-fonts-in-the-ui), [G64](#g64).) Plex Sans Italic 400 is bundled for the drawn FontPicker state: the design declares no italic Plex Sans face, so the boards show a synthesised oblique there, and the app uses IBM's true italic instead. Plex Sans Hebrew and Plex Sans Devanagari are bundled too, as the owner decided. Japanese, Korean and both Chinese scripts use system fonts, with no font packs. The handwriting faces (M4) and similar fonts for missing glyphs (M3) are bundled, as the owner chose for groups 3 and 4 of [Q08](QUESTIONS.md#q08) on 2026-10-16. The design's woff2 subsets are not used.
- **Status:** Decided. The owner answered [Q08](QUESTIONS.md#q08) groups 1 and 2 on 2026-10-15 (bundle Plex Sans Hebrew and Devanagari; CJK from system fonts). Was Needs owner.
- **Evidence:** The five `plex-sans-*-400-normal.woff2` files carry fvar, gvar, avar, HVAR and STAT tables. `forms.css` line 128 sets `font-style: italic` on `.fm-fonttrigger--missing`. The latin-ext range jumps from U+1E9F to U+1EF2.

<a id="g07"></a>

### G07 · Fonts loaded from Google Fonts at run time

- **Type:** export gap
- **Milestone:** M1
- **Area:** Fonts / privacy
- **Artboards:** `a1-1`, `a5-3`
- **Gap or conflict:** `fm-additions.css` line 1 imports 13 families from fonts.googleapis.com at run time: IBM Plex Sans JP, KR, Hebrew and Devanagari, Noto Sans SC, Noto Serif JP, Noto Naskh Arabic, EB Garamond, Cormorant Garamond, Crimson Pro, Caveat, Homemade Apple and Dancing Script. None of them is bundled, and every board links this file. Traditional Chinese has no font at all: "繁體中文" falls back to Noto Sans SC, with Simplified glyph forms, or to a system font. Vietnamese is covered by neither the bundled nor the imported fonts. So the a1-1 picker shows the native names for he, hi, ja, ko, zh-Hans, zh-Hant and vi correctly only when online or through system fonts. The handwriting fonts are used in a5-3, FmSettings and the mobile tasks file.
- **Decision:** The app never fetches fonts at run time and never uses the Google Fonts import ([ADR 0013](adr/0013-fonts-and-icons.md), [ADR 0015](adr/0015-privacy-and-network.md)). The bundled Plex families cover Latin (including Turkish and Vietnamese), Cyrillic, Greek, Arabic and Persian. Japanese, Korean and Chinese use system fonts, and every text style carries the UI locale, so Traditional Chinese gets Traditional forms. Hebrew and Hindi use the bundled Plex Sans Hebrew and Plex Sans Devanagari. The handwriting fonts and the similar-font faces are bundled, as the owner chose for groups 3 and 4 of [Q08](QUESTIONS.md#q08) on 2026-10-16, when M4 and M3 need them. The a1-1 picker is tested for every native language name.
- **Status:** Decided. The owner answered [Q08](QUESTIONS.md#q08) groups 1 and 2 on 2026-10-15; groups 3 (handwriting, M4) and 4 (similar fonts, M3) followed on 2026-10-16 (bundled) and do not change this decision. Was Needs owner.
- **Evidence:** No board lacks the `fm-additions.css` link. `tokens/fonts.css` bundles only Plex Sans, Sans Arabic, Serif and Mono. `--font-ui` stops at Noto Sans SC, with no Traditional Chinese family. M1: `tools/design-refs` serves the 13 families from pinned @fontsource 5.3.0 packages and React, ReactDOM and Babel from npm with SRI hashes matching `design/support.js`, and fails on any other request, so the reference renders are offline too. Glyphs no web font covers fall back to the machine's system fonts, so container and CI renders can differ there; CI renders its own references.

<a id="g08"></a>

### G08 · No licence texts for fonts or icons

- **Type:** export gap
- **Milestone:** M1
- **Area:** Fonts / licences
- **Artboards:** `a11-5`, `a1-2c`, `a13-15`
- **Gap or conflict:** No licence text ships anywhere in the export: no OFL.txt, ISC, MIT or Apache-2.0 file. Licences are only named in comments (`fonts.css`, `_ds_bundle.js`, `fm-icons.js`), in the readme and in the a11-5 credit line "Type: IBM Plex (SIL OFL 1.1) · Icons: Lucide (ISC)", which leaves out Noto, the handwriting and Garamond families, and Feather. No notices screen is drawn behind the a11-5 "Licences" button ([G14](#g14)), and the About copy says GPL-3.0-or-later ([G13](#g13)). The bundled Plex files are Google subsets that keep the Reserved Font Name "Plex". DS additions labels the three typed-signature faces "(Caveat, Homemade Apple, Dancing Script, OFL)", but Homemade Apple is Apache-2.0.
- **Decision:** Ship IBM's unmodified font files, never subsets or renamed copies, so the Reserved Font Name is respected. Ship each family's OFL-1.1 text, the Lucide ISC licence, the Feather MIT notice, and the Apache-2.0 licence of Homemade Apple if that font ships ([Q08](QUESTIONS.md#q08)). All of them feed the third-party notices screen ([G14](#g14); [ADR 0013](adr/0013-fonts-and-icons.md), [ADR 0016](adr/0016-dependency-licence-policy.md)). Until a re-export carries them, the repository holds the OFL-1.1 (IBM Plex), ISC (Lucide) and MIT (Feather) texts for the material already in `design/` in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md), outside `design/`, which stays unedited. That file covers the repository only; the app still ships its own licence files in `app/assets` (brief §2).
- **Status:** Decided
- **Evidence:** A search for licence, OFL, NOTICE and COPYING files finds nothing. Feather is named nowhere. DS additions.dc.html line 36 labels Caveat, Homemade Apple and Dancing Script as "OFL", but Homemade Apple is Apache-2.0.

<a id="g09"></a>

### G09 · Tools: an eighth mode tab

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** App shell / mode tabs
- **Artboards:** `FmWindow` and every desktop and tablet board with a mode, for example `f4a`, `f6`, `f6a`, `a1-7`, `a1-10`, `a1-11`, `a10-1`, `a11-2`, `a11-7`, `a12-1tr`, `a12-1de`, `a9-8`
- **Gap or conflict:** FmWindow (`MODE_IDS`) and every desktop and tablet board with a mode show 8 mode tabs: View, Edit, Comment, Fill & Sign, Organize, Convert, Protect, Tools. The design system constant `FERMAN_MODES` in `_ds_bundle.js` and the design system readme list 7, without Tools. The Index and the a12-1de note ("The mode bar fits all eight modes") confirm 8. The Tools row holds Compress, Compare, Accessibility, PDF/A & preflight, Batch actions, Print, Measure, Version history and AI assistant. Compress is also a Start quick tool, a mobile file action and a batch step; Version history has no entry point other than the Tools row (a9-8). The brief does not list the modes.
- **Decision:** Follow the artboards: 8 mode tabs, including Tools, in the drawn order. `FERMAN_MODES` is stale. Tools items from later phases stay visible but disabled with "Available in a future version". Compress and Version history (M4) work from the Tools row as drawn, and basic Print once [Q10](QUESTIONS.md#q10) confirms M4; Compress also works from Start ([ADR 0011](adr/0011-flutter-state-navigation-components.md)).
- **Status:** Decided. The owner confirmed eight mode tabs on 2026-10-15 ([Q05](QUESTIONS.md#q05)). Was Needs owner.
- **Evidence:** FmWindow.dc.html line 190: `MODE_IDS = ['view','edit','comment','sign','organize','convert','protect','tools']`, labelled Tools, Araçlar, Werkzeuge, أدوات and ツール. `_ds_bundle.js` lines 1785–1813: `FERMAN_MODES` ends at protect.

<a id="g10"></a>

### G10 · No disabled "Available in a future version" state

- **Type:** missing state
- **Milestone:** M1
- **Area:** Shell / tool rows / start / palette / settings
- **Artboards:** `a1-4`, `a1-4b`, `a1-4c`, `a1-11`, `a3-11`, `a3-15`, `a11-2`, `a11-1e`, `a11-1f`, `a11-1g`; drawn disabled in export 519d42a: `a1-2c-m1`, `a1-5-m1`, `a1-4-m2`, `a11-1-m1`, `a11-1w-m1`, `a11-1h-m1`, `a1-9c`, `a1-11b`, `a2-3m` and the View row of the M2 boards
- **Gap or conflict:** The design never uses the words "Available in a future version" and draws no disabled tool button, menu item or segment with a tooltip that gives a reason. The only disabled-with-reason pattern is a3-15 (Bold is unavailable because the font has no bold weight), which is a capability limit. Every later-phase entry point is drawn active: the mode-bar AI icon button (shown when `ai` is set) and the Tools row's "AI assistant" (P4); the Edit row's Add text, Add image, Link, Find & replace and Page marks (P2); the Convert and Protect rows (P2, P3); Digital signature, e-imza and Prepare form in Fill & Sign (P3, P4); the Start quick tools (a1-4, a1-4b, a1-4c); "PDF/A-2b, for archiving" in Save as (a1-11, P4); the OCR offer in a3-11; the a11-2 palette; and the Settings panes a11-1e, a11-1f and a11-1g.
- **Decision:** Add a disabled state to ToolButton, MenuItem, SegmentedControl segments, Button, palette items and Settings controls, with the design system's disabled styling and the tooltip "Available in a future version" (localised). One feature registry (approved by the owner on 2026-10-16; [ROADMAP.md](ROADMAP.md)) drives these states, and every disabled entry point gets a [BACKLOG.md](BACKLOG.md) entry (brief §6). Boards showing which items are disabled in each milestone are asked for in the re-export ([Q11](QUESTIONS.md#q11)); until then the registry is the reference. The Start action cards (FmStart `actions`) have no design-system component. Disabled, a card keeps its frame: the raised fill, the subtle border and the small shadow stay, and the hover border does not appear. Inside, the icon tile turns sunken with the disabled icon colour, and the title and description take the disabled text colour; the key cap stays as drawn. A disabled card stays focusable and gives the reason as its tooltip and semantics hint.
- **Status:** Decided; partly resolved on 2026-10-17 by export 519d42a. Its boards draw the disabled state with "Available in a future version" on the start cards, quick tools and drop-area buttons (a1-5-m1, a1-4-m2), with the card styling this entry specifies; on the welcome tiles (a1-2c-m1); on the default-app button, the Privacy switches and "Show network activity…" (a11-1-m1, a11-1w-m1, a11-1h-m1); on Split view, Read aloud, Present and Dark reading mode in the View row of the nine M2 boards that draw it (FmWindow's new `future` list); on Convert to PDF… (a1-9c), PDF/A-2b in Save as (a1-11b) and the OCR action in Search (a2-3m). Still undrawn: the rows of the other modes (FmWindow can disable each of their tools except the Organize row's, but no board does), menu items, palette items (a11-2), segmented-control segments, the mode bar's AI icon button, and the Settings navigation and search field, which the M1 build boards draw enabled ([G108](#g108)). The feature registry stays the reference for those. On 2026-10-16 the disabled Start action card was specified.
- **Evidence:** A case-insensitive search for "future version", "coming soon", "not yet", "later version" and "coming in" finds nothing. The DS additions state matrix has no disabled ToolButton, MenuItem or SegmentedControl. The Start action card is plain markup in `design/FmStart.dc.html` line 20, with no disabled branch. Implemented in `app/lib/features/start/start_screen.dart` lines 189–318 (M1 phase I3); checked in `app/test/features/start/start_screen_test.dart` line 46. In 519d42a: `design/FmStart.dc.html` lines 20–22 and 38 (the disabled card, quick tools and drop-area buttons) and 82–107 (`gated`); `design/FmWindow.dc.html` line 212 (`future`, read by a `disabled` on every tool but those of the Organize row, lines 107–113); `design/01 First run and files.dc.html` lines 102, 123 and 137 (the a1-2c-m1, a1-4-m2 and a1-5-m1 notes) and 362 (`viewFuture`); `design/02 View.dc.html` line 320 (`viewFuture`).

<a id="g11"></a>

### G11 · Start screen promises conversion and later tools

- **Type:** conflict
- **Milestone:** M2
- **Area:** Start screen / drag-and-drop
- **Artboards:** `a1-3`, `a1-4`, `a1-4b`, `a1-4c`, `a1-5`, `a1-6`, `a1-12`, `a11-4b`, `a11-5`, `a12-2a`, `a12-2b`; resolved by `a1-4-m2`, `a1-5-m1` and `a1-9c` (export 519d42a)
- **Gap or conflict:** FmStart promises conversion in four strings: "PDFs, or Word, Excel and images to convert" (open), "PDFs open in tabs. Other files are converted to PDF first." (drop), "…Word, Excel and image files are converted to PDF." (empty) and the drop-on-tabs line. The a1-6 dragged-file notes read "Excel · converted to PDF" and "Image · converted to PDF". The quick tools Compress, Convert, Sign, Recognize text (OCR), Protect and Compare are enabled on every Start board: a1-3, a1-4, a1-4b, a1-4c, a1-5, a1-6, a1-12, a11-4b, a11-5, a12-2a and a12-2b. Office conversion, OCR and Compare are phase 3, Protect is phase 2, and Compress and simple signatures are M4. No disabled variant exists.
- **Decision:** Until conversion ships (P3), the Start copy speaks of PDFs only (for example "PDF files open in tabs"), and a dropped non-PDF file gets the unsupported-file state ([G28](#g28)), with conversion marked "Available in a future version". The quick tools stay visible as drawn and are disabled with the same tooltip until their milestone. The design's strings return when their features ship. On the M1 start screen (a1-5) the Open file… card says "PDF files", and the drop area says "or open one from your computer.", the shorter subtitle the German and Arabic strings already use. **Where the boards stop:** a1-6 still draws the finished product while files are dragged over the window ("Excel · converted to PDF", and "The Excel file and the image are converted to PDF first." under "Open in 3 tabs"). Under this decision the tabs target keeps only "Each file opens on its own.", the shorter line the Turkish, German and Arabic strings already use. **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** until conversion ships, a file that isn't a PDF shows the note "Can't open yet" with the future-version tooltip while it is dragged (ROADMAP §6 step 6).
- **Status:** Resolved on 2026-10-17 by export 519d42a. The M1 and M2 build boards draw this decision: a1-5-m1 has "PDF files" on Open file… and "or open one from your computer." in the drop area, with every card, quick tool and drop-area button disabled; a1-4-m2 has the drop strip "PDF files open in tabs.", Create PDF and Combine files disabled until M4, Scan to PDF until P3 and every quick tool until its milestone; a1-9c draws a dropped Excel file as an error tab with "That file isn't a PDF." and Convert to PDF… disabled until P3. Was Decided; on 2026-10-16 the M1 start-screen copy was specified.
- **Evidence:** FmStart.dc.html line 58 (the German and Arabic strings carry the same promise); lines 107–110 hold the a1-6 notes; lines 22–24 always render the quick tools as enabled Buttons. The German and Arabic `emptySub` (lines 59 and 60) stop after the open clause: "oder eine Datei von Ihrem Computer öffnen." and "أو افتح ملفًا من جهازك.". Implemented in `app/lib/features/start/start_screen.dart` lines 61–68 and 147–158, with the keys `startOpenFileDescription` and `startDropSubtitle` (`app/lib/l10n/app_en.arb` lines 903 and 963) (M1 phase I3). In 519d42a: `design/01 First run and files.dc.html` lines 119–123 (a1-4-m2), 133–137 (a1-5-m1) and 192–196 (a1-9c); `design/FmStart.dc.html` lines 59–62 (`openSubPdf`, `dropSubPdf` and `emptySubPdf` in English, Turkish and Arabic, and `dropTabsSub` in each language), 84 (the PDF-only strings when `gated`) and 114–118 (a1-6's `dragged` notes, unchanged).

<a id="g12"></a>

### G12 · Onboarding marks later features as included

- **Type:** conflict
- **Milestone:** M1
- **Area:** First run
- **Artboards:** `a1-2c`, `a11-5`; the welcome steps `a1-2a` and `a1-2b`; resolved by `a1-2c-m1` (export 519d42a)
- **Gap or conflict:** a1-2c ("Free forever, nothing locked") shows 10 feature tiles with the same green check, whose accessible label is "Included"; the word is not visible text. The headline says "Every feature is included, with no trial, no subscription and no paid tier." Seven tiles are later-phase features: Text recognition (OCR), e-imza and digital signatures, Redaction, Convert to and from Office, Compare documents, Batch actions and Accessibility checker. The design has no "coming" tile style. a11-5 also says "nothing locked". a1-2a, the first of the three welcome steps, presents in-place text editing (M3), and its note says the specimen is "a live editing frame, not an illustration".
- **Decision:** The grid follows the build. Features that have shipped keep the check and the "Included" label. The others are shown disabled, in a neutral style, with "Available in a future version" instead of "Included": the sunken fill, the disabled icon colour, the secondary text colour and a `clock` glyph where the check was, with the reason as the tile's tooltip and in its accessible name. In M1 only the interface languages have shipped; their tile counts the build's translations ("3 interface languages", in the region's digits). A tile's label wraps instead of ending in an ellipsis: two lines fill the drawn 44 px tile, and a label that needs a third line (Turkish and Arabic at narrow widths) makes both tiles of its row grow to the same height. The headline about no trial, subscription or paid tier stays, because nothing is ever behind a paywall. a1-2a joins first run with the editor in M3 ([B087](BACKLOG.md#open)). Until then first run has two welcome steps after the language picker, a1-2b and a1-2c, shown as "1 of 2" and "2 of 2" and announced as "Step 1 of 2" and "Step 2 of 2".
- **Status:** Resolved on 2026-10-17 by export 519d42a: a1-2c-m1, the M1 build of this step, draws the decision. It reads "2 of 2", announced "Step 2 of 2"; only "3 interface languages" keeps the check and "Included"; every other tile has the sunken fill, the disabled icon colour, the secondary text colour and a clock where the check was, with "Available in a future version" as its tooltip and in its accessible name ("label. Available in a future version"); labels wrap and a row grows to its taller tile. Its note has a1-2b read "1 of 2" until the editor ships in M3. a1-2c stays the finished product. Was Decided; on 2026-10-16 the disabled tile was specified, and a1-2a was left out of first run until M3.
- **Evidence:** 01 First run and files.dc.html lines 76–88 and 248–251; line 83 renders every tile with `var(--success-solid)` and `label='Included'`. Line 60 is the a1-2a note; lines 58, 72 and 86 announce "Step 1 of 3" to "Step 3 of 3". Implemented in `app/lib/features/onboarding/free_step.dart` lines 12–204 and `app/lib/features/onboarding/onboarding_screen.dart` lines 36–38 and 62–63 (M1 phase I2); checked in `app/test/features/onboarding/onboarding_test.dart` lines 398, 428 and 541. In 519d42a: `design/01 First run and files.dc.html` lines 90–102 (a1-2c-m1: the tiles at line 97, the note at line 102) and 356 (`tilesM1`, with the accessible name `label + '. ' + S.future`).

<a id="g13"></a>

### G13 · Licence shown as GPL-3.0, not Apache-2.0

- **Type:** conflict
- **Milestone:** M1
- **Area:** First run / About
- **Artboards:** `a1-2c`, `a11-5`; also `a1-2c-m1` (export 519d42a)
- **Gap or conflict:** a1-2c reads "Licence: GPL-3.0-or-later" and a11-5 About reads "Free and open source under GPL-3.0-or-later. No accounts, no telemetry, nothing locked." The brief says Apache-2.0. The a1-2c note and the Index both flag the licence as a proposal for review.
- **Decision:** Both screens say Apache-2.0 (brief §1) and change nothing else. a1-2c reads "Licence: Apache-2.0", and a11-5 changes only the licence: "Free and open source under Apache-2.0. No accounts, no telemetry, nothing locked." The licence line keeps a1-2c's Source code and Support the project links. They stay visible, disabled with the future-version tooltip ([G10](#g10)), until the app opens web pages (with About, a11-5; [B086](BACKLOG.md#open)).
- **Status:** Resolved on 2026-10-17 by export 519d42a: a1-2c reads "Licence: Apache-2.0", and a11-5 "Free and open source under Apache-2.0. No accounts, no telemetry, nothing locked."; both notes say nothing else changes. a1-2c-m1 draws Source code and Support the project visible and disabled with the future-version tooltip until the app opens web pages. Was Decided; on 2026-10-16 a1-2c's links were kept, disabled until the app opens web pages.
- **Evidence:** 01 First run and files.dc.html line 81 (a1-2c) and line 88 (the note); 11b App.dc.html line 66 (a11-5). Before 519d42a, "Apache" appeared nowhere in `design/`. a1-2c's licence line is implemented in `app/lib/features/onboarding/free_step.dart` lines 206–237 (`LicenceNote`, key `onboardingFreeLicence`) (M1 phase I2); checked in `app/test/features/onboarding/onboarding_test.dart` line 541. In 519d42a: `design/01 First run and files.dc.html` lines 81 and 89 (a1-2c and its note) and 95 (a1-2c-m1's licence line, the links with `aria-disabled` and the future-version title); `design/11b App.dc.html` lines 63 (the a11-5 note) and 66.

<a id="g14"></a>

### G14 · No third-party notices screen

- **Type:** missing screen
- **Milestone:** M4
- **Area:** About / licences
- **Artboards:** `a11-5`, `a13-15`
- **Gap or conflict:** a11-5 About has a "Licences" button and a one-line credit, and the iOS settings board a13-15 has an "About and licence" row. Neither leads to a drawn view. No board shows the Apache-2.0 text or a list of third-party components: the PDF engine, Flutter, fonts under OFL (including the typed-signature faces), Noto, the OCR engine and its language data, Lucide under ISC. Desktop Settings has no About or Licences entry at all.
- **Decision:** Build a Licences view from design-system components, opened by the "Licences" button in a11-5 (and by the a13-15 row in the mobile phase). It shows Ferman's licence (Apache-2.0) in full and a searchable list of every bundled component with its licence text: Rust crates, Dart packages (Flutter's `LicenseRegistry`), PDFium (the archive's `licenses/` folder, where PDFium's own BSD-3-Clause and Apache-2.0 text is `licenses/pdfium.txt`, and the packager's MIT `LICENSE`), fonts and icons ([ADR 0016](adr/0016-dependency-licence-policy.md)). The view is asked for in the re-export ([Q11](QUESTIONS.md#q11)).
- **Status:** Decided
- **Evidence:** 11b App.dc.html lines 67–68 (a11-5). The FmSettings navigation (General to Advanced) has no About pane. 13b line 264 (a13-15).

<a id="g15"></a>

### G15 · No Linux window chrome

- **Type:** missing variant
- **Milestone:** M1
- **Area:** App shell / window chrome
- **Artboards:** none drawn; references to mirror: `f6a`, `a1-4c`, `a1-10b`, `a11-1w`
- **Gap or conflict:** No Linux board exists, and "Linux" appears in no board. The platform prop of FmWindow, FmStart, FmSettings, FmEditPanel and FmDocPanel allows only `mac` and `win`, and FmBoard has no `linux` option. The Linux title bar and caption buttons, the dialog button order, Ctrl shortcuts and file-manager wording ("Show in Files") are undefined.
- **Decision:** Linux gets a custom title bar: client-side decorations drawn by Ferman, matching the custom title bars on macOS and Windows, with the caption buttons at the end in the GNOME (libadwaita) style. Ctrl shortcuts, Cancel on the left and the affirmative button on the right in dialogs, and "Show in Files" wording. Until Linux boards exist, the Linux chrome is built from the Windows chrome of f6a with those changes and recorded in goldens. Boards for the main editor (like f6a), Start (like a1-4c), one dialog (like a1-10b) and Settings (like a11-1w) are asked for in the re-export. The owner chose the packaging on 2026-10-16 ([Q12](QUESTIONS.md#q12)): a Flatpak on Flathub plus an AppImage, in M5.
- **Status:** Decided. The owner chose the custom title bar on 2026-10-15 ([Q12](QUESTIONS.md#q12), window chrome). Was Needs owner. On 2026-10-16 the Dialog component took over the platform's button order (`DialogButtonOrder`, [COMPONENTS.md](COMPONENTS.md) decision 43): Cancel first on macOS and Linux, last on Windows.
- **Evidence:** A search of all files for Linux, GNOME, GTK, Ubuntu, Fedora, Flatpak, AppImage, libadwaita, Nautilus and "Show in Files" finds nothing. The Index describes FmWindow as "Desktop shell: macOS and Windows chrome".

<a id="g16"></a>

### G16 · Windows variants missing for most screens

- **Type:** missing variant
- **Milestone:** M1
- **Area:** Windows variants of M1–M4 screens
- **Artboards:** drawn: `f6`, `f6a`, `a1-4c`, `a11-1w`, `a12-1de`, `a12-2b`, `a12-2d`, `a14-1d`; not drawn on Windows: `a1-8`, `a1-8b`, `a1-10`, `a1-10b`, `a1-11`, `a1-12`, `a11-7`, `a11-7c`, `a11-1e`, `a11-1g`, `a11-1j`
- **Gap or conflict:** Windows is drawn in f6 (a title-bar strip), f6a, a1-4c, a11-1w, a12-1de, a12-2b and a12-2d (Settings › Language and region, in German); a14-1d reuses Windows chrome in Organize mode inside an Android tablet frame. Not drawn on Windows: any dialog (the button order exists only as text in the a1-10b and f6a notes); the a1-10 tab overflow menu (its data says ⌘7 to ⌘9); View, Comment and Fill modes, and Organize on desktop; missing glyph and overflow; the error states (a11-7 to a11-7c, "Show in Finder"); and Settings panes other than General and Language. a11-1e, a11-1g and a11-1j hard-code "macOS keychain", "this Mac" and ⌘. The Windows General board a11-1w still shows "Preview opens PDFs on this Mac", against its own note.
- **Decision:** Build the Windows variants from the platform rules in f6 and f6a: caption buttons and corners as drawn, Ctrl shortcuts (in the a1-10 overflow menu the document jump shows Alt+7 to Alt+9: it moved off Ctrl+1 to Ctrl+9 because Ctrl+1 and Ctrl+2 are zoom keys, [G81](#g81)), dialog order primary, secondary, then Cancel ("Save", "Don't save", "Cancel" for a1-10b), "Show in Explorer", Windows Credential Manager instead of the macOS keychain in a11-1e, wording that never says "this Mac" on Windows, and a General pane whose default-app text names Windows and opens Windows Settings, as the a11-1w note says. Platform strings come from one table and are never hard-coded. Goldens cover the Windows variant of every screen with platform-specific chrome or copy.
- **Status:** Decided. On 2026-10-16 the overflow-menu keys became Alt+7 to Alt+9 ([G81](#g81)); they were Ctrl+7 to Ctrl+9. On 2026-10-16 the Dialog component took over the button orders this entry names (a1-10b: Save, Don't save, Cancel on Windows; f6a: primary, secondary, Cancel), through its `cancelAction` and `alternateAction` slots, so screens no longer order the buttons.
- **Evidence:** `platform="win"` appears only in f6, f6a, a1-4c, a11-1w, a12-1de, a12-2b, a12-2d and a14-1d. FmSettings hard-codes "macOS keychain" (line 129), "Nothing leaves this Mac" (line 68) and ⌘ shortcuts (lines 138–145); line 30 holds the General text.

<a id="g17"></a>

### G17 · Dark variants missing for most screens

- **Type:** missing variant
- **Milestone:** M1
- **Area:** Dark theme for M1–M4 screens
- **Artboards:** drawn: `a1-4b`, `a2-3x`, `a2-5a`, `a2-9`, `a3-1d`, `a4-1d`, `a5-1d`, `a11-6`; theme-invariant, not drawn in dark: `a5-2b`; not drawn in dark: `a1-1`, `a1-3`, `a1-8`, `a1-8b`, `a1-9`, `a1-9b`, `a1-10`, `a1-10b`, `a1-11`, `a1-12`, `a11-1`, `a3-3a`, `a3-3b`, `a3-4`, `a3-12`, `a11-2`, `a11-6b`, `a11-7`, `a2-1b`
- **Gap or conflict:** Dark is drawn in a1-4b, a2-3x, a2-5a, a2-9, a3-1d, a4-1d, a5-1d and a11-6 (toasts), plus a dark Windows title-bar specimen in DS additions. a5-2b (field states) is drawn in light only; its "light and dark" label and note mean that on-page field colours are the same in both themes. The dark chrome with a paper-white page exists for Edit, Comment and Fill (a3-1d, a4-1d, a5-1d) but not for View: none of a2-1a to a2-1d has a dark version. No dark version exists for onboarding (a1-1 to a1-3), any dialog (a1-8 to a1-12), any Settings pane, a3-3a, a3-3b, a3-4, a3-12, Organize, the palette (a11-2), the task drawer (a11-6b) or the errors (a11-7 to a11-7c). The "Dimmed" page option in Settings › General ("PDF pages in dark theme") is never drawn.
- **Decision:** Every screen gets its dark variant from the dark tokens with the same layout, and goldens cover light and dark for every implemented screen (brief §5). In View the page stays paper-white in the dark theme, as a3-1d and the a2-9 note say. "Dimmed" uses the design system's `[data-page=dim]` tokens and `--page-filter`. Dark boards for a1-8, a1-10b, a1-12, a3-3a, a3-4, Settings, the palette and a dark a2-1b are asked for in the re-export.
- **Status:** Decided
- **Evidence:** `theme="dark"` appears only on the boards listed as drawn. FmSettings has no theme prop. FmSettings line 27 defines Paper white (default), Dimmed (sepia) and Dark reading mode; DocKira has no dim prop.

<a id="g18"></a>

### G18 · Right-to-left variants missing for most screens

- **Type:** missing variant
- **Milestone:** M1
- **Area:** RTL (ar/fa/he) for M1–M4 screens
- **Artboards:** drawn: `a12-1ar`, `a12-2a`, `a12-2c`, `a12-3`, `a12-3b`, `a12-3c`, `a3-13a`; not drawn in RTL: `a1-8`, `a1-8b`, `a1-10`, `a1-10b`, `a1-11`, `a1-12`, `a2-1c`, `a2-1d`, `a2-4a`, `a3-3a`, `a3-4`, `a3-12`, `a11-2`, `a11-6`, `a11-6b`; pickers: `a1-1`, `a13-1b`
- **Gap or conflict:** Right-to-left desktop chrome is drawn only in a12-1ar (editor, Pages tab, edit panel), a12-2a (Start) and a12-2c (Settings › Language), all on macOS. Mobile RTL exists (a12-3, a12-3b, a12-3c), and a3-13a shows RTL page content inside LTR chrome. Not drawn in RTL: the dialogs (a1-8 to a1-12), the a1-10 tab overflow menu, the View layouts (a2-1c, a2-1d), sidebar tabs other than Pages, the find bar (a2-4a), the missing-glyph and overflow callouts (a3-3a, a3-4), the review list (a3-12), toasts and the task drawer (a11-6, a11-6b), the palette (a11-2), and Windows RTL caption buttons. Persian and Hebrew appear only as entries in the language pickers (a1-1, a13-1b) and in font legends; no Persian or Hebrew screen is drawn.
- **Decision:** Chrome mirrors everywhere through directional layout (`EdgeInsetsDirectional`, `AlignmentDirectional`) and per-icon mirroring flags. The PDF canvas and the content of thumbnails are never mirrored ([ADR 0014](adr/0014-localization-and-rtl.md)). Windows RTL chrome follows the platform convention until it is drawn. Goldens run every implemented screen in Arabic, and Persian and Hebrew get one editor spot-check each. Arabic boards for a1-10, a1-10b, a1-8b, a2-4a, a3-3a, a3-4 and a11-2 are asked for in the re-export.
- **Status:** Decided
- **Evidence:** `dir="rtl"` on desktop chrome appears only in a12-1ar, a12-2a and a12-2c, and no Windows board has it. 'فارسی' and 'עברית' appear only in the a1-1 list (01 line 234) and the a13-1b list (13a line 222).

<a id="g19"></a>

### G19 · Turkish UI drawn only in the editor

- **Type:** missing variant
- **Milestone:** M1
- **Area:** Turkish UI locale
- **Artboards:** `a12-1tr`, `a12-3d`, `a12-3e`; Turkish capitals in content: `a4-3`, `a4-3b`, `a3-8a`; English-only dialogs: `a1-8`, `a1-8b`, `a1-9`, `a1-9b`, `a1-10b`, `a1-11`, `a3-3a`, `a3-4`; to draw in Turkish: `a1-4`, `a11-1b`
- **Gap or conflict:** The desktop Turkish UI is drawn only in a12-1tr. Turkish mobile UI exists in a12-3d (Android reader) and a12-3e (iOS fill, back button "Geri"). FmStart and FmSettings accept only en, de and ar, so a Turkish Start screen or Turkish Settings cannot be rendered; FmWindow, FmSidebar, FmEditPanel, FmPhone and FmMHome do support Turkish. No Turkish dialog is drawn: the password, repair, unsaved-changes, Save as, missing-glyph, overflow and signature boards are all English. "İMZALA" appears nowhere, and no Turkish UI label is ever shown in capitals. Turkish capitals appear only in document or stamp content inside English UI (a4-3, a4-3b, a3-8a) and in the unnumbered "Turkish capitals" rule in 12 Localization.
- **Decision:** Turkish is complete from M1 (brief §6), and every implemented screen, Start and Settings included, has Turkish goldens built from the ARB files. A locale-aware casing utility makes uppercase labels correct ("imzala" becomes "İMZALA") and is tested. Numbers follow the region format ("10,5 pt") ([ADR 0014](adr/0014-localization-and-rtl.md)). Turkish boards for a1-4, a11-1b, a1-10b, a3-3a and a3-4, with at least one uppercase label, are asked for in the re-export.
- **Status:** Decided
- **Evidence:** FmStart and FmSettings `data-props` list lang `en`, `de`, `ar`. A search for Parola, Şifre, İptal, Vazgeç and "Farklı kaydet" finds nothing. The 12 Localization rule renders "imzala · kiracı" as "İMZALA · KIRACI".

<a id="g20"></a>

### G20 · Language picker has no translation states

- **Type:** missing state
- **Milestone:** M1
- **Area:** First run / language selection
- **Artboards:** `a1-1`, `a13-1b`, `a1-2c`, `a11-5`, `a11-1b`; also `a12-1de`, `a12-1ja`, `a12-2b`, `a12-2d`, `a12-1ar`, `a12-2a`, `a12-2c`
- **Gap or conflict:** a1-1 (desktop) offers all 21 languages as equal choices, and a13-1b (Android, 12 languages) does the same. No translation-status, partial-translation or fallback state is drawn, nor the filter's no-results state, nor the picker after the promised live switch to a right-to-left language. The design claims full coverage: a1-2c says "21 interface languages" and a11-5 says "Translations by volunteers in 21 languages", while M1 ships English, Turkish and Arabic and other languages fall back to English (brief §6). The design also draws German and Japanese UI (a12-1de, a12-1ja, a12-2b, a12-2d). Right-to-left chrome itself is drawn in a12-1ar, a12-2a and a12-2c.
- **Decision:** The picker lists all 21 languages by their native names. Languages that are not translated yet carry a "Not translated yet" caption and stay selectable; their missing messages fall back to English ([ADR 0014](adr/0014-localization-and-rtl.md)). The picker's footer link, "Help translate Ferman" as a1-1 draws it, stands in for a link on each row. It is disabled with the future-version tooltip ([G10](#g10)) until the translation project exists ([B085](BACKLOG.md#open)). Choosing Arabic, Persian or Hebrew mirrors the UI at once (Persian and Hebrew with the English strings, [G93](#g93)). The filter's no-results state uses the empty-state component ([G29](#g29)) once it exists in M2. Until then it is one centred line in the body style and the secondary text colour, "No language matches “…”.", announced as a live region ([B088](BACKLOG.md#open)). The language counts in a1-2c and a11-5 say what that build actually has.
- **Status:** Decided. On 2026-10-16 the footer link replaced the per-row links, and a plain line stands in for the empty state until M2.
- **Evidence:** The `LANGS` array in 01 First run and files lists 21 entries with no status field. The a1-1 note: "Choosing a language switches the interface live, before Continue." No "not translated", "fallback" or "No results" string exists. `design/01 First run and files.dc.html` line 38 draws the footer link ("Missing your language? Help translate Ferman"). Implemented in `app/lib/l10n/app_language.dart` and `app/lib/features/onboarding/language_picker.dart` lines 190–199 (the no-match line) and 303–309 (the footer link) (M1 phase I2).

<a id="g21"></a>

### G21 · Narrow windows and pane resizing not drawn

- **Type:** missing state
- **Milestone:** M1
- **Area:** App shell responsiveness
- **Artboards:** `a1-10`, `a12-1de`, `a12-2b`, `a12-2d`, `a2-8a`, `a2-8b`, `a14-1`, `a14-1b`, `a14-1c`, `a14-1d`
- **Gap or conflict:** No desktop window narrower than 1440 px is drawn. No icon-only tool row with an overflow menu is drawn, mode-tab truncation is not specified, and ModeTabs has no overflow handling; a12-1de only says the mode bar fits all eight modes at 1440 px. Sidebar and panel resize handles and their minimum and maximum widths are not specified; the only resize separator is the split-pane one in a2-8a and a2-8b. What is drawn: German labels wrapping at full width (a12-1de, a12-2b, a12-2d), document tabs shrinking to 112 px with a "+4" overflow (a1-10), collapsed sidebars and panels with the mode row still visible (many boards), and narrower tablet shells (a14-1b at 1032 px, a14-1c at about 683 px, a14-1d at 1280 px). The a14-1 note says the tool row scrolls when it runs out of room, while the 12 Localization rule says labels hide behind their icons.
- **Decision:** Desktop follows the 12 Localization rule: when the tool row runs out of room, labels hide behind their icons (the tooltip keeps the name), and then the remaining tools move into an overflow menu. Scrolling stays a tablet behaviour (a14-1). Panels collapse before anything overlaps. Mode tabs are checked at the minimum width in English, Turkish, German and Arabic; if they do not fit, they fall back to icons with tooltips. M1 sets a minimum window width (1024 px, approved by the owner on 2026-10-16; [G95](#g95)) and records resize limits for the sidebar and the right panel. Narrow-window boards in English and German are asked for in the re-export.
- **Status:** Decided. M1 builds it as [G95](#g95) records (2026-10-16).
- **Evidence:** All desktop `fm-root` frames are 1440 × 900. The "Resize panes" separator appears only in a2-8a and a2-8b. The design system ModeTabs source has no overflow logic.

<a id="g22"></a>

### G22 · Tooltip shortcuts and focus states mostly undrawn

- **Type:** missing state
- **Milestone:** M1
- **Area:** Component library: tooltips, shortcuts, focus
- **Artboards:** `a3-1a`, `f5`, `f6`, `a1-1`, `a1-4`, `a1-8`, `a4-1`, `a3-15`, `a5-2b`, `a5-3d`, `a5-4`, `a5-6b`, `a9-7`, `a11-3`
- **Gap or conflict:** The only tooltip that shows a shortcut is the "Rotate page" specimen in DS additions; no product board draws a tool-button tooltip with its key. The drawn tooltips are content tooltips (a3-1a, f5). Focus is drawn more widely: the DS additions "Interactive states" sheet forces focus on Button (primary, secondary, danger), IconButton, TextField, Checkbox, Switch and PageThumbnail, and focus also shows in a1-1, a5-2b, f5, the a9-7 calibration handle, the autofocused password and PIN fields (a1-8, a5-6b) and the highlighted menu item in a5-3d. Shortcuts in menus and lists are drawn in a5-3d, a5-4, a11-3 and the a1-4 action cards. Not drawn: focus for ToolButton, ModeTabs, document tabs, SegmentedControl, sidebar items other than thumbnails, and the canvas text block; and a disabled state with an explaining tooltip, which exists only as prose (a3-15, a4-1, f6). The missing focus states exist only as CSS (`:focus-visible` in navigation.css).
- **Decision:** Every focusable component gets the design system's focus-visible ring (2 px ink ring with a 2 px gap), using the navigation.css rules where they exist. Tool-button tooltips show the name and the platform shortcut (⌘ on macOS, Ctrl on Windows and Linux) through the design system's Tooltip with a key, as the "Rotate page" specimen does. Disabled controls say why in their tooltip (the a3-15 pattern), and unshipped features use the future-version tooltip ([G10](#g10)). A component state sheet is asked for in the re-export.
- **Status:** Decided
- **Evidence:** DS additions "Interactive states" (`data-fm-force="focus"`) and `Tooltip content="Rotate page"`. Prose only: a4-1 ("Every tool has a single-key shortcut shown in its tooltip"), f6 and a3-15.

<a id="g23"></a>

### G23 · App accessibility scope and high contrast undefined

- **Type:** ambiguity
- **Milestone:** M1
- **Area:** App accessibility
- **Artboards:** `a1-2a`, `a1-8`, `a1-8b`, `a3-1a`, `f2`, `f4`, `f5`, `a11-6`; document tools: `a9-3`, `a9-3b`
- **Gap or conflict:** The design system's themes are Dark, Page Dim and Density Touch. There are no high-contrast, forced-colours or prefers-contrast tokens, and Settings offers only Match system, Light and Dark. Reduced motion is specified (every duration becomes 0 ms, implemented in `tokens/effects.css`), the readme gives a focus-visible rule for every focusable element, and many board notes describe screen-reader announcements (for example `aria-invalid` in a1-8b, a polite live region in f4, "announced assertively" in a11-6). Missing are a high-contrast variant and a decision on whether app accessibility belongs to M1 or waits for the PDF/UA document tools (P4), which appear only in a9-3 and a9-3b.
- **Decision:** App accessibility is part of every milestone from M1: every control reachable by keyboard, focus-visible, Semantics labels and the announcements the notes describe, the OS reduced-motion setting through the tokens, and the OS high-contrast setting respected where the tokens allow. PDF/UA document tools stay in P4. The token generator leaves room for a high-contrast set but invents no values ([ADR 0012](adr/0012-design-token-pipeline.md)); the set is asked for in the re-export.
- **Status:** Decided
- **Evidence:** `colors.css` defines `[data-theme=dark]` and `[data-page=dim]`, `spacing.css` defines `[data-density=touch]`, and `effects.css` has `@media (prefers-reduced-motion: reduce)`. No forced-colors or prefers-contrast rule exists.

<a id="g24"></a>

### G24 · Onboarding lists only the update check

- **Type:** conflict
- **Milestone:** M1
- **Area:** First run privacy
- **Artboards:** `a1-2b`, `a11-1h`, `a13-16`
- **Gap or conflict:** a1-2b names "One optional check for updates" as the only network use ("Once a day, sending only the version number") and says "Editing, OCR, signing and conversion need no connection." a11-1h contradicts it: it lists five connections, and its update copy says "sends only the version number and platform". The five are the update check, signature revocation checks when signing or opening a signed file, the timestamp server when signing, downloads you start (OCR language packs, the assistant's model) and your AI provider. Revocation checks are not one of the brief's four uses ([G51](#g51)). a13-16 (mobile, offline) says "Everything works except updates and certificate checks", which contradicts the desktop claim that signing needs no connection.
- **Decision:** a1-2b lists the brief's four uses: the update check, optional language-pack downloads, optional AI (a local model or your own key) and signature timestamp servers. Each is "off until you use it" except the update check, which can be turned off. The screen links to Settings › Privacy and uses a11-1h's payload wording, "the version number and platform" (the endpoint and payload were settled on 2026-10-16 in [Q15](QUESTIONS.md#q15)). Revocation lookups, allowed on 2026-10-16 and off until first use ([G51](#g51), [Q06](QUESTIONS.md#q06); [ADR 0015](adr/0015-privacy-and-network.md)), join the list when phase 3 builds them. In M1 the drawn update row becomes four rows in the same style, after the four facts. "One optional check for updates" reads "Once a day, sending only the version number and platform. You can turn it off." Then "OCR language packs", "AI assistant" and "Signature timestamps" each end "Off until you use it.", with the `download`, `sparkles` and `clock` icons. Under the card, "See every connection in Settings › Privacy" opens Settings › Privacy over the step, and closing it returns to the step.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a1-2b now draws the four facts, then the four network rows as decided ("Once a day, sending only the version number and platform. You can turn it off.", then OCR language packs, AI assistant and Signature timestamps, each "Off until you use it.", with the `download`, `sparkles` and `clock` icons), and under the card the link "See every connection in Settings › Privacy". Its note says revocation lookups are not listed "until the owner decides (G51)"; the owner allowed them on 2026-10-16 ([Q06](QUESTIONS.md#q06)), and this entry's reason stands: they join the list when phase 3 builds them. Was Decided; on 2026-10-16 the four rows and the link to Settings › Privacy were specified.
- **Evidence:** The privacy array in 01 First run and files (rendered in a1-2b); the FmSettings `nets` rows used by a11-1h; the a13-16 banner. Implemented in `app/lib/features/onboarding/privacy_step.dart` lines 44–85 (the rows) and 161–165 (the link) (M1 phase I2); checked in `app/test/features/onboarding/onboarding_test.dart` lines 398 and 483. In 519d42a: `design/01 First run and files.dc.html` lines 62–74 (a1-2b: the link at line 70, the note at line 74) and 376–383 (the eight rows).

<a id="g25"></a>

### G25 · Opening files from the OS not drawn

- **Type:** missing screen
- **Milestone:** M2
- **Area:** Open: Open with / OS dialog / cold launch
- **Artboards:** `a1-3`, `a1-4`, `a1-4b`, `a1-4c`, `a1-6`, `a1-7`, `a11-1`, `a11-1w`, `a11-3`, `a13-13`; resolved by `a1-13` (export 519d42a)
- **Gap or conflict:** Drag and drop (a1-6), recent files (a1-4, a1-4b, a1-4c) and the default-app prompt (a1-3, a11-1, a11-1w) are drawn. The desktop design never shows a file arriving from the OS (a double-click in Finder or Explorer, "Open with", the Dock or the taskbar) into a running instance, a file that is already open, a cold launch straight into a document, or the ⌘O open dialog, although ⌘O is on the a11-3 cheat sheet. Step 1 of flow A (`fa`, "Double-click in Finder, drop on the window, or ⌘O from Start") links to a1-4, a Start screen. The only spec is a note on mobile a13-13: "Open in Ferman" from Mail or Files "lands here as a new tab in the reader".
- **Decision:** A file from the OS opens as a new active tab in the running instance (one instance per user), as a13-13 describes and a1-7 draws for a new tab. A file that is already open focuses its tab instead of opening twice. A cold launch with a file skips Start and opens the document. The open dialog behind ⌘O or Ctrl+O and Start's "Open file…" is the OS-native picker of [ADR 0018](adr/0018-native-file-pickers.md), Accepted on 2026-10-16 ([Q07](QUESTIONS.md#q07)). M1 built no picker; M2 builds the native open picker. Drag and drop, recent files and "open with" work alongside it. Boards for these states are asked for in the re-export.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a1-13 draws ⌘O, "Open file…" and "Open a PDF" handing off to the system open panel (NSOpenPanel, IFileOpenDialog or the Linux desktop portal, asking for PDF files and allowing several at once), each chosen file opening as a new active tab, and its note states the rest of this decision: a file sent from Finder, Explorer or the file manager opens the same way in the running window, one instance per user; a file already open focuses its tab; a cold launch with a file skips Start. Its note still says "pending Q07"; the owner answered Q07 on 2026-10-16. Was Decided; the owner answered [Q07](QUESTIONS.md#q07) on 2026-10-16: OS-native pickers for opening, the save location and folders, with the a1-11 sheet handing off for "Other location…"; [ADR 0018](adr/0018-native-file-pickers.md) is Accepted, so the native pickers are the plan, not an interim. Was Needs owner before that.
- **Evidence:** No board contains "Open with", "already open", "NSOpenPanel", "IFileDialog", "portal" or "cold". 15 Flows, flow A step 1, links to a1-4. In 519d42a: `design/01 First run and files.dc.html` lines 220–224 (a1-13: the panel placeholder at line 222, the note at line 224).

<a id="g26"></a>

### G26 · Native or custom file pickers not specified

- **Type:** ambiguity
- **Milestone:** M2
- **Area:** Dialogs
- **Artboards:** `a1-11`, `a6-2`, `a7-2`, `a9-6`, `a13-13`, `a13-1c`; resolved by `a1-13`, `a1-11b` and `a1-9e` (export 519d42a)
- **Gap or conflict:** a1-11 draws a custom Ferman "Save as" sheet with a File name field and a "Where" dropdown ("Belgeler › Ev", "Masaüstü", "Other location…") above the format options. Nothing says whether "Other location…", "Choose a folder…" (a6-2 Split, a7-2 Convert batch) or the ⌘O open command use the OS-native picker or a custom one, and the open dialog behind Start's "Open file…" is not drawn. The design already hands off to the OS elsewhere: print has "Use system dialog…" (a9-6), mobile sharing uses the system share sheet (a13-13), and a13-1c explains the camera permission before the system prompt. The brief requires custom popup dialogs (§6).
- **Decision:** Accepted in [ADR 0018](adr/0018-native-file-pickers.md) on 2026-10-16 ([Q07](QUESTIONS.md#q07)): OS-native pickers are the only exception to the custom-dialog rule, for opening a file, choosing a save location and choosing a folder, because sandboxed builds and portals need them. a1-11 stays a Ferman sheet with File name, Where and the format options; "Other location…" hands off to the native save picker, and the sheet then shows the chosen folder. M1 built no picker. M2 builds the native open picker, M3 the native save-location handoff from a1-11, and the folder picker comes in the later milestone that needs one.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a1-13 draws the open command handing off to the system open panel; a1-11b draws the a1-11 sheet after "Other location…" handed off to the system save panel, with the chosen folder (Projeler › 2026) in Where and in the copy line, and notes that M3 brings saving; a1-9e's "Locate…" opens the system open panel too. No board draws "Choose a folder…" (a6-2, a7-2) handing off, which [ADR 0018](adr/0018-native-file-pickers.md) already settles. Was Decided; the owner answered [Q07](QUESTIONS.md#q07) on 2026-10-16: OS-native pickers for opening, the save location and folders, with the a1-11 sheet handing off for "Other location…"; ADR 0018 is Accepted, so the native pickers are the plan, not an interim. Was Needs owner before that.
- **Evidence:** a1-11 `whereOptions`. No board and no design system text sets a rule for file pickers. The a9-6 note: "On macOS the system dialog is one click away". In 519d42a: `design/01 First run and files.dc.html` lines 205–209 (a1-9e), 220–224 (a1-13), 284–304 (a1-11b, its note at line 304) and 369 (`whereChosen`).

<a id="g27"></a>

### G27 · Restricted and certificate-encrypted PDFs not drawn

- **Type:** missing state
- **Milestone:** M2
- **Area:** Encrypted / permission-restricted PDFs
- **Artboards:** `a1-8`, `a1-8b`, `a2-7`, `a8-1`, `a8-4`, `a11-7c`; resolved by `a2-10a` and `a2-10b` (export 519d42a)
- **Gap or conflict:** Only the user (open) password is drawn (a1-8, a1-8b), plus the author's side of permissions (a8-1) and the unrestricted case (a8-4 "No usage restrictions"; the a2-7 Summary line "Security: No password · 1 signature"). Not drawn: opening an owner-password or permission-restricted PDF (a banner, Edit, Comment and Fill disabled with the reason, an optional unlock), opening a certificate-encrypted PDF, and the a2-7 Security tab, which is defined in `propTabs` and mentioned in the a2-7 note but never shown.
- **Decision:** A restricted document opens with a banner that names the restriction. Tools the permissions forbid are disabled, and their tooltip gives the reason (for example "The author doesn't allow editing"); "Unlock with owner password…" lifts the restriction. The a2-7 Security tab follows the layout of the drawn Summary tab and lists the encryption method and each permission. A certificate-encrypted PDF gets the open-error state ([G28](#g28)) with a plain reason until certificate support arrives with the phase 3 signature work; that has a BACKLOG entry. A mode or tool the permissions forbid shows the future-version tooltip until it ships (Edit in M3) and the author's reason from then on, as the a2-10a note says. The unlock dialog itself is not drawn ([G106](#g106)).
- **Status:** Resolved on 2026-10-17 by export 519d42a: a2-10a draws a restricted document opening with an info Banner ("The author restricted this document." / "You can read and print it. Editing, comments and form filling are turned off.") and "Unlock with owner password…", a shield on the tab, and the tooltip "The author doesn't allow editing"; its note sends a certificate-encrypted PDF to a1-9b's open-error state until P3. a2-10b draws the Security tab in the Summary tab's layout: the encryption method, whether a password is needed to open, and each of eight permissions, Allowed in green and Not allowed in neutral. Was Decided.
- **Evidence:** No board contains "restricted" or "owner password". a2-7 draws only `SegmentedControl value="summary"`. FmWindow has no restricted state. In 519d42a: `design/02 View.dc.html` lines 238–246 (a2-10a, the tooltip at line 244), 247–260 (a2-10b) and 311 (`PERM`).

<a id="g28"></a>

### G28 · Unsupported, read-only and missing files not drawn

- **Type:** missing state
- **Milestone:** M2
- **Area:** Open errors
- **Artboards:** drawn: `a1-7`, `a1-9`, `a1-9b`, `a11-7`, `a11-7b`, `a11-7c`; related: `a1-4`, `a1-5`, `a1-6`, `a13-16b`, `a14-2b`; resolved by `a1-9c`, `a1-9d`, `a1-9e` and `a1-9f` (export 519d42a)
- **Gap or conflict:** Drawn: damaged and repaired (a1-9), damaged and unrecoverable (a1-9b), XFA (a11-7c), disk full (a11-7) and changed on disk (a11-7b); a large file opens with progress (a1-7). Not drawn: a truly unsupported file type (for example .zip or .pages; the DropZone error variant `.fm-drop--error` is never used), a read-only or permission-denied file on open, a recent file that was moved or deleted (web a14-2b "Choose again…" is the only analogue), and an out-of-memory failure (mobile a13-16b only warns about memory use). Office and image files are not drawn as errors: a1-5, a1-6 and the FmStart strings promise to convert them on open, while the design system readme's voice table says "That file isn't a PDF. To edit a Word or image file, convert it first."
- **Decision:** An unsupported file, and an Office or image file until conversion ships in P3, gets an error tab and the DropZone error variant with the voice line "That file isn't a PDF.", conversion marked "Available in a future version" ([G11](#g11)). A read-only or permission-denied file opens read-only with FmWindow `save="readonly"`, as in a11-7c (a lock and "Read-only" in the status bar). A missing recent file offers "Remove from list" and "Locate…". An out-of-memory or similar failure closes that document's tab with a plain message and keeps the rest of the app running ([ADR 0010](adr/0010-error-handling-no-panics.md)). **Where the M2 build differs from the boards:** a1-9d's "Save a copy…" and a1-9's "Save repaired copy…" need the writer, which arrives in M3, so they stay visible and disabled with the future-version tooltip until then ([G10](#g10)). **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** a1-9f's promise holds where the engine sees the shortage coming, through its limits and reservations checked before allocating; memory running out inside PDFium cannot be caught.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a1-9c draws a file that isn't a PDF as an error tab (the file's name with the `file-x` icon) with the DropZone error variant, "That file isn't a PDF.", Open another file… and Show in Finder, and Convert to PDF… disabled until P3; a1-9d draws a read-only file opening read-only as in a11-7c, with a lock on the tab, Read-only in the status bar, Save disabled with the tooltip "Read-only" and a Banner that says why; a1-9e draws a missing recent file with "Remove from list" and "Locate…"; a1-9f draws an out-of-memory failure that closes only its tab, with a danger Toast and Try again. Was Decided.
- **Evidence:** The FmStart strings; FmWindow `save="readonly"` appears only in a11-7c; the DropZone `.fm-drop--error` variant is unused. In 519d42a: `design/01 First run and files.dc.html` lines 192–196 (a1-9c), 197–204 (a1-9d), 205–209 (a1-9e), 210–217 (a1-9f) and 329 (their English strings); `design/FmWindow.dc.html` line 229 (`saveTip`: "Read-only").

<a id="g29"></a>

### G29 · Empty sidebar tabs and search states not drawn

- **Type:** missing state
- **Milestone:** M2
- **Area:** Sidebar and search
- **Artboards:** `a2-3p`, `a2-3o`, `a2-3b`, `a2-3c`, `a2-3d`, `a2-3e`, `a2-3x`, `a2-4a`, `a2-4b`, `a1-7`, `a3-11`, `a7-5`, `a7-5b`, `a11-1f`, `a8-2c`; partly resolved by `a2-3m`, `a2-4c` and `a2-4d` (export 519d42a)
- **Gap or conflict:** The sidebar tabs (a2-3p, a2-3o, a2-3b, a2-3c, a2-3d, a2-3e, a2-3x) are drawn only with content. FmSidebar's data is hard-coded and has no empty branch, so there is no empty outline, attachments, layers or signatures state. Search (a2-4a, a2-4b) has no "No results" state and no state for a search that is still running; a1-7 covers only the indexing before search turns on for a large file. The no-text-layer case is drawn only in Edit (a3-11, "No text on this page yet · Recognize text to edit"), not in Search. The design system has no EmptyState component (`components/empty` holds only DropZone). OCR is fully drawn (a3-11, a7-5, a7-5b, a11-1f), but it is a phase 3 feature.
- **Decision:** Specify one EmptyState component from design-system tokens (icon, title, one line, optional action) and use it for every empty sidebar tab, for search with no results, and for the language filter ([G20](#g20)). A long search shows progress and Cancel in the find bar, following the a1-7 indexing pattern. A page without text says so in Search, and its OCR action is disabled with "Available in a future version" until P3 (brief §7: OCR is phase 3).
- **Status:** Decided; partly resolved on 2026-10-17 by export 519d42a. a2-3m specifies the EmptyState (a 40 px sunken icon tile, a title, one line, an optional action) and draws it for the empty Outline, Attachments, Layers and Signatures tabs, for Search with no result ("No results for “depozito”") and for Search in a document without text ("No text to search", with Recognize text (OCR) disabled with the future-version tooltip). a2-4c draws a long search with its progress under the find bar (the page reached, a bar, Cancel) while the matches found so far are counted and highlighted; a2-4d draws the find bar's "No results" with what was searched and where to look next. Still undrawn: the empty task drawer and the language filter with no match ([G20](#g20)), which the a2-3m note names as uses of the same EmptyState.
- **Evidence:** Every sidebar board uses `FmSidebar doc="kira"`. The only "0 matches" is on a8-2c, where it confirms a redaction. `components/empty` holds DropZone only. In 519d42a: `design/02 View.dc.html` lines 105–107 (a2-3m, six sidebars and the note), 134–140 (a2-4c) and 141–148 (a2-4d); `design/FmSidebar.dc.html` lines 98–101 (`ESS`, the empty-state strings).

<a id="g30"></a>

### G30 · Tile loading, zoom and Go to page states not drawn

- **Type:** missing state
- **Milestone:** M2
- **Area:** Rendering / zoom
- **Artboards:** `a2-1a`, `a2-1c`, `a2-1d`, `a2-2`, `a1-7`, `a6-5`, `a11-1`, `a11-2`, `a11-3`, `a13-16`; partly resolved by `a2-13` (export 519d42a)
- **Gap or conflict:** Drawn: Fit page (a2-1a), spread and book at 55 % (a2-1c, a2-1d) and the zoom menu (a2-2: Fit width ⌘2, Fit page ⌘0, Actual size ⌘1). Not drawn: tiles loading or sharpening while zooming or scrolling, a page that fails to render, and the Fit width and Actual size selected states, although Fit width is the default zoom in Settings › General (a11-1). a1-7's "Rendering page 2" spinner page is the only per-page placeholder, and only during the large-file open; mobile a13-16 notes that "the rest load while you read". Go to page exists only as a shortcut (⌘G, a11-3), a palette group (a11-2) and a note (a6-5); the status-bar page indicator is static text.
- **Decision:** Tiles draw a low-resolution version first and sharpen in place, without layout shift ([ADR 0009](adr/0009-threading-and-jobs.md)). A page that fails to render shows a placeholder with a plain message and a retry, and the rest of the document keeps working. The status-bar page indicator becomes an editable field that ⌘G or Ctrl+G focuses and that accepts page labels, as a6-5 describes. The zoom control shows Fit width and Actual size when selected.
- **Status:** Decided; partly resolved on 2026-10-17 by export 519d42a. a2-13 draws low-resolution tiles sharpening in place without layout shift (the lower part of page 2), a page that failed to render with a placeholder ("Ferman couldn't draw page 3.", "Something on this page can't be read. The rest of the document works as usual.") and Try again, Fit width selected in the Fit control and named in the zoom field while the status bar shows the zoom it gives, and the status bar's page field, which ⌘G or Ctrl+G focuses and which takes page numbers and labels. Actual size's selected state is still undrawn.
- **Evidence:** FmWindow's `fit` prop is only ever `"page"`. Settings › General defaults Zoom to `fitw`. The status-bar page text is a plain span. In 519d42a: `design/02 View.dc.html` lines 263–270 (a2-13: `fit="width"`, `page-edit`, the note at line 270); `design/FmWindow.dc.html` lines 169 and 244 (`pageEdit`).

<a id="g31"></a>

### G31 · Signatures shown as valid before validation exists

- **Type:** missing state
- **Milestone:** M2
- **Area:** Signatures sidebar
- **Artboards:** `a2-3d`, `a2-1a`, `a2-1b`, `a2-1c`, `a2-1d`, `a2-2`, `a2-3a`, `a2-4a`, `a2-4b`, `a2-6`, `a2-7`, `a2-9`, `a1-4`, `a1-4b`, `a1-4c`, `a13-2`, `a13-3b`, `a8-4`, `a5-7`, `a5-7e`, `a11-1e`; resolved by `a2-14` and `a1-4-m2` (export 519d42a)
- **Gap or conflict:** Signature validation is phase 3, but every signature surface shows a checked result: the Signatures tab a2-3d ("Valid. The document hasn't changed since it was signed.", "e-imza · 13.10.2026 11:04"); the View doc panel ("1 valid signature, page 3", green) on nearly every 02 View board (a2-1a to a2-9); the green "Signed" badge on Start and on mobile (a1-4, a1-4b, a1-4c, a13-2, a13-3b); and "2 valid signatures" in a8-4. a5-7 to a5-7e show validation states only, and a11-1e offers revocation checks when opening signed files. No board shows a signature that is present but not checked, which is all that M2 to M5 can show.
- **Decision:** Until P3, signatures appear in a neutral state, with no validity colour or check icon. The Signatures tab shows the signer's name as written in the file and "Signature checking is available in a future version". The doc panel says "1 signature, page 3", and file lists use the neutral signature chip. P3 replaces the neutral state with the drawn validation states.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a2-14 draws the Signatures tab with the signer's entry in the neutral state (the `signature` icon in the secondary icon colour, "Signature checking is available in a future version.") and the document panel's "1 signature, page 3" with no green and no check; a1-4-m2 draws the neutral Signed chip, with the `signature` icon and no green, on the signed recent file. The other boards keep drawing the validated states of P3. Was Decided.
- **Evidence:** FmSidebar.dc.html line 153; FmDocPanel.dc.html line 25 (badge-check in `--success-solid`). The Index defines `R='ready'` and `P='planned'`, and no board uses P. In 519d42a: `design/02 View.dc.html` lines 271–279 (a2-14); `design/FmSidebar.dc.html` lines 99 (`sigFuture`) and 186 (`sigNeutral`); `design/FmDocPanel.dc.html` line 25 (`sigNeutral`: "1 signature, page 3"); `design/FmStart.dc.html` lines 76 (`signedNeutral`) and 89.

<a id="g32"></a>

### G32 · Page order for right-to-left documents undefined

- **Type:** ambiguity
- **Milestone:** M2
- **Area:** RTL documents: spread/book/organize order
- **Artboards:** `a2-1c`, `a2-1d`, `a6-1`, `a6-1b`, `a9-6b`, `a12-1ar`, `a12-2a`, `a12-3b`, `a13-10`; partly resolved by `a2-15` (export 519d42a)
- **Gap or conflict:** Spread and booklet order already follow the document's own direction: the a2-1c note ("In right-to-left documents the spread starts from the right"), a9-6b binding and a12-3b swiping; a12-1ar keeps the Turkish page unmirrored. Still open: (1) whether "document direction" comes from `/ViewerPreferences/Direction` or from the content language; (2) the right-to-left book layout (cover position, first spread), because a2-1d is left-to-right only and no right-to-left document is drawn in any layout; (3) whether the Organize grid (a6-1, a6-1b; mobile a13-10) and the thumbnail order flow right to left under an Arabic UI, as the Start file grid does in a12-2a; (4) page content staying unmirrored in those views.
- **Decision:** Spread and book order follow the document's `/ViewerPreferences/Direction` only (`/R2L` puts the first page on the right). With no entry the order is left to right, the PDF default; it never follows the UI language or a guessed script. In book layout a right-to-left document mirrors the cover rule of a2-1d. The Organize grid and thumbnail order follow the UI direction, as the Start grid does, and page content is never mirrored ([ADR 0014](adr/0014-localization-and-rtl.md)). The test corpus gets a right-to-left Arabic document for goldens.
- **Status:** Decided; partly resolved on 2026-10-17 by export 519d42a. a2-15 draws a two-page spread of an Arabic document whose `/ViewerPreferences/Direction` is `/R2L`: page 1 on the right and page 2 on its left, in every interface language, and its note settles point (1) as this entry does: the order follows only that entry, left to right without it, never the UI language. Still undrawn: the right-to-left book layout and the Organize grid and thumbnails of a right-to-left document; the a2-15 note states this entry's decision for them (the cover stands alone on the left, mirroring a2-1d; the grid and thumbnails follow the interface direction; page content is never mirrored).
- **Evidence:** 02 View.dc.html line 53 (the a2-1c note); 09b line 91 ("Binding follows the document direction"); the a12-2a note ("Grid flows right to left"). In 519d42a: `design/02 View.dc.html` lines 280–286 (a2-15: `layout="two"`, the pages at line 283, the note at line 286) and 66 (the a2-1d note: "The cover stands alone on the right").

<a id="g33"></a>

### G33 · Drawn features with no milestone

- **Type:** ambiguity
- **Milestone:** M2
- **Area:** Roadmap mapping
- **Artboards:** `a2-3c`, `a2-5a`, `a2-5b`, `a2-6`, `a2-8a`, `a2-8b`, `a2-9`, `a4-1c`, `a9-7`, `a9-6`, `a9-6b`, `a9-6c`, `a9-6d`, `a13-4d`, `a14-1c`
- **Gap or conflict:** The design maps no board to any milestone: the Index marks every board "ready" and none "planned", and there are no milestone tags. The brief's roadmap does not name these drawn features: presentation mode (a2-5a), reading mode (a2-5b), read aloud (a2-6), split view (a2-8a, a2-8b), inverted dark reading (a2-9), the layers tab (a2-3c), measure (a4-1c, a9-7), basic print with booklet, poster and production preview (a9-6, a9-6b, a9-6c, a9-6d), plus mobile night mode and read aloud (a13-4d) and iPad split view (a14-1c).
- **Decision:** The mapping the owner accepted on 2026-10-16 ([Q10](QUESTIONS.md#q10)): layers tab → M2 (rendering); basic system print → M4; presentation, reading mode, split view and inverted dark reading → P2; read aloud and measure → P4; booklet, poster and separations (a9-6b, a9-6c, a9-6d) → P5; mobile night mode and read aloud, and iPad split view → P5 with the mobile and tablet apps. Until a feature ships, its entry points stay visible, disabled with "Available in a future version", and listed in [BACKLOG.md](BACKLOG.md) ([ROADMAP.md](ROADMAP.md), "Not scheduled yet").
- **Status:** Decided. The owner accepted the proposed mapping on 2026-10-16 ([Q10](QUESTIONS.md#q10)). Was Needs owner.
- **Evidence:** Index.dc.html: `const R='ready', P='planned'`, with no use of P. No board carries an M1 to M5 or P2 to P5 tag.

<a id="g34"></a>

### G34 · Dates and numbers mix four locale styles

- **Type:** conflict
- **Milestone:** M2
- **Area:** Locale formatting in English UI
- **Artboards:** rule: `a11-1b`, `a12-2c`, and `a12-0` (export 519d42a), which resolves this entry; dates: `a2-7`, `a1-4`, `a1-4b`, `a1-4c`, `a1-6`, `a12-2a`, `a2-3b`, `a2-3d`, `a5-5c`; decimals: `a1-2a`, `a3-1b`, `a3-1c`, `a3-3a`, `a3-4`, `a1-9b`, `a12-1ja`, `a13-5`, `a12-1tr`, `a12-1de`, `a9-1`, `a11-6b`
- **Gap or conflict:** a11-1b states the rule: region formats drive dates and numbers (with the region Türkiye: "13.10.2026", "18.500,50", "10,5 pt"), and a12-2c repeats it. The boards break it with four date styles: "13 Oct 2026, 14:32" (the FmDocPanel on most 02 View boards, a2-7), the US "Oct 12, 2026" (Start a1-4, a1-4b, a1-4c, a1-6), "١٢/١٠/٢٠٢٦" (Arabic Start a12-2a, Arabic-Indic digits through FmStart's dg()) and the region-correct "13.10.2026" (a2-3b, a2-3d, a5-5c). Decimals mix too: "10.5 pt" and "2.4 MB" (a1-2a, a3-1b, a3-1c, a3-3a, a3-4, a1-9b, a12-1ja, a13-5) against "10,5 pt", "1,2 MB" and "24,6 MB" (a12-1tr, a12-1de, a2-3b, a9-1, a11-6b). FmStart dates and the font-size labels in a12-1tr, a12-1de and a12-1ja follow the UI language.
- **Decision:** Numbers, dates, file sizes, paper sizes and units always follow the region setting (a11-1b), never the UI language ([ADR 0014](adr/0014-localization-and-rtl.md)). Boards that show another format are read as drawn for another region. Goldens fix the region in each test. Built in M1 (`app/lib/l10n/region.dart`, `format.dart`). The digits come from the region. Both Arabic boards draw Arabic-Indic digits: a12-1ar ("١٠٫٥ pt") and a12-2a, whose dates FmStart converts with dg() (lines 82–87; rendered "١٢/١٠/٢٠٢٦"). They are the Saudi Arabia region, and goldens of the Arabic boards use Saudi Arabia. The United Arab Emirates region writes Latin digits, as CLDR's ar-AE does; no board draws it. Numeric dates follow CLDR `yMd`, so the German region writes "2.10.2026" and "28.9.2026" where a12-2b draws "02.10.2026" and "28.09.2026"; accepted. a12-2a writes Arabic times on a 24-hour clock ("اليوم ١٤:٣٢"); CLDR's ar-SA and ar-EG write "h:mm a" ("٢:٣٢ م"). Times follow CLDR; accepted. US times keep CLDR's U+202F before "PM". The a11-1b week picker draws Monday, Sunday and Saturday; a region whose CLDR first day is Friday (the Maldives) adds a Friday option. Percentages: Turkish CLDR writes "%100", with the sign first, while the boards draw "100%" (no "%100" appears anywhere in `design/`). The app follows CLDR through `RegionFormat.percent`, added in M1: "%100" for Türkiye, "100%" for the United States and "١٠٠٪" for Saudi Arabia, with CLDR's U+061C after the sign. The shell's zoom readouts (the status bar and the View row's zoom menu) and the "100%" zoom option in Settings › General use it ([G74](#g74)). The goldens fix the region per language ([G97](#g97)): Türkiye for Turkish, Saudi Arabia for Arabic, and the United Kingdom for English, whose 24-hour clock and "100%" give FmWindow's "14:32" and "100%" (the United States would write "2:32 PM"); Settings › Language and region uses Türkiye in every language, as a11-1b and a12-2c show.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a12-0, "Region formats, from CLDR", tabulates this decision for Türkiye, the United Kingdom, the United States, Germany, Saudi Arabia and the United Arab Emirates (date, time, number, percent and font size), marks Türkiye, the United Kingdom and Saudi Arabia as the Turkish, English and Arabic golden regions, and its note repeats the rules: the region, never the interface language; digits from the region; CLDR `yMd` dates ("2.10.2026" for Germany); CLDR times ("٢:٣٢ م", the narrow space before "PM"); "%100" for Türkiye, which FmWindow's zoom field and status bar now use; other formats on the boards read as drawn for another region. Was Decided; on 2026-10-16 the percentage helper arrived in M1 (the entry had left percentages to the zoom field in M2), the golden regions were added, and the owner kept the United Kingdom for the English goldens.
- **Evidence:** FmSettings.dc.html line 95 (the a11-1b examples); FmStart lines 66–72 ("Oct 12, 2026" in English, "12.10.2026" in German, "12/10/2026" in Arabic, turned into Arabic-Indic digits by dg() at lines 82–87). In 519d42a: `design/12 Localization.dc.html` line 39 (a12-0, a table without the board-language switch, which ROADMAP §6 step 6 makes the oracle of the M2 `RegionFormat` tests); `design/FmWindow.dc.html` line 219 (`pct`).

<a id="g35"></a>

### G35 · No warning before editing a signed document

- **Type:** missing screen
- **Milestone:** M3
- **Area:** Edit: signed-document warning
- **Artboards:** resolved by `a3-16a`, `a3-16b` and the signature row of `a3-12` (export 519d42a); edits on a signed file: `a3-1a`, `a3-1b`, `a3-1c`, `a3-2`, `a3-3a`, `a3-4`, `f4a`, `a12-1tr`, `a12-1de`, `a12-1ar`, `a12-1ja`; signature facts: `a2-3p`, `a2-3d`, `a5-5c`, `a5-6d`; scattered copy: `a9-1`, `a9-5`, `a9-5b`, `a6-3`, `a4-5b`, `a3-13a`, `a8-4`, `a5-7`, `a5-7e`, `a13-11`; no policy in `a3-12`, `a11-1c`, `a11-1e`
- **Gap or conflict:** No board draws a warning before the first edit of a signed document; Edit, Comment, Fill and Save have no such state, and a3-12 has no signature row. The tab edited in a3-1a to a3-4, f4a and a12-1tr, a12-1de, a12-1ar and a12-1ja is "Kira sözleşmesi.pdf", which the View doc panel lists with "1 valid signature, page 3" and whose page-3 thumbnail carries the signature badge (a2-3p, a3-4). The two valid signatures in a5-5c belong to a separate copy, "Kira sözleşmesi — imzalı.pdf" (a5-6d). Signature-consequence copy exists but is scattered and never covers ordinary editing: the a9-1 note (compress, not drawn), a9-5 and a9-5b (batch), a6-3 (combine), a4-5b (flatten), a3-13a ("signatures kept"), a8-4 and flow C (redact), a5-7 and a5-7e (after the fact), and a13-11.
- **Decision:** Brief §4 requires the warning. Before the first change to a signed document the engine asks for confirmation ([ADR 0005](adr/0005-block-scoped-text-editing.md)), and the UI shows a custom dialog that says how many signatures will become invalid and offers "Edit a copy" (default), "Edit anyway" and "Cancel". After "Edit anyway", a persistent banner says the signatures are no longer valid. The same check runs before the first change in Comment, Fill, Organize and Save, and the notice says what that change does to the signatures (for example, filling fields that a certification allows keeps it valid). The review list gets a signature row ([G42](#g42)). It is built from the design system's Dialog and Banner; boards are asked for in the re-export.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a3-16a draws the dialog before the first change ("Edit a signed document?", how many signatures the change invalidates and by whom, Edit a copy as the default with Enter, Edit anyway, Cancel with Esc, and where the copy opens); a3-16b draws the warning Banner that stays after Edit anyway, with Review edits, and the page-3 thumbnail's warning badge; a3-12 adds the signature row at the top of the review list. The a3-16a note names the same check before the first change in Comment, Fill & Sign and Organize and before saving a repaired file, where this entry said Save; the board's reading holds, because an ordinary save follows a change that was already confirmed. It also says no setting turns the check off ([G43](#g43)). Was Decided.
- **Evidence:** No "Edit a copy" or "Edit anyway" copy exists. FmDocPanel.dc.html lines 21–25; a3-4 `thumbsWarn` marks page 3 `{fields:true, signed:true}`; 15 Flows line 78 (flow C's branch "The file is signed" links to a8-4). In 519d42a: `design/03a Edit text.dc.html` lines 153–162 (a3-16a) and 163–171 (a3-16b); `design/03c Edit review and translate.dc.html` lines 60–74 (a3-12 and its note) and 202 (the signature row).

<a id="g36"></a>

### G36 · Missing glyph: the design substitutes by default

- **Type:** ambiguity (resolved)
- **Milestone:** M3
- **Area:** Edit: missing glyph
- **Artboards:** `a3-3a`, `a3-3b`, `f2`, `a11-1c`, `a13-5c`; resolved by the `a3-3a` note and `a3-17` (export 519d42a)
- **Gap or conflict:** The design is not silent. It says so once (FmEditPanel and f2: "This font has no ‘ğ’. Ferman will use a similar font for this character."), marks the glyph with an amber wavy underline and a page warning badge, and offers "Choose a font…", "Keep as is" and the a3-3b picker. a11-1c also offers "Ask each time" and "Keep the original font and mark the character". The open point: the default (a11-1c "Use a similar font and say so", the FmEditPanel and f2 copy, a13-5c and flow A) applies a similar font at once and skips the brief's middle step, taking the glyph from the same font installed on the system and re-subsetting it. That step is only implied by the f2 note (the `warning` prop "is reserved for fonts that are not installed") and is never drawn; the a3-3b installed group shows only other families.
- **Decision:** Three steps in the brief's order ([ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md)): (1) use the embedded glyph if it is present; (2) if the same font is installed, take the glyph from it, re-subset, embed it as a new font resource for the edited runs, and say so once; (3) otherwise follow the design's flow as drawn: the a11-1c default "Use a similar font and say so", marked once, with "Choose a font…" and "Keep as is", and "Ask each time" available in Settings. Nothing is ever substituted silently. The owner confirmed this default on 2026-10-16 ([Q09](QUESTIONS.md#q09)).
- **Status:** Resolved on 2026-10-17 by export 519d42a: the a3-3a note now says a3-3a is step 3 (the embedded glyph is missing and the same font isn't installed), and a3-17 draws step 2: "Character added from this computer", "Ferman took ‘ğ’ from Garamond Premier Pro installed on this computer and added it to the document's font.", with the three steps in the brief's order in its note. Was Decided; the owner confirmed the default, "Use a similar font and say so", and the `fsType` detail of ADR 0006 on 2026-10-16 ([Q09](QUESTIONS.md#q09)). Was Needs owner before that.
- **Evidence:** FmEditPanel.dc.html line 44; 00 Fixes lines 45–53; FmSettings.dc.html line 44 (the a11-1c radios, first one checked); 15 Flows line 54; 03a lines 163–174 (the a3-3b groups). In 519d42a: `design/03a Edit text.dc.html` lines 83 (the a3-3a note) and 174–176 (a3-17 and its note).

<a id="g37"></a>

### G37 · Missing-glyph steps and outcomes not drawn

- **Type:** missing state
- **Milestone:** M3
- **Area:** Edit: missing glyph
- **Artboards:** `a3-3a`, `a3-3b`, `a13-5c`, `a3-12`, `a11-6`, `f5`, `a11-1c`, `a2-7`, `a3-7`, `a3-9`; resolved by `a3-17` (export 519d42a)
- **Gap or conflict:** The warning (a3-3a, and a13-5c on mobile) and the picker (a3-3b) are the only full missing-glyph screens. Some later pieces exist: a3-12 has a font-substitution row ("Madde 6 · font: Garamond Premier Pro → EB Garamond (whole block)") with a Fonts filter, a11-6 has a "Font substituted" toast, the f5 thumbnail tooltip covers a kept warning, a11-1c has the policy setting, a2-7's font list notes that typing ‘ğ’ needs a substitute, and a3-3b has a scope control ("Missing characters only" or "Whole block"). Not drawn: (a) step 2, where the same font (Garamond Premier Pro) is installed and the glyph is re-subset from it; (b) no font covers the character; (c) the font's licence forbids embedding; (d) the page after substitution, in either scope; (e) missing glyphs in find-and-replace text (a3-7) or in table cells (a3-9).
- **Decision:** Built from the a3-3a callout pattern with new copy ([ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md)): (a) step 2 says once where the glyph came from (for example "Ferman took ‘ğ’ from Garamond Premier Pro on this computer"); (b) when no font covers the character, the callout says so and offers only "Choose a font…" and "Keep as is"; (c) fonts whose `fsType` forbids embedding are listed with the reason and skipped; accepted with [Q09](QUESTIONS.md#q09) on 2026-10-16: text set in an embedded font whose OS/2 `fsType` allows at most preview and print does not reuse its embedded glyphs, so step 2 runs only if the installed copy allows embedding, and otherwise step 3, with the reason shown; (d) substituted characters keep the f2 marking, in the scope chosen; (e) find and replace (P2) and table cells use the same flow. Every case lands in the review list. Boards are asked for in the re-export.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a3-17 draws the panel callouts for (a) step 2 ("Character added from this computer"), (b) no font with the character ("No font has this character", offering only Choose a font… and Keep as is) and (c) a licence that allows only preview and print ("This font can't be embedded", going on to a similar font), and its note states (d) and (e) as decided here: the f2 marking in the scope chosen in a3-3b, every case in Review edits, and the same flow for find and replace and table cells. Was Decided.
- **Evidence:** 03a lines 162–174: every alternative in a3-3b shows "Full Turkish" and none has a licence flag. FmEditPanel has only `glyph` and `noGlyph` booleans. 11b line 162 holds the toast. In 519d42a: `design/03a Edit text.dc.html` lines 174–176 (a3-17 and its note); `design/FmEditPanel.dc.html` line 73 (the new `callout` prop).

<a id="g38"></a>

### G38 · Overflow results not drawn

- **Type:** missing state
- **Milestone:** M3
- **Area:** Edit: overflow
- **Artboards:** `a3-4`, `a13-5c`, `a3-12`, `f5`; resolved by `a3-18` (export 519d42a)
- **Gap or conflict:** a3-4 (and a13-5c on mobile) draws only the choice, with FmEditPanel's "Extend block by 1 line", "Tighten spacing slightly (−0.6%)" and "Keep and warn". "Keep and warn" is partly shown afterwards: a3-12 lists "kept warning — 1 line hidden — overflow kept", and page 1's warning badge appears by default on every board of the rental contract. Not drawn: the result of Extend block, the result of Tighten spacing, Extend colliding with the IBAN line below, tightening that is not enough, and the on-page kept-warning marker after the choice.
- **Decision:** As [ADR 0005](adr/0005-block-scoped-text-editing.md) says. Extend block grows the frame and is disabled, with the reason, when it would overlap other content such as the IBAN line. Tighten spacing slightly stays within a small cap and is disabled, with the reason, when that is not enough. Keep and warn loses no text: lines that do not fit are clipped to the frame, and the `--overflow-mark` with "+1 line hidden" stays on the page, with the thumbnail badge and the review-list row. Result boards are asked for in the re-export.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a3-18 draws the three results (the frame extended by one line into free space; character spacing tightened by −0.6% inside the small cap; the line kept, clipped, with "+1 line hidden") and the panel with a choice that can't apply: Extend block disabled with "The IBAN line sits right below this block." under it, and Tighten spacing slightly disabled with "Even the tightest allowed spacing leaves 1 line over.". Its note adds that the page snippets keep the document's own direction in every interface language. Was Decided.
- **Evidence:** a3-4 renders `FmEditPanel overflow=true`. FmSidebar line 105 sets `warn:true` on page 1. No board shows an extended or tightened block. In 519d42a: `design/03a Edit text.dc.html` lines 111 (the a3-4 note, pointing to a3-18) and 177–179 (a3-18 and its note).

<a id="g39"></a>

### G39 · Text that cannot be edited has no state

- **Type:** missing state
- **Milestone:** M3
- **Area:** Edit: non-editable content
- **Artboards:** `a3-11`, `a8-1`, `a8-4`, `a2-7`, `a11-7c`; partly resolved by `a3-19` (export 519d42a)
- **Gap or conflict:** The only drawn treatment of content that cannot be edited is the scanned page in a3-11: a not-allowed cursor, the tooltip "No text on this page yet · Recognize text to edit", a banner and a panel. Nothing is drawn for Type3 or outlined glyphs, text inside form XObjects, content streams that cannot be parsed, documents whose permissions forbid editing, or files that are read-only on disk. a11-7c's read-only state is the XFA case in View mode, not feedback in Edit mode.
- **Decision:** Reuse the a3-11 pattern for every case: a not-allowed cursor on hover, an inverse tooltip with the reason, and a panel callout. Reasons include text drawn as vector paths rather than glyphs, content the engine cannot parse or rewrite safely (for example a form XObject shared with other pages that cannot be split), editing forbidden by the document's permissions ([G27](#g27)) and a file that is read-only on disk ([G28](#g28)). On scanned pages the OCR action stays disabled with "Available in a future version" until P3. An edit case that cannot pass the zero-pixel-difference test becomes "not editable" with a reason instead of being attempted.
- **Status:** Decided; partly resolved on 2026-10-17 by export 519d42a. a3-19 draws one reason, text drawn as vector shapes: the inverse tooltip with a lock ("This text is drawn as shapes, so it can't be edited") and the panel callout "This text can't be edited", reusing a3-11's pattern, and its note repeats this decision, the zero-pixel-difference rule included. The other reasons (content the engine can't parse or rewrite safely such as a shared form XObject, editing forbidden by the permissions, a file read-only on disk) are named only in that note and are still undrawn.
- **Evidence:** No board mentions Type3, outlined text, XObjects or editing restrictions. 03c lines 34 and 45 hold the a3-11 cursor and tooltip. In 519d42a: `design/03a Edit text.dc.html` lines 182–190 (a3-19 and its note).

<a id="g40"></a>

### G40 · Most save failures not drawn

- **Type:** missing state
- **Milestone:** M3
- **Area:** Save / atomic save
- **Artboards:** `f4`, `f4a`, `f4b`, `a11-6`, `a11-7`, `a11-7b`, `a11-7c`, `a1-10b`, `a1-12`, `a11-4`; resolved by `a11-7d`, `a11-7e` and `a11-7f` (export 519d42a)
- **Gap or conflict:** Drawn: the save states (f4, f4a, f4b), disk full (a11-7, the f4 toast and the a11-6 toast), changed on disk with unsaved edits (a11-7b), and FmWindow `save="readonly"` (a11-7c: XFA, a lock and "Read-only" in the status bar). Not drawn: a read-only or permission-denied destination on save, the atomic rename failing, a file locked by another app, a network drive disappearing, quitting with several unsaved documents (a1-10b covers one document; the a11-4 note mentions restoring unsaved documents after an update restart), and crash recovery when the original changed on disk (a1-12 says outright that the files haven't changed).
- **Decision:** One family of save errors that reuses the a11-7 layout ([ADR 0008](adr/0008-file-safety-and-saving.md)). Each failure (read-only or permission denied, locked by another app, rename failed, volume gone) says what happened, keeps the edits and offers "Try again" and "Save as…". The read-only tab state follows a11-7c. Quitting with unsaved documents shows one dialog that lists them, built from a1-10b. Recovery checks the original's recorded hash and shows a conflict state in a1-12 if the original changed.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a11-7d draws the family in a11-7's layout (permission denied, locked by another app, couldn't replace the original, drive disconnected), each saying the edits are kept and offering Try again and Save as…, with the unsaved dot kept and "Couldn't save" in the status bar; a11-7e draws quitting with three unsaved documents, built from a1-10b (one checked row per document, Save and quit, Quit without saving, Cancel, and the Windows button order); a11-7f draws recovery when an original changed after its copy (the hash recorded with the copy, a "Changed on disk" badge, the restored version opening under a new name so neither is overwritten). Was Decided.
- **Evidence:** 11b line 96 (a11-7, `save="error"`) and line 112 (a11-7c, `save="readonly"`). The a1-12 caption: "Restored documents open as unsaved; the files on disk haven’t changed." 15 Flows lists only "Disk full while saving". In 519d42a: `design/11b App.dc.html` lines 119 (a11-7d), 120–126 (a11-7e), 127–130 (a11-7f) and 143–147 (their strings).

<a id="g41"></a>

### G41 · Save disabled in the error state

- **Type:** conflict
- **Milestone:** M3
- **Area:** Save button states
- **Artboards:** `f4`, `a11-7`; resolved by FmWindow and the notes of `a11-7` and `a1-9d` (export 519d42a)
- **Gap or conflict:** f4's state table shows "Couldn't save" with Save enabled, but FmWindow computes `saveDisabled: save !== 'unsaved'` and sets the tooltip to "No changes to save" for every state except unsaved. So a11-7, rendered with `save="error"`, shows a disabled Save with that tooltip, while the tab shows the unsaved dot and the dialog offers "Try again" and "Save somewhere else…".
- **Decision:** Follow f4, the binding fix: Save stays enabled in the error state so the user can retry. It is disabled only when saved, saving or read-only, and its tooltip matches the state.
- **Status:** Resolved on 2026-10-17 by export 519d42a: FmWindow now disables Save only when saved, saving or read-only, with "No changes to save" or "Read-only" as its tooltip, so a11-7 (`save="error"`) shows Save enabled, as its new note says; a1-9d shows the read-only Save with the tooltip "Read-only". Was Decided.
- **Evidence:** 00 Fixes line 91: the "Couldn't save" row has no `disabled` prop, while "Saved" has `disabled={{ true }}`. FmWindow.dc.html line 227. In 519d42a: `design/FmWindow.dc.html` line 229 (`saveDisabled`, `saveTip`); `design/11b App.dc.html` line 95 (the a11-7 note); `design/01 First run and files.dc.html` line 204 (the a1-9d note).

<a id="g42"></a>

### G42 · Review list has no empty or confirm states

- **Type:** missing state
- **Milestone:** M3
- **Area:** Edit review list
- **Artboards:** `a3-12`, `f4b`, `a3-5a`; resolved by `a3-12b` and the changed `a3-12` (export 519d42a)
- **Gap or conflict:** a3-12 shows only the populated list (5 rows). It has no empty state, no confirmation for "Revert all…" (only the button) and no conflict when reverting an edit that another edit depends on. There is no signed-document row, and no edit-time signature warning exists anywhere ([G35](#g35)). The list already has a font-substitution row and a kept-overflow warning row, with All, Text, Fonts and Warnings filters. The f4b note says edit marks stay until the document is closed; what happens after reopening is not stated. The "Page 1 · new text box" row needs Add text (a3-5a), which is phase 2.
- **Decision:** Add an empty state (EmptyState, [G29](#g29)), a confirmation dialog for "Revert all…", a notice when a revert would also undo edits that depend on it, and a signed-document row ([G35](#g35)). The list covers the current session and clears when the document closes, as f4b says; earlier sessions are reached through version history (M4). In M3 the new-text-box row cannot occur, so M3 goldens use an M3 edit type in its place.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a3-12b draws the empty list with the shared EmptyState ("No edits yet") and Revert all and Export list disabled, the confirmation for Revert all… ("Revert all 5 edits?", undoable until the document closes), and the notice for an edit that a later edit builds on ("Also revert the edit that depends on it?", Revert both); a3-12 gains the signature row at the top ("Mert Kaya's signature is no longer valid"), and its note states the session scope with earlier sessions in Version history and the M3 goldens' stand-in for the new-text-box row. Was Decided.
- **Evidence:** The 03c script's `E[]` rows; footer buttons "Revert all…" and "Export list…". No "no edits" or "nothing to review" string exists. In 519d42a: `design/03c Edit review and translate.dc.html` lines 60–74 (a3-12 and its note), 77–87 (a3-12b and its note) and 201–202 (`E`, with the signature row).

<a id="g43"></a>

### G43 · No saving options in Settings › Editing

- **Type:** missing state
- **Milestone:** M3
- **Area:** Settings › Editing
- **Artboards:** `a11-1c`, `a1-12`, `a11-7`, `a3-4`, `a11-1e`; resolved by the changed `a11-1c` (export 519d42a)
- **Gap or conflict:** a11-1c has "Keep versions" (30 days next to the file, 7 days, Don't keep versions) and "Save a recovery copy every minute", so recovery can be turned off. Not drawn: any explanation or choice of incremental versus full saving (incremental is the default and keeps signatures), a recovery interval, the recovery-copy location (a1-12 says only that Ferman "kept a copy of each on this device", and a11-7 names the copy without a path), a default for overflow, and a preference for the signed-document warning (a11-1e has only the revocation switch).
- **Decision:** Add a "Saving" group to a11-1c in its existing style. It explains that changes are saved at the end of the file by default (faster, and signatures stay intact), offers "Optimize and clean" as an explicit command that warns before it breaks signatures and is never the default, and shows where recovery copies are kept, with "Show in Finder" or "Show in Explorer" ([ADR 0008](adr/0008-file-safety-and-saving.md)). The interval stays at one minute, as drawn. There is no overflow default and no signed-warning preference: overflow is chosen per edit (a3-4), and the signed-document warning always shows (brief §4).
- **Status:** Resolved on 2026-10-17 by export 519d42a: a11-1c now draws the Saving group: "Changes are added to the end of the file" ("Saving stays fast, and signatures made before your changes stay intact. Ferman rewrites the whole file only when you choose Optimize and clean."), Optimize and clean as a command-palette action that is never used on its own and warns first when signatures would become invalid, and Recovery copies with the folder (`~/Library/Application Support/Ferman/Recovery`, `%LOCALAPPDATA%\Ferman\Recovery` on Windows) and Show in Finder or Show in Explorer ([G107](#g107)). Its note keeps the one-minute interval, no overflow default and no switch for the signed-document warning. Was Decided.
- **Evidence:** FmSettings.dc.html lines 41–48 (the Editing pane). No board contains "incremental", "end of the file" or "rewrite the whole". In 519d42a: `design/FmSettings.dc.html` lines 48 (the Saving group) and 127 (`recPath`, `showIn`); `design/11a Settings.dc.html` line 33 (the a11-1c note).

<a id="g44"></a>

### G44 · ⌥⌘S bound to three commands

- **Type:** conflict
- **Milestone:** M3
- **Area:** Keyboard shortcuts
- **Artboards:** `a1-11`, `a11-2`, `a11-3`, `a11-1j`; resolved by the changed `a11-1j`, `a11-2` and `a11-3` and FmWindow (export 519d42a)
- **Gap or conflict:** ⌥⌘S is bound to "Save a copy" (the a1-11 note), "Add signature" (the a11-2 palette and the a11-3 Fill & Sign group) and "Sidebar" (the a11-3 Window group, and the FmWindow sidebar tooltip, ⌥⌘S or Ctrl+Alt+S, on every editor board). The a11-3 cheat sheet lists it twice. a11-1j draws the clash as a reassignment in progress (warning text: ⌥⌘S is already "Show or hide sidebar"), which treats Sidebar as the owner, while a11-2 and a11-3 present Add signature on ⌥⌘S as already assigned. The shortcut data is copied in both 11a Settings and 11b App.
- **Decision:** ⌥⌘S stays "Save a copy", the only one of the three tied to saving. Sidebar moves to ⌃⌘S, the usual macOS key for showing a sidebar. Add signature gets ⇧S on every system, active only in Fill & Sign, beside ⇧D for today's date (a11-3). On Windows and Linux the sidebar keeps Ctrl+Alt+S, as FmWindow draws it, so Save a copy has no key there (a1-11 also offers it as a checkbox in Save as). All shortcuts come from one table, and a test fails on any duplicate per platform. M1 already applies this, because the shell tooltips show the Sidebar shortcut ([ADR 0011](adr/0011-flutter-state-navigation-components.md)).
- **Status:** Resolved on 2026-10-17 by export 519d42a: FmWindow's sidebar tooltip is ⌃⌘S (Ctrl+Alt+S on Windows); the a11-2 palette gives Add signature ⇧S; the a11-3 cheat sheet lists Save a copy ⌥⌘S, Sidebar ⌃⌘S and Add signature ⇧S once each; a11-1j draws recording ⌥⌘S for Add signature with the warning "⌥⌘S is already “Save a copy”. Press Enter to reassign it, Esc to keep ⇧S.", and its note repeats this decision, the Windows and Linux keys and the duplicate test included. Was Decided; on 2026-10-16 the keys were filled in: ⇧S for Add signature, and on Windows and Linux Ctrl+Alt+S stays the sidebar, so Save a copy has no key there.
- **Evidence:** 01 First run and files line 211; 11b App lines 134, 144 and 147; FmWindow.dc.html line 203; FmSettings.dc.html line 141. Implemented in `app/lib/features/shell/shortcuts.dart` (`saveCopy` lines 222–224, `toggleSidebar` lines 300–305, `addSignature` lines 572–577) and checked in `app/test/features/shell/shortcuts_test.dart` lines 143–163 (M1 phase H5). In 519d42a: `design/FmWindow.dc.html` line 203 (`sidebar`: ⌃⌘S, Ctrl+Alt+S); `design/11b App.dc.html` lines 28 and 36 (the a11-2 and a11-3 notes) and 183–190 (the cheat-sheet groups); `design/FmSettings.dc.html` line 162 (the a11-1j recording row); `design/11a Settings.dc.html` line 41 (the a11-1j note).

<a id="g45"></a>

### G45 · Insert, replace and extract dialogs not drawn

- **Type:** missing screen
- **Milestone:** M4
- **Area:** Organize
- **Artboards:** `a6-1`, `a6-1b`, `a6-3`, `a6-5`, `a1-6`, `a11-6`, `a11-6b`, `a13-10`
- **Gap or conflict:** The entry points for Insert blank page, Pages from a file, Replace and Extract exist in the a6-1 panel and context menu, but none of their dialogs is drawn (mobile a13-10 only mentions them). Also not drawn: encrypted or locked inputs that need unlocking in Combine (a6-3), and split or combine rows in the background-task drawer (a11-6b). Delete with undo is drawn (the a11-6 toast "3 pages deleted · Pages 4–6 · Undo", and the a6-1b note), and combining from Start or from a multi-file drop is covered (the a6-3 "Combine files" tab, a1-6 "Combine into one PDF"). The design relies on undo instead of a delete confirmation.
- **Decision:** Build the four dialogs from design-system components: Insert blank page (size, orientation, count, position), Insert pages from file (file, page range, position), Replace pages (range in this document and in the source) and Extract (one file or one file per page, optionally deleting the pages afterwards). Choosing the file uses the picker from [G26](#g26). A locked input in Combine shows a lock row with the a1-8 password field inline. Split and combine run as background tasks with drawer rows. Delete keeps the drawn undo toast and asks for no confirmation.
- **Status:** Decided
- **Evidence:** 06 Organize lines 38–39 and 139 (panel buttons and context menu); 11b line 161 (the toast); the a6-3 file list has no locked file.

<a id="g46"></a>

### G46 · Comment states and commenter name not drawn

- **Type:** missing state
- **Milestone:** M4
- **Area:** Comments and annotations
- **Artboards:** `a4-1`, `a4-1d`, `a4-2`, `a4-3`, `a13-7`, `a13-15`, `a1-1`, `a1-2c`
- **Gap or conflict:** Not drawn: a setting for the commenter's name (no desktop Settings pane, no a13-15 row and no onboarding step from a1-1 to a1-2c asks for it, yet a4-2 shows authors and a4-3's dynamic stamps "fill in your name"); an annotation context menu; an empty comments panel and a filter with no match; deleting a comment with undo; Comment mode on a signed or permission-restricted document; and editing of Text (X) and Callout (C) annotations. Annotation properties are partly drawn: a4-1 has a floating "Rectangle style" bar with Colour, Stroke width, Opacity, Open comment and Delete, and a13-7 has a colour and width palette on mobile.
- **Decision:** The first comment asks once for the name to show on comments, prefilled from the OS account name, editable and allowed to stay empty; it is stored as "Your name for comments" in Settings › General. A context menu offers the style bar's actions. The comments panel uses EmptyState for empty and no-match ([G29](#g29)). Delete shows the undo toast (the a11-6 pattern). Signed and restricted documents get the notices from [G35](#g35) and [G27](#g27). Text and Callout editing reuses Edit mode's text-box editing.
- **Status:** Decided
- **Evidence:** The FmSettings General pane (lines 24–31) has no name field. FmComments props have no empty state. FmWindow.dc.html line 235 lists Text (X) and Callout (C).

<a id="g47"></a>

### G47 · Finish, clear and empty Sign states not drawn

- **Type:** missing state
- **Milestone:** M4
- **Area:** Form filling / simple signatures
- **Artboards:** `a5-1`, `a5-2b`, `a5-3`, `a5-3b`, `a5-3c`, `a5-3d`, `a5-5`, `a5-8`, `a13-8e`
- **Gap or conflict:** Not drawn: the Finish dialog after the last field (flatten or keep editable, then save); the Clear form confirmation; a document-level notice when filling a signed or certified form; the empty Sign menu with no saved signatures; the imported-image signature result (a5-3c shows only the empty "Choose image…" area); and moving between fields on several pages (every Fill board uses one page). Initials creation is drawn: a5-3, a5-3b and a5-3c have "Create: Signature | Initials", and a5-3d lists INITIALS. A read-only signed field appears in a5-2b, as a field state only. Digital signature, e-imza and Prepare form are enabled in the Fill & Sign row, although their flows (a5-5 to a5-8) are phase 3 and phase 4.
- **Decision:** Add a Finish dialog (flatten or keep editable, then Save or Save as), a Clear form confirmation, the signed-form notice ([G35](#g35); it says whether filling keeps a certification valid), an empty Sign menu with "Create signature…", the imported image with crop handles, and field navigation that moves across pages with Tab and Enter. Digital signature, e-imza and Prepare form stay visible and disabled with "Available in a future version" until P3 and P4.
- **Status:** Decided
- **Evidence:** FmFormPanel.dc.html line 25 ("Clear form…", "Finish"); every 05a board sets `pages="{{ 1 }}"`; FmWindow.dc.html lines 96–100 (no disabled tools).

<a id="g48"></a>

### G48 · Compress progress and history states not drawn

- **Type:** missing state
- **Milestone:** M4
- **Area:** Compress / version history
- **Artboards:** `a9-1`, `a9-5`, `a9-8`, `a11-6`, `a11-6b`, `a11-1c`
- **Gap or conflict:** a9-1 Compress shows presets, an estimated before-and-after bar (Now 24,6 MB, After ≈ 6,8 MB) and "Compress and save as…". It does not draw progress, cancel, the final result in context or the signed-file warning; the warning is only in the a9-1 note and is drawn only for Batch (a9-5, "If a file is signed"). a11-6 has no compress toast; the only result is the a11-6b drawer row "Compressed İmar planı… 24,6 MB → 6,9 MB". a9-8 Version history has no restore confirmation, no empty state for a document with no saved versions and no storage-failure state; its footer does point to the retention setting ("Change in Settings › Editing", a11-1c). Both tools live in the Tools mode ([G09](#g09)).
- **Decision:** Compress runs as a background task with progress and Cancel, and ends with a result: the size before and after, Open, and Show in Finder or Show in Explorer. Before it starts on a signed file, it warns with the a9-5 wording. Version history gets a restore confirmation, an empty state and a storage-failure message. Both stay in the Tools row as drawn, and Compress is also a Start quick tool from M4.
- **Status:** Decided
- **Evidence:** 09a Tools lines 27–41 (a9-1); 09b lines 42 and 111–124; 11b lines 87 and 159–163.

<a id="g49"></a>

### G49 · Palette, toast and task drawer states incomplete

- **Type:** missing state
- **Milestone:** M4
- **Area:** Command palette / toasts / background tasks
- **Artboards:** `a11-2`, `a11-6`, `a11-6b`, `a6-1b`, `a12-1ar`, `a14-1d`, `a13-16c`, `f4`
- **Gap or conflict:** a11-2 shows only a populated query ("imza"): no empty-query state, no drawn no-match state (its note says Enter then searches the document text) and no disabled future-feature items; a14-1d only lists the palette shortcut. Toasts are drawn only in isolation (a11-6, light and dark columns without a window, and one toast in the f4 table): there is no placement or stacking inside a window, no right-to-left toast (a12-1ar has none) and none next to the status bar; the a6-1b note mentions an Undo toast that is not drawn. The a11-6b drawer shows running, paused, done and error rows only, with no empty drawer and no cancel confirmation; mobile a13-16c has none either.
- **Decision:** The palette shows recent commands for an empty query, a no-match row that searches the document text on Enter (the a11-2 note), and unshipped commands disabled with the future-version hint. Toasts stack at the bottom end of the window, above the status bar, at most three at a time, and mirror in right-to-left layouts. The task drawer gets an empty state (EmptyState, [G29](#g29)) and a confirmation before a running task is cancelled.
- **Status:** Decided
- **Evidence:** CommandPalette appears only in a11-2 (11b line 34, `default-query="imza"`). No FmWindow board contains a toast. a11-6b sets `on-cancel={{ noop }}`.

<a id="g50"></a>

### G50 · Settings variants and follow-up dialogs missing

- **Type:** missing variant
- **Milestone:** M4
- **Area:** Full settings
- **Artboards:** `a11-1`, `a11-1b`, `a11-1g`, `a11-1h`, `a11-1k`, `a11-1w`, `a12-2c`, `a12-2d`, `a13-15b`, `a10-2`
- **Gap or conflict:** Desktop Settings (a11-1 and a11-1b to a11-1k) exist only in light, on macOS and in English, plus Windows General (a11-1w), Arabic right-to-left Language (a12-2c) and German Windows Language (a12-2d). There is no dark desktop version (only mobile a13-15b is dark), no Turkish version (FmSettings supports en, de and ar) and no Linux version. Not drawn: settings search results and no-match, the network activity log behind "Show network activity…" (a11-1h), and the reset confirmation and import error behind "Reset settings…" and "Import settings…" (a11-1k). AI key entry is partly drawn in a10-2 (a provider picker and a disabled API key field); the entered, checking and failed states, and key entry from Settings › AI assistant (a11-1g), are missing.
- **Decision:** Dark, Turkish and Linux Settings follow the same rules as [G17](#g17), [G19](#g19) and [G15](#g15). Settings search uses EmptyState when nothing matches ([G29](#g29)). The network activity log is a list of the connections Ferman made, kept on the device. Reset and import get a confirmation and a plain error. The AI key states arrive with the assistant in P4.
- **Status:** Decided
- **Evidence:** FmSettings: lang enum `[en, de, ar]`, platform enum `[mac, win]`, no theme prop; lines 73 and 83 hold buttons with no follow-up board.

<a id="g51"></a>

### G51 · Revocation lookups not in the brief's network list

- **Type:** conflict
- **Milestone:** M4
- **Area:** Settings › Privacy / signatures
- **Artboards:** `a11-1h`, `a11-1e`, `a5-5b`, `a5-6`, `a5-6c`, `a5-6d`, `a5-7b`, `a5-7c`, `a13-16`, `a1-2b`
- **Gap or conflict:** a11-1h lists "Signature checks" (asking the certificate provider whether a certificate was revoked, when you sign or open a signed file), on by default. a11-1e has "Check revocation online when opening signed files", on. a5-5b adds revocation data for long-term validation by default, a5-6 defaults to "PAdES-B-LT (recommended)" (a5-6d shows it), a5-6c has the step "Checking the certificate status" with "Good · OCSP", a5-7b shows "Checked when signed (OCSP)", a5-7c shows "Revocation: Not checked · offline" with "Check again", and a13-16 says certificate checks need a connection. OCSP and CRL lookups are not among the brief's four network uses. The design is consistent with itself, since the lookup has its own Privacy row and switch. a1-2b names only the update check ([G24](#g24)).
- **Decision:** Revocation lookups are allowed ([Q06](QUESTIONS.md#q06), 2026-10-16) and built in phase 3. They are off until first use, have their own switch in Settings › Privacy, go through the single network gateway and appear in the network activity log ([ADR 0015](adr/0015-privacy-and-network.md)). Until phase 3, the drawn "Signature checks" row and the a11-1e switch stay visible but disabled. While the lookups are off, validation uses only revocation data embedded in the document and says plainly when revocation was not checked, and signing defaults to PAdES-B-T (with a timestamp, an allowed use). Once the user turns them on, signing defaults to PAdES-B-LT, as a5-6 draws it.
- **Status:** Decided. The owner answered [Q06](QUESTIONS.md#q06) on 2026-10-16: revocation lookups are allowed, off until first use (option (a)). Was Needs owner.
- **Evidence:** FmSettings `nets` ("Signature checks", `on: true`) and line 60 (the a11-1e switch, checked); 05b Sign line 46 (the a5-5b checkbox) and line 80 (the a5-6 format); FmSigCard in a5-7c.

<a id="g52"></a>

### G52 · Language packs and local network unclear in Privacy

- **Type:** ambiguity
- **Milestone:** M4
- **Area:** Settings › Privacy
- **Artboards:** `a11-1h`, `a11-1b`, `a1-1`, `a11-5`, `a7-4`, `a13-15`
- **Gap or conflict:** a11-1h "Downloads you start" covers only "OCR language packs and the assistant's model". No screen says whether the UI translations for the 21 languages are bundled or downloaded; the a1-1 and a11-1b notes ("switches live") suggest they are bundled, and a11-5 credits volunteers in 21 languages. The local-network uses in a7-4 (Wi-Fi scanner discovery, phone pairing by QR code) are not listed in a11-1h or in the mobile privacy row (a13-15).
- **Decision:** UI translations are bundled with the app and never downloaded ([ADR 0015](adr/0015-privacy-and-network.md)). "Downloads you start" stays as drawn. Local-network scanner discovery and phone pairing are not built ([G56](#g56), [Q06](QUESTIONS.md#q06)), so they get no row in Settings › Privacy; revocation lookups get their own row, off until first use ([G51](#g51)).
- **Status:** Decided. The owner answered [Q06](QUESTIONS.md#q06) on 2026-10-16: revocation lookups get their own row, off until first use ([G51](#g51)); there is no local-network discovery and no phone pairing, only the scanners the operating system provides ([G56](#g56)). Was Needs owner.
- **Evidence:** FmSettings `nets` ("Downloads you start"); a7-4's scanner list ("Canon imageFORMULA · Wi-Fi") and QR caption.

<a id="g53"></a>

### G53 · Update states missing

- **Type:** missing state
- **Milestone:** M5
- **Area:** Updates
- **Artboards:** `a11-1i`, `a11-1h`, `a11-4`, `a11-4b`, `a13-16`
- **Gap or conflict:** Drawn: "Up to date" (a11-1i: "Ferman 1.4.2 is up to date · Checked today at 09:12", Check now, a daily-check switch, automatic download off, a Stable or Beta channel), "Update ready" (the a11-4 banner) and What's new after an update (a11-4b). Missing: checking, update available (automatic download is off by default in a11-1i), downloading, failed or offline (only mobile a13-16 mentions offline), the check turned off (possible in both a11-1h and a11-1i), and updates managed by a package manager (Homebrew, winget, Linux packages).
- **Decision:** Build all of these states in a11-1i and the a11-4 banner from design-system components. When a package manager installed Ferman, automatic updating is off and the pane says which manager handles updates ("Managed by Homebrew", "Managed by winget"). The endpoint and payload were settled on 2026-10-16 ([Q15](QUESTIONS.md#q15), [ADR 0015](adr/0015-privacy-and-network.md)): one signed manifest per channel, served from GitHub (Releases or Pages).
- **Status:** Decided. The owner answered [Q15](QUESTIONS.md#q15) on 2026-10-16: the release files for macOS, Windows and Linux are published on GitHub Releases, and the update check reads one signed manifest per channel served from GitHub (Releases or Pages), sending no identifiers. Was Needs owner.
- **Evidence:** A search for "checking for update", "update available", "downloading update", "managed by", Homebrew, winget and Linux finds nothing.

<a id="g54"></a>

### G54 · Overflow labels drift in translate and mobile

- **Type:** conflict
- **Milestone:** P4
- **Area:** Overflow choices outside desktop edit
- **Artboards:** `a3-4`, `a3-13b`, `a13-5c`
- **Gap or conflict:** The desktop canon is FmEditPanel in a3-4: "Extend block by 1 line", "Tighten spacing slightly (−0.6%)" and "Keep and warn", repeated in flow A. a3-13b (translation) offers "Let blocks grow into free space", "Shrink these 2 blocks (10 → 9.5 pt)" and "Review one by one", although its own note says they are "resolved with the same three choices as manual edits (3.4)": "Shrink" reduces the font size instead of the spacing, and "Keep and warn" is missing. a13-5c (mobile) keeps the three actions as "Extend", "Tighten" and "Keep", and "Keep" drops the warning.
- **Decision:** Every surface uses the desktop canon from a3-4: "Extend block by N line(s)", "Tighten spacing slightly (−x%)" and "Keep and warn", with the amounts filled in for each case. Translation may apply them to several blocks at once but never shrinks the font size. Mobile may shorten a visible label only if its accessible name and its result keep the warning.
- **Status:** Decided
- **Evidence:** FmEditPanel.dc.html line 25 (the a3-4 labels); 03c lines 135–137 (a3-13b); 13a line 172 (a13-5c); 15 Flows, flow A ("Extend the block, tighten spacing slightly, or keep it and get a warning").

<a id="g55"></a>

### G55 · Mobile and web boards drift from the rules

- **Type:** conflict
- **Milestone:** P5
- **Area:** Mobile / web shell
- **Artboards:** `a13-8c`, `a5-2`, `a14-2`, `a13-1b`, `a1-1`
- **Gap or conflict:** (1) The a13-8c note says "Date fields open the Material date picker in the field's format", but no picker is drawn; the board shows only the custom İl sheet, and the desktop a5-2 note describes Ferman's own picker (DD.MM.YYYY, Monday first). The mobile intro adopts "Material conventions" for Pixel, but nothing exempts dialogs. (2) The a14-2 note says web mode tabs use the underline style, but the board uses FmWindow `platform="tab"`, which renders the default boxed ModeTabs. The design system readme says Ferman Web uses `ModeTabs variant="underline"`, so underline on the web is the design system's rule; the note and the drawing disagree. (3) a13-1b lists 12 languages, and they are not the first 12 of the 21 in a1-1: Italiano, Nederlands, Polski and Українська are skipped.
- **Decision:** (1) A custom Ferman date-picker sheet on mobile with the a5-2 behaviour, never the Material date picker (brief §6). (2) The web uses the design system's underline variant of the custom ModeTabs control, as the readme and the a14-2 note say, because the drawing does not apply the variant; it remains a custom segmented control over an `IndexedStack`, never `TabBarView`. To be confirmed with the re-export ([Q11](QUESTIONS.md#q11)). (3) Mobile lists all 21 languages (brief §1).
- **Status:** Decided
- **Evidence:** 13b Mobile tasks line 42; 14 Tablet and web lines 78–82; design system readme line 22; 13a Mobile core line 222.

<a id="g56"></a>

### G56 · Local-network scanning and phone pairing

- **Type:** conflict
- **Milestone:** P3
- **Area:** Scan to PDF
- **Artboards:** `a7-4`, `a11-1h`, `a13-8f`, `a13-15`
- **Gap or conflict:** a7-4 has two local-network features: a Wi-Fi scanner picker ("Canon imageFORMULA · Wi-Fi", with "Search again", which implies discovery) and phone-as-camera pairing by QR code over the same Wi-Fi ("Photos go straight to this Mac, not through a server"). The a11-1h Privacy pane lists exactly five uses and says "These are the only times Ferman connects to the internet". "Internet" could be read to exclude the local network, but the a11-1h note promises every network use listed with its own switch. No board draws a local-network permission prompt or the phone side of pairing, and the mobile privacy row (a13-15) says only "No data collected". a13-8f's "Send to my computer…" is a second, unexplained device-to-device path, also missing from Privacy. None of these is in the brief's list.
- **Decision:** Not built ([Q06](QUESTIONS.md#q06), 2026-10-16). Scan to PDF (P3) offers only the scanners the operating system provides through its own scanner interfaces, and the phone panel stays visible but disabled. Pairing is reconsidered with the mobile apps in phase 5; if allowed then, local-network discovery and pairing are off until first use, have their own row and switch in Settings › Privacy, and appear in the network activity log ([ADR 0015](adr/0015-privacy-and-network.md)). The same applies to "Send to my computer…" in the mobile phase.
- **Status:** Decided. The owner answered [Q06](QUESTIONS.md#q06) on 2026-10-16: Scan to PDF offers only the scanners the operating system provides; the phone panel stays disabled, and pairing and "Send to my computer…" are reconsidered with the mobile apps in phase 5. Was Needs owner.
- **Evidence:** 07 Convert lines 73–94 and 179; FmSettings.dc.html line 71 and line 134 (five `nets` entries). A search for "local network", "Bonjour", "eSCL", "TWAIN" and "WIA" finds nothing.

<a id="g57"></a>

### G57 · Image crop says hidden content is removed

- **Type:** conflict
- **Milestone:** P2
- **Area:** Edit images (crop)
- **Artboards:** `a3-5b`, `a8-2b`, `a8-2c`, `a8-3`, `a6-4`, `a11-1c`
- **Gap or conflict:** The a3-5b note says "Cropping is non-destructive until you save; the hidden part is removed then, so it can't be recovered from the PDF." The design's own model contradicts this. a8-3 says "Content from before the last 2 saves is still inside the file", and a8-2c says redaction rewrote the file without its 2 earlier saves; so ordinary saves are incremental, and the original image stream survives unless the crop forces a full rewrite, which no board says. Settings › Editing (a11-1c) also keeps versions next to the file for 30 days by default. Page crop in a6-4 uses the opposite model ("Cropping hides what's outside; the hidden content is removed only if you choose so when saving"), so image crop and page crop disagree.
- **Decision:** Image crop and page crop share one model: cropping hides content and does not remove it. The copy says so ("hidden, not removed") and points to "Remove hidden information" (a8-2b, a8-3), which rewrites the whole file ([ADR 0008](adr/0008-file-safety-and-saving.md)). An explicit choice to remove cropped content when saving may trigger that full rewrite, and says so.
- **Status:** Decided
- **Evidence:** 03b Edit content line 70 (a3-5b); 08 Protect lines 69, 73, 152 and 163; 06 Organize line 91 (a6-4); the FmSettings `keepVer` default.

<a id="g58"></a>

### G58 · Flow B drawn on the rental contract

- **Type:** ambiguity
- **Milestone:** P3
- **Area:** Flows
- **Artboards:** `a5-6`, `a5-6b`, `a5-6c`, `a5-5c`
- **Gap or conflict:** Flow B (`fb`) is billed as "e-Devlet form with e-imza", but its e-imza steps (a5-6, a5-6b, a5-6c, a5-5c) are drawn on Kira sözleşmesi, not on the e-Devlet form (DocForm).
- **Decision:** Read the steps as illustrating the e-imza UI, whatever the document. Flow B acceptance tests run on the e-Devlet form fixture `form-aks1-tr` ([ADR 0017](adr/0017-testing-and-ci.md)).
- **Status:** Decided
- **Evidence:** Found during the M0 discovery and confirmed against 15 Flows.dc.html (flow B steps 3 to 6) and 05b Sign.dc.html.

<a id="g59"></a>

### G59 · e-Devlet form page count differs

- **Type:** ambiguity
- **Milestone:** M2
- **Area:** Start / sample documents
- **Artboards:** none; `FmStart` and `DocForm`; resolved in `FmStart` and the `a1-4-m2` note (export 519d42a)
- **Gap or conflict:** FmStart lists "Adres değişikliği formu.pdf" as 2 pages, but the DocForm fixture footer reads "1 / 1".
- **Decision:** The corpus fixture is a one-page form (`form-aks1-tr`), and recent-file metadata in the app always comes from the real file.
- **Status:** Resolved on 2026-10-17 by export 519d42a: FmStart lists the e-Devlet form with 1 page on every Start board, and the a1-4-m2 note says "The e-Devlet form lists 1 page, as the file has." Was Decided.
- **Evidence:** Found during the M0 discovery and confirmed against the FmStart recent-file data and the DocForm footer. In 519d42a: `design/FmStart.dc.html` line 68; `design/01 First run and files.dc.html` line 123 (the a1-4-m2 note).

<a id="g60"></a>

### G60 · Icon provenance: seven glyphs not from Lucide 0.460.0

- **Type:** export gap
- **Milestone:** M1
- **Area:** Icons
- **Artboards:** none (`ds-additions/fm-icons.js`, Index.dc.html)
- **Gap or conflict:** Of the 84 icons added in `ds-additions/fm-icons.js`, 77 match Lucide 0.460.0. Seven do not: bell, grid-2x2 and funnel match Lucide 1.56.0; paperclip matches Lucide 0.469.0 and 0.500.0; expand matches Lucide 0.500.0; file-signature matches Lucide 0.263.0 and 0.300.0 (an older drawing). Only ellipse, a plain SVG ellipse, matches no Lucide release, so 228 of the 229 glyphs are Lucide's work. Index.dc.html says "Icon set (+64)"; the file has 84.
- **Decision:** Ship the design's exact path data as SVG assets at 1.5 px, because the design is the visual source of truth, with a generated provenance table that gives each icon's source (the Lucide release its geometry matches: 0.460.0, 1.56.0, 0.500.0 or 0.300.0, or "Ferman design" for ellipse alone) and the Lucide ISC and Feather MIT notices ([ADR 0013](adr/0013-fonts-and-icons.md)). The one glyph that matches no release, ellipse, is marked pending in the provenance table until the re-export settles it.
- **Status:** Decided. The owner answered [Q11](QUESTIONS.md#q11) on 2026-10-16 with (c): the missing files come with the next design-system export, and corrected or new boards come for the riskiest gaps; the owner adds the export to `design/`. Was Needs owner.
- **Evidence:** During the M0 discovery the path data of every added icon was compared with Lucide 0.460.0 and 1.56.0; the M0 review compared the other seven with the lucide-static packages of 0.263.0, 0.300.0, 0.469.0 and 0.500.0, and the result was confirmed against `fm-icons.js`; Index.dc.html still says "+64". Confirmed again in M1 by `tools/icons` against the pinned lucide-static npm tarballs (`tools/icons/lucide_matches.json`).

<a id="g61"></a>

### G61 · Search ignores accents by default only for Turkish documents

- **Type:** conflict
- **Milestone:** M2
- **Area:** Search
- **Artboards:** `a2-4a`, resolved by its change in export 519d42a; search results: `a2-4b`, `a2-3e`
- **Gap or conflict:** Brief §7 M2 requires search that is "diacritic-insensitive, İ/ı aware". The a2-4a search options draw the checkbox "Ignore accents and dotted/dotless i", checked, with the description "“i” finds İ, ı and î; “c” finds ç; “kira” finds KİRA. On by default for Turkish documents." That implies the option is off by default for other documents, so a German or English document would open with search that is sensitive to accents, and "muller" would not find "Müller".
- **Decision:** The option is on by default for every document, whatever its language. The checkbox stays as drawn, so people can turn it off. The last sentence of its description becomes "On by default." M2 acceptance tests the default settings: "muller" finds "Müller" in `mietvertrag-de`, and "istanbul" finds "İSTANBUL" in `kira-tr`.
- **Status:** Resolved on 2026-10-17 by export 519d42a: a2-4a's description ends "On by default.", and its note says ignoring accents is on by default for every document, whatever its language: "muller" finds "Müller" in a German file, "istanbul" finds "İSTANBUL". Was Decided.
- **Evidence:** 02 View.dc.html line 116 (a2-4a): the checkbox with `default-checked` and the description "On by default for Turkish documents."; brief §7, M2. In 519d42a: `design/02 View.dc.html` lines 119 (the checkbox) and 123 (the note).

<a id="g62"></a>

### G62 · The bundle's annotation-tool list is stale

- **Type:** conflict
- **Milestone:** M1
- **Area:** Comment / annotation tools (component library)
- **Artboards:** `a4-1` and every board that shows the Comment tool row through `FmWindow`
- **Gap or conflict:** The bundle's `ANNOTATION_TOOLS` constant, the default `tools` of AnnotationTools, lists 9 tools: Select, Highlight, Underline, Strikethrough, Note, "Text box", Draw, Shapes (with the `square` icon) and Stamp. `FmWindow` passes its own list of 11 to AnnotationTools, and that is what the boards draw: it adds Callout (C) and Measure (M, with a menu), labels the text tool "Text" and draws Shapes with the `shapes` icon.
- **Decision:** The `AnnotationTool` enum follows the drawing (11 tools, in FmWindow's order, labels, icons and keys), as `FermanMode` does for the mode tabs ([G09](#g09)). The stale constant is not copied. Tools that do not work yet are disabled with the future-version tooltip ([G10](#g10)).
- **Status:** Decided
- **Evidence:** `_ds_bundle.js` lines 2218–2270 (`ANNOTATION_TOOLS`, 9 entries); `FmWindow.dc.html` lines 233–237 (`annotTools`, 11 entries) and line 86, which passes them as `tools`; `04 Comment.dc.html` (a4-1). Found while writing the component spec ([COMPONENTS.md](COMPONENTS.md)).

<a id="g63"></a>

### G63 · No message drawn for an internal error

- **Type:** missing state
- **Milestone:** M1
- **Area:** Errors
- **Artboards:** `a1-9b` (the pattern to follow)
- **Gap or conflict:** The engine's `Internal` error kind (a bug, or a panic caught at the API boundary) needs a message in the user's language, with the message key `errorInternal` ([ARCHITECTURE.md §8.2](ARCHITECTURE.md#82-mapping-to-apierror)). No board draws one. a1-9b draws only the damaged-file error with "Copy technical details".
- **Decision:** A generic message in the style of a1-9b, with no error code in the sentence: "Something went wrong inside Ferman. Copy the technical details to report the problem.", with the "Copy technical details" action. The ARB entries (`errorInternal` in `app_en.arb` and `app_tr.arb`, with a translator description) are added with the first error strings; the Turkish text goes through native review like every other string.
- **Status:** Decided
- **Evidence:** `MessageKey::INTERNAL` in `crates/ferman-api/src/facade/error.rs`; no board in `design/` draws a generic internal-error message.

<a id="g64"></a>

### G64 · Arabic, Hebrew and Hindi UI text: which Plex family comes first

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Typography / localization
- **Artboards:** `a12-2a`, `a12-2c`
- **Gap or conflict:** The Arabic boards inherit `.fm-root`'s `--type-body`, which uses `--font-ui`: IBM Plex Sans first, then Plex Sans Arabic, Hebrew and Devanagari, so Latin letters, digits and spaces in Arabic UI text come from Plex Sans. The design system also defines `--font-arabic` (`typography.css:7`) with Plex Sans Arabic first; it appears once, on a mock translated document page in 03c, and no UI board uses it. The M0 version of [ARCHITECTURE.md §11.5](ARCHITECTURE.md#115-fonts-in-the-ui) put Plex Sans Arabic first for ar and fa, Plex Sans Hebrew first for he and Plex Sans Devanagari first for hi. Measured in M1: the three script fonts lack İ, ş and ế but carry I, s, ê and the combining marks U+0307, U+0327 and U+0301, so with one of them first Flutter builds those letters from it as base plus mark. Plex Sans Devanagari misplaces all three marks; Plex Sans Arabic and Hebrew place İ and ş correctly but set the acute of ế beside the circumflex.
- **Decision:** Every UI language but CJK uses the design's `--font-ui` order, IBM Plex Sans first, ar, fa, he and hi included, as the Arabic boards do. Arabic, Persian, Hebrew and Devanagari text renders pixel-identically either way (checked at 11 to 40 px, with digits and punctuation); only the Latin letters, digits and punctuation inside those UIs come from Plex Sans, and a wrapped line that holds only digits or punctuation takes Plex Sans's line metrics, as in the browser. `--font-arabic` is not used for UI text. Implemented in `FermanFontFamilies.uiChain` (`app/lib/design/theme/typography.dart`); ARCHITECTURE §11.5 and [ADR 0013](adr/0013-fonts-and-icons.md) record the chains. Revisit if the step 11 goldens for a12-2a and a12-2c differ visibly from their references.
- **Status:** Decided
- **Evidence:** `--font-ui` and `--font-arabic` in `design/_ds/…/tokens/typography.css` lines 6–7, `--font-ui` in `design/ds-additions/fm-additions.css` line 48; the `dir="rtl"` boards in `design/12 Localization.dc.html`, which never use `--font-arabic`; `--font-arabic` in `design/03c Edit review and translate.dc.html`. M1: the mark placement in `app/test/goldens/script_coverage_golden_test.dart` and its golden `script_coverage.png`.

<a id="g65"></a>

### G65 · CJK text: no synthetic bold, which Flutter cannot switch off

- **Type:** conflict
- **Milestone:** M1
- **Area:** Typography / CJK
- **Artboards:** none (a CSS rule)
- **Gap or conflict:** `fm-additions.css` sets `font-synthesis: none` for `[lang|="ja"]`, `zh` and `ko`. Flutter has no such switch; when a system CJK font lacks the requested weight, the engine may embolden the regular face.
- **Decision:** The CJK roles keep the design's weights and no role is italic. For ja, ko, zh-Hans and zh-Hant the theme names the ADR 0013 system families right after IBM Plex Sans (Hiragino Sans, Yu Gothic UI, Noto Sans CJK JP; Apple SD Gothic Neo, Malgun Gothic, Noto Sans CJK KR; PingFang SC, Microsoft YaHei UI, Noto Sans CJK SC; PingFang TC, Microsoft JhengHei UI, Noto Sans CJK TC), so real bold faces are picked where the system has them. Remaining synthesis is checked by hand with the step 5 CJK samples on R1, R2 and Linux.
- **Status:** Decided
- **Evidence:** `design/ds-additions/fm-additions.css` lines 55–56; `FermanFontFamilies` in `app/lib/design/theme/typography.dart`.

<a id="g66"></a>

### G66 · Title bar states and gestures the boards do not draw

- **Type:** missing state
- **Milestone:** M1
- **Area:** Window chrome
- **Artboards:** every board drawn with `FmWindow`; f6 and f6a (caption buttons)
- **Gap or conflict:** FmWindow draws the title bar of an active, unmaximized window. It draws no maximized (restore) caption button and has no "Restore" string, no inactive window, no macOS full screen, and it does not say what dragging or double-clicking the bar does or where a window without the system title bar resizes from its top edge.
- **Decision:** A maximized window shows the restore glyph (two overlapping squares: the `copy` icon mirrored horizontally, so the front square sits at the bottom left, as Windows draws it; mirrored with the bar in right to left) named "Restore", with the operating system's own word in Turkish ("Geri yükle") and Arabic ("استعادة"), pending the native-speaker review like every string. The caption buttons keep the arrow cursor, as native caption buttons do (FmWindow line 33 sets no cursor). An inactive window keeps the active colours. In macOS full screen, where the system owns the traffic lights, the light slot gives way to the 8 px gap the Windows bar has. The bar's empty space moves the window once a pressed pointer moves (a trackpad scroll never does); a double-click there, counted with the system's double-click interval and distance, does what the system does (macOS: the "Double-click a window's title bar to" setting; Windows and Linux: maximize or restore, [B009](BACKLOG.md#open) for desktop settings on Linux). On Windows the top strip of the window, over the caption buttons too, is the top resize edge while the window is not maximized, as on a native title bar.
- **Status:** Decided. On 2026-10-16 the restore glyph was described exactly (the mirrored `copy` icon) and the arrow cursor was added.
- **Evidence:** `design/FmWindow.dc.html` lines 17–34 (header), line 33 (caption buttons, no `cursor`) and line 184 (`minimize`, `maximize`, `closeWin`; no restore); `design/00 Fixes.dc.html` f6 and f6a. Implemented in M1 phase H1 ([ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration)).

<a id="g67"></a>

### G67 · Idle document tabs with a spinner or a custom icon

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Window chrome / document tabs
- **Artboards:** the DS additions sheet (document tabs and window chrome); `a1-7`, `a1-8`, `a1-8b`, `a1-9`, `a1-9b` (on the active tab only)
- **Gap or conflict:** FmWindow builds every tab with its loading state and icon (line 213). Its active-tab markup draws the 12 px Spinner "Opening" while the tab loads and the tab's icon otherwise (line 23), but its idle-tab markup has no spinner and hard-codes the `file-text` icon (line 24). The DS additions sheet passes idle tabs that are loading ("İmar planı açıklama raporu.pdf") and locked ("Maaş bordrosu Eylül 2026.pdf", `lock`) (line 156), and its caption lists loading (spinner), locked and repaired among the tab states (line 65), yet it renders them as plain idle tabs. The product boards draw loading, locked, repaired and broken tabs only as the active tab (`01 First run and files` lines 255–262).
- **Decision:** The tab data and the caption win: an idle tab shows the 12 px Spinner while it loads and its own icon (`lock`, `wrench`, `file-x`) otherwise, as the active tab does. The unsaved dot and the empty close-button space of idle tabs stay as drawn.
- **Status:** Decided
- **Evidence:** `design/FmWindow.dc.html` lines 23 (active tab: Spinner or `tab.icon`), 24 (idle tab: `name="file-text"`) and 213 (`tabList`, with `loading` and `icon` for every tab); `design/DS additions.dc.html` lines 65 (caption) and 156 (`tabStates`); `design/01 First run and files.dc.html` lines 255–262. Implemented in `app/lib/design/components/additions/document_tab.dart` (M1 phase G).

<a id="g68"></a>

### G68 · Tab heights: the drawn 32 px against `--doctab-h` and a size hint

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Window chrome / document tabs and mode bar
- **Artboards:** every board drawn with `FmWindow`; `f6`, `f6a`
- **Gap or conflict:** The token `--doctab-h` is 28 px, and the Index describes the document tabs as "28–32 px". FmWindow draws the active tab 32 px tall and the idle tab as a 32 px box that holds a 28 px row 4 px above its bottom. The tab list sits in the 38 px title bar above its 1 px bottom border with `padding-top: 6px`, which leaves 31 px for the 32 px tabs, so they overflow the padding by 1 px; the active tab reaches 1 px further down to cover the border (`margin-bottom: -1px`). The mode bar imports ModeTabs with a 30 px size hint, but its CSS makes the track 32 px: a 26 px tab (`--control-h-sm`) plus 2 px of padding and a 1 px border on each side.
- **Decision:** The markup and the CSS win. The active tab and the idle tab's box are 32 px tall, and the idle row is 28 px, which is what `--doctab-h` describes; the idle boxes start 5 px below the top of the title bar, where the 1 px overflow puts them. The ModeTabs track is 32 px: a `hint-size` only sizes the board tool's placeholder.
- **Status:** Decided
- **Evidence:** `design/ds-additions/fm-additions.css` line 19 (`--doctab-h: 28px`); `design/Index.dc.html` line 102; `design/FmWindow.dc.html` lines 17 (title bar and its border), 21 (`padding-top:6px`), 23 (active tab), 24 (idle tab) and 38 (`hint-size="640px,30px"`); `design/_ds/…/tokens/spacing.css` lines 23 (`--control-h-sm`) and 33 (`--titlebar-h`); `design/_ds/…/components/navigation/navigation.css` lines 4–8. Implemented in `app/lib/design/components/additions/document_tab.dart` (`DocumentTab`, `DocumentTabStrip`) and `app/lib/design/components/navigation/mode_tabs.dart` (M1 phase G).

<a id="g69"></a>

### G69 · Annotation colour swatches: focus, the disabled group and orange

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Comment / annotation tools (component library)
- **Artboards:** `a4-1` and every board that shows the Comment tool row through `FmWindow`
- **Gap or conflict:** Three points of the AnnotationTools colour group disagree. (1) `.fm-annot-color:focus-visible` puts the focus ring in place of the swatch's rings, but the checked rule comes later with the same specificity, so a focused checked swatch shows its checked rings and no focus ring. (2) When the active tool is not coloured, the bundle dims the group to 0.4 opacity and marks it `aria-disabled`, yet the swatches stay Tab stops and a click still changes the colour. (3) The annotation palette has orange (`--annot-orange`, the Highlight colours), but the AnnotationTools palette lists only yellow, green, blue, pink, red and ink; with orange as the colour no swatch is checked, and the active tool's swatch falls back to yellow.
- **Decision:** (1) Focus wins: a focused swatch shows the focus ring whether it is checked or not ([G22](#g22)). (2) A group dimmed for an uncoloured tool is disabled in behaviour too: its swatches are skipped by Tab and the arrow keys and ignore clicks; with a reason ([G10](#g10)) they stay focusable and show it. (3) The tool's swatch shows the real colour, orange included; no swatch is checked, and the first swatch is the group's Tab stop.
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/annotations/annotations.css` lines 39–44; `design/_ds/…/_ds_bundle.js` line 19 (`orange` in the Highlight `COLORS`), lines 2271–2295 (`PALETTE`, no orange), 2320 (the swatch's fallback `|| PALETTE[0]`), 2338–2341 (`aria-disabled` and the opacity on the group) and 2352 (each swatch's `onClick`); `design/_ds/…/tokens/colors.css` line 77 (`--annot-orange`). Implemented in `app/lib/design/components/annotations/annotation_tools.dart` (M1 phase G).

<a id="g70"></a>

### G70 · Window controls: the macOS light slot and the pressed caption button

- **Type:** missing state
- **Milestone:** M1
- **Area:** Window chrome
- **Artboards:** every board drawn with `FmWindow`; `f6`, `f6a`
- **Gap or conflict:** FmWindow draws the window controls as markup. On macOS it paints three placeholder traffic lights (decorative, 12 px, 8 px apart, with `padding-inline: 14px 12px`), which the app cannot use: the real lights belong to the system. On Windows it draws the 46 px caption buttons with a hover tint and the red close hover, but no pressed state. Linux is not drawn ([G15](#g15)).
- **Decision:** On macOS the title bar keeps a 78 × 38 px slot at its start (the drawn padding, three lights and two gaps, by the height of the title bar), empty in the app: the window integration places the native lights in it. Goldens and the component gallery paint the design's placeholder lights there. On Windows a pressed minimize or maximize button shows `--surface-pressed`, and a pressed close button keeps the red of its hover with the white glyph. Linux uses the Windows caption buttons until GNOME and KDE boards exist ([G15](#g15), [B015](BACKLOG.md#open)). The restore glyph, the cursor and the other title-bar states are [G66](#g66).
- **Status:** Decided
- **Evidence:** `design/FmWindow.dc.html` lines 18 (the placeholder lights, `aria-hidden`), 19 (the 8 px start gap on Windows) and 33 (the caption buttons: `style-hover` only); `design/ds-additions/fm-additions.css` lines 23–24 (`--win-caption-w`, `--win-close-hover`); `design/_ds/…/tokens/spacing.css` line 33 (`--titlebar-h: 38px`). Implemented in `app/lib/design/components/additions/window_chrome.dart` (M1 phase G) and the window integration ([ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration)).

<a id="g71"></a>

### G71 · Disabled-with-reason controls: the design hides or dims their focus ring

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Component library: focus
- **Artboards:** none draws a focused disabled control; the DS additions "Interactive states" sheet draws the disabled states
- **Gap or conflict:** [G10](#g10) keeps a control that is disabled with a reason focusable, so its reason can be read, and [G22](#g22) gives every focusable control the focus ring. The CSS assumes a disabled control never has focus: `.fm-btn:disabled` and `.fm-iconbtn:disabled` set `box-shadow: none`, which would remove the ring that `:focus-visible` adds, and the bundle's 0.4 opacity on a disabled AnnotationTools colour group would dim a focused swatch's ring with it.
- **Decision:** A focused disabled-with-reason control shows the full focus ring over its disabled look: buttons and icon buttons keep the ring despite `box-shadow: none`, and a disabled colour group is dimmed swatch by swatch under the ring ([COMPONENTS.md](COMPONENTS.md) decision 26). Plain disabled controls cannot take focus, so the CSS rule still holds for them.
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/core/core.css` lines 11 and 50 (`:focus-visible`), 32 and 57 (`:disabled`, `box-shadow: none`); `design/_ds/…/_ds_bundle.js` lines 2339–2341 (the colour group's opacity). Implemented in `app/lib/design/components/core/button.dart`, `core/icon_button.dart` and `annotations/annotation_tools.dart` (M1 phase G).

<a id="g72"></a>

### G72 · Pressed secondary and primary icon buttons: core.css and the state sheet disagree

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Component library: IconButton
- **Artboards:** none draws a pressed icon button; the DS additions "Interactive states" sheet draws its other states
- **Gap or conflict:** In `core.css`, `.fm-iconbtn:active` sets `--surface-pressed`, but `.fm-iconbtn--secondary:hover` and `.fm-iconbtn--primary:hover` come later with the same specificity, and a pressed button is also hovered, so a pressed secondary or primary icon button shows its hover fill. The forced-state harness of the state sheet gives every icon button `--surface-pressed` when it forces the active state.
- **Decision:** The `core.css` cascade wins, since it is what the components run: a pressed ghost icon button shows `--surface-pressed`, a pressed secondary one the hover tint over the raised surface, and a pressed primary one `--accent-hover`. The harness is documentation only, and the state sheet draws no pressed icon button.
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/core/core.css` lines 49 (`:active`), 52 and 54 (`--secondary:hover`, `--primary:hover`); `design/ds-additions/fm-additions.css` lines 89 (the harness, "for state sheets only") and 96 (`[data-fm-force="active"] … .fm-iconbtn`); `design/DS additions.dc.html` lines 98–103 (the icon-button row of the state sheet). Implemented in `app/lib/design/components/core/icon_button.dart` (M1 phase G).

<a id="g73"></a>

### G73 · Drop zone: the dashed border and the Open shortcut

- **Type:** ambiguity
- **Milestone:** M1
- **Area:** Start / empty state (DropZone)
- **Artboards:** `a1-5`
- **Gap or conflict:** The drop zone's border is `1.5px dashed`; CSS leaves the dash pattern to the browser, and Flutter has no dashed border. The Open button shows its shortcut after the label as `shortcut.join('')`, which suits the macOS symbols ("⌘O") but runs word caps together: FmStart passes `Ctrl`, `O` on Windows, which the bundle writes "CtrlO", while the f6a note writes Windows shortcuts with a plus ("Ctrl+K, Ctrl+Z, Ctrl+Y, Ctrl+H").
- **Decision:** The border is painted with 3 px dashes and 2 px gaps, as Chromium draws the 1.5 px dashed border in the `a1-5` render; the over state stays solid. The shortcut joins symbol caps without a separator ("⌘O") and puts a plus between word caps ("Ctrl+O").
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/empty/empty.css` lines 5 (`border: 1.5px dashed`) and 8 (`--over`, solid); `design/_ds/…/_ds_bundle.js` line 791 (`shortcut.join('')`); `design/FmStart.dc.html` lines 38 (`shortcut="{{ openKeys }}"`) and 106 (`openKeys`); `design/00 Fixes.dc.html` line 131 (f6a). Implemented in `app/lib/design/components/empty/drop_zone.dart` (M1 phase G).

<a id="g74"></a>

### G74 · Progress percentages: the bundle writes "N%" in every region

- **Type:** conflict
- **Milestone:** M1
- **Area:** Locale formatting / progress
- **Artboards:** `a9-5b` (batch progress, "43%"), and every progress bar that shows its value
- **Gap or conflict:** ProgressBar writes its percentage as the number followed by "%", whatever the region. [G34](#g34) makes numbers follow the region setting: Turkish CLDR writes the sign first ("%43"), and the Saudi Arabia region writes Arabic-Indic digits.
- **Decision:** The screen formats the percentage for the region and passes it to ProgressBar as `valueText`; without it the bar shows "N%". The semantics value stays the number from 0 to 100. `RegionFormat.percent` writes the region's form; it arrived in M1 with the first screens that show a percentage: the shell's status bar and zoom menu, and the "100%" zoom option in Settings › General ([G34](#g34)).
- **Status:** Decided. On 2026-10-16 the helper arrived in M1, not with the zoom field in M2.
- **Evidence:** `design/_ds/…/_ds_bundle.js` lines 874 (`pct`) and 882 (`pct, "%"`); `design/09b Tools.dc.html` line 50 (`a9-5b`, `show-value`). Implemented in `app/lib/design/components/feedback/progress_bar.dart` (M1 phase G). `RegionFormat.percent` is in `app/lib/l10n/format.dart` lines 106–124, used by `app/lib/features/shell/shell_status_bar.dart` line 140, `app/lib/features/shell/shell_tool_rows.dart` lines 149 and 234 and `app/lib/features/settings/general_pane.dart` line 164; checked in `app/test/l10n/format_test.dart` line 303.

<a id="g75"></a>

### G75 · Disabled form controls: the cascade lets hover win

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Component library: Field, TextField, NumberStepper, Select, Checkbox, Radio
- **Artboards:** none hovers a disabled control; the DS additions "Interactive states" sheet draws disabled controls at rest
- **Gap or conflict:** `.fm-input:hover` (specificity 0,2,0) beats `.fm-input--disabled` (0,1,0), so a disabled field under the pointer takes the strong border. `.fm-check:hover .fm-check__input` (0,3,0, and its dark variant at 0,4,0) beats `.fm-check__input:disabled` and `:disabled:checked`, so a disabled checkbox or radio under the pointer takes the hover border.
- **Decision:** Disabled controls show no hover: a disabled field keeps the subtle border and a disabled checkbox or radio keeps its disabled look, as native disabled controls do and as their not-allowed cursor says.
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/forms/forms.css` lines 17 (`.fm-input:hover`), 22 (`.fm-input--disabled`), 46–47 (`.fm-check:hover`) and 52–53 (`:disabled`, `:disabled:checked`). Implemented in `app/lib/design/components/forms/field.dart`, `checkbox.dart` and `radio.dart` (M1 phase G).

<a id="g76"></a>

### G76 · Find bar: the rows overflow the end padding in the browser

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Component library: SearchReplaceBar
- **Artboards:** `a2-4a`, `a3-7`
- **Gap or conflict:** `.fm-search` is a 440 px grid with 6 px padding and one implicit `auto` column. Chromium sizes that column to the find row's min-content, and the bare `<input>` keeps its default width (`size=20`), which `min-width: 0` on `.fm-input` does not remove. The rows come out 436 px wide instead of 428 px, so they and the notice run over the 6 px end padding and end about 2 px past the bar's edge. In the renders the find field is 247 px wide and the replace field 257 px.
- **Decision:** Follow the CSS as written: the rows fill the 428 px content box, so the find and replace fields are 8 px narrower than in the renders, and the close button and the notice end 6 px inside the bar. Goldens differ from `build/design-refs/a2-4a.png` and `a3-7.png` by exactly that.
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/editing/editing.css` lines 37–39 (`.fm-search`, its rows, `flex: 1` fields); `design/_ds/…/components/forms/forms.css` lines 9–12 (`.fm-input`, `min-width: 0`); measured in `build/design-refs/a3-7.png` (bar x 720–1160, find field 756–1003, notice 726–1161). Implemented in `app/lib/design/components/editing/search_replace_bar.dart` (M1 phase G).

<a id="g77"></a>

### G77 · Page thumbnail: the drop line's round ends and the reach of the dim filter

- **Type:** ambiguity
- **Milestone:** M1
- **Area:** Component library: PageThumbnail
- **Artboards:** none draws a drop indicator or a dimmed thumbnail; `pages.css` is the only reference
- **Gap or conflict:** (1) The round ends of the drop line are `6px` square with a `2px` border, and their offsets (`top: -4px` on a 2 px line, `-6px` along it) centre them on the line only under content-box sizing; `.fm-root` sets border-box, so the CSS draws a 6 px end 2 px off the line's centre. (2) `filter: var(--page-filter)` on `.fm-thumb__page` dims everything that element paints, including its own `box-shadow`: the hairline, the 2 px accent ring of a selected page and `--shadow-sm`.
- **Decision:** (1) The widget draws the 10 px end the CSS offsets centre on the line, reaching 6 px past the line's ends, with the 2 px accent border and the panel-coloured centre. (2) The filter dims the page, its marker and its badges; the outer ring and shadow stay at full strength, so a selected thumbnail keeps the same accent ring under the dim page setting.
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/pages/pages.css` lines 12 (`filter: var(--page-filter)`), 20 (the selected ring), 29–30 (the drop line and its ends) and 33–38 (their offsets); `design/_ds/…/tokens/base.css` line 12 (`box-sizing: border-box`). Implemented in `app/lib/design/components/pages/page_thumbnail.dart` (M1 phase G).

<a id="g78"></a>

### G78 · Menu check: the CSS asks for the accent, the render draws it grey

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Component library: Menu and the Select list
- **Artboards:** `a2-2` (the zoom menu, "100%" checked) and every menu with a checked item
- **Gap or conflict:** `.fm-menu__check` sets `color: var(--text-accent)` on the span around the check, but `.fm-menu__item svg` (`--icon-secondary`) matches the check's own `<svg>` and wins, as do the danger and disabled `svg` rules; the icon strokes with `currentColor`. The render draws a grey check (about `#7A766E` in `build/design-refs/a2-2.png`, antialiased paper-600), not the accent.
- **Decision:** The render wins: the check takes the row's icon colour (secondary, danger on a danger row, disabled on a disabled row). The Select list, which reuses the Menu look ([COMPONENTS.md](COMPONENTS.md) decision 8), does the same.
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/overlays/overlays.css` lines 34, 37 and 39 (the `svg` colours) and 41 (`.fm-menu__check`); `design/_ds/…/_ds_bundle.js` line 2662 (`fm-menu__check`). Implemented in `app/lib/design/components/overlays/menu.dart` and `forms/select.dart` (M1 phase G).

<a id="g79"></a>

### G79 · Checkbox and radio: three states the cascade draws wrongly

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Component library: Checkbox, Radio
- **Artboards:** none draws these states; the DS additions "Interactive states" sheet draws enabled and disabled checkboxes and radios at rest
- **Gap or conflict:** (1) `.fm-radio .fm-check__input:checked` comes after `.fm-check__input:disabled:checked` with the same specificity (0,3,0), so a disabled checked radio is drawn as an enabled one, in the accent. (2) In dark, `[data-theme="dark"] .fm-check:hover .fm-check__input` (0,4,0) beats the checked radio's accent border, so a checked radio under the pointer takes the soot border; in light the checked rule comes later and keeps the accent. (3) `.fm-check__input:disabled` comes after `.fm-check__input.is-indeterminate` with the same specificity, and `:disabled:checked` does not match an indeterminate box, so a disabled indeterminate box is sunken with its white minus barely visible on it.
- **Decision:** (1) A disabled checked radio takes the checkbox's disabled-checked strong grey. (2) A checked radio keeps its accent border under the pointer in both themes. (3) A disabled indeterminate box takes the disabled-checked look with its minus.
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/forms/forms.css` lines 46–47 (hover), 48 (checked and indeterminate), 51 (the mark), 52–53 (`:disabled`, `:disabled:checked`) and 59 (the checked radio). Implemented in `app/lib/design/components/forms/checkbox.dart` and `radio.dart` (M1 phase G).

<a id="g80"></a>

### G80 · Text fields: no context menu is designed

- **Type:** missing state
- **Milestone:** M1, with the menu in M2
- **Area:** Component library: TextField, NumberStepper and the pickers' search fields; PdfFormField text fields
- **Artboards:** none draws a context menu on a field
- **Gap or conflict:** The design's fields are native `<input>` elements, which bring the browser's context menu (Cut, Copy, Paste, Select all). Flutter's text input shows none unless the app builds one, and the Material and Cupertino toolbars are not used ([ADR 0011](adr/0011-flutter-state-navigation-components.md)).
- **Decision:** In M1 a right click on a field opens nothing; cut, copy, paste and select all work from the keyboard. A context menu built from the design-system Menu, with the platform's items, order and shortcuts, comes in M2 with the first screens that edit text in fields ([B017](BACKLOG.md#open)).
- **Status:** Decided
- **Evidence:** `design/_ds/…/components/forms/forms.css` lines 24–27 (`.fm-input__control`, a native input). Implemented in `app/lib/design/components/forms/field_input.dart` (M1 phase G).

<a id="g81"></a>

### G81 · Shortcut table: the document jump and the Delete key

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Keyboard shortcuts
- **Artboards:** `a1-10`, `a2-2`, `a6-1`, `a11-3`, `a14-1d`
- **Gap or conflict:** Two keys clash in the design. (1) The a1-10 note says "⌘1…⌘9 jump" to the open documents, and its overflow menu shows ⌘7, ⌘8 and ⌘9. But a2-2's zoom menu binds Actual size to ⌘1 and Fit width to ⌘2. (2) FmWindow writes the Organize Delete tool's key as `del: ['⌫']`, outside its `K()` helper, so a Windows board would show ⌫ too. The a11-3 cheat sheet lists "Delete pages" with ⌫. The a14-1d hardware-keyboard list, which uses the Ctrl conventions, writes "Delete" with Del.
- **Decision:** (1) Zoom keeps ⌘1 and ⌘2 (Ctrl+1 and Ctrl+2 on Windows and Linux). The document jump takes ⌥⌘1 to ⌥⌘9 on macOS and Alt+1 to Alt+9 on Windows and Linux. In M1 it moves between the shell's placeholder documents. The a1-10 overflow menu shows the same keys when it is built in M2 ([G16](#g16)). (2) Delete pages shows ⌫ on macOS and Del on Windows and Linux. Each system also accepts the other key: forward delete on macOS, Backspace on Windows and Linux. The keys are bound in Organize only, while the page grid has focus. The re-export is asked to correct the a1-10 note and menu, and to put `k.del` in `K()`.
- **Status:** Decided
- **Evidence:** `design/01 First run and files.dc.html` lines 178 (the a1-10 note) and 266–268 (the menu's ⌘7 to ⌘9); `design/02 View.dc.html` line 227 (a2-2 `zoomMenu`: Fit width ⌘2, Fit page ⌘0, Actual size ⌘1); `design/FmWindow.dc.html` lines 200 (`K`) and 205 (`del: ['⌫']`); `design/11b App.dc.html` line 145 (a11-3, "Delete pages" ⌫); `design/14 Tablet and web.dc.html` line 133 (a14-1d, "Delete" Del). Implemented in `app/lib/features/shell/shortcuts.dart` (`document1` to `document9` lines 246–298, `actualSize` and `fitWidth` lines 370–380, `deletePages` lines 614–621) and `app/lib/features/shell/shell_commands.dart` lines 49–68 (M1 phase H5); checked in `app/test/features/shell/shortcuts_test.dart` lines 138–139, 165–177 and 438, and `app/test/features/shell/shell_screen_test.dart` line 549.

<a id="g82"></a>

### G82 · Shortcut table: the edit box's keys and dialog keys stay out of it

- **Type:** conflict (internal to design)
- **Milestone:** M3
- **Area:** Keyboard shortcuts
- **Artboards:** `a2-3a`, `a3-1c`, `a1-10b`, `a2-7`, and every board that shows the Outline tab
- **Gap or conflict:** ⌘B has two meanings. FmSidebar puts ⌘B (Ctrl+B) on Add bookmark, and the a2-3a note says "⌘B adds a bookmark at the current view". The edit box uses ⌘B for Bold, with ⌘I and ⌘U (FmEditPanel, a3-1c). a3-1c also puts ⌘K on Add link, which is the command palette's key in FmWindow. Dialogs bring keys of their own: in a1-10b ⌘D is "Don't save", while ⌘D is Duplicate in Organize. The a2-7 note opens with "⌘D.", the way other notes open with their command's key (a1-11 "⇧⌘S.", a2-4a "⌘F.", a2-5a "⌘L."), so Document properties takes ⌘D as well: a third meaning beside Duplicate in Organize and "Don't save" in a1-10b.
- **Decision:** The shell's one table holds the commands of the window and its modes. In M1 it keeps ⌘B for Add bookmark and ⌘K for the command palette in every mode, as FmSidebar and FmWindow draw them. The edit box's formatting keys (⌘B, ⌘I, ⌘U, and ⌘K for Add link) and dialog accelerators such as a1-10b's ⌘D are not in the table. They belong to those components, and their clash with the table is settled when the edit box is built in M3 (Add link in P2). The table has no Document properties command yet; a2-7's ⌘D, which clashes with Duplicate in Organize, is settled when that dialog is built in M2.
- **Status:** Decided
- **Evidence:** `design/FmSidebar.dc.html` lines 20 (Add bookmark with `kBookmark`) and 171 (`kBookmark`: ⌘B, Ctrl+B); `design/02 View.dc.html` lines 90 (the a2-3a note), 120 and 140 (the a2-4a and a2-5a notes, "⌘F." and "⌘L.") and 180 (the a2-7 note, "⌘D."); `design/FmEditPanel.dc.html` line 71 (⌘B, ⌘I, ⌘U); `design/03a Edit text.dc.html` lines 50 (a3-1c, Add link with `kK`) and 159 (`kB`, `kI`, `kU`, `kK`); `design/FmWindow.dc.html` lines 30 (Search with `k.palette`) and 202 (`palette`: ⌘K); `design/01 First run and files.dc.html` lines 188 (the a1-10b note) and 211 (the a1-11 note, "⇧⌘S."); `design/11b App.dc.html` line 145 (Duplicate ⌘D). Implemented in `app/lib/features/shell/shortcuts.dart` lines 175–178 (the rule), 180–184 (`commandPalette`), 394–398 (`addBookmark`, every mode) and 593–598 (`duplicatePages`, Organize only) (M1 phase H5).

<a id="g83"></a>

### G83 · Window keys the boards do not draw

- **Type:** missing state
- **Milestone:** M1
- **Area:** Window chrome / keyboard shortcuts
- **Artboards:** none draws them; `a11-3` lists the Window group without them
- **Gap or conflict:** No board shows a key to minimize the window, close it or quit Ferman. The a11-3 cheat sheet's Window group lists only Next document, Sidebar, Panel and Close document, and FmWindow's key table has no window commands.
- **Decision:** The window commands use each system's own keys and live in the one shortcut table: ⌘M (minimize) and ⌘Q (quit) on macOS, Alt+F4 (close the window) on Windows and Linux, and Ctrl+Q (quit) on Linux. Windows has no quit or minimize key in the table, and macOS has no close-window key, since ⌘W closes the document. The window frame binds these keys on every screen: first run, the start screen, Settings and the editor. Nothing is bound where the system draws the window. Close and quit both close the window, as the caption buttons do; on macOS the app ends with its last window. On macOS ⌘Q closes the window through this binding; the native main menu, which also lists Quit ⌘Q and Minimize ⌘M, is not relied on. Asking about unsaved documents before closing follows [G40](#g40). Settings, an in-window surface in M1, also closes with the table's Close document keys (⌘W, Ctrl+W; [G89](#g89)).
- **Status:** Decided
- **Evidence:** A search of `design/` for ⌘Q, ⌘M, Alt+F4 and Ctrl+Q finds nothing. `design/11b App.dc.html` line 147 (a11-3, the Window group); `design/FmWindow.dc.html` lines 201–206 (`k`). Implemented in `app/lib/features/shell/shortcuts.dart` lines 662–673 (the commands) and 720–727 (`windowCommands`), `app/lib/features/shell/shell_commands.dart` lines 102–173 (`WindowCommandScope`), `app/lib/app/window_frame.dart` lines 18–20 and 37–40 and `app/lib/features/settings/settings_screen.dart` lines 245–250 (M1 phase H5); the macOS runner ends the app with its last window (`app/macos/Runner/AppDelegate.swift` lines 6–8, from the Flutter template), and its native main menu lists Quit ⌘Q and Minimize ⌘M (`app/macos/Runner/Base.lproj/MainMenu.xib` lines 61 and 305, from the template too); checked in `app/test/app/window_frame_test.dart` lines 451, 470 and 505, and `app/test/features/shell/shell_route_test.dart` line 131.

<a id="g84"></a>

### G84 · The tool row is 45 px: FmWindow adds a second line

- **Type:** conflict (internal to design)
- **Milestone:** M1
- **Area:** Window chrome / tool row
- **Artboards:** every board drawn with `FmWindow` in a mode; measured in `a2-1b`, `a2-2`, `a3-1d`, `a4-1`, `a6-1`
- **Gap or conflict:** The Toolbar is `--toolbar-h` (44 px) tall with its own 1 px bottom line, under border-box. FmWindow wraps the tool rows in a box with a second 1 px bottom line. So the boards draw a 45 px tool row with a 2 px line, against `--toolbar-h` and the ROADMAP's "tool row 44 px". In the renders of a2-1b, a2-2, a3-1d and a6-1, rows 121 and 122 are both line, and the sidebar, canvas and panel start at y = 123. In Comment mode the AnnotationTools row and the Show comments switch share the box, so in a4-1 the upper line stops where the switch begins (x = 1289) and the lower line runs to the window's edge.
- **Decision:** The markup wins. The tool row is the 44 px Toolbar plus the box's 1 px line, 45 px in all, in every mode, with a4-1's shorter upper line in Comment mode. At 1440 × 900 the sidebar, canvas and panel start at y = 123 and are 751 px tall. [ROADMAP.md §5](ROADMAP.md#5-m1-foundations) step 8 asks for a 44 px tool row and for every difference to be recorded here: the Toolbar is that 44 px, and the box's line is the difference this entry records.
- **Status:** Decided
- **Evidence:** `design/FmWindow.dc.html` lines 46 (the box, `border-bottom:1px solid var(--border-subtle)`), 48 (the View Toolbar, `hint-size="100%,44px"`) and 86 (the Comment row: AnnotationTools in a `flex:1` box, the switch outside it); `design/_ds/…/components/navigation/navigation.css` line 43 (`.fm-toolbar--bar`: `height: var(--toolbar-h)`, `border-bottom`); `design/_ds/…/tokens/spacing.css` line 35 (`--toolbar-h: 44px`); `design/_ds/…/tokens/base.css` line 12 (border-box); `design/_ds/…/_ds_bundle.js` line 2304 (AnnotationTools, `variant = 'bar'`); measured in `build/design-refs/a2-1b.png`, `a2-2.png`, `a3-1d.png`, `a4-1.png` and `a6-1.png`; the sizes criterion of ROADMAP.md §5 step 8. Implemented in `app/lib/features/shell/shell_tool_rows.dart` lines 17–19 and 46–56, and lines 498–541 for Comment (M1 phase H3); checked in `app/test/features/shell/shell_screen_test.dart` lines 49 and 62–70.

<a id="g85"></a>

### G85 · Save and the tab's close button before saving and closing exist

- **Type:** missing state
- **Milestone:** M1
- **Area:** Mode bar / document tabs
- **Artboards:** every board drawn with `FmWindow`; `f4`, `f4b`
- **Gap or conflict:** FmWindow draws Save enabled while the document has unsaved changes, and disabled with "No changes to save" in every other state (`saveDisabled`, line 227; the f4b note says the same for a saved document, while f4's table keeps Save enabled for "Couldn't save", [G41](#g41)). It draws the active clean tab with an enabled close button, "Close document" with ⌘W. Saving comes in M3 and closing documents in M2, so in M1 both would offer something that does nothing. No board draws either control disabled for that reason.
- **Decision:** Both stay where they are drawn. Save is disabled with "No changes to save" when the active document has no unsaved changes, as FmWindow and the f4b note draw it. While it has unsaved changes, Save is disabled with the future-version tooltip ([G10](#g10)) until saving exists in M3 ([B031](BACKLOG.md#open)). In M1 every state but unsaved counts as clean, as FmWindow's `saveDisabled` does; the error state follows [G41](#g41) once saving exists. The tab's dot, Save and the status bar follow the same document, so they always agree. The active clean tab's close button is drawn, disabled with the future-version tooltip, until closing documents exists in M2 ([B029](BACKLOG.md#open)). An unsaved tab shows its dot instead, as drawn.
- **Status:** Decided
- **Evidence:** `design/FmWindow.dc.html` lines 23 (the active tab's close button, `shortcut="{{ k.close }}"`), 42 (Save, `disabled="{{ saveDisabled }}"`, `title="{{ saveTip }}"`), 184 (`saveTipOff: 'No changes to save'`) and 227 (`saveDisabled`, `saveTip`); `design/00 Fixes.dc.html` lines 85 (the f4b note, inside the f4 section) and 88–91 (f4's table of save states). Implemented in `app/lib/features/shell/shell_mode_bar.dart` lines 16–19 and 106–114, `app/lib/features/shell/shell_title_bar.dart` lines 25–28 and 184–205, and `DocumentTab.closeDisabledReason` in `app/lib/design/components/additions/document_tab.dart` lines 35–41, 101–105 and 282–298 (M1 phase H2); checked in `app/test/features/shell/shell_screen_test.dart` lines 261 and 591–592.

<a id="g86"></a>

### G86 · Shell areas with nothing to show yet

- **Type:** missing state
- **Milestone:** M1
- **Area:** App shell: canvas, sidebar, right panel, title bar, status bar
- **Artboards:** every board drawn with `FmWindow`; `a1-10` ("+N"); `a3-14` (the status-bar language)
- **Gap or conflict:** Every board draws the shell with a rendered document: pages on the canvas, a filled sidebar tab and the FmDocPanel sections (File, Fonts in this document, Security). In M1 no page renders (M2), so these areas have nothing to show, and no board draws them empty. Two drawn details are incomplete too. The "+N" overflow button (a1-10) is a ghost Button whose only text is `'+' + tabsMore`, so its only name is "+4", which says nothing to a screen reader, and its digits stay Latin where FmWindow turns the page and zoom digits Arabic-Indic. FmWindow's strings hold `more: '{n} more'`, which no markup uses. The status bar's language slot (`statusLang`) is drawn once, in a3-14, with the language of the selected text block.
- **Decision:** (1) **Canvas:** its surface with a quiet empty state in the centre: the `file-text` glyph at `--icon-lg` in the secondary icon colour, over "Available in a future version" in the caption style and the tertiary text colour ([B069](BACKLOG.md#open)). It is a focus stop named "Document pages" and has focus when the shell opens, so the table's keys work at once. Its inset focus ring ([G22](#g22)) shows after a key press on it or when Tab returns to it, not for the launch focus: no board draws a ring around the document area. (2) **Sidebar:** the tabs switch. The heading shows the tab's name, the placeholder document's page count on Pages, and the tab's buttons disabled with the future-version tooltip. The tab body stays empty until M2, where [G29](#g29)'s EmptyState covers empty tabs ([B065](BACKLOG.md#open)). (3) **Right panel:** only its 40 px heading, "Document" ("Edit" in Edit mode), with More disabled. The sections come with an open document in M2 ([B068](BACKLOG.md#open)). (4) **"+N":** the visible text is "+" and the count, in the region's digits ([G34](#g34)). Its accessible name is FmWindow's "{n} more" ("3 more"). It is disabled with the future-version tooltip until the menu exists in M2 ([B028](BACKLOG.md#open)). (5) **Status-bar language:** left out in M1. The slot shows with the M3 editor, when the selected block's language is known (a3-14, [B072](BACKLOG.md#open)).
- **Status:** Decided
- **Evidence:** `design/FmWindow.dc.html` lines 26 (the "+N" Button), 166 (the canvas slot), 170 (the language slot), 184 (`more: '{n} more'`), 199 and 242 (`digits()` on the page and zoom text), 212 (a board that passes no tabs still gets an open document), 224 (`overflowLabel: '+' + (p.tabsMore || 0)`) and 243 (`statusLang`); `design/FmDocPanel.dc.html` lines 17 (the 40 px heading) and 21–25 (the sections); `design/01 First run and files.dc.html` line 171 (a1-10, `tabs-more="{{ 4 }}"`); `design/03c Edit review and translate.dc.html` line 149 (a3-14, `status-lang="English (United Kingdom) · spelling"`). Implemented in `app/lib/features/shell/shell_canvas.dart` lines 10–25 and 78–121, `shell_sidebar.dart` lines 19–22 and 158–166, `shell_panel.dart` lines 13–17, 29–32 and 72–83, `shell_title_bar.dart` lines 108–123, `shell_status_bar.dart` lines 24–25 and 153–166 (`shell_screen.dart` line 71 passes no language), and the keys `shellCanvas`, `shellMoreDocuments` and `shellMoreDocumentsBadge` in `app/lib/l10n/app_en.arb` (M1 phases H2 and H4); checked in `app/test/features/shell/shell_screen_test.dart` lines 596–597, 745, 765, 790 and 820.

<a id="g87"></a>

### G87 · macOS key symbols missing from the bundled fonts

- **Type:** export gap
- **Milestone:** M1
- **Area:** Fonts / key caps
- **Artboards:** every macOS board that shows a shortcut, in tooltips, `Kbd` and menus; for example `a1-5`, `a2-2`, `a11-3`
- **Gap or conflict:** The macOS key caps use ⌘ (U+2318), ⌥ (U+2325), ⇧ (U+21E7), ⌃ (U+2303), ⌫ (U+232B) and ⌦ (U+2326). Kbd sets them in `--font-ui`, whose IBM Plex faces have none of these glyphs, so the browser draws them from the system fonts at the end of the stack (`system-ui`, `-apple-system`, `'Segoe UI'`). The references do the same. The app bundles only the Plex files and drops the system families from the stack ([ADR 0013](adr/0013-fonts-and-icons.md)). None of the 18 bundled TTF files (Plex Sans, Serif, Mono, Sans Arabic, Sans Hebrew and Sans Devanagari) maps any of the six code points (as [G06](#g06) found for several scripts). All of them map the arrows (U+2190 to U+2193) and the minus sign (U+2212) that the table also uses.
- **Decision:** The Plex files stay unmodified (OFL-1.1, Reserved Font Name), and no symbol font is added. On macOS, the only system whose caps use these symbols, Flutter's own fallback draws them from a system font, as ADR 0013 provides for characters the bundle does not cover; the design's stack does the same through `system-ui`. Windows and Linux never show them: the table writes Ctrl, Alt, Shift and Del there. In M1 the symbols show in the Search button's ⌘K, in the tooltips of enabled controls (the sidebar and panel toggles, Settings), on the start screen's cards and drop zone (⌘O, ⌘N) and on the entries of a narrow tool row's "More tools" menu; a disabled control's tooltip shows its reason instead of its keys, while a disabled menu entry keeps its caps, greyed, as native menus do. `flutter test` renders with Flutter's test fonts and no system fallback on every system, and the goldens run on Linux only, so a macOS variant rendered in a test draws a box for each of these caps (a test screenshot of the macOS shell shows a box before the K of Search). This is a test artefact, not what users see. The goldens get real glyphs from DejaVu Sans Mono, a system font of the Linux runner that only the tests load and append to the UI font chains ([G96](#g96)); the app never names it. ↵ (U+21B5), the table's cap for Enter, is missing too; no command uses Enter yet.
- **Status:** Decided. On 2026-10-16 phase K1 settled the goldens: DejaVu Sans Mono in tests only ([G96](#g96)); before, the macOS goldens waited for K1.
- **Evidence:** `design/_ds/…/components/core/core.css` line 60 (`.fm-kbd`, `var(--font-ui)`); `design/ds-additions/fm-additions.css` line 48 (`--font-ui`, ending in `system-ui, -apple-system, 'Segoe UI', sans-serif`); `design/FmWindow.dc.html` lines 202–205 (the caps); `tools/design-refs/README.md`, section "Deterministic output" (glyphs that no web font covers fall back to the system's fonts); the `cmap` tables of `app/assets/fonts/*/*.ttf`, read on 2026-10-16. Implemented in `app/lib/features/shell/shortcuts.dart` lines 98–137 (the caps), `app/lib/design/components/core/kbd.dart` lines 79–88 (Kbd uses the body font chain) and `app/lib/design/tokens.g.dart` lines 863–872 (the dropped families) (M1 phases F, G and H5).

<a id="g88"></a>

### G88 · Title bar content: the start screen's home header, a bare bar for first run and Settings

- **Type:** ambiguity
- **Milestone:** M1
- **Area:** Window chrome / title bar content
- **Artboards:** `a1-5`, `a1-3`, `a1-1`, `a1-2a`, `a1-2b`, `a1-2c`, `a11-1`
- **Gap or conflict:** The boards draw each screen as a window of its own. The start screen (FmStart) uses FmWindow's home header: the active "Ferman" tab, the open documents as idle tabs (two in FmStart's default data), "+" Open file, Search with ⌘K and Settings with ⌘,. a1-5 and a1-3 pass no tabs. First run (a1-1, a1-2a to a1-2c) and Settings (FmSettings, a11-1) use the bare header. The app shows these screens in one window under one title bar, so the bar's content has to follow the screen. The boards do not say what the bar shows when Settings opens over another screen.
- **Decision:** The title bar's content follows the route. The start screen shows a1-5's home header: the "Ferman" tab, no document tabs until documents open in M2, "+" and Search disabled with the future-version tooltip ([G10](#g10); [B018](BACKLOG.md#open), [B030](BACKLOG.md#open)), and Settings, which opens Settings (⌘, or Ctrl+,). On the start screen only Settings' keys work: the table's other keys have no handler there, so they do nothing and pass through (`ShellCommandScope` with `home`), and the cards show their keys from the same table. First run and Settings keep the bare bar their boards draw. Settings is a route inside the main window in M1 ([G89](#g89), ARCHITECTURE.md §12), so opening it over the start screen or the editor makes the bar bare too, and closing it brings the header back. The editor (in M1 only at `/debug/shell`) shows the house button "Home" and its documents.
- **Status:** Decided
- **Evidence:** `design/FmStart.dc.html` lines 16 (`FmWindow … home="{{ true }}"`) and 93 (two sample tabs by default); `design/01 First run and files.dc.html` lines 45 (a1-3) and 107 (a1-5), both `tabs="{{ noTabs }}"`, line 240 (`noTabs: []`), and lines 30, 52, 64 and 78 (a1-1, a1-2a, a1-2b and a1-2c, `bare`); `design/FmSettings.dc.html` line 16 (`bare`); `design/FmWindow.dc.html` lines 20 (the home tab or the house button), 27 ("+"), 30 (Search) and 31 (Settings). Implemented in `app/lib/app/router.dart` lines 57–76, `app/lib/features/shell/shell_title_bar.dart` lines 15–36 and 50–54, `app/lib/features/shell/shell_commands.dart` lines 35–38 and 46, and `app/lib/features/start/start_screen.dart` lines 58–74 (M1 phases H2, H5 and I3); checked in `app/test/features/shell/shell_route_test.dart` lines 51, 87, 115 and 182.

<a id="g89"></a>

### G89 · Settings in M1: a surface in the main window, the Privacy switches and the default-app line

- **Type:** conflict
- **Milestone:** M1
- **Area:** Settings: the window, Privacy, General
- **Artboards:** `a11-1`, `a11-1w`, `a11-1h`, `a1-3`; the added close control applies to every built Settings pane (`a11-1b`, `a12-2c`, `a12-2d`); resolved by `a11-1-m1`, `a11-1w-m1` and `a11-1h-m1` (export 519d42a)
- **Gap or conflict:** Three things the boards draw cannot hold in M1. (1) a11-1 draws Settings in its own window ("Settings open in their own window (⌘,)"), under FmWindow's bare title bar with its own traffic lights or caption buttons, which are the only way to close it. M1 opens no second window: Flutter 3.47.7 has no stable desktop multi-window support ([ROADMAP.md §5](ROADMAP.md#5-m1-foundations) step 9; [ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration)), so Settings shows inside the main window, whose caption buttons close the whole app. (2) a11-1h draws four of the five network switches on: Check for updates, Signature checks, Timestamps and Downloads you start. Your AI provider is off. Nothing connects in M1: the update check comes in M5, language packs and timestamps in P3, and AI in P4 ([ADR 0015](adr/0015-privacy-and-network.md)); revocation lookups come in phase 3, allowed on 2026-10-16 and off until first use ([G51](#g51)). [G24](#g24), [G51](#g51) and [G52](#g52) cover which rows are listed, not their state. (3) The General pane says "Preview opens PDFs on this Mac." on both systems ([G16](#g16)). Naming the current default app needs the system lookup that comes with "Make Ferman the default…" in M2 (a1-3).
- **Decision:** (1) **Close control:** Settings is a window-styled surface inside the main window: the route `/settings` (`/settings/<pane>`), pushed over the screen it opens from, under the bare title bar ([G88](#g88)), with the 240 px pane list at the start. The surface adds an X icon button named "Close settings", 12 px from the top and end edges of the pane, with Esc in its tooltip. Esc and the shortcut table's Close document keys, ⌘W on macOS and Ctrl+W on Windows and Linux, close it too ([G83](#g83)). Closing returns to the screen below, or to the start screen when Settings was opened directly. The caption buttons still close the app. Real windows follow later (ARCHITECTURE.md §12, [B090](BACKLOG.md#open)). (2) **Privacy switches:** Privacy is a skeleton in M1. All five switches show off and are disabled with the future-version tooltip ([G10](#g10)), and so is "Show network activity…" ([B084](BACKLOG.md#open)). The pane never claims a connection the app does not make. Each switch takes its ADR 0015 default when its feature ships: the update check on, the others off until used. "Signature checks" stays disabled until phase 3 builds the revocation lookups, which the owner allowed on 2026-10-16 ([G51](#g51), [B083](BACKLOG.md#open)). (3) **Default-app line:** until the lookup exists, the line says what the button does, in a1-3's words: "Ferman can be the app that opens when you double-click a PDF." On Windows it adds "Windows lets you choose it in Settings › Default apps.", following the a11-1w and a1-3 notes ([G16](#g16)). The button is disabled with the future-version tooltip ([B080](BACKLOG.md#open)). The design's line, naming the app that opens PDFs now, returns with the lookup in M2.
- **Status:** Resolved on 2026-10-17 by export 519d42a: the M1 build boards draw all three parts. a11-1-m1 draws Settings as a window-styled surface pushed over the screen below, with the Close settings button 12 px from the pane's top and end edges and Esc in its tooltip, closed by Esc and ⌘W too, and the default-app line in a1-3's words with the button disabled and its future-version tooltip; a11-1w-m1 adds "Windows lets you choose it in Settings › Default apps." and Ctrl+W; a11-1h-m1 draws the five switches off and disabled, and "Show network activity…" disabled. The a11-1h-m1 note keeps Signature checks disabled "until the owner decides on revocation lookups (G51, Q06)"; the owner allowed them on 2026-10-16, and this entry's reason stands: the switch stays disabled until phase 3 builds them. These boards also draw General's M2 controls and every pane of the navigation enabled, which the app does not follow ([G108](#g108)). Was Decided.
- **Evidence:** `design/11a Settings.dc.html` lines 28 (the a11-1 note), 29 (the a11-1w note) and 36 (the a11-1h note); `design/FmSettings.dc.html` lines 16 (`FmWindow … bare`), 17–23 (the pane list and the pane, with no close control), 30 (the default-app line) and 134 (`nets`, `on: true` on four rows); `design/FmWindow.dc.html` lines 18 (the traffic lights) and 33 (the Windows caption buttons); `design/01 First run and files.dc.html` lines 45 (a1-3, "Ferman can be the app that opens when you double-click a PDF.") and 46 (its note on Windows). Implemented in `app/lib/features/settings/settings_screen.dart` lines 18–37, 74–82 and 231–250, `app/lib/app/router.dart` lines 24–27 and 88–103, `app/lib/features/shell/shortcuts.dart` lines 232–238 (`closeDocument`), `app/lib/features/settings/privacy_pane.dart` lines 17–20 and 126–141, and `app/lib/features/settings/general_pane.dart` lines 26–30 and 182–218, with the keys `settingsClose`, `settingsDefaultApp` and `settingsDefaultAppWindows` (`app/lib/l10n/app_en.arb` lines 987, 1123 and 1127) (M1 phases H5 and I4); checked in `app/test/features/settings/settings_screen_test.dart` lines 145, 169, 289, 344 and 662. In 519d42a: `design/11a Settings.dc.html` lines 29, 30 and 39 (a11-1-m1, a11-1w-m1 and a11-1h-m1 with their notes); `design/FmSettings.dc.html` lines 22 (Close settings, shown when `gated`), 30 and 126 (the default-app line and its disabled button) and 154 (every switch off when `gated`).

<a id="g90"></a>

### G90 · Settings: a change that cannot be saved

- **Type:** missing state
- **Milestone:** M1
- **Area:** Settings: storing the settings
- **Artboards:** none draws it; it can show on every built pane (`a11-1`, `a11-1b`, `a11-1h`)
- **Gap or conflict:** Changes in Settings apply at once, and there is no Save button (a11-1 note). When the settings file cannot be written, the change still applies for the session, but no board says how Settings tells the person. FmSettings and the 11a boards draw no error. The design's warning Banners are bars for app events, such as a11-7b's "changed on disk" and a11-7c's XFA form.
- **Decision:** Settings shows a warning Banner, the box variant with the warning tone's icon, at the top of the pane above its heading: "Your settings couldn't be saved." over "This change applies until you close Ferman.", with Dismiss. The change stays in force for the session. The Banner stays while other panes show, and goes when a later change is stored or on Dismiss. First run reports no failure yet ([B089](BACKLOG.md#open)): a language choice that cannot be stored still switches the UI, and when the end of first run cannot be stored, first run shows again at the next launch.
- **Status:** Decided
- **Evidence:** `design/11a Settings.dc.html` line 28 (the a11-1 note: "Changes apply immediately; there is no Save button."); `design/FmSettings.dc.html` lines 22–23 (the pane starts with its heading); `design/11b App.dc.html` lines 103 and 106 (a11-7b, a `bar` Banner in the warning tone) and 111 and 114 (a11-7c); `design/_ds/…/_ds_bundle.js` lines 831–860 (Banner: `variant = 'box'`, the warning icon, the Dismiss icon button). Implemented in `app/lib/features/settings/settings_save_failure.dart` lines 9–43, `app/lib/features/settings/settings_screen.dart` lines 40–42 and 206–215, `app/lib/features/settings/general_pane.dart` lines 74–82 and `app/lib/features/settings/language_region_pane.dart` lines 71–74, with the keys `settingsSaveFailedTitle`, `settingsSaveFailedMessage` and `settingsSaveFailedDismiss` (`app/lib/l10n/app_en.arb` lines 991–999); first run in `app/lib/features/onboarding/language_picker.dart` lines 139–141 and `app/lib/features/onboarding/onboarding_screen.dart` lines 78–89 (M1 phases I2 and I4); checked in `app/test/features/settings/settings_screen_test.dart` line 218.

<a id="g91"></a>

### G91 · Region formats: which regions the picker offers, and how they are named and ordered

- **Type:** ambiguity
- **Milestone:** M1
- **Area:** Settings › Language and region: region formats
- **Artboards:** `a11-1b`, `a12-2c`, `a12-2d`
- **Gap or conflict:** a11-1b's Region formats picker, set to Türkiye, holds three sample regions: Türkiye, Deutschland and United States. Only Türkiye is translated: "Türkei" in German (a12-2d) and "تركيا (Türkiye)" in Arabic (a12-2c). "Deutschland" and "United States" stay in their own languages in every UI language, so the English board shows one own name and two English names. The design does not say which regions the picker offers, how their names read in each UI language, in what order they come, or how a person goes back to the system's region.
- **Decision:** The picker offers the 45 regions of `Region.all`, plus the system's region and the stored one when either is outside that list. Each region shows its name in the UI language, followed by its own name in parentheses when the two differ. This generalises a12-2c's "تركيا (Türkiye)": English shows "Türkiye", "Germany (Deutschland)" and "United States", Turkish "Almanya (Deutschland)". The names are CLDR 48 territory names in English, Turkish and Arabic; other UI languages take the English names, as their UI does. A code CLDR does not name shows as the code. The list follows the UI language's alphabetical order: CLDR 48 collation for English, Turkish and Arabic (Turkish puts Çekya between Brezilya and Danimarka), the English order for other languages. There is no separate "match system" item. Choosing the system's region stores no region, so the formats follow the system again, also when its region changes.
- **Status:** Decided
- **Evidence:** `design/FmSettings.dc.html` lines 37 (the region Select, `default-value="tr"`) and 112 (`regions`: Türkiye, "Türkei" in German, "تركيا (Türkiye)" in Arabic; "Deutschland" and "United States" in every language); `design/12 Localization.dc.html` line 96 (a12-2c, `lang="ar"`). Implemented in `app/lib/l10n/region_names.dart` lines 1–55 (the CLDR 48 / ICU 78.3 / Node.js 24.22.0 provenance, `regionDisplayName`, `sortRegionCodes`), 63–772 (the names) and 774–1554 (the orders), `app/lib/l10n/region.dart` lines 155–205 (`Region.all`) and `app/lib/features/settings/language_region_pane.dart` lines 31–39 and 162–203 (M1 phase I4); the script that generated the tables is not in the repository yet ([B092](BACKLOG.md#open)); checked in `app/test/l10n/locale_providers_test.dart` lines 267–345 and `app/test/features/settings/settings_screen_test.dart` lines 600 and 622.

<a id="g92"></a>

### G92 · Document languages: the list before anyone can change it

- **Type:** ambiguity
- **Milestone:** M1
- **Area:** Settings › Language and region: document languages
- **Artboards:** `a11-1b`, `a12-2c`, `a12-2d`
- **Gap or conflict:** a11-1b draws the document languages as two accent badges, Turkish and English, and an Add button. The badges are fixed data: always Turkish and English, only translated into the UI language ("Türkisch" and "Englisch" in German, a12-2d; "التركية" and "الإنجليزية" in Arabic, a12-2c), and every Language board uses the Türkiye region. The design does not say where the list starts for another region. Nothing uses the list in M1: text recognition, spell-check and hyphenation come later (a11-1b note).
- **Decision:** Until a person can change the list, its Add button is disabled with the future-version tooltip ([G10](#g10), [B081](BACKLOG.md#open)), and the badges show the list the app would start from: the language of the region's formats when the app has a name for it, then English. Türkiye gives Turkish and English, as a11-1b and a12-2c draw it. Saudi Arabia, Egypt and the United Arab Emirates give Arabic and English. A region whose language is English or has no name in the app, such as Germany or the United States, gives English alone. The names are UI strings in the UI language. The badges change with the region setting at once, as the examples do.
- **Status:** Decided
- **Evidence:** `design/FmSettings.dc.html` lines 36 (the badges `t.tr` and `t.en`, and Add) and 91–93 (`tr` and `en` in English, German and Arabic); `design/11a Settings.dc.html` line 30 (the a11-1b note); `design/12 Localization.dc.html` line 96 (a12-2c: "Region formats still follow Türkiye because that is the chosen region"). Implemented in `app/lib/features/settings/language_region_pane.dart` lines 26–30 and 127–160 (M1 phase I4); checked in `app/test/features/settings/settings_screen_test.dart` lines 552, 576 and 585.

<a id="g93"></a>

### G93 · Persian and Hebrew: a right-to-left UI with English strings

- **Type:** missing variant
- **Milestone:** M1
- **Area:** Localization / right to left
- **Artboards:** `a1-1`, `a11-1b`; right to left drawn only in Arabic: `a12-1ar`, `a12-2a`, `a12-2c`
- **Gap or conflict:** Persian and Hebrew appear only as rows in the language pickers; no Persian or Hebrew screen is drawn ([G18](#g18)). [G20](#g20) has them mirror the UI at once and show English until they are translated, and M1 translates neither. So the app needs a right-to-left UI with English strings, which no board draws: every right-to-left board is Arabic, with Arabic strings. Flutter takes the direction from the strings' locale, so English would stay left to right.
- **Decision:** The UI's direction follows the chosen language, not the language of its strings. This keeps the outcome [ADR 0014](adr/0014-localization-and-rtl.md) asks for (right to left for ar, fa and he), but takes the direction from the chosen language (`AppLanguage.textDirection`) rather than the strings' locale, which is English for Persian and Hebrew until their ARB files exist. Persian and Hebrew mirror the whole UI at once, as Arabic does ([G18](#g18)), while their strings fall back to English ([G20](#g20)). This holds in first run as soon as the row is chosen (a1-1 note), in Settings, and at launch when either is the system's language. The strings keep English type and casing; numbers, dates and units follow the region ([G34](#g34)). In the pickers each language's own name keeps its script and direction. The other untranslated languages stay left to right. Inside the mirrored UI each English string is wrapped in a left-to-right isolate, so it keeps its own order and sits at the start of its line: without it "1 of 2" would read "of 2 1" and "Open file…" "…Open file". When a translation ships, its strings replace the English ones and nothing else changes.
- **Status:** Decided
- **Evidence:** `design/01 First run and files.dc.html` lines 234 (the فارسی and עברית rows, `rtl`) and 41 (the a1-1 note: "Choosing a language switches the interface live, before Continue."); `design/12 Localization.dc.html` line 96 (a12-2c, the only right-to-left Settings board, in Arabic). Implemented in `app/lib/app/app.dart` lines 14–18, 47 and 75–81 (`Directionality` in the `MaterialApp.router` builder, above every route), `app/lib/l10n/app_language.dart` lines 103–129 (`textDirection`, `isolatesFallbackStrings`, `uiLocale`) and `app/lib/l10n/locale_providers.dart` lines 70–82 (`appLocale`) (M1 phases I2 and I4); checked in `app/test/app/app_test.dart` lines 67–105, `app/test/features/onboarding/onboarding_test.dart` line 355 and `app/test/features/settings/settings_screen_test.dart` line 380. The isolates come from `IsolatedFallbackLocalizations` (`app/lib/l10n/isolated_fallback.g.dart`, generated by `tools/l10n`), installed by `app/lib/app/app.dart` when `AppLanguage.isolatesFallbackStrings` (`app/lib/l10n/app_language.dart`), and checked in `app/test/l10n/isolated_fallback_test.dart`.

<a id="g94"></a>

### G94 · AI clients through MCP: no board draws the connection settings

- **Type:** missing state
- **Milestone:** M4
- **Area:** Settings / AI clients
- **Artboards:** none; nearest: `a11-1g` (Ferman's own AI assistant pane), `a11-1h` (Privacy, "Your AI provider")
- **Gap or conflict:** The owner decided on 2026-10-16 that AI clients such as Claude and ChatGPT can work in the running app through a local MCP server, set up from Settings with a connection link or a one-click setup ([ADR 0019](adr/0019-ai-clients-through-mcp.md), [Q20](QUESTIONS.md#q20)). No board draws that section, the notice shown while a client is connected, the client's name on its edits in the review list, or the Privacy row for connected clients. The drawn AI boards (a10-1 to a10-2b, a11-1g) are Ferman's own assistant, a different feature (P4).
- **Decision:** Built in M4 step 11 from the existing Settings components: a section that lists the supported clients, each with its connection link or setup button and its state, and a switch that stops the server; a Privacy row per connected client; a quiet notice in the window while one is connected. A board is asked for in the re-export; until then the layout is recorded here when it is built.
- **Status:** Decided
- **Evidence:** No board in `design/` mentions MCP or connecting an outside assistant. `design/11a Settings.dc.html` (a11-1g, a11-1h) draws Ferman's own assistant and "Your AI provider". Built in M4 step 11 ([ROADMAP.md](ROADMAP.md#8-m4-rest-of-phase-1)).

<a id="g95"></a>

### G95 · Narrow windows in M1: how the tool row, the mode tabs and the panels give way

- **Type:** missing state
- **Milestone:** M1
- **Area:** App shell responsiveness
- **Artboards:** none narrower than 1440 px ([G21](#g21)); the tool rows of every mode in FmWindow
- **Gap or conflict:** [G21](#g21) decides the principle (labels hide behind their icons, then tools move into an overflow menu; panels collapse before anything overlaps; mode tabs fall back to icons when they do not fit; a minimum window width) but no board draws any of it: not the order, not the overflow button, not what its menu lists, not which panel goes first.
- **Decision:** (1) A tool row frees space one item at a time, from the end: first the hints that have no menu entry (the Organize hint), then the labels of inline tools, which hide behind their icons (the name stays the tooltip and the accessible name), then tools move into the overflow menu, and last the actions after the spacer (Dark reading mode, Mark edited text, Review edits, Apply redactions) and the colour group of the Comment row. Show comments never moves. (2) The overflow button, "More tools" with the `ellipsis` icon and no caret, takes the place of the first item that moved, before the spacer, and mirrors in right to left. It is in the row's arrow-key order and opens with Enter, Space or ArrowDown. (3) Its menu lists exactly the moved items, in row order, with dividers where the row had a separator or the spacer: toggles as checkable items with their state, disabled items with their reason, the zoom select and the segmented controls as submenus with the current choice checked, Review edits with its count ("Review edits (3)", the number written for the region), the colours as a "Color" submenu once every tool has moved; tools that have their own menu appear as plain items ([B093](BACKLOG.md#open)). (4) A focused tool that moves into the menu hands focus to the overflow button, which hands it back to that tool when it returns, never out of an open menu. An item that moves into the menu closes the popover it had open (a select's list), which does not reopen. (5) Mode tabs fall back to icons all together, only when the labelled strip does not fit; the label is then the tooltip, after the usual delay and closed by Escape, and stays the accessible name; if even the icons do not fit, the strip scrolls. (6) A panel steps aside when the canvas would drop below 640 px (approved by the owner on 2026-10-17): the right panel first, as the document is the hero; then the panel opened last stays. A panel that stepped aside stays open and comes back when there is room; its toggle and shortcut show what is visible and bring it back, and the other panel steps aside. Below the width where a panel fits beside the canvas on its own (904 px for the right panel, 856 for the sidebar; only on the web and narrow tablets) its toggle is disabled with "Make the window wider to show this panel". (7) The window's minimum size is 1024 × 640 px; the owner approved the width on 2026-10-16 (960 px would also have allowed half-screen snapping on a 1920 px display, with only German-length mode labels falling back to icons), and 640 px fits a 1280 × 720 screen with the taskbar. At 1024 px every row fits with some labels hidden and the overflow menu is not needed; the right panel steps aside. (8) Document tabs keep their 112 px minimum (a1-10) down to the desktop minimum; "+N" is unchanged until M2 counts it from the width ([B028](BACKLOG.md#open)). (9) A stacked tool button at touch density is 52 px tall: the CSS fixes it at 48 px and touch raises `--icon-lg` from 20 to 24 px, so the button grows by the same 4 px. (10) A disabled tool whose label has hidden shows its reason as its tooltip, as every disabled control does ([G10](#g10)); its name stays in the accessible name and the menu ([B095](BACKLOG.md#open)).
- **Status:** Decided. The owner approved the 1024 px minimum width on 2026-10-16 and the 640 px canvas minimum on 2026-10-17; the canvas minimum was Proposed until then.
- **Evidence:** `design/FmWindow.dc.html` lines 46–100 (the tool rows); [G21](#g21). Implemented in `app/lib/design/components/navigation/toolbar.dart` (the overflow), `label_collapse.dart`, `mode_tabs.dart` and `tool_button.dart` (`stackedHeightFor`), `annotations/annotation_tools.dart`, `forms/popover.dart` (`PopoverAnchorVisibility`), `core/tooltip.dart` (`focused`), `app/lib/features/shell/shell_state.dart` (`ShellPanels`), `shell_tool_rows.dart`, `shell_mode_bar.dart`, `shell_canvas.dart`, `app/lib/design/window_metrics.dart` and `app/lib/app/desktop_window.dart` (`setMinimumSize`) (M1 phase H6); checked in `app/test/design/components/navigation/toolbar_overflow_test.dart`, `label_collapse_test.dart`, `mode_tabs_test.dart` and `app/test/features/shell/shell_narrow_test.dart`.

<a id="g96"></a>

### G96 · Window goldens: the native traffic lights and the system font fallback

- **Type:** ambiguity
- **Milestone:** M1
- **Area:** Goldens / window chrome / fonts
- **Artboards:** every macOS board, which draws the traffic lights inside FmWindow (for example `a1-1`, `a1-5`, `a2-1b`, `a11-1`, `a12-1ar`); the key caps of `a1-5` and `a2-1b`; the CJK language names of `a1-1`
- **Gap or conflict:** The boards draw the macOS traffic lights as part of the window: 12 px circles in #FF5F57, #FEBC2E and #28C840 with a 0.5 px inner ring of rgba(0,0,0,.25), 8 px apart, 14 px from the leading edge. In the app they are the real native buttons, which the Swift runner places beside Ferman's title bar (G15, phase H1). The boards also draw the macOS key symbols with the browser's system font fallback (no `--font-ui` web font has them), and the Japanese, Korean and Chinese language names of a1-1 in the design's `--font-ui` web fonts, IBM Plex Sans JP and KR and Noto Sans SC, which the app does not bundle. The app leaves both to the user's system ([ADR 0013](adr/0013-fonts-and-icons.md), [G87](#g87)). `flutter test` has neither a native window nor a system font fallback, so a whole-window golden would show an empty slot where the lights sit and boxes for those characters.
- **Decision:** Test-only stand-ins, never in the app. macOS window goldens paint simulated traffic lights over the view (`app/test/helpers/traffic_lights.dart`) at the layout `TitleBar` sends to the native side, repeating the Swift layout (centred in the 37 px above the title bar line, mirrored right to left with close at the end), in FmWindow's colours in both themes; `app/test/goldens/traffic_lights_test.dart` pins the geometry in both directions. For the characters, `app/test/flutter_test_config.dart` loads DejaVu Sans Mono and Noto Sans CJK JP from the Linux runner's `fonts-dejavu-core` and `fonts-noto-cjk` and appends them to every UI font chain through the test-only `FermanFontFamilies.debugExtraFallback`; CI fails when either package changes version, and a golden that shows such a character fails when its font is missing. Expected differences: the goldens' ⌘ is DejaVu's, smaller and lighter than in the references, which take it from Inter through the container's fontconfig, and the CJK names are Noto Sans CJK JP Regular where a1-1 draws IBM Plex Sans JP and KR and Noto Sans SC at a medium weight, a different typeface as well as a different weight. On a Mac both come from the system's own fonts, and where the real lights sit is the owner's hardware check (ROADMAP §5 step 8). Windows and Linux goldens show Ferman's own caption buttons, which the app draws itself. The component goldens also load DejaVu Serif (fonts-dejavu-core) under the names Georgia and Times New Roman, the system fonts the FontPicker sample's "On this device" list names (`systemFontStandIns` in `app/test/helpers/component_golden.dart`), and fail any golden whose text uses a font family the run has not loaded.
- **Status:** Decided.
- **Evidence:** `design/FmWindow.dc.html` line 18 (the lights); `design/ds-additions/fm-additions.css` line 48 (`--font-ui`: the Plex CJK and Noto Sans SC web fonts, then the system families); `app/macos/Runner/MainFlutterWindow.swift` (the native layout, phase H1). Implemented in `app/test/helpers/traffic_lights.dart`, `app/test/helpers/fonts.dart`, `app/test/helpers/window_golden.dart` and `app/lib/design/theme/typography.dart` (the hook), with the tests `app/test/goldens/traffic_lights_test.dart`, `app/test/goldens/test_fonts_test.dart` and `app/test/design/theme/typography_test.dart` (M1 phase K1); the component goldens in `app/test/helpers/component_golden.dart` and `app/test/goldens/components_golden_test.dart` (M1 phase L).

<a id="g97"></a>

### G97 · The golden matrix: drawn variants, variants built from tokens, and expected differences

- **Type:** missing variant
- **Milestone:** M1
- **Area:** Golden matrix
- **Artboards:** compared: `f6`, `f6a`, `a1-1`, `a1-2b`, `a1-2c`, `a1-5`, `a11-1`, `a11-1w`, `a11-1b`, `a11-1h`, `a12-2a`, `a12-2c`, `a2-1b`, `a3-1d`, `a12-1tr`, `a12-1ar`; not compared (German): `a12-2b`, `a12-2d`; nearest drawn modes: `a2-9`, `a4-1`, `a4-1d`, `a5-1`, `a5-1d`, `a6-1`, `a7-1`, `a8-1`, `a9-1`
- **Gap or conflict:** ROADMAP §5 step 11 asks for goldens of the language picker, welcome steps 2 and 3, the empty start screen, Settings General and Language and region, and the shell in eight modes with macOS and Windows chrome, each in light and dark × en, tr and ar. The matrix adds Settings General with Windows chrome (a11-1w) and the Privacy pane, the third built pane of Settings, as the brief asks goldens of every implemented screen: 144 goldens. The boards draw only some of these variants, and those they draw often show states M1 cannot reach (an open document, recent files, unsaved edits).
- **Decision:** Every golden is built from the tokens and the ARB files; a board, where one exists, is the reference the comparison report scores it against ([ARCHITECTURE §13.5](ARCHITECTURE.md#135-flutter-tests)). The variants with no board are built from tokens as G16 (Windows), G17 (dark), G18 (right to left) and G19 (Turkish) decide:

  | Screen (goldens) | Drawn | Built from tokens, no board |
  |---|---|---|
  | Language picker (6) | `a1-1` macOS light en | dark; tr; ar |
  | Welcome step 2 (6) | `a1-2b` macOS light en | dark; tr; ar |
  | Welcome step 3 (6) | `a1-2c` macOS light en | dark; tr; ar |
  | Empty start (6) | `a1-5` macOS light en; `a12-2a` macOS light ar (with recent files, M2) | dark (`a1-4b` is the dark start with recent files, M2); tr |
  | Settings General, macOS (6) | `a11-1` light en | dark; tr; ar |
  | Settings General, Windows (6) | `a11-1w` light en | dark; tr; ar |
  | Settings Language and region (6) | `a11-1b` macOS light en; `a12-2c` macOS light ar | dark; tr |
  | Settings Privacy (6) | `a11-1h` macOS light en (its switches drawn on; M1 shows them off and disabled, [G89](#g89)) | dark; tr; ar |
  | Shell, macOS (48) | light en: View `a2-1b`, Edit `a3-1a` to `a3-1c`, Comment `a4-1`, Fill & Sign `a5-1`, Organize `a6-1`, Convert `a7-1`, Protect `a8-1`, Tools `a9-1`; dark en: View `a2-9` (with the Dark reading mode on, P2, B040), Edit `a3-1d`, Comment `a4-1d`, Fill & Sign `a5-1d`; Edit tr `a12-1tr`; Edit ar `a12-1ar` | dark Organize, Convert, Protect, Tools; tr and ar in every mode but Edit |
  | Shell, Windows (48) | Edit light en `f6a` (and the strip of `f6`); dark: only a title bar and mode bar strip in the DS additions sheet | every other mode; dark (whole window); tr; ar |

  The shell goldens show the editor at `/debug/shell` with its placeholder documents, so the drawn modes are the nearest states, not the same document; the report compares a2-1b, a3-1d, f6, f6a, a12-1tr and a12-1ar with the canvas masked ([B098](BACKLOG.md#open)). Regions: Türkiye for Turkish, Saudi Arabia for Arabic and the United Kingdom for English, and Türkiye for Language and region in every language ([G34](#g34)). During first run only the theme is stored, so language and region come from the system locale (en-GB, tr-TR, ar-SA), as at a first launch.

  Differences the report shows and that are expected in M1, each from a decision recorded elsewhere:
  - Every screen: controls for later milestones are disabled with the future-version tooltip where the boards draw them enabled ([G10](#g10), [G11](#g11)): the start cards, quick tools and drop-zone buttons, Search, most Settings panes and options, the shell's tools and Save, and the links (Help translate, Source code, Support the project). Headings sit about 1 px lower than in the references; body rows line up within a pixel.
  - `a1-1`: the app focuses the search field at launch (accent border and caret) where the board draws a focus ring on Türkçe; 18 rows add "Not translated yet" ([G20](#g20)); the CJK names differ in weight ([G96](#g96)).
  - `a1-2b`: "1 of 2" against "2 of 3", eight facts against five and two dots against three ([G24](#g24)).
  - `a1-2c`: "2 of 2"; nine tiles show the clock and only "3 interface languages" is ticked ([G12](#g12)); the licence reads Apache-2.0 ([G13](#g13)).
  - `a1-5`: the shorter start copy of [G11](#g11) ("PDF files", and a drop-area subtitle without conversion), so the drop zone's content is one line shorter: the icon and heading sit about 10 px lower, the buttons and the privacy note about 10 px higher.
  - `a12-2a`: the board is the start with recent files (M2), masked below the quick tools; the Arabic card descriptions fit on one line, so the cards are shorter.
  - `a11-1`, `a11-1w`: the stored theme shows Light or Dark where the board shows Match system; the default-app line and the close button follow [G89](#g89), and the Windows text wraps, making that card about 10 px taller.
  - `a11-1b`, `a12-2c`: the closest pairs; in Arabic the example rows sit 1 to 3 px lower.
  - `a11-1h`: the switches are off and disabled where the board draws four of them on ([G89](#g89)), and "Show network activity…" is disabled.
  - Shell (`a2-1b`, `a3-1d`, `f6`, `f6a`, `a12-1tr`, `a12-1ar`): no page, thumbnails or document panel before M2 ([G86](#g86)); five placeholder tabs plus "+3" against three; the placeholder document is saved, where the Edit boards show unsaved edits (Save enabled, a dot on the tab, Review edits 3); "Page 1 of 3" against a2-1b's "Page 2 of 3". `a2-9` is not compared: it draws the Dark reading mode on with the page inverted, which M1 keeps disabled (B040) and paper-white ([G17](#g17)).
- **Status:** Decided. On 2026-10-17 the comparison moved to the M1 build boards of export 519d42a: the pairs of `a1-2c`, `a1-5`, `a11-1`, `a11-1w` and `a11-1h` now use `a1-2c-m1`, `a1-5-m1`, `a11-1-m1`, `a11-1w-m1` and `a11-1h-m1`, each also in Turkish and Arabic, and the superseded boards are not compared. `tools/design-refs/compare-map.json` records the differences expected against the new boards; the list above still describes the earlier pairs.
- **Evidence:** `app/test/goldens/screens_golden_test.dart` and `shell_golden_test.dart` (the matrix, with the board ids in the test names), `tools/design-refs/compare-map.json` (the pairs, crops, masks and notes), `build/design-compare/report.md` from `node tools/design-refs compare` (M1 phases K1 and K2).

<a id="g98"></a>

### G98 · Key caps and weekday names in right to left

- **Type:** missing variant
- **Milestone:** M1
- **Area:** Component library: Kbd, DatePicker
- **Artboards:** `a12-1ar` (the title bar's "K ⌘"); no board draws a Kbd with a bracket or arrow, a menu, a tooltip or a DatePicker in right to left ([G18](#g18))
- **Gap or conflict:** The right-to-left component goldens showed two things no board decides. A `Kbd` cap took the paragraph direction, so a mirrored character flipped: "⌘]" read "[ ⌘", naming the wrong key. And the DatePicker took intl's short weekday names, which for Arabic are the whole day names ("الخميس"), too wide for a day column, so one broke mid-word.
- **Decision:** A cap is one key and reads left to right in every UI direction, so its glyph is never mirrored; the row of caps follows the UI direction, as a12-1ar draws "K ⌘" ([COMPONENTS.md](COMPONENTS.md) decision 45). The DatePicker uses the language's short weekday names unless one of them is longer than four characters, and then the narrow names: one letter each in Arabic (ح ن ث ر خ ج س) and Persian, a letter with geresh in Hebrew, while English, Turkish and French keep their short names (decision 46). Arabic boards of a menu with shortcuts and of the DatePicker are asked for in the re-export.
- **Status:** Decided.
- **Evidence:** `design/FmWindow.dc.html` (the Search caps), drawn mirrored in `build/design-refs/a12-1ar.png`; intl 0.20.3's Arabic `STANDALONESHORTWEEKDAYS` and `STANDALONENARROWWEEKDAYS`. Implemented in `app/lib/design/components/core/kbd.dart` and `app/lib/design/components/additions/date_picker.dart` (M1 phase L); checked in `app/test/design/components/core/kbd_test.dart`, `app/test/design/components/additions/date_picker_test.dart` and the `component_Kbd`, `component_Tooltip`, `component_Menu` and `component_DatePicker` right-to-left goldens.

<a id="g99"></a>

### G99 · Commands whose keys no M1 control shows

- **Type:** missing state
- **Milestone:** M4
- **Area:** Keyboard shortcuts
- **Artboards:** `a11-3` (the shortcut table), `a11-1j`, `a11-2` (the palette), `FmWindow` (the tool rows and their key hints)
- **Gap or conflict:** The shortcut table has commands that no control of the M1 shell shows with its keys: the cheat sheet itself; Create PDF in the Convert row, Duplicate and Extract in Organize, Find & redact in Protect, and Date and Sign in Fill & Sign, which FmWindow draws without keys; Save (a Button, which shows no keys) and Save as and Save a copy (no control); moving between documents; Find, Go to page and reading mode; the Show comments switch (a Switch has no keys); form-field navigation; the page grid's keys; and the window's own commands (the caption buttons and traffic lights give their names without keys, as native windows do). The Fit width, Fit page and Actual size keys have controls whose keys M1 cannot show yet (B034).
- **Decision:** Tools show the keys FmWindow gives them and no others. The keys of every other command are listed by the command palette (B030) and the cheat sheet (B076); until then they work from the keyboard where their feature exists. `app/test/features/shell/shortcut_caps_test.dart` walks every control of the shell on the three systems, checks that each shows exactly its command's keys, and keeps the list of key-only commands (`_keysOnly`) and of those shown from M2 (`_shownFromM2`).
- **Status:** Decided.
- **Evidence:** `design/FmWindow.dc.html` lines 93, 95, 110, 111, 133 and 141 (Date, Sign, Duplicate, Extract, Create PDF and Find & redact, without `shortcut`) and 140 (Redact, with it). Implemented in `app/lib/features/shell/shell_tool_rows.dart` (M1 phase L).

<a id="g100"></a>

### G100 · Scripts in a document: no board draws the notice

- **Type:** missing state
- **Milestone:** M2
- **Area:** Open / document scripts
- **Artboards:** none draws it; the copy comes from `a8-4` (Security report) and `a8-3` (Remove hidden information); the banner slot of `a1-9`, `a1-9d` and `a2-10a`
- **Gap or conflict:** The owner confirmed on 2026-10-16 that Ferman never runs document JavaScript and tells the user when a document contains scripts ([Q13](QUESTIONS.md#q13)). No board draws that notice, in the window or in Document properties. The design speaks of scripts only where they are removed: in Protect (P2), a8-4's finding "JavaScript blocked" ("1 script runs when this file is opened. Ferman never runs scripts; other apps might.") and a8-3's row "A script that runs when the file opens. Ferman never runs it."; and in PDF/A-2b (P4), a1-11's option and a9-4's "Removed 1 script".
- **Decision:** **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** the engine finds the scripts in its structure scan at open, and the document opens with an info Banner in the banner slot above the page, in the bar variant of a1-9 and a2-10a, with the `shield-check` icon a8-4 gives that finding. Its title says how many scripts the file has ("This document contains 1 script."), its text is a8-4's sentence "Ferman never runs scripts; other apps might.", and it has Dismiss. Document properties lists the scripts in a row of its Advanced tab, which no board draws, in a8-3's words. Nothing offers to run a script; removing them stays in Protect (a8-3, a8-4).
- **Status:** Decided; the decision is Proposed with the M2 plan.
- **Evidence:** `design/08 Protect.dc.html` lines 106 (the a8-4 note: "JavaScript is never run; Ferman says it blocked it."), 161 (a8-3's JavaScript row) and 168 (a8-4's finding); `design/09a Tools.dc.html` lines 114 and 160 (a9-4's `pdfaFixes`); `design/01 First run and files.dc.html` lines 175 (a1-9's Banner), 201 (a1-9d's) and 265 (a1-11's PDF/A-2b option); `design/02 View.dc.html` line 242 (a2-10a's). No board shows a scripts notice in the window. [ARCHITECTURE.md §9.2](ARCHITECTURE.md#92-untrusted-content-rules) keeps scripts from running.

<a id="g101"></a>

### G101 · Engine or PDFium unavailable: no board draws the error

- **Type:** missing state
- **Milestone:** M2
- **Area:** Start / errors
- **Artboards:** none draws it; nearest: `a1-9b` (an open error), `a1-4-m2` and `a1-5` (the start screen it shows on), and the warning Banner of [G90](#g90)
- **Gap or conflict:** When the engine library does not load or speaks an API version the app does not accept, `bootstrap()` installs `UnavailableEngineService` (M1), so the app still opens ([ARCHITECTURE.md §3.9](ARCHITECTURE.md#39-versioning)). When PDFium is missing or broken, the engine still starts and reports it in `PdfiumStatus`. ARCHITECTURE §3.9 and §12 and ROADMAP §6 step 1 promise "an error screen instead of crashing" for both. No board draws it.
- **Decision:** **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** the start screen shows a warning Banner, the box variant, at the top of its content, as Settings shows its warning ([G90](#g90)): "Ferman can't open PDF files right now." over "A part of Ferman is missing or doesn't match this version. Installing Ferman again fixes this.", with "Copy technical details" as in [G63](#g63). Open file…, the drop area, recent files and ⌘O or Ctrl+O are disabled with the Banner's title as their reason; Settings and the rest of the app keep working. The web build, whose engine is stubbed until phase 5 (`unsupportedPlatform`), keeps the future-version state instead.
- **Status:** Decided; the decision is Proposed with the M2 plan.
- **Evidence:** `app/lib/app/bootstrap.dart` line 42 (`_startEngine`); `app/lib/engine/engine_service.dart` lines 19–27 (`libraryMissing`, `apiMismatch`, `unsupportedPlatform`) and 49 (`UnavailableEngineService`); `crates/ferman-api/src/facade/engine.rs` lines 62–66 ("Starting never fails"); [ARCHITECTURE.md §12](ARCHITECTURE.md#12-platform-integration) ("If the library is missing, Ferman shows an error screen instead of crashing."); ROADMAP §6 step 1. No board in `design/` draws an engine or PDFium failure. Implemented in M2 step 1 (wave W1, the render commit): `app/lib/engine/engine_problem.dart` line 7 (`EngineProblem`, with the technical details, which hold no path), `app/lib/engine/engine_providers.dart` line 26 (`engineProblem`, which reads an error in every state because Riverpod retries a failed status), `app/lib/features/start/start_screen.dart` lines 70 (the reason for Open file… and the drop area), 118 and 208 (the Banner with "Copy technical details"), and the keys `startEngineUnavailableTitle`, `startEngineUnavailableMessage` and `startCopyTechnicalDetails` (`app/lib/l10n/app_en.arb` line 996); checked in `app/test/features/start/start_screen_test.dart` line 203 (the group "when the engine cannot open files (G101)", in English, Turkish and Arabic) and `app/test/engine/engine_problem_test.dart`. Recent files and the ⌘O key do not exist yet, so they need no reason until M2 step 6. The integration test with PDFium missing and the goldens of the banner come with M2's CI and goldens commits.

<a id="g102"></a>

### G102 · lopdf and PDFium disagree: no notice drawn

- **Type:** missing state
- **Milestone:** M2
- **Area:** Open / the two parsers
- **Artboards:** none draws it; the read-only state of `a1-9d` (and `a11-7c`)
- **Gap or conflict:** When both parsers open a file but disagree on its structure (the page count or page sizes), the document opens read-only with a notice: approved by the owner on 2026-10-16 ([ADR 0004](adr/0004-lopdf-model-pdfium-renderer.md), [ARCHITECTURE.md §5.1](ARCHITECTURE.md#51-open) step 6). No board draws the notice. The nearest drawn states are a1-9d (a file read-only on disk) and a1-9 (a repaired file).
- **Decision:** **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** the document opens in a1-9d's read-only state: the lock on its tab, Read-only in the status bar and Save disabled with the tooltip "Read-only". An info Banner in the bar variant says why: "Ferman opened “name” read-only." over "Parts of this file don't match each other, which can mean it is damaged. You can read it as usual." It offers no action in M2: repair is a full rewrite to a new file, which needs the writer of M3.
- **Status:** Decided; the behaviour was approved on 2026-10-16, and the notice is Proposed with the M2 plan.
- **Evidence:** `docs/adr/0004-lopdf-model-pdfium-renderer.md` lines 78–80 (the approval); ARCHITECTURE.md §5.1 step 6 and §5.2; `design/01 First run and files.dc.html` lines 197–204 (a1-9d). ROADMAP §6 step 2 tests it with a crafted file.

<a id="g103"></a>

### G103 · Default PDF app on Windows and Linux

- **Type:** missing variant
- **Milestone:** M2
- **Area:** Default PDF app
- **Artboards:** `a1-3`, `a11-1`, `a11-1w`, `a11-1-m1`, `a11-1w-m1`
- **Gap or conflict:** a1-3 draws the macOS prompt ("Open PDFs with Ferman?", "macOS asks you to confirm the change.", "Opens PDFs now: Preview → Ferman"), and its note says that on Windows the button opens Settings › Default apps, "because Windows doesn't let apps change this themselves". Windows lists there only apps registered for PDF files, which the installer of M5 does. Nothing is drawn for Linux, where the choice needs the desktop file that packaging installs (M5, [Q12](QUESTIONS.md#q12)). a11-1-m1 and a11-1w-m1 draw the M1 line and a disabled button ([G89](#g89)).
- **Decision:** **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** on macOS the button works from M2: the line names the app that opens PDFs now, as a11-1 draws it, and the button asks the system (`NSWorkspace`, macOS 12 and later), which asks the user, as a1-3 says. On Windows the button opens Settings › Default apps (`ms-settings:defaultapps`) only once Ferman is registered for PDF files, which the M5 installer does; until then it stays disabled with "Available in a future version" and the line keeps a11-1w-m1's wording. On Linux it stays disabled the same way until packaging (M5), and the line keeps a11-1-m1's wording. The first-run prompt a1-3 shows only where the button can act ([B080](BACKLOG.md#open)).
- **Status:** Decided; the decision is Proposed with the M2 plan.
- **Evidence:** `design/01 First run and files.dc.html` lines 43–46 (a1-3 and its note); `design/11a Settings.dc.html` lines 29 and 30 (a11-1-m1, a11-1w-m1); `design/FmSettings.dc.html` lines 30 (the line and the button) and 126 (`defaultLine`).

<a id="g104"></a>

### G104 · Progressive open: where a1-7's rules begin, and thumbnails

- **Type:** ambiguity
- **Milestone:** M2
- **Area:** Open / large files / thumbnails
- **Artboards:** `a1-7`; related: `a2-3p` (thumbnails)
- **Gap or conflict:** a1-7 draws a 2,400-page file opening with a progress card and the banner "You can read while Ferman finishes. Search, thumbnails and editing turn on when all 2,400 pages are indexed.", and [ARCHITECTURE.md §5.1](ARCHITECTURE.md#51-open) applies that to every file. The Proposed thumbnail budget asks for the first 12 thumbnails within 300 ms after the first page ([ARCHITECTURE.md §14](ARCHITECTURE.md#14-performance-budgets)). Thumbnails come from the render thread, that is PDFium, and need nothing from lopdf's index (§5.3). The design does not say at what size an open becomes a1-7's progressive open.
- **Decision:** **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** thumbnails render from PDFium once the first page is visible, without waiting for indexing; search waits for the index, and so does editing from M3. Above the progressive-open threshold, Proposed as more than 1,000 pages or an indexing estimate over 2 s (taken after 1 s of indexing), a1-7 applies as drawn: the progress card, the banner, the sidebar closed, and search and thumbnails turning on when indexing ends. The thumbnail budget is measured on `long-500`, below the threshold. The threshold is presented at the M2 review.
- **Status:** Decided; the decision and the threshold are Proposed with the M2 plan.
- **Evidence:** `design/01 First run and files.dc.html` lines 145–155 (a1-7: `sidebar="{{ false }}"`, the TaskProgress, and the Banner at line 152); ARCHITECTURE.md §5.1 step 5, §5.3 ("Thumbnails come from the render thread.") and §14 (the thumbnail strip budget).

<a id="g105"></a>

### G105 · Drop targets in a document window

- **Type:** missing state
- **Milestone:** M2
- **Area:** Drag and drop
- **Artboards:** `a1-6`; related: `a1-4-m2`, `a6-1`
- **Gap or conflict:** a1-6 draws files dragged over the start screen ("Drop files anywhere in this window") with two targets, "Open in 3 tabs" and "Combine into one PDF", and its note says that dropping onto an open document's page grid inserts pages instead (6.1). No board draws files dragged over a document window or its tab strip. Combining files waits for M4 (a1-4-m2: "Create PDF and Combine files wait for M4"), and so does Organize's page grid.
- **Decision:** **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** in M2 the start screen (the whole window, as a1-6 draws) and a document window (its canvas and its tab strip) take drops, with a1-6's overlay and per-file notes; each PDF opens in a new tab, and a file that isn't a PDF follows [G11](#g11) and [G28](#g28). a1-6's "Combine into one PDF" target stays visible and disabled with "Available in a future version" until M4, and inserting pages by a drop on the page grid comes with Organize in M4 ([B104](BACKLOG.md#open)).
- **Status:** Decided; the decision is Proposed with the M2 plan.
- **Evidence:** `design/01 First run and files.dc.html` lines 123 (the a1-4-m2 note) and 130–132 (a1-6 and its note); `design/FmStart.dc.html` lines 41–52 (the drag-over overlay) and 59 (`drop`, `dropTabs`, `dropCombine`).

<a id="g106"></a>

### G106 · The owner-password unlock dialog is not drawn

- **Type:** missing screen
- **Milestone:** M2
- **Area:** Restricted PDFs
- **Artboards:** `a2-10a`, `a2-10b` (the "Unlock with owner password…" buttons); `a1-8`, `a1-8b` (the layout reused)
- **Gap or conflict:** a2-10a's banner and a2-10b's dialog footer offer "Unlock with owner password…", and the a2-10a note says it "lifts the restriction for this session". The dialog it opens is not drawn. a1-8 and a1-8b draw only the password a file needs to open.
- **Decision:** **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** the dialog reuses a1-8's document-modal Dialog with the `key-round` icon of a2-10b's button: the title "Unlock with owner password", the description "Enter the owner password for “name”. Ferman forgets it when you close the file.", a password field labelled "Owner password" with "Show password", and Cancel and Unlock. A wrong password shows a1-8b's error, with the keyboard hint and no lockout. The right one removes the banner, and the modes and tools it allows take the state of their milestone ([G27](#g27)); reopening the file brings the restriction back.
- **Status:** Decided; the decision is Proposed with the M2 plan.
- **Evidence:** `design/02 View.dc.html` lines 242 (a2-10a's Banner with `actUnlock`), 246 (its note) and 254 (a2-10b's `unlockBtn`); `design/01 First run and files.dc.html` lines 156–167 (a1-8, a1-8b).

<a id="g107"></a>

### G107 · "Show in" buttons: the label on each system

- **Type:** missing variant
- **Milestone:** M2
- **Area:** File actions / platform wording
- **Artboards:** `a1-9b`, `a1-9c`, `a11-7c`, `a11-1c`; later phases: `a5-6d`, `a7-3`, `a8-2c`, `a9-4`
- **Gap or conflict:** Every "Show in" button the boards render is the macOS one, "Show in Finder": a1-9b, a1-9c, a11-7c and the recovery-copy row of a11-1c ("Finder’da göster" and "إظهار في Finder" in a1-9c's Turkish and Arabic variants), and the later-phase results of a5-6d, a7-3, a8-2c and a9-4. Only FmSettings carries another system's label: "Show in Explorer" for that row on Windows, which no board renders. Nothing names the Linux label.
- **Decision:** macOS shows "Show in Finder", as drawn. Windows shows "Show in Explorer", FmSettings' label, which [G43](#g43) already uses. **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** Linux shows "Show in folder" and opens the folder that holds the file in the desktop's file manager. Each label is its own string, translated like the drawn ones.
- **Status:** Decided; the Linux label is Proposed with the M2 plan.
- **Evidence:** `design/01 First run and files.dc.html` lines 187 (a1-9b) and 329, 336 and 343 (`showIn` in English, Turkish and Arabic, a1-9c); `design/11b App.dc.html` lines 114 and 213 (`actXfa`, a11-7c); `design/FmSettings.dc.html` line 127 (`showIn`: "Show in Explorer" on Windows, "Show in Finder" otherwise); `design/Wording for app strings.md` line 32.

<a id="g108"></a>

### G108 · M1 build Settings boards draw the M2 controls and every pane enabled

- **Type:** conflict
- **Milestone:** M1
- **Area:** Settings: General and the pane list
- **Artboards:** `a11-1-m1`, `a11-1w-m1`, `a11-1h-m1`; the finished panes `a11-1`, `a11-1w`, `a11-1h`
- **Gap or conflict:** The M1 build boards of export 519d42a disable only what their notes name: the default-app button (a11-1-m1, a11-1w-m1), and the five network switches and "Show network activity…" (a11-1h-m1). They draw General's M2 controls enabled (PDF pages in dark theme, Page layout for new documents, Zoom, Reopen documents from last time), every pane of the Settings navigation enabled, and the search field above it. In M1 those controls do nothing, only General, Language and region and Privacy are built, and searching Settings comes in M4 ([B073](BACKLOG.md#open)).
- **Decision:** The brief's rule for unfinished features outranks the board: what is not implemented yet stays visible as designed, disabled, with "Available in a future version" ([G10](#g10)). The app keeps those General controls disabled until they work: M2 step 3 enables Paper white and Dimmed, the page layout, the zoom and reopening, and Dark reading mode waits for P2 ([G33](#g33)). The panes not built yet stay disabled in the navigation until their milestone, and so does the search field. Everything else follows the boards, and their comparison pairs expect this difference ([G97](#g97)).
- **Status:** Decided
- **Evidence:** `design/FmSettings.dc.html` lines 19 (the search field, with no `disabled`), 20 (the pane list, with no disabled branch), 26–29 (the General controls, with no `disabled`) and 30 (only the button takes `disabled="{{ gated }}"`); `design/11a Settings.dc.html` lines 29, 30 and 39 (the three boards and their notes). Implemented in `app/lib/features/settings/general_pane.dart` lines 15–24 and 111–202 and `app/lib/features/settings/settings_screen.dart` lines 34–37 and 272–292 (`_NavRow`) (M1 phase I4); `tools/design-refs/compare-map.json` (the a11-1-m1, a11-1w-m1 and a11-1h-m1 pairs).

<a id="g109"></a>

### G109 · A recent file that needs a password: no preview

- **Type:** missing state
- **Milestone:** M2
- **Area:** Start / recent files
- **Artboards:** `a1-4`, `a1-4b`, `a1-4c`, `a1-4-m2`, `a12-2a`; the lock of `a1-8`
- **Gap or conflict:** Every recent file on the Start boards shows a page preview, and none needs a password; a1-8's payslip, which does, is not in the list. A preview of such a file cannot be drawn without its password, and keeping one would store an image of protected content on disk.
- **Decision:** **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** Ferman renders and stores no preview of a file that needs a password to open. Its card keeps the page shape in paper white with the `lock` icon centred where the page image would be, the icon a1-8's tab carries, and the rest of the card follows the boards. A file with only an owner password opens without one (a2-10a) and gets its preview as usual.
- **Status:** Decided; the decision is Proposed with the M2 plan.
- **Evidence:** `design/FmStart.dc.html` lines 25 and 29 (the pinned and recent cards with their page previews) and 65–74 (the recent files, none of them encrypted); `design/01 First run and files.dc.html` lines 158 and 394 (a1-8's `tabsLocked`, with the `lock` icon); ROADMAP §6 step 6 ("no preview is stored for a document that needs a password").

<a id="g110"></a>

### G110 · Search results from comments, form fields and bookmarks

- **Type:** missing state
- **Milestone:** M2
- **Area:** Search
- **Artboards:** `a2-4a` (Look in), `a2-4b`, `a2-3e`
- **Gap or conflict:** a2-4a's "Look in" offers Page text and Comments, both on by default, Form fields and Bookmarks. a2-4b and a2-3e show the results in the sidebar grouped by page ("Page 1", with its count), and every result drawn is page text. Nothing shows where a match in a comment, a form field or a bookmark title goes or how it is told apart, and a bookmark sits on no page.
- **Decision:** **Proposed, part of the [M2 plan](PROGRESS.md#m2-plan):** results stay grouped by page, as a2-3e draws. A comment or a form field belongs to the page it is on, and a bookmark to the page it opens. Inside a group, page text comes first in reading order, then comments, fields and bookmarks, each with an icon before its snippet: `message-square` and `text-cursor-input`, the badges of the Pages thumbnails, and `bookmark` from the design system's icon set. The kind (comment, form field, bookmark) is part of the result's accessible name. A bookmark that opens no page is listed after the last page.
- **Status:** Decided; the decision is Proposed with the M2 plan.
- **Evidence:** `design/02 View.dc.html` lines 100 (a2-3e), 119 (the a2-4a options) and 124–131 (a2-4b); `design/FmSidebar.dc.html` lines 30–31 and 43–44 (the Pages badges and their legend: `message-square` for comments, `text-cursor-input` for form fields) and 166–176 (`results`: page groups of page text only).

<a id="g111"></a>

### G111 · Save as: "Optimized for web" drawn enabled

- **Type:** conflict
- **Milestone:** M3
- **Area:** Saving
- **Artboards:** `a1-11`, `a1-11b`
- **Gap or conflict:** a1-11 and a1-11b (export 519d42a) draw Save as with three formats: "PDF", "PDF/A-2b, for archiving" and "Optimized for web" ("The first page opens before the whole file downloads. Images are compressed to 150 ppi."). a1-11b draws only PDF/A-2b disabled, which reads as "Optimized for web" being available when Save as ships in M3. ROADMAP §7 step 8 keeps both disabled. Writing a linearized file with downsampled images needs the image pipeline that arrives with Compress in M4, beyond M3's writer (incremental update and the full rewrite).
- **Decision:** "Optimized for web" stays visible and disabled with "Available in a future version" until M4, when Compress brings the image pipeline; PDF/A-2b stays disabled until P4. The decision is looked at again when M3 is planned: if linearizing without image changes fits M3, the format could ship then with its description shortened to the first sentence.
- **Status:** Decided.
- **Evidence:** `design/01 First run and files.dc.html` line 266 (a1-11's three format radios) and line 297 (a1-11b: only PDF/A-2b carries `disabled`); [ROADMAP.md §7](ROADMAP.md) step 8.

<a id="g112"></a>

### G112 · App icons from the logo export

- **Type:** gap
- **Milestone:** M2
- **Area:** App icons
- **Artboards:** `Ferman Logo.dc.html` (directions `1a`, `1b`, `1c`)
- **Gap or conflict:** The owner's logo export of 2026-10-19 (`94e596d`) adds a board with three directions and the folder `design/assets/logo/`. The folder holds only direction 1a, "Mühür": the mark, its dark, small and one-colour forms, a 1024 app icon in light and dark, and a favicon. The board shows the icon on mock tiles: macOS (132 px, radius 30, a 96 px mark), iOS light and dark, Android adaptive and themed, Windows and Linux light and dark, a browser tab, and a size test where 32 px and below use the small mark. It does not say:
  - the file sizes and shapes each platform needs;
  - the macOS icon's margins and shadow;
  - which colour a Windows icon takes, since an ICO cannot follow the system theme;
  - how a favicon follows a dark browser.
- **Decision:** direction 1a is the logo, since it is the only one exported. `tools/app-icons` draws every desktop and web icon from the export's own paths and colours (the tokens `seal-500`, `seal-300`, `paper-50`, `soot-100`), and 32 px and below use the small mark, as the board's size test does.
  - **macOS:** Apple's 1024 grid: an 824-point `paper-50` rounded square, 100 points in, radius 185.4. Inside it, the export's 600-point mark at `translate(212 212) scale(6)`, which is the board's 96 px mark in a 132 px tile. The board's radius 30 would scale to 187, so Apple's radius is used. The board's web shadow (8 px down, 18 px blur) is replaced by Apple's template shadow (10 points down, 10 points blur, 30 %), which stays inside the canvas.
  - **Windows and Linux:** the mark alone on a transparent ground in `seal-500`, with the ring and the F cut out. The board draws them in the tile's colour, so the taskbar shows through. The board's lighter `seal-300` on dark taskbars is not possible in one ICO, so `seal-500` is used everywhere.
  - **Web:** an SVG favicon with the small mark as one even-odd path. It is `seal-500`, and `seal-300` under `prefers-color-scheme: dark`, as the board's light and dark tabs draw it, with a 32 px PNG fallback. The PWA icons are the mark (`any`) and the edge-to-edge app icon (`maskable`, and the 180 px Apple touch icon). The manifest's colours are `paper-50`.
  - **Not drawn yet:** the dark and tinted macOS icons need an Icon Composer `.icon` ([B108](BACKLOG.md#open), M5), and the iOS and Android icons wait for those projects ([B107](BACKLOG.md#open), P5).
- **Status:** Decided.
- **Evidence:** `design/Ferman Logo.dc.html`, the `DEF` entry `1a` (tile colours per platform) and `sizes()` (the small mark from 32 px down); the seven files of `design/assets/logo/`; `tools/app-icons/README.md`.

<a id="g113"></a>

### G113 · Madde 6: a font without "ğ" whose text has a "ğ"

- **Type:** conflict
- **Milestone:** M2 (the corpus file); M3 uses it
- **Area:** Test corpus / missing glyph
- **Artboards:** `DocKira` (Madde 6), `a3-3a`, `a3-3b`, `a3-17`
- **Gap or conflict:** The design sets Madde 6 in a font that lacks "ğ" and "Ğ": a3-3b flags the current font "No ‘ğ’ ‘Ğ’", and in a3-3a typing the "ğ" of "değiştirilemez" is the missing-glyph case. Yet Madde 6's own text, "… Olağan bakım ve küçük onarımlar kiracıya aittir.", already has a "ğ" in that font. A subset made from that text would contain the glyph.
- **Decision:** `kira-tr` keeps the design's text and sets Madde 6 in EB Garamond, a font Ferman does not bundle. The "ğ" of "Olağan" comes from IBM Plex Serif, the document's body font, the way a producer substitutes a glyph its font lacks. EB Garamond's subsets therefore have no "ğ" or "Ğ", and the missing-glyph path of ROADMAP E02 and E03 is exercised as drawn. The extracted text reads "Olağan" as usual.
- **Status:** Decided.
- **Evidence:** `design/DocKira.dc.html` line 35 (Madde 6 in `'EB Garamond'`, and the `glyph` state that adds "değiştirilemez"); `tools/corpus/src/docs/kira.rs` (`borrowed` in the Madde 6 style); `tests/corpus/README.md` (the kira-tr row).
