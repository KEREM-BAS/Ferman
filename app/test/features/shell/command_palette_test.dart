import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/settings/shortcuts_pane.dart';
import 'package:ferman/features/shell/shell_palette.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcut_sheet.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';
import 'shell_host.dart';

const String _path = '/Belgeler/Tez.pdf';

/// long-500's shape: 500 pages, an outline entry on each.
final OpenedDocument _long = OpenedDocument(
  id: 1,
  pages: [
    for (var i = 0; i < 500; i++)
      PageInfo(width: 595, height: 842, handle: i + 1),
  ],
  outline: [
    for (var i = 0; i < 500; i++)
      OutlineEntry(title: i == 2 ? 'İmzalar' : 'Bölüm ${i + 1}', page: i),
  ],
);

void main() {
  late FakeEngineService engine;
  late MemorySettingsStore store;
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<void> keys(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Overlay).first));

  /// The app, with [_long] open in the editor when [document].
  Future<ProviderContainer> open(
    WidgetTester tester, {
    bool document = true,
    String language = 'en',
  }) async {
    engine = FakeEngineService(documents: {_path: _long});
    final picker = FakeFilePickerService(picked: [_path]);
    store = await pumpFermanApp(
      tester,
      engine: engine,
      picker: picker,
      home: '/home/elif',
      settings: AppSettings(onboardingCompleted: true, languageCode: language),
      window: window,
    );
    if (document) {
      await keys(tester, LogicalKeyboardKey.keyO);
      await tester.pumpAndSettle();
    }
    return container(tester);
  }

  List<CommandItem> rows(WidgetTester tester) => [
    for (final group
        in tester.widget<CommandPalette>(find.byType(CommandPalette)).groups)
      ...group.items,
  ];

  CommandItem row(WidgetTester tester, String label) =>
      rows(tester).firstWhere((item) => item.label == label);

  Finder field() => find.descendant(
    of: find.byType(CommandPalette),
    matching: find.byType(EditableText),
  );

  testWidgets('Ctrl+K and Search open it on the start screen; Esc closes it', (
    tester,
  ) async {
    await open(tester, document: false);
    expect(find.byType(FmStart), findsOneWidget);
    await keys(tester, LogicalKeyboardKey.keyK);
    expect(find.byType(ShellPalette), findsOneWidget);
    // Only the start screen's commands, and nothing of a document.
    expect(row(tester, 'Open file').disabledReason, isNull);
    expect(rows(tester).any((item) => item.label == 'Save'), isFalse);
    expect(rows(tester).any((item) => item.id == 'tasks'), isFalse);
    expect(row(tester, 'Keyboard shortcuts').hint, 'Settings');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(ShellPalette), findsNothing);
    await tester.tap(find.text('Search'));
    await settle(tester);
    expect(find.byType(ShellPalette), findsOneWidget);
  });

  testWidgets('lists the commands that work and those held back with their '
      'reason', (tester) async {
    await open(tester);
    await keys(tester, LogicalKeyboardKey.keyK);
    expect(row(tester, 'Save as').shortcut, ['Ctrl', 'Shift', 'S']);
    expect(row(tester, 'Print').disabledReason, futureVersion);
    expect(row(tester, 'Zoom in').disabledReason, isNull);
    expect(row(tester, 'Background tasks').disabledReason, isNull);
    expect(row(tester, 'Optimize and clean').disabledReason, isNull);
    // The window's own keys are not palette commands.
    expect(rows(tester).any((item) => item.label == 'Quit Ferman'), isFalse);
  });

  testWidgets('Enter runs the command: Background tasks opens the drawer '
      '(decision 30)', (tester) async {
    final app = await open(tester);
    await keys(tester, LogicalKeyboardKey.keyK);
    await tester.enterText(field(), 'background');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byType(ShellPalette), findsNothing);
    expect(app.read(backgroundJobsProvider).open, isTrue);
  });

  testWidgets('folds Turkish case and finds pages on long-500 within 100 ms', (
    tester,
  ) async {
    final app = await open(tester, language: 'tr');
    await keys(tester, LogicalKeyboardKey.keyK);
    final watch = Stopwatch()..start();
    await tester.enterText(field(), 'imza');
    await tester.pump();
    watch.stop();
    // "imza" finds "İmzalar" (a11-2 note).
    expect(find.text('Sayfa 3 · İmzalar'), findsOneWidget);
    // shortcut: a debug-mode test timing on the machine running the tests,
    // not R1; the profile-mode figure is an owner check.
    expect(watch.elapsedMilliseconds, lessThan(100));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(app.read(viewerProvider)?.currentPage, 2);
    // A page number names a page.
    await keys(tester, LogicalKeyboardKey.keyK);
    await tester.enterText(field(), '420');
    await tester.pump();
    expect(rows(tester).any((item) => item.id == 'page-419'), isTrue);
  });

  testWidgets('with no match, Enter searches the document instead', (
    tester,
  ) async {
    final app = await open(tester);
    await keys(tester, LogicalKeyboardKey.keyK);
    await tester.enterText(field(), 'kiracı');
    await tester.pump();
    expect(
      find.text(
        'No commands match “kiracı”. Press Enter to search the document '
        'instead.',
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byType(ShellPalette), findsNothing);
    expect(app.read(findProvider).open, isTrue);
    expect(app.read(findProvider).query, 'kiracı');
    expect(engine.searches.last.$1, 'kiracı');
  });

  group('the cheat sheet (a11-3)', () {
    testWidgets('Ctrl+/ shows every shortcut by group and searches', (
      tester,
    ) async {
      await open(tester);
      await keys(tester, LogicalKeyboardKey.slash);
      expect(find.byType(ShortcutSheet), findsOneWidget);
      for (final group in ['GENERAL', 'NAVIGATE', 'ORGANIZE', 'WINDOW']) {
        expect(find.text(group), findsOneWidget, reason: group);
      }
      expect(find.text('Save a copy'), findsNothing); // no key on Linux
      expect(find.text('Rotate right'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(ShortcutSheet),
          matching: find.byType(EditableText),
        ),
        'rotate',
      );
      await tester.pump();
      expect(find.text('GENERAL'), findsNothing);
      expect(find.text('Rotate left'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(ShortcutSheet), findsNothing);
    });

    testWidgets('fits a 1024 px window in fewer columns (decision 32)', (
      tester,
    ) async {
      engine = FakeEngineService();
      await pumpFermanApp(tester, size: const Size(1024, 680));
      await keys(tester, LogicalKeyboardKey.slash);
      expect(find.byType(ShortcutSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Settings › Keyboard shortcuts (a11-1j)', () {
    Future<ProviderContainer> pane(WidgetTester tester) async {
      final app = await open(tester, document: false);
      await keys(tester, LogicalKeyboardKey.comma);
      await tester.tap(find.text('Keyboard shortcuts'));
      await settle(tester);
      expect(find.byType(ShortcutsPane), findsOneWidget);
      return app;
    }

    Finder keysOf(String command) =>
        find.bySemanticsLabel('Change the shortcut of $command');

    testWidgets('a free key applies and is stored; reset gives the default '
        'back', (tester) async {
      final app = await pane(tester);
      await tester.ensureVisible(keysOf('Present'));
      await tester.pump();
      await tester.tap(keysOf('Present'));
      await settle(tester);
      expect(find.text('Press new shortcut…'), findsOneWidget);
      await keys(tester, LogicalKeyboardKey.keyJ, shift: true);
      expect(find.text('Press new shortcut…'), findsNothing);
      expect(app.read(shortcutBindingsProvider).caps(ShellCommand.present), [
        'Ctrl',
        'Shift',
        'J',
      ]);
      expect((await store.load()).shortcuts, {
        'linux.present': ['CS+${LogicalKeyboardKey.keyJ.keyId}'],
      });
      await tester.tap(find.bySemanticsLabel('Restore the default shortcut'));
      await settle(tester);
      expect(app.read(shortcutBindingsProvider).caps(ShellCommand.present), [
        'Ctrl',
        'L',
      ]);
    });

    testWidgets('a taken key asks first; Enter reassigns it and leaves the '
        'other with none', (tester) async {
      final app = await pane(tester);
      await tester.ensureVisible(keysOf('Add signature'));
      await tester.pump();
      await tester.tap(keysOf('Add signature'));
      await settle(tester);
      await keys(tester, LogicalKeyboardKey.keyS, shift: true);
      expect(
        find.text(
          'CtrlShiftS is already “Save as”. Press Enter to reassign it, Esc '
          'to keep ShiftS.',
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      final bindings = app.read(shortcutBindingsProvider);
      expect(bindings.caps(ShellCommand.addSignature), ['Ctrl', 'Shift', 'S']);
      expect(bindings.caps(ShellCommand.saveAs), isNull);
      // Save a copy has none on Linux already.
      expect(find.text('No shortcut'), findsNWidgets(2));
    });

    testWidgets('Esc keeps the keys; system keys are refused', (tester) async {
      final app = await pane(tester);
      await tester.ensureVisible(keysOf('Add signature'));
      await tester.pump();
      await tester.tap(keysOf('Add signature'));
      await settle(tester);
      await keys(tester, LogicalKeyboardKey.keyS, shift: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(app.read(shortcutBindingsProvider).changes, isEmpty);
      // Esc stops recording; Settings stays.
      expect(find.byType(ShortcutsPane), findsOneWidget);
      await tester.ensureVisible(keysOf('Present'));
      await tester.pump();
      await tester.tap(keysOf('Present'));
      await settle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settle(tester);
      expect(
        find.text(
          'AltF4 belongs to the system. Press other keys, or Esc to '
          'cancel.',
        ),
        findsOneWidget,
      );
      expect(app.read(shortcutBindingsProvider).changes, isEmpty);
    });

    testWidgets('the presets other than Ferman wait for a later version', (
      tester,
    ) async {
      await pane(tester);
      final options = tester
          .widget<Select<String>>(find.byType(Select<String>))
          .options;
      expect(
        options.where((option) => !option.disabled).single.value,
        'ferman',
      );
      for (final option in options.where((option) => option.disabled)) {
        expect(option.disabledReason, futureVersion);
      }
    });

    testWidgets('a changed key shows in the tooltips and the cheat sheet', (
      tester,
    ) async {
      final app = await open(tester);
      const ctrlShiftJ = KeyBinding(
        LogicalKeyboardKey.keyJ,
        control: true,
        shift: true,
      );
      await app
          .read(settingsProvider.notifier)
          .change(
            (settings) => settings.copyWith(
              shortcuts: app
                  .read(shortcutBindingsProvider)
                  .rebind(ShellCommand.toggleSidebar, ctrlShiftJ)
                  .toSettings(settings.shortcuts),
            ),
          );
      await settle(tester);
      // The mode bar's toggle shows the new keys, and they work.
      expect(
        tester
            .widgetList<IconButton>(find.byType(IconButton))
            .firstWhere((button) => button.icon == IconName.panelLeft)
            .shortcut,
        ['Ctrl', 'Shift', 'J'],
      );
      final shown = app.read(shellSidebarOpenProvider);
      await keys(tester, LogicalKeyboardKey.keyJ, shift: true);
      expect(app.read(shellSidebarOpenProvider), !shown);
      await keys(tester, LogicalKeyboardKey.slash);
      expect(find.text('Changed'), findsOneWidget);
      expect(app.read(organizeDialogProvider), isA<ShortcutSheet>());
    });
  });
}
