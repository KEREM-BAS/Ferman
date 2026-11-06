import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/block_language.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_status_bar.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';
import 'editor_test.dart' show document, pumps;

TextBlock _block(
  int id,
  Rect frame,
  String text, {
  BlockAlignment alignment = BlockAlignment.left,
  String? language,
}) => TextBlock(
  id: id,
  frame: frame,
  alignment: alignment,
  language: language,
  lines: [
    TextLine(
      text: text,
      bbox: frame,
      baselineStart: frame.bottomLeft,
      baselineEnd: frame.bottomRight,
    ),
  ],
);

final PageBlocks _page = PageBlocks(
  blocks: [
    _block(
      1,
      const Rect.fromLTRB(72, 100, 400, 124),
      'Quote',
      language: 'en-GB',
    ),
    _block(
      2,
      const Rect.fromLTRB(300, 300, 400, 324),
      '1.250,00',
      alignment: BlockAlignment.right,
    ),
  ],
);

void main() {
  late FakeDesktopWindow window;
  late FakeEngineService engine;

  setUpAll(initializeRegionFormats);
  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<void> pumpEditor(WidgetTester tester) async {
    engine = FakeEngineService(
      documents: {'/tez.pdf': document},
      pageBlocks: {0: _page},
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
            name: 'tez.pdf',
            path: '/tez.pdf',
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

  Future<void> click(WidgetTester tester, Offset point) async {
    final view = containerOf(tester).read(viewerProvider)!;
    final at =
        tester.getTopLeft(find.byType(DocumentView)) +
        view.placement.rects.first!.topLeft -
        view.offset +
        point * view.scale;
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

  testWidgets('the block being edited shows its language in the panel and '
      'the status bar, with spell-check disabled', (tester) async {
    await pumpEditor(tester);
    expect(find.byType(BlockLanguageSection), findsNothing);
    await click(tester, const Offset(100, 110));
    expect(find.byType(BlockLanguageSection), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ShellStatusBar),
        matching: find.text('English (United Kingdom)'),
      ),
      findsOneWidget,
    );
    final select = tester.widget<Select<String>>(find.byType(Select<String>));
    expect(select.value, 'en');
    final context = tester.element(find.byType(BlockLanguageSection));
    final switches = tester.widgetList<Switch>(
      find.descendant(
        of: find.byType(BlockLanguageSection),
        matching: find.byType(Switch),
      ),
    );
    expect(switches, hasLength(2));
    for (final toggle in switches) {
      expect(toggle.disabled, isTrue);
      expect(toggle.disabledReason, Feature.spellCheck.disabledReason(context));
    }
  });

  testWidgets('a language picked commits as one step, the editor stays open '
      'and the page has it', (tester) async {
    await pumpEditor(tester);
    await click(tester, const Offset(100, 110));
    final select = tester.widget<Select<String>>(find.byType(Select<String>));
    expect(select.onChanged, isNotNull);
    await tester.tap(find.byType(Select<String>));
    await pumps(tester);
    expect(editor(tester).active, isNotNull, reason: 'the focus moved here');
    await tester.tap(find.text('Turkish').last);
    await pumps(tester);
    expect(editor(tester).language, 'tr');
    expect(editor(tester).active, isNotNull);
    expect(
      find.descendant(
        of: find.byType(ShellStatusBar),
        matching: find.text('Turkish'),
      ),
      findsOneWidget,
    );

    await containerOf(tester).read(documentEditorProvider.notifier).commit();
    await pumps(tester);
    final history = editor(tester).history;
    expect(history.steps, hasLength(1));
    expect(history.steps.single.name, 'Changed language · page 1');
    final blocks = await engine.textBlocks(document.id, 0);
    expect(blocks.blocks.first.language, 'tr');
    expect(blocks.blocks.last.language, isNull);
    expect(editor(tester).active?.block.language, 'tr');
  });

  testWidgets('a right-aligned cell keeps its edge in the field', (
    tester,
  ) async {
    await pumpEditor(tester);
    await click(tester, const Offset(350, 310));
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.textAlign, TextAlign.end);
    expect(field.textDirection, TextDirection.ltr);
    // No language known: the slot stays out and the select is empty.
    expect(editor(tester).language, isNull);
    expect(
      tester.widget<Select<String>>(find.byType(Select<String>)).value,
      isNull,
    );
  });

  testWidgets('names follow the UI language and a tag without a name shows '
      'itself', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('tr'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    expect(blockLanguageName(context, 'en-GB'), 'İngilizce (Birleşik Krallık)');
    expect(blockLanguageName(context, 'TR-tr'), 'Türkçe (Türkiye)');
    expect(blockLanguageName(context, 'de'), 'Almanca');
    expect(blockLanguageName(context, 'fr-FR'), 'fr-FR');
  });
}
