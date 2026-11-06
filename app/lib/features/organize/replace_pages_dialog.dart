import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_range.dart';
import 'package:ferman/features/organize/page_source_field.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for G45's replace of [pages] (indices) of [document].
void showReplacePagesDialog(
  WidgetRef ref,
  OpenedDocument document,
  List<int> pages,
) => ref
    .read(organizeDialogProvider.notifier)
    .show(ReplacePagesDialog(document: document, pages: pages));

/// Replace pages (G45): the range in this document and in the file. The file
/// is read as a background job, whose change commits as one step.
class ReplacePagesDialog extends ConsumerStatefulWidget {
  /// The dialog.
  const new({required this.document, required this.pages, super.key});

  /// The document.
  final OpenedDocument document;

  /// The pages to replace at first, as indices.
  final List<int> pages;

  @override
  ConsumerState<ReplacePagesDialog> createState() => _ReplacePagesDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<OpenedDocument>('document', document))
      ..add(IterableProperty<int>('pages', pages));
  }
}

class _ReplacePagesDialogState extends ConsumerState<ReplacePagesDialog> {
  late final TextEditingController _these = TextEditingController(
    text: formatPageRange(
      widget.pages,
      RegionFormat.forRegion(ref.read(regionProvider).region),
    ),
  );
  final TextEditingController _range = TextEditingController();
  PageSource? _source;

  @override
  void dispose() {
    _these.dispose();
    _range.dispose();
    super.dispose();
  }

  void _replace(
    PageSource source,
    List<int> pages,
    List<int>? range,
    String name,
  ) {
    final engine = ref.read(engineServiceProvider);
    final jobs = ref.read(backgroundJobsProvider.notifier);
    final id = widget.document.id;
    final handles = [
      for (final page in pages) widget.document.pageHandle(page),
    ];
    final dialog = ref.read(organizeDialogProvider.notifier);
    afterSigned(
      ref,
      widget.document,
      () => jobs.pagesFromFile(
        BackgroundJobKind.replacePages,
        id,
        source.name,
        engine.replacePagesJob(
          id,
          handles,
          path: source.path,
          name: name,
          password: source.password,
          sourcePages: range,
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
    final count = widget.document.pages.length;
    final source = _source;
    final these = parsePageRange(_these.text, count);
    final range = source == null
        ? const <int>[]
        : parsePageRange(_range.text, source.pages);
    final coming = range == null || source == null
        ? null
        : (range.isEmpty ? source.pages : range.length);
    final going = these?.length ?? 0;
    final ready = source != null && going > 0 && range != null;
    return Dialog(
      title: l10n.replaceTitle,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: ready
              ? () => _replace(
                  source,
                  these!,
                  range.isEmpty ? null : range,
                  l10n.replaceStep,
                )
              : null,
          child: Text(l10n.replaceAction(going, format.integer(going))),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space3,
        children: [
          TextField(
            label: l10n.replaceThese,
            size: FieldSize.sm,
            controller: _these,
            error: these == null || these.isEmpty
                ? l10n.organizeBadRange(format.integer(count))
                : null,
            onChanged: (_) => setState(() {}),
          ),
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
          if (coming != null && going > 0 && coming != going)
            Text(
              coming < going ? l10n.replaceFewer : l10n.replaceMore,
              style: theme.typography.caption.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
