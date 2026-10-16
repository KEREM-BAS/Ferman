import 'dart:convert';
import 'dart:io';

import 'package:checks/src/check.dart';
import 'package:checks/src/checks/s6_source.dart';
import 'package:path/path.dart' as p;

/// ROADMAP M1 step 7: the spec walker. Every component of
/// `app/test/design/component_spec.json` (`docs/COMPONENTS.md`) exists in
/// `app/lib/design/` with the names the spec gives (ADR 0011):
///
/// - `missing`: no class or enum named the component's `flutterClass`;
/// - `kind`: an `enum` component declared as a class, or the reverse;
/// - `prop`: a prop with a Dart name has no constructor parameter of that
///   name (any constructor of the class: `new`, named, factory);
/// - `enum`: a `dartEnum` a prop names is missing or lacks one of the Dart
///   values the spec's `enums` table lists.
///
/// The Dart source is read with comments and strings masked, so a name in
/// a comment or a string does not count. Generated files count (the
/// `IconName` enum is generated).
final class ComponentSpecCheck implements Check {
  /// Creates the check.
  const new();

  /// The spec file.
  static const specPath = 'app/test/design/component_spec.json';

  /// Where the components live.
  static const sourceRoot = 'app/lib/design';

  @override
  String get name => 'component_spec';

  @override
  CheckResult run(CheckContext context) {
    final specFile = context.file(specPath);
    if (!specFile.existsSync()) {
      return CheckResult.skip('$specPath does not exist yet');
    }
    final root = context.dir(sourceRoot);
    if (!root.existsSync()) {
      return CheckResult.skip('$sourceRoot does not exist yet');
    }
    final Object? spec;
    try {
      spec = jsonDecode(specFile.readAsStringSync());
    } on FormatException catch (error) {
      return CheckResult.fail([
        '$specPath is not valid JSON: ${error.message}',
      ]);
    }
    if (spec is! Map<String, Object?>) {
      return const CheckResult.fail(['$specPath is not a JSON object']);
    }
    final sources = [
      for (final file
          in root
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => p.extension(file.path) == '.dart'))
        DartSource(context.relative(file.path), file.readAsStringSync()),
    ]..sort((a, b) => a.path.compareTo(b.path));
    return CheckResult.from(problems(spec, sources));
  }

  /// The problems of [spec] against [sources].
  static List<String> problems(
    Map<String, Object?> spec,
    List<DartSource> sources,
  ) {
    final declarations = <String, Declaration>{};
    for (final source in sources) {
      for (final declaration in declarationsIn(source)) {
        declarations.putIfAbsent(declaration.name, () => declaration);
      }
    }
    final enums = spec['enums'] is Map<String, Object?>
        ? spec['enums']! as Map<String, Object?>
        : const <String, Object?>{};
    final components = spec['components'] is List<Object?>
        ? spec['components']! as List<Object?>
        : const <Object?>[];
    final result = <String>[];
    final checkedEnums = <String>{};
    for (final entry in components.whereType<Map<String, Object?>>()) {
      final component = entry['name'] as String? ?? '?';
      final className = entry['flutterClass'];
      if (className is! String) {
        result.add('$component: the spec gives no flutterClass');
        continue;
      }
      final declaration = declarations[className];
      final wantsEnum = entry['kind'] == 'enum';
      if (declaration == null) {
        result.add(
          '$component: no ${wantsEnum ? 'enum' : 'class'} $className in '
          '$sourceRoot [missing]',
        );
        continue;
      }
      if (wantsEnum != declaration.isEnum) {
        result.add(
          '$component: $className in ${declaration.path} is '
          '${declaration.isEnum ? 'an enum' : 'a class'}, the spec says '
          '${wantsEnum ? 'enum' : 'class'} [kind]',
        );
        continue;
      }
      final props = entry['props'] is List<Object?>
          ? entry['props']! as List<Object?>
          : const <Object?>[];
      for (final prop in props.whereType<Map<String, Object?>>()) {
        final dart = prop['dart'];
        if (dart is String && !declaration.isEnum) {
          if (!declaration.parameters.contains(dart)) {
            result.add(
              '$component: $className has no constructor parameter '
              "'$dart' (${declaration.path}) [prop]",
            );
          }
        }
        final dartEnum = prop['dartEnum'];
        if (dartEnum is String && checkedEnums.add(dartEnum)) {
          result.addAll(
            _enumProblems(component, dartEnum, enums, declarations),
          );
        }
      }
    }
    return result;
  }

  static List<String> _enumProblems(
    String component,
    String dartEnum,
    Map<String, Object?> enums,
    Map<String, Declaration> declarations,
  ) {
    final declaration = declarations[dartEnum];
    if (declaration == null || !declaration.isEnum) {
      return ['$component: no enum $dartEnum in $sourceRoot [enum]'];
    }
    final entry = enums[dartEnum];
    final values = entry is Map<String, Object?> && entry['dart'] is List
        ? (entry['dart']! as List).whereType<String>()
        : const <String>[];
    String lacks(String value) =>
        '$component: enum $dartEnum lacks the value $value '
        '(${declaration.path}) [enum]';
    return [
      for (final value in values)
        if (!declaration.values.contains(value)) lacks(value),
    ];
  }

  static final RegExp _declaration = RegExp(r'\b(class|enum)\s+([A-Za-z_]\w*)');

  /// The classes and enums declared in [source], with their constructor
  /// parameter names or enum values.
  static List<Declaration> declarationsIn(DartSource source) {
    final code = source.code;
    final result = <Declaration>[];
    for (final match in _declaration.allMatches(code)) {
      final open = code.indexOf('{', match.end);
      if (open < 0) continue;
      final close = _matching(code, open, '{', '}');
      if (close < 0) continue;
      final body = code.substring(open + 1, close);
      final name = match.group(2)!;
      final isEnum = match.group(1) == 'enum';
      result.add(
        Declaration(
          name: name,
          path: source.path,
          isEnum: isEnum,
          parameters: isEnum ? const {} : _constructorParameters(body, name),
          values: isEnum ? _enumValues(body) : const {},
        ),
      );
    }
    return result;
  }

  /// The parameter names of every constructor in a class [body]: Dart
  /// 3.13's `new(`, `new name(`, `factory`, and the classic `Name(` and
  /// `Name.named(` forms.
  static Set<String> _constructorParameters(String body, String className) {
    const prefix = r'(?:^|[;{}\s])(?:const\s+|factory\s+)?';
    const newForm = r'new(?:\s+[A-Za-z_]\w*)?';
    const named = r'(?:\.[A-Za-z_]\w*)?';
    final name = RegExp.escape(className);
    final starts = RegExp(
      '$prefix(?:$newForm|$name$named)'
      r'\s*\(',
    );
    final names = <String>{};
    for (final match in starts.allMatches(body)) {
      final open = match.end - 1;
      final close = _matching(body, open, '(', ')');
      if (close < 0) continue;
      final parameters = body.substring(open + 1, close);
      for (final name in RegExp(
        r'(?:this\.|super\.)?([A-Za-z_]\w*)\s*(?:[,=})\]]|$)',
      ).allMatches(parameters)) {
        names.add(name.group(1)!);
      }
    }
    return names;
  }

  /// The values of an enum [body]: the identifiers before the first
  /// top-level `;`, one per top-level comma.
  static Set<String> _enumValues(String body) {
    var depth = 0;
    var end = body.length;
    for (var i = 0; i < body.length; i++) {
      final c = body[i];
      if (c == '(' || c == '[' || c == '{' || c == '<') depth++;
      if (c == ')' || c == ']' || c == '}' || c == '>') depth--;
      if (c == ';' && depth == 0) {
        end = i;
        break;
      }
    }
    final values = <String>{};
    final head = body.substring(0, end);
    var start = 0;
    depth = 0;
    for (var i = 0; i <= head.length; i++) {
      final c = i < head.length ? head[i] : ',';
      if (c == '(' || c == '[' || c == '{' || c == '<') depth++;
      if (c == ')' || c == ']' || c == '}' || c == '>') depth--;
      if (c == ',' && depth == 0) {
        final item = head.substring(start, i).trim();
        final id = RegExp(r'^(?:@\w+\s+)*([A-Za-z_]\w*)').firstMatch(item);
        if (id != null) values.add(id.group(1)!);
        start = i + 1;
      }
    }
    return values;
  }

  /// The index of the bracket that closes the one at [open], or -1.
  static int _matching(String code, int open, String opening, String closing) {
    var depth = 0;
    for (var i = open; i < code.length; i++) {
      if (code[i] == opening) depth++;
      if (code[i] == closing) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}

/// A class or enum found in the design library's source.
final class Declaration {
  /// Describes a declaration.
  const new({
    required this.name,
    required this.path,
    required this.isEnum,
    required this.parameters,
    required this.values,
  });

  /// The class or enum name.
  final String name;

  /// The file, `/`-separated from the repository root.
  final String path;

  /// Whether it is an enum.
  final bool isEnum;

  /// The parameter names of the class's constructors.
  final Set<String> parameters;

  /// The values of the enum.
  final Set<String> values;
}
