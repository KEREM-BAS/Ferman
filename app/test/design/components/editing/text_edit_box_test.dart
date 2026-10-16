import 'package:ferman/design/components/editing/text_edit_box.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
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
    });

    testWidgets('page-tuned: the same frame colour in the dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(block(), brightness: Brightness.dark),
      );
      expect(frameOf(tester), paints..rect(color: page.editBox));
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
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isFalse);
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isTrue);
      expect(frameOf(tester), paints..path(color: page.editBoxHover));
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
