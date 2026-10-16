import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The width of a field as it sits in the 264 px panel, inside its 12 px
/// padding.
double _fieldWidth(FermanTheme theme) =>
    theme.size.panelW - 2 * theme.space.space3;

/// A stage with room for an open popover under its trigger: the font
/// picker's popover, the widest and tallest, with its margins.
Widget _popoverStage(FermanTheme theme, Widget child) => GalleryStage(
  width: FontPicker.popoverWidth + theme.space.space8,
  height: FontPicker.popoverMaxHeight + theme.space.space16,
  child: Padding(
    padding: EdgeInsetsDirectional.all(theme.space.space2),
    child: child,
  ),
);

/// `Field`: the box every field shares, in each state and size.
Widget fieldSection(BuildContext context) {
  final theme = context.ferman;
  Widget field({
    FieldSize size = FieldSize.md,
    String? error,
    bool warning = false,
    bool disabled = false,
    String value = GallerySamples.pageValue,
  }) => Field(
    label: GallerySamples.page,
    hint: GallerySamples.pageHint,
    error: error,
    warning: warning,
    size: size,
    disabled: disabled,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(value),
    ),
  );
  final width = _fieldWidth(theme);
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(
            label: GalleryLabels.standard,
            width: width,
            child: field(),
          ),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            width: width,
            child: field(),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            width: width,
            child: field(),
          ),
          GallerySpecimen(
            label: GalleryLabels.error,
            width: width,
            child: field(
              error: GallerySamples.pageError,
              value: GallerySamples.pageValueError,
            ),
          ),
          GallerySpecimen(
            label: GalleryLabels.warning,
            width: width,
            child: field(warning: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabled,
            width: width,
            child: field(disabled: true),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final size in FieldSize.values)
            GallerySpecimen(
              label: size.name,
              width: width,
              child: field(size: size),
            ),
        ],
      ),
    ],
  );
}

/// `TextField`: each state and size, with an icon and a suffix.
Widget textFieldSection(BuildContext context) {
  final theme = context.ferman;
  final future = futureVersionReason(context);
  final width = _fieldWidth(theme);
  Widget specimen(
    String label, {
    String text = GallerySamples.pageValue,
    String? error,
    bool disabled = false,
    String? disabledReason,
    FieldSize size = FieldSize.sm,
    Set<WidgetState>? forced,
  }) => GallerySpecimen(
    label: label,
    forced: forced,
    width: width,
    child: _TextFieldSample(
      text: text,
      error: error,
      disabled: disabled,
      disabledReason: disabledReason,
      size: size,
    ),
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          specimen(GalleryLabels.standard),
          specimen(GalleryLabels.hover, forced: GalleryForced.hover),
          specimen(
            GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
          ),
          specimen(GalleryLabels.placeholder, text: ''),
          specimen(
            GalleryLabels.error,
            text: GallerySamples.pageValueError,
            error: GallerySamples.pageError,
          ),
          specimen(GalleryLabels.disabled, text: '', disabled: true),
          specimen(
            GalleryLabels.disabledWithReason,
            text: '',
            disabled: true,
            disabledReason: future,
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final size in FieldSize.values) specimen(size.name, size: size),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.props,
        children: [
          GallerySpecimen(
            label: GalleryLabels.both(SpecName.icon.name, SpecName.suffix.name),
            width: width,
            child: _TextFieldSample(
              text: GallerySamples.spaceAfterValue,
              label: GallerySamples.spaceAfter,
              icon: IconName.rows2,
              suffix: LengthUnit.point.symbol,
            ),
          ),
        ],
      ),
    ],
  );
}

/// A [TextField] that owns its controller, starting from [text].
class _TextFieldSample extends StatefulWidget {
  const new({
    required this.text,
    this.label = GallerySamples.page,
    this.error,
    this.disabled = false,
    this.disabledReason,
    this.size = FieldSize.sm,
    this.icon,
    this.suffix,
  });

  final String text;
  final String label;
  final String? error;
  final bool disabled;
  final String? disabledReason;
  final FieldSize size;
  final IconName? icon;
  final String? suffix;

  @override
  State<_TextFieldSample> createState() => _TextFieldSampleState();
}

class _TextFieldSampleState extends State<_TextFieldSample> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    label: widget.label,
    controller: _controller,
    placeholder: GallerySamples.page,
    error: widget.error,
    disabled: widget.disabled,
    disabledReason: widget.disabledReason,
    size: widget.size,
    icon: widget.icon,
    suffix: widget.suffix,
  );
}

/// `Select`: each state and size; the list opens on a click.
Widget selectSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  final future = futureVersionReason(context);
  final width = _fieldWidth(theme);
  final options = [
    SelectOption(value: 0, label: l10n.settingsPageLayoutScroll),
    SelectOption(value: 1, label: l10n.settingsPageLayoutSingle),
    SelectOption(
      value: 2,
      label: l10n.settingsPageLayoutSpread,
      disabled: true,
      disabledReason: future,
    ),
  ];
  Widget select({
    FieldSize size = FieldSize.md,
    bool disabled = false,
    String? disabledReason,
  }) => GalleryValue<int>(
    initial: 0,
    builder: (context, value, set) => Select<int>(
      label: l10n.settingsPageLayout,
      options: options,
      value: value,
      onChanged: set,
      size: size,
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
            width: width,
            child: select(),
          ),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            width: width,
            child: select(),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            width: width,
            child: select(),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabled,
            width: width,
            child: select(disabled: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabledWithReason,
            width: width,
            child: select(disabled: true, disabledReason: future),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final size in FieldSize.values)
            GallerySpecimen(
              label: size.name,
              width: width,
              child: select(size: size),
            ),
        ],
      ),
      const GalleryNote(GalleryLabels.selectOpenNote),
    ],
  );
}

/// `NumberStepper`: each state and size.
Widget numberStepperSection(BuildContext context) {
  final region = GalleryEnvironment.of(context).region;
  Widget stepper({
    double initial = 1.5,
    FieldSize size = FieldSize.sm,
    bool disabled = false,
    String? error,
  }) => GalleryValue<double>(
    initial: initial,
    builder: (context, value, set) => NumberStepper(
      label: GallerySamples.lineSpacing,
      value: value,
      min: 1,
      max: 3,
      step: 0.05,
      precision: 2,
      size: size,
      disabled: disabled,
      error: error,
      region: region,
      onChanged: set,
    ),
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(label: GalleryLabels.standard, child: stepper()),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            child: stepper(),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: stepper(),
          ),
          GallerySpecimen(
            label: SpecName.arrowDisabled.name,
            child: stepper(initial: 3),
          ),
          GallerySpecimen(
            label: GalleryLabels.error,
            child: stepper(initial: 1, error: GallerySamples.pageError),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabled,
            child: stepper(disabled: true),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final size in FieldSize.values)
            GallerySpecimen(
              label: size.name,
              child: stepper(size: size),
            ),
        ],
      ),
      const GalleryNote(GalleryLabels.stepperArrowsNote),
    ],
  );
}

/// `Checkbox`: each state.
Widget checkboxSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final future = futureVersionReason(context);
  Widget box({
    bool checked = false,
    bool indeterminate = false,
    bool disabled = false,
    String? disabledReason,
    String? description,
  }) => GalleryValue<bool>(
    initial: checked,
    builder: (context, value, set) => Checkbox(
      label: l10n.settingsReopen,
      description: description,
      checked: value,
      indeterminate: indeterminate,
      disabled: disabled,
      disabledReason: disabledReason,
      onChanged: set,
    ),
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(label: GalleryLabels.standard, child: box()),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            child: box(),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: box(checked: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.checked,
            child: box(checked: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.indeterminate,
            child: box(indeterminate: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabled,
            child: box(disabled: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabledChecked,
            child: box(checked: true, disabled: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabledWithReason,
            child: box(disabled: true, disabledReason: future),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.props,
        children: [
          GallerySpecimen(
            label: SpecName.description.name,
            child: GalleryValue<bool>(
              initial: true,
              builder: (context, value, set) => Checkbox(
                label: GallerySamples.ocrFirst,
                description: l10n.settingsNetUpdatesDescription,
                checked: value,
                onChanged: set,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// `Radio`: each state, in the page-theme group of Settings.
Widget radioSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final future = futureVersionReason(context);
  Widget radio({
    bool checked = false,
    bool disabled = false,
    String? disabledReason,
  }) => Radio<int>(
    value: 0,
    groupValue: checked ? 0 : 1,
    label: l10n.settingsPagePaper,
    description: l10n.settingsPagePaperDescription,
    disabled: disabled,
    disabledReason: disabledReason,
    onChanged: (_) {},
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(label: GalleryLabels.standard, child: radio()),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            child: radio(),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: radio(checked: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.checked,
            child: radio(checked: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabled,
            child: radio(disabled: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabledChecked,
            child: radio(checked: true, disabled: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabledWithReason,
            child: radio(disabled: true, disabledReason: future),
          ),
        ],
      ),
      GalleryRow(
        label: SpecName.group.name,
        children: [
          GallerySpecimen(
            label: SpecName.group.name,
            child: GalleryValue<int>(
              initial: 0,
              builder: (context, value, set) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: context.ferman.space.space2,
                children: [
                  for (final (index, label, description) in [
                    (
                      0,
                      l10n.settingsPagePaper,
                      l10n.settingsPagePaperDescription,
                    ),
                    (
                      1,
                      l10n.settingsPageDimmed,
                      l10n.settingsPageDimmedDescription,
                    ),
                    (
                      2,
                      l10n.settingsPageDark,
                      l10n.settingsPageDarkDescription,
                    ),
                  ])
                    Radio<int>(
                      value: index,
                      groupValue: value,
                      label: label,
                      description: description,
                      onChanged: set,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// `Switch`: off, on and the other states.
Widget switchSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final future = futureVersionReason(context);
  Widget toggle({
    bool on = false,
    bool disabled = false,
    String? disabledReason,
  }) => GalleryValue<bool>(
    initial: on,
    builder: (context, value, set) => Switch(
      label: l10n.settingsNetUpdates,
      value: value,
      disabled: disabled,
      disabledReason: disabledReason,
      onChanged: set,
    ),
  );
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      GallerySpecimen(label: GalleryLabels.off, child: toggle()),
      GallerySpecimen(label: GalleryLabels.on, child: toggle(on: true)),
      GallerySpecimen(
        label: GalleryLabels.hover,
        forced: GalleryForced.hover,
        child: toggle(),
      ),
      GallerySpecimen(
        label: GalleryLabels.focusVisible,
        forced: GalleryForced.focusVisible,
        child: toggle(on: true),
      ),
      GallerySpecimen(
        label: GalleryLabels.disabled,
        child: toggle(disabled: true),
      ),
      GallerySpecimen(
        label: GalleryLabels.disabledWithReason,
        child: toggle(on: true, disabled: true, disabledReason: future),
      ),
    ],
  );
}

/// `ColorPicker`: the trigger's states, and the open popover.
Widget colorPickerSection(BuildContext context) {
  final theme = context.ferman;
  final documentColors = [
    theme.ramps.paper900,
    theme.ramps.ink600,
    theme.ramps.seal500,
  ];
  Widget picker({
    Color? value,
    bool open = false,
    bool allowNone = false,
    bool disabled = false,
    FieldSize size = FieldSize.sm,
  }) => GalleryValue<Color?>(
    initial: value,
    builder: (context, current, set) => ColorPicker(
      label: GallerySamples.color,
      value: current,
      documentColors: documentColors,
      allowNone: allowNone,
      open: open ? true : null,
      size: size,
      disabled: disabled,
      onChanged: set,
      noneLabel: GallerySamples.none,
      documentColorsLabel: GallerySamples.inThisDocument,
      standardColorsLabel: GallerySamples.standardColors,
      noColorLabel: GallerySamples.noColor,
      hexLabel: GallerySamples.hex,
      hexSemanticLabel: GallerySamples.hexColor,
      dialogLabel: GallerySamples.chooseColor,
    ),
  );
  final ink = theme.ramps.paper900;
  final width = _fieldWidth(theme) / 2;
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(
            label: GalleryLabels.standard,
            width: width,
            child: picker(value: ink),
          ),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            width: width,
            child: picker(value: ink),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            width: width,
            child: picker(value: ink),
          ),
          GallerySpecimen(
            label: SpecName.none.name,
            width: width,
            child: picker(allowNone: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabled,
            width: width,
            child: picker(value: ink, disabled: true),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final size in FieldSize.values)
            GallerySpecimen(
              label: size.name,
              width: width,
              child: picker(value: ink, size: size),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.open,
        children: [
          GallerySpecimen(
            label: GalleryLabels.both(
              GalleryLabels.open,
              SpecName.swatchSelected.name,
            ),
            child: _popoverStage(
              theme,
              SizedBox(
                width: width,
                child: picker(value: ink, open: true),
              ),
            ),
          ),
          GallerySpecimen(
            label: GalleryLabels.both(
              SpecName.swatchHover.name,
              GalleryLabels.focusVisible,
            ),
            forced: const {
              ...GalleryForced.hover,
              ...GalleryForced.focusVisible,
            },
            child: _popoverStage(
              theme,
              SizedBox(
                width: width,
                child: picker(value: ink, open: true, allowNone: true),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// `FontPicker`: the trigger's states, the missing font, and the open
/// popover.
Widget fontPickerSection(BuildContext context) {
  final theme = context.ferman;
  const fonts = [
    FontOption(
      name: GallerySamples.plexSerif,
      family: GallerySamples.plexSerif,
      group: FontGroup.document,
    ),
    FontOption(
      name: GallerySamples.garamond,
      available: false,
      substitute: GallerySamples.garamondSubstitute,
      group: FontGroup.document,
    ),
    FontOption(name: GallerySamples.plexSans, family: GallerySamples.plexSans),
    FontOption(name: GallerySamples.georgia),
    FontOption(name: GallerySamples.timesNewRoman),
  ];
  final width = _fieldWidth(theme);
  Widget picker({
    String value = GallerySamples.plexSerif,
    List<FontOption> options = fonts,
    bool open = false,
    bool glyphWarning = false,
    String? warning,
    bool disabled = false,
    FieldSize size = FieldSize.sm,
  }) => GalleryValue<String>(
    initial: value,
    builder: (context, current, set) => FontPicker(
      label: GallerySamples.font,
      value: current,
      fonts: options,
      open: open ? true : null,
      glyphWarning: glyphWarning,
      warning: warning,
      disabled: disabled,
      size: size,
      onChanged: set,
      missingNote: GallerySamples.garamondMissing,
      missingBadge: const Badge(
        tone: BadgeTone.warning,
        label: GallerySamples.notInstalled,
      ),
      documentGroupLabel: GallerySamples.inThisDocument,
      systemGroupLabel: GallerySamples.onThisDevice,
      searchPlaceholder: GallerySamples.searchFonts,
      searchSemanticLabel: GallerySamples.searchFonts,
      listSemanticLabel: GallerySamples.fonts,
      noMatchesText: (_) => GallerySamples.noFontsMatch,
    ),
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(
            label: GalleryLabels.standard,
            width: width,
            child: picker(),
          ),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            width: width,
            child: picker(),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            width: width,
            child: picker(),
          ),
          GallerySpecimen(
            label: SpecName.missing.name,
            width: width,
            child: picker(value: GallerySamples.garamond),
          ),
          GallerySpecimen(
            label: SpecName.glyphWarning.name,
            width: width,
            child: picker(
              glyphWarning: true,
              warning: GallerySamples.glyphWarning,
            ),
          ),
          GallerySpecimen(
            label: GalleryLabels.disabled,
            width: width,
            child: picker(disabled: true),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final size in FieldSize.values)
            GallerySpecimen(
              label: size.name,
              width: width,
              child: picker(size: size),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.open,
        children: [
          GallerySpecimen(
            label: GalleryLabels.open,
            child: ExcludeFocus(
              child: _popoverStage(
                theme,
                SizedBox(width: width, child: picker(open: true)),
              ),
            ),
          ),
          GallerySpecimen(
            label: SpecName.emptySearch.name,
            child: ExcludeFocus(
              child: _popoverStage(
                theme,
                SizedBox(
                  width: width,
                  child: picker(open: true, options: const []),
                ),
              ),
            ),
          ),
        ],
      ),
      const GalleryNote(GalleryLabels.fontEmptySearchNote),
      const GalleryNote(GalleryLabels.noFocusNote),
    ],
  );
}

/// `Popover`: closed and open under its trigger, with its surface and
/// section heading.
Widget popoverSection(BuildContext context) {
  final theme = context.ferman;
  Widget popover({required bool open}) => Popover(
    open: open,
    anchor: Button(
      iconEnd: IconName.chevronDown,
      onPressed: () {},
      child: const Text(GallerySamples.color),
    ),
    child: SizedBox(
      width: ColorPicker.popoverWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PopoverSection(GallerySamples.inThisDocument),
          Padding(
            padding: EdgeInsetsDirectional.all(theme.space.space2_5),
            child: const Text(GallerySamples.bannerNeutral),
          ),
        ],
      ),
    ),
  );
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      GallerySpecimen(
        label: GalleryLabels.closed,
        child: _popoverStage(theme, popover(open: false)),
      ),
      GallerySpecimen(
        label: GalleryLabels.open,
        child: _popoverStage(theme, popover(open: true)),
      ),
      GallerySpecimen(
        label: SpecName.surface.name,
        child: PopoverSurface(
          child: SizedBox(
            width: ColorPicker.popoverWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PopoverSection(GallerySamples.standardColors),
                Padding(
                  padding: EdgeInsetsDirectional.all(theme.space.space2_5),
                  child: const Text(GallerySamples.bannerNeutral),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
