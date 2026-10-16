import 'dart:ui' show CheckedState, SemanticsRole;

import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/overlays/menu.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;
  final dark = FermanTheme.dark.colors;

  const items = [
    MenuItem.section('Page'),
    MenuItem(
      id: 'rotate',
      label: 'Rotate',
      icon: IconName.rotateCw,
      shortcut: ['Ctrl', 'R'],
    ),
    MenuItem(id: 'copy', label: 'Copy', icon: IconName.copy, disabled: true),
    MenuItem(
      id: 'extract',
      label: 'Extract',
      disabled: true,
      disabledReason: 'Available in a future version',
    ),
    MenuItem(
      id: 'insert',
      label: 'Insert',
      submenu: [
        MenuItem(id: 'blank', label: 'Blank page'),
        MenuItem(id: 'file', label: 'From file'),
      ],
    ),
    MenuItem.divider(),
    MenuItem(
      id: 'delete',
      label: 'Delete',
      icon: IconName.trash2,
      danger: true,
    ),
  ];

  Widget host(Widget child, {TextDirection? textDirection}) => TapRegionSurface(
    child: componentHost(
      Align(
        alignment: AlignmentDirectional.topStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(20),
          child: child,
        ),
      ),
      textDirection: textDirection,
    ),
  );

  Widget menu({
    List<MenuItem> entries = items,
    ValueChanged<MenuItem>? onSelected,
    VoidCallback? onClose,
    bool autofocus = true,
  }) => Menu(
    items: entries,
    onSelected: onSelected,
    onClose: onClose,
    semanticLabel: 'Page menu',
    autofocus: autofocus,
  );

  Color? rowColor(WidgetTester tester, String label) {
    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('Menu', () {
    testWidgets('surface: at least 208 px, popover shadow, 28 px rows', (
      tester,
    ) async {
      await tester.pumpWidget(host(menu(autofocus: false)));
      await tester.pumpAndSettle();
      final surface = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(Menu),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = surface.decoration as BoxDecoration;
      expect(decoration.color, light.surfaceRaised);
      expect(decoration.boxShadow, FermanTheme.light.elevation.shadowPopover);
      expect(
        tester.getSize(find.byType(Menu)).width,
        greaterThanOrEqualTo(208),
      );
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Rotate'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        Menu.itemHeight,
      );
    });

    testWidgets('items: icon, plain shortcut, danger, disabled, heading, '
        'separator, submenu chevron', (tester) async {
      await tester.pumpWidget(host(menu(autofocus: false)));
      await tester.pumpAndSettle();
      final rotateIcon = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.name == IconName.rotateCw),
      );
      expect(rotateIcon.color, light.iconSecondary);
      expect(rotateIcon.size, 16);
      expect(tester.widget<Kbd>(find.byType(Kbd)).tone, KbdTone.plain);
      expect(
        tester.widget<Text>(find.text('Delete')).style!.color,
        light.danger,
      );
      expect(
        tester.widget<Text>(find.text('Copy')).style!.color,
        light.textDisabled,
      );
      expect(
        tester.widget<Text>(find.text('Page')).style!.color,
        light.textTertiary,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.name == IconName.chevronRight,
        ),
        findsOneWidget,
      );
    });

    testWidgets('a click selects an item', (tester) async {
      final chosen = <MenuItem>[];
      await tester.pumpWidget(host(menu(onSelected: chosen.add)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rotate'));
      expect(chosen.map((item) => item.id), ['rotate']);
      await tester.tap(find.text('Copy'), warnIfMissed: false);
      expect(chosen, hasLength(1));
    });

    testWidgets('hover tints a row', (tester) async {
      await tester.pumpWidget(host(menu(autofocus: false)));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Delete')));
      await tester.pump();
      expect(rowColor(tester, 'Delete'), light.surfaceSelectedStrong);
    });

    testWidgets('keyboard: autofocus on the first item, arrows skip plain '
        'disabled items, stop on a reason, wrap; Home, End, Enter, Escape', (
      tester,
    ) async {
      final chosen = <MenuItem>[];
      var closes = 0;
      await tester.pumpWidget(
        host(menu(onSelected: chosen.add, onClose: () => closes++)),
      );
      await tester.pumpAndSettle();
      expect(rowColor(tester, 'Rotate'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(rowColor(tester, 'Extract'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(chosen, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(rowColor(tester, 'Delete'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(rowColor(tester, 'Rotate'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(rowColor(tester, 'Delete'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(chosen.map((item) => item.id), ['rotate']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 1);
    });

    testWidgets('submenu: ArrowRight opens it beside the item with the first '
        'item focused; ArrowLeft closes it; choosing reports the item', (
      tester,
    ) async {
      final chosen = <MenuItem>[];
      await tester.pumpWidget(host(menu(onSelected: chosen.add)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(rowColor(tester, 'Insert'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Blank page'), findsOneWidget);
      final item = tester.getRect(find.text('Insert'));
      final sub = tester.getRect(find.byType(Menu).last);
      expect(sub.left, greaterThanOrEqualTo(item.right));
      expect(rowColor(tester, 'Blank page'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Blank page'), findsNothing);
      expect(rowColor(tester, 'Insert'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen.map((item) => item.id), ['file']);
      expect(find.text('From file'), findsNothing);
    });

    testWidgets('submenu: Escape closes only the submenu', (tester) async {
      var closes = 0;
      await tester.pumpWidget(host(menu(onClose: () => closes++)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();
      expect(find.text('Blank page'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Blank page'), findsNothing);
      expect(closes, 0);
    });

    testWidgets('submenu inside a popover: a click on it is not outside', (
      tester,
    ) async {
      final chosen = <MenuItem>[];
      var dismissed = 0;
      await tester.pumpWidget(
        host(
          Popover(
            open: true,
            surface: false,
            onDismiss: () => dismissed++,
            anchor: const SizedBox(width: 60, height: 20),
            child: menu(onSelected: chosen.add),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blank page'));
      await tester.pumpAndSettle();
      expect(dismissed, 0);
      expect(chosen.map((item) => item.id), ['blank']);
    });

    testWidgets('right to left: the submenu opens on the left; ArrowLeft '
        'opens it', (tester) async {
      // Centred, so both sides have room and no flip can hide a wrong side.
      await tester.pumpWidget(
        TapRegionSurface(
          child: componentHost(menu(), textDirection: TextDirection.rtl),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Blank page'), findsOneWidget);
      final row = tester.getRect(
        find
            .ancestor(of: find.text('Insert'), matching: find.byType(Container))
            .first,
      );
      final sub = tester.getRect(find.byType(Menu).last);
      expect(sub.right, lessThanOrEqualTo(row.left));
    });

    testWidgets('left to right, centred: the submenu opens on the right', (
      tester,
    ) async {
      await tester.pumpWidget(TapRegionSurface(child: componentHost(menu())));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final row = tester.getRect(
        find
            .ancestor(of: find.text('Insert'), matching: find.byType(Container))
            .first,
      );
      expect(
        tester.getRect(find.byType(Menu).last).left,
        greaterThanOrEqualTo(row.right),
      );
    });

    testWidgets('disabled with a reason: the reason as tooltip and hint when '
        'focused', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(menu()));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Extract')),
        isSemantics(
          label: 'Extract',
          hint: 'Available in a future version',
          role: SemanticsRole.menuItem,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
          isFocused: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled items keep the default arrow cursor', (tester) async {
      await tester.pumpWidget(host(menu(autofocus: false)));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      // A test mouse is device 1.
      MouseCursor? cursor() =>
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);
      await mouse.moveTo(tester.getCenter(find.text('Copy')));
      await tester.pump();
      expect(cursor(), SystemMouseCursors.basic);
      await mouse.moveTo(tester.getCenter(find.text('Extract')));
      await tester.pump();
      expect(cursor(), SystemMouseCursors.basic);
      await mouse.moveTo(tester.getCenter(find.text('Rotate')));
      await tester.pump();
      expect(cursor(), SystemMouseCursors.click);
    });

    testWidgets('item glyphs stay 16 px at touch density', (tester) async {
      await tester.pumpWidget(
        host(FermanThemeScope(touch: true, child: menu(autofocus: false))),
      );
      await tester.pumpAndSettle();
      final glyph = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.name == IconName.rotateCw),
      );
      expect(glyph.size, 16);
    });

    testWidgets('checkable items show a check column', (tester) async {
      await tester.pumpWidget(
        host(
          menu(
            autofocus: false,
            entries: const [
              MenuItem(label: 'Grid', checked: true),
              MenuItem(label: 'Rulers', checked: false),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      // `.fm-menu__item svg` colours the check's own svg: the row's icon
      // colour, not the span's accent.
      final check = tester.widget<Icon>(find.byType(Icon));
      expect(check.name, IconName.check);
      expect(check.color, light.iconSecondary);
      await tester.pumpWidget(
        host(
          menu(
            autofocus: false,
            entries: const [
              MenuItem(label: 'Purge', checked: true, danger: true),
              MenuItem(label: 'Locked', checked: true, disabled: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final checks = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(checks.map((icon) => icon.color), [
        light.danger,
        light.iconDisabled,
      ]);
      await tester.pumpWidget(
        TapRegionSurface(
          child: componentHost(
            menu(
              autofocus: false,
              entries: const [MenuItem(label: 'Grid', checked: true)],
            ),
            brightness: Brightness.dark,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Icon>(find.byType(Icon)).color, dark.iconSecondary);
    });

    testWidgets('semantics: a menu of menu items and checkbox items', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          menu(
            autofocus: false,
            entries: const [
              MenuItem(label: 'Rotate'),
              MenuItem(label: 'Grid', checked: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rotate = tester.getSemantics(find.text('Rotate'));
      expect(rotate.getSemanticsData().role, SemanticsRole.menuItem);
      final grid = tester.getSemantics(find.text('Grid')).getSemanticsData();
      expect(grid.role, SemanticsRole.menuItemCheckbox);
      expect(grid.flagsCollection.isChecked, CheckedState.isTrue);
      var node = rotate.parent;
      while (node != null &&
          node.getSemanticsData().role != SemanticsRole.menu) {
        node = node.parent;
      }
      expect(node?.label, 'Page menu');
      handle.dispose();
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        TapRegionSurface(
          child: componentHost(menu(), brightness: Brightness.dark),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        rowColor(tester, 'Rotate'),
        FermanTheme.dark.colors.surfaceSelectedStrong,
      );
      Color? textColor(String label) =>
          tester.widget<Text>(find.text(label)).style!.color;
      expect(textColor('Delete'), dark.danger);
      expect(textColor('Copy'), dark.textDisabled);
      expect(textColor('Page'), dark.textTertiary);
    });
  });
}
