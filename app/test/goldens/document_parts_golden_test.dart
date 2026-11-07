import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/document_parts.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Yüksek lisans tezi.pdf';

/// a2-3a's thesis outline, its third page signed.
FakeEngineService _engine() => FakeEngineService(
  documents: {
    _path: OpenedDocument(
      id: 1,
      pages: const [
        PageInfo(width: 595, height: 842, handle: 1),
        PageInfo(width: 595, height: 842, handle: 2),
        PageInfo(width: 595, height: 842, handle: 3),
      ],
      outline: const [
        OutlineEntry(title: 'ÖZET', page: 0),
        OutlineEntry(title: 'ABSTRACT', page: 0),
        OutlineEntry(title: '1. GİRİŞ', page: 0, open: true),
        OutlineEntry(title: '1.1 Araştırmanın amacı', page: 0, depth: 1),
        OutlineEntry(title: '1.2 Yöntem ve veri', page: 1, depth: 1),
        OutlineEntry(title: '2. KENTSEL DÖNÜŞÜM VE KİRA', page: 1, open: true),
        OutlineEntry(title: '2.1 Yasal çerçeve', page: 1, depth: 1),
        OutlineEntry(
          title: '2.2 İstanbul’da kira artışları',
          page: 1,
          depth: 1,
        ),
        OutlineEntry(title: '3. BULGULAR', page: 2),
        OutlineEntry(title: '4. SONUÇ', page: 2),
        OutlineEntry(title: 'KAYNAKÇA', page: 2),
      ],
      signatures: [
        Signature(
          field: 'Imza',
          signed: true,
          signer: 'Elif Demir',
          signedAt: DateTime(2026, 10, 13, 11, 4),
          page: 2,
        ),
      ],
    ),
  },
);

/// Sends desktop_drop's [method] as its runner would.
Future<void> _drop(WidgetTester tester, String method, Object? arguments) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'desktop_drop',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );

/// M4 W6 in light and dark × en, tr and ar with macOS chrome: a2-3a's
/// bookmark renamed in place, f5's badge legend open over the Pages tab,
/// and a1-6's overlay with the pointer over "Combine into one PDF". Goldens
/// run on Linux CI only.
Future<void> main() async {
  for (final screen in const [
    'outline_rename',
    'badge_legend',
    'drop_combine',
  ]) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: theme == GoldenTheme.light && language == GoldenLanguage.en
              ? switch (screen) {
                  'outline_rename' => 'a2-3a',
                  'badge_legend' => 'f5',
                  _ => 'a1-6',
                }
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ),
          engine: _engine(),
          open: (tester) async {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(FermanApp)),
            );
            if (screen == 'drop_combine') {
              await _drop(tester, 'entered', <double>[720, 450]);
              await tester.pumpAndSettle();
              final over = tester.getCenter(
                find
                    .byWidgetPredicate(
                      (widget) =>
                          widget is Icon && widget.name == IconName.merge,
                    )
                    .last,
              );
              await _drop(tester, 'updated', <double>[over.dx, over.dy]);
              await tester.pumpAndSettle();
              return;
            }
            await container.read(documentOpenerProvider.notifier).open([_path]);
            await tester.pumpAndSettle();
            if (screen == 'outline_rename') {
              container
                  .read(shellSidebarTabProvider.notifier)
                  .select(SidebarTab.outline);
              container.read(outlineRenamingProvider.notifier).start(8);
            } else {
              await tester.tap(
                find.descendant(
                  of: find.byType(FmSidebar),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is IconButton && widget.icon == IconName.info,
                  ),
                ),
              );
            }
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
