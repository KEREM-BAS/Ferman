import 'package:ferman/design/components/additions/comment_card.dart';
import 'package:ferman/design/components/annotations/sticky_note.dart';
import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;
  const ramps = FermanRamps();
  final frame = find.byKey(const ValueKey<String>('CommentCard.frame'));
  final chip = find.byKey(const ValueKey<String>('CommentCard.chip'));

  const replies = [
    NoteReply(author: 'Mert Kaya', time: '10:40', text: 'Olur, 10’u yazalım.'),
    NoteReply(author: 'Av. Deniz Aksoy', time: '11:02', text: 'Güncelliyorum.'),
  ];

  Widget card({
    String author = 'Ayşe Yılmaz',
    List<NoteReply> replies = const [],
    bool expanded = false,
    bool composing = false,
    String? resolvedBy,
    VoidCallback? onPressed,
    VoidCallback? onResolve,
    ValueChanged<String>? onReply,
    VoidCallback? onReopen,
    Color? iconColor,
  }) => SizedBox(
    width: 284,
    child: CommentCard(
      icon: IconName.highlighter,
      chipColor: ramps.annotYellow,
      iconColor: iconColor,
      author: author,
      time: '10:12',
      quote: '“her ayın beşinci gününe kadar”',
      text: 'Ödeme günü beşi yerine onu olabilir mi?',
      replies: replies,
      expanded: expanded,
      composing: composing,
      resolvedBy: resolvedBy,
      onPressed: onPressed,
      onResolve: onResolve,
      onReply: onReply,
      onReopen: onReopen,
      repliesLabel: '2 replies',
      replyPlaceholder: 'Reply',
      semanticLabel: '$author, highlight on page 1, 2 replies',
      resolveLabel: 'Resolve',
      replyLabel: 'Reply',
      reopenLabel: 'Reopen',
    ),
  );

  BoxDecoration frameOf(WidgetTester tester) =>
      tester.widget<Container>(frame).decoration! as BoxDecoration;

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('CommentCard look', () {
    testWidgets('collapsed: raised card, subtle hairline, the replies count', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(card(replies: replies)));
      final box = frameOf(tester);
      expect(box.color, light.surfaceRaised);
      expect((box.border! as Border).top.color, light.borderSubtle);
      expect(box.boxShadow, isNull);
      expect(find.text('2 replies'), findsOneWidget);
      expect(find.text('Olur, 10’u yazalım.'), findsNothing);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('10:12'), findsOneWidget);
      final chipBox =
          tester.widget<Container>(chip).decoration! as BoxDecoration;
      expect(chipBox.color, ramps.annotYellow);
      expect(tester.getSize(chip), const Size.square(CommentCard.chipSize));
      final glyph = tester.widget<Icon>(
        find.descendant(of: chip, matching: find.byType(Icon)),
      );
      expect(glyph.color, ramps.paper900);
      expect(glyph.size, CommentCard.chipIconSize);
    });

    testWidgets('the quote is one line in the document face', (tester) async {
      await tester.pumpWidget(componentHost(card()));
      final quote = tester.widget<Text>(
        find.text('“her ayın beşinci gününe kadar”'),
      );
      expect(quote.maxLines, 1);
      expect(quote.style!.fontFamily, FermanTypeTokens.fontDocSample.family);
      expect(quote.style!.fontSize, CommentCard.quoteFontSize);
      expect(quote.style!.color, light.textSecondary);
    });

    testWidgets('icon colour override', (tester) async {
      await tester.pumpWidget(componentHost(card(iconColor: ramps.annotRed)));
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: chip, matching: find.byType(Icon)),
            )
            .color,
        ramps.annotRed,
      );
    });

    testWidgets('expanded: accent hairline and ring, replies shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(card(replies: replies, expanded: true)),
      );
      final box = frameOf(tester);
      expect((box.border! as Border).top.color, light.accent);
      expect(box.boxShadow, [BoxShadow(color: light.accent, spreadRadius: 1)]);
      expect(find.text('Olur, 10’u yazalım.'), findsOneWidget);
      expect(find.text('2 replies'), findsNothing);
    });

    testWidgets('resolved: faded, a green check and the Reopen footer', (
      tester,
    ) async {
      var reopened = 0;
      await tester.pumpWidget(
        componentHost(
          card(
            resolvedBy: 'Resolved by Mert Kaya · 11:06',
            onReopen: () => reopened++,
          ),
        ),
      );
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        CommentCard.resolvedOpacity,
      );
      final check = tester.widget<Icon>(
        find.byWidgetPredicate(
          (w) => w is Icon && w.name == IconName.circleCheck,
        ),
      );
      expect(check.color, light.successSolid);
      expect(find.text('Resolved by Mert Kaya · 11:06'), findsOneWidget);
      await tester.tap(find.text('Reopen'));
      expect(reopened, 1);
    });

    testWidgets('dark theme takes the dark surface', (tester) async {
      await tester.pumpWidget(
        componentHost(card(), brightness: Brightness.dark),
      );
      expect(frameOf(tester).color, FermanColorTokens.dark.surfaceRaised);
    });

    testWidgets('right to left: replies indent at the start (right)', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          card(replies: replies, expanded: true),
          textDirection: TextDirection.rtl,
        ),
      );
      final cardRight = tester.getTopRight(frame).dx;
      final replyRight = tester.getTopRight(find.text('Güncelliyorum.')).dx;
      // 1 px border + 10 px padding + 10 px indent.
      expect(cardRight - replyRight, closeTo(21, 0.5));
    });

    testWidgets('the content sits inside the border and the padding', (
      tester,
    ) async {
      // Unbounded height, as in the scrolling comments list.
      await tester.pumpWidget(
        componentHost(
          Column(mainAxisSize: MainAxisSize.min, children: [card()]),
        ),
      );
      final card0 = tester.getRect(frame);
      final chip0 = tester.getRect(chip);
      // `border: 1px` + `padding: 9px 10px`.
      expect(chip0.top - card0.top, CommentCard.paddingY + 1);
      expect(chip0.left - card0.left, FermanSpaceTokens.space2_5 + 1);
      final text = tester.getRect(
        find.text('Ödeme günü beşi yerine onu olabilir mi?'),
      );
      expect(card0.bottom - text.bottom, CommentCard.paddingY + 1);
    });
  });

  group('CommentCard compose', () {
    testWidgets('composing: the field, Resolve and Reply', (tester) async {
      var resolved = 0;
      final sent = <String>[];
      await tester.pumpWidget(
        componentHost(
          card(
            expanded: true,
            composing: true,
            onResolve: () => resolved++,
            onReply: sent.add,
          ),
        ),
      );
      expect(find.byType(EditableText), findsOneWidget);
      Button reply() => tester.widget<Button>(
        find.ancestor(
          of: find.text('Reply').last,
          matching: find.byType(Button),
        ),
      );
      expect(reply().disabled, isTrue);
      await tester.tap(find.text('Resolve'));
      expect(resolved, 1);
      await tester.enterText(find.byType(EditableText), 'Teşekkürler');
      await tester.pump();
      expect(reply().disabled, isFalse);
      await tester.tap(
        find.ancestor(
          of: find.text('Reply').last,
          matching: find.byType(Button),
        ),
      );
      await tester.pump();
      expect(sent, ['Teşekkürler']);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
    });

    testWidgets('sending keeps focus in the reply field', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        componentHost(
          card(
            expanded: true,
            composing: true,
            onResolve: () {},
            onReply: sent.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      FocusNode field() =>
          tester.widget<EditableText>(find.byType(EditableText)).focusNode;
      // Enter in the field.
      await tester.enterText(find.byType(EditableText), 'Teşekkürler');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(sent, ['Teşekkürler']);
      expect(field().hasFocus, isTrue);
      // The Reply button, from the keyboard: it turns disabled, and focus
      // goes back to the field, not to Resolve.
      await tester.enterText(find.byType(EditableText), 'Bir de bu.');
      await tester.pump();
      final reply = find.descendant(
        of: find.ancestor(
          of: find.text('Reply').last,
          matching: find.byType(Button),
        ),
        matching: find.text('Reply'),
      );
      Focus.of(tester.element(reply)).requestFocus();
      await tester.pumpAndSettle();
      expect(field().hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sent, ['Teşekkürler', 'Bir de bu.']);
      expect(field().hasFocus, isTrue);
      expect(Focus.of(tester.element(find.text('Resolve'))).hasFocus, isFalse);
    });

    testWidgets('composing needs an expanded card', (tester) async {
      await tester.pumpWidget(componentHost(card(composing: true)));
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('Space typed in the field does not press the card', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(
        componentHost(
          card(
            expanded: true,
            composing: true,
            onPressed: () => presses++,
            onReply: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 0);
    });
  });

  group('CommentCard keyboard and semantics', () {
    testWidgets('a click, Enter and Space press the card', (tester) async {
      var presses = 0;
      await tester.pumpWidget(componentHost(card(onPressed: () => presses++)));
      await tester.tap(find.text('Ödeme günü beşi yerine onu olabilir mi?'));
      expect(presses, 1);
      Focus.of(tester.element(frame)).requestFocus();
      await tester.pumpAndSettle();
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 3);
    });

    testWidgets('ArrowDown and ArrowUp move between cards', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              card(author: 'A', onPressed: () {}),
              card(author: 'B', onPressed: () {}),
            ],
          ),
        ),
      );
      final first = Focus.of(tester.element(frame.first));
      final second = Focus.of(tester.element(frame.last));
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(second.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(second.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(first.hasFocus, isTrue);
    });

    testWidgets('the arrows stop at the first and last card', (tester) async {
      final above = FocusNode();
      final below = FocusNode();
      addTearDown(above.dispose);
      addTearDown(below.dispose);
      // The app's own shortcuts: an unhandled arrow moves focus
      // directionally (DirectionalFocusIntent).
      await tester.pumpWidget(
        componentHost(
          Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Focus(
                    focusNode: above,
                    child: const SizedBox(width: 40, height: 20),
                  ),
                  card(author: 'A', onPressed: () {}),
                  card(author: 'B', onPressed: () {}),
                  Focus(
                    focusNode: below,
                    child: const SizedBox(width: 40, height: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final first = Focus.of(tester.element(frame.first));
      final last = Focus.of(tester.element(frame.last))..requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(last.hasFocus, isTrue);
      expect(below.hasFocus, isFalse);
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(first.hasFocus, isTrue);
      expect(above.hasFocus, isFalse);
    });

    testWidgets('the arrows scroll the focused card into view', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            height: 200,
            child: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  for (var i = 0; i < 6; i++)
                    card(author: 'Kişi $i', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      bool focusedInView() {
        final rect = FocusManager.instance.primaryFocus!.rect;
        return rect.top >= viewport.top - 0.5 &&
            rect.bottom <= viewport.bottom + 0.5;
      }

      Focus.of(tester.element(frame.first)).requestFocus();
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focusedInView(), isTrue);
      }
      expect(controller.offset, greaterThan(0));
      expect(Focus.of(tester.element(frame.last)).hasFocus, isTrue);
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(focusedInView(), isTrue);
      }
      expect(controller.offset, 0);
    });

    testWidgets('semantics: a button with the summary label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(card(onPressed: () {})));
      expect(
        tester.getSemantics(frame),
        isSemantics(
          label: 'Ayşe Yılmaz, highlight on page 1, 2 replies',
          isButton: true,
        ),
      );
      handle.dispose();
    });
  });
}
