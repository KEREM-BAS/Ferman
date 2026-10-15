import 'package:icons/icons.dart';
import 'package:test/test.dart';

void main() {
  test('innerMarkup undoes svgFile and rejects other shapes', () {
    const markup = '<path d="m9 18 6-6-6-6" />';
    expect(innerMarkup(svgFile(markup)), markup);
    expect(innerMarkup('<svg>$markup</svg>\n'), isNull);
    expect(innerMarkup(svgFile(markup).trimRight()), isNull);
  });

  test('geometry ignores attribute order and whitespace', () {
    final a = parseShapes('<rect width="18" height="18" x="3" y="3" rx="2" />');
    final b = parseShapes(
      '\n  <rect x="3" y="3" width="18" height="18" rx="2"/>\n',
    );
    expect(sameGeometry(a, b), isTrue);
  });

  test('geometry notices changed values, element order and extra shapes', () {
    final base = parseShapes('<path d="M1 2"/><circle cx="1" cy="1" r="2"/>');
    expect(
      sameGeometry(
        base,
        parseShapes('<path d="M1 3"/><circle cx="1" cy="1" r="2"/>'),
      ),
      isFalse,
    );
    expect(
      sameGeometry(
        base,
        parseShapes('<circle cx="1" cy="1" r="2"/><path d="M1 2"/>'),
      ),
      isFalse,
    );
    expect(sameGeometry(base, parseShapes('<path d="M1 2"/>')), isFalse);
    expect(
      sameGeometry(
        parseShapes('<ellipse cx="12" cy="12" rx="10" ry="7"/>'),
        parseShapes('<ellipse cx="12" cy="12" rx="10" ry="6"/>'),
      ),
      isFalse,
    );
  });

  test('parseShapes rejects anything but self-closing shapes', () {
    expect(() => parseShapes('text'), throwsA(isA<IconsException>()));
    expect(
      () => parseShapes('<g><path d="M1"/></g>'),
      throwsA(isA<IconsException>()),
    );
    expect(
      () => parseShapes('<path d="1" d="2"/>'),
      throwsA(isA<IconsException>()),
    );
    expect(() => parseShapes(''), throwsA(isA<IconsException>()));
  });

  test('svgDocumentChildren reads a Lucide release file', () {
    const document = '''
<!-- @license lucide-static v0.460.0 - ISC -->
<svg
  class="lucide lucide-align-center"
  xmlns="http://www.w3.org/2000/svg"
  width="24"
  height="24"
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width="2"
  stroke-linecap="round"
  stroke-linejoin="round"
>
  <path d="M17 12H7" />
  <path d="M19 18H5" />
</svg>
''';
    expect(
      sameGeometry(
        parseShapes(svgDocumentChildren(document)),
        parseShapes('<path d="M17 12H7" /><path d="M19 18H5" />'),
      ),
      isTrue,
    );
  });
}
