import 'dart:convert';
import 'dart:io';

import 'package:checks/src/check.dart';
import 'package:checks/src/text.dart';

/// Turkish is complete: `app_tr.arb` has exactly the message keys of
/// `app_en.arb`. Arabic may be partial, but every key in `app_ar.arb` exists
/// in English. Keys starting with `@` are metadata and not compared.
final class ArbParityCheck implements Check {
  /// Creates the check.
  const new();

  /// The folder of the ARB files, relative to the repository root.
  static const l10nDir = 'app/lib/l10n';

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
      );
    return CheckResult.from(problems);
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
