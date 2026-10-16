import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/navigation/segmented_control.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import 'navigation_test_helpers.dart';

const List<SegmentOption<String>> _theme = [
  SegmentOption(value: 'light', label: 'Light'),
  SegmentOption(value: 'dark', label: 'Dark'),
  SegmentOption(value: 'system', label: 'System'),
];

/// A SegmentedControl that keeps its own value.
class _Host extends StatefulWidget {
  const new({
    this.options = _theme,
    this.initial = 'light',
    this.onChanged,
    this.fullWidth = false,
    this.disabled = false,
    this.disabledReason,
  });

  final List<SegmentOption<String>> options;
  final String initial;
  final ValueChanged<String>? onChanged;
  final bool fullWidth;
  final bool disabled;
  final String? disabledReason;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String _value = widget.initial;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.fullWidth ? 300 : null,
    child: SegmentedControl<String>(
      options: widget.options,
      value: _value,
      semanticLabel: 'Theme',
      fullWidth: widget.fullWidth,
      disabled: widget.disabled,
      disabledReason: widget.disabledReason,
      onChanged: (value) {
        setState(() => _value = value);
        widget.onChanged?.call(value);
      },
    ),
  );
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('SegmentedControl', () {
    testWidgets('track and segments use the navigation.css tokens', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(const _Host()));
      final theme = FermanTheme.light;
      final track =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(SegmentedControl<String>),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(track.color, theme.colors.surfaceSunken);
      expect(track.border, Border.all(color: theme.colors.borderSubtle));
      expect(track.borderRadius, BorderRadius.circular(4));
      // 20 px segments in a 26 px track (`--control-h-sm`).
      expect(tester.getSize(find.byType(SegmentedControl<String>)).height, 26);
      final segment = find.ancestor(
        of: find.text('Dark'),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(segment).height, 20);

      final checked = containerDecoration(tester, find.text('Light'));
      expect(checked.color, theme.colors.surfaceRaised);
      expect(checked.borderRadius, BorderRadius.circular(3));
      expect(checked.boxShadow, [
        BoxShadow(color: theme.colors.borderSubtle, spreadRadius: 1),
        ...theme.elevation.shadowSm,
      ]);
      expect(textColor(tester, 'Light'), theme.colors.textPrimary);
      expect(containerDecoration(tester, find.text('Dark')).color, transparent);
      expect(textColor(tester, 'Dark'), theme.colors.textSecondary);
      final style = textStyle(tester, 'Dark');
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.height, 1);
    });

    testWidgets('dark: the checked segment is soot-200 without a shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const _Host(), brightness: Brightness.dark),
      );
      final theme = FermanTheme.dark;
      final checked = containerDecoration(tester, find.text('Light'));
      expect(checked.color, theme.ramps.soot200);
      expect(checked.boxShadow, isEmpty);
    });

    testWidgets('hover tints an unchecked segment', (tester) async {
      await tester.pumpWidget(componentHost(const _Host()));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Dark')));
      await tester.pumpAndSettle();
      final theme = FermanTheme.light;
      expect(
        containerDecoration(tester, find.text('Dark')).color,
        theme.colors.surfaceHover,
      );
      expect(textColor(tester, 'Dark'), theme.colors.textPrimary);
    });

    testWidgets('a tap checks the segment', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(componentHost(_Host(onChanged: changes.add)));
      await tester.tap(find.text('System'));
      await tester.pump();
      expect(changes, ['system']);
    });

    testWidgets('icon-only segments: 14 px icon, 5 px padding, tooltip and '
        'name from title', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          const _Host(
            initial: 'width',
            options: [
              SegmentOption(
                value: 'width',
                icon: IconName.arrowLeftRight,
                tooltip: 'Fit width',
              ),
              SegmentOption(
                value: 'page',
                icon: IconName.maximize,
                tooltip: 'Fit page',
              ),
            ],
          ),
        ),
      );
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.first.size, 14);
      final padding = tester
          .widget<AnimatedContainer>(
            find
                .ancestor(
                  of: find.byType(Icon).first,
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          )
          .padding;
      expect(padding, const EdgeInsetsDirectional.symmetric(horizontal: 5));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Fit page')),
        isSemantics(
          label: 'Fit page',
          tooltip: 'Fit page',
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: false,
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(Icon).last));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Fit page'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('semantics: a radio group of radios, one checked', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(const _Host()));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Theme')),
        isSemantics(label: 'Theme', role: SemanticsRole.radioGroup),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Light')),
        isSemantics(
          label: 'Light',
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: true,
          isButton: false,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Dark')),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
      handle.dispose();
    });

    testWidgets('only the checked segment is a Tab stop; focus shows the '
        'inset ring', (tester) async {
      await tester.pumpWidget(componentHost(const _Host(initial: 'dark')));
      expect(tabStops, ['SegmentedControl 1']);
      await focusFirstTabStop(tester);
      final ring = tester.widget<FocusRing>(
        find.ancestor(of: find.text('Dark'), matching: find.byType(FocusRing)),
      );
      expect(ring.visible, isTrue);
      expect(ring.style, FocusRingStyle.inset);
    });

    testWidgets('arrow keys move and check, wrapping; right to left mirrors', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(componentHost(_Host(onChanged: changes.add)));
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changes, ['dark']);
      expect(focusLabel, 'SegmentedControl 1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changes, ['dark', 'light', 'system']);

      changes.clear();
      await tester.pumpWidget(
        componentHost(
          KeyedSubtree(
            key: const ValueKey('rtl'),
            child: _Host(onChanged: changes.add),
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changes, ['dark']);
      expect(
        tester.getCenter(find.text('Light')).dx,
        greaterThan(tester.getCenter(find.text('Dark')).dx),
      );
    });

    testWidgets('arrow keys skip plain disabled segments and stop on '
        'disabled-with-reason ones without checking them', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(
        componentHost(
          _Host(
            onChanged: changes.add,
            options: const [
              SegmentOption(value: 'a', label: 'A'),
              SegmentOption(value: 'b', label: 'B', disabled: true),
              SegmentOption(
                value: 'c',
                label: 'C',
                disabled: true,
                disabledReason: 'Not for this font',
              ),
              SegmentOption(value: 'd', label: 'D'),
            ],
            initial: 'a',
          ),
        ),
      );
      final theme = FermanTheme.light;
      expect(textColor(tester, 'B'), theme.colors.textDisabled);
      expect(textColor(tester, 'C'), theme.colors.textDisabled);
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusLabel, 'SegmentedControl 2');
      expect(changes, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changes, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changes, ['d']);
      await tester.tap(find.text('B'), warnIfMissed: false);
      expect(changes, ['d']);
    });

    testWidgets('the whole control disabled with a reason: focusable, the '
        'reason as hint, nothing checks', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = <String>[];
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => _Host(
              onChanged: changes.add,
              disabled: true,
              disabledReason: futureVersionReason(context),
            ),
          ),
        ),
      );
      final theme = FermanTheme.light;
      expect(textColor(tester, 'Dark'), theme.colors.textDisabled);
      // The checked segment keeps its shadow; the fill goes transparent.
      final checked = containerDecoration(tester, find.text('Light'));
      expect(checked.color, transparent);
      expect(checked.boxShadow, isNotEmpty);
      expect(tabStops, ['SegmentedControl 0']);
      await tester.tap(find.text('Dark'));
      expect(changes, isEmpty);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Dark')),
        isSemantics(
          hint: 'Available in a future version',
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
        ),
      );
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusLabel, 'SegmentedControl 1');
      expect(changes, isEmpty);
      handle.dispose();
    });

    testWidgets('disabled without a reason: no Tab stop', (tester) async {
      await tester.pumpWidget(componentHost(const _Host(disabled: true)));
      expect(tabStops, isEmpty);
    });

    testWidgets('full width shares the track equally', (tester) async {
      await tester.pumpWidget(componentHost(const _Host(fullWidth: true)));
      expect(tester.getSize(find.byType(SegmentedControl<String>)).width, 300);
      Size size(String label) => tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(size('Light').width, size('System').width);
      // 300 - 2 × 3 px of padding and border - 2 × 2 px gaps, in three.
      expect(size('Light').width, closeTo((300 - 6 - 4) / 3, 0.01));
    });
  });
}
