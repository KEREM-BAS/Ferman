import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart' show MissingFont;
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// How Finish ends (G47): the fields flattened or kept, then Save or Save as.
@immutable
final class FinishChoice {
  /// The choice.
  const new({required this.flatten, required this.saveAs});

  /// The fields become page content.
  final bool flatten;

  /// Save as… rather than Save.
  final bool saveAs;
}

/// G47's Finish dialog: flatten the fields or keep them editable, then Save
/// or Save as.
class FormFinishDialog extends StatefulWidget {
  /// The dialog; [done] gets the choice, or null for Cancel.
  const new({required this.done, super.key});

  /// Called once with the answer.
  final ValueChanged<FinishChoice?> done;

  @override
  State<FormFinishDialog> createState() => _FormFinishDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      ObjectFlagProperty<ValueChanged<FinishChoice?>>.has('done', done),
    );
  }
}

class _FormFinishDialogState extends State<FormFinishDialog> {
  bool _flatten = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    // Radio's onChanged hands the value over positionally.
    // ignore: avoid_positional_boolean_parameters
    void choose(bool? flatten) =>
        setState(() => _flatten = flatten ?? _flatten);

    return Dialog(
      title: l10n.formFinishTitle,
      description: l10n.formFinishBody,
      icon: IconName.check,
      onClose: () => widget.done(null),
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: () => widget.done(null),
        child: Text(l10n.organizeCancel),
      ),
      alternateAction: Button(
        onPressed: () =>
            widget.done(FinishChoice(flatten: _flatten, saveAs: true)),
        child: Text(l10n.formFinishSaveAs),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          autofocus: true,
          onPressed: () =>
              widget.done(FinishChoice(flatten: _flatten, saveAs: false)),
          child: Text(l10n.formFinishSave),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space2_5,
        children: [
          Radio<bool>(
            value: true,
            groupValue: _flatten,
            label: l10n.formFinishFlatten,
            description: l10n.formFinishFlattenBody,
            onChanged: choose,
          ),
          Radio<bool>(
            value: false,
            groupValue: _flatten,
            label: l10n.formFinishKeep,
            description: l10n.formFinishKeepBody,
            onChanged: choose,
          ),
        ],
      ),
    );
  }
}

/// G47's Clear form confirmation.
class FormClearDialog extends StatelessWidget {
  /// The dialog; [done] says whether to clear.
  const new({required this.done, super.key});

  /// Called once with the answer.
  final void Function({required bool confirmed}) done;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      title: l10n.formClearTitle,
      description: l10n.formClearBody,
      tone: DialogTone.danger,
      onClose: () => done(confirmed: false),
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: () => done(confirmed: false),
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.danger,
          onPressed: () => done(confirmed: true),
          child: Text(l10n.formClearConfirm),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      ObjectFlagProperty<void Function({required bool confirmed})>.has(
        'done',
        done,
      ),
    );
  }
}

/// Ask each time (a11-1c, M4 decision 18): characters the field's font
/// cannot draw take bundled IBM Plex, or are left out with the field marked.
class FormFontDialog extends StatelessWidget {
  /// The dialog; [done] gets the choice, or null for Cancel, which keeps the
  /// field as it was.
  const new({required this.done, super.key});

  /// Called once with the answer.
  final ValueChanged<MissingFont?> done;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      title: l10n.formFontAskTitle,
      description: l10n.formFontAskBody,
      tone: DialogTone.warning,
      onClose: () => done(null),
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: () => done(null),
        child: Text(l10n.organizeCancel),
      ),
      alternateAction: Button(
        onPressed: () => done(MissingFont.keep),
        child: Text(l10n.formFontAskKeep),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: () => done(MissingFont.bundled),
          child: Text(l10n.formFontAskPlex),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      ObjectFlagProperty<ValueChanged<MissingFont?>>.has('done', done),
    );
  }
}
