import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

Map<String, Object?> _spec(List<Map<String, Object?>> components) => {
  'enums': {
    'ButtonVariant': {
      'dart': ['primary', 'secondary', 'ghost', 'danger'],
    },
    'FontGroup': {
      'ds': ['document', 'system'],
      'dart': ['document', 'system'],
    },
    'ThumbnailBadge': {
      'ds': ['edited', 'comments', 'form-fields', 'signature', 'warnings'],
      'dart': ['edited', 'comments', 'formFields', 'signature', 'warnings'],
    },
    'ThumbnailMarker': {
      'ds': ['edited', 'comment'],
      'dart': ['edited', 'comment'],
    },
  },
  'components': components,
};

const Map<String, Object?> _button = {
  'name': 'Button',
  'flutterClass': 'Button',
  'kind': 'widget',
  'props': [
    {'dart': 'variant', 'dartEnum': 'ButtonVariant'},
    {'dart': 'disabledReason'},
    {'dart': 'onPressed'},
    {'dart': 'child'},
    {'dart': null, 'type': 'n/a'},
  ],
  // Carried by the enum prop, so checked with the props only.
  'variants': {
    'variant': ['primary', 'secondary', 'ghost', 'danger'],
  },
};

const Map<String, Object?> _iconName = {
  'name': 'ICON_PATHS',
  'flutterClass': 'IconName',
  'kind': 'enum',
  'props': <Object?>[],
};

const _goodButton = '''
/// Buttons; "class Fake {" in a comment does not count.
enum ButtonVariant { primary, secondary, ghost, danger }

class Button extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.variant = ButtonVariant.secondary,
    this.disabledReason,
    this.onPressed,
  });
  final Widget child;
}
''';

/// A component with a generic item type and an item field that names an
/// enum.
const Map<String, Object?> _fontPicker = {
  'name': 'FontPicker',
  'flutterClass': 'FontPicker',
  'kind': 'widget',
  'props': [
    {'dart': 'fonts'},
  ],
  'itemTypes': [
    {
      'name': 'FontOption',
      'dart': 'FontOption<T>',
      'fields': [
        {'dart': 'name'},
        {'dart': 'group', 'dartEnum': 'FontGroup'},
        {'ds': 'label', 'dart': null, 'type': 'n/a'},
      ],
    },
  ],
};

/// A component whose item type is an enum with fields.
const Map<String, Object?> _modeTabs = {
  'name': 'ModeTabs',
  'flutterClass': 'ModeTabs',
  'kind': 'widget',
  'props': [
    {'dart': 'value'},
  ],
  'itemTypes': [
    {
      'name': 'FermanMode',
      'dart': 'FermanMode',
      'fields': [
        {'dart': 'id'},
        {'dart': 'icon'},
        {'dart': 'shortcut'},
      ],
    },
  ],
};

/// A variant no enum prop carries: the badge kinds come as a set, through
/// a prop of the [type] (none when null).
Map<String, Object?> _badges(
  List<String> values, {
  String? type = 'Set<ThumbnailBadge>',
}) => {
  'name': 'ThumbnailBadges',
  'flutterClass': 'ThumbnailBadges',
  'kind': 'addition',
  'props': [
    {'dart': 'badges', 'type': ?type},
  ],
  'variants': {'badge': values},
};

const _goodFontPicker = '''
enum FontGroup { document, system }

class FontPicker<T> extends StatelessWidget {
  const new({required this.fonts, super.key});
  final List<FontOption<T>> fonts;
}

class FontOption<T> {
  const new({required this.name, this.group = FontGroup.system});
}
''';

const _goodModeTabs = '''
class ModeTabs extends StatelessWidget {
  const new({required this.value, super.key});
}

enum FermanMode {
  view('view', IconName.bookOpen),
  edit('edit', IconName.filePenLine, shortcut: 'E');

  new(this.id, this.icon, {this.shortcut});
  final String id;
  final IconName icon;
  final String? shortcut;
}
''';

const _goodBadges = '''
enum ThumbnailBadge { edited, comments, formFields, signature, warnings }

class ThumbnailBadges extends StatelessWidget {
  const new({super.key, this.badges = const {}});
}
''';

List<String> _problems(Map<String, Object?> spec, Map<String, String> files) =>
    ComponentSpecCheck.problems(spec, [
      for (final MapEntry(:key, :value) in files.entries)
        DartSource(key, value),
    ]);

void main() {
  test('skips without the spec or the design library', () {
    expect(Fixture().run(const ComponentSpecCheck()), skips);
    final fixture = Fixture()
      ..write(ComponentSpecCheck.specPath, jsonEncode(_spec([_button])));
    expect(fixture.run(const ComponentSpecCheck()), skips);
  });

  test('passes when every component, prop and enum value exists', () {
    final fixture = Fixture()
      ..write(
        ComponentSpecCheck.specPath,
        jsonEncode(_spec([_button, _iconName])),
      )
      ..write('app/lib/design/components/core/button.dart', _goodButton)
      // Generated files count.
      ..write(
        'app/lib/design/icons/icon_name.g.dart',
        'enum IconName { arrowLeft(true), x(false); const IconName(this.d); '
            'final bool d; }\n',
      );
    expect(fixture.run(const ComponentSpecCheck()), passes);
  });

  test('reports a missing component, prop and enum value', () {
    final problems = _problems(_spec([_button, _iconName]), {
      'app/lib/design/components/core/button.dart': '''
enum ButtonVariant { primary, secondary, ghost }
class Button {
  // this.disabledReason is only a comment
  const new({required this.child, this.variant, this.onPressed});
}
''',
    });
    const noParameter =
        "Button: Button has no constructor parameter 'disabledReason' "
        '(app/lib/design/components/core/button.dart) [prop]';
    const noValue =
        'Button: enum ButtonVariant lacks the value danger '
        '(app/lib/design/components/core/button.dart) [enum]';
    expect(
      problems,
      unorderedEquals([
        noParameter,
        noValue,
        'ICON_PATHS: no enum IconName in app/lib/design [missing]',
      ]),
    );
  });

  test('passes when every item type, field and variant value exists', () {
    final fixture = Fixture()
      ..write(
        ComponentSpecCheck.specPath,
        jsonEncode(
          _spec([
            _fontPicker,
            _modeTabs,
            _badges(['edited', 'form-fields', 'warnings']),
          ]),
        ),
      )
      ..write(
        'app/lib/design/components/forms/font_picker.dart',
        _goodFontPicker,
      )
      ..write(
        'app/lib/design/components/navigation/mode_tabs.dart',
        _goodModeTabs,
      )
      ..write(
        'app/lib/design/components/additions/thumbnail_badges.dart',
        _goodBadges,
      );
    expect(fixture.run(const ComponentSpecCheck()), passes);
  });

  test('reports a missing item type and a missing item field', () {
    final problems = _problems(_spec([_fontPicker, _modeTabs]), {
      'app/lib/design/components/forms/font_picker.dart': '''
enum FontGroup { document, system }
class FontPicker { const new({required this.fonts}); }
class FontOption<T> {
  // this.group is only a comment
  const new({required this.name});
}
''',
      'app/lib/design/components/navigation/mode_tabs.dart': '''
class ModeTabs { const new({required this.value}); }
''',
    });
    const noField =
        "FontPicker: item type FontOption has no constructor parameter 'group' "
        '(app/lib/design/components/forms/font_picker.dart) [field]';
    const noItem =
        'ModeTabs: no class or enum FermanMode for the item type FermanMode '
        'in app/lib/design [item]';
    expect(problems, unorderedEquals([noField, noItem]));
  });

  test('reports a missing field of an enum item type and a missing enum '
      'value an item field names', () {
    final problems = _problems(_spec([_fontPicker, _modeTabs]), {
      'app/lib/design/components/forms/font_picker.dart': _goodFontPicker
          .replaceFirst('document, system', 'document'),
      'app/lib/design/components/navigation/mode_tabs.dart': _goodModeTabs
          .replaceFirst(', {this.shortcut}', ''),
    });
    const noValue =
        'FontPicker: enum FontGroup lacks the value system '
        '(app/lib/design/components/forms/font_picker.dart) [enum]';
    const noField =
        'ModeTabs: item type FermanMode has no constructor parameter '
        "'shortcut' (app/lib/design/components/navigation/mode_tabs.dart) "
        '[field]';
    expect(problems, unorderedEquals([noValue, noField]));
  });

  test('reports a missing value of a variant without an enum prop', () {
    final problems = _problems(
      _spec([
        _badges(['edited', 'form-fields', 'warnings']),
      ]),
      {
        'app/lib/design/components/additions/thumbnail_badges.dart': _goodBadges
            .replaceFirst('formFields, ', ''),
      },
    );
    const noValue =
        'ThumbnailBadges: enum ThumbnailBadge lacks the value formFields of '
        'the variant badge '
        '(app/lib/design/components/additions/thumbnail_badges.dart) '
        '[variant]';
    expect(problems, [noValue]);
  });

  test('reports a variant without an enum prop whose enum is missing', () {
    final problems = _problems(
      _spec([
        _badges(['edited', 'form-fields']),
      ]),
      {
        'app/lib/design/components/additions/thumbnail_badges.dart': '''
class ThumbnailBadges { const new({this.badges}); }
''',
      },
    );
    const noEnum =
        'ThumbnailBadges: no enum ThumbnailBadge for the variant badge in '
        'app/lib/design [variant]';
    expect(problems, [noEnum]);
  });

  test('a variant without an enum prop takes the enum of the table with its '
      'values that one prop type names', () {
    const files = {
      'app/lib/design/components/additions/thumbnail_badges.dart': _goodBadges,
    };
    List<String> problemsOf(List<String> values, String? type) =>
        _problems(_spec([_badges(values, type: type)]), files);
    // No enum has "stacked".
    const unpaired =
        "ThumbnailBadges: no enum of the spec's enums table has the values "
        'of the variant badge (edited, stacked) [variant]';
    expect(problemsOf(['edited', 'stacked'], 'Set<ThumbnailBadge>'), [
      unpaired,
    ]);
    // Only ThumbnailBadge has "form-fields", but matching values prove
    // nothing while no prop type names it.
    const untyped =
        'ThumbnailBadges: no prop or item field type names the enum of the '
        'variant badge (form-fields; the enums table has ThumbnailBadge) '
        '[variant]';
    expect(problemsOf(['form-fields'], null), [untyped]);
    // ThumbnailBadge and ThumbnailMarker both have "edited": the prop type
    // tells them apart, unless it names both.
    expect(problemsOf(['edited'], null).single, contains('no prop or item'));
    expect(problemsOf(['edited'], 'Map<ThumbnailBadge, String>'), isEmpty);
    expect(
      problemsOf(['edited'], 'Map<ThumbnailBadge, ThumbnailMarker>').single,
      contains('more than one prop or item field type'),
    );
  });

  test('a default value or a constructor call is never a parameter', () {
    final problems = _problems(
      _spec([
        {
          ..._fontPicker,
          'itemTypes': [
            {
              'name': 'FontOption',
              'dart': 'FontOption<T>',
              'fields': [
                {'dart': 'name'},
                // The default `FontGroup.system` and `true`.
                {'dart': 'system'},
                {'dart': 'available'},
                {'dart': 'true'},
                // A named argument of a call in a body.
                {'dart': 'extra'},
              ],
            },
          ],
        },
        {
          'name': 'Box',
          'flutterClass': 'Box',
          'kind': 'widget',
          'props': [
            {'dart': 'variant'},
            {'dart': 'b'},
          ],
        },
      ]),
      {
        'app/lib/design/components/forms/font_picker.dart': '''
enum FontGroup { document, system }
class FontPicker { const new({required this.fonts}); }
class FontOption<T> {
  const new({
    required this.name,
    this.group = FontGroup.system,
    this.available = true,
  });
  factory FontOption.of(String name) => FontOption(name: name, extra: 1);
  FontOption<T> copy() {
    return FontOption(name: name, extra: 2);
  }
}
''',
        'app/lib/design/components/core/box.dart': '''
enum Variant { a, b }
class Box { const new({this.variant = Variant.b}); }
''',
      },
    );
    String field(String name) =>
        "FontPicker: item type FontOption has no constructor parameter '$name' "
        '(app/lib/design/components/forms/font_picker.dart) [field]';
    const noProp =
        "Box: Box has no constructor parameter 'b' "
        '(app/lib/design/components/core/box.dart) [prop]';
    expect(
      problems,
      unorderedEquals([field('system'), field('true'), field('extra'), noProp]),
    );
  });

  test('reports a class where the spec wants an enum', () {
    final problems = _problems(_spec([_iconName]), {
      'app/lib/design/icons/icon_name.dart': 'class IconName {}\n',
    });
    expect(problems.single, contains('[kind]'));
  });

  test('reports a missing enum a prop names', () {
    final problems = _problems(_spec([_button]), {
      'app/lib/design/components/core/button.dart': '''
class Button {
  Button({required this.child, this.variant, this.disabledReason, this.onPressed});
}
''',
    });
    expect(problems, [
      'Button: no enum ButtonVariant in app/lib/design [enum]',
    ]);
  });

  test('reads classic, named and factory constructors and generics', () {
    final declarations = ComponentSpecCheck.declarationsIn(
      DartSource('app/lib/design/x.dart', '''
class Select<T> extends StatefulWidget {
  const Select({required this.options, this.value});
  Select.empty(this.placeholder) : options = const [];
  factory Select.of(List<T> items, {bool dense = false}) => Select(options: items);
  new other({required void Function(T) onChanged});
}
'''),
    );
    final select = declarations.single;
    expect(select.name, 'Select');
    // Not the default `false`, the `T` of a function type or the arguments
    // of the call in the factory's body.
    expect(select.parameters, {
      'options',
      'value',
      'placeholder',
      'items',
      'dense',
      'onChanged',
    });
  });

  test('reads factories written the Dart 3.13 way, by name alone', () {
    final declarations = ComponentSpecCheck.declarationsIn(
      DartSource('app/lib/design/x.dart', '''
class Select<T> {
  const new({required this.options});
  factory of(List<T> items, {bool dense = false}) => Select(options: items);
  factory _resolve(Locale? locale, FermanScript script) {
    return Select(options: const []);
  }
  const factory redirect({int z}) = _Other;
}
'''),
    );
    expect(declarations.single.parameters, {
      'options',
      'items',
      'dense',
      'locale',
      'script',
      'z',
    });
  });

  test('reads annotated constructors, function-typed formals and legacy '
      'defaults', () {
    final declarations = ComponentSpecCheck.declarationsIn(
      DartSource('app/lib/design/x.dart', '''
class Tile {
  @Deprecated('use new')
  const Tile.old(this.builder(BuildContext context)?, [int count = 0]);
  new({
    @required this.label,
    int depth: 2,
    Map<String, int> sizes = const {'a': 1, 'b': 2},
    void Function(int a, int b)? onPair,
  });
  static Tile make() => Tile(label: 'x', extra: true);
}
'''),
    );
    expect(declarations.single.parameters, {
      'builder',
      'count',
      'label',
      'depth',
      'sizes',
      'onPair',
    });
  });

  test('reads enhanced enum values and stops at the members', () {
    final declarations = ComponentSpecCheck.declarationsIn(
      DartSource('app/lib/design/x.dart', '''
enum FermanMode {
  view('view', IconName.eye),
  edit('edit', IconName.pen),
  fillSign('fill-sign', IconName.signature);

  const FermanMode(this.id, this.icon);
  final String id;
}
'''),
    );
    expect(declarations.single.values, {'view', 'edit', 'fillSign'});
    expect(declarations.single.parameters, {'id', 'icon'});
  });

  test('reports invalid JSON', () {
    final fixture = Fixture()
      ..write(ComponentSpecCheck.specPath, '{')
      ..write('app/lib/design/a.dart', '');
    expect(
      fixture.run(const ComponentSpecCheck()),
      failsWith(['is not valid JSON']),
    );
  });
}
