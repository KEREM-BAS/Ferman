import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'window_golden.dart';

/// The size of every phone golden: the iPhone 16 of the 13a and 13b boards,
/// at a device pixel ratio of 1.
const Size goldenPhoneSize = Size(393, 852);

/// The golden file name of a phone golden:
/// `<screen>_phone_<theme>_<lang>`, the contract with `tools/design-refs`'
/// comparison report.
String phoneGoldenFileName(
  String screen,
  GoldenTheme theme,
  GoldenLanguage language,
) => '${screen}_phone_${theme.name}_${language.name}';

/// Declares a golden of the whole app at [goldenPhoneSize], as a phone's
/// browser runs it: no title bar, the engine the web build has (none, so
/// opening stays in its future-version state), and Android as the platform,
/// which the layout does not read since it goes by width (G129). The rest
/// is [windowGoldenTest]'s, parameter by parameter.
Future<void> phoneGoldenTest({
  required String screen,
  required GoldenTheme theme,
  required GoldenLanguage language,
  required AppSettings settings,
  String? board,
  String? initialLocation,
  Future<void> Function(WidgetTester tester)? open,
  List<Override> overrides = const [],
  bool muteTickers = true,
}) => appGoldenTest(
  fileName: phoneGoldenFileName(screen, theme, language),
  size: goldenPhoneSize,
  platform: null,
  targetPlatform: TargetPlatform.android,
  shortcuts: ShortcutPlatform.windows,
  language: language,
  settings: settings,
  board: board,
  initialLocation: initialLocation,
  open: open,
  overrides: overrides,
  engine: const UnavailableEngineService(
    EngineUnavailableException(EngineUnavailableReason.unsupportedPlatform),
  ),
  muteTickers: muteTickers,
);
