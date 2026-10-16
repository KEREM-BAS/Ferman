import 'dart:ui' show SemanticsRole, Tristate;

import 'package:ferman/design/components/additions/document_tab.dart';
import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
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

    testWidgets('idle: no pressed fill, only the hover tint (FmWindow line '
        '24)', (tester) async {
      final theme = FermanTheme.light;
      Color? fill() =>
          (tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: find.byType(DocumentTab),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color;
      await tester.pumpWidget(
        componentHost(
          _tab('a.pdf'),
          forcedStates: const {WidgetState.hovered, WidgetState.pressed},
        ),
      );
      expect(fill(), theme.colors.surfaceHover);
      await tester.pumpWidget(
        componentHost(_tab('a.pdf'), forcedStates: const {WidgetState.pressed}),
      );
      await tester.pumpAndSettle();
      expect(fill(), transparent);
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
      // The library's xs IconButton, not a copy of it.
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.size, IconButtonSize.xs);
      expect(iconButton.icon, IconName.x);
      expect(iconButton.label, 'Close document');
      expect(iconButton.shortcut, ['Ctrl', 'W']);
      final button = find
          .ancestor(of: close, matching: find.byType(AnimatedContainer))
          .first;
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

      await tester.pumpWidget(componentHost(_tab('a.pdf', unsaved: true)));
      expect(
        (tester.widget<DecoratedBox>(dot).decoration as BoxDecoration).color,
        theme.colors.iconSecondary,
      );
      // One node, the tab, with both parts of the name, and no extra child
      // node (FermanInteractive alone states "not selected").
      final idle = tester.getSemantics(find.byType(FocusRing));
      expect(idle.label, 'a.pdf\nUnsaved changes');
      expect(idle.childrenCount, 0);
      expect(
        idle.getSemanticsData().flagsCollection.isSelected,
        Tristate.isFalse,
      );
      handle.dispose();
    });

    testWidgets('unsaved: the dot has its own "Unsaved changes" tooltip, on '
        'active and idle tabs', (tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      for (final active in [true, false]) {
        await tester.pumpWidget(
          componentHost(
            KeyedSubtree(
              key: ValueKey(active),
              child: _tab('a.pdf', active: active, unsaved: true),
            ),
          ),
        );
        final dot = find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(find.text('Unsaved changes'), findsNothing);
        await mouse.moveTo(tester.getCenter(dot));
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pumpAndSettle();
        expect(find.text('Unsaved changes'), findsOneWidget);
        // Not the name's tooltip.
        expect(find.text('a.pdf'), findsOneWidget);
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('loading: the spinner replaces the icon, and screen readers '
        'hear its status inside the tab', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          _tab(
            'İmar planı.pdf',
            active: true,
            loading: true,
            spinner: const Spinner(size: 12, semanticLabel: 'Opening'),
          ),
        ),
      );
      expect(tester.getSize(find.byType(Spinner)), const Size(12, 12));
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.name == IconName.fileText,
        ),
        findsNothing,
      );
      final status = tester.getSemantics(find.bySemanticsLabel('Opening'));
      expect(status, isSemantics(label: 'Opening', isLiveRegion: true));
      final tab = tester.getSemantics(find.bySemanticsLabel('İmar planı.pdf'));
      expect(tab.getSemanticsData().role, SemanticsRole.tab);
      expect(tab.label, 'İmar planı.pdf');
      expect(status.parent, tab);
      handle.dispose();
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

    testWidgets('keyboard: the inset ring and the focused state mark the tab, '
        'not while its close button has focus; Enter and Space activate', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
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
      Tristate focused(String label) => tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData()
          .flagsCollection
          .isFocused;
      // The close button is a Tab stop of its own after the tab: its focus
      // hangs beside the tab's, not under it.
      expect(tabStops, ['DocumentTab', 'FermanInteractive']);
      await focusFirstTabStop(tester);
      expect(focusLabel, 'DocumentTab');
      expect(tabRing().visible, isTrue);
      expect(tabRing().style, FocusRingStyle.inset);
      expect(focused('a.pdf'), Tristate.isTrue);
      expect(focused('Close document'), Tristate.isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 2);
      await pressTab(tester);
      expect(focusLabel, 'FermanInteractive');
      expect(tabRing().visible, isFalse);
      expect(focused('a.pdf'), Tristate.isFalse);
      expect(focused('Close document'), Tristate.isTrue);
      // The close button stays inside the tab for screen readers.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Close document')).parent,
        tester.getSemantics(find.bySemanticsLabel('a.pdf')),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(closes, 1);
      expect(presses, 2);
      tabStopNodes
          .firstWhere((node) => node.debugLabel == 'DocumentTab')
          .requestFocus();
      await tester.pumpAndSettle();
      expect(tabRing().visible, isTrue);
      expect(focused('a.pdf'), Tristate.isTrue);
      expect(focused('Close document'), Tristate.isFalse);
      handle.dispose();
    });
  });

  group('DocumentTabStrip', () {
    Widget strip({
      int active = 0,
      ValueChanged<int>? onPressed,
      Widget? overflow,
      Widget? trailing,
      double width = 900,
      double? height,
      List<String> names = const ['a.pdf', 'b.pdf', 'c.pdf'],
    }) => SizedBox(
      width: width,
      height: height,
      child: DocumentTabStrip(
        semanticLabel: 'Open documents',
        overflow: overflow,
        trailing: trailing,
        tabs: [
          for (final (i, name) in names.indexed)
            _tab(
              name,
              active: i == active,
              onPressed: () => onPressed?.call(i),
            ),
        ],
      ),
    );

    testWidgets('tabs 2 px apart, bottom-aligned 5 px down, then the '
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
      final strip0 = tester.getRect(find.byType(DocumentTabStrip));
      // The title bar's 37 px above its line; FmWindow's 6 px padding
      // leaves 31 px, which the 32 px tabs overflow by 1 px.
      expect(strip0.height, 37);
      expect(first.top - strip0.top, 5);
      final more = tester.getRect(find.byKey(const Key('more')));
      final open = tester.getRect(find.byKey(const Key('open')));
      final last = tester.getRect(tabs.at(2));
      expect(more.left - last.right, 4);
      expect(open.left - more.right, 2);
      // Centred in the 32 px row above its 4 px bottom padding.
      expect(last.bottom - more.bottom, 5);
    });

    testWidgets("in the title bar's 37 px: idle tabs 5..37 at full height, "
        'the active tab 6..38 over the line below', (tester) async {
      final theme = FermanTheme.light;
      // The area the window frame gives the title bar's content.
      final height = theme.density.titlebarH - theme.border.borderWidth;
      await tester.pumpWidget(
        componentHost(
          strip(
            height: height,
            trailing: const SizedBox(width: 26, height: 26, key: Key('open')),
          ),
        ),
      );
      final top = tester.getRect(find.byType(DocumentTabStrip)).top;
      final tabs = find.byType(DocumentTab);
      final idle = tester.getRect(tabs.at(1));
      expect(idle.top - top, 5);
      expect(idle.bottom - top, 37);
      final pill = find.descendant(
        of: tabs.at(1),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getRect(pill).top - top, 5);
      expect(tester.getSize(pill).height, 28);
      // Painted 1 px down by its translation: over the title bar's line.
      final active = tester.getRect(
        find
            .descendant(
              of: tabs.at(0),
              matching: find.byWidgetPredicate(
                (widget) => widget is Container && widget.decoration != null,
              ),
            )
            .first,
      );
      expect(active.top - top, 6);
      expect(active.bottom - top, 38);
      final open = tester.getRect(find.byKey(const Key('open')));
      expect(open.top - top, 6);
      expect(open.bottom - top, 32);
    });

    testWidgets('no open documents: no tab bar, and the buttons come first '
        'with no gap', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          strip(
            names: const [],
            trailing: Semantics(
              button: true,
              label: 'Open file',
              child: const SizedBox(width: 26, height: 26, key: Key('open')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Open documents'), findsNothing);
      expect(find.bySemanticsLabel('Open file'), findsOneWidget);
      final left = tester.getRect(find.byType(DocumentTabStrip)).left;
      expect(tester.getRect(find.byKey(const Key('open'))).left, left);
      expect(tabStops, isEmpty);

      await tester.pumpWidget(
        componentHost(
          strip(
            names: const [],
            overflow: const SizedBox(width: 50, height: 26, key: Key('more')),
            trailing: const SizedBox(width: 26, height: 26, key: Key('open')),
          ),
        ),
      );
      // Only the overflow button's own 2 px.
      expect(
        tester.getRect(find.byKey(const Key('more'))).left - left,
        DocumentTabStrip.overflowGap,
      );
      handle.dispose();
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
      final bar = tester.getSemantics(find.bySemanticsLabel('Open documents'));
      expect(bar, isSemantics(role: SemanticsRole.tabBar));
      final children = <SemanticsNode>[];
      bar.visitChildren((child) {
        children.add(child);
        return true;
      });
      expect(
        [for (final child in children) child.label],
        ['a.pdf', 'b.pdf', 'c.pdf'],
      );
      final open = tester.getSemantics(find.bySemanticsLabel('Open file'));
      expect(open.parent, isNot(bar));
      handle.dispose();
    });
  });
}
