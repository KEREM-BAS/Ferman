import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/annotations/sticky_note.dart';
import 'package:ferman/design/components/forms/text_field.dart';
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
      expect(box.boxShadow, StickyNote.pinShadow);
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
      expect(box.boxShadow, [
        BoxShadow(color: ramps.ink500, spreadRadius: 4),
        const BoxShadow(color: StickyNote.pinFocusGap, spreadRadius: 2),
      ]);
    });
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
      await tester.enterText(find.byType(EditableText), 'Tamam.');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(sent, ['Tamam.']);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
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
