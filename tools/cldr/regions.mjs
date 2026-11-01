// Writes app/lib/l10n/region_names.dart from CLDR through Node.js's ICU
// (B092): every territory's English, Turkish and Arabic name, its own name,
// and the region picker's order in each of the three languages. See
// README.md. `--check` compares instead of writing.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const target = join(root, 'app', 'lib', 'l10n', 'region_names.dart');
const regionDart = join(root, 'app', 'lib', 'l10n', 'region.dart');

// The names change with CLDR, so the file says which one made it.
const wanted = { node: '24.22.0', icu: '78.3', cldr: '48.0' };
const have = {
  node: process.versions.node,
  icu: process.versions.icu,
  cldr: process.versions.cldr,
};
if (Object.keys(wanted).some((key) => wanted[key] !== have[key])) {
  console.error(
    `regions.mjs needs Node.js ${wanted.node} (ICU ${wanted.icu}, CLDR ` +
      `${wanted.cldr}); this is ${have.node} (ICU ${have.icu}, CLDR ${have.cldr}).`,
  );
  process.exit(2);
}

/// Groupings and test codes CLDR names but no region is.
const notRegions = new Set(['EU', 'EZ', 'UN', 'QO', 'XA', 'XB', 'ZZ']);
const languages = ['en', 'tr', 'ar'];

// The long names, but Hong Kong's and Macao's short ones: their long forms
// are "Hong Kong SAR China" and "Macao SAR China".
const nameOf = (locale, code) =>
  new Intl.DisplayNames(locale, {
    type: 'region',
    style: code === 'HK' || code === 'MO' ? 'short' : 'long',
    fallback: 'none',
  }).of(code);

// Region.all's format locales: a region's own name is in its language.
const formatLocales = Object.fromEntries(
  [...readFileSync(regionDart, 'utf8').matchAll(/Region\._\('([A-Z]{2})', '([A-Za-z_]+)'\)/g)].map(
    (match) => [match[1], match[2].replace('_', '-')],
  ),
);

const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const names = new Map();
for (const first of letters) {
  for (const second of letters) {
    const code = first + second;
    const en = nameOf('en', code);
    if (notRegions.has(code) || !en || en === code) continue;
    // A deprecated code (BU, YU) maximizes to the region that replaced it.
    const likely = new Intl.Locale(`und-${code}`).maximize();
    if (likely.region !== code) continue;
    const own = nameOf(formatLocales[code] ?? `${likely.language}-${code}`, code);
    names.set(code, { own, en, tr: nameOf('tr', code), ar: nameOf('ar', code) });
  }
}

// The picker's order: the name shown, with the own name in parentheses
// when it differs, by each language's collation.
const order = Object.fromEntries(
  languages.map((language) => {
    const collator = new Intl.Collator(language);
    const shown = (code) => {
      const entry = names.get(code);
      const local = entry[language];
      return local === entry.own ? local : `${local} (${entry.own})`;
    };
    const codes = [...names.keys()].sort(
      (a, b) => collator.compare(shown(a), shown(b)) || (a < b ? -1 : 1),
    );
    return [language, codes];
  }),
);

// A Dart string literal: single quotes, and invisible format characters
// (U+200D in Sri Lanka's own name) as escapes.
const literal = (text) =>
  `'${text
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\$/g, '\\$')
    .replace(/\p{Cf}/gu, (char) => `\\u${char.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')}`)}'`;

// dart format's layout: a record on one line when it fits in 80 columns,
// else one field per line.
const entry = (code, { own, en, tr, ar }) => {
  const fields = [`own: ${literal(own)}`, `en: ${literal(en)}`, `tr: ${literal(tr)}`, `ar: ${literal(ar)}`];
  const line = `  '${code}': (${fields.join(', ')}),`;
  return line.length <= 80 ? line : `  '${code}': (\n${fields.map((field) => `    ${field},`).join('\n')}\n  ),`;
};

const head = `// GENERATED — do not edit; run (cd tools/cldr && node regions.mjs)
//
// From CLDR 48 through ICU 78.3 in Node.js 24.22.0, with the regions and
// format locales of app/lib/l10n/region.dart (tools/cldr/README.md).
// \`node regions.mjs --check\` fails while this file is stale.

/// The names of the regions the region setting can show (a11-1b "Region
/// formats"), and their order in its picker.
///
/// The names are CLDR data, not UI strings: CLDR 48's territory display
/// names, read through ICU 78.3 in Node.js 24.22.0 (the CLDR snapshot of
/// region.dart), with \`Intl.DisplayNames(locale, {type: 'region'})\`: the
/// long form, except the short one for Hong Kong and Macao, whose long
/// forms are "Hong Kong SAR China" and "Macao SAR China". The table holds
/// every territory CLDR names, so a region the operating system reports
/// outside \`Region.all\` has a name too: all two-letter codes but the
/// deprecated ones (those \`Intl.Locale('und-XX').maximize()\` replaces,
/// such as BU and YU) and the groupings and test codes EU, EZ, UN, QO, XA,
/// XB and ZZ. Unicode License v3. Like the date and number formats, they
/// are never translated by hand.
library;

/// The name of the region with the ISO 3166-1 alpha-2 [code] for a UI in
/// [languageCode], as the picker lists it: the name in the UI language,
/// followed by the region's own name in parentheses when that differs
/// (a12-2c draws "تركيا (Türkiye)" in Arabic; English shows "Türkiye" and
/// "Germany (Deutschland)").
///
/// The table has English, Turkish and Arabic names, the translated UI
/// languages; another language gets the English names, as its UI does.
/// A code CLDR does not name gives the code itself.
String regionDisplayName(String code, String languageCode) {
  final names = _regionNames[code.toUpperCase()];
  if (names == null) return code.toUpperCase();
  final local = switch (languageCode) {
    'tr' => names.tr,
    'ar' => names.ar,
    _ => names.en,
  };
  return local == names.own ? local : '$local (\${names.own})';
}

/// Whether [regionDisplayName] has a name for [code].
bool hasRegionName(String code) => _regionNames.containsKey(code.toUpperCase());

/// [codes] in the order of their [regionDisplayName]s for a UI in
/// [languageCode], the alphabetical order of that language: Turkish puts
/// Çekya between Brezilya and Danimarka, Arabic sorts أ, إ and ا as one
/// letter (CLDR 48's collation, \`Intl.Collator(language)\` in Node.js
/// 24.22.0, computed with the names, so the picker sorts without an engine
/// call). Another language takes the English order, as it
/// takes the English names. Codes without a name come last, by code.
List<String> sortRegionCodes(Iterable<String> codes, String languageCode) {
  final ranks = _regionRanks[languageCode] ?? _regionRanks['en']!;
  final unknown = ranks.length;
  int rank(String code) => ranks[code.toUpperCase()] ?? unknown;
  return codes.toList()..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.compareTo(b);
  });
}

/// Each code's place in [_regionOrder], per language.
final Map<String, Map<String, int>> _regionRanks = {
  for (final MapEntry(key: language, value: codes) in _regionOrder.entries)
    language: {for (final (index, code) in codes.indexed) code: index},
};

/// Each region's own name and its English, Turkish and Arabic names. The
/// own name is in the language of the region's format locale
/// (\`Region.formatLocale\`) for the regions of \`Region.all\`, and in the
/// language CLDR's likely subtags give the territory for the others
/// (\`Intl.Locale('und-BE').maximize()\`: Dutch, "België").
const Map<String, ({String own, String en, String tr, String ar})>
_regionNames = {
`;
const output =
  head +
  [...names].map(([code, value]) => entry(code, value)).join('\n') +
  '\n};\n\n/// The codes of [_regionNames] sorted by their [regionDisplayName] in\n' +
  '/// English, Turkish and Arabic, with `Intl.Collator(language).compare`.\n' +
  'const Map<String, List<String>> _regionOrder = {\n' +
  languages
    .map((language) => `  '${language}': [\n${order[language].map((code) => `    '${code}',`).join('\n')}\n  ],`)
    .join('\n') +
  '\n};\n';

if (process.argv.includes('--check')) {
  if (readFileSync(target, 'utf8') !== output) {
    console.error('app/lib/l10n/region_names.dart is stale: run (cd tools/cldr && node regions.mjs)');
    process.exit(1);
  }
  console.log(`region_names.dart is current (${names.size} regions).`);
} else {
  writeFileSync(target, output);
  console.log(`Wrote app/lib/l10n/region_names.dart (${names.size} regions).`);
}
