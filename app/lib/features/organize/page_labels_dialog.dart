import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_range.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for a6-5's page labels of [document].
void showPageLabelsDialog(WidgetRef ref, OpenedDocument document) => ref
    .read(organizeDialogProvider.notifier)
    .show(PageLabelsDialog(document: document));

String _roman(int value) {
  const steps = [
    (1000, 'M'),
    (900, 'CM'),
    (500, 'D'),
    (400, 'CD'),
    (100, 'C'),
    (90, 'XC'),
    (50, 'L'),
    (40, 'XL'),
    (10, 'X'),
    (9, 'IX'),
    (5, 'V'),
    (4, 'IV'),
    (1, 'I'),
  ];
  final out = StringBuffer();
  var left = value;
  for (final (amount, letters) in steps) {
    while (left >= amount) {
      out.write(letters);
      left -= amount;
    }
  }
  return out.toString();
}

/// The label [range] gives its page at [offset], as the PDF standard writes
/// it: A to Z, then AA, BB.
String pageLabelText(PageLabelRange range, int offset) {
  final number = range.first + offset;
  String letters() =>
      String.fromCharCode(0x41 + (number - 1) % 26) * ((number - 1) ~/ 26 + 1);
  final text = switch (range.style) {
    PageLabelStyle.none => '',
    PageLabelStyle.decimal => '$number',
    PageLabelStyle.romanUpper => _roman(number),
    PageLabelStyle.romanLower => LocaleCasing.root.lower(_roman(number)),
    PageLabelStyle.lettersUpper => letters(),
    PageLabelStyle.lettersLower => LocaleCasing.root.lower(letters()),
  };
  return '${range.prefix}$text';
}

/// a6-5's preview row for [ranges] of a document of [count] pages: the first
/// labels and the last of each range, "i ii iii … ix · 1 2 3 … 55".
String pageLabelPreview(List<PageLabelRange> ranges, int count) => [
  for (final (index, range) in ranges.indexed)
    () {
      final next = index + 1 < ranges.length ? ranges[index + 1].start : count;
      final pages = next - range.start;
      String label(int offset) => pageLabelText(range, offset);
      return pages <= 4
          ? [for (var i = 0; i < pages; i++) label(i)].join(' ')
          : '${label(0)} ${label(1)} ${label(2)} … ${label(pages - 1)}';
    }(),
].join(' · ');

/// One row of the range table, as typed.
@immutable
final class PageLabelRow {
  /// A row.
  const new({
    required this.pages,
    this.style = PageLabelStyle.decimal,
    this.prefix = '',
    this.first = 1,
  });

  /// "1–9".
  final String pages;

  /// How it writes its numbers.
  final PageLabelStyle style;

  /// What comes before each number.
  final String prefix;

  /// The number of its first page.
  final int first;
}

/// What is wrong with a range table (states a6-5 does not draw).
enum PageLabelProblem {
  /// A row's pages cannot be read.
  invalid,

  /// A row starts inside the one before it, or before it.
  overlap,

  /// A row goes past the last page.
  past,

  /// A page is in no row: the labels would run on through it unasked.
  uncovered,
}

/// [rows] as ranges for a document of [count] pages, or what is wrong and the
/// row (from 1) or page (from 1) it concerns.
({List<PageLabelRange>? ranges, PageLabelProblem? problem, int at})
checkPageLabels(List<PageLabelRow> rows, int count) {
  ({List<PageLabelRange>? ranges, PageLabelProblem? problem, int at}) wrong(
    PageLabelProblem problem,
    int at,
  ) => (ranges: null, problem: problem, at: at);
  final ranges = <PageLabelRange>[];
  var expected = 1;
  for (final (index, row) in rows.indexed) {
    final span = parsePageSpan(row.pages);
    if (span == null) return wrong(PageLabelProblem.invalid, index + 1);
    if (span.first < expected) {
      return wrong(PageLabelProblem.overlap, index + 1);
    }
    if (span.first > expected) {
      return wrong(PageLabelProblem.uncovered, expected);
    }
    if (span.last > count) return wrong(PageLabelProblem.past, index + 1);
    ranges.add(
      PageLabelRange(
        start: span.first - 1,
        style: row.style,
        prefix: row.prefix,
        first: row.first,
      ),
    );
    expected = span.last + 1;
  }
  if (rows.isNotEmpty && expected <= count) {
    return wrong(PageLabelProblem.uncovered, expected);
  }
  return (ranges: ranges, problem: null, at: 0);
}

/// Page labels (a6-5): a table of ranges in order, a preview row and the
/// disabled "Also print the numbers on the pages" (`pageMarks`). No row removes
/// the labels.
class PageLabelsDialog extends ConsumerStatefulWidget {
  /// The dialog.
  const new({required this.document, super.key});

  /// The document.
  final OpenedDocument document;

  /// a6-5's Pages column.
  static const double pagesWidth = 120;

  /// a6-5's Prefix column.
  static const double prefixWidth = 110;

  /// a6-5's Start at column.
  static const double startWidth = 90;

  /// a6-5's remove column.
  static const double removeWidth = 26;

  /// The largest Start at.
  static const double largestStart = 99999;

  @override
  ConsumerState<PageLabelsDialog> createState() => _PageLabelsDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<OpenedDocument>('document', document));
  }
}

class _Row {
  new(PageLabelRow row)
    : pages = TextEditingController(text: row.pages),
      prefix = TextEditingController(text: row.prefix),
      style = row.style,
      first = row.first;

  final TextEditingController pages;
  final TextEditingController prefix;
  PageLabelStyle style;
  int first;

  PageLabelRow get row => PageLabelRow(
    pages: pages.text,
    style: style,
    prefix: prefix.text,
    first: first,
  );

  void dispose() {
    pages.dispose();
    prefix.dispose();
  }
}

class _PageLabelsDialogState extends ConsumerState<PageLabelsDialog> {
  final List<_Row> _rows = [];
  bool _loaded = false;

  int get _count => widget.document.pages.length;

  RegionFormat get _format =>
      RegionFormat.forRegion(ref.read(regionProvider).region);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    var ranges = const <PageLabelRange>[];
    try {
      ranges = await ref
          .read(engineServiceProvider)
          .pageLabelRanges(widget.document.id);
    } on EngineException {
      // Starts from no labels.
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      for (final (index, range) in ranges.indexed) {
        final next = index + 1 < ranges.length
            ? ranges[index + 1].start
            : _count;
        _rows.add(
          _Row(
            PageLabelRow(
              pages: _span(range.start, next - 1),
              style: range.style,
              prefix: range.prefix,
              first: range.first,
            ),
          ),
        );
      }
      if (_rows.isEmpty) {
        _rows.add(_Row(PageLabelRow(pages: _span(0, _count - 1))));
      }
    });
  }

  String _span(int first, int last) => first == last
      ? _format.integer(first + 1)
      : '${_format.integer(first + 1)}–${_format.integer(last + 1)}';

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _apply(List<PageLabelRange> ranges, String name) {
    final engine = ref.read(engineServiceProvider);
    final id = widget.document.id;
    final dialog = ref.read(organizeDialogProvider.notifier);
    afterSigned(
      ref,
      widget.document,
      () => commitPageChange(
        ref,
        id,
        () => engine.setPageLabels(id, ranges, name),
      ),
    );
    dialog.close();
  }

  String? _problem(
    AppLocalizations l10n,
    PageLabelProblem? problem,
    int at,
  ) => switch (problem) {
    null => null,
    PageLabelProblem.invalid => l10n.labelsErrorInvalid(_format.integer(at)),
    PageLabelProblem.overlap => l10n.labelsErrorOverlap(_format.integer(at)),
    PageLabelProblem.past => l10n.labelsErrorPast(
      _format.integer(at),
      _format.integer(_count),
    ),
    PageLabelProblem.uncovered => l10n.labelsErrorUncovered(
      _format.integer(at),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.ferman;
    final region = ref.watch(regionProvider).region;
    final dialog = ref.read(organizeDialogProvider.notifier);
    final casing = LocaleCasing.of(context);
    final checked = checkPageLabels([for (final row in _rows) row.row], _count);
    final ranges = checked.ranges;
    final problem = _problem(l10n, checked.problem, checked.at);
    final gap = theme.space.space2_5;
    Widget head(String text) => Text(
      casing.upper(text),
      maxLines: 1,
      style: theme.typography.label.copyWith(color: theme.colors.textTertiary),
    );
    // Where the columns cannot fit, a range takes two lines and each field its
    // own heading.
    final phone = WindowMetrics.isPhone(context);
    Widget headed(String text, Widget field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: theme.space.space1,
      children: [head(text), field],
    );
    Widget pagesField(_Row row) => TextField(
      size: FieldSize.sm,
      semanticLabel: l10n.labelsColumnPages,
      controller: row.pages,
      onChanged: (_) => setState(() {}),
    );
    Widget styleField(_Row row) => Select<PageLabelStyle>(
      size: FieldSize.sm,
      semanticLabel: l10n.labelsColumnStyle,
      value: row.style,
      options: [
        SelectOption(
          value: PageLabelStyle.romanLower,
          label: l10n.labelsStyleRomanLower,
        ),
        SelectOption(
          value: PageLabelStyle.romanUpper,
          label: l10n.labelsStyleRomanUpper,
        ),
        SelectOption(
          value: PageLabelStyle.decimal,
          label: l10n.labelsStyleDecimal,
        ),
        SelectOption(
          value: PageLabelStyle.lettersLower,
          label: l10n.labelsStyleLettersLower,
        ),
        // Not on the board; PDF has it, and a document's own
        // labels must survive this dialog.
        SelectOption(
          value: PageLabelStyle.lettersUpper,
          label: l10n.labelsStyleLettersUpper,
        ),
        SelectOption(value: PageLabelStyle.none, label: l10n.labelsStyleNone),
      ],
      onChanged: (value) => setState(() => row.style = value),
    );
    Widget prefixField(_Row row) => TextField(
      size: FieldSize.sm,
      semanticLabel: l10n.labelsColumnPrefix,
      controller: row.prefix,
      placeholder: l10n.labelsPrefixNone,
      onChanged: (_) => setState(() {}),
    );
    Widget startField(_Row row) => FmNumber(
      region: region,
      semanticLabel: l10n.labelsColumnStart,
      value: row.first.toDouble(),
      precision: 0,
      unit: null,
      width: PageLabelsDialog.startWidth,
      min: 1,
      max: PageLabelsDialog.largestStart,
      onChanged: (value) => setState(() => row.first = value.round()),
    );
    Widget removeButton(_Row row) => IconButton(
      icon: IconName.trash2,
      label: l10n.labelsRemoveRange,
      size: IconButtonSize.sm,
      onPressed: () => setState(() {
        _rows.remove(row);
        row.dispose();
      }),
    );
    return Dialog(
      size: DialogSize.lg,
      title: l10n.labelsTitle,
      description: l10n.labelsDescription,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: _loaded && ranges != null
              ? () => _apply(ranges, l10n.labelsStep)
              : null,
          child: Text(l10n.labelsApply),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          if (!phone)
            Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.space.space1,
              ),
              child: Row(
                spacing: gap,
                children: [
                  SizedBox(
                    width: PageLabelsDialog.pagesWidth,
                    child: head(l10n.labelsColumnPages),
                  ),
                  Expanded(child: head(l10n.labelsColumnStyle)),
                  SizedBox(
                    width: PageLabelsDialog.prefixWidth,
                    child: head(l10n.labelsColumnPrefix),
                  ),
                  SizedBox(
                    width: PageLabelsDialog.startWidth,
                    child: head(l10n.labelsColumnStart),
                  ),
                  const SizedBox(width: PageLabelsDialog.removeWidth),
                ],
              ),
            ),
          for (final row in _rows)
            DecoratedBox(
              key: ObjectKey(row),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colors.borderSubtle,
                    width: theme.border.borderWidth,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  vertical: theme.space.space2,
                  horizontal: theme.space.space1,
                ),
                child: phone
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: gap,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            spacing: gap,
                            children: [
                              Expanded(
                                child: headed(
                                  l10n.labelsColumnPages,
                                  pagesField(row),
                                ),
                              ),
                              Expanded(
                                child: headed(
                                  l10n.labelsColumnPrefix,
                                  prefixField(row),
                                ),
                              ),
                              removeButton(row),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            spacing: gap,
                            children: [
                              Expanded(
                                child: headed(
                                  l10n.labelsColumnStyle,
                                  styleField(row),
                                ),
                              ),
                              headed(l10n.labelsColumnStart, startField(row)),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        spacing: gap,
                        children: [
                          SizedBox(
                            width: PageLabelsDialog.pagesWidth,
                            child: pagesField(row),
                          ),
                          Expanded(child: styleField(row)),
                          SizedBox(
                            width: PageLabelsDialog.prefixWidth,
                            child: prefixField(row),
                          ),
                          startField(row),
                          removeButton(row),
                        ],
                      ),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Button(
              size: ButtonSize.sm,
              variant: ButtonVariant.ghost,
              icon: IconName.plus,
              onPressed: () => setState(
                () => _rows.add(_Row(const PageLabelRow(pages: ''))),
              ),
              child: Text(l10n.labelsAddRange),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surfaceSunken,
              borderRadius: BorderRadius.circular(theme.radius.radiusMd),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                vertical: gap,
                horizontal: theme.space.space3,
              ),
              child: Row(
                spacing: theme.space.space2,
                children: [
                  Text(
                    l10n.labelsPreview,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ranges == null
                          ? ''
                          : bidiIsolate(pageLabelPreview(ranges, _count)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.mono.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (problem != null)
            Text(
              problem,
              style: theme.typography.caption.copyWith(
                color: theme.colors.danger,
              ),
            ),
          Checkbox(
            checked: false,
            label: l10n.labelsPrint,
            description: l10n.labelsPrintNote,
            disabled: true,
            disabledReason: Feature.pageMarks.disabledReason(context),
          ),
        ],
      ),
    );
  }
}
