import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The start screen with no recent files, board a1-5 (right to left
/// a12-2a; building block `FmStart.dc.html` with `empty`).
///
/// Four action cards (Open file…, Create PDF, Combine files, Scan to PDF),
/// the quick tools, and the drop area ([DropZone]) with Open a PDF and New
/// blank PDF. Everything is visible as drawn and disabled with "Available
/// in a future version" until its milestone (G10, G11): opening files and
/// dropping them in M2 (no file picker in M1, ADR 0018, Q07), creating and
/// combining PDFs and compressing in M4, signing in M4 (simple
/// signatures), protecting in P2, scanning, conversion, text recognition
/// and compare in P3. The copy speaks of PDFs only until conversion exists
/// (G11).
///
/// The keys come from the shell's shortcut table: ⌘, (Ctrl+, on Windows
/// and Linux) opens Settings (the a11-1 note) through a
/// [ShellCommandScope] for the start screen, and the cards show the
/// table's ⌘O and ⌘N. The title bar above shows the home header (a1-5),
/// with the Settings button.
class StartScreen extends ConsumerWidget {
  /// Creates the start screen.
  const new({super.key});

  /// The page's padding (`padding: 36px 64px 40px`): top …
  static const double paddingTop = 36;

  /// … sides …
  static const double paddingX = 64;

  /// … and bottom.
  static const double paddingBottom = 40;

  /// The page's largest width (`max-width: 1312px`).
  static const double maxWidth = 1312;

  /// The gap between the parts (`gap: 28px`).
  static const double gap = 28;

  /// The drop area's least height (`min-height={470}`).
  static const double dropMinHeight = 470;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final reason = futureVersionReason(context);
    final platform = ref.watch(shortcutPlatformProvider);
    // ⌘O and ⌘N have keys on every system.
    final open = ShellCommand.open.caps(platform)!;
    final actions = [
      (
        IconName.folderOpen,
        l10n.startOpenFile,
        l10n.startOpenFileDescription,
        open,
      ),
      (
        IconName.filePlus2,
        l10n.startCreatePdf,
        l10n.startCreatePdfDescription,
        ShellCommand.createPdf.caps(platform),
      ),
      (
        IconName.merge,
        l10n.startCombineFiles,
        l10n.startCombineFilesDescription,
        null,
      ),
      (
        IconName.scan,
        l10n.startScanToPdf,
        l10n.startScanToPdfDescription,
        null,
      ),
    ];
    final tools = [
      (IconName.minimize2, l10n.startToolCompress),
      (IconName.refreshCw, l10n.startToolConvert),
      (IconName.signature, l10n.startToolSign),
      (IconName.scanText, l10n.startToolOcr),
      (IconName.shield, l10n.startToolProtect),
      (IconName.gitCompare, l10n.startToolCompare),
    ];

    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space4,
            children: [
              for (final (icon, title, description, keys) in actions)
                Expanded(
                  child: _ActionCard(
                    icon: icon,
                    title: title,
                    description: description,
                    shortcut: keys,
                    disabledReason: reason,
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: theme.space.space1_5,
          runSpacing: theme.space.space1_5,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(end: theme.space.space2),
              child: Text(
                l10n.startQuickTools,
                style: theme.typography.label.copyWith(
                  color: theme.colors.textTertiary,
                  letterSpacing:
                      theme.typeScale.trackingLabel * theme.typeScale.sizeXs,
                ),
              ),
            ),
            for (final (icon, label) in tools)
              Button(
                size: ButtonSize.sm,
                icon: icon,
                disabledReason: reason,
                child: Text(label),
              ),
          ],
        ),
        DropZone(
          title: l10n.startDropTitle,
          subtitle: l10n.startDropSubtitle,
          openLabel: l10n.startOpenPdf,
          createLabel: l10n.startNewBlankPdf,
          shortcut: open,
          footnote: l10n.startDropFootnote,
          minHeight: dropMinHeight,
          disabledReason: reason,
        ),
      ],
    );

    return ShellCommandScope(
      home: true,
      onOpenSettings: () => context.push(Routes.settings),
      child: Focus(
        autofocus: true,
        child: SingleChildScrollView(
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  paddingX,
                  paddingTop,
                  paddingX,
                  paddingBottom,
                ),
                child: page,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An action card of the start screen (FmStart `actions`): a 36 px icon
/// tile on the accent-subtle fill, the title with its shortcut, and a line
/// of description, on a raised card.
///
/// Disabled with [disabledReason] (G10): the tile, title and description
/// take the disabled colours and the card keeps its frame; it stays
/// focusable and shows the reason as tooltip and semantics hint.
class _ActionCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.description,
    required this.shortcut,
    required this.disabledReason,
  });

  final IconName icon;
  final String title;
  final String description;
  final List<String>? shortcut;
  final String disabledReason;

  /// The card's padding (`padding: 16px`) is `--space-4`; the gap between
  /// the tile and the text (`gap: 14px`).
  static const double gap = 14;

  /// The icon tile (`width: 36px; height: 36px`).
  static const double tileSize = 36;

  /// The icon in the tile (`size={20}`).
  static const double iconSize = 20;

  /// The gap between the title and the description (`gap: 3px`).
  static const double textGap = 3;

  /// The title's size (`font: 600 14px/20px`).
  static const double titleSize = 14;

  @override
  Widget build(BuildContext context) => FermanInteractive(
    disabledReason: disabledReason,
    semanticLabel: '$title. $description',
    builder: (context, states, _) {
      final theme = context.ferman;
      final colors = theme.colors;
      final disabled = states.contains(WidgetState.disabled);
      final hovered = states.contains(WidgetState.hovered);
      final radius = BorderRadius.all(Radius.circular(theme.radius.radiusMd));
      final keys = shortcut;
      return FocusRing(
        visible: states.contains(WidgetState.focused),
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(theme.space.space4),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            border: Border.all(
              color: hovered && !disabled
                  ? colors.borderStrong
                  : colors.borderSubtle,
              width: theme.border.borderWidth,
            ),
            borderRadius: radius,
            boxShadow: theme.elevation.shadowSm,
          ),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: gap,
              children: [
                Container(
                  width: tileSize,
                  height: tileSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: disabled
                        ? colors.surfaceSunken
                        : colors.accentSubtle,
                    borderRadius: BorderRadius.all(
                      Radius.circular(theme.radius.radiusSm),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: disabled ? colors.iconDisabled : colors.textAccent,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: textGap,
                    children: [
                      Wrap(
                        spacing: theme.space.space2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: theme.typography.prose.copyWith(
                              fontSize: titleSize,
                              fontWeight: theme.typeScale.weightSemibold,
                              color: disabled
                                  ? colors.textDisabled
                                  : colors.textPrimary,
                            ),
                          ),
                          if (keys != null)
                            Kbd(keys, semanticLabel: keys.join(' ')),
                        ],
                      ),
                      Text(
                        description,
                        style: theme.typography.caption.copyWith(
                          color: disabled
                              ? colors.textDisabled
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
