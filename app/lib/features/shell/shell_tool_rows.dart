import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/editor/edit_history_panel.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/review_list.dart';
import 'package:ferman/features/organize/combine.dart';
import 'package:ferman/features/organize/crop_panel.dart';
import 'package:ferman/features/organize/crop_session.dart';
import 'package:ferman/features/organize/extract_pages_dialog.dart';
import 'package:ferman/features/organize/insert_blank_dialog.dart';
import 'package:ferman/features/organize/insert_file_dialog.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/organize/page_labels_dialog.dart';
import 'package:ferman/features/organize/replace_pages_dialog.dart';
import 'package:ferman/features/organize/split_dialog.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/settings/settings_providers.dart';
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
/// disabled with the future-version tooltip (G10), taken from its value in
/// the feature registry ([Feature]); each one's milestone is in
/// docs/BACKLOG.md. The tool each mode starts with (FmWindow `tool`:
/// Select, Edit text, Highlight, Fill fields, Redact) is drawn on.
///
/// **Narrow windows** (G21): every row is a `Toolbar` bar that hides the
/// Organize hint, then its tool labels from the end, then moves items into
/// its "More tools" menu (`ShellLabels.moreTools`). The zoom menu and the
/// segmented controls are listed there as submenus of their choices, the
/// labelled buttons (Review edits, Apply redactions) as items; the items
/// after a row's spacer move last. At the 1024 px minimum every row fits
/// with labels hidden, in English, Turkish, Arabic and German-length text.
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

/// A tool button of [feature], which is not built yet: drawn as designed,
/// disabled with the future-version tooltip.
ToolButton _future(
  BuildContext context, {
  required Feature feature,
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
  disabledReason: feature.disabledReason(context),
);

/// View (FmWindow lines 47–66): Select, Hand, Marquee zoom | zoom out, the
/// zoom menu, zoom in, Fit | Page layout | Split view, Read aloud, Present
/// … Dark reading mode.
///
/// With a document open (`viewerProvider`) the tools, zoom, Fit and Page
/// layout work: the zoom field names a fit while one is on and shows the
/// zoom otherwise (a2-13). Without one (a document still opening, locked or
/// not opened) they stay disabled.
class _ViewTools extends ConsumerWidget {
  const new();

  /// The zoom menu's box: `width: 92px`.
  static const double zoomWidth = 92;

  /// The zoom steps of the menu (FmWindow `zooms`).
  static const List<int> zoomSteps = [50, 75, 100, 125, 150, 200, 400];

  /// The commands of the zoom menu's and the Fit control's choices, by
  /// their values.
  static const Map<String, ShellCommand> fitCommands = {
    'fit-width': ShellCommand.fitWidth,
    'fit-page': ShellCommand.fitPage,
    'width': ShellCommand.fitWidth,
    'page': ShellCommand.fitPage,
    'actual': ShellCommand.actualSize,
  };

  /// The layouts by their values.
  static const Map<String, PageLayout> layouts = {
    'single': PageLayout.single,
    'scroll': PageLayout.continuous,
    'two': PageLayout.twoPage,
    'book': PageLayout.book,
  };

  /// The zoom typed into the zoom field (B127), or null when it is no
  /// number. The region's digits and either decimal sign are read, with or
  /// without a percent sign; `Viewer.zoomTo` holds it to 10 % to 1,600 %.
  static double? typedZoom(String text, Region region) {
    final value = NumberStepper.parse(
      text.replaceAll(RegExp('[%\u066a\uff05\ufe6a]'), ''),
      region,
    );
    return value == null ? null : value / 100;
  }

  /// Applies a choice of the zoom menu or the Fit control.
  static void zoomChoice(Viewer viewer, String value) => switch (value) {
    'fit-width' || 'width' => viewer.fit(ZoomFit.width),
    'fit-page' || 'page' => viewer.fit(ZoomFit.page),
    'actual' => viewer.zoomTo(1),
    'marquee' => viewer.setTool(ViewerTool.marquee),
    _ => viewer.zoomTo((int.tryParse(value) ?? 100) / 100),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final region = ref.watch(regionProvider).region;
    final format = RegionFormat.forRegion(region);
    final view = ref.watch(
      viewerProvider.select(
        (view) => view == null
            ? null
            : (
                tool: view.tool,
                zoom: (view.zoom * 100).round(),
                fit: view.fit,
                layout: view.layout,
              ),
      ),
    );
    final viewer = ref.read(viewerProvider.notifier);
    final live = view != null;
    // The region writes the percentage: "%100" for Türkiye (G34).
    String percent(int value) => bidiIsolate(format.percent(value));
    final zoomValue = switch (view?.fit) {
      ZoomFit.width => 'fit-width',
      ZoomFit.page => 'fit-page',
      null => '${view?.zoom ?? 100}',
    };
    final fitValue = switch (view) {
      (fit: ZoomFit.width, tool: _, zoom: _, layout: _) => 'width',
      (fit: ZoomFit.page, tool: _, zoom: _, layout: _) => 'page',
      (fit: null, zoom: 100, tool: _, layout: _) => 'actual',
      _ => null,
    };
    final layoutValue = switch (view?.layout) {
      PageLayout.single => 'single',
      PageLayout.twoPage => 'two',
      PageLayout.book => 'book',
      _ => 'scroll',
    };
    final zoomOptions = [
      // A zoom of its own (a pinch, a marquee) shows as the field's value.
      if (!zoomValue.startsWith('fit') &&
          !zoomSteps.contains(int.parse(zoomValue)))
        (zoomValue, percent(int.parse(zoomValue)), null),
      for (final step in zoomSteps) ('$step', percent(step), null),
      ('fit-width', l10n.shellFitWidth, null),
      ('fit-page', l10n.shellFitPage, null),
    ];
    // a2-2's menu: the fits with their keys, the steps, Marquee zoom.
    List<MenuItem> zoomMenu() => [
      for (final (value, name, icon) in [
        ('fit-width', l10n.shellFitWidth, IconName.arrowLeftRight),
        ('fit-page', l10n.shellFitPage, IconName.maximize),
        ('actual', l10n.shellActualSize, IconName.scan),
      ])
        MenuItem(
          id: value,
          label: name,
          icon: icon,
          shortcut: fitCommands[value]?.caps(platform),
          checked: value == zoomValue,
        ),
      const MenuItem.divider(),
      for (final step in zoomSteps)
        MenuItem(
          id: '$step',
          label: percent(step),
          checked: '$step' == zoomValue,
        ),
      const MenuItem.divider(),
      MenuItem(
        id: 'marquee',
        label: l10n.shellToolMarqueeZoom,
        icon: IconName.squareDashed,
        shortcut: ShellCommand.marqueeZoom.caps(platform),
      ),
    ];
    // The zoom menu and the segmented controls move into a narrow row's
    // overflow menu as submenus of their choices (G21). A choice that is a
    // command of the shortcut table shows its keys, as the zoom menu (a2-2)
    // draws Fit width ⌘2, Fit page ⌘0 and Actual size ⌘1.
    MenuItem choices(
      String label,
      List<(String, String, IconName?)> options, {
      String? checked,
      Map<String, ShellCommand> commands = const {},
    }) => MenuItem(
      id: label,
      label: label,
      disabled: !live,
      submenu: [
        for (final (value, name, icon) in options)
          MenuItem(
            id: value,
            label: name,
            icon: icon,
            shortcut: commands[value]?.caps(platform),
            checked: value == checked,
          ),
      ],
    );
    ToolButton tool(
      ViewerTool which,
      IconName icon,
      String label,
      ShellCommand command,
    ) => ToolButton(
      icon: icon,
      label: label,
      active: (view?.tool ?? ViewerTool.select) == which,
      shortcut: command.caps(platform),
      disabled: !live,
      onPressed: live ? () => viewer.setTool(which) : null,
    );
    IconButton step(
      IconName icon,
      String label,
      ShellCommand command,
      VoidCallback action,
    ) => IconButton(
      icon: icon,
      label: label,
      shortcut: command.caps(platform),
      disabled: !live,
      onPressed: live ? action : null,
    );
    void chosen(MenuItem item, void Function(String) apply) {
      final id = item.id;
      if (live && id != null) apply(id);
    }

    return Toolbar(
      semanticLabel: l10n.shellViewTools,
      overflowLabel: l10n.moreTools,
      children: [
        tool(
          ViewerTool.select,
          IconName.mousePointer2,
          l10n.shellToolSelect,
          ShellCommand.selectTool,
        ),
        tool(
          ViewerTool.hand,
          IconName.hand,
          l10n.shellToolHand,
          ShellCommand.handTool,
        ),
        ToolButton(
          icon: IconName.squareDashed,
          label: l10n.shellToolMarqueeZoom,
          active: view?.tool == ViewerTool.marquee,
          shortcut: ShellCommand.marqueeZoom.caps(platform),
          disabled: !live,
          onPressed: live ? () => viewer.setTool(ViewerTool.marquee) : null,
        ),
        const ToolbarSeparator(),
        step(
          IconName.zoomOut,
          l10n.shellZoomOut,
          ShellCommand.zoomOut,
          viewer.zoomOut,
        ),
        ToolbarItem(
          menuItem: MenuItem(
            id: l10n.shellZoom,
            label: l10n.shellZoom,
            disabled: !live,
            submenu: zoomMenu(),
          ),
          onMenuSelected: (item) =>
              chosen(item, (value) => zoomChoice(viewer, value)),
          child: SizedBox(
            width: zoomWidth,
            child: Select<String>(
              size: FieldSize.sm,
              semanticLabel: l10n.shellZoom,
              value: zoomValue,
              disabled: !live,
              onChanged: live ? (value) => zoomChoice(viewer, value) : null,
              menu: zoomMenu(),
              onMenuSelected: (item) =>
                  chosen(item, (value) => zoomChoice(viewer, value)),
              onTyped: live
                  ? (text) {
                      final zoom = typedZoom(text, region);
                      if (zoom != null) viewer.zoomTo(zoom);
                    }
                  : null,
              typingHint: l10n.shellZoomTypeHint(
                percent((minZoom * 100).round()),
                percent((maxZoom * 100).round()),
              ),
              options: [
                for (final (value, name, _) in zoomOptions)
                  SelectOption(value: value, label: name),
              ],
            ),
          ),
        ),
        step(
          IconName.zoomIn,
          l10n.shellZoomIn,
          ShellCommand.zoomIn,
          viewer.zoomIn,
        ),
        ToolbarItem(
          menuItem: choices(
            l10n.shellFit,
            [
              ('width', l10n.shellFitWidth, IconName.arrowLeftRight),
              ('page', l10n.shellFitPage, IconName.maximize),
              ('actual', l10n.shellActualSize, IconName.scan),
            ],
            checked: fitValue,
            commands: fitCommands,
          ),
          onMenuSelected: (item) =>
              chosen(item, (value) => zoomChoice(viewer, value)),
          child: SegmentedControl<String?>(
            semanticLabel: l10n.shellFit,
            value: fitValue,
            disabled: !live,
            onChanged: live
                ? (value) {
                    if (value != null) zoomChoice(viewer, value);
                  }
                : null,
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
        ),
        const ToolbarSeparator(),
        ToolbarItem(
          menuItem: choices(l10n.shellPageLayout, [
            ('single', l10n.shellLayoutSingle, IconName.fileText),
            ('scroll', l10n.shellLayoutContinuous, IconName.arrowUpDown),
            ('two', l10n.shellLayoutTwoPage, IconName.columns2),
            ('book', l10n.shellLayoutBook, IconName.bookOpen),
          ], checked: layoutValue),
          onMenuSelected: (item) => chosen(item, (value) {
            final chosen = layouts[value];
            if (chosen != null) viewer.setLayout(chosen);
          }),
          child: SegmentedControl<String>(
            semanticLabel: l10n.shellPageLayout,
            value: layoutValue,
            disabled: !live,
            onChanged: live
                ? (value) {
                    final chosen = layouts[value];
                    if (chosen != null) viewer.setLayout(chosen);
                  }
                : null,
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
        ),
        const ToolbarSeparator(),
        _future(
          context,
          feature: Feature.splitView,
          icon: IconName.columns2,
          label: l10n.shellToolSplitView,
          active: false,
        ),
        _future(
          context,
          feature: Feature.readAloud,
          icon: IconName.volume2,
          label: l10n.shellToolReadAloud,
          active: false,
        ),
        _future(
          context,
          feature: Feature.presentation,
          icon: IconName.presentation,
          label: l10n.shellToolPresent,
          shortcut: ShellCommand.present.caps(platform),
        ),
        const ToolbarSpacer(),
        Switch(
          value: false,
          label: l10n.shellDarkReadingMode,
          disabled: true,
          disabledReason: Feature.darkReadingMode.disabledReason(context),
        ),
      ],
    );
  }
}

/// Edit (FmWindow lines 67–84): Edit text, Add text, Add image, Link |
/// Find & replace, Page marks | undo, redo, Edit history … Mark edited
/// text, Review edits with its count.
///
/// Edit text, the only tool built, is on. Undo and redo work while the
/// history has a step for them (`documentEditorProvider`), and say
/// "Nothing to undo" or "Nothing to redo" otherwise (G126); Edit history
/// shows or hides a3-10's panel in the right panel's place.
class _EditTools extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final edits = ref.watch(shellDocumentsProvider).active?.editCount ?? 0;
    final document = ref.watch(viewerProvider.select((view) => view != null));
    final editor = ref.watch(documentEditorProvider);
    final historyOpen = ref.watch(editHistoryOpenProvider);
    final reviewOpen = ref.watch(reviewListProvider.select((s) => s.open));
    void toggleReview() => reviewOpen
        ? ref.read(reviewListProvider.notifier).show(open: false)
        : showReviewList(ref);
    final forbidden =
        ref
            .watch(shellDocumentsProvider)
            .active
            ?.document
            ?.security
            ?.forbidsEditing ??
        false;
    return Toolbar(
      semanticLabel: l10n.shellEditTools,
      overflowLabel: l10n.moreTools,
      children: [
        // The only tool so far, always on: T has nothing to switch to. The
        // author's permissions can forbid it (a2-10a, G27).
        ToolButton(
          icon: IconName.textCursor,
          label: l10n.shellToolEditText,
          active: true,
          shortcut: ShellCommand.editText.caps(platform),
          disabled: forbidden,
          disabledReason: forbidden ? l10n.shellEditForbidden : null,
          onPressed: forbidden ? null : () {},
        ),
        _future(
          context,
          feature: Feature.addingTextBoxes,
          icon: IconName.type,
          label: l10n.shellToolAddText,
          active: false,
          shortcut: ShellCommand.addText.caps(platform),
        ),
        _future(
          context,
          feature: Feature.addingImages,
          icon: IconName.image,
          label: l10n.shellToolAddImage,
          active: false,
          shortcut: ShellCommand.addImage.caps(platform),
        ),
        _future(
          context,
          feature: Feature.links,
          icon: IconName.link,
          label: l10n.shellToolLink,
          active: false,
          shortcut: ShellCommand.link.caps(platform),
        ),
        const ToolbarSeparator(),
        _future(
          context,
          feature: Feature.findAndReplace,
          icon: IconName.replace,
          label: l10n.shellToolFindReplace,
          active: false,
          shortcut: ShellCommand.findAndReplace.caps(platform),
        ),
        _future(
          context,
          feature: Feature.pageMarks,
          icon: IconName.droplet,
          label: l10n.shellToolPageMarks,
          active: false,
          hasMenu: true,
        ),
        const ToolbarSeparator(),
        // Undo and redo mirror in right to left (FmWindow `data-fm-flip`;
        // `IconName.directional`).
        IconButton(
          icon: IconName.undo2,
          label: l10n.shellUndo,
          shortcut: ShellCommand.undo.caps(platform),
          disabledReason: l10n.editNothingToUndo,
          onPressed: document && editor.canUndo
              ? () =>
                    unawaited(ref.read(documentEditorProvider.notifier).undo())
              : null,
        ),
        IconButton(
          icon: IconName.redo2,
          label: l10n.shellRedo,
          shortcut: ShellCommand.redo.caps(platform),
          disabledReason: l10n.editNothingToRedo,
          onPressed: document && editor.canRedo
              ? () =>
                    unawaited(ref.read(documentEditorProvider.notifier).redo())
              : null,
        ),
        IconButton(
          icon: IconName.history,
          label: l10n.shellEditHistory,
          active: historyOpen,
          onPressed: () => toggleEditHistory(ref),
        ),
        const ToolbarSpacer(),
        Switch(
          value: ref.watch(settingsProvider.select((s) => s.markEdited)),
          label: l10n.shellMarkEditedText,
          onChanged: (value) => unawaited(
            changeSetting(
              ref,
              (current) => current.copyWith(markEdited: value),
            ),
          ),
        ),
        ToolbarItem(
          // The count the row's badge shows stays in the menu entry; the
          // region writes the number (G34).
          menuItem: MenuItem(
            id: 'review-edits',
            label: l10n.shellReviewEditsCount(
              bidiIsolate(format.integer(edits)),
            ),
            icon: IconName.listChecks,
          ),
          onMenuSelected: (_) => toggleReview(),
          // `<div style="width:8px">` and the toolbar's 2 px gap after it,
          // part of the item so it leaves the row with the button.
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: theme.space.space2 + theme.space.space0_5,
            ),
            child: Button(
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              icon: IconName.listChecks,
              onPressed: toggleReview,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space1_5,
                children: [
                  Text(l10n.shellReviewEdits),
                  Badge(label: format.integer(edits), tone: BadgeTone.edited),
                ],
              ),
            ),
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
    final comments = Feature.comments.disabledReason(context);
    return Row(
      children: [
        Expanded(
          child: AnnotationTools(
            semanticLabel: l10n.shellCommentTools,
            toolLabelOf: l10n.annotationToolLabel,
            colorsSemanticLabel: l10n.shellColor,
            colorLabelOf: l10n.annotationColorLabel,
            showLabels: true,
            // Measure is a measure tool of its own (B051), the others are
            // comments (B050).
            disabledReasons: {
              for (final tool in AnnotationTool.values)
                tool: tool == AnnotationTool.measure
                    ? Feature.measure.disabledReason(context)
                    : comments,
            },
            colorsDisabledReason: comments,
            overflowLabel: l10n.moreTools,
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
            disabledReason: comments,
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
      overflowLabel: l10n.moreTools,
      children: [
        _future(
          context,
          feature: Feature.formFilling,
          icon: IconName.textCursorInput,
          label: l10n.shellToolFillFields,
          active: true,
        ),
        _future(
          context,
          feature: Feature.formFilling,
          icon: IconName.type,
          label: l10n.shellToolAddText,
          active: false,
        ),
        _future(
          context,
          feature: Feature.formFilling,
          icon: IconName.squareCheck,
          label: l10n.shellToolCheckmark,
          active: false,
        ),
        _future(
          context,
          feature: Feature.formFilling,
          icon: IconName.calendar,
          label: l10n.shellToolDate,
          active: false,
        ),
        const ToolbarSeparator(),
        _future(
          context,
          feature: Feature.simpleSignatures,
          icon: IconName.signature,
          label: l10n.shellToolSign,
          active: false,
          hasMenu: true,
        ),
        _future(
          context,
          feature: Feature.simpleSignatures,
          icon: IconName.penLine,
          label: l10n.shellToolInitials,
          active: false,
        ),
        _future(
          context,
          feature: Feature.certificateSignatures,
          icon: IconName.badgeCheck,
          label: l10n.shellToolDigitalSignature,
          active: false,
        ),
        _future(
          context,
          feature: Feature.eImza,
          icon: IconName.usb,
          label: l10n.shellToolEimza,
          active: false,
        ),
        const ToolbarSeparator(),
        _future(
          context,
          feature: Feature.preparingForms,
          icon: IconName.squarePen,
          label: l10n.shellToolPrepareForm,
          active: false,
        ),
        const ToolbarSpacer(),
      ],
    );
  }
}

/// a6-1's Insert menu: Blank page, Pages from a file and, disabled until it
/// ships, the scanner.
List<MenuItem> _insertItems(BuildContext context, AppLocalizations l10n) => [
  MenuItem(id: 'blank', label: l10n.insertMenuBlank, icon: IconName.filePlus2),
  MenuItem(id: 'file', label: l10n.insertMenuFile, icon: IconName.folderOpen),
  MenuItem(
    id: 'scan',
    label: l10n.insertMenuScan,
    icon: IconName.scan,
    disabled: true,
    disabledReason: Feature.scanToPdf.disabledReason(context),
  ),
];

/// Does what Insert's menu entry [item] says.
void _insertChosen(WidgetRef ref, MenuItem item) {
  final document = ref.read(viewerProvider)?.document;
  if (document == null) return;
  final pages = organizeSelection(ref);
  switch (item.id) {
    case 'blank':
      showInsertBlankDialog(ref, document, pages);
    case 'file':
      showInsertFileDialog(ref, document, pages);
  }
}

/// a6-1's Insert button with its menu.
class _InsertTool extends ConsumerStatefulWidget {
  const new({required this.live});

  /// Whether the document can change.
  final bool live;

  @override
  ConsumerState<_InsertTool> createState() => _InsertToolState();
}

class _InsertToolState extends ConsumerState<_InsertTool> {
  bool _open = false;

  void _close() => setState(() => _open = false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Popover(
      open: _open,
      surface: false,
      onDismiss: _close,
      anchor: ToolButton(
        icon: IconName.filePlus2,
        label: l10n.shellToolInsert,
        hasMenu: true,
        disabled: !widget.live,
        onPressed: widget.live ? () => setState(() => _open = !_open) : null,
      ),
      child: Menu(
        items: _insertItems(context, l10n),
        autofocus: true,
        onClose: _close,
        onSelected: (item) {
          _close();
          _insertChosen(ref, item);
        },
      ),
    );
  }
}

/// Organize (FmWindow lines 105–122): Insert, rotate left and right
/// (icon-only), Duplicate, Extract, Replace, Delete | Split, Combine files,
/// Crop, Page labels … the hint, which counts the selection (a6-1) and the
/// pages a drag moves (a6-1b). The commands act on the selection.
class _OrganizeTools extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final selected = ref.watch(selectedPagesProvider).length;
    final total = ref.watch(openDocumentProvider)?.pages.length ?? 0;
    final moving = ref.watch(pagesDraggedProvider);
    PageCommands commands() => ref.read(pageCommandsProvider.notifier);
    final refusal = ref.watch(organizeRefusalProvider)?.call(l10n);
    final reason = refusal ?? (selected == 0 ? l10n.organizeSelectFirst : null);
    final deleteRefusal = ref.watch(deleteRefusalProvider)?.call(l10n);
    final document = ref.watch(viewerProvider.select((view) => view?.document));
    final name = ref.watch(shellDocumentsProvider).active?.name ?? '';
    // Extract only reads; the others change the document.
    final changes = document != null && refusal == null;
    final crop = ref.watch(cropShowingProvider);
    final live = ref.watch(viewerProvider.select((view) => view != null));
    final combineTab = ref.watch(
      shellDocumentsProvider.select((list) => list.active?.combine ?? false),
    );
    return Toolbar(
      semanticLabel: l10n.shellOrganizeTools,
      overflowLabel: l10n.moreTools,
      children: [
        ToolbarItem(
          menuItem: MenuItem(
            id: l10n.shellToolInsert,
            label: l10n.shellToolInsert,
            icon: IconName.filePlus2,
            disabled: !changes,
            submenu: _insertItems(context, l10n),
          ),
          onMenuSelected: (item) => _insertChosen(ref, item),
          child: _InsertTool(live: changes),
        ),
        ToolButton(
          icon: IconName.rotateCcw,
          label: l10n.shellToolRotateLeft,
          showLabel: false,
          shortcut: ShellCommand.rotateLeft.caps(platform),
          disabled: reason != null,
          disabledReason: reason,
          onPressed: reason != null
              ? null
              : () => unawaited(commands().rotate(-1)),
        ),
        ToolButton(
          icon: IconName.rotateCw,
          label: l10n.shellToolRotateRight,
          showLabel: false,
          shortcut: ShellCommand.rotateRight.caps(platform),
          disabled: reason != null,
          disabledReason: reason,
          onPressed: reason != null
              ? null
              : () => unawaited(commands().rotate(1)),
        ),
        ToolButton(
          icon: IconName.copy,
          label: l10n.shellToolDuplicate,
          disabled: reason != null,
          disabledReason: reason,
          onPressed: reason != null
              ? null
              : () => unawaited(commands().duplicate()),
        ),
        ToolButton(
          icon: IconName.fileOutput,
          label: l10n.shellToolExtract,
          disabled: document == null,
          onPressed: document == null
              ? null
              : () => showExtractPagesDialog(
                  ref,
                  document,
                  name,
                  organizeSelection(ref),
                ),
        ),
        ToolButton(
          icon: IconName.replace,
          label: l10n.shellToolReplace,
          disabled: !changes,
          onPressed: changes
              ? () => showReplacePagesDialog(
                  ref,
                  document,
                  organizeSelection(ref),
                )
              : null,
        ),
        ToolButton(
          icon: IconName.trash2,
          label: l10n.shellToolDelete,
          shortcut: ShellCommand.deletePages.caps(platform),
          disabled: reason != null || deleteRefusal != null,
          disabledReason: reason ?? deleteRefusal,
          onPressed: reason != null || deleteRefusal != null
              ? null
              : () => unawaited(commands().delete()),
        ),
        const ToolbarSeparator(),
        ToolButton(
          icon: IconName.split,
          label: l10n.shellToolSplit,
          active: false,
          disabled: !live,
          onPressed: live
              ? () => ref
                    .read(organizeDialogProvider.notifier)
                    .show(const SplitDialog())
              : null,
        ),
        ToolButton(
          icon: IconName.merge,
          label: l10n.shellToolCombineFiles,
          active: combineTab,
          onPressed: () => ref
              .read(combineFilesProvider.notifier)
              .showTab(l10n.shellToolCombineFiles),
        ),
        ToolButton(
          icon: IconName.crop,
          label: l10n.shellToolCrop,
          active: crop,
          disabled: !changes,
          onPressed: changes
              ? () => crop
                    ? ref.read(organizeCropProvider.notifier).cancel()
                    : showCropTool(ref, document, organizeSelection(ref))
              : null,
        ),
        ToolButton(
          icon: IconName.hash,
          label: l10n.shellToolPageLabels,
          active: false,
          disabled: !changes,
          onPressed: changes ? () => showPageLabelsDialog(ref, document) : null,
        ),
        const ToolbarSpacer(),
        Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.space.space2,
          ),
          child: Text(
            switch ((moving, selected)) {
              (final count?, _) => l10n.organizeHintMoving(
                count,
                format.integer(count),
              ),
              (null, 0) => l10n.shellOrganizeHint,
              (null, final count) => l10n.organizeHintSelected(
                total,
                format.integer(count),
                format.integer(total),
              ),
            },
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
class _ConvertTools extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ToolButton tool(Feature feature, IconName icon, String label) => _future(
      context,
      feature: feature,
      icon: icon,
      label: label,
      active: false,
    );
    return Toolbar(
      semanticLabel: l10n.shellConvertTools,
      overflowLabel: l10n.moreTools,
      children: [
        tool(Feature.convertFromPdf, IconName.fileType, l10n.shellConvertWord),
        tool(
          Feature.convertFromPdf,
          IconName.fileSpreadsheet,
          l10n.shellConvertExcel,
        ),
        tool(
          Feature.convertFromPdf,
          IconName.presentation,
          l10n.shellConvertPowerPoint,
        ),
        tool(
          Feature.convertFromPdf,
          IconName.fileImage,
          l10n.shellConvertImage,
        ),
        tool(Feature.convertFromPdf, IconName.code, l10n.shellConvertHtml),
        tool(Feature.convertFromPdf, IconName.fileText, l10n.shellConvertText),
        tool(Feature.convertFromPdf, IconName.hash, l10n.shellConvertMarkdown),
        const ToolbarSeparator(),
        ToolButton(
          icon: IconName.fileInput,
          label: l10n.shellToolCreatePdf,
          active: false,
          onPressed: () => ref
              .read(organizeDialogProvider.notifier)
              .show(const CreatePdfDialog()),
        ),
        tool(Feature.scanToPdf, IconName.scan, l10n.shellToolScan),
        tool(Feature.ocr, IconName.scanText, l10n.shellToolRecognizeText),
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
      overflowLabel: l10n.moreTools,
      children: [
        _future(
          context,
          feature: Feature.redaction,
          icon: IconName.eyeOff,
          label: l10n.shellToolRedact,
          active: true,
          shortcut: ShellCommand.redact.caps(platform),
        ),
        _future(
          context,
          feature: Feature.redaction,
          icon: IconName.fileSearch,
          label: l10n.shellToolFindRedact,
          active: false,
        ),
        const ToolbarSeparator(),
        _future(
          context,
          feature: Feature.passwordProtection,
          icon: IconName.keyRound,
          label: l10n.shellToolPassword,
          active: false,
        ),
        _future(
          context,
          feature: Feature.removeHiddenInformation,
          icon: IconName.eraser,
          label: l10n.shellToolRemoveHidden,
          active: false,
        ),
        _future(
          context,
          feature: Feature.securityReport,
          icon: IconName.shieldCheck,
          label: l10n.shellToolSecurityReport,
          active: false,
        ),
        const ToolbarSpacer(),
        ToolbarItem(
          menuItem: MenuItem(
            id: 'apply-redactions',
            label: l10n.shellApplyRedactions,
            icon: IconName.eyeOff,
            danger: true,
            disabled: true,
            disabledReason: Feature.redaction.disabledReason(context),
          ),
          child: Button(
            variant: ButtonVariant.danger,
            size: ButtonSize.sm,
            icon: IconName.eyeOff,
            disabledReason: Feature.redaction.disabledReason(context),
            child: Text(l10n.shellApplyRedactions),
          ),
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
    ToolButton tool(
      Feature feature,
      IconName icon,
      String label, {
      List<String>? shortcut,
    }) => _future(
      context,
      feature: feature,
      icon: icon,
      label: label,
      active: false,
      shortcut: shortcut,
    );
    return Toolbar(
      semanticLabel: l10n.shellModeTools,
      overflowLabel: l10n.moreTools,
      children: [
        tool(Feature.compress, IconName.minimize2, l10n.shellToolCompress),
        tool(Feature.compare, IconName.gitCompare, l10n.shellToolCompare),
        tool(
          Feature.accessibilityTools,
          IconName.accessibility,
          l10n.shellToolAccessibility,
        ),
        tool(Feature.pdfAAndPreflight, IconName.fileCheck2, l10n.shellToolPdfA),
        tool(Feature.batchActions, IconName.workflow, l10n.shellToolBatch),
        tool(
          Feature.printing,
          IconName.printer,
          l10n.shellToolPrint,
          shortcut: ShellCommand.printDocument.caps(platform),
        ),
        tool(Feature.measure, IconName.ruler, l10n.shellToolMeasure),
        tool(
          Feature.versionHistory,
          IconName.history,
          l10n.shellToolVersionHistory,
        ),
        const ToolbarSeparator(),
        tool(Feature.aiAssistant, IconName.sparkles, l10n.shellAiAssistant),
      ],
    );
  }
}
