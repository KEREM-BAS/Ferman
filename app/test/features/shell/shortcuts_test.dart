import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import 'shell_host.dart';

void main() {
  group('the shortcut table', () {
    for (final platform in ShortcutPlatform.values) {
      test('has no duplicate binding on ${platform.name}', () {
        expect(ShellCommand.conflicts(platform), isEmpty);
      });
    }

    group('the duplicate check', () {
      const h = KeyBinding(LogicalKeyboardKey.keyH);
      const tab = KeyBinding(LogicalKeyboardKey.tab);
      const linux = ShortcutPlatform.linux;

      test('finds two commands on the same key in a shared mode', () {
        final problems = ShellCommand.conflictsIn(linux, [
          (name: 'a', bindings: [h], modes: {FermanMode.comment}),
          (name: 'b', bindings: [h], modes: {FermanMode.comment}),
        ]);
        expect(problems, ['linux: H is both a and b in comment']);
      });

      test('allows the same key in modes that never meet', () {
        // As the View Hand tool and the Comment Highlight share H.
        expect(
          ShellCommand.conflictsIn(linux, [
            (name: 'hand', bindings: [h], modes: {FermanMode.view}),
            (name: 'highlight', bindings: [h], modes: {FermanMode.comment}),
          ]),
          isEmpty,
        );
      });

      test('a key of every mode collides with a key of one mode, whatever '
          'the scope', () {
        // A window key (every mode) against a canvas key of Fill & Sign.
        expect(
          ShellCommand.conflictsIn(linux, [
            (name: 'window', bindings: [tab], modes: null),
            (name: 'canvas', bindings: [tab], modes: {FermanMode.sign}),
          ]),
          hasLength(1),
        );
      });

      test('tells modifiers apart', () {
        expect(
          ShellCommand.conflictsIn(linux, [
            (
              name: 'ctrl',
              bindings: [
                const KeyBinding(LogicalKeyboardKey.keyH, control: true),
              ],
              modes: null,
            ),
            (name: 'plain', bindings: [h], modes: null),
          ]),
          isEmpty,
        );
      });
    });

    test('gives the Comment tools the keys their tooltips show', () {
      // AnnotationTools draws each tool's key from the component; the table
      // must bind the same key, so the tooltip and the binding agree.
      const counterpart = {
        AnnotationTool.select: ShellCommand.annotationSelect,
        AnnotationTool.highlight: ShellCommand.highlight,
        AnnotationTool.underline: ShellCommand.underline,
        AnnotationTool.strikethrough: ShellCommand.strikethrough,
        AnnotationTool.note: ShellCommand.note,
        AnnotationTool.text: ShellCommand.textBox,
        AnnotationTool.callout: ShellCommand.callout,
        AnnotationTool.pen: ShellCommand.draw,
        AnnotationTool.shapes: ShellCommand.shapes,
        AnnotationTool.measure: ShellCommand.measure,
      };
      expect(
        AnnotationTool.values.where((tool) => tool.shortcutKey != null).toSet(),
        counterpart.keys.toSet(),
      );
      expect(AnnotationTool.stamp.shortcut, isNull);
      for (final MapEntry(key: tool, value: command) in counterpart.entries) {
        expect(command.modes, {FermanMode.comment}, reason: command.name);
        for (final platform in ShortcutPlatform.values) {
          expect(command.bindingsFor(platform), [
            KeyBinding(tool.shortcutKey!),
          ], reason: '${command.name} on ${platform.name}');
          expect(command.caps(platform), [tool.shortcut]);
        }
      }
      // No other Comment command takes a single key.
      for (final command in ShellCommand.values) {
        if (command.modes?.contains(FermanMode.comment) != true) continue;
        if (counterpart.containsValue(command)) continue;
        for (final platform in ShortcutPlatform.values) {
          expect(
            command.bindingsFor(platform).where((binding) => binding.isPlain),
            isEmpty,
            reason: command.name,
          );
        }
      }
    });

    test('shows ⌘ ⌥ ⇧ ⌃ on macOS and Ctrl Alt Shift elsewhere', () {
      const mac = ShortcutPlatform.mac;
      const win = ShortcutPlatform.windows;
      const linux = ShortcutPlatform.linux;
      expect(ShellCommand.commandPalette.caps(mac), ['⌘', 'K']);
      expect(ShellCommand.commandPalette.caps(win), ['Ctrl', 'K']);
      expect(ShellCommand.commandPalette.caps(linux), ['Ctrl', 'K']);
      expect(ShellCommand.togglePanel.caps(mac), ['⌥', '⌘', 'P']);
      expect(ShellCommand.togglePanel.caps(win), ['Ctrl', 'Alt', 'P']);
      expect(ShellCommand.saveAs.caps(mac), ['⇧', '⌘', 'S']);
      expect(ShellCommand.saveAs.caps(win), ['Ctrl', 'Shift', 'S']);
      expect(ShellCommand.redo.caps(mac), ['⇧', '⌘', 'Z']);
      expect(ShellCommand.redo.caps(win), ['Ctrl', 'Y']);
      expect(ShellCommand.findAndReplace.caps(mac), ['⌥', '⌘', 'F']);
      expect(ShellCommand.findAndReplace.caps(win), ['Ctrl', 'H']);
      expect(ShellCommand.zoomIn.caps(mac), ['⌘', '+']);
      expect(ShellCommand.zoomOut.caps(win), ['Ctrl', '−']);
      expect(ShellCommand.settings.caps(mac), ['⌘', ',']);
      expect(ShellCommand.rotateLeft.caps(win), ['Ctrl', '[']);
      expect(ShellCommand.nextDocument.caps(mac), ['⌃', 'Tab']);
      expect(ShellCommand.addText.caps(mac), ['⇧', 'T']);
      expect(ShellCommand.previousField.caps(win), ['Shift', 'Tab']);
      expect(ShellCommand.deletePages.caps(mac), ['⌫']);
      expect(ShellCommand.deletePages.caps(win), ['Del']);
      expect(ShellCommand.movePagesUp.caps(linux), ['Ctrl', 'Alt', '↑']);
    });

    test('resolves the ⌥⌘S collision as G44 decides', () {
      const mac = ShortcutPlatform.mac;
      const optionCommandS = KeyBinding(
        LogicalKeyboardKey.keyS,
        meta: true,
        alt: true,
      );
      final owners = ShellCommand.values.where(
        (command) => command.mac.contains(optionCommandS),
      );
      expect(owners, [ShellCommand.saveCopy]);
      expect(ShellCommand.toggleSidebar.caps(mac), ['⌃', '⌘', 'S']);
      expect(ShellCommand.addSignature.modes, {FermanMode.sign});
      // Windows and Linux keep FmWindow's sidebar key; Save a copy has none.
      expect(ShellCommand.toggleSidebar.caps(ShortcutPlatform.windows), [
        'Ctrl',
        'Alt',
        'S',
      ]);
      expect(ShellCommand.saveCopy.caps(ShortcutPlatform.windows), isNull);
    });

    test('moves the document jump off the zoom keys', () {
      expect(ShellCommand.actualSize.caps(ShortcutPlatform.mac), ['⌘', '1']);
      expect(ShellCommand.fitWidth.caps(ShortcutPlatform.mac), ['⌘', '2']);
      expect(ShellCommand.document1.caps(ShortcutPlatform.mac), [
        '⌥',
        '⌘',
        '1',
      ]);
      expect(ShellCommand.document9.caps(ShortcutPlatform.windows), [
        'Alt',
        '9',
      ]);
    });

    test('holds the window commands of each system', () {
      expect(ShellCommand.minimizeWindow.caps(ShortcutPlatform.mac), [
        '⌘',
        'M',
      ]);
      expect(ShellCommand.quit.caps(ShortcutPlatform.mac), ['⌘', 'Q']);
      expect(ShellCommand.closeDocument.caps(ShortcutPlatform.mac), ['⌘', 'W']);
      expect(ShellCommand.closeDocument.caps(ShortcutPlatform.windows), [
        'Ctrl',
        'W',
      ]);
      expect(ShellCommand.closeWindow.caps(ShortcutPlatform.windows), [
        'Alt',
        'F4',
      ]);
      expect(ShellCommand.closeWindow.caps(ShortcutPlatform.linux), [
        'Alt',
        'F4',
      ]);
      expect(ShellCommand.quit.caps(ShortcutPlatform.linux), ['Ctrl', 'Q']);
      expect(ShellCommand.quit.caps(ShortcutPlatform.windows), isNull);
      expect(
        ShellCommand.minimizeWindow.caps(ShortcutPlatform.windows),
        isNull,
      );
    });

    test('gives every command a key on every system but the listed ones', () {
      const without = {
        ShortcutPlatform.mac: {ShellCommand.closeWindow},
        ShortcutPlatform.windows: {
          ShellCommand.saveCopy,
          ShellCommand.minimizeWindow,
          ShellCommand.quit,
        },
        ShortcutPlatform.linux: {
          ShellCommand.saveCopy,
          ShellCommand.minimizeWindow,
        },
      };
      for (final platform in ShortcutPlatform.values) {
        final missing = {
          for (final command in ShellCommand.values)
            if (command.bindingsFor(platform).isEmpty) command,
        };
        expect(missing, without[platform], reason: platform.name);
      }
    });

    test('binds each mode only its own keys and the canvas only its own', () {
      Set<ShellCommand> commandsOf(
        FermanMode mode, {
        ShortcutScope scope = ShortcutScope.window,
      }) => {
        for (final intent in ShellCommand.shortcutsFor(
          ShortcutPlatform.mac,
          mode,
          scope: scope,
        ).values)
          (intent as ShellCommandIntent).command,
      };
      final view = commandsOf(FermanMode.view);
      expect(view, contains(ShellCommand.handTool));
      expect(view, contains(ShellCommand.toggleSidebar));
      expect(view, isNot(contains(ShellCommand.highlight)));
      expect(view, isNot(contains(ShellCommand.nextPage)));
      final comment = commandsOf(FermanMode.comment);
      expect(comment, contains(ShellCommand.highlight));
      expect(comment, isNot(contains(ShellCommand.handTool)));
      expect(commandsOf(FermanMode.sign, scope: ShortcutScope.canvas), {
        ShellCommand.nextPage,
        ShellCommand.previousPage,
        ShellCommand.nextField,
        ShellCommand.previousField,
      });
    });

    test('maps the running system to its conventions', () {
      expect(ShortcutPlatform.of(TargetPlatform.macOS), ShortcutPlatform.mac);
      expect(
        ShortcutPlatform.of(TargetPlatform.windows),
        ShortcutPlatform.windows,
      );
      expect(ShortcutPlatform.of(TargetPlatform.linux), ShortcutPlatform.linux);
      expect(
        ShortcutPlatform.of(TargetPlatform.android),
        ShortcutPlatform.linux,
      );
    });
  });

  group('ShellCommandAction', () {
    testWidgets('runs only commands with a handler, and no single key while '
        'the user types', (tester) async {
      var runs = 0;
      final action = ShellCommandAction({ShellCommand.handTool: () => runs++});
      const hand = ShellCommandIntent(ShellCommand.handTool, plain: true);
      expect(action.isEnabled(hand), isTrue);
      expect(
        action.isEnabled(const ShellCommandIntent(ShellCommand.open)),
        isFalse,
      );
      action.invoke(hand);
      expect(runs, 1);

      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: EditableText(
            controller: controller,
            focusNode: focus,
            style: const TextStyle(),
            cursorColor: const Color(0xFF000000),
            backgroundCursorColor: const Color(0xFF000000),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      expect(ShellCommandAction.typing, isTrue);
      expect(action.isEnabled(hand), isFalse);
      expect(
        ShellCommandAction({ShellCommand.handTool: () {}})
            .isEnabled(const ShellCommandIntent(ShellCommand.handTool)),
        isTrue,
      );
    });
  });

  group('the shell binds the table', () {
    late FakeDesktopWindow window;

    tearDown(() => window.dispose());

    testWidgets('Ctrl+Alt+S and Ctrl+Alt+P toggle the sidebar and the panel '
        'on Linux', (tester) async {
      window = FakeDesktopWindow(WindowPlatform.linux);
      await pumpShell(tester, shellHost(window: window));
      final container = containerOf(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(container.read(shellSidebarOpenProvider), isFalse);
      expect(container.read(shellPanelOpenProvider), isFalse);
    });

    testWidgets('⌃⌘S toggles the sidebar on macOS, and ⌥⌘S does not', (
      tester,
    ) async {
      window = FakeDesktopWindow(WindowPlatform.mac);
      await pumpShell(
        tester,
        shellHost(window: window, platform: ShortcutPlatform.mac),
      );
      final container = containerOf(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      final saveCopy = await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(saveCopy, isFalse, reason: 'Save a copy is disabled until M3');
      expect(container.read(shellSidebarOpenProvider), isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await settle(tester);
      expect(container.read(shellSidebarOpenProvider), isFalse);
    });

    testWidgets('works while focus is in the title bar', (tester) async {
      window = FakeDesktopWindow(WindowPlatform.win);
      await pumpShell(
        tester,
        shellHost(window: window, platform: ShortcutPlatform.windows),
      );
      final container = containerOf(tester);
      final home = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.label == 'Home',
      );
      Focus.of(
        tester.element(find.descendant(of: home, matching: find.byType(Icon))),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(container.read(shellPanelOpenProvider), isFalse);
    });

    testWidgets('runs the window commands through the window frame', (
      tester,
    ) async {
      window = FakeDesktopWindow(WindowPlatform.linux);
      await pumpShell(tester, shellHost(window: window));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(window.calls, ['close', 'close']);
    });

    testWidgets('runs ⌘M on macOS', (tester) async {
      window = FakeDesktopWindow(WindowPlatform.mac);
      await pumpShell(
        tester,
        shellHost(window: window, platform: ShortcutPlatform.mac),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(window.calls, ['minimize']);
    });

    testWidgets('leaves the keys of commands that do not work yet alone', (
      tester,
    ) async {
      window = FakeDesktopWindow(WindowPlatform.linux);
      await pumpShell(tester, shellHost(window: window));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final palette = await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      final open = await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(palette, isFalse);
      expect(open, isFalse);
      // A single-key tool of the View mode.
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyH), isFalse);
    });

    testWidgets('Tab still moves focus from the canvas in Fill & Sign', (
      tester,
    ) async {
      window = FakeDesktopWindow(WindowPlatform.linux);
      await pumpShell(tester, shellHost(window: window));
      final container = containerOf(tester);
      container.read(shellModeProvider.notifier).select(FermanMode.sign);
      await settle(tester);
      final canvas = FocusManager.instance.primaryFocus;
      expect(canvas?.debugLabel, 'ShellCanvas');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(canvas));
    });

    testWidgets('Ctrl+Tab and Alt+2 move between the placeholder documents', (
      tester,
    ) async {
      window = FakeDesktopWindow(WindowPlatform.linux);
      await pumpShell(tester, shellHost(window: window));
      final container = containerOf(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(container.read(shellDocumentsProvider).activeIndex, 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(container.read(shellDocumentsProvider).activeIndex, 2);
      await settle(tester);
    });

    testWidgets('tooltips show the platform keys', (tester) async {
      window = FakeDesktopWindow(WindowPlatform.mac);
      await pumpShell(
        tester,
        shellHost(window: window, platform: ShortcutPlatform.mac),
      );
      final sidebarToggle = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.label == 'Show or hide sidebar',
      );
      expect(tester.widget<IconButton>(sidebarToggle).shortcut, [
        '⌃',
        '⌘',
        'S',
      ]);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(sidebarToggle));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Show or hide sidebar'), findsOneWidget);
      final keys = tester.widget<Kbd>(
        find.descendant(
          of: find.byType(Overlay).first,
          matching: find.byWidgetPredicate(
            (widget) => widget is Kbd && widget.tone == KbdTone.inverse,
          ),
        ),
      );
      expect(keys.keys, ['⌃', '⌘', 'S']);
      await gesture.moveTo(Offset.zero);
      await settle(tester);
    });

    testWidgets('tooltips show Ctrl Alt on Windows', (tester) async {
      window = FakeDesktopWindow(WindowPlatform.win);
      await pumpShell(
        tester,
        shellHost(window: window, platform: ShortcutPlatform.windows),
      );
      IconButton button(String label) => tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.label == label,
        ),
      );
      expect(button('Show or hide sidebar').shortcut, ['Ctrl', 'Alt', 'S']);
      expect(button('Show or hide panel').shortcut, ['Ctrl', 'Alt', 'P']);
      expect(button('Open file').shortcut, ['Ctrl', 'O']);
      expect(button('Settings').shortcut, ['Ctrl', ',']);
      final kbd = tester.widget<Kbd>(
        find.byWidgetPredicate(
          (widget) => widget is Kbd && widget.tone == KbdTone.plain,
        ),
      );
      expect(kbd.keys, ['Ctrl', 'K']);
    });
  });
}
