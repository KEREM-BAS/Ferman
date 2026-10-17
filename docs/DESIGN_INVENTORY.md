# Design inventory

This document inventories everything in [`design/`](../design/): every artboard, component, token,
icon and font. It maps each screen to the feature it shows, the milestone that ships it and the
engine capability it needs, and it flags the screens and states the design does not draw. It answers
item 2 of section 8 in the [brief](BRIEF.md).

The design is the visual source of truth and is read-only (brief §2). Behaviour follows the brief.
Conflicts and gaps, each with the decision taken, are in [DESIGN_GAPS.md](DESIGN_GAPS.md). Open
questions for the owner are in [QUESTIONS.md](QUESTIONS.md). The delivery plan is in
[ROADMAP.md](ROADMAP.md) and the engine design in [ARCHITECTURE.md](ARCHITECTURE.md).

The large tables in sections 5 to 9 were generated from a read-only pass over the first export, which
covered all of its 223 boards, and are included as generated. They keep the wording of that pass, so
an absolute path in them such as `/home/user/Ferman/design/...` means `design/...` in this
repository. The owner's export 519d42a ([Q11](QUESTIONS.md#q11)) added 30 boards, for 253 in all,
and changed the notes or copy of 13 others and of seven building blocks. The 30 new rows were written
by hand from the boards, their captions and their copy, in the shape of the generated rows, and the
rows of the changed boards were corrected where the change shows. After a further re-export,
regenerate the tables rather than editing rows by hand.

## Contents

1. [Purpose and how to read this document](#1-purpose-and-how-to-read-this-document)
2. [What the export contains](#2-what-the-export-contains)
3. [Section overview](#3-section-overview)
4. [Milestones](#4-milestones)
5. [Artboards](#5-artboards)
6. [Design system](#6-design-system)
7. [Icons](#7-icons)
8. [Fonts](#8-fonts)
9. [Fixes, flows and sample documents](#9-fixes-flows-and-sample-documents)
10. [Missing screens and states](#10-missing-screens-and-states)

## 1. Purpose and how to read this document

**Ids.** Every artboard has a stable id. The id is also an anchor in its file.

- `f1` to `f6a` are the boards in `00 Fixes`. `f4` and `f6` are the section boards for fixes 4 and 6.
- `a<section>-<board><variant>` are the product boards. `a3-3a` is section 3, board 3, variant a.
  Files that share a number share the section: 03a, 03b and 03c are all section 3, and the same
  holds for 05a/05b, 09a/09b, 11a/11b and 13a/13b. Some suffixes name what varies: `a2-3p` is the
  Pages tab, `a11-1w` is Windows, `a12-1tr` is the Turkish UI.
- A `-m1` or `-m2` suffix names a milestone build: `a1-2c-m1` is `a1-2c` as the M1 build shows it,
  and `a1-4-m2` is `a1-4` in the M2 build. The board without the suffix stays the finished product.
  `a12-0` is the region-format table at the top of `12 Localization`.
- `fa` to `fd` are the four flows in `15 Flows`.
- `G01` onwards are entries in [DESIGN_GAPS.md](DESIGN_GAPS.md), linked as `DESIGN_GAPS.md#g07`.
  `Q01` onwards are entries in [QUESTIONS.md](QUESTIONS.md). The boards that export 519d42a added or
  changed for a design gap print its G id as a tag beside their title, except the sidebar tab cards,
  which print no title of their own.

**Printed labels.** The id is the board's HTML anchor. The canvas prints its own label above each
board, and the board notes cite that label (for example "Review edits (3.12)"). For most boards the
two match, but not for all of them, so look a board up by its id:

- The fix boards print "FIX 1" to "FIX 6" (`f1` to `f6`) and "F4a", "F4b" and "F6a".
- The seven sidebar tab cards (`a2-3p`, `a2-3o`, `a2-3b`, `a2-3c`, `a2-3d`, `a2-3e`, `a2-3x`) print
  no label of their own.
- 40 boards have no variant letter in the id but print "a": `a1-4` is printed 1.4a, `a5-8` is 5.8a
  and `a13-16` is 13.16a.
- The M1 builds print the label of the board they build: `a1-2c-m1` prints 1.2c, `a1-5-m1` 1.5,
  `a11-1-m1` 11.1a, `a11-1w-m1` 11.1b and `a11-1h-m1` 11.1i. `a1-4-m2` prints 1.4d. `a12-0` prints
  no number, only its title; the Index calls it 12.0.
- 17 boards print a different letter:

| Ids | Printed | Boards |
|---|---|---|
| `a4-1d` | 4.1b | Comment — Note open on the page (dark). |
| `a5-1d` | 5.1b | Fill — Same form (dark). |
| `a11-1w`, then `a11-1b` to `a11-1k` | 11.1b, then 11.1c to 11.1l | Settings. The Windows board prints 11.1b, so every later letter is one step ahead of its id: `a11-1c` (Editing) is printed 11.1d and `a11-1h` (Privacy) 11.1i. |
| `a12-1tr`, `a12-1de`, `a12-1ar`, `a12-1ja` | 12.1a to 12.1d | The editor in Turkish, German, Arabic and Japanese. |

**Opening a board.** Open [`design/Index.dc.html`](../design/Index.dc.html) in a browser, or open a
section file with the id as the fragment, for example `design/03a Edit text.dc.html#a3-3a`. The files
load React and Babel from unpkg.com when they open, so they need a network connection until the M1
design-reference renderer vendors those scripts. The app never reuses their HTML or JavaScript
(brief §2).

**Milestone codes.** `M0` to `M5` are the milestones in brief §7. `P2` to `P5` are phases 2 to 5.
The design itself carries no milestone tags ([G33](DESIGN_GAPS.md#g33)), so every milestone here comes from the brief's
roadmap. Each board has one primary milestone: the first milestone that ships the board as drawn, or
its main part. Section 4 says what each milestone covers.

**Engine capability.** The last column of the artboard tables says what a screen needs from the
engine. It uses the crate names from brief §3 plus three terms:

| Term | Meaning |
|---|---|
| `ferman-core` | Document model, parsing and writing (lopdf), content-stream interpreter, incremental save. |
| `ferman-render` | Page rendering with pdfium-render, tiles, thumbnails, caches. |
| `ferman-text` | Text layout model (glyphs to words, lines, paragraphs and columns), hit testing, editing, reflow. |
| `ferman-fonts` | Font parsing, shaping, subsetting, system fonts, coverage and substitution. |
| `ferman-ops` | Page organisation, annotations, forms, watermark, redaction, compress and other operations. It splits into more crates as it grows. |
| `jobs` | Long work run through the `ferman-api` job system: async, cancellable, with a progress stream (OCR, convert, compress, batch). |
| `platform` | Operating-system integration on the app side: window chrome, file dialogs and associations, drag and drop, keychain, smart-card drivers, camera, printing. |
| `ui-only` | Flutter only. The screen needs nothing from the engine beyond what it already has. |

The UI reaches every engine capability through `ferman-api`, the only crate it calls, so `ferman-api`
is not repeated in each row. `ferman-cli` exposes the same operations. Text in parentheses narrows a
term, for example `ferman-core (incremental save)`. Three rows go beyond this vocabulary: the
assistant boards `a10-1` and `a10-2` need a model runtime that no crate in the brief covers (decided
when P4 is planned), `a7-4` needs scan edge detection (unassigned), and the web board `a14-2` assumes
the engine compiled to WebAssembly.

## 2. What the export contains

`design/` is a static HTML export of the Ferman Design System and the product screens. None of it is
application code.

| Path | What it holds |
|---|---|
| `00 Fixes.dc.html` to `14 Tablet and web.dc.html` | 21 section files with 253 artboards: 9 fix boards in `00 Fixes` and 244 product boards in the 20 files `01` to `14`. See section 3. |
| [`15 Flows.dc.html`](../design/15%20Flows.dc.html) | Four user journeys, `fa` to `fd`. Each step links to an artboard. See section 9. |
| [`Index.dc.html`](../design/Index.dc.html) | Table of contents with a status badge per row. |
| [`DS additions.dc.html`](../design/DS%20additions.dc.html) | Documentation sheet for 26 additions: patched and new components, tokens, type additions and state matrices. It defines no tokens itself. |
| [`ds-additions/fm-additions.css`](../design/ds-additions/fm-additions.css) | 31 new tokens, 3 overrides of DS tokens, component patches, CJK type overrides and a Google Fonts `@import`. |
| [`ds-additions/fm-icons.js`](../design/ds-additions/fm-icons.js) | 84 icons merged into the DS icon set at runtime. |
| `Fm*.dc.html` (15 files) | Building blocks: the desktop shell (`FmWindow`), sidebar and panels, Start, Settings, the number field, the phone frame and keyboard, mobile Home and reader, and the artboard frame (`FmBoard`). |
| `Doc*.dc.html` (5 files) | Sample documents drawn as pages: a rental contract, a bank statement, an e-Devlet form, a CV and a floor plan. |
| [`_ds/ferman-design-system-27832349-21bc-410e-acd5-6ab20d2f87e2/`](../design/_ds/ferman-design-system-27832349-21bc-410e-acd5-6ab20d2f87e2/) | The design system: `tokens/` (6 CSS files), `components/` (11 group folders, CSS only), `assets/fonts/` (23 WOFF2 files), `styles.css`, `readme.md`, `_ds_manifest.json`, `_adherence.oxlintrc.json` (declared props and enum values) and `_ds_bundle.js` (compiled components, the icon paths and the unexported desktop kit). |
| `shots/` | 84 preview images captured while the design was made. They are 924 × 540 JPEG data despite the `.png` extension, and they cover only part of the sections. They are not a reference set: M1 renders every artboard into `build/design-refs/` with Playwright (brief §2). |
| [`support.js`](../design/support.js) | The design runtime. It loads React 18.3.1, ReactDOM 18.3.1 and Babel standalone 7.29.0 from unpkg.com each time a page opens. |
| [`Wording for app strings.md`](../design/Wording%20for%20app%20strings.md) | Added by export 519d42a. The strings added or changed on that export's boards, per section file and building block, in English, Turkish and Arabic. Rows marked **ARB** reuse an existing key's text; the others are new wording for the native-speaker review. It also lists three changes to existing strings: the typographic apostrophe in the Turkish `startDropTitle`, the percent sign first in Turkish (%100, [G34](DESIGN_GAPS.md#g34)) and the shortcut table of [G44](DESIGN_GAPS.md#g44). |
| [`github.md`](../design/github.md) | Added by export 519d42a. The design session's sync note: the repository and branch, the time of the last sync, what the session updated (the gap pass, the Turkish and Arabic copy, the Start gating) and a map from the gap boards to the repository files they follow. |
| [`docs/TRANSLATION_REVIEW.md`](../design/docs/TRANSLATION_REVIEW.md) | Added by export 519d42a. An unchanged copy of this repository's [TRANSLATION_REVIEW.md](TRANSLATION_REVIEW.md) as of the M1 merge (aa7ad21), from which the boards took their Turkish and Arabic copy. |
| [`uploads/fulldoc-1792178724997-r3sp.md`](../design/uploads/fulldoc-1792178724997-r3sp.md) | Added by export 519d42a. An unchanged copy of this repository's [DESIGN_GAPS.md](DESIGN_GAPS.md) as of the M1 merge (aa7ad21), before the owner's answers of 2026-10-16 were recorded (f7e04dc). |

**Notes, not references.** The four Markdown files of export 519d42a are notes and wording sources.
They draw nothing, so they are not visual references: the boards are. The app never reads them.
Strings from `Wording for app strings.md` reach the app only through the ARB files, as reviewed
suggestions. The two copies are older than this repository's own files, which stay the reference.

**Not in the export.** Brief §2 cites `design/ui_kits/desktop/index.html` as an example. That file
does not exist, and there is no `ui_kits/` folder anywhere in `design/` ([G01](DESIGN_GAPS.md#g01)). The desktop kit
survives only as compiled, readable code inside `_ds_bundle.js`. Until a re-export, the shell
reference is `FmWindow`, `FmStart`, `FmSidebar`, `FmEditPanel` and `FmSettings`. Also missing:
component sources, type definitions and cards ([G02](DESIGN_GAPS.md#g02)); the `guidelines/` foundation cards,
`thumbnail.html` and `SKILL.md` ([G03](DESIGN_GAPS.md#g03)); the icon SVGs ([G04](DESIGN_GAPS.md#g04)); and every licence text ([G08](DESIGN_GAPS.md#g08)).
Section 10 lists all export gaps. Export 519d42a brought boards for the design gaps but none of these
files, and left `_ds/`, `ds-additions/`, `shots/`, `15 Flows` and the `Doc*` files unchanged. The
owner's answer to [Q11](QUESTIONS.md#q11) expects the missing files with the next design-system
export.

**Canvas conventions.**

- Desktop artboards are 1440 × 900.
- Phones are 393 × 852 (iPhone 16) and 412 × 915 (Pixel). With device chrome the frames are
  417 × 876 and 436 × 939.
- Tablets run the desktop shell at touch density; the iPad portrait board is 1032 px wide.
- Document pages are 794 × 1123, which is A4 at 96 dpi.
- Every artboard sits in an `FmBoard` frame that sets `data-theme`, `lang`, `dir` and `data-density`,
  so theme, language, direction and density are explicit per board. The exception is `a12-0`, a
  table with no frame. On the boards with the language switch, `lang` and `dir` follow the switch.
- Section files open as a pan-and-zoom canvas.

**Index status.** The Index header reads 253 ready and 0 planned. Its 253 rows are 249 artboards plus
the 4 flows. The files hold 4 more artboard ids that the Index does not list (`f4`, `f6`, `a2-3o`,
`a2-3x`), so the files also hold 253 artboards. Every Index link, all 34 flow links and the link to
the additions sheet resolve. A few resolve to the wrong content: flow B's e-imza steps are drawn on
the rental contract instead of the e-Devlet form ([G58](DESIGN_GAPS.md#g58)), and flow C's "Send" and "The file is
signed" steps link to boards that do not show those states. Export 519d42a added a "Design gaps
pass" card to the Index: the boards changed or added for DESIGN_GAPS.md carry their G id as a tag
(G10–G13, G24–G44, G59, G61, G82, G89), a milestone build ("M1 build", "M2 build") sits next to the
drawn board, which stays the shipped state, and the new boards share one EN · TR · AR switch across
the files.

**Coverage.** Each board has one platform and one theme. All but 29 boards have one UI language. The
29 are the boards of export 519d42a except `a12-0`: they carry a board-language switch for English,
Turkish and Arabic, and `tools/design-refs` renders each of them three times, as `<id>.png`,
`<id>.tr.png` and `<id>.ar.png` (58 language variants).

| Platform | Boards | Theme | Boards | UI language | Boards |
|---|---|---|---|---|---|
| macOS | 162 | Light | 234 | English | 211 |
| Windows | 8 | Dark | 18 | English, Turkish and Arabic (switch) | 29 |
| Linux | 0 | Light and dark | 1 | Arabic (right to left) | 6 |
| iOS | 23 | | | Turkish | 3 |
| Android | 20 | | | German | 3 |
| Tablet | 4 | | | Japanese | 1 |
| Web | 3 | | | Persian, Hebrew | 0 |
| Spec sheet | 33 | | | | |

A spec sheet is a component or panel drawn on its own, without a window. The 33 include the eight
bare dialogs (`a5-3b`, `a5-3c`, `a5-5b`, `a5-6b`, `a5-6c`, `a5-6d`, `a5-6e`, `a9-4`), which the
design labels "Dialog · light" and draws over a scrim with no window chrome. The tables call them
"Dialog (spec sheet)". Six spec sheets came with export 519d42a: the six empty sidebars of `a2-3m`,
the edit panels of `a3-17`, the page snippets and panels of `a3-18`, the review panel and dialogs of
`a3-12b`, the four save errors of `a11-7d` and the region-format table `a12-0`. The UI language is
the language of the chrome and the notes: `f3` is English, although its page specimens are Turkish
text. The language switch changes the chrome and the copy; the captions stay in English and the
documents keep their own language and direction.

Linux is not drawn at all ([G15](DESIGN_GAPS.md#g15)). Windows, dark, right-to-left and Turkish coverage is thin for the
screens that M1 to M4 ship ([G16](DESIGN_GAPS.md#g16), [G17](DESIGN_GAPS.md#g17), [G18](DESIGN_GAPS.md#g18), [G19](DESIGN_GAPS.md#g19)). The 29 switchable boards add Turkish and
right-to-left Arabic for the M1 builds and the new M2 and M3 states. They add one Windows board
(`a11-1w-m1`) and no dark board.

## 3. Section overview

One row per section file. "Milestones" counts the boards in the file by primary milestone.

| File | Title | Artboards | Milestones |
|---|---|---|---|
| [`00 Fixes`](../design/00%20Fixes.dc.html) | Fixes to the current editor kit | 9 | M1 2 · M2 1 · M3 6 |
| [`01 First run and files`](../design/01%20First%20run%20and%20files.dc.html) | First run, start and file handling | 28 | M1 6 · M2 17 · M3 5 |
| [`02 View`](../design/02%20View.dc.html) | View mode | 30 | M2 23 · M3 1 · P2 5 · P4 1 |
| [`03a Edit text`](../design/03a%20Edit%20text.dc.html) | Edit mode — text | 14 | M3 14 |
| [`03b Edit content`](../design/03b%20Edit%20content.dc.html) | Edit mode — content | 10 | M3 2 · M4 1 · P2 7 |
| [`03c Edit review and translate`](../design/03c%20Edit%20review%20and%20translate.dc.html) | Edit mode — scans, review, translation, languages | 6 | M3 3 · P3 1 · P4 2 |
| [`04 Comment`](../design/04%20Comment.dc.html) | Comment mode | 9 | M4 8 · P4 1 |
| [`05a Fill`](../design/05a%20Fill.dc.html) | Fill & Sign — filling forms | 9 | M4 9 |
| [`05b Sign`](../design/05b%20Sign.dc.html) | Fill & Sign — digital signatures and forms | 15 | P3 13 · P4 2 |
| [`06 Organize`](../design/06%20Organize.dc.html) | Organize | 6 | M4 6 |
| [`07 Convert`](../design/07%20Convert.dc.html) | Convert | 6 | P3 6 |
| [`08 Protect`](../design/08%20Protect.dc.html) | Protect | 6 | P2 6 |
| [`09a Tools`](../design/09a%20Tools.dc.html) | Tools — compress, compare, accessibility, standards | 7 | M4 1 · P3 2 · P4 4 |
| [`09b Tools`](../design/09b%20Tools.dc.html) | Tools — batch, print, measure, history | 8 | M4 2 · P4 3 · P5 3 |
| [`10 AI assistant`](../design/10%20AI%20assistant.dc.html) | AI assistant | 3 | P4 3 |
| [`11a Settings`](../design/11a%20Settings.dc.html) | Settings | 15 | M1 6 · M3 1 · M4 5 · M5 1 · P3 1 · P4 1 |
| [`11b App`](../design/11b%20App.dc.html) | App-level | 13 | M2 1 · M3 5 · M4 4 · M5 3 |
| [`12 Localization`](../design/12%20Localization.dc.html) | Localization validation | 14 | M1 4 · M2 1 · M3 4 · P5 5 |
| [`13a Mobile core`](../design/13a%20Mobile%20core.dc.html) | Mobile — start, files, reading, editing | 20 | P5 20 |
| [`13b Mobile tasks`](../design/13b%20Mobile%20tasks.dc.html) | Mobile — sign, scan, organize, protect, share | 18 | P5 18 |
| [`14 Tablet and web`](../design/14%20Tablet%20and%20web.dc.html) | Tablet and web | 7 | P5 7 |
| **Total** | | **253** | |

The other files are not artboards: `15 Flows` (4 flows), `DS additions` (26 additions), `Index`, the
15 `Fm*` building blocks, the 5 `Doc*` sample documents and the four Markdown notes of export 519d42a
(section 2).

## 4. Milestones

Counts are primary milestones, so each board is counted once.

| Code | Scope in brief §7 | Boards | Set by Q10 | What the boards cover |
|---|---|---|---|---|
| M0 | Discovery and plan (docs only) | 0 | 0 | No boards. This inventory is part of M0. |
| M1 | Foundations | 18 | 0 | Windows chrome and the shell (`f6`, `f6a`), the language picker and two welcome screens, the empty Start screen, the Settings skeleton (General on macOS and Windows, Language and region) and the Arabic and German Start and Settings boards that check localization and right to left; the M1 builds of the last welcome step, the empty Start screen, Settings General on macOS and Windows and Settings Privacy (`a1-2c-m1`, `a1-5-m1`, `a11-1-m1`, `a11-1w-m1`, `a11-1h-m1`). |
| M2 | Open and view | 43 | 1 | The default-app prompt, Start with recent files and its M2 build, drag and drop, the system open panel, a large file, password unlock, repair, open errors (not a PDF, read-only, a missing recent file, out of memory), tab overflow, the four page layouts and zoom, tiles that sharpen, a page that fails to render and Go to page, right-to-left spreads, the sidebar tabs (pages, outline, attachments, layers, search results) and their empty states, find with a long search and no results, document properties with the Security tab, restricted PDFs, signatures before validation, the XFA notice, the thumbnail badge legend and the region-format table. |
| M3 | Edit text core | 41 | 0 | Hover, caret, selection and reflow; the text-block panel; missing glyph and font substitution, and every outcome of the missing-glyph steps; overflow, its results and the choices that cannot apply; text that cannot be edited; the warning before editing a signed document and its banner; table-aware, per-block-language and vertical Japanese editing; undo history and the review list with its empty and confirm states; fixes `f1` to `f4b`; Save as, also with a folder from the system panel, closing with unsaved changes, quitting with several, crash recovery, also when the original changed, disk-full, changed-on-disk and the other save errors; Settings → Editing; the Signatures tab used by the signed-document warning; the editor in Turkish, German, Arabic and Japanese. |
| M4 | Rest of phase 1 | 36 | 1 | Comment mode, form filling and simple signatures, Organize, links, Compress, basic print, version history, the command palette and shortcuts, toasts, the task drawer and the remaining Settings panes. |
| M5 | Release pipeline | 4 | 0 | Settings → Updates, the update-ready banner, What's new and About. |
| P2 | Phase 2 | 18 | 5 | Adding text and images, find and replace, watermark, header and footer, Bates numbering, page background, redaction with verification, removing hidden information, passwords and the security report, plus the viewer extras placed by Q10: presentation, reading mode, split view and inverted dark reading. |
| P3 | Phase 3 | 23 | 0 | OCR, conversion, scan to PDF, certificate signatures, Turkish e-imza, signature validation, compare and Settings → Text recognition. |
| P4 | Phase 4 | 17 | 3 | Form authoring, PDF/A and preflight, accessibility tools, batch actions, in-place translation and the local AI assistant, plus read aloud and measuring, placed by Q10. |
| P5 | Phase 5 | 53 | 0 | Print production (booklet, poster, separations), the web app, tablets, and the iOS and Android apps with their Arabic and Turkish checks. |
| | **Total** | **253** | **10** | |

**Milestones set by Q10.** Ten boards show features the roadmap does not name. The owner accepted the
proposed milestones on 2026-10-16 ([Q10](QUESTIONS.md#q10), [G33](DESIGN_GAPS.md#g33)):

- layers (`a2-3c`) → M2, because layer visibility is part of rendering;
- presentation (`a2-5a`), reading mode (`a2-5b`), split view (`a2-8a`, `a2-8b`) and inverted dark
  reading (`a2-9`) → P2;
- read aloud (`a2-6`) and measuring (`a4-1c`, `a9-7`) → P4;
- basic system print (`a9-6`) → M4.

Booklet (`a9-6b`), poster (`a9-6c`) and separations (`a9-6d`) go to P5, where the brief puts print
production. Mobile night mode and read aloud (`a13-4d`) and iPad split view (`a14-1c`) go to P5 with
the mobile and tablet apps. The owner confirmed both with [Q10](QUESTIONS.md#q10).

A few more drawn features are not named in the roadmap and take the nearest roadmap item. They are
part of [Q10](QUESTIONS.md#q10) as well:

- crash recovery (`a1-12`), per-block language (`a3-14`) and the German and Japanese editors
  (`a12-1de`, `a12-1ja`) → M3;
- vertical Japanese editing (`a3-15`) → M3, as a candidate to defer;
- links (`a3-6`) and the shortcut cheat sheet (`a11-3`) → M4;
- What's new (`a11-4b`) → M5;
- page background (`a3-8d`), passwords (`a8-1`) and the security report (`a8-4`) → P2.

Until a feature ships, its entry points stay visible exactly as designed but disabled, with the
tooltip "Available in a future version" and an entry in [BACKLOG.md](BACKLOG.md) (brief §6).

### Decisions that change or confirm what the boards show

- **Licence.** `a1-2c` and `a11-5` said GPL-3.0-or-later. Export 519d42a changed both to Apache-2.0,
  as the brief requires, and `a1-2c-m1` says Apache-2.0 too ([G13](DESIGN_GAPS.md#g13)).
- **Later-phase features.** `a1-2c` marks every feature as included, and Start shows the later quick
  tools as active. In the app, features that have not shipped are shown disabled with the tooltip
  "Available in a future version", not as "Included" ([G10](DESIGN_GAPS.md#g10), [G11](DESIGN_GAPS.md#g11), [G12](DESIGN_GAPS.md#g12)). Export 519d42a draws this
  in its milestone builds: `a1-2c-m1` keeps the check only on the interface-languages tile, and
  `a1-5-m1` and `a1-4-m2` disable every card and quick tool whose feature has not shipped.
- **Network uses.** `a1-2b` named only the update check. Export 519d42a adds the other three uses the
  brief allows (OCR language packs, the AI assistant and signature timestamps, each off until used)
  and a link to Settings → Privacy. The app's onboarding lists all four and points to Settings →
  Privacy ([G24](DESIGN_GAPS.md#g24)).
- **Extra network uses.** OCSP/CRL revocation lookups (`a11-1h` and the signing boards) and
  local-network scanner discovery and phone pairing (`a7-4`) are not in the brief. The owner decided
  on 2026-10-16 ([Q06](QUESTIONS.md#q06)): revocation lookups are allowed, off until first use, with their own switch in
  Settings → Privacy and an entry in the network log (phase 3); Scan to PDF offers only the scanners
  the operating system provides, with no local-network discovery and no phone pairing ([G51](DESIGN_GAPS.md#g51), [G56](DESIGN_GAPS.md#g56)).
  The captions of `a1-2b` and `a11-1h-m1` still leave revocation out "until the owner decides"; they
  predate the answer.
- **Mode tabs.** The app has the eight modes the artboards draw: View, Edit, Comment, Fill & Sign,
  Organize, Convert, Protect, Tools. The DS constant `FERMAN_MODES` lists seven and is stale
  ([G09](DESIGN_GAPS.md#g09), [Q05](QUESTIONS.md#q05)). The brief does not enumerate the modes.
- **Missing glyph.** The design is not silent. It says so once, marks the glyph and offers
  "Choose a font…" or "Keep as is", and Settings → Editing (`a11-1c`) offers "Ask each time". The app
  keeps this as drawn, behind the three-step policy in
  [ADR 0006](adr/0006-font-pipeline-and-missing-glyphs.md): embedded glyph first, then the same font
  if it is installed (take the glyph, re-subset, embed and say so), then the design's similar-font
  flow ([G36](DESIGN_GAPS.md#g36), [Q09](QUESTIONS.md#q09)).
- **Formats.** Numbers, dates, paper sizes and units follow the region setting, never the UI language
  ([G34](DESIGN_GAPS.md#g34)). Export 519d42a draws the rule as the region-format table `a12-0` (from CLDR, with the
  region the goldens use for each language) and reads boards that show another format as drawn for
  another region.
- **Search.** `a2-4a` drew "Ignore accents and dotted/dotless i" as on by default for Turkish
  documents only. Since export 519d42a it is on by default for every document, as brief §7 requires,
  and the description ends "On by default." ([G61](DESIGN_GAPS.md#g61)).

## 5. Artboards

Each row gives the id, the screen (title, then platform · theme · UI language), the feature and the
states drawn, the milestone and the engine capability. **Bold** is the primary milestone; the text
after the dash is nuance, such as parts that land in another milestone. Boards whose milestone text
starts with "proposed" show features the roadmap does not name; the owner accepted those milestones
with [Q10](QUESTIONS.md#q10). The rows of the 30 boards that export 519d42a added give `en, tr, ar` as the UI language
when the board carries the language switch, and link the design gaps the board answers.

### 00 · Fixes to the current editor kit

Source: `design/00 Fixes.dc.html` · 9 artboards. Six problems found in the editor kit, fixed in the design system (ds-additions/fm-additions.css tokens/patches) before any other screen was drawn, so every artboard uses the corrected version.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `f1` | The text-frame label never covers content<br>Spec sheet · light · en | Placement of the font · size tab on a selected text frame: above, then below, then page margin<br>*States:* before: label above covering IBAN line; after: flipped below; after: in page margin (heading above, IBAN below) | **M3** | ferman-text, ferman-fonts, ui-only |
| `f2` | The missing-glyph warning appears once<br>Spec sheet · light · en | Missing-glyph warning in Edit panel: amber icon in font field, single warning callout with way out<br>*States:* before: warning under font field and in banner (duplicate); after: amber-bordered font field + Banner 'Missing character' + actions; Edited badge in panel header | **M3** | ferman-fonts, ferman-text |
| `f3` | Edited text and highlights look different<br>Spec sheet · light · en | Edit marking (dotted underline + left margin bar, accent ink) vs highlight annotation (translucent marker)<br>*States:* edited text marking; highlight annotation (yellow); both on same line | **M3** — highlight annotation M4 | ferman-text, ferman-ops, ui-only |
| `f4` | Save state is always honest<br>macOS · light · en | Save button / tab dot / status bar save states and save-failure toast<br>*States:* Unsaved (Save enabled, amber dot); Saving (button loading, spinner); Saved (Save disabled, 'Saved on this device · 14:32'); Couldn’t save (danger); error Toast with Save as… action | **M3** | ferman-core, platform, ui-only |
| `f4a` | Main editor — unsaved changes<br>macOS · light · en | Main editor in Edit mode with unsaved edits; selected edited text block with label in margin<br>*States:* save=unsaved; tab dot on active tab; text block p4 selected + edited; meta label in margin | **M3** | ferman-core, ferman-text, ferman-render, ferman-fonts |
| `f4b` | Main editor — saved<br>macOS · light · en | Main editor after save: Save disabled, no tab dot, status 'Saved on this device · 14:32'<br>*States:* save=saved; saved-at=14:32; edit marks retained; no selection | **M3** | ferman-core, ferman-text |
| `f5` | Thumbnail badges have a legend<br>Spec sheet · light · en | Five page-thumbnail badges (edited, comments, form fields, signature, warnings) with legend popover and tooltips<br>*States:* legend popover open; badge tooltip open/focused; badges stacked top-end in fixed order | **M2** — thumbnails; edited/warning badges M3, others with M4 features | ferman-render, ferman-core, ferman-fonts, ui-only |
| `f6` | Windows window chrome<br>Windows · light · en | Platform layer for window chrome: Windows caption buttons vs macOS traffic lights<br>*States:* macOS title bar; Windows title bar | **M1** | platform, ui-only |
| `f6a` | Main editor<br>Windows · light · en | Main editor on Windows 11 with unsaved edits<br>*States:* save=unsaved; text block p4 selected + edited; meta label in margin | **M1** — (shell); edit content M3 | platform, ui-only |

### 01 · First run, start and file handling

Source: `design/01 First run and files.dc.html` · 28 artboards. Desktop, 1440 × 900. Language and onboarding, the start screen in light, dark and Windows, and every state a file can arrive in: large, locked, damaged, many at once, unsaved, restored. Export 519d42a added nine boards with the EN/TR/AR switch: the M1 builds of the last welcome step and the empty Start screen, the M2 build of Start, four open errors (not a PDF, read-only, a missing recent file, out of memory), the system open panel and Save as with a folder chosen in the system panel.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a1-1` | First run — Language picker<br>macOS · light · en | First-run app language selection (21 languages, native names, RTL rows)<br>*States:* English preselected as system language; keyboard focus ring on Türkçe; 2-column radiogroup of 21 languages; ar/fa/he rows dir=rtl | **M1** | ui-only, platform |
| `a1-3` | First run — Default PDF app<br>macOS · light · en | Offer to become the default PDF handler (file association)<br>*States:* prompt shown once after onboarding; Opens PDFs now: Preview → Ferman; "Don't ask again" unchecked | **M2** | platform |
| `a1-2a` | Welcome 1 of 3 — Edit any PDF like a document<br>macOS · light · en | Onboarding step 1: in-place text editing pitch with live editing specimen (Turkish contract)<br>*States:* step 1 of 3; TextEditBox editing with caret, edited PageMark on "19.500 TL", meta "IBM Plex Serif · 10.5 pt" | **M3** | ui-only, ferman-text, ferman-fonts |
| `a1-2b` | Welcome 2 of 3 — Everything stays on your device<br>macOS · light · en | Onboarding step 2: privacy facts (local files, offline, no account, no telemetry) and the network uses: the optional update check, then OCR language packs, the AI assistant and signature timestamps, each off until used ([G24](DESIGN_GAPS.md#g24), since 519d42a)<br>*States:* step 2 of 3; 8 rows; link 'See every connection in Settings › Privacy' | **M1** — reads "1 of 2" until the editor ships in M3 (`a1-2c-m1`) | ui-only |
| `a1-2c` | Welcome 3 of 3 — Free forever, nothing locked<br>macOS · light · en | Onboarding step 3: free/open-source statement, licence (Apache-2.0 since 519d42a, [G13](DESIGN_GAPS.md#g13)), included-features grid<br>*States:* step 3 of 3, no Skip; 10 features each with green 'Included' check | **M1** — through its M1 build `a1-2c-m1`; this board stays the finished product, and each tile gets its check when its feature ships ([G12](DESIGN_GAPS.md#g12)) | ui-only |
| `a1-2c-m1` | Welcome 2 of 2 — Free forever, M1 build<br>macOS · light · en, tr, ar | The M1 build of `a1-2c`: the same step with only the shipped feature included ([G10](DESIGN_GAPS.md#g10), [G12](DESIGN_GAPS.md#g12), [G13](DESIGN_GAPS.md#g13))<br>*States:* step 2 of 2 (announced "Step 2 of 2"); licence Apache-2.0; Source code and Support the project disabled until the app opens web pages; '3 interface languages' tile with the green check; the other 9 tiles disabled with a clock, the future-version tooltip shown on the focused Text recognition tile; labels wrap; Back, Start using Ferman | **M1** | ui-only |
| `a1-4` | Start — Recent documents, grid<br>macOS · light · en | Start screen: actions, quick tools, drop strip, pinned, recent grid with badges<br>*States:* Home tab active (wordmark) + 2 doc tabs; 3 pinned; 10 recents with Edited/Form/Signed/Scanned badges; grid view, sort Last opened | **M2** — through its M2 build `a1-4-m2`; this board stays the finished product | ferman-render, ferman-core, platform, ui-only |
| `a1-4b` | Start — Recent documents, grid<br>macOS · dark · en | Start screen grid in dark theme<br>*States:* dark theme; same content as 1.4a | **M2** | ferman-render, ui-only |
| `a1-4c` | Start — Recent documents, list<br>Windows · light · en | Start screen recent list view with columns<br>*States:* list view; columns Name, Location, Pages, Last opened, badge; Ctrl shortcuts | **M2** | ferman-core, platform, ui-only |
| `a1-4-m2` | Start — Recent documents, M2 build<br>macOS · light · en, tr, ar | The M2 build of `a1-4`: opening and dropping PDFs work, everything later is disabled ([G10](DESIGN_GAPS.md#g10), [G11](DESIGN_GAPS.md#g11), [G31](DESIGN_GAPS.md#g31), [G59](DESIGN_GAPS.md#g59))<br>*States:* Open file… enabled; Create PDF, Combine files and Scan to PDF disabled (tooltip on Create PDF); all six quick tools disabled; drop strip 'PDF files open in tabs.'; neutral Signed chip with no check and no green; e-Devlet form listed as 1 page | **M2** — Create PDF and Combine files M4, Scan to PDF P3; the green Signed badge with P3 validation | ferman-render, ferman-core, platform, ui-only |
| `a1-5` | Start — Empty state<br>macOS · light · en | Empty start screen with drop zone<br>*States:* no recents, no pins, no tabs; DropZone with open/create and ⌘O | **M1** — through its M1 build `a1-5-m1`; this board stays the finished product, which opens files from M2 | ui-only, platform |
| `a1-6` | Start — Files dragged over the window<br>macOS · light · en | Multi-file drag-and-drop with two targets: open in tabs vs combine<br>*States:* 3 files dragged (PDF, .xlsx, .jpg); "Open in 3 tabs" target under pointer (accent ring); per-file handling notes | **M2** | platform, ferman-ops, jobs |
| `a1-5-m1` | Start — Empty state, M1 build<br>macOS · light · en, tr, ar | The M1 build of `a1-5`: no file picker yet, so every entry point is visible and disabled ([G10](DESIGN_GAPS.md#g10), [G11](DESIGN_GAPS.md#g11))<br>*States:* no recents, no pins, no tabs; all four action cards, the quick tools and the drop-area buttons disabled with the future-version tooltip and accessible hint (shown on the focused Open file card); disabled card keeps frame and small shadow, sunken icon tile, key cap kept; copy speaks of PDF files only ('PDF files', 'or open one from your computer.') | **M1** | ui-only |
| `a1-7` | Opening a large file<br>macOS · light · en | Progressive open of a 2,400-page PDF with read-while-indexing<br>*States:* tab loading spinner; page 1 rendered, page 2 spinner; TaskProgress 35% with Cancel; info banner; status bar mirrors task; sidebar hidden | **M2** | ferman-core, ferman-render, ferman-text, jobs |
| `a1-8` | Password-protected PDF — Unlock<br>macOS · light · en | Password unlock for encrypted PDF<br>*States:* locked tab with lock icon; password field autofocused; Show password unchecked | **M2** | ferman-core |
| `a1-8b` | Password-protected PDF — Wrong password<br>macOS · light · en | Wrong password error with Turkish keyboard hint<br>*States:* field error, attempt kept selected; no lockout | **M2** | ferman-core |
| `a1-9` | Damaged PDF — Repaired<br>macOS · light · en | Auto-repair notice with plain-language repair list<br>*States:* tab with wrench icon, unsaved; banner bar with Details / Save repaired copy…; "What Ferman repaired" popover: xref rebuilt, non-embedded font substituted | **M2** | ferman-core, ferman-fonts, ferman-render |
| `a1-9b` | Damaged PDF — Can’t be opened<br>macOS · light · en | Unrecoverable file error (truncated download)<br>*States:* tab with file-x icon; error with cause, actions, mono technical details | **M2** | ferman-core, platform |
| `a1-9c` | Not a PDF — error tab<br>macOS · light · en, tr, ar | A file that is not a PDF (an Excel file here) opens as an error tab with the DropZone error variant and the voice line "That file isn't a PDF." ([G28](DESIGN_GAPS.md#g28), [G11](DESIGN_GAPS.md#g11))<br>*States:* active tab 'Ek-1 Demirbaş listesi.xlsx' with file-x icon; Open another file… (primary); Show in Finder; Convert to PDF… disabled with the future-version tooltip; Word, Excel and image files get this state until conversion ships | **M2** — conversion P3 | ferman-core, platform |
| `a1-9d` | Read-only file<br>macOS · light · en, tr, ar | A read-only or permission-denied file opens read-only, as in `a11-7c` ([G28](DESIGN_GAPS.md#g28), [G41](DESIGN_GAPS.md#g41))<br>*States:* lock on the tab; info banner '"Kira sözleşmesi.pdf" is read-only.' with Save a copy…; Read-only in the status bar; Save disabled with the tooltip 'Read-only'; later View tools disabled | **M2** — Save a copy… needs saving, so M3 | ferman-core, platform, ferman-render |
| `a1-9e` | Recent file is missing<br>macOS · light · en, tr, ar | Opening a recent file that was moved, renamed or deleted ([G28](DESIGN_GAPS.md#g28), [G26](DESIGN_GAPS.md#g26))<br>*States:* dialog over the M2 Start screen naming the file and where it was; Remove from list; Locate… (primary) opens the system open panel and updates the recent entry; nothing else changes on disk | **M2** | platform, ui-only |
| `a1-9f` | Out of memory — one tab closed<br>macOS · light · en, tr, ar | A document that runs out of memory or fails beyond recovery closes only its own tab ([G28](DESIGN_GAPS.md#g28), [ADR 0010](adr/0010-error-handling-no-panics.md))<br>*States:* the large file's tab gone, two tabs left; danger toast '"İmar planı açıklama raporu.pdf" was closed' at the bottom end of the canvas, above the status bar, with Try again (reopens the file); other documents keep working | **M2** | ferman-core, ferman-render, ui-only |
| `a1-13` | Open file — system open panel<br>macOS · light · en, tr, ar | ⌘O, "Open file…" and "Open a PDF" hand off to the system open panel; files from the OS open in the running window ([G25](DESIGN_GAPS.md#g25), [G26](DESIGN_GAPS.md#g26))<br>*States:* placeholder for the panel over the M2 Start screen (NSOpenPanel, IFileOpenDialog or the Linux desktop portal, in the system's language; PDF files, several at once); the caption adds: each file opens as a new active tab, one instance per user, a file already open focuses its tab, a cold launch with a file skips Start | **M2** — the caption's "pending Q07" predates the answer of 2026-10-16 ([ADR 0018](adr/0018-native-file-pickers.md) is Accepted) | platform |
| `a1-10` | Many documents — tab overflow<br>macOS · light · en | Document tab overflow (+4 menu) and tab navigation<br>*States:* 6 visible tabs shrunk, "+4"; menu open with shortcuts ⌘7–⌘9; unsaved markers | **M2** | ui-only, platform |
| `a1-10b` | Close with unsaved changes<br>macOS · light · en | Unsaved-changes prompt on close<br>*States:* macOS button order: Don't save \| Cancel, Save (default) | **M3** | ferman-core, ui-only |
| `a1-11` | Save as — formats and options<br>macOS · light · en | Save as with format choice (PDF, PDF/A-2b, web-optimized) and options<br>*States:* PDF selected; Save as a copy unchecked; Include comments checked; Remove edit history checked | **M3** | ferman-core, ferman-ops, ferman-fonts, platform |
| `a1-12` | Crash recovery — restored documents<br>macOS · light · en | Crash recovery of autosaved unsaved documents<br>*States:* 2 documents listed, both checked; Discard / Open 2 documents; Copy crash log | **M3** | ferman-core, platform |
| `a1-11b` | Save as — folder chosen in the system panel<br>macOS · light · en, tr, ar | "Other location…" in Where hands off to the system save panel; afterwards the sheet shows the chosen folder ([G26](DESIGN_GAPS.md#g26), [G10](DESIGN_GAPS.md#g10))<br>*States:* file name 'Kira sözleşmesi — son hâli.pdf'; Where = the chosen folder, named in the copy line too; format PDF selected, PDF/A-2b disabled with the reason in its line, Optimized for web; Save as a copy unchecked; Include comments and Remove edit history checked | **M3** — PDF/A-2b P4 | ferman-core, platform |

### 02 · View mode

Source: `design/02 View.dc.html` · 30 artboards. Page layouts, zoom, every sidebar tab, search with Turkish-aware matching, presentation and reading modes, read aloud, document properties, split view and dark reading mode. The 22 artboards of the first export are lang=en: the seven sidebar tab cards (a2-3p to a2-3x) are 1:1 spec sheets and the other 15 are macOS. All are light except the dark sidebar panel (a2-3x), presentation (black surround) and dark reading (a2-9). Export 519d42a added eight light boards with the EN/TR/AR switch: the empty sidebar tabs (a2-3m, six sidebars side by side, a spec sheet), a long search and no results (a2-4c, a2-4d), restricted PDFs and the Security tab (a2-10a, a2-10b), rendering states and Go to page (a2-13), signatures before validation (a2-14) and a right-to-left spread (a2-15), all macOS but a2-3m.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a2-1a` | View — Single page, fit page<br>macOS · light · en | Single-page layout with Fit page zoom (66%)<br>*States:* layout=single; fit=page; zoom 66%; saved; 3 tabs, Kira active | **M2** | ferman-render, ui-only |
| `a2-1b` | View — Continuous scroll<br>macOS · light · en | Continuous scroll layout, current page tracking<br>*States:* layout=scroll; page 2 of 3; thumbnail selection follows (current=2); saved | **M2** | ferman-render, ui-only |
| `a2-1c` | View — Two-page spread<br>macOS · light · en | Two-page spread layout at 55%<br>*States:* layout=two; fit=page; zoom 55% | **M2** | ferman-render, ferman-core |
| `a2-1d` | View — Book mode with cover page<br>macOS · light · en | Book layout: cover alone, then i–ii/ii–iii spreads; 64-page Turkish thesis<br>*States:* layout=book; fit=page; zoom 55%; pages=64; page labels i, ii, iii, 1, 2 in thumbnails | **M2** | ferman-render, ferman-core |
| `a2-2` | View — Zoom menu and marquee zoom<br>macOS · light · en | Zoom presets menu, fit modes, marquee zoom tool<br>*States:* tool=marquee; zoom menu open (100% checked); marquee drag rectangle with zoom label | **M2** | ferman-render, ui-only |
| `a2-3a` | Sidebar — Outline: nested bookmarks, renaming<br>macOS · light · en | Outline tab with nested thesis bookmarks, inline rename of '3. BULGULAR'<br>*States:* outline-edit row (TextField); unsaved tab (tabsTezU); page 27 of 64; current section tinted | **M2** — (view outline); rename/add/reorder bookmarks needs save, so M3 | ferman-core |
| `a2-3p` | Sidebar — Pages tab (1:1)<br>Spec sheet · light · en | Thumbnails with page badges (edited, comments, form fields, signature, warnings)<br>*States:* page 1 selected; badges: p1 edited+comments+warning, p3 fields+signed; count 3 | **M2** — (thumbnails); badges arrive with their features (edited/warn/signed M3, comments/fields M4) | ferman-render, ferman-core |
| `a2-3o` | Sidebar — Outline tab (1:1)<br>Spec sheet · light · en | Outline of the rental contract (Madde 1–8, nested 4.1/4.2)<br>*States:* current row tinted (Madde 4); expanded parent | **M2** | ferman-core |
| `a2-3b` | Sidebar — Attachments tab (1:1)<br>Spec sheet · light · en | Embedded file list with save-as; attach-a-file action<br>*States:* 3 attachments (xlsx, jpg, pdf) | **M2** — 'Attach a file' is unlisted in the roadmap (writes the file, so M3 or later) | ferman-core, platform |
| `a2-3c` | Sidebar — Layers tab (1:1)<br>Spec sheet · light · en | Optional content layers with show/hide and locked state<br>*States:* visible; hidden (Filigran — TASLAK); locked (İmzalar) | **M2** — proposed: layers (OCG) visibility is part of rendering | ferman-core, ferman-render |
| `a2-3d` | Sidebar — Signatures tab (1:1)<br>Spec sheet · light · en | Signature list with validity sentence and empty signature field<br>*States:* valid e-imza signature; empty signature field (page 3) | **M3** — (detect and list signatures for the signed-document warning); validity statement needs P3 signature validation; until then the tab shows the neutral state of `a2-14` (M2) | ferman-core, ferman-ops |
| `a2-3e` | Sidebar — Search results tab (1:1)<br>Spec sheet · light · en | Search results grouped by page with snippets<br>*States:* 7 matches on 2 pages; current result tinted; whole-word miss example | **M2** | ferman-text |
| `a2-3x` | Sidebar — Outline rename, dark (1:1)<br>Spec sheet · dark · en | Outline inline rename in dark theme<br>*States:* outline-edit=3 (Madde 4 row as TextField); dark | **M2** — (outline, dark theme from M1); rename needs save, so M3 | ferman-core |
| `a2-3m` | Sidebar — Empty tabs and searches with no result<br>Spec sheet · light · en, tr, ar | One EmptyState for every empty sidebar tab and search state: a 40 px sunken icon tile, a title, one line, an optional action ([G29](DESIGN_GAPS.md#g29), [G10](DESIGN_GAPS.md#g10))<br>*States:* six sidebars side by side: Outline, Attachments, Layers and Signatures empty; Search with no result for 'depozito'; Search on scanned pages with no text layer, Recognize text (OCR) disabled with the future-version tooltip | **M2** — OCR P3 | ferman-core, ferman-text, ui-only |
| `a2-4a` | Search — Find bar with options<br>macOS · light · en | Find bar with match options and Turkish-aware accent/dotted-i folding<br>*States:* query 'kira', 1 of 7; matches highlighted (current orange, others yellow); Ignore accents on; Look in: Page text + Comments on | **M2** — find/replace bar's replace is P2; the accent option is on by default for every document, as the board says since 519d42a ([G61](DESIGN_GAPS.md#g61)) | ferman-text, ferman-core |
| `a2-4b` | Search — All results, grouped by page<br>macOS · light · en | Show all results in sidebar, grouped by page<br>*States:* sidebar tab=search; current result tinted; matches highlighted on page | **M2** | ferman-text |
| `a2-4c` | Search — still searching a long file<br>macOS · light · en, tr, ar | A search that takes more than a moment shows its progress under the find bar, as the large-file open does in `a1-7` ([G29](DESIGN_GAPS.md#g29))<br>*States:* 2,400-page file, query 'otopark', 1 of 38 so far; 'Searching · page 840 of 2,400', 'Matches appear as they're found.', progress bar, Cancel (Esc); matches found so far highlighted, so ↵ already works; sidebar and panel hidden | **M2** | ferman-text, jobs |
| `a2-4d` | Search — no results<br>macOS · light · en, tr, ar | No results says what was searched and how, and offers the next place to look ([G29](DESIGN_GAPS.md#g29))<br>*States:* query 'depozito' kept selected; count 'No results' in the danger text colour; 'Ferman searched all 3 pages, ignoring accents and dotted/dotless i. Comments and form fields weren't searched.'; action Also search comments and fields | **M2** | ferman-text |
| `a2-5a` | Presentation mode, full screen<br>macOS · dark · en | Full-screen presentation with auto-hiding control bar<br>*States:* page 1 / 3; control bar visible | **P2** — proposed: viewer extras after phase 1 (presentation mode) | ferman-render, platform |
| `a2-5b` | Reading mode, chrome hidden<br>macOS · light · en | Reading mode hides tabs, tool rows, sidebar, panel and status bar<br>*States:* bare window; floating reading toolbar visible | **P2** — proposed: viewer extras after phase 1 (reading mode) | ui-only, ferman-render |
| `a2-6` | Read aloud<br>macOS · light · en | Text-to-speech with sentence highlighting, speed and voice<br>*States:* playing (Pause shown); Sentence 9 of 31; speed 1×; voice Yelda · Türkçe | **P4** — proposed: read aloud grouped with accessibility tools | ferman-text, platform |
| `a2-7` | Document properties<br>macOS · light · en | Properties dialog: metadata summary and font embedding status<br>*States:* Summary tab; fonts: Embedded / Subset / Not embedded with substitute | **M2** — (properties view); in-place metadata editing needs save, so M3; font status ties to M3 font handling | ferman-core, ferman-fonts |
| `a2-8a` | Split view — same document, two places<br>macOS · light · en | Split view of one document (page 1 and page 3) with independent zoom<br>*States:* tool=split; left pane active (accent outline); right panel hidden | **P2** — proposed: viewer extras after phase 1 (split view) | ferman-render, ui-only |
| `a2-8b` | Split view — two documents<br>macOS · light · en | Split view of two open documents with per-pane document picker<br>*States:* sidebar and panel hidden; right pane active; Scroll together off | **P2** — proposed: viewer extras after phase 1 (split view) | ferman-render, ui-only |
| `a2-9` | Dark reading mode — inverted page<br>macOS · dark · en | Dark reading: page inverted with hue kept, images and signatures re-inverted<br>*States:* dark theme; dark-reading switch on; annotations visible | **P2** — proposed: viewer extras after phase 1 (inverted dark reading) | ferman-render |
| `a2-10a` | Restricted PDF — permissions<br>macOS · light · en, tr, ar | A document with an owner password or permission flags opens with a banner that names the restriction ([G27](DESIGN_GAPS.md#g27))<br>*States:* tab with shield icon; banner 'The author restricted this document.' ('You can read and print it. Editing, comments and form filling are turned off.') with Unlock with owner password…; forbidden modes and tools disabled with the reason ('The author doesn't allow editing'); a certificate-encrypted PDF gets the open error of `a1-9b` | **M2** — the reason tooltip on the Edit tab from M3 (the future-version tooltip before); certificate encryption P3 | ferman-core, ui-only |
| `a2-10b` | Document properties — Security tab<br>macOS · light · en, tr, ar | The Security tab of `a2-7`, in the Summary tab's layout ([G27](DESIGN_GAPS.md#g27))<br>*States:* Encryption 'AES-256 · owner password'; Password to open 'None'; 8 permissions, each a badge: Allowed (green, check) for printing (high quality), copying and screen-reader access, Not allowed (neutral) for the other five; Unlock with owner password… and Done | **M2** | ferman-core |
| `a2-13` | Rendering — tiles sharpening, a page that failed, Go to page<br>macOS · light · en, tr, ar | Tiles draw at low resolution first and sharpen in place; a page that fails to render keeps the rest of the document working ([G30](DESIGN_GAPS.md#g30))<br>*States:* continuous scroll; lower part of page 2 still sharpening, no layout shift; page 3 placeholder 'Ferman couldn't draw page 3.' with Try again; Fit width selected and named in the zoom field, status bar 113%; page field focused for editing (⌘G / Ctrl+G, numbers and labels) | **M2** | ferman-render, ui-only |
| `a2-14` | Signatures before signature checking ships<br>macOS · light · en, tr, ar | Until P3 a signature appears in a neutral state, with no green and no check ([G31](DESIGN_GAPS.md#g31))<br>*States:* Signatures tab with the signer's name as written in the file and 'Signature checking is available in a future version.'; document panel '1 signature, page 3' (drawn in English only); page 3; file lists use the neutral Signed chip of `a1-4-m2` | **M2** — P3 replaces it with the validation states of `a5-7` to `a5-7e` | ferman-core, ui-only |
| `a2-15` | Two-page spread — right-to-left document<br>macOS · light · en, tr, ar | Spread order follows only the document's /ViewerPreferences/Direction, never the UI language ([G32](DESIGN_GAPS.md#g32))<br>*States:* Arabic annual report, 12 pages, /R2L; two-page spread at 55%, fit page; page 1 on the right, page 2 on its left in every UI language; sidebar and panel hidden; in book layout a right-to-left cover stands alone on the left; Organize grid and thumbnails follow the UI direction | **M2** | ferman-core, ferman-render |

### 03 · Edit mode — text

Source: `design/03a Edit text.dc.html` · 14 artboards. The core of Ferman: click into any paragraph and edit it like a document. Covers hover, caret, selection and reflow, the text-block panel, missing glyphs and font substitution, overflow, and vertical Japanese. Continued in 03b · Edit mode — content (Review edits 3.12 is in 03c). Export 519d42a added a section 3.16 – 3.19 with five light boards with the EN/TR/AR switch: the signed-document warning and its banner, the missing-glyph outcomes, overflow results and text that can't be edited (macOS, except the spec sheets a3-17 and a3-18).

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a3-1a` | Edit — Hover reveals an editable block<br>macOS · light · en | Edit mode hover: only the block under the pointer shows a dashed frame, with an I-beam and a tooltip<br>*States:* hover on block p3; tooltip 'Click to edit · Madde 3'; doc unsaved/edited; Pages sidebar; Edit doc panel (help) | **M3** | ferman-text (paragraph model, hit testing, reading order), ferman-render (tiles), ui-only (hover frame, tooltip, ⌥ reveal-all) |
| `a3-1b` | Edit — Caret in a paragraph, typing reflows the block<br>macOS · light · en | Caret placed in a paragraph; inserted text reflows inside the original frame with the original font and justification<br>*States:* block editing; caret after inserted text; inserted run marked edited; margin change bar across 2 lines; meta tab 'IBM Plex Serif · 10.5 pt' in margin | **M3** | ferman-text (editing, reflow, caret), ferman-fonts (shaping, metrics, subset extension), ferman-core (content-stream rewrite) |
| `a3-1c` | Edit — Selecting words inside a block<br>macOS · light · en | Word selection inside an editing block with a floating format bar<br>*States:* selection (ink 26%); floating toolbar open; edited run marked | **M3** — bar: highlight/comment = M4; add link, find & replace = P2 | ferman-text (selection, run styling), ferman-fonts (bold/italic face lookup), ferman-ops (link/highlight/comment annotations), ui-only (floating bar) |
| `a3-1d` | Edit — Main editor<br>macOS · dark · en | Edit mode main editor in dark theme with a selected block<br>*States:* dark theme; block p4 selected; edited marks; meta in margin | **M3** — dark theme from M1 | ui-only (dark tokens), ferman-render (page not inverted) |
| `a3-2` | Edit — Selected text block, all properties<br>macOS · light · en | Text-block properties panel: font, size, colour (document colours first), B/I/U, alignment, spacing, position/size (mm), language with spell-check and hyphenat…<br>*States:* block selected; colour picker open (document colours); Position and size section open | **M3** — spell-check/hyphenation could slip to M4 | ferman-text (paragraph attrs, spacing, alignment, geometry, spell/hyphenation), ferman-fonts (document + system font list), ferman-core (colour extraction, content-stream write), ui-only (panel) |
| `a3-3a` | Edit — Missing glyph<br>macOS · light · en | Typed character (‘ğ’) missing from the embedded subset font: inline warning plus panel callout<br>*States:* missing-glyph warning; amber wavy underline on ‘ğ’; frame meta tab amber and flipped below; font field icon-only warning; page-1 thumbnail warning badge | **M3** — step 3 of the missing-glyph chain; the other outcomes are in `a3-17` ([G36](DESIGN_GAPS.md#g36)) | ferman-fonts (coverage check, substitution, subsetting), ferman-text (run marking), ferman-render (thumbnail badge) |
| `a3-3b` | Edit — Font substitution picker<br>macOS · light · en | 'Choose a font for this block' picker: embedded / installed / bundled similar fonts with coverage badges, a Turkish preview string and a closest-match ranking<br>*States:* dialog open; scope = Whole block; 'Closest match' row selected (EB Garamond); current font flagged 'No ‘ğ’ ‘Ğ’' | **M3** | ferman-fonts (embedded font enumeration, system fonts, bundled fonts, metric matching, coverage), ferman-core (embed new font), ferman-text (reflow preview, apply to N blocks) |
| `a3-4` | Edit — Text no longer fits<br>macOS · light · en | Overflow: the edited paragraph needs one more line than its frame; three resolution choices in the panel<br>*States:* overflow warning; third line faded under amber dashed edge; margin status '+1 line hidden'; page-1 thumbnail warn badge | **M3** — results and the choices that can't apply are in `a3-18` ([G38](DESIGN_GAPS.md#g38)) | ferman-text (overflow detection, reflow, tracking adjust), ferman-core (content-stream write), ui-only (status chip, banner) |
| `a3-15` | Edit — Vertical text (縦書き) in a Japanese letter<br>macOS · light · en | Editing vertical Japanese text: right-to-left columns, tate-chu-yoko, kinsoku, vertical punctuation; custom text-block panel<br>*States:* vertical block editing; horizontal caret moving down column; edited date run; bold/italic disabled with reason; direction = vertical | **M3** — vertical CJK editing is not explicit in the roadmap; candidate to defer | ferman-text (vertical writing mode, kinsoku, tate-chu-yoko, caret), ferman-fonts (vert/vrt2 features, CJK font coverage) |
| `a3-16a` | Edit — Signed document, before the first change<br>macOS · light · en, tr, ar | Before the first change to a signed document the engine asks, and the UI says how many signatures the change invalidates ([G35](DESIGN_GAPS.md#g35))<br>*States:* dialog 'Edit a signed document?' (1 signature, by Mert Kaya on 13.10.2026); Edit a copy (default, Enter; opens 'Kira sözleşmesi (copy).pdf' in a new tab), Edit anyway, Cancel (Esc); nothing edited yet; no setting turns it off | **M3** — the same check before the first change in Comment, Fill & Sign and Organize arrives with those modes (M4) | ferman-core (signature detection, copy), ferman-text, ui-only |
| `a3-16b` | Edit — After "Edit anyway"<br>macOS · light · en, tr, ar | After Edit anyway, a banner stays above the page while the document is open ([G35](DESIGN_GAPS.md#g35))<br>*States:* banner 'The signature in this document is no longer valid.' ('Saving keeps the signature, but it will show as invalid.') with Review edits; tab unsaved; page-3 thumbnail with the signature and warning badges; Review edits gets a signature row (`a3-12`) | **M3** | ferman-core, ferman-render (thumbnail badge), ui-only |
| `a3-17` | Missing glyph — the outcomes the panel reports<br>Spec sheet · light · en, tr, ar | The steps of the missing-glyph chain in the brief's order, as edit-panel callouts ([G37](DESIGN_GAPS.md#g37), [G36](DESIGN_GAPS.md#g36))<br>*States:* step 2, same font installed ('Character added from this computer': ‘ğ’ taken from Garamond Premier Pro, re-subset and embedded, said once); no font has the character (‘ǧ’; only Choose a font… and Keep as is); licence forbids embedding (preview-and-print font never re-embedded; a similar font is used and Ferman says so) | **M3** — find and replace uses the same flow in P2 | ferman-fonts (system fonts, fsType, re-subsetting, coverage), ferman-text |
| `a3-18` | Overflow — results, and choices that can't apply<br>Spec sheet · light · en, tr, ar | What each overflow choice does, and when Extend or Tighten is disabled ([G38](DESIGN_GAPS.md#g38))<br>*States:* extended by 1 line (frame grew into free space, nothing moved); spacing tightened −0.6% (within the cap, frame unchanged); kept with a warning ('+1 line hidden', clipped, marked on the page, the thumbnail and in Review edits); Extend block disabled ('The IBAN line sits right below this block.'); Tighten spacing disabled ('Even the tightest allowed spacing leaves 1 line over.'); snippets in the document's own direction | **M3** | ferman-text (overflow detection, collision check, tracking cap), ferman-core (content-stream write) |
| `a3-19` | Edit — Text that can't be edited<br>macOS · light · en, tr, ar | Every kind of text Ferman can't safely rewrite reuses the scanned-page pattern of `a3-11` ([G39](DESIGN_GAPS.md#g39))<br>*States:* heading drawn as vector shapes; not-allowed cursor with the inverse tooltip 'This text is drawn as shapes, so it can't be edited'; panel callout 'This text can't be edited'; the caption also names shared form XObjects, unparsable content, permissions ([G27](DESIGN_GAPS.md#g27)), read-only files ([G28](DESIGN_GAPS.md#g28)) and edits that can't pass the zero-pixel-difference test | **M3** | ferman-text (editability check, hit testing), ferman-core (content-stream interpreter), ferman-render (pixel-difference check) |

### 03b · Edit mode — content

Source: `design/03b Edit content.dc.html` · 10 artboards. Text boxes, images, links, find and replace, page marks (watermark, header and footer, Bates, background), table-aware editing on an invoice, and undo history. Continued in 03c (Edit review and translate).

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a3-5a` | Edit — Add a text box<br>macOS · light · en | Add text tool: place and size a new text box that inherits the nearest paragraph style and snaps to the text column<br>*States:* Add text tool active; new box editing with caret; snap guide 'Aligned to text column'; unsaved | **P2** | ferman-text, ferman-fonts, ferman-core |
| `a3-5b` | Edit — Image selected, cropping, properties<br>macOS · light · en | Image selection with non-destructive crop, replace/extract, rotate/flip, position/size, alt text and quality info<br>*States:* image selected; crop mode active (page dimmed, white corner handles); 'Cropping · 28 × 35 mm' label; edited thumbnail; unsaved | **P2** | ferman-core, ferman-render, ferman-ops, platform |
| `a3-6` | Edit — Add and edit links, link list<br>macOS · light · en | Link tool: Edit link popover (Web/E-mail/Page/File), appearance, remove; Links panel listing all links incl. broken destination<br>*States:* Link tool on (faint outlines); Edit link popover, type E-mail; link list with selected item; broken link warning 'Broken: this document has 3 pages'; attachment link | **M4** — link annotations; open-link prompt is M2 view behaviour | ferman-ops, ferman-core, platform |
| `a3-7` | Edit — Find and replace with per-match preview<br>macOS · light · en | Turkish-aware find and replace with per-match before/after preview, Replace/Skip, suffix warning<br>*States:* replace bar open, match 2 of 5 current; per-match states Replaced / current / Waiting / Skipped (form label); Turkish suffix notice | **P2** | ferman-text, ferman-fonts, ferman-core |
| `a3-8a` | Edit — Watermark<br>macOS · light · en | Text watermark with live preview, font/size/opacity/rotation/colour, layer behind/over, page scope, print toggle<br>*States:* live preview; Type=Text; Layer=Behind text; All 3 pages; All capitals on | **P2** | ferman-ops, ferman-fonts, ferman-core, ferman-render |
| `a3-8b` | Edit — Header and footer<br>macOS · light · en | Header/footer with left/center/right slots, insertable fields, localized date format, size/edge offset, duplicate page-number warning<br>*States:* Footer tab selected; live preview header+footer; warning banner about existing page numbers | **P2** | ferman-ops, ferman-text, ferman-fonts, ferman-core |
| `a3-8c` | Edit — Page marks menu and Bates numbering<br>macOS · light · en | Page marks menu (Watermark, Header and footer, Background, Bates, Remove) and Bates numbering across open documents<br>*States:* Page marks menu open, Bates checked; Bates panel; scope 'All 3 open documents, in tab order' selected; live stamp preview KAYA-000001 | **P2** | ferman-ops, ferman-core, ferman-fonts, jobs |
| `a3-8d` | Edit — Page background<br>macOS · light · en | Page background colour/image with swatches, opacity, page scope, print toggle and contrast check<br>*States:* Type=Colour; live preview; contrast OK caption | **P2** | ferman-ops, ferman-core, ferman-render |
| `a3-9` | Edit — Column- and table-aware editing on an invoice<br>macOS · light · en | Editing a number in a detected table cell, keeping right alignment, flagging dependent totals<br>*States:* cell C2 editing with caret; column letters A–F overlay, C highlighted; dependent cells tinted; Edited badge; 'Totals don’t update' warning | **M3** — (in-cell edit, alignment, dependent-cell flag); table detection/row insert not in roadmap, P2 at earliest | ferman-text, ferman-fonts, ferman-core |
| `a3-10` | Edit — Undo history<br>macOS · light · en | Edit history panel listing named steps with time, current step and undone (redoable) steps<br>*States:* history panel open; current step 'Moved image · page 3'; 2 undone steps greyed | **M3** | ferman-core, ferman-text, ui-only |

### 03c · Edit mode — scans, review, translation, languages

Source: `design/03c Edit review and translate.dc.html` · 6 artboards. What happens when a page is only an image, how every edit can be reviewed and reverted, in-place translation that keeps the layout (including a change of writing direction), and documents that mix languages. Export 519d42a added `a3-12b`, the review list's empty and confirm states, as a light spec sheet with the EN/TR/AR switch.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a3-11` | Edit — Scanned page: run OCR to edit<br>macOS · light · en | Edit mode on an image-only (scanned) page: explains the missing text and offers on-device OCR to make it editable or searchable<br>*States:* image-only page in Edit mode, cursor not-allowed; info bar banner over the canvas with Not now / Recognize text…; pointer hint tooltip on the scan; thumbnail warning badge (FmSidebar doc=scan); OCR panel default: Turkis… | **P3** — (OCR); the image-only page detection and pointer hint are needed in M3 Edit mode, with the OCR buttons disabled ('Available in a future version') unt… | ferman-text (detect page with no text layer, hit testing), jobs (async on-device OCR with progress), ferman-fonts (matching font for 'Editable text' result), ferman-ops (replace image with text / add invisible text layer), ferman-render (thumbnail warning badge), ferman-core (save) |
| `a3-12` | Edit — Review all edits<br>macOS · light · en | Edit review list: every change with where, when, before/after, plus Go to and Revert for each, filter, Revert all and Export list<br>*States:* review panel open from the tool-row 'Review edits' button (badge 5); filter = All; first row selected (accent border) and selected on page (DocKira sel=p4); kept-warning row (overflow) in warning style; save=unsaved; since 519d42a a signature row at the top ('Mert Kaya’s signature is no longer valid', [G35](DESIGN_GAPS.md#g35), [G42](DESIGN_GAPS.md#g42)) | **M3** — the list covers this session; earlier sessions are in version history (M4); the new-text-box row needs Add text (P2), so M3 goldens use an M3 edit | ferman-text (edit journal, revert a single edit even when it isn't the last), ferman-fonts (font substitution records listed as edits), ferman-core (incremental save of the edit set), ui-only (list, filter, Go to, export) |
| `a3-12b` | Review edits — empty, revert all, dependent edits<br>Spec sheet · light · en, tr, ar | The review list's empty state and its two confirmations ([G42](DESIGN_GAPS.md#g42))<br>*States:* empty list with the shared EmptyState ('No edits yet'; the list clears when the document closes, earlier sessions are in Version history), Revert all… and Export list… disabled; 'Revert all 5 edits?' (undoable until the document closes) with Revert 5 edits; 'Also revert the edit that depends on it?' with Revert both | **M3** | ferman-text (edit journal, dependencies between edits), ui-only |
| `a3-13a` | Translate — Turkish → Arabic, side by side<br>macOS · light · en | On-device in-place translation that keeps layout, with left-to-right → right-to-left direction change, font fallback and per-page accept<br>*States:* side-by-side original/preview; preview blocks tinted (--translated-mark), preview page with accent border; RTL switch on, keep-numbers switch on; Page 1 accepted, Pages 2–3 pending with Accept; LTR runs (IDs, dates, IBA… | **P4** | jobs (on-device translation model run, progress/cancel), ferman-text (block reflow, bidi direction flip, number/IBAN isolation), ferman-fonts (Arabic coverage check, announced Noto Naskh fallback, shaping, subsetting), ferman-core (write translation as new PDF; keep signatures page), ferman-render (preview) |
| `a3-13b` | Translate — English → German, longer text<br>macOS · light · en | Translation overflow handling: German expansion reflowed with hyphenation, blocks that still overflow marked '+1 line' with resolution choices<br>*States:* warning banner '2 blocks don’t fit'; two overflowing blocks clipped with overflow underline and amber '+1 line' tags; page list: Page 1 needs room, Pages 2–4 fit; save=saved, pages=4 | **P4** — reuses the M3 overflow machinery | jobs (translation model), ferman-text (reflow, German hyphenation, overflow detection per block), ferman-fonts (size reduction, metrics), ferman-core (save new PDF) |
| `a3-14` | Edit — Turkish thesis with an English quote, language per block<br>macOS · light · en | Language per block in mixed-language documents: detected on open, margin language tags, spell-check and hyphenation per block language, status-bar language<br>*States:* English quote block selected (TextEditBox selected, meta below); TR/EN margin tags shown ('Show block languages' on); Turkish misspelling 'kiracınnın' with wavy red underline; status bar 'English (United Kingdom) · spel… | **M3** — (block language, spell-check and hyphenation in the edit panel); writing lang into the PDF structure tags is P4 (PDF/UA) | ferman-text (per-block language detection, spell-check, language-aware hyphenation/reflow), ferman-core (write /Lang into the structure tree), ferman-fonts, ui-only (margin tags, status-bar language, View menu toggle) |

### 04 · Comment mode

Source: `design/04 Comment.dc.html` · 9 artboards. Markup, notes, shapes, stamps and measurement; threads with replies and mentions; summaries; hiding and flattening. Comments are standard PDF annotations, so they open in any PDF reader.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a4-1` | Comment — Toolbar, shapes menu, markup on the page<br>macOS · light · en | Comment tool row (Select V, Highlight H, Underline U, Strikethrough S, Note N, Text X, Callout C, Draw P, Shapes R, Stamp, Measure M, Show comments switch); Sh…<br>*States:* tool=shapes active, annot colour red; Shapes menu open, Rectangle checked; rectangle selected with 8 handles + floating style bar (colour, 2 pt, 100%); freehand ink circle, callout with arrow (TR text), seal stamp place… | **M4** | ferman-ops (square/ink/freetext-callout/stamp annotations, appearance streams), ferman-render (annotation rendering on tiles), ferman-core (incremental save), ui-only (tool row, menu, style bar) |
| `a4-1d` | Comment — Note open on the page<br>macOS · dark · en | Sticky note opened from its pin on the page, with reply; dark chrome<br>*States:* dark theme (page and marks stay as printed); tool=note, annot colour yellow; note open: Mert Kaya 09:58 with 1 reply (Ayşe Yılmaz 10:05 'Katılıyorum.'); panel card 2 expanded | **M4** | ferman-ops (Text/Popup annotations, IRT replies), ferman-render, ui-only (focus handling) |
| `a4-1c` | Comment — Distance and area on a floor plan<br>macOS · light · en | Measure tool (distance, perimeter, area) with snapping, calibrated scale, per-page measurement list, CSV export<br>*States:* tool=measure, kind=area; Snap to lines and corners on; scale calibrated 1:75 (1 mm = 7,5 cm) from 12,00 m dimension line; list: Area · Yatak odası 25,65 m²; Distance · Salon 6,88 m (area row selected); plan tab active +… | **P4** — proposed: measuring grouped with a9-7 measure tools | ferman-ops (Line/PolyLine/Polygon annots with Measure dict, viewport scale), ferman-core (content-stream interpreter for snap geometry), ferman-render, platform (CSV save dialog) |
| `a4-2` | Comment — Thread with replies, mention, filters<br>macOS · light · en | Comment threads: replies, @mentions, status/author/type filters, sort, resolve/reopen, selected mark linked to page<br>*States:* tool=select; filter=Open (Open 7 / Resolved 2 / All 9), filters row open (Author, Type, Sort); thread 1 expanded with 2 replies incl. '@Mert Kaya'; composer focused 'Teşekkürler @Av' with 'People in this document' sugge… | **M4** | ferman-ops (annotation /IRT replies, /State review model, /T author), ferman-text (quoted text under markup), ui-only (filters, sort, mention suggest, a11y labels) |
| `a4-3` | Comment — Stamp library<br>macOS · light · en | Stamp library: search, Standard, Türkçe, dynamic (name and date), My stamps; create and import<br>*States:* tool=stamp; popover open, 'Onaylandı' selected; groups STANDARD / TÜRKÇE / WITH NAME AND DATE / MY STAMPS | **M4** | ferman-ops (stamp annotations + appearance streams), ferman-fonts (glyph coverage/subset for İ, Ş etc.), platform (Import… file dialog), ui-only (library, search) |
| `a4-3b` | Comment — Create a custom stamp<br>macOS · light · en | Create custom stamp: text, second line (name/date/time), colour, language for capitals, live preview<br>*States:* text 'İncelendi', My name + Date checked, Time unchecked, name 'Av. Deniz Aksoy'; colour Ink; Language for capitals: Turkish (İNCELENDİ); preview stamp rotated -4 with '13.10.2026' | **M4** | ferman-ops (stamp appearance generation), ferman-fonts (shaping/subset, locale casing), platform (local storage, export file dialog) |
| `a4-4` | Comment — Export a comment summary<br>macOS · light · en | Export comment summary as PDF (3 layouts) or CSV, with include options, sort, paper size and live preview<br>*States:* format PDF; layout 'Page and comments' selected; Open comments (7) + Replies checked; Resolved (2) and Pages without comments unchecked; Sort Page order, Paper A4; preview page 1 of 2 (Turkish content, numbered markers) | **M4** | ferman-ops (annotation enumeration), ferman-core (write new summary PDF), ferman-render (page thumbnails), ferman-fonts (embed/subset for summary text), platform (save dialog), jobs (long exports) |
| `a4-5` | Comment — All comments hidden<br>macOS · light · en | Hide all comments (Show comments switch, ⇧⌘H) with count notice<br>*States:* show-annots=false (switch off), page rendered without marks; notice '9 comments hidden' + 'Show comments' button; panel still lists comments | **M4** | ferman-render (render with annotations suppressed), ui-only (switch, notice) |
| `a4-5b` | Comment — Flatten comments<br>macOS · light · en | Flatten comments into page content, all or resolved only, keep commented copy<br>*States:* confirm dialog, 'All 9 comments' selected; 'Only the 2 resolved comments' option; Keep a copy with comments checked (default) | **M4** | ferman-ops (flatten annotation appearances into content streams), ferman-core (write copy, incremental/full save), platform (file write next to original) |

### 05a · Fill & Sign — filling forms

Source: `design/05a Fill.dc.html` · 9 artboards. Detected form fields, tab order and field navigation; every field type and state; simple signatures that are typed, drawn or made from an image; and filling PDFs that have no fields. Digital and e-imza signatures continue in 05b.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a5-1` | Fill — Detected fields, tab order, field navigation<br>macOS · light · en | AcroForm field detection, field tint, tab-order overlay, Tab/⇧Tab field navigation, form panel with per-field status<br>*States:* fillable-form info banner; tab order shown; field 3 of 20 focused (Adı); 13 required left; partially filled; unsaved | **M4** | ferman-core (AcroForm field tree), ferman-ops (forms: values, /Tabs order, required flags), ferman-render (field highlight), ui-only |
| `a5-1d` | Fill — Same form<br>macOS · dark · en | Dark-theme version of form filling<br>*States:* dark chrome; field tints unchanged on white paper; field 3 of 20; partially filled | **M4** | ui-only |
| `a5-2` | Fill — Date picker and a number that fails validation<br>macOS · light · en | Date field picker in the field's own format; number range check on blur; error shown in field, panel and thumbnail<br>*States:* date picker open (November 2026, Monday-first); number field error on 'hane'; thumbnail warning badge; field 15 of 20; 6 required left | **M4** | ferman-ops (forms: AFDate/AFNumber format, keystroke and validate actions), ferman-core, ui-only (picker) |
| `a5-2b` | Fill — Field types and states<br>Spec sheet · light · en | PdfFormField matrix: text, date, dropdown, number, checkbox/radio, signature × empty/hover/focus/filled/error/read-only<br>*States:* empty; hover; focus; filled; error; read-only | **M4** | ferman-ops (forms: appearance streams per field type), ferman-fonts (field fonts, Turkish glyphs in values), ui-only |
| `a5-3` | Sign — Type your signature<br>macOS · light · en | Add signature dialog in Type mode with handwriting styles filtered by glyph coverage; Signature/Initials switch<br>*States:* Type mode; name 'Ayşe Yılmaz'; handwriting style 1 selected; Signature (not Initials); field 20 of 20, 1 required left | **M4** | ferman-fonts (coverage check, shaping, subsetting of handwriting fonts), ferman-ops (signatures: simple stamp), platform (device-local signature storage), ui-only |
| `a5-3b` | Sign — Draw<br>Dialog (spec sheet) · light · en | Add signature dialog in Draw mode with smoothed strokes<br>*States:* Draw mode with strokes | **M4** | ui-only (stroke capture/smoothing), ferman-ops (vector appearance for signature) |
| `a5-3c` | Sign — From an image<br>Dialog (spec sheet) · light · en | Add signature from a photo or scan, with local background removal and crop to the ink<br>*States:* Image mode empty drop zone | **M4** | ferman-ops (image background removal/crop, image XObject with SMask), platform (file dialog, drag-and-drop) |
| `a5-3d` | Sign — Place, resize and rotate; saved signatures<br>macOS · light · en | Sign menu of saved signatures/initials; placing a signature that snaps into the field; resize, rotate and nudge<br>*States:* Sign menu open; signature placed and selected with handles; size/angle label '62 × 16 mm · −2°'; All required filled; panel row green | **M4** | ferman-ops (signatures: place into widget/stamp, rotate, resize), ferman-render, platform (local signature storage), ui-only |
| `a5-4` | Fill — A PDF without form fields<br>macOS · light · en | Fill anything: detect lines, boxes and comb boxes on a flat page and place text and marks; 'Find fields' turns it into a form (5.8)<br>*States:* no-fields banner; Text tool active; editing 'Abone No' with mini toolbar (10 pt); comb boxes filled; checkbox checked | **M4** | ferman-core (content-stream interpreter for line/box detection), ferman-text (baseline hit testing), ferman-ops (add text/marks), ferman-fonts (font for typed text, subsetting), ui-only |

### 05b · Fill & Sign — digital signatures and forms

Source: `design/05b Sign.dc.html` · 15 artboards. Certificate signatures, Turkish qualified e-signature (e-imza) with a smart card, signature validation in plain language, and form authoring. Certificate and timestamp provider names are placeholders.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a5-5` | Sign — Choose a certificate<br>macOS · light · en | Certificate picker for signing: lists smart-card, keychain and file certificates<br>*States:* NES smart-card cert selected; keychain corporate cert available; expired S/MIME cert disabled with reason | **P3** | ferman-ops (signatures), platform (keychain / Windows cert store, PKCS#11 token enumeration, file dialog) |
| `a5-5b` | Sign — Reason, location, appearance, timestamp<br>Dialog (spec sheet) · light · en | Signature options: reason, location, appearance style, timestamp server, LTV, lock document<br>*States:* default: reason approve, handwriting appearance, TÜRKSERT TSA selected, LTV checked, lock unchecked | **P3** | ferman-ops (PAdES signing, appearance stream, TSA/OCSP client), ferman-fonts (handwriting font subset for appearance), ferman-core (incremental save) |
| `a5-5c` | Sign — Signed document<br>macOS · light · en | Post-signing state: success bar, signature appearance on page, Signatures panel<br>*States:* signed and valid; 2 valid signatures (Ayşe Yılmaz expanded, Mert Kaya collapsed); saved at 14:41 | **P3** | ferman-ops (signature validation), ferman-core (revisions, incremental save preserving earlier signature), ferman-render |
| `a5-6` | e-imza — Card detected, ready to sign<br>macOS · light · en | Turkish e-imza panel: reader/card detection, 3-step flow, format and TSA options<br>*States:* card ready; step 1 done (field chosen, dashed outline on page); step 2 current (PIN); step 3 pending | **P3** | platform (PKCS#11 driver loading, reader detection), ferman-ops (PAdES signing), ferman-core (incremental save) |
| `a5-6b` | e-imza — PIN<br>Dialog (spec sheet) · light · en | PIN entry for the smart card<br>*States:* PIN typed (masked), 3 tries left | **P3** | platform (PKCS#11 login) |
| `a5-6c` | e-imza — Signing<br>Dialog (spec sheet) · light · en | Signing progress with per-step results<br>*States:* 2 steps done; step 3 running (spinner); 2 waiting; progress 55% | **P3** | jobs (cancellable signing task with progress), platform (PKCS#11), ferman-ops (OCSP/TSA, PAdES), ferman-core (save) |
| `a5-6d` | e-imza — Signed<br>Dialog (spec sheet) · light · en | e-imza success confirmation with legal statement and file location<br>*States:* success | **P3** | ferman-core (save as new file), platform (reveal in file manager) |
| `a5-6e` | e-imza — No card found<br>Dialog (spec sheet) · light · en | No reader/card troubleshooting checklist with continuous polling<br>*States:* no reader connected; card/driver checks pending; polling (spinner) | **P3** | platform (reader polling, PKCS#11 module loading, file dialog) |
| `a5-7` | Validation — Document changed after signing<br>macOS · light · en | Signature validation on open: warning bar for post-signing modification<br>*States:* changed after signing; 1 warning, 1 valid (covers revision 1) | **P3** | ferman-ops (signature validation), ferman-core (incremental revisions), ferman-text (compare) |
| `a5-7b` | Valid<br>Spec sheet · light · en | Signature card — valid<br>*States:* valid | **P3** | ferman-ops (signature validation) |
| `a5-7c` | Valid with warnings<br>Spec sheet · light · en | Signature card — valid with warnings (no timestamp, revocation unchecked offline)<br>*States:* warn | **P3** | ferman-ops (signature validation, OCSP/CRL) |
| `a5-7d` | Invalid<br>Spec sheet · light · en | Signature card — invalid (revoked certificate)<br>*States:* invalid | **P3** | ferman-ops (signature validation) |
| `a5-7e` | Modified after signing<br>Spec sheet · light · en | Signature card — document changed after signing<br>*States:* modified | **P3** | ferman-ops (signature validation), ferman-core (revision diff) |
| `a5-8` | Prepare form — Draw fields, field properties<br>macOS · light · en | Form authoring: field-type palette, draw fields, text field properties<br>*States:* text field selected; required on; number format 1–20, 0 decimals; calculation none; document unsaved | **P4** | ferman-ops (forms/AcroForm authoring), ferman-text (label detection for tooltip), ferman-core (save) |
| `a5-8b` | Prepare form — Fields found on a flat form<br>macOS · light · en | Automatic field detection on a flat PDF with review list<br>*States:* 11 fields detected; 2 uncertain (amber); nothing created yet | **P4** | ferman-core (content-stream interpreter for lines/boxes), ferman-text (label proximity, naming), ferman-ops (forms) |

### 06 · Organize

Source: `design/06 Organize.dc.html` · 6 artboards. The page grid with selection, drag reorder and every page command; split, combine, crop and page size; page labels. Every change can be undone until the file is saved.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a6-1` | Organize — Multi-select and page commands<br>macOS · light · en | Page grid with multi-select (pages 4–6), context menu and panel of page commands acting on the selection<br>*States:* 3 of 64 selected (pages 4–6); context menu open, heading '3 pages'; Selection panel populated; document unsaved; no sidebar | **M4** — scanner/camera import: not on roadmap | ferman-ops (rotate, duplicate, extract, insert, replace, delete pages), ferman-render (thumbnails), ferman-core (write/incremental save, page labels, page size), platform (open-file dialog for pages from file; scanner/camera), ui-only (selection, focus, a11y announcements) |
| `a6-1b` | Organize — Dragging 3 pages, insertion marker<br>macOS · light · en | Drag reorder of a multi-page selection with lifted stack, placeholder slots and insertion marker<br>*States:* dragging 3 pages; source slots shown as placeholders; accent insertion bar with dot; stack count badge '3'; status bubble 'Drop to move pages 4–6 before page 3'; organize-hint 'Moving 3 pages' | **M4** | ferman-ops (page reorder), ferman-render (thumbnails), ui-only (drag, auto-scroll, toast) |
| `a6-2` | Organize — Split with result preview<br>macOS · light · en | Split document by N pages / top-level bookmarks / file size / blank separator pages, with per-file result preview<br>*States:* 'At top-level bookmarks' selected (6 bookmarks found); preview lists 6 files with label ranges, page counts, sizes; save='saved'; tool=split | **M4** | ferman-ops (split), ferman-core (outline/bookmarks, write new files), ferman-render (blank-page detection), jobs (writing files with progress, size estimation), platform (folder chooser) |
| `a6-3` | Organize — Combine files<br>macOS · light · en | Combine multiple files (PDF, Excel, image) with reorder, per-file page ranges, bookmarks per file and live result preview<br>*States:* 5 files listed, row 3 lifted mid-drag with insertion bar; Excel and JPG rows 'converted to 1 page'; range field per file (All / 1 / 1–2); bookmark + keep-signatures checkboxes checked; size estimate 'About 3,4 MB'; no-p… | **M4** — Word/Excel input conversion: P3; image input M4 | ferman-ops (combine, bookmarks, forms/signature carry-over), ferman-core (outline, AcroForm merge, write), ferman-render (result thumbnails), jobs (Office/image conversion, combine progress), platform (file dialog, drag-and-drop) |
| `a6-4` | Organize — Crop and page size<br>macOS · light · en | Crop with handles/margins, 'Remove white margins', page size change with Centre/Scale to fit, apply-to scope<br>*States:* crop rectangle with 8 handles and size tag '180 × 270 mm'; margins 12/15/15/15 mm; page size 'Keep current size (A4)'; Content = Centre; Apply to 'All 3 pages'; unsaved, zoom 70 | **M4** — removing hidden content on save ties to P2 remove hidden information | ferman-ops (CropBox/MediaBox, page resize/scale), ferman-core (content-stream interpreter for content bbox, save), ferman-render (page render, white-margin detection), ui-only (crop overlay) |
| `a6-5` | Organize — Page labels and numbering<br>macOS · light · en | Page label ranges (style, prefix, start) with preview and optional stamping as visible footer numbers<br>*States:* 3 ranges: 1–9 roman, 10–64 arabic, 65–66 arabic prefix 'Ek-'; preview 'i ii iii … ix · 1 2 3 … 55 · Ek-1 Ek-2'; stamp checkbox unchecked; unsaved | **M4** — footer stamping: P2 header/footer | ferman-core (/PageLabels number tree read/write), ferman-ops (footer stamping), ui-only (range editor, preview) |

### 07 · Convert

Source: `design/07 Convert.dc.html` · 6 artboards. Converting from and to PDF, batch queues, honest fidelity reports, scanning, and text recognition in several languages at once. Everything runs on this device.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a7-1` | Convert — Hub<br>macOS · light · en | Convert hub: two groups of format cards. 'From this PDF' has 7 targets, 'To PDF' has 6 sources, and each card says what the conversion keeps.<br>*States:* Word card selected (accent ring); From this PDF: Word, Excel, PowerPoint, Image, HTML, Plain text, Markdown; To PDF: Word(.docx .odt), Excel(.xlsx .ods), PowerPoint(.pptx .odp), Images(.jpg .png .heic), Web page(.html),… | **P3** | jobs, ferman-core, ferman-text, ferman-render, ferman-fonts, platform |
| `a7-2` | Convert — Options and batch queue<br>macOS · light · en | PDF to Word options (layout, content, images, save location) and a 5-file conversion queue showing the state of each file<br>*States:* Layout: 'Flowing text' selected / 'Exact layout'; switches on: OCR scanned pages, Word comments, headers/footers; queue: done (with Report), converting page 21 of 64 with progress, waiting, needs password (Unlock…), fai… | **P3** — multi-file queue overlaps P4 batch actions; background tasks M4 | jobs, ferman-core, ferman-text, ferman-fonts, ferman-render, platform |
| `a7-3` | Convert — Result and fidelity report<br>macOS · light · en | Conversion result dialog with a fidelity report: Kept list and Changed list, each change with a link to its page<br>*States:* success with 2 changes; Kept (6): text font, headings, 1 table, 9 comments, header/footer, 4 links; Changed (2 warning cards): font substituted p1, signatures became images p3 | **P3** | jobs, ferman-fonts, ferman-ops, ferman-text, ferman-render, platform |
| `a7-4` | Scan to PDF — Scanner or phone camera<br>macOS · light · en | Scan to PDF from a scanner or phone camera: edge detection, perspective correction, corner handles, page strip, per-page look/rotate/rescan, and phone pairing…<br>*States:* Source=Scanner (Canon imageFORMULA · Wi-Fi), Both sides on; 300 dpi, Paper=Detect; after scanning: OCR Turkish on, remove blank pages on; status 'Edges found · perspective corrected · page 4'; strip of 4 pages, page 4 s… | **P3** — phone-camera source depends on Ferman Mobile, P5 | platform, jobs, ferman-ops, ferman-core, ferman-render, unassigned: edge detection/perspective correction |
| `a7-5` | OCR — Languages, packs and output<br>macOS · light · en | OCR setup: choose several languages, language packs with their state, Searchable or Editable output, page scope, and a time estimate<br>*States:* Türkçe 'Detected' (checked); English 'Installed' (checked); Deutsch Installed; العربية downloading 45% (checkbox disabled); 日本語 / Русский available '18 MB' download button (disabled); Result=Searchable selected | **P3** | jobs, ferman-render, ferman-text, ferman-fonts, ferman-core, platform |
| `a7-5b` | OCR — Running, then words to check<br>macOS · light · en | OCR progress card, then review of low-confidence words: amber tint on the page and suggested readings in the panel<br>*States:* running 'Page 2 of 3 · about 6 seconds left' with cancel; save=unsaved, tab unsaved; page-1 thumbnail warning; 4 low-confidence words tinted, first focused (accent outline); list: 19.5OO TL 58%, TUFE 64%, Saygılanmızla… | **P3** | jobs, ferman-text, ferman-render, ferman-core, ui-only |

### 08 · Protect

Source: `design/08 Protect.dc.html` · 6 artboards. Passwords and permissions, redaction that really removes content and proves it, removing hidden information, and a plain-language security report.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a8-1` | Protect — Open password, permissions, encryption<br>macOS · light · en | Set an open password, optional permissions password and restrictions, and the encryption level, then save as a new file<br>*States:* tool=password; save=saved; password strong (0.82, success tone); restrictions checkbox on; Screen readers checked+disabled; AES-256 selected | **P2** — password-protect is not listed in the roadmap; grouped with Protect. Unlocking is M2 | ferman-core (encryption AES-256/128, permission flags, write), platform (save-as dialog, optional keychain), ui-only (strength meter) |
| `a8-2` | Redact — Mark text, areas and patterns; review<br>macOS · light · en | Find & redact: pattern detection, search terms, area marks drawn on the page, review list, then apply<br>*States:* tool=findRedact; redactions=4 (tool-row button "Apply redactions (4)"); save=unsaved; marks pending (red hatching); area mark selected in review; search-term hit unchecked ("not marked") | **P2** | ferman-text (search, pattern detection with TCKN checksum/IBAN, hit testing, glyph boxes), ferman-ops (redaction marks), ferman-render (hatched overlay), ui-only (review list) |
| `a8-2b` | Redact — Confirm<br>macOS · light · en | Confirm applying redactions, with save-as-new-file and remove-hidden-information options<br>*States:* redactions=4; save=unsaved; Save as a new file checked (default); Also remove hidden information checked (default) | **P2** | ferman-ops (redaction apply: content-stream/glyph/image removal), ferman-core (full non-incremental rewrite, metadata/XMP/attachments removal), jobs (apply progress), platform (save location) |
| `a8-2c` | Redact — Applied and verified<br>macOS · light · en | Check after redaction: re-read the saved file and list each check that passed<br>*States:* save=saved at 14:50; new tab with shield-check icon; redactions applied (black boxes); verification Passed (6 checks); success banner | **P2** | ferman-core (re-parse saved output, check that revisions are gone), ferman-text (extract text under boxes, search check), ferman-render (pixel check), ferman-ops (verification), jobs, platform (reveal in Finder/Explorer) |
| `a8-3` | Protect — Remove hidden information<br>macOS · light · en | Remove hidden information: per-category list of what this file actually contains, then remove the selected items<br>*States:* tool=hidden; save=saved; 7 categories found and checked; category with "None found" disabled and greyed; Bookmarks found but unchecked (kept); DocKira annot=true | **P2** | ferman-core (metadata/XMP, attachments, incremental-revision stripping, JS detection, OCG layers, outline), ferman-ops (annotation/layer/JS removal, cropped content), ferman-text (white-on-white hidden text detection), ferman-render (visibility check) |
| `a8-4` | Protect — Security report<br>macOS · light · en | Plain-language security report: findings sorted by importance, each with an action<br>*States:* tool=report; save=saved; block/ok (JS blocked); warn x2 (amber border); info x2; ok x2 (one with no action) | **P2** — security report is not listed in the roadmap; the signature-validity row needs P3 signature validation and e-imza | ferman-core (encryption/permissions, JS detection, links, attachments, metadata), ferman-ops (signature validation), ferman-text (PII detection: TCKN/IBAN), ui-only (report layout) |

### 09a · Tools — compress, compare, accessibility, standards

Source: `design/09a Tools.dc.html` · 7 artboards. Size estimates before compressing, visual and text comparison, PDF/UA checking with fixes, PDF/A and PDF/X. Continued in 09b (batch, print, print production, measure, version history).

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a9-1` | Compress — Presets with estimated size<br>macOS · light · en | Compress panel: presets with estimated output size, before/after bar, what the preset does, compress and save as<br>*States:* Balanced preset selected (High quality ≈14,2 MB / Balanced ≈6,8 MB / Smallest ≈3,1 MB / Custom…); estimate shown: Now 24,6 MB, After ≈6,8 MB; document saved; 2,400-page doc (İmar planı) | **M4** | ferman-ops (compress, image recompression), ferman-core (full rewrite, unused-object removal, write), ferman-fonts (merge duplicate font copies), jobs (sample estimate, compress with progress), platform (save-as dialog) |
| `a9-2` | Compare — Side by side, text and visual differences<br>macOS · light · en | Side-by-side compare of old vs current version with tinted diffs and a filterable, steppable differences list<br>*States:* Side by side view; difference 1 of 4 selected (outlined on page); filter All 4 active (Text 2, Format 1, Comments 1); Scroll together on | **P3** | ferman-text (text diff, word-level alignment), ferman-render (page render, diff tint overlay), ferman-core (load both versions, incremental revisions, annotations), jobs (compare long docs), platform (export report save dialog) |
| `a9-2b` | Compare — Overlay<br>macOS · light · en | Overlay compare: old in red, current in blue, multiply-blended; fade slider between versions<br>*States:* Overlay view selected; fade slider at 50%; legend Old only / Current only / Both | **P3** | ferman-render (tinted rendering, blend), ferman-text (diff list), ui-only (slider, legend) |
| `a9-3` | Accessibility — Issues with fixes<br>macOS · light · en | PDF/UA checker listing problems and warnings with one-click or guided fixes<br>*States:* 3 problems · 2 warnings · 21 checks passed; document unsaved; page thumbnail with warn marker; auto-fixable issues have secondary buttons, judgement fixes ghost buttons | **P4** | ferman-ops (PDF/UA checks and fixes), ferman-core (structure tree, /Lang), ferman-text (list detection, reading order, language detection), ferman-render (issue markers, contrast sampling) |
| `a9-3b` | Accessibility — Tag tree, reading order, alt text<br>macOS · light · en | Tag tree editor synced with reading-order numbers on page, alt text and decorative flag for a figure<br>*States:* Figure 'Vesikalık fotoğraf' selected in tree; reading order numbers overlaid, photo 4th in amber; alt text filled (Turkish); Decorative unchecked; document unsaved | **P4** | ferman-core (structure tree edit, alt text), ferman-text (reading order, hit testing), ferman-ops (tagging) |
| `a9-4` | PDF/A — Convert and validate<br>Dialog (spec sheet) · light · en | PDF/A conversion result dialog: conformance level, list of automatic fixes, validation banner<br>*States:* success: Saved as PDF/A-2b; conformance 2b selected (1b, 2b, 2u, 3b, 4); 5 automatic fixes listed; success banner Valid PDF/A-2b | **P4** | ferman-ops (PDF/A convert and validator, flatten transparency), ferman-core (XMP, output intent, remove JS, attachments), ferman-fonts (embed/substitute fonts), jobs (convert+validate), platform (Show in Finder) |
| `a9-4b` | Preflight — PDF/X-4 with fixups<br>macOS · light · en | Print preflight against PDF/X profiles with per-issue fixups selectable and run in batch<br>*States:* profile PDF/X-4 · FOGRA39; 2 errors · 2 warnings; 4 fixups checked; thumbnails with warn markers and roman page labels (ii, iii) | **P4** — CMYK/bleed fixups overlap P5 print production | ferman-ops (preflight checks, fixups), ferman-core (output intent/ICC, page boxes, page labels), ferman-fonts (embed matching font), ferman-render (colour conversion, thumbnails), jobs (fixups with progress) |

### 09b · Tools — batch, print, measure, history

Source: `design/09b Tools.dc.html` · 8 artboards. Chained batch actions, printing with booklet, poster and production previews, scale calibration for measurements, and version history.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a9-5` | Batch — Build an action from steps<br>macOS · light · en | Batch action builder: saved actions list, ordered step cards, per-step settings, signed-file policy<br>*States:* saved action 'Arşive hazırla' selected (4 steps); step 3 'Add watermark' selected (accent ring) with settings open; signed-file policy radio defaults to skip; no-pages, no sidebar, no doc panel | **P4** — (batch actions); steps reference P3 OCR, P2 watermark/redaction, M4 compress | jobs, ferman-ops, ferman-core, ferman-fonts, platform |
| `a9-5b` | Batch — Running on a folder<br>macOS · light · en | Batch run progress per file per step, with pause/cancel and background task in status bar<br>*States:* running 43% (18 of 42 files, ~3 min left); row done; row running (OCR page 2 of 3); row waiting; row skipped: locked/needs password (danger border); row skipped: signed, watermark would break signatures | **P4** | jobs, ferman-core, ferman-ops, platform |
| `a9-6` | Print — Preview and options<br>macOS · light · en | Print dialog: printer, copies, page range, layout (Pages/Booklet/Poster), duplex, scale, include comments/forms/hidden layers, live sheet preview<br>*States:* printer 'Brother HL-L2350DW · office' selected; copies 2, pages 1–3; layout Pages; both sides long edge; scale Fit to printable area; comments+form contents checked, hidden layers unchecked | **M4** — proposed: basic system print in phase 1; booklet/poster are P5 | ferman-render, platform, ferman-core |
| `a9-6d` | Print production — Separations and overprint<br>macOS · light · en | Output preview: press-profile simulation, overprint preview, per-ink separations toggle, ink coverage readout, total-ink-limit highlight<br>*States:* profile Coated FOGRA39 selected; overprint preview on; CMYK visible, PANTONE 2945 C spot hidden; pointer readout C96 M78 Y12 K18, Total 204%; highlight-over-limit off (max 287% vs limit 300%) | **P5** — print production | ferman-render, ferman-core |
| `a9-6b` | Print — Booklet<br>Spec sheet · light · en | Booklet imposition: binding side, sheets per booklet (signatures), auto duplex, spread preview<br>*States:* layout Booklet; binding Left (this document); All in one booklet; print both sides checked; preview Sheet 1 front: pages 4 and 1, A4 folded to A5 | **P5** — print production (imposition) | ferman-ops, ferman-render, platform |
| `a9-6c` | Print — Poster tiling<br>Spec sheet · light · en | Poster tiling: size %, overlap mm, cut marks and tile labels, tile grid preview<br>*States:* layout Poster; size 200%; overlap 10 mm; cut marks and tile labels checked; 4 sheets of A4 · 2 × 2 with A1/A2/B1/B2 labels | **P5** — print production (poster tiling) | ferman-render, ferman-ops, platform |
| `a9-7` | Measure — Calibrate the scale<br>macOS · light · en | Scale calibration from a drawn reference line, title-block scale detection, scale stored in PDF<br>*States:* line drawn (158,7 mm on paper); real length 12 m entered; computed 1:75,6; 'Round to 1:75' checked (title-block scale detected); use for This page; document unsaved | **P4** — proposed: measure tools (not named in the roadmap) | ferman-core, ferman-ops, ferman-text, ferman-render |
| `a9-8` | Version history — Timeline, restore, compare<br>macOS · light · en | Version timeline (saves, signatures, imports), read-only preview of a past version, restore as new version, compare with current<br>*States:* previewing signed version 11:04 (read-only banner); selected item shows Restore… / Compare with current; 'Now · unsaved · 2 edits since the last save'; 7 versions; retention footer | **M4** — (version history); Compare is P3, e-imza and docx-conversion entries are P3 | ferman-core, ferman-render, platform |

### 10 · AI assistant

Source: `design/10 AI assistant.dc.html` · 3 artboards. Optional and off by default. It runs on this computer with a downloaded model, or with an API key you bring. Every answer cites the pages it comes from.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a10-1` | Assistant — Summary, clause explanation, draft reply<br>macOS · light · en | AI assistant chat panel: quick actions, Turkish summary with page-citation chips, draft reply card, citation highlighted on the PDF<br>*States:* panel open, local model ('On this Mac' badge); 2 Turkish Q&A turns; summary bullets with citation chips (3rd chip selected: surface-selected-strong); canvas passage outlined + tag 'Cited · answer 1'; draft reply card wi… | **P4** | new AI runtime/provider client (not in crate vocabulary, e.g. ferman-ai), jobs (async cancellable inference), ferman-text (passage extraction, hit-testing/rects for citation outline), ferman-core (document read), ferman-ops (Add as comment -> annotation, M4 dependency) |
| `a10-2` | Assistant — Setup<br>macOS · light · en | First-run setup: choose local model download vs own API key, privacy statement, model download progress<br>*States:* 'Runs on this computer' radio card selected; 'Use your own API key' card unselected: provider Select (compat) + disabled password field; 'What Ferman sends' disclosure; download in progress 29% with cancel (drawn alongs… | **P4** | jobs (cancellable model download with progress), platform (keychain for API key, RAM/disk-space query), new AI runtime/provider client (not in crate vocabulary) |
| `a10-2b` | Assistant — Off (default)<br>macOS · light · en | Default-off explainer shown when the assistant button is pressed before setup<br>*States:* panel open, Badge 'Off'; explainer with primary 'Set up…' and help link | **P4** | ui-only |

### 11a · Settings

Source: `design/11a Settings.dc.html` · 15 artboards. "Every settings pane, on macOS and Windows. App-level screens continue in 11b." One section, 15 FmBoard artboards. Each wraps <FmSettings pane=...>, a separate window (FmWindow bare=true, mode="", status=false) with a 240px pane list (title "Settings", search field, 11 panes) and a content column up to 760px wide. The 12 artboards of the first export are light, en, ltr; all are macOS except a11-1w (Windows 11). Export 519d42a added three M1 builds with the EN/TR/AR switch (a11-1-m1, a11-1w-m1 on Windows 11, a11-1h-m1): they pass FmSettings gated="m1", which adds the Close settings button ([G89](DESIGN_GAPS.md#g89)) and disables the default-app button, the network switches and Show network activity, while General's M2 controls and the other panes stay drawn enabled ([G108](DESIGN_GAPS.md#g108)). Pane contents and copy live in FmSettings.dc.html, not in this file. The trailing data script in 11a holds the board-language switch and the G tags; the rest are leftovers that nothing here renders.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a11-1` | Settings — General<br>macOS · light · en | Settings window shell and General pane: theme, how PDF pages look in dark theme, defaults for new documents, reopen last session, default PDF app<br>*States:* Theme=Match system; Pages in dark=Paper white; Layout=Continuous scroll; Zoom=Fit width; Reopen documents on; Preview is the default PDF app | **M1** — (settings skeleton, theme); layout/zoom defaults, reopen, default app, dimmed/dark page modes M2; the M1 build is `a11-1-m1`, and this board stays the finished product | ui-only, platform, ferman-render |
| `a11-1-m1` | Settings — General, M1 build<br>macOS · light · en, tr, ar | The M1 build of `a11-1`: Settings as a window-styled surface pushed over the screen it opens from ([G89](DESIGN_GAPS.md#g89), [G10](DESIGN_GAPS.md#g10))<br>*States:* Close settings button 12 px from the pane's top and end edges (Esc, ⌘W), returning to the screen below or to Start; traffic lights still close the app; default-app line 'Ferman can be the app that opens when you double-click a PDF.' with Make Ferman the default… disabled and the future-version tooltip; theme, dark-page radios, layout, zoom and Reopen drawn enabled | **M1** — the default-app button M2; by the brief's rule for unfinished features, the app keeps the dark-page, layout, zoom and Reopen controls and the panes not built yet disabled until they work ([G108](DESIGN_GAPS.md#g108)) | ui-only, platform |
| `a11-1w-m1` | Settings — General, Windows, M1 build<br>Windows · light · en, tr, ar | The M1 build of `a11-1w` ([G89](DESIGN_GAPS.md#g89), [G10](DESIGN_GAPS.md#g10); the caption cites [G16](DESIGN_GAPS.md#g16))<br>*States:* as `a11-1-m1` with Windows caption buttons, which close the app; the default-app line adds 'Windows lets you choose it in Settings › Default apps.'; Close settings is Ctrl+W or Esc | **M1** — as `a11-1-m1`; on Windows the default-app handoff needs Ferman registered for PDF files, which the M5 installer does, so the button stays disabled until then ([G103](DESIGN_GAPS.md#g103), Proposed with the M2 plan) | ui-only, platform |
| `a11-1w` | Settings — General<br>Windows · light · en | General pane on Windows: caption buttons, Ctrl shortcuts, default-app handoff to Windows Settings<br>*States:* same values as a11-1 | **M1** — M2 for the default-app handoff; the M1 build is `a11-1w-m1`, and this board stays the finished product | ui-only, platform |
| `a11-1b` | Settings — Language and region<br>macOS · light · en | App language (switches live), document languages, region formats (paper, units, first day of week) with a live preview<br>*States:* App language=English; Document languages=Turkish, English; Region=Türkiye; Paper=A4; Units=mm; Week starts Monday | **M1** — (l10n, locale-aware formats); document-language use by OCR/hyphenation P3/M3 | ui-only, ferman-text |
| `a11-1c` | Settings — Editing<br>macOS · light · en | Edit marking preview, policy for a font missing a character, font for new text, version retention, reflow, recovery copies; since 519d42a a Saving group ([G43](DESIGN_GAPS.md#g43))<br>*States:* Mark edited text on (PageMark preview "19.500 TL"); Missing character=Use a similar font and say so; New text font=Match the text around it; Keep versions=30 days, next to the file; Reflow on; Recovery copy every minute…; Saving: changes added to the end of the file, Optimize and clean as the only full rewrite, the recovery-copy folder with Show in Finder | **M3** — (edit marks, missing-glyph policy, reflow, recovery); Keep versions M4; Font for new text P2 | ferman-text, ferman-fonts, ferman-core |
| `a11-1d` | Settings — Fonts<br>macOS · light · en | Installed-font browser with a Turkish test string and script-coverage chips read from the font files<br>*States:* Filter=Covers Turkish; 6 rows: IBM Plex Serif and IBM Plex Sans Arabic (bundled), EB Garamond, Georgia, Noto Serif JP, Hiragino Mincho ProN (no TR) | **M4** — (pane); coverage and system-font engine from M3 | ferman-fonts |
| `a11-1e` | Settings — Signatures and certificates<br>macOS · light · en | Saved signatures, certificate list with validity, e-imza PKCS#11 driver, timestamp server, online revocation check<br>*States:* 3 saved signatures (Typed, Drawn, Initials); certs: NES smart card valid, keychain valid, email cert expired (danger); Driver=Find automatically; TSA=TÜRKSERT Zaman Damgası; Revocation check on | **M4** — (saved simple signatures); certificates, PKCS#11, TSA, revocation P3 | ferman-ops, platform |
| `a11-1f` | Settings — Text recognition<br>macOS · light · en | OCR language packs (installed or downloadable, with sizes) and the policy for scanned pages<br>*States:* installed: Türkçe 14 MB, English 12 MB, Deutsch 14 MB (Remove); downloadable: العربية 22 MB, 日本語 38 MB, Русский 18 MB, Français 13 MB (Download); Scanned pages=Offer to recognize text | **P3** | jobs, ferman-text |
| `a11-1g` | Settings — AI assistant<br>macOS · light · en | AI assistant on/off, local model vs your own API key, delete the model, clear chat history<br>*States:* Assistant on; Runs on this computer selected; Model downloaded | **P4** | jobs, ferman-text |
| `a11-1h` | Settings — Privacy<br>macOS · light · en | No-telemetry statement, every network use with its own switch, link to a network activity log<br>*States:* Updates on; Signature checks on; Timestamps on; Downloads you start on; Your AI provider off | **M4** — (pane); entries arrive with M5 updates, P3 OCR/TSA/revocation, P4 AI; the M1 build is `a11-1h-m1`, and this board stays the finished product | ui-only, platform |
| `a11-1h-m1` | Settings — Privacy, M1 build<br>macOS · light · en, tr, ar | The M1 build of `a11-1h`: nothing connects in M1, and the pane never claims a connection the app doesn't make ([G89](DESIGN_GAPS.md#g89), [G10](DESIGN_GAPS.md#g10), [G51](DESIGN_GAPS.md#g51))<br>*States:* Close settings button; all five switches off and disabled with the future-version tooltip (shown on the first); Show network activity… disabled; each switch takes its default when its feature ships (the update check on in M5, the others off until used) | **M1** — the caption keeps Signature checks disabled "until the owner decides"; [Q06](QUESTIONS.md#q06) was answered on 2026-10-16 (off until first use, phase 3) | ui-only |
| `a11-1i` | Settings — Updates<br>macOS · light · en | Update status, Check now, daily check toggle, auto-download, Stable/Beta channel, release notes<br>*States:* Up to date (success callout); Daily check on; Auto-download off; Channel=Stable | **M5** | platform |
| `a11-1j` | Settings — Keyboard shortcuts<br>macOS · light · en | Shortcut list searchable by name or keypress, presets (Ferman / Like Acrobat / Like Preview), recording with conflict detection<br>*States:* Preset=Ferman (default); row recording a new shortcut with a conflict warning; unassigned row (Apply redactions); since 519d42a ⌥⌘S belongs to Save a copy, the sidebar is ⌃⌘S and Add signature ⇧S, from one shortcut table ([G44](DESIGN_GAPS.md#g44)) | **M4** | ui-only |
| `a11-1k` | Settings — Advanced<br>macOS · light · en | GPU rendering, page cache, thumbnail generation, developer PDF object inspector, settings import/export, logs, reset<br>*States:* GPU on; Page cache=1 GB; Thumbnails=Make as needed; Inspector off | **M4** | ferman-render, ferman-core, ui-only |

### 11b · App-level

Source: `design/11b App.dc.html` · 13 artboards. The command palette, shortcuts, updates, About, toasts, the background task drawer, and the errors people actually meet. Settings are in 11a. Export 519d42a added three light boards with the EN/TR/AR switch: the family of save errors (a11-7d, a spec sheet), quitting with several unsaved documents (a11-7e) and crash recovery when the original changed (a11-7f).

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a11-2` | Command palette — Commands, pages, files, settings<br>macOS · light · en | ⌘K command palette with grouped results (Commands, Pages, Recent files, Settings), query 'imza'<br>*States:* query typed 'imza' with results in 4 groups; first item Add signature with shortcut ⇧S (⌥⌘S until 519d42a, [G44](DESIGN_GAPS.md#g44)); doc unsaved/edited behind scrim | **M4** | ui-only, ferman-text, ferman-core |
| `a11-3` | Keyboard shortcuts — Cheat sheet<br>macOS · light · en | ⌘/ keyboard shortcut cheat sheet, grouped by mode, searchable<br>*States:* default list, 8 groups (General, Navigate, Edit, Comment, Fill & Sign, Organize, Protect, Window); since 519d42a the shell's one table: Save a copy ⌥⌘S, Sidebar ⌃⌘S, Add signature ⇧S, Add bookmark ⌘B ([G44](DESIGN_GAPS.md#g44), [G82](DESIGN_GAPS.md#g82)) | **M4** | ui-only |
| `a11-4` | Update ready<br>macOS · light · en | Update-ready one-line banner<br>*States:* update downloaded, ready to install; doc saved | **M5** | platform, ferman-core |
| `a11-4b` | What’s new<br>macOS · light · en | What's new release-notes dialog for Ferman 1.5<br>*States:* 5 grouped change items + Fixed row | **M5** | ui-only |
| `a11-5` | About Ferman<br>macOS · light · en | About dialog: version/build, licence (Apache-2.0 since 519d42a, [G13](DESIGN_GAPS.md#g13)), contribute links, credits<br>*States:* default | **M5** | ui-only, platform |
| `a11-6` | Toasts<br>Spec sheet · light+dark · en | Toast notifications in four tones<br>*States:* success 'Saved'; neutral '3 pages deleted' + Undo; warning 'Font substituted' + Review; danger 'Couldn’t save' + Save as…; light; dark | **M4** | ui-only |
| `a11-6b` | Background task drawer<br>macOS · light · en | Background task drawer opened from status-bar task indicator<br>*States:* running (OCR 22%) with pause/cancel; paused batch with resume; done compress with Show; error convert; status bar inline task progress | **M4** | jobs, ferman-ops |
| `a11-7` | Error — Out of disk space<br>macOS · light · en | Save failed: disk full error dialog with recovery-copy reassurance<br>*States:* save=error in status bar; edited document; Save stays enabled for a retry ([G40](DESIGN_GAPS.md#g40), [G41](DESIGN_GAPS.md#g41), since 519d42a) | **M3** | ferman-core, platform |
| `a11-7b` | Error — File changed on disk<br>macOS · light · en | External modification detected while document has unsaved edits<br>*States:* unsaved, 3 edits; warning banner | **M3** | platform, ferman-core |
| `a11-7c` | Unsupported — XFA form<br>macOS · light · en | Unsupported XFA form: shows fallback page, read-only, explanation panel<br>*States:* read-only; tab icon file-x; thumbnail warning badge; fallback 'Please wait…' page | **M2** | ferman-core, ferman-render, platform |
| `a11-7d` | Save errors — the family<br>Spec sheet · light · en, tr, ar | Every save failure reuses the `a11-7` layout: what happened, that the edits are kept, Try again and Save as… ([G40](DESIGN_GAPS.md#g40))<br>*States:* four dialogs 'Couldn't save "Kira sözleşmesi.pdf"': permission denied; locked by another app; couldn't replace the original (the temporary file was written, the original is unchanged); drive disconnected ('Ortak'); the caption adds that the tab keeps its unsaved dot and the status bar says Couldn't save | **M3** | ferman-core (temporary file and atomic rename), platform |
| `a11-7e` | Quit with several unsaved documents<br>macOS · light · en, tr, ar | Quitting with unsaved changes in more than one document asks once, built from `a1-10b` ([G40](DESIGN_GAPS.md#g40))<br>*States:* dialog 'Save changes to 3 documents before quitting?', one checked row per document (3 edits, 2 comments, 1 edit); Quit without saving at the start, Cancel, Save and quit; any failure stops the quit and shows its error; Windows orders Save and quit, Quit without saving, Cancel | **M3** | ferman-core, ui-only |
| `a11-7f` | Crash recovery — the original changed<br>macOS · light · en, tr, ar | Ferman records each original's hash with its recovery copy; an original that changed opens the restored version under a new name ([G40](DESIGN_GAPS.md#g40))<br>*States:* the `a1-12` dialog over Start, 2 documents checked; 'e-Arşiv fatura 4187.pdf' with the warning badge 'Changed on disk' and the note that it opens as 'e-Arşiv fatura 4187 (recovered).pdf'; the matching row restores as in `a1-12`; Discard, Open 2 documents | **M3** | ferman-core (recovery hash), platform |

### 12 · Localization validation

Source: `design/12 Localization.dc.html` · 14 artboards. The same editor state in Turkish, German, Arabic and Japanese, and the start screen in Arabic and German. The shell is built with logical properties, so Arabic mirrors the chrome while the PDF page keeps its own direction. It opens with an unnumbered "Rules applied everywhere" block: a locale formats table (en-US, tr, de, ar, ja, en-UK showing date/time, number, paper, units and font size), a "Turkish capitals" card (lang="tr" uppercase is correct, English rules are shown as wrong) and a "Long labels" rule (+40% expansion). Export 519d42a ends the block with the board `a12-0`, a region-format table from CLDR without a frame or a language switch.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a12-0` | Region formats, from CLDR<br>Spec sheet · light · en | Numbers, dates, file sizes, paper sizes, units and percentages follow the region in Settings › Language and region, never the UI language ([G34](DESIGN_GAPS.md#g34))<br>*States:* six regions with date (2 Oct), time, number, percent and font size: Türkiye tr-TR (the Turkish goldens; 02.10.2026, 18.500,5, %100), United Kingdom en-GB (the English goldens), United States en-US (2:32 PM), Germany de-DE (2.10.2026, 100 %), Saudi Arabia ar-SA (the Arabic goldens; Arabic-Indic digits), United Arab Emirates ar-AE (Latin digits); boards that show another format are read as drawn for another region | **M2** — the Turkish percent sign first in the zoom field and status bar; region formats and the region per golden language exist from M1 | ui-only |
| `a12-1tr` | Editor — Türkçe<br>macOS · light · tr | Main editor in Edit mode, localized to Turkish (shell, sidebar, edit panel, locale number formats)<br>*States:* Edit mode; paragraph p4 selected and edited; unsaved (dot on tab + status); 3 doc tabs (tabs3); Pages sidebar tab, page 1 of 3; redo disabled | **M3** — l10n infra + tr strings M1 | ui-only, ferman-text, ferman-fonts, ferman-render |
| `a12-1de` | Editor — Deutsch<br>Windows · light · de | Main editor in Edit mode in German: stress test for the longest labels<br>*States:* Edit mode; p4 selected/edited; unsaved; 3 tabs; Windows caption buttons; Ctrl shortcuts | **M3** — de locale not assigned in roadmap | ui-only, ferman-text, ferman-fonts, ferman-render |
| `a12-1ar` | Editor — العربية, full right-to-left<br>macOS · light · ar · RTL | Main editor in Edit mode in Arabic, full RTL chrome mirroring over an LTR Turkish PDF<br>*States:* Edit mode; p4 selected/edited; unsaved; 3 tabs; mirrored chrome; Arabic-Indic digits | **M3** — RTL/ar l10n M1 | ui-only, ferman-text, ferman-fonts, ferman-render |
| `a12-1ja` | Editor — 日本語<br>macOS · light · ja | Main editor in Edit mode in Japanese (CJK UI font and leading)<br>*States:* Edit mode; p4 selected/edited; unsaved; 3 tabs | **M3** — ja locale not assigned in roadmap | ui-only, ferman-text, ferman-fonts, ferman-render |
| `a12-2a` | Start — العربية<br>macOS · light · ar · RTL | Start screen in Arabic RTL (open/create/combine/scan actions, quick tools, pinned and recent files)<br>*States:* populated recent/pinned; grid view (default) | **M1** — recent files M2 | ui-only, platform, ferman-render |
| `a12-2b` | Start — Deutsch<br>Windows · light · de | Start screen in German on Windows (long action descriptions, DE date format)<br>*States:* populated recent/pinned; grid view | **M1** — de locale unassigned; recent files M2 | ui-only, platform, ferman-render |
| `a12-2c` | Settings — العربية, right to left<br>macOS · light · ar · RTL | Settings > Language and region pane in Arabic RTL (app language, document languages, region formats, paper, units, first weekday, examples)<br>*States:* Language and region pane; region = Türkiye | **M1** — settings skeleton + l10n; full settings M4 | ui-only, platform |
| `a12-2d` | Settings — Deutsch<br>Windows · light · de | Settings > Language and region pane in German (long nav labels in the 240 px list)<br>*States:* Language and region pane; Windows chrome | **M1** — settings skeleton; de locale unassigned | ui-only, platform |
| `a12-3` | Home — العربية<br>iOS · light · ar · RTL | Mobile home in Arabic RTL (search, tool grid, pinned/recent docs, tab bar)<br>*States:* populated; large title 'Ferman'; tab = home | **P5** | ui-only, platform, ferman-render |
| `a12-3b` | Reader — العربية<br>iOS · light · ar · RTL | Mobile reader in Arabic with mirrored page navigation over an LTR Turkish document<br>*States:* page 1 of 3 ("الصفحة ١ من ٣"); back = "رجوع"; no tab bar | **P5** | ferman-render, ui-only, platform |
| `a12-3c` | Fill — العربية<br>Android · light · ar · RTL | Mobile form filling in Arabic UI on an LTR Turkish form, with field navigator and keyboard<br>*States:* field 3 of 20 focused ('Adı'); typing 'AYŞ'; 13 required left (danger); Arabic keyboard up; action 'إنهاء' | **P5** | ferman-ops, ferman-render, ui-only, platform |
| `a12-3d` | Reader — Türkçe<br>Android · light · tr | Mobile reader in Turkish<br>*States:* page "Sayfa 1 / 3"; Önceki/Sonraki; nav arrow | **P5** | ferman-render, ui-only, platform |
| `a12-3e` | Fill — Türkçe<br>iOS · light · tr | Mobile form filling in Turkish with Turkish keyboard<br>*States:* field 3/20 focused ('Adı'); typing 'AYŞ'; 13 required left; Turkish keyboard caps; action 'Bitir' | **P5** | ferman-ops, ferman-render, ui-only, platform |

### 13a · Mobile — start, files, reading, editing

Source: `design/13a Mobile core.dc.html` · 20 artboards. iPhone 16 (393 × 852) with iOS conventions (navigation bar, tab bar, sheets) and Pixel (412 × 915) with Material conventions (top app bar, navigation bar, bottom sheets, FAB). Same Ferman tokens at touch density: every target is at least 44 pt / 48 dp. Tasks continue in 13b (Fill & Sign, Scan, Organize/Convert/Protect/Share/Assistant, Settings, States). Every artboard is FmBoard(bare) > FmPhone. lang=en and dir=ltr throughout (FmBoard defaults). Turkish appears only in document content and file names.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a13-1` | Onboarding 1 of 3<br>iOS · light · en | First-run onboarding, step 1: edit any PDF like a document<br>*States:* step 1 of 3; live text-edit specimen (caret, edited mark) | **P5** — (mobile app); desktop onboarding parity M1 | ui-only |
| `a13-1b` | Language<br>Android · light · en | First-run app language picker<br>*States:* system language (English) preselected; radio list of 12 languages with native names, RTL names in rtl | **P5** — (mobile app); l10n M1 | ui-only |
| `a13-1c` | Permission — Camera<br>iOS · light · en | Just-in-time camera permission explainer before the OS prompt<br>*States:* pre-prompt explainer | **P5** — mobile scan | platform |
| `a13-2` | Home<br>iOS · light · en | Mobile home: search, 8 quick tools, pinned, recent, open-from sources<br>*States:* populated; recent with badges Edited/Form/Signed | **P5** — (mobile app); recent files M2, tools M4/P2/P3 | ferman-render, ferman-core, platform |
| `a13-2b` | Home<br>iOS · dark · en | Mobile home, dark theme<br>*States:* populated; dark | **P5** — (mobile app); themes M1 | ferman-render, ferman-core, platform |
| `a13-2c` | Home<br>Android · light · en | Mobile home, Android/Material variant with FAB<br>*States:* populated; FAB 'Open a file' | **P5** — (mobile app); recent files M2 | ferman-render, ferman-core, platform |
| `a13-2d` | Home<br>Android · dark · en | Mobile home, Android dark<br>*States:* populated; dark | **P5** — (mobile app); themes M1 | ferman-render, ferman-core, platform |
| `a13-2e` | Home — Empty<br>Android · light · en | Mobile home empty state (no recent files)<br>*States:* empty | **P5** — (mobile app); start screen M1 | platform, ui-only |
| `a13-3` | Files — Folders, sort, multi-select<br>iOS · light · en | File browser with folders, sort/filter and multi-select batch actions<br>*States:* select mode, 3 selected; sort 'Last opened'; filter 'PDFs' | **P5** — (mobile app); combine/compress M4 | platform, ferman-ops, jobs, ferman-render |
| `a13-3b` | Files — Details sheet<br>Android · light · en | Per-file details and actions bottom sheet<br>*States:* sheet open over list; file badges Signed + 9 comments | **P5** — (mobile app); document properties M2, compress M4 | ferman-core, ferman-render, ferman-ops, platform |
| `a13-4` | Reader — Continuous scroll, thumbnail strip<br>iOS · light · en | Mobile reader: continuous scroll, page strip, outline and read-aloud entry<br>*States:* bars visible; page 1 of 3 current | **P5** — (mobile app); rendering/thumbnails/outline M2 | ferman-render, ferman-core, ferman-text, platform |
| `a13-4b` | Reader<br>iOS · dark · en | Mobile reader, dark theme<br>*States:* dark; page stays white | **P5** — (mobile app); themes M1 | ferman-render |
| `a13-4c` | Reader — Search results sheet<br>Android · light · en | In-document search with results grouped by page; Turkish case folding<br>*States:* 7 matches on 2 pages; first match selected; half-height sheet | **P5** — (mobile app); search M2 | ferman-text, ferman-render |
| `a13-4d` | Reader — Night mode and read aloud<br>Android · dark · en | Night (inverted page) mode plus read-aloud player<br>*States:* night mode on; read aloud playing, sentence 9 of 31; speed 1× | **P5** — (mobile app); read aloud not on roadmap (nearest P4 accessibility) | ferman-render, ferman-text, platform |
| `a13-5` | Edit — Keyboard open, floating format bar<br>iOS · light · en | Click-to-edit text block on phone with format bar<br>*States:* caret editing in block p4; edited mark; keyboard tr with suggestions TL’yi/TL’dir/TL’ye; alignment active | **P5** — (mobile app); text editing M3 | ferman-text, ferman-fonts, ferman-core, platform |
| `a13-5b` | Edit — Keyboard open<br>iOS · dark · en | Mobile text editing, dark theme<br>*States:* dark; caret editing; edited mark | **P5** — (mobile app); text editing M3 | ferman-text, ferman-fonts |
| `a13-5c` | Edit — Missing glyph and overflow<br>Android · light · en | Missing-glyph notice and text-overflow choices on phone<br>*States:* missing glyph 'ğ' (missing-glyph page mark); overflow: 1 line hidden; both banners stacked | **P5** — (mobile app); glyph/overflow handling M3 | ferman-fonts, ferman-text |
| `a13-6` | Add — Image, text, link; touch handles<br>iOS · light · en | Add text/image/link/signature/date; touch handles for placed objects<br>*States:* image placed and selected with corner + rotate handles; Add menu open; floating bar Replace/Crop/Alt text/Delete | **P5** — (mobile app); add text/images P2, signature M4 | ferman-ops, ferman-core, ferman-fonts, platform |
| `a13-7` | Annotate — Pen, highlight, shapes, palm rejection<br>Android · light · en | Annotation tools palette with stylus-only drawing<br>*States:* Pen active; blue swatch selected, 2 pt; Draw only with stylus = on; freehand stroke drawn | **P5** — (mobile app); annotations M4 | ferman-ops, ferman-text, platform |
| `a13-7b` | Annotate — Comment thread sheet<br>iOS · light · en | Comment thread for a markup: reply, mention, resolve<br>*States:* thread with 3 replies incl. @mention; unresolved | **P5** — (mobile app); comments M4 | ferman-ops, ferman-core |

### 13b · Mobile — sign, scan, organize, protect, share

Source: `design/13b Mobile tasks.dc.html` · 18 artboards. Task flows on iPhone 16 and Pixel, then settings and system states. Starts in 13a (Mobile core). All artboards are FmBoard + FmPhone; every frame is lang=en dir=ltr (FmBoard defaults), and document content is Turkish.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a13-8` | Fill — Field by field, keyboard toolbar<br>iOS · light · en | Form filling one field at a time, with a keyboard accessory toolbar<br>*States:* active field 'Adı' focused, typing 'AYŞ'; Turkish keyboard, caps on, suggestions AYŞE/AYŞEGÜL/AYŞEN; status 'Field 3 of 20 · Adı' / '13 required left' (danger); nav actions Sign + bold Finish | **P5** — (mobile); form filling M4 | ferman-ops, ferman-render, ferman-fonts, platform |
| `a13-8b` | Fill — Field by field<br>iOS · dark · en | Dark-theme version of field-by-field filling<br>*States:* same as 13.8a in dark; dark keyboard | **P5** — (mobile); form filling M4 | ferman-ops, ferman-render, platform |
| `a13-8c` | Fill — Date and dropdown pickers<br>Android · light · en | Choice-field picker as searchable bottom sheet; date fields via picker<br>*States:* 'İl' dropdown sheet open over scrim; search 'ist' typed; İstanbul selected (check), Isparta/Kastamonu/Kırıkkale listed | **P5** — (mobile); form filling M4 | ferman-ops, ferman-text, platform |
| `a13-8d` | Sign — Full-screen landscape capture<br>iOS · light · en | Drawn signature capture pad<br>*States:* signature drawn on baseline with × mark; navy ink selected (navy/black); 'Save for next time' switch on; Cancel / 'Sign · Ayşe Yılmaz' / Done | **P5** — (mobile); simple signatures M4 | ferman-ops, platform |
| `a13-8e` | Sign — Saved signature placed<br>Android · light · en | Placing a saved signature into a field, resize/rotate<br>*States:* signature 'Ayşe Yılmaz' placed and selected with 4 corner handles; tray 'Saved on this phone' (2 saved + New); all required filled; actions Undo + Finish | **P5** — (mobile); simple signatures M4 | ferman-ops, ferman-render, platform |
| `a13-8f` | e-imza — Use your token on desktop, or NFC<br>iOS · light · en | Qualified e-imza on phone: USB token not supported, NFC ID card option<br>*States:* USB token card: 'Your token works on a computer' + 'Send to my computer…'; NFC option highlighted; waiting: 'Hold your card to the iPhone…' with spinner | **P5** — (mobile); Turkish e-imza P3 | ferman-ops, platform |
| `a13-9` | Scan — Edge detection, auto-capture<br>iOS · dark · en | Document scanner camera with live edge detection and auto-capture<br>*States:* edges traced live; 'Hold still · capturing' with shutter ring ~60%; batch count 3; Flash, Auto toggle, Cancel, Done | **P5** — (mobile); OCR/scan P3 | platform, jobs |
| `a13-9b` | Scan — Review: crop, rotate, filter, reorder<br>Android · light · en | Scan batch review and save as one PDF with OCR<br>*States:* title '3 pages', page 2 selected; tools Crop/Rotate/Retake/Reorder; filter B&W selected (Auto/B&W/Greyscale/Colour); 'Recognize text · Türkçe' on; 'Save PDF · 3 pages' | **P5** — (mobile); OCR P3 | jobs, ferman-core, ferman-ops, ferman-text |
| `a13-10` | Organize — Page grid<br>Android · light · en | Page grid with multi-select, drag reorder and action bar<br>*States:* '2 selected' (pages 4,5); insertion bar during drag; bar Rotate/Extract/Duplicate/Delete (danger); overflow 'More: insert, combine, split' | **P5** — (mobile); organize pages M4 | ferman-ops, ferman-render, ferman-core |
| `a13-11` | Convert — Target, progress, share<br>iOS · light · en | PDF to Office/image/text conversion with progress and result<br>*States:* source 'Kira sözleşmesi.pdf · 3 pages · 284 KB'; Word selected (Excel, PowerPoint, Images, Text); TaskProgress 'Converting to Word' page 2 of 3, 66%; success card 'Kira sözleşmesi.docx' with Share/Open | **P5** — (mobile); PDF->Office P3 | jobs, ferman-text, ferman-core, platform |
| `a13-12` | Protect — Redaction with finger and patterns<br>Android · light · en | Redaction by finger marking and pattern search<br>*States:* 3 pending marks as red hatching (DocEkstre redact=pending); patterns T.C. Kimlik No · 1, IBAN · 1, Phone · 1 on; E-mail · 0 off; 'Apply 3 redactions…' danger button | **P5** — (mobile); redaction P2 | ferman-ops, ferman-text, ferman-core |
| `a13-13` | Share — Export options and share sheet<br>iOS · light · en | Pre-share export options (format, compression, comments)<br>*States:* sheet over FmMReader with scrim; Format PDF selected (PDF/PDF/A/Images); Size 'Smaller ≈ 120 KB' selected (Original 284 KB, Smallest ≈ 60 KB); 'Include comments (9)' on | **P5** — (mobile); compress M4, PDF/A P4 | ferman-ops, ferman-core, jobs, platform |
| `a13-14` | Assistant sheet<br>Android · light · en | Local AI assistant Q&A about the document with page citations<br>*States:* badge 'On this phone' (local model); quick chips Summarize / Dates and amounts / Draft a reply; Turkish Q&A with citation 's. 1 · Madde 5'; input 'Ask about this document' | **P5** — (mobile); local AI assistant P4 | ferman-text, platform |
| `a13-15` | Settings<br>iOS · light · en | Top-level mobile settings<br>*States:* Language and region English, Theme System, Fonts 86; DOCUMENTS: Signatures 2 saved, Text recognition 3 languages, Assistant Off; PRIVACY: Privacy 'No data collected', About and licence 1.4.2; Settings tab active | **P5** — (mobile); settings M1/M4 | ui-only, ferman-fonts, platform |
| `a13-15b` | Settings — Language and region<br>Android · dark · en | Language and region settings with format preview<br>*States:* App language 'English · switches right away'; Document languages 'Türkçe, English · for OCR and spell-check'; Formats 'Türkiye · 13.10.2026 · 18.500,50 · 10,5 pt', Paper size A4, Units Millimetres; 'Use the phone’s sett… | **P5** — (mobile); l10n M1 | ui-only, platform |
| `a13-16` | Loading a large file, offline<br>iOS · light · en | Progressive open of large file and offline notice<br>*States:* offline banner; page 1 rendered, page 2 spinner; TaskProgress 'Opening 2,400 pages' 'Page 840 · about 30 seconds left' 35% | **P5** — (mobile); rendering M2 | ferman-core, ferman-render, jobs, platform |
| `a13-16b` | Large file, password, repaired<br>Android · light · en | Open-interrupt states: large file warning, password, repair notice<br>*States:* 'This file is 180 MB' with Open / Compress first; password field with error; 'Ferman repaired this file' info card | **P5** — (mobile); password/repair M2 | ferman-core, ferman-ops, platform |
| `a13-16c` | Out of storage, background task notification<br>Android · dark · en | Out-of-storage save failure and background OCR notification<br>*States:* alertdialog 'Not enough storage' with Later / Open storage settings; notification 'Recognizing text · page 14 of 64' 22% with Pause/Cancel; FmMHome behind scrim | **P5** — (mobile); background tasks/autosave M4 | jobs, ferman-core, platform |

### 14 · Tablet and web

Source: `design/14 Tablet and web.dc.html` · 7 artboards. Tablets run the full desktop editor under touch density: the same shell, every target at least 44 pt, collapsible sidebars, a Pencil and stylus palette and hardware-keyboard shortcuts. The web app is the desktop editor in a browser tab, with honest notes where a feature needs the desktop app. The web address is a placeholder.

| ID | Screen | Feature and states shown | Milestone | Engine capability |
|---|---|---|---|---|
| `a14-1` | iPad Pro 13″ — Full editor, landscape<br>Tablet · light · en | Full desktop shell on iPad at touch density in Edit mode, with a floating Pencil palette<br>*States:* edit mode, text block p4 selected and edited; unsaved, 3 doc tabs; Pages sidebar, page 1; Pencil palette: Pen active, blue ink selected; 'Pencil only / Finger scrolls' | **P5** — tablet app; builds on M1 shell, M3 text edit, M4 annotations | ui-only (touch density, Pencil palette), platform (iPadOS touch/Pencil input), ferman-text (tap hit testing, caret), ferman-render |
| `a14-1b` | iPad — Portrait, sidebars collapsed, annotating<br>Tablet · dark · en | Portrait Comment mode with freehand Pencil ink; sidebar and panel collapsed to toggles; 3x2 floating Pencil tool grid<br>*States:* comment mode, pen tool, blue ink; sidebar=false, panel=false; handwritten ink strokes on page; page zoom 1.15; unsaved, 1 tab | **P5** — tablet; ink annotations M4 | ferman-ops (ink annotations), ferman-render, platform (Pencil, Scribble, squeeze), ui-only (overlay sidebars, palette) |
| `a14-1c` | iPad — Two documents in split view<br>Tablet · light · en | Two Ferman windows side by side (Kira sözleşmesi + Hesap ekstresi); drag text or pages between them to copy<br>*States:* view mode both panes, saved; sidebar/panel hidden, tool-row none; zoom 0.8; DocEkstre rent row highlighted | **P5** — tablet; page copy needs M4 organize/combine, text drop needs P2 add text | platform (iPadOS multi-window, drag and drop), ferman-ops (copy pages between docs), ferman-text (copy text), ferman-core |
| `a14-1d` | Android tablet — Hardware keyboard shortcuts<br>Tablet · dark · en | Organize mode page grid with a hold-Ctrl keyboard-shortcut overlay<br>*States:* organize mode, 64 pages, pages 4-5 selected; shortcut overlay 'Organize · shortcuts' (9 items); unsaved, sidebar hidden | **P5** — tablet; organize and command palette M4 | ferman-ops (rotate/duplicate/extract/delete/move/insert pages), ferman-render (thumbnails), platform (Android hardware keyboard, Shortcuts Helper), ui-only (overlay) |
| `a14-2` | Web — Editor in a browser tab<br>Web · light · en | Full editor in a browser tab at app.ferman.org, with the engine compiled to WebAssembly and an install icon in the address bar<br>*States:* edit mode, text block p4 selected and edited; unsaved, 3 tabs; browser chrome: app.ferman.org, 'Install Ferman' icon | **P5** — web build | ferman-core/render/text/fonts compiled to WASM, platform (web: in-memory files, shortcut remap) |
| `a14-2b` | Web — Open from device<br>Web · light · en | Web start screen: drop zone, recent files remembered by name only, one-time PWA install prompt<br>*States:* drop zone idle; 3 recent files, each with 'Choose again…'; install prompt (Not now / Install) | **P5** — web; open/drag-drop/recent M2 | platform (browser File API, drag-drop, PWA install/file handling), ferman-core (open), ui-only |
| `a14-2c` | Web — Feature that needs the desktop app<br>Web · light · en | e-imza unavailable in browser: dialog lists what works on web vs what needs desktop, with handoff to the desktop app<br>*States:* Fill & Sign mode, e-imza tool active, page 3; saved; scrim + inline Dialog (icon usb) | **P5** — web; e-imza/cert signatures P3, simple signature M4 | platform (no PKCS#11/cert store in browser; desktop handoff), ferman-ops (signatures), jobs (batch), ui-only |

## 6. Design system

The design system lives in [`_ds/ferman-design-system-27832349-21bc-410e-acd5-6ab20d2f87e2/`](../design/_ds/ferman-design-system-27832349-21bc-410e-acd5-6ab20d2f87e2/), with additions in
[`ds-additions/`](../design/ds-additions/) documented by
[`DS additions.dc.html`](../design/DS%20additions.dc.html).

### Tokens

The tokens are CSS custom properties in `tokens/`: `colors.css`, `typography.css`, `spacing.css` and
`effects.css`. `base.css` and `fonts.css` declare none. `ds-additions/fm-additions.css` loads after
them and wins the cascade. [ADR 0012](adr/0012-design-token-pipeline.md) turns all of them into
`app/lib/design/tokens.g.dart`, exposed through `ThemeExtension`. Widgets never hardcode colours,
sizes, radii or durations (brief §6).

| File | Default (`:root`) | Overrides |
|---|---|---|
| `colors.css` | 132 (63 ramp, 69 semantic) | 48 dark, 1 dim page |
| `typography.css` | 41 | none |
| `spacing.css` | 34 | 12 touch density |
| `effects.css` | 31 | 5 dark (shadows), 4 reduced motion |
| `fm-additions.css` | 34 (31 new, 3 overrides) | 5 CJK type roles, 1 dark |

That makes 348 declarations and 269 unique names: 238 in the DS and 31 in the additions. They fall
into the 44 groups listed below: colour ramps (ink, seal, paper, soot, status), the annotation
palette, semantic surfaces, text, icons, borders, accent and status colours, on-page editing states,
the page, font families, weights, size and leading pairs, tracking, numerals, type roles, the space
scale, desktop controls, app layout, radii, border widths, elevation, focus, motion and z-index.

The tokens describe six environments:

- **Light** is the default (`:root`). There is no explicit light rule.
- **Dark** (`[data-theme="dark"]`) redefines 48 semantic colours and 5 shadows. Ramps, the annotation
  palette, on-page editing marks and the page do not change: the PDF page stays paper-white in both
  themes.
- **Dim page** (`[data-page="dim"]`) sets only `--page-filter`, a reading-comfort filter applied to
  the page, never to chrome.
- **Touch** (`[data-density="touch"]`) raises 12 control, icon and bar sizes so every target is at
  least 44 px. Tablets and the mobile apps use it.
- **Reduced motion** sets the four durations to 0 ms.
- **CJK** (`[lang|="ja"]`, `zh`, `ko`, in the additions) gives five type roles taller leading and
  turns off synthetic bold and italic.

**The additions are not merged into the DS tokens.** `fm-additions.css` defines 31 tokens that are in
neither the DS token files nor the manifest; 22 are applied through `var()` by boards, building blocks
or the bundle. Nine are never applied: `--editbox-meta-h`, `--thumb-badge` and `--doctab-h`, which only
the Index and 00 Fixes name in prose, and 6 of the 7 mobile tokens; only `--sheet-radius` is used, in
13a and 13b.
It also overrides 3 DS tokens: `--edit-changed` and `--edit-changed-bg` change from teal to ink, and
`--font-ui` gains the full script stack. A generator that read only `tokens/*.css` would get these
values wrong, so it reads the additions last ([G05](DESIGN_GAPS.md#g05)). The additions' `--doctab-h` (28 px) also
disagrees with the 32 px tab height hard-coded in `FmWindow`.

Mapping to Flutter needs care with about 40 rgba overlays, multi-layer shadows with hairline rings,
the two-layer and inset focus rings, cubic-bezier curves, the CSS `font` shorthand, `var()` chains
resolved per theme, the `--page-filter` colour matrix, hatch patterns and kebab-case names that mix
kinds (`--text-*`, `--icon-*`, `--border-*`). The generated notes at the end of the token reference
cover each one. One of their options is overruled by a decision in section 8: IBM Plex ships as
IBM's static TTFs, not as a variable font. The app never fetches fonts at run time (no
`google_fonts` package, no Google Fonts import). Class names in the notes, such as `FermanColors` or
`FermanPageColors`, were M0 suggestions; the generated names are in
[ADR 0012](adr/0012-design-token-pipeline.md#output) (`FermanColorTokens`, `FermanPageColorTokens` and
so on).

#### Token reference (generated)

Counts: Custom-property declarations, verified by parsing every block. colors.css: 132 in :root (63 base-ramp + 69 semantic), 48 in [data-theme="dark"], 1 in [data-page="dim"]. typography.css: 41 in :root, no dark. spacing.css: 34 in :root, 12 in [data-density="touch"]. effects.css: 31 in :root, 5 in [data-theme="dark"] (shadows), 4 in @media (prefers-reduced-motion: reduce) :root. base.css: 0 declarations (it only uses tokens and defines 5 @keyframes). fonts.css: 0 custom properties (33 @font-face rules in 11 family/weight/style combinations). fm-additions.css: 34 in :root (31 new names plus 3 overrides of DS tokens: --edit-changed, --edit-changed-bg, --font-ui), 5 in [lang\|="ja"],[lang\|="zh"],[lang\|="ko"] (type-role leading overrides), 1 in [data-theme="dark"] (--win-close-hover, same value as light). Total declarations: 348. Unique token names: 269 (238 DS + 31 additions). By kind, after the cascade: about 120 colours (63 ramp + 57 semantic/on-page incl. additions), 5 shadow lists + 2 focus shadows + 1 outline, 9 font stacks after additions (font-ui, arabic, mono, brand, doc-sample, doc-cjk, hand-1/2/3), 10 type roles, 3 weights, 18 size/leading, 3 tracking, 2 font-feature, about 60 dimensions (space 15, controls/icons 9, layout 10, radii 6+sheet-radius, border widths 2, focus offset, additions sizes 15), 4 durations, 3 easings, 7 z-indices, 1 filter. "DS additions.dc.html" defines no tokens: its Colour tokens section documents 10 tokens and its Type additions section documents 2 font entries (--font-ui extended, --font-hand-1/2/3).

#### `colors.css`

**Ink ramp (single accent, Lacivert iron-gall ink blue) - theme-invariant, not overridden in dark** (10)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--ink-50` | `#EEF2FC` |  | light surface-selected, accent-subtle, info-bg |
| `--ink-100` | `#DCE4F8` |  | light surface-selected-strong, accent-subtle-hover |
| `--ink-200` | `#B8C8F0` |  | light info-border |
| `--ink-300` | `#8BA4E4` |  | accent-border, form-field-border; dark text-accent/text-link/info |
| `--ink-400` | `#5D7FD6` |  | dark border-focus, accent-border; rgb(93,127,214) is the base of the dark rgba accent tints |
| `--ink-500` | `#3A60C6` |  | border-focus, edit-box, form-field-focus; dark accent; rgb(58,96,198) is the base of the on-page edit tints |
| `--ink-600` | `#2A4DAF` |  | accent, text-accent, text-link, info; edit-changed/edit-mark (additions); dark accent-pressed |
| `--ink-700` | `#213E8E` |  | accent-hover, edit-caret |
| `--ink-800` | `#1A3170` |  | accent-pressed |
| `--ink-900` | `#142553` |  | darkest ink, no semantic alias |

**Seal ramp (vermilion wax/ink seal) - brand moments and stamps only, never UI chrome; declared in source order 100, 500, 600, 300** (4)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--seal-100` | `#F8E3DF` |  | seal tint |
| `--seal-500` | `#B5372A` |  | seal primary |
| `--seal-600` | `#962C21` |  | seal dark |
| `--seal-300` | `#E0675A` |  | seal light (declared last) |

**Paper ramp (warm neutrals, light theme) - theme-invariant** (14)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--paper-0` | `#FFFFFF` |  | surface-raised (light) |
| `--paper-25` | `#FCFBF9` |  | text-inverse (light) |
| `--paper-50` | `#F7F6F3` |  | surface-panel (light) |
| `--paper-100` | `#F0EEEA` |  | surface-sunken (light) |
| `--paper-150` | `#E8E5DF` |  | surface-canvas (light), behind the PDF page |
| `--paper-200` | `#DEDAD2` |  | border-default (light) |
| `--paper-300` | `#C9C4BA` |  | border-strong (light) |
| `--paper-400` | `#A39E94` |  | text-disabled, icon-disabled (light) |
| `--paper-500` | `#8A857C` |  | checkbox hover border (harness); no semantic alias |
| `--paper-600` | `#6F6A62` |  | text-tertiary, icon-secondary (light) |
| `--paper-700` | `#57534C` |  | text-secondary (light) |
| `--paper-800` | `#3A3732` |  | icon-primary (light) |
| `--paper-900` | `#1F1D1A` |  | text-primary, surface-inverse (light); text-inverse (dark); rgb(31,29,26) is the base of the light hover/pressed overla… |
| `--paper-950` | `#141311` |  | rgb(20,19,17) is the base of the light shadows, scrim and page-border |

**Soot ramp (warm charcoals, dark theme) - theme-invariant** (12)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--soot-0` | `#0E0E0D` |  | surface-canvas (dark) |
| `--soot-50` | `#161615` |  | surface-panel (dark) |
| `--soot-100` | `#1D1C1B` |  | surface-raised (dark) |
| `--soot-150` | `#252422` |  | no semantic alias |
| `--soot-200` | `#2E2D2A` |  | border-subtle (dark); selected modetab/segment bg in dark (components) |
| `--soot-300` | `#3B3936` |  | border-default (dark) |
| `--soot-400` | `#57544F` |  | border-strong (dark) |
| `--soot-500` | `#7A766F` |  | text-disabled, icon-disabled (dark) |
| `--soot-600` | `#9A958D` |  | text-tertiary, icon-secondary (dark) |
| `--soot-700` | `#BDB8AF` |  | text-secondary (dark) |
| `--soot-800` | `#E3DFD8` |  | icon-primary (dark) |
| `--soot-900` | `#F2EFEA` |  | text-primary, surface-inverse (dark); rgb(242,239,234) is the base of the dark hover/pressed overlays |

**Status ramps (green / amber / red) - theme-invariant; source order per hue 50,200,500,600\|700,300** (15)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--green-50` | `#E7F4EC` |  | success-bg (light) |
| `--green-200` | `#A9D8BC` |  | success-border (light) |
| `--green-500` | `#2E9A5C` |  | success-solid (both), diff-added-line |
| `--green-600` | `#1E7A46` |  | success (light) |
| `--green-300` | `#4CC07E` |  | success (dark) |
| `--amber-50` | `#FDF3E1` |  | warning-bg (light) |
| `--amber-200` | `#F0CD8F` |  | warning-border (light) |
| `--amber-500` | `#D98A0B` |  | warning-solid (both), glyph-missing, overflow-mark, ocr-low, diff-changed-line |
| `--amber-700` | `#9A5B00` |  | warning (light) |
| `--amber-300` | `#F0B04A` |  | warning (dark) |
| `--red-50` | `#FCEBE9` |  | danger-bg (light) |
| `--red-200` | `#F2B8B1` |  | danger-border (light) |
| `--red-500` | `#D93A2B` |  | diff-removed-line; same hex as --annot-red |
| `--red-600` | `#B42318` |  | danger, danger-solid (light), redact-pending, form-field-required |
| `--red-300` | `#F07A6E` |  | danger (dark) |

**Annotation palette - document colours, identical in both themes** (8)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--annot-yellow` | `#FFE066` |  | highlight yellow |
| `--annot-green` | `#A8E6A1` |  | highlight green |
| `--annot-blue` | `#A8D1FF` |  | highlight blue |
| `--annot-pink` | `#FFB3C7` |  | highlight pink |
| `--annot-orange` | `#FFC58A` |  | highlight orange |
| `--annot-ink` | `#1F1D1A` |  | pen/text ink black (= paper-900) |
| `--annot-red` | `#D93A2B` |  | pen red (= red-500) |
| `--annot-blue-ink` | `#2A4DAF` |  | pen blue (= ink-600) |

**Semantic - surfaces** (10)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--surface-canvas` | `var(--paper-150)` | `var(--soot-0)` | behind the PDF page. resolved #E8E5DF / #0E0E0D |
| `--surface-panel` | `var(--paper-50)` | `var(--soot-50)` | toolbars, sidebars, properties; .fm-root background. #F7F6F3 / #161615 |
| `--surface-raised` | `var(--paper-0)` | `var(--soot-100)` | menus, popovers, dialogs, inputs; also the gap colour in --focus-ring. #FFFFFF / #1D1C1B |
| `--surface-sunken` | `var(--paper-100)` | `#121211` | segmented tracks, wells. #F0EEEA / #121211 (dark is a literal, not a ramp step) |
| `--surface-hover` | `rgba(31, 29, 26, 0.06)` | `rgba(242, 239, 234, 0.07)` | overlay on top of a surface. 0x0F1F1D1A / 0x12F2EFEA |
| `--surface-pressed` | `rgba(31, 29, 26, 0.10)` | `rgba(242, 239, 234, 0.11)` | overlay. 0x1A1F1D1A / 0x1CF2EFEA |
| `--surface-selected` | `var(--ink-50)` | `rgba(93, 127, 214, 0.18)` | #EEF2FC / 0x2E5D7FD6 (opaque in light, translucent in dark) |
| `--surface-selected-strong` | `var(--ink-100)` | `rgba(93, 127, 214, 0.28)` | #DCE4F8 / 0x475D7FD6 |
| `--surface-inverse` | `var(--paper-900)` | `var(--soot-900)` | tooltips/toasts. #1F1D1A / #F2EFEA |
| `--surface-scrim` | `rgba(20, 19, 17, 0.38)` | `rgba(0, 0, 0, 0.56)` | modal backdrop. 0x61141311 / 0x8F000000 |

**Semantic - text** (8)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--text-primary` | `var(--paper-900)` | `var(--soot-900)` | #1F1D1A / #F2EFEA; .fm-root color |
| `--text-secondary` | `var(--paper-700)` | `var(--soot-700)` | #57534C / #BDB8AF |
| `--text-tertiary` | `var(--paper-600)` | `var(--soot-600)` | #6F6A62 / #9A958D |
| `--text-disabled` | `var(--paper-400)` | `var(--soot-500)` | #A39E94 / #7A766F |
| `--text-on-accent` | `#FFFFFF` | `#FFFFFF` | text on accent/danger fills; redeclared in dark with the same value |
| `--text-inverse` | `var(--paper-25)` | `var(--paper-900)` | text on surface-inverse. #FCFBF9 / #1F1D1A |
| `--text-accent` | `var(--ink-600)` | `var(--ink-300)` | #2A4DAF / #8BA4E4 |
| `--text-link` | `var(--ink-600)` | `var(--ink-300)` | links (underline 1px, offset 2px; hover goes to --accent-hover). #2A4DAF / #8BA4E4 |

**Semantic - icon colours** (3)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--icon-primary` | `var(--paper-800)` | `var(--soot-800)` | #3A3732 / #E3DFD8 (name prefix clashes with --icon-sm/md/lg sizes) |
| `--icon-secondary` | `var(--paper-600)` | `var(--soot-600)` | #6F6A62 / #9A958D |
| `--icon-disabled` | `var(--paper-400)` | `var(--soot-500)` | #A39E94 / #7A766F |

**Semantic - borders** (4)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--border-subtle` | `#E6E2DB` | `var(--soot-200)` | light value is a literal, not a ramp step. #E6E2DB / #2E2D2A |
| `--border-default` | `var(--paper-200)` | `var(--soot-300)` | #DEDAD2 / #3B3936 |
| `--border-strong` | `var(--paper-300)` | `var(--soot-400)` | hover border. #C9C4BA / #57544F |
| `--border-focus` | `var(--ink-500)` | `var(--ink-400)` | focus ring/outline colour. #3A60C6 / #5D7FD6 |

**Semantic - accent** (6)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--accent` | `var(--ink-600)` | `var(--ink-500)` | primary button fill. #2A4DAF / #3A60C6 |
| `--accent-hover` | `var(--ink-700)` | `#4A6DD0` | #213E8E / #4A6DD0 (dark is a literal between ink-400 and ink-500) |
| `--accent-pressed` | `var(--ink-800)` | `var(--ink-600)` | #1A3170 / #2A4DAF |
| `--accent-subtle` | `var(--ink-50)` | `rgba(93, 127, 214, 0.16)` | #EEF2FC / 0x295D7FD6 |
| `--accent-subtle-hover` | `var(--ink-100)` | `rgba(93, 127, 214, 0.24)` | #DCE4F8 / 0x3D5D7FD6 |
| `--accent-border` | `var(--ink-300)` | `var(--ink-400)` | #8BA4E4 / #5D7FD6 |

**Semantic - status (success / warning / danger / info)** (16)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--success` | `var(--green-600)` | `var(--green-300)` | status text/icon. #1E7A46 / #4CC07E |
| `--success-solid` | `var(--green-500)` | `var(--green-500)` | solid fills/dots. #2E9A5C in both themes |
| `--success-bg` | `var(--green-50)` | `#13291C` | #E7F4EC / #13291C |
| `--success-border` | `var(--green-200)` | `#22503A` | #A9D8BC / #22503A |
| `--warning` | `var(--amber-700)` | `var(--amber-300)` | #9A5B00 / #F0B04A |
| `--warning-solid` | `var(--amber-500)` | `var(--amber-500)` | #D98A0B in both; FontPicker glyph-warning border/icon |
| `--warning-bg` | `var(--amber-50)` | `#2E2212` | #FDF3E1 / #2E2212 |
| `--warning-border` | `var(--amber-200)` | `#5A4220` | #F0CD8F / #5A4220 |
| `--danger` | `var(--red-600)` | `var(--red-300)` | #B42318 / #F07A6E |
| `--danger-solid` | `var(--red-600)` | `#C8352A` | danger button fill. #B42318 / #C8352A |
| `--danger-hover` | `#961C13` | `#D94A3E` | danger button hover/active. #961C13 / #D94A3E |
| `--danger-bg` | `var(--red-50)` | `#331816` | #FCEBE9 / #331816 |
| `--danger-border` | `var(--red-200)` | `#632C27` | #F2B8B1 / #632C27 |
| `--info` | `var(--ink-600)` | `var(--ink-300)` | #2A4DAF / #8BA4E4 |
| `--info-bg` | `var(--ink-50)` | `rgba(93, 127, 214, 0.14)` | #EEF2FC / 0x245D7FD6 |
| `--info-border` | `var(--ink-200)` | `rgba(93, 127, 214, 0.36)` | #B8C8F0 / 0x5C5D7FD6 |

**Editing states (drawn on top of the PDF page, tuned against white paper) - NOT overridden in dark** (19)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--edit-selection` | `rgba(58, 96, 198, 0.26)` |  | selected text run; also .fm-root ::selection. 0x423A60C6 |
| `--edit-box` | `var(--ink-500)` |  | active text-block frame. #3A60C6 |
| `--edit-box-hover` | `rgba(58, 96, 198, 0.45)` |  | hover affordance on editable text. 0x733A60C6 |
| `--edit-handle-fill` | `#FFFFFF` |  | selection handle fill |
| `--edit-caret` | `var(--ink-700)` |  | text caret. #213E8E |
| `--edit-changed` | `#0F7F72` |  | edited since open (teal). OVERRIDDEN in fm-additions.css to var(--ink-600) = #2A4DAF; the effective value is ink-600 |
| `--edit-changed-bg` | `rgba(15, 127, 114, 0.10)` |  | 0x1A0F7F72. OVERRIDDEN in fm-additions.css to rgba(42, 77, 175, 0.08) |
| `--glyph-missing` | `var(--amber-500)` |  | substituted / missing glyph. #D98A0B |
| `--glyph-missing-bg` | `rgba(217, 138, 11, 0.20)` |  | 0x33D98A0B |
| `--redact-pending` | `var(--red-600)` |  | marked, not yet applied. #B42318 |
| `--redact-pending-bg` | `rgba(180, 35, 24, 0.12)` |  | 0x1FB42318; editing.css uses it in a -45deg hatch with untokenized rgba(180,35,24,0.22) stripes (4px/2px) |
| `--redact-applied` | `#000000` |  | burned in, always true black |
| `--search-match` | `rgba(255, 216, 77, 0.55)` |  | search hit. 0x8CFFD84D |
| `--search-current` | `rgba(255, 159, 28, 0.70)` |  | current search hit; additions reuse it for replace preview. 0xB2FF9F1C (or 0xB3 depending on rounding) |
| `--search-current-border` | `#C46A00` |  | current search hit outline |
| `--form-field-bg` | `rgba(58, 96, 198, 0.07)` |  | PDF form field tint. 0x123A60C6 |
| `--form-field-border` | `var(--ink-300)` |  | #8BA4E4 |
| `--form-field-focus` | `var(--ink-500)` |  | #3A60C6 |
| `--form-field-required` | `var(--red-600)` |  | #B42318 |

**The page (PDF page stays paper-white in both themes)** (3)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--page-bg` | `#FFFFFF` |  | page background; not overridden in dark |
| `--page-filter` | `none` |  | @kind other. CSS filter on the page; changed only by [data-page="dim"] |
| `--page-border` | `rgba(20, 19, 17, 0.08)` | `rgba(0, 0, 0, 0.5)` | used as the 1px ring in --shadow-page. 0x14141311 / 0x80000000 |

**[data-page="dim"] override (optional reading comfort, intended for dark theme; selector is not scoped to dark)** (1)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--page-filter` | `brightness(0.86) contrast(1.04) sepia(0.06)` |  | @kind other. Dims the page without inverting it; needs a ColorFilter.matrix in Flutter |

#### `typography.css`

**Font families** (5)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--font-ui` | `'IBM Plex Sans', 'IBM Plex Sans Arabic', system-ui, -apple-system, 'Segoe UI', sans-serif` |  | one UI family with Plex Sans Arabic fallback. OVERRIDDEN by fm-additions.css with the 21-language extended stack |
| `--font-arabic` | `'IBM Plex Sans Arabic', 'IBM Plex Sans', system-ui, sans-serif` |  | Arabic-first stack |
| `--font-mono` | `'IBM Plex Mono', ui-monospace, 'SF Mono', Menlo, Consolas, monospace` |  | shortcuts and raw values; .fm-mono |
| `--font-brand` | `'IBM Plex Serif', Georgia, 'Times New Roman', serif` |  | wordmark and long-form brand moments only |
| `--font-doc-sample` | `'IBM Plex Serif', Georgia, serif` |  | stand-in for PDF content in mocks only |

**Font weights** (3)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--weight-regular` | `400` |  | unitless, FontWeight.w400 |
| `--weight-medium` | `500` |  | FontWeight.w500 |
| `--weight-semibold` | `600` |  | FontWeight.w600 |

**Size / line-height pairs (desktop UI base 13px; each pair is declared on one line and shares one comment)** (18)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--text-2xs` | `10px` |  | status-bar counters, thumbnail page numbers |
| `--leading-2xs` | `12px` |  | pairs with text-2xs (height 1.2) |
| `--text-xs` | `11px` |  | section labels, badges, shortcut hints |
| `--leading-xs` | `14px` |  | pairs with text-xs (1.2727) |
| `--text-sm` | `12px` |  | secondary text, tooltips, captions |
| `--leading-sm` | `16px` |  | pairs with text-sm (1.3333) |
| `--text-md` | `13px` |  | default UI text, buttons, inputs |
| `--leading-md` | `18px` |  | pairs with text-md (1.3846) |
| `--text-lg` | `14px` |  | dialog body, readable prose |
| `--leading-lg` | `20px` |  | pairs with text-lg (1.4286) |
| `--text-xl` | `16px` |  | panel titles, palette input |
| `--leading-xl` | `22px` |  | pairs with text-xl (1.375) |
| `--text-2xl` | `20px` |  | dialog titles |
| `--leading-2xl` | `26px` |  | pairs with text-2xl (1.3) |
| `--text-3xl` | `28px` |  | empty-state headline |
| `--leading-3xl` | `34px` |  | pairs with text-3xl (1.2143) |
| `--text-4xl` | `40px` |  | onboarding / brand |
| `--leading-4xl` | `46px` |  | pairs with text-4xl (1.15) |

**Tracking (letter-spacing)** (3)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--tracking-tight` | `-0.01em` |  | em-relative, multiply by font size for Flutter letterSpacing |
| `--tracking-normal` | `0` |  | unitless zero |
| `--tracking-label` | `0.02em` |  | small-caps-like section labels |

**Numerals / OpenType features** (2)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--numeric-tabular` | `tabular-nums` |  | @kind font. Page numbers, zoom, measurements and counters are always tabular (.fm-num). FontFeature.tabularFigures() |
| `--features-ui` | `'kern' 1, 'liga' 1` |  | @kind font. .fm-root font-feature-settings. FontFeature.enable('kern'), FontFeature.enable('liga') |

**Semantic type roles (CSS font shorthand: weight size/line-height family)** (10)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--type-body` | `var(--weight-regular) var(--text-md)/var(--leading-md) var(--font-ui)` |  | 400 13/18 font-ui; .fm-root default font. CJK override in additions: 13/20 |
| `--type-body-strong` | `var(--weight-medium) var(--text-md)/var(--leading-md) var(--font-ui)` |  | 500 13/18 font-ui. CJK: 13/20 |
| `--type-label` | `var(--weight-medium) var(--text-xs)/var(--leading-xs) var(--font-ui)` |  | 500 11/14 font-ui. CJK: 11/16 |
| `--type-caption` | `var(--weight-regular) var(--text-sm)/var(--leading-sm) var(--font-ui)` |  | 400 12/16 font-ui. CJK: 12/18 |
| `--type-prose` | `var(--weight-regular) var(--text-lg)/var(--leading-lg) var(--font-ui)` |  | 400 14/20 font-ui |
| `--type-panel-title` | `var(--weight-semibold) var(--text-md)/var(--leading-md) var(--font-ui)` |  | 600 13/18 font-ui. CJK: 13/20 |
| `--type-dialog-title` | `var(--weight-semibold) var(--text-xl)/var(--leading-xl) var(--font-ui)` |  | 600 16/22 font-ui (uses text-xl, not text-2xl) |
| `--type-headline` | `var(--weight-semibold) var(--text-3xl)/var(--leading-3xl) var(--font-ui)` |  | 600 28/34 font-ui |
| `--type-mono` | `var(--weight-regular) var(--text-sm)/var(--leading-sm) var(--font-mono)` |  | 400 12/16 font-mono |
| `--type-wordmark` | `var(--weight-semibold) var(--text-xl)/1 var(--font-brand)` |  | 600 16px with unitless line-height 1, font-brand (Plex Serif) |

#### `spacing.css`

**Space scale (4px base with 2px and 6px half-steps)** (15)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--space-0` | `0` |  | unitless zero |
| `--space-px` | `1px` |  | hairline |
| `--space-0-5` | `2px` |  | half-step |
| `--space-1` | `4px` |  |  |
| `--space-1-5` | `6px` |  | half-step |
| `--space-2` | `8px` |  |  |
| `--space-2-5` | `10px` |  | half-step |
| `--space-3` | `12px` |  |  |
| `--space-4` | `16px` |  |  |
| `--space-5` | `20px` |  |  |
| `--space-6` | `24px` |  |  |
| `--space-8` | `32px` |  |  |
| `--space-10` | `40px` |  |  |
| `--space-12` | `48px` |  |  |
| `--space-16` | `64px` |  |  |

**Controls - desktop (default, compact density)** (9)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--control-h-xs` | `22px` |  | inline chips, stepper arrows. touch: 32px |
| `--control-h-sm` | `26px` |  | toolbar buttons, panel inputs. touch: 44px |
| `--control-h-md` | `30px` |  | default buttons, fields. touch: 44px |
| `--control-h-lg` | `36px` |  | dialog primary actions, palette rows. touch: 48px |
| `--control-pad-x` | `10px` |  | horizontal control padding. touch: 14px |
| `--icon-sm` | `14px` |  | icon size, not overridden by touch |
| `--icon-md` | `16px` |  | icon size. touch: 20px |
| `--icon-lg` | `20px` |  | icon size. touch: 24px |
| `--hit-min` | `24px` |  | smallest clickable target on desktop. touch: 44px |

**App layout** (10)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--titlebar-h` | `38px` |  | window title bar. touch: 56px |
| `--modebar-h` | `40px` |  | mode tabs bar. touch: 48px |
| `--toolbar-h` | `44px` |  | contextual toolbar. touch: 56px |
| `--statusbar-h` | `26px` |  | status bar. touch: 40px |
| `--sidebar-w` | `216px` |  | left sidebar width |
| `--panel-w` | `264px` |  | properties panel width |
| `--thumb-w` | `112px` |  | page thumbnail width |
| `--dialog-w-sm` | `400px` |  | small dialog width |
| `--dialog-w-md` | `520px` |  | medium dialog width |
| `--palette-w` | `600px` |  | command palette width |

**[data-density="touch"] overrides (tablets and the mobile app; every target at least 44px)** (12)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--control-h-xs` | `32px` |  | desktop 22px |
| `--control-h-sm` | `44px` |  | desktop 26px |
| `--control-h-md` | `44px` |  | desktop 30px |
| `--control-h-lg` | `48px` |  | desktop 36px |
| `--control-pad-x` | `14px` |  | desktop 10px |
| `--icon-md` | `20px` |  | desktop 16px |
| `--icon-lg` | `24px` |  | desktop 20px |
| `--hit-min` | `44px` |  | desktop 24px |
| `--toolbar-h` | `56px` |  | desktop 44px |
| `--modebar-h` | `48px` |  | desktop 40px |
| `--titlebar-h` | `56px` |  | desktop 38px |
| `--statusbar-h` | `40px` |  | desktop 26px. Also untokenized in forms.css under touch: switch track 44x26, thumb 22x22, checked thumb offset 20px |

#### `effects.css`

**Radii** (6)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--radius-xs` | `2px` |  | selection handles, checkbox inner, colour chips |
| `--radius-sm` | `4px` |  | buttons, inputs, toolbar items |
| `--radius-md` | `6px` |  | menus, thumbnails, cards, toasts |
| `--radius-lg` | `8px` |  | dialogs, command palette, floating bars |
| `--radius-xl` | `12px` |  | drop zone, onboarding surfaces; aliased by --sheet-radius |
| `--radius-full` | `999px` |  | status dots, switch track (pill/stadium) |

**Border widths** (2)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--border-width` | `1px` |  | default border |
| `--border-width-strong` | `1.5px` |  | active text-edit frame (fractional px) |

**Elevation (multi-layer box-shadows; soft, only for things that float above the document)** (5)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--shadow-page` | `0 0 0 1px var(--page-border), 0 1px 2px rgba(20, 19, 17, 0.06), 0 6px 20px -8px rgba(20,…` | `0 0 0 1px var(--page-border), 0 2px 4px rgba(0, 0, 0, 0.4), 0 10px 28…` | PDF page. Layer 1 is a 1px spread ring = --page-border (light 0x14141311, dark 0x80000000); negative spread on the last… |
| `--shadow-sm` | `0 1px 2px rgba(20, 19, 17, 0.08)` | `0 1px 2px rgba(0, 0, 0, 0.4)` | small lift. 0x14141311 / 0x66000000 |
| `--shadow-popover` | `0 0 0 1px rgba(20, 19, 17, 0.08), 0 4px 12px rgba(20, 19, 17, 0.08), 0 12px 28px -6px rgb…` | `0 0 0 1px rgba(255, 255, 255, 0.07), 0 4px 12px rgba(0, 0, 0, 0.36),…` | menus/popovers. 1px ring (light dark-ink 8%, dark white 7%) + 2 blur layers |
| `--shadow-dialog` | `0 0 0 1px rgba(20, 19, 17, 0.08), 0 8px 24px rgba(20, 19, 17, 0.10), 0 24px 56px -12px rg…` | `0 0 0 1px rgba(255, 255, 255, 0.08), 0 8px 24px rgba(0, 0, 0, 0.4), 0…` | dialogs. 1px ring + 2 blur layers |
| `--shadow-drag` | `0 2px 6px rgba(20, 19, 17, 0.12), 0 14px 32px -8px rgba(20, 19, 17, 0.28)` | `0 2px 6px rgba(0, 0, 0, 0.4), 0 14px 32px -8px rgba(0, 0, 0, 0.7)` | dragged item (thumbnail reorder); no ring |

**Focus (2px ink ring with a 2px gap in the surface colour) - not redeclared in dark, but resolves differently through var chains** (4)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--focus-ring` | `0 0 0 2px var(--surface-raised), 0 0 0 4px var(--border-focus)` |  | light resolves to 0 0 0 2px #FFFFFF, 0 0 0 4px #3A60C6; dark (inherited) resolves to 0 0 0 2px #1D1C1B, 0 0 0 4px #5D7F… |
| `--focus-ring-inset` | `inset 0 0 0 2px var(--border-focus)` |  | inset ring. light #3A60C6, dark (inherited) #5D7FD6 |
| `--focus-outline` | `2px solid var(--border-focus)` |  | the :focus-visible outline in base.css. light #3A60C6, dark (inherited) #5D7FD6. Text inputs suppress it and show borde… |
| `--focus-offset` | `2px` |  | outline-offset for :focus-visible |

**Motion - durations (short ease-out, never bouncy)** (4)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--dur-instant` | `60ms` |  | @kind other. 0ms under prefers-reduced-motion |
| `--dur-fast` | `120ms` |  | @kind other. 0ms under reduced motion |
| `--dur-base` | `180ms` |  | @kind other. 0ms under reduced motion |
| `--dur-slow` | `260ms` |  | @kind other. 0ms under reduced motion |

**Motion - easing** (3)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--ease-out` | `cubic-bezier(0.2, 0, 0, 1)` |  | @kind other. Default enter/move. Cubic(0.2, 0, 0, 1) |
| `--ease-in-out` | `cubic-bezier(0.4, 0, 0.2, 1)` |  | @kind other. Cubic(0.4, 0, 0.2, 1), same as Curves.fastOutSlowIn |
| `--ease-exit` | `cubic-bezier(0.4, 0, 1, 1)` |  | @kind other. Exit/accelerate. Cubic(0.4, 0, 1, 1) |

**Z-index layers** (7)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--z-canvas` | `0` |  | @kind other. Document canvas |
| `--z-edit` | `10` |  | @kind other. Edit overlays on the page |
| `--z-sticky` | `20` |  | @kind other. Sticky chrome |
| `--z-popover` | `100` |  | @kind other |
| `--z-dialog` | `200` |  | @kind other |
| `--z-toast` | `300` |  | @kind other |
| `--z-tooltip` | `400` |  | @kind other |

**@media (prefers-reduced-motion: reduce) :root overrides** (4)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--dur-instant` | `0ms` |  | @kind other. Default 60ms |
| `--dur-fast` | `0ms` |  | @kind other. Default 120ms |
| `--dur-base` | `0ms` |  | @kind other. Default 180ms |
| `--dur-slow` | `0ms` |  | @kind other. Default 260ms |

#### `base.css`

**base.css - no custom-property declarations; tokens consumed and keyframes defined (scoped to .fm-root)** (11)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `(consumes) .fm-root` | `font: var(--type-body); font-feature-settings: var(--features-ui); color: var(--text-prim…` |  | defaults for the app root; also antialiased smoothing and box-sizing border-box |
| `(consumes) :focus-visible` | `outline: var(--focus-outline); outline-offset: var(--focus-offset)` |  | suppressed on .fm-input__control, .fm-palette__field, .fm-sigpad__typed, .fm-pff__input, [contenteditable] |
| `(consumes) ::selection` | `background: var(--edit-selection)` |  |  |
| `(consumes) links` | `color: var(--text-link); hover color: var(--accent-hover); underline 1px thick, 2px offset` |  | .fm-root a, a.fm-link |
| `(consumes) .fm-num / .fm-mono` | `font-variant-numeric: tabular-nums / font-family: var(--font-mono)` |  |  |
| `@keyframes fm-spin` | `to { transform: rotate(360deg) }` |  | spinner |
| `@keyframes fm-fade-in` | `opacity 0 -> 1` |  |  |
| `@keyframes fm-rise-in` | `opacity 0, translateY(4px) -> opacity 1, none` |  |  |
| `@keyframes fm-indeterminate` | `inset-inline-start -40% -> 100%` |  | indeterminate progress bar (logical/RTL-aware) |
| `@keyframes fm-caret` | `0-49% opacity 1; 50-100% opacity 0` |  | caret blink (step) |
| `(rule) [dir="rtl"] [data-flip-rtl]` | `transform: scaleX(-1)` |  | directional icons mirror under RTL |

#### `fonts.css`

**@font-face inventory (no custom properties). 33 faces, all font-display: swap, woff2, self-hosted in ../assets/fonts/; Latin+Latin-Ext cover full Turkish** (11)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `IBM Plex Sans 400 normal` | `plex-sans-{cyrillic-ext,cyrillic,greek,latin-ext,latin}-400-normal.woff2` |  | 5 unicode-range subsets; font-stretch: 100% (variable font from Google Fonts) |
| `IBM Plex Sans 500 normal` | `same 5 files as 400 (plex-sans-*-400-normal.woff2)` |  | 500 points to the 400 file, so the file is a variable-wght font. Flutter needs a variable TTF with FontVariation('wght'… |
| `IBM Plex Sans 600 normal` | `same 5 files as 400 (plex-sans-*-400-normal.woff2)` |  | variable-wght file, as for 500 |
| `IBM Plex Sans Arabic 400 normal` | `plex-sans-arabic-arabic-400-normal.woff2` |  | arabic subset U+0600-06FF etc. |
| `IBM Plex Sans Arabic 500 normal` | `plex-sans-arabic-arabic-500-normal.woff2` |  | distinct file |
| `IBM Plex Sans Arabic 600 normal` | `plex-sans-arabic-arabic-600-normal.woff2` |  | distinct file (same byte size as 500, different hash) |
| `IBM Plex Serif 400 italic` | `plex-serif-{cyrillic,latin-ext,latin}-400-italic.woff2` |  | brand / doc-sample |
| `IBM Plex Serif 400 normal` | `plex-serif-{cyrillic,latin-ext,latin}-400-normal.woff2` |  |  |
| `IBM Plex Serif 600 normal` | `plex-serif-{cyrillic,latin-ext,latin}-600-normal.woff2` |  | wordmark weight |
| `IBM Plex Mono 400 normal` | `plex-mono-{cyrillic,latin-ext,latin}-400-normal.woff2` |  |  |
| `IBM Plex Mono 500 normal` | `plex-mono-{cyrillic,latin-ext,latin}-500-normal.woff2` |  | no Mono 600 face; a 600 request would be synthesised or fall back |

#### `fm-additions.css`

**Remote webfont @import (Google Fonts, line 1) - not self-hosted** (13)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `IBM Plex Sans JP` | `wght 400;500;600` |  | in extended --font-ui |
| `IBM Plex Sans KR` | `wght 400;500;600` |  | in extended --font-ui |
| `IBM Plex Sans Hebrew` | `wght 400;500;600` |  | in extended --font-ui |
| `IBM Plex Sans Devanagari` | `wght 400;500;600` |  | in extended --font-ui |
| `Noto Sans SC` | `wght 400;500;600` |  | Simplified Chinese, in extended --font-ui |
| `Noto Serif JP` | `wght 400;600` |  | --font-doc-cjk |
| `EB Garamond` | `ital,wght 0,400; 0,600; 1,400` |  | document font sample ('Garamond Premier Pro' substitute in the FontPicker demo) |
| `Cormorant Garamond` | `wght 400;600` |  | document font sample |
| `Crimson Pro` | `wght 400;600` |  | document font sample |
| `Noto Naskh Arabic` | `wght 400;600` |  | Arabic document font sample |
| `Caveat` | `wght 500` |  | --font-hand-1 |
| `Homemade Apple` | `400 (default)` |  | --font-hand-2 |
| `Dancing Script` | `wght 500` |  | --font-hand-3 |

**A. New tokens - edited-text marking (fix 3: accent ink, dotted underline + margin bar, never yellow); overrides DS teal** (5)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--edit-changed` | `var(--ink-600)` |  | OVERRIDES colors.css #0F7F72. Resolves to #2A4DAF in both themes. Docs: 'Now ink 600 (was teal): edited dot, badge' |
| `--edit-changed-bg` | `rgba(42, 77, 175, 0.08)` |  | OVERRIDES colors.css rgba(15,127,114,0.10). 0x142A4DAF |
| `--edit-mark` | `var(--ink-600)` |  | #2A4DAF. Docs: 'Edited text: dotted underline, margin bar'. .fm-mark--edited uses an underline dotted at 1.5px, offset… |
| `--edit-mark-bar-w` | `2px` |  | margin bar width |
| `--edit-mark-bar-gap` | `12px` |  | gap between the margin bar and the text |

**A. New tokens - editor chrome sizes and window** (7)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--editbox-meta-h` | `18px` |  | text-frame label height (fix 1); label placement above/below/margin |
| `--thumb-badge` | `16px` |  | thumbnail badge chip size (fix 5); the edited badge stays an 8px accent dot |
| `--doctab-h` | `28px` |  | document tab height |
| `--doctab-w` | `188px` |  | document tab width |
| `--doctab-w-min` | `112px` |  | document tab min width (overflow shows '+N') |
| `--win-caption-w` | `46px` |  | Windows caption button width (fix 6) |
| `--win-close-hover` | `#C42B1C` | `#C42B1C` | Windows close button hover; redeclared in [data-theme=dark] with the same value |

**A. New tokens - on-page marks (page-tuned like other on-page marks; not overridden in dark)** (10)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--overflow-mark` | `var(--amber-500)` |  | #D98A0B. Text that no longer fits its frame (3.4) |
| `--ocr-low` | `var(--amber-500)` |  | #D98A0B. OCR low-confidence word (7.5) |
| `--ocr-low-bg` | `rgba(217, 138, 11, 0.16)` |  | 0x29D98A0B. Low-confidence OCR word background |
| `--diff-added` | `rgba(46, 154, 92, 0.22)` |  | 0x382E9A5C. Compare: added text (9.2) |
| `--diff-added-line` | `var(--green-500)` |  | #2E9A5C |
| `--diff-removed` | `rgba(217, 58, 43, 0.18)` |  | 0x2ED93A2B. Compare: removed text |
| `--diff-removed-line` | `var(--red-500)` |  | #D93A2B |
| `--diff-changed` | `rgba(217, 138, 11, 0.22)` |  | 0x38D98A0B. Compare: changed text |
| `--diff-changed-line` | `var(--amber-500)` |  | #D98A0B |
| `--translated-mark` | `rgba(58, 96, 198, 0.10)` |  | 0x1A3A60C6. Translated block, preview only (3.13) |

**A. New tokens - mobile (13)** (7)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--ios-navbar-h` | `44px` |  | iOS navigation bar |
| `--ios-tabbar-h` | `83px` |  | iOS tab bar incl. home-indicator inset |
| `--android-appbar-h` | `64px` |  | Android top app bar |
| `--android-navbar-h` | `80px` |  | Android bottom navigation bar |
| `--fab-size` | `56px` |  | floating action button |
| `--sheet-radius` | `var(--radius-xl)` |  | bottom sheet corner radius, resolves to 12px |
| `--grabber-w` | `36px` |  | sheet grabber width |

**A. New tokens - script coverage fonts (UI stack extended for all 21 launch languages)** (5)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--font-ui` | `'IBM Plex Sans', 'IBM Plex Sans Arabic', 'IBM Plex Sans Hebrew', 'IBM Plex Sans Devanagar…` |  | OVERRIDES typography.css; this is the effective value that all --type-* roles except mono and wordmark resolve to |
| `--font-doc-cjk` | `'Noto Serif JP', 'IBM Plex Sans JP', serif` |  | CJK document content |
| `--font-hand-1` | `'Caveat', cursive` |  | typed-signature style 1 (demo 500 32px/1) |
| `--font-hand-2` | `'Homemade Apple', cursive` |  | typed-signature style 2 (demo 400 24px/1) |
| `--font-hand-3` | `'Dancing Script', cursive` |  | typed-signature style 3 (demo 500 30px/1) |

**[lang\|="ja"], [lang\|="zh"], [lang\|="ko"] overrides (CJK: taller leading, font-synthesis: none, never synthesise bold/italic)** (5)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--type-body` | `var(--weight-regular) var(--text-md)/20px var(--font-ui)` |  | 400 13/20 (default 18) |
| `--type-body-strong` | `var(--weight-medium) var(--text-md)/20px var(--font-ui)` |  | 500 13/20 (default 18) |
| `--type-caption` | `var(--weight-regular) var(--text-sm)/18px var(--font-ui)` |  | 400 12/18 (default 16) |
| `--type-label` | `var(--weight-medium) var(--text-xs)/16px var(--font-ui)` |  | 500 11/16 (default 14) |
| `--type-panel-title` | `var(--weight-semibold) var(--text-md)/20px var(--font-ui)` |  | 600 13/20 (default 18). prose, dialog-title, headline, mono and wordmark are not overridden |

#### `DS additions.dc.html`

**Colour tokens section (documentation of additions; values come from fm-additions.css / colors.css)** (10)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--edit-mark` | `var(--edit-mark) = #2A4DAF` |  | Edited text: dotted underline, margin bar |
| `--edit-changed` | `var(--edit-changed) = #2A4DAF` |  | Now ink 600 (was teal): edited dot, badge |
| `--overflow-mark` | `var(--overflow-mark) = #D98A0B` |  | Text that no longer fits its frame |
| `--ocr-low-bg` | `var(--ocr-low-bg) = rgba(217, 138, 11, 0.16)` |  | Low-confidence OCR word |
| `--diff-added` | `var(--diff-added) = rgba(46, 154, 92, 0.22)` |  | Compare: added text |
| `--diff-removed` | `var(--diff-removed) = rgba(217, 58, 43, 0.18)` |  | Compare: removed text |
| `--diff-changed` | `var(--diff-changed) = rgba(217, 138, 11, 0.22)` |  | Compare: changed text |
| `--translated-mark` | `var(--translated-mark) = rgba(58, 96, 198, 0.10)` |  | Translated block, preview only |
| `--win-close-hover` | `var(--win-close-hover) = #C42B1C` | `#C42B1C` | Windows close button hover |
| `--search-current` | `var(--search-current) = rgba(255, 159, 28, 0.70)` |  | Existing, reused for replace preview |

**Type additions section (documentation)** (2)

| Token | Light / default | Dark / override | Note |
|---|---|---|---|
| `--font-ui (extended)` | `IBM Plex Sans + Plex Arabic, Hebrew, Devanagari, JP, KR, then Noto Sans SC` |  | Covers Ferman/Turkish/German/Russian/Arabic/Hebrew/Hindi/Japanese/Korean/Simplified Chinese. CJK gets 20px leading at 1… |
| `--font-hand-1 / --font-hand-2 / --font-hand-3` | `Caveat / Homemade Apple / Dancing Script (OFL)` |  | The design's "(OFL)" label is wrong for Homemade Apple, which is Apache-2.0 ([G08](DESIGN_GAPS.md#g08)). Typed-signature styles, demo colour #1A3170 (ink-800). Each covers ş, ğ, ı, İ; styles without full coverage are hidden… |

**Theming attributes**

- :root (default) - light theme plus desktop compact density. colors.css sets color-scheme: light. Note there is NO [data-theme="light"] rule. The design docs use data-theme="light" 72 times, but it only works because the :root defaults apply; a light element nested inside a dark one would NOT reset. In Flutter that is a non-issue: pick the ThemeExtension instance explicitly.
- [data-theme="dark"] - colors.css redeclares 48 semantic tokens: surface x10, text x8, icon x3, border x4, accent x6, success/warning/danger/info x16, --page-border; sets color-scheme: dark. effects.css redeclares 5 shadows (page, sm, popover, dialog, drag). fm-additions.css redeclares --win-close-hover with the same #C42B1C. NOT overridden in dark: all ramps (ink/seal/paper/soot/green/amber/red), annotation palette, editing/on-page states (edit-*, glyph-*, redact-*, search-*, form-field-*), --page-bg, --page-filter, and all additions marks (diff/ocr/translated/overflow). Inherited var chains still change in dark: --focus-ring, --focus-ring-inset and --focus-outline follow --surface-raised/--border-focus, and --shadow-page uses the dark --page-border. Component CSS has hardcoded dark tweaks that are not tokens: scrim-top rgba(0,0,0,0.4); selected modetab/segment bg soot-200 with no shadow; annot-color/chip/swatch inset ring rgba(255,255,255,.24-.28); checkbox hover border soot-500; core.css .fm-badge--edited #4FC2B4, which fm-additions patches to ink-300.
- [data-page="dim"] - overrides only --page-filter, from none to brightness(0.86) contrast(1.04) sepia(0.06). It is a per-user reading-comfort option meant for dark theme, but the selector is not scoped to dark. Pages apply filter: var(--page-filter) on the page element only, never on chrome.
- [data-density="touch"] - tablets and the mobile app (every target at least 44px). 12 overrides: control-h-xs 32, control-h-sm 44, control-h-md 44, control-h-lg 48, control-pad-x 14, icon-md 20, icon-lg 24, hit-min 44, toolbar-h 56, modebar-h 48, titlebar-h 56, statusbar-h 40. Not overridden: icon-sm, space-*, widths. forms.css also resizes the switch under touch (track 44x26, thumb 22, checked offset 20px). Set by the DS bundle's touch prop and by FmBoard data-density="{{ density }}". Map it to a FermanDensity ThemeExtension with desktop/touch instances, keyed off platform (iOS/Android/tablet) and not off VisualDensity alone.
- @media (prefers-reduced-motion: reduce) - --dur-instant/fast/base/slow all become 0ms. Flutter: MediaQuery.disableAnimationsOf(context) gives Duration.zero.
- [dir="rtl"] - no token overrides. [data-flip-rtl] (base.css) and [data-fm-flip] svg (additions) mirror with scaleX(-1); panels.css rotates the collapsed section toggle 90deg. Components use logical properties (inset-inline-start/end), as does the fm-indeterminate keyframe. Flutter: Directionality plus EdgeInsetsDirectional/AlignmentDirectional, and Transform.flip(flipX) for icons marked directional. Arabic (ar) is used in RTL docs, and the Hebrew stack is included.
- [lang\|="ja"], [lang\|="zh"], [lang\|="ko"] (fm-additions) - font-synthesis: none, and 5 type-role overrides with taller fixed leading: body 13/20, body-strong 13/20, caption 12/18, label 11/16, panel-title 13/20. Flutter: choose a CJK FermanTypography variant from Localizations.localeOf(context).languageCode, and avoid fake bold/italic.
- Non-token attributes, for awareness only (do not generate): [data-fm-mode] (text frames inert outside edit mode); [data-meta-placement=below\|margin] (TextEditBox label position); [data-fm-glyph-warning] (FontPicker amber border and warning icon mask); [data-fm-force=hover\|active\|focus] and [data-fm-artboard] (documentation state harness only); .fm-root (base scope class).

**What the token generator must handle**

- color-mix(): none in any token file or component CSS (grep confirmed). The generator needs no colour-mix support.
- rgba overlays and tints (about 40 distinct rgba literals): surface-hover/pressed, scrim, dark selected/accent-subtle/info-bg/info-border, edit-selection, edit-box-hover, edit-changed-bg, glyph-missing-bg, redact-pending-bg, search-match/current, form-field-bg, page-border, ocr-low-bg, diff-*, translated-mark, and every shadow colour. Emit Color(0xAARRGGBB), or Color.from(alpha:, red:, green:, blue:) for exact float alpha. Alpha rounding is a trap: Color.fromRGBO truncates (0.07*255 gives 17 = 0x11), round() gives 18 = 0x12, and 0.70 gives 0xB2 or 0xB3. Pick one rule and test it. surface-hover/pressed are overlays meant to composite over the surface beneath (the secondary button paints linear-gradient(hover) over surface-raised), so use them as overlayColor or Color.alphaBlend, not as opaque fills. Dark selected/accent/info values are translucent while light ones are opaque ramp steps, so the type must allow alpha in both.
- Multi-layer shadows with rings: --shadow-page, --shadow-popover and --shadow-dialog start with '0 0 0 1px <color>', a hairline ring made from a zero-blur spread. Map it to BoxShadow(spreadRadius: 1, blurRadius: 0). Later layers use negative spread (-6, -8, -12px), which BoxShadow supports. Split the comma-separated layers only at top-level commas (rgba() contains commas). CSS paints the FIRST shadow on top; Flutter paints boxShadow in list order (last on top), so reverse the list. Flutter's blurRadius converts to sigma as r*0.57735+0.5, while CSS uses sigma = blur/2, so shadows render slightly sharper or softer. Either accept that or pre-compute blurRadius = (blur/2 - 0.5)/0.57735. --shadow-page embeds var(--page-border) and must be resolved per theme.
- Focus ring: --focus-ring is a 2-layer spread ring (2px gap in --surface-raised, then a 4px spread in --border-focus) and needs both layers in reverse order. It is not redeclared in dark, but its var() inputs are, so resolve it per theme (dark: 0x1D1C1B gap, #5D7FD6 ring). --focus-ring-inset is an INSET shadow, which BoxShadow cannot draw; use Border.all(width: 2, strokeAlign: BorderSide.strokeAlignInside) or a foregroundDecoration. --focus-outline '2px solid' with --focus-offset 2px is an outline drawn outside a 2px gap; emulate it with an outer DecoratedBox/border using strokeAlignOutside plus 2px padding, or reuse the ring. Text inputs instead show border-color --border-focus plus a 1px ring.
- cubic-bezier easing: --ease-out maps to Cubic(0.2, 0, 0, 1), --ease-in-out to Cubic(0.4, 0, 0.2, 1) (identical to Curves.fastOutSlowIn), and --ease-exit to Cubic(0.4, 0, 1, 1). Durations in ms map to Duration(milliseconds: n). The reduced-motion media block sets all four to 0.
- Font shorthand --type-* ('weight size/line-height family-var'): expand nested var() first, then parse into TextStyle(fontWeight, fontSize, height: leading/size, fontFamily, fontFamilyFallback). CSS line-height distributes half-leading evenly, so set leadingDistribution: TextLeadingDistribution.even (or TextHeightBehavior) to match vertical centring. --type-wordmark uses unitless line-height '1', so height is 1.0. The CJK overrides use literal px leading (20/18/16px) instead of --leading-* vars.
- Font-family stacks: CSS lists become fontFamily (first entry) plus fontFamilyFallback (the rest). Drop CSS generic and system keywords (system-ui, -apple-system, 'Segoe UI', sans-serif, serif, monospace, ui-monospace, cursive, 'SF Mono', Menlo, Consolas, Georgia, 'Times New Roman') or map them to platform defaults. Use the fm-additions --font-ui, which overrides typography.css (cascade order). Every family must be declared in pubspec.yaml with matching names.
- Font files: all self-hosted fonts are woff2, which Flutter does not reliably load as bundled assets (TTF/OTF only). Fetch TTF/OTF equivalents. IBM Plex Sans 500 and 600 reference the 400 woff2 file (a variable-wght Google Fonts build with font-stretch 100%), so either bundle the variable TTF and pass FontVariation('wght', w), or bundle static weights. unicode-range subsetting has no Flutter equivalent; the fallback chain does that job. The remote Google Fonts @import is never used and nothing is loaded at run time (no google_fonts package, no deferred download; [ADR 0013](adr/0013-fonts-and-icons.md), [ADR 0015](adr/0015-privacy-and-network.md)). Plex Sans Hebrew and Devanagari are bundled ([Q08](QUESTIONS.md#q08)); the handwriting faces (M4) and the similar-font candidates (M3) are bundled as unmodified files with their licences (Q08 groups 3 and 4, answered on 2026-10-16); CJK uses system fonts. No Plex Mono 600 face exists.
- var() chains: semantic tokens point to ramps (1 level). Type roles point to weight/size/leading/font (1-2 levels). --sheet-radius points to --radius-xl. --focus-* point to --surface-raised/--border-focus and then to ramps (2 levels). --shadow-page points to --page-border. --edit-changed (additions) points to --ink-600. Resolve recursively with a cycle guard, AFTER merging each environment (light, dark = light + dark block, touch, cjk), so inherited chains pick up dark values. Emitting resolved constants is better than runtime lookups. Optionally keep the alias in a doc comment.
- @kind annotations: the trailing '/* @kind other */' (on --page-filter in both blocks, --dur-* including the reduced-motion copies, --ease-*, --z-*) and '/* @kind font */' (on --numeric-tabular, --features-ui) are DS-tooling type hints. They are the only explicit typing. Every other token's type must be inferred from its value pattern (#hex/rgba means colour; Npx means dimension; Nms means duration; cubic-bezier means curve; quoted list means font stack; 'w s/l f' means font shorthand; plain integer means weight or z-index). Strip the @kind text from doc comments and use it as a classifier override.
- Unit-less and odd values: --space-0: 0 and --tracking-normal: 0 (unitless zero); --weight-* 400/500/600 map to FontWeight.w400/w500/w600; --z-* are ints with no Flutter z-index (they inform Overlay/Stack ordering only); --radius-full: 999px means a pill (use StadiumBorder or BorderRadius.circular(999)); --border-width-strong: 1.5px is fractional; --tracking-tight -0.01em and --tracking-label 0.02em are em-relative, so letterSpacing = em * fontSize (for example 11px * 0.02 = 0.22) and must be computed per TextStyle; --line-height '1' is unitless in wordmark.
- Font features: --numeric-tabular (tabular-nums) maps to FontFeature.tabularFigures() and must be applied wherever .fm-num is used (page numbers, zoom, counters, measurements). --features-ui ('kern' 1, 'liga' 1) maps to FontFeature.enable('kern') and FontFeature.enable('liga'), which Flutter already enables by default.
- --page-filter (dim): 'brightness(0.86) contrast(1.04) sepia(0.06)' has no direct Flutter equivalent. Compose three 5x4 colour matrices (brightness scales RGB by 0.86; contrast scales by 1.04 with an offset of 255*(0.5 - 0.5*1.04); sepia(0.06) lerps identity toward the standard sepia matrix by 0.06) into one ColorFilter.matrix, applied only to the rendered page widget. 'none' means no filter.
- Hatch patterns: no hatch token exists, but components use repeating-linear-gradient. .fm-mark--redact-pending (editing.css) draws -45deg stripes: 4px of --redact-pending-bg, then 2px of the untokenized rgba(180,35,24,0.22), on a 6px period. .fm-thumb__lines (pages.css) draws 2px #D6D2CB lines with 4px gaps vertically. Implement with a CustomPainter or LinearGradient(tileMode: TileMode.repeated) using hard stops. Consider promoting the 0.22 stripe colour to a token.
- Cascade overrides that the generator must honour (fm-additions loads after the DS): --edit-changed changes from #0F7F72 teal to ink-600 #2A4DAF; --edit-changed-bg changes to rgba(42,77,175,0.08); --font-ui gets the extended stack. Last declaration wins per selector. Redundant redeclarations (--text-on-accent and --win-close-hover in dark, success-solid/warning-solid dark = light) should collapse to one value.
- Theme-invariant on-page colours (page-bg, edit-*, glyph-*, redact-*, search-*, form-field-*, diff/ocr/translated/overflow, annot-*) are tuned against white paper and must NOT flip in dark mode. Generate them as a separate const class (for example FermanPageColors), not as part of the light/dark lerped ThemeExtension.
- Name collisions in the kebab namespace: --text-* holds both colours (text-primary) and sizes (text-xs); --icon-* holds both colours (icon-primary) and sizes (icon-sm/md/lg); --border-* holds both colours (border-subtle) and widths (border-width). Namespace them by kind (colors.textPrimary vs type.sizeXs, colors.iconPrimary vs size.iconSm). Names with dashes and dots such as --space-0-5 and --space-1-5 need sanitising (space0_5 or spaceHalf).
- Logical/RTL properties (inset-inline-start/end, the fm-indeterminate keyframe) map to EdgeInsetsDirectional/PositionedDirectional. Mirroring of directional icons is attribute-driven ([data-flip-rtl]) and has no token form; keep a per-icon 'directional' flag.
- Keyframes in base.css (fm-spin, fm-fade-in, fm-rise-in with a 4px rise, fm-indeterminate from -40% to 100%, fm-caret as a 50% step blink) are not tokens. Recreate them as AnimationControllers/implicit animations using the --dur-* and --ease-* tokens.

**Generator approach (input to M1).** Recommended approach for tools/tokens to app/lib/design/tokens.g.dart:  (1) Inputs, in cascade order matching styles.css: tokens/colors.css, typography.css, spacing.css, effects.css (fonts.css and base.css declare no custom properties), then ds-additions/fm-additions.css. Treat "DS additions.dc.html" as documentation only; optionally scrape its renderVals colors[] 'use' strings for doc comments.  (2) Parsing. This is a tiny, regular subset of CSS, so a hand-rolled tokenizer (in Dart, or Python run with -I) beats a full CSS parser: - Strip @import lines. - Track @media (prefers-reduced-motion: reduce) as a wrapper flag. - Capture blocks with the regex ([^{}]+)\{([^{}]*)\} after unwrapping @media. - Split declarations on ';' at paren depth 0, using --[\w-]+ as the name. - Capture the trailing same-line /* ... */ as the doc comment. Some lines hold two declarations (the text/leading pairs in typography.css) that share one comment. - Pull the @kind (other\|font) tag out of the comment. - Ignore non-custom properties (color-scheme, font-synthesis) except to record brightness.  (3) Environments. Merge with last-wins: - light = all :root blocks (the additions :root overrides edit-changed, edit-changed-bg, font-ui). - dark = light + [data-theme="dark"] (colors, effects, additions). - touch = light + [data-density="touch"]. - dim = { page-filter }. - cjk = the type-role overrides from [lang\|="ja"],[lang\|="zh"],[lang\|="ko"]. - reducedMotion = the dur-* zeros. Then resolve var() recursively per environment with a cycle guard. This matters for focus-ring and shadow-page in dark.  (4) Classification. Use the @kind override first, then value regex: - ^#[0-9A-F]{6}$ or rgba(...) gives Color. - -?\d*\.?\d+px gives double. - \d+ms gives Duration. - cubic-bezier(a,b,c,d) gives Cubic. - A bare integer gives int (weight 400-600, or z-index). - \d*\.?\d+em gives a letter-spacing factor. - A quoted comma list gives a font stack (List<String>). - weight size/lh family gives TextStyle. - A comma list of 'x y blur spread color' layers gives List<BoxShadow>; handle the 'inset' keyword separately. - brightness()/contrast()/sepia() gives a ColorFilter matrix.  (5) Emit, as deterministic sorted output with a header saying it is generated and must not be edited: - FermanRamps (static const Colors: ink 10, seal 4, paper 14, soot 12, green/amber/red 15, annot 8). - FermanColors extends ThemeExtension with light/dark const instances plus copyWith/lerp, covering the 47 semantic UI colours. page-border can sit here or in shadows. - FermanPageColors (theme-invariant on-page marks, including the additions' edit-mark/diff/ocr/translated/overflow and page-bg). - FermanSpacing (const space scale). - FermanDensity ThemeExtension (desktop/touch: control heights, pad-x, icon-md/lg, hit-min, bar heights) plus the static layout widths. - FermanRadii and border widths. - FermanShadows (light/dark, layer order reversed for Flutter, focus ring per theme). - FermanMotion (durations and Cubic curves, with a reducedMotion getter). - FermanZ (ints). - FermanFonts (family plus fallback lists; the Plex Sans variable-weight note). - FermanTypography (10 roles, default and CJK variants, plus tabularFigures). - Additions sizes (editbox meta, thumb badge, doctab, win caption, mobile bars, fab, sheet radius, grabber) and winCloseHover.  (6) Naming. Strip '--', camelCase the rest, and replace '-0-5'/'-1-5' with '0_5'/'1_5' (or Half). Disambiguate the text-/icon-/border- prefixes by kind.  (7) Verification. Add a unit test that asserts 269 unique source names were seen and 348 declarations parsed (238 DS + 31 additions). Spot-check resolved values: - surfaceCanvas dark = 0xFF0E0E0D - editChanged = 0xFF2A4DAF (the additions override) - typeBody height = 18/13 - focusRing dark gap = 0xFF1D1C1B Fail the build on any unresolved var() or unclassified value.  (8) Out of scope: component patches (section B), the doc harness (section C), and component-level hardcoded dark tweaks. Record them in a TODO list for widget code.

### Components

The manifest names 45 components, counting the data constants `ICON_PATHS`, `FERMAN_MODES` and
`ANNOTATION_TOOLS`. Three more pieces exist only as CSS: `Field`, `Popover` and `Scrim`. The sources
are not in the export ([G02](DESIGN_GAPS.md#g02)), so the props and states below come from the compiled bundle and the
adherence lint config.

**Naming.** The Flutter library in `app/lib/design/components` mirrors the design system one to one,
with the same names, variants and states (brief §6). Dart class names are the DS names: `Button`
stays `Button` and `ModeTabs` stays `ModeTabs`
([ADR 0011](adr/0011-flutter-state-navigation-components.md)). Files that also import Material or
the widgets library use an import prefix or `hide`, so names such as `Icon`, `Tooltip` or `Dialog`
never clash. Only the `Fm*` building blocks keep their `Fm` names. Data constants become enums or
generated data: `FERMAN_MODES` becomes the `FermanMode` enum, `ANNOTATION_TOOLS` the
`AnnotationTool` enum (with the 11 tools the boards draw, [G62](DESIGN_GAPS.md#g62)) and `ICON_PATHS`
the generated `IconName` enum with its path data and SVG assets. Additions
that have no DS name take a plain name in the same style, such as `DocumentTab` or `SaveIndicator`.
Where the generated porting notes suggest `FermanInputDecorator` or `FermanNumberField`, read `Field`
and `FmNumber`.

**First needed** is the earliest milestone whose boards use the component. The brief asks for the
library before the screens, so M1 builds what the shell, Start and Settings need first;
[ROADMAP.md](ROADMAP.md) sets the order for the rest. The component spec written in M1
([COMPONENTS.md](COMPONENTS.md)) refines this with tiers: AnnotationTools and the status-bar
SaveIndicator are tier 1, because the M1 shell draws the Comment tool row and the save indicator
(disabled where the feature is not built); PanelSection, TaskProgress and ProgressBar are tier 2,
because no M1 board draws them.

#### Planned Flutter widgets

| DS component | Group | Flutter widget | First needed | Notes |
|---|---|---|---|---|
| `Icon` | core | `Icon` | M1 | Paints the glyph from the design's exact path data with a `CustomPainter` (path_parsing) at the DS stroke width of 1.5; the SVG assets are not loaded at run time (flutter_svg pulls in `http`). `flipRtl` defaults to `IconName.directional` and mirrors those glyphs under RTL. |
| `ICON_PATHS` | core (data) | `IconName` (generated enum), generated path data and SVG assets | M1 | All 229 glyphs: 145 from the bundle and 84 from `fm-icons.js`. The SVGs are the exported, provenance-tracked set. |
| `Button` | core | `Button` | M1 | Primary, secondary, ghost and danger; sm, md and lg; loading. |
| `IconButton` | core | `IconButton` | M1 | Toggle and loading states. |
| `Tooltip` | core | `Tooltip` | M1 | Shows the shortcut with `Kbd`. Also carries "Available in a future version" ([G10](DESIGN_GAPS.md#g10)). |
| `Kbd` | core | `Kbd` | M1 | ⌘ and ⌥ on macOS; Ctrl and Alt on Windows and Linux. |
| `Badge` | core | `Badge` | M1 | The `edited` tone is patched from teal to ink (DS additions). |
| `TextField` | forms | `TextField` | M1 | Validators return bool and check null and empty values (brief §6). |
| `Select` | forms | `Select` | M1 |  |
| `NumberStepper` | forms | `NumberStepper` | M3 | Screens use the locale-aware `FmNumber` built on it ("10,5 pt" in Turkish). |
| `Checkbox` | forms | `Checkbox` | M2 |  |
| `Radio` | forms | `Radio` | M1 |  |
| `Switch` | forms | `Switch` | M1 | Larger track at touch density. |
| `ColorPicker` | forms | `ColorPicker` | M3 |  |
| `FontPicker` | forms | `FontPicker` | M3 | Adds the missing-glyph warning state (`f2`). |
| `PanelSection` | panels | `PanelSection` | M1 | Right-panel structure in the shell. |
| `ModeTabs` | navigation | `ModeTabs` | M1 | Custom segmented control with `IndexedStack`; never `TabBarView` (brief §6). Eight modes. |
| `FERMAN_MODES` | navigation (data) | `FermanMode` (enum) | M1 | Eight values including `tools`, as drawn. The DS constant lists seven and is stale ([G09](DESIGN_GAPS.md#g09)). |
| `SegmentedControl` | navigation | `SegmentedControl` | M1 | Sidebar tabs use it with `IndexedStack`. |
| `Toolbar` | navigation | `Toolbar` | M1 | One tool row per mode. |
| `ToolbarSeparator` | navigation | `ToolbarSeparator` | M1 |  |
| `ToolbarSpacer` | navigation | `ToolbarSpacer` | M1 |  |
| `ToolbarGroup` | navigation | `ToolbarGroup` | M1 |  |
| `ToolButton` | navigation | `ToolButton` | M1 | Needs the focus and disabled-with-reason states the design does not draw ([G10](DESIGN_GAPS.md#g10), [G22](DESIGN_GAPS.md#g22)). |
| `PageThumbnail` | pages | `PageThumbnail` | M2 | Badge stack and legend (`f5`). |
| `TextEditBox` | editing | `TextEditBox` | M3 | Frame label above, below or in the margin (`f1`). |
| `TextCaret` | editing | `TextCaret` | M3 |  |
| `PageMark` | editing | `PageMark` | M2 | Search kinds in M2; edited and missing-glyph kinds in M3; redaction kinds in P2. Page colours do not follow the theme. |
| `SearchReplaceBar` | editing | `SearchReplaceBar` | M2 | Find in M2; replace in P2. |
| `AnnotationTools` | annotations | `AnnotationTools` | M4 |  |
| `ANNOTATION_TOOLS` | annotations (data) | `AnnotationTool` (enum) | M4 |  |
| `Highlight` | annotations | `Highlight` | M4 | Highlights already in a PDF are drawn by the renderer from M2. |
| `StickyNote` | annotations | `StickyNote` | M4 |  |
| `Stamp` | annotations | `Stamp` | M4 |  |
| `PdfFormField` | fill-sign | `PdfFormField` | M4 |  |
| `SignaturePad` | fill-sign | `SignaturePad` | M4 |  |
| `Toast` | feedback | `Toast` | M2 | The out-of-memory toast (`a1-9f`, since export 519d42a); the save-failure toast (`f4`) in M3; the toast stack follows in M4 (`a11-6`). |
| `Banner` | feedback | `Banner` | M2 |  |
| `ProgressBar` | feedback | `ProgressBar` | M2 | A long search's progress under the find bar (`a2-4c`, since export 519d42a); required-fields progress in the Form panel in M4. |
| `Spinner` | feedback | `Spinner` | M2 |  |
| `TaskProgress` | feedback | `TaskProgress` | M2 | Inline variant in the status bar while a large file is indexed (`a1-7`). |
| `DropZone` | empty | `DropZone` | M1 | Start empty state (`a1-5`). The DS has no general empty state ([G29](DESIGN_GAPS.md#g29)). |
| `Dialog` | overlays | `Dialog` | M2 | Custom popup; never a Material or Cupertino dialog (brief §6). OS file pickers are the only exception ([ADR 0018](adr/0018-native-file-pickers.md), accepted with [Q07](QUESTIONS.md#q07) on 2026-10-16). |
| `Menu` | overlays | `Menu` | M2 |  |
| `CommandPalette` | overlays | `CommandPalette` | M4 |  |
| `Field (internal)` | internal | `Field` | M1 | Shared label, hint, error and input box for every field. |
| `Popover (internal)` | internal | `Popover` | M3 | Shell for the colour and font pickers. |
| `Scrim (internal)` | internal | `Scrim` | M2 | Behind dialogs and the command palette. |

#### Additions and gap fixes as widgets

| Addition | Flutter widget | First needed | Notes |
|---|---|---|---|
| Document tabs (in `FmWindow`) | `DocumentTab` | M1 | Active, idle, unsaved, loading and overflow states. |
| Window chrome | `WindowChrome` | M1 | macOS traffic lights and Windows caption buttons. A Linux variant is not drawn ([G15](DESIGN_GAPS.md#g15)). |
| Status-bar save indicator | `SaveIndicator` | M3 | Unsaved, saving, saved, error and read-only (`f4`). The status bar itself is M1. |
| Thumbnail badges and legend | part of `PageThumbnail` | M2 | Badges arrive with their features (`f5`). |
| `FmNumber` | `FmNumber` | M3 | Locale-aware number field, formatted from the region setting. |
| Date picker (inline in `DocForm`) | `DatePicker` | M4 | Custom popup, also on mobile, where a note asks for the Material picker ([G55](DESIGN_GAPS.md#g55)). |
| Mention list and comment card (inline in `FmComments`) | `MentionList`, `CommentCard` | M4 | |
| Disabled with reason (gap) | state of `ToolButton`, `Menu` items and `SegmentedControl` | M1 | Tooltip "Available in a future version" ([G10](DESIGN_GAPS.md#g10)). Drawn since export 519d42a on the milestone builds, for example `a1-5-m1` and `a1-2c-m1`. |
| Empty state (gap) | `EmptyState` | M2 | Sidebar tabs, search and lists ([G29](DESIGN_GAPS.md#g29)). Drawn since export 519d42a in `a2-3m`: a 40 px sunken icon tile, a title, one line and an optional action. |

#### Building blocks in the app

| Building block | App region or use | First needed |
|---|---|---|
| `FmWindow` | Desktop shell: title bar with document tabs, mode bar, tool rows, sidebar and panel slots, canvas, status bar. | M1 |
| `FmSidebar` | Left sidebar (216 px) with six tabs. | M1 for the frame, M2 for the tabs |
| `FmEditPanel` | Right panel for a selected text block. | M3 (the panel slot is M1) |
| `FmDocPanel` | Right panel with the document summary and the Edit help. | M1 for the frame (the `FmDocPanel` class, `app/lib/features/shell/shell_panel.dart`: the title and More), M2 for the sections |
| `FmFormPanel` | Right panel for forms. | M4 |
| `FmComments` | Right panel for comments. | M4 |
| `FmSigCard` | Signature validation card. | P3; a neutral "not checked" row is needed from M2 ([G31](DESIGN_GAPS.md#g31)); `a2-14` draws that state in the Signatures tab |
| `FmStart` | Start screen. Its `gated` prop (export 519d42a) draws the M1 and M2 builds (`a1-5-m1`, `a1-4-m2`). | M1; recent files in M2 |
| `FmSettings` | Settings window with 11 panes. Its `gated` prop (export 519d42a) draws the M1 builds (`a11-1-m1`, `a11-1w-m1`, `a11-1h-m1`). | M1 for the skeleton, M4 for all panes |
| `FmNumber` | The `FmNumber` component. | M3 |
| `FmBoard` | Artboard frame used by the design-reference renderer. Not shipped. | M1 (tools) |
| `FmPhone` | Phone frame. Its bars define the mobile shell. | P5 |
| `FmKeyboard` | On-screen keyboard mock. Reference only. | P5 |
| `FmMHome` | Mobile Home tab. | P5 |
| `FmMReader` | Mobile reader. | P5 |
| `DocKira`, `DocForm`, `DocEkstre`, `DocCv`, `DocPlan` | Sample pages. Not shipped; each becomes a test-corpus PDF (section 9). | `DocKira` M2 and M3, `DocForm` M4, `DocEkstre` P2, `DocCv` P4, `DocPlan` P4 |

#### Component reference (generated)

| Component | Group | Props / variants | States | Notes for the Flutter port |
|---|---|---|---|---|
| `Icon` | core | name: IconName (key of ICON_PATHS; 145 bundled Lucide v0.460 glyphs + 84 added by ds-additions/fm-icons.js); size=16 (14 in dense rows/inputs, 20 large/touch, 12 only with strokeWidth 2; screens also use 10/11/18/24/25/26/28/48); strokeWidth=1.5; color='currentColor'; label?: string (sets role=img + aria-label, otherwise aria-hidden); className; style; flipRtl=false (sets data-flip-rtl, mirrored by [dir=rtl] scaleX(-1)). Unknown name renders an empty svg and console.warn.<br>*Variants:* stroke 1.5 (default), stroke 2 (12px and badges), flipRtl<br>*Sizes:* 10, 11, 12, 14, 16, 18, 20, 24 | default, rtl-mirrored | Decorative by default (aria-hidden). Pass label to expose as role=img. Do not use an icon font. Paint Lucide 24x24 path data with CustomPainter or flutter_svg: stroke-only, round caps/joins, stroke width scaled = strokeWidth*size/24, color from IconTheme/currentColor. Mirror with Transform.flip when Directionality is RTL and flipRtl is true. |
| `ICON_PATHS` | core (data) | Record<string, svgInnerMarkup>. 145 names: align-center, align-justify, align-left, align-right, arrow-left, arrow-left-right, arrow-right, arrow-up-down, arrow-up-right, ban, baseline, bold, book-open, bookmark, calendar, case-sensitive, check, chevron-down/left/right/up, circle, circle-alert, circle-check, circle-help, circle-x, clock, columns-2, command, copy, corner-down-left, crop, download, droplet, ellipsis, ellipsis-vertical, eraser, external-link, eye, eye-off, file-check-2, file-image, file-input, file-lock-2, file-output, file-pen-line, file-plus-2, file-search, file-spreadsheet, f… |  | Generate a Dart const Map<String, List<PathCommand>> (or SVG strings) from this table plus the 84 fm-icons.js additions; key-round and palette contain filled dots (fill=currentColor). |
| `Button` | core | variant: 'primary'\\|'secondary'\\|'ghost'\\|'danger' (default 'secondary'); size: 'sm'\\|'md'\\|'lg' (default 'md'); icon?: IconName (leading; 14px at sm, 16px otherwise); iconEnd?: IconName (hidden while loading); loading=false (leading icon becomes spinning loader-circle 0.9s linear, aria-busy=true, cursor progress); disabled=false; fullWidth=false; type='button'; children (label, wrapped in span); className; ...rest (title, onClick, style).<br>*Variants:* primary, secondary, ghost, danger<br>*Sizes:* sm 26px pad 0 8 text 12px, md 30px pad 0 12, lg 36px pad 0 16, touch density: 44/44/48 | default, hover, active/pressed, focus-visible, disabled (also aria-disabled=true), loading | Native button; aria-busy when loading; focus ring = 2px surface-raised gap + 2px ink-500 (--focus-ring). Labels are verb + object, no OK/Yes. Radius 4, gap 6, min-width 24, font 13/18 w500. primary: ink-600 -> hover ink-700 -> pressed ink-800, white text. secondary: surface-raised + 1px border-default + shadow-sm; hover adds 6% black overlay + border-strong; pressed 10% overlay, no shadow. ghost:… |
| `IconButton` | core | icon: IconName (required); label: string (required; aria-label and tooltip text); size: 'xs'\\|'sm'\\|'md'\\|'lg' (default 'md'); variant: 'ghost'\\|'secondary'\\|'primary' (default 'ghost'); active?: boolean (renders aria-pressed; undefined = not a toggle); shortcut?: string[] (shown in tooltip as inverse Kbd); tooltip=true; tooltipSide: 'bottom'\\|'top'\\|'left'\\|'right' (default 'bottom'); disabled=false (disabled buttons get no tooltip); className; ...rest.<br>*Variants:* ghost, secondary, primary<br>*Sizes:* xs 22px icon 14 radius 2, sm 26px icon 16, md 30px icon 16, lg 36px icon 20, to… | default, hover (surface-hover, icon -> text-primary), active/pressed (surface-pressed), focus-visible, toggled aria-pressed=true (accent-subtle bg, text-accent; hover accent-subtle-hover), disabled (icon-disabled, transparent) | aria-label always set; aria-pressed only for toggles; wrapped in Tooltip (450 ms delay) unless tooltip=false or disabled. Square, radius 4 (xs 2), icon color icon-primary. secondary: raised + border-default + shadow-sm. primary: accent bg + white icon. Compose with the Tooltip widget below. |
| `Tooltip` | core | content: node; shortcut?: string[]; side: 'bottom'\\|'top'\\|'left'\\|'right' (default 'bottom'); open?: boolean (controlled); delay=450 (ms); children (single element, receives aria-describedby while visible).<br>*Variants:* bottom, top, left, right | hidden, visible (fade-in 120ms) | role=tooltip with id, linked via aria-describedby; opens on mouseenter and focus after delay; closes on mouseleave, blur and Escape. Overlay at 6px offset, padding 4x8, radius 4, surface-inverse (paper-900 light / soot-900 dark), text-inverse, caption 12/16, shadow-sm, gap 8 before an inverse Kbd at 68% opacity, nowrap, z 400. Text is 1-4 words with no period. |
| `Kbd` | core | keys?: string[] (one span per key) or children as a single key; tone: 'default'\\|'plain'\\|'inverse' (default 'default').<br>*Variants:* default (keycap), plain (menus, palette, title-bar search), inverse (inside tooltips) | static | Rendered as <kbd>. Shortcuts appear only in tooltips and menus, never in sentences. Keycap: min 18x18, padding 0 4, 1px border-default with a 2px bottom border, radius 3, surface-raised, text-secondary 11px tabular; key gap 2. plain/inverse: no border or background (plain text-tertiary; inverse text-inverse at 0.68). Glyphs: mac ⌘ ⌥ ⇧ ↵ ⌫ ↑ ↓ Esc; Windows Ctrl Alt Shift. |
| `Badge` | core | tone: 'neutral'\\|'accent'\\|'success'\\|'warning'\\|'danger'\\|'edited' (default 'neutral'); dot=false (6px currentColor dot); icon?: IconName (12px, stroke 2); children; ...rest.<br>*Variants:* neutral, accent, success, warning, danger, edited (patched by ds-additions)<br>*Sizes:* 18px height | static | Decorative span; the dot is aria-hidden. Height 18, padding 0 6, radius 2, 1px border, label 11/14 w500 tabular, gap 4. neutral: surface-sunken/border-default/text-secondary; accent: accent-subtle/info-border/text-accent; success: success-bg/success-border/success; warning and danger follow the same pattern; edited (patched): accent-subtle bg, text-accent (dark: ink-300), transparent border. |
| `TextField` | forms | label?; hint?; error?: string (danger border, circle-alert message, aria-invalid, aria-describedby={id}-msg; replaces hint); icon?: IconName (leading, 14 at sm / 16 at md); suffix? (unit text, caption tertiary); size: 'sm'\\|'md' (default 'md'); disabled=false; id; className; inputRef; ...rest native input props (placeholder, value, defaultValue, type, autoFocus, aria-label, onChange).<br>*Variants:* md, sm, with icon, with suffix<br>*Sizes:* sm 26px pad 0 6, text 12, md 30px pad 0 8, text 13, touch 44 | default, placeholder, hover (border-strong), focus-within (border ink-500 + 1px ink-500 ring), error (danger border; focus ring danger), disabled (surface-sunken, border-subtle, text-disabled) | Label linked by htmlFor; error/hint linked by aria-describedby; aria-invalid when error. Focus is shown on the container, not as an outline on the input. Field = column gap 4: label 12/16 w500 text-secondary; control; hint caption tertiary OR error caption danger with 14px icon. Input box: surface-raised, 1px border-default, radius 4, gap 6, tabular numerals. |
| `Select` | forms | label?; options: (string \\| {value, label, disabled?})[]; value / defaultValue; onChange(value, event); size: 'sm'\\|'md' (default 'md'); icon?: IconName; disabled=false; id; className; ...rest (aria-label).<br>*Variants:* md, sm, with leading icon<br>*Sizes:* sm 26, md 30 | default, hover, focus-within, disabled | Native <select> restyled; label via htmlFor. Same box as TextField with a trailing chevron-down 14px. No error state. On desktop use a menu-style dropdown in the Menu style (not a Material DropdownButton look). |
| `NumberStepper` | forms | label?; value / defaultValue=0; min=-Infinity; max=Infinity; step=1; unit? (suffix); precision=0; size: 'sm'\\|'md' (default 'sm'); width=84; disabled=false; onChange(number); id.<br>*Variants:* with unit, without unit<br>*Sizes:* sm 26 (default), md 30 | default, hover, focus-within, disabled, arrow disabled at min/max, arrow hover/pressed | Input role=spinbutton with aria-valuenow/min/max; arrow buttons have tabIndex -1 and aria-labels Increase/Decrease. Commit = round to step, clamp, toFixed(precision). ArrowUp/Down = ±step (Shift x10); Enter blurs and commits; the typed draft accepts ',' as the decimal mark. Arrows are a stacked 18px-wide column separated from the input by a border-default line, with border-subtle between up and d… |
| `Checkbox` | forms | label?; description?; checked / defaultChecked; indeterminate=false (shows a minus); disabled=false; onChange(checked, event); id; ...rest (aria-label).<br>*Variants:* unchecked, checked, indeterminate, with description<br>*Sizes:* 16px box | default, hover (border paper-500 / dark soot-500), checked (accent fill, white check 12px stroke 2.75), indeterminate, focus-visible ring, disabled (sunken, border-subtle, label text-disabled), disabled+checked (fill border-strong) | Native input inside a <label>; indeterminate is set on the DOM property. Box 16, radius 3, 1px border-strong, surface-raised, 1px top offset; text gap 8; description caption tertiary; 120ms transitions. |
| `Radio` | forms | label?; description?; checked / defaultChecked; disabled=false; name; value; onChange(value, event); id; ...rest.<br>*Variants:* unchecked, checked, with description<br>*Sizes:* 16px | default, hover, checked (surface-raised fill, accent border, inset 4px accent ring), focus-visible (inset ring + focus ring), disabled | Native radio inside a label; group by name. Shares the Checkbox shell (.fm-check) with a round box. |
| `Switch` | forms | label?; checked / defaultChecked; disabled=false; onChange(checked, event); id; ...rest (aria-label).<br>*Variants:* off, on<br>*Sizes:* desktop track 28x16, thumb 12, travel 2->14px, touch track 44x26, thumb 22, travel 2->20px | default, on (accent track), focus-visible ring, disabled (opacity .5, label text-disabled, not-allowed) | input type=checkbox role=switch inside a label. Track radius full, off = border-strong, on = accent; thumb white with 0 1px 2px rgba(0,0,0,.25) shadow; slides with 120ms ease-out (inset-inline-start, so RTL-aware). Label gap 8. |
| `ColorPicker` | forms | label?; value / defaultValue='#1F1D1A'; documentColors: string[]=[] (adds an 'In this document' section); swatches = 16 standard colours (#1F1D1A #57534C #8A857C #C9C4BA #FFFFFF #2A4DAF #0F7F72 #1E7A46 #D98A0B #B42318 #962C21 #6B3FA0 #FFE066 #A8E6A1 #A8D1FF #FFB3C7); allowNone=false (value 'none' = chip with a red diagonal); open / defaultOpen=false / onOpenChange; onChange(hex \\| 'none'); size: 'sm'\\|'md' (default 'sm'); disabled=false.<br>*Variants:* sm trigger, md trigger, allowNone<br>*Sizes:* trigger 26/30, popover 232px wide, swatch 20px, 8-column grid, gap 6 | closed, open (popover rise-in 180ms), trigger hover/focus-visible ring, disabled, swatch hover (2px border-strong ring), swatch selected (aria-pressed: 2px surface gap + 2px accent ring), swatch focus-visible | Trigger aria-haspopup=dialog + aria-expanded; popover role=dialog 'Choose color'; swatches are buttons with aria-label=hex and aria-pressed; Esc closes; outside mousedown closes when uncontrolled. Trigger = input-styled button: 16px chip (radius 3, inset 1px rgba(0,0,0,.14) ring; dark: white .24) + uppercase hex value + chevron. Popover: surface-raised, radius 6, shadow-popover, section labels 11… |
| `FontPicker` | forms | label?; value: string (font name); fonts: {name, family?, group: 'document'\\|'system' (default 'system'), available?: boolean, substitute?: string}[]; warning?: string (overrides the missing-font note); open / defaultOpen=false / onOpenChange; onChange(name); size: 'sm'\\|'md' (default 'sm'); disabled=false.<br>*Variants:* normal, missing font (available:false), glyph-warning (patched wrapper [data-fm-glyph-warning])<br>*Sizes:* trigger 26/30, popover 280 wide, max-height 340 | closed, open, trigger hover/focus-visible, missing (warning border, triangle icon, italic secondary name, note below), disabled, row hover/focus, row selected (check), row missing ('Not installed' warning badge), empty search result | Trigger aria-haspopup=listbox + aria-expanded; popover role=listbox 'Fonts'; rows role=option aria-selected; the note has role=status; Esc closes. The trigger shows the font name in its own family (UI font if missing). Missing note: 'X isn’t installed. Ferman is showing Y instead.' (caption, warning colour, triangle). Popover: sticky search ('Search fonts'), groups 'In this document' / 'On this d… |
| `PanelSection` | panels | title; collapsible=true; defaultOpen=true; open / onOpenChange; actions? (node, right of the header); children.<br>*Variants:* collapsible, static (renders an h3)<br>*Sizes:* header min-height 36 | expanded, collapsed (chevron rotated -90deg, +90deg in RTL, 120ms), toggle focus-visible (inset ring) | section aria-labelledby; the toggle button has aria-expanded and aria-controls. Hairline border-subtle on top except the first section. Header padding 0 8 0 12; toggle 28px high with chevron-down 14 (icon-secondary) + title 13/18 w600. Body = column gap 10, padding 0 12 14. |
| `ModeTabs` | navigation | modes = FERMAN_MODES ({id, label, icon}[]); value / defaultValue (default first) / onChange(id); variant: 'segmented'\\|'underline' (default 'segmented'; underline is for web); showIcons=false; label='Mode' (aria-label).<br>*Variants:* segmented, underline<br>*Sizes:* segmented tab 26px (control-h-sm), pad 0 12, underline tab height = --modebar-h 40 (touch 48), pad 0 10 | idle (text-secondary), hover (text-primary + surface-hover), selected (raised + shadow-sm + 1px subtle ring; dark: soot-200, no shadow; icon text-accent), focus-visible (inset 2px ring), underline selected (2px accent bar, inset 10px, radius 2 2 0 0) | role tablist/tab, aria-selected, roving tabindex; Left/Right arrows (RTL-aware, wrapping) and Home/End move and select (selection follows focus). Track: surface-sunken, 1px border-subtle, radius 6, padding 2, gap 2; horizontally scrollable with a hidden scrollbar. The app (FmWindow) passes 8 localized modes including Tools (wrench). |
| `FERMAN_MODES` | navigation (data) | [{id:'view',label:'View',icon:'book-open'},{id:'edit',label:'Edit',icon:'file-pen-line'},{id:'comment',label:'Comment',icon:'message-square'},{id:'sign',label:'Fill & Sign',icon:'signature'},{id:'organize',label:'Organize',icon:'layout-grid'},{id:'convert',label:'Convert',icon:'refresh-cw'},{id:'protect',label:'Protect',icon:'shield'}] |  | Define a FermanMode enum. Screens add 'tools' (wrench). Mode names are proper nouns. |
| `SegmentedControl` | navigation | options: {value, label?, icon?, title? (tooltip and aria-label for icon-only), flipRtl?, disabled?}[]; value / defaultValue (default first) / onChange(value); label (aria-label); fullWidth=false; disabled=false.<br>*Variants:* text, icon+text, icon-only (wrapped in Tooltip), fullWidth<br>*Sizes:* segment height = control-h-sm - 6 (20px desktop), pad 0 8 (icon-only 0 5), min-width 24 | idle, hover, selected aria-checked (raised + shadow-sm + subtle ring; dark soot-200), focus-visible inset ring, disabled | role radiogroup/radio with aria-checked and roving tabindex; Left/Right (RTL-aware) move and select. Track: surface-sunken, border-subtle, radius 4, padding 2, gap 2; segment radius 3, 12px w500, 14px icon, gap 4. |
| `Toolbar` | navigation | variant: 'bar'\\|'floating' (default 'bar'); label (aria-label); children; className; style.<br>*Variants:* bar, floating<br>*Sizes:* bar height --toolbar-h 44 (touch 56) | static | role=toolbar; Left/Right arrows move focus between enabled buttons, selects and inputs (RTL-aware); skipped while focus is in an input or select; items inside a tablist or radiogroup are skipped unless tabindex=0. bar: padding 0 8, surface-panel, bottom hairline, gap 2. floating: inline, padding 3, surface-raised, radius 8, shadow-popover. Use FocusTraversalGroup + Shortcuts. |
| `ToolbarSeparator` | navigation | none<br>*Variants:* bar (margin 0 6), floating (margin 0 3) | static | role separator, aria-orientation vertical. 1x20 line in border-default. |
| `ToolbarSpacer` | navigation | none |  | Spacer() / Expanded. |
| `ToolbarGroup` | navigation | label (aria-label); children. |  | role=group. Row with gap 2. Not used in any screen. |
| `ToolButton` | navigation | icon?: IconName; label; showLabel=true; layout: 'inline'\\|'stacked' (default 'inline'); active?: boolean (aria-pressed); hasMenu=false (12px chevron caret at 0.7 opacity, aria-haspopup=menu); swatch?: CSS colour (14x3 bar, 4px from the bottom, centred); shortcut?: string[]; disabled=false; onClick; ...rest.<br>*Variants:* inline label, icon-only (showLabel=false), stacked, with menu caret, with colour swatch<br>*Sizes:* inline 30px (control-h-md), min-width 30, pad 0 8, icon 16, stacked 48px tall, min-width 56, pad 4 6, icon 20, text 11/14 | default, hover (surface-hover), pressed (surface-pressed), focus-visible ring, active aria-pressed (accent-subtle bg, text and icon accent; hover accent-subtle-hover), disabled (text-disabled, icon-disabled) | aria-label only when icon-only. Tooltip (label + shortcut) only when icon-only or a shortcut is given, and never when disabled. Text 13 text-primary, icon icon-primary, radius 4, gap 6. |
| `PageThumbnail` | pages | page: number; label? (replaces the number and aria-label 'Page N'; e.g. roman numerals); selected=false; state: 'idle'\\|'dragging'\\|'placeholder' (default 'idle'); dropIndicator?: 'before'\\|'after'; orientation: 'vertical'\\|'horizontal' (drop-line axis; default vertical); marker?: 'edited'\\|'comment'; width=112; aspect=1.4142; rotation: 0\\|90\\|180\\|270 (sideways rotations re-proportion the page, rotate the lines and add a rotate-cw icon by the number); children (custom page content; default = striped placeholder lines); onClick; ...rest (aria-label).<br>*Variants:* portrait, landscape… | idle, hover (surface-hover), focus-visible ring, selected (surface-selected bg, 2px accent ring around the page, accent number), dragging (raised, shadow-drag, scale 1.03, grabbing cursor, z 2), placeholder (1.5px dashed accent-border outline, content hidden), drop indicator before/after (2px accen… | button role=option with aria-selected inside a listbox; aria-label lists badges ('Page 1, edited, 2 comments, 1 warning'). Padding 8 8 6, radius 6, gap 6. Page: white with 1px border-default ring + shadow-sm, radius 1, page-filter applied. Number 11px w500 tabular text-secondary. Markers: 8px dots with a 2px page-bg ring (edited = --edit-changed, ink-600 after the patch; comment = amber-500). Tra… |
| `TextEditBox` | editing | state: 'idle'\\|'hover'\\|'selected'\\|'editing' (default 'editing'); meta?: string (frame label, e.g. 'IBM Plex Serif · 10.5 pt'; shown only when selected/editing); metaWarning=false (amber label + 10px triangle); showHandles? (defaults to true for selected/editing); width; style; children; onClick; ...rest (data-meta-placement 'above'\\|'below'\\|'margin' from ds-additions).<br>*Variants:* meta above (default), meta below, meta in margin, metaWarning<br>*Sizes:* handles 7x7, meta label 18px (--editbox-meta-h) | idle, idle:hover / hover (1px dashed rgba(58,96,198,.45)), selected (1.5px solid ink-500 outline + 8 handles), editing (same outline + rgba(58,96,198,.03) fill, role textbox), inert outside Edit mode ([data-fm-mode] patch) | role=textbox + aria-multiline only while editing; handles are aria-hidden. Padding 3 4 with negative margin -4 -5 so the frame hugs the text; text paper-900 (page colour, not theme). Handles: white fill, 1px ink-500 border, radius 1, at nw n ne e se s sw w (-4px offsets) with matching resize cursors. Meta label: ink-500 bg, white 10px w500 tabular, padding 0 6, radius 2 2 0 0, placed at bottom: 1… |
| `TextCaret` | editing | none | blink on/off (hard steps) | aria-hidden. 1.5px wide, 1.15em tall, vertical offset -0.2em, colour --edit-caret (ink-700); blinks every 1.05s with steps(1) (no fade). Disable the blink under reduced motion. |
| `PageMark` | editing | kind: 'selection'\\|'edited'\\|'missing-glyph'\\|'search'\\|'search-current'\\|'redact-pending'\\|'redact-applied' (default 'selection'); title? (tooltip; defaults: edited 'Edited', redact-pending 'Marked for redaction. Apply redactions to remove it permanently.', redact-applied 'Redacted', missing-glyph 'This font has no ‘<char>’. Ferman will use a similar font for this character.'); char? (the missing character); children; ...rest.<br>*Variants:* selection, edited (patched), missing-glyph, search, search-current, redact-pending, redact-applied | static (theme-independent page colours) | <mark data-kind> with title; redact-applied text is transparent and not selectable. Paint as inline span decorations clipped per line fragment (box-decoration-break clone). selection rgba(58,96,198,.26); edited (patched) = 1.5px dotted ink-600 underline at offset 3 with no fill (was teal fill + inset underline), plus a 2px margin bar drawn by the host; missing-glyph = rgba(217,138,11,.20) fill +… |
| `SearchReplaceBar` | editing | query=''; replaceWith=''; showReplace=false; current=0; total=0; matchCase=false; wholeWord=false; regex=false; notice?: string (warning callout); onQueryChange; onReplaceChange; onToggleReplace; onToggleOption(key: 'matchCase'\\|'wholeWord'\\|'regex', next); onPrev; onNext; onReplace; onReplaceAll; onClose; autoFocus=false.<br>*Variants:* find only, find + replace row, with notice<br>*Sizes:* 440px wide, padding 6, row gap 6 | empty query (no count), results 'N of M', no results ('No results' in danger, prev/next disabled), option toggles pressed (accent-subtle, text-accent), option hover/focus (inset ring), Replace/Replace all disabled when total=0 | role=search 'Find and replace'; count aria-live=polite; notice role=status; option toggles use aria-pressed; Esc closes, Enter = next and Shift+Enter = previous in the find field. Floating card: surface-raised, radius 8, shadow-popover. Row 1: chevron toggle (sm IconButton 'Show/Hide replace') \| sm input with search icon + 3 20px option toggles (case-sensitive, whole-word, regex) \| count (min-w… |
| `AnnotationTools` | annotations | tool / defaultTool='highlight' / onToolChange(id); color / defaultColor='yellow' / onColorChange(id); showLabels=false; variant: 'bar'\\|'floating' (default 'bar'); tools = ANNOTATION_TOOLS ({id, icon, label, key?, colored?, menu?}[]).<br>*Variants:* bar, floating, icon-only, labelled<br>*Sizes:* colour dot 18px, gap 4 | tool active (ToolButton pressed + swatch of current colour on colored tools), colour dot hover (2px border-strong ring), colour dot focus-visible, colour checked (2px surface-panel gap + 2px text-primary ring), colour group disabled (opacity .4, aria-disabled) when the active tool is not colored | Toolbar 'Comment tools'; colours are role=radiogroup 'Color' with radio buttons (aria-checked, aria-label). Palette: yellow, green, blue, pink, red, ink (labelled 'Black', #1F1D1A). Composition of Toolbar + ToolButton + separator + a radio dot row. Dark theme dot ring: inset 1px rgba(255,255,255,.28). Note that 'ink' means black here, while Highlight's 'ink' maps to blue ink #2A4DAF. |
| `ANNOTATION_TOOLS` | annotations (data) | select (mouse-pointer-2, V); highlight (highlighter, H, colored); underline (underline, U, colored); strikethrough (strikethrough, S, colored); note (sticky-note, N, colored); text 'Text box' (type, X); pen 'Draw' (pen-tool, P, colored); shapes (square, R, menu, colored); stamp (stamp, menu). FmWindow overrides it: text 'Text', + callout (message-square, C), shapes uses icon 'shapes', + measure (ruler, M, menu). |  | Model as an AnnotationTool enum with icon, label, shortcut, colored and hasMenu. |
| `Highlight` | annotations | color: 'yellow'\\|'green'\\|'blue'\\|'pink'\\|'orange'\\|'red'\\|'ink' (default 'yellow'; ink = --annot-blue-ink #2A4DAF) or any CSS colour; variant: 'highlight'\\|'underline'\\|'strikethrough'\\|'squiggly' (default 'highlight'); children; ...rest.<br>*Variants:* highlight (fill, multiply blend), underline (2px, offset 2), strikethrough (2px), squiggly (wavy 1.5px, offset 3) | static | <mark>. Document colours, the same in both themes: yellow #FFE066, green #A8E6A1, blue #A8D1FF, pink #FFB3C7, orange #FFC58A, red #D93A2B. Highlight uses BlendMode.multiply over the text; padding 0 1 with margin 0 -1, radius 1, per-line fragments. |
| `StickyNote` | annotations | collapsed=false; color: 'yellow'\\|'green'\\|'blue'\\|'pink'\\|'orange' (or CSS); author; time; text; replies: {author, time, text}[]=[]; onToggle; onReply(text) (pass null to hide the reply footer); children.<br>*Variants:* collapsed pin, expanded card<br>*Sizes:* pin 24x24 radius 4, card 256px wide, head 32px | pin default, pin focus-visible (2px white + 2px ink-500 ring), expanded, head icon-button hover (rgba(0,0,0,.08)) | Pin: button aria-label 'Note from X'. Card: role=dialog 'Note from X'; header xs IconButtons 'More' and 'Close note'; reply input 'Reply' submits on Enter. Pin: tinted bg, message-square 14, shadow 0 0 0 1px rgba(0,0,0,.12) + 0 2px 4px rgba(0,0,0,.14). Card: surface-raised, radius 6, shadow-popover; tinted head (author 12 w600 ellipsis; time 11 tabular paper-700; icons paper-800); body 13/18 pre-… |
| `Stamp` | annotations | label='Approved'; tone: 'seal'\\|'ink'\\|'green'\\|'neutral' (default 'seal'); meta? (second line, e.g. name and date); rotation=-3 (degrees); lang (set 'tr' so uppercase gives İ); size=18 (font px); style.<br>*Variants:* seal (#B5372A), ink (ink-600), green (green-600), neutral (paper-800) | static | role=img, aria-label 'Stamp: <label>, <meta>'. 2px border + 1px outline at offset 2, both in currentColor; radius 3; padding 7 14 6; w600 uppercase, letter-spacing .14em; multiply blend at opacity .9; meta 9px w500 tabular, no uppercase. Seal red is used only for stamps. |
| `PdfFormField` | fill-sign | type: 'text'\\|'multiline'\\|'date'\\|'dropdown'\\|'checkbox'\\|'radio'\\|'signature' (default 'text'); state?: 'empty'\\|'filled'\\|'focus'\\|'error'\\|'readonly' (derived when omitted: error if error is set, filled if value/checked/signedAs, else empty); value; placeholder; label (10/12 w500 #6F6A62 above the box); required=false (red * at the top-end corner); error?: string (11/14 red-600 message with 12px circle-alert); options: string[] (dropdown; disabled first option = placeholder or 'Choose'); width=160; checked (checkbox/radio); signedAs (signature name); onChange(value); onClick.<br… | empty, hover (border ink-400), focus (border ink-500 + 2px rgba(58,96,198,.22) ring, white bg), filled (4% ink bg, 35% ink border), error (red-600 border + 16% red ring + 4% red bg), readonly (transparent, dotted #A39E94 underline only), signature signed (solid 1px border, italic 22px Plex Serif #1… | Inputs carry aria-label, aria-invalid and aria-required. Checkbox/radio: span role=checkbox\|radio with aria-checked and tabIndex 0. Signature: role=button labelled 'Sign here' or 'Signed by X'. These are on-page widgets drawn over the PDF in page colours: bg rgba(58,96,198,.07), border ink-300, text 12px Plex Serif paper-900; placeholder 11px UI font #8A857C. |
| `SignaturePad` | fill-sign | mode / defaultMode='draw' ('draw'\\|'type'\\|'image') / onModeChange; name='' (initial typed text); ink / defaultInk='#1F1D1A' (options Black #1F1D1A, Blue #1A3170); saveForLater=true (default for the 'Save on this device' checkbox); onChange({mode, strokes, text, ink, empty}); initialStrokes: [x,y][][]=[].<br>*Variants:* draw, type, image<br>*Sizes:* area height 188, radius 6 | empty (hint 'Sign above the line' / 'Type your name above the line'), drawing, has strokes/text, Clear disabled while empty, ink selected, area focus-visible ring | SegmentedControl 'Signature method'. Draw area is focusable (aria-label 'Signature drawing area. Draw with a mouse, trackpad, pen or finger.'). Ink choice is a radiogroup 'Ink color'. Typed field aria-label 'Type your name'. Area: white page-bg, 1px border-default, crosshair cursor, touch-action none. Baseline 1px #C9C4BA at bottom 48 with inset 28; '×' 18px #A39E94 at start. Strokes are quadrati… |
| `Toast` | feedback | tone: 'neutral'\\|'success'\\|'warning'\\|'danger' (default 'neutral'; default icons info / circle-check / triangle-alert / circle-alert); title (≤4 words); message; icon? (override); action?: {label, onClick} (sm ghost button in accent colour); onClose? (sm 'Dismiss' x).<br>*Variants:* neutral, success, warning, danger<br>*Sizes:* 380px wide, padding 10 6 10 12 | entering (rise-in 260ms), static | danger: role=alert, aria-live=assertive; others: role=status, aria-live=polite. surface-raised, radius 6, shadow-popover, gap 10. Icon 16 coloured by tone (neutral icon-secondary, success success-solid, warning warning-solid, danger danger). Title body-strong, message caption secondary. Region (.fm-toast-region): pinned to the canvas end/bottom (inset-inline-end 16, bottom statusbar-h+12), gap 8,… |
| `Banner` | feedback | tone: 'info'\\|'success'\\|'warning'\\|'danger'\\|'neutral' (default 'info'); variant: 'box'\\|'bar' (default 'box'); title?; icon? (override; defaults info / circle-check / triangle-alert / circle-alert / info); actions? (node); onDismiss? (xs 'Dismiss' x); children.<br>*Variants:* box, bar (full-bleed strip, bottom border only, inline title+text)<br>*Sizes:* box padding 8 10, radius 4, bar padding 6 12 | static | role=alert for danger and warning, role=status otherwise. Tinted bg + full 1px border per tone (info: info-bg/info-border; neutral: surface-sunken/border-subtle). Caption 12/16, title 12/16 w600, 14px icon coloured by tone. No coloured left stripes. |
| `ProgressBar` | feedback | value: 0..1; indeterminate=false; tone: 'accent'\\|'success'\\|'danger'\\|'paused' (default 'accent'); size: 'sm'\\|'md' (default 'sm'); label?; showValue=false (shows a percentage).<br>*Variants:* accent, success, danger, paused (border-strong fill)<br>*Sizes:* sm 4px, md 6px | determinate (width transition 180ms), indeterminate (40% bar sliding 1.4s ease-in-out, RTL-aware) | Track role=progressbar with aria-valuemin 0, max 100, now = pct (omitted when indeterminate); aria-label from a string label. Track: surface-sunken, radius full, inset 1px border-subtle ring. Head row: label caption secondary + value tabular tertiary. |
| `Spinner` | feedback | size=16; onAccent=false; label='Loading'.<br>*Variants:* default, onAccent (white on accent)<br>*Sizes:* 12 (border 1.5), 16 (border 2), 32+ (border 3) | spinning (0.8s linear) | role=status with aria-label. Ring in border-default with the top arc in accent (onAccent: rgba(255,255,255,.35) + white top). |
| `TaskProgress` | feedback | title; detail? (e.g. 'Page 14 of 120 · about 2 minutes left'); value: 0..1; indeterminate=false; state: 'running'\\|'paused'\\|'done'\\|'error' (default 'running'); icon='scan-text'; variant: 'card'\\|'inline' (default 'card'); onCancel; onPause; onResume; primaryAction?: {label, onClick}; secondaryAction?: {label, onClick}.<br>*Variants:* card, inline (status bar)<br>*Sizes:* card 380px, padding 12 12 12 14, inline progress width 96 | running, paused, done (circle-check, success tile), error (circle-alert, danger tile) | role=status (card adds aria-live=polite). Card: surface-raised, radius 6, shadow-popover. Row: 28px icon tile (accent-subtle/text-accent; done success-bg; error danger-bg; paused sunken) + title body-strong + detail caption tabular + Cancel x (sm, running/paused only). ProgressBar shown only while running/paused (tone accent, or paused). Actions, right-aligned: Pause (ghost, running), Resume (sec… |
| `DropZone` | empty | state: 'idle'\\|'over'\\|'error' (default 'idle'; 'over' is also set internally on dragover); title / subtitle (idle-state overrides); onOpen; onCreate? (adds a lg secondary 'New blank PDF' button); shortcut=['⌘','O'] (appended to the primary 'Open a PDF' button at 75% opacity); recent: {name, meta}[]=[] (idle only); onOpenRecent(file); footnote='Files stay on this device. Ferman never uploads your documents.'; onFiles(File[]); minHeight.<br>*Variants:* idle, over, error, with recent list, with create action<br>*Sizes:* min-height 380, padding 48 32, radius 12, gap 16 | idle (dashed border-strong), drag-over (solid accent border, accent-subtle bg, accent icon, no actions), error (danger-border, danger icon, 'That file isn’t a PDF'), recent row hover / focus-visible (inset ring) | The title is an h2; recent files are buttons. Icon tile 56px, radius 12, raised + ring + shadow-sm, 24px icon (file-text / download / circle-alert). Title 20/26 w600 tight; subtitle 14/20 secondary, max-width 420; recent rows 36px with file-text 16 + name + tabular meta; footnote caption tertiary with hard-drive 14. Use DropTarget (desktop_drop). |
| `Dialog` | overlays | open=true; inline=false (no scrim and no focus trap; used for docs/artboards); title; description?; icon? (32px glyph tile); tone: 'default'\\|'danger'\\|'warning' (default 'default'); size: 'sm'\\|'md'\\|'lg' (400/520/640; default 'md'); children (body, hidden when empty); actions (right-aligned footer node); footerStart (footer start slot); onClose (x sm IconButton + Esc + scrim mousedown); closeLabel='Close'.<br>*Variants:* default, danger (alertdialog, red glyph), warning (amber glyph)<br>*Sizes:* sm 400, md 520, lg 640, max-width 100vw-32, max-height 100vh-64 | entering (rise-in 260ms; scrim fade 180ms), open, body empty (footer padding-top 20) | role=dialog (alertdialog when danger), aria-modal, aria-labelledby (title) and aria-describedby (description). Focus goes to [data-autofocus] or the first tabbable element in the body; Tab/Shift+Tab are trapped; focus is restored on close; Esc closes. surface-raised, radius 8, shadow-dialog. Head padding 18 16 0 20, gap 12; title 16/22 w600; description 14/20 secondary. Body padding 16 20, prose.… |
| `Menu` | overlays | items: ({id?, label, icon?, shortcut?: string[], checked?: boolean, disabled?, danger?, submenu?: boolean, flipRtl?} \\| {separator: true} \\| {heading: string})[]; onSelect(id \\|\\| label, item); onClose; label (aria-label); autoFocus=false (focuses the first enabled item); style.<br>*Variants:* plain, with check column (any item has checked), with icons, with shortcuts, with submenu chevrons, danger item<br>*Sizes:* min-width 208, padding 4; item height 28 | item hover/focus (surface-selected-strong = ink-100), danger (red text and icon), disabled (text-disabled, icon-disabled), checked (accent check) | role=menu; items are role=menuitem or menuitemcheckbox (aria-checked) with tabIndex -1; Up/Down wrap, Home/End, Esc closes; separators role=separator; headings role=presentation. surface-raised, radius 6, shadow-popover, fade-in 120ms. Item: padding 0 8, radius 4, gap 8, body 13; icon 16 icon-secondary; label ellipsis; plain Kbd at the end; submenu chevron-right 14 (flips in RTL). Separator 1px b… |
| `CommandPalette` | overlays | open=true; inline=false; groups: {label, items: {id, label, icon? (default 'command'), hint?, shortcut?: string[], keywords?}[]}[]; query / defaultQuery='' / onQueryChange; onSelect(id, item); onClose; placeholder='Search commands, pages and text'; emptyText? (default 'No commands match “q”. Press Enter to search the document instead.').<br>*Variants:* modal (top scrim at 14vh), inline<br>*Sizes:* 600px wide; input 48px; list max-height 344; item 34px; footer 34px | empty query (all groups), filtered (Turkish-locale case-insensitive substring match on label + keywords; matched part bold), active item (aria-selected: surface-selected-strong, accent icon), no results | role=dialog 'Command palette'; input role=combobox (aria-expanded, aria-controls, aria-activedescendant); list role=listbox with group roles; options role=option. Up/Down clamp, Enter runs, Esc closes; mouse move sets the active item; the active item scrolls into view. surface-raised, radius 8, shadow-dialog. Input row: 18px search icon + 16/22 field + Esc Kbd, bottom hairline. Group label 11px t… |
| `Field (internal .fm-field)` | internal | CSS-only anatomy shared by TextField, Select, NumberStepper, ColorPicker, FontPicker and FmNumber: .fm-field (grid gap 4), __label, __hint, __error; .fm-input box with --sm, --error, --warning, --disabled; __control; __suffix.<br>*Variants:* md, sm, error, warning (border warning-solid), disabled | hover, focus-within, error, warning, disabled | Build one FermanInputDecorator widget and reuse it for every field. |
| `Popover (internal .fm-popover)` | internal | CSS shell used by ColorPicker and FontPicker: .fm-popover-anchor / -host; .fm-popover at top 100%+4, inset-inline-start 0, z 100; __section label.<br>*Variants:* colour (232w), font list (280w, max-height 340, scroll) | open (rise-in 180ms) | Use OverlayPortal/CompositedTransformFollower; surface-raised, radius 6, shadow-popover; fade + 4px rise; no blur. |
| `Scrim (internal .fm-scrim)` | internal | .fm-scrim (centred, padding 16, --surface-scrim, fade 180ms) and .fm-scrim--top (top-aligned at 14vh, lighter 18% / dark 40%).<br>*Variants:* dialog, palette (top) | fading in | ModalBarrier colours per theme; tapping it calls onClose. |

#### Additions (`DS additions.dc.html`, `ds-additions/`)

| Addition | Kind | Description |
|---|---|---|
| PageMark kind='edited' | patched component | Fix 3. Edited text is a 1.5px dotted ink-600 underline (offset 3, skip-ink none) with no fill and no box-shadow. A 2px margin bar (--edit-mark, width --edit-mark-bar-w 2px, sitting --edit-mark-bar-gap 12px outside the text column) is drawn by the host (see DocKira). This replaces the original teal fill + inset underline. Fills are reserved for highlights. |
| Badge tone='edited' | patched component | Was teal (edit-changed-bg, #4FC2B4 in dark). Now accent-subtle bg + text-accent, with ink-300 text in dark. |
| TextEditBox data-meta-placement | patched component | Fix 1. The frame label goes 'above' (default, only when the space is clear), 'below' (top: 100%+1px, radius 0 0 2 2) or 'margin' (top -1.5px, inset-inline-end: 100%+8px, i.e. in the page margin, radius 2). Rule: the first free side wins, in the order above, below, margin. Label height token --editbox-meta-h 18px. |
| FontPicker [data-fm-glyph-warning] | patched component | Fix 2. When the font lacks a glyph, the trigger shows only an amber border (--warning-solid) and a 14px masked triangle-alert icon before the name. The sentence moves to a panel Banner (tone warning, title 'Missing character', 'This font has no ‘ğ’. Ferman will use a similar font for this character.') with 'Choose a font…' and 'Keep as is' buttons. The original missing-font state (available:false plus a note) is separate and unchanged. |
| Text frames inert outside Edit | patched component | [data-fm-mode] not equal to 'edit' makes .fm-editbox use cursor:auto and removes the idle hover outline, so one page markup works in every mode. |
| [data-fm-flip] RTL icon mirroring | patched component | [dir=rtl] [data-fm-flip] svg { scaleX(-1) }. Mirrors directional icons inside DS buttons that have no flipRtl prop (undo/redo, prev/next field chevrons, mobile back). |
| ModeTabs 'Tools' mode | patched component | FmWindow passes 8 modes: FERMAN_MODES plus {id:'tools', icon:'wrench'}, with localized labels (en/tr/de/ar/ja). Tools tool row: Compress, Compare, Accessibility, PDF/A & preflight, Batch actions, Print, Measure, Version history \| AI assistant. |
| Thumbnail badges + legend | new component | Fix 5. Edited stays an 8px dot in --edit-changed (now ink-600) with a 2px page-bg ring. Other badges are 16px (--thumb-badge) chips stacked at the top-end, gap 3: white bg, 1px paper-200 ring, paper-800 10px icon stroke 2. They are comments (message-square), form fields (text-cursor-input) and signature (signature). The warnings chip uses amber-50 bg, amber-200 ring, amber-700 icon (triangle-alert). Only warnings are coloured. A 236px legend popover (opened by an info xs IconButton) explains ea… |
| FmNumber | new component | Locale-aware number field with the same anatomy as NumberStepper (sm input, suffix unit, stacked 11px chevrons). The value is formatted with Intl.NumberFormat for the app region (en-US 10.5, tr-TR/de-DE 10,5 and 1.234,5, ar, ja-JP) and typing accepts either separator. Optional label and error (danger border + error text, e.g. 'Enter 4–96 pt.'). role=spinbutton. |
| Document tabs (FmWindow title bar) | new component | Tab states: active (32px, surface-panel, 1px border-subtle, radius 8 8 0 0, margin-bottom -1 so it attaches to the mode bar, body-strong name); idle (28px inner pill, radius 6, text-secondary, hover surface-hover); unsaved (a 7px dot replaces the close button; icon-primary when active, icon-secondary when idle); clean (xs IconButton x 'Close document' ⌘W/Ctrl W); loading (Spinner 12 replaces the file icon); locked (icon 'lock'); repaired (icon 'wrench'); overflow ('+N' ghost sm button with chev… |
| Window chrome | new component | macOS traffic lights (12px circles #FF5F57 #FEBC2E #28C840 with a 0.5px inner ring). Windows caption buttons 46px wide (--win-caption-w) with minus/square/x icons at stroke 1 (square 13px stroke 1.2); hover surface-hover, close hover #C42B1C (--win-close-hover, both themes) with a white icon. Home: house IconButton, or on the Start screen an active 'Ferman' wordmark tab (Plex Serif 600 15px). |
| Extra Lucide glyphs (fm-icons.js) | new component | 84 glyphs merged into ICON_PATHS (the Index says '+64', but the file has 84): paperclip sparkles volume-2 camera star pin usb credit-card cpu bell user users funnel heart code git-compare git-commit-vertical accessibility presentation tablet cloud archive list-checks workflow sliders-horizontal circle-dot circle-plus triangle pentagon slash reply at-sign check-check arrow-down arrow-up phone id-card nfc contrast rows-2 percent tag file-x mic skip-forward skip-back expand maximize-2 server badge… |
| DatePicker popover (inline in DocForm) | new component | Implicit component, no DS equivalent. 260px popover (surface-raised, radius 8, shadow-popover, padding 10). Header: chevron-left/right sm IconButtons around 'November 2026'. role=grid of 7 columns (weekday labels 11px tertiary; 30px day cells, radius 4; selected day accent with white w600 text; outside-month days text-disabled). Footer: 'Format DD.MM.YYYY · from the form' caption + 'Today' ghost sm button. |
| Mention list + comment card (inline in FmComments) | new component | Implicit components. Comment card: role=article, surface-raised, radius 6, 1px border (expanded = accent border + 1px accent ring), resolved at opacity .78. Contents: 20px type chip tinted by annotation colour, author, time, resolved check, quoted text in serif ellipsis, body, replies indented 10 with an @mention in accent w500, 'N replies' link, composer with Resolve/Reply, 'Resolved by…' + Reopen. Mention list: 220px listbox ('People in this document'), 30px options with 20px initials avatars… |
| Status-bar save indicator (inline in FmWindow) | new component | Five states: unsaved (7px warning-solid dot + 'Unsaved changes' in text-primary), saved (hard-drive 12 + 'Saved on this device · 14:32'), saving (Spinner 12 + 'Saving…'), error (circle-alert, danger, 'Couldn’t save'), readonly (lock + 'Read-only'). Paired with the Save button state (disabled unless unsaved, loading while saving). |
| Edit / compare / OCR mark tokens | token | --edit-changed: ink-600 (was #0F7F72 teal); --edit-changed-bg rgba(42,77,175,.08); --edit-mark ink-600; --edit-mark-bar-w 2px; --edit-mark-bar-gap 12px; --overflow-mark amber-500; --ocr-low amber-500; --ocr-low-bg rgba(217,138,11,.16); --diff-added rgba(46,154,92,.22) / --diff-added-line green-500; --diff-removed rgba(217,58,43,.18) / --diff-removed-line red-500; --diff-changed rgba(217,138,11,.22) / --diff-changed-line amber-500; --translated-mark rgba(58,96,198,.10). All are page-tuned and th… |
| Layout tokens | token | --editbox-meta-h 18px; --thumb-badge 16px; --doctab-h 28px; --doctab-w 188px; --doctab-w-min 112px; --win-caption-w 46px; --win-close-hover #C42B1C (also re-declared in dark). |
| Mobile tokens | token | --ios-navbar-h 44px; --ios-tabbar-h 83px; --android-appbar-h 64px; --android-navbar-h 80px; --fab-size 56px; --sheet-radius = --radius-xl (12px); --grabber-w 36px. Use them with data-density=touch (44px targets). |
| Extended font stacks | type role | --font-ui = IBM Plex Sans, Plex Sans Arabic, Plex Sans Hebrew, Plex Sans Devanagari, Plex Sans JP, Plex Sans KR, Noto Sans SC, then system UI fonts (21 launch languages). --font-doc-cjk = Noto Serif JP / Plex Sans JP. --font-hand-1 Caveat 500, --font-hand-2 Homemade Apple, --font-hand-3 Dancing Script 500 for typed signatures (each must cover ş ğ ı İ; styles without coverage are hidden). fm-additions.css pulls these from Google Fonts at runtime, along with EB Garamond, Cormorant Garamond, Crims… |
| CJK type overrides | type role | [lang ja\|zh\|ko]: font-synthesis none (never fake bold or italic). type-body and body-strong 13/20, caption 12/18, label 11/16, panel-title 13/20 w600 (20px leading at 13px). |
| Button state matrix | interactive state | Primary (Save + save icon), Secondary (Cancel) and Danger (Apply), each shown as default, hover, focus (ring), active (pressed), disabled and loading (spinner; for Secondary the label reads 'Exporting'). The error column for Primary says 'Shown as toast': buttons have no error state. |
| IconButton state matrix | interactive state | rotate-cw 'Rotate page': default; hover shows the open Tooltip with the shortcut ⌘ ]; focus ring; active = toggled (bold, active=true → accent-subtle); disabled (redo); loading = Spinner 16 in place of the icon. |
| TextField state matrix | interactive state | sm 'Page' field: default (placeholder), hover (border-strong), focus (ink border + ring, value 12), active = same as focus, disabled, error ('52' with 'Enter 1–48.'). |
| Checkbox / Switch state matrix | interactive state | Default, hover (checkbox border paper-500), focus (checked + ring), active (checked), disabled. No loading or error states. |
| PageThumbnail state matrix | interactive state | Width 64: default, hover (surface-hover), focus ring, active = selected, disabled column = placeholder, loading column = dragging, error column = 'Warning badge' (amber chip). |
| [data-fm-force] / [data-fm-artboard] harness | interactive state | Documentation only. Forces hover/focus/active styles for .fm-btn variants, .fm-iconbtn, .fm-input, .fm-check__input, .fm-switch__input, .fm-fonttrigger, .fm-colortrigger, .fm-thumb, .fm-menu__item:nth-child(2) and .fm-pff__box. [data-fm-artboard] limits .fm-dialog max size to the artboard. In Flutter, reproduce it with a WidgetStatesController / forced-state parameter on each control for golden tests. |

#### Building blocks (`Fm*`, `Doc*`)

| Block | Renders | Props | Becomes in the app |
|---|---|---|---|
| `FmWindow` | The complete desktop editor frame (fills its parent). (1) Title bar, 38px, surface-sunken: mac traffic lights or an 8px Windows inset; a Home IconButton(house), or when home=true an active 'Ferman' wordmark tab; the document tablist (active/idle/unsaved/loading/custom-icon tabs, '+N' overflow, '+' Open file ⌘O); a 'Search ⌘K' ghost button; Settings IconButton (⌘,); Windows caption buttons. (2) Mode bar, 40px: sidebar toggle (panel-left, ⌥⌘S), ModeTabs with 8 modes, spacer, optional AI toggle (sparkles), panel toggle (panel-right, ⌥⌘P), primary sm Save (disabled unless unsaved, loading while saving, tooltip 'No changes to save'). (3) One 44px Toolbar per mode. view: Select V, Hand H, Marquee… | Declared: platform 'mac'\|'win' (default mac); mode 'view'\|'edit'\|'comment'\|'sign'\|'organize'\|'convert'\|'protect'\|'tools' (default 'edit'; '' or 'none' hides the mode bar and tool row); lang 'en'\|'tr'\|'de'\|'ar'\|'ja'; save 'unsaved'\|'saved'\|'saving'\|'error'\|'readonly' (default unsaved); tool (active tool id; defaults per mode: view select, edit editText, sign fill, protect redact; in comment mode it is the annotation tool, default highlight); page=1; pages=3; zoom=100; home=false;… | AppShell (desktop). Split into TitleBar (WindowChrome + DocumentTabStrip + global search/settings), ModeBar, ToolRow (one Toolbar config per FermanMode), Body (Sidebar \| Canvas \| Panel) and StatusBar (page nav, zoom, background-task inline progress, save indicator) widgets. Used in 21 files (131… |
| `FmSidebar` | The 216px left sidebar (surface-panel, end hairline). Top: full-width icon SegmentedControl with 6 tabs (files, list-tree, paperclip, layers, signature, search). Header row (34px): title + count + per-tab actions (Pages: legend info toggle; Outline: Add bookmark ⌘B + More; Attachments: Attach). Tab bodies: pages = listbox of 104px PageThumbnails with the badge stack (edited dot; comments, fields, signature and warning chips) and an optional legend popover; outline = nested bookmark rows (28px, indent 8+18*level, chevron for parents, page number, current row accent on surface-selected, one row can be an inline rename TextField); attachments = cards (file icon, name, size · date, download xs)… | tab 'pages'\|'outline'\|'attachments'\|'layers'\|'signatures'\|'search' (default pages); doc 'kira'\|'fatura'\|'ekstre'\|'form'\|'tez'\|'cv'\|'nda'\|'scan' (selects page count, badges and the outline set; 'tez' has 64 pages with roman labels and a thesis outline); current=1 (selected page); lang 'en'\|'tr'\|'de'\|'ar'\|'ja'; legend=false; outlineEdit=-1 (index of the row being renamed); thumbs ({edited?, comments?, fields?, signed?, warn?, label?, aspect?}[] overrides the doc preset); query='ki… | Left sidebar region (PageSidebar widget with tabs Pages/Outline/Attachments/Layers/Signatures/Search). Note: only kira, ekstre, form and cv have Doc* fixtures; fatura, tez, nda and scan exist only as thumbnail presets. |
| `FmEditPanel` | 264px right properties panel for a selected text block. Header 40px: 'Text block' + edited Badge + reset (rotate-ccw) and More xs buttons. PanelSection 'Text': FontPicker (wrapped in [data-fm-glyph-warning] when glyph is on), FmNumber size (pt) + ColorPicker (document colours #1F1D1A #57534C #2A4DAF), Bold/Italic/Underline sm IconButtons with ⌘B/I/U, alignment SegmentedControl (left/center/right/justify). Optional glyph Banner with 'Choose a font…' / 'Keep as is'. Optional overflow Banner 'Text doesn’t fit' with 3 full-width actions ('Extend block by 1 line' primary, 'Tighten spacing slightly (−0.6%)', 'Keep and warn' ghost). PanelSection 'Spacing': 4 FmNumbers (Character %, Line, Before pt… | lang 'en'\|'tr'\|'de'\|'ar'\|'ja' (labels and number format); glyph=false (font becomes Garamond Premier Pro, size 11.5, warning state); overflow=false; edited=true; font (default IBM Plex Serif); size=10.5; blockLang 'tr'\|'en'\|'de'\|'ar'\|'ja' (default tr); fontOpen=false; posOpen=true; platform 'mac'\|'win' (shortcut glyphs). Undeclared: colorOpen, color (default #1F1D1A), bold, align (default justify), hyph (default true), spell (alias for blockLang). | Right panel region: TextBlockPropertiesPanel shown in Edit mode while a text block is selected. |
| `FmDocPanel` | 264px right panel. kind=view → title 'Document': static PanelSection 'File' (2-column key/value grid: Pages, Page size 'A4 · 210 × 297 mm', File size, PDF version, Location, Modified), 'Fonts in this document' (rows with type icon, name, Badge Embedded (neutral) / Partial (warning) with a subset note), 'Security' (lock-open 'No password', badge-check '1 valid signature, page 3'). kind=edit → title 'Edit': help rows ('Click any text to select its block…', 'Tab moves between blocks; Enter starts editing. Hold ⌥/Alt to show every block.'), an edited Badge '3 edits' 'in this session' + 'Review' ghost button, and the fonts section. | kind 'view'\|'edit' (default view); platform 'mac'\|'win' (⌥ vs Alt key). | Right panel region: DocumentPropertiesPanel (View mode) and the Edit-mode panel with no selection. |
| `FmFormPanel` | 264px right 'Form' panel. Top: ProgressBar labelled 'x of y required fields', summary ('20 fields · N required left · field k of n'), 'Highlight fields' and 'Show tab order' Switches. List of 20 fields in 3 sections ('Kişisel bilgiler', 'Yeni adres', 'Beyan ve imza'), 28px rows with a status icon (circle-check success = done, text-cursor-input accent = current, circle-alert danger = error, circle icon-disabled = empty) and a red 'Required' tag. The current row is accent on surface-selected. Footer: 'Clear form…' ghost + primary 'Finish' (check). | filled 'partial'\|'more'\|'all' (default partial); current = field id (default 'ad'; ids tc, dogum, ad, soyad, cins, medeni, tel, eposta, il, ilce, mahalle, sokak, dis, ic, tasinma, hane, beyan1, beyan2, tarih, imza); order=false; errorField = field id; signed=false (counts 'imza' as done when filled=all). | Right panel region in Fill & Sign mode: FormFieldsPanel. Mirrors the DocForm fixture field ids. |
| `FmComments` | 300px right 'Comments' panel. Header: title + neutral count Badge + filter toggle (list-filter) + More. SegmentedControl Open 7 / Resolved 2 / All 9; optional filter row with 3 sm Selects (author, type, sort). Cards grouped by page ('Page N' + count), each showing a chip with the annotation type icon (highlight, sticky-note, square, pen-tool, underline, stamp, strikethrough, type) tinted by colour, author, time, quoted text, body, replies with @mentions, collapsed 'N replies', a composer (focused sm input with a caret, Resolve ghost + Reply primary), an optional mention listbox, and the resolved footer 'Resolved by…' + Reopen. Footer note: 'Comments are saved in the PDF. Mentions travel wit… | filter 'open'\|'resolved'\|'all' (default open); expand = comment id 1–9 (default 1; expanded card gets an accent ring and shows its replies); compose=false; mention=false; filters=false; author 'all'\|'ay'\|'mk'\|'da'. | Right panel region in Comment mode: CommentsPanel (thread list, filters, composer). |
| `FmSigCard` | Signature validation card: a tinted status callout (20px icon + 14px w600 title + explanation), a 96px/1fr key/value grid (Signed by, Issued by, Certificate, Signed on, Revocation, Covers, Format; warning or danger values coloured) and 2 sm action buttons. | state 'valid'\|'warn'\|'invalid'\|'modified' (default valid). valid: badge-check success, 'Valid signature', actions Certificate… / Go to signature. warn: shield-alert warning, 'Valid, with 2 warnings' (signer’s clock, revocation not checked offline), actions Check again / Certificate…. invalid: shield-x danger, 'Invalid signature' (revoked certificate). modified: file-pen-line warning, 'Changed after signing', actions Show signed version / Compare. | Panel content in Fill & Sign: SignatureValidationCard (signature details panel, sidebar Signatures tab detail, validation dialog). |
| `FmStart` | The Start/Home screen inside FmWindow(home, no status bar). Four action cards (Open file… ⌘O, Create PDF ⌘N, Combine files, Scan to PDF; 36px accent-subtle icon tile, title, subtitle, Kbd). 'Quick tools' row of sm buttons (Compress, Convert, Sign, Recognize text (OCR), Protect, Compare). A dashed 64px 'Drop files anywhere in this window' strip. 'Pinned' (3 cards with an active pin IconButton). 'Recent' header with a search TextField, sort Select and grid/list SegmentedControl. Grid view = 5 columns of 150px previews with name, meta and badge; list view = table (Name, Location, Pages, Last opened, badge). Footer: 'Recent files are listed only on this device.' + 'Clear list' link. Empty state… | platform 'mac'\|'win'; lang 'en'\|'de'\|'ar'; view 'grid'\|'list' (default grid); empty=false; dragOver=false; tabs (passed to FmWindow; default 2 idle tabs); children (overlay slot). Undeclared: recentCount (truncates the 10-item recent list). Badges: edited (file-pen-line), form (accent, text-cursor-input), signed (success, badge-check), scanned (neutral, scan). | Home / Start screen (body of the app shell when no document tab is active). |
| `FmSettings` | Settings window: FmWindow(bare, no mode bar, no status bar) with a 240px nav (headline 'Settings', search TextField, 11 icon rows with the current row in accent on surface-selected) and a main column (surface-raised, max-width 760, padding 28 40, h1 = pane title). Panes: general (Theme segmented system/light/dark; 'PDF pages in dark theme' radios Paper white / Dimmed / Dark reading mode; default layout and zoom Selects; 'Reopen documents' Switch; default-app prompt). language (app language Select with 16 more…; document languages as Badges + Add; region formats, paper, units, first weekday; examples). editing (Mark edited text with a PageMark preview, missing-glyph policy radios, new-text f… | pane 'general'\|'language'\|'editing'\|'fonts'\|'signatures'\|'ocr'\|'ai'\|'privacy'\|'updates'\|'shortcuts'\|'advanced' (default general); platform 'mac'\|'win'; lang 'en'\|'de'\|'ar'. | Settings window/route (FmSettings with a NavigationRail-like list + 11 pane widgets). |
| `FmNumber` | Locale-aware number stepper: optional label, sm stepper box with tabular formatted value, optional unit suffix, stacked chevron arrows, optional error text and danger border. | value=10.5; precision=1; unit='pt'; label=''; lang 'en'\|'tr'\|'de'\|'ar'\|'ja' (en-US, tr-TR, de-DE, ar, ja-JP; grouping on); width=84; error=''. Undeclared: aria (accessible name; falls back to label, then 'Value'). | Form control used in every properties panel (replaces DS NumberStepper): FermanNumberField with Intl formatting through intl NumberFormat. |
| `FmBoard` | Documentation artboard: a header (mono number, 26px title, meta such as 'macOS · Light') above a fixed-size .fm-root frame carrying data-fm-artboard, data-theme, lang, dir and data-density, with platform-specific radius and shadow; optional note paragraph below. | bid (anchor id); num; title; meta (default '<platform name> · Light/Dark'); platform 'mac'\|'win'\|'web'\|'ios'\|'android'\|'ipad'\|'atab'; theme 'light'\|'dark'; kind 'window'\|'panel'\|'bare' (default bare for ios/android, else window); lang='en'; dir 'ltr'\|'rtl'; w (default 1440, ios 417, android 436); h (default 900, ios 876, android 939); note; noteW; children. Undeclared: density (defaults to 'touch' when kind=bare). | Not an app widget. Use it as the golden-test / Widgetbook wrapper: Theme (light/dark) + Locale + Directionality + density + fixed surface size. |
| `FmPhone` | Phone device frame (12px bezel, outer radius 66 iOS / 48 Android). Status bar (54px iOS with Dynamic Island, 36px Android; clock, wifi/wifi-off, battery). Top bar: iOS 44px nav bar (back chevron + label in accent or a lead text, centred title, right text/icon actions) with an optional large title (32/40 bold); Android 64px app bar (nav icon arrow-left/menu/x, 22px title, actions). Content slot. Bottom: iOS 83px tab bar or Android 80px navigation bar (accent-subtle indicator pill) with 4 tabs: Home (house), Files (folder), Scan (scan), Settings. Android FAB (56px, radius 12, accent). Overlay slot. Home indicator. | platform 'ios'\|'android'; title='Ferman'; large=true (iOS large title); back (back label); tab 'home'\|'files'\|'scan'\|'settings'\|'none'; bars 'full'\|'top'\|'status'\|'none'; lang 'en'\|'tr'\|'ar'\|'de' (tab labels, Eastern Arabic digits); fab (icon name, Android only); actions (string \| {text?, icon?, label?, bold?})[]; overlay; children. Undeclared: darkScreen, landscape, contentBg, barBg, clock, offline, lowBatt, lead, nav 'menu'\|'close'\|'none', flatTop, fabLabel (default 'New'). | Mobile app shell (MobileScaffold: CupertinoNavigationBar / M3 TopAppBar, bottom tab bar / NavigationBar, FAB). The bezel, status bar and home indicator are mock-only. |
| `FmKeyboard` | A static iOS/Android on-screen keyboard mock: optional 3-slot suggestion bar, 3 letter rows (Turkish QWERTY with ı ğ ü ş i ö ç; English; Arabic; numbers/symbols with ₺), shift/delete modifiers, bottom row (123/ABC, globe, space or 'Türkçe', return). | platform 'ios'\|'android'; layout 'tr'\|'en'\|'ar'\|'num' (default tr); dark=false; suggestions string[]. Undeclared: caps (uppercases with the Turkish locale), space (label), ret (label, default 'return'). | Mock only (the system keyboard). Not built in Flutter; at most a screenshot-test fixture showing keyboard insets. |
| `FmMHome` | Mobile Home tab content: search pill ('Search documents'), 4x2 grid of quick tools (Scan, Sign, Edit, Convert, Compress, Combine, Protect, OCR; 56x52 tiles with an accent icon), 'Pinned' 2-column cards, 'Recent' list (60px rows with a mini page, name, 'when · pages', Badge edited/form(accent)/signed(success), ellipsis), an empty state (file-text tile, 'No documents yet', primary lg 'Open a file' + 'Scan a document') and 'OPEN FROM' source chips (iOS: Files, iCloud Drive, Google Drive, OneDrive; Android: Downloads, Google Drive, OneDrive, Files). | lang 'en'\|'tr'\|'ar'; platform 'ios'\|'android'; empty=false. | Mobile Home tab body (inside FmPhone). |
| `FmMReader` | Mobile reader canvas: surface-canvas column of zoomed DocKira page 1 (with editing states) and page 2 (view), optional night inversion filter, plus children (sheets, toolbars). | zoom=0.46; night=false (invert(0.9) hue-rotate(180deg)); mode='view' (passed to DocKira); sel (DocKira block id); edited=false; search=false; annot=false; children. Undeclared: padTop (default 12), selState ('selected'\|'editing'), glyph. metaPlace is fixed to 'below'. | Mobile reader/canvas body (MobileReader with a PDF page viewer; the Doc pages stand in for rendered pages). |
| `DocKira` | An A4 page (794x1123, padding 88 96 96, Plex Serif 14/1.5, page shadow and page-filter, lang tr) of a 3-page Turkish residential lease 'KONUT KİRA SÖZLEŞMESİ'. Page 1: title, contract meta, Madde 1–6, every block wrapped in a TextEditBox (states driven by mode/sel/hover), with optional search marks, redaction marks on the T.C. numbers and IBAN, an edited amount (18.500 → 19.500 TL as PageMark edited + margin bar, or plain), caret, Highlight (yellow 'her ayın beşinci gününe kadar', green underline IBAN), a collapsed StickyNote pin, and a missing-glyph sentence in EB Garamond ('değiştirilemez'). Page 2: Madde 7–10 plain, with emails/phones redactable. Page 3: signatures, with PdfFormFields fo… | page 1\|2\|3; mode 'view'\|'edit'\|'comment'\|'sign'\|'protect' (TextEditBox states only in edit; sets data-fm-mode); sel ''\|'title'\|'p1'\|'p4'\|'iban'\|'p4b'\|'p6' (the logic also accepts meta, h1–h6, p2, p3, p5); selState 'selected'\|'editing' (editing on p4 shows a caret); metaPlace 'above'\|'below'\|'margin'; metaText='IBM Plex Serif · 10.5 pt'; edited=false; marks=true (edited underline + bar only in edit mode); hover (true = all blocks, or a string[] of block ids); glyph=false; annot=fa… | Sample-document test fixture (primary). Becomes a fixture PDF plus a block map for goldens of the on-page edit overlay layer (TextEditBox, PageMark, Highlight, StickyNote, PdfFormField). Used in 19 files (91 instances). |
| `DocForm` | An A4 Turkish government form 'YERLEŞİM YERİ ADRESİ BEYAN FORMU' (T.C., AKS-1, application no. in mono). 3 sections, 20 PdfFormFields: text, date (GG.AA.YYYY), dropdown (Seçiniz), radio group (Kadın/Erkek), checkboxes and signature. Options: tab-order number badges (accent when focused, ink-700 when required, paper-600 otherwise), author mode (field name chips in mono + dashed outlines, the selected one in accent), a date-picker popover (November 2026), an error field, a footer verification code and 1 / 1. | filled 'none'\|'partial'\|'more'\|'all' (data-props default is 'partial', but the logic falls back to 'none' when the prop is omitted); focus = field id (default 'ad'); order=false; author=false; selected = field id (author mode); errorField = field id; datePicker=false; signed=false (imza counts as filled when filled=all); zoom=1; children. Undeclared: extra ({id: value} overrides), errorValue (default '0'), errorText (default 'Enter a number from 1 to 20.'), pickerTop (default 548). | Sample-document test fixture for Fill & Sign: an AcroForm PDF with these field names (tc_kimlik_no, dogum_tarihi, adi, soyadi, cinsiyet, medeni_hal, telefon, eposta, il, ilce, mahalle, cadde_sokak, dis_kapi_no, ic_kapi_no, tasinma_tarihi, hane_kisi_sayisi, beyan_dogruluk, beyan_kurum, beyan_tarihi,… |
| `DocEkstre` | An A4 bank statement (Boğaziçi Bankası, HESAP EKSTRESİ 01.09–30.09.2026): customer box (T.C., IBAN and phone are redactable), an 8-row transaction table (Tarih, Açıklama, Tutar, Bakiye; credits in green #1E7A46), totals, footer 1 / 2. | redact 'none'\|'pending'\|'applied'; zoom=1; highlightRent=false (yellow row highlight on the 'Kira ödemesi' line). | Sample-document test fixture for View / Protect (redaction mark → confirm → applied) and mobile redact. |
| `DocCv` | An A4 CV (Zeynep Arslan, Kıdemli Muhasebe Uzmanı): a photo placeholder (user icon) plus DENEYİM, EĞİTİM and DİLLER sections. Accessibility overlays: reading-order number badges (accent, one amber) and issue markers (image = missing alt, contrast, list). | order=false (reading-order badges); issues=false (issue markers); imgSel=false (2px accent outline on the photo). No zoom prop. Uses the undefined token --amber-600 (falls back to #B26E00). | Sample-document test fixture for Tools › Accessibility (tags, reading order, alt text) and mobile core screens. |
| `DocPlan` | An A4 architectural floor plan drawn with absolute boxes (SALON 35,1 m², YATAK ODASI 25,9 m², MUTFAK, ANTRE, BANYO; dimension lines 12,00 / 10,80; title block 'Kat planı — Daire 5 (2+1)', scale 1:75). Optional measurement overlay: an area polygon (blue ink, 'Alan 25,65 m² · Çevre 20,3 m'), a distance line (red, '6,88 m') and a 'Scale 1:75 · calibrated' chip. Optional calibration line ('158,7 mm on paper') with a focus-ringed end handle. | measure=false; calib=false; zoom=1. | Sample-document test fixture for Comment › Measure and Tools › Measure calibration. |

## 7. Icons

### Icon decision

These points come from [ADR 0013](adr/0013-fonts-and-icons.md).

- The app ships the design's exact path data, not a fresh Lucide download: the 145 `ICON_PATHS`
  glyphs in `_ds_bundle.js` plus the 84 in `ds-additions/fm-icons.js`, 229 in all. `tools/icons`
  writes them as SVG assets in `app/assets/icons/` (the exported, provenance-tracked set) and as
  generated path data, which the Icon widget paints with a `CustomPainter` through path_parsing at the
  DS stroke width of 1.5 (not Lucide's default of 2; 2 only for 12 px glyphs and badges), with round
  caps and joins and the colour taken from the theme. The SVGs are not loaded at run time: flutter_svg
  and vector_graphics depend on `http`, which the network deny list forbids. There is no icon font and
  no sprite sheet, as the DS asks ([G04](DESIGN_GAPS.md#g04)).
- All 229 ship, including the 58 that nothing in the design references yet.
- The licence notices ship with them: Lucide's ISC licence, and Feather's MIT licence for the
  roughly 57 glyphs derived from Feather. Both appear in the third-party notices ([G08](DESIGN_GAPS.md#g08), [G14](DESIGN_GAPS.md#g14)).
- A provenance table names, for each glyph, the Lucide release its geometry matches. 222 match
  0.460.0; `bell`, `grid-2x2` and `funnel` match 1.56.0; `paperclip` matches 0.469.0 and 0.500.0;
  `expand` matches 0.500.0; `file-signature` matches 0.263.0 and 0.300.0. Only `ellipse` matches no
  Lucide release; it is recorded as Ferman design and stays pending until the re-export settles it
  ([G60](DESIGN_GAPS.md#g60), [ADR 0013](adr/0013-fonts-and-icons.md)).
- Directional icons carry a per-icon flag and mirror under right-to-left. The flag is set on exactly
  the 8 icons the design flips: `arrow-left`, `arrow-right`, `chevron-left`, `chevron-right`,
  `undo-2`, `redo-2`, `skip-back` and `skip-forward` (checked by a `tools/icons` test against the
  design files). `send`, `reply`, the list icons, `text-cursor`, `arrow-left-right`, `volume-2` and
  `chevrons-left`/`chevrons-right` are not marked. The PDF canvas never mirrors (brief §6).
- Where the generated notes below suggest taking glyphs from a Lucide release or replacing
  `file-signature` and `ellipse`, this decision applies instead: the design's own paths ship as drawn.

The generated notes below compared the added icons only with Lucide 0.460.0 and 1.56.0. The M0
review later found `paperclip`, `expand` and `file-signature` in other Lucide releases, as the
provenance bullet above says.

### Icon reference (generated)

229 distinct icon names, none duplicated. The first 145 in the list come from ICON_PATHS in /home/user/Ferman/design/_ds/ferman-design-system-27832349-21bc-410e-acd5-6ab20d2f87e2/_ds_bundle.js (components/core/Icon.jsx). I diffed all 145 against lucide-static 0.460.0 and every one matches exactly. The last 84 (starting at "paperclip") come from /home/user/Ferman/design/ds-additions/fm-icons.js, which merges them into ICON_PATHS. Index.dc.html line 129 says "Icon set (+64)", which is out of date: the file has 84. Where the 84 additions come from: 77 match lucide-static 0.460.0 exactly. bell, grid-2x2 and funnel match lucide-static 1.56.0, and funnel does not exist in 0.460.0. expand and paperclip match neither 0.460.0 nor 1.56.0. file-signature does not exist in 0.460.0 and uses an old drawing; in 1.56.0 it is only an alias of file-pen-line with different geometry. ellipse does not exist in 0.460.0 and is not Lucide's shape (it uses ry=7; Lucide 1.56.0 uses ry=6), so it was drawn by hand. Usage, counting icon names passed through data arrays and component helpers as well as attributes: the artboards, the Fm* building blocks and the DS components reference 168 of the 229 names (for example, SearchReplaceBar draws case-sensitive, whole-word and regex through its option helper, and FmSigCard uses shield-alert and shield-x for its warn and invalid states). The unexported desktop kit in _ds_bundle.js adds bookmark, smartphone and sun, so 171 are referenced somewhere and 58 are not. The 18 unreferenced names from ICON_PATHS are ban, circle-help, corner-down-left, ellipsis-vertical, file-lock-2, indent-increase, list-ordered, move, panel-left-close, pen, pencil, pilcrow, pointer, scissors, share, spell-check, table-of-contents and text-select. The 40 unreferenced names from fm-icons.js are archive, arrow-down-to-line, arrow-up, at-sign, bell, braces, check-check, chevrons-left, chevrons-right, circle-plus, cloud-download, credit-card, expand, file-signature, folder-plus, gauge, git-commit-vertical, graduation-cap, grid-2x2, id-card, image-plus, landmark, maximize-2, mic, package, percent, phone, plug, receipt, scan-line, server, sigma, sliders-horizontal, square-x, star, table, tablet, tag, triangle and users. About 57 of the 229 come from Feather, so the Feather MIT notice also applies to them. Examples: x, plus, check, chevrons, arrows, search, lock, circle-alert/triangle-alert, trash-2, type, zoom-in/out, server, smartphone, tablet, triangle, percent, at-sign, code.

All icon names (alphabetical):

`accessibility`, `align-center`, `align-justify`, `align-left`, `align-right`, `archive`, `arrow-big-up`, `arrow-down`, `arrow-down-to-line`, `arrow-down-wide-narrow`, `arrow-left`, `arrow-left-right`, `arrow-right`, `arrow-up`, `arrow-up-down`, `arrow-up-right`, `at-sign`, `badge-check`, `ban`, `baseline`, `bell`, `bold`, `book-open`, `bookmark`, `braces`, `calendar`, `camera`, `case-sensitive`, `check`, `check-check`, `chevron-down`, `chevron-left`, `chevron-right`, `chevron-up`, `chevrons-left`, `chevrons-right`, `circle`, `circle-alert`, `circle-check`, `circle-dot`, `circle-help`, `circle-plus`, `circle-x`, `clock`, `cloud`, `cloud-download`, `code`, `columns-2`, `command`, `contrast`, `copy`, `corner-down-left`, `cpu`, `credit-card`, `crop`, `delete`, `download`, `droplet`, `ellipse`, `ellipsis`, `ellipsis-vertical`, `eraser`, `expand`, `external-link`, `eye`, `eye-off`, `file-check-2`, `file-image`, `file-input`, `file-lock-2`, `file-output`, `file-pen-line`, `file-plus-2`, `file-search`, `file-signature`, `file-spreadsheet`, `file-text`, `file-type`, `file-x`, `files`, `folder`, `folder-open`, `folder-plus`, `funnel`, `gauge`, `git-commit-vertical`, `git-compare`, `globe`, `graduation-cap`, `grid-2x2`, `grip-vertical`, `hand`, `hard-drive`, `hash`, `heart`, `highlighter`, `history`, `house`, `id-card`, `image`, `image-plus`, `indent-increase`, `info`, `italic`, `key-round`, `keyboard`, `landmark`, `languages`, `layers`, `layout-grid`, `link`, `list`, `list-checks`, `list-filter`, `list-ordered`, `list-tree`, `loader-circle`, `lock`, `lock-open`, `mail`, `maximize`, `maximize-2`, `menu`, `merge`, `message-square`, `mic`, `minimize-2`, `minus`, `monitor`, `moon`, `mouse-pointer-2`, `move`, `nfc`, `package`, `palette`, `panel-left`, `panel-left-close`, `panel-right`, `paperclip`, `pause`, `pen`, `pen-line`, `pen-tool`, `pencil`, `pentagon`, `percent`, `phone`, `pilcrow`, `pin`, `pipette`, `play`, `plug`, `plus`, `pointer`, `presentation`, `printer`, `receipt`, `redo-2`, `refresh-cw`, `regex`, `replace`, `reply`, `rotate-ccw`, `rotate-cw`, `rows-2`, `ruler`, `save`, `scan`, `scan-line`, `scan-text`, `scissors`, `search`, `send`, `server`, `settings`, `shapes`, `share`, `share-2`, `shield`, `shield-alert`, `shield-check`, `shield-x`, `sigma`, `signature`, `skip-back`, `skip-forward`, `slash`, `sliders-horizontal`, `smartphone`, `sparkles`, `spell-check`, `split`, `square`, `square-check`, `square-dashed`, `square-pen`, `square-x`, `stamp`, `star`, `sticky-note`, `strikethrough`, `sun`, `table`, `table-of-contents`, `tablet`, `tag`, `text-cursor`, `text-cursor-input`, `text-select`, `trash-2`, `triangle`, `triangle-alert`, `type`, `underline`, `undo-2`, `upload`, `usb`, `user`, `users`, `volume-2`, `whole-word`, `wifi`, `wifi-off`, `workflow`, `wrench`, `x`, `zap`, `zoom-in`, `zoom-out`

**Mirrored in RTL**

- How flipping works: the Icon prop flipRtl (default false) adds a data-flip-rtl attribute, and tokens/base.css:22 has [dir="rtl"] [data-flip-rtl]{transform:scaleX(-1)}. Artboards instead wrap icons in <span data-fm-flip>, which ds-additions/fm-additions.css:67 handles with [dir="rtl"] [data-fm-flip] svg{transform:scaleX(-1)}. SegmentedControl options (o.flipRtl) and Menu items (it.flipRtl) pass the flag through, but no artboard sets it on them.
- chevron-right: hard-coded flipRtl:true for the Menu submenu arrow (_ds_bundle.js ~line 2679); flip-rtl={{true}} in '05b Sign' line 59; data-fm-flip in '13b Mobile tasks' line 187 and FmWindow line 102 (Next field)
- chevron-left: data-fm-flip in '02 View' line 138 (Previous page), '12 Localization' lines 106 and 114 (mobile back), FmPhone line 25 (iOS back) and FmWindow line 102 (Previous field)
- arrow-right: flip-rtl={{true}} in '01 First run and files' line 45 and '03c Edit review and translate' line 103
- skip-back: data-fm-flip in '02 View' line 153 (read-aloud toolbar)
- skip-forward: data-fm-flip in '02 View' line 153 (read-aloud toolbar)
- undo-2: data-fm-flip in FmWindow line 77 (title-bar toolbar)
- redo-2: data-fm-flip in FmWindow line 77 (title-bar toolbar)
- arrow-left (also menu and x): FmPhone line 29 wraps the Android navIcon in data-fm-flip. navIcon is arrow-left, menu or x; only arrow-left needs it, the other two are symmetric.
- Directional icons that sometimes appear with no flip: arrow-right (4 instances), arrow-left (1), chevron-left (2), chevron-right (2), undo-2/redo-2 in the '13a/13b Mobile' data lists, send (4), reply, list/list-tree/list-checks, text-cursor(-input), arrow-left-right and volume-2. Each needs an RTL decision in Flutter (Directionality-aware icons).

**Source and licence.** The set is Lucide (https://lucide.dev), lucide-static v0.460.0. _ds_bundle.js line 72 says "Lucide icon set (ISC license, lucide-static v0.460.0), copied programmatically", and readme.md lines 14 and 146 agree. My diff confirms it: all 145 ICON_PATHS entries match 0.460.0 exactly. The licence is ISC, plus the MIT licence (Cole Bemis, Feather) for icons that came from Feather. The readme says the SVG originals are in assets/icons/*.svg, but the export has no assets/icons folder; assets/ contains only fonts/. To get the originals for app/assets, use the npm tarball https://registry.npmjs.org/lucide-static/-/lucide-static-0.460.0.tgz. It holds 1539 SVGs at package/icons/<name>.svg plus package/LICENSE; npm lists its licence as "ISC". The same files are under git tag 0.460.0 at raw.githubusercontent.com/lucide-icons/lucide/0.460.0/. The newest version is lucide-static 1.56.0 (ISC), but 57 of the 145 base icons have different geometry there, so pin 0.460.0. Seven fm-icons.js names have no matching 0.460.0 SVG: funnel, bell and grid-2x2 (take them from 1.56.0, or use 0.460.0 'filter' for funnel), expand and paperclip (their paths match neither version), file-signature (old drawing; use file-pen-line or signature instead) and ellipse (custom shape, needs design sign-off). Rendering: the Icon component draws at strokeWidth 1.5 with a default size of 16, while the Lucide SVG files use stroke-width 2. The Flutter renderer or export step has to override the stroke to 1.5. You also need to ship the Lucide ISC and Feather MIT notices; the export has neither text, only code comments.

## 8. Fonts

### Fonts in the export

The DS uses IBM Plex (brief §2). The export holds 23 WOFF2 files in `_ds/ferman-design-system-27832349-21bc-410e-acd5-6ab20d2f87e2/assets/fonts/`, declared by
33 `@font-face` rules in `tokens/fonts.css`. More families load from Google Fonts through
`fm-additions.css`.

| Family | Files in the export | Weights and styles | Scripts | Used for |
|---|---|---|---|---|
| IBM Plex Sans | 5 unicode-range subsets (latin, latin-ext, cyrillic, cyrillic-ext, greek), all named `-400-normal` | 15 rules for 400, 500 and 600 point at the same 5 files, which are variable fonts (weight axis 100 to 700, revision 3.201). No italic. | Latin, Latin Extended, Cyrillic, Cyrillic Extended, Greek. No Vietnamese (U+1EA0 to U+1EF1). | The UI (first in `--font-ui`). |
| IBM Plex Sans Arabic | 3 files: 400, 500, 600 | Static, revision 1.101. No italic. | Arabic, including the Persian letters and digits. No Latin. ZWNJ and ZWJ are not in the character map. | The UI (second in `--font-ui`) and `--font-arabic`. |
| IBM Plex Serif | 9 files: latin, latin-ext and cyrillic at 400, 400 italic and 600 | Static, revision 2.006. No 500, no 600 italic. | Latin, Latin Extended, Cyrillic. | The wordmark (`--font-brand`, 600) and stand-in page text in mocks. |
| IBM Plex Mono | 6 files: latin, latin-ext and cyrillic at 400 and 500 | Static, revision 2.003. No italic, no 600. | Latin, Latin Extended, Cyrillic. | Shortcuts and raw values (`--font-mono`). |
| Loaded from Google Fonts, not in the export | None | IBM Plex Sans JP, KR, Hebrew and Devanagari; Noto Sans SC; Noto Serif JP; Noto Naskh Arabic; EB Garamond; Cormorant Garamond; Crimson Pro; Caveat; Homemade Apple; Dancing Script | Hebrew, Devanagari, Japanese, Korean, Simplified Chinese, Arabic Naskh for page text, Latin display and handwriting. No Traditional Chinese. | The extended `--font-ui`, `--font-doc-cjk`, `--font-hand-1` to `-3` (signature mocks) and mock page text. |

### Issues

- Flutter cannot use any of the 23 files: they are WOFF2, and Flutter font assets must be TTF or OTF
  ([G06](DESIGN_GAPS.md#g06)).
- Plex Sans is a variable font cut into unicode-range subsets. The 500 and 600 rules work only
  because of the weight axis. Flutter has no unicode-range, so the subsets cannot stand in for the
  complete files.
- Vietnamese is missing, although `a1-1` lists "Tiếng Việt".
- Six of the 21 UI languages (he, hi, ja, ko, zh-Hans, zh-Hant) have no local font. They, and the
  handwriting fonts, load from Google Fonts at runtime, which a local-first app cannot depend on.
  Traditional Chinese has no font at all and would fall back to Simplified forms ([G07](DESIGN_GAPS.md#g07)).
- Missing styles: no Plex Sans italic (the FontPicker missing state uses italic UI text, which would be
  synthesised), no Plex Serif 500 or 600 italic, no Plex Mono italic or 600.
- Plex Sans Arabic has no Latin glyphs, and IBM's Arabic TTF lacks ğ, ş and İ, so Latin and Turkish
  text inside Arabic or Persian UI needs Plex Sans as a fallback. ZWNJ and ZWJ are not mapped; Persian
  text with ZWNJ needs a test.
- No licence files ship with the fonts: no OFL-1.1 text, and no Apache-2.0 text for Homemade Apple
  ([G08](DESIGN_GAPS.md#g08)).
- "Plex" is a Reserved Font Name. A modified version, such as a subset or a format conversion, may
  not use the name. The export's files are Google subsets that keep it. Shipping IBM's unmodified
  files avoids the problem.
- The versions differ: the export has Plex Sans 3.201 (variable), Serif 2.006, Mono 2.003 and Sans
  Arabic 1.101; IBM's release TTFs report 3.005, 3.006, 2.005 and 1.005. Metrics and line heights
  need a visual check after the switch.

### Script coverage per language

"In the export" is what the export's own font files cover. "Decision" is what the app does.

| Language | Script | In the export | Decision |
|---|---|---|---|
| English (`en`) | Latin | Yes: Plex Sans, Serif and Mono latin subsets | IBM Plex Sans (bundled). |
| Turkish (`tr`) | Latin + Latin Extended-A (ğ ş İ ı) | Yes: ı (U+0131) is in the latin subset; ğ, ş and İ are in latin-ext (all 6 tested letters present) | IBM Plex Sans (bundled). It comes first in every UI chain: Plex Sans Arabic, Hebrew and Devanagari carry only one of İ ı Ğ ğ Ş ş ([G64](DESIGN_GAPS.md#g64)). |
| German (`de`) | Latin (ß, ẞ U+1E9E in latin-ext) | Yes | IBM Plex Sans (bundled). |
| French (`fr`) | Latin (œ « » ’) | Yes | IBM Plex Sans (bundled). |
| Spanish (`es`) | Latin (ñ ¿ ¡) | Yes | IBM Plex Sans (bundled). |
| Portuguese (Brazil) (`pt-BR`) | Latin (ã õ ç) | Yes | IBM Plex Sans (bundled). |
| Italian (`it`) | Latin | Yes | IBM Plex Sans (bundled). |
| Dutch (`nl`) | Latin (ĳ U+0133 in latin-ext) | Yes | IBM Plex Sans (bundled). |
| Polish (`pl`) | Latin Extended-A (ą ć ę ł ń ś ź ż) | Yes: all 16 tested letters in latin-ext for Sans, Serif and Mono | IBM Plex Sans (bundled). |
| Russian (`ru`) | Cyrillic | Yes: 66 of 66 tested letters in the cyrillic subsets of Sans, Serif and Mono | IBM Plex Sans (bundled); the complete file covers Cyrillic. |
| Ukrainian (`uk`) | Cyrillic (є і ї ґ) | Yes: є, і, ї and ґ are present; only U+02BC (modifier-letter apostrophe) is missing, and U+2019 is in the latin subset | IBM Plex Sans (bundled). Use U+2019 for the apostrophe. |
| Arabic (`ar`) | Arabic | Yes: IBM Plex Sans Arabic 400/500/600 (49 of 49 tested letters and Arabic-Indic digits). It also carries ASCII and Latin-1, but the UI draws Latin from IBM Plex Sans, which comes first (ARCHITECTURE §11.5). | IBM Plex Sans Arabic 400, 500, 600 (bundled), after IBM Plex Sans (the `--font-ui` order, [G64](DESIGN_GAPS.md#g64)). |
| Persian (`fa`) | Arabic script (Persian: پ چ ژ گ ک ی, Persian digits ۰-۹ U+06F0-06F9, ZWNJ) | Mostly: the Arabic file has پ چ ژ گ ک ی and U+06F0-06F9. ZWNJ isn't in the cmap (the shaper treats it as invisible). The Serif and Mono files have no Arabic. | IBM Plex Sans Arabic (bundled), after IBM Plex Sans (the `--font-ui` order). Persian digits come from the region setting (Iran), not the UI language ([G34](DESIGN_GAPS.md#g34)). Test text with ZWNJ in goldens. |
| Hebrew (`he`) | Hebrew | No: not in the export (only loaded from the Google CDN by fm-additions.css) | IBM Plex Sans Hebrew (bundled, [Q08](QUESTIONS.md#q08)), after IBM Plex Sans (the `--font-ui` order). |
| Hindi (`hi`) | Devanagari | No: not in the export (only loaded from the Google CDN) | IBM Plex Sans Devanagari (bundled, [Q08](QUESTIONS.md#q08)), after IBM Plex Sans (the `--font-ui` order: with Plex Sans Devanagari first, İ, ş and ế get misplaced marks). |
| Japanese (`ja`) | Japanese (Kanji + Kana) | No: only loaded from the Google CDN (IBM Plex Sans JP, Noto Serif JP) | System fonts (Hiragino Sans; Yu Gothic UI or Meiryo UI; Noto Sans CJK JP). Pass the ja locale so Han characters take Japanese forms. No synthetic bold or italic. |
| Korean (`ko`) | Hangul (+ Hanja) | No: only loaded from the Google CDN (IBM Plex Sans KR) | System fonts (Apple SD Gothic Neo, Malgun Gothic, Noto Sans CJK KR). |
| Chinese (Simplified) (`zh-Hans`) | Simplified Chinese (Han) | No: Noto Sans SC loads from the Google CDN only | System fonts (PingFang SC, Microsoft YaHei UI, Noto Sans CJK SC). |
| Chinese (Traditional) (`zh-Hant`) | Traditional Chinese (Han) | No, and the design stack has no Traditional Chinese font at all, so it would render with Noto Sans SC glyph forms | System fonts (PingFang TC or HK, Microsoft JhengHei UI, Noto Sans CJK TC). Always pass the zh-Hant locale. |
| Indonesian (`id`) | Latin (basic) | Yes | IBM Plex Sans (bundled). |
| Vietnamese (`vi`) | Latin + Vietnamese (Ă Đ Ơ Ư and stacked diacritics U+1EA0-1EF9, ₫) | No: latin-ext has the base letters (Ă, Đ, Ơ, Ư) but none of the precomposed U+1EA0-1EF1 letters (only 22 of 104 test code points). Google's 'vietnamese' subset was not exported. Serif and Mono have the same gap. | IBM Plex Sans (bundled). IBM's complete TTF covers all 104 tested code points, ₫ included. |

### Font decision

These points come from [ADR 0013](adr/0013-fonts-and-icons.md). The Hebrew and Devanagari fonts were
approved by the owner on 2026-10-15.

- The app bundles IBM's unmodified static TTFs from the official IBM Plex releases, each with IBM's
  OFL-1.1 licence file. They are never subset, converted or renamed, so the Reserved Font Name "Plex"
  is respected.
  - IBM Plex Sans 400, 500 and 600, plus Italic 400 for the FontPicker missing state. The complete
    files cover Latin, Turkish, Vietnamese, Cyrillic and Greek.
  - IBM Plex Serif 400, Italic 400 and 600, for the wordmark and the specimens.
  - IBM Plex Mono 400 and 500, for shortcuts and raw values.
  - IBM Plex Sans Arabic 400, 500 and 600, which also covers Persian.
  - IBM Plex Sans Hebrew and IBM Plex Sans Devanagari, 400, 500 and 600 ([Q08](QUESTIONS.md#q08)).
- Japanese, Korean, Simplified Chinese and Traditional Chinese use system fonts. The app passes the
  locale so Han characters take the right regional forms, and never asks for italic. Flutter cannot
  switch synthetic bold off, so the theme names system families with real bold faces
  ([G65](DESIGN_GAPS.md#g65)).
- The design's WOFF2 subsets are not used. The app never loads fonts from the network; the Google
  Fonts `@import` in `fm-additions.css` is a detail of the design tool ([G07](DESIGN_GAPS.md#g07)).
- IBM Plex Sans comes first in every UI chain (the design's `--font-ui` order), so Latin, Turkish and
  Vietnamese text renders correctly inside Arabic, Persian, Hebrew and Hindi UI
  ([G64](DESIGN_GAPS.md#g64)).
- The signature handwriting fonts (`--font-hand-1` to `-3`: Caveat, Homemade Apple, Dancing Script)
  ship for typed signatures in M4, and Cormorant Garamond and Crimson Pro ship as similar fonts for
  missing glyphs in M3 ([Q08](QUESTIONS.md#q08) groups 3 and 4, answered on 2026-10-16). Each ships
  unmodified with its licence: Homemade Apple is Apache-2.0, the others OFL-1.1.
- Golden tests load the real fonts (brief §5).

## 9. Fixes, flows and sample documents

**Fixes.** The six fixes in `00 Fixes` were applied to the design system before any other board was
drawn, so every board already shows them. Each one is a binding rule for the Flutter port. The table
gives one rule per fix board. Fixes 4 and 6 are listed under their boards `f4a`, `f4b` and `f6a`;
their section boards `f4` and `f6` are in section 5.

**Flows.** The four flows join boards into journeys. Each flow has one milestone, set by its latest
required step.

**Sample documents.** The `Doc*` files and the documents named on the boards are drawn pages, not
PDFs. Each one implies a PDF for the test corpus in `tests/corpus/`, generated or freely licensed,
with provenance in `tests/corpus/README.md` (brief §5). All names, IBANs and ID numbers in them are
fictitious. One data issue remains: flow B's e-imza steps are drawn on the rental contract ([G58](DESIGN_GAPS.md#g58)).
Start listed the e-Devlet form as 2 pages while the fixture has 1 ([G59](DESIGN_GAPS.md#g59)); since export 519d42a
`FmStart` lists it as 1 page on every Start board.

| Fix | Binding rule |
|---|---|
| `f1` Fix 1 — The text-frame label never covers content | The font · size tab of a selected text frame attaches outside the frame and takes the first free side: (1) above, when the 20 px above are empty (18 px label + 2 px gap), starting at the frame's start edge (the right edge in RTL); (2) below, when text, an image, a mark or the page edge is directly above, with the tab shape flipped so its flat edge touches the frame; (3) margin, beside the first line outside the text column, allowed to extend past the page edge. It never overlaps text, handles or other marks, and placement is recalculated while the frame is dragged or resized. Implementation: TextEditBox data-meta-placement = above\|below\|margin; token --editbox-meta-h: 18px. Milestone: M3 (click-to-edit). |
| `f2` Fix 2 — The missing-glyph warning appears once | A missing glyph is never silent and is never said twice. The font field shows only an amber border and a 14 px triangle before the name. Its tooltip reads 'Missing ‘ğ’. Details below.' and screen readers hear 'Font, <name>, warning: missing character'. The sentence appears only in the warning callout ('Missing character'), which names the exact character and what Ferman does ('will use a similar font for this character') and offers 'Choose a font…' (opens the 3.3 substitution picker) or 'Keep as is'. On the page the glyph gets an amber wavy underline and the frame tab turns amber. FontPicker gets the new state [data-fm-glyph-warning]; its `warning` prop is reserved for fonts that are not installed. Milestone: M3 (missing-glyph handling). |
| `f3` Fix 3 — Edited text and highlights look different | Ferman's edit marking is a line, never a fill and never yellow: a dotted 1.5 px underline plus a 2 px bar 12 px outside the text column in the left margin, both in --edit-mark (ink 600, 7:1 on white). It appears only on the lines that changed, only while 'Mark edited text' is on, and is never saved into the PDF or printed. Highlights are translucent marker fills (--annot-yellow/green/blue/pink/orange) multiplied onto the text, saved in the PDF, listed in Comments and printed by default. When both apply, the fill sits under the dotted line. Milestone: M3 (edit marks and review), with highlights in M4. |
| `f4a` Fix 4 — Save state is always honest: main editor, unsaved changes | With unsaved edits: Save is primary and enabled (⌘S / Ctrl+S); the tab's dot replaces the close button (screen readers hear '<file>, unsaved changes'); the status bar says 'Unsaved changes' with an amber dot, as a polite live region. Defined save states: Unsaved → Saving… (button spinner) → Saved → Couldn't save (danger text plus a persistent danger toast with a 'Save as…' action, e.g. disk full). Milestone: M3 (save/save as). |
| `f4b` Fix 4 — Save state is always honest: main editor, saved | After saving: Save is disabled with the tooltip 'No changes to save', the tab dot goes away, and the status bar shows a hard-drive icon with 'Saved on this device · HH:MM'. Edit marks stay until the document is closed so the session's changes can still be reviewed. The status bar must never claim saved while changes are pending. Milestone: M3. |
| `f5` Fix 5 — Thumbnail badges have a legend | Page thumbnails carry up to five defined badges, stacked at the top-end corner in a fixed order: edited, comments, form fields, signature, warnings. Badges are 16 px chips with 10 px icons at 2 px stroke (Edited is an 8 px accent dot, --edit-changed ink 600). Comments, forms and signature are neutral chips on white; warnings is the only coloured chip (amber triangle on amber tint). Chip colours don't change with theme because they sit on the white page preview. The page-text lines in the thumbnail are inset 24% at inline-end so badges never cover the preview. Every badge has a tooltip (e.g. '1 warning · Madde 6 uses a font without ‘ğ’'), can be focused with the arrow keys inside the thumbnail, and announces its tooltip. An info button in the Pages header opens the legend. Milestone: M2 for thumbnails and legend; each badge type ships with its feature (edited and warnings M3, comments, f… |
| `f6a` Fix 6 — Windows window chrome: main editor | Windows uses the same layout and components; only the platform layer changes. Caption buttons (minimize, maximize, close) sit flush top-right, 46 px wide (--win-caption-w), and close turns red on hover (--win-close-hover). There are no traffic lights and window corners are 8 px. Shortcuts use Ctrl/Alt/Shift (Ctrl+K, Ctrl+Z, Ctrl+Y, Ctrl+H in tooltips and menus). Dialog buttons follow Windows order: primary, then secondary, then Cancel. Snap layouts appear on hover over maximize, and the title-bar area between the tabs and search drags the window. Milestone: M1 (app shell / title bar). |

**Flow A — Open a PDF and fix a typo (Desktop · about 20 seconds)** — milestone: M3 (Edit existing text). Opening, password and Start are M2 or earlier; click-to-edit, missing glyph, overflow, Review edits and Save are M3. The 'page is a scan' branch needs OCR and only completes in P3.

- 1. Open the file (double-click in Finder, drop on window, or ⌘O from Start) -> 01 First run and files.dc.html#a1-4
- 2. Point at the text (Edit mode, paragraph under pointer shows its frame) -> 03a Edit text.dc.html#a3-1a
- 3. Click twice and type (first click selects block, second places caret; text reflows in frame) -> 03a Edit text.dc.html#a3-1b
- 4. Check what changed (dotted underline + margin bar; Review edits lists it) -> 03c Edit review and translate.dc.html#a3-12
- 5. Save (Unsaved changes -> Saved on this device · 14:32) [end] -> 00 Fixes.dc.html#f4b
- branch (warn). The font has no ‘ğ’: similar font, said once, offer to choose -> 03a Edit text.dc.html#a3-3a
- branch (warn). Text no longer fits: extend block / tighten spacing / keep and warn -> 03a Edit text.dc.html#a3-4
- branch (info). Page is a scan: offer text recognition first -> 03c Edit review and translate.dc.html#a3-11
- branch (err). Password-protected: unlock dialog, Turkish keyboard pitfalls -> 01 First run and files.dc.html#a1-8b

**Flow B — Fill and e-sign a form (Desktop · e-Devlet form with e-imza)** — milestone: P3. Form filling is M4, but e-imza (PKCS#11 smart card), timestamping, signature validation and the 'changed after signing' compare are all P3. Note: steps 3-6 are drawn on Kira sözleşmesi, not the e-Devlet form.

- 1. Fields are found (form banner; 20 fields, 15 required, tab order shown) -> 05a Fill.dc.html#a5-1
- 2. Tab through fields ('Field 3 of 20', required count drops, date picker) -> 05a Fill.dc.html#a5-2
- 3. Choose e-imza (card reader found, field to sign outlined) -> 05b Sign.dc.html#a5-6
- 4. Enter the PIN (masked, sent only to the card, tries left shown) -> 05b Sign.dc.html#a5-6b
- 5. Signing (certificate check, card signs, timestamp, signed copy saved) -> 05b Sign.dc.html#a5-6c
- 6. Signed and valid (green bar, plain-words signature panel) [end] -> 05b Sign.dc.html#a5-5c
- branch (err). A number is out of range: field explains, Finish unavailable until fixed -> 05a Fill.dc.html#a5-2
- branch (err). No card found: checklist, continues when card appears -> 05b Sign.dc.html#a5-6e
- branch (warn). Document changes later: 'Changed after signing' with compare -> 05b Sign.dc.html#a5-7

**Flow C — Redact and send (Desktop · bank statement)** — milestone: P2. Redaction with verification and removing hidden information are P2. Toasts (M4) and disk-full handling (M3) are already in place by then.

- 1. Find and redact (patterns find T.C. Kimlik No, IBAN, phone, e-mail) -> 08 Protect.dc.html#a8-2
- 2. Review the marks (red hatching; uncheck to keep) -> 08 Protect.dc.html#a8-2
- 3. Apply (dialog names consequence; saves a new file by default) -> 08 Protect.dc.html#a8-2b
- 4. Verified (Ferman re-reads saved file and lists each check passed) -> 08 Protect.dc.html#a8-2c
- 5. Send (share the 'karartılmış' copy from the tab or Finder) [end] -> 11b App.dc.html#a11-6
- branch (info). Hidden information: author names, comments, old versions removed in same step -> 08 Protect.dc.html#a8-3
- branch (warn). The file is signed: redacting invalidates signatures, said before applying -> 08 Protect.dc.html#a8-4
- branch (err). Disk full while saving: edits stay in recovery copy; save elsewhere -> 11b App.dc.html#a11-7

**Flow D — Scan a paper contract, recognize, sign, share (Mobile · iPhone and Pixel)** — milestone: P5 (tablet and mobile apps, the last P5 step after plugins and web). It also depends on P3 OCR; the NFC e-imza branch needs P3 e-imza on mobile.

- 1. Scan (camera permission explained first; edges found, auto-capture) -> 13b Mobile tasks.dc.html#a13-9
- 2. Review pages (crop, rotate, B&W filter, reorder) -> 13b Mobile tasks.dc.html#a13-9b
- 3. Recognize text (Turkish on; PDF becomes searchable) -> 13b Mobile tasks.dc.html#a13-9b
- 4. Sign (landscape capture or saved signature, touch handles) -> 13b Mobile tasks.dc.html#a13-8d
- 5. Share (choose size and format, system share sheet) [end] -> 13b Mobile tasks.dc.html#a13-13
- branch (info). Camera not allowed: choose photos instead -> 13a Mobile core.dc.html#a13-1c
- branch (warn). Needs a qualified e-signature: ID card over NFC or send to desktop -> 13b Mobile tasks.dc.html#a13-8f
- branch (err). Phone storage full: scan kept, says how much space is needed -> 13b Mobile tasks.dc.html#a13-16c

**Sample documents and the corpus PDFs they imply**

- DocKira.dc.html: Turkish residential rental contract 'Kira sözleşmesi.pdf' (KONUT KİRA SÖZLEŞMESİ No 2026/0412, 13.10.2026). 3 A4 pages, Madde 1-10 plus a signature page, IBM Plex Serif 10.5 pt justified. Fictitious T.C. Kimlik Nos 35712648950 / 41239876516, IBAN TR12 0006 4000 0011 2345 6789 01, e-mails and phones. Madde 4 rent edit 18.500 -> 19.500 TL with the IBAN line directly below; Madde 6 in a subset font with no 'ğ'. Lists Ek-1 Demirbaş listesi.xlsx and Ek-2 Tapu fotokopisi; the sidebar also shows Kimlik fotokopisi.pdf. Implied corpus PDF: 3-page Turkish contract with subset-embedded fonts, one subset deliberately missing 'ğ' (missing-glyph path), a tight frame above the IBAN line (overflow), a 'KİRA' title for Turkish i/İ search folding, three embedded file attachments (xlsx, jpg, pdf), signature fields on page 3, PII for redaction. Derived variants: 'Kira sözleşmesi — imzalı.pdf' (PAdES/qualified signature with TÜRKSERT-style timestamp); 'Kira sözleşmesi — imzalı (2).pdf' (incremental update after signing -> 'changed after signing'); 'Kira sözleşmesi (eski).pdf' (repairable: broken xref, 48 objects, 3 pages, page 3 references non-embedded TimesNewRomanPSMT); 'Kira sözleşmesi.docx' / 'Kira sözleşmesi taslak.docx' (conversion and version-history origin); 'Kira sözleşmesi — yorumlu.pdf' (with comments/annotations).
- DocEkstre.dc.html: Turkish bank statement 'Hesap ekstresi Eylül 2026.pdf' (Boğaziçi Bankası, Kadıköy Şubesi, 01-30.09.2026). 2 pages; a transaction table (Tarih/Açıklama/Tutar/Bakiye, Turkish number format such as 12.430,15) and customer block with T.C. Kimlik No 41239876516, IBAN TR33 0006 1005 1978 6457 8413 26, address and phone. Implied corpus PDF: 2-page statement with real text (not an image) containing checksum-valid TCKN, IBAN, phone and e-mail patterns, plus metadata/hidden content (author, comments, old incremental versions). It tests pattern redaction, verified removal in 'Hesap ekstresi Eylül 2026 — karartılmış.pdf' (re-read shows no recoverable text) and hidden-information removal.
- DocForm.dc.html: e-Devlet 'T.C. Yerleşim Yeri Adresi Beyan Formu' (Adres Kayıt Sistemi, Form AKS-1, Başvuru No 2026-0047812, verification code AKS-7F3K-91QD), file 'Adres değişikliği formu.pdf'. The fixture is 1 page; FmStart said 2 pages until export 519d42a, which lists 1. 20 fields, 15 required: text (tc_kimlik_no, adi, soyadi, telefon, eposta, mahalle, cadde_sokak, dis_kapi_no, ic_kapi_no, hane_kisi_sayisi), date GG.AA.YYYY (dogum_tarihi, tasinma_tarihi, beyan_tarihi), radio group (cinsiyet), dropdowns (medeni_hal, il, ilce), checkboxes (beyan_dogruluk, beyan_kurum) and a signature field (imza). Implied corpus PDF: AcroForm with exactly these field types, names, required flags, date format and number-range validation actions, and a defined tab order. A flat non-interactive twin is needed for 'Fill anything' (a5-4) and 'Prepare form — fields found' (a5-8b), and a signed copy for e-imza tests.
- DocCv.dc.html: Turkish CV 'Zeynep Arslan — Özgeçmiş.pdf' (Kıdemli Muhasebe Uzmanı, İzmir). 1 page: header, photo image at top-right, sections DENEYİM, EĞİTİM, DİLLER with bullet lists. Props drive reading-order badges, accessibility issues (image without alt text, low-contrast line, untagged list) and image selection. Implied corpus PDF: an untagged 1-page CV with an embedded raster photo, a low-contrast text run and visual-only lists. It feeds the accessibility checker (a9-3/a9-3b), image crop (a3-5b) and 'Fill anything' on a flat page.
- DocPlan.dc.html: Turkish floor plan 'Kat planı — Daire 5.pdf' (Moda Cad. No 18, Kadıköy; scale 1:75; sheet A-01; rooms SALON 35,1 m², YATAK ODASI 25,9 m², MUTFAK 10,6 m², ANTRE 10,8 m², BANYO 7,4 m²; dimensions 12,00 / 10,80). Implied corpus PDF: a vector drawing page with a known 1:75 scale (optionally a /Measure viewport dictionary). It tests distance, area and perimeter measurement and calibration (a4-1c, a9-7).
- e-Arşiv invoice 'e-Arşiv fatura 4187.pdf' (inline in 03b a3-9, not a Doc* fixture): Defne Kırtasiye ve Ofis Ürünleri Ltd. Şti., No DKO2026000004187, 13.10.2026, buyer Yılmaz Mimarlık, VKN numbers, line-item table with columns A-F (Sıra, Mal/Hizmet, Miktar, Birim fiyat, KDV %20, Tutar), Turkish amounts. 1 page. Implied corpus PDF: 1-page invoice with a real column/table layout, right-aligned numeric columns and dependent totals. It tests column-aware editing and flagging of dependent amounts; it also appears in tabs, crash recovery and conversion queues.
- Master's thesis 'Yüksek lisans tezi — Elif Şahin.pdf' (Kentsel Dönüşüm Sürecinde Kiracı Hakları): 64 pages, Turkish with an English block quote, a deliberate misspelling 'kiracınnın', and nested outline Özet ve içindekiler / 1. Giriş / 2. Kentsel dönüşüm ve kiracılık / 3. Bulgular / 4. Sonuç / Kaynakça. Implied corpus PDF: a 64-page tagged PDF with nested bookmarks, page labels, per-block /Lang (tr and en). It tests outline (a2-3a), split by chapter (a6-2), search speed, per-block language and spell-check (a3-14), plus OCR/conversion queues.
- English: 'Mutual NDA — Northwind.pdf' (Northwind Analytics Ltd. and Kaya Mimarlık A.Ş., 2 October 2026), 4 pages, marked signed in Start. Implied corpus PDF: 4-page English contract with a digital signature, for validation states and English -> German translation with text expansion and German hyphenation (a3-13b).
- German: 'Mietvertrag Berlin.pdf', 6 pages (recent files). Implied corpus PDF: 6-page German contract with umlauts and ß, for diacritic-insensitive search, German hyphenation/reflow and German UI validation.
- Arabic: 'التقرير السنوي 2025.pdf' (Annual report 2025), 12 pages (recent files); a3-13a also previews the rental contract translated Turkish -> Arabic. Implied corpus PDF: 12-page RTL Arabic document with shaped text, mixed LTR numbers/IBAN (bidi isolation), embedded Arabic font. It tests rendering, search and editing in RTL. Since export 519d42a, a2-15 draws its first two pages as a right-to-left spread, so the PDF also needs /ViewerPreferences/Direction /R2L.
- Japanese: '見積書_2026-10.pdf' (quotation), 2 pages, marked scanned. Implied corpus PDF: image-only Japanese scan for Japanese OCR (38 MB pack proposal). Also '賃貸借契約更新のご案内.pdf' (lease-renewal letter to アイシェ・ユルマズ from 株式会社モダ不動産, a3-15). Implied corpus PDF: vertical-writing (縦書き) CJK text with an embedded Japanese font, an upright tate-chu-yoko '19' and kinsoku line breaking.
- Scanned Turkish letter 'Kira artış bildirimi (tarama).pdf' (Kaya Gayrimenkul Yönetimi, 06.10.2026, rent increase to 19.500 TL), 3 pages per the OCR queue ('Recognizing page 2 of 3'). Implied corpus PDF: image-only 3-page scan with Turkish text for scanned-page detection (a3-11), Turkish auto-detect OCR, words-to-check (a7-5b) and batch OCR.
- Password-protected payslip 'Maaş bordrosu Eylül 2026.pdf' (unlock a1-8/a1-8b, wrong-password example 'eylul2026', Protect a8-1). Implied corpus PDF: encrypted PDF (user password, AES-256) whose correct password contains Turkish ı/ş/ü characters, to test the Turkish keyboard-layout hint.
- Large file 'İmar planı açıklama raporu.pdf' (Kadıköy Belediyesi 1/1000 zoning plan report, Cilt 1-6, 2,400 pages). Implied corpus PDF: a generated 2,400-page document for progressive open, first-page-first rendering, background indexing and thumbnail performance.
- Truncated file 'Tarama_0042.pdf' (stops at 18 KB, expected about 2.4 MB, last complete object 12 0 obj). Implied corpus PDF: a deliberately truncated, unrecoverable PDF for the 'can't be opened' path (a1-9b) and the failed-conversion queue row.
- XFA form 'Vize başvuru formu.pdf' (a11-7c). Implied corpus PDF: dynamic XFA-only form for the unsupported-XFA notice.
- Flat form 'Otomatik ödeme talimatı.pdf' (05a/05b 'Fill anything' and Prepare form). Implied corpus PDF: non-interactive form-looking page with no AcroForm, for click-anywhere fill and automatic field detection.
- Organize/combine inputs: 'Kimlik fotokopisi.pdf' (2 pages, 340 KB), 'Tapu fotokopisi.jpg', 'Ek-1 Demirbaş listesi.xlsx', combined output 'Kira dosyası — tam.pdf'. Implied corpus: mixed-format inputs (PDF, JPG, XLSX) for combine-with-conversion and attachment extraction.
- Boards of export 519d42a imply a few more inputs: a restricted variant of the rental contract (owner password, AES-256, no password to open; printing at high quality, copying and screen-reader access allowed, the other five permissions not) for a2-10a and a2-10b; a read-only copy for a1-9d; a signed copy whose page 3 holds Mert Kaya's signature of 13.10.2026 for a2-14, a3-16a and a3-16b; a page PDFium cannot draw for a2-13; a heading drawn as vector shapes for a3-19; a search in the 2,400-page file with many matches for 'otopark' for a2-4c; and the Excel attachment 'Ek-1 Demirbaş listesi.xlsx' opened on its own for a1-9c.

## 10. Missing screens and states

Every gap of type missing screen, missing state or missing variant that the M0 inventory recorded
(G01 to G61), plus the export gaps, grouped by the milestone that needs them. Each line names the
affected boards and links to the entry in [DESIGN_GAPS.md](DESIGN_GAPS.md), which records the option
chosen. Where a state is not drawn, the app builds it from DS components in the design's voice, as
the entry describes (brief §2). Phases 2 to 5 have no entries of these types yet; their boards are
checked again when each phase is planned. Entries of these types added after M0 (G63 onwards) are
listed only in DESIGN_GAPS.md. Export 519d42a drew many of these screens and states. Each line below
names the boards that now draw them and says what is still not drawn; the entry in DESIGN_GAPS.md
keeps the decision and its status.

### Export gaps (all affect M1)

- [G01](DESIGN_GAPS.md#g01) Export gap. `design/ui_kits/desktop/index.html`, cited in brief §2, and the whole `ui_kits/` folder are absent. Until a re-export the shell reference is `FmWindow`, `FmStart`, `FmSidebar`, `FmEditPanel` and `FmSettings`. Boards: every desktop shell board, for example `f6a`, `a1-4`, `a3-1d`.
- [G02](DESIGN_GAPS.md#g02) Export gap. No component sources, type definitions, prompts or cards, and no `EditorScreen` template. Props come from `_ds_bundle.js` and `_adherence.oxlintrc.json`. Affects: the component library (section 6).
- [G03](DESIGN_GAPS.md#g03) Export gap. The `guidelines/` folder (23 foundation cards), `thumbnail.html`, `SKILL.md` and `_dev/` are absent. The values survive in `tokens/*.css` and `readme.md`. Affects: focus, motion, elevation and spacing rules.
- [G04](DESIGN_GAPS.md#g04) Export gap. No icon SVGs: `assets/icons/` is absent, and the glyphs exist only as path data in `_ds_bundle.js` and `fm-icons.js`. Affects: section 7.
- [G05](DESIGN_GAPS.md#g05) Export gap. 31 tokens and 3 overrides live only in `fm-additions.css`. Affects: the token generator and every board with edit marks, document tabs or Windows chrome.
- [G06](DESIGN_GAPS.md#g06) Export gap. The 23 font files are WOFF2 unicode-range subsets Flutter cannot bundle, with no Vietnamese and no Plex Sans italic. Affects: every board; `a1-1` lists "Tiếng Việt".
- [G07](DESIGN_GAPS.md#g07) Export gap. 13 font families load from Google Fonts at runtime. Hebrew, Devanagari, CJK and handwriting fonts are not bundled, and Traditional Chinese has no font. Boards: `a1-1`, `a13-1b`, `a5-3`, `a12-1ja`, `a3-15`.
- [G08](DESIGN_GAPS.md#g08) Export gap. No licence texts: OFL-1.1, Lucide ISC, Feather MIT, and Apache-2.0 for Homemade Apple. Boards: `a11-5`, whose credit line omits several families and Feather. The repository carries the OFL-1.1, ISC and MIT texts for the material already in `design/` in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md); the app ships its own licence files in `app/assets`.
- [G60](DESIGN_GAPS.md#g60) Export gap. Seven of the 84 added icons are not Lucide 0.460.0: `bell`, `grid-2x2` and `funnel` match 1.56.0, `paperclip` and `expand` match 0.500.0, `file-signature` matches 0.300.0, and only `ellipse` matches no release. The Index says "+64" where the file has 84. Affects: section 7.

### M1 Foundations

- [G10](DESIGN_GAPS.md#g10) Missing state. No "Available in a future version" disabled state with a tooltip anywhere in the design. Boards: the `FmWindow` tool rows (Edit, Convert, Protect, Fill & Sign, Tools) and AI button, `a1-4`, `a1-4b`, `a1-4c`, `a1-11`, `a3-11`, `a11-2`, `a11-1e`, `a11-1f`, `a11-1g`. Drawn in 519d42a: the M1 builds `a1-2c-m1`, `a1-5-m1`, `a11-1-m1`, `a11-1w-m1` and `a11-1h-m1`, the M2 build `a1-4-m2`, Convert to PDF… in `a1-9c`, PDF/A-2b in `a1-11b` and the OCR action in `a2-3m`; `FmWindow` gained a `future` list that draws later tools disabled, as on the new View boards.
- [G15](DESIGN_GAPS.md#g15) Missing variant. No Linux artboard; the `platform` prop allows only `mac` and `win`. Needed at least: the Linux versions of `f6a`, `a1-4c`, `a1-10b` and `a11-1w`.
- [G16](DESIGN_GAPS.md#g16) Missing variant. Windows is drawn only in `f6`, `f6a`, `a1-4c`, `a11-1w`, `a12-1de`, `a12-2b`, `a12-2d`. Missing: the dialogs (`a1-8`, `a1-8b`, `a1-10b`, `a1-11`, `a1-12`, `a11-7`), the tab overflow menu (`a1-10`), View, Comment, Fill and Organize modes, and most Settings panes (`a11-1e`, `a11-1g`, `a11-1j` hard-code macOS wording). Export 519d42a adds `a11-1w-m1`, and the caption of `a11-7e` gives the Windows button order in words.
- [G17](DESIGN_GAPS.md#g17) Missing variant. Dark is drawn only in `a1-4b`, `a2-3x`, `a2-5a`, `a2-9`, `a3-1d`, `a4-1d`, `a5-1d`, `a11-6`; `a5-2b` states that on-page field colours are theme-invariant but is drawn in light only. Missing: onboarding (`a1-1` to `a1-3`), the dialogs (`a1-8` to `a1-12`), Settings (`a11-1` and its panes), `a3-3a`, `a3-3b`, `a3-4`, `a3-12`, Organize (`a6-1` to `a6-5`), `a11-2`, `a11-6b`, the errors (`a11-7`, `a11-7b`, `a11-7c`), a dark View-mode window (`a2-1a` to `a2-1d`) and the Dimmed page option.
- [G18](DESIGN_GAPS.md#g18) Missing variant. Desktop right-to-left is drawn only in `a12-1ar`, `a12-2a`, `a12-2c`. Missing: the dialogs, `a1-10`, `a2-1c`, `a2-1d`, sidebar tabs other than Pages, `a2-4a`, `a3-3a`, `a3-4`, `a3-12`, `a11-2`, `a11-6`, `a11-6b`, Windows caption buttons in right to left, and any Persian or Hebrew screen. Export 519d42a adds an Arabic variant of its 29 switchable boards (section 2), among them Save as (`a1-11b`), sidebar tabs (`a2-3m`, `a2-14`), dialogs (`a1-9e`, `a3-16a`, `a3-12b`, `a11-7d`, `a11-7e`, `a11-7f`) and a Windows board in right to left (`a11-1w-m1`). The boards named above (`a1-10`, `a2-1c`, `a2-1d`, `a2-4a`, `a3-3a`, `a3-4`, `a3-12`, `a11-2`, `a11-6`, `a11-6b`) and the first export's dialogs are still drawn left to right only, and Persian and Hebrew are still not drawn.
- [G19](DESIGN_GAPS.md#g19) Missing variant. Turkish UI is drawn only in `a12-1tr` (desktop) and `a12-3d`, `a12-3e` (mobile). `FmStart` and `FmSettings` have no `tr` option, no Turkish dialog exists, and no Turkish all-caps label such as "İMZALA" appears in the UI chrome. Export 519d42a adds a Turkish variant of its 29 switchable boards, gives `FmStart` and `FmSettings` a `tr` option, and draws Turkish dialogs (`a1-9e`, `a1-11b`, `a3-16a`, `a3-12b`, `a11-7d`, `a11-7e`, `a11-7f`) and the Turkish capitals heading "İZİNLER" in `a2-10b`.
- [G20](DESIGN_GAPS.md#g20) Missing state. Language picker (`a1-1`, `a13-1b`): no translation status or fallback state, no filter state without results, no state after choosing a right-to-left language. `a1-2c` and `a11-5` claim 21 languages.
- [G21](DESIGN_GAPS.md#g21) Missing state. No shell narrower than 1440 px: no icon-only tool row with overflow, no mode-tab truncation, no sidebar or panel resize handles or limits. Partial references: `a12-1de`, `a1-10`, `a14-1b`, `a14-1c`, `a14-1d`.
- [G22](DESIGN_GAPS.md#g22) Missing state. No focus state for ToolButton, ModeTabs, document tabs, SegmentedControl, sidebar rows or the canvas text block, and no product tooltip with a shortcut (only the DS additions specimen). Focus is drawn in `a1-1`, `a5-2b`, `f5`, `a9-7`, and since 519d42a on a feature tile of `a1-2c-m1` and an action card of `a1-5-m1`.

### M2 Open and view

- [G25](DESIGN_GAPS.md#g25) Missing screen. A file arriving from the OS (double-click, Open with, Dock or taskbar) into a running instance, a file that is already open, a cold launch into a document, and the open dialog. Flow `fa` step 1 points to `a1-4`; `a13-13` has the only related note. See [ADR 0018](adr/0018-native-file-pickers.md) (Accepted with [Q07](QUESTIONS.md#q07) on 2026-10-16). Drawn in 519d42a: `a1-13`, the hand-off to the system open panel. Its caption describes a file from the OS, a file already open and a cold launch, which are not drawn.
- [G27](DESIGN_GAPS.md#g27) Missing state. Opening an owner-password or permission-restricted PDF, or a certificate-encrypted one, and the Security tab of `a2-7`. Related boards: `a1-8`, `a1-8b`, `a8-1`, `a8-4`. Drawn in 519d42a: `a2-10a` (the banner, the disabled tools with their reason, Unlock with owner password…) and `a2-10b` (the Security tab). The owner-password dialog and the certificate-encrypted error are described, not drawn.
- [G28](DESIGN_GAPS.md#g28) Missing state. Open errors: an unsupported file type, a read-only or permission-denied file, a moved or deleted recent file (`a1-4`), running out of memory. `a1-5` and `a1-6` promise conversion on open, which arrives only in P3 ([G11](DESIGN_GAPS.md#g11)). Drawn in 519d42a: `a1-9c` (not a PDF), `a1-9d` (read-only), `a1-9e` (a missing recent file) and `a1-9f` (out of memory). `a1-5-m1` and `a1-4-m2` speak of PDF files only; `a1-6` still promises conversion.
- [G29](DESIGN_GAPS.md#g29) Missing state. Empty states for every sidebar tab (`a2-3p`, `a2-3o`, `a2-3b`, `a2-3c`, `a2-3d`, `a2-3e`), search with no results or still running (`a2-4a`, `a2-4b`), and a page without a text layer in search. The DS has no empty-state component. Drawn in 519d42a: one EmptyState in `a2-3m` (empty Outline, Attachments, Layers and Signatures tabs, Search with no result and with no text layer), the running search `a2-4c` and the no-results find bar `a2-4d`. The caption of `a2-3m` gives the same EmptyState to the task drawer and the language filter, which are not drawn.
- [G30](DESIGN_GAPS.md#g30) Missing state. Tiles loading while zooming or scrolling, a page that fails to render, Fit width and Actual size selected, and go-to-page entry in the status bar. Related boards: `a2-1a`, `a2-1c`, `a2-1d`, `a2-2`, `a1-7`. Drawn in 519d42a: `a2-13` (tiles sharpening, a failed page with Try again, Fit width selected, the page field focused by ⌘G). Actual size selected is not drawn.
- [G31](DESIGN_GAPS.md#g31) Missing state. A signature that is present but not checked, needed until P3 validation. Boards: `a2-3d`, the document panel in `a2-1a` to `a2-9`, the badges in `a1-4`, `a13-2`, `a13-3b`, and `a8-4`. Drawn in 519d42a: `a2-14` (the neutral Signatures tab, and the document panel in English only) and the neutral Signed chip of `a1-4-m2`. The other boards named above still show validated signatures, the state P3 ships.

### M3 Edit text core

- [G35](DESIGN_GAPS.md#g35) Missing screen. The warning before the first edit of a signed document, its persistent banner and a row in the review list. Boards that edit the signed contract without it: `a3-1a`, `a3-1b`, `a3-1c`, `a3-2`, `a3-3a`, `a3-4`, `f4a`, `a12-1tr`, `a12-1de`, `a12-1ar`, `a12-1ja`; `a3-12` has no signature row. Drawn in 519d42a: the warning `a3-16a`, the banner `a3-16b` and the signature row in `a3-12`. The boards named above still edit the signed contract without the warning.
- [G37](DESIGN_GAPS.md#g37) Missing state. The missing-glyph chain beyond `a3-3a`, `a3-3b` and `a13-5c`: step 2 (the same font installed, glyph re-subset), no font covers the character, the font's licence forbids embedding, the result on the page after substitution, and missing glyphs in replacement text (`a3-7`) or table cells (`a3-9`). Drawn in 519d42a: `a3-17` (step 2, no font, licence forbids embedding). Its caption describes the result after a substitution and the same flow in replacement text and table cells, which are not drawn.
- [G38](DESIGN_GAPS.md#g38) Missing state. Overflow results (`a3-4`, `a13-5c`): after "Extend block", after "Tighten spacing slightly", Extend colliding with the line below, tightening not being enough, and the marker on the page after "Keep and warn". Drawn in 519d42a: all five in `a3-18`.
- [G39](DESIGN_GAPS.md#g39) Missing state. Text that cannot be edited: Type3 or outlined glyphs, form XObjects, unparsable content streams, editing forbidden by permissions, a read-only file. Only the scanned-page case (`a3-11`) is drawn. Drawn in 519d42a: `a3-19`, with text drawn as vector shapes; its caption lists the other reasons, which are not drawn.
- [G40](DESIGN_GAPS.md#g40) Missing state. Save failures: a read-only or permission-denied destination, the atomic rename failing, a file locked by another app, a lost network drive, quitting with several unsaved documents, recovery after the original changed. Drawn: `f4`, `f4a`, `f4b`, `a11-7`, `a11-7b`, `a1-10b`, `a1-12`, and since 519d42a `a11-7d` (permission denied, locked, rename failed, drive disconnected), `a11-7e` (quitting with several unsaved documents) and `a11-7f` (recovery after the original changed).
- [G42](DESIGN_GAPS.md#g42) Missing state. Review list (`a3-12`): empty state, the "Revert all…" confirmation, reverting an edit another edit depends on, a signed-document row, and whether the list survives reopening. Drawn in 519d42a: `a3-12b` (the empty state and both confirmations) and the signature row in `a3-12`, whose note says the list covers the current session and clears when the document closes.
- [G43](DESIGN_GAPS.md#g43) Missing state. Settings → Editing (`a11-1c`): incremental versus full save, recovery interval and location, an overflow default and a signed-document warning preference. Drawn in 519d42a: the Saving group in `a11-1c` (incremental save, Optimize and clean, the recovery folder; the interval stays one minute). Its note says there is no overflow default and no switch for the signed-document warning.

### M4 Rest of phase 1

- [G14](DESIGN_GAPS.md#g14) Missing screen. Licences and third-party notices, behind the "Licences" button in `a11-5` and the "About and licence" row in `a13-15`. Desktop Settings has no entry for them.
- [G45](DESIGN_GAPS.md#g45) Missing screen. The insert blank page, insert pages from a file, replace and extract dialogs (entry points in `a6-1`), combining locked inputs (`a6-3`), and split or combine rows in the task drawer (`a11-6b`).
- [G46](DESIGN_GAPS.md#g46) Missing state. Comments: a commenter-name setting, the annotation context menu, an empty panel and a filter without matches, delete with undo, Comment mode on a signed or restricted document, and editing Text (X) and Callout (C) annotations. Boards: `a4-1`, `a4-1d`, `a4-2`, `a4-3`.
- [G47](DESIGN_GAPS.md#g47) Missing state. Forms and simple signatures: the Finish dialog, the Clear form confirmation, a notice for signed or certified forms, an empty Sign menu, the result of an imported-image signature (`a5-3c`), field navigation across pages. Boards: `a5-1`, `a5-2`, `a5-3d`.
- [G48](DESIGN_GAPS.md#g48) Missing state. Compress (`a9-1`): progress, cancel, the result in context, the signed-file warning. Version history (`a9-8`): restore confirmation, empty first-save state, storage failure.
- [G49](DESIGN_GAPS.md#g49) Missing state. Command palette (`a11-2`): empty, no-match and disabled items. Toasts (`a11-6`): placement and stacking in the window. Task drawer (`a11-6b`): empty state and cancel confirmation.
- [G50](DESIGN_GAPS.md#g50) Missing variant. Settings (`a11-1`, `a11-1b` to `a11-1k`) exist only in light, macOS and English, apart from `a11-1w`, `a12-2c`, `a12-2d`: no dark, Turkish or Linux version, no search results or no-match state, no network activity log (`a11-1h`), reset confirmation (`a11-1k`) or import error, and no AI key entry states (`a10-2`, `a11-1g`). Export 519d42a adds Turkish and Arabic for General and Privacy through the M1 builds `a11-1-m1`, `a11-1w-m1` and `a11-1h-m1`.

### M5 Release pipeline

- [G53](DESIGN_GAPS.md#g53) Missing state. The update flow: checking, update available, downloading, failed or offline, check turned off, and updates managed by Homebrew, winget or a Linux package manager. Drawn: `a11-1i`, `a11-4`, `a11-4b`.

### Conflicts and decisions

The conflicts ([G09](DESIGN_GAPS.md#g09), [G11](DESIGN_GAPS.md#g11), [G12](DESIGN_GAPS.md#g12), [G13](DESIGN_GAPS.md#g13), [G24](DESIGN_GAPS.md#g24), [G34](DESIGN_GAPS.md#g34), [G41](DESIGN_GAPS.md#g41), [G44](DESIGN_GAPS.md#g44), [G51](DESIGN_GAPS.md#g51), [G54](DESIGN_GAPS.md#g54), [G55](DESIGN_GAPS.md#g55), [G56](DESIGN_GAPS.md#g56), [G57](DESIGN_GAPS.md#g57) and [G61](DESIGN_GAPS.md#g61)) and the ambiguities ([G23](DESIGN_GAPS.md#g23), [G26](DESIGN_GAPS.md#g26), [G32](DESIGN_GAPS.md#g32), [G33](DESIGN_GAPS.md#g33), [G36](DESIGN_GAPS.md#g36), [G52](DESIGN_GAPS.md#g52), [G58](DESIGN_GAPS.md#g58) and [G59](DESIGN_GAPS.md#g59)) are in
[DESIGN_GAPS.md](DESIGN_GAPS.md), each with the decision taken. Questions for the owner are in
[QUESTIONS.md](QUESTIONS.md). Export 519d42a draws several of these decisions: the milestone builds
for G11 and G12 (`a1-2c-m1`, `a1-5-m1`, `a1-4-m2`, `a1-9c`), Apache-2.0 for G13 (`a1-2c`, `a11-5`),
the four network uses for G24 (`a1-2b`), the system panels for G26 (`a1-9e`, `a1-13`, `a1-11b`), the
right-to-left spread for G32 (`a2-15`), the region-format table for G34 (`a12-0`), the missing-glyph
steps for G36 (`a3-3a`, `a3-17`), Save disabled only when saved, saving or read-only for G41
(`a1-9d`, `a11-7`), one shortcut table for G44 (`a11-1j`, `a11-2`, `a11-3`), the
1-page e-Devlet form for G59 (`FmStart`) and the accent default for G61 (`a2-4a`).
