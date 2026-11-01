import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/document_banners.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
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

Future<ProviderContainer> openAll(
  WidgetTester tester,
  FakeEngineService engine,
) async {
  await pumpFermanApp(
    tester,
    engine: engine,
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
}
