import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/settings/general_pane.dart';
import 'package:ferman/features/settings/language_region_pane.dart';
import 'package:ferman/features/settings/privacy_pane.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings, board a11-1 (`11a Settings.dc.html`, building block
/// `FmSettings.dc.html`; Windows a11-1w, right to left a12-2c).
///
/// a11-1 draws Settings as its own window; M1 has no second window
/// (ARCHITECTURE.md §12), so Settings is a window-styled surface in the
/// main window: the route `/settings` (`/settings/<pane>`), pushed over the
/// screen it was opened from, under the main window's bare title bar, with
/// the pane list at the start (240 px on `--surface-panel`) and the pane on
/// `--surface-raised`. Changes apply at once; there is no Save button
/// (a11-1 note).
///
/// Because the caption buttons close the whole app here, the surface has
/// its own close button at its top end ("Close settings"), and Esc and ⌘W
/// (Ctrl+W on Windows and Linux, the shortcut table's
/// `ShellCommand.closeDocument`) close it too, back to the screen below.
///
/// Built panes: General, Language and region, Privacy (a skeleton). The
/// others are listed and disabled with "Available in a future version"
/// (G10), as is the settings search ("Search filters every pane").
///
/// Tab goes through the pane list first (the search, then the panes), then
/// through the pane, each column as one group in reading order. When a
/// change cannot be stored, a warning Banner at the top of the pane says
/// that it lasts only until Ferman closes (`settingsSaveFailedProvider`).
class FmSettings extends ConsumerStatefulWidget {
  /// Settings on [initialPane].
  const new({super.key, this.initialPane = SettingsPane.general});

  /// The pane shown first.
  final SettingsPane initialPane;

  /// The pane list's width (`width: 240px`).
  static const double navWidth = 240;

  /// The pane list's padding (`padding: 14px 10px`): vertical …
  static const double navPaddingY = 14;

  /// … and horizontal.
  static const double navPaddingX = 10;

  /// A list row's least height (`min-height: 32px`).
  static const double navRowHeight = 32;

  /// The pane's largest width (`max-width: 760px`).
  static const double paneMaxWidth = 760;

  /// The pane's padding (`padding: 28px 40px 40px`): top …
  static const double panePaddingTop = 28;

  /// … sides and bottom.
  static const double panePaddingX = 40;

  /// The gap between the heading and the pane (`gap: 22px`).
  static const double paneGap = 22;

  /// Closes Settings: back to the screen below, or to the start screen
  /// when Settings was opened directly.
  static void close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.start);
    }
  }

  @override
  ConsumerState<FmSettings> createState() => _FmSettingsState();
}

class _FmSettingsState extends ConsumerState<FmSettings> {
  late SettingsPane _pane = widget.initialPane;

  @override
  void didUpdateWidget(FmSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPane != widget.initialPane) {
      _pane = widget.initialPane;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final saveFailed = ref.watch(settingsSaveFailedProvider);
    void close() => FmSettings.close(context);

    final nav = Container(
      width: FmSettings.navWidth,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: FmSettings.navPaddingX,
        vertical: FmSettings.navPaddingY,
      ),
      decoration: BoxDecoration(
        color: colors.surfacePanel,
        border: BorderDirectional(
          end: BorderSide(
            color: colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Semantics(
          container: true,
          label: l10n.settingsTitle,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space0_5,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  theme.space.space2_5,
                  theme.space.space1,
                  theme.space.space2_5,
                  theme.space.space3,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.settingsTitle,
                    style: theme.typography.headline,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  theme.space.space1,
                  0,
                  theme.space.space1,
                  theme.space.space2_5,
                ),
                child: TextField(
                  size: FieldSize.sm,
                  icon: IconName.search,
                  placeholder: l10n.settingsSearch,
                  semanticLabel: l10n.settingsSearch,
                  disabled: true,
                  disabledReason: futureVersionReason(context),
                ),
              ),
              for (final pane in SettingsPane.values)
                _NavRow(
                  pane: pane,
                  selected: pane == _pane,
                  onPressed: () => setState(() => _pane = pane),
                ),
            ],
          ),
        ),
      ),
    );

    final body = switch (_pane) {
      SettingsPane.language => const LanguageRegionPane(),
      SettingsPane.privacy => const PrivacyPane(),
      _ => const GeneralPane(),
    };

    final main = ColoredBox(
      color: colors.surfaceRaised,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: FmSettings.paneMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      FmSettings.panePaddingX,
                      FmSettings.panePaddingTop,
                      FmSettings.panePaddingX,
                      FmSettings.panePaddingX,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: FmSettings.paneGap,
                      children: [
                        if (saveFailed)
                          Banner(
                            tone: BannerTone.warning,
                            title: l10n.settingsSaveFailedTitle,
                            dismissLabel: l10n.settingsSaveFailedDismiss,
                            onDismiss: ref
                                .read(settingsSaveFailedProvider.notifier)
                                .dismiss,
                            child: Text(l10n.settingsSaveFailedMessage),
                          ),
                        Semantics(
                          header: true,
                          child: Text(
                            _pane.label(l10n),
                            style: theme.typography.headline,
                          ),
                        ),
                        KeyedSubtree(key: ValueKey(_pane), child: body),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: theme.space.space3,
            end: theme.space.space3,
            child: IconButton(
              icon: IconName.x,
              label: l10n.settingsClose,
              shortcut: const ['Esc'],
              onPressed: close,
            ),
          ),
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): close,
        for (final binding in ShellCommand.closeDocument.bindingsFor(platform))
          binding.activator: close,
      },
      child: FocusTraversalGroup(
        child: Focus(
          autofocus: true,
          // Holds focus when Settings opens, so Esc works at once, but is no
          // Tab stop of its own.
          skipTraversal: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // One group per column, so Tab finishes the pane list before
              // the pane instead of zigzagging between rows that share a
              // band.
              FocusTraversalGroup(child: nav),
              Expanded(child: FocusTraversalGroup(child: main)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of the pane list: the pane's icon and name; the current pane on
/// `--surface-selected` in the accent text colour (`aria-current="page"`),
/// a pane not built yet disabled with "Available in a future version".
class _NavRow extends StatelessWidget {
  const new({
    required this.pane,
    required this.selected,
    required this.onPressed,
  });

  final SettingsPane pane;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FermanInteractive(
      onPressed: pane.available ? onPressed : null,
      disabledReason: pane.available ? null : futureVersionReason(context),
      selected: selected,
      semanticLabel: pane.label(l10n),
      builder: (context, states, _) {
        final theme = context.ferman;
        final colors = theme.colors;
        final disabled = states.contains(WidgetState.disabled);
        final foreground = disabled
            ? colors.textDisabled
            : selected
            ? colors.textAccent
            : colors.textPrimary;
        final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));
        return FocusRing(
          visible: states.contains(WidgetState.focused),
          style: FocusRingStyle.inset,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: FmSettings.navRowHeight,
            ),
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.space.space2_5,
              vertical: theme.space.space1,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colors.surfaceSelected
                  : states.contains(WidgetState.hovered)
                  ? colors.surfaceHover
                  : null,
              borderRadius: radius,
            ),
            child: Row(
              spacing: theme.space.space2_5,
              children: [
                Icon(pane.icon, color: foreground),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      pane.label(l10n),
                      style: theme.typography.body.copyWith(color: foreground),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
