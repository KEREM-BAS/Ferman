import 'package:ferman/engine/engine_problem.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/recent/recent_previews.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../helpers/phone_golden.dart';
import '../helpers/window_golden.dart';

/// The recent files of a13-2c, dated long ago, so each row shows a date that
/// does not depend on today.
final List<RecentEntry> _recent = [
  RecentEntry(
    path: '/home/ayse/Belgeler/Kira sözleşmesi.pdf',
    name: 'Kira sözleşmesi.pdf',
    opened: DateTime(2025, 10, 13, 14, 32),
    pages: 3,
    pinned: true,
    signed: true,
  ),
  RecentEntry(
    path: '/home/ayse/Belgeler/Yüksek lisans tezi.pdf',
    name: 'Yüksek lisans tezi.pdf',
    opened: DateTime(2025, 10, 12, 11, 5),
    pages: 64,
    pinned: true,
  ),
  RecentEntry(
    path: '/home/ayse/Belgeler/Adres değişikliği formu.pdf',
    name: 'Adres değişikliği formu.pdf',
    opened: DateTime(2025, 10, 11, 9, 5),
    pages: 2,
    form: true,
  ),
  RecentEntry(
    path: '/home/ayse/Belgeler/Tarama 0412.pdf',
    name: 'Tarama 0412.pdf',
    opened: DateTime(2025, 10, 10, 17, 48),
    pages: 6,
    scanned: true,
  ),
];

List<Override> _withFiles() => [
  initialRecentFilesProvider.overrideWithValue(_recent),
  recentFilesStoreProvider.overrideWithValue(MemoryRecentFilesStore(_recent)),
  recentPreviewStoreProvider.overrideWithValue(MemoryRecentPreviewStore()),
];

/// The phone's home (a13-2c, a13-2e; G129), empty as the web build always is,
/// with files, and with the notice of G101, each in light and dark × en, tr
/// and ar.
Future<void> main() async {
  final screens = <(String, List<Override>)>[
    ('start', const []),
    ('start_recent', _withFiles()),
    (
      'start_no_pdfium',
      [
        engineProblemProvider.overrideWithValue(
          const EngineProblem('engine: 0.1.0\npdfium: not loaded'),
        ),
      ],
    ),
  ];
  for (final (screen, overrides) in screens) {
    for (final theme in GoldenTheme.values) {
      for (final language in const [
        GoldenLanguage.en,
        GoldenLanguage.tr,
        GoldenLanguage.ar,
      ]) {
        await phoneGoldenTest(
          screen: screen,
          theme: theme,
          language: language,
          board:
              screen == 'start' &&
                  theme == GoldenTheme.light &&
                  language == GoldenLanguage.en
              ? 'a13-2e'
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ),
          overrides: overrides,
        );
      }
    }
  }
}
