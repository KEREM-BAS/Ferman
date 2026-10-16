import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/foundation/modal_scope.dart';
import 'package:ferman/design/components/overlays/dialog.dart';
import 'package:ferman/design/components/overlays/scrim.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import '../keyboard_reach.dart';

/// A focusable stand-in for a footer or body button.
class _Button extends StatelessWidget {
  const new(this.label, {this.node, this.autofocus = false});

  final String label;
  final FocusNode? node;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: node,
    autofocus: autofocus,
    child: SizedBox(width: 80, height: 30, child: Text(label)),
  );
}

/// A tap counter that keeps its count in its state.
class _Counter extends StatefulWidget {
  const new();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _taps++),
    child: SizedBox(width: 80, height: 30, child: Text('Taps $_taps')),
  );
}

/// [page] as the first route of a navigator under a 40 px top bar, as the
/// app's screens sit under the window frame's title bar.
Widget _nested(Widget page, {GlobalKey<NavigatorState>? navigator}) =>
    SizedBox.expand(
      child: Column(
        children: [
          const SizedBox(height: 40, width: double.infinity),
          Expanded(
            child: Navigator(
              key: navigator,
              onGenerateRoute: (settings) => _route(page),
            ),
          ),
        ],
      ),
    );

PageRouteBuilder<void> _route(Widget page) => PageRouteBuilder<void>(
  pageBuilder: (context, animation, secondary) => page,
);

/// Whether a pointer at [position] reaches the scrim.
bool _scrimHit(WidgetTester tester, Offset position) {
  final scrim = <RenderObject>{};
  for (final element in find.byType(Scrim, skipOffstage: false).evaluate()) {
    void visit(Element child) {
      final object = child.renderObject;
      if (object != null) scrim.add(object);
      child.visitChildren(visit);
    }

    visit(element);
  }
  return tester
      .hitTestOnBinding(position)
      .path
      .any((entry) => scrim.contains(entry.target));
}

void main() {
  final light = FermanTheme.light.colors;
  final dark = FermanTheme.dark.colors;

  final boxFinder = find
      .descendant(of: find.byType(Dialog), matching: find.byType(DecoratedBox))
      .first;
  final modalBoxFinder = find
      .descendant(of: find.byType(Scrim), matching: find.byType(DecoratedBox))
      .first;

  BoxDecoration surfaceOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(
                      of: find.byType(Dialog),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;

  Widget dialog({
    bool open = true,
    bool inline = false,
    DialogTone tone = DialogTone.standard,
    DialogSize size = DialogSize.md,
    IconName? icon = IconName.shieldAlert,
    Widget? child = const Text('Body text'),
    List<Widget> actions = const [_Button('Cancel'), _Button('Apply')],
    Widget? cancelAction,
    Widget? alternateAction,
    DialogButtonOrder? buttonOrder,
    Widget? footerStart,
    VoidCallback? onClose,
  }) => Dialog(
    open: open,
    inline: inline,
    title: 'Apply 2 redactions?',
    description: 'The text under them is removed for good.',
    icon: icon,
    tone: tone,
    size: size,
    actions: actions,
    cancelAction: cancelAction,
    alternateAction: alternateAction,
    buttonOrder: buttonOrder,
    footerStart: footerStart,
    onClose: onClose,
    closeLabel: 'Close',
    child: child,
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    ModalScope.debugReset();
  });

  group('Dialog', () {
    testWidgets('inline: the box in place, 520 px, large corners, dialog '
        'shadow', (tester) async {
      await tester.pumpWidget(componentHost(dialog(inline: true)));
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsNothing);
      final surface = surfaceOf(tester);
      expect(surface.color, light.surfaceRaised);
      expect(surface.borderRadius, const BorderRadius.all(Radius.circular(8)));
      expect(surface.boxShadow, FermanTheme.light.elevation.shadowDialog);
      expect(
        tester
            .getSize(
              find
                  .descendant(
                    of: find.byType(Dialog),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .width,
        520,
      );
    });

    testWidgets('sizes: 400, 520 and 640 px', (tester) async {
      for (final (size, width) in [
        (DialogSize.sm, 400.0),
        (DialogSize.md, 520.0),
        (DialogSize.lg, 640.0),
      ]) {
        await tester.pumpWidget(
          componentHost(
            dialog(inline: true, size: size),
            size: const Size(900, 700),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(Dialog),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .width,
          width,
        );
      }
    });

    testWidgets('head: glyph colours by tone, title and description type', (
      tester,
    ) async {
      for (final (tone, background, foreground) in [
        (DialogTone.standard, light.accentSubtle, light.textAccent),
        (DialogTone.warning, light.warningBg, light.warning),
        (DialogTone.danger, light.dangerBg, light.danger),
      ]) {
        await tester.pumpWidget(
          componentHost(dialog(inline: true, tone: tone)),
        );
        await tester.pumpAndSettle();
        final glyph = tester.widget<Container>(
          find
              .ancestor(of: find.byType(Icon), matching: find.byType(Container))
              .first,
        );
        expect((glyph.decoration! as BoxDecoration).color, background);
        expect(tester.widget<Icon>(find.byType(Icon)).color, foreground);
        expect(tester.widget<Icon>(find.byType(Icon)).size, 18);
      }
      final title = tester.widget<Text>(find.text('Apply 2 redactions?'));
      expect(title.style!.fontSize, 16);
      expect(title.style!.fontWeight, FontWeight.w600);
      final description = tester.widget<Text>(
        find.text('The text under them is removed for good.'),
      );
      expect(description.style!.color, light.textSecondary);
      expect(description.style!.fontSize, 14);
    });

    testWidgets('layout: head 18 px down and 20 px in, actions at the end '
        '8 px apart, footer start at the start', (tester) async {
      await tester.pumpWidget(
        componentHost(
          dialog(inline: true, footerStart: const Text('Don’t ask again')),
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final glyph = tester.getRect(
        find
            .ancestor(of: find.byType(Icon), matching: find.byType(Container))
            .first,
      );
      expect(glyph.top - box.top, 18);
      expect(glyph.left - box.left, 20);
      final cancel = tester.getRect(find.widgetWithText(_Button, 'Cancel'));
      final apply = tester.getRect(find.widgetWithText(_Button, 'Apply'));
      expect(box.right - apply.right, 20);
      expect(apply.left - cancel.left - 80, 8);
      expect(tester.getRect(find.text('Don’t ask again')).left - box.left, 20);
      // `.fm-dialog__body { padding: 16px 20px }` then the foot's 4 px top
      // and 18 px bottom.
      expect(apply.top - tester.getRect(find.text('Body text')).bottom, 16 + 4);
      expect(box.bottom - apply.bottom, Dialog.footBottom);
    });

    test('button order by system: Cancel last on Windows only', () {
      for (final platform in TargetPlatform.values) {
        expect(
          DialogButtonOrder.of(platform),
          platform == TargetPlatform.windows
              ? DialogButtonOrder.cancelLast
              : DialogButtonOrder.cancelFirst,
          reason: '$platform',
        );
      }
      const a = SizedBox(key: Key('a'));
      const b = SizedBox(key: Key('b'));
      const cancel = SizedBox(key: Key('cancel'));
      const alternate = SizedBox(key: Key('alternate'));
      // The buttons apart at the start, then those lined up at the end.
      List<List<Widget>> arranged(
        DialogButtonOrder order, {
        Widget? cancel,
        Widget? alternate,
      }) {
        final (:start, :end) = order.arrange(
          const [a, b],
          cancel: cancel,
          alternate: alternate,
        );
        return [start, end];
      }

      expect(
        arranged(
          DialogButtonOrder.cancelFirst,
          cancel: cancel,
          alternate: alternate,
        ),
        [
          [alternate],
          [cancel, a, b],
        ],
      );
      expect(
        arranged(
          DialogButtonOrder.cancelLast,
          cancel: cancel,
          alternate: alternate,
        ),
        [
          <Widget>[],
          [b, a, alternate, cancel],
        ],
      );
      expect(arranged(DialogButtonOrder.cancelFirst, cancel: cancel), [
        <Widget>[],
        [cancel, a, b],
      ]);
      expect(arranged(DialogButtonOrder.cancelLast), [
        <Widget>[],
        [b, a],
      ]);
    });

    testWidgets(
      'button order (a1-10b): on macOS and Linux "Don’t save" apart at the '
      'start, then Cancel and Save at the end; on Windows Save, Don’t save, '
      'Cancel at the end. The footer start stays at the start (f6a, G15, '
      'G16)',
      (tester) async {
        final windows = defaultTargetPlatform == TargetPlatform.windows;
        Rect rect(String label) =>
            tester.getRect(find.widgetWithText(_Button, label));
        List<String> drawn(List<String> labels) =>
            labels..sort((a, b) => rect(a).left.compareTo(rect(b).left));

        await tester.pumpWidget(
          componentHost(
            dialog(
              inline: true,
              cancelAction: const _Button('Cancel'),
              alternateAction: const _Button('Don’t save'),
              actions: const [_Button('Save')],
            ),
          ),
        );
        await tester.pumpAndSettle();
        var box = tester.getRect(boxFinder);
        expect(
          drawn(['Cancel', 'Don’t save', 'Save']),
          windows
              ? ['Save', 'Don’t save', 'Cancel']
              : ['Don’t save', 'Cancel', 'Save'],
        );
        // The end group 20 px in, 8 px apart.
        final end = windows
            ? ['Save', 'Don’t save', 'Cancel']
            : ['Cancel', 'Save'];
        expect(box.right - rect(end.last).right, 20);
        for (var i = 1; i < end.length; i++) {
          expect(rect(end[i]).left - rect(end[i - 1]).right, 8);
        }
        if (!windows) {
          expect(rect('Don’t save').left - box.left, 20);
          expect(
            rect('Cancel').left - rect('Don’t save').right,
            greaterThan(8),
          );
        }

        // f6a: primary, then secondary, then Cancel on Windows; and a footer
        // start, which stays at the start, with the alternate after it on
        // macOS and Linux.
        await tester.pumpWidget(
          componentHost(
            dialog(
              inline: true,
              footerStart: const Text('Don’t ask again'),
              cancelAction: const _Button('Cancel'),
              alternateAction: const _Button('Don’t save'),
              actions: const [_Button('Secondary'), _Button('Primary')],
            ),
          ),
        );
        await tester.pumpAndSettle();
        box = tester.getRect(boxFinder);
        final askAgain = tester.getRect(find.text('Don’t ask again'));
        expect(askAgain.left - box.left, 20);
        expect(
          drawn(['Cancel', 'Don’t save', 'Secondary', 'Primary']),
          windows
              ? ['Primary', 'Secondary', 'Don’t save', 'Cancel']
              : ['Don’t save', 'Cancel', 'Secondary', 'Primary'],
        );
        expect(rect('Don’t save').left > askAgain.right, isTrue);
        if (!windows) {
          expect(rect('Don’t save').left - askAgain.right, 8);
        }
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      }),
    );

    testWidgets('buttonOrder overrides the system; right to left mirrors the '
        'row', (tester) async {
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          componentHost(
            dialog(
              inline: true,
              buttonOrder: DialogButtonOrder.cancelLast,
              cancelAction: const _Button('Cancel'),
              actions: const [_Button('Apply')],
            ),
            textDirection: direction,
          ),
        );
        await tester.pumpAndSettle();
        final apply = tester.getRect(find.widgetWithText(_Button, 'Apply'));
        final cancel = tester.getRect(find.widgetWithText(_Button, 'Cancel'));
        // Apply leads in the reading direction.
        expect(
          direction == TextDirection.ltr
              ? apply.left < cancel.left
              : apply.left > cancel.left,
          isTrue,
          reason: '$direction',
        );
      }
    });

    testWidgets(
      'button order: focus starts on the default button, Tab and '
      'Shift+Tab follow the drawn order inside the dialog, Enter activates '
      'the focused button and Escape closes, on every system',
      (tester) async {
        final pressed = <String>[];
        var closes = 0;
        final save = FocusNode(debugLabel: 'Save');
        final dontSave = FocusNode(debugLabel: 'Don’t save');
        final cancel = FocusNode(debugLabel: 'Cancel');
        for (final node in [save, dontSave, cancel]) {
          addTearDown(node.dispose);
        }
        Widget button(String label, FocusNode node, {bool autofocus = false}) =>
            Button(
              focusNode: node,
              autofocus: autofocus,
              onPressed: () => pressed.add(label),
              child: Text(label),
            );
        await tester.pumpWidget(
          componentHost(
            dialog(
              child: null,
              onClose: () => closes++,
              cancelAction: button('Cancel', cancel),
              alternateAction: button('Don’t save', dontSave),
              actions: [button('Save', save, autofocus: true)],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(save.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(pressed, ['Save']);
        final close = find.byWidgetPredicate(
          (w) => w is IconButton && w.label == 'Close',
        );
        String? focused() {
          for (final (name, node) in [
            ('Save', save),
            ('Don’t save', dontSave),
            ('Cancel', cancel),
          ]) {
            if (node.hasPrimaryFocus) return name;
          }
          return focusIsWithin(close) ? 'Close' : null;
        }

        Future<void> tab({bool shift = false}) async {
          if (shift) {
            await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pump();
        }

        // From Save in the drawn order, wrapping through the close button
        // in the head, never out of the dialog.
        final expected = defaultTargetPlatform == TargetPlatform.windows
            ? ['Don’t save', 'Cancel', 'Close', 'Save']
            : ['Close', 'Don’t save', 'Cancel', 'Save'];
        final order = <String?>[];
        for (var i = 0; i < expected.length; i++) {
          await tab();
          order.add(focused());
        }
        expect(order, expected);
        await tab(shift: true);
        expect(focused(), expected[2]);
        cancel.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(pressed, ['Save', 'Cancel']);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(closes, 1);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      }),
    );

    testWidgets('modal: over a scrim in the overlay, closed when open is '
        'false', (tester) async {
      await tester.pumpWidget(componentHost(dialog(open: false)));
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsNothing);
      await tester.pumpWidget(componentHost(dialog()));
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsOneWidget);
      expect(find.text('Apply 2 redactions?'), findsOneWidget);
      final box = tester.getRect(
        find
            .descendant(
              of: find.byType(Scrim),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(box.center.dx, 400);
      await tester.pumpWidget(componentHost(dialog(open: false)));
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsNothing);
    });

    testWidgets('modal: Escape and a scrim click call onClose; a pointer '
        'down inside the box does not', (tester) async {
      var closes = 0;
      await tester.pumpWidget(componentHost(dialog(onClose: () => closes++)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 1);
      await tester.tapAt(tester.getRect(modalBoxFinder).center);
      await tester.tap(find.text('Apply 2 redactions?'));
      expect(closes, 1);
      await tester.tapAt(const Offset(10, 10));
      expect(closes, 2);
    });

    testWidgets('modal: in the root overlay, so the scrim covers the whole '
        'window, a top bar over a nested navigator included', (tester) async {
      const bar = Key('bar');
      await tester.pumpWidget(
        componentHost(
          SizedBox.expand(
            child: Column(
              children: [
                // The window frame's title bar, above the screens'
                // navigator.
                const SizedBox(key: bar, height: 40, width: double.infinity),
                Expanded(
                  child: Navigator(
                    onGenerateRoute: (settings) => PageRouteBuilder<void>(
                      pageBuilder: (context, animation, secondary) =>
                          Center(child: dialog(onClose: () {})),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(Scrim)),
        Offset.zero & const Size(800, 600),
      );
      final barRect = tester.getRect(find.byKey(bar));
      expect(
        tester.getRect(find.byType(Scrim)).contains(barRect.center),
        isTrue,
      );
      // The box is centred in the window, not in the navigator's area.
      expect(tester.getRect(modalBoxFinder).center, const Offset(400, 300));
      // A pointer down on the title bar's area lands on the scrim.
      expect(
        tester
            .hitTestOnBinding(barRect.center)
            .path
            .any(
              (entry) =>
                  entry.target is RenderBox &&
                  tester
                      .renderObjectList<RenderBox>(find.byType(Scrim))
                      .contains(entry.target),
            ),
        isTrue,
      );
    });

    testWidgets('modal: counted by ModalScope while it shows', (tester) async {
      expect(ModalScope.openCount.value, 0);
      await tester.pumpWidget(componentHost(dialog()));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 1);
      await tester.pumpWidget(componentHost(dialog(open: false)));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 0);
      await tester.pumpWidget(componentHost(dialog()));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 1);
      // Disposed while open.
      await tester.pumpWidget(componentHost(const SizedBox()));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 0);
      // An inline dialog is not a modal.
      await tester.pumpWidget(componentHost(dialog(inline: true)));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 0);
      // An open modal that turns inline stops counting, and so does a
      // later close.
      await tester.pumpWidget(componentHost(dialog()));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 1);
      await tester.pumpWidget(componentHost(dialog(inline: true)));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 0);
      await tester.pumpWidget(componentHost(dialog(inline: true, open: false)));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 0);
      await tester.pumpWidget(componentHost(dialog()));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 1);
    });

    testWidgets('modal under a nested navigator: a tooltip and a popover in '
        'the body show above the box', (tester) async {
      await tester.pumpWidget(
        TapRegionSurface(
          child: componentHost(
            _nested(
              dialog(
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: 'Tip text',
                      open: true,
                      child: SizedBox(width: 40, height: 20),
                    ),
                    Popover(
                      open: true,
                      anchor: SizedBox(width: 40, height: 20),
                      child: SizedBox(
                        width: 120,
                        height: 60,
                        child: Text('Popover text'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tip text'), findsOneWidget);
      expect(find.text('Popover text'), findsOneWidget);
      // The box keeps its size and place.
      expect(tester.getSize(modalBoxFinder).width, 520);
      expect(tester.getRect(modalBoxFinder).center.dx, 400);
      // A pointer on the popover reaches it, not the scrim or the box.
      final popover = tester.renderObject(find.text('Popover text'));
      final hit = tester.hitTestOnBinding(
        tester.getCenter(find.text('Popover text')),
      );
      expect(hit.path.first.target, popover);
    });

    testWidgets('modal: a route pushed above hides it and stops counting it; '
        'popping shows it again with its state and focus', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final field = FocusNode(debugLabel: 'field');
      final above = FocusNode(debugLabel: 'above');
      addTearDown(field.dispose);
      addTearDown(above.dispose);
      var closes = 0;
      var taps = 0;
      await tester.pumpWidget(
        componentHost(
          _nested(
            dialog(
              onClose: () => closes++,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Button('Field', node: field, autofocus: true),
                  const _Counter(),
                ],
              ),
            ),
            navigator: navigator,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taps 0'));
      await tester.pump();
      expect(find.text('Taps 1'), findsOneWidget);
      expect(field.hasFocus, isTrue);
      expect(ModalScope.openCount.value, 1);
      const point = Offset(400, 500);
      expect(_scrimHit(tester, point), isTrue);
      navigator.currentState!.push(
        _route(
          Focus(
            focusNode: above,
            autofocus: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      // Hidden from the push on, while the new route comes in.
      await tester.pump();
      await tester.pump();
      expect(_scrimHit(tester, point), isFalse);
      expect(ModalScope.openCount.value, 0);
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsNothing);
      expect(_scrimHit(tester, point), isFalse);
      expect(ModalScope.openCount.value, 0);
      await tester.tapAt(point);
      await tester.pump();
      expect(taps, 1);
      expect(closes, 0);
      expect(above.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsOneWidget);
      expect(_scrimHit(tester, point), isTrue);
      expect(ModalScope.openCount.value, 1);
      expect(find.text('Taps 1'), findsOneWidget);
      expect(field.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 1);
    });

    testWidgets('modal: closed while a route above hides it, it leaves focus '
        'on that route', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final above = FocusNode(debugLabel: 'above');
      final opener = FocusNode(debugLabel: 'opener');
      addTearDown(above.dispose);
      addTearDown(opener.dispose);
      final open = ValueNotifier<bool>(false);
      addTearDown(open.dispose);
      await tester.pumpWidget(
        componentHost(
          _nested(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Button('Opener', node: opener),
                ValueListenableBuilder<bool>(
                  valueListenable: open,
                  builder: (context, value, _) => dialog(open: value),
                ),
              ],
            ),
            navigator: navigator,
          ),
        ),
      );
      opener.requestFocus();
      await tester.pumpAndSettle();
      open.value = true;
      await tester.pumpAndSettle();
      expect(opener.hasFocus, isFalse);
      navigator.currentState!.push(
        _route(
          Focus(focusNode: above, autofocus: true, child: const Text('Above')),
        ),
      );
      await tester.pumpAndSettle();
      expect(above.hasFocus, isTrue);
      open.value = false;
      await tester.pumpAndSettle();
      expect(above.hasFocus, isTrue);
      expect(ModalScope.openCount.value, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsNothing);
      expect(ModalScope.openCount.value, 0);
    });

    testWidgets('modal: opened while a route above covers its own, it waits '
        'for that route to go, without taking focus', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final above = FocusNode(debugLabel: 'above');
      final field = FocusNode(debugLabel: 'field');
      addTearDown(above.dispose);
      addTearDown(field.dispose);
      final open = ValueNotifier<bool>(false);
      addTearDown(open.dispose);
      await tester.pumpWidget(
        componentHost(
          _nested(
            ValueListenableBuilder<bool>(
              valueListenable: open,
              builder: (context, value, _) => dialog(
                open: value,
                child: _Button('Field', node: field, autofocus: true),
              ),
            ),
            navigator: navigator,
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        _route(
          Focus(focusNode: above, autofocus: true, child: const Text('Up')),
        ),
      );
      await tester.pumpAndSettle();
      open.value = true;
      await tester.pumpAndSettle();
      expect(above.hasFocus, isTrue);
      expect(field.hasFocus, isFalse);
      expect(find.byType(Scrim), findsNothing);
      expect(ModalScope.openCount.value, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsOneWidget);
      expect(ModalScope.openCount.value, 1);
      expect(field.hasFocus, isTrue);
    });

    testWidgets('modal: rises 4 px and fades in over --dur-slow; at once '
        'with reduced motion', (tester) async {
      await tester.pumpWidget(componentHost(dialog()));
      final opacity = find
          .ancestor(of: modalBoxFinder, matching: find.byType(Opacity))
          .first;
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      final first = tester.getRect(modalBoxFinder).top;
      await tester.pump(FermanTheme.light.motion.durSlow);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      expect(first - tester.getRect(modalBoxFinder).top, Dialog.riseDistance);
      await tester.pumpWidget(
        componentHost(
          KeyedSubtree(key: UniqueKey(), child: dialog()),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: modalBoxFinder, matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
        1,
      );
    });

    testWidgets('modal: clamped to the window less 16 px a side and 32 px '
        'above and below, the body scrolling', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 300)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        componentHost(
          dialog(child: const SizedBox(height: 1000)),
          size: const Size(400, 300),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(modalBoxFinder), const Size(368, 236));
      final body = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        ),
      );
      expect(body.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('modal: no onClose, no Escape', (tester) async {
      await tester.pumpWidget(componentHost(dialog()));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsOneWidget);
    });

    testWidgets('modal: focus goes to the autofocus child, Tab cycles inside, '
        'focus returns on close', (tester) async {
      final outside = FocusNode();
      final cancel = FocusNode();
      final apply = FocusNode();
      for (final node in [outside, cancel, apply]) {
        addTearDown(node.dispose);
      }
      Widget page({required bool open}) => componentHost(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              focusNode: outside,
              child: const SizedBox(width: 10, height: 10),
            ),
            dialog(
              open: open,
              child: null,
              actions: [
                _Button('Cancel', node: cancel),
                _Button('Apply', node: apply, autofocus: true),
              ],
            ),
          ],
        ),
      );
      await tester.pumpWidget(page(open: false));
      outside.requestFocus();
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(open: true));
      await tester.pumpAndSettle();
      expect(apply.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(cancel.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(apply.hasFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(cancel.hasFocus, isTrue);
      expect(outside.hasFocus, isFalse);
      await tester.pumpWidget(page(open: false));
      await tester.pumpAndSettle();
      expect(outside.hasFocus, isTrue);
    });

    testWidgets('modal: without autofocus, the first control in the body', (
      tester,
    ) async {
      final field = FocusNode();
      addTearDown(field.dispose);
      await tester.pumpWidget(
        componentHost(dialog(child: _Button('Password', node: field))),
      );
      await tester.pumpAndSettle();
      expect(field.hasFocus, isTrue);
    });

    testWidgets('modal: with nothing focusable, the dialog itself', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(dialog(actions: const [])));
      await tester.pumpAndSettle();
      final focus = FocusManager.instance.primaryFocus;
      expect(focus?.debugLabel, 'Dialog box');
    });

    testWidgets('onClose shows the close button: a small x, 16 px from the '
        'end, named by closeLabel, without a tooltip', (tester) async {
      final handle = tester.ensureSemantics();
      var closes = 0;
      await tester.pumpWidget(componentHost(dialog(inline: true)));
      await tester.pumpAndSettle();
      expect(find.byType(IconButton), findsNothing);
      await tester.pumpWidget(
        componentHost(dialog(inline: true, onClose: () => closes++)),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.icon, IconName.x);
      expect(button.size, IconButtonSize.sm);
      expect(button.showTooltip, isFalse);
      expect(button.label, 'Close');
      final close = tester.getRect(find.byType(IconButton));
      expect(close.size, const Size.square(26));
      expect(tester.getRect(boxFinder).right - close.right, 16);
      expect(close.top - tester.getRect(boxFinder).top, Dialog.headTop);
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(closes, 1);
      handle.dispose();
    });

    test('a closable dialog needs closeLabel', () {
      expect(
        () => Dialog(title: 'Apply?', onClose: () {}),
        throwsAssertionError,
      );
    });

    testWidgets('inline: Escape inside calls onClose; nothing without it', (
      tester,
    ) async {
      var closes = 0;
      final field = FocusNode();
      addTearDown(field.dispose);
      await tester.pumpWidget(
        componentHost(
          dialog(
            inline: true,
            child: _Button('Password', node: field),
            onClose: () => closes++,
          ),
        ),
      );
      field.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 1);
      await tester.pumpWidget(
        componentHost(
          dialog(inline: true, child: _Button('Password', node: field)),
        ),
      );
      field.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no body: the footer sits 20 px under the head; with no foot '
        'either the box ends under the head', (tester) async {
      await tester.pumpWidget(componentHost(dialog(inline: true, child: null)));
      await tester.pumpAndSettle();
      expect(find.text('Body text'), findsNothing);
      // The titles column (taller than the 32 px glyph) ends the head.
      final head = tester
          .getRect(find.text('The text under them is removed for good.'))
          .bottom;
      final cancel = tester.getRect(find.widgetWithText(_Button, 'Cancel'));
      // `.fm-dialog__body:empty + .fm-dialog__foot { padding-top: 20px }`.
      expect(cancel.top - head, 20);
      expect(tester.getRect(boxFinder).bottom - cancel.bottom, 18);
      // `.fm-dialog__head` has no bottom padding.
      await tester.pumpWidget(
        componentHost(dialog(inline: true, child: null, actions: const [])),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(boxFinder).bottom,
        tester
            .getRect(find.text('The text under them is removed for good.'))
            .bottom,
      );
    });

    testWidgets('semantics: a dialog named by the title, an alert dialog for '
        'danger', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(dialog()));
      await tester.pumpAndSettle();
      var node = tester.getSemantics(find.byType(DecoratedBox).first);
      while (node.label != 'Apply 2 redactions?' && node.parent != null) {
        node = node.parent!;
      }
      var data = node.getSemanticsData();
      expect(data.label, 'Apply 2 redactions?');
      expect(data.hint, 'The text under them is removed for good.');
      expect(data.role, SemanticsRole.dialog);
      expect(data.flagsCollection.scopesRoute, isTrue);
      await tester.pumpWidget(componentHost(dialog(tone: DialogTone.danger)));
      await tester.pumpAndSettle();
      node = tester.getSemantics(find.text('Body text'));
      while (node.label != 'Apply 2 redactions?' && node.parent != null) {
        node = node.parent!;
      }
      data = node.getSemanticsData();
      expect(data.role, SemanticsRole.alertDialog);
      handle.dispose();
    });

    testWidgets('right to left: glyph on the right, actions on the left', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(dialog(inline: true), textDirection: TextDirection.rtl),
      );
      await tester.pumpAndSettle();
      final box = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final glyph = tester.getRect(
        find
            .ancestor(of: find.byType(Icon), matching: find.byType(Container))
            .first,
      );
      expect(box.right - glyph.right, 20);
      expect(
        tester.getRect(find.widgetWithText(_Button, 'Apply')).left - box.left,
        20,
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(dialog(inline: true), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      expect(surfaceOf(tester).color, FermanTheme.dark.colors.surfaceRaised);
    });

    testWidgets('dark theme: glyph colours by tone', (tester) async {
      for (final (tone, background, foreground) in [
        (DialogTone.standard, dark.accentSubtle, dark.textAccent),
        (DialogTone.warning, dark.warningBg, dark.warning),
        (DialogTone.danger, dark.dangerBg, dark.danger),
      ]) {
        await tester.pumpWidget(
          componentHost(
            dialog(inline: true, tone: tone),
            brightness: Brightness.dark,
          ),
        );
        await tester.pumpAndSettle();
        final glyph = tester.widget<Container>(
          find
              .ancestor(of: find.byType(Icon), matching: find.byType(Container))
              .first,
        );
        expect((glyph.decoration! as BoxDecoration).color, background);
        expect(tester.widget<Icon>(find.byType(Icon)).color, foreground);
      }
    });
  });
}
