import 'dart:async';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/annotations/annotation_color.dart'
    as design;
import 'package:ferman/design/components/annotations/annotation_tool.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/features/comments/comment_time.dart';
import 'package:ferman/features/comments/commenter_name_dialog.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_commands.dart'
    show pageCommandsProvider;
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/stamps/comment_tool_menus.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'comment_state.g.dart';

/// The open document's annotations as its committed steps leave them, read
/// again after each step, undo and redo.
@riverpod
Future<AnnotationList> documentAnnotations(Ref ref) async {
  final document = ref.watch(openDocumentProvider.select((d) => d?.id));
  ref.watch(documentEditorProvider.select((s) => s.history.current));
  if (document == null) return const AnnotationList();
  return await ref.read(engineServiceProvider).annotations(document);
}

/// The open document's threads, empty until the engine answers.
@riverpod
List<CommentThread> documentThreads(Ref ref) {
  final list = ref.watch(documentAnnotationsProvider).value;
  return list == null ? const [] : commentThreads(list.annotations);
}

/// What the open document's permissions say about comments; null until the
/// engine answers.
@riverpod
Future<OpGate?> commentGate(Ref ref) async {
  final document = ref.watch(openDocumentProvider);
  if (document == null) return null;
  return await ref
      .read(engineServiceProvider)
      .opGate(document.id, DocumentOp.comment);
}

/// Why the open document takes no comments, in the language given, or null
/// when it does (G27, G46).
@riverpod
String Function(AppLocalizations)? commentRefusal(Ref ref) {
  if (ref.watch(openDocumentProvider)?.readOnly != null) {
    return (l10n) => l10n.editTipReadOnly;
  }
  return ref.watch(commentGateProvider).value == OpGate.forbidden
      ? (l10n) => l10n.editTipRestricted
      : null;
}

/// The Comment row's choices (a4-1); they stay across documents.
@immutable
final class CommentTools {
  /// Highlight in yellow, as FmWindow draws the row.
  const new({
    this.tool = AnnotationTool.highlight,
    this.color = design.AnnotationColor.yellow,
  });

  /// The active tool.
  final AnnotationTool tool;

  /// The colour new marks take.
  final design.AnnotationColor color;

  /// Whether [tool] marks text the pointer selects.
  bool get marksText => textMarkKind(tool) != null;

  /// A copy with the given values.
  CommentTools copyWith({
    AnnotationTool? tool,
    design.AnnotationColor? color,
  }) => CommentTools(tool: tool ?? this.tool, color: color ?? this.color);
}

/// The text mark [tool] makes, if it makes one.
AnnotationKind? textMarkKind(AnnotationTool tool) => switch (tool) {
  AnnotationTool.highlight => AnnotationKind.highlight,
  AnnotationTool.underline => AnnotationKind.underline,
  AnnotationTool.strikethrough => AnnotationKind.strikeOut,
  _ => null,
};

/// The Comment row's state, as `commentToolProvider`.
@Riverpod(keepAlive: true)
class CommentTool extends _$CommentTool {
  @override
  CommentTools build() => const CommentTools();

  /// Picks [tool]; a tool that marks needs the comments it marks to show.
  void pick(AnnotationTool tool) {
    state = state.copyWith(tool: tool);
    if (tool != AnnotationTool.select) {
      unawaited(ref.read(commentsShownProvider.notifier).show(visible: true));
    }
  }

  /// Picks [color] for new marks.
  void color(design.AnnotationColor color) =>
      state = state.copyWith(color: color);

  /// A mark was placed: shapes and pinned objects go back to Select, unless
  /// kept (a4-1's Keep tool selected). Text marks and Draw stay, for the next
  /// one.
  void placed() {
    if (ref.read(commentToolMenusProvider).keepSelected ||
        state.marksText ||
        state.tool == AnnotationTool.pen) {
      return;
    }
    state = state.copyWith(tool: AnnotationTool.select);
  }
}

/// The selected comment, by its handle, never an index (a4-2).
@immutable
final class CommentSelected {
  /// [handle] selected.
  const new(this.handle, {this.composing = false, this.noteOpen = false});

  /// The annotation.
  final int handle;

  /// Whether its panel card shows the reply field.
  final bool composing;

  /// Whether its note shows open on the page (a4-1d).
  final bool noteOpen;
}

/// The comment selected on the page and in the panel, as
/// `commentSelectionProvider`. It holds through any change around it; one the
/// list no longer has selects nothing, nor does anything while comments are
/// hidden.
///
/// The handle of an annotation written directly in the file's page names its
/// place, which a step on its neighbour or an undo gives to another, so any
/// such step drops it.
// shortcut: a reply or resolve on such a mark drops the selection instead of
// following the mark to its new handle; those calls return no thread handle.
@Riverpod(keepAlive: true)
class CommentSelection extends _$CommentSelection {
  @override
  CommentSelected? build() {
    ref
      ..watch(openDocumentProvider.select((document) => document?.id))
      ..listen(commentsShownProvider.select((shown) => shown.visible), (
        _,
        visible,
      ) {
        if (!visible) state = null;
      })
      ..listen(documentEditorProvider.select((s) => s.history.current), (_, _) {
        final handle = stateOrNull?.handle;
        if (handle != null && isDirectAnnotationHandle(handle)) state = null;
      });
    return null;
  }

  /// Selects [handle].
  void select(int handle, {bool composing = false, bool noteOpen = false}) =>
      state = CommentSelected(handle, composing: composing, noteOpen: noteOpen);

  /// Selects nothing.
  void clear() => state = null;

  /// The list changed: one it no longer has selects nothing.
  void listed(List<AnnotationInfo> annotations) {
    final handle = stateOrNull?.handle;
    if (handle != null && !annotations.any((each) => each.handle == handle)) {
      state = null;
    }
  }

  /// A first change gave the file's direct annotation [to] in place of [from].
  void follow(int from, int to) {
    final now = state;
    if (now?.handle == from) {
      state = CommentSelected(
        to,
        composing: now!.composing,
        noteOpen: now.noteOpen,
      );
    }
  }
}

/// FmComments's filters, as `commentFilterProvider`; each document starts
/// with the board's.
@Riverpod(keepAlive: true)
class CommentFilter extends _$CommentFilter {
  @override
  CommentFilters build() {
    ref.watch(openDocumentProvider.select((document) => document?.id));
    return const CommentFilters();
  }

  /// Sets the filters.
  // ignore: use_setters_to_change_properties
  void set(CommentFilters filters) => state = filters;
}

/// Whether a document's comments show (a4-5), and the render key that says so.
@immutable
final class CommentsVisibility {
  /// Shown, by default.
  const new({this.visible = true, this.renderKey = 0});

  /// Whether they show.
  final bool visible;

  /// Every page's render key after the last change; 0 before one.
  final int renderKey;
}

/// Show comments (⇧⌘H, a4-5), as `commentsShownProvider`: render-only, never
/// saved, and each document keeps its own, as its layers do.
@Riverpod(keepAlive: true)
class CommentsShown extends _$CommentsShown {
  @override
  CommentsVisibility build() {
    final id = ref.watch(openDocumentProvider.select((d) => d?.id));
    if (id == null) return const CommentsVisibility();
    final memory = ref.read(documentMemoryProvider(id));
    listenSelf((_, next) => memory.remember(next));
    return memory.recall<CommentsVisibility>() ?? const CommentsVisibility();
  }

  /// Shows or hides them; if the engine refuses, a toast says why and nothing
  /// changes.
  Future<void> show({required bool visible}) async {
    final document = ref.read(openDocumentProvider)?.id;
    if (document == null || visible == state.visible) return;
    final int key;
    try {
      key = await ref
          .read(engineServiceProvider)
          .showComments(document, visible: visible);
    } on EngineException catch (error) {
      if (ref.mounted) {
        showPageChangeFailure(
          ref.read(toastNoticesProvider.notifier),
          error,
          ref.read(shellDocumentsProvider).active?.name ?? '',
        );
      }
      return;
    }
    if (!ref.mounted) return;
    final shown = CommentsVisibility(visible: visible, renderKey: key);
    if (ref.read(openDocumentProvider)?.id == document) {
      state = shown;
    } else {
      ref.read(documentMemoryProvider(document)).remember(shown);
    }
  }
}

/// What the comment tools do, each one step of the history (a4-1, a4-2), as
/// `commentCommandsProvider`. A signed document asks first (a3-16a).
@Riverpod(keepAlive: true)
class CommentCommands extends _$CommentCommands {
  EngineService get _engine => ref.read(engineServiceProvider);

  AppLocalizations get _l10n =>
      lookupAppLocalizations(ref.read(appLocaleProvider));

  @override
  void build() {}

  /// The name on a new comment; the first comment asks once, and a Cancel
  /// there gives null (G46).
  Future<String?> _author() async {
    final name = ref.read(settingsProvider).commenterName;
    if (name != null) return name;
    final answer = Completer<String?>();
    final dialog = ref.read(organizeDialogProvider.notifier);
    dialog.show(
      CommenterNameDialog(
        done: (name) {
          dialog.close();
          answer.complete(name);
          if (name != null) {
            ref
                .read(settingsProvider.notifier)
                .change((old) => old.copyWith(commenterName: name))
                .ignore();
          }
        },
      ),
    );
    return await answer.future;
  }

  /// Takes [change] as a step of [on], else the open document, or says why not
  /// in a toast.
  Future<void> _commit(
    Future<RevisionInfo> Function(int document) change, {
    void Function()? committed,
    int? on,
  }) async {
    final document = on ?? ref.read(openDocumentProvider)?.id;
    if (document == null) return;
    final failure = await ref
        .read(documentEditorProvider.notifier)
        .pageChange(document, () => change(document), committed: committed);
    if (failure == null) return;
    final name = ref.read(shellDocumentsProvider).active?.name ?? '';
    showPageChangeFailure(
      ref.read(toastNoticesProvider.notifier),
      failure,
      name,
    );
  }

  /// Creates what [draft] gives on the page [page], by its handle, and selects
  /// it; with [composing] its card waits for the text. [step] names it in the
  /// history when "Add comment" says too little.
  Future<void> add(
    int page,
    NewAnnotation Function(String author) draft, {
    bool composing = false,
    String? step,
  }) async {
    final author = await _author();
    if (author == null || !ref.mounted) return;
    int? handle;
    await _commit(
      (document) async {
        final commit = await _engine.addAnnotation(
          document,
          page,
          draft(author),
          step ?? _l10n.commentStepAdd,
        );
        handle = commit.handle;
        return commit.revision;
      },
      committed: () {
        ref
            .read(commentSelectionProvider.notifier)
            .select(handle!, composing: composing);
        ref.read(commentToolProvider.notifier).placed();
        if (composing) revealShellPanel(ref.read);
      },
    );
  }

  /// What was being typed on the page when its view went away, perhaps for
  /// another document's: [draft] on page [page] of [document], selecting
  /// nothing.
  Future<void> addLeft(
    int document,
    int page,
    NewAnnotation Function(String author) draft,
  ) async {
    final author = await _author();
    if (author == null || !ref.mounted) return;
    await _commit(
      on: document,
      (document) async => (await _engine.addAnnotation(
        document,
        page,
        draft(author),
        _l10n.commentStepAdd,
      )).revision,
    );
  }

  /// [addLeft] for [change] of annotation [handle].
  Future<void> updateLeft(int document, int handle, AnnotationChange change) =>
      _commit(
        on: document,
        (document) async => (await _engine.updateAnnotation(
          document,
          handle,
          change,
          _l10n.commentStepChange,
        )).revision,
      );

  /// Marks the text of [selection] as [kind] in [color].
  Future<void> markText(
    AnnotationKind kind,
    PageSelection selection,
    AnnotationColor color, {
    bool composing = false,
  }) {
    final document = ref.read(openDocumentProvider);
    if (document == null) return Future.value();
    return add(
      document.pageHandle(selection.page),
      (author) => NewAnnotation(
        kind: kind,
        color: color,
        author: author,
        points: [
          for (final quad in selection.quads)
            [quad.topLeft, quad.topRight, quad.bottomLeft, quad.bottomRight],
        ],
      ),
      composing: composing,
    );
  }

  /// Applies [change] to annotation [handle].
  Future<void> update(int handle, AnnotationChange change) => _commit((
    document,
  ) async {
    final commit = await _engine.updateAnnotation(
      document,
      handle,
      change,
      _l10n.commentStepChange,
    );
    ref.read(commentSelectionProvider.notifier).follow(handle, commit.handle);
    return commit.revision;
  });

  /// Deletes annotation [handle], with its replies; a toast offers Undo (G46).
  Future<void> delete(int handle) => _commit(
    (document) =>
        _engine.deleteAnnotation(document, handle, _l10n.commentStepDelete),
    committed: () {
      ref.read(commentSelectionProvider.notifier).clear();
      ref
          .read(pageCommandsProvider.notifier)
          .offerUndo(
            (l10n) => l10n.commentDeletedToast,
            (l10n) => l10n.commentDeletedNote,
          );
    },
  );

  /// Sends [text] on [thread]: the text of a mark its author left without one,
  /// else a reply. Nothing is sent to anyone (a4-2).
  Future<void> reply(CommentThread thread, String text) async {
    final author = await _author();
    if (author == null || !ref.mounted) return;
    final top = thread.top;
    if ((top.contents ?? '').isEmpty && top.author == author) {
      await update(top.handle, AnnotationChange(contents: text));
      return;
    }
    await _commit(
      (document) async => (await _engine.replyToAnnotation(
        document,
        top.handle,
        author: author,
        text: text,
        name: _l10n.commentStepReply,
      )).revision,
    );
  }

  /// Resolves or reopens the thread of [handle].
  Future<void> resolve(int handle, {required bool resolved}) async {
    final author = await _author();
    if (author == null || !ref.mounted) return;
    await _commit(
      (document) => _engine.setAnnotationResolved(
        document,
        handle,
        author: author,
        resolved: resolved,
        name: resolved ? _l10n.commentStepResolve : _l10n.commentStepReopen,
      ),
    );
  }

  /// a3-1c's Highlight and Comment: marks characters [start] to [end] of the
  /// block [block] of the page [page] in yellow.
  Future<void> markBlockText(
    int page,
    int block,
    int start,
    int end,
    AnnotationColor color, {
    required bool composing,
  }) async {
    final document = ref.read(openDocumentProvider)?.id;
    if (document == null) return;
    final PageSelection selection;
    try {
      selection = await _engine.selection(
        document,
        page,
        BlockPosition(block: block, index: start),
        BlockPosition(block: block, index: end),
      );
    } on EngineException catch (error) {
      showPageChangeFailure(ref.read(toastNoticesProvider.notifier), error, '');
      return;
    }
    if (selection.quads.isEmpty) return;
    await markText(
      AnnotationKind.highlight,
      PageSelection(page: page, quads: selection.quads, text: selection.text),
      color,
      composing: composing,
    );
  }

  /// a4-4's Export summary: asks where to write, then writes the comments of
  /// the open document as [format] and the choices say, as a job.
  Future<void> exportSummary(
    SummaryFormat format, {
    required bool open,
    required bool resolved,
    required bool replies,
    required bool emptyPages,
    required SummarySort sort,
    required PaperSize paper,
  }) async {
    final document = ref.read(openDocumentProvider);
    if (document == null) return;
    final l10n = _l10n;
    final output = await ref
        .read(filePickerServiceProvider)
        .saveFile(
          suggestedName: format == SummaryFormat.csv
              ? l10n.commentSummaryCsvFile
              : l10n.commentSummaryFile,
        );
    if (output == null || !ref.mounted) return;
    final dates = RegionFormat.forRegion(ref.read(regionProvider).region);
    await ref
        .read(backgroundJobsProvider.notifier)
        .commentSummary(
          document.id,
          output: output,
          format: format,
          options: SummaryOptions(
            open: open,
            resolved: resolved,
            replies: replies,
            emptyPages: emptyPages,
            sort: sort,
            pageLabel: l10n.sidebarPage('{n}'),
            columns: [
              l10n.commentColumnPage,
              l10n.commentColumnType,
              l10n.commentColumnAuthor,
              l10n.commentColumnDate,
              l10n.commentColumnText,
              l10n.commentColumnReplies,
              l10n.commentColumnStatus,
            ],
            kinds: {
              for (final kind in AnnotationKind.values)
                kind: l10n.commentKindName(kind),
            },
            openLabel: l10n.commentStatusOpen,
            resolvedLabel: l10n.commentStatusResolved,
            noComments: l10n.commentsEmptyTitle,
            datePattern: dates.numericDateTimePattern,
            paperWidth: paper.widthPoints,
            paperHeight: paper.heightPoints,
          ),
        );
  }
}
