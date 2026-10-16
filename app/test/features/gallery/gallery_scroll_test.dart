import 'dart:math' as math;

import 'package:ferman/features/gallery/gallery_catalog.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_screen.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import 'gallery_host.dart';

/// Scrolls the gallery from top to bottom a little less than a screen at a
/// time, failing on any exception (an overflow included), and returns the
/// names of the sections that were built with their name shown.
Future<Set<String>> scrollThrough(WidgetTester tester) async {
  final seen = <String>{};
  void record() {
    for (final entry in galleryEntries) {
      final section = find.byKey(GallerySection.keyFor(entry.name));
      if (section.evaluate().isEmpty) continue;
      expect(
        find.descendant(of: section, matching: find.text(entry.name)),
        findsWidgets,
        reason: '${entry.name} shows its name',
      );
      seen.add(entry.name);
    }
  }

  final position = galleryPosition(tester);
  record();
  for (var step = 0; step < 400; step++) {
    final next = math.min(
      position.pixels + position.viewportDimension * 0.8,
      position.maxScrollExtent,
    );
    if (next <= position.pixels) break;
    position.jumpTo(next);
    await settleFrames(tester);
    expect(
      tester.takeException(),
      isNull,
      reason: 'at ${position.pixels.round()} px',
    );
    record();
  }
  return seen;
}

void main() {
  for (final size in [artboard, smallWindow]) {
    for (final (name, preview) in [
      ('left to right', const GalleryPreview()),
      (
        'right to left',
        const GalleryPreview(
          language: AppLanguage.arabic,
          direction: TextDirection.rtl,
        ),
      ),
    ]) {
      testWidgets('every section shows, with no overflow or exception, at '
          '${size.width.round()} × ${size.height.round()}, $name', (
        tester,
      ) async {
        useView(tester, size);
        await tester.pumpWidget(galleryHost(size: size, preview: preview));
        await settleFrames(tester);
        expect(tester.takeException(), isNull);
        final seen = await scrollThrough(tester);
        expect(
          [
            for (final entry in galleryEntries)
              if (!seen.contains(entry.name)) entry.name,
          ],
          isEmpty,
          reason: 'sections never shown while scrolling',
        );
      });
    }
  }
}
