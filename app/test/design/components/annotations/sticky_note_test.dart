import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/annotations/sticky_note.dart';
import 'package:ferman/design/components/forms/text_field.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const ramps = FermanRamps();
  final pin = find.byKey(const ValueKey<String>('StickyNote.pin'));
  final card = find.byKey(const ValueKey<String>('StickyNote.card'));
  final head = find.byKey(const ValueKey<String>('StickyNote.head'));

  Widget note({
    bool collapsed = false,
    AnnotationColor color = AnnotationColor.yellow,
    List<NoteReply> replies = const [],
    VoidCallback? onToggle,
    ValueChanged<String>? onReply,
    VoidCallback? onMore,
  }) => StickyNote(
    author: 'Mert Kaya',
    time: '09:58',
    text: 'Artış oranı TÜFE’ye bağlı kalsın.',
    semanticLabel: 'Note from Mert Kaya',
    moreLabel: 'More',
    closeLabel: 'Close note',
    replyPlaceholder: 'Reply',
    collapsed: collapsed,
    color: color,
    replies: replies,
    onToggle: onToggle,
    onReply: onReply,
    onMore: onMore,
  );

  Finder headButton(String label) => find.byWidgetPredicate(
    (w) => w is FermanInteractive && w.semanticLabel == label,
  );

  FocusRingPainter pinRingOf(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find
                    .ancestor(of: pin, matching: find.byType(CustomPaint))
                    .first,
              )
              .foregroundPainter!
          as FocusRingPainter;

  /// The label of the control that has focus, or its focus node's.
  String? focusedLabel() {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (context == null) return null;
    return context
            .findAncestorWidgetOfExactType<FermanInteractive>()
            ?.semanticLabel ??
        focus?.debugLabel;
  }

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('StickyNote pin', () {
    testWidgets('a 24 px pin in the note colour with its shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(note(collapsed: true, onToggle: () {})),
      );
      expect(tester.getSize(pin), const Size.square(StickyNote.pinSize));
      final box = tester.widget<Container>(pin).decoration! as BoxDecoration;
      expect(box.color, ramps.annotYellow);
      expect(box.boxShadow, StickyNote.pinDropShadow);
      // `0 2px 4px`: a CSS blur of 4 px is a blur radius of 2.5981.
      expect(StickyNote.pinDropShadow.single.blurRadius, 2.5981);
      // The hairline ring, its corner grown to 5 px as CSS does, above the
      // drop shadow.
      final ring = pinRingOf(tester);
      expect(ring.layers, StickyNote.pinRing);
      expect(
        ring.borderRadius,
        const BorderRadius.all(Radius.circular(StickyNote.pinRadius)),
      );
      expect(
        tester.renderObject(
          find.ancestor(of: pin, matching: find.byType(CustomPaint)).first,
        ),
        paints..drrect(
          outer: RRect.fromRectAndRadius(
            const Rect.fromLTWH(-1, -1, 26, 26),
            const Radius.circular(StickyNote.pinRadius + 1),
          ),
        ),
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).name,
        IconName.messageSquare,
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color, ramps.paper900);
    });

    testWidgets('click, Enter and Space expand it', (tester) async {
      var toggles = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(note(collapsed: true, onToggle: () => toggles++)),
      );
      await tester.tap(pin);
      expect(toggles, 1);
      Focus.of(tester.element(find.byType(Icon))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(toggles, 3);
      expect(
        tester.getSemantics(find.byType(Icon)),
        isSemantics(label: 'Note from Mert Kaya', isButton: true),
      );
      handle.dispose();
    });

    testWidgets('keyboard focus: the white and ink ring', (tester) async {
      await tester.pumpWidget(
        componentHost(
          note(collapsed: true, onToggle: () {}),
          forcedStates: const {WidgetState.focused},
        ),
      );
      final box = tester.widget<Container>(pin).decoration! as BoxDecoration;
      // Focus replaces the whole box shadow.
      expect(box.boxShadow, isNull);
      expect(pinRingOf(tester).layers, [
        BoxShadow(color: ramps.ink500, spreadRadius: StickyNote.pinFocusSpread),
        const BoxShadow(
          color: StickyNote.pinFocusGap,
          spreadRadius: StickyNote.pinFocusGapSpread,
        ),
      ]);
      // Each band's corner grows with it: 8 px for the ink, 6 px for the
      // white.
      expect(
        tester.renderObject(
          find.ancestor(of: pin, matching: find.byType(CustomPaint)).first,
        ),
        paints
          ..drrect(
            color: ramps.ink500,
            outer: RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -4, 32, 32),
              const Radius.circular(8),
            ),
          )
          ..drrect(
            color: StickyNote.pinFocusGap,
            outer: RRect.fromRectAndRadius(
              const Rect.fromLTWH(-2, -2, 28, 28),
              const Radius.circular(6),
            ),
          ),
      );
    });

    testWidgets(
      'opened from the keyboard: focus in, Esc closes, back to the pin',
      (tester) async {
        final after = FocusNode(debugLabel: 'after');
        addTearDown(after.dispose);
        var collapsed = true;
        final sent = <String>[];
        await tester.pumpWidget(
          componentHost(
            Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: Actions(
                actions: WidgetsApp.defaultActions,
                child: StatefulBuilder(
                  builder: (context, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      note(
                        collapsed: collapsed,
                        onToggle: () => setState(() => collapsed = !collapsed),
                        onReply: sent.add,
                      ),
                      Focus(focusNode: after, child: const SizedBox.square()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> key(LogicalKeyboardKey key) async {
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
        }

        Focus.of(tester.element(find.byType(Icon))).requestFocus();
        await tester.pumpAndSettle();
        expect(focusedLabel(), 'Note from Mert Kaya');
        // Enter opens the card and focus moves into it.
        await key(LogicalKeyboardKey.enter);
        expect(collapsed, isFalse);
        expect(focusedLabel(), 'StickyNote.card');
        await key(LogicalKeyboardKey.tab);
        expect(focusedLabel(), 'More');
        // Escape closes it and focus returns to the pin.
        await key(LogicalKeyboardKey.escape);
        expect(collapsed, isTrue);
        expect(focusedLabel(), 'Note from Mert Kaya');
        // Close, from the keyboard, does the same.
        await key(LogicalKeyboardKey.enter);
        await key(LogicalKeyboardKey.tab);
        await key(LogicalKeyboardKey.tab);
        expect(focusedLabel(), 'Close note');
        await key(LogicalKeyboardKey.enter);
        expect(collapsed, isTrue);
        expect(focusedLabel(), 'Note from Mert Kaya');
        // Escape in the reply field closes it too.
        await key(LogicalKeyboardKey.enter);
        await key(LogicalKeyboardKey.tab);
        await key(LogicalKeyboardKey.tab);
        await key(LogicalKeyboardKey.tab);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
        // A note is not modal: Tab goes on out of the card.
        await key(LogicalKeyboardKey.tab);
        expect(after.hasFocus, isTrue);
        await key(LogicalKeyboardKey.tab);
        // Back in the card (wherever traversal lands), Escape closes it.
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .requestFocus();
        await tester.pumpAndSettle();
        await key(LogicalKeyboardKey.escape);
        expect(collapsed, isTrue);
        expect(focusedLabel(), 'Note from Mert Kaya');
        expect(sent, isEmpty);
      },
    );
  });

  group('StickyNote card', () {
    testWidgets('expanded: 256 px raised card with a coloured head', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(note(color: AnnotationColor.green, onToggle: () {})),
      );
      expect(tester.getSize(card).width, StickyNote.cardWidth);
      final surface =
          tester.widget<Container>(card).decoration! as BoxDecoration;
      expect(surface.color, FermanColorTokens.light.surfaceRaised);
      expect(surface.boxShadow, FermanElevationTokens.light.shadowPopover);
      expect(tester.widget<Container>(head).color, ramps.annotGreen);
      expect(tester.getSize(head).height, StickyNote.headHeight);
      expect(find.text('Mert Kaya'), findsOneWidget);
      expect(find.text('09:58'), findsOneWidget);
      expect(find.text('Artış oranı TÜFE’ye bağlı kalsın.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('replies over hairlines', (tester) async {
      await tester.pumpWidget(
        componentHost(
          note(
            replies: const [
              NoteReply(
                author: 'Ayşe Yılmaz',
                time: '10:05',
                text: 'Katılıyorum.',
              ),
            ],
          ),
        ),
      );
      expect(find.text('Katılıyorum.'), findsOneWidget);
      expect(
        find.textContaining('Ayşe Yılmaz', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('Close calls onToggle; More is disabled with the reason', (
      tester,
    ) async {
      var toggles = 0;
      await tester.pumpWidget(componentHost(note(onToggle: () => toggles++)));
      await tester.tap(headButton('Close note'));
      expect(toggles, 1);
      final more = tester.widget<FermanInteractive>(headButton('More'));
      expect(more.onPressed, isNull);
      expect(
        more.disabledReason,
        futureVersionReason(tester.element(find.byType(StickyNote))),
      );
    });

    testWidgets('head buttons: page ink, the head hover tint', (tester) async {
      await tester.pumpWidget(
        componentHost(
          note(onToggle: () {}),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      final square = tester.widget<Container>(
        find
            .descendant(
              of: headButton('Close note'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (square.decoration! as BoxDecoration).color,
        StickyNote.headButtonHover,
      );
      // `.fm-iconbtn` transitions: the tint over --dur-instant, the focus
      // ring over --dur-fast.
      const motion = FermanMotionTokens.standard;
      expect(
        tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: headButton('Close note'),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .duration,
        motion.durInstant,
      );
      expect(
        tester
            .widget<FocusRing>(
              find.descendant(
                of: headButton('Close note'),
                matching: find.byType(FocusRing),
              ),
            )
            .duration,
        motion.durFast,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: headButton('Close note'),
                matching: find.byType(Icon),
              ),
            )
            .color,
        ramps.paper800,
      );
    });

    testWidgets('Enter in the reply field sends and clears it', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(componentHost(note(onReply: sent.add)));
      expect(find.text('Reply'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.enterText(find.byType(EditableText), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(sent, isEmpty);
      // The field keeps focus after Enter, even on an empty field.
      bool fieldFocused() => tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode
          .hasFocus;
      await tester.pumpAndSettle();
      expect(fieldFocused(), isTrue);
      await tester.enterText(find.byType(EditableText), 'Tamam.');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(sent, ['Tamam.']);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
      expect(fieldFocused(), isTrue);
      // Ready for the next reply.
      await tester.enterText(find.byType(EditableText), 'Bir de bu.');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(sent, ['Tamam.', 'Bir de bu.']);
      expect(fieldFocused(), isTrue);
    });

    testWidgets('semantics: a dialog named after the author', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(note()));
      final dialog = find.bySemanticsLabel('Note from Mert Kaya');
      expect(dialog, findsOneWidget);
      expect(
        tester.getSemantics(dialog).getSemanticsData().role,
        SemanticsRole.dialog,
      );
      expect(
        tester.getSemantics(dialog),
        isSemantics(namesRoute: true, scopesRoute: true),
      );
      handle.dispose();
    });

    testWidgets('dark theme: dark surface, the same head colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(note(), brightness: Brightness.dark),
      );
      final surface =
          tester.widget<Container>(card).decoration! as BoxDecoration;
      expect(surface.color, FermanColorTokens.dark.surfaceRaised);
      expect(tester.widget<Container>(head).color, ramps.annotYellow);
    });

    testWidgets('right to left: the author starts at the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(note(), textDirection: TextDirection.rtl),
      );
      final headRight = tester.getTopRight(head).dx;
      final authorRight = tester.getTopRight(find.text('Mert Kaya')).dx;
      expect(headRight - authorRight, FermanSpaceTokens.space2_5);
    });
  });
}
