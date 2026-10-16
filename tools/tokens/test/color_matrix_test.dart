import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

void main() {
  group('composeColorMatrix', () {
    test('none is no filter', () {
      expect(composeColorMatrix(const []), isNull);
    });

    test('brightness scales RGB', () {
      final matrix = composeColorMatrix(const [
        FilterFunction('brightness', 0.86),
      ])!;
      expect(matrix, hasLength(20));
      expect(matrix[0], closeTo(0.86, 1e-12));
      expect(matrix[6], closeTo(0.86, 1e-12));
      expect(matrix[12], closeTo(0.86, 1e-12));
      expect(matrix[4], 0);
    });

    test('contrast offsets in the 0–255 range', () {
      final matrix = composeColorMatrix(const [
        FilterFunction('contrast', 1.04),
      ])!;
      expect(matrix[0], closeTo(1.04, 1e-12));
      // (0.5 - 0.5 × 1.04) × 255
      expect(matrix[4], closeTo(-5.1, 1e-9));
    });

    test('sepia(0) is the identity', () {
      final matrix = composeColorMatrix(const [FilterFunction('sepia', 0)])!;
      expect(matrix, [
        for (var row = 0; row < 4; row++)
          for (var column = 0; column < 5; column++)
            closeTo(row == column ? 1 : 0, 1e-12),
      ]);
    });

    test('the dim page filter composes left to right', () {
      final matrix = composeColorMatrix(const [
        FilterFunction('brightness', 0.86),
        FilterFunction('contrast', 1.04),
        FilterFunction('sepia', 0.06),
      ])!;
      // R' = sepia row 1 · (0.8944 × RGB − 0.02)
      expect(matrix[0], closeTo((0.393 + 0.607 * 0.94) * 0.8944, 1e-9));
      expect(matrix[1], closeTo(0.769 * 0.06 * 0.8944, 1e-9));
      expect(matrix[4], closeTo(-5.2074, 1e-4));
      expect(matrix.sublist(15), [0, 0, 0, 1, 0]);
    });
  });
}
