import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/link_open_dialog.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Kira sözleşmesi.pdf';

const List<LinkInfo> _links = [
  LinkInfo(
    handle: 1,
    page: 0,
    rect: Rect.fromLTWH(160, 180, 190, 16),
    kind: LinkKind.mail,
    target: 'mailto:mert.kaya@ornekposta.com.tr',
  ),
  LinkInfo(
    handle: 2,
    page: 0,
    rect: Rect.fromLTWH(160, 204, 190, 16),
    kind: LinkKind.mail,
    target: 'mailto:ayse.yilmaz@ornekposta.com.tr',
  ),
  LinkInfo(
    handle: 3,
    page: 0,
    rect: Rect.fromLTWH(320, 330, 40, 16),
    kind: LinkKind.file,
    target: 'Ek-1 Demirbaş listesi.xlsx',
  ),
  LinkInfo(
    handle: 4,
    page: 0,
    rect: Rect.fromLTWH(160, 400, 80, 16),
    kind: LinkKind.broken,
    wantedPage: 5,
  ),
];

/// a3-6's Link tool with its panel and popover, and G145's prompt, in light and
/// dark × en, tr and ar. Goldens run on Linux CI only.
Future<void> main() async {
  for (final screen in const ['links', 'link_prompt']) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        final engine = FakeEngineService(
          documents: const {
            _path: OpenedDocument(
              id: 1,
              pages: [
                PageInfo(width: 595, height: 842),
                PageInfo(width: 595, height: 842),
                PageInfo(width: 595, height: 842),
              ],
            ),
          },
        );
        engine.fakeLinks[1] = [..._links];
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board:
              screen == 'links' &&
                  theme == GoldenTheme.light &&
                  language == GoldenLanguage.en
              ? 'a3-6'
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ),
          engine: engine,
          // The prompt is a modal Dialog, which hides while tickers are muted.
          muteTickers: screen == 'links',
          open: (tester) async {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(FermanApp)),
            );
            await container.read(documentOpenerProvider.notifier).open([_path]);
            if (screen == 'links') {
              container
                  .read(shellModeProvider.notifier)
                  .select(FermanMode.edit);
              await tester.pump();
              container.read(linkToolProvider.notifier)
                ..toggle()
                ..mark(1);
            } else {
              container
                  .read(organizeDialogProvider.notifier)
                  .show(
                    const LinkOpenDialog(
                      link: LinkInfo(
                        handle: 9,
                        page: 0,
                        rect: Rect.zero,
                        kind: LinkKind.web,
                        target:
                            'https://www.ornekposta.com.tr/sozlesme/kira/2026',
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
