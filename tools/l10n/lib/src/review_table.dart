/// Renders the translation table of docs/TRANSLATION_REVIEW.md from the ARB
/// files.
///
/// The prose of the document (what the review is, how to send corrections)
/// is written by hand; only the region between [reviewBeginMarker] and
/// [reviewEndMarker] is rendered here, so the table and the ARB files cannot
/// drift apart.
library;

import 'dart:convert';
import 'dart:io';

import 'package:l10n/src/errors.dart';
import 'package:path/path.dart' as p;

/// The ARB files' directory, relative to the repository root (`arb-dir` in
/// `app/l10n.yaml`, which is relative to `app/`).
const String arbDirectory = 'app/lib/l10n';

/// The source-language ARB file in [arbDirectory] (`template-arb-file`).
const String templateArbFile = 'app_en.arb';

/// The review document, relative to the repository root.
const String reviewDocPath = 'docs/TRANSLATION_REVIEW.md';

/// Opens the rendered region of [reviewDocPath].
const String reviewBeginMarker =
    '<!-- BEGIN GENERATED TRANSLATION TABLE: tools/l10n, '
    'dart run l10n:review_table -->';

/// Closes the rendered region of [reviewDocPath].
const String reviewEndMarker = '<!-- END GENERATED TRANSLATION TABLE -->';

/// The English names of the languages with an ARB file, for the column
/// headings; a language missing here is headed by its locale code.
const Map<String, String> languageNames = {
  'en': 'English',
  'tr': 'Turkish',
  'ar': 'Arabic',
};

/// Shown in a cell whose language has no message for the key (the app shows
/// the English one).
const String missingCell = '—';

final RegExp _arbName = RegExp(r'^app_(.+)\.arb$');

/// The messages of one ARB file, in file order.
final class ArbFile {
  /// Creates the contents of the ARB file for [locale].
  new(this.locale, this.messages, this.descriptions);

  /// The locale in the file name: `tr` for `app_tr.arb`.
  final String locale;

  /// Every message, by key, in file order; metadata (`@key`, `@@locale`) is
  /// left out.
  final Map<String, String> messages;

  /// The `description` of each `@key` entry that has one, by key.
  final Map<String, String> descriptions;
}

/// Decodes the ARB file [name] holding [json] for [locale].
ArbFile parseArb(String locale, String json, {required String name}) {
  final Object? data;
  try {
    data = jsonDecode(json);
  } on FormatException catch (error) {
    throw L10nException('$name is not valid JSON: ${error.message}');
  }
  if (data is! Map<String, Object?>) {
    throw L10nException('$name must hold a JSON object.');
  }
  final messages = <String, String>{};
  final descriptions = <String, String>{};
  for (final MapEntry(:key, :value) in data.entries) {
    if (key.startsWith('@@')) continue;
    if (key.startsWith('@')) {
      if (value case {'description': final String description}) {
        descriptions[key.substring(1)] = description;
      }
      continue;
    }
    if (value is! String) {
      throw L10nException(
        '$name: the message $key is ${jsonEncode(value)}, not a string.',
      );
    }
    messages[key] = value;
  }
  return ArbFile(locale, messages, descriptions);
}

/// Reads every `app_<locale>.arb` in [arbDirectory] under [root]: English
/// first, then Turkish, then the others by locale code.
List<ArbFile> loadArbFiles(String root) {
  final directory = Directory(p.joinAll([root, ...arbDirectory.split('/')]));
  final template = File(p.join(directory.path, templateArbFile));
  if (!template.existsSync()) {
    throw L10nException('$arbDirectory/$templateArbFile is missing.');
  }
  final files = <ArbFile>[];
  for (final entity in directory.listSync()) {
    final name = p.basename(entity.path);
    final match = _arbName.firstMatch(name);
    if (entity is! File || match == null) continue;
    files.add(
      parseArb(
        match.group(1)!,
        _readText(entity, '$arbDirectory/$name'),
        name: '$arbDirectory/$name',
      ),
    );
  }
  int rank(String locale) => switch (locale) {
    'en' => 0,
    'tr' => 1,
    _ => 2,
  };
  return files..sort(
    (a, b) => rank(a.locale) != rank(b.locale)
        ? rank(a.locale) - rank(b.locale)
        : a.locale.compareTo(b.locale),
  );
}

/// Renders the table for [files], whose first entry is English: a line of
/// counts, then one row per English message in file order, with every
/// language and the English description for translators.
String renderReviewTable(List<ArbFile> files) {
  if (files.isEmpty || files.first.locale != 'en') {
    throw L10nException('$arbDirectory/$templateArbFile is missing.');
  }
  final english = files.first;
  final translations = files.skip(1).toList();
  final keys = english.messages.keys.toList();
  String heading(ArbFile file) => languageNames[file.locale] ?? file.locale;
  final counts = [
    for (final file in translations)
      '${heading(file)} ${keys.where(file.messages.containsKey).length}',
  ];
  final out = StringBuffer()
    ..writeln(
      '${keys.length} messages in `$templateArbFile`'
      '${counts.isEmpty ? '' : '; translated: ${counts.join(', ')}'}.',
    )
    ..writeln()
    ..writeln(
      '| Key | ${[for (final file in files) heading(file)].join(' | ')} '
      '| Context |',
    )
    ..writeln('|---|${'---|' * files.length}---|');
  for (final key in keys) {
    final cells = [
      '`$key`',
      for (final file in files)
        switch (file.messages[key]) {
          final String message => markdownCell(message),
          null => missingCell,
        },
      markdownCell(english.descriptions[key] ?? ''),
    ];
    out.writeln('| ${cells.join(' | ')} |');
  }
  return out.toString();
}

/// Returns [text] safe to stand in one cell of a GitHub Markdown table: the
/// characters Markdown would read as syntax (emphasis, links, code, math,
/// HTML, the cell separator) are escaped, and line breaks become `<br>`.
String markdownCell(String text) {
  final out = StringBuffer();
  for (final char in _normalizeNewlines(text).split('')) {
    out.write(switch (char) {
      r'\' ||
      '|' ||
      '*' ||
      '_' ||
      '`' ||
      '[' ||
      ']' ||
      '~' ||
      r'$' => '\\$char',
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '\n' => '<br>',
      _ => char,
    });
  }
  return out.toString();
}

/// Returns [doc] with the region between [reviewBeginMarker] and
/// [reviewEndMarker] replaced by [table]; the text around it is kept as it
/// is.
String replaceReviewRegion(String doc, String table) {
  final begin = doc.indexOf(reviewBeginMarker);
  final end = doc.indexOf(reviewEndMarker);
  if (begin < 0 || end < 0) {
    throw L10nException(
      '$reviewDocPath needs the markers "$reviewBeginMarker" and '
      '"$reviewEndMarker".',
    );
  }
  if (doc.indexOf(reviewBeginMarker, begin + 1) >= 0 ||
      doc.indexOf(reviewEndMarker, end + 1) >= 0) {
    throw L10nException('$reviewDocPath has a marker more than once.');
  }
  if (end < begin) {
    throw L10nException(
      '$reviewDocPath has "$reviewEndMarker" before "$reviewBeginMarker".',
    );
  }
  return '${doc.substring(0, begin + reviewBeginMarker.length)}\n\n'
      '$table\n'
      '${doc.substring(end)}';
}

/// Returns the contents [reviewDocPath] under [root] should have.
String generateReviewDoc(String root) {
  final doc = File(p.joinAll([root, ...reviewDocPath.split('/')]));
  if (!doc.existsSync()) throw L10nException('$reviewDocPath is missing.');
  return replaceReviewRegion(
    _readText(doc, reviewDocPath),
    renderReviewTable(loadArbFiles(root)),
  );
}

/// The text of [file], named [name] in errors, with its line breaks
/// normalized.
String _readText(File file, String name) {
  try {
    return _normalizeNewlines(file.readAsStringSync());
  } on FileSystemException catch (error) {
    throw L10nException('$name cannot be read as UTF-8: ${error.message}');
  }
}

/// [text] with every `\r\n` or lone `\r` turned into `\n`, so a Windows
/// checkout gives the same result.
String _normalizeNewlines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
