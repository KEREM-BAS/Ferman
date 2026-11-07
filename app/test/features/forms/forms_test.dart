import 'dart:async';

import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/forms/fill_anything.dart';
import 'package:ferman/features/forms/form_dialogs.dart';
import 'package:ferman/features/forms/form_overlay.dart';
import 'package:ferman/features/forms/form_panel.dart';
import 'package:ferman/features/forms/form_state.dart';
import 'package:ferman/features/save/document_closer.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/signatures/add_signature_dialog.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';

const String _path = '/docs/form.pdf';
const int _document = 9;
const int _page = 100;

const OpenedDocument _opened = OpenedDocument(
  id: _document,
  pages: [PageInfo(width: 595, height: 842, handle: _page)],
);

FieldWidget _at(double left, double top, {double width = 200, String? on}) =>
    FieldWidget(
      page: _page,
      rect: Rect.fromLTWH(left, top, width, 18),
      onState: on,
    );

final FieldInfo _name = FieldInfo(
  handle: 1,
  name: 'kisisel.ad',
  label: 'Adı',
  kind: FieldKind.text,
  required: true,
  widgets: [_at(100, 100)],
);

final FieldInfo _surname = FieldInfo(
  handle: 2,
  name: 'kisisel.soyad',
  label: 'Soyadı',
  kind: FieldKind.text,
  widgets: [_at(320, 100)],
);

final FieldInfo _declaration = FieldInfo(
  handle: 3,
  name: 'beyan',
  label: 'Doğruluk beyanı',
  kind: FieldKind.check,
  required: true,
  widgets: [_at(100, 200, width: 14, on: 'Yes')],
);

final FieldInfo _people = FieldInfo(
  handle: 4,
  name: 'hane',
  label: 'Hanede yaşayan kişi sayısı',
  kind: FieldKind.text,
  values: const ['0'],
  format: FieldFormatKind.number,
  min: 1,
  max: 20,
  problem: const FieldProblem(
    kind: FieldProblemKind.outOfRange,
    min: 1,
    max: 20,
  ),
  widgets: [_at(100, 260, width: 80)],
);

FakeEngineService _engine({List<FieldInfo>? fields}) =>
    FakeEngineService(documents: {_path: _opened})
      ..initialFields[_document] =
          fields ?? [_name, _surname, _declaration, _people];

/// The app in Fill & Sign with the document open.
Future<ProviderContainer> _open(
  WidgetTester tester,
  FakeEngineService engine, {
  Locale locale = const Locale('en', 'US'),
}) async {
  await pumpFermanApp(
    tester,
    engine: engine,
    systemLocales: [locale],
    home: '/docs',
    picker: FakeFilePickerService(picked: const [_path]),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(FmStart)),
  );
  await container
      .read(settingsProvider.notifier)
      .change((old) => old.copyWith(commenterName: 'Elif'));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  container.read(shellModeProvider.notifier).select(FermanMode.sign);
  await tester.pumpAndSettle();
  return container;
}

/// Where the point [point] of the page is on the screen, over [layer].
Offset _onScreen(
  ProviderContainer container,
  WidgetTester tester,
  Offset point,
  Type layer,
) {
  final view = container.read(viewerProvider)!;
  final rect = view.placement.rects[0]!;
  final origin = tester.getTopLeft(find.byType(layer));
  return origin + rect.topLeft + point * view.scale - view.offset;
}

Future<List<String>> _values(FakeEngineService engine, int handle) async =>
    (await engine.formFields(_document)).fields
        .firstWhere((field) => field.handle == handle)
        .values;

void main() {
  testWidgets('a form shows its bar, the panel with its fields and the '
      'navigation', (tester) async {
    await _open(tester, _engine());
    expect(find.byType(FormPanel), findsOneWidget);
    expect(find.byType(FormOverlay), findsOneWidget);
    expect(find.text('This PDF is a fillable form.'), findsOneWidget);
    expect(
      find.text('4 fields, 2 required. Tab moves to the next field.'),
      findsOneWidget,
    );
    expect(find.text('0 of 2 required fields'), findsOneWidget);
    // A section from the names' parent, and "Required" on empty ones.
    expect(find.text('kisisel'), findsOneWidget);
    expect(find.text('Required'), findsNWidgets(2));
    expect(find.text('2 required left'), findsOneWidget);
    expect(find.text('4 fields'), findsWidgets);
    // A value that fails what its field declares says so under it.
    expect(find.text('Enter a number from 1 to 20.'), findsOneWidget);
  });

  testWidgets('typing commits on Tab as one step and moves on; a check box '
      'takes its on-state', (tester) async {
    final engine = _engine();
    final container = await _open(tester, engine);
    await tester.tapAt(
      _onScreen(container, tester, const Offset(150, 109), FormOverlay),
    );
    await tester.pumpAndSettle();
    expect(container.read(formSessionProvider).current, 1);
    expect(find.text('Field 1 of 4'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'AYŞE');
    await tester.pump();
    // Not per keystroke (decision 16).
    expect(await _values(engine, 1), isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(await _values(engine, 1), ['AYŞE']);
    expect(container.read(formSessionProvider).current, 2);
    expect(find.text('1 required left'), findsOneWidget);

    await tester.tapAt(
      _onScreen(container, tester, const Offset(107, 209), FormOverlay),
    );
    await tester.pumpAndSettle();
    expect(await _values(engine, 3), ['Yes']);
    expect(find.text('All required filled'), findsOneWidget);
  });

  for (final fields in [null, const <FieldInfo>[]]) {
    final layer = fields == null ? FormOverlay : FillAnythingOverlay;
    testWidgets('closing with $layer still being typed takes the typing first '
        'and asks to save', (tester) async {
      final engine = _engine(fields: fields)
        ..fillTargetsByPage[_page] = const FillTargets();
      final container = await _open(tester, engine);
      await tester.tapAt(
        _onScreen(container, tester, const Offset(150, 109), layer),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Ayşe');
      await tester.pump();
      // ⌘W while the field still has the caret.
      unawaited(container.read(documentCloserProvider.notifier).close(_path));
      await tester.pumpAndSettle();
      expect(container.read(documentCloserProvider).asking?.path, _path);
      if (fields == null) {
        expect(await _values(engine, 1), ['Ayşe']);
      } else {
        final annotations = (await engine.annotations(_document)).annotations;
        expect(annotations.single.contents, 'Ayşe');
      }
    });
  }

  testWidgets('a value on a turned page turns with the page, sized by the '
      'field’s own height', (tester) async {
    final engine =
        FakeEngineService(
            documents: {
              _path: const OpenedDocument(
                id: _document,
                pages: [
                  PageInfo(
                    width: 842,
                    height: 595,
                    handle: _page,
                    rotation: 90,
                  ),
                ],
              ),
            },
          )
          ..initialFields[_document] = [
            const FieldInfo(
              handle: 1,
              name: 'ad',
              kind: FieldKind.text,
              values: ['AYŞE'],
              widgets: [
                FieldWidget(
                  page: _page,
                  rect: Rect.fromLTWH(100, 100, 14, 200),
                ),
              ],
            ),
          ];
    final container = await _open(tester, engine);
    final value = find.text('AYŞE');
    final turned = tester.widget<RotatedBox>(
      find.ancestor(of: value, matching: find.byType(RotatedBox)).first,
    );
    expect(turned.quarterTurns, 1);
    final scale = container.read(viewerProvider)!.scale;
    expect(
      tester.widget<Text>(value).style?.fontSize,
      closeTo(14 * FormOverlay.textShare * scale, 1e-6),
    );
  });

  testWidgets('Finish under Ask each time asks for the font first, then says '
      'which it took', (tester) async {
    final engine = _engine(fields: [_surname])
      ..wholeFormFonts = const ['IBM Plex Sans'];
    await _open(tester, engine);
    await tester.tap(find.widgetWithText(Button, 'Finish'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FormFinishDialog),
        matching: find.widgetWithText(Button, 'Save'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FormFontDialog), findsOneWidget);
    expect((await engine.formFields(_document)).fields, hasLength(1));
    await tester.tap(find.widgetWithText(Button, 'Use IBM Plex'));
    await tester.pumpAndSettle();
    expect((await engine.formFields(_document)).fields, isEmpty);
    expect(find.text('Characters added in IBM Plex'), findsOneWidget);
  });

  testWidgets('Finish with required fields empty shows them; filled, it asks '
      'and flattens', (tester) async {
    final engine = _engine(fields: [_name, _declaration]);
    final container = await _open(tester, engine);
    await tester.tap(find.widgetWithText(Button, 'Finish'));
    await tester.pumpAndSettle();
    expect(find.byType(FormFinishDialog), findsNothing);
    expect(find.text('Required to submit.'), findsNWidgets(2));
    expect(container.read(formSessionProvider).current, 1);

    await engine.setFieldValue(_document, 1, ['AYŞE'], name: 'Fill');
    await engine.setFieldValue(_document, 3, ['Yes'], name: 'Fill');
    container.invalidate(documentFormProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Finish'));
    await tester.pumpAndSettle();
    expect(find.byType(FormFinishDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(FormFinishDialog),
        matching: find.widgetWithText(Button, 'Save'),
      ),
    );
    await tester.pumpAndSettle();
    expect((await engine.formFields(_document)).fields, isEmpty);
  });

  testWidgets('Clear form asks first, then empties the fields as one step', (
    tester,
  ) async {
    final engine = _engine(
      fields: [
        _name.withValues(const ['AYŞE']),
        _surname,
      ],
    );
    await _open(tester, engine);
    await tester.tap(find.widgetWithText(Button, 'Clear form…'));
    await tester.pumpAndSettle();
    expect(find.byType(FormClearDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(Button, 'Clear form'));
    await tester.pumpAndSettle();
    expect(await _values(engine, 1), isEmpty);
  });

  testWidgets('Tab and ⇧Tab on the canvas move between the fields; a row '
      'goes to its field', (tester) async {
    final container = await _open(tester, _engine());
    await tester.tap(find.text('Soyadı'));
    await tester.pumpAndSettle();
    expect(container.read(formSessionProvider).current, 2);
    expect(find.text('Field 2 of 4'), findsOneWidget);
    // A click off the fields gives the canvas its keys back.
    await tester.tapAt(
      _onScreen(container, tester, const Offset(560, 150), FormOverlay),
    );
    await tester.pumpAndSettle();
    expect(container.read(formSessionProvider).current, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(container.read(formSessionProvider).current, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(container.read(formSessionProvider).current, 4);
  });

  testWidgets('Fill anything: a page without fields types on a line and '
      'checks a box, as text boxes and marks', (tester) async {
    final engine = _engine(fields: const [])
      ..fillTargetsByPage[_page] = const FillTargets(
        targets: [
          FillTarget(
            kind: FillTargetKind.line,
            rect: Rect.fromLTRB(200, 300, 450, 301),
          ),
          FillTarget(
            kind: FillTargetKind.check,
            rect: Rect.fromLTWH(200, 400, 12, 12),
          ),
        ],
      );
    final container = await _open(tester, engine);
    expect(find.text('This PDF has no form fields.'), findsOneWidget);
    expect(find.byType(FillAnythingPanel), findsOneWidget);
    expect(find.byType(FillAnythingOverlay), findsOneWidget);
    await tester.tapAt(
      _onScreen(container, tester, const Offset(250, 295), FillAnythingOverlay),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '1043 8826');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    var annotations = (await engine.annotations(_document)).annotations;
    expect(annotations.single.kind, AnnotationKind.freeText);
    expect(annotations.single.contents, '1043 8826');
    // On the line's baseline.
    expect(annotations.single.rect.bottom, closeTo(300, 0.01));

    await tester.tapAt(
      _onScreen(container, tester, const Offset(206, 406), FillAnythingOverlay),
    );
    await tester.pumpAndSettle();
    annotations = (await engine.annotations(_document)).annotations;
    expect(annotations.last.kind, AnnotationKind.ink);
  });

  testWidgets('Fill anything’s bare keys work only with its panel open '
      '(decision 24)', (tester) async {
    final container = await _open(tester, _engine(fields: const []));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.pumpAndSettle();
    expect(container.read(fillToolsStateProvider).tool, FillTool.cross);
    container.read(shellPanelOpenProvider.notifier).toggle();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(container.read(fillToolsStateProvider).tool, FillTool.cross);
  });

  testWidgets('Fill anything’s Signature opens the signature dialog', (
    tester,
  ) async {
    await _open(tester, _engine(fields: const []));
    await tester.tap(
      find.descendant(
        of: find.byType(FillAnythingPanel),
        matching: find.text('Signature'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AddSignatureDialog), findsOneWidget);
  });

  for (final locale in const [Locale('tr', 'TR'), Locale('ar', 'SA')]) {
    testWidgets('the form lays out in ${locale.languageCode} with its order, '
        'errors and panels', (tester) async {
      final container = await _open(tester, _engine(), locale: locale);
      container.read(formSessionProvider.notifier)
        ..options(order: true)
        ..attempt()
        ..focus(1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      container.read(fillToolsStateProvider.notifier).pick(FillTool.text);
      await tester.pumpAndSettle();
      expect(find.byType(FillAnythingPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('a date takes its field’s own pattern', () {
    final day = DateTime(2026, 3, 4);
    expect(formatFieldDate('dd.mm.yyyy', day), '04.03.2026');
    expect(formatFieldDate('m/d/yy', day), '3/4/26');
    // Every pattern AFDate_Format names, as the engine's check reads them
    // (ferman_ops::forms' dates_read_by_their_declared_pattern has the same).
    final picked = DateTime(2026, 11, 7);
    const expected = {
      'm/d': '11/7',
      'm/d/yy': '11/7/26',
      'mm/dd/yy': '11/07/26',
      'mm/yy': '11/26',
      'd-mmm': '7-Nov',
      'd-mmm-yy': '7-Nov-26',
      'dd-mmm-yy': '07-Nov-26',
      'yy-mm-dd': '26-11-07',
      'mmm-yy': 'Nov-26',
      'mmmm-yy': 'November-26',
      'mmm d, yyyy': 'Nov 7, 2026',
      'mmmm d, yyyy': 'November 7, 2026',
      'm/d/yy h:MM tt': '11/7/26 12:00 am',
      'm/d/yy HH:MM': '11/7/26 00:00',
    };
    for (final MapEntry(key: pattern, value: text) in expected.entries) {
      expect(formatFieldDate(pattern, picked), text, reason: pattern);
    }
    expect(
      formatFieldDate('dd.mm.yyyy HH:MM', DateTime(2026, 11, 7, 15, 5)),
      '07.11.2026 15:05',
    );
  });

  test('a line takes text on its baseline; marks are strokes in the box', () {
    const line = FillTarget(
      kind: FillTargetKind.line,
      rect: Rect.fromLTRB(10, 50, 110, 51),
    );
    expect(fillTextRect(line, 10), const Rect.fromLTRB(10, 35, 110, 50));
    expect(fillTargetAt(const [line], const Offset(20, 45)), line);
    expect(fillTargetAt(const [line], const Offset(20, 20)), isNull);
    const box = Rect.fromLTWH(0, 0, 10, 10);
    expect(markStrokes(FillTool.cross, box), hasLength(2));
    expect(markStrokes(FillTool.check, box).single, hasLength(3));
  });

  testWidgets('the canvas leaves the widgets to the field overlay and draws '
      'them in the other modes (B203)', (tester) async {
    final engine = FakeEngineService(
      documents: {
        _path: OpenedDocument(
          id: _document,
          pages: _opened.pages,
          formFields: 1,
        ),
      },
    )..initialFields[_document] = [_name];
    final container = await _open(tester, engine);
    expect(engine.formWidgetRequests.last, isFalse);
    container.read(fillToolsStateProvider.notifier).pick(FillTool.text);
    await tester.pumpAndSettle();
    expect(engine.formWidgetRequests.last, isTrue);
    container.read(fillToolsStateProvider.notifier).pick(FillTool.fields);
    await tester.pumpAndSettle();
    expect(engine.formWidgetRequests.last, isFalse);
    container.read(shellModeProvider.notifier).select(FermanMode.view);
    await tester.pumpAndSettle();
    expect(engine.formWidgetRequests.last, isTrue);
  });
}
