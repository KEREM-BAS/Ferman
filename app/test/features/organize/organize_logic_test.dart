import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/crop_overlay.dart';
import 'package:ferman/features/organize/crop_session.dart';
import 'package:ferman/features/organize/page_labels_dialog.dart';
import 'package:ferman/features/organize/page_position_field.dart';
import 'package:ferman/features/organize/page_range.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('page ranges', () {
    test('reads what people write, in the order written', () {
      expect(parsePageRange('1-3, 5', 9), [0, 1, 2, 4]);
      expect(parsePageRange('7–8;2', 9), [6, 7, 1]);
      expect(parsePageRange('٣', 9), [2]);
      expect(parsePageRange('1.234', 2000), [1233]);
      expect(parsePageRange('  ', 9), isEmpty);
    });

    test('refuses what the document does not have', () {
      expect(parsePageRange('10', 9), isNull);
      expect(parsePageRange('0', 9), isNull);
      expect(parsePageRange('3-1', 9), isNull);
      expect(parsePageRange('1,1', 9), isNull);
      expect(parsePageRange('abc', 9), isNull);
      expect(parsePageRange('1-999999999', 9), isNull);
    });

    test('a field shows what it reads back', () {
      final format = RegionFormat.forRegion(Region.forCode('SA'));
      final text = formatPageRange([3, 4, 5, 8], format);
      expect(parsePageRange(text, 9), [3, 4, 5, 8]);
    });
  });

  group('page labels', () {
    test('writes each style', () {
      String label(PageLabelStyle style, int first, {String prefix = ''}) =>
          pageLabelText(
            PageLabelRange(
              start: 0,
              style: style,
              first: first,
              prefix: prefix,
            ),
            0,
          );
      expect(label(PageLabelStyle.romanLower, 9), 'ix');
      expect(label(PageLabelStyle.romanUpper, 14), 'XIV');
      expect(label(PageLabelStyle.decimal, 3, prefix: 'Ek-'), 'Ek-3');
      expect(label(PageLabelStyle.lettersLower, 28), 'bb');
      expect(label(PageLabelStyle.lettersUpper, 1), 'A');
      expect(label(PageLabelStyle.none, 5, prefix: 'Ek'), 'Ek');
    });

    test('previews the first labels of each range', () {
      expect(
        pageLabelPreview(const [
          PageLabelRange(start: 0, style: PageLabelStyle.romanLower),
          PageLabelRange(start: 9),
          PageLabelRange(start: 64, prefix: 'Ek-'),
        ], 66),
        'i ii iii … ix · 1 2 3 … 55 · Ek-1 Ek-2',
      );
    });

    test('takes ranges that cover every page, once', () {
      final checked = checkPageLabels(const [
        PageLabelRow(pages: '1–9', style: PageLabelStyle.romanLower),
        PageLabelRow(pages: '10–64'),
      ], 64);
      expect(checked.problem, isNull);
      expect(checked.ranges!.map((range) => range.start), [0, 9]);
      expect(checkPageLabels(const [], 64).ranges, isEmpty);
    });

    test('says what is wrong with the others', () {
      PageLabelProblem? problem(List<String> pages) => checkPageLabels([
        for (final text in pages) PageLabelRow(pages: text),
      ], 10).problem;
      expect(problem(['x']), PageLabelProblem.invalid);
      expect(problem(['1–5', '5–10']), PageLabelProblem.overlap);
      expect(problem(['6–10', '1–5']), PageLabelProblem.uncovered);
      expect(problem(['1–3', '6–10']), PageLabelProblem.uncovered);
      expect(problem(['1–9']), PageLabelProblem.uncovered);
      expect(problem(['1–12']), PageLabelProblem.past);
    });
  });

  group('the crop', () {
    const document = OpenedDocument(
      id: 1,
      pages: [
        PageInfo(width: 100, height: 200, handle: 11),
        PageInfo(width: 50, height: 200, handle: 12),
        PageInfo(width: 100, height: 200, handle: 13),
        PageInfo(width: 100, height: 200, handle: 14),
      ],
    );

    test('a scope names its pages', () {
      const all = CropSession(document: 1, scope: CropScope.all);
      expect(all.targets(2, 4), [0, 1, 2, 3]);
      const one = CropSession(document: 1, scope: CropScope.thisPage);
      expect(one.targets(2, 4), [2]);
      const odd = CropSession(
        document: 1,
        scope: CropScope.pages,
        parity: PageParity.odd,
      );
      expect(odd.targets(0, 4), [0, 2]);
      const even = CropSession(
        document: 1,
        scope: CropScope.pages,
        range: '2-3',
        parity: PageParity.even,
      );
      expect(even.targets(0, 4), [1]);
      const bad = CropSession(document: 1, scope: CropScope.pages, range: '9');
      expect(bad.targets(0, 4), isNull);
    });

    test('margins that leave nothing of a smaller page are refused', () {
      const session = CropSession(
        document: 1,
        scope: CropScope.all,
        margins: PageMargins(left: 30, right: 30),
      );
      expect(session.tooMuch(document, [0, 2]), isNull);
      expect(session.tooMuch(document, [0, 1]), 1);
    });

    test('what was found holds per page until margins are typed', () {
      const found = CropSession(
        document: 1,
        scope: CropScope.all,
        detected: {11: PageMargins(top: 5)},
      );
      expect(found.marginsOf(11).top, 5);
      expect(found.marginsOf(12).top, 0);
      expect(found.crops, isTrue);
      final typed = found.copyWith(keepDetected: false);
      expect(typed.detected, isNull);
      expect(typed.crops, isFalse);
    });

    test('a handle stops at the page and at the side across', () {
      const page = Size(100, 200);
      final left = draggedMargins(
        const PageMargins(right: 20),
        page,
        delta: const Offset(500, 0),
        left: true,
      );
      expect(left.left, 79);
      final back = draggedMargins(
        const PageMargins(left: 10),
        page,
        delta: const Offset(-50, 0),
        left: true,
      );
      expect(back.left, 0);
      final corner = draggedMargins(
        const PageMargins(),
        page,
        delta: const Offset(-10, -30),
        right: true,
        bottom: true,
      );
      expect(corner.right, 10);
      expect(corner.bottom, 30);
      expect(corner.left, 0);
    });
  });

  test('a position names the page it follows', () {
    const document = OpenedDocument(
      id: 1,
      pages: [
        PageInfo(width: 1, height: 1, handle: 11),
        PageInfo(width: 1, height: 1, handle: 12),
      ],
    );
    expect(const PagePosition(page: 1).after(document), 12);
    expect(const PagePosition(page: 1, before: true).after(document), 11);
    expect(const PagePosition(page: 0, before: true).after(document), isNull);
  });
}
