import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_problem.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The start screen with no recent files, board a1-5 (right to left
/// a12-2a; building block `FmStart.dc.html` with `empty`).
///
/// Four action cards (Open file…, Create PDF, Combine files, Scan to PDF),
/// the quick tools, and the drop area ([DropZone]) with Open a PDF and New
/// blank PDF. Open file… and Open a PDF show the system open panel
/// (a1-13, ADR 0018); everything else is visible as drawn and disabled
/// with "Available in a future version" until its milestone (G10, G11):
/// creating and combining PDFs and compressing
/// in M4, signing in M4 (simple signatures), protecting in P2, scanning,
/// conversion, text recognition and compare in P3. Each of those controls
/// takes its state from its feature in the feature registry ([Feature]).
/// The copy speaks of PDFs only until conversion exists (G11). A file that
/// did not open shows a danger banner at the top until dismissed (G116).
/// Files dropped anywhere on the window open too (`FileDrop`, a1-6).
///
/// The keys come from the shell's shortcut table: ⌘, (Ctrl+, on Windows
/// and Linux) opens Settings (the a11-1 note) through a
/// [ShellCommandScope] for the start screen, and the cards show the
/// table's ⌘O and ⌘N. The title bar above shows the home header (a1-5),
/// with the Settings button.
///
/// When the engine cannot open PDF files ([engineProblemProvider]: the
/// engine library is missing or speaks another API version, or PDFium did
/// not load), a warning banner heads the page with "Copy technical
/// details", and Open file… and the drop area take the banner's title as
/// their reason (G101). The rest of the app keeps working.
class FmStart extends ConsumerWidget {
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
    final platform = ref.watch(shortcutPlatformProvider);
    final problem = ref.watch(engineProblemProvider);
    final openReason = openFilesDisabledReason(context, ref);
    final onOpen = openFiles(context, ref);
    final failed = ref.watch(documentOpenerProvider);
    // ⌘O and ⌘N have keys on every system.
    final open = ShellCommand.open.caps(platform)!;
    final actions = [
      (
        null,
        IconName.folderOpen,
        l10n.startOpenFile,
        l10n.startOpenFileDescription,
        open,
      ),
      (
        Feature.createPdf,
        IconName.filePlus2,
        l10n.startCreatePdf,
        l10n.startCreatePdfDescription,
        ShellCommand.createPdf.caps(platform),
      ),
      (
        Feature.combineAndSplit,
        IconName.merge,
        l10n.startCombineFiles,
        l10n.startCombineFilesDescription,
        null,
      ),
      (
        Feature.scanToPdf,
        IconName.scan,
        l10n.startScanToPdf,
        l10n.startScanToPdfDescription,
        null,
      ),
    ];
    final tools = [
      (Feature.compress, IconName.minimize2, l10n.startToolCompress),
      (Feature.convertFromPdf, IconName.refreshCw, l10n.startToolConvert),
      (Feature.simpleSignatures, IconName.signature, l10n.startToolSign),
      (Feature.ocr, IconName.scanText, l10n.startToolOcr),
      (Feature.passwordProtection, IconName.shield, l10n.startToolProtect),
      (Feature.compare, IconName.gitCompare, l10n.startToolCompare),
    ];

    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        if (problem != null) _EngineProblemBanner(problem),
        if (failed != null) OpenProblemBanner(failed),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space4,
            children: [
              for (final (feature, icon, title, description, keys) in actions)
                Expanded(
                  child: _ActionCard(
                    icon: icon,
                    title: title,
                    description: description,
                    shortcut: keys,
                    onPressed: feature == null ? onOpen : null,
                    disabledReason: feature == null
                        ? openReason
                        : feature.disabledReason(context),
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
            for (final (feature, icon, label) in tools)
              Button(
                size: ButtonSize.sm,
                icon: icon,
                disabledReason: feature.disabledReason(context),
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
          onOpen: onOpen,
          disabledReason: openReason,
          createDisabledReason: Feature.createPdf.disabledReason(context),
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

/// The warning banner of G101: the box variant at the top of the page, as
/// Settings shows its warning (G90), with "Copy technical details" (G63).
class _EngineProblemBanner extends StatelessWidget {
  const new(this.problem);

  final EngineProblem problem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Banner(
      tone: BannerTone.warning,
      title: l10n.startEngineUnavailableTitle,
      actions: [
        Button(
          size: ButtonSize.sm,
          icon: IconName.copy,
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: problem.technicalDetails)),
          child: Text(l10n.startCopyTechnicalDetails),
        ),
      ],
      child: Text(l10n.startEngineUnavailableMessage),
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
    this.onPressed,
  });

  final IconName icon;
  final String title;
  final String description;
  final List<String>? shortcut;
  final String? disabledReason;
  final VoidCallback? onPressed;

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
    onPressed: onPressed,
    disabled: onPressed == null,
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
