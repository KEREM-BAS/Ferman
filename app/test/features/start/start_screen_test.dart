import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/settings/settings_screen.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../onboarding/ferman_app_harness.dart';

const _future = 'Available in a future version';

void main() {
  testWidgets('shows the actions, quick tools and drop area of a1-5', (
    tester,
  ) async {
    await pumpFermanApp(tester);
    for (final text in [
      'Open file…',
      'PDF files',
      'Create PDF',
      'From a blank page, files or the clipboard',
      'Combine files',
      'Merge several files into one PDF',
      'Scan to PDF',
      'From a scanner or a phone camera',
      'Quick tools',
      'Compress',
      'Convert',
      'Sign',
      'Recognize text (OCR)',
      'Protect',
      'Compare',
      'Drop a PDF here',
      'or open one from your computer.',
      'Files stay on this device. Ferman never uploads them.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byType(DropZone), findsOneWidget);
    // G11: no conversion promise until conversion ships.
    expect(find.textContaining('converted'), findsNothing);
    expect(find.textContaining('Word'), findsNothing);
  });

  testWidgets('every entry point is disabled with the reason (G10)', (
    tester,
  ) async {
    await pumpFermanApp(tester);
    for (final label in [
      'Open file…. PDF files',
      'Create PDF. From a blank page, files or the clipboard',
      'Combine files. Merge several files into one PDF',
      'Scan to PDF. From a scanner or a phone camera',
    ]) {
      final card = find.bySemanticsLabel(label);
      expect(card, findsOneWidget, reason: label);
      expect(tester.getSemantics(card).hint, _future, reason: label);
    }
    for (final label in [
      'Compress',
      'Convert',
      'Sign',
      'Recognize text (OCR)',
      'Protect',
      'Compare',
      'Open a PDF',
      'New blank PDF',
    ]) {
      final button = find.ancestor(
        of: find.textContaining(label),
        matching: find.byType(FermanInteractive),
      );
      expect(button, findsWidgets, reason: label);
      final interactive = tester.widget<FermanInteractive>(button.first);
      expect(interactive.onPressed, isNull, reason: label);
      expect(interactive.disabledReason, _future, reason: label);
    }
    final zone = tester.widget<DropZone>(find.byType(DropZone));
    expect(zone.disabledReason, _future);
  });

  testWidgets('shows the platform’s shortcut caps', (tester) async {
    await pumpFermanApp(tester);
    final caps = [
      for (final kbd in tester.widgetList<Kbd>(find.byType(Kbd))) kbd.keys,
    ];
    expect(caps, [
      ['⌘', 'O'],
      ['⌘', 'N'],
    ]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('shows Ctrl on Windows', (tester) async {
    await pumpFermanApp(tester);
    expect(tester.widget<Kbd>(find.byType(Kbd).first).keys, ['Ctrl', 'O']);
    expect(tester.widget<DropZone>(find.byType(DropZone)).shortcut, [
      'Ctrl',
      'O',
    ]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  /// Sends [key] with [modifier] held.
  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+, opens Settings on Linux; ⌘, does not', (tester) async {
    await pumpFermanApp(tester);
    await press(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.comma);
    expect(find.byType(FmSettings), findsNothing);
    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.comma,
    );
    expect(find.byType(FmSettings), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FmStart), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('⌘, opens Settings on macOS; Ctrl+, does not', (tester) async {
    await pumpFermanApp(tester);
    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.comma,
    );
    expect(find.byType(FmSettings), findsNothing);
    await press(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.comma);
    expect(find.byType(FmSettings), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  group('in en, tr and ar', () {
    for (final (code, direction, title) in const [
      ('en', TextDirection.ltr, 'Open file…'),
      ('tr', TextDirection.ltr, 'Dosya aç…'),
      ('ar', TextDirection.rtl, 'فتح ملف…'),
    ]) {
      for (final size in const [boardSize, Size(1024, 680)]) {
        final name = '$code at ${size.width.toInt()} × ${size.height.toInt()}';
        testWidgets(name, (tester) async {
          await pumpFermanApp(
            tester,
            settings: AppSettings(
              onboardingCompleted: true,
              languageCode: code,
            ),
            size: size,
          );
          expect(tester.takeException(), isNull);
          expect(localeOf(tester, find.byType(FmStart)), Locale(code));
          expect(directionOf(tester, find.byType(FmStart)), direction);
          expect(find.text(title), findsOneWidget);
        });
      }
    }

    testWidgets('right to left mirrors the order (a12-2a)', (tester) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          languageCode: 'ar',
        ),
      );
      // The first card (Open file…) sits at the right, the last (Scan to
      // PDF) at the left; the quick-tools label leads at the right too.
      final open = tester.getCenter(find.text('فتح ملف…')).dx;
      final scan = tester.getCenter(find.text('مسح ضوئي إلى PDF')).dx;
      expect(open, greaterThan(scan));
      final label = tester.getCenter(find.text('أدوات سريعة')).dx;
      final compress = tester.getCenter(find.text('ضغط')).dx;
      expect(label, greaterThan(compress));
    });

    testWidgets('Turkish quick tools come from the design', (tester) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          languageCode: 'tr',
        ),
      );
      for (final text in ['Sıkıştır', 'Dönüştür', 'İmzala', 'Koru']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });
  });
}
