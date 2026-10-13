# Ferman Design System

Ferman is a free, fully open-source PDF editor meant to match and exceed Adobe Acrobat. A Rust engine sits under a single Flutter UI that ships to desktop first (macOS, Windows), then web and mobile. The core promise: **click any text in any PDF and edit it like a Word document**, with nothing behind a paywall. No subscription, no account, no telemetry. Documents never leave the device.

People use Ferman for hours at a time: lawyers, accountants, students, office workers, public-sector staff. The interface is calm, precise and trustworthy. **The document is always the hero**, and the UI stays quiet around it.

The name is the Ottoman word for an official imperial decree. That heritage shows up in small ways (iron-gall ink blue as the accent, a vermilion seal colour kept for stamps, paper-toned neutrals, a serif wordmark) but the result is modern and minimal, never ornamental.

## Sources

This system was built from a written brief only. **No codebase, Figma file, logo, brand fonts or screenshots were provided.** Every value here is an original proposal and needs review by the Ferman team. If those materials turn up, they take precedence and this system should be reconciled against them.

- Brief: product description, audience, colour, type, layout, component list, tone of voice and accessibility requirements (pasted into the project chat on 13 Oct 2026).
- Icons: [Lucide](https://lucide.dev) v0.460.0 (ISC), copied programmatically from `lucide-static`.
- Fonts: [IBM Plex](https://github.com/IBM/plex) Sans, Sans Arabic, Serif and Mono (SIL OFL 1.1), self-hosted from Google Fonts.

## Products

| Surface | Status | Covered here |
|---|---|---|
| Ferman Desktop (macOS, Windows) | First release | `ui_kits/desktop/` — full interactive recreation |
| Ferman Web | Later | Same components; `ModeTabs variant="underline"` and fluid layout |
| Ferman Mobile / tablet | Later | Same components under `data-density="touch"` (≥44px targets) |

## Index

```
styles.css                 Global entry — @imports only. Link this one file.
tokens/
  fonts.css                @font-face for IBM Plex (Latin, Latin Ext, Cyrillic, Greek, Arabic)
  colors.css               Ink / Seal / Paper / Soot ramps, status, annotation palette, semantic aliases, dark theme
  typography.css           Families, size/leading pairs, semantic type roles
  spacing.css              Spacing scale, control heights, app layout sizes, touch density
  effects.css              Radii, borders, shadows, focus ring, motion, z-index
  base.css                 Opt-in base (.fm-root), RTL icon flipping, keyframes
components/<group>/        React primitives (.jsx + .d.ts + .prompt.md + group .css + card)
guidelines/                Foundation specimen cards (colours, type, spacing, brand)
ui_kits/desktop/           Interactive Ferman Desktop recreation (index.html + JSX)
templates/editor-screen/   "Ferman editor screen" template for consuming projects (Design Component)
assets/fonts/              Self-hosted IBM Plex woff2 files
assets/icons/              145 Lucide SVGs used by the product
_dev/                      Dev-only shim so cards render before the bundle is compiled
thumbnail.html             Project tile
SKILL.md                   Agent-skill entry point
```

### Components

Load `styles.css` plus the compiled bundle, then read components from the namespace (`window.FermanDesignSystem_278323` in this project).

- **core/** — `Icon`, `Button`, `IconButton`, `Tooltip`, `Kbd`, `Badge`
- **forms/** — `TextField`, `Select`, `NumberStepper`, `Checkbox`, `Radio`, `Switch`, `ColorPicker`, `FontPicker`
- **panels/** — `PanelSection`
- **navigation/** — `ModeTabs` (+ `FERMAN_MODES`), `SegmentedControl`, `Toolbar` (+ `ToolbarSeparator`, `ToolbarSpacer`, `ToolbarGroup`), `ToolButton`
- **pages/** — `PageThumbnail`
- **editing/** — `TextEditBox` (+ `TextCaret`), `PageMark`, `SearchReplaceBar`
- **annotations/** — `AnnotationTools` (+ `ANNOTATION_TOOLS`), `Highlight`, `StickyNote`, `Stamp`
- **fill-sign/** — `PdfFormField`, `SignaturePad`
- **feedback/** — `Toast`, `Banner`, `TaskProgress`, `ProgressBar`, `Spinner`
- **empty/** — `DropZone`
- **overlays/** — `Dialog`, `Menu`, `CommandPalette`

No source component inventory existed, so the set follows the brief's key components plus the standard primitives they need. **Intentional additions** beyond the brief's list: `Menu` (context menus on thumbnails, tool variants), `Badge` (document state, "Not installed"), `PanelSection` (properties-panel structure), `PageMark` (one component for every on-page editing state), `Spinner`/`ProgressBar` (building blocks of `TaskProgress`), `Kbd` (shortcut display in tooltips, menus, palette).

### UI kit

`ui_kits/desktop/index.html` — a working recreation of the editor: switch modes, click text to select it and click again to edit it, change font/size/colour in the properties panel, ⌘K palette, ⌘F / ⌥⌘F find & replace with an honest font notice, comments, form filling and signatures, drag-to-reorder pages, OCR progress, redaction with confirmation, light/dark, dim page, RTL, touch density and the empty "Drop a PDF here" state. See its README.

---

## Content fundamentals

**Voice: clear, direct, helpful.** Ferman talks like a capable colleague: plain words, short sentences, no jargon, no hype. It explains what will happen and what the person can do about it.

- **Person.** The product calls itself **Ferman**, in the third person: "Ferman will use a similar font for this character." Never "we" or "I". The reader is "you" only when needed ("You can’t undo this after saving."). Most UI text needs neither.
- **Casing.** Sentence case everywhere: buttons, menu items, tooltips, dialog titles, panel sections ("Fonts in this document"). Mode names are proper nouns and keep their form: View, Edit, Comment, Fill & Sign, Organize, Convert, Protect.
- **Buttons are verbs.** Verb + object, repeating the action named in the title: "Apply redactions", "Save a copy", "Add signature", "Skip page". Never "OK", "Yes", "Submit". Use "…" when a command opens a dialog ("Extract as new PDF…").
- **Dialog titles are the question.** "Apply 2 redactions?" / "Save changes to “Kira sözleşmesi.pdf”?" The description states the consequence in one or two sentences.
- **Honest warnings.** Name the exact problem and what Ferman does about it: *"This font has no ‘ğ’. Ferman will use a similar font for this character."* / *"Garamond Premier Pro isn’t installed. Ferman is showing EB Garamond instead."* Never hide a substitution, never say "may".
- **Errors.** What happened, then the way out. No blame, no error codes in the main text, no "Oops". *"Couldn’t save. The disk is full — free some space or save somewhere else."* / *"Enter a page between 1 and 48."*
- **Progress and success.** Running: present participle with a count ("Recognizing text · Page 14 of 120 · about 2 minutes left"). Done: past-tense fact ("Text recognized", "Saved", "3 pages deleted"). Time estimates only after a few seconds of work.
- **Privacy is stated as fact.** "Files stay on this device." "Signatures are saved only on this device." No superlatives, no "military-grade", no badges of trust.
- **No emoji. No exclamation marks.** Not in UI, not in empty states, not in toasts.
- **Length.** Tooltips 1–4 words, no period ("Rotate page"). Toast titles ≤ 4 words. Banners one sentence where possible.
- **Numbers.** Always numerals, always tabular. Follow the OS locale: Turkish shows 13.10.2026, 18.500 TL, 11,5 pt; English shows 10/13/2026, 11.5 pt. Units are lowercase with a space: "11 pt", "210 × 297 mm".
- **Turkish first.** Use real Turkish characters everywhere, set `lang="tr"` so uppercase gives İ (GİZLİ, not GIZLI), and match search with Turkish case folding (I↔ı, İ↔i).
- **Keyboard shortcuts** appear in tooltips and menus, never inside sentences. macOS: ⌘ ⌥ ⇧; Windows: Ctrl Alt Shift.

| Write | Not |
|---|---|
| This font has no ‘ğ’. Ferman will use a similar font for this character. | Glyph substitution error (0x011F). |
| Apply 2 redactions? | Are you sure you want to proceed? |
| That file isn’t a PDF. To edit a Word or image file, convert it first. | Unsupported file format! |
| 3 pages deleted · Undo | Pages have been successfully deleted. |
| Files stay on this device. | Your data is 100% safe with us! |

---

## Visual foundations

**Overall feel.** Paper, ink, precision. Warm off-white surfaces, one confident ink-blue accent, hairline structure and very little decoration. The white PDF page is the brightest, most saturated thing on screen; the UI recedes around it.

**Colour.**
- *Ink* (`--ink-*`, iron-gall blue) is the only accent: primary buttons, selection, focus, active tool, links. Light theme uses ink-600 (#2A4DAF, 7:1 on white); dark uses ink-500.
- *Seal* (`--seal-500`, vermilion #B5372A) appears only on stamps and rare brand moments. It is never used for UI chrome, so it can't be confused with danger red.
- *Paper* neutrals are slightly warm (cream-grey). Canvas `--paper-150` sits behind the page, panels use `--paper-50`, menus and dialogs `--paper-0`.
- *Soot* neutrals (warm charcoal) build the dark theme: canvas `--soot-0`, panels `--soot-50`, raised `--soot-100`.
- *Status*: green success, amber warning, red danger, each with solid / text / tint / border tokens. Text tones meet 4.5:1 on their tints in both themes.
- *Editing states* have their own tokens, tuned for white paper and identical in both themes: selection (ink 26%), edited text (teal tint + underline), missing glyph (amber tint + wavy underline), search match (yellow) and current match (orange), redaction pending (red hatch + outline), redaction applied (true black), active text frame (ink-500).
- *Annotation palette* (yellow, green, blue, pink, orange, red, ink, black) is document colour and never changes with theme.

**Dark mode keeps the page readable.** The PDF page stays paper-white in dark theme. Users can opt into `data-page="dim"`, which lowers brightness and adds a trace of sepia without inverting anything.

**Type.** IBM Plex Sans for all UI (complete Turkish, Latin Extended, Cyrillic, Greek; IBM Plex Sans Arabic as the Arabic fallback). Desktop base 13/18. Weights 400 (text), 500 (buttons, labels), 600 (titles). Tabular numerals for page numbers, zoom, sizes, counters and hex values. IBM Plex Mono for raw values. IBM Plex Serif for the wordmark and as the stand-in for PDF content in mocks — never for UI.

**Spacing and density.** 4px base with 2/6/10px half-steps. Desktop is dense: controls 22/26/30/36px, panel padding 12px, section gaps 10px. `data-density="touch"` raises every control to ≥44px for tablet and mobile without changing components.

**Backgrounds.** Flat, solid surfaces only. No photography, no illustrations, no gradients, no textures, no patterns. The document supplies all the imagery.

**Borders.** 1px warm hairlines (`--border-subtle` between panels and sections, `--border-default` on inputs and secondary buttons, `--border-strong` on hover). The active text-edit frame is 1.5px ink. Panels are separated by hairlines, not shadows.

**Shadows.** Five levels, used only for things that float above the document: `--shadow-page` (the PDF page), `--shadow-sm` (secondary buttons, selected segments), `--shadow-popover` (menus, toasts, floating bars), `--shadow-dialog`, `--shadow-drag` (a lifted page). Each includes a faint 1px ring so edges stay crisp on paper backgrounds. No inner shadows except the pressed danger button.

**Corner radii.** Small and precise: 2px handles and badges, 4px buttons and inputs, 6px menus/cards/thumbnails, 8px dialogs and the command palette, 12px drop zone. Only status dots and the switch track are round. Nothing is pill-shaped.

**Cards.** Raised surface (`--surface-raised`), 6px radius, either a hairline border (lists in panels) or `--shadow-popover` (floating). No coloured left-border stripes. Status is shown with a tinted fill plus a full hairline border.

**Hover.** A neutral overlay: `--surface-hover` (6% ink-black, 7% white in dark) on ghost items; secondary buttons gain the overlay and a stronger border; primary buttons step one shade darker (ink-600 → 700). Hover appears in 60ms.

**Press.** One step further: `--surface-pressed` (10%) or ink-800 on primary. No scaling or bouncing.

**Focus.** Every focusable element shows a 2px ink ring with a 2px gap in the surface colour (`--focus-ring`). Inputs show focus on the field (ink border + 1px ring). Inside menus and lists focus is a stronger ink tint.

**Motion.** Short ease-out (`cubic-bezier(0.2, 0, 0, 1)`), like ink settling into paper. 60ms hover, 120ms toggles and tooltips, 180ms popovers, 260ms dialogs and toasts. Entrances are a fade plus a 4px rise; nothing bounces or overshoots. The text caret blinks in hard steps. `prefers-reduced-motion` sets every duration to 0.

**Transparency and blur.** No backdrop blur anywhere. Transparency is used only for hover/pressed overlays, the dialog scrim (38% warm black), and marks drawn on the page (selection, highlights multiply over text).

**Layout.** Fixed frame, scrolling canvas: title bar with mode tabs (38px), tool row (44px), page sidebar (216px), properties panel (264px), status bar (26px). Only the canvas and panel bodies scroll. Floating UI (find bar, task progress, toasts) pins to the canvas's top-end or bottom-end corner. All layout uses logical properties, so `dir="rtl"` mirrors the chrome while the PDF page keeps its own direction.

**Imagery.** None in the product chrome. If marketing ever needs imagery, it should be real documents on real desks, warm and natural, never stock-office cliché.

---

## Iconography

- **Set:** [Lucide](https://lucide.dev) (ISC licence), the only icon source. 145 glyphs are bundled into the `Icon` component (`ICON_PATHS`) and the originals live in `assets/icons/*.svg`. Lucide was chosen as a substitute because no Ferman icon set exists — **flagged for review**.
- **Style:** 24px grid line icons, rendered at **1.5px stroke** (the SVG files on disk use Lucide's default 2px; the component overrides it). Round caps and joins. No filled or duotone icons.
- **Sizes:** 16px default, 14px in dense rows and inputs, 20px for large/touch. 12px only with a 2px stroke.
- **Colour:** `currentColor`. `--icon-primary` for tools, `--icon-secondary` for decorative or leading icons, ink for the active tool, status colours only for status.
- **Delivery:** inline SVG through `<Icon name="…" />`. No icon font, no PNG icons, no sprite sheet.
- **RTL:** directional icons (arrows, chevrons in menus) take `flipRtl` and mirror under `dir="rtl"`.
- **Emoji:** never.
- **Unicode as icons:** only keyboard symbols in shortcuts (⌘ ⌥ ⇧ ↵ ⌫ ↑ ↓) and the × mark on the signature line. Typographic marks (· — “ ” ‘ ’ …) are punctuation, not icons.
- **Missing a glyph?** Copy it from `lucide-static` into `assets/icons/` and `ICON_PATHS`. Don't draw one.
- **Logo:** none was supplied. The wordmark is the name set in IBM Plex Serif Semibold (`--type-wordmark`). Do not draw a mark or a seal-style logo until the team provides one.

---

## Theming and accessibility

| Attribute | Effect |
|---|---|
| `class="fm-root"` | Opt-in base: font, colours, focus outlines, box-sizing |
| `data-theme="dark"` | Dark UI; page stays white |
| `data-page="dim"` | Dims PDF pages (dark-mode reading comfort) |
| `data-density="touch"` | ≥44px targets for tablet/mobile |
| `dir="rtl"` | Mirrors chrome via logical properties; flips `flipRtl` icons |

WCAG AA contrast for all text tokens, full keyboard support (roving focus in ModeTabs, SegmentedControl and Toolbar; trapped focus in Dialog; arrow navigation in Menu and CommandPalette), visible focus on everything, and live regions for search counts, toasts and progress.

## Notes for builders

- `_dev/ds-dev-shim.js` and `_dev/dev-bundle.js` let cards and the UI kit render before the compiled `_ds_bundle.js` exists. They do nothing once the bundle loads; consuming projects don't need them.
- Component styling lives in the group stylesheets under `components/*/` (reached through `styles.css`) and reads only design tokens.
