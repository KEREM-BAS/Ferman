import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

void main() {
  group('alphaByte rounds alpha × 255 half up, exactly', () {
    for (final (alpha, byte) in [
      ('0', 0x00),
      ('1', 0xFF),
      ('0.06', 0x0F), // 15.3
      ('0.07', 0x12), // 17.85; Color.fromRGBO truncates to 0x11
      ('0.08', 0x14), // 20.4
      ('0.10', 0x1A), // 25.5 rounds up
      ('0.5', 0x80), // 127.5 rounds up
      ('.5', 0x80),
      ('0.70', 0xB3), // 178.5; binary floating point would give 0xB2
      ('70%', 0xB3),
      ('0.38', 0x61), // 96.9
    ]) {
      test('$alpha → 0x${byte.toRadixString(16)}', () {
        expect(alphaByte(alpha), byte);
      });
    }

    test('rejects values outside 0–1', () {
      expect(() => alphaByte('1.2'), throwsA(isA<TokenException>()));
      expect(() => alphaByte('abc'), throwsA(isA<TokenException>()));
    });
  });

  group('parseCssColor', () {
    test('hex forms', () {
      expect(parseCssColor('#2A4DAF'), 0xFF2A4DAF);
      expect(parseCssColor('#fff'), 0xFFFFFFFF);
      expect(parseCssColor('#11223344'), 0x44112233);
    });

    test('rgb and rgba, comma and space syntax', () {
      expect(parseCssColor('rgba(255, 159, 28, 0.70)'), 0xB3FF9F1C);
      expect(parseCssColor('rgb(1, 2, 3)'), 0xFF010203);
      expect(parseCssColor('rgb(1 2 3 / 50%)'), 0x80010203);
    });

    test('transparent', () {
      expect(parseCssColor('transparent'), 0x00000000);
    });

    test('returns null for non-colours', () {
      expect(parseCssColor('12px'), isNull);
      expect(parseCssColor('rgba(300, 0, 0, 1)'), isNull);
      expect(parseCssColor('#12345'), isNull);
    });

    test('argbHex pads and upper-cases', () {
      expect(argbHex(0x0F1F1D1A), '0x0F1F1D1A');
    });
  });
}
