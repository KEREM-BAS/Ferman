import 'dart:convert';

import 'package:ferman/design/components/annotations/annotation_color.dart'
    as design;
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/stamps/comment_tool_menus.dart';
import 'package:ferman/features/stamps/create_stamp_dialog.dart';
import 'package:ferman/features/stamps/mark_placement_overlay.dart';
import 'package:ferman/features/stamps/stamp_design.dart';
import 'package:ferman/features/stamps/stamp_library.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';
import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';
import '../shell/shell_host.dart';

const String _path = '/Belgeler/Kira.pdf';

const List<PageInfo> _pages = [
  PageInfo(width: 595, height: 842, handle: 7),
  PageInfo(width: 595, height: 842, handle: 8),
];

final RegionFormat _format = RegionFormat.forRegion(Region.forCode('TR'));
final DateTime _now = DateTime(2026, 10, 13, 14, 36);

void main() {
  group('StampDesign', () {
    test('capitals follow the stamp language, not the UI', () {
      expect(
        const StampDesign(
          label: 'İncelendi',
          tone: StampTone.ink,
          language: StampLanguage.turkish,
        ).capitals,
        'İNCELENDİ',
      );
      expect(turkishStamps[2].capitals, 'GİZLİ');
      expect(
        const StampDesign(label: 'gizli', tone: StampTone.ink).capitals,
        'GIZLI',
      );
    });

    test('the second line is filled as a4-3 draws it', () {
      expect(
        namedStamps[0].metaAt(_now, _format, 'Av. Deniz Aksoy'),
        'Av. Deniz Aksoy · 13.10.2026',
      );
      expect(namedStamps[1].metaAt(_now, _format, 'x'), '13.10.2026 14:36');
      expect(standardStamps[0].metaAt(_now, _format, 'x'), isNull);
      // No name given: the line has no leading separator.
      expect(namedStamps[0].metaAt(_now, _format, '  '), '13.10.2026');
    });

    test('a custom stamp round-trips through its file', () {
      const stamp = StampDesign(
        label: 'İncelendi',
        tone: StampTone.green,
        language: StampLanguage.turkish,
        name: 'Av. Deniz Aksoy',
        withName: true,
        withDate: true,
      );
      expect(StampDesign.fromFile(stamp.toFile()), stamp);
    });

    test('a file that is no stamp is refused', () {
      Uint8List json(Object value) => utf8.encode(jsonEncode(value));
      const good = {
        'fermanStamp': 1,
        'label': 'A',
        'tone': 'ink',
        'language': 'english',
      };
      expect(StampDesign.fromFile(json(good)), isNotNull);
      for (final bad in [
        Uint8List(0),
        Uint8List.fromList([0xff, 0xfe]),
        json(const <Object>[]),
        json({...good, 'fermanStamp': 2}),
        json({...good, 'label': '   '}),
        json({...good, 'label': 7}),
        json({...good, 'label': 'x' * (StampDesign.longestLabel + 1)}),
        json({...good, 'tone': 'mauve'}),
        json({...good, 'language': 'klingon'}),
        json({...good, 'name': 7}),
        json({...good, 'name': 'x' * (StampDesign.longestName + 1)}),
        Uint8List(StampDesign.largestFile + 1),
      ]) {
        expect(StampDesign.fromFile(bad), isNull);
      }
    });

    test('a stamp stays on the page', () {
      const page = Size(100, 100);
      expect(
        keptOnPage(const Rect.fromLTWH(90, -5, 20, 10), page),
        const Rect.fromLTWH(80, 0, 20, 10),
      );
      expect(
        keptOnPage(const Rect.fromLTWH(5, 5, 200, 10), page),
        const Rect.fromLTWH(-50, 5, 200, 10),
      );
    });
  });

  test('a shape keeps what was drawn', () {
    const color = AnnotationColor(1, 0, 0);
    final arrow = shapeAnnotation(
      ShapeTool.arrow,
      color: color,
      author: 'a',
      b: const Offset(10, 20),
    );
    expect(arrow.kind, AnnotationKind.line);
    expect(arrow.arrow, isTrue);
    expect(arrow.points.single, [Offset.zero, const Offset(10, 20)]);
    expect(arrow.stroke, shapeStroke);
    final pentagon = defaultShape(
      ShapeTool.polygon,
      const Offset(50, 50),
      color: color,
      author: 'a',
    );
    expect(pentagon.kind, AnnotationKind.polygon);
    expect(pentagon.points.single, hasLength(5));
  });

  group('in the app', () {
    late FakeEngineService engine;
    late FakeFilePickerService picker;
    late ProviderContainer container;
    late int finished;
    late List<int> placed;
    OverlayEntry? entry;

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
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(FmStart)),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      container.read(shellModeProvider.notifier).select(FermanMode.comment);
      await settle(tester);
      finished = 0;
      placed = [];
    }

    /// Shows [child] over the window, as the shell will show it over the
    /// canvas, with the overlay's origin at the window's.
    Future<void> show(WidgetTester tester, Widget child) async {
      entry = OverlayEntry(builder: (_) => child);
      addTearDown(() {
        entry?.remove();
        entry = null;
      });
      tester.state<OverlayState>(find.byType(Overlay).first).insert(entry!);
      await settle(tester);
    }

    Future<void> placing(WidgetTester tester, AnnotationTool tool) => show(
      tester,
      Positioned.fill(
        child: MarkPlacementOverlay(
          tool: tool,
          color: design.AnnotationColor.red,
          author: 'Av. Deniz Aksoy',
          onPlaced: placed.add,
          onFinished: () => finished++,
        ),
      ),
    );

    /// Where the point [at] of the first page is on the window.
    Offset onPage(Offset at) {
      final view = container.read(viewerProvider)!;
      final page = view.placement.rects[0]!.shift(-view.offset);
      return page.topLeft + at * view.scale;
    }

    Future<List<AnnotationInfo>> marks() async =>
        (await engine.annotations(1)).annotations;

    testWidgets('a dragged rectangle is one step on its page', (tester) async {
      await open(tester);
      await placing(tester, AnnotationTool.shapes);
      final gesture = await tester.startGesture(onPage(const Offset(100, 200)));
      await gesture.moveTo(onPage(const Offset(120, 210)));
      await tester.pump();
      await gesture.moveTo(onPage(const Offset(300, 400)));
      await tester.pump();
      expect(await marks(), isEmpty, reason: 'nothing commits during a drag');
      await gesture.up();
      await settle(tester);
      final mark = (await marks()).single;
      expect(mark.kind, AnnotationKind.square);
      expect(mark.page, 7);
      expect(mark.author, 'Av. Deniz Aksoy');
      expect(mark.rect.left, moreOrLessEquals(100, epsilon: 1));
      expect(mark.rect.bottom, moreOrLessEquals(400, epsilon: 1));
      expect(placed, [mark.handle]);
      expect(finished, 1);
    });

    testWidgets('a slip of the mouse places nothing', (tester) async {
      await open(tester);
      await placing(tester, AnnotationTool.shapes);
      final gesture = await tester.startGesture(onPage(const Offset(100, 200)));
      await gesture.moveTo(
        onPage(const Offset(100, 200)) + const Offset(30, 0),
      );
      await gesture.moveTo(onPage(const Offset(100, 200)));
      await gesture.up();
      await settle(tester);
      expect(await marks(), isEmpty);
      expect(finished, 0);
    });

    testWidgets('Keep tool selected leaves the tool on', (tester) async {
      await open(tester);
      container.read(commentToolMenusProvider.notifier)
        ..toggleKeep()
        ..chooseShape(ShapeTool.ellipse);
      await placing(tester, AnnotationTool.shapes);
      await tester.dragFrom(
        onPage(const Offset(100, 200)),
        const Offset(80, 60),
      );
      await settle(tester);
      expect((await marks()).single.kind, AnnotationKind.circle);
      expect(finished, 0);
    });

    testWidgets('a polygon takes a click per corner and Enter', (tester) async {
      await open(tester);
      container
          .read(commentToolMenusProvider.notifier)
          .chooseShape(ShapeTool.polygon);
      await placing(tester, AnnotationTool.shapes);
      Future<void> click(Offset at) async {
        await tester.tapAt(onPage(at));
        await tester.pump(const Duration(milliseconds: 400));
      }

      await click(const Offset(100, 100));
      await click(const Offset(200, 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(await marks(), isEmpty, reason: 'two corners make no polygon');
      await click(const Offset(200, 200));
      await click(const Offset(100, 200));
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      final mark = (await marks()).single;
      expect(mark.kind, AnnotationKind.polygon);
      expect(mark.points.single, hasLength(3));
    });

    testWidgets('a click on the first corner closes the polygon', (
      tester,
    ) async {
      await open(tester);
      container
          .read(commentToolMenusProvider.notifier)
          .chooseShape(ShapeTool.polygon);
      await placing(tester, AnnotationTool.shapes);
      for (final at in const [
        Offset(100, 100),
        Offset(200, 100),
        Offset(200, 200),
        Offset(100, 100),
      ]) {
        await tester.tapAt(onPage(at));
        await tester.pump(const Duration(milliseconds: 400));
      }
      await settle(tester);
      expect((await marks()).single.points.single, hasLength(3));
    });

    testWidgets('Esc drops the draft, then leaves the tool', (tester) async {
      await open(tester);
      container
          .read(commentToolMenusProvider.notifier)
          .chooseShape(ShapeTool.polygon);
      await placing(tester, AnnotationTool.shapes);
      await tester.tapAt(onPage(const Offset(100, 100)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(finished, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(finished, 1);
      expect(await marks(), isEmpty);
    });

    testWidgets('a click places the chosen stamp with its capitals', (
      tester,
    ) async {
      await open(tester);
      container
          .read(commentToolMenusProvider.notifier)
          .chooseStamp(turkishStamps[0]);
      await placing(tester, AnnotationTool.stamp);
      await tester.tapAt(onPage(const Offset(300, 400)));
      await settle(tester);
      final mark = (await marks()).single;
      expect(mark.kind, AnnotationKind.stamp);
      expect(mark.rect.center.dx, moreOrLessEquals(300, epsilon: 1));
      expect(finished, 1);
    });

    testWidgets('Enter places the stamp mid-page', (tester) async {
      await open(tester);
      container
          .read(commentToolMenusProvider.notifier)
          .chooseStamp(standardStamps[0]);
      await placing(tester, AnnotationTool.stamp);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      final mark = (await marks()).single;
      expect(mark.icon, 'Approved');
      expect(mark.rect.center.dy, moreOrLessEquals(421, epsilon: 1));
    });

    testWidgets('no stamp chosen, the overlay is out of the way', (
      tester,
    ) async {
      await open(tester);
      await placing(tester, AnnotationTool.stamp);
      expect(find.byType(GestureDetector), findsWidgets);
      await tester.tapAt(onPage(const Offset(300, 400)));
      await settle(tester);
      expect(await marks(), isEmpty);
    });

    Future<void> library(WidgetTester tester) => show(
      tester,
      Positioned(
        top: 120,
        child: StampLibrary(
          yourName: 'Av. Deniz Aksoy',
          onChosen: container
              .read(commentToolMenusProvider.notifier)
              .chooseStamp,
        ),
      ),
    );

    testWidgets('the library searches and chooses', (tester) async {
      await open(tester);
      await library(tester);
      expect(find.text('ONAYLANDI'), findsOneWidget);
      expect(find.text('TÜRKÇE'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'GİZ');
      await settle(tester);
      expect(find.text('ONAYLANDI'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'gizli');
      await settle(tester);
      expect(find.text('GİZLİ'), findsOneWidget);
      await tester.tap(find.text('GİZLİ'));
      await settle(tester);
      expect(container.read(commentToolMenusProvider).stamp, turkishStamps[2]);
      await tester.enterText(find.byType(EditableText), 'zzz');
      await settle(tester);
      expect(find.text('No stamps match your search'), findsOneWidget);
    });

    testWidgets('a4-3b saves the stamp and makes it the chosen one', (
      tester,
    ) async {
      await open(tester);
      container
          .read(organizeDialogProvider.notifier)
          .show(const CreateStampDialog(yourName: 'Av. Deniz Aksoy'));
      await settle(tester);
      final save = find.widgetWithText(Button, 'Save stamp');
      expect(tester.widget<Button>(save).onPressed, isNull);
      await tester.enterText(find.byType(EditableText).first, 'incelendi');
      await settle(tester);
      // The Turkish capitals come from the choice, not from the UI's English.
      expect(find.text('INCELENDI'), findsOneWidget);
      await tester.tap(find.text('English'));
      await settle(tester);
      await tester.tap(find.text('Turkish (İNCELENDİ)'));
      await settle(tester);
      expect(find.text('İNCELENDİ'), findsOneWidget);
      await tester.tap(save);
      await settle(tester);
      expect(container.read(organizeDialogProvider), isNull);
      final saved = container.read(myStampsProvider).single;
      expect(saved.language, StampLanguage.turkish);
      expect(saved.name, 'Av. Deniz Aksoy');
      expect(container.read(commentToolMenusProvider).stamp, saved);
      expect(container.read(settingsProvider).myStamps, hasLength(1));
    });

    testWidgets('Import takes a stamp file and refuses anything else', (
      tester,
    ) async {
      await open(tester);
      await library(tester);
      picker.stampFile = Uint8List.fromList([1, 2, 3]);
      await tester.tap(find.text('Import…'));
      await settle(tester);
      expect(find.text('This stamp can’t be imported'), findsOneWidget);
      expect(container.read(myStampsProvider), isEmpty);
      const stamp = StampDesign(label: 'Paylaşılan', tone: StampTone.ink);
      picker.stampFile = stamp.toFile();
      await tester.tap(find.text('Import…'));
      await settle(tester);
      expect(container.read(myStampsProvider), [stamp]);
      expect(find.text('PAYLAŞILAN'), findsOneWidget);
    });

    testWidgets('a saved stamp exports and deletes from its menu', (
      tester,
    ) async {
      await open(tester);
      const stamp = StampDesign(label: 'A/B', tone: StampTone.ink);
      await container.read(myStampsProvider.notifier).add(stamp);
      await library(tester);
      picker.saveTo = '/tmp/stamp';
      await tester.tap(find.text('A/B'), buttons: kSecondaryButton);
      await settle(tester);
      await tester.tap(find.text('Export…'));
      await settle(tester);
      expect(picker.saves.single, 'A_B.fermanstamp');
      expect(StampDesign.fromFile(picker.written['/tmp/stamp']!), stamp);
      await tester.tap(find.text('A/B'), buttons: kSecondaryButton);
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(container.read(myStampsProvider), isEmpty);
    });
  });

  group('the tool row', () {
    Finder tool(String label) => find.byWidgetPredicate(
      (widget) => widget is ToolButton && widget.label == label,
    );

    Widget row({double width = 1200, ValueChanged<AnnotationTool>? onTool}) =>
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final menus = ref.read(commentToolMenusProvider.notifier);
              void select(AnnotationTool tool) {
                onTool?.call(tool);
                if (tool.hasMenu) menus.show(tool);
              }

              return SizedBox(
                width: width,
                child: AnnotationTools(
                  semanticLabel: 'Comment tools',
                  toolLabelOf: (tool) => tool.id,
                  colorsSemanticLabel: 'Color',
                  colorLabelOf: (color) => color.name,
                  showLabels: true,
                  overflowLabel: 'More tools',
                  onToolChanged: select,
                  onToolMenuRequested: menus.show,
                  toolMenus: commentToolMenusOf(
                    context,
                    ref,
                    onTool: (tool) => onTool?.call(tool),
                    yourName: 'Av. Deniz Aksoy',
                  ),
                ),
              );
            },
          ),
        );

    testWidgets('the Shapes menu lists a4-1 and its keys choose', (
      tester,
    ) async {
      final tools = <AnnotationTool>[];
      await tester.pumpWidget(
        componentHost(row(onTool: tools.add), size: const Size(1300, 800)),
      );
      await tester.tap(tool('shapes'));
      await tester.pumpAndSettle();
      final menu = tester.widget<Menu>(find.byType(Menu));
      expect(menu.items.map((item) => item.id).whereType<String>(), [
        'rect',
        'ellipse',
        'arrow',
        'line',
        'polygon',
        'keep',
      ]);
      expect(menu.items.first.checked, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pumpAndSettle();
      expect(find.byType(Menu), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AnnotationTools)),
      );
      expect(container.read(commentToolMenusProvider).shape, ShapeTool.polygon);
      expect(tools.last, AnnotationTool.shapes);
    });

    testWidgets('Stamp opens the library under its button', (tester) async {
      await tester.pumpWidget(
        componentHost(row(), size: const Size(1300, 800)),
      );
      await tester.tap(tool('stamp'));
      await tester.pumpAndSettle();
      expect(find.byType(StampLibrary), findsOneWidget);
      await tester.tap(find.text('APPROVED').first);
      await tester.pumpAndSettle();
      expect(find.byType(StampLibrary), findsNothing);
    });

    testWidgets('in the overflow menu the two offer submenus (B093)', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(row(width: 200), size: const Size(1300, 800)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('More tools'));
      await tester.pumpAndSettle();
      final items = tester.widget<Menu>(find.byType(Menu)).items;
      expect(
        items.firstWhere((item) => item.id == 'shapes').submenu!.first.id,
        'rect',
      );
      expect(
        items.firstWhere((item) => item.id == 'stamp').submenu,
        contains(predicate<MenuItem>((item) => item.label == 'APPROVED')),
      );
    });
  });
}
