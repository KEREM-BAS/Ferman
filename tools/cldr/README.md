# tools/cldr

Generates `app/lib/l10n/region_names.dart`: the names of the regions the region setting can show
(a11-1b, [G91](../../docs/DESIGN_GAPS.md#g91)) and their order in its picker, from CLDR through
the ICU that Node.js bundles. No npm packages, no network.

```sh
node regions.mjs           # write the file
node regions.mjs --check   # fail while it is stale (CI)
```

It runs only on **Node.js 24.22.0** (ICU 78.3, CLDR 48), the version `tools/design-refs/.nvmrc`
pins: another version has other names and stops with exit code 2. A CLDR update is a Node.js
update: change the pin, regenerate, and review the diff.

What it reads and writes:

- **Regions:** every two-letter code that `Intl.DisplayNames('en', {type: 'region'})` names, but
  the deprecated ones (those `Intl.Locale('und-XX').maximize()` replaces, such as BU and YU) and
  the groupings and test codes EU, EZ, UN, QO, XA, XB and ZZ.
- **Names:** English, Turkish and Arabic, the long form except the short one for Hong Kong and
  Macao. A region's own name is in its format locale's language for the regions of `Region.all`
  (read from `app/lib/l10n/region.dart`), else in the language its likely subtags give
  (`und-BE` → Dutch, "België").
- **Order:** per language, the name the picker shows (the own name in parentheses when it
  differs) sorted with `Intl.Collator(language)`, then by code.

The output follows `dart format`'s layout, so the formatter leaves it as it is. CLDR data is under
the Unicode License v3 ([DEPENDENCIES.md](../../docs/DEPENDENCIES.md)).
