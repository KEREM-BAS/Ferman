import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

import 'support.dart';

void main() {
  group('hatchExpression', () {
    test('maps hard stops to stripes', () {
      expect(
        compact(
          hatchExpression(
            'repeating-linear-gradient(to bottom, #D6D2CB 0 2px, '
            'transparent 2px 6px)',
            name: 'thumb-lines',
          ),
        ),
        'FermanHatch(angle:180,stripes:<FermanHatchStripe>['
        'FermanHatchStripe(color:Color(0xFFD6D2CB),width:2),'
        'FermanHatchStripe(color:Color(0x00000000),width:4)])',
      );
    });

    test('rejects gaps between stops', () {
      expect(
        () => hatchExpression(
          'repeating-linear-gradient(45deg, #000 0 2px, #fff 3px 6px)',
          name: 'gap',
        ),
        throwsA(isA<TokenException>()),
      );
    });

    test('rejects single-position stops', () {
      expect(
        () => hatchExpression(
          'repeating-linear-gradient(45deg, #000 2px, #fff 6px)',
          name: 'single',
        ),
        throwsA(isA<TokenException>()),
      );
    });
  });

  group('Supplement.load', () {
    test('reads the committed supplement and checks its citations', () {
      final supplement = Supplement.load(repoRoot);
      expect(supplement.hatches.map((h) => h.name), [
        'redact-pending',
        'thumb-lines',
      ]);
    });

    test('fails when a cited line no longer holds the CSS', () {
      final root = copyGeneratorInputs();
      addTearDown(() => root.deleteSync(recursive: true));
      final hatch = Supplement.load(root.path).hatches.first;
      final cited = File(
        p.joinAll([root.path, ...hatch.source.split(':').first.split('/')]),
      );
      cited.writeAsStringSync('\n${cited.readAsStringSync()}');
      expect(
        () => Supplement.load(root.path),
        throwsA(
          isA<TokenException>().having(
            (e) => e.message,
            'message',
            contains('no longer matches'),
          ),
        ),
      );
    });
  });
}
