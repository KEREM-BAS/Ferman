import 'package:l10n/l10n.dart';
import 'package:test/test.dart';

import 'support.dart';

List<Message> _parse(String members) =>
    parseMessages(classWith(members), className: 'AppLocalizations');

Matcher _fails(String message) => throwsA(
  isA<L10nException>().having((e) => e.message, 'message', contains(message)),
);

void main() {
  group('parseMessages', () {
    test('reads getters and skips the constructor, fields and statics', () {
      final messages = _parse('''
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Tooltip of the home button, which the doc comment says is
  /// `String get notAMessage;`.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellHome;

  String get shellOpenFile;
''');
      expect(messages.map((m) => m.signature), [
        'String get shellHome',
        'String get shellOpenFile',
      ]);
      expect(messages.every((m) => m.isGetter), isTrue);
      expect(messages.first.line, 25);
    });

    test('reads methods with their typed parameters', () {
      final messages = _parse('''
  String shellPageOf(String page, String count);

  String onboardingFeatureLanguages(
    int count,
    String formatted,
  );

  String dated(DateTime date, num amount, Object value);
''');
      expect(messages.map((m) => m.signature), [
        'String shellPageOf(String page, String count)',
        'String onboardingFeatureLanguages(int count, String formatted)',
        'String dated(DateTime date, num amount, Object value)',
      ]);
      final languages = messages[1];
      expect(languages.isGetter, isFalse);
      expect(languages.parameters!.map((p) => p.name), ['count', 'formatted']);
      expect(
        languages.parameters!.map((p) => p.kind),
        everyElement(ParameterKind.positional),
      );
      expect(languages.argumentList, 'count, formatted');
    });

    test('reads optional positional parameters with defaults', () {
      final message = _parse(
        "  String greet(String name, [int times = 1, String? suffix = ',']);",
      ).single;
      expect(
        message.parameterList,
        "String name, [int times = 1, String? suffix = ',']",
      );
      expect(message.parameters!.map((p) => (p.name, p.kind)), [
        ('name', ParameterKind.positional),
        ('times', ParameterKind.optionalPositional),
        ('suffix', ParameterKind.optionalPositional),
      ]);
      expect(message.argumentList, 'name, times, suffix');
    });

    test('reads named parameters, required, nullable or with defaults', () {
      final message = _parse('''
  String invite(
    String host, {
    required String guest,
    int? seats,
    Map<String, List<int>> tables = const {'a': [1, 2]},
    void Function(int, String)? onDone,
  });
''').single;
      expect(message.parameters!.map((p) => (p.name, p.kind)), [
        ('host', ParameterKind.positional),
        ('guest', ParameterKind.named),
        ('seats', ParameterKind.named),
        ('tables', ParameterKind.named),
        ('onDone', ParameterKind.named),
      ]);
      expect(
        message.parameterList,
        'String host, {required String guest, int? seats, '
        "Map<String, List<int>> tables = const {'a': [1, 2]}, "
        'void Function(int, String)? onDone}',
      );
      expect(
        message.argumentList,
        'host, guest: guest, seats: seats, tables: tables, onDone: onDone',
      );
    });

    test('reads a method without parameters and skips annotations', () {
      final messages = _parse('''
  @Deprecated('use b')
  String a();

  @override String get b;
''');
      expect(messages.map((m) => m.signature), ['String a()', 'String get b']);
      expect(messages.first.parameters, isEmpty);
    });

    test('ignores members of other classes', () {
      expect(_parse('  String get only;').map((m) => m.name), ['only']);
    });

    test('is deterministic and keeps the source order', () {
      const members = '  String get b;\n  String a(int x);\n  String get c;';
      expect(
        _parse(members).map((m) => m.signature),
        _parse(members).map((m) => m.signature),
      );
      expect(_parse(members).map((m) => m.name), ['b', 'a', 'c']);
    });

    test('fails on members it cannot wrap', () {
      expect(() => _parse('  int get count;'), _fails('returns int'));
      expect(
        () => _parse('  String? maybe(String a);'),
        _fails('returns String?'),
      );
      expect(
        () => _parse("  String get done => 'x';"),
        _fails('concrete member'),
      );
      expect(
        () => _parse("  String done() {\n    return 'x';\n  }"),
        _fails('concrete member'),
      );
      expect(() => _parse('  set name(String value);'), _fails('setters'));
      expect(
        () => _parse('  String operator +(String other);'),
        _fails('operators'),
      );
      expect(() => _parse('  String pick<T>(T a);'), _fails('generic'));
      expect(() => _parse('  noType(String a);'), _fails('return type'));
      expect(() => _parse('  String plain;'), _fails('unsupported member'));
      expect(() => _parse("  String withValue = 'x';"), _fails('initializer'));
      expect(
        () => _parse('  String get a;\n  String a(int x);'),
        _fails('declared twice'),
      );
    });

    test('fails on parameters it cannot pass on', () {
      expect(
        () => _parse('  String apply(String f(int x));'),
        _fails('unsupported parameter'),
      );
      expect(
        () => _parse('  String apply(this.x);'),
        _fails('this. and super.'),
      );
      expect(
        () => _parse('  String apply([int a], String b);'),
        _fails('after the optional parameters'),
      );
    });

    test('fails without the abstract class', () {
      expect(
        () => parseMessages(
          'class AppLocalizations {}',
          className: 'AppLocalizations',
        ),
        _fails('no abstract class AppLocalizations'),
      );
    });

    test('reads the real gen-l10n output', () {
      final messages = parseMessages(
        readInput(),
        className: localizationsClass,
      );
      expect(messages.length, greaterThan(250));
      expect(messages.map((m) => m.name).toSet(), hasLength(messages.length));
      final pageOf = messages.firstWhere((m) => m.name == 'shellPageOf');
      expect(pageOf.signature, 'String shellPageOf(String page, String count)');
      final languages = messages.firstWhere(
        (m) => m.name == 'onboardingFeatureLanguages',
      );
      expect(languages.parameterList, 'int count, String formatted');
    });
  });

  group('parseParameters', () {
    test('splits at top-level commas only', () {
      const text = 'Map<String, int> a, (int, String) b, List<Map<int, int>> c';
      expect(parseParameters(text, text).map((p) => p.name), ['a', 'b', 'c']);
    });

    test('accepts a trailing comma and an empty list', () {
      expect(parseParameters('int a, ', 'int a, ').map((p) => p.name), ['a']);
      expect(parseParameters('', ''), isEmpty);
      expect(
        parseParameters('{int? a,}', '{int? a,}').single.kind,
        ParameterKind.named,
      );
    });
  });
}
