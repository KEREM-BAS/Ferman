import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/additions/thumbnail_badges.dart';
import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const ramps = FermanRamps();
  const page = FermanPageColors();

  const tooltips = {
    ThumbnailBadge.edited: 'Edited since opened',
    ThumbnailBadge.comments: '2 comments',
    ThumbnailBadge.formFields: 'Has form fields',
    ThumbnailBadge.signature: 'Has a signature',
    ThumbnailBadge.warnings: '1 warning · Madde 6 uses a font without ‘ğ’',
  };

  Finder badge(ThumbnailBadge badge) =>
      find.byKey(ValueKey<ThumbnailBadge>(badge));

  BoxDecoration chipOf(WidgetTester tester, ThumbnailBadge which) =>
      tester
              .widget<Container>(
                find
                    .descendant(
                      of: badge(which),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  FocusNode nodeOf(WidgetTester tester, ThumbnailBadge which) => Focus.of(
    tester.element(
      find.descendant(of: badge(which), matching: find.byType(Container)).first,
    ),
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('ThumbnailBadges', () {
    testWidgets('fixed order whatever the set order', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const ThumbnailBadges(
            badges: {
              ThumbnailBadge.warnings,
              ThumbnailBadge.edited,
              ThumbnailBadge.comments,
            },
            tooltips: tooltips,
          ),
        ),
      );
      final tops = [
        for (final b in [
          ThumbnailBadge.edited,
          ThumbnailBadge.comments,
          ThumbnailBadge.warnings,
        ])
          tester.getTopLeft(badge(b)).dy,
      ];
      expect(tops[0], lessThan(tops[1]));
      expect(tops[1], lessThan(tops[2]));
      expect(badge(ThumbnailBadge.signature), findsNothing);
    });

    testWidgets('edited: an 8 px accent dot with a page ring', (tester) async {
      await tester.pumpWidget(
        componentHost(const ThumbnailBadges(badges: {ThumbnailBadge.edited})),
      );
      final dot = chipOf(tester, ThumbnailBadge.edited);
      expect(dot.color, page.editChanged);
      expect(dot.shape, BoxShape.circle);
      expect(dot.boxShadow, [
        BoxShadow(color: page.pageBg, spreadRadius: ThumbnailBadges.dotRing),
      ]);
      expect(
        tester.getSize(
          find
              .descendant(
                of: badge(ThumbnailBadge.edited),
                matching: find.byType(Container),
              )
              .first,
        ),
        const Size.square(ThumbnailBadges.dotSize),
      );
    });

    testWidgets('neutral chips: 16 px white, paper ring, 10 px glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const ThumbnailBadges(
            badges: {
              ThumbnailBadge.comments,
              ThumbnailBadge.formFields,
              ThumbnailBadge.signature,
            },
          ),
        ),
      );
      for (final (which, icon) in [
        (ThumbnailBadge.comments, IconName.messageSquare),
        (ThumbnailBadge.formFields, IconName.textCursorInput),
        (ThumbnailBadge.signature, IconName.signature),
      ]) {
        final chip = chipOf(tester, which);
        expect(chip.color, ramps.paper0);
        expect(chip.boxShadow!.single.color, ramps.paper200);
        final glyph = tester.widget<Icon>(
          find.descendant(of: badge(which), matching: find.byType(Icon)),
        );
        expect(glyph.name, icon);
        expect(glyph.size, ThumbnailBadges.iconSize);
        expect(glyph.strokeWidth, ThumbnailBadges.iconStroke);
        expect(glyph.color, ramps.paper800);
      }
      expect(
        tester.getSize(
          find
              .descendant(
                of: badge(ThumbnailBadge.comments),
                matching: find.byType(Container),
              )
              .first,
        ),
        const Size.square(FermanSizeTokens.thumbBadge),
      );
    });

    testWidgets('warnings: the only amber chip; the same in dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          componentHost(
            const ThumbnailBadges(badges: {ThumbnailBadge.warnings}),
            brightness: brightness,
          ),
        );
        final chip = chipOf(tester, ThumbnailBadge.warnings);
        expect(chip.color, ramps.amber50);
        expect(chip.boxShadow!.single.color, ramps.amber200);
        expect(tester.widget<Icon>(find.byType(Icon)).color, ramps.amber700);
      }
    });

    testWidgets('each badge has its tooltip and announces it', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          const ThumbnailBadges(
            badges: {ThumbnailBadge.comments, ThumbnailBadge.warnings},
            tooltips: tooltips,
          ),
        ),
      );
      expect(
        tester.widgetList<Tooltip>(find.byType(Tooltip)).map((t) => t.message),
        ['2 comments', '1 warning · Madde 6 uses a font without ‘ğ’'],
      );
      expect(
        tester.getSemantics(
          find.descendant(
            of: badge(ThumbnailBadge.comments),
            matching: find.byType(Icon),
          ),
        ),
        isSemantics(label: '2 comments', isImage: true, isFocusable: true),
      );
      handle.dispose();
    });

    testWidgets('one Tab stop; the arrow keys move and wrap', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const ThumbnailBadges(
            badges: {
              ThumbnailBadge.edited,
              ThumbnailBadge.comments,
              ThumbnailBadge.warnings,
            },
            tooltips: tooltips,
          ),
        ),
      );
      final edited = nodeOf(tester, ThumbnailBadge.edited);
      final comments = nodeOf(tester, ThumbnailBadge.comments);
      final warnings = nodeOf(tester, ThumbnailBadge.warnings);
      expect(edited.skipTraversal, isFalse);
      expect(comments.skipTraversal, isTrue);
      edited.requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FocusRing>(
              find
                  .descendant(
                    of: badge(ThumbnailBadge.edited),
                    matching: find.byType(FocusRing),
                  )
                  .first,
            )
            .visible,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(comments.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(warnings.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(edited.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(warnings.hasFocus, isTrue);
      expect(warnings.skipTraversal, isFalse);
      expect(edited.skipTraversal, isTrue);
    });

    testWidgets('right to left: ArrowLeft moves forward', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const ThumbnailBadges(
            badges: {ThumbnailBadge.comments, ThumbnailBadge.signature},
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      final comments = nodeOf(tester, ThumbnailBadge.comments);
      final signature = nodeOf(tester, ThumbnailBadge.signature);
      comments.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(signature.hasFocus, isTrue);
    });

    testWidgets('no badges: nothing drawn', (tester) async {
      await tester.pumpWidget(componentHost(const ThumbnailBadges()));
      expect(find.byType(Icon), findsNothing);
      expect(tester.getSize(find.byType(ThumbnailBadges)), Size.zero);
    });
  });

  group('ThumbnailBadgeLegend', () {
    testWidgets('title, one row per badge in order, the footnote', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          const ThumbnailBadgeLegend(
            title: 'Page badges',
            footnote: 'Screen readers hear badges in the page name.',
            entries: {
              ThumbnailBadge.warnings: (
                name: 'Warnings',
                description: 'missing glyphs, overflow, broken links',
              ),
              ThumbnailBadge.edited: (
                name: 'Edited',
                description: 'changed since you opened it',
              ),
            },
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ThumbnailBadgeLegend)).width,
        ThumbnailBadgeLegend.width,
      );
      expect(find.text('Page badges'), findsOneWidget);
      final edited = tester.getTopLeft(
        find.textContaining('Edited', findRichText: true),
      );
      final warnings = tester.getTopLeft(
        find.textContaining('Warnings', findRichText: true),
      );
      expect(edited.dy, lessThan(warnings.dy));
      expect(
        find.text('Screen readers hear badges in the page name.'),
        findsOneWidget,
      );
      final dialog = find.bySemanticsLabel('Page badges');
      expect(
        tester.getSemantics(dialog.first).getSemanticsData().role,
        SemanticsRole.dialog,
      );
      handle.dispose();
    });
  });
}
