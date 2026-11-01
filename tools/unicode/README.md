# tools/unicode

Generates the Unicode tables of `app/lib/l10n/casing.dart` (`LocaleCasing`, ADR 0014): the part
between `// dart format off` and `// dart format on`. The rest of the file is hand-written.

```sh
bash fetch.sh                       # UCD 15.0.0 files → build/unicode/15.0.0/ (SHA-256 pinned)
dart run bin/casing.dart            # write the tables
dart run bin/casing.dart --check    # fail while they are stale (CI)
```

It reads four files of the Unicode Character Database 15.0.0: SpecialCasing.txt,
UnicodeData.txt, PropList.txt and DerivedCoreProperties.txt. `fetch.sh` downloads them from
unicode.org and checks each SHA-256; they stay in `build/`, never committed. It runs only on
Dart 3.13.5 (Flutter 3.47.7), because one table lists what that VM's `toUpperCase` and
`toLowerCase` leave out: another SDK stops with exit code 2.

The tables:

- `_fullMappings`: the unconditional entries of SpecialCasing.txt, by code point.
- `_deltas`: the simple mappings of UnicodeData.txt the Dart VM does not apply, as runs with one
  offset, or alternating upper and lower case from an upper-case code point.
- `_softDotted` and `_cased`: Soft_Dotted and Cased, complete, as inversion lists.
- `_caseIgnorable`: Case_Ignorable in the blocks next to Latin, Greek and Cyrillic letters.
- `_marksAbove` and `_marksOther`: canonical combining class 230, and every other nonzero class,
  in the combining-mark blocks.

A Unicode update changes `version` and the pins in `fetch.sh`, and the docs of `casing.dart` that
name 15.0; `app/test/l10n/casing_test.dart` and `casing_icu_test.dart` then show what changed.
Unicode data is under the Unicode License v3 ([DEPENDENCIES.md](../../docs/DEPENDENCIES.md)).
