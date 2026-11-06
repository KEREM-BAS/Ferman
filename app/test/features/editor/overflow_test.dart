import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/block_editor.dart';
import 'package:ferman/features/editor/edit_callouts.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';
import 'editor_test.dart' show document, page, pumps;

void main() {
  late FakeDesktopWindow window;
  late FakeEngineService engine;

  setUpAll(initializeRegionFormats);
  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  /// Opens kira.pdf in Edit mode; its paragraph (block 3) overflows as
  /// a3-18 draws it, and block 1 depends on it.
  Future<void> pumpEditor(WidgetTester tester) async {
    engine = FakeEngineService(
      documents: {'/kira.pdf': document},
      pageBlocks: {0: page},
      overflows: const {3: FakeEngineService.ibanOverflow},
      dependents: const {
        3: [1],
      },
    );
    await pumpShell(
      tester,
      shellHost(
        window: window,
        regionCode: 'GB',
        samples: false,
        overrides: [engineServiceProvider.overrideWithValue(engine)],
      ),
    );
    containerOf(tester)
        .read(shellDocumentsProvider.notifier)
        .add(
          const ShellDocument(
            name: 'kira.pdf',
            path: '/kira.pdf',
            document: document,
            saveState: SaveState.saved,
            pageCount: 1,
          ),
        );
    containerOf(tester)
        .read(shellModeProvider.notifier)
        .select(FermanMode.edit);
    await settle(tester);
  }

  Future<void> clickParagraph(WidgetTester tester) async {
    final view = containerOf(tester).read(viewerProvider)!;
    final rect = view.placement.rects.first!;
    final at =
        tester.getTopLeft(find.byType(DocumentView)) +
        rect.topLeft -
        view.offset +
        const Offset(100, 306) * view.scale;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getTopLeft(find.byType(DocumentView)),
    );
    await mouse.moveTo(at);
    await tester.pump();
    await tester.pump();
    await mouse.down(at);
    await mouse.up();
    await mouse.removePointer();
    await pumps(tester);
  }

  EditorState editor(WidgetTester tester) =>
      containerOf(tester).read(documentEditorProvider);

  Button choice(WidgetTester tester, String label) => tester.widget<Button>(
    find.ancestor(of: find.text(label), matching: find.byType(Button)),
  );

  Future<void> typeLonger(WidgetTester tester) async {
    await clickParagraph(tester);
    await tester.enterText(
      find.byType(EditableText),
      'Birinci satır biraz daha uzun\nİkinci satır\nÜçüncü satır',
    );
    await pumps(tester);
  }

  testWidgets('text that no longer fits offers the three choices with their '
      'amounts, and Extend is disabled with its reason', (tester) async {
    await pumpEditor(tester);
    await typeLonger(tester);
    expect(find.byType(EditCallouts), findsOneWidget);
    expect(find.text('Text doesn’t fit'), findsOneWidget);
    expect(
      find.text('The edited paragraph needs 1 more line than its frame.'),
      findsOneWidget,
    );
    expect(choice(tester, 'Extend block by 1 line').disabled, isTrue);
    expect(
      find.text('The \u2068IBAN\u2069 line sits right below this block.'),
      findsOneWidget,
    );
    final tighten = choice(tester, 'Tighten spacing slightly (−0.6%)');
    expect(tighten.disabled, isFalse);
    expect(tighten.variant, ButtonVariant.primary);
    expect(choice(tester, 'Keep and warn').variant, ButtonVariant.ghost);
    expect(find.text('Edited'), findsOneWidget);
    // Keep and warn applies until another choice: the margin status and
    // the faded text under the amber edge.
    expect(find.text('+1 line hidden'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('BlockEditor.overflowEdge')),
      findsOneWidget,
    );

    await tester.tap(find.text('Tighten spacing slightly (−0.6%)'));
    await pumps(tester);
    expect(editor(tester).preview?.chosen, OverflowChoice.tighten);
    expect(find.text('Text doesn’t fit'), findsNothing);
    expect(find.text('+1 line hidden'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    expect(editor(tester).history.current, 1);
    expect(editor(tester).history.steps.single.hiddenLines, 0);
  });

  testWidgets('Keep and warn marks the page and its thumbnail, and a choice '
      'picked after the commit replaces that step', (tester) async {
    await pumpEditor(tester);
    await typeLonger(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    expect(find.byType(BlockEditor), findsNothing);
    expect(editor(tester).history.steps.single.hiddenLines, 1);
    expect(editor(tester).hidden.single.lines, 1);
    expect(find.text('+1 line hidden'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ThumbnailBadges &&
            widget.badges.contains(ThumbnailBadge.warnings),
      ),
      findsOneWidget,
    );
    // The panel still asks; a choice now rewrites the step.
    expect(find.text('Text doesn’t fit'), findsOneWidget);
    await tester.tap(find.text('Tighten spacing slightly (−0.6%)'));
    await pumps(tester);
    await pumps(tester);
    expect(editor(tester).history.current, 1);
    expect(editor(tester).history.steps.single.hiddenLines, 0);
    expect(editor(tester).hidden, isEmpty);
    expect(find.text('+1 line hidden'), findsNothing);
    expect(find.byType(ThumbnailBadges), findsNothing);
  });

  testWidgets('undo after Keep and warn drops the choices it asked for', (
    tester,
  ) async {
    await pumpEditor(tester);
    await typeLonger(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    expect(find.text('Text doesn’t fit'), findsOneWidget);
    await containerOf(tester).read(documentEditorProvider.notifier).undo();
    await pumps(tester);
    expect(editor(tester).history.current, 0);
    expect(editor(tester).asking, isNull);
    expect(find.text('Text doesn’t fit'), findsNothing);
    expect(find.text('+1 line hidden'), findsNothing);
  });

  testWidgets('a cell that depends on the edited one is tinted, with '
      '"Totals don’t update"', (tester) async {
    await pumpEditor(tester);
    await typeLonger(tester);
    expect(
      find.byKey(const ValueKey<String>('DocumentView.dependentCell')),
      findsOneWidget,
    );
    expect(find.text('Totals don’t update'), findsOneWidget);
    expect(choice(tester, 'Review the marked cell').onPressed, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    expect(
      find.byKey(const ValueKey<String>('DocumentView.dependentCell')),
      findsNothing,
    );
  });

  test('the amounts and reasons follow the region and the engine', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final tr = lookupAppLocalizations(const Locale('tr'));
    final us = RegionFormat.forRegion(Region.unitedStates);
    final turkiye = RegionFormat.forRegion(Region.turkiye);
    const plan = OverflowPlan(
      over: 2,
      keepHidden: 2,
      extendLines: 2,
      tightenShort: 1,
    );
    expect(
      overflowChoiceLabel(en, us, plan, OverflowChoice.extend),
      'Extend block by 2 lines',
    );
    expect(
      overflowChoiceLabel(
        tr,
        turkiye,
        FakeEngineService.ibanOverflow,
        OverflowChoice.tighten,
      ),
      'Aralığı biraz daralt (−%0,6)',
    );
    expect(
      overflowDisabledReason(en, us, plan, OverflowChoice.tighten),
      'Even the tightest allowed spacing leaves 1 line over.',
    );
    expect(overflowDisabledReason(en, us, plan, OverflowChoice.extend), isNull);
    // Tighten disabled names the cap that was not enough.
    expect(
      overflowChoiceLabel(en, us, plan, OverflowChoice.tighten),
      'Tighten spacing slightly (−2%)',
    );
    // A line that starts with a time is not a label.
    expect(
      overflowDisabledReason(
        en,
        us,
        const OverflowPlan(
          over: 1,
          keepHidden: 1,
          extendBlocked: ExtendBlocked(
            kind: ExtendBlockedKind.block,
            text: '12:30 toplantı',
          ),
        ),
        OverflowChoice.extend,
      ),
      'The line “\u206812:30 toplantı\u2069” sits right below this block.',
    );
    // Arabic is a3-18's own copy.
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(
      overflowDisabledReason(
        ar,
        us,
        FakeEngineService.ibanOverflow,
        OverflowChoice.extend,
      ),
      'سطر \u2068IBAN\u2069 يقع مباشرة أسفل هذه الكتلة.',
    );
    expect(
      overflowDisabledReason(
        en,
        us,
        const OverflowPlan(
          over: 1,
          keepHidden: 1,
          extendBlocked: ExtendBlocked(
            kind: ExtendBlockedKind.block,
            text: 'Kiraya veren, kira bedelini aldığında',
          ),
        ),
        OverflowChoice.extend,
      ),
      'The line “\u2068Kiraya veren, kira bedel…\u2069” sits right below '
      'this block.',
    );
    expect(
      overflowDisabledReason(
        tr,
        turkiye,
        const OverflowPlan(
          over: 1,
          keepHidden: 1,
          extendBlocked: ExtendBlocked(kind: ExtendBlockedKind.pageEdge),
        ),
        OverflowChoice.extend,
      ),
      'Blok uzarsa sayfanın kenarını aşar.',
    );
  });
}
