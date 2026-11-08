import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart' hide AnnotationColor;
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/forms/form_state.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/signatures/add_signature_dialog.dart';
import 'package:ferman/features/signatures/sign_tools.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The 40 px heading the right panels share (FmFormPanel line 16).
class _Heading extends StatelessWidget {
  const new({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Container(
      height: FormPanel.headingHeight,
      padding: EdgeInsetsDirectional.only(
        start: theme.space.space3,
        end: theme.space.space1_5,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: Row(
        spacing: theme.space.space2,
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.panelTitle.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// The panel's surface: `--panel-w` wide, a subtle line on its start side.
Widget _surface(
  BuildContext context, {
  required String label,
  required double? width,
  required List<Widget> children,
}) {
  final theme = context.ferman;
  return Semantics(
    container: true,
    explicitChildNodes: true,
    label: label,
    child: Container(
      width: width ?? theme.size.panelW,
      decoration: BoxDecoration(
        color: theme.colors.surfacePanel,
        border: BorderDirectional(
          start: BorderSide(
            color: theme.colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

/// Fill & Sign's right panel: FmFormPanel on a form, Fill anything on a page
/// without fields or with one of its tools.
class FillSignPanel extends ConsumerWidget {
  /// The panel, [width] wide (null: `--panel-w`).
  const new({super.key, this.width});

  /// The width the user dragged it to.
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(documentFormProvider).value;
    final tool = ref.watch(fillToolsStateProvider).effective(form);
    return tool == FillTool.fields && form != null
        ? FormPanel(form: form, width: width)
        : FillAnythingPanel(width: width);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width));
  }
}

/// FmFormPanel (a5-1, a5-2): the required count with its bar, Highlight
/// fields and Show tab order, the signed-form and font notices, every field
/// with its status, Clear form… and Finish.
class FormPanel extends ConsumerWidget {
  /// The panel of [form].
  const new({required this.form, super.key, this.width});

  /// The form.
  final FormInfo form;

  /// The width the user dragged it to.
  final double? width;

  /// FmFormPanel's heading: `height: 40px`.
  static const double headingHeight = 40;

  /// A field's row: `height: 28px`.
  static const double rowHeight = 28;

  /// A row's icon: `size={14}`.
  static const double rowIcon = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final session = ref.watch(formSessionProvider);
    final gate = ref.watch(fillGateProvider).value;
    final refusal = ref.watch(fillRefusalProvider);
    final commands = ref.read(formCommandsProvider.notifier);
    final notifier = ref.read(formSessionProvider.notifier);
    final fillable = fillableFields(form);
    final at = fillable.indexWhere((f) => f.handle == session.current);
    final filled = form.required - form.requiredLeft;
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final summary = [
      l10n.formSummaryFields(
        form.fields.length,
        format.integer(form.fields.length),
      ),
      if (form.requiredLeft > 0)
        l10n.formRequiredLeft(
          form.requiredLeft,
          format.integer(form.requiredLeft),
        )
      else
        l10n.formAllRequiredFilled,
      if (at >= 0)
        l10n.formFieldOf(
          format.integer(at + 1),
          format.integer(fillable.length),
        ),
    ].join(' · ');
    final rows = <Widget>[];
    String? group;
    for (final field in form.fields) {
      // shortcut: sections come from the full name's parent ("kisisel.ad");
      // upgrade if forms name their sections another way.
      final dot = field.name.lastIndexOf('.');
      final parent = dot > 0 ? field.name.substring(0, dot) : null;
      if (parent != null && parent != group) {
        rows.add(_Section(parent));
      }
      group = parent;
      rows.add(
        _FieldRow(
          field: field,
          current: field.handle == session.current,
          marked: session.marked.contains(field.handle),
          error:
              field.problem != null ||
              (session.attempted && field.required && !field.filled),
          onPressed: field.readOnly || field.kind == FieldKind.push
              ? null
              : () => notifier.show(field),
        ),
      );
    }
    return _surface(
      context,
      label: l10n.formPanelTitle,
      width: width,
      children: [
        _Heading(
          title: l10n.formPanelTitle,
          action: _More(refusal: refusal),
        ),
        Container(
          padding: EdgeInsetsDirectional.all(theme.space.space3),
          decoration: BoxDecoration(border: Border(bottom: line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space2,
            children: [
              if (form.required > 0)
                ProgressBar(
                  value: filled / form.required,
                  label: l10n.formRequiredProgress(
                    format.integer(filled),
                    format.integer(form.required),
                  ),
                ),
              Text(
                summary,
                style: theme.typography.caption.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
              Switch(
                value: session.highlight,
                label: l10n.formHighlight,
                onChanged: (value) => notifier.options(highlight: value),
              ),
              Switch(
                value: session.order,
                label: l10n.formShowOrder,
                onChanged: (value) => notifier.options(order: value),
              ),
            ],
          ),
        ),
        if (refusal == null &&
            (gate == OpGate.keepsSignatures || gate == OpGate.breaksSignatures))
          Padding(
            padding: EdgeInsetsDirectional.all(theme.space.space3),
            child: Banner(
              tone: gate == OpGate.keepsSignatures
                  ? BannerTone.info
                  : BannerTone.warning,
              icon: IconName.badgeCheck,
              title: l10n.formSignedTitle,
              child: Text(
                gate == OpGate.keepsSignatures
                    ? l10n.formSignedKeeps
                    : l10n.formSignedBreaks,
              ),
            ),
          ),
        if (session.fonts.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.all(theme.space.space3),
            child: Banner(
              title: l10n.formFontNoticeTitle,
              onDismiss: notifier.dismissFonts,
              dismissLabel: l10n.formDismiss,
              child: Text(l10n.formFontNoticeBody(session.fonts.join(', '))),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.symmetric(
              vertical: theme.space.space1,
              horizontal: theme.space.space1_5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
        Container(
          padding: EdgeInsetsDirectional.symmetric(
            vertical: theme.space.space2_5,
            horizontal: theme.space.space3,
          ),
          decoration: BoxDecoration(border: Border(top: line)),
          child: Row(
            spacing: theme.space.space2,
            children: [
              Button(
                size: ButtonSize.sm,
                variant: ButtonVariant.ghost,
                disabled: refusal != null,
                disabledReason: refusal?.call(l10n),
                onPressed: refusal == null ? commands.clear : null,
                child: Text(l10n.formClear),
              ),
              const Spacer(),
              Button(
                size: ButtonSize.sm,
                variant: ButtonVariant.primary,
                icon: IconName.check,
                disabled: refusal != null,
                disabledReason: refusal?.call(l10n),
                onPressed: refusal == null ? commands.finish : null,
                child: Text(l10n.formFinish),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<FormInfo>('form', form))
      ..add(DoubleProperty('width', width));
  }
}

/// The panel's More: Clear form… and, not built yet, Export data….
class _More extends ConsumerStatefulWidget {
  const new({required this.refusal});

  final String Function(AppLocalizations)? refusal;

  @override
  ConsumerState<_More> createState() => _MoreState();
}

class _MoreState extends ConsumerState<_More> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void close() => setState(() => _open = false);
    return Popover(
      open: _open,
      surface: false,
      onDismiss: close,
      anchor: IconButton(
        icon: IconName.ellipsis,
        label: l10n.formMore,
        size: IconButtonSize.xs,
        onPressed: () => setState(() => _open = !_open),
      ),
      child: Menu(
        semanticLabel: l10n.formMore,
        autofocus: true,
        items: [
          MenuItem(
            id: 'clear',
            label: l10n.formClear,
            disabled: widget.refusal != null,
            disabledReason: widget.refusal?.call(l10n),
          ),
          MenuItem(
            id: 'export',
            label: l10n.formExportData,
            disabled: true,
            disabledReason: Feature.formDataExport.disabledReason(context),
          ),
        ],
        onClose: close,
        onSelected: (item) {
          close();
          if (item.id == 'clear') {
            ref.read(formCommandsProvider.notifier).clear();
          }
        },
      ),
    );
  }
}

/// A heading over a section's fields.
class _Section extends StatelessWidget {
  const new(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          theme.space.space1_5,
          theme.space.space2_5,
          theme.space.space1_5,
          theme.space.space1,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.label.copyWith(
            color: theme.colors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// One field in FmFormPanel: its status icon, its name, and "Required"
/// while a required field is empty.
class _FieldRow extends StatelessWidget {
  const new({
    required this.field,
    required this.current,
    required this.marked,
    required this.error,
    required this.onPressed,
  });

  final FieldInfo field;
  final bool current;
  final bool marked;
  final bool error;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final colors = theme.colors;
    final (icon, iconColor) = error
        ? (IconName.circleAlert, colors.danger)
        : marked
        ? (IconName.triangleAlert, colors.warningSolid)
        : field.filled
        ? (IconName.circleCheck, colors.successSolid)
        : current
        ? (IconName.textCursorInput, colors.accent)
        : (IconName.circle, colors.iconDisabled);
    final required = field.required && (!field.filled || error) && !current;
    return FermanInteractive(
      onPressed: onPressed,
      selected: current,
      semanticLabel: [
        field.label ?? field.name,
        if (field.required) l10n.formRequired,
        if (marked) l10n.formMarkedField,
      ].join(', '),
      builder: (context, states, _) => Container(
        height: FormPanel.rowHeight,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: theme.space.space2,
        ),
        decoration: BoxDecoration(
          color: current
              ? colors.surfaceSelected
              : states.contains(WidgetState.hovered)
              ? colors.surfaceHover
              : null,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusSm),
          ),
        ),
        child: Row(
          spacing: theme.space.space2,
          children: [
            Icon(icon, size: FormPanel.rowIcon, color: iconColor),
            Expanded(
              child: Text(
                field.label ?? field.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(
                  color: current ? colors.textAccent : colors.textPrimary,
                ),
              ),
            ),
            if (required)
              Text(
                l10n.formRequired,
                style: theme.typography.caption.copyWith(color: colors.danger),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fill anything's panel (a5-4): its tools with their keys, and Options.
class FillAnythingPanel extends ConsumerWidget {
  /// The panel, [width] wide.
  const new({super.key, this.width});

  /// The width the user dragged it to.
  final double? width;

  /// A tool's row: `height: 32px`.
  static const double toolHeight = 32;

  /// The tools, their icons and their commands, in a5-4's order.
  static const List<(FillTool, IconName, ShellCommand)> tools = [
    (FillTool.text, IconName.textCursorInput, ShellCommand.fillText),
    (FillTool.check, IconName.check, ShellCommand.fillCheck),
    (FillTool.cross, IconName.x, ShellCommand.fillCross),
    (FillTool.dot, IconName.circleDot, ShellCommand.fillDot),
    (FillTool.date, IconName.calendar, ShellCommand.todaysDate),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final keys = ref.watch(shortcutBindingsProvider);
    final form = ref.watch(documentFormProvider).value;
    final choices = ref.watch(fillToolsStateProvider);
    final tool = choices.effective(form);
    final notifier = ref.read(fillToolsStateProvider.notifier);
    final refusal = ref.watch(fillRefusalProvider)?.call(l10n);
    // A signature is a stamp annotation, behind the Comment gate (G148).
    final signRefusal = ref.watch(commentRefusalProvider)?.call(l10n);
    Widget row(
      IconName icon,
      String label,
      List<String> keys, {
      bool active = false,
      VoidCallback? onPressed,
      String? reason,
    }) => FermanInteractive(
      onPressed: onPressed,
      selected: active,
      disabled: onPressed == null,
      disabledReason: reason,
      semanticLabel: label,
      builder: (context, states, _) {
        final color = onPressed == null
            ? theme.colors.textDisabled
            : active
            ? theme.colors.textAccent
            : theme.colors.textPrimary;
        return Container(
          height: toolHeight,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.space.space2,
          ),
          decoration: BoxDecoration(
            color: active
                ? theme.colors.surfaceSelected
                : states.contains(WidgetState.hovered)
                ? theme.colors.surfaceHover
                : null,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusSm),
            ),
          ),
          child: Row(
            spacing: theme.space.space2_5,
            children: [
              Icon(icon, size: theme.density.iconMd, color: color),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: color),
                ),
              ),
              Kbd(keys, tone: KbdTone.plain),
            ],
          ),
        );
      },
    );
    return _surface(
      context,
      label: l10n.fillPanelTitle,
      width: width,
      children: [
        _Heading(title: l10n.fillPanelTitle),
        Padding(
          padding: EdgeInsetsDirectional.all(theme.space.space1_5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (which, icon, command) in tools)
                row(
                  icon,
                  _toolLabel(l10n, which),
                  keys.caps(command) ?? const [],
                  active: which == tool,
                  reason: refusal,
                  onPressed: refusal == null
                      ? () => notifier.pick(which)
                      : null,
                ),
              row(
                IconName.signature,
                l10n.fillToolSignature,
                keys.caps(ShellCommand.addSignature) ?? const [],
                reason: signRefusal,
                onPressed: signRefusal == null
                    ? () =>
                          showAddSignatureDialog(ref, yourName: yourNameOf(ref))
                    : null,
              ),
            ],
          ),
        ),
        PanelSection(
          title: l10n.fillOptions,
          collapsible: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space2_5,
            children: [
              Switch(
                value: choices.snap,
                label: l10n.fillSnap,
                onChanged: (value) => notifier.options(snap: value),
              ),
              Switch(
                value: choices.comb,
                label: l10n.fillComb,
                onChanged: (value) => notifier.options(comb: value),
              ),
              Select<FillInk>(
                size: FieldSize.sm,
                label: l10n.fillInk,
                value: choices.ink,
                options: [
                  SelectOption(value: FillInk.black, label: l10n.fillInkBlack),
                  SelectOption(value: FillInk.blue, label: l10n.fillInkBlue),
                ],
                onChanged: (ink) => notifier.options(ink: ink),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width));
  }
}

/// Fill anything's name of [tool].
String _toolLabel(AppLocalizations l10n, FillTool tool) => switch (tool) {
  FillTool.text || FillTool.fields => l10n.fillToolText,
  FillTool.check => l10n.fillToolCheck,
  FillTool.cross => l10n.fillToolCross,
  FillTool.dot => l10n.fillToolDot,
  FillTool.date => l10n.fillToolToday,
};

/// The bar over the canvas in Fill & Sign (a5-1, a5-4): a form's field and
/// required counts with Hide and Show tab order, or, on a page without
/// fields, Fill anything's hint with Find fields (P4).
class FormBanner extends ConsumerWidget {
  /// The bar.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final form = ref.watch(documentFormProvider).value;
    final session = ref.watch(formSessionProvider);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    if (form == null || session.bannerHidden) return const SizedBox.shrink();
    if (form.fields.isEmpty) {
      return Banner(
        variant: BannerVariant.bar,
        icon: IconName.textCursorInput,
        title: l10n.fillBannerTitle,
        actions: [
          Button(
            size: ButtonSize.sm,
            icon: IconName.scan,
            disabled: true,
            disabledReason: Feature.preparingForms.disabledReason(context),
            child: Text(l10n.fillFindFields),
          ),
        ],
        child: Text(l10n.fillBannerBody),
      );
    }
    final notifier = ref.read(formSessionProvider.notifier);
    return Banner(
      variant: BannerVariant.bar,
      icon: IconName.textCursorInput,
      title: l10n.formBannerTitle,
      actions: [
        Button(
          size: ButtonSize.sm,
          variant: ButtonVariant.ghost,
          onPressed: notifier.hideBanner,
          child: Text(l10n.formBannerHide),
        ),
        Button(
          size: ButtonSize.sm,
          onPressed: () => notifier.options(order: !session.order),
          child: Text(session.order ? l10n.formHideOrder : l10n.formShowOrder),
        ),
      ],
      child: Text(
        l10n.formBannerBody(
          form.fields.length,
          format.integer(form.fields.length),
          format.integer(form.required),
        ),
      ),
    );
  }
}

/// The field navigation at the end of the Fill & Sign row (FmWindow line
/// 102): previous, "Field 3 of 20", next, and the required count.
class FieldNavigation extends ConsumerWidget {
  /// The navigation; nothing without a form.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final keys = ref.watch(shortcutBindingsProvider);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final form = ref.watch(documentFormProvider).value;
    if (form == null || form.fields.isEmpty) return const SizedBox.shrink();
    final current = ref.watch(formSessionProvider.select((s) => s.current));
    final notifier = ref.read(formSessionProvider.notifier);
    final fillable = fillableFields(form);
    final at = fillable.indexWhere((f) => f.handle == current);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: theme.space.space1,
      children: [
        IconButton(
          icon: IconName.chevronLeft,
          label: l10n.formPreviousField,
          shortcut: keys.caps(ShellCommand.previousField),
          size: IconButtonSize.sm,
          onPressed: () => notifier.move(form, -1),
        ),
        Text(
          at < 0
              ? l10n.formNavFields(
                  fillable.length,
                  format.integer(fillable.length),
                )
              : l10n.formNavField(
                  format.integer(at + 1),
                  format.integer(fillable.length),
                ),
          style: theme.typography.bodyStrong.copyWith(
            color: theme.colors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        IconButton(
          icon: IconName.chevronRight,
          label: l10n.formNextField,
          shortcut: keys.caps(ShellCommand.nextField),
          size: IconButtonSize.sm,
          onPressed: () => notifier.move(form, 1),
        ),
        SizedBox(width: theme.space.space1_5),
        Badge(
          tone: form.requiredLeft > 0 ? BadgeTone.danger : BadgeTone.success,
          label: form.requiredLeft > 0
              ? l10n.formRequiredLeft(
                  form.requiredLeft,
                  format.integer(form.requiredLeft),
                )
              : l10n.formNavAllFilled,
        ),
      ],
    );
  }
}
