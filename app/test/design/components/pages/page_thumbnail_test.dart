import 'package:ferman/design/components/additions/thumbnail_badges.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/pages/page_thumbnail.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;
  final cell = find.byKey(const ValueKey<String>('PageThumbnail.cell'));
  final lift = find.byKey(const ValueKey<String>('PageThumbnail.lift'));
  final pageBox = find.byKey(const ValueKey<String>('PageThumbnail.page'));
  final drop = find.byKey(const ValueKey<String>('PageThumbnail.drop'));

  BoxDecoration cellOf(WidgetTester tester, {int index = 0}) =>
      tester.widget<AnimatedContainer>(cell.at(index)).decoration!
          as BoxDecoration;

  // The value painted now, part way through a transition.
  BoxDecoration paintedCellOf(WidgetTester tester) =>
      tester
              .widget<Container>(
                find
                    .descendant(of: cell, matching: find.byType(Container))
                    .first,
              )
              .decoration!
          as BoxDecoration;

  BoxDecoration pageOf(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(pageBox).decoration! as BoxDecoration;

  Finder roundEnds() => find.descendant(
    of: drop,
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    ),
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('PageThumbnail look', () {
    testWidgets('default: 112 px page at √2, the number under it', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(PageThumbnail(page: 3, onPressed: () {})),
      );
      expect(tester.getSize(pageBox), const Size(112, 158));
      expect(cellOf(tester).color, isNull);
      final shadows = pageOf(tester).boxShadow!;
      expect(shadows.last.color, light.borderDefault);
      expect(shadows.last.spreadRadius, 1);
      final number = tester.widget<Text>(find.text('3'));
      expect(number.style!.color, light.textSecondary);
      expect(number.style!.fontFeatures, FermanTypeTokens.numericTabular);
      final gap =
          tester.getTopLeft(find.text('3')).dy -
          tester.getBottomLeft(pageBox).dy;
      expect(gap, PageThumbnail.gap);
    });

    testWidgets('a label replaces the number', (tester) async {
      await tester.pumpWidget(
        componentHost(PageThumbnail(page: 3, label: 'iii', onPressed: () {})),
      );
      expect(find.text('iii'), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('hover tints, selected fills and rings the page', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(page: 1, onPressed: () {}),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(cellOf(tester).color, light.surfaceHover);
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(page: 1, selected: true, onPressed: () {}),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(cellOf(tester).color, light.surfaceSelected);
      final ring = pageOf(tester).boxShadow!.last;
      expect(ring.color, light.accent);
      expect(ring.spreadRadius, PageThumbnail.selectedRing);
      expect(
        tester.widget<Text>(find.text('1')).style!.color,
        light.textAccent,
      );
    });

    testWidgets('keyboard focus shows the outer ring', (tester) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(page: 1, onPressed: () {}),
          forcedStates: const {WidgetState.focused},
        ),
      );
      final ring = tester.widget<FocusRing>(find.byType(FocusRing));
      expect(ring.visible, isTrue);
      expect(ring.style, FocusRingStyle.outer);
    });

    testWidgets('dragging: raised, the drag shadow, 3 % larger', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            state: PageThumbnailState.dragging,
            onPressed: () {},
          ),
        ),
      );
      expect(cellOf(tester).color, light.surfaceRaised);
      expect(
        (tester.widget<AnimatedContainer>(lift).decoration! as BoxDecoration)
            .boxShadow,
        FermanElevationTokens.light.shadowDrag,
      );
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, PageThumbnail.dragScale);
      expect(
        tester
            .renderObject<RenderBox>(cell)
            .getTransformTo(null)
            .getMaxScaleOnAxis(),
        closeTo(PageThumbnail.dragScale, 1e-9),
      );
    });

    testWidgets('state changes animate as the CSS transitions do', (
      tester,
    ) async {
      const motion = FermanMotionTokens.standard;
      await tester.pumpWidget(
        componentHost(PageThumbnail(page: 1, onPressed: () {})),
      );
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            selected: true,
            state: PageThumbnailState.dragging,
            onPressed: () {},
          ),
        ),
      );
      final fill = tester.widget<AnimatedContainer>(cell);
      expect(fill.duration, motion.durInstant);
      expect(fill.curve, motion.easeOut);
      expect(tester.widget<AnimatedContainer>(lift).duration, motion.durBase);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        motion.durBase,
      );
      expect(
        tester.widget<FocusRing>(find.byType(FocusRing)).duration,
        motion.durBase,
      );
      expect(
        tester.widget<AnimatedContainer>(pageBox).duration,
        motion.durFast,
      );
      await tester.pump(motion.durInstant ~/ 2);
      expect(paintedCellOf(tester).color, isNot(light.surfaceSelected));
      await tester.pumpAndSettle();
      expect(paintedCellOf(tester).color, light.surfaceSelected);
    });

    testWidgets('reduced motion: every change at once', (tester) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(page: 1, onPressed: () {}),
          disableAnimations: true,
        ),
      );
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(page: 1, selected: true, onPressed: () {}),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(paintedCellOf(tester).color, light.surfaceSelected);
      expect(tester.widget<AnimatedContainer>(cell).duration, Duration.zero);
    });

    testWidgets('dragging and the drop line never rebuild the cell', (
      tester,
    ) async {
      final badge = FocusNode();
      addTearDown(badge.dispose);
      Widget thumb({
        DropIndicator? dropIndicator,
        PageThumbnailState state = PageThumbnailState.idle,
      }) => componentHost(
        PageThumbnail(
          page: 1,
          dropIndicator: dropIndicator,
          state: state,
          onPressed: () {},
          badges: const ThumbnailBadges(
            badges: {ThumbnailBadge.comments},
            tooltips: {ThumbnailBadge.comments: '2 comments'},
          ),
          child: const _Probe(),
        ),
      );
      await tester.pumpWidget(thumb());
      final probe = tester.state(find.byType(_Probe));
      final badgeNode = Focus.of(
        tester.element(
          find
              .descendant(
                of: find.byKey(
                  const ValueKey<ThumbnailBadge>(ThumbnailBadge.comments),
                ),
                matching: find.byType(Container),
              )
              .first,
        ),
      )..requestFocus();
      await tester.pump();
      for (final widget in [
        thumb(dropIndicator: DropIndicator.before),
        thumb(),
        thumb(state: PageThumbnailState.dragging),
        thumb(
          state: PageThumbnailState.dragging,
          dropIndicator: DropIndicator.after,
        ),
        thumb(),
      ]) {
        await tester.pumpWidget(widget);
        await tester.pump();
        expect(tester.state(find.byType(_Probe)), same(probe));
        expect(badgeNode.hasFocus, isTrue);
      }
    });

    testWidgets('placeholder: a dashed slot, the number kept hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            state: PageThumbnailState.placeholder,
            onPressed: () {},
          ),
        ),
      );
      expect(
        find.descendant(of: pageBox, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
      expect(
        tester.renderObject(
          find.descendant(of: pageBox, matching: find.byType(CustomPaint)),
        ),
        paints..path(
          color: light.accentBorder,
          strokeWidth: PageThumbnail.placeholderOutline,
        ),
      );
      final visibility = tester.widget<Visibility>(find.byType(Visibility));
      expect(visibility.visible, isFalse);
      expect(tester.getSize(pageBox), const Size(112, 158));
    });

    testWidgets('sideways rotation re-proportions the page; a rotate glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(PageThumbnail(page: 2, rotation: 90, onPressed: () {})),
      );
      expect(tester.getSize(pageBox), const Size(114, 81));
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.rotateCw);
      await tester.pumpWidget(
        componentHost(PageThumbnail(page: 2, rotation: 180, onPressed: () {})),
      );
      expect(tester.getSize(pageBox), const Size(112, 158));
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('a rendered page replaces the lines', (tester) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            onPressed: () {},
            child: const SizedBox(key: ValueKey('render')),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('render')), findsOneWidget);
      expect(find.byType(LayoutBuilder), findsNothing);
    });

    testWidgets('badges move the placeholder lines aside', (tester) async {
      EdgeInsetsDirectional linesPadding() =>
          tester
                  .widget<Padding>(
                    find
                        .descendant(
                          of: find.byType(LayoutBuilder),
                          matching: find.byType(Padding),
                        )
                        .first,
                  )
                  .padding
              as EdgeInsetsDirectional;
      const badges = ThumbnailBadges(badges: {ThumbnailBadge.comments});
      await tester.pumpWidget(
        componentHost(PageThumbnail(page: 1, badges: badges, onPressed: () {})),
      );
      expect(
        linesPadding().end,
        closeTo(PageThumbnail.linesEndWithBadges * 112, 1e-9),
      );
      expect(
        linesPadding().start,
        closeTo(PageThumbnail.linesInset.start * 112, 1e-9),
      );
      await tester.pumpWidget(
        componentHost(PageThumbnail(page: 1, onPressed: () {})),
      );
      expect(
        linesPadding().end,
        closeTo(PageThumbnail.linesInset.end * 112, 1e-9),
      );
      // A sideways page keeps its turned lines' inset.
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            rotation: 90,
            badges: badges,
            onPressed: () {},
          ),
        ),
      );
      final width = tester.getSize(pageBox).width;
      expect(
        linesPadding().end,
        closeTo(PageThumbnail.sidewaysLinesInset.end * width, 1e-9),
      );
    });

    testWidgets('the dim filter covers the page, its badges and marker', (
      tester,
    ) async {
      const badges = ThumbnailBadges(badges: {ThumbnailBadge.comments});
      await tester.pumpWidget(
        componentHost(
          FermanThemeScope(
            pageDim: true,
            child: PageThumbnail(
              page: 1,
              badges: badges,
              marker: ThumbnailMarker.edited,
              onPressed: () {},
            ),
          ),
        ),
      );
      final filtered = find.descendant(
        of: pageBox,
        matching: find.byType(ColorFiltered),
      );
      expect(filtered, findsOneWidget);
      expect(
        find.descendant(of: filtered, matching: find.byType(ThumbnailBadges)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: filtered,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color ==
                    const FermanPageColors().editChanged,
          ),
        ),
        findsOneWidget,
      );
      // Not the number, nor the cell and its rings.
      expect(
        find.ancestor(of: find.text('1'), matching: find.byType(ColorFiltered)),
        findsNothing,
      );
      expect(
        find.ancestor(of: pageBox, matching: find.byType(ColorFiltered)),
        findsNothing,
      );
      // The placeholder slot is not a page: no filter.
      await tester.pumpWidget(
        componentHost(
          FermanThemeScope(
            pageDim: true,
            child: PageThumbnail(
              page: 1,
              state: PageThumbnailState.placeholder,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets('badges sit at the top-end corner and mirror in RTL', (
      tester,
    ) async {
      const badges = ThumbnailBadges(badges: {ThumbnailBadge.comments});
      await tester.pumpWidget(
        componentHost(PageThumbnail(page: 1, badges: badges, onPressed: () {})),
      );
      final page = tester.getRect(pageBox);
      var rect = tester.getRect(find.byType(ThumbnailBadges));
      expect(rect.right, page.right - PageThumbnail.cornerInset);
      expect(rect.top, page.top + PageThumbnail.cornerInset);
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(page: 1, badges: badges, onPressed: () {}),
          textDirection: TextDirection.rtl,
        ),
      );
      rect = tester.getRect(find.byType(ThumbnailBadges));
      expect(
        rect.left,
        tester.getRect(pageBox).left + PageThumbnail.cornerInset,
      );
    });

    testWidgets('the older marker dot', (tester) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            marker: ThumbnailMarker.comment,
            markerTooltip: 'Has comments',
            onPressed: () {},
          ),
        ),
      );
      final dot = tester.widget<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color ==
                  const FermanRamps().amber500,
        ),
      );
      expect(dot.constraints!.maxWidth, PageThumbnail.markerSize);
    });

    testWidgets('dark theme takes the dark hover tint', (tester) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(page: 1, onPressed: () {}),
          brightness: Brightness.dark,
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(cellOf(tester).color, FermanColorTokens.dark.surfaceHover);
    });

    testWidgets('dark theme: selected and dragged take the dark tokens', (
      tester,
    ) async {
      const dark = FermanColorTokens.dark;
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            selected: true,
            state: PageThumbnailState.dragging,
            onPressed: () {},
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(cellOf(tester).color, dark.surfaceSelected);
      expect(pageOf(tester).boxShadow!.last.color, dark.accent);
      expect(tester.widget<Text>(find.text('1')).style!.color, dark.textAccent);
      expect(
        (tester.widget<AnimatedContainer>(lift).decoration! as BoxDecoration)
            .boxShadow,
        FermanElevationTokens.dark.shadowDrag,
      );
    });
  });

  group('PageThumbnail drop line', () {
    testWidgets('vertical: across the page, above or below', (tester) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            dropIndicator: DropIndicator.before,
            onPressed: () {},
          ),
        ),
      );
      final cellRect = tester.getRect(cell);
      var line = tester.getRect(drop);
      expect(line.height, PageThumbnail.dropEndSize);
      expect(
        line.center.dy,
        cellRect.top - PageThumbnail.dropOffsetVertical + 1,
      );
      expect(line.left, cellRect.left + PageThumbnail.dropInset);
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            dropIndicator: DropIndicator.after,
            onPressed: () {},
          ),
        ),
      );
      line = tester.getRect(drop);
      expect(
        line.center.dy,
        tester.getRect(cell).bottom + PageThumbnail.dropOffsetVertical - 1,
      );
    });

    testWidgets('the round ends start 6 px past the line (pages.css)', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            dropIndicator: DropIndicator.before,
            onPressed: () {},
          ),
        ),
      );
      var line = tester.getRect(drop);
      var start = tester.getRect(roundEnds().first);
      var end = tester.getRect(roundEnds().last);
      expect(start.size, const Size.square(PageThumbnail.dropEndSize));
      expect(start.left, line.left - PageThumbnail.dropEndOffset);
      expect(end.right, line.right + PageThumbnail.dropEndOffset);
      // Centred across the 2 px line (`top: -4px`).
      expect(start.center.dy, line.center.dy);
      final stroke = tester.widget<DecoratedBox>(
        find.descendant(of: drop, matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (stroke.decoration as BoxDecoration).borderRadius,
        const BorderRadius.all(Radius.circular(PageThumbnail.dropRadius)),
      );
      // Right to left: the start end sits at the right.
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            dropIndicator: DropIndicator.before,
            onPressed: () {},
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      line = tester.getRect(drop);
      start = tester.getRect(roundEnds().first);
      expect(start.right, line.right + PageThumbnail.dropEndOffset);
      // Horizontal: 6 px above and below the line.
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            dropIndicator: DropIndicator.after,
            orientation: ThumbnailOrientation.horizontal,
            onPressed: () {},
          ),
        ),
      );
      line = tester.getRect(drop);
      start = tester.getRect(roundEnds().first);
      end = tester.getRect(roundEnds().last);
      expect(start.top, line.top - PageThumbnail.dropEndOffset);
      expect(end.bottom, line.bottom + PageThumbnail.dropEndOffset);
      expect(start.center.dx, line.center.dx);
    });

    testWidgets('horizontal: down the start side, mirrored in RTL', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            dropIndicator: DropIndicator.before,
            orientation: ThumbnailOrientation.horizontal,
            onPressed: () {},
          ),
        ),
      );
      var line = tester.getRect(drop);
      expect(line.width, PageThumbnail.dropEndSize);
      expect(
        line.center.dx,
        tester.getRect(cell).left - PageThumbnail.dropOffsetHorizontal + 1,
      );
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 1,
            dropIndicator: DropIndicator.before,
            orientation: ThumbnailOrientation.horizontal,
            onPressed: () {},
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      line = tester.getRect(drop);
      expect(
        line.center.dx,
        tester.getRect(cell).right + PageThumbnail.dropOffsetHorizontal - 1,
      );
    });
  });

  group('PageThumbnail keyboard and semantics', () {
    testWidgets('Enter and Space select', (tester) async {
      var presses = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(page: 1, focusNode: node, onPressed: () => presses++),
        ),
      );
      await tester.tap(find.byType(PageThumbnail));
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 3);
    });

    testWidgets('ArrowDown and ArrowUp move between thumbnails', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PageThumbnail(
                page: 1,
                width: 60,
                onPressed: () {},
                badges: const ThumbnailBadges(
                  badges: {ThumbnailBadge.comments},
                ),
              ),
              PageThumbnail(
                page: 2,
                width: 60,
                onPressed: () {},
                badges: const ThumbnailBadges(
                  badges: {ThumbnailBadge.comments},
                ),
              ),
            ],
          ),
        ),
      );
      final first = Focus.of(tester.element(cell.first));
      final second = Focus.of(tester.element(cell.last));
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(second.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(first.hasFocus, isTrue);
    });

    testWidgets('the arrows stop at the first and last thumbnail', (
      tester,
    ) async {
      final above = FocusNode();
      final below = FocusNode();
      addTearDown(above.dispose);
      addTearDown(below.dispose);
      // The app's own shortcuts: an unhandled arrow moves focus
      // directionally (DirectionalFocusIntent).
      await tester.pumpWidget(
        componentHost(
          Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Focus(
                    focusNode: above,
                    child: const SizedBox(width: 40, height: 20),
                  ),
                  PageThumbnail(page: 1, width: 60, onPressed: () {}),
                  PageThumbnail(page: 2, width: 60, onPressed: () {}),
                  Focus(
                    focusNode: below,
                    child: const SizedBox(width: 40, height: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final first = Focus.of(tester.element(cell.first));
      final last = Focus.of(tester.element(cell.last))..requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(last.hasFocus, isTrue);
      expect(below.hasFocus, isFalse);
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(first.hasFocus, isTrue);
      expect(above.hasFocus, isFalse);
    });

    testWidgets('the arrows scroll the focused thumbnail into view', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 140,
            height: 300,
            child: ListView(
              controller: controller,
              children: [
                for (var i = 1; i <= 20; i++)
                  PageThumbnail(page: i, width: 60, onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      final viewport = tester.getRect(find.byType(ListView));
      bool focusedInView() {
        final rect = FocusManager.instance.primaryFocus!.rect;
        return rect.top >= viewport.top - 0.5 &&
            rect.bottom <= viewport.bottom + 0.5;
      }

      int focusedPage() => FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<PageThumbnail>()!
          .page;

      Focus.of(tester.element(cell.first)).requestFocus();
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focusedInView(), isTrue);
      }
      expect(focusedPage(), 7);
      expect(controller.offset, greaterThan(0));
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(focusedInView(), isTrue);
      }
      expect(focusedPage(), 1);
      expect(controller.offset, 0);
    });

    testWidgets('a selectable button named "Page N" or the label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          PageThumbnail(
            page: 4,
            selected: true,
            semanticLabel: 'Page 4',
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(cell),
        isSemantics(
          label: 'Page 4',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      await tester.pumpWidget(
        componentHost(PageThumbnail(page: 4, label: 'iv', onPressed: () {})),
      );
      expect(
        tester.getSemantics(cell),
        isSemantics(label: 'iv', hasSelectedState: true, isSelected: false),
      );
      handle.dispose();
    });
  });
}

/// A stateful stand-in for a rendered page, to see whether it is rebuilt
/// from scratch.
class _Probe extends StatefulWidget {
  const new();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
