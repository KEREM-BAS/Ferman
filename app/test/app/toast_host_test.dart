import 'package:ferman/app/app.dart';
import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/features/shell/shell_status_bar.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/onboarding/ferman_app_harness.dart';
import '../features/shell/shell_host.dart';
import '../helpers/fake_desktop_window.dart';

final class _FailingStore implements SettingsStore {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async =>
      throw const SettingsStoreException('disk full');
}

ToastNotices _notices(WidgetTester tester, [Type widget = FermanApp]) =>
    ProviderScope.containerOf(tester.element(find.byType(widget)))
        .read(toastNoticesProvider.notifier);

int _show(
  WidgetTester tester,
  String title, {
  ToastTone tone = ToastTone.neutral,
  VoidCallback? onUndo,
}) => _notices(tester).show(
  title: (_) => title,
  tone: tone,
  action: onUndo == null ? null : (label: (_) => 'Undo', onPressed: onUndo),
);

/// A slight move past the toast's rise-in, short of its time.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('shows on the start screen and leaves after six seconds', (
    tester,
  ) async {
    await pumpFermanApp(tester);
    _show(tester, 'Saved');
    await _frames(tester);
    expect(find.text('Saved'), findsOne);
    await tester.pump(ToastHost.lifetime - const Duration(seconds: 2));
    expect(find.text('Saved'), findsOne);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('an error stays until dismissed', (tester) async {
    await pumpFermanApp(tester);
    _show(tester, 'Couldn’t save', tone: ToastTone.danger);
    await _frames(tester);
    await tester.pump(ToastHost.lifetime * 10);
    expect(find.text('Couldn’t save'), findsOne);
    await tester.tap(
      find.descendant(
        of: find.byType(Toast),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pump();
    expect(find.byType(Toast), findsNothing);
  });

  testWidgets('hovering holds a toast; leaving starts its time again', (
    tester,
  ) async {
    await pumpFermanApp(tester);
    _show(tester, 'Saved');
    await _frames(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.byType(Toast)));
    await tester.pump();
    await tester.pump(ToastHost.lifetime * 2);
    expect(find.text('Saved'), findsOne);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(ToastHost.lifetime - const Duration(seconds: 1));
    expect(find.text('Saved'), findsOne);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('focus in a toast holds it', (tester) async {
    await pumpFermanApp(tester);
    _show(tester, 'Pages deleted', onUndo: () {});
    await _frames(tester);
    final focus = Focus.of(tester.element(find.text('Undo')))..requestFocus();
    await tester.pump();
    await tester.pump(ToastHost.lifetime * 2);
    expect(find.text('Pages deleted'), findsOne);
    focus.unfocus();
    await tester.pump();
    await tester.pump(ToastHost.lifetime);
    await tester.pump();
    expect(find.text('Pages deleted'), findsNothing);
  });

  testWidgets('its action runs and takes the toast away', (tester) async {
    await pumpFermanApp(tester);
    var undone = 0;
    _show(tester, 'Pages deleted', onUndo: () => undone++);
    await _frames(tester);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(undone, 1);
    expect(find.text('Pages deleted'), findsNothing);
  });

  testWidgets('at most three show; the one past them waits', (tester) async {
    await pumpFermanApp(tester);
    final first = _show(tester, 'One', tone: ToastTone.danger);
    _show(tester, 'Two', tone: ToastTone.danger);
    _show(tester, 'Three', tone: ToastTone.danger);
    final fourth = _show(tester, 'Four', tone: ToastTone.danger);
    await _frames(tester);
    expect(find.byType(Toast), findsNWidgets(3));
    expect(find.text('One'), findsNothing);
    // Newest lowest.
    expect(
      tester.getTopLeft(find.text('Four')).dy,
      greaterThan(tester.getTopLeft(find.text('Two')).dy),
    );
    _notices(tester).dismiss(fourth);
    await _frames(tester);
    expect(find.text('One'), findsOne);
    _notices(tester).dismiss(first);
  });

  testWidgets('a waiting toast does not run its time', (tester) async {
    await pumpFermanApp(tester);
    _show(tester, 'Quiet');
    final ids = [
      for (final title in ['A', 'B', 'C'])
        _show(tester, title, tone: ToastTone.danger),
    ];
    await _frames(tester);
    await tester.pump(ToastHost.lifetime * 2);
    expect(find.text('Quiet'), findsNothing);
    _notices(tester).dismiss(ids.last);
    await _frames(tester);
    expect(find.text('Quiet'), findsOne);
  });

  group('placement', () {
    testWidgets('bottom end, with no status bar on the start screen', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      _show(tester, 'Saved');
      await _frames(tester);
      final toast = tester.getRect(find.byType(Toast));
      expect(toast.right, boardSize.width - 16);
      expect(toast.bottom, boardSize.height - 12);
      expect(toast.width, Toast.width);
    });

    testWidgets('mirrors in Arabic', (tester) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          languageCode: 'ar',
        ),
      );
      _show(tester, 'Saved');
      await _frames(tester);
      expect(tester.getTopLeft(find.byType(Toast)).dx, 16);
    });

    testWidgets('above the status bar, and above the open task drawer', (
      tester,
    ) async {
      final window = FakeDesktopWindow(WindowPlatform.linux);
      addTearDown(window.dispose);
      await pumpShell(tester, shellHost(window: window));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ToastHost)),
      );
      final id = container
          .read(toastNoticesProvider.notifier)
          .show(title: (_) => 'Saved', tone: ToastTone.danger);
      await _frames(tester);
      final bar = tester.getRect(find.byType(ShellStatusBar));
      expect(tester.getRect(find.byType(Toast)).bottom, bar.top - 12);

      container.read(taskDrawerHeightProvider.notifier).set(200);
      await _frames(tester);
      expect(tester.getRect(find.byType(Toast)).bottom, bar.top - 212);
      container.read(toastNoticesProvider.notifier).dismiss(id);
    });

    testWidgets('three long toasts fit a phone, and a short window scrolls', (
      tester,
    ) async {
      const phone = Size(360, 320);
      expect(WindowMetrics.isPhoneWidth(phone.width), isTrue);
      await pumpFermanApp(tester, size: phone);
      for (final title in ['One', 'Two', 'Three']) {
        _notices(tester).show(
          title: (_) => title,
          message: (_) => 'A long explanation of what happened. ' * 5,
          tone: ToastTone.danger,
        );
      }
      await _frames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(Toast), findsNWidgets(3));
      final toast = tester.getRect(find.byType(Toast).last);
      expect(toast.left, 16);
      expect(toast.right, phone.width - 16);
      expect(toast.bottom, phone.height - 12);
    });
  });

  group('first run (B089)', () {
    const firstRun = AppSettings();

    testWidgets('a language that cannot be stored says so', (tester) async {
      await pumpFermanApp(tester, settings: firstRun, store: _FailingStore());
      await tester.tap(find.text('Türkçe'));
      await tester.pump();
      await _frames(tester);
      final toast = tester.widget<Toast>(find.byType(Toast));
      expect(toast.tone, ToastTone.warning);
      // In the language that now shows.
      expect(toast.title, 'Ayarlarınız kaydedilemedi.');
      await tester.pump(ToastHost.lifetime);
      await tester.pump();
      expect(find.byType(Toast), findsNothing);
    });

    testWidgets('an end of first run that cannot be stored says so, on the '
        'start screen', (tester) async {
      await pumpFermanApp(tester, settings: firstRun, store: _FailingStore());
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start using Ferman'));
      await _frames(tester);
      expect(find.byType(FmStart), findsOne);
      expect(find.text('Your settings couldn’t be saved.'), findsOne);
      await tester.pump(ToastHost.lifetime);
    });
  });
}
