import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_position_field.dart';
import 'package:ferman/features/organize/page_range.dart';
import 'package:ferman/features/organize/page_source_field.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for G45's pages from a file, after the last of [pages] (indices) of
/// [document].
void showInsertFileDialog(
  WidgetRef ref,
  OpenedDocument document,
  List<int> pages,
) => ref
    .read(organizeDialogProvider.notifier)
    .show(InsertFileDialog(document: document, pages: pages));

/// Insert pages from file (G45): the file, its page range and the position.
/// The file is read as a background job, whose change commits as one step.
class InsertFileDialog extends ConsumerStatefulWidget {
  /// The dialog.
  const new({required this.document, required this.pages, super.key});

  /// The document.
  final OpenedDocument document;

  /// The pages the command acts on, as indices.
  final List<int> pages;

  @override
  ConsumerState<InsertFileDialog> createState() => _InsertFileDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<OpenedDocument>('document', document))
      ..add(IterableProperty<int>('pages', pages));
  }
}

class _InsertFileDialogState extends ConsumerState<InsertFileDialog> {
  final TextEditingController _range = TextEditingController();
  late PagePosition _position = PagePosition(
    page: widget.pages.lastOrNull ?? widget.document.pages.length - 1,
  );
  PageSource? _source;

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  void _insert(PageSource source, List<int>? range, String name) {
    final engine = ref.read(engineServiceProvider);
    final jobs = ref.read(backgroundJobsProvider.notifier);
    final id = widget.document.id;
    final after = _position.after(widget.document);
    final paper = ref.read(regionProvider).paperSize == PaperSize.letter
        ? ImagePaper.letter
        : ImagePaper.a4;
    final dialog = ref.read(organizeDialogProvider.notifier);
    afterSigned(
      ref,
      widget.document,
      () => jobs.pagesFromFile(
        BackgroundJobKind.insertPages,
        id,
        source.name,
        engine.insertPagesJob(
          id,
          path: source.path,
          after: after,
          paper: paper,
          name: name,
          password: source.password,
          pages: range,
        ),
      ),
    );
    dialog.close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.ferman;
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final dialog = ref.read(organizeDialogProvider.notifier);
    final source = _source;
    final range = source == null
        ? const <int>[]
        : parsePageRange(_range.text, source.pages);
    return Dialog(
      title: l10n.insertFileTitle,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: source == null || range == null
              ? null
              : () => _insert(
                  source,
                  range.isEmpty ? null : range,
                  l10n.insertFileStep,
                ),
          child: Text(l10n.insertFileAction),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space3,
        children: [
          PageSourceField(
            onChanged: (value) => setState(() => _source = value),
          ),
          TextField(
            label: l10n.sourceRange,
            size: FieldSize.sm,
            controller: _range,
            placeholder: l10n.sourceAllPages,
            error: source != null && range == null
                ? l10n.organizeBadRange(format.integer(source.pages))
                : null,
            onChanged: (_) => setState(() {}),
          ),
          PagePositionField(
            value: _position,
            count: widget.document.pages.length,
            onChanged: (position) => setState(() => _position = position),
          ),
        ],
      ),
    );
  }
}
