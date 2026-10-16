import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

Map<String, Object?> _spec(List<Map<String, Object?>> components) => {
  'enums': {
    'ButtonVariant': {
      'dart': ['primary', 'secondary', 'ghost', 'danger'],
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
    expect(
      select.parameters,
      containsAll(['options', 'value', 'placeholder', 'dense', 'onChanged']),
    );
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
