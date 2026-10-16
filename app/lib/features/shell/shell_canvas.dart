import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The document canvas between the sidebar and the panel (FmWindow's
/// `<main>` on `--surface-canvas`).
///
/// No PDF renders in M1, so it shows the canvas background and a quiet
/// empty state: a page glyph and "Available in a future version". It is a
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
    _focus.onKeyEvent = (_, _) {
      if (_launchFocus) setState(() => _launchFocus = false);
      // The shortcuts above still get the key.
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
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
                child: Center(
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
                          futureVersionReason(context),
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
