import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/settings/general_pane.dart';
import 'package:ferman/platform/default_app.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../onboarding/ferman_app_harness.dart';

/// macOS as a test sees it: [handler] opens PDF files until Ferman is made
/// the default.
final class _FakeDefaultApp implements DefaultPdfApp {
  new(this.handler);

  PdfHandler? handler;
  int asked = 0;

  @override
  Future<PdfHandler?> current() async => handler;

  @override
  Future<bool> makeFerman() async {
    asked++;
    handler = const PdfHandler(name: 'Ferman', ferman: true);
    return true;
  }
}

const PdfHandler _preview = PdfHandler(name: 'Preview', ferman: false);

final Finder _prompt = find.text('Open PDFs with Ferman?');

void main() {
  testWidgets('a1-3 names the app that opens PDFs; Use Ferman for PDFs asks '
      'the system and never asks again (B080)', (tester) async {
    final app = _FakeDefaultApp(_preview);
    final store = await pumpFermanApp(tester, defaultApp: app);
    expect(_prompt, findsOne);
    expect(find.textContaining('Preview'), findsOne);

    await tester.tap(find.text('Use Ferman for PDFs'));
    await tester.pumpAndSettle();
    expect(app.asked, 1);
    expect(_prompt, findsNothing);
    expect((await store.load()).askDefaultApp, isFalse);
  });

  testWidgets('Not now asks again next time; with Don’t ask again it never '
      'does', (tester) async {
    final store = await pumpFermanApp(
      tester,
      defaultApp: _FakeDefaultApp(_preview),
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(_prompt, findsNothing);
    expect((await store.load()).askDefaultApp, isTrue);

    // A new run: the app starts again with its own state.
    await tester.pumpWidget(const SizedBox());
    final again = await pumpFermanApp(
      tester,
      defaultApp: _FakeDefaultApp(_preview),
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect((await again.load()).askDefaultApp, isFalse);
  });

  testWidgets('nothing asks when Ferman already opens PDFs, the system does '
      'not say, or it was turned down', (tester) async {
    await pumpFermanApp(
      tester,
      defaultApp: _FakeDefaultApp(
        const PdfHandler(name: 'Ferman', ferman: true),
      ),
    );
    expect(_prompt, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await pumpFermanApp(tester);
    expect(_prompt, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await pumpFermanApp(
      tester,
      settings: const AppSettings(
        onboardingCompleted: true,
        askDefaultApp: false,
      ),
      defaultApp: _FakeDefaultApp(_preview),
    );
    expect(_prompt, findsNothing);
  });

  testWidgets('Settings › General on macOS names the app and makes Ferman '
      'the default; then it says Ferman opens PDFs', (tester) async {
    final app = _FakeDefaultApp(_preview);
    await pumpFermanApp(
      tester,
      settings: const AppSettings(
        onboardingCompleted: true,
        askDefaultApp: false,
      ),
      defaultApp: app,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.byType(GeneralPane), findsOne);
    expect(find.textContaining('opens PDFs on this Mac.'), findsOne);

    await tester.tap(find.text('Make Ferman the default…'));
    await tester.pumpAndSettle();
    expect(app.asked, 1);
    expect(find.text('Ferman opens PDFs on this Mac.'), findsOne);
    expect(find.text('Make Ferman the default…'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
