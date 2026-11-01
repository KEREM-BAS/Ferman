import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../onboarding/ferman_app_harness.dart';

const String _kira = '/docs/Kira sözleşmesi.pdf';
const String _fatura = '/docs/Fatura.pdf';
const String _gone = '/docs/Silinen.pdf';

const OpenedDocument _document = OpenedDocument(
  id: 1,
  pages: [PageInfo(width: 595, height: 842)],
);

RecentEntry _entry(String path) => RecentEntry(
  path: path,
  name: path.split('/').last,
  opened: DateTime.utc(2026, 11),
);

Future<ProviderContainer> _start(
  WidgetTester tester, {
  required bool reopen,
}) async {
  await pumpFermanApp(
    tester,
    settings: AppSettings(
      onboardingCompleted: true,
      reopenDocuments: reopen,
      lastDocuments: const [_kira, _gone, _fatura],
    ),
    engine: FakeEngineService(
      documents: {
        _kira: _document,
        _fatura: const OpenedDocument(
          id: 2,
          pages: [PageInfo(width: 595, height: 842)],
        ),
      },
    ),
    // The gone file is on the list, but the engine does not find it.
    recentFiles: [_entry(_kira), _entry(_gone), _entry(_fatura)],
  );
  return ProviderScope.containerOf(tester.element(find.byType(Overlay).first));
}

List<String?> _tabs(ProviderContainer container) => [
  for (final document in container.read(shellDocumentsProvider).documents)
    document.path,
];

void main() {
  testWidgets('the documents from last time open again in their order; a '
      'file that is gone is skipped and left off the list (B079)', (
    tester,
  ) async {
    final container = await _start(tester, reopen: true);
    expect(find.byType(FmStart), findsNothing);
    expect(_tabs(container), [_kira, _fatura]);
    expect(container.read(documentOpenerProvider), isNull);

    container.read(documentOpenerProvider.notifier).close(_kira);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).lastDocuments, [_fatura]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('with the switch off Start shows and nothing opens, while the '
      'open tabs are still kept', (tester) async {
    final container = await _start(tester, reopen: false);
    expect(find.byType(FmStart), findsOne);
    expect(container.read(settingsProvider).lastDocuments, isEmpty);

    await container.read(documentOpenerProvider.notifier).open([_kira]);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).lastDocuments, [_kira]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  test('the switch and the list survive the JSON round trip', () {
    const settings = AppSettings(
      reopenDocuments: false,
      lastDocuments: [_kira, _fatura],
    );
    expect(AppSettings.fromJson(settings.toJson()), settings);
    expect(AppSettings.fromJson(const {}).reopenDocuments, isTrue);
    expect(
      AppSettings.fromJson(const {
        'lastDocuments': [_kira, 3, ''],
      }).lastDocuments,
      [_kira],
    );
  });
}
