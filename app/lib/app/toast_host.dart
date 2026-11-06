import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/editor/edit_callouts.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/save/save_dialogs.dart';
import 'package:ferman/features/shell/attachment_save.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'toast_host.g.dart';

/// A toast's text, read in the language showing when it draws: first run
/// can change the language under a toast.
typedef ToastText = String Function(AppLocalizations l10n);

/// A toast raised with [ToastNotices.show].
final class ToastNotice {
  /// The toast numbered [id].
  const new({
    required this.id,
    required this.tone,
    required this.title,
    this.message,
    this.action,
  });

  /// What [ToastNotices.dismiss] takes.
  final int id;

  /// A danger toast stays until dismissed; the others leave on their own.
  final ToastTone tone;

  /// The bold first line.
  final ToastText title;

  /// The second line.
  final ToastText? message;

  /// The one action (Undo); pressing it also dismisses the toast.
  final ({ToastText label, VoidCallback onPressed})? action;
}

/// The toasts that belong to no other state, in the order they came.
@Riverpod(keepAlive: true)
class ToastNotices extends _$ToastNotices {
  int _next = 0;

  @override
  List<ToastNotice> build() => const [];

  /// Shows a toast; the result is what [dismiss] takes.
  int show({
    required ToastText title,
    ToastTone tone = ToastTone.neutral,
    ToastText? message,
    ({ToastText label, VoidCallback onPressed})? action,
  }) {
    final id = _next++;
    state = [
      ...state,
      ToastNotice(
        id: id,
        tone: tone,
        title: title,
        message: message,
        action: action,
      ),
    ];
    return id;
  }

  /// Takes away the toast [id], if it still shows.
  void dismiss(int id) {
    state = [
      for (final notice in state)
        if (notice.id != id) notice,
    ];
  }
}

/// The height of the task drawer while it is open, 0 while it is closed:
/// toasts stack above it, so they never overlap (decision 31, G49).
@Riverpod(keepAlive: true)
class TaskDrawerHeight extends _$TaskDrawerHeight {
  @override
  double build() => 0;

  /// The drawer now takes [height] above the status bar.
  // ignore: use_setters_to_change_properties
  void set(double height) => state = height;
}

/// The toasts of the whole window over [child], every screen below the title
/// bar (a11-6, G49): at the bottom end, above the status bar and the open
/// task drawer, newest lowest, mirrored in right to left.
///
/// At most three show. A toast past that waits, without running its time,
/// and shows when one below it leaves, so no error is lost. Errors stay until
/// dismissed; the rest leave after [lifetime], which starts again once the
/// pointer and the focus leave them.
class ToastHost extends ConsumerWidget {
  /// The toasts over [child], the screen at the route [path].
  const new({required this.path, required this.child, super.key});

  /// a11-6: "the rest leave after 6 seconds".
  static const int lifetimeMs = 6000;

  /// [lifetimeMs] as a duration: not motion, so not a token.
  static const Duration lifetime = Duration(milliseconds: lifetimeMs);

  /// The most that show at a time (G49).
  static const int maxShown = 3;

  /// The route showing: the status bar is the editor's, and the start screen
  /// has a banner of its own for a file that did not open.
  final String path;

  /// The screen.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final problem = path == Routes.start
        ? null
        : ref.watch(documentOpenerProvider);
    final saveFailure = ref.watch(
      documentSaverProvider.select((s) => s.toast ? s.failure : null),
    );
    final unsaved = ref.watch(attachmentSaverProvider);
    // Only with a document: the editor starts its font and recovery work
    // when first read, which first run and the start screen must not cause.
    final substituted = ref.watch(openDocumentProvider) == null
        ? null
        : ref.watch(documentEditorProvider.select((s) => s.toast));
    final toasts = <_Slot>[
      if (problem != null)
        _Slot(key: ValueKey(problem), child: OpenProblemToast(problem)),
      if (saveFailure != null)
        _Slot(key: ValueKey(saveFailure), child: SaveFailureToast(saveFailure)),
      if (unsaved != null)
        _Slot(key: ValueKey(unsaved), child: AttachmentSaveToast(unsaved)),
      if (substituted != null)
        _Slot(
          key: ValueKey(substituted),
          onExpired: ref.read(documentEditorProvider.notifier).dismissToast,
          child: FontSubstitutedToast(substituted),
        ),
      for (final notice in ref.watch(toastNoticesProvider))
        _Slot(
          key: ValueKey(notice.id),
          onExpired: notice.tone == ToastTone.danger
              ? null
              : () =>
                    ref.read(toastNoticesProvider.notifier).dismiss(notice.id),
          child: _NoticeToast(notice),
        ),
    ];
    final bare = ref.watch(shellDocumentsProvider).active?.bare ?? false;
    final statusBar = path == Routes.editor && !bare;
    // The canvas holds the drawer, and the height stays when it unmounts.
    final drawer =
        path == Routes.editor &&
        ref.watch(backgroundJobsProvider.select((jobs) => jobs.open));
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (toasts.isNotEmpty)
          // `.fm-toast-region`: 16 px from the end, 12 px above the status
          // bar, 8 px apart; narrower than a toast on a phone.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              theme.space.space4,
              theme.space.space3,
              theme.space.space4,
              theme.space.space3 +
                  (statusBar ? theme.density.statusbarH : 0) +
                  (drawer ? ref.watch(taskDrawerHeightProvider) : 0),
            ),
            child: Align(
              alignment: AlignmentDirectional.bottomEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Toast.width),
                // A window too short for all three scrolls them; the toasts'
                // shadows stay unclipped.
                child: SingleChildScrollView(
                  primary: false,
                  reverse: true,
                  clipBehavior: Clip.none,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: theme.space.space2,
                    children: toasts.length > maxShown
                        ? toasts.sublist(toasts.length - maxShown)
                        : toasts,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('path', path));
  }
}

/// One toast's place in the stack, which holds its time.
class _Slot extends StatefulWidget {
  const new({required this.child, super.key, this.onExpired});

  /// Called when its time is up; null for a toast that stays.
  final VoidCallback? onExpired;

  final Widget child;

  @override
  State<_Slot> createState() => _SlotState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      ObjectFlagProperty<VoidCallback>.has('onExpired', onExpired),
    );
  }
}

class _SlotState extends State<_Slot> {
  Timer? _timer;
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = _hovered || _focused || widget.onExpired == null
        ? null
        : Timer(ToastHost.lifetime, () => widget.onExpired?.call());
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) {
      _hovered = true;
      _restart();
    },
    onExit: (_) {
      _hovered = false;
      _restart();
    },
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) {
        _focused = focused;
        _restart();
      },
      child: widget.child,
    ),
  );
}

/// The [Toast] of a [ToastNotice]. a11-6 draws Dismiss on none of its toasts,
/// so only the error, which stays, has it.
class _NoticeToast extends ConsumerWidget {
  const new(this.notice);

  final ToastNotice notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notices = ref.read(toastNoticesProvider.notifier);
    final action = notice.action;
    return Toast(
      tone: notice.tone,
      title: notice.title(l10n),
      message: notice.message?.call(l10n),
      action: action == null
          ? null
          : (
              label: action.label(l10n),
              onPressed: () {
                notices.dismiss(notice.id);
                action.onPressed();
              },
            ),
      onClose: notice.tone == ToastTone.danger
          ? () => notices.dismiss(notice.id)
          : null,
      closeLabel: l10n.saveToastDismiss,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ToastNotice>('notice', notice));
  }
}
