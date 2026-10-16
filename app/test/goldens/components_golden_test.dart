import 'package:ferman/features/gallery/gallery_catalog.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/component_golden.dart';

/// The gallery sections with no right-to-left golden. Every other section
/// has directional content (a row of icon and text, an inline start or end,
/// a directional icon; ADR 0014, G18) and gets one.
///
/// - Symmetric, the same in right to left: the focus rings, the icon-only
///   IconButton (its glyphs, rotate-cw and bold, never mirror:
///   `IconName.directional`), the round Spinner, and the Scrim with its
///   centred surface.
/// - On the page, which is never mirrored (ADR 0014; `GalleryPage` keeps
///   left to right): PageMark, TextEditBox, TextCaret, Highlight, Stamp
///   and PdfFormField.
/// - Covered elsewhere: ICON_PATHS lists all 229 glyphs, of which only the
///   eight `IconName.directional` ones mirror; the Icon section draws those
///   eight in right to left, and `icons.png` checks them too. Its right to
///   left goldens would cost 0.4 MB for nothing new.
const Set<String> noRtlGolden = {
  'FocusRing',
  'IconButton',
  'Spinner',
  'Scrim',
  'PageMark',
  'TextEditBox',
  'TextCaret',
  'Highlight',
  'Stamp',
  'PdfFormField',
  'ICON_PATHS',
};

/// Whether [entry] gets right-to-left goldens.
bool hasRtlGolden(GalleryEntry entry) => !noRtlGolden.contains(entry.name);

/// Every component of the gallery (`galleryEntries`: the component spec
/// and the focus rings), each with every variant and state its section
/// draws, in light and dark, and in Arabic, right to left, for the
/// directional ones (ROADMAP §5 step 7). Each language takes the
/// gallery's region for it (`Region.fromLocale`): the United States for
/// English, and Egypt, CLDR's likely region for Arabic, so the DatePicker's
/// week starts on Saturday; the window goldens use Saudi Arabia (G34).
///
/// Files: `component_<entry>_<light|dark>.png` and
/// `component_<entry>_<light|dark>_rtl.png`, the entry being the
/// design-system name as the spec writes it (`IconButton`, `ICON_PATHS`).
Future<void> main() async {
  await loadSystemFontStandIns();

  test('every section without a right-to-left golden is in the gallery', () {
    final names = {for (final entry in galleryEntries) entry.name};
    expect(noRtlGolden.difference(names), isEmpty);
  });

  for (final entry in galleryEntries) {
    for (final theme in [GalleryTheme.light, GalleryTheme.dark]) {
      await componentGoldenTest(
        description: '${entry.name} in ${theme.name}',
        fileName: 'component_${entry.name}_${theme.name}',
        preview: GalleryPreview(theme: theme),
        builder: entry.builder,
      );
      if (hasRtlGolden(entry)) {
        await componentGoldenTest(
          description: '${entry.name} in ${theme.name}, Arabic, right to left',
          fileName: 'component_${entry.name}_${theme.name}_rtl',
          preview: GalleryPreview(
            theme: theme,
            language: AppLanguage.arabic,
            direction: AppLanguage.arabic.textDirection,
          ),
          builder: entry.builder,
        );
      }
    }
  }
}
