import 'dart:async';
import 'dart:convert';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/settings/advanced_pane.dart';
import 'package:ferman/features/settings/fonts_pane.dart';
import 'package:ferman/features/settings/licences_pane.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/settings/signatures_pane.dart';
import 'package:ferman/features/signatures/saved_signatures.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';

const _future = 'Available in a future version';
const _folder = '/data/Signatures';

/// Opens Settings on [pane] and settles; the app's container.
Future<ProviderContainer> _open(WidgetTester tester, SettingsPane pane) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(FmStart)),
  );
  unawaited(
    container.read(routerProvider).push(Routes.settingsPane(pane.path)),
  );
  await tester.pumpAndSettle();
  return container;
}

const List<InstalledFont> _fonts = [
  InstalledFont(
    family: 'IBM Plex Serif',
    origin: FontOrigin.bundled,
    scripts: {
      FontScript.turkish,
      FontScript.latinExtended,
      FontScript.cyrillic,
      FontScript.greek,
    },
  ),
  InstalledFont(
    family: 'Georgia',
    origin: FontOrigin.installed,
    scripts: {FontScript.turkish, FontScript.latinExtended},
  ),
  InstalledFont(
    family: 'Hiragino Mincho ProN',
    origin: FontOrigin.installed,
    scripts: {FontScript.latinExtended, FontScript.cjk},
  ),
];

void main() {
  group('Fonts (a11-1d)', () {
    testWidgets('lists the fonts that cover Turkish; All fonts and the '
        'search change the list', (tester) async {
      final engine = FakeEngineService()..installed = _fonts;
      await pumpFermanApp(tester, engine: engine);
      await _open(tester, SettingsPane.fonts);
      expect(find.byType(FontsPane), findsOneWidget);
      expect(find.text('IBM Plex Serif'), findsOneWidget);
      expect(find.text('Included with Ferman'), findsOneWidget);
      expect(find.text('Georgia'), findsOneWidget);
      expect(find.text('Hiragino Mincho ProN'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).placeholder,
        'Search 3 installed fonts',
      );
      // The chips: covered in the success colour, the others struck.
      final cy = tester
          .widgetList<Text>(find.text('CY'))
          .map((text) => text.style?.decoration);
      expect(cy, [null, TextDecoration.lineThrough]);

      final filter = tester.widget<Select<Object?>>(
        find.byWidgetPredicate((widget) => widget is Select).last,
      );
      expect(filter.options.last.disabled, isTrue);
      expect(filter.options.last.disabledReason, _future);
      await tester.tap(find.text('Covers Turkish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All fonts').last);
      await tester.pumpAndSettle();
      expect(find.text('Hiragino Mincho ProN'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).last, 'geo');
      await tester.pumpAndSettle();
      expect(find.text('Georgia'), findsOneWidget);
      expect(find.text('IBM Plex Serif'), findsNothing);
      await tester.enterText(find.byType(EditableText).last, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No fonts match'), findsOneWidget);
    });
  });

  group('Signatures and certificates (a11-1e)', () {
    testWidgets('lists the saved signatures and deletes one; the '
        'certificate parts are disabled', (tester) async {
      final engine = FakeEngineService();
      engine.savedSignatureFiles[_folder] = {
        'signature-1.json': const SavedSignature(
          ink: TypedInk(text: 'Ayşe Yılmaz', family: 'Caveat'),
          color: AnnotationColor(0.1, 0.2, 0.4),
        ).toFile(),
        'initials-1.json': const SavedSignature(
          ink: TypedInk(text: 'AY', family: 'Caveat'),
          color: AnnotationColor(0.1, 0.2, 0.4),
          initials: true,
        ).toFile(),
      };
      await pumpFermanApp(
        tester,
        engine: engine,
        overrides: [
          signatureDirectoryProvider.overrideWith((ref) async => _folder),
        ],
      );
      await _open(tester, SettingsPane.signatures);
      expect(find.byType(SignaturesPane), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Typed'), findsOneWidget);
      expect(find.text('Initials'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Ayşe Yılmaz'),
                matching: find.byType(Stack),
              )
              .first,
          matching: find.bySemanticsLabel('Delete saved signature'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ayşe Yılmaz'), findsNothing);
      expect(engine.savedSignatureFiles[_folder]!.keys, ['initials-1.json']);

      final add = tester.widget<Button>(
        find.widgetWithText(Button, 'Add certificate file…'),
      );
      expect(add.disabledReason, _future);
      final revocation = tester.widget<Switch>(
        find.widgetWithText(
          Switch,
          'Check revocation online when opening '
          'signed files',
        ),
      );
      expect(revocation.disabled, isTrue);
      expect(revocation.value, isFalse);
    });

    testWidgets('says when nothing is saved', (tester) async {
      await pumpFermanApp(
        tester,
        overrides: [
          signatureDirectoryProvider.overrideWith((ref) async => _folder),
        ],
      );
      await _open(tester, SettingsPane.signatures);
      expect(
        find.text('No saved signatures yet. Fill & Sign › Sign makes one.'),
        findsOneWidget,
      );
    });
  });

  group('Advanced (a11-1k)', () {
    testWidgets('exports the settings without the documents open last', (
      tester,
    ) async {
      final picker = FakeFilePickerService(saveTo: '/tmp/out.json');
      await pumpFermanApp(
        tester,
        picker: picker,
        settings: const AppSettings(
          onboardingCompleted: true,
          lastDocuments: ['/Users/elif/kira.pdf'],
          commenterName: 'Elif',
        ),
      );
      await _open(tester, SettingsPane.advanced);
      await tester.tap(find.text('Export settings…'));
      await tester.pumpAndSettle();
      expect(picker.saves, ['Ferman settings.json']);
      final json = jsonDecode(
        utf8.decode(picker.written['/tmp/out.json']!),
      ) as Map<String, Object?>;
      expect(json.containsKey('lastDocuments'), isFalse);
      expect(json['commenterName'], 'Elif');
      expect(find.text('Settings exported'), findsOneWidget);
    });

    testWidgets('an import that is not a settings file says so and '
        'changes nothing', (tester) async {
      final picker = FakeFilePickerService()
        ..stampFile = Uint8List.fromList(utf8.encode('[1, 2]'));
      final store = await pumpFermanApp(tester, picker: picker);
      await _open(tester, SettingsPane.advanced);
      await tester.tap(find.text('Import settings…'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t import the settings'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(store.saves, 0);
    });

    testWidgets('an import asks, then replaces the settings but keeps the '
        'open documents', (tester) async {
      final picker = FakeFilePickerService()
        ..stampFile = Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'version': 1,
              'theme': 'dark',
              'lastDocuments': ['/elsewhere/evil.pdf'],
              'onboardingCompleted': false,
              'commenterName': 'x' * 300,
              'injected': true,
            }),
          ),
        );
      await pumpFermanApp(
        tester,
        picker: picker,
        settings: const AppSettings(
          onboardingCompleted: true,
          lastDocuments: ['/Users/elif/kira.pdf'],
        ),
      );
      final container = await _open(tester, SettingsPane.advanced);
      // The start screen keeps the list of open documents itself.
      final before = container.read(settingsProvider).lastDocuments;
      await tester.tap(find.text('Import settings…'));
      await tester.pumpAndSettle();
      expect(find.text('Replace your settings?'), findsOneWidget);
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      final settings = container.read(settingsProvider);
      expect(settings.themeMode.name, 'dark');
      expect(settings.lastDocuments, before);
      expect(settings.lastDocuments, isNot(contains('/elsewhere/evil.pdf')));
      expect(settings.onboardingCompleted, isTrue);
      expect(settings.commenterName, isNull);
      expect(settings.unknown, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('reset asks, then keeps first run, documents and stamps', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          markEdited: false,
          lastDocuments: ['/Users/elif/kira.pdf'],
          myStamps: ['{}'],
        ),
      );
      final container = await _open(tester, SettingsPane.advanced);
      // The start screen keeps the list of open documents itself.
      final before = container.read(settingsProvider).lastDocuments;
      await tester.tap(find.text('Reset settings…'));
      await tester.pumpAndSettle();
      expect(find.text('Reset every setting?'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      final settings = container.read(settingsProvider);
      expect(settings.markEdited, isTrue);
      expect(settings.onboardingCompleted, isTrue);
      expect(settings.lastDocuments, before);
      expect(settings.myStamps, ['{}']);
    });

    testWidgets('the unfinished controls are disabled with the reason', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      await _open(tester, SettingsPane.advanced);
      for (final label in [
        'Use the graphics card to draw pages',
        'Show the PDF object inspector (for developers)',
      ]) {
        final control = tester.widget<Switch>(
          find.widgetWithText(Switch, label),
        );
        expect(control.disabledReason, _future, reason: label);
      }
      expect(
        tester
            .widget<Button>(find.widgetWithText(Button, 'Show log files'))
            .disabledReason,
        _future,
      );
      final cache = tester.widget<Select<int>>(find.byType(Select<int>));
      expect(cache.value, AdvancedPane.engineCacheMegabytes);
      expect(cache.options.where((option) => option.disabled), hasLength(3));
    });
  });

  group('Editing (a11-1c)', () {
    testWidgets('Keep versions reaches the engine and is stored', (
      tester,
    ) async {
      final engine = FakeEngineService();
      await pumpFermanApp(tester, engine: engine);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FmStart)),
      );
      final _ = container.read(documentEditorProvider);
      await _open(tester, SettingsPane.editing);
      final select = tester.widget<Select<bool>>(find.byType(Select<bool>));
      expect(select.options.map((option) => option.label), [
        'Kept for 30 days',
        'Don’t keep versions',
      ]);
      select.onChanged!(false);
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).keepVersions, isFalse);
      expect(engine.versionsEnabled, isFalse);
    });
  });

  group('Licences', () {
    setUp(LicenseRegistry.reset);
    tearDown(LicenseRegistry.reset);

    testWidgets('lists what ships by name, searches and opens a text', (
      tester,
    ) async {
      LicenseRegistry.addLicense(
        () => Stream.fromIterable([
          const LicenseEntryWithLineBreaks(['lopdf'], 'MIT License text'),
          const LicenseEntryWithLineBreaks(['PDFium'], 'BSD text'),
          // A package that only builds the app.
          const LicenseEntryWithLineBreaks(['build_runner'], 'BSD again'),
        ]),
      );
      await pumpFermanApp(tester);
      await _open(tester, SettingsPane.licences);
      expect(find.byType(LicencesPane), findsOneWidget);
      expect(find.text('lopdf'), findsOneWidget);
      expect(find.text('PDFium'), findsOneWidget);
      expect(find.text('build_runner'), findsNothing);
      await tester.tap(find.text('lopdf'));
      await tester.pumpAndSettle();
      expect(find.text('MIT License text'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'pdfi');
      await tester.pumpAndSettle();
      expect(find.text('lopdf'), findsNothing);
      expect(find.text('PDFium'), findsOneWidget);
    });
  });
}
