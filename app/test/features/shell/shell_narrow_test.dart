import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/components/navigation/label_collapse.dart';
import 'package:ferman/design/tokens.g.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/features/shell/shell_canvas.dart';
import 'package:ferman/features/shell/shell_mode_bar.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_tool_rows.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';
import '../../helpers/fake_desktop_window.dart';
import 'shell_host.dart';

/// The languages the narrow shell is checked in (G21): English, Turkish,
/// Arabic and German-length labels.
const List<(String, Locale, bool)> _languages = [
  ('English', Locale('en'), false),
  ('Turkish', Locale('tr'), false),
  ('Arabic', Locale('ar'), false),
  ('German-length labels', Locale('en'), true),
];

/// The window widths checked: the artboard, two common laptop widths and
/// the minimum ([WindowMetrics.minimumWidth], Proposed).
const List<double> _widths = [1440, 1280, 1152, 1024];

/// Whether [finder]'s widget is in the row: painted and hit-tested.
bool _shown(Finder finder) => finder.hitTestable().evaluate().isNotEmpty;

/// The overflow button: the only ellipsis tool of a row.
bool _isOverflowButton(Widget widget) =>
    widget is ToolButton && widget.icon == IconName.ellipsis;

Finder _row(FermanMode mode) => find.byKey(ShellToolRows.keyOf(mode));

/// The tool buttons of [mode]'s row, without the overflow button.
List<ToolButton> _tools(WidgetTester tester, FermanMode mode) => tester
    .widgetList<ToolButton>(
      find.descendant(of: _row(mode), matching: find.byType(ToolButton)),
    )
    .where((tool) => !_isOverflowButton(tool))
    .toList();

Finder _toolFinder(FermanMode mode, ToolButton tool) =>
    find.descendant(of: _row(mode), matching: find.byWidget(tool));

/// Whether [tool]'s label is hidden behind its icon.
bool _compact(WidgetTester tester, FermanMode mode, ToolButton tool) {
  final labels = tester.renderObjectList<RenderCollapsibleLabel>(
    find.descendant(
      of: _toolFinder(mode, tool),
      matching: find.byType(CollapsibleLabel),
    ),
  );
  return labels.isNotEmpty && labels.first.isCompact;
}

Finder _overflowButton(FermanMode mode) => find.descendant(
  of: _row(mode),
  matching: find.byWidgetPredicate(_isOverflowButton),
);

/// Whether the mode tabs show only their icons.
bool _tabsIconsOnly(WidgetTester tester) => tester
    .renderObjectList<RenderCollapsibleLabel>(
      find.descendant(
        of: find.byType(ModeTabs),
        matching: find.byType(CollapsibleLabel),
      ),
    )
    .every((label) => label.isCompact);

Finder _iconButton(String label) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.label == label,
);

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.win));
  tearDown(() => window.dispose());

  group('narrow windows (G21)', () {
    for (final (name, locale, germanLike) in _languages) {
      testWidgets('$name: from 1440 to 1024 px every mode fits without '
          'overflow; labels hide from the end, the right panel steps aside '
          'and the mode tabs keep their labels', (tester) async {
        final sizes = ValueNotifier(const Size(1440, 720));
        await pumpShellAt(
          tester,
          shellHost(
            window: window,
            locale: locale,
            germanLike: germanLike,
            size: sizes,
          ),
          sizes,
        );
        final container = containerOf(tester);
        final previous = <FermanMode, int>{};
        for (final width in _widths) {
          for (final height in [720.0, if (width == 1024) 640.0]) {
            final size = Size(width, height);
            await resizeShell(tester, sizes, size);
            expect(tester.takeException(), isNull, reason: '$size');
            // Panels collapse before anything overlaps: both fit from
            // 216 + 264 + the canvas minimum.
            const both =
                FermanSizeTokens.sidebarW +
                FermanSizeTokens.panelW +
                WindowMetrics.canvasMinWidth;
            expect(find.byType(ShellSidebar), findsOneWidget);
            expect(
              find.byType(ShellPanel),
              width >= both ? findsOneWidget : findsNothing,
              reason: '$size',
            );
            expect(
              tester.getSize(find.byType(ShellCanvas)).width,
              greaterThanOrEqualTo(WindowMetrics.canvasMinWidth),
            );
            expect(_tabsIconsOnly(tester), isFalse, reason: '$size');
            // The document tabs keep at least `--doctab-w-min`.
            for (final tab in tester.widgetList(find.byType(DocumentTab))) {
              expect(
                tester.getSize(find.byWidget(tab)).width,
                greaterThanOrEqualTo(FermanSizeTokens.doctabWMin - 0.01),
                reason: '$size',
              );
            }
            for (final mode in FermanMode.values) {
              container.read(shellModeProvider.notifier).select(mode);
              await settle(tester);
              expect(tester.takeException(), isNull, reason: '$size $mode');
              final toolbar = tester
                  .getRect(
                    find.descendant(
                      of: _row(mode),
                      matching: find.byType(Toolbar),
                    ),
                  )
                  .deflate(8);
              final labelled = [
                for (final tool in _tools(tester, mode))
                  if (tool.showLabel) tool,
              ];
              final compact = [
                for (final tool in labelled)
                  if (_compact(tester, mode, tool)) tool.label,
              ];
              // Labels hide from the end of the row.
              expect(
                compact,
                labelled
                    .sublist(labelled.length - compact.length)
                    .map((tool) => tool.label),
                reason: '$size $mode',
              );
              // At these widths hiding labels is enough: every tool stays
              // in the row and inside it.
              expect(_shown(_overflowButton(mode)), isFalse);
              for (final tool in _tools(tester, mode)) {
                final finder = _toolFinder(mode, tool);
                expect(_shown(finder), isTrue, reason: '$size ${tool.label}');
                final rect = tester.getRect(finder);
                expect(rect.left, greaterThanOrEqualTo(toolbar.left - 0.01));
                expect(rect.right, lessThanOrEqualTo(toolbar.right + 0.01));
              }
              // A narrower window never shows more labels.
              expect(
                compact.length,
                greaterThanOrEqualTo(previous[mode] ?? 0),
                reason: '$size $mode',
              );
              previous[mode] = compact.length;
            }
          }
        }
        // At the artboard width every label shows (checked first), and at
        // 1024 px the Comment row has hidden some.
        expect(previous[FermanMode.comment], greaterThan(0));
      });
    }

    testWidgets('English: the boards’ 1440 px show every label; 1280 px hides '
        'only Measure’s', (tester) async {
      final sizes = ValueNotifier(const Size(1440, 900));
      await pumpShellAt(tester, shellHost(window: window, size: sizes), sizes);
      final container = containerOf(tester);
      container.read(shellModeProvider.notifier).select(FermanMode.comment);
      await settle(tester);
      List<String> compact() => [
        for (final tool in _tools(tester, FermanMode.comment))
          if (_compact(tester, FermanMode.comment, tool)) tool.label,
      ];
      expect(compact(), isEmpty);
      await resizeShell(tester, sizes, const Size(1280, 800));
      expect(compact(), ['Measure']);
      // The hidden label is the tooltip.
      final measure = _tools(
        tester,
        FermanMode.comment,
      ).firstWhere((tool) => tool.label == 'Measure');
      expect(
        find.descendant(
          of: _toolFinder(FermanMode.comment, measure),
          matching: find.text('Measure'),
        ),
        findsNothing,
      );
      await resizeShell(tester, sizes, const Size(1440, 900));
      expect(compact(), isEmpty);
    });

    testWidgets('the mode tabs fall back to icons only where their labels do '
        'not fit: German-length labels at 960 px, not at 1024', (tester) async {
      final sizes = ValueNotifier(const Size(1024, 720));
      await pumpShellAt(
        tester,
        shellHost(window: window, germanLike: true, size: sizes),
        sizes,
      );
      expect(_tabsIconsOnly(tester), isFalse);
      expect(find.text('Kommentieren'), findsOneWidget);
      // Keyboard focus on the selected tab survives the fallback.
      final tab = FocusManager.instance.rootScope.descendants.firstWhere(
        (node) => node.debugLabel == 'ModeTabs view',
      )..requestFocus();
      await settle(tester);
      await resizeShell(tester, sizes, const Size(960, 720));
      expect(tester.takeException(), isNull);
      expect(_tabsIconsOnly(tester), isTrue);
      expect(FocusManager.instance.primaryFocus, same(tab));
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Kommentieren'), findsOneWidget);
      handle.dispose();
      await resizeShell(tester, sizes, const Size(1024, 720));
      expect(_tabsIconsOnly(tester), isFalse);
      expect(FocusManager.instance.primaryFocus, same(tab));
      // Let the focused tab's tooltip timer run out.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('English mode tabs keep their labels at 960 px', (
      tester,
    ) async {
      final sizes = ValueNotifier(const Size(960, 720));
      await pumpShellAt(tester, shellHost(window: window, size: sizes), sizes);
      expect(tester.takeException(), isNull);
      expect(_tabsIconsOnly(tester), isFalse);
      expect(find.text('Comment'), findsOneWidget);
    });

    testWidgets('an icon-only mode tab names its mode in its tooltip', (
      tester,
    ) async {
      final sizes = ValueNotifier(const Size(960, 720));
      await pumpShellAt(
        tester,
        shellHost(window: window, germanLike: true, size: sizes),
        sizes,
      );
      expect(_tabsIconsOnly(tester), isTrue);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final comment = find
          .descendant(
            of: find.byType(ModeTabs),
            matching: find.byType(CollapsibleLabel),
          )
          .at(FermanMode.comment.index);
      await mouse.moveTo(tester.getCenter(comment));
      await tester.pump(const Duration(milliseconds: 450));
      await settle(tester);
      expect(find.text('Kommentieren'), findsOneWidget);
    });

    testWidgets('the panel toggles bring back a panel that stepped aside; '
        'the one opened last stays; both return when the window widens', (
      tester,
    ) async {
      final sizes = ValueNotifier(const Size(1024, 720));
      await pumpShellAt(tester, shellHost(window: window, size: sizes), sizes);
      final canvas = tester.state(find.byType(ShellCanvas));
      bool active(String label) =>
          tester.widget<IconButton>(_iconButton(label)).active ?? false;

      // The right panel steps aside first; its toggle reads as off.
      expect(find.byType(ShellSidebar), findsOneWidget);
      expect(find.byType(ShellPanel), findsNothing);
      expect(active('Show or hide sidebar'), isTrue);
      expect(active('Show or hide panel'), isFalse);

      // Opening it keeps it; the sidebar steps aside.
      await tester.tap(_iconButton('Show or hide panel'));
      await settle(tester);
      expect(find.byType(ShellPanel), findsOneWidget);
      expect(find.byType(ShellSidebar), findsNothing);
      expect(active('Show or hide sidebar'), isFalse);
      expect(active('Show or hide panel'), isTrue);

      // Its shortcut does the same for the sidebar (Ctrl+Alt+S on Linux).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.byType(ShellSidebar), findsOneWidget);
      expect(find.byType(ShellPanel), findsNothing);

      // Both come back when the window widens, and the one opened last
      // stays when it narrows again.
      await resizeShell(tester, sizes, const Size(1280, 720));
      expect(find.byType(ShellSidebar), findsOneWidget);
      expect(find.byType(ShellPanel), findsOneWidget);
      await tester.tap(_iconButton('Show or hide panel'));
      await settle(tester);
      await tester.tap(_iconButton('Show or hide panel'));
      await settle(tester);
      await resizeShell(tester, sizes, const Size(1024, 720));
      expect(find.byType(ShellPanel), findsOneWidget);
      expect(find.byType(ShellSidebar), findsNothing);

      // A panel that stepped aside stays open: closing the other gives it
      // the room back.
      await tester.tap(_iconButton('Show or hide panel'));
      await settle(tester);
      expect(find.byType(ShellPanel), findsNothing);
      expect(find.byType(ShellSidebar), findsOneWidget);

      // A closed panel stays closed when the window widens.
      await tester.tap(_iconButton('Show or hide sidebar'));
      await settle(tester);
      expect(find.byType(ShellSidebar), findsNothing);
      expect(find.byType(ShellPanel), findsNothing);
      await resizeShell(tester, sizes, const Size(1440, 720));
      expect(find.byType(ShellSidebar), findsNothing);
      expect(find.byType(ShellPanel), findsNothing);
      expect(identical(tester.state(find.byType(ShellCanvas)), canvas), isTrue);
    });

    testWidgets('below 904 px the panel toggle and its keys are disabled with '
        'the reason, below 856 px the sidebar’s too; the panels wait for a '
        'wider window', (tester) async {
      final sizes = ValueNotifier(const Size(880, 720));
      await pumpShellAt(tester, shellHost(window: window, size: sizes), sizes);
      final container = containerOf(tester);
      IconButton toggle(String label) =>
          tester.widget<IconButton>(_iconButton(label));
      Future<void> keys(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await settle(tester);
      }

      const reason = 'Make the window wider to show this panel';
      // 880 px: the sidebar fits on its own, the panel does not.
      expect(find.byType(ShellSidebar), findsOneWidget);
      expect(find.byType(ShellPanel), findsNothing);
      final panel = toggle('Show or hide panel');
      expect(panel.onPressed, isNull);
      expect(panel.active, isFalse);
      expect(panel.disabledReason, reason);
      await keys(LogicalKeyboardKey.keyP);
      expect(container.read(shellPanelOpenProvider), isTrue);
      expect(container.read(shellPanelPreferenceProvider), ShellSide.sidebar);
      expect(find.byType(ShellPanel), findsNothing);
      // The sidebar's toggle and keys still close and open it.
      expect(toggle('Show or hide sidebar').disabledReason, isNull);
      await tester.tap(_iconButton('Show or hide sidebar'));
      await settle(tester);
      expect(find.byType(ShellSidebar), findsNothing);
      await keys(LogicalKeyboardKey.keyS);
      expect(find.byType(ShellSidebar), findsOneWidget);

      // 800 px: neither fits; both toggles and their keys are disabled.
      await resizeShell(tester, sizes, const Size(800, 720));
      expect(find.byType(ShellSidebar), findsNothing);
      expect(find.byType(ShellPanel), findsNothing);
      for (final label in ['Show or hide sidebar', 'Show or hide panel']) {
        expect(toggle(label).onPressed, isNull, reason: label);
        expect(toggle(label).disabledReason, reason, reason: label);
      }
      await keys(LogicalKeyboardKey.keyS);
      await keys(LogicalKeyboardKey.keyP);
      expect(container.read(shellSidebarOpenProvider), isTrue);
      expect(container.read(shellPanelOpenProvider), isTrue);

      // Both come back when the window widens.
      await resizeShell(tester, sizes, const Size(1440, 720));
      expect(find.byType(ShellSidebar), findsOneWidget);
      expect(find.byType(ShellPanel), findsOneWidget);
      expect(toggle('Show or hide panel').onPressed, isNotNull);
    });

    testWidgets('a focused tool keeps its focus when its label hides and '
        'returns', (tester) async {
      final sizes = ValueNotifier(const Size(1440, 720));
      await pumpShellAt(tester, shellHost(window: window, size: sizes), sizes);
      containerOf(tester)
          .read(shellModeProvider.notifier)
          .select(FermanMode.comment);
      await settle(tester);
      final measure = _tools(
        tester,
        FermanMode.comment,
      ).firstWhere((tool) => tool.label == 'Measure');
      final node = Focus.of(
        tester.element(
          find
              .descendant(
                of: _toolFinder(FermanMode.comment, measure),
                matching: find.byType(GestureDetector),
              )
              .first,
        ),
      )..requestFocus();
      await settle(tester);
      expect(node.hasPrimaryFocus, isTrue);
      await resizeShell(tester, sizes, const Size(1024, 720));
      expect(_compact(tester, FermanMode.comment, measure), isTrue);
      expect(FocusManager.instance.primaryFocus, same(node));
      await resizeShell(tester, sizes, const Size(1440, 720));
      expect(_compact(tester, FermanMode.comment, measure), isFalse);
      expect(FocusManager.instance.primaryFocus, same(node));
    });

    testWidgets('right to left: the hidden labels are at the left end of the '
        'row, the panels mirrored', (tester) async {
      final sizes = ValueNotifier(const Size(1024, 720));
      await pumpShellAt(
        tester,
        shellHost(window: window, locale: const Locale('ar'), size: sizes),
        sizes,
      );
      containerOf(tester)
          .read(shellModeProvider.notifier)
          .select(FermanMode.comment);
      await settle(tester);
      final tools = _tools(tester, FermanMode.comment);
      final compact = [
        for (final tool in tools)
          if (_compact(tester, FermanMode.comment, tool)) tool,
      ];
      final full = [
        for (final tool in tools)
          if (!_compact(tester, FermanMode.comment, tool)) tool,
      ];
      expect(compact, isNotEmpty);
      final leftmostFull = full
          .map((tool) => tester.getRect(_toolFinder(FermanMode.comment, tool)))
          .map((rect) => rect.left)
          .reduce((a, b) => a < b ? a : b);
      for (final tool in compact) {
        expect(
          tester.getRect(_toolFinder(FermanMode.comment, tool)).right,
          lessThanOrEqualTo(leftmostFull),
        );
      }
      expect(tester.getRect(find.byType(ShellSidebar)).right, 1024);
      expect(find.byType(ShellPanel), findsNothing);
    });
  });

  group('the tool rows’ overflow menu', () {
    /// Only the tool rows, [width] wide.
    Widget rows(double width, ProviderContainer container) =>
        UncontrolledProviderScope(
          container: container,
          child: componentHost(
            SizedBox(width: width, child: const ShellToolRows()),
            size: const Size(1000, 600),
          ),
        );

    /// The name of an item of a row, as the overflow menu lists it; the
    /// zoom menu, the segmented controls, the buttons and the colours are
    /// in [ToolbarItem]s with their entry.
    String? nameOf(Widget widget) => switch (widget) {
      ToolButton(:final label) when !_isOverflowButton(widget) => label,
      IconButton(:final label) => label,
      Switch(:final label) => label,
      ToolbarItem(:final menuItem?) => menuItem.label,
      _ => null,
    };

    /// Whether [widget], an item of a row, is in the row.
    bool inRow(Widget widget) => switch (widget) {
      // The colour group: its first swatch (the group's centre is a gap).
      ToolbarItem(:final menuItem?) when menuItem.id == 'colors' => _shown(
        find.byWidgetPredicate(
          (swatch) =>
              swatch is FermanInteractive && swatch.semanticLabel == 'Yellow',
        ),
      ),
      _ => _shown(find.byWidget(widget)),
    };

    for (final mode in FermanMode.values) {
      testWidgets('${mode.id}: lists exactly the items out of the row, '
          'disabled with the future-version reason, toggles with their '
          'state', (tester) async {
        final container = ProviderContainer.test(
          overrides: [
            shortcutPlatformProvider.overrideWithValue(ShortcutPlatform.linux),
            initialSettingsProvider.overrideWithValue(
              const AppSettings(regionCode: 'TR'),
            ),
          ],
        );
        container.read(shellModeProvider.notifier).select(mode);
        tester.view
          ..physicalSize = const Size(1000, 600)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(rows(240, container));
        await settle(tester);
        expect(tester.takeException(), isNull);
        final items = tester
            .widgetList(
              find.descendant(
                of: _row(mode),
                matching: find.byWidgetPredicate(
                  (widget) => nameOf(widget) != null,
                ),
              ),
            )
            .toList();
        expect(_shown(_overflowButton(mode)), isTrue);
        final outside = [
          for (final item in items)
            if (!inRow(item)) nameOf(item)!,
        ];
        await tester.tap(_overflowButton(mode));
        await settle(tester);
        final menu = tester.widget<Menu>(find.byType(Menu));
        final entries = [
          for (final item in menu.items)
            if (!item.separator) item,
        ];
        expect(entries.map((item) => item.label), outside);
        for (final entry in entries) {
          expect(entry.disabled, isTrue, reason: entry.label);
          expect(entry.disabledReason, futureVersion, reason: entry.label);
        }
        for (final tool in _tools(tester, mode)) {
          final entry = entries.where((item) => item.label == tool.label);
          if (entry.isEmpty) continue;
          expect(entry.single.checked, tool.active, reason: tool.label);
        }
      });
    }

    testWidgets('Edit: Review edits keeps its count in the menu, written for '
        'the region', (tester) async {
      final container = ProviderContainer.test(
        overrides: [
          shortcutPlatformProvider.overrideWithValue(ShortcutPlatform.linux),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(regionCode: 'TR'),
          ),
        ],
      );
      container.read(shellModeProvider.notifier).select(FermanMode.edit);
      // The statement with three unsaved edits.
      container.read(shellDocumentsProvider.notifier).activate(2);
      tester.view
        ..physicalSize = const Size(1000, 600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(rows(240, container));
      await settle(tester);
      await tester.tap(_overflowButton(FermanMode.edit));
      await settle(tester);
      final review = tester
          .widget<Menu>(find.byType(Menu))
          .items
          .singleWhere((item) => item.id == 'review-edits');
      expect(review.label, 'Review edits (${bidiIsolate('3')})');
      expect(review.icon, IconName.listChecks);
    });

    testWidgets('Comment: the active tool is checked; Escape closes the menu '
        'and gives focus back to the overflow button', (tester) async {
      final container = ProviderContainer.test(
        overrides: [
          shortcutPlatformProvider.overrideWithValue(ShortcutPlatform.linux),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
        ],
      );
      container.read(shellModeProvider.notifier).select(FermanMode.comment);
      tester.view
        ..physicalSize = const Size(1000, 600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Narrow enough for Highlight, the active tool, to move. Show
      // comments sits outside the tools, as FmWindow draws it, and stays.
      await tester.pumpWidget(rows(240, container));
      await settle(tester);
      await tester.tap(_overflowButton(FermanMode.comment));
      await settle(tester);
      final menu = tester.widget<Menu>(find.byType(Menu));
      final highlight = menu.items.firstWhere(
        (item) => item.label == 'Highlight',
      );
      expect(highlight.checked, isTrue);
      expect(highlight.shortcut, ['H']);
      expect(highlight.disabledReason, futureVersion);
      // The menu has keyboard focus; Escape gives it back to the button.
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        startsWith('Menu item'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(Menu), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Toolbar overflow',
      );
    });
  });

  group('ShellModeBar', () {
    testWidgets('outside the shell the toggles follow the providers', (
      tester,
    ) async {
      final container = ProviderContainer.test(
        overrides: [
          shortcutPlatformProvider.overrideWithValue(ShortcutPlatform.linux),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
        ],
      );
      tester.view
        ..physicalSize = const Size(1440, 200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: componentHost(
            const SizedBox(width: 1440, child: ShellModeBar()),
            size: const Size(1440, 200),
          ),
        ),
      );
      expect(
        tester.widget<IconButton>(_iconButton('Show or hide panel')).active,
        isTrue,
      );
      await tester.tap(_iconButton('Show or hide panel'));
      await tester.pump();
      expect(container.read(shellPanelOpenProvider), isFalse);
      expect(
        tester.widget<IconButton>(_iconButton('Show or hide panel')).active,
        isFalse,
      );
    });
  });

  group('ShellPanels.resolve', () {
    ShellPanels resolve(
      double? width, {
      bool sidebar = true,
      bool panel = true,
      ShellSide preferred = ShellSide.sidebar,
    }) => ShellPanels.resolve(
      width: width,
      sidebarOpen: sidebar,
      panelOpen: panel,
      preferred: preferred,
    );

    test(
      'every open panel shows before the first layout and while both fit',
      () {
        expect(resolve(null), const ShellPanels(sidebar: true, panel: true));
        expect(resolve(1120), const ShellPanels(sidebar: true, panel: true));
        expect(
          resolve(1440, panel: false),
          const ShellPanels(sidebar: true, panel: false),
        );
      },
    );

    test('below that the panel opened last stays, the right panel steps '
        'aside first', () {
      expect(resolve(1119), const ShellPanels(sidebar: true, panel: false));
      expect(
        resolve(1024, preferred: ShellSide.panel),
        const ShellPanels(sidebar: false, panel: true),
      );
      expect(
        resolve(1024, sidebar: false),
        const ShellPanels(sidebar: false, panel: true),
      );
    });

    test(
      'when only the other one fits, it shows; at the narrowest none does',
      () {
        // 640 + 264 = 904: the panel no longer fits, the sidebar (856) does.
        expect(
          resolve(880, preferred: ShellSide.panel),
          const ShellPanels(sidebar: true, panel: false, panelAvailable: false),
        );
        expect(
          resolve(800),
          const ShellPanels(
            sidebar: false,
            panel: false,
            sidebarAvailable: false,
            panelAvailable: false,
          ),
        );
      },
    );

    test('a panel is available where it fits on its own: the panel from '
        '904 px, the sidebar from 856', () {
      expect(resolve(904).panelAvailable, isTrue);
      expect(resolve(903).panelAvailable, isFalse);
      expect(resolve(856).sidebarAvailable, isTrue);
      expect(resolve(855).sidebarAvailable, isFalse);
      expect(resolve(903).sidebarAvailable, isTrue);
      expect(resolve(null).available(ShellSide.panel), isTrue);
    });
  });
}
