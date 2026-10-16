import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/feedback/banner.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;

  Widget wide(Widget child) => SizedBox(width: 480, child: child);

  final surface = find
      .descendant(of: find.byType(Banner), matching: find.byType(Container))
      .first;

  BoxDecoration decoration(WidgetTester tester) =>
      tester.widget<Container>(surface).decoration! as BoxDecoration;

  Icon toneIcon(WidgetTester tester) => tester
      .widgetList<Icon>(
        find.descendant(of: find.byType(Banner), matching: find.byType(Icon)),
      )
      .first;

  group('Banner', () {
    testWidgets('tones: fill, border, icon and colour', (tester) async {
      for (final (tone, background, border, icon, iconColor) in [
        (
          BannerTone.info,
          light.infoBg,
          light.infoBorder,
          IconName.info,
          light.info,
        ),
        (
          BannerTone.success,
          light.successBg,
          light.successBorder,
          IconName.circleCheck,
          light.successSolid,
        ),
        (
          BannerTone.warning,
          light.warningBg,
          light.warningBorder,
          IconName.triangleAlert,
          light.warningSolid,
        ),
        (
          BannerTone.danger,
          light.dangerBg,
          light.dangerBorder,
          IconName.circleAlert,
          light.danger,
        ),
        (
          BannerTone.neutral,
          light.surfaceSunken,
          light.borderSubtle,
          IconName.info,
          light.iconSecondary,
        ),
      ]) {
        await tester.pumpWidget(
          componentHost(wide(Banner(tone: tone, child: const Text('Note')))),
        );
        final box = decoration(tester);
        expect(box.color, background, reason: '$tone');
        expect((box.border! as Border).top.color, border, reason: '$tone');
        expect(toneIcon(tester).name, icon, reason: '$tone');
        expect(toneIcon(tester).color, iconColor, reason: '$tone');
        expect(toneIcon(tester).size, Banner.iconSize);
      }
    });

    testWidgets('box: 4 px corners, 8/10 padding, semibold title, caption '
        'message', (tester) async {
      await tester.pumpWidget(
        componentHost(
          wide(
            const Banner(
              tone: BannerTone.warning,
              title: 'Missing character',
              child: Text('The font has no ğ.'),
            ),
          ),
        ),
      );
      final box = decoration(tester);
      expect(
        box.borderRadius,
        const BorderRadius.all(Radius.circular(FermanRadiusTokens.radiusSm)),
      );
      expect(
        tester.widget<Container>(surface).padding,
        const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
      );
      final title = tester.widget<Text>(find.text('Missing character'));
      expect(title.style!.fontWeight, FermanTypeTokens.weightSemibold);
      expect(title.style!.fontSize, FermanTypeTokens.sizeSm);
      final message = DefaultTextStyle.of(
        tester.element(find.text('The font has no ğ.')),
      ).style;
      expect(message.fontSize, FermanTypeTokens.sizeSm);
      expect(message.color, light.textPrimary);
      // Title above the message, 2 px apart.
      expect(
        tester.getTopLeft(find.text('The font has no ğ.')).dy -
            tester.getBottomLeft(find.text('Missing character')).dy,
        2,
      );
      // Icon 1 px below the top of the body.
      expect(
        tester.getTopLeft(find.byType(Icon)).dy -
            tester.getTopLeft(find.text('Missing character')).dy,
        Banner.iconOffset,
      );
    });

    testWidgets('bar: bottom border only, square, title and message on one '
        'line', (tester) async {
      await tester.pumpWidget(
        componentHost(
          wide(
            const Banner(
              variant: BannerVariant.bar,
              icon: IconName.wrench,
              title: 'Ferman repaired this file.',
              child: Text('Details'),
            ),
          ),
        ),
      );
      final box = decoration(tester);
      expect(box.borderRadius, isNull);
      final border = box.border! as Border;
      expect(border.top, BorderSide.none);
      expect(border.bottom.color, light.infoBorder);
      expect(toneIcon(tester).name, IconName.wrench);
      expect(
        tester.getCenter(find.text('Details')).dy,
        tester.getCenter(find.text('Ferman repaired this file.')).dy,
      );
      expect(
        tester.widget<Container>(surface).padding,
        const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
      );
    });

    testWidgets('actions and Dismiss: the actions reach into the padding, as '
        'the negative margins do', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        componentHost(
          wide(
            Banner(
              title: 'Read only',
              onDismiss: () => dismissed++,
              dismissLabel: 'Dismiss',
            ),
          ),
        ),
      );
      final dismiss = tester.widget<IconButton>(find.byType(IconButton));
      expect(dismiss.icon, IconName.x);
      expect(dismiss.size, IconButtonSize.xs);
      expect(dismiss.label, 'Dismiss');
      expect(dismiss.showTooltip, isFalse);
      await tester.tap(find.byType(IconButton));
      expect(dismissed, 1);
      // 16 px line + 2 × 8 px padding + 2 × 1 px border; the 22 px button
      // overhangs the padding by 3 px each side.
      expect(tester.getSize(surface).height, 16 + 16 + 2);
      // The button ends 6 px (10 − 4) from the inner edge.
      expect(
        tester.getTopRight(surface).dx -
            tester.getTopRight(find.byType(IconButton)).dx,
        1 + 6,
      );
    });

    testWidgets('actions come before Dismiss', (tester) async {
      await tester.pumpWidget(
        componentHost(
          wide(
            Banner(
              variant: BannerVariant.bar,
              title: 'This page is an image.',
              actions: [
                Button(
                  size: ButtonSize.sm,
                  onPressed: () {},
                  child: const Text('Recognize text'),
                ),
              ],
              onDismiss: () {},
              dismissLabel: 'Dismiss',
            ),
          ),
        ),
      );
      expect(
        tester.getCenter(find.text('Recognize text')).dx,
        lessThan(tester.getCenter(find.byType(IconButton)).dx),
      );
    });

    testWidgets('right to left mirrors the row', (tester) async {
      await tester.pumpWidget(
        componentHost(
          wide(const Banner(title: 'ملاحظة')),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.byType(Icon)).dx,
        greaterThan(tester.getCenter(find.text('ملاحظة')).dx),
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          wide(const Banner(tone: BannerTone.danger, title: 'Failed')),
          brightness: Brightness.dark,
        ),
      );
      expect(decoration(tester).color, FermanColorTokens.dark.dangerBg);
      expect(toneIcon(tester).color, FermanColorTokens.dark.danger);
    });

    testWidgets('a polite live region labelled by its text', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          wide(const Banner(title: 'Read only', child: Text('Signed.'))),
        ),
      );
      expect(
        tester.getSemantics(find.text('Read only')),
        isSemantics(label: 'Read only\nSigned.', isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
