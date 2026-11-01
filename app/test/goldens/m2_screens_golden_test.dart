import 'dart:async';

import 'package:ferman/app/app.dart';
import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/platform/default_app.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/open_requests.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/recent/recent_previews.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

/// Where the sample document is: "~/Belgeler" with [_home].
const String _home = '/Users/elif';
const String _kiraPath = '$_home/Belgeler/Kira sözleşmesi.pdf';
const String _bordroPath = '$_home/Belgeler/Bordro Eylül 2026.pdf';
const String _sheetPath = '$_home/Belgeler/Ek-1 Demirbaş listesi.xlsx';
const String _scanPath = '$_home/Belgeler/Tarama_0042.pdf';
const String _damagedPath = '$_home/Belgeler/Kira sözleşmesi (eski).pdf';
const String _visaPath = '$_home/Belgeler/Vize başvurusu.pdf';

/// The lease of the boards (a2-1b, a2-3o, a2-3b, a2-3c, a2-14): three A4
/// pages, its outline, attachments, layers and signatures, with its fonts
/// and facts for the panel and the properties.
final OpenedDocument _kira = OpenedDocument(
  id: 1,
  pages: const [
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
  ],
  outline: const [
    OutlineEntry(title: 'Madde 1 — Taraflar', page: 0),
    OutlineEntry(title: 'Madde 4 — Kira bedeli', page: 1, open: true),
    OutlineEntry(title: '4.1 Yıllık artış', page: 1, depth: 1),
    OutlineEntry(title: '4.2 Gecikme', page: 2, depth: 1),
    OutlineEntry(title: 'İmzalar', page: 2),
  ],
  attachments: [
    Attachment(
      name: 'Ek-1 Demirbaş listesi.xlsx',
      size: 18 * 1024,
      modified: DateTime(2026, 10, 12, 9, 30),
    ),
    const Attachment(name: 'Tapu fotokopisi.jpg'),
  ],
  layers: const [
    Layer(name: 'Metin'),
    Layer(name: 'İmzalar', locked: true),
    Layer(name: 'Filigran — TASLAK', visible: false),
  ],
  layersSwitchable: true,
  signatures: [
    Signature(
      field: 'KiraVeren.Imza',
      signed: true,
      signer: 'Mert Kaya',
      signedAt: DateTime(2026, 10, 13, 11, 4),
      page: 2,
    ),
    const Signature(field: 'Kiracı · İmza', page: 2),
  ],
  version: '1.7',
  fileSize: 248 * 1024,
  language: 'tr-TR',
);

/// The lease restricted by its owner password (a2-10a): no editing, no
/// copying.
const OpenedDocument _restricted = OpenedDocument(
  id: 2,
  pages: [PageInfo(width: 595, height: 842)],
  version: '1.7',
  security: Security(
    method: EncryptionMethod.aes256,
    keyBits: 256,
    permissions: DocumentPermissions(modify: false, copy: false),
    restricted: true,
  ),
);

/// Two matches of "kira" for the find bar and the Search results tab.
final Map<String, List<List<SearchMatch>>> _matches = {
  'kira': [
    [
      const SearchMatch(
        page: 0,
        rects: [Rect.fromLTRB(72, 80, 120, 94)],
        snippet: 'KİRA SÖZLEŞMESİ',
        snippetStart: 0,
        snippetEnd: 4,
      ),
    ],
    [
      const SearchMatch(
        page: 1,
        rects: [Rect.fromLTRB(110, 300, 140, 312)],
        snippet: 'Aylık kira bedeli 18.500,00 TL olup',
        snippetStart: 6,
        snippetEnd: 10,
      ),
    ],
  ],
};

/// The query of a2-4c's long search.
/// kira-tr-damaged as ferman-core repairs it (a1-9): a rebuilt table and
/// a stream read to its end.
const OpenedDocument _repaired = OpenedDocument(
  id: 3,
  pages: [
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
  ],
  readOnly: ReadOnlyReason.repaired,
  repairs: [
    RepairFix(kind: RepairKind.crossReferenceRebuilt, count: 48),
    RepairFix(kind: RepairKind.streamLengthsCorrected, count: 1),
  ],
);

/// An XFA-only visa form (a11-7c).
const OpenedDocument _xfa = OpenedDocument(
  id: 4,
  pages: [PageInfo(width: 595, height: 842)],
  readOnly: ReadOnlyReason.xfaOnly,
);

const String _slowQuery = 'otopark';

/// The fake engine of the screens, whose search for [_slowQuery] finds
/// a2-4c's 38 matches, reaches page 840 of 2,400 and waits there.
final class _Engine extends FakeEngineService {
  new()
    : super(
        documents: {
          _kiraPath: _kira,
          '$_home/Belgeler/Sözleşme (kısıtlı).pdf': _restricted,
          _bordroPath: _kira,
          _damagedPath: _repaired,
          _visaPath: _xfa,
        },
        passwords: {_bordroPath: 'bordro2026'},
        failures: {
          _sheetPath: const EngineException(
            kind: EngineErrorKind.unsupported,
            messageKey: 'errorNotPdf',
          ),
          // a1-9b's file, cut off at 18 KB.
          _scanPath: const EngineException(
            kind: EngineErrorKind.damaged,
            messageKey: 'errorDamagedTruncated',
            details:
                'Expected about 2.4 MB, found 18 KB · last complete object '
                '12 0 obj · no trailer',
          ),
        },
        searchResults: _matches,
      );

  @override
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  ) async* {
    if (query != _slowQuery) {
      yield* super.search(document, query, options);
      return;
    }
    yield SearchMatches([
      for (var i = 0; i < 38; i++)
        SearchMatch(
          page: i % 3,
          rects: [Rect.fromLTWH(72, 120 + 18.0 * (i ~/ 3), 44, 12)],
          snippet: 'Kiracı otopark alanını kullanır',
          snippetStart: 7,
          snippetEnd: 14,
        ),
    ]);
    yield const SearchProgress(searched: 840, pages: 2400);
    await Completer<void>().future;
  }
}

/// An engine whose PDFium did not load (G101).
final FakeEngineService _noPdfium = FakeEngineService(
  fakeStatus: const EngineStatus(
    appVersion: '0.1.0',
    apiVersion: kAppApiVersion,
    isDebugBuild: false,
    pdfium: PdfiumState.failed,
    pdfiumReason: 'cannot load the PDFium library: dlopen failed',
  ),
);

/// The lease with [query] searched in the find bar.
Future<void> Function(WidgetTester) _kiraSearching(String query) =>
    (tester) async {
      await _open(tester, _kiraPath);
      _container(tester).read(findProvider.notifier)
        ..open()
        ..setQuery(query);
      // A search that waits never settles.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    };

/// The recent files of a1-4-m2: dated long ago, so each card shows a date
/// rather than "Today", and the golden does not change with the clock.
final List<RecentEntry> _recent = [
  RecentEntry(
    path: _kiraPath,
    name: 'Kira sözleşmesi.pdf',
    opened: DateTime(2025, 10, 13, 14, 32),
    pages: 3,
    signed: true,
  ),
  RecentEntry(
    path: '$_home/Belgeler/Başvuru formu.pdf',
    name: 'Başvuru formu.pdf',
    opened: DateTime(2025, 10, 12, 9, 5),
    pages: 2,
    form: true,
  ),
  RecentEntry(
    path: '$_home/Belgeler/Tarama 0412.pdf',
    name: 'Tarama 0412.pdf',
    opened: DateTime(2025, 10, 10, 17, 48),
    pages: 6,
    scanned: true,
  ),
  RecentEntry(
    path: '$_home/Okul/Tez taslağı.pdf',
    name: 'Tez taslağı.pdf',
    opened: DateTime(2025, 10, 2, 11),
    pages: 64,
    pinned: true,
  ),
];

/// Preview, which opens PDF files until Ferman does (a1-3).
final class _Preview implements DefaultPdfApp {
  @override
  Future<PdfHandler?> current() async =>
      const PdfHandler(name: 'Preview', ferman: false);

  @override
  Future<bool> makeFerman() async => false;
}

/// An M2 screen of the golden matrix: its golden name, the board it is
/// compared with in English, and how the app gets there.
final class _Screen {
  const new(
    this.name,
    this.open, {
    this.board,
    this.recent = false,
    this.defaultApp = false,
    this.dialog = false,
    this.engine,
  });

  final String name;
  final Future<void> Function(WidgetTester tester) open;
  final String? board;

  /// Whether the start screen lists [_recent].
  final bool recent;

  /// Whether another app opens PDF files (a1-3's prompt).
  final bool defaultApp;

  /// Whether it shows a modal Dialog.
  final bool dialog;

  /// The engine in place of the screens' own.
  final FakeEngineService? engine;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FermanApp)));

/// Opens [path] as the app does, then lets it settle.
Future<void> _open(WidgetTester tester, String path) async {
  await _container(tester).read(documentOpenerProvider.notifier).open([path]);
  await tester.pumpAndSettle();
}

/// The lease with [tab] shown in the sidebar.
Future<void> Function(WidgetTester) _kiraWith(SidebarTab tab) =>
    (tester) async {
      await _open(tester, _kiraPath);
      _container(tester).read(shellSidebarTabProvider.notifier).select(tab);
      await tester.pumpAndSettle();
    };

final List<_Screen> _screens = [
  _Screen('viewer', _kiraWith(SidebarTab.pages), board: 'a2-1b'),
  _Screen('viewer_outline', _kiraWith(SidebarTab.outline)),
  _Screen('viewer_attachments', _kiraWith(SidebarTab.attachments)),
  _Screen('viewer_layers', _kiraWith(SidebarTab.layers)),
  _Screen('viewer_signatures', _kiraWith(SidebarTab.signatures)),
  _Screen('viewer_search', (tester) async {
    await _open(tester, _kiraPath);
    _container(tester).read(findProvider.notifier)
      ..open()
      ..setQuery('kira');
    await tester.pumpAndSettle();
    _container(tester)
        .read(shellSidebarTabProvider.notifier)
        .select(SidebarTab.search);
    await tester.pumpAndSettle();
  }, board: 'a2-4b'),
  _Screen(
    'properties',
    (tester) async {
      await _open(tester, _kiraPath);
      // ⌘D's command.
      _container(tester)
          .read(documentPropertiesRequestProvider.notifier)
          .request();
      await tester.pumpAndSettle();
    },
    board: 'a2-7',
    dialog: true,
  ),
  _Screen('restricted', (tester) async {
    await _open(tester, '$_home/Belgeler/Sözleşme (kısıtlı).pdf');
  }, board: 'a2-10a'),
  _Screen('unlock', (tester) => _open(tester, _bordroPath), board: 'a1-8'),
  _Screen('not_a_pdf', (tester) => _open(tester, _sheetPath), board: 'a1-9c'),
  _Screen('damaged', (tester) => _open(tester, _scanPath), board: 'a1-9b'),
  _Screen('repaired', (tester) => _open(tester, _damagedPath), board: 'a1-9'),
  _Screen('xfa_only', (tester) => _open(tester, _visaPath), board: 'a11-7c'),
  _Screen('viewer_search_progress', _kiraSearching(_slowQuery), board: 'a2-4c'),
  _Screen('viewer_search_none', _kiraSearching('depozito'), board: 'a2-4d'),
  // No board draws it (G101): the warning Banner over the empty start
  // screen, its open actions disabled.
  _Screen('start_no_pdfium', (_) async {}, engine: _noPdfium),
  _Screen('start_recent', (_) async {}, board: 'a1-4-m2', recent: true),
  // The system's answer arrives a frame after the start screen.
  _Screen(
    'default_app',
    (tester) => tester.pumpAndSettle(),
    board: 'a1-3',
    defaultApp: true,
    dialog: true,
  ),
];

/// The M2 screens (ROADMAP §6, gate S4) in light and dark × en, tr and ar
/// with macOS chrome: the viewer with the lease open and each sidebar tab,
/// search with its options, a long search's progress (a2-4c) and no
/// results (a2-4d), the properties, a restricted document, the unlock
/// dialog, a damaged file (a1-9b), a file that is not a PDF, the recent
/// files, the default-app prompt and the start screen without PDFium
/// (G101). The fake engine draws no pages, so the canvas shows the pages'
/// paper only.
Future<void> main() async {
  final engine = _Engine();
  for (final screen in _screens) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.values) {
        await windowGoldenTest(
          screen: screen.name,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: theme == GoldenTheme.light && language == GoldenLanguage.en
              ? screen.board
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ),
          open: screen.open,
          engine: screen.engine ?? engine,
          muteTickers: !screen.dialog,
          overrides: [
            homeDirectoryProvider.overrideWithValue(_home),
            fileAccessProvider.overrideWithValue(const NoFileAccess()),
            openRequestsProvider.overrideWithValue(const NoOpenRequests()),
            initialRecentFilesProvider.overrideWithValue(
              screen.recent ? _recent : const [],
            ),
            recentFilesStoreProvider.overrideWithValue(
              MemoryRecentFilesStore(screen.recent ? _recent : const []),
            ),
            recentPreviewStoreProvider.overrideWithValue(
              MemoryRecentPreviewStore(),
            ),
            defaultPdfAppProvider.overrideWithValue(
              screen.defaultApp ? _Preview() : const NoDefaultPdfApp(),
            ),
          ],
        );
      }
    }
  }
}
