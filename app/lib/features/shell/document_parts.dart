import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'document_parts.g.dart';

/// What the open document's permissions say about changing its information
/// and attachments (a2-7, a2-3b); null until the engine answers.
@riverpod
Future<OpGate?> modifyGate(Ref ref) async {
  final document = ref.watch(openDocumentProvider);
  if (document == null) return null;
  return await ref
      .read(engineServiceProvider)
      .opGate(document.id, DocumentOp.modify);
}

/// Why the open document's information and attachments cannot change, in
/// the language given, or null when they can.
@riverpod
String Function(AppLocalizations)? modifyRefusal(Ref ref) {
  if (ref.watch(openDocumentProvider)?.readOnly != null) {
    return (l10n) => l10n.editTipReadOnly;
  }
  return ref.watch(modifyGateProvider).value == OpGate.forbidden
      ? (l10n) => l10n.editTipRestricted
      : null;
}

/// Where a bookmark dragged onto another goes (a2-3a).
enum OutlineDrop {
  /// Before it, at its level.
  before,

  /// Its first child.
  into,

  /// After it and its children, at its level.
  after,
}

/// [outline] as `EngineService.setOutline` keeps it, every item unchanged.
List<OutlineEdit> keptOutline(List<OutlineEntry> outline) => [
  for (final (index, entry) in outline.indexed)
    OutlineEdit(
      item: index,
      title: entry.title,
      depth: entry.depth,
      open: entry.open,
    ),
];

OutlineEdit _copy(OutlineEdit edit, {String? title, int? depth}) => OutlineEdit(
  item: edit.item,
  page: edit.page,
  title: title ?? edit.title,
  depth: depth ?? edit.depth,
  open: edit.open,
);

/// The end (exclusive) of [index]'s branch: the item and its children.
int outlineBranchEnd(List<OutlineEdit> items, int index) {
  var end = index + 1;
  while (end < items.length && items[end].depth > items[index].depth) {
    end++;
  }
  return end;
}

/// [items] with [index] named [title].
List<OutlineEdit> outlineRenamed(
  List<OutlineEdit> items,
  int index,
  String title,
) => [...items]..[index] = _copy(items[index], title: title);

/// [items] without [index] and its children.
List<OutlineEdit> outlineRemoved(List<OutlineEdit> items, int index) =>
    [...items]..removeRange(index, outlineBranchEnd(items, index));

/// [items] with [edit] at [at].
List<OutlineEdit> outlineAdded(
  List<OutlineEdit> items,
  int at,
  OutlineEdit edit,
) => [...items]..insert(at, edit);

/// [items] with [from]'s branch moved to [where] of [target]; null when
/// [target] is in that branch. Each of the three places keeps every item at
/// most one level below the one before it.
List<OutlineEdit>? outlineMoved(
  List<OutlineEdit> items,
  int from,
  int target,
  OutlineDrop where,
) {
  final end = outlineBranchEnd(items, from);
  if (target >= from && target < end) return null;
  final branch = items.sublist(from, end);
  final rest = [...items]..removeRange(from, end);
  final at = target < from ? target : target - branch.length;
  final (index, depth) = switch (where) {
    OutlineDrop.before => (at, rest[at].depth),
    OutlineDrop.into => (at + 1, rest[at].depth + 1),
    OutlineDrop.after => (outlineBranchEnd(rest, at), rest[at].depth),
  };
  final shift = depth - branch.first.depth;
  return rest..insertAll(index, [
    for (final edit in branch) _copy(edit, depth: edit.depth + shift),
  ]);
}

/// [items] with [index]'s branch one level in, under the item above, or
/// out; null when it cannot go there.
List<OutlineEdit>? outlineNested(
  List<OutlineEdit> items,
  int index, {
  required bool inward,
}) {
  final depth = items[index].depth;
  if (inward ? index == 0 || items[index - 1].depth < depth : depth == 0) {
    return null;
  }
  final end = outlineBranchEnd(items, index);
  return [
    for (final (at, edit) in items.indexed)
      if (at >= index && at < end)
        _copy(edit, depth: edit.depth + (inward ? 1 : -1))
      else
        edit,
  ];
}

/// [items] with [index]'s branch swapped with its sibling before it
/// ([down] false) or after it; null when it has none.
List<OutlineEdit>? outlineStepped(
  List<OutlineEdit> items,
  int index, {
  required bool down,
}) {
  final depth = items[index].depth;
  if (down) {
    final next = outlineBranchEnd(items, index);
    return next < items.length && items[next].depth == depth
        ? outlineMoved(items, index, next, OutlineDrop.after)
        : null;
  }
  for (var at = index - 1; at >= 0 && items[at].depth >= depth; at--) {
    if (items[at].depth == depth) {
      return outlineMoved(items, index, at, OutlineDrop.before);
    }
  }
  return null;
}

/// The last item of [outline] at or before [page], in reading order: where
/// ⌘B adds the next one.
int? outlineItemAt(List<OutlineEntry> outline, int page) {
  int? found;
  for (final (index, entry) in outline.indexed) {
    if ((entry.page ?? page + 1) <= page) found = index;
  }
  return found;
}

/// The bookmark the Outline tab renames in place (a2-3a), by its index in
/// the open document's outline; null for none.
@Riverpod(keepAlive: true)
class OutlineRenaming extends _$OutlineRenaming {
  @override
  int? build() {
    ref.watch(openDocumentProvider.select((document) => document?.id));
    return null;
  }

  /// Renames [index].
  // ignore: use_setters_to_change_properties
  void start(int index) => state = index;

  /// Stops renaming.
  void stop() => state = null;
}

/// The bookmark the Outline tab's More menu, F2 and Delete act on, by its
/// index in the open document's outline: the one last clicked or focused;
/// null for the reader's section.
@Riverpod(keepAlive: true)
class OutlineSelected extends _$OutlineSelected {
  @override
  int? build() {
    ref.watch(openDocumentProvider.select((document) => document?.outline));
    return null;
  }

  /// Selects [index].
  // ignore: use_setters_to_change_properties
  void select(int index) => state = index;
}

/// What the Outline tab's More menu does to a bookmark (a2-3a).
enum OutlineAction {
  /// Renames it in place (F2).
  rename,

  /// Nests it under the one above.
  nest,

  /// Moves it out a level.
  unnest,

  /// Swaps it with the one above at its level.
  moveUp,

  /// Swaps it with the one below at its level.
  moveDown,

  /// Deletes it and the ones nested in it (Delete).
  delete;

  /// [items] after this action on [index]; null when it cannot apply. Rename
  /// leaves them as they are: the field renames.
  List<OutlineEdit>? on(List<OutlineEdit> items, int index) => switch (this) {
    rename => items,
    nest => outlineNested(items, index, inward: true),
    unnest => outlineNested(items, index, inward: false),
    moveUp => outlineStepped(items, index, down: false),
    moveDown => outlineStepped(items, index, down: true),
    delete => outlineRemoved(items, index),
  };
}

/// Does [action] to bookmark [index] of [document] as one step.
void runOutlineAction(
  WidgetRef ref,
  AppLocalizations l10n,
  OpenedDocument document,
  OutlineAction action,
  int index,
) {
  if (action == OutlineAction.rename) {
    ref.read(outlineRenamingProvider.notifier).start(index);
    return;
  }
  final items = action.on(keptOutline(document.outline), index);
  if (items == null) return;
  commitOutline(ref, document.id, items, l10n.outlineStep);
}

/// Makes [items] the outline of [document] as one step named [name], then
/// runs [committed].
void commitOutline(
  WidgetRef ref,
  int document,
  List<OutlineEdit> items,
  String name, {
  VoidCallback? committed,
}) => commitPageChange(
  ref,
  document,
  () => ref.read(engineServiceProvider).setOutline(document, items, name),
  committed: committed,
);

/// ⌘B and the Outline tab's Add bookmark (a2-3a): a bookmark to the reader's
/// page after the section it is in, renamed in place once added.
void addBookmark(WidgetRef ref) {
  final view = ref.read(viewerProvider);
  if (view == null || ref.read(organizeRefusalProvider) != null) return;
  final l10n = lookupAppLocalizations(ref.read(appLocaleProvider));
  final document = view.document;
  final items = keptOutline(document.outline);
  final current = outlineItemAt(document.outline, view.currentPage);
  final at = current == null ? 0 : outlineBranchEnd(items, current);
  ref.read(shellSidebarTabProvider.notifier).select(SidebarTab.outline);
  if (!ref.read(shellPanelsProvider).shows(ShellSide.sidebar)) {
    toggleShellSide(ref, ShellSide.sidebar);
  }
  commitOutline(
    ref,
    document.id,
    outlineAdded(
      items,
      at,
      OutlineEdit(
        title: l10n.outlineNewBookmark,
        page: view.currentPage,
        depth: current == null ? 0 : items[current].depth,
      ),
    ),
    l10n.outlineStep,
    committed: () => ref.read(outlineRenamingProvider.notifier).start(at),
  );
}

/// Attach a file (a2-3b): a file the open panel picks, embedded in
/// [document] as one step.
Future<void> attachFile(
  WidgetRef ref,
  AppLocalizations l10n,
  int document,
) async {
  final engine = ref.read(engineServiceProvider);
  final path = await ref.read(filePickerServiceProvider).openAnyFile();
  if (path == null) return;
  commitPageChange(
    ref,
    document,
    () =>
        engine.attachFile(document, path, fileName(path), l10n.shellAttachFile),
  );
}

/// A text field that edits a name in place (a2-3a's bookmark, a2-7's
/// metadata): it starts focused with the text selected; Enter or leaving it
/// calls [onDone] with the text, Esc with null.
class InlineNameField extends StatefulWidget {
  /// Edits [initial], named [label] for screen readers.
  const new({
    required this.initial,
    required this.label,
    required this.onDone,
    super.key,
  });

  /// The text it starts with.
  final String initial;

  /// The field's accessible name.
  final String label;

  /// Called once with the text, or null when cancelled.
  final ValueChanged<String?> onDone;

  @override
  State<InlineNameField> createState() => _InlineNameFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('initial', initial))
      ..add(StringProperty('label', label))
      ..add(ObjectFlagProperty<ValueChanged<String?>>.has('onDone', onDone));
  }
}

class _InlineNameFieldState extends State<InlineNameField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.length,
        );
  final FocusNode _focus = FocusNode(debugLabel: 'Inline name');
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish(_controller.text);
    });
  }

  void _finish(String? text) {
    if (_done) return;
    _done = true;
    widget.onDone(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () => _finish(null),
    },
    child: TextField(
      size: FieldSize.sm,
      autofocus: true,
      controller: _controller,
      focusNode: _focus,
      semanticLabel: widget.label,
      onSubmitted: _finish,
    ),
  );
}
