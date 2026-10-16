import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/feedback/toast.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;

  final card = find
      .descendant(of: find.byType(Toast), matching: find.byType(Container))
      .first;

  BoxDecoration decoration(WidgetTester tester) =>
      tester.widget<Container>(card).decoration! as BoxDecoration;

  Icon toneIcon(WidgetTester tester) => tester
      .widgetList<Icon>(
        find.descendant(of: find.byType(Toast), matching: find.byType(Icon)),
      )
      .first;

  group('Toast', () {
    testWidgets('a 380 px raised card, popover shadow, 6 px corners', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const Toast(title: 'Saved', message: 'On this device')),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(card).width, Toast.width);
      final box = decoration(tester);
      expect(box.color, light.surfaceRaised);
      expect(box.boxShadow, FermanElevationTokens.light.shadowPopover);
      expect(
        box.borderRadius,
        const BorderRadius.all(Radius.circular(FermanRadiusTokens.radiusMd)),
      );
      // 18 px title + 2 px gap + 16 px message + 2 × 10 px padding.
      expect(tester.getSize(card).height, 18 + 2 + 16 + 20);
    });

    testWidgets('narrower when the parent is', (tester) async {
      await tester.pumpWidget(
        componentHost(const SizedBox(width: 300, child: Toast(title: 'Saved'))),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(card).width, 300);
    });

    testWidgets('tones: icon and colour', (tester) async {
      for (final (tone, icon, color) in [
        (ToastTone.neutral, IconName.info, light.iconSecondary),
        (ToastTone.success, IconName.circleCheck, light.successSolid),
        (ToastTone.warning, IconName.triangleAlert, light.warningSolid),
        (ToastTone.danger, IconName.circleAlert, light.danger),
      ]) {
        await tester.pumpWidget(
          componentHost(Toast(tone: tone, title: 'Done')),
        );
        await tester.pumpAndSettle();
        expect(toneIcon(tester).name, icon, reason: '$tone');
        expect(toneIcon(tester).color, color, reason: '$tone');
        expect(toneIcon(tester).size, Toast.iconSize);
      }
      await tester.pumpWidget(
        componentHost(const Toast(icon: IconName.wrench, title: 'Done')),
      );
      expect(toneIcon(tester).name, IconName.wrench);
    });

    testWidgets('title in body-strong, message in caption', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const Toast(title: 'Couldn’t save', message: 'The disk is full.'),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(find.text('Couldn’t save'));
      expect(title.style!.fontWeight, FermanTypeTokens.weightMedium);
      expect(title.style!.color, light.textPrimary);
      final message = tester.widget<Text>(find.text('The disk is full.'));
      expect(message.style!.fontSize, FermanTypeTokens.sizeSm);
      expect(message.style!.color, light.textSecondary);
    });

    testWidgets('one action as a small ghost button in the accent colour; '
        'Dismiss without a tooltip', (tester) async {
      var saves = 0;
      var closes = 0;
      await tester.pumpWidget(
        componentHost(
          Toast(
            tone: ToastTone.danger,
            title: 'Couldn’t save',
            action: (label: 'Save as…', onPressed: () => saves++),
            onClose: () => closes++,
            closeLabel: 'Dismiss',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = tester.widget<Button>(find.byType(Button));
      expect(action.variant, ButtonVariant.ghost);
      expect(action.size, ButtonSize.sm);
      expect(
        DefaultTextStyle.of(tester.element(find.text('Save as…'))).style.color,
        isNot(light.textAccent),
      );
      expect(
        tester.widget<Text>(find.text('Save as…')).style!.color,
        light.textAccent,
      );
      final close = tester.widget<IconButton>(find.byType(IconButton));
      expect(close.size, IconButtonSize.sm);
      expect(close.showTooltip, isFalse);
      expect(close.label, 'Dismiss');
      await tester.tap(find.text('Save as…'));
      await tester.tap(find.byType(IconButton));
      expect(saves, 1);
      expect(closes, 1);
      // The 26 px actions overhang the 10 px padding by 4 px: one title
      // line still gives 18 + 20.
      expect(tester.getSize(card).height, 18 + 20);
    });

    testWidgets('rises in over --dur-slow; at once under reduced motion', (
      tester,
    ) async {
      double opacity() => tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(Toast),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      await tester.pumpWidget(componentHost(const Toast(title: 'Saved')));
      expect(opacity(), 0);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      await tester.pumpWidget(
        componentHost(
          const Toast(key: Key('reduced'), title: 'Saved'),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(opacity(), 1);
    });

    testWidgets('right to left mirrors the row', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const Toast(title: 'تم الحفظ'),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byType(Icon)).dx,
        greaterThan(tester.getCenter(find.text('تم الحفظ')).dx),
      );
      // 12 px start padding on the right.
      expect(
        tester.getTopRight(card).dx - tester.getTopRight(find.byType(Icon)).dx,
        12,
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(const Toast(title: 'Saved'), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      expect(decoration(tester).color, FermanColorTokens.dark.surfaceRaised);
    });

    testWidgets('a polite live region labelled by its text', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(const Toast(title: 'Saved', message: 'At 14:32')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Saved')),
        isSemantics(label: 'Saved\nAt 14:32', isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
