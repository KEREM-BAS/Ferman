import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/document_banners.dart';
import 'package:ferman/features/shell/document_properties.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';
import 'document_banners_test.dart' show restricted;

const PageInfo _a4 = PageInfo(width: 595, height: 842);

/// a2-7's rental contract, signed on page 3.
const OpenedDocument kira = OpenedDocument(
  id: 7,
  pages: [_a4, _a4, _a4],
  version: '1.7',
  fileSize: 284000,
  info: DocumentInfo(
    title: 'Konut Kira Sözleşmesi',
    author: 'Mert Kaya',
    creator: 'Writer',
    producer: 'LibreOffice 24.8',
  ),
  tagged: true,
  fonts: [
    FontEntry(name: 'IBM Plex Serif', kind: FontType.trueType, embedded: true),
    FontEntry(
      name: 'Garamond Premier Pro',
      kind: FontType.type1,
      embedded: true,
      subset: true,
    ),
    FontEntry(name: 'Helvetica', kind: FontType.type1),
  ],
  signatures: [
    Signature(field: 'Kiraci', signed: true, page: 2),
    Signature(field: 'Kefil'),
  ],
  scripts: 1,
);

Future<ProviderContainer> open(
  WidgetTester tester,
  Map<String, OpenedDocument> documents, {
  Map<int, List<FontCoverage>> fontCoverages = const {},
}) async {
  final engine = FakeEngineService(
    documents: documents,
    ownerPasswords: {restricted.id: 'Kaya-Moda-18'},
    fontCoverages: fontCoverages,
  );
  await pumpFermanApp(
    tester,
    engine: engine,
    home: '/home/mert',
    picker: FakeFilePickerService(picked: documents.keys.toList()),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(FmStart)),
  );
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  return container;
}

Future<void> controlD(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Finder inPanel(Finder finder) =>
    find.descendant(of: find.byType(FmDocPanel), matching: finder);

Finder inDialog(Finder finder) => find.descendant(
  of: find.byType(DocumentPropertiesDialog),
  matching: finder,
);

Finder inTabs(String label) => find.descendant(
  of: find.byType(SegmentedControl<PropertiesTab>),
  matching: find.text(label),
);

/// The label of the badge in the row that also shows [row].
String badgeBeside(WidgetTester tester, String row) {
  final rowFinder = find.ancestor(
    of: find.text(row),
    matching: find.byType(Row),
  );
  return tester
      .widget<Badge>(
        find.descendant(of: rowFinder.first, matching: find.byType(Badge)),
      )
      .label;
}

void main() {
  testWidgets("Edit mode's panel shows a3-1a's tips and, with edits, their "
      'number and Review; the tips leave no File section', (tester) async {
    final container = await open(tester, {'/home/mert/kira.pdf': kira});
    container.read(shellModeProvider.notifier).select(FermanMode.edit);
    await tester.pumpAndSettle();
    expect(
      inPanel(
        find.text(
          'Click any text to select its block. Click again to place the '
          'caret.',
        ),
      ),
      findsOne,
    );
    expect(inPanel(find.byType(Kbd)), findsOne);
    expect(inPanel(find.text('in this session')), findsNothing);

    final documents = container.read(shellDocumentsProvider.notifier);
    final tab = container.read(shellDocumentsProvider).active!;
    documents.replace(tab.path!, tab.withSave(SaveState.unsaved, editCount: 3));
    await tester.pumpAndSettle();
    expect(inPanel(find.text('3 edits')), findsOne);
    expect(inPanel(find.text('in this session')), findsOne);
    final review = tester.widget<Button>(
      find.ancestor(
        of: inPanel(find.text('Review')),
        matching: find.byType(Button),
      ),
    );
    expect(review.onPressed, isNotNull);
    expect(review.disabledReason, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('the zoom field takes a typed number; the menu stays (B127)', (
    tester,
  ) async {
    final container = await open(tester, {'/home/mert/kira.pdf': kira});
    final field = find.byWidgetPredicate(
      (widget) => widget is Select<String> && widget.semanticLabel == 'Zoom',
    );
    double zoom() => container.read(viewerProvider)!.zoom;

    Future<void> type(String text) async {
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.text('Marquee zoom'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(input).controller.text, '1');
      await tester.enterText(input, text);
    }

    await type('150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(zoom(), closeTo(1.5, 0.0001));

    await type('%250');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(zoom(), closeTo(2.5, 0.0001));

    // Past the limits it stops at them.
    await type('90000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(zoom(), closeTo(16, 0.0001));

    // Not a number, and Escape: the zoom stays.
    await type('abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(zoom(), closeTo(16, 0.0001));
    await type('75');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(zoom(), closeTo(16, 0.0001));
    expect(
      find.descendant(of: field, matching: find.byType(EditableText)),
      findsNothing,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('the right panel shows the file, its fonts and its security; '
      'Edit mode only the fonts (FmDocPanel)', (tester) async {
    final container = await open(tester, {
      '/home/mert/Belgeler/Ev/Kira sözleşmesi.pdf': kira,
    });
    expect(inPanel(find.text('File')), findsOne);
    expect(inPanel(find.text(bidiIsolate('3'))), findsOne);
    expect(inPanel(find.textContaining('A4 · ')), findsOne);
    expect(inPanel(find.text(bidiIsolate('284\u00a0KB'))), findsOne);
    expect(inPanel(find.text(bidiIsolate('1.7'))), findsOne);
    expect(
      inPanel(
        find.text(
          bidiIsolate(
            '~/Belgeler/Ev/Kira sözleşmesi.pdf'.split('').join('\u200B'),
          ),
        ),
      ),
      findsOne,
    );
    expect(badgeBeside(tester, 'IBM Plex Serif'), 'Embedded');
    expect(badgeBeside(tester, 'Garamond Premier Pro'), 'Partial');
    expect(
      inPanel(find.text('Subset: only characters already in the file.')),
      findsOne,
    );
    expect(badgeBeside(tester, 'Helvetica'), 'Not embedded');
    expect(inPanel(find.text('No password')), findsOne);
    expect(inPanel(find.text('1 signature, page 3')), findsOne);

    container.read(shellModeProvider.notifier).select(FermanMode.edit);
    await tester.pumpAndSettle();
    expect(inPanel(find.text('Fonts in this document')), findsOne);
    expect(inPanel(find.text('File')), findsNothing);
    expect(inPanel(find.text('Security')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('the fonts name the substitute and the letters a subset lacks '
      '(a2-7, B122)', (tester) async {
    await open(
      tester,
      {'/home/mert/Kira sözleşmesi.pdf': kira},
      fontCoverages: {
        kira.id: const [
          FontCoverage(name: 'Helvetica', shownAs: 'IBM Plex Sans'),
          FontCoverage(name: 'Garamond Premier Pro', missingLetters: 'ğĞ'),
        ],
      },
    );
    await controlD(tester);
    final note = bidiIsolate('‘ğ’, ‘Ğ’');
    expect(
      inDialog(
        find.text(
          'Only the characters already used. '
          'Typing $note needs a substitute.',
        ),
      ),
      findsOne,
    );
    expect(
      inDialog(
        find.text('Ferman is showing ${bidiIsolate('IBM Plex Sans')} instead.'),
      ),
      findsOne,
    );
  });

  testWidgets('a2-7: five missing letters name four and go on', (tester) async {
    await open(
      tester,
      {'/home/mert/Kira sözleşmesi.pdf': kira},
      fontCoverages: {
        kira.id: const [
          FontCoverage(name: 'Garamond Premier Pro', missingLetters: 'abcde'),
        ],
      },
    );
    await controlD(tester);
    final note = bidiIsolate('‘a’, ‘b’, ‘c’, ‘d’ …');
    expect(
      inDialog(
        find.text(
          'Only the characters already used. '
          'Typing $note needs a substitute.',
        ),
      ),
      findsOne,
    );
  });

  testWidgets('Ctrl+D shows a2-7: the summary, the fonts and the Advanced '
      "tab's scripts row; Done closes it", (tester) async {
    await open(tester, {'/home/mert/Kira sözleşmesi.pdf': kira});
    await controlD(tester);
    expect(find.byType(DocumentPropertiesDialog), findsOne);
    expect(
      find.textContaining('Kira sözleşmesi.pdf\u2069 — Properties'),
      findsOne,
    );
    for (final text in [
      'Konut Kira Sözleşmesi',
      'Mert Kaya',
      '1.7 (Acrobat 8.x)',
      'LibreOffice 24.8',
      'No password · 1 signature',
    ]) {
      expect(inDialog(find.text(bidiIsolate(text))), findsOne, reason: text);
    }
    expect(inDialog(find.text('TrueType')), findsOne);
    expect(inDialog(find.text('Only the characters already used.')), findsOne);
    expect(inDialog(find.text('Type 1')), findsNWidgets(2));
    // The subject, keywords and dates the file does not give.
    expect(inDialog(find.text(bidiIsolate('None'))), findsNWidgets(4));
    expect(inDialog(find.text('FONT')), findsOne);

    await tester.tap(inTabs('Advanced'));
    await tester.pumpAndSettle();
    expect(
      inDialog(
        find.text(
          bidiIsolate(
            'A script that runs when the file opens. Ferman never runs it.',
          ),
        ),
      ),
      findsOne,
    );

    await tester.tap(inDialog(find.text('Done')));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentPropertiesDialog), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("a restricted document's Security tab lists each permission "
      'and hands over to the owner-password dialog (a2-10b)', (tester) async {
    await open(tester, {'/docs/kira-tr-restricted.pdf': restricted});
    await controlD(tester);
    await tester.tap(inTabs('Security'));
    await tester.pumpAndSettle();
    expect(
      inDialog(find.text(bidiIsolate('AES-128 · owner password'))),
      findsOne,
    );
    expect(inDialog(find.text('PERMISSIONS')), findsOne);
    expect(badgeBeside(tester, 'Printing'), 'Allowed, high quality');
    expect(badgeBeside(tester, 'Changing the document'), 'Not allowed');
    expect(badgeBeside(tester, 'Signing'), 'Not allowed');
    expect(badgeBeside(tester, 'Copying text and images'), 'Not allowed');
    expect(badgeBeside(tester, 'Text access for screen readers'), 'Allowed');
    expect(badgeBeside(tester, 'Assembling pages'), 'Allowed');

    await tester.tap(inDialog(find.text('Unlock with owner password…')));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentPropertiesDialog), findsNothing);
    expect(find.byType(OwnerUnlockDialog), findsOne);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Organize keeps Ctrl+D for Duplicate', (tester) async {
    final container = await open(tester, {'/docs/kira.pdf': kira});
    container.read(shellModeProvider.notifier).select(FermanMode.organize);
    await tester.pumpAndSettle();
    await controlD(tester);
    expect(find.byType(DocumentPropertiesDialog), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
