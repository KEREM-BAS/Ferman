import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/signatures/add_signature_dialog.dart';
import 'package:ferman/features/signatures/saved_signatures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Adres değişikliği formu.pdf';
const String _folder = '/data/Signatures';
const String _name = 'Ayşe Yılmaz';

const OpenedDocument _document = OpenedDocument(
  id: 1,
  pages: [PageInfo(width: 595, height: 842)],
);

const AnnotationColor _blue = AnnotationColor(0.102, 0.192, 0.439);

const List<SavedSignature> _saved = [
  SavedSignature(
    name: 'signature-1.json',
    ink: TypedInk(text: _name, family: 'Caveat'),
    color: _blue,
  ),
  SavedSignature(
    name: 'signature-2.json',
    ink: DrawnInk(
      strokes: [
        [Offset(36, 92), Offset(80, 60), Offset(120, 96), Offset(180, 70)],
        [Offset(40, 122), Offset(340, 126)],
      ],
      width: 2.2,
    ),
    color: _blue,
  ),
  SavedSignature(
    name: 'initials-1.json',
    ink: TypedInk(text: 'AY', family: 'Dancing Script'),
    color: _blue,
    initials: true,
  ),
];

/// a5-3's dialog, a5-3d's Sign menu and a placed draft in light and dark ×
/// en, tr and ar. Goldens run on Linux CI only.
Future<void> main() async {
  const screens = ['sign_dialog', 'sign_menu', 'sign_place'];
  for (final screen in screens) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        final engine = FakeEngineService(documents: const {_path: _document});
        engine.savedSignatureFiles[_folder] = {
          for (final each in _saved) each.name: each.toFile(),
        };
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: theme == GoldenTheme.light && language == GoldenLanguage.en
              ? const {'sign_dialog': 'a5-3', 'sign_menu': 'a5-3d'}[screen]
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ).copyWith(commenterName: _name),
          engine: engine,
          overrides: [
            signatureDirectoryProvider.overrideWith((ref) async => _folder),
          ],
          // A Dialog and a popover hide while tickers are muted.
          muteTickers: false,
          // The menu lays itself out every frame (an OverlayPortal).
          layoutPortals: screen == 'sign_menu' ? 1 : 0,
          open: (tester) async {
            final context = tester.element(find.byType(FermanApp));
            final container = ProviderScope.containerOf(context);
            await container.read(documentOpenerProvider.notifier).open([_path]);
            container.read(shellModeProvider.notifier).select(FermanMode.sign);
            await tester.pumpAndSettle();
            switch (screen) {
              case 'sign_dialog':
                container
                    .read(organizeDialogProvider.notifier)
                    .show(const AddSignatureDialog(yourName: _name));
              case 'sign_menu':
                await tester.tap(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is ToolButton &&
                        widget.icon == IconName.signature,
                  ),
                );
              case 'sign_place':
                container
                    .read(signaturePlacementProvider.notifier)
                    .choose(_saved.first);
                await tester.pumpAndSettle();
                await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            }
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
