import 'dart:async';
import 'dart:ui' show Offset;

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart' show ToastTone;
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'page_commands.g.dart';

/// The pages selected in Organize by handle, never by index, so a selection
/// holds through any change around it (a6-1), as `pageSelectionProvider`. A
/// deleted page stays in the set and is selected again when undo brings it
/// back; read the pages through `selectedPagesProvider`.
@Riverpod(keepAlive: true)
class PageSelection extends _$PageSelection {
  int? _anchor;

  @override
  Set<int> build() {
    ref.watch(openDocumentProvider.select((document) => document?.id));
    _anchor = null;
    return const {};
  }

  /// A click: only [handle].
  void only(int handle) {
    _anchor = handle;
    state = {handle};
  }

  /// ⌘-click, or Space: adds or takes away [handle].
  void toggle(int handle) {
    _anchor = handle;
    state = state.contains(handle)
        ? state.difference({handle})
        : {...state, handle};
  }

  /// ⇧-click: the pages of [order] from the last page clicked to [handle].
  void extendTo(int handle, List<int> order) {
    final to = order.indexOf(handle);
    final found = _anchor == null ? -1 : order.indexOf(_anchor!);
    final from = found < 0 ? to : found;
    state = order
        .sublist(from < to ? from : to, (from < to ? to : from) + 1)
        .toSet();
  }

  /// ⌘A: every page of [order].
  void all(List<int> order) => state = order.toSet();
}

/// The handles of the pages selected in the open document, in its order.
@Riverpod(keepAlive: true)
List<int> selectedPages(Ref ref) {
  final document = ref.watch(openDocumentProvider);
  if (document == null) return const [];
  final selected = ref.watch(pageSelectionProvider);
  return [
    for (var i = 0; i < document.pages.length; i++)
      if (selected.contains(document.pageHandle(i))) document.pageHandle(i),
  ];
}

/// What the open document's permissions say about changing its pages; null
/// until the engine answers, and without a document.
@riverpod
Future<OpGate?> organizeGate(Ref ref) async {
  final document = ref.watch(openDocumentProvider);
  if (document == null) return null;
  final gate = await ref
      .read(engineServiceProvider)
      .opGate(document.id, DocumentOp.organize);
  return gate;
}

/// Why the open document's pages cannot change, in the language given, or null
/// when they can.
@riverpod
String Function(AppLocalizations)? organizeRefusal(Ref ref) {
  if (ref.watch(openDocumentProvider)?.readOnly != null) {
    return (l10n) => l10n.editTipReadOnly;
  }
  return ref.watch(organizeGateProvider).value == OpGate.forbidden
      ? (l10n) => l10n.editTipRestricted
      : null;
}

/// Why the selection cannot be deleted, as [organizeRefusal]: a document keeps
/// at least one page, and the engine refuses to delete them all (a6-1 draws no
/// such state).
@riverpod
String Function(AppLocalizations)? deleteRefusal(Ref ref) {
  final pages = ref.watch(openDocumentProvider)?.pages.length;
  return ref.watch(selectedPagesProvider).length == pages
      ? (l10n) => l10n.organizeDeleteAllReason
      : ref.watch(organizeRefusalProvider);
}

/// How many pages are being dragged in the page grid, for the tool row's hint
/// ("Moving 3 pages", a6-1b); null without a drag.
@Riverpod(keepAlive: true)
class PagesDragged extends _$PagesDragged {
  @override
  int? build() => null;

  /// [count] pages are now being dragged; null when none is.
  // ignore: use_setters_to_change_properties
  void set(int? count) => state = count;
}

/// [pages], indices from 0 in order, as the numbers people read: "4–6, 9".
String pageRanges(List<int> pages, RegionFormat format) {
  final parts = <String>[];
  for (var i = 0; i < pages.length; i++) {
    final start = pages[i];
    while (i + 1 < pages.length && pages[i + 1] == pages[i] + 1) {
      i++;
    }
    parts.add(
      start == pages[i]
          ? format.integer(start + 1)
          : '${format.integer(start + 1)}–${format.integer(pages[i] + 1)}',
    );
  }
  return parts.join(', ');
}

/// Where a drag of files over the window asks the page grid what it takes
/// (B104, G105).
abstract interface class PageGridDropTarget {
  /// Files are over [global], or left when null; whether they would land in
  /// the grid.
  bool hover(Offset? global);

  /// [paths] were dropped at [global]; whether the grid took them.
  bool drop(List<String> paths, Offset global);
}

/// Holds the page grid showing, for the window's drop target: the two are
/// far apart in the tree, and files have no other way to find the grid.
final class PageGridDropSlot {
  /// The grid showing, if any.
  PageGridDropTarget? target;
}

/// The one [PageGridDropSlot].
@Riverpod(keepAlive: true)
PageGridDropSlot pageGridDropSlot(Ref ref) => PageGridDropSlot();

/// The page commands on the selection (a6-1, a6-1b), as
/// `pageCommandsProvider`: each is one step of the history, offered back by a
/// toast's Undo for as long as it is the newest step (G45).
@Riverpod(keepAlive: true)
class PageCommands extends _$PageCommands {
  int? _undoToast;
  int? _undoAt;

  EngineService get _engine => ref.read(engineServiceProvider);

  AppLocalizations get _l10n =>
      lookupAppLocalizations(ref.read(appLocaleProvider));

  RegionFormat get _format =>
      RegionFormat.forRegion(ref.read(regionProvider).region);

  OpenedDocument? get _document => ref.read(openDocumentProvider);

  List<int> get _order => switch (_document) {
    final document? => [
      for (var i = 0; i < document.pages.length; i++) document.pageHandle(i),
    ],
    null => const [],
  };

  /// Where [pages] sit in [order], in order.
  static List<int> _indices(List<int> pages, List<int> order) => [
    for (var i = 0; i < order.length; i++)
      if (pages.contains(order[i])) i,
  ];

  @override
  void build() {
    // The toast's Undo steps back the newest step, so it goes with it.
    ref
      ..listen(documentEditorProvider.select((s) => s.history.current), (
        _,
        current,
      ) {
        if (current != _undoAt) _withdrawUndo();
      })
      ..listen(
        openDocumentProvider.select((document) => document?.id),
        (_, _) => _withdrawUndo(),
      );
  }

  void _withdrawUndo() {
    final toast = _undoToast;
    _undoToast = null;
    if (toast != null) ref.read(toastNoticesProvider.notifier).dismiss(toast);
  }

  void _offerUndo(ToastText title, ToastText message) {
    _withdrawUndo();
    final editor = ref.read(documentEditorProvider.notifier);
    _undoAt = ref.read(documentEditorProvider).history.current;
    _undoToast = ref
        .read(toastNoticesProvider.notifier)
        .show(
          title: title,
          message: message,
          action: (
            label: (l10n) => l10n.shellUndo,
            onPressed: () => unawaited(editor.undo()),
          ),
        );
  }

  /// Takes [change] as a step; a signed document asks first (a3-16a).
  Future<void> _apply(
    Future<RevisionInfo> Function(int document) change,
    ToastText title,
    ToastText message,
  ) async {
    final failure = await ref
        .read(documentEditorProvider.notifier)
        .pageChange(change);
    if (failure == null) {
      _offerUndo(title, message);
      return;
    }
    final tab = ref.read(shellDocumentsProvider).active;
    if (failure.kind == EngineErrorKind.confirmationRequired && tab != null) {
      ref
          .read(documentSaverProvider.notifier)
          .askSigned(tab, () => unawaited(_apply(change, title, message)));
      return;
    }
    ref
        .read(toastNoticesProvider.notifier)
        .show(
          tone: ToastTone.danger,
          title: (l10n) => l10n.organizeFailed,
          message: (l10n) => engineMessage(l10n, failure, tab?.name ?? ''),
        );
  }

  ToastText _pagesLine(List<int> indices) {
    final ranges = bidiIsolate(pageRanges(indices, _format));
    return (l10n) => l10n.organizeToastPages(indices.length, ranges);
  }

  /// Turns the selection by [quarterTurns] quarter turns, clockwise when
  /// positive.
  Future<void> rotate(int quarterTurns) async {
    final pages = ref.read(selectedPagesProvider);
    if (pages.isEmpty) return;
    final count = _format.integer(pages.length);
    String title(AppLocalizations l10n) =>
        l10n.organizeToastRotated(pages.length, count);
    await _apply(
      (document) =>
          _engine.rotatePages(document, pages, quarterTurns, title(_l10n)),
      title,
      _pagesLine(_indices(pages, _order)),
    );
  }

  /// Deletes the selection, unless that would leave no page. Nothing asks: the
  /// toast's Undo is the way back (G45), and it says the pages stay in the
  /// file until it is cleaned (M4 plan, question 5).
  Future<void> delete() async {
    final pages = ref.read(selectedPagesProvider);
    final order = _order;
    if (pages.isEmpty || pages.length == order.length) return;
    final count = _format.integer(pages.length);
    final line = _pagesLine(_indices(pages, order));
    String title(AppLocalizations l10n) =>
        l10n.organizeToastDeleted(pages.length, count);
    await _apply(
      (document) => _engine.deletePages(document, pages, title(_l10n)),
      title,
      (l10n) => l10n.organizeToastDeletedNote(pages.length, line(l10n)),
    );
  }

  /// Copies the selection.
  Future<void> duplicate() async {
    final pages = ref.read(selectedPagesProvider);
    if (pages.isEmpty) return;
    final count = _format.integer(pages.length);
    String title(AppLocalizations l10n) =>
        l10n.organizeToastDuplicated(pages.length, count);
    await _apply(
      (document) => _engine.duplicatePages(document, pages, title(_l10n)),
      title,
      _pagesLine(_indices(pages, _order)),
    );
  }

  /// Moves the selection before the page [before], or to the end when null;
  /// nothing happens when that is where it is.
  Future<void> moveBefore(int? before) async {
    final pages = ref.read(selectedPagesProvider);
    final order = _order;
    if (pages.isEmpty || pages.contains(before)) return;
    final rest = [
      for (final page in order)
        if (!pages.contains(page)) page,
    ];
    final at = before == null ? rest.length : rest.indexOf(before);
    final moved = [...rest.take(at), ...pages, ...rest.skip(at)];
    if (_sameOrder(moved, order)) return;
    final count = _format.integer(pages.length);
    String title(AppLocalizations l10n) =>
        l10n.organizeToastMoved(pages.length, count);
    await _apply(
      (document) => _engine.movePages(document, pages, before, title(_l10n)),
      title,
      _pagesLine(_indices(pages, moved)),
    );
  }

  static bool _sameOrder(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// ⌥⌘↑: the selection, gathered, one page earlier.
  Future<void> moveUp() async {
    final pages = ref.read(selectedPagesProvider);
    final order = _order;
    if (pages.isEmpty) return;
    final first = order.indexOf(pages.first);
    if (first == 0) {
      // Pages apart gather at the start; pages already there stay.
      await moveBefore(order.firstWhere((p) => !pages.contains(p)));
      return;
    }
    await moveBefore(order[first - 1]);
  }

  /// ⌥⌘↓: the selection, gathered, one page later.
  Future<void> moveDown() async {
    final pages = ref.read(selectedPagesProvider);
    final order = _order;
    if (pages.isEmpty) return;
    final last = order.indexOf(pages.last);
    await moveBefore(last + 2 < order.length ? order[last + 2] : null);
  }

  /// Inserts the files at [paths] after the page [after], or first when null,
  /// each as a job and a step of its own, the files in their order. Undo in
  /// the toast takes back the file named in it, the last one in.
  Future<void> insertFiles(List<String> paths, {required int? after}) async {
    final document = _document;
    final tab = ref.read(shellDocumentsProvider).active;
    if (document == null || tab == null) return;
    final saver = ref.read(documentSaverProvider.notifier);
    if (saver.needsConfirmation(document)) {
      saver.askSigned(tab, () => unawaited(insertFiles(paths, after: after)));
      return;
    }
    final paper = switch (ref.read(regionProvider).paperSize) {
      PaperSize.a4 => ImagePaper.a4,
      PaperSize.letter => ImagePaper.letter,
    };
    // Each goes right after [after], so the last file goes in first.
    for (final path in paths.reversed) {
      final name = path.split(RegExp(r'[/\\]')).last;
      final shown = bidiIsolate(name);
      try {
        final job = await ref
            .read(backgroundJobsProvider.notifier)
            .insertPages(
              document.id,
              name,
              path: path,
              after: after,
              paper: paper,
              stepName: _l10n.organizeStepInsert(shown),
            );
        if (job == null) return;
        if (_document?.id != document.id) {
          // The change waits on a document no longer shown: the editor's
          // steps follow the shown one.
          throw const EngineException(messageKey: 'errorInternal');
        }
        final before = _document!.pages.length;
        final failure = await ref
            .read(documentEditorProvider.notifier)
            .pageChange((_) => _engine.applyJobChange(job));
        if (failure != null) throw failure;
        final added = (_document?.pages.length ?? before) - before;
        final count = _format.integer(added);
        _offerUndo(
          (l10n) => l10n.organizeToastInserted(added, count),
          (_) => shown,
        );
      } on EngineException catch (error) {
        ref
            .read(toastNoticesProvider.notifier)
            .show(
              tone: ToastTone.danger,
              title: (l10n) => l10n.organizeInsertFailed(shown),
              message: (l10n) => engineMessage(l10n, error, shown),
            );
      }
    }
  }
}
