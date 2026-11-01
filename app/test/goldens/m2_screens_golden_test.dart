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
/// search, the properties, a restricted document, the unlock dialog, a
/// file that is not a PDF, the recent files and the default-app prompt. The
/// fake engine draws no pages, so the canvas shows the pages' paper only.
Future<void> main() async {
  final engine = FakeEngineService(
    documents: {
      _kiraPath: _kira,
      '$_home/Belgeler/Sözleşme (kısıtlı).pdf': _restricted,
      _bordroPath: _kira,
    },
    passwords: {_bordroPath: 'bordro2026'},
    failures: {
      _sheetPath: const EngineException(
        kind: EngineErrorKind.unsupported,
        messageKey: 'errorNotPdf',
      ),
    },
    searchResults: _matches,
  );
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
          engine: engine,
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
