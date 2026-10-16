import 'dart:math' as math;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_catalog.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/features/gallery/gallery_screen.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import 'gallery_host.dart';

/// The list of sections, inside the preview: its context shows what the
/// preview applies.
BuildContext previewContext(WidgetTester tester) =>
    tester.element(find.byType(GalleryList));

/// The control bar, which stays in the app's own settings.
BuildContext controlsContext(WidgetTester tester) =>
    tester.element(find.byType(GalleryControls));

/// Taps the segment [label] of the control [control].
Future<void> choose(WidgetTester tester, String control, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(GalleryControls.controlKey(control)),
      matching: find.text(label),
    ),
  );
  await settleFrames(tester);
}

/// Scrolls the list until the section of [name] is built, then brings it
/// into view.
Future<void> showSection(WidgetTester tester, String name) async {
  final section = find.byKey(GallerySection.keyFor(name));
  final position = galleryPosition(tester)..jumpTo(0);
  await settleFrames(tester);
  while (section.evaluate().isEmpty &&
      position.pixels < position.maxScrollExtent) {
    position.jumpTo(
      math.min(
        position.pixels + position.viewportDimension * 0.8,
        position.maxScrollExtent,
      ),
    );
    await settleFrames(tester);
  }
  await tester.ensureVisible(section);
  await settleFrames(tester);
}

void main() {
  testWidgets('the gallery opens in the app’s settings: light, desktop, '
      'standard motion, English, left to right', (tester) async {
    useView(tester, artboard);
    await tester.pumpWidget(galleryHost());
    await settleFrames(tester);
    final context = previewContext(tester);
    final theme = FermanTheme.of(context);
    expect(theme.isDark, isFalse);
    expect(theme.pageColorFilter, isNull);
    expect(theme.density.hitMin, FermanDensityTokens.desktop.hitMin);
    expect(MediaQuery.disableAnimationsOf(context), isFalse);
    expect(Directionality.of(context), TextDirection.ltr);
    expect(Localizations.localeOf(context), const Locale('en'));
    expect(find.text(GalleryLabels.title), findsOneWidget);
    expect(find.byType(GalleryGroupHeading), findsWidgets);
  });

  testWidgets('the theme switches to dark and to dim in the preview only', (
    tester,
  ) async {
    useView(tester, artboard);
    await tester.pumpWidget(galleryHost());
    await settleFrames(tester);
    final background = FermanTheme.of(previewContext(tester))
        .colors
        .surfacePanel;

    await choose(tester, GalleryLabels.theme, 'Dark');
    var theme = FermanTheme.of(previewContext(tester));
    expect(theme.isDark, isTrue);
    expect(theme.colors.surfacePanel, isNot(background));
    expect(theme.pageColorFilter, isNull);

    await choose(tester, GalleryLabels.theme, 'Dimmed');
    theme = FermanTheme.of(previewContext(tester));
    expect(theme.isDark, isTrue);
    expect(theme.pageColorFilter, isNotNull);

    // The app around the preview keeps its light theme.
    expect(FermanTheme.of(controlsContext(tester)).isDark, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the density switches to touch and motion to reduced', (
    tester,
  ) async {
    useView(tester, artboard);
    await tester.pumpWidget(galleryHost());
    await settleFrames(tester);

    await choose(tester, GalleryLabels.density, GalleryLabels.densityTouch);
    expect(
      FermanTheme.of(previewContext(tester)).density.hitMin,
      FermanDensityTokens.touch.hitMin,
    );
    expect(
      FermanTheme.of(controlsContext(tester)).density.hitMin,
      FermanDensityTokens.desktop.hitMin,
    );

    await choose(tester, GalleryLabels.motion, GalleryLabels.motionReduced);
    final context = previewContext(tester);
    expect(MediaQuery.disableAnimationsOf(context), isTrue);
    expect(FermanTheme.of(context).motion.durBase, Duration.zero);
    expect(MediaQuery.disableAnimationsOf(controlsContext(tester)), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the direction switches to right to left, and the language '
      'brings its own direction', (tester) async {
    useView(tester, artboard);
    await tester.pumpWidget(galleryHost());
    await settleFrames(tester);

    await choose(tester, GalleryLabels.direction, GalleryLabels.directionRtl);
    expect(Directionality.of(previewContext(tester)), TextDirection.rtl);
    expect(Directionality.of(controlsContext(tester)), TextDirection.ltr);

    await choose(tester, GalleryLabels.language, 'Türkçe');
    expect(Directionality.of(previewContext(tester)), TextDirection.ltr);

    await choose(tester, GalleryLabels.language, 'العربية');
    expect(Directionality.of(previewContext(tester)), TextDirection.rtl);
    expect(Localizations.localeOf(previewContext(tester)), const Locale('ar'));

    await choose(tester, GalleryLabels.direction, GalleryLabels.directionLtr);
    expect(Directionality.of(previewContext(tester)), TextDirection.ltr);
    expect(Localizations.localeOf(previewContext(tester)), const Locale('ar'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the language switches the copy that comes from the ARB files', (
    tester,
  ) async {
    useView(tester, artboard);
    await tester.pumpWidget(galleryHost());
    await settleFrames(tester);
    await showSection(tester, 'ModeTabs');
    final en = lookupAppLocalizations(const Locale('en'));
    expect(find.text(en.shellModeView), findsWidgets);

    await choose(tester, GalleryLabels.language, 'Türkçe');
    final tr = lookupAppLocalizations(const Locale('tr'));
    expect(Localizations.localeOf(previewContext(tester)), const Locale('tr'));
    await showSection(tester, 'ModeTabs');
    expect(find.text(tr.shellModeView), findsWidgets);
    expect(find.text(en.shellModeView), findsNothing);
    // The app's own copy stays English.
    expect(
      AppLocalizations.of(controlsContext(tester)).settingsThemeDark,
      en.settingsThemeDark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the group filter shows one group', (tester) async {
    useView(tester, artboard);
    await tester.pumpWidget(galleryHost());
    await settleFrames(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(GalleryControls),
        matching: find.byType(Select<int>),
      ),
    );
    await settleFrames(tester);
    await tester.tap(find.text(GalleryGroup.navigation.id).last);
    await settleFrames(tester);

    expect(
      find.byKey(GalleryGroupHeading.keyFor(GalleryGroup.navigation)),
      findsOneWidget,
    );
    expect(
      find.byKey(GalleryGroupHeading.keyFor(GalleryGroup.core)),
      findsNothing,
    );
    expect(find.byKey(GallerySection.keyFor('ModeTabs')), findsOneWidget);
    expect(find.byKey(GallerySection.keyFor('FocusRing')), findsNothing);
    final list = tester.widget<GalleryList>(find.byType(GalleryList));
    expect(list.entries.map((entry) => entry.group).toSet(), {
      GalleryGroup.navigation,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('states are forced as the design’s state sheet forces them', (
    tester,
  ) async {
    useView(tester, artboard);
    await tester.pumpWidget(galleryHost());
    await settleFrames(tester);
    await showSection(tester, 'Button');
    final forced = tester
        .widgetList<FermanForcedStates>(
          find.descendant(
            of: find.byKey(GallerySection.keyFor('Button')),
            matching: find.byType(FermanForcedStates),
          ),
        )
        .map((widget) => widget.states)
        .toSet();
    expect(
      forced,
      containsAll([
        {WidgetState.hovered},
        {WidgetState.pressed},
        {WidgetState.focused},
      ]),
    );
  });

  testWidgets('overlays are drawn inline, never as modals', (tester) async {
    useView(tester, artboard);
    await tester.pumpWidget(galleryHost());
    await settleFrames(tester);
    await showSection(tester, 'Dialog');
    final dialogs = tester.widgetList<Dialog>(find.byType(Dialog));
    expect(dialogs, isNotEmpty);
    expect(dialogs.every((dialog) => dialog.inline), isTrue);
    await showSection(tester, 'CommandPalette');
    final palettes = tester.widgetList<CommandPalette>(
      find.byType(CommandPalette),
    );
    expect(palettes, isNotEmpty);
    expect(palettes.every((palette) => palette.inline), isTrue);
    expect(ModalScope.isOpen, isFalse);
  });
}
