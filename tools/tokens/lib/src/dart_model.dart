/// The shape of the generated Dart file: classes, instances and fields.
library;

import 'package:tokens/src/cascade.dart';

/// One generated constant instance of a token class, such as
/// `FermanColorTokens.dark`.
final class DartInstance {
  /// Creates an instance description.
  const new({
    required this.name,
    required this.label,
    required this.environment,
    required this.doc,
  });

  /// The static field name, such as `dark`.
  final String name;

  /// The label used in field documentation, such as `Dark`.
  final String label;

  /// The environment whose resolved values the instance holds.
  final TokenEnvironment environment;

  /// The documentation of the static field.
  final String doc;
}

/// One generated field.
final class DartField {
  /// Creates a field.
  new({
    required this.name,
    required this.type,
    required this.doc,
    required this.values,
    required this.cssNames,
  });

  /// The Dart field name.
  final String name;

  /// The Dart type.
  final String type;

  /// Documentation paragraphs.
  final List<String> doc;

  /// The constant expression per instance name; a class without instances
  /// uses the single key `''`.
  final Map<String, String> values;

  /// The CSS custom properties the field comes from, without `--`.
  final List<String> cssNames;
}

/// One generated class.
final class DartClass {
  /// Creates a class.
  new({
    required this.name,
    required this.doc,
    required this.instances,
    required this.fields,
  });

  /// The class name.
  final String name;

  /// Documentation paragraphs.
  final List<String> doc;

  /// The constant instances; empty for a class of static constants.
  final List<DartInstance> instances;

  /// The fields, sorted by name.
  final List<DartField> fields;

  /// Whether the class holds static constants only.
  bool get isStatic => instances.isEmpty;

  /// The field called [name]; throws a [StateError] if there is none.
  DartField field(String name) => fields.firstWhere(
    (field) => field.name == name,
    orElse: () => throw StateError('$this has no field $name'),
  );

  @override
  String toString() => name;
}
