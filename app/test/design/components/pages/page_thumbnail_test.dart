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
  final pageBox = find.byKey(const ValueKey<String>('PageThumbnail.page'));
  final drop = find.byKey(const ValueKey<String>('PageThumbnail.drop'));

  BoxDecoration cellOf(WidgetTester tester, {int index = 0}) =>
      tester.widget<Container>(cell.at(index)).decoration! as BoxDecoration;

  BoxDecoration pageOf(WidgetTester tester) =>
      tester.widget<Container>(pageBox).decoration! as BoxDecoration;

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
      expect(cellOf(tester).boxShadow, FermanElevationTokens.light.shadowDrag);
      final scale = tester.widget<Transform>(
        find.ancestor(of: cell, matching: find.byType(Transform)).first,
      );
      expect(scale.transform.getMaxScaleOnAxis(), PageThumbnail.dragScale);
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
