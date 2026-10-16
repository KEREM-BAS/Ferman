import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/platform_window.dart';
import 'package:ferman/app/window_frame.dart';
import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/component_host.dart';
import '../helpers/fake_desktop_window.dart';

void main() {
  // `--win-caption-w`.
  const captionWidth = 46.0;
  // `--titlebar-h` (38) less its 1 px bottom line.
  const barContentHeight = 37.0;
  const light = FermanColorTokens.light;

  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.win));
  tearDown(() => window.dispose());

  Widget bar({
    Locale locale = const Locale('en'),
    Widget? content,
    bool show = true,
  }) => componentHost(
    SizedBox(
      width: 800,
      height: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (show)
            TitleBar(
              window: window,
              platform: window.platform!,
              content: content,
            ),
          const Expanded(child: SizedBox()),
        ],
      ),
    ),
    locale: locale,
  );

  Finder caption(String label) => find.byWidgetPredicate(
    (widget) => widget is FermanInteractive && widget.semanticLabel == label,
  );

  Color captionBackground(WidgetTester tester, int index) => tester
      .widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(WindowChrome),
          matching: find.byType(ColoredBox),
        ),
      )
      .elementAt(index)
      .color;

  group('TitleBar', () {
    testWidgets('is 38 px on the sunken surface with a subtle line below', (
      tester,
    ) async {
      await tester.pumpWidget(bar());
      expect(
        tester.getRect(find.byType(TitleBar)),
        const Rect.fromLTWH(0, 0, 800, 38),
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(TitleBar),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, light.surfaceSunken);
      final border = decoration.border! as Border;
      expect(border.bottom.color, light.borderSubtle);
      expect(border.bottom.width, 1);
    });

    group('macOS', () {
      setUp(() => window = FakeDesktopWindow(WindowPlatform.mac));

      testWidgets('keeps the traffic-light slot at the start and places the '
          'native lights in it', (tester) async {
        await tester.pumpWidget(bar());
        final slot = tester.getRect(find.byType(WindowChrome));
        expect(slot.left, 0);
        expect(slot.width, 78);
        expect(caption('Minimize'), findsNothing);
        final layout = window.trafficLightLayouts.single;
        expect(layout.titleBarHeight, barContentHeight);
        expect(layout.leading, 14);
        expect(layout.diameter, 12);
        expect(layout.spacing, 8);
        expect(layout.rightToLeft, isFalse);

        // A rebuild with the same layout sends nothing new.
        await tester.pumpWidget(bar(content: const SizedBox()));
        expect(window.trafficLightLayouts, hasLength(1));
      });

      testWidgets('puts the lights at the right edge in right to left', (
        tester,
      ) async {
        await tester.pumpWidget(bar(locale: const Locale('ar')));
        expect(tester.getRect(find.byType(WindowChrome)).right, 800);
        expect(window.trafficLightLayouts.single.rightToLeft, isTrue);

        await tester.pumpWidget(bar());
        expect(window.trafficLightLayouts, hasLength(2));
        expect(window.trafficLightLayouts.last.rightToLeft, isFalse);
      });

      testWidgets('drops the slot in full screen, where the system owns the '
          'lights', (tester) async {
        await tester.pumpWidget(bar());
        window.stateNotifier.value = const DesktopWindowState(fullScreen: true);
        await tester.pump();
        expect(find.byType(WindowChrome), findsNothing);
      });

      testWidgets('reports no maximize button', (tester) async {
        await tester.pumpWidget(bar());
        await tester.pump();
        expect(window.maximizeButtonRects, isEmpty);
      });
    });

    group('Windows', () {
      testWidgets('draws the caption buttons at the end and runs the window '
          'commands', (tester) async {
        await tester.pumpWidget(bar());
        expect(window.trafficLightLayouts, isEmpty);
        expect(tester.getRect(find.byType(WindowChrome)).right, 800);

        await tester.tap(caption('Minimize'));
        await tester.tap(caption('Maximize'));
        await tester.tap(caption('Close'));
        expect(window.calls, ['minimize', 'toggleMaximize', 'close']);
      });

      testWidgets('shows Restore while maximized', (tester) async {
        await tester.pumpWidget(bar());
        window.stateNotifier.value = const DesktopWindowState(maximized: true);
        await tester.pump();
        expect(caption('Maximize'), findsNothing);
        expect(caption('Restore'), findsOneWidget);
      });

      testWidgets('reports the maximize button for the snap layouts, and '
          'gives the area back when it goes', (tester) async {
        await tester.pumpWidget(bar());
        await tester.pump();
        expect(
          window.maximizeButtonRects.last,
          const Rect.fromLTWH(
            800 - 2 * captionWidth,
            0,
            captionWidth,
            barContentHeight,
          ),
        );
        final reports = window.maximizeButtonRects.length;
        await tester.pump();
        expect(window.maximizeButtonRects, hasLength(reports));

        // Right to left: minimize at the right edge, then maximize.
        await tester.pumpWidget(bar(locale: const Locale('ar')));
        await tester.pump();
        expect(
          window.maximizeButtonRects.last,
          const Rect.fromLTWH(captionWidth, 0, captionWidth, barContentHeight),
        );

        await tester.pumpWidget(bar(show: false));
        expect(window.maximizeButtonRects.last, isNull);
      });

      testWidgets('draws the hover and press the native side reports', (
        tester,
      ) async {
        await tester.pumpWidget(bar());
        expect(captionBackground(tester, 1), const Color(0x00000000));
        window.maximizeButtonNotifier.value = const MaximizeButtonState(
          hovered: true,
        );
        await tester.pump();
        expect(captionBackground(tester, 1), light.surfaceHover);
        window.maximizeButtonNotifier.value = const MaximizeButtonState(
          hovered: true,
          pressed: true,
        );
        await tester.pump();
        expect(captionBackground(tester, 1), light.surfacePressed);
        // The other buttons stay as they are.
        expect(captionBackground(tester, 0), const Color(0x00000000));
      });
    });

    group('Linux', () {
      setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));

      testWidgets('draws the caption buttons at the end, without snap '
          'layouts', (tester) async {
        await tester.pumpWidget(bar());
        await tester.pump();
        expect(caption('Minimize'), findsOneWidget);
        expect(tester.getRect(find.byType(WindowChrome)).right, 800);
        expect(window.maximizeButtonRects, isEmpty);
      });
    });

    group('moving the window', () {
      const empty = Offset(400, 19);

      testWidgets('a drag on the empty space moves the window', (tester) async {
        await tester.pumpWidget(bar());
        await tester.dragFrom(empty, const Offset(60, 0));
        // Past the double-tap timeout the down started.
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(window.calls, ['startDragging']);
      });

      testWidgets('a double-click on the empty space does what the system '
          'does, at once', (tester) async {
        await tester.pumpWidget(bar());
        await tester.tapAt(empty, kind: PointerDeviceKind.mouse);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(empty, kind: PointerDeviceKind.mouse);
        // Counted on the second press, as a native title bar does.
        expect(window.calls, ['titleBarDoubleClicked']);
        await tester.pumpAndSettle();
        expect(window.calls, ['titleBarDoubleClicked']);
      });

      testWidgets("double-clicks follow the system's interval and distance", (
        tester,
      ) async {
        window.doubleClick = const DoubleClickSettings(
          interval: Duration(milliseconds: 500),
          distance: 4,
        );
        await tester.pumpWidget(bar());
        // Presses at given event times, as the platform stamps them.
        Future<void> press(Offset at, int milliseconds) async {
          final time = Duration(milliseconds: milliseconds);
          final gesture = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await gesture.down(at, timeStamp: time);
          await gesture.up(timeStamp: time);
          await gesture.removePointer();
        }

        // 400 ms apart: past Flutter's 300 ms, inside the system's 500 ms.
        await press(empty, 0);
        await press(empty, 400);
        expect(window.calls, ['titleBarDoubleClicked']);

        // Too slow.
        window.calls.clear();
        await press(empty, 2000);
        await press(empty, 2600);
        expect(window.calls, isEmpty);

        // Too far apart.
        await press(empty, 4000);
        await press(empty + const Offset(10, 0), 4050);
        expect(window.calls, isEmpty);

        // After a double-click, a third press starts counting again.
        await press(empty, 6000);
        await press(empty, 6050);
        await press(empty, 6100);
        expect(window.calls, ['titleBarDoubleClicked']);
        await tester.pumpAndSettle();
      });

      testWidgets('a secondary click is not part of a double-click', (
        tester,
      ) async {
        await tester.pumpWidget(bar());
        await tester.tapAt(
          empty,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryButton,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(empty, kind: PointerDeviceKind.mouse);
        expect(window.calls, isEmpty);
        await tester.pumpAndSettle();
      });

      testWidgets('a mouse drag moves the window; a trackpad scroll does not', (
        tester,
      ) async {
        await tester.pumpWidget(bar());
        final trackpad = await tester.startGesture(
          empty,
          kind: PointerDeviceKind.trackpad,
        );
        await tester.pump();
        await trackpad.panZoomUpdate(empty, pan: const Offset(60, 0));
        await tester.pump();
        await trackpad.panZoomEnd();
        await tester.pumpAndSettle();
        expect(window.calls, isEmpty);

        await tester.dragFrom(
          empty,
          const Offset(60, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(window.calls, ['startDragging']);
      });

      testWidgets('the empty space is not in the semantics tree', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(bar());
        final nodes = <SemanticsNode>[];
        void collect(SemanticsNode node) {
          nodes.add(node);
          node.visitChildren((child) {
            collect(child);
            return true;
          });
        }

        collect(tester.getSemantics(find.byType(TitleBar)));
        for (final node in nodes) {
          final data = node.getSemanticsData();
          expect(data.hasAction(SemanticsAction.scrollLeft), isFalse);
          expect(data.hasAction(SemanticsAction.scrollUp), isFalse);
        }
        semantics.dispose();
      });

      testWidgets('controls in the content keep their clicks and drags', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          bar(
            content: Align(
              alignment: AlignmentDirectional.centerStart,
              child: GestureDetector(
                key: const Key('tab'),
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                onHorizontalDragStart: (_) {},
                child: const SizedBox(width: 120, height: 30),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('tab')));
        await tester.drag(find.byKey(const Key('tab')), const Offset(60, 0));
        expect(taps, 1);
        expect(window.calls, isEmpty);
      });
    });
  });

  group('WindowFrame', () {
    Widget frame(DesktopWindow window) {
      final container = ProviderContainer(
        overrides: [desktopWindowProvider.overrideWithValue(window)],
      );
      addTearDown(container.dispose);
      return UncontrolledProviderScope(
        container: container,
        child: componentHost(
          const SizedBox(
            width: 800,
            height: 600,
            child: WindowFrame(child: SizedBox.expand(key: Key('screen'))),
          ),
        ),
      );
    }

    testWidgets('puts the title bar above the screen on the desktop', (
      tester,
    ) async {
      await tester.pumpWidget(frame(window));
      expect(find.byType(TitleBar), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('screen'))),
        const Rect.fromLTRB(0, 38, 800, 600),
      );
    });

    testWidgets('is just the screen where the system frames the app', (
      tester,
    ) async {
      final none = NoDesktopWindow();
      addTearDown(none.dispose);
      await tester.pumpWidget(frame(none));
      expect(find.byType(TitleBar), findsNothing);
      expect(
        tester.getRect(find.byKey(const Key('screen'))),
        const Rect.fromLTRB(0, 0, 800, 600),
      );
    });
  });
}
