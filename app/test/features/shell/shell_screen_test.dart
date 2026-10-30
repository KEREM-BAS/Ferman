import 'dart:ui' show CheckedState, Tristate;

import 'package:ferman/app/window_frame.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/icons/icon_painter.dart';
import 'package:ferman/features/shell/shell_canvas.dart';
import 'package:ferman/features/shell/shell_mode_bar.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_region.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_status_bar.dart';
import 'package:ferman/features/shell/shell_tool_rows.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import 'shell_host.dart';

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Finder iconButton(String label) => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.label == label,
  );

  group('layout', () {
    testWidgets('matches FmWindow sizes at 1440 × 900', (tester) async {
      await pumpShell(tester, shellHost(window: window));

      expect(
        tester.getRect(find.byType(TitleBar)),
        const Rect.fromLTWH(0, 0, 1440, 38),
      );
      expect(
        tester.getRect(find.byType(ShellModeBar)),
        const Rect.fromLTWH(0, 38, 1440, 40),
      );
      // The 44 px Toolbar and FmWindow's second 1 px line under it.
      expect(
        tester.getRect(find.byType(ShellToolRows)),
        const Rect.fromLTWH(0, 78, 1440, 45),
      );
      expect(
        tester.getRect(
          find.descendant(
            of: find.byKey(ShellToolRows.keyOf(FermanMode.view)),
            matching: find.byType(Toolbar),
          ),
        ),
        const Rect.fromLTWH(0, 78, 1440, 44),
      );
      expect(
        tester.getRect(find.byType(FmSidebar)),
        const Rect.fromLTWH(0, 123, 216, 751),
      );
      expect(
        tester.getRect(find.byType(FmDocPanel)),
        const Rect.fromLTWH(1440 - 264, 123, 264, 751),
      );
      expect(
        tester.getRect(find.byType(ShellCanvas)),
        const Rect.fromLTWH(216, 123, 1440 - 216 - 264, 751),
      );
      expect(
        tester.getRect(find.byType(ShellStatusBar)),
        const Rect.fromLTWH(0, 874, 1440, 26),
      );
    });

    for (final (platform, system) in [
      (WindowPlatform.win, ShortcutPlatform.windows),
      (WindowPlatform.mac, ShortcutPlatform.mac),
      (WindowPlatform.linux, ShortcutPlatform.linux),
    ]) {
      testWidgets('fits every mode on ${platform.name} without overflow', (
        tester,
      ) async {
        final other = FakeDesktopWindow(platform);
        addTearDown(other.dispose);
        await pumpShell(tester, shellHost(window: other, platform: system));
        final container = containerOf(tester);
        for (final mode in FermanMode.values) {
          container.read(shellModeProvider.notifier).select(mode);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: '$mode');
        }
      });
    }

    testWidgets('mirrors in right to left, with the sidebar at the right', (
      tester,
    ) async {
      await pumpShell(
        tester,
        shellHost(window: window, locale: const Locale('ar')),
      );
      expect(
        tester.getRect(find.byType(FmSidebar)),
        const Rect.fromLTWH(1440 - 216, 123, 216, 751),
      );
      expect(
        tester.getRect(find.byType(FmDocPanel)),
        const Rect.fromLTWH(0, 123, 264, 751),
      );
      expect(find.text('عرض'), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);
      expect(
        tester.getCenter(iconButton('إظهار الشريط الجانبي أو إخفاؤه')).dx,
        greaterThan(1400),
      );
    });
    testWidgets('the canvas is never mirrored: in right to left its subtree '
        'runs left to right and its glyph is not flipped (ADR 0014)', (
      tester,
    ) async {
      await pumpShell(
        tester,
        shellHost(window: window, locale: const Locale('ar')),
      );
      final canvas = find.byType(ShellCanvas);
      expect(Directionality.of(tester.element(canvas)), TextDirection.rtl);
      final glyph = find.descendant(of: canvas, matching: find.byType(Icon));
      expect(tester.widget<Icon>(glyph).name, IconName.fileText);
      // The canvas content runs with its own left-to-right geometry.
      expect(Directionality.of(tester.element(glyph)), TextDirection.ltr);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: glyph,
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as IconPainter;
      expect(painter.mirror, isFalse);
      // No mirroring transform between the canvas and its content.
      final transforms = tester.widgetList<Transform>(
        find.descendant(of: canvas, matching: find.byType(Transform)),
      );
      for (final transform in transforms) {
        expect(transform.transform.storage[0], isNot(lessThan(0)));
      }
      // The placeholder's copy keeps the UI's direction.
      final copy = tester.widget<Text>(
        find.descendant(of: canvas, matching: find.byType(Text)),
      );
      expect(copy.textDirection, TextDirection.rtl);
      // And the canvas sits between the mirrored panels, the sidebar right.
      expect(
        tester.getRect(canvas).right,
        tester.getRect(find.byType(FmSidebar)).left,
      );
    });
  });

  group('mode bar', () {
    testWidgets('shows the eight modes in the designed order', (tester) async {
      await pumpShell(tester, shellHost(window: window));
      final tabs = tester.widget<ModeTabs>(find.byType(ModeTabs));
      expect(tabs.modes, FermanMode.values);
      expect(tabs.value, FermanMode.view);
      const labels = [
        'View',
        'Edit',
        'Comment',
        'Fill & Sign',
        'Organize',
        'Convert',
        'Protect',
        'Tools',
      ];
      final xs = [
        for (final label in labels)
          tester
              .getCenter(
                find.descendant(
                  of: find.byType(ModeTabs),
                  matching: find.text(label),
                ),
              )
              .dx,
      ];
      expect(xs, [...xs]..sort());
    });

    testWidgets('names the modes in Turkish from the design', (tester) async {
      await pumpShell(
        tester,
        shellHost(window: window, locale: const Locale('tr')),
      );
      for (final label in [
        'Görüntüle',
        'Düzenle',
        'Yorum',
        'Doldur ve İmzala',
        'Sayfalar',
        'Dönüştür',
        'Koru',
        'Araçlar',
        'Kaydet',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets("switches modes and keeps each mode's state", (tester) async {
      await pumpShell(tester, shellHost(window: window));
      final elements = {
        for (final mode in FermanMode.values)
          mode: tester.element(
            find.byKey(ShellToolRows.keyOf(mode), skipOffstage: false),
          ),
      };
      expect(find.text('Marquee zoom'), findsOneWidget);
      expect(find.text('Edit text'), findsNothing);

      await tester.tap(find.text('Edit'));
      await settle(tester);
      expect(containerOf(tester).read(shellModeProvider), FermanMode.edit);
      expect(find.text('Edit text'), findsOneWidget);
      expect(find.text('Marquee zoom'), findsNothing);

      for (final mode in [...FermanMode.values.reversed, FermanMode.edit]) {
        containerOf(tester).read(shellModeProvider.notifier).select(mode);
        await settle(tester);
      }
      for (final mode in FermanMode.values) {
        final element = tester.element(
          find.byKey(ShellToolRows.keyOf(mode), skipOffstage: false),
        );
        expect(identical(element, elements[mode]), isTrue, reason: '$mode');
        expect(element.mounted, isTrue);
      }
    });

    testWidgets('toggles the sidebar and the panel, keeping the canvas', (
      tester,
    ) async {
      await pumpShell(tester, shellHost(window: window));
      final canvas = tester.state(find.byType(ShellCanvas));

      await tester.tap(iconButton('Show or hide sidebar'));
      await settle(tester);
      expect(find.byType(FmSidebar), findsNothing);
      expect(
        tester.widget<IconButton>(iconButton('Show or hide sidebar')).active,
        isFalse,
      );
      expect(tester.getRect(find.byType(ShellCanvas)).left, 0);

      await tester.tap(iconButton('Show or hide panel'));
      await settle(tester);
      expect(find.byType(FmDocPanel), findsNothing);
      expect(tester.getRect(find.byType(ShellCanvas)).width, 1440);
      expect(identical(tester.state(find.byType(ShellCanvas)), canvas), isTrue);

      await tester.tap(iconButton('Show or hide sidebar'));
      await tester.tap(iconButton('Show or hide panel'));
      await settle(tester);
      expect(find.byType(FmSidebar), findsOneWidget);
      expect(find.byType(FmDocPanel), findsOneWidget);
      expect(identical(tester.state(find.byType(ShellCanvas)), canvas), isTrue);
    });

    testWidgets('keeps the sidebar tab while the sidebar is hidden', (
      tester,
    ) async {
      await pumpShell(tester, shellHost(window: window));
      containerOf(tester)
          .read(shellSidebarTabProvider.notifier)
          .select(SidebarTab.outline);
      await settle(tester);
      await tester.tap(iconButton('Show or hide sidebar'));
      await settle(tester);
      expect(find.byType(FmSidebar), findsNothing);
      await tester.tap(iconButton('Show or hide sidebar'));
      await settle(tester);
      expect(
        tester
            .widget<SegmentedControl<SidebarTab>>(
              find.byType(SegmentedControl<SidebarTab>),
            )
            .value,
        SidebarTab.outline,
      );
      expect(
        find.descendant(
          of: find.byType(FmSidebar),
          matching: find.text('Outline'),
        ),
        findsWidgets,
      );
    });

    testWidgets('disables Save with "No changes to save" for a clean '
        'document, and until M3 for an unsaved one (fix 4)', (tester) async {
      await pumpShell(tester, shellHost(window: window));
      Button save() => tester.widget<Button>(
        find.ancestor(of: find.text('Save'), matching: find.byType(Button)),
      );
      expect(save().variant, ButtonVariant.primary);
      expect(save().size, ButtonSize.sm);
      expect(save().onPressed, isNull);
      expect(save().disabledReason, 'No changes to save');
      expect(
        find.text('Saved on this device · ${bidiIsolate('14:32')}'),
        findsOneWidget,
      );

      // The statement has unsaved changes: its tab, Save and the status bar
      // agree.
      await tester.tap(find.text('Hesap ekstresi Eylül 2026.pdf'));
      await settle(tester);
      expect(save().disabledReason, futureVersion);
      expect(
        find.descendant(
          of: find.byType(ShellStatusBar),
          matching: find.text('Unsaved changes'),
        ),
        findsOneWidget,
      );
      final tab = tester.widget<DocumentTab>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DocumentTab &&
              widget.name == 'Hesap ekstresi Eylül 2026.pdf',
        ),
      );
      expect(tab.active, isTrue);
      expect(tab.unsaved, isTrue);
    });

    testWidgets('hides the AI button while AI is off', (tester) async {
      await pumpShell(tester, shellHost(window: window));
      expect(iconButton('AI assistant'), findsNothing);
    });

    testWidgets('shows the AI button when AI is on', (tester) async {
      await pumpShell(tester, shellHost(window: window, aiEnabled: true));
      final ai = tester.widget<IconButton>(iconButton('AI assistant'));
      expect(ai.disabledReason, futureVersion);
      expect(
        tester.getCenter(iconButton('AI assistant')).dx,
        lessThan(tester.getCenter(iconButton('Show or hide panel')).dx),
      );
    });
  });

  group('tool rows', () {
    List<Widget> itemsOf(WidgetTester tester, FermanMode mode) => tester
        .widgetList(
          find.descendant(
            of: find.byKey(ShellToolRows.keyOf(mode), skipOffstage: false),
            // Not the overflow button "More tools", which is out of the
            // row while every tool fits (G21).
            matching: find.byWidgetPredicate(
              (widget) =>
                  (widget is ToolButton && widget.label != 'More tools') ||
                  widget is IconButton ||
                  widget is ToolbarSeparator ||
                  widget is ToolbarSpacer ||
                  widget is Switch ||
                  widget is Select<String> ||
                  widget is SegmentedControl ||
                  widget is Button,
              skipOffstage: false,
            ),
            skipOffstage: false,
          ),
        )
        .toList();

    String describe(Widget widget) => switch (widget) {
      ToolButton(:final label, :final showLabel, :final hasMenu) =>
        '${showLabel ? '' : 'icon:'}$label${hasMenu ? '▾' : ''}',
      IconButton(:final label) => 'icon:$label',
      ToolbarSeparator() => '|',
      ToolbarSpacer() => '…',
      Switch(:final label) => 'switch:$label',
      Select<String>() => 'select',
      SegmentedControl(:final semanticLabel) => 'segments:$semanticLabel',
      Button() => 'button',
      _ => '?',
    };

    const rows = {
      FermanMode.view: [
        'Select',
        'Hand',
        'Marquee zoom',
        '|',
        'icon:Zoom out',
        'select',
        'icon:Zoom in',
        'segments:Fit',
        '|',
        'segments:Page layout',
        '|',
        'Split view',
        'Read aloud',
        'Present',
        '…',
        'switch:Dark reading mode',
      ],
      FermanMode.edit: [
        'Edit text',
        'Add text',
        'Add image',
        'Link',
        '|',
        'Find & replace',
        'Page marks▾',
        '|',
        'icon:Undo',
        'icon:Redo',
        'icon:Edit history',
        '…',
        'switch:Mark edited text',
        'button',
      ],
      FermanMode.comment: [
        'Select',
        'Highlight',
        'Underline',
        'Strikethrough',
        'Note',
        'Text',
        'Callout',
        'Draw',
        'Shapes▾',
        'Stamp▾',
        'Measure▾',
        '|',
        'switch:Show comments',
      ],
      FermanMode.sign: [
        'Fill fields',
        'Add text',
        'Checkmark',
        'Date',
        '|',
        'Sign▾',
        'Initials',
        'Digital signature',
        'e-imza',
        '|',
        'Prepare form',
        '…',
      ],
      FermanMode.organize: [
        'Insert▾',
        'icon:Rotate left',
        'icon:Rotate right',
        'Duplicate',
        'Extract',
        'Replace',
        'Delete',
        '|',
        'Split',
        'Combine files',
        'Crop',
        'Page labels',
        '…',
      ],
      FermanMode.convert: [
        'Word',
        'Excel',
        'PowerPoint',
        'Image',
        'HTML',
        'Text',
        'Markdown',
        '|',
        'Create PDF',
        'Scan',
        'Recognize text (OCR)',
      ],
      FermanMode.protect: [
        'Redact',
        'Find & redact',
        '|',
        'Password',
        'Remove hidden information',
        'Security report',
        '…',
        'button',
      ],
      FermanMode.tools: [
        'Compress',
        'Compare',
        'Accessibility',
        'PDF/A & preflight',
        'Batch actions',
        'Print',
        'Measure',
        'Version history',
        '|',
        'AI assistant',
      ],
    };

    testWidgets('draw every tool of FmWindow, in order', (tester) async {
      await pumpShell(tester, shellHost(window: window));
      for (final MapEntry(key: mode, value: row) in rows.entries) {
        expect(itemsOf(tester, mode).map(describe), row, reason: mode.id);
      }
      expect(
        find.descendant(
          of: find.byKey(
            ShellToolRows.keyOf(FermanMode.organize),
            skipOffstage: false,
          ),
          matching: find.text(
            'Drag pages to reorder. Right-click for more.',
            skipOffstage: false,
          ),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('disable every tool with the future-version tooltip', (
      tester,
    ) async {
      await pumpShell(tester, shellHost(window: window));
      for (final mode in FermanMode.values) {
        for (final item in itemsOf(tester, mode)) {
          final reason = switch (item) {
            ToolButton(:final disabledReason, :final onPressed) =>
              onPressed == null ? disabledReason : 'enabled',
            IconButton(:final disabledReason, :final onPressed) =>
              onPressed == null ? disabledReason : 'enabled',
            Switch(:final disabledReason, :final onChanged) =>
              onChanged == null ? disabledReason : 'enabled',
            Select<String>(:final disabledReason, :final onChanged) =>
              onChanged == null ? disabledReason : 'enabled',
            SegmentedControl(:final disabledReason, :final disabled) =>
              disabled ? disabledReason : 'enabled',
            Button(:final disabledReason, :final onPressed) =>
              onPressed == null ? disabledReason : 'enabled',
            _ => futureVersion,
          };
          expect(reason, futureVersion, reason: '$mode ${describe(item)}');
        }
      }
      final annotations = tester.widget<AnnotationTools>(
        find.byType(AnnotationTools, skipOffstage: false),
      );
      expect(annotations.tools, AnnotationTool.values);
      expect(annotations.showLabels, isTrue);
      expect(annotations.tool, AnnotationTool.highlight);
      expect(annotations.disabledReasons.keys, AnnotationTool.values);
      expect(annotations.disabledReasons.values.toSet(), {futureVersion});
      expect(annotations.colorsDisabledReason, futureVersion);
    });

    testWidgets("draw each mode's first tool on and show its keys", (
      tester,
    ) async {
      await pumpShell(tester, shellHost(window: window));
      ToolButton tool(FermanMode mode, String label) =>
          tester.widget<ToolButton>(
            find.descendant(
              of: find.byKey(ShellToolRows.keyOf(mode), skipOffstage: false),
              matching: find.byWidgetPredicate(
                (widget) => widget is ToolButton && widget.label == label,
                skipOffstage: false,
              ),
              skipOffstage: false,
            ),
          );
      expect(tool(FermanMode.view, 'Select').active, isTrue);
      expect(tool(FermanMode.view, 'Hand').active, isFalse);
      expect(tool(FermanMode.view, 'Present').active, isNull);
      expect(tool(FermanMode.edit, 'Edit text').active, isTrue);
      expect(tool(FermanMode.sign, 'Fill fields').active, isTrue);
      expect(tool(FermanMode.protect, 'Redact').active, isTrue);
      expect(tool(FermanMode.view, 'Hand').shortcut, ['H']);
      expect(tool(FermanMode.edit, 'Add text').shortcut, ['Shift', 'T']);
      expect(tool(FermanMode.sign, 'Add text').shortcut, isNull);
      expect(tool(FermanMode.edit, 'Find & replace').shortcut, ['Ctrl', 'H']);
      expect(tool(FermanMode.tools, 'Print').shortcut, ['Ctrl', 'P']);
      expect(tool(FermanMode.organize, 'Rotate left').shortcut, ['Ctrl', '[']);
      expect(tool(FermanMode.organize, 'Delete').shortcut, ['Del']);
    });
  });

  group('title bar', () {
    testWidgets('shows the house button, the document tabs and their states', (
      tester,
    ) async {
      var home = 0;
      await pumpShell(tester, shellHost(window: window, onHome: () => home++));
      await tester.tap(iconButton('Home'));
      expect(home, 1);

      final tabs = tester
          .widgetList<DocumentTab>(find.byType(DocumentTab))
          .toList();
      expect(tabs.map((tab) => tab.name), [
        'Kira sözleşmesi.pdf',
        'e-Arşiv fatura 4187.pdf',
        'Hesap ekstresi Eylül 2026.pdf',
        'İmar planı açıklama raporu.pdf',
        'Maaş bordrosu Eylül 2026.pdf',
      ]);
      expect(tabs.map((tab) => tab.active), [true, false, false, false, false]);
      expect(tabs.map((tab) => tab.unsaved), [
        false,
        false,
        true,
        false,
        false,
      ]);
      expect(tabs.map((tab) => tab.loading), [
        false,
        false,
        false,
        true,
        false,
      ]);
      expect(tabs[4].icon, IconName.lock);
      expect(tabs[0].closeShortcut, ['Ctrl', 'W']);
      // The active clean tab's close button is drawn, disabled until
      // closing documents exists (M2).
      expect(tabs[0].closeDisabledReason, futureVersion);
      final close = tester.widget<IconButton>(iconButton('Close document'));
      expect(close.onPressed, isNull);
      expect(close.disabledReason, futureVersion);
      expect(close.shortcut, ['Ctrl', 'W']);
      expect(find.text('+3'), findsOneWidget);
      expect(find.bySemanticsLabel('3 more'), findsOneWidget);
      expect(
        tester.widget<IconButton>(iconButton('Open file')).disabledReason,
        // This host starts no engine, so opening takes G101's reason.
        'Ferman can’t open PDF files right now.',
      );
      final overflow = tester.widget<Button>(
        find.ancestor(of: find.text('+3'), matching: find.byType(Button)),
      );
      // "+N" opens the menu of the documents without a tab (a1-10).
      expect(overflow.disabledReason, isNull);
      expect(overflow.onPressed, isNotNull);
      expect(overflow.iconEnd, IconName.chevronDown);
      final search = tester.widget<Button>(
        find.ancestor(of: find.text('Search'), matching: find.byType(Button)),
      );
      expect(search.disabledReason, futureVersion);
      expect(search.variant, ButtonVariant.ghost);
    });

    testWidgets('activates a tab', (tester) async {
      await pumpShell(tester, shellHost(window: window));
      await tester.tap(find.text('e-Arşiv fatura 4187.pdf'));
      await settle(tester);
      expect(containerOf(tester).read(shellDocumentsProvider).activeIndex, 1);
      expect(find.text('Page 1 of 1'), findsOneWidget);
      expect(
        find.text('Saved on this device · ${bidiIsolate('11:05')}'),
        findsOneWidget,
      );
      // A locked document has no page count and is read-only.
      await tester.tap(find.text('Maaş bordrosu Eylül 2026.pdf'));
      await settle(tester);
      expect(find.textContaining('Page 1 of'), findsNothing);
      expect(find.text('Read-only'), findsOneWidget);
      // An unsaved document shows its dot instead of the close button.
      await tester.tap(find.text('Hesap ekstresi Eylül 2026.pdf'));
      await settle(tester);
      expect(iconButton('Close document'), findsNothing);
    });

    testWidgets('opens Settings from the button and with Ctrl+,', (
      tester,
    ) async {
      var opened = 0;
      await pumpShell(
        tester,
        shellHost(window: window, onOpenSettings: () => opened++),
      );
      final settings = tester.widget<IconButton>(iconButton('Settings'));
      expect(settings.disabledReason, isNull);
      expect(settings.shortcut, ['Ctrl', ',']);
      await tester.tap(iconButton('Settings'));
      expect(opened, 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(opened, 2);
    });

    testWidgets('leaves the space between the tabs and Search to move the '
        'window', (tester) async {
      await pumpShell(tester, shellHost(window: window));
      final plus = tester.getRect(iconButton('Open file'));
      final search = tester.getRect(
        find.ancestor(of: find.text('Search'), matching: find.byType(Button)),
      );
      expect(search.left - plus.right, greaterThan(20));
      final gap = Offset((plus.right + search.left) / 2, plus.center.dy);
      final gesture = await tester.startGesture(
        gap,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(40, 0));
      await gesture.up();
      expect(window.calls, contains('startDragging'));
    });

    testWidgets('shows the wordmark tab while home is active', (tester) async {
      await pumpShell(tester, titleBarHost(window: window, homeActive: true));
      expect(find.text('Ferman'), findsOneWidget);
      expect(iconButton('Home'), findsNothing);
      expect(
        tester
            .widgetList<DocumentTab>(find.byType(DocumentTab))
            .where((tab) => tab.active),
        isEmpty,
      );
    });
  });

  group('sidebar, canvas, panel and status bar', () {
    testWidgets('the sidebar tabs switch over an IndexedStack', (tester) async {
      await pumpShell(tester, shellHost(window: window));
      final control = find.byType(SegmentedControl<SidebarTab>);
      expect(
        tester.widget<SegmentedControl<SidebarTab>>(control).fullWidth,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(FmSidebar),
          matching: find.text('Pages'),
        ),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(iconButton('What the page badges mean'))
            .disabledReason,
        futureVersion,
      );
      final pages = tester.element(
        find.byKey(FmSidebar.keyOf(SidebarTab.pages), skipOffstage: false),
      );

      containerOf(tester)
          .read(shellSidebarTabProvider.notifier)
          .select(SidebarTab.outline);
      await settle(tester);
      expect(find.text('Outline'), findsOneWidget);
      expect(tester.widget<IconButton>(iconButton('Add bookmark')).shortcut, [
        'Ctrl',
        'B',
      ]);
      expect(iconButton('More'), findsNWidgets(2));

      containerOf(tester)
          .read(shellSidebarTabProvider.notifier)
          .select(SidebarTab.pages);
      await settle(tester);
      expect(
        identical(
          tester.element(find.byKey(FmSidebar.keyOf(SidebarTab.pages))),
          pages,
        ),
        isTrue,
      );
    });

    testWidgets('the canvas shows its empty state and has focus first', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpShell(tester, shellHost(window: window));
      expect(
        find.descendant(
          of: find.byType(ShellCanvas),
          matching: find.text(futureVersion),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Document pages'), findsOneWidget);
      expect(
        ShellRegion.of(FocusManager.instance.primaryFocus!.context!),
        ShellRegion.canvas,
      );
      semantics.dispose();
    });

    testWidgets('the canvas shows no focus ring for its launch focus, but '
        'does once the keyboard is used', (tester) async {
      // Desktop: the system shows focus highlights for keyboard focus.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await pumpShell(tester, shellHost(window: window));
      FocusRing ring() => tester.widget<FocusRing>(
        find.descendant(
          of: find.byType(ShellCanvas),
          matching: find.byType(FocusRing),
        ),
      );
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ShellCanvas');
      expect(ring().visible, isFalse);
      // A key pressed on the canvas is keyboard use (Shift moves no focus).
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ShellCanvas');
      expect(ring().visible, isTrue);
    });

    testWidgets('the canvas shows its focus ring when Tab brings focus back', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await pumpShell(tester, shellHost(window: window));
      FocusRing ring() => tester.widget<FocusRing>(
        find.descendant(
          of: find.byType(ShellCanvas),
          matching: find.byType(FocusRing),
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('ShellCanvas'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ShellCanvas');
      expect(ring().visible, isTrue);
    });

    testWidgets('the panel is titled Document, or Edit in Edit mode', (
      tester,
    ) async {
      await pumpShell(tester, shellHost(window: window));
      expect(
        find.descendant(
          of: find.byType(FmDocPanel),
          matching: find.text('Document'),
        ),
        findsOneWidget,
      );
      containerOf(tester)
          .read(shellModeProvider.notifier)
          .select(FermanMode.edit);
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(FmDocPanel),
          matching: find.text('Edit'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the status bar shows pages, zoom and the save state in the '
        "region's formats", (tester) async {
      await pumpShell(tester, shellHost(window: window));
      expect(find.text('Page 1 of 3'), findsOneWidget);
      // The region writes the percentage, not the UI language: Türkiye
      // puts the sign first (G34).
      expect(
        find.descendant(
          of: find.byType(ShellStatusBar),
          matching: find.text(bidiIsolate('%100')),
        ),
        findsOneWidget,
      );
      final zoom = tester.widget<Select<String>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Select<String> && widget.semanticLabel == 'Zoom',
        ),
      );
      expect(zoom.options.take(3).map((option) => option.label), [
        bidiIsolate('%50'),
        bidiIsolate('%75'),
        bidiIsolate('%100'),
      ]);
      final indicator = tester.widget<SaveIndicator>(
        find.byType(SaveIndicator),
      );
      expect(indicator.state, SaveState.saved);
      for (final label in [
        'Previous page',
        'Next page',
        'Zoom out',
        'Zoom in',
      ]) {
        expect(
          tester
              .widget<IconButton>(
                find.descendant(
                  of: find.byType(ShellStatusBar),
                  matching: iconButton(label),
                ),
              )
              .disabledReason,
          futureVersion,
        );
      }
    });

    testWidgets('the status bar reads Turkish from the design', (tester) async {
      await pumpShell(
        tester,
        shellHost(window: window, locale: const Locale('tr')),
      );
      expect(find.text('Sayfa 1 / 3'), findsOneWidget);
      expect(
        find.text('Bu cihaza kaydedildi · ${bidiIsolate('14:32')}'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ShellStatusBar),
          matching: find.text(bidiIsolate('%100')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the United States region writes 100% and 2:32 PM', (
      tester,
    ) async {
      await pumpShell(tester, shellHost(window: window, regionCode: 'US'));
      expect(
        find.descendant(
          of: find.byType(ShellStatusBar),
          matching: find.text(bidiIsolate('100%')),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Saved on this device · ${bidiIsolate('2:32\u202FPM')}'),
        findsOneWidget,
      );
    });

    testWidgets('a 12-hour time keeps its order in the Arabic status bar', (
      tester,
    ) async {
      await pumpShell(
        tester,
        shellHost(window: window, locale: const Locale('ar'), regionCode: 'US'),
      );
      // Isolated, "2:32 PM" never splits into "PM 2:32" in right to left.
      expect(
        find.text('حُفظ على هذا الجهاز · ${bidiIsolate('2:32\u202FPM')}'),
        findsOneWidget,
      );
    });

    testWidgets('the status bar reads Arabic from the design', (tester) async {
      await pumpShell(
        tester,
        shellHost(window: window, locale: const Locale('ar')),
      );
      expect(find.text('الصفحة 1 من 3'), findsOneWidget);
      // The Türkiye region decides, whatever the UI language.
      expect(
        find.descendant(
          of: find.byType(ShellStatusBar),
          matching: find.text(bidiIsolate('%100')),
        ),
        findsOneWidget,
      );
    });
  });

  group('accessibility', () {
    testWidgets('focus moves title bar, mode bar, tool row, sidebar, canvas, '
        'panel, status bar', (tester) async {
      await pumpShell(tester, shellHost(window: window, onHome: () {}));
      Focus.of(
        tester.element(
          find.descendant(of: iconButton('Home'), matching: find.byType(Icon)),
        ),
      ).requestFocus();
      await tester.pump();
      final seen = <ShellRegion>[];
      for (var i = 0; i < 120; i++) {
        final region = ShellRegion.of(
          FocusManager.instance.primaryFocus!.context!,
        );
        if (region != null && (seen.isEmpty || seen.last != region)) {
          seen.add(region);
        }
        if (seen.length > 1 && region == ShellRegion.titleBar) break;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(seen, [...ShellRegion.values, ShellRegion.titleBar]);
    });

    testWidgets('names every control', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpShell(tester, shellHost(window: window));
      final unnamed = <String>[];
      void visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        final flags = data.flagsCollection;
        final control =
            flags.isButton ||
            flags.isFocused != Tristate.none ||
            flags.isToggled != Tristate.none ||
            flags.isChecked != CheckedState.none;
        if (control &&
            data.label.trim().isEmpty &&
            data.tooltip.trim().isEmpty &&
            data.value.trim().isEmpty) {
          unnamed.add(node.toString());
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      SemanticsNode root() => tester
          .binding
          .renderViews
          .first
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!;
      // Every mode's tool row and every sidebar tab: the hidden children of
      // the IndexedStacks are not in the semantics tree until shown.
      final container = containerOf(tester);
      for (final mode in FermanMode.values) {
        container.read(shellModeProvider.notifier).select(mode);
        await settle(tester);
        final before = unnamed.length;
        visit(root());
        for (var i = before; i < unnamed.length; i++) {
          unnamed[i] = '${mode.id}: ${unnamed[i]}';
        }
      }
      container.read(shellModeProvider.notifier).select(FermanMode.view);
      for (final tab in SidebarTab.values) {
        container.read(shellSidebarTabProvider.notifier).select(tab);
        await settle(tester);
        final before = unnamed.length;
        visit(root());
        for (var i = before; i < unnamed.length; i++) {
          unnamed[i] = '${tab.name}: ${unnamed[i]}';
        }
      }
      expect(unnamed, isEmpty);
      semantics.dispose();
    });
  });
}
