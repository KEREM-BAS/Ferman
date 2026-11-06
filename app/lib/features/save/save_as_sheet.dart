import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/save/file_exists.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Save as sheet (a1-11, a1-11b): a Ferman dialog with the file name,
/// Where, the formats and the options, then Cancel and Save.
///
/// Where lists the document's own folder, which saves without a picker,
/// and "Other location…", which hands off to the system save panel (ADR
/// 0018); the sheet then shows the folder chosen there, in Where and in
/// the copy line (a1-11b), and takes the name typed there. The name may
/// not hold a folder separator, and `.pdf` is added when it is missing; a
/// name already taken in a folder the panel did not confirm asks for
/// another, so the sheet never replaces a file unasked, and so does the
/// file of another open tab, wherever. Only PDF works:
/// PDF/A-2b (P4) and "Optimized for web" (M4) stay visible and disabled,
/// their reason in place of their description (G111), and so do the two
/// options ([Feature.saveAsOptions]). "Save as a copy" writes a copy and
/// leaves the document as it was (⌥⌘S starts with it checked).
class SaveAsSheet extends ConsumerStatefulWidget {
  /// The sheet for [request].
  const new(this.request, {super.key});

  /// The document and whether the copy option starts checked.
  final SaveSheetRequest request;

  @override
  ConsumerState<SaveAsSheet> createState() => _SaveAsSheetState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SaveSheetRequest>('request', request));
  }
}

class _SaveAsSheetState extends ConsumerState<SaveAsSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.request.document.name,
  );

  /// The document's own folder.
  late final String _home = folderOf(widget.request.document.path ?? '');

  /// The folder chosen in the system save panel, if any.
  String? _chosen;

  /// The file the system save panel confirmed, replacing it if it exists.
  String? _confirmed;

  late String _folder = _home;
  late bool _copy = widget.request.copy;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  DocumentSaver get _saver => ref.read(documentSaverProvider.notifier);

  /// "Other location…": the system save panel, then its folder and name.
  Future<void> _pickOther() async {
    final path = await ref
        .read(filePickerServiceProvider)
        .saveFile(suggestedName: pdfFileName(_name.text));
    if (path == null || !mounted) return;
    setState(() {
      _chosen = _folder = folderOf(path);
      _confirmed = path;
      _name.text = fileName(path);
      _error = null;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text;
    if (!validFileName(name)) {
      setState(
        () => _error = name.trim().isEmpty
            ? l10n.saveAsNameEmpty
            : defaultTargetPlatform == TargetPlatform.windows
            ? l10n.saveAsNameInvalidWindows
            : l10n.saveAsNameInvalid,
      );
      return;
    }
    final path = pathIn(_folder, pdfFileName(name));
    if (_saver.openInAnotherTab(path, widget.request.document)) {
      setState(() => _error = l10n.saveAsNameOpen);
      return;
    }
    if (path != _confirmed &&
        path != widget.request.document.path &&
        await fileExists(path)) {
      if (mounted) setState(() => _error = l10n.saveAsNameTaken);
      return;
    }
    await _saver.saveTo(path, copy: _copy);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final future = Feature.saveAsOptions.disabledReason(context);
    final chosen = _chosen;
    return Dialog(
      title: l10n.saveAsTitle,
      onClose: _saver.closeSheet,
      closeLabel: l10n.saveAsClose,
      cancelAction: Button(
        onPressed: _saver.closeSheet,
        child: Text(l10n.saveAsCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: () => unawaited(_save()),
          child: Text(l10n.shellSave),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _SaveAsSheetLayout.gap,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.space2_5,
            children: [
              Expanded(
                child: TextField(
                  label: l10n.saveAsName,
                  controller: _name,
                  autofocus: true,
                  error: _error,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => unawaited(_save()),
                ),
              ),
              SizedBox(
                width: _SaveAsSheetLayout.whereWidth,
                child: Select<String?>(
                  label: l10n.saveAsWhere,
                  icon: IconName.folder,
                  value: _folder,
                  options: [
                    SelectOption(value: _home, label: folderLabel(_home)),
                    if (chosen != null && chosen != _home)
                      SelectOption(value: chosen, label: folderLabel(chosen)),
                    SelectOption(value: null, label: l10n.saveAsOtherLocation),
                  ],
                  onChanged: (folder) {
                    if (folder == null) {
                      unawaited(_pickOther());
                    } else {
                      setState(() => _folder = folder);
                    }
                  },
                ),
              ),
            ],
          ),
          Semantics(
            container: true,
            label: l10n.saveAsFormat,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.surfaceSunken,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusMd),
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.all(theme.space.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: theme.space.space2_5,
                  children: [
                    Radio<int>(
                      value: 0,
                      groupValue: 0,
                      label: l10n.saveAsPdf,
                      description: l10n.saveAsPdfDescription,
                      onChanged: (_) {},
                    ),
                    Radio<int>(
                      value: 1,
                      groupValue: 0,
                      label: l10n.saveAsPdfA,
                      description: Feature.pdfAAndPreflight.disabledReason(
                        context,
                      ),
                      disabled: true,
                      disabledReason: Feature.pdfAAndPreflight.disabledReason(
                        context,
                      ),
                    ),
                    Radio<int>(
                      value: 2,
                      groupValue: 0,
                      label: l10n.saveAsWeb,
                      description: Feature.compress.disabledReason(context),
                      disabled: true,
                      disabledReason: Feature.compress.disabledReason(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Checkbox(
            checked: _copy,
            label: l10n.saveAsCopy,
            description: _folder == _home
                ? l10n.saveAsCopyDescriptionHere(
                    bidiIsolate(widget.request.document.name),
                  )
                : l10n.saveAsCopyDescription(
                    bidiIsolate(widget.request.document.name),
                    bidiIsolate(folderLabel(_folder)),
                  ),
            onChanged: (value) => setState(() => _copy = value),
          ),
          // Comments are always included, and the edit history stays in
          // the file (an incremental update), so each shows what it does.
          Checkbox(
            checked: true,
            label: l10n.saveAsComments,
            disabled: true,
            disabledReason: future,
          ),
          Checkbox(
            checked: false,
            label: l10n.saveAsHistory,
            disabled: true,
            disabledReason: future,
          ),
        ],
      ),
    );
  }
}

/// a1-11's measures that are not tokens.
abstract final class _SaveAsSheetLayout {
  /// The Where menu's width (`hint-size="180px,52px"`).
  static const double whereWidth = 180;

  /// The gap between the sheet's rows (`gap:14px`).
  static const double gap = 14;
}
