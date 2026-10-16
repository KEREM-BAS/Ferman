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
/// - `item`: an item type (`itemTypes`, the data a component takes in a
///   list or a value, such as `MenuItem`, `SelectOption<T>` or
///   `FermanMode`) has no class or enum of its Dart name;
/// - `field`: a field of an item type with a Dart name has no constructor
///   parameter of that name in the item type's class or enum;
/// - `enum`: a `dartEnum` a prop or an item field names is missing or lacks
///   one of the Dart values the spec's `enums` table lists;
/// - `variant`: a variant no enum prop carries (the badge kinds of
///   `ThumbnailBadges`, which come as a set) has no enum in the spec's
///   `enums` table whose design values include the variant's and whose
///   name exactly one prop or item field type of the component contains
///   (`Set<ThumbnailBadge>`), or that Dart enum is missing or lacks the
///   Dart value paired with one of them.
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
      final props = _maps(entry['props']);
      for (final prop in props) {
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
      for (final item in _maps(entry['itemTypes'])) {
        result.addAll(
          _itemProblems(component, item, enums, declarations, checkedEnums),
        );
      }
      final variants = entry['variants'] is Map<String, Object?>
          ? entry['variants']! as Map<String, Object?>
          : const <String, Object?>{};
      for (final MapEntry(key: variant, value: values) in variants.entries) {
        // An enum prop of the variant's name is checked with the props.
        if (props.any(
          (prop) =>
              (prop['ds'] == variant || prop['dart'] == variant) &&
              prop['dartEnum'] is String,
        )) {
          continue;
        }
        result.addAll(
          _variantProblems(
            component,
            entry,
            variant,
            values is List<Object?> ? values.whereType<String>().toList() : [],
            enums,
            declarations,
          ),
        );
      }
    }
    return result;
  }

  /// The problems of the item type [item] of [component]: its class or
  /// enum, the constructor parameter of each field and the enums its
  /// fields name (once each, with [checkedEnums]).
  static List<String> _itemProblems(
    String component,
    Map<String, Object?> item,
    Map<String, Object?> enums,
    Map<String, Declaration> declarations,
    Set<String> checkedEnums,
  ) {
    final spelled = item['dart'] ?? item['name'];
    if (spelled is! String) {
      return ['$component: an item type gives no Dart name [item]'];
    }
    // `SelectOption<T>` is declared as `class SelectOption<T>`.
    final className = spelled.split('<').first.trim();
    final declaration = declarations[className];
    if (declaration == null) {
      final missing =
          '$component: no class or enum $className for the item type '
          '${item['name']} in $sourceRoot [item]';
      return [missing];
    }
    final result = <String>[];
    for (final field in _maps(item['fields'])) {
      final dart = field['dart'];
      if (dart is String && !declaration.parameters.contains(dart)) {
        result.add(
          '$component: item type $className has no constructor parameter '
          "'$dart' (${declaration.path}) [field]",
        );
      }
      final dartEnum = field['dartEnum'];
      if (dartEnum is String && checkedEnums.add(dartEnum)) {
        result.addAll(_enumProblems(component, dartEnum, enums, declarations));
      }
    }
    return result;
  }

  /// The problems of the [variant] of [component] that no enum prop
  /// carries, with the design [values]: the enum of the spec's table that
  /// pairs them with Dart values, and those values in the Dart enum.
  static List<String> _variantProblems(
    String component,
    Map<String, Object?> entry,
    String variant,
    List<String> values,
    Map<String, Object?> enums,
    Map<String, Declaration> declarations,
  ) {
    final candidates = [
      for (final MapEntry(key: name, value: table) in enums.entries)
        if (values.every(_strings(table, 'ds').contains)) name,
    ];
    // The types the component's props and item fields are written with
    // (`Set<ThumbnailBadge>`).
    final types = [
      for (final prop in _maps(entry['props'])) prop['type'],
      for (final item in _maps(entry['itemTypes']))
        for (final field in _maps(item['fields'])) field['type'],
    ].whereType<String>().join(' ');
    final typed = [
      for (final name in candidates)
        if (RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(types)) name,
    ];
    if (candidates.isEmpty) {
      final unpaired =
          "$component: no enum of the spec's enums table has the values of "
          'the variant $variant (${values.join(', ')}) [variant]';
      return [unpaired];
    }
    // Matching values alone prove nothing: the component must take the
    // enum through a prop or an item field.
    if (typed.length != 1) {
      final untyped =
          '$component: ${typed.isEmpty ? 'no' : 'more than one'} prop or '
          'item field type names the enum of the variant $variant '
          '(${values.join(', ')}; the enums table has '
          '${candidates.join(', ')}) [variant]';
      return [untyped];
    }
    final chosen = typed.single;
    final declaration = declarations[chosen];
    if (declaration == null || !declaration.isEnum) {
      final missing =
          '$component: no enum $chosen for the variant $variant in '
          '$sourceRoot [variant]';
      return [missing];
    }
    final ds = _strings(enums[chosen], 'ds');
    final dart = _strings(enums[chosen], 'dart');
    final result = <String>[];
    for (final value in values) {
      final index = ds.indexOf(value);
      final dartValue = index < dart.length ? dart[index] : value;
      if (!declaration.values.contains(dartValue)) {
        result.add(
          '$component: enum $chosen lacks the value $dartValue of the '
          'variant $variant (${declaration.path}) [variant]',
        );
      }
    }
    return result;
  }

  /// The JSON objects in the list [value]; none when it is not a list.
  static List<Map<String, Object?>> _maps(Object? value) => value is List
      ? value.whereType<Map<String, Object?>>().toList()
      : const [];

  /// The strings in the list under [key] of the JSON object [table].
  static List<String> _strings(Object? table, String key) =>
      table is Map<String, Object?> && table[key] is List
      ? (table[key]! as List).whereType<String>().toList()
      : const [];

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
  /// parameter names and, for enums, their values.
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
          parameters: _constructorParameters(body, name),
          values: isEnum ? _enumValues(body) : const {},
        ),
      );
    }
    return result;
  }

  /// The parameter names of every constructor in a class or enum [body]:
  /// Dart 3.13's `new(`, `new name(`, `factory`, and the classic `Name(`
  /// and `Name.named(` forms. Only declarations count: a constructor
  /// starts a member (after a `;`, `{` or `}`, its annotations and its
  /// `const`, `factory` or `external`), so a call such as
  /// `=> Name(child: x)` in a body does not.
  static Set<String> _constructorParameters(String body, String className) {
    const prefix =
        r'(?:^|[;{}])\s*(?:@[A-Za-z_][\w.]*(?:\([^()]*\))?\s*)*'
        r'(?:(?:const|factory|external)\s+)*';
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
      names.addAll(_parameterNames(body.substring(open + 1, close)));
    }
    return names;
  }

  /// The names in the parameter [list] of a constructor: one per
  /// top-level comma, with the `{...}` or `[...]` group read as a list of
  /// its own. Each parameter is cut at its default value (`=`, or the
  /// legacy `:`) and before the own parameters of a function-typed formal
  /// (`this.builder(BuildContext context)`); its name is the last
  /// identifier left (`this.name`, `super.key`, `List<T> items`), so a
  /// default such as `FontGroup.system` or `true` is never a name.
  static Iterable<String> _parameterNames(String list) sync* {
    for (final part in _topLevel(list, ',')) {
      final parameter = part.trim();
      if (parameter.isEmpty) continue;
      final opening = parameter[0];
      if (opening == '{' || opening == '[') {
        final close = _matching(
          parameter,
          0,
          opening,
          opening == '{' ? '}' : ']',
        );
        yield* _parameterNames(
          parameter.substring(1, close < 0 ? parameter.length : close),
        );
        continue;
      }
      var head = _topLevel(_topLevel(parameter, '=').first, ':').first.trim();
      if (head.endsWith('?')) head = head.substring(0, head.length - 1).trim();
      if (head.endsWith(')')) {
        final open = _matchingBackward(head, head.length - 1);
        head = head.substring(0, open < 0 ? 0 : open).trim();
      }
      final name = RegExp(r'([A-Za-z_]\w*)$').firstMatch(head);
      if (name != null) yield name.group(1)!;
    }
  }

  /// [text] split at each [separator] outside brackets (`()`, `[]`, `{}`
  /// and the `<>` of type arguments).
  static List<String> _topLevel(String text, String separator) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '(' || c == '[' || c == '{' || c == '<') depth++;
      if (c == ')' || c == ']' || c == '}' || c == '>') {
        // A lone `>` (in `=>` or `a > b`) never goes below the top level.
        if (depth > 0) depth--;
      }
      if (c == separator && depth == 0) {
        parts.add(text.substring(start, i));
        start = i + 1;
      }
    }
    return parts..add(text.substring(start));
  }

  /// The index of the `(` that opens the `)` at [close] in [code], or -1.
  static int _matchingBackward(String code, int close) {
    var depth = 0;
    for (var i = close; i >= 0; i--) {
      if (code[i] == ')') depth++;
      if (code[i] == '(') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
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

  /// The parameter names of the constructors of the class or enum.
  final Set<String> parameters;

  /// The values of the enum.
  final Set<String> values;
}
