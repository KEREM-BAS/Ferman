import 'dart:async';

import 'package:ferman/app/app.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/block_editor.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/review_list.dart';
import 'package:ferman/features/onboarding/language_picker.dart';
import 'package:ferman/features/save/document_closer.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/save/save_as_sheet.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/default_app.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/platform/open_requests.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/recent/recent_previews.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/viewer/text_layer_test.dart' show block;
import '../helpers/fake_file_picker.dart';
import '../helpers/window_golden.dart';

/// Where the documents are: "~/Belgeler" with [_home].
const String _home = '/Users/elif';
const String _kiraPath = '$_home/Belgeler/Kira sözleşmesi.pdf';
const String _faturaPath = '$_home/Belgeler/e-Arşiv fatura 4187.pdf';
const String _ekstrePath = '$_home/Belgeler/Hesap ekstresi Eylül 2026.pdf';
const String _signedPath = '$_home/Belgeler/Kira sözleşmesi (imzalı).pdf';

/// The history's clock: the times on the review rows never move.
DateTime _now() => DateTime(2025, 10, 13, 14, 32);

const List<PageInfo> _a4 = [PageInfo(width: 595, height: 842)];
const OpenedDocument _kira = OpenedDocument(
  id: 1,
  pages: [..._a4, ..._a4, ..._a4],
);
const OpenedDocument _fatura = OpenedDocument(id: 2, pages: _a4);
const OpenedDocument _ekstre = OpenedDocument(id: 3, pages: [..._a4, ..._a4]);

/// The lease with Mert Kaya's signature (a3-16a).
const OpenedDocument _signed = OpenedDocument(
  id: 4,
  pages: _a4,
  signed: true,
  signatures: [Signature(field: 'S', signed: true, signer: 'Mert Kaya')],
);

/// Madde 4's heading.
final TextBlock _heading = block(1, const Rect.fromLTRB(72, 268, 400, 284), [
  'Madde 4 — Kira bedeli',
]);

/// Madde 4's paragraph, whose edits overflow onto the IBAN line (a3-4).
final TextBlock _paragraph = block(3, const Rect.fromLTRB(72, 292, 523, 334), [
  'Aylık kira bedeli 18.500,00 TL olup her ayın beşinci',
  'gününe kadar aşağıdaki hesaba ödenir. Gecikme halinde',
  'yasal faiz uygulanır.',
], language: 'tr-TR');

/// Madde 6's paragraph, whose font has no "ğ" (a3-3a).
final TextBlock _madde6 = block(4, const Rect.fromLTRB(72, 400, 523, 428), [
  'Kiracı, kiralananı sözleşme süresince özenle kullanır',
  've sözleşme bitiminde teslim eder.',
], language: 'tr-TR');

/// The contract's title, drawn as shapes (a3-19).
final TextBlock _outlined = block(5, const Rect.fromLTRB(72, 90, 523, 118), [
  'KİRA SÖZLEŞMESİ',
], notEditable: NotEditableReason.outlinedText);

const String _longer =
    'Aylık kira bedeli 19.500,00 TL olup her ayın beşinci gününe kadar '
    'aşağıdaki hesaba ödenir. Gecikme halinde yasal faiz uygulanır ve '
    'kiracı bunu kabul eder.';
const String _withG =
    'Kiracı, kiralananı sözleşme süresince özenle kullanır '
    've değiştirilemez şekilde teslim eder.';

/// a3-4's plan: one line over, all three choices open.
const OverflowPlan _fits = OverflowPlan(
  over: 1,
  extendLines: 1,
  tightenPercent: 0.6,
  keepHidden: 1,
);

/// a3-18: the tightest allowed spacing leaves a line over.
const OverflowPlan _tooTight = OverflowPlan(
  over: 1,
  extendLines: 1,
  tightenShort: 1,
  keepHidden: 1,
);

/// a3-17: no font has the character.
final MissingGlyphs _noFont = MissingGlyphs(
  chars: FakeEngineService.madde6Glyphs.chars,
  font: FakeEngineService.madde6Glyphs.font,
);

/// a3-17: the installed copy's licence allows only preview and print.
final MissingGlyphs _notEmbeddable = MissingGlyphs(
  chars: FakeEngineService.madde6Glyphs.chars,
  font: FakeEngineService.madde6Glyphs.font,
  reason: MissingReason.notEmbeddable,
  reasonFont: 'Garamond Premier Pro',
  reasonEmbedding: FontEmbedding.previewAndPrint,
  candidates: FakeEngineService.madde6Glyphs.candidates,
);

const List<RecoverableDocument> _recoverable = [
  RecoverableDocument(
    session: 's',
    document: 'a',
    original: _kiraPath,
    changes: 6,
  ),
  RecoverableDocument(
    session: 's',
    document: 'b',
    original: _faturaPath,
    changes: 2,
  ),
];

/// A fake engine with the lease's page, its blocks and styles.
FakeEngineService _engine({
  Map<int, OverflowPlan> overflows = const {},
  Map<int, MissingGlyphs> missing = const {},
  Map<int, FontSubstitution> same = const {},
}) {
  final engine = FakeEngineService(
    documents: const {
      _kiraPath: _kira,
      _faturaPath: _fatura,
      _ekstrePath: _ekstre,
      _signedPath: _signed,
    },
    pageBlocks: {
      0: PageBlocks(blocks: [_outlined, _heading, _paragraph, _madde6]),
    },
    overflows: overflows,
    missingGlyphs: missing,
    sameFonts: same,
  )..now = _now;
  engine.signed.add(_signed.id);
  for (final id in [_heading.id, _paragraph.id, _madde6.id]) {
    engine.blockStyles[id] = const BlockStyleInfo(
      font: 'IBMPlexSerif-Regular',
      family: 'IBM Plex Serif',
      size: 11,
      frame: Rect.fromLTWH(72, 292, 451, 42),
      boldToggle: BlockFont(
        origin: FontOrigin.embedded,
        postscriptName: 'IBMPlexSerif-Bold',
      ),
      colour: 0x1F1D1A,
      documentColours: [0x1F1D1A, 0xC81E1E],
    );
  }
  return engine;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FermanApp)));

DocumentEditor _editor(WidgetTester tester) =>
    _container(tester).read(documentEditorProvider.notifier);

DocumentSaver _saver(WidgetTester tester) =>
    _container(tester).read(documentSaverProvider.notifier);

DocumentCloser _closer(WidgetTester tester) =>
    _container(tester).read(documentCloserProvider.notifier);

ReviewList _review(WidgetTester tester) =>
    _container(tester).read(reviewListProvider.notifier);

FakeEngineService _engineOf(WidgetTester tester) =>
    _container(tester).read(engineServiceProvider) as FakeEngineService;

/// Lets the app answer, without waiting for the idle commit.
Future<void> _pumps(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

/// Opens [paths] in Edit mode, the first one shown.
Future<void> _openEdit(
  WidgetTester tester, [
  List<String> paths = const [_kiraPath],
]) async {
  await _container(tester).read(documentOpenerProvider.notifier).open(paths);
  await _pumps(tester);
  _container(tester).read(shellDocumentsProvider.notifier).focus(paths.first);
  _container(tester).read(shellModeProvider.notifier).select(FermanMode.edit);
  await _pumps(tester);
}

/// Opens [text]'s block, with the text it has now, in the editor.
Future<void> _openBlock(WidgetTester tester, TextBlock text) async {
  final document = _container(tester)
      .read(shellDocumentsProvider)
      .active!
      .document!;
  final page = await _engineOf(tester).textBlocks(document.id, 0);
  await _editor(tester).open(
    0,
    page.blocks.firstWhere((candidate) => candidate.id == text.id),
    caret: 0,
    name: 'Edited text · page 1',
  );
  await _pumps(tester);
}

/// The open block's field.
Finder _field() => find.descendant(
  of: find.byType(BlockEditor),
  matching: find.byType(EditableText),
);

/// Types [typed] into [text]'s block, which stays open.
Future<void> _type(WidgetTester tester, TextBlock text, String typed) async {
  await _openBlock(tester, text);
  await tester.enterText(_field(), typed);
  await _pumps(tester);
}

/// One finished edit of [text]'s block.
Future<void> _edit(WidgetTester tester, TextBlock text, String typed) async {
  await _type(tester, text, typed);
  await _editor(tester).finish();
  await _pumps(tester);
}

/// The tab at [path] as unsaved, with [edits] edits.
void _unsaved(WidgetTester tester, String path, int edits) {
  final notifier = _container(tester).read(shellDocumentsProvider.notifier);
  final tab = _container(tester)
      .read(shellDocumentsProvider)
      .documents
      .firstWhere((t) => t.path == path);
  notifier.replace(path, tab.withSave(SaveState.unsaved, editCount: edits));
}

/// A screen in Edit mode: [open] goes on from the lease shown there.
Future<void> Function(WidgetTester) _inEdit(
  Future<void> Function(WidgetTester) open,
) => (tester) async {
  await _openEdit(tester);
  await open(tester);
  await _pumps(tester);
};

/// The lease, unsaved, with a save that fails with [kind] (a11-7, a11-7d).
Future<void> Function(WidgetTester) _saveFailing(EngineErrorKind kind) =>
    _inEdit((tester) async {
      _unsaved(tester, _kiraPath, 3);
      _engineOf(tester).failNextSave(kind);
      await _saver(tester).save();
    });

/// The mouse a screen left over the page; [_cleanUp] takes it away.
TestGesture? _mouse;

/// Hovers page space's [point].
Future<void> _hover(WidgetTester tester, Offset point) async {
  final view = _container(tester).read(viewerProvider)!;
  final at =
      tester.getTopLeft(find.byType(DocumentView)) +
      view.placement.rects.first!.topLeft -
      view.offset +
      point * view.scale;
  final mouse = _mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(
    location: tester.getTopLeft(find.byType(DocumentView)),
  );
  await mouse.moveTo(at);
  await tester.pump();
  await tester.pump();
}

/// What a screen leaves running: its mouse, a toast's timer.
Future<void> _cleanUp(WidgetTester tester) async {
  await _mouse?.removePointer();
  _mouse = null;
  await tester.pump(DocumentEditor.toastTime);
}

/// An M3 screen of the golden matrix: its golden name, the board it is
/// compared with, and how the app gets there.
final class _Screen {
  const new(
    this.name,
    this.open, {
    this.board,
    this.dialog = false,
    this.engine = _engine,
    this.firstRun = false,
    this.layoutPortals = 0,
  });

  final String name;
  final Future<void> Function(WidgetTester tester) open;

  /// The board drawn in English and light, or the spec sheet that draws it.
  final String? board;

  /// Whether it shows a modal Dialog.
  final bool dialog;

  /// A fresh engine for each golden: an edit changes its state.
  final FakeEngineService Function() engine;

  /// Whether it is a step of first run.
  final bool firstRun;

  /// See [windowGoldenTest]: the format bar is one.
  final int layoutPortals;
}

/// The lease with three tabs, one edit done and its block open: a3-1d,
/// a12-1tr, a12-1ar, a12-1de, a12-1ja and f6a.
Future<void> _editMain(WidgetTester tester) async {
  await _openEdit(tester, const [_kiraPath, _faturaPath, _ekstrePath]);
  _unsaved(tester, _ekstrePath, 3);
  await _edit(
    tester,
    _paragraph,
    _paragraph.text.replaceFirst('18.500', '19.500'),
  );
  await _openBlock(tester, _paragraph);
}

const String _editMainName = 'edit_main';

final List<_Screen> _screens = [
  const _Screen(_editMainName, _editMain),
  _Screen(
    'edit_caret',
    _inEdit((tester) => _type(tester, _paragraph, _longer)),
    board: 'a3-1b',
  ),
  _Screen(
    'edit_selection',
    _inEdit((tester) async {
      await _openBlock(tester, _paragraph);
      tester.widget<EditableText>(_field()).controller.selection =
          const TextSelection(baseOffset: 18, extentOffset: 27);
    }),
    board: 'a3-1c',
    layoutPortals: 1,
  ),
  _Screen(
    'edit_panel',
    _inEdit((tester) => _openBlock(tester, _paragraph)),
    board: 'a3-2',
  ),
  _Screen(
    'missing_glyph',
    _inEdit((tester) => _type(tester, _madde6, _withG)),
    board: 'a3-3a',
    engine: () => _engine(missing: const {4: FakeEngineService.madde6Glyphs}),
  ),
  _Screen(
    'font_picker',
    _inEdit((tester) async {
      await _type(tester, _madde6, _withG);
      _editor(tester).showFontPicker(open: true);
    }),
    board: 'a3-3b',
    dialog: true,
    engine: () => _engine(missing: const {4: FakeEngineService.madde6Glyphs}),
  ),
  // The page after a substitution, with the toast (G37 d).
  _Screen(
    'missing_kept',
    _inEdit((tester) async {
      await _type(tester, _madde6, _withG);
      await _editor(tester).finish();
    }),
    engine: () => _engine(missing: const {4: FakeEngineService.madde6Glyphs}),
  ),
  _Screen(
    'missing_same_font',
    _inEdit((tester) => _type(tester, _madde6, _withG)),
    board: 'a3-17',
    engine: () => _engine(same: const {4: FakeEngineService.madde6SameFont}),
  ),
  _Screen(
    'missing_no_font',
    _inEdit((tester) => _type(tester, _madde6, _withG)),
    board: 'a3-17',
    engine: () => _engine(missing: {4: _noFont}),
  ),
  _Screen(
    'missing_not_embeddable',
    _inEdit((tester) => _type(tester, _madde6, _withG)),
    board: 'a3-17',
    engine: () => _engine(missing: {4: _notEmbeddable}),
  ),
  _Screen(
    'overflow',
    _inEdit((tester) => _type(tester, _paragraph, _longer)),
    board: 'a3-4',
    engine: () => _engine(overflows: const {3: _fits}),
  ),
  _Screen(
    'overflow_extend_blocked',
    _inEdit((tester) => _type(tester, _paragraph, _longer)),
    board: 'a3-18',
    engine: () => _engine(overflows: const {3: FakeEngineService.ibanOverflow}),
  ),
  _Screen(
    'overflow_tighten_blocked',
    _inEdit((tester) => _type(tester, _paragraph, _longer)),
    board: 'a3-18',
    engine: () => _engine(overflows: const {3: _tooTight}),
  ),
  _Screen(
    'overflow_extended',
    _inEdit((tester) async {
      await _type(tester, _paragraph, _longer);
      await _editor(tester).resolve(OverflowChoice.extend);
    }),
    board: 'a3-18',
    engine: () => _engine(overflows: const {3: _fits}),
  ),
  _Screen(
    'overflow_tightened',
    _inEdit((tester) async {
      await _type(tester, _paragraph, _longer);
      await _editor(tester).resolve(OverflowChoice.tighten);
    }),
    board: 'a3-18',
    engine: () => _engine(overflows: const {3: _fits}),
  ),
  _Screen(
    'overflow_kept',
    _inEdit((tester) => _edit(tester, _paragraph, _longer)),
    board: 'a3-18',
    engine: () => _engine(overflows: const {3: _fits}),
  ),
  _Screen(
    'not_editable',
    _inEdit((tester) => _hover(tester, const Offset(200, 104))),
    board: 'a3-19',
  ),
  _Screen(
    'review_list',
    (tester) async {
      await _openEdit(tester, const [_signedPath]);
      await _openBlock(tester, _heading);
      await _pumps(tester);
      await _saver(tester).editAnyway();
      await _pumps(tester);
      _editor(tester).type('Madde 4 — Aylık kira bedeli');
      await _editor(tester).finish();
      await _pumps(tester);
      await _edit(tester, _paragraph, _longer);
      await _edit(tester, _madde6, _withG);
      _review(tester).show(open: true);
      await _pumps(tester);
    },
    board: 'a3-12',
    engine: () => _engine(
      overflows: const {3: _fits},
      missing: const {4: FakeEngineService.madde6Glyphs},
    ),
  ),
  _Screen(
    'review_empty',
    _inEdit((tester) async => _review(tester).show(open: true)),
    board: 'a3-12b',
  ),
  _Screen(
    'review_revert_all',
    _inEdit((tester) async {
      await _edit(tester, _heading, 'Madde 4 — Aylık kira bedeli');
      await _edit(tester, _paragraph, _longer);
      _review(tester)
        ..show(open: true)
        ..askRevertAll(2);
    }),
    board: 'a3-12b',
    dialog: true,
  ),
  _Screen(
    'review_dependent',
    _inEdit((tester) async {
      await _edit(tester, _paragraph, _longer);
      await _edit(tester, _paragraph, '$_longer Ek bir cümle.');
      _review(tester).show(open: true);
      await _review(tester).revert(0, 'Revert');
    }),
    board: 'a3-12b',
    dialog: true,
  ),
  _Screen(
    'signed_warning',
    (tester) async {
      await _openEdit(tester, const [_signedPath]);
      await _openBlock(tester, _paragraph);
    },
    board: 'a3-16a',
    dialog: true,
  ),
  _Screen('signed_banner', (tester) async {
    await _openEdit(tester, const [_signedPath]);
    await _openBlock(tester, _paragraph);
    await _saver(tester).editAnyway();
    await _pumps(tester);
    await tester.enterText(_field(), _longer);
    await _pumps(tester);
    await _editor(tester).finish();
    await _pumps(tester);
  }, board: 'a3-16b'),
  _Screen(
    'close_unsaved',
    _inEdit((tester) async {
      _unsaved(tester, _kiraPath, 3);
      unawaited(_closer(tester).close(_kiraPath));
    }),
    board: 'a1-10b',
    dialog: true,
  ),
  _Screen(
    'save_as',
    _inEdit((tester) async => _saver(tester).openSheet()),
    board: 'a1-11',
    dialog: true,
  ),
  _Screen(
    'save_as_folder',
    _inEdit((tester) async {
      _saver(tester).openSheet();
      await _pumps(tester);
      final context = tester.element(find.byType(SaveAsSheet));
      await tester.tap(find.byType(Select<String?>));
      await _pumps(tester);
      await tester.tap(
        find.text(AppLocalizations.of(context).saveAsOtherLocation).last,
      );
    }),
    board: 'a1-11b',
    dialog: true,
  ),
  _Screen(
    'save_disk_full',
    _saveFailing(EngineErrorKind.diskFull),
    board: 'a11-7',
    dialog: true,
  ),
  _Screen(
    'save_permission',
    _saveFailing(EngineErrorKind.permissionDenied),
    board: 'a11-7d',
    dialog: true,
  ),
  _Screen(
    'save_locked',
    _saveFailing(EngineErrorKind.fileLocked),
    board: 'a11-7d',
    dialog: true,
  ),
  _Screen(
    'save_replace_failed',
    _saveFailing(EngineErrorKind.renameFailed),
    board: 'a11-7d',
    dialog: true,
  ),
  _Screen(
    'save_volume_gone',
    _saveFailing(EngineErrorKind.volumeGone),
    board: 'a11-7d',
    dialog: true,
  ),
  _Screen(
    'file_changed',
    _inEdit((tester) async {
      _unsaved(tester, _kiraPath, 3);
      _engineOf(tester).changedOnDisk.add(_kira.id);
      await _saver(tester).save();
    }),
    board: 'a11-7b',
  ),
  _Screen(
    'quit_unsaved',
    (tester) async {
      await _openEdit(tester, const [_kiraPath, _faturaPath, _ekstrePath]);
      _unsaved(tester, _kiraPath, 3);
      _unsaved(tester, _faturaPath, 1);
      _unsaved(tester, _ekstrePath, 5);
      unawaited(_closer(tester).quit());
    },
    board: 'a11-7e',
    dialog: true,
  ),
  _Screen(
    'recovery',
    (tester) => tester.pumpAndSettle(),
    board: 'a1-12',
    dialog: true,
    engine: () => _engine()
      ..recoveryRoot = '/recovery'
      ..recoverable.addAll(_recoverable),
  ),
  _Screen(
    'recovery_changed',
    (tester) => tester.pumpAndSettle(),
    board: 'a11-7f',
    dialog: true,
    engine: () => _engine()
      ..recoveryRoot = '/recovery'
      ..recoverable.addAll([
        _recoverable.first,
        const RecoverableDocument(
          session: 's',
          document: 'b',
          original: _faturaPath,
          originalChanged: true,
          changes: 2,
        ),
      ]),
  ),
  _Screen(
    'settings_editing',
    (tester) async {
      unawaited(
        _container(tester)
            .read(routerProvider)
            .push(Routes.settingsPane(SettingsPane.editing.path)),
      );
      await tester.pumpAndSettle();
    },
    board: 'a11-1c',
    engine: () => _engine()..recoveryRoot = '/recovery',
  ),
  _Screen(
    'welcome_edit',
    (tester) async {
      tester.widget<LanguagePicker>(find.byType(LanguagePicker)).onContinue();
      await tester.pumpAndSettle();
    },
    board: 'a1-2a',
    firstRun: true,
  ),
];

/// The board of [screen]'s golden, for its test name.
String? _board(_Screen screen, GoldenTheme theme, GoldenLanguage language) =>
    switch ((screen.name, theme, language)) {
      (_editMainName, GoldenTheme.dark, GoldenLanguage.en) => 'a3-1d',
      (_editMainName, GoldenTheme.light, GoldenLanguage.tr) => 'a12-1tr',
      (_editMainName, GoldenTheme.light, GoldenLanguage.ar) => 'a12-1ar',
      (_, GoldenTheme.light, GoldenLanguage.en) => screen.board,
      _ => null,
    };

Future<void> _golden(
  _Screen screen,
  GoldenChrome chrome,
  GoldenTheme theme,
  GoldenLanguage language, {
  String? board,
}) => windowGoldenTest(
  screen: screen.name,
  chrome: chrome,
  theme: theme,
  language: language,
  board: board,
  settings: goldenSettings(
    theme: theme,
    language: language,
    onboardingCompleted: !screen.firstRun,
  ),
  open: screen.open,
  engine: screen.engine(),
  muteTickers: !screen.dialog,
  cleanUp: _cleanUp,
  layoutPortals: screen.layoutPortals,
  overrides: [
    homeDirectoryProvider.overrideWithValue(_home),
    fileAccessProvider.overrideWithValue(const NoFileAccess()),
    openRequestsProvider.overrideWithValue(const NoOpenRequests()),
    initialRecentFilesProvider.overrideWithValue(const []),
    recentFilesStoreProvider.overrideWithValue(MemoryRecentFilesStore()),
    recentPreviewStoreProvider.overrideWithValue(MemoryRecentPreviewStore()),
    defaultPdfAppProvider.overrideWithValue(const NoDefaultPdfApp()),
    filePickerServiceProvider.overrideWithValue(
      FakeFilePickerService(saveTo: '$_home/Projeler/2026/Kira kopya.pdf'),
    ),
  ],
);

/// The M3 screens (ROADMAP §7, gate S4) in light and dark × en, tr and ar
/// with macOS chrome: Edit mode and its panel, the missing-glyph and overflow
/// states (G37, G38), text that can't be edited, the review list (G42), a
/// signed document, Save as, the save failures (G40), closing, quitting,
/// recovery, Settings › Editing and welcome step 1; and the main editor with
/// Windows chrome (f6a, in German a12-1de) and in Japanese (a12-1ja), whose
/// strings fall back to English. The fake engine draws no pages, so the
/// canvas shows the pages' paper and what the app draws over it.
Future<void> main() async {
  for (final screen in _screens) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        await _golden(
          screen,
          GoldenChrome.mac,
          theme,
          language,
          board: _board(screen, theme, language),
        );
      }
    }
  }
  final main = _screens.first;
  await _golden(
    main,
    GoldenChrome.win,
    GoldenTheme.light,
    GoldenLanguage.en,
    board: 'f6a',
  );
  await _golden(
    main,
    GoldenChrome.win,
    GoldenTheme.light,
    GoldenLanguage.de,
    board: 'a12-1de',
  );
  await _golden(
    main,
    GoldenChrome.mac,
    GoldenTheme.light,
    GoldenLanguage.ja,
    board: 'a12-1ja',
  );
}
