import 'package:ferman/design/components/components.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/account_name.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The first comment asks once for the name to show on comments (G46),
/// prefilled from the system's account, editable and allowed to stay empty.
/// Settings › General changes it later.
class CommenterNameDialog extends StatefulWidget {
  /// The dialog; [done] gets the name, or null for Cancel.
  const new({required this.done, super.key});

  /// Called once with the answer.
  final ValueChanged<String?> done;

  @override
  State<CommenterNameDialog> createState() => _CommenterNameDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<ValueChanged<String?>>.has('done', done));
  }
}

class _CommenterNameDialogState extends State<CommenterNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: accountName(),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save([String? _]) => widget.done(_name.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      title: l10n.commentNameTitle,
      description: l10n.commentNameBody,
      onClose: () => widget.done(null),
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: () => widget.done(null),
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: _save,
          child: Text(l10n.commentNameSave),
        ),
      ],
      child: TextField(
        label: l10n.settingsCommenterName,
        controller: _name,
        autofocus: true,
        onSubmitted: _save,
      ),
    );
  }
}
