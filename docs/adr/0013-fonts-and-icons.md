# ADR 0013: Fonts and icons

- **Status:** Accepted. The brief's parts are Accepted (brief); the Plex Sans Hebrew and Devanagari
  part was accepted by the owner on 2026-10-15 (Q08 groups 1 and 2); bundling the handwriting faces
  and the similar fonts was approved on 2026-10-16 (Q08 groups 3 and 4).
- **Date:** 2026-10-14
- **Approval:** brief §2 for the parts marked Accepted (brief), including the icons. Bundling Plex
  Sans Hebrew and Plex Sans Devanagari was approved by the owner on 2026-10-15
  ([Q08](../QUESTIONS.md#q08), groups 1 and 2); groups 3 and 4 on 2026-10-16.
- **Supersedes:** none
- **Superseded by:** none

## Context

The brief: "Fonts and icons come from the design (IBM Plex families, Lucide icons). Verify their
licences (OFL / ISC) and bundle them in app/assets with their licence files. For scripts the bundled
fonts don't cover (e.g. CJK), fall back to system fonts; record this in an ADR." ([brief §2](../BRIEF.md))
This is that ADR.

What the export contains, and why it cannot be used as is:

- **Fonts.** 23 woff2 files, all Google Fonts unicode-range subsets: IBM Plex Sans (a variable font
  despite the "-400-" file names), Plex Sans Arabic, Plex Serif and Plex Mono. Flutter cannot bundle
  woff2, has no unicode-range, and the subsets miss Vietnamese (U+1EA0 to U+1EF1). Subsets are modified
  fonts, and IBM's licence reserves the font name "Plex", so shipping them under that name is not
  allowed ([G06](../DESIGN_GAPS.md#g06)).
- **Network fonts.** `fm-additions.css` loads 13 families from Google Fonts at run time: Plex Sans JP,
  KR, Hebrew and Devanagari, Noto Sans SC, Noto Serif JP, Noto Naskh Arabic, EB Garamond, Cormorant
  Garamond, Crimson Pro, and the handwriting faces Caveat, Homemade Apple and Dancing Script. Traditional
  Chinese has no font at all ([G07](../DESIGN_GAPS.md#g07)). A local-first app cannot depend on this.
- **Licence texts.** None ship in the export: no OFL, ISC, MIT or Apache-2.0 file
  ([G08](../DESIGN_GAPS.md#g08)). The repository carries the OFL-1.1, ISC and MIT texts for the copies
  already in `design/` in [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md); the app ships its own
  licence files.
- **Icons.** 229 glyphs, all unique: 145 in the bundle's `ICON_PATHS` (every one matches Lucide 0.460.0
  exactly) and 84 in `ds-additions/fm-icons.js`. Of the 84, 77 match Lucide 0.460.0; bell, grid-2x2 and
  funnel match Lucide 1.56.0; paperclip matches Lucide 0.469.0 and 0.500.0; expand matches Lucide
  0.500.0; file-signature matches Lucide 0.263.0 and 0.300.0 (an older drawing). Only ellipse, a plain
  SVG ellipse, matches no Lucide release ([G04](../DESIGN_GAPS.md#g04), [G60](../DESIGN_GAPS.md#g60)).
  So 228 of the 229 glyphs are Lucide's work. The design system draws icons at a 1.5 px stroke and
  rules out an icon font ("No icon font, no PNG icons, no sprite sheet."). The promised
  `assets/icons/*.svg` folder is missing. About 57 of the glyphs derive from Feather (MIT).

Licences verified on 2026-10-13 and 2026-10-14: IBM Plex is OFL-1.1, "Copyright © 2017 IBM Corp. with
Reserved Font Name 'Plex'", for every family package. Lucide is ISC. The `LICENSE` files of Lucide
0.263.0, 0.300.0, 0.460.0, 0.469.0 and 0.500.0 are identical: the ISC text, with a copyright line that
names the Feather portions as MIT (Cole Bemis). The 1.56.0 file adds the list of Feather-derived icons
and the full MIT text. Homemade Apple is Apache-2.0, not OFL.

## Decision

### Accepted (brief): IBM Plex, bundled unmodified

- We bundle **IBM's official, unmodified static TTF files** from the IBM/plex GitHub releases
  (`fonts/complete/ttf`), never the design's woff2 subsets:
  - **IBM Plex Sans** 400, 500 and 600, plus Italic 400 (IBM release `plex-sans` 1.1.0, font
    revision 3.005). The complete files cover Latin, Turkish, Vietnamese, Cyrillic and Greek. The
    italic is there because a drawn UI state needs one: the FontPicker missing state uses italic text,
    which the boards synthesise as an oblique because the design declares no italic face; the app uses
    IBM's true italic ([G06](../DESIGN_GAPS.md#g06)).
  - **IBM Plex Serif** 400, Italic 400 and 600 (IBM release `plex-serif` 2.0.0, revision 3.006): the
    weights the design system's `@font-face` set declares (the wordmark at 600).
  - **IBM Plex Mono** 400 and 500 (IBM release `plex-mono` 2.5.0, revision 2.005), for technical
    details (a1-9b). Mono 600 appears only in the boards' own section numbers and weight 700 only in a
    mobile large title (a later phase), so neither is bundled.
  - **IBM Plex Sans Arabic** 400, 500 and 600 (IBM release `plex-sans-arabic` 1.1.0, revision 1.005),
    which also covers the Persian letters (پ چ ژ گ ک ی) and digits. It carries full ASCII and the
    Latin-1 letters but not Latin Extended-A (only one of İ ı Ğ ğ Ş ş), ế or U+200C (zero-width
    non-joiner), so in the UI it comes after IBM Plex Sans, in the design's `--font-ui` order (see
    [the UI font order](#the-ui-font-order-m1-2026-10-15)).
  - The 18 files and 6 licence texts are fetched by `tools/fonts` from IBM's release zips and pinned by
    SHA-256 in `tools/fonts/fonts.lock` ([DEPENDENCIES.md §5.2](../DEPENDENCIES.md#52-fonts)).
- **The Reserved Font Name is respected.** We never subset, convert, rename or otherwise modify the font
  files we ship. Subsets that Ferman embeds into a user's PDF are document embedding, which OFL-1.1
  allows ([ADR 0006](0006-font-pipeline-and-missing-glyphs.md)).
- Each family's `LICENSE.txt` ships next to its files in `app/assets/fonts/` and is registered with
  Flutter's `LicenseRegistry` for the third-party notices screen ([G14](../DESIGN_GAPS.md#g14)).
- Families are declared per weight in `pubspec.yaml` with the names the token generator emits
  ([ADR 0012](0012-design-token-pipeline.md)).

### Accepted (brief): system fallback for scripts the bundle does not cover

- **CJK uses system fonts**: Japanese (Hiragino Sans, Yu Gothic UI, Noto Sans CJK JP), Korean (Apple SD
  Gothic Neo, Malgun Gothic, Noto Sans CJK KR), Simplified Chinese (PingFang SC, Microsoft YaHei UI, Noto
  Sans CJK SC) and Traditional Chinese (PingFang TC, Microsoft JhengHei UI, Noto Sans CJK TC), on macOS,
  Windows and Linux respectively. IBM's Plex Sans JP, KR, SC and TC releases are 73 to 523 MB as zips,
  far too large to bundle.
- Every text style carries the UI locale, so Han characters take the right regional forms
  (Traditional Chinese never shows Simplified forms). Bold and italic are never synthesised for CJK, as
  the design asks (`font-synthesis: none`). Flutter has no switch for this, so the theme names the
  system families, which picks real bold faces where the system has them, and no CJK role is italic
  ([G65](../DESIGN_GAPS.md#g65)).
- If a character is not covered by any bundled or system font, Flutter's own fallback applies; the
  language picker (a1-1) is tested for every native language name.

### Accepted (owner, Q08, 2026-10-15): Plex Sans Hebrew and Plex Sans Devanagari

- We also bundle **IBM Plex Sans Hebrew** (IBM release `plex-sans-hebrew` 1.1.0) and **IBM Plex Sans
  Devanagari** (IBM release `plex-sans-devanagari` 1.1.0), 400, 500 and 600, unmodified, with their
  licences, under the same rules as the other Plex families. They are small (zips of 1.7 MB and
  5.3 MB), they are what the design's UI stack names, and they keep the Hebrew and Hindi UI in the
  design's typeface (revisions 1.003 and 1.002). Like the Arabic font they carry ASCII and Latin-1 but
  not Latin Extended-A, so in the UI they come after IBM Plex Sans (below).

### The UI font order (M1, 2026-10-15)

- Every UI language but Japanese, Korean and Chinese uses the design's `--font-ui` order: IBM Plex
  Sans, then Plex Sans Arabic, Plex Sans Hebrew and Plex Sans Devanagari, then the system fonts. That
  includes ar, fa, he and hi, as the design's Arabic boards (12 Localization) use `--font-ui`. For CJK
  the system families of the language come right after IBM Plex Sans, and the rest of `--font-ui`
  follows them. `FermanFontFamilies.uiChain` (`app/lib/design/theme/typography.dart`) builds every
  chain from the generated `--font-ui` stack ([ARCHITECTURE.md §11.5](../ARCHITECTURE.md#115-fonts-in-the-ui)).
- Why no script font comes first: the Arabic, Hebrew and Devanagari fonts lack İ, ş and ế but carry
  their base letters and combining marks, so with one of them first Flutter draws those letters from
  it as base plus mark, with misplaced marks (script-coverage golden, 2026-10-15). With Plex Sans first,
  Arabic, Persian, Hebrew and Devanagari text renders pixel-identically.
- This replaces the M0 wording, which put each script font before Plex Sans. It follows the boards
  and changes none of the decisions above ([G64](../DESIGN_GAPS.md#g64)).

### Accepted (brief): icons from the design's exact path data

- `tools/icons` extracts the path data of all **229 icons** from `ICON_PATHS` in `_ds_bundle.js` and
  from `ds-additions/fm-icons.js` and writes one SVG per icon to `app/assets/icons/` (24 × 24 view box,
  `currentColor` stroke, round caps and joins, **stroke width 1.5** as the design system draws them).
  The brief says the icons come from the design ([brief §2](../BRIEF.md)), so we ship its exact
  geometry, including the seven glyphs that are not in Lucide 0.460.0. A test fails if the count or any
  path differs from the design source.
- The app paints the icons itself: `tools/icons` also generates Dart path data, which a small
  `CustomPainter` in the Icon widget parses with path_parsing (MIT, from the flutter/packages
  repository) and strokes. The SVG files stay in `app/assets/icons/` as the exported, provenance-tracked
  set and are not loaded at run time. flutter_svg was dropped in M1 (lead decision, 2026-10-15): it and
  vector_graphics depend on the `http` package, which the network deny list forbids
  ([ADR 0015](0015-privacy-and-network.md)). No icon font, as the design system says; not the
  third-party lucide_icons_flutter package. The widget can override the stroke width, because some
  drawings use 1.8, 2 or 2.2.
- A **provenance table** (`app/assets/icons/PROVENANCE.md`, generated) names, for each icon, the Lucide
  release its geometry matches: "Lucide 0.460.0" (222 icons), "Lucide 1.56.0" (bell, grid-2x2, funnel),
  "Lucide 0.500.0" (paperclip, which also matches 0.469.0, and expand) and "Lucide 0.300.0"
  (file-signature, which also matches 0.263.0). Only ellipse is listed as "Ferman design"; it stays
  marked pending until the design re-export settles it ([Q11](../QUESTIONS.md#q11)).
- The **Lucide ISC licence and the Feather MIT notice** ship in `app/assets/icons/` and in the notices
  screen: the `LICENSE` of each source release. The 0.300.0, 0.460.0 and 0.500.0 files are identical, so
  one copy covers them (`LICENSE-lucide-0.460.0.txt`); the 1.56.0 file ships beside it
  (`LICENSE-lucide-1.56.0.txt`), both copied verbatim from the npm tarballs, which `tools/icons` checks
  against pinned hashes. Both are registered with `LicenseRegistry` under "Lucide". They cover the Lucide and Feather geometry. The
  one glyph drawn for Ferman (ellipse) is part of the project.
- A per-icon `directional` flag drives RTL mirroring ([ADR 0014](0014-localization-and-rtl.md)). It
  is set on exactly the 8 icons the design flips: arrow-left, arrow-right, chevron-left,
  chevron-right, undo-2, redo-2, skip-back and skip-forward. A `tools/icons` test re-reads the design
  files for this list. Send, reply, the list icons, text-cursor, arrow-left-right, volume-2 and
  chevrons-left and chevrons-right are not mirrored. The Icon widget's `flipRtl` defaults to this flag.

### Other fonts the design uses

- **Handwriting faces** for typed signatures (`--font-hand-1..3`: Caveat and Dancing Script under
  OFL, Homemade Apple under Apache-2.0) are needed for simple signatures in M4. They are bundled
  (group 3 of [Q08](../QUESTIONS.md#q08), approved 2026-10-16); Homemade Apple's Apache-2.0 licence
  ships with it.
- **Similar fonts for missing glyphs** (the a3-3b group "SIMILAR FONTS INCLUDED WITH FERMAN", drawn
  with Cormorant Garamond and Crimson Pro) are group 4 of Q08, bundled (approved 2026-10-16) and
  needed by M3 ([ADR 0006](0006-font-pipeline-and-missing-glyphs.md)). Any font chosen must allow
  embedding.
- **The Google Fonts `@import` is never used.** Ferman never fetches fonts at run time
  ([ADR 0015](0015-privacy-and-network.md)).

## Consequences

### Positive

- The UI looks as designed on every platform, offline, with the licences honoured.
- Vietnamese and Turkish are fully covered by the complete Plex Sans files.
- The install stays small: CJK comes from the OS.
- Icons match the artboards exactly, with a clear record of where each glyph came from.

### Negative

- IBM's release files differ in version from the design's Google copies (for example Plex Sans 3.005
  versus 3.201), so metrics and line heights are compared against the design references in M1.
- CJK depends on the fonts installed on each system. Goldens for those languages vary by platform and
  are not part of the M1 en, tr and ar golden set.
- Static weights mean one file per weight instead of one variable font.
- Persian text with ZWNJ needs explicit tests, because the Arabic font does not map it.

### Follow-up

- M1: download script with pinned checksums for the font zips (including Plex Sans Hebrew and
  Devanagari), `pubspec.yaml` font declarations, `tools/icons` with the provenance table, licence
  registration. Done in phase D: `tools/fonts` (with the committed TTFs and `coverage.py`) and
  `tools/icons` (229 SVGs, `IconName`, the provenance table and the Lucide licence files). The `pubspec.yaml`
  font and asset declarations came with the committed fonts (`67fd234`). Done in phase F: the Icon
  widget (`app/lib/design/icons/icon.dart`, painted by `icon_painter.dart` from the generated element
  data) and the `LicenseRegistry` entries (`app/lib/app/licenses.dart`, 24 texts, registered by
  `bootstrap()` and checked against `pubspec.yaml` by `app/test/app/licenses_test.dart`), with the
  script-coverage and icon goldens.
- M3: similar fonts for missing glyphs, once Q08 group 4 is answered.
- M4: handwriting fonts for typed signatures, once Q08 group 3 is answered; the third-party notices
  screen ([G14](../DESIGN_GAPS.md#g14)).

## Alternatives considered

- **Use the design's woff2 subsets.** Flutter cannot load them, they miss Vietnamese, and modified Plex
  files may not keep the name "Plex".
- **Convert the woff2 files to TTF.** Still modified subsets, with the same naming problem.
- **The google_fonts package or any run-time download.** A network use the brief does not allow, and it
  fails offline.
- **The variable Plex Sans TTF.** Works, but needs `FontVariation` handling everywhere; static weights
  are simpler and IBM ships them.
- **Bundle the CJK families.** Hundreds of megabytes. System fonts are better for this.
- **An icon font, or lucide_icons_flutter.** Against the design system's rule, and the package is a
  single-maintainer repackaging with Lucide's default 2 px stroke.
- **Fetch the official Lucide 0.460.0 SVGs instead of the design's paths.** Identical for 222 icons, but
  wrong for the other seven: six of them come from other Lucide releases (1.56.0, 0.500.0 and 0.300.0,
  above) and ellipse is in none. Taking official SVGs from four releases would give the same geometry
  for 228 icons, with more moving parts, and would still need the design's path data for ellipse.

## References

- [Brief](../BRIEF.md) §2, §6
- [ARCHITECTURE.md](../ARCHITECTURE.md), section 11.5
- [DESIGN_INVENTORY.md](../DESIGN_INVENTORY.md) (icons, fonts, script coverage)
- [DEPENDENCIES.md](../DEPENDENCIES.md) (bundled assets and notices)
- [ADR 0006](0006-font-pipeline-and-missing-glyphs.md), [ADR 0012](0012-design-token-pipeline.md),
  [ADR 0014](0014-localization-and-rtl.md), [ADR 0015](0015-privacy-and-network.md),
  [ADR 0016](0016-dependency-licence-policy.md)
- [G04](../DESIGN_GAPS.md#g04), [G06](../DESIGN_GAPS.md#g06), [G07](../DESIGN_GAPS.md#g07),
  [G08](../DESIGN_GAPS.md#g08), [G14](../DESIGN_GAPS.md#g14), [G60](../DESIGN_GAPS.md#g60)
- [Q08](../QUESTIONS.md#q08), [Q11](../QUESTIONS.md#q11)
- IBM/plex `LICENSE.txt` (OFL-1.1, Reserved Font Name "Plex"); Lucide `LICENSE` of releases 0.300.0,
  0.460.0, 0.500.0 and 1.56.0 (ISC, with the Feather MIT notice), compared with the lucide-static
  packages of those releases and of 0.263.0 and 0.469.0
