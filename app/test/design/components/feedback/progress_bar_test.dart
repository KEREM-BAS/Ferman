import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/feedback/progress_bar.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;

  Widget bar(ProgressBar child) => SizedBox(width: 200, child: child);

  final fill = find.descendant(
    of: find.byType(ClipRRect),
    matching: find.byType(DecoratedBox),
  );

  final track = find
      .descendant(
        of: find.byType(ProgressBar),
        matching: find.byType(DecoratedBox),
      )
      .first;

  Color? fillColor(WidgetTester tester) =>
      (tester.widget<DecoratedBox>(fill).decoration as BoxDecoration).color;

  group('ProgressBar', () {
    testWidgets('determinate: the fill covers the value from the start', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(bar(const ProgressBar(value: 0.4))),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(fill).width, closeTo(80, 0.01));
      expect(
        tester.getTopLeft(fill).dx,
        tester.getTopLeft(find.byType(ProgressBar)).dx,
      );
      expect(fillColor(tester), light.accent);
    });

    testWidgets('track: 4 px (6 px at md), sunken, subtle inner line', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(bar(const ProgressBar(value: 0.5))),
      );
      expect(tester.getSize(track).height, ProgressBar.trackHeight);
      final decoration =
          tester.widget<DecoratedBox>(track).decoration as BoxDecoration;
      expect(decoration.color, light.surfaceSunken);
      expect((decoration.border! as Border).top.color, light.borderSubtle);
      await tester.pumpWidget(
        componentHost(
          bar(const ProgressBar(value: 0.5, size: ProgressSize.md)),
        ),
      );
      expect(tester.getSize(track).height, ProgressBar.trackHeightMd);
    });

    testWidgets('tones', (tester) async {
      for (final (tone, color) in [
        (ProgressTone.accent, light.accent),
        (ProgressTone.success, light.successSolid),
        (ProgressTone.danger, light.danger),
        (ProgressTone.paused, light.borderStrong),
      ]) {
        await tester.pumpWidget(
          componentHost(bar(ProgressBar(value: 0.5, tone: tone))),
        );
        expect(fillColor(tester), color, reason: '$tone');
      }
    });

    testWidgets('head: label and percentage, caption type', (tester) async {
      await tester.pumpWidget(
        componentHost(
          bar(
            const ProgressBar(value: 0.42, label: 'Uploading', showValue: true),
          ),
        ),
      );
      final label = tester.widget<Text>(find.text('Uploading'));
      expect(label.style!.color, light.textSecondary);
      expect(label.style!.fontSize, FermanTypeTokens.sizeSm);
      final value = tester.widget<Text>(find.text('42%'));
      expect(value.style!.color, light.textTertiary);
      expect(
        value.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      // 6 px between the head and the track.
      expect(
        tester.getTopLeft(track).dy -
            tester.getBottomLeft(find.text('Uploading')).dy,
        6,
      );
    });

    testWidgets('valueText replaces the percentage (region format)', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          bar(const ProgressBar(value: 0.4, showValue: true, valueText: '%40')),
        ),
      );
      expect(find.text('%40'), findsOneWidget);
      expect(find.text('40%'), findsNothing);
    });

    testWidgets('values outside 0 to 1 are clamped', (tester) async {
      expect(const ProgressBar(value: 1.7).percent, 100);
      expect(const ProgressBar(value: -1).percent, 0);
      expect(const ProgressBar().percent, 0);
      expect(const ProgressBar(value: 0.426).percent, 43);
    });

    testWidgets('indeterminate: a 40 % fill sweeps; no percentage', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          bar(const ProgressBar(indeterminate: true, showValue: true)),
        ),
      );
      expect(find.textContaining('%'), findsNothing);
      expect(tester.getSize(fill).width, closeTo(80, 0.01));
      final start = tester.getTopLeft(fill).dx;
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.getTopLeft(fill).dx, greaterThan(start));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('indeterminate under reduced motion: still, at the start', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          bar(const ProgressBar(indeterminate: true)),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(fill).width, closeTo(80, 0.01));
      expect(
        tester.getTopLeft(fill).dx,
        tester.getTopLeft(find.byType(ProgressBar)).dx,
      );
    });

    testWidgets('right to left fills from the right', (tester) async {
      await tester.pumpWidget(
        componentHost(
          bar(const ProgressBar(value: 0.25)),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopRight(fill).dx,
        tester.getTopRight(find.byType(ProgressBar)).dx,
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          bar(const ProgressBar(value: 0.5)),
          brightness: Brightness.dark,
        ),
      );
      expect(fillColor(tester), FermanColorTokens.dark.accent);
    });

    testWidgets('a progress bar with the percentage for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(bar(const ProgressBar(value: 0.4, label: 'Uploading'))),
      );
      var data = tester.getSemantics(track).getSemanticsData();
      expect(data.role, SemanticsRole.progressBar);
      expect(data.label, 'Uploading');
      expect(data.value, '40');
      expect(data.minValue, '0');
      expect(data.maxValue, '100');

      await tester.pumpWidget(
        componentHost(
          bar(const ProgressBar(indeterminate: true, label: 'Indexing')),
          disableAnimations: true,
        ),
      );
      data = tester.getSemantics(track).getSemanticsData();
      expect(data.role, SemanticsRole.loadingSpinner);
      expect(data.value, isEmpty);
      handle.dispose();
    });
  });
}
