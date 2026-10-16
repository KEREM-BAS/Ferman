import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tool row under the mode bar: one row per mode exactly as FmWindow
/// draws it (lines 46–164), in an [IndexedStack] so each mode keeps its
/// state while another mode shows (ADR 0011).
///
/// FmWindow puts the rows in a box with its own subtle bottom line under
/// the Toolbar's, so the boards draw a 2 px line and a 45 px row; the row
/// is built the same way.
///
/// No tool works without a document, so every tool is visible as drawn and
/// disabled with the future-version tooltip (G10); each one's milestone is
/// in docs/BACKLOG.md. The tool each mode starts with (FmWindow `tool`:
/// Select, Edit text, Highlight, Fill fields, Redact) is drawn on.
class ShellToolRows extends ConsumerWidget {
  /// The tool rows.
  const new({super.key});

  /// The key of [mode]'s row, for tests.
  static ValueKey<String> keyOf(FermanMode mode) =>
      ValueKey('shell-tools-${mode.id}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final mode = ref.watch(shellModeProvider);
    // A Container, so its line sits under the row instead of over it.
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surfacePanel,
        border: Border(
          bottom: BorderSide(
            color: theme.colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: IndexedStack(
        index: mode.index,
        children: [
          for (final each in FermanMode.values)
            KeyedSubtree(
              key: keyOf(each),
              child: switch (each) {
                FermanMode.view => const _ViewTools(),
                FermanMode.edit => const _EditTools(),
                FermanMode.comment => const _CommentTools(),
                FermanMode.sign => const _SignTools(),
                FermanMode.organize => const _OrganizeTools(),
                FermanMode.convert => const _ConvertTools(),
                FermanMode.protect => const _ProtectTools(),
                FermanMode.tools => const _ToolsTools(),
              },
            ),
        ],
      ),
    );
  }
}

/// A tool button whose feature is not built yet: drawn as designed,
/// disabled with the future-version tooltip.
ToolButton _future(
  BuildContext context, {
  required IconName icon,
  required String label,
  bool? active,
  bool hasMenu = false,
  bool showLabel = true,
  List<String>? shortcut,
}) => ToolButton(
  icon: icon,
  label: label,
  active: active,
  hasMenu: hasMenu,
  showLabel: showLabel,
  shortcut: shortcut,
  disabled: true,
  disabledReason: futureVersionReason(context),
);

/// An icon button whose feature is not built yet.
IconButton _futureIcon(
  BuildContext context, {
  required IconName icon,
  required String label,
  bool? active,
  List<String>? shortcut,
}) => IconButton(
  icon: icon,
  label: label,
  active: active,
  shortcut: shortcut,
  disabled: true,
  disabledReason: futureVersionReason(context),
);

/// View (FmWindow lines 47–66): Select, Hand, Marquee zoom | zoom out, the
/// zoom menu, zoom in, Fit | Page layout | Split view, Read aloud, Present
/// … Dark reading mode.
class _ViewTools extends ConsumerWidget {
  const new();

  /// The zoom menu's box: `width: 92px`.
  static const double zoomWidth = 92;

  /// The zoom steps of the menu (FmWindow `zooms`).
  static const List<int> zoomSteps = [50, 75, 100, 125, 150, 200, 400];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final future = futureVersionReason(context);
    // The region writes the percentage: "%100" for Türkiye (G34).
    String percent(int value) => bidiIsolate(format.percent(value));
    return Toolbar(
      semanticLabel: l10n.shellViewTools,
      children: [
        _future(
          context,
          icon: IconName.mousePointer2,
          label: l10n.shellToolSelect,
          active: true,
          shortcut: ShellCommand.selectTool.caps(platform),
        ),
        _future(
          context,
          icon: IconName.hand,
          label: l10n.shellToolHand,
          active: false,
          shortcut: ShellCommand.handTool.caps(platform),
        ),
        _future(
          context,
          icon: IconName.squareDashed,
          label: l10n.shellToolMarqueeZoom,
          active: false,
          shortcut: ShellCommand.marqueeZoom.caps(platform),
        ),
        const ToolbarSeparator(),
        _futureIcon(
          context,
          icon: IconName.zoomOut,
          label: l10n.shellZoomOut,
          shortcut: ShellCommand.zoomOut.caps(platform),
        ),
        SizedBox(
          width: zoomWidth,
          child: Select<String>(
            size: FieldSize.sm,
            semanticLabel: l10n.shellZoom,
            value: '100',
            disabled: true,
            disabledReason: future,
            options: [
              for (final step in zoomSteps)
                SelectOption(value: '$step', label: percent(step)),
              SelectOption(value: 'fit-width', label: l10n.shellFitWidth),
              SelectOption(value: 'fit-page', label: l10n.shellFitPage),
            ],
          ),
        ),
        _futureIcon(
          context,
          icon: IconName.zoomIn,
          label: l10n.shellZoomIn,
          shortcut: ShellCommand.zoomIn.caps(platform),
        ),
        SegmentedControl<String?>(
          semanticLabel: l10n.shellFit,
          value: null,
          disabled: true,
          disabledReason: future,
          options: [
            SegmentOption(
              value: 'width',
              icon: IconName.arrowLeftRight,
              tooltip: l10n.shellFitWidth,
            ),
            SegmentOption(
              value: 'page',
              icon: IconName.maximize,
              tooltip: l10n.shellFitPage,
            ),
            SegmentOption(
              value: 'actual',
              icon: IconName.scan,
              tooltip: l10n.shellActualSize,
            ),
          ],
        ),
        const ToolbarSeparator(),
        SegmentedControl<String>(
          semanticLabel: l10n.shellPageLayout,
          value: 'scroll',
          disabled: true,
          disabledReason: future,
          options: [
            SegmentOption(
              value: 'single',
              icon: IconName.fileText,
              tooltip: l10n.shellLayoutSingle,
            ),
            SegmentOption(
              value: 'scroll',
              icon: IconName.arrowUpDown,
              tooltip: l10n.shellLayoutContinuous,
            ),
            SegmentOption(
              value: 'two',
              icon: IconName.columns2,
              tooltip: l10n.shellLayoutTwoPage,
            ),
            SegmentOption(
              value: 'book',
              icon: IconName.bookOpen,
              tooltip: l10n.shellLayoutBook,
            ),
          ],
        ),
        const ToolbarSeparator(),
        _future(
          context,
          icon: IconName.columns2,
          label: l10n.shellToolSplitView,
          active: false,
        ),
        _future(
          context,
          icon: IconName.volume2,
          label: l10n.shellToolReadAloud,
          active: false,
        ),
        _future(
          context,
          icon: IconName.presentation,
          label: l10n.shellToolPresent,
          shortcut: ShellCommand.present.caps(platform),
        ),
        const ToolbarSpacer(),
        Switch(
          value: false,
          label: l10n.shellDarkReadingMode,
          disabled: true,
          disabledReason: future,
        ),
      ],
    );
  }
}

/// Edit (FmWindow lines 67–84): Edit text, Add text, Add image, Link |
/// Find & replace, Page marks | undo, redo, Edit history … Mark edited
/// text, Review edits with its count.
class _EditTools extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final edits = ref.watch(shellDocumentsProvider).active?.editCount ?? 0;
    final future = futureVersionReason(context);
    return Toolbar(
      semanticLabel: l10n.shellEditTools,
      children: [
        _future(
          context,
          icon: IconName.textCursor,
          label: l10n.shellToolEditText,
          active: true,
          shortcut: ShellCommand.editText.caps(platform),
        ),
        _future(
          context,
          icon: IconName.type,
          label: l10n.shellToolAddText,
          active: false,
          shortcut: ShellCommand.addText.caps(platform),
        ),
        _future(
          context,
          icon: IconName.image,
          label: l10n.shellToolAddImage,
          active: false,
          shortcut: ShellCommand.addImage.caps(platform),
        ),
        _future(
          context,
          icon: IconName.link,
          label: l10n.shellToolLink,
          active: false,
          shortcut: ShellCommand.link.caps(platform),
        ),
        const ToolbarSeparator(),
        _future(
          context,
          icon: IconName.replace,
          label: l10n.shellToolFindReplace,
          active: false,
          shortcut: ShellCommand.findAndReplace.caps(platform),
        ),
        _future(
          context,
          icon: IconName.droplet,
          label: l10n.shellToolPageMarks,
          active: false,
          hasMenu: true,
        ),
        const ToolbarSeparator(),
        // Undo and redo mirror in right to left (FmWindow `data-fm-flip`;
        // `IconName.directional`).
        _futureIcon(
          context,
          icon: IconName.undo2,
          label: l10n.shellUndo,
          shortcut: ShellCommand.undo.caps(platform),
        ),
        _futureIcon(
          context,
          icon: IconName.redo2,
          label: l10n.shellRedo,
          shortcut: ShellCommand.redo.caps(platform),
        ),
        _futureIcon(
          context,
          icon: IconName.history,
          label: l10n.shellEditHistory,
          active: false,
        ),
        const ToolbarSpacer(),
        Switch(
          value: true,
          label: l10n.shellMarkEditedText,
          disabled: true,
          disabledReason: future,
        ),
        // `<div style="width:8px">`, between the toolbar's 2 px gaps.
        SizedBox(width: theme.space.space2),
        Button(
          variant: ButtonVariant.ghost,
          size: ButtonSize.sm,
          icon: IconName.listChecks,
          disabledReason: future,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: theme.space.space1_5,
            children: [
              Text(l10n.shellReviewEdits),
              Badge(label: format.integer(edits), tone: BadgeTone.edited),
            ],
          ),
        ),
      ],
    );
  }
}

/// Comment (FmWindow lines 85–87): the AnnotationTools row with labels,
/// Highlight on in yellow, and the Show comments switch after it.
class _CommentTools extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final future = futureVersionReason(context);
    return Row(
      children: [
        Expanded(
          child: AnnotationTools(
            semanticLabel: l10n.shellCommentTools,
            toolLabelOf: l10n.annotationToolLabel,
            colorsSemanticLabel: l10n.shellColor,
            colorLabelOf: l10n.annotationColorLabel,
            showLabels: true,
            disabledReasons: {
              for (final tool in AnnotationTool.values) tool: future,
            },
            colorsDisabledReason: future,
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: theme.space.space2,
            end: theme.space.space2_5,
          ),
          child: Switch(
            value: true,
            label: l10n.shellShowComments,
            disabled: true,
            disabledReason: future,
          ),
        ),
      ],
    );
  }
}

/// Fill & Sign (FmWindow lines 88–104): Fill fields, Add text, Checkmark,
/// Date | Sign, Initials, Digital signature, e-imza | Prepare form. The
/// field navigation after the spacer shows only on a form, so not in M1.
class _SignTools extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Toolbar(
      semanticLabel: l10n.shellFillSignTools,
      children: [
        _future(
          context,
          icon: IconName.textCursorInput,
          label: l10n.shellToolFillFields,
          active: true,
        ),
        _future(
          context,
          icon: IconName.type,
          label: l10n.shellToolAddText,
          active: false,
        ),
        _future(
          context,
          icon: IconName.squareCheck,
          label: l10n.shellToolCheckmark,
          active: false,
        ),
        _future(
          context,
          icon: IconName.calendar,
          label: l10n.shellToolDate,
          active: false,
        ),
        const ToolbarSeparator(),
        _future(
          context,
          icon: IconName.signature,
          label: l10n.shellToolSign,
          active: false,
          hasMenu: true,
        ),
        _future(
          context,
          icon: IconName.penLine,
          label: l10n.shellToolInitials,
          active: false,
        ),
        _future(
          context,
          icon: IconName.badgeCheck,
          label: l10n.shellToolDigitalSignature,
          active: false,
        ),
        _future(
          context,
          icon: IconName.usb,
          label: l10n.shellToolEimza,
          active: false,
        ),
        const ToolbarSeparator(),
        _future(
          context,
          icon: IconName.squarePen,
          label: l10n.shellToolPrepareForm,
          active: false,
        ),
        const ToolbarSpacer(),
      ],
    );
  }
}

/// Organize (FmWindow lines 105–122): Insert, rotate left and right
/// (icon-only), Duplicate, Extract, Replace, Delete | Split, Combine files,
/// Crop, Page labels … the drag hint.
class _OrganizeTools extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    return Toolbar(
      semanticLabel: l10n.shellOrganizeTools,
      children: [
        _future(
          context,
          icon: IconName.filePlus2,
          label: l10n.shellToolInsert,
          hasMenu: true,
        ),
        _future(
          context,
          icon: IconName.rotateCcw,
          label: l10n.shellToolRotateLeft,
          showLabel: false,
          shortcut: ShellCommand.rotateLeft.caps(platform),
        ),
        _future(
          context,
          icon: IconName.rotateCw,
          label: l10n.shellToolRotateRight,
          showLabel: false,
          shortcut: ShellCommand.rotateRight.caps(platform),
        ),
        _future(
          context,
          icon: IconName.copy,
          label: l10n.shellToolDuplicate,
          shortcut: ShellCommand.duplicatePages.caps(platform),
        ),
        _future(
          context,
          icon: IconName.fileOutput,
          label: l10n.shellToolExtract,
          shortcut: ShellCommand.extractPages.caps(platform),
        ),
        _future(context, icon: IconName.replace, label: l10n.shellToolReplace),
        _future(
          context,
          icon: IconName.trash2,
          label: l10n.shellToolDelete,
          shortcut: ShellCommand.deletePages.caps(platform),
        ),
        const ToolbarSeparator(),
        _future(
          context,
          icon: IconName.split,
          label: l10n.shellToolSplit,
          active: false,
        ),
        _future(
          context,
          icon: IconName.merge,
          label: l10n.shellToolCombineFiles,
          active: false,
        ),
        _future(
          context,
          icon: IconName.crop,
          label: l10n.shellToolCrop,
          active: false,
        ),
        _future(
          context,
          icon: IconName.hash,
          label: l10n.shellToolPageLabels,
          active: false,
        ),
        const ToolbarSpacer(),
        Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.space.space2,
          ),
          child: Text(
            l10n.shellOrganizeHint,
            maxLines: 1,
            softWrap: false,
            style: theme.typography.caption.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Convert (FmWindow lines 123–137): Word, Excel, PowerPoint, Image, HTML,
/// Text, Markdown | Create PDF, Scan, Recognize text (OCR).
class _ConvertTools extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ToolButton tool(IconName icon, String label) =>
        _future(context, icon: icon, label: label, active: false);
    return Toolbar(
      semanticLabel: l10n.shellConvertTools,
      children: [
        tool(IconName.fileType, l10n.shellConvertWord),
        tool(IconName.fileSpreadsheet, l10n.shellConvertExcel),
        tool(IconName.presentation, l10n.shellConvertPowerPoint),
        tool(IconName.fileImage, l10n.shellConvertImage),
        tool(IconName.code, l10n.shellConvertHtml),
        tool(IconName.fileText, l10n.shellConvertText),
        tool(IconName.hash, l10n.shellConvertMarkdown),
        const ToolbarSeparator(),
        tool(IconName.fileInput, l10n.shellToolCreatePdf),
        tool(IconName.scan, l10n.shellToolScan),
        tool(IconName.scanText, l10n.shellToolRecognizeText),
      ],
    );
  }
}

/// Protect (FmWindow lines 138–149): Redact, Find & redact | Password,
/// Remove hidden information, Security report … Apply redactions.
class _ProtectTools extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    return Toolbar(
      semanticLabel: l10n.shellProtectTools,
      children: [
        _future(
          context,
          icon: IconName.eyeOff,
          label: l10n.shellToolRedact,
          active: true,
          shortcut: ShellCommand.redact.caps(platform),
        ),
        _future(
          context,
          icon: IconName.fileSearch,
          label: l10n.shellToolFindRedact,
          active: false,
          shortcut: ShellCommand.findAndRedact.caps(platform),
        ),
        const ToolbarSeparator(),
        _future(
          context,
          icon: IconName.keyRound,
          label: l10n.shellToolPassword,
          active: false,
        ),
        _future(
          context,
          icon: IconName.eraser,
          label: l10n.shellToolRemoveHidden,
          active: false,
        ),
        _future(
          context,
          icon: IconName.shieldCheck,
          label: l10n.shellToolSecurityReport,
          active: false,
        ),
        const ToolbarSpacer(),
        Button(
          variant: ButtonVariant.danger,
          size: ButtonSize.sm,
          icon: IconName.eyeOff,
          disabledReason: futureVersionReason(context),
          child: Text(l10n.shellApplyRedactions),
        ),
      ],
    );
  }
}

/// Tools (FmWindow lines 150–163): Compress, Compare, Accessibility, PDF/A
/// & preflight, Batch actions, Print, Measure, Version history | AI
/// assistant.
class _ToolsTools extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    ToolButton tool(IconName icon, String label, {List<String>? shortcut}) =>
        _future(
          context,
          icon: icon,
          label: label,
          active: false,
          shortcut: shortcut,
        );
    return Toolbar(
      semanticLabel: l10n.shellModeTools,
      children: [
        tool(IconName.minimize2, l10n.shellToolCompress),
        tool(IconName.gitCompare, l10n.shellToolCompare),
        tool(IconName.accessibility, l10n.shellToolAccessibility),
        tool(IconName.fileCheck2, l10n.shellToolPdfA),
        tool(IconName.workflow, l10n.shellToolBatch),
        tool(
          IconName.printer,
          l10n.shellToolPrint,
          shortcut: ShellCommand.printDocument.caps(platform),
        ),
        tool(IconName.ruler, l10n.shellToolMeasure),
        tool(IconName.history, l10n.shellToolVersionHistory),
        const ToolbarSeparator(),
        tool(IconName.sparkles, l10n.shellAiAssistant),
      ],
    );
  }
}
