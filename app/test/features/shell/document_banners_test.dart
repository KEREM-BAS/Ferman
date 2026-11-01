import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/document_banners.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../../helpers/recording_file_access.dart';
import '../onboarding/ferman_app_harness.dart';

const PageInfo _a4 = PageInfo(width: 595, height: 842);

/// kira-tr-restricted's permissions: read and print only.
const OpenedDocument restricted = OpenedDocument(
  id: 1,
  pages: [_a4],
  security: Security(
    method: EncryptionMethod.aes128,
    keyBits: 128,
    permissions: DocumentPermissions(
      modify: false,
      annotate: false,
      fillForms: false,
      copy: false,
    ),
    restricted: true,
  ),
);

/// Printing forbidden too: a2-10a's sentence would be false.
const OpenedDocument noPrinting = OpenedDocument(
  id: 2,
  pages: [_a4],
  security: Security(
    method: EncryptionMethod.rc4,
    keyBits: 40,
    permissions: DocumentPermissions(print: false, copy: false),
    restricted: true,
  ),
);

const OpenedDocument scripted = OpenedDocument(id: 3, pages: [_a4], scripts: 2);

/// kira-tr-damaged as ferman-core repairs it: a rebuilt table and a stream
/// read to its end.
const OpenedDocument repaired = OpenedDocument(
  id: 4,
  pages: [_a4, _a4, _a4],
  readOnly: ReadOnlyReason.repaired,
  repairs: [
    RepairFix(kind: RepairKind.crossReferenceRebuilt, count: 48),
    RepairFix(kind: RepairKind.streamLengthsCorrected, count: 1),
  ],
);

const OpenedDocument xfa = OpenedDocument(
  id: 5,
  pages: [_a4],
  readOnly: ReadOnlyReason.xfaOnly,
);

const OpenedDocument disagreeing = OpenedDocument(
  id: 6,
  pages: [_a4],
  readOnly: ReadOnlyReason.parsersDisagree,
);

Future<ProviderContainer> openAll(
  WidgetTester tester,
  FakeEngineService engine, {
  FileAccess fileAccess = const NoFileAccess(),
}) async {
  await pumpFermanApp(
    tester,
    engine: engine,
    fileAccess: fileAccess,
    picker: FakeFilePickerService(picked: engine.documents.keys.toList()),
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

void main() {
  testWidgets("a restricted document shows the shield and a2-10a's bar; the "
      'owner password lifts both, a wrong one asks again (G106)', (
    tester,
  ) async {
    final engine = FakeEngineService(
      documents: {'/docs/kira-tr-restricted.pdf': restricted},
      ownerPasswords: {restricted.id: 'Kaya-Moda-18'},
    );
    final container = await openAll(tester, engine);
    ShellDocument active() => container.read(shellDocumentsProvider).active!;
    expect(active().icon, IconName.shield);
    expect(find.text('The author restricted this document.'), findsOne);
    expect(
      find.text(
        'You can read and print it. Editing, comments and form filling '
        'are turned off.',
      ),
      findsOne,
    );

    // Cancel keeps the restriction.
    await tester.tap(find.text('Unlock with owner password…'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerUnlockDialog), findsOne);
    expect(find.byType(Scrim), findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerUnlockDialog), findsNothing);
    expect(find.text('The author restricted this document.'), findsOne);

    await tester.tap(find.text('Unlock with owner password…'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(EditableText), 'kaya');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.textContaining('That password didn’t work.'), findsOne);
    expect(engine.ownerUnlocked, isEmpty);

    await tester.enterText(find.byType(EditableText), 'Kaya-Moda-18');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(OwnerUnlockDialog), findsNothing);
    expect(find.text('The author restricted this document.'), findsNothing);
    expect(engine.ownerUnlocked, {restricted.id});
    expect(active().icon, IconName.fileText);
    expect(active().document!.security!.owner, isTrue);
    expect(active().document!.id, restricted.id);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("permissions the board's sentence does not describe get the "
      'neutral one', (tester) async {
    await openAll(
      tester,
      FakeEngineService(documents: {'/docs/no-print.pdf': noPrinting}),
    );
    expect(
      find.text('You can read it. The author turned some actions off.'),
      findsOne,
    );
    expect(find.textContaining('read and print'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a document with scripts says so until dismissed, also after '
      'another tab showed (G100)', (tester) async {
    final container = await openAll(
      tester,
      FakeEngineService(
        documents: {
          '/docs/js.pdf': scripted,
          '/docs/kira-tr-restricted.pdf': restricted,
        },
      ),
    );
    final documents = container.read(shellDocumentsProvider.notifier)
      ..activate(0);
    await tester.pumpAndSettle();
    expect(find.text('This document contains 2 scripts.'), findsOne);
    expect(find.text('Ferman never runs scripts; other apps might.'), findsOne);
    // The restricted bar is the other document's.
    expect(find.text('The author restricted this document.'), findsNothing);
    expect(
      container.read(shellDocumentsProvider).active!.icon,
      isNot(IconName.shield),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(Banner),
        matching: find.bySemanticsLabel('Dismiss'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This document contains 2 scripts.'), findsNothing);
    documents.activate(1);
    await tester.pumpAndSettle();
    expect(find.text('The author restricted this document.'), findsOne);
    documents.activate(0);
    await tester.pumpAndSettle();
    expect(find.text('This document contains 2 scripts.'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("a repaired document shows a1-9's bar with the engine's "
      'repairs, and Save repaired copy… disabled (B103)', (tester) async {
    final container = await openAll(
      tester,
      FakeEngineService(documents: {'/docs/kira-tr-damaged.pdf': repaired}),
    );
    final tab = container.read(shellDocumentsProvider).active!;
    expect(tab.icon, IconName.wrench);
    expect(tab.saveState, SaveState.readOnly);
    expect(find.text('Ferman repaired this file.'), findsOne);
    expect(
      find.text(
        '2 problems were fixed in this copy. The original stays as it was '
        'until you save.',
      ),
      findsOne,
    );
    final save = tester.widget<Button>(
      find.widgetWithText(Button, 'Save repaired copy…'),
    );
    expect(save.disabled, isTrue);
    expect(save.onPressed, isNull);
    expect(save.disabledReason, 'Available in a future version');
    expect(Feature.saveRepairedCopy.backlog, 'B103');

    // Details lists the repairs; Copy details copies them.
    expect(find.text('What Ferman repaired'), findsNothing);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('What Ferman repaired'), findsOne);
    expect(find.text('The cross-reference table was broken'), findsOne);
    expect(
      find.text(
        'Rebuilt from the 48 objects found in the file. All 3 pages are '
        'present.',
      ),
      findsOne,
    );
    expect(find.text('1 stream had the wrong length'), findsOne);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Copy details'));
    await tester.pump();
    expect(copied, startsWith('The cross-reference table was broken. '));
    expect(copied, contains('\n1 stream had the wrong length. '));

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('What Ferman repaired'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('unreadable objects are listed but not counted as fixed; '
      'with no repairs listed Details hides; closing Details returns focus '
      'to it', (tester) async {
    const partly = OpenedDocument(
      id: 7,
      pages: [_a4],
      readOnly: ReadOnlyReason.repaired,
      repairs: [
        RepairFix(kind: RepairKind.trailerRebuilt, count: 1),
        RepairFix(kind: RepairKind.objectsUnreadable, count: 2),
      ],
    );
    await openAll(
      tester,
      FakeEngineService(documents: {'/docs/partly.pdf': partly}),
    );
    expect(find.textContaining('1 problem was fixed'), findsOne);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.name == IconName.triangleAlert,
      ),
      findsOne,
    );
    // Escape from inside the popover closes it, and focus goes back to
    // Details.
    Focus.of(tester.element(find.text('Copy details'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('What Ferman repaired'), findsNothing);
    expect(Focus.of(tester.element(find.text('Details'))).hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a repaired document with no repairs listed shows no Details', (
    tester,
  ) async {
    const bare = OpenedDocument(
      id: 8,
      pages: [_a4],
      readOnly: ReadOnlyReason.repaired,
    );
    await openAll(
      tester,
      FakeEngineService(documents: {'/docs/bare.pdf': bare}),
    );
    expect(find.text('Ferman repaired this file.'), findsOne);
    expect(find.text('Details'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("an XFA-only form opens read-only with a11-7c's bar and Show "
      'in folder', (tester) async {
    final files = RecordingFileAccess();
    final container = await openAll(
      tester,
      FakeEngineService(documents: {'/docs/xfa-visa.pdf': xfa}),
      fileAccess: files,
    );
    final tab = container.read(shellDocumentsProvider).active!;
    expect(tab.icon, IconName.fileX);
    expect(tab.saveState, SaveState.readOnly);
    expect(
      find.text('This is an XFA form, which Ferman can’t show.'),
      findsOne,
    );
    expect(
      find.text(
        'XFA is a discontinued Adobe format. Open it in Adobe Acrobat '
        'Reader, or ask the sender for a regular PDF.',
      ),
      findsOne,
    );
    expect(tester.widget<Banner>(find.byType(Banner)).tone, BannerTone.warning);
    await tester.tap(find.widgetWithText(Button, 'Show in folder'));
    await tester.pump();
    expect(files.shown, ['/docs/xfa-visa.pdf']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a document the two parsers disagree on opens read-only with '
      "G102's notice", (tester) async {
    final container = await openAll(
      tester,
      FakeEngineService(documents: {'/docs/crafted.pdf': disagreeing}),
    );
    final tab = container.read(shellDocumentsProvider).active!;
    expect(tab.icon, IconName.lock);
    expect(tab.saveState, SaveState.readOnly);
    expect(
      find.text('Ferman opened “\u2068crafted.pdf\u2069” read-only.'),
      findsOne,
    );
    expect(
      find.text(
        'Parts of this file don’t match each other, which can mean it is '
        'damaged. You can read it as usual.',
      ),
      findsOne,
    );
    final bar = tester.widget<Banner>(find.byType(Banner));
    expect(bar.actions, isEmpty);
    expect(bar.icon, IconName.lock);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
