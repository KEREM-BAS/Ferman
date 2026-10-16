/// ROADMAP §5 step 8: every action in the shortcut table appears in its
/// tooltip and menu as ⌘, ⌥, ⇧ on macOS and Ctrl, Alt, Shift on Windows and
/// Linux. The test walks every tool button, icon button, key cap and
/// overflow-menu entry of the shell in all eight modes and every sidebar
/// tab, on each system, and checks each against the shortcut table
/// (`shortcuts.dart`).
library;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_tool_rows.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/gen/app_localizations_en.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';
import '../../helpers/fake_desktop_window.dart';
import 'shell_host.dart';

/// The English labels.
final AppLocalizations _l10n = AppLocalizationsEn();

/// The commands of the controls every mode shows (the title bar, the mode
/// bar, the status bar and the sidebar), by the control's label.
final Map<String, ShellCommand> _chromeControls = {
  _l10n.shellOpenFile: ShellCommand.open,
  // The active tab's close button.
  _l10n.shellCloseDocument: ShellCommand.closeDocument,
  _l10n.shellSettings: ShellCommand.settings,
  _l10n.shellToggleSidebar: ShellCommand.toggleSidebar,
  _l10n.shellTogglePanel: ShellCommand.togglePanel,
  _l10n.shellPreviousPage: ShellCommand.previousPage,
  _l10n.shellNextPage: ShellCommand.nextPage,
  _l10n.shellZoomOut: ShellCommand.zoomOut,
  _l10n.shellZoomIn: ShellCommand.zoomIn,
  // Sidebar › Outline.
  _l10n.shellAddBookmark: ShellCommand.addBookmark,
};

/// The commands of each mode's tool row, by the tool's label. Tools not
/// listed (Split view, Page marks, Fill fields, Convert's tools …) have no
/// command and show no keys.
final Map<FermanMode, Map<String, ShellCommand>> _rowControls = {
  FermanMode.view: {
    _l10n.shellToolSelect: ShellCommand.selectTool,
    _l10n.shellToolHand: ShellCommand.handTool,
    _l10n.shellToolMarqueeZoom: ShellCommand.marqueeZoom,
    _l10n.shellZoomOut: ShellCommand.zoomOut,
    _l10n.shellZoomIn: ShellCommand.zoomIn,
    _l10n.shellToolPresent: ShellCommand.present,
  },
  FermanMode.edit: {
    _l10n.shellToolEditText: ShellCommand.editText,
    _l10n.shellToolAddText: ShellCommand.addText,
    _l10n.shellToolAddImage: ShellCommand.addImage,
    _l10n.shellToolLink: ShellCommand.link,
    _l10n.shellToolFindReplace: ShellCommand.findAndReplace,
    _l10n.shellUndo: ShellCommand.undo,
    _l10n.shellRedo: ShellCommand.redo,
  },
  FermanMode.comment: {
    for (final (tool, command) in [
      (AnnotationTool.select, ShellCommand.annotationSelect),
      (AnnotationTool.highlight, ShellCommand.highlight),
      (AnnotationTool.underline, ShellCommand.underline),
      (AnnotationTool.strikethrough, ShellCommand.strikethrough),
      (AnnotationTool.note, ShellCommand.note),
      (AnnotationTool.text, ShellCommand.textBox),
      (AnnotationTool.callout, ShellCommand.callout),
      (AnnotationTool.pen, ShellCommand.draw),
      (AnnotationTool.shapes, ShellCommand.shapes),
      (AnnotationTool.measure, ShellCommand.measure),
    ])
      _l10n.annotationToolLabel(tool): command,
  },
  FermanMode.sign: const {},
  FermanMode.organize: {
    _l10n.shellToolRotateLeft: ShellCommand.rotateLeft,
    _l10n.shellToolRotateRight: ShellCommand.rotateRight,
    _l10n.shellToolDelete: ShellCommand.deletePages,
  },
  FermanMode.convert: const {},
  FermanMode.protect: {_l10n.shellToolRedact: ShellCommand.redact},
  FermanMode.tools: {_l10n.shellToolPrint: ShellCommand.printDocument},
};

/// The commands of the choices the View row's zoom menu and Fit control
/// list as submenus in its overflow menu, by the choice's label.
final Map<String, ShellCommand> _choiceCommands = {
  _l10n.shellFitWidth: ShellCommand.fitWidth,
  _l10n.shellFitPage: ShellCommand.fitPage,
  _l10n.shellActualSize: ShellCommand.actualSize,
};

/// The commands that have a control but whose keys no M1 surface shows
/// (B034): the Fit segments and the zoom Select cannot show keys
/// (SegmentOption and SelectOption have no shortcut field), and the
/// overflow submenus that carry them sit under entries disabled until M2.
const Set<ShellCommand> _shownFromM2 = {
  ShellCommand.fitWidth,
  ShellCommand.fitPage,
  ShellCommand.actualSize,
};

/// The commands no control of the shell shows, with the reason. Their keys
/// are listed by the command palette (B030) and the cheat sheet (B076).
const Set<ShellCommand> _keysOnly = {
  // The cheat sheet itself (B076).
  ShellCommand.keyboardShortcuts,
  // The start screen's Create PDF card shows ⌘N (B019); FmWindow draws the
  // Convert row's Create PDF without keys.
  ShellCommand.createPdf,
  // Save is a Button, which shows no keys, as FmWindow draws it; Save as
  // and Save a copy have no control (B031).
  ShellCommand.save,
  ShellCommand.saveAs,
  ShellCommand.saveCopy,
  // Moving between documents (a1-10's note); the tabs show no keys.
  ShellCommand.nextDocument,
  ShellCommand.document1,
  ShellCommand.document2,
  ShellCommand.document3,
  ShellCommand.document4,
  ShellCommand.document5,
  ShellCommand.document6,
  ShellCommand.document7,
  ShellCommand.document8,
  ShellCommand.document9,
  // Find (B071), Go to page (B070) and reading mode (B039, G33).
  ShellCommand.find,
  ShellCommand.goToPage,
  ShellCommand.readingMode,
  // The Show comments switch: a Switch shows no keys (B050).
  ShellCommand.showComments,
  // Fill & Sign: the field navigation shows only on a form, and FmWindow
  // draws Date and Sign without keys (B052, B024).
  ShellCommand.nextField,
  ShellCommand.previousField,
  ShellCommand.todaysDate,
  ShellCommand.addSignature,
  // Organize: the page grid's keys and Insert from file (B056); FmWindow
  // draws Duplicate and Extract without keys.
  ShellCommand.duplicatePages,
  ShellCommand.extractPages,
  ShellCommand.insertFromFile,
  ShellCommand.selectAllPages,
  ShellCommand.movePagesUp,
  ShellCommand.movePagesDown,
  // Protect: FmWindow draws Find & redact without keys (only Redact has
  // them).
  ShellCommand.findAndRedact,
  // The window's own commands: the caption buttons and traffic lights give
  // their names without keys, as native windows do.
  ShellCommand.minimizeWindow,
  ShellCommand.closeWindow,
  ShellCommand.quit,
};

/// The title bar each system draws.
WindowPlatform _windowOf(ShortcutPlatform platform) => switch (platform) {
  ShortcutPlatform.mac => WindowPlatform.mac,
  ShortcutPlatform.windows => WindowPlatform.win,
  ShortcutPlatform.linux => WindowPlatform.linux,
};

/// A control the walk checks: a tool button or an icon button.
typedef _Control = ({
  Widget widget,
  String label,
  List<String>? shortcut,
  bool enabled,
  String? disabledReason,
  bool tooltip,
});

_Control? _controlOf(Widget widget) => switch (widget) {
  ToolButton() => (
    widget: widget,
    label: widget.label,
    shortcut: widget.shortcut,
    enabled: !widget.disabled && widget.onPressed != null,
    disabledReason: widget.disabledReason,
    // A tool button with its label shown has a tooltip only for its keys.
    tooltip: widget.shortcut != null || !widget.showLabel,
  ),
  IconButton() => (
    widget: widget,
    label: widget.label,
    shortcut: widget.shortcut,
    enabled: !widget.disabled && !widget.loading && widget.onPressed != null,
    disabledReason: widget.disabledReason,
    tooltip: widget.showTooltip,
  ),
  _ => null,
};

/// The tooltips under [finder]'s widget (Ferman's `Tooltip`).
List<Tooltip> _tooltipsOf(WidgetTester tester, Finder finder) => tester
    .widgetList<Tooltip>(
      find.descendant(of: finder, matching: find.byType(Tooltip)),
    )
    .toList();

void main() {
  for (final platform in ShortcutPlatform.values) {
    testWidgets('${platform.name}: every control bound to a command shows '
        'exactly its keys, or its reason while disabled, and every command '
        'with a control is found', (tester) async {
      final window = FakeDesktopWindow(_windowOf(platform));
      addTearDown(window.dispose);
      await pumpShell(
        tester,
        shellHost(
          window: window,
          platform: platform,
          onHome: () {},
          onOpenSettings: () {},
          aiEnabled: true,
        ),
      );
      final container = containerOf(tester);
      final found = <ShellCommand>{};
      final checked = <String>{};

      void walk(FermanMode mode, String where) {
        final row = find.byKey(ShellToolRows.keyOf(mode));
        final controls = [
          for (final widget in tester.widgetList(
            find.byWidgetPredicate((widget) => _controlOf(widget) != null),
          ))
            _controlOf(widget)!,
        ];
        expect(controls, isNotEmpty);
        for (final control in controls) {
          final finder = find.byWidget(control.widget);
          final inRow = find
              .descendant(of: row, matching: finder)
              .evaluate()
              .isNotEmpty;
          // A control the tables do not list (Home, More, the overflow
          // button "More tools" …) has no command and shows no keys.
          final command = inRow
              ? _rowControls[mode]![control.label]
              : _chromeControls[control.label];
          final keys = command?.caps(platform);
          final reason = '$where: ${control.label}';
          expect(control.shortcut, keys, reason: reason);
          if (command != null && keys != null) found.add(command);
          checked.add('${inRow ? mode.id : 'shell'} ${control.label}');

          final tooltips = _tooltipsOf(tester, finder);
          expect(tooltips.length, lessThanOrEqualTo(1), reason: reason);
          if (!control.enabled) {
            // Every disabled control says why (G10) …
            expect(control.disabledReason, isNotNull, reason: reason);
            // … in its tooltip, instead of its keys (G87).
            expect(tooltips, hasLength(1), reason: reason);
            expect(tooltips.single.message, control.disabledReason);
            expect(tooltips.single.shortcut, isNull, reason: reason);
          } else if (control.tooltip) {
            expect(tooltips, hasLength(1), reason: reason);
            expect(tooltips.single.message, control.label, reason: reason);
            expect(tooltips.single.shortcut, keys, reason: reason);
          } else {
            expect(tooltips, isEmpty, reason: reason);
          }
        }

        // The only key caps on screen are the Search button's.
        final search = find.ancestor(
          of: find.text(_l10n.shellSearch),
          matching: find.byType(Button),
        );
        expect(search, findsOneWidget);
        final caps = tester.widgetList<Kbd>(find.byType(Kbd)).toList();
        expect(caps, hasLength(1), reason: where);
        expect(
          find.descendant(of: search, matching: find.byWidget(caps.single)),
          findsOneWidget,
        );
        expect(caps.single.keys, ShellCommand.commandPalette.caps(platform));
        found.add(ShellCommand.commandPalette);
        // Search is disabled until M4: its tooltip is the reason.
        final searchTip = _tooltipsOf(tester, search).single;
        expect(searchTip.message, futureVersion);
        expect(searchTip.shortcut, isNull);
      }

      for (final mode in FermanMode.values) {
        container.read(shellModeProvider.notifier).select(mode);
        await settle(tester);
        walk(mode, mode.id);
      }
      container.read(shellModeProvider.notifier).select(FermanMode.view);
      for (final tab in SidebarTab.values) {
        container.read(shellSidebarTabProvider.notifier).select(tab);
        await settle(tester);
        walk(FermanMode.view, 'sidebar ${tab.name}');
      }

      // Every row's and the shell's commands have their control …
      for (final MapEntry(key: mode, value: tools) in _rowControls.entries) {
        for (final label in tools.keys) {
          expect(checked, contains('${mode.id} $label'));
        }
      }
      for (final label in _chromeControls.keys) {
        expect(checked, contains('shell $label'));
      }
      // … and every command of the table is shown by a control, or is one
      // of the listed key-only commands or of those shown from M2.
      expect(
        ShellCommand.values.toSet().difference(found).difference(_shownFromM2),
        _keysOnly,
      );
      expect(found.intersection(_keysOnly.union(_shownFromM2)), isEmpty);
    });

    testWidgets('${platform.name}: every overflow-menu entry shows exactly '
        'its command’s keys, and its reason as its tooltip', (tester) async {
      tester.view
        ..physicalSize = const Size(1000, 600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rowCommands = {
        for (final tools in _rowControls.values) ...tools.values,
      };
      final shown = <ShellCommand>{};
      final inSubmenus = <ShellCommand>{};
      for (final mode in FermanMode.values) {
        final container = ProviderContainer.test(
          overrides: [
            shortcutPlatformProvider.overrideWithValue(platform),
            initialSettingsProvider.overrideWithValue(const AppSettings()),
          ],
        );
        container.read(shellModeProvider.notifier).select(mode);
        // A row so narrow that every tool with keys moves into the overflow
        // menu: 80 px leaves room for the overflow button and one icon. The
        // Comment row keeps its Show comments switch beside the tools, as
        // FmWindow draws it, so 240 px leaves its tools the same room.
        final width = mode == FermanMode.comment ? 240.0 : 80.0;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: componentHost(
              SizedBox(width: width, child: const ShellToolRows()),
              size: const Size(1000, 600),
            ),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull, reason: mode.id);
        final row = find.byKey(ShellToolRows.keyOf(mode));
        final overflow = find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ToolButton && widget.icon == IconName.ellipsis,
          ),
        );
        await tester.tap(overflow);
        await settle(tester);
        final menuFinder = find.byType(Menu);
        final menu = tester.widget<Menu>(menuFinder);
        final entries = [
          for (final item in menu.items)
            if (item.isItem) item,
        ];
        expect(entries, isNotEmpty, reason: mode.id);
        for (final entry in entries) {
          final command = _rowControls[mode]![entry.label];
          final keys = command?.caps(platform);
          expect(entry.shortcut, keys, reason: '${mode.id}: ${entry.label}');
          if (command != null && keys != null) shown.add(command);
          // The choices of a submenu (the zoom menu, Fit, Page layout).
          for (final choice in entry.submenu ?? const <MenuItem>[]) {
            final choiceCommand = _choiceCommands[choice.label];
            expect(
              choice.shortcut,
              choiceCommand?.caps(platform),
              reason: '${mode.id}: ${entry.label} › ${choice.label}',
            );
            if (choiceCommand != null) inSubmenus.add(choiceCommand);
          }
        }
        // The menu rows draw the keys as caps, in order, disabled rows too,
        // as native menus do. G87's list of where key symbols show in M1
        // does not name this menu yet: whether a disabled row keeps its
        // caps is pending the lead's decision, and this expectation follows
        // it.
        expect(
          tester
              .widgetList<Kbd>(
                find.descendant(of: menuFinder, matching: find.byType(Kbd)),
              )
              .map((kbd) => kbd.keys),
          [for (final entry in entries) ?entry.shortcut],
          reason: mode.id,
        );
        // All disabled, the rows give the reason as their tooltip, without
        // keys (G10).
        final tooltips = _tooltipsOf(tester, menuFinder);
        expect(tooltips, hasLength(entries.length), reason: mode.id);
        for (final tooltip in tooltips) {
          expect(tooltip.message, futureVersion, reason: mode.id);
          expect(tooltip.shortcut, isNull, reason: mode.id);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
      // Every command of a tool row reaches the menu at this width …
      expect(shown, rowCommands);
      // … and the zoom and Fit submenus carry the Fit choices' keys, which
      // no one sees before their parents work in M2 (B034).
      expect(inSubmenus, _shownFromM2);
    });
  }
}
