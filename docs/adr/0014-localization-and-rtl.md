# ADR 0014: Localization and right-to-left support

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §1 and §6
- **Supersedes:** none
- **Superseded by:** none

## Context

Ferman targets 21 UI languages: English (source), Turkish, German, French, Spanish, Portuguese (BR),
Italian, Dutch, Polish, Russian, Ukrainian, Arabic, Persian, Hebrew, Hindi, Japanese, Korean,
Simplified Chinese, Traditional Chinese, Indonesian and Vietnamese, with full right-to-left support for
Arabic, Persian and Hebrew ([brief §1](../BRIEF.md)).

The brief's rules ([brief §6](../BRIEF.md)):

- gen-l10n with ARB files in `app/lib/l10n`. English is the source and Turkish is complete; other
  languages fall back to English until translated. Never machine-translate silently; prepare for
  community translation through Weblate.
- Dart's `toUpperCase` is not locale-aware: implement locale-aware casing so Turkish shows "İMZALA".
- Locale-aware dates, numbers ("10,5 pt"), paper sizes and units.
- RTL: `EdgeInsetsDirectional` and `AlignmentDirectional` everywhere; mirror directional icons; never
  mirror the PDF canvas.
- M1 delivers l10n for en, tr and ar ([brief §7](../BRIEF.md)); goldens run in en, tr and ar
  ([brief §5](../BRIEF.md)).

The design shows a Turkish editor (a12-1tr), full Arabic RTL chrome over an unmirrored Turkish document
(a12-1ar), an Arabic start screen (a12-2a), Arabic and German Settings › Language and region (a12-2c,
a12-2d), German and Japanese editors (a12-1de, a12-1ja), the 21-language picker (a1-1) and the region
settings (a11-1b: region, paper, units, first day of week). Gaps: thin RTL coverage
([G18](../DESIGN_GAPS.md#g18)), thin Turkish coverage and no all-caps Turkish label anywhere
([G19](../DESIGN_GAPS.md#g19)), no translation-status state in the picker ([G20](../DESIGN_GAPS.md#g20)),
undefined page order for right-to-left documents ([G32](../DESIGN_GAPS.md#g32)) and mixed number and
date formats across boards ([G34](../DESIGN_GAPS.md#g34)).

## Decision

### Strings

- Flutter **gen-l10n** with ARB files in `app/lib/l10n/`. `app_en.arb` is the template. Messages use ICU
  plural and select forms; no string is built by concatenation.
- **Turkish is complete** in every milestone. **Arabic** ships from M1 so the right-to-left UI is real
  and tested; its strings are written or reviewed by a person.
- **Other languages fall back to English** message by message. gen-l10n fills missing messages from the
  template and writes an untranslated-messages report, which CI publishes.
- **No silent machine translation.** Machine output may only enter through Weblate as a suggestion that
  a person reviews. A language counts as translated only when a reviewer has approved it.
- **Weblate** hosts community translation, synced with the ARB files through pull requests. Translators
  need no other tool.
- The language picker (a1-1) shows every language by its native name and marks languages that are not
  translated yet ([G20](../DESIGN_GAPS.md#g20)).
- The engine never produces UI text. It returns message keys and parameters
  ([ADR 0010](0010-error-handling-no-panics.md)).

### Locale-aware casing

- A small pure-Dart casing utility in `app/lib/l10n/` applies the language-specific rules of Unicode
  SpecialCasing for Turkish and Azerbaijani (i ↔ İ, ı ↔ I, and the combining dot above), on top of Dart's
  case mapping. "imzala" becomes **"İMZALA"** under Turkish.
- It is pure Dart because casing happens while widgets build (no synchronous engine calls on that path),
  and because widget tests and goldens run without the native library.
- The engine uses ICU4X (`icu_casemap`) for search folding, so "kira" finds "KİRA" and "ı" and "i" are
  handled correctly ([brief §7](../BRIEF.md), M2 search). A test checks the Dart utility against a table
  generated with ICU4X.
- Every uppercase label in the UI goes through the utility. A CI script flags direct `toUpperCase()`
  calls on user-visible strings.

### Numbers, dates, paper and units

- They follow the **region setting** (a11-1b), never the UI language ([G34](../DESIGN_GAPS.md#g34)). With
  the Türkiye region, an English UI shows "13.10.2026 · 14:32", "18.500,50" and "10,5 pt".
- The app keeps two locales: the UI locale (strings, direction, fonts) and the format locale (numbers,
  dates, digit system, paper size, units, first day of week). intl formats with the format locale.
- Paper size defaults (A4 or Letter) and units (mm, in, pt) come from the region and can be changed in
  a11-1b. Number fields accept the region's decimal separator.
- The digit system follows the region (for example Arabic-Indic digits, as drawn in a12-1ar).
- The engine returns raw values (points, bytes, counts, timestamps). Dart formats them.

### Right to left

- `Directionality` comes from the UI locale: right to left for ar, fa and he.
- `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional` and `BorderRadiusDirectional`
  everywhere. A CI script flags `EdgeInsets.only(left: …)`, `Alignment.centerLeft` and similar
  left-or-right APIs in feature code, with a reviewed allow-list.
- **Directional icons mirror** through a per-icon flag ([ADR 0013](0013-fonts-and-icons.md)). Symmetric
  icons never do.
- **The PDF canvas is never mirrored.** Page content, on-page marks and thumbnail contents stay exactly as
  the document defines them. The canvas subtree runs with its own left-to-right geometry.
- **Page order in spreads and book layout follows the document's `/ViewerPreferences/Direction`**
  (`/R2L` puts the first page on the right), never the UI language ([G32](../DESIGN_GAPS.md#g32)).
- Grid and thumbnail reading order (Organize, the start screen) follows the UI direction, but each
  thumbnail's content is not mirrored.
- Mixed-direction values inside RTL text (dates, numbers, IBANs, file names) are isolated with Unicode
  isolates so they read correctly (a12-2c).
- Window chrome follows the design for macOS RTL (a12-1ar). Windows RTL chrome is not drawn and follows
  the platform convention until it is ([G18](../DESIGN_GAPS.md#g18)).
- Text inside documents uses the engine's bidi handling ([ADR 0005](0005-block-scoped-text-editing.md)),
  independent of the UI direction.

### Fonts per script

Script fonts and fallbacks are in [ADR 0013](0013-fonts-and-icons.md). CJK type roles use the design's
taller leading ([ADR 0012](0012-design-token-pipeline.md)).

### Tests

- Goldens for every implemented screen in en, tr and ar, light and dark, with the real fonts
  ([ADR 0017](0017-testing-and-ci.md)).
- Unit tests for casing (İ/ı round trips), region formatting (Türkiye, Germany, United States, Saudi
  Arabia, Iran), paper and unit defaults, and RTL layout of each component.
- A check that every ARB key used in code exists in `app_en.arb` and `app_tr.arb`.

## Consequences

### Positive

- Turkish users get correct casing and number formats from the first release.
- RTL is proven in M1, not retrofitted.
- Community translations can grow without code changes, and nobody ships unreviewed machine output.
- The document is never distorted by the UI language.

### Negative

- Two locales (UI and format) add a concept that every formatting call must respect.
- 19 languages fall back to English until volunteers translate them; the picker must say so honestly.
- RTL chrome for many screens is not drawn yet; we follow the drawn patterns and log the gaps.
- Our own casing utility must stay in step with ICU; the cross-check test guards it.

### Follow-up

- M1: gen-l10n setup, en, tr and ar ARB files, the casing utility, format locale plumbing, RTL shell,
  goldens, the CI checks.
- M2: search folding with ICU4X; spread and book order from `/ViewerPreferences/Direction`.
- After M1: Weblate project setup, documented in [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Alternatives considered

- **Format numbers and dates from the UI language.** Simpler, but wrong for an English UI used in
  Türkiye, and contradicts a11-1b.
- **Call ICU4X through the bridge for casing.** One implementation, but a synchronous FFI call in widget
  builds and no native library in widget tests.
- **Machine-translate missing languages.** Forbidden by the brief when silent; low quality for legal and
  financial vocabulary.
- **Mirror the whole app including the canvas.** Simple to implement, but it would show documents
  backwards. Forbidden by the brief.
- **Spread order from the UI language.** An Arabic UI would show a left-to-right Turkish thesis in the
  wrong order.

## References

- [Brief](../BRIEF.md) §1, §5, §6, §7
- [ARCHITECTURE.md](../ARCHITECTURE.md), section 11
- [ADR 0005](0005-block-scoped-text-editing.md), [ADR 0010](0010-error-handling-no-panics.md),
  [ADR 0012](0012-design-token-pipeline.md), [ADR 0013](0013-fonts-and-icons.md),
  [ADR 0017](0017-testing-and-ci.md)
- Artboards a1-1, a11-1b, a12-1tr, a12-1ar, a12-1de, a12-1ja, a12-2a, a12-2c, a12-2d, a2-1c, a2-1d
- [G18](../DESIGN_GAPS.md#g18), [G19](../DESIGN_GAPS.md#g19), [G20](../DESIGN_GAPS.md#g20),
  [G32](../DESIGN_GAPS.md#g32), [G34](../DESIGN_GAPS.md#g34)
