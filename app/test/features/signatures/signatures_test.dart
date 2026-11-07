import 'dart:convert';

import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/signatures/add_signature_dialog.dart';
import 'package:ferman/features/signatures/saved_signatures.dart';
import 'package:ferman/features/signatures/sign_tools.dart';
import 'package:ferman/features/signatures/signature_placement_overlay.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';
import '../shell/shell_host.dart';

const String _path = '/Belgeler/Form.pdf';
const String _folder = '/data/Signatures';

const List<PageInfo> _pages = [
  PageInfo(width: 595, height: 842, handle: 7),
  PageInfo(width: 595, height: 842, handle: 8),
];

const AnnotationColor _blue = AnnotationColor(0.1, 0.19, 0.44);

const SavedSignature _typed = SavedSignature(
  name: 'signature-1.json',
  ink: TypedInk(text: 'Ayşe Yılmaz', family: 'Caveat'),
  color: _blue,
);

void main() {
  group('SavedSignature', () {
    test('each ink round-trips through its file', () {
      const drawn = SavedSignature(
        name: 'b',
        ink: DrawnInk(
          strokes: [
            [Offset(1, 2), Offset(3, 4)],
          ],
          width: 2.2,
        ),
        color: _blue,
        initials: true,
      );
      final image = SavedSignature(
        name: 'c',
        ink: ImageInk(Uint8List.fromList([1, 2, 3])),
        color: _blue,
      );
      for (final each in [_typed, drawn, image]) {
        final back = SavedSignature.fromFile(each.name, each.toFile())!;
        expect(back.name, each.name);
        expect(back.initials, each.initials);
        expect(back.color.blue, each.color.blue);
        switch ((back.ink, each.ink)) {
          case (final TypedInk a, final TypedInk b):
            expect((a.text, a.family), (b.text, b.family));
          case (final DrawnInk a, final DrawnInk b):
            expect(a.strokes, b.strokes);
            expect(a.width, b.width);
          case (final ImageInk a, final ImageInk b):
            expect(a.bytes, b.bytes);
          default:
            fail('the ink changed kind');
        }
      }
    });

    test('a file that is no signature is refused', () {
      Uint8List json(Object value) => utf8.encode(jsonEncode(value));
      const good = {
        'fermanSignature': 1,
        'initials': false,
        'color': [0, 0, 0],
        'typed': {'text': 'A', 'family': 'Caveat'},
      };
      expect(SavedSignature.fromFile('a', json(good)), isNotNull);
      for (final bad in [
        Uint8List(0),
        Uint8List.fromList([0xff]),
        json(const <Object>[]),
        json({...good, 'fermanSignature': 2}),
        json({
          ...good,
          'color': [2, 0, 0],
        }),
        json({
          ...good,
          'typed': {'text': 'A', 'family': 'Comic Sans'},
        }),
        json({
          ...good,
          'typed': {'text': ' ', 'family': 'Caveat'},
        }),
        json({
          'fermanSignature': 1,
          'initials': false,
          'color': [0, 0, 0],
          'drawn': {
            'width': 2,
            'strokes': [
              [1, 2, 3],
            ],
          },
        }),
        json({
          'fermanSignature': 1,
          'initials': false,
          'color': [0, 0, 0],
          'image': '!!',
        }),
      ]) {
        expect(SavedSignature.fromFile('a', bad), isNull);
      }
    });

    test('initials take each word’s first letter in the locale’s capitals', () {
      expect(
        initialsOf(
          'ayşe  irmak yılmaz',
          LocaleCasing.forLocale(const Locale('tr')),
        ),
        'AİY',
      );
    });
  });

  group('in the app', () {
    late FakeEngineService engine;
    late FakeFilePickerService picker;
    late ProviderContainer container;
    late WidgetTester host;

    Future<void> open(WidgetTester tester) async {
      engine = FakeEngineService(
        documents: {_path: const OpenedDocument(id: 1, pages: _pages)},
      );
      picker = FakeFilePickerService(picked: [_path]);
      await pumpFermanApp(
        tester,
        engine: engine,
        home: '/home/elif',
        picker: picker,
        overrides: [
          signatureDirectoryProvider.overrideWith((ref) async => _folder),
        ],
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(FmStart)),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await container
          .read(settingsProvider.notifier)
          .change((old) => old.copyWith(commenterName: 'Ayşe Yılmaz'));
      container.read(shellModeProvider.notifier).select(FermanMode.sign);
      await settle(tester);
      host = tester;
    }

    Offset onPage(Offset at) {
      final view = container.read(viewerProvider)!;
      final page = view.placement.rects[0]!.shift(-view.offset);
      return host.getTopLeft(find.byType(DocumentView)) +
          page.topLeft +
          at * view.scale;
    }

    Future<List<AnnotationInfo>> marks() async =>
        (await engine.annotations(1)).annotations;

    testWidgets('a click makes a draft, and Enter places it as one step', (
      tester,
    ) async {
      await open(tester);
      container.read(signaturePlacementProvider.notifier).choose(_typed);
      await settle(tester);
      expect(find.byType(SignaturePlacementOverlay), findsOneWidget);
      await tester.tapAt(onPage(const Offset(300, 200)));
      await settle(tester);
      expect(await marks(), isEmpty, reason: 'a draft commits nothing');
      expect(
        find.textContaining(RegExp(r'^2\.44.×.0\.63.in · 0°$')),
        findsOneWidget,
      );
      // ⇧→ nudges it 10 pt.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      final mark = (await marks()).single;
      expect(mark.kind, AnnotationKind.stamp);
      expect(mark.icon, signatureStampName);
      expect(mark.page, 7);
      expect(mark.author, 'Ayşe Yılmaz');
      expect(mark.rect.center.dx, moreOrLessEquals(310, epsilon: 1));
      expect(container.read(signaturePlacementProvider), isNull);
      expect(find.byType(SignaturePlacementOverlay), findsNothing);
    });

    testWidgets('the round handle turns the draft, ⇧ in 15° steps', (
      tester,
    ) async {
      await open(tester);
      container.read(signaturePlacementProvider.notifier).choose(_typed);
      await settle(tester);
      await tester.tapAt(onPage(const Offset(300, 200)));
      await settle(tester);
      final scale = container.read(viewerProvider)!.scale;
      // A corner drag keeps the proportions: half as large again.
      await tester.dragFrom(
        onPage(const Offset(388, 222.5)),
        Offset(88 * scale, 22.5 * scale),
      );
      await settle(tester);
      expect(
        find.textContaining(RegExp(r'^3\.67.×.0\.94.in · 0°$')),
        findsOneWidget,
      );
      // The knob sits 28 px above the box's top centre.
      final knob =
          onPage(const Offset(344, 177.5)) -
          const Offset(0, SignaturePlacementOverlay.knobReach);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final gesture = await tester.startGesture(knob);
      await gesture.moveTo(knob + Offset(10 * scale, 0));
      await gesture.moveTo(onPage(const Offset(446, 109)));
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settle(tester);
      expect(find.textContaining(RegExp(r' · 45°$')), findsOneWidget);
    });

    testWidgets('a click in an unsigned signature field fills it', (
      tester,
    ) async {
      await open(tester);
      engine.initialFields[1] = [
        const FieldInfo(
          handle: 1,
          name: 'imza',
          kind: FieldKind.signature,
          required: true,
          widgets: [
            FieldWidget(page: 7, rect: Rect.fromLTWH(100, 100, 200, 50)),
          ],
        ),
      ];
      container.read(signaturePlacementProvider.notifier).choose(_typed);
      await settle(tester);
      await tester.tapAt(onPage(const Offset(150, 120)));
      await settle(tester);
      // A click beside the draft places it.
      await tester.tapAt(onPage(const Offset(400, 250)));
      await settle(tester);
      final mark = (await marks()).single;
      expect(mark.rect, const Rect.fromLTWH(100, 100, 200, 50));
      final field = (await engine.formFields(1)).fields.single;
      expect(field.signature, mark.handle);
      expect(field.filled, isTrue);
    });

    testWidgets('Esc drops the draft, then stops placing', (tester) async {
      await open(tester);
      container.read(signaturePlacementProvider.notifier).choose(_typed);
      await settle(tester);
      await tester.tapAt(onPage(const Offset(300, 200)));
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(container.read(signaturePlacementProvider), isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(container.read(signaturePlacementProvider), isNull);
      expect(await marks(), isEmpty);
    });

    testWidgets('the dialog hides styles that cannot write the name', (
      tester,
    ) async {
      await open(tester);
      container
          .read(organizeDialogProvider.notifier)
          .show(const AddSignatureDialog(yourName: 'Ayşe Yılmaz'));
      await settle(tester);
      expect(find.byType(AddSignatureDialog), findsOneWidget);
      // Homemade Apple has no ş (G158).
      Finder tile(String family) => find.byWidgetPredicate(
        (widget) =>
            widget is FermanInteractive && widget.semanticLabel == family,
      );
      expect(tile('Caveat'), findsOneWidget);
      expect(tile('Dancing Script'), findsOneWidget);
      expect(tile('Homemade Apple'), findsNothing);
      expect(find.text('Saved only on this device.'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'أحمد');
      await settle(tester);
      expect(
        find.textContaining('No handwriting style can write'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Button>(
              find
                  .ancestor(
                    of: find.text('Add signature'),
                    matching: find.byType(Button),
                  )
                  .last,
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('Add signature saves it and makes it the one to place', (
      tester,
    ) async {
      await open(tester);
      container
          .read(organizeDialogProvider.notifier)
          .show(const AddSignatureDialog(yourName: 'Ayşe Yılmaz'));
      await settle(tester);
      await tester.tap(
        find
            .ancestor(
              of: find.text('Add signature'),
              matching: find.byType(Button),
            )
            .last,
      );
      await settle(tester);
      expect(find.byType(AddSignatureDialog), findsNothing);
      final files = engine.savedSignatureFiles[_folder]!;
      final saved = SavedSignature.fromFile(
        files.keys.single,
        files.values.single,
      )!;
      expect((saved.ink as TypedInk).text, 'Ayşe Yılmaz');
      expect(container.read(signaturePlacementProvider)?.name, saved.name);
      expect(container.read(savedSignaturesProvider).value, hasLength(1));
    });

    testWidgets('Image takes a chosen picture', (tester) async {
      await open(tester);
      picker.imageFile = Uint8List.fromList([1, 2, 3]);
      container
          .read(organizeDialogProvider.notifier)
          .show(const AddSignatureDialog(yourName: 'A'));
      await settle(tester);
      await tester.tap(find.text('Image'));
      await settle(tester);
      await tester.tap(find.text('Choose image…'));
      await settle(tester);
      expect(
        find.byKey(const ValueKey<String>('SignaturePad.chosen')),
        findsOneWidget,
      );
      await tester.tap(find.text('Save on this device'));
      await settle(tester);
      await tester.tap(
        find
            .ancestor(
              of: find.text('Add signature'),
              matching: find.byType(Button),
            )
            .last,
      );
      await settle(tester);
      expect(engine.savedSignatureFiles[_folder], isNull);
      expect(container.read(signaturePlacementProvider)?.ink, isA<ImageInk>());
    });

    testWidgets('the Sign menu lists what is saved, and ⌥S places the first', (
      tester,
    ) async {
      await open(tester);
      engine.savedSignatureFiles[_folder] = {_typed.name: _typed.toFile()};
      container.invalidate(savedSignaturesProvider);
      await settle(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is ToolButton && widget.label == 'Sign',
        ),
      );
      await settle(tester);
      expect(find.byType(SignMenu), findsOneWidget);
      expect(find.text('SIGNATURES'), findsOneWidget);
      expect(find.text('Add signature…'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settle(tester);
      expect(find.byType(SignMenu), findsNothing);
      expect(container.read(signaturePlacementProvider)?.name, _typed.name);
    });

    testWidgets('Initials with none saved opens the dialog on Initials', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is ToolButton && widget.label == 'Initials',
        ),
      );
      await settle(tester);
      expect(find.text('Add initials'), findsWidgets);
      expect(
        tester
            .widget<AddSignatureDialog>(find.byType(AddSignatureDialog))
            .initials,
        isTrue,
      );
    });

    testWidgets('⇧S opens the dialog in Fill & Sign', (tester) async {
      await open(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settle(tester);
      expect(find.byType(AddSignatureDialog), findsOneWidget);
    });
  });

  testWidgets('the overflow submenu lists the saved ones (B093)', (
    tester,
  ) async {
    late List<MenuItem> items;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(
          builder: (context) {
            items = signMenuItems(context, AppLocalizations.of(context), const [
              _typed,
            ]);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(items.map((item) => item.label), contains('Ayşe Yılmaz'));
    expect(items.last.disabled, isTrue);
  });
}
