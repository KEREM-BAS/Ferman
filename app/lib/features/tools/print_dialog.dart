import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_range.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/tools/printed_page.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/platform/print_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens a9-6's Print dialog for the open document; nothing without one.
void showPrintDialog(WidgetRef ref) {
  final document = ref.read(openDocumentProvider);
  if (document == null) return;
  ref.read(organizeDialogProvider.notifier).show(PrintDialog(document));
}

/// Prints [pages] of [document], by handle (all when empty), through the
/// system's print dialog (decision 29): the dialog first, then each page
/// rendered in memory and handed over once the one before is drawn. Says how
/// it went in a toast; a print the person cancelled says nothing.
Future<void> printDocument(
  WidgetRef ref,
  OpenedDocument document, {
  List<int> pages = const [],
  bool includeComments = true,
  bool fit = true,
}) async {
  final printer = ref.read(printServiceProvider);
  final engine = ref.read(engineServiceProvider);
  final toasts = ref.read(toastNoticesProvider.notifier);
  final name =
      ref
          .read(shellDocumentsProvider)
          .documents
          .where((tab) => tab.document?.id == document.id)
          .firstOrNull
          ?.name ??
      '';
  final count = pages.isEmpty ? document.pages.length : pages.length;
  if (!await printer.begin(name: name, pages: count, fit: fit)) return;
  EngineException? failure;
  var sent = true;
  try {
    await for (final page in engine.printPages(
      document.id,
      pages: pages,
      includeComments: includeComments,
    )) {
      if (!await printer.page(page)) {
        sent = false;
        break;
      }
    }
  } on EngineException catch (error) {
    failure = error;
  }
  if (failure == null && sent) {
    await printer.end();
    toasts.show(
      tone: ToastTone.success,
      title: (l10n) => l10n.printSent(bidiIsolate(name)),
    );
    return;
  }
  await printer.abort();
  toasts.show(
    tone: ToastTone.danger,
    title: (l10n) => l10n.printFailed(bidiIsolate(name)),
    message: failure == null
        ? null
        : (l10n) => engineMessage(l10n, failure!, bidiIsolate(name)),
  );
}

/// a9-6 as question 3 of the M4 plan says: the preview, which is the real
/// output, Pages, Scale and Include work; Layout stays on Pages (booklet and
/// poster are P5); Printer, Copies and Both sides are the system dialog's,
/// which Print opens, and "Use system dialog…" opens it for the whole
/// document as it is.
class PrintDialog extends ConsumerStatefulWidget {
  /// The dialog for [document].
  const new(this.document, {super.key});

  /// The document to print.
  final OpenedDocument document;

  @override
  ConsumerState<PrintDialog> createState() => _PrintDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<OpenedDocument>('document', document));
  }
}

/// a9-6's measures that are not tokens.
abstract final class _PrintLayout {
  /// The options column (`grid-template-columns:300px …`).
  static const double optionsWidth = 300;

  /// The two columns' gap (`gap:24px`).
  static const double columnsGap = 24;

  /// The options' gap (`gap:12px`).
  static const double optionsGap = 12;

  /// Copies and Pages' gap (`gap:10px`).
  static const double pairGap = 10;

  /// Copies' width (`width="{{ 140 }}"`).
  static const double copiesWidth = 140;

  /// The preview's padding (`padding:14px`).
  static const double previewPadding = 14;

  /// The preview page's width: DocKira's 794 px at `zoom:0.36`.
  static const double pageWidth = 794 * 0.36;
}

class _PrintDialogState extends ConsumerState<PrintDialog> {
  final TextEditingController _pages = TextEditingController();
  bool _fit = true;
  bool _comments = true;

  /// The previewed sheet, from 0 among the pages printed.
  int _sheet = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The pages typed, as indices; all when empty, null when not valid.
  List<int>? get _chosen {
    final count = widget.document.pages.length;
    final pages = parsePageRange(_pages.text, count);
    if (pages == null) return null;
    return pages.isEmpty ? [for (var i = 0; i < count; i++) i] : pages;
  }

  void _print(List<int> indices, {required bool system}) {
    final document = widget.document;
    final all = system || indices.length == document.pages.length;
    ref.read(organizeDialogProvider.notifier).close();
    unawaited(
      printDocument(
        ref,
        document,
        pages: all
            ? const []
            : [for (final i in indices) document.pageHandle(i)],
        includeComments: system || _comments,
        fit: system || _fit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final region = ref.watch(regionProvider);
    final format = RegionFormat.forRegion(region.region);
    final dialog = ref.read(organizeDialogProvider.notifier);
    final document = widget.document;
    final name = ref.watch(shellDocumentsProvider).active?.name ?? '';
    final chosen = _chosen;
    final comments = ref.watch(documentThreadsProvider).length;
    final system = Feature.printSystemOptions.disabledReason(context);
    final more = Feature.printMoreOptions.disabledReason(context);
    final layouts = Feature.printLayouts.disabledReason(context);
    final sheet = chosen == null || chosen.isEmpty
        ? null
        : _sheet.clamp(0, chosen.length - 1);
    Widget labelled(String label, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space1_5,
      children: [Field.labelOf(context, label), child],
    );
    return Dialog(
      title: l10n.printTitle(bidiIsolate(name)),
      size: DialogSize.lg,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      footerStart: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () => _print(const [], system: true),
        child: Text(l10n.printSystemDialog),
      ),
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          icon: IconName.printer,
          onPressed: chosen == null
              ? null
              : () => _print(chosen, system: false),
          child: Text(l10n.printAction),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _PrintLayout.columnsGap,
        children: [
          SizedBox(
            width: _PrintLayout.optionsWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _PrintLayout.optionsGap,
              children: [
                Select<String>(
                  label: l10n.printPrinter,
                  size: FieldSize.sm,
                  icon: IconName.printer,
                  value: 'system',
                  options: [
                    SelectOption(
                      value: 'system',
                      label: l10n.printPrinterSystem,
                    ),
                  ],
                  disabled: true,
                  disabledReason: system,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: _PrintLayout.pairGap,
                  children: [
                    Tooltip(
                      message: system,
                      child: FmNumber(
                        region: region.region,
                        label: l10n.printCopies,
                        value: 1,
                        precision: 0,
                        unit: null,
                        width: _PrintLayout.copiesWidth,
                        disabled: true,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        size: FieldSize.sm,
                        label: l10n.printPages,
                        placeholder: l10n.printPagesAll,
                        controller: _pages,
                        error: chosen == null
                            ? l10n.organizeBadRange(
                                format.integer(document.pages.length),
                              )
                            : null,
                        onChanged: (_) => setState(() => _sheet = 0),
                      ),
                    ),
                  ],
                ),
                labelled(
                  l10n.printLayout,
                  SegmentedControl<String>(
                    semanticLabel: l10n.printLayout,
                    fullWidth: true,
                    value: 'pages',
                    options: [
                      SegmentOption(
                        value: 'pages',
                        label: l10n.printLayoutPages,
                      ),
                      SegmentOption(
                        value: 'booklet',
                        label: l10n.printLayoutBooklet,
                        disabled: true,
                        disabledReason: layouts,
                      ),
                      SegmentOption(
                        value: 'poster',
                        label: l10n.printLayoutPoster,
                        disabled: true,
                        disabledReason: layouts,
                      ),
                    ],
                    onChanged: (_) {},
                  ),
                ),
                Select<String>(
                  label: l10n.printBothSides,
                  size: FieldSize.sm,
                  value: 'long',
                  options: [
                    SelectOption(value: 'long', label: l10n.printLongEdge),
                    SelectOption(value: 'short', label: l10n.printShortEdge),
                    SelectOption(value: 'off', label: l10n.printOneSide),
                  ],
                  disabled: true,
                  disabledReason: system,
                ),
                Select<bool?>(
                  label: l10n.printScale,
                  size: FieldSize.sm,
                  value: _fit,
                  options: [
                    SelectOption(value: true, label: l10n.printScaleFit),
                    SelectOption(value: false, label: l10n.printScaleActual),
                    SelectOption(
                      value: null,
                      label: l10n.printScaleCustom,
                      disabled: true,
                      disabledReason: more,
                    ),
                  ],
                  onChanged: (fit) {
                    if (fit != null) setState(() => _fit = fit);
                  },
                ),
                Field.labelOf(context, l10n.printInclude),
                Checkbox(
                  checked: _comments,
                  label: l10n.printComments(comments, format.integer(comments)),
                  onChanged: (value) => setState(() => _comments = value),
                ),
                // Form fields always print since B203.
                Checkbox(
                  checked: true,
                  label: l10n.printFormFields,
                  disabled: true,
                  disabledReason: more,
                ),
                Checkbox(
                  checked: false,
                  label: l10n.printHiddenLayers,
                  disabled: true,
                  disabledReason: more,
                ),
              ],
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.surfaceSunken,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusMd),
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(
                  _PrintLayout.previewPadding,
                ),
                child: Column(
                  spacing: _PrintLayout.pairGap,
                  children: [
                    if (sheet != null)
                      SizedBox(
                        width: _PrintLayout.pageWidth,
                        child: PrintedPage(
                          document: document.id,
                          handle: document.pageHandle(chosen![sheet]),
                          page: document.pages[chosen[sheet]],
                          includeComments: _comments,
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: theme.space.space1_5,
                      children: [
                        IconButton(
                          icon: IconName.chevronLeft,
                          label: l10n.printPreviousSheet,
                          size: IconButtonSize.xs,
                          onPressed: sheet == null || sheet == 0
                              ? null
                              : () => setState(() => _sheet = sheet - 1),
                        ),
                        Text(
                          l10n.printSheetOf(
                            format.integer((sheet ?? 0) + 1),
                            format.integer(chosen?.length ?? 0),
                            switch (region.paperSize) {
                              PaperSize.a4 => l10n.regionPaperA4,
                              PaperSize.letter => l10n.regionPaperLetter,
                            },
                          ),
                          style: theme.typography.caption.copyWith(
                            color: theme.colors.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        IconButton(
                          icon: IconName.chevronRight,
                          label: l10n.printNextSheet,
                          size: IconButtonSize.xs,
                          onPressed:
                              sheet == null || sheet >= chosen!.length - 1
                              ? null
                              : () => setState(() => _sheet = sheet + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
