import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/find_bar.dart';
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
/// ↓, Page Up, Page Down, Space, Home and End. Until documents open from
/// the UI (W3), the placeholder documents of the shell show the canvas
/// background and a quiet empty state: a page glyph and "Available in a
/// future version", the reason of [Feature.pageRendering]. It is a
/// focus stop named "Document pages", focused when the shell opens, so the
/// shortcut table's keys work at once. The inset focus ring shows once the
/// keyboard is used there: not for the focus it gets at launch (no board
/// draws a ring around the document area), but after a key press on it or
/// when Tab brings focus back to it. The shortcut
/// table's canvas keys (`ShortcutScope.canvas`: page turns, form fields,
/// the page grid) are bound here. The canvas is never mirrored in right to
/// left: its subtree runs with a left-to-right [Directionality], as pages
/// keep their own geometry (ADR 0014), while the placeholder's copy keeps
/// the UI's direction.
class ShellCanvas extends ConsumerStatefulWidget {
  /// The canvas.
  const new({super.key});

  @override
  ConsumerState<ShellCanvas> createState() => _ShellCanvasState();
}

class _ShellCanvasState extends ConsumerState<ShellCanvas> {
  final FocusNode _focus = FocusNode(debugLabel: 'ShellCanvas');

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
      if (_scroll(event)) return KeyEventResult.handled;
      // The shortcuts above still get the key.
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
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
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    return Shortcuts(
      shortcuts: ShellCommand.shortcutsFor(
        platform,
        mode,
        scope: ShortcutScope.canvas,
      ),
      // The focus stop itself is named, so focusing it reads "Document
      // pages"; the empty state is a node of its own inside it.
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
                child: view != null
                    // The find bar follows the UI's direction; the pages
                    // never mirror (ADR 0014).
                    ? Directionality(
                        textDirection: uiDirection,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: DocumentView(
                                  key: ValueKey(view.document.id),
                                  uiDirection: uiDirection,
                                  tools: mode == FermanMode.view,
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              top: theme.space.space3,
                              end: theme.space.space4,
                              child: const FindBar(),
                            ),
                            if (ref.watch(documentOpenerProvider)
                                case final problem?)
                              PositionedDirectional(
                                bottom: theme.space.space4,
                                end: theme.space.space4,
                                child: SizedBox(
                                  width: Toast.width,
                                  child: OpenProblemToast(problem),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Center(
                        child: Semantics(
                          container: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: theme.space.space2,
                            children: [
                              Icon(
                                IconName.fileText,
                                size: theme.density.iconLg,
                                color: theme.colors.iconSecondary,
                              ),
                              Text(
                                Feature.pageRendering.disabledReason(context),
                                textAlign: TextAlign.center,
                                textDirection: uiDirection,
                                style: theme.typography.caption.copyWith(
                                  color: theme.colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
