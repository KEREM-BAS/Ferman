# ADR 0006: Font pipeline and the missing-glyph policy

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §3 and §4. The `fsType` detail below, Proposed in M0, was approved by the
  owner on 2026-10-16 ([Q09](../QUESTIONS.md#q09)).
- **Supersedes:** none
- **Superseded by:** none

## Context

Editing text means working with the fonts already inside the PDF, which are often subsets that hold
only the glyphs the original text used. A Turkish contract set in a subset font may have no ‘ğ’, ‘ş’ or
‘İ’, so typing one of them is the first problem a Turkish user meets.

The brief fixes the font stack and the policy:

- ferman-fonts does "font parsing (skrifa/read-fonts), shaping (rustybuzz), subsetting (subsetter),
  system fonts (fontdb), coverage and substitution" ([brief §3](../BRIEF.md)).
- "Missing glyphs (e.g. ğ, ş, İ in a subset font): (1) use the embedded glyph if present; (2) if the
  same font is installed, take the glyph from it, re-subset and embed; (3) otherwise offer similar fonts
  exactly as the design shows. Never substitute silently." ([brief §4](../BRIEF.md))

The design shows step 3 and the settings around it:

- **a3-3a** and **f2**: the warning appears once. The font field shows only an amber border and a
  triangle; the callout "Missing character" says "This font has no ‘ğ’. Ferman will use a similar font
  for this character." and offers **"Choose a font…"** and **"Keep as is"**. On the page the character
  gets an amber wavy underline and the frame tab turns amber.
- **a3-3b**: the picker "Choose a font for this block", with three groups ("EMBEDDED IN THIS DOCUMENT",
  "INSTALLED ON THIS COMPUTER", "SIMILAR FONTS INCLUDED WITH FERMAN"), coverage badges, a Turkish
  preview string, a "Closest match" tag and a scope choice ("Missing characters only" or "Whole block").
  The group titles are uppercase section labels, so the app stores them in sentence case and renders
  them through the locale-aware casing utility ([ADR 0014](0014-localization-and-rtl.md)).
- **a11-1c** (Settings › Editing), "When a font is missing a character": **"Use a similar font and say
  so"** (default), **"Ask each time"**, and **"Keep the original font and mark the character"**.
- Downstream: a font-substitution row in the review list (a3-12), the "Font substituted" toast (a11-6),
  the thumbnail warning badge and its tooltip (f5), and font embedding status in document properties
  (a2-7).

So the design is not silent. It does skip the brief's step 2, which is never drawn, and several states
are missing: the step-2 notice, no font covering the character, a font whose licence forbids embedding,
and the result after substitution ([G36](../DESIGN_GAPS.md#g36), [G37](../DESIGN_GAPS.md#g37)).

## Decision

### Pipeline

| Stage | Library | Notes |
|---|---|---|
| Parse font programs | skrifa and read-fonts | TrueType and CFF/CFF2 outlines and tables. skrifa does not read Type1; a minimal Type1 parser in ferman-fonts reads the built-in encoding and glyph names. Bare CFF programs (FontFile3) are expected to go through read-fonts' CFF support (verified in M2). Type3 glyphs are content-stream procedures, handled by the interpreter. ttf-parser is never a direct dependency. |
| Encodings and CMaps | ferman-fonts | Standard, WinAnsi, MacRoman, MacExpert, PDFDoc, Symbol, ZapfDingbats, `/Differences`, glyph names to Unicode, ToUnicode and embedded CMaps with `usecmap`. Predefined CJK CMaps and glyph-list data are added after their licences are checked. |
| Shape | harfrust ([ADR 0007](0007-harfrust-instead-of-rustybuzz.md), accepted) | Behind one internal `Shaper` trait; nothing outside ferman-fonts names the shaping crate. |
| Subset | subsetter | Builds the new subsets that steps 2 and 3 embed. |
| System fonts | fontdb | Finds installed fonts for steps 2 and 3. |
| Cache | ferman-fonts | Parsed fonts, glyph outlines and shaping results, keyed by a hash of the font program. |

ferman-fonts works on font bytes and knows nothing about PDF objects. ferman-text resolves PDF font
dictionaries into fonts and decides which step applies ([ADR 0003](0003-crate-layout-and-api-boundary.md)).

### The missing-glyph policy

Coverage is checked per **shaped glyph**, not per character, because a subset can hold ‘ب’ in one
joining form and lack another.

1. **The embedded font has the glyph.** Use it. If the program has the glyph but the encoding has no
   code for it (for example `/gbreve` in a WinAnsi font), the edited runs use a new font dictionary that
   adds the code through `/Differences`. The original dictionary is not touched.
2. **The same font is installed.** fontdb looks it up by PostScript name with the subset tag removed,
   then by family and style. It counts as "the same" only if the units per em match and the advance
   widths of the glyphs the document uses agree with the PDF's widths to within 1 unit in 1000. The
   engine builds a new subset from the installed font and embeds it as a new font resource (Type0,
   Identity-H, with a ToUnicode map) used only by the runs that need it. The original subset is not
   modified, so all other text keeps its bytes and its rendering
   ([ADR 0005](0005-block-scoped-text-editing.md)). **The user is told once**, in the same callout as
   a3-3a, for example "Ferman took ‘ğ’ from Garamond Premier Pro on this computer". That state is not
   drawn yet ([G37](../DESIGN_GAPS.md#g37)).
3. **Otherwise, the design's flow.** Candidate fonts are ranked by coverage of the needed glyphs and by
   metrics (x-height, cap height, average width, weight, serif or sans) from the three a3-3b groups.
   What happens next follows the a11-1c setting:
   - **"Use a similar font and say so"** (default): the closest match draws the character, marked once
     as in a3-3a and f2. "Choose a font…" opens a3-3b. "Keep as is" keeps the substitution.
   - **"Ask each time"**: the a3-3b picker opens before anything changes.
   - **"Keep the original font and mark the character"**: the character stays in the original font
     without a glyph and is marked; the warning stays on the thumbnail and in the review list.

**Never silent.** Every substitution, at every step, is recorded in the review list (a3-12) and
announced with the "Font substituted" toast (a11-6) when it happens outside the panel, for example in a
batch of changes. Bold and italic are never synthesised.

The default follows the design; the owner confirmed it on 2026-10-16 ([Q09](../QUESTIONS.md#q09)).
If no font covers the character, the callout says so and the only choices are "Choose a font…" and
"Keep as is" (state to draw, [G37](../DESIGN_GAPS.md#g37)).

### Fonts that restrict embedding

Installed fonts carry embedding permissions in the OS/2 table (`fsType`). Ferman follows them:

| `fsType` | Meaning | What Ferman does |
|---|---|---|
| 0 | Installable | embeds a subset |
| bit 1 (0x0002) | Restricted licence embedding | never embeds; the font is listed with the reason and skipped, and the flow moves to the next option |
| bit 2 (0x0004) | Preview and print | may be embedded for viewing and printing only; the licence expects documents with this font to be opened read-only. Ferman does not use it for new edited text: the font is listed with the reason and skipped, and the flow moves to the next option |
| bit 3 (0x0008) | Editable | embeds a subset |
| bit 8 (0x0100) | No subsetting | embeds the whole font, after checking its size, or skips it with the reason |
| bit 9 (0x0200) | Bitmap embedding only | never embeds outlines; skipped with the reason |

Where bits 1, 2 and 3 are combined, the least restrictive one applies, as the OpenType specification
says.

**Approved by the owner on 2026-10-16** ([Q09](../QUESTIONS.md#q09)): the same restriction applies
to fonts already embedded in the document. When an embedded font program carries an OS/2 table whose
`fsType` allows at most preview and print (bit 1, or bit 2 without bit 3), editing text set in that
font does not reuse the embedded glyphs (step 1). Step 2 applies only if the installed copy allows
embedding under the table above; otherwise the flow goes to step 3, with the reason shown. The rest
of the document stays editable, and text in other fonts is not affected. The rule reads only the
OS/2 table, so programs without one (bare CFF, Type1, Type3) are not restricted by it.

The "embedding forbidden" state is not drawn yet ([G37](../DESIGN_GAPS.md#g37)).

### Fonts Ferman ships for step 3

The a3-3b group "SIMILAR FONTS INCLUDED WITH FERMAN" needs a small set of bundled document fonts
with licences that allow embedding (the board shows Cormorant Garamond and Crimson Pro). The UI fonts
(IBM Plex) qualify. The owner approved Cormorant Garamond and Crimson Pro (OFL-1.1) for this group
on 2026-10-16 ([Q08](../QUESTIONS.md#q08) group 4); they ship from M3 as the unmodified upstream
files with their licences, beside the IBM Plex families ([ADR 0013](0013-fonts-and-icons.md)).

## Consequences

### Positive

- The brief's three steps are implemented in order, and the design's step 3 is used as drawn.
- Other text is never touched: new glyphs come in through new font resources scoped to the edited runs.
- Font licences are respected automatically, and the user is told why a font is not offered.

### Negative

- Each step-2 or step-3 edit adds a font resource. Files grow slightly; "Optimize and clean" removes
  unused ones ([ADR 0008](0008-file-safety-and-saving.md)).
- "The same font" is a heuristic. A false match would change how the new glyph looks. The width check
  keeps this rare, and the step-2 notice names the font so the user can choose another.
- The fontations crates (skrifa, read-fonts) are pre-1.0 and break every few weeks; subsetter still uses
  an older fontations version. We pin exact versions and upgrade the font crates together
  ([DEPENDENCIES.md](../DEPENDENCIES.md)).
- Three design states must still be drawn ([G37](../DESIGN_GAPS.md#g37)). Until then, Ferman uses the
  a3-3a callout pattern with new copy.

### Follow-up

- M2: font parsing, encodings and ToUnicode for viewing, text extraction and search.
- M3: shaping, subsetting, system font lookup, the three steps, the a3-3a and a3-3b UI, the a11-1c
  setting, the review list rows and the pixel-diff cases for each step.

## Alternatives considered

- **Substitute silently with a similar font.** Forbidden by the brief.
- **Modify the embedded subset in place** (add the glyph to the existing font program). Saves a font
  resource, but subsetters renumber glyphs, so every other run using that font would have to be
  re-encoded. That breaks the block-scoped rule.
- **Always ask** (make "Ask each time" the default). Safe, but slower for the common case. The design
  chose "say so" as the default; we follow it, and the owner confirmed it on 2026-10-16.
- **Ignore `fsType`.** Simpler, but it would make Ferman embed fonts their licences forbid.

## References

- [Brief](../BRIEF.md) §3, §4
- [ARCHITECTURE.md](../ARCHITECTURE.md), sections 6.2 to 6.7
- [ADR 0005](0005-block-scoped-text-editing.md), [ADR 0007](0007-harfrust-instead-of-rustybuzz.md),
  [ADR 0008](0008-file-safety-and-saving.md), [ADR 0013](0013-fonts-and-icons.md)
- Artboards a3-3a, a3-3b, a3-12, a11-1c, a11-6, a2-7, f2, f5
- [G36](../DESIGN_GAPS.md#g36), [G37](../DESIGN_GAPS.md#g37), [Q08](../QUESTIONS.md#q08),
  [Q09](../QUESTIONS.md#q09)
- OpenType specification, OS/2 table, `fsType`
