# tools/l10n

Generates `app/lib/l10n/isolated_fallback.g.dart`: the English strings, each wrapped in a
left-to-right isolate, for a right-to-left app language that has no translation yet
([G93](../../docs/DESIGN_GAPS.md#g93), [G20](../../docs/DESIGN_GAPS.md#g20)). Pure Dart; no Flutter
needed to run it.

```sh
cd tools/l10n
dart pub get
dart run l10n           # write app/lib/l10n/isolated_fallback.g.dart (only if it changed)
dart run l10n --check   # write nothing; exit 1 if the file is missing or stale
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

## Self-tests

`dart test` covers the reader (comments, nested block comments, raw, triple-quoted and interpolated
strings), the member parser (getters, methods with typed, optional positional and named parameters,
defaults, trailing commas, annotations, and every rejected form), the emitter, the real gen-l10n
output, determinism, formatting, that the committed file is current, the `app/l10n.yaml` paths, and
the command line (`--check` on a missing, stale and fresh file, a new message, root discovery, exit
codes 2 and 64, `--help`). In the app, `app/test/l10n/isolated_fallback_test.dart` checks
independently that the generated class overrides every message of `AppLocalizations` and every key
of `app_en.arb`, and measures the reading order on screen.
