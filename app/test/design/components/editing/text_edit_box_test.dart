import 'package:ferman/design/components/editing/text_edit_box.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const page = FermanPageColors();
  const ramps = FermanRamps();

  final handles = find.byKey(const ValueKey<String>('TextEditBox.handle'));
  final meta = find.byKey(const ValueKey<String>('TextEditBox.meta'));

  RenderObject frameOf(WidgetTester tester) => tester.renderObject(
    find
        .descendant(
          of: find.byType(TextEditBox),
          matching: find.byType(CustomPaint),
        )
        .first,
  );

  Rect boxRect(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: find.byType(TextEditBox),
          matching: find.byType(CustomPaint),
        )
        .first,
  );

  FocusRingPainter ringOf(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(TextEditBox),
                  matching: find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is FocusRingPainter,
                  ),
                ),
              )
              .painter!
          as FocusRingPainter;

  Widget block({
    TextEditBoxState state = TextEditBoxState.editing,
    String? meta,
    bool metaWarning = false,
    bool? showHandles,
    double? width,
    MetaPlacement metaPlacement = MetaPlacement.above,
    bool inert = false,
    ValueChanged<TextEditBoxState>? onStateChanged,
    VoidCallback? onPressed,
    FocusNode? focusNode,
  }) => TextEditBox(
    state: state,
    meta: meta,
    metaWarning: metaWarning,
    showHandles: showHandles,
    width: width,
    metaPlacement: metaPlacement,
    inert: inert,
    onStateChanged: onStateChanged,
    onPressed: onPressed,
    focusNode: focusNode,
    semanticLabel: 'Madde 4',
    child: const Text('Kiracı, aylık kira bedeli'),
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('TextEditBox states', () {
    testWidgets('editing is the default: solid frame, tint, handles, label', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(block(meta: 'IBM Plex Serif · 10.5 pt')),
      );
      expect(
        frameOf(tester),
        paints..rect(
          color: page.editBox,
          style: PaintingStyle.stroke,
          strokeWidth: FermanBorderTokens.borderWidthStrong,
        ),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  TextEditBox.editingTint,
        ),
        findsOneWidget,
      );
      expect(handles, findsNWidgets(8));
      expect(meta, findsOneWidget);
      expect(find.text('IBM Plex Serif · 10.5 pt'), findsOneWidget);
      final label = tester.widget<Container>(meta);
      expect((label.decoration! as BoxDecoration).color, page.editBox);
      expect(tester.getSize(meta).height, FermanSizeTokens.editboxMetaH);
    });

    testWidgets('the text keeps the page ink', (tester) async {
      await tester.pumpWidget(componentHost(block()));
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('Kiracı, aylık kira bedeli')),
        ).style.color,
        ramps.paper900,
      );
    });

    testWidgets('selected: solid frame and handles, no tint', (tester) async {
      await tester.pumpWidget(
        componentHost(block(state: TextEditBoxState.selected, meta: 'Plex')),
      );
      expect(frameOf(tester), paints..rect(color: page.editBox));
      expect(handles, findsNWidgets(8));
      expect(meta, findsOneWidget);
    });

    testWidgets('idle: no frame, no handles, no label', (tester) async {
      await tester.pumpWidget(
        componentHost(block(state: TextEditBoxState.idle, meta: 'Plex')),
      );
      expect(frameOf(tester), isNot(paints..rect()));
      expect(frameOf(tester), isNot(paints..path()));
      expect(handles, findsNothing);
      expect(meta, findsNothing);
    });

    testWidgets('hover state and idle hover: the dashed frame', (tester) async {
      await tester.pumpWidget(
        componentHost(block(state: TextEditBoxState.hover)),
      );
      expect(
        frameOf(tester),
        paints..path(
          color: page.editBoxHover,
          strokeWidth: TextEditBox.hoverOutlineWidth,
        ),
      );
      await tester.pumpWidget(
        componentHost(
          block(state: TextEditBoxState.idle),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(frameOf(tester), paints..path(color: page.editBoxHover));
    });

    testWidgets('inert outside Edit mode: no hover frame', (tester) async {
      await tester.pumpWidget(
        componentHost(
          block(state: TextEditBoxState.idle, inert: true),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(frameOf(tester), isNot(paints..path()));
    });

    testWidgets('showHandles overrides the state', (tester) async {
      await tester.pumpWidget(componentHost(block(showHandles: false)));
      expect(handles, findsNothing);
      await tester.pumpWidget(
        componentHost(block(state: TextEditBoxState.idle, showHandles: true)),
      );
      expect(handles, findsNWidgets(8));
    });

    testWidgets('handles straddle the frame corners', (tester) async {
      await tester.pumpWidget(componentHost(block()));
      final box = boxRect(tester);
      final first = tester.getRect(handles.first);
      expect(first.size, const Size.square(TextEditBox.handleSize));
      expect(first.topLeft, box.topLeft - const Offset(4, 4));
    });

    testWidgets('width fixes the outer width', (tester) async {
      await tester.pumpWidget(componentHost(block(width: 240)));
      expect(boxRect(tester).width, 240);
      // The slot is the frame less the 5 px negative margins.
      expect(
        tester.getSize(find.byType(TextEditBox)).width,
        240 - 2 * TextEditBox.marginX,
      );
    });

    testWidgets('margin -4px -5px: the frame hugs the text in its slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Madde 3'),
              block(state: TextEditBoxState.selected),
              const Text('Madde 5'),
            ],
          ),
        ),
      );
      final slot = tester.getRect(find.byType(TextEditBox));
      expect(
        boxRect(tester),
        Rect.fromLTRB(
          slot.left - TextEditBox.marginX,
          slot.top - TextEditBox.marginY,
          slot.right + TextEditBox.marginX,
          slot.bottom + TextEditBox.marginY,
        ),
      );
      // The text sits 1 px up and back from where its neighbours put it.
      final text = tester.getTopLeft(find.text('Kiracı, aylık kira bedeli'));
      expect(text, slot.topLeft - const Offset(1, 1));
      expect(tester.getTopLeft(find.text('Madde 5')).dy, slot.bottom);
      // The overhang still takes the pointer.
      var presses = 0;
      await tester.pumpWidget(
        componentHost(
          block(state: TextEditBoxState.idle, onPressed: () => presses++),
        ),
      );
      final frame = boxRect(tester);
      await tester.tapAt(frame.topLeft + const Offset(1, 1));
      expect(presses, 1);
    });

    testWidgets('page-tuned: the same frame colour in the dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(block(), brightness: Brightness.dark),
      );
      expect(frameOf(tester), paints..rect(color: page.editBox));
    });

    testWidgets('handles: resize cursors, taking the pointer past the frame', (
      tester,
    ) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      // A test mouse is device 1.
      MouseCursor? cursor() =>
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);
      Future<MouseCursor?> cursorAt(Offset position) async {
        await mouse.moveTo(position);
        await tester.pump();
        return cursor();
      }

      await tester.pumpWidget(componentHost(block()));
      final frame = boxRect(tester);
      final corners = tester.getRect(handles.at(0));
      // The handle's outer corner, outside the frame.
      expect(
        await cursorAt(corners.topLeft + const Offset(1, 1)),
        SystemMouseCursors.resizeUpLeftDownRight,
      );
      expect(frame.contains(corners.topLeft + const Offset(1, 1)), isFalse);
      expect(
        await cursorAt(tester.getCenter(handles.at(1))),
        SystemMouseCursors.resizeUpDown,
      );
      expect(
        await cursorAt(tester.getCenter(handles.at(2))),
        SystemMouseCursors.resizeUpRightDownLeft,
      );
      expect(
        await cursorAt(tester.getCenter(handles.at(3))),
        SystemMouseCursors.resizeLeftRight,
      );
      // The frame itself: the text cursor.
      expect(await cursorAt(frame.center), SystemMouseCursors.text);
      // Right to left: the top-start handle is at the right.
      await tester.pumpWidget(
        componentHost(block(), textDirection: TextDirection.rtl),
      );
      final topStart = tester.getRect(handles.at(0));
      expect(topStart.right, boxRect(tester).right + TextEditBox.handleOffset);
      expect(
        await cursorAt(topStart.center),
        SystemMouseCursors.resizeUpRightDownLeft,
      );
      // Inert: the handles defer to the page.
      await tester.pumpWidget(componentHost(block(inert: true)));
      expect(
        await cursorAt(tester.getCenter(handles.at(0))),
        SystemMouseCursors.basic,
      );
    });
  });

  group('TextEditBox label', () {
    testWidgets('warning: amber with a triangle', (tester) async {
      await tester.pumpWidget(
        componentHost(block(meta: 'Plex · missing ğ', metaWarning: true)),
      );
      final label = tester.widget<Container>(meta);
      expect((label.decoration! as BoxDecoration).color, ramps.amber500);
      expect(
        find.descendant(of: meta, matching: find.byType(Icon)),
        findsOneWidget,
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).name,
        IconName.triangleAlert,
      );
    });

    testWidgets('above (default), below and in the margin', (tester) async {
      await tester.pumpWidget(componentHost(block(meta: 'Plex')));
      var box = boxRect(tester);
      var label = tester.getRect(meta);
      expect(label.bottom, box.top - TextEditBox.metaGap);
      expect(label.left, box.left - TextEditBox.metaInset);

      await tester.pumpWidget(
        componentHost(block(meta: 'Plex', metaPlacement: MetaPlacement.below)),
      );
      box = boxRect(tester);
      label = tester.getRect(meta);
      expect(label.top, box.bottom + TextEditBox.metaGap);

      await tester.pumpWidget(
        componentHost(block(meta: 'Plex', metaPlacement: MetaPlacement.margin)),
      );
      box = boxRect(tester);
      label = tester.getRect(meta);
      expect(label.right, closeTo(box.left - TextEditBox.metaMarginGap, 1e-6));
      expect(label.top, box.top - TextEditBox.metaInset);
    });

    testWidgets('right to left: the label sits at the start (right)', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(block(meta: 'Plex'), textDirection: TextDirection.rtl),
      );
      var box = boxRect(tester);
      var label = tester.getRect(meta);
      expect(label.right, box.right + TextEditBox.metaInset);
      await tester.pumpWidget(
        componentHost(
          block(meta: 'Plex', metaPlacement: MetaPlacement.margin),
          textDirection: TextDirection.rtl,
        ),
      );
      box = boxRect(tester);
      label = tester.getRect(meta);
      expect(label.left, closeTo(box.right + TextEditBox.metaMarginGap, 1e-6));
    });
  });

  group('TextEditBox keyboard and semantics', () {
    testWidgets('Enter on a selected block asks for editing', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final asked = <TextEditBoxState>[];
      await tester.pumpWidget(
        componentHost(
          block(
            state: TextEditBoxState.selected,
            focusNode: node,
            onStateChanged: asked.add,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(asked, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(asked, [TextEditBoxState.editing]);
    });

    testWidgets('Escape while editing asks for selected', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final asked = <TextEditBoxState>[];
      await tester.pumpWidget(
        componentHost(block(focusNode: node, onStateChanged: asked.add)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(asked, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(asked, [TextEditBoxState.selected]);
    });

    testWidgets('keyboard focus on an idle block: dashed frame and ring', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(block(state: TextEditBoxState.idle, focusNode: node)),
      );
      expect(ringOf(tester).progress, 0);
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(ringOf(tester).progress, 1);
      expect(frameOf(tester), paints..path(color: page.editBoxHover));
      // The selected frame doubles as focus: no ring.
      await tester.pumpWidget(
        componentHost(block(state: TextEditBoxState.selected, focusNode: node)),
      );
      expect(ringOf(tester).progress, 0);
    });

    testWidgets('the focus ring is page-tuned: white and ink in dark too', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          block(state: TextEditBoxState.idle, focusNode: node),
          brightness: Brightness.dark,
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      final ring = ringOf(tester);
      expect(ring.progress, 1);
      expect(ring.layers, [
        BoxShadow(
          color: page.editBox,
          spreadRadius: TextEditBox.focusRingSpread,
        ),
        BoxShadow(color: page.pageBg, spreadRadius: TextEditBox.focusGapSpread),
      ]);
      // Not the dark theme's `--focus-ring` (soot gap, dark-blue ring).
      expect(
        ring.layers.map((layer) => layer.color),
        isNot(contains(FermanFocusTokens.dark.focusRing.first.color)),
      );
      expect(
        frameOf(tester),
        paints
          ..drrect(color: page.editBox)
          ..drrect(color: page.pageBg),
      );
    });

    testWidgets('semantics: focusable, focused and tappable', (tester) async {
      final handle = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      var presses = 0;
      await tester.pumpWidget(
        componentHost(block(focusNode: node, onPressed: () => presses++)),
      );
      final text = find.text('Kiracı, aylık kira bedeli');
      expect(
        tester.getSemantics(text),
        isSemantics(
          isFocusable: true,
          isFocused: false,
          hasTapAction: true,
          hasFocusAction: true,
          isTextField: true,
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(text),
        isSemantics(isFocusable: true, isFocused: true, isTextField: true),
      );
      tester.semantics.tap(find.semantics.byLabel(RegExp('^Madde 4')));
      expect(presses, 1);
      // Outside Edit mode: neither focusable nor tappable.
      await tester.pumpWidget(
        componentHost(block(inert: true, onPressed: () => presses++)),
      );
      expect(
        tester.getSemantics(text),
        isSemantics(isFocusable: false, hasTapAction: false),
      );
      handle.dispose();
    });

    testWidgets('a click calls onPressed', (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        componentHost(
          block(state: TextEditBoxState.idle, onPressed: () => presses++),
        ),
      );
      await tester.tap(find.byType(TextEditBox));
      expect(presses, 1);
    });

    testWidgets('editing: a multiline text field labelled with the block', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(block()));
      expect(
        tester.getSemantics(find.text('Kiracı, aylık kira bedeli')),
        isSemantics(isTextField: true, isMultiline: true),
      );
      await tester.pumpWidget(
        componentHost(block(state: TextEditBoxState.selected)),
      );
      expect(
        tester.getSemantics(find.text('Kiracı, aylık kira bedeli')),
        isSemantics(isTextField: false),
      );
      handle.dispose();
    });
  });
}
