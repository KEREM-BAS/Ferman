import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/edit_callouts.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/font_picker_dialog.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';
import 'editor_test.dart' show document, page, pumps;

/// The fake, counting the texts that reach the engine.
class _CountingEngine extends FakeEngineService {
  new({super.missingGlyphs, super.sameFonts})
    : super(documents: {'/kira.pdf': document}, pageBlocks: {0: page});

  final List<String> applied = [];

  @override
  Future<EditPreview> applyEdit(int transaction, String text) {
    applied.add(text);
    return super.applyEdit(transaction, text);
  }
}

/// The fake with a character no font has, as the engine answers it: the
/// text is not applied, and "Keep as is" is refused while it is asked for.
class _NoFontEngine extends _CountingEngine {
  new() : super(missingGlyphs: const {3: FakeEngineService.madde6Glyphs});

  static const String none = '\u{13000}';

  late EditPreview _last;
  bool _blocked = false;

  @override
  Future<EditPreview> applyEdit(int transaction, String text) async {
    _blocked = text.contains(none);
    if (!_blocked) return _last = await super.applyEdit(transaction, text);
    applied.add(text);
    return EditPreview(
      page: _last.page,
      missing: const [none],
      glyphs: MissingGlyphs(
        chars: [MissingChar(text: none, at: text.indexOf(none))],
        font: 'EBGaramond-Regular',
      ),
      substitutions: _last.substitutions,
    );
  }

  @override
  Future<EditPreview> keepAsIs(int transaction) => _blocked
      ? Future.error(
          const EngineException(
            kind: EngineErrorKind.invalidInput,
            messageKey: 'errorInternal',
          ),
        )
      : super.keepAsIs(transaction);
}

void main() {
  late FakeDesktopWindow window;
  late _CountingEngine engine;

  setUpAll(initializeRegionFormats);
  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  /// Opens kira.pdf in Edit mode; its paragraph (block 3) is Madde 6, whose
  /// font has no "ğ" (a3-3a) unless [sameFont] gives step 2.
  Future<void> pumpEditor(
    WidgetTester tester, {
    bool sameFont = false,
    _CountingEngine? using,
  }) async {
    engine =
        using ??
        (sameFont
            ? _CountingEngine(
                sameFonts: const {3: FakeEngineService.madde6SameFont},
              )
            : _CountingEngine(
                missingGlyphs: const {3: FakeEngineService.madde6Glyphs},
              ));
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

  EditableText field(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  Future<void> typeMissing(
    WidgetTester tester, [
    String text = 'Değiştirilemez',
  ]) async {
    await clickParagraph(tester);
    await tester.enterText(find.byType(EditableText), text);
    await pumps(tester);
  }

  /// Lets the idle commit and the toast run out.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(DocumentEditor.idle);
    await pumps(tester);
    await tester.pump(DocumentEditor.toastTime);
    await pumps(tester);
  }

  const missingBody =
      'This font has no ‘\u2068ğ\u2069’. Ferman will use a similar font for '
      'this character.';

  testWidgets('a missing character is drawn provisionally, marked once, and '
      'the idle commit waits for Keep as is', (tester) async {
    await pumpEditor(tester);
    await typeMissing(tester);
    expect(editor(tester).glyphs?.drawn, isTrue);
    expect(find.text('Missing character'), findsOneWidget);
    expect(find.text(missingBody), findsOneWidget);
    expect(find.text('Choose a font…'), findsOneWidget);
    // The frame's label warns, below the frame (a3-3a).
    final box = tester.widget<TextEditBox>(find.byType(TextEditBox));
    expect(box.meta, 'EBGaramond-Regular');
    expect(box.metaWarning, isTrue);
    expect(box.metaPlacement, MetaPlacement.below);
    // The amber wavy underline under "ğ" alone.
    final span = field(tester).controller.buildTextSpan(
      context: tester.element(find.byType(EditableText)),
      withComposing: true,
    );
    final marked = span.children!
        .cast<TextSpan>()
        .where((s) => s.style?.decorationStyle == TextDecorationStyle.wavy)
        .map((s) => s.text);
    expect(marked, ['ğ']);

    // The idle commit does not commit while the question waits.
    await tester.pump(DocumentEditor.idle * 2);
    await pumps(tester);
    expect(editor(tester).history.current, 0);

    await tester.tap(find.text('Keep as is'));
    await pumps(tester);
    expect(find.text('Missing character'), findsNothing);
    expect(
      tester.widget<TextEditBox>(find.byType(TextEditBox)).metaWarning,
      isFalse,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    final step = editor(tester).history.steps.single;
    expect(step.substitutions.single.toFont, 'IBMPlexSerif-Regular');
    // The toast says it once and leaves after six seconds.
    expect(find.text('Font substituted'), findsOneWidget);
    expect(
      find.text(
        'This block uses \u2068IBMPlexSerif-Regular\u2069 for '
        '‘\u2068ğ\u2069’.',
      ),
      findsOneWidget,
    );
    expect(find.byType(FontSubstitutedToast), findsOneWidget);
    await tester.pump(DocumentEditor.toastTime);
    await pumps(tester);
    expect(find.text('Font substituted'), findsNothing);

    // The same font again: no second toast.
    await typeMissing(tester, 'Değiş');
    await tester.tap(find.text('Keep as is'));
    await pumps(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    expect(editor(tester).history.current, 2);
    expect(find.text('Font substituted'), findsNothing);
    await drain(tester);
  });

  testWidgets('closing the editor without an answer keeps the characters as '
      'they are drawn', (tester) async {
    await pumpEditor(tester);
    await typeMissing(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    expect(editor(tester).history.current, 1);
    expect(editor(tester).glyphs, isNull);
    expect(find.text('Font substituted'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('a character no font has after one drawn provisionally keeps '
      'the drawn text and leaves no transaction open', (tester) async {
    await pumpEditor(tester, using: _NoFontEngine());
    await typeMissing(tester);
    await tester.enterText(
      find.byType(EditableText),
      'Değiştirilemez${_NoFontEngine.none}',
    );
    await pumps(tester);
    expect(find.text('No font has this character'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    // The text drawn provisionally is the step; the next edit can begin.
    expect(editor(tester).history.current, 1);
    expect(editor(tester).active, isNull);
    expect(engine.applied.last, 'Değiştirilemez');
    await typeMissing(tester, 'Değ');
    expect(editor(tester).glyphs, isNotNull);
    await drain(tester);
  });

  testWidgets('the picker groups the candidates with their coverage, and '
      'Use sets the characters in the selected one', (tester) async {
    await pumpEditor(tester);
    await typeMissing(tester);
    await tester.tap(find.text('Choose a font…'));
    await pumps(tester);
    expect(find.byType(FontPickerDialog), findsOneWidget);
    expect(find.text('Choose a font for this block'), findsOneWidget);
    expect(find.text('EMBEDDED IN THIS DOCUMENT'), findsOneWidget);
    expect(find.text('SIMILAR FONTS INCLUDED WITH FERMAN'), findsOneWidget);
    expect(find.text('INSTALLED ON THIS COMPUTER'), findsNothing);
    expect(find.text('Closest match'), findsOneWidget);
    expect(find.text('No ‘\u2068ğ\u2069’'), findsOneWidget);
    // The bundled candidate previews its letters in its own font.
    final preview = tester.widget<Text>(find.text('Ğğ İı Şş Çç Öö Üü'));
    expect(preview.style?.fontFamily, 'IBM Plex Serif');
    // "Whole block" waits (B137).
    final scope = tester.widget<SegmentedControl<bool>>(
      find.byType(SegmentedControl<bool>),
    );
    expect(scope.options.last.disabled, isTrue);
    expect(scope.options.last.disabledReason, isNotNull);
    // The editor stays open behind the modal picker.
    expect(editor(tester).active, isNotNull);

    // Search narrows the rows.
    await tester.enterText(
      find.descendant(
        of: find.byType(FontPickerDialog),
        matching: find.byType(EditableText),
      ),
      'arabic',
    );
    await pumps(tester);
    expect(find.text('IBM Plex Serif'), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byType(FontPickerDialog),
        matching: find.byType(EditableText),
      ),
      '',
    );
    await pumps(tester);

    // The embedded Plex Serif, the second row.
    await tester.tap(find.text('IBM Plex Serif').first);
    await pumps(tester);
    await tester.tap(find.text('Use \u2068IBM Plex Serif\u2069'));
    await pumps(tester);
    expect(find.byType(FontPickerDialog), findsNothing);
    expect(editor(tester).glyphs, isNull);
    expect(editor(tester).active, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    final substitution = editor(tester).history.steps.single.substitutions;
    expect(substitution.single.toFont, 'IBMPlexSerif');
    expect(substitution.single.origin, FontOrigin.embedded);
    await drain(tester);
  });

  testWidgets('Cancel closes the picker and the question stays', (
    tester,
  ) async {
    await pumpEditor(tester);
    await typeMissing(tester);
    await tester.tap(find.text('Choose a font…'));
    await pumps(tester);
    await tester.tap(find.text('Cancel'));
    await pumps(tester);
    expect(find.byType(FontPickerDialog), findsNothing);
    expect(find.text('Missing character'), findsOneWidget);
    expect(editor(tester).active, isNotNull);
    await drain(tester);
  });

  testWidgets('"Ask each time" reaches the engine and applies nothing until '
      'the answer', (tester) async {
    await pumpEditor(tester);
    await containerOf(tester)
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(missingGlyphs: MissingGlyphPolicy.ask));
    await pumps(tester);
    expect(engine.fontSettings.askEachTime, isTrue);
    expect(engine.fontSettings.systemFonts, isTrue);
    await typeMissing(tester);
    expect(editor(tester).glyphs?.drawn, isFalse);
    expect(editor(tester).preview?.missing, ['ğ']);
    expect(find.text('Missing character'), findsOneWidget);
    await tester.tap(find.text('Keep as is'));
    await pumps(tester);
    expect(editor(tester).glyphs, isNull);
    expect(editor(tester).preview?.missing, isEmpty);
    await drain(tester);
  });

  testWidgets('step 2 says once where the character came from', (tester) async {
    await pumpEditor(tester, sameFont: true);
    await typeMissing(tester);
    expect(find.text('Character added from this computer'), findsOneWidget);
    expect(
      find.text(
        'Ferman took ‘\u2068ğ\u2069’ from \u2068EBGaramond-Regular\u2069 '
        'installed on this computer and added it to the document’s font.',
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    // Step 2 keeps the font: no toast.
    expect(find.text('Font substituted'), findsNothing);
    await typeMissing(tester, 'Değiş');
    expect(find.text('Character added from this computer'), findsNothing);
    await drain(tester);
  });

  group('input methods', () {
    TextEditingValue value(WidgetTester tester) =>
        field(tester).controller.value;

    Future<void> send(WidgetTester tester, TextEditingDelta delta) async {
      tester.testTextInput.updateEditingValue(delta.apply(value(tester)));
      await pumps(tester);
    }

    testWidgets('composing text shows in the field and reaches the engine '
        'as one edit when the composition ends', (tester) async {
      await pumpEditor(tester);
      await clickParagraph(tester);
      final caret = value(tester).selection.baseOffset;
      final before = value(tester).text;
      // A Japanese IME: "k", then "か", both composing.
      await send(
        tester,
        TextEditingDeltaInsertion(
          oldText: before,
          textInserted: 'k',
          insertionOffset: caret,
          selection: TextSelection.collapsed(offset: caret + 1),
          composing: TextRange(start: caret, end: caret + 1),
        ),
      );
      await send(
        tester,
        TextEditingDeltaReplacement(
          oldText: value(tester).text,
          replacementText: 'か',
          replacedRange: TextRange(start: caret, end: caret + 1),
          selection: TextSelection.collapsed(offset: caret + 1),
          composing: TextRange(start: caret, end: caret + 1),
        ),
      );
      expect(value(tester).text, contains('か'));
      expect(engine.applied, isEmpty);
      // Idle time while composing commits nothing.
      await tester.pump(DocumentEditor.idle * 2);
      await pumps(tester);
      expect(editor(tester).history.current, 0);
      expect(editor(tester).preview, isNull);

      // The composition ends: the text goes once.
      await send(
        tester,
        TextEditingDeltaNonTextUpdate(
          oldText: value(tester).text,
          selection: TextSelection.collapsed(offset: caret + 1),
          composing: TextRange.empty,
        ),
      );
      expect(engine.applied, [value(tester).text]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumps(tester);
      expect(editor(tester).history.current, 1);
      await containerOf(tester).read(documentEditorProvider.notifier).undo();
      await pumps(tester);
      expect(editor(tester).history.current, 0);
      await drain(tester);
    });

    testWidgets('a Turkish dead key is one edit with the letter it makes', (
      tester,
    ) async {
      await pumpEditor(tester);
      await clickParagraph(tester);
      final caret = value(tester).selection.baseOffset;
      await send(
        tester,
        TextEditingDeltaInsertion(
          oldText: value(tester).text,
          textInserted: '¨',
          insertionOffset: caret,
          selection: TextSelection.collapsed(offset: caret + 1),
          composing: TextRange(start: caret, end: caret + 1),
        ),
      );
      expect(engine.applied, isEmpty);
      await send(
        tester,
        TextEditingDeltaReplacement(
          oldText: value(tester).text,
          replacementText: 'ü',
          replacedRange: TextRange(start: caret, end: caret + 1),
          selection: TextSelection.collapsed(offset: caret + 1),
          composing: TextRange.empty,
        ),
      );
      expect(engine.applied, hasLength(1));
      expect(engine.applied.single, isNot(contains('¨')));
      expect(engine.applied.single, contains('ü'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumps(tester);
      await drain(tester);
    });
  });
}
