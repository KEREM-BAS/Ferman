/// Small text helpers for the regular subset of CSS the tokens use.
library;

/// Collapses runs of whitespace outside quoted strings into one space and
/// trims the result. Quoted strings are copied unchanged.
String collapseWhitespace(String value) {
  final out = StringBuffer();
  var pendingSpace = false;
  String? quote;
  for (var i = 0; i < value.length; i++) {
    final c = value[i];
    if (quote != null) {
      out.write(c);
      if (c == r'\' && i + 1 < value.length) {
        out.write(value[++i]);
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (_isSpace(c)) {
      pendingSpace = out.isNotEmpty;
      continue;
    }
    if (pendingSpace) {
      out.write(' ');
      pendingSpace = false;
    }
    if (c == '"' || c == "'") quote = c;
    out.write(c);
  }
  return out.toString();
}

/// Splits [value] at every [separator] that is outside parentheses,
/// brackets and quoted strings. Parts are trimmed; empty parts are kept so
/// callers can reject them.
List<String> splitTopLevel(String value, String separator) {
  final parts = <String>[];
  var depth = 0;
  String? quote;
  var start = 0;
  for (var i = 0; i < value.length; i++) {
    final c = value[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    switch (c) {
      case '"' || "'":
        quote = c;
      case '(' || '[':
        depth++;
      case ')' || ']':
        depth--;
      default:
        if (depth == 0 && c == separator) {
          parts.add(value.substring(start, i).trim());
          start = i + 1;
        }
    }
  }
  parts.add(value.substring(start).trim());
  return parts;
}

/// Splits [value] at top-level whitespace (outside parentheses and quotes).
List<String> splitTopLevelWords(String value) => splitTopLevel(
  collapseWhitespace(value),
  ' ',
).where((part) => part.isNotEmpty).toList();

/// Returns the index of the parenthesis that closes the one at [open], or
/// -1 when it is not closed.
int matchingParen(String value, int open) {
  var depth = 0;
  String? quote;
  for (var i = open; i < value.length; i++) {
    final c = value[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '"' || c == "'") {
      quote = c;
    } else if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Removes one pair of matching outer quotes from [value], if present.
String unquote(String value) {
  if (value.length >= 2 &&
      (value.startsWith('"') && value.endsWith('"') ||
          value.startsWith("'") && value.endsWith("'"))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';
