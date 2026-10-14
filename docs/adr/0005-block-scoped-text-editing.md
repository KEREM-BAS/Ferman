# ADR 0005: Block-scoped text editing

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §4
- **Supersedes:** none
- **Superseded by:** none

## Context

The core promise is "click any text in any PDF and edit it like a Word document"
([brief §1](../BRIEF.md)). The brief calls this "the hardest part" and says it "must be flawless"
([brief §4](../BRIEF.md)):

- A content-stream interpreter with full graphics and text state, Form XObjects (recursive) and marked
  content.
- All font types (Type1, TrueType, Type3, Type0/CID), encodings (Standard, WinAnsi, MacRoman,
  `/Differences`, Identity-H/V, CMaps), ToUnicode and widths (`/Widths`, `/W`, `/DW`).
- A text model that rebuilds words, lines, paragraphs, alignment and columns from glyph runs.
- "Editing rewrites only the operators of the edited block; every other byte of the page content stays
  identical. Text is re-encoded in the font's own encoding."
- Missing glyphs and overflow follow the design ([ADR 0006](0006-font-pipeline-and-missing-glyphs.md)
  for glyphs).
- Signed documents: warn before editing that the signature will become invalid.
- "Acceptance test for every edit: render before and after with PDFium; the pixel difference outside
  the edited region must be exactly zero. Cover Turkish, Arabic (RTL shaping) and CJK cases."

The design draws the experience: hover shows one block's frame (a3-1a); the second click places a caret
and text reflows inside the original frame with the original font and justification (a3-1b); the frame
label never covers content (f1); edited lines get a dotted underline and a margin bar that are never
saved (f3); the review list shows every change (a3-12); overflow offers "Extend block", "Tighten spacing
slightly" and "Keep and warn" (a3-4); vertical Japanese text is edited in place (a3-15); the Arabic UI
edits a Turkish document without mirroring it (a12-1ar).

Gaps found in the design are recorded and decided in DESIGN_GAPS.md: no signed-document warning
([G35](../DESIGN_GAPS.md#g35)), overflow results not drawn ([G38](../DESIGN_GAPS.md#g38)), no states for
text that cannot be edited ([G39](../DESIGN_GAPS.md#g39)), review list states
([G42](../DESIGN_GAPS.md#g42)), and overflow wording that drifts in later boards
([G54](../DESIGN_GAPS.md#g54)).

## Decision

### What a block is

A **block** is a paragraph-level unit from the text model (a paragraph, heading, list item or table
cell). Internally it is the set of **operator spans** that draw its glyphs: for each span, the content
stream object and the byte range of the operators, including the state-setting operators inside the
block. The interpreter in ferman-core records a span for every operator, including spans that cross
stream boundaries when `/Contents` is an array.

### The edit

1. **Begin.** `begin_edit` captures the block's spans and the complete graphics and text state at the
   block's start and at its end: text matrix, line matrix, `Tf`, `Tc`, `Tw`, `Tz`, `TL`, `Ts`, `Tr`,
   colour and `q` depth. It refuses blocks that are not editable, with a reason the UI shows
   ([G39](../DESIGN_GAPS.md#g39)). For a signed document it asks for confirmation first (below).
2. **Layout.** ferman-text applies the change to the block's logical text, breaks lines inside the
   frame (UAX #14, with kinsoku rules for CJK) and keeps the block's alignment and justification method
   (`Tw` or `TJ` adjustments). Lines before the first change keep their original operator bytes when
   their layout does not change.
3. **Shape and re-encode.** Complex scripts are shaped first (Arabic joining forms, marks, ligatures;
   shaper per [ADR 0007](0007-harfrust-instead-of-rustybuzz.md)). Every character or shaped glyph
   becomes a code **in the font's own encoding**: the reverse of the effective simple-font encoding
   (base encoding plus `/Differences`), or the reverse CMap plus `/CIDToGIDMap` for Type0 fonts, using the
   ToUnicode map to find codes in subset fonts that have no cmap. Anything without a code goes to the
   missing-glyph steps in [ADR 0006](0006-font-pipeline-and-missing-glyphs.md). We never change a font
   dictionary or font program that other text shares; when a new code or glyph is needed, the edited
   runs use a new font resource of their own.
4. **Generate operators.** The replacement starts from the state the block started with and positions
   lines relative to the original line origins. `TJ` carries kerning and justification (`Tw` applies
   only to the single-byte code 32). Numbers are written with fixed, deterministic precision.
5. **Keep the state invariant.** After the replacement, every piece of state that later operators can
   observe must equal what the original block left behind. The generator ends with explicit operators
   that restore it (for example a final `Tm` with the original end matrix). Otherwise a following `Td`,
   which is relative to the line matrix, would move text outside the block.
6. **Interleaved blocks.** When a block's operators are interleaved with other blocks' operators, all
   new text goes into the block's first span. Its other spans are replaced with only the state-setting
   operators needed to keep the invariant.
7. **Splice.** ferman-core replaces exactly the block's byte spans in the **decoded** content stream.
   Every other decoded byte stays identical. The stream is re-encoded with its original filter where
   Ferman can encode it, otherwise with Flate. Compressed bytes necessarily change; decoded bytes
   outside the spans do not.
8. **Revision.** The new stream is a new version of the same object, kept in the revision overlay. If
   the stream is shared with other pages, it becomes a new object and only this page's `/Contents`
   changes. Text inside a Form XObject used in several places gets a copy of that XObject for the
   edited placement (copy-on-write); its `Do` operator belongs to the block, so the page's other bytes
   stay identical.
9. **Commit and undo.** `commit` makes the change a revision on the engine's undo stack; `rollback`
   discards it. Undo and redo move between revisions ([ADR 0003](0003-crate-layout-and-api-boundary.md)).
10. **Save.** All revisions since the last save become **one incremental update** appended to the file
    ([ADR 0008](0008-file-safety-and-saving.md)). The original bytes stay an exact prefix of the saved
    file.

### Overflow

The design's three choices, with the brief's labels everywhere ([G54](../DESIGN_GAPS.md#g54)):
**Extend block** (grows the frame; disabled with a reason if it would overlap other content),
**Tighten spacing slightly** (within a small cap; disabled with a reason if it is not enough), and
**Keep and warn** (no text is lost; lines that do not fit are clipped to the frame and the warning stays
in the review list and on the thumbnail). Result states are recorded in [G38](../DESIGN_GAPS.md#g38).

### Signed documents

ferman-core detects signatures and certification (DocMDP) at open. Before the first change to a signed
document, `begin_edit` returns "needs confirmation" with the signatures it would invalidate, and the UI
warns that they will become invalid. Without the confirmation the engine refuses to commit. The dialog
is proposed in [G35](../DESIGN_GAPS.md#g35). Incremental saving keeps the signed bytes intact, so the
signed revision still verifies, but validators will report changes after signing.

### Acceptance test for every edit

Every edit case in the test suite runs this check, through the facade or `ferman verify-edit`
([ADR 0017](0017-testing-and-ci.md)):

1. Render the page before the edit with PDFium at 72, 150 and 300 dpi, with fixed render flags.
2. Apply the edit, save incrementally to a temp file, reopen it **from disk** and render again.
3. The **edited region** is the union of the block's bounding box before and after the edit (including
   an extended frame), in device pixels after page rotation. It is computed from the engine's geometry
   before the diff, never from the diff itself. A margin of 2 device pixels for anti-aliasing is
   proposed and documented in the test.
4. Assert **zero** differing pixels outside the region, at every resolution. Also assert that every
   other page renders identically, that decoded content bytes outside the block's spans are identical,
   that every other object is byte-identical, and that the original file is an exact prefix.
5. Required coverage: Turkish (ğ, ş, İ, ı in WinAnsi with `/Differences`, subset TrueType, Identity-H),
   Arabic with RTL shaping (joining forms, lam-alef, marks, isolated numbers and IBANs), Persian with
   ZWNJ, CJK (Identity-H and Identity-V, vertical text as in a3-15), every font type, justified text,
   `TJ` kerning, multi-column pages, rotated pages and rotated text, Form XObjects, marked content with
   `/ActualText`, every missing-glyph step and every overflow choice.

## Consequences

### Positive

- Edits are surgical. Nothing outside the edited block can change, and the tests prove it on every
  case.
- Incremental saving keeps signatures over their original bytes and makes saves fast.
- The text stays real text: searchable, selectable and extractable, with an updated ToUnicode map.
- One code path for the app and the CLI, so every edit case is testable without the UI.

### Negative

- This is the most complex part of the engine. The interpreter, the text model and the state invariant
  all have to be right for the long tail of producers. Blocks we cannot handle safely are refused with
  a reason rather than edited badly.
- New font resources for edited runs make the file grow a little with each font change. "Optimize and
  clean" removes what is no longer used ([ADR 0008](0008-file-safety-and-saving.md)).
- Old text remains inside the file after an incremental save. That is how incremental updates work;
  "Remove hidden information" (P2) and full rewrites remove it, and the design already says so (a8-3).
- The pixel-diff harness depends on deterministic PDFium output. Render flags and the PDFium version are
  pinned ([ADR 0004](0004-lopdf-model-pdfium-renderer.md)).

### Follow-up

- M2: the interpreter, fonts and text model for viewing, search and hit testing.
- M3: editing, re-encoding, splicing, overflow, missing glyphs, the signed-document warning, the review
  list, the incremental writer and the full acceptance suite.

## Alternatives considered

- **Regenerate the page's whole content stream from a parsed model.** What most editors (and PDFium's
  editing functions) do. It changes bytes far outside the edit and risks subtle rendering changes. It
  breaks the brief's rule.
- **White-out and overlay.** Cover the old text and draw new text on top. The old text stays in the file
  and in search results, which is a privacy problem, and it fails the pixel test wherever the background
  is not plain white.
- **Convert to an editable format and back.** Lossy for layout, fonts and structure.
- **Edit by re-encoding the whole text object (`BT` to `ET`).** Simpler, but one text object often holds
  several visual blocks, so it would rewrite text the user did not touch.

## References

- [Brief](../BRIEF.md) §1, §3, §4, §5
- [ARCHITECTURE.md](../ARCHITECTURE.md), sections 5.4 and 6, and 13.4 (pixel-diff harness)
- [ADR 0003](0003-crate-layout-and-api-boundary.md), [ADR 0004](0004-lopdf-model-pdfium-renderer.md),
  [ADR 0006](0006-font-pipeline-and-missing-glyphs.md), [ADR 0007](0007-harfrust-instead-of-rustybuzz.md),
  [ADR 0008](0008-file-safety-and-saving.md), [ADR 0017](0017-testing-and-ci.md)
- Artboards a3-1a, a3-1b, a3-4, a3-12, a3-15, a12-1ar, f1, f3, f4a, f4b
- [G35](../DESIGN_GAPS.md#g35), [G38](../DESIGN_GAPS.md#g38), [G39](../DESIGN_GAPS.md#g39),
  [G42](../DESIGN_GAPS.md#g42), [G54](../DESIGN_GAPS.md#g54)
