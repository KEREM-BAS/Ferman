/// Turns each icon's SVG markup into const Dart data for the app's painter.
///
/// The app draws icons with a small painter instead of an SVG package (the
/// SVG packages pull in `http`, which the network deny list forbids). The
/// painter reads `icon_data.g.dart`: for every `IconName`, the design's
/// elements as instances of the sealed `IconElement` classes in the
/// hand-written `icon_element.dart`. Only the elements and attributes the
/// design uses are understood; anything else stops the tool, so a re-export
/// that needs more drawing features cannot be drawn wrongly by accident.
library;

import 'package:icons/src/dart_enum.dart';
import 'package:icons/src/design_icons.dart';
import 'package:icons/src/errors.dart';
import 'package:icons/src/svg.dart';

/// Where the element data is written, relative to the repository root.
const String dataPath = 'app/lib/design/icons/icon_data.g.dart';

/// The hand-written element classes the data uses, relative to the
/// repository root.
const String elementPath = 'app/lib/design/icons/icon_element.dart';

/// What an attribute value holds, which decides how it is checked and
/// written.
enum AttributeKind {
  /// A plain SVG number such as `12`, `.5` or `-1.25`, written as a Dart
  /// `double` literal with the same text.
  number,

  /// SVG path data, kept as a string (the painter parses it).
  pathData,

  /// An SVG points list, kept as a string.
  points,
}

/// One SVG element type the icons use and its Dart class.
class IconElementType {
  /// Creates a type for [tag] drawn by [dartClass], with its [attributes]
  /// in the order the Dart constructor lists them; those in [optional] may
  /// be missing.
  const new(
    this.tag,
    this.dartClass,
    this.attributes, {
    this.optional = const {},
  });

  /// The SVG element name, such as `circle`.
  final String tag;

  /// The `IconElement` subclass in `icon_element.dart`.
  final String dartClass;

  /// Attribute name → kind. The Dart field has the attribute's name.
  final Map<String, AttributeKind> attributes;

  /// Attributes that may be missing (nullable in Dart).
  final Set<String> optional;
}

/// Every element type the icons may use. All of them occur in the design.
const List<IconElementType> iconElementTypes = [
  IconElementType('path', 'IconPath', {'d': AttributeKind.pathData}),
  IconElementType('circle', 'IconCircle', {
    'cx': AttributeKind.number,
    'cy': AttributeKind.number,
    'r': AttributeKind.number,
  }),
  IconElementType('ellipse', 'IconEllipse', {
    'cx': AttributeKind.number,
    'cy': AttributeKind.number,
    'rx': AttributeKind.number,
    'ry': AttributeKind.number,
  }),
  IconElementType(
    'rect',
    'IconRect',
    {
      'x': AttributeKind.number,
      'y': AttributeKind.number,
      'width': AttributeKind.number,
      'height': AttributeKind.number,
      'rx': AttributeKind.number,
      'ry': AttributeKind.number,
    },
    optional: {'rx', 'ry'},
  ),
  IconElementType('line', 'IconLine', {
    'x1': AttributeKind.number,
    'y1': AttributeKind.number,
    'x2': AttributeKind.number,
    'y2': AttributeKind.number,
  }),
  IconElementType('polyline', 'IconPolyline', {'points': AttributeKind.points}),
  IconElementType('polygon', 'IconPolygon', {'points': AttributeKind.points}),
];

/// The one fill the design uses: a dot filled with the icon colour. It is
/// written as `filled: true`; any other `fill` value stops the tool.
const String fillAttribute = 'fill';

/// The only accepted value of [fillAttribute].
const String fillValue = 'currentColor';

/// Attributes that do not change the drawing of a standalone icon and are
/// dropped: names for scripts and styles that the app never uses.
const Set<String> ignoredAttributes = {'class', 'id', 'key'};

final RegExp _number = RegExp(r'^-?(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?$');
final RegExp _pathData = RegExp(r'^\s*[Mm][MmLlHhVvCcSsQqTtAaZz0-9eE.,+\s-]*$');
final RegExp _listSeparator = RegExp(r'[\s,]+');

/// One element of an icon, checked against [iconElementTypes].
class IconElementData {
  /// Creates an element of [type] with its attribute [values] (source text,
  /// in the type's order) and whether it is [filled].
  const new(this.type, this.values, {required this.filled});

  /// The element type.
  final IconElementType type;

  /// Attribute name → value exactly as the design writes it, in the order
  /// of [IconElementType.attributes]; missing optional attributes are
  /// absent.
  final Map<String, String> values;

  /// Whether the element carries `fill="currentColor"`.
  final bool filled;

  /// The const constructor call that recreates this element in Dart, such
  /// as `IconCircle(cx: 12, cy: 12, r: .5, filled: true)`.
  String toDart() {
    String literal(String name, String value) =>
        type.attributes[name] == AttributeKind.number
        ? value
        : dartString(value);
    final arguments = [
      for (final MapEntry(key: name, :value) in values.entries)
        '$name: ${literal(name, value)}',
      if (filled) 'filled: true',
    ];
    return '${type.dartClass}(${arguments.join(', ')})';
  }

  /// The SVG attributes this element stands for, without the ignored ones.
  Map<String, String> toSvgAttributes() => {
    ...values,
    if (filled) fillAttribute: fillValue,
  };
}

/// Parses and checks the [markup] of the icon [name].
///
/// Throws [IconsException] on an element type outside [iconElementTypes],
/// an attribute it does not list (other than [ignoredAttributes] and a
/// `fill="currentColor"`), a missing required attribute or a value of the
/// wrong form.
List<IconElementData> iconElements(String name, String markup) {
  final types = {for (final t in iconElementTypes) t.tag: t};
  return [
    for (final element in parseShapes(markup))
      _checkElement(name, element, types),
  ];
}

IconElementData _checkElement(
  String name,
  SvgElement element,
  Map<String, IconElementType> types,
) {
  Never fail(String problem) =>
      throw IconsException('Icon "$name": $problem in $element.');

  final type = types[element.tag];
  if (type == null) {
    fail(
      'unsupported element <${element.tag}> (the painter knows '
      '${types.keys.join(', ')})',
    );
  }
  var filled = false;
  for (final MapEntry(key: attribute, :value) in element.attributes.entries) {
    if (ignoredAttributes.contains(attribute) ||
        type.attributes.containsKey(attribute)) {
      continue;
    }
    if (attribute == fillAttribute && value == fillValue) {
      filled = true;
      continue;
    }
    fail(
      attribute == fillAttribute
          ? 'unsupported fill "$value" (only "$fillValue")'
          : 'unsupported attribute "$attribute"',
    );
  }
  final values = <String, String>{};
  for (final MapEntry(key: attribute, value: kind) in type.attributes.entries) {
    final value = element.attributes[attribute];
    if (value == null) {
      if (type.optional.contains(attribute)) continue;
      fail('missing attribute "$attribute"');
    }
    if (!_validValue(kind, value)) {
      fail('"$attribute" is not valid ${kind.name}: "$value"');
    }
    values[attribute] = value;
  }
  return IconElementData(type, values, filled: filled);
}

bool _validValue(AttributeKind kind, String value) => switch (kind) {
  AttributeKind.number => _number.hasMatch(value),
  AttributeKind.pathData => _pathData.hasMatch(value),
  AttributeKind.points => _validPoints(value),
};

/// At least two points, each a pair of plain numbers.
bool _validPoints(String value) {
  final numbers = value.trim().split(_listSeparator);
  return numbers.length >= 4 &&
      numbers.length.isEven &&
      numbers.every(_number.hasMatch);
}

/// A single-quoted Dart string literal for [value].
String dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$escaped'";
}

/// Returns the unformatted source of `icon_data.g.dart` for [icons].
String emitIconData(List<DesignIcon> icons) {
  final out = StringBuffer()
    ..writeln('// GENERATED by tools/icons from the design export. Do not edit')
    ..writeln('// by hand; run (cd tools/icons && dart run).')
    ..writeln()
    ..writeln("import 'icon_element.dart';")
    ..writeln("import 'icon_name.g.dart';")
    ..writeln()
    ..writeln("/// The drawing of every [IconName]: the design's exact SVG")
    ..writeln('/// elements as const data (ADR 0013).')
    ..writeln('///')
    ..writeln('/// Coordinates are in the 24 × 24 viewBox. Every element is')
    ..writeln('/// stroked with the icon colour (1.5 wide by default, scaled')
    ..writeln('/// by size / 24) with round caps and joins, and filled only')
    ..writeln('/// when [IconElement.filled] is true.')
    ..writeln('extension IconNameElements on IconName {')
    ..writeln('  /// The SVG elements of this icon, in drawing order.')
    ..writeln('  List<IconElement> get elements => switch (this) {');
  for (final icon in icons) {
    final elements = iconElements(icon.name, icon.markup);
    out.writeln(
      '    IconName.${dartIdentifier(icon.name)} => const '
      '[${elements.map((e) => e.toDart()).join(', ')}],',
    );
  }
  out
    ..writeln('  };')
    ..writeln('}');
  return out.toString();
}
