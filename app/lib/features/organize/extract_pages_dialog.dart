import 'dart:async';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/organize/page_range.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for G45's extract of [pages] (indices) of [document], named [name].
void showExtractPagesDialog(
  WidgetRef ref,
  OpenedDocument document,
  String name,
  List<int> pages,
) => ref
    .read(organizeDialogProvider.notifier)
    .show(ExtractPagesDialog(document: document, name: name, pages: pages));

/// Extract pages (G45): one file or one file per page, and optionally deleting
/// the pages afterwards. The files are written as a background job.
class ExtractPagesDialog extends ConsumerStatefulWidget {
  /// The dialog.
  const new({
    required this.document,
    required this.name,
    required this.pages,
    super.key,
  });

  /// The document.
  final OpenedDocument document;

  /// Its file name, untrusted text.
  final String name;

  /// The pages to extract at first, as indices.
  final List<int> pages;

  @override
  ConsumerState<ExtractPagesDialog> createState() => _ExtractPagesDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<OpenedDocument>('document', document))
      ..add(StringProperty('name', name))
      ..add(IterableProperty<int>('pages', pages));
  }
}

class _ExtractPagesDialogState extends ConsumerState<ExtractPagesDialog> {
  late final RegionFormat _format = RegionFormat.forRegion(
    ref.read(regionProvider).region,
  );
  late final TextEditingController _pages = TextEditingController(
    text: formatPageRange(widget.pages, _format),
  );
  bool _each = false;
  bool _delete = false;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The document's name without its extension.
  String get _stem =>
      widget.name.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');

  Future<void> _extract(List<int> pages, AppLocalizations l10n) async {
    final id = widget.document.id;
    final name = widget.name;
    final jobs = ref.read(backgroundJobsProvider.notifier);
    final picker = ref.read(filePickerServiceProvider);
    final engine = ref.read(engineServiceProvider);
    final toasts = ref.read(toastNoticesProvider.notifier);
    final dialog = ref.read(organizeDialogProvider.notifier);
    final handles = [
      for (final page in pages) widget.document.pageHandle(page),
    ];
    final deleteName = _delete ? l10n.extractDeleteStep : null;
    setState(() => _busy = true);
    try {
      if (_each) {
        final folder = await picker.chooseFolder();
        if (folder == null) return;
        // One file a page, named free in the folder; the plan's numbers are
        // the page numbers.
        final preview = await engine.splitPreview(
          id,
          kind: SplitKind.everyPages,
          amount: 1,
          template: l10n.extractFileName('{document}', '{n}'),
          folder: folder,
        );
        final wanted = pages.toSet();
        jobs.extractEachPage(
          id,
          name,
          [
            for (final file in preview.files)
              if (wanted.contains(file.first)) file,
          ],
          folder: folder,
          pages: handles,
          deleteName: deleteName,
        );
      } else {
        final output = await picker.saveFile(
          suggestedName:
              '${l10n.extractFileName(_stem, formatPageRange(pages, _format))}'
              '.pdf',
        );
        if (output == null) return;
        await jobs.extractPages(
          id,
          name,
          handles,
          output: output,
          deleteName: deleteName,
        );
      }
      dialog.close();
    } on EngineException catch (error) {
      showPageChangeFailure(toasts, error, name);
      dialog.close();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.ferman;
    final dialog = ref.read(organizeDialogProvider.notifier);
    final count = widget.document.pages.length;
    final pages = parsePageRange(_pages.text, count);
    final valid = pages != null && pages.isNotEmpty;
    final all = pages?.length == count;
    // Extract only reads, so it runs on a document that cannot change.
    final refusal = ref.watch(organizeRefusalProvider)?.call(l10n);
    return Dialog(
      title: l10n.extractTitle,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: valid && !_busy
              ? () => unawaited(_extract(pages, l10n))
              : null,
          child: Text(l10n.extractAction),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space3,
        children: [
          TextField(
            label: l10n.extractPages,
            size: FieldSize.sm,
            controller: _pages,
            error: valid ? null : l10n.organizeBadRange(_format.integer(count)),
            onChanged: (_) => setState(() {
              if (parsePageRange(_pages.text, count)?.length == count) {
                _delete = false;
              }
            }),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space1_5,
            children: [
              Radio<bool>(
                value: false,
                groupValue: _each,
                label: l10n.extractOneFile,
                onChanged: (value) => setState(() => _each = value),
              ),
              Radio<bool>(
                value: true,
                groupValue: _each,
                label: l10n.extractEachFile,
                onChanged: (value) => setState(() => _each = value),
              ),
            ],
          ),
          Checkbox(
            checked: _delete,
            label: l10n.extractDelete,
            // A document keeps a page: the engine refuses to delete them all.
            disabled: all || refusal != null,
            disabledReason: refusal ?? (all ? l10n.extractDeleteAll : null),
            onChanged: (value) => setState(() => _delete = value),
          ),
        ],
      ),
    );
  }
}
