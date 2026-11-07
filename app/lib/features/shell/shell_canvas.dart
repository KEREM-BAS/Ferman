import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/comments/comments_panel.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/jobs/task_drawer.dart';
import 'package:ferman/features/organize/combine_tab.dart';
import 'package:ferman/features/organize/crop_overlay.dart';
import 'package:ferman/features/organize/crop_session.dart';
import 'package:ferman/features/organize/page_grid.dart';
import 'package:ferman/features/save/save_dialogs.dart';
import 'package:ferman/features/shell/document_banners.dart';
import 'package:ferman/features/shell/document_properties.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_tab.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/find_bar.dart';
import 'package:ferman/features/viewer/text_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The document canvas between the sidebar and the panel (FmWindow's
/// `<main>` on `--surface-canvas`).
///
/// With a document open (`viewerProvider`) it shows its pages
/// ([DocumentView]), names the page in its semantics and scrolls with ↑,
/// ↓, Page Up, Page Down, Space, Home and End. While the document is still
/// opening it shows only the canvas background (no board draws an empty
/// canvas, G86). It is a
/// focus stop named "Document pages", focused when the shell opens, so the
/// shortcut table's keys work at once. The inset focus ring shows once the
/// keyboard is used there: not for the focus it gets at launch (no board
/// draws a ring around the document area), but after a key press on it or
/// when Tab brings focus back to it. The shortcut
/// table's canvas keys (`ShortcutScope.canvas`: page turns, form fields,
/// the page grid) are bound here. The canvas is never mirrored in right to
/// left: its subtree runs with a left-to-right [Directionality], as pages
/// keep their own geometry (ADR 0014).
class ShellCanvas extends ConsumerStatefulWidget {
  /// The canvas.
  const new({super.key});

  @override
  ConsumerState<ShellCanvas> createState() => _ShellCanvasState();
}

class _ShellCanvasState extends ConsumerState<ShellCanvas> {
  final FocusNode _focus = FocusNode(debugLabel: 'ShellCanvas');

  /// The document whose owner-password dialog shows (G106), by id: it
  /// stays with that document when another tab shows.
  int? _ownerUnlock;

  /// The document whose properties show (a2-7), by id, like
  /// [_ownerUnlock].
  int? _properties;

  /// Whether the system would show a focus highlight now.
  bool _highlight = false;

  /// Whether the canvas still holds the focus it got at launch, before any
  /// key press on it.
  bool _launchFocus = true;

  @override
  void initState() {
    super.initState();
    _focus.onKeyEvent = (_, event) {
      if (_launchFocus) setState(() => _launchFocus = false);
      if (_commentKey(event) || _scroll(event)) return KeyEventResult.handled;
      // The shortcuts above still get the key.
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// a4-1: Delete and Esc on the mark selected on the page, never on keys a
  /// text field inside the canvas is getting.
  bool _commentKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        ref.read(shellModeProvider) != FermanMode.comment ||
        ShellCommandAction.typing) {
      return false;
    }
    final selected = ref.read(commentSelectionProvider)?.handle;
    if (selected == null ||
        !ref.read(commentsShownProvider).visible ||
        !ref
            .read(documentThreadsProvider)
            .any((thread) => thread.top.handle == selected)) {
      return false;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.delete || LogicalKeyboardKey.backspace:
        if (ref.read(commentRefusalProvider) == null) {
          unawaited(
            ref.read(commentCommandsProvider.notifier).delete(selected),
          );
        }
      case LogicalKeyboardKey.escape:
        ref.read(commentSelectionProvider.notifier).clear();
      default:
        return false;
    }
    return true;
  }

  /// The line ↑ and ↓ scroll.
  static const double _line = 40;

  /// Scrolls the open document for a scrolling key; false for other keys,
  /// with modifiers, or without a document.
  bool _scroll(KeyEvent event) {
    final view = ref.read(viewerProvider);
    if (view == null || event is KeyUpEvent) return false;
    final keys = HardwareKeyboard.instance;
    if (keys.isMetaPressed || keys.isControlPressed || keys.isAltPressed) {
      return false;
    }
    final viewer = ref.read(viewerProvider.notifier);
    final screen = view.viewport.height * 0.9;
    final back = keys.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        viewer.scrollBy(const Offset(0, _line));
      case LogicalKeyboardKey.arrowUp:
        viewer.scrollBy(const Offset(0, -_line));
      case LogicalKeyboardKey.pageDown:
        viewer.scrollBy(Offset(0, screen));
      case LogicalKeyboardKey.pageUp:
        viewer.scrollBy(Offset(0, -screen));
      case LogicalKeyboardKey.space:
        viewer.scrollBy(Offset(0, back ? -screen : screen));
      case LogicalKeyboardKey.home when event is KeyDownEvent:
        viewer.goToPage(0);
      case LogicalKeyboardKey.end when event is KeyDownEvent:
        viewer.goToPage(view.pageSizes.length - 1);
      default:
        return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final mode = ref.watch(shellModeProvider);
    // The UI's direction, for the placeholder's copy inside the canvas's
    // own left-to-right geometry.
    final uiDirection = Directionality.of(context);
    final view = ref.watch(viewerProvider);
    final selection = ref.watch(canvasSelectionProvider);
    ref.listen(documentPropertiesRequestProvider, (_, _) {
      final id = ref.read(viewerProvider)?.document.id;
      if (id != null) setState(() => _properties = id);
    });
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final active = ref.watch(shellDocumentsProvider).active;
    // a11-6b: below the dialogs, at the canvas's bottom end.
    final taskDrawer = ref.watch(backgroundJobsProvider.select((s) => s.open))
        ? PositionedDirectional(
            top: theme.space.space2,
            bottom: theme.space.space2,
            start: theme.space.space3,
            end: theme.space.space3,
            child: const TaskDrawer(),
          )
        : null;
    // a1-7: a file still opening, with its Cancel (also Esc).
    final opening = active != null && active.loading ? active.path : null;
    void cancelOpening() =>
        ref.read(documentOpenerProvider.notifier).close(opening!);
    final hiddenComments = !ref.watch(commentsShownProvider).visible;
    return Shortcuts(
      shortcuts: ShellCommand.shortcutsFor(
        platform,
        mode,
        scope: ShortcutScope.canvas,
      ),
      // The focus stop itself is named, so focusing it reads "Document
      // pages"; the empty state is a node of its own inside it.
      child: CallbackShortcuts(
        bindings: {
          if (opening != null)
            const SingleActivator(LogicalKeyboardKey.escape): cancelOpening,
          // B106: the Select tool's text.
          if (selection != null)
            SingleActivator(
              LogicalKeyboardKey.keyC,
              meta: platform == ShortcutPlatform.mac,
              control: platform != ShortcutPlatform.mac,
            ): () =>
                copySelection(selection),
        },
        child: Semantics(
          container: true,
          label: l10n.shellCanvas,
          value: view == null
              ? null
              : l10n.shellPageOf(
                  format.integer(view.currentPage + 1),
                  format.integer(view.pageSizes.length),
                ),
          child: FocusableActionDetector(
            focusNode: _focus,
            autofocus: true,
            onFocusChange: (focused) {
              if (!focused && _launchFocus) {
                setState(() => _launchFocus = false);
              }
            },
            onShowFocusHighlight: (value) => setState(() => _highlight = value),
            child: FocusRing(
              visible: _highlight && !_launchFocus,
              style: FocusRingStyle.inset,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: ColoredBox(
                  color: theme.colors.surfaceCanvas,
                  child: active?.combine ?? false
                      ? Directionality(
                          textDirection: uiDirection,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [const CombineTab(), ?taskDrawer],
                          ),
                        )
                      : active != null &&
                            (active.locked || active.error != null)
                      ? Directionality(
                          textDirection: uiDirection,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: active.locked
                                    ? UnlockTab(
                                        active,
                                        key: ValueKey(active.path),
                                      )
                                    : OpenErrorTab(active),
                              ),
                              ?taskDrawer,
                            ],
                          ),
                        )
                      : opening != null
                      ? Directionality(
                          textDirection: uiDirection,
                          child: Stack(
                            children: [
                              PositionedDirectional(
                                bottom: theme.space.space6,
                                end: theme.space.space6,
                                child: TaskProgress(
                                  icon: IconName.fileText,
                                  title: l10n.openingTitle(
                                    bidiIsolate(active!.name),
                                  ),
                                  indeterminate: true,
                                  onCancel: cancelOpening,
                                  cancelLabel: l10n.openingCancel,
                                ),
                              ),
                              ?taskDrawer,
                            ],
                          ),
                        )
                      : view != null
                      // The find bar follows the UI's direction; the pages
                      // never mirror (ADR 0014).
                      ? Directionality(
                          textDirection: uiDirection,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (active != null)
                                      DocumentBanners(
                                        document: active,
                                        onUnlock: () => setState(
                                          () => _ownerUnlock = view.document.id,
                                        ),
                                      ),
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child:
                                                mode == FermanMode.organize &&
                                                    // a6-4 works on the
                                                    // reader's page.
                                                    !ref.watch(
                                                      cropShowingProvider,
                                                    )
                                                // G32: the grid follows the
                                                // UI's direction, its pages
                                                // never mirror.
                                                ? PageGrid(
                                                    key: ValueKey(
                                                      view.document.id,
                                                    ),
                                                  )
                                                : Directionality(
                                                    textDirection:
                                                        TextDirection.ltr,
                                                    child: DocumentView(
                                                      key: ValueKey(
                                                        view.document.id,
                                                      ),
                                                      uiDirection: uiDirection,
                                                      tools:
                                                          mode ==
                                                          FermanMode.view,
                                                      edit:
                                                          mode ==
                                                          FermanMode.edit,
                                                      comment:
                                                          mode ==
                                                          FermanMode.comment,
                                                    ),
                                                  ),
                                          ),
                                          // a6-4, over the pages' own
                                          // geometry, which never mirrors.
                                          if (ref.watch(cropShowingProvider))
                                            const Positioned.fill(
                                              child: Directionality(
                                                textDirection:
                                                    TextDirection.ltr,
                                                child: CropOverlay(),
                                              ),
                                            ),
                                          // a4-5, at the canvas's top.
                                          if (hiddenComments)
                                            const _HiddenCommentsNotice(),
                                          PositionedDirectional(
                                            top: theme.space.space3,
                                            end: theme.space.space4,
                                            child: const FindBar(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (active != null &&
                                  _properties == view.document.id)
                                DocumentPropertiesDialog(
                                  tab: active,
                                  onClose: () =>
                                      setState(() => _properties = null),
                                  onUnlock: () => setState(() {
                                    _properties = null;
                                    _ownerUnlock = view.document.id;
                                  }),
                                ),
                              if (active != null &&
                                  _ownerUnlock == view.document.id)
                                Positioned.fill(
                                  child: OwnerUnlockDialog(
                                    document: active,
                                    onClose: () =>
                                        setState(() => _ownerUnlock = null),
                                  ),
                                ),
                              ?taskDrawer,
                              const Positioned.fill(child: SaveOverlays()),
                            ],
                          ),
                        )
                      : taskDrawer != null
                      ? Directionality(
                          textDirection: uiDirection,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [taskDrawer],
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// a4-5's notice, at the canvas's top, centred.
class _HiddenCommentsNotice extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: EdgeInsetsDirectional.only(top: context.ferman.space.space3),
      child: const CommentsHiddenNotice(),
    ),
  );
}
