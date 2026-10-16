# tools/l10n

Generates `app/lib/l10n/isolated_fallback.g.dart`: the English strings, each wrapped in a
left-to-right isolate, for a right-to-left app language that has no translation yet
([G93](../../docs/DESIGN_GAPS.md#g93), [G20](../../docs/DESIGN_GAPS.md#g20)). A second command
renders the translation table of [docs/TRANSLATION_REVIEW.md](../../docs/TRANSLATION_REVIEW.md) from
the ARB files ([Review table](#review-table)). Pure Dart; no Flutter needed to run either.

```sh
cd tools/l10n
dart pub get
dart run l10n           # write app/lib/l10n/isolated_fallback.g.dart (only if it changed)
dart run l10n --check   # write nothing; exit 1 if the file is missing or stale
dart run l10n:review_table           # render the table in docs/TRANSLATION_REVIEW.md (only if it changed)
dart run l10n:review_table --check   # write nothing; exit 1 if the table is stale
dart test
```

Run it after `flutter gen-l10n` (in `app/`), whenever an ARB message is added, removed or renamed in
`app_en.arb`. Plain `dart run` writes the file too, but `dart run --check` does not work: `dart run`
reads the flag as its own option. `--root <dir>` points at another checkout (`--root ../..` is this
one); by default the repository root is the nearest parent directory that holds `app/l10n.yaml` and
`tools/l10n/`. `--help` lists the options. Exit codes: 0 success (written or already up to date), 1
stale or missing (`--check`), 2 the gen-l10n output is missing or has a member the generator cannot
wrap, 64 bad usage.

## Why

Persian and Hebrew mirror the whole UI at once while their strings fall back to English (G20, G93).
In a right-to-left paragraph an English string's numbers and neutral characters take the paragraph's
direction: "1 of 2" shows as "of 2 1", "Open file…" as "…Open file" and "3 interface languages" as
"interface languages 3". Wrapping each string in U+2066 LEFT-TO-RIGHT ISOLATE … U+2069 POP
DIRECTIONAL ISOLATE keeps its own order, while the paragraph, still right to left, places it at the
start (the right). Placeholder values keep their own direction inside the isolate (a language's own
name in Arabic or Hebrew script reads right to left), and values the app already wraps in
`bidiIsolate` (U+2068 FIRST STRONG ISOLATE) nest inside.

Dart has no reflection in Flutter, so the wrapping class is generated rather than written: it must
override every message, and a hand-written list would fall behind the ARB files.

## Input

`app/lib/l10n/gen/app_localizations.dart`, the gen-l10n output (`output-dir`,
`output-localization-file` and `output-class` in `app/l10n.yaml`; a test checks that the three still
match). A small reader blanks comments and string literals, finds `abstract class AppLocalizations`
and reads its members:

- Skipped: the constructor, static members (`of`, `delegate`, `localizationsDelegates`,
  `supportedLocales`) and fields (`final String localeName`).
- Read: abstract getters `String get name;` and abstract methods `String name(T a, …);` with their
  exact parameter lists, as written: required positional parameters, then optional positional ones
  in `[…]` or named ones in `{…}`, with types (generic and function types included), `required` and
  default values. gen-l10n itself writes only getters and methods with required positional
  parameters.
- Anything else stops the run with exit code 2, naming the member and its line: a member that does
  not return `String`, a concrete member (`=>` or a block body), a setter or operator, a generic
  method, an instance field, an old-style function-typed parameter (`String f(int x)`), `this.` or
  `super.` parameters, or two members with one name. The generator never guesses.

## Output

`app/lib/l10n/isolated_fallback.g.dart`, formatted with the SDK's `dart format` as if it lived at
that path, deterministic (no timestamp), and starting with
`// GENERATED — do not edit; run (cd tools/l10n && dart run l10n)`. It holds:

- `final class IsolatedFallbackLocalizations extends AppLocalizationsEn`, which overrides every
  message as `isolate(super.name)` or `isolate(super.name(a, b: b))`, in source order;
- `static String isolate(String text)`, the wrapping (`'\u2066$text\u2069'`);
- `static const delegate`, a `LocalizationsDelegate<AppLocalizations>` that loads it synchronously
  for English, and `static const localizationsDelegates`: that delegate, then
  `AppLocalizations.localizationsDelegates`.

A message named `isolate`, `delegate`, `localizationsDelegates` or `localeName` would clash with the
class's own members and stops the run.

`FermanApp` (`app/lib/app/app.dart`) passes `IsolatedFallbackLocalizations.localizationsDelegates`
to `MaterialApp.router` while `AppLanguage.isolatesFallbackStrings` holds (right to left and not
translated: Persian and Hebrew today). `Localizations` loads the first delegate of each type that
supports the locale, so it replaces `AppLocalizations.delegate`. English, Turkish and Arabic keep the
gen-l10n classes unchanged.

## Review table

`dart run l10n:review_table` replaces the region between the two `GENERATED TRANSLATION TABLE`
markers of `docs/TRANSLATION_REVIEW.md` with a table rendered from the ARB files in `app/lib/l10n/`
(`arb-dir` and `template-arb-file` in `app/l10n.yaml`; a test checks that they still match); the
prose around the markers is written by hand. Run it whenever an ARB message or the description of
an English message is added, changed or removed. `--check` writes nothing and exits with 1 when the table is stale; CI runs it in the step
"Generated files are current", and the codegen job regenerates it and fails on any diff.

- A line of counts: the messages in `app_en.arb` and how many of them each other language has.
- One row per message of `app_en.arb`, in file order: the key, the English message, the message of
  each other ARB file (Turkish first, then the others by locale code; a language without a name in
  `languageNames` is headed by its code), and the `description` of the English `@key` entry, the
  note for translators. Keys only in a translation are left out (`tools/checks` `arb_parity` and the
  app's ARB tests catch those); `@@locale` and the other metadata are skipped.
- A dash (—) marks a language without a message for the key: the app shows the English one.
- Cells are escaped for GitHub Markdown: a backslash before each of `\`, `|`, `*`, `_`, `` ` ``,
  `[`, `]`, `~` and `$`, the entities `&amp;`, `&lt;` and `&gt;` for `&`, `<` and `>`, and `<br>`
  for a line break, so the syntax characters of a message show as written, ICU syntax included.
  Spaces at the start or end of a cell and runs of spaces collapse, as Markdown renders them.
- The output is deterministic, with LF line endings; a checkout with CRLF line endings reads as
  current.

Exit codes are those of `dart run l10n`: 2 when the document, its markers (each exactly once, the
begin marker first) or `app_en.arb` is missing, or an ARB file is not UTF-8 or not a JSON object of
string messages.

## Self-tests

`dart test` covers the reader (comments, nested block comments, raw, triple-quoted and interpolated
strings), the member parser (getters, methods with typed, optional positional and named parameters,
defaults, trailing commas, annotations, and every rejected form), the emitter, the real gen-l10n
output, determinism, formatting, that the committed file is current, the `app/l10n.yaml` paths, and
the command line (`--check` on a missing, stale and fresh file, a new message, root discovery, exit
codes 2 and 64, `--help`), and the review table (the ARB reader and its errors, row and column
order, missing messages, escaping, the marker region and its errors, that the committed document is
current and has a row for every message, the `app/l10n.yaml` paths, and the command line). In the
app, `app/test/l10n/isolated_fallback_test.dart` checks independently that the generated class
overrides every message of `AppLocalizations` and every key of `app_en.arb`, and measures the
reading order on screen.
