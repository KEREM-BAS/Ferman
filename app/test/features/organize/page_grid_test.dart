import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/organize/crop_overlay.dart';
import 'package:ferman/features/organize/extract_pages_dialog.dart';
import 'package:ferman/features/organize/insert_blank_dialog.dart';
import 'package:ferman/features/organize/insert_file_dialog.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/organize_panel.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/organize/page_grid.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_tool_rows.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/find_bar.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';

const String _path = '/docs/tez.pdf';

OpenedDocument _document({int pages = 12}) => OpenedDocument(
  id: 9,
  pages: [
    for (var i = 0; i < pages; i++)
      PageInfo(width: 595, height: 842, handle: 100 + i),
  ],
);

/// The app in Organize with `_document` open.
Future<ProviderContainer> _open(
  WidgetTester tester,
  FakeEngineService engine, {
  Size size = boardSize,
  Locale locale = const Locale('en', 'US'),
}) async {
  await pumpFermanApp(
    tester,
    size: size,
    systemLocales: [locale],
    engine: engine,
    home: '/docs',
    picker: FakeFilePickerService(picked: const [_path]),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(FmStart)),
  );
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  container.read(shellModeProvider.notifier).select(FermanMode.organize);
  await tester.pumpAndSettle();
  return container;
}

FakeEngineService _engine({int pages = 12}) =>
    FakeEngineService(documents: {_path: _document(pages: pages)});

Finder _page(int number) => find.byWidgetPredicate(
  (widget) => widget is PageThumbnail && widget.page == number,
);

List<int> _order(ProviderContainer container) => [
  for (final page in container.read(openDocumentProvider)!.pages) page.handle!,
];

Set<int> _selected(ProviderContainer container) =>
    container.read(selectedPagesProvider).toSet();

ToolButton _tool(WidgetTester tester, String label) =>
    tester.widget<ToolButton>(
      find.descendant(
        of: find.byKey(ShellToolRows.keyOf(FermanMode.organize)),
        matching: find.byWidgetPredicate(
          (widget) => widget is ToolButton && widget.label == label,
        ),
      ),
    );

RegionFormat _format() => RegionFormat.forRegion(Region.unitedStates);

void main() {
  group('PageGridMetrics', () {
    test('the board fits six columns of 150 with 28 between', () {
      // 1440 less the 280 panel is a little under what six need with padding
      // only when the window is narrower than the board's.
      const metrics = PageGridMetrics(1160);
      expect(metrics.columns, 6);
      expect(metrics.inset, (1160 - 6 * 150 - 5 * 28) / 2);
      expect(const PageGridMetrics(100).columns, 1);
      expect(const PageGridMetrics(100).inset, 0);
    });

    test('a slot is the nearest gap of the row under the pointer', () {
      const metrics = PageGridMetrics(1160);
      final inset = metrics.inset;
      final first = metrics.rowTop(0) + 10;
      expect(metrics.slotAt(inset + 10, first, 12).index, 0);
      expect(metrics.slotAt(inset + 100, first, 12).index, 1);
      expect(metrics.slotAt(inset + 178 + 100, first, 12).index, 2);
      // The end of the first row is the second row's first page.
      final end = metrics.slotAt(1160, first, 12);
      expect((end.index, end.row, end.column), (6, 0, 6));
      final second = metrics.slotAt(inset + 10, metrics.rowTop(1) + 10, 12);
      expect((second.index, second.row, second.column), (6, 1, 0));
      // Past the last page, its end.
      final past = metrics.slotAt(1160, 5000, 8);
      expect((past.index, past.row, past.column), (8, 1, 2));
    });
  });

  test('page ranges read as people write them', () {
    final format = _format();
    expect(pageRanges(const [3, 4, 5, 8], format), '4–6, 9');
    expect(pageRanges(const [0], format), '1');
    expect(pageRanges(const [], format), '');
  });

  test('a page of any shape fits the cell', () {
    for (final page in const [
      PageInfo(width: 595, height: 842),
      PageInfo(width: 842, height: 595),
      PageInfo(width: 1, height: 14400),
      PageInfo(width: 14400, height: 1),
      PageInfo(width: 0, height: 0),
      PageInfo(width: 842, height: 595, rotation: 90),
      PageInfo(width: 14400, height: 1, rotation: 270),
    ]) {
      final fit = PageGrid.fit(page);
      final size = PageThumbnail(
        page: 1,
        width: fit.width,
        aspect: fit.aspect,
        rotation: page.rotation,
      ).pageSize;
      expect(size.width, lessThanOrEqualTo(PageGrid.thumbnailWidth + 1));
      expect(size.height, lessThanOrEqualTo(PageGrid.thumbnailMaxHeight + 1));
    }
  });

  group('selection (a6-1)', () {
    testWidgets(
      'click, ⇧-click and Ctrl-click keep handles and name the count',
      (tester) async {
        final container = await _open(tester, _engine());
        await tester.tap(_page(4), kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(_selected(container), {103});
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tap(_page(6), kind: PointerDeviceKind.mouse);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(_selected(container), {103, 104, 105});
        expect(find.text('3 of 12 pages selected'), findsOne);
        expect(find.text('3 pages selected'), findsOne);
        expect(find.byType(OrganizePanel), findsOne);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(_page(9), kind: PointerDeviceKind.mouse);
        await tester.tap(_page(4), kind: PointerDeviceKind.mouse);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(_selected(container), {104, 105, 108});
        expect(find.text('5, 6, 9'), findsOne);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('arrows move focus, Space toggles, Ctrl+A selects all', (
      tester,
    ) async {
      final container = await _open(tester, _engine());
      await tester.tap(_page(1), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_selected(container), {100, 101});
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_selected(container), {101});
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(_selected(container).length, 12);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('each page reads "Page 5 of 12", selected', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, _engine());
      await tester.tap(_page(5), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Page 5 of 12')),
        matchesSemantics(
          label: 'Page 5 of 12',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasFocusAction: true,
          hasTapAction: true,
          isFocused: true,
        ),
      );
      handle.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('commands', () {
    testWidgets('need a selection, and work on it with an Undo toast', (
      tester,
    ) async {
      final engine = _engine();
      final container = await _open(tester, engine);
      expect(_tool(tester, 'Duplicate').onPressed, isNull);
      await tester.tap(_page(2), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is ToolButton && w.label == 'Rotate right',
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(openDocumentProvider)!.pages[1].rotation, 90);
      expect(find.text('1 page rotated'), findsOne);
      expect(find.text('Page \u20682\u2069'), findsOne);
      expect(find.text('0°'), findsNothing);
      expect(find.text('90°'), findsOne);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(container.read(openDocumentProvider)!.pages[1].rotation, 0);
      expect(find.text('1 page rotated'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('delete asks nothing, says the pages stay in the file, and '
        'Undo selects them again', (tester) async {
      final container = await _open(tester, _engine());
      await tester.tap(_page(3), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(_order(container), isNot(contains(102)));
      expect(_selected(container), isEmpty);
      expect(find.text('1 page deleted'), findsOne);
      expect(
        find.text(
          'Page \u20683\u2069. It stays in the file until you save with Remove '
          'edit history or run Optimize and clean.',
        ),
        findsOne,
      );
      // The tab, the viewer and the status bar follow.
      expect(container.read(viewerProvider)!.pageSizes.length, 11);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(_order(container), contains(102));
      expect(_selected(container), {102});
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Delete is refused with every page selected', (tester) async {
      final container = await _open(tester, _engine(pages: 2));
      container.read(pageSelectionProvider.notifier).all(_order(container));
      await tester.pumpAndSettle();
      expect(
        _tool(tester, 'Delete').disabledReason,
        'A document keeps at least one page',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(_order(container).length, 2);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a later step takes the Undo away, since undo would step it '
        'back instead', (tester) async {
      final container = await _open(tester, _engine());
      final commands = container.read(pageCommandsProvider.notifier);
      await tester.tap(_page(1), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await commands.rotate(1);
      await tester.pumpAndSettle();
      expect(find.text('1 page rotated'), findsOne);
      await commands.duplicate();
      await tester.pumpAndSettle();
      expect(find.text('1 page rotated'), findsNothing);
      expect(find.text('1 page duplicated'), findsOne);
      expect(container.read(documentEditorProvider).history.current, 2);
      await container.read(documentEditorProvider.notifier).undo();
      await tester.pumpAndSettle();
      expect(container.read(toastNoticesProvider), isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('⌥-Ctrl-arrows reach the commands from a page with focus', (
      tester,
    ) async {
      final container = await _open(tester, _engine(pages: 5));
      await tester.tap(_page(3), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      Future<void> press(LogicalKeyboardKey arrow) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(arrow);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await press(LogicalKeyboardKey.arrowUp);
      expect(_order(container), [100, 102, 101, 103, 104]);
      await press(LogicalKeyboardKey.arrowDown);
      expect(_order(container), [100, 101, 102, 103, 104]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('moving every page up does nothing, and so on one page', (
      tester,
    ) async {
      final container = await _open(tester, _engine(pages: 1));
      container.read(pageSelectionProvider.notifier).only(100);
      await container.read(pageCommandsProvider.notifier).moveUp();
      await tester.pumpAndSettle();
      expect(_order(container), [100]);
      expect(container.read(documentEditorProvider).history.current, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('after a keyboard delete focus stays in the grid', (
      tester,
    ) async {
      final container = await _open(tester, _engine(pages: 5));
      await tester.tap(_page(3), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(_order(container), [100, 101, 103, 104]);
      // The page that took its place.
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Page 103');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Page 104');
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Ctrl+A in the find field selects its text, not the pages', (
      tester,
    ) async {
      final container = await _open(tester, _engine());
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(FindBar),
          matching: find.byType(EditableText),
        ),
        'kira',
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(_selected(container), isEmpty);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(FindBar),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.selection.textInside('kira'), 'kira');
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the panel draws a dash only for pages side by side', (
      tester,
    ) async {
      final engine = FakeEngineService(
        documents: {
          _path: OpenedDocument(
            id: 9,
            pages: [
              for (var i = 0; i < 5; i++)
                PageInfo(
                  width: 595,
                  height: 842,
                  handle: 100 + i,
                  label: 'l$i',
                ),
            ],
          ),
        },
      );
      final container = await _open(tester, engine);
      container.read(pageSelectionProvider.notifier)
        ..only(100)
        ..toggle(103);
      await tester.pumpAndSettle();
      expect(find.textContaining('l0, l3'), findsOne);
      container.read(pageSelectionProvider.notifier)
        ..only(100)
        ..toggle(101);
      await tester.pumpAndSettle();
      expect(find.textContaining('l0–l1'), findsOne);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets(
      '⌥-Ctrl-arrows move the selection, gathered, a page at a time',
      (tester) async {
        final container = await _open(tester, _engine(pages: 5));
        final selection = container.read(pageSelectionProvider.notifier);
        final commands = container.read(pageCommandsProvider.notifier);
        selection.only(102);
        await commands.moveUp();
        await tester.pumpAndSettle();
        expect(_order(container), [100, 102, 101, 103, 104]);
        await commands.moveDown();
        await tester.pumpAndSettle();
        expect(_order(container), [100, 101, 102, 103, 104]);
        selection.only(104);
        await commands.moveDown();
        await tester.pumpAndSettle();
        // Already last: no step.
        expect(container.read(documentEditorProvider).history.current, 2);
        selection
          ..only(100)
          ..toggle(102);
        await commands.moveUp();
        await tester.pumpAndSettle();
        expect(_order(container), [100, 102, 101, 103, 104]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('a signed document asks first (a3-16a) and goes on after', (
      tester,
    ) async {
      final engine = _engine()..signed.add(9);
      final container = await _open(tester, engine);
      await tester.tap(_page(1), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await container.read(pageCommandsProvider.notifier).rotate(1);
      await tester.pumpAndSettle();
      expect(container.read(openDocumentProvider)!.pages[0].rotation, 0);
      expect(container.read(documentSaverProvider).signed, isNotNull);
      await container.read(documentSaverProvider.notifier).editAnyway();
      await tester.pumpAndSettle();
      expect(container.read(openDocumentProvider)!.pages[0].rotation, 90);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a document that forbids assembling says so on every command', (
      tester,
    ) async {
      final engine = _engine();
      engine.opGates[(9, DocumentOp.organize)] = OpGate.forbidden;
      final container = await _open(tester, engine);
      await tester.tap(_page(1), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_selected(container), {100});
      const reason = 'The author’s permissions don’t allow editing';
      expect(_tool(tester, 'Duplicate').disabledReason, reason);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(_order(container).length, 12);
      final grid = container.read(pageGridDropSlotProvider).target!;
      expect(grid.hover(tester.getCenter(find.byType(PageGrid))), isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets(
      'the page menu acts on the whole selection and names its count',
      (tester) async {
        final container = await _open(tester, _engine());
        await tester.tap(_page(2), kind: PointerDeviceKind.mouse);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(_page(3), kind: PointerDeviceKind.mouse);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        await tester.tap(
          _page(3),
          buttons: kSecondaryButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(find.text('2 pages'), findsOne);
        expect(find.text('Rotate left'), findsWidgets);
        await tester.tap(find.text('Delete 2 pages'));
        await tester.pumpAndSettle();
        expect(_order(container).length, 10);
        expect(find.text('2 pages deleted'), findsOne);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('a right click on a page outside the selection selects it', (
      tester,
    ) async {
      final container = await _open(tester, _engine());
      container.read(pageSelectionProvider.notifier).only(100);
      await tester.tap(
        _page(5),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_selected(container), {104});
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('the dialogs on the selection', () {
    testWidgets('the page menu opens them on the selection', (tester) async {
      await _open(tester, _engine());
      await tester.tap(_page(2), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(_page(3), kind: PointerDeviceKind.mouse);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.tap(
        _page(3),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extract as new PDF…'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ExtractPagesDialog>(find.byType(ExtractPagesDialog))
            .pages,
        [1, 2],
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the panel inserts after the last page selected', (
      tester,
    ) async {
      final engine = _engine();
      final container = await _open(tester, engine);
      container.read(pageSelectionProvider.notifier).all([101, 103]);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(OrganizePanel),
          matching: find.text('Blank page'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<InsertBlankDialog>(find.byType(InsertBlankDialog)).pages,
        [1, 3],
      );
      await tester.tap(find.text('Insert 1 page'));
      await tester.pumpAndSettle();
      expect(_order(container).length, 13);
      expect(container.read(organizeDialogProvider), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a document that forbids assembling refuses what changes it, '
        'and still extracts', (tester) async {
      final engine = _engine()
        ..opGates[(9, DocumentOp.organize)] = OpGate.forbidden;
      final container = await _open(tester, engine);
      container.read(pageSelectionProvider.notifier).only(100);
      await tester.pumpAndSettle();
      expect(_tool(tester, 'Crop').onPressed, isNull);
      expect(_tool(tester, 'Replace').onPressed, isNull);
      const reason = 'The author’s permissions don’t allow editing';
      for (final label in ['Insert', 'Replace', 'Crop', 'Page labels']) {
        expect(_tool(tester, label).disabledReason, reason, reason: label);
      }
      expect(_tool(tester, 'Extract').onPressed, isNotNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Extract and Insert from file have their keys', (tester) async {
      final container = await _open(tester, _engine());
      container.read(pageSelectionProvider.notifier).only(104);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ExtractPagesDialog>(find.byType(ExtractPagesDialog))
            .pages,
        [4],
      );
      container.read(organizeDialogProvider.notifier).close();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(InsertFileDialog), findsOne);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Crop shows the reader, on the first page selected, and comes '
        'back to the grid', (tester) async {
      final container = await _open(tester, _engine());
      container.read(pageSelectionProvider.notifier).only(104);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ToolButton, 'Crop'));
      await tester.pumpAndSettle();
      expect(find.byType(PageGrid), findsNothing);
      expect(find.byType(DocumentView), findsOne);
      expect(find.byType(CropOverlay), findsOne);
      expect(container.read(viewerProvider)!.currentPage, 4);
      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(PageGrid), findsOne);
      expect(find.byType(CropOverlay), findsNothing);
      expect(_selected(container), {104});
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('drag (a6-1b)', () {
    Future<TestGesture> lift(WidgetTester tester, int page) async {
      final gesture = await tester.startGesture(
        tester.getCenter(_page(page)),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      return gesture;
    }

    testWidgets('lifts the selection over empty slots, says what a drop does '
        'and moves it', (tester) async {
      final container = await _open(tester, _engine());
      container.read(pageSelectionProvider.notifier)
        ..only(103)
        ..extendTo(105, _order(container));
      await tester.pumpAndSettle();
      final gesture = await lift(tester, 5);
      expect(find.text('Moving 3 pages'), findsOne);
      for (final page in [4, 5, 6]) {
        expect(
          tester.widget<PageThumbnail>(_page(page)).state,
          PageThumbnailState.placeholder,
        );
      }
      expect(
        tester.widget<PageThumbnail>(_page(3)).state,
        PageThumbnailState.idle,
      );
      await gesture.moveTo(tester.getTopLeft(_page(3)) + const Offset(2, 40));
      await tester.pump();
      expect(
        find.text('Drop to move pages \u20684–6\u2069 before page 3'),
        findsOne,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_order(container).take(6), [100, 101, 103, 104, 105, 102]);
      expect(_selected(container), {103, 104, 105});
      expect(find.text('3 pages moved'), findsOne);
      expect(find.text('Moving 3 pages'), findsNothing);
      // The moved pages keep their cells' place in the new order.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(_order(container).take(4), [100, 101, 102, 103]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Esc cancels', (tester) async {
      final container = await _open(tester, _engine());
      final before = _order(container);
      final gesture = await lift(tester, 2);
      expect(_selected(container), {101}, reason: 'the page under the drag');
      await gesture.moveTo(tester.getCenter(_page(8)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.textContaining('Drop to move'), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_order(container), before);
      expect(container.read(documentEditorProvider).history.current, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a drop back where it was adds no step', (tester) async {
      final container = await _open(tester, _engine());
      final gesture = await lift(tester, 2);
      await gesture.moveTo(tester.getCenter(_page(2)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(container.read(documentEditorProvider).history.current, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the canvas edge scrolls, and the drag ends clean', (
      tester,
    ) async {
      await _open(tester, _engine(pages: 60));
      final gesture = await lift(tester, 2);
      final grid = tester.getRect(find.byType(PageGrid));
      await gesture.moveTo(grid.bottomCenter - const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 200));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(PageGrid),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await gesture.up();
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('files dropped on the grid (B104, G105)', () {
    testWidgets('go in at the marker in their order, as jobs', (tester) async {
      final engine = _engine()..insertedPages = 2;
      final container = await _open(tester, engine);
      final grid = container.read(pageGridDropSlotProvider).target!;
      final at = tester.getTopLeft(_page(3)) + const Offset(2, 40);
      expect(grid.hover(at), isTrue);
      await tester.pump();
      expect(find.text('Drop to insert before page 3'), findsOne);
      expect(grid.drop(const ['/a/one.pdf', '/a/two.pdf'], at), isTrue);
      await tester.pump();
      expect(find.textContaining('Drop to insert'), findsNothing);
      // The last file goes in first, so each stays right after page 2.
      expect(engine.assembleJobs, ['insert /a/two.pdf']);
      engine.endJob(const JobUpdate(job: 1, state: JobState.done));
      // The next job's spinner never settles.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.assembleJobs, ['insert /a/two.pdf', 'insert /a/one.pdf']);
      engine.endJob(const JobUpdate(job: 2, state: JobState.done));
      await tester.pumpAndSettle();
      expect(_order(container).length, 16);
      expect(find.text('2 pages inserted'), findsOne);
      expect(find.text('\u2068one.pdf\u2069'), findsOne);
      expect(container.read(documentEditorProvider).history.current, 2);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a file that fails says why and the document stays', (
      tester,
    ) async {
      final engine = _engine();
      final container = await _open(tester, engine);
      container.read(pageGridDropSlotProvider).target!.drop(const [
        '/a/bad.pdf',
      ], tester.getCenter(_page(1)));
      await tester.pump();
      engine.endJob(
        const JobUpdate(
          job: 1,
          state: JobState.failed,
          error: EngineException(messageKey: 'errorDamagedTruncated'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t insert \u2068bad.pdf\u2069'), findsOne);
      expect(_order(container).length, 12);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('outside the grid, and in other modes, there is no target', (
      tester,
    ) async {
      final container = await _open(tester, _engine());
      final grid = container.read(pageGridDropSlotProvider).target!;
      expect(grid.hover(Offset.zero), isFalse);
      container.read(shellModeProvider.notifier).select(FermanMode.view);
      await tester.pumpAndSettle();
      expect(container.read(pageGridDropSlotProvider).target, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  testWidgets('leaving Organize shows the page again and opens the sidebar it '
      'closed', (tester) async {
    final container = await _open(tester, _engine());
    expect(container.read(shellSidebarOpenProvider), isFalse);
    expect(find.byType(PageGrid), findsOne);
    expect(find.byType(DocumentView), findsNothing);
    container.read(shellModeProvider.notifier).select(FermanMode.view);
    await tester.pumpAndSettle();
    expect(container.read(shellSidebarOpenProvider), isTrue);
    expect(find.byType(DocumentView), findsOne);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('the grid follows the UI into right to left (G32)', (
    tester,
  ) async {
    await _open(tester, _engine(), locale: const Locale('ar', 'EG'));
    expect(
      tester.getCenter(_page(2)).dx,
      lessThan(tester.getCenter(_page(1)).dx),
    );
    // Starting at the right, so the first gap is there too.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PageGrid)),
    );
    final grid = container.read(pageGridDropSlotProvider).target!;
    expect(
      grid.hover(tester.getTopRight(_page(1)) + const Offset(-2, 40)),
      isTrue,
    );
    await tester.pump();
    expect(find.text('أفلت للإدراج قبل الصفحة ١'), findsOne);
    grid.hover(null);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a phone-wide window has room for two columns', (tester) async {
    await _open(tester, _engine(), size: const Size(393, 852));
    expect(tester.takeException(), isNull);
    final first = tester.getCenter(_page(1));
    final second = tester.getCenter(_page(2));
    expect(second.dx, greaterThan(first.dx));
    expect(second.dy, first.dy);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
