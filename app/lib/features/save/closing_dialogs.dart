import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/save/document_closer.dart';
import 'package:ferman/features/save/document_recovery.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_tab.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The questions of closing, quitting and crash recovery around [child], every
/// screen of the window: a1-10b, a11-7e, a1-12 and its a1-8. Nothing is drawn
/// until one asks, so [child] keeps its place and size.
class ClosingOverlays extends ConsumerWidget {
  /// The questions around [child].
  const new({required this.child, super.key});

  /// The screen.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closing = ref.watch(documentCloserProvider);
    final recovery = ref.watch(documentRecoveryProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (closing.asking case final tab?) UnsavedCloseDialog(tab),
        if (closing.reviewing.isNotEmpty)
          QuitReviewDialog(
            closing.reviewing,
            key: ObjectKey(closing.reviewing),
          ),
        if (recovery.offered.isNotEmpty)
          RecoveryDialog(recovery.offered, key: ObjectKey(recovery.offered)),
        if (recovery.asking case final document?)
          _RecoveryPassword(document, key: ObjectKey(document)),
      ],
    );
  }
}

/// [count] edits as a1-10b and a11-7e count them; a document with typing only
/// has no steps yet, and counts as one.
String _edits(AppLocalizations l10n, RegionFormat format, int count) {
  final shown = count < 1 ? 1 : count;
  return l10n.closingEdits(shown, format.integer(shown));
}

/// a1-10b: closing or quitting with one unsaved document. Save (the default,
/// Enter), "Don't save" (⌘D or Ctrl+D) and Cancel (Esc), in the system's order
/// ([DialogButtonOrder]).
class UnsavedCloseDialog extends ConsumerStatefulWidget {
  /// The question about [document].
  const new(this.document, {super.key});

  /// The document's tab.
  final ShellDocument document;

  @override
  ConsumerState<UnsavedCloseDialog> createState() => _UnsavedCloseDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ShellDocument>('document', document));
  }
}

class _UnsavedCloseDialogState extends ConsumerState<UnsavedCloseDialog> {
  bool _onKey(KeyEvent event) {
    final platform = ref.read(shortcutPlatformProvider);
    final keys = HardwareKeyboard.instance;
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyD ||
        !(platform == ShortcutPlatform.mac
            ? keys.isMetaPressed
            : keys.isControlPressed)) {
      return false;
    }
    unawaited(ref.read(documentCloserProvider.notifier).discard());
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final closer = ref.read(documentCloserProvider.notifier);
    return Dialog(
      icon: IconName.save,
      title: l10n.closeUnsavedTitle(bidiIsolate(widget.document.name)),
      description: l10n.closeUnsavedBody(
        _edits(l10n, format, widget.document.editCount),
      ),
      onClose: closer.cancel,
      closeLabel: l10n.saveAsClose,
      alternateAction: Button(
        variant: ButtonVariant.ghost,
        onPressed: () => unawaited(closer.discard()),
        child: Text(l10n.closeUnsavedDiscard),
      ),
      cancelAction: Button(
        onPressed: closer.cancel,
        child: Text(l10n.saveAsCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          autofocus: true,
          onPressed: () => unawaited(closer.save()),
          child: Text(l10n.closeUnsavedSave),
        ),
      ],
    );
  }
}

/// A checked row of a1-12's and a11-7e's lists.
class _CheckRow extends StatelessWidget {
  const new({
    required this.name,
    required this.checked,
    required this.onChanged,
    required this.last,
    this.caption,
    this.badge,
    this.warning = false,
  });

  final String name;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final bool last;
  final String? caption;
  final String? badge;
  final bool warning;

  /// `gap: 12px`, between the box and the text.
  static const double gap = 12;

  /// `padding: 12px 14px`, horizontally; vertically it is [gap].
  static const double paddingX = 14;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: paddingX,
        vertical: gap,
      ),
      decoration: BoxDecoration(
        color: warning ? colors.warningBg : null,
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: colors.borderSubtle,
                  width: theme.border.borderWidth,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: warning
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        spacing: gap,
        children: [
          Semantics(
            label: name,
            child: Checkbox(checked: checked, onChanged: onChanged),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // `gap: 4px` in a11-7f's warning row, `2px` in the others.
              spacing: warning ? theme.space.space1 : theme.space.space0_5,
              children: [
                Wrap(
                  spacing: theme.space.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(bidiIsolate(name), style: theme.typography.bodyStrong),
                    if (badge case final label?)
                      Badge(
                        tone: BadgeTone.warning,
                        icon: IconName.triangleAlert,
                        label: label,
                      ),
                  ],
                ),
                if (caption case final text?)
                  Text(
                    text,
                    style: theme.typography.caption.copyWith(
                      color: warning
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The bordered list a1-12 and a11-7e share.
class _CheckList extends StatelessWidget {
  const new({required this.rows});

  final List<_CheckRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colors.borderSubtle,
          width: theme.border.borderWidth,
        ),
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusMd)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// a11-7e: quitting with several unsaved documents, asked once: one checked
/// row per document, "Save and quit" (Enter), "Quit without saving" and Cancel
/// (Esc).
class QuitReviewDialog extends ConsumerStatefulWidget {
  /// The question about [documents].
  const new(this.documents, {super.key});

  /// The documents with unsaved changes.
  final List<ShellDocument> documents;

  @override
  ConsumerState<QuitReviewDialog> createState() => _QuitReviewDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<ShellDocument>('documents', documents));
  }
}

class _QuitReviewDialogState extends ConsumerState<QuitReviewDialog> {
  late final Set<ShellDocument> _checked = {...widget.documents};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final closer = ref.read(documentCloserProvider.notifier);
    final count = widget.documents.length;
    return Dialog(
      icon: IconName.save,
      title: l10n.quitReviewTitle(count, format.integer(count)),
      description: l10n.quitReviewBody,
      onClose: closer.cancel,
      closeLabel: l10n.saveAsClose,
      alternateAction: Button(
        variant: ButtonVariant.ghost,
        onPressed: () => unawaited(closer.quitWithoutSaving()),
        child: Text(l10n.quitReviewDiscard),
      ),
      cancelAction: Button(
        onPressed: closer.cancel,
        child: Text(l10n.saveAsCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          autofocus: true,
          onPressed: () => unawaited(closer.saveAndQuit(_checked)),
          child: Text(l10n.quitReviewSave),
        ),
      ],
      child: _CheckList(
        rows: [
          for (final (index, tab) in widget.documents.indexed)
            _CheckRow(
              name: tab.name,
              caption: _edits(l10n, format, tab.editCount),
              checked: _checked.contains(tab),
              last: index == count - 1,
              onChanged: (checked) => setState(
                () => checked ? _checked.add(tab) : _checked.remove(tab),
              ),
            ),
        ],
      ),
    );
  }
}

/// a1-12 and a11-7f at launch: what a session that ended without cleaning up
/// left, each document checked, "Open N documents" (Enter) and Discard. An
/// original that changed since gets the warning badge and says it opens under
/// a new name. The engine gives no times, so the copy names none (G40); Copy
/// crash log is hidden while no crash log exists (B142).
class RecoveryDialog extends ConsumerStatefulWidget {
  /// The offer of [documents].
  const new(this.documents, {super.key});

  /// The documents with recovery files.
  final List<RecoverableDocument> documents;

  @override
  ConsumerState<RecoveryDialog> createState() => _RecoveryDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      IterableProperty<RecoverableDocument>('documents', documents),
    );
  }
}

class _RecoveryDialogState extends ConsumerState<RecoveryDialog> {
  late final Set<RecoverableDocument> _checked = {...widget.documents};

  /// The folder of [path], the home directory shown as "~".
  String _folder(String path) {
    final folder = folderOf(path);
    final home = ref.read(homeDirectoryProvider);
    return home != null && (folder == home || folder.startsWith('$home/'))
        ? '~${folder.substring(home.length)}'
        : folder;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final recovery = ref.read(documentRecoveryProvider.notifier);
    final count = widget.documents.length;
    final checked = _checked.length;
    return Dialog(
      icon: IconName.history,
      title: l10n.recoveryTitle(count, format.integer(count)),
      description: l10n.recoveryBody,
      cancelAction: Button(
        onPressed: () => unawaited(recovery.discard()),
        child: Text(l10n.recoveryDiscard),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          autofocus: true,
          onPressed: checked == 0
              ? null
              : () => unawaited(recovery.open(_checked)),
          child: Text(l10n.recoveryOpen(checked, format.integer(checked))),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space3,
        children: [
          _CheckList(
            rows: [
              for (final (index, document) in widget.documents.indexed)
                _CheckRow(
                  name: fileName(document.original),
                  warning: document.originalChanged,
                  badge: document.originalChanged
                      ? l10n.recoveryChangedBadge
                      : null,
                  caption: document.originalChanged
                      ? l10n.recoveryChangedBody
                      : '${_edits(l10n, format, document.changes)} · '
                            '${_folder(document.original)}',
                  checked: _checked.contains(document),
                  last: index == count - 1,
                  onChanged: (value) => setState(
                    () => value
                        ? _checked.add(document)
                        : _checked.remove(document),
                  ),
                ),
            ],
          ),
          Text(
            l10n.recoveryNote,
            style: theme.typography.caption.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// a1-8 over the window for an encrypted document being restored.
class _RecoveryPassword extends ConsumerWidget {
  const new(this.document, {super.key});

  final RecoverableDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final recovery = ref.read(documentRecoveryProvider.notifier);
    return Scrim(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(theme.space.space6),
        child: PasswordDialog(
          icon: IconName.lock,
          title: l10n.errorPasswordRequired,
          description: l10n.unlockDescription(
            bidiIsolate(fileName(document.original)),
          ),
          label: l10n.unlockPassword,
          action: l10n.unlockOpen,
          onSubmit: recovery.unlock,
          onCancel: recovery.skip,
        ),
      ),
    );
  }
}
