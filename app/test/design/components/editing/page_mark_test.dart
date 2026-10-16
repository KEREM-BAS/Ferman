import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/editing/page_mark.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const page = FermanPageColors();

  RenderObject markOf(WidgetTester tester) =>
      tester.renderObject(find.byType(MarkedText));

  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      componentHost(SizedBox(width: 300, child: child), brightness: brightness);

  group('PageMark kinds', () {
    testWidgets('selection is the default: the edit-selection tint', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const PageMark(child: TextSpan(text: 'kira'))),
      );
      expect(
        markOf(tester),
        paints
          ..rrect(color: page.editSelection)
          ..paragraph(),
      );
    });

    testWidgets('edited: a dotted ink underline and no fill (fix 3)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.edited,
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      expect(
        markOf(tester),
        paints
          ..paragraph()
          ..circle(color: page.editMark, radius: PageMark.editedThickness / 2),
      );
      expect(markOf(tester), isNot(paints..rrect()));
    });

    testWidgets('missing glyph: amber tint and a wavy amber underline', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.missingGlyph,
            char: 'ğ',
            child: TextSpan(text: 'ğ'),
          ),
        ),
      );
      expect(
        markOf(tester),
        paints
          ..rrect(color: page.glyphMissingBg)
          ..paragraph()
          ..path(
            color: page.glyphMissing,
            style: PaintingStyle.stroke,
            strokeWidth: PageMark.missingGlyphThickness,
          ),
      );
    });

    testWidgets('search and current search hit', (tester) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.search,
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      expect(markOf(tester), paints..rrect(color: page.searchMatch));
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.searchCurrent,
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      expect(
        markOf(tester),
        paints
          ..rrect(color: page.searchCurrent)
          ..rrect(
            color: page.searchCurrentBorder,
            style: PaintingStyle.stroke,
            strokeWidth: PageMark.ringWidth,
          )
          ..paragraph(),
      );
    });

    testWidgets('pending redaction: red stripes and a red ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.redactPending,
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      expect(
        markOf(tester),
        paints
          ..something((method, arguments) {
            if (method != #drawRRect) return false;
            return (arguments[1] as Paint).shader != null;
          })
          ..rrect(color: page.redactPending, style: PaintingStyle.stroke)
          ..paragraph(),
      );
    });

    testWidgets('applied redaction: black, the text no longer drawn', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.redactApplied,
            tooltip: 'Redacted',
            child: TextSpan(text: 'secret'),
          ),
        ),
      );
      expect(markOf(tester), paints..rrect(color: page.redactApplied));
      expect(markOf(tester), isNot(paints..paragraph()));
      expect(find.bySemanticsLabel('secret'), findsNothing);
      expect(
        tester.getSemantics(find.byType(MarkedText)),
        isSemantics(tooltip: 'Redacted'),
      );
      handle.dispose();
    });
  });

  group('PageMark layout and semantics', () {
    testWidgets('the mark is painted once per line fragment', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const SizedBox(
            width: 60,
            child: PageMark(child: TextSpan(text: 'kira bedeli her yıl artar')),
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(MarkedText));
      expect(box.size.height, greaterThan(20));
      expect(
        markOf(tester),
        paints
          ..rrect(color: page.editSelection)
          ..rrect(color: page.editSelection),
      );
    });

    testWidgets('the tooltip shows and is given to screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.edited,
            tooltip: 'Edited',
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      expect(find.byType(Tooltip), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(MarkedText)),
        isSemantics(label: 'kira', tooltip: 'Edited'),
      );
      handle.dispose();
    });

    testWidgets('page-tuned: the same colours in the dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.search,
            child: TextSpan(text: 'kira'),
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(markOf(tester), paints..rrect(color: page.searchMatch));
    });

    testWidgets('right-to-left text is marked too', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const SizedBox(
            width: 300,
            child: PageMark(child: TextSpan(text: 'عقد الإيجار')),
          ),
          locale: const Locale('ar'),
        ),
      );
      expect(markOf(tester), paints..rrect(color: page.editSelection));
    });

    testWidgets('MarkedText inherits the ambient text style', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const DefaultTextStyle(
            style: TextStyle(fontSize: 30),
            child: MarkedText(text: TextSpan(text: 'A')),
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(MarkedText));
      expect(box.size.height, 30);
    });
  });
}
