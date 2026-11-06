import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/combine.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// a6-3: the Combine tab. The file list on the start side with drag reorder,
/// a page range per file, a bookmark per file and the locked rows G45 adds; the
/// result on the end side as the pages it will hold.
class CombineTab extends ConsumerStatefulWidget {
  /// The tab.
  const new({super.key});

  /// The list's column (`grid-template-columns: 560px …`).
  static const double listWidth = 560;

  /// The share of a narrow canvas the list takes at most.
  static const double listShare = 0.6;

  /// The footer's padding and the result heading's gap (`14px`).
  static const double footerPadding = 14;

  /// The header's height (`height: 44px`).
  static const double headerHeight = 44;

  @override
  ConsumerState<CombineTab> createState() => _CombineTabState();
}

class _CombineTabState extends ConsumerState<CombineTab> {
  TextEditingController? _name;

  /// Where a dragged row would land, by row index.
  int? _dropAt;

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final files = ref.watch(combineFilesProvider);
    final notifier = ref.read(combineFilesProvider.notifier);
    final name = _name ??= TextEditingController(text: l10n.combineDefaultName);
    final rows = files.rows;
    final summary = [
      l10n.organizeFileCount(rows.length, format.integer(rows.length)),
      l10n.organizePageCount(files.pages, format.integer(files.pages)),
    ].join(' · ');
    void addFiles() =>
        unawaited(notifier.pick(filterLabel: l10n.combineFilter));

    final list = ColoredBox(
      color: theme.colors.surfacePanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: CombineTab.headerHeight,
            padding: EdgeInsetsDirectional.only(
              start: theme.space.space4,
              end: theme.space.space2_5,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colors.borderSubtle),
              ),
            ),
            child: Row(
              spacing: theme.space.space2,
              children: [
                Expanded(
                  child: Text(
                    summary,
                    style: theme.typography.panelTitle.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ),
                Button(
                  size: ButtonSize.sm,
                  icon: IconName.plus,
                  onPressed: addFiles,
                  child: Text(l10n.combineAddFiles),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? EmptyState(
                    icon: IconName.merge,
                    title: l10n.combineEmptyTitle,
                    body: l10n.combineEmptyBody,
                  )
                : SingleChildScrollView(
                    padding: EdgeInsetsDirectional.all(theme.space.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: theme.space.space2,
                      children: [
                        for (final (index, row) in rows.indexed)
                          _FileRow(
                            key: ValueKey(row.id),
                            row: row,
                            number: index + 1,
                            count: rows.length,
                            dropBefore: _dropAt == index,
                            dropAfter:
                                _dropAt == rows.length &&
                                index == rows.length - 1,
                            onHover: (after) => setState(
                              () => _dropAt = after ? index + 1 : index,
                            ),
                            onLeave: () => setState(() => _dropAt = null),
                            onDrop: (id) {
                              final at = _dropAt;
                              setState(() => _dropAt = null);
                              if (at != null) notifier.move(id, at);
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          Container(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.space.space4,
              vertical: CombineTab.footerPadding,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.colors.borderSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space2_5,
              children: [
                TextField(
                  size: FieldSize.sm,
                  label: l10n.combineNewFile,
                  controller: name,
                ),
                Checkbox(
                  checked: files.bookmarks,
                  label: l10n.combineBookmarks,
                  onChanged: (on) => notifier.setBookmarks(on: on),
                ),
                Checkbox(
                  checked: files.keepForms,
                  label: l10n.combineKeepForms,
                  description: l10n.combineKeepFormsNote,
                  onChanged: (on) => notifier.setKeepForms(on: on),
                ),
                Row(
                  spacing: theme.space.space2_5,
                  children: [
                    Expanded(
                      child: rows.isEmpty
                          ? const SizedBox.shrink()
                          : Text(
                              l10n.combineAbout(
                                bidiIsolate(format.fileSize(files.bytes)),
                              ),
                              style: theme.typography.caption.copyWith(
                                color: theme.colors.textSecondary,
                              ),
                            ),
                    ),
                    Button(
                      variant: ButtonVariant.primary,
                      icon: IconName.merge,
                      disabled: !files.canCombine,
                      onPressed: files.canCombine
                          ? () => unawaited(notifier.combine(name: name.text))
                          : null,
                      child: Text(
                        l10n.combineAction(
                          rows.length,
                          format.integer(rows.length),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // The list over the result where they cannot sit side by side.
    if (WindowMetrics.isPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: list),
          Expanded(child: _Result(files)),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: math.min(
              CombineTab.listWidth,
              constraints.maxWidth * CombineTab.listShare,
            ),
            decoration: BoxDecoration(
              border: BorderDirectional(
                end: BorderSide(color: theme.colors.borderSubtle),
              ),
            ),
            child: list,
          ),
          Expanded(child: _Result(files)),
        ],
      ),
    );
  }
}

/// A row of the list: grip, number, name and what it is, pages, remove; below,
/// a locked row's password and whatever the output will lose.
class _FileRow extends ConsumerStatefulWidget {
  const new({
    required this.row,
    required this.number,
    required this.count,
    required this.dropBefore,
    required this.dropAfter,
    required this.onHover,
    required this.onLeave,
    required this.onDrop,
    super.key,
  });

  /// The grip's and the number chip's column (`20px 22px`).
  static const double numberSize = 22;

  /// The range field's column (`120px`).
  static const double rangeWidth = 120;

  /// The insertion bar's thickness (`height: 3px`).
  static const double barHeight = 3;

  /// How far a lifted row turns (`rotate(-1deg)`).
  static const double liftTurn = -math.pi / 180;

  /// How far a lifted row sits from the pointer.
  static const Offset liftOffset = Offset(-24, -24);

  final CombineRow row;
  final int number;
  final int count;
  final bool dropBefore;
  final bool dropAfter;
  final ValueChanged<bool> onHover;
  final VoidCallback onLeave;
  final ValueChanged<int> onDrop;

  @override
  ConsumerState<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends ConsumerState<_FileRow> {
  final TextEditingController _password = TextEditingController();
  TextEditingController? _range;

  CombineRow get _row => widget.row;

  @override
  void dispose() {
    _password.dispose();
    _range?.dispose();
    super.dispose();
  }

  CombineFilesNotifier get _notifier => ref.read(combineFilesProvider.notifier);

  void _move(int by) =>
      // Before the row now there: past the next one when going down.
      _notifier.move(_row.id, widget.number - 1 + (by > 0 ? 2 : -1));

  String _meta(AppLocalizations l10n, RegionFormat format) {
    if (_row.office) return l10n.combineMetaOffice;
    final info = _row.info;
    if (info == null) return '';
    if (info.image) return l10n.combineMetaImage;
    final pages = l10n.organizePageCount(
      info.pages,
      format.integer(info.pages),
    );
    return 'PDF · $pages';
  }

  /// What stops the row, if anything.
  String? _problem(AppLocalizations l10n) {
    if (_row.badRange) return l10n.combineBadRange;
    return switch (_row.info?.status) {
      CombineInputStatus.passwordRequired => l10n.combineNeedsPassword,
      CombineInputStatus.wrongPassword => l10n.combineWrongPassword,
      CombineInputStatus.ownerPasswordRequired => l10n.combineOwnerPassword,
      CombineInputStatus.unreadable => l10n.combineUnreadable,
      _ => null,
    };
  }

  bool get _locked => switch (_row.info?.status) {
    CombineInputStatus.passwordRequired ||
    CombineInputStatus.wrongPassword ||
    CombineInputStatus.ownerPasswordRequired => true,
    _ => false,
  };

  Widget _card(BuildContext context, {required Widget grip}) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final info = _row.info;
    final problem = _problem(l10n);
    final range = _range ??= TextEditingController(
      text: _row.range ?? l10n.combineAllPages,
    );
    final caption = theme.typography.caption;
    // Where the columns cannot fit, the range has a line of its own.
    final phone = WindowMetrics.isPhone(context);
    final rangeField = TextField(
      size: FieldSize.sm,
      semanticLabel: l10n.combinePagesToInclude,
      controller: range,
      disabled: _row.office || (info?.image ?? false),
      disabledReason: _row.office
          ? Feature.officeInputs.disabledReason(context)
          : null,
      onChanged: (text) {
        final typed = text.trim();
        _notifier.setRange(
          _row.id,
          typed.isEmpty || typed == l10n.combineAllPages ? null : typed,
        );
      },
    );
    return Container(
      padding: EdgeInsetsDirectional.all(theme.space.space2_5),
      decoration: BoxDecoration(
        color: theme.colors.surfaceRaised,
        border: Border.fromBorderSide(
          BorderSide(color: theme.colors.borderSubtle),
        ),
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusMd)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space2,
        children: [
          Row(
            spacing: theme.space.space2_5,
            children: [
              grip,
              Container(
                width: _FileRow.numberSize,
                height: _FileRow.numberSize,
                alignment: AlignmentDirectional.center,
                decoration: BoxDecoration(
                  color: theme.colors.surfaceSunken,
                  borderRadius: BorderRadius.all(
                    Radius.circular(theme.radius.radiusSm),
                  ),
                ),
                child: Text(
                  format.integer(widget.number),
                  style: caption.copyWith(color: theme.colors.textPrimary),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.space.space0_5,
                  children: [
                    Text(
                      _row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.bodyStrong.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                    Text(
                      _meta(l10n, format),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!phone)
                SizedBox(width: _FileRow.rangeWidth, child: rangeField),
              IconButton(
                icon: IconName.x,
                label: l10n.combineRemoveFile,
                size: IconButtonSize.sm,
                onPressed: () => _notifier.remove(_row.id),
              ),
            ],
          ),
          if (phone) rangeField,
          if (problem != null)
            Text(problem, style: caption.copyWith(color: theme.colors.danger)),
          if (_locked)
            Row(
              spacing: theme.space.space2,
              children: [
                Expanded(
                  child: TextField(
                    size: FieldSize.sm,
                    icon: IconName.lock,
                    semanticLabel: l10n.combinePassword,
                    placeholder: l10n.combinePassword,
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (text) => _notifier.setPassword(_row.id, text),
                  ),
                ),
                Button(
                  size: ButtonSize.sm,
                  onPressed: () =>
                      _notifier.setPassword(_row.id, _password.text),
                  child: Text(l10n.combineUnlock),
                ),
              ],
            ),
          if (info?.encrypted ?? false)
            Text(
              l10n.combineNotProtected,
              style: caption.copyWith(color: theme.colors.textSecondary),
            ),
          if (info?.signed ?? false)
            Text(
              l10n.combineNotSigned,
              style: caption.copyWith(color: theme.colors.textSecondary),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final grip = Draggable<int>(
      data: _row.id,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Directionality(
        textDirection: direction,
        child: Transform.translate(
          offset: _FileRow.liftOffset,
          child: Transform.rotate(
            angle: _FileRow.liftTurn,
            child: Container(
              constraints: const BoxConstraints(maxWidth: CombineTab.listWidth),
              padding: EdgeInsetsDirectional.all(theme.space.space2_5),
              decoration: BoxDecoration(
                color: theme.colors.surfaceRaised,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusMd),
                ),
                boxShadow: theme.elevation.shadowDrag,
              ),
              child: Text(
                _row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.bodyStrong.copyWith(
                  color: theme.colors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
      // The keyboard's way, and a screen reader's.
      child: Semantics(
        label: l10n.combineDrag,
        customSemanticsActions: {
          if (widget.number > 1)
            CustomSemanticsAction(label: l10n.combineMoveUp): () => _move(-1),
          if (widget.number < widget.count)
            CustomSemanticsAction(label: l10n.combineMoveDown): () => _move(1),
        },
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyUpEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                widget.number > 1) {
              _move(-1);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                widget.number < widget.count) {
              _move(1);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (context) => MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: FocusRing(
                visible: Focus.of(context).hasFocus,
                child: Icon(
                  IconName.gripVertical,
                  color: theme.colors.iconSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return DragTarget<int>(
      onMove: (details) {
        final box = context.findRenderObject();
        if (box is! RenderBox) return;
        final local = box.globalToLocal(details.offset);
        widget.onHover(local.dy > box.size.height / 2);
      },
      onLeave: (_) => widget.onLeave(),
      onAcceptWithDetails: (details) => widget.onDrop(details.data),
      builder: (context, _, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          _card(context, grip: grip),
          if (widget.dropBefore || widget.dropAfter)
            PositionedDirectional(
              start: 0,
              end: 0,
              top: widget.dropBefore
                  ? -(theme.space.space2 + _FileRow.barHeight) / 2
                  : null,
              bottom: widget.dropAfter
                  ? -(theme.space.space2 + _FileRow.barHeight) / 2
                  : null,
              height: _FileRow.barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colors.accent,
                  borderRadius: BorderRadius.all(
                    Radius.circular(theme.radius.radiusSm),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// a6-3's result: a sheet per page of the output, with its file's number.
///
/// shortcut: blank sheets, no page images, since the engine renders only open
/// documents; upgrade with a thumbnail by path (B196).
class _Result extends ConsumerWidget {
  const new(this.files);

  final CombineFiles files;

  /// A page's width (`width:110px`).
  static const double sheetWidth = 110;

  /// A page's height (`height:156px`).
  static const double sheetHeight = 156;

  /// A cell of the grid (`repeat(4,128px)`).
  static const double cellWidth = 128;

  /// A cell's height: the sheet, its gap and its number.
  static const double cellHeight = 182;

  /// The file's chip (`width:18px;height:18px`).
  static const double chipSize = 18;

  /// The gap between columns (`gap: 18px 22px`).
  static const double columnGap = 22;

  /// The gap between rows.
  static const double rowGap = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final fileOfPage = <int>[
      for (final (index, row) in files.rows.indexed)
        for (var i = 0; i < (row.info?.selected ?? 0); i++) index + 1,
    ];
    return Padding(
      padding: EdgeInsetsDirectional.all(theme.space.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CombineTab.footerPadding,
        children: [
          Text(
            l10n.combineResult(
              fileOfPage.length,
              format.integer(fileOfPage.length),
            ),
            style: theme.typography.label.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: cellWidth,
                mainAxisExtent: cellHeight,
                crossAxisSpacing: columnGap,
                mainAxisSpacing: rowGap,
              ),
              itemCount: fileOfPage.length,
              itemBuilder: (context, index) => Semantics(
                label: l10n.combineResultPage(
                  format.integer(index + 1),
                  format.integer(fileOfPage[index]),
                ),
                excludeSemantics: true,
                child: Column(
                  spacing: theme.space.space1_5,
                  children: [
                    Container(
                      width: sheetWidth,
                      height: sheetHeight,
                      alignment: AlignmentDirectional.topStart,
                      padding: EdgeInsetsDirectional.all(theme.space.space1),
                      decoration: BoxDecoration(
                        color: theme.ramps.paper0,
                        border: Border.fromBorderSide(
                          BorderSide(color: theme.colors.borderDefault),
                        ),
                        boxShadow: theme.elevation.shadowSm,
                      ),
                      child: Container(
                        width: chipSize,
                        height: chipSize,
                        alignment: AlignmentDirectional.center,
                        decoration: BoxDecoration(
                          color: theme.colors.surfaceSunken,
                          border: Border.fromBorderSide(
                            BorderSide(color: theme.colors.borderDefault),
                          ),
                          borderRadius: BorderRadius.all(
                            Radius.circular(theme.radius.radiusSm),
                          ),
                        ),
                        child: Text(
                          format.integer(fileOfPage[index]),
                          style: theme.typography.caption.copyWith(
                            color: theme.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      format.integer(index + 1),
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.textSecondary,
                      ),
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
