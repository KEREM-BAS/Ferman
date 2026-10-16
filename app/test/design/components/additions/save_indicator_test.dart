import 'package:ferman/design/components/additions/save_indicator.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import '../navigation/navigation_test_helpers.dart';

void main() {
  group('SaveIndicator', () {
    testWidgets('unsaved: an amber dot and primary text in the caption '
        'style with tabular figures', (tester) async {
      await tester.pumpWidget(
        componentHost(const SaveIndicator(label: 'Unsaved changes')),
      );
      final theme = FermanTheme.light;
      final dot = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration).color ==
                theme.colors.warningSolid,
      );
      expect(tester.getSize(dot), const Size(7, 7));
      expect(textColor(tester, 'Unsaved changes'), theme.colors.textPrimary);
      final style = textStyle(tester, 'Unsaved changes');
      expect(style.fontSize, 12);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(
        tester.getRect(find.text('Unsaved changes')).left -
            tester.getRect(dot).right,
        6,
      );
    });

    testWidgets('saved: a 12 px hard-drive at a 2 px stroke, secondary text', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          SaveIndicator(
            state: SaveState.saved,
            savedAt: DateTime(2026, 10, 15, 14, 32),
            label: 'Saved on this device · 14:32',
          ),
        ),
      );
      final theme = FermanTheme.light;
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.name, IconName.hardDrive);
      expect(icon.size, 12);
      expect(icon.strokeWidth, 2);
      expect(icon.color, theme.colors.textSecondary);
      expect(
        textColor(tester, 'Saved on this device · 14:32'),
        theme.colors.textSecondary,
      );
    });

    testWidgets('saved: the time of savedAt in the region format, in the '
        'localized text, shown and announced', (tester) async {
      final handle = tester.ensureSemantics();
      String saved(String time) => 'Saved on this device · $time';
      final at = DateTime(2026, 10, 15, 14, 32);
      await tester.pumpWidget(
        componentHost(
          SaveIndicator(
            state: SaveState.saved,
            savedAt: at,
            region: Region.turkiye,
            savedLabel: saved,
            label: 'Saved on this device',
          ),
        ),
      );
      expect(find.text('Saved on this device · 14:32'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(SaveIndicator)),
        isSemantics(label: 'Saved on this device · 14:32', isLiveRegion: true),
      );
      await tester.pumpWidget(
        componentHost(
          SaveIndicator(
            state: SaveState.saved,
            savedAt: at,
            region: Region.unitedStates,
            savedLabel: saved,
            label: 'Saved on this device',
          ),
        ),
      );
      expect(find.text('Saved on this device · 2:32\u202FPM'), findsOneWidget);
      // Without a region the caller's text stands.
      await tester.pumpWidget(
        componentHost(
          SaveIndicator(
            state: SaveState.saved,
            savedAt: at,
            savedLabel: saved,
            label: 'Saved on this device · 14:32',
          ),
        ),
      );
      expect(find.text('Saved on this device · 14:32'), findsOneWidget);
      // Other states always show the label.
      await tester.pumpWidget(
        componentHost(
          SaveIndicator(
            savedAt: at,
            region: Region.turkiye,
            savedLabel: saved,
            label: 'Unsaved changes',
          ),
        ),
      );
      expect(find.text('Unsaved changes'), findsOneWidget);
      handle.dispose();
    });

    testWidgets("saving: the design's 12 px Spinner, decorative", (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          const SaveIndicator(state: SaveState.saving, label: 'Saving…'),
        ),
      );
      final spinner = tester.widget<Spinner>(find.byType(Spinner));
      expect(spinner.size, 12);
      expect(spinner.semanticLabel, isNull);
      expect(find.byType(Icon), findsNothing);
      expect(
        tester.getRect(find.text('Saving…')).left -
            tester.getRect(find.byType(Spinner)).right,
        6,
      );
      expect(
        tester.getSemantics(find.byType(SaveIndicator)),
        isSemantics(label: 'Saving…', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('error: circle-alert in the danger colour, light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          componentHost(
            const SaveIndicator(state: SaveState.error, label: 'Couldn’t save'),
            brightness: brightness,
          ),
        );
        final theme = FermanTheme.forBrightness(brightness);
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.name, IconName.circleAlert);
        expect(icon.color, theme.colors.danger);
        expect(textColor(tester, 'Couldn’t save'), theme.colors.danger);
      }
    });

    testWidgets('read-only: a lock', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const SaveIndicator(state: SaveState.readOnly, label: 'Read-only'),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.lock);
    });

    testWidgets('right to left: the mark comes first from the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const SaveIndicator(state: SaveState.readOnly, label: 'للقراءة فقط'),
          locale: const Locale('ar'),
        ),
      );
      expect(
        tester.getCenter(find.byType(Icon)).dx,
        greaterThan(tester.getCenter(find.text('للقراءة فقط')).dx),
      );
    });

    testWidgets('semantics: a polite live region labelled with the state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(const SaveIndicator(label: 'Unsaved changes')),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Unsaved changes')),
        isSemantics(label: 'Unsaved changes', isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
