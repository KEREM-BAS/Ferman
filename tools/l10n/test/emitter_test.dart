import 'package:l10n/l10n.dart';
import 'package:test/test.dart';

void main() {
  group('emitIsolatedFallback', () {
    const getter = Message(name: 'shellHome', line: 1);
    const method = Message(
      name: 'invite',
      line: 2,
      parameters: [
        Parameter(
          name: 'host',
          kind: ParameterKind.positional,
          source: 'String host',
        ),
        Parameter(
          name: 'guest',
          kind: ParameterKind.named,
          source: 'required String guest',
        ),
      ],
    );

    test('starts with the generated header', () {
      expect(emitIsolatedFallback([getter]).split('\n').first, generatedHeader);
    });

    test('wraps a getter in the isolate', () {
      expect(
        emitIsolatedFallback([getter]),
        contains(
          '  @override\n'
          '  String get shellHome => isolate(super.shellHome);\n',
        ),
      );
    });

    test('wraps a method with its exact parameters and passes them on', () {
      expect(
        emitIsolatedFallback([method]),
        contains(
          '  @override\n'
          '  String invite(String host, {required String guest}) => '
          'isolate(super.invite(host, guest: guest));\n',
        ),
      );
    });

    test('subclasses the English class and installs its delegate first', () {
      final source = emitIsolatedFallback([getter]);
      expect(
        source,
        contains('final class $generatedClass extends AppLocalizationsEn {'),
      );
      expect(
        source,
        contains('[delegate, ...AppLocalizations.localizationsDelegates]'),
      );
      expect(
        source,
        contains(r"static String isolate(String text) => '\u2066$text\u2069';"),
      );
      expect(
        source,
        contains('extends LocalizationsDelegate<AppLocalizations>'),
      );
    });

    test('fails without messages or on a clashing name', () {
      expect(() => emitIsolatedFallback([]), throwsA(isA<L10nException>()));
      for (final name in reservedNames) {
        expect(
          () => emitIsolatedFallback([Message(name: name, line: 7)]),
          throwsA(
            isA<L10nException>().having(
              (e) => e.message,
              'message',
              contains('line 7: the message $name clashes'),
            ),
          ),
        );
      }
    });
  });
}
