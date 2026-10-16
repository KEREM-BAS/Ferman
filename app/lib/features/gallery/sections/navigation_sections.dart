import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// `ModeTabs`: both variants, with and without icons, in each state.
Widget modeTabsSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  Widget tabs(
    ModeTabsVariant variant, {
    bool showIcons = false,
    FermanMode initial = FermanMode.view,
  }) => GalleryValue<FermanMode>(
    initial: initial,
    builder: (context, value, set) => ModeTabs(
      value: value,
      onChanged: set,
      variant: variant,
      showIcons: showIcons,
      labelOf: l10n.modeLabel,
      semanticLabel: l10n.shellModeLabel,
    ),
  );
  return GalleryBody(
    children: [
      for (final variant in ModeTabsVariant.values)
        GalleryRow(
          label: GalleryLabels.named(GalleryLabels.variant, variant.name),
          children: [
            GallerySpecimen(
              excludeSemantics: true,
              label: GalleryLabels.standard,
              child: tabs(variant),
            ),
            GallerySpecimen(
              excludeSemantics: true,
              label: GalleryLabels.both(
                GalleryLabels.selected,
                SpecName.showIcons.name,
              ),
              child: tabs(variant, showIcons: true, initial: FermanMode.edit),
            ),
            GallerySpecimen(
              excludeSemantics: true,
              label: GalleryLabels.hover,
              forced: GalleryForced.hover,
              child: tabs(variant),
            ),
            GallerySpecimen(
              excludeSemantics: true,
              label: GalleryLabels.focusVisible,
              forced: GalleryForced.focusVisible,
              child: tabs(variant),
            ),
          ],
        ),
    ],
  );
}

/// `FERMAN_MODES`, the `FermanMode` enum: each mode's id, icon and label.
Widget fermanModesSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  return _enumRow(theme, [
    for (final mode in FermanMode.values)
      (mode.id, mode.icon, l10n.modeLabel(mode), const <Widget>[]),
  ]);
}

/// `ANNOTATION_TOOLS`, the `AnnotationTool` enum: each tool's id, icon,
/// label, key and flags.
Widget annotationToolsEnumSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  return _enumRow(theme, [
    for (final tool in AnnotationTool.values)
      (
        tool.id,
        tool.icon,
        l10n.annotationToolLabel(tool),
        [
          if (tool.shortcut case final key?) Kbd([key]),
          if (tool.colored) const Badge(label: GallerySamples.colored),
          if (tool.hasMenu) const Badge(label: GallerySamples.hasMenu),
        ],
      ),
  ]);
}

/// The values of an enum component: id, icon, label and extras.
Widget _enumRow(
  FermanTheme theme,
  List<(String, IconName, String, List<Widget>)> values,
) => Wrap(
  spacing: theme.space.space5,
  runSpacing: theme.space.space4,
  children: [
    for (final (id, icon, label, extras) in values)
      GallerySpecimen(
        label: id,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.space.space2,
          children: [Icon(icon), Text(label), ...extras],
        ),
      ),
  ],
);

/// `SegmentedControl`: text, icon-only, full width and disabled.
Widget segmentedControlSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  final future = futureVersionReason(context);
  final sidebar = [
    SegmentOption(value: 0, label: l10n.shellSidebarPages),
    SegmentOption(value: 1, label: l10n.shellSidebarOutline),
  ];
  const alignment = [
    SegmentOption(
      value: 0,
      icon: IconName.alignLeft,
      tooltip: GallerySamples.alignLeft,
    ),
    SegmentOption(
      value: 1,
      icon: IconName.alignCenter,
      tooltip: GallerySamples.alignCenter,
    ),
    SegmentOption(
      value: 2,
      icon: IconName.alignRight,
      tooltip: GallerySamples.alignRight,
    ),
    SegmentOption(
      value: 3,
      icon: IconName.alignJustify,
      tooltip: GallerySamples.justify,
    ),
  ];
  Widget control(
    List<SegmentOption<int>> options,
    String label, {
    bool fullWidth = false,
    bool disabled = false,
    String? disabledReason,
  }) => GalleryValue<int>(
    initial: 0,
    builder: (context, value, set) => SegmentedControl<int>(
      options: options,
      value: value,
      onChanged: set,
      semanticLabel: label,
      fullWidth: fullWidth,
      disabled: disabled,
      disabledReason: disabledReason,
    ),
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(
            label: GalleryLabels.standard,
            child: control(sidebar, l10n.shellSidebar),
          ),
          GallerySpecimen(
            label: SpecName.iconOnly.name,
            child: control(alignment, GallerySamples.alignment),
          ),
          GallerySpecimen(
            label: SpecName.fullWidth.name,
            width: theme.size.panelW,
            child: control(sidebar, l10n.shellSidebar, fullWidth: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: control(sidebar, l10n.shellSidebar),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabled,
            child: control(sidebar, l10n.shellSidebar, disabled: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabledWithReason,
            child: control(
              sidebar,
              l10n.shellSidebar,
              disabled: true,
              disabledReason: future,
            ),
          ),
        ],
      ),
    ],
  );
}

/// The View tools of the tool row, from the shell's copy.
List<Widget> _viewTools(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final env = GalleryEnvironment.of(context);
  final future = futureVersionReason(context);
  return [
    ToolButton(
      icon: IconName.mousePointer2,
      label: l10n.shellToolSelect,
      showLabel: false,
      active: true,
      shortcut: env.caps(ShellCommand.selectTool),
      onPressed: () {},
    ),
    ToolButton(
      icon: IconName.hand,
      label: l10n.shellToolHand,
      showLabel: false,
      active: false,
      shortcut: env.caps(ShellCommand.handTool),
      onPressed: () {},
    ),
    const ToolbarSeparator(),
    IconButton(
      icon: IconName.zoomOut,
      label: l10n.shellZoomOut,
      shortcut: env.caps(ShellCommand.zoomOut),
      onPressed: () {},
    ),
    IconButton(
      icon: IconName.zoomIn,
      label: l10n.shellZoomIn,
      shortcut: env.caps(ShellCommand.zoomIn),
      onPressed: () {},
    ),
    const ToolbarSeparator(),
    IconButton(
      icon: IconName.undo2,
      label: l10n.shellUndo,
      shortcut: env.caps(ShellCommand.undo),
      onPressed: () {},
    ),
    IconButton(
      icon: IconName.redo2,
      label: l10n.shellRedo,
      disabled: true,
      disabledReason: future,
    ),
  ];
}

/// `Toolbar`: the bar and the floating variant.
Widget toolbarSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  return GalleryRow(
    label: GalleryLabels.variant,
    children: [
      GallerySpecimen(
        label: ToolbarVariant.bar.name,
        width: theme.size.dialogWMd,
        child: Toolbar(
          semanticLabel: l10n.shellViewTools,
          children: [
            ..._viewTools(context),
            const ToolbarSpacer(),
            Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.sm,
              icon: IconName.save,
              onPressed: () {},
              child: Text(l10n.shellSave),
            ),
          ],
        ),
      ),
      GallerySpecimen(
        label: ToolbarVariant.floating.name,
        child: Toolbar(
          variant: ToolbarVariant.floating,
          semanticLabel: l10n.shellViewTools,
          children: _viewTools(context),
        ),
      ),
    ],
  );
}

/// `ToolbarSeparator`: the line between groups.
Widget toolbarSeparatorSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return GallerySpecimen(
    label: GalleryLabels.standard,
    child: Toolbar(
      variant: ToolbarVariant.floating,
      semanticLabel: l10n.shellEditTools,
      children: [
        IconButton(
          icon: IconName.undo2,
          label: l10n.shellUndo,
          onPressed: () {},
        ),
        const ToolbarSeparator(),
        IconButton(
          icon: IconName.redo2,
          label: l10n.shellRedo,
          onPressed: () {},
        ),
      ],
    ),
  );
}

/// `ToolbarSpacer`: pushes the items after it to the end.
Widget toolbarSpacerSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  return GallerySpecimen(
    label: GalleryLabels.standard,
    width: theme.size.dialogWSm,
    child: Toolbar(
      semanticLabel: l10n.shellEditTools,
      children: [
        IconButton(
          icon: IconName.undo2,
          label: l10n.shellUndo,
          onPressed: () {},
        ),
        const ToolbarSpacer(),
        Button(
          variant: ButtonVariant.primary,
          size: ButtonSize.sm,
          onPressed: () {},
          child: Text(l10n.shellSave),
        ),
      ],
    ),
  );
}

/// `ToolbarGroup`: a labelled group of tools.
Widget toolbarGroupSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return GallerySpecimen(
    label: GalleryLabels.standard,
    child: Toolbar(
      variant: ToolbarVariant.floating,
      semanticLabel: l10n.shellEditTools,
      children: [
        ToolbarGroup(
          semanticLabel: GallerySamples.textStyle,
          children: [
            IconButton(
              icon: IconName.bold,
              label: GallerySamples.bold,
              active: true,
              onPressed: () {},
            ),
            IconButton(
              icon: IconName.italic,
              label: GallerySamples.italic,
              active: false,
              onPressed: () {},
            ),
            IconButton(
              icon: IconName.underline,
              label: l10n.shellAnnotationUnderline,
              active: false,
              onPressed: () {},
            ),
          ],
        ),
        const ToolbarSeparator(),
        ToolbarGroup(
          semanticLabel: GallerySamples.alignment,
          children: [
            IconButton(
              icon: IconName.alignLeft,
              label: GallerySamples.alignLeft,
              onPressed: () {},
            ),
            IconButton(
              icon: IconName.alignCenter,
              label: GallerySamples.alignCenter,
              onPressed: () {},
            ),
          ],
        ),
      ],
    ),
  );
}

/// `ToolButton`: each state, both layouts, with a menu and a swatch.
Widget toolButtonSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  final env = GalleryEnvironment.of(context);
  final future = futureVersionReason(context);
  Widget tool({
    ToolButtonLayout layout = ToolButtonLayout.inline,
    bool? active,
    bool showLabel = true,
    bool hasMenu = false,
    Color? swatch,
    bool disabled = false,
    String? disabledReason,
  }) => ToolButton(
    icon: hasMenu || swatch != null
        ? IconName.highlighter
        : IconName.textCursorInput,
    label: hasMenu || swatch != null
        ? l10n.shellAnnotationHighlight
        : l10n.shellToolEditText,
    layout: layout,
    active: active,
    showLabel: showLabel,
    hasMenu: hasMenu,
    swatch: swatch,
    shortcut: env.caps(
      hasMenu || swatch != null
          ? ShellCommand.highlight
          : ShellCommand.editText,
    ),
    disabled: disabled,
    disabledReason: disabledReason,
    onPressed: () {},
    onMenuRequested: hasMenu ? () {} : null,
  );
  return GalleryBody(
    children: [
      for (final layout in ToolButtonLayout.values)
        GalleryRow(
          label: GalleryLabels.named(SpecName.layout.name, layout.name),
          children: [
            GallerySpecimen(
              label: GalleryLabels.standard,
              child: tool(layout: layout),
            ),
            GallerySpecimen(
              label: GalleryLabels.hover,
              forced: GalleryForced.hover,
              child: tool(layout: layout),
            ),
            GallerySpecimen(
              label: GalleryLabels.pressed,
              forced: GalleryForced.pressed,
              child: tool(layout: layout),
            ),
            GallerySpecimen(
              label: GalleryLabels.focusVisible,
              forced: GalleryForced.focusVisible,
              child: tool(layout: layout),
            ),
            GallerySpecimen(
              label: GalleryLabels.toggledOn,
              child: tool(layout: layout, active: true),
            ),
            GallerySpecimen(
              label: GalleryLabels.disabled,
              child: tool(layout: layout, disabled: true),
            ),
            GallerySpecimen(
              label: GalleryLabels.disabledWithReason,
              child: tool(
                layout: layout,
                disabled: true,
                disabledReason: future,
              ),
            ),
          ],
        ),
      GalleryRow(
        label: GalleryLabels.props,
        children: [
          GallerySpecimen(
            label: SpecName.iconOnly.name,
            child: tool(showLabel: false),
          ),
          GallerySpecimen(
            label: SpecName.withMenu.name,
            child: tool(hasMenu: true, active: true),
          ),
          GallerySpecimen(
            label: SpecName.withSwatch.name,
            child: tool(
              hasMenu: true,
              active: true,
              swatch: AnnotationColor.yellow.resolve(theme),
            ),
          ),
          GallerySpecimen(
            label: GalleryLabels.both(
              SpecName.stacked.name,
              SpecName.withSwatch.name,
            ),
            child: tool(
              layout: ToolButtonLayout.stacked,
              active: true,
              swatch: AnnotationColor.green.resolve(theme),
            ),
          ),
        ],
      ),
    ],
  );
}
