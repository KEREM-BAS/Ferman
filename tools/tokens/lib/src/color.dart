/// CSS colour parsing with one documented alpha rule.
library;

import 'package:tokens/src/errors.dart';
import 'package:tokens/src/text.dart';

final _hex = RegExp(r'^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');
final _function = RegExp(r'^(rgba?)\((.*)\)$', caseSensitive: false);
final _decimal = RegExp(r'^(\d*)(?:\.(\d+))?$');

/// Parses a CSS colour into a 32-bit ARGB integer, or returns null when
/// [value] is not a colour.
///
/// Supports `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb()`/`rgba()` with
/// comma or space syntax, and `transparent`. Alpha follows [alphaByte].
int? parseCssColor(String value) {
  final v = value.trim();
  if (v.toLowerCase() == 'transparent') return 0x00000000;
  final hex = _hex.firstMatch(v);
  if (hex != null) return _parseHex(hex.group(1)!);
  final function = _function.firstMatch(v);
  if (function == null) return null;
  final body = function.group(2)!;
  final List<String> parts;
  if (body.contains(',')) {
    parts = splitTopLevel(body, ',');
  } else {
    final slash = body.split('/');
    if (slash.length > 2) return null;
    parts = [
      ...splitTopLevelWords(slash.first),
      if (slash.length == 2) slash.last.trim(),
    ];
  }
  if (parts.length != 3 && parts.length != 4) return null;
  final rgb = [for (final part in parts.take(3)) _channel(part)];
  if (rgb.contains(null)) return null;
  final alpha = parts.length == 4 ? alphaByte(parts[3]) : 0xFF;
  return alpha << 24 | rgb[0]! << 16 | rgb[1]! << 8 | rgb[2]!;
}

/// Converts a CSS alpha value (`0.07`, `.5`, `70%`) to a byte.
///
/// The rule (ADR 0012): the byte is `alpha × 255` rounded half up, computed
/// exactly on the decimal digits, so `0.70` gives 178.5 → `0xB3` and `0.07`
/// gives 17.85 → `0x12`. Binary floating point would turn 0.70 × 255 into
/// 178.4999… and round it down; `Color.fromRGBO` truncates instead. Throws a
/// [TokenException] for values outside 0–1.
int alphaByte(String value) {
  var text = value.trim();
  var scale = BigInt.one;
  if (text.endsWith('%')) {
    text = text.substring(0, text.length - 1).trim();
    scale = BigInt.from(100);
  }
  final match = _decimal.firstMatch(text);
  if (match == null || text.isEmpty || text == '.') {
    throw TokenException('invalid alpha "$value"');
  }
  final whole = match.group(1)!;
  final fraction = match.group(2) ?? '';
  final numerator = BigInt.parse('${whole.isEmpty ? '0' : whole}$fraction');
  final denominator = BigInt.from(10).pow(fraction.length) * scale;
  if (numerator > denominator) {
    throw TokenException('alpha "$value" is greater than 1');
  }
  // round-half-up(n × 255 / d) = floor((2 × n × 255 + d) / (2 × d))
  final two = BigInt.two;
  return ((two * numerator * BigInt.from(255) + denominator) ~/
          (two * denominator))
      .toInt();
}

int? _channel(String part) {
  final text = part.trim();
  if (text.endsWith('%')) {
    final percent = double.tryParse(text.substring(0, text.length - 1));
    if (percent == null || percent < 0 || percent > 100) return null;
    return (percent * 255 / 100).round();
  }
  final number = int.tryParse(text);
  if (number == null || number < 0 || number > 255) return null;
  return number;
}

int _parseHex(String digits) {
  final expanded = digits.length <= 4
      ? digits.split('').map((d) => '$d$d').join()
      : digits;
  final rgb = int.parse(expanded.substring(0, 6), radix: 16);
  final alpha = expanded.length == 8
      ? int.parse(expanded.substring(6, 8), radix: 16)
      : 0xFF;
  return alpha << 24 | rgb;
}

/// Formats [argb] as an 8-digit upper-case hex literal, `0xAARRGGBB`.
String argbHex(int argb) =>
    '0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';
