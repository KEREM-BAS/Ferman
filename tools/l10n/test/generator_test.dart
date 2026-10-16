import 'dart:io';

import 'package:l10n/l10n.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('generateIsolatedFallback', () {
    late String first;

    setUpAll(() async {
      first = await generateIsolatedFallback(repoRoot);
    });

    test('is deterministic: two runs are byte-identical', () async {
      expect(await generateIsolatedFallback(repoRoot), first);
    });

    test('starts with the generated header and has no timestamp', () {
      expect(first.split('\n').first, generatedHeader);
      expect(first, isNot(matches(RegExp(r'\b20\d\d-\d\d-\d\d'))));
    });

    test('is already formatted', () async {
      final formatted = await formatDart(
        first,
        stdinName: p.join(repoRoot, outputPath),
      );
      expect(formatted, first);
    });

    test('overrides every message once', () {
      final messages = loadMessages(repoRoot);
      for (final message in messages) {
        expect(
          RegExp('String (get )?${RegExp.escape(message.name)}\\b')
              .allMatches(first),
          hasLength(1),
          reason: message.name,
        );
      }
      // The messages plus the delegate's three.
      expect('@override'.allMatches(first), hasLength(messages.length + 3));
    });

    test('matches the committed app/lib/l10n/isolated_fallback.g.dart', () {
      final committed = File(p.join(repoRoot, outputPath));
      expect(
        committed.existsSync() && committed.readAsStringSync() == first,
        isTrue,
        reason: '$outputPath is stale or missing; run $writeCommand',
      );
    });

    test('reads where app/l10n.yaml tells gen-l10n to write', () {
      final config = File(p.join(repoRoot, 'app', 'l10n.yaml'))
          .readAsLinesSync()
          .where((line) => line.contains(':'))
          .map((line) => line.split(':').map((part) => part.trim()).toList())
          .fold(<String, String>{}, (map, kv) => map..[kv[0]] = kv[1]);
      expect(
        'app/${config['output-dir']}/${config['output-localization-file']}',
        inputPath,
      );
      expect(config['output-class'], localizationsClass);
      expect(config['template-arb-file'], 'app_en.arb');
    });
  });
}
