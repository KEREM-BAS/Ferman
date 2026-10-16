import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/empty/drop_zone.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;
  const recent = [
    RecentFile(name: 'Kira sözleşmesi.pdf', meta: '2 hours ago'),
    RecentFile(name: 'Ekstre.pdf', meta: 'Yesterday', path: '/docs/e.pdf'),
  ];

  Widget zone({
    DropZoneState state = DropZoneState.idle,
    VoidCallback? onOpen,
    VoidCallback? onCreate,
    ValueChanged<RecentFile>? onOpenRecent,
    ValueChanged<List<String>>? onFiles,
    String? disabledReason,
    List<RecentFile> files = const [],
    List<String> shortcut = const ['⌘', 'O'],
    double? minHeight,
  }) => SizedBox(
    width: 700,
    child: DropZone(
      state: state,
      title: 'Drop a PDF here',
      subtitle: 'Or open one from your computer.',
      overTitle: 'Release to open',
      overSubtitle: 'Ferman opens the file on this device.',
      errorTitle: 'That file isn’t a PDF',
      errorSubtitle: 'Ferman opens PDF files.',
      openLabel: 'Open a PDF',
      createLabel: 'New blank PDF',
      recentTitle: 'Recent',
      footnote: 'Files stay on this device.',
      shortcut: shortcut,
      onOpen: onOpen,
      onCreate: onCreate,
      onOpenRecent: onOpenRecent,
      onFiles: onFiles,
      disabledReason: disabledReason,
      recent: files,
      minHeight: minHeight,
    ),
  );

  /// Tab moves focus, as in the app (WidgetsApp's shortcuts), starting in
  /// a focused scope.
  Widget tabHost(Widget child) => Shortcuts(
    shortcuts: WidgetsApp.defaultShortcuts,
    child: Actions(
      actions: WidgetsApp.defaultActions,
      child: FocusScope(autofocus: true, child: child),
    ),
  );

  DropZoneBorderPainter border(WidgetTester tester) =>
      tester
              .widgetList<CustomPaint>(
                find.descendant(
                  of: find.byType(DropZone),
                  matching: find.byType(CustomPaint),
                ),
              )
              .firstWhere(
                (paint) => paint.foregroundPainter is DropZoneBorderPainter,
              )
              .foregroundPainter!
          as DropZoneBorderPainter;

  final body = find
      .descendant(
        of: find.byType(DropZone),
        matching: find.byType(AnimatedContainer),
      )
      .first;

  Icon stateIcon(WidgetTester tester) => tester
      .widgetList<Icon>(
        find.descendant(of: find.byType(DropZone), matching: find.byType(Icon)),
      )
      .first;

  Button button(WidgetTester tester, String label) => tester.widget<Button>(
    find.ancestor(of: find.text(label), matching: find.byType(Button)),
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('DropZone states', () {
    testWidgets('idle: dashed strong border, copy, actions, footnote', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(zone(onOpen: () {}, onCreate: () {}, files: recent)),
      );
      final painter = border(tester);
      expect(painter.dashed, isTrue);
      expect(painter.color, light.borderStrong);
      expect(painter.width, FermanBorderTokens.borderWidthStrong);
      expect(painter.radius, FermanRadiusTokens.radiusXl);
      expect(stateIcon(tester).name, IconName.fileText);
      expect(stateIcon(tester).color, light.iconSecondary);
      expect(stateIcon(tester).size, DropZone.iconSize);
      expect(find.text('Drop a PDF here'), findsOneWidget);
      expect(find.text('Or open one from your computer.'), findsOneWidget);
      final open = button(tester, 'Open a PDF');
      expect(open.variant, ButtonVariant.primary);
      expect(open.size, ButtonSize.lg);
      expect(open.icon, IconName.folderOpen);
      expect(find.text('⌘O'), findsOneWidget);
      final create = button(tester, 'New blank PDF');
      expect(create.variant, ButtonVariant.secondary);
      expect(create.size, ButtonSize.lg);
      expect(create.icon, IconName.filePlus2);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Kira sözleşmesi.pdf'), findsOneWidget);
      expect(find.text('Files stay on this device.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.name == IconName.hardDrive,
        ),
        findsOneWidget,
      );
    });

    testWidgets('type: 20 px semibold title, prose subtitle, centred', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(zone(onOpen: () {})));
      final title = tester.widget<Text>(find.text('Drop a PDF here'));
      expect(title.style!.fontSize, FermanTypeTokens.size2xl);
      expect(title.style!.fontWeight, FermanTypeTokens.weightSemibold);
      expect(title.style!.color, light.textPrimary);
      expect(title.textAlign, TextAlign.center);
      final sub = tester.widget<Text>(
        find.text('Or open one from your computer.'),
      );
      expect(sub.style!.fontSize, FermanTypeTokens.sizeLg);
      expect(sub.style!.color, light.textSecondary);
    });

    testWidgets('at least 380 px tall, or minHeight, applied at once', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(zone(onOpen: () {})));
      expect(tester.getSize(body).height, DropZone.defaultMinHeight);
      expect(tester.getSize(body).width, 700);
      await tester.pumpWidget(
        componentHost(zone(onOpen: () {}, minHeight: 470)),
      );
      // `.fm-drop` transitions only colours: no tween of the height.
      expect(tester.getSize(body).height, 470);
    });

    testWidgets('the icon tile: raised, the 1 px subtle ring over the small '
        'shadow', (tester) async {
      await tester.pumpWidget(componentHost(zone(onOpen: () {})));
      final tile = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(Icon).first,
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = tile.decoration! as BoxDecoration;
      expect(decoration.color, light.surfaceRaised);
      final shadows = decoration.boxShadow!;
      // Flutter paints the last layer on top; CSS the first.
      expect(
        shadows.last,
        BoxShadow(color: light.borderSubtle, spreadRadius: 1),
      );
      expect(
        shadows.take(shadows.length - 1).toList(),
        FermanElevationTokens.light.shadowSm,
      );
    });

    testWidgets('over: solid accent border and fill, no actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          zone(
            state: DropZoneState.over,
            onOpen: () {},
            onCreate: () {},
            files: recent,
          ),
        ),
      );
      expect(border(tester).dashed, isFalse);
      expect(border(tester).color, light.accent);
      final decoration =
          tester.widget<AnimatedContainer>(body).decoration! as BoxDecoration;
      expect(decoration.color, light.accentSubtle);
      expect(stateIcon(tester).name, IconName.download);
      expect(stateIcon(tester).color, light.textAccent);
      expect(find.text('Release to open'), findsOneWidget);
      expect(find.byType(Button), findsNothing);
      expect(find.text('Recent'), findsNothing);
      expect(find.text('Files stay on this device.'), findsNothing);
    });

    testWidgets('error: dashed danger border, alert icon, actions stay', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          zone(state: DropZoneState.error, onOpen: () {}, files: recent),
        ),
      );
      expect(border(tester).dashed, isTrue);
      expect(border(tester).color, light.dangerBorder);
      expect(stateIcon(tester).name, IconName.circleAlert);
      expect(stateIcon(tester).color, light.danger);
      expect(find.text('That file isn’t a PDF'), findsOneWidget);
      expect(find.text('Open a PDF'), findsOneWidget);
      expect(find.text('Recent'), findsNothing);
      expect(find.text('Files stay on this device.'), findsNothing);
    });

    testWidgets('dark theme: over fill takes the dark accent subtle', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          zone(state: DropZoneState.over),
          brightness: Brightness.dark,
        ),
      );
      final decoration =
          tester.widget<AnimatedContainer>(body).decoration! as BoxDecoration;
      expect(decoration.color, FermanColorTokens.dark.accentSubtle);
      expect(border(tester).color, FermanColorTokens.dark.accent);
    });
  });

  group('DropZone dragging', () {
    Widget withSource(Widget child) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Draggable<List<String>>(
          data: ['/docs/a.pdf', '/docs/b.pdf'],
          feedback: SizedBox.square(dimension: 10),
          // Hit-testable, so a press on it starts the drag.
          child: ColoredBox(
            color: Color(0xFF000000),
            child: SizedBox.square(dimension: 40, key: Key('source')),
          ),
        ),
        child,
      ],
    );

    testWidgets('a drag over it shows over; a drop calls onFiles', (
      tester,
    ) async {
      List<String>? dropped;
      await tester.pumpWidget(
        componentHost(
          withSource(zone(onOpen: () {}, onFiles: (paths) => dropped = paths)),
        ),
      );
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('source'))),
      );
      await drag.moveBy(const Offset(0, 30));
      await tester.pump();
      await drag.moveTo(tester.getCenter(find.byType(DropZone)));
      await tester.pump();
      expect(find.text('Release to open'), findsOneWidget);
      expect(border(tester).dashed, isFalse);
      await drag.up();
      await tester.pumpAndSettle();
      expect(dropped, ['/docs/a.pdf', '/docs/b.pdf']);
      expect(find.text('Drop a PDF here'), findsOneWidget);
    });

    testWidgets('disabled with a reason ignores drags', (tester) async {
      List<String>? dropped;
      await tester.pumpWidget(
        componentHost(
          withSource(
            zone(
              disabledReason: 'Available in a future version',
              onFiles: (paths) => dropped = paths,
            ),
          ),
        ),
      );
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('source'))),
      );
      await drag.moveBy(const Offset(0, 30));
      await tester.pump();
      await drag.moveTo(tester.getCenter(find.byType(DropZone)));
      await tester.pump();
      expect(find.text('Release to open'), findsNothing);
      await drag.up();
      await tester.pumpAndSettle();
      expect(dropped, isNull);
    });
  });

  group('DropZone actions and recent files', () {
    testWidgets('Open, New and a recent file call back', (tester) async {
      var opens = 0;
      var creates = 0;
      RecentFile? picked;
      await tester.pumpWidget(
        componentHost(
          zone(
            onOpen: () => opens++,
            onCreate: () => creates++,
            onOpenRecent: (file) => picked = file,
            files: recent,
          ),
        ),
      );
      await tester.tap(find.text('Open a PDF'));
      await tester.tap(find.text('New blank PDF'));
      await tester.tap(find.text('Ekstre.pdf'));
      expect(opens, 1);
      expect(creates, 1);
      expect(picked, recent[1]);
    });

    testWidgets('New hides without onCreate; Open hides without a label', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(zone(onOpen: () {})));
      expect(find.text('New blank PDF'), findsNothing);
      await tester.pumpWidget(
        componentHost(const SizedBox(width: 600, child: DropZone())),
      );
      expect(find.byType(Button), findsNothing);
    });

    testWidgets('word key caps take a plus', (tester) async {
      await tester.pumpWidget(
        componentHost(zone(onOpen: () {}, shortcut: const ['Ctrl', 'O'])),
      );
      expect(find.text('Ctrl+O'), findsOneWidget);
    });

    testWidgets('recent rows: 36 px, hover fill, inset focus ring, Enter', (
      tester,
    ) async {
      RecentFile? picked;
      await tester.pumpWidget(
        componentHost(
          tabHost(zone(onOpenRecent: (file) => picked = file, files: recent)),
        ),
      );
      final row = find.ancestor(
        of: find.text('Kira sözleşmesi.pdf'),
        matching: find.byType(Container),
      );
      expect(tester.getSize(row.first).height, DropZone.recentRowHeight);
      // `.fm-drop__file` has no transition: no animated container.
      expect(
        find.ancestor(
          of: find.text('Kira sözleşmesi.pdf'),
          matching: find.byType(AnimatedContainer),
        ),
        findsOneWidget, // the zone's fill only
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Kira sözleşmesi.pdf')));
      // The hover fill shows on the next frame, not over --dur-instant.
      await tester.pump();
      final hovered =
          tester.widget<Container>(row.first).decoration! as BoxDecoration;
      expect(hovered.color, light.surfaceHover);

      // Open is disabled without onOpen, so the first Tab stop is the first
      // recent file.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final ring = tester.widget<FocusRing>(
        find.ancestor(
          of: find.text('Kira sözleşmesi.pdf'),
          matching: find.byType(FocusRing),
        ),
      );
      expect(ring.visible, isTrue);
      expect(ring.style, FocusRingStyle.inset);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(picked, recent.first);
    });

    testWidgets('recent heading: label type, tertiary, tracked', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(zone(files: recent)));
      final heading = tester.widget<Text>(find.text('Recent'));
      expect(heading.style!.color, light.textTertiary);
      expect(heading.style!.fontSize, FermanTypeTokens.sizeXs);
      expect(
        heading.style!.letterSpacing,
        closeTo(FermanTypeTokens.trackingLabel * FermanTypeTokens.sizeXs, 1e-9),
      );
    });

    testWidgets('Tab reaches Open, New and each recent file', (tester) async {
      await tester.pumpWidget(
        componentHost(
          tabHost(
            zone(
              onOpen: () {},
              onCreate: () {},
              onOpenRecent: (_) {},
              files: recent,
            ),
          ),
        ),
      );
      final order = <String>[];
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final visible = tester
            .widgetList<FocusRing>(find.byType(FocusRing))
            .where((ring) => ring.visible);
        final ring = find.byWidget(visible.single);
        for (final label in [
          'Open a PDF',
          'New blank PDF',
          'Kira sözleşmesi.pdf',
          'Ekstre.pdf',
        ]) {
          if (find
              .descendant(of: ring, matching: find.text(label))
              .evaluate()
              .isNotEmpty) {
            order.add(label);
          }
        }
      }
      expect(order, [
        'Open a PDF',
        'New blank PDF',
        'Kira sözleşmesi.pdf',
        'Ekstre.pdf',
      ]);
    });

    testWidgets('disabled with a reason: buttons and rows stay focusable and '
        'show the reason; New shows without onCreate', (tester) async {
      var opens = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => zone(
              onOpen: () => opens++,
              onOpenRecent: (_) => opens++,
              disabledReason: futureVersionReason(context),
              files: recent,
            ),
          ),
        ),
      );
      final open = button(tester, 'Open a PDF');
      expect(open.disabled, isTrue);
      expect(open.disabledReason, 'Available in a future version');
      final create = button(tester, 'New blank PDF');
      expect(create.disabledReason, 'Available in a future version');
      await tester.tap(find.text('Open a PDF'), warnIfMissed: false);
      await tester.tap(find.text('Ekstre.pdf'), warnIfMissed: false);
      expect(opens, 0);
      expect(
        tester.getSemantics(find.text('Ekstre.pdf')),
        isSemantics(
          hint: 'Available in a future version',
          isEnabled: false,
          isFocusable: true,
        ),
      );
      final name = tester.widget<Text>(find.text('Ekstre.pdf'));
      expect(name.style!.color, light.textDisabled);
      handle.dispose();
    });
  });

  group('DropZone layout and semantics', () {
    testWidgets('a footnote that wraps stays centred', (tester) async {
      await tester.pumpWidget(componentHost(zone(onOpen: () {})));
      expect(
        tester.widget<Text>(find.text('Files stay on this device.')).textAlign,
        TextAlign.center,
      );
    });

    testWidgets('with no copy the tile is centred: empty blocks add no gap', (
      tester,
    ) async {
      final stateIcon = find
          .descendant(of: find.byType(DropZone), matching: find.byType(Icon))
          .first;
      for (final state in DropZoneState.values) {
        await tester.pumpWidget(
          componentHost(
            SizedBox(
              width: 600,
              child: DropZone(state: state, title: 'Drop a PDF here'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Idle shows the title, the other states have no copy at all.
        if (state == DropZoneState.idle) continue;
        expect(
          tester.getCenter(stateIcon).dy,
          tester.getCenter(body).dy,
          reason: '$state',
        );
      }
      await tester.pumpWidget(
        componentHost(const SizedBox(width: 600, child: DropZone())),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(stateIcon).dy, tester.getCenter(body).dy);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('a recent row keeps its focus when the list changes', (
      tester,
    ) async {
      const files = [
        RecentFile(name: 'A.pdf', meta: 'Now', path: '/a.pdf'),
        RecentFile(name: 'B.pdf', meta: 'Now', path: '/b.pdf'),
        RecentFile(name: 'C.pdf', meta: 'Now', path: '/c.pdf'),
      ];
      Widget list(List<RecentFile> recent) =>
          componentHost(zone(onOpenRecent: (_) {}, files: recent));
      String focusedName() {
        final focused = tester
            .widgetList<FocusRing>(find.byType(FocusRing))
            .where((ring) => ring.visible);
        return tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byWidget(focused.single),
                    matching: find.byType(Text),
                  )
                  .first,
            )
            .data!;
      }

      await tester.pumpWidget(list(files));
      // The row's own focus node, the nearest above its name.
      Focus.of(tester.element(find.text('B.pdf'))).requestFocus();
      await tester.pumpAndSettle();
      expect(focusedName(), 'B.pdf');

      await tester.pumpWidget(list(files.sublist(1)));
      await tester.pumpAndSettle();
      expect(focusedName(), 'B.pdf');
    });

    testWidgets('a region named by the title, which is a heading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(zone(onOpen: () {})));
      final region = tester.getSemantics(
        find
            .descendant(
              of: find.byType(DropZone),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(region.getSemanticsData().role, SemanticsRole.region);
      expect(region.label, 'Drop a PDF here');
      expect(
        tester.getSemantics(find.text('Drop a PDF here')),
        isSemantics(label: 'Drop a PDF here', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('right to left: the recent file icon comes first on the '
        'right', (tester) async {
      await tester.pumpWidget(
        componentHost(
          zone(onOpenRecent: (_) {}, files: recent),
          textDirection: TextDirection.rtl,
        ),
      );
      final icon = find.descendant(
        of: find.ancestor(
          of: find.text('Ekstre.pdf'),
          matching: find.byType(FermanInteractive),
        ),
        matching: find.byType(Icon),
      );
      expect(
        tester.getCenter(icon).dx,
        greaterThan(tester.getCenter(find.text('Ekstre.pdf')).dx),
      );
      expect(
        tester.getCenter(find.text('Yesterday')).dx,
        lessThan(tester.getCenter(find.text('Ekstre.pdf')).dx),
      );
    });

    testWidgets('right to left: the Open shortcut still reads ⌘O', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(zone(), textDirection: TextDirection.rtl),
      );
      final shortcut = tester.widget<Text>(find.text('⌘O'));
      expect(shortcut.textDirection, TextDirection.ltr);
      // The shortcut follows the label, so it sits on its left.
      expect(
        tester.getCenter(find.text('⌘O')).dx,
        lessThan(tester.getCenter(find.text('Open a PDF')).dx),
      );
    });

    testWidgets('RecentFile is a value', (tester) async {
      expect(
        const RecentFile(name: 'a', meta: 'b'),
        const RecentFile(name: 'a', meta: 'b'),
      );
      expect(
        const RecentFile(name: 'a', meta: 'b').hashCode,
        const RecentFile(name: 'a', meta: 'b').hashCode,
      );
      expect(
        const RecentFile(name: 'a', meta: 'b', path: '/a'),
        isNot(const RecentFile(name: 'a', meta: 'b')),
      );
    });
  });
}
