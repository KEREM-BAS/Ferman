import 'dart:ui' show SemanticsRole, Tristate;

import 'package:ferman/design/components/additions/document_tab.dart';
import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import '../navigation/navigation_test_helpers.dart';

DocumentTab _tab(
  String name, {
  bool active = false,
  bool unsaved = false,
  bool loading = false,
  IconName icon = IconName.fileText,
  VoidCallback? onPressed,
  VoidCallback? onClose,
  Widget? spinner,
}) => DocumentTab(
  name: name,
  unsavedLabel: 'Unsaved changes',
  closeLabel: 'Close document',
  closeShortcut: const ['Ctrl', 'W'],
  active: active,
  unsaved: unsaved,
  loading: loading,
  icon: icon,
  onPressed: onPressed ?? () {},
  onClose: onClose,
  spinner: spinner,
);

Container _activeBox(WidgetTester tester) => tester.widget<Container>(
  find
      .descendant(
        of: find.byType(DocumentTab),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration != null,
        ),
      )
      .first,
);

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
  return mouse;
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('DocumentTab', () {
    testWidgets('active: 32 px on the panel surface, open at the bottom, '
        'strong name, 1 px over the border below', (tester) async {
      await tester.pumpWidget(
        componentHost(_tab('Kira sözleşmesi.pdf', active: true)),
      );
      final theme = FermanTheme.light;
      final box = _activeBox(tester);
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, theme.colors.surfacePanel);
      final side = BorderSide(color: theme.colors.borderSubtle);
      expect(
        decoration.border,
        BorderDirectional(top: side, start: side, end: side),
      );
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(8)),
      );
      expect(box.padding, const EdgeInsetsDirectional.only(start: 10, end: 4));
      expect(tester.getSize(find.byType(DocumentTab)), const Size(188, 32));
      final translate = tester.widget<Transform>(
        find.descendant(
          of: find.byType(DocumentTab),
          matching: find.byType(Transform),
        ),
      );
      expect(translate.transform.getTranslation().y, 1);
      expect(
        textColor(tester, 'Kira sözleşmesi.pdf'),
        theme.colors.textPrimary,
      );
      expect(
        textStyle(tester, 'Kira sözleşmesi.pdf').fontWeight,
        FontWeight.w500,
      );
      final icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(icon.name, IconName.fileText);
      expect(icon.size, 14);
      expect(icon.color, theme.colors.iconSecondary);
    });

    testWidgets('idle: a 28 px rounded row in the secondary colour that '
        'tints on hover', (tester) async {
      await tester.pumpWidget(componentHost(_tab('e-Arşiv fatura 4187.pdf')));
      final theme = FermanTheme.light;
      final inner = find.descendant(
        of: find.byType(DocumentTab),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(inner), const Size(188, 28));
      expect(tester.getSize(find.byType(DocumentTab)).height, 32);
      // 4 px below it.
      expect(
        tester.getRect(find.byType(DocumentTab)).bottom -
            tester.getRect(inner).bottom,
        4,
      );
      final decoration =
          tester.widget<AnimatedContainer>(inner).decoration! as BoxDecoration;
      expect(decoration.color, transparent);
      expect(decoration.borderRadius, BorderRadius.circular(6));
      expect(
        textColor(tester, 'e-Arşiv fatura 4187.pdf'),
        theme.colors.textSecondary,
      );
      expect(
        textStyle(tester, 'e-Arşiv fatura 4187.pdf').fontWeight,
        FontWeight.w400,
      );
      await _hover(tester, inner);
      expect(
        (tester.widget<AnimatedContainer>(inner).decoration! as BoxDecoration)
            .color,
        theme.colors.surfaceHover,
      );
      // The full name shows in a tooltip.
      expect(find.text('e-Arşiv fatura 4187.pdf'), findsNWidgets(2));
    });

    testWidgets('the active clean tab has a 22 px close button with the '
        'shortcut in its tooltip', (tester) async {
      var closes = 0;
      var presses = 0;
      await tester.pumpWidget(
        componentHost(
          _tab(
            'Kira sözleşmesi.pdf',
            active: true,
            onPressed: () => presses++,
            onClose: () => closes++,
          ),
        ),
      );
      final close = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.name == IconName.x,
      );
      expect(close, findsOneWidget);
      final button = find.ancestor(
        of: close,
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(button), const Size(22, 22));
      await tester.tap(close);
      expect(closes, 1);
      expect(presses, 0);
      await _hover(tester, close);
      expect(find.text('Close document'), findsOneWidget);
      expect(find.byType(Kbd), findsOneWidget);
    });

    testWidgets('idle clean tabs keep the close space empty', (tester) async {
      await tester.pumpWidget(componentHost(_tab('a.pdf', onClose: () {})));
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.name == IconName.x,
        ),
        findsNothing,
      );
    });

    testWidgets('unsaved: a 7 px dot replaces the close button and is read '
        'after the name', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          _tab(
            'Kira sözleşmesi.pdf',
            active: true,
            unsaved: true,
            onClose: () {},
          ),
        ),
      );
      final theme = FermanTheme.light;
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.name == IconName.x,
        ),
        findsNothing,
      );
      final dot = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(tester.getSize(dot), const Size(7, 7));
      expect(
        (tester.widget<DecoratedBox>(dot).decoration as BoxDecoration).color,
        theme.colors.iconPrimary,
      );
      final node = tester.getSemantics(find.byType(FocusRing));
      expect(node.label, 'Kira sözleşmesi.pdf\nUnsaved changes');
      handle.dispose();

      await tester.pumpWidget(componentHost(_tab('a.pdf', unsaved: true)));
      expect(
        (tester.widget<DecoratedBox>(dot).decoration as BoxDecoration).color,
        theme.colors.iconSecondary,
      );
    });

    testWidgets('loading: the spinner replaces the icon', (tester) async {
      await tester.pumpWidget(
        componentHost(
          _tab(
            'İmar planı.pdf',
            active: true,
            loading: true,
            spinner: const SizedBox.square(dimension: 12, key: Key('spinner')),
          ),
        ),
      );
      expect(find.byKey(const Key('spinner')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.name == IconName.fileText,
        ),
        findsNothing,
      );
    });

    testWidgets('locked and repaired icons', (tester) async {
      await tester.pumpWidget(
        componentHost(_tab('Maaş bordrosu.pdf', icon: IconName.lock)),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.lock);
    });

    testWidgets('dark: the active tab is on the dark panel surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(_tab('a.pdf', active: true), brightness: Brightness.dark),
      );
      final decoration = _activeBox(tester).decoration! as BoxDecoration;
      expect(decoration.color, FermanTheme.dark.colors.surfacePanel);
    });

    testWidgets('the name takes its own direction (dir="auto")', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(_tab('عقد الإيجار.pdf')));
      expect(
        tester.widget<Text>(find.text('عقد الإيجار.pdf')).textDirection,
        TextDirection.rtl,
      );
      await tester.pumpWidget(
        componentHost(
          _tab('Kira sözleşmesi.pdf'),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.widget<Text>(find.text('Kira sözleşmesi.pdf')).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('a long name is ellipsized within 188 px', (tester) async {
      await tester.pumpWidget(
        componentHost(
          _tab('Hesap ekstresi Eylül 2026 ve diğer ekler birleştirilmiş.pdf'),
        ),
      );
      expect(tester.getSize(find.byType(DocumentTab)).width, 188);
      expect(
        tester
            .renderObject<RenderParagraph>(
              find.textContaining('Hesap ekstresi'),
            )
            .didExceedMaxLines,
        isTrue,
      );
    });

    testWidgets('semantics: a tab with the selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(_tab('a.pdf', active: true)));
      final node = tester.getSemantics(find.bySemanticsLabel('a.pdf'));
      expect(node.getSemanticsData().role, SemanticsRole.tab);
      expect(
        node.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(node, isSemantics(isFocusable: true, hasTapAction: true));
      await tester.pumpWidget(componentHost(_tab('b.pdf')));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('b.pdf'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      handle.dispose();
    });

    testWidgets('keyboard: the inset ring marks the tab, not while its close '
        'button has focus; Enter activates', (tester) async {
      var presses = 0;
      var closes = 0;
      await tester.pumpWidget(
        componentHost(
          _tab(
            'a.pdf',
            active: true,
            onPressed: () => presses++,
            onClose: () => closes++,
          ),
        ),
      );
      FocusRing tabRing() => tester.widget<FocusRing>(
        find.byWidgetPredicate(
          (widget) =>
              widget is FocusRing && widget.style == FocusRingStyle.inset,
        ),
      );
      // The close button's node is inside the tab's, so it comes first
      // among the descendants; focus the tab itself.
      tabStopNodes
          .firstWhere((node) => node.debugLabel == 'DocumentTab')
          .requestFocus();
      await tester.pumpAndSettle();
      expect(tabRing().visible, isTrue);
      expect(tabRing().style, FocusRingStyle.inset);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 1);
      // The close button is a Tab stop of its own, inside the tab.
      expect(tabStops, ['FermanInteractive', 'DocumentTab']);
      tabStopNodes
          .firstWhere((node) => node.debugLabel == 'FermanInteractive')
          .requestFocus();
      await tester.pumpAndSettle();
      expect(focusLabel, 'FermanInteractive');
      expect(tabRing().visible, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(closes, 1);
      expect(presses, 1);
    });
  });

  group('DocumentTabStrip', () {
    Widget strip({
      int active = 0,
      ValueChanged<int>? onPressed,
      Widget? overflow,
      Widget? trailing,
      double width = 900,
    }) => SizedBox(
      width: width,
      child: DocumentTabStrip(
        semanticLabel: 'Open documents',
        overflow: overflow,
        trailing: trailing,
        tabs: [
          for (final (i, name) in ['a.pdf', 'b.pdf', 'c.pdf'].indexed)
            _tab(
              name,
              active: i == active,
              onPressed: () => onPressed?.call(i),
            ),
        ],
      ),
    );

    testWidgets('tabs 2 px apart, bottom-aligned 6 px down, then the '
        'overflow and open buttons', (tester) async {
      await tester.pumpWidget(
        componentHost(
          strip(
            overflow: const SizedBox(width: 50, height: 26, key: Key('more')),
            trailing: const SizedBox(width: 26, height: 26, key: Key('open')),
          ),
        ),
      );
      final tabs = find.byType(DocumentTab);
      final first = tester.getRect(tabs.at(0));
      final second = tester.getRect(tabs.at(1));
      expect(second.left - first.right, 2);
      expect(first.top - tester.getRect(find.byType(DocumentTabStrip)).top, 6);
      final more = tester.getRect(find.byKey(const Key('more')));
      final open = tester.getRect(find.byKey(const Key('open')));
      final last = tester.getRect(tabs.at(2));
      expect(more.left - last.right, 4);
      expect(open.left - more.right, 2);
      // Centred in the 32 px row above its 4 px bottom padding.
      expect(last.bottom - more.bottom, 5);
    });

    testWidgets('tabs shrink when space runs out', (tester) async {
      await tester.pumpWidget(componentHost(strip(width: 400)));
      final width = tester.getSize(find.byType(DocumentTab).first).width;
      expect(width, lessThan(188));
      expect(width, closeTo((400 - 4) / 3, 0.01));
    });

    testWidgets('only the active tab is a Tab stop; arrows move and '
        'activate, wrapping, mirrored in right to left', (tester) async {
      final presses = <int>[];
      await tester.pumpWidget(
        componentHost(strip(active: 1, onPressed: presses.add)),
      );
      expect(tabStops, ['DocumentTabStrip 1']);
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(presses, [2]);
      expect(focusLabel, 'DocumentTabStrip 2');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(presses, [2, 0]);

      presses.clear();
      await tester.pumpWidget(
        componentHost(
          KeyedSubtree(
            key: const ValueKey('rtl'),
            child: strip(active: 1, onPressed: presses.add),
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(presses, [0]);
    });

    testWidgets('semantics: a tab bar of the tabs only', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          strip(
            trailing: Semantics(
              button: true,
              label: 'Open file',
              child: const SizedBox(width: 26, height: 26),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Open documents')),
        isSemantics(role: SemanticsRole.tabBar),
      );
      expect(find.bySemanticsLabel('Open file'), findsOneWidget);
      handle.dispose();
    });
  });
}
