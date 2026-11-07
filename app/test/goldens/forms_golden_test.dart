import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/forms/form_dialogs.dart';
import 'package:ferman/features/forms/form_state.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter/widgets.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _form = '/Users/elif/Belgeler/Adres değişikliği formu.pdf';
const String _flat = '/Users/elif/Belgeler/Otomatik ödeme talimatı.pdf';

const List<PageInfo> _pages = [PageInfo(width: 595, height: 842, handle: 100)];

FieldWidget _at(double left, double top, double width, {String? on}) =>
    FieldWidget(
      page: 100,
      rect: Rect.fromLTWH(left, top, width, 18),
      onState: on,
    );

/// A part of a5-1's form: personal data, the new address and the
/// declaration, some filled.
List<FieldInfo> _fields() => [
  FieldInfo(
    handle: 1,
    name: 'kisisel.tc',
    label: 'T.C. Kimlik No',
    kind: FieldKind.text,
    required: true,
    values: const ['41239876516'],
    filled: true,
    widgets: [_at(70, 150, 150)],
  ),
  FieldInfo(
    handle: 2,
    name: 'kisisel.dogum',
    label: 'Doğum tarihi',
    kind: FieldKind.text,
    required: true,
    format: FieldFormatKind.date,
    datePattern: 'dd.mm.yyyy',
    values: const ['14.03.1994'],
    filled: true,
    widgets: [_at(240, 150, 100)],
  ),
  FieldInfo(
    handle: 3,
    name: 'kisisel.ad',
    label: 'Adı',
    kind: FieldKind.text,
    required: true,
    widgets: [_at(70, 190, 190)],
  ),
  FieldInfo(
    handle: 4,
    name: 'kisisel.soyad',
    label: 'Soyadı',
    kind: FieldKind.text,
    required: true,
    widgets: [_at(280, 190, 190)],
  ),
  FieldInfo(
    handle: 5,
    name: 'kisisel.medeni',
    label: 'Medeni hâli',
    kind: FieldKind.combo,
    options: const [
      FieldOption(export: 'bekar', display: 'Bekâr'),
      FieldOption(export: 'evli', display: 'Evli'),
    ],
    widgets: [_at(280, 230, 140)],
  ),
  FieldInfo(
    handle: 6,
    name: 'adres.hane',
    label: 'Hanede yaşayan kişi sayısı',
    kind: FieldKind.text,
    required: true,
    values: const ['0'],
    format: FieldFormatKind.number,
    min: 1,
    max: 20,
    problem: const FieldProblem(
      kind: FieldProblemKind.outOfRange,
      min: 1,
      max: 20,
    ),
    widgets: [_at(70, 290, 100)],
  ),
  FieldInfo(
    handle: 7,
    name: 'beyan.dogruluk',
    label: 'Doğruluk beyanı',
    kind: FieldKind.check,
    required: true,
    widgets: [_at(70, 350, 14, on: 'Yes')],
  ),
  const FieldInfo(
    handle: 8,
    name: 'beyan.imza',
    label: 'İmza',
    kind: FieldKind.signature,
    required: true,
    widgets: [
      FieldWidget(page: 100, rect: Rect.fromLTWH(70, 400, 180, 44)),
    ],
  ),
];

FakeEngineService _engine() =>
    FakeEngineService(
        documents: const {
          _form: OpenedDocument(id: 1, pages: _pages),
          _flat: OpenedDocument(id: 2, pages: _pages),
        },
      )
      ..initialFields[1] = _fields()
      ..fillTargetsByPage[100] = const FillTargets(
        targets: [
          FillTarget(
            kind: FillTargetKind.line,
            rect: Rect.fromLTRB(200, 180, 450, 181),
          ),
          FillTarget(
            kind: FillTargetKind.comb,
            rect: Rect.fromLTWH(200, 220, 264, 26),
            cells: 11,
          ),
        ],
      );

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FermanApp)));

Future<void> _opened(WidgetTester tester, String path) async {
  final container = _container(tester);
  await container.read(documentOpenerProvider.notifier).open([path]);
  await tester.pumpAndSettle();
  container.read(shellModeProvider.notifier).select(FermanMode.sign);
  await tester.pumpAndSettle();
}

/// Fill & Sign (a5-1, a5-1d, a5-2, a5-4) and G47's Finish dialog in light
/// and dark × en, tr and ar. Goldens run on Linux CI only.
Future<void> main() async {
  final screens = <String, Future<void> Function(WidgetTester)>{
    'form_fields': (tester) async {
      await _opened(tester, _form);
      _container(tester).read(formSessionProvider.notifier)
        ..options(order: true)
        ..focus(3);
      await tester.pumpAndSettle();
    },
    'form_error': (tester) async {
      await _opened(tester, _form);
      _container(tester).read(formSessionProvider.notifier)
        ..attempt()
        ..focus(6);
      await tester.pumpAndSettle();
    },
    'form_finish': (tester) async {
      await _opened(tester, _form);
      _container(tester)
          .read(organizeDialogProvider.notifier)
          .show(FormFinishDialog(done: (_) {}));
      await tester.pumpAndSettle();
    },
    'fill_anything': (tester) async {
      await _opened(tester, _flat);
    },
  };
  const boards = {
    'form_fields': 'a5-1',
    'form_error': 'a5-2',
    'fill_anything': 'a5-4',
  };
  for (final MapEntry(key: screen, value: open) in screens.entries) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: language != GoldenLanguage.en
              ? null
              : theme == GoldenTheme.light
              ? boards[screen]
              : screen == 'form_fields'
              ? 'a5-1d'
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ).copyWith(commenterName: 'Elif'),
          engine: _engine(),
          // A Dialog hides while tickers are muted.
          muteTickers: screen != 'form_finish',
          open: open,
        );
      }
    }
  }
}
