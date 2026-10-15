/// Writes icon SVG files and compares icon geometry.
library;

import 'package:icons/src/errors.dart';

/// The root element every generated icon file opens with: the 24 × 24 grid,
/// no fill, a `currentColor` stroke 1.5 wide with round caps and joins, as
/// the design system's Icon component draws it ([ADR 0013]).
///
/// The `stroke-width="1.5"` attribute occurs exactly once per file, so a
/// viewer that needs another width (badges draw at 2) can replace it. The
/// app itself paints from the generated element data, not from these
/// files.
const String svgOpenTag =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" '
    'stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">';

/// The closing tag of a generated icon file.
const String svgCloseTag = '</svg>';

/// Returns the file content for an icon whose child elements are [markup].
///
/// [markup] is copied byte for byte; the file ends with one newline.
String svgFile(String markup) => '$svgOpenTag$markup$svgCloseTag\n';

/// Returns the child markup of a generated icon file, or `null` when [file]
/// does not have the generated shape.
String? innerMarkup(String file) {
  if (!file.startsWith(svgOpenTag) || !file.endsWith('$svgCloseTag\n')) {
    return null;
  }
  return file.substring(
    svgOpenTag.length,
    file.length - svgCloseTag.length - 1,
  );
}

/// One self-closing SVG shape element such as `<path d="…"/>`.
class SvgElement {
  /// Creates an element with a [tag] and its [attributes].
  const new(this.tag, this.attributes);

  /// The element name, such as `path` or `circle`.
  final String tag;

  /// The attributes, in source order.
  final Map<String, String> attributes;

  /// Whether [other] is the same shape: the same tag and the same
  /// attributes, in any order.
  bool sameAs(SvgElement other) =>
      other.tag == tag &&
      other.attributes.length == attributes.length &&
      attributes.entries.every((e) => other.attributes[e.key] == e.value);

  @override
  String toString() => '<$tag $attributes/>';
}

final RegExp _element = RegExp(
  r'<([A-Za-z][\w-]*)((?:\s+[\w:-]+\s*=\s*"[^"]*")*)\s*/>',
);
final RegExp _attribute = RegExp(r'([\w:-]+)\s*=\s*"([^"]*)"');

/// Parses [markup], a run of self-closing shape elements, into its geometry.
///
/// Whitespace between elements and inside tags is ignored, and so is the
/// order of attributes; anything else (text, comments, open tags) is an
/// error, so two drawings are equal only if their shapes are.
List<SvgElement> parseShapes(String markup) {
  final shapes = <SvgElement>[];
  var pos = 0;
  for (final match in _element.allMatches(markup)) {
    if (markup.substring(pos, match.start).trim().isNotEmpty) {
      throw IconsException(
        'Unexpected SVG content: "${markup.substring(pos, match.start)}".',
      );
    }
    final attributes = <String, String>{};
    for (final a in _attribute.allMatches(match.group(2)!)) {
      if (attributes.containsKey(a.group(1))) {
        throw IconsException('Duplicate attribute in "${match.group(0)}".');
      }
      attributes[a.group(1)!] = a.group(2)!;
    }
    shapes.add(SvgElement(match.group(1)!, attributes));
    pos = match.end;
  }
  if (markup.substring(pos).trim().isNotEmpty) {
    throw IconsException('Unexpected SVG content: "${markup.substring(pos)}".');
  }
  if (shapes.isEmpty) throw IconsException('SVG markup without shapes.');
  return shapes;
}

/// Returns the child markup of a complete SVG document such as a Lucide
/// release file: everything between the root `<svg …>` start tag and its
/// closing tag, after removing comments.
String svgDocumentChildren(String document) {
  final text = document.replaceAll(RegExp('<!--.*?-->', dotAll: true), '');
  final open = RegExp(r'<svg\b[^>]*>').firstMatch(text);
  final close = text.lastIndexOf(svgCloseTag);
  if (open == null || close < open.end) {
    throw IconsException('Not an SVG document.');
  }
  return text.substring(open.end, close);
}

/// Whether [a] and [b] draw the same shapes in the same order.
bool sameGeometry(List<SvgElement> a, List<SvgElement> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!a[i].sameAs(b[i])) return false;
  }
  return true;
}
