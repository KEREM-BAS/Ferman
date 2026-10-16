/// Writes the Dart source of `isolated_fallback.g.dart`.
library;

import 'package:l10n/src/errors.dart';
import 'package:l10n/src/messages.dart';

/// The first line of the generated file.
const String generatedHeader =
    '// GENERATED — do not edit; run (cd tools/l10n && dart run l10n)';

/// The generated class.
const String generatedClass = 'IsolatedFallbackLocalizations';

/// The members the generated class declares itself; a message with one of
/// these names would clash with them.
const Set<String> reservedNames = {
  'isolate',
  'delegate',
  'localizationsDelegates',
  'localeName',
};

/// Emits the library for [messages]. The result is valid Dart but not yet
/// formatted.
///
/// Throws an [L10nException] when there are no messages or a message is
/// named like one of [reservedNames].
String emitIsolatedFallback(List<Message> messages) {
  if (messages.isEmpty) {
    throw L10nException('the localizations class has no messages');
  }
  for (final message in messages) {
    if (reservedNames.contains(message.name)) {
      throw L10nException(
        'line ${message.line}: the message ${message.name} clashes with a '
        'member of $generatedClass',
      );
    }
  }
  final out = StringBuffer()
    ..write(_prologue)
    ..writeln();
  for (final message in messages) {
    out
      ..writeln('  @override')
      ..writeln(
        message.isGetter
            ? '  String get ${message.name} => '
                  'isolate(super.${message.name});'
            : '  String ${message.name}(${message.parameterList}) => '
                  'isolate(super.${message.name}(${message.argumentList}));',
      )
      ..writeln();
  }
  out
    ..writeln('}')
    ..write(_delegate);
  return out.toString();
}

const String _prologue =
    '''
$generatedHeader
//
// From the abstract members of app/lib/l10n/gen/app_localizations.dart, the
// gen-l10n output: run it after `flutter gen-l10n`. `dart run l10n --check`
// (in CI) fails while this file is stale (tools/l10n/README.md).

import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/gen/app_localizations_en.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The English strings, each wrapped in U+2066 LEFT-TO-RIGHT ISOLATE and
/// U+2069 POP DIRECTIONAL ISOLATE ([isolate]), for a right-to-left app
/// language without a translation (Persian and Hebrew today, G93).
///
/// Such a language mirrors the UI while its strings fall back to English
/// (G20). In a right-to-left paragraph an English string's numbers and
/// neutral characters would move: "1 of 2" would read "of 2 1" and "Open
/// file…" "…Open file". Inside the isolate each string keeps its own
/// left-to-right order, and the paragraph still places it at the start
/// (the right). Placeholder values keep their own direction: a language's
/// own name in Arabic or Hebrew script reads right to left inside the
/// isolate. Strings that already hold isolates (values in `bidiIsolate`)
/// nest correctly.
///
/// `FermanApp` installs it through [localizationsDelegates] while
/// `AppLanguage.isolatesFallbackStrings` holds; English, Turkish and Arabic
/// never see it. It overrides every message of [AppLocalizations] and wraps
/// [AppLocalizationsEn]'s text.
final class $generatedClass extends AppLocalizationsEn {
  /// The English strings, isolated.
  new();

  /// Loads [$generatedClass] for English, synchronously.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _${generatedClass}Delegate();

  /// [delegate], then the app's own delegates. `Localizations` loads the
  /// first delegate of each type that supports the locale, so [delegate]
  /// replaces [AppLocalizations.delegate].
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      [delegate, ...AppLocalizations.localizationsDelegates];

  /// [text] between U+2066 LEFT-TO-RIGHT ISOLATE and U+2069 POP DIRECTIONAL
  /// ISOLATE.
  static String isolate(String text) => '\\u2066\$text\\u2069';
''';

const String _delegate =
    '''

final class _${generatedClass}Delegate
    extends LocalizationsDelegate<AppLocalizations> {
  const new();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>($generatedClass());

  @override
  bool shouldReload(_${generatedClass}Delegate old) => false;
}
''';
