import 'dart:math' as math;

import 'package:ferman/design/components/annotations/stamp.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const ramps = FermanRamps();

  BoxDecoration frame(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.descendant(
                  of: find.byType(Stamp),
                  matching: find.byType(Container),
                ),
              )
              .decoration!
          as BoxDecoration;

  testWidgets('seal is the default: seal-red border, uppercase label', (
    tester,
  ) async {
    await tester.pumpWidget(componentHost(const Stamp(label: 'Approved')));
    expect(find.text('APPROVED'), findsOneWidget);
    final border = frame(tester).border! as Border;
    expect(border.top.color, ramps.seal500);
    expect(border.top.width, Stamp.borderWidth);
    final style = tester.widget<Text>(find.text('APPROVED')).style!;
    expect(style.fontSize, 18);
    expect(style.letterSpacing, closeTo(Stamp.tracking * 18, 1e-9));
    expect(style.color, ramps.seal500);
  });

  testWidgets('tones', (tester) async {
    for (final (tone, ink) in [
      (StampTone.ink, ramps.ink600),
      (StampTone.green, ramps.green600),
      (StampTone.neutral, ramps.paper800),
    ]) {
      await tester.pumpWidget(componentHost(Stamp(label: 'Draft', tone: tone)));
      expect((frame(tester).border! as Border).top.color, ink);
    }
  });

  testWidgets('casing follows the locale: Turkish i becomes İ', (tester) async {
    await tester.pumpWidget(
      componentHost(const Stamp(label: 'imzalandı', locale: Locale('tr'))),
    );
    expect(find.text('İMZALANDI'), findsOneWidget);
    await tester.pumpWidget(
      componentHost(const Stamp(label: 'imza'), locale: const Locale('tr')),
    );
    expect(find.text('İMZA'), findsOneWidget);
    await tester.pumpWidget(componentHost(const Stamp(label: 'imza')));
    expect(find.text('IMZA'), findsOneWidget);
  });

  testWidgets('meta: 9 px, not uppercased, tabular', (tester) async {
    await tester.pumpWidget(
      componentHost(
        const Stamp(label: 'Onaylandı', meta: 'Av. Deniz Aksoy · 13.10.2026'),
      ),
    );
    final meta = tester.widget<Text>(find.text('Av. Deniz Aksoy · 13.10.2026'));
    expect(meta.style!.fontSize, Stamp.metaFontSize);
    expect(meta.style!.fontFeatures, FermanTypeTokens.numericTabular);
  });

  testWidgets('rotation and size', (tester) async {
    await tester.pumpWidget(
      componentHost(const Stamp(label: 'Paid', rotation: 5, fontSize: 24)),
    );
    final transform = tester.widget<Transform>(
      find.descendant(of: find.byType(Stamp), matching: find.byType(Transform)),
    );
    final expected = Matrix4.rotationZ(5 * math.pi / 180);
    for (var i = 0; i < 16; i++) {
      expect(
        transform.transform.storage[i],
        closeTo(expected.storage[i], 1e-9),
      );
    }
    expect(tester.widget<Text>(find.text('PAID')).style!.fontSize, 24);
  });

  testWidgets('screen readers hear an image with the label and meta', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      componentHost(const Stamp(label: 'Approved', meta: 'M. Kaya')),
    );
    expect(
      tester.getSemantics(find.text('APPROVED')),
      isSemantics(label: 'Approved, M. Kaya', isImage: true),
    );
    await tester.pumpWidget(
      componentHost(
        const Stamp(label: 'Approved', semanticLabel: 'Stamp: Approved'),
      ),
    );
    expect(
      tester.getSemantics(find.text('APPROVED')),
      isSemantics(label: 'Stamp: Approved', isImage: true),
    );
    handle.dispose();
  });

  testWidgets('document colours: the same in the dark theme', (tester) async {
    await tester.pumpWidget(
      componentHost(
        const Stamp(label: 'Approved'),
        brightness: Brightness.dark,
      ),
    );
    expect((frame(tester).border! as Border).top.color, ramps.seal500);
  });
}
