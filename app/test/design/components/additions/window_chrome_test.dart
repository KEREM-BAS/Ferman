import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import '../navigation/navigation_test_helpers.dart';

WindowChrome _chrome(
  WindowPlatform platform, {
  bool maximized = false,
  VoidCallback? onMinimize,
  VoidCallback? onMaximize,
  VoidCallback? onClose,
  bool paintTrafficLights = false,
}) => WindowChrome(
  platform: platform,
  minimizeLabel: 'Minimize',
  maximizeLabel: 'Maximize',
  restoreLabel: 'Restore',
  closeLabel: 'Close',
  maximized: maximized,
  onMinimize: onMinimize,
  onMaximize: onMaximize,
  onClose: onClose,
  paintTrafficLights: paintTrafficLights,
);

Finder _glyph(IconName name) =>
    find.byWidgetPredicate((widget) => widget is Icon && widget.name == name);

Color? _fill(WidgetTester tester, IconName name) => tester
    .widget<ColoredBox>(
      find.ancestor(of: _glyph(name), matching: find.byType(ColoredBox)).first,
    )
    .color;

Future<void> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump();
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('WindowChrome', () {
    testWidgets('Windows: three 46 px caption buttons, 38 px tall, after a '
        '4 px gap, with the drawn glyphs', (tester) async {
      await tester.pumpWidget(
        componentHost(
          _chrome(
            WindowPlatform.win,
            onMinimize: () {},
            onMaximize: () {},
            onClose: () {},
          ),
        ),
      );
      final theme = FermanTheme.light;
      expect(
        tester.getSize(find.byType(WindowChrome)),
        const Size(4 + 3 * 46, 38),
      );
      for (final name in [IconName.minus, IconName.square, IconName.x]) {
        final box = find.ancestor(
          of: _glyph(name),
          matching: find.byType(ColoredBox),
        );
        expect(tester.getSize(box.first), const Size(46, 38));
        expect(
          tester.widget<Icon>(_glyph(name)).color,
          theme.colors.iconPrimary,
        );
      }
      expect(tester.widget<Icon>(_glyph(IconName.minus)).size, 16);
      expect(tester.widget<Icon>(_glyph(IconName.minus)).strokeWidth, 1);
      expect(tester.widget<Icon>(_glyph(IconName.square)).size, 13);
      expect(tester.widget<Icon>(_glyph(IconName.square)).strokeWidth, 1.2);
      expect(tester.widget<Icon>(_glyph(IconName.x)).strokeWidth, 1);
      expect(_fill(tester, IconName.x), transparent);
      // Minimize, maximize, close from the start.
      expect(
        tester.getCenter(_glyph(IconName.minus)).dx,
        lessThan(tester.getCenter(_glyph(IconName.x)).dx),
      );
    });

    testWidgets('hover tints a caption button', (tester) async {
      await tester.pumpWidget(
        componentHost(_chrome(WindowPlatform.win, onMinimize: () {})),
      );
      await _hover(tester, _glyph(IconName.minus));
      expect(
        _fill(tester, IconName.minus),
        FermanTheme.light.colors.surfaceHover,
      );
    });

    testWidgets('close turns #C42B1C with a white glyph on hover, in both '
        'themes', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          componentHost(
            _chrome(WindowPlatform.win, onClose: () {}),
            brightness: brightness,
            forcedStates: const {WidgetState.hovered},
          ),
        );
        expect(_fill(tester, IconName.x), const Color(0xFFC42B1C));
        expect(
          tester.widget<Icon>(_glyph(IconName.x)).color,
          WindowChrome.closeHoverGlyph,
        );
      }
    });

    testWidgets('the buttons call the window commands', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        componentHost(
          _chrome(
            WindowPlatform.win,
            onMinimize: () => calls.add('min'),
            onMaximize: () => calls.add('max'),
            onClose: () => calls.add('close'),
          ),
        ),
      );
      await tester.tap(_glyph(IconName.minus));
      await tester.tap(_glyph(IconName.square));
      await tester.tap(_glyph(IconName.x));
      expect(calls, ['min', 'max', 'close']);
    });

    testWidgets('maximized: the restore glyph and label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          _chrome(WindowPlatform.win, maximized: true, onMaximize: () {}),
        ),
      );
      expect(_glyph(IconName.square), findsNothing);
      expect(_glyph(IconName.copy), findsOneWidget);
      expect(find.bySemanticsLabel('Restore'), findsOneWidget);
      expect(find.bySemanticsLabel('Maximize'), findsNothing);
      handle.dispose();
    });

    testWidgets('the restore glyph is the copy glyph mirrored, as Windows '
        'draws it; right to left mirrors the bar and the glyph with it', (
      tester,
    ) async {
      double flipOf(IconName name) => tester
          .widget<Transform>(
            find.ancestor(of: _glyph(name), matching: find.byType(Transform)),
          )
          .transform
          .entry(0, 0);
      await tester.pumpWidget(
        componentHost(
          _chrome(WindowPlatform.win, maximized: true, onMaximize: () {}),
        ),
      );
      expect(flipOf(IconName.copy), -1);
      expect(flipOf(IconName.minus), 1);
      await tester.pumpWidget(
        componentHost(_chrome(WindowPlatform.win, onMaximize: () {})),
      );
      expect(flipOf(IconName.square), 1);
      await tester.pumpWidget(
        componentHost(
          _chrome(WindowPlatform.win, maximized: true, onMaximize: () {}),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(flipOf(IconName.copy), 1);
    });

    testWidgets('caption buttons keep the arrow cursor, enabled or not', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(_chrome(WindowPlatform.win, onMinimize: () {})),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      // A test mouse is device 1.
      MouseCursor? cursor() =>
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);
      await mouse.moveTo(tester.getCenter(_glyph(IconName.minus)));
      await tester.pump();
      expect(cursor(), SystemMouseCursors.basic);
      // Maximize has no command here, so it is disabled.
      await mouse.moveTo(tester.getCenter(_glyph(IconName.square)));
      await tester.pump();
      expect(cursor(), SystemMouseCursors.basic);
    });

    testWidgets('the maximize rectangle goes to a new receiver at once', (
      tester,
    ) async {
      final first = <Rect>[];
      final second = <Rect>[];
      Widget chrome(ValueChanged<Rect> onRect) => componentHost(
        WindowChrome(
          platform: WindowPlatform.win,
          minimizeLabel: 'Minimize',
          maximizeLabel: 'Maximize',
          restoreLabel: 'Restore',
          closeLabel: 'Close',
          onMaximize: () {},
          onMaximizeButtonRect: onRect,
        ),
      );
      await tester.pumpWidget(chrome(first.add));
      // The first reporter of the process registers the frame callback
      // during its first frame, which then runs from the next frame on.
      await tester.pumpWidget(chrome(first.add));
      expect(first, hasLength(1));
      expect(
        first.single,
        tester.getRect(
          find
              .ancestor(
                of: _glyph(IconName.square),
                matching: find.byType(ColoredBox),
              )
              .first,
        ),
      );
      // The button has not moved; the new receiver still gets it.
      await tester.pumpWidget(chrome(second.add));
      expect(first, hasLength(1));
      expect(second, [first.single]);
      // And only once while nothing moves.
      await tester.pumpWidget(chrome(second.add));
      expect(second, hasLength(1));
    });

    testWidgets('the native maximize hover shows the maximize tooltip after '
        'the delay (Windows owns that area, so Flutter sees no hover)', (
      tester,
    ) async {
      Widget chrome(Set<WidgetState> states) => componentHost(
        WindowChrome(
          platform: WindowPlatform.win,
          minimizeLabel: 'Minimize',
          maximizeLabel: 'Maximize',
          restoreLabel: 'Restore',
          closeLabel: 'Close',
          onMinimize: () {},
          onMaximize: () {},
          onClose: () {},
          maximizeButtonStates: states,
        ),
      );
      await tester.pumpWidget(chrome(const {}));
      await tester.pumpWidget(chrome(const {WidgetState.hovered}));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Maximize'), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('Maximize'), findsOneWidget);
      expect(find.text('Minimize'), findsNothing);
      await tester.pumpWidget(chrome(const {}));
      await tester.pump();
      expect(find.text('Maximize'), findsNothing);
    });

    testWidgets('the native maximize states show on the maximize button '
        'only', (tester) async {
      await tester.pumpWidget(
        componentHost(
          WindowChrome(
            platform: WindowPlatform.win,
            minimizeLabel: 'Minimize',
            maximizeLabel: 'Maximize',
            restoreLabel: 'Restore',
            closeLabel: 'Close',
            onMinimize: () {},
            onMaximize: () {},
            onClose: () {},
            maximizeButtonStates: const {WidgetState.pressed},
          ),
        ),
      );
      final theme = FermanTheme.light;
      expect(_fill(tester, IconName.square), theme.colors.surfacePressed);
      expect(_fill(tester, IconName.minus), transparent);
      expect(_fill(tester, IconName.x), transparent);
    });

    testWidgets('caption buttons are not Tab stops; screen readers get named '
        'buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          _chrome(
            WindowPlatform.win,
            onMinimize: () {},
            onMaximize: () {},
            onClose: () {},
          ),
        ),
      );
      expect(tabStops, isEmpty);
      for (final label in ['Minimize', 'Maximize', 'Close']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(
            label: label,
            tooltip: label,
            isButton: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
      }
      handle.dispose();
    });

    testWidgets('a button without its command is disabled', (tester) async {
      await tester.pumpWidget(
        componentHost(_chrome(WindowPlatform.win, onClose: () {})),
      );
      expect(
        tester.widget<Icon>(_glyph(IconName.square)).color,
        FermanTheme.light.colors.iconDisabled,
      );
    });

    testWidgets('Linux reuses the Windows layout (G15)', (tester) async {
      await tester.pumpWidget(componentHost(_chrome(WindowPlatform.linux)));
      expect(
        tester.getSize(find.byType(WindowChrome)),
        const Size(4 + 3 * 46, 38),
      );
      expect(_glyph(IconName.minus), findsOneWidget);
    });

    testWidgets('right to left: the caption buttons mirror', (tester) async {
      await tester.pumpWidget(
        componentHost(
          _chrome(WindowPlatform.win),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(_glyph(IconName.x)).dx,
        lessThan(tester.getCenter(_glyph(IconName.minus)).dx),
      );
    });

    testWidgets('macOS: an empty 78 px slot for the native lights', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(_chrome(WindowPlatform.mac)));
      expect(tester.getSize(find.byType(WindowChrome)), const Size(78, 38));
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('macOS placeholder lights: three 12 px circles 8 px apart, '
        'decorative', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          _chrome(WindowPlatform.mac, paintTrafficLights: true, onClose: () {}),
        ),
      );
      expect(tester.getSize(find.byType(WindowChrome)), const Size(78, 38));
      final lights = [
        for (final color in [
          WindowChrome.macClose,
          WindowChrome.macMinimize,
          WindowChrome.macZoom,
        ])
          find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                (widget.decoration as BoxDecoration).color == color,
          ),
      ];
      for (final light in lights) {
        expect(tester.getSize(light), const Size(12, 12));
      }
      final first = tester.getRect(lights[0]);
      final second = tester.getRect(lights[1]);
      expect(second.left - first.right, 8);
      expect(first.left - tester.getTopLeft(find.byType(WindowChrome)).dx, 14);
      expect(find.bySemanticsLabel('Close'), findsNothing);
      handle.dispose();
    });
  });
}
