import 'package:ferman/design/components/core/badge.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;

  final pill = find.descendant(
    of: find.byType(Badge),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container && widget.constraints?.maxHeight == Badge.height,
    ),
  );

  BoxDecoration decoration(WidgetTester tester) =>
      tester.widget<Container>(pill).decoration! as BoxDecoration;

  TextStyle labelStyle(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!;

  group('Badge', () {
    testWidgets('neutral (default): 18 px pill, sunken, label type', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(const Badge(label: '3')));
      expect(tester.getSize(pill).height, Badge.height);
      final box = decoration(tester);
      expect(box.color, light.surfaceSunken);
      expect((box.border! as Border).top.color, light.borderDefault);
      expect(
        box.borderRadius,
        const BorderRadius.all(Radius.circular(FermanRadiusTokens.radiusXs)),
      );
      final style = labelStyle(tester, '3');
      expect(style.color, light.textSecondary);
      expect(style.fontSize, FermanTypeTokens.sizeXs);
      expect(style.fontWeight, FermanTypeTokens.weightMedium);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(
        tester.widget<Container>(pill).padding,
        const EdgeInsetsDirectional.symmetric(horizontal: 6),
      );
    });

    testWidgets('tones', (tester) async {
      for (final (tone, background, border, foreground) in [
        (
          BadgeTone.accent,
          light.accentSubtle,
          light.infoBorder,
          light.textAccent,
        ),
        (
          BadgeTone.success,
          light.successBg,
          light.successBorder,
          light.success,
        ),
        (
          BadgeTone.warning,
          light.warningBg,
          light.warningBorder,
          light.warning,
        ),
        (BadgeTone.danger, light.dangerBg, light.dangerBorder, light.danger),
        (
          BadgeTone.edited,
          light.accentSubtle,
          const Color(0x00000000),
          light.textAccent,
        ),
      ]) {
        await tester.pumpWidget(
          componentHost(Badge(label: 'Edited', tone: tone)),
        );
        final box = decoration(tester);
        expect(box.color, background, reason: '$tone');
        expect((box.border! as Border).top.color, border, reason: '$tone');
        expect(labelStyle(tester, 'Edited').color, foreground, reason: '$tone');
      }
    });

    testWidgets('edited in dark uses ink 300 (fix 3), not teal', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const Badge(label: 'Edited', tone: BadgeTone.edited),
          brightness: Brightness.dark,
        ),
      );
      expect(labelStyle(tester, 'Edited').color, FermanRampTokens.ink300);
      expect(decoration(tester).color, FermanColorTokens.dark.accentSubtle);
    });

    testWidgets('dot: 6 px in the text colour, before the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const Badge(label: 'Unsaved', tone: BadgeTone.warning, dot: true),
        ),
      );
      final dot = find.descendant(
        of: find.byType(Badge),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == Badge.dotSize,
        ),
      );
      expect(tester.getSize(dot), const Size.square(Badge.dotSize));
      final dotBox = tester.widget<Container>(dot).decoration! as BoxDecoration;
      expect(dotBox.color, light.warning);
      expect(
        tester.getCenter(dot).dx,
        lessThan(tester.getCenter(find.text('Unsaved')).dx),
      );
      // 4 px gap.
      expect(
        tester.getTopLeft(find.text('Unsaved')).dx - tester.getTopRight(dot).dx,
        4,
      );
    });

    testWidgets('icon: 12 px at stroke 2', (tester) async {
      await tester.pumpWidget(
        componentHost(const Badge(label: 'Signed', icon: IconName.check)),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, Badge.iconSize);
      expect(icon.strokeWidth, Badge.iconStrokeWidth);
      expect(icon.color, light.textSecondary);
    });

    testWidgets('right to left puts the dot after the label', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const Badge(label: 'Unsaved', dot: true),
          textDirection: TextDirection.rtl,
        ),
      );
      final dot = find.descendant(
        of: find.byType(Badge),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == Badge.dotSize,
        ),
      );
      expect(
        tester.getCenter(dot).dx,
        greaterThan(tester.getCenter(find.text('Unsaved')).dx),
      );
    });

    testWidgets('one text node for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(const Badge(label: '12 edits', dot: true)),
      );
      expect(find.bySemanticsLabel('12 edits'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('12 edits')),
        isSemantics(label: '12 edits', isButton: false),
      );
      handle.dispose();
    });
  });
}
