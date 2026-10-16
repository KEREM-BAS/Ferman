import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/number_stepper.dart';
import 'package:ferman/design/components/forms/text_field.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;
  final dark = FermanTheme.dark.colors;

  BoxDecoration boxOf(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.byKey(FieldBox.boxKey),
    );
    return container.decoration! as BoxDecoration;
  }

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

  Color borderOf(WidgetTester tester) =>
      (boxOf(tester).border! as Border).top.color;

  Widget field({
    String? label = 'Search',
    String? hint,
    String? error,
    IconName? icon,
    String? suffix,
    FieldSize size = FieldSize.md,
    bool disabled = false,
    String? disabledReason,
    String? placeholder,
    String? semanticLabel,
    FocusNode? focusNode,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    bool obscureText = false,
  }) => SizedBox(
    width: 240,
    child: TextField(
      label: label,
      hint: hint,
      error: error,
      icon: icon,
      suffix: suffix,
      size: size,
      disabled: disabled,
      disabledReason: disabledReason,
      placeholder: placeholder,
      semanticLabel: semanticLabel,
      focusNode: focusNode,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
    ),
  );

  // A test mouse is device 1.
  MouseCursor? cursor() =>
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('TextField', () {
    testWidgets('medium: 30 px box, 1 px default border, 4 px radius, '
        'raised surface', (tester) async {
      await tester.pumpWidget(componentHost(field()));
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 30);
      final box = boxOf(tester);
      expect(box.color, light.surfaceRaised);
      expect(borderOf(tester), light.borderDefault);
      expect((box.border! as Border).top.width, 1);
      expect(box.borderRadius, const BorderRadius.all(Radius.circular(4)));
      expect(ringOf(tester), isEmpty);
    });

    testWidgets('small: 26 px box, 12 px text, 14 px icon', (tester) async {
      await tester.pumpWidget(
        componentHost(field(size: FieldSize.sm, icon: IconName.search)),
      );
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 26);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.style.fontSize, 12);
      expect(tester.getSize(find.byType(Icon)), const Size.square(14));
    });

    testWidgets('medium: 13 px text, 16 px secondary icon', (tester) async {
      await tester.pumpWidget(componentHost(field(icon: IconName.search)));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.style.fontSize, 13);
      expect(editable.style.color, light.textPrimary);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, 16);
      expect(icon.color, light.iconSecondary);
    });

    testWidgets('label in 12 px medium secondary text above the box', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(field()));
      final label = tester.widget<Text>(find.text('Search'));
      expect(label.style!.fontSize, 12);
      expect(label.style!.fontWeight, FontWeight.w500);
      expect(label.style!.color, light.textSecondary);
      expect(
        tester.getBottomLeft(find.text('Search')).dy + Field.gap,
        tester.getTopLeft(find.byKey(FieldBox.boxKey)).dy,
      );
    });

    testWidgets('hint under the box in tertiary caption text', (tester) async {
      await tester.pumpWidget(componentHost(field(hint: 'Any language')));
      final hint = tester.widget<Text>(find.text('Any language'));
      expect(hint.style!.color, light.textTertiary);
      expect(hint.style!.fontSize, 12);
    });

    testWidgets('error replaces the hint, with a danger border and glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(field(hint: 'Any language', error: 'Enter 1–48.')),
      );
      expect(find.text('Any language'), findsNothing);
      final error = tester.widget<Text>(find.text('Enter 1–48.'));
      expect(error.style!.color, light.danger);
      final glyph = tester.widget<Icon>(find.byType(Icon));
      expect(glyph.name, IconName.circleAlert);
      expect(glyph.color, light.danger);
      expect(borderOf(tester), light.danger);
    });

    testWidgets('placeholder in tertiary text while empty', (tester) async {
      await tester.pumpWidget(componentHost(field(placeholder: 'Find')));
      final placeholder = tester.widget<Text>(find.text('Find'));
      expect(placeholder.style!.color, light.textTertiary);
      await tester.enterText(find.byType(EditableText), 'x');
      await tester.pump();
      expect(find.text('Find'), findsNothing);
    });

    testWidgets('suffix after the text in tertiary caption', (tester) async {
      await tester.pumpWidget(componentHost(field(suffix: 'pt')));
      final suffix = tester.widget<Text>(find.text('pt'));
      expect(suffix.style!.color, light.textTertiary);
      expect(
        tester.getTopLeft(find.text('pt')).dx,
        greaterThan(tester.getTopRight(find.byType(EditableText)).dx),
      );
    });

    testWidgets('typing reports changes; Enter submits and keeps focus', (
      tester,
    ) async {
      final changes = <String>[];
      final submitted = <String>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          field(
            onChanged: changes.add,
            onSubmitted: submitted.add,
            focusNode: node,
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'Türkçe');
      expect(changes, ['Türkçe']);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, ['Türkçe']);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('the whole box height takes clicks: the band above the text '
        'line focuses the field, and keeps a focused one focused', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      Future<void> click(Offset at) async {
        await mouse.moveTo(at);
        await mouse.down(at);
        await mouse.up();
        await tester.pumpAndSettle();
      }

      for (final size in FieldSize.values) {
        await tester.pumpWidget(
          TapRegionSurface(
            child: componentHost(field(focusNode: node, size: size)),
          ),
        );
        node.unfocus();
        await tester.pump();
        final box = tester.getRect(find.byKey(FieldBox.boxKey));
        final text = tester.getRect(find.byType(EditableText));
        // The text line is 18 px; the band above it is still the control.
        final band = Offset(text.center.dx, box.top + 2);
        expect(band.dy, lessThan(text.top));
        await click(band);
        expect(node.hasFocus, isTrue, reason: '$size: focuses');
        expect(cursor(), SystemMouseCursors.text);
        await click(Offset(text.center.dx, box.bottom - 2));
        expect(node.hasFocus, isTrue, reason: '$size: stays focused');
      }
    });

    testWidgets('a click on the label focuses the field, and keeps a focused '
        'one focused', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        TapRegionSurface(child: componentHost(field(focusNode: node))),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      Future<void> clickLabel() async {
        final at = tester.getCenter(find.text('Search'));
        await mouse.moveTo(at);
        await mouse.down(at);
        await mouse.up();
        await tester.pumpAndSettle();
      }

      await clickLabel();
      expect(node.hasFocus, isTrue);
      // A mouse down on the label does not blur the focused field.
      await clickLabel();
      expect(node.hasFocus, isTrue);
      // A plain disabled field's label stays inert.
      final other = FocusNode();
      addTearDown(other.dispose);
      await tester.pumpWidget(
        TapRegionSurface(
          child: componentHost(field(focusNode: other, disabled: true)),
        ),
      );
      await clickLabel();
      expect(other.hasFocus, isFalse);
    });

    testWidgets('a plain disabled field shows the not-allowed cursor and '
        'takes no click', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final controller = TextEditingController(text: 'A4');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        componentHost(
          field(disabled: true, focusNode: node, controller: controller),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(EditableText)));
      await tester.pump();
      expect(cursor(), SystemMouseCursors.forbidden);
      await tester.tap(find.byType(EditableText), warnIfMissed: false);
      await tester.pump();
      expect(node.hasFocus, isFalse);
      expect(controller.text, 'A4');
      // The disabled NumberStepper shares the control.
      await tester.pumpWidget(
        componentHost(
          NumberStepper(
            value: 10,
            region: Region.unitedStates,
            onChanged: (_) {},
            disabled: true,
          ),
        ),
      );
      await mouse.moveTo(tester.getCenter(find.byType(EditableText)));
      await tester.pump();
      expect(cursor(), SystemMouseCursors.forbidden);
    });

    testWidgets('obscureText masks the text and announces it as obscured', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController(text: 'secret');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        componentHost(
          field(label: 'Password', obscureText: true, controller: controller),
        ),
      );
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.obscureText, isTrue);
      expect(editable.enableSuggestions, isFalse);
      expect(editable.autocorrect, isFalse);
      final node = tester.getSemantics(find.byType(EditableText));
      expect(
        node,
        isSemantics(label: 'Password', isTextField: true, isObscured: true),
      );
      expect(node.getSemanticsData().value, isNot('secret'));
      handle.dispose();
    });

    testWidgets('hover turns the border strong', (tester) async {
      await tester.pumpWidget(componentHost(field()));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(FieldBox.boxKey)));
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderStrong);
    });

    testWidgets('forced hover and focus', (tester) async {
      await tester.pumpWidget(
        componentHost(field(), forcedStates: {WidgetState.hovered}),
      );
      expect(borderOf(tester), light.borderStrong);
      await tester.pumpWidget(
        componentHost(field(), forcedStates: {WidgetState.focused}),
      );
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderFocus);
      expect(ringOf(tester), [
        BoxShadow(color: light.borderFocus, spreadRadius: 1),
      ]);
    });

    testWidgets('focus shows the focus border and the 1 px field ring', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(componentHost(field(focusNode: node)));
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderFocus);
      expect(ringOf(tester), [
        BoxShadow(color: light.borderFocus, spreadRadius: 1),
      ]);
    });

    testWidgets('a click focuses the field and shows the ring', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(componentHost(field(focusNode: node)));
      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(borderOf(tester), light.borderFocus);
    });

    testWidgets('focus with an error keeps the danger border and ring', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(field(error: 'Enter 1–48.', focusNode: node)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.danger);
      expect(ringOf(tester), [BoxShadow(color: light.danger, spreadRadius: 1)]);
    });

    testWidgets('disabled: sunken, subtle border, disabled text, no focus, '
        'no input', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final controller = TextEditingController(text: 'A4');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        componentHost(
          field(disabled: true, focusNode: node, controller: controller),
        ),
      );
      final box = boxOf(tester);
      expect(box.color, light.surfaceSunken);
      expect(borderOf(tester), light.borderSubtle);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.style.color, light.textDisabled);
      expect(editable.readOnly, isTrue);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(FieldBox.boxKey)));
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderSubtle);
    });

    testWidgets('disabled with a reason: focusable, read only, reason as '
        'tooltip and hint', (tester) async {
      final handle = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          field(
            disabled: true,
            disabledReason: 'Available in a future version',
            focusNode: node,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(borderOf(tester), light.borderFocus);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.readOnly, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Search',
          hint: 'Available in a future version',
          isTextField: true,
          isReadOnly: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('semantics: a text field named by the label, with the error '
        'or hint as hint and the text as value', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController(text: 'Deutsch');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        componentHost(field(hint: 'Any language', controller: controller)),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Search',
          hint: 'Any language',
          value: 'Deutsch',
          isTextField: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      await tester.pumpWidget(
        componentHost(field(error: 'No match', controller: controller)),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(label: 'Search', hint: 'No match', isTextField: true),
      );
      expect(
        tester
            .getSemantics(find.byType(EditableText))
            .getSemanticsData()
            .validationResult,
        SemanticsValidationResult.invalid,
      );
      handle.dispose();
    });

    testWidgets('semantics: semanticLabel names a field without a label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(field(label: null, semanticLabel: 'Search recent files')),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(label: 'Search recent files', isTextField: true),
      );
      expect(find.text('Search recent files'), findsNothing);
      handle.dispose();
    });

    testWidgets('right to left: the icon leads on the right, the suffix '
        'trails on the left', (tester) async {
      await tester.pumpWidget(
        componentHost(
          field(icon: IconName.search, suffix: 'pt'),
          textDirection: TextDirection.rtl,
        ),
      );
      final box = tester.getRect(find.byKey(FieldBox.boxKey));
      expect(tester.getRect(find.byType(Icon)).right, box.right - 1 - 8);
      expect(tester.getRect(find.text('pt')).left, lessThan(box.center.dx));
      expect(
        tester.getTopRight(find.text('Search')).dx,
        moreOrLessEquals(box.right),
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(field(), brightness: Brightness.dark),
      );
      expect(boxOf(tester).color, dark.surfaceRaised);
      expect(borderOf(tester), dark.borderDefault);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.style.color, dark.textPrimary);
    });

    testWidgets('debugFillProperties lists the props', (tester) async {
      final builder = DiagnosticPropertiesBuilder();
      const TextField(label: 'Zoom', suffix: '%').debugFillProperties(builder);
      final names = builder.properties.map((p) => p.name);
      expect(names, containsAll(['label', 'suffix', 'size', 'disabled']));
    });
  });
}
