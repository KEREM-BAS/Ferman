import 'dart:convert';
import 'dart:io';

import 'package:checks/src/check.dart';
import 'package:checks/src/text.dart';

/// Turkish is complete: `app_tr.arb` has exactly the message keys of
/// `app_en.arb`, and none of its values repeats the English one, so English
/// copied in as a stand-in cannot pass for a translation. The few values
/// that are the same in every language (names, symbols, formats) are listed
/// in [sameInTurkish] (by default [repositorySameInTurkish]) with the
/// reason, and an entry that no longer applies fails too. Arabic may be
/// partial, but every key in `app_ar.arb` exists in English. Keys starting
/// with `@` are metadata and not compared. Every message key the engine
/// can return (`MessageKey` in [engineKeysFile]) is a key of `app_en.arb`,
/// so each error has its sentence.
final class ArbParityCheck implements Check {
  /// Creates the check; [sameInTurkish] replaces the repository's list
  /// (tests).
  const new({this.sameInTurkish = repositorySameInTurkish});

  /// The folder of the ARB files, relative to the repository root.
  static const l10nDir = 'app/lib/l10n';

  /// The engine's message keys, each a `Self("…")` constant of
  /// `MessageKey`, relative to the repository root.
  static const engineKeysFile = 'crates/ferman-api/src/facade/error.rs';

  /// The message keys whose Turkish value may equal the English one, each
  /// with the reason.
  final Map<String, String> sameInTurkish;

  /// The repository's keys whose Turkish value is the English one on
  /// purpose, each with the reason. Reviewed like the S6 allowlist: add a
  /// key only when the text is the same in Turkish.
  static const Map<String, String> repositorySameInTurkish = {
    'appName': 'the product name, never translated',
    'shellMoreDocumentsBadge': 'a plus sign and a count ("+3")',
    'shellToolEimza': 'e-imza, the Turkish name of the electronic signature',
    'shellConvertWord': 'a file format named after its product',
    'shellConvertExcel': 'a file format named after its product',
    'shellConvertPowerPoint': 'a file format named after its product',
    'shellConvertHtml': 'a file format',
    'shellConvertMarkdown': 'a file format',
    'regionPaperA4': 'the ISO paper size name',
    'regionPaperLetter': 'the paper size name, used as is in Turkish',
  };

  @override
  String get name => 'arb_parity';

  @override
  CheckResult run(CheckContext context) {
    final en = context.file('$l10nDir/app_en.arb');
    final tr = context.file('$l10nDir/app_tr.arb');
    final ar = context.file('$l10nDir/app_ar.arb');
    for (final file in [en, tr]) {
      if (!file.existsSync()) {
        return CheckResult.skip(
          '${context.relative(file.path)} does not exist yet',
        );
      }
    }

    final problems = <String>[];
    Set<String>? keysOf(File file) {
      try {
        return messageKeys(file.readAsStringSync());
      } on FormatException catch (error) {
        problems.add('${context.relative(file.path)}: ${error.message}');
        return null;
      }
    }

    final enKeys = keysOf(en);
    final trKeys = keysOf(tr);
    final arKeys = ar.existsSync() ? keysOf(ar) : <String>{};
    if (enKeys == null || trKeys == null || arKeys == null) {
      return CheckResult.fail(problems);
    }
    final enValues = messages(en.readAsStringSync());
    final trValues = messages(tr.readAsStringSync());
    String repeated(String key) =>
        'app_tr.arb repeats the English text of $key: translate it, or list '
        'it in ArbParityCheck.repositorySameInTurkish with the reason';
    String listedButGone(String key) =>
        'ArbParityCheck.repositorySameInTurkish lists $key, which app_en.arb '
        'does not have';
    String listedButTranslated(String key) =>
        'ArbParityCheck.repositorySameInTurkish lists $key, whose Turkish now '
        'differs from the English: remove the entry';

    List<String> sorted(Iterable<String> keys) => keys.toList()..sort();
    problems
      ..addAll(
        capped([
          for (final key in sorted(enKeys.difference(trKeys)))
            'app_tr.arb is missing $key',
        ]),
      )
      ..addAll(
        capped([
          for (final key in sorted(trKeys.difference(enKeys)))
            'app_tr.arb has $key, which app_en.arb does not',
        ]),
      )
      ..addAll(
        capped([
          for (final key in sorted(arKeys.difference(enKeys)))
            'app_ar.arb has $key, which app_en.arb does not',
        ]),
      )
      ..addAll(
        capped([
          for (final key in sorted(enKeys.intersection(trKeys)))
            if (trValues[key] == enValues[key] &&
                !sameInTurkish.containsKey(key))
              repeated(key),
        ]),
      )
      ..addAll([
        for (final key in sorted(sameInTurkish.keys))
          if (!enKeys.contains(key))
            listedButGone(key)
          else if (trValues[key] != enValues[key])
            listedButTranslated(key),
      ]);
    final engine = context.file(engineKeysFile);
    if (engine.existsSync()) {
      final keys = RegExp(r'Self\("(\w+)"\)')
          .allMatches(engine.readAsStringSync())
          .map((match) => match[1]!);
      problems.addAll([
        for (final key in sorted(keys.toSet().difference(enKeys)))
          'app_en.arb is missing the engine message $key ($engineKeysFile)',
      ]);
    }
    return CheckResult.from(problems);
  }

  /// The messages of an ARB file: every top-level key not starting with `@`
  /// with its value.
  ///
  /// Throws a [FormatException] when [arb] is not a JSON object.
  static Map<String, Object?> messages(String arb) {
    final json = jsonDecode(arb);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('not a JSON object');
    }
    return {
      for (final entry in json.entries)
        if (!entry.key.startsWith('@')) entry.key: entry.value,
    };
  }

  /// The message keys of an ARB file: every top-level key not starting with
  /// `@`.
  ///
  /// Throws a [FormatException] when [arb] is not a JSON object.
  static Set<String> messageKeys(String arb) {
    final json = jsonDecode(arb);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('not a JSON object');
    }
    return json.keys.where((key) => !key.startsWith('@')).toSet();
  }
}
