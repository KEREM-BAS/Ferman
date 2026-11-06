import 'package:ferman/l10n/format.dart';

/// [text] with the region's digits as ASCII and its group separators gone: a
/// field filled with [formatPageRange] reads back whatever the region writes.
String _plain(String text) => String.fromCharCodes(
  text.runes
      .map(
        (rune) => switch (rune) {
          >= 0x0660 && <= 0x0669 => rune - 0x0660 + 0x30,
          >= 0x06F0 && <= 0x06F9 => rune - 0x06F0 + 0x30,
          _ => rune,
        },
      )
      .where((rune) => !const {0x2E, 0xA0, 0x202F, 0x27, 0x66C}.contains(rune)),
);

final RegExp _span = RegExp(r'^\s*(\d{1,9})\s*(?:[-–—]\s*(\d{1,9})\s*)?$');

/// The page numbers from 1 of "4" or "4–6": first and last; null when [text]
/// is neither or runs backwards.
({int first, int last})? parsePageSpan(String text) {
  final match = _span.firstMatch(_plain(text));
  if (match == null) return null;
  final first = int.parse(match[1]!);
  final last = int.parse(match[2] ?? match[1]!);
  return first < 1 || last < first ? null : (first: first, last: last);
}

/// The page indices of "1–3, 5" as typed, in a document of [count] pages; null
/// for something else, a page it does not have or a page named twice. An empty
/// [text] names none.
List<int>? parsePageRange(String text, int count) {
  final pages = <int>{};
  if (text.trim().isEmpty) return const [];
  for (final part in text.split(RegExp('[,;،؛]'))) {
    final span = parsePageSpan(part);
    if (span == null || span.last > count) return null;
    for (var page = span.first; page <= span.last; page++) {
      if (!pages.add(page - 1)) return null;
    }
  }
  return pages.toList();
}

/// [pages], indices in document order, as a field shows them: "4–6, 9".
String formatPageRange(List<int> pages, RegionFormat format) {
  final parts = <String>[];
  for (var i = 0; i < pages.length; i++) {
    var last = i;
    while (last + 1 < pages.length && pages[last + 1] == pages[last] + 1) {
      last++;
    }
    final first = format.integer(pages[i] + 1);
    parts.add(last == i ? first : '$first–${format.integer(pages[last] + 1)}');
    i = last;
  }
  return parts.join(', ');
}
