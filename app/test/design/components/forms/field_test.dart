import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;
  final dark = FermanTheme.dark.colors;

  BoxDecoration boxOf(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(find.byKey(FieldBox.boxKey)).decoration!
          as BoxDecoration;

  Color borderOf(WidgetTester tester) =>
      (boxOf(tester).border! as Border).top.color;

  List<BoxShadow> ringOf(WidgetTester tester) {
    final ring = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.byKey(FieldBox.boxKey),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return (ring.decoration! as BoxDecoration).boxShadow ?? const [];
  }

  Widget field({
    String? label = 'Label',
    String? hint,
    String? error,
    bool warning = false,
    FieldSize size = FieldSize.md,
    bool disabled = false,
    bool? focused,
    bool? hovered,
    FocusRingStyle focusRingStyle = FocusRingStyle.field,
    Widget child = const SizedBox(width: 10, height: 10),
  }) => SizedBox(
    width: 200,
    child: Field(
      label: label,
      hint: hint,
      error: error,
      warning: warning,
      size: size,
      disabled: disabled,
      focused: focused,
      hovered: hovered,
      focusRingStyle: focusRingStyle,
      child: child,
    ),
  );

  group('Field', () {
    testWidgets('sizes: 30 and 26 px boxes with 8 and 6 px padding', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(field()));
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 30);
      expect(
        tester.widget<AnimatedContainer>(find.byKey(FieldBox.boxKey)).padding,
        const EdgeInsetsDirectional.symmetric(horizontal: 8),
      );
      await tester.pumpWidget(componentHost(field(size: FieldSize.sm)));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 26);
      expect(
        tester.widget<AnimatedContainer>(find.byKey(FieldBox.boxKey)).padding,
        const EdgeInsetsDirectional.symmetric(horizontal: 6),
      );
    });

    testWidgets('label, box and message 4 px apart', (tester) async {
      await tester.pumpWidget(componentHost(field(hint: 'Hint')));
      final label = tester.getRect(find.text('Label'));
      final box = tester.getRect(find.byKey(FieldBox.boxKey));
      final hint = tester.getRect(find.text('Hint'));
      expect(box.top - label.bottom, Field.gap);
      expect(hint.top - box.bottom, Field.gap);
    });

    testWidgets('error replaces the hint', (tester) async {
      await tester.pumpWidget(componentHost(field(hint: 'Hint', error: 'Bad')));
      expect(find.text('Hint'), findsNothing);
      expect(find.text('Bad'), findsOneWidget);
      expect(borderOf(tester), light.danger);
    });

    testWidgets('warning border; error wins over warning', (tester) async {
      await tester.pumpWidget(componentHost(field(warning: true)));
      expect(borderOf(tester), light.warningSolid);
      await tester.pumpWidget(componentHost(field(warning: true, error: 'x')));
      expect(borderOf(tester), light.danger);
    });

    testWidgets('focus overrides the warning border', (tester) async {
      await tester.pumpWidget(
        componentHost(field(warning: true, focused: true)),
      );
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderFocus);
    });

    testWidgets('the outer ring style', (tester) async {
      await tester.pumpWidget(
        componentHost(
          field(focused: true, focusRingStyle: FocusRingStyle.outer),
        ),
      );
      await tester.pumpAndSettle();
      expect(ringOf(tester), FermanTheme.light.focus.focusRing);
    });

    testWidgets('hover tracked by the box, and as a parameter', (tester) async {
      await tester.pumpWidget(componentHost(field()));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(FieldBox.boxKey)));
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderStrong);
      await tester.pumpWidget(componentHost(field(hovered: false)));
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderDefault);
    });

    testWidgets('focus within the box shows the field ring', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          field(
            child: Focus(focusNode: node, child: const SizedBox(height: 4)),
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderFocus);
      expect(ringOf(tester), [
        BoxShadow(color: light.borderFocus, spreadRadius: 1),
      ]);
    });

    testWidgets('disabled: sunken and subtle; no hover', (tester) async {
      await tester.pumpWidget(componentHost(field(disabled: true)));
      expect(boxOf(tester).color, light.surfaceSunken);
      expect(borderOf(tester), light.borderSubtle);
      await tester.pumpWidget(
        componentHost(field(disabled: true, hovered: true)),
      );
      expect(borderOf(tester), light.borderSubtle);
    });

    testWidgets('texts are excluded from semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(field(hint: 'Hint')));
      expect(find.bySemanticsLabel('Label'), findsNothing);
      expect(find.bySemanticsLabel('Hint'), findsNothing);
      handle.dispose();
    });

    testWidgets('right to left: the label lines up on the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(field(), textDirection: TextDirection.rtl),
      );
      expect(
        tester.getTopRight(find.text('Label')).dx,
        tester.getTopRight(find.byKey(FieldBox.boxKey)).dx,
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(field(), brightness: Brightness.dark),
      );
      expect(boxOf(tester).color, dark.surfaceRaised);
      expect(borderOf(tester), dark.borderDefault);
    });
  });
}
