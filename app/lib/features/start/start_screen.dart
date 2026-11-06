import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/engine/engine_problem.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/features/phone/fm_phone.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/start/default_app_prompt.dart';
import 'package:ferman/features/start/recent_files_view.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The start screen: with no recent files board a1-5 (right to left
/// a12-2a; building block `FmStart.dc.html` with `empty`), with some the M2
/// build of a1-4 (a1-4-m2; a1-4b and a1-4c in its grid and list), where
/// [RecentFilesView] takes the drop area's place.
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
///
/// Under [WindowMetrics.phoneMaxWidth] it is the phone's home instead
/// (a13-2c, a13-2e; G129).
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
    if (WindowMetrics.isPhone(context)) return const _PhoneHome();
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final problem = ref.watch(engineProblemProvider);
    final openReason = openFilesDisabledReason(context, ref);
    final onOpen = openFiles(context, ref);
    final failed = ref.watch(documentOpenerProvider);
    final hasRecent = ref.watch(recentFilesProvider).isNotEmpty;
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
        if (hasRecent)
          const RecentFilesView()
        else
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

    final scope = ShellCommandScope(
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
    // a1-3 shows over the window, from wherever it sits.
    return Stack(
      fit: StackFit.expand,
      children: [scope, const DefaultAppPrompt()],
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
    final copy = Button(
      size: ButtonSize.sm,
      icon: IconName.copy,
      onPressed: () =>
          Clipboard.setData(ClipboardData(text: problem.technicalDetails)),
      child: Text(l10n.startCopyTechnicalDetails),
    );
    final message = Text(l10n.startEngineUnavailableMessage);
    // A phone has no room for the button beside the text.
    final phone = WindowMetrics.isPhone(context);
    return Banner(
      tone: BannerTone.warning,
      title: l10n.startEngineUnavailableTitle,
      actions: phone ? const [] : [copy],
      child: phone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: context.ferman.space.space2,
              children: [message, copy],
            )
          : message,
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

/// The phone's home (FmMHome in FmPhone; G129): the search field, eight quick
/// tools, then the pinned and recent files or the empty state, and the places
/// to open from. Only opening a file and the files themselves can work, and
/// only with an engine: the web build's stub keeps them in their
/// future-version state, and everything else names its feature.
class _PhoneHome extends ConsumerWidget {
  const new();

  /// The gap between the parts (`gap: 18px`).
  static const double gap = 18;

  /// The tools in a row (`repeat(4, 1fr)`).
  static const int toolColumns = 4;

  /// The gap between the tools' rows (`gap: 10px 8px`) …
  static const double toolRowGap = 10;

  /// … and between the tools in a row.
  static const double toolGap = 8;

  /// "Open from"'s size and line height (`font: 600 13px/16px`).
  static const double openFromSize = 13;

  /// "Open from"'s line height.
  static const double openFromHeight = 16 / 13;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final problem = ref.watch(engineProblemProvider);
    final failed = ref.watch(documentOpenerProvider);
    final hasRecent = ref.watch(recentFilesProvider).isNotEmpty;
    final tools = [
      (Feature.scanToPdf, IconName.scan, l10n.phoneTabScan),
      (Feature.simpleSignatures, IconName.signature, l10n.startToolSign),
      (Feature.phoneEditing, IconName.filePenLine, l10n.shellModeEdit),
      (Feature.convertFromPdf, IconName.refreshCw, l10n.startToolConvert),
      (Feature.compress, IconName.minimize2, l10n.startToolCompress),
      (Feature.combineAndSplit, IconName.merge, l10n.startPhoneToolCombine),
      (Feature.passwordProtection, IconName.shield, l10n.startToolProtect),
      (Feature.ocr, IconName.scanText, l10n.startPhoneToolOcr),
    ];
    final sources = [
      (IconName.download, l10n.startPhoneSourceDownloads),
      (IconName.hardDrive, l10n.startPhoneSourceGoogleDrive),
      (IconName.cloud, l10n.startPhoneSourceOneDrive),
      (IconName.folder, l10n.phoneTabFiles),
    ];
    final searchReason = Feature.phoneSearch.disabledReason(context);
    final moreReason = Feature.phoneMoreMenus.disabledReason(context);
    final openFromReason = Feature.phoneOpenFrom.disabledReason(context);

    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        if (problem != null) _EngineProblemBanner(problem),
        if (failed != null) OpenProblemBanner(failed),
        TextField(
          icon: IconName.search,
          placeholder: l10n.startPhoneSearch,
          semanticLabel: l10n.startPhoneSearch,
          disabled: true,
          disabledReason: searchReason,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: toolRowGap,
          children: [
            for (var start = 0; start < tools.length; start += toolColumns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: toolGap,
                children: [
                  for (final (feature, icon, label) in tools.sublist(
                    start,
                    start + toolColumns,
                  ))
                    Expanded(
                      child: _PhoneTool(
                        icon: icon,
                        label: label,
                        disabledReason: feature.disabledReason(context),
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (hasRecent) const RecentFilesView() else const _PhoneEmpty(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space2,
          children: [
            Text(
              LocaleCasing.of(context).upper(l10n.startPhoneOpenFrom),
              style: theme.typography.label.copyWith(
                fontSize: openFromSize,
                height: openFromHeight,
                color: theme.colors.textTertiary,
              ),
            ),
            Wrap(
              spacing: theme.space.space2,
              runSpacing: theme.space.space2,
              children: [
                for (final (icon, label) in sources)
                  Button(
                    size: ButtonSize.sm,
                    icon: icon,
                    disabled: true,
                    disabledReason: openFromReason,
                    child: Text(label),
                  ),
              ],
            ),
          ],
        ),
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        FmPhone(
          title: l10n.appName,
          tab: PhoneTab.home,
          actions: [
            IconButton(
              icon: IconName.search,
              label: l10n.shellSearch,
              size: IconButtonSize.lg,
              disabled: true,
              disabledReason: searchReason,
            ),
            IconButton(
              icon: IconName.ellipsis,
              label: l10n.shellMore,
              size: IconButtonSize.lg,
              disabled: true,
              disabledReason: moreReason,
            ),
          ],
          child: ShellCommandScope(
            home: true,
            onOpenSettings: () => context.push(Routes.settings),
            child: Focus(
              autofocus: true,
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  theme.space.space4,
                  theme.space.space1,
                  theme.space.space4,
                  // The last row can scroll clear of the FAB.
                  theme.space.space4 +
                      (hasRecent
                          ? _PhoneOpenFab.size + _PhoneOpenFab.margin
                          : 0),
                ),
                child: page,
              ),
            ),
          ),
        ),
        if (hasRecent)
          const PositionedDirectional(
            end: _PhoneOpenFab.margin,
            bottom: FmPhone.navBarHeight + _PhoneOpenFab.margin,
            child: _PhoneOpenFab(),
          ),
        const DefaultAppPrompt(),
      ],
    );
  }
}

/// a13-2c's FAB, for the home with files: Open a file, in the disabled colours
/// while it cannot open anything. The empty home has the same action as a
/// button (a13-2e), so it draws none.
class _PhoneOpenFab extends ConsumerWidget {
  const new();

  /// The side (`width: 56px`).
  static const double size = 56;

  /// The margin to the end and to the navigation bar (`inset-inline-end:
  /// 16px`, `bottom: 96px` over the 80 px bar).
  static const double margin = 16;

  /// The icon (`size="{{ 24 }}"`).
  static const double iconSize = 24;

  /// The icon's stroke (`stroke-width="{{ 2 }}"`).
  static const double iconStroke = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FermanInteractive(
    onPressed: openFiles(context, ref),
    disabledReason: openFilesDisabledReason(context, ref),
    semanticLabel: AppLocalizations.of(context).startPhoneOpen,
    builder: (context, states, _) {
      final theme = context.ferman;
      final colors = theme.colors;
      final disabled = states.contains(WidgetState.disabled);
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled ? colors.surfaceSunken : colors.accent,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusXl),
          ),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: Icon(
          IconName.plus,
          size: iconSize,
          strokeWidth: iconStroke,
          color: disabled ? colors.iconDisabled : colors.textOnAccent,
        ),
      );
    },
  );
}

/// A quick tool of the phone's home (FmMHome `tools`): an icon on a raised
/// tile with its name under it, in the disabled colours until it works.
class _PhoneTool extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.disabledReason,
  });

  /// The tile (`width: 56px; height: 52px`).
  static const double tileWidth = 56;

  /// The tile's height.
  static const double tileHeight = 52;

  /// The icon on it (`size={24}`).
  static const double iconSize = 24;

  /// The gap between the tile and the name (`gap: 6px`).
  static const double nameGap = 6;

  /// The name's size (`font: 500 12px/14px`).
  static const double nameSize = 12;

  /// The name's line height.
  static const double nameHeight = 14 / 12;

  final IconName icon;
  final String label;
  final String disabledReason;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    return FermanInteractive(
      disabled: true,
      disabledReason: disabledReason,
      semanticLabel: label,
      builder: (context, states, _) => ExcludeSemantics(
        child: Column(
          spacing: nameGap,
          children: [
            Container(
              width: tileWidth,
              height: tileHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                border: Border.all(
                  color: colors.borderSubtle,
                  width: theme.border.borderWidth,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusLg),
                ),
              ),
              child: Icon(icon, size: iconSize, color: colors.iconDisabled),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.typography.caption.copyWith(
                fontSize: nameSize,
                height: nameHeight,
                fontWeight: theme.typeScale.weightMedium,
                color: colors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phone's home with no files yet (a13-2e): a file on a sunken tile, the
/// words, and the two first actions, Open a file and Scan a document.
class _PhoneEmpty extends ConsumerWidget {
  const new();

  /// The padding (`padding: 28px 12px 8px`): top …
  static const double paddingTop = 28;

  /// … sides …
  static const double paddingX = 12;

  /// … and bottom.
  static const double paddingBottom = 8;

  /// The gap between the parts (`gap: 10px`).
  static const double gap = 10;

  /// The tile (`56px`).
  static const double tileSize = 56;

  /// The icon on it (`size={28}`).
  static const double iconSize = 28;

  /// The title's size (`font: 600 19px/24px`).
  static const double titleSize = 19;

  /// The title's line height.
  static const double titleHeight = 24 / 19;

  /// The text's size (`font: 400 15px/21px`).
  static const double textSize = 15;

  /// The text's line height.
  static const double textHeight = 21 / 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        paddingX,
        paddingTop,
        paddingX,
        paddingBottom,
      ),
      child: Column(
        spacing: gap,
        children: [
          Container(
            width: tileSize,
            height: tileSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.all(
                Radius.circular(theme.radius.radiusLg),
              ),
            ),
            child: Icon(
              IconName.fileText,
              size: iconSize,
              color: colors.iconSecondary,
            ),
          ),
          Text(
            l10n.startPhoneEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.typography.bodyStrong.copyWith(
              fontSize: titleSize,
              height: titleHeight,
              fontWeight: theme.typeScale.weightSemibold,
              color: colors.textPrimary,
            ),
          ),
          Text(
            l10n.startPhoneEmptySubtitle,
            textAlign: TextAlign.center,
            style: theme.typography.body.copyWith(
              fontSize: textSize,
              height: textHeight,
              color: colors.textSecondary,
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(top: theme.space.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                Button(
                  variant: ButtonVariant.primary,
                  size: ButtonSize.lg,
                  icon: IconName.folderOpen,
                  fullWidth: true,
                  onPressed: openFiles(context, ref),
                  disabledReason: openFilesDisabledReason(context, ref),
                  child: Text(l10n.startPhoneOpen),
                ),
                Button(
                  size: ButtonSize.lg,
                  icon: IconName.scan,
                  fullWidth: true,
                  disabled: true,
                  disabledReason: Feature.scanToPdf.disabledReason(context),
                  child: Text(l10n.startPhoneScan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
