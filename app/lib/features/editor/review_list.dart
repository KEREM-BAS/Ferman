import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'review_list.g.dart';

/// a3-12's filter.
enum ReviewFilter {
  /// Every row.
  all,

  /// The changes to text.
  text,

  /// The font rows.
  fonts,

  /// The kept warnings and the signature row.
  warnings,
}

/// What a row of the review list says.
enum ReviewRowKind {
  /// A block's text changed.
  text,

  /// Characters were set in another font.
  font,

  /// "Keep and warn" hides lines past the block's frame.
  warning,
}

/// One row of the review list: part of a history step.
@immutable
final class ReviewRow {
  /// The row of step [step].
  const new({
    required this.step,
    required this.kind,
    required this.time,
    this.page,
    this.from = '',
    this.to = '',
    this.hiddenLines = 0,
    this.name = '',
  });

  /// The history step it belongs to, from 0.
  final int step;

  /// What it says.
  final ReviewRowKind kind;

  /// When the step was committed.
  final DateTime time;

  /// The page, from 0; null for a step restored from the recovery files,
  /// whose block is not known.
  final int? page;

  /// What stood there, or the font it was in; empty for an addition.
  final String from;

  /// What stands there now, or the font it is in.
  final String to;

  /// The lines a warning row counts.
  final int hiddenLines;

  /// The step's name, which a restored step shows in place of its page.
  final String name;
}

/// The words of [before] and [after] that differ, as "18.500 TL" and
/// "19.500 TL" in a block of many lines; line feeds read as spaces.
(String, String) changedWords(String before, String after) {
  final a = before.runes.toList();
  final b = after.runes.toList();
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var end = 0;
  while (end < a.length - start &&
      end < b.length - start &&
      a[a.length - 1 - end] == b[b.length - 1 - end]) {
    end++;
  }
  bool space(int rune) => rune == 0x20 || rune == 0x0A;
  while (start > 0 && !space(a[start - 1])) {
    start--;
  }
  while (end > 0 && !space(a[a.length - end])) {
    end--;
  }
  String part(List<int> runes) =>
      String.fromCharCodes(runes.sublist(start, runes.length - end))
          .replaceAll('\n', ' ')
          .trim();
  return (part(a), part(b));
}

bool _sameText(String before, String after) =>
    before.replaceAll('\n', ' ') == after.replaceAll('\n', ' ');

/// The arrow between what stood and what stands, pointing the way the text
/// reads: bidi does not mirror arrows.
String _arrow(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl ? ' ← ' : ' → ';

const double _rowTextSize = 12.5;
const double _rowTextHeight = 1.45;

/// a3-12's `font:400 12.5px/1.45 var(--font-doc-sample)`: a row quotes the
/// document in the document's face.
TextStyle _rowStyle(FermanTheme theme) {
  final sample = theme.typeScale.fontDocSample;
  return TextStyle(
    fontFamily: sample.family,
    fontFamilyFallback: sample.fallback,
    fontSize: _rowTextSize,
    height: _rowTextHeight,
    color: theme.colors.textPrimary,
  );
}

/// Every row of [history]'s edits that still count, oldest first: a text row,
/// then a font row per font, then a warning row for lines left hidden. A step
/// reverted or undone has none, and a revert is no edit. A step's page is
/// where [document] has it now; null once it is gone.
List<ReviewRow> reviewRows(EditHistory history, OpenedDocument? document) => [
  for (final index in history.live)
    ...() {
      final step = history.steps[index];
      final page = switch (step.pages.firstOrNull) {
        final handle? => document?.pageIndexOf(handle),
        null => null,
      };
      // A style, a move or a language changes no word: the row names the step.
      final (from, to) = _sameText(step.before, step.after)
          ? ('', '')
          : changedWords(step.before, step.after);
      final fonts = <String>{};
      return [
        ReviewRow(
          step: index,
          kind: ReviewRowKind.text,
          time: step.time,
          page: page,
          from: from,
          to: to,
          name: step.name,
        ),
        for (final substitution in step.substitutions)
          if (fonts.add(substitution.toFont))
            ReviewRow(
              step: index,
              kind: ReviewRowKind.font,
              time: step.time,
              page: page,
              from: substitution.fromFont,
              to: substitution.toFont,
              name: step.name,
            ),
        if (step.hiddenLines > 0)
          ReviewRow(
            step: index,
            kind: ReviewRowKind.warning,
            time: step.time,
            page: page,
            hiddenLines: step.hiddenLines,
            name: step.name,
          ),
      ];
    }(),
];

/// Where the row is, as a3-12's first line says it.
String _where(AppLocalizations l10n, RegionFormat format, ReviewRow row) {
  final page = row.page;
  if (page == null) return row.name;
  final number = format.integer(page + 1);
  return switch (row.kind) {
    ReviewRowKind.text => l10n.reviewWhereText(number),
    ReviewRowKind.font => l10n.reviewWhereFont(number),
    ReviewRowKind.warning => l10n.reviewWhereWarning(number),
  };
}

String _keptWarning(
  AppLocalizations l10n,
  RegionFormat format,
  ReviewRow row,
) => l10n.reviewKeptWarning(row.hiddenLines, format.integer(row.hiddenLines));

/// The page of the one signature the edits invalidated; null with several
/// signers, whose row names no page.
int? _signaturePage(OpenedDocument? document) {
  final signed = [
    for (final signature in document?.signatures ?? const <Signature>[])
      if (signature.signed) signature,
  ];
  return signed.length == 1 ? signed.first.page : null;
}

/// The people whose signatures the edits invalidated, as a3-12's row says it.
String _signatureRow(AppLocalizations l10n, OpenedDocument? document) {
  final signers = [
    for (final signature in document?.signatures ?? const <Signature>[])
      if (signature.signed) signature.signer,
  ];
  return switch (signers) {
    [final String signer] => l10n.signedReviewRow(bidiIsolate(signer)),
    _ => l10n.signedReviewRowOther,
  };
}

/// A question the review list asks (a3-12b).
@immutable
sealed class ReviewQuestion {
  const new();
}

/// "Revert all N edits?"
final class RevertAllQuestion extends ReviewQuestion {
  /// The question about [count] edits.
  const new(this.count);

  /// The edits that still count.
  final int count;
}

/// "Also revert the edit that depends on it?"
final class DependentsQuestion extends ReviewQuestion {
  /// The question about reverting [step], on which [dependents] build.
  const new(this.step, this.dependents);

  /// The step asked for, from 0.
  final int step;

  /// The later steps that go with it.
  final List<int> dependents;
}

/// The review list: whether it shows, what it asks, the row Go to selected and
/// whether the last export failed.
@immutable
final class ReviewListState {
  /// The state.
  const new({
    this.open = false,
    this.asking,
    this.selected,
    this.exportFailed = false,
  });

  /// Whether the list shows in the right panel's place.
  final bool open;

  /// The question waiting for an answer, or null.
  final ReviewQuestion? asking;

  /// The step of the row Go to last went to, or null.
  final int? selected;

  /// Whether the last Export list failed.
  final bool exportFailed;
}

/// Review edits (a3-12, a3-12b), as `reviewListProvider`: reverts go through
/// `DocumentEditor`, the list itself comes from its history, so it follows
/// every edit, undo and revert and clears with the document (G42).
@Riverpod(keepAlive: true)
class ReviewList extends _$ReviewList {
  @override
  ReviewListState build() {
    // A row, or a failed export, of one document means nothing on the next.
    ref.listen(
      openDocumentProvider.select((document) => document?.id),
      // The document can change while a widget builds.
      (_, _) => unawaited(
        Future.microtask(() {
          if (ref.mounted) state = ReviewListState(open: state.open);
        }),
      ),
    );
    return const ReviewListState();
  }

  DocumentEditor get _editor => ref.read(documentEditorProvider.notifier);

  /// Shows or hides the list.
  void show({required bool open}) => state = ReviewListState(open: open);

  /// Reverts step [step] as the history step [name], or asks when later
  /// steps depend on it.
  Future<void> revert(int step, String name) async {
    final dependents = await _editor.revert(step, name);
    if (dependents.isEmpty) return;
    state = ReviewListState(
      open: state.open,
      selected: state.selected,
      asking: DependentsQuestion(step, dependents),
    );
  }

  /// Asks before Revert all.
  void askRevertAll(int count) => state = ReviewListState(
    open: state.open,
    selected: state.selected,
    asking: RevertAllQuestion(count),
  );

  /// Closes the question: nothing changes.
  void cancel() =>
      state = ReviewListState(open: state.open, selected: state.selected);

  /// "Revert both": the step asked about and those that depend on it.
  Future<void> revertWithDependents(int step, String name) async {
    cancel();
    await _editor.revert(step, name, withDependents: true);
  }

  /// "Revert N edits".
  Future<void> revertAll(String name) async {
    cancel();
    await _editor.revertAll(name);
  }

  /// Go to: shows [row]'s page and selects its block, whose editor opens.
  Future<void> goTo(ReviewRow row, String stepName) async {
    state = ReviewListState(open: state.open, selected: row.step);
    final page = row.page;
    if (page == null) return;
    ref.read(viewerProvider.notifier).goToPage(page);
    await _editor.select(row.step, stepName);
  }

  /// Export list: writes [text] where the save panel says, through the
  /// engine's safe write (ADR 0008).
  Future<void> export(String suggestedName, String text) async {
    final path = await ref
        .read(filePickerServiceProvider)
        .saveFile(suggestedName: suggestedName);
    if (path == null) return;
    final access = ref.read(fileAccessProvider);
    final staging = await access.staging(path);
    var failed = false;
    try {
      final staged = await ref
          .read(engineServiceProvider)
          .saveText(path, text, staging: staging);
      failed = staged != null && await access.swapIn(staged, path) != null;
    } on EngineException {
      failed = true;
      if (staging != null) await access.discardStaging(staging);
    }
    state = ReviewListState(
      open: state.open,
      selected: state.selected,
      exportFailed: failed,
    );
  }
}

/// Shows the review list in Edit, in the right panel's place, opening that
/// place when it was closed: the tool row's Review edits, a3-16b's bar and
/// a3-9's "Review the marked cells".
void showReviewList(WidgetRef ref) {
  ref.read(shellModeProvider.notifier).select(FermanMode.edit);
  ref.read(editHistoryOpenProvider.notifier).show(open: false);
  ref.read(reviewListProvider.notifier).show(open: true);
  if (!ref.read<ShellPanels>(shellPanelsProvider).panel) {
    toggleShellSide(ref, ShellSide.panel);
  }
}

/// a3-12 and a3-12b: the 320 px panel in the right panel's place. The heading
/// with the count and Close review, the filter, a row per change with where,
/// when, before and after, Go to and Revert, and Revert all… and Export list…
/// at the bottom. With no change the shared EmptyState shows and both are
/// disabled.
class ReviewListPanel extends ConsumerWidget {
  /// The panel, [width] wide (null: [boardWidth]).
  const new({super.key, this.width});

  /// The width the user dragged the right panel to (B094).
  final double? width;

  /// a3-12: `width:320px`, wider than the right panel's `--panel-w`.
  static const double boardWidth = 320;

  /// a3-12: the heading's `height: 40px`.
  static const double headingHeight = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ReviewBody(width: width);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width, defaultValue: null));
  }
}

class _ReviewBody extends ConsumerStatefulWidget {
  const new({this.width});

  final double? width;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width, defaultValue: null));
  }
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  ReviewFilter _filter = ReviewFilter.all;

  /// The list as a text file: a line per row, its fields separated by tabs.
  String _exported(
    AppLocalizations l10n,
    RegionFormat format,
    EditHistory history,
    List<ReviewRow> rows,
    OpenedDocument? document,
  ) {
    final line = StringBuffer();
    if (history.signatureInvalidated) {
      line.writeln(_signatureRow(l10n, document));
    }
    for (final row in rows) {
      final to = row.kind == ReviewRowKind.warning
          ? _keptWarning(l10n, format, row)
          : row.from.isEmpty && row.to.isEmpty
          ? row.name
          : row.to;
      line.writeln(
        [
          _where(l10n, format, row),
          format.time(row.time),
          row.from,
          to,
        ].join('\t'),
      );
    }
    return line.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final history = ref.watch(documentEditorProvider).history;
    final review = ref.watch(reviewListProvider);
    final list = ref.read(reviewListProvider.notifier);
    final tab = ref.watch(shellDocumentsProvider).active;
    final document = tab?.document;
    final rows = reviewRows(history, document);
    final count = history.live.length;
    final signature = history.signatureInvalidated;
    final shown = [
      for (final row in rows)
        if (switch (_filter) {
          ReviewFilter.all => true,
          ReviewFilter.text => row.kind == ReviewRowKind.text,
          ReviewFilter.fonts => row.kind == ReviewRowKind.font,
          ReviewFilter.warnings => row.kind == ReviewRowKind.warning,
        })
          row,
    ];
    final showSignature =
        signature &&
        (_filter == ReviewFilter.all || _filter == ReviewFilter.warnings);
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.shellReviewEdits,
      child: Container(
        width: widget.width ?? ReviewListPanel.boardWidth,
        decoration: BoxDecoration(
          color: theme.colors.surfacePanel,
          border: BorderDirectional(start: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: ReviewListPanel.headingHeight,
              padding: EdgeInsetsDirectional.only(
                start: theme.space.space3,
                end: theme.space.space1_5,
              ),
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: Row(
                spacing: theme.space.space2,
                children: [
                  Expanded(
                    child: Row(
                      spacing: theme.space.space2,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.shellReviewEdits,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.panelTitle.copyWith(
                              color: theme.colors.textPrimary,
                            ),
                          ),
                        ),
                        if (count > 0)
                          Badge(
                            label: format.integer(count),
                            tone: BadgeTone.edited,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: IconName.x,
                    label: l10n.reviewClose,
                    size: IconButtonSize.xs,
                    onPressed: () => list.show(open: false),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.space.space2_5,
                vertical: theme.space.space2,
              ),
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: SegmentedControl<ReviewFilter>(
                fullWidth: true,
                semanticLabel: l10n.reviewShow,
                value: _filter,
                onChanged: (filter) => setState(() => _filter = filter),
                options: [
                  SegmentOption(
                    value: ReviewFilter.all,
                    label: l10n.reviewFilterAll,
                  ),
                  SegmentOption(
                    value: ReviewFilter.text,
                    label: l10n.reviewFilterText,
                  ),
                  SegmentOption(
                    value: ReviewFilter.fonts,
                    label: l10n.reviewFilterFonts,
                  ),
                  SegmentOption(
                    value: ReviewFilter.warnings,
                    label: l10n.reviewFilterWarnings,
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty && !signature
                  ? Align(
                      alignment: AlignmentDirectional.topCenter,
                      child: EmptyState(
                        icon: IconName.listChecks,
                        title: l10n.reviewEmptyTitle,
                        body: l10n.reviewEmptyBody,
                      ),
                    )
                  : ListView(
                      padding: EdgeInsetsDirectional.all(theme.space.space2),
                      children: [
                        if (showSignature)
                          _SignatureRow(
                            label: _signatureRow(l10n, document),
                            page: _signaturePage(document),
                            locale: documentLocale(document?.language),
                            time: history.steps.isEmpty
                                ? null
                                : history.steps.first.time,
                          ),
                        for (final row in shown)
                          _Row(
                            key: ValueKey((row.step, row.kind, row.to)),
                            row: row,
                            selected: review.selected == row.step,
                            locale: documentLocale(document?.language),
                          ),
                      ],
                    ),
            ),
            if (review.exportFailed)
              Padding(
                padding: EdgeInsetsDirectional.all(theme.space.space2),
                child: Banner(
                  tone: BannerTone.danger,
                  title: l10n.reviewExportFailed,
                ),
              ),
            Container(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.space.space3,
                vertical: theme.space.space2_5,
              ),
              decoration: BoxDecoration(border: Border(top: line)),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: theme.space.space2,
                runSpacing: theme.space.space1_5,
                children: [
                  Button(
                    size: ButtonSize.sm,
                    variant: ButtonVariant.ghost,
                    icon: IconName.rotateCcw,
                    disabledReason: l10n.reviewNothing,
                    onPressed: count == 0
                        ? null
                        : () => list.askRevertAll(count),
                    child: Text(l10n.reviewRevertAll),
                  ),
                  Button(
                    size: ButtonSize.sm,
                    icon: IconName.fileOutput,
                    disabledReason: l10n.reviewNothing,
                    onPressed: rows.isEmpty && !signature
                        ? null
                        : () {
                            final name = tab?.name ?? '';
                            final dot = name.lastIndexOf('.');
                            final stem = dot > 0
                                ? name.substring(0, dot)
                                : name;
                            unawaited(
                              list.export(
                                '${l10n.reviewExportName(stem)}.txt',
                                _exported(
                                  l10n,
                                  format,
                                  history,
                                  rows,
                                  document,
                                ),
                              ),
                            );
                          },
                    child: Text(l10n.reviewExportList),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card a row is drawn on (a3-12's `padding:10px`, `--radius-md`).
class _Card extends StatelessWidget {
  const new({required this.border, required this.children});

  final Color border;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: theme.space.space1_5),
      child: Semantics(
        container: true,
        child: Container(
          padding: EdgeInsetsDirectional.all(theme.space.space2_5),
          decoration: BoxDecoration(
            color: theme.colors.surfaceRaised,
            border: Border.all(color: border, width: theme.border.borderWidth),
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusMd),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space1_5,
            children: children,
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('border', border));
  }
}

/// The card's first line: the icon, where and when.
class _Heading extends ConsumerWidget {
  const new({
    required this.icon,
    required this.color,
    required this.where,
    this.time,
  });

  final IconName icon;
  final Color color;
  final String where;
  final DateTime? time;

  /// a3-12: `size="{{ 14 }}"`.
  static const double iconSize = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final style = theme.typography.caption.copyWith(
      color: theme.colors.textTertiary,
    );
    final time = this.time;
    return Row(
      spacing: theme.space.space2,
      children: [
        Icon(icon, size: iconSize, color: color),
        Expanded(child: Text(where, style: style)),
        if (time != null)
          Text(
            format.time(time),
            style: style.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<IconName>('icon', icon))
      ..add(ColorProperty('color', color))
      ..add(StringProperty('where', where))
      ..add(DiagnosticsProperty<DateTime?>('time', time));
  }
}

/// a3-12's signature row (G35, G42), at the top: it follows from the edits, so
/// Revert has no meaning on it, and it goes when no change stands. With one
/// signer it names the page and Go to shows it.
class _SignatureRow extends ConsumerWidget {
  const new({required this.label, this.time, this.page, this.locale});

  final String label;
  final DateTime? time;

  /// The signature's page, from 0; null when the row covers several.
  final int? page;

  /// The document's language.
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final page = this.page;
    return _Card(
      border: theme.colors.warningBorder,
      children: [
        _Heading(
          icon: IconName.signature,
          color: theme.colors.warningSolid,
          where: page == null
              ? l10n.reviewWhereSignature
              : l10n.reviewWhereSignaturePage(format.integer(page + 1)),
          time: time,
        ),
        Text(
          label,
          locale: locale,
          style: _rowStyle(theme)
              .copyWith(backgroundColor: theme.pageColors.diffAdded),
        ),
        if (page != null)
          Row(
            children: [
              Button(
                size: ButtonSize.sm,
                variant: ButtonVariant.ghost,
                icon: IconName.arrowRight,
                onPressed: () =>
                    ref.read(viewerProvider.notifier).goToPage(page),
                child: Text(l10n.reviewGoTo),
              ),
            ],
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(DiagnosticsProperty<DateTime?>('time', time))
      ..add(IntProperty('page', page))
      ..add(DiagnosticsProperty<Locale?>('locale', locale));
  }
}

class _Row extends ConsumerWidget {
  const new({
    required this.row,
    required this.selected,
    this.locale,
    super.key,
  });

  final ReviewRow row;
  final bool selected;

  /// The document's language.
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final list = ref.read(reviewListProvider.notifier);
    final warning = row.kind == ReviewRowKind.warning;
    final style = _rowStyle(theme);
    final noWords = !warning && row.from.isEmpty && row.to.isEmpty;
    return _Card(
      border: warning
          ? colors.warningBorder
          : selected
          ? colors.accent
          : colors.borderSubtle,
      children: [
        _Heading(
          icon: warning ? IconName.triangleAlert : IconName.type,
          color: switch (row.kind) {
            ReviewRowKind.text => theme.pageColors.editMark,
            ReviewRowKind.font => colors.iconSecondary,
            ReviewRowKind.warning => colors.warningSolid,
          },
          where: _where(l10n, format, row),
          time: row.time,
        ),
        // A restored step's name already stands in the heading.
        if (noWords && row.page != null)
          Text(row.name, style: style)
        else if (!noWords)
          Text.rich(
            locale: locale,
            TextSpan(
              style: style,
              children: [
                if (row.from.isNotEmpty) ...[
                  TextSpan(
                    text: bidiIsolate(row.from),
                    style: style.copyWith(
                      color: colors.danger,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  TextSpan(text: _arrow(context)),
                ],
                TextSpan(
                  text: warning
                      ? _keptWarning(l10n, format, row)
                      : bidiIsolate(row.to),
                  style: style.copyWith(
                    backgroundColor: warning
                        ? theme.pageColors.glyphMissingBg
                        : theme.pageColors.diffAdded,
                  ),
                ),
              ],
            ),
          ),
        Row(
          spacing: theme.space.space1_5,
          children: [
            if (row.page != null)
              Button(
                size: ButtonSize.sm,
                variant: ButtonVariant.ghost,
                icon: IconName.arrowRight,
                onPressed: () => unawaited(
                  list.goTo(
                    row,
                    l10n.editStepText(format.integer(row.page! + 1)),
                  ),
                ),
                child: Text(l10n.reviewGoTo),
              ),
            Button(
              size: ButtonSize.sm,
              variant: ButtonVariant.ghost,
              icon: IconName.rotateCcw,
              onPressed: () =>
                  unawaited(list.revert(row.step, l10n.reviewStepReverted)),
              child: Text(l10n.reviewRevert),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ReviewRow>('row', row))
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(DiagnosticsProperty<Locale?>('locale', locale));
  }
}

/// The review list's question over the window (a3-12b), or nothing.
class ReviewListDialogs extends ConsumerWidget {
  /// The dialogs.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final list = ref.read(reviewListProvider.notifier);
    final name = ref.watch(shellDocumentsProvider).active?.name ?? '';
    final history = ref.watch(documentEditorProvider).history;
    final asking = ref.watch(reviewListProvider.select((s) => s.asking));
    switch (asking) {
      case null:
        return const SizedBox.shrink();
      case RevertAllQuestion(:final count):
        final shown = format.integer(count);
        return Dialog(
          icon: IconName.rotateCcw,
          title: l10n.reviewRevertAllTitle(count, shown),
          description: l10n.reviewRevertAllBody(bidiIsolate(name)),
          onClose: list.cancel,
          closeLabel: l10n.saveAsClose,
          cancelAction: Button(
            onPressed: list.cancel,
            child: Text(l10n.saveAsCancel),
          ),
          actions: [
            Button(
              variant: ButtonVariant.primary,
              autofocus: true,
              onPressed: () =>
                  unawaited(list.revertAll(l10n.reviewStepRevertedAll)),
              child: Text(l10n.reviewRevertAllButton(count, shown)),
            ),
          ],
        );
      case DependentsQuestion(:final step, :final dependents):
        String quoted(int index) {
          if (index >= history.steps.length) return '';
          final item = history.steps[index];
          return bidiIsolate(changedWords(item.before, item.after).$2);
        }

        final item = history.steps.elementAtOrNull(step);
        final String change;
        if (item == null || _sameText(item.before, item.after)) {
          change = bidiIsolate(item?.name ?? '');
        } else {
          final (from, to) = changedWords(item.before, item.after);
          change = '${bidiIsolate(from)}${_arrow(context)}${bidiIsolate(to)}';
        }
        final count = dependents.length;
        return Dialog(
          icon: IconName.rotateCcw,
          title: l10n.reviewDependentTitle(count, format.integer(count)),
          description: count == 1
              ? l10n.reviewDependentBody(quoted(dependents.first), change)
              : l10n.reviewDependentsBody(count, format.integer(count), change),
          onClose: list.cancel,
          closeLabel: l10n.saveAsClose,
          cancelAction: Button(
            onPressed: list.cancel,
            child: Text(l10n.saveAsCancel),
          ),
          actions: [
            Button(
              variant: ButtonVariant.primary,
              autofocus: true,
              onPressed: () => unawaited(
                list.revertWithDependents(step, l10n.reviewStepReverted),
              ),
              child: Text(
                l10n.reviewDependentButton(count, format.integer(count + 1)),
              ),
            ),
          ],
        );
    }
  }
}
