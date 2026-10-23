/// **Proposed** (ROADMAP §5 step 10): a test-only pseudo-locale for text
/// expansion. It stands in for the German boards a12-2b and a12-2d, which
/// draw how much longer translated text gets; the app has no such locale.
///
/// [PseudoLocalizations] answers every [AppLocalizations] message with its
/// English text from `lib/l10n/app_en.arb`, made at least 40% longer:
/// accented letters ("Šéţţîñĝš"), padding, and a bracket at each end, so a
/// cut-off end shows ("[Šéţţîñĝš ábçðé]"). Placeholder values are inserted
/// unchanged. [pumpPseudoApp] runs the app's router with it, so a test can
/// check every M1 screen for overflow and clipping (`text_fit.dart`).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/foundation.dart';
// The test app is a MaterialApp, as FermanApp is.
import 'package:flutter/material.dart' show MaterialApp, Theme, ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The path of the English ARB file, from the app package (where
/// `flutter test` runs).
const String englishArbPath = 'lib/l10n/app_en.arb';

/// The opening marker of a pseudo-localized string.
const String pseudoStart = '[';

/// The closing marker: missing when the end of the text is cut off.
const String pseudoEnd = ']';

/// **Proposed.** The pseudo-locale's [AppLocalizations]: each message is
/// the English one from `app_en.arb`, [expansion] times as long (at least
/// two characters longer, for the markers), with accented letters when
/// [accents] is set.
///
/// With [expansion] 1, [accents] off and [markers] off it gives exactly the
/// English text, which a test compares with the real English screens.
///
/// It extends the generated class and answers its members through
/// [noSuchMethod], so it follows the ARB file without generated code of its
/// own: a getter returns its message, a method formats its message with
/// its arguments in the order of the message's `placeholders` (as
/// gen-l10n orders the parameters). It understands the ICU forms the ARB
/// files use: `{name}`, `plural` (`=n`, `zero`, `one`, `two`, `other`) and
/// `select`.
final class PseudoLocalizations extends AppLocalizations {
  /// The messages of [arb] (an ARB file's JSON), expanded.
  new(
    Map<String, Object?> arb, {
    this.expansion = 1.4,
    this.accents = true,
    this.markers = true,
  }) : _messages = {
         for (final MapEntry(:key, :value) in arb.entries)
           if (!key.startsWith('@') && value is String) key: value,
       },
       _placeholders = {
         for (final MapEntry(:key, :value) in arb.entries)
           if (!key.startsWith('@') && value is String)
             key: _placeholderNames(value, arb['@$key']),
       },
       super('en') {
    _symbols = {for (final key in _messages.keys) Symbol(key): key};
  }

  /// The pseudo-locale from the app's English ARB file.
  factory fromArb({
    double expansion = 1.4,
    bool accents = true,
    bool markers = true,
  }) => PseudoLocalizations(
    readArb(englishArbPath),
    expansion: expansion,
    accents: accents,
    markers: markers,
  );

  /// How much longer each message gets: 1.4 is 40% longer.
  final double expansion;

  /// Whether letters take accents.
  final bool accents;

  /// Whether the text is framed by [pseudoStart] and [pseudoEnd].
  final bool markers;

  final Map<String, String> _messages;
  final Map<String, List<String>> _placeholders;
  late final Map<Symbol, String> _symbols;

  /// The message keys this pseudo-locale answers.
  Iterable<String> get keys => _messages.keys;

  /// The pseudo-localized message [key] with [arguments] in placeholder
  /// order.
  String message(String key, [List<Object?> arguments = const []]) {
    final names = _placeholders[key]!;
    final values = {
      for (var i = 0; i < names.length && i < arguments.length; i++)
        names[i]: arguments[i],
    };
    final source = _messages[key]!;
    final english = formatMessage(source, values, (text) => text);
    final text = formatMessage(
      source,
      values,
      accents ? accentLetters : (text) => text,
    );
    return pad(text, english.length);
  }

  /// [text], [expansion] times [englishLength] long: padded, and framed
  /// when [markers] is set.
  String pad(String text, int englishLength) {
    final extra = (englishLength * (expansion - 1)).ceil();
    if (!markers) return text + _padding(extra, spaced: text.contains(' '));
    final padding = math.max(0, extra - pseudoStart.length - pseudoEnd.length);
    return '$pseudoStart$text'
        '${_padding(padding, spaced: text.contains(' '))}$pseudoEnd';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = _symbols[invocation.memberName];
    if (key == null || invocation.isSetter) {
      return super.noSuchMethod(invocation);
    }
    return message(key, invocation.positionalArguments);
  }
}

/// **Proposed.** Loads [localizations] for every locale: the pseudo-locale.
final class PseudoLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  /// A delegate that always gives [localizations].
  const new(this.localizations);

  /// The pseudo-locale.
  final AppLocalizations localizations;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(localizations);

  @override
  bool shouldReload(PseudoLocalizationsDelegate old) =>
      old.localizations != localizations;
}

/// The JSON object of the ARB file at [path].
Map<String, Object?> readArb(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

/// The placeholder names of [message], in the order gen-l10n gives the
/// generated method's parameters: the order of its metadata's
/// `placeholders`, else their order in the message.
List<String> _placeholderNames(String message, Object? metadata) {
  if (metadata case {'placeholders': final Map<String, Object?> declared}) {
    return declared.keys.toList();
  }
  return {
    for (final match in RegExp(r'\{(\w+)').allMatches(message)) match.group(1)!,
  }.toList();
}

/// [message] (an ICU message as gen-l10n reads it, without escaping) with
/// [values] for its placeholders and [literal] applied to its own text.
///
/// Placeholder values are inserted as they are. Supports `{name}`,
/// `{name, plural, …}` (English rules: `=n`, then `zero`, `one` and `two`
/// for 0, 1 and 2, then `other`) and `{name, select, …}`.
String formatMessage(
  String message,
  Map<String, Object?> values,
  String Function(String text) literal,
) {
  final out = StringBuffer();
  final text = StringBuffer();
  void flush() {
    if (text.isEmpty) return;
    out.write(literal(text.toString()));
    text.clear();
  }

  var i = 0;
  while (i < message.length) {
    if (message[i] == '{') {
      final end = _matchingBrace(message, i);
      flush();
      out.write(_argument(message.substring(i + 1, end), values, literal));
      i = end + 1;
    } else {
      text.write(message[i]);
      i++;
    }
  }
  flush();
  return out.toString();
}

String _argument(
  String body,
  Map<String, Object?> values,
  String Function(String text) literal,
) {
  final firstComma = body.indexOf(',');
  if (firstComma < 0) return '${values[body.trim()]}';
  final name = body.substring(0, firstComma).trim();
  final rest = body.substring(firstComma + 1);
  final secondComma = rest.indexOf(',');
  final kind = rest.substring(0, secondComma).trim();
  final cases = _cases(rest.substring(secondComma + 1));
  final value = values[name];
  final chosen = switch (kind) {
    'plural' => _pluralCase(cases, value! as num),
    'select' => cases['$value'] ?? cases['other'],
    _ => throw UnsupportedError('ICU form "$kind" in "{$body}"'),
  };
  if (chosen == null) throw FormatException('no case for $value', body);
  return formatMessage(chosen, values, literal);
}

String? _pluralCase(Map<String, String> cases, num count) =>
    cases['=$count'] ??
    switch (count) {
      0 => cases['zero'],
      1 => cases['one'],
      2 => cases['two'],
      _ => null,
    } ??
    cases['other'];

Map<String, String> _cases(String source) {
  final cases = <String, String>{};
  var i = 0;
  while (i < source.length) {
    final open = source.indexOf('{', i);
    if (open < 0) break;
    final selector = source.substring(i, open).trim();
    final close = _matchingBrace(source, open);
    cases[selector] = source.substring(open + 1, close);
    i = close + 1;
  }
  return cases;
}

int _matchingBrace(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}' && --depth == 0) return i;
  }
  throw FormatException('unbalanced braces', source, open);
}

/// Each ASCII letter of [text] with an accent that IBM Plex Sans has, in
/// both cases (so locale-aware upper and lower case stay in the font);
/// letters without such a form stay as they are.
String accentLetters(String text) => String.fromCharCodes([
  for (final unit in text.codeUnits)
    switch (unit) {
      >= 0x61 && <= 0x7A => _lower.codeUnitAt(unit - 0x61),
      >= 0x41 && <= 0x5A => _upper.codeUnitAt(unit - 0x41),
      _ => unit,
    },
]);

/// a to z with accents (b, f, m, q, v and x unchanged).
const String _lower = 'ábçðéfĝĥîĵķļmñöþqŕšţûvŵxýž';

/// A to Z with accents, the upper case of [_lower].
const String _upper = 'ÁBÇÐÉFĜĤÎĴĶĻMÑÖÞQŔŠŢÛVŴXÝŽ';

/// [count] characters of padding: accented letters, in words of up to six
/// letters after a space when [spaced] (the text has spaces, so it can
/// wrap there), else one run that lengthens the last word.
String _padding(int count, {required bool spaced}) {
  if (count <= 0) return '';
  final out = StringBuffer();
  var letter = 0;
  for (var i = 0; i < count; i++) {
    if (spaced && i % 7 == 0) {
      out.write(' ');
    } else {
      out.write(_lower[letter++ % _lower.length]);
    }
  }
  return out.toString();
}

/// **Proposed.** Runs the app's router (first run, the start screen,
/// Settings) with the pseudo-locale [localizations], as `FermanApp` runs
/// it: the same delegates after the app's own, the light theme, the
/// left-to-right direction of the English UI, the resolved Ferman theme
/// and the app surface. The window is [size]; [window] draws a title bar
/// (none by default). [settings] are stored in a [MemorySettingsStore].
///
/// `FermanApp` cannot take another delegate, so this mirrors its builder;
/// keep the two in step.
Future<void> pumpPseudoApp(
  WidgetTester tester, {
  required AppLocalizations localizations,
  AppSettings settings = const AppSettings(onboardingCompleted: true),
  Size size = const Size(1440, 900),
  DesktopWindow? window,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(MemorySettingsStore(settings)),
        initialSettingsProvider.overrideWithValue(settings),
        engineServiceProvider.overrideWithValue(const FakeEngineService()),
        if (window != null) desktopWindowProvider.overrideWithValue(window),
      ],
      child: _PseudoApp(localizations),
    ),
  );
  await tester.pumpAndSettle();
}

class _PseudoApp extends ConsumerWidget {
  const new(this.localizations);

  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: [
      PseudoLocalizationsDelegate(localizations),
      ...AppLocalizations.localizationsDelegates.skip(1),
    ],
    supportedLocales: const [Locale('en')],
    locale: const Locale('en'),
    theme: FermanMaterialTheme.light,
    darkTheme: FermanMaterialTheme.dark,
    themeMode: ThemeMode.light,
    builder: (context, child) => Directionality(
      textDirection: TextDirection.ltr,
      child: FermanThemeScope(
        touch: FermanThemeScope.isTouchPlatform(Theme.of(context).platform),
        child: _Surface(child: child),
      ),
    ),
    routerConfig: ref.watch(routerProvider),
  );
}

/// The app's background (`--surface-panel`), as `FermanApp` paints it.
class _Surface extends StatelessWidget {
  const new({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.ferman.colors.surfacePanel,
    child: child ?? const SizedBox.shrink(),
  );
}
