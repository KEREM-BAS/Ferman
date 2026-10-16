/// Composes CSS filter functions into one colour matrix.
library;

import 'package:tokens/src/errors.dart';
import 'package:tokens/src/values.dart';

/// Composes [functions] into the 5×4 row-major matrix that
/// `ColorFilter.matrix` takes.
///
/// CSS applies the functions left to right, so `brightness(b) contrast(c)
/// sepia(s)` is `S · C · B` on a column vector `[r, g, b, a, 1]`. The
/// matrices are the ones in the Filter Effects specification. The fifth
/// column (the offset) is in Flutter's 0–255 range. The browser clamps to
/// 0–1 between functions; the composed matrix clamps once at the end, which
/// only differs for colours that a step pushes out of range (here, the
/// darkest blacks after `contrast`, which end up at 0 either way).
///
/// Returns null for an empty list (`none`).
List<double>? composeColorMatrix(List<FilterFunction> functions) {
  if (functions.isEmpty) return null;
  var result = _identity();
  for (final function in functions) {
    result = _multiply(_matrixFor(function), result);
  }
  return [
    for (var row = 0; row < 4; row++) ...[
      ...result[row].take(4),
      result[row][4] * 255,
    ],
  ];
}

/// One function as a 5×5 matrix whose offsets are in the 0–1 range.
List<List<double>> _matrixFor(FilterFunction function) {
  final amount = function.amount;
  switch (function.name) {
    case 'brightness':
      return _rgbScale(amount, 0);
    case 'contrast':
      return _rgbScale(amount, 0.5 - 0.5 * amount);
    case 'sepia':
      final k = 1 - amount.clamp(0.0, 1.0);
      return [
        [0.393 + 0.607 * k, 0.769 - 0.769 * k, 0.189 - 0.189 * k, 0, 0],
        [0.349 - 0.349 * k, 0.686 + 0.314 * k, 0.168 - 0.168 * k, 0, 0],
        [0.272 - 0.272 * k, 0.534 - 0.534 * k, 0.131 + 0.869 * k, 0, 0],
        [0, 0, 0, 1, 0],
        [0, 0, 0, 0, 1],
      ];
    default:
      throw TokenException('unsupported filter function ${function.name}()');
  }
}

List<List<double>> _rgbScale(double slope, double offset) => [
  [slope, 0, 0, 0, offset],
  [0, slope, 0, 0, offset],
  [0, 0, slope, 0, offset],
  [0, 0, 0, 1, 0],
  [0, 0, 0, 0, 1],
];

List<List<double>> _identity() => [
  for (var row = 0; row < 5; row++)
    List<double>.generate(5, (column) => column == row ? 1 : 0),
];

List<List<double>> _multiply(List<List<double>> a, List<List<double>> b) => [
  for (var row = 0; row < 5; row++)
    [
      for (var column = 0; column < 5; column++)
        [for (var k = 0; k < 5; k++) a[row][k] * b[k][column]]
            .fold<double>(0, (sum, term) => sum + term),
    ],
];
